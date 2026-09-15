extends "res://lab/main.gd"

# P0.5 deliberately stays above the defended Matter/lifecycle substrate.
# This layer exists to make the same P0 consumer readable and comfortable enough
# that Owner testing can pressure the system instead of mainly pressure the UI.

const CAMERA_DEFAULT_YAW := 0.78
const CAMERA_DEFAULT_PITCH := 0.52
const CAMERA_DEFAULT_DISTANCE := 8.2
const CAMERA_MIN_DISTANCE := 4.2
const CAMERA_MAX_DISTANCE := 14.0
const CAMERA_ORBIT_SENSITIVITY := 0.008
const CAMERA_ZOOM_STEP := 0.8
const CAMERA_FOCUS_HEIGHT := 0.72
const GRID_ALPHA := 0.34

var _camera_yaw := CAMERA_DEFAULT_YAW
var _camera_pitch := CAMERA_DEFAULT_PITCH
var _camera_distance := CAMERA_DEFAULT_DISTANCE
var _camera_orbiting := false

var _compact_panel: PanelContainer
var _compact_label: Label
var _remove_preview: MeshInstance3D
var _place_preview: MeshInstance3D
var _matter_grid: MeshInstance3D
var _p05_environment: WorldEnvironment
var _matter_static_material: StandardMaterial3D
var _matter_dynamic_material: StandardMaterial3D
var _last_styled_provider_id := 0


func _ready() -> void:
	super._ready()
	_setup_p05_presentation()
	_rebuild_matter_grid()
	_set_debug_visible(false)
	_update_camera(true)
	_update_hud()


func _process(_delta: float) -> void:
	_update_camera()
	_refresh_pointer_selection()
	_sync_p05_visuals()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _camera_orbiting:
			var motion := event as InputEventMouseMotion
			_camera_yaw -= motion.relative.x * CAMERA_ORBIT_SENSITIVITY
			_camera_pitch = clampf(
				_camera_pitch - motion.relative.y * CAMERA_ORBIT_SENSITIVITY,
				0.18,
				1.20
			)
			return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_camera_orbiting = mouse_event.pressed
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_camera_zoom(-CAMERA_ZOOM_STEP)
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_camera_zoom(CAMERA_ZOOM_STEP)
			return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				_set_debug_visible(not $HUD/Panel.visible)
				return
			KEY_K:
				_recover_actor()
				return
			KEY_HOME:
				_reset_camera_view()
				return

	super._unhandled_input(event)


func _setup_p05_presentation() -> void:
	_setup_environment()
	_setup_compact_hud()
	_setup_selection_previews()
	_setup_matter_grid()
	_setup_lab_materials()

	$Camera3D.fov = 62.0
	$Camera3D.near = 0.05

	if _actor_visual != null and _actor_visual.material_override is StandardMaterial3D:
		var actor_material := _actor_visual.material_override as StandardMaterial3D
		actor_material.albedo_color = Color(0.10, 0.72, 1.0)
		actor_material.emission_enabled = true
		actor_material.emission = Color(0.03, 0.22, 0.36)
		actor_material.emission_energy_multiplier = 0.75

	if _selection_marker != null and _selection_marker.material_override is StandardMaterial3D:
		var marker_material := _selection_marker.material_override as StandardMaterial3D
		marker_material.albedo_color = Color(1.0, 0.86, 0.18)
		marker_material.emission_enabled = true
		marker_material.emission = Color(0.6, 0.32, 0.03)
		marker_material.emission_energy_multiplier = 1.25


func _setup_environment() -> void:
	_p05_environment = get_node_or_null("P05Environment") as WorldEnvironment
	if _p05_environment == null:
		_p05_environment = WorldEnvironment.new()
		_p05_environment.name = "P05Environment"
		add_child(_p05_environment)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.035, 0.055)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.57, 0.72)
	environment.ambient_light_energy = 0.52
	_p05_environment.environment = environment


func _setup_compact_hud() -> void:
	_compact_panel = $HUD.get_node_or_null("CompactPanel") as PanelContainer
	if _compact_panel == null:
		_compact_panel = PanelContainer.new()
		_compact_panel.name = "CompactPanel"
		_compact_panel.offset_left = 18.0
		_compact_panel.offset_top = 18.0
		_compact_panel.offset_right = 890.0
		_compact_panel.offset_bottom = 154.0
		$HUD.add_child(_compact_panel)

		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.018, 0.026, 0.042, 0.88)
		panel_style.border_color = Color(0.23, 0.42, 0.60, 0.65)
		panel_style.set_border_width_all(1)
		panel_style.set_corner_radius_all(7)
		panel_style.content_margin_left = 14.0
		panel_style.content_margin_right = 14.0
		panel_style.content_margin_top = 10.0
		panel_style.content_margin_bottom = 10.0
		_compact_panel.add_theme_stylebox_override("panel", panel_style)

		_compact_label = Label.new()
		_compact_label.name = "Label"
		_compact_label.add_theme_font_size_override("font_size", 15)
		_compact_panel.add_child(_compact_label)
	else:
		_compact_label = _compact_panel.get_node_or_null("Label") as Label

	var debug_panel := $HUD/Panel as Panel
	var debug_style := StyleBoxFlat.new()
	debug_style.bg_color = Color(0.012, 0.018, 0.030, 0.94)
	debug_style.border_color = Color(0.28, 0.50, 0.70, 0.72)
	debug_style.set_border_width_all(1)
	debug_style.set_corner_radius_all(7)
	debug_panel.add_theme_stylebox_override("panel", debug_style)


