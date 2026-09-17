class_name P1RecoveryObserver
extends Node

# Observer-light telemetry for the Spark recovery slice. This node is strictly a
# consumer: it never mutates Matter, Space ownership, actor state, camera state,
# physics bodies or lifecycle policy. The goal is to make one natural Owner run
# explainable without turning the sandbox into a debug dashboard.

const TRACE_SCHEMA := "framematter.spark.observer.v2"
const SESSION_ROOT := "user://framematter-observer"
const SAMPLE_INTERVAL_SECONDS := 0.50
const FLUSH_INTERVAL_SECONDS := 1.00
const TRUTH_LABEL_NAME := "P1RecoveryObserverTruthStrip"

var _host: Node
var _registry: P1SpaceRegistry
var _player: SpaceQueryCharacter
var _interactor: P1MatterInteractor
var _world_space: LocalMatterSpace
var _truth_label: Label

var _session_dir := ""
var _trace_path := ""
var _trace_file: FileAccess
var _pending_lines: Array[String] = []
var _started_msec := 0
var _sample_accumulator := 0.0
var _flush_accumulator := 0.0
var _record_count := 0
var _owner_mark_count := 0
var _trace_available := false
var _bound := false
var _latest_snapshot: Dictionary = {}
var _last_edit_timing: Dictionary = {}
var _last_authority_timing: Dictionary = {}
var _mark_flash_until_msec := 0


func _ready() -> void:
	set_process(false)
	call_deferred("_bind")


func _exit_tree() -> void:
	if _bound:
		_record("session_end", {"records_before_end": _record_count})
	_flush_trace()
	_trace_file = null


func _process(delta: float) -> void:
	if not _bound:
		return
	_sample_accumulator += maxf(0.0, delta)
	_flush_accumulator += maxf(0.0, delta)
	if _sample_accumulator >= SAMPLE_INTERVAL_SECONDS:
		_sample_accumulator = fmod(_sample_accumulator, SAMPLE_INTERVAL_SECONDS)
		var sample_started_usec := Time.get_ticks_usec()
		_latest_snapshot = _capture_snapshot()
		_latest_snapshot["observer_sample_usec"] = Time.get_ticks_usec() - sample_started_usec
		_record("sample", _latest_snapshot)
		_refresh_truth_strip()
	if _flush_accumulator >= FLUSH_INTERVAL_SECONDS:
		_flush_accumulator = fmod(_flush_accumulator, FLUSH_INTERVAL_SECONDS)
		_flush_trace()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F7 or key.physical_keycode == KEY_F7:
		owner_mark_for_test("owner_hotkey")
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_F8 or key.physical_keycode == KEY_F8:
		_open_session_folder()
		get_viewport().set_input_as_handled()


func get_trace_path_for_test() -> String:
	return _trace_path


func get_session_dir_for_test() -> String:
	return _session_dir


func get_record_count_for_test() -> int:
	return _record_count


func get_last_edit_timing_for_test() -> Dictionary:
	return _last_edit_timing.duplicate(true)


func get_last_authority_timing_for_test() -> Dictionary:
	return _last_authority_timing.duplicate(true)


func capture_snapshot_for_test() -> Dictionary:
	var sample_started_usec := Time.get_ticks_usec()
	_latest_snapshot = _capture_snapshot()
	_latest_snapshot["observer_sample_usec"] = Time.get_ticks_usec() - sample_started_usec
	_refresh_truth_strip()
	return _latest_snapshot.duplicate(true)


func owner_mark_for_test(label: String = "owner_mark") -> void:
	_owner_mark_count += 1
	_mark_flash_until_msec = Time.get_ticks_msec() + 1400
	_record("owner_mark", {
		"mark_index": _owner_mark_count,
		"label": label,
		"snapshot": _capture_snapshot(),
	})
	_flush_trace()
	_refresh_truth_strip()


