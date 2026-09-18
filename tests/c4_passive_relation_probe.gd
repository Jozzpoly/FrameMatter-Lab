extends SceneTree

const SOURCE_SIZE := Vector3i(8, 3, 1)
const ANCHOR_CELL := Vector3i(1, 1, 0)
const SEAM_LEFT := Vector3i(3, 1, 0)
const SEAM_RIGHT := Vector3i(4, 1, 0)
const DRIVE_FRAMES := 150

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "C4PassiveRelationWorld"
	get_root().add_child(world)

	var control := _prepare_fixture(
		world,
		"C4Control",
		Transform3D(Basis.IDENTITY, Vector3(-12.0, 7.0, 0.0)),
		41001
	)
	var related := _prepare_fixture(
		world,
		"C4Related",
		Transform3D(Basis.IDENTITY, Vector3(12.0, 7.0, 0.0)),
		42001
	)

	_check(bool(control.get("valid", false)), "control fixture reaches pending C3 authority composition")
	_check(bool(related.get("valid", false)), "relation fixture reaches pending C3 authority composition")
	if not bool(control.get("valid", false)) or not bool(related.get("valid", false)):
		_finish(world)
		return

	await physics_frame

	var control_source := control["source"] as W0AuthorityPartitionSpace
	var related_source := related["source"] as W0AuthorityPartitionSpace
	var control_target := control_source.get_last_authority_partition_result().get("target_space") as LocalMatterSpace
	var related_result := related_source.get_last_authority_partition_result()
	var related_target := related_result.get("target_space") as LocalMatterSpace

	_check(control_target != null and is_instance_valid(control_target), "control C3 transfer publishes a dynamic island")
	_check(related_target != null and is_instance_valid(related_target), "related C3 transfer publishes a dynamic island")
	if control_target == null or related_target == null:
		_finish(world)
		return

	var control_body := control_target.get_active_provider() as ConstructBody
	var related_body := related_target.get_active_provider() as ConstructBody
	_check(control_body != null and related_body != null, "both C3 targets own dynamic ConstructBody providers")
	if control_body == null or related_body == null:
		_finish(world)
		return

	# Eliminate contact/collision as an alternate explanation. C4 is only about
	# passive relation kinematics. Later gates reintroduce living-world contact.
	control_body.collision_layer = 0
	control_body.collision_mask = 0
	related_body.collision_layer = 0
	related_body.collision_mask = 0

	var relation: Dictionary = related["relation"]
	_check(
		not relation.has("body_id")
		and not relation.has("provider_id")
		and not relation.has("space_id"),
		"relation truth contains no engine body/provider/Space identity"
	)

	var world_token := int(relation["world_lineage"])
	var island_token := int(relation["island_lineage"])
	_check(_lineage_contains(related_source.lineage, world_token), "WORLD-side relation lineage remains owned by canonical authority")
	_check(_lineage_contains(related_target.lineage, island_token), "island-side relation lineage follows retained Matter into dynamic authority")
	_check(not _lineage_contains(related_source.lineage, island_token), "island endpoint lineage no longer belongs to WORLD")
	_check(not _lineage_contains(related_target.lineage, world_token), "WORLD endpoint lineage does not migrate to island")

	var related_source_transform: Transform3D = related["source_transform"]
	var anchor_source_local: Vector3 = relation["anchor_source_local"]
	var axis_source_local: Vector3 = relation["axis_source_local"]
	var anchor_world := related_source_transform * anchor_source_local
	var axis_world := (related_source_transform.basis * axis_source_local).normalized()
	_check(axis_world.distance_to(Vector3.FORWARD) < 0.000001, "fixture resolves intended world hinge axis")

	var target_source_origin: Vector3i = related_result.get("source_origin", Vector3i.ZERO)
	var related_anchor_local := anchor_source_local - Vector3(target_source_origin)
	var related_anchor_world_before := related_body.global_transform * related_anchor_local
	_check(related_anchor_world_before.distance_to(anchor_world) < 0.00001, "lineage seam frame maps continuously through C3 compact transfer")

	var control_result := control_source.get_last_authority_partition_result()
	var control_origin: Vector3i = control_result.get("source_origin", Vector3i.ZERO)
	var control_anchor_local: Vector3 = control["anchor_source_local"] - Vector3(control_origin)
	var control_anchor_world_initial := control_body.global_transform * control_anchor_local

	var related_initial_basis := related_body.global_basis
	var control_initial_basis := control_body.global_basis
	var related_tokens_before := related_target.lineage.duplicate_tokens()
	var related_cells_before := related_target.volume.duplicate_cells()
	var related_pre_linear := related_body.linear_velocity
	var related_pre_angular := related_body.angular_velocity
	_check(related_pre_linear.length() < 0.000001 and related_pre_angular.length() < 0.000001, "C4 relation installs before any hidden island motion")

	# Godot Joint3D defines an omitted endpoint as a fixed StaticBody3D. For this
	# first bounded specimen canonical WORLD is the fixed endpoint; relation truth
	# remains the lineage+frame record above, while HingeJoint3D is disposable host
	# machinery.
	var joint := HingeJoint3D.new()
	joint.name = "C4DisposablePassiveHinge"
	world.add_child(joint)
	joint.global_transform = Transform3D(_basis_with_z_axis(axis_world), anchor_world)
	joint.node_b = joint.get_path_to(related_body)
	joint.exclude_nodes_from_collision = true
	_check(joint.node_a == NodePath(""), "WORLD side uses bounded fixed-host endpoint rather than body identity")
	_check(not joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR), "C4 passive hinge has no motor")
	_check(not joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT), "C4 passive hinge has no angular limits")

	var max_related_anchor_gap := 0.0
	var max_related_rotation := 0.0
	var max_control_anchor_gap := 0.0
	var max_control_rotation := 0.0
	var related_com_min_y := related_body.global_position.y
	var control_com_min_y := control_body.global_position.y

	for _frame in range(DRIVE_FRAMES):
		await physics_frame
		await process_frame

		var related_anchor_world := related_body.global_transform * related_anchor_local
		var control_anchor_world := control_body.global_transform * control_anchor_local
		max_related_anchor_gap = maxf(max_related_anchor_gap, related_anchor_world.distance_to(anchor_world))
		max_control_anchor_gap = maxf(max_control_anchor_gap, control_anchor_world.distance_to(control_anchor_world_initial))
		max_related_rotation = maxf(max_related_rotation, _basis_angle(related_initial_basis, related_body.global_basis))
		max_control_rotation = maxf(max_control_rotation, _basis_angle(control_initial_basis, control_body.global_basis))
		related_com_min_y = minf(related_com_min_y, related_body.global_position.y)
		control_com_min_y = minf(control_com_min_y, control_body.global_position.y)
		_check(_finite_body_state(related_body) and _finite_body_state(control_body), "C4 physics remains finite")

	_check(max_control_anchor_gap > 1.0, "unrelated C3 control falls freely away from its former seam")
	_check(max_control_rotation < 0.02, "gravity alone does not invent control-body rotation without a relation")
	_check(max_related_anchor_gap < 0.06, "passive relation keeps retained island seam anchored to canonical WORLD")
	_check(max_related_rotation > 0.35, "ordinary gravity produces substantial passive relative rotation around the seam")
	_check(related_com_min_y < anchor_world.y - 0.15, "related island COM moves under gravity while its seam stays anchored")
	_check(control_com_min_y < control_anchor_world_initial.y - 1.0, "control island exhibits unconstrained gravity translation")
	_check(related_target.volume.duplicate_cells() == related_cells_before, "passive relation motion does not mutate island Matter")
	_check(related_target.lineage.duplicate_tokens() == related_tokens_before, "passive relation motion does not mutate island lineage")
	_check(_lineage_contains(related_source.lineage, world_token), "WORLD relation endpoint remains live after passive motion")
	_check(_lineage_contains(related_target.lineage, island_token), "island relation endpoint remains live after passive motion")

	print(
		"C4_PASSIVE_RELATION_METRIC control_anchor_gap=%.6f control_rotation=%.6f related_anchor_gap=%.6f related_rotation=%.6f related_min_y=%.6f control_min_y=%.6f world_token=%d island_token=%d"
		% [
			max_control_anchor_gap,
			max_control_rotation,
			max_related_anchor_gap,
			max_related_rotation,
			related_com_min_y,
			control_com_min_y,
			world_token,
			island_token,
		]
	)

	_finish(world)


