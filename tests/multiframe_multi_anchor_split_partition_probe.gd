extends SceneTree

const VOLUME_SIZE := Vector3i(10, 3, 3)
const CUT_CELL := Vector3i(4, 1, 1)
const LEFT_OWNER_CELL := Vector3i(0, 1, 1)
const RIGHT_OWNER_CELL := Vector3i(9, 1, 1)
const MASS_PER_CELL := 1.6
const PRE_SPLIT_FRAMES := 60
const POST_SPLIT_FRAMES := 180

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "MultiAnchorSplitPartitionWorld"
	get_root().add_child(world)

	var parent_volume := _make_parent_volume()
	var parent_lineage := MatterLineageMap.new(VOLUME_SIZE)
	var next_token := 70001
	for cell in _occupied_cells(parent_volume):
		parent_lineage.set_lineage(cell, next_token)
		next_token += 1
	var left_owner_token := parent_lineage.get_lineage(LEFT_OWNER_CELL)
	var right_owner_token := parent_lineage.get_lineage(RIGHT_OWNER_CELL)
	_check(left_owner_token != 0 and right_owner_token != 0 and left_owner_token != right_owner_token, "both mechanical anchors start with distinct retained Matter lineage")

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.14, -0.47, 0.22)),
		Vector3(18.0, 9.0, -12.0)
	)
	var parent := _make_body(world, "PartitionParent", parent_volume, assembly_transform)
	var left_sibling := _make_box_body(
		world,
		"LeftPersistentSibling",
		Vector3i(3, 3, 3),
		4,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(-3.0, 0.0, 0.0))
	)
	var right_sibling := _make_box_body(
		world,
		"RightPersistentSibling",
		Vector3i(3, 3, 3),
		5,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	)
	var parent_id := parent.get_instance_id()
	var left_sibling_id := left_sibling.get_instance_id()
	var right_sibling_id := right_sibling.get_instance_id()

	var left_parent_anchor_local := Vector3(0.0, 1.5, 1.5)
	var right_parent_anchor_local := Vector3(10.0, 1.5, 1.5)
	var left_anchor_world: Vector3 = parent.to_global(left_parent_anchor_local)
	var right_anchor_world: Vector3 = parent.to_global(right_parent_anchor_local)
	var left_sibling_anchor_local: Vector3 = left_sibling.to_local(left_anchor_world)
	var right_sibling_anchor_local: Vector3 = right_sibling.to_local(right_anchor_world)

	# Give all three bodies one common instantaneous rigid velocity field so the
	# two pin constraints begin without an artificial bind impulse.
	var common_linear := Vector3(1.7, 0.25, -0.9)
	var common_angular := Vector3(0.16, -0.31, 0.24)
	var parent_com_world: Vector3 = parent.to_global(parent.matter_center_of_mass_local)
	parent.linear_velocity = common_linear
	parent.angular_velocity = common_angular
	left_sibling.linear_velocity = _velocity_at_point(common_linear, common_angular, parent_com_world, left_sibling.to_global(left_sibling.matter_center_of_mass_local))
	right_sibling.linear_velocity = _velocity_at_point(common_linear, common_angular, parent_com_world, right_sibling.to_global(right_sibling.matter_center_of_mass_local))
	left_sibling.angular_velocity = common_angular
	right_sibling.angular_velocity = common_angular

	var left_joint := _make_pin_joint(world, "LeftMechanicalLink", left_anchor_world, parent, left_sibling)
	var right_joint := _make_pin_joint(world, "RightMechanicalLink", right_anchor_world, parent, right_sibling)
	var left_joint_id := left_joint.get_instance_id()
	var right_joint_id := right_joint.get_instance_id()

	var max_pre_left_gap := 0.0
	var max_pre_right_gap := 0.0
	for _frame in range(PRE_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_pre_left_gap = max(max_pre_left_gap, parent.to_global(left_parent_anchor_local).distance_to(left_sibling.to_global(left_sibling_anchor_local)))
		max_pre_right_gap = max(max_pre_right_gap, parent.to_global(right_parent_anchor_local).distance_to(right_sibling.to_global(right_sibling_anchor_local)))
	_check(max_pre_left_gap < 0.01 and max_pre_right_gap < 0.01, "both mechanical anchors remain bounded before topology partition")

	# Commit the split and graph partition before the upcoming PhysicsServer step.
	await physics_frame
	var parent_transform: Transform3D = parent.global_transform
	var parent_linear: Vector3 = parent.linear_velocity
	var parent_angular: Vector3 = parent.angular_velocity
	parent_com_world = parent.to_global(parent.matter_center_of_mass_local)
	var left_anchor_now: Vector3 = parent.to_global(left_parent_anchor_local)
	var right_anchor_now: Vector3 = parent.to_global(right_parent_anchor_local)
	var left_joint_staleness := left_joint.global_position.distance_to(left_anchor_now)
	var right_joint_staleness := right_joint.global_position.distance_to(right_anchor_now)

	_check(parent.volume.set_cell(CUT_CELL, CellVolume.EMPTY), "partition transaction removes the intended bridge Matter")
	parent_lineage.clear_lineage(CUT_CELL)
	var components: Array[CellVolume] = MatterTopology.extract_connected_components(parent.volume)
	_check(components.size() == 2, "one parent split produces exactly two successor frames")
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
		var source_component := components[index]
		var compact_info: Dictionary = MatterTopology.compact_volume(source_component)
		var origin: Vector3i = compact_info["origin"]
		var compact: CellVolume = compact_info["volume"]
		var child := _make_body(
			world,
			"PartitionSuccessor_%d" % index,
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

	_check(left_child_index >= 0 and right_child_index >= 0, "each anchor owner maps to a successor")
	_check(left_child_index != right_child_index, "the topology cut partitions the two mechanical anchors onto different successors")
	if left_child_index < 0 or right_child_index < 0 or left_child_index == right_child_index:
		_finish()
		return

	var left_child := children[left_child_index]
	var right_child := children[right_child_index]
	var left_origin := origins[left_child_index]
	var right_origin := origins[right_child_index]
	var left_anchor_local := left_parent_anchor_local - Vector3(left_origin)
	var right_anchor_local := right_parent_anchor_local - Vector3(right_origin)
	var left_owner_local := LEFT_OWNER_CELL - left_origin
	var right_owner_local := RIGHT_OWNER_CELL - right_origin
	var inherited_left_token := lineages[left_child_index].get_lineage(left_owner_local)
	var inherited_right_token := lineages[right_child_index].get_lineage(right_owner_local)

	_check(inherited_left_token == left_owner_token, "left mechanical endpoint follows its retained owner lineage")
	_check(inherited_right_token == right_owner_token, "right mechanical endpoint follows its retained owner lineage")
	_check(lineage_mismatches == 0, "all retained Matter lineage survives graph partition")
	_check(max_world_error < 0.00001, "graph partition preserves retained Matter world positions")
	_check(max_velocity_error < 0.00001, "graph partition preserves retained Matter instantaneous velocity field")
	_check(left_child.to_global(left_anchor_local).distance_to(left_anchor_now) < 0.00001, "left logical anchor maps continuously into its compact successor")
	_check(right_child.to_global(right_anchor_local).distance_to(right_anchor_now) < 0.00001, "right logical anchor maps continuously into its compact successor")
	_check(left_joint_staleness > 0.1 and right_joint_staleness > 0.1, "both persistent Joint3D scene frames are materially stale before succession")

	# Rebase each persistent constraint frame to its current logical anchor before
	# endpoint replacement. Each joint then follows the Matter lineage it owns.
	left_joint.global_position = left_anchor_now
	left_joint.force_update_transform()
	right_joint.global_position = right_anchor_now
	right_joint.force_update_transform()
	var left_rebase_error := left_joint.global_position.distance_to(left_anchor_now)
	var right_rebase_error := right_joint.global_position.distance_to(right_anchor_now)
	left_joint.node_a = left_joint.get_path_to(left_child)
	right_joint.node_a = right_joint.get_path_to(right_child)

	_check(left_rebase_error < 0.000001 and right_rebase_error < 0.000001, "both constraint frames rebase exactly before endpoint succession")
	_check(left_joint.get_instance_id() == left_joint_id and right_joint.get_instance_id() == right_joint_id, "both logical mechanical-link identities survive graph partition")
	_check(left_sibling.get_instance_id() == left_sibling_id and right_sibling.get_instance_id() == right_sibling_id, "both unaffected external endpoints preserve physics identity")
	_check(left_child.get_instance_id() != parent_id and right_child.get_instance_id() != parent_id, "both topology successors replace the old parent physics identity")
	parent.free()

	await process_frame
	await physics_frame
	await process_frame

	var left_linear_before := left_child.linear_velocity
	var left_angular_before := left_child.angular_velocity
	var right_linear_before := right_child.linear_velocity
	var right_angular_before := right_child.angular_velocity
	var initial_child_distance := left_child.global_position.distance_to(right_child.global_position)

	# Drive the two inherited mechanical islands in opposite directions. There is
	# deliberately no constraint between the two topology successors.
	left_sibling.apply_central_impulse(assembly_transform.basis * Vector3(-14.0, 3.0, 7.0))
	left_sibling.apply_torque_impulse(assembly_transform.basis * Vector3(5.0, 11.0, -4.0))
	right_sibling.apply_central_impulse(assembly_transform.basis * Vector3(16.0, -2.0, -8.0))
	right_sibling.apply_torque_impulse(assembly_transform.basis * Vector3(-6.0, -13.0, 5.0))

	var max_left_anchor_gap := 0.0
	var max_right_anchor_gap := 0.0
	var max_child_distance_change := 0.0
	for _frame in range(POST_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_left_anchor_gap = max(max_left_anchor_gap, left_child.to_global(left_anchor_local).distance_to(left_sibling.to_global(left_sibling_anchor_local)))
		max_right_anchor_gap = max(max_right_anchor_gap, right_child.to_global(right_anchor_local).distance_to(right_sibling.to_global(right_sibling_anchor_local)))
		max_child_distance_change = max(max_child_distance_change, abs(left_child.global_position.distance_to(right_child.global_position) - initial_child_distance))
		_check(_finite_body_state(left_child) and _finite_body_state(right_child) and _finite_body_state(left_sibling) and _finite_body_state(right_sibling), "partitioned mechanical graph remains numerically finite")

	var final_left_gap := left_child.to_global(left_anchor_local).distance_to(left_sibling.to_global(left_sibling_anchor_local))
	var final_right_gap := right_child.to_global(right_anchor_local).distance_to(right_sibling.to_global(right_sibling_anchor_local))
	var left_linear_change := left_child.linear_velocity.distance_to(left_linear_before)
	var left_angular_change := left_child.angular_velocity.distance_to(left_angular_before)
	var right_linear_change := right_child.linear_velocity.distance_to(right_linear_before)
	var right_angular_change := right_child.angular_velocity.distance_to(right_angular_before)

	_check(max_left_anchor_gap < 0.02 and max_right_anchor_gap < 0.02, "both inherited joints remain bounded after one-to-two graph partition")
	_check(final_left_gap < 0.005 and final_right_gap < 0.005, "both inherited joints finish with tight anchors")
	_check(max_child_distance_change > 0.1, "the two successor mechanical islands can diverge independently after the parent split")
	_check(left_linear_change > 0.01 or left_angular_change > 0.01, "left successor receives mechanical reaction through its inherited link")
	_check(right_linear_change > 0.01 or right_angular_change > 0.01, "right successor receives mechanical reaction through its inherited link")
	_check(left_joint.node_a == left_joint.get_path_to(left_child) and right_joint.node_a == right_joint.get_path_to(right_child), "each joint remains mapped to the lineage-owning successor")
	_check(left_joint.node_b == left_joint.get_path_to(left_sibling) and right_joint.node_b == right_joint.get_path_to(right_sibling), "external endpoints remain unchanged")

	print(
		"MULTIFRAME_MULTI_ANCHOR_PARTITION_METRIC components=%d left_index=%d right_index=%d left_token=%d inherited_left=%d right_token=%d inherited_right=%d lineage_mismatches=%d world_error=%.10f velocity_error=%.10f left_staleness=%.10f right_staleness=%.10f left_rebase_error=%.10f right_rebase_error=%.10f max_left_gap=%.10f final_left_gap=%.10f max_right_gap=%.10f final_right_gap=%.10f child_distance_change=%.6f left_linear_change=%.6f left_angular_change=%.6f right_linear_change=%.6f right_angular_change=%.6f left_joint_id=%d right_joint_id=%d"
		% [
			components.size(), left_child_index, right_child_index,
			left_owner_token, inherited_left_token, right_owner_token, inherited_right_token,
			lineage_mismatches, max_world_error, max_velocity_error,
			left_joint_staleness, right_joint_staleness, left_rebase_error, right_rebase_error,
			max_left_anchor_gap, final_left_gap, max_right_anchor_gap, final_right_gap,
			max_child_distance_change,
			left_linear_change, left_angular_change, right_linear_change, right_angular_change,
			left_joint_id, right_joint_id,
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


func _make_box_body(world: Node3D, body_name: String, size: Vector3i, material_id: int, transform: Transform3D) -> ConstructBody:
	var volume := CellVolume.new(size)
	volume.fill_box(Vector3i.ZERO, size, material_id)
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


func _make_pin_joint(world: Node3D, joint_name: String, anchor_world: Vector3, body_a: ConstructBody, body_b: ConstructBody) -> PinJoint3D:
	var joint := PinJoint3D.new()
	joint.name = joint_name
	world.add_child(joint)
	joint.global_position = anchor_world
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
	joint.exclude_nodes_from_collision = true
	return joint


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
		print("MULTIFRAME_MULTI_ANCHOR_PARTITION_PROBE_PASS: two lineage-owned mechanical anchors partitioned onto different topology successors while both logical links survived and the resulting mechanical islands remained independent.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_MULTI_ANCHOR_PARTITION_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
