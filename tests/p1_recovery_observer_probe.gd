extends SceneTree

const BIND_FRAMES := 4

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "instrumented recovery scene loads")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(BIND_FRAMES)
	var observer := root.get_node_or_null("P1RecoveryObserver") as P1RecoveryObserver
	var interactor := root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	var world := root.call("get_recovery_world_space") as LocalMatterSpace
	_check(observer != null and interactor != null and world != null, "observer binds to recovery runtime roles")
	if observer == null or interactor == null or world == null:
		_finish(root)
		return

	var snapshot: Dictionary = observer.capture_snapshot_for_test()
	for key in [
		"support", "focus", "support_equals_focus",
		"logical_spaces", "nonempty_spaces", "empty_spaces",
		"static_spaces", "dynamic_spaces", "awake_dynamic_spaces",
		"physics_process_info_supported", "physics_active_objects", "physics_collision_pairs", "physics_islands",
		"fps_sampled", "frame_process_ms_sampled", "physics_process_ms_sampled",
		"occupied_cells", "collision_shapes", "max_provider_rebuild_usec",
		"observer_sample_usec",
	]:
		_check(snapshot.has(key), "snapshot exposes %s" % key)
	_check(int(snapshot.get("logical_spaces", 0)) == 1, "instrumented Spark still starts as one logical world Space")
	_check(int(snapshot.get("nonempty_spaces", 0)) == 1, "startup census sees one non-empty world Space")
	_check(int(snapshot.get("empty_spaces", -1)) == 0, "startup census sees no ghost Space")
	_check(not bool(snapshot.get("physics_process_info_supported", true)), "Jolt process-info counters are explicitly marked unsupported instead of presented as false zeros")
	_check(snapshot.get("physics_active_objects") == null, "unsupported Jolt active-object counter is null")
	_check(snapshot.get("physics_collision_pairs") == null, "unsupported Jolt collision-pair counter is null")
	_check(snapshot.get("physics_islands") == null, "unsupported Jolt island counter is null")
	_check(int(snapshot.get("observer_sample_usec", -1)) >= 0, "observer measures its own periodic census cost")

	var trace_path := observer.get_trace_path_for_test()
	_check(not trace_path.is_empty(), "observer publishes a session trace path")
	_check(FileAccess.file_exists(trace_path), "session trace file exists in user data")

	var records_before := observer.get_record_count_for_test()
	var safe_cell := Vector3i(3, 4, 4)
	_check(world.volume.get_cell(safe_cell) != CellVolume.EMPTY, "fixture edit target is ordinary canonical Matter")
	_check(
		interactor.apply_edit_to_cell(world, safe_cell, P1MatterInteractor.EditMode.REMOVE),
		"ordinary edit passes through the instrumented interactor"
	)
	var timing: Dictionary = observer.get_last_edit_timing_for_test()
	_check(not timing.is_empty(), "successful edit emits one timing sample")
	for key in [
		"mutation_usec", "topology_usec", "listeners_usec", "total_usec", "provider_rebuild_usec",
		"surface_grid_refresh_usec", "state_presentation_refresh_usec",
		"w0_policy_usec", "w0_partition_request_usec", "unattributed_listener_usec",
	]:
		_check(int(timing.get(key, -1)) >= 0, "edit timing exposes nonnegative %s" % key)
	_check(int(timing.get("total_usec", 0)) >= int(timing.get("mutation_usec", 0)), "total edit timing contains mutation timing")
	_check(observer.get_record_count_for_test() > records_before, "edit adds observer records without changing edit authority")

	var bridge: Vector3i = root.call("get_recovery_causal_bridge_cell_for_test")
	_check(
		interactor.apply_edit_to_cell(world, bridge, P1MatterInteractor.EditMode.REMOVE),
		"causal bridge edit queues the real W0 authority path under instrumentation"
	)
	await world.authority_partition_committed
	var authority_timing := observer.get_last_authority_timing_for_test()
	_check(not authority_timing.is_empty(), "authority commit publishes phase attribution")
	for key in [
		"validation_usec", "staging_usec", "source_rebuild_usec",
		"target_initialize_usec", "pre_signal_total_usec", "recovery_publication_usec",
	]:
		_check(int(authority_timing.get(key, -1)) >= 0, "authority timing exposes nonnegative %s" % key)

	observer.owner_mark_for_test("probe")
	_check(FileAccess.file_exists(trace_path), "Owner mark flush keeps trace file materialized")
	var trace_file := FileAccess.open(trace_path, FileAccess.READ)
	_check(trace_file != null, "flushed trace can be reopened for analysis")
	if trace_file != null:
		var text := trace_file.get_as_text()
		_check(text.contains("\"kind\":\"session_start\""), "trace records session provenance")
		_check(text.contains("\"kind\":\"edit_timing\""), "trace records successful edit microtiming")
		_check(text.contains("\"kind\":\"owner_mark\""), "trace records explicit Owner bookmark")

	var truth_label := root.get_node_or_null("HUD/P1RecoveryObserverTruthStrip") as Label
	_check(truth_label != null and truth_label.text.contains("SUPPORT") and truth_label.text.contains("FOCUS"), "truth strip presents SUPPORT and FOCUS separately")
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
		root.free()
	if _failures.is_empty():
		print("P1_RECOVERY_OBSERVER_PASS: calibrated Spark observer writes causal JSONL, marks unsupported Jolt process counters honestly, attributes edit/presentation/W0 costs and records authority-commit phases without taking authority.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_RECOVERY_OBSERVER_FAIL: " + failure)
	quit(1)
