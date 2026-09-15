extends SceneTree

# G8 adversarial rehearsal. This script is injected into the frozen runtime
# checkout as an untracked test-only file; production candidate bytes remain
# untouched. One live canonical scene is stressed continuously across camera,
# edits, finite motion, storage maintenance, topology, mixed successor state and
# automatic fall recovery.

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 6
const MOTION_FRAMES := 24
const POST_REBASE_FRAMES := 4
const POST_SPLIT_FRAMES := 6
const SIBLING_MOTION_FRAMES := 45
const SIBLING_PULSE_COUNT := 3
const SIBLING_PULSE_GAP_FRAMES := 2
const POST_FREEZE_FRAMES := 4
const MAX_RECOVERY_FRAMES := 240

const CLOSE_WALL_LOCAL := Vector3(4.65, 1.94, 6.5)
const FAR_AIRBORNE_WORLD := Vector3(34.5, -7.0, 0.0)
const CENTRAL_IMPULSE := Vector3(0.0, 0.0, -36.0)
const TORQUE_IMPULSE := Vector3(0.0, 180.0, 0.0)
const SIBLING_IMPULSE := Vector3(36.0, 0.0, 0.0)
const EDGE_Z := 8
const BURST_CELLS := [
	Vector3i(3, 2, 5),
	Vector3i(3, 2, 6),
	Vector3i(3, 2, 7),
]

