extends SceneTree

const PLATFORM_SIZE := Vector3i(9, 1, 9)
const ACTOR_LOCAL_START := Vector3(4.5, 1.95, 4.5)
const ACQUIRE_FRAMES := 60
const DYNAMIC_RIDE_FRAMES := 120
const STATIC_OBSERVE_FRAMES := 60
const MASS_PER_CELL := 1.0
const DRIVE_LINEAR := Vector3(1.3, 0.0, -0.4)
const DRIVE_ANGULAR := Vector3(0.0, 0.45, 0.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "LifecycleActorProviderTransitionWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(PLATFORM_SIZE)
	volume.fill_box(Vector3i.ZERO, PLATFORM_SIZE, CellVolume.SOLID)
	var lineage := MatterLineageMap.new(PLATFORM_SIZE)
	var token := 610001
	for z in range(PLATFORM_SIZE.z):
		for y in range(PLATFORM_SIZE.y):
			for x in range(PLATFORM_SIZE.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					lineage.set_lineage(cell, token)
					token += 1

	var space := LocalMatterSpace.new()
	space.name = "ActorSupportSpace"
	space.mass_per_cell = MASS_PER_CELL
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.0
	space.dynamic_angular_damp = 0.0
	space.dynamic_can_sleep = false
	world.add_child(space)
	var initial_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, 0.28, 0.0)).orthonormalized(),
		Vector3(3.0, 2.0, -4.0)
	)
	space.initialize_static(volume, lineage, initial_transform)

	var actor := FrameProbeCharacter.new()
	actor.name = "LifecycleActor"
	world.add_child(actor)
	actor.global_position = space.get_active_provider().to_global(ACTOR_LOCAL_START)

	var acquired := false
	for _step in range(ACQUIRE_FRAMES):
		await physics_frame
		await process_frame
		if actor.grounded and actor.support_space == space:
			acquired = true
			break

	_check(acquired, "actor acquires the static LocalMatterSpace through ordinary ground contact")
	if not acquired:
		_finish(world)
		return

	var initial_static := space.get_active_provider()
	_check(initial_static is MatterRepresentation, "initial logical support resolves to MatterRepresentation rather than its internal StaticBody3D")
	_check(actor.support_body == initial_static, "actor normalizes static collision to the active provider frame")
	var logical_space_id := space.get_instance_id()
	var initial_static_id := initial_static.get_instance_id()
	var initial_local := initial_static.to_local(actor.global_position)
	var initial_world := actor.global_position
	var transfers_before_activation := actor.observed_support_transfers
	var acquisitions_before_activation := actor.observed_ground_acquisitions

	_check(space.request_dynamic(DRIVE_LINEAR, DRIVE_ANGULAR), "I2 queues static→dynamic provider replacement while actor is grounded")
	await space.provider_transition_committed
	var dynamic_provider := space.get_active_provider()
	_check(dynamic_provider is ConstructBody, "I2 installs dynamic provider")
	if not dynamic_provider is ConstructBody:
		_finish(world)
		return
	var dynamic_body := dynamic_provider as ConstructBody
	var dynamic_id := dynamic_body.get_instance_id()

	# LocalMatterSpace commits before actor _physics_process. The actor must notice
	# the provider change itself during this physics tick; the test does not call
	# transfer_support_frame() or inject a concrete-provider handoff.
	await process_frame
	var activation_local := dynamic_body.to_local(actor.global_position)
	var activation_local_jump := activation_local.distance_to(initial_local)
	var activation_world_jump := actor.global_position.distance_to(initial_world)
	_check(actor.grounded, "actor remains grounded through static→dynamic provider replacement")
	_check(actor.support_space == space, "actor retains logical support Space through activation")
	_check(actor.support_body == dynamic_body, "actor automatically resolves support to the new dynamic provider")
	_check(actor.observed_support_transfers == transfers_before_activation + 1, "activation records exactly one provider support transfer")
	_check(actor.observed_ground_acquisitions == acquisitions_before_activation, "provider transition is not misreported as fresh contact acquisition")
	_check(activation_local_jump < 0.00001, "activation preserves actor local support coordinate")
	_check(activation_world_jump < 0.00001, "activation introduces no synchronous actor world-space teleport")
	_check(actor.observed_support_velocity.length() > 0.2, "actor receives dynamic support velocity immediately after provider transfer")

	var ride_local_start := dynamic_body.to_local(actor.global_position)
	var max_dynamic_local_drift := 0.0
	var dynamic_floor_loss := 0
	var wrong_dynamic_support_frames := 0
	var max_linear_velocity_error := 0.0
	var max_angular_velocity_error := 0.0
	for _step in range(DYNAMIC_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := dynamic_body.to_local(actor.global_position)
		var drift := Vector2(local_now.x - ride_local_start.x, local_now.z - ride_local_start.z).length()
		max_dynamic_local_drift = max(max_dynamic_local_drift, drift)
		if not actor.grounded:
			dynamic_floor_loss += 1
		if actor.support_space != space or actor.support_body != dynamic_body:
			wrong_dynamic_support_frames += 1
		max_linear_velocity_error = max(max_linear_velocity_error, dynamic_body.linear_velocity.distance_to(DRIVE_LINEAR))
		max_angular_velocity_error = max(max_angular_velocity_error, dynamic_body.angular_velocity.distance_to(DRIVE_ANGULAR))

	_check(dynamic_floor_loss == 0, "actor never loses grounded state while riding after provider activation")
	_check(wrong_dynamic_support_frames == 0, "actor keeps logical Space and current provider authority throughout dynamic ride")
	_check(max_dynamic_local_drift < 0.02, "actor preserves local support position while dynamic Space translates and rotates")
	_check(max_linear_velocity_error < 0.01, "actor support logic does not perturb dynamic provider linear velocity")
	_check(max_angular_velocity_error < 0.01, "actor support logic does not perturb dynamic provider angular velocity")

	# At this point the scene-node pose is the last PhysicsServer-synchronized pose.
	# The next physics tick begins with another legal sync of the still-dynamic
	# provider before LocalMatterSpace commits the static replacement. Therefore
	# pre_freeze_world -> transaction-boundary world motion is phase advance, not
	# a replacement teleport. Measure the actual transition against the transform
	# captured by LocalMatterSpace at its commit boundary.
	var pre_freeze_local := dynamic_body.to_local(actor.global_position)
	var pre_freeze_world := actor.global_position
	var transfers_before_freeze := actor.observed_support_transfers
	var acquisitions_before_freeze := actor.observed_ground_acquisitions
	_check(space.request_static(), "I2 queues dynamic→static provider replacement while actor is grounded")
	await space.provider_transition_committed
	var freeze_report := space.get_last_transition_report()
	var freeze_previous_transform: Transform3D = freeze_report["previous_transform"]
	var freeze_current_transform: Transform3D = freeze_report["current_transform"]
	var freeze_transaction_expected_world := freeze_previous_transform * pre_freeze_local
	var freeze_phase_advance := freeze_transaction_expected_world.distance_to(pre_freeze_world)
	var provider_freeze_pose_jump := _transform_gap(freeze_previous_transform, freeze_current_transform)

	var final_provider := space.get_active_provider()
	_check(final_provider is MatterRepresentation, "I2 installs fresh static provider")
	if not final_provider is MatterRepresentation:
		_finish(world)
		return
	var final_static := final_provider as MatterRepresentation
	var final_static_id := final_static.get_instance_id()

	await process_frame
	var freeze_local := final_static.to_local(actor.global_position)
	var freeze_local_jump := freeze_local.distance_to(pre_freeze_local)
	var freeze_transition_world_jump := actor.global_position.distance_to(freeze_transaction_expected_world)
	_check(actor.grounded, "actor remains grounded through dynamic→static provider replacement")
	_check(actor.support_space == space, "actor retains logical support Space through freeze")
	_check(actor.support_body == final_static, "actor automatically resolves support to the fresh static provider")
	_check(actor.observed_support_transfers == transfers_before_freeze + 1, "freeze records exactly one provider support transfer")
	_check(actor.observed_ground_acquisitions == acquisitions_before_freeze, "freeze provider transfer is not a fresh contact acquisition")
	_check(provider_freeze_pose_jump < 0.000001, "dynamic→static provider replacement itself preserves pose at commit")
	_check(freeze_local_jump < 0.00001, "freeze preserves actor local support coordinate")
	_check(freeze_transition_world_jump < 0.00001, "freeze provider transition introduces no actor world-space teleport at the transaction boundary")
	_check(actor.observed_support_velocity.length() < 0.00001, "actor support velocity coherently becomes zero on static provider")
	_check(space.get_instance_id() == logical_space_id, "entire I2 cycle preserves logical Space identity")
	_check(final_static_id != dynamic_id and final_static_id != initial_static_id, "I2 traverses three distinct provider instances")

	var static_local_start := final_static.to_local(actor.global_position)
	var max_static_local_drift := 0.0
	var static_floor_loss := 0
	var wrong_static_support_frames := 0
	for _step in range(STATIC_OBSERVE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := final_static.to_local(actor.global_position)
		var drift := Vector2(local_now.x - static_local_start.x, local_now.z - static_local_start.z).length()
		max_static_local_drift = max(max_static_local_drift, drift)
		if not actor.grounded:
			static_floor_loss += 1
		if actor.support_space != space or actor.support_body != final_static:
			wrong_static_support_frames += 1

	_check(static_floor_loss == 0, "actor remains grounded after returning to static provider")
	_check(wrong_static_support_frames == 0, "actor keeps logical Space + final static provider support after freeze")
	_check(max_static_local_drift < 0.02, "actor remains locally stable on final static provider")

	print(
		"LIFECYCLE_ACTOR_PROVIDER_TRANSITION_METRIC logical_space_id=%d initial_static_id=%d dynamic_id=%d final_static_id=%d activation_local_jump=%.10f activation_world_jump=%.10f max_dynamic_local_drift=%.10f dynamic_floor_loss=%d wrong_dynamic_support=%d linear_velocity_error=%.10f angular_velocity_error=%.10f freeze_phase_advance=%.10f provider_freeze_pose_jump=%.10f freeze_local_jump=%.10f freeze_transition_world_jump=%.10f max_static_local_drift=%.10f static_floor_loss=%d wrong_static_support=%d support_transfers=%d contact_acquisitions=%d"
		% [
			logical_space_id,
			initial_static_id,
			dynamic_id,
			final_static_id,
			activation_local_jump,
			activation_world_jump,
			max_dynamic_local_drift,
			dynamic_floor_loss,
			wrong_dynamic_support_frames,
			max_linear_velocity_error,
			max_angular_velocity_error,
			freeze_phase_advance,
			provider_freeze_pose_jump,
			freeze_local_jump,
			freeze_transition_world_jump,
			max_static_local_drift,
			static_floor_loss,
			wrong_static_support_frames,
			actor.observed_support_transfers,
			actor.observed_ground_acquisitions,
		]
	)

	_finish(world)


func _transform_gap(a: Transform3D, b: Transform3D) -> float:
	return max(a.origin.distance_to(b.origin), _basis_axis_error(a.basis.orthonormalized(), b.basis.orthonormalized()))


func _basis_axis_error(a: Basis, b: Basis) -> float:
	return max(a.x.distance_to(b.x), max(a.y.distance_to(b.y), a.z.distance_to(b.z)))


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("LIFECYCLE_ACTOR_PROVIDER_TRANSITION_PROBE_PASS: actor support remained a logical LocalMatterSpace relation while static→dynamic→static concrete providers changed underneath it without test-local handoff orchestration.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("LIFECYCLE_ACTOR_PROVIDER_TRANSITION_PROBE_FAIL: " + failure)
	world.free()
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
