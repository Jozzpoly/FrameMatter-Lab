extends SceneTree

const BUDGET := 64
const RECOVERY_ANCHORS: Array[Vector3i] = [
	Vector3i(1, 0, 1),
	Vector3i(30, 0, 1),
	Vector3i(1, 0, 30),
	Vector3i(30, 0, 30),
]
const REPEATS := 7

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_compare_fixture("line articulation", _line_fixture(), Vector3i(3, 0, 0), [Vector3i(0, 0, 0)], true)
	_compare_fixture("ring alternate path", _ring_fixture(), Vector3i(2, 0, 0), [Vector3i(0, 0, 0)], true)
	_compare_fixture("dense interior", _dense_fixture(), Vector3i(4, 0, 4), [Vector3i(0, 0, 0)], true)
	_compare_fixture("two anchored sides", _line_fixture(), Vector3i(3, 0, 0), [Vector3i(0, 0, 0), Vector3i(6, 0, 0)], true)
	_check_forced_fallback()

	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads for bounded detach classification")
	if packed == null:
		_finish(null)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(4)
	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	var bridge: Vector3i = root.call("get_recovery_causal_bridge_cell_for_test")
	_check(world != null and world.volume.get_cell(bridge) != CellVolume.EMPTY, "Recovery bridge fixture is live")
	if world == null:
		_finish(root)
		return

	var after := world.volume.duplicate_volume()
	var after_lineage := world.lineage.duplicate_map()
	after.set_cell(bridge, CellVolume.EMPTY)
	after_lineage.clear_lineage(bridge)
	var live_anchors: Array[Vector3i] = []
	var anchor_tokens: Dictionary = {}
	for anchor in RECOVERY_ANCHORS:
		if after.get_cell(anchor) == CellVolume.EMPTY:
			continue
		var token := after_lineage.get_lineage(anchor)
		_check(token != MatterLineageMap.NONE, "Recovery anchor keeps lineage")
		live_anchors.append(anchor)
		anchor_tokens[token] = true

	var bounded := MatterTopology.prove_partition_after_single_removal_from_connected_source(
		after,
		bridge,
		live_anchors,
		BUDGET
	)
	var full := W0AnchoredDetachmentPolicy.evaluate(after, after_lineage, anchor_tokens)
	_check(bool(bounded.get("proven", false)), "Recovery bridge partition is boundedly proven")
	_check(_detached_signatures(bounded.get("detached_components", [])) == _detached_signatures(full.get("detached_components", [])), "Recovery bounded detached membership exactly equals full W0 policy")
	var bounded_detached: Array = bounded.get("detached_components", [])
	_check(bounded_detached.size() == 1 and (bounded_detached[0] as Array).size() == 36, "Recovery bounded proof finds exact 36-cell shelf")
	_check(int(bounded.get("anchored_component_count", 0)) == 1, "Recovery bounded proof leaves exactly one anchored remainder")

	var bounded_us := _measure(func() -> void:
		MatterTopology.prove_partition_after_single_removal_from_connected_source(after, bridge, live_anchors, BUDGET)
	)
	var full_us := _measure(func() -> void:
		W0AnchoredDetachmentPolicy.evaluate(after, after_lineage, anchor_tokens)
	)
	print(
		"W0_BOUNDED_DETACH_CLASSIFICATION_METRIC slots=%d solids=%d budget=%d bounded_us=%d full_policy_us=%d visited=%d neighbors=%d detached_cells=%d"
		% [
			after.size.x * after.size.y * after.size.z,
			after.count_solid(),
			BUDGET,
			bounded_us,
			full_us,
			int(bounded.get("visited_cells", -1)),
			int(bounded.get("occupied_neighbors", -1)),
			(bounded_detached[0] as Array).size() if bounded_detached.size() == 1 else -1,
		]
	)
	_finish(root)


