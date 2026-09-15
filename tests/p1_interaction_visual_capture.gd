extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 2
const FEEDBACK_EXPIRE_FRAMES := 96
const CENTER_ACTOR_LOCAL := Vector3(8.5, 2.15, 8.5)
const EXPAND_ACTOR_LOCAL := Vector3(6.5, 1.95, 8.5)
const EXPAND_REMOVE := Vector3i(8, 5, 8)
const EXPAND_PLACE := Vector3i(8, 6, 8)
const POINTER_SCAN_STEP := 52
const POINTER_CENTER_EXCLUSION := 0.18
const HUD_PROBE_POINT := Vector2(50.0, 50.0)
const POINTER_ORBITS := [
	[0.72, 0.48, 7.2],
	[0.20, 0.48, 7.2],
	[1.20, 0.48, 7.2],
	[0.72, 0.62, 7.2],
]
const EXPAND_ORBITS := [
	[0.72, 0.48, 7.2],
	[0.72, 0.62, 7.2],
	[0.72, 0.78, 7.2],
	[0.72, 0.95, 7.2],
	[0.20, 0.62, 7.2],
	[1.20, 0.62, 7.2],
	[0.20, 0.78, 7.2],
	[1.20, 0.78, 7.2],
	[0.72, 0.78, 9.0],
]

