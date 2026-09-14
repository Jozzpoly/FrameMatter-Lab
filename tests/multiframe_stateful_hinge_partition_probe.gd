extends SceneTree

const VOLUME_SIZE := Vector3i(10, 3, 3)
const CUT_CELL := Vector3i(4, 1, 1)
const LEFT_OWNER_CELL := Vector3i(0, 1, 1)
const RIGHT_OWNER_CELL := Vector3i(9, 1, 1)
const MASS_PER_CELL := 1.7
const PRE_SPLIT_FRAMES := 50
const POST_SPLIT_FRAMES := 220
const LEFT_LIMIT := 0.40
const RIGHT_LIMIT := 0.55
const LEFT_MOTOR_TARGET := 1.10
const RIGHT_MOTOR_TARGET := -1.30
const MOTOR_MAX_IMPULSE := 40.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "StatefulHingePartitionWorld"
	get_root().add_child(world)

	var parent_volume := _make_parent_volume()
	var parent_lineage := MatterLineageMap.new(VOLUME_SIZE)
	var next_token := 160001
	for cell in _occupied_cells(parent_volume):
		parent_lineage.set_lineage(cell, next_token)
		next_token += 1
	var left_owner_token := parent_lineage.get_lineage(LEFT_OWNER_CELL)
	var right_owner_token := parent_lineage.get_lineage(RIGHT_OWNER_CELL)
	_check(left_owner_token != 0 and right_owner_token != 0 and left_owner_token != right_owner_token, "two stateful hinge anchors start with distinct retained Matter lineage")

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.13, -0.43, 0.20)),
		Vector3(17.0, 8.0, -11.0)
	)
	var parent := _make_body(world, "StatefulPartitionParent", parent_volume, assembly_transform)
	var left_sibling := _make_box_body(
		world, "StatefulLeftSibling", Vector3i(3, 3, 3), 4,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(-3.0, 0.0, 0.0))
	)
	var right_sibling := _make_box_body(
		world, "StatefulRightSibling", Vector3i(3, 3, 3), 5,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	)
	var parent_id := parent.get_instance_id()
	var left_sibling_id := left_sibling.get_instance_id()
	var right_sibling_id := right_sibling.get_instance_id()

	var left_parent_frame := Transform3D(
		Basis.from_euler(Vector3(0.28, -0.16, 0.34)).orthonormalized(),
		Vector3(0.0, 1.5, 1.5)
	)
	var right_parent_frame := Transform3D(
		Basis.from_euler(Vector3(-0.21, 0.24, -0.31)).orthonormalized(),
		Vector3(10.0, 1.5, 1.5)
	)
	var left_world_initial: Transform3D = parent.global_transform * left_parent_frame
	var right_world_initial: Transform3D = parent.global_transform * right_parent_frame
	var left_sibling_frame: Transform3D = left_sibling.global_transform.affine_inverse() * left_world_initial
	var right_sibling_frame: Transform3D = right_sibling.global_transform.affine_inverse() * right_world_initial

	var common_angular := Vector3(0.18, -0.26, 0.29)
	var common_origin_velocity := Vector3(1.35, 0.12, -0.72)
	_set_shared_rigid_field(parent, left_sibling, right_sibling, common_origin_velocity, common_angular)

	var left_joint := _make_hinge(world, "LeftStatefulHinge", left_world_initial, parent, left_sibling)
	var right_joint := _make_hinge(world, "RightStatefulHinge", right_world_initial, parent, right_sibling)
	var left_joint_id := left_joint.get_instance_id()
	var right_joint_id := right_joint.get_instance_id()

	var max_pre_left_gap := 0.0
	var max_pre_right_gap := 0.0
	var max_pre_left_axis_error := 0.0
	var max_pre_right_axis_error := 0.0
	for _frame in range(PRE_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_pre_left_gap = max(max_pre_left_gap, _hinge_anchor_gap(parent, left_parent_frame, left_sibling, left_sibling_frame))
		max_pre_right_gap = max(max_pre_right_gap, _hinge_anchor_gap(parent, right_parent_frame, right_sibling, right_sibling_frame))
		max_pre_left_axis_error = max(max_pre_left_axis_error, _hinge_axis_error(parent, left_parent_frame, left_sibling, left_sibling_frame))
		max_pre_right_axis_error = max(max_pre_right_axis_error, _hinge_axis_error(parent, right_parent_frame, right_sibling, right_sibling_frame))
	_check(max_pre_left_gap < 0.01 and max_pre_right_gap < 0.01, "both passive hinge anchors are stable before graph partition")
	_check(max_pre_left_axis_error < 0.01 and max_pre_right_axis_error < 0.01, "both passive hinge axes are aligned before graph partition")

	# Commit stateful graph partition before the upcoming solver step. Reset all
	# three bodies onto one instantaneous rigid velocity field first, so both hinge
	# relative speeds begin essentially at zero. Post-split angular motion must then
	# come from each inherited motor rather than inherited relative spin.
	await physics_frame
	var parent_transform: Transform3D = parent.global_transform
	_set_shared_rigid_field(parent, left_sibling, right_sibling, common_origin_velocity, common_angular)
	var parent_linear: Vector3 = parent.linear_velocity
	var parent_angular: Vector3 = parent.angular_velocity
	var parent_com_world: Vector3 = parent.to_global(parent.matter_center_of_mass_local)
	var left_world_before: Transform3D = parent_transform * left_parent_frame
	var right_world_before: Transform3D = parent_transform * right_parent_frame
	var left_speed_before: float = _relative_hinge_speed(parent, left_parent_frame, left_sibling, left_sibling_frame)
	var right_speed_before: float = _relative_hinge_speed(parent, right_parent_frame, right_sibling, right_sibling_frame)
	var left_angle_before: float = abs(_signed_hinge_angle(parent, left_parent_frame, left_sibling, left_sibling_frame))
	var right_angle_before: float = abs(_signed_hinge_angle(parent, right_parent_frame, right_sibling, right_sibling_frame))
	_check(left_speed_before < 0.001 and right_speed_before < 0.001, "both stateful hinges begin partition with essentially zero relative angular speed")
	_check(left_angle_before < 0.04 and right_angle_before < 0.04, "both stateful hinges begin partition near their neutral angle")

	_configure_stateful_hinge(left_joint, LEFT_LIMIT, LEFT_MOTOR_TARGET)
	_configure_stateful_hinge(right_joint, RIGHT_LIMIT, RIGHT_MOTOR_TARGET)
	_check(_state_matches(left_joint, LEFT_LIMIT, LEFT_MOTOR_TARGET), "left motor/limit state is configured before graph partition")
	_check(_state_matches(right_joint, RIGHT_LIMIT, RIGHT_MOTOR_TARGET), "right motor/limit state is configured before graph partition")

	var left_origin_staleness := left_joint.global_position.distance_to(left_world_before.origin)
	var right_origin_staleness := right_joint.global_position.distance_to(right_world_before.origin)
	var left_basis_staleness := _basis_axis_error(left_joint.global_basis.orthonormalized(), left_world_before.basis.orthonormalized())
	var right_basis_staleness := _basis_axis_error(right_joint.global_basis.orthonormalized(), right_world_before.basis.orthonormalized())
	_check(left_origin_staleness > 0.1 and right_origin_staleness > 0.1, "both persistent hinge origins are materially stale before partition")
	_check(left_basis_staleness > 0.01 and right_basis_staleness > 0.01, "both persistent hinge bases are materially stale before partition")

	_check(parent.volume.set_cell(CUT_CELL, CellVolume.EMPTY), "stateful graph partition removes intended bridge Matter")
	parent_lineage.clear_lineage(CUT_CELL)
	var components: Array[CellVolume] = MatterTopology.extract_connected_components(parent.volume)
	_check(components.size() == 2, "stateful graph partition produces exactly two successors")
	if components.size() != 2:
		_finish()
		return

	var children: Array[ConstructBody] = []
	var origins: Array[Vector3i] = []
	var lineages: Array[MatterLineageMap] = []
	var left_child_index := -1
	var right_child_index := -1
	var lineage_mismatches := 0
	var max_world_error := 0.0
	var max_velocity_error := 0.0

	for index in range(components.size()):
		var source_component: CellVolume = components[index]
		var compact_info: Dictionary = MatterTopology.compact_volume(source_component)
		var origin: Vector3i = compact_info["origin"]
		var compact: CellVolume = compact_info["volume"]
		var child := _make_body(
			world,
			"StatefulPartitionSuccessor_%d" % index,
			compact,
			parent_transform * Transform3D(Basis.IDENTITY, Vector3(origin))
		)
		var child_com_world := child.to_global(child.matter_center_of_mass_local)
		child.linear_velocity = _velocity_at_point(parent_linear, parent_angular, parent_com_world, child_com_world)
		child.angular_velocity = parent_angular
		children.append(child)
		origins.append(origin)

		var lineage := MatterLineageMap.new(compact.size)
		for source_cell in _occupied_cells(source_component):
			var compact_cell := source_cell - origin
			var token := parent_lineage.get_lineage(source_cell)
			lineage.set_lineage(compact_cell, token)
			if lineage.get_lineage(compact_cell) != token:
				lineage_mismatches += 1
			var old_world := parent_transform * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
			var new_world := child.to_global(Vector3(compact_cell) + Vector3(0.5, 0.5, 0.5))
			max_world_error = max(max_world_error, old_world.distance_to(new_world))
			var old_velocity := _velocity_at_point(parent_linear, parent_angular, parent_com_world, old_world)
			var new_velocity := _velocity_at_point(child.linear_velocity, child.angular_velocity, child_com_world, new_world)
			max_velocity_error = max(max_velocity_error, old_velocity.distance_to(new_velocity))
		lineages.append(lineage)
		if source_component.get_cell(LEFT_OWNER_CELL) != CellVolume.EMPTY:
			left_child_index = index
		if source_component.get_cell(RIGHT_OWNER_CELL) != CellVolume.EMPTY:
			right_child_index = index

	_check(left_child_index >= 0 and right_child_index >= 0 and left_child_index != right_child_index, "distinct hinge owners partition onto distinct successors")
	if left_child_index < 0 or right_child_index < 0 or left_child_index == right_child_index:
		_finish()
		return

	var left_child: ConstructBody = children[left_child_index]
	var right_child: ConstructBody = children[right_child_index]
	var left_origin: Vector3i = origins[left_child_index]
	var right_origin: Vector3i = origins[right_child_index]
	var mapped_left_frame := Transform3D(left_parent_frame.basis, left_parent_frame.origin - Vector3(left_origin))
	var mapped_right_frame := Transform3D(right_parent_frame.basis, right_parent_frame.origin - Vector3(right_origin))
	var inherited_left_token := lineages[left_child_index].get_lineage(LEFT_OWNER_CELL - left_origin)
	var inherited_right_token := lineages[right_child_index].get_lineage(RIGHT_OWNER_CELL - right_origin)
	var mapped_left_world: Transform3D = left_child.global_transform * mapped_left_frame
	var mapped_right_world: Transform3D = right_child.global_transform * mapped_right_frame

	_check(inherited_left_token == left_owner_token and inherited_right_token == right_owner_token, "both stateful hinges follow their retained owner lineage")
	_check(lineage_mismatches == 0, "stateful graph partition preserves all retained Matter lineage")
	_check(max_world_error < 0.00001 and max_velocity_error < 0.00001, "stateful graph partition preserves retained Matter world/velocity continuity")
	_check(mapped_left_world.origin.distance_to(left_world_before.origin) < 0.00001 and mapped_right_world.origin.distance_to(right_world_before.origin) < 0.00001, "both hinge anchors map continuously into compact successors")
	_check(_basis_axis_error(mapped_left_world.basis.orthonormalized(), left_world_before.basis.orthonormalized()) < 0.00001, "left hinge basis maps continuously into compact successor")
	_check(_basis_axis_error(mapped_right_world.basis.orthonormalized(), right_world_before.basis.orthonormalized()) < 0.00001, "right hinge basis maps continuously into compact successor")

	left_joint.global_transform = left_world_before
	left_joint.force_update_transform()
	right_joint.global_transform = right_world_before
	right_joint.force_update_transform()
	var left_rebase_origin_error := left_joint.global_position.distance_to(left_world_before.origin)
	var right_rebase_origin_error := right_joint.global_position.distance_to(right_world_before.origin)
	var left_rebase_basis_error := _basis_axis_error(left_joint.global_basis.orthonormalized(), left_world_before.basis.orthonormalized())
	var right_rebase_basis_error := _basis_axis_error(right_joint.global_basis.orthonormalized(), right_world_before.basis.orthonormalized())
	left_joint.node_a = left_joint.get_path_to(left_child)
	right_joint.node_a = right_joint.get_path_to(right_child)

	_check(left_rebase_origin_error < 0.000001 and right_rebase_origin_error < 0.000001, "both hinge origins rebase exactly before endpoint replacement")
	_check(left_rebase_basis_error < 0.000001 and right_rebase_basis_error < 0.000001, "both hinge bases rebase exactly before endpoint replacement")
	_check(left_joint.get_instance_id() == left_joint_id and right_joint.get_instance_id() == right_joint_id, "both logical stateful hinge identities survive graph partition")
	_check(left_sibling.get_instance_id() == left_sibling_id and right_sibling.get_instance_id() == right_sibling_id, "unaffected external hinge endpoints preserve body identity")
	_check(left_child.get_instance_id() != parent_id and right_child.get_instance_id() != parent_id, "both successors replace the old parent physics identity")
	_check(_state_matches(left_joint, LEFT_LIMIT, LEFT_MOTOR_TARGET), "left motor/limit state survives host hinge reconstruction")
	_check(_state_matches(right_joint, RIGHT_LIMIT, RIGHT_MOTOR_TARGET), "right motor/limit state survives host hinge reconstruction")
	parent.free()

	await process_frame
	await physics_frame
	await process_frame

	var max_left_gap := 0.0
	var max_right_gap := 0.0
	var max_left_axis_error := 0.0
	var max_right_axis_error := 0.0
	var max_left_angle := 0.0
	var max_right_angle := 0.0
	var max_left_speed := 0.0
	var max_right_speed := 0.0
	var left_angle_after_30 := 0.0
	var right_angle_after_30 := 0.0
	var initial_child_distance := left_child.global_position.distance_to(right_child.global_position)
	var max_child_distance_change := 0.0

	# Opposite central impulses demonstrate that the two inherited mechanisms are
	# independent mechanical islands. They do not add torque around either hinge;
	# the measured hinge rotation must still come from each motor.
	left_sibling.apply_central_impulse(assembly_transform.basis * Vector3(-5.0, 2.0, 4.0))
	right_sibling.apply_central_impulse(assembly_transform.basis * Vector3(6.0, -2.0, -5.0))

	for frame in range(POST_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		var left_angle: float = abs(_signed_hinge_angle(left_child, mapped_left_frame, left_sibling, left_sibling_frame))
		var right_angle: float = abs(_signed_hinge_angle(right_child, mapped_right_frame, right_sibling, right_sibling_frame))
		var left_speed: float = _relative_hinge_speed(left_child, mapped_left_frame, left_sibling, left_sibling_frame)
		var right_speed: float = _relative_hinge_speed(right_child, mapped_right_frame, right_sibling, right_sibling_frame)
		max_left_angle = max(max_left_angle, left_angle)
		max_right_angle = max(max_right_angle, right_angle)
		max_left_speed = max(max_left_speed, left_speed)
		max_right_speed = max(max_right_speed, right_speed)
		max_left_gap = max(max_left_gap, _hinge_anchor_gap(left_child, mapped_left_frame, left_sibling, left_sibling_frame))
		max_right_gap = max(max_right_gap, _hinge_anchor_gap(right_child, mapped_right_frame, right_sibling, right_sibling_frame))
		max_left_axis_error = max(max_left_axis_error, _hinge_axis_error(left_child, mapped_left_frame, left_sibling, left_sibling_frame))
		max_right_axis_error = max(max_right_axis_error, _hinge_axis_error(right_child, mapped_right_frame, right_sibling, right_sibling_frame))
		max_child_distance_change = max(max_child_distance_change, abs(left_child.global_position.distance_to(right_child.global_position) - initial_child_distance))
		if frame == 30:
			left_angle_after_30 = left_angle
			right_angle_after_30 = right_angle
		_check(_finite_body_state(left_child) and _finite_body_state(right_child) and _finite_body_state(left_sibling) and _finite_body_state(right_sibling), "stateful partitioned hinge graph remains numerically finite")

	var final_left_angle: float = abs(_signed_hinge_angle(left_child, mapped_left_frame, left_sibling, left_sibling_frame))
	var final_right_angle: float = abs(_signed_hinge_angle(right_child, mapped_right_frame, right_sibling, right_sibling_frame))
	var final_left_speed: float = _relative_hinge_speed(left_child, mapped_left_frame, left_sibling, left_sibling_frame)
	var final_right_speed: float = _relative_hinge_speed(right_child, mapped_right_frame, right_sibling, right_sibling_frame)
	var final_left_gap: float = _hinge_anchor_gap(left_child, mapped_left_frame, left_sibling, left_sibling_frame)
	var final_right_gap: float = _hinge_anchor_gap(right_child, mapped_right_frame, right_sibling, right_sibling_frame)
	var final_left_axis_error: float = _hinge_axis_error(left_child, mapped_left_frame, left_sibling, left_sibling_frame)
	var final_right_axis_error: float = _hinge_axis_error(right_child, mapped_right_frame, right_sibling, right_sibling_frame)

	_check(left_angle_after_30 > 0.08 and right_angle_after_30 > 0.08, "both inherited motors create early post-partition relative rotation")
	_check(max_left_speed > 0.4 and max_right_speed > 0.4, "both inherited motors produce material relative angular speed")
	_check(max_left_angle > 0.25 and max_left_angle < LEFT_LIMIT + 0.12, "left inherited hinge reaches but does not escape its angular range")
	_check(max_right_angle > 0.35 and max_right_angle < RIGHT_LIMIT + 0.12, "right inherited hinge reaches but does not escape its angular range")
	_check(final_left_angle > 0.25 and final_left_angle < LEFT_LIMIT + 0.10, "left stateful hinge settles near its configured limit")
	_check(final_right_angle > 0.35 and final_right_angle < RIGHT_LIMIT + 0.10, "right stateful hinge settles near its configured limit")
	_check(final_left_speed < 0.20 and final_right_speed < 0.20, "both angular limits arrest sustained motor-driven rotation")
	_check(max_left_gap < 0.02 and max_right_gap < 0.02 and final_left_gap < 0.006 and final_right_gap < 0.006, "both inherited stateful hinges keep tight translational anchors")
	_check(max_left_axis_error < 0.02 and max_right_axis_error < 0.02 and final_left_axis_error < 0.01 and final_right_axis_error < 0.01, "both inherited stateful hinges preserve physical hinge axes")
	_check(max_child_distance_change > 0.1, "partitioned stateful hinge mechanisms remain independent mechanical islands")
	_check(left_joint.node_a == left_joint.get_path_to(left_child) and right_joint.node_a == right_joint.get_path_to(right_child), "each stateful hinge remains mapped to its lineage-owning successor")

	print(
		"MULTIFRAME_STATEFUL_HINGE_PARTITION_METRIC left_token=%d inherited_left=%d right_token=%d inherited_right=%d lineage_mismatches=%d world_error=%.10f velocity_error=%.10f left_angle_before=%.10f right_angle_before=%.10f left_speed_before=%.10f right_speed_before=%.10f left_origin_staleness=%.10f right_origin_staleness=%.10f left_basis_staleness=%.10f right_basis_staleness=%.10f left_rebase_origin_error=%.10f right_rebase_origin_error=%.10f left_rebase_basis_error=%.10f right_rebase_basis_error=%.10f left_angle_after_30=%.6f right_angle_after_30=%.6f max_left_angle=%.6f max_right_angle=%.6f final_left_angle=%.6f final_right_angle=%.6f max_left_speed=%.6f max_right_speed=%.6f final_left_speed=%.6f final_right_speed=%.6f max_left_gap=%.10f max_right_gap=%.10f final_left_gap=%.10f final_right_gap=%.10f max_left_axis_error=%.10f max_right_axis_error=%.10f final_left_axis_error=%.10f final_right_axis_error=%.10f child_distance_change=%.6f left_joint_id=%d right_joint_id=%d"
		% [
			left_owner_token, inherited_left_token, right_owner_token, inherited_right_token,
			lineage_mismatches, max_world_error, max_velocity_error,
			left_angle_before, right_angle_before, left_speed_before, right_speed_before,
			left_origin_staleness, right_origin_staleness, left_basis_staleness, right_basis_staleness,
			left_rebase_origin_error, right_rebase_origin_error, left_rebase_basis_error, right_rebase_basis_error,
			left_angle_after_30, right_angle_after_30,
			max_left_angle, max_right_angle, final_left_angle, final_right_angle,
			max_left_speed, max_right_speed, final_left_speed, final_right_speed,
			max_left_gap, max_right_gap, final_left_gap, final_right_gap,
			max_left_axis_error, max_right_axis_error, final_left_axis_error, final_right_axis_error,
			max_child_distance_change, left_joint_id, right_joint_id,
		]
	)

	_finish()


func _make_parent_volume() -> CellVolume:
	var volume := CellVolume.new(VOLUME_SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 3, 3), 2)
	volume.fill_box(Vector3i(6, 0, 0), Vector3i(10, 3, 3), 2)
	for x in range(3, 6):
		volume.set_cell(Vector3i(x, 1, 1), 2)
	return volume


func _make_box_body(world: Node3D, body_name: String, size: Vector3i, material: int, transform: Transform3D) -> ConstructBody:
	var volume := CellVolume.new(size)
	volume.fill_box(Vector3i.ZERO, size, material)
	return _make_body(world, body_name, volume, transform)


func _make_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D) -> ConstructBody:
	var body := ConstructBody.new()
	body.name = body_name
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.can_sleep = false
	body.collision_layer = 0
	body.collision_mask = 0
	body.mass_per_cell = MASS_PER_CELL
	world.add_child(body)
	body.global_transform = transform
	body.set_volume(volume)
	return body


