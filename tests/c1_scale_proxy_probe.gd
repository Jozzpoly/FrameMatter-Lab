extends SceneTree

const WATCHDOG_SECONDS := 12.0
const SETTLE_FRAMES := 24

var _failures: Array[String] = []
var _finished := false


func _init() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")


func _watchdog() -> void:
	await create_timer(WATCHDOG_SECONDS).timeout
	if _finished:
		return
	push_error("C1_SCALE_PROXY_TIMEOUT")
	quit(1)


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "recovery scene loads")
	if packed == null:
		_finish()
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame

	var player := root.call("get_player") as SpaceQueryCharacter
	var camera_rig := root.call("get_camera_rig") as P1CameraRig
	var interactor := root.call("get_interactor") as P1MatterInteractor
	_check(player != null, "player exists")
	_check(camera_rig != null, "camera rig exists")
	_check(interactor != null, "interactor exists")
	if player == null or camera_rig == null or interactor == null:
		root.free()
		_finish()
		return

	root.call("set_c1_scale_probe_for_test", 4.0)
	await _advance_frames(SETTLE_FRAMES)
	var world := root.call("get_recovery_world_space") as LocalMatterSpace
	_check(is_equal_approx(float(root.call("get_c1_scale_probe_factor")), 4.0), "4x scale factor is active")
	_check(is_equal_approx(float(root.call("get_c1_scale_probe_equivalent_cell_meters")), 0.25), "4x maps to 0.25 m relative-cell proxy")
	_check(is_equal_approx(player.radius, 1.28), "player radius scales 4x")
	_check(is_equal_approx(player.height, 7.2), "player height scales 4x")
	_check(is_equal_approx(player.gravity_acceleration, 72.0), "gravity length scale tracks 4x")
	_check(is_equal_approx(player.jump_speed, 23.2), "jump speed tracks 4x")
	_check(is_equal_approx(interactor.max_distance, 56.0), "edit reach scales 4x")
	_check(is_equal_approx(camera_rig.default_distance, 28.8), "camera distance scales 4x")
	_check(is_equal_approx(camera_rig.min_distance, 12.0), "camera minimum scales 4x")
	_check(is_equal_approx(camera_rig.max_distance, 52.0), "camera maximum scales 4x")
	_check(player.grounded and player.support_space == world, "4x actor settles on ordinary WORLD Matter")

	root.call("set_c1_scale_probe_for_test", 1.0)
	await _advance_frames(SETTLE_FRAMES)
	world = root.call("get_recovery_world_space") as LocalMatterSpace
	_check(is_equal_approx(float(root.call("get_c1_scale_probe_factor")), 1.0), "proxy returns to 1x")
	_check(is_equal_approx(player.radius, 0.32), "player radius returns to baseline")
	_check(is_equal_approx(player.height, 1.8), "player height returns to baseline")
	_check(is_equal_approx(interactor.max_distance, 14.0), "edit reach returns to baseline")
	_check(is_equal_approx(camera_rig.default_distance, 7.2), "camera returns to baseline")
	_check(player.grounded and player.support_space == world, "1x actor reacquires ordinary WORLD Matter after reset")

	print(
		"C1_SCALE_PROXY_METRIC active=%.1f player_height=%.3f reach=%.3f camera=%.3f"
		% [
			float(root.call("get_c1_scale_probe_factor")),
			player.height,
			interactor.max_distance,
			camera_rig.default_distance,
		]
	)

	root.free()
	_finish()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	_finished = true
	if _failures.is_empty():
		print("C1_SCALE_PROXY_PASS: one recovery runtime can switch relative player/camera/reach scale without changing Matter representation and can return to baseline.")
		quit(0)
		return
	for failure in _failures:
		push_error("C1_SCALE_PROXY_FAIL: " + failure)
	quit(1)
