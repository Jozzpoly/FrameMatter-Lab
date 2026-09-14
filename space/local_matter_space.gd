class_name LocalMatterSpace
extends Node

# Experimental I0B/I1 lifecycle substrate. This is intentionally a single-Space
# owner, not a general Space manager or final persistence/data-model API.

enum ProviderKind {
	NONE,
	STATIC,
	DYNAMIC,
}

signal provider_transition_committed(previous_provider_id: int, current_provider_id: int, provider_kind: int)

var volume: CellVolume
var lineage: MatterLineageMap

var mass_per_cell := 1.0
var dynamic_gravity_scale := 0.0
var dynamic_linear_damp := 0.0
var dynamic_angular_damp := 0.0
var dynamic_can_sleep := false

var _provider_kind := ProviderKind.NONE
var _active_provider: Node3D
var _pending_provider_kind := ProviderKind.NONE
var _pending_linear_velocity := Vector3.ZERO
var _pending_angular_velocity := Vector3.ZERO
var _last_transition_report: Dictionary = {}


func initialize_static(
	new_volume: CellVolume,
	new_lineage: MatterLineageMap,
	world_transform: Transform3D
) -> void:
	assert(volume == null)
	assert(new_volume != null)
	assert(new_lineage != null)
	assert(new_lineage.size == new_volume.size)
	volume = new_volume
	lineage = new_lineage
	_active_provider = _create_static_provider(world_transform)
	_provider_kind = ProviderKind.STATIC
	set_physics_process(true)


func request_dynamic(linear_velocity: Vector3, angular_velocity: Vector3) -> bool:
	if _active_provider == null or _provider_kind == ProviderKind.DYNAMIC or _pending_provider_kind != ProviderKind.NONE:
		return false
	_pending_provider_kind = ProviderKind.DYNAMIC
	_pending_linear_velocity = linear_velocity
	_pending_angular_velocity = angular_velocity
	return true


func request_static() -> bool:
	if _active_provider == null or _provider_kind == ProviderKind.STATIC or _pending_provider_kind != ProviderKind.NONE:
		return false
	_pending_provider_kind = ProviderKind.STATIC
	return true


func mutate_cell(cell: Vector3i, material_id: int, created_lineage_token: int = MatterLineageMap.NONE) -> bool:
	assert(volume != null and lineage != null)
	if not volume.in_bounds(cell):
		return false
	var previous_material: int = volume.get_cell(cell)
	if previous_material == material_id:
		return false

	if material_id == CellVolume.EMPTY:
		volume.set_cell(cell, CellVolume.EMPTY)
		lineage.clear_lineage(cell)
	elif previous_material == CellVolume.EMPTY:
		assert(created_lineage_token != MatterLineageMap.NONE)
		volume.set_cell(cell, material_id)
		lineage.set_lineage(cell, created_lineage_token)
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


func is_transition_pending() -> bool:
	return _pending_provider_kind != ProviderKind.NONE


func _physics_process(_delta: float) -> void:
	if _pending_provider_kind == ProviderKind.NONE:
		return
	_commit_pending_transition()


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

	# Retire the old physics/render provider before installing the successor.
	# Logical Matter + lineage remain owned here and are never duplicated.
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


func _create_static_provider(world_transform: Transform3D) -> MatterRepresentation:
	var provider := MatterRepresentation.new()
	provider.name = "StaticMatterProvider"
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