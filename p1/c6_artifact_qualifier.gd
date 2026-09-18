extends RefCounted

const ACQUIRE_FRAMES := 24
const DRIVE_FRAMES := 80
const POST_EDIT_FRAMES := 20
const TARGET_CELL := Vector3i(15, 5, 16)
const NON_ENDPOINT_SOURCE_CELL := Vector3i(20, 5, 19)
const SCAN_STEP := 24
const ORBITS := [
	[0.72, 0.48, 7.2],
	[0.35, 0.48, 7.2],
	[1.10, 0.48, 7.2],
	[0.72, 0.62, 7.2],
	[0.20, 0.62, 9.0],
	[1.20, 0.62, 9.0],
	[-0.35, 0.55, 10.0],
	[1.55, 0.55, 10.0],
]

var _failures: Array[String] = []
var _evidence_dir := ""


func run(root: Node) -> Dictionary:
	_evidence_dir = OS.get_environment("C6_EXPORTED_EVIDENCE_DIR")
	if not _evidence_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_evidence_dir)

	await _advance(root, ACQUIRE_FRAMES)

	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	var player := root.call("get_player") as SpaceQueryCharacter
	var camera_rig := root.call("get_camera_rig") as P1CameraRig
	var interactor := root.call("get_interactor") as P1MatterInteractor
	var registry := root.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry

	_check(world != null and player != null and camera_rig != null and interactor != null and registry != null, "exported C6 resolves real scene roles")
	_check(player != null and player.grounded and player.support_space == world, "exported C6 begins with actor grounded on ordinary WORLD")
	_check(InputMap.has_action("p1_structural_seam"), "exported C6 retains structural-seam InputMap action")
	_check(_action_has_h_key(), "exported C6 retains physical H binding")
	if not _failures.is_empty():
		return _report(false)

	var found := await _find_visible_target(root, world, camera_rig, interactor)
	_check(not found.is_empty(), "exported rendered scene exposes the intended WORLD seam target through production pointer resolution")
	if found.is_empty():
		return _report(false)

	var screen: Vector2 = found["screen"]
	interactor.update_target_from_pointer_position(screen)
	_check(interactor.target_space == world and interactor.target_valid, "exported pointer target is live ordinary WORLD Matter")
	_check(interactor.remove_cell == TARGET_CELL, "exported pointer resolves exact structural-seam target cell")
	if not _failures.is_empty():
		return _report(false)

	await _capture(root, "00_exported_seam_target")

	var occupied_before := world.volume.count_solid()
	var actor_world_before := player.global_position
	var request_frame := Engine.get_physics_frames()

	Input.warp_mouse(screen)
	await root.get_tree().process_frame
	var viewport := camera_rig.get_camera().get_viewport()
	var live_pointer := viewport.get_mouse_position()
	_check(live_pointer.distance_to(screen) <= 2.0, "exported OS pointer aligns with qualified world target")

	var press := InputEventKey.new()
	press.keycode = KEY_H
	press.physical_keycode = KEY_H
	press.pressed = true
	Input.parse_input_event(press)
	await root.get_tree().process_frame

	var release := InputEventKey.new()
	release.keycode = KEY_H
	release.physical_keycode = KEY_H
	release.pressed = false
	Input.parse_input_event(release)

	var authoring: Dictionary = root.call("get_c6_last_authoring_result_for_test")
	_check(bool(authoring.get("accepted", false)), "exported actual H input reaches structural-seam authoring")
	_check(int(authoring.get("candidate_count", 0)) == 1, "exported pointer/H resolves exactly one bounded structural-law candidate")
	_check(world.volume.count_solid() == occupied_before, "exported seam authoring changes meaning without destroying Matter")
	var committed_during_input_turn := bool(root.call("has_c6_active_relation_for_test"))
	_check(
		world.is_authority_partition_pending() or committed_during_input_turn,
		"exported H input either queues or already atomically commits W0 authority composition"
	)
	if world.is_authority_partition_pending():
		await world.authority_partition_committed
	elif not committed_during_input_turn:
		return _report(false)

	var result := world.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	var relation: Dictionary = root.call("get_c6_active_relation_for_test")
	var joint := root.call("get_c6_relation_joint_for_test") as HingeJoint3D
	var install_frame := int(root.call("get_c6_relation_install_physics_frame_for_test"))
	_check(target != null and is_instance_valid(target), "exported actual input publishes dynamic relation island")
	_check(not relation.is_empty(), "exported actual input publishes logical relation truth")
	_check(joint != null and is_instance_valid(joint), "exported actual input manifests passive host")
	_check(install_frame == Engine.get_physics_frames(), "exported relation manifests in authority-commit physics frame before solver step")
	_check(install_frame >= request_frame, "exported relation installation follows actual H request causally")
	_check(player.grounded and player.support_space == target, "exported actor follows supporting Matter into relation-owned island")
	_check(player.global_position.distance_to(actor_world_before) < 0.0001, "exported actor authority handoff is world-continuous")
	if target == null or relation.is_empty() or joint == null:
		return _report(false)

	var body := target.get_active_provider() as ConstructBody
	_check(body != null, "exported related island owns dynamic provider")
	if body == null:
		return _report(false)

	var island_token := int(relation.get("island_lineage", MatterLineageMap.NONE))
	var island_cell_result := _find_lineage_cell(target, island_token)
	_check(not island_cell_result.is_empty(), "exported relation endpoint lineage resolves in dynamic island")
	if island_cell_result.is_empty():
		return _report(false)

	var island_cell: Vector3i = island_cell_result["cell"]
	var offset: Vector3i = relation.get("world_to_island_offset", Vector3i.ZERO)
	var island_anchor_local := (
		Vector3(island_cell)
		+ Vector3(0.5, 0.5, 0.5)
		- Vector3(offset) * 0.5
		- Vector3.UP * 0.5
	)
	var anchor_world := joint.global_position
	var immediate_gap := (body.global_transform * island_anchor_local).distance_to(anchor_world)
	_check(immediate_gap < 0.0001, "exported relation begins without seam teleport")
	_check(body.linear_velocity.length() < 0.00001 and body.angular_velocity.length() < 0.00001, "exported relation begins with zero hidden launch")

	var initial_basis := body.global_basis
	var max_gap := immediate_gap
	var max_rotation := 0.0
	var ride_frames := 0
	for _frame in range(DRIVE_FRAMES):
		await root.get_tree().physics_frame
		await root.get_tree().process_frame
		max_gap = maxf(max_gap, (body.global_transform * island_anchor_local).distance_to(anchor_world))
		max_rotation = maxf(max_rotation, _basis_angle(initial_basis, body.global_basis))
		if player.grounded and player.support_space == target:
			ride_frames += 1

	_check(max_gap < 0.12, "exported passive relation remains bounded under real WORLD collision")
	_check(max_rotation > 0.10, "exported gravity produces passive rotational motion")
	_check(ride_frames > 0, "exported actor rides related Matter during motion")
	await _capture(root, "01_exported_relation_live")

	var source_origin: Vector3i = result.get("source_origin", Vector3i.ZERO)
	var non_endpoint_local := NON_ENDPOINT_SOURCE_CELL - source_origin
	var non_endpoint_token := (
		target.lineage.get_lineage(non_endpoint_local)
		if target.volume.in_bounds(non_endpoint_local)
		else MatterLineageMap.NONE
	)
	_check(non_endpoint_token != MatterLineageMap.NONE and non_endpoint_token != island_token, "exported history edit selects live non-endpoint Matter")
	if non_endpoint_token != MatterLineageMap.NONE:
		_check(
			interactor.apply_edit_to_cell(target, non_endpoint_local, P1MatterInteractor.EditMode.REMOVE),
			"exported production mutation edits moving related Matter"
		)
	_check(bool(root.call("has_c6_active_relation_for_test")), "exported unrelated moving edit preserves relation")
	await _advance(root, POST_EDIT_FRAMES)

	var endpoint_result := _find_lineage_cell(target, island_token)
	_check(not endpoint_result.is_empty(), "exported relation endpoint remains live before history destruction")
	if endpoint_result.is_empty():
		return _report(false)
	var endpoint_cell: Vector3i = endpoint_result["cell"]
	_check(
		interactor.apply_edit_to_cell(target, endpoint_cell, P1MatterInteractor.EditMode.REMOVE),
		"exported production edit destroys actual relation endpoint Matter"
	)
	_check(not bool(root.call("has_c6_active_relation_for_test")), "exported endpoint destruction kills logical relation")
	var dead_joint := root.call("get_c6_relation_joint_for_test") as HingeJoint3D
	_check(dead_joint == null or not is_instance_valid(dead_joint), "exported stale passive host retires after relation death")

	_check(
		interactor.apply_edit_to_cell(target, endpoint_cell, P1MatterInteractor.EditMode.PLACE),
		"exported same address accepts fresh Matter after endpoint death"
	)
	var fresh_token := target.lineage.get_lineage(endpoint_cell)
	_check(fresh_token != MatterLineageMap.NONE and fresh_token != island_token, "exported same-address Matter receives fresh identity")
	_check(not bool(root.call("has_c6_active_relation_for_test")), "exported fresh Matter does not resurrect historical relation")
	await _capture(root, "02_exported_relation_history")

	var metrics := {
		"screen": screen,
		"selected_cells": int(authoring.get("selected_cells", 0)),
		"install_frame": install_frame,
		"immediate_gap": immediate_gap,
		"max_gap": max_gap,
		"max_rotation": max_rotation,
		"ride_frames": ride_frames,
		"old_endpoint": island_token,
		"fresh_endpoint": fresh_token,
	}
	if _failures.is_empty():
		print(
			"C6_EXPORTED_AUTONOMOUS_FLOW_METRIC screen=(%.1f,%.1f) selected=%d install_frame=%d immediate_gap=%.10f max_gap=%.6f rotation=%.6f ride_frames=%d old_endpoint=%d fresh_endpoint=%d"
			% [
				screen.x, screen.y,
				metrics["selected_cells"],
				install_frame,
				immediate_gap,
				max_gap,
				max_rotation,
				ride_frames,
				island_token,
				fresh_token,
			]
		)
		return {"pass": true, "failures": [], "metrics": metrics}
	return {"pass": false, "failures": _failures.duplicate(), "metrics": metrics}


