extends Node3D

const SIZE := Vector3i(8, 4, 8)
const PROBE_CELL := Vector3i(3, 1, 3)
const MATERIAL_CELL := Vector3i(6, 1, 5)
const MASS_PER_CELL := 1.25
const DRIVE_LINEAR := Vector3(1.15, 0.0, -0.35)
const DRIVE_ANGULAR := Vector3(0.08, 0.34, 0.12)
const ACTOR_SPEED := 3.2
const ACTOR_SPAWN := Vector3(4.5, 2.15, 4.5)
const CAMERA_OFFSET := Vector3(8.5, 7.0, 10.0)
const EDIT_RAY_DISTANCE := 120.0
const INVALID_CELL := Vector3i(-999999, -999999, -999999)

var _space: LocalMatterSpace
var _volume: CellVolume
var _lineage: MatterLineageMap
var _actor: FrameProbeCharacter
var _actor_visual: MeshInstance3D
var _selection_marker: MeshInstance3D
var _next_lineage_token := 500001
var _last_action := "boot"
var _transition_count := 0
var _mutation_count := 0
var _selected_remove_cell := INVALID_CELL
var _selected_place_cell := INVALID_CELL
var _selected_hit_position := Vector3.ZERO
var _selected_hit_normal := Vector3.UP


func _ready() -> void:
	_ensure_interactive_nodes()
	$DirectionalLight3D.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	_reset_lab()


func _process(_delta: float) -> void:
	_update_camera()
	_refresh_pointer_selection()
	_update_hud()


func _physics_process(_delta: float) -> void:
	_update_actor_intent()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				_remove_selected_cell()
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				_place_selected_cell()
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.physical_keycode:
		KEY_SPACE:
			if _actor != null:
				_actor.request_jump()
		KEY_T:
			_toggle_provider_state()
		KEY_F:
			_freeze_to_static()
		KEY_M:
			_toggle_probe_cell()
		KEY_C:
			_cycle_retained_material()
		KEY_R:
			_reset_lab()


func _ensure_interactive_nodes() -> void:
	if _actor == null:
		_actor = FrameProbeCharacter.new()
		_actor.name = "InteractiveActor"
		_actor.gravity_acceleration = 18.0
		_actor.jump_speed = 5.8
		_actor.half_height = 0.9
		_actor.ground_probe_distance = 0.45
		add_child(_actor)

		_actor_visual = MeshInstance3D.new()
		_actor_visual.name = "ActorVisual"
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.height = 1.8
		_actor_visual.mesh = capsule
		var actor_material := StandardMaterial3D.new()
		actor_material.albedo_color = Color(0.22, 0.72, 0.95)
		actor_material.roughness = 0.55
		_actor_visual.material_override = actor_material
		_actor.add_child(_actor_visual)

	if _selection_marker == null:
		_selection_marker = MeshInstance3D.new()
		_selection_marker.name = "PointerSelectionMarker"
		var marker_mesh := SphereMesh.new()
		marker_mesh.radius = 0.09
		marker_mesh.height = 0.18
		_selection_marker.mesh = marker_mesh
		var marker_material := StandardMaterial3D.new()
		marker_material.albedo_color = Color(1.0, 0.72, 0.12)
		marker_material.roughness = 0.35
		marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_selection_marker.material_override = marker_material
		_selection_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_selection_marker.visible = false
		add_child(_selection_marker)


func _reset_lab() -> void:
	if _space != null:
		_space.free()

	_volume = CellVolume.new(SIZE)
	_volume.fill_box(Vector3i.ZERO, Vector3i(8, 1, 8), CellVolume.SOLID)
	_volume.fill_box(Vector3i(1, 1, 1), Vector3i(3, 3, 3), CellVolume.SOLID)
	_volume.fill_box(Vector3i(6, 1, 5), Vector3i(7, 4, 6), CellVolume.SOLID)
	_volume.set_cell(PROBE_CELL, CellVolume.SOLID)

	_lineage = MatterLineageMap.new(SIZE)
	_next_lineage_token = 500001
	for cell in _occupied_cells(_volume):
		_lineage.set_lineage(cell, _next_lineage_token)
		_next_lineage_token += 1

	_space = LocalMatterSpace.new()
	_space.name = "InteractiveLocalMatterSpace"
	_space.mass_per_cell = MASS_PER_CELL
	_space.dynamic_gravity_scale = 0.0
	_space.dynamic_linear_damp = 0.0
	_space.dynamic_angular_damp = 0.0
	_space.dynamic_can_sleep = false
	add_child(_space)
	_space.provider_transition_committed.connect(_on_provider_transition_committed)
	_space.initialize_static(
		_volume,
		_lineage,
		Transform3D(Basis.IDENTITY, Vector3.ZERO)
	)

	_reset_actor_state()
	_transition_count = 0
	_mutation_count = 0
	_selected_remove_cell = INVALID_CELL
	_selected_place_cell = INVALID_CELL
	if _selection_marker != null:
		_selection_marker.visible = false
	_last_action = "reset → one logical Space with static provider"
	_update_camera(true)
	_update_hud()


