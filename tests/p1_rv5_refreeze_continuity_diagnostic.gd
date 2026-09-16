extends SceneTree

# Diagnostic-only follow-up to the R-V5 rendered finding. This lane does not
# change production behavior. It isolates the final DYNAMIC -> STATIC refreeze
# from the later camera reset and records authority/support/interpolation truth
# at several temporal checkpoints.

const ACQUIRE_FRAMES := 30
const PRE_MOTION_SETTLE_FRAMES := 60
const MOTION_FRAMES := 180
const DYNAMIC_NEAR_FRAMES := 120
const ACTOR_LOCAL := Vector3(8.5, 2.15, 8.5)
const CENTRAL_IMPULSE := Vector3(0.0, 0.0, -36.0)
const TORQUE_IMPULSE := Vector3(0.0, 90.0, 0.0)
const TRANSFORM_EPSILON := 0.0001
const SUPPORT_WORLD_EPSILON := 0.02

const REMOVE_CELLS := [
	Vector3i(5, 0, 4),
	Vector3i(5, 0, 5),
	Vector3i(6, 0, 5),
	Vector3i(10, 0, 10),
	Vector3i(10, 0, 11),
	Vector3i(9, 0, 11),
	Vector3i(3, 2, 5),
	Vector3i(3, 2, 6),
	Vector3i(3, 1, 7),
	Vector3i(3, 2, 8),
	Vector3i(11, 1, 8),
	Vector3i(12, 1, 9),
]

const PLACE_CELLS := [
	Vector3i(5, 1, 10),
	Vector3i(6, 1, 10),
	Vector3i(6, 2, 10),
	Vector3i(7, 1, 10),
	Vector3i(7, 2, 10),
	Vector3i(7, 3, 10),
	Vector3i(9, 1, 4),
	Vector3i(9, 2, 4),
	Vector3i(10, 1, 4),
	Vector3i(12, 1, 4),
	Vector3i(12, 2, 4),
	Vector3i(12, 3, 4),
	Vector3i(5, 1, 12),
	Vector3i(5, 2, 12),
]

