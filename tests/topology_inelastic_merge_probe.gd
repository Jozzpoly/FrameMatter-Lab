extends SceneTree

const MERGED_SIZE := Vector3i(7, 3, 3)
const LEFT_ORIGIN := Vector3i(0, 0, 0)
const RIGHT_ORIGIN := Vector3i(3, 0, 0)
const MASS_PER_CELL := 2.3

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var left_volume := _left_volume()
	var right_volume := _right_volume()
	var merged_volume := CellVolume.new(MERGED_SIZE)
	_copy_volume(left_volume, LEFT_ORIGIN, merged_volume)
	_copy_volume(right_volume, RIGHT_ORIGIN, merged_volume)

	var common_transform := Transform3D(
		Basis.from_euler(Vector3(0.29, -0.57, 0.21)),
		Vector3(14.0, 6.0, -9.0)
	)
	var rotation := common_transform.basis.orthonormalized()

	var left_props: Dictionary = MatterMassProperties.calculate(left_volume, MASS_PER_CELL)
	var right_props: Dictionary = MatterMassProperties.calculate(right_volume, MASS_PER_CELL)
	var merged_props: Dictionary = MatterMassProperties.calculate(merged_volume, MASS_PER_CELL)

	var left_mass: float = left_props["mass"]
	var right_mass: float = right_props["mass"]
	var merged_mass: float = merged_props["mass"]

	var left_com_world: Vector3 = common_transform * (Vector3(LEFT_ORIGIN) + Vector3(left_props["center_of_mass_local"]))
	var right_com_world: Vector3 = common_transform * (Vector3(RIGHT_ORIGIN) + Vector3(right_props["center_of_mass_local"]))
	var merged_com_world: Vector3 = common_transform * Vector3(merged_props["center_of_mass_local"])

	var left_inertia_world: Basis = MatterMassProperties.world_inertia(left_props["inertia_tensor_local"], rotation)
	var right_inertia_world: Basis = MatterMassProperties.world_inertia(right_props["inertia_tensor_local"], rotation)
	var merged_inertia_world: Basis = MatterMassProperties.world_inertia(merged_props["inertia_tensor_local"], rotation)

	# Deliberately incompatible source rigid motions.
	var left_linear := Vector3(3.4, -0.7, 1.2)
	var left_angular := Vector3(0.4, -0.2, 0.7)
	var right_linear := Vector3(-1.1, 1.6, 3.0)
	var right_angular := Vector3(-0.3, 0.9, -0.15)

	var total_linear_momentum: Vector3 = left_linear * left_mass + right_linear * right_mass
	var merged_linear: Vector3 = total_linear_momentum / merged_mass

	var left_spin: Vector3 = left_inertia_world * left_angular
	var right_spin: Vector3 = right_inertia_world * right_angular
	var left_orbital: Vector3 = (left_com_world - merged_com_world).cross(left_linear * left_mass)
	var right_orbital: Vector3 = (right_com_world - merged_com_world).cross(right_linear * right_mass)
	var total_angular_momentum: Vector3 = left_spin + right_spin + left_orbital + right_orbital
	var merged_angular: Vector3 = merged_inertia_world.inverse() * total_angular_momentum

	var linear_after: Vector3 = merged_linear * merged_mass
	var angular_after: Vector3 = merged_inertia_world * merged_angular
	var linear_momentum_error: float = linear_after.distance_to(total_linear_momentum)
	var angular_momentum_error: float = angular_after.distance_to(total_angular_momentum)

	var energy_before := (
		0.5 * left_mass * left_linear.length_squared()
		+ 0.5 * left_angular.dot(left_inertia_world * left_angular)
		+ 0.5 * right_mass * right_linear.length_squared()
		+ 0.5 * right_angular.dot(right_inertia_world * right_angular)
	)
	var energy_after := (
		0.5 * merged_mass * merged_linear.length_squared()
		+ 0.5 * merged_angular.dot(merged_inertia_world * merged_angular)
	)
	var energy_loss: float = energy_before - energy_after

	var velocity_change: Dictionary = _measure_velocity_field_change(
		left_volume, LEFT_ORIGIN, left_com_world, left_linear, left_angular,
		right_volume, RIGHT_ORIGIN, right_com_world, right_linear, right_angular,
		common_transform, merged_com_world, merged_linear, merged_angular
	)
	var max_cell_delta: float = velocity_change["max"]
	var rms_cell_delta: float = velocity_change["rms"]

	_check(abs((left_mass + right_mass) - merged_mass) < 0.00001, "merged mass equals source mass")
	_check(linear_momentum_error < 0.0001, "perfectly inelastic merge conserves total linear momentum")
	_check(angular_momentum_error < 0.0001, "perfectly inelastic merge conserves total angular momentum")
	_check(energy_loss > 0.1, "incompatible rigid binding dissipates positive kinetic energy")
	_check(energy_after <= energy_before + 0.0001, "inelastic merge does not create kinetic energy")
	_check(max_cell_delta > 0.1 and rms_cell_delta > 0.1, "incompatible source velocity fields cannot both survive rigid merge")

	var world := Node3D.new()
	get_root().add_child(world)
	var merged_body := ConstructBody.new()
	merged_body.gravity_scale = 0.0
	merged_body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	merged_body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	merged_body.linear_damp = 0.0
	merged_body.angular_damp = 0.0
	merged_body.collision_layer = 0
	merged_body.collision_mask = 0
	merged_body.mass_per_cell = MASS_PER_CELL
	world.add_child(merged_body)
	merged_body.global_transform = common_transform
	merged_body.set_volume(merged_volume)
	merged_body.linear_velocity = merged_linear
	merged_body.angular_velocity = merged_angular

	var construct_mass_error: float = abs(merged_body.mass - merged_mass)
	_check(construct_mass_error < 0.0001, "ConstructBody accepts merged Matter mass within float precision")
	_check(merged_body.linear_velocity.distance_to(merged_linear) < 0.000001, "ConstructBody accepts momentum-derived linear velocity")
	_check(merged_body.angular_velocity.distance_to(merged_angular) < 0.000001, "ConstructBody accepts momentum-derived angular velocity")

	print(
		"TOPOLOGY_INELASTIC_MERGE_METRIC left_mass=%.6f right_mass=%.6f merged_mass=%.6f construct_mass_error=%.10f linear_momentum_error=%.10f angular_momentum_error=%.10f energy_before=%.6f energy_after=%.6f energy_loss=%.6f max_cell_velocity_delta=%.6f rms_cell_velocity_delta=%.6f merged_linear=%s merged_angular=%s"
		% [
			left_mass, right_mass, merged_mass, construct_mass_error,
			linear_momentum_error, angular_momentum_error,
			energy_before, energy_after, energy_loss,
			max_cell_delta, rms_cell_delta,
			merged_linear, merged_angular,
		]
	)
	_finish()