func _setup_selection_previews() -> void:
	_remove_preview = _make_cell_preview(
		"RemoveCellPreview",
		Color(1.0, 0.20, 0.10, 0.24),
		Vector3.ONE * 1.035
	)
	_place_preview = _make_cell_preview(
		"PlaceCellPreview",
		Color(0.18, 0.92, 0.62, 0.28),
		Vector3.ONE * 0.94
	)


func _make_cell_preview(node_name: String, color: Color, size: Vector3) -> MeshInstance3D:
	var preview := get_node_or_null(node_name) as MeshInstance3D
	if preview != null:
		return preview

	preview = MeshInstance3D.new()
	preview.name = node_name
	var box := BoxMesh.new()
	box.size = size
	preview.mesh = box

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	preview.material_override = material
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.visible = false
	add_child(preview)
	return preview


func _setup_matter_grid() -> void:
	_matter_grid = get_node_or_null("MatterCellGrid") as MeshInstance3D
	if _matter_grid == null:
		_matter_grid = MeshInstance3D.new()
		_matter_grid.name = "MatterCellGrid"
		_matter_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_matter_grid)

	var grid_material := StandardMaterial3D.new()
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.albedo_color = Color(0.06, 0.12, 0.18, GRID_ALPHA)
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_matter_grid.material_override = grid_material


func _setup_lab_materials() -> void:
	_matter_static_material = StandardMaterial3D.new()
	_matter_static_material.albedo_color = Color(0.46, 0.59, 0.76)
	_matter_static_material.roughness = 0.82

	_matter_dynamic_material = StandardMaterial3D.new()
	_matter_dynamic_material.albedo_color = Color(0.30, 0.66, 0.88)
	_matter_dynamic_material.roughness = 0.70
	_matter_dynamic_material.metallic = 0.06

	_last_styled_provider_id = 0
	_refresh_provider_visual_style()


func _update_camera(force_snap: bool = false) -> void:
	if _actor == null:
		return

	var target := _actor.global_position + Vector3.UP * CAMERA_FOCUS_HEIGHT
	var horizontal := cos(_camera_pitch) * _camera_distance
	var offset := Vector3(
		sin(_camera_yaw) * horizontal,
		sin(_camera_pitch) * _camera_distance,
		cos(_camera_yaw) * horizontal
	)
	var desired_position := target + offset

	if force_snap:
		$Camera3D.global_position = desired_position
	else:
		$Camera3D.global_position = $Camera3D.global_position.lerp(desired_position, 0.18)
	$Camera3D.look_at(target, Vector3.UP)


func _adjust_camera_zoom(delta_distance: float) -> void:
	_camera_distance = clampf(
		_camera_distance + delta_distance,
		CAMERA_MIN_DISTANCE,
		CAMERA_MAX_DISTANCE
	)


func _reset_camera_view() -> void:
	_camera_yaw = CAMERA_DEFAULT_YAW
	_camera_pitch = CAMERA_DEFAULT_PITCH
	_camera_distance = CAMERA_DEFAULT_DISTANCE
	_update_camera(true)
	_last_action = "camera view reset"


func _refresh_pointer_selection() -> void:
	super._refresh_pointer_selection()
	_sync_selection_previews()


func _sync_selection_previews() -> void:
	if _remove_preview == null or _place_preview == null:
		return

	_remove_preview.visible = false
	_place_preview.visible = false
	if _space == null or _space.get_active_provider() == null:
		return

	var provider := _space.get_active_provider()
	if _selected_remove_cell != INVALID_CELL:
		_remove_preview.global_transform = provider.global_transform * Transform3D(
			Basis.IDENTITY,
			Vector3(_selected_remove_cell) + Vector3.ONE * 0.5
		)
		_remove_preview.visible = true
	if _selected_place_cell != INVALID_CELL:
		_place_preview.global_transform = provider.global_transform * Transform3D(
			Basis.IDENTITY,
			Vector3(_selected_place_cell) + Vector3.ONE * 0.5
		)
		_place_preview.visible = true


