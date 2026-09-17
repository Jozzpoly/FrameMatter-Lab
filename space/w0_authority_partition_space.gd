class_name W0AuthorityPartitionSpace
extends LocalMatterSpace

# Experimental W0 execution piece. This is deliberately narrower than
# LocalMatterSpace: it proves an asymmetric authority partition where the
# canonical/source Space survives and one connected Matter portion moves to a
# fresh LocalMatterSpace. If later consumers demonstrate that this belongs in
# the general Space lifecycle, it can be promoted then.

signal authority_partition_committed(result: Dictionary)

var _pending_authority_partition_cells: Array[Vector3i] = []
var _pending_authority_partition_snapshot: Dictionary = {}
var _pending_authority_partition_target_kind := ProviderKind.NONE
var _pending_authority_partition_revision := -1
var _last_authority_partition_result: Dictionary = {}


func mutate_cell(
	cell: Vector3i,
	material_id: int,
	created_lineage_token: int = MatterLineageMap.NONE
) -> bool:
	# An accepted authority partition is a transaction boundary, not merely an
	# advisory intent. Until it commits or cancels, ordinary logical edits to the
	# canonical source are quarantined so the request cannot commit against a
	# different source truth than the one it classified.
	if is_authority_partition_pending():
		return false
	return super.mutate_cell(cell, material_id, created_lineage_token)


func request_authority_partition(
	selected_cells: Array[Vector3i],
	target_provider_kind: int = ProviderKind.STATIC
) -> bool:
	if is_retired() or volume == null or lineage == null or get_active_provider() == null:
		return false
	# The source is the designated canonical/static authority in W0. The target
	# may remain static for pure ownership evidence (W0A) or enter a zero-launch
	# dynamic provider immediately (W0B).
	if get_provider_kind() != ProviderKind.STATIC:
		return false
	if target_provider_kind != ProviderKind.STATIC and target_provider_kind != ProviderKind.DYNAMIC:
		return false
	if not _pending_authority_partition_cells.is_empty():
		return false
	if _pending_provider_kind != ProviderKind.NONE or _pending_connected_component_split or _pending_storage_rebase:
		return false
	if selected_cells.is_empty() or selected_cells.size() >= volume.count_solid():
		return false

	var unique: Dictionary = {}
	var snapshot: Dictionary = {}
	for cell in selected_cells:
		if unique.has(cell) or not volume.in_bounds(cell):
			return false
		var material_id: int = volume.get_cell(cell)
		var token: int = lineage.get_lineage(cell)
		if material_id == CellVolume.EMPTY or token == MatterLineageMap.NONE:
			return false
		unique[cell] = true
		snapshot[cell] = {
			"material": material_id,
			"lineage": token,
		}

	if not MatterTopology.cells_form_single_component(selected_cells):
		return false

	_pending_authority_partition_cells = selected_cells.duplicate()
	_pending_authority_partition_snapshot = snapshot
	_pending_authority_partition_target_kind = target_provider_kind
	_pending_authority_partition_revision = volume.revision
	_last_authority_partition_result = {}
	return true


func get_last_authority_partition_result() -> Dictionary:
	return _last_authority_partition_result.duplicate()


func is_authority_partition_pending() -> bool:
	return not _pending_authority_partition_cells.is_empty()


func _on_physics_frame() -> void:
	if is_retired():
		return
	if not _pending_authority_partition_cells.is_empty():
		_commit_authority_partition()
		return
	super._on_physics_frame()


