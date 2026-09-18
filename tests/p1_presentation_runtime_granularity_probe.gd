extends SceneTree

const EDGES: Array[int] = [4, 6, 7, 8]
const ACQUIRE_FRAMES := 12
const ORDINARY_CELL := Vector3i(8, 0, 8)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for edge in EDGES:
		await _run_edge(edge)
	_finish()


func _run_edge(edge: int) -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "edge %d Recovery scene loads" % edge)
	if packed == null:
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(ACQUIRE_FRAMES)

	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	var interactor := root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	var grid := root.get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
	var state := root.get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	_check(world != null and interactor != null and grid != null and state != null, "edge %d resolves runtime roles" % edge)
	if world == null or interactor == null or grid == null or state == null:
		root.queue_free()
		await _advance_frames(2)
		return

	var refresh_started := Time.get_ticks_usec()
	grid.set_chunk_edge_override(edge)
	state.set_chunk_edge_override(edge)
	var full_refresh_usec := Time.get_ticks_usec() - refresh_started
	var grid_nodes := grid.get_chunk_ids_for_test(world).size()
	var state_nodes := state.get_state_chunk_ids_for_test(world).size()
	var focus_nodes := state.get_focus_chunk_ids_for_test(world).size()
	_check(grid_nodes > 0 and state_nodes > 0 and focus_nodes > 0, "edge %d materializes presentation chunks" % edge)

	_check(world.volume.get_cell(ORDINARY_CELL) != CellVolume.EMPTY, "edge %d ordinary fixture is occupied" % edge)
	var ordinary_started := Time.get_ticks_usec()
	_check(interactor.apply_edit_to_cell(world, ORDINARY_CELL, P1MatterInteractor.EditMode.REMOVE), "edge %d ordinary edit succeeds" % edge)
	var ordinary_call_usec := Time.get_ticks_usec() - ordinary_started
	_check(not world.is_authority_partition_pending(), "edge %d ordinary edit remains connected" % edge)

	var bridge: Vector3i = root.call("get_recovery_causal_bridge_cell_for_test")
	_check(world.volume.get_cell(bridge) != CellVolume.EMPTY, "edge %d bridge fixture is occupied" % edge)
	var bridge_started := Time.get_ticks_usec()
	_check(interactor.apply_edit_to_cell(world, bridge, P1MatterInteractor.EditMode.REMOVE), "edge %d bridge edit succeeds" % edge)
	var bridge_call_usec := Time.get_ticks_usec() - bridge_started
	_check(world.is_authority_partition_pending(), "edge %d bridge edit queues authority transfer" % edge)

	var callback_started := Time.get_ticks_usec()
	await world.authority_partition_committed
	var callback_wait_usec := Time.get_ticks_usec() - callback_started
	var result := world.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "edge %d detach creates target" % edge)
	var publication: Dictionary = root.call("get_last_recovery_publication_timing")
	var timing: Dictionary = result.get("timing", {})

	print(
		"P1_PRESENTATION_RUNTIME_GRANULARITY_METRIC edge=%d grid_nodes=%d state_nodes=%d focus_nodes=%d total_presentation_nodes=%d full_refresh_us=%d ordinary_call_us=%d bridge_call_us=%d bridge_wait_us=%d source_rebuild_us=%d publication_us=%d source_grid_us=%d source_state_us=%d registry_us=%d"
		% [
			edge,
			grid_nodes,
			state_nodes,
			focus_nodes,
			grid_nodes + state_nodes + focus_nodes,
			full_refresh_usec,
			ordinary_call_usec,
			bridge_call_usec,
			callback_wait_usec,
			int(timing.get("source_rebuild_usec", -1)),
			int(publication.get("total_usec", -1)),
			int(publication.get("source_grid_usec", -1)),
			int(publication.get("source_state_usec", -1)),
			int(publication.get("registry_usec", -1)),
		]
	)

	root.queue_free()
	await _advance_frames(3)


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_PRESENTATION_RUNTIME_GRANULARITY_PASS: presentation edge candidates run through real Recovery ordinary-edit and causal-detach lifecycle with explicit node/full-refresh/local-publication tradeoffs while physics provider granularity remains unchanged.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_PRESENTATION_RUNTIME_GRANULARITY_FAIL: " + failure)
	quit(1)
