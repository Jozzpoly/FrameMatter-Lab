extends SceneTree

const SOURCE_SIZE := Vector3i(7, 2, 3)
const SOURCE_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(-3.0, 1.0, 5.0))

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "W0AAuthorityPartitionWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(SOURCE_SIZE)
	volume.fill_box(Vector3i.ZERO, SOURCE_SIZE, CellVolume.SOLID)
	var lineage := MatterLineageMap.new(SOURCE_SIZE)
	var issuer := MatterLineageIssuer.new(310001)
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, issuer.allocate())

	var source := LocalMatterSpace.new()
	source.name = "W0ACanonicalSource"
	source.lineage_issuer = issuer
	world.add_child(source)
	source.initialize_static(volume, lineage, SOURCE_TRANSFORM)

	var selected: Array[Vector3i] = [
		Vector3i(4, 0, 0),
		Vector3i(5, 0, 0),
		Vector3i(4, 0, 1),
	]
	var truth_before := _snapshot_truth(source.volume, source.lineage)
	var tokens_before := _token_set(source.lineage)
	var source_space_id := source.get_instance_id()

	if not source.has_method("request_authority_partition"):
		_check(false, "LocalMatterSpace exposes the W0A authority-partition request path")
		_finish(world)
		return
	if not source.has_method("get_last_authority_partition_result"):
		_check(false, "LocalMatterSpace exposes the W0A authority-partition result")
		_finish(world)
		return

	var accepted := bool(source.call(
		"request_authority_partition",
		selected,
		LocalMatterSpace.ProviderKind.STATIC
	))
	_check(accepted, "one connected Matter portion is accepted for authority partition")
	if not accepted:
		_finish(world)
		return

	await physics_frame
	await process_frame

	var result: Variant = source.call("get_last_authority_partition_result")
	_check(result != null, "W0A publishes an explicit partition result")
	if result == null:
		_finish(world)
		return

	var target := result.get("target_space") as LocalMatterSpace
	var source_origin: Vector3i = result.get("source_origin")
	_check(target != null and is_instance_valid(target), "partition creates one fresh live target Space")
	if target == null:
		_finish(world)
		return

	_check(source.get_instance_id() == source_space_id and not source.is_retired(), "canonical source Space survives the partition")
	_check(source.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "canonical source remains statically represented")
	_check(target.get_instance_id() != source_space_id and not target.is_retired(), "detached Matter receives fresh Space identity")
	_check(target.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "W0A isolates ownership transfer from dynamic physics")
	_check(target.lineage_issuer == issuer and source.lineage_issuer == issuer, "source and target share one lineage issuer domain")

	var selected_lookup: Dictionary = {}
	for cell in selected:
		selected_lookup[cell] = true
		_check(source.volume.get_cell(cell) == CellVolume.EMPTY, "transferred source cell becomes empty")
		_check(source.lineage.get_lineage(cell) == MatterLineageMap.NONE, "transferred source cell retains no source lineage authority")

	for source_cell_variant in truth_before.keys():
		var source_cell: Vector3i = source_cell_variant
		if selected_lookup.has(source_cell):
			continue
		var truth: Dictionary = truth_before[source_cell]
		_check(source.volume.get_cell(source_cell) == int(truth["material"]), "canonical remainder preserves retained material")
		_check(source.lineage.get_lineage(source_cell) == int(truth["lineage"]), "canonical remainder preserves retained lineage")

	var source_tokens_after := _token_set(source.lineage)
	var target_tokens_after := _token_set(target.lineage)
	var overlap_count := 0
	for token_variant in source_tokens_after.keys():
		if target_tokens_after.has(token_variant):
			overlap_count += 1
	_check(overlap_count == 0, "no lineage token is authoritative in source and target simultaneously")
	_check(source_tokens_after.size() + target_tokens_after.size() == tokens_before.size(), "authority partition conserves lineage cardinality")
	for token_variant in tokens_before.keys():
		_check(source_tokens_after.has(token_variant) or target_tokens_after.has(token_variant), "every pre-transfer lineage token remains authoritative exactly once")

	var target_provider := target.get_active_provider()
	_check(target_provider != null, "fresh target owns a live static provider")
	var max_world_error := 0.0
	for source_cell in selected:
		var target_cell := source_cell - source_origin
		var truth: Dictionary = truth_before[source_cell]
		_check(target.volume.get_cell(target_cell) == int(truth["material"]), "target compact storage preserves transferred material")
		_check(target.lineage.get_lineage(target_cell) == int(truth["lineage"]), "target compact storage preserves transferred lineage")
		if target_provider != null:
			var old_world := SOURCE_TRANSFORM * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
			var new_world := target_provider.global_transform * (Vector3(target_cell) + Vector3(0.5, 0.5, 0.5))
			max_world_error = max(max_world_error, old_world.distance_to(new_world))
	_check(max_world_error < 0.00001, "authority transfer does not move selected Matter in world space")

	# The selected L-shape leaves one empty target cell inside its compact bounds.
	# Creating fresh Matter on each owner after extraction must use one shared
	# issuer domain rather than colliding independent counters.
	var target_fresh_cell := Vector3i(1, 0, 1)
	_check(target.volume.get_cell(target_fresh_cell) == CellVolume.EMPTY, "target fixture retains one empty cell for fresh-lineage challenge")
	_check(target.mutate_cell(target_fresh_cell, CellVolume.SOLID), "target can create fresh Matter after transfer")
	var target_fresh_token := target.lineage.get_lineage(target_fresh_cell)
	var source_fresh_cell := selected[0]
	_check(source.mutate_cell(source_fresh_cell, CellVolume.SOLID), "canonical source can create fresh Matter after transfer")
	var source_fresh_token := source.lineage.get_lineage(source_fresh_cell)
	_check(target_fresh_token != MatterLineageMap.NONE and source_fresh_token != MatterLineageMap.NONE, "both owners receive fresh nonzero lineage")
	_check(target_fresh_token != source_fresh_token, "fresh Matter created on different owners cannot collide in lineage")
	_check(not tokens_before.has(target_fresh_token) and not tokens_before.has(source_fresh_token), "post-transfer fresh lineage never reuses pre-transfer identity")

	print(
		"W0A_AUTHORITY_PARTITION_METRIC source_space_id=%d target_space_id=%d before_tokens=%d source_tokens=%d target_tokens=%d overlap=%d world_error=%.10f source_origin=%s target_fresh=%d source_fresh=%d"
		% [
			source_space_id,
			target.get_instance_id(),
			tokens_before.size(),
			source_tokens_after.size(),
			target_tokens_after.size(),
			overlap_count,
			max_world_error,
			str(source_origin),
			target_fresh_token,
			source_fresh_token,
		]
	)

	_finish(world)


func _snapshot_truth(volume: CellVolume, lineage: MatterLineageMap) -> Dictionary:
	var snapshot: Dictionary = {}
	for cell in _occupied_cells(volume):
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
		print("W0A_AUTHORITY_PARTITION_PASS: one canonical Space survived while selected Matter changed owner exactly once, retained lineage stayed disjoint/conserved and world positions remained continuous.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("W0A_AUTHORITY_PARTITION_FAIL: " + failure)
	world.free()
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
