class_name P1MatterInteractor
extends Node3D

enum EditMode {
	REMOVE,
	PLACE,
}

enum TargetingMode {
	CENTER_RETICLE,
	POINTER,
}

signal edit_mode_changed(mode: int)
signal edit_applied(space: LocalMatterSpace, cell: Vector3i, mode: int, topology_split_queued: bool)
signal edit_timing_sample(space: LocalMatterSpace, cell: Vector3i, mode: int, topology_split_queued: bool, sample: Dictionary)
signal storage_expansion_requested(space: LocalMatterSpace, source_cell: Vector3i)
signal edit_rejected(reason: String)

@export var max_distance := 14.0
@export_flags_3d_physics var collision_mask := 1

var camera: Camera3D
var registry: P1SpaceRegistry
var pointer_blocker: Control
var mode := EditMode.REMOVE
var targeting_mode := TargetingMode.POINTER
var target_space: LocalMatterSpace
var remove_cell := Vector3i.ZERO
var place_cell := Vector3i.ZERO
var target_valid := false
var target_in_storage := false
var last_rejection := ""


func _ready() -> void:
	call_deferred("_bind_pointer_blocker_from_scene")


func set_camera(value: Camera3D) -> void:
	camera = value


func set_registry(value: P1SpaceRegistry) -> void:
	registry = value


func set_pointer_blocker(value: Control) -> void:
	pointer_blocker = value


func set_mode(value: int) -> void:
	if value != EditMode.REMOVE and value != EditMode.PLACE:
		return
	if mode == value:
		return
	mode = value
	edit_mode_changed.emit(mode)


func set_targeting_mode(value: int) -> void:
	if value != TargetingMode.CENTER_RETICLE and value != TargetingMode.POINTER:
		return
	if targeting_mode == value:
		return
	targeting_mode = value
	_clear_target()


func toggle_mode() -> void:
	set_mode(EditMode.PLACE if mode == EditMode.REMOVE else EditMode.REMOVE)


func get_mode_name() -> String:
	return "REMOVE" if mode == EditMode.REMOVE else "PLACE"


func get_target_cell() -> Vector3i:
	return remove_cell if mode == EditMode.REMOVE else place_cell


func apply_current_edit() -> bool:
	if target_space == null:
		_reject("no Matter target")
		return false
	if mode == EditMode.PLACE:
		return request_place_to_cell(target_space, place_cell)
	if not target_valid:
		_reject("no Matter target")
		return false
	return apply_edit_to_cell(target_space, remove_cell, EditMode.REMOVE)


func request_place_to_cell(space: LocalMatterSpace, cell: Vector3i) -> bool:
	if space == null or not is_instance_valid(space) or space.is_retired() or space.volume == null:
		_reject("target Space is not live")
		return false
	if space.volume.in_bounds(cell):
		return apply_edit_to_cell(space, cell, EditMode.PLACE)

	# Out-of-storage placement is not a mutation yet. The composed consumer asks
	# the Space owner to perform a bounded storage-frame maintenance transaction;
	# actual placement happens only after the new mapping is committed.
	last_rejection = ""
	storage_expansion_requested.emit(space, cell)
	return true


func apply_edit_to_cell(space: LocalMatterSpace, cell: Vector3i, edit_mode: int) -> bool:
	if space == null or not is_instance_valid(space) or space.is_retired() or space.volume == null:
		_reject("target Space is not live")
		return false
	if not space.volume.in_bounds(cell):
		_reject("target is outside current local storage")
		return false

	var edit_started_usec := Time.get_ticks_usec()
	var previous := space.volume.get_cell(cell)
	var changed := false
	var mutation_started_usec := Time.get_ticks_usec()
	if edit_mode == EditMode.REMOVE:
		if previous == CellVolume.EMPTY:
			_reject("remove target is already empty")
			return false
		changed = space.mutate_cell(cell, CellVolume.EMPTY)
	elif edit_mode == EditMode.PLACE:
		if previous != CellVolume.EMPTY:
			_reject("place target is occupied")
			return false
		# LocalMatterSpace owns fresh lineage issuance when no explicit token is
		# supplied. The interaction layer never manufactures logical identity.
		changed = space.mutate_cell(cell, CellVolume.SOLID)
	else:
		_reject("unsupported edit mode")
		return false
	var mutation_usec := Time.get_ticks_usec() - mutation_started_usec

	if not changed:
		_reject("Matter mutation was rejected")
		return false

	var topology_started_usec := Time.get_ticks_usec()
	var split_queued := false
	if edit_mode == EditMode.REMOVE and space.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC:
		if MatterTopology.extract_connected_components(space.volume).size() > 1:
			split_queued = space.request_connected_component_split()
	var topology_usec := Time.get_ticks_usec() - topology_started_usec
	var provider_rebuild_usec := _provider_last_rebuild_usec(space)

	last_rejection = ""
	var listeners_started_usec := Time.get_ticks_usec()
	edit_applied.emit(space, cell, edit_mode, split_queued)
	var listeners_usec := Time.get_ticks_usec() - listeners_started_usec
	var total_usec := Time.get_ticks_usec() - edit_started_usec
	# Observer signal is deliberately emitted after edit_applied so telemetry does
	# not contaminate the listener timing it is meant to measure.
	edit_timing_sample.emit(space, cell, edit_mode, split_queued, {
		"mutation_usec": mutation_usec,
		"topology_usec": topology_usec,
		"listeners_usec": listeners_usec,
		"total_usec": total_usec,
		"provider_rebuild_usec": provider_rebuild_usec,
	})
	return true


