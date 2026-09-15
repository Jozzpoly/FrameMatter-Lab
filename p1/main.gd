extends Node3D

const SPACE_SIZE := Vector3i(16, 6, 16)
const PLAYER_SPEED := 4.2
const PLAYER_SPAWN_LOCAL := Vector3(8.5, 1.93, 8.5)
const TEST_LINEAR_VELOCITY := Vector3(0.65, 0.0, -0.16)
const TEST_ANGULAR_VELOCITY := Vector3(0.0, 0.22, 0.0)

var _space: LocalMatterSpace
var _volume: CellVolume
var _lineage: MatterLineageMap
var _next_lineage_token := 900001
var _last_event := "P1 boot"

@onready var _player: SpaceQueryCharacter = $P1Player
@onready var _camera_rig: P1CameraRig = $P1CameraRig
@onready var _status_label: Label = $HUD/Panel/MarginContainer/VBoxContainer/Status
@onready var _hint_label: Label = $HUD/Panel/MarginContainer/VBoxContainer/Hint


func _ready() -> void:
	_ensure_input_actions()
	_initialize_space()
	_camera_rig.set_target(_player)
	_camera_rig.set_context_target(_space.get_active_provider())
	_recover_player_to_space()
	_update_hud()


func _physics_process(_delta: float) -> void:
	_update_player_intent()
	if _player.global_position.y < -12.0:
		_recover_player_to_space("automatic fall recovery")


func _process(_delta: float) -> void:
	_update_hud()


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


func get_space() -> LocalMatterSpace:
	return _space


func get_player() -> SpaceQueryCharacter:
	return _player


func get_camera_rig() -> P1CameraRig:
	return _camera_rig


func activate_dynamic_probe_for_test() -> bool:
	if _space == null or _space.get_provider_kind() != LocalMatterSpace.ProviderKind.STATIC:
		return false
	var accepted := _space.request_dynamic(TEST_LINEAR_VELOCITY, TEST_ANGULAR_VELOCITY)
	if accepted:
		_last_event = "test lifecycle activation queued"
	return accepted


func freeze_static_probe_for_test() -> bool:
	if _space == null or _space.get_provider_kind() != LocalMatterSpace.ProviderKind.DYNAMIC:
		return false
	var accepted := _space.request_static()
	if accepted:
		_last_event = "test lifecycle freeze queued"
	return accepted


func recover_player_for_test() -> void:
	_recover_player_to_space("test recovery")


func _initialize_space() -> void:
	if _space != null and is_instance_valid(_space):
		_space.free()

	_volume = CellVolume.new(SPACE_SIZE)
	# A deliberately larger authored test deck than P0.5. Editing remains off in
	# P1-B; P1-C will challenge storage/bounds separately instead of pretending
	# this fixed volume is already a world model.
	_volume.fill_box(Vector3i(2, 0, 2), Vector3i(14, 1, 14), CellVolume.SOLID)
	_volume.fill_box(Vector3i(3, 1, 4), Vector3i(4, 3, 9), CellVolume.SOLID)
	_volume.fill_box(Vector3i(11, 1, 8), Vector3i(13, 2, 10), CellVolume.SOLID)
	_volume.fill_box(Vector3i(7, 1, 12), Vector3i(10, 2, 13), CellVolume.SOLID)

	_lineage = MatterLineageMap.new(SPACE_SIZE)
	_next_lineage_token = 900001
	for cell in _occupied_cells(_volume):
		_lineage.set_lineage(cell, _next_lineage_token)
		_next_lineage_token += 1

	_space = LocalMatterSpace.new()
	_space.name = "P1LocalMatterSpace"
	_space.mass_per_cell = 1.0
	_space.dynamic_gravity_scale = 0.0
	_space.dynamic_linear_damp = 0.0
	_space.dynamic_angular_damp = 0.0
	_space.dynamic_can_sleep = false
	$Spaces.add_child(_space)
	_space.provider_transition_committed.connect(_on_provider_transition_committed)
	_space.initialize_static(
		_volume,
		_lineage,
		Transform3D(Basis.IDENTITY, Vector3(-8.0, 0.0, -8.0))
	)
	_last_event = "new logical Space initialized"


func _reset_experiment() -> void:
	_initialize_space()
	_camera_rig.set_context_target(_space.get_active_provider())
	_recover_player_to_space("experiment reset")
	_camera_rig.reset_view()


func _recover_player_to_space(reason: String = "initial spawn") -> void:
	if _space == null or _space.get_active_provider() == null:
		return
	var provider := _space.get_active_provider()
	_player.global_position = provider.to_global(PLAYER_SPAWN_LOCAL)
	_player.desired_local_velocity = Vector3.ZERO
	_player.world_velocity = Vector3.ZERO
	_player.jump_requested = false
	_player.grounded = false
	_player.support_body = null
	_player.support_space = null
	_player.observed_support_velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_last_event = reason


func _update_player_intent() -> void:
	var side := Input.get_action_strength("p1_move_right") - Input.get_action_strength("p1_move_left")
	var forward_amount := Input.get_action_strength("p1_move_forward") - Input.get_action_strength("p1_move_back")
	var input_axis := Vector2(side, forward_amount)
	if input_axis.length_squared() > 1.0:
		input_axis = input_axis.normalized()

	if input_axis.is_zero_approx():
		_player.desired_local_velocity = Vector3.ZERO
		return

	var desired_world := (
		_camera_rig.get_planar_right() * input_axis.x
		+ _camera_rig.get_planar_forward() * input_axis.y
	) * PLAYER_SPEED

	if _player.grounded and _player.support_body != null and is_instance_valid(_player.support_body):
		var support_basis := _player.support_body.global_transform.basis.orthonormalized()
		_player.desired_local_velocity = support_basis.inverse() * desired_world
	else:
		_player.desired_local_velocity = desired_world

	var planar := desired_world
	planar.y = 0.0
	if planar.length_squared() > 0.000001:
		_player.rotation.y = atan2(-planar.x, -planar.z)


func _on_provider_transition_committed(
	previous_provider_id: int,
	current_provider_id: int,
	provider_kind: int
) -> void:
	_camera_rig.set_context_target(_space.get_active_provider())
	_last_event = "provider %d → %d (%s)" % [
		previous_provider_id,
		current_provider_id,
		"DYNAMIC" if provider_kind == LocalMatterSpace.ProviderKind.DYNAMIC else "STATIC",
	]


func _update_hud() -> void:
	if _space == null or _space.get_active_provider() == null:
		_status_label.text = "P1 rebuild — no active Space"
		return
	var kind := "STATIC" if _space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC else "DYNAMIC"
	var support := "world"
	if _player.support_space == _space:
		support = "local Space"
	elif not _player.grounded:
		support = "airborne"
	_status_label.text = "P1 INTERACTIVE FOUNDATION   •   %s   •   actor %s   •   support %s" % [
		kind,
		"grounded" if _player.grounded else "airborne",
		support,
	]
	_hint_label.text = "WASD move   Space jump   MMB orbit   wheel zoom   Home camera   K recover   R reset\n%s" % _last_event


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


func _ensure_key_action(action: StringName, physical_keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, event)


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					cells.append(cell)
	return cells
