class_name P1SpaceControl
extends Node

# Bounded P1 control challenger. It makes motion causality explicit without
# introducing a vehicle framework: release changes representation state with
# zero launch velocity; subsequent movement comes from finite rigid impulses.

signal release_requested(space: LocalMatterSpace)
signal freeze_requested(space: LocalMatterSpace)
signal impulse_applied(space: LocalMatterSpace, world_impulse: Vector3)
signal torque_impulse_applied(space: LocalMatterSpace, world_impulse: Vector3)
signal control_rejected(reason: String)


func release_space(space: LocalMatterSpace) -> bool:
	if not _is_live_space(space):
		return _reject("Space is not live")
	if space.get_provider_kind() != LocalMatterSpace.ProviderKind.STATIC:
		return _reject("Space is not static")
	if not space.request_dynamic(Vector3.ZERO, Vector3.ZERO):
		return _reject("dynamic release request rejected")
	release_requested.emit(space)
	return true


func freeze_space(space: LocalMatterSpace) -> bool:
	if not _is_live_space(space):
		return _reject("Space is not live")
	if space.get_provider_kind() != LocalMatterSpace.ProviderKind.DYNAMIC:
		return _reject("Space is not dynamic")
	if not space.request_static():
		return _reject("static freeze request rejected")
	freeze_requested.emit(space)
	return true


func apply_local_central_impulse(space: LocalMatterSpace, local_impulse: Vector3) -> bool:
	var body := _get_dynamic_body(space)
	if body == null:
		return _reject("central impulse requires a live dynamic Space")
	var world_impulse := body.global_transform.basis.orthonormalized() * local_impulse
	body.apply_central_impulse(world_impulse)
	impulse_applied.emit(space, world_impulse)
	return true


func apply_local_torque_impulse(space: LocalMatterSpace, local_impulse: Vector3) -> bool:
	var body := _get_dynamic_body(space)
	if body == null:
		return _reject("torque impulse requires a live dynamic Space")
	var world_impulse := body.global_transform.basis.orthonormalized() * local_impulse
	body.apply_torque_impulse(world_impulse)
	torque_impulse_applied.emit(space, world_impulse)
	return true


func _get_dynamic_body(space: LocalMatterSpace) -> ConstructBody:
	if not _is_live_space(space):
		return null
	if space.get_provider_kind() != LocalMatterSpace.ProviderKind.DYNAMIC:
		return null
	return space.get_active_provider() as ConstructBody


func _is_live_space(space: LocalMatterSpace) -> bool:
	return space != null and is_instance_valid(space) and not space.is_retired() and space.get_active_provider() != null


func _reject(reason: String) -> bool:
	control_rejected.emit(reason)
	return false
