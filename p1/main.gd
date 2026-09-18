extends Node3D

const SPACE_SIZE := Vector3i(16, 6, 16)
const PLAYER_SPEED := 4.2
const STORAGE_REBASE_PADDING := 2
const OWNER_CENTRAL_IMPULSE := 36.0
const OWNER_TORQUE_IMPULSE := 180.0
const TEST_LINEAR_VELOCITY := Vector3(0.65, 0.0, -0.16)
const TEST_ANGULAR_VELOCITY := Vector3(0.0, 0.22, 0.0)

var _focus_space: LocalMatterSpace
var _player_speed_scale := 1.0
var _last_event := "P1 boot"
var _pending_storage_place := false
var _pending_storage_place_space: LocalMatterSpace
var _pending_storage_place_source_cell := Vector3i.ZERO
var _pending_split_actor_source: LocalMatterSpace
var _pending_split_actor_has_witness := false
var _pending_split_actor_local_center := Vector3.ZERO
var _pending_split_actor_witness_cell := Vector3i.ZERO
var _pending_split_actor_witness_token := MatterLineageMap.NONE
var _pending_split_actor_contact_local_point := Vector3.ZERO
var _pending_split_actor_contact_local_normal := Vector3.ZERO

@onready var _registry: P1SpaceRegistry = $P1SpaceRegistry
@onready var _space_control: P1SpaceControl = $P1SpaceControl
@onready var _player: SpaceQueryCharacter = $P1Player
@onready var _camera_rig: P1CameraRig = $P1CameraRig
@onready var _interactor: P1MatterInteractor = $P1MatterInteractor


func _ready() -> void:
	_ensure_input_actions()
	_registry.provider_changed.connect(_on_registry_provider_changed)
	_registry.storage_rebased.connect(_on_registry_storage_rebased)
	_registry.split_committed.connect(_on_registry_split_committed)
	_registry.active_spaces_changed.connect(_on_active_spaces_changed)
	_interactor.edit_mode_changed.connect(_on_edit_mode_changed)
	_interactor.edit_applied.connect(_on_edit_applied)
	_interactor.storage_expansion_requested.connect(_on_storage_expansion_requested)
	_interactor.edit_rejected.connect(_on_edit_rejected)
	_initialize_space()
	_camera_rig.set_target(_player)
	_interactor.set_camera(_camera_rig.get_camera())
	_interactor.set_registry(_registry)
	_refresh_camera_context()
	_recover_player_to_space("initial spawn")


func _physics_process(_delta: float) -> void:
	_update_player_intent()
	if _player.global_position.y < -12.0:
		_recover_player_to_space("automatic fall recovery")


func _process(_delta: float) -> void:
	_refresh_focus_from_player()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p1_jump"):
		_player.request_jump()
		return
	if event.is_action_pressed("p1_recover"):
		_recover_player_to_space("manual recovery")
		return
	if event.is_action_pressed("p1_camera_reset"):
		_camera_rig.reset_view()
		_last_event = "camera reset"
		return
	if event.is_action_pressed("p1_reset"):
		_reset_experiment()
		return

	# Space-control keys are discrete physical pulses. Ignore OS key-repeat so a
	# held key cannot masquerade as hidden continuous velocity control.
	if _is_echo_key_event(event):
		return
	if event.is_action_pressed("p1_space_toggle"):
		_toggle_focused_space_state()
		return
	if event.is_action_pressed("p1_space_forward_impulse"):
		_apply_focused_central_impulse(Vector3(0.0, 0.0, -OWNER_CENTRAL_IMPULSE))
		return
	if event.is_action_pressed("p1_space_back_impulse"):
		_apply_focused_central_impulse(Vector3(0.0, 0.0, OWNER_CENTRAL_IMPULSE))
		return
	if event.is_action_pressed("p1_space_yaw_left"):
		_apply_focused_torque_impulse(Vector3(0.0, OWNER_TORQUE_IMPULSE, 0.0))
		return
	if event.is_action_pressed("p1_space_yaw_right"):
		_apply_focused_torque_impulse(Vector3(0.0, -OWNER_TORQUE_IMPULSE, 0.0))
		return


func get_space() -> LocalMatterSpace:
	# Compatibility accessor for the bounded P1 foundation smoke. Internally P1
	# treats this as the current focus Space, not as a global singleton authority.
	return _focus_space


func get_active_spaces() -> Array[LocalMatterSpace]:
	return _registry.get_active_spaces()


