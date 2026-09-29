class_name BiomeBlocks
extends RefCounted
## The three BlockBits biomes: Verdant Glade (sunny meadow), Frostpeak (snowy peak) and
## Magma Depths (basalt over lava). Biome.build() owns the shared parts (environment, lights,
## island, clouds, ambient particles, spreading) and calls dress() for the rest.
##
## Terrain: the island top is paved with BlockBits cubes on the ring's own grid (cell =
## BoardView.PITCH, so every ring tile sits on one block). The border outside the ring rises
## in steps at the back and sides (a heightmap, see _height()); the flat paving is one
## MultiMesh per block type ("Floor", never sunk by the occluder pass), raised blocks are
## ordinary props so the combat camera can sink them like any other dressing.
##
## Dressing is placed at final (already spread) positions and tagged "prescaled", so
## Biome._spread() leaves it alone; props stand on the terrain height at their spot.

const B := Props.K + "blocks/"
const CELL := 2.1

## Looks share Biome.LOOKS keys; extra keys: sea ("clouds" | "lava"), tile_base.
const LOOKS := {
	"glade": {
		"sky_top": Color(0.3, 0.56, 0.92), "sky_horizon": Color(0.88, 0.93, 0.96),
		"sky_bottom": Color(0.58, 0.74, 0.9), "sky_glow": Color(1.0, 0.9, 0.6),
		"glow_strength": 0.55, "stars": 0.0,
		"fog": Color(0.66, 0.8, 0.95), "fog_density": 0.0, "fog_height_density": 0.0,
		"ambient": Color(0.7, 0.8, 0.95), "ambient_energy": 0.5,
		"key": Color(1.0, 0.9, 0.72), "key_energy": 1.35, "key_rot": Vector3(-52.0, -32.0, 0.0),
		"fill": Color(0.62, 0.78, 1.0), "fill_energy": 0.4,
		"exposure": 0.92, "saturation": 1.12, "contrast": 1.1, "glow": 0.25,
		"island_top": Color(0.4, 0.62, 0.3), "island_side": Color(0.5, 0.38, 0.26),
		"island_bottom": Color(0.26, 0.2, 0.16),
		"particles": "pollen", "light": Color(1.0, 0.72, 0.4),
		"cloud_deep": Color(0.6, 0.74, 0.92), "cloud_light": Color(0.98, 0.99, 1.0), "cloud_rim": Color(1.0, 0.95, 0.8),
		"sea": "clouds", "tile_base": Color(0.5, 0.42, 0.32),
	},
	"frost": {
		"sky_top": Color(0.2, 0.3, 0.55), "sky_horizon": Color(0.78, 0.86, 0.96),
		"sky_bottom": Color(0.4, 0.5, 0.66), "sky_glow": Color(0.75, 0.9, 1.0),
		"glow_strength": 0.45, "stars": 0.12,
		"fog": Color(0.62, 0.74, 0.9), "fog_density": 0.0, "fog_height_density": 0.0,
		"ambient": Color(0.6, 0.72, 1.0), "ambient_energy": 0.5,
		"key": Color(0.92, 0.96, 1.0), "key_energy": 1.2, "key_rot": Vector3(-46.0, 38.0, 0.0),
		"fill": Color(0.45, 0.65, 1.0), "fill_energy": 0.5,
		"exposure": 0.9, "saturation": 1.1, "contrast": 1.12, "glow": 0.4,
		"island_top": Color(0.86, 0.9, 0.96), "island_side": Color(0.5, 0.55, 0.66),
		"island_bottom": Color(0.2, 0.24, 0.36),
		"particles": "snow", "light": Color(0.55, 0.85, 1.0),
		"cloud_deep": Color(0.42, 0.52, 0.7), "cloud_light": Color(0.88, 0.93, 1.0), "cloud_rim": Color(0.7, 0.9, 1.0),
		"sea": "clouds", "tile_base": Color(0.52, 0.58, 0.68),
	},
	"magma": {
		"sky_top": Color(0.05, 0.04, 0.12), "sky_horizon": Color(0.42, 0.12, 0.12),
		"sky_bottom": Color(0.2, 0.06, 0.06), "sky_glow": Color(1.0, 0.45, 0.16),
		"glow_strength": 0.45, "stars": 0.25,
		"fog": Color(0.16, 0.08, 0.14), "fog_density": 0.0, "fog_height_density": 0.0,
		"ambient": Color(0.46, 0.44, 0.7), "ambient_energy": 0.55,
		"key": Color(1.0, 0.86, 0.74), "key_energy": 1.25, "key_rot": Vector3(-54.0, -140.0, 0.0),
		"fill": Color(0.42, 0.48, 1.0), "fill_energy": 0.6,
		"exposure": 1.0, "saturation": 1.08, "contrast": 1.1, "glow": 0.22,
		"island_top": Color(0.12, 0.11, 0.13), "island_side": Color(0.09, 0.08, 0.1),
		"island_bottom": Color(0.4, 0.12, 0.05),
		"particles": "embers", "light": Color(1.0, 0.45, 0.15),
		"cloud_deep": Color(0.2, 0.05, 0.03), "cloud_light": Color(0.5, 0.14, 0.05), "cloud_rim": Color(1.0, 0.5, 0.2),
		"sea": "lava", "tile_base": Color(0.6, 0.57, 0.56), "tile_glow": Color(1.0, 0.4, 0.1),
	},
}

## Terrain palette per biome: flat paving (weighted), raised tops, raised fill, accents.
const TERRAIN := {
	"glade": {"floor": [["grass", 1]], "path": "dirt", "floor_shader": "meadow",
		"top": ["grass", "grass", "dirt_with_grass"], "fill": "dirt", "tint": Color(0.86, 0.92, 0.8),
		"raise_tint": Color(0.86, 0.9, 0.72)},
	"frost": {"floor": [["snow", 1]], "floor_shader": "snow",
		"top": ["snow", "dirt_with_snow", "snow"], "fill": "stone", "tint": Color(0.8, 0.86, 0.97),
		"raise_tint": Color(0.92, 0.95, 1.0)},
	"magma": {"floor": [["stone_dark", 1]], "top": ["stone_dark"], "fill": "stone_dark",
		"tint": Color(1, 1, 1), "shader": "basalt", "channel": true},
}

## Current build state (set by dress()).
static var _id := ""
static var _s := 1.0
static var _extent := 7.35
static var _off := 0.5
static var _heights: Dictionary = {}
static var _rng := RandomNumberGenerator.new()
static var _meshes: Dictionary = {}
static var _chan: Dictionary = {}
## Lava surface height in the Magma channel (world y).
const CHANNEL_Y := -0.32


# --- entry points (called by Biome.build) ---------------------------------------------------

static func dress(id: String, root: Node3D, d: Node3D, c: Node3D) -> void:
	_id = id
	_s = Biome.layout_scale()
	_extent = Biome.BASE_EXTENT * _s
	# ring side parity: an even side puts tile centres on half cells
	var q := int(round((_extent - CELL * 0.5) / (CELL * 0.5)))
	_off = 0.5 if q % 2 == 1 else 0.0
	# the terrain's height breaks vary with the board's dressing variant (Magma keeps its
	# fixed framing: tight island, channel beside the ring, falls behind)
	_rng.seed = Biome.seed_of(id) * 7919 + (0 if id == "magma" else Dressing.layout * 104729)
	_terrain(d)
	match id:
		"glade":
			_glade(root, d, c)
		"frost":
			_frost(root, d, c)
		"magma":
			_magma(root, d, c)


