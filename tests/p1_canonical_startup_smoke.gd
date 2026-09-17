extends SceneTree

const ACQUIRE_FRAMES := 16
const MOTION_FRAMES := 12
const EXPECTED_MAIN_SCENE := "res://p1/recovery_main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var configured_main: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(configured_main == EXPECTED_MAIN_SCENE, "canonical project startup points at the recovery Owner surface")

	for action in [
		"p1_move_left",
		"p1_move_right",
		"p1_move_forward",
		"p1_move_back",
		"p1_jump",
		"p1_space_toggle",
		"p1_space_forward_impulse",
		"p1_space_back_impulse",
		"p1_space_yaw_left",
		"p1_space_yaw_right",
		"p1_camera_reset",
		"p1_recover",
		"p1_reset",
	]:
		_check(InputMap.has_action(action), "canonical project InputMap contains %s" % action)

	var packed := load(configured_main) as PackedScene
	_check(packed != null, "configured canonical recovery scene loads")
	if packed == null:
		_finish()
		return

	var main := packed.instantiate()
	get_root().add_child(main)
	await process_frame

	var player := main.get_node_or_null("P1Player") as SpaceQueryCharacter
	var camera_rig := main.get_node_or_null("P1CameraRig") as P1CameraRig
	var registry := main.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry
	var space_control := main.get_node_or_null("P1SpaceControl") as P1SpaceControl
	var interactor := main.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	var direct_edit := main.get_node_or_null("P1RecoveryDirectEdit") as P1RecoveryDirectEdit
	var world := main.call("get_recovery_world_space") as LocalMatterSpace
	var moving := main.call("get_recovery_demo_space") as LocalMatterSpace

	_check(player != null, "canonical startup composes volumetric P1 player")
	_check(camera_rig != null, "canonical startup composes P1 camera rig")
	_check(registry != null, "canonical startup composes P1 Space registry")
	_check(space_control != null, "canonical startup composes finite P1 Space control")
	_check(interactor != null, "canonical startup composes shared P1 Matter interaction")
	_check(direct_edit != null, "canonical startup composes direct sandbox edit controls")
	_check(world != null, "canonical startup creates ordinary world Matter")
	_check(moving != null, "canonical startup creates a second moving Matter Space")
	_check(main.get_node_or_null("WorldReference") == null, "canonical Owner surface has no fake non-Matter terrain")

	var moving_start := moving.get_active_provider().global_position if moving != null else Vector3.ZERO
	await _advance_frames(ACQUIRE_FRAMES)
	_check(player != null and player.grounded and player.support_space == world, "canonical startup actor acquires ordinary world Matter")
	_check(player != null and player.support_body == world.get_active_provider(), "canonical startup actor resolves world Matter provider")
	_check(camera_rig != null and camera_rig.target == player, "canonical startup camera targets actor")
	_check(camera_rig != null and camera_rig.context_target == null, "large ordinary world does not force whole-world camera framing")
	_check(registry != null and registry.get_active_count() == 2, "canonical startup exposes world Matter plus moving Matter")

	await _advance_frames(MOTION_FRAMES)
	var moving_delta := moving.get_active_provider().global_position.distance_to(moving_start) if moving != null else 0.0
	_check(moving_delta > 0.02, "canonical startup contains visible Matter motion without a setup sequence")

	print(
		"P1_CANONICAL_STARTUP_METRIC main_scene=%s world_space_id=%d moving_space_id=%d active_spaces=%d moving_delta=%.6f"
		% [
			configured_main,
			world.get_instance_id() if world != null else 0,
			moving.get_instance_id() if moving != null else 0,
			registry.get_active_count() if registry != null else 0,
			moving_delta,
		]
	)

	main.free()
	_finish()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_CANONICAL_STARTUP_PASS: project startup now resolves to the bounded recovery surface with editable world Matter, direct interaction and live moving Matter.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CANONICAL_STARTUP_FAIL: " + failure)
	quit(1)
