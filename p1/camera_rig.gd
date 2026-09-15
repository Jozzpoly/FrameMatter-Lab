class_name P1CameraRig
extends Node3D

const ESCAPE_YAW_OFFSETS := [0.0, -0.45, 0.45, -0.90, 0.90, -1.35, 1.35]
const ESCAPE_PITCH_ADDS := [0.0, 0.18, 0.36]

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
@export var max_context_focus_shift: float = 3.2
@export var context_extent_distance_scale: float = 0.95

# G4 camera policy. Local obstruction and extreme actor↔Space separation are
# different composition problems. Blocked orbits search nearby collision-clear
# rays. Extreme separation keeps actor X/Z as the hard anchor, lifts only the
# presentation focus toward higher context when needed, and turns the rendered
# view along actor→Space without rotating the player's control frame.
@export var emergency_relation_start: float = 18.0
@export var emergency_relation_full: float = 28.0
@export var emergency_vertical_lift_weight: float = 0.55
@export var emergency_vertical_lift_cap: float = 4.5
@export var emergency_track_pitch: float = 0.12
@export var camera_probe_radius: float = 0.28
@export var escape_clearance_target: float = 0.78
@export var escape_orbit_response_speed: float = 20.0

var target: Node3D
var context_target: Node3D
var context_local_point := Vector3.ZERO
var context_planar_radius := 0.0

var _yaw: float = default_yaw
var _pitch: float = default_pitch
var _distance: float = default_distance
var _orbiting := false
var _runtime_yaw: float = default_yaw
var _runtime_pitch: float = default_pitch
var _probe_shape: SphereShape3D

@onready var _yaw_pivot: Node3D = $YawPivot
@onready var _pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var _spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var _camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	_yaw = default_yaw
	_pitch = default_pitch
	_distance = default_distance
	_runtime_yaw = _yaw
	_runtime_pitch = _pitch
	_probe_shape = SphereShape3D.new()
	_probe_shape.radius = camera_probe_radius
	_apply_user_orbit_immediately()


func set_target(node: Node3D) -> void:
	target = node


func set_context_target(
	node: Node3D,
	local_point: Vector3 = Vector3.ZERO,
	planar_radius: float = 0.0
) -> void:
	context_target = node
	context_local_point = local_point
	context_planar_radius = maxf(0.0, planar_radius)


func get_camera() -> Camera3D:
	return _camera


func get_planar_forward() -> Vector3:
	# Movement follows explicit user yaw, not presentation-only obstacle/relation
	# recovery. Automatic camera work must never rotate controls behind the Owner.
	var basis := Basis(Vector3.UP, _yaw)
	var forward: Vector3 = -basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD


func get_planar_right() -> Vector3:
	var basis := Basis(Vector3.UP, _yaw)
	var right: Vector3 = basis.x
	right.y = 0.0
	return right.normalized() if right.length_squared() > 0.000001 else Vector3.RIGHT


func reset_view() -> void:
	_yaw = default_yaw
	_pitch = default_pitch
	_distance = default_distance
	_runtime_yaw = _yaw
	_runtime_pitch = _pitch
	_apply_user_orbit_immediately()


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var target_transform: Transform3D = target.get_global_transform_interpolated()
	var actor_focus: Vector3 = target_transform.origin + Vector3.UP * focus_height
	var focus: Vector3 = actor_focus
	var desired_distance: float = _distance
	var context_point := Vector3.ZERO
	var separation := 0.0
	var emergency_relation_t := 0.0

	if context_target != null and is_instance_valid(context_target):
		var context_transform: Transform3D = context_target.get_global_transform_interpolated()
		context_point = context_transform * context_local_point
		separation = actor_focus.distance_to(context_point)
		var blend_span: float = maxf(0.001, context_blend_full - context_blend_start)
		var context_t: float = clampf(
			(separation - context_blend_start) / blend_span,
			0.0,
			1.0
		)
		var context_weight: float = context_t * max_context_weight
		var bounded_shift: Vector3 = (context_point - actor_focus) * context_weight
		if bounded_shift.length() > max_context_focus_shift:
			bounded_shift = bounded_shift.normalized() * max_context_focus_shift

		if separation > emergency_relation_start:
			var emergency_span := maxf(0.001, emergency_relation_full - emergency_relation_start)
			emergency_relation_t = smoothstep(
				0.0,
				1.0,
				clampf((separation - emergency_relation_start) / emergency_span, 0.0, 1.0)
			)
			# Extreme relation keeps actor X/Z authoritative. Only vertical focus
			# may rise toward a higher context so opaque world geometry does not
			# force the camera to pretend it can see through the reference plane.
			focus = actor_focus
			var upward_gap := maxf(0.0, context_point.y - actor_focus.y)
			focus.y += minf(
				emergency_vertical_lift_cap,
				upward_gap * emergency_vertical_lift_weight
			) * emergency_relation_t
		else:
			focus += bounded_shift

		desired_distance = clampf(
			maxf(_distance, separation * 0.72),
			min_distance,
			max_distance
		)

		# Matter extent is soft composition pressure, not a demand to show every
		# occupied cell. Explicit close zoom remains available to the Owner.
		if (
			context_planar_radius > 0.0
			and _distance >= default_distance - 0.001
			and emergency_relation_t < 0.001
		):
			desired_distance = maxf(
				desired_distance,
				minf(max_distance, context_planar_radius * context_extent_distance_scale)
			)

	_update_presentation_orbit(
		focus,
		desired_distance,
		delta,
		actor_focus,
		context_point,
		emergency_relation_t
	)
	global_position = focus
	_spring_arm.spring_length = desired_distance


