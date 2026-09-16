class_name MatterRepresentation
extends Node3D

var volume: CellVolume
var collision_mode := CellCollisionBoxer.Mode.MERGED_CUBOIDS
var last_rebuild_usec := 0

var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _material: StandardMaterial3D


func set_volume(new_volume: CellVolume) -> void:
	volume = new_volume
	_ensure_nodes()
	rebuild()


func rebuild() -> void:
	assert(volume != null)
	_ensure_nodes()
	var started_usec := Time.get_ticks_usec()

	_mesh_instance.mesh = CellMesher.build_mesh(volume)

	for child in _body.get_children():
		_body.remove_child(child)
		child.free()

	var collision_boxes := CellCollisionBoxer.build_boxes(volume, collision_mode)
	for box_info in collision_boxes:
		var box_origin: Vector3i = box_info["origin"]
		var box_size: Vector3i = box_info["size"]
		var box := BoxShape3D.new()
		box.size = Vector3(float(box_size.x), float(box_size.y), float(box_size.z))
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = box
		collision_shape.position = Vector3(float(box_origin.x), float(box_origin.y), float(box_origin.z)) + box.size * 0.5
		_body.add_child(collision_shape)

	last_rebuild_usec = Time.get_ticks_usec() - started_usec


func get_collision_shape_count() -> int:
	if _body == null:
		return 0
	return _body.get_child_count()


func get_mesh_vertex_count() -> int:
	if _mesh_instance == null or _mesh_instance.mesh == null:
		return 0
	if _mesh_instance.mesh.get_surface_count() == 0:
		return 0
	var arrays := _mesh_instance.mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX].size()


func _ensure_nodes() -> void:
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "DerivedMesh"
		add_child(_mesh_instance)

		_material = MatterSurfaceStyle.create_material()
		_mesh_instance.material_override = _material

	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "DerivedCollision"
		add_child(_body)
