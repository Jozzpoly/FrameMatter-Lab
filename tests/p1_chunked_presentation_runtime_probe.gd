extends SceneTree

const ACQUIRE_FRAMES := 20
const EDIT_CELL := Vector3i(8, 0, 8)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads for chunked presentation runtime")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(ACQUIRE_FRAMES)

	var world := root.call("get_recovery_world_space") as LocalMatterSpace
	var player := root.get_node_or_null("P1Player") as SpaceQueryCharacter
	var interactor := root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	var grid := root.get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
	var state := root.get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	var provider: MatterRepresentation
	if world != null:
		provider = world.get_active_provider() as MatterRepresentation
	_check(
		world != null and player != null and interactor != null
		and grid != null and state != null and provider != null,
		"runtime presentation probe resolves Recovery roles"
	)
	if world == null or player == null or interactor == null or grid == null or state == null or provider == null:
		_finish(root)
		return

	_check(provider.chunk_edge == 8, "runtime presentation probe keeps edge-8 Recovery WORLD physics chunks")
	_check(grid.chunk_edge_override == 7, "Recovery surface grid uses independently selected edge-7 presentation chunks")
	_check(state.chunk_edge_override == 7, "Recovery state/focus presentation uses independently selected edge-7 chunks")
	_check(player.grounded and player.support_space == world and player.support_body == provider, "actor begins on the same logical chunked provider")

	var grid_root := grid.get_overlay_for_space(world)
	var state_root := state.get_state_overlay_for_space(world)
	var focus_root := state.get_focus_overlay_for_space(world)
	_check(grid_root != null and state_root != null and focus_root != null, "WORLD begins with grid/state/focus roots")
	if grid_root == null or state_root == null or focus_root == null:
		_finish(root)
		return

	var grid_root_id := grid_root.get_instance_id()
	var state_root_id := state_root.get_instance_id()
	var focus_root_id := focus_root.get_instance_id()
	var grid_before := grid.get_chunk_ids_for_test(world)
	var state_before := state.get_state_chunk_ids_for_test(world)
	var focus_before := state.get_focus_chunk_ids_for_test(world)
	_check(grid_before.size() > 16 and grid_before.size() < 50, "WORLD edge-7 grid materializes bounded independent presentation chunks")
	_check(state_before.size() > 16 and state_before.size() < 50, "WORLD edge-7 state contour materializes bounded independent chunks")
	_check(focus_before.size() > 16 and focus_before.size() < 50, "WORLD edge-7 focus crown materializes bounded independent chunks")
	_check(_same_keys(_segment_set(P1MatterSurfaceGrid.build_exposed_surface_grid(world.volume)), _segment_set_from_root(grid_root)), "initial chunk grid exactly equals whole-volume grid")
	_check(_same_keys(_segment_set(P1MatterStatePresentation.build_side_surface_contour(world.volume)), _segment_set_from_root(state_root)), "initial chunk state exactly equals whole-volume contour")
	_check(_same_keys(_segment_set(P1MatterStatePresentation.build_top_surface_perimeter(world.volume)), _segment_set_from_root(focus_root)), "initial chunk focus exactly equals whole-volume crown")

	_check(world.volume.get_cell(EDIT_CELL) != CellVolume.EMPTY, "runtime presentation edit fixture is occupied")
	_check(
		interactor.apply_edit_to_cell(world, EDIT_CELL, P1MatterInteractor.EditMode.REMOVE),
		"ordinary boundary edit succeeds through shared authority"
	)
	_check(not (world as W0AuthorityPartitionSpace).is_authority_partition_pending(), "ordinary boundary edit does not invent detachment")

	var grid_after_root := grid.get_overlay_for_space(world)
	var state_after_root := state.get_state_overlay_for_space(world)
	var focus_after_root := state.get_focus_overlay_for_space(world)
	_check(grid_after_root != null and grid_after_root.get_instance_id() == grid_root_id, "local edit preserves grid root identity")
	_check(state_after_root != null and state_after_root.get_instance_id() == state_root_id, "local edit preserves state root identity")
	_check(focus_after_root != null and focus_after_root.get_instance_id() == focus_root_id, "local edit preserves focus root identity")

	var grid_after := grid.get_chunk_ids_for_test(world)
	var state_after := state.get_state_chunk_ids_for_test(world)
	var focus_after := state.get_focus_chunk_ids_for_test(world)
	var changed_grid := _changed_ids(grid_before, grid_after)
	var changed_state := _changed_ids(state_before, state_after)
	var changed_focus := _changed_ids(focus_before, focus_after)
	_check(changed_grid >= 1 and changed_grid <= 4, "local edit changes only bounded grid chunks")
	_check(changed_state >= 1 and changed_state <= 4, "local edit changes only bounded state chunks")
	_check(changed_focus >= 1 and changed_focus <= 4, "local edit changes only bounded focus chunks")
	_check(_unchanged_ids(grid_before, grid_after) > 0, "unrelated grid chunks preserve identity")
	_check(_unchanged_ids(state_before, state_after) > 0, "unrelated state chunks preserve identity")
	_check(_unchanged_ids(focus_before, focus_after) > 0, "unrelated focus chunks preserve identity")

	_check(_same_keys(_segment_set(P1MatterSurfaceGrid.build_exposed_surface_grid(world.volume)), _segment_set_from_root(grid_after_root)), "edited chunk grid exactly equals whole-volume grid")
	_check(_same_keys(_segment_set(P1MatterStatePresentation.build_side_surface_contour(world.volume)), _segment_set_from_root(state_after_root)), "edited chunk state exactly equals whole-volume contour")
	_check(_same_keys(_segment_set(P1MatterStatePresentation.build_top_surface_perimeter(world.volume)), _segment_set_from_root(focus_after_root)), "edited chunk focus exactly equals whole-volume crown")

	await _advance_frames(3)
	_check(player.grounded and player.support_space == world and player.support_body == provider, "presentation locality does not disturb actor support frame")

	print(
		"P1_CHUNKED_PRESENTATION_RUNTIME_METRIC changed_grid=%d changed_state=%d changed_focus=%d grid_us=%d state_us=%d provider_us=%d grid_chunks=%d state_chunks=%d focus_chunks=%d"
		% [
			changed_grid,
			changed_state,
			changed_focus,
			grid.last_refresh_usec,
			state.last_refresh_usec,
			provider.last_rebuild_usec,
			grid_after.size(),
			state_after.size(),
			focus_after.size(),
		]
	)
	_finish(root)