func _reset_actor_state() -> void:
	if _actor == null:
		return
	_actor.global_position = ACTOR_SPAWN
	_actor.desired_local_velocity = Vector3.ZERO
	_actor.world_velocity = Vector3.ZERO
	_actor.grounded = false
	_actor.support_body = null
	_actor.support_space = null
	_actor.observed_support_velocity = Vector3.ZERO
	_actor.jump_requested = false


func _update_actor_intent() -> void:
	if _actor == null:
		return

	var side: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var forward_amount: float = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var input_axis := Vector2(side, forward_amount)
	if input_axis.length_squared() > 1.0:
		input_axis = input_axis.normalized()

	if input_axis.is_zero_approx():
		_actor.desired_local_velocity = Vector3.ZERO
		return

	var camera_to_actor: Vector3 = _actor.global_position - $Camera3D.global_position
	camera_to_actor.y = 0.0
	var camera_forward: Vector3 = camera_to_actor.normalized() if camera_to_actor.length_squared() > 0.000001 else Vector3.FORWARD
	var camera_right: Vector3 = camera_forward.cross(Vector3.UP).normalized()
	var desired_world: Vector3 = (camera_right * input_axis.x + camera_forward * input_axis.y) * ACTOR_SPEED

	if _actor.grounded and _actor.support_body != null and is_instance_valid(_actor.support_body):
		var support_basis: Basis = _actor.support_body.global_transform.basis.orthonormalized()
		_actor.desired_local_velocity = support_basis.inverse() * desired_world
	else:
		# FrameProbeCharacter intentionally has no air-control model. Keep the
		# desired vector world-aligned so the first grounded frame receives a sane
		# intent without creating a parallel airborne controller in the LAB.
		_actor.desired_local_velocity = desired_world


func _update_camera(force_snap: bool = false) -> void:
	if _actor == null:
		return
	var desired_position: Vector3 = _actor.global_position + CAMERA_OFFSET
	if force_snap:
		$Camera3D.global_position = desired_position
	else:
		$Camera3D.global_position = $Camera3D.global_position.lerp(desired_position, 0.12)
	$Camera3D.look_at(_actor.global_position + Vector3.UP * 0.15, Vector3.UP)


func _refresh_pointer_selection() -> void:
	_selected_remove_cell = INVALID_CELL
	_selected_place_cell = INVALID_CELL
	if _selection_marker != null:
		_selection_marker.visible = false
	if _space == null or _space.get_active_provider() == null:
		return

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_from: Vector3 = $Camera3D.project_ray_origin(mouse_position)
	var ray_to: Vector3 = ray_from + $Camera3D.project_ray_normal(mouse_position) * EDIT_RAY_DISTANCE
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var collider: Node3D = hit["collider"] as Node3D
	var provider: Node3D = _resolve_active_provider_from_collider(collider)
	if provider == null:
		return

	var hit_position: Vector3 = Vector3(hit["position"])
	var hit_normal: Vector3 = Vector3(hit["normal"]).normalized()
	var inward_local: Vector3 = provider.to_local(hit_position - hit_normal * 0.02)
	var outward_local: Vector3 = provider.to_local(hit_position + hit_normal * 0.02)
	var remove_cell: Vector3i = _floor_to_cell(inward_local)
	var place_cell: Vector3i = _floor_to_cell(outward_local)

	if _volume.in_bounds(remove_cell) and _volume.get_cell(remove_cell) != CellVolume.EMPTY:
		_selected_remove_cell = remove_cell
	if _volume.in_bounds(place_cell) and _volume.get_cell(place_cell) == CellVolume.EMPTY:
		_selected_place_cell = place_cell

	_selected_hit_position = hit_position
	_selected_hit_normal = hit_normal
	if _selection_marker != null:
		_selection_marker.global_position = hit_position + hit_normal * 0.035
		_selection_marker.visible = true


func _remove_selected_cell() -> void:
	if _selected_remove_cell == INVALID_CELL:
		_last_action = "LMB: no removable Matter cell under pointer"
		return
	_remove_cell(_selected_remove_cell, "LMB")


func _place_selected_cell() -> void:
	if _selected_place_cell == INVALID_CELL:
		_last_action = "RMB: no empty in-bounds placement cell under pointer"
		return
	_place_cell(_selected_place_cell, "RMB")