func _find_visible_target(
	root: Node,
	world: LocalMatterSpace,
	camera_rig: P1CameraRig,
	interactor: P1MatterInteractor
) -> Dictionary:
	for orbit_variant in ORBITS:
		var orbit := orbit_variant as Array
		camera_rig.set("_yaw", float(orbit[0]))
		camera_rig.set("_pitch", float(orbit[1]))
		camera_rig.set("_distance", float(orbit[2]))
		camera_rig.call("_apply_user_orbit_immediately")
		await root.get_tree().process_frame
		await root.get_tree().physics_frame
		await root.get_tree().process_frame

		var camera := camera_rig.get_camera()
		var viewport := camera.get_viewport()
		var rect := viewport.get_visible_rect()
		for y in range(int(rect.size.y * 0.16), int(rect.size.y * 0.94), SCAN_STEP):
			for x in range(int(rect.size.x * 0.06), int(rect.size.x * 0.94), SCAN_STEP):
				var screen := rect.position + Vector2(float(x), float(y))
				interactor.update_target_from_pointer_position(screen)
				if (
					interactor.target_space == world
					and interactor.target_valid
					and interactor.remove_cell == TARGET_CELL
				):
					return {
						"screen": screen,
						"norm": Vector2(screen.x / rect.size.x, screen.y / rect.size.y),
						"orbit": orbit.duplicate(),
					}
	return {}