## One of the four moat-corner vignettes (larger rings).
static func inner_corner(id: String, holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> void:
	match id:
		"glade":
			DressGlade.corner(holder, p, yaw, sx, sz)
		"frost":
			DressFrost.corner(holder, p, yaw, sx, sz)
		"magma":
			if DressMagma.corner(holder, p, yaw, sx, sz):
				return
			var v := Node3D.new()
			v.name = "Vent"
			v.position = p
			holder.add_child(v)
			basalt_columns(v, Vector3(sx * 0.2, 0, sz * 0.2), 0.95, 8, 3 + int(sx * 2 + sz), 0.55)
			var pool := lava_pool(v, Vector3(-sx * 0.75, 0.02, -sz * 0.05), 0.42)
			pool.name = "Fissure"
			pool.scale = Vector3(1.0, 1.0, 0.55)
			pool.rotation.y = deg_to_rad(yaw + 35.0)
			crack_decal(v, Vector3(-sx * 0.5, 0.02, sz * 0.4), 1.4, yaw)
			Biome.flame(v, Vector3(-sx * 0.75, 0.1, -sz * 0.05), Color(1.0, 0.45, 0.12), 0.2, 5)
			Biome.flicker_light(holder, p + Vector3(0, 0.9, 0), Color(1.0, 0.42, 0.12), 0.9, 3.0)


# --- terrain ------------------------------------------------------------------------------

## Height in blocks of the terrain column at cell (i, j) (0 = flat paving).
static func _height(cx: float, cz: float) -> int:
	var e := _extent + 0.2
	var half := Biome.ISLAND_HALF * _s
	if absf(cx) < e and absf(cz) < e:
		return 0
	var edge := maxf(absf(cx), absf(cz)) > half - CELL * 0.75
	var back := cz < -e
	var front := cz > e
	var up := 0
	match _id:
		"glade":
			if back:
				up = 2 if edge else 1
			elif not front:
				up = (1 if edge else 0) if cz < 0.0 else (1 if edge and cz < _extent * 0.45 else 0)
		"frost":
			if back:
				up = 3 if edge else (2 if absf(cx) > _extent * 0.55 else 1)
			elif not front:
				up = (2 if edge else 1) if cz < -_extent * 0.3 else (1 if edge else 0)
		"magma":
			if back:
				up = 2 if edge else 1
			elif not front:
				up = (2 if edge else 0) if cz < 0.0 else (1 if edge and cz < _extent * 0.5 else 0)
	# break up the rows
	if up > 0 and _rng.randf() < 0.22:
		up = maxi(up - 1, 0) if _rng.randf() < 0.6 else up + 1
	return up


## Top surface height (world y) at a position.
static func ground(x: float, z: float) -> float:
	var i := int(floor(x / CELL - _off + 0.5))
	var j := int(floor(z / CELL - _off + 0.5))
	if _chan.has(Vector2i(i, j)):
		return CHANNEL_Y
	return float(_heights.get(Vector2i(i, j), 0)) * CELL


## True for a cell under a ring tile (patches stay off the ring so tiles read on one colour).
static func _ring_cell(cx: float, cz: float) -> bool:
	var m := maxf(absf(cx), absf(cz))
	return m > _extent - CELL - 0.2 and m < _extent + 0.2


## Glade: a worn dirt path from the front edge of the island up to the set piece, with a
## one-cell jog so it does not read as a ruler line.
static func _path_cell(cx: float, cz: float) -> bool:
	var inner := _extent - CELL
	var jog := CELL * 0.5 if cz > _extent + 0.2 else -CELL * 0.5
	if absf(cx - jog) > CELL * 0.6:
		return false
	return cz > 2.6 * _s and not (cz > inner and cz < _extent + 0.2)


## True for a cell of the Magma lava channel: the column just outside the ring on both
## sides (running off the island's front edge) and the row behind the ring.
static func _is_channel(cx: float, cz: float) -> bool:
	var e := _extent + 0.2
	var ax := absf(cx)
	if ax > e and ax < e + CELL:
		return true
	return cz < -e and cz > -e - CELL and ax < e + CELL


static func _pick(list: Array) -> String:
	var total := 0
	for e in list:
		total += int(e[1])
	var r := _rng.randi_range(0, total - 1)
	for e in list:
		r -= int(e[1])
		if r < 0:
			return String(e[0])
	return String(list[0][0])


static func _terrain(d: Node3D) -> void:
	_heights.clear()
	_chan.clear()
	var pal: Dictionary = TERRAIN[_id]
	var shader_mat: Material = basalt_material() if String(pal.get("shader", "")) == "basalt" else null
	var chan_node: Node3D = null
	var half := Biome.ISLAND_HALF * _s
	var n := int(ceil(half / CELL)) + 1
	var flat: Dictionary = {}     # block name -> Array[Transform3D]
	var floor_node := Node3D.new()
	floor_node.name = "Floor"
	d.add_child(floor_node)
	var basis := Basis().scaled(Vector3.ONE * (CELL * 0.5))
	# low-frequency meadow / snowfield patches: per-cell tint and patch blocks
	var nz := FastNoiseLite.new()
	nz.seed = Biome.seed_of(_id) * 31
	nz.frequency = 0.09
	var patch_cols: Array = pal.get("patch_tints", [])
	var cols: Dictionary = {}     # block name -> Array[Color]
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var cx := (float(i) + _off) * CELL
			var cz := (float(j) + _off) * CELL
			# squircle clip (the island's own outline), a hair inside so edges stay on the rock
			var r := pow(pow(absf(cx) / half, 8.0) + pow(absf(cz) / half, 8.0), 1.0 / 8.0)
			if r > 1.0 - CELL * 0.2 / half:
				continue
			var up := _height(cx, cz)
			var chan := bool(pal.get("channel", false)) and _is_channel(cx, cz)
			if chan:
				up = 0
				_chan[Vector2i(i, j)] = true
				if chan_node == null:
					chan_node = Node3D.new()
					chan_node.name = "LavaChannel"
					chan_node.set_meta("prescaled", true)
					d.add_child(chan_node)
				var lp := MeshInstance3D.new()
				var pm := PlaneMesh.new()
				pm.size = Vector2(CELL, CELL)
				lp.mesh = pm
				lp.material_override = channel_material()
				lp.position = Vector3(cx, CHANNEL_Y, cz)
				lp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				chan_node.add_child(lp)
			_heights[Vector2i(i, j)] = up
			var name := _pick(pal.floor) if up == 0 else String(pal.fill)
			var nv := nz.get_noise_2d(cx, cz)
			if up == 0 and pal.has("patch") and nv > float(pal.get("patch_at", 0.3)) and not _ring_cell(cx, cz):
				name = String(pal.patch)
			if up == 0 and pal.has("path") and _path_cell(cx, cz):
				name = String(pal.path)
			if not flat.has(name):
				flat[name] = []
				cols[name] = []
			var tint := Color(1, 1, 1)
			if patch_cols.size() >= 2:
				var k := clampf(nz.get_noise_2d(cx * 1.7 + 40.0, cz * 1.7) * 0.9 + 0.5, 0.0, 1.0)
				tint = (patch_cols[0] as Color).lerp(patch_cols[1], k)
			cols[name].append(tint)
			flat[name].append(Transform3D(basis.rotated(Vector3.UP, PI * 0.5 * _rng.randi_range(0, 3)),
				Vector3(cx, -CELL * 0.5 - (0.55 if chan else 0.0), cz)))
			if up > 0:
				var col := Node3D.new()
				col.name = "Block"
				col.set_meta("prescaled", true)
				col.position = Vector3(cx, 0, cz)
				d.add_child(col)
				for k in up:
					var bn := String(pal.fill) if k < up - 1 else String(pal.top[_rng.randi_range(0, pal.top.size() - 1)])
					var mi := MeshInstance3D.new()
					var bm: Array = block_mesh(bn)
					mi.mesh = bm[0]
					mi.material_override = shader_mat if shader_mat else _floor_material(bm[1], pal.get("raise_tint", Color(0, 0, 0, 0)))
					mi.scale = Vector3.ONE * (CELL * 0.5)
					mi.position = Vector3(0, CELL * (k + 0.5), 0)
					mi.rotation.y = PI * 0.5 * _rng.randi_range(0, 3)
					col.add_child(mi)
	for name in flat:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bm: Array = block_mesh(String(name))
		mm.mesh = bm[0]
		if shader_mat:
			# plain boxes: no bevelled cube edges, so the floor reads as one surface
			var box := BoxMesh.new()
			box.size = Vector3(2, 2, 2)
			mm.mesh = box
		var xs: Array = flat[name]
		mm.use_colors = not patch_cols.is_empty()
		mm.instance_count = xs.size()
		for k in xs.size():
			mm.set_instance_transform(k, xs[k])
			if mm.use_colors:
				mm.set_instance_color(k, cols[name][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = String(name)
		mmi.multimesh = mm
		var fmat: Material = shader_mat
		if pal.has("floor_shader"):
			fmat = ground_material(String(pal.floor_shader) + ("_path" if String(name) == String(pal.get("path", "")) else ""))
			var box := BoxMesh.new()
			box.size = Vector3(2, 2, 2)
			mm.mesh = box
		mmi.material_override = fmat if fmat else _floor_material(bm[1], pal.tint, mm.use_colors)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		floor_node.add_child(mmi)


static var _basalt: ShaderMaterial
static var _ground_mats: Dictionary = {}

## Ground looks (terrain_top.gdshader parameters).
const GROUNDS := {
	"meadow": {"top_a": Color(0.33, 0.6, 0.22), "top_b": Color(0.56, 0.72, 0.26), "speck_color": Color(0.22, 0.46, 0.16),
		"side_color": Color(0.5, 0.35, 0.22), "patch_scale": 0.12, "speck_amount": 0.22, "speck_scale": 1.6},
	"meadow_path": {"top_a": Color(0.6, 0.45, 0.3), "top_b": Color(0.66, 0.52, 0.34), "speck_color": Color(0.5, 0.48, 0.44),
		"side_color": Color(0.5, 0.35, 0.22), "patch_scale": 0.5, "speck_amount": 0.5, "speck_scale": 5.0, "lip": 0.0},
	"snow": {"top_a": Color(0.82, 0.88, 0.97), "top_b": Color(0.95, 0.97, 1.0), "speck_color": Color(0.7, 0.8, 0.95),
		"side_color": Color(0.42, 0.46, 0.56), "patch_scale": 0.1, "speck_amount": 0.3, "glint": 1.2, "roughness": 0.7,
		"lip": 0.3},
}


## Shared ground material by look id (see GROUNDS).
static func ground_material(id: String) -> ShaderMaterial:
	if not _ground_mats.has(id):
		var m := ShaderMaterial.new()
		m.shader = preload("res://game/world/shaders/terrain_top.gdshader")
		var g: Dictionary = GROUNDS.get(id, GROUNDS["meadow"])
		for k in g:
			m.set_shader_parameter(k, g[k])
		_ground_mats[id] = m
	return _ground_mats[id]
static var _channel_mat: ShaderMaterial


## Calm world-space basalt (Magma terrain; see basalt.gdshader).
static func basalt_material() -> ShaderMaterial:
	if _basalt == null:
		_basalt = ShaderMaterial.new()
		_basalt.shader = preload("res://game/world/shaders/basalt.gdshader")
	return _basalt


static var _column_mat: ShaderMaterial


## Basalt for the hexagonal columns: lighter ash tops and warmer sides so the prisms read
## against the paving.
static func column_material() -> ShaderMaterial:
	if _column_mat == null:
		_column_mat = ShaderMaterial.new()
		_column_mat.shader = preload("res://game/world/shaders/basalt.gdshader")
		_column_mat.set_shader_parameter("top_color", Color(0.46, 0.41, 0.42))
		_column_mat.set_shader_parameter("side_color", Color(0.17, 0.14, 0.16))
		_column_mat.set_shader_parameter("slab", 1.4)
		_column_mat.set_shader_parameter("crack_density", 0.0)
	return _column_mat


## Crust-plate lava for the channel around the Magma ring (bright, fast-ish seams).
static func channel_material() -> ShaderMaterial:
	if _channel_mat == null:
		_channel_mat = ShaderMaterial.new()
		_channel_mat.shader = preload("res://game/world/shaders/lava_sea.gdshader")
		_channel_mat.set_shader_parameter("scale", 0.42)
		_channel_mat.set_shader_parameter("speed", 0.05)
		_channel_mat.set_shader_parameter("energy", 1.15)
		_channel_mat.set_shader_parameter("seam", 0.05)
		_channel_mat.set_shader_parameter("hot_share", 0.36)
		_channel_mat.set_shader_parameter("crust_seam", 0.12)
		_channel_mat.set_shader_parameter("plate_heat", 0.2)
		_channel_mat.set_shader_parameter("warm_crust", Color(0.2, 0.06, 0.04))
	return _channel_mat


## The flat paving is darkened a touch (`mul`, alpha 0 = as is) so ring tiles read on it.
static var _floor_mats: Dictionary = {}


static func _floor_material(base: Material, mul: Color, vcol := false) -> Material:
	if mul.a <= 0.0 or not base is BaseMaterial3D:
		return base
	var key := "%d|%s|%s" % [base.get_instance_id(), mul.to_html(), vcol]
	if not _floor_mats.has(key):
		var m := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
		m.albedo_color = mul
		m.vertex_color_use_as_albedo = vcol
		_floor_mats[key] = m
	return _floor_mats[key]


## [Mesh, Material] of a BlockBits cube (cached). Lava gets the glowing block material.
static func block_mesh(name: String) -> Array:
	if _meshes.has(name):
		return _meshes[name]
	var n := Props.inst(B + name + ".gltf")
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var mat: Material = mi.get_active_material(0)
	if name == "lava":
		mat = lava_block_material(mat)
	_meshes[name] = [mi.mesh, mat]
	n.free()
	return _meshes[name]


static func lava_block_material(base: Material) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://game/world/shaders/block_glow.gdshader")
	var bm := base as BaseMaterial3D
	if bm:
		sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
	return sm


## A single block prop (tinted or not) at a final position.
static func block(parent: Node3D, name: String, pos: Vector3, size := CELL, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm: Array = block_mesh(name)
	mi.mesh = bm[0]
	mi.material_override = bm[1]
	mi.scale = Vector3.ONE * size * 0.5
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	parent.add_child(mi)
	return mi


# --- placement helpers ----------------------------------------------------------------------

## Places a prop at an authored (7x7 layout) spot: spread by the layout scale, standing on
## the terrain there, tagged prescaled.
static func put(d: Node3D, path: String, at: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	var p := spot(at)
	var n := Props.put(d, path, p, yaw, scale)
	n.set_meta("prescaled", true)
	return n


## Final position of an authored spot (x/z spread, y = terrain + at.y).
static func spot(at: Vector3) -> Vector3:
	var x := at.x * _s
	var z := at.z * _s
	return Vector3(x, ground(x, z) + at.y, z)


static func _tag(n: Node3D) -> Node3D:
	n.set_meta("prescaled", true)
	return n


static func tinted(d: Node3D, path: String, at: Vector3, yaw: float, scale: float, color: Color,
		strength := 0.85, emission := Color.BLACK) -> Node3D:
	var n := put(d, path, at, yaw, scale)
	Props.tint(n, color, strength, emission)
	return n


# --- procedural props -----------------------------------------------------------------------

## Flat-shaded copy of a primitive mesh with optional vertex jitter (low-poly KayKit look).
## Vertex colour = `color`, blended to `bottom` below y = 0 of the source mesh.
static func faceted(src: Mesh, color: Color, jitter := 0.0, seed := 1, bottom := Color(0, 0, 0, 0),
		squash := Vector3.ONE) -> ArrayMesh:
	var arr := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# jitter per unique position so shared corners stay welded
	var moved := {}
	var out := PackedVector3Array()
	for v in verts:
		var key := Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
		if not moved.has(key):
			moved[key] = v * squash + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1) * 0.6, rng.randf_range(-1, 1)) * jitter
		out.append(moved[key])
	var ys := []
	for v in out:
		ys.append(v.y)
	var lo: float = ys.min() if not ys.is_empty() else 0.0
	var hi: float = ys.max() if not ys.is_empty() else 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri_count := idx.size() / 3 if idx.size() > 0 else out.size() / 3
	for t in tri_count:
		var ia := idx[t * 3] if idx.size() > 0 else t * 3
		var ib := idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
		var ic := idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
		var a := out[ia]
		var b := out[ib]
		var c := out[ic]
		var nrm := (c - a).cross(b - a).normalized()
		var shade := 1.0 + rng.randf_range(-0.05, 0.05)
		for v in [a, b, c]:
			var col := color
			if bottom.a > 0.0:
				col = bottom.lerp(color, smoothstep(lo, lo + (hi - lo) * 0.7, (v as Vector3).y))
			st.set_color(Color(col.r * shade, col.g * shade, col.b * shade, col.a))
			st.set_normal(-nrm)
			st.add_vertex(v)
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	mesh.surface_set_material(0, m)
	return mesh


static func _sphere(radius: float, segs := 7, rings := 4) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segs
	sm.rings = rings
	return sm


## A chunky low-poly round tree (trunk + three canopy lumps).
static func round_tree(parent: Node3D, pos: Vector3, k: float, leaf: Color, seed := 1) -> Node3D:
	var n := Node3D.new()
	n.name = "RoundTree"
	n.position = pos
	n.rotation.y = float(seed) * 1.7
	parent.add_child(n)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.26
	cm.height = 1.5
	cm.radial_segments = 6
	cm.rings = 1
	trunk.mesh = faceted(cm, Color(0.42, 0.28, 0.18), 0.02, seed)
	trunk.position.y = 0.75
	n.add_child(trunk)
	var lumps := [[Vector3(0, 1.95, 0), 0.95], [Vector3(0.55, 1.6, 0.25), 0.62], [Vector3(-0.5, 1.7, -0.2), 0.66],
		[Vector3(0.1, 2.55, -0.1), 0.6]]
	for li in lumps.size():
		var l: Array = lumps[li]
		var mi := MeshInstance3D.new()
		mi.mesh = faceted(_sphere(float(l[1]), 8, 5), leaf.lightened(0.08 * (li % 2)), 0.08, seed * 13 + li,
			leaf.darkened(0.35))
		mi.position = l[0]
		n.add_child(mi)
	n.scale = Vector3.ONE * k
	return n


## Pale pink blossom puffs scattered over a round tree's canopy.
static func blossoms(tree: Node3D, count: int, seed := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.8, 0.86)
	m.roughness = 0.8
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = _sphere(0.12, 5, 3)
		mi.material_override = m
		var a := rng.randf() * TAU
		var h := rng.randf_range(1.5, 2.9)
		var r := rng.randf_range(0.55, 1.0) * (1.2 - absf(h - 2.0) * 0.4)
		mi.position = Vector3(cos(a) * r, h, sin(a) * r)
		tree.add_child(mi)


## A low mound of leaves.
static func bush(parent: Node3D, pos: Vector3, k: float, leaf: Color, seed := 3) -> Node3D:
	var n := Node3D.new()
	n.name = "Bush"
	n.position = pos
	parent.add_child(n)
	for li in 3:
		var mi := MeshInstance3D.new()
		var r: float = [0.55, 0.42, 0.38][li]
		mi.mesh = faceted(_sphere(r, 7, 4), leaf.lightened(0.06 * li), 0.06, seed * 7 + li, leaf.darkened(0.35),
			Vector3(1.0, 0.8, 1.0))
		mi.position = [Vector3(0, 0.35, 0), Vector3(0.45, 0.25, 0.15), Vector3(-0.4, 0.24, 0.1)][li]
		n.add_child(mi)
	n.scale = Vector3.ONE * k
	return n


## A faceted boulder.
static func rock(parent: Node3D, pos: Vector3, k: float, color: Color, seed := 5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Rock"
	mi.mesh = faceted(_sphere(1.0, 6, 3), color, 0.18, seed, color.darkened(0.35), Vector3(1.0, 0.62, 0.9))
	mi.position = pos + Vector3.UP * 0.3 * k
	mi.rotation.y = float(seed) * 0.9
	mi.scale = Vector3.ONE * k
	parent.add_child(mi)
	return mi


static var _crystal_mesh: ArrayMesh
static var _crystal_mat: StandardMaterial3D


## Hexagonal crystal (prism + point), unit height, tip up.
static func crystal_mesh() -> ArrayMesh:
	if _crystal_mesh:
		return _crystal_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 0.16
	var h := 0.72
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0
		ring0.append(Vector3(cos(a) * r * 0.85, 0.0, sin(a) * r * 0.85))
		ring1.append(Vector3(cos(a) * r, h, sin(a) * r))
	var tip := Vector3(0, 1.0, 0)
	var tris: Array = []
	for i in 6:
		var j := (i + 1) % 6
		tris.append([ring0[i], ring1[i], ring1[j]])
		tris.append([ring0[i], ring1[j], ring0[j]])
		tris.append([ring1[i], tip, ring1[j]])
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var nrm := (b - a).cross(c - a).normalized()
		if nrm.dot((a + b + c) / 3.0 - Vector3(0, 0.5, 0)) < 0.0:
			nrm = -nrm
			var tmp := b
			b = c
			c = tmp
		for v in [a, c, b]:
			st.set_normal(nrm)
			st.set_color(Color(1, 1, 1).lerp(Color(0.75, 0.9, 1.0), 1.0 - (v as Vector3).y))
			st.add_vertex(v)
	_crystal_mesh = st.commit()
	return _crystal_mesh


static func crystal_material() -> StandardMaterial3D:
	if _crystal_mat:
		return _crystal_mat
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.88, 1.0)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.12
	m.metallic = 0.15
	m.emission_enabled = true
	m.emission = Color(0.3, 0.7, 1.0)
	m.emission_energy_multiplier = 0.85
	m.rim_enabled = true
	m.rim = 0.8
	m.rim_tint = 0.2
	_crystal_mat = m
	return m


## A cluster of `count` crystals around a point; k = overall size.
static func crystal_cluster(parent: Node3D, pos: Vector3, k: float, count := 5, seed := 11,
		light := true, mat: Material = null) -> Node3D:
	var n := Node3D.new()
	n.name = "Crystals"
	n.position = pos
	parent.add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = crystal_mesh()
		mi.material_override = mat if mat else crystal_material()
		var main := i == 0
		var hgt := (1.6 if main else rng.randf_range(0.6, 1.1)) * k
		var wid := (1.3 if main else rng.randf_range(0.7, 1.0)) * k
		mi.scale = Vector3(wid, hgt, wid)
		var a := TAU * float(i) / float(maxi(count - 1, 1)) + rng.randf() * 0.6
		var off := Vector3.ZERO if main else Vector3(cos(a), 0, sin(a)) * 0.22 * k
		mi.position = off
		mi.rotation = Vector3(0.0 if main else rng.randf_range(0.2, 0.5) * signf(cos(a)),
			rng.randf() * TAU, 0.0 if main else rng.randf_range(0.2, 0.5) * signf(sin(a)))
		n.add_child(mi)
	if light and mat == null:
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 0.85, 1.0)
		l.light_energy = 0.9
		l.omni_range = 2.6 * k + 1.0
		l.position = Vector3(0, 0.9 * k, 0.3)
		n.add_child(l)
	return n


## A bubbling lava disc (flat, glowing, with the lava shader).
static func lava_pool(parent: Node3D, pos: Vector3, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 0.9
	cm.height = 0.08
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = lava_material(1.1, 0.7, 0.58)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func lava_material(scale := 0.35, energy := 3.0, crust := 0.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/world/shaders/lava.gdshader")
	m.set_shader_parameter("scale", scale)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("crust", crust)
	return m


static var _tuft_mesh: ArrayMesh
static var _bloom_mesh: ArrayMesh
static var _stem_mesh: ArrayMesh


## Three crossed grass blades (vertex colour dark base -> light tip).
static func tuft_mesh() -> ArrayMesh:
	if _tuft_mesh:
		return _tuft_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var base := dir * 0.05
		var h := 0.26 + 0.08 * float(i % 3)
		var tip := dir * 0.16 + Vector3.UP * h
		for v in [base - side * 0.035, tip, base + side * 0.035]:
			st.set_color(Color(0.55, 0.55, 0.55) if (v as Vector3).y < 0.01 else Color(1, 1, 1))
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	_tuft_mesh = st.commit()
	return _tuft_mesh


static func _grass_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	return m


## Scatters grass tufts (MultiMesh) over the flat border and the moat, avoiding ring tiles
## and the set piece. `density` = tufts per square unit.
static func scatter_tufts(d: Node3D, color: Color, count: int, ring_gap := true) -> void:
	var xs := _scatter_points(count, 2.9 * minf(1.0 + (_s - 1.0) * 1.4, 1.45), ring_gap)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tuft_mesh()
	mm.instance_count = xs.size()
	for k in xs.size():
		var p: Vector3 = xs[k]
		var s := _rng.randf_range(0.7, 1.35)
		mm.set_instance_transform(k, Transform3D(Basis().rotated(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s)), p))
		mm.set_instance_color(k, color.lightened(_rng.randf_range(-0.12, 0.15)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tufts"
	mmi.multimesh = mm
	mmi.material_override = _grass_material(Color.WHITE)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.get_node("Floor").add_child(mmi)


## Scatters flowers (stem + bloom MultiMeshes) like scatter_tufts().
static func scatter_flowers(d: Node3D, colors: Array, count: int) -> void:
	var xs := _scatter_points(count, 3.0 * minf(1.0 + (_s - 1.0) * 1.4, 1.45), true)
	_flower_multimesh(d.get_node("Floor"), xs, colors)


## A small patch of flowers around a local point (props, corners).
static func flower_patch(parent: Node3D, pos: Vector3, radius: float, count: int) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var xs: Array = []
	for i in count:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * radius
		xs.append(Vector3(cos(a) * r, 0, sin(a) * r))
	_flower_multimesh(n, xs, [Color(1.0, 0.95, 0.9), Color(1.0, 0.55, 0.7), Color(1.0, 0.85, 0.3), Color(0.7, 0.6, 1.0)])
	return n


static func _flower_multimesh(parent: Node3D, xs: Array, colors: Array) -> void:
	if _bloom_mesh == null:
		_bloom_mesh = faceted(_sphere(0.075, 6, 3), Color.WHITE, 0.0, 1, Color(0, 0, 0, 0), Vector3(1.0, 0.55, 1.0))
		var cm := CylinderMesh.new()
		cm.top_radius = 0.012
		cm.bottom_radius = 0.018
		cm.height = 0.24
		cm.radial_segments = 4
		cm.rings = 1
		_stem_mesh = faceted(cm, Color(0.3, 0.55, 0.22))
	var stems := MultiMesh.new()
	stems.transform_format = MultiMesh.TRANSFORM_3D
	stems.mesh = _stem_mesh
	stems.instance_count = xs.size()
	var blooms := MultiMesh.new()
	blooms.transform_format = MultiMesh.TRANSFORM_3D
	blooms.use_colors = true
	blooms.mesh = _bloom_mesh
	blooms.instance_count = xs.size()
	for k in xs.size():
		var p: Vector3 = xs[k]
		var s := _rng.randf_range(0.8, 1.3)
		stems.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * s), p + Vector3.UP * 0.12 * s))
		blooms.set_instance_transform(k, Transform3D(Basis().rotated(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s),
			p + Vector3.UP * 0.25 * s))
		blooms.set_instance_color(k, colors[_rng.randi_range(0, colors.size() - 1)])
	for mm in [stems, blooms]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mm == blooms:
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.roughness = 0.6
			m.emission_enabled = true
			m.emission_energy_multiplier = 0.12
			m.emission = Color(1, 1, 1)
			mmi.material_override = m
		parent.add_child(mmi)


## Random flat-ground points: the border and the moat, off the ring tiles and the centre.
static func _scatter_points(count: int, centre_r: float, ring_gap: bool) -> Array:
	var out: Array = []
	var half := Biome.ISLAND_HALF * _s - 0.6
	var tries := 0
	while out.size() < count and tries < count * 12:
		tries += 1
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(-half, half)
		var ax := absf(x)
		var az := absf(z)
		var r := pow(pow(ax / half, 8.0) + pow(az / half, 8.0), 1.0 / 8.0)
		if r > 0.97:
			continue
		if maxf(ax, az) < centre_r:
			continue
		# ring band (tiles) stays clean
		var m := maxf(ax, az)
		if ring_gap and m > _extent - CELL - 0.1 and m < _extent + 0.35:
			continue
		# only the flat paving (raised blocks get their own dressing)
		if ground(x, z) > 0.01:
			continue
		out.append(Vector3(x, 0.0, z))
	return out


## Wooden log bench (for the glade campfire).
static func log_seat(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw)
	parent.add_child(n)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.17
	cm.bottom_radius = 0.17
	cm.height = 1.1
	cm.radial_segments = 7
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = faceted(cm, Color(0.5, 0.33, 0.2), 0.015, 9)
	mi.rotation.z = PI * 0.5
	mi.position.y = 0.17
	n.add_child(mi)
	return n


## A cute snowman (three faceted snowballs, coal eyes, carrot nose).
static func snowman(parent: Node3D, pos: Vector3, yaw: float, k := 1.0) -> Node3D:
	var n := Node3D.new()
	n.name = "Snowman"
	n.position = pos
	n.rotation.y = deg_to_rad(yaw)
	n.scale = Vector3.ONE * k
	parent.add_child(n)
	var snow := Color(0.95, 0.97, 1.0)
	var y := 0.0
	for i in 3:
		var r: float = [0.42, 0.32, 0.23][i]
		var mi := MeshInstance3D.new()
		mi.mesh = faceted(_sphere(r, 8, 5), snow, 0.02, 40 + i, Color(0.72, 0.8, 0.95))
		y += r * (0.9 if i > 0 else 1.0)
		mi.position.y = y
		y += r * 0.8
		n.add_child(mi)
	var head_y := 0.42 + 0.32 * 1.7 + 0.23 * 0.9 + 0.12
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = _sphere(0.035, 5, 3)
		eye.material_override = Props.flat_material(Color(0.08, 0.07, 0.1), 0.5)
		eye.position = Vector3(sx * 0.08, head_y + 0.28, 0.19)
		n.add_child(eye)
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.045
	cone.height = 0.2
	cone.radial_segments = 5
	nose.mesh = cone
	nose.material_override = Props.flat_material(Color(1.0, 0.5, 0.15), 0.6)
	nose.rotation.x = PI * 0.5
	nose.position = Vector3(0, head_y + 0.2, 0.3)
	n.add_child(nose)
	return n


## Rising smoke column (soft grey puffs).
static func smoke(parent: Node3D, pos: Vector3, k := 1.0, color := Color(0.25, 0.2, 0.2, 0.5)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 14
	p.lifetime = 4.0
	p.position = pos
	p.preprocess = 4.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.5 * k
	pm.initial_velocity_max = 0.9 * k
	pm.gravity = Vector3(0.12, 0.1, 0)
	pm.damping_min = 0.1
	pm.damping_max = 0.2
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.3))
	c.add_point(Vector2(1.0, 1.0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(color, 0.0), color, Color(color, color.a * 0.5), Color(color, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2) * k
	q.material = Props.particle_material("dot", false)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 12, 8))
	parent.add_child(p)
	return p


## Butterflies fluttering low over the meadow (flapping wings via a non-uniform scale curve).
static func butterflies(parent: Node3D) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Butterflies"
	p.amount = 14
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector3(0, 1.3, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(11.0 * _s, 0.8, 11.0 * _s)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.2
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_noise_speed = Vector3(0.1, 0.3, 0.1)
	var xyz := CurveXYZTexture.new()
	var cx := Curve.new()
	var cy := Curve.new()
	var flaps := 60
	for i in flaps + 1:
		var t := float(i) / float(flaps)
		var edge := minf(1.0, minf(t, 1.0 - t) * 12.0)
		cx.add_point(Vector2(t, (1.0 if i % 2 == 0 else 0.25) * edge))
		cy.add_point(Vector2(t, edge))
	cx.bake_resolution = 512
	xyz.curve_x = cx
	xyz.curve_y = cy
	xyz.curve_z = cy
	pm.scale_curve = xyz
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.85, 0.3), Color(1.0, 0.6, 0.8), Color(0.65, 0.8, 1.0), Color(1.0, 1.0, 0.95)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_initial_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	var m := Props.particle_material("butterfly", false)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-16, -3, -16), Vector3(32, 8, 32))
	parent.add_child(p)
	return p


