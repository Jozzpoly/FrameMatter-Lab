extends SceneTree

const SOURCE_SIZE := Vector3i(8, 3, 1)
const ANCHOR_CELL := Vector3i(1, 1, 0)
const SEAM_LEFT := Vector3i(3, 1, 0)
const SEAM_RIGHT := Vector3i(4, 1, 0)
const NON_ENDPOINT_SOURCE_CELL := Vector3i(6, 1, 0)
const PRE_EDIT_FRAMES := 55
const POST_NON_ENDPOINT_FRAMES := 45
const POST_DEATH_FRAMES := 45
const POST_RECREATE_FRAMES := 20

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "C5ARelationHistoryWorld"
	get_root().add_child(world)

	var source_transform := Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))
	var volume := CellVolume.new(SOURCE_SIZE)
	var lineage := MatterLineageMap.new(SOURCE_SIZE)
	var issuer := MatterLineageIssuer.new(51001)
	for x in range(1, 7):
		var cell := Vector3i(x, 1, 0)
		_check(volume.set_cell(cell, CellVolume.SOLID), "fixture cell %s becomes occupied" % str(cell))
		_check(lineage.set_lineage(cell, issuer.allocate()), "fixture cell %s receives lineage" % str(cell))

	var seam := [{
		"a": lineage.get_lineage(SEAM_LEFT),
		"b": lineage.get_lineage(SEAM_RIGHT),
	}]
	var rigid := C2RigidConnectivityChallenger.extract_rigid_components(volume, lineage, seam)
	_check(bool(rigid.get("valid", false)) and _component_sizes(rigid) == [3, 3], "C5A starts from the defended C2 seam split")
	if not bool(rigid.get("valid", false)):
		_finish(world)
		return

	var anchor_token := lineage.get_lineage(ANCHOR_CELL)
	var selected: Array[Vector3i] = []
	for component_variant in rigid.get("components", []):
		var component: Array = component_variant
		if _component_contains_token(component, lineage, anchor_token):
			continue
		for cell_variant in component:
			selected.append(cell_variant)
	_check(selected.size() == 3, "C5A selects the C3 unanchored island")
	if selected.size() != 3:
		_finish(world)
		return

	var relation := {
		"world_lineage": lineage.get_lineage(SEAM_LEFT),
		"island_lineage": lineage.get_lineage(SEAM_RIGHT),
		"anchor_source_local": Vector3(4.0, 1.5, 0.5),
		"axis_source_local": Vector3.FORWARD,
	}
	var original_island_token := int(relation["island_lineage"])

	var source := W0AuthorityPartitionSpace.new()
	source.name = "C5ACanonicalWorld"
	source.lineage_issuer = issuer
	source.dynamic_gravity_scale = 1.0
	source.dynamic_linear_damp = 0.0
	source.dynamic_angular_damp = 0.0
	source.dynamic_can_sleep = false
	world.add_child(source)
	source.initialize_static(volume, lineage, source_transform)
	_check(source.request_authority_partition(selected, LocalMatterSpace.ProviderKind.DYNAMIC), "C5A composes C3 authority from the seam law")

	await physics_frame
	var result := source.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "C5A C3 transfer creates dynamic island")
	if target == null:
		_finish(world)
		return
	var body := target.get_active_provider() as ConstructBody
	_check(body != null, "C5A island owns dynamic provider")
	if body == null:
		_finish(world)
		return

	body.collision_layer = 0
	body.collision_mask = 0
	var source_origin: Vector3i = result.get("source_origin", Vector3i.ZERO)
	var endpoint_local := SEAM_RIGHT - source_origin
	var non_endpoint_local := NON_ENDPOINT_SOURCE_CELL - source_origin
	var anchor_local: Vector3 = relation["anchor_source_local"] - Vector3(source_origin)
	var anchor_world := source_transform * (relation["anchor_source_local"] as Vector3)
	var axis_world := (source_transform.basis * (relation["axis_source_local"] as Vector3)).normalized()

	_check(_relation_is_live(source, target, relation), "relation is live after C3 because both retained lineage endpoints resolve")
	_check(target.lineage.get_lineage(endpoint_local) == original_island_token, "mapped target seam cell owns the original relation lineage")
	_check(non_endpoint_local != endpoint_local, "non-endpoint edit target is distinct from relation endpoint")

	var joint := _make_passive_joint(world, body, anchor_world, axis_world)
	var joint_id := joint.get_instance_id()
	var initial_basis := body.global_basis
	var max_anchor_gap_before_edit := 0.0
	var max_rotation_before_edit := 0.0
	for _frame in range(PRE_EDIT_FRAMES):
		await physics_frame
		await process_frame
		max_anchor_gap_before_edit = maxf(
			max_anchor_gap_before_edit,
			(body.global_transform * anchor_local).distance_to(anchor_world)
		)
		max_rotation_before_edit = maxf(max_rotation_before_edit, _basis_angle(initial_basis, body.global_basis))

	_check(max_anchor_gap_before_edit < 0.06, "relation is physically anchored before history edit")
	_check(max_rotation_before_edit > 0.10, "gravity has already produced passive relation motion before edit")

	# Living edit that does not touch either relation endpoint. The host constraint
	# must not be treated as a one-shot snapshot invalidated by unrelated Matter
	# change.
	var non_endpoint_token := target.lineage.get_lineage(non_endpoint_local)
	_check(non_endpoint_token != MatterLineageMap.NONE, "non-endpoint edit cell has live lineage")
	_check(target.mutate_cell(non_endpoint_local, CellVolume.EMPTY), "moving related Matter accepts a live non-endpoint REMOVE")
	_check(target.lineage.get_lineage(non_endpoint_local) == MatterLineageMap.NONE, "non-endpoint lineage retires after its Matter is destroyed")
	_check(_relation_is_live(source, target, relation), "relation remains live because its own endpoints survived")
	_check(joint.get_instance_id() == joint_id and is_instance_valid(joint), "same disposable host remains while relation truth remains live")

	var max_anchor_gap_after_non_endpoint := 0.0
	for _frame in range(POST_NON_ENDPOINT_FRAMES):
		await physics_frame
		await process_frame
		max_anchor_gap_after_non_endpoint = maxf(
			max_anchor_gap_after_non_endpoint,
			(body.global_transform * anchor_local).distance_to(anchor_world)
		)
	_check(max_anchor_gap_after_non_endpoint < 0.08, "relation remains physically anchored after unrelated moving-Matter edit")

	# Destroy the actual island-side endpoint. Joint existence is now stale
	# implementation state; live Matter identity says the relation is dead.
	_check(target.mutate_cell(endpoint_local, CellVolume.EMPTY), "relation-owning endpoint Matter can be destroyed while world is live")
	_check(target.lineage.get_lineage(endpoint_local) == MatterLineageMap.NONE, "destroyed endpoint lineage leaves authority")
	_check(not _relation_is_live(source, target, relation), "relation truth becomes invalid immediately when endpoint lineage dies")
	_check(is_instance_valid(joint), "host joint can still physically exist even after relation truth is already invalid")

	var anchor_at_relation_death := body.global_transform * anchor_local
	joint.free()
	await process_frame
	_check(not is_instance_valid(joint), "stale host relation is retired after live truth invalidates it")

	var max_unconstrained_gap := 0.0
	var body_y_at_death := body.global_position.y
	for _frame in range(POST_DEATH_FRAMES):
		await physics_frame
		await process_frame
		max_unconstrained_gap = maxf(
			max_unconstrained_gap,
			(body.global_transform * anchor_local).distance_to(anchor_at_relation_death)
		)
	_check(max_unconstrained_gap > 0.5, "former island moves unconstrained after relation host retires")
	_check(body.global_position.y < body_y_at_death - 0.2, "gravity continues world history after relation death")

	# Same-address recreation must be fresh Matter. It may not resurrect a
	# historical relation whose endpoint identity was destroyed.
	_check(target.mutate_cell(endpoint_local, CellVolume.SOLID), "same local address can receive fresh Matter after endpoint death")
	var fresh_token := target.lineage.get_lineage(endpoint_local)
	_check(fresh_token != MatterLineageMap.NONE, "recreated Matter receives lineage")
	_check(fresh_token != original_island_token, "same-address recreation receives fresh lineage instead of resurrecting endpoint identity")
	_check(not _relation_is_live(source, target, relation), "old relation stays dead after same-address fresh Matter recreation")

	var y_before_recreate_history := body.global_position.y
	for _frame in range(POST_RECREATE_FRAMES):
		await physics_frame
		await process_frame
	_check(body.global_position.y < y_before_recreate_history - 0.05, "recreated Matter does not silently reinstall old physical relation")

	print(
		"C5A_RELATION_HISTORY_METRIC pre_gap=%.6f pre_rotation=%.6f post_edit_gap=%.6f free_gap=%.6f old_endpoint=%d fresh_endpoint=%d non_endpoint=%d"
		% [
			max_anchor_gap_before_edit,
			max_rotation_before_edit,
			max_anchor_gap_after_non_endpoint,
			max_unconstrained_gap,
			original_island_token,
			fresh_token,
			non_endpoint_token,
		]
	)

	_finish(world)


func _relation_is_live(
	source: LocalMatterSpace,
	target: LocalMatterSpace,
	relation: Dictionary
) -> bool:
	return (
		_lineage_contains(source.lineage, int(relation["world_lineage"]))
		and _lineage_contains(target.lineage, int(relation["island_lineage"]))
	)


func _make_passive_joint(
	world: Node3D,
	body: ConstructBody,
	anchor_world: Vector3,
	axis_world: Vector3
) -> HingeJoint3D:
	var joint := HingeJoint3D.new()
	joint.name = "C5ADisposablePassiveHinge"
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
		print("C5A_RELATION_HISTORY_PASS: passive relation validity follows live Matter lineage through moving edits; unrelated Matter destruction preserves it, endpoint destruction kills it, and same-address fresh Matter does not resurrect the historical relation.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("C5A_RELATION_HISTORY_FAIL: " + failure)
	world.free()
	quit(1)
