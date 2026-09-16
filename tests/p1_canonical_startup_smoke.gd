extends SceneTree

const ACQUIRE_FRAMES := 14
const EXPECTED_MAIN_SCENE := "res://p1/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var configured_main: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(configured_main == EXPECTED_MAIN_SCENE, "canonical project startup points at P1 main scene")

	for action in [
		"p1_move_left",
		"p1_move_right",
		"p1_move_forward",
		"p1_move_back",
		"p1_jump",
		"p1_edit_toggle",
		"p1_edit_apply",
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
	_check(packed != null, "configured canonical main scene loads")
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
	var space := main.call("get_space") as LocalMatterSpace

	_check(player != null, "canonical startup composes volumetric P1 player")
	_check(camera_rig != null, "canonical startup composes P1 camera rig")
	_check(registry != null, "canonical startup composes P1 Space registry")
	_check(space_control != null, "canonical startup composes finite P1 Space control")
	_check(interactor != null, "canonical startup composes P1 Matter interaction")
	_check(space != null, "canonical startup creates logical Matter Space")

	if player != null and camera_rig != null and space != null:
		await _advance_frames(ACQUIRE_FRAMES)
		_check(player.grounded and player.support_space == space, "canonical startup actor acquires authored logical Space")
		_check(player.support_body == space.get_active_provider(), "canonical startup actor resolves current provider")
		_check(camera_rig.target == player, "canonical startup camera targets actor")
		_check(camera_rig.context_target == space.get_active_provider(), "canonical startup camera preserves Space context")

	print(
		"P1_CANONICAL_STARTUP_METRIC main_scene=%s logical_space_id=%d provider_kind=%d active_spaces=%d"
		% [
			configured_main,
			space.get_instance_id() if space != null else 0,
			space.get_provider_kind() if space != null else -1,
			registry.get_active_count() if registry != null else 0,
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
		print("P1_CANONICAL_STARTUP_PASS: project startup, persisted Owner controls and composed P1 runtime resolve to the same canonical Owner-candidate scene.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CANONICAL_STARTUP_FAIL: " + failure)
	quit(1)
