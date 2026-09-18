extends SceneTree

const ACQUIRE_FRAMES := 24
const SETTLE_FRAMES := 2
const DRIVE_FRAMES := 90
const TARGET_CELL := Vector3i(15, 5, 16)
const SCAN_STEP := 28
const ACTOR_LOCAL_CANDIDATES := [
	Vector3(18.5, 7.2, 17.5),
	Vector3(19.5, 7.2, 17.5),
	Vector3(18.5, 7.2, 19.5),
	Vector3(21.0, 7.2, 17.0),
]
const ORBITS := [
	[0.72, 0.48, 7.2],
	[0.35, 0.48, 7.2],
	[1.10, 0.48, 7.2],
	[0.72, 0.65, 7.2],
	[0.20, 0.62, 9.0],
	[1.20, 0.62, 9.0],
]

var _failures: Array[String] = []
var _output_dir := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("C6_INTERACTION_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/convergence-c6/interaction")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "C6 pointer evidence loads exact Owner-facing recovery scene")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	var player := root.call("get_player") as SpaceQueryCharacter
	var camera_rig := root.call("get_camera_rig") as P1CameraRig
	var interactor := root.call("get_interactor") as P1MatterInteractor
	_check(world != null and player != null and camera_rig != null and interactor != null, "C6 pointer evidence resolves real scene roles")
	if world == null or player == null or camera_rig == null or interactor == null:
		_finish(root)
		return

	_check(InputMap.has_action("p1_structural_seam"), "production InputMap exposes structural-seam action")
	_check(_action_has_h_key(), "production structural-seam action is physically bound to H")
	_check(interactor.targeting_mode == P1MatterInteractor.TargetingMode.POINTER, "production recovery interaction remains pointer-owned")

	player.set_physics_process(false)
	interactor.set_process(false)

	var found := await _find_exact_target(player, camera_rig, interactor, world)
	_check(not found.is_empty(), "real production pointer can visibly resolve the authored C6 seam target cell")
	if found.is_empty():
		player.set_physics_process(true)
		interactor.set_process(true)
		_finish(root)
		return

	var screen: Vector2 = found["screen"]
	interactor.update_target_from_pointer_position(screen)
	_check(interactor.target_space == world, "pointer targets ordinary canonical WORLD Matter")
	_check(interactor.remove_cell == TARGET_CELL, "pointer resolves the exact C6 target Matter cell")
	_check(interactor.target_valid, "pointer target is actionable")

	await _capture("00_structural_seam_target")

	Input.warp_mouse(screen)
	await process_frame
	var live_pointer := camera_rig.get_camera().get_viewport().get_mouse_position()
	_check(live_pointer.distance_to(screen) <= 2.0, "OS/window pointer is aligned with the qualified Matter target")

	var event := InputEventKey.new()
	event.keycode = KEY_H
	event.physical_keycode = KEY_H
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame

	var release := InputEventKey.new()
	release.keycode = KEY_H
	release.physical_keycode = KEY_H
	release.pressed = false
	Input.parse_input_event(release)

	var authoring: Dictionary = root.call("get_c6_last_authoring_result_for_test")
	_check(bool(authoring.get("accepted", false)), "actual H input invokes the bounded structural-seam authoring path")
	_check(int(authoring.get("candidate_count", 0)) == 1, "actual pointer/H input resolves exactly one structural-law candidate")
	var committed_during_input_turn := bool(root.call("has_c6_active_relation_for_test"))
	_check(
		world.is_authority_partition_pending() or committed_during_input_turn,
		"actual pointer/H input either queues or already atomically commits real authority composition"
	)
	if world.is_authority_partition_pending():
		await world.authority_partition_committed
	elif not committed_during_input_turn:
		player.set_physics_process(true)
		interactor.set_process(true)
		_finish(root)
		return

	var result := world.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "actual input produces the live dynamic relation island")
	_check(bool(root.call("has_c6_active_relation_for_test")), "actual input manifests logical relation truth")
	_check(root.call("get_c6_relation_joint_for_test") != null, "actual input manifests passive solver host")
	if target == null:
		player.set_physics_process(true)
		interactor.set_process(true)
		_finish(root)
		return

	player.set_physics_process(true)
	interactor.set_process(true)
	await _advance_frames(DRIVE_FRAMES)
	var body := target.get_active_provider() as ConstructBody
	_check(body != null, "actual-input island remains dynamically represented")
	_check(bool(root.call("has_c6_active_relation_for_test")), "actual-input relation remains live during ordinary gravity")
	_check(root.get_node_or_null("C6StructuralSeamMarker") != null, "rendered world exposes a minimal structural-seam marker")
	await _capture("01_structural_relation_live")

	print(
		"C6_POINTER_INPUT_METRIC screen=(%.1f,%.1f) norm=(%.4f,%.4f) target=%s candidates=%d selected=%d relation_live=%s"
		% [
			screen.x, screen.y,
			float(found["norm"].x), float(found["norm"].y),
			str(interactor.remove_cell),
			int(authoring.get("candidate_count", 0)),
			int(authoring.get("selected_cells", 0)),
			str(bool(root.call("has_c6_active_relation_for_test"))),
		]
	)

	_finish(root)


