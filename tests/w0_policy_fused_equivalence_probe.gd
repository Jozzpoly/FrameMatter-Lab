extends SceneTree

const LARGE_SIZE := Vector3i(32, 8, 32)
const REPEATS := 5

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_compare_case("connected", _connected_case())
	_compare_case("one_detached", _one_detached_case())
	_compare_case("two_anchored", _two_anchored_case())
	_compare_case("two_detached", _two_detached_case())
	_compare_case("no_retained_anchor", _no_retained_anchor_case())

	var large := _large_connected_case()
	var volume := large["volume"] as CellVolume
	var lineage := large["lineage"] as MatterLineageMap
	var anchors: Dictionary = large["anchors"]
	var legacy_usec := _measure(func() -> void: _legacy_evaluate(volume, lineage, anchors))
	var fused_usec := _measure(func() -> void: W0AnchoredDetachmentPolicy.evaluate(volume, lineage, anchors))

	print(
		"W0_POLICY_FUSED_METRIC slots=%d solids=%d legacy_policy_us=%d fused_policy_us=%d"
		% [LARGE_SIZE.x * LARGE_SIZE.y * LARGE_SIZE.z, volume.count_solid(), legacy_usec, fused_usec]
	)
	_finish()


func _compare_case(label: String, fixture: Dictionary) -> void:
	var volume := fixture["volume"] as CellVolume
	var lineage := fixture["lineage"] as MatterLineageMap
	var anchors: Dictionary = fixture["anchors"]
	var legacy := _canonical_result(_legacy_evaluate(volume, lineage, anchors))
	var fused := _canonical_result(W0AnchoredDetachmentPolicy.evaluate(volume, lineage, anchors))
	_check(legacy == fused, "%s fused policy is semantically identical to legacy policy" % label)


func _legacy_evaluate(volume: CellVolume, lineage: MatterLineageMap, anchor_tokens: Dictionary) -> Dictionary:
	if volume == null or lineage == null:
		return _invalid("missing Matter authority")
	if lineage.size != volume.size:
		return _invalid("Matter/lineage size mismatch")
	if anchor_tokens.is_empty():
		return _invalid("no canonical anchor lineage supplied")

	var components: Array = MatterTopology.extract_connected_cell_components(volume)
	if components.is_empty():
		return _invalid("canonical Matter is empty")

	var anchored_components: Array = []
	var detached_components: Array = []
	var retained_anchor_tokens: Dictionary = {}
	for component_variant in components:
		var component: Array = component_variant
		var cells: Array[Vector3i] = []
		var contains_anchor := false
		for cell_variant in component:
			var cell: Vector3i = cell_variant
			var token := lineage.get_lineage(cell)
			if token == MatterLineageMap.NONE:
				return _invalid("occupied Matter is missing lineage")
			cells.append(cell)
			if anchor_tokens.has(token):
				contains_anchor = true
				retained_anchor_tokens[token] = true
		if contains_anchor:
			anchored_components.append(cells)
		else:
			detached_components.append(cells)

	if retained_anchor_tokens.is_empty() or anchored_components.is_empty():
		return _invalid("no retained canonical anchor lineage remains")
	return {
		"valid": true,
		"reason": "",
		"anchored_components": anchored_components,
		"detached_components": detached_components,
		"retained_anchor_tokens": retained_anchor_tokens,
	}


func _invalid(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"anchored_components": [],
		"detached_components": [],
		"retained_anchor_tokens": {},
	}


func _canonical_result(result: Dictionary) -> Dictionary:
	var anchor_tokens: Array[int] = []
	for token_variant in (result.get("retained_anchor_tokens", {}) as Dictionary).keys():
		anchor_tokens.append(int(token_variant))
	anchor_tokens.sort()
	return {
		"valid": bool(result.get("valid", false)),
		"reason": str(result.get("reason", "")),
		"anchored": _component_signatures(result.get("anchored_components", [])),
		"detached": _component_signatures(result.get("detached_components", [])),
		"anchors": anchor_tokens,
	}


func _component_signatures(components: Array) -> Array[String]:
	var signatures: Array[String] = []
	for component_variant in components:
		var component: Array = component_variant
		var cells: Array[String] = []
		for cell_variant in component:
			var cell: Vector3i = cell_variant
			cells.append("%d,%d,%d" % [cell.x, cell.y, cell.z])
		cells.sort()
		signatures.append("|".join(cells))
	signatures.sort()
	return signatures


func _connected_case() -> Dictionary:
	var volume := CellVolume.new(Vector3i(8, 3, 8))
	volume.fill_box(Vector3i(1, 0, 1), Vector3i(7, 2, 7), CellVolume.SOLID)
	return _lineaged_fixture(volume, [Vector3i(2, 0, 2)])


func _one_detached_case() -> Dictionary:
	var volume := CellVolume.new(Vector3i(10, 3, 8))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(4, 1, 4), CellVolume.SOLID)
	volume.fill_box(Vector3i(6, 1, 4), Vector3i(10, 2, 8), CellVolume.SOLID)
	return _lineaged_fixture(volume, [Vector3i(1, 0, 1)])


func _two_anchored_case() -> Dictionary:
	var volume := CellVolume.new(Vector3i(10, 2, 5))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 1, 3), CellVolume.SOLID)
	volume.fill_box(Vector3i(7, 0, 2), Vector3i(10, 1, 5), CellVolume.SOLID)
	return _lineaged_fixture(volume, [Vector3i(1, 0, 1), Vector3i(8, 0, 3)])


func _two_detached_case() -> Dictionary:
	var volume := CellVolume.new(Vector3i(12, 2, 6))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(4, 1, 4), CellVolume.SOLID)
	volume.fill_box(Vector3i(6, 0, 0), Vector3i(8, 1, 2), CellVolume.SOLID)
	volume.fill_box(Vector3i(9, 0, 4), Vector3i(12, 1, 6), CellVolume.SOLID)
	return _lineaged_fixture(volume, [Vector3i(1, 0, 1)])


func _no_retained_anchor_case() -> Dictionary:
	var fixture := _one_detached_case()
	fixture["anchors"] = {99999999: true}
	return fixture


func _large_connected_case() -> Dictionary:
	var volume := CellVolume.new(LARGE_SIZE)
	volume.fill_box(Vector3i(1, 0, 1), Vector3i(31, 4, 31), CellVolume.SOLID)
	return _lineaged_fixture(volume, [Vector3i(2, 0, 2), Vector3i(29, 0, 29)])


func _lineaged_fixture(volume: CellVolume, anchor_cells: Array[Vector3i]) -> Dictionary:
	var lineage := MatterLineageMap.new(volume.size)
	var issuer := MatterLineageIssuer.new(910001)
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					lineage.set_lineage(cell, issuer.allocate())
	var anchors: Dictionary = {}
	for cell in anchor_cells:
		var token := lineage.get_lineage(cell)
		_check(token != MatterLineageMap.NONE, "fixture anchor %s has real lineage" % str(cell))
		anchors[token] = true
	return {"volume": volume, "lineage": lineage, "anchors": anchors}


func _measure(callback: Callable) -> int:
	var values: Array[int] = []
	for _i in range(REPEATS):
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
		print("W0_POLICY_FUSED_PASS: fused topology/lineage classification preserves legacy anchored-detachment semantics across connected, detached, multi-anchor and invalid-anchor fixtures.")
		quit(0)
		return
	for failure in _failures:
		push_error("W0_POLICY_FUSED_FAIL: " + failure)
	quit(1)
