extends SceneTree

const LEFT_SIZE := Vector3i(4, 2, 4)
const RIGHT_SIZE := Vector3i(3, 2, 4)
const MERGED_SIZE := Vector3i(7, 2, 4)
const LEFT_ORIGIN := Vector3i(0, 0, 0)
const RIGHT_ORIGIN := Vector3i(4, 0, 0)
const MASS_PER_CELL := 2.0
const ACTOR_LOCAL_START := Vector3(1.5, 3.15, 1.5)
const POST_MERGE_RIDE_FRAMES := 120

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "TopologyActorInelasticMergeWorld"
	get_root().add_child(world)

	var left_volume := CellVolume.new(LEFT_SIZE)
	left_volume.fill_box(Vector3i.ZERO, LEFT_SIZE, CellVolume.SOLID)
	var right_volume := CellVolume.new(RIGHT_SIZE)
	right_volume.fill_box(Vector3i.ZERO, RIGHT_SIZE, CellVolume.SOLID)
	var merged_volume := CellVolume.new(MERGED_SIZE)
	_copy_volume(left_volume, LEFT_ORIGIN, merged_volume)
	_copy_volume(right_volume, RIGHT_ORIGIN, merged_volume)

	var common_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, 0.41, 0.0)),
		Vector3(-6.0, 4.0, 9.0)
	)

	var left := _make_body(world, "LeftSource", left_volume, common_transform, 1)
	var right := _make_body(
		world,
		"RightSource",
		right_volume,
		common_transform * Transform3D(Basis.IDENTITY, Vector3(RIGHT_ORIGIN)),
		0
	)

	var actor := FrameProbeCharacter.new()
	actor.name = "Actor"
	world.add_child(actor)
	actor.global_position = left.to_global(ACTOR_LOCAL_START)

	var acquired := false
	for _step in range(60):
		await physics_frame
		await process_frame
		if actor.grounded and actor.support_body == left:
			acquired = true
			break

	_check(acquired, "actor acquires left source before merge")
	if not acquired:
		_finish()
		return

	# Keep the two source lattices exactly aligned while support is acquired.
	_check(left.linear_velocity.length() < 0.000001 and left.angular_velocity.length() < 0.000001, "left source stayed at rest before bind")
	_check(right.linear_velocity.length() < 0.000001 and right.angular_velocity.length() < 0.000001, "right source stayed at rest before bind")

	var actor_world_before: Vector3 = actor.global_position
	var actor_left_local_before: Vector3 = left.to_local(actor_world_before)
	var transfers_before: int = actor.observed_support_transfers
	var recontacts_before: int = actor.observed_recontacts

	var left_props: Dictionary = MatterMassProperties.calculate(left_volume, MASS_PER_CELL)
	var right_props: Dictionary = MatterMassProperties.calculate(right_volume, MASS_PER_CELL)
	var merged_props: Dictionary = MatterMassProperties.calculate(merged_volume, MASS_PER_CELL)
	var rotation: Basis = common_transform.basis.orthonormalized()

	var left_mass: float = float(left_props["mass"])
	var right_mass: float = float(right_props["mass"])
	var merged_mass: float = float(merged_props["mass"])
	var left_com_world: Vector3 = left.global_transform * Vector3(left_props["center_of_mass_local"])
	var right_com_world: Vector3 = right.global_transform * Vector3(right_props["center_of_mass_local"])
	var merged_com_world: Vector3 = common_transform * Vector3(merged_props["center_of_mass_local"])
	var left_inertia_world: Basis = MatterMassProperties.world_inertia(left_props["inertia_tensor_local"], rotation)
	var right_inertia_world: Basis = MatterMassProperties.world_inertia(right_props["inertia_tensor_local"], rotation)
	var merged_inertia_world: Basis = MatterMassProperties.world_inertia(merged_props["inertia_tensor_local"], rotation)

	# Deliberately incompatible but G3-bounded horizontal/yaw source motions.
	var left_linear := Vector3(2.8, 0.0, -1.2)
	var left_angular := Vector3(0.0, 0.65, 0.0)
	var right_linear := Vector3(-1.4, 0.0, 2.2)
	var right_angular := Vector3(0.0, -0.35, 0.0)
	left.linear_velocity = left_linear
	left.angular_velocity = left_angular
	right.linear_velocity = right_linear
	right.angular_velocity = right_angular

	var total_p: Vector3 = left_linear * left_mass + right_linear * right_mass
	var merged_linear: Vector3 = total_p / merged_mass
	var total_l_about_merged := (
		left_inertia_world * left_angular
		+ (left_com_world - merged_com_world).cross(left_linear * left_mass)
		+ right_inertia_world * right_angular
		+ (right_com_world - merged_com_world).cross(right_linear * right_mass)
	)
	var merged_angular: Vector3 = merged_inertia_world.inverse() * total_l_about_merged

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
	_check(energy_loss > 0.1, "actor merge case is a genuinely dissipative incompatible bind")
	_check(abs(merged_angular.x) < 0.00001 and abs(merged_angular.z) < 0.00001, "merged motion stays inside bounded yaw-only actor scope")

	var actor_velocity_before_bind: Vector3 = _rigid_velocity_at_point(left_linear, left_angular, left_com_world, actor_world_before)
	var actor_velocity_after_bind: Vector3 = _rigid_velocity_at_point(merged_linear, merged_angular, merged_com_world, actor_world_before)
	var bind_velocity_impulse: float = actor_velocity_before_bind.distance_to(actor_velocity_after_bind)
	_check(bind_velocity_impulse > 0.1, "merge changes the actor support velocity field materially")

	var merged := _make_body(world, "MergedSuccessor", merged_volume, common_transform, 1)
	merged.linear_velocity = merged_linear
	merged.angular_velocity = merged_angular

	var mapped_actor_local: Vector3 = merged.to_local(actor_world_before)
	var handoff_ok: bool = actor.transfer_support_frame(merged, mapped_actor_local)
	var handoff_world_jump: float = actor.global_position.distance_to(actor_world_before)
	var handoff_velocity_error: float = actor.world_velocity.distance_to(actor_velocity_after_bind)
	var mapped_local_error: float = actor.support_local_center.distance_to(mapped_actor_local)

	_check(handoff_ok, "actor accepts merged successor as explicit topology frame")
	_check(actor.observed_support_transfers == transfers_before + 1, "merge handoff increments support transfer exactly once")
	_check(actor.observed_recontacts == recontacts_before, "merge handoff is not misclassified as contact reacquisition")
	_check(handoff_world_jump < 0.0001, "inelastic merge handoff does not teleport actor")
	_check(handoff_velocity_error < 0.00001, "actor adopts successor velocity field atomically")
	_check(mapped_local_error < 0.000001, "actor stores mapped successor-local support point")

	left.free()
	right.free()

	await physics_frame
	await process_frame
	_check(actor.grounded and actor.support_body == merged, "actor remains grounded on merged successor after source removal")

	var post_merge_local_start: Vector3 = merged.to_local(actor.global_position)
	var max_post_merge_drift := 0.0
	var floor_loss := 0
	var max_linear_error := 0.0
	var max_angular_error := 0.0
	for _step in range(POST_MERGE_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now: Vector3 = merged.to_local(actor.global_position)
		var drift: float = Vector2(local_now.x - post_merge_local_start.x, local_now.z - post_merge_local_start.z).length()
		max_post_merge_drift = max(max_post_merge_drift, drift)
		if not actor.grounded or actor.support_body != merged:
			floor_loss += 1
		max_linear_error = max(max_linear_error, merged.linear_velocity.distance_to(merged_linear))
		max_angular_error = max(max_angular_error, merged.angular_velocity.distance_to(merged_angular))

	_check(floor_loss == 0, "actor keeps support through post-merge ride")
	_check(max_post_merge_drift < 0.002, "actor support-local position remains stable after inelastic merge")
	_check(max_linear_error < 0.01, "actor does not add a measurable linear kick to merged body")
	_check(max_angular_error < 0.01, "actor does not add a measurable angular kick to merged body")
	_check(abs(left_mass + right_mass - merged_mass) < 0.00001, "merged Matter mass equals source Matter mass")

	print(
		"TOPOLOGY_ACTOR_INELASTIC_MERGE_METRIC left_mass=%.6f right_mass=%.6f merged_mass=%.6f energy_loss=%.6f bind_velocity_impulse=%.6f handoff_world_jump=%.10f handoff_velocity_error=%.10f mapped_local_error=%.10f post_merge_drift=%.8f floor_loss=%d merged_linear_error=%.8f merged_angular_error=%.8f actor_left_local_before=%s actor_merged_local=%s merged_linear=%s merged_angular=%s transfers=%d"
		% [
			left_mass,
			right_mass,
			merged_mass,
			energy_loss,
			bind_velocity_impulse,
			handoff_world_jump,
			handoff_velocity_error,
			mapped_local_error,
			max_post_merge_drift,
			floor_loss,
			max_linear_error,
			max_angular_error,
			actor_left_local_before,
			mapped_actor_local,
			merged_linear,
			merged_angular,
			actor.observed_support_transfers,
		]
	)
	_finish()


func _make_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D, collision_layer_value: int) -> ConstructBody:
	var body := ConstructBody.new()
	body.name = body_name
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = collision_layer_value
	body.collision_mask = 0
	body.mass_per_cell = MASS_PER_CELL
	world.add_child(body)
	body.global_transform = transform
	body.set_volume(volume)
	return body


func _rigid_velocity_at_point(linear: Vector3, angular: Vector3, com_world: Vector3, point_world: Vector3) -> Vector3:
	return linear + angular.cross(point_world - com_world)


func _copy_volume(source: CellVolume, target_origin: Vector3i, target: CellVolume) -> void:
	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var cell := Vector3i(x, y, z)
				var material_id: int = source.get_cell(cell)
				if material_id != CellVolume.EMPTY:
					target.set_cell(cell + target_origin, material_id)


func _finish() -> void:
	if _failures.is_empty():
		print("TOPOLOGY_ACTOR_INELASTIC_MERGE_PROBE_PASS: an actor on one incompatible source frame crossed an atomic inelastic merge handoff without teleport, contact reacquisition or extra rigid-body kick.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_ACTOR_INELASTIC_MERGE_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