func _update_presentation_orbit(
	focus: Vector3,
	desired_distance: float,
	delta: float,
	actor_focus: Vector3,
	context_point: Vector3,
	emergency_relation_t: float
) -> void:
	var target_yaw := _yaw
	var target_pitch := _pitch

	if emergency_relation_t > 0.0:
		var actor_to_context := context_point - actor_focus
		actor_to_context.y = 0.0
		if actor_to_context.length_squared() > 0.000001:
			# SpringArm extends along +Z from focus. Put the camera on the side
			# opposite Space so the view runs from actor toward the experiment.
			var arm_away_from_context := -actor_to_context.normalized()
			var relation_yaw := atan2(arm_away_from_context.x, arm_away_from_context.z)
			target_yaw = lerp_angle(_yaw, relation_yaw, emergency_relation_t)
		target_pitch = lerpf(_pitch, emergency_track_pitch, emergency_relation_t)

	var base_clearance := _probe_orbit_clearance(focus, target_yaw, target_pitch, desired_distance)
	if base_clearance < escape_clearance_target:
		var best_score := -INF
		var best_clearance := base_clearance
		var best_yaw := target_yaw
		var best_pitch := target_pitch
		for yaw_offset_variant in ESCAPE_YAW_OFFSETS:
			var yaw_offset := float(yaw_offset_variant)
			for pitch_add_variant in ESCAPE_PITCH_ADDS:
				var pitch_add := float(pitch_add_variant)
				var candidate_yaw := target_yaw + yaw_offset
				var candidate_pitch := clampf(target_pitch + pitch_add, 0.12, 1.35)
				var clearance := _probe_orbit_clearance(
					focus,
					candidate_yaw,
					candidate_pitch,
					desired_distance
				)
				var score := clearance - absf(yaw_offset) * 0.055 - pitch_add * 0.04
				if score > best_score:
					best_score = score
					best_clearance = clearance
					best_yaw = candidate_yaw
					best_pitch = candidate_pitch
		if best_clearance > base_clearance + 0.05:
			target_yaw = best_yaw
			target_pitch = best_pitch

	var response := 1.0 - exp(-escape_orbit_response_speed * maxf(0.0, delta))
	_runtime_yaw = lerp_angle(_runtime_yaw, target_yaw, response)
	_runtime_pitch = lerpf(_runtime_pitch, target_pitch, response)
	_yaw_pivot.rotation = Vector3(0.0, _runtime_yaw, 0.0)
	_pitch_pivot.rotation = Vector3(-_runtime_pitch, 0.0, 0.0)


func _probe_orbit_clearance(
	focus: Vector3,
	yaw: float,
	pitch: float,
	desired_distance: float
) -> float:
	if _probe_shape == null or desired_distance <= 0.001 or not is_inside_tree():
		return 1.0
	var yaw_basis := Basis(Vector3.UP, yaw)
	var pitch_basis := Basis(Vector3.RIGHT, -pitch)
	var arm_direction: Vector3 = (yaw_basis * pitch_basis).z.normalized()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _probe_shape
	query.transform = Transform3D(Basis.IDENTITY, focus)
	query.motion = arm_direction * desired_distance
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var motion_result: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	if motion_result.is_empty():
		return 1.0
	return clampf(motion_result[0], 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * orbit_sensitivity
		_pitch = clampf(_pitch - motion.relative.y * orbit_sensitivity, 0.12, 1.15)
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


func _apply_user_orbit_immediately() -> void:
	if not is_node_ready():
		return
	_runtime_yaw = _yaw
	_runtime_pitch = _pitch
	_yaw_pivot.rotation = Vector3(0.0, _runtime_yaw, 0.0)
	_pitch_pivot.rotation = Vector3(-_runtime_pitch, 0.0, 0.0)
