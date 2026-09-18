extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 5
const POST_SPLIT_FRAMES := 7
const ALLOWED_VARIANTS := ["current_contour", "top_crown", "side_rim"]
const TEST_STATE_NAME := "R_V3_StateCue"
const TEST_FOCUS_NAME := "R_V3_FocusCrown"

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
	var target_presenter := _p1.get_node_or_null("P1MatterTargetPresentation") as P1MatterTargetPresentation
	if target_presenter != null:
		target_presenter.set_enabled(false)


func _apply_variant() -> void:
	_clear_test_overlays()
	if _variant == "current_contour":
		_state_presenter.set_enabled(true)
		return
	_state_presenter.set_enabled(false)
	_refresh_custom_overlays()


func _refresh_custom_overlays() -> void:
	var focused := _p1.call("get_space") as LocalMatterSpace
	var spaces: Array[LocalMatterSpace] = _p1.call("get_active_spaces")
	for space in spaces:
		if space == null or space.is_retired() or space.volume == null:
			continue
		var provider := space.get_active_provider()
		if provider == null:
			continue

		var state_mesh := (
			P1MatterStatePresentation.build_top_surface_perimeter(space.volume)
			if _variant == "top_crown"
			else _build_side_surface_contour(space.volume)
		)
		if state_mesh.get_surface_count() != 0:
			var state_overlay := MeshInstance3D.new()
			state_overlay.name = TEST_STATE_NAME
			state_overlay.mesh = state_mesh
			# The production focus crown already lives 0.020 m above top surfaces.
			# Keep a top-only state cue slightly below it so focus and state do not
			# occupy exactly the same depth plane. Side-rim geometry needs no shift.
			if _variant == "top_crown":
				state_overlay.position.y = -0.010
			state_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			state_overlay.material_override = _line_material(
				P1MatterStatePresentation.STATIC_COLOR
				if space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC
				else P1MatterStatePresentation.DYNAMIC_COLOR
			)
			provider.add_child(state_overlay)

		if space != focused:
			continue
		var focus_mesh := P1MatterStatePresentation.build_top_surface_perimeter(space.volume)
		if focus_mesh.get_surface_count() == 0:
			continue
		var focus_overlay := MeshInstance3D.new()
		focus_overlay.name = TEST_FOCUS_NAME
		focus_overlay.mesh = focus_mesh
		focus_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		focus_overlay.material_override = _line_material(P1MatterStatePresentation.FOCUS_COLOR)
		provider.add_child(focus_overlay)


func _build_side_surface_contour(volume: CellVolume) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if volume == null or volume.count_solid() == 0:
		return mesh

	var edge_records: Dictionary = {}
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var origin := Vector3(cell)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					var normal: Vector3 = CellMesher.FACE_NORMALS[face_index]
					if absf(normal.dot(Vector3.UP)) > 0.01:
						continue
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var corners := _face_corners(origin, face_index)
					for edge_index in range(4):
						var a: Vector3 = corners[edge_index]
						var b: Vector3 = corners[(edge_index + 1) % 4]
						var key := _oriented_edge_key(face_index, a, b)
						if not edge_records.has(key):
							edge_records[key] = {"count": 0, "a": a, "b": b, "face": face_index}
						var record: Dictionary = edge_records[key]
						record["count"] = int(record["count"]) + 1
						edge_records[key] = record

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	for record_variant in edge_records.values():
		var record: Dictionary = record_variant
		if int(record["count"]) != 1:
			continue
		var normal: Vector3 = CellMesher.FACE_NORMALS[int(record["face"])]
		_add_segment(
			surface,
			Vector3(record["a"]) + normal * P1MatterStatePresentation.CONTOUR_OFFSET,
			Vector3(record["b"]) + normal * P1MatterStatePresentation.CONTOUR_OFFSET
		)
	return surface.commit(mesh)


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
	_report_overlay_budget(label)
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


func _report_overlay_budget(label: String) -> void:
	var state_segments := 0
	var focus_segments := 0
	var spaces: Array[LocalMatterSpace] = _p1.call("get_active_spaces")
	for space in spaces:
		if space == null or space.is_retired() or space.get_active_provider() == null:
			continue
		var state_overlay: MeshInstance3D
		var focus_overlay: MeshInstance3D
		if _variant == "current_contour":
			state_overlay = _state_presenter.get_state_overlay_for_space(space)
			focus_overlay = _state_presenter.get_focus_overlay_for_space(space)
		else:
			var provider := space.get_active_provider()
			state_overlay = provider.get_node_or_null(TEST_STATE_NAME) as MeshInstance3D
			focus_overlay = provider.get_node_or_null(TEST_FOCUS_NAME) as MeshInstance3D
		state_segments += _line_segment_count(state_overlay)
		focus_segments += _line_segment_count(focus_overlay)
	print("P1_STATE_POLICY_BUDGET: variant=%s label=%s spaces=%d state_segments=%d focus_segments=%d" % [
		_variant, label, spaces.size(), state_segments, focus_segments
	])


func _line_segment_count(overlay: MeshInstance3D) -> int:
	if overlay == null or overlay.mesh == null or overlay.mesh.get_surface_count() == 0:
		return 0
	var arrays := overlay.mesh.surface_get_arrays(0)
	return int(arrays[Mesh.ARRAY_VERTEX].size() / 2)


func _face_corners(origin: Vector3, face_index: int) -> Array:
	var face_vertices: Array = CellMesher.FACE_VERTICES[face_index]
	return [
		origin + face_vertices[0],
		origin + face_vertices[1],
		origin + face_vertices[2],
		origin + face_vertices[5],
	]


func _add_segment(surface: SurfaceTool, a: Vector3, b: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)


func _oriented_edge_key(face_index: int, a: Vector3, b: Vector3) -> String:
	var ai := Vector3i(int(a.x), int(a.y), int(a.z))
	var bi := Vector3i(int(b.x), int(b.y), int(b.z))
	if _vector3i_less(bi, ai):
		var swap := ai
		ai = bi
		bi = swap
	return "%d|%d,%d,%d|%d,%d,%d" % [face_index, ai.x, ai.y, ai.z, bi.x, bi.y, bi.z]


func _vector3i_less(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z


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
		print("P1_STATE_POLICY_CAPTURE_PASS: variant=%s completed isolated real STATIC, DYNAMIC, split and mixed-state rendered evidence." % _variant)
		quit(0)
		return
	for failure in _failures:
		push_error("P1_STATE_POLICY_CAPTURE_FAIL: " + failure)
	quit(1)
