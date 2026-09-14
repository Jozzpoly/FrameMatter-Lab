class_name ConstructBindingPolicy
extends RefCounted

# Experimental decision surface only. This deliberately does not decide from
# contact/connectivity alone and is not a final gameplay/docking API.
enum RequestMode {
	NONE,
	COMPATIBLE_ONLY,
	ALLOW_INELASTIC,
}

enum Decision {
	KEEP_SEPARATE,
	COMPATIBLE_REFRAME,
	REJECT_INCOMPATIBLE,
	INELASTIC_BIND,
}


static func decide(
	request_mode: RequestMode,
	anchor_velocity_error: float,
	angular_velocity_error: float,
	anchor_velocity_tolerance: float = 0.0001,
	angular_tolerance: float = 0.0001
) -> Decision:
	assert(anchor_velocity_error >= 0.0)
	assert(angular_velocity_error >= 0.0)
	assert(anchor_velocity_tolerance >= 0.0)
	assert(angular_tolerance >= 0.0)

	if request_mode == RequestMode.NONE:
		return Decision.KEEP_SEPARATE

	# Two bodies can have different COM linear velocities while belonging to one
	# compatible rigid velocity field. Compatibility is therefore evaluated at a
	# shared physical anchor/seam point plus angular velocity, not by comparing
	# raw RigidBody3D.linear_velocity values.
	var compatible := (
		anchor_velocity_error <= anchor_velocity_tolerance
		and angular_velocity_error <= angular_tolerance
	)
	if compatible:
		return Decision.COMPATIBLE_REFRAME

	if request_mode == RequestMode.ALLOW_INELASTIC:
		return Decision.INELASTIC_BIND

	return Decision.REJECT_INCOMPATIBLE
