extends SceneTree

# R-V5 current-development visual rehearsal. Unlike historical G8, this test
# deliberately leaves authored geometry dirty: REMOVE and PLACE mutations
# accumulate and remain present while camera, interaction, state and motion are
# exercised on the same live P1 scene.

const ACQUIRE_FRAMES := 30
const EDIT_STEP_FRAMES := 3
const BATCH_DWELL_FRAMES := 90
const CAMERA_DWELL_FRAMES := 120
const TARGET_DWELL_FRAMES := 90
const PRE_MOTION_SETTLE_FRAMES := 60
const MOTION_FRAMES := 180
const DYNAMIC_NEAR_FRAMES := 120
const FINAL_DWELL_FRAMES := 90
const MIN_PERSISTENT_EDITS := 20
const POINTER_SCAN_STEP := 48
const POINTER_CENTER_EXCLUSION := 0.12
const ACTOR_LOCAL := Vector3(8.5, 2.15, 8.5)
const CENTRAL_IMPULSE := Vector3(0.0, 0.0, -36.0)
const TORQUE_IMPULSE := Vector3(0.0, 90.0, 0.0)

const REMOVE_CELLS := [
	# Two irregular floor holes / concavities.
	Vector3i(5, 0, 4),
	Vector3i(5, 0, 5),
	Vector3i(6, 0, 5),
	Vector3i(10, 0, 10),
	Vector3i(10, 0, 11),
	Vector3i(9, 0, 11),
	# Carve the authored vertical masses instead of restoring them.
	Vector3i(3, 2, 5),
	Vector3i(3, 2, 6),
	Vector3i(3, 1, 7),
	Vector3i(3, 2, 8),
	Vector3i(11, 1, 8),
	Vector3i(12, 1, 9),
]

const PLACE_CELLS := [
	# A stepped/protruding cluster.
	Vector3i(5, 1, 10),
	Vector3i(6, 1, 10),
	Vector3i(6, 2, 10),
	Vector3i(7, 1, 10),
	Vector3i(7, 2, 10),
	Vector3i(7, 3, 10),
	# Narrow local features / pillars.
	Vector3i(9, 1, 4),
	Vector3i(9, 2, 4),
	Vector3i(10, 1, 4),
	Vector3i(12, 1, 4),
	Vector3i(12, 2, 4),
	Vector3i(12, 3, 4),
	Vector3i(5, 1, 12),
	Vector3i(5, 2, 12),
]

const POINTER_ORBITS := [
	[0.72, 0.48, 7.2],
	[0.20, 0.52, 6.4],
	[1.20, 0.58, 7.2],
	[0.72, 0.72, 5.2],
]

