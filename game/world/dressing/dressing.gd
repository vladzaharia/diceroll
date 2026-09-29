class_name Dressing
extends RefCounted
## Seeded, rule-checked set dressing shared by every biome (see Biome.build).
##
## A board's look = the biome's fixed "frame" (floor, walls, terrain, sky) plus variable
## pieces picked from a variant seed: the centre set piece, the side / back kits, the moat
## corner vignettes, prop palettes (banner colours, tree species and colours) and the ground
## scatter. The same seed always gives the same board; the run seed gives each run its own.
##
##   Dressing.begin("glade", variant_seed, layout_scale, ring_extent, dressing_node)
##   Dressing.place(Dressing.FOREST + "Tree_3_B_Color1.gltf", Vector3(x, 0, z), yaw, 0.8)
##   Dressing.scatter([...], 60, "border")            # MultiMesh ground clutter
##   Dressing.finish()                                 # builds the MultiMeshes
##
## Placement rules (checked by fits()): never on or overlapping the ring tiles, never in the
## set-piece disc, inside the island outline, on flat ground (one terrain height under the
## whole footprint, never in the Magma channel), no overlap with earlier props, and height
## limits by zone so nothing tall stands between the default cameras and the hero's ring:
## the front strip only takes low props, the side strips take tall ones only toward the back.
## All positions here are final world positions (already spread to the ring size) and are
## tagged "prescaled" so Biome._spread() leaves them alone.

const FOREST := Props.K + "forest/"
const DX := Props.K + "dungeon_x/"
const RES := Props.K + "resources/"
const TX := Props.K + "tools_x/"
const WX := Props.K + "weapons_x/"
const SKP := Props.K + "skeleton_props/"
const ORC := Props.K + "mystery/orc/"
const WOOD := Props.K + "mystery/woodcutter/"
const PAL := Props.K + "mystery/paladin/"
const CELL := 2.1
const MM_SHADER := preload("res://game/world/dressing/prop_mm.gdshader")

## Current build state (set by begin()).
static var id := ""
## Layout index 0..8 (set piece = layout % 3; side / corner kits cycle differently).
static var layout := 0
static var rng := RandomNumberGenerator.new()
static var s := 1.0
static var extent := Biome.BASE_EXTENT
static var half := Biome.ISLAND_HALF
## Radius around the centre kept for the set piece (final units).
static var centre_r := 2.9
static var d: Node3D
static var blocks := false
static var _occ: Array = []          # [Vector2 centre, radius]
static var _mm: Dictionary = {}      # key -> {path, tint, strength, emission, xforms, colors, parent, shadow}
static var _info: Dictionary = {}    # path -> {size, y0, meshes: [[Mesh, Transform3D]]}
static var _mats: Dictionary = {}


## Variant seed -> layout index (0..8).
static func layout_of(variant_seed: int) -> int:
	return posmod(variant_seed, 9)


static func begin(p_id: String, variant_seed: int, p_s: float, p_extent: float, p_d: Node3D) -> void:
	id = p_id
	layout = layout_of(variant_seed)
	rng.seed = hash([p_id, variant_seed, "dress"])
	s = p_s
	extent = p_extent
	half = Biome.ISLAND_HALF * p_s
	centre_r = 2.9 * minf(1.0 + (p_s - 1.0) * 1.4, 1.45)
	d = p_d
	blocks = BiomeBlocks.LOOKS.has(p_id)
	_occ.clear()
	_mm.clear()


## Which of three kits a slot uses: `slot` 0 = set piece, 1 = sides / back, 2 = corners.
## Layouts 0..2 use kit i for everything (so the first three read as three distinct
## boards); 3..8 mix them.
static func kit(slot: int) -> int:
	var v := layout % 3
	var k := layout / 3
	return (v + slot * k) % 3


static func pick(list: Array) -> Variant:
	return list[rng.randi() % list.size()]


static func chance(p: float) -> bool:
	return rng.randf() < p


# --- geometry ---------------------------------------------------------------------------------

## Terrain top at a point (0 on the flat biomes).
static func gy(x: float, z: float) -> float:
	return BiomeBlocks.ground(x, z) if blocks else 0.0


static func _squircle(x: float, z: float, h: float) -> float:
	return pow(pow(absf(x) / h, 8.0) + pow(absf(z) / h, 8.0), 1.0 / 8.0)