func _bind() -> void:
	_host = get_parent()
	if _host == null or not is_instance_valid(_host):
		return
	_registry = _host.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry
	_player = _host.get_node_or_null("P1Player") as SpaceQueryCharacter
	_interactor = _host.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	if _host.has_method("get_recovery_world_space"):
		_world_space = _host.call("get_recovery_world_space") as LocalMatterSpace
	if _registry == null or _player == null or _interactor == null:
		return

	_started_msec = Time.get_ticks_msec()
	_create_truth_strip()
	_create_trace()
	_connect_observed_signals()
	_bound = true
	_latest_snapshot = _capture_snapshot()
	_record("session_start", {
		"trace_schema": TRACE_SCHEMA,
		"godot_version": str(Engine.get_version_info().get("string", "")),
		"physics_engine": str(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"user_data_dir": OS.get_user_data_dir(),
		"sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
		"performance_monitor_note": "TIME_* monitors are sampled values and may update more slowly than this trace. Jolt PhysicsServer3D process-info counters are unsupported and are therefore recorded as null.",
	})
	_record("sample", _latest_snapshot)
	_refresh_truth_strip()
	set_process(true)


func _create_trace() -> void:
	var session_token := "session_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	_session_dir = "%s/%s" % [SESSION_ROOT, session_token]
	var absolute_dir := ProjectSettings.globalize_path(_session_dir)
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK:
		_trace_available = false
		return
	_trace_path = "%s/trace.jsonl" % _session_dir
	_trace_file = FileAccess.open(_trace_path, FileAccess.WRITE)
	_trace_available = _trace_file != null


func _create_truth_strip() -> void:
	var hud := _host.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	var existing := hud.get_node_or_null(TRUTH_LABEL_NAME) as Label
	if existing != null:
		_truth_label = existing
		return
	_truth_label = Label.new()
	_truth_label.name = TRUTH_LABEL_NAME
	_truth_label.position = Vector2(16.0, 80.0)
	_truth_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_truth_label.add_theme_font_size_override("font_size", 10)
	_truth_label.add_theme_constant_override("outline_size", 3)
	_truth_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94, 0.92))
	_truth_label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.94))
	hud.add_child(_truth_label)


func _connect_observed_signals() -> void:
	if not _interactor.edit_timing_sample.is_connected(_on_edit_timing_sample):
		_interactor.edit_timing_sample.connect(_on_edit_timing_sample)
	if not _interactor.edit_rejected.is_connected(_on_edit_rejected):
		_interactor.edit_rejected.connect(_on_edit_rejected)
	if not _registry.active_spaces_changed.is_connected(_on_active_spaces_changed):
		_registry.active_spaces_changed.connect(_on_active_spaces_changed)
	if not _registry.provider_changed.is_connected(_on_provider_changed):
		_registry.provider_changed.connect(_on_provider_changed)
	if not _registry.storage_rebased.is_connected(_on_storage_rebased):
		_registry.storage_rebased.connect(_on_storage_rebased)
	if not _registry.split_committed.is_connected(_on_split_committed):
		_registry.split_committed.connect(_on_split_committed)
	if _world_space is W0AuthorityPartitionSpace:
		var world := _world_space as W0AuthorityPartitionSpace
		if not world.authority_partition_committed.is_connected(_on_authority_partition_committed):
			world.authority_partition_committed.connect(_on_authority_partition_committed)


