extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	_run_known_geometry_cases()
	_run_mutation_stability_case()
	_run_performance_probe()

	if _failures.is_empty():
		print("G0_CAMPAIGN_PASS: correctness, mutation stability, and baseline performance probes completed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("G0_CAMPAIGN_FAIL: " + failure)
		quit(1)


func _run_known_geometry_cases() -> void:
	var isolated := CellVolume.new(Vector3i(4, 4, 4))
	isolated.set_cell(Vector3i(1, 1, 1), CellVolume.SOLID)
	_check(CellMesher.count_exposed_faces(isolated) == 6, "isolated cell face ground truth")
	_check(_mesh_vertex_count(isolated) == 36, "isolated cell vertex ground truth")

	var pair := CellVolume.new(Vector3i(4, 4, 4))
	pair.set_cell(Vector3i(1, 1, 1), CellVolume.SOLID)
	pair.set_cell(Vector3i(2, 1, 1), CellVolume.SOLID)
	_check(CellMesher.count_exposed_faces(pair) == 10, "adjacent pair face ground truth")
	_check(_mesh_vertex_count(pair) == 60, "adjacent pair vertex ground truth")

	var cube := CellVolume.new(Vector3i(4, 4, 4))
	cube.fill_box(Vector3i.ZERO, Vector3i(4, 4, 4), CellVolume.SOLID)
	_check(cube.count_solid() == 64, "4^3 cube solid-cell ground truth")
	_check(CellMesher.count_exposed_faces(cube) == 96, "4^3 cube surface-face ground truth")
	_check(_mesh_vertex_count(cube) == 576, "4^3 cube vertex ground truth")

	var representation := MatterRepresentation.new()
	get_root().add_child(representation)
	representation.set_volume(cube)
	var expected_collision_count := CellCollisionBoxer.build_boxes(cube, representation.collision_mode).size()
	_check(representation.get_collision_shape_count() == expected_collision_count, "collision count matches active compiled representation")
	_check(representation.get_mesh_vertex_count() == 576, "derived representation matches known cube")
	representation.free()


func _run_mutation_stability_case() -> void:
	var volume := CellVolume.new(Vector3i(8, 8, 8))
	var representation := MatterRepresentation.new()
	get_root().add_child(representation)
	representation.set_volume(volume)

	var rng := RandomNumberGenerator.new()
	rng.seed = 61453

	for step in range(500):
		var cell := Vector3i(
			rng.randi_range(0, volume.size.x - 1),
			rng.randi_range(0, volume.size.y - 1),
			rng.randi_range(0, volume.size.z - 1)
		)
		var material_id := CellVolume.SOLID
		if volume.get_cell(cell) != CellVolume.EMPTY:
			material_id = CellVolume.EMPTY
		volume.set_cell(cell, material_id)

		if step % 10 == 0 or step == 499:
			representation.rebuild()
			var expected_faces := CellMesher.count_exposed_faces(volume)
			var expected_collision_count := CellCollisionBoxer.build_boxes(volume, representation.collision_mode).size()
			_check(
				representation.get_collision_shape_count() == expected_collision_count,
				"mutation step %d collision count" % step
			)
			_check(
				representation.get_mesh_vertex_count() == expected_faces * 6,
				"mutation step %d mesh topology" % step
			)

	var truth_snapshot := volume.duplicate_cells()
	representation.free()

	var rebuilt := MatterRepresentation.new()
	get_root().add_child(rebuilt)
	rebuilt.set_volume(volume)
	var expected_rebuilt_collision_count := CellCollisionBoxer.build_boxes(volume, rebuilt.collision_mode).size()
	_check(volume.duplicate_cells() == truth_snapshot, "destroy/rebuild preserves logical truth after 500 mutations")
	_check(rebuilt.get_collision_shape_count() == expected_rebuilt_collision_count, "post-stress collision regeneration")
	_check(rebuilt.get_mesh_vertex_count() == CellMesher.count_exposed_faces(volume) * 6, "post-stress mesh regeneration")
	rebuilt.free()


func _run_performance_probe() -> void:
	for edge in [4, 8, 12]:
		var volume := CellVolume.new(Vector3i(edge, edge, edge))
		volume.fill_box(Vector3i.ZERO, Vector3i(edge, edge, edge), CellVolume.SOLID)

		var mesh_started := Time.get_ticks_usec()
		var mesh := CellMesher.build_mesh(volume)
		var mesh_usec := Time.get_ticks_usec() - mesh_started
		var vertex_count := 0
		if mesh.get_surface_count() > 0:
			vertex_count = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()

		var representation := MatterRepresentation.new()
		get_root().add_child(representation)
		representation.set_volume(volume)
		print(
			"G0_METRIC edge=%d cells=%d faces=%d vertices=%d mesh_us=%d representation_us=%d collision_shapes=%d"
			% [
				edge,
				volume.count_solid(),
				CellMesher.count_exposed_faces(volume),
				vertex_count,
				mesh_usec,
				representation.last_rebuild_usec,
				representation.get_collision_shape_count(),
			]
		)
		representation.free()


func _mesh_vertex_count(volume: CellVolume) -> int:
	var mesh := CellMesher.build_mesh(volume)
	if mesh.get_surface_count() == 0:
		return 0
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