## Zone of a point: "centre", "moat", "ring", "front", "back", "side" (outside the ring).
static func zone(x: float, z: float) -> String:
	var m := maxf(absf(x), absf(z))
	if m < centre_r:
		return "centre"
	if m < extent - CELL - 0.1:
		return "moat"
	if m < extent + 0.3:
		return "ring"
	if z > extent:
		return "front"
	if z < -extent:
		return "back"
	return "side"


## Tallest prop allowed at a point (keeps the default cameras' view of the ring clear).
static func max_height(x: float, z: float) -> float:
	match zone(x, z):
		"front":
			return 0.9
		"moat":
			return 1.5
		"side":
			var out := absf(x) - extent   # distance outside the ring
			if z > extent * 0.35:
				return 1.1 if out < 1.6 else 2.2
			return 2.4 if out < 1.2 else 99.0
		"back":
			return 99.0
	return 0.0


## True when a prop of footprint radius `r` and height `h` may stand at (x, z).
static func fits(x: float, z: float, r: float, h := 0.5, allow_moat := false) -> bool:
	if _squircle(absf(x) + r * 0.7, absf(z) + r * 0.7, half - 0.35) > 1.0:
		return false
	var m := maxf(absf(x), absf(z))
	# ring tiles (their footprint band plus a margin)
	if m + r > extent - CELL - 0.05 and m - r < extent + 0.3:
		return false
	if m - r < centre_r:
		return false
	if not allow_moat and m < extent:
		return false
	if h > max_height(x, z):
		return false
	# one ground height under the footprint, never lava
	var y := gy(x, z)
	if y < -0.05:
		return false
	var k := minf(r * 0.75, 0.45)
	for o in [Vector2(k, k), Vector2(-k, k), Vector2(k, -k), Vector2(-k, -k)]:
		if absf(gy(x + o.x, z + o.y) - y) > 0.05:
			return false
	for c in _occ:
		if Vector2(x, z).distance_to(c[0]) < r + float(c[1]):
			return false
	return true


static func occupy(x: float, z: float, r: float) -> void:
	_occ.append([Vector2(x, z), r])


# --- props ------------------------------------------------------------------------------------

## Size / base / meshes of a model (cached; one instancing per path).
static func info(path: String) -> Dictionary:
	if _info.has(path):
		return _info[path]
	var n := Props.inst(path)
	var meshes: Array = []
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != n and p != null:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		meshes.append([mi.mesh, t, mi])
		var a := t * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	var mats: Array = []
	for e in meshes:
		var mi: MeshInstance3D = e[2]
		var list: Array = []
		for si in (e[0] as Mesh).get_surface_count():
			list.append(mi.get_active_material(si))
		mats.append(list)
		e.resize(2)
	var out := {"size": box.size, "y0": box.position.y, "meshes": meshes, "mats": mats}
	n.free()
	_info[path] = out
	return out


## Footprint radius and height of a model at a scale. Tall props (trees) count their trunk
## area, not the canopy, so a row of trees can interlock their crowns.
static func footprint(path: String, k: float) -> Vector2:
	var sz: Vector3 = info(path).size
	var r := maxf(sz.x, sz.z) * 0.5 * k * 0.8
	if sz.y * k > 2.5:
		r = minf(r, 0.95)
	return Vector2(r, sz.y * k)


## Places a prop (its own node, a direct child of the dressing holder so the combat
## occluder pass can sink it). `at.y` is added to the ground height. Tint alpha > 0
## re-colours it with the atlas tint.
static func place(path: String, at: Vector3, yaw := 0.0, k := 1.0, tint := Color(0, 0, 0, 0),
		parent: Node3D = null) -> Node3D:
	var n := Props.inst(path, k)
	n.position = Vector3(at.x, gy(at.x, at.z) + at.y, at.z)
	n.rotation.y = deg_to_rad(yaw)
	n.set_meta("prescaled", true)
	n.set_meta("dress", true)
	(parent if parent else d).add_child(n)
	if tint.a > 0.0:
		Props.tint(n, Color(tint.r, tint.g, tint.b), tint.a)
	var fp := footprint(path, k)
	occupy(at.x, at.z, fp.x)
	return n


## place() only when the spot passes fits(); returns null otherwise.
static func try_place(path: String, x: float, z: float, yaw := 0.0, k := 1.0, tint := Color(0, 0, 0, 0),
		allow_moat := false) -> Node3D:
	var fp := footprint(path, k)
	if not fits(x, z, fp.x, fp.y, allow_moat):
		return null
	return place(path, Vector3(x, 0, z), yaw, k, tint)


