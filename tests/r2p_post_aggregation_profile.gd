extends SceneTree

const EXTENTS: Array[int] = [6, 10, 14]
const PATTERNS: Array[String] = ["dense", "shell", "skeleton"]
const TIMING_SAMPLES := 3

var _failures: Array[String] = []
var _next_lineage_token := 4_000_001


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "R2PPostAggregationProfileWorld"
	get_root().add_child(world)

	print("R2P_PROFILE_BEGIN extents=%s patterns=%s samples=%d" % [str(EXTENTS), str(PATTERNS), TIMING_SAMPLES])

	for extent in EXTENTS:
		for pattern in PATTERNS:
			_measure_representation_case(world, extent, pattern)

	for extent in EXTENTS:
		_measure_split_case(world, extent)

	_finish(world)


func _measure_representation_case(world: Node3D, extent: int, pattern: String) -> void:
	var reference := _make_pattern_volume(extent, pattern)
	var occupied := reference.count_solid()
	var boxes := CellCollisionBoxer.build_boxes(reference, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
	var shape_count := boxes.size()
	var mesh_vertices := _mesh_vertex_count(reference)

	_check(occupied > 0, "R2P %s/%d contains occupied Matter" % [pattern, extent])
	_check(shape_count > 0, "R2P %s/%d has merged collision" % [pattern, extent])
	_check(CellCollisionBoxer.covered_cell_count(boxes) == occupied, "R2P %s/%d merged coverage cardinality matches Matter" % [pattern, extent])

	var count_samples: Array[float] = []
	var mesh_samples: Array[float] = []
	var compile_samples: Array[float] = []
	var com_samples: Array[float] = []
	var static_install_samples: Array[float] = []
	var dynamic_install_samples: Array[float] = []
	var static_provider_samples: Array[float] = []
	var dynamic_provider_samples: Array[float] = []
	var material_edit_samples: Array[float] = []
	var occupancy_edit_samples: Array[float] = []
	var occupancy_shapes_after := 0

	for _sample in range(TIMING_SAMPLES):
		var started := Time.get_ticks_usec()
		var counted := reference.count_solid()
		count_samples.append(float(Time.get_ticks_usec() - started))
		_check(counted == occupied, "R2P direct occupied count remains deterministic")

		started = Time.get_ticks_usec()
		var direct_mesh := CellMesher.build_mesh(reference)
		mesh_samples.append(float(Time.get_ticks_usec() - started))
		_check(direct_mesh.get_surface_count() > 0, "R2P direct mesh build produces a surface")

		started = Time.get_ticks_usec()
		var direct_boxes := CellCollisionBoxer.build_boxes(reference, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
		compile_samples.append(float(Time.get_ticks_usec() - started))
		_check(direct_boxes.size() == shape_count, "R2P collision compiler remains deterministic")

		started = Time.get_ticks_usec()
		var direct_com := MatterTopology.center_of_mass_local(reference)
		com_samples.append(float(Time.get_ticks_usec() - started))
		_check(_finite_vector(direct_com), "R2P Matter COM remains finite")

		static_install_samples.append(_measure_collision_install(world, boxes, false))
		dynamic_install_samples.append(_measure_collision_install(world, boxes, true))
		static_provider_samples.append(_measure_static_provider(world, reference))
		dynamic_provider_samples.append(_measure_dynamic_provider(world, reference))

		var material_result := _measure_material_edit(world, extent, pattern)
		material_edit_samples.append(material_result["elapsed_us"])
		_check(material_result["collision_unchanged"], "R2P material-only edit leaves current collision compilation unchanged")
		_check(material_result["lineage_retained"], "R2P material-only edit retains Matter lineage")

		var occupancy_result := _measure_occupancy_edit(world, extent, pattern)
		occupancy_edit_samples.append(occupancy_result["elapsed_us"])
		occupancy_shapes_after = occupancy_result["shape_count"]
		_check(occupancy_result["solid_count"] == occupied - 1, "R2P occupancy edit removes exactly one Matter cell")

	print(
		"R2P_CASE pattern=%s extent=%d scanned=%d occupied=%d shapes=%d occupancy_shapes_after=%d vertices=%d count_us=%.1f mesh_us=%.1f collision_compile_us=%.1f com_us=%.1f static_shape_install_us=%.1f dynamic_shape_install_us=%.1f static_provider_us=%.1f dynamic_provider_us=%.1f material_edit_fullpath_us=%.1f occupancy_edit_fullpath_us=%.1f"
		% [
			pattern,
			extent,
			extent * extent * extent,
			occupied,
			shape_count,
			occupancy_shapes_after,
			mesh_vertices,
			_median(count_samples),
			_median(mesh_samples),
			_median(compile_samples),
			_median(com_samples),
			_median(static_install_samples),
			_median(dynamic_install_samples),
			_median(static_provider_samples),
			_median(dynamic_provider_samples),
			_median(material_edit_samples),
			_median(occupancy_edit_samples),
		]
	)


func _measure_collision_install(world: Node3D, boxes: Array[Dictionary], dynamic: bool) -> float:
	var body: CollisionObject3D
	if dynamic:
		var dynamic_body := RigidBody3D.new()
		dynamic_body.gravity_scale = 0.0
		dynamic_body.can_sleep = false
		body = dynamic_body
	else:
		body = StaticBody3D.new()
	world.add_child(body)

	var started := Time.get_ticks_usec()
	for box_info in boxes:
		var box_origin: Vector3i = box_info["origin"]
		var box_size: Vector3i = box_info["size"]
		var shape := BoxShape3D.new()
		shape.size = Vector3(float(box_size.x), float(box_size.y), float(box_size.z))
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = shape
		collision_shape.position = Vector3(box_origin) + shape.size * 0.5
		body.add_child(collision_shape)
	var elapsed := float(Time.get_ticks_usec() - started)
	body.free()
	return elapsed


func _measure_static_provider(world: Node3D, source: CellVolume) -> float:
	var provider := MatterRepresentation.new()
	provider.collision_mode = CellCollisionBoxer.Mode.MERGED_CUBOIDS
	world.add_child(provider)
	var started := Time.get_ticks_usec()
	provider.set_volume(source)
	var elapsed := float(Time.get_ticks_usec() - started)
	_check(provider.get_collision_shape_count() == CellCollisionBoxer.build_boxes(source, provider.collision_mode).size(), "R2P static provider installs expected merged shapes")
	provider.free()
	return elapsed


func _measure_dynamic_provider(world: Node3D, source: CellVolume) -> float:
	var provider := ConstructBody.new()
	provider.collision_mode = CellCollisionBoxer.Mode.MERGED_CUBOIDS
	provider.gravity_scale = 0.0
	provider.can_sleep = false
	world.add_child(provider)
	var started := Time.get_ticks_usec()
	provider.set_volume(source)
	var elapsed := float(Time.get_ticks_usec() - started)
	_check(provider.get_collision_shape_count() == CellCollisionBoxer.build_boxes(source, provider.collision_mode).size(), "R2P dynamic provider installs expected merged shapes")
	provider.free()
	return elapsed


func _measure_material_edit(world: Node3D, extent: int, pattern: String) -> Dictionary:
	var volume := _make_pattern_volume(extent, pattern)
	var lineage := _make_lineage(volume)
	var cell := _edit_cell(extent, pattern)
	var before_boxes := CellCollisionBoxer.build_boxes(volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
	var token_before := lineage.get_lineage(cell)
	var before_material := volume.get_cell(cell)
	var after_material := 2 if before_material == CellVolume.SOLID else CellVolume.SOLID

	var space := LocalMatterSpace.new()
	space.dynamic_gravity_scale = 0.0
	space.dynamic_can_sleep = false
	world.add_child(space)
	space.initialize_dynamic(volume, lineage, Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO)

	var started := Time.get_ticks_usec()
	var mutated := space.mutate_cell(cell, after_material)
	var elapsed := float(Time.get_ticks_usec() - started)
	var after_boxes := CellCollisionBoxer.build_boxes(volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
	var provider := space.get_active_provider() as ConstructBody
	_check(mutated, "R2P material-only mutation succeeds")
	_check(provider != null and provider.get_collision_shape_count() == after_boxes.size(), "R2P material-only edit leaves provider coherent")

	var result := {
		"elapsed_us": elapsed,
		"collision_unchanged": before_boxes == after_boxes,
		"lineage_retained": lineage.get_lineage(cell) == token_before,
	}
	space.free()
	return result


func _measure_occupancy_edit(world: Node3D, extent: int, pattern: String) -> Dictionary:
	var volume := _make_pattern_volume(extent, pattern)
	var lineage := _make_lineage(volume)
	var cell := _edit_cell(extent, pattern)

	var space := LocalMatterSpace.new()
	space.dynamic_gravity_scale = 0.0
	space.dynamic_can_sleep = false
	world.add_child(space)
	space.initialize_dynamic(volume, lineage, Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO)

	var started := Time.get_ticks_usec()
	var mutated := space.mutate_cell(cell, CellVolume.EMPTY)
	var elapsed := float(Time.get_ticks_usec() - started)
	var boxes_after := CellCollisionBoxer.build_boxes(volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
	var provider := space.get_active_provider() as ConstructBody
	_check(mutated, "R2P occupancy mutation succeeds")
	_check(lineage.get_lineage(cell) == MatterLineageMap.NONE, "R2P occupancy deletion retires Matter lineage")
	_check(provider != null and provider.get_collision_shape_count() == boxes_after.size(), "R2P occupancy edit rebuild installs expected merged shapes")

	var result := {
		"elapsed_us": elapsed,
		"shape_count": boxes_after.size(),
		"solid_count": volume.count_solid(),
	}
	space.free()
	return result


func _measure_split_case(world: Node3D, extent: int) -> void:
	var request_samples: Array[float] = []
	var commit_samples: Array[float] = []
	var occupied := 0
	var successor_shapes := 0
	var successor_count := 0

	for _sample in range(TIMING_SAMPLES):
		var volume := _make_split_volume(extent)
		var lineage := _make_lineage(volume)
		occupied = volume.count_solid()
		var space := LocalMatterSpace.new()
		space.dynamic_gravity_scale = 0.0
		space.dynamic_can_sleep = false
		world.add_child(space)
		space.initialize_dynamic(volume, lineage, Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO)

		var started := Time.get_ticks_usec()
		var accepted := space.request_connected_component_split()
		request_samples.append(float(Time.get_ticks_usec() - started))
		_check(accepted, "R2P disconnected split request accepted")
		if not accepted:
			space.free()
			continue

		started = Time.get_ticks_usec()
		space._commit_connected_component_split()
		commit_samples.append(float(Time.get_ticks_usec() - started))
		var result := space.get_last_split_result()
		_check(result != null, "R2P split publishes result")
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
				successor.free()
		space.free()

	print(
		"R2P_SPLIT extent=%d scanned=%d occupied=%d successors=%d successor_shapes=%d request_preflight_us=%.1f commit_transaction_us=%.1f synchronous_split_work_us=%.1f"
		% [
			extent,
			extent * extent * extent,
			occupied,
			successor_count,
			successor_shapes,
			_median(request_samples),
			_median(commit_samples),
			_median(request_samples) + _median(commit_samples),
		]
	)
	_check(successor_count == 2, "R2P split creates two successors")
	_check(successor_shapes > 0 and successor_shapes < occupied, "R2P split successors retain merged collision compression")


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
			assert(false, "Unknown R2P pattern")
	return volume


func _make_split_volume(extent: int) -> CellVolume:
	var size := Vector3i(extent, extent, extent)
	var volume := CellVolume.new(size)
	var gap_x := extent / 2
	volume.fill_box(Vector3i.ZERO, Vector3i(gap_x, extent, extent), CellVolume.SOLID)
	volume.fill_box(Vector3i(gap_x + 1, 0, 0), size, CellVolume.SOLID)
	return volume


func _edit_cell(extent: int, pattern: String) -> Vector3i:
	var mid := extent / 2
	match pattern:
		"dense":
			return Vector3i(mid, mid, mid)
		"shell":
			return Vector3i(0, mid, mid)
		"skeleton":
			return Vector3i(mid, mid, 0)
	return Vector3i.ZERO


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


func _mesh_vertex_count(volume: CellVolume) -> int:
	var mesh := CellMesher.build_mesh(volume)
	if mesh.get_surface_count() == 0:
		return 0
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _finish(world: Node3D) -> void:
	world.free()
	if _failures.is_empty():
		print("R2P_POST_AGGREGATION_PROFILE_PASS: promoted merged-collision costs were decomposed without selecting or implementing the next optimization.")
		quit(0)
		return
	for failure in _failures:
		push_error("R2P_POST_AGGREGATION_PROFILE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