func _segment_set_from_root(root: MeshInstance3D) -> Dictionary:
	var result: Dictionary = {}
	if root == null:
		return result
	if root.mesh != null:
		_merge_segments(result, _segment_set(root.mesh))
	for child in root.get_children():
		if child is MeshInstance3D:
			_merge_segments(result, _segment_set((child as MeshInstance3D).mesh))
	return result


func _segment_set(mesh: Mesh) -> Dictionary:
	var result: Dictionary = {}
	if mesh == null:
		return result
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		_check(vertices.size() % 2 == 0, "line mesh contains paired vertices")
		for index in range(0, vertices.size(), 2):
			result[_segment_key(vertices[index], vertices[index + 1])] = true
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


func _segment_key(a: Vector3, b: Vector3) -> String:
	var ak := _point_key(a)
	var bk := _point_key(b)
	return "%s|%s" % [ak, bk] if ak < bk else "%s|%s" % [bk, ak]


func _point_key(value: Vector3) -> String:
	return "%.5f,%.5f,%.5f" % [value.x, value.y, value.z]


func _changed_ids(before: Dictionary, after: Dictionary) -> int:
	var keys: Dictionary = {}
	for key in before.keys():
		keys[key] = true
	for key in after.keys():
		keys[key] = true
	var changed := 0
	for key in keys.keys():
		if int(before.get(key, 0)) != int(after.get(key, 0)):
			changed += 1
	return changed


func _unchanged_ids(before: Dictionary, after: Dictionary) -> int:
	var unchanged := 0
	for key in before.keys():
		if int(before.get(key, 0)) != 0 and int(before.get(key, 0)) == int(after.get(key, 0)):
			unchanged += 1
	return unchanged


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
		print("P1_CHUNKED_PRESENTATION_RUNTIME_PASS: Recovery WORLD keeps one presentation root per semantic layer while ordinary edits replace only bounded child chunks and remain exactly equivalent to whole-volume grid/state/focus geometry.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CHUNKED_PRESENTATION_RUNTIME_FAIL: " + failure)
	quit(1)
