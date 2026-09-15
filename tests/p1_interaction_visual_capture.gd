extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 1
const CENTER_ACTOR_LOCAL := Vector3(8.5, 2.15, 8.5)
const EXPAND_ACTOR_LOCAL := Vector3(6.5, 1.95, 8.5)
const EXPAND_REMOVE := Vector3i(8, 5, 8)
const EXPAND_PLACE := Vector3i(8, 6, 8)
const USABLE_TOP_NORM := 0.22
const SCAN_YAWS := [
	0.72,
	0.0,
	PI * 0.25,
	PI * 0.5,
	PI * 0.75,
	PI,
	-PI * 0.75,
	-PI * 0.5,
	-PI * 0.25,
]
const SCAN_PITCHES := [0.48, 0.34, 0.62, 0.78]
const SCAN_DISTANCES := [5.2, 7.2, 4.0]
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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_INTERACTION_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-interaction-evidence")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "G5 capture loads canonical P1 scene")
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
		"G5 capture resolves real P1 Space/actor/camera/interactor"
	)
	if _space == null or _player == null or _camera_rig == null or _interactor == null:
		_p1.free()
		_finish()
		return

	# Target semantics, not player locomotion, are under test here. Hold the actor
	# at exact authored positions while the real interactor performs real physics
	# rays against canonical Matter collision.
	_player.set_physics_process(false)

	var remove_found := await _find_center_target(P1MatterInteractor.EditMode.REMOVE, CENTER_ACTOR_LOCAL)
	_check(remove_found, "G5 baseline resolves an actionable in-storage REMOVE target")
	if remove_found:
		await _capture_center_target("00_remove_target", "REMOVE")

	var place_found := await _find_center_target(P1MatterInteractor.EditMode.PLACE, CENTER_ACTOR_LOCAL)
	_check(place_found, "G5 baseline resolves an actionable in-storage PLACE target")
	if place_found:
		await _capture_center_target("01_place_target", "PLACE")

	# Build a connected pillar through y=5, the highest legal dense-storage cell.
	# Its top face is physically visible. PLACE across that face resolves to y=6,
	# providing a real EXPAND target without asking the interaction system to pick
	# an occluded boundary face.
	for y in range(1, 6):
		var cell := Vector3i(8, y, 8)
		_check(
			_interactor.apply_edit_to_cell(_space, cell, P1MatterInteractor.EditMode.PLACE),
			"G5 A/B builds storage-height pillar cell %s" % str(cell)
		)
	await _advance_frames(2)

	var ab_state := await _find_expand_ab_state()
	_check(not ab_state.is_empty(), "G5 A/B finds one usable-view state where pointer reaches visible EXPAND and center reticle does not")
	if not ab_state.is_empty():
		await _capture_expand_ab(ab_state)

	_interactor.set_process(true)
	_player.set_physics_process(true)
	_p1.free()
	_finish()


func _find_center_target(mode: int, actor_local: Vector3) -> bool:
	var provider := _space.get_active_provider()
	if provider == null:
		return false
	_move_player_world(provider.to_global(actor_local))
	_interactor.set_mode(mode)
	_camera_rig.reset_view()
	await _advance_frames(2)

	for distance_variant in SCAN_DISTANCES:
		var distance := float(distance_variant)
		for pitch_variant in SCAN_PITCHES:
			var pitch := float(pitch_variant)
			for yaw_variant in SCAN_YAWS:
				var yaw := float(yaw_variant)
				_camera_rig.set("_yaw", yaw)
				_camera_rig.set("_pitch", pitch)
				_camera_rig.set("_distance", distance)
				_camera_rig.call("_apply_user_orbit_immediately")
				await _advance_frames(SETTLE_FRAMES)
				_interactor.call("_update_target_from_camera")
				if _interactor.target_space == _space and _interactor.target_valid and _interactor.target_in_storage:
					print(
						"P1_INTERACTION_TARGET_FOUND mode=%s yaw=%.3f pitch=%.3f distance=%.2f remove=%s place=%s face=%s" % [
							_interactor.get_mode_name(),
							yaw,
							pitch,
							distance,
							str(_interactor.remove_cell),
							str(_interactor.place_cell),
							str(_interactor.place_cell - _interactor.remove_cell),
						]
					)
					return true
	return false


