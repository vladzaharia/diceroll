class_name TileStyle
extends RefCounted
## Tile colours and the small 3D prop that identifies each tile type.

const TYPES := ["start", "forge", "treasury", "portal", "enemy", "elite", "miniboss", "chest", "event", "campfire",
	"trap", "ice", "lava", "minigame", "empty"]

## Inset top colour per type (sRGB).
const COLORS := {
	"start": Color(0.98, 0.84, 0.46),
	"forge": Color(0.95, 0.5, 0.22),
	"treasury": Color(1.0, 0.76, 0.18),
	"portal": Color(0.62, 0.4, 0.98),
	"enemy": Color(0.9, 0.26, 0.24),
	"elite": Color(0.66, 0.1, 0.22),
	"miniboss": Color(0.58, 0.1, 0.4),
	"chest": Color(0.28, 0.6, 0.98),
	"event": Color(0.24, 0.8, 0.78),
	"campfire": Color(0.46, 0.82, 0.3),
	"trap": Color(0.5, 0.44, 0.52),
	"ice": Color(0.66, 0.88, 1.0),
	"lava": Color(1.0, 0.4, 0.12),
	"minigame": Color(0.98, 0.42, 0.74),
	"empty": Color(0.7, 0.66, 0.6),
}

## Plinth (base) colour per biome (BlockBits biomes take theirs from BiomeBlocks.LOOKS).
const BASE := {"crypt": Color(0.46, 0.42, 0.42), "hollow": Color(0.42, 0.34, 0.3), "throne": Color(0.34, 0.33, 0.42)}


static func base_color(biome: Variant) -> Color:
	var id := Biome.id_of(biome)
	if BASE.has(id):
		return BASE[id]
	return Biome.look(id).get("tile_base", BASE["crypt"])


static func color(type: String) -> Color:
	return COLORS.get(type, COLORS["empty"])


static func glyph(type: String) -> String:
	match type:
		"event":
			return "?"
	return ""


## Builds the identifying prop for a tile type. Props sit around y = 0 (the tile top) and
## fit inside ~1.4 x 1.4. Enemy figures are not included (BoardView adds Characters).
static func make_prop(type: String, game := "") -> Node3D:
	var root := Node3D.new()
	root.name = "Prop_" + type
	match type:
		"start":
			var f := Props.put(root, Props.BGB + "flag_A_yellow.gltf", Vector3(-0.42, 0, -0.42), 30.0, 0.85)
			f.name = "Flag"
			var f2 := Props.put(root, Props.BGB + "flag_B_red.gltf", Vector3(0.45, 0, -0.45), -20.0, 0.6)
			f2.name = "Flag2"
		"forge":
			Props.put(root, Props.TOOLS + "anvil.gltf", Vector3(0.0, 0, -0.35), 15.0, 0.62)
			Props.put(root, Props.TOOLS + "hammer.gltf", Vector3(0.45, 0.02, 0.2), 80.0, 0.5)
			var spark := Biome.flame(root, Vector3(0.0, 0.55, -0.35), Color(1.0, 0.6, 0.2), 0.14, 5)
			spark.name = "Sparks"
		"treasury":
			Props.put(root, Props.DUN + "coin_stack_large.gltf", Vector3(-0.1, 0, -0.3), 20.0, 0.55)
			Props.put(root, Props.DUN + "coin_stack_small.gltf", Vector3(0.5, 0, 0.2), -40.0, 0.5)
			Props.put(root, Props.DUN + "coin.gltf", Vector3(-0.5, 0, 0.35), 0.0, 0.8)
		"portal":
			var arch := Props.put(root, Props.HAL + "arch.gltf", Vector3(0, 0, -0.25), 0.0, 0.34)
			arch.name = "Arch"
			var swirl := Fx.portal_swirl(root, Vector3(0, 0.72, -0.25), 0.62, false)
			swirl.name = "Swirl"
		"chest":
			Props.put(root, Props.DUN + "chest.gltf", Vector3(0, 0, -0.2), -12.0, 0.5)
		"event":
			var stone := Props.put(root, Props.HAL + "shrine.gltf", Vector3(-0.4, 0, -0.4), 20.0, 0.36)
			stone.name = "Shrine"
			root.add_child(_question_mark())
		"campfire":
			root.add_child(_campfire())
		"trap":
			var spikes := Props.put(root, Props.DUN + "floor_tile_big_spikes.gltf", Vector3(0, -0.03, 0), 0.0, 0.34)
			spikes.scale = Vector3(0.36, 0.3, 0.36)
		"ice":
			root.add_child(_ice_slab())
		"lava":
			root.add_child(_lava_vent())
		"minigame":
			root.add_child(MinigameProps.make(game))
		"enemy":
			pass
		"elite":
			pass
	Props.set_shadows(root, true)
	return root


