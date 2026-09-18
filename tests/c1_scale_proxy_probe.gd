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

	var variants := [
		{"scale": 1.0, "cell_m": 1.0, "radius": 0.32, "height": 1.8, "gravity": 18.0, "jump": 5.8, "reach": 14.0, "camera": 7.2},
		{"scale": 2.0, "cell_m": 0.5, "radius": 0.64, "height": 3.6, "gravity": 36.0, "jump": 11.6, "reach": 28.0, "camera": 14.4},
		{"scale": 4.0, "cell_m": 0.25, "radius": 1.28, "height": 7.2, "gravity": 72.0, "jump": 23.2, "reach": 56.0, "camera": 28.8},
		{"scale": 8.0, "cell_m": 0.125, "radius": 2.56, "height": 14.4, "gravity": 144.0, "jump": 46.4, "reach": 112.0, "camera": 57.6},
		{"scale": 1.0, "cell_m": 1.0, "radius": 0.32, "height": 1.8, "gravity": 18.0, "jump": 5.8, "reach": 14.0, "camera": 7.2},
	]

	for variant in variants:
		var scale_factor := float(variant["scale"])
		root.call("set_c1_scale_probe_for_test", scale_factor)
		await _advance_frames(SETTLE_FRAMES)
		var world := root.call("get_recovery_world_space") as LocalMatterSpace
		_check(is_equal_approx(float(root.call("get_c1_scale_probe_factor")), scale_factor), "%.0fx scale factor is active" % scale_factor)
		_check(is_equal_approx(float(root.call("get_c1_scale_probe_equivalent_cell_meters")), float(variant["cell_m"])), "%.0fx relative-cell proxy is correct" % scale_factor)
		_check(is_equal_approx(player.radius, float(variant["radius"])), "%.0fx player radius is correct" % scale_factor)
		_check(is_equal_approx(player.height, float(variant["height"])), "%.0fx player height is correct" % scale_factor)
		_check(is_equal_approx(player.gravity_acceleration, float(variant["gravity"])), "%.0fx gravity scale is correct" % scale_factor)
		_check(is_equal_approx(player.jump_speed, float(variant["jump"])), "%.0fx jump scale is correct" % scale_factor)
		_check(is_equal_approx(interactor.max_distance, float(variant["reach"])), "%.0fx edit reach is correct" % scale_factor)
		_check(is_equal_approx(camera_rig.default_distance, float(variant["camera"])), "%.0fx camera distance is correct" % scale_factor)
		_check(player.grounded and player.support_space == world, "%.0fx actor settles on ordinary WORLD Matter after reset" % scale_factor)

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
