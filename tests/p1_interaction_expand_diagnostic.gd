extends SceneTree

const ACQUIRE_FRAMES := 18
const ACTOR_LOCAL := Vector3(1.5, 1.95, 8.5)
const YAWS := [-PI * 0.5, -PI * 0.45, -PI * 0.55]
const PITCHES := [0.12, 0.18, 0.24, 0.32]
const DISTANCES := [5.2, 7.2]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/main.tscn") as PackedScene
	if packed == null:
		push_error("P1_INTERACTION_EXPAND_DIAGNOSTIC_FAIL: canonical P1 scene did not load")
		quit(1)
		return

	var p1 := packed.instantiate()
	get_root().add_child(p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	var space := p1.call("get_space") as LocalMatterSpace
	var player := p1.call("get_player") as SpaceQueryCharacter
	var camera_rig := p1.call("get_camera_rig") as P1CameraRig
	var interactor := p1.call("get_interactor") as P1MatterInteractor
	if space == null or player == null or camera_rig == null or interactor == null:
		push_error("P1_INTERACTION_EXPAND_DIAGNOSTIC_FAIL: composed roles missing")
		p1.free()
		quit(1)
		return

	player.set_physics_process(false)
	for cell in [
		Vector3i(1, 0, 8),
		Vector3i(0, 0, 8),
		Vector3i(0, 1, 8),
		Vector3i(0, 2, 8),
	]:
		if not interactor.apply_edit_to_cell(space, cell, P1MatterInteractor.EditMode.PLACE):
			push_error("P1_INTERACTION_EXPAND_DIAGNOSTIC_FAIL: could not build boundary cell %s" % str(cell))
			p1.free()
			quit(1)
			return

	var provider := space.get_active_provider()
	_move_player(player, provider.to_global(ACTOR_LOCAL))
	interactor.set_mode(P1MatterInteractor.EditMode.PLACE)
	camera_rig.reset_view()
	await _advance_frames(3)

	for distance_variant in DISTANCES:
		var distance := float(distance_variant)
		for pitch_variant in PITCHES:
			var pitch := float(pitch_variant)
			for yaw_variant in YAWS:
				var yaw := float(yaw_variant)
				camera_rig.set("_yaw", yaw)
				camera_rig.set("_pitch", pitch)
				camera_rig.set("_distance", distance)
				camera_rig.call("_apply_user_orbit_immediately")
				await _advance_frames(1)
				interactor.call("_update_target_from_camera")
				_print_diagnostic(space, player, camera_rig, interactor, yaw, pitch, distance)

	player.set_physics_process(true)
	p1.free()
	print("P1_INTERACTION_EXPAND_DIAGNOSTIC_PASS")
	quit(0)


func _print_diagnostic(
	space: LocalMatterSpace,
	player: SpaceQueryCharacter,
	camera_rig: P1CameraRig,
	interactor: P1MatterInteractor,
	requested_yaw: float,
	requested_pitch: float,
	requested_distance: float
) -> void:
	var camera := camera_rig.get_camera()
	var viewport := camera.get_viewport()
	var center := viewport.get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * interactor.max_distance, interactor.collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var collider_name := "NONE"
	var hit_position := Vector3.ZERO
	var hit_normal := Vector3.ZERO
	if not hit.is_empty():
		var collider := hit.get("collider") as Node
		collider_name = collider.name if collider != null else "UNKNOWN"
		hit_position = Vector3(hit.get("position", Vector3.ZERO))
		hit_normal = Vector3(hit.get("normal", Vector3.ZERO))
	var camera_from_actor := camera.global_position - player.global_position
	print(
		"P1_INTERACTION_EXPAND_DIAG req_yaw=%.3f req_pitch=%.3f req_dist=%.2f camera_from_actor=(%.3f,%.3f,%.3f) collider=%s hit=(%.3f,%.3f,%.3f) normal=(%.3f,%.3f,%.3f) target_space=%s valid=%s in_storage=%s remove=%s place=%s" % [
			requested_yaw,
			requested_pitch,
			requested_distance,
			camera_from_actor.x,
			camera_from_actor.y,
			camera_from_actor.z,
			collider_name,
			hit_position.x,
			hit_position.y,
			hit_position.z,
			hit_normal.x,
			hit_normal.y,
			hit_normal.z,
			str(interactor.target_space == space),
			str(interactor.target_valid),
			str(interactor.target_in_storage),
			str(interactor.remove_cell),
			str(interactor.place_cell),
		]
	)


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