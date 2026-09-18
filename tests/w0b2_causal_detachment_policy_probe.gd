extends SceneTree

const SOURCE_SIZE := Vector3i(9, 5, 5)
const SOURCE_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(-4.0, 0.0, -2.0))
const BRIDGE_CELL := Vector3i(3, 1, 2)
const ANCHOR_CELL := Vector3i(1, 0, 2)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "W0B2CausalDetachmentWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(SOURCE_SIZE)
	# Canonical foundation.
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 1, 5), CellVolume.SOLID)
	# One-cell-high neck from the anchored foundation to the elevated platform.
	volume.set_cell(Vector3i(2, 1, 2), CellVolume.SOLID)
	volume.set_cell(BRIDGE_CELL, CellVolume.SOLID)
	# Elevated ordinary Matter. Before the edit this is part of the same canonical
	# authority; there is no pre-authored moving Space.
	volume.fill_box(Vector3i(4, 1, 1), Vector3i(8, 2, 4), CellVolume.SOLID)

	var lineage := MatterLineageMap.new(SOURCE_SIZE)
	var issuer := MatterLineageIssuer.new(330001)
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, issuer.allocate())
	var anchor_token := lineage.get_lineage(ANCHOR_CELL)
	var destroyed_bridge_token := lineage.get_lineage(BRIDGE_CELL)
	_check(anchor_token != MatterLineageMap.NONE, "fixture has a retained canonical anchor lineage")
	_check(destroyed_bridge_token != MatterLineageMap.NONE, "fixture bridge carries real Matter lineage before destruction")

	var source := W0AuthorityPartitionSpace.new()
	source.name = "W0B2CanonicalSource"
	source.lineage_issuer = issuer
	source.dynamic_gravity_scale = 1.0
	source.dynamic_linear_damp = 0.0
	source.dynamic_angular_damp = 0.0
	source.dynamic_can_sleep = true
	world.add_child(source)
	source.initialize_static(volume, lineage, SOURCE_TRANSFORM)

	var tokens_before := _token_set(source.lineage)
	_check(MatterTopology.extract_connected_components(source.volume).size() == 1, "ordinary Matter starts as one connected canonical component")

	# Ordinary destructive edit: this Matter genuinely dies. Detachment is a
	# consequence of the resulting topology, not a special extraction click.
	_check(source.mutate_cell(BRIDGE_CELL, CellVolume.EMPTY), "ordinary REMOVE destroys the bridge Matter")
	_check(source.lineage.get_lineage(BRIDGE_CELL) == MatterLineageMap.NONE, "destroyed bridge lineage is retired, not transferred")
	_check(MatterTopology.extract_connected_components(source.volume).size() == 2, "bridge removal creates one anchored and one unanchored component")

	var anchors := {anchor_token: true}
	var decision := W0AnchoredDetachmentPolicy.evaluate(source.volume, source.lineage, anchors)
	_check(bool(decision.get("valid", false)), "anchored detachment policy can classify the post-edit canonical topology")
	if not bool(decision.get("valid", false)):
		_finish(world)
		return

	var anchored_components: Array = decision.get("anchored_components", [])
	var detached_components: Array = decision.get("detached_components", [])
	_check(anchored_components.size() == 1, "exactly one component retains canonical anchoring")
	_check(detached_components.size() == 1, "exactly one component becomes a detach candidate")
	if detached_components.size() != 1:
		_finish(world)
		return

	var detached_cells: Array[Vector3i] = detached_components[0]
	_check(detached_cells.size() == 12, "policy returns the complete elevated Matter component, not a heuristic subset")
	_check(not detached_cells.has(BRIDGE_CELL), "destroyed bridge Matter is never part of the transfer payload")
	_check(not detached_cells.has(ANCHOR_CELL), "canonical anchor Matter never leaks into detached payload")

	var accepted := source.request_authority_partition(detached_cells, LocalMatterSpace.ProviderKind.DYNAMIC)
	_check(accepted, "same W0 authority path accepts the policy-selected detached component")
	if not accepted:
		_finish(world)
		return

	await physics_frame
	var result := source.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "causal detach creates one fresh LocalSpace only after the world edit")
	if target == null:
		_finish(world)
		return

	var target_tokens := _token_set(target.lineage)
	var source_tokens := _token_set(source.lineage)
	_check(source_tokens.has(anchor_token), "canonical anchor lineage remains owned by the surviving source")
	_check(not source_tokens.has(destroyed_bridge_token) and not target_tokens.has(destroyed_bridge_token), "destroyed bridge lineage does not resurrect in either owner")

	var overlap := 0
	for token_variant in source_tokens.keys():
		if target_tokens.has(token_variant):
			overlap += 1
	_check(overlap == 0, "causal detach keeps source and target lineage authority disjoint")
	_check(source_tokens.size() + target_tokens.size() + 1 == tokens_before.size(), "post-edit ownership plus one destroyed bridge token exactly accounts for pre-edit Matter")

	var body := target.get_active_provider() as ConstructBody
	_check(body != null, "unanchored component becomes a real dynamic ConstructBody")
	if body != null:
		_check(body.linear_velocity.length() < 0.000001 and body.angular_velocity.length() < 0.000001, "causal detach begins with zero hidden launch")
		var rid := body.get_rid()
		var pre_step_origin := body.global_transform.origin
		await process_frame
		var server_transform: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
		_check(server_transform.origin.y < pre_step_origin.y - 0.00001, "gravity moves the detached world fragment after the edit")

	print(
		"W0B2_CAUSAL_DETACH_METRIC before_tokens=%d source_tokens=%d target_tokens=%d detached_cells=%d overlap=%d anchor=%d destroyed_bridge=%d"
		% [
			tokens_before.size(),
			source_tokens.size(),
			target_tokens.size(),
			detached_cells.size(),
			overlap,
			anchor_token,
			destroyed_bridge_token,
		]
	)

	_finish(world)


func _token_set(lineage: MatterLineageMap) -> Dictionary:
	var result: Dictionary = {}
	for z in range(lineage.size.z):
		for y in range(lineage.size.y):
			for x in range(lineage.size.x):
				var token := lineage.get_lineage(Vector3i(x, y, z))
				if token != MatterLineageMap.NONE:
					result[token] = true
	return result


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					result.append(cell)
	return result


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("W0B2_CAUSAL_DETACH_PASS: an ordinary destructive world edit exposes an unanchored Matter component that transfers through the same W0 authority path and begins solver-driven motion without a pre-authored moving Space.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("W0B2_CAUSAL_DETACH_FAIL: " + failure)
	world.free()
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
