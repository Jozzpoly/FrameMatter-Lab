class_name MatterRepresentation
extends Node3D

var volume: CellVolume
var collision_mode := CellCollisionBoxer.Mode.MERGED_CUBOIDS
var chunk_edge := 0
var last_rebuild_usec := 0

var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _material: StandardMaterial3D
var _mesh_chunks: Dictionary = {}
var _collision_chunks: Dictionary = {}


func set_volume(new_volume: CellVolume) -> void:
	volume = new_volume
	_ensure_nodes()
	rebuild()


func set_volume_dirty_cells(new_volume: CellVolume, dirty_cells: Array[Vector3i]) -> void:
	assert(new_volume != null)
	_ensure_nodes()
	var can_rebuild_locally := (
		chunk_edge > 0
		and volume != null
		and volume.size == new_volume.size
		and not _mesh_chunks.is_empty()
		and not _collision_chunks.is_empty()
		and not dirty_cells.is_empty()
	)
	volume = new_volume
	if not can_rebuild_locally:
		rebuild()
		return

	var started_usec := Time.get_ticks_usec()
	_mesh_instance.mesh = null
	_mesh_instance.visible = false
	var dirty_mesh_origins: Dictionary = {}
	var dirty_collision_origins: Dictionary = {}
	for cell in dirty_cells:
		if not volume.in_bounds(cell):
			rebuild()
			return
		for origin in _dirty_mesh_chunk_origins(cell):
			dirty_mesh_origins[origin] = true
		dirty_collision_origins[_chunk_origin(cell)] = true
	for origin_variant in dirty_mesh_origins.keys():
		_rebuild_mesh_chunk(origin_variant)
	for origin_variant in dirty_collision_origins.keys():
		_rebuild_collision_chunk(origin_variant)
	last_rebuild_usec = Time.get_ticks_usec() - started_usec


func rebuild() -> void:
	assert(volume != null)
	_ensure_nodes()
	var started_usec := Time.get_ticks_usec()
	if chunk_edge > 0:
		_rebuild_all_chunks()
	else:
		_rebuild_whole_volume()
	last_rebuild_usec = Time.get_ticks_usec() - started_usec


func rebuild_cell(cell: Vector3i) -> void:
	assert(volume != null and volume.in_bounds(cell))
	_ensure_nodes()
	if chunk_edge <= 0:
		rebuild()
		return
	var started_usec := Time.get_ticks_usec()
	_mesh_instance.mesh = null
	_mesh_instance.visible = false
	for origin in _dirty_mesh_chunk_origins(cell):
		_rebuild_mesh_chunk(origin)
	_rebuild_collision_chunk(_chunk_origin(cell))
	last_rebuild_usec = Time.get_ticks_usec() - started_usec


func get_collision_shape_count() -> int:
	if chunk_edge <= 0:
		return _body.get_child_count() if _body != null else 0
	var count := 0
	for body_variant in _collision_chunks.values():
		var body := body_variant as StaticBody3D
		if body != null and is_instance_valid(body):
			count += body.get_child_count()
	return count


func get_mesh_vertex_count() -> int:
	if chunk_edge <= 0:
		return _mesh_vertex_count(_mesh_instance)
	var count := 0
	for mesh_variant in _mesh_chunks.values():
		count += _mesh_vertex_count(mesh_variant as MeshInstance3D)
	return count


func get_chunk_mesh_ids_for_test() -> Dictionary:
	var result: Dictionary = {}
	for origin_variant in _mesh_chunks.keys():
		var origin: Vector3i = origin_variant
		var node := _mesh_chunks[origin] as MeshInstance3D
		if node != null and is_instance_valid(node):
			result[origin] = node.get_instance_id()
	return result


func get_chunk_collision_ids_for_test() -> Dictionary:
	var result: Dictionary = {}
	for origin_variant in _collision_chunks.keys():
		var origin: Vector3i = origin_variant
		var node := _collision_chunks[origin] as StaticBody3D
		if node != null and is_instance_valid(node):
			result[origin] = node.get_instance_id()
	return result


func _rebuild_whole_volume() -> void:
	_clear_chunk_nodes()
	_mesh_instance.visible = true
	_mesh_instance.mesh = CellMesher.build_mesh(volume)
	for child in _body.get_children():
		child.free()
	var collision_boxes := CellCollisionBoxer.build_boxes(volume, collision_mode)
	for box_info in collision_boxes:
		_add_collision_shape(_body, box_info["origin"], box_info["size"])


