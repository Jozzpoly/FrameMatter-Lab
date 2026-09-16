extends SceneTree

# Regression for the R-V5 causal failure: SpaceQueryCharacter used cast_motion()
# as its sole persistent-ground validator even though cast_motion deliberately
# ignores shapes the query already overlaps. A tiny floor overlap must therefore
# remain a valid ground-contact state instead of turning into free-fall.

const ACQUIRE_FRAMES := 24
const EDGE_FRAMES := 75
const SHALLOW_OVERLAP_Y := 1.899

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "P1ActorOverlapGroundRegression"
	get_root().add_child(host)

	var volume := CellVolume.new(Vector3i(6, 1, 6))
	volume.fill_box(Vector3i.ZERO, Vector3i(6, 1, 6), CellVolume.SOLID)
	var lineage := MatterLineageMap.new(volume.size)
	var token := 880001
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				lineage.set_lineage(cell, token)
				token += 1

	var space := LocalMatterSpace.new()
	space.name = "OverlapGroundSpace"
	host.add_child(space)
	space.initialize_static(volume, lineage, Transform3D.IDENTITY)

	# Full capsule height is 1.8 m, so an actor center at 1.899 m places the
	# capsule bottom 1 mm into the y=1 floor surface. This is deliberately tiny:
	# it models the shallow-contact classification change observed in R-V5 rather
	# than a deep-penetration recovery feature.
	var actor := SpaceQueryCharacter.new()
	actor.name = "OverlapGroundActor"
	host.add_child(actor)
	actor.global_position = Vector3(3.0, SHALLOW_OVERLAP_Y, 3.0)
	await _advance_frames(ACQUIRE_FRAMES)

	_check(actor.grounded, "shallow floor overlap is recognized as valid ground contact")
	_check(actor.support_space == space, "shallow floor overlap resolves the logical LocalMatterSpace support")
	_check(actor.support_body == space.get_active_provider(), "shallow floor overlap resolves the active provider frame")
	_check(actor.global_position.y > 1.80, "shallow overlap recovery does not fall through the Matter floor")

	# The overlap fallback must not become sticky-ground authority. Walking beyond
	# the finite floor has to release support normally once there is neither a
	# forward ground hit nor a current floor overlap.
	if actor.grounded:
		actor.desired_local_velocity = Vector3(4.0, 0.0, 0.0)
		await _advance_frames(EDGE_FRAMES)
		actor.desired_local_velocity = Vector3.ZERO
		_check(not actor.grounded, "overlap-aware ground logic still releases support after leaving a real edge")
		_check(actor.support_space == null, "edge release clears logical Space support")
		_check(actor.global_position.x > 6.0, "edge challenger actually travels beyond the finite floor")

	print(
		"P1_ACTOR_OVERLAP_GROUND_METRIC final_position=%s grounded=%s support_space=%s" % [
			str(actor.global_position),
			str(actor.grounded),
			str(actor.support_space != null),
		]
	)

	actor.free()
	space.free()
	host.free()
	_finish()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_ACTOR_OVERLAP_GROUND_PASS: shallow floor overlap remains grounded while a true finite-floor edge still releases support.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_ACTOR_OVERLAP_GROUND_FAIL: " + failure)
	quit(1)
