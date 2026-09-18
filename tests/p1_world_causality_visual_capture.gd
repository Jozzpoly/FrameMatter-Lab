extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 3
const MOTION_SEGMENT_FRAMES := 60
const SPLIT_SEPARATION_FRAMES := 45
const POST_FREEZE_FRAMES := 45
const HUD_SAFE_POINT := Vector2(50.0, 50.0)
const MOTION_IMPULSE := Vector3(0.0, 0.0, -72.0)
const MOTION_TORQUE := Vector3(0.0, 360.0, 0.0)
const SIBLING_IMPULSE := Vector3(72.0, 0.0, 0.0)
const SIBLING_TORQUE := Vector3(0.0, -240.0, 0.0)
const VARIANT_BASELINE := "baseline"
const VARIANT_COARSE_GRID := "coarse_grid"

var _failures: Array[String] = []
var _output_dir := ""
var _variant := VARIANT_BASELINE
var _p1: Node
var _source: LocalMatterSpace
var _player: SpaceQueryCharacter
var _camera_rig: P1CameraRig
var _interactor: P1MatterInteractor
var _control: P1SpaceControl


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_WORLD_CAUSALITY_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-world-causality-evidence")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var requested := OS.get_environment("P1_WORLD_CAUSALITY_VARIANT").strip_edges().to_lower()
	if not requested.is_empty():
		_variant = requested
	_check(_variant == VARIANT_BASELINE or _variant == VARIANT_COARSE_GRID, "G6 capture variant is supported")
	if not _failures.is_empty():
		_finish()
		return

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "G6 capture loads canonical P1 scene")
	if packed == null:
		_finish()
		return

	_p1 = packed.instantiate()
	var world_reference := _p1.get_node_or_null("WorldReference") as Node3D
	_check(world_reference != null, "G6 capture resolves authored WorldReference")
	var world_presentation: P1WorldReferencePresentation = null
	if world_reference != null:
		world_presentation = world_reference.get_node_or_null("P1WorldReferencePresentation") as P1WorldReferencePresentation
	_check(world_presentation != null, "G6 capture resolves promoted canonical world datum")
	if world_presentation != null:
		# Both variants use the same production scene and presenter. Baseline only
		# suppresses its visibility so A/B differs by one presentation dimension.
		world_presentation.visible = _variant == VARIANT_COARSE_GRID
	get_root().add_child(_p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	_source = _p1.call("get_space") as LocalMatterSpace
	_player = _p1.call("get_player") as SpaceQueryCharacter
	_camera_rig = _p1.call("get_camera_rig") as P1CameraRig
	_interactor = _p1.call("get_interactor") as P1MatterInteractor
	_control = _p1.call("get_space_control") as P1SpaceControl
	_check(
		_source != null and _player != null and _camera_rig != null and _interactor != null and _control != null,
		"G6 capture resolves real Space/actor/camera/interactor/control roles"
	)
	if _source == null or _player == null or _camera_rig == null or _interactor == null or _control == null:
		_p1.free()
		_finish()
		return

	Input.warp_mouse(HUD_SAFE_POINT)
	await process_frame
	_interactor.update_target_from_pointer_position(HUD_SAFE_POINT)
	_check(_interactor.target_space == null, "G6 capture removes interaction-cue confound under HUD")

	print("P1_WORLD_CAUSALITY_VARIANT: %s" % _variant)
	await _capture("00_static")

	var static_transform := _source.get_active_provider().global_transform
	_check(_control.release_space(_source), "G6 release request succeeds")
	await _source.provider_transition_committed
	await _advance_frames(SETTLE_FRAMES)
	var released_provider := _source.get_active_provider()
	var release_pose_error := _transform_error(static_transform, released_provider.global_transform)
	var released_body := released_provider as RigidBody3D
	_check(released_body != null, "G6 release produces dynamic provider")
	if released_body != null:
		_check(released_body.linear_velocity.length() < 0.0001, "G6 release has zero hidden linear launch")
		_check(released_body.angular_velocity.length() < 0.0001, "G6 release has zero hidden angular launch")
	_check(release_pose_error < 0.0005, "G6 release preserves current world pose")
	print("P1_G6_RELEASE pose_error=%.8f linear=%.6f angular=%.6f" % [
		release_pose_error,
		released_body.linear_velocity.length() if released_body != null else -1.0,
		released_body.angular_velocity.length() if released_body != null else -1.0,
	])
	await _capture("01_released_zero_motion")

	_check(_control.apply_local_central_impulse(_source, MOTION_IMPULSE), "G6 finite translation impulse succeeds")
	_check(_control.apply_local_torque_impulse(_source, MOTION_TORQUE), "G6 finite yaw impulse succeeds")
	await _advance_frames(1)
	await _capture("02_motion_start")
	await _advance_frames(MOTION_SEGMENT_FRAMES)
	await _capture("03_motion_mid")
	await _advance_frames(MOTION_SEGMENT_FRAMES)
	await _capture("04_motion_late")
	var moving_provider := _source.get_active_provider()
	print("P1_G6_MOTION origin=%s yaw=%.4f" % [str(moving_provider.global_position), moving_provider.global_rotation.y])

	# Remove one full local deck seam. The edit API and topology scheduler are the
	# real production paths; the evidence script does not manufacture successors.
	for z in range(2, 14):
		var cut_cell := Vector3i(6, 0, z)
		_check(
			_interactor.apply_edit_to_cell(_source, cut_cell, P1MatterInteractor.EditMode.REMOVE),
			"G6 split removes seam cell %s" % str(cut_cell)
		)
	_check(_source.is_topology_split_pending(), "G6 real seam cut queues topology succession")
	if _source.is_topology_split_pending():
		await _source.topology_split_committed
	await _advance_frames(5)
	var active_spaces: Array[LocalMatterSpace] = _p1.call("get_active_spaces")
	_check(active_spaces.size() == 2, "G6 split produces exactly two live successor Spaces")
	await _capture("05_split_immediate")

	var actor_successor := _p1.call("get_space") as LocalMatterSpace
	_check(actor_successor != null and not actor_successor.is_retired(), "G6 resolves actor/focus successor")
	var sibling: LocalMatterSpace = null
	for space in active_spaces:
		if space != actor_successor:
			sibling = space
			break
	_check(sibling != null and not sibling.is_retired(), "G6 resolves independent sibling successor")
	if actor_successor == null or sibling == null:
		_p1.free()
		_finish()
		return
	_check(actor_successor.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "G6 actor successor remains dynamic after split")
	_check(sibling.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "G6 sibling successor remains dynamic after split")

	var actor_before_separation := actor_successor.get_active_provider().global_position
	var sibling_before_separation := sibling.get_active_provider().global_position
	_check(_control.apply_local_central_impulse(sibling, SIBLING_IMPULSE), "G6 finite impulse applies to sibling only")
	_check(_control.apply_local_torque_impulse(sibling, SIBLING_TORQUE), "G6 finite torque applies to sibling only")
	await _advance_frames(SPLIT_SEPARATION_FRAMES)
	var actor_after_separation := actor_successor.get_active_provider().global_position
	var sibling_after_separation := sibling.get_active_provider().global_position
	var actor_delta := actor_after_separation.distance_to(actor_before_separation)
	var sibling_delta := sibling_after_separation.distance_to(sibling_before_separation)
	_check(sibling_delta > actor_delta + 0.15, "G6 sibling develops independent relative motion")
	print("P1_G6_SPLIT_MOTION actor_delta=%.4f sibling_delta=%.4f relative_extra=%.4f" % [
		actor_delta, sibling_delta, sibling_delta - actor_delta
	])
	await _capture("06_split_independent_motion")

	await _capture("07_pre_freeze_dynamic")
	# request_static() is asynchronous. A moving rigid body may legally advance
	# during the final solver phase before LocalMatterSpace commits replacement at
	# the physics boundary. Therefore request-time -> commit-boundary motion is
	# telemetry, not a pose-reset failure. The actual continuity invariant is the
	# transform copied from the outgoing dynamic provider to the incoming static
	# provider in the transition report.
	var freeze_request_transform := actor_successor.get_active_provider().global_transform
	_check(_control.freeze_space(actor_successor), "G6 freeze request succeeds on actor successor")
	await actor_successor.provider_transition_committed
	var freeze_report := actor_successor.get_last_transition_report()
	var freeze_previous_transform: Transform3D = freeze_report.get("previous_transform", freeze_request_transform)
	var freeze_current_transform: Transform3D = freeze_report.get("current_transform", actor_successor.get_active_provider().global_transform)
	var freeze_phase_advance := _transform_error(freeze_request_transform, freeze_previous_transform)
	var freeze_transition_jump := _transform_error(freeze_previous_transform, freeze_current_transform)
	await _advance_frames(SETTLE_FRAMES)
	var frozen_transform := actor_successor.get_active_provider().global_transform
	var freeze_settle_drift := _transform_error(freeze_current_transform, frozen_transform)
	_check(actor_successor.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "G6 actor successor becomes static")
	_check(freeze_transition_jump < 0.00001, "G6 freeze provider replacement preserves commit-boundary world pose")
	_check(freeze_settle_drift < 0.0001, "G6 newly frozen successor remains at committed world pose")
	print("P1_G6_FREEZE phase_advance=%.8f transition_jump=%.8f settle_drift=%.8f frozen_origin=%s" % [
		freeze_phase_advance,
		freeze_transition_jump,
		freeze_settle_drift,
		str(frozen_transform.origin),
	])
	await _capture("08_post_freeze_same_pose")

	var frozen_before_wait := actor_successor.get_active_provider().global_transform
	var sibling_before_wait := sibling.get_active_provider().global_position
	await _advance_frames(POST_FREEZE_FRAMES)
	var frozen_after_wait := actor_successor.get_active_provider().global_transform
	var sibling_after_wait := sibling.get_active_provider().global_position
	var frozen_drift := _transform_error(frozen_before_wait, frozen_after_wait)
	var sibling_continued := sibling_after_wait.distance_to(sibling_before_wait)
	_check(frozen_drift < 0.0001, "G6 frozen successor remains fixed in world")
	_check(sibling_continued > 0.05, "G6 dynamic sibling continues independently after other successor freezes")
	print("P1_G6_POST_FREEZE frozen_drift=%.8f sibling_motion=%.4f" % [frozen_drift, sibling_continued])
	await _capture("09_frozen_vs_dynamic_sibling")

	_p1.free()
	_finish()


func _transform_error(a: Transform3D, b: Transform3D) -> float:
	var error := 0.0
	for local_point in [Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]:
		error = maxf(error, (a * local_point).distance_to(b * local_point))
	return error


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "%s produced rendered pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "%s saved PNG" % label)
	if save_error == OK:
		print("P1_WORLD_CAUSALITY_FRAME: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_WORLD_CAUSALITY_CAPTURE_PASS: variant=%s release/motion/split/freeze sequence completed." % _variant)
		quit(0)
		return
	for failure in _failures:
		push_error("P1_WORLD_CAUSALITY_CAPTURE_FAIL: " + failure)
	quit(1)