func _rebuild_all_chunks() -> void:
	_mesh_instance.mesh = null
	_mesh_instance.visible = false
	for child in _body.get_children():
		child.free()
	_clear_chunk_nodes()
	for origin in _chunk_origins():
		_rebuild_mesh_chunk(origin)
		_rebuild_collision_chunk(origin)


func _rebuild_mesh_chunk(origin: Vector3i) -> void:
	if _mesh_chunks.has(origin):
		var previous := _mesh_chunks[origin] as MeshInstance3D
		if previous != null and is_instance_valid(previous):
			previous.free()
		_mesh_chunks.erase(origin)
	var mesh := CellMesher.build_mesh_region(volume, origin, _chunk_end(origin))
	if mesh.get_surface_count() == 0:
		return
	var node := MeshInstance3D.new()
	node.name = "DerivedMeshChunk_%d_%d_%d" % [origin.x, origin.y, origin.z]
	node.mesh = mesh
	node.material_override = _material
	add_child(node)
	_mesh_chunks[origin] = node


func _rebuild_collision_chunk(origin: Vector3i) -> void:
	if _collision_chunks.has(origin):
		var previous := _collision_chunks[origin] as StaticBody3D
		if previous != null and is_instance_valid(previous):
			previous.free()
		_collision_chunks.erase(origin)
	var end := _chunk_end(origin)
	var local := CellVolume.new(end - origin)
	for z in range(origin.z, end.z):
		for y in range(origin.y, end.y):
			for x in range(origin.x, end.x):
				var source_cell := Vector3i(x, y, z)
				var material_id := volume.get_cell(source_cell)
				if material_id != CellVolume.EMPTY:
					local.set_cell(source_cell - origin, material_id)
	if local.count_solid() == 0:
		return
	var boxes := CellCollisionBoxer.build_boxes(local, collision_mode)
	var body := StaticBody3D.new()
	body.name = "DerivedCollisionChunk_%d_%d_%d" % [origin.x, origin.y, origin.z]
	body.position = Vector3(origin)
	add_child(body)
	for box_info in boxes:
		_add_collision_shape(body, box_info["origin"], box_info["size"])
	_collision_chunks[origin] = body


func _add_collision_shape(body: StaticBody3D, box_origin: Vector3i, box_size: Vector3i) -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(float(box_size.x), float(box_size.y), float(box_size.z))
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = box
	collision_shape.position = Vector3(float(box_origin.x), float(box_origin.y), float(box_origin.z)) + box.size * 0.5
	body.add_child(collision_shape)


func _clear_chunk_nodes() -> void:
	for node_variant in _mesh_chunks.values():
		var node := node_variant as Node
		if node != null and is_instance_valid(node):
			node.free()
	for node_variant in _collision_chunks.values():
		var node := node_variant as Node
		if node != null and is_instance_valid(node):
			node.free()
	_mesh_chunks.clear()
	_collision_chunks.clear()


func _chunk_origins() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(0, volume.size.z, chunk_edge):
		for y in range(0, volume.size.y, chunk_edge):
			for x in range(0, volume.size.x, chunk_edge):
				result.append(Vector3i(x, y, z))
	return result


func _dirty_mesh_chunk_origins(cell: Vector3i) -> Array[Vector3i]:
	var unique: Dictionary = {}
	var candidates: Array[Vector3i] = [cell]
	for offset in MatterTopology.AXIAL_NEIGHBORS:
		var neighbor := cell + offset
		if volume.in_bounds(neighbor):
			candidates.append(neighbor)
	for candidate in candidates:
		unique[_chunk_origin(candidate)] = true
	var result: Array[Vector3i] = []
	for origin_variant in unique.keys():
		result.append(origin_variant)
	return result


func _chunk_origin(cell: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(cell.x) / float(chunk_edge)) * chunk_edge,
		floori(float(cell.y) / float(chunk_edge)) * chunk_edge,
		floori(float(cell.z) / float(chunk_edge)) * chunk_edge
	)


func _chunk_end(origin: Vector3i) -> Vector3i:
	return Vector3i(
		mini(volume.size.x, origin.x + chunk_edge),
		mini(volume.size.y, origin.y + chunk_edge),
		mini(volume.size.z, origin.z + chunk_edge)
	)


func _mesh_vertex_count(mesh_instance: MeshInstance3D) -> int:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return 0
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


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
