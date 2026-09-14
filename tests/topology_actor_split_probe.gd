extends SceneTree

const VOLUME_SIZE := Vector3i(10, 3, 3)
const CUT_CELL := Vector3i(4, 1, 1)
const ACTOR_LOCAL_START := Vector3(1.5, 4.15, 1.5)
const MASS_PER_CELL := 2.0
const POST_SPLIT_RIDE_FRAMES := 120

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "TopologyActorSplitWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(VOLUME_SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 3, 3), CellVolume.SOLID)
	volume.fill_box(Vector3i(6, 0, 0), Vector3i(10, 3, 3), CellVolume.SOLID)
	for x in range(3, 6):
		volume.set_cell(Vector3i(x, 1, 1), CellVolume.SOLID)

	var parent := ConstructBody.new()
	parent.name = "ParentConstruct"
	parent.gravity_scale = 0.0
	parent.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	parent.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	parent.linear_damp = 0.0
	parent.angular_damp = 0.0
	parent.mass_per_cell = MASS_PER_CELL
	world.add_child(parent)
	parent.position = Vector3(-4.0, 5.0, 7.0)
	parent.rotation = Vector3(0.0, 0.42, 0.0)
	parent.set_volume(volume)
	parent.linear_velocity = Vector3(2.2, 0.0, -1.4)
	parent.angular_velocity = Vector3(0.0, 0.65, 0.0)

	var actor := FrameProbeCharacter.new()
	actor.name = "Actor"
	world.add_child(actor)
	actor.global_position = parent.to_global(ACTOR_LOCAL_START)

	var acquired := false
	for _step in range(60):
		await physics_frame
		await process_frame
		if actor.grounded and actor.support_body == parent:
			acquired = true
			break

	_check(acquired, "actor acquires the unsplit parent frame")
	if not acquired:
		_finish()
		return

	var max_pre_split_drift := 0.0
	var pre_split_local: Vector3 = parent.to_local(actor.global_position)
	for _step in range(60):
		await physics_frame
		await process_frame
		var local_now: Vector3 = parent.to_local(actor.global_position)
		max_pre_split_drift = max(max_pre_split_drift, Vector2(local_now.x - pre_split_local.x, local_now.z - pre_split_local.z).length())
		_check(actor.grounded and actor.support_body == parent, "actor remains on parent before split")

	var parent_transform: Transform3D = parent.global_transform
	var parent_linear: Vector3 = parent.linear_velocity
	var parent_angular: Vector3 = parent.angular_velocity
	var parent_com_local: Vector3 = parent.observed_center_of_mass_local
	var parent_com_world: Vector3 = parent_transform * parent_com_local
	var actor_world_before_split: Vector3 = actor.global_position
	var actor_local_before_split: Vector3 = parent.to_local(actor.global_position)
	var recontacts_before: int = actor.observed_recontacts

	_check(volume.set_cell(CUT_CELL, CellVolume.EMPTY), "split edit removes bridge Matter")
	var components: Array[CellVolume] = MatterTopology.extract_connected_components(volume)
	_check(components.size() == 2, "split edit creates two components")

	var children: Array[ConstructBody] = []
	var expected_child_linear: Array[Vector3] = []
	for index in range(components.size()):
		var component: CellVolume = components[index]
		var child := ConstructBody.new()
		child.name = "Child_%d" % index
		child.gravity_scale = 0.0
		child.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		child.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		child.linear_damp = 0.0
		child.angular_damp = 0.0
		child.mass_per_cell = MASS_PER_CELL
		world.add_child(child)
		child.global_transform = parent_transform
		child.set_volume(component)

		var child_com_local: Vector3 = MatterTopology.center_of_mass_local(component)
		var child_com_world: Vector3 = parent_transform * child_com_local
		var inherited_linear: Vector3 = parent_linear + parent_angular.cross(child_com_world - parent_com_world)
		child.linear_velocity = inherited_linear
		child.angular_velocity = parent_angular
		children.append(child)
		expected_child_linear.append(inherited_linear)

	# Scan order guarantees Child_0 contains the left block where the actor stands.
	var expected_support: ConstructBody = children[0]
	_check(expected_support.volume.get_cell(Vector3i(1, 1, 1)) != CellVolume.EMPTY, "expected child contains actor-side Matter")
	parent.free()

	var transition_frames := -1
	var max_transition_world_step := 0.0
	var previous_actor_world: Vector3 = actor_world_before_split
	for step in range(8):
		await physics_frame
		await process_frame
		max_transition_world_step = max(max_transition_world_step, actor.global_position.distance_to(previous_actor_world))
		previous_actor_world = actor.global_position
		if actor.grounded and actor.support_body == expected_support:
			transition_frames = step + 1
			break

	_check(transition_frames > 0, "actor reacquires the child frame after parent removal")
	_check(transition_frames <= 3, "support transition resolves within three physics frames")
	_check(actor.observed_recontacts > recontacts_before, "support transition is recorded as a new frame acquisition")
	_check(actor.support_body == expected_support, "actor transitions to the child containing its supporting Matter")
	_check(max_transition_world_step < 0.2, "support transition does not teleport the actor")

	var child_local_after_transition := Vector3.ZERO
	var split_local_error := 999.0
	if transition_frames > 0:
		child_local_after_transition = expected_support.to_local(actor.global_position)
		split_local_error = Vector2(
			child_local_after_transition.x - actor_local_before_split.x,
			child_local_after_transition.z - actor_local_before_split.z
		).length()
	_check(split_local_error < 0.05, "actor preserves its horizontal local-frame position across split")

	var post_split_local_start: Vector3 = expected_support.to_local(actor.global_position)
	var max_post_split_drift := 0.0
	var post_split_floor_loss := 0
	var max_support_linear_error := 0.0
	var max_support_angular_error := 0.0

	for _step in range(POST_SPLIT_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now: Vector3 = expected_support.to_local(actor.global_position)
		var drift: float = Vector2(local_now.x - post_split_local_start.x, local_now.z - post_split_local_start.z).length()
		max_post_split_drift = max(max_post_split_drift, drift)
		if not actor.grounded or actor.support_body != expected_support:
			post_split_floor_loss += 1
		max_support_linear_error = max(max_support_linear_error, expected_support.linear_velocity.distance_to(expected_child_linear[0]))
		max_support_angular_error = max(max_support_angular_error, expected_support.angular_velocity.distance_to(parent_angular))

	_check(post_split_floor_loss == 0, "actor remains on the selected child after transition")
	_check(max_post_split_drift < 0.002, "actor has stable support-local coordinates after split")
	_check(max_support_linear_error < 0.01, "actor does not perturb selected child linear velocity")
	_check(max_support_angular_error < 0.01, "actor does not perturb selected child angular velocity")

	print(
		"TOPOLOGY_ACTOR_SPLIT_METRIC pre_split_drift=%.8f transition_frames=%d max_transition_world_step=%.8f split_local_error=%.8f post_split_drift=%.8f post_floor_loss=%d support_linear_error=%.8f support_angular_error=%.8f local_before=%s local_after=%s support_cells=%d sibling_cells=%d"
		% [
			max_pre_split_drift,
			transition_frames,
			max_transition_world_step,
			split_local_error,
			max_post_split_drift,
			post_split_floor_loss,
			max_support_linear_error,
			max_support_angular_error,
			actor_local_before_split,
			child_local_after_transition,
			expected_support.volume.count_solid(),
			children[1].volume.count_solid(),
		]
	)

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("TOPOLOGY_ACTOR_SPLIT_PROBE_PASS: actor support migrated from a removed parent frame to the correct dynamic child without teleport, fall, or rigid-body kick.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_ACTOR_SPLIT_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
