extends SceneTree

const VOLUME_SIZE := Vector3i(10, 3, 3)
const CUT_OWNER_CELL := Vector3i(4, 1, 1)
const SURVIVING_OWNER_CELL := Vector3i(9, 1, 1)
const MASS_PER_CELL := 1.65
const PRE_SPLIT_FRAMES := 60
const POST_SPLIT_FRAMES := 180

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "MixedMechanicalAnchorSplitWorld"
	get_root().add_child(world)

	var parent_volume := _make_parent_volume()
	var lineage := MatterLineageMap.new(VOLUME_SIZE)
	var next_token := 93001
	for cell in _occupied_cells(parent_volume):
		lineage.set_lineage(cell, next_token)
		next_token += 1
	var retired_owner_token := lineage.get_lineage(CUT_OWNER_CELL)
	var surviving_owner_token := lineage.get_lineage(SURVIVING_OWNER_CELL)
	_check(retired_owner_token != 0 and surviving_owner_token != 0 and retired_owner_token != surviving_owner_token, "mixed transaction starts with two distinct anchor-owner lineages")

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.16, -0.44, 0.23)),
		Vector3(15.0, 8.0, -10.0)
	)
	var parent := _make_body(world, "MixedParent", parent_volume, assembly_transform)
	var retiring_sibling := _make_box_body(
		world,
		"RetiringEndpointSibling",
		Vector3i(2, 2, 2),
		4,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(4.5, 0.5, 0.5))
	)
	var surviving_sibling := _make_box_body(
		world,
		"SurvivingEndpointSibling",
		Vector3i(3, 3, 3),
		5,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	)
	var parent_id := parent.get_instance_id()
	var retiring_sibling_id := retiring_sibling.get_instance_id()
	var surviving_sibling_id := surviving_sibling.get_instance_id()

	# Link A is literally owned by the bridge cell that will be destroyed.
	# Link B is owned by retained Matter on the far right component.
	var retired_parent_anchor_local := Vector3(CUT_OWNER_CELL) + Vector3(0.5, 0.5, 0.5)
	var surviving_parent_anchor_local := Vector3(10.0, 1.5, 1.5)
	var retired_anchor_world := parent.to_global(retired_parent_anchor_local)
	var surviving_anchor_world := parent.to_global(surviving_parent_anchor_local)
	var retiring_sibling_anchor_local := retiring_sibling.to_local(retired_anchor_world)
	var surviving_sibling_anchor_local := surviving_sibling.to_local(surviving_anchor_world)

	var common_linear := Vector3(1.5, -0.18, 0.85)
	var common_angular := Vector3(0.19, -0.32, 0.27)
	var parent_com_world := parent.to_global(parent.matter_center_of_mass_local)
	parent.linear_velocity = common_linear
	parent.angular_velocity = common_angular
	retiring_sibling.linear_velocity = _velocity_at_point(common_linear, common_angular, parent_com_world, retiring_sibling.to_global(retiring_sibling.matter_center_of_mass_local))
	surviving_sibling.linear_velocity = _velocity_at_point(common_linear, common_angular, parent_com_world, surviving_sibling.to_global(surviving_sibling.matter_center_of_mass_local))
	retiring_sibling.angular_velocity = common_angular
	surviving_sibling.angular_velocity = common_angular

	var retiring_joint := _make_pin_joint(world, "RetiringMechanicalLink", retired_anchor_world, parent, retiring_sibling)
	var surviving_joint := _make_pin_joint(world, "SurvivingMechanicalLink", surviving_anchor_world, parent, surviving_sibling)
	var retired_joint_id := retiring_joint.get_instance_id()
	var surviving_joint_id := surviving_joint.get_instance_id()

	var max_pre_retired_gap := 0.0
	var max_pre_surviving_gap := 0.0
	for _frame in range(PRE_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_pre_retired_gap = max(max_pre_retired_gap, parent.to_global(retired_parent_anchor_local).distance_to(retiring_sibling.to_global(retiring_sibling_anchor_local)))
		max_pre_surviving_gap = max(max_pre_surviving_gap, parent.to_global(surviving_parent_anchor_local).distance_to(surviving_sibling.to_global(surviving_sibling_anchor_local)))
	_check(max_pre_retired_gap < 0.01 and max_pre_surviving_gap < 0.01, "both links are stable before mixed topology transaction")

	await physics_frame
	var parent_transform := parent.global_transform
	var parent_linear := parent.linear_velocity
	var parent_angular := parent.angular_velocity
	parent_com_world = parent.to_global(parent.matter_center_of_mass_local)
	var retired_anchor_before := parent.to_global(retired_parent_anchor_local)
	var surviving_anchor_before := parent.to_global(surviving_parent_anchor_local)
	var surviving_joint_staleness := surviving_joint.global_position.distance_to(surviving_anchor_before)

	# One Matter edit has two mechanical consequences: the cut-owner lineage is
	# destroyed, while the far-right owner lineage survives into one successor.
	_check(parent.volume.set_cell(CUT_OWNER_CELL, CellVolume.EMPTY), "mixed transaction destroys the bridge/anchor-owner Matter cell")
	_check(lineage.clear_lineage(CUT_OWNER_CELL), "destroyed bridge owner lineage is explicitly retired")
	_check(lineage.get_lineage(CUT_OWNER_CELL) == MatterLineageMap.NONE, "retired mechanical owner has no surviving lineage")
	var components := MatterTopology.extract_connected_components(parent.volume)
	_check(components.size() == 2, "destroying the owner bridge also splits parent Matter into two successors")
	if components.size() != 2:
		_finish()
		return

	var children: Array[ConstructBody] = []
	var origins: Array[Vector3i] = []
	var child_lineages: Array[MatterLineageMap] = []
	var surviving_child_index := -1
	var retired_token_found := false
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
			"MixedSuccessor_%d" % index,
			compact,
			parent_transform * Transform3D(Basis.IDENTITY, Vector3(origin))
		)
		var child_com_world := child.to_global(child.matter_center_of_mass_local)
		child.linear_velocity = _velocity_at_point(parent_linear, parent_angular, parent_com_world, child_com_world)
		child.angular_velocity = parent_angular
		children.append(child)
		origins.append(origin)

		var child_lineage := MatterLineageMap.new(compact.size)
		for source_cell in _occupied_cells(source_component):
			var compact_cell := source_cell - origin
			var token := lineage.get_lineage(source_cell)
			child_lineage.set_lineage(compact_cell, token)
			if child_lineage.get_lineage(compact_cell) != token:
				lineage_mismatches += 1
			if token == retired_owner_token:
				retired_token_found = true

			var old_world := parent_transform * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
			var new_world := child.to_global(Vector3(compact_cell) + Vector3(0.5, 0.5, 0.5))
			max_world_error = max(max_world_error, old_world.distance_to(new_world))
			var old_velocity := _velocity_at_point(parent_linear, parent_angular, parent_com_world, old_world)
			var new_velocity := _velocity_at_point(child.linear_velocity, child.angular_velocity, child_com_world, new_world)
			max_velocity_error = max(max_velocity_error, old_velocity.distance_to(new_velocity))
		child_lineages.append(child_lineage)

		if source_component.get_cell(SURVIVING_OWNER_CELL) != CellVolume.EMPTY:
			surviving_child_index = index

	_check(not retired_token_found, "destroyed anchor-owner lineage appears in no successor")
	_check(surviving_child_index >= 0, "retained anchor-owner Matter selects one successor")
	_check(lineage_mismatches == 0, "all retained lineage maps exactly through mixed split")
	_check(max_world_error < 0.00001, "mixed split preserves retained Matter world positions")
	_check(max_velocity_error < 0.00001, "mixed split preserves retained Matter instantaneous velocity field")
	if surviving_child_index < 0:
		_finish()
		return

	var surviving_child := children[surviving_child_index]
	var free_child := children[1 - surviving_child_index]
	var surviving_origin := origins[surviving_child_index]
	var mapped_surviving_anchor_local := surviving_parent_anchor_local - Vector3(surviving_origin)
	var mapped_surviving_owner_cell := SURVIVING_OWNER_CELL - surviving_origin
	var inherited_surviving_token := child_lineages[surviving_child_index].get_lineage(mapped_surviving_owner_cell)
	_check(inherited_surviving_token == surviving_owner_token, "surviving link follows its retained owner lineage")
	_check(surviving_child.to_global(mapped_surviving_anchor_local).distance_to(surviving_anchor_before) < 0.00001, "surviving mechanical anchor maps continuously into compact successor")
	_check(surviving_joint_staleness > 0.1, "surviving persistent Joint3D scene frame is materially stale before endpoint succession")

	# Per-anchor decision inside one transaction:
	# - destroyed owner => retire its logical/host link,
	# - retained owner => rebase constraint frame and move endpoint to successor.
	retiring_joint.free()
	_check(not is_instance_valid(retiring_joint), "destroyed owner retires only its own mechanical link")
	surviving_joint.global_position = surviving_anchor_before
	surviving_joint.force_update_transform()
	var surviving_rebase_error := surviving_joint.global_position.distance_to(surviving_anchor_before)
	surviving_joint.node_a = surviving_joint.get_path_to(surviving_child)
	_check(surviving_rebase_error < 0.000001, "surviving constraint frame rebases before endpoint succession")
	_check(surviving_joint.get_instance_id() == surviving_joint_id, "surviving logical link identity is preserved")
	_check(retired_joint_id != surviving_joint_id, "retired and surviving mechanical links had distinct logical identities")
	_check(retiring_sibling.get_instance_id() == retiring_sibling_id and surviving_sibling.get_instance_id() == surviving_sibling_id, "unaffected external frames preserve identity")
	_check(surviving_child.get_instance_id() != parent_id and free_child.get_instance_id() != parent_id, "topology split replaces the parent physics identity")
	parent.free()

	await process_frame
	await physics_frame
	await process_frame

	_check(_count_pin_joints(world) == 1, "mixed transaction leaves exactly the retained mechanical link alive")
	var gap_retired_at_transaction := retiring_sibling.to_global(retiring_sibling_anchor_local).distance_to(retired_anchor_before)
	var surviving_linear_before := surviving_child.linear_velocity
	var surviving_angular_before := surviving_child.angular_velocity
	var free_child_start := free_child.global_position

	# Drive all post-transaction branches differently. The retired external body
	# must be independent; the surviving sibling must still transmit reaction;
	# the non-owning topology successor must remain free.
	retiring_sibling.apply_central_impulse(assembly_transform.basis * Vector3(-18.0, 5.0, 11.0))
	surviving_sibling.apply_central_impulse(assembly_transform.basis * Vector3(13.0, -3.0, -7.0))
	surviving_sibling.apply_torque_impulse(assembly_transform.basis * Vector3(5.0, 12.0, -4.0))
	free_child.apply_central_impulse(assembly_transform.basis * Vector3(-9.0, 2.0, 14.0))

	var max_surviving_gap := 0.0
	var max_retired_endpoint_distance := gap_retired_at_transaction
	var max_free_child_separation := 0.0
	for _frame in range(POST_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_surviving_gap = max(max_surviving_gap, surviving_child.to_global(mapped_surviving_anchor_local).distance_to(surviving_sibling.to_global(surviving_sibling_anchor_local)))
		max_retired_endpoint_distance = max(max_retired_endpoint_distance, retiring_sibling.to_global(retiring_sibling_anchor_local).distance_to(retired_anchor_before))
		max_free_child_separation = max(max_free_child_separation, free_child.global_position.distance_to(free_child_start))
		_check(_count_pin_joints(world) == 1, "retired link never resurrects during mixed post-split motion")
		_check(_finite_body_state(surviving_child) and _finite_body_state(free_child) and _finite_body_state(retiring_sibling) and _finite_body_state(surviving_sibling), "mixed successor graph remains numerically finite")

	var final_surviving_gap := surviving_child.to_global(mapped_surviving_anchor_local).distance_to(surviving_sibling.to_global(surviving_sibling_anchor_local))
	var surviving_linear_change := surviving_child.linear_velocity.distance_to(surviving_linear_before)
	var surviving_angular_change := surviving_child.angular_velocity.distance_to(surviving_angular_before)

	_check(max_surviving_gap < 0.02 and final_surviving_gap < 0.005, "retained mechanical endpoint remains bounded after mixed transaction")
	_check(max_retired_endpoint_distance > 0.5, "destroyed-owner endpoint becomes physically independent in the same mixed transaction")
	_check(max_free_child_separation > 0.1, "non-owning topology successor remains mechanically independent")
	_check(surviving_linear_change > 0.01 or surviving_angular_change > 0.01, "surviving successor still receives reaction through inherited link")
	_check(surviving_joint.node_a == surviving_joint.get_path_to(surviving_child), "surviving link remains attached to lineage-owning successor")
	_check(surviving_joint.node_b == surviving_joint.get_path_to(surviving_sibling), "surviving external endpoint remains unchanged")

	print(
		"MULTIFRAME_MIXED_ANCHOR_SPLIT_METRIC retired_token=%d surviving_token=%d inherited_surviving=%d retired_token_found=%s components=%d surviving_index=%d lineage_mismatches=%d world_error=%.10f velocity_error=%.10f surviving_staleness=%.10f surviving_rebase_error=%.10f max_surviving_gap=%.10f final_surviving_gap=%.10f retired_endpoint_distance=%.6f free_child_separation=%.6f surviving_linear_change=%.6f surviving_angular_change=%.6f final_pin_joints=%d retired_joint_id=%d surviving_joint_id=%d"
		% [
			retired_owner_token, surviving_owner_token, inherited_surviving_token, retired_token_found,
			components.size(), surviving_child_index, lineage_mismatches, max_world_error, max_velocity_error,
			surviving_joint_staleness, surviving_rebase_error,
			max_surviving_gap, final_surviving_gap,
			max_retired_endpoint_distance, max_free_child_separation,
			surviving_linear_change, surviving_angular_change,
			_count_pin_joints(world), retired_joint_id, surviving_joint_id,
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
		print("MULTIFRAME_MIXED_ANCHOR_SPLIT_PROBE_PASS: one topology transaction retired a destroyed-owner mechanical link while independently succeeding a retained-owner link onto its lineage-selected successor.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_MIXED_ANCHOR_SPLIT_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
