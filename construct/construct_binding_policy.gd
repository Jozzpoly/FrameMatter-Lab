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
	linear_velocity_error: float,
	angular_velocity_error: float,
	linear_tolerance: float = 0.0001,
	angular_tolerance: float = 0.0001
) -> Decision:
	assert(linear_velocity_error >= 0.0)
	assert(angular_velocity_error >= 0.0)
	assert(linear_tolerance >= 0.0)
	assert(angular_tolerance >= 0.0)

	if request_mode == RequestMode.NONE:
		return Decision.KEEP_SEPARATE

	var compatible := (
		linear_velocity_error <= linear_tolerance
		and angular_velocity_error <= angular_tolerance
	)
	if compatible:
		return Decision.COMPATIBLE_REFRAME

	if request_mode == RequestMode.ALLOW_INELASTIC:
		return Decision.INELASTIC_BIND

	return Decision.REJECT_INCOMPATIBLE