## Frostpeak trap: a slick, pale-blue ice slab with frost sparkle and a crystal at its back.
static func _ice_slab() -> Node3D:
	var n := Node3D.new()
	n.name = "Ice"
	var slab := MeshInstance3D.new()
	slab.name = "Slab"
	var bx := BoxMesh.new()
	bx.size = Vector3(1.28, 0.1, 1.28)
	slab.mesh = bx
	slab.material_override = BiomeBlocks.ice_material()
	slab.position.y = 0.03
	slab.rotation.y = deg_to_rad(8.0)
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(slab)
	# a few crack lines on top
	var crack := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(1.1, 1.1)
	crack.mesh = q
	var cm := Props.glow_material(Color(0.85, 0.97, 1.0), true, 0.7)
	cm.albedo_texture = crack_texture()
	crack.material_override = cm
	crack.position.y = 0.085
	crack.rotation.y = deg_to_rad(8.0)
	n.add_child(crack)
	var cr := BiomeBlocks.crystal_cluster(n, Vector3(-0.42, 0.05, -0.42), 0.42, 3, 21, false)
	cr.name = "Crystal"
	var sp := Fx.elite_sparkle(n, Vector3(0, 0.1, 0), 0.55, 0.5)
	sp.name = "Sparkle"
	(sp.process_material as ParticleProcessMaterial).color = Color(0.8, 0.95, 1.0)
	return n


