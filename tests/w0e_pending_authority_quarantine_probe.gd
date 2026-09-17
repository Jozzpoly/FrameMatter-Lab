extends SceneTree

const SOURCE_SIZE := Vector3i(8, 2, 2)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "W0PendingAuthorityQuarantineWorld"
	get_root().add_child(world)

	var first := _make_source(world, "QuarantineSource", Vector3.ZERO, 510001)
	var source := first["space"] as W0AuthorityPartitionSpace
	var selected: Array[Vector3i] = first["selected"]
	var unrelated_cell: Vector3i = first["unrelated_cell"]
	var revision_before: int = source.volume.revision

	_check(
		source.request_authority_partition(selected, LocalMatterSpace.ProviderKind.STATIC),
		"first authority partition request is accepted"
	)
	_check(source.is_authority_partition_pending(), "accepted request enters pending transaction state")
	_check(
		not source.mutate_cell(unrelated_cell, CellVolume.EMPTY),
		"ordinary source mutation is quarantined while authority partition is pending"
	)
	_check(source.volume.revision == revision_before, "rejected pending-window mutation cannot advance source revision")
	_check(source.volume.get_cell(unrelated_cell) == CellVolume.SOLID, "quarantined source Matter remains unchanged")

	await source.authority_partition_committed
	var first_result := source.get_last_authority_partition_result()
	var first_target := first_result.get("target_space") as LocalMatterSpace
	_check(first_target != null and is_instance_valid(first_target), "unchanged pending request commits normally")
	_check(source.volume.get_cell(unrelated_cell) == CellVolume.SOLID, "commit preserves unrelated canonical source Matter")

	var second := _make_source(world, "BypassSource", Vector3(20.0, 0.0, 0.0), 520001)
	var bypass_source := second["space"] as W0AuthorityPartitionSpace
	var bypass_selected: Array[Vector3i] = second["selected"]
	var bypass_cell: Vector3i = second["unrelated_cell"]
	var bypass_revision_before: int = bypass_source.volume.revision
	_check(
		bypass_source.request_authority_partition(bypass_selected, LocalMatterSpace.ProviderKind.STATIC),
		"second authority partition request is accepted"
	)
	_check(
		bypass_source.volume.set_cell(bypass_cell, CellVolume.EMPTY),
		"fixture can simulate a direct state bypass outside the normal mutation authority"
	)
	_check(
		bypass_source.volume.revision != bypass_revision_before,
		"direct bypass visibly changes the source revision captured by the transaction"
	)

	await _advance_frames(2)
	_check(not bypass_source.is_authority_partition_pending(), "stale request is cancelled at the defended physics boundary")
	_check(bypass_source.get_last_authority_partition_result().is_empty(), "revision mismatch produces no authority-transfer result")
	for source_cell in bypass_selected:
		_check(
			bypass_source.volume.get_cell(source_cell) != CellVolume.EMPTY,
			"failed-closed transaction leaves selected Matter under source authority at %s" % str(source_cell)
		)

	_finish(world)


func _make_source(
	world: Node3D,
	space_name: String,
	world_origin: Vector3,
	lineage_seed: int
) -> Dictionary:
	var volume := CellVolume.new(SOURCE_SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 1, 2), CellVolume.SOLID)
	volume.fill_box(Vector3i(5, 0, 0), Vector3i(8, 1, 2), CellVolume.SOLID)

	var lineage := MatterLineageMap.new(SOURCE_SIZE)
	var issuer := MatterLineageIssuer.new(lineage_seed)
	for z in range(SOURCE_SIZE.z):
		for y in range(SOURCE_SIZE.y):
			for x in range(SOURCE_SIZE.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					lineage.set_lineage(cell, issuer.allocate())

	var source := W0AuthorityPartitionSpace.new()
	source.name = space_name
	source.lineage_issuer = issuer
	world.add_child(source)
	source.initialize_static(volume, lineage, Transform3D(Basis.IDENTITY, world_origin))

	var selected: Array[Vector3i] = []
	for z in range(2):
		for x in range(5, 8):
			selected.append(Vector3i(x, 0, z))

	return {
		"space": source,
		"selected": selected,
		"unrelated_cell": Vector3i(0, 0, 0),
	}


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(world: Node3D) -> void:
	if world != null and is_instance_valid(world):
		world.free()
	if _failures.is_empty():
		print("W0E_PENDING_AUTHORITY_QUARANTINE_PASS: accepted W0 partitions quarantine ordinary source edits and fail closed if source revision changes outside the transaction.")
		quit(0)
		return
	for failure in _failures:
		push_error("W0E_PENDING_AUTHORITY_QUARANTINE_FAIL: " + failure)
	quit(1)
