extends SceneTree

const PLATFORM_SIZE := Vector3i(9, 1, 9)
const ACTOR_LOCAL_START := Vector3(5.5, 2.15, 4.5)
const RIDE_FRAMES := 180
const WALK_FRAMES := 120
const MAX_JUMP_FRAMES := 180
const POST_RECONTACT_FRAMES := 60

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: Node3D = Node3D.new()
	world.name = "FrameProbeWorld"
	get_root().add_child(world)

	var volume: CellVolume = CellVolume.new(PLATFORM_SIZE)
	volume.fill_box(Vector3i.ZERO, PLATFORM_SIZE, CellVolume.SOLID)

	var construct: ConstructBody = ConstructBody.new()
	construct.name = "FreeConstruct"
	construct.gravity_scale = 0.0
	construct.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	construct.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	construct.linear_damp = 0.0
	construct.angular_damp = 0.0
	construct.mass_per_cell = 1.0
	world.add_child(construct)
	construct.set_volume(volume)

	var actor: FrameProbeCharacter = FrameProbeCharacter.new()
	actor.name = "FrameProbeActor"
	world.add_child(actor)
	actor.global_position = construct.to_global(ACTOR_LOCAL_START)

	var acquired: bool = false
	for _step in range(60):
		await physics_frame
		await process_frame
		if actor.grounded and actor.support_body == construct:
			acquired = true
			break

	_check(acquired, "query-based actor acquires free ConstructBody as support")
	if not acquired:
		_finish(world)
		return

	var ride_local_start: Vector3 = construct.to_local(actor.global_position)
	var commanded_linear := Vector3(1.5, 0.0, -0.5)
	var commanded_angular := Vector3(0.0, 0.6, 0.0)
	construct.linear_velocity = commanded_linear
	construct.angular_velocity = commanded_angular

	var max_ride_local_drift: float = 0.0
	var ride_floor_loss_frames: int = 0
	var max_linear_velocity_error: float = 0.0
	var max_angular_velocity_error: float = 0.0

	for _step in range(RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now: Vector3 = construct.to_local(actor.global_position)
		var drift: float = Vector2(local_now.x - ride_local_start.x, local_now.z - ride_local_start.z).length()
		max_ride_local_drift = max(max_ride_local_drift, drift)
		if not actor.grounded:
			ride_floor_loss_frames += 1
		max_linear_velocity_error = max(max_linear_velocity_error, (construct.linear_velocity - commanded_linear).length())
		max_angular_velocity_error = max(max_angular_velocity_error, (construct.angular_velocity - commanded_angular).length())

	_check(ride_floor_loss_frames == 0, "frame-aware actor remains grounded during free construct translation/rotation")
	_check(max_ride_local_drift < 0.02, "frame-aware actor preserves local position while riding")

	var walk_local_start: Vector3 = construct.to_local(actor.global_position)
	actor.desired_local_velocity = Vector3(-0.45, 0.0, 0.25)
	var walk_floor_loss_frames: int = 0
	for _step in range(WALK_FRAMES):
		await physics_frame
		await process_frame
		if not actor.grounded:
			walk_floor_loss_frames += 1
		max_linear_velocity_error = max(max_linear_velocity_error, (construct.linear_velocity - commanded_linear).length())
		max_angular_velocity_error = max(max_angular_velocity_error, (construct.angular_velocity - commanded_angular).length())

	actor.desired_local_velocity = Vector3.ZERO
	var walk_local_end: Vector3 = construct.to_local(actor.global_position)
	var walk_local_delta := Vector2(walk_local_end.x - walk_local_start.x, walk_local_end.z - walk_local_start.z)
	_check(walk_floor_loss_frames == 0, "frame-aware actor walks on moving free construct without losing support")
	_check(walk_local_delta.length() > 0.7, "frame-aware actor produces material local-frame walking displacement")

	var recontacts_before: int = actor.observed_recontacts
	actor.request_jump()
	var saw_airborne: bool = false
	var airborne_frames: int = 0
	var recontact_frame: int = -1

	for step in range(MAX_JUMP_FRAMES):
		await physics_frame
		await process_frame
		max_linear_velocity_error = max(max_linear_velocity_error, (construct.linear_velocity - commanded_linear).length())
		max_angular_velocity_error = max(max_angular_velocity_error, (construct.angular_velocity - commanded_angular).length())
		if not actor.grounded:
			saw_airborne = true
			airborne_frames += 1
		elif saw_airborne:
			recontact_frame = step
			break

	_check(saw_airborne, "jump detaches actor from support frame")
	_check(recontact_frame >= 0, "airborne actor recontacts the moving free construct")
	_check(actor.observed_recontacts > recontacts_before, "recontact is recorded as a new support acquisition")
	_check(actor.support_body == construct, "jump recontact resolves back to the same ConstructBody")

	var post_recontact_local_start: Vector3 = construct.to_local(actor.global_position)
	var post_recontact_drift: float = 0.0
	var post_recontact_floor_loss: int = 0
	if recontact_frame >= 0:
		for _step in range(POST_RECONTACT_FRAMES):
			await physics_frame
			await process_frame
			var local_now: Vector3 = construct.to_local(actor.global_position)
			var drift: float = Vector2(local_now.x - post_recontact_local_start.x, local_now.z - post_recontact_local_start.z).length()
			post_recontact_drift = max(post_recontact_drift, drift)
			if not actor.grounded:
				post_recontact_floor_loss += 1
			max_linear_velocity_error = max(max_linear_velocity_error, (construct.linear_velocity - commanded_linear).length())
			max_angular_velocity_error = max(max_angular_velocity_error, (construct.angular_velocity - commanded_angular).length())

	_check(post_recontact_floor_loss == 0, "actor remains supported after jump recontact")
	_check(post_recontact_drift < 0.02, "actor re-establishes a stable local frame after recontact")
	_check(max_linear_velocity_error < 0.01, "actor does not materially perturb free construct linear velocity")
	_check(max_angular_velocity_error < 0.01, "actor does not materially perturb free construct angular velocity")

	print(
		"G3_FRAME_CHALLENGER_METRIC ride_drift=%.6f ride_floor_loss=%d walk_delta=%s walk_floor_loss=%d airborne_frames=%d recontact_frame=%d post_recontact_drift=%.6f post_recontact_floor_loss=%d linear_velocity_error=%.8f angular_velocity_error=%.8f final_actor_local=%s construct_linear=%s construct_angular=%s"
		% [
			max_ride_local_drift,
			ride_floor_loss_frames,
			walk_local_delta,
			walk_floor_loss_frames,
			airborne_frames,
			recontact_frame,
			post_recontact_drift,
			post_recontact_floor_loss,
			max_linear_velocity_error,
			max_angular_velocity_error,
			construct.to_local(actor.global_position),
			construct.linear_velocity,
			construct.angular_velocity,
		]
	)

	_finish(world)


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("G3_FRAME_CHALLENGER_PASS: query-based support-frame actor rode, walked, jumped and recontacted a freely simulated construct without kinematic push.")
		world.free()
		quit(0)
		return

	for failure in _failures:
		push_error("G3_FRAME_CHALLENGER_FAIL: " + failure)
	world.free()
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
