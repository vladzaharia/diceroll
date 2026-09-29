class_name DressMoonlit
extends RefCounted
## Moonlit Woods kits (docs/design/2026-09-29-new-biomes.md §4.5). Frame (BiomeBlocks): a night
## meadow on wooded hills, a starry indigo sky, silver-blue moon key and violet fill, fireflies.
## Here: the moon (a big disc behind the island whose fill follows the phase, blood-red for the
## Moon King's phase 2), cool-coloured trees and bushes, low ground mist, then the seeded kits:
##  palettes (kit(1)): 0 teal wood, 1 violet grove, 2 silver birchwood (each with its side camp:
##                     a hunter's fire, a woodcutter's pile, a wolf den);
##  set pieces (kit(0)): 0 the throne of roots (a gnarled bare tree with a root seat in a ring of
##                       standing stones, a moon pool before it), 1 the woodcutter's clearing,
##                       2 the moonwell (a stone basin of silver light on a rune circle);
##  moat corners (kit(2)): 0 a glowing mushroom ring, 1 boulders and ferns, 2 a stump and axe.
##
## The phase: set_phase() / set_fill() / set_blood() drive every moon glyph (sky moon, moon pool,
## moonwell) and the key light (brighter toward the Full moon). BoardView forwards its
## set_moon_phase / set_moon_fill / set_blood_moon here.

const F := Dressing.FOREST
const WC := Props.K + "mystery/woodcutter/"
const RES := Dressing.RES
const H := Props.HAL
## Lit fraction of the sky moon per phase.
const FILL := {"crescent": 0.28, "half": 0.55, "full": 1.0}
const SILVER := Color(0.72, 0.82, 1.0)
const BLOOD := Color(1.0, 0.3, 0.22)
const STONE := Color(0.58, 0.62, 0.74)
## Bushes under the moon: deep blue-green, so they don't read as bright balls.
const BUSH_TINT := Color(0.24, 0.42, 0.5, 0.55)
## [broad trees, tall trees, colour index, tint (alpha = strength), bush colour index]
const PALETTES := [
	{"broad": ["Tree_1_A", "Tree_1_B", "Tree_3_A", "Tree_2_A"], "tall": ["Tree_4_A", "Tree_5_B", "Tree_5_D"],
		"col": 4, "tall_col": 2, "tint": Color(0.6, 0.78, 1.0, 0.25), "bush": 2},
	{"broad": ["Tree_1_A", "Tree_7_A", "Tree_3_B"], "tall": ["Tree_Bare_1_A", "Tree_5_A", "Tree_Bare_2_B"],
		"col": 4, "tall_col": 4, "tint": Color(0.62, 0.5, 1.0, 0.45), "bush": 4},
	{"broad": ["Tree_6_A", "Tree_6_B", "Tree_2_B"], "tall": ["Tree_5_E", "Tree_Bare_2_A", "Tree_4_B"],
		"col": 4, "tall_col": 2, "tint": Color(0.7, 0.82, 1.0, 0.4), "bush": 2},
]


