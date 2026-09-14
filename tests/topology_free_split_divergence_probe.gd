extends SceneTree

const MERGED_SIZE := Vector3i(7, 3, 3)
const LEFT_ORIGIN := Vector3i(0, 0, 0)
const RIGHT_ORIGIN := Vector3i(3, 0, 0)
const MASS_PER_CELL := 2.3
const FREE_FRAMES := 120

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "FreeSplitDivergenceWorld"
	get_root().add_child(world)

	var left_volume := _left_volume()
	var right_volume := _right_volume()
	var merged_volume := CellVolume.new(MERGED_SIZE)
	_copy_volume(left_volume, LEFT_ORIGIN, merged_volume)
	_copy_volume(right_volume, RIGHT_ORIGIN, merged_volume)

	var common_transform := Transform3D(
		Basis.from_euler(Vector3(0.31, -0.49, 0.22)),
		Vector3(12.0, 5.0, -8.0)
	)
	var origin_velocity := Vector3(1.6, -0.3, 2.1)
	var common_angular := Vector3(0.60, -0.40, 0.85)

	var left_props: Dictionary = MatterMassProperties.calculate(left_volume, MASS_PER_CELL)
	var right_props: Dictionary = MatterMassProperties.calculate(right_volume, MASS_PER_CELL)
	var merged_props: Dictionary = MatterMassProperties.calculate(merged_volume, MASS_PER_CELL)

	var merged_com_world: Vector3 = common_transform * Vector3(merged_props["center_of_mass_local"])
	var merged_linear: Vector3 = _velocity_at_point(origin_velocity, common_angular, common_transform.origin, merged_com_world)
	var merged_inertia_world: Basis = MatterMassProperties.world_inertia(merged_props["inertia_tensor_local"], common_transform.basis)
	var parent_p: Vector3 = merged_linear * float(merged_props["mass"])
	var parent_l: Vector3 = merged_inertia_world * common_angular + merged_com_world.cross(parent_p)
	var parent_energy: float = _body_energy(float(merged_props["mass"]), merged_linear, merged_inertia_world, common_angular)

	var left := _make_child(world, "LeftChild", left_volume, common_transform * Transform3D(Basis.IDENTITY, Vector3(LEFT_ORIGIN)))
	var right := _make_child(world, "RightChild", right_volume, common_transform * Transform3D(Basis.IDENTITY, Vector3(RIGHT_ORIGIN)))

	var left_com_world: Vector3 = left.global_transform * Vector3(left_props["center_of_mass_local"])
	var right_com_world: Vector3 = right.global_transform * Vector3(right_props["center_of_mass_local"])
	left.linear_velocity = _velocity_at_point(origin_velocity, common_angular, common_transform.origin, left_com_world)
	right.linear_velocity = _velocity_at_point(origin_velocity, common_angular, common_transform.origin, right_com_world)
	left.angular_velocity = common_angular
	right.angular_velocity = common_angular

	var initial_metrics: Dictionary = _system_metrics(left, left_props, right, right_props)
	var initial_p_error: float = Vector3(initial_metrics["p"]).distance_to(parent_p)
	var initial_l_error: float = Vector3(initial_metrics["l"]).distance_to(parent_l)
	var initial_energy_error: float = abs(float(initial_metrics["energy"]) - parent_energy)

	_check(initial_p_error < 0.0002, "instantaneous split preserves parent linear momentum")
	_check(initial_l_error < 0.0002, "instantaneous split preserves parent angular momentum")
	_check(initial_energy_error < 0.001, "instantaneous split preserves parent kinetic energy")

	var initial_alignment: Dictionary = _alignment_metrics(left, left_props, right, right_props)
	_check(float(initial_alignment["frame_origin_gap"]) < 0.00001, "successor frames begin with one common frame origin")
	_check(float(initial_alignment["frame_angle_gap"]) < 0.00001, "successor frames begin with one common frame orientation")
	_check(float(initial_alignment["seam_gap"]) < 0.00001, "successor seam begins coincident")
	_check(float(initial_alignment["seam_velocity_gap"]) < 0.00001, "successor seam begins with one common velocity field")

	var max_seam_gap := 0.0
	var max_angle_gap := 0.0
	var max_velocity_gap := 0.0
	for _step in range(FREE_FRAMES):
		await physics_frame
		await process_frame
		var alignment := _alignment_metrics(left, left_props, right, right_props)
		max_seam_gap = max(max_seam_gap, float(alignment["seam_gap"]))
		max_angle_gap = max(max_angle_gap, float(alignment["frame_angle_gap"]))
		max_velocity_gap = max(max_velocity_gap, float(alignment["seam_velocity_gap"]))

	var final_alignment: Dictionary = _alignment_metrics(left, left_props, right, right_props)
	var final_metrics: Dictionary = _system_metrics(left, left_props, right, right_props)
	var p_error: float = Vector3(final_metrics["p"]).distance_to(Vector3(initial_metrics["p"]))
	var l_error: float = Vector3(final_metrics["l"]).distance_to(Vector3(initial_metrics["l"]))
	var energy_error: float = abs(float(final_metrics["energy"]) - float(initial_metrics["energy"]))
	var p_relative: float = p_error / max(Vector3(initial_metrics["p"]).length(), 1.0)
	var l_relative: float = l_error / max(Vector3(initial_metrics["l"]).length(), 1.0)
	var energy_relative: float = energy_error / max(abs(float(initial_metrics["energy"])), 1.0)

	_check(max_seam_gap > 0.01, "free successors physically diverge at their former seam")
	_check(max_angle_gap > 0.001, "free successors no longer share one rigid-frame orientation")
	_check(max_velocity_gap > 0.01, "free successors develop incompatible seam velocity fields")
	_check(p_relative < 0.0001, "collisionless free successors conserve total linear momentum")
	_check(l_relative < 0.005, "collisionless free successors keep total angular momentum bounded")
	_check(energy_relative < 0.005, "collisionless free successors keep total kinetic energy bounded")

	print(
		"TOPOLOGY_FREE_SPLIT_DIVERGENCE_METRIC frames=%d initial_p_error=%.10f initial_l_error=%.10f initial_energy_error=%.10f final_frame_origin_gap=%.6f final_frame_angle_gap=%.6f final_seam_gap=%.6f final_seam_velocity_gap=%.6f max_frame_angle_gap=%.6f max_seam_gap=%.6f max_seam_velocity_gap=%.6f p_relative_error=%.10f l_relative_error=%.10f energy_relative_error=%.10f left_angular=%s right_angular=%s"
		% [
			FREE_FRAMES,
			initial_p_error,
			initial_l_error,
			initial_energy_error,
			float(final_alignment["frame_origin_gap"]),
			float(final_alignment["frame_angle_gap"]),
			float(final_alignment["seam_gap"]),
			float(final_alignment["seam_velocity_gap"]),
			max_angle_gap,
			max_seam_gap,
			max_velocity_gap,
			p_relative,
			l_relative,
			energy_relative,
			left.angular_velocity,
			right.angular_velocity,
		]
	)

	_finish()


