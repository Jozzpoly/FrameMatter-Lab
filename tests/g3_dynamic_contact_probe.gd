extends SceneTree

const PLATFORM_SIZE := Vector3i(7, 1, 7)
const CHARACTER_LOCAL_START := Vector3(5.0, 2.15, 3.5)
const OBSERVE_FRAMES := 120


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for mass_per_cell in [1.0, 100.0, 10000.0]:
		await _run_mass_case(mass_per_cell)

	print("G3_DYNAMIC_CONTACT_PROBE_COMPLETE: free-rigid contact behavior measured; this probe does not declare G3 PASS.")
	quit(0)


func _run_mass_case(mass_per_cell: float) -> void:
	var world: Node3D = Node3D.new()
	world.name = "FreeDynamic_%.0f" % mass_per_cell
	get_root().add_child(world)

	var volume: CellVolume = CellVolume.new(PLATFORM_SIZE)
	volume.fill_box(Vector3i.ZERO, PLATFORM_SIZE, CellVolume.SOLID)

	var construct: ConstructBody = ConstructBody.new()
	construct.name = "FreeConstruct"
	construct.gravity_scale = 0.0
	construct.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	construct.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	construct.linear_damp = 0.0
	construct.angular_damp = 0.0
	construct.mass_per_cell = mass_per_cell
	world.add_child(construct)
	construct.set_volume(volume)

	var character: BaselineCharacter = BaselineCharacter.new()
	character.name = "Character"
	character.configure_default_shape()
	world.add_child(character)
	character.global_position = construct.to_global(CHARACTER_LOCAL_START)

	var construct_start: Vector3 = construct.global_position
	var character_start: Vector3 = character.global_position
	var ever_grounded: bool = false
	var grounded_frames: int = 0
	var first_grounded_frame: int = -1
	var max_construct_displacement: float = 0.0
	var max_construct_vertical_displacement: float = 0.0
	var max_construct_speed: float = 0.0

	for step in range(OBSERVE_FRAMES):
		await physics_frame
		if character.observed_on_floor:
			grounded_frames += 1
			if not ever_grounded:
				ever_grounded = true
				first_grounded_frame = step

		var construct_delta: Vector3 = construct.global_position - construct_start
		max_construct_displacement = max(max_construct_displacement, construct_delta.length())
		max_construct_vertical_displacement = max(max_construct_vertical_displacement, abs(construct_delta.y))
		max_construct_speed = max(max_construct_speed, construct.linear_velocity.length())

	var final_local: Vector3 = construct.to_local(character.global_position)
	var character_world_delta: Vector3 = character.global_position - character_start
	var construct_world_delta: Vector3 = construct.global_position - construct_start

	print(
		"G3_DYNAMIC_CONTACT mass_per_cell=%.1f total_mass=%.1f frames=%d ever_grounded=%s first_grounded_frame=%d grounded_frames=%d construct_delta=%s max_construct_displacement=%.6f max_construct_vertical_displacement=%.6f max_construct_speed=%.6f character_delta=%s final_character_local=%s"
		% [
			mass_per_cell,
			construct.mass,
			OBSERVE_FRAMES,
			ever_grounded,
			first_grounded_frame,
			grounded_frames,
			construct_world_delta,
			max_construct_displacement,
			max_construct_vertical_displacement,
			max_construct_speed,
			character_world_delta,
			final_local,
		]
	)

	world.free()
	await process_frame
