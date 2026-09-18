extends SceneTree

const EDGES: Array[int] = [4, 6, 7, 8]
const REPEATS := 3

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads for presentation granularity tradeoff")
	if packed == null:
		_finish(null)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(4)
	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	_check(world != null and world.volume != null, "granularity probe resolves WORLD")
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
	var detached: Array = policy.get("detached_components", [])
	_check(bool(policy.get("valid", false)) and detached.size() == 1, "granularity fixture resolves one detached shelf")
	if detached.size() != 1:
		_finish(root)
		return

	var transferred: Array[Vector3i] = []
	var source_after := bridge_after.duplicate_volume()
	for candidate in detached[0]:
		var cell: Vector3i = candidate
		transferred.append(cell)
		source_after.set_cell(cell, CellVolume.EMPTY)

	var source_full_grid := _segment_set(P1MatterSurfaceGrid.build_exposed_surface_grid(source_after))
	var source_full_state := _segment_set(P1MatterStatePresentation.build_side_surface_contour(source_after))
	var source_full_focus := _segment_set(P1MatterStatePresentation.build_top_surface_perimeter(source_after))

	for edge in EDGES:
		var origins := _chunk_origins(source_after.size, edge)
		var bridge_dirty := _dirty_origins(bridge_after.size, [bridge], edge)
		var source_dirty := _dirty_origins(source_after.size, transferred, edge)

		var chunk_grid: Dictionary = {}
		var chunk_state: Dictionary = {}
		var chunk_focus: Dictionary = {}
		var nonempty_grid := 0
		var nonempty_state := 0
		var nonempty_focus := 0
		for origin in origins:
			var end := _chunk_end(source_after.size, origin, edge)
			var grid_mesh := P1MatterSurfaceGrid.build_exposed_surface_grid_region(source_after, origin, end)
			var state_mesh := P1MatterStatePresentation.build_side_surface_contour_region(source_after, origin, end)
			var focus_mesh := P1MatterStatePresentation.build_top_surface_perimeter_region(source_after, origin, end)
			if grid_mesh.get_surface_count() > 0:
				nonempty_grid += 1
			if state_mesh.get_surface_count() > 0:
				nonempty_state += 1
			if focus_mesh.get_surface_count() > 0:
				nonempty_focus += 1
			_merge_segments(chunk_grid, _segment_set(grid_mesh))
			_merge_segments(chunk_state, _segment_set(state_mesh))
			_merge_segments(chunk_focus, _segment_set(focus_mesh))

		_check(_same_keys(source_full_grid, chunk_grid), "edge %d grid union exactly equals whole-volume source" % edge)
		_check(_same_keys(source_full_state, chunk_state), "edge %d state union exactly equals whole-volume source" % edge)
		_check(_same_keys(source_full_focus, chunk_focus), "edge %d focus union exactly equals whole-volume source" % edge)

		var bridge_grid_us := _measure(func() -> void: _build_regions(bridge_after, bridge_dirty, edge, "grid"))
		var bridge_state_us := _measure(func() -> void: _build_regions(bridge_after, bridge_dirty, edge, "state"))
		var bridge_focus_us := _measure(func() -> void: _build_regions(bridge_after, bridge_dirty, edge, "focus"))
		var source_grid_us := _measure(func() -> void: _build_regions(source_after, source_dirty, edge, "grid"))
		var source_state_us := _measure(func() -> void: _build_regions(source_after, source_dirty, edge, "state"))
		var full_grid_us := _measure(func() -> void: _build_regions(source_after, origins, edge, "grid"))
		var full_state_us := _measure(func() -> void: _build_regions(source_after, origins, edge, "state"))
		var full_focus_us := _measure(func() -> void: _build_regions(source_after, origins, edge, "focus"))

		print(
			"P1_PRESENTATION_GRANULARITY_METRIC edge=%d total_chunks=%d nonempty_grid=%d nonempty_state=%d nonempty_focus=%d bridge_dirty=%d bridge_grid_us=%d bridge_state_us=%d bridge_focus_us=%d source_dirty=%d source_grid_us=%d source_state_us=%d full_grid_us=%d full_state_us=%d full_focus_us=%d"
			% [
				edge,
				origins.size(),
				nonempty_grid,
				nonempty_state,
				nonempty_focus,
				bridge_dirty.size(),
				bridge_grid_us,
				bridge_state_us,
				bridge_focus_us,
				source_dirty.size(),
				source_grid_us,
				source_state_us,
				full_grid_us,
				full_state_us,
				full_focus_us,
			]
		)

	_finish(root)


func _build_regions(volume: CellVolume, origins: Array[Vector3i], edge: int, kind: String) -> void:
	for origin in origins:
		var end := _chunk_end(volume.size, origin, edge)
		if kind == "grid":
			P1MatterSurfaceGrid.build_exposed_surface_grid_region(volume, origin, end)
		elif kind == "state":
			P1MatterStatePresentation.build_side_surface_contour_region(volume, origin, end)
		else:
			P1MatterStatePresentation.build_top_surface_perimeter_region(volume, origin, end)


func _chunk_origins(size: Vector3i, edge: int) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(0, size.z, edge):
		for y in range(0, size.y, edge):
			for x in range(0, size.x, edge):
				result.append(Vector3i(x, y, z))
	return result


func _dirty_origins(size: Vector3i, cells: Array[Vector3i], edge: int) -> Array[Vector3i]:
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
			unique[_chunk_origin(candidate, edge)] = true
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
		print("P1_PRESENTATION_GRANULARITY_PASS: candidate presentation chunk edges preserve exact source grid/state/focus unions while exposing bridge, detach-publication and nonempty-chunk tradeoffs independently of physics-provider granularity.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_PRESENTATION_GRANULARITY_FAIL: " + failure)
	quit(1)
