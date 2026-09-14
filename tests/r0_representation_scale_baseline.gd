extends SceneTree

const EXTENTS: Array[int] = [6, 10, 14]
const PATTERNS: Array[String] = ["dense", "shell", "skeleton"]
const TIMING_SAMPLES := 3
const MASS_PER_CELL := 1.0

var _failures: Array[String] = []
var _next_lineage_token := 2_000_001


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "R0RepresentationScaleBaseline"
	get_root().add_child(world)

	print("R0_BASELINE_BEGIN extents=%s patterns=%s samples=%d" % [str(EXTENTS), str(PATTERNS), TIMING_SAMPLES])

	for extent in EXTENTS:
		for pattern in PATTERNS:
			await _measure_representation_case(world, extent, pattern)

	for extent in EXTENTS:
		await _measure_split_case(world, extent)

	_finish(world)


func _measure_representation_case(world: Node3D, extent: int, pattern: String) -> void:
	var static_samples: Array[float] = []
	var dynamic_samples: Array[float] = []
	var mutation_samples: Array[float] = []
	var topology_samples: Array[float] = []
	var occupied := 0
	var collision_shapes := 0
	var mesh_vertices := 0
	var component_count := 0

	for _sample in range(TIMING_SAMPLES):
		var static_volume := _make_pattern_volume(extent, pattern)
		var static_lineage := _make_lineage(static_volume)
		occupied = static_volume.count_solid()
		var static_space := LocalMatterSpace.new()
		static_space.name = "R0Static_%s_%d" % [pattern, extent]
		static_space.collision_mode = CellCollisionBoxer.Mode.PER_CELL
		world.add_child(static_space)
		var static_started := Time.get_ticks_usec()
		static_space.initialize_static(static_volume, static_lineage, Transform3D.IDENTITY)
		static_samples.append(float(Time.get_ticks_usec() - static_started))
		var static_provider := static_space.get_active_provider() as MatterRepresentation
		_check(static_provider != null, "R0 static provider exists for %s/%d" % [pattern, extent])
		if static_provider != null:
			_check(static_provider.get_collision_shape_count() == occupied, "reference static box-per-cell shape count matches occupied Matter")
		static_space.free()

		var dynamic_volume := _make_pattern_volume(extent, pattern)
		var dynamic_lineage := _make_lineage(dynamic_volume)
		var dynamic_space := LocalMatterSpace.new()
		dynamic_space.name = "R0Dynamic_%s_%d" % [pattern, extent]
		dynamic_space.mass_per_cell = MASS_PER_CELL
		dynamic_space.collision_mode = CellCollisionBoxer.Mode.PER_CELL
		dynamic_space.dynamic_gravity_scale = 0.0
		dynamic_space.dynamic_linear_damp = 0.0
		dynamic_space.dynamic_angular_damp = 0.0
		dynamic_space.dynamic_can_sleep = false
		world.add_child(dynamic_space)
		var dynamic_started := Time.get_ticks_usec()
		dynamic_space.initialize_dynamic(
			dynamic_volume,
			dynamic_lineage,
			Transform3D.IDENTITY,
			Vector3.ZERO,
			Vector3.ZERO
		)
		dynamic_samples.append(float(Time.get_ticks_usec() - dynamic_started))
		var body := dynamic_space.get_active_provider() as ConstructBody
		_check(body != null, "R0 dynamic provider exists for %s/%d" % [pattern, extent])
		if body != null:
			collision_shapes = body.get_collision_shape_count()
			mesh_vertices = body.get_mesh_vertex_count()
			_check(collision_shapes == occupied, "reference dynamic box-per-cell shape count matches occupied Matter")
			_check(mesh_vertices > 0, "derived mesh exists for non-empty R0 case")

		var mutation_cell := _first_occupied_cell(dynamic_volume)
		_check(mutation_cell.x >= 0, "R0 mutation cell exists")
		if mutation_cell.x >= 0:
			var before_material := dynamic_volume.get_cell(mutation_cell)
			var after_material := 2 if before_material == CellVolume.SOLID else CellVolume.SOLID
			var mutation_started := Time.get_ticks_usec()
			var mutated := dynamic_space.mutate_cell(mutation_cell, after_material)
			mutation_samples.append(float(Time.get_ticks_usec() - mutation_started))
			_check(mutated, "R0 retained-Matter material mutation succeeds")
			_check(dynamic_lineage.get_lineage(mutation_cell) != MatterLineageMap.NONE, "R0 retained material mutation keeps lineage")

		var topology_started := Time.get_ticks_usec()
		var components := MatterTopology.extract_connected_components(dynamic_volume)
		topology_samples.append(float(Time.get_ticks_usec() - topology_started))
		component_count = components.size()
		_check(component_count == 1, "R0 %s pattern remains one connected component" % pattern)
		dynamic_space.free()

	var scanned := extent * extent * extent
	print(
		"R0_CASE pattern=%s extent=%d scanned=%d occupied=%d occupancy=%.6f shapes=%d vertices=%d components=%d static_init_us=%.1f dynamic_init_us=%.1f mutation_full_rebuild_us=%.1f topology_extract_us=%.1f"
		% [
			pattern,
			extent,
			scanned,
			occupied,
			float(occupied) / float(scanned),
			collision_shapes,
			mesh_vertices,
			component_count,
			_median(static_samples),
			_median(dynamic_samples),
			_median(mutation_samples),
			_median(topology_samples),
		]
	)