## try_place() at (x, z), then at up to `tries` jittered spots within `spread` of it.
static func place_near(path: String, x: float, z: float, k := 1.0, spread := 1.2, tint := Color(0, 0, 0, 0),
		tries := 10) -> Node3D:
	var n := try_place(path, x, z, rng.randf() * 360.0, k, tint)
	var i := 0
	while n == null and i < tries:
		i += 1
		var a := rng.randf() * TAU
		var r := spread * sqrt(float(i) / float(tries))
		n = try_place(path, x + cos(a) * r, z + sin(a) * r, rng.randf() * 360.0, k, tint)
	return n


## Tries up to `tries` random spots in a zone rect (final coords) for a prop.
static func place_in(path: String, rect: Rect2, k := 1.0, tint := Color(0, 0, 0, 0), tries := 14) -> Node3D:
	for i in tries:
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var z := rng.randf_range(rect.position.y, rect.end.y)
		var n := try_place(path, x, z, rng.randf() * 360.0, k, tint)
		if n:
			return n
	return null


## Batches a copy of `path` into a MultiMesh (one draw per mesh per group). Low clutter goes
## under the never-sunk Floor; `group` splits tall batches by island sector so the occluder
## pass only sinks the nearby part.
static func mm(path: String, pos: Vector3, yaw: float, k: float, tint := Color(0, 0, 0, 0), group := "floor",
		col := Color.WHITE, shadow := false) -> void:
	var key := "%s|%s|%s|%s" % [path, tint.to_html(), group, shadow]
	if not _mm.has(key):
		_mm[key] = {"path": path, "tint": tint, "group": group, "xforms": [], "colors": [], "shadow": shadow}
	var e: Dictionary = _mm[key]
	var b := Basis().rotated(Vector3.UP, deg_to_rad(yaw)).scaled(Vector3.ONE * k)
	e.xforms.append(Transform3D(b, Vector3(pos.x, gy(pos.x, pos.z) + pos.y, pos.z)))
	e.colors.append(col)


## Sector name of a point (groups tall MultiMeshes so each covers one part of the island).
static func sector(x: float, z: float) -> String:
	var sx := "w" if x < -extent * 0.4 else ("e" if x > extent * 0.4 else "")
	var sz := "n" if z < -extent * 0.4 else ("s" if z > extent * 0.4 else "")
	var out := sz + sx
	return "sec_" + (out if out != "" else "c")


## Ground clutter: `count` MultiMesh copies of `paths` scattered over a zone ("border":
## everything outside the ring, "moat": inside it, "all"). Density falls off toward the ring
## (and toward the front strip's middle, where the camera looks), so clutter gathers at the
## island rim and around props. Only models lower than `max_h` (after scaling) are used.
static func scatter(paths: Array, count: int, where := "border", k_range := Vector2(0.8, 1.2),
		tint := Color(0, 0, 0, 0), col_jitter := 0.08, max_h := 0.7) -> int:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 10:
		tries += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var zn := zone(x, z)
		if zn == "ring" or zn == "centre":
			continue
		if where == "border" and zn == "moat":
			continue
		if where == "moat" and zn != "moat":
			continue
		if _squircle(x, z, half - 0.4) > 1.0:
			continue
		var m := maxf(absf(x), absf(z))
		if m > extent - CELL - 0.15 and m < extent + 0.4:
			continue
		# falloff: sparse next to the ring, dense at the rim
		var dist := absf(m - (extent - CELL * 0.5)) - CELL * 0.5
		var w := clampf(dist / 2.2, 0.15, 1.0)
		if zn == "front":
			w *= lerpf(0.45, 1.0, clampf(absf(x) / extent, 0.0, 1.0))
		if rng.randf() > w:
			continue
		var y := gy(x, z)
		if y < -0.05:
			continue
		var path: String = paths[rng.randi() % paths.size()]
		var k := rng.randf_range(k_range.x, k_range.y)
		var fp := footprint(path, k)
		if fp.y > max_h:
			continue
		# keep clutter off the bigger props
		var hit := false
		for c in _occ:
			if Vector2(x, z).distance_to(c[0]) < float(c[1]) * 0.8:
				hit = true
				break
		if hit:
			continue
		var j := 1.0 + rng.randf_range(-col_jitter, col_jitter)
		mm(path, Vector3(x, 0, z), rng.randf() * 360.0, k, tint, "floor", Color(j, j, j))
		placed += 1
	return placed


