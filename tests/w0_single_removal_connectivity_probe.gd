extends SceneTree

const LARGE_SIZE := Vector3i(32, 8, 32)
const PROOF_BUDGET := 256
const REPEATS := 7

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_case("dense interior", _dense_fixture(), Vector3i(4, 0, 4), true, 1)
	_check_case("leaf", _line_fixture(), Vector3i(0, 0, 0), true, 1)
	_check_case("line articulation", _line_fixture(), Vector3i(3, 0, 0), false, 2)
	_check_case("bridge articulation", _bridge_fixture(), Vector3i(4, 0, 2), false, 2)
	_check_case("cycle alternate path", _ring_fixture(), Vector3i(2, 0, 0), true, 1)
	_check_budget_refusal()

	# Exhaustively attack the one-sided claim over every occupied removal in a
	# dense connected fixture. False negatives are allowed; false positives are not.
	var sweep := _dense_fixture()
	var proven := 0
	var refused := 0
	for z in range(sweep.size.z):
		for y in range(sweep.size.y):
			for x in range(sweep.size.x):
				var cell := Vector3i(x, y, z)
				if sweep.get_cell(cell) == CellVolume.EMPTY:
					continue
				var after := sweep.duplicate_volume()
				after.set_cell(cell, CellVolume.EMPTY)
				if after.count_solid() == 0:
					continue
				var result := MatterTopology.prove_connected_after_single_removal(after, cell, PROOF_BUDGET)
				var components := MatterTopology.extract_connected_cell_components(after)
				if bool(result.get("proven_connected", false)):
					proven += 1
					_check(components.size() == 1, "sweep proof at %s has no false positive" % str(cell))
				else:
					refused += 1

	var large := CellVolume.new(LARGE_SIZE)
	large.fill_box(Vector3i.ZERO, Vector3i(32, 4, 32), CellVolume.SOLID)
	var removed := Vector3i(16, 0, 16)
	var after_large := large.duplicate_volume()
	after_large.set_cell(removed, CellVolume.EMPTY)
	var lineage := MatterLineageMap.new(LARGE_SIZE)
	var issuer := MatterLineageIssuer.new(930001)
	for z in range(LARGE_SIZE.z):
		for y in range(LARGE_SIZE.y):
			for x in range(LARGE_SIZE.x):
				var cell := Vector3i(x, y, z)
				if after_large.get_cell(cell) != CellVolume.EMPTY:
					lineage.set_lineage(cell, issuer.allocate())
	var anchors: Dictionary = {}
	for cell in [Vector3i(1, 0, 1), Vector3i(30, 0, 30)]:
		var token := lineage.get_lineage(cell)
		_check(token != MatterLineageMap.NONE, "large benchmark anchor has lineage")
		anchors[token] = true

	var proof_result := MatterTopology.prove_connected_after_single_removal(after_large, removed, PROOF_BUDGET)
	_check(bool(proof_result.get("proven_connected", false)), "large ordinary removal is locally proven connected")
	var policy_result := W0AnchoredDetachmentPolicy.evaluate(after_large, lineage, anchors)
	_check(bool(policy_result.get("valid", false)) and (policy_result.get("detached_components", []) as Array).is_empty(), "full policy independently agrees large removal has no detachment")

	var proof_us := _measure(func() -> void:
		MatterTopology.prove_connected_after_single_removal(after_large, removed, PROOF_BUDGET)
	)
	var policy_us := _measure(func() -> void:
		W0AnchoredDetachmentPolicy.evaluate(after_large, lineage, anchors)
	)
	print(
		"W0_SINGLE_REMOVAL_CONNECTIVITY_METRIC slots=%d solids=%d proof_us=%d full_policy_us=%d visited=%d neighbors=%d sweep_proven=%d sweep_refused=%d"
		% [
			LARGE_SIZE.x * LARGE_SIZE.y * LARGE_SIZE.z,
			after_large.count_solid(),
			proof_us,
			policy_us,
			int(proof_result.get("visited_cells", -1)),
			int(proof_result.get("occupied_neighbors", -1)),
			proven,
			refused,
		]
	)
	_finish()


func _check_case(label: String, source: CellVolume, removed: Vector3i, expect_proven: bool, expected_components: int) -> void:
	_check(source.get_cell(removed) != CellVolume.EMPTY, "%s removal fixture starts occupied" % label)
	var after := source.duplicate_volume()
	after.set_cell(removed, CellVolume.EMPTY)
	var result := MatterTopology.prove_connected_after_single_removal(after, removed, PROOF_BUDGET)
	var components := MatterTopology.extract_connected_cell_components(after)
	_check(components.size() == expected_components, "%s independent component count is expected" % label)
	if bool(result.get("proven_connected", false)):
		_check(components.size() == 1, "%s proof never claims connected for a split graph" % label)
	_check(bool(result.get("proven_connected", false)) == expect_proven, "%s proof decisiveness matches bounded fixture expectation" % label)


func _check_budget_refusal() -> void:
	var source := _dense_fixture()
	var removed := Vector3i(4, 0, 4)
	var after := source.duplicate_volume()
	after.set_cell(removed, CellVolume.EMPTY)
	var result := MatterTopology.prove_connected_after_single_removal(after, removed, 1)
	_check(not bool(result.get("proven_connected", false)), "tiny budget refuses rather than guessing connectivity")
	_check(MatterTopology.extract_connected_cell_components(after).size() == 1, "budget-refusal fixture really remains connected")


func _dense_fixture() -> CellVolume:
	var volume := CellVolume.new(Vector3i(9, 2, 9))
	volume.fill_box(Vector3i.ZERO, volume.size, CellVolume.SOLID)
	return volume


func _line_fixture() -> CellVolume:
	var volume := CellVolume.new(Vector3i(7, 1, 1))
	volume.fill_box(Vector3i.ZERO, volume.size, CellVolume.SOLID)
	return volume


func _bridge_fixture() -> CellVolume:
	var volume := CellVolume.new(Vector3i(9, 1, 5))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(4, 1, 5), CellVolume.SOLID)
	volume.fill_box(Vector3i(5, 0, 0), Vector3i(9, 1, 5), CellVolume.SOLID)
	volume.set_cell(Vector3i(4, 0, 2), CellVolume.SOLID)
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


func _measure(callback: Callable) -> int:
	var values: Array[int] = []
	for _iteration in range(REPEATS):
		var started := Time.get_ticks_usec()
		callback.call()
		values.append(Time.get_ticks_usec() - started)
	values.sort()
	return values[values.size() / 2]


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("W0_SINGLE_REMOVAL_CONNECTIVITY_PASS: bounded local proof has no false connected claims across articulation, cycle, leaf, budget-refusal and exhaustive dense-removal checks, with full-policy fallback left authoritative.")
		quit(0)
		return
	for failure in _failures:
		push_error("W0_SINGLE_REMOVAL_CONNECTIVITY_FAIL: " + failure)
	quit(1)
