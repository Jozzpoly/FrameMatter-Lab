extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var volume := CellVolume.new(Vector3i(32, 8, 32))
	_assert_count(volume, "fresh volume")

	var changed := volume.fill_box(Vector3i(1, 0, 1), Vector3i(31, 4, 31), CellVolume.SOLID)
	_check(changed == 30 * 4 * 30, "fill_box reports exact newly occupied cardinality")
	_assert_count(volume, "after large fill")

	var count_before_replace := volume.count_solid()
	var revision_before_replace := volume.revision
	_check(volume.set_cell(Vector3i(4, 2, 4), 2), "non-empty material replacement is accepted")
	_check(volume.count_solid() == count_before_replace, "non-empty to non-empty replacement preserves occupancy count")
	_check(volume.revision == revision_before_replace + 1, "material replacement still advances logical revision")
	_assert_count(volume, "after material replacement")

	var revision_before_noop := volume.revision
	_check(not volume.set_cell(Vector3i(4, 2, 4), 2), "same-material write is a no-op")
	_check(volume.revision == revision_before_noop, "same-material no-op does not advance revision")
	_assert_count(volume, "after no-op")

	for z in range(1, 31, 3):
		for x in range(1, 31, 4):
			volume.set_cell(Vector3i(x, 0, z), CellVolume.EMPTY)
	_assert_count(volume, "after sparse removals")

	volume.fill_box(Vector3i(0, 4, 0), Vector3i(32, 8, 32), CellVolume.SOLID)
	_assert_count(volume, "after second large fill")

	var components: Array[CellVolume] = MatterTopology.extract_connected_components(volume)
	_check(not components.is_empty(), "topology can consume cached-count volume")
	for component in components:
		_assert_count(component, "topology component clone")

	var compact_info := MatterTopology.compact_volume(volume)
	var compact := compact_info.get("volume") as CellVolume
	_check(compact != null, "compact_volume returns a volume")
	if compact != null:
		_assert_count(compact, "compact volume")

	var count_calls := 20000
	var count_started := Time.get_ticks_usec()
	var sink := 0
	for _i in range(count_calls):
		sink += volume.count_solid()
	var count_usec := Time.get_ticks_usec() - count_started
	_check(sink == volume.count_solid() * count_calls, "repeated count calls remain deterministic")

	print(
		"P1_CELL_VOLUME_SOLID_COUNT_METRIC slots=%d solids=%d calls=%d count_calls_us=%d revision=%d"
		% [
			volume.size.x * volume.size.y * volume.size.z,
			volume.count_solid(),
			count_calls,
			count_usec,
			volume.revision,
		]
	)
	_finish()


func _assert_count(volume: CellVolume, label: String) -> void:
	_check(volume.count_solid() == _manual_count(volume), "%s cached occupancy matches independent full scan" % label)


func _manual_count(volume: CellVolume) -> int:
	var count := 0
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				if volume.get_cell(Vector3i(x, y, z)) != CellVolume.EMPTY:
					count += 1
	return count


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_CELL_VOLUME_SOLID_COUNT_PASS: cached occupancy remains identical to independent scans through fill, removal, material replacement, topology cloning and compaction.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CELL_VOLUME_SOLID_COUNT_FAIL: " + failure)
	quit(1)
