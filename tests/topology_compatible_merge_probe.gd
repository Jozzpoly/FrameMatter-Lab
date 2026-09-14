extends SceneTree

const MERGED_SIZE := Vector3i(7, 3, 3)
const LEFT_ORIGIN := Vector3i(0, 0, 0)
const RIGHT_ORIGIN := Vector3i(3, 0, 0)
const MASS_PER_CELL := 2.3

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "CompatibleMergeWorld"
	get_root().add_child(world)

	var left_volume := CellVolume.new(Vector3i(3, 3, 3))
	left_volume.fill_box(Vector3i.ZERO, left_volume.size, CellVolume.SOLID)
	left_volume.set_cell(Vector3i(0, 0, 0), CellVolume.EMPTY)
	left_volume.set_cell(Vector3i(1, 2, 2), CellVolume.EMPTY)

	var right_volume := CellVolume.new(Vector3i(4, 3, 3))
	right_volume.fill_box(Vector3i.ZERO, right_volume.size, CellVolume.SOLID)
	right_volume.set_cell(Vector3i(3, 0, 0), CellVolume.EMPTY)
	right_volume.set_cell(Vector3i(2, 2, 2), CellVolume.EMPTY)

	var merged_volume := CellVolume.new(MERGED_SIZE)
	_copy_volume(left_volume, LEFT_ORIGIN, merged_volume)
	_copy_volume(right_volume, RIGHT_ORIGIN, merged_volume)

	_check(merged_volume.count_solid() == left_volume.count_solid() + right_volume.count_solid(), "merge retains every source Matter cell without overlap")
	_check(MatterTopology.extract_connected_components(merged_volume).size() == 1, "merged Matter is one connected component")

	var common_transform := Transform3D(
		Basis.from_euler(Vector3(0.23, -0.61, 0.17)),
		Vector3(17.0, -3.0, 11.0)
	)
	var common_origin_world: Vector3 = common_transform.origin
	var common_origin_velocity := Vector3(1.9, -0.4, 2.6)
	var common_angular := Vector3(0.31, -0.58, 0.44)

	var left := _make_body(world, "LeftSource", left_volume, common_transform * Transform3D(Basis.IDENTITY, Vector3(LEFT_ORIGIN)))
	var right := _make_body(world, "RightSource", right_volume, common_transform * Transform3D(Basis.IDENTITY, Vector3(RIGHT_ORIGIN)))

	var left_com_local: Vector3 = MatterTopology.center_of_mass_local(left_volume)
	var right_com_local: Vector3 = MatterTopology.center_of_mass_local(right_volume)
	var left_com_world: Vector3 = left.global_transform * left_com_local
	var right_com_world: Vector3 = right.global_transform * right_com_local
	left.linear_velocity = _velocity_at_point(common_origin_velocity, common_angular, common_origin_world, left_com_world)
	right.linear_velocity = _velocity_at_point(common_origin_velocity, common_angular, common_origin_world, right_com_world)
	left.angular_velocity = common_angular
	right.angular_velocity = common_angular

	var merged := _make_body(world, "MergedConstruct", merged_volume, common_transform)
	var merged_com_local: Vector3 = MatterTopology.center_of_mass_local(merged_volume)
	var merged_com_world: Vector3 = merged.global_transform * merged_com_local
	merged.linear_velocity = _velocity_at_point(common_origin_velocity, common_angular, common_origin_world, merged_com_world)
	merged.angular_velocity = common_angular

	var max_world_cell_error := 0.0
	var max_velocity_field_error := 0.0

	max_world_cell_error = max(max_world_cell_error, _measure_source_mapping(
		left,
		left_volume,
		LEFT_ORIGIN,
		left_com_world,
		merged,
		merged_com_world,
		common_angular,
		merged_volume,
		true
	))
	max_velocity_field_error = max(max_velocity_field_error, _last_velocity_error)

	max_world_cell_error = max(max_world_cell_error, _measure_source_mapping(
		right,
		right_volume,
		RIGHT_ORIGIN,
		right_com_world,
		merged,
		merged_com_world,
		common_angular,
		merged_volume,
		true
	))
	max_velocity_field_error = max(max_velocity_field_error, _last_velocity_error)

	var source_linear_momentum: Vector3 = left.linear_velocity * left.mass + right.linear_velocity * right.mass
	var merged_linear_momentum: Vector3 = merged.linear_velocity * merged.mass
	var linear_momentum_error: float = source_linear_momentum.distance_to(merged_linear_momentum)
	var source_mass_error: float = abs((left.mass + right.mass) - merged.mass)

	_check(max_world_cell_error < 0.00001, "compatible merge preserves every source cell world position")
	_check(max_velocity_field_error < 0.00001, "compatible merge preserves the common instantaneous velocity field")
	_check(source_mass_error < 0.00001, "compatible merge preserves retained Matter mass")
	_check(linear_momentum_error < 0.0001, "compatible merge preserves total linear momentum")

	left.free()
	right.free()

	await physics_frame
	await process_frame

	var solver_com_error: float = merged.observed_center_of_mass_local.distance_to(merged_com_local)
	_check(solver_com_error < 0.00001, "merged solver COM matches Matter COM")
	_check(merged.angular_velocity.distance_to(common_angular) < 0.00001, "merged body retains compatible angular velocity")

	print(
		"TOPOLOGY_COMPATIBLE_MERGE_METRIC left_cells=%d right_cells=%d merged_cells=%d world_cell_error=%.10f velocity_field_error=%.10f mass_error=%.10f linear_momentum_error=%.10f solver_com_error=%.10f merged_linear=%s merged_angular=%s"
		% [
			left_volume.count_solid(),
			right_volume.count_solid(),
			merged_volume.count_solid(),
			max_world_cell_error,
			max_velocity_field_error,
			source_mass_error,
			linear_momentum_error,
			solver_com_error,
			merged.linear_velocity,
			merged.angular_velocity,
		]
	)

	_finish()


