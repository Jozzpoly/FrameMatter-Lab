extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/camera_rig.tscn") as PackedScene
	_check(packed != null, "camera rig scene loads")
	if packed == null:
		_finish()
		return

	var rig := packed.instantiate() as P1CameraRig
	get_root().add_child(rig)
	await process_frame

	var baseline_forward := rig.get_planar_forward()
	var baseline_right := rig.get_planar_right()

	# Simulate a presentation-only recovery orbit. This may move the rendered
	# camera, but must not rotate camera-relative player controls.
	rig.set("_runtime_yaw", float(rig.get("_yaw")) + 1.15)
	var yaw_pivot := rig.get_node("YawPivot") as Node3D
	yaw_pivot.rotation.y = float(rig.get("_runtime_yaw"))
	await process_frame
	_check(
		rig.get_planar_forward().is_equal_approx(baseline_forward),
		"presentation runtime yaw does not change control forward"
	)
	_check(
		rig.get_planar_right().is_equal_approx(baseline_right),
		"presentation runtime yaw does not change control right"
	)

	# Explicit user yaw remains the authority for camera-relative movement.
	rig.set("_yaw", float(rig.get("_yaw")) + 0.55)
	var user_forward := rig.get_planar_forward()
	var user_right := rig.get_planar_right()
	_check(
		not user_forward.is_equal_approx(baseline_forward),
		"user yaw changes control forward"
	)
	_check(
		not user_right.is_equal_approx(baseline_right),
		"user yaw changes control right"
	)
	_check(absf(user_forward.dot(user_right)) < 0.0001, "control basis remains orthogonal")
	_check(absf(user_forward.length() - 1.0) < 0.0001, "control forward remains normalized")
	_check(absf(user_right.length() - 1.0) < 0.0001, "control right remains normalized")

	rig.free()
	_finish()


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_CAMERA_CONTROL_FRAME_PASS: presentation recovery is decoupled from user camera-relative movement authority.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CAMERA_CONTROL_FRAME_FAIL: " + failure)
	quit(1)
