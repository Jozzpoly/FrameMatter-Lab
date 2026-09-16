extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 12
const OBSERVE_FRAMES := 30
const RECOVERY_FRAMES := 30
const ACTOR_LOCAL := Vector3(8.5, 1.94, 6.5)
const RING_CENTER := Vector2i(8, 6)
const RING_MIN_Y := 1
const RING_MAX_Y := 4
const VISUAL_UNSAFE_ARM_MAX := 0.60
const VISUAL_UNSAFE_AVATAR_GAP_MAX := 0.25
const OVERHEAD_ESCAPE_PITCH := 1.48
const RECOVERED_ARM_MIN := 2.50
const ALLOWED_VARIANTS := ["baseline", "near_hide", "overhead_escape", "production"]

var _failures: Array[String] = []
var _output_dir := ""
var _variant := "baseline"
var _p1: Node
var _space: LocalMatterSpace
var _player: SpaceQueryCharacter
var _camera_rig: P1CameraRig
var _interactor: P1MatterInteractor
var _user_pitch_reference := 0.0
var _control_forward_reference := Vector3.ZERO


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_RV4_CAMERA_SAFETY_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-rv4-camera-safety")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	_variant = OS.get_environment("P1_RV4_CAMERA_SAFETY_VARIANT").strip_edges().to_lower()
	if _variant.is_empty():
		_variant = "baseline"
	_check(ALLOWED_VARIANTS.has(_variant), "R-V4 variant is supported: %s" % _variant)
	if not ALLOWED_VARIANTS.has(_variant):
		_finish()
		return

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "R-V4 capture loads canonical P1 scene")
	if packed == null:
		_finish()
		return

	_p1 = packed.instantiate()
	get_root().add_child(_p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	_space = _p1.call("get_space") as LocalMatterSpace
	_player = _p1.call("get_player") as SpaceQueryCharacter
	_camera_rig = _p1.call("get_camera_rig") as P1CameraRig
	_interactor = _p1.call("get_interactor") as P1MatterInteractor
	_check(
		_space != null and _player != null and _camera_rig != null and _interactor != null,
		"R-V4 capture resolves canonical Space/player/camera/interactor"
	)
	if _space == null or _player == null or _camera_rig == null or _interactor == null:
		_cleanup_and_finish()
		return

	var target_presenter := _p1.get_node_or_null("P1MatterTargetPresentation") as P1MatterTargetPresentation
	if target_presenter != null:
		target_presenter.set_enabled(false)
	var hud := _p1.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false

	_player.set_physics_process(false)
	_move_player_to_space_local(ACTOR_LOCAL)
	_set_avatar_visible(true)
	_camera_rig.reset_view()
	await _advance_frames(SETTLE_FRAMES)
	_user_pitch_reference = float(_camera_rig.get("_pitch"))
	_control_forward_reference = _camera_rig.get_planar_forward()
	_print_camera_avatar_metric("00_open_reference")
	_check(_camera_avatar_signed_distance() > 0.0, "open reference keeps Camera3D outside visible avatar capsule")
	_check(_actual_arm_length() > VISUAL_UNSAFE_ARM_MAX, "open reference is not already in catastrophic near-avatar framing")
	_check(_avatar_visible(), "open reference keeps avatar visible")
	await _capture("00_open_reference")

	_check(_build_tight_matter_ring(), "R-V4 creates real Matter enclosure through normal PLACE edits")
	_apply_variant_presentation()
	await _advance_frames(SETTLE_FRAMES)

	var inside_frames := 0
	var visual_unsafe_frames := 0
	var visible_hazard_frames := 0
	var recovered_arm_frames := 0
	var minimum_signed := INF
	var maximum_signed := -INF
	var minimum_arm := INF
	var maximum_arm := -INF
	for _frame in range(OBSERVE_FRAMES):
		await physics_frame
		await process_frame
		_apply_variant_presentation()
		var signed_distance := _camera_avatar_signed_distance()
		var actual_arm := _actual_arm_length()
		var visual_unsafe := _is_visual_unsafe(actual_arm, signed_distance)
		minimum_signed = minf(minimum_signed, signed_distance)
		maximum_signed = maxf(maximum_signed, signed_distance)
		minimum_arm = minf(minimum_arm, actual_arm)
		maximum_arm = maxf(maximum_arm, actual_arm)
		if signed_distance < 0.0:
			inside_frames += 1
		if actual_arm >= RECOVERED_ARM_MIN:
			recovered_arm_frames += 1
		if visual_unsafe:
			visual_unsafe_frames += 1
			if _avatar_visible():
				visible_hazard_frames += 1

	_apply_variant_presentation()
	_print_camera_avatar_metric("01_tight_matter_enclosure")
	print(
		"P1_RV4_SAFETY_WINDOW variant=%s frames=%d visual_unsafe_frames=%d visible_hazard_frames=%d recovered_arm_frames=%d inside_frames=%d min_avatar_signed=%.4f max_avatar_signed=%.4f min_actual_arm=%.4f max_actual_arm=%.4f" % [
			_variant,
			OBSERVE_FRAMES,
			visual_unsafe_frames,
			visible_hazard_frames,
			recovered_arm_frames,
			inside_frames,
			minimum_signed,
			maximum_signed,
			minimum_arm,
			maximum_arm,
		]
	)

	var sustained_unsafe := visual_unsafe_frames >= int(ceil(float(OBSERVE_FRAMES) * 0.8))
	var sustained_recovery := recovered_arm_frames >= int(ceil(float(OBSERVE_FRAMES) * 0.8))
	if _variant == "baseline":
		_check(sustained_unsafe, "tight real-Matter enclosure sustains the same physical near-camera stress")
		_check(
			visible_hazard_frames >= int(ceil(float(OBSERVE_FRAMES) * 0.8)),
			"baseline reproduces sustained world-safe but avatar-unsafe visible framing"
		)
	elif _variant == "near_hide":
		_check(sustained_unsafe, "near-hide control retains the same physical near-camera stress")
		_check(visible_hazard_frames == 0, "near-hide challenger suppresses visible avatar throughout unsafe near framing")
		_check(not _avatar_visible(), "near-hide challenger leaves avatar hidden in sustained unsafe state")
	else:
		_check(sustained_recovery, "%s restores material SpringArm distance for most observed frames" % _variant)
		_check(visual_unsafe_frames == 0, "%s exits catastrophic near-avatar framing" % _variant)
		_check(_avatar_visible(), "%s keeps avatar visible" % _variant)
		_check(inside_frames == 0, "%s never places Camera3D inside avatar geometry" % _variant)
		if _variant == "production":
			_check(
				absf(float(_camera_rig.get("_pitch")) - _user_pitch_reference) <= 0.0001,
				"production escape preserves Owner pitch intent"
			)
			_check(
				_camera_rig.get_planar_forward().dot(_control_forward_reference) >= 0.9999,
				"production escape preserves movement/control yaw frame"
			)

	await _capture("01_tight_matter_enclosure")

	if _variant == "production":
		_check(_remove_tight_matter_ring(), "R-V4 removes stress Matter through normal REMOVE edits")
		await _advance_frames(RECOVERY_FRAMES)
		_print_camera_avatar_metric("02_post_obstruction_recovery")
		var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
		var desired_arm := spring_arm.spring_length
		_check(
			_actual_arm_length() >= desired_arm * 0.95,
			"production camera restores full ordinary SpringArm distance after obstruction clears"
		)
		_check(
			absf(float(_camera_rig.get("_runtime_pitch")) - _user_pitch_reference) <= 0.03,
			"production camera returns presentation pitch to Owner intent after obstruction clears"
		)
		_check(
			absf(float(_camera_rig.get("_pitch")) - _user_pitch_reference) <= 0.0001,
			"production recovery never mutates Owner pitch intent"
		)
		_check(
			_camera_rig.get_planar_forward().dot(_control_forward_reference) >= 0.9999,
			"production recovery preserves movement/control yaw frame"
		)
		_check(_avatar_visible(), "production recovery keeps avatar visible")
		await _capture("02_post_obstruction_recovery")

	if _failures.is_empty():
		if _variant == "baseline":
			print("P1_RV4_BASELINE_REPRODUCED: real Matter obstruction sustained catastrophic near-avatar framing while camera remained outside the capsule; fix not yet promoted.")
		elif _variant == "near_hide":
			print("P1_RV4_NEAR_HIDE_CHALLENGER_PASS: identical camera/world state retained while local avatar presentation was suppressed in the unsafe near field; diagnostic challenger only.")
		elif _variant == "overhead_escape":
			print("P1_RV4_OVERHEAD_ESCAPE_CHALLENGER_PASS: high presentation pitch recovered collision-clear camera distance through the open top while preserving visible avatar and control yaw; diagnostic challenger only.")
		else:
			print("P1_RV4_PRODUCTION_POLICY_PASS: canonical escape search recovered readable camera distance under tight Matter obstruction and returned to untouched Owner pitch/control intent after the obstruction cleared.")

	_cleanup_and_finish()


func _apply_variant_presentation() -> void:
	if _variant == "near_hide":
		_set_avatar_visible(not _is_visual_unsafe(_actual_arm_length(), _camera_avatar_signed_distance()))
		return
	_set_avatar_visible(true)
	if _variant == "overhead_escape":
		# Historical diagnostic challenger: force the presentation pitch that
		# proved an open-top route exists. Production must recover without this.
		_camera_rig.set("_pitch", OVERHEAD_ESCAPE_PITCH)
		_camera_rig.call("_apply_user_orbit_immediately")


func _is_visual_unsafe(actual_arm: float, signed_distance: float) -> bool:
	return actual_arm <= VISUAL_UNSAFE_ARM_MAX and signed_distance <= VISUAL_UNSAFE_AVATAR_GAP_MAX


func _avatar_body() -> MeshInstance3D:
	return _player.get_node_or_null("Body") as MeshInstance3D


func _avatar_visible() -> bool:
	var body := _avatar_body()
	return body != null and body.visible


func _set_avatar_visible(value: bool) -> void:
	var body := _avatar_body()
	if body != null:
		body.visible = value
	var facing_marker := _player.get_node_or_null("FacingMarker") as MeshInstance3D
	if facing_marker != null:
		facing_marker.visible = value


func _build_tight_matter_ring() -> bool:
	return _set_tight_matter_ring(true)


func _remove_tight_matter_ring() -> bool:
	return _set_tight_matter_ring(false)


func _set_tight_matter_ring(present: bool) -> bool:
	var all_changed := true
	for y in range(RING_MIN_Y, RING_MAX_Y + 1):
		for z in range(RING_CENTER.y - 1, RING_CENTER.y + 2):
			for x in range(RING_CENTER.x - 1, RING_CENTER.x + 2):
				if x == RING_CENTER.x and z == RING_CENTER.y:
					continue
				var cell := Vector3i(x, y, z)
				var expected_before := CellVolume.EMPTY if present else CellVolume.SOLID
				if _space.volume.get_cell(cell) != expected_before:
					all_changed = false
					continue
				var mode := P1MatterInteractor.EditMode.PLACE if present else P1MatterInteractor.EditMode.REMOVE
				if not _interactor.apply_edit_to_cell(_space, cell, mode):
					all_changed = false
	return all_changed


func _move_player_to_space_local(local_position: Vector3) -> void:
	var provider := _space.get_active_provider()
	_player.global_position = provider.to_global(local_position)
	_player.desired_local_velocity = Vector3.ZERO
	_player.world_velocity = Vector3.ZERO
	_player.jump_requested = false
	_player.grounded = false
	_player.support_body = null
	_player.support_space = null
	_player.observed_support_velocity = Vector3.ZERO
	_player.reset_physics_interpolation()


func _camera_avatar_signed_distance() -> float:
	var body := _avatar_body()
	var camera := _camera_rig.get_camera()
	if body == null or camera == null or not (body.mesh is CapsuleMesh):
		return INF
	var capsule := body.mesh as CapsuleMesh
	var local_camera := body.to_local(camera.global_position)
	var axis_half := maxf(0.0, capsule.height * 0.5 - capsule.radius)
	var nearest_axis := Vector3(0.0, clampf(local_camera.y, -axis_half, axis_half), 0.0)
	return local_camera.distance_to(nearest_axis) - capsule.radius


func _actual_arm_length() -> float:
	var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	return _camera_rig.get_camera().global_position.distance_to(spring_arm.global_position)


func _print_camera_avatar_metric(label: String) -> void:
	var body := _avatar_body()
	var camera := _camera_rig.get_camera()
	var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	var local_camera := body.to_local(camera.global_position) if body != null else Vector3.ZERO
	var signed_distance := _camera_avatar_signed_distance()
	var actual_arm := _actual_arm_length()
	var desired_arm := spring_arm.spring_length
	print(
		"P1_RV4_CAMERA_AVATAR_METRIC variant=%s label=%s desired_arm=%.4f actual_arm=%.4f camera_body_local=(%.4f,%.4f,%.4f) avatar_signed=%.4f inside=%s visual_unsafe=%s avatar_visible=%s user_pitch=%.4f runtime_pitch=%.4f" % [
			_variant,
			label,
			desired_arm,
			actual_arm,
			local_camera.x,
			local_camera.y,
			local_camera.z,
			signed_distance,
			str(signed_distance < 0.0),
			str(_is_visual_unsafe(actual_arm, signed_distance)),
			str(_avatar_visible()),
			float(_camera_rig.get("_pitch")),
			float(_camera_rig.get("_runtime_pitch")),
		]
	)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "R-V4 capture %s produced pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "R-V4 capture %s saved PNG" % label)
	if save_error == OK:
		print("P1_RV4_CAMERA_SAFETY_FRAME: variant=%s label=%s %dx%d -> %s" % [_variant, label, image.get_width(), image.get_height(), path])


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _cleanup_and_finish() -> void:
	if _p1 != null and is_instance_valid(_p1):
		_p1.free()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error("P1_RV4_CAMERA_SAFETY_FAIL: " + failure)
	quit(1)