var _last_velocity_error := 0.0


func _measure_source_mapping(
	source_body: ConstructBody,
	source_volume: CellVolume,
	source_origin: Vector3i,
	source_com_world: Vector3,
	merged_body: ConstructBody,
	merged_com_world: Vector3,
	angular_velocity: Vector3,
	merged_volume: CellVolume,
	verify_material: bool
) -> float:
	var max_world_error := 0.0
	var max_velocity_error := 0.0
	for z in range(source_volume.size.z):
		for y in range(source_volume.size.y):
			for x in range(source_volume.size.x):
				var local_cell := Vector3i(x, y, z)
				var material_id: int = source_volume.get_cell(local_cell)
				if material_id == CellVolume.EMPTY:
					continue
				var merged_cell: Vector3i = local_cell + source_origin
				if verify_material:
					_check(merged_volume.get_cell(merged_cell) == material_id, "source material identity survives merge mapping")

				var source_world: Vector3 = source_body.global_transform * (Vector3(local_cell) + Vector3(0.5, 0.5, 0.5))
				var merged_world: Vector3 = merged_body.global_transform * (Vector3(merged_cell) + Vector3(0.5, 0.5, 0.5))
				max_world_error = max(max_world_error, source_world.distance_to(merged_world))

				var source_velocity: Vector3 = source_body.linear_velocity + angular_velocity.cross(source_world - source_com_world)
				var merged_velocity: Vector3 = merged_body.linear_velocity + angular_velocity.cross(merged_world - merged_com_world)
				max_velocity_error = max(max_velocity_error, source_velocity.distance_to(merged_velocity))

	_last_velocity_error = max_velocity_error
	return max_world_error


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
				var material_id: int = source.get_cell(source_cell)
				if material_id == CellVolume.EMPTY:
					continue
				target.set_cell(source_cell + target_origin, material_id)


func _velocity_at_point(linear_at_origin: Vector3, angular: Vector3, origin_world: Vector3, point_world: Vector3) -> Vector3:
	return linear_at_origin + angular.cross(point_world - origin_world)


func _finish() -> void:
	if _failures.is_empty():
		print("TOPOLOGY_COMPATIBLE_MERGE_PROBE_PASS: two aligned co-moving Matter frames merged into one rigid frame without world-space, velocity-field, mass or linear-momentum discontinuity.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_COMPATIBLE_MERGE_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