func _compare_fixture(
	label: String,
	source_before: CellVolume,
	removed: Vector3i,
	anchor_cells: Array[Vector3i],
	expect_proven: bool
) -> void:
	_check(source_before.get_cell(removed) != CellVolume.EMPTY, "%s starts with occupied removal cell" % label)
	_check(MatterTopology.extract_connected_cell_components(source_before).size() == 1, "%s precondition source is connected" % label)
	var lineage := MatterLineageMap.new(source_before.size)
	var issuer := MatterLineageIssuer.new(940001)
	for z in range(source_before.size.z):
		for y in range(source_before.size.y):
			for x in range(source_before.size.x):
				var cell := Vector3i(x, y, z)
				if source_before.get_cell(cell) != CellVolume.EMPTY:
					lineage.set_lineage(cell, issuer.allocate())
	var anchors: Dictionary = {}
	for anchor in anchor_cells:
		anchors[lineage.get_lineage(anchor)] = true

	var after := source_before.duplicate_volume()
	var after_lineage := lineage.duplicate_map()
	after.set_cell(removed, CellVolume.EMPTY)
	after_lineage.clear_lineage(removed)
	var live_anchor_cells: Array[Vector3i] = []
	for anchor in anchor_cells:
		if after.get_cell(anchor) != CellVolume.EMPTY:
			live_anchor_cells.append(anchor)
	var bounded := MatterTopology.prove_partition_after_single_removal_from_connected_source(after, removed, live_anchor_cells, BUDGET)
	var full := W0AnchoredDetachmentPolicy.evaluate(after, after_lineage, anchors)
	_check(bool(bounded.get("proven", false)) == expect_proven, "%s bounded decisiveness matches expectation" % label)
	if bool(bounded.get("proven", false)):
		_check(bool(full.get("valid", false)), "%s full policy remains valid" % label)
		_check(_detached_signatures(bounded.get("detached_components", [])) == _detached_signatures(full.get("detached_components", [])), "%s bounded detached membership equals full policy" % label)
		_check(int(bounded.get("anchored_component_count", 0)) == (full.get("anchored_components", []) as Array).size(), "%s bounded anchored component count equals full policy" % label)


func _check_forced_fallback() -> void:
	var source := _dense_fixture()
	var removed := Vector3i(4, 0, 4)
	var after := source.duplicate_volume()
	after.set_cell(removed, CellVolume.EMPTY)
	var result := MatterTopology.prove_partition_after_single_removal_from_connected_source(
		after,
		removed,
		[Vector3i(0, 0, 0)],
		1
	)
	_check(not bool(result.get("proven", false)), "insufficient budget falls back instead of guessing")


func _detached_signatures(components: Array) -> Array[String]:
	var result: Array[String] = []
	for component_variant in components:
		var cells: Array = component_variant
		var labels: Array[String] = []
		for cell_variant in cells:
			var cell: Vector3i = cell_variant
			labels.append("%d,%d,%d" % [cell.x, cell.y, cell.z])
		labels.sort()
		result.append("|".join(labels))
	result.sort()
	return result


func _line_fixture() -> CellVolume:
	var volume := CellVolume.new(Vector3i(7, 1, 1))
	volume.fill_box(Vector3i.ZERO, volume.size, CellVolume.SOLID)
	return volume


func _ring_fixture() -> CellVolume:
	var volume := CellVolume.new(Vector3i(5, 1, 5))
	for x in range(5):
		volume.set_cell(Vector3i(x, 0, 0), CellVolume.SOLID)
		volume.set_cell(Vector3i(x, 0, 4), CellVolume.SOLID)
	for z in range(1, 4):
		volume.set_cell(Vector3i(0, 0, z), CellVolume.SOLID)
		volume.set_cell(Vector3i(4, 0, z), CellVolume.SOLID)
	return volume


func _dense_fixture() -> CellVolume:
	var volume := CellVolume.new(Vector3i(9, 2, 9))
	volume.fill_box(Vector3i.ZERO, volume.size, CellVolume.SOLID)
	return volume


func _measure(callback: Callable) -> int:
	var values: Array[int] = []
	for _iteration in range(REPEATS):
		var started := Time.get_ticks_usec()
		callback.call()
		values.append(Time.get_ticks_usec() - started)
	values.sort()
	return values[values.size() / 2]


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(root: Node) -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	if _failures.is_empty():
		print("W0_BOUNDED_DETACH_CLASSIFICATION_PASS: bounded post-removal partition proof matches full W0 detached membership on adversarial connected fixtures and the exact 36-cell Recovery shelf, while insufficient evidence fails closed.")
		quit(0)
		return
	for failure in _failures:
		push_error("W0_BOUNDED_DETACH_CLASSIFICATION_FAIL: " + failure)
	quit(1)
