extends SceneTree

const PLATFORM_SIZE := Vector3i(11, 1, 11)
const RIDE_FRAMES := 120
const WALK_FRAMES := 90
const MAX_JUMP_FRAMES := 120
const POST_RECONTACT_FRAMES := 30

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_case(
		"linear_fast",
		Vector3(5.0, 0.0, -3.0),
		Vector3.ZERO,
		Vector3(5.5, 2.15, 5.5),
		Vector3(-0.4, 0.0, 0.2),
		1.0
	)
	await _run_case(
		"spin_offset",
		Vector3.ZERO,
		Vector3(0.0, 0.9, 0.0),
		Vector3(7.0, 2.15, 5.5),
		Vector3(-0.25, 0.0, 0.3),
		1.0
	)
	await _run_case(
		"combined_reverse",
		Vector3(-2.5, 0.0, 2.0),
		Vector3(0.0, -0.8, 0.0),
		Vector3(4.5, 2.15, 6.5),
		Vector3(0.3, 0.0, -0.25),
		50.0
	)
	await _run_case(
		"combined_heavy",
		Vector3(3.5, 0.0, -1.5),
		Vector3(0.0, 1.1, 0.0),
		Vector3(6.2, 2.15, 4.6),
		Vector3(-0.2, 0.0, 0.35),
		1000.0
	)

	if _failures.is_empty():
		print("G3_FRAME_CAMPAIGN_PASS: frame-aware support semantics survived varied translation, rotation, mass, walking and jump/recontact cases.")
		quit(0)
		return

	for failure in _failures:
		push_error("G3_FRAME_CAMPAIGN_FAIL: " + failure)
	quit(1)