func _capture_snapshot() -> Dictionary:
	var census := _collect_lifecycle_census()
	var support := _space_state(_player.support_space if _player != null else null)
	var focus_space: LocalMatterSpace
	if _host != null and is_instance_valid(_host) and _host.has_method("get_space"):
		focus_space = _host.call("get_space") as LocalMatterSpace
	var focus := _space_state(focus_space)
	var physics_process_info_supported := not _jolt_process_info_unavailable()
	var physics_active_objects: Variant = null
	var physics_collision_pairs: Variant = null
	var physics_islands: Variant = null
	if physics_process_info_supported:
		physics_active_objects = PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS)
		physics_collision_pairs = PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_COLLISION_PAIRS)
		physics_islands = PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ISLAND_COUNT)
	return {
		"support": support,
		"focus": focus,
		"support_equals_focus": int(support.get("id", 0)) != 0 and int(support.get("id", 0)) == int(focus.get("id", 0)),
		"logical_spaces": census["logical_spaces"],
		"nonempty_spaces": census["nonempty_spaces"],
		"empty_spaces": census["empty_spaces"],
		"static_spaces": census["static_spaces"],
		"dynamic_spaces": census["dynamic_spaces"],
		"awake_dynamic_spaces": census["awake_dynamic_spaces"],
		"sleeping_dynamic_spaces": census["sleeping_dynamic_spaces"],
		"occupied_cells": census["occupied_cells"],
		"collision_shapes": census["collision_shapes"],
		"max_provider_rebuild_usec": census["max_provider_rebuild_usec"],
		"physics_process_info_supported": physics_process_info_supported,
		"physics_active_objects": physics_active_objects,
		"physics_collision_pairs": physics_collision_pairs,
		"physics_islands": physics_islands,
		"fps_sampled": Performance.get_monitor(Performance.TIME_FPS),
		"frame_process_ms_sampled": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_process_ms_sampled": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
	}


func _jolt_process_info_unavailable() -> bool:
	var physics_engine := str(ProjectSettings.get_setting("physics/3d/physics_engine", ""))
	return physics_engine.to_lower().contains("jolt")


func _collect_lifecycle_census() -> Dictionary:
	var logical := 0
	var nonempty := 0
	var empty := 0
	var statics := 0
	var dynamics := 0
	var awake := 0
	var sleeping := 0
	var occupied := 0
	var collision_shapes := 0
	var max_rebuild_usec := 0
	if _registry != null:
		for space in _registry.get_active_spaces():
			if space == null or not is_instance_valid(space) or space.is_retired():
				continue
			logical += 1
			var solid_count := space.volume.count_solid() if space.volume != null else 0
			occupied += solid_count
			if solid_count > 0:
				nonempty += 1
			else:
				empty += 1
			var provider := space.get_active_provider()
			if space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC:
				statics += 1
			elif space.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC:
				dynamics += 1
				if provider is RigidBody3D and (provider as RigidBody3D).sleeping:
					sleeping += 1
				else:
					awake += 1
			if provider is ConstructBody:
				var body := provider as ConstructBody
				collision_shapes += body.get_collision_shape_count()
				max_rebuild_usec = maxi(max_rebuild_usec, body.last_rebuild_usec)
			elif provider is MatterRepresentation:
				var representation := provider as MatterRepresentation
				collision_shapes += representation.get_collision_shape_count()
				max_rebuild_usec = maxi(max_rebuild_usec, representation.last_rebuild_usec)
	return {
		"logical_spaces": logical,
		"nonempty_spaces": nonempty,
		"empty_spaces": empty,
		"static_spaces": statics,
		"dynamic_spaces": dynamics,
		"awake_dynamic_spaces": awake,
		"sleeping_dynamic_spaces": sleeping,
		"occupied_cells": occupied,
		"collision_shapes": collision_shapes,
		"max_provider_rebuild_usec": max_rebuild_usec,
	}


func _space_state(space: LocalMatterSpace) -> Dictionary:
	if space == null or not is_instance_valid(space) or space.is_retired():
		return {"id": 0, "role": "NONE", "kind": "NONE"}
	var kind := "STATIC" if space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC else "DYNAMIC"
	var role := "WORLD" if space == _world_space else "DETACHED"
	return {
		"id": space.get_instance_id(),
		"role": role,
		"kind": kind,
	}


func _record(kind: String, payload: Dictionary = {}) -> void:
	var support := _space_state(_player.support_space if _player != null else null)
	var focus_space: LocalMatterSpace
	if _host != null and is_instance_valid(_host) and _host.has_method("get_space"):
		focus_space = _host.call("get_space") as LocalMatterSpace
	var focus := _space_state(focus_space)
	var record := {
		"schema": TRACE_SCHEMA,
		"kind": kind,
		"t_ms": maxi(0, Time.get_ticks_msec() - _started_msec),
		"process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(),
		"support_space_id": support["id"],
		"support_role": support["role"],
		"support_kind": support["kind"],
		"focus_space_id": focus["id"],
		"focus_role": focus["role"],
		"focus_kind": focus["kind"],
	}
	for key in payload.keys():
		record[key] = payload[key]
	_record_count += 1
	if not _trace_available:
		return
	_pending_lines.append(JSON.stringify(record))


