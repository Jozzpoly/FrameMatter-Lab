class_name CellVolume
extends RefCounted

const EMPTY := 0
const SOLID := 1

var size: Vector3i
var revision := 0
var _cells := PackedInt32Array()


func _init(volume_size: Vector3i = Vector3i(8, 8, 8)) -> void:
	assert(volume_size.x > 0 and volume_size.y > 0 and volume_size.z > 0)
	size = volume_size
	_cells.resize(size.x * size.y * size.z)
	_cells.fill(EMPTY)


func in_bounds(cell: Vector3i) -> bool:
	return (
		cell.x >= 0 and cell.x < size.x
		and cell.y >= 0 and cell.y < size.y
		and cell.z >= 0 and cell.z < size.z
	)


func index_of(cell: Vector3i) -> int:
	assert(in_bounds(cell))
	return cell.x + size.x * (cell.y + size.y * cell.z)


func get_cell(cell: Vector3i) -> int:
	if not in_bounds(cell):
		return EMPTY
	return _cells[index_of(cell)]


func set_cell(cell: Vector3i, material_id: int) -> bool:
	if not in_bounds(cell):
		return false
	var index := index_of(cell)
	if _cells[index] == material_id:
		return false
	_cells[index] = material_id
	revision += 1
	return true


func fill_box(from_inclusive: Vector3i, to_exclusive: Vector3i, material_id: int) -> int:
	var changed := 0
	for z in range(from_inclusive.z, to_exclusive.z):
		for y in range(from_inclusive.y, to_exclusive.y):
			for x in range(from_inclusive.x, to_exclusive.x):
				if set_cell(Vector3i(x, y, z), material_id):
					changed += 1
	return changed


func count_solid() -> int:
	var count := 0
	for material_id in _cells:
		if material_id != EMPTY:
			count += 1
	return count


func duplicate_cells() -> PackedInt32Array:
	return _cells.duplicate()
