extends SceneTree

const OWNER_CELL := Vector3i(5, 1, 1)
const OWNER_MATERIAL := 2
const MASS_PER_CELL := 1.9
const PRE_BREAK_FRAMES := 60
const POST_BREAK_FRAMES := 90
const POST_RECREATE_FRAMES := 90
const RECREATED_TOKEN := 910001

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "MechanicalAnchorDestructionWorld"
	get_root().add_child(world)

	var owner_volume := CellVolume.new(Vector3i(6, 3, 3))
	owner_volume.fill_box(Vector3i.ZERO, owner_volume.size, OWNER_MATERIAL)
	var sibling_volume := CellVolume.new(Vector3i(3, 3, 3))
	sibling_volume.fill_box(Vector3i.ZERO, sibling_volume.size, 3)

	var lineage := MatterLineageMap.new(owner_volume.size)
	var next_token := 81001
	for cell in _occupied_cells(owner_volume):
		lineage.set_lineage(cell, next_token)
		next_token += 1
	var owner_token := lineage.get_lineage(OWNER_CELL)
	_check(owner_token != 0, "mechanical anchor owner begins with retained Matter lineage")

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.12, -0.38, 0.19)),
		Vector3(11.0, 8.0, -6.0)
	)
	var owner_body := _make_body(world, "AnchorOwnerConstruct", owner_volume, assembly_transform)
	var sibling := _make_body(
		world,
		"PersistentSibling",
		sibling_volume,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(6.0, 0.0, 0.0))
	)
	var owner_body_id := owner_body.get_instance_id()
	var sibling_id := sibling.get_instance_id()

	var owner_anchor_local := Vector3(6.0, 1.5, 1.5)
	var anchor_world := owner_body.to_global(owner_anchor_local)
	var sibling_anchor_local := sibling.to_local(anchor_world)
	var common_linear := Vector3(1.4, -0.15, 0.8)
	var common_angular := Vector3(0.18, -0.29, 0.21)
	var owner_com_world := owner_body.to_global(owner_body.matter_center_of_mass_local)
	owner_body.linear_velocity = common_linear
	owner_body.angular_velocity = common_angular
	sibling.linear_velocity = _velocity_at_point(common_linear, common_angular, owner_com_world, sibling.to_global(sibling.matter_center_of_mass_local))
	sibling.angular_velocity = common_angular

	var joint := PinJoint3D.new()
	joint.name = "OwnedMechanicalLink"
	world.add_child(joint)
	joint.global_position = anchor_world
	joint.node_a = joint.get_path_to(owner_body)
	joint.node_b = joint.get_path_to(sibling)
	joint.exclude_nodes_from_collision = true
	var retired_joint_id := joint.get_instance_id()

	var max_pre_break_gap := 0.0
	for _frame in range(PRE_BREAK_FRAMES):
		await physics_frame
		await process_frame
		max_pre_break_gap = max(max_pre_break_gap, owner_body.to_global(owner_anchor_local).distance_to(sibling.to_global(sibling_anchor_local)))
	_check(max_pre_break_gap < 0.01, "owned mechanical link is stable before owner destruction")

	# The endpoint owner Matter is actually destroyed. Coordinate continuity is
	# deliberately insufficient: clearing lineage retires ownership even though
	# the surrounding construct and the local address both continue to exist.
	await physics_frame
	var break_anchor_world := owner_body.to_global(owner_anchor_local)
	_check(owner_body.volume.set_cell(OWNER_CELL, CellVolume.EMPTY), "anchor-owner Matter is explicitly destroyed")
	_check(lineage.clear_lineage(OWNER_CELL), "destroyed anchor owner retires its lineage token")
	owner_body.rebuild_derived()
	_check(owner_body.get_instance_id() == owner_body_id, "anchor destruction does not require replacing the surviving construct frame")
	_check(lineage.get_lineage(OWNER_CELL) == MatterLineageMap.NONE, "destroyed anchor coordinate has no retained lineage")
	_check(owner_body.volume.get_cell(OWNER_CELL) == CellVolume.EMPTY, "destroyed owner address is physically empty")

	# A logical mechanical link whose owner no longer exists is retired rather
	# than silently reassigned to nearby Matter or to the same storage address.
	joint.free()
	_check(not is_instance_valid(joint), "mechanical link is retired in the same topology/mutation transaction as owner destruction")
	_check(_count_pin_joints(world) == 0, "no host pin constraint remains after owner destruction")

	await process_frame
	await physics_frame
	await process_frame

	var gap_at_break := owner_body.to_global(owner_anchor_local).distance_to(sibling.to_global(sibling_anchor_local))
	_check(gap_at_break < 0.01, "retiring the link itself does not teleport the previously coincident anchors")
	_check(break_anchor_world.distance_to(owner_body.to_global(owner_anchor_local)) < 0.1, "surviving owner construct does not receive a large artificial break teleport")

	# The former endpoints are now independent and must be able to diverge.
	owner_body.apply_central_impulse(assembly_transform.basis * Vector3(-18.0, 4.0, 9.0))
	sibling.apply_central_impulse(assembly_transform.basis * Vector3(15.0, -3.0, -8.0))
	owner_body.apply_torque_impulse(assembly_transform.basis * Vector3(4.0, 9.0, -3.0))
	sibling.apply_torque_impulse(assembly_transform.basis * Vector3(-5.0, -8.0, 4.0))

	var max_post_break_gap := gap_at_break
	for _frame in range(POST_BREAK_FRAMES):
		await physics_frame
		await process_frame
		max_post_break_gap = max(max_post_break_gap, owner_body.to_global(owner_anchor_local).distance_to(sibling.to_global(sibling_anchor_local)))
		_check(_finite_body_state(owner_body) and _finite_body_state(sibling), "bodies remain finite after mechanical endpoint destruction")
	_check(max_post_break_gap > 0.5, "destroying anchor ownership makes the former mechanical endpoints genuinely independent")

	# Recreate identical material at the same local address. It is new Matter,
	# so it receives fresh lineage and MUST NOT resurrect the retired link.
	await physics_frame
	_check(owner_body.volume.set_cell(OWNER_CELL, OWNER_MATERIAL), "same material is recreated at the old anchor-owner coordinate")
	_check(lineage.set_lineage(OWNER_CELL, RECREATED_TOKEN), "recreated Matter receives a fresh lineage token")
	owner_body.rebuild_derived()
	var recreated_token := lineage.get_lineage(OWNER_CELL)
	_check(recreated_token == RECREATED_TOKEN and recreated_token != owner_token, "same address/material recreation does not resurrect retired owner lineage")
	_check(owner_body.get_instance_id() == owner_body_id and sibling.get_instance_id() == sibling_id, "recreation preserves the two surviving frame identities")
	_check(_count_pin_joints(world) == 0, "recreated Matter does not implicitly recreate the retired mechanical link")

	var gap_at_recreation := owner_body.to_global(owner_anchor_local).distance_to(sibling.to_global(sibling_anchor_local))
	var min_post_recreate_gap := INF
	var max_post_recreate_gap := 0.0
	for _frame in range(POST_RECREATE_FRAMES):
		await physics_frame
		await process_frame
		var gap := owner_body.to_global(owner_anchor_local).distance_to(sibling.to_global(sibling_anchor_local))
		min_post_recreate_gap = min(min_post_recreate_gap, gap)
		max_post_recreate_gap = max(max_post_recreate_gap, gap)
		_check(_count_pin_joints(world) == 0, "no implicit host constraint appears after same-address Matter recreation")
		_check(_finite_body_state(owner_body) and _finite_body_state(sibling), "recreated-owner bodies remain numerically finite")

	_check(_count_pin_joints(world) == 0, "mechanical link remains retired after recreation campaign")
	_check(retired_joint_id != 0, "retired mechanical link had a concrete prior identity")
	_check(gap_at_recreation > 0.1, "recreated owner Matter begins while former endpoints are already physically separated")

	print(
		"MULTIFRAME_ANCHOR_DESTRUCTION_METRIC owner_token=%d recreated_token=%d owner_body_id=%d sibling_id=%d retired_joint_id=%d pre_break_gap=%.10f gap_at_break=%.10f max_post_break_gap=%.6f gap_at_recreation=%.6f min_post_recreate_gap=%.6f max_post_recreate_gap=%.6f final_pin_joints=%d final_cells=%d"
		% [
			owner_token,
			recreated_token,
			owner_body_id,
			sibling_id,
			retired_joint_id,
			max_pre_break_gap,
			gap_at_break,
			max_post_break_gap,
			gap_at_recreation,
			min_post_recreate_gap,
			max_post_recreate_gap,
			_count_pin_joints(world),
			owner_body.volume.count_solid(),
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
	body.can_sleep = false
	body.collision_layer = 0
	body.collision_mask = 0
	body.mass_per_cell = MASS_PER_CELL
	world.add_child(body)
	body.global_transform = transform
	body.set_volume(volume)
	return body


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


func _count_pin_joints(world: Node) -> int:
	var count := 0
	for child in world.get_children():
		if child is PinJoint3D:
			count += 1
	return count


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
		print("MULTIFRAME_ANCHOR_DESTRUCTION_PROBE_PASS: destroying mechanical-anchor owner Matter retired its link; same-address same-material recreation received fresh lineage and did not resurrect the old constraint.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_ANCHOR_DESTRUCTION_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