var _failures: Array[String] = []
var _output_dir := ""
var _p1: Node
var _space: LocalMatterSpace
var _player: SpaceQueryCharacter
var _camera_rig: P1CameraRig
var _interactor: P1MatterInteractor
var _control: P1SpaceControl


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_RV5_REFREEZE_DIAG_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-rv5-refreeze-diagnostic")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "diagnostic loads canonical P1 scene")
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
	_control = _p1.call("get_space_control") as P1SpaceControl
	_check(
		_space != null and _player != null and _camera_rig != null and _interactor != null and _control != null,
		"diagnostic resolves canonical P1 roles"
	)
	if _space == null or _player == null or _camera_rig == null or _interactor == null or _control == null:
		_cleanup_and_finish()
		return

	# Reproduce the exact accumulated R-V5 dirty geometry while actor locomotion
	# is paused. This is setup, not a new presentation experiment.
	_player.set_physics_process(false)
	_interactor.set_process(false)
	_move_player_to_space_local(ACTOR_LOCAL)
	for cell in REMOVE_CELLS:
		_check(_interactor.apply_edit_to_cell(_space, cell, P1MatterInteractor.EditMode.REMOVE), "dirty REMOVE accepted %s" % str(cell))
		await _advance_frames(2)
	for cell in PLACE_CELLS:
		_check(_interactor.apply_edit_to_cell(_space, cell, P1MatterInteractor.EditMode.PLACE), "dirty PLACE accepted %s" % str(cell))
		await _advance_frames(2)
	_check(_space.volume.count_solid() == 163, "diagnostic reproduces R-V5 163-cell dirty corpus")

	# Re-enter the real actor/support loop exactly as R-V5 did before motion.
	_interactor.set_process(true)
	_player.set_physics_process(true)
	_p1.call("recover_player_for_test")
	_camera_rig.reset_view()
	await _advance_frames(PRE_MOTION_SETTLE_FRAMES)
	_check(_player.grounded and _player.support_space == _space, "actor reacquires dirty Space before motion")

	_check(_control.release_space(_space), "diagnostic releases dirty Space")
	await _space.provider_transition_committed
	await _advance_frames(8)
	_check(_space.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "dirty Space becomes DYNAMIC")
	_check(_control.apply_local_central_impulse(_space, CENTRAL_IMPULSE), "diagnostic applies translation impulse")
	_check(_control.apply_local_torque_impulse(_space, TORQUE_IMPULSE), "diagnostic applies yaw impulse")
	await _advance_frames(MOTION_FRAMES)
	_check(_player.grounded and _player.support_space == _space, "actor remains supported before refreeze")

	_set_camera_orbit(1.18, 0.62, 3.6)
	await _advance_frames(DYNAMIC_NEAR_FRAMES)
	_print_state("00_pre_freeze_dynamic_near")
	await _capture("00_pre_freeze_dynamic_near")

	# Freeze, then deliberately do NOT reset the camera. The checkpoints below
	# distinguish provider commit, actor support convergence and presentation
	# interpolation from the later artificial reset used by the original R-V5.
	_check(_control.freeze_space(_space), "diagnostic queues refreeze")
	await _space.provider_transition_committed
	_check(_space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "refreeze commits STATIC provider")
	_check_transition_continuity()
	_print_state("01_post_freeze_commit")
	await _capture("01_post_freeze_commit")

	await _advance_frames(1)
	_print_state("02_post_freeze_01f_no_reset")
	await _capture("02_post_freeze_01f_no_reset")

	await _advance_frames(7)
	_check_support_continuity("post-freeze 8f")
	_print_state("03_post_freeze_08f_no_reset")
	await _capture("03_post_freeze_08f_no_reset")

	await _advance_frames(82)
	_check_support_continuity("post-freeze 90f")
	_print_state("04_post_freeze_90f_no_reset")
	await _capture("04_post_freeze_90f_no_reset")

	# Only now reproduce the harness-owned camera reset that contaminated the old
	# final checkpoint. Any discontinuity beginning here belongs to a different
	# causal class from provider/support continuity.
	_camera_rig.reset_view()
	await _advance_frames(1)
	_print_state("05_post_reset_01f")
	await _capture("05_post_reset_01f")

	await _advance_frames(59)
	_check_support_continuity("post-reset 60f")
	_print_state("06_post_reset_60f")
	await _capture("06_post_reset_60f")

	_cleanup_and_finish()


func _check_transition_continuity() -> void:
	var report: Dictionary = _space.get_last_transition_report()
	_check(not report.is_empty(), "refreeze exposes provider transition report")
	if report.is_empty():
		return
	var previous_transform: Transform3D = report.get("previous_transform", Transform3D.IDENTITY)
	var current_transform: Transform3D = report.get("current_transform", Transform3D.IDENTITY)
	var origin_error := previous_transform.origin.distance_to(current_transform.origin)
	var basis_error := _basis_max_axis_error(previous_transform.basis, current_transform.basis)
	print("P1_RV5_REFREEZE_TRANSITION origin_error=%.9f basis_error=%.9f previous_provider=%s current_provider=%s" % [
		origin_error,
		basis_error,
		str(report.get("previous_provider_id", 0)),
		str(report.get("current_provider_id", 0)),
	])
	_check(origin_error <= TRANSFORM_EPSILON, "provider refreeze preserves direct world origin")
	_check(basis_error <= TRANSFORM_EPSILON, "provider refreeze preserves direct world basis")


func _check_support_continuity(label: String) -> void:
	var provider := _space.get_active_provider()
	_check(_player.grounded, "%s actor remains grounded" % label)
	_check(_player.support_space == _space, "%s actor remains on same logical Space" % label)
	_check(_player.support_body == provider, "%s support body converges to active provider" % label)
	if provider == null:
		return
	var reconstructed := provider.to_global(_player.support_local_center)
	var error := reconstructed.distance_to(_player.global_position)
	print("P1_RV5_REFREEZE_SUPPORT label=%s world_error=%.9f" % [label, error])
	_check(error <= SUPPORT_WORLD_EPSILON, "%s actor world position matches logical support frame" % label)


