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

# FACE_VERTICES remains the shared logical face/triangle template used by
# presentation consumers as well as this mesher. Its stored triangle order has
# geometric cross products aligned with FACE_NORMALS, while Godot renders
# clockwise triangle winding as the front side. build_mesh() therefore reverses
# each stored triangle at emission time so the visible front face and authored
# outward normal agree without silently changing the presentation consumers'
# face-corner assumptions.
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
	var mesh := ArrayMesh.new()
	if volume.count_solid() == 0:
		return mesh

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
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

	return surface.commit(mesh)
