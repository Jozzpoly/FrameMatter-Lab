class_name LocalMatterSpace
extends Node

# Experimental integrated lifecycle substrate. This is intentionally a local
# single-Space owner, not a general Space manager or final persistence model.

const MAX_EXPANDED_STORAGE_CELLS := 262144

enum ProviderKind {
	NONE,
	STATIC,
	DYNAMIC,
}

signal provider_transition_committed(previous_provider_id: int, current_provider_id: int, provider_kind: int)
signal topology_split_committed(result)
signal storage_rebase_committed(report: Dictionary)

var volume: CellVolume
var lineage: MatterLineageMap
var lineage_issuer: MatterLineageIssuer

var mass_per_cell := 1.0
var collision_mode := CellCollisionBoxer.Mode.MERGED_CUBOIDS
var dynamic_gravity_scale := 0.0
var dynamic_linear_damp := 0.0
var dynamic_angular_damp := 0.0
var dynamic_can_sleep := false

var _provider_kind := ProviderKind.NONE
var _active_provider: Node3D
var _pending_provider_kind := ProviderKind.NONE
var _pending_linear_velocity := Vector3.ZERO
var _pending_angular_velocity := Vector3.ZERO
var _pending_connected_component_split := false
var _pending_storage_rebase := false
var _pending_storage_cell := Vector3i.ZERO
var _pending_storage_padding := 0
var _last_transition_report: Dictionary = {}
var _last_storage_rebase_report: Dictionary = {}
var _last_split_result: LocalMatterSplitResult
var _physics_boundary_connected := false
var _retired := false


func initialize_static(
	new_volume: CellVolume,
	new_lineage: MatterLineageMap,
	world_transform: Transform3D
) -> void:
	_initialize_authority(new_volume, new_lineage)
	_active_provider = _create_static_provider(world_transform)
	_provider_kind = ProviderKind.STATIC
	_connect_physics_boundary()


func initialize_dynamic(
	new_volume: CellVolume,
	new_lineage: MatterLineageMap,
	world_transform: Transform3D,
	linear_velocity: Vector3,
	angular_velocity: Vector3
) -> void:
	_initialize_authority(new_volume, new_lineage)
	_active_provider = _create_dynamic_provider(world_transform, linear_velocity, angular_velocity)
	_provider_kind = ProviderKind.DYNAMIC
	_connect_physics_boundary()


func request_dynamic(linear_velocity: Vector3, angular_velocity: Vector3) -> bool:
	if _retired or _active_provider == null:
		return false
	if (
		_provider_kind == ProviderKind.DYNAMIC
		or _pending_provider_kind != ProviderKind.NONE
		or _pending_connected_component_split
		or _pending_storage_rebase
	):
		return false
	_pending_provider_kind = ProviderKind.DYNAMIC
	_pending_linear_velocity = linear_velocity
	_pending_angular_velocity = angular_velocity
	return true


func request_static() -> bool:
	if _retired or _active_provider == null:
		return false
	if (
		_provider_kind == ProviderKind.STATIC
		or _pending_provider_kind != ProviderKind.NONE
		or _pending_connected_component_split
		or _pending_storage_rebase
	):
		return false
	_pending_provider_kind = ProviderKind.STATIC
	return true


func request_connected_component_split() -> bool:
	if _retired or _active_provider == null or not (_active_provider is ConstructBody):
		return false
	if (
		_provider_kind != ProviderKind.DYNAMIC
		or _pending_provider_kind != ProviderKind.NONE
		or _pending_connected_component_split
		or _pending_storage_rebase
	):
		return false
	if MatterTopology.extract_connected_components(volume).size() <= 1:
		return false
	_pending_connected_component_split = true
	return true


