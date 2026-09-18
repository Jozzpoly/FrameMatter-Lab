extends SceneTree

const EDGES: Array[int] = [4, 6, 7, 8]
const SAMPLE_LIMIT := 48

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads for presentation spatial sweep")
	if packed == null:
		_finish(null)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(4)
	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	_check(world != null and world.volume != null, "spatial sweep resolves WORLD")
	if world == null or world.volume == null:
		_finish(root)
		return

	var samples := _sample_occupied_cells(world.volume)
	_check(samples.size() >= 24, "spatial sweep resolves enough distributed occupied cells")
	if samples.size() < 24:
		_finish(root)
		return

	for edge in EDGES:
		var dirty_counts: Array[int] = []
		var grid_times: Array[int] = []
		var state_times: Array[int] = []
		var focus_times: Array[int] = []
		var total_times: Array[int] = []
		for cell in samples:
			var material_id := world.volume.get_cell(cell)
			if material_id == CellVolume.EMPTY:
				continue
			world.volume.set_cell(cell, CellVolume.EMPTY)
			var origins := _dirty_origins(world.volume.size, cell, edge)
			var grid_started := Time.get_ticks_usec()
			_build_regions(world.volume, origins, edge, "grid")
			var grid_us := Time.get_ticks_usec() - grid_started
			var state_started := Time.get_ticks_usec()
			_build_regions(world.volume, origins, edge, "state")
			var state_us := Time.get_ticks_usec() - state_started
			var focus_started := Time.get_ticks_usec()
			_build_regions(world.volume, origins, edge, "focus")
			var focus_us := Time.get_ticks_usec() - focus_started
			world.volume.set_cell(cell, material_id)

			dirty_counts.append(origins.size())
			grid_times.append(grid_us)
			state_times.append(state_us)
			focus_times.append(focus_us)
			total_times.append(grid_us + state_us + focus_us)

		print(
			"P1_PRESENTATION_SPATIAL_SWEEP_METRIC edge=%d samples=%d dirty_median=%d dirty_p90=%d grid_median_us=%d grid_p90_us=%d state_median_us=%d state_p90_us=%d focus_median_us=%d focus_p90_us=%d total_median_us=%d total_p90_us=%d total_max_us=%d"
			% [
				edge,
				total_times.size(),
				_percentile(dirty_counts, 0.50),
				_percentile(dirty_counts, 0.90),
				_percentile(grid_times, 0.50),
				_percentile(grid_times, 0.90),
				_percentile(state_times, 0.50),
				_percentile(state_times, 0.90),
				_percentile(focus_times, 0.50),
				_percentile(focus_times, 0.90),
				_percentile(total_times, 0.50),
				_percentile(total_times, 0.90),
				_percentile(total_times, 1.00),
			]
		)

	_finish(root)


func _sample_occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var seen: Dictionary = {}
	for i in range(1024):
		var cell := Vector3i(
			(i * 17 + 3) % volume.size.x,
			(i * 5 + 1) % volume.size.y,
			(i * 29 + 7) % volume.size.z
		)
		if seen.has(cell):
			continue
		seen[cell] = true
		if volume.get_cell(cell) == CellVolume.EMPTY:
			continue
		result.append(cell)
		if result.size() >= SAMPLE_LIMIT:
			break
	return result


func _dirty_origins(size: Vector3i, cell: Vector3i, edge: int) -> Array[Vector3i]:
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
		unique[_chunk_origin(candidate, edge)] = true
	var result: Array[Vector3i] = []
	for origin_variant in unique.keys():
		result.append(origin_variant)
	return result


func _build_regions(volume: CellVolume, origins: Array[Vector3i], edge: int, kind: String) -> void:
	for origin in origins:
		var end := _chunk_end(volume.size, origin, edge)
		if kind == "grid":
			P1MatterSurfaceGrid.build_exposed_surface_grid_region(volume, origin, end)
		elif kind == "state":
			P1MatterStatePresentation.build_side_surface_contour_region(volume, origin, end)
		else:
			P1MatterStatePresentation.build_top_surface_perimeter_region(volume, origin, end)


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


func _percentile(values: Array[int], fraction: float) -> int:
	if values.is_empty():
		return -1
	var sorted := values.duplicate()
	sorted.sort()
	var index := int(floor((sorted.size() - 1) * clampf(fraction, 0.0, 1.0)))
	return sorted[index]


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
		print("P1_PRESENTATION_SPATIAL_SWEEP_PASS: distributed ordinary WORLD removals expose median/p90/max regional presentation cost across candidate chunk edges without coupling the result to the authored detach bridge.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_PRESENTATION_SPATIAL_SWEEP_FAIL: " + failure)
	quit(1)
