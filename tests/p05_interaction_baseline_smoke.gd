extends SceneTree

const GROUND_ACQUIRE_FRAMES := 8
const POST_RECOVERY_FRAMES := 8

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://lab/main.tscn") as PackedScene
	_check(packed != null, "P0.5 LAB scene loads")
	if packed == null:
		_finish()
		return

	var lab := packed.instantiate()
	get_root().add_child(lab)
	await process_frame

	var space := lab.get_node_or_null("InteractiveLocalMatterSpace") as LocalMatterSpace
	var actor := lab.get_node_or_null("InteractiveActor") as FrameProbeCharacter
	var camera := lab.get_node_or_null("Camera3D") as Camera3D
	var compact_panel := lab.get_node_or_null("HUD/CompactPanel") as PanelContainer
	var compact_label := lab.get_node_or_null("HUD/CompactPanel/Label") as Label
	var debug_panel := lab.get_node_or_null("HUD/Panel") as Panel
	var debug_label := lab.get_node_or_null("HUD/Panel/Label") as Label
	var remove_preview := lab.get_node_or_null("RemoveCellPreview") as MeshInstance3D
	var place_preview := lab.get_node_or_null("PlaceCellPreview") as MeshInstance3D
	var matter_grid := lab.get_node_or_null("MatterCellGrid") as MeshInstance3D

	_check(space != null, "P0.5 keeps the shared logical LocalMatterSpace")
	_check(actor != null, "P0.5 keeps the embodied FrameProbeCharacter")
	_check(camera != null, "P0.5 exposes an owner-facing camera")
	_check(compact_panel != null and compact_label != null, "P0.5 creates compact owner HUD")
	_check(debug_panel != null and debug_label != null, "P0.5 preserves rich debug telemetry")
	_check(remove_preview != null and place_preview != null, "P0.5 creates explicit remove/place previews")
	_check(matter_grid != null and matter_grid.mesh != null, "P0.5 creates visible cell-grid context")
	if space == null or actor == null or camera == null:
		lab.free()
		_finish()
		return

	_check(compact_panel.visible, "P0.5 compact HUD is visible by default")
	_check(not debug_panel.visible, "P0.5 telemetry HUD is hidden by default")
	_check(compact_label.text.contains("FrameMatter P0.5"), "P0.5 compact HUD identifies the interaction baseline")
	_check(debug_label.text.contains("FrameMatter P0 LAB"), "P0 rich telemetry remains alive behind F1")

	var initial_camera_distance := camera.global_position.distance_to(actor.global_position + Vector3.UP * 0.72)
	_check(initial_camera_distance > 4.0 and initial_camera_distance < 10.0, "P0.5 starts with a materially closer camera than P0")
	lab.call("_adjust_camera_zoom", -2.0)
	lab.call("_update_camera", true)
	var zoomed_camera_distance := camera.global_position.distance_to(actor.global_position + Vector3.UP * 0.72)
	_check(zoomed_camera_distance < initial_camera_distance, "P0.5 camera zoom changes framing deterministically")
	lab.call("_reset_camera_view")

	lab.call("_set_debug_visible", true)
	_check(debug_panel.visible and not compact_panel.visible, "F1 debug mode can replace the compact HUD")
	lab.call("_set_debug_visible", false)
	_check(not debug_panel.visible and compact_panel.visible, "compact HUD can be restored after debug")

	await _advance_frames(GROUND_ACQUIRE_FRAMES)
	_check(actor.grounded, "P0.5 actor acquires support before recovery probe")
	var logical_space_id := space.get_instance_id()
	var provider_id := space.get_active_provider().get_instance_id()
	var occupied_before := space.volume.count_solid()

	actor.global_position = Vector3(100.0, -50.0, 100.0)
	lab.call("_recover_actor")
	_check(space.get_instance_id() == logical_space_id, "P0.5 recovery does not replace logical Space")
	_check(space.get_active_provider().get_instance_id() == provider_id, "P0.5 recovery does not replace provider")
	await _advance_frames(POST_RECOVERY_FRAMES)
	_check(actor.grounded, "P0.5 recovered actor reacquires support")
	_check(actor.support_space == space, "P0.5 recovery reacquires the same logical support Space")

	var edit_cell := Vector3i(0, 0, 0)
	_check(bool(lab.call("_remove_cell", edit_cell, "P0.5 smoke")), "P0.5 removal still uses shared Matter mutation path")
	_check(space.volume.count_solid() == occupied_before - 1, "P0.5 removal changes authoritative occupancy")
	_check(matter_grid.mesh != null, "P0.5 grid survives occupancy rebuild")
	_check(bool(lab.call("_place_cell", edit_cell, "P0.5 smoke")), "P0.5 placement still uses shared Matter mutation path")
	_check(space.volume.count_solid() == occupied_before, "P0.5 placement restores authoritative occupancy")

	lab.call("_activate_dynamic")
	await space.provider_transition_committed
	await _advance_frames(3)
	_check(space.get_active_provider() is ConstructBody, "P0.5 remains compatible with static→dynamic activation")
	_check(matter_grid.global_transform.origin.distance_to(space.get_active_provider().global_transform.origin) < 0.001, "P0.5 cell grid follows the active moving provider")

	print(
		"P05_INTERACTION_BASELINE_METRIC initial_camera_distance=%.3f zoomed_camera_distance=%.3f cells=%d provider_kind=%d"
		% [
			initial_camera_distance,
			zoomed_camera_distance,
			space.volume.count_solid(),
			space.get_provider_kind(),
		]
	)

	lab.free()
	_finish()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("P05_INTERACTION_BASELINE_PASS: compact owner HUD, closer orbit/zoom camera, explicit edit previews, Matter grid context and non-destructive actor recovery coexist with the defended P0 consumer.")
		quit(0)
		return
	for failure in _failures:
		push_error("P05_INTERACTION_BASELINE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
