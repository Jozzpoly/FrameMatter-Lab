extends SceneTree

const PLATFORM_SIZE := Vector3i(7, 1, 7)
const CHARACTER_LOCAL_START := Vector3(5.0, 2.15, 3.5)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var linear: Dictionary = await _run_case(
		"linear",
		Vector3(2.0, 0.0, 0.0),
		Vector3.ZERO,
		180
	)
	var rotational: Dictionary = await _run_case(
		"rotational",
		Vector3.ZERO,
		Vector3(0.0, 0.6, 0.0),
		240
	)
	var combined: Dictionary = await _run_case(
		"combined",
		Vector3(1.5, 0.0, -0.5),
		Vector3(0.0, 0.6, 0.0),
		240
	)

	# This is a probe, not the final G3 contract. Only validate that the controlled
	# platform baseline itself is functioning and observable; drift is reported as evidence.
	_check(bool(linear["initial_grounded"]), "linear baseline acquires controlled Matter platform as floor")
	_check(bool(rotational["initial_grounded"]), "rotation baseline acquires controlled Matter platform as floor")
	_check(bool(combined["initial_grounded"]), "combined baseline acquires controlled Matter platform as floor")
	_check(bool(linear["saw_platform_linear_velocity"]), "CharacterBody3D reports platform linear velocity in linear case")
	_check(bool(rotational["saw_platform_angular_velocity"]), "CharacterBody3D reports platform angular velocity in rotation case")
	_check(bool(combined["saw_platform_linear_velocity"]), "CharacterBody3D reports platform linear velocity in combined case")
	_check(bool(combined["saw_platform_angular_velocity"]), "CharacterBody3D reports platform angular velocity in combined case")

	if _failures.is_empty():
		print("G3_BASELINE_PROBE_COMPLETE: stock CharacterBody3D controlled-platform behavior measured without declaring G3 PASS.")
		quit(0)
	else:
		for failure in _failures:
			push_error("G3_BASELINE_PROBE_FAIL: " + failure)
		quit(1)


func _run_case(
	case_name: String,
	platform_linear_velocity: Vector3,
	platform_angular_velocity: Vector3,
	measure_frames: int
) -> Dictionary:
	var world: Node3D = Node3D.new()
	world.name = "World_%s" % case_name
	get_root().add_child(world)

	var volume: CellVolume = CellVolume.new(PLATFORM_SIZE)
	volume.fill_box(Vector3i.ZERO, PLATFORM_SIZE, CellVolume.SOLID)

	var platform: ControlledMatterPlatform = ControlledMatterPlatform.new()
	platform.name = "Platform_%s" % case_name
	world.add_child(platform)
	platform.set_volume(volume)

	var character: BaselineCharacter = BaselineCharacter.new()
	character.name = "Character_%s" % case_name
	character.configure_default_shape()
	world.add_child(character)
	character.global_position = platform.to_global(CHARACTER_LOCAL_START)

	# Let the character settle on a stationary, externally controlled representation.
	for _step in range(45):
		await physics_frame

	var initial_grounded: bool = character.observed_on_floor
	var local_start: Vector3 = platform.to_local(character.global_position)
	platform.motion_linear_velocity = platform_linear_velocity
	platform.motion_angular_velocity = platform_angular_velocity

	var max_local_horizontal_drift: float = 0.0
	var max_local_vertical_drift: float = 0.0
	var floor_loss_frames: int = 0
	var saw_platform_linear_velocity: bool = false
	var saw_platform_angular_velocity: bool = false
	var max_reported_platform_linear_speed: float = 0.0
	var max_reported_platform_angular_speed: float = 0.0

	for _step in range(measure_frames):
		await physics_frame
		var local_now: Vector3 = platform.to_local(character.global_position)
		var local_horizontal_drift: float = Vector2(local_now.x - local_start.x, local_now.z - local_start.z).length()
		var local_vertical_drift: float = abs(local_now.y - local_start.y)
		max_local_horizontal_drift = max(max_local_horizontal_drift, local_horizontal_drift)
		max_local_vertical_drift = max(max_local_vertical_drift, local_vertical_drift)
		if not character.observed_on_floor:
			floor_loss_frames += 1

		var reported_linear_speed: float = character.observed_platform_velocity.length()
		var reported_angular_speed: float = character.observed_platform_angular_velocity.length()
		max_reported_platform_linear_speed = max(max_reported_platform_linear_speed, reported_linear_speed)
		max_reported_platform_angular_speed = max(max_reported_platform_angular_speed, reported_angular_speed)
		if reported_linear_speed > 0.05:
			saw_platform_linear_velocity = true
		if reported_angular_speed > 0.05:
			saw_platform_angular_velocity = true

	var final_local: Vector3 = platform.to_local(character.global_position)
	var result: Dictionary = {
		"initial_grounded": initial_grounded,
		"max_local_horizontal_drift": max_local_horizontal_drift,
		"max_local_vertical_drift": max_local_vertical_drift,
		"floor_loss_frames": floor_loss_frames,
		"saw_platform_linear_velocity": saw_platform_linear_velocity,
		"saw_platform_angular_velocity": saw_platform_angular_velocity,
		"max_reported_platform_linear_speed": max_reported_platform_linear_speed,
		"max_reported_platform_angular_speed": max_reported_platform_angular_speed,
	}

	print(
		"G3_METRIC case=%s frames=%d initial_grounded=%s max_local_horizontal_drift=%.6f max_local_vertical_drift=%.6f floor_loss_frames=%d final_local=%s platform_linear_reported=%.6f platform_angular_reported=%.6f commanded_linear=%s commanded_angular=%s"
		% [
			case_name,
			measure_frames,
			initial_grounded,
			max_local_horizontal_drift,
			max_local_vertical_drift,
			floor_loss_frames,
			final_local,
			max_reported_platform_linear_speed,
			max_reported_platform_angular_speed,
			platform_linear_velocity,
			platform_angular_velocity,
		]
	)

	world.free()
	await process_frame
	return result


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