## Low drifting mist (frost breath-fog).
static func mist(parent: Node3D, color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Mist"
	p.amount = 26
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.position = Vector3(0, 0.5, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(12.0 * _s, 0.3, 12.0 * _s)
	pm.gravity = Vector3(0.05, 0.0, 0.02)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.15
	pm.spread = 180.0
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(4.0, 4.0)
	q.material = Props.particle_material("dot", false)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-16, -3, -16), Vector3(32, 6, 32))
	parent.add_child(p)
	return p


# --- Verdant Glade ------------------------------------------------------------------------------

static func _glade(root: Node3D, d: Node3D, c: Node3D) -> void:
	# trees, bushes, rocks and side vignettes: seeded kits (see DressGlade)
	DressGlade.dress(root, d, c)
	scatter_tufts(d, Color(0.3, 0.52, 0.2), int(170 * _s * _s))
	scatter_flowers(d, [Color(1.0, 0.97, 0.92), Color(1.0, 0.6, 0.72), Color(1.0, 0.85, 0.32), Color(0.72, 0.62, 1.0)],
		int(150 * _s * _s))
	for p in [Vector3(-3.4, 0, 3.4), Vector3(3.6, 0, -3.2), Vector3(3.2, 0, 3.6), Vector3(-3.6, 0, -3.0),
			Vector3(-6.0, 0, 9.2), Vector3(6.4, 0, 9.4)]:
		_tag(flower_patch(d, spot(p), 0.9, 14))
	_tag(butterflies(d))
	match Dressing.kit(0):
		1:
			DressGlade.clearing(c)
			return
		2:
			DressGlade.spring(c)
			return
	# set piece: the old oak on a mossy mound, a ring of standing stones and a campfire
	var mound := Node3D.new()
	mound.name = "Mound"
	c.add_child(mound)
	for p in [Vector3(-0.55, 0, -0.55), Vector3(0.55, 0, -0.55), Vector3(-0.55, 0, 0.55), Vector3(0.55, 0, 0.55)]:
		block(mound, "grass", p + Vector3(0, -0.28, 0), 1.1, 90.0 * (int(p.x > 0) + 2 * int(p.z > 0)))
	block(mound, "dirt_with_grass", Vector3(0.0, 0.05, -0.2), 1.0, 0.0)
	var oak := round_tree(c, Vector3(0.0, 0.55, -0.25), 1.45, Color(0.44, 0.72, 0.3), 77)
	oak.name = "Oak"
	blossoms(oak, 26, 78)
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.25
		var p := Vector3(cos(a) * 2.15, 0, sin(a) * 2.15)
		if p.z > 1.3 and absf(p.x) < 0.9:
			continue
		var st := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.36, 0.95 + 0.25 * float(i % 3), 0.28)
		st.mesh = faceted(bx, Color(0.62, 0.64, 0.6), 0.04, 100 + i, Color(0.4, 0.46, 0.36))
		st.position = p + Vector3.UP * bx.size.y * 0.5
		st.rotation.y = -a + PI * 0.5
		st.rotation.z = deg_to_rad(_rng.randf_range(-6.0, 6.0))
		c.add_child(st)
	var fire := TileStyle.make_prop("campfire")
	fire.position = Vector3(0.0, 0.0, 1.55)
	fire.scale = Vector3.ONE * 1.25
	c.add_child(fire)
	log_seat(c, Vector3(-1.05, 0, 1.45), 70.0)
	log_seat(c, Vector3(1.05, 0, 1.45), -70.0)
	var fl := flower_patch(c, Vector3(0.0, 0.0, -0.1), 1.9, 16)
	fl.name = "Flowers"
	var halo := Biome._rune_circle(Color(1.0, 0.85, 0.45), 2.6)
	halo.position = Vector3(0, 0.03, 0)
	(halo.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.5)
	c.add_child(halo)


