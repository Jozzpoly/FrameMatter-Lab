extends SceneTree

const ACQUIRE_FRAMES := 20
const ORDINARY_CELL := Vector3i(4, 0, 4)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads for bounded policy runtime")
	if packed == null:
		_finish(null)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(ACQUIRE_FRAMES)

	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	var interactor := root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	_check(world != null and interactor != null, "bounded policy runtime resolves WORLD and interactor")
	if world == null or interactor == null:
		_finish(root)
		return

	_check(bool(root.call("is_recovery_source_known_single_connected_for_test")), "startup source begins with defended connected precondition")
	_check(world.volume.get_cell(ORDINARY_CELL) != CellVolume.EMPTY, "ordinary policy fixture begins occupied")
	_check(
		interactor.apply_edit_to_cell(world, ORDINARY_CELL, P1MatterInteractor.EditMode.REMOVE),
		"ordinary source edit succeeds"
	)
	_check(str(root.call("get_last_recovery_policy_mode")) == "bounded_connected", "ordinary connected edit uses bounded connected proof")
	_check(not world.is_authority_partition_pending(), "ordinary connected edit does not queue partition")
	_check(bool(root.call("is_recovery_source_known_single_connected_for_test")), "ordinary bounded proof preserves connected precondition")
	var ordinary_policy_usec := int(root.call("get_last_recovery_policy_usec"))
	var ordinary_visited := int(root.call("get_last_recovery_policy_visited_cells"))

	var bridge: Vector3i = root.call("get_recovery_causal_bridge_cell_for_test")
	_check(world.volume.get_cell(bridge) != CellVolume.EMPTY, "bridge fixture remains occupied after ordinary edit")
	_check(
		interactor.apply_edit_to_cell(world, bridge, P1MatterInteractor.EditMode.REMOVE),
		"causal bridge edit succeeds"
	)
	_check(str(root.call("get_last_recovery_policy_mode")) == "bounded_partition", "causal bridge uses bounded partition proof")
	_check(world.is_authority_partition_pending(), "bounded partition queues authority transfer")
	_check(not bool(root.call("is_recovery_source_known_single_connected_for_test")), "source precondition is suspended while detached Matter remains in source")
	var bridge_policy_usec := int(root.call("get_last_recovery_policy_usec"))
	var bridge_visited := int(root.call("get_last_recovery_policy_visited_cells"))

	await world.authority_partition_committed
	var result := world.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "bounded runtime partition creates live target")
	_check((result.get("source_cells", []) as Array).size() == 36, "bounded runtime transfers exact 36-cell shelf")
	_check(bool(root.call("is_recovery_source_known_single_connected_for_test")), "successful partition restores connected-source precondition")
	await _advance_frames(3)

	print(
		"W0_BOUNDED_POLICY_RUNTIME_METRIC ordinary_us=%d ordinary_visited=%d bridge_us=%d bridge_visited=%d transferred=%d source_rebuild_us=%d publication_us=%d"
		% [
			ordinary_policy_usec,
			ordinary_visited,
			bridge_policy_usec,
			bridge_visited,
			(result.get("source_cells", []) as Array).size(),
			int((result.get("timing", {}) as Dictionary).get("source_rebuild_usec", -1)),
			int(root.call("get_last_recovery_partition_publication_usec")),
		]
	)
	_finish(root)


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
		print("W0_BOUNDED_POLICY_RUNTIME_PASS: Recovery uses fail-closed bounded proofs for ordinary connected removal and the exact causal shelf detach, suspends the connected-source invariant while partition is pending, and restores it only after successful authority commit.")
		quit(0)
		return
	for failure in _failures:
		push_error("W0_BOUNDED_POLICY_RUNTIME_FAIL: " + failure)
	quit(1)
