extends SceneTree

const ACQUIRE_FRAMES := 20
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
	var hint := main.get_node_or_null("HUD/Panel/MarginContainer/VBoxContainer/Hint") as Label
	var world := main.call("get_recovery_world_space") as LocalMatterSpace
	var old_demo := main.call("get_recovery_demo_space") as LocalMatterSpace
	var bridge_cell: Vector3i = main.call("get_recovery_causal_bridge_cell_for_test") if main.has_method("get_recovery_causal_bridge_cell_for_test") else Vector3i(-1, -1, -1)

	_check(player != null, "canonical startup composes volumetric P1 player")
	_check(camera_rig != null, "canonical startup composes P1 camera rig")
	_check(registry != null, "canonical startup composes P1 Space registry")
	_check(space_control != null, "canonical startup composes finite P1 Space control")
	_check(interactor != null, "canonical startup composes shared P1 Matter interaction")
	_check(direct_edit != null, "canonical startup composes direct sandbox edit controls")
	_check(world is W0AuthorityPartitionSpace, "canonical startup creates one causal ordinary-Matter world")
	_check(old_demo == null, "canonical startup has no pre-authored moving demo Space")
	_check(main.get_node_or_null("WorldReference") == null, "canonical Owner surface has no fake non-Matter terrain")
	_check(registry != null and registry.get_active_count() == 1, "canonical startup begins with exactly one ordinary world Space")
	_check(world != null and world.volume.in_bounds(bridge_cell) and world.volume.get_cell(bridge_cell) != CellVolume.EMPTY, "canonical startup contains the ordinary-Matter causal bridge")

	await _advance_frames(ACQUIRE_FRAMES)
	_check(player != null and player.grounded and player.support_space == world, "canonical startup actor acquires ordinary world Matter")
	_check(player != null and player.support_body == world.get_active_provider(), "canonical startup actor resolves world Matter provider")
	_check(camera_rig != null and camera_rig.target == player, "canonical startup camera targets actor")
	_check(camera_rig != null and camera_rig.context_target == null, "large ordinary world does not force whole-world camera framing")
	var witness: Dictionary = player.get_support_contact_witness() if player != null else {}
	_check(bool(witness.get("valid", false)), "canonical startup establishes exact actor↔Matter contact witness")

	# Recovery teaches one causal model: edit the canonical world; only detached
	# Matter receives explicit rigid-body controls. The canonical authority must
	# never be releasable through the legacy T/arrows Space-control surface.
	var toggle_accepted: bool = bool(main.call("toggle_focused_space_for_test"))
	var impulse_accepted: bool = bool(main.call("apply_focused_central_impulse_for_test", Vector3(0.0, 0.0, -4.0)))
	var torque_accepted: bool = bool(main.call("apply_focused_torque_impulse_for_test", Vector3(0.0, 1.0, 0.0)))
	_check(not toggle_accepted, "canonical causal world rejects legacy release/freeze toggle")
	_check(not impulse_accepted and not torque_accepted, "canonical causal world rejects manual rigid-body impulses")
	_check(world.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "canonical causal world remains static after rejected legacy controls")
	_check(not world.is_provider_transition_pending(), "rejected legacy controls queue no hidden provider transition")
	_check(hint != null, "canonical recovery HUD exposes first-contact hint")
	if hint != null:
		_check(hint.text.contains("LMB remove") and hint.text.contains("RMB build"), "world HUD prioritizes direct Matter editing")
		_check(not hint.text.contains("T release") and not hint.text.contains("arrows push"), "world HUD does not advertise detached-Matter controls on canonical authority")

	print(
		"P1_CANONICAL_STARTUP_METRIC main_scene=%s world_space_id=%d active_spaces=%d bridge=%s witness=%s world_toggle=%s world_impulse=%s"
		% [
			configured_main,
			world.get_instance_id() if world != null else 0,
			registry.get_active_count() if registry != null else 0,
			str(bridge_cell),
			str(witness.get("cell", Vector3i(-1, -1, -1))),
			str(toggle_accepted),
			str(impulse_accepted),
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
		print("P1_CANONICAL_STARTUP_PASS: project startup resolves to one editable causal Matter world with direct interaction and exact actor support; rigid-body controls are scoped to detached Matter rather than the world authority.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CANONICAL_STARTUP_FAIL: " + failure)
	quit(1)