var _failures: Array[String] = []
var _output_dir := ""
var _p1: Node
var _space: LocalMatterSpace
var _player: SpaceQueryCharacter
var _camera_rig: P1CameraRig
var _interactor: P1MatterInteractor
var _target_presentation: P1MatterTargetPresentation
var _feedback: P1InteractionFeedback


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_INTERACTION_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-interaction-evidence/production")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "G5 production capture loads canonical P1 scene")
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
	_target_presentation = _p1.get_node_or_null("P1MatterTargetPresentation") as P1MatterTargetPresentation
	_feedback = _p1.get_node_or_null("HUD/P1InteractionFeedback") as P1InteractionFeedback
	_check(
		_space != null and _player != null and _camera_rig != null and _interactor != null,
		"G5 production capture resolves composed interaction roles"
	)
	_check(_target_presentation != null, "G5 production scene owns one target presentation consumer")
	_check(_feedback != null, "G5 production scene owns transient interaction feedback consumer")
	_check(
		_interactor != null and _interactor.targeting_mode == P1MatterInteractor.TargetingMode.POINTER,
		"G5 production interaction uses pointer acquisition"
	)
	_check(_p1.get_node_or_null("HUD/Reticle") == null, "G5 production HUD has no false center reticle")
	if _interactor != null:
		_check(_interactor.get_node_or_null("TargetOutline") == null, "G5 retired legacy TargetOutline is absent")
	if _target_presentation != null and _interactor != null:
		_check(_target_presentation.interactor == _interactor, "G5 production presenter binds existing interactor authority")
	if _feedback != null and _interactor != null:
		_check(_feedback.interactor == _interactor, "G5 transient feedback binds existing interactor authority")
	if (
		_space == null
		or _player == null
		or _camera_rig == null
		or _interactor == null
		or _target_presentation == null
		or _feedback == null
	):
		_p1.free()
		_finish()
		return

	# Deterministic evidence drives the same production pointer-safe resolver with
	# explicit screen positions; disable only live mouse polling during capture.
	_player.set_physics_process(false)
	_interactor.set_process(false)

	_check(_interactor.pointer_blocker != null, "G5 production interactor binds HUD pointer blocker")
	if _interactor.pointer_blocker != null:
		_check(
			_interactor.pointer_blocker.get_global_rect().has_point(HUD_PROBE_POINT),
			"G5 HUD probe point is physically inside pointer blocker"
		)
	_interactor.update_target_from_pointer_position(HUD_PROBE_POINT)
	_check(_interactor.target_space == null and not _interactor.target_valid, "G5 pointer cannot target Matter through HUD")
	print("P1_INTERACTION_UI_BLOCK_PASS point=%s target_cleared=%s" % [str(HUD_PROBE_POINT), str(_interactor.target_space == null)])

	var remove_state := await _find_pointer_target(P1MatterInteractor.EditMode.REMOVE, CENTER_ACTOR_LOCAL)
	_check(not remove_state.is_empty(), "G5 production resolves an off-center visible REMOVE target")
	if not remove_state.is_empty():
		await _capture_pointer_target("00_remove_target", "REMOVE", remove_state, true)
		var removed_cell := _interactor.remove_cell
		var remove_screen: Vector2 = remove_state["screen"]
		_check(_interactor.apply_current_edit(), "G5 real REMOVE mutation succeeds from promoted pointer target")
		_check(_feedback.is_feedback_visible(), "G5 successful edit produces transient feedback")
		_check(_feedback.get_feedback_text() == "REMOVED", "G5 successful REMOVE feedback is semantically explicit")
		_interactor.update_target_from_pointer_position(remove_screen)
		_target_presentation.refresh_now()
		await _capture_pixels("01_remove_success_feedback")

		# A real user rejection occurs under the live pointer. Keep the OS/window
		# pointer aligned with the explicit evidence ray so the production fallback
		# anchor is tested rather than an artificial centered test cursor.
		Input.warp_mouse(remove_screen)
		await process_frame
		var live_pointer := _camera_rig.get_camera().get_viewport().get_mouse_position()
		_check(live_pointer.distance_to(remove_screen) <= 2.0, "G5 evidence cursor matches rejected interaction point")
		_check(
			not _interactor.apply_edit_to_cell(_space, removed_cell, P1MatterInteractor.EditMode.REMOVE),
			"G5 repeated REMOVE is actually rejected"
		)
		_check(_feedback.is_feedback_visible(), "G5 rejected edit produces transient feedback")
		_check(_feedback.get_feedback_text() == "BLOCKED", "G5 rejection feedback is semantically explicit")
		await _capture_pixels("02_remove_rejection_feedback")
		await _advance_frames(FEEDBACK_EXPIRE_FRAMES)
		_check(not _feedback.is_feedback_visible(), "G5 transient feedback expires instead of becoming persistent telemetry")
		print("P1_INTERACTION_FEEDBACK_EXPIRE_PASS frames=%d" % FEEDBACK_EXPIRE_FRAMES)

	var place_state := await _find_pointer_target(P1MatterInteractor.EditMode.PLACE, CENTER_ACTOR_LOCAL)
	_check(not place_state.is_empty(), "G5 production resolves an off-center visible PLACE target")
	if not place_state.is_empty():
		await _capture_pointer_target("03_place_target", "PLACE", place_state, true)

	for y in range(1, 6):
		var cell := Vector3i(8, y, 8)
		if _space.volume.get_cell(cell) == CellVolume.EMPTY:
			_check(
				_interactor.apply_edit_to_cell(_space, cell, P1MatterInteractor.EditMode.PLACE),
				"G5 production builds storage-height pillar cell %s" % str(cell)
			)
	await _advance_frames(2)

	var expand_state := await _find_exact_expand_target()
	_check(not expand_state.is_empty(), "G5 production resolves visible out-of-storage EXPAND target")
	if not expand_state.is_empty():
		await _capture_pointer_target("04_expand_target", "EXPAND", expand_state, false)
		_check(_interactor.remove_cell == EXPAND_REMOVE, "G5 EXPAND resolves exact source top cell")
		_check(_interactor.place_cell == EXPAND_PLACE, "G5 EXPAND resolves exact out-of-storage destination")
		_check(_interactor.place_cell - _interactor.remove_cell == Vector3i.UP, "G5 EXPAND preserves exact +Y hit face")

	_interactor.set_process(true)
	_player.set_physics_process(true)
	_p1.free()
	_finish()


