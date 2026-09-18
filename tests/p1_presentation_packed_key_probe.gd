extends SceneTree

const EDGE := 8
const REPEATS := 5

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads for presentation key benchmark")
	if packed == null:
		_finish(null)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(4)
	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	_check(world != null and world.volume != null, "presentation key benchmark resolves WORLD")
	if world == null or world.volume == null:
		_finish(root)
		return

	var bridge: Vector3i = root.call("get_recovery_causal_bridge_cell_for_test")
	var bridge_after := world.volume.duplicate_volume()
	var bridge_lineage := world.lineage.duplicate_map()
	bridge_after.set_cell(bridge, CellVolume.EMPTY)
	bridge_lineage.clear_lineage(bridge)

	var anchors: Dictionary = {}
	for anchor in [Vector3i(1, 0, 1), Vector3i(30, 0, 1), Vector3i(1, 0, 30), Vector3i(30, 0, 30)]:
		var token := bridge_lineage.get_lineage(anchor)
		if token != MatterLineageMap.NONE:
			anchors[token] = true
	var policy := W0AnchoredDetachmentPolicy.evaluate(bridge_after, bridge_lineage, anchors)
	_check(bool(policy.get("valid", false)), "full reference policy resolves bridge source")
	var detached: Array = policy.get("detached_components", [])
	_check(detached.size() == 1 and (detached[0] as Array).size() == 36, "bridge source has exact 36-cell detached shelf")
	if detached.size() != 1:
		_finish(root)
		return

	var source_after := bridge_after.duplicate_volume()
	var transferred: Array[Vector3i] = []
	for candidate in detached[0]:
		var cell: Vector3i = candidate
		transferred.append(cell)
		source_after.set_cell(cell, CellVolume.EMPTY)

	var bridge_origins := _dirty_origins(bridge_after.size, [bridge])
	var source_origins := _dirty_origins(source_after.size, transferred)
	_check(bridge_origins.size() > 0 and source_origins.size() > 0, "dirty region sets are non-empty")

	_compare_region_union("bridge_grid", bridge_after, bridge_origins, "grid")
	_compare_region_union("bridge_state", bridge_after, bridge_origins, "state")
	_compare_region_union("bridge_focus", bridge_after, bridge_origins, "focus")
	_compare_region_union("source_grid", source_after, source_origins, "grid")
	_compare_region_union("source_state", source_after, source_origins, "state")

	var bridge_grid_string := _measure(func() -> void: _build_production_regions(bridge_after, bridge_origins, "grid"))
	var bridge_grid_packed := _measure(func() -> void: _build_packed_regions(bridge_after, bridge_origins, "grid"))
	var bridge_state_string := _measure(func() -> void: _build_production_regions(bridge_after, bridge_origins, "state"))
	var bridge_state_packed := _measure(func() -> void: _build_packed_regions(bridge_after, bridge_origins, "state"))
	var bridge_focus_string := _measure(func() -> void: _build_production_regions(bridge_after, bridge_origins, "focus"))
	var bridge_focus_packed := _measure(func() -> void: _build_packed_regions(bridge_after, bridge_origins, "focus"))
	var source_grid_string := _measure(func() -> void: _build_production_regions(source_after, source_origins, "grid"))
	var source_grid_packed := _measure(func() -> void: _build_packed_regions(source_after, source_origins, "grid"))
	var source_state_string := _measure(func() -> void: _build_production_regions(source_after, source_origins, "state"))
	var source_state_packed := _measure(func() -> void: _build_packed_regions(source_after, source_origins, "state"))

	print(
		"P1_PRESENTATION_PACKED_KEY_METRIC bridge_chunks=%d source_chunks=%d bridge_grid_string_us=%d bridge_grid_packed_us=%d bridge_state_string_us=%d bridge_state_packed_us=%d bridge_focus_string_us=%d bridge_focus_packed_us=%d source_grid_string_us=%d source_grid_packed_us=%d source_state_string_us=%d source_state_packed_us=%d"
		% [
			bridge_origins.size(),
			source_origins.size(),
			bridge_grid_string,
			bridge_grid_packed,
			bridge_state_string,
			bridge_state_packed,
			bridge_focus_string,
			bridge_focus_packed,
			source_grid_string,
			source_grid_packed,
			source_state_string,
			source_state_packed,
		]
	)
	_finish(root)


func _compare_region_union(label: String, volume: CellVolume, origins: Array[Vector3i], kind: String) -> void:
	var production: Dictionary = {}
	var packed: Dictionary = {}
	for origin in origins:
		var end := _chunk_end(volume.size, origin)
		_merge_segments(production, _segment_set(_production_region(volume, origin, end, kind)))
		_merge_segments(packed, _segment_set(_packed_region(volume, origin, end, kind)))
	_check(_same_keys(production, packed), "%s packed keys preserve exact segment geometry" % label)


