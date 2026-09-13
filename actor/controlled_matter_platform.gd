class_name ControlledMatterPlatform
extends AnimatableBody3D

var volume: CellVolume
var motion_linear_velocity: Vector3 = Vector3.ZERO
var motion_angular_velocity: Vector3 = Vector3.ZERO
var _local_center: Vector3 = Vector3.ZERO


func set_volume(new_volume: CellVolume) -> void:
	volume = new_volume
	_rebuild_collision()
	_local_center = _compute_local_center()


func get_collision_shape_count() -> int:
	var count: int = 0
	for child in get_children():
		if child is CollisionShape3D:
			count += 1
	return count


func _physics_process(delta: float) -> void:
	if motion_linear_velocity.is_zero_approx() and motion_angular_velocity.is_zero_approx():
		return

	var transform_now: Transform3D = global_transform
	var center_world: Vector3 = transform_now * _local_center
	center_world += motion_linear_velocity * delta

	var angular_speed: float = motion_angular_velocity.length()
	var next_basis: Basis = transform_now.basis
	if angular_speed > 0.000001:
		var axis: Vector3 = motion_angular_velocity / angular_speed
		var delta_rotation: Basis = Basis(axis, angular_speed * delta)
		next_basis = delta_rotation * transform_now.basis

	transform_now.basis = next_basis
	transform_now.origin = center_world - next_basis * _local_center
	global_transform = transform_now


func _rebuild_collision() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.free()

	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell: Vector3i = Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var shape: BoxShape3D = BoxShape3D.new()
				shape.size = Vector3.ONE
				var collision_shape: CollisionShape3D = CollisionShape3D.new()
				collision_shape.shape = shape
				collision_shape.position = Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)
				add_child(collision_shape)


func _compute_local_center() -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				if volume.get_cell(Vector3i(x, y, z)) == CellVolume.EMPTY:
					continue
				sum += Vector3(float(x) + 0.5, float(y) + 0.5, float(z) + 0.5)
				count += 1
	if count == 0:
		return Vector3.ZERO
	return sum / float(count)