func _make_hinge(world: Node3D, joint_name: String, world_frame: Transform3D, body_a: ConstructBody, body_b: ConstructBody) -> HingeJoint3D:
	var joint := HingeJoint3D.new()
	joint.name = joint_name
	world.add_child(joint)
	joint.global_transform = world_frame
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
	joint.exclude_nodes_from_collision = true
	return joint


func _configure_stateful_hinge(joint: HingeJoint3D, limit_abs: float, motor_target: float) -> void:
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -limit_abs)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, limit_abs)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, motor_target)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, MOTOR_MAX_IMPULSE)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)


func _state_matches(joint: HingeJoint3D, limit_abs: float, motor_target: float) -> bool:
	return (
		joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
		and joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		and abs(joint.get_param(HingeJoint3D.PARAM_LIMIT_LOWER) + limit_abs) < 0.000001
		and abs(joint.get_param(HingeJoint3D.PARAM_LIMIT_UPPER) - limit_abs) < 0.000001
		and abs(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY) - motor_target) < 0.000001
	)


func _set_shared_rigid_field(parent: ConstructBody, left_sibling: ConstructBody, right_sibling: ConstructBody, linear_at_parent_com: Vector3, angular: Vector3) -> void:
	var parent_com_world := parent.to_global(parent.matter_center_of_mass_local)
	parent.linear_velocity = linear_at_parent_com
	parent.angular_velocity = angular
	for body in [left_sibling, right_sibling]:
		body.linear_velocity = _velocity_at_point(linear_at_parent_com, angular, parent_com_world, body.to_global(body.matter_center_of_mass_local))
		body.angular_velocity = angular


