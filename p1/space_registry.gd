class_name P1SpaceRegistry
extends Node

# Consumer-side lifecycle index for the interactive P1 lab.
# It is deliberately NOT Matter authority and not a final world manager.
# LocalMatterSpace remains authoritative for Matter/provider lifecycle; this
# registry only keeps the interactive scene aware of which Spaces are live.

signal active_spaces_changed
signal provider_changed(space: LocalMatterSpace)
signal storage_rebased(space: LocalMatterSpace, report: Dictionary)
signal split_committed(source: LocalMatterSpace, result: LocalMatterSplitResult)

var _active_spaces: Array[LocalMatterSpace] = []


func register_space(space: LocalMatterSpace) -> void:
	if not _register_space_internal(space):
		return
	active_spaces_changed.emit()


func unregister_space(space: LocalMatterSpace) -> void:
	if not _active_spaces.has(space):
		return
	_active_spaces.erase(space)
	active_spaces_changed.emit()


func clear() -> void:
	if _active_spaces.is_empty():
		return
	_active_spaces.clear()
	active_spaces_changed.emit()


func get_active_spaces() -> Array[LocalMatterSpace]:
	_prune_invalid()
	return _active_spaces.duplicate()


func get_active_count() -> int:
	_prune_invalid()
	return _active_spaces.size()


func find_space_for_node(node: Node) -> LocalMatterSpace:
	var current := node
	while current != null:
		if current is LocalMatterSpace:
			var space := current as LocalMatterSpace
			return space if _active_spaces.has(space) and not space.is_retired() else null
		current = current.get_parent()
	return null


func find_space_for_provider(provider: Node3D) -> LocalMatterSpace:
	if provider == null:
		return null
	for space in get_active_spaces():
		if space.get_active_provider() == provider:
			return space
	return null


func find_nearest_space(world_point: Vector3) -> LocalMatterSpace:
	var best: LocalMatterSpace
	var best_distance := INF
	for space in get_active_spaces():
		var provider := space.get_active_provider()
		if provider == null:
			continue
		var focus_world := provider.to_global(space.get_content_center_local())
		var distance := world_point.distance_squared_to(focus_world)
		if distance < best_distance:
			best_distance = distance
			best = space
	return best


func _register_space_internal(space: LocalMatterSpace) -> bool:
	if space == null or space.is_retired() or _active_spaces.has(space):
		return false
	_active_spaces.append(space)
	var provider_callback := Callable(self, "_on_provider_transition_committed").bind(space)
	if not space.provider_transition_committed.is_connected(provider_callback):
		space.provider_transition_committed.connect(provider_callback)
	var storage_callback := Callable(self, "_on_storage_rebase_committed").bind(space)
	if not space.storage_rebase_committed.is_connected(storage_callback):
		space.storage_rebase_committed.connect(storage_callback)
	var split_callback := Callable(self, "_on_topology_split_committed").bind(space)
	if not space.topology_split_committed.is_connected(split_callback):
		space.topology_split_committed.connect(split_callback)
	return true


func _on_provider_transition_committed(
	_previous_provider_id: int,
	_current_provider_id: int,
	_provider_kind: int,
	space: LocalMatterSpace
) -> void:
	if _active_spaces.has(space) and not space.is_retired():
		provider_changed.emit(space)


func _on_storage_rebase_committed(report: Dictionary, space: LocalMatterSpace) -> void:
	if _active_spaces.has(space) and not space.is_retired():
		storage_rebased.emit(space, report.duplicate(true))


func _on_topology_split_committed(result: LocalMatterSplitResult, source: LocalMatterSpace) -> void:
	_active_spaces.erase(source)
	for successor_variant in result.successors:
		var successor := successor_variant as LocalMatterSpace
		if successor != null:
			_register_space_internal(successor)
	split_committed.emit(source, result)
	active_spaces_changed.emit()


func _prune_invalid() -> void:
	for index in range(_active_spaces.size() - 1, -1, -1):
		var space := _active_spaces[index]
		if space == null or not is_instance_valid(space) or space.is_retired():
			_active_spaces.remove_at(index)
