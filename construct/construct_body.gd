class_name ConstructBody
extends RigidBody3D

const MIN_BODY_MASS := 0.001

var volume: CellVolume
var mass_per_cell := 1.0
var collision_mode := CellCollisionBoxer.Mode.PER_CELL
var last_rebuild_usec := 0

# Authoritative equal-density Matter COM, available synchronously as soon as
# derived state is rebuilt. Frame/topology kinematics must not depend on the
# one-physics-step-later solver observation below.
var matter_center_of_mass_local := Vector3.ZERO

# Solver-observed values are telemetry/validation, not synchronous topology
# authority. They update from PhysicsDirectBodyState3D in _integrate_forces().
var observed_center_of_mass_local := Vector3.ZERO
var observed_inverse_inertia := Vector3.ZERO
var observed_inverse_inertia_tensor := Basis.IDENTITY
var observed_inverse_mass := 0.0

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D


func set_volume(new_volume: CellVolume) -> void:
	volume = new_volume
	_ensure_mesh_node()
	rebuild_derived()


func rebuild_derived() -> void:
	assert(volume != null)
	_ensure_mesh_node()
	var started_usec := Time.get_ticks_usec()

	_mesh_instance.mesh = CellMesher.build_mesh(volume)

	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
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
		add_child(collision_shape)

	_refresh_mass_properties()
	last_rebuild_usec = Time.get_ticks_usec() - started_usec


func get_collision_shape_count() -> int:
	var count := 0
	for child in get_children():
		if child is CollisionShape3D:
			count += 1
	return count


func get_mesh_vertex_count() -> int:
	if _mesh_instance == null or _mesh_instance.mesh == null:
		return 0
	if _mesh_instance.mesh.get_surface_count() == 0:
		return 0
	return _mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()


func _refresh_mass_properties() -> void:
	var solid_count := volume.count_solid()
	mass = max(float(solid_count) * mass_per_cell, MIN_BODY_MASS)
	matter_center_of_mass_local = MatterTopology.center_of_mass_local(volume)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO
	inertia = Vector3.ZERO
	PhysicsServer3D.body_reset_mass_properties(get_rid())
	sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	observed_center_of_mass_local = state.center_of_mass_local
	observed_inverse_inertia = state.inverse_inertia
	observed_inverse_inertia_tensor = state.inverse_inertia_tensor
	observed_inverse_mass = state.inverse_mass


func _ensure_mesh_node() -> void:
	if _mesh_instance != null:
		return
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "DerivedMesh"
	add_child(_mesh_instance)

	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.74, 0.79, 0.88)
	_material.roughness = 0.78
	_mesh_instance.material_override = _material