## Magma lava tile: a cracked basalt rim around a glowing lava pool, embers and a pulsing glow.
static func _lava_vent() -> Node3D:
	var n := Node3D.new()
	n.name = "Lava"
	var pool := MeshInstance3D.new()
	pool.name = "Pool"
	var bx := BoxMesh.new()
	bx.size = Vector3(1.22, 0.06, 1.22)
	pool.mesh = bx
	pool.material_override = BiomeBlocks.lava_material(1.5, 1.25, 0.82)
	pool.position.y = 0.02
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(pool)
	# a few low crust stones at the corners (the pool itself stays open and bright)
	var basalt := Color(0.22, 0.18, 0.19)
	for i in 3:
		var c := [Vector3(-0.46, 0.0, -0.44), Vector3(0.5, 0.0, 0.42), Vector3(-0.5, 0.0, 0.46)][i] as Vector3
		var r := BiomeBlocks.rock(n, c, 0.12 + 0.04 * float(i % 2), basalt, 300 + i)
		r.name = "Crust%d" % i
		r.scale.y *= 0.6
	var ember := Biome.flame(n, Vector3(0, 0.12, 0), Color(1.0, 0.45, 0.1), 0.3, 8)
	ember.name = "Embers"
	var l := OmniLight3D.new()
	l.name = "Glow"
	l.light_color = Color(1.0, 0.42, 0.12)
	l.light_energy = 0.7
	l.omni_range = 2.0
	l.position = Vector3(0, 0.8, 0)
	n.add_child(l)
	var t := l.create_tween().set_loops()
	t.tween_property(l, "light_energy", 1.1, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(l, "light_energy", 0.5, 0.9).set_trans(Tween.TRANS_SINE)
	return n


static var _crack_tex: Texture2D
static var _skirt_tex: Texture2D


## A soft glowing seam on the ground around a tile plinth (Magma: the tiles sit on lava
## light, so they separate from the dark basalt).
static func glow_skirt(color: Color, width: float) -> MeshInstance3D:
	if _skirt_tex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var u := absf((float(x) + 0.5) / n * 2.0 - 1.0)
				var v := absf((float(y) + 0.5) / n * 2.0 - 1.0)
				var d := pow(pow(u, 6.0) + pow(v, 6.0), 1.0 / 6.0)
				var a := clampf(1.0 - absf(d - 0.8) / 0.2, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		img.generate_mipmaps()
		_skirt_tex = ImageTexture.create_from_image(img)
	var mi := MeshInstance3D.new()
	mi.name = "GlowSkirt"
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * width * 1.25
	mi.mesh = pm
	var m := Props.glow_material(color, true, 1.6)
	m.albedo_texture = _skirt_tex
	mi.material_override = m
	mi.position.y = 0.015
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Thin white crack lines on transparent (ice tile surface).
static func crack_texture() -> Texture2D:
	if _crack_tex:
		return _crack_tex
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 5:
		var p := Vector2(64, 64) + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
		var dir := Vector2.RIGHT.rotated(TAU * k / 5.0 + rng.randf_range(-0.3, 0.3))
		for step in 60:
			dir = dir.rotated(rng.randf_range(-0.35, 0.35))
			p += dir * 1.0
			if p.x < 1 or p.y < 1 or p.x > size - 2 or p.y > size - 2:
				break
			var a := 1.0 - float(step) / 60.0
			img.set_pixelv(Vector2i(p), Color(1, 1, 1, a))
			img.set_pixelv(Vector2i(p) + Vector2i(1, 0), Color(1, 1, 1, a * 0.5))
	img.generate_mipmaps()
	_crack_tex = ImageTexture.create_from_image(img)
	return _crack_tex


## A chunky gold "?" that bobs and turns (event tiles).
static func _question_mark() -> Node3D:
	var n := Node3D.new()
	n.name = "Glyph"
	var tm := TextMesh.new()
	tm.text = "?"
	tm.font = Props.font(true)
	tm.font_size = 64
	tm.pixel_size = 0.02
	tm.depth = 0.2
	tm.curve_step = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.82, 0.3)
	m.metallic = 0.5
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.15)
	m.emission_energy_multiplier = 0.5
	mi.material_override = m
	n.add_child(mi)
	n.position = Vector3(0.15, 0.95, 0.05)
	n.rotation.x = deg_to_rad(-30.0)
	var t := n.create_tween().set_loops()
	t.tween_property(n, "position:y", 1.1, 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:y", 0.95, 1.1).set_trans(Tween.TRANS_SINE)
	mi.rotation.y = deg_to_rad(-25.0)
	var r := mi.create_tween().set_loops()
	r.tween_property(mi, "rotation:y", deg_to_rad(25.0), 1.6).set_trans(Tween.TRANS_SINE)
	r.tween_property(mi, "rotation:y", deg_to_rad(-25.0), 1.6).set_trans(Tween.TRANS_SINE)
	return n


## Stones, crossed logs, flame particles and a warm light.
static func _campfire() -> Node3D:
	var n := Node3D.new()
	n.name = "Campfire"
	var stone_mat := Props.flat_material(Color(0.5, 0.48, 0.5))
	for i in 8:
		var a := TAU * i / 8.0
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.18
		sm.radial_segments = 6
		sm.rings = 3
		s.mesh = sm
		s.material_override = stone_mat
		s.position = Vector3(cos(a) * 0.42, 0.06, sin(a) * 0.42)
		s.rotation.y = a
		n.add_child(s)
	var log_mat := Props.flat_material(Color(0.45, 0.27, 0.16))
	for i in 3:
		var l := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.08
		cm.height = 0.7
		cm.radial_segments = 6
		l.mesh = cm
		l.material_override = log_mat
		l.rotation = Vector3(deg_to_rad(62.0), TAU * i / 3.0, 0.0)
		l.position = Vector3(0, 0.2, 0)
		n.add_child(l)
	var ember := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.2
	em.height = 0.16
	ember.mesh = em
	ember.material_override = Props.glow_material(Color(1.0, 0.45, 0.1), false, 2.0)
	ember.position = Vector3(0, 0.06, 0)
	n.add_child(ember)
	Biome.flame(n, Vector3(0, 0.25, 0), Color(1.0, 0.5, 0.15), 0.5, 14)
	Biome.flicker_light(n, Vector3(0, 0.8, 0), Color(1.0, 0.55, 0.2), 1.4, 3.2)
	return n
