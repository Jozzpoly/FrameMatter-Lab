extends SceneTree

const SOURCE_SIZE := Vector3i(8, 3, 1)
const SOURCE_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(-4.0, 4.0, 0.0))
const ANCHOR_CELL := Vector3i(1, 1, 0)
const SEAM_LEFT := Vector3i(3, 1, 0)
const SEAM_RIGHT := Vector3i(4, 1, 0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "C3AuthorityCompositionWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(SOURCE_SIZE)
	var lineage := MatterLineageMap.new(SOURCE_SIZE)
	var issuer := MatterLineageIssuer.new(23001)
	for x in range(1, 7):
		var cell := Vector3i(x, 1, 0)
		_check(volume.set_cell(cell, CellVolume.SOLID), "fixture cell %s becomes occupied" % str(cell))
		_check(lineage.set_lineage(cell, issuer.allocate()), "fixture cell %s receives lineage" % str(cell))

	var anchor_token := lineage.get_lineage(ANCHOR_CELL)
	var seam := [{
		"a": lineage.get_lineage(SEAM_LEFT),
		"b": lineage.get_lineage(SEAM_RIGHT),
	}]

	var source := W0AuthorityPartitionSpace.new()
	source.name = "C3CanonicalWorldMatter"
	source.lineage_issuer = issuer
	source.dynamic_gravity_scale = 1.0
	source.dynamic_linear_damp = 0.0
	source.dynamic_angular_damp = 0.0
	source.dynamic_can_sleep = true
	world.add_child(source)
	source.initialize_static(volume, lineage, SOURCE_TRANSFORM)

	var source_space_id := source.get_instance_id()
	var truth_before := _snapshot_truth(source.volume, source.lineage)
	var tokens_before := _token_set(source.lineage)
	var revision_before := source.volume.revision

	_check(MatterTopology.extract_connected_cell_components(source.volume).size() == 1, "ordinary WORLD Matter begins as one materially continuous component")

	var rigid_control := C2RigidConnectivityChallenger.extract_rigid_components(source.volume, source.lineage, [])
	_check(bool(rigid_control.get("valid", false)), "control rigid classification is valid")
	_check(_component_sizes(rigid_control) == [6], "without the local law ordinary WORLD Matter derives one rigid organization")

	var rigid_law := C2RigidConnectivityChallenger.extract_rigid_components(source.volume, source.lineage, seam)
	_check(bool(rigid_law.get("valid", false)), "local-law rigid classification is valid")
	_check(_component_sizes(rigid_law) == [3, 3], "one local seam derives two rigid components without changing Matter occupancy")
	_check(source.volume.revision == revision_before, "deriving rigid organization does not mutate Matter revision")
	_check(_token_set(source.lineage).size() == tokens_before.size(), "deriving rigid organization does not mutate lineage authority")

	var anchored_components: Array = []
	var unanchored_components: Array = []
	for component_variant in rigid_law.get("components", []):
		var component: Array = component_variant
		if _component_contains_token(component, source.lineage, anchor_token):
			anchored_components.append(component)
		else:
			unanchored_components.append(component)

	_check(anchored_components.size() == 1, "exactly one derived rigid component retains canonical anchor lineage")
	_check(unanchored_components.size() == 1, "exactly one derived rigid component is unanchored")
	if unanchored_components.size() != 1:
		_finish(world)
		return

	var selected: Array[Vector3i] = []
	for cell_variant in unanchored_components[0]:
		selected.append(cell_variant)

	_check(selected.size() == 3, "derived unanchored island contains the expected three retained Matter cells")
	_check(not selected.has(ANCHOR_CELL), "canonical anchor Matter never enters the transfer payload")
	_check(MatterTopology.cells_form_single_component(selected), "derived target is valid connected Matter for the existing W0 transaction")

	# This is the C3 composition boundary: the local-law-derived island is fed
	# directly into the already-earned W0 authority transaction. No Matter REMOVE
	# or topology mutation is used to cause decomposition.
	var accepted := source.request_authority_partition(
		selected,
		LocalMatterSpace.ProviderKind.DYNAMIC
	)
	_check(accepted, "existing W0 authority transaction accepts the derived unanchored rigid island")
	if not accepted:
		_finish(world)
		return

	# Request acceptance still must not mutate canonical Matter before commit.
	_check(_snapshot_truth(source.volume, source.lineage) == truth_before, "authority request does not pre-mutate WORLD Matter")
	_check(source.volume.revision == revision_before, "authority request preserves source revision until commit")

	await physics_frame
	var result := source.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "C3 creates one fresh authority only at the transaction boundary")
	if target == null:
		_finish(world)
		return

	_check(source.get_instance_id() == source_space_id and not source.is_retired(), "canonical WORLD Space survives authority composition")
	_check(source.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "anchored WORLD remainder stays static")
	_check(target.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "derived unanchored rigid island receives dynamic authority")
	_check(target.get_instance_id() != source_space_id, "dynamic island receives fresh Space identity rather than redefining WORLD identity")

	var source_tokens := _token_set(source.lineage)
	var target_tokens := _token_set(target.lineage)
	var overlap := 0
	for token_variant in source_tokens.keys():
		if target_tokens.has(token_variant):
			overlap += 1
	_check(overlap == 0, "source and target lineage authority are disjoint after composition")
	_check(source_tokens.size() + target_tokens.size() == tokens_before.size(), "authority composition conserves all pre-law Matter lineage")
	for token_variant in tokens_before.keys():
		_check(source_tokens.has(token_variant) or target_tokens.has(token_variant), "every pre-law lineage token remains authoritative exactly once")
	_check(source_tokens.has(anchor_token), "canonical anchor lineage remains in WORLD")

	var source_origin: Vector3i = result.get("source_origin", Vector3i.ZERO)
	var body := target.get_active_provider() as ConstructBody
	_check(body != null, "derived target owns a real dynamic provider")
	if body == null:
		_finish(world)
		return

	var max_world_error := 0.0
	for source_cell in selected:
		var target_cell := source_cell - source_origin
		var before: Dictionary = truth_before[source_cell]
		_check(source.volume.get_cell(source_cell) == CellVolume.EMPTY, "transferred cell leaves canonical storage without Matter destruction semantics")
		_check(source.lineage.get_lineage(source_cell) == MatterLineageMap.NONE, "transferred lineage leaves canonical authority")
		_check(target.volume.get_cell(target_cell) == int(before["material"]), "target retains transferred material")
		_check(target.lineage.get_lineage(target_cell) == int(before["lineage"]), "target retains exact transferred lineage")
		var old_world := SOURCE_TRANSFORM * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
		var new_world := body.global_transform * (Vector3(target_cell) + Vector3(0.5, 0.5, 0.5))
		max_world_error = maxf(max_world_error, old_world.distance_to(new_world))
	_check(max_world_error < 0.00001, "authority composition introduces no world-space Matter jump")

	var pre_linear := body.linear_velocity
	var pre_angular := body.angular_velocity
	_check(pre_linear.length() < 0.000001, "derived dynamic authority begins with zero hidden linear launch")
	_check(pre_angular.length() < 0.000001, "derived dynamic authority begins with zero hidden angular launch")

	var rid := body.get_rid()
	var pre_step_origin := body.global_transform.origin
	await process_frame
	var server_transform: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	var server_linear: Vector3 = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
	_check(server_transform.origin.y < pre_step_origin.y - 0.00001, "gravity supplies the first physical motion after law-driven decomposition")
	_check(server_linear.y < -0.0001, "first nonzero velocity is solver-owned downward motion")

	print(
		"C3_AUTHORITY_COMPOSITION_METRIC material_components=%d rigid_control=%s rigid_law=%s selected=%d source_tokens=%d target_tokens=%d overlap=%d world_error=%.10f pre_v=%s first_v=%s"
		% [
			MatterTopology.extract_connected_cell_components(volume).size(),
			str(_component_sizes(rigid_control)),
			str(_component_sizes(rigid_law)),
			selected.size(),
			source_tokens.size(),
			target_tokens.size(),
			overlap,
			max_world_error,
			str(pre_linear),
			str(server_linear),
		]
	)

	_finish(world)


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


func _snapshot_truth(volume: CellVolume, lineage: MatterLineageMap) -> Dictionary:
	var snapshot: Dictionary = {}
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				snapshot[cell] = {
					"material": volume.get_cell(cell),
					"lineage": lineage.get_lineage(cell),
				}
	return snapshot


func _token_set(lineage: MatterLineageMap) -> Dictionary:
	var result: Dictionary = {}
	for z in range(lineage.size.z):
		for y in range(lineage.size.y):
			for x in range(lineage.size.x):
				var token := lineage.get_lineage(Vector3i(x, y, z))
				if token != MatterLineageMap.NONE:
					result[token] = true
	return result


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("C3_AUTHORITY_COMPOSITION_PASS: one local structural law derives an unanchored rigid island from ordinary materially-continuous WORLD Matter; the existing W0 transaction transfers exactly that retained Matter to zero-launch dynamic authority while canonical WORLD survives.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("C3_AUTHORITY_COMPOSITION_FAIL: " + failure)
	world.free()
	quit(1)