func _measure_split_case(world: Node3D, extent: int) -> void:
	var request_samples: Array[float] = []
	var commit_samples: Array[float] = []
	var occupied := 0
	var successor_count := 0
	var successor_shapes := 0

	for _sample in range(TIMING_SAMPLES):
		var volume := _make_split_volume(extent)
		var lineage := _make_lineage(volume)
		occupied = volume.count_solid()
		var space := LocalMatterSpace.new()
		space.name = "R0Split_%d" % extent
		space.mass_per_cell = MASS_PER_CELL
		space.collision_mode = CellCollisionBoxer.Mode.PER_CELL
		space.dynamic_gravity_scale = 0.0
		space.dynamic_linear_damp = 0.0
		space.dynamic_angular_damp = 0.0
		space.dynamic_can_sleep = false
		world.add_child(space)
		space.initialize_dynamic(volume, lineage, Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO)

		var request_started := Time.get_ticks_usec()
		var accepted := space.request_connected_component_split()
		request_samples.append(float(Time.get_ticks_usec() - request_started))
		_check(accepted, "R0 disconnected split request accepted")
		if not accepted:
			space.free()
			continue

		# R0 measures synchronous work, not scheduler wait. This invokes the exact
		# shared transaction implementation that the physics-frame callback invokes.
		var commit_started := Time.get_ticks_usec()
		space._commit_connected_component_split()
		commit_samples.append(float(Time.get_ticks_usec() - commit_started))
		var result := space.get_last_split_result()
		_check(result != null, "R0 split publishes result")
		if result != null:
			successor_count = result.size()
			successor_shapes = 0
			for successor_variant in result.successors:
				var successor := successor_variant as LocalMatterSpace
				if successor == null:
					continue
				var body := successor.get_active_provider() as ConstructBody
				if body != null:
					successor_shapes += body.get_collision_shape_count()
			_check(successor_count == 2, "R0 split creates two successors")
			_check(successor_shapes == occupied, "R0 successor reference shapes partition retained occupied Matter")
			for successor_variant in result.successors:
				var successor := successor_variant as LocalMatterSpace
				if successor != null:
					successor.free()
		space.free()

	var scanned := extent * extent * extent
	print(
		"R0_SPLIT extent=%d scanned=%d occupied=%d successors=%d successor_shapes=%d request_preflight_us=%.1f commit_transaction_us=%.1f synchronous_split_work_us=%.1f"
		% [
			extent,
			scanned,
			occupied,
			successor_count,
			successor_shapes,
			_median(request_samples),
			_median(commit_samples),
			_median(request_samples) + _median(commit_samples),
		]
	)


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
			assert(false, "Unknown R0 pattern")
	return volume


func _make_split_volume(extent: int) -> CellVolume:
	var size := Vector3i(extent, extent, extent)
	var volume := CellVolume.new(size)
	var gap_x := extent / 2
	volume.fill_box(Vector3i.ZERO, Vector3i(gap_x, extent, extent), CellVolume.SOLID)
	volume.fill_box(Vector3i(gap_x + 1, 0, 0), size, CellVolume.SOLID)
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


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("R0_REPRESENTATION_SCALE_BASELINE_PASS: reference representation costs measured without changing the implementation under test.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("R0_REPRESENTATION_SCALE_BASELINE_FAIL: " + failure)
	world.free()
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
