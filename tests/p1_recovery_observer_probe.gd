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
		"physics_active_objects", "physics_collision_pairs", "physics_islands",
		"fps_sampled", "frame_process_ms_sampled", "physics_process_ms_sampled",
		"occupied_cells", "collision_shapes", "max_provider_rebuild_usec",
	]:
		_check(snapshot.has(key), "snapshot exposes %s" % key)
	_check(int(snapshot.get("logical_spaces", 0)) == 1, "instrumented Spark still starts as one logical world Space")
	_check(int(snapshot.get("nonempty_spaces", 0)) == 1, "startup census sees one non-empty world Space")
	_check(int(snapshot.get("empty_spaces", -1)) == 0, "startup census sees no ghost Space")
	_check(int(snapshot.get("physics_active_objects", -1)) >= 0, "PhysicsServer active-object census is readable")
	_check(int(snapshot.get("physics_collision_pairs", -1)) >= 0, "PhysicsServer collision-pair census is readable")
	_check(int(snapshot.get("physics_islands", -1)) >= 0, "PhysicsServer island census is readable")

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
	for key in ["mutation_usec", "topology_usec", "listeners_usec", "total_usec", "provider_rebuild_usec"]:
		_check(int(timing.get(key, -1)) >= 0, "edit timing exposes nonnegative %s" % key)
	_check(int(timing.get("total_usec", 0)) >= int(timing.get("mutation_usec", 0)), "total edit timing contains mutation timing")
	_check(observer.get_record_count_for_test() > records_before, "edit adds observer records without changing edit authority")

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
		print("P1_RECOVERY_OBSERVER_PASS: Instrumented Spark writes a low-frequency JSONL truth trace, separates SUPPORT from FOCUS, samples PhysicsServer/lifecycle state and records edit microtiming plus Owner marks without taking authority.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_RECOVERY_OBSERVER_FAIL: " + failure)
	quit(1)