var _failures: Array[String] = []
var _output_dir := ""
var _p1: Node
var _space: LocalMatterSpace
var _player: SpaceQueryCharacter
var _camera_rig: P1CameraRig
var _interactor: P1MatterInteractor
var _target_presentation: P1MatterTargetPresentation
var _control: P1SpaceControl
var _initial_solid_count := 0
var _initial_revision := 0
var _persistent_edits := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_RV5_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-rv5-chaotic-owner-surface")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "R-V5 loads canonical P1 scene")
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
	_target_presentation = _p1.get_node_or_null("P1MatterTargetPresentation") as P1MatterTargetPresentation
	_check(
		_space != null and _player != null and _camera_rig != null and _interactor != null and _control != null and _target_presentation != null,
		"R-V5 resolves canonical composed runtime roles"
	)
	if (
		_space == null or _player == null or _camera_rig == null
		or _interactor == null or _control == null or _target_presentation == null
	):
		_cleanup_and_finish()
		return

	_check(_space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "R-V5 begins from STATIC Space")
	_initial_solid_count = _space.volume.count_solid()
	_initial_revision = _space.volume.revision
	_check(_initial_solid_count == 161, "R-V5 begins from expected authored 161-cell corpus")

	# Deterministic authored-session camera. Freeze only actor locomotion while the
	# world is being edited; all Matter mutations still use the production Space
	# and interactor path and rebuild real render/collision representation.
	_player.set_physics_process(false)
	_interactor.set_process(false)
	_move_player_to_space_local(ACTOR_LOCAL)
	_camera_rig.reset_view()
	await _advance_frames(30)
	await _capture("00_start_static")

	# 26 persistent edits. Nothing in these batches is restored. The three
	# checkpoints make the movie readable as entropy accumulates rather than only
	# showing a before/after pair.
	for index in range(REMOVE_CELLS.size()):
		var cell: Vector3i = REMOVE_CELLS[index]
		_check(_space.volume.get_cell(cell) != CellVolume.EMPTY, "R-V5 remove source exists %s" % str(cell))
		if _interactor.apply_edit_to_cell(_space, cell, P1MatterInteractor.EditMode.REMOVE):
			_persistent_edits += 1
		else:
			_check(false, "R-V5 persistent REMOVE accepted %s" % str(cell))
		await _advance_frames(EDIT_STEP_FRAMES)
		if index == 7:
			await _advance_frames(BATCH_DWELL_FRAMES)
			await _capture("01_chaos_after_08_removes")

	for index in range(PLACE_CELLS.size()):
		var cell: Vector3i = PLACE_CELLS[index]
		_check(_space.volume.get_cell(cell) == CellVolume.EMPTY, "R-V5 place destination begins empty %s" % str(cell))
		if _interactor.apply_edit_to_cell(_space, cell, P1MatterInteractor.EditMode.PLACE):
			_persistent_edits += 1
		else:
			_check(false, "R-V5 persistent PLACE accepted %s" % str(cell))
		await _advance_frames(EDIT_STEP_FRAMES)
		if index == 3:
			await _advance_frames(BATCH_DWELL_FRAMES)
			await _capture("02_chaos_after_16_edits")

	await _advance_frames(BATCH_DWELL_FRAMES)
	_check(_persistent_edits == REMOVE_CELLS.size() + PLACE_CELLS.size(), "R-V5 records every authored persistent edit")
	_check(_persistent_edits >= MIN_PERSISTENT_EDITS, "R-V5 exceeds minimum persistent edit count")
	_check(
		_space.volume.count_solid() == _initial_solid_count - REMOVE_CELLS.size() + PLACE_CELLS.size(),
		"R-V5 accumulated volume matches non-restored edit arithmetic"
	)
	_check(
		_space.volume.revision >= _initial_revision + _persistent_edits,
		"R-V5 logical volume revision proves accumulated mutation history"
	)

	# Near composition on the already irregular world. This is intentionally not
	# the isolated R-V4 ring fixture: the camera has to cope with the ordinary
	# authored scene after sustained destructive/constructive edits.
	_set_camera_orbit(0.28, 0.58, 3.4)
	await _advance_frames(CAMERA_DWELL_FRAMES)
	_print_camera_metric("03_chaos_near")
	await _capture("03_chaos_26_near")

	# Exercise production REMOVE and PLACE pointer semantics with state/focus/grid
	# still visible on the dirty world. These are target rehearsals, not cleanup.
	var remove_target := await _find_pointer_target(P1MatterInteractor.EditMode.REMOVE)
	_check(not remove_target.is_empty(), "R-V5 resolves REMOVE target on accumulated irregular Matter")
	if not remove_target.is_empty():
		_target_presentation.refresh_now()
		await _advance_frames(TARGET_DWELL_FRAMES)
		await _capture("04_chaos_remove_target")

	var place_target := await _find_pointer_target(P1MatterInteractor.EditMode.PLACE)
	_check(not place_target.is_empty(), "R-V5 resolves PLACE target on accumulated irregular Matter")
	if not place_target.is_empty():
		_target_presentation.refresh_now()
		await _advance_frames(TARGET_DWELL_FRAMES)
		await _capture("05_chaos_place_target")

	# Mid-distance composed view after all geometry entropy is present.
	_set_camera_orbit(0.92, 0.52, 7.2)
	await _advance_frames(CAMERA_DWELL_FRAMES)
	_print_camera_metric("06_chaos_mid")
	await _capture("06_chaos_mid_composed")

	# Reacquire real support, then change state and move the same irregular Space.
	_interactor.set_process(true)
	_player.set_physics_process(true)
	_p1.call("recover_player_for_test")
	_camera_rig.reset_view()
	await _advance_frames(PRE_MOTION_SETTLE_FRAMES)
	_check(_player.grounded and _player.support_space == _space, "R-V5 actor reacquires irregular Space before motion")

	_check(_control.release_space(_space), "R-V5 releases irregular Space to DYNAMIC")
	await _space.provider_transition_committed
	await _advance_frames(8)
	_check(_space.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "R-V5 irregular Space becomes DYNAMIC")
	_check(_control.apply_local_central_impulse(_space, CENTRAL_IMPULSE), "R-V5 applies finite translation to irregular Space")
	_check(_control.apply_local_torque_impulse(_space, TORQUE_IMPULSE), "R-V5 applies finite yaw to irregular Space")
	await _advance_frames(MOTION_FRAMES)
	_check(_player.grounded and _player.support_space == _space, "R-V5 actor remains supported on moving irregular Space")
	_print_camera_metric("07_dynamic_irregular_motion")
	await _capture("07_dynamic_irregular_motion")

	_set_camera_orbit(1.18, 0.62, 3.6)
	await _advance_frames(DYNAMIC_NEAR_FRAMES)
	_print_camera_metric("08_dynamic_irregular_near")
	await _capture("08_dynamic_irregular_near")

	_check(_control.freeze_space(_space), "R-V5 refreezes irregular Space")
	await _space.provider_transition_committed
	await _advance_frames(FINAL_DWELL_FRAMES)
	_check(_space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "R-V5 final irregular Space is STATIC")
	_check(_space.volume.count_solid() == _initial_solid_count - REMOVE_CELLS.size() + PLACE_CELLS.size(), "R-V5 final state preserves all accumulated edits")
	_check(_persistent_edits >= MIN_PERSISTENT_EDITS, "R-V5 final state still represents accumulated session rather than reset")
	_camera_rig.reset_view()
	await _advance_frames(60)
	_print_camera_metric("09_refrozen_irregular_final")
	await _capture("09_refrozen_irregular_final")

	print(
		"P1_RV5_CHAOS_METRIC persistent_edits=%d removes=%d places=%d initial_solid=%d final_solid=%d revision_delta=%d movie_nominal_fps=30" % [
			_persistent_edits,
			REMOVE_CELLS.size(),
			PLACE_CELLS.size(),
			_initial_solid_count,
			_space.volume.count_solid(),
			_space.volume.revision - _initial_revision,
		]
	)

	_cleanup_and_finish()


