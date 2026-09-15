class_name P1MatterTargetPresentation
extends Node

# Presentation-only consumer for G5. Target authority remains entirely in
# P1MatterInteractor; this node only derives depth-tested geometry from the
# currently resolved Space/cells/operation.

const OVERLAY_NAME := "P1MatterTargetCue"
const FACE_OFFSET := 0.025
const REMOVE_COLOR := Color(1.0, 0.30, 0.18, 0.92)
const PLACE_COLOR := Color(0.32, 1.0, 0.58, 0.88)
const EXPAND_COLOR := Color(0.18, 0.82, 1.0, 0.92)

var interactor: P1MatterInteractor
var enabled := true
var suppress_legacy_outline := true

var _overlay: MeshInstance3D
var _provider: Node3D
var _signature := ""


func _process(_delta: float) -> void:
	if suppress_legacy_outline:
		_hide_legacy_outline()
	_refresh_if_needed()


func set_interactor(value: P1MatterInteractor) -> void:
	clear()
	interactor = value
	_signature = ""
	_refresh_if_needed()


func set_enabled(value: bool) -> void:
	enabled = value
	_signature = ""
	if not enabled:
		clear()
	else:
		_refresh_if_needed()


func refresh_now() -> void:
	_signature = ""
	_hide_legacy_outline()
	_refresh_if_needed()


func clear() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.free()
	_overlay = null
	_provider = null


func _refresh_if_needed() -> void:
	if not enabled or interactor == null or not is_instance_valid(interactor):
		clear()
		return
	if interactor.target_space == null or not is_instance_valid(interactor.target_space) or not interactor.target_valid:
		if not _signature.is_empty():
			clear()
			_signature = ""
		return
	var space := interactor.target_space
	if space.is_retired() or space.get_active_provider() == null:
		clear()
		_signature = ""
		return
	var provider := space.get_active_provider()
	var signature := "%d|%d|%d|%s|%s|%s" % [
		space.get_instance_id(),
		provider.get_instance_id(),
		interactor.mode,
		str(interactor.target_in_storage),
		str(interactor.remove_cell),
		str(interactor.place_cell),
	]
	if signature == _signature and _overlay != null and is_instance_valid(_overlay):
		return
	_signature = signature
	_rebuild(provider)


func _rebuild(provider: Node3D) -> void:
	clear()
	_provider = provider
	if provider == null:
		return
	var face := interactor.place_cell - interactor.remove_cell
	if absi(face.x) + absi(face.y) + absi(face.z) != 1:
		return

	var mesh := _build_target_mesh(face)
	if mesh.get_surface_count() == 0:
		return
	_overlay = MeshInstance3D.new()
	_overlay.name = OVERLAY_NAME
	_overlay.mesh = mesh
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.material_override = _make_material(_current_color())
	provider.add_child(_overlay)


func _build_target_mesh(face: Vector3i) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)

	var normal := Vector3(face)
	var axes := _face_axes(face)
	var u: Vector3 = axes[0]
	var v: Vector3 = axes[1]
	var remove_center := Vector3(interactor.remove_cell) + Vector3(0.5, 0.5, 0.5)
	var shared_face := remove_center + normal * (0.5 + FACE_OFFSET)

	if interactor.mode == P1MatterInteractor.EditMode.REMOVE:
		_add_square(surface, shared_face, u, v, 0.38)
		_add_segment(surface, shared_face + (-u - v) * 0.24, shared_face + (u + v) * 0.24)
		_add_segment(surface, shared_face + (-u + v) * 0.24, shared_face + (u - v) * 0.24)
		return surface.commit(mesh)

	# PLACE and EXPAND use an open directional prism: the hit/source face stays
	# readable while a far face and four rails show which adjacent cell will be
	# created. Depth testing hides rails that should be physically occluded.
	var source_half := 0.33
	var far_half := 0.39
	var far_face := shared_face + normal * (1.0 + FACE_OFFSET)
	var source_corners := _square_corners(shared_face, u, v, source_half)
	var far_corners := _square_corners(far_face, u, v, far_half)
	_add_square_from_corners(surface, source_corners)
	_add_square_from_corners(surface, far_corners)
	for i in range(4):
		_add_segment(surface, source_corners[i], far_corners[i])

	# A small plus on the destination face makes PLACE readable even when some
	# prism rails are hidden by real geometry.
	_add_segment(surface, far_face - u * 0.20, far_face + u * 0.20)
	_add_segment(surface, far_face - v * 0.20, far_face + v * 0.20)

	if not interactor.target_in_storage:
		# EXPAND remains the same operation family but gets an outer destination
		# frame. This encodes the storage-boundary consequence geometrically rather
		# than relying on cyan alone.
		_add_square(surface, far_face + normal * 0.006, u, v, 0.47)
	return surface.commit(mesh)


func _current_color() -> Color:
	if interactor.mode == P1MatterInteractor.EditMode.REMOVE:
		return REMOVE_COLOR
	return PLACE_COLOR if interactor.target_in_storage else EXPAND_COLOR


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.vertex_color_use_as_albedo = false
	# Intentionally leave no_depth_test at its default false. Occlusion is part of
	# the G5 contract, not an optional visual preference.
	return material


func _face_axes(face: Vector3i) -> Array[Vector3]:
	if face.x != 0:
		return [Vector3.UP, Vector3.FORWARD]
	if face.y != 0:
		return [Vector3.RIGHT, Vector3.FORWARD]
	return [Vector3.RIGHT, Vector3.UP]


func _square_corners(center: Vector3, u: Vector3, v: Vector3, half: float) -> Array[Vector3]:
	return [
		center - u * half - v * half,
		center + u * half - v * half,
		center + u * half + v * half,
		center - u * half + v * half,
	]


func _add_square(surface: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, half: float) -> void:
	_add_square_from_corners(surface, _square_corners(center, u, v, half))


func _add_square_from_corners(surface: SurfaceTool, corners: Array[Vector3]) -> void:
	for i in range(4):
		_add_segment(surface, corners[i], corners[(i + 1) % 4])


func _add_segment(surface: SurfaceTool, a: Vector3, b: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)


func _hide_legacy_outline() -> void:
	if interactor == null or not is_instance_valid(interactor):
		return
	var outline := interactor.get_node_or_null("TargetOutline") as MeshInstance3D
	if outline != null:
		outline.visible = false
