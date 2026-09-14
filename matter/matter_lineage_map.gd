class_name MatterLineageMap
extends RefCounted

# Experimental logical-identity sidecar. Tokens are opaque test identities, not
# a final UUID/persistence scheme. Zero means no tracked lineage at this cell.
const NONE := 0

var size: Vector3i
var _tokens := PackedInt64Array()


func _init(map_size: Vector3i = Vector3i(8, 8, 8)) -> void:
	assert(map_size.x > 0 and map_size.y > 0 and map_size.z > 0)
	size = map_size
	_tokens.resize(size.x * size.y * size.z)
	_tokens.fill(NONE)


func in_bounds(cell: Vector3i) -> bool:
	return (
		cell.x >= 0 and cell.x < size.x
		and cell.y >= 0 and cell.y < size.y
		and cell.z >= 0 and cell.z < size.z
	)


func index_of(cell: Vector3i) -> int:
	assert(in_bounds(cell))
	return cell.x + size.x * (cell.y + size.y * cell.z)


func get_lineage(cell: Vector3i) -> int:
	if not in_bounds(cell):
		return NONE
	return _tokens[index_of(cell)]


func set_lineage(cell: Vector3i, lineage_token: int) -> bool:
	if not in_bounds(cell):
		return false
	assert(lineage_token >= NONE)
	var index := index_of(cell)
	if _tokens[index] == lineage_token:
		return false
	_tokens[index] = lineage_token
	return true


func clear_lineage(cell: Vector3i) -> bool:
	return set_lineage(cell, NONE)


func count_assigned() -> int:
	var count := 0
	for token in _tokens:
		if token != NONE:
			count += 1
	return count


func duplicate_tokens() -> PackedInt64Array:
	return _tokens.duplicate()