func _prepare_fixture(
	world: Node3D,
	fixture_name: String,
	source_transform: Transform3D,
	first_token: int
) -> Dictionary:
	var volume := CellVolume.new(SOURCE_SIZE)
	var lineage := MatterLineageMap.new(SOURCE_SIZE)
	var issuer := MatterLineageIssuer.new(first_token)
	for x in range(1, 7):
		var cell := Vector3i(x, 1, 0)
		if not volume.set_cell(cell, CellVolume.SOLID):
			return {"valid": false}
		if not lineage.set_lineage(cell, issuer.allocate()):
			return {"valid": false}

	var seam := [{
		"a": lineage.get_lineage(SEAM_LEFT),
		"b": lineage.get_lineage(SEAM_RIGHT),
	}]
	var rigid := C2RigidConnectivityChallenger.extract_rigid_components(volume, lineage, seam)
	if not bool(rigid.get("valid", false)) or _component_sizes(rigid) != [3, 3]:
		return {"valid": false}

	var anchor_token := lineage.get_lineage(ANCHOR_CELL)
	var selected: Array[Vector3i] = []
	for component_variant in rigid.get("components", []):
		var component: Array = component_variant
		if _component_contains_token(component, lineage, anchor_token):
			continue
		for cell_variant in component:
			selected.append(cell_variant)
	if selected.size() != 3:
		return {"valid": false}

	var source := W0AuthorityPartitionSpace.new()
	source.name = fixture_name + "_CanonicalWorld"
	source.lineage_issuer = issuer
	source.dynamic_gravity_scale = 1.0
	source.dynamic_linear_damp = 0.0
	source.dynamic_angular_damp = 0.0
	source.dynamic_can_sleep = false
	world.add_child(source)
	source.initialize_static(volume, lineage, source_transform)

	var relation := {
		"world_lineage": lineage.get_lineage(SEAM_LEFT),
		"island_lineage": lineage.get_lineage(SEAM_RIGHT),
		"anchor_source_local": Vector3(4.0, 1.5, 0.5),
		"axis_source_local": Vector3.FORWARD,
	}

	if not source.request_authority_partition(selected, LocalMatterSpace.ProviderKind.DYNAMIC):
		return {"valid": false}

	return {
		"valid": true,
		"source": source,
		"source_transform": source_transform,
		"anchor_source_local": relation["anchor_source_local"],
		"relation": relation,
	}


func _component_contains_token(
	component: Array,
	lineage: MatterLineageMap,
	token: int
) -> bool:
	for cell_variant in component:
		var cell: Vector3i = cell_variant
		if lineage.get_lineage(cell) == token:
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


func _finite_body_state(body: ConstructBody) -> bool:
	return (
		body.global_position.is_finite()
		and body.linear_velocity.is_finite()
		and body.angular_velocity.is_finite()
	)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("C4_PASSIVE_RELATION_PASS: the same lineage-owned structural seam that drove C3 authority composition resolves to one disposable passive hinge; ordinary gravity rotates the retained dynamic island around a stable WORLD seam while an equivalent unjointed control falls freely.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("C4_PASSIVE_RELATION_FAIL: " + failure)
	world.free()
	quit(1)