func request_storage_rebase(local_cell: Vector3i, padding: int = 2) -> bool:
	if _retired or volume == null or lineage == null or _active_provider == null:
		return false
	if volume.in_bounds(local_cell):
		return false
	if (
		_pending_provider_kind != ProviderKind.NONE
		or _pending_connected_component_split
		or _pending_storage_rebase
	):
		return false
	var expansion: Dictionary = _compute_storage_expansion(local_cell, padding)
	if expansion.is_empty():
		return false
	_pending_storage_rebase = true
	_pending_storage_cell = local_cell
	_pending_storage_padding = maxi(0, padding)
	return true


func allocate_lineage_token() -> int:
	if _retired or lineage_issuer == null:
		return MatterLineageMap.NONE
	return lineage_issuer.allocate()


func mutate_cell(cell: Vector3i, material_id: int, created_lineage_token: int = MatterLineageMap.NONE) -> bool:
	if _retired or volume == null or lineage == null or _active_provider == null:
		return false
	if _pending_connected_component_split or _pending_storage_rebase:
		return false
	if not volume.in_bounds(cell):
		return false
	var previous_material: int = volume.get_cell(cell)
	if previous_material == material_id:
		return false

	if material_id == CellVolume.EMPTY:
		volume.set_cell(cell, CellVolume.EMPTY)
		lineage.clear_lineage(cell)
	elif previous_material == CellVolume.EMPTY:
		var lineage_token: int = created_lineage_token
		if lineage_token == MatterLineageMap.NONE:
			lineage_token = allocate_lineage_token()
		assert(lineage_token != MatterLineageMap.NONE)
		volume.set_cell(cell, material_id)
		lineage.set_lineage(cell, lineage_token)
	else:
		# Material mutation retains logical Matter lineage.
		volume.set_cell(cell, material_id)

	_rebuild_active_provider()
	return true


func get_active_provider() -> Node3D:
	return _active_provider


func get_provider_kind() -> int:
	return _provider_kind


func get_provider_node_count() -> int:
	var count := 0
	for child in get_children():
		if child is MatterRepresentation or child is ConstructBody:
			count += 1
	return count


func get_last_transition_report() -> Dictionary:
	return _last_transition_report.duplicate(true)


func get_last_storage_rebase_report() -> Dictionary:
	return _last_storage_rebase_report.duplicate(true)


func get_last_split_result() -> LocalMatterSplitResult:
	return _last_split_result


func get_content_center_local() -> Vector3:
	if _retired or volume == null or volume.count_solid() == 0:
		return Vector3.ZERO
	return MatterTopology.center_of_mass_local(volume)


func is_transition_pending() -> bool:
	return _pending_provider_kind != ProviderKind.NONE


func is_topology_split_pending() -> bool:
	return _pending_connected_component_split


func is_storage_rebase_pending() -> bool:
	return _pending_storage_rebase


func is_retired() -> bool:
	return _retired


func _initialize_authority(new_volume: CellVolume, new_lineage: MatterLineageMap) -> void:
	assert(not _retired)
	assert(volume == null)
	assert(new_volume != null)
	assert(new_lineage != null)
	assert(new_lineage.size == new_volume.size)
	volume = new_volume
	lineage = new_lineage
	if lineage_issuer == null:
		lineage_issuer = MatterLineageIssuer.new()
	lineage_issuer.absorb_existing(lineage)


func _connect_physics_boundary() -> void:
	if _physics_boundary_connected:
		return
	var tree := get_tree()
	assert(tree != null)
	var callback := Callable(self, "_on_physics_frame")
	if not tree.physics_frame.is_connected(callback):
		tree.physics_frame.connect(callback)
	_physics_boundary_connected = true


func _on_physics_frame() -> void:
	# SceneTree.physics_frame is emitted after PhysicsServer sync but before node
	# _physics_process callbacks and before the upcoming PhysicsServer step.
	if _retired:
		return
	if _pending_connected_component_split:
		_commit_connected_component_split()
		return
	if _pending_storage_rebase:
		_commit_storage_rebase()
		return
	if _pending_provider_kind != ProviderKind.NONE:
		_commit_pending_transition()