# --- Frostpeak ----------------------------------------------------------------------------------

static func _frost(root: Node3D, d: Node3D, c: Node3D) -> void:
	# crystals on the back peaks (the Frostpeak signature)
	for p in [Vector3(-8.2, 0, -8.8), Vector3(-4.6, 0, -9.0), Vector3(2.2, 0, -8.9), Vector3(5.8, 0, -8.7), Vector3(8.8, 0, -8.6)]:
		var cp := spot(p)
		Dressing.occupy(cp.x, cp.z, 0.7)
		_tag(crystal_cluster(d, cp, _rng.randf_range(0.6, 0.95), 5, int(p.x * 7 + 3), p.x < 0.0 and p.x > -6.0))
	# pines, icy rocks and the side camps: seeded kits (see DressFrost)
	DressFrost.dress(d)
	scatter_tufts(d, Color(0.62, 0.72, 0.62), int(50 * _s * _s))
	# frozen ponds in the moat corners (thin icy slabs)
	var mat := ice_material()
	for sx in [-1.0, 1.0]:
		var slab := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(1.9, 0.05, 1.3)
		slab.mesh = bx
		slab.material_override = mat
		slab.position = Vector3(sx * 3.9 * _s, 0.03, 1.6 * _s)
		slab.rotation.y = sx * 0.4
		slab.set_meta("prescaled", true)
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.add_child(slab)
	_tag(mist(d, Color(0.85, 0.92, 1.0, 0.16)))
	match Dressing.kit(0):
		1:
			DressFrost.sword(c)
			return
		2:
			DressFrost.spire(c)
			return
	# set piece: a stepped stone altar under a snow cap, crowned by a glowing ice crystal
	var base_k := [1.95, 1.35, 0.8]
	var y := 0.0
	for i in base_k.size():
		var k: float = base_k[i]
		var h := k * 0.35
		var bmi := block(c, "stone" if i < 2 else "snow", Vector3(0, y + h * 0.5, 0), 1.0, 45.0 * i)
		bmi.scale = Vector3(k, h, k) * 0.5
		y += h
	crystal_cluster(c, Vector3(0, y, 0), 1.35, 7, 777)
	for p in [Vector3(-1.8, 0, -1.3), Vector3(1.7, 0, -1.5), Vector3(-1.6, 0, 1.6), Vector3(1.9, 0, 1.2)]:
		crystal_cluster(c, p, 0.48, 3, int(p.x * 11 + p.z * 3 + 5), false)
	var ring := Biome._rune_circle(Color(0.45, 0.85, 1.0), 2.7)
	ring.position = Vector3(0, 0.04, 0)
	c.add_child(ring)
	Biome.flicker_light(c, Vector3(0, 2.4, 1.2), Color(0.5, 0.85, 1.0), 2.2, 6.0)
	var motes := Fx.elite_sparkle(c, Vector3(0, 0.6, 0), 1.2, 3.0)
	(motes.process_material as ParticleProcessMaterial).color = Color(0.7, 0.95, 1.0)


