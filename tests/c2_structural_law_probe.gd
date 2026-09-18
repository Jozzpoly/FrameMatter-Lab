extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var volume := CellVolume.new(Vector3i(8, 3, 1))
	var lineage := MatterLineageMap.new(volume.size)
	var issuer := MatterLineageIssuer.new(21001)

	for x in range(1, 7):
		_put(volume, lineage, issuer, Vector3i(x, 1, 0))

	var left_cell := Vector3i(3, 1, 0)
	var right_cell := Vector3i(4, 1, 0)
	var seam := [{
		"a": lineage.get_lineage(left_cell),
		"b": lineage.get_lineage(right_cell),
	}]

	var baseline_occupancy := _occupancy_signature(volume)
	var baseline_lineage := lineage.duplicate_tokens()

	var material_control := MatterTopology.extract_connected_cell_components(volume)
	_check(material_control.size() == 1, "ordinary Matter topology remains one materially continuous component")

	var rigid_control := C2RigidConnectivityChallenger.extract_rigid_components(volume, lineage, [])
	_check(bool(rigid_control.get("valid", false)), "rigid control classification is valid")
	_check(_component_sizes(rigid_control) == [6], "without a local law override the six-cell bar is one rigid component")

	var rigid_seam := C2RigidConnectivityChallenger.extract_rigid_components(volume, lineage, seam)
	_check(bool(rigid_seam.get("valid", false)), "seam classification is valid")
	_check(_component_sizes(rigid_seam) == [3, 3], "one lineage-owned blocked adjacency derives two rigid components")
	_check(MatterTopology.extract_connected_cell_components(volume).size() == 1, "material continuity remains one component while rigid connectivity splits")
	_check(_occupancy_signature(volume) == baseline_occupancy, "derived rigid view does not mutate CellVolume")
	_check(lineage.duplicate_tokens() == baseline_lineage, "derived rigid view does not mutate Matter lineage")

	var bypass_a := Vector3i(3, 2, 0)
	var bypass_b := Vector3i(4, 2, 0)
	_put(volume, lineage, issuer, bypass_a)
	_put(volume, lineage, issuer, bypass_b)
	var bypass_result := C2RigidConnectivityChallenger.extract_rigid_components(volume, lineage, seam)
	_check(bool(bypass_result.get("valid", false)), "bypass classification is valid")
	_check(_component_sizes(bypass_result) == [8], "an alternate rigid path bypasses the seam and reconnects the whole Matter region")

	_check(volume.set_cell(bypass_a, CellVolume.EMPTY), "bypass A can be removed")
	_check(lineage.clear_lineage(bypass_a), "bypass A lineage retires")
	_check(volume.set_cell(bypass_b, CellVolume.EMPTY), "bypass B can be removed")
	_check(lineage.clear_lineage(bypass_b), "bypass B lineage retires")
	var restored_split := C2RigidConnectivityChallenger.extract_rigid_components(volume, lineage, seam)
	_check(bool(restored_split.get("valid", false)), "post-bypass classification is valid")
	_check(_component_sizes(restored_split) == [3, 3], "removing the alternate path restores the two rigid components")
	_check(MatterTopology.extract_connected_cell_components(volume).size() == 1, "removing bypass still leaves one materially continuous component")

	var stale_seam := [{
		"a": lineage.get_lineage(left_cell),
		"b": 99999999,
	}]
	var stale_result := C2RigidConnectivityChallenger.extract_rigid_components(volume, lineage, stale_seam)
	_check(not bool(stale_result.get("valid", true)), "a seam that does not resolve to a live lineage adjacency fails closed")

	print(
		"C2_STRUCTURAL_LAW_METRIC material_components=%d rigid_control=%s rigid_seam=%s rigid_bypass=%s rigid_restored=%s"
		% [
			MatterTopology.extract_connected_cell_components(volume).size(),
			str(_component_sizes(rigid_control)),
			str(_component_sizes(rigid_seam)),
			str(_component_sizes(bypass_result)),
			str(_component_sizes(restored_split)),
		]
	)

	_finish()


func _put(
	volume: CellVolume,
	lineage: MatterLineageMap,
	issuer: MatterLineageIssuer,
	cell: Vector3i
) -> void:
	_check(volume.set_cell(cell, CellVolume.SOLID), "fixture cell %s can become occupied" % str(cell))
	_check(lineage.set_lineage(cell, issuer.allocate()), "fixture cell %s receives lineage" % str(cell))


func _component_sizes(result: Dictionary) -> Array[int]:
	var sizes: Array[int] = []
	for component_variant in result.get("components", []):
		var component: Array = component_variant
		sizes.append(component.size())
	sizes.sort()
	return sizes


func _occupancy_signature(volume: CellVolume) -> String:
	var parts: Array[String] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					parts.append("%d,%d,%d" % [x, y, z])
	return "|".join(parts)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("C2_STRUCTURAL_LAW_PASS: identical Matter occupancy can remain materially continuous while a lineage-owned local adjacency law derives one or two rigid components; alternate rigid paths bypass the seam without changing the law.")
		quit(0)
		return
	for failure in _failures:
		push_error("C2_STRUCTURAL_LAW_FAIL: " + failure)
	quit(1)
