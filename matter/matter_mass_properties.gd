class_name MatterMassProperties
extends RefCounted


static func calculate(volume: CellVolume, mass_per_cell: float = 1.0) -> Dictionary:
	assert(volume != null)
	assert(mass_per_cell > 0.0)
	var solid_count := volume.count_solid()
	assert(solid_count > 0)

	var total_mass := float(solid_count) * mass_per_cell
	var center := MatterTopology.center_of_mass_local(volume)

	var i_xx := 0.0
	var i_yy := 0.0
	var i_zz := 0.0
	var i_xy := 0.0
	var i_xz := 0.0
	var i_yz := 0.0
	var cube_axis_inertia := mass_per_cell / 6.0

	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var cell_center := Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)
				var r := cell_center - center
				i_xx += cube_axis_inertia + mass_per_cell * (r.y * r.y + r.z * r.z)
				i_yy += cube_axis_inertia + mass_per_cell * (r.x * r.x + r.z * r.z)
				i_zz += cube_axis_inertia + mass_per_cell * (r.x * r.x + r.y * r.y)
				i_xy -= mass_per_cell * r.x * r.y
				i_xz -= mass_per_cell * r.x * r.z
				i_yz -= mass_per_cell * r.y * r.z

	var inertia_tensor := Basis(
		Vector3(i_xx, i_xy, i_xz),
		Vector3(i_xy, i_yy, i_yz),
		Vector3(i_xz, i_yz, i_zz)
	)

	return {
		"mass": total_mass,
		"center_of_mass_local": center,
		"inertia_tensor_local": inertia_tensor,
	}


static func world_inertia(local_inertia: Basis, world_basis: Basis) -> Basis:
	var rotation := world_basis.orthonormalized()
	return rotation * local_inertia * rotation.transposed()


static func world_inverse_inertia(local_inertia: Basis, world_basis: Basis) -> Basis:
	return world_inertia(local_inertia, world_basis).inverse()
