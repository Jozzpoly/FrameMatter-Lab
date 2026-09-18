extends SceneTree

const ACQUIRE_FRAMES := 18
const ACTOR_LOCAL := Vector3(6.5, 1.95, 8.5)
const PILLAR_XZ := Vector2i(8, 8)
const EXPECTED_REMOVE := Vector3i(8, 5, 8)
const EXPECTED_PLACE := Vector3i(8, 6, 8)
const ORBITS := [
	[0.72, 0.48, 7.2],
	[0.72, 0.34, 7.2],
	[0.72, 0.62, 7.2],
	[0.20, 0.48, 7.2],
	[1.20, 0.48, 7.2],
	[0.72, 0.48, 5.2],
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "pointer challenger loads canonical P1 scene")
	if packed == null:
		_finish()
		return

	var p1 := packed.instantiate()
	get_root().add_child(p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	var space := p1.call("get_space") as LocalMatterSpace
	var player := p1.call("get_player") as SpaceQueryCharacter
	var camera_rig := p1.call("get_camera_rig") as P1CameraRig
	var interactor := p1.call("get_interactor") as P1MatterInteractor
	_check(space != null and player != null and camera_rig != null and interactor != null, "pointer challenger resolves composed roles")
	if space == null or player == null or camera_rig == null or interactor == null:
		p1.free()
		_finish()
		return

	# Build a connected vertical Matter pillar to y=5, the highest legal cell in
	# the current dense storage. Its exposed top face is plainly visible from an
	# ordinary elevated third-person camera, and PLACE across that face resolves
	# to y=6: a real out-of-storage EXPAND request. This avoids demanding that a
	# pointer select a physically hidden outward wall face.
	player.set_physics_process(false)
	for y in range(1, 6):
		var cell := Vector3i(PILLAR_XZ.x, y, PILLAR_XZ.y)
		_check(
			interactor.apply_edit_to_cell(space, cell, P1MatterInteractor.EditMode.PLACE),
			"pointer challenger builds storage-height pillar cell %s" % str(cell)
		)
	await _advance_frames(2)

	var provider := space.get_active_provider()
	_move_player(player, provider.to_global(ACTOR_LOCAL))
	interactor.set_mode(P1MatterInteractor.EditMode.PLACE)

	var top_face_world := provider.to_global(Vector3(
		float(PILLAR_XZ.x) + 0.5,
		6.0,
		float(PILLAR_XZ.y) + 0.5
	))
	var found := false
	var found_screen := Vector2.ZERO
	var found_orbit: Array = []
	for orbit_variant in ORBITS:
		var orbit := orbit_variant as Array
		camera_rig.set("_yaw", float(orbit[0]))
		camera_rig.set("_pitch", float(orbit[1]))
		camera_rig.set("_distance", float(orbit[2]))
		camera_rig.call("_apply_user_orbit_immediately")
		await _advance_frames(2)

		var camera := camera_rig.get_camera()
		var viewport := camera.get_viewport()
		var visible_rect := viewport.get_visible_rect()
		if camera.is_position_behind(top_face_world):
			continue
		var screen := camera.unproject_position(top_face_world)
		if not visible_rect.has_point(screen):
			continue
		interactor.update_target_from_screen_position(screen)
		if (
			interactor.target_space == space
			and interactor.target_valid
			and not interactor.target_in_storage
			and interactor.remove_cell == EXPECTED_REMOVE
			and interactor.place_cell == EXPECTED_PLACE
		):
			found = true
			found_screen = screen
			found_orbit = orbit.duplicate()
			break

	_check(found, "pointer ray can select the visible top face that produces real EXPAND semantics")
	if found:
		var viewport_size := camera_rig.get_camera().get_viewport().get_visible_rect().size
		var face := interactor.place_cell - interactor.remove_cell
		print(
			"P1_POINTER_TARGET_FOUND screen=(%.1f,%.1f) norm=(%.3f,%.3f) yaw=%.3f pitch=%.3f distance=%.2f remove=%s place=%s face=%s" % [
				found_screen.x,
				found_screen.y,
				found_screen.x / viewport_size.x,
				found_screen.y / viewport_size.y,
				float(found_orbit[0]),
				float(found_orbit[1]),
				float(found_orbit[2]),
				str(interactor.remove_cell),
				str(interactor.place_cell),
				str(face),
			]
		)
		_check(face == Vector3i.UP, "pointer EXPAND target preserves exact top-face relation")

	player.set_physics_process(true)
	p1.free()
	_finish()


func _move_player(player: SpaceQueryCharacter, world_position: Vector3) -> void:
	player.global_position = world_position
	player.desired_local_velocity = Vector3.ZERO
	player.world_velocity = Vector3.ZERO
	player.jump_requested = false
	player.grounded = false
	player.support_body = null
	player.support_space = null
	player.observed_support_velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_POINTER_TARGETING_PASS: explicit screen ray selected a visible top-face EXPAND target while preserving canonical collision and face semantics.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_POINTER_TARGETING_FAIL: " + failure)
	quit(1)