func _remove_cell(cell: Vector3i, source: String = "edit") -> bool:
	if _space == null or not _volume.in_bounds(cell) or _volume.get_cell(cell) == CellVolume.EMPTY:
		return false
	var retired_token := _lineage.get_lineage(cell)
	if not _space.mutate_cell(cell, CellVolume.EMPTY):
		return false
	_mutation_count += 1
	_last_action = "%s: removed %s; retired lineage %d" % [source, str(cell), retired_token]
	return true


func _place_cell(cell: Vector3i, source: String = "edit") -> bool:
	if _space == null or not _volume.in_bounds(cell) or _volume.get_cell(cell) != CellVolume.EMPTY:
		return false
	var token := _next_lineage_token
	_next_lineage_token += 1
	if not _space.mutate_cell(cell, CellVolume.SOLID, token):
		return false
	_mutation_count += 1
	_last_action = "%s: placed %s with fresh lineage %d" % [source, str(cell), token]
	return true


func _resolve_active_provider_from_collider(collider: Node3D) -> Node3D:
	if collider == null or _space == null:
		return null
	var active_provider: Node3D = _space.get_active_provider()
	var current: Node = collider
	while current != null:
		if current == active_provider:
			return active_provider
		current = current.get_parent()
	return null


func _floor_to_cell(local_position: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(local_position.x)),
		int(floor(local_position.y)),
		int(floor(local_position.z))
	)


func _toggle_provider_state() -> void:
	if _space == null:
		return
	if _space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC:
		_activate_dynamic()
	elif _space.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC:
		_freeze_to_static()


func _activate_dynamic() -> void:
	if _space == null:
		return
	if _space.get_provider_kind() != LocalMatterSpace.ProviderKind.STATIC:
		_last_action = "activate ignored: Space is not static"
		return
	if _space.request_dynamic(DRIVE_LINEAR, DRIVE_ANGULAR):
		_last_action = "queued static → dynamic provider replacement"
	else:
		_last_action = "activate ignored: transition already pending"


func _freeze_to_static() -> void:
	if _space == null:
		return
	if _space.get_provider_kind() != LocalMatterSpace.ProviderKind.DYNAMIC:
		_last_action = "freeze ignored: Space is not dynamic"
		return
	if _space.request_static():
		_last_action = "queued dynamic → static provider replacement"
	else:
		_last_action = "freeze ignored: transition already pending"


func _toggle_probe_cell() -> void:
	if _space == null:
		return
	if _volume.get_cell(PROBE_CELL) == CellVolume.EMPTY:
		var token := _next_lineage_token
		_next_lineage_token += 1
		if _space.mutate_cell(PROBE_CELL, CellVolume.SOLID, token):
			_mutation_count += 1
			_last_action = "M: created probe cell with fresh lineage %d" % token
	else:
		var retired_token := _lineage.get_lineage(PROBE_CELL)
		if _space.mutate_cell(PROBE_CELL, CellVolume.EMPTY):
			_mutation_count += 1
			_last_action = "M: removed probe cell; retired lineage %d" % retired_token


func _cycle_retained_material() -> void:
	if _space == null:
		return
	var current_material := _volume.get_cell(MATERIAL_CELL)
	if current_material == CellVolume.EMPTY:
		_last_action = "C ignored: retained-material probe cell is unexpectedly empty"
		return
	var next_material := current_material + 1
	if next_material > 8:
		next_material = 2
	var retained_token := _lineage.get_lineage(MATERIAL_CELL)
	if _space.mutate_cell(MATERIAL_CELL, next_material):
		_mutation_count += 1
		_last_action = "C: material %d → %d; lineage %d retained" % [current_material, next_material, retained_token]


func _on_provider_transition_committed(previous_provider_id: int, current_provider_id: int, provider_kind: int) -> void:
	_transition_count += 1
	_last_action = (
		"transition #%d committed: provider %d → %d (%s)"
		% [_transition_count, previous_provider_id, current_provider_id, _provider_kind_name(provider_kind)]
	)


