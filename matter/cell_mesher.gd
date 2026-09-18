class_name CellMesher
extends RefCounted

const FACE_DIRECTIONS := [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]

const FACE_NORMALS := [
	Vector3(1, 0, 0),
	Vector3(-1, 0, 0),
	Vector3(0, 1, 0),
	Vector3(0, -1, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1),
]

const FACE_VERTICES := [
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)],
	[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(0, 0, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
]

const TRIANGLE_FRONT_ORDER := [0, 2, 1]


static func count_exposed_faces(volume: CellVolume) -> int:
	var face_count := 0
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				for direction in FACE_DIRECTIONS:
					if volume.get_cell(cell + direction) == CellVolume.EMPTY:
						face_count += 1
	return face_count


static func build_mesh(volume: CellVolume) -> ArrayMesh:
	assert(volume != null)
	return build_mesh_region(volume, Vector3i.ZERO, volume.size)


static func build_mesh_region(volume: CellVolume, from_cell: Vector3i, to_cell: Vector3i) -> ArrayMesh:
	assert(volume != null)
	assert(
		from_cell.x >= 0 and from_cell.y >= 0 and from_cell.z >= 0
		and to_cell.x <= volume.size.x and to_cell.y <= volume.size.y and to_cell.z <= volume.size.z
		and from_cell.x <= to_cell.x and from_cell.y <= to_cell.y and from_cell.z <= to_cell.z
	)
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var emitted := false

	for z in range(from_cell.z, to_cell.z):
		for y in range(from_cell.y, to_cell.y):
			for x in range(from_cell.x, to_cell.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var origin := Vector3(x, y, z)
				for face_index in range(FACE_DIRECTIONS.size()):
					if volume.get_cell(cell + FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var face_vertices: Array = FACE_VERTICES[face_index]
					for triangle_start in [0, 3]:
						for local_index in TRIANGLE_FRONT_ORDER:
							surface.set_normal(FACE_NORMALS[face_index])
							surface.add_vertex(origin + Vector3(face_vertices[triangle_start + local_index]))
							emitted = true

	if not emitted:
		return mesh
	return surface.commit(mesh)
