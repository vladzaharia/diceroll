class_name DieMesh
extends RefCounted
## Procedural rounded-cube die mesh (edge length 1, centred on the origin).
##
## Each of the 6 faces is its own grid (vertices are not shared between faces), so the
## die shader can tell faces apart. Per vertex:
##   UV       face-local coordinates in 0..1 (the flat area is the middle, bevels at the rim)
##   CUSTOM0  (u.x, u.y, u.z, slot) - the face's in-plane "right" axis and its face slot 0..5
## Face slot k shows die.faces[k]. Slots are laid out so opposite slots sum to 5
## (0/5, 1/4, 2/3), i.e. a default 1..6 die has opposite faces summing to 7.

## Face normals per slot (model space).
const DIRS: Array[Vector3] = [
	Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN,
]
## In-plane "u" (texture right) axis per slot; v = u x n is texture down.
const U_AXES: Array[Vector3] = [
	Vector3.RIGHT, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.RIGHT,
]

## Bevel radius in half-extent units (0..1). Must match `bevel` in die.gdshader.
const BEVEL := 0.26
const HALF := 0.5

static var _mesh: ArrayMesh


static func face_u(slot: int) -> Vector3:
	return U_AXES[slot]


static func face_v(slot: int) -> Vector3:
	return U_AXES[slot].cross(DIRS[slot])


## Basis that puts face `slot` up (+Y) with its texture right along +X and texture down
## along +Z (towards the camera), i.e. upright for a camera looking down -Z.
static func up_basis(slot: int) -> Basis:
	var m := Basis(face_u(slot), DIRS[slot], face_v(slot))  # columns
	return m.transposed()  # orthonormal, det +1 -> inverse


## Face slot currently pointing most upward for a body with the given global basis.
static func up_slot(b: Basis) -> int:
	var best := 0
	var best_dot := -2.0
	for k in 6:
		var d := (b * DIRS[k]).normalized().dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best = k
	return best


## Distance from the centre to the lowest point along -Y for a body with this basis
## (support function of the rounded box). 0.5 when resting flat.
static func support_down(b: Basis) -> float:
	var r := BEVEL * HALF
	var inner := HALF - r
	var s := absf(b.x.y) + absf(b.y.y) + absf(b.z.y)
	return inner * s + r


## Drops the cached mesh (call before quitting to avoid leak reports).
static func clear_cache() -> void:
	_mesh = null


static func get_mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build()
	return _mesh


static func _grid_coords() -> PackedFloat32Array:
	# Dense samples in the bevels, sparse in the flat middle.
	var f := 1.0 - BEVEL
	var out := PackedFloat32Array()
	var bev_steps := 7
	var flat_steps := 4
	for i in bev_steps:
		out.append(-1.0 + BEVEL * float(i) / bev_steps)
	for i in flat_steps:
		out.append(-f + 2.0 * f * float(i) / flat_steps)
	for i in bev_steps + 1:
		out.append(f + BEVEL * float(i) / bev_steps)
	return out


static func _build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var cs := _grid_coords()
	var n := cs.size()
	var f := 1.0 - BEVEL
	var base := 0
	for slot in 6:
		var nrm := DIRS[slot]
		var u := face_u(slot)
		var v := face_v(slot)
		for j in n:
			for i in n:
				var a := cs[i]
				var b := cs[j]
				var p := nrm + u * a + v * b  # point on the unit cube surface
				var inner := p.clamp(Vector3(-f, -f, -f), Vector3(f, f, f))
				var dn := (p - inner).normalized()
				var pos := (inner + dn * BEVEL) * HALF
				st.set_normal(dn)
				st.set_uv(Vector2(a * 0.5 + 0.5, b * 0.5 + 0.5))
				st.set_custom(0, Color(u.x, u.y, u.z, float(slot)))
				st.add_vertex(pos)
		for j in n - 1:
			for i in n - 1:
				var i0 := base + j * n + i
				var i1 := i0 + 1
				var i2 := i0 + n
				var i3 := i2 + 1
				# Godot treats clockwise (seen from outside) as front-facing.
				for tri in [[i0, i1, i3], [i0, i3, i2]]:
					_add_tri(st, tri, nrm, cs, n, base, u, v)
		base += n * n
	return st.commit()


static func _add_tri(st: SurfaceTool, tri: Array, nrm: Vector3, cs: PackedFloat32Array, n: int, base: int, u: Vector3, v: Vector3) -> void:
	var pts: Array[Vector3] = []
	for idx: int in tri:
		var k: int = idx - base
		pts.append(nrm + u * cs[k % n] + v * cs[k / n])
	var c := (pts[1] - pts[0]).cross(pts[2] - pts[0])
	if c.dot(nrm) < 0.0:
		st.add_index(tri[0])
		st.add_index(tri[1])
		st.add_index(tri[2])
	else:
		st.add_index(tri[0])
		st.add_index(tri[2])
		st.add_index(tri[1])