func _find_exact_target(
	player: SpaceQueryCharacter,
	camera_rig: P1CameraRig,
	interactor: P1MatterInteractor,
	world: LocalMatterSpace
) -> Dictionary:
	var provider := world.get_active_provider()
	if provider == null:
		return {}

	for actor_local_variant in ACTOR_LOCAL_CANDIDATES:
		var actor_local: Vector3 = actor_local_variant
		_move_player(player, provider.to_global(actor_local))
		for orbit_variant in ORBITS:
			var orbit := orbit_variant as Array
			camera_rig.set("_yaw", float(orbit[0]))
			camera_rig.set("_pitch", float(orbit[1]))
			camera_rig.set("_distance", float(orbit[2]))
			camera_rig.call("_apply_user_orbit_immediately")
			await _advance_frames(SETTLE_FRAMES)

			var viewport := camera_rig.get_camera().get_viewport()
			var rect := viewport.get_visible_rect()
			for y in range(int(rect.size.y * 0.18), int(rect.size.y * 0.92), SCAN_STEP):
				for x in range(int(rect.size.x * 0.08), int(rect.size.x * 0.92), SCAN_STEP):
					var screen := rect.position + Vector2(float(x), float(y))
					interactor.update_target_from_screen_position(screen)
					if (
						interactor.target_space == world
						and interactor.target_valid
						and interactor.remove_cell == TARGET_CELL
					):
						return {
							"screen": screen,
							"norm": Vector2(screen.x / rect.size.x, screen.y / rect.size.y),
							"actor_local": actor_local,
							"orbit": orbit.duplicate(),
						}
	return {}


func _action_has_h_key() -> bool:
	for event_variant in InputMap.action_get_events("p1_structural_seam"):
		var event := event_variant as InputEvent
		if event is InputEventKey:
			var key := event as InputEventKey
			if key.physical_keycode == KEY_H or key.keycode == KEY_H:
				return true
	return false


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


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "%s produced rendered pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var error := image.save_png(path)
	_check(error == OK, "%s saved rendered evidence PNG" % label)
	if error == OK:
		print("C6_RENDER_CAPTURE: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(root: Node) -> void:
	if root != null and is_instance_valid(root):
		root.free()
	if _failures.is_empty():
		print("C6_POINTER_INPUT_PASS: rendered production pointer acquisition plus real H InputMap dispatch authors the bounded structural seam and produces a live passive relation in the Owner-facing scene.")
		quit(0)
		return
	for failure in _failures:
		push_error("C6_POINTER_INPUT_FAIL: " + failure)
	quit(1)
