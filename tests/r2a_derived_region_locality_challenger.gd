extends SceneTree

const EXTENTS: Array[int] = [14, 24, 32]
const PATTERNS: Array[String] = ["dense", "shell", "skeleton"]
const REGION_EDGES: Array[int] = [4, 8]
const TIMING_SAMPLES := 3

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print(
		"R2A_DERIVED_REGION_BEGIN extents=%s patterns=%s region_edges=%s samples=%d"
		% [str(EXTENTS), str(PATTERNS), str(REGION_EDGES), TIMING_SAMPLES]
	)

	for extent in EXTENTS:
		for pattern in PATTERNS:
			for region_edge in REGION_EDGES:
				_measure_case(extent, pattern, region_edge)

	_finish()


func _measure_case(extent: int, pattern: String, region_edge: int) -> void:
	var source := _make_pattern_volume(extent, pattern)
	var occupied := source.count_solid()
	var global_boxes := CellCollisionBoxer.build_boxes(source, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
	var global_mesh_vertices := _global_mesh_vertex_count(source)
	var target := _select_worst_boundary_target(source, region_edge)
	_check(target.x >= 0, "R2A target exists for %s/%d/r%d" % [pattern, extent, region_edge])
	if target.x < 0:
		return

	var regional_boxes := _build_all_region_boxes(source, region_edge)
	var regional_vertices := _build_all_region_mesh_vertex_count(source, region_edge)
	var occupied_regions := _count_occupied_regions(source, region_edge)
	var render_regions := _count_render_regions(source, region_edge)
	var affected_mesh_regions := _affected_mesh_region_origins(source, target, region_edge).size()

	_check(_coverage_error_count(source, regional_boxes) == 0, "R2A regional collision exactly covers source Matter")
	_check(CellCollisionBoxer.covered_cell_count(regional_boxes) == occupied, "R2A regional collision coverage cardinality matches occupied Matter")
	_check(regional_vertices == global_mesh_vertices, "R2A regional mesh has exactly the global exposed vertex set")
	_check(regional_boxes.size() <= occupied, "R2A regional cuboids never exceed per-cell reference count")
	_check(affected_mesh_regions <= 4, "R2A one-cell edit touches at most own + three face-neighbor regions")

	var full_collision_samples: Array[float] = []
	var full_mesh_samples: Array[float] = []
	var dirty_collision_samples: Array[float] = []
	var dirty_mesh_samples: Array[float] = []

	for _sample in range(TIMING_SAMPLES):
		var timed_source := _make_pattern_volume(extent, pattern)

		var started := Time.get_ticks_usec()
		var timed_boxes := _build_all_region_boxes(timed_source, region_edge)
		full_collision_samples.append(float(Time.get_ticks_usec() - started))
		_check(timed_boxes.size() == regional_boxes.size(), "R2A full regional collision compile is deterministic")

		started = Time.get_ticks_usec()
		var timed_vertices := _build_all_region_mesh_vertex_count(timed_source, region_edge)
		full_mesh_samples.append(float(Time.get_ticks_usec() - started))
		_check(timed_vertices == global_mesh_vertices, "R2A full regional mesh compile is deterministic")

		_check(timed_source.set_cell(target, CellVolume.EMPTY), "R2A timed occupancy edit removes target Matter")

		var target_origin := _region_origin_for_cell(target, region_edge)
		started = Time.get_ticks_usec()
		var dirty_boxes := _build_region_boxes(timed_source, target_origin, region_edge)
		dirty_collision_samples.append(float(Time.get_ticks_usec() - started))
		_check(not dirty_boxes.is_empty() or _region_occupied_count(timed_source, target_origin, region_edge) == 0, "R2A dirty collision compile returns coherent edited-region output")

		var dirty_origins := _affected_mesh_region_origins(timed_source, target, region_edge)
		started = Time.get_ticks_usec()
		var dirty_vertices := 0
		for origin_variant in dirty_origins:
			var origin: Vector3i = origin_variant
			dirty_vertices += _region_mesh_vertex_count(timed_source, origin, region_edge)
		dirty_mesh_samples.append(float(Time.get_ticks_usec() - started))
		_check(dirty_vertices >= 0, "R2A dirty mesh compile completed")

	var edited := _make_pattern_volume(extent, pattern)
	_check(edited.set_cell(target, CellVolume.EMPTY), "R2A verification occupancy edit removes target Matter")
	var edited_global_boxes := CellCollisionBoxer.build_boxes(edited, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
	var edited_regional_boxes := _build_all_region_boxes(edited, region_edge)
	var edited_global_vertices := _global_mesh_vertex_count(edited)
	var edited_regional_vertices := _build_all_region_mesh_vertex_count(edited, region_edge)
	_check(_coverage_error_count(edited, edited_regional_boxes) == 0, "R2A regional collision stays exact after occupancy edit")
	_check(CellCollisionBoxer.covered_cell_count(edited_regional_boxes) == edited.count_solid(), "R2A edited regional collision cardinality matches Matter")
	_check(edited_regional_vertices == edited_global_vertices, "R2A regional mesh stays exact after occupancy edit")

	var full_collision_us := _median(full_collision_samples)
	var full_mesh_us := _median(full_mesh_samples)
	var dirty_collision_us := _median(dirty_collision_samples)
	var dirty_mesh_us := _median(dirty_mesh_samples)
	var full_total_us := full_collision_us + full_mesh_us
	var dirty_total_us := dirty_collision_us + dirty_mesh_us
	var locality_speedup := full_total_us / max(dirty_total_us, 1.0)
	var shape_inflation := float(regional_boxes.size()) / float(max(global_boxes.size(), 1))
	var edited_shape_inflation := float(edited_regional_boxes.size()) / float(max(edited_global_boxes.size(), 1))

	if extent >= 24 and occupied_regions > affected_mesh_regions:
		_check(dirty_total_us < full_total_us, "R2A bounded dirty compile materially reduces work on larger case")

	print(
		"R2A_CASE pattern=%s extent=%d region_edge=%d scanned=%d occupied=%d target=%s global_shapes=%d regional_shapes=%d shape_inflation=%.3f edited_global_shapes=%d edited_regional_shapes=%d edited_shape_inflation=%.3f global_vertices=%d regional_vertices=%d occupied_regions=%d render_regions=%d affected_mesh_regions=%d full_collision_us=%.1f full_mesh_us=%.1f dirty_collision_us=%.1f dirty_mesh_us=%.1f locality_speedup=%.3f"
		% [
			pattern,
			extent,
			region_edge,
			extent * extent * extent,
			occupied,
			target,
			global_boxes.size(),
			regional_boxes.size(),
			shape_inflation,
			edited_global_boxes.size(),
			edited_regional_boxes.size(),
			edited_shape_inflation,
			global_mesh_vertices,
			regional_vertices,
			occupied_regions,
			render_regions,
			affected_mesh_regions,
			full_collision_us,
			full_mesh_us,
			dirty_collision_us,
			dirty_mesh_us,
			locality_speedup,
		]
	)


func _build_all_region_boxes(volume: CellVolume, region_edge: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for origin in _all_region_origins(volume, region_edge):
		for box_info in _build_region_boxes(volume, origin, region_edge):
			result.append(box_info)
	return result


func _build_region_boxes(volume: CellVolume, origin: Vector3i, region_edge: int) -> Array[Dictionary]:
	var end := _region_end(volume, origin, region_edge)
	var local_size := end - origin
	var local := CellVolume.new(local_size)
	for z in range(origin.z, end.z):
		for y in range(origin.y, end.y):
			for x in range(origin.x, end.x):
				var source_cell := Vector3i(x, y, z)
				var material_id := volume.get_cell(source_cell)
				if material_id == CellVolume.EMPTY:
					continue
				local.set_cell(source_cell - origin, material_id)

	var local_boxes := CellCollisionBoxer.build_boxes(local, CellCollisionBoxer.Mode.MERGED_CUBOIDS)
	var result: Array[Dictionary] = []
	for local_box in local_boxes:
		var local_origin: Vector3i = local_box["origin"]
		var box_size: Vector3i = local_box["size"]
		result.append({"origin": origin + local_origin, "size": box_size})
	return result


func _build_all_region_mesh_vertex_count(volume: CellVolume, region_edge: int) -> int:
	var total := 0
	for origin in _all_region_origins(volume, region_edge):
		total += _region_mesh_vertex_count(volume, origin, region_edge)
	return total


func _region_mesh_vertex_count(volume: CellVolume, origin: Vector3i, region_edge: int) -> int:
	var end := _region_end(volume, origin, region_edge)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertex_count := 0

	for z in range(origin.z, end.z):
		for y in range(origin.y, end.y):
			for x in range(origin.x, end.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var cell_origin := Vector3(x, y, z)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					var direction: Vector3i = CellMesher.FACE_DIRECTIONS[face_index]
					if volume.get_cell(cell + direction) != CellVolume.EMPTY:
						continue
					var normal: Vector3 = CellMesher.FACE_NORMALS[face_index]
					for vertex_variant in CellMesher.FACE_VERTICES[face_index]:
						var vertex: Vector3 = vertex_variant
						surface.set_normal(normal)
						surface.add_vertex(cell_origin + vertex)
						vertex_count += 1

	if vertex_count > 0:
		var mesh := ArrayMesh.new()
		surface.commit(mesh)
	return vertex_count


func _global_mesh_vertex_count(volume: CellVolume) -> int:
	var mesh := CellMesher.build_mesh(volume)
	if mesh.get_surface_count() == 0:
		return 0
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()


func _count_occupied_regions(volume: CellVolume, region_edge: int) -> int:
	var count := 0
	for origin in _all_region_origins(volume, region_edge):
		if _region_occupied_count(volume, origin, region_edge) > 0:
			count += 1
	return count


func _count_render_regions(volume: CellVolume, region_edge: int) -> int:
	var count := 0
	for origin in _all_region_origins(volume, region_edge):
		if _region_mesh_vertex_count(volume, origin, region_edge) > 0:
			count += 1
	return count


func _region_occupied_count(volume: CellVolume, origin: Vector3i, region_edge: int) -> int:
	var end := _region_end(volume, origin, region_edge)
	var count := 0
	for z in range(origin.z, end.z):
		for y in range(origin.y, end.y):
			for x in range(origin.x, end.x):
				if volume.get_cell(Vector3i(x, y, z)) != CellVolume.EMPTY:
					count += 1
	return count


func _select_worst_boundary_target(volume: CellVolume, region_edge: int) -> Vector3i:
	var best := Vector3i(-1, -1, -1)
	var best_affected := -1
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var affected := _affected_mesh_region_origins(volume, cell, region_edge).size()
				if affected > best_affected:
					best = cell
					best_affected = affected
	return best


func _affected_mesh_region_origins(volume: CellVolume, cell: Vector3i, region_edge: int) -> Array:
	var unique: Dictionary = {}
	unique[_region_origin_for_cell(cell, region_edge)] = true
	for direction in CellMesher.FACE_DIRECTIONS:
		var neighbor: Vector3i = cell + direction
		if not volume.in_bounds(neighbor):
			continue
		unique[_region_origin_for_cell(neighbor, region_edge)] = true
	return unique.keys()


func _region_origin_for_cell(cell: Vector3i, region_edge: int) -> Vector3i:
	return Vector3i(
		(cell.x / region_edge) * region_edge,
		(cell.y / region_edge) * region_edge,
		(cell.z / region_edge) * region_edge
	)


func _all_region_origins(volume: CellVolume, region_edge: int) -> Array[Vector3i]:
	var origins: Array[Vector3i] = []
	for z in range(0, volume.size.z, region_edge):
		for y in range(0, volume.size.y, region_edge):
			for x in range(0, volume.size.x, region_edge):
				origins.append(Vector3i(x, y, z))
	return origins


func _region_end(volume: CellVolume, origin: Vector3i, region_edge: int) -> Vector3i:
	return Vector3i(
		min(origin.x + region_edge, volume.size.x),
		min(origin.y + region_edge, volume.size.y),
		min(origin.z + region_edge, volume.size.z)
	)


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
					coverage[_index(volume.size, Vector3i(x, y, z))] += 1

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
			assert(false, "Unknown R2A pattern")
	return volume


func _index(size: Vector3i, cell: Vector3i) -> int:
	return cell.x + size.x * (cell.y + size.y * cell.z)


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _finish() -> void:
	if _failures.is_empty():
		print("R2A_DERIVED_REGION_LOCALITY_CHALLENGER_PASS: bounded derived regions preserved exact collision/mesh semantics while exposing update-locality versus representation-inflation tradeoffs without changing logical Matter identity.")
		quit(0)
		return
	for failure in _failures:
		push_error("R2A_DERIVED_REGION_LOCALITY_CHALLENGER_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
