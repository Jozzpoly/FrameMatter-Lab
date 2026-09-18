extends SceneTree

const CHUNK_EDGES: Array[int] = [4, 8, 16]
const REPEATS := 3

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads for chunk feasibility probe")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(4)

	var world := root.call("get_recovery_world_space") as LocalMatterSpace
	_check(world != null and world.volume != null, "chunk probe resolves canonical Recovery WORLD Matter")
	if world == null or world.volume == null:
		_finish(root)
		return

	var volume := world.volume
	var edit_cell: Vector3i = root.call("get_recovery_causal_bridge_cell_for_test")
	_check(volume.in_bounds(edit_cell) and volume.get_cell(edit_cell) != CellVolume.EMPTY, "dirty-cell fixture is occupied canonical Matter")

	var full_mesh := CellMesher.build_mesh(volume)
	var full_vertices := _mesh_vertex_count(full_mesh)
	var full_faces := CellMesher.count_exposed_faces(volume)
	var full_boxes: Array[Dictionary] = CellCollisionBoxer.build_boxes(volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
	_check(full_vertices == full_faces * 6, "whole-volume mesh vertex count matches exposed-face contract")
	_check(CellCollisionBoxer.covered_cell_count(full_boxes) == volume.count_solid(), "whole-volume collision boxes cover every occupied cell")

	var full_mesh_us := _measure(func() -> void: CellMesher.build_mesh(volume))
	var full_boxes_us := _measure(func() -> void: CellCollisionBoxer.build_boxes(volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS))

	for edge in CHUNK_EDGES:
		var origins := _chunk_origins(volume.size, edge)
		var dirty_mesh_origins := _dirty_mesh_chunk_origins(volume.size, edit_cell, edge)
		var dirty_collision_origin := _chunk_origin(edit_cell, edge)

		var chunk_face_count := 0
		var chunk_vertex_count := 0
		var chunk_box_count := 0
		var collision_coverage: Dictionary = {}
		var duplicate_collision_cells := 0

		for origin in origins:
			var end := _chunk_end(volume.size, origin, edge)
			chunk_face_count += _count_exposed_faces_region(volume, origin, end)
			var mesh := _build_mesh_region(volume, origin, end)
			chunk_vertex_count += _mesh_vertex_count(mesh)

			var collision := _build_collision_chunk(volume, origin, end)
			var boxes: Array = collision["boxes"]
			chunk_box_count += boxes.size()
			for box_variant in boxes:
				var box: Dictionary = box_variant
				var local_origin: Vector3i = box["origin"]
				var box_size: Vector3i = box["size"]
				for z in range(local_origin.z, local_origin.z + box_size.z):
					for y in range(local_origin.y, local_origin.y + box_size.y):
						for x in range(local_origin.x, local_origin.x + box_size.x):
							var global_cell := origin + Vector3i(x, y, z)
							if collision_coverage.has(global_cell):
								duplicate_collision_cells += 1
							collision_coverage[global_cell] = true

		_check(chunk_face_count == full_faces, "edge %d chunk union preserves exact exposed-face cardinality" % edge)
		_check(chunk_vertex_count == full_vertices, "edge %d chunk mesh union preserves exact mesh vertex cardinality" % edge)
		_check(duplicate_collision_cells == 0, "edge %d chunk collision coverage never overlaps cells" % edge)
		_check(collision_coverage.size() == volume.count_solid(), "edge %d chunk collision covers exact occupied cardinality" % edge)
		for z in range(volume.size.z):
			for y in range(volume.size.y):
				for x in range(volume.size.x):
					var cell := Vector3i(x, y, z)
					var occupied := volume.get_cell(cell) != CellVolume.EMPTY
					_check(
						collision_coverage.has(cell) == occupied,
						"edge %d chunk collision occupancy matches WORLD at %s" % [edge, str(cell)]
					)

		var all_mesh_us := _measure(func() -> void: _build_mesh_chunks(volume, origins, edge))
		var all_boxes_us := _measure(func() -> void: _build_collision_chunks(volume, origins, edge))
		var dirty_mesh_us := _measure(func() -> void: _build_mesh_chunks(volume, dirty_mesh_origins, edge))
		var dirty_boxes_us := _measure(func() -> void:
			_build_collision_chunk(volume, dirty_collision_origin, _chunk_end(volume.size, dirty_collision_origin, edge))
		)

		print(
			"P1_CHUNKED_PROVIDER_FEASIBILITY_METRIC edge=%d chunks=%d dirty_mesh_chunks=%d full_mesh_us=%d full_boxes_us=%d all_chunk_mesh_us=%d all_chunk_boxes_us=%d dirty_chunk_mesh_us=%d dirty_chunk_boxes_us=%d full_boxes=%d chunk_boxes=%d box_inflation=%.3f faces=%d vertices=%d"
			% [
				edge,
				origins.size(),
				dirty_mesh_origins.size(),
				full_mesh_us,
				full_boxes_us,
				all_mesh_us,
				all_boxes_us,
				dirty_mesh_us,
				dirty_boxes_us,
				full_boxes.size(),
				chunk_box_count,
				float(chunk_box_count) / float(maxi(1, full_boxes.size())),
				full_faces,
				full_vertices,
			]
		)

	_finish(root)


func _build_mesh_chunks(volume: CellVolume, origins: Array[Vector3i], edge: int) -> void:
	for origin in origins:
		_build_mesh_region(volume, origin, _chunk_end(volume.size, origin, edge))


func _build_collision_chunks(volume: CellVolume, origins: Array[Vector3i], edge: int) -> void:
	for origin in origins:
		_build_collision_chunk(volume, origin, _chunk_end(volume.size, origin, edge))


func _build_mesh_region(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var emitted := false

	for z in range(from_cell.z, to_cell.z):
		for y in range(from_cell.y, to_cell.y):
			for x in range(from_cell.x, to_cell.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var origin := Vector3(cell)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var face_vertices: Array = CellMesher.FACE_VERTICES[face_index]
					for triangle_start in [0, 3]:
						for local_index in CellMesher.TRIANGLE_FRONT_ORDER:
							surface.set_normal(CellMesher.FACE_NORMALS[face_index])
							surface.add_vertex(origin + Vector3(face_vertices[triangle_start + local_index]))
							emitted = true

	if not emitted:
		return mesh
	return surface.commit(mesh)


func _count_exposed_faces_region(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i) -> int:
	var count := 0
	for z in range(from_cell.z, to_cell.z):
		for y in range(from_cell.y, to_cell.y):
			for x in range(from_cell.x, to_cell.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				for direction in CellMesher.FACE_DIRECTIONS:
					if volume.get_cell(cell + direction) == CellVolume.EMPTY:
						count += 1
	return count


func _build_collision_chunk(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i) -> Dictionary:
	var chunk_size := to_cell - from_cell
	var local := CellVolume.new(chunk_size)
	for z in range(chunk_size.z):
		for y in range(chunk_size.y):
			for x in range(chunk_size.x):
				var global_cell := from_cell + Vector3i(x, y, z)
				var material_id := volume.get_cell(global_cell)
				if material_id != CellVolume.EMPTY:
					local.set_cell(Vector3i(x, y, z), material_id)
	var boxes: Array[Dictionary] = CellCollisionBoxer.build_boxes(local, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
	return {"boxes": boxes, "volume": local}


func _chunk_origins(size: Vector3i, edge: int) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(0, size.z, edge):
		for y in range(0, size.y, edge):
			for x in range(0, size.x, edge):
				result.append(Vector3i(x, y, z))
	return result


func _dirty_mesh_chunk_origins(size: Vector3i, edited_cell: Vector3i, edge: int) -> Array[Vector3i]:
	var unique: Dictionary = {}
	var candidates: Array[Vector3i] = [edited_cell]
	for offset in MatterTopology.AXIAL_NEIGHBORS:
		var neighbor := edited_cell + offset
		if (
			neighbor.x >= 0 and neighbor.x < size.x
			and neighbor.y >= 0 and neighbor.y < size.y
			and neighbor.z >= 0 and neighbor.z < size.z
		):
			candidates.append(neighbor)
	for cell in candidates:
		var origin := _chunk_origin(cell, edge)
		unique[origin] = true
	var result: Array[Vector3i] = []
	for origin_variant in unique.keys():
		result.append(origin_variant)
	return result


func _chunk_origin(cell: Vector3i, edge: int) -> Vector3i:
	return Vector3i(
		floori(float(cell.x) / float(edge)) * edge,
		floori(float(cell.y) / float(edge)) * edge,
		floori(float(cell.z) / float(edge)) * edge
	)


func _chunk_end(size: Vector3i, origin: Vector3i, edge: int) -> Vector3i:
	return Vector3i(
		mini(size.x, origin.x + edge),
		mini(size.y, origin.y + edge),
		mini(size.z, origin.z + edge)
	)


func _mesh_vertex_count(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var arrays := mesh.surface_get_arrays(0)
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func _measure(callback: Callable) -> int:
	var values: Array[int] = []
	for _i in range(REPEATS):
		var started := Time.get_ticks_usec()
		callback.call()
		values.append(Time.get_ticks_usec() - started)
	values.sort()
	return values[values.size() / 2]


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(root: Node) -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	if _failures.is_empty():
		print("P1_CHUNKED_PROVIDER_FEASIBILITY_PASS: fixed-grid chunk candidates preserve exact exposed mesh faces and exact non-overlapping collision occupancy while exposing full-build, dirty-local and collision-box inflation costs.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CHUNKED_PROVIDER_FEASIBILITY_FAIL: " + failure)
	quit(1)
