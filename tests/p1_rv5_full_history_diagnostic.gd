extends "res://tests/p1_rv5_chaotic_owner_surface_rehearsal.gd"

# Diagnostic subclass of the exact full R-V5 rehearsal. The inherited _run()
# remains authoritative and unchanged. This enriches existing camera checkpoints
# and arms a read-only monitor immediately before the known final refreeze.

var _post_freeze_monitor_armed := false
var _post_freeze_monitor_last_grounded := false
var _post_freeze_monitor_last_support_same := false


func _print_camera_metric(label: String) -> void:
	super._print_camera_metric(label)
	_print_full_history_state(label)
	if label == "08_dynamic_irregular_near" and not _post_freeze_monitor_armed:
		_post_freeze_monitor_armed = true
		_post_freeze_monitor_last_grounded = _player.grounded
		_post_freeze_monitor_last_support_same = _player.support_space == _space
		_space.provider_transition_committed.connect(_on_monitored_provider_transition, CONNECT_ONE_SHOT)
		print("P1_RV5_POST_FREEZE_MONITOR armed=true")


func _on_monitored_provider_transition(previous_id: int, current_id: int, target_kind: int) -> void:
	print("P1_RV5_POST_FREEZE_TRANSITION previous_provider=%d current_provider=%d target_kind=%d" % [previous_id, current_id, target_kind])
	_print_post_freeze_sample(-1, "commit_signal")
	call_deferred("_monitor_post_freeze_frames")


func _monitor_post_freeze_frames() -> void:
	for frame_index in range(160):
		await physics_frame
		await process_frame
		var grounded_now := _player.grounded
		var support_same_now := _player.support_space == _space
		var state_changed := (
			grounded_now != _post_freeze_monitor_last_grounded
			or support_same_now != _post_freeze_monitor_last_support_same
		)
		if frame_index < 12 or frame_index % 8 == 7 or state_changed:
			_print_post_freeze_sample(frame_index, "state_change" if state_changed else "checkpoint")
		_post_freeze_monitor_last_grounded = grounded_now
		_post_freeze_monitor_last_support_same = support_same_now


func _print_post_freeze_sample(frame_index: int, reason: String) -> void:
	var provider: Node3D = _space.get_active_provider() if _space != null else null
	var provider_id := provider.get_instance_id() if provider != null else 0
	var support_id := _player.support_body.get_instance_id() if _player.support_body != null and is_instance_valid(_player.support_body) else 0
	var support_valid := _player.support_body != null and is_instance_valid(_player.support_body)
	var short_cast := _player.call("_cast_motion", Vector3.DOWN * _player.ground_snap_distance) as PackedFloat32Array
	var long_cast := _player.call("_cast_motion", Vector3.DOWN * 20.0) as PackedFloat32Array
	var short_safe := float(short_cast[0]) if short_cast.size() > 0 else -1.0
	var short_unsafe := float(short_cast[1]) if short_cast.size() > 1 else -1.0
	var long_safe := float(long_cast[0]) if long_cast.size() > 0 else -1.0
	var long_unsafe := float(long_cast[1]) if long_cast.size() > 1 else -1.0
	var provider_collision_count := -1
	if provider is MatterRepresentation:
		provider_collision_count = (provider as MatterRepresentation).get_collision_shape_count()
	elif provider is ConstructBody:
		provider_collision_count = (provider as ConstructBody).get_collision_shape_count()
	print(
		"P1_RV5_POST_FREEZE_SAMPLE frame=%d reason=%s provider_kind=%d provider_id=%d provider_collision_count=%d player=%s player_y=%.6f grounded=%s support_space_same=%s support_id=%d support_valid=%s support_equals_provider=%s support_local=%s velocity=%s short_cast=(%.6f,%.6f) long_cast=(%.6f,%.6f) acquisitions=%d transfers=%d" % [
			frame_index,
			reason,
			_space.get_provider_kind(),
			provider_id,
			provider_collision_count,
			str(_player.global_position),
			_player.global_position.y,
			str(_player.grounded),
			str(_player.support_space == _space),
			support_id,
			str(support_valid),
			str(_player.support_body == provider),
			str(_player.support_local_center),
			str(_player.world_velocity),
			short_safe,
			short_unsafe,
			long_safe,
			long_unsafe,
			_player.observed_ground_acquisitions,
			_player.observed_support_transfers,
		]
	)


