class_name LocalMatterSplitResult
extends RefCounted

# Bounded I3 transaction result. It describes one source Space retiring into
# fresh connected-component successor Spaces. This is mapping evidence, not a
# final persistence/identity-succession schema.

var source_space: LocalMatterSpace
var source_provider_id := 0
var source_transform := Transform3D.IDENTITY
var source_linear_velocity := Vector3.ZERO
var source_angular_velocity := Vector3.ZERO
var source_com_world := Vector3.ZERO

var successors: Array = []
var source_origins: Array = []
var source_components: Array = []


func size() -> int:
	return successors.size()


func find_successor_index_for_source_cell(source_cell: Vector3i) -> int:
	for index in range(source_components.size()):
		var component: CellVolume = source_components[index]
		if component.in_bounds(source_cell) and component.get_cell(source_cell) != CellVolume.EMPTY:
			return index
	return -1


func get_successor_for_source_cell(source_cell: Vector3i) -> LocalMatterSpace:
	var index := find_successor_index_for_source_cell(source_cell)
	if index < 0:
		return null
	return successors[index] as LocalMatterSpace


func get_source_origin_for_source_cell(source_cell: Vector3i) -> Vector3i:
	var index := find_successor_index_for_source_cell(source_cell)
	assert(index >= 0)
	return source_origins[index] as Vector3i


func map_source_local_point_for_cell(source_cell: Vector3i, source_local_point: Vector3) -> Dictionary:
	var index := find_successor_index_for_source_cell(source_cell)
	if index < 0:
		return {}
	var origin: Vector3i = source_origins[index]
	return {
		"index": index,
		"space": successors[index],
		"source_origin": origin,
		"local_point": source_local_point - Vector3(origin),
	}