func _flush_trace() -> void:
	if not _trace_available or _trace_file == null or _pending_lines.is_empty():
		return
	for line in _pending_lines:
		_trace_file.store_line(line)
	_pending_lines.clear()
	_trace_file.flush()


func _refresh_truth_strip() -> void:
	if _truth_label == null:
		return
	if _latest_snapshot.is_empty():
		_latest_snapshot = _capture_snapshot()
	var s := _latest_snapshot
	var support: Dictionary = s["support"]
	var focus: Dictionary = s["focus"]
	var relation := "=" if bool(s["support_equals_focus"]) else "!="
	var trace_state := "TRACE" if _trace_available else "TRACE OFF"
	var mark_state := " · MARK %d" % _owner_mark_count if Time.get_ticks_msec() < _mark_flash_until_msec else ""
	var last_edit_ms := float(_last_edit_timing.get("total_usec", 0)) / 1000.0
	_truth_label.text = (
		"OBS · SUPPORT %s/%s %s FOCUS %s/%s · SPACES %d/%d (empty %d) · DYN/AWAKE %d/%d\n"
		+ "CELLS %d · SHAPES %d · FPS %.0f · physics %.2f ms* · EDIT %.1f ms · %s · F7 MARK · F8 FOLDER%s"
	) % [
		support["role"], support["kind"], relation, focus["role"], focus["kind"],
		s["logical_spaces"], s["nonempty_spaces"], s["empty_spaces"],
		s["dynamic_spaces"], s["awake_dynamic_spaces"],
		s["occupied_cells"], s["collision_shapes"],
		s["fps_sampled"], s["physics_process_ms_sampled"], last_edit_ms, trace_state, mark_state,
	]


func _open_session_folder() -> void:
	if _session_dir.is_empty():
		return
	var absolute_dir := ProjectSettings.globalize_path(_session_dir)
	var error := OS.shell_open(absolute_dir)
	_record("open_trace_folder", {"error": int(error)})
	_flush_trace()


func _on_edit_timing_sample(
	space: LocalMatterSpace,
	cell: Vector3i,
	mode: int,
	split_queued: bool,
	sample: Dictionary
) -> void:
	var grid := _host.get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
	var state_presentation := _host.get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	var grid_usec := grid.last_refresh_usec if grid != null else -1
	var state_usec := state_presentation.last_refresh_usec if state_presentation != null else -1
	var policy_usec := (
		int(_host.call("get_last_recovery_policy_usec"))
		if _host != null and _host.has_method("get_last_recovery_policy_usec")
		else -1
	)
	var request_usec := (
		int(_host.call("get_last_recovery_partition_request_usec"))
		if _host != null and _host.has_method("get_last_recovery_partition_request_usec")
		else -1
	)
	var listeners_usec := int(sample.get("listeners_usec", -1))
	var known_listener_usec := maxi(0, grid_usec) + maxi(0, state_usec) + maxi(0, policy_usec) + maxi(0, request_usec)
	var unattributed_listener_usec := maxi(0, listeners_usec - known_listener_usec)
	_last_edit_timing = sample.duplicate(true)
	_last_edit_timing["surface_grid_refresh_usec"] = grid_usec
	_last_edit_timing["state_presentation_refresh_usec"] = state_usec
	_last_edit_timing["w0_policy_usec"] = policy_usec
	_last_edit_timing["w0_partition_request_usec"] = request_usec
	_last_edit_timing["unattributed_listener_usec"] = unattributed_listener_usec
	_record("edit_timing", {
		"space_id": space.get_instance_id() if space != null and is_instance_valid(space) else 0,
		"cell": [cell.x, cell.y, cell.z],
		"mode": "REMOVE" if mode == P1MatterInteractor.EditMode.REMOVE else "PLACE",
		"split_queued": split_queued,
		"mutation_usec": int(sample.get("mutation_usec", -1)),
		"topology_usec": int(sample.get("topology_usec", -1)),
		"listeners_usec": listeners_usec,
		"total_usec": int(sample.get("total_usec", -1)),
		"provider_rebuild_usec": int(sample.get("provider_rebuild_usec", -1)),
		"surface_grid_refresh_usec": grid_usec,
		"state_presentation_refresh_usec": state_usec,
		"w0_policy_usec": policy_usec,
		"w0_partition_request_usec": request_usec,
		"unattributed_listener_usec": unattributed_listener_usec,
	})