func _commit_storage_rebase() -> void:
	assert(_active_provider != null)
	assert(volume != null and lineage != null)
	var expansion: Dictionary = _compute_storage_expansion(_pending_storage_cell, _pending_storage_padding)
	assert(not expansion.is_empty())

	var local_shift: Vector3i = expansion["local_shift"]
	var previous_size: Vector3i = volume.size
	var previous_volume: CellVolume = volume
	var previous_lineage: MatterLineageMap = lineage
	var previous_revision: int = previous_volume.revision
	var new_size: Vector3i = expansion["current_size"]
	var new_volume := CellVolume.new(new_size)
	var new_lineage := MatterLineageMap.new(new_size)

	for z in range(previous_size.z):
		for y in range(previous_size.y):
			for x in range(previous_size.x):
				var old_cell := Vector3i(x, y, z)
				var material_id: int = previous_volume.get_cell(old_cell)
				if material_id == CellVolume.EMPTY:
					continue
				var mapped_cell := old_cell + local_shift
				new_volume.set_cell(mapped_cell, material_id)
				var token: int = previous_lineage.get_lineage(old_cell)
				assert(token != MatterLineageMap.NONE)
				new_lineage.set_lineage(mapped_cell, token)
	# Coordinate-frame maintenance is not a logical Matter edit.
	new_volume.revision = previous_revision

	var provider: Node3D = _active_provider
	var provider_id: int = provider.get_instance_id()
	var previous_transform: Transform3D = provider.global_transform
	var rebased_transform := previous_transform * Transform3D(Basis.IDENTITY, -Vector3(local_shift))
	var preserved_linear := Vector3.ZERO
	var preserved_angular := Vector3.ZERO
	if provider is ConstructBody:
		preserved_linear = provider.linear_velocity
		preserved_angular = provider.angular_velocity

	volume = new_volume
	lineage = new_lineage
	provider.global_transform = rebased_transform
	if provider is MatterRepresentation:
		(provider as MatterRepresentation).set_volume(new_volume)
	elif provider is ConstructBody:
		var body := provider as ConstructBody
		body.set_volume(new_volume)
		body.linear_velocity = preserved_linear
		body.angular_velocity = preserved_angular
	else:
		assert(false, "Unsupported active Matter provider")
	provider.reset_physics_interpolation()

	_last_storage_rebase_report = {
		"requested_source_cell": _pending_storage_cell,
		"mapped_cell": _pending_storage_cell + local_shift,
		"local_shift": local_shift,
		"previous_size": previous_size,
		"current_size": new_size,
		"previous_transform": previous_transform,
		"current_transform": rebased_transform,
		"provider_id": provider_id,
	}
	_pending_storage_rebase = false
	_pending_storage_cell = Vector3i.ZERO
	_pending_storage_padding = 0
	storage_rebase_committed.emit(_last_storage_rebase_report.duplicate(true))


func _compute_storage_expansion(local_cell: Vector3i, padding: int) -> Dictionary:
	if volume == null or volume.in_bounds(local_cell):
		return {}
	var grow: int = maxi(0, padding)
	var min_coord := Vector3i.ZERO
	var max_exclusive: Vector3i = volume.size
	if local_cell.x < 0:
		min_coord.x = local_cell.x - grow
	elif local_cell.x >= volume.size.x:
		max_exclusive.x = local_cell.x + 1 + grow
	if local_cell.y < 0:
		min_coord.y = local_cell.y - grow
	elif local_cell.y >= volume.size.y:
		max_exclusive.y = local_cell.y + 1 + grow
	if local_cell.z < 0:
		min_coord.z = local_cell.z - grow
	elif local_cell.z >= volume.size.z:
		max_exclusive.z = local_cell.z + 1 + grow
	var new_size: Vector3i = max_exclusive - min_coord
	var new_cell_count: int = new_size.x * new_size.y * new_size.z
	if new_cell_count <= 0 or new_cell_count > MAX_EXPANDED_STORAGE_CELLS:
		return {}
	var local_shift: Vector3i = -min_coord
	return {
		"requested_source_cell": local_cell,
		"mapped_cell": local_cell + local_shift,
		"local_shift": local_shift,
		"previous_size": volume.size,
		"current_size": new_size,
	}


