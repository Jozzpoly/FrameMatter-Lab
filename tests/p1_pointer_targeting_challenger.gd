extends SceneTree

const ACQUIRE_FRAMES := 18
const ACTOR_LOCAL := Vector3(1.5, 1.95, 8.5)
const SCREEN_STEP := 24
const EDGE_MARGIN := 24
const ORBITS := [
	[-PI * 0.5, 0.12, 5.2],
	[-PI * 0.45, 0.12, 5.2],
	[-PI * 0.55, 0.12, 5.2],
	[-PI * 0.5, 0.18, 5.2],
	[-PI * 0.45, 0.18, 5.2],
	[-PI * 0.55, 0.18, 5.2],
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

	# Same real boundary geometry as the failed center-reticle evidence state.
	# Only the screen ray source is challenged; Matter/collision/edit semantics
	# remain canonical.
	player.set_physics_process(false)
	for cell in [
		Vector3i(1, 0, 8),
		Vector3i(0, 0, 8),
		Vector3i(0, 1, 8),
		Vector3i(0, 2, 8),
	]:
		_check(
			interactor.apply_edit_to_cell(space, cell, P1MatterInteractor.EditMode.PLACE),
			"pointer challenger builds boundary cell %s" % str(cell)
		)
	await _advance_frames(2)

	var provider := space.get_active_provider()
	_move_player(player, provider.to_global(ACTOR_LOCAL))
	interactor.set_mode(P1MatterInteractor.EditMode.PLACE)

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
		var viewport := camera_rig.get_camera().get_viewport()
		var size := viewport.get_visible_rect().size
		for y in range(EDGE_MARGIN, int(size.y) - EDGE_MARGIN, SCREEN_STEP):
			for x in range(EDGE_MARGIN, int(size.x) - EDGE_MARGIN, SCREEN_STEP):
				var screen := Vector2(float(x), float(y))
				interactor.update_target_from_screen_position(screen)
				if (
					interactor.target_space == space
					and interactor.target_valid
					and not interactor.target_in_storage
				):
					found = true
					found_screen = screen
					found_orbit = orbit.duplicate()
					break
			if found:
				break
		if found:
			break

	_check(found, "pointer ray can select a visible out-of-storage PLACE target on the real boundary")
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
		_check(
			abs(face.x) + abs(face.y) + abs(face.z) == 1,
			"pointer target preserves one exact hit-face relation"
		)

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
		print("P1_POINTER_TARGETING_PASS: explicit screen ray found a visible EXPAND target while preserving canonical collision and face semantics.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_POINTER_TARGETING_FAIL: " + failure)
	quit(1)
