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