func get_player() -> SpaceQueryCharacter:
	return _player


func get_camera_rig() -> P1CameraRig:
	return _camera_rig


func get_interactor() -> P1MatterInteractor:
	return _interactor


func get_space_control() -> P1SpaceControl:
	return _space_control


func set_player_speed_scale(scale_factor: float) -> void:
	_player_speed_scale = maxf(0.01, scale_factor)


func activate_dynamic_probe_for_test() -> bool:
	if not _is_live_space(_focus_space):
		return false
	if _focus_space.get_provider_kind() != LocalMatterSpace.ProviderKind.STATIC:
		return false
	var accepted: bool = _focus_space.request_dynamic(TEST_LINEAR_VELOCITY, TEST_ANGULAR_VELOCITY)
	if accepted:
		_last_event = "test lifecycle activation queued"
	return accepted


func freeze_static_probe_for_test() -> bool:
	if not _is_live_space(_focus_space):
		return false
	if _focus_space.get_provider_kind() != LocalMatterSpace.ProviderKind.DYNAMIC:
		return false
	var accepted: bool = _focus_space.request_static()
	if accepted:
		_last_event = "test lifecycle freeze queued"
	return accepted


func toggle_focused_space_for_test() -> bool:
	return _toggle_focused_space_state()


func apply_focused_central_impulse_for_test(local_impulse: Vector3) -> bool:
	return _apply_focused_central_impulse(local_impulse)


func apply_focused_torque_impulse_for_test(local_impulse: Vector3) -> bool:
	return _apply_focused_torque_impulse(local_impulse)


func recover_player_for_test() -> void:
	_recover_player_to_space("test recovery")


func _initialize_space() -> void:
	_clear_pending_storage_place()
	_clear_pending_split_actor_handoff()
	_registry.clear()
	for child in $Spaces.get_children():
		child.free()

	var volume := CellVolume.new(SPACE_SIZE)
	# A deliberately larger authored test deck than P0.5. P1 now subjects this
	# same authored Space to editing, storage maintenance, topology and motion.
	volume.fill_box(Vector3i(2, 0, 2), Vector3i(14, 1, 14), CellVolume.SOLID)
	volume.fill_box(Vector3i(3, 1, 4), Vector3i(4, 3, 9), CellVolume.SOLID)
	volume.fill_box(Vector3i(11, 1, 8), Vector3i(13, 2, 10), CellVolume.SOLID)
	volume.fill_box(Vector3i(7, 1, 12), Vector3i(10, 2, 13), CellVolume.SOLID)

	var lineage := MatterLineageMap.new(SPACE_SIZE)
	var issuer := MatterLineageIssuer.new(900001)
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, issuer.allocate())

	var space := LocalMatterSpace.new()
	space.name = "P1LocalMatterSpace"
	space.lineage_issuer = issuer
	space.mass_per_cell = 1.0
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.0
	space.dynamic_angular_damp = 0.0
	space.dynamic_can_sleep = false
	$Spaces.add_child(space)
	space.initialize_static(
		volume,
		lineage,
		Transform3D(Basis.IDENTITY, Vector3(-8.0, 0.0, -8.0))
	)
	_registry.register_space(space)
	_focus_space = space
	_last_event = "new logical Space initialized"


func _reset_experiment() -> void:
	_initialize_space()
	_recover_player_to_space("experiment reset")
	_camera_rig.reset_view()
	_refresh_camera_context()


func _recover_player_to_space(reason: String = "recovery") -> void:
	var target_space: LocalMatterSpace = _focus_space if _is_live_space(_focus_space) else _registry.find_nearest_space(_player.global_position)
	if not _is_live_space(target_space):
		return
	_focus_space = target_space
	var provider: Node3D = target_space.get_active_provider()
	var spawn_local: Vector3 = _find_safe_spawn_local(target_space)
	_player.global_position = provider.to_global(spawn_local)
	_player.desired_local_velocity = Vector3.ZERO
	_player.world_velocity = Vector3.ZERO
	_player.jump_requested = false
	_player.grounded = false
	_player.support_body = null
	_player.support_space = null
	_player.observed_support_velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_refresh_camera_context()
	_last_event = reason


