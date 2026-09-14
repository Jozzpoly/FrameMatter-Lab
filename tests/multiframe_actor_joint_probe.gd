extends SceneTree

const MASS_PER_CELL := 2.5
const ACQUIRE_FRAMES := 80
const PRE_DRIVE_FRAMES := 30
const DRIVE_FRAMES := 180
const ACTOR_LOCAL_START := Vector3(2.5, 3.15, 2.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "MultiFrameActorJointWorld"
	get_root().add_child(world)

	var left_volume := CellVolume.new(Vector3i(5, 2, 5))
	left_volume.fill_box(Vector3i.ZERO, left_volume.size, 2)
	var right_volume := CellVolume.new(Vector3i(3, 2, 3))
	right_volume.fill_box(Vector3i.ZERO, right_volume.size, 3)

	var left_snapshot := left_volume.duplicate_cells()
	var right_snapshot := right_volume.duplicate_cells()

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, 0.35, 0.0)),
		Vector3(-8.0, 5.0, 6.0)
	)
	var right_offset := Vector3(5.0, 0.0, 1.0)
	var left := _make_body(world, "ActorSupportFrame", left_volume, assembly_transform, 1)
	var right := _make_body(
		world,
		"DrivenSiblingFrame",
		right_volume,
		assembly_transform * Transform3D(Basis.IDENTITY, right_offset),
		0
	)

	# Keep this composition inside the bounded G3 yaw/upright actor scope. The
	# constraint is still free to transmit forces and yaw torque between frames.
	left.axis_lock_angular_x = true
	left.axis_lock_angular_z = true
	right.axis_lock_angular_x = true
	right.axis_lock_angular_z = true

	var anchor_world: Vector3 = assembly_transform * Vector3(5.0, 1.0, 2.5)
	var left_anchor_local := left.to_local(anchor_world)
	var right_anchor_local := right.to_local(anchor_world)
	var initial_linear_at_anchor := Vector3(1.4, 0.0, -0.5)
	var initial_angular := Vector3(0.0, 0.18, 0.0)
	left.linear_velocity = _velocity_at_point(
		initial_linear_at_anchor,
		initial_angular,
		anchor_world,
		left.to_global(left.matter_center_of_mass_local)
	)
	right.linear_velocity = _velocity_at_point(
		initial_linear_at_anchor,
		initial_angular,
		anchor_world,
		right.to_global(right.matter_center_of_mass_local)
	)
	left.angular_velocity = initial_angular
	right.angular_velocity = initial_angular

	var joint := PinJoint3D.new()
	joint.name = "ActorMechanicalLink"
	world.add_child(joint)
	joint.global_position = anchor_world
	joint.node_a = joint.get_path_to(left)
	joint.node_b = joint.get_path_to(right)
	joint.exclude_nodes_from_collision = true

	var actor := FrameProbeCharacter.new()
	actor.name = "JointRider"
	world.add_child(actor)
	actor.global_position = left.to_global(ACTOR_LOCAL_START)

	var acquired := false
	for _frame in range(ACQUIRE_FRAMES):
		await physics_frame
		await process_frame
		if actor.grounded and actor.support_body == left:
			acquired = true
			break
	_check(acquired, "actor acquires the intended constrained support frame")
	if not acquired:
		_finish()
		return

	var support_local_reference := left.to_local(actor.global_position)
	var max_pre_drive_drift := 0.0
	var max_anchor_gap := 0.0
	for _frame in range(PRE_DRIVE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := left.to_local(actor.global_position)
		max_pre_drive_drift = max(
			max_pre_drive_drift,
			Vector2(local_now.x - support_local_reference.x, local_now.z - support_local_reference.z).length()
		)
		max_anchor_gap = max(max_anchor_gap, _anchor_gap(left, right, left_anchor_local, right_anchor_local))
	_check(max_pre_drive_drift < 0.002, "actor is stably riding the constrained frame before drive impulse")

	var left_linear_before := left.linear_velocity
	var left_angular_before := left.angular_velocity
	var relative_basis_before: Basis = left.global_basis.inverse() * right.global_basis
	var floor_loss := 0
	var wrong_support_frames := 0
	var max_local_drift := 0.0
	var max_relative_angle := 0.0
	var max_left_linear_change := 0.0
	var max_left_angular_change := 0.0

	# Drive only the sibling. Any material change in the support frame's motion
	# must therefore arrive through the mechanical constraint.
	right.apply_torque_impulse(assembly_transform.basis * Vector3(0.0, 55.0, 0.0))

	for _frame in range(DRIVE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := left.to_local(actor.global_position)
		max_local_drift = max(
			max_local_drift,
			Vector2(local_now.x - support_local_reference.x, local_now.z - support_local_reference.z).length()
		)
		if not actor.grounded:
			floor_loss += 1
		elif actor.support_body != left:
			wrong_support_frames += 1

		max_anchor_gap = max(max_anchor_gap, _anchor_gap(left, right, left_anchor_local, right_anchor_local))
		var relative_now: Basis = left.global_basis.inverse() * right.global_basis
		max_relative_angle = max(max_relative_angle, _basis_angle(relative_basis_before, relative_now))
		max_left_linear_change = max(max_left_linear_change, left.linear_velocity.distance_to(left_linear_before))
		max_left_angular_change = max(max_left_angular_change, left.angular_velocity.distance_to(left_angular_before))

	var final_anchor_gap := _anchor_gap(left, right, left_anchor_local, right_anchor_local)
	var left_storage_mismatch := _count_mismatches(left_snapshot, left.volume.duplicate_cells())
	var right_storage_mismatch := _count_mismatches(right_snapshot, right.volume.duplicate_cells())

	_check(floor_loss == 0, "actor never loses grounded state while sibling drives the constraint graph")
	_check(wrong_support_frames == 0, "actor support remains local to its original construct rather than transferring to the linked sibling")
	_check(max_local_drift < 0.002, "actor remains stable in support-frame coordinates during constraint-driven motion")
	_check(max_anchor_gap < 0.01 and final_anchor_gap < 0.005, "mechanical link keeps frame anchors co-located during actor ride")
	_check(max_relative_angle > 0.15, "linked sibling develops meaningful relative yaw without rigid-frame collapse")
	_check(max_left_linear_change > 0.01 or max_left_angular_change > 0.01, "support frame receives material motion change through the constraint")
	_check(left_storage_mismatch == 0 and right_storage_mismatch == 0, "constraint-driven actor composition preserves both Matter sources of truth")
	_check(left.get_parent() == world and right.get_parent() == world, "mechanical linkage remains separate from scene-tree parenting")
	_check(left.get_instance_id() != right.get_instance_id(), "linked frames retain distinct physics identities")

	print(
		"MULTIFRAME_ACTOR_JOINT_METRIC left_cells=%d right_cells=%d pre_drive_drift=%.10f max_local_drift=%.10f floor_loss=%d wrong_support_frames=%d max_anchor_gap=%.10f final_anchor_gap=%.10f max_relative_angle=%.10f max_left_linear_change=%.10f max_left_angular_change=%.10f left_storage_mismatch=%d right_storage_mismatch=%d left_id=%d right_id=%d final_left_linear=%s final_right_linear=%s final_left_angular=%s final_right_angular=%s"
		% [
			left.volume.count_solid(),
			right.volume.count_solid(),
			max_pre_drive_drift,
			max_local_drift,
			floor_loss,
			wrong_support_frames,
			max_anchor_gap,
			final_anchor_gap,
			max_relative_angle,
			max_left_linear_change,
			max_left_angular_change,
			left_storage_mismatch,
			right_storage_mismatch,
			left.get_instance_id(),
			right.get_instance_id(),
			left.linear_velocity,
			right.linear_velocity,
			left.angular_velocity,
			right.angular_velocity,
		]
	)

	_finish()


func _make_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D, layer: int) -> ConstructBody:
	var body := ConstructBody.new()
	body.name = body_name
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.can_sleep = false
	body.collision_layer = layer
	body.collision_mask = 0
	body.mass_per_cell = MASS_PER_CELL
	world.add_child(body)
	body.global_transform = transform
	body.set_volume(volume)
	return body


func _anchor_gap(left: ConstructBody, right: ConstructBody, left_local: Vector3, right_local: Vector3) -> float:
	return left.to_global(left_local).distance_to(right.to_global(right_local))


func _velocity_at_point(linear_at_anchor: Vector3, angular: Vector3, anchor_world: Vector3, point_world: Vector3) -> Vector3:
	return linear_at_anchor + angular.cross(point_world - anchor_world)


func _basis_angle(reference: Basis, current: Basis) -> float:
	var delta: Basis = reference.inverse() * current
	return abs(delta.get_rotation_quaternion().get_angle())


func _count_mismatches(expected: PackedInt32Array, actual: PackedInt32Array) -> int:
	if expected.size() != actual.size():
		return max(expected.size(), actual.size())
	var mismatches := 0
	for index in range(expected.size()):
		if expected[index] != actual[index]:
			mismatches += 1
	return mismatches


func _finish() -> void:
	if _failures.is_empty():
		print("MULTIFRAME_ACTOR_JOINT_PROBE_PASS: actor support remained local and stable on one independent Matter frame while a constrained sibling drove shared mechanical motion without frame collapse.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_ACTOR_JOINT_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
