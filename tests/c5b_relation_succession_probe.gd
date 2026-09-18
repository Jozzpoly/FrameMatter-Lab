extends SceneTree

const SOURCE_SIZE := Vector3i(8, 3, 1)
const CANONICAL_ANCHOR_CELL := Vector3i(6, 1, 0)
const SEAM_ISLAND := Vector3i(3, 1, 0)
const SEAM_WORLD := Vector3i(4, 1, 0)
const PRE_SPLIT_FRAMES := 55
const POST_SPLIT_FRAMES := 80

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "C5BRelationSuccessionWorld"
	get_root().add_child(world)

	var source_transform := Transform3D(Basis.IDENTITY, Vector3(0.0, 9.0, 0.0))
	var volume := CellVolume.new(SOURCE_SIZE)
	var lineage := MatterLineageMap.new(SOURCE_SIZE)
	var issuer := MatterLineageIssuer.new(52001)
	for x in range(1, 7):
		var cell := Vector3i(x, 1, 0)
		_check(volume.set_cell(cell, CellVolume.SOLID), "fixture cell %s becomes occupied" % str(cell))
		_check(lineage.set_lineage(cell, issuer.allocate()), "fixture cell %s receives lineage" % str(cell))

	var relation := {
		"world_lineage": lineage.get_lineage(SEAM_WORLD),
		"island_lineage": lineage.get_lineage(SEAM_ISLAND),
		"anchor_source_local": Vector3(4.0, 1.5, 0.5),
		"axis_source_local": Vector3.FORWARD,
	}
	var relation_before := relation.duplicate(true)
	var seam := [{
		"a": relation["world_lineage"],
		"b": relation["island_lineage"],
	}]
	var rigid := C2RigidConnectivityChallenger.extract_rigid_components(volume, lineage, seam)
	_check(bool(rigid.get("valid", false)) and _component_sizes(rigid) == [3, 3], "C5B begins from defended C2 rigid decomposition")
	if not bool(rigid.get("valid", false)):
		_finish(world)
		return

	var canonical_anchor_token := lineage.get_lineage(CANONICAL_ANCHOR_CELL)
	var selected: Array[Vector3i] = []
	for component_variant in rigid.get("components", []):
		var component: Array = component_variant
		if _component_contains_token(component, lineage, canonical_anchor_token):
			continue
		for cell_variant in component:
			selected.append(cell_variant)
	_check(selected.size() == 3 and selected.has(SEAM_ISLAND), "left unanchored C3 island contains the relation endpoint")
	if selected.size() != 3:
		_finish(world)
		return

	var source := W0AuthorityPartitionSpace.new()
	source.name = "C5BCanonicalWorld"
	source.lineage_issuer = issuer
	source.dynamic_gravity_scale = 1.0
	source.dynamic_linear_damp = 0.0
	source.dynamic_angular_damp = 0.0
	source.dynamic_can_sleep = false
	world.add_child(source)
	source.initialize_static(volume, lineage, source_transform)
	_check(source.request_authority_partition(selected, LocalMatterSpace.ProviderKind.DYNAMIC), "C5B composes C3 authority from the seam law")

	await physics_frame
	var c3_result := source.get_last_authority_partition_result()
	var target := c3_result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "C5B obtains dynamic island")
	if target == null:
		_finish(world)
		return
	var body := target.get_active_provider() as ConstructBody
	_check(body != null, "C5B island owns dynamic provider")
	if body == null:
		_finish(world)
		return

	body.collision_layer = 0
	body.collision_mask = 0
	var c3_origin: Vector3i = c3_result.get("source_origin", Vector3i.ZERO)
	var endpoint_source_local := SEAM_ISLAND - c3_origin
	var old_anchor_local: Vector3 = relation["anchor_source_local"] - Vector3(c3_origin)
	var anchor_world := source_transform * (relation["anchor_source_local"] as Vector3)
	var axis_world := (source_transform.basis * (relation["axis_source_local"] as Vector3)).normalized()

	_check(endpoint_source_local == Vector3i(2, 0, 0), "C5B fixture places relation endpoint away from target compact origin")
	_check(_lineage_contains(target.lineage, int(relation["island_lineage"])), "relation endpoint lineage is live in pre-split island")
	_check((body.global_transform * old_anchor_local).distance_to(anchor_world) < 0.00001, "C3 maps relation frame into island continuously")

	var joint := _make_passive_joint(world, body, anchor_world, axis_world)
	var joint_id := joint.get_instance_id()
	var old_body_id := body.get_instance_id()
	var max_pre_gap := 0.0
	for _frame in range(PRE_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_pre_gap = maxf(max_pre_gap, (body.global_transform * old_anchor_local).distance_to(anchor_world))
	_check(max_pre_gap < 0.06, "relation is stable before topology succession")

	# Remove the middle cell of the three-cell moving arm. The relation endpoint at
	# old local x=2 survives, while ordinary material topology becomes two
	# components. Relation truth remains live before the Space/body succession.
	var split_cut := Vector3i(1, 0, 0)
	var split_cut_token := target.lineage.get_lineage(split_cut)
	_check(split_cut_token != MatterLineageMap.NONE, "split cut has real lineage before destruction")
	_check(target.mutate_cell(split_cut, CellVolume.EMPTY), "live related moving Matter accepts topology-changing edit")
	_check(target.lineage.get_lineage(split_cut) == MatterLineageMap.NONE, "split cut lineage retires")
	_check(MatterTopology.extract_connected_cell_components(target.volume).size() == 2, "moving island now contains two material components")
	_check(_lineage_contains(target.lineage, int(relation["island_lineage"])), "relation endpoint survives the split-causing edit")
	_check(joint.get_instance_id() == joint_id and is_instance_valid(joint), "same host still exists before topology commit")

	_check(target.request_connected_component_split(), "production topology succession accepts the disconnected moving island")
	await physics_frame

	var split_result := target.get_last_split_result()
	_check(split_result != null and split_result.size() == 2, "production split publishes two dynamic successors")
	if split_result == null or split_result.size() != 2:
		_finish(world)
		return
	_check(target.is_retired(), "old dynamic Space retires after topology succession")

	# Succession must preserve the actual relation frame carried by the source at
	# the transaction boundary. The passive solver host is compliant: before the
	# split its seam can differ from the ideal authored anchor by a few millimeters.
	# A successor must inherit that exact live source frame, not magically snap the
	# accumulated solver compliance back to the authored frame.
	var seam_world_at_split := split_result.source_transform * old_anchor_local
	var pre_split_solver_gap := seam_world_at_split.distance_to(anchor_world)

	var relation_successor_index := _find_successor_index_for_lineage(
		split_result,
		int(relation["island_lineage"])
	)
	_check(relation_successor_index >= 0, "retained relation endpoint lineage resolves to exactly one successor")
	if relation_successor_index < 0:
		_finish(world)
		return

	var successor := split_result.successors[relation_successor_index] as LocalMatterSpace
	var successor_origin: Vector3i = split_result.source_origins[relation_successor_index]
	_check(successor_origin.x > 0, "endpoint successor uses non-zero source origin so relation-frame remapping is nontrivial")
	var mapped_endpoint := endpoint_source_local - successor_origin
	var mapped_anchor_local := old_anchor_local - Vector3(successor_origin)
	var successor_body := successor.get_active_provider() as ConstructBody
	_check(successor_body != null, "relation successor owns fresh dynamic provider")
	if successor_body == null:
		_finish(world)
		return
	successor_body.collision_layer = 0
	successor_body.collision_mask = 0

	_check(successor_body.get_instance_id() != old_body_id, "relation endpoint now lives on new physics-body identity")
	_check(successor.lineage.get_lineage(mapped_endpoint) == int(relation["island_lineage"]), "exact relation endpoint lineage survives compact succession mapping")
	var mapped_seam_world := successor_body.global_transform * mapped_anchor_local
	var succession_frame_error := mapped_seam_world.distance_to(seam_world_at_split)
	_check(succession_frame_error < 0.00002, "mapped successor relation frame preserves the actual source seam continuously across succession")
	_check(pre_split_solver_gap < 0.08, "source relation remains within bounded passive-joint compliance at the succession boundary")
	_check(relation == relation_before, "logical relation record itself is unchanged by Space/body succession")

	var endpoint_owner_count := 0
	for successor_variant in split_result.successors:
		var candidate := successor_variant as LocalMatterSpace
		if _lineage_contains(candidate.lineage, int(relation["island_lineage"])):
			endpoint_owner_count += 1
	_check(endpoint_owner_count == 1, "relation endpoint lineage has exactly one successor owner")

	# Rebind the same disposable host to the current body before the upcoming
	# solver step. Logical relation identity is unchanged; only its execution
	# endpoint follows retained Matter.
	joint.global_transform = Transform3D(_basis_with_z_axis(axis_world), anchor_world)
	joint.force_update_transform()
	joint.node_b = joint.get_path_to(successor_body)
	_check(joint.get_instance_id() == joint_id, "host joint identity may persist while its body endpoint is replaced")

	await process_frame
	await physics_frame
	await process_frame

	var successor_basis_start := successor_body.global_basis
	var max_post_gap := 0.0
	var max_post_rotation := 0.0
	for _frame in range(POST_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_post_gap = maxf(
			max_post_gap,
			(successor_body.global_transform * mapped_anchor_local).distance_to(anchor_world)
		)
		max_post_rotation = maxf(
			max_post_rotation,
			_basis_angle(successor_basis_start, successor_body.global_basis)
		)

	_check(max_post_gap < 0.08, "relation remains physically anchored after topology succession and frame remap")
	_check(max_post_rotation > 0.10, "successor continues passive gravity-driven relation motion")
	_check(_lineage_contains(source.lineage, int(relation["world_lineage"])), "WORLD endpoint lineage remains live after island succession")
	_check(_lineage_contains(successor.lineage, int(relation["island_lineage"])), "island endpoint lineage remains live after island succession")

	print(
		"C5B_RELATION_SUCCESSION_METRIC pre_gap=%.6f split_gap=%.6f succession_error=%.10f post_gap=%.6f post_rotation=%.6f old_body=%d new_body=%d successor_origin=%s endpoint=%d cut_token=%d"
		% [
			max_pre_gap,
			pre_split_solver_gap,
			succession_frame_error,
			max_post_gap,
			max_post_rotation,
			old_body_id,
			successor_body.get_instance_id(),
			str(successor_origin),
			int(relation["island_lineage"]),
			split_cut_token,
		]
	)

	_finish(world)


func _find_successor_index_for_lineage(
	result: LocalMatterSplitResult,
	token: int
) -> int:
	var found := -1
	for index in range(result.successors.size()):
		var successor := result.successors[index] as LocalMatterSpace
		if not _lineage_contains(successor.lineage, token):
			continue
		if found >= 0:
			return -2
		found = index
	return found


func _make_passive_joint(
	world: Node3D,
	body: ConstructBody,
	anchor_world: Vector3,
	axis_world: Vector3
) -> HingeJoint3D:
	var joint := HingeJoint3D.new()
	joint.name = "C5BDisposablePassiveHinge"
	world.add_child(joint)
	joint.global_transform = Transform3D(_basis_with_z_axis(axis_world), anchor_world)
	joint.node_b = joint.get_path_to(body)
	joint.exclude_nodes_from_collision = true
	return joint


func _component_contains_token(
	component: Array,
	lineage: MatterLineageMap,
	token: int
) -> bool:
	for cell_variant in component:
		if lineage.get_lineage(cell_variant) == token:
			return true
	return false


func _component_sizes(result: Dictionary) -> Array[int]:
	var sizes: Array[int] = []
	for component_variant in result.get("components", []):
		var component: Array = component_variant
		sizes.append(component.size())
	sizes.sort()
	return sizes


func _lineage_contains(lineage: MatterLineageMap, token: int) -> bool:
	if lineage == null or token == MatterLineageMap.NONE:
		return false
	for existing in lineage.duplicate_tokens():
		if int(existing) == token:
			return true
	return false


func _basis_with_z_axis(axis: Vector3) -> Basis:
	var z := axis.normalized()
	var helper := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := helper.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z).orthonormalized()


func _basis_angle(reference: Basis, current: Basis) -> float:
	var delta := reference.inverse() * current
	return absf(delta.get_rotation_quaternion().get_angle())


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("C5B_RELATION_SUCCESSION_PASS: a live relation endpoint follows retained Matter lineage through production topology succession, non-zero compact-frame remap and fresh body identity while the same logical relation remains world-continuous and passively solver-driven.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("C5B_RELATION_SUCCESSION_FAIL: " + failure)
	world.free()
	quit(1)
