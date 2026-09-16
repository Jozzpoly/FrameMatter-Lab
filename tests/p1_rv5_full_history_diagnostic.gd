extends "res://tests/p1_rv5_chaotic_owner_surface_rehearsal.gd"

# Diagnostic subclass of the exact full R-V5 rehearsal. The inherited _run()
# remains authoritative and unchanged; this only enriches existing camera
# checkpoints so the pixel-identical final failure can be classified without
# perturbing the sequence or production runtime.


func _print_camera_metric(label: String) -> void:
	super._print_camera_metric(label)
	_print_full_history_state(label)


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