static func dress(root: Node3D, d: Node3D, c: Node3D) -> void:
	var e := Dressing.extent
	var h := Dressing.half
	var s := Dressing.s
	var pal: Dictionary = PALETTES[Dressing.kit(1)]
	_sky_moon(root)
	# the tree line on the back hills and down the sides
	var n := 9
	for i in n:
		var t := float(i) / float(n - 1)
		var x := lerpf(-h + 1.2, h - 1.2, t) + Dressing.rng.randf_range(-0.5, 0.5)
		var z := -h + 1.3 + Dressing.rng.randf_range(-0.3, 0.6)
		_tree(pal, x, z, i % 3 != 1, 0.8 + Dressing.rng.randf_range(-0.08, 0.12))
	for i in 5:
		var x := lerpf(-h + 2.6, h - 2.6, float(i) / 4.0) + Dressing.rng.randf_range(-0.6, 0.6)
		_tree(pal, x, -e - 1.2 + Dressing.rng.randf_range(-0.2, 0.2), i % 2 == 0, 0.62)
	for side in [-1.0, 1.0]:
		for z in [-e + 0.6, -e * 0.45, -0.4]:
			_tree(pal, side * (h - 1.3 + Dressing.rng.randf_range(-0.3, 0.2)), z + Dressing.rng.randf_range(-0.6, 0.6),
				Dressing.chance(0.5), 0.64 + Dressing.rng.randf_range(0.0, 0.14))
		for z in [-e * 0.7, -e * 0.1, e * 0.35, e * 0.8]:
			_bush(pal, side * (e + 0.9 + Dressing.rng.randf_range(0.0, 1.2)), z + Dressing.rng.randf_range(-0.8, 0.8), 0.55)
		for z in [e * 0.55, e * 0.95]:
			var r: String = F + Dressing.pick(["Rock_1_B", "Rock_1_E", "Rock_1_H", "Rock_6_C"]) + "_Color1.gltf"
			Dressing.place_in(r, Rect2(side * (e + 2.4) - 1.0, z - 0.8, 2.0, 1.6), Dressing.rng.randf_range(0.5, 0.75),
				Color(0.6, 0.66, 0.85, 0.4))
	_camp(Dressing.kit(1))
	_front(pal)
	var gc := int(pal.bush)
	Dressing.scatter([F + "Grass_1_B_Color%d.gltf" % gc, F + "Grass_1_C_Color%d.gltf" % gc, F + "Grass_2_B_Color%d.gltf" % gc,
		F + "Grass_2_C_Color%d.gltf" % gc], int(60 * s * s), "border", Vector2(0.55, 0.9), Color(0.3, 0.52, 0.56, 0.55))
	Dressing.scatter([F + "Grass_1_A_Color%d.gltf" % gc, F + "Grass_1_B_Color%d.gltf" % gc], int(24 * s), "moat",
		Vector2(0.5, 0.75), Color(0.3, 0.52, 0.56, 0.55))
	Dressing.scatter([F + "Rock_5_A_Color1.gltf", F + "Rock_5_B_Color1.gltf", F + "Rock_2_A_Color1.gltf"],
		int(22 * s), "border", Vector2(0.6, 1.1), Color(0.36, 0.4, 0.52, 0.7))
	BiomeBlocks.scatter_flowers(d, [Color(0.7, 0.8, 1.0), Color(0.78, 0.62, 1.0), Color(0.55, 0.95, 0.9)], int(40 * s * s))
	var mist := BiomeBlocks.mist(d, Color(0.62, 0.72, 1.0, 0.07))
	mist.set_meta("prescaled", true)
	match Dressing.kit(0):
		0:
			root_throne(root, c)
		1:
			woodcutter(root, c)
		2:
			moonwell(root, c)
	set_phase(root, String(Biome.opt("moon_phase", "crescent")), false)


static func _tree(pal: Dictionary, x: float, z: float, broad: bool, k: float) -> Node3D:
	var name: String = Dressing.pick(pal.broad if broad else pal.tall)
	var col := int(pal.col if broad else pal.tall_col)
	var path := F + "%s_Color%d.gltf" % [name, 1 if name.begins_with("Tree_Bare") else col]
	var tint: Color = pal.tint
	if name.begins_with("Tree_Bare"):
		tint = Color(0.62, 0.66, 0.9, 0.5)
	return Dressing.place_near(path, x, z, k, 1.3, tint)


static func _bush(pal: Dictionary, x: float, z: float, k: float) -> Node3D:
	var b: String = F + Dressing.pick(["Bush_1_C", "Bush_1_D", "Bush_3_B", "Bush_4_B"]) + "_Color%d.gltf" % int(pal.bush)
	return Dressing.place_near(b, x, z, k, 1.0, BUSH_TINT)


# --- the moon ----------------------------------------------------------------------------------------

## The sky moon: a big billboard disc behind the island (with a soft halo) and a cool rim light.
static func _sky_moon(root: Node3D) -> void:
	var s := Dressing.s
	var m := TileStyle.moon_quad(6.0 * s, 0.3, true, 0.7)
	m.name = "SkyMoon"
	# low over the back tree line, so the steep board cameras catch it rising behind the woods
	m.position = Vector3(3.2 * s, 4.4, -13.6 * s)
	(m.material_override as ShaderMaterial).set_shader_parameter("energy", 1.3)
	m.set_meta("moon_glyph", true)
	root.add_child(m)
	_register(root, m)


