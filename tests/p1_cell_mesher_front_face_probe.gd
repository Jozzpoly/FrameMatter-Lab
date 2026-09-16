extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var reference := BoxMesh.new()
	reference.size = Vector3.ONE
	var reference_stats := _orientation_stats(reference)
	_check(int(reference_stats.get("triangles", 0)) > 0, "built-in BoxMesh exposes triangle orientation reference")
	_check(int(reference_stats.get("mixed", 1)) == 0, "built-in BoxMesh has one consistent front-face orientation relative to authored normals")

	var volume := CellVolume.new(Vector3i.ONE)
	_check(volume.set_cell(Vector3i.ZERO, CellVolume.SOLID), "single-cell Matter fixture becomes solid")
	var matter_mesh := CellMesher.build_mesh(volume)
	var matter_stats := _orientation_stats(matter_mesh)
	_check(int(matter_stats.get("triangles", 0)) == 12, "single-cell Matter emits exactly twelve triangles")
	_check(int(matter_stats.get("mixed", 1)) == 0, "CellMesher triangles have one consistent orientation relative to authored normals")

	var reference_sign := int(reference_stats.get("sign", 0))
	var matter_sign := int(matter_stats.get("sign", 0))
	_check(reference_sign != 0, "built-in BoxMesh orientation reference is non-degenerate")
	_check(matter_sign == reference_sign, "CellMesher front-face ordering matches Godot built-in BoxMesh convention")

	print(
		"P1_CELL_MESHER_FRONT_FACE_STATS: reference_triangles=%d reference_sign=%d matter_triangles=%d matter_sign=%d" % [
			int(reference_stats.get("triangles", 0)),
			reference_sign,
			int(matter_stats.get("triangles", 0)),
			matter_sign,
		]
	)
	_finish()


func _orientation_stats(mesh: Mesh) -> Dictionary:
	if mesh == null or mesh.get_surface_count() == 0:
		return {"triangles": 0, "sign": 0, "mixed": 1}
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var positive := 0
	var negative := 0
	var degenerate := 0
	var triangle_count := 0
	var index_count := indices.size() if not indices.is_empty() else vertices.size()
	for offset in range(0, index_count, 3):
		if offset + 2 >= index_count:
			break
		var ia := int(indices[offset]) if not indices.is_empty() else offset
		var ib := int(indices[offset + 1]) if not indices.is_empty() else offset + 1
		var ic := int(indices[offset + 2]) if not indices.is_empty() else offset + 2
		var a: Vector3 = vertices[ia]
		var b: Vector3 = vertices[ib]
		var c: Vector3 = vertices[ic]
		var geometric := (b - a).cross(c - a)
		var authored := (normals[ia] + normals[ib] + normals[ic]) / 3.0
		if geometric.length_squared() <= 0.00000001 or authored.length_squared() <= 0.00000001:
			degenerate += 1
			continue
		var dot := geometric.normalized().dot(authored.normalized())
		if dot > 0.99:
			positive += 1
		elif dot < -0.99:
			negative += 1
		else:
			degenerate += 1
		triangle_count += 1
	var sign := 1 if positive > 0 and negative == 0 and degenerate == 0 else (-1 if negative > 0 and positive == 0 and degenerate == 0 else 0)
	return {
		"triangles": triangle_count,
		"positive": positive,
		"negative": negative,
		"degenerate": degenerate,
		"sign": sign,
		"mixed": 0 if sign != 0 else 1,
	}


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_CELL_MESHER_FRONT_FACE_PASS: procedural Matter triangles match Godot built-in front-face orientation relative to authored outward normals.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CELL_MESHER_FRONT_FACE_FAIL: " + failure)
	quit(1)
