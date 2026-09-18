extends SceneTree

const ACQUIRE_FRAMES := 20
const BASELINE_FRAMES := 12
const POST_FRAMES := 5
const ORDINARY_CELL := Vector3i(4, 0, 4)

var _failures: Array[String] = []
var _authority_callback_usec := -1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads for frame-gap characterization")
	if packed == null:
		_finish(null)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(ACQUIRE_FRAMES)

	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	var interactor := root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	_check(world != null and interactor != null, "frame-gap probe resolves WORLD/interactor")
	if world == null or interactor == null:
		_finish(root)
		return

	var baseline_gaps: Array[int] = []
	var previous := Time.get_ticks_usec()
	for _index in range(BASELINE_FRAMES):
		await process_frame
		var now := Time.get_ticks_usec()
		baseline_gaps.append(now - previous)
		previous = now
	baseline_gaps.sort()
	var baseline_median := baseline_gaps[baseline_gaps.size() / 2]
	var baseline_max := baseline_gaps[-1]

	await process_frame
	var ordinary_process_anchor := Time.get_ticks_usec()
	var ordinary_call_started := Time.get_ticks_usec()
	_check(
		interactor.apply_edit_to_cell(world, ORDINARY_CELL, P1MatterInteractor.EditMode.REMOVE),
		"ordinary frame-gap edit succeeds"
	)
	var ordinary_call_usec := Time.get_ticks_usec() - ordinary_call_started
	await process_frame
	var ordinary_to_next_process_usec := Time.get_ticks_usec() - ordinary_process_anchor
	var ordinary_tail := await _collect_process_gaps(POST_FRAMES)

	await process_frame
	var bridge_process_anchor := Time.get_ticks_usec()
	var bridge: Vector3i = root.call("get_recovery_causal_bridge_cell_for_test")
	_check(world.volume.get_cell(bridge) != CellVolume.EMPTY, "bridge frame-gap fixture remains occupied")
	_authority_callback_usec = -1
	if not world.authority_partition_committed.is_connected(_on_authority_partition_committed):
		world.authority_partition_committed.connect(_on_authority_partition_committed)
	var bridge_call_started := Time.get_ticks_usec()
	_check(
		interactor.apply_edit_to_cell(world, bridge, P1MatterInteractor.EditMode.REMOVE),
		"bridge frame-gap edit succeeds"
	)
	var bridge_call_usec := Time.get_ticks_usec() - bridge_call_started
	_check(world.is_authority_partition_pending(), "bridge queues authority partition")

	await process_frame
	var first_process_after_bridge := Time.get_ticks_usec()
	var bridge_to_next_process_usec := first_process_after_bridge - bridge_process_anchor
	var bridge_tail := await _collect_process_gaps(POST_FRAMES)
	_check(_authority_callback_usec >= bridge_process_anchor, "authority callback occurs after bridge edit begins")
	var bridge_to_authority_callback_usec := (
		_authority_callback_usec - bridge_process_anchor
		if _authority_callback_usec >= bridge_process_anchor
		else -1
	)

	var result := world.get_last_authority_partition_result()
	_check(not result.is_empty(), "authority result exists by first/nearby post-bridge process frames")
	var timing: Dictionary = result.get("timing", {})
	var publication_usec := int(root.call("get_last_recovery_partition_publication_usec"))

	print(
		"P1_DETACH_FRAME_GAP_METRIC baseline_median_us=%d baseline_max_us=%d ordinary_call_us=%d ordinary_to_next_process_us=%d ordinary_tail_max_us=%d bridge_call_us=%d bridge_to_authority_callback_us=%d bridge_to_next_process_us=%d bridge_tail_max_us=%d authority_pre_signal_us=%d authority_source_rebuild_us=%d publication_us=%d"
		% [
			baseline_median,
			baseline_max,
			ordinary_call_usec,
			ordinary_to_next_process_usec,
			_max_value(ordinary_tail),
			bridge_call_usec,
			bridge_to_authority_callback_usec,
			bridge_to_next_process_usec,
			_max_value(bridge_tail),
			int(timing.get("pre_signal_total_usec", -1)),
			int(timing.get("source_rebuild_usec", -1)),
			publication_usec,
		]
	)
	_finish(root)


func _on_authority_partition_committed(_result: Dictionary) -> void:
	_authority_callback_usec = Time.get_ticks_usec()


func _collect_process_gaps(count: int) -> Array[int]:
	var gaps: Array[int] = []
	var previous := Time.get_ticks_usec()
	for _index in range(count):
		await process_frame
		var now := Time.get_ticks_usec()
		gaps.append(now - previous)
		previous = now
	return gaps


func _max_value(values: Array[int]) -> int:
	var result := 0
	for value in values:
		result = maxi(result, value)
	return result


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
		print("P1_DETACH_FRAME_GAP_PASS: independent wall-clock frame-boundary probe captured ordinary and causal-detach blocking envelopes without changing Recovery runtime behavior.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_DETACH_FRAME_GAP_FAIL: " + failure)
	quit(1)