func _find_safe_spawn_local(space: LocalMatterSpace) -> Vector3:
	if space == null or space.volume == null:
		return Vector3(0.5, 2.0, 0.5)
	var center: Vector3 = space.get_content_center_local()
	var best_cell := Vector3i.ZERO
	var best_score: float = INF
	var found := false
	for cell in _occupied_cells(space.volume):
		# Prefer high exposed cells near the Matter content center. A cell with
		# Matter immediately above it is not a useful standing surface.
		var above := cell + Vector3i.UP
		if space.volume.in_bounds(above) and space.volume.get_cell(above) != CellVolume.EMPTY:
			continue
		var horizontal: float = Vector2(float(cell.x) + 0.5 - center.x, float(cell.z) + 0.5 - center.z).length_squared()
		var score: float = horizontal - float(cell.y) * 0.12
		if score < best_score:
			best_score = score
			best_cell = cell
			found = true
	if not found:
		return center + Vector3.UP * 2.0
	return Vector3(float(best_cell.x) + 0.5, float(best_cell.y) + 1.0 + _player.height * 0.5 + 0.04, float(best_cell.z) + 0.5)


func _update_player_intent() -> void:
	var side: float = Input.get_action_strength("p1_move_right") - Input.get_action_strength("p1_move_left")
	var forward_amount: float = Input.get_action_strength("p1_move_forward") - Input.get_action_strength("p1_move_back")
	var input_axis := Vector2(side, forward_amount)
	if input_axis.length_squared() > 1.0:
		input_axis = input_axis.normalized()

	if input_axis.is_zero_approx():
		_player.desired_local_velocity = Vector3.ZERO
		return

	var desired_world: Vector3 = (
		_camera_rig.get_planar_right() * input_axis.x
		+ _camera_rig.get_planar_forward() * input_axis.y
	) * (PLAYER_SPEED * _player_speed_scale)

	if _player.grounded and _player.support_body != null and is_instance_valid(_player.support_body):
		var support_basis: Basis = _player.support_body.global_transform.basis.orthonormalized()
		_player.desired_local_velocity = support_basis.inverse() * desired_world
	else:
		_player.desired_local_velocity = desired_world

	var planar: Vector3 = desired_world
	planar.y = 0.0
	if planar.length_squared() > 0.000001:
		_player.rotation.y = atan2(-planar.x, -planar.z)


func _toggle_focused_space_state() -> bool:
	if not _is_live_space(_focus_space):
		_last_event = "Space control blocked: no live focus"
		return false
	var accepted := false
	if _focus_space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC:
		accepted = _space_control.release_space(_focus_space)
		_last_event = "Space released with zero hidden launch" if accepted else "Space release rejected"
	else:
		accepted = _space_control.freeze_space(_focus_space)
		_last_event = "Space frozen at current pose" if accepted else "Space freeze rejected"
	return accepted


func _apply_focused_central_impulse(local_impulse: Vector3) -> bool:
	if not _is_live_space(_focus_space):
		_last_event = "impulse blocked: no live focus"
		return false
	var accepted: bool = _space_control.apply_local_central_impulse(_focus_space, local_impulse)
	_last_event = "finite local impulse %s" % str(local_impulse) if accepted else "impulse blocked: release Space first"
	return accepted


func _apply_focused_torque_impulse(local_impulse: Vector3) -> bool:
	if not _is_live_space(_focus_space):
		_last_event = "torque blocked: no live focus"
		return false
	var accepted: bool = _space_control.apply_local_torque_impulse(_focus_space, local_impulse)
	_last_event = "finite local torque impulse %s" % str(local_impulse) if accepted else "torque blocked: release Space first"
	return accepted


func _on_registry_provider_changed(space: LocalMatterSpace) -> void:
	if space == _focus_space or _player.support_space == space:
		_focus_space = space
		_refresh_camera_context()
		_last_event = "provider replaced in focused Space"


func _on_registry_storage_rebased(space: LocalMatterSpace, report: Dictionary) -> void:
	var actor_rebased := false
	var local_shift: Vector3i = report["local_shift"]
	if _player.grounded and _player.support_space == space:
		actor_rebased = _player.rebase_support_local_coordinates(Vector3(local_shift))

	if space == _focus_space or _player.support_space == space:
		_focus_space = space
		_refresh_camera_context()

	if _pending_storage_place and _pending_storage_place_space == space:
		var mapped_cell: Vector3i = _pending_storage_place_source_cell + local_shift
		call_deferred("_complete_pending_storage_placement", space, mapped_cell)
		_last_event = "storage frame rebased; placement mapped%s" % ("; actor mapped" if actor_rebased else "")
		return
	_last_event = "storage frame rebased%s" % ("; actor mapped" if actor_rebased else "")