## Builds the batched MultiMeshes (call once, after all dressing is placed).
static func finish() -> void:
	if d == null:
		return
	var floor_node: Node3D = d.get_node_or_null("Floor")
	if floor_node == null:
		floor_node = Node3D.new()
		floor_node.name = "Floor"
		d.add_child(floor_node)
	var groups: Dictionary = {}
	for key in _mm:
		var e: Dictionary = _mm[key]
		var parent: Node3D = floor_node
		if String(e.group) != "floor":
			if not groups.has(e.group):
				var g := Node3D.new()
				g.name = String(e.group)
				g.set_meta("prescaled", true)
				d.add_child(g)
				groups[e.group] = g
			parent = groups[e.group]
		var inf := info(String(e.path))
		var xs: Array = e.xforms
		for mi_idx in inf.meshes.size():
			var entry: Array = inf.meshes[mi_idx]
			var local: Transform3D = entry[1]
			var mesh: Mesh = entry[0]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_colors = true
			multi.mesh = mesh
			multi.instance_count = xs.size()
			for i in xs.size():
				multi.set_instance_transform(i, (xs[i] as Transform3D) * local)
				multi.set_instance_color(i, e.colors[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = String(e.path).get_file().get_basename()
			mmi.multimesh = multi
			mmi.set_meta("dress", true)
			mmi.material_override = _mm_material(String(e.path), mi_idx, e.tint)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if e.shadow \
					else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mmi)
	_mm.clear()


static func _mm_material(path: String, mesh_idx: int, tint: Color) -> Material:
	var inf := info(path)
	var base := (inf.mats[mesh_idx] as Array)[0] as BaseMaterial3D if not (inf.mats[mesh_idx] as Array).is_empty() else null
	var tex: Texture2D = base.albedo_texture if base else null
	var key := "%s|%s" % [tex.get_instance_id() if tex else 0, tint.to_html()]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = MM_SHADER
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b))
		m.set_shader_parameter("strength", tint.a)
		_mats[key] = m
	return _mats[key]


## `count` small vignettes spread along the front strip (low props only): `fill` is called
## as fill.call(group, index) for each spot that fits.
static func front_row(fill: Callable, count: int, r := 0.8) -> void:
	var z_lo := extent + 0.3 + r
	var z_hi := half - 0.9 - r
	if z_hi < z_lo:
		return
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		for attempt in 6:
			var x := lerpf(-half + 2.0, half - 2.0, t) + rng.randf_range(-1.2, 1.2)
			var z := rng.randf_range(z_lo, z_hi)
			if absf(x) < 1.4 and attempt < 3:
				continue    # keep the centre line (the camera's view of the ring) clearest
			if fits(x, z, r, 0.8):
				var g := group("Front", x, z, r)
				g.rotation.y = rng.randf() * TAU
				fill.call(g, i)
				break


# --- shared vignettes ---------------------------------------------------------------------------

## A leaning weapon (rotated about its grip so the head rests up, the tip in the ground).
static func stuck(parent: Node3D, path: String, pos: Vector3, yaw: float, tilt: float, k := 1.0,
		tint := Color(0, 0, 0, 0)) -> Node3D:
	var n := Props.inst(path, k)
	n.position = pos
	n.rotation = Vector3(deg_to_rad(tilt), deg_to_rad(yaw), 0.0)
	n.set_meta("prescaled", true)
	parent.add_child(n)
	if tint.a > 0.0:
		Props.tint(n, Color(tint.r, tint.g, tint.b), tint.a)
	return n


## A prop lying flat on its face (weapons, tools): tipped 90 degrees about x so its thin
## depth is vertical, lifted by half that depth.
static func lying(parent: Node3D, path: String, pos: Vector3, yaw: float, k := 1.0,
		tint := Color(0, 0, 0, 0)) -> Node3D:
	var inf := info(path)
	var n := Props.inst(path, k)
	var sz: Vector3 = inf.size
	n.rotation = Vector3(deg_to_rad(90.0), deg_to_rad(yaw), 0.0)
	n.position = pos + Vector3.UP * sz.z * 0.5 * k
	n.set_meta("prescaled", true)
	parent.add_child(n)
	if tint.a > 0.0:
		Props.tint(n, Color(tint.r, tint.g, tint.b), tint.a)
	return n


## A small group node (vignette) at a final position: children are local to it and it
## counts as one prop for the occluder pass.
static func group(name: String, x: float, z: float, r: float, parent: Node3D = null) -> Node3D:
	var g := Node3D.new()
	g.name = name
	g.position = Vector3(x, gy(x, z), z)
	g.set_meta("prescaled", true)
	g.set_meta("dress", true)
	(parent if parent else d).add_child(g)
	occupy(x, z, r)
	return g