func _run_case(
	case_name: String,
	commanded_linear: Vector3,
	commanded_angular: Vector3,
	actor_local_start: Vector3,
	walk_local_velocity: Vector3,
	mass_per_cell: float
) -> void:
	var world: Node3D = Node3D.new()
	world.name = "Campaign_%s" % case_name
	get_root().add_child(world)

	var volume: CellVolume = CellVolume.new(PLATFORM_SIZE)
	volume.fill_box(Vector3i.ZERO, PLATFORM_SIZE, CellVolume.SOLID)

	var construct: ConstructBody = ConstructBody.new()
	construct.name = "Construct_%s" % case_name
	construct.gravity_scale = 0.0
	construct.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	construct.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	construct.linear_damp = 0.0
	construct.angular_damp = 0.0
	construct.mass_per_cell = mass_per_cell
	world.add_child(construct)
	construct.set_volume(volume)

	var actor: FrameProbeCharacter = FrameProbeCharacter.new()
	actor.name = "Actor_%s" % case_name
	world.add_child(actor)
	actor.global_position = construct.to_global(actor_local_start)

	var acquired: bool = false
	for _step in range(60):
		await physics_frame
		await process_frame
		if actor.grounded and actor.support_body == construct:
			acquired = true
			break

	_check_case(acquired, case_name, "actor acquires support")
	if not acquired:
		world.free()
		await process_frame
		return

	var ride_local_start: Vector3 = construct.to_local(actor.global_position)
	construct.linear_velocity = commanded_linear
	construct.angular_velocity = commanded_angular

	var max_ride_drift: float = 0.0
	var ride_floor_loss: int = 0
	var max_linear_error: float = 0.0
	var max_angular_error: float = 0.0

	for _step in range(RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now: Vector3 = construct.to_local(actor.global_position)
		var drift: float = Vector2(local_now.x - ride_local_start.x, local_now.z - ride_local_start.z).length()
		max_ride_drift = max(max_ride_drift, drift)
		if not actor.grounded:
			ride_floor_loss += 1
		max_linear_error = max(max_linear_error, (construct.linear_velocity - commanded_linear).length())
		max_angular_error = max(max_angular_error, (construct.angular_velocity - commanded_angular).length())

	var walk_local_start: Vector3 = construct.to_local(actor.global_position)
	actor.desired_local_velocity = walk_local_velocity
	var walk_floor_loss: int = 0
	for _step in range(WALK_FRAMES):
		await physics_frame
		await process_frame
		if not actor.grounded:
			walk_floor_loss += 1
		max_linear_error = max(max_linear_error, (construct.linear_velocity - commanded_linear).length())
		max_angular_error = max(max_angular_error, (construct.angular_velocity - commanded_angular).length())

	actor.desired_local_velocity = Vector3.ZERO
	var walk_local_end: Vector3 = construct.to_local(actor.global_position)
	var walk_delta := Vector2(walk_local_end.x - walk_local_start.x, walk_local_end.z - walk_local_start.z)

	var recontacts_before: int = actor.observed_recontacts
	actor.request_jump()
	var saw_airborne: bool = false
	var airborne_frames: int = 0
	var recontact_frame: int = -1
	for step in range(MAX_JUMP_FRAMES):
		await physics_frame
		await process_frame
		max_linear_error = max(max_linear_error, (construct.linear_velocity - commanded_linear).length())
		max_angular_error = max(max_angular_error, (construct.angular_velocity - commanded_angular).length())
		if not actor.grounded:
			saw_airborne = true
			airborne_frames += 1
		elif saw_airborne:
			recontact_frame = step
			break

	var post_recontact_drift: float = 0.0
	var post_recontact_floor_loss: int = 0
	if recontact_frame >= 0:
		var post_local_start: Vector3 = construct.to_local(actor.global_position)
		for _step in range(POST_RECONTACT_FRAMES):
			await physics_frame
			await process_frame
			var local_now: Vector3 = construct.to_local(actor.global_position)
			var drift: float = Vector2(local_now.x - post_local_start.x, local_now.z - post_local_start.z).length()
			post_recontact_drift = max(post_recontact_drift, drift)
			if not actor.grounded:
				post_recontact_floor_loss += 1
			max_linear_error = max(max_linear_error, (construct.linear_velocity - commanded_linear).length())
			max_angular_error = max(max_angular_error, (construct.angular_velocity - commanded_angular).length())

	_check_case(ride_floor_loss == 0, case_name, "ride stays grounded")
	_check_case(max_ride_drift < 0.002, case_name, "ride local drift remains sub-2mm")
	_check_case(walk_floor_loss == 0, case_name, "walk stays grounded")
	_check_case(walk_delta.length() > 0.4, case_name, "walk produces local displacement")
	_check_case(saw_airborne, case_name, "jump leaves support")
	_check_case(recontact_frame >= 0, case_name, "jump recontacts within bounded window")
	_check_case(actor.observed_recontacts > recontacts_before, case_name, "recontact is a new support acquisition")
	_check_case(actor.support_body == construct, case_name, "recontact returns to same construct")
	_check_case(post_recontact_floor_loss == 0, case_name, "post-recontact support remains stable")
	_check_case(post_recontact_drift < 0.002, case_name, "post-recontact local drift remains sub-2mm")
	_check_case(max_linear_error < 0.01, case_name, "actor does not perturb construct linear velocity")
	_check_case(max_angular_error < 0.01, case_name, "actor does not perturb construct angular velocity")

	print(
		"G3_FRAME_CAMPAIGN_METRIC case=%s mass=%.1f linear=%s angular=%s ride_drift=%.8f ride_floor_loss=%d walk_delta=%s walk_floor_loss=%d airborne_frames=%d recontact_frame=%d post_drift=%.8f post_floor_loss=%d linear_error=%.8f angular_error=%.8f final_local=%s"
		% [
			case_name,
			construct.mass,
			commanded_linear,
			commanded_angular,
			max_ride_drift,
			ride_floor_loss,
			walk_delta,
			walk_floor_loss,
			airborne_frames,
			recontact_frame,
			post_recontact_drift,
			post_recontact_floor_loss,
			max_linear_error,
			max_angular_error,
			construct.to_local(actor.global_position),
		]
	)

	world.free()
	await process_frame


func _check_case(condition: bool, case_name: String, description: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [case_name, description])
