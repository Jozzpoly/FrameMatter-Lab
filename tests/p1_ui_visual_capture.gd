extends SceneTree

const ACQUIRE_FRAMES := 18
const MOTION_FRAMES := 36
const POST_SPLIT_FRAMES := 8
const HUD_SAFE_POINT := Vector2(50.0, 50.0)
const VARIANT_BASELINE := "baseline"
const VARIANT_COMPACT := "compact"
const MOTION_IMPULSE := Vector3(0.0, 0.0, -48.0)
const MOTION_TORQUE := Vector3(0.0, 240.0, 0.0)

var _failures: Array[String] = []
var _output_dir := ""
var _variant := VARIANT_BASELINE
var _p1: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_UI_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-ui-evidence")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var requested := OS.get_environment("P1_UI_VARIANT").strip_edges().to_lower()
	if not requested.is_empty():
		_variant = requested
	_check(_variant == VARIANT_BASELINE or _variant == VARIANT_COMPACT, "UI capture variant is supported")

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "UI capture loads canonical P1 scene")
	if packed == null:
		_finish()
		return
	_p1 = packed.instantiate()
	if _variant == VARIANT_COMPACT:
		var presentation := P1HudPresentation.new()
		presentation.name = "P1HudPresentationEvidence"
		_p1.add_child(presentation)
		presentation.bind_host(_p1)
	get_root().add_child(_p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	var source := _p1.call("get_space") as LocalMatterSpace
	var control := _p1.call("get_space_control") as P1SpaceControl
	var interactor := _p1.call("get_interactor") as P1MatterInteractor
	var panel := _p1.get_node_or_null("HUD/Panel") as PanelContainer
	var status := _p1.get_node_or_null("HUD/Panel/MarginContainer/VBoxContainer/Status") as Label
	_check(source != null and control != null and interactor != null and panel != null and status != null, "UI capture resolves composed roles and default HUD")
	if source == null or control == null or interactor == null or panel == null or status == null:
		_p1.free()
		_finish()
		return

	Input.warp_mouse(HUD_SAFE_POINT)
	await process_frame
	interactor.update_target_from_pointer_position(HUD_SAFE_POINT)
	_check(interactor.target_space == null, "UI-owned pointer region clears world target")

	if _variant == VARIANT_COMPACT:
		_check(panel.size.x <= 340.0 and panel.size.y <= 64.0, "compact HUD remains bounded instead of recreating a top strip")
		var normalized := status.text.to_lower()
		_check(not normalized.contains("target") and not normalized.contains("support") and not normalized.contains("ω") and not normalized.contains(" v "), "compact default status omits engineering telemetry")

	print("P1_UI_VARIANT: %s panel_size=%s status=%s" % [_variant, str(panel.size), status.text])
	await _capture("00_static")

	_check(control.release_space(source), "UI sequence releases Space")
	await source.provider_transition_committed
	await _advance_frames(3)
	await _capture("01_released_zero_motion")

	_check(control.apply_local_central_impulse(source, MOTION_IMPULSE), "UI sequence applies finite translation")
	_check(control.apply_local_torque_impulse(source, MOTION_TORQUE), "UI sequence applies finite yaw")
	await _advance_frames(MOTION_FRAMES)
	await _capture("02_dynamic_motion")

	for z in range(2, 14):
		var cut_cell := Vector3i(6, 0, z)
		_check(interactor.apply_edit_to_cell(source, cut_cell, P1MatterInteractor.EditMode.REMOVE), "UI sequence removes split seam cell %s" % str(cut_cell))
	if source.is_topology_split_pending():
		await source.topology_split_committed
	await _advance_frames(POST_SPLIT_FRAMES)
	var spaces: Array[LocalMatterSpace] = _p1.call("get_active_spaces")
	_check(spaces.size() == 2, "UI sequence reaches two live successor Spaces")
	await _capture("03_split_successors")

	_p1.free()
	_finish()


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "%s produced rendered pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "%s saved PNG" % label)
	if save_error == OK:
		print("P1_UI_FRAME: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_UI_CAPTURE_PASS: variant=%s default UI hierarchy sequence completed." % _variant)
		quit(0)
		return
	for failure in _failures:
		push_error("P1_UI_CAPTURE_FAIL: " + failure)
	quit(1)