func _find_expand_ab_state() -> Dictionary:
	var provider := _space.get_active_provider()
	if provider == null:
		return {}
	_move_player_world(provider.to_global(EXPAND_ACTOR_LOCAL))
	_interactor.set_mode(P1MatterInteractor.EditMode.PLACE)
	_camera_rig.reset_view()
	await _advance_frames(2)
	_interactor.set_process(false)

	var top_face_world := provider.to_global(Vector3(8.5, 6.0, 8.5))
	for orbit_variant in EXPAND_ORBITS:
		var orbit := orbit_variant as Array
		_camera_rig.set("_yaw", float(orbit[0]))
		_camera_rig.set("_pitch", float(orbit[1]))
		_camera_rig.set("_distance", float(orbit[2]))
		_camera_rig.call("_apply_user_orbit_immediately")
		await _advance_frames(2)

		var camera := _camera_rig.get_camera()
		var viewport := camera.get_viewport()
		var visible_rect := viewport.get_visible_rect()
		if camera.is_position_behind(top_face_world):
			continue
		var screen := camera.unproject_position(top_face_world)
		if not visible_rect.has_point(screen):
			continue
		var norm := Vector2(screen.x / visible_rect.size.x, screen.y / visible_rect.size.y)
		if norm.x < 0.05 or norm.x > 0.95 or norm.y < USABLE_TOP_NORM or norm.y > 0.95:
			continue

		_interactor.update_target_from_screen_position(screen)
		var pointer_hits_expand := (
			_interactor.target_space == _space
			and _interactor.target_valid
			and not _interactor.target_in_storage
			and _interactor.remove_cell == EXPAND_REMOVE
			and _interactor.place_cell == EXPAND_PLACE
		)
		if not pointer_hits_expand:
			continue

		_interactor.call("_update_target_from_camera")
		var center_hits_same_expand := (
			_interactor.target_space == _space
			and _interactor.target_valid
			and not _interactor.target_in_storage
			and _interactor.remove_cell == EXPAND_REMOVE
			and _interactor.place_cell == EXPAND_PLACE
		)
		if center_hits_same_expand:
			continue

		print(
			"P1_INTERACTION_AB_STATE screen=(%.1f,%.1f) norm=(%.3f,%.3f) yaw=%.3f pitch=%.3f distance=%.2f center_remove=%s center_place=%s center_valid=%s center_in_storage=%s" % [
				screen.x,
				screen.y,
				norm.x,
				norm.y,
				float(orbit[0]),
				float(orbit[1]),
				float(orbit[2]),
				str(_interactor.remove_cell),
				str(_interactor.place_cell),
				str(_interactor.target_valid),
				str(_interactor.target_in_storage),
			]
		)
		return {"screen": screen, "norm": norm, "orbit": orbit.duplicate()}
	return {}


func _capture_center_target(label: String, semantic_name: String) -> void:
	_interactor.call("_update_target_from_camera")
	_check(_interactor.target_space == _space, "%s targets the live authored Space" % label)
	_check(_interactor.target_valid, "%s target remains actionable at capture" % label)
	_check(_interactor.target_in_storage, "%s remains an in-storage %s target" % [label, semantic_name])
	var face := _interactor.place_cell - _interactor.remove_cell
	_check(abs(face.x) + abs(face.y) + abs(face.z) == 1, "%s resolves one exact hit face" % label)
	print(
		"P1_INTERACTION_TRUTH label=%s semantic=%s target_cell=%s remove=%s place=%s face=%s in_storage=%s valid=%s" % [
			label,
			semantic_name,
			str(_interactor.get_target_cell()),
			str(_interactor.remove_cell),
			str(_interactor.place_cell),
			str(face),
			str(_interactor.target_in_storage),
			str(_interactor.target_valid),
		]
	)
	await _capture_pixels(label)


func _capture_expand_ab(ab_state: Dictionary) -> void:
	var screen: Vector2 = ab_state["screen"]
	var norm: Vector2 = ab_state["norm"]

	# Same camera, same world, same frame semantics. First capture the canonical
	# center-reticle result. The visible storage-height top face is on-screen but
	# the center ray resolves somewhere else.
	_interactor.call("_update_target_from_camera")
	var center_remove := _interactor.remove_cell
	var center_place := _interactor.place_cell
	var center_valid := _interactor.target_valid
	var center_in_storage := _interactor.target_in_storage
	_check(
		not (
			_interactor.target_space == _space
			and center_valid
			and not center_in_storage
			and center_remove == EXPAND_REMOVE
			and center_place == EXPAND_PLACE
		),
		"center-reticle baseline does not silently target the off-center EXPAND face"
	)
	print(
		"P1_INTERACTION_TRUTH label=02_expand_center_reticle_miss semantic=CENTER_MISS visible_expand_screen_norm=(%.3f,%.3f) center_remove=%s center_place=%s center_valid=%s center_in_storage=%s" % [
			norm.x,
			norm.y,
			str(center_remove),
			str(center_place),
			str(center_valid),
			str(center_in_storage),
		]
	)
	await _capture_pixels("02_expand_center_reticle_miss")

	# Now change only the ray source to the exact visible top-face screen point.
	_interactor.update_target_from_screen_position(screen)
	_check(_interactor.target_space == _space, "pointer A/B targets the live authored Space")
	_check(_interactor.target_valid, "pointer A/B target is actionable")
	_check(not _interactor.target_in_storage, "pointer A/B target carries real EXPAND semantics")
	_check(_interactor.remove_cell == EXPAND_REMOVE, "pointer A/B resolves exact source top cell")
	_check(_interactor.place_cell == EXPAND_PLACE, "pointer A/B resolves exact out-of-storage destination cell")
	var face := _interactor.place_cell - _interactor.remove_cell
	_check(face == Vector3i.UP, "pointer A/B preserves exact +Y hit face")
	print(
		"P1_INTERACTION_TRUTH label=03_expand_pointer_hit semantic=EXPAND screen=(%.1f,%.1f) norm=(%.3f,%.3f) remove=%s place=%s face=%s" % [
			screen.x,
			screen.y,
			norm.x,
			norm.y,
			str(_interactor.remove_cell),
			str(_interactor.place_cell),
			str(face),
		]
	)
	await _capture_pixels("03_expand_pointer_hit")


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
		print("P1_INTERACTION_CAPTURE_PASS: D3D12 evidence captured canonical REMOVE/PLACE plus same-frame visible EXPAND center-miss versus explicit-screen-ray hit.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_INTERACTION_CAPTURE_FAIL: " + failure)
	quit(1)