func _on_storage_expansion_requested(space: LocalMatterSpace, source_cell: Vector3i) -> void:
	if _pending_storage_place:
		_last_event = "storage expansion blocked: placement transaction already pending"
		return
	if not _is_live_space(space):
		_last_event = "storage expansion blocked: target Space is not live"
		return

	_pending_storage_place = true
	_pending_storage_place_space = space
	_pending_storage_place_source_cell = source_cell
	if not space.request_storage_rebase(source_cell, STORAGE_REBASE_PADDING):
		_clear_pending_storage_place()
		_last_event = "storage expansion request rejected"
		return
	_focus_space = space
	_last_event = "storage expansion queued for %s" % str(source_cell)


func _complete_pending_storage_placement(space: LocalMatterSpace, mapped_cell: Vector3i) -> void:
	if not _pending_storage_place or _pending_storage_place_space != space:
		return
	_clear_pending_storage_place()
	if not _is_live_space(space):
		_last_event = "mapped placement cancelled: Space retired"
		return
	var placed: bool = _interactor.apply_edit_to_cell(space, mapped_cell, P1MatterInteractor.EditMode.PLACE)
	_last_event = "storage expanded → placed %s" % str(mapped_cell) if placed else "mapped placement rejected"


func _clear_pending_storage_place() -> void:
	_pending_storage_place = false
	_pending_storage_place_space = null
	_pending_storage_place_source_cell = Vector3i.ZERO


func _on_registry_split_committed(source: LocalMatterSpace, result: LocalMatterSplitResult) -> void:
	var transferred := false
	if (
		_pending_split_actor_source == source
		and _pending_split_actor_has_witness
		and _player.grounded
		and _player.support_space == source
	):
		var mapping: Dictionary = result.map_source_local_point_for_cell(
			_pending_split_actor_witness_cell,
			_pending_split_actor_local_center
		)
		if not mapping.is_empty():
			var successor := mapping["space"] as LocalMatterSpace
			var provider: Node3D = successor.get_active_provider() if successor != null else null
			var source_origin: Vector3i = mapping["source_origin"]
			var mapped_witness_cell := _pending_split_actor_witness_cell - source_origin
			var successor_owns_witness := (
				successor != null
				and successor.lineage != null
				and successor.lineage.in_bounds(mapped_witness_cell)
				and successor.lineage.get_lineage(mapped_witness_cell) == _pending_split_actor_witness_token
			)
			if provider != null and successor_owns_witness:
				transferred = _player.transfer_support_frame_with_contact_witness(
					provider,
					mapping["local_point"],
					_pending_split_actor_contact_local_point - Vector3(source_origin),
					_pending_split_actor_contact_local_normal
				)
				if transferred:
					_focus_space = successor

	_clear_pending_split_actor_handoff()
	if _pending_storage_place and _pending_storage_place_space == source:
		_clear_pending_storage_place()
	if not transferred and source == _focus_space:
		_focus_space = _registry.find_nearest_space(_player.global_position)
	_refresh_camera_context()
	_last_event = "topology split → %d live Spaces%s" % [
		_registry.get_active_count(),
		"; actor mapped by support witness" if transferred else "",
	]


func _on_active_spaces_changed() -> void:
	if _pending_storage_place and not _is_live_space(_pending_storage_place_space):
		_clear_pending_storage_place()
	if not _is_live_space(_focus_space):
		_focus_space = _registry.find_nearest_space(_player.global_position)
	_refresh_camera_context()


func _refresh_focus_from_player() -> void:
	if _player.support_space != null and _is_live_space(_player.support_space) and _player.support_space != _focus_space:
		_focus_space = _player.support_space
		_refresh_camera_context()


func _refresh_camera_context() -> void:
	var context_space: LocalMatterSpace = _player.support_space if _is_live_space(_player.support_space) else _focus_space
	if not _is_live_space(context_space):
		context_space = _registry.find_nearest_space(_player.global_position)
	if not _is_live_space(context_space):
		_camera_rig.set_context_target(null)
		return
	_focus_space = context_space
	_camera_rig.set_context_target(
		context_space.get_active_provider(),
		context_space.get_content_center_local(),
		_space_planar_radius(context_space)
	)


func _space_planar_radius(space: LocalMatterSpace) -> float:
	if space == null or space.volume == null or space.volume.count_solid() == 0:
		return 0.0
	var center: Vector3 = space.get_content_center_local()
	var radius := 0.0
	for cell in _occupied_cells(space.volume):
		var offset := Vector2(
			float(cell.x) + 0.5 - center.x,
			float(cell.z) + 0.5 - center.z
		)
		radius = maxf(radius, offset.length() + 0.70710678)
	return radius