func _provider_last_rebuild_usec(space: LocalMatterSpace) -> int:
	if space == null or not is_instance_valid(space):
		return -1
	var provider := space.get_active_provider()
	if provider is ConstructBody:
		return (provider as ConstructBody).last_rebuild_usec
	if provider is MatterRepresentation:
		return (provider as MatterRepresentation).last_rebuild_usec
	return -1


func _process(_delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		_clear_target()
		return
	var viewport := camera.get_viewport()
	if viewport == null:
		_clear_target()
		return
	if targeting_mode == TargetingMode.POINTER:
		update_target_from_pointer_position(viewport.get_mouse_position())
	else:
		_update_target_from_screen_position(viewport.get_visible_rect().size * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p1_edit_toggle"):
		toggle_mode()
		return
	if event.is_action_pressed("p1_edit_apply"):
		apply_current_edit()


func update_target_from_pointer_position(screen_position: Vector2) -> void:
	# Pointer ownership is resolved before world targeting. The P1 HUD panel is a
	# concrete blocker, while gui_get_hovered_control covers any future visible UI
	# that owns the live mouse. Both routes clear stale world targets.
	if _screen_position_is_ui_owned(screen_position):
		_clear_target()
		return
	_update_target_from_screen_position(screen_position)


func update_target_from_screen_position(screen_position: Vector2) -> void:
	# Raw interaction-surface primitive used by bounded diagnostic/reference work.
	# Production pointer input uses update_target_from_pointer_position so UI
	# ownership is enforced before the same physical ray/cell resolver.
	_update_target_from_screen_position(screen_position)


func _update_target_from_camera() -> void:
	# Compatibility path retained for older probes and explicit baseline evidence.
	if camera == null or not is_instance_valid(camera):
		_clear_target()
		return
	var viewport := camera.get_viewport()
	if viewport == null:
		_clear_target()
		return
	_update_target_from_screen_position(viewport.get_visible_rect().size * 0.5)


func _screen_position_is_ui_owned(screen_position: Vector2) -> bool:
	if pointer_blocker != null and is_instance_valid(pointer_blocker) and pointer_blocker.is_visible_in_tree():
		if pointer_blocker.get_global_rect().has_point(screen_position):
			return true
	if camera == null or not is_instance_valid(camera):
		return false
	var viewport := camera.get_viewport()
	if viewport == null:
		return false
	var hovered_control := viewport.gui_get_hovered_control()
	return hovered_control != null and hovered_control.is_visible_in_tree()


func _bind_pointer_blocker_from_scene() -> void:
	if pointer_blocker != null and is_instance_valid(pointer_blocker):
		return
	var scene_root := get_parent()
	if scene_root == null:
		return
	pointer_blocker = scene_root.get_node_or_null("HUD/Panel") as Control


func _update_target_from_screen_position(screen_position: Vector2) -> void:
	_clear_target()
	if camera == null or registry == null or not is_instance_valid(camera):
		return
	var viewport := camera.get_viewport()
	if viewport == null:
		return
	var visible_rect := viewport.get_visible_rect()
	if not visible_rect.has_point(screen_position):
		return

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position).normalized()
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * max_distance, collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var collider := hit.get("collider") as Node
	var space := registry.find_space_for_node(collider)
	if space == null or space.get_active_provider() == null or space.volume == null:
		return
	var provider := space.get_active_provider()
	var world_position := Vector3(hit.get("position", Vector3.ZERO))
	var world_normal := Vector3(hit.get("normal", Vector3.UP)).normalized()
	var local_position := provider.to_local(world_position)
	var local_normal := provider.global_transform.basis.orthonormalized().inverse() * world_normal
	local_normal = local_normal.normalized()

	remove_cell = Vector3i(
		floori(local_position.x - local_normal.x * 0.01),
		floori(local_position.y - local_normal.y * 0.01),
		floori(local_position.z - local_normal.z * 0.01)
	)
	place_cell = Vector3i(
		floori(local_position.x + local_normal.x * 0.01),
		floori(local_position.y + local_normal.y * 0.01),
		floori(local_position.z + local_normal.z * 0.01)
	)
	target_space = space

	var cell := get_target_cell()
	target_in_storage = space.volume.in_bounds(cell)
	if mode == EditMode.REMOVE:
		target_valid = target_in_storage and space.volume.get_cell(remove_cell) != CellVolume.EMPTY
	else:
		# Placement just beyond the current dense storage edge is actionable: it
		# requests a bounded rebase before the logical edit is applied.
		target_valid = not target_in_storage or space.volume.get_cell(place_cell) == CellVolume.EMPTY


func _clear_target() -> void:
	target_valid = false
	target_in_storage = false
	target_space = null


func _reject(reason: String) -> void:
	last_rejection = reason
	edit_rejected.emit(reason)