static var _obsidian: StandardMaterial3D


## Black volcanic glass with an ember-orange sheen (Magma crystals).
static func obsidian_material() -> StandardMaterial3D:
	if _obsidian:
		return _obsidian
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.085, 0.11)
	m.roughness = 0.08
	m.metallic = 0.55
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.06)
	m.emission_energy_multiplier = 0.1
	m.rim_enabled = true
	m.rim = 0.7
	m.rim_tint = 0.6
	_obsidian = m
	return m


## Pale translucent ice (ponds, ice tiles).
static func ice_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.9, 1.0, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.1
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = Color(0.35, 0.65, 0.9)
	m.emission_energy_multiplier = 0.3
	m.rim_enabled = true
	m.rim = 0.6
	return m


# --- Magma Depths -------------------------------------------------------------------------------

static func _magma(root: Node3D, d: Node3D, c: Node3D) -> void:
	var T := Props.TOOLS
	var D := Props.DUN
	var basalt := Color(0.3, 0.28, 0.31)
	var smoke_col := Color(0.3, 0.28, 0.4, 0.5)
	# warm uplight from the lava below (the key stays neutral, the fill cool)
	var up := DirectionalLight3D.new()
	up.name = "LavaUplight"
	up.light_color = Color(1.0, 0.4, 0.14)
	up.light_energy = 0.4
	up.light_specular = 0.2
	up.rotation_degrees = Vector3(35.0, 20.0, 0.0)
	root.add_child(up)
	var side_x := (_extent + CELL * 1.5) / _s      # authored x of the raised side columns
	var back_z := -(_extent + CELL * 1.5) / _s     # authored z of the raised back row
	# back cliffs: lava falls pouring into the channel, smoke columns and obsidian spires
	for x in [-6.3, 0.0, 6.3]:
		var p := spot(Vector3(x, 0, back_z))
		var fall := Node3D.new()
		fall.name = "LavaFall"
		fall.set_meta("prescaled", true)
		fall.position = Vector3(p.x, p.y, p.z + CELL * 0.5 + 0.05)
		d.add_child(fall)
		var sheet := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, p.y - CHANNEL_Y)
		sheet.mesh = q
		sheet.material_override = fall_material()
		sheet.position = Vector3(0, (p.y + CHANNEL_Y) * 0.5 - p.y, 0)
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fall.add_child(sheet)
		lava_pool(fall, Vector3(0, CHANNEL_Y - p.y + 0.03, 0.5), 0.8)
		Biome.flame(fall, Vector3(0, CHANNEL_Y - p.y + 0.2, 0.6), Color(1.0, 0.5, 0.12), 0.35, 8)
		Biome.flicker_light(fall, Vector3(0, CHANNEL_Y - p.y + 1.0, 1.0), Color(1.0, 0.42, 0.12), 1.6, 5.0)
		_tag(smoke(d, p + Vector3(0, 0.2, -0.6), 1.3, smoke_col))
	for x in [-9.4, -3.2, 3.2, 9.4]:
		_tag(basalt_columns(d, spot(Vector3(x, 0, back_z)), _rng.randf_range(1.5, 1.8), 7, int(x * 5 + 40)))
	# side columns: the forge yard up on the basalt shelves
	for side in [-1.0, 1.0]:
		_tag(basalt_columns(d, spot(Vector3(side * side_x, 0, -5.8)), 1.5, 7, int(side * 7 + 3)))
		_tag(spire(d, spot(Vector3(side * side_x + side * 0.6, 0, -4.4)), 0.7, int(side * 7 + 5)))
		_tag(rock(d, spot(Vector3(side * side_x, 0, 6.6)), 0.55, basalt, int(side * 7 + 33)))
		# forge yard / mine camp / battlefield on the shelf (seeded kits, see DressMagma)
		DressMagma.side(d, side, side_x * _s)
	# front: low basalt boulders and a few thin glowing cracks (the camera side stays open)
	for p in [Vector3(-5.6, 0, 9.9), Vector3(5.4, 0, 9.8)]:
		_tag(basalt_columns(d, spot(p), 1.1, 10, int(p.x * 7 + 99), 0.6))
	for p in [Vector3(-2.2, 0, 9.6), Vector3(2.6, 0, 9.8)]:
		_tag(crack_decal(d, spot(p) + Vector3(0, 0.02, 0), 1.5, _rng.randf() * 180.0))
	_tag(smoke(d, spot(Vector3(-side_x, 0, -8.0)) + Vector3(0, 0.5, 0), 0.9, smoke_col))
	_tag(smoke(d, spot(Vector3(side_x, 0, -7.0)) + Vector3(0, 0.5, 0), 0.9, smoke_col))
	for p in [Vector3(-5.6, 0, 9.9), Vector3(5.4, 0, 9.8)]:
		var q := spot(p)
		Dressing.occupy(q.x, q.z, 1.2)
	DressMagma.front(d)
	match Dressing.kit(0):
		1:
			DressMagma.hoard(c)
			return
		2:
			DressMagma.war_drum(c)
			return
	# set piece: the Cinder Forge. A stepped basalt dais over a ring of lava, a great anvil on
	# top with a glowing greatsword driven into it, flanked by two obsidian spires.
	var moat := lava_pool(c, Vector3(0, 0.01, -0.1), 2.05)
	moat.name = "ForgeMoat"
	var tiers := [[3.0, 0.4, 0.0], [2.2, 0.4, 20.0], [1.5, 0.35, 45.0]]
	var y := 0.0
	for i in tiers.size():
		var t: Array = tiers[i]
		var mi := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = float(t[0]) * 0.5
		cy.bottom_radius = float(t[0]) * 0.54
		cy.height = float(t[1])
		cy.radial_segments = 8
		cy.rings = 1
		mi.mesh = cy
		mi.material_override = basalt_material()
		mi.position = Vector3(0, y + float(t[1]) * 0.5, -0.1)
		mi.rotation.y = deg_to_rad(float(t[2]) + 22.5)
		c.add_child(mi)
		y += float(t[1])
	var anvil := Props.put(c, T + "anvil.gltf", Vector3(0.0, y, -0.1), 90.0, 1.7)
	anvil.name = "ForgeAnvil"
	Props.tint(anvil, Color(0.26, 0.25, 0.3), 0.85)
	var blade := Props.put(c, Props.WPN + "sword_A.gltf", Vector3(0.0, y + 0.55, -0.1), 0.0, 2.3)
	blade.name = "Greatsword"
	Props.tint(blade, Color(1.0, 0.45, 0.12), 0.9, Color(0.9, 0.25, 0.02) * 0.9)
	blade.rotation = Vector3(deg_to_rad(180.0), deg_to_rad(20.0), 0.0)
	blade.position.y = y + 2.3
	Biome.flame(c, Vector3(0, y + 0.55, -0.1), Color(1.0, 0.55, 0.15), 0.45, 12)
	var sm := smoke(c, Vector3(0, y + 2.2, -0.1), 1.1, smoke_col)
	sm.name = "ForgeSmoke"
	Biome.flicker_light(c, Vector3(0, y + 1.5, 0.9), Color(1.0, 0.5, 0.18), 2.4, 6.5)
	for sx in [-1.0, 1.0]:
		spire(c, Vector3(sx * 1.85, 0, -0.9), 1.25, int(sx * 3 + 90))
		var bz := Props.put(c, D + "torch_lit.gltf", Vector3(sx * 1.7, 0, 1.25), 0.0, 0.95)
		bz.name = "Brazier"
		Biome.flame(c, Vector3(sx * 1.7, 0.75, 1.25), Color(1.0, 0.5, 0.15), 0.3, 7)
	var ring := Biome._rune_circle(Color(1.0, 0.42, 0.12), 2.85)
	ring.position = Vector3(0, 0.04, 0)
	(ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.6)
	c.add_child(ring)