func _print_full_history_state(label: String) -> void:
	var provider: Node3D = _space.get_active_provider() if _space != null else null
	var camera: Camera3D = _camera_rig.get_camera() if _camera_rig != null else null
	var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D if _camera_rig != null else null
	var context_target: Node3D = _camera_rig.context_target if _camera_rig != null else null
	var provider_id := provider.get_instance_id() if provider != null else 0
	var support_id := _player.support_body.get_instance_id() if _player != null and _player.support_body != null and is_instance_valid(_player.support_body) else 0
	var context_id := context_target.get_instance_id() if context_target != null and is_instance_valid(context_target) else 0
	var direct_center := Vector3.ZERO
	var interpolated_center := Vector3.ZERO
	var direct_interp_error := -1.0
	var direct_screen := Vector2(-1.0, -1.0)
	var interp_screen := Vector2(-1.0, -1.0)
	var direct_behind := true
	var interp_behind := true
	var provider_position := Vector3.ZERO
	if provider != null and camera != null:
		provider_position = provider.global_position
		var local_center: Vector3 = _space.get_content_center_local()
		direct_center = provider.global_transform * local_center
		interpolated_center = provider.get_global_transform_interpolated() * local_center
		direct_interp_error = direct_center.distance_to(interpolated_center)
		direct_behind = camera.is_position_behind(direct_center)
		interp_behind = camera.is_position_behind(interpolated_center)
		var rect := camera.get_viewport().get_visible_rect()
		if not direct_behind:
			var p := camera.unproject_position(direct_center) - rect.position
			direct_screen = Vector2(p.x / rect.size.x, p.y / rect.size.y)
		if not interp_behind:
			var p := camera.unproject_position(interpolated_center) - rect.position
			interp_screen = Vector2(p.x / rect.size.x, p.y / rect.size.y)

	var support_world_error := -1.0
	if provider != null and _player != null and _player.grounded and _player.support_space == _space:
		support_world_error = provider.to_global(_player.support_local_center).distance_to(_player.global_position)

	var actual_arm := -1.0
	var desired_arm := -1.0
	if spring_arm != null and camera != null:
		actual_arm = camera.global_position.distance_to(spring_arm.global_position)
		desired_arm = spring_arm.spring_length

	var player_position := _player.global_position if _player != null else Vector3.ZERO
	var camera_position := camera.global_position if camera != null else Vector3.ZERO
	var camera_focus := _camera_rig.global_position if _camera_rig != null else Vector3.ZERO
	var player_to_center := player_position.distance_to(direct_center) if provider != null else -1.0
	print(
		"P1_RV5_FULL_HISTORY_STATE label=%s provider_kind=%d provider_id=%d provider_pos=%s player=%s player_y=%.6f grounded=%s support_space_same=%s support_id=%d support_equals_provider=%s support_world_error=%.6f support_local=%s player_to_center=%.6f camera=%s camera_y=%.6f camera_focus=%s context_id=%d context_equals_provider=%s direct_center=%s interp_center=%s direct_interp_error=%.6f desired_arm=%.4f actual_arm=%.4f user_yaw=%.4f runtime_yaw=%.4f user_pitch=%.4f runtime_pitch=%.4f direct_behind=%s direct_screen=(%.4f,%.4f) interp_behind=%s interp_screen=(%.4f,%.4f) world_reference_top_y=-1.0000" % [
			label,
			_space.get_provider_kind() if _space != null else -1,
			provider_id,
			str(provider_position),
			str(player_position),
			player_position.y,
			str(_player.grounded if _player != null else false),
			str(_player.support_space == _space if _player != null else false),
			support_id,
			str(_player.support_body == provider if _player != null else false),
			support_world_error,
			str(_player.support_local_center if _player != null else Vector3.ZERO),
			player_to_center,
			str(camera_position),
			camera_position.y,
			str(camera_focus),
			context_id,
			str(context_target == provider),
			str(direct_center),
			str(interpolated_center),
			direct_interp_error,
			desired_arm,
			actual_arm,
			float(_camera_rig.get("_yaw")) if _camera_rig != null else 0.0,
			float(_camera_rig.get("_runtime_yaw")) if _camera_rig != null else 0.0,
			float(_camera_rig.get("_pitch")) if _camera_rig != null else 0.0,
			float(_camera_rig.get("_runtime_pitch")) if _camera_rig != null else 0.0,
			str(direct_behind),
			direct_screen.x,
			direct_screen.y,
			str(interp_behind),
			interp_screen.x,
			interp_screen.y,
		]
	)
