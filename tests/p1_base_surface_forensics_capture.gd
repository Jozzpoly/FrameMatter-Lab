extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 3
const ALLOWED_VARIANTS := ["current", "cull_front", "corrected_winding"]

var _failures: Array[String] = []
var _output_dir := ""
var _variant := "current"
var _p1: Node
var _space: LocalMatterSpace
var _camera_rig: P1CameraRig


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_BASE_SURFACE_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-base-surface-forensics")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	_variant = OS.get_environment("P1_BASE_SURFACE_VARIANT").strip_edges().to_lower()
	if _variant.is_empty():
		_variant = "current"
	_check(ALLOWED_VARIANTS.has(_variant), "base-surface variant is supported: %s" % _variant)
	if not ALLOWED_VARIANTS.has(_variant):
		_finish()
		return

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "base-surface forensics loads canonical P1 scene")
	if packed == null:
		_finish()
		return

	_p1 = packed.instantiate()
	get_root().add_child(_p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	_space = _p1.call("get_space") as LocalMatterSpace
	_camera_rig = _p1.call("get_camera_rig") as P1CameraRig
	_check(_space != null and _camera_rig != null, "base-surface forensics resolves Matter and camera")
	if _space == null or _camera_rig == null:
		_cleanup_and_finish()
		return

	_disable_semantic_presentation()
	_apply_variant()
	await _advance_frames(SETTLE_FRAMES)
	print("P1_BASE_SURFACE_VARIANT: %s" % _variant)

	await _capture_angle("00_clean_default", 0.72, 0.48, 7.2)
	await _capture_angle("01_clean_opposite", 2.35, 0.52, 8.4)

	_apply_chaotic_geometry()
	_apply_variant()
	await _advance_frames(SETTLE_FRAMES)
	await _capture_angle("02_chaos_default", 0.72, 0.48, 7.2)
	await _capture_angle("03_chaos_opposite", 2.35, 0.52, 8.4)

	_cleanup_and_finish()


func _disable_semantic_presentation() -> void:
	var surface_grid := _p1.get_node_or_null("P1MatterSurfaceGrid")
	if surface_grid != null and surface_grid.has_method("set_enabled"):
		surface_grid.call("set_enabled", false)
	var state_presentation := _p1.get_node_or_null("P1MatterStatePresentation")
	if state_presentation != null and state_presentation.has_method("set_enabled"):
		state_presentation.call("set_enabled", false)

	# Hide Owner instrumentation so the capture judges base physical form only.
	var player := _p1.get_node_or_null("P1Player") as Node3D
	if player != null:
		player.visible = false
	var hud := _p1.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var marker := _p1.get_node_or_null("WorldOriginMarker") as MeshInstance3D
	if marker != null:
		marker.visible = false


func _apply_chaotic_geometry() -> void:
	# Deterministic accumulated geometry entropy: holes, notches, stairs and
	# protrusions. This intentionally does not restore edits like the old G8 burst.
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


func _apply_variant() -> void:
	var provider := _space.get_active_provider()
	_check(provider != null, "base-surface variant has active provider")
	if provider == null:
		return
	var derived := provider.get_node_or_null("DerivedMesh") as MeshInstance3D
	_check(derived != null, "base-surface variant resolves DerivedMesh")
	if derived == null:
		return
	var material := derived.material_override as StandardMaterial3D
	_check(material != null, "base-surface variant resolves StandardMaterial3D")
	if material == null:
		return

	match _variant:
		"current":
			material.cull_mode = BaseMaterial3D.CULL_BACK
		"cull_front":
			material.cull_mode = BaseMaterial3D.CULL_FRONT
		"corrected_winding":
			material.cull_mode = BaseMaterial3D.CULL_BACK
			derived.mesh = _build_corrected_winding_mesh(_space.volume)


func _build_corrected_winding_mesh(volume: CellVolume) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if volume == null or volume.count_solid() == 0:
		return mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var origin := Vector3(cell)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var vertices: Array = CellMesher.FACE_VERTICES[face_index]
					var normal: Vector3 = CellMesher.FACE_NORMALS[face_index]
					for triangle_start in [0, 3]:
						for local_index in [0, 2, 1]:
							surface.set_normal(normal)
							surface.add_vertex(origin + Vector3(vertices[triangle_start + local_index]))
	return surface.commit(mesh)


func _capture_angle(label: String, yaw: float, pitch: float, distance: float) -> void:
	_camera_rig.set("_yaw", yaw)
	_camera_rig.set("_pitch", pitch)
	_camera_rig.set("_distance", distance)
	_camera_rig.call("_apply_user_orbit_immediately")
	await _advance_frames(SETTLE_FRAMES)
	_apply_variant()
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
		print("P1_BASE_SURFACE_FRAME: variant=%s label=%s %dx%d -> %s" % [_variant, label, image.get_width(), image.get_height(), path])


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
		print("P1_BASE_SURFACE_FORENSICS_PASS: variant=%s clean and chaotic base-Matter captures completed with semantic overlays disabled." % _variant)
		quit(0)
		return
	for failure in _failures:
		push_error("P1_BASE_SURFACE_FORENSICS_FAIL: " + failure)
	quit(1)
