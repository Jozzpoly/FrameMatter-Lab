extends SceneTree

const EDGE := 8
const REPEATS := 3
const EDIT_CELL := Vector3i(8, 0, 8)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads for chunked presentation feasibility")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(4)
	var world := root.call("get_recovery_world_space") as LocalMatterSpace
	_check(world != null and world.volume != null, "presentation feasibility resolves canonical WORLD")
	if world == null or world.volume == null:
		_finish(root)
		return

	var volume := world.volume
	_compare_exact_segment_sets("before", volume)
	var edited := _copy_volume(volume)
	_check(edited.get_cell(EDIT_CELL) != CellVolume.EMPTY, "edited presentation fixture starts occupied")
	edited.set_cell(EDIT_CELL, CellVolume.EMPTY)
	_compare_exact_segment_sets("after", edited)

	var dirty_origins := _dirty_origins(volume.size, EDIT_CELL)
	var full_grid_us := _measure(func() -> void: P1MatterSurfaceGrid.build_exposed_surface_grid(volume))
	var dirty_grid_us := _measure(func() -> void:
		for origin in dirty_origins:
			_build_grid_region(volume, origin, _chunk_end(volume.size, origin))
	)
	var full_state_us := _measure(func() -> void: P1MatterStatePresentation.build_side_surface_contour(volume))
	var dirty_state_us := _measure(func() -> void:
		for origin in dirty_origins:
			_build_state_region(volume, origin, _chunk_end(volume.size, origin))
	)
	var full_focus_us := _measure(func() -> void: P1MatterStatePresentation.build_top_surface_perimeter(volume))
	var dirty_focus_us := _measure(func() -> void:
		for origin in dirty_origins:
			_build_focus_region(volume, origin, _chunk_end(volume.size, origin))
	)

	print(
		"P1_CHUNKED_PRESENTATION_FEASIBILITY_METRIC edge=%d chunks=%d dirty_chunks=%d full_grid_us=%d dirty_grid_us=%d full_state_us=%d dirty_state_us=%d full_focus_us=%d dirty_focus_us=%d"
		% [
			EDGE,
			_chunk_origins(volume.size).size(),
			dirty_origins.size(),
			full_grid_us,
			dirty_grid_us,
			full_state_us,
			dirty_state_us,
			full_focus_us,
			dirty_focus_us,
		]
	)
	_finish(root)


func _compare_exact_segment_sets(label: String, volume: CellVolume) -> void:
	var full_grid := _segment_set(P1MatterSurfaceGrid.build_exposed_surface_grid(volume))
	var full_state := _segment_set(P1MatterStatePresentation.build_side_surface_contour(volume))
	var full_focus := _segment_set(P1MatterStatePresentation.build_top_surface_perimeter(volume))

	var chunk_grid: Dictionary = {}
	var chunk_state: Dictionary = {}
	var chunk_focus: Dictionary = {}
	var duplicate_grid := 0
	var duplicate_state := 0
	var duplicate_focus := 0
	for origin in _chunk_origins(volume.size):
		var end := _chunk_end(volume.size, origin)
		duplicate_grid += _merge_segments(chunk_grid, _segment_set(_build_grid_region(volume, origin, end)))
		duplicate_state += _merge_segments(chunk_state, _segment_set(_build_state_region(volume, origin, end)))
		duplicate_focus += _merge_segments(chunk_focus, _segment_set(_build_focus_region(volume, origin, end)))

	_check(duplicate_grid == 0, "%s chunk grid emits no duplicate global segments" % label)
	_check(duplicate_state == 0, "%s chunk state contour emits no duplicate global segments" % label)
	_check(duplicate_focus == 0, "%s chunk focus crown emits no duplicate global segments" % label)
	_check(_same_keys(full_grid, chunk_grid), "%s chunk grid segment set exactly equals whole-volume production grid" % label)
	_check(_same_keys(full_state, chunk_state), "%s chunk state segment set exactly equals whole-volume production contour" % label)
	_check(_same_keys(full_focus, chunk_focus), "%s chunk focus segment set exactly equals whole-volume production crown" % label)


