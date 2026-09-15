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

# G4 bounded challenger controls. These stay inert in canonical runtime until a
# rendered A/B earns promotion. They are composition safeguards, not new world
# or Space authority.
@export var max_context_focus_shift: float = 3.2
@export var context_extent_distance_scale: float = 0.95
@export var compression_trigger_ratio: float = 0.72
@export var compression_full_ratio: float = 0.20
@export var compression_pitch_bias: float = 0.55
@export var compression_focus_lift: float = 0.90
@export var compression_response_speed: float = 18.0

# Second G4 challenger: solve the two observed failure classes independently.
# Extreme actor↔Space separation gets bounded emergency group framing, while a
# locally blocked orbit is solved by selecting a nearby collision-clear camera
# ray. Neither path changes Space/Matter authority or normal user zoom limits.
@export var emergency_group_start: float = 18.0
@export var emergency_group_full: float = 28.0
@export var emergency_group_distance_scale: float = 0.92
@export var emergency_group_max_distance: float = 34.0
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
var _composition_guard_enabled := false
var _adaptive_relational_enabled := false
var _compression_amount := 0.0
var _last_desired_distance := 0.0
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
	_apply_orbit()


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


func set_composition_guard_enabled(enabled: bool) -> void:
	_composition_guard_enabled = enabled
	if not enabled:
		_adaptive_relational_enabled = false
	_compression_amount = 0.0
	_last_desired_distance = 0.0
	_runtime_yaw = _yaw
	_runtime_pitch = _pitch
	_apply_orbit()


func set_adaptive_relational_enabled(enabled: bool) -> void:
	_adaptive_relational_enabled = enabled
	_composition_guard_enabled = enabled
	_compression_amount = 0.0
	_last_desired_distance = 0.0
	_runtime_yaw = _yaw
	_runtime_pitch = _pitch
	_apply_orbit()


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
	_compression_amount = 0.0
	_last_desired_distance = 0.0
	_runtime_yaw = _yaw
	_runtime_pitch = _pitch
	_apply_orbit()


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	if _composition_guard_enabled and not _adaptive_relational_enabled:
		_update_compression_recovery(delta)

	var target_transform: Transform3D = target.get_global_transform_interpolated()
	var actor_focus: Vector3 = target_transform.origin + Vector3.UP * focus_height
	var focus: Vector3 = actor_focus
	var desired_distance: float = _distance
	var separation := 0.0
	var has_context := false
	var context_point := Vector3.ZERO

	if context_target != null and is_instance_valid(context_target):
		var context_transform: Transform3D = context_target.get_global_transform_interpolated()
		context_point = context_transform * context_local_point
		separation = actor_focus.distance_to(context_point)
		has_context = true
		var blend_span: float = maxf(0.001, context_blend_full - context_blend_start)
		var context_t: float = clampf(
			(separation - context_blend_start) / blend_span,
			0.0,
			1.0
		)
		var context_weight: float = context_t * max_context_weight

		if _composition_guard_enabled:
			var bounded_shift: Vector3 = (context_point - actor_focus) * context_weight
			if bounded_shift.length() > max_context_focus_shift:
				bounded_shift = bounded_shift.normalized() * max_context_focus_shift

			if _adaptive_relational_enabled and separation > emergency_group_start:
				var emergency_span := maxf(0.001, emergency_group_full - emergency_group_start)
				var emergency_t := smoothstep(
					0.0,
					1.0,
					clampf((separation - emergency_group_start) / emergency_span, 0.0, 1.0)
				)
				var group_shift: Vector3 = (context_point - actor_focus) * max_context_weight
				focus = actor_focus + bounded_shift.lerp(group_shift, emergency_t)
				var emergency_distance := minf(
					emergency_group_max_distance,
					separation * emergency_group_distance_scale
				)
				desired_distance = maxf(
					desired_distance,
					lerpf(max_distance, emergency_distance, emergency_t)
				)
			else:
				focus += bounded_shift
		else:
			focus = focus.lerp(context_point, context_weight)

		if not (_adaptive_relational_enabled and separation > emergency_group_start):
			desired_distance = clampf(
				maxf(_distance, separation * 0.72),
				min_distance,
				max_distance
			)

		# Space extent is soft context pressure, not a demand to fit the complete
		# Space. Explicit close zoom remains possible; the floor only affects the
		# ordinary/default research view.
		if (
			_composition_guard_enabled
			and context_planar_radius > 0.0
			and _distance >= default_distance - 0.001
			and not (_adaptive_relational_enabled and separation > emergency_group_start)
		):
			desired_distance = maxf(
				desired_distance,
				minf(max_distance, context_planar_radius * context_extent_distance_scale)
			)

	if _adaptive_relational_enabled:
		_update_adaptive_orbit(focus, desired_distance, delta)
	elif _composition_guard_enabled:
		focus += Vector3.UP * (_compression_amount * compression_focus_lift)
		_apply_guarded_pitch()

	global_position = focus
	_spring_arm.spring_length = desired_distance
	_last_desired_distance = desired_distance

	# Keep these variables live in the debugger even when no extreme relation is
	# active; they are intentionally local presentation evidence only.
	if not has_context:
		separation = 0.0
		context_point = Vector3.ZERO


func _update_compression_recovery(delta: float) -> void:
	if _last_desired_distance <= 0.001:
		return
	var actual_distance: float = _camera.global_position.distance_to(_spring_arm.global_position)
	var ratio: float = clampf(actual_distance / _last_desired_distance, 0.0, 1.0)
	var denominator: float = maxf(0.001, compression_trigger_ratio - compression_full_ratio)
	var target_amount: float = clampf(
		(compression_trigger_ratio - ratio) / denominator,
		0.0,
		1.0
	)
	var response: float = 1.0 - exp(-compression_response_speed * maxf(0.0, delta))
	_compression_amount = lerpf(_compression_amount, target_amount, response)


func _update_adaptive_orbit(focus: Vector3, desired_distance: float, delta: float) -> void:
	var target_yaw := _yaw
	var target_pitch := _pitch
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
		if not _adaptive_relational_enabled:
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


func _apply_guarded_pitch() -> void:
	var runtime_pitch: float = clampf(
		_pitch + _compression_amount * compression_pitch_bias,
		0.12,
		1.35
	)
	_pitch_pivot.rotation = Vector3(-runtime_pitch, 0.0, 0.0)


func _apply_orbit() -> void:
	if not is_node_ready():
		return
	if _adaptive_relational_enabled:
		_runtime_yaw = _yaw
		_runtime_pitch = _pitch
		_yaw_pivot.rotation = Vector3(0.0, _runtime_yaw, 0.0)
		_pitch_pivot.rotation = Vector3(-_runtime_pitch, 0.0, 0.0)
		return
	_yaw_pivot.rotation = Vector3(0.0, _yaw, 0.0)
	if _composition_guard_enabled:
		_apply_guarded_pitch()
	else:
		_pitch_pivot.rotation = Vector3(-_pitch, 0.0, 0.0)
