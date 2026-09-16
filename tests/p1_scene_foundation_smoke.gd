extends SceneTree

const ACQUIRE_FRAMES := 14
const WORLD_FALL_FRAMES := 90
const POST_TRANSITION_FRAMES := 8
const WATCHDOG_SECONDS := 12.0

var _failures: Array[String] = []
var _phase := "boot"
var _finished := false


func _init() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")


func _watchdog() -> void:
	await create_timer(WATCHDOG_SECONDS).timeout
	if _finished:
		return
	push_error("P1_SCENE_FOUNDATION_TIMEOUT: phase=%s" % _phase)
	quit(1)


func _run() -> void:
	_phase = "load scene"
	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "P1 composed main scene loads")
	if packed == null:
		_finish()
		return

	_phase = "instantiate scene"
	var p1 := packed.instantiate()
	get_root().add_child(p1)
	await process_frame

	_phase = "resolve composed roles"
	var world_reference := p1.get_node_or_null("WorldReference") as StaticBody3D
	var world_collision := p1.get_node_or_null("WorldReference/CollisionShape3D") as CollisionShape3D
	var player := p1.get_node_or_null("P1Player") as SpaceQueryCharacter
	var camera_rig := p1.get_node_or_null("P1CameraRig") as P1CameraRig
	var spring_arm := p1.get_node_or_null("P1CameraRig/YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	var camera := p1.get_node_or_null("P1CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D") as Camera3D
	var space := p1.call("get_space") as LocalMatterSpace

	_check(world_reference != null, "P1 world reference is a real StaticBody3D")
	_check(world_collision != null and world_collision.shape != null, "P1 visible world reference owns real collision")
	_check(player != null, "P1 scene uses SpaceQueryCharacter")
	_check(camera_rig != null, "P1 scene composes a dedicated camera rig")
	_check(spring_arm != null and spring_arm.shape != null, "P1 camera uses collision-aware SpringArm3D")
	_check(camera != null and camera.current, "P1 SpringArm owns the current Camera3D")
	_check(space != null, "P1 scene owns a logical LocalMatterSpace")
	_check(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "P1 enables Godot physics interpolation")
	_check(InputMap.has_action("p1_move_forward") and InputMap.has_action("p1_jump"), "P1 controls use named InputMap actions")
	if world_reference == null or player == null or camera_rig == null or space == null:
		p1.free()
		_finish()
		return

	_phase = "acquire Matter support"
	await _advance_frames(ACQUIRE_FRAMES)
	_check(player.grounded, "P1 player acquires Matter deck support")
	_check(player.support_space == space, "P1 player support resolves to the logical Space")
	_check(camera_rig.target == player, "P1 camera targets the player")
	_check(camera_rig.context_target == space.get_active_provider(), "P1 camera also tracks the active Space provider as context")

	_phase = "fall to real world reference"
	# Prove the visible grey world floor is not decorative. Move the actor well
	# outside the Matter deck, clear old support and let the same volumetric
	# controller fall under gravity onto WorldReference.
	player.global_position = Vector3(20.0, 5.0, 20.0)
	player.world_velocity = Vector3.ZERO
	player.desired_local_velocity = Vector3.ZERO
	player.grounded = false
	player.support_body = null
	player.support_space = null
	player.reset_physics_interpolation()
	await _advance_frames(WORLD_FALL_FRAMES)
	_check(player.grounded, "P1 player physically lands on the visible world reference")
	_check(player.support_space == null, "ordinary world floor is support without pretending to be a logical LocalMatterSpace")
	_check(player.support_body == world_reference, "P1 visible world floor is the actual support body")

	_phase = "recover to Matter support"
	p1.call("recover_player_for_test")
	await _advance_frames(ACQUIRE_FRAMES)
	_check(player.grounded and player.support_space == space, "P1 recovery returns to the same logical Space")

	_phase = "request dynamic provider"
	var logical_space_id := space.get_instance_id()
	var old_provider_id := space.get_active_provider().get_instance_id()
	_check(bool(p1.call("activate_dynamic_probe_for_test")), "P1 internal lifecycle probe queues static→dynamic replacement")
	if not space.is_transition_pending():
		_failures.append("P1 activation did not leave a pending provider transition")
	else:
		_phase = "await dynamic provider commit"
		await space.provider_transition_committed

	_phase = "validate provider succession"
	await _advance_frames(POST_TRANSITION_FRAMES)
	_check(space.get_instance_id() == logical_space_id, "P1 activation preserves logical Space identity")
	_check(space.get_active_provider() is ConstructBody, "P1 activation installs the real dynamic provider")
	_check(space.get_active_provider().get_instance_id() != old_provider_id, "P1 provider replacement is real rather than an in-place presentation trick")
	_check(player.grounded and player.support_space == space, "P1 volumetric player remains logically supported through provider replacement")
	_check(player.support_body == space.get_active_provider(), "P1 volumetric player follows the current provider")
	_check(camera_rig.context_target == space.get_active_provider(), "P1 camera context retargets with provider replacement")

	print(
		"P1_SCENE_FOUNDATION_METRIC player_y=%.6f logical_space_id=%d provider_id=%d world_support_id=%d spring_length=%.3f"
		% [
			player.global_position.y,
			logical_space_id,
			space.get_active_provider().get_instance_id(),
			world_reference.get_instance_id(),
			spring_arm.spring_length,
		]
	)

	_phase = "finish"
	p1.free()
	_finish()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _finish() -> void:
	_finished = true
	if _failures.is_empty():
		print("P1_SCENE_FOUNDATION_PASS: real world collision, volumetric actor, SpringArm camera context and logical-Space provider replacement compose in the new scene without inheriting P0/P0.5 consumer code.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_SCENE_FOUNDATION_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