func _on_edit_rejected(reason: String) -> void:
	_record("edit_rejected", {"reason": reason})


func _on_active_spaces_changed() -> void:
	# Keep lifecycle callbacks O(1)-ish. Full volume/collision census belongs to
	# the periodic observer sample, not inside authority/split publication.
	_record("active_spaces_changed", {
		"logical_spaces": _registry.get_active_count() if _registry != null else 0,
	})


func _on_provider_changed(space: LocalMatterSpace) -> void:
	_record("provider_changed", {
		"space_id": space.get_instance_id(),
		"provider_kind": space.get_provider_kind(),
	})


func _on_storage_rebased(space: LocalMatterSpace, report: Dictionary) -> void:
	var shift: Vector3i = report.get("local_shift", Vector3i.ZERO)
	_record("storage_rebased", {
		"space_id": space.get_instance_id(),
		"local_shift": [shift.x, shift.y, shift.z],
	})


func _on_split_committed(source: LocalMatterSpace, result: LocalMatterSplitResult) -> void:
	var successor_ids: Array[int] = []
	for successor_variant in result.successors:
		var successor := successor_variant as LocalMatterSpace
		if successor != null and is_instance_valid(successor):
			successor_ids.append(successor.get_instance_id())
	_record("topology_split_committed", {
		"source_space_id": source.get_instance_id() if source != null and is_instance_valid(source) else 0,
		"successor_space_ids": successor_ids,
	})


func _on_authority_partition_committed(result: Dictionary) -> void:
	var target := result.get("target_space") as LocalMatterSpace
	var source_cells: Array = result.get("source_cells", [])
	var timing: Dictionary = result.get("timing", {})
	var publication_usec := (
		int(_host.call("get_last_recovery_partition_publication_usec"))
		if _host != null and _host.has_method("get_last_recovery_partition_publication_usec")
		else -1
	)
	_last_authority_timing = {
		"validation_usec": int(timing.get("validation_usec", -1)),
		"staging_usec": int(timing.get("staging_usec", -1)),
		"source_rebuild_usec": int(timing.get("source_rebuild_usec", -1)),
		"target_initialize_usec": int(timing.get("target_initialize_usec", -1)),
		"pre_signal_total_usec": int(timing.get("pre_signal_total_usec", -1)),
		"recovery_publication_usec": publication_usec,
	}
	_record("authority_partition_committed", {
		"target_space_id": target.get_instance_id() if target != null and is_instance_valid(target) else 0,
		"transferred_cell_count": source_cells.size(),
		"validation_usec": _last_authority_timing["validation_usec"],
		"staging_usec": _last_authority_timing["staging_usec"],
		"source_rebuild_usec": _last_authority_timing["source_rebuild_usec"],
		"target_initialize_usec": _last_authority_timing["target_initialize_usec"],
		"pre_signal_total_usec": _last_authority_timing["pre_signal_total_usec"],
		"recovery_publication_usec": publication_usec,
	})
func _on_authority_partition_committed(result: Dictionary) -> void:
	var target := result.get("target_space") as LocalMatterSpace
	var source_cells: Array = result.get("source_cells", [])
	_record("authority_partition_committed", {
		"target_space_id": target.get_instance_id() if target != null and is_instance_valid(target) else 0,
		"transferred_cell_count": source_cells.size(),
	})