func _find_pointer_target(mode: int, actor_local: Vector3) -> Dictionary:
	var provider := _space.get_active_provider()
	if provider == null:
		return {}
	_move_player_world(provider.to_global(actor_local))
	_interactor.set_mode(mode)
	_camera_rig.reset_view()
	await _advance_frames(SETTLE_FRAMES)

	for orbit_variant in POINTER_ORBITS:
		var orbit := orbit_variant as Array
		_camera_rig.set("_yaw", float(orbit[0]))
		_camera_rig.set("_pitch", float(orbit[1]))
		_camera_rig.set("_distance", float(orbit[2]))
		_camera_rig.call("_apply_user_orbit_immediately")
		await _advance_frames(SETTLE_FRAMES)

		var viewport := _camera_rig.get_camera().get_viewport()
		var rect := viewport.get_visible_rect()
		for y in range(int(rect.size.y * 0.24), int(rect.size.y * 0.86), POINTER_SCAN_STEP):
			for x in range(int(rect.size.x * 0.12), int(rect.size.x * 0.88), POINTER_SCAN_STEP):
				var screen := rect.position + Vector2(float(x), float(y))
				var norm := Vector2(float(x) / rect.size.x, float(y) / rect.size.y)
				if norm.distance_to(Vector2(0.5, 0.5)) < POINTER_CENTER_EXCLUSION:
					continue
				_interactor.update_target_from_pointer_position(screen)
				if _interactor.target_space != _space or not _interactor.target_valid or not _interactor.target_in_storage:
					continue
				var face := _interactor.place_cell - _interactor.remove_cell
				if absi(face.x) + absi(face.y) + absi(face.z) != 1:
					continue
				return {"screen": screen, "norm": norm, "orbit": orbit.duplicate()}
	return {}


func _find_exact_expand_target() -> Dictionary:
	var provider := _space.get_active_provider()
	if provider == null:
		return {}
	_move_player_world(provider.to_global(EXPAND_ACTOR_LOCAL))
	_interactor.set_mode(P1MatterInteractor.EditMode.PLACE)
	_camera_rig.reset_view()
	await _advance_frames(SETTLE_FRAMES)
	var top_face_world := provider.to_global(Vector3(8.5, 6.0, 8.5))

	for orbit_variant in EXPAND_ORBITS:
		var orbit := orbit_variant as Array
		_camera_rig.set("_yaw", float(orbit[0]))
		_camera_rig.set("_pitch", float(orbit[1]))
		_camera_rig.set("_distance", float(orbit[2]))
		_camera_rig.call("_apply_user_orbit_immediately")
		await _advance_frames(SETTLE_FRAMES)
		var camera := _camera_rig.get_camera()
		var rect := camera.get_viewport().get_visible_rect()
		if camera.is_position_behind(top_face_world):
			continue
		var screen := camera.unproject_position(top_face_world)
		if not rect.has_point(screen):
			continue
		var norm := Vector2(screen.x / rect.size.x, screen.y / rect.size.y)
		if norm.x < 0.05 or norm.x > 0.95 or norm.y < 0.22 or norm.y > 0.95:
			continue
		_interactor.update_target_from_pointer_position(screen)
		if (
			_interactor.target_space == _space
			and _interactor.target_valid
			and not _interactor.target_in_storage
			and _interactor.remove_cell == EXPAND_REMOVE
			and _interactor.place_cell == EXPAND_PLACE
		):
			return {"screen": screen, "norm": norm, "orbit": orbit.duplicate()}
	return {}


func _capture_pointer_target(
	label: String,
	semantic_name: String,
	state: Dictionary,
	expect_in_storage: bool
) -> void:
	var screen: Vector2 = state["screen"]
	var norm: Vector2 = state["norm"]
	_interactor.update_target_from_pointer_position(screen)
	_check(_interactor.target_space == _space, "%s targets the live authored Space" % label)
	_check(_interactor.target_valid, "%s remains actionable" % label)
	_check(_interactor.target_in_storage == expect_in_storage, "%s storage relation matches %s" % [label, semantic_name])
	var face := _interactor.place_cell - _interactor.remove_cell
	_check(absi(face.x) + absi(face.y) + absi(face.z) == 1, "%s resolves one exact hit face" % label)
	print(
		"P1_INTERACTION_PRODUCTION_TRUTH label=%s semantic=%s screen_norm=(%.3f,%.3f) target=%s remove=%s place=%s face=%s in_storage=%s" % [
			label, semantic_name, norm.x, norm.y, str(_interactor.get_target_cell()),
			str(_interactor.remove_cell), str(_interactor.place_cell), str(face), str(_interactor.target_in_storage),
		]
	)
	_target_presentation.refresh_now()
	await _capture_pixels(label)


func _capture_pixels(label: String) -> void:
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
		print("P1_INTERACTION_CAPTURE_FRAME: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


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


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_INTERACTION_CAPTURE_PASS: promoted pointer acquisition, UI exclusion, face-led prediction and transient success/rejection feedback rendered on D3D12.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_INTERACTION_CAPTURE_FAIL: " + failure)
	quit(1)