func _measure_velocity_field_change(
	left_volume: CellVolume, left_origin: Vector3i, left_com_world: Vector3, left_linear: Vector3, left_angular: Vector3,
	right_volume: CellVolume, right_origin: Vector3i, right_com_world: Vector3, right_linear: Vector3, right_angular: Vector3,
	common_transform: Transform3D, merged_com_world: Vector3, merged_linear: Vector3, merged_angular: Vector3
) -> Dictionary:
	var max_delta := 0.0
	var sum_sq := 0.0
	var count := 0
	for spec in [
		{"volume": left_volume, "origin": left_origin, "com": left_com_world, "linear": left_linear, "angular": left_angular},
		{"volume": right_volume, "origin": right_origin, "com": right_com_world, "linear": right_linear, "angular": right_angular},
	]:
		var volume: CellVolume = spec["volume"]
		var source_origin: Vector3i = spec["origin"]
		for z in range(volume.size.z):
			for y in range(volume.size.y):
				for x in range(volume.size.x):
					var cell := Vector3i(x, y, z)
					if volume.get_cell(cell) == CellVolume.EMPTY:
						continue
					var world_point: Vector3 = common_transform * (Vector3(cell + source_origin) + Vector3(0.5, 0.5, 0.5))
					var before: Vector3 = Vector3(spec["linear"]) + Vector3(spec["angular"]).cross(world_point - Vector3(spec["com"]))
					var after: Vector3 = merged_linear + merged_angular.cross(world_point - merged_com_world)
					var delta: float = before.distance_to(after)
					max_delta = max(max_delta, delta)
					sum_sq += delta * delta
					count += 1
	return {"max": max_delta, "rms": sqrt(sum_sq / float(count))}


func _left_volume() -> CellVolume:
	var volume := CellVolume.new(Vector3i(3, 3, 3))
	volume.fill_box(Vector3i.ZERO, volume.size, CellVolume.SOLID)
	volume.set_cell(Vector3i(0, 0, 0), CellVolume.EMPTY)
	volume.set_cell(Vector3i(1, 2, 2), CellVolume.EMPTY)
	return volume


func _right_volume() -> CellVolume:
	var volume := CellVolume.new(Vector3i(4, 3, 3))
	volume.fill_box(Vector3i.ZERO, volume.size, CellVolume.SOLID)
	volume.set_cell(Vector3i(3, 0, 0), CellVolume.EMPTY)
	volume.set_cell(Vector3i(2, 2, 2), CellVolume.EMPTY)
	return volume


func _copy_volume(source: CellVolume, target_origin: Vector3i, target: CellVolume) -> void:
	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var source_cell := Vector3i(x, y, z)
				var material_id: int = source.get_cell(source_cell)
				if material_id != CellVolume.EMPTY:
					target.set_cell(source_cell + target_origin, material_id)


func _finish() -> void:
	if _failures.is_empty():
		print("TOPOLOGY_INELASTIC_MERGE_PROBE_PASS: incompatible source frames collapsed into one rigid successor while conserving total linear/angular momentum and dissipating, rather than creating, kinetic energy.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_INELASTIC_MERGE_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