func _print_state(label: String) -> void:
	var provider := _space.get_active_provider()
	var camera := _camera_rig.get_camera()
	var context_target := _camera_rig.context_target
	var provider_id := provider.get_instance_id() if provider != null else 0
	var support_id := _player.support_body.get_instance_id() if _player.support_body != null and is_instance_valid(_player.support_body) else 0
	var context_id := context_target.get_instance_id() if context_target != null and is_instance_valid(context_target) else 0
	var direct_center := Vector3.ZERO
	var interpolated_center := Vector3.ZERO
	var direct_interp_error := -1.0
	var direct_screen := Vector2(-1.0, -1.0)
	var interp_screen := Vector2(-1.0, -1.0)
	var direct_behind := true
	var interp_behind := true
	if provider != null:
		var local_center := _space.get_content_center_local()
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
	if provider != null and _player.grounded and _player.support_space == _space:
		support_world_error = provider.to_global(_player.support_local_center).distance_to(_player.global_position)

	var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	var actual_arm := camera.global_position.distance_to(spring_arm.global_position)
	print(
		"P1_RV5_REFREEZE_STATE label=%s provider_kind=%d provider_id=%d grounded=%s support_space_same=%s support_id=%d support_equals_provider=%s support_world_error=%.6f player=%s direct_center=%s interp_center=%s direct_interp_error=%.6f context_id=%d context_equals_provider=%s camera=%s desired_arm=%.4f actual_arm=%.4f user_pitch=%.4f runtime_pitch=%.4f direct_behind=%s direct_screen=(%.4f,%.4f) interp_behind=%s interp_screen=(%.4f,%.4f)" % [
			label,
			_space.get_provider_kind(),
			provider_id,
			str(_player.grounded),
			str(_player.support_space == _space),
			support_id,
			str(_player.support_body == provider),
			support_world_error,
			str(_player.global_position),
			str(direct_center),
			str(interpolated_center),
			direct_interp_error,
			context_id,
			str(context_target == provider),
			str(camera.global_position),
			spring_arm.spring_length,
			actual_arm,
			float(_camera_rig.get("_pitch")),
			float(_camera_rig.get("_runtime_pitch")),
			str(direct_behind),
			direct_screen.x,
			direct_screen.y,
			str(interp_behind),
			interp_screen.x,
			interp_screen.y,
		]
	)


func _basis_max_axis_error(a: Basis, b: Basis) -> float:
	return maxf(a.x.distance_to(b.x), maxf(a.y.distance_to(b.y), a.z.distance_to(b.z)))


func _set_camera_orbit(yaw: float, pitch: float, distance: float) -> void:
	_camera_rig.set("_yaw", yaw)
	_camera_rig.set("_pitch", pitch)
	_camera_rig.set("_distance", distance)
	_camera_rig.call("_apply_user_orbit_immediately")


func _move_player_to_space_local(local_position: Vector3) -> void:
	var provider := _space.get_active_provider()
	if provider == null:
		return
	_player.global_position = provider.to_global(local_position)
	_player.desired_local_velocity = Vector3.ZERO
	_player.world_velocity = Vector3.ZERO
	_player.jump_requested = false
	_player.grounded = false
	_player.support_body = null
	_player.support_space = null
	_player.observed_support_velocity = Vector3.ZERO
	_player.reset_physics_interpolation()


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "capture %s produced pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "capture %s saved PNG" % label)
	if save_error == OK:
		print("P1_RV5_REFREEZE_CAPTURE %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


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
		print("P1_RV5_REFREEZE_DIAGNOSTIC_PASS: provider transform and actor support continuity survived; inspect checkpoint pixels and interpolation/screen metrics to classify the R-V5 rendered failure.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_RV5_REFREEZE_DIAGNOSTIC_FAIL: " + failure)
	quit(1)
