class_name P1WorldReferencePresentation
extends Node3D

# Presentation-only world datum for G6. It is intentionally much coarser than
# the one-cell Matter grid and remains fixed to the authored WorldReference.
# It owns no Space, Matter, physics or motion state.

@export var half_extent := 28.0
@export var spacing := 4.0
@export var major_every := 2
@export var surface_offset_y := 0.26
@export var minor_color := Color(0.045, 0.075, 0.10, 0.34)
@export var major_color := Color(0.09, 0.15, 0.20, 0.54)

var _grid: MeshInstance3D


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	if _grid != null and is_instance_valid(_grid):
		_grid.free()
	_grid = MeshInstance3D.new()
	_grid.name = "CoarseWorldGrid"
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.mesh = _build_grid_mesh()
	_grid.material_override = _build_material()
	add_child(_grid)


func _build_grid_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var count := int(floor(half_extent / spacing))
	for index in range(-count, count + 1):
		var coordinate := float(index) * spacing
		var color := major_color if index % major_every == 0 else minor_color
		_add_segment(
			surface,
			Vector3(coordinate, surface_offset_y, -half_extent),
			Vector3(coordinate, surface_offset_y, half_extent),
			color
		)
		_add_segment(
			surface,
			Vector3(-half_extent, surface_offset_y, coordinate),
			Vector3(half_extent, surface_offset_y, coordinate),
			color
		)
	return surface.commit(mesh)


func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	# Keep normal depth testing. World reference must never draw through Matter.
	return material


func _add_segment(surface: SurfaceTool, a: Vector3, b: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.add_vertex(a)
	surface.set_color(color)
	surface.add_vertex(b)
