class_name MatterTopology
extends RefCounted

const AXIAL_NEIGHBORS: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]


# Cell-list connectivity is the lightweight topology representation for callers
# that need component membership but not a full component-sized Matter clone.
# Logical authority remains in the source CellVolume; these arrays are derived.
static func extract_connected_cell_components(source: CellVolume) -> Array:
	var components: Array = []
	if source == null:
		return components

	var visited := PackedByteArray()
	visited.resize(source.size.x * source.size.y * source.size.z)
	visited.fill(0)

	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var start := Vector3i(x, y, z)
				var start_index := _flat_index(source.size, start)
				if source.get_cell(start) == CellVolume.EMPTY or visited[start_index] != 0:
					continue

				var component: Array[Vector3i] = []
				var queue: Array[Vector3i] = [start]
				var cursor := 0
				visited[start_index] = 1

				while cursor < queue.size():
					var cell: Vector3i = queue[cursor]
					cursor += 1
					component.append(cell)

					for offset in AXIAL_NEIGHBORS:
						var neighbor := cell + offset
						if not source.in_bounds(neighbor):
							continue
						var neighbor_index := _flat_index(source.size, neighbor)
						if visited[neighbor_index] != 0:
							continue
						if source.get_cell(neighbor) == CellVolume.EMPTY:
							continue
						visited[neighbor_index] = 1
						queue.append(neighbor)

				components.append(component)

	return components


static func cells_form_single_component(cells: Array[Vector3i]) -> bool:
	if cells.is_empty():
		return false

	var selected: Dictionary = {}
	for cell in cells:
		if selected.has(cell):
			return false
		selected[cell] = true

	var visited: Dictionary = {}
	var queue: Array[Vector3i] = [cells[0]]
	var cursor := 0
	visited[cells[0]] = true

	while cursor < queue.size():
		var cell: Vector3i = queue[cursor]
		cursor += 1
		for offset in AXIAL_NEIGHBORS:
			var neighbor := cell + offset
			if not selected.has(neighbor) or visited.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)

	return visited.size() == selected.size()


static func extract_connected_components(source: CellVolume) -> Array[CellVolume]:
	var components: Array[CellVolume] = []
	var visited: Dictionary = {}

	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var start := Vector3i(x, y, z)
				if source.get_cell(start) == CellVolume.EMPTY or visited.has(start):
					continue

				var component := CellVolume.new(source.size)
				var queue: Array[Vector3i] = [start]
				var cursor := 0
				visited[start] = true

				while cursor < queue.size():
					var cell: Vector3i = queue[cursor]
					cursor += 1
					component.set_cell(cell, source.get_cell(cell))

					for offset in AXIAL_NEIGHBORS:
						var neighbor := cell + offset
						if not source.in_bounds(neighbor):
							continue
						if source.get_cell(neighbor) == CellVolume.EMPTY:
							continue
						if visited.has(neighbor):
							continue
						visited[neighbor] = true
						queue.append(neighbor)

				components.append(component)

	return components


static func compact_volume(source: CellVolume) -> Dictionary:
	assert(source.count_solid() > 0)

	var min_cell := Vector3i(source.size.x, source.size.y, source.size.z)
	var max_cell := Vector3i(-1, -1, -1)

	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var cell := Vector3i(x, y, z)
				if source.get_cell(cell) == CellVolume.EMPTY:
					continue
				min_cell.x = min(min_cell.x, x)
				min_cell.y = min(min_cell.y, y)
				min_cell.z = min(min_cell.z, z)
				max_cell.x = max(max_cell.x, x)
				max_cell.y = max(max_cell.y, y)
				max_cell.z = max(max_cell.z, z)

	var compact_size: Vector3i = max_cell - min_cell + Vector3i.ONE
	var compact := CellVolume.new(compact_size)

	for z in range(min_cell.z, max_cell.z + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for x in range(min_cell.x, max_cell.x + 1):
				var source_cell := Vector3i(x, y, z)
				var material_id: int = source.get_cell(source_cell)
				if material_id == CellVolume.EMPTY:
					continue
				compact.set_cell(source_cell - min_cell, material_id)

	return {
		"origin": min_cell,
		"volume": compact,
	}


static func center_of_mass_local(volume: CellVolume) -> Vector3:
	var weighted_sum := Vector3.ZERO
	var solid_count := 0

	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				weighted_sum += Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)
				solid_count += 1

	if solid_count == 0:
		return Vector3.ZERO
	return weighted_sum / float(solid_count)


static func _flat_index(volume_size: Vector3i, cell: Vector3i) -> int:
	return cell.x + volume_size.x * (cell.y + volume_size.y * cell.z)