func _build_grid_region(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var emitted := false
	var seen: Dictionary = {}
	var scan_from := _scan_from(from_cell)
	var scan_to := _scan_to(volume.size, to_cell)

	for z in range(scan_from.z, scan_to.z):
		for y in range(scan_from.y, scan_to.y):
			for x in range(scan_from.x, scan_to.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var cell_origin := Vector3(cell)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var face_vertices: Array = CellMesher.FACE_VERTICES[face_index]
					var normal: Vector3 = CellMesher.FACE_NORMALS[face_index]
					var corners := [
						cell_origin + face_vertices[0],
						cell_origin + face_vertices[1],
						cell_origin + face_vertices[2],
						cell_origin + face_vertices[5],
					]
					for edge_index in range(4):
						var a: Vector3 = corners[edge_index]
						var b: Vector3 = corners[(edge_index + 1) % 4]
						var key := _oriented_edge_key(face_index, a, b)
						if seen.has(key):
							continue
						seen[key] = cell
						if not _cell_in_region(cell, from_cell, to_cell):
							continue
						var offset := normal * P1MatterSurfaceGrid.SURFACE_OFFSET
						surface.add_vertex(a + offset)
						surface.add_vertex(b + offset)
						emitted = true
	if not emitted:
		return mesh
	return surface.commit(mesh)


func _build_state_region(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var records: Dictionary = {}
	var scan_from := _scan_from(from_cell)
	var scan_to := _scan_to(volume.size, to_cell)

	for z in range(scan_from.z, scan_to.z):
		for y in range(scan_from.y, scan_to.y):
			for x in range(scan_from.x, scan_to.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var origin := Vector3(cell)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					var normal: Vector3 = CellMesher.FACE_NORMALS[face_index]
					if absf(normal.dot(Vector3.UP)) > 0.01:
						continue
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var corners := _face_corners(origin, face_index)
					for edge_index in range(4):
						var a: Vector3 = corners[edge_index]
						var b: Vector3 = corners[(edge_index + 1) % 4]
						var key := _oriented_edge_key(face_index, a, b)
						if not records.has(key):
							records[key] = {"count": 0, "a": a, "b": b, "face": face_index, "owner": cell}
						var record: Dictionary = records[key]
						record["count"] = int(record["count"]) + 1
						records[key] = record

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var emitted := false
	for record_variant in records.values():
		var record: Dictionary = record_variant
		if int(record["count"]) != 1:
			continue
		var owner: Vector3i = record["owner"]
		if not _cell_in_region(owner, from_cell, to_cell):
			continue
		var normal: Vector3 = CellMesher.FACE_NORMALS[int(record["face"])]
		surface.add_vertex(Vector3(record["a"]) + normal * P1MatterStatePresentation.CONTOUR_OFFSET)
		surface.add_vertex(Vector3(record["b"]) + normal * P1MatterStatePresentation.CONTOUR_OFFSET)
		emitted = true
	if not emitted:
		return mesh
	return surface.commit(mesh)


func _build_focus_region(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var records: Dictionary = {}
	var scan_from := _scan_from(from_cell)
	var scan_to := _scan_to(volume.size, to_cell)

	for z in range(scan_from.z, scan_to.z):
		for y in range(scan_from.y, scan_to.y):
			for x in range(scan_from.x, scan_to.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var origin := Vector3(cell)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					var normal: Vector3 = CellMesher.FACE_NORMALS[face_index]
					if normal.dot(Vector3.UP) < 0.99:
						continue
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var corners := _face_corners(origin, face_index)
					for edge_index in range(4):
						var a: Vector3 = corners[edge_index]
						var b: Vector3 = corners[(edge_index + 1) % 4]
						var key := _plain_edge_key(a, b)
						if not records.has(key):
							records[key] = {"count": 0, "a": a, "b": b, "owner": cell}
						var record: Dictionary = records[key]
						record["count"] = int(record["count"]) + 1
						records[key] = record

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var emitted := false
	for record_variant in records.values():
		var record: Dictionary = record_variant
		if int(record["count"]) != 1:
			continue
		var owner: Vector3i = record["owner"]
		if not _cell_in_region(owner, from_cell, to_cell):
			continue
		surface.add_vertex(Vector3(record["a"]) + Vector3.UP * P1MatterStatePresentation.FOCUS_CROWN_OFFSET)
		surface.add_vertex(Vector3(record["b"]) + Vector3.UP * P1MatterStatePresentation.FOCUS_CROWN_OFFSET)
		emitted = true
	if not emitted:
		return mesh
	return surface.commit(mesh)


func _segment_set(mesh: ArrayMesh) -> Dictionary:
	var result: Dictionary = {}
	if mesh == null:
		return result
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		_check(vertices.size() % 2 == 0, "line mesh has paired vertices")
		for index in range(0, vertices.size(), 2):
			result[_segment_geometry_key(vertices[index], vertices[index + 1])] = true
	return result


func _merge_segments(target: Dictionary, source: Dictionary) -> int:
	var duplicates := 0
	for key in source.keys():
		if target.has(key):
			duplicates += 1
		target[key] = true
	return duplicates


func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key):
			return false
	return true


func _segment_geometry_key(a: Vector3, b: Vector3) -> String:
	var ak := _point_key(a)
	var bk := _point_key(b)
	return "%s|%s" % [ak, bk] if ak < bk else "%s|%s" % [bk, ak]


func _point_key(value: Vector3) -> String:
	return "%.5f,%.5f,%.5f" % [value.x, value.y, value.z]


func _face_corners(origin: Vector3, face_index: int) -> Array:
	var face_vertices: Array = CellMesher.FACE_VERTICES[face_index]
	return [
		origin + face_vertices[0],
		origin + face_vertices[1],
		origin + face_vertices[2],
		origin + face_vertices[5],
	]


func _oriented_edge_key(face_index: int, a: Vector3, b: Vector3) -> String:
	return "%d|%s" % [face_index, _plain_edge_key(a, b)]


func _plain_edge_key(a: Vector3, b: Vector3) -> String:
	var ai := Vector3i(int(a.x), int(a.y), int(a.z))
	var bi := Vector3i(int(b.x), int(b.y), int(b.z))
	if _vector3i_less(bi, ai):
		var swap := ai
		ai = bi
		bi = swap
	return "%d,%d,%d|%d,%d,%d" % [ai.x, ai.y, ai.z, bi.x, bi.y, bi.z]


func _vector3i_less(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z


func _chunk_origins(size: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(0, size.z, EDGE):
		for y in range(0, size.y, EDGE):
			for x in range(0, size.x, EDGE):
				result.append(Vector3i(x, y, z))
	return result


func _dirty_origins(size: Vector3i, cell: Vector3i) -> Array[Vector3i]:
	var unique: Dictionary = {}
	var candidates: Array[Vector3i] = [cell]
	for offset in MatterTopology.AXIAL_NEIGHBORS:
		var neighbor := cell + offset
		if (
			neighbor.x >= 0 and neighbor.x < size.x
			and neighbor.y >= 0 and neighbor.y < size.y
			and neighbor.z >= 0 and neighbor.z < size.z
		):
			candidates.append(neighbor)
	for candidate in candidates:
		unique[_chunk_origin(candidate)] = true
	var result: Array[Vector3i] = []
	for origin_variant in unique.keys():
		result.append(origin_variant)
	return result


func _chunk_origin(cell: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(cell.x) / float(EDGE)) * EDGE,
		floori(float(cell.y) / float(EDGE)) * EDGE,
		floori(float(cell.z) / float(EDGE)) * EDGE
	)


func _chunk_end(size: Vector3i, origin: Vector3i) -> Vector3i:
	return Vector3i(
		mini(size.x, origin.x + EDGE),
		mini(size.y, origin.y + EDGE),
		mini(size.z, origin.z + EDGE)
	)


func _scan_from(origin: Vector3i) -> Vector3i:
	return Vector3i(maxi(0, origin.x - 1), maxi(0, origin.y - 1), maxi(0, origin.z - 1))


func _scan_to(size: Vector3i, end: Vector3i) -> Vector3i:
	return Vector3i(mini(size.x, end.x + 1), mini(size.y, end.y + 1), mini(size.z, end.z + 1))


func _cell_in_region(cell: Vector3i, from_cell: Vector3i, to_cell: Vector3i) -> bool:
	return (
		cell.x >= from_cell.x and cell.x < to_cell.x
		and cell.y >= from_cell.y and cell.y < to_cell.y
		and cell.z >= from_cell.z and cell.z < to_cell.z
	)


func _copy_volume(source: CellVolume) -> CellVolume:
	var result := CellVolume.new(source.size)
	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var cell := Vector3i(x, y, z)
				var material_id := source.get_cell(cell)
				if material_id != CellVolume.EMPTY:
					result.set_cell(cell, material_id)
	result.revision = source.revision
	return result


func _measure(callback: Callable) -> int:
	var values: Array[int] = []
	for _iteration in range(REPEATS):
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
		print("P1_CHUNKED_PRESENTATION_FEASIBILITY_PASS: edge-8 halo/ownership chunks preserve exact global grid, state-contour and focus-crown segment sets before and after a local edit while exposing bounded dirty-region costs.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CHUNKED_PRESENTATION_FEASIBILITY_FAIL: " + failure)
	quit(1)