func _hinge_anchor_gap(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	return (body_a.global_transform * frame_a).origin.distance_to((body_b.global_transform * frame_b).origin)


func _hinge_axis(body: ConstructBody, frame: Transform3D) -> Vector3:
	return (body.global_basis * frame.basis.z).normalized()


func _hinge_axis_error(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	return _hinge_axis(body_a, frame_a).angle_to(_hinge_axis(body_b, frame_b))


func _signed_hinge_angle(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	var axis_a := _hinge_axis(body_a, frame_a)
	var axis_b := _hinge_axis(body_b, frame_b)
	var axis := (axis_a + axis_b).normalized()
	var normal_a := (body_a.global_basis * frame_a.basis.x).normalized()
	var normal_b := (body_b.global_basis * frame_b.basis.x).normalized()
	var sin_term := axis.dot(normal_a.cross(normal_b))
	var cos_term: float = clampf(normal_a.dot(normal_b), -1.0, 1.0)
	return atan2(sin_term, cos_term)


func _relative_hinge_speed(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	var axis_a := _hinge_axis(body_a, frame_a)
	var axis_b := _hinge_axis(body_b, frame_b)
	var axis := (axis_a + axis_b).normalized()
	return abs((body_b.angular_velocity - body_a.angular_velocity).dot(axis))


func _basis_axis_error(a: Basis, b: Basis) -> float:
	return max(a.x.distance_to(b.x), max(a.y.distance_to(b.y), a.z.distance_to(b.z)))


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					cells.append(cell)
	return cells


func _velocity_at_point(linear: Vector3, angular: Vector3, com_world: Vector3, point_world: Vector3) -> Vector3:
	return linear + angular.cross(point_world - com_world)


func _finite_body_state(body: ConstructBody) -> bool:
	return (
		body.global_position.is_finite()
		and body.linear_velocity.is_finite()
		and body.angular_velocity.is_finite()
		and body.matter_center_of_mass_local.is_finite()
		and is_finite(body.mass)
	)


func _finish() -> void:
	if _failures.is_empty():
		print("MULTIFRAME_STATEFUL_HINGE_PARTITION_PROBE_PASS: one topology split partitioned two independently stateful motor/limit hinges onto different lineage-owned successors while preserving full constraint frames and active behavior.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_STATEFUL_HINGE_PARTITION_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