## Remembers a moon glyph (a MeshInstance3D with the moon shader) so the phase drives it.
static func _register(root: Node3D, mi: MeshInstance3D) -> void:
	var list: Array = root.get_meta("moon_glyphs", [])
	list.append(mi)
	root.set_meta("moon_glyphs", list)


## The sky moon takes `phase`'s fill (see FILL) and the key light follows.
static func set_phase(root: Node3D, phase: String, animate := true) -> void:
	set_fill(root, float(FILL.get(phase, FILL.crescent)), animate)


## Fills every moon glyph to f (0..1) and brightens the moonlight with it.
static func set_fill(root: Node3D, f: float, animate := true) -> void:
	if not root.has_meta("moon_glyphs"):
		return
	f = clampf(f, 0.0, 1.0)
	var from := float(root.get_meta("moon_fill", f))
	root.set_meta("moon_fill", f)
	var apply := func(v: float) -> void:
		for mi in root.get_meta("moon_glyphs", []):
			if is_instance_valid(mi):
				((mi as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("fill", v)
		var key := root.get_node_or_null("KeyLight") as DirectionalLight3D
		if key:
			key.light_energy = 0.8 + 0.55 * v
	if animate and root.is_inside_tree():
		root.create_tween().tween_method(apply, from, f, 1.2).set_trans(Tween.TRANS_SINE)
	else:
		apply.call(f)


## The blood moon (the Moon King's phase 2): every moon glyph and the key light turn red.
static func set_blood(root: Node3D, on: bool, animate := true) -> void:
	if not root.has_meta("moon_glyphs"):
		return
	var to := 1.0 if on else 0.0
	var from := float(root.get_meta("moon_blood", 0.0))
	root.set_meta("moon_blood", to)
	var apply := func(v: float) -> void:
		for mi in root.get_meta("moon_glyphs", []):
			if is_instance_valid(mi):
				((mi as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("blood", v)
		var key := root.get_node_or_null("KeyLight") as DirectionalLight3D
		if key:
			key.light_color = SILVER.lerp(BLOOD, v * 0.8)
		var fill := root.get_node_or_null("FillLight") as DirectionalLight3D
		if fill:
			fill.light_color = Color(0.62, 0.42, 1.0).lerp(Color(0.9, 0.2, 0.3), v)
	if animate and root.is_inside_tree():
		root.create_tween().tween_method(apply, from, to, 1.0).set_trans(Tween.TRANS_SINE)
	else:
		apply.call(to)


# --- sides and front ----------------------------------------------------------------------------------

## The side camp of the palette: 0 hunter's fire, 1 woodcutter's pile, 2 wolf den.
static func _camp(kit: int) -> void:
	var e := Dressing.extent
	for side in [-1.0, 1.0]:
		var x: float = side * (e + 2.0)
		var z: float = e * Dressing.rng.randf_range(0.05, 0.4) * (1.0 if side < 0 else -0.6)
		if not Dressing.fits(x, z, 1.0, 1.2):
			continue
		var g := Dressing.group("Camp", x, z, 1.0)
		g.rotation.y = deg_to_rad(-90.0 * side)
		match kit:
			0:
				DressWarcamp.fire_ring(g)
				g.scale = Vector3.ONE * 0.8
				Biome.flicker_light(Dressing.d, g.position + Vector3(0, 1.0, 0), Color(1.0, 0.6, 0.25), 1.4, 4.5) \
					.set_meta("prescaled", true)
			1:
				Props.put(g, WC + "log_stacks.gltf", Vector3(0, 0, -0.2), 0.0, 0.6)
				Props.put(g, WC + "log_split.gltf", Vector3(0.7, 0.3, 0.35), 0.0, 0.5)
				Dressing.stuck(g, WC + "axe.gltf", Vector3(-0.55, 0.3, 0.4), 30.0, 15.0, 0.7)
			2:
				for i in 3:
					var r := Props.put(g, F + ["Rock_1_B", "Rock_1_H", "Rock_6_C"][i] + "_Color1.gltf",
						Vector3(-0.5 + 0.5 * i, 0, -0.2 + 0.2 * (i % 2)), 30.0 * i, 0.5)
					Props.tint(r, Color(0.6, 0.66, 0.85), 0.4)
				DressBits.bone_pile(g, 0.6, null, Color(0.9, 0.9, 1.0, 0.3))


## Front strip: low bushes, ferns and a few stones.
static func _front(pal: Dictionary) -> void:
	var e := Dressing.extent
	var h := Dressing.half
	for i in 6:
		var x := lerpf(-h + 1.6, h - 1.6, float(i) / 5.0) + Dressing.rng.randf_range(-0.6, 0.6)
		var z := Dressing.rng.randf_range(e + 1.0, h - 0.9)
		if i % 2 == 0:
			var b: String = F + Dressing.pick(["Bush_1_B", "Bush_1_C", "Bush_1_E"]) + "_Color%d.gltf" % int(pal.bush)
			Dressing.try_place(b, x, z, Dressing.rng.randf() * 360.0, Dressing.rng.randf_range(0.8, 1.1), BUSH_TINT)
		else:
			Dressing.try_place(F + Dressing.pick(["Rock_5_C", "Rock_5_E", "Rock_2_B"]) + "_Color1.gltf", x, z,
				Dressing.rng.randf() * 360.0, Dressing.rng.randf_range(0.45, 0.7), Color(0.6, 0.66, 0.85, 0.4))


# --- set pieces ----------------------------------------------------------------------------------------

## A tall standing stone with a faint silver rune.
static func standing_stone(c: Node3D, pos: Vector3, yaw: float, hgt: float, seed := 1) -> MeshInstance3D:
	var st := MeshInstance3D.new()
	st.name = "Stone"
	var bx := BoxMesh.new()
	bx.size = Vector3(0.42, hgt, 0.32)
	st.mesh = BiomeBlocks.solid(bx, STONE, 0.05, seed, STONE.darkened(0.35))
	st.position = pos + Vector3.UP * hgt * 0.5
	st.rotation.y = yaw
	st.rotation.z = deg_to_rad(Dressing.rng.randf_range(-5.0, 5.0))
	c.add_child(st)
	var rune := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.24, 0.24)
	rune.mesh = q
	var m := Props.glow_material(SILVER, true, 1.4)
	m.albedo_texture = Props.particle_texture("ring")
	rune.material_override = m
	rune.position = Vector3(0, hgt * 0.15, 0.17)
	st.add_child(rune)
	return st


## A flat moon glyph on the ground / water (driven by the phase like the sky moon).
static func _moon_pool(root: Node3D, c: Node3D, pos: Vector3, r: float) -> void:
	var rim := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 1.12
	cm.bottom_radius = r * 1.22
	cm.height = 0.1
	cm.radial_segments = 12
	rim.mesh = BiomeBlocks.solid(cm, STONE, 0.02, 5)
	rim.position = pos + Vector3.UP * 0.03
	c.add_child(rim)
	var water := MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = r
	wc.bottom_radius = r
	wc.height = 0.02
	wc.radial_segments = 16
	water.mesh = wc
	var wm := Props.flat_material(Color(0.05, 0.08, 0.2), 0.05)
	wm.metallic_specular = 1.0
	water.material_override = wm
	water.position = pos + Vector3.UP * 0.085
	c.add_child(water)
	var m := TileStyle.moon_quad(r * 2.2, 0.3, false, 0.45)
	m.name = "MoonPool"
	m.rotation.x = -PI * 0.5
	m.position = pos + Vector3.UP * 0.1
	var sm := m.material_override as ShaderMaterial
	sm.set_shader_parameter("energy", 1.1)
	sm.set_shader_parameter("dark_alpha", 0.25)
	c.add_child(m)
	_register(root, m)


## Set piece 0: the throne of roots. A huge gnarled bare tree whose roots form an empty seat
## (the Moon King's), a ring of standing stones and a moon pool before it.
static func root_throne(root: Node3D, c: Node3D) -> void:
	var tr := Props.put(c, F + "Tree_Bare_2_A_Color1.gltf", Vector3(0, 0, -0.75), 180.0, 1.5)
	tr.name = "ThroneTree"
	Props.tint(tr, Color(0.6, 0.6, 0.84), 0.5)
	var bark := Color(0.44, 0.38, 0.5)
	var seat := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.9, 0.42, 0.62)
	seat.mesh = BiomeBlocks.solid(sb, bark, 0.04, 31)
	seat.position = Vector3(0, 0.21, -0.35)
	c.add_child(seat)
	var back := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.0, 1.35, 0.22)
	back.mesh = BiomeBlocks.solid(bb, bark, 0.06, 32, bark.darkened(0.3))
	back.position = Vector3(0, 0.68, -0.72)
	c.add_child(back)
	for i in 6:
		var a := PI * (0.15 + 0.14 * i)
		var rt := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.11
		cm.height = 1.1
		cm.radial_segments = 5
		rt.mesh = BiomeBlocks.solid(cm, bark, 0.02, 40 + i)
		rt.position = Vector3(cos(a) * 0.62, 0.22, -0.55 - sin(a) * 0.35)
		rt.rotation = Vector3(0.0, -a + PI * 0.5, deg_to_rad(70.0))
		c.add_child(rt)
	var n := 7
	for i in n:
		var a := TAU * float(i) / float(n) + 0.22
		var p := Vector3(cos(a) * 2.2, 0, sin(a) * 2.05)
		if p.z > 1.4 and absf(p.x) < 1.0:
			continue
		standing_stone(c, p, -a + PI * 0.5, 1.3 + 0.35 * float(i % 3), 100 + i)
	_moon_pool(root, c, Vector3(0, 0, 0.95), 0.62)
	Biome.flicker_light(c, Vector3(0, 1.4, 1.6), SILVER, 1.4, 5.0)
	var motes := Fx.elite_sparkle(c, Vector3(0, 0.6, -0.4), 1.4, 2.2)
	(motes.process_material as ParticleProcessMaterial).color = SILVER


## Set piece 1: the woodcutter's clearing. A great stump with the axe in it, log stacks and split
## logs, a lantern on a post, a claw-scored tree.
static func woodcutter(root: Node3D, c: Node3D) -> void:
	var stump := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.95
	cm.height = 0.7
	cm.radial_segments = 10
	stump.mesh = BiomeBlocks.solid(cm, Color(0.42, 0.3, 0.24), 0.05, 50, Color(0.28, 0.2, 0.18))
	stump.position = Vector3(0, 0.35, -0.1)
	c.add_child(stump)
	var top := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.72
	tc.bottom_radius = 0.72
	tc.height = 0.02
	tc.radial_segments = 10
	top.mesh = BiomeBlocks.solid(tc, Color(0.78, 0.64, 0.46))
	top.position = Vector3(0, 0.71, -0.1)
	c.add_child(top)
	var axe := Dressing.stuck(c, WC + "axe.gltf", Vector3(0.1, 1.05, -0.1), 20.0, 10.0, 1.1)
	axe.name = "Axe"
	Props.put(c, WC + "log_stacks.gltf", Vector3(-1.55, 0, -0.9), 25.0, 0.95)
	Props.put(c, WC + "log_stacks.gltf", Vector3(1.6, 0, -0.85), -30.0, 0.8)
	for i in 3:
		Props.put(c, WC + "log_split.gltf", Vector3(-0.9 + 0.3 * i, 0.12, 1.1 + 0.1 * (i % 2)), 30.0 * i, 0.5).rotation.z = PI * 0.5
	var g := Node3D.new()
	g.position = Vector3(1.45, 0, 0.8)
	c.add_child(g)
	DressMines.lantern_post(g, 0.85)
	Biome.flicker_light(c, Vector3(1.8, 1.3, 1.1), Color(1.0, 0.65, 0.3), 1.6, 4.5)
	_moon_pool(root, c, Vector3(-1.2, 0, 1.0), 0.45)
	var motes := Fx.elite_sparkle(c, Vector3(0, 0.8, -0.1), 1.2, 1.4)
	(motes.process_material as ParticleProcessMaterial).color = Color(1.0, 0.85, 0.5)


## Set piece 2: the moonwell. A round stone basin of silver light on a rune circle, four short
## standing stones and silver motes rising from it.
static func moonwell(root: Node3D, c: Node3D) -> void:
	var ring := Biome._rune_circle(SILVER, 2.6)
	ring.position = Vector3(0, 0.03, 0)
	(ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.6)
	c.add_child(ring)
	var wall := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.12
	cm.height = 0.55
	cm.radial_segments = 12
	wall.mesh = BiomeBlocks.solid(cm, STONE, 0.03, 60, STONE.darkened(0.3))
	wall.position = Vector3(0, 0.275, 0)
	c.add_child(wall)
	_moon_pool(root, c, Vector3(0, 0.5, 0), 0.82)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		standing_stone(c, Vector3(cos(a) * 1.85, 0, sin(a) * 1.75), -a + PI * 0.5, 1.1 + 0.2 * (i % 2), 120 + i)
	var sp := Fx.elite_sparkle(c, Vector3(0, 0.6, 0), 0.9, 2.6)
	(sp.process_material as ParticleProcessMaterial).color = SILVER
	Biome.flicker_light(c, Vector3(0, 1.4, 0.6), SILVER, 2.0, 5.5)


# --- moat corners -----------------------------------------------------------------------------------

static var _cap_mats: Dictionary = {}


## A little glowing mushroom (stem + cap) at a local position.
static func mushroom(g: Node3D, pos: Vector3, k: float, color: Color) -> void:
	var stem := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.05
	cm.height = 0.22
	cm.radial_segments = 5
	stem.mesh = BiomeBlocks.solid(cm, Color(0.86, 0.86, 0.95))
	stem.position = pos + Vector3.UP * 0.11 * k
	stem.scale = Vector3.ONE * k
	g.add_child(stem)
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.12
	sm.is_hemisphere = true
	sm.radial_segments = 8
	sm.rings = 2
	cap.mesh = sm
	var key := color.to_html()
	if not _cap_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
		m.roughness = 0.5
		_cap_mats[key] = m
	cap.material_override = _cap_mats[key]
	cap.position = pos + Vector3.UP * 0.21 * k
	cap.scale = Vector3.ONE * k
	g.add_child(cap)


static func corner(holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> void:
	var g := Node3D.new()
	g.position = p
	g.rotation.y = deg_to_rad(yaw)
	holder.add_child(g)
	match Dressing.kit(2):
		0:
			g.name = "FairyRing"
			var cols := [Color(0.35, 0.95, 0.9), Color(0.75, 0.5, 1.0)]
			for i in 7:
				var a := TAU * float(i) / 7.0
				mushroom(g, Vector3(cos(a) * 0.6, 0, sin(a) * 0.6), 1.0 + 0.4 * float(i % 3), cols[i % 2])
			var l := OmniLight3D.new()
			l.light_color = Color(0.5, 0.9, 1.0)
			l.light_energy = 0.8
			l.omni_range = 2.4
			l.position = Vector3(0, 0.6, 0)
			g.add_child(l)
		1:
			g.name = "Boulders"
			for i in 2:
				var r := Props.put(g, F + ["Rock_1_B", "Rock_1_H"][i] + "_Color1.gltf", Vector3(-0.3 + 0.6 * i, 0, 0.1 * i), 40.0 * i, 0.55)
				Props.tint(r, Color(0.6, 0.66, 0.85), 0.4)
			Props.put(g, F + "Bush_4_B_Color4.gltf", Vector3(0.2, 0, 0.5), 0.0, 0.6)
			mushroom(g, Vector3(-0.5, 0, 0.45), 1.2, Color(0.35, 0.95, 0.9))
		2:
			g.name = "Stump"
			var st := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.32
			cm.bottom_radius = 0.4
			cm.height = 0.36
			cm.radial_segments = 8
			st.mesh = BiomeBlocks.solid(cm, Color(0.42, 0.3, 0.24), 0.03, int(sx * 3 + sz * 5 + 70))
			st.position.y = 0.18
			g.add_child(st)
			Dressing.stuck(g, WC + "axe.gltf", Vector3(0.05, 0.55, 0), 30.0, 12.0, 0.6)
			Props.put(g, WC + "log_split.gltf", Vector3(0.55, 0.1, 0.3), 20.0, 0.45).rotation.z = PI * 0.5
