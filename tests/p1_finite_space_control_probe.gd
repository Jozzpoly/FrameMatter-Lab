extends SceneTree

const IMPULSE := Vector3(4.0, 0.0, 0.0)
const TORQUE_IMPULSE := Vector3(0.0, 2.0, 0.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "P1FiniteSpaceControlProbe"
	get_root().add_child(host)
	var control := P1SpaceControl.new()
	host.add_child(control)

	var light := _make_space(host, "LightSpace", 1.0, Vector3(-6.0, 0.0, 0.0))
	var heavy := _make_space(host, "HeavySpace", 2.0, Vector3(6.0, 0.0, 0.0))
	await process_frame

	var light_static_transform := light.get_active_provider().global_transform
	var heavy_static_transform := heavy.get_active_provider().global_transform
	_check(control.release_space(light), "finite control releases light Space with zero launch request")
	await light.provider_transition_committed
	_check(control.release_space(heavy), "finite control releases heavy Space with zero launch request")
	await heavy.provider_transition_committed
	await physics_frame
	await process_frame

	var light_body := light.get_active_provider() as ConstructBody
	var heavy_body := heavy.get_active_provider() as ConstructBody
	_check(light_body != null and heavy_body != null, "release installs real ConstructBody providers")
	if light_body == null or heavy_body == null:
		host.free()
		_finish()
		return

	_check(light_body.global_position.distance_to(light_static_transform.origin) < 0.0001, "zero-launch release preserves light world position")
	_check(heavy_body.global_position.distance_to(heavy_static_transform.origin) < 0.0001, "zero-launch release preserves heavy world position")
	_check(light_body.linear_velocity.length() < 0.0001 and heavy_body.linear_velocity.length() < 0.0001, "release itself creates no hidden translational launch")
	_check(light_body.angular_velocity.length() < 0.0001 and heavy_body.angular_velocity.length() < 0.0001, "release itself creates no hidden angular launch")
	_check(absf(heavy_body.mass - light_body.mass * 2.0) < 0.0001, "mass_per_cell produces the intended 2x mass challenger")

	var expected_light_world_impulse := light_body.global_transform.basis.orthonormalized() * IMPULSE
	var expected_heavy_world_impulse := heavy_body.global_transform.basis.orthonormalized() * IMPULSE
	_check(control.apply_local_central_impulse(light, IMPULSE), "light Space accepts explicit finite central impulse")
	_check(control.apply_local_central_impulse(heavy, IMPULSE), "heavy Space accepts identical explicit finite central impulse")
	await physics_frame
	await process_frame

	var light_speed := light_body.linear_velocity.length()
	var heavy_speed := heavy_body.linear_velocity.length()
	_check(light_speed > 0.01 and heavy_speed > 0.01, "finite impulses produce actual rigid motion")
	var speed_ratio := light_speed / max(heavy_speed, 0.000001)
	_check(absf(speed_ratio - 2.0) < 0.05, "same impulse produces inverse-mass velocity response instead of hard-coded speed")
	_check(light_body.linear_velocity.normalized().dot(expected_light_world_impulse.normalized()) > 0.999, "local light impulse is transformed through current provider frame")
	_check(heavy_body.linear_velocity.normalized().dot(expected_heavy_world_impulse.normalized()) > 0.999, "local heavy impulse is transformed through current provider frame")

	_check(control.apply_local_torque_impulse(light, TORQUE_IMPULSE), "dynamic Space accepts explicit finite torque impulse")
	await physics_frame
	await process_frame
	_check(light_body.angular_velocity.length() > 0.001, "torque impulse creates solver-owned angular motion")

	print(
		"P1_FINITE_CONTROL_METRIC light_mass=%.3f heavy_mass=%.3f light_speed=%.6f heavy_speed=%.6f speed_ratio=%.6f angular_speed=%.6f" % [
			light_body.mass,
			heavy_body.mass,
			light_speed,
			heavy_speed,
			speed_ratio,
			light_body.angular_velocity.length(),
		]
	)

	host.free()
	_finish()


func _make_space(host: Node3D, node_name: String, mass_per_cell: float, origin: Vector3) -> LocalMatterSpace:
	var volume := CellVolume.new(Vector3i(4, 2, 4))
	volume.fill_box(Vector3i(1, 0, 1), Vector3i(3, 1, 3), CellVolume.SOLID)
	var lineage := MatterLineageMap.new(volume.size)
	var issuer := MatterLineageIssuer.new(830000 if mass_per_cell <= 1.0 else 840000)
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					lineage.set_lineage(cell, issuer.allocate())
	var space := LocalMatterSpace.new()
	space.name = node_name
	space.lineage_issuer = issuer
	space.mass_per_cell = mass_per_cell
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.0
	space.dynamic_angular_damp = 0.0
	space.dynamic_can_sleep = false
	host.add_child(space)
	space.initialize_static(volume, lineage, Transform3D(Basis(Vector3.UP, 0.41), origin))
	return space


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_FINITE_CONTROL_PASS: release has zero hidden launch and explicit impulses remain solver/mass-driven rather than hard-coded velocity control.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_FINITE_CONTROL_FAIL: " + failure)
	quit(1)
