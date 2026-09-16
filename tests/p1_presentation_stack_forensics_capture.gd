extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 3
const ALLOWED_VARIANTS := ["base", "grid", "state", "grid_state"]

var _failures: Array[String] = []
var _output_dir := ""
var _variant := "base"
var _p1: Node
var _space: LocalMatterSpace
var _camera_rig: P1CameraRig
var _surface_grid: P1MatterSurfaceGrid
var _state_presentation: P1MatterStatePresentation


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_PRESENTATION_STACK_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-presentation-stack-forensics")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	_variant = OS.get_environment("P1_PRESENTATION_STACK_VARIANT").strip_edges().to_lower()
	if _variant.is_empty():
		_variant = "base"
	_check(ALLOWED_VARIANTS.has(_variant), "presentation-stack variant is supported: %s" % _variant)
	if not ALLOWED_VARIANTS.has(_variant):
		_finish()
		return

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "presentation-stack forensics loads canonical P1 scene")
	if packed == null:
		_finish()
		return

	_p1 = packed.instantiate()
	get_root().add_child(_p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	_space = _p1.call("get_space") as LocalMatterSpace
	_camera_rig = _p1.call("get_camera_rig") as P1CameraRig
	_surface_grid = _p1.get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
	_state_presentation = _p1.get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	_check(
		_space != null and _camera_rig != null and _surface_grid != null and _state_presentation != null,
		"presentation-stack forensics resolves canonical Matter presentation roles"
	)
	if _space == null or _camera_rig == null or _surface_grid == null or _state_presentation == null:
		_cleanup_and_finish()
		return

	_hide_unrelated_instrumentation()
	_apply_presentation_variant()
	await _advance_frames(SETTLE_FRAMES)
	print("P1_PRESENTATION_STACK_VARIANT: %s" % _variant)

	await _capture_angle("00_clean_mid", 0.72, 0.48, 7.2)
	await _capture_angle("01_clean_near", 0.72, 0.52, 4.6)

	_apply_chaotic_geometry()
	_apply_presentation_variant()
	await _advance_frames(SETTLE_FRAMES)
	await _capture_angle("02_chaos_near", 0.72, 0.56, 4.6)
	await _capture_angle("03_chaos_mid", 0.72, 0.48, 7.2)
	await _capture_angle("04_chaos_opposite", 2.35, 0.52, 8.4)

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


func _apply_presentation_variant() -> void:
	var grid_enabled := _variant == "grid" or _variant == "grid_state"
	var state_enabled := _variant == "state" or _variant == "grid_state"
	_surface_grid.set_enabled(grid_enabled)
	_state_presentation.set_enabled(state_enabled)
	if state_enabled:
		_state_presentation.set_focus_space(_space)


func _apply_chaotic_geometry() -> void:
	var removals := [
		Vector3i(4, 0, 4), Vector3i(5, 0, 4), Vector3i(6, 0, 5),
		Vector3i(8, 0, 6), Vector3i(9, 0, 6), Vector3i(10, 0, 7),
		Vector3i(5, 0, 9), Vector3i(6, 0, 10), Vector3i(8, 0, 10),
		Vector3i(10, 0, 11), Vector3i(12, 0, 5), Vector3i(3, 0, 11),
		Vector3i(3, 1, 5), Vector3i(3, 2, 7), Vector3i(11, 1, 9),
	]
	for cell in removals:
		if _space.volume.in_bounds(cell) and _space.volume.get_cell(cell) != CellVolume.EMPTY:
			_check(_space.mutate_cell(cell, CellVolume.EMPTY), "chaos removal applies %s" % str(cell))

	var additions := [
		Vector3i(5, 1, 5), Vector3i(5, 2, 5),
		Vector3i(6, 1, 5), Vector3i(7, 1, 6), Vector3i(7, 2, 6),
		Vector3i(8, 1, 7), Vector3i(9, 1, 8), Vector3i(9, 2, 8),
		Vector3i(10, 1, 10), Vector3i(10, 2, 10), Vector3i(10, 3, 10),
		Vector3i(12, 1, 6), Vector3i(12, 2, 6),
	]
	for cell in additions:
		if _space.volume.in_bounds(cell) and _space.volume.get_cell(cell) == CellVolume.EMPTY:
			_check(_space.mutate_cell(cell, CellVolume.SOLID), "chaos addition applies %s" % str(cell))

	_check(_space.volume.count_solid() > 100, "chaotic corpus retains substantial Matter mass")


func _capture_angle(label: String, yaw: float, pitch: float, distance: float) -> void:
	_camera_rig.set("_yaw", yaw)
	_camera_rig.set("_pitch", pitch)
	_camera_rig.set("_distance", distance)
	_camera_rig.call("_apply_user_orbit_immediately")
	await _advance_frames(SETTLE_FRAMES)
	_apply_presentation_variant()
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
		print("P1_PRESENTATION_STACK_FRAME: variant=%s label=%s %dx%d -> %s" % [_variant, label, image.get_width(), image.get_height(), path])


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _cleanup_and_finish() -> void:
	if _p1 != null and is_instance_valid(_p1):
		_p1.free()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("P1_PRESENTATION_STACK_FORENSICS_PASS: variant=%s clean and chaotic corrected-surface presentation captures completed." % _variant)
		quit(0)
		return
	for failure in _failures:
		push_error("P1_PRESENTATION_STACK_FORENSICS_FAIL: " + failure)
	quit(1)