func _on_edit_mode_changed(_mode: int) -> void:
	_last_event = "edit mode → %s" % _interactor.get_mode_name()


func _on_edit_applied(space: LocalMatterSpace, cell: Vector3i, mode: int, split_queued: bool) -> void:
	if split_queued:
		_capture_pending_split_actor_handoff(space)
	_focus_space = space
	_refresh_camera_context()
	_last_event = "%s %s%s" % [
		"removed" if mode == P1MatterInteractor.EditMode.REMOVE else "placed",
		str(cell),
		"; topology split queued" if split_queued else "",
	]


func _capture_pending_split_actor_handoff(space: LocalMatterSpace) -> void:
	_clear_pending_split_actor_handoff()
	_pending_split_actor_source = space
	if not _player.grounded or _player.support_space != space:
		return
	var witness: Dictionary = _player.get_support_contact_witness()
	if not bool(witness.get("valid", false)):
		# The edit may have destroyed the exact Matter that was supporting the
		# actor. In that case there is deliberately no explicit successor handoff;
		# normal airborne/contact logic may reacquire something later.
		return
	if int(witness.get("space_id", 0)) != space.get_instance_id():
		return
	var witness_cell: Vector3i = witness.get("cell", Vector3i(-1, -1, -1))
	if space.lineage == null or not space.lineage.in_bounds(witness_cell):
		return
	var witness_token: int = space.lineage.get_lineage(witness_cell)
	if witness_token == MatterLineageMap.NONE:
		return

	_pending_split_actor_has_witness = true
	_pending_split_actor_local_center = _player.support_local_center
	_pending_split_actor_witness_cell = witness_cell
	_pending_split_actor_witness_token = witness_token
	_pending_split_actor_contact_local_point = witness.get("local_point", Vector3.ZERO)
	_pending_split_actor_contact_local_normal = witness.get("local_normal", Vector3.ZERO)


func _clear_pending_split_actor_handoff() -> void:
	_pending_split_actor_source = null
	_pending_split_actor_has_witness = false
	_pending_split_actor_local_center = Vector3.ZERO
	_pending_split_actor_witness_cell = Vector3i.ZERO
	_pending_split_actor_witness_token = MatterLineageMap.NONE
	_pending_split_actor_contact_local_point = Vector3.ZERO
	_pending_split_actor_contact_local_normal = Vector3.ZERO


func _on_edit_rejected(reason: String) -> void:
	_last_event = "edit blocked: %s" % reason


func _is_live_space(space: LocalMatterSpace) -> bool:
	return space != null and is_instance_valid(space) and not space.is_retired() and space.get_active_provider() != null


func _ensure_input_actions() -> void:
	# Named InputMap actions are the runtime contract. They are also persisted in
	# project.godot on this branch; this fallback keeps isolated scene/probe loads
	# robust if the scene is copied into an incomplete project during research.
	_ensure_key_action("p1_move_left", KEY_A)
	_ensure_key_action("p1_move_right", KEY_D)
	_ensure_key_action("p1_move_forward", KEY_W)
	_ensure_key_action("p1_move_back", KEY_S)
	_ensure_key_action("p1_jump", KEY_SPACE)
	_ensure_key_action("p1_recover", KEY_K)
	_ensure_key_action("p1_camera_reset", KEY_HOME)
	_ensure_key_action("p1_reset", KEY_R)
	_ensure_key_action("p1_edit_toggle", KEY_E)
	_ensure_key_action("p1_structural_seam", KEY_H)
	_ensure_key_action("p1_space_toggle", KEY_T)
	_ensure_key_action("p1_space_forward_impulse", KEY_UP)
	_ensure_key_action("p1_space_back_impulse", KEY_DOWN)
	_ensure_key_action("p1_space_yaw_left", KEY_LEFT)
	_ensure_key_action("p1_space_yaw_right", KEY_RIGHT)
	_ensure_mouse_action("p1_edit_apply", MOUSE_BUTTON_LEFT)


func _ensure_key_action(action: StringName, physical_keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, event)


func _ensure_mouse_action(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _is_echo_key_event(event: InputEvent) -> bool:
	return event is InputEventKey and (event as InputEventKey).echo


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					cells.append(cell)
	return cells