func _commit_pending_transition() -> void:
	assert(_active_provider != null)
	var target_kind := _pending_provider_kind
	var previous_provider := _active_provider
	var previous_kind := _provider_kind
	var previous_id := previous_provider.get_instance_id()
	var previous_transform := previous_provider.global_transform
	var previous_linear := Vector3.ZERO
	var previous_angular := Vector3.ZERO
	if previous_provider is ConstructBody:
		previous_linear = previous_provider.linear_velocity
		previous_angular = previous_provider.angular_velocity

	previous_provider.free()
	_active_provider = null
	_provider_kind = ProviderKind.NONE
	var provider_count_after_retire := get_provider_node_count()

	if target_kind == ProviderKind.DYNAMIC:
		_active_provider = _create_dynamic_provider(
			previous_transform,
			_pending_linear_velocity,
			_pending_angular_velocity
		)
	elif target_kind == ProviderKind.STATIC:
		_active_provider = _create_static_provider(previous_transform)
	else:
		assert(false, "Unsupported provider transition target")

	_provider_kind = target_kind
	var provider_count_after_install := get_provider_node_count()
	var current_id := _active_provider.get_instance_id()
	var current_transform := _active_provider.global_transform
	_last_transition_report = {
		"previous_kind": previous_kind,
		"current_kind": target_kind,
		"previous_provider_id": previous_id,
		"current_provider_id": current_id,
		"previous_transform": previous_transform,
		"current_transform": current_transform,
		"previous_linear_velocity": previous_linear,
		"previous_angular_velocity": previous_angular,
		"provider_count_after_retire": provider_count_after_retire,
		"provider_count_after_install": provider_count_after_install,
	}

	_pending_provider_kind = ProviderKind.NONE
	_pending_linear_velocity = Vector3.ZERO
	_pending_angular_velocity = Vector3.ZERO
	provider_transition_committed.emit(previous_id, current_id, target_kind)


func _commit_connected_component_split() -> void:
	assert(_active_provider is ConstructBody)
	var source_body := _active_provider as ConstructBody
	var components: Array[CellVolume] = MatterTopology.extract_connected_components(volume)
	assert(components.size() > 1)

	var source_provider_id := source_body.get_instance_id()
	var source_transform := source_body.global_transform
	var source_linear := source_body.linear_velocity
	var source_angular := source_body.angular_velocity
	var source_com_world := source_transform * source_body.matter_center_of_mass_local
	var parent_node := get_parent()
	assert(parent_node != null)

	var successor_specs: Array = []
	for component in components:
		var compact_info: Dictionary = MatterTopology.compact_volume(component)
		var source_origin: Vector3i = compact_info["origin"]
		var compact_volume: CellVolume = compact_info["volume"]
		var compact_lineage := _compact_lineage(component, source_origin, compact_volume.size)
		var successor_transform := source_transform * Transform3D(Basis.IDENTITY, Vector3(source_origin))
		var successor_com_local := MatterTopology.center_of_mass_local(compact_volume)
		var successor_com_world := successor_transform * successor_com_local
		var inherited_linear := _velocity_at_point(
			source_linear,
			source_angular,
			source_com_world,
			successor_com_world
		)
		successor_specs.append({
			"component": component,
			"source_origin": source_origin,
			"volume": compact_volume,
			"lineage": compact_lineage,
			"transform": successor_transform,
			"linear_velocity": inherited_linear,
			"angular_velocity": source_angular,
		})

	var result := LocalMatterSplitResult.new()
	result.source_space = self
	result.source_provider_id = source_provider_id
	result.source_transform = source_transform
	result.source_linear_velocity = source_linear
	result.source_angular_velocity = source_angular
	result.source_com_world = source_com_world

	source_body.free()
	_active_provider = null
	_provider_kind = ProviderKind.NONE
	_pending_connected_component_split = false
	_retired = true
	assert(get_provider_node_count() == 0)

	for index in range(successor_specs.size()):
		var spec: Dictionary = successor_specs[index]
		var successor := LocalMatterSpace.new()
		successor.name = "%s_Successor_%d" % [name, index]
		_copy_runtime_configuration_to(successor)
		parent_node.add_child(successor)
		successor.initialize_dynamic(
			spec["volume"],
			spec["lineage"],
			spec["transform"],
			spec["linear_velocity"],
			spec["angular_velocity"]
		)
		result.successors.append(successor)
		result.source_origins.append(spec["source_origin"])
		result.source_components.append(spec["component"])

	volume = null
	lineage = null
	_last_split_result = result
	topology_split_committed.emit(result)


