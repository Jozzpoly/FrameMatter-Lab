extends SceneTree

const FLOOR_SIZE := Vector3i(14, 1, 7)
const SETTLE_FRAMES := 24
const PUSH_FRAMES := 80
const IMPACT_FRAMES := 90

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var light := await _run_push_case(1.0)
	var heavy := await _run_push_case(64.0)

	_check(int(light.contacts) > 0, "light Matter receives reciprocal contacts")
	_check(int(heavy.contacts) > 0, "heavy Matter receives reciprocal contacts")
	_check(float(light.max_impulse) <= 8.0001, "light contact impulse remains bounded")
	_check(float(heavy.max_impulse) <= 8.0001, "heavy contact impulse remains bounded")
	_check(float(light.body_dx) > 0.20, "light Matter is visibly displaced by actor contact")
	_check(
		float(light.body_dx) > float(heavy.body_dx) * 2.0,
		"light Matter moves materially farther than heavy Matter under the same actor intent"
	)
	_check(
		float(heavy.body_dx) < 0.45,
		"heavy Matter does not behave like mass-independent kinematic bulldozing"
	)

	var incoming_control := await _run_incoming_case(false)
	var incoming_reciprocal := await _run_incoming_case(true)
	_check(
		int(incoming_reciprocal.contacts) > 0,
		"incoming dynamic Matter is detected by reciprocal side-contact probe"
	)
	_check(
		float(incoming_reciprocal.actor_dx) > float(incoming_control.actor_dx) + 0.05,
		"incoming Matter produces actor displacement beyond the no-reciprocity control"
	)
	_check(
		float(incoming_reciprocal.max_impulse) <= 8.0001,
		"incoming reaction remains bounded"
	)

	print(
		"RECIPROCAL_CONTACT_METRIC light_dx=%.6f heavy_dx=%.6f light_contacts=%d heavy_contacts=%d light_max_impulse=%.6f heavy_max_impulse=%.6f incoming_control_actor_dx=%.6f incoming_actor_dx=%.6f incoming_contacts=%d incoming_max_impulse=%.6f incoming_control_body_x=%.6f incoming_body_x=%.6f"
		% [
			float(light.body_dx),
			float(heavy.body_dx),
			int(light.contacts),
			int(heavy.contacts),
			float(light.max_impulse),
			float(heavy.max_impulse),
			float(incoming_control.actor_dx),
			float(incoming_reciprocal.actor_dx),
			int(incoming_reciprocal.contacts),
			float(incoming_reciprocal.max_impulse),
			float(incoming_control.body_x),
			float(incoming_reciprocal.body_x),
		]
	)

	if _failures.is_empty():
		print("RECIPROCAL_CONTACT_PASS: query actor and dynamic Matter exchange finite mass-sensitive contact without restoring infinite CharacterBody push authority.")
		quit(0)
		return
	for failure in _failures:
		push_error("RECIPROCAL_CONTACT_FAIL: " + failure)
	quit(1)


func _run_push_case(mass_per_cell: float) -> Dictionary:
	var host := Node3D.new()
	host.name = "PushCase_%.0f" % mass_per_cell
	get_root().add_child(host)
	var floor := _make_floor(host)

	var body := _make_body(host, mass_per_cell, Vector3(4.2, 1.0, 3.0))
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 1.4
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp = 2.0

	var actor := SpaceQueryCharacter.new()
	actor.name = "ReciprocalActor"
	actor.reciprocal_dynamic_contact_enabled = true
	actor.reciprocal_actor_mass = 4.0
	actor.reciprocal_contact_coupling = 0.72
	actor.reciprocal_max_impulse = 8.0
	host.add_child(actor)
	actor.global_position = Vector3(2.25, 1.94, 3.5)

	await _advance_frames(SETTLE_FRAMES)
	_check(actor.grounded, "push case actor acquires static Matter support")

	var body_start := body.global_position
	actor.desired_local_velocity = Vector3(3.0, 0.0, 0.0)
	await _advance_frames(PUSH_FRAMES)
	actor.desired_local_velocity = Vector3.ZERO
	var result := {
		"body_dx": body.global_position.x - body_start.x,
		"contacts": actor.observed_reciprocal_contacts,
		"max_impulse": actor.observed_reciprocal_max_impulse,
		"impulse_total": actor.observed_reciprocal_impulse_total,
	}
	host.free()
	await process_frame
	return result


func _run_incoming_case(enabled: bool) -> Dictionary:
	var host := Node3D.new()
	host.name = "Incoming_%s" % str(enabled)
	get_root().add_child(host)
	var floor := _make_floor(host)

	var body := _make_body(host, 18.0, Vector3(2.0, 1.45, 3.0))
	# Incoming-contact fixture must actually reach the query actor. Keep this body
	# clear of the supporting floor so Coulomb friction cannot stop it before the
	# intended side impact.
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp = 2.0

	var actor := SpaceQueryCharacter.new()
	actor.name = "IncomingActor"
	actor.reciprocal_dynamic_contact_enabled = enabled
	actor.reciprocal_actor_mass = 4.0
	actor.reciprocal_contact_coupling = 0.72
	actor.reciprocal_max_impulse = 8.0
	host.add_child(actor)
	actor.global_position = Vector3(5.0, 1.94, 3.5)

	await _advance_frames(SETTLE_FRAMES)
	_check(actor.grounded, "incoming case actor acquires static Matter support")
	var actor_start := actor.global_position
	body.linear_velocity = Vector3(4.6, 0.0, 0.0)
	await _advance_frames(IMPACT_FRAMES)
	var result := {
		"actor_dx": actor.global_position.x - actor_start.x,
		"contacts": actor.observed_reciprocal_contacts,
		"max_impulse": actor.observed_reciprocal_max_impulse,
		"body_x": body.global_position.x,
	}
	host.free()
	await process_frame
	return result


func _make_floor(host: Node3D) -> LocalMatterSpace:
	var volume := CellVolume.new(FLOOR_SIZE)
	volume.fill_box(Vector3i.ZERO, FLOOR_SIZE, CellVolume.SOLID)
	var lineage := MatterLineageMap.new(FLOOR_SIZE)
	var token := 880001
	for z in range(FLOOR_SIZE.z):
		for x in range(FLOOR_SIZE.x):
			lineage.set_lineage(Vector3i(x, 0, z), token)
			token += 1
	var space := LocalMatterSpace.new()
	space.name = "StaticMatterFloor"
	host.add_child(space)
	space.initialize_static(volume, lineage, Transform3D.IDENTITY)
	return space


func _make_body(host: Node3D, mass_per_cell: float, position: Vector3) -> ConstructBody:
	var volume := CellVolume.new(Vector3i.ONE)
	volume.set_cell(Vector3i.ZERO, CellVolume.SOLID)
	var body := ConstructBody.new()
	body.name = "DynamicMatter_%.0f" % mass_per_cell
	body.mass_per_cell = mass_per_cell
	body.gravity_scale = 1.0
	body.can_sleep = false
	host.add_child(body)
	body.global_position = position
	body.set_volume(volume)
	return body


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
