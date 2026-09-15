class_name P1CameraRig
extends Node3D

@export var focus_height: float = 0.65
@export var default_yaw: float = 0.72
@export var default_pitch: float = 0.48
@export var default_distance: float = 7.2
@export var min_distance: float = 3.0
@export var max_distance: float = 13.0
@export var orbit_sensitivity: float = 0.007
@export var zoom_step: float = 0.65
@export var context_blend_start: float = 5.0
@export var context_blend_full: float = 14.0
@export var max_context_weight: float = 0.42

var target: Node3D
var context_target: Node3D
var context_local_point := Vector3.ZERO

var _yaw: float = default_yaw
var _pitch: float = default_pitch
var _distance: float = default_distance
var _orbiting := false

@onready var _yaw_pivot: Node3D = $YawPivot
@onready var _pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var _spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var _camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	_yaw = default_yaw
	_pitch = default_pitch
	_distance = default_distance
	_apply_orbit()


func set_target(node: Node3D) -> void:
	target = node


func set_context_target(node: Node3D, local_point: Vector3 = Vector3.ZERO) -> void:
	context_target = node
	context_local_point = local_point


func get_camera() -> Camera3D:
	return _camera


func get_planar_forward() -> Vector3:
	var forward: Vector3 = -_yaw_pivot.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD


func get_planar_right() -> Vector3:
	var right: Vector3 = _yaw_pivot.global_transform.basis.x
	right.y = 0.0
	return right.normalized() if right.length_squared() > 0.000001 else Vector3.RIGHT


func reset_view() -> void:
	_yaw = default_yaw
	_pitch = default_pitch
	_distance = default_distance
	_apply_orbit()


func _process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var target_transform: Transform3D = target.get_global_transform_interpolated()
	var focus: Vector3 = target_transform.origin + Vector3.UP * focus_height
	var desired_distance: float = _distance

	if context_target != null and is_instance_valid(context_target):
		var context_transform: Transform3D = context_target.get_global_transform_interpolated()
		var context_point: Vector3 = context_transform * context_local_point
		var separation: float = focus.distance_to(context_point)
		var blend_span: float = maxf(0.001, context_blend_full - context_blend_start)
		var context_t: float = clampf(
			(separation - context_blend_start) / blend_span,
			0.0,
			1.0
		)
		var context_weight: float = context_t * max_context_weight
		focus = focus.lerp(context_point, context_weight)
		desired_distance = clampf(maxf(_distance, separation * 0.72), min_distance, max_distance)

	global_position = focus
	_spring_arm.spring_length = desired_distance


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * orbit_sensitivity
		_pitch = clampf(_pitch - motion.relative.y * orbit_sensitivity, 0.12, 1.15)
		_apply_orbit()
		return

	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index == MOUSE_BUTTON_MIDDLE:
		_orbiting = mouse.pressed
		return
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
		_distance = maxf(min_distance, _distance - zoom_step)
		return
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_distance = minf(max_distance, _distance + zoom_step)


func _apply_orbit() -> void:
	if not is_node_ready():
		return
	_yaw_pivot.rotation = Vector3(0.0, _yaw, 0.0)
	_pitch_pivot.rotation = Vector3(-_pitch, 0.0, 0.0)