func _compact_lineage(component: CellVolume, source_origin: Vector3i, compact_size: Vector3i) -> MatterLineageMap:
	var compact_lineage := MatterLineageMap.new(compact_size)
	for z in range(component.size.z):
		for y in range(component.size.y):
			for x in range(component.size.x):
				var source_cell := Vector3i(x, y, z)
				if component.get_cell(source_cell) == CellVolume.EMPTY:
					continue
				var lineage_token := lineage.get_lineage(source_cell)
				assert(lineage_token != MatterLineageMap.NONE)
				compact_lineage.set_lineage(source_cell - source_origin, lineage_token)
	return compact_lineage


func _copy_runtime_configuration_to(successor: LocalMatterSpace) -> void:
	successor.lineage_issuer = lineage_issuer
	successor.mass_per_cell = mass_per_cell
	successor.collision_mode = collision_mode
	successor.dynamic_gravity_scale = dynamic_gravity_scale
	successor.dynamic_linear_damp = dynamic_linear_damp
	successor.dynamic_angular_damp = dynamic_angular_damp
	successor.dynamic_can_sleep = dynamic_can_sleep


func _velocity_at_point(
	linear_velocity: Vector3,
	angular_velocity: Vector3,
	com_world: Vector3,
	point_world: Vector3
) -> Vector3:
	return linear_velocity + angular_velocity.cross(point_world - com_world)


func _create_static_provider(world_transform: Transform3D) -> MatterRepresentation:
	var provider := MatterRepresentation.new()
	provider.name = "StaticMatterProvider"
	provider.collision_mode = collision_mode
	add_child(provider)
	provider.global_transform = world_transform
	provider.set_volume(volume)
	return provider


func _create_dynamic_provider(
	world_transform: Transform3D,
	linear_velocity: Vector3,
	angular_velocity: Vector3
) -> ConstructBody:
	var provider := ConstructBody.new()
	provider.name = "DynamicMatterProvider"
	provider.gravity_scale = dynamic_gravity_scale
	provider.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	provider.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	provider.linear_damp = dynamic_linear_damp
	provider.angular_damp = dynamic_angular_damp
	provider.can_sleep = dynamic_can_sleep
	provider.mass_per_cell = mass_per_cell
	provider.collision_mode = collision_mode
	add_child(provider)
	provider.global_transform = world_transform
	provider.set_volume(volume)
	provider.linear_velocity = linear_velocity
	provider.angular_velocity = angular_velocity
	return provider


func _rebuild_active_provider() -> void:
	assert(_active_provider != null)
	if _active_provider is MatterRepresentation:
		(_active_provider as MatterRepresentation).rebuild()
	elif _active_provider is ConstructBody:
		(_active_provider as ConstructBody).rebuild_derived()
	else:
		assert(false, "Unsupported active Matter provider")
