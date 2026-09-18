extends SceneTree

const ACQUIRE_FRAMES := 24
const DRIVE_FRAMES := 80
const POST_EDIT_FRAMES := 24
const C6_TARGET_CELL := Vector3i(15, 5, 16)
const NON_ENDPOINT_SOURCE_CELL := Vector3i(20, 5, 19)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "C6 runtime probe loads Owner-facing recovery scene")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	var player := root.call("get_player") as SpaceQueryCharacter
	var interactor := root.call("get_interactor") as P1MatterInteractor
	var registry := root.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry
	_check(world != null and player != null and interactor != null and registry != null, "C6 resolves real scene roles")
	_check(player.grounded and player.support_space == world, "actor begins supported by ordinary WORLD Matter")
	if world == null or player == null or interactor == null or registry == null:
		_finish(root)
		return

	var occupied_before := world.volume.count_solid()
	var actor_world_before := player.global_position
	var physics_frame_before := Engine.get_physics_frames()
	var accepted := bool(root.call("request_c6_structural_seam_near_cell_for_test", C6_TARGET_CELL))
	_check(accepted, "one bounded structural-seam action is accepted on the authored narrow neck")
	var authoring: Dictionary = root.call("get_c6_last_authoring_result_for_test")
	_check(int(authoring.get("candidate_count", 0)) == 1, "target cell resolves exactly one separable horizontal adjacency")
	_check(int(authoring.get("selected_cells", 0)) > 0, "C6 derives a nonempty unanchored rigid island")
	_check(world.volume.count_solid() == occupied_before, "authoring the local law does not destroy Matter")
	_check(world.is_authority_partition_pending(), "local law queues real W0 authority composition")
	if not accepted or not world.is_authority_partition_pending():
		_finish(root)
		return

	await world.authority_partition_committed
	var result := world.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "C6 authority composition publishes one dynamic target")
	if target == null:
		_finish(root)
		return

	var body := target.get_active_provider() as ConstructBody
	var relation: Dictionary = root.call("get_c6_active_relation_for_test")
	var joint := root.call("get_c6_relation_joint_for_test") as HingeJoint3D
	var install_frame := int(root.call("get_c6_relation_install_physics_frame_for_test"))
	_check(not relation.is_empty(), "C6 relation truth is live in the real scene immediately after authority commit")
	_check(joint != null and is_instance_valid(joint), "passive relation host exists before leaving the authority publication boundary")
	_check(install_frame == Engine.get_physics_frames(), "relation host manifests in the same physics frame as authority composition")
	_check(install_frame >= physics_frame_before, "relation install frame is causally after the Owner seam request")
	_check(
		not relation.has("body_id") and not relation.has("provider_id") and not relation.has("space_id"),
		"logical relation truth contains no body/provider/Space identity"
	)
	_check(body != null, "related island owns a dynamic ConstructBody")
	_check(registry.get_active_count() == 2, "canonical WORLD and one related dynamic island coexist")
	_check(player.grounded and player.support_space == target, "actor follows supporting Matter into the relation-owned dynamic island")
	_check(player.global_position.distance_to(actor_world_before) < 0.0001, "actor handoff remains world-continuous")
	if body == null or joint == null:
		_finish(root)
		return

	var island_token := int(relation.get("island_lineage", MatterLineageMap.NONE))
	var island_cell_result := _find_lineage_cell(target, island_token)
	_check(not island_cell_result.is_empty(), "relation island endpoint lineage resolves inside the current target")
	if island_cell_result.is_empty():
		_finish(root)
		return
	var island_cell: Vector3i = island_cell_result["cell"]
	var offset: Vector3i = relation.get("world_to_island_offset", Vector3i.ZERO)
	var island_anchor_local := (
		Vector3(island_cell)
		+ Vector3(0.5, 0.5, 0.5)
		- Vector3(offset) * 0.5
		- Vector3.UP * 0.5
	)
	var anchor_world := joint.global_position
	var immediate_anchor_gap := (body.global_transform * island_anchor_local).distance_to(anchor_world)
	_check(immediate_anchor_gap < 0.0001, "relation begins with no world-space seam jump")
	_check(body.linear_velocity.length() < 0.00001 and body.angular_velocity.length() < 0.00001, "authority+relation transaction has no hidden launch")

	var initial_basis := body.global_basis
	var max_anchor_gap := immediate_anchor_gap
	var max_rotation := 0.0
	var actor_ride_frames := 0
	for _frame in range(DRIVE_FRAMES):
		await physics_frame
		await process_frame
		max_anchor_gap = maxf(max_anchor_gap, (body.global_transform * island_anchor_local).distance_to(anchor_world))
		max_rotation = maxf(max_rotation, _basis_angle(initial_basis, body.global_basis))
		if player.grounded and player.support_space == target:
			actor_ride_frames += 1

	_check(max_anchor_gap < 0.12, "passive structural seam stays physically bounded under ordinary world collision")
	_check(max_rotation > 0.10, "gravity produces real passive relation rotation in the Owner-facing scene")
	_check(actor_ride_frames > 0, "actor remains materially supported by the related island for at least part of its motion")

	var source_origin: Vector3i = result.get("source_origin", Vector3i.ZERO)
	var non_endpoint_local := NON_ENDPOINT_SOURCE_CELL - source_origin
	_check(target.volume.in_bounds(non_endpoint_local), "non-endpoint history edit maps inside related island")
	var non_endpoint_token := target.lineage.get_lineage(non_endpoint_local) if target.volume.in_bounds(non_endpoint_local) else MatterLineageMap.NONE
	_check(non_endpoint_token != MatterLineageMap.NONE and non_endpoint_token != island_token, "history edit selects live non-endpoint Matter")
	if non_endpoint_token != MatterLineageMap.NONE:
		_check(
			interactor.apply_edit_to_cell(target, non_endpoint_local, P1MatterInteractor.EditMode.REMOVE),
			"real production mutation path edits the moving related island"
		)
	_check(bool(root.call("has_c6_active_relation_for_test")), "unrelated live Matter edit preserves structural relation truth")
	await _advance_frames(POST_EDIT_FRAMES)
	_check(bool(root.call("has_c6_active_relation_for_test")), "relation remains live after edited mass/geometry evolves under physics")

	var endpoint_result := _find_lineage_cell(target, island_token)
	_check(not endpoint_result.is_empty(), "endpoint Matter still exists before destruction history")
	if endpoint_result.is_empty():
		_finish(root)
		return
	var endpoint_cell: Vector3i = endpoint_result["cell"]
	_check(
		interactor.apply_edit_to_cell(target, endpoint_cell, P1MatterInteractor.EditMode.REMOVE),
		"live endpoint Matter can be destroyed through the production edit authority"
	)
	_check(not bool(root.call("has_c6_active_relation_for_test")), "endpoint destruction kills logical relation immediately")
	var dead_joint := root.call("get_c6_relation_joint_for_test") as HingeJoint3D
	_check(dead_joint == null or not is_instance_valid(dead_joint), "stale solver host retires when relation truth dies")

	_check(
		interactor.apply_edit_to_cell(target, endpoint_cell, P1MatterInteractor.EditMode.PLACE),
		"same address can receive fresh Matter after relation endpoint death"
	)
	var fresh_token := target.lineage.get_lineage(endpoint_cell)
	_check(fresh_token != MatterLineageMap.NONE and fresh_token != island_token, "same-address recreation receives fresh lineage")
	_check(not bool(root.call("has_c6_active_relation_for_test")), "fresh same-address Matter does not resurrect historical relation")

	print(
		"C6_RUNTIME_FLOW_METRIC selected=%d install_frame=%d immediate_gap=%.10f max_gap=%.6f rotation=%.6f actor_ride_frames=%d old_endpoint=%d fresh_endpoint=%d"
		% [
			int(authoring.get("selected_cells", 0)),
			install_frame,
			immediate_anchor_gap,
			max_anchor_gap,
			max_rotation,
			actor_ride_frames,
			island_token,
			fresh_token,
		]
	)

	_finish(root)


func _find_lineage_cell(space: LocalMatterSpace, token: int) -> Dictionary:
	if space == null or space.lineage == null:
		return {}
	for z in range(space.lineage.size.z):
		for y in range(space.lineage.size.y):
			for x in range(space.lineage.size.x):
				var cell := Vector3i(x, y, z)
				if space.lineage.get_lineage(cell) == token:
					return {"cell": cell}
	return {}


func _basis_angle(reference: Basis, current: Basis) -> float:
	var delta := reference.inverse() * current
	return absf(delta.get_rotation_quaternion().get_angle())


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(root: Node) -> void:
	if root != null and is_instance_valid(root):
		root.free()
	if _failures.is_empty():
		print("C6_RUNTIME_FLOW_PASS: the real recovery scene composes local structural law -> authority split -> same-frame passive relation -> gravity/ride -> live edit -> endpoint-history death without mechanism-object truth.")
		quit(0)
		return
	for failure in _failures:
		push_error("C6_RUNTIME_FLOW_FAIL: " + failure)
	quit(1)