func _find_pointer_target(mode: int) -> Dictionary:
	_interactor.set_mode(mode)
	for orbit_variant in POINTER_ORBITS:
		var orbit := orbit_variant as Array
		_set_camera_orbit(float(orbit[0]), float(orbit[1]), float(orbit[2]))
		await _advance_frames(12)
		var viewport := _camera_rig.get_camera().get_viewport()
		var rect := viewport.get_visible_rect()
		for y in range(int(rect.size.y * 0.24), int(rect.size.y * 0.88), POINTER_SCAN_STEP):
			for x in range(int(rect.size.x * 0.10), int(rect.size.x * 0.90), POINTER_SCAN_STEP):
				var screen := rect.position + Vector2(float(x), float(y))
				var norm := Vector2(float(x) / rect.size.x, float(y) / rect.size.y)
				if norm.distance_to(Vector2(0.5, 0.5)) < POINTER_CENTER_EXCLUSION:
					continue
				_interactor.update_target_from_pointer_position(screen)
				if _interactor.target_space != _space or not _interactor.target_valid:
					continue
				if mode == P1MatterInteractor.EditMode.PLACE and not _interactor.target_in_storage:
					continue
				var face := _interactor.place_cell - _interactor.remove_cell
				if absi(face.x) + absi(face.y) + absi(face.z) != 1:
					continue
				print(
					"P1_RV5_TARGET semantic=%s screen_norm=(%.3f,%.3f) remove=%s place=%s face=%s" % [
						"REMOVE" if mode == P1MatterInteractor.EditMode.REMOVE else "PLACE",
						norm.x, norm.y,
						str(_interactor.remove_cell), str(_interactor.place_cell), str(face),
					]
				)
				return {"screen": screen, "norm": norm, "orbit": orbit.duplicate()}
	return {}


func _set_camera_orbit(yaw: float, pitch: float, distance: float) -> void:
	_camera_rig.set("_yaw", yaw)
	_camera_rig.set("_pitch", pitch)
	_camera_rig.set("_distance", distance)
	_camera_rig.call("_apply_user_orbit_immediately")


func _print_camera_metric(label: String) -> void:
	var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	var camera := _camera_rig.get_camera()
	var actual_arm := camera.global_position.distance_to(spring_arm.global_position)
	var desired_arm := spring_arm.spring_length
	var ratio := actual_arm / desired_arm if desired_arm > 0.001 else 0.0
	print(
		"P1_RV5_CAMERA_METRIC label=%s desired_arm=%.4f actual_arm=%.4f arm_ratio=%.4f user_pitch=%.4f runtime_pitch=%.4f" % [
			label,
			desired_arm,
			actual_arm,
			ratio,
			float(_camera_rig.get("_pitch")),
			float(_camera_rig.get("_runtime_pitch")),
		]
	)
	_check(actual_arm > 0.45, "%s avoids catastrophic sub-0.45m camera collapse" % label)


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
	_check(image != null and not image.is_empty(), "R-V5 capture %s produced pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "R-V5 capture %s saved PNG" % label)
	if save_error == OK:
		print("P1_RV5_CAPTURE_FRAME: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


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
		print("P1_RV5_CHAOTIC_OWNER_SURFACE_PASS: accumulated non-restored geometry, near/mid camera, composed interaction targets and post-entropy STATIC/DYNAMIC motion completed without mechanical invariant failure; rendered gestalt still requires human review.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_RV5_CHAOTIC_OWNER_SURFACE_FAIL: " + failure)
	quit(1)