func _commit_authority_partition() -> void:
	var commit_started_usec := Time.get_ticks_usec()
	# Revalidate current truth at the defended pre-step boundary. A request is
	# intent, not a lock: if selected Matter or another lifecycle transaction
	# changed before commit, fail closed without touching authority.
	var validation_started_usec := Time.get_ticks_usec()
	var request_is_current := _partition_request_is_current()
	var validation_usec := Time.get_ticks_usec() - validation_started_usec
	if not request_is_current:
		_clear_pending_authority_partition()
		_last_authority_partition_result = {}
		return

	var staging_started_usec := Time.get_ticks_usec()
	var selection := CellVolume.new(volume.size)
	var selected_lookup: Dictionary = {}
	for cell in _pending_authority_partition_cells:
		selection.set_cell(cell, volume.get_cell(cell))
		selected_lookup[cell] = true

	var compact_info: Dictionary = MatterTopology.compact_volume(selection)
	var source_origin: Vector3i = compact_info["origin"]
	var target_volume: CellVolume = compact_info["volume"]
	var target_lineage := MatterLineageMap.new(target_volume.size)
	for target_cell in _occupied_cells(target_volume):
		var source_cell := target_cell + source_origin
		var token: int = lineage.get_lineage(source_cell)
		assert(token != MatterLineageMap.NONE)
		target_lineage.set_lineage(target_cell, token)

	var source_after_volume := CellVolume.new(volume.size)
	var source_after_lineage := MatterLineageMap.new(volume.size)
	for source_cell in _occupied_cells(volume):
		if selected_lookup.has(source_cell):
			continue
		var material_id: int = volume.get_cell(source_cell)
		var token: int = lineage.get_lineage(source_cell)
		assert(token != MatterLineageMap.NONE)
		source_after_volume.set_cell(source_cell, material_id)
		source_after_lineage.set_lineage(source_cell, token)
	# This is a logical Matter ownership change, unlike storage-coordinate
	# maintenance. Preserve monotonic revision meaning without counting the clone.
	source_after_volume.revision = volume.revision + _pending_authority_partition_cells.size()

	var source_provider: Node3D = get_active_provider()
	var source_transform: Transform3D = source_provider.global_transform
	var target_transform := source_transform * Transform3D(Basis.IDENTITY, Vector3(source_origin))
	var parent_node := get_parent()
	assert(parent_node != null)
	var staging_usec := Time.get_ticks_usec() - staging_started_usec

	# Commit boundary: source keeps Space/provider identity but swaps its complete
	# authoritative Matter state in one rebuild. The staged target has not been a
	# live owner before this point.
	var source_rebuild_started_usec := Time.get_ticks_usec()
	volume = source_after_volume
	lineage = source_after_lineage
	if source_provider is MatterRepresentation:
		(source_provider as MatterRepresentation).set_volume(source_after_volume)
	elif source_provider is ConstructBody:
		(source_provider as ConstructBody).set_volume(source_after_volume)
	else:
		assert(false, "Unsupported W0 source provider")
	source_provider.reset_physics_interpolation()
	var source_rebuild_usec := Time.get_ticks_usec() - source_rebuild_started_usec

	var target_initialize_started_usec := Time.get_ticks_usec()
	var target_kind := _pending_authority_partition_target_kind
	var target := LocalMatterSpace.new()
	target.name = "%s_Extracted" % name
	_copy_runtime_configuration_to(target)
	parent_node.add_child(target)
	if target_kind == ProviderKind.STATIC:
		target.initialize_static(target_volume, target_lineage, target_transform)
	elif target_kind == ProviderKind.DYNAMIC:
		# Authority changes first; physical motion begins from the same pose with no
		# hidden launch. Gravity/contacts in the upcoming solver step are the first
		# permitted causes of new motion.
		target.initialize_dynamic(
			target_volume,
			target_lineage,
			target_transform,
			Vector3.ZERO,
			Vector3.ZERO
		)
	else:
		assert(false, "Unsupported W0 target provider kind")
	var target_initialize_usec := Time.get_ticks_usec() - target_initialize_started_usec
	var pre_signal_total_usec := Time.get_ticks_usec() - commit_started_usec

	_last_authority_partition_result = {
		"source_space": self,
		"target_space": target,
		"source_origin": source_origin,
		"source_transform": source_transform,
		"target_transform": target_transform,
		"target_provider_kind": target_kind,
		"source_cells": _pending_authority_partition_cells.duplicate(),
		"timing": {
			"validation_usec": validation_usec,
			"staging_usec": staging_usec,
			"source_rebuild_usec": source_rebuild_usec,
			"target_initialize_usec": target_initialize_usec,
			"pre_signal_total_usec": pre_signal_total_usec,
		},
	}
	_clear_pending_authority_partition()
	authority_partition_committed.emit(_last_authority_partition_result.duplicate(true))


func _partition_request_is_current() -> bool:
	if is_retired() or volume == null or lineage == null or get_active_provider() == null:
		return false
	if get_provider_kind() != ProviderKind.STATIC:
		return false
	if (
		_pending_authority_partition_target_kind != ProviderKind.STATIC
		and _pending_authority_partition_target_kind != ProviderKind.DYNAMIC
	):
		return false
	if _pending_provider_kind != ProviderKind.NONE or _pending_connected_component_split or _pending_storage_rebase:
		return false
	if _pending_authority_partition_cells.is_empty():
		return false
	# The normal mutation API is quarantined while pending. Revision equality is
	# the second line of defense: any bypass/direct state edit makes the request
	# stale and the transaction fails closed without moving authority.
	if volume.revision != _pending_authority_partition_revision:
		return false
	if _pending_authority_partition_cells.size() >= volume.count_solid():
		return false

	for cell in _pending_authority_partition_cells:
		if not volume.in_bounds(cell) or not _pending_authority_partition_snapshot.has(cell):
			return false
		var expected: Dictionary = _pending_authority_partition_snapshot[cell]
		if volume.get_cell(cell) != int(expected["material"]):
			return false
		if lineage.get_lineage(cell) != int(expected["lineage"]):
			return false
	return MatterTopology.cells_form_single_component(_pending_authority_partition_cells)


func _clear_pending_authority_partition() -> void:
	_pending_authority_partition_cells.clear()
	_pending_authority_partition_snapshot.clear()
	_pending_authority_partition_target_kind = ProviderKind.NONE
	_pending_authority_partition_revision = -1


func _occupied_cells(target_volume: CellVolume) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(target_volume.size.z):
		for y in range(target_volume.size.y):
			for x in range(target_volume.size.x):
				var cell := Vector3i(x, y, z)
				if target_volume.get_cell(cell) != CellVolume.EMPTY:
					result.append(cell)
	return result