## A cluster of hexagonal basalt columns (the Magma signature prop): stepped prisms of the
## calm basalt, lighter ash on their tops, one glowing seam at the foot. k = overall size.
static func basalt_columns(parent: Node3D, pos: Vector3, k: float, count := 6, seed := 1, tall := 1.0) -> Node3D:
	var n := Node3D.new()
	n.name = "BasaltColumns"
	n.position = pos
	parent.add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var r := 0.3 * k
	# hex packing around the centre: the centre column is the tallest
	var spots: Array[Vector2] = [Vector2.ZERO]
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		spots.append(Vector2(cos(a), sin(a)) * r * 1.75)
	for i in 6:
		var a := TAU * i / 6.0
		spots.append(Vector2(cos(a), sin(a)) * r * 3.1)
	for i in mini(count, spots.size()):
		var h := (1.0 if i == 0 else rng.randf_range(0.35, 0.8) * (0.7 if i > 6 else 1.0)) * 1.6 * k * tall
		var mi := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = r * 0.97
		cy.bottom_radius = r
		cy.height = h
		cy.radial_segments = 6
		cy.rings = 1
		mi.mesh = cy
		mi.material_override = column_material()
		mi.position = Vector3(spots[i].x, h * 0.5 - 0.05, spots[i].y)
		mi.rotation.y = rng.randf_range(-0.12, 0.12)
		n.add_child(mi)
	return n


## A tall obsidian spire (a few black glass crystals with an ember sheen).
static func spire(parent: Node3D, pos: Vector3, k: float, seed := 1) -> Node3D:
	var n := crystal_cluster(parent, pos, k, 4, seed, false, obsidian_material())
	n.name = "Obsidian"
	return n


static var _fall_mat: ShaderMaterial


## A lava fall sheet (the crust-plate lava, streaming down).
static func fall_material() -> ShaderMaterial:
	if _fall_mat == null:
		_fall_mat = ShaderMaterial.new()
		_fall_mat.shader = preload("res://game/world/shaders/lava_fall.gdshader")
	return _fall_mat


## Thin glowing cracks on the ground (an additive decal quad).
static func crack_decal(parent: Node3D, pos: Vector3, size: float, yaw: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Crack"
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var m := Props.glow_material(Color(1.0, 0.45, 0.12), true, 2.0)
	m.albedo_texture = TileStyle.crack_texture()
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

