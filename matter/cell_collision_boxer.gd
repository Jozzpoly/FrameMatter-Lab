class_name CellCollisionBoxer
extends RefCounted

# Collision boxes are disposable derived representation. They never define
# Matter identity, mass or lineage.
enum Mode {
	PER_CELL,
	MERGED_CUBOIDS,
}


static func build_boxes(volume: CellVolume, mode: int = Mode.MERGED_CUBOIDS) -> Array[Dictionary]:
	assert(volume != null)
	if mode == Mode.PER_CELL:
		return _build_per_cell_boxes(volume)
	assert(mode == Mode.MERGED_CUBOIDS)
	return _build_merged_cuboids(volume)


static func covered_cell_count(boxes: Array[Dictionary]) -> int:
	var count := 0
	for box_info in boxes:
		var size: Vector3i = box_info["size"]
		count += size.x * size.y * size.z
	return count


static func _build_per_cell_boxes(volume: CellVolume) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				boxes.append({"origin": cell, "size": Vector3i.ONE})
	return boxes


static func _build_merged_cuboids(volume: CellVolume) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var visited := PackedByteArray()
	visited.resize(volume.size.x * volume.size.y * volume.size.z)
	visited.fill(0)

	# Deterministic x→y→z greedy partition. It is not claimed to minimize box
	# count globally; the invariant is exact, non-overlapping occupied coverage.
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var start := Vector3i(x, y, z)
				if volume.get_cell(start) == CellVolume.EMPTY or _is_visited(visited, volume.size, start):
					continue

				var end_x := x + 1
				while end_x < volume.size.x:
					var candidate := Vector3i(end_x, y, z)
					if volume.get_cell(candidate) == CellVolume.EMPTY or _is_visited(visited, volume.size, candidate):
						break
					end_x += 1

				var end_y := y + 1
				while end_y < volume.size.y:
					var row_valid := true
					for check_x in range(x, end_x):
						var candidate := Vector3i(check_x, end_y, z)
						if volume.get_cell(candidate) == CellVolume.EMPTY or _is_visited(visited, volume.size, candidate):
							row_valid = false
							break
					if not row_valid:
						break
					end_y += 1

				var end_z := z + 1
				while end_z < volume.size.z:
					var plane_valid := true
					for check_y in range(y, end_y):
						for check_x in range(x, end_x):
							var candidate := Vector3i(check_x, check_y, end_z)
							if volume.get_cell(candidate) == CellVolume.EMPTY or _is_visited(visited, volume.size, candidate):
								plane_valid = false
								break
						if not plane_valid:
							break
					if not plane_valid:
						break
					end_z += 1

				var box_size := Vector3i(end_x - x, end_y - y, end_z - z)
				for mark_z in range(z, end_z):
					for mark_y in range(y, end_y):
						for mark_x in range(x, end_x):
							_set_visited(visited, volume.size, Vector3i(mark_x, mark_y, mark_z))
				boxes.append({"origin": start, "size": box_size})

	return boxes


static func _is_visited(visited: PackedByteArray, volume_size: Vector3i, cell: Vector3i) -> bool:
	return visited[_index(volume_size, cell)] != 0


static func _set_visited(visited: PackedByteArray, volume_size: Vector3i, cell: Vector3i) -> void:
	visited[_index(volume_size, cell)] = 1


static func _index(volume_size: Vector3i, cell: Vector3i) -> int:
	return cell.x + volume_size.x * (cell.y + volume_size.y * cell.z)
