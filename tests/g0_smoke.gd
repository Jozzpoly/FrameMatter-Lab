extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var volume := CellVolume.new(Vector3i(4, 4, 4))
	_check(volume.count_solid() == 0, "new volume is empty")
	_check(volume.get_cell(Vector3i(-1, 0, 0)) == CellVolume.EMPTY, "out-of-bounds reads as empty")

	_check(volume.set_cell(Vector3i(1, 1, 1), CellVolume.SOLID), "first mutation changes Matter")
	_check(volume.revision == 1, "revision increments after mutation")
	_check(volume.count_solid() == 1, "solid count follows Matter")
	_check(CellMesher.count_exposed_faces(volume) == 6, "isolated cell has six exposed faces")

	volume.set_cell(Vector3i(2, 1, 1), CellVolume.SOLID)
	_check(volume.count_solid() == 2, "second adjacent cell exists")
	_check(CellMesher.count_exposed_faces(volume) == 10, "adjacent cells hide their shared faces")

	var representation := MatterRepresentation.new()
	get_root().add_child(representation)
	representation.set_volume(volume)
	_check(representation.get_collision_shape_count() == 2, "collision representation derives from Matter")
	_check(representation.get_mesh_vertex_count() == 60, "mesh representation has 10 quads / 60 vertices")

	var truth_snapshot := volume.duplicate_cells()
	representation.position = Vector3(50.0, 12.0, -30.0)
	_check(volume.duplicate_cells() == truth_snapshot, "moving representation does not mutate local Matter")

	representation.free()
	var rebuilt := MatterRepresentation.new()
	get_root().add_child(rebuilt)
	rebuilt.set_volume(volume)
	_check(rebuilt.get_collision_shape_count() == 2, "destroyed collision representation regenerates from Matter")
	_check(rebuilt.get_mesh_vertex_count() == 60, "destroyed mesh representation regenerates from Matter")

	volume.set_cell(Vector3i(2, 1, 1), CellVolume.EMPTY)
	rebuilt.rebuild()
	_check(rebuilt.get_collision_shape_count() == 1, "mutation invalidates/rebuilds collision representation")
	_check(rebuilt.get_mesh_vertex_count() == 36, "mutation invalidates/rebuilds mesh representation")
	_check(CellMesher.count_exposed_faces(volume) == 6, "logical truth remains internally consistent after mutation")

	rebuilt.free()

	if _failures.is_empty():
		print("G0_SMOKE_PASS: Matter truth and representation regeneration checks passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("G0_SMOKE_FAIL: " + failure)
		quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