func _action_has_h_key() -> bool:
	for event_variant in InputMap.action_get_events("p1_structural_seam"):
		if event_variant is InputEventKey:
			var key := event_variant as InputEventKey
			if key.physical_keycode == KEY_H or key.keycode == KEY_H:
				return true
	return false


func _find_lineage_cell(space: LocalMatterSpace, token: int) -> Dictionary:
	if space == null or space.lineage == null:
		return {}
	for z in range(space.lineage.size.z):
		for y in range(space.lineage.size.y):
			for x in range(space.lineage.size.x):
				var cell := Vector3i(x, y, z)
				if space.lineage.get_lineage(cell) == token:
					return {"cell": cell}
	return {}


func _capture(root: Node, label: String) -> void:
	if _evidence_dir.is_empty():
		return
	await root.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	_check(image != null and not image.is_empty(), "%s produced exported rendered pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _evidence_dir.path_join(label + ".png")
	var error := image.save_png(path)
	_check(error == OK, "%s saved exported rendered evidence" % label)
	if error == OK:
		print("C6_EXPORTED_RENDER_CAPTURE: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


func _advance(root: Node, count: int) -> void:
	for _frame in range(count):
		await root.get_tree().physics_frame
		await root.get_tree().process_frame


func _basis_angle(reference: Basis, current: Basis) -> float:
	var delta := reference.inverse() * current
	return absf(delta.get_rotation_quaternion().get_angle())


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _report(passed: bool) -> Dictionary:
	return {"pass": passed and _failures.is_empty(), "failures": _failures.duplicate(), "metrics": {}}
