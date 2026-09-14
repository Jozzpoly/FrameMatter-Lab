extends SceneTree

const MASS_PER_CELL := 2.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "BindingPolicyWorld"
	get_root().add_child(world)

	var left_volume := CellVolume.new(Vector3i(2, 2, 2))
	left_volume.fill_box(Vector3i.ZERO, left_volume.size, 2)
	var right_volume := CellVolume.new(Vector3i(2, 2, 2))
	right_volume.fill_box(Vector3i.ZERO, right_volume.size, 3)

	# If the two lattices were copied into one logical volume, their face contact
	# would make one connected Matter component. They nevertheless begin as two
	# explicitly separate frames/bodies.
	var combined := CellVolume.new(Vector3i(4, 2, 2))
	_copy_volume(left_volume, Vector3i.ZERO, combined)
	_copy_volume(right_volume, Vector3i(2, 0, 0), combined)
	_check(MatterTopology.extract_connected_components(combined).size() == 1, "combined candidate Matter is geometrically connected across the seam")

	var common_transform := Transform3D(
		Basis.from_euler(Vector3(0.18, -0.42, 0.27)),
		Vector3(9.0, -2.0, 6.0)
	)
	var left := _make_body(world, "BindingLeft", left_volume, common_transform)
	var right := _make_body(
		world,
		"BindingRight",
		right_volume,
		common_transform * Transform3D(Basis.IDENTITY, Vector3(2.0, 0.0, 0.0))
	)

	var left_id := left.get_instance_id()
	var right_id := right.get_instance_id()
	_check(left_id != right_id, "contact candidate begins with distinct physics-body identities")

	var left_seam_world: Vector3 = left.global_transform * Vector3(2.0, 1.0, 1.0)
	var right_seam_world: Vector3 = right.global_transform * Vector3(0.0, 1.0, 1.0)
	var seam_position_error := left_seam_world.distance_to(right_seam_world)
	_check(seam_position_error < 0.000001, "source frame surfaces are coincident at the tested seam anchor")

	# Give both bodies one common rigid velocity field around the shared seam.
	# Raw COM linear velocities intentionally differ because the COMs are on
	# opposite sides of the rotation anchor.
	var common_anchor_velocity := Vector3(1.4, -0.35, 0.9)
	var common_angular := Vector3(0.22, -0.37, 0.41)
	var left_com_world: Vector3 = left.to_global(left.matter_center_of_mass_local)
	var right_com_world: Vector3 = right.to_global(right.matter_center_of_mass_local)
	left.linear_velocity = common_anchor_velocity + common_angular.cross(left_com_world - left_seam_world)
	right.linear_velocity = common_anchor_velocity + common_angular.cross(right_com_world - right_seam_world)
	left.angular_velocity = common_angular
	right.angular_velocity = common_angular

	var raw_com_linear_difference := left.linear_velocity.distance_to(right.linear_velocity)
	var compatible_anchor_error := _velocity_at_point(left, left_seam_world).distance_to(_velocity_at_point(right, right_seam_world))
	var compatible_angular_error := left.angular_velocity.distance_to(right.angular_velocity)
	_check(raw_com_linear_difference > 0.1, "compatible rotating sources have materially different raw COM linear velocities")
	_check(compatible_anchor_error < 0.000001, "compatible rotating sources share the same seam velocity")
	_check(compatible_angular_error < 0.000001, "compatible rotating sources share angular velocity")

	var no_request_decision := ConstructBindingPolicy.decide(
		ConstructBindingPolicy.RequestMode.NONE,
		compatible_anchor_error,
		compatible_angular_error
	)
	_check(no_request_decision == ConstructBindingPolicy.Decision.KEEP_SEPARATE, "geometric connectivity and compatible motion do not bind frames without explicit intent")
	_check(left.get_instance_id() == left_id and right.get_instance_id() == right_id, "no-request decision preserves both source body identities")

	var compatible_decision := ConstructBindingPolicy.decide(
		ConstructBindingPolicy.RequestMode.COMPATIBLE_ONLY,
		compatible_anchor_error,
		compatible_angular_error
	)
	_check(compatible_decision == ConstructBindingPolicy.Decision.COMPATIBLE_REFRAME, "explicit compatible-only intent admits a lossless-compatible reframe")

	# Make the right source physically incompatible while preserving exactly the
	# same seam geometry and logical connectivity candidate.
	right.linear_velocity += Vector3(1.8, -0.4, 0.7)
	right.angular_velocity += Vector3(-0.15, 0.25, 0.35)
	var incompatible_anchor_error := _velocity_at_point(left, left_seam_world).distance_to(_velocity_at_point(right, right_seam_world))
	var incompatible_angular_error := left.angular_velocity.distance_to(right.angular_velocity)
	_check(incompatible_anchor_error > 0.1, "incompatible case has a material seam velocity discontinuity")
	_check(incompatible_angular_error > 0.1, "incompatible case has a material angular-velocity discontinuity")

	var incompatible_no_request := ConstructBindingPolicy.decide(
		ConstructBindingPolicy.RequestMode.NONE,
		incompatible_anchor_error,
		incompatible_angular_error
	)
	_check(incompatible_no_request == ConstructBindingPolicy.Decision.KEEP_SEPARATE, "incompatible contact also remains separate without bind intent")

	var rejected_decision := ConstructBindingPolicy.decide(
		ConstructBindingPolicy.RequestMode.COMPATIBLE_ONLY,
		incompatible_anchor_error,
		incompatible_angular_error
	)
	_check(rejected_decision == ConstructBindingPolicy.Decision.REJECT_INCOMPATIBLE, "compatible-only intent rejects rather than silently averages incompatible frames")
	_check(left.get_instance_id() == left_id and right.get_instance_id() == right_id, "rejected bind leaves both source body identities intact")

	var inelastic_decision := ConstructBindingPolicy.decide(
		ConstructBindingPolicy.RequestMode.ALLOW_INELASTIC,
		incompatible_anchor_error,
		incompatible_angular_error
	)
	_check(inelastic_decision == ConstructBindingPolicy.Decision.INELASTIC_BIND, "explicit inelastic permission routes incompatible sources to the dissipative bind regime")

	print(
		"TOPOLOGY_BINDING_POLICY_METRIC seam_position_error=%.10f raw_com_linear_difference=%.10f compatible_anchor_error=%.10f compatible_angular_error=%.10f incompatible_anchor_error=%.10f incompatible_angular_error=%.10f left_body_id=%d right_body_id=%d no_request=%d compatible=%d rejected=%d inelastic=%d"
		% [
			seam_position_error,
			raw_com_linear_difference,
			compatible_anchor_error,
			compatible_angular_error,
			incompatible_anchor_error,
			incompatible_angular_error,
			left_id,
			right_id,
			no_request_decision,
			compatible_decision,
			rejected_decision,
			inelastic_decision,
		]
	)

	left.free()
	right.free()
	_finish()


func _velocity_at_point(body: ConstructBody, world_point: Vector3) -> Vector3:
	var com_world: Vector3 = body.to_global(body.matter_center_of_mass_local)
	return body.linear_velocity + body.angular_velocity.cross(world_point - com_world)


func _make_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D) -> ConstructBody:
	var body := ConstructBody.new()
	body.name = body_name
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = 0
	body.collision_mask = 0
	body.mass_per_cell = MASS_PER_CELL
	world.add_child(body)
	body.global_transform = transform
	body.set_volume(volume)
	return body


func _copy_volume(source: CellVolume, target_origin: Vector3i, target: CellVolume) -> void:
	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var source_cell := Vector3i(x, y, z)
				var material_id := source.get_cell(source_cell)
				if material_id == CellVolume.EMPTY:
					continue
				target.set_cell(source_cell + target_origin, material_id)


func _finish() -> void:
	if _failures.is_empty():
		print("TOPOLOGY_BINDING_POLICY_PROBE_PASS: seam contact/connectivity did not imply rigid binding; explicit intent selected compatible reframing, rejection, or inelastic binding according to velocity-field compatibility.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_BINDING_POLICY_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
