extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 5
const POST_SPLIT_FRAMES := 7
const ALLOWED_VARIANTS := ["current_contour", "top_crown"]
const TEST_STATE_NAME := "R_V3A_StateCrown"
const TEST_FOCUS_NAME := "R_V3A_FocusCrown"
const STATE_ALPHA := 0.40
const FOCUS_ALPHA := 0.62

var _failures: Array[String] = []
var _output_dir := ""
var _variant := "current_contour"
var _p1: Node
var _source: LocalMatterSpace
var _interactor: P1MatterInteractor
var _state_presenter: P1MatterStatePresentation


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_STATE_POLICY_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-state-policy")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	_variant = OS.get_environment("P1_STATE_POLICY_VARIANT").strip_edges().to_lower()
	if _variant.is_empty():
		_variant = "current_contour"
	_check(ALLOWED_VARIANTS.has(_variant), "state-policy variant is supported: %s" % _variant)
	if not ALLOWED_VARIANTS.has(_variant):
		_finish()
		return

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "state-policy capture loads canonical P1 scene")
	if packed == null:
		_finish()
		return

	_p1 = packed.instantiate()
	get_root().add_child(_p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	_source = _p1.call("get_space") as LocalMatterSpace
	_interactor = _p1.call("get_interactor") as P1MatterInteractor
	_state_presenter = _p1.get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	var grid := _p1.get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
	_check(_source != null and _interactor != null and _state_presenter != null and grid != null, "state-policy capture resolves canonical roles")
	if _source == null or _interactor == null or _state_presenter == null or grid == null:
		_cleanup_and_finish()
		return

	_hide_unrelated_instrumentation()
	grid.set_enabled(true)
	_apply_variant()
	await _advance_frames(SETTLE_FRAMES)
	await _capture("00_static_focused")

	_check(bool(_p1.call("toggle_focused_space_for_test")), "state-policy sequence releases focused Space")
	await _source.provider_transition_committed
	await _advance_frames(SETTLE_FRAMES)
	_apply_variant()
	await _capture("01_dynamic_focused")

	for z in range(2, 14):
		var cut_cell := Vector3i(6, 0, z)
		_check(_interactor.apply_edit_to_cell(_source, cut_cell, P1MatterInteractor.EditMode.REMOVE), "state-policy split cut removes %s" % str(cut_cell))
	if _source.is_topology_split_pending():
		await _source.topology_split_committed
	await _advance_frames(POST_SPLIT_FRAMES)
	_apply_variant()
	var successors: Array[LocalMatterSpace] = _p1.call("get_active_spaces")
	_check(successors.size() == 2, "state-policy split produces two live successors")
	await _capture("02_split_two_dynamic")

	var focused := _p1.call("get_space") as LocalMatterSpace
	_check(focused != null and successors.has(focused), "state-policy sequence resolves focused successor")
	if focused != null:
		_check(bool(_p1.call("toggle_focused_space_for_test")), "state-policy sequence freezes focused successor")
		await focused.provider_transition_committed
	await _advance_frames(SETTLE_FRAMES)
	_apply_variant()
	await _capture("03_mixed_static_dynamic")
	await _capture_with_camera("04_mixed_low_angle", 0.72, 0.28, 8.4)

	_cleanup_and_finish()


func _hide_unrelated_instrumentation() -> void:
	var player := _p1.get_node_or_null("P1Player") as Node3D
	if player != null:
		player.visible = false
	var hud := _p1.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var marker := _p1.get_node_or_null("WorldOriginMarker") as MeshInstance3D
	if marker != null:
		marker.visible = false


func _apply_variant() -> void:
	_clear_test_overlays()
	if _variant == "current_contour":
		_state_presenter.set_enabled(true)
		return
	_state_presenter.set_enabled(false)
	_refresh_top_crowns()


func _refresh_top_crowns() -> void:
	var focused := _p1.call("get_space") as LocalMatterSpace
	var spaces: Array[LocalMatterSpace] = _p1.call("get_active_spaces")
	for space in spaces:
		if space == null or space.is_retired() or space.volume == null:
			continue
		var provider := space.get_active_provider()
		if provider == null:
			continue
		var crown_mesh := P1MatterStatePresentation.build_top_surface_perimeter(space.volume)
		if crown_mesh.get_surface_count() == 0:
			continue

		var state_crown := MeshInstance3D.new()
		state_crown.name = TEST_STATE_NAME
		state_crown.mesh = crown_mesh
		state_crown.position.y = -0.006
		state_crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		state_crown.material_override = _line_material(
			Color(0.22, 0.56, 0.72, STATE_ALPHA)
			if space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC
			else Color(0.86, 0.53, 0.20, STATE_ALPHA)
		)
		provider.add_child(state_crown)

		if space == focused:
			var focus_crown := MeshInstance3D.new()
			focus_crown.name = TEST_FOCUS_NAME
			focus_crown.mesh = crown_mesh
			focus_crown.position.y = 0.010
			focus_crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			focus_crown.material_override = _line_material(Color(0.96, 0.98, 1.0, FOCUS_ALPHA))
			provider.add_child(focus_crown)


func _clear_test_overlays() -> void:
	if _p1 == null or not is_instance_valid(_p1):
		return
	var spaces: Array[LocalMatterSpace] = _p1.call("get_active_spaces")
	for space in spaces:
		if space == null or space.is_retired():
			continue
		var provider := space.get_active_provider()
		if provider == null:
			continue
		for node_name in [TEST_STATE_NAME, TEST_FOCUS_NAME]:
			var existing := provider.get_node_or_null(node_name)
			if existing != null:
				existing.free()


func _line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _capture_with_camera(label: String, yaw: float, pitch: float, distance: float) -> void:
	var camera_rig := _p1.call("get_camera_rig") as P1CameraRig
	camera_rig.set("_yaw", yaw)
	camera_rig.set("_pitch", pitch)
	camera_rig.set("_distance", distance)
	camera_rig.call("_apply_user_orbit_immediately")
	await _advance_frames(SETTLE_FRAMES)
	_apply_variant()
	await _capture(label)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "capture %s produced pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "capture %s saved PNG" % label)
	if save_error == OK:
		print("P1_STATE_POLICY_FRAME: variant=%s label=%s %dx%d -> %s" % [_variant, label, image.get_width(), image.get_height(), path])


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _cleanup_and_finish() -> void:
	_clear_test_overlays()
	if _p1 != null and is_instance_valid(_p1):
		_p1.free()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("P1_STATE_POLICY_CAPTURE_PASS: variant=%s completed real STATIC, DYNAMIC, split and mixed-state rendered evidence." % _variant)
		quit(0)
		return
	for failure in _failures:
		push_error("P1_STATE_POLICY_CAPTURE_FAIL: " + failure)
	quit(1)