func _build_production_regions(volume: CellVolume, origins: Array[Vector3i], kind: String) -> void:
	for origin in origins:
		_production_region(volume, origin, _chunk_end(volume.size, origin), kind)


func _build_packed_regions(volume: CellVolume, origins: Array[Vector3i], kind: String) -> void:
	for origin in origins:
		_packed_region(volume, origin, _chunk_end(volume.size, origin), kind)


func _production_region(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i, kind: String) -> ArrayMesh:
	if kind == "grid":
		return P1MatterSurfaceGrid.build_exposed_surface_grid_region(volume, from_cell, to_cell)
	if kind == "state":
		return P1MatterStatePresentation.build_side_surface_contour_region(volume, from_cell, to_cell)
	return P1MatterStatePresentation.build_top_surface_perimeter_region(volume, from_cell, to_cell)


func _packed_region(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i, kind: String) -> ArrayMesh:
	if kind == "grid":
		return _packed_grid(volume, from_cell, to_cell)
	if kind == "state":
		return _packed_state(volume, from_cell, to_cell)
	return _packed_focus(volume, from_cell, to_cell)


func _packed_grid(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var seen: Dictionary = {}
	var emitted := false
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
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var face_vertices: Array = CellMesher.FACE_VERTICES[face_index]
					var normal: Vector3 = CellMesher.FACE_NORMALS[face_index]
					var corners := [
						origin + face_vertices[0],
						origin + face_vertices[1],
						origin + face_vertices[2],
						origin + face_vertices[5],
					]
					for edge_index in range(4):
						var a: Vector3 = corners[edge_index]
						var b: Vector3 = corners[(edge_index + 1) % 4]
						var key := _oriented_key(volume.size, face_index, a, b)
						if seen.has(key):
							continue
						seen[key] = true
						if not _cell_in_region(cell, from_cell, to_cell):
							continue
						var offset := normal * P1MatterSurfaceGrid.SURFACE_OFFSET
						surface.add_vertex(a + offset)
						surface.add_vertex(b + offset)
						emitted = true
	if not emitted:
		return mesh
	return surface.commit(mesh)


func _packed_state(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i) -> ArrayMesh:
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
						var key := _oriented_key(volume.size, face_index, a, b)
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


func _packed_focus(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i) -> ArrayMesh:
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
						var key := _plain_key(volume.size, a, b)
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


func _oriented_key(size: Vector3i, face_index: int, a: Vector3, b: Vector3) -> int:
	return _plain_key(size, a, b) * 6 + face_index


func _plain_key(size: Vector3i, a: Vector3, b: Vector3) -> int:
	var ai := _point_index(size, Vector3i(int(a.x), int(a.y), int(a.z)))
	var bi := _point_index(size, Vector3i(int(b.x), int(b.y), int(b.z)))
	if bi < ai:
		var swap := ai
		ai = bi
		bi = swap
	var point_count := (size.x + 1) * (size.y + 1) * (size.z + 1)
	return ai * point_count + bi


func _point_index(size: Vector3i, point: Vector3i) -> int:
	return point.x + (size.x + 1) * (point.y + (size.y + 1) * point.z)


func _dirty_origins(size: Vector3i, cells: Array[Vector3i]) -> Array[Vector3i]:
	var unique: Dictionary = {}
	for cell in cells:
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


func _face_corners(origin: Vector3, face_index: int) -> Array:
	var face_vertices: Array = CellMesher.FACE_VERTICES[face_index]
	return [
		origin + face_vertices[0],
		origin + face_vertices[1],
		origin + face_vertices[2],
		origin + face_vertices[5],
	]


func _segment_set(mesh: Mesh) -> Dictionary:
	var result: Dictionary = {}
	if mesh == null:
		return result
	for surface_index in range(mesh.get_surface_count()):
		var vertices := mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for index in range(0, vertices.size(), 2):
			var a := vertices[index]
			var b := vertices[index + 1]
			var ak := "%.5f,%.5f,%.5f" % [a.x, a.y, a.z]
			var bk := "%.5f,%.5f,%.5f" % [b.x, b.y, b.z]
			result["%s|%s" % [ak, bk] if ak < bk else "%s|%s" % [bk, ak]] = true
	return result


func _merge_segments(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = true


func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key):
			return false
	return true


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
		print("P1_PRESENTATION_PACKED_KEY_PASS: packed integer edge keys preserve exact regional grid/state/focus geometry for bridge and detached-source batches while exposing deduplication cost independently of chunk granularity.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_PRESENTATION_PACKED_KEY_FAIL: " + failure)
	quit(1)