func _update_hud() -> void:
	if _space == null or _space.get_active_provider() == null:
		$HUD/Panel/Label.text = "FrameMatter P0 LAB — no active Space"
		return

	var provider := _space.get_active_provider()
	var provider_kind := _space.get_provider_kind()
	var provider_position := provider.global_position
	var provider_rotation := provider.rotation_degrees
	var collision_shapes := _provider_collision_shape_count(provider)
	var mesh_vertices := _provider_mesh_vertex_count(provider)
	var rebuild_usec := _provider_rebuild_usec(provider)
	var dynamic_line := "velocity: n/a (static provider)"
	var server_node_line := "PhysicsServer→Node gap: n/a"

	if provider is ConstructBody:
		var body := provider as ConstructBody
		dynamic_line = "linear: %s    angular: %s" % [_fmt_vec(body.linear_velocity), _fmt_vec(body.angular_velocity)]
		var server_transform := PhysicsServer3D.body_get_state(
			body.get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM
		) as Transform3D
		server_node_line = "PhysicsServer→Node position gap: %.6f" % server_transform.origin.distance_to(body.global_position)

	var transition_report := _space.get_last_transition_report()
	var transition_line := "last transition: none"
	if not transition_report.is_empty():
		transition_line = (
			"last transition providers: %d → %d    retire/install count: %d/%d"
			% [
				int(transition_report["previous_provider_id"]),
				int(transition_report["current_provider_id"]),
				int(transition_report["provider_count_after_retire"]),
				int(transition_report["provider_count_after_install"]),
			]
		)

	var actor_line := "actor: n/a"
	if _actor != null:
		actor_line = "actor grounded=%s pos=%s support_space=%s support_provider=%s" % [
			str(_actor.grounded),
			_fmt_vec(_actor.global_position),
			_instance_id_text(_actor.support_space),
			_instance_id_text(_actor.support_body),
		]

	var selection_line := "pointer remove=%s place=%s" % [
		_cell_text(_selected_remove_cell),
		_cell_text(_selected_place_cell),
	]

	$HUD/Panel/Label.text = (
		"FrameMatter P0 LAB — embodied lifecycle/edit pressure\n"
		+ "WASD move    Space jump    T activate/freeze    LMB remove    RMB place    R reset\n"
		+ "Legacy probes: M fixed-cell remove/create    C retained material    F freeze\n\n"
		+ "logical Space ID: %d    provider: %s    provider ID: %d\n" % [
			_space.get_instance_id(),
			_provider_kind_name(provider_kind),
			provider.get_instance_id(),
		]
		+ actor_line + "\n"
		+ selection_line + "\n"
		+ "transition pending: %s    transitions: %d    mutations: %d\n" % [
			str(_space.is_transition_pending()),
			_transition_count,
			_mutation_count,
		]
		+ "position: %s    rotation°: %s\n" % [_fmt_vec(provider_position), _fmt_vec(provider_rotation)]
		+ dynamic_line + "\n"
		+ server_node_line + "\n"
		+ "Matter revision: %d    occupied: %d    lineage assigned: %d\n" % [
			_volume.revision,
			_volume.count_solid(),
			_lineage.count_assigned(),
		]
		+ "probe cell: material=%d lineage=%d    retained cell: material=%d lineage=%d\n" % [
			_volume.get_cell(PROBE_CELL),
			_lineage.get_lineage(PROBE_CELL),
			_volume.get_cell(MATERIAL_CELL),
			_lineage.get_lineage(MATERIAL_CELL),
		]
		+ "derived collision shapes: %d    mesh vertices: %d    rebuild: %d us\n" % [
			collision_shapes,
			mesh_vertices,
			rebuild_usec,
		]
		+ transition_line + "\n"
		+ "last action: " + _last_action
	)


func _provider_kind_name(provider_kind: int) -> String:
	match provider_kind:
		LocalMatterSpace.ProviderKind.STATIC:
			return "STATIC / MatterRepresentation"
		LocalMatterSpace.ProviderKind.DYNAMIC:
			return "DYNAMIC / ConstructBody"
		_:
			return "NONE"


func _provider_collision_shape_count(provider: Node3D) -> int:
	if provider is MatterRepresentation:
		return (provider as MatterRepresentation).get_collision_shape_count()
	if provider is ConstructBody:
		return (provider as ConstructBody).get_collision_shape_count()
	return 0


func _provider_mesh_vertex_count(provider: Node3D) -> int:
	if provider is MatterRepresentation:
		return (provider as MatterRepresentation).get_mesh_vertex_count()
	if provider is ConstructBody:
		return (provider as ConstructBody).get_mesh_vertex_count()
	return 0


func _provider_rebuild_usec(provider: Node3D) -> int:
	if provider is MatterRepresentation:
		return (provider as MatterRepresentation).last_rebuild_usec
	if provider is ConstructBody:
		return (provider as ConstructBody).last_rebuild_usec
	return 0


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					cells.append(cell)
	return cells


func _instance_id_text(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "none"
	return str(node.get_instance_id())


func _cell_text(cell: Vector3i) -> String:
	return "none" if cell == INVALID_CELL else str(cell)


func _fmt_vec(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
