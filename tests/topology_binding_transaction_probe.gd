extends SceneTree

const LEFT_SIZE := Vector3i(4, 2, 4)
const RIGHT_SIZE := Vector3i(3, 2, 4)
const MERGED_SIZE := Vector3i(7, 2, 4)
const RIGHT_ORIGIN := Vector3i(4, 0, 0)
const MASS_PER_CELL := 2.0
const ACTOR_LOCAL_START := Vector3(1.5, 3.15, 1.5)
const PRE_BIND_RIDE_FRAMES := 24
const POST_BIND_RIDE_FRAMES := 60

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "BindingTransactionWorld"
	get_root().add_child(world)

	var left_volume := CellVolume.new(LEFT_SIZE)
	left_volume.fill_box(Vector3i.ZERO, LEFT_SIZE, 2)
	var right_volume := CellVolume.new(RIGHT_SIZE)
	right_volume.fill_box(Vector3i.ZERO, RIGHT_SIZE, 3)
	var merged_volume := CellVolume.new(MERGED_SIZE)
	_copy_volume(left_volume, Vector3i.ZERO, merged_volume)
	_copy_volume(right_volume, RIGHT_ORIGIN, merged_volume)

	var left_lineage := MatterLineageMap.new(LEFT_SIZE)
	var right_lineage := MatterLineageMap.new(RIGHT_SIZE)
	var expected_lineage: Dictionary = {}
	var next_token := 30001
	for cell in _occupied_cells(left_volume):
		left_lineage.set_lineage(cell, next_token)
		expected_lineage[cell] = next_token
		next_token += 1
	for cell in _occupied_cells(right_volume):
		right_lineage.set_lineage(cell, next_token)
		expected_lineage[cell + RIGHT_ORIGIN] = next_token
		next_token += 1

	var initial_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, 0.37, 0.0)),
		Vector3(-7.0, 4.0, 8.0)
	)
	var left := _make_body(world, "BindLeft", left_volume, initial_transform, 1)
	var right := _make_body(
		world,
		"BindRight",
		right_volume,
		initial_transform * Transform3D(Basis.IDENTITY, Vector3(RIGHT_ORIGIN)),
		0
	)
	var left_id := left.get_instance_id()
	var right_id := right.get_instance_id()

	var common_linear := Vector3(1.1, 0.0, -0.55)
	left.linear_velocity = common_linear
	right.linear_velocity = common_linear

	var actor := FrameProbeCharacter.new()
	actor.name = "BindActor"
	world.add_child(actor)
	actor.global_position = left.to_global(ACTOR_LOCAL_START)

	var acquired := false
	for _step in range(60):
		await physics_frame
		await process_frame
		if actor.grounded and actor.support_body == left:
			acquired = true
			break
	_check(acquired, "actor acquires left source before explicit bind")
	if not acquired:
		_finish()
		return

	var pre_bind_local := left.to_local(actor.global_position)
	var max_pre_bind_drift := 0.0
	for _step in range(PRE_BIND_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := left.to_local(actor.global_position)
		max_pre_bind_drift = max(max_pre_bind_drift, Vector2(local_now.x - pre_bind_local.x, local_now.z - pre_bind_local.z).length())
	_check(max_pre_bind_drift < 0.002, "actor genuinely rides source before bind transaction")

	# Resume at physics_frame: this is before Node._physics_process and before the
	# upcoming PhysicsServer step. The replacement transaction must commit here.
	await physics_frame

	var transaction_transform: Transform3D = left.global_transform
	var expected_right_transform := transaction_transform * Transform3D(Basis.IDENTITY, Vector3(RIGHT_ORIGIN))
	var source_alignment_error := right.global_transform.origin.distance_to(expected_right_transform.origin)
	var source_angle_error := Quaternion(right.global_transform.basis.orthonormalized()).angle_to(
		Quaternion(expected_right_transform.basis.orthonormalized())
	)
	_check(source_alignment_error < 0.0001, "source lattices remain aligned at explicit bind instant")
	_check(source_angle_error < 0.0001, "source orientations remain aligned at explicit bind instant")

	var actor_world_before := actor.global_position
	var actor_local_before := left.to_local(actor_world_before)
	var transfers_before := actor.observed_support_transfers
	var recontacts_before := actor.observed_recontacts

	# Create a genuinely incompatible docking state at the explicit bind instant.
	var left_linear: Vector3 = left.linear_velocity
	var left_angular: Vector3 = left.angular_velocity
	var right_linear := Vector3(-1.6, 0.0, 2.1)
	var right_angular := Vector3(0.0, -0.42, 0.0)
	right.linear_velocity = right_linear
	right.angular_velocity = right_angular

	var seam_world: Vector3 = left.global_transform * Vector3(4.0, 1.0, 2.0)
	var anchor_velocity_error := _body_velocity_at_point(left, seam_world).distance_to(_body_velocity_at_point(right, seam_world))
	var angular_velocity_error := left.angular_velocity.distance_to(right.angular_velocity)
	var rejected := ConstructBindingPolicy.decide(
		ConstructBindingPolicy.RequestMode.COMPATIBLE_ONLY,
		anchor_velocity_error,
		angular_velocity_error
	)
	var decision := ConstructBindingPolicy.decide(
		ConstructBindingPolicy.RequestMode.ALLOW_INELASTIC,
		anchor_velocity_error,
		angular_velocity_error
	)
	_check(rejected == ConstructBindingPolicy.Decision.REJECT_INCOMPATIBLE, "same bind state is rejected under compatible-only policy")
	_check(decision == ConstructBindingPolicy.Decision.INELASTIC_BIND, "explicit policy outcome authorizes inelastic successor transaction")
	_check(anchor_velocity_error > 0.1 and angular_velocity_error > 0.1, "integrated transaction actually enters incompatible regime")

	var left_props := MatterMassProperties.calculate(left_volume, MASS_PER_CELL)
	var right_props := MatterMassProperties.calculate(right_volume, MASS_PER_CELL)
	var merged_props := MatterMassProperties.calculate(merged_volume, MASS_PER_CELL)
	var rotation := transaction_transform.basis.orthonormalized()
	var left_mass: float = left_props["mass"]
	var right_mass: float = right_props["mass"]
	var merged_mass: float = merged_props["mass"]
	var left_com_world: Vector3 = left.global_transform * Vector3(left_props["center_of_mass_local"])
	var right_com_world: Vector3 = right.global_transform * Vector3(right_props["center_of_mass_local"])
	var merged_com_world: Vector3 = transaction_transform * Vector3(merged_props["center_of_mass_local"])
	var left_inertia_world := MatterMassProperties.world_inertia(left_props["inertia_tensor_local"], rotation)
	var right_inertia_world := MatterMassProperties.world_inertia(right_props["inertia_tensor_local"], rotation)
	var merged_inertia_world := MatterMassProperties.world_inertia(merged_props["inertia_tensor_local"], rotation)

	var total_p := left_linear * left_mass + right_linear * right_mass
	var merged_linear := total_p / merged_mass
	var total_l := (
		left_inertia_world * left_angular
		+ (left_com_world - merged_com_world).cross(left_linear * left_mass)
		+ right_inertia_world * right_angular
		+ (right_com_world - merged_com_world).cross(right_linear * right_mass)
	)
	var merged_angular := merged_inertia_world.inverse() * total_l
	var reconstructed_p := merged_linear * merged_mass
	var reconstructed_l := merged_inertia_world * merged_angular
	var linear_momentum_error := reconstructed_p.distance_to(total_p)
	var angular_momentum_error := reconstructed_l.distance_to(total_l)

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
	var energy_loss := energy_before - energy_after
	_check(linear_momentum_error < 0.0001, "inelastic successor preserves total linear momentum")
	_check(angular_momentum_error < 0.001, "inelastic successor preserves total angular momentum about merged COM")
	_check(energy_loss > 0.1, "authorized incompatible bind dissipates rather than creates kinetic energy")
	_check(abs(merged_angular.x) < 0.00001 and abs(merged_angular.z) < 0.00001, "integrated actor case stays inside bounded yaw-only support scope")

	var merged_lineage := MatterLineageMap.new(MERGED_SIZE)
	for cell in _occupied_cells(left_volume):
		merged_lineage.set_lineage(cell, left_lineage.get_lineage(cell))
	for cell in _occupied_cells(right_volume):
		merged_lineage.set_lineage(cell + RIGHT_ORIGIN, right_lineage.get_lineage(cell))
	var lineage_mismatches := 0
	for merged_cell_variant in expected_lineage.keys():
		var merged_cell: Vector3i = merged_cell_variant
		if merged_lineage.get_lineage(merged_cell) != int(expected_lineage[merged_cell]):
			lineage_mismatches += 1
	_check(lineage_mismatches == 0, "binding transaction preserves every retained Matter lineage token")
	_check(merged_lineage.count_assigned() == merged_volume.count_solid(), "successor has one lineage token per retained Matter cell")

	var actor_velocity_before := _rigid_velocity(left_linear, left_angular, left_com_world, actor_world_before)
	var actor_velocity_after := _rigid_velocity(merged_linear, merged_angular, merged_com_world, actor_world_before)
	var intended_actor_velocity_change := actor_velocity_before.distance_to(actor_velocity_after)
	_check(intended_actor_velocity_change > 0.1, "bind transaction materially changes actor support velocity field")

	var successor := _make_body(world, "BindSuccessor", merged_volume, transaction_transform, 1)
	successor.linear_velocity = merged_linear
	successor.angular_velocity = merged_angular
	var successor_id := successor.get_instance_id()
	_check(successor_id != left_id and successor_id != right_id, "authorized bind replaces both source physics identities")

	var mapped_actor_local := successor.to_local(actor_world_before)
	var handoff_ok := actor.transfer_support_frame(successor, mapped_actor_local)
	var handoff_world_jump := actor.global_position.distance_to(actor_world_before)
	var handoff_velocity_error := actor.world_velocity.distance_to(actor_velocity_after)
	_check(handoff_ok, "actor accepts policy-authorized successor in same transaction")
	_check(actor.observed_support_transfers == transfers_before + 1, "integrated bind performs exactly one explicit actor support transfer")
	_check(actor.observed_recontacts == recontacts_before, "explicit bind transfer is not misclassified as contact reacquisition")
	_check(handoff_world_jump < 0.0001, "integrated bind does not teleport actor")
	_check(handoff_velocity_error < 0.00001, "integrated bind applies successor velocity field atomically")
	_check(actor.support_local_center.distance_to(mapped_actor_local) < 0.000001, "integrated bind stores mapped successor-local support point")

	var successor_origin_before_step := successor.global_transform.origin
	left.free()
	right.free()

	# Because the transaction committed from physics_frame, the new successor must
	# participate in the immediately upcoming PhysicsServer step rather than lose
	# one frame of phase.
	await process_frame
	var immediate_step_displacement := successor.global_transform.origin.distance_to(successor_origin_before_step)
	_check(immediate_step_displacement > 0.001, "pre-step successor participates in the immediately upcoming physics step")
	_check(actor.grounded and actor.support_body == successor, "actor remains grounded after the same pre-step bind transaction")

	var post_bind_local := successor.to_local(actor.global_position)
	var max_post_bind_drift := 0.0
	var floor_loss := 0
	for _step in range(POST_BIND_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := successor.to_local(actor.global_position)
		max_post_bind_drift = max(max_post_bind_drift, Vector2(local_now.x - post_bind_local.x, local_now.z - post_bind_local.z).length())
		if not actor.grounded or actor.support_body != successor:
			floor_loss += 1
	_check(floor_loss == 0, "actor keeps successor support after integrated bind")
	_check(max_post_bind_drift < 0.002, "actor stays locally stable after integrated bind")

	print(
		"TOPOLOGY_BINDING_TRANSACTION_METRIC anchor_velocity_error=%.8f angular_velocity_error=%.8f linear_momentum_error=%.10f angular_momentum_error=%.10f energy_loss=%.6f lineage_mismatches=%d handoff_world_jump=%.10f handoff_velocity_error=%.10f intended_actor_velocity_change=%.6f immediate_step_displacement=%.8f post_bind_drift=%.8f floor_loss=%d left_id=%d right_id=%d successor_id=%d actor_local_before=%s actor_local_after=%s"
		% [
			anchor_velocity_error,
			angular_velocity_error,
			linear_momentum_error,
			angular_momentum_error,
			energy_loss,
			lineage_mismatches,
			handoff_world_jump,
			handoff_velocity_error,
			intended_actor_velocity_change,
			immediate_step_displacement,
			max_post_bind_drift,
			floor_loss,
			left_id,
			right_id,
			successor_id,
			actor_local_before,
			actor.support_local_center,
		]
	)

	successor.free()
	_finish()


func _body_velocity_at_point(body: ConstructBody, world_point: Vector3) -> Vector3:
	return _rigid_velocity(body.linear_velocity, body.angular_velocity, body.to_global(body.matter_center_of_mass_local), world_point)


func _rigid_velocity(linear: Vector3, angular: Vector3, com_world: Vector3, world_point: Vector3) -> Vector3:
	return linear + angular.cross(world_point - com_world)


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					result.append(cell)
	return result


func _make_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D, layer: int) -> ConstructBody:
	var body := ConstructBody.new()
	body.name = body_name
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = layer
	body.collision_mask = layer
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
				if material_id != CellVolume.EMPTY:
					target.set_cell(source_cell + target_origin, material_id)


func _finish() -> void:
	if _failures.is_empty():
		print("TOPOLOGY_BINDING_TRANSACTION_PROBE_PASS: explicit inelastic policy outcome committed a pre-PhysicsServer two-frame bind while preserving momentum semantics, retained Matter lineage, actor continuity and immediate successor integration.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_BINDING_TRANSACTION_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
