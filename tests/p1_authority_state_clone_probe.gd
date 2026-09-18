extends SceneTree

const SIZE := Vector3i(32, 8, 32)
const REPEATS := 5

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var volume := CellVolume.new(SIZE)
	volume.fill_box(Vector3i(1, 0, 1), Vector3i(31, 4, 31), CellVolume.SOLID)
	var lineage := MatterLineageMap.new(SIZE)
	var issuer := MatterLineageIssuer.new(810001)
	for z in range(SIZE.z):
		for y in range(SIZE.y):
			for x in range(SIZE.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					lineage.set_lineage(cell, issuer.allocate())

	var selected: Array[Vector3i] = [
		Vector3i(12, 0, 12),
		Vector3i(13, 0, 12),
		Vector3i(12, 0, 13),
		Vector3i(13, 0, 13),
	]
	var original_revision := volume.revision
	var original_count := volume.count_solid()
	var original_token := lineage.get_lineage(selected[0])

	var volume_clone := volume.duplicate_volume()
	var lineage_clone := lineage.duplicate_map()
	_check(volume_clone != volume, "volume clone has independent object identity")
	_check(lineage_clone != lineage, "lineage clone has independent object identity")
	_check(volume_clone.size == volume.size and lineage_clone.size == lineage.size, "deep clones preserve storage shape")
	_check(volume_clone.revision == original_revision, "volume clone preserves logical revision")
	_check(volume_clone.count_solid() == original_count, "volume clone preserves occupied cardinality")
	_check(lineage_clone.get_lineage(selected[0]) == original_token, "lineage clone preserves tokens")

	_check(volume_clone.set_cell(selected[0], CellVolume.EMPTY), "volume clone can mutate independently")
	_check(lineage_clone.clear_lineage(selected[0]), "lineage clone can mutate independently")
	_check(volume.get_cell(selected[0]) != CellVolume.EMPTY, "mutating volume clone cannot alter original Matter")
	_check(lineage.get_lineage(selected[0]) == original_token, "mutating lineage clone cannot alter original lineage")
	_check(volume_clone.count_solid() == original_count - 1, "clone occupancy invariant remains correct after independent mutation")
	_check(volume_clone.revision == original_revision + 1, "clone revision advances through normal mutation")

	var legacy_usec := _measure(func() -> void: _legacy_source_stage(volume, lineage, selected))
	var clone_usec := _measure(func() -> void: _clone_source_stage(volume, lineage, selected))

	print(
		"P1_AUTHORITY_STATE_CLONE_METRIC slots=%d solids=%d selected=%d legacy_source_stage_us=%d clone_source_stage_us=%d"
		% [SIZE.x * SIZE.y * SIZE.z, original_count, selected.size(), legacy_usec, clone_usec]
	)
	_finish()


func _legacy_source_stage(volume: CellVolume, lineage: MatterLineageMap, selected: Array[Vector3i]) -> void:
	var selected_lookup: Dictionary = {}
	for cell in selected:
		selected_lookup[cell] = true
	var staged_volume := CellVolume.new(volume.size)
	var staged_lineage := MatterLineageMap.new(lineage.size)
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				var material_id := volume.get_cell(cell)
				if material_id == CellVolume.EMPTY or selected_lookup.has(cell):
					continue
				staged_volume.set_cell(cell, material_id)
				staged_lineage.set_lineage(cell, lineage.get_lineage(cell))
	staged_volume.revision = volume.revision + selected.size()


func _clone_source_stage(volume: CellVolume, lineage: MatterLineageMap, selected: Array[Vector3i]) -> void:
	var staged_volume := volume.duplicate_volume()
	var staged_lineage := lineage.duplicate_map()
	for cell in selected:
		staged_volume.set_cell(cell, CellVolume.EMPTY)
		staged_lineage.clear_lineage(cell)


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
		print("P1_AUTHORITY_STATE_CLONE_PASS: deep Matter/lineage clones preserve source truth, mutate independently and support O(k)-style authority staging without manual source reconstruction.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_AUTHORITY_STATE_CLONE_FAIL: " + failure)
	quit(1)
