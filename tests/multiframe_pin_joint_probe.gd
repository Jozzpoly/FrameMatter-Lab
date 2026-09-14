extends SceneTree

const MASS_PER_CELL := 3.0
const SETTLE_FRAMES := 30
const DRIVE_FRAMES := 180

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "MultiFrameJointWorld"
	get_root().add_child(world)

	var left_volume := CellVolume.new(Vector3i(3, 2, 2))
	left_volume.fill_box(Vector3i.ZERO, left_volume.size, CellVolume.SOLID)
	left_volume.set_cell(Vector3i(0, 1, 1), 2)

	var right_volume := CellVolume.new(Vector3i(2, 2, 2))
	right_volume.fill_box(Vector3i.ZERO, right_volume.size, CellVolume.SOLID)
	right_volume.set_cell(Vector3i(1, 0, 1), 3)

	var left_snapshot := left_volume.duplicate_cells()
	var right_snapshot := right_volume.duplicate_cells()

	var basis := Basis.from_euler(Vector3(0.21, -0.47, 0.18))
	var assembly_transform := Transform3D(basis, Vector3(11.0, 4.0, -7.0))
	var left := _make_body(world, "LeftFrame", left_volume, assembly_transform)
	var right := _make_body(
		world,
		"RightFrame",
		right_volume,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, 0.0))
	)

	var anchor_world: Vector3 = assembly_transform * Vector3(3.0, 1.0, 1.0)
	var left_anchor_local: Vector3 = left.to_local(anchor_world)
	var right_anchor_local: Vector3 = right.to_local(anchor_world)

	var common_linear_at_anchor := Vector3(1.3, -0.25, 0.8)
	var common_angular := Vector3(0.16, -0.31, 0.22)
	left.linear_velocity = _velocity_at_point(
		common_linear_at_anchor,
		common_angular,
		anchor_world,
		left.global_transform * left.matter_center_of_mass_local
	)
	right.linear_velocity = _velocity_at_point(
		common_linear_at_anchor,
		common_angular,
		anchor_world,
		right.global_transform * right.matter_center_of_mass_local
	)
	left.angular_velocity = common_angular
	right.angular_velocity = common_angular

	var joint := PinJoint3D.new()
	joint.name = "MechanicalLink"
	world.add_child(joint)
	joint.global_position = anchor_world
	joint.node_a = joint.get_path_to(left)
	joint.node_b = joint.get_path_to(right)
	joint.exclude_nodes_from_collision = true

	_check(left.get_parent() == world and right.get_parent() == world, "linked constructs remain sibling frames, not transform-parented")
	_check(left.get_instance_id() != right.get_instance_id(), "linked constructs retain distinct physics-body identity")
	_check(left.volume != right.volume, "linked constructs retain distinct Matter volumes")

	var max_anchor_gap := 0.0
	for _frame in range(SETTLE_FRAMES):
		await physics_frame
		await process_frame
		max_anchor_gap = max(max_anchor_gap, _anchor_gap(left, right, left_anchor_local, right_anchor_local))

	var relative_before: Basis = left.global_basis.inverse() * right.global_basis
	right.apply_torque_impulse(assembly_transform.basis * Vector3(0.0, 18.0, 7.0))

	var max_relative_angle := 0.0
	for _frame in range(DRIVE_FRAMES):
		await physics_frame
		await process_frame
		max_anchor_gap = max(max_anchor_gap, _anchor_gap(left, right, left_anchor_local, right_anchor_local))
		var relative_now: Basis = left.global_basis.inverse() * right.global_basis
		max_relative_angle = max(max_relative_angle, _basis_angle(relative_before, relative_now))

	var final_anchor_gap := _anchor_gap(left, right, left_anchor_local, right_anchor_local)
	var left_storage_mismatch := _count_mismatches(left_snapshot, left.volume.duplicate_cells())
	var right_storage_mismatch := _count_mismatches(right_snapshot, right.volume.duplicate_cells())

	_check(max_anchor_gap < 0.01, "joint keeps the two independent frame anchors co-located")
	_check(final_anchor_gap < 0.005, "joint remains closed after driven relative motion")
	_check(max_relative_angle > 0.15, "constraint permits material relative rotation rather than collapsing frames into one rigid transform")
	_check(left_storage_mismatch == 0 and right_storage_mismatch == 0, "constraint motion does not mutate either Matter source of truth")
	_check(left.get_parent() == world and right.get_parent() == world, "mechanical linkage never becomes scene-tree parenting")

	print(
		"MULTIFRAME_PIN_JOINT_METRIC left_cells=%d right_cells=%d max_anchor_gap=%.10f final_anchor_gap=%.10f max_relative_angle=%.10f left_storage_mismatch=%d right_storage_mismatch=%d left_body_id=%d right_body_id=%d left_linear=%s right_linear=%s left_angular=%s right_angular=%s"
		% [
			left.volume.count_solid(),
			right.volume.count_solid(),
			max_anchor_gap,
			final_anchor_gap,
			max_relative_angle,
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


func _make_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D) -> ConstructBody:
	var body := ConstructBody.new()
	body.name = body_name
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = 0
	body.collision_mask = 0
	body.mass_per_cell = MASS_PER_CELL
	world.add_child(body)
	body.global_transform = transform
	body.set_volume(volume)
	return body


func _anchor_gap(left: ConstructBody, right: ConstructBody, left_local: Vector3, right_local: Vector3) -> float:
	return (left.global_transform * left_local).distance_to(right.global_transform * right_local)


func _velocity_at_point(linear_at_origin: Vector3, angular: Vector3, origin_world: Vector3, point_world: Vector3) -> Vector3:
	return linear_at_origin + angular.cross(point_world - origin_world)


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
		print("MULTIFRAME_PIN_JOINT_PROBE_PASS: two independent Matter frames remained separate identities while one physics constraint coupled their motion and allowed relative rotation.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_PIN_JOINT_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
