extends SceneTree

const EXTENTS: Array[int] = [6, 10, 14]
const PATTERNS: Array[String] = ["dense", "shell", "skeleton"]
const TIMING_SAMPLES := 3

var _failures: Array[String] = []
var _next_lineage_token := 3_000_001


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "R1CollisionAggregationWorld"
	get_root().add_child(world)

	for extent in EXTENTS:
		for pattern in PATTERNS:
			await _measure_case(world, extent, pattern)

	_finish(world)


func _measure_case(world: Node3D, extent: int, pattern: String) -> void:
	var truth_volume := _make_pattern_volume(extent, pattern)
	var occupied := truth_volume.count_solid()
	var reference_boxes := CellCollisionBoxer.build_boxes(truth_volume, CellCollisionBoxer.Mode.PER_CELL)
	var merged_boxes := CellCollisionBoxer.build_boxes(truth_volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
	var coverage_errors := _coverage_error_count(truth_volume, merged_boxes)

	_check(reference_boxes.size() == occupied, "R1 reference box count equals occupied Matter")
	_check(CellCollisionBoxer.covered_cell_count(merged_boxes) == occupied, "R1 merged cuboids cover exactly occupied-cell cardinality")
	_check(coverage_errors == 0, "R1 merged cuboids exactly cover occupied Matter without gaps/overlap")
	_check(merged_boxes.size() <= reference_boxes.size(), "R1 aggregation never increases shape count")
	if pattern == "dense":
		_check(merged_boxes.size() == 1, "R1 dense cuboid compiles to one exact box")
	else:
		_check(merged_boxes.size() < reference_boxes.size(), "R1 non-dense pressure case achieves real shape compression")

	var per_static_samples: Array[float] = []
	var merged_static_samples: Array[float] = []
	var per_dynamic_samples: Array[float] = []
	var merged_dynamic_samples: Array[float] = []
	var per_mutation_samples: Array[float] = []
	var merged_mutation_samples: Array[float] = []

	for _sample in range(TIMING_SAMPLES):
		per_static_samples.append(_measure_static_init(world, extent, pattern, CellCollisionBoxer.Mode.PER_CELL))
		merged_static_samples.append(_measure_static_init(world, extent, pattern, CellCollisionBoxer.Mode.MERGED_CUBOIDS))
		per_dynamic_samples.append(_measure_dynamic_init(world, extent, pattern, CellCollisionBoxer.Mode.PER_CELL))
		merged_dynamic_samples.append(_measure_dynamic_init(world, extent, pattern, CellCollisionBoxer.Mode.MERGED_CUBOIDS))
		per_mutation_samples.append(_measure_space_mutation(world, extent, pattern, CellCollisionBoxer.Mode.PER_CELL))
		merged_mutation_samples.append(_measure_space_mutation(world, extent, pattern, CellCollisionBoxer.Mode.MERGED_CUBOIDS))

	var per_static := _median(per_static_samples)
	var merged_static := _median(merged_static_samples)
	var per_dynamic := _median(per_dynamic_samples)
	var merged_dynamic := _median(merged_dynamic_samples)
	var per_mutation := _median(per_mutation_samples)
	var merged_mutation := _median(merged_mutation_samples)

	var compression: float = float(reference_boxes.size()) / float(max(merged_boxes.size(), 1))
	var static_speedup: float = per_static / max(merged_static, 1.0)
	var dynamic_speedup: float = per_dynamic / max(merged_dynamic, 1.0)
	var mutation_speedup: float = per_mutation / max(merged_mutation, 1.0)

	if extent == 14 and pattern == "dense":
		_check(static_speedup > 3.0, "R1 dense14 static aggregation materially improves dominant R0 cost")
		_check(dynamic_speedup > 3.0, "R1 dense14 dynamic aggregation materially improves dominant R0 cost")
		_check(mutation_speedup > 3.0, "R1 dense14 aggregated full rebuild materially improves dominant R0 cost")

	print(
		"R1_CASE pattern=%s extent=%d scanned=%d occupied=%d reference_shapes=%d merged_shapes=%d compression=%.3f coverage_errors=%d per_static_us=%.1f merged_static_us=%.1f static_speedup=%.3f per_dynamic_us=%.1f merged_dynamic_us=%.1f dynamic_speedup=%.3f per_mutation_us=%.1f merged_mutation_us=%.1f mutation_speedup=%.3f"
		% [
			pattern,
			extent,
			extent * extent * extent,
			occupied,
			reference_boxes.size(),
			merged_boxes.size(),
			compression,
			coverage_errors,
			per_static,
			merged_static,
			static_speedup,
			per_dynamic,
			merged_dynamic,
			dynamic_speedup,
			per_mutation,
			merged_mutation,
			mutation_speedup,
		]
	)


func _measure_static_init(world: Node3D, extent: int, pattern: String, mode: int) -> float:
	var volume := _make_pattern_volume(extent, pattern)
	var provider := MatterRepresentation.new()
	provider.collision_mode = mode
	world.add_child(provider)
	var started := Time.get_ticks_usec()
	provider.set_volume(volume)
	var elapsed := float(Time.get_ticks_usec() - started)
	var expected_shapes := CellCollisionBoxer.build_boxes(volume, mode).size()
	_check(provider.get_collision_shape_count() == expected_shapes, "R1 static provider installs compiled collision shape count")
	provider.free()
	return elapsed


func _measure_dynamic_init(world: Node3D, extent: int, pattern: String, mode: int) -> float:
	var volume := _make_pattern_volume(extent, pattern)
	var provider := ConstructBody.new()
	provider.collision_mode = mode
	provider.gravity_scale = 0.0
	provider.can_sleep = false
	world.add_child(provider)
	var started := Time.get_ticks_usec()
	provider.set_volume(volume)
	var elapsed := float(Time.get_ticks_usec() - started)
	var expected_shapes := CellCollisionBoxer.build_boxes(volume, mode).size()
	_check(provider.get_collision_shape_count() == expected_shapes, "R1 dynamic provider installs compiled collision shape count")
	_check(abs(provider.mass - float(volume.count_solid())) < 0.001, "R1 dynamic mass remains Matter-derived")
	provider.free()
	return elapsed


func _measure_space_mutation(world: Node3D, extent: int, pattern: String, mode: int) -> float:
	var volume := _make_pattern_volume(extent, pattern)
	var lineage := _make_lineage(volume)
	var space := LocalMatterSpace.new()
	space.collision_mode = mode
	space.dynamic_gravity_scale = 0.0
	space.dynamic_can_sleep = false
	world.add_child(space)
	space.initialize_dynamic(volume, lineage, Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO)
	var cell := _first_occupied_cell(volume)
	var token_before := lineage.get_lineage(cell)
	var material_before := volume.get_cell(cell)
	var material_after := 2 if material_before == CellVolume.SOLID else CellVolume.SOLID
	var started := Time.get_ticks_usec()
	var mutated := space.mutate_cell(cell, material_after)
	var elapsed := float(Time.get_ticks_usec() - started)
	_check(mutated, "R1 retained-Matter mutation succeeds")
	_check(lineage.get_lineage(cell) == token_before, "R1 retained-Matter mutation preserves lineage")
	var provider := space.get_active_provider() as ConstructBody
	var expected_shapes := CellCollisionBoxer.build_boxes(volume, mode).size()
	_check(provider != null and provider.get_collision_shape_count() == expected_shapes, "R1 shared mutation rebuild uses selected collision compiler")
	space.free()
	return elapsed


func _coverage_error_count(volume: CellVolume, boxes: Array[Dictionary]) -> int:
	var total := volume.size.x * volume.size.y * volume.size.z
	var coverage := PackedInt32Array()
	coverage.resize(total)
	coverage.fill(0)
	var errors := 0

	for box_info in boxes:
		var origin: Vector3i = box_info["origin"]
		var size: Vector3i = box_info["size"]
		if size.x <= 0 or size.y <= 0 or size.z <= 0:
			errors += 1
			continue
		if origin.x < 0 or origin.y < 0 or origin.z < 0:
			errors += 1
			continue
		if origin.x + size.x > volume.size.x or origin.y + size.y > volume.size.y or origin.z + size.z > volume.size.z:
			errors += 1
			continue
		for z in range(origin.z, origin.z + size.z):
			for y in range(origin.y, origin.y + size.y):
				for x in range(origin.x, origin.x + size.x):
					var index := _index(volume.size, Vector3i(x, y, z))
					coverage[index] += 1

	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				var expected := 0 if volume.get_cell(cell) == CellVolume.EMPTY else 1
				if coverage[_index(volume.size, cell)] != expected:
					errors += 1
	return errors


func _make_pattern_volume(extent: int, pattern: String) -> CellVolume:
	var size := Vector3i(extent, extent, extent)
	var volume := CellVolume.new(size)
	match pattern:
		"dense":
			volume.fill_box(Vector3i.ZERO, size, CellVolume.SOLID)
		"shell":
			for z in range(extent):
				for y in range(extent):
					for x in range(extent):
						if x == 0 or y == 0 or z == 0 or x == extent - 1 or y == extent - 1 or z == extent - 1:
							volume.set_cell(Vector3i(x, y, z), CellVolume.SOLID)
		"skeleton":
			var mid := extent / 2
			for axis_index in range(extent):
				volume.set_cell(Vector3i(axis_index, mid, mid), CellVolume.SOLID)
				volume.set_cell(Vector3i(mid, axis_index, mid), CellVolume.SOLID)
				volume.set_cell(Vector3i(mid, mid, axis_index), CellVolume.SOLID)
		_:
			assert(false, "Unknown R1 pattern")
	return volume


func _make_lineage(volume: CellVolume) -> MatterLineageMap:
	var lineage := MatterLineageMap.new(volume.size)
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				lineage.set_lineage(cell, _next_lineage_token)
				_next_lineage_token += 1
	return lineage


func _first_occupied_cell(volume: CellVolume) -> Vector3i:
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					return cell
	return Vector3i(-1, -1, -1)


func _index(size: Vector3i, cell: Vector3i) -> int:
	return cell.x + size.x * (cell.y + size.y * cell.z)


func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("R1_COLLISION_AGGREGATION_CHALLENGER_PASS: exact merged cuboids preserved occupied collision coverage and materially reduced the dominant R0 provider/rebuild cost in the pressure case.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("R1_COLLISION_AGGREGATION_CHALLENGER_FAIL: " + failure)
	world.free()
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