func _system_metrics(left: ConstructBody, left_props: Dictionary, right: ConstructBody, right_props: Dictionary) -> Dictionary:
	var total_p := Vector3.ZERO
	var total_l := Vector3.ZERO
	var total_energy := 0.0
	for spec in [
		{"body": left, "props": left_props},
		{"body": right, "props": right_props},
	]:
		var body: ConstructBody = spec["body"]
		var props: Dictionary = spec["props"]
		var mass: float = float(props["mass"])
		var com_world: Vector3 = body.global_transform * Vector3(props["center_of_mass_local"])
		var inertia_world: Basis = MatterMassProperties.world_inertia(props["inertia_tensor_local"], body.global_transform.basis)
		var p: Vector3 = body.linear_velocity * mass
		total_p += p
		total_l += inertia_world * body.angular_velocity + com_world.cross(p)
		total_energy += _body_energy(mass, body.linear_velocity, inertia_world, body.angular_velocity)
	return {"p": total_p, "l": total_l, "energy": total_energy}


func _alignment_metrics(left: ConstructBody, left_props: Dictionary, right: ConstructBody, right_props: Dictionary) -> Dictionary:
	var left_frame: Transform3D = left.global_transform * Transform3D(Basis.IDENTITY, -Vector3(LEFT_ORIGIN))
	var right_frame: Transform3D = right.global_transform * Transform3D(Basis.IDENTITY, -Vector3(RIGHT_ORIGIN))
	var frame_origin_gap: float = left_frame.origin.distance_to(right_frame.origin)
	var left_q := Quaternion(left_frame.basis.orthonormalized())
	var right_q := Quaternion(right_frame.basis.orthonormalized())
	var frame_angle_gap: float = left_q.angle_to(right_q)

	var left_seam_local := Vector3(3.0, 1.5, 1.5)
	var right_seam_local := Vector3(0.0, 1.5, 1.5)
	var left_seam_world: Vector3 = left.global_transform * left_seam_local
	var right_seam_world: Vector3 = right.global_transform * right_seam_local
	var seam_gap: float = left_seam_world.distance_to(right_seam_world)

	var left_com_world: Vector3 = left.global_transform * Vector3(left_props["center_of_mass_local"])
	var right_com_world: Vector3 = right.global_transform * Vector3(right_props["center_of_mass_local"])
	var left_seam_velocity: Vector3 = _velocity_at_point(left.linear_velocity, left.angular_velocity, left_com_world, left_seam_world)
	var right_seam_velocity: Vector3 = _velocity_at_point(right.linear_velocity, right.angular_velocity, right_com_world, right_seam_world)
	var seam_velocity_gap: float = left_seam_velocity.distance_to(right_seam_velocity)

	return {
		"frame_origin_gap": frame_origin_gap,
		"frame_angle_gap": frame_angle_gap,
		"seam_gap": seam_gap,
		"seam_velocity_gap": seam_velocity_gap,
	}


func _body_energy(mass: float, linear: Vector3, inertia_world: Basis, angular: Vector3) -> float:
	return 0.5 * mass * linear.length_squared() + 0.5 * angular.dot(inertia_world * angular)


func _velocity_at_point(linear: Vector3, angular: Vector3, com_world: Vector3, point_world: Vector3) -> Vector3:
	return linear + angular.cross(point_world - com_world)


func _make_child(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D) -> ConstructBody:
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
		print("TOPOLOGY_FREE_SPLIT_DIVERGENCE_PROBE_PASS: an instantaneous momentum/energy-preserving split produced successors that later became physically incompatible free frames while the isolated system kept conserved quantities bounded.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_FREE_SPLIT_DIVERGENCE_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