var _failures: Array[String] = []
var _output_dir := ""
var _p1: Node
var _source: LocalMatterSpace
var _player: SpaceQueryCharacter
var _camera_rig: P1CameraRig
var _interactor: P1MatterInteractor
var _control: P1SpaceControl


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_G8_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-g8-adversarial")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "G8 loads canonical P1 scene")
	if packed == null:
		_finish()
		return

	_p1 = packed.instantiate()
	get_root().add_child(_p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	_source = _p1.call("get_space") as LocalMatterSpace
	_player = _p1.call("get_player") as SpaceQueryCharacter
	_camera_rig = _p1.call("get_camera_rig") as P1CameraRig
	_interactor = _p1.call("get_interactor") as P1MatterInteractor
	_control = _p1.call("get_space_control") as P1SpaceControl
	var panel := _p1.get_node_or_null("HUD/Panel") as PanelContainer
	_check(
		_source != null and _player != null and _camera_rig != null and _interactor != null and _control != null,
		"G8 resolves canonical runtime roles"
	)
	_check(panel != null and panel.size.x <= 340.0 and panel.size.y <= 64.0, "G8 begins with bounded canonical HUD")
	if _source == null or _player == null or _camera_rig == null or _interactor == null or _control == null:
		_cleanup_and_finish()
		return

	_check(_source.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "G8 begins from STATIC Matter")
	_check(_player.grounded and _player.support_space == _source, "G8 actor begins grounded on source Space")
	await _capture("00_start_static")

	# 1. Begin from a real Matter obstruction rather than a synthetic camera wall.
	_camera_rig.reset_view()
	_move_player_to_space_local(_source, CLOSE_WALL_LOCAL)
	await _advance_frames(SETTLE_FRAMES)
	var provider := _source.get_active_provider()
	var wall_world := provider.to_global(Vector3(3.5, 1.6, 6.5))
	var to_wall: Vector3 = wall_world - _player.global_position
	to_wall.y = 0.0
	if to_wall.length_squared() > 0.000001:
		_camera_rig.set("_yaw", atan2(to_wall.x, to_wall.z))
		_camera_rig.call("_apply_user_orbit_immediately")
	await _advance_frames(SETTLE_FRAMES)
	var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	var actual_arm := _camera_rig.get_camera().global_position.distance_to(spring_arm.global_position)
	var desired_arm := spring_arm.spring_length
	var close_arm_ratio := actual_arm / desired_arm if desired_arm > 0.001 else 0.0
	_check(close_arm_ratio >= 0.75, "G8 close Matter obstruction does not collapse camera into unusable compression")
	await _capture("01_close_matter_camera_stress")

	# 2. Rapidly mutate and restore real authored Matter while the camera is in the
	# difficult near-wall composition. This pressures render/collision/state
	# rebuilds without changing topology or relying on a reset.
	for cell in BURST_CELLS:
		_check(_source.volume.get_cell(cell) != CellVolume.EMPTY, "G8 burst source cell exists %s" % str(cell))
		_check(_interactor.apply_edit_to_cell(_source, cell, P1MatterInteractor.EditMode.REMOVE), "G8 burst removes %s" % str(cell))
		await _advance_frames(1)
		_check(not _source.is_topology_split_pending(), "G8 burst removal does not accidentally queue topology split")
	for cell in BURST_CELLS:
		_check(_interactor.apply_edit_to_cell(_source, cell, P1MatterInteractor.EditMode.PLACE), "G8 burst restores %s" % str(cell))
		await _advance_frames(1)
	await _capture("02_close_camera_after_rapid_edit_burst")

	# Return the actor to the canonical safe relation without recreating the scene.
	_p1.call("recover_player_for_test")
	_camera_rig.reset_view()
	await _advance_frames(SETTLE_FRAMES)
	_check(_player.grounded and _player.support_space == _source, "G8 actor reacquires original Space after close-camera stress")

	# 3. Release must remain a pure representation change even after the prior
	# camera/edit pressure.
	_check(_control.release_space(_source), "G8 queues zero-launch release")
	await _source.provider_transition_committed
	await _advance_frames(3)
	var body := _source.get_active_provider() as ConstructBody
	_check(body != null, "G8 release installs dynamic provider")
	if body == null:
		_cleanup_and_finish()
		return
	_check(body.linear_velocity.length() < 0.0001 and body.angular_velocity.length() < 0.0001, "G8 release still contributes zero hidden motion")
	await _capture("03_zero_launch_release_after_stress")

	# 4. Apply production-scale finite motion, then keep editing while the same
	# logical Space is moving.
	_check(_control.apply_local_central_impulse(_source, CENTRAL_IMPULSE), "G8 finite translation impulse accepted")
	_check(_control.apply_local_torque_impulse(_source, TORQUE_IMPULSE), "G8 finite yaw impulse accepted")
	await _advance_frames(MOTION_FRAMES)
	body = _source.get_active_provider() as ConstructBody
	_check(body != null and body.linear_velocity.length() > 0.01 and body.angular_velocity.length() > 0.001, "G8 finite motion remains solver-owned and measurable")
	_check(_player.grounded and _player.support_space == _source, "G8 actor rides moving source after prior stress")
	await _capture("04_finite_motion_after_camera_edit_stress")

	_check(_interactor.apply_edit_to_cell(_source, Vector3i(1, 0, EDGE_Z), P1MatterInteractor.EditMode.PLACE), "G8 moving edit reaches first storage edge cell")
	await _advance_frames(1)
	_check(_interactor.apply_edit_to_cell(_source, Vector3i(0, 0, EDGE_Z), P1MatterInteractor.EditMode.PLACE), "G8 moving edit reaches second storage edge cell")
	await _advance_frames(1)
	await _capture("05_moving_edge_edit_pressure")

	# 5. Force real non-zero storage maintenance while motion is active.
	var provider_id_before_rebase := _source.get_active_provider().get_instance_id()
	var support_local_before_rebase := _player.support_local_center
	var linear_before_rebase := body.linear_velocity
	var angular_before_rebase := body.angular_velocity
	var source_edge_cell := Vector3i(-1, 0, EDGE_Z)
	_check(_interactor.request_place_to_cell(_source, source_edge_cell), "G8 moving out-of-storage placement requests maintenance")
	_check(_source.is_storage_rebase_pending(), "G8 rebase is pending before physics boundary")
	await _source.storage_rebase_committed
	var rebase_report: Dictionary = _source.get_last_storage_rebase_report()
	var local_shift: Vector3i = rebase_report["local_shift"]
	_check(local_shift != Vector3i.ZERO, "G8 performs real non-zero storage-frame shift")
	_check(_source.get_active_provider().get_instance_id() == provider_id_before_rebase, "G8 rebase preserves provider identity")
	_check(_player.support_local_center.distance_to(support_local_before_rebase + Vector3(local_shift)) < 0.001, "G8 actor support coordinates remap across moving rebase")
	await process_frame
	await _advance_frames(POST_REBASE_FRAMES)
	var mapped_edge_cell := source_edge_cell + local_shift
	_check(_source.volume.in_bounds(mapped_edge_cell) and _source.volume.get_cell(mapped_edge_cell) != CellVolume.EMPTY, "G8 deferred mapped placement commits after rebase")
	body = _source.get_active_provider() as ConstructBody
	var linear_rebase_error := body.linear_velocity.distance_to(linear_before_rebase) if body != null else INF
	var angular_rebase_error := body.angular_velocity.distance_to(angular_before_rebase) if body != null else INF
	_check(linear_rebase_error < 0.02 and angular_rebase_error < 0.02, "G8 rebase preserves moving solver state")
	_check(_player.grounded and _player.support_space == _source, "G8 actor remains attached after moving rebase")
	await _capture("06_post_rebase_under_motion")

	# 6. Immediately push the already-stressed/rebased moving Space through
	# one-to-many topology succession.
	var actor_local_before_split := _player.support_local_center
	for z in range(2, 14):
		var cut_cell := Vector3i(6, 0, z) + local_shift
		_check(_interactor.apply_edit_to_cell(_source, cut_cell, P1MatterInteractor.EditMode.REMOVE), "G8 mapped split cut removes %s" % str(cut_cell))
		if z < 13:
			_check(not _source.is_topology_split_pending(), "G8 partial split cut remains connected")
	_check(_source.is_topology_split_pending(), "G8 final split edit queues topology succession")
	await _source.topology_split_committed
	var split_result: LocalMatterSplitResult = _source.get_last_split_result()
	var handoff_world_error := INF
	_check(split_result != null and split_result.size() == 2, "G8 split produces exactly two successors")
	if split_result != null:
		var expected_handoff_world := split_result.source_transform * actor_local_before_split
		handoff_world_error = _player.global_position.distance_to(expected_handoff_world)
		_check(handoff_world_error < 0.0001, "G8 actor handoff remains world-continuous")
	await _advance_frames(POST_SPLIT_FRAMES)
	var active_spaces: Array[LocalMatterSpace] = _p1.call("get_active_spaces") as Array[LocalMatterSpace]
	var actor_successor: LocalMatterSpace = _player.support_space
	_check(active_spaces.size() == 2 and actor_successor != null and active_spaces.has(actor_successor), "G8 actor owns one of two live successors")
	await _capture("07_immediate_split_after_rebase_motion")

	var sibling: LocalMatterSpace = null
	for candidate in active_spaces:
		if candidate != actor_successor:
			sibling = candidate
			break
	_check(sibling != null and sibling.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "G8 sibling successor remains independently dynamic")
	var sibling_origin_before := Vector3.ZERO
	if sibling != null:
		sibling_origin_before = sibling.get_active_provider().global_position
		# A single legal pulse was insufficient to make the heavier sibling's
		# independence visually readable in the first G8 run. Keep the acceptance
		# threshold and use a short burst of the same production-scale finite pulse
		# rather than injecting velocity or weakening the criterion.
		for pulse in range(SIBLING_PULSE_COUNT):
			_check(
				_control.apply_local_central_impulse(sibling, SIBLING_IMPULSE),
				"G8 sibling-only finite pulse %d/%d accepted" % [pulse + 1, SIBLING_PULSE_COUNT]
			)
			await _advance_frames(SIBLING_PULSE_GAP_FRAMES)
	await _advance_frames(SIBLING_MOTION_FRAMES)
	var sibling_delta := 0.0
	if sibling != null:
		sibling_delta = sibling.get_active_provider().global_position.distance_to(sibling_origin_before)
		_check(sibling_delta > 0.75, "G8 sibling establishes materially independent motion")
	await _capture("08_independent_successors_under_motion")

	# 7. Freeze only the actor-owned successor after all prior pressure while the
	# sibling continues dynamic, then immediately stress recovery.
	_check(actor_successor != null and _control.freeze_space(actor_successor), "G8 actor successor queues freeze")
	if actor_successor != null:
		await actor_successor.provider_transition_committed
	await _advance_frames(POST_FREEZE_FRAMES)
	_check(actor_successor != null and actor_successor.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "G8 actor successor becomes STATIC")
	_check(sibling != null and sibling.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "G8 sibling remains DYNAMIC")
	_check(_player.grounded and _player.support_space == actor_successor, "G8 actor remains supported through mixed successor state")
	await _capture("09_frozen_actor_successor_dynamic_sibling")

	# 8. Real fall/recovery path: first hold the actor in the known difficult far
	# airborne composition, then re-enable actor physics and let gravity cross the
	# production y<-12 automatic-recovery threshold. No explicit recovery helper
	# is used for the actual recovery event.
	_player.set_physics_process(false)
	_move_player_world(FAR_AIRBORNE_WORLD)
	await _advance_frames(6)
	_check(_player.global_position.distance_to(FAR_AIRBORNE_WORLD) <= 0.001, "G8 preserves exact far-airborne pre-fall state")
	_check(not _player.grounded and _player.support_space == null, "G8 far-airborne state has no fake support")
	await _capture("10_far_airborne_before_automatic_recovery")
	_player.set_physics_process(true)

	var recovery_frames := 0
	var recovered := false
	for i in range(MAX_RECOVERY_FRAMES):
		await physics_frame
		await process_frame
		recovery_frames = i + 1
		if _player.global_position.y > -5.0 and _player.global_position.distance_to(FAR_AIRBORNE_WORLD) > 10.0:
			recovered = true
			break
	_check(recovered, "G8 production automatic fall recovery triggers within bounded time")
	await _advance_frames(SETTLE_FRAMES)
	_check(_player.grounded and _player.support_space == actor_successor, "G8 actor reacquires frozen actor successor after automatic recovery")
	_check(_camera_rig.context_target == actor_successor.get_active_provider(), "G8 camera reacquires recovered actor successor")
	await _capture("11_post_automatic_fall_recovery")

	print(
		"P1_G8_ADVERSARIAL_METRIC close_arm_ratio=%.4f rebase_shift=%s linear_rebase_error=%.8f angular_rebase_error=%.8f handoff_world_error=%.8f sibling_pulses=%d sibling_delta=%.4f recovery_frames=%d successors=%d" % [
			close_arm_ratio, str(local_shift), linear_rebase_error, angular_rebase_error,
			handoff_world_error, SIBLING_PULSE_COUNT, sibling_delta, recovery_frames, active_spaces.size(),
		]
	)
	_cleanup_and_finish()


func _move_player_to_space_local(space: LocalMatterSpace, local_position: Vector3) -> void:
	var provider := space.get_active_provider()
	if provider != null:
		_move_player_world(provider.to_global(local_position))


func _move_player_world(world_position: Vector3) -> void:
	_player.global_position = world_position
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
	_check(image != null and not image.is_empty(), "G8 capture %s produced rendered pixels" % label)
	if image == null or image.is_empty():
		return
	var camera := _camera_rig.get_camera()
	_check(not camera.is_position_behind(_player.global_position), "G8 %s keeps actor in front of camera" % label)
	var actor_screen := camera.unproject_position(_player.global_position)
	var actor_norm := Vector2(actor_screen.x / image.get_width(), actor_screen.y / image.get_height())
	_check(actor_norm.x >= 0.01 and actor_norm.x <= 0.99 and actor_norm.y >= 0.20 and actor_norm.y <= 0.97, "G8 %s keeps actor in usable viewport" % label)
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "G8 capture %s saved PNG" % label)
	if save_error == OK:
		print("P1_G8_FRAME: %s actor_norm=(%.3f,%.3f) %dx%d -> %s" % [label, actor_norm.x, actor_norm.y, image.get_width(), image.get_height(), path])


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _cleanup_and_finish() -> void:
	if _player != null:
		_player.set_physics_process(true)
	if _p1 != null and is_instance_valid(_p1):
		_p1.free()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("P1_G8_ADVERSARIAL_REHEARSAL_PASS: one frozen canonical runtime survived close-Matter camera pressure, rapid edits, zero-launch release, finite motion, moving storage rebase, topology succession, mixed successor state and production automatic fall recovery.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_G8_ADVERSARIAL_REHEARSAL_FAIL: " + failure)
	quit(1)
