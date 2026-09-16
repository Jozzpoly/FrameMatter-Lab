class_name MatterSurfaceStyle
extends RefCounted

# One neutral visual identity for Matter regardless of the current physics host.
# Provider kind (STATIC/RigidBody) is simulation state, not material identity.
# This is intentionally a tiny shared source of truth, not a general material system.
const BASE_ALBEDO := Color(0.72, 0.77, 0.84, 1.0)
const BASE_ROUGHNESS := 0.82


static func create_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = BASE_ALBEDO
	material.roughness = BASE_ROUGHNESS
	return material