func _sync_p05_visuals() -> void:
	if _space == null or _space.get_active_provider() == null:
		return
	var provider := _space.get_active_provider()
	if _matter_grid != null:
		_matter_grid.global_transform = provider.global_transform
	_refresh_provider_visual_style()


func _refresh_provider_visual_style() -> void:
	if _space == null or _space.get_active_provider() == null:
		return
	var provider := _space.get_active_provider()
	var provider_id := provider.get_instance_id()
	if provider_id == _last_styled_provider_id:
		return

	var derived_mesh := provider.get_node_or_null("DerivedMesh") as MeshInstance3D
	if derived_mesh != null:
		if _space.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC:
			derived_mesh.material_override = _matter_dynamic_material
		else:
			derived_mesh.material_override = _matter_static_material
	_last_styled_provider_id = provider_id


func _rebuild_matter_grid() -> void:
	if _matter_grid == null or _volume == null:
		return

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var edge_pairs := [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
		Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7),
	]

	for cell in _occupied_cells(_volume):
		var origin := Vector3(cell)
		var corners := [
			origin,
			origin + Vector3(1.0, 0.0, 0.0),
			origin + Vector3(1.0, 1.0, 0.0),
			origin + Vector3(0.0, 1.0, 0.0),
			origin + Vector3(0.0, 0.0, 1.0),
			origin + Vector3(1.0, 0.0, 1.0),
			origin + Vector3(1.0, 1.0, 1.0),
			origin + Vector3(0.0, 1.0, 1.0),
		]
		for pair in edge_pairs:
			surface.add_vertex(corners[pair.x])
			surface.add_vertex(corners[pair.y])

	_matter_grid.mesh = surface.commit()
	_sync_p05_visuals()


func _remove_cell(cell: Vector3i, source: String = "edit") -> bool:
	var changed := super._remove_cell(cell, source)
	if changed:
		_rebuild_matter_grid()
	return changed


func _place_cell(cell: Vector3i, source: String = "edit") -> bool:
	var changed := super._place_cell(cell, source)
	if changed:
		_rebuild_matter_grid()
	return changed


func _toggle_probe_cell() -> void:
	var before_revision := _volume.revision if _volume != null else -1
	super._toggle_probe_cell()
	if _volume != null and _volume.revision != before_revision:
		_rebuild_matter_grid()


func _reset_lab() -> void:
	super._reset_lab()
	_last_styled_provider_id = 0
	if _matter_grid != null:
		_rebuild_matter_grid()
	_sync_p05_visuals()


func _on_provider_transition_committed(previous_provider_id: int, current_provider_id: int, provider_kind: int) -> void:
	super._on_provider_transition_committed(previous_provider_id, current_provider_id, provider_kind)
	_last_styled_provider_id = 0
	_sync_p05_visuals()


func _recover_actor() -> void:
	if _actor == null or _space == null or _space.get_active_provider() == null:
		return

	var provider := _space.get_active_provider()
	_actor.global_position = provider.to_global(ACTOR_SPAWN)
	_actor.desired_local_velocity = Vector3.ZERO
	_actor.world_velocity = Vector3.ZERO
	_actor.grounded = false
	_actor.support_body = null
	_actor.support_space = null
	_actor.observed_support_velocity = Vector3.ZERO
	_actor.jump_requested = false
	_update_camera(true)
	_last_action = "K: actor recovered onto current logical Space"


func _set_debug_visible(visible: bool) -> void:
	$HUD/Panel.visible = visible
	if _compact_panel != null:
		_compact_panel.visible = not visible


func _update_hud() -> void:
	# Keep the original rich telemetry alive for automated evidence and F1 debug.
	super._update_hud()
	if _compact_label == null:
		return
	if _space == null or _space.get_active_provider() == null:
		_compact_label.text = "FrameMatter P0.5 — no active Space"
		return

	var provider_kind := _space.get_provider_kind()
	var state := "STATIC" if provider_kind == LocalMatterSpace.ProviderKind.STATIC else "DYNAMIC"
	var actor_state := "grounded" if _actor != null and _actor.grounded else "airborne"
	_compact_label.text = (
		"FrameMatter P0.5   •   %s   •   Matter %d cells   •   actor %s\n" % [
			state,
			_volume.count_solid(),
			actor_state,
		]
		+ "target remove %s    |    place %s    |    camera %.1f m\n" % [
			_cell_text(_selected_remove_cell),
			_cell_text(_selected_place_cell),
			_camera_distance,
		]
		+ "WASD move   Space jump   LMB remove   RMB place   T activate/freeze\n"
		+ "MMB drag orbit   wheel zoom   Home camera   K recover   F1 debug   R reset\n"
		+ "last: " + _last_action
	)
