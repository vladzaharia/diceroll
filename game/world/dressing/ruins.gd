class_name DressRuins
extends RefCounted
## Sunscorched Ruins kits (docs/design/2026-09-29-new-biomes.md §5). Frame (BiomeBlocks): bleached
## sand, a low sandstone dune line at the back, a harsh high-noon key, sand streaming on the wind.
## Here: sandstone ruins (tinted Dungeon walls, pillars and columns sunk at angles), bleached dead
## trees, half-buried shields and weapons, bones, dust devils, then the seeded kits:
##  set pieces (kit(0)): 0 the half-buried tomb gate (an arch with a giant skull over a dark stair),
##                       1 the great oasis (a turquoise pool in a ring of broken columns),
##                       2 the colossus remains (a giant ribcage and skull, a buried sarcophagus);
##  sides (kit(1)): 0 a colonnade, 1 caravan remains, 2 obelisks and shields;
##  moat corners (kit(2)): 0 a broken column stump, 1 bones and a shield, 2 a small palm pool.

const D := Props.DUN
const H := Props.HAL
const RES := Dressing.RES
const SKP := Dressing.SKP
const F := Dressing.FOREST
## Sandstone re-tint for the Dungeon masonry (colour, strength).
const STONE := Color(0.98, 0.8, 0.56, 0.72)
const STONE_DARK := Color(0.82, 0.6, 0.4, 0.75)
const BONE := Color(0.96, 0.92, 0.8, 0.5)
const SAND := Color(0.9, 0.76, 0.52)
const PALM := Color(0.36, 0.66, 0.26)


static func dress(root: Node3D, d: Node3D, c: Node3D) -> void:
	var e := Dressing.extent
	var h := Dressing.half
	var s := Dressing.s
	_back()
	_sides(Dressing.kit(1))
	_front()
	# rubble heaps and palm clumps round the border
	for i in 6:
		var a := TAU * float(i) / 6.0 + Dressing.rng.randf_range(-0.3, 0.3)
		var r := e + Dressing.rng.randf_range(1.2, 2.6)
		var x := cos(a) * r
		var z := sin(a) * r
		if Dressing.fits(x, z, 0.8, 1.4 if i % 3 == 0 else 0.9):
			var g := Dressing.group("Rubble" if i % 3 != 0 else "Palms", x, z, 0.8)
			if i % 3 != 0:
				ruin(g, D + "rubble_half.gltf", Vector3.ZERO, Dressing.rng.randf() * 360.0, 0.2, 0.0, 0.0, STONE)
				g.scale.y = 0.55
			else:
				for k in 2:
					BiomeBlocks.round_tree(g, Vector3(0.35 * k - 0.15, 0, 0.25 * k), 0.36 + 0.08 * k, PALM, 90 + i * 3 + k, true)
	for i in 2:
		var x := (-1.0 if i == 0 else 1.0) * (e + Dressing.rng.randf_range(1.2, 2.2))
		var z := Dressing.rng.randf_range(-e * 0.4, e * 0.6)
		var dd := dust_devil(d, Vector3(x, 0.0, z))
		dd.set_meta("prescaled", true)
	Dressing.scatter([F + "Rock_5_A_Color1.gltf", F + "Rock_5_B_Color1.gltf", F + "Rock_2_A_Color1.gltf"], int(30 * s * s),
		"border", Vector2(0.4, 0.9), Color(0.86, 0.68, 0.46, 0.7))
	Dressing.scatter([H + "bone_A.gltf", H + "bone_B.gltf", H + "bone_C.gltf", SKP + "Skeleton_Arrow_Broken_Half.gltf"],
		int(12 * s), "all", Vector2(0.5, 0.8), BONE)
	BiomeBlocks.scatter_tufts(d, Color(0.72, 0.62, 0.32), int(26 * s * s))
	match Dressing.kit(0):
		0:
			tomb_gate(c)
		1:
			great_oasis(c)
		2:
			colossus_remains(c)


# --- shared pieces ------------------------------------------------------------------------------------

## A Dungeon masonry piece re-tinted to sandstone, sunk `sink` into the sand and tilted `tilt`
## degrees about z (a ruin), under `parent` at a local position.
static func ruin(parent: Node3D, path: String, pos: Vector3, yaw: float, k: float, tilt := 0.0, sink := 0.0,
		tint := STONE) -> Node3D:
	var n := Props.put(parent, path, pos + Vector3.DOWN * sink, yaw, k)
	n.rotation.z = deg_to_rad(tilt)
	Props.tint(n, Color(tint.r, tint.g, tint.b), tint.a)
	return n


## A low sand drift (a faceted, jittered mound) of radius r.
static func drift(parent: Node3D, pos: Vector3, r: float, seed := 1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Drift"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 1.0
	cm.height = 0.26
	cm.radial_segments = 9
	cm.rings = 1
	mi.mesh = BiomeBlocks.solid(cm, SAND.lightened(0.05), 0.05, seed)
	mi.position = pos + Vector3.UP * 0.1 * r
	mi.scale = Vector3(r, r, r * 0.8)
	mi.rotation.y = float(seed) * 0.7
	parent.add_child(mi)
	return mi


## A terracotta amphora (belly, neck and lip) at a local position; k = size.
static func amphora(parent: Node3D, pos: Vector3, k: float, color := Color(0.78, 0.4, 0.24), tipped := false) -> Node3D:
	var n := Node3D.new()
	n.name = "Amphora"
	n.position = pos
	n.scale = Vector3.ONE * k
	parent.add_child(n)
	var body := MeshInstance3D.new()
	body.mesh = BiomeBlocks.solid(BiomeBlocks._sphere(0.26, 8, 5), color, 0.0, 3, color.darkened(0.25), Vector3(1.0, 1.25, 1.0))
	body.position.y = 0.32
	n.add_child(body)
	var neck := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.13
	cm.height = 0.22
	cm.radial_segments = 8
	neck.mesh = BiomeBlocks.solid(cm, color.lightened(0.05))
	neck.position.y = 0.66
	n.add_child(neck)
	var band := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.265
	bc.bottom_radius = 0.265
	bc.height = 0.05
	bc.radial_segments = 8
	band.mesh = BiomeBlocks.solid(bc, Color(0.2, 0.16, 0.14))
	band.position.y = 0.42
	n.add_child(band)
	if tipped:
		n.rotation.z = deg_to_rad(80.0)
		n.position.y += 0.26 * k
	return n


## A sandstone obelisk (tapered shaft, pyramid cap) of height hgt at a local position.
static func obelisk(parent: Node3D, pos: Vector3, hgt: float, seed := 1) -> Node3D:
	var n := Node3D.new()
	n.name = "Obelisk"
	n.position = pos
	parent.add_child(n)
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.3
	cm.height = hgt
	cm.radial_segments = 4
	cm.rings = 1
	shaft.mesh = BiomeBlocks.solid(cm, Color(0.9, 0.74, 0.52), 0.01, seed, Color(0.72, 0.52, 0.36))
	shaft.position.y = hgt * 0.5
	shaft.rotation.y = PI * 0.25
	n.add_child(shaft)
	var cap := MeshInstance3D.new()
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.22
	tip.height = 0.36
	tip.radial_segments = 4
	cap.mesh = BiomeBlocks.solid(tip, Color(1.0, 0.84, 0.44))
	cap.position.y = hgt + 0.18
	cap.rotation.y = PI * 0.25
	n.add_child(cap)
	var glyph := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.14, hgt * 0.5, 0.02)
	glyph.mesh = gb
	glyph.material_override = Props.flat_material(Color(0.5, 0.3, 0.2))
	glyph.position = Vector3(0, hgt * 0.55, 0.23)
	n.add_child(glyph)
	return n


## A dust devil: a thin column of sand swirling up (particles).
static func dust_devil(parent: Node3D, pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "DustDevil"
	p.amount = 40
	p.lifetime = 2.4
	p.preprocess = 2.4
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.25
	pm.emission_ring_inner_radius = 0.05
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3.ZERO
	pm.orbit_velocity_min = 0.9
	pm.orbit_velocity_max = 1.3
	pm.radial_accel_min = 0.25
	pm.radial_accel_max = 0.45
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	grad.colors = PackedColorArray([Color(0.95, 0.82, 0.6, 0.0), Color(0.95, 0.82, 0.6, 0.55), Color(0.95, 0.82, 0.6, 0.3),
		Color(0.95, 0.82, 0.6, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	q.material = Props.particle_material("dot", false)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	parent.add_child(p)
	return p


## A pool of water with a sand rim, reeds and palms (radius r) at a local position.
static func pool(parent: Node3D, pos: Vector3, r: float, palms := 2, seed := 1) -> Node3D:
	var n := Node3D.new()
	n.name = "Pool"
	n.position = pos
	parent.add_child(n)
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = r * 1.15
	rc.bottom_radius = r * 1.3
	rc.height = 0.08
	rc.radial_segments = 14
	rim.mesh = BiomeBlocks.solid(rc, Color(0.62, 0.66, 0.36), 0.03, seed)
	rim.position.y = 0.02
	n.add_child(rim)
	var w := MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = r
	wc.bottom_radius = r
	wc.height = 0.03
	wc.radial_segments = 18
	w.mesh = wc
	w.material_override = TileStyle.water_material()
	w.position.y = 0.06
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(w)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in palms:
		var a := rng.randf() * TAU
		var t := BiomeBlocks.round_tree(n, Vector3(cos(a), 0, sin(a)) * r * 1.2, rng.randf_range(0.5, 0.75) * r, PALM, seed + i, true)
		t.name = "Palm"
	for i in 3:
		var a := rng.randf() * TAU
		BiomeBlocks.bush(n, Vector3(cos(a), 0, sin(a)) * r * 1.15, 0.35 * r + 0.15, PALM.lightened(0.05), seed + 10 + i, true)
	return n


# --- frame: the back dunes and ruined wall -----------------------------------------------------------

static func _back() -> void:
	var e := Dressing.extent
	var h := Dressing.half
	# a broken sandstone wall line along the back, with gaps
	var n := 6
	for i in n:
		if i == 2 or Dressing.chance(0.2):
			continue
		var x := lerpf(-h + 2.2, h - 2.2, (float(i) + 0.5) / float(n)) + Dressing.rng.randf_range(-0.4, 0.4)
		var z := -e - 1.3
		var path: String = [D + "wall_broken.gltf", D + "wall_half.gltf", D + "wall_cracked.gltf", D + "wall.gltf"][i % 4]
		if not Dressing.fits(x, z, 1.1, 99.0):
			continue
		var g := Dressing.group("RuinWall", x, z, 1.1)
		ruin(g, path, Vector3.ZERO, Dressing.rng.randf_range(-8.0, 8.0), 0.5, Dressing.rng.randf_range(-4.0, 4.0), 0.3)
	# broken pillars and bleached dead trees on the dunes
	for x in [-h + 1.3, -e * 0.3, e * 0.4, h - 1.3]:
		var px: float = x + Dressing.rng.randf_range(-0.5, 0.5)
		var pz := -h + 1.4 + Dressing.rng.randf_range(0.0, 0.8)
		if Dressing.chance(0.5):
			var t := Dressing.place_near(F + "Tree_Bare_%d_%s_Color1.gltf" % [1 + Dressing.rng.randi() % 2, ["A", "B", "C"][Dressing.rng.randi() % 3]],
				px, pz, 0.7, 1.0, Color(0.92, 0.84, 0.72, 0.75))
		else:
			if Dressing.fits(px, pz, 0.8, 99.0):
				var g := Dressing.group("Pillar", px, pz, 0.8)
				ruin(g, D + "pillar.gltf", Vector3.ZERO, 0.0, 0.42, Dressing.rng.randf_range(-10.0, 10.0), 0.2)
	for side in [-1.0, 1.0]:
		Dressing.place_near(F + "Tree_Bare_2_A_Color1.gltf", side * (h - 1.4), -e * 0.2, 0.6, 1.0,
			Color(0.92, 0.84, 0.72, 0.75))
		# tall obelisks on the back corners of the dunes
		var ox: float = side * (e + 1.6)
		var oz := -e - 1.5
		if Dressing.fits(ox, oz, 0.5, 99.0):
			var g := Dressing.group("Obelisk", ox, oz, 0.5)
			obelisk(g, Vector3.ZERO, 3.0, int(side * 5.0) + 9)


# --- sides and front ----------------------------------------------------------------------------------

static func _sides(kit: int) -> void:
	var e := Dressing.extent
	for side in [-1.0, 1.0]:
		var x: float = side * (e + 1.9)
		var face: float = -90.0 * side
		match kit:
			0:  # colonnade: a row of columns, one fallen, one lintel still up
				var zs := [-e * 0.6, -e * 0.15, e * 0.3]
				for k in zs.size():
					var z: float = zs[k] + Dressing.rng.randf_range(-0.3, 0.3)
					if not Dressing.fits(x, z, 0.55, 2.4 if z < e * 0.35 else 1.1):
						continue
					var g := Dressing.group("Column", x, z, 0.55)
					var broken := k == 2 or Dressing.chance(0.25)
					ruin(g, D + "pillar.gltf", Vector3.ZERO, 0.0, 0.46, Dressing.rng.randf_range(-6.0, 6.0), 0.1 if not broken else 0.75)
				var fl := Dressing.group("Fallen", x - side * 0.2, e * 0.75, 0.9)
				ruin(fl, D + "column.gltf", Vector3(0, 0.3, 0), face, 1.05, 90.0, 0.0)
			1:  # caravan remains
				var g := Dressing.group("Caravan", x, -e * 0.3, 1.1)
				g.rotation.y = deg_to_rad(face)
				Props.put(g, RES + "Containers_Crate_Medium_Tan.gltf", Vector3(0, 0, 0), 12.0, 0.62)
				Props.put(g, RES + "Textiles_Stack_Small.gltf", Vector3(0.8, 0, 0.3), -20.0, 0.62)
				Props.put(g, D + "barrel_small.gltf", Vector3(-0.7, 0, 0.35), 0.0, 0.5)
				amphora(g, Vector3(0.3, 0, 0.75), 0.9)
				amphora(g, Vector3(-0.2, 0, 0.85), 0.8, Color(0.86, 0.5, 0.3), true)
				var bones := Dressing.group("Bones", x, e * 0.45, 0.8)
				DressBits.bone_pile(bones, 0.85, null, BONE)
				Dressing.place_near(RES + "Food_Crate_Large_Empty.gltf", x, e * 0.95, 0.5, 0.8)
			2:  # obelisks and shields
				for z in [-e * 0.5, e * 0.2]:
					var zz: float = z + Dressing.rng.randf_range(-0.3, 0.3)
					if Dressing.fits(x, zz, 0.5, 2.3 if zz < e * 0.35 else 1.1):
						var g := Dressing.group("Obelisk", x, zz, 0.5)
						obelisk(g, Vector3.ZERO, 2.1 if zz < e * 0.35 else 1.0, int(absf(zz) * 10.0) + 3)
				var sh := Dressing.group("Shields", x, e * 0.7, 0.7)
				Dressing.stuck(sh, SKP + "Skeleton_Shield_Large_A.gltf", Vector3(0, 0.3, 0), face, -35.0, 0.8, STONE_DARK)
				Dressing.stuck(sh, SKP + "Skeleton_Blade.gltf", Vector3(0.45, 0.35, 0.2), face + 30.0, 25.0, 0.9)


## Front strip: half-buried shields and weapons, a skull, a sand drift (all low).
static func _front() -> void:
	var fill := func(g: Node3D, i: int) -> void:
		match (i + Dressing.kit(1)) % 3:
			0:
				drift(g, Vector3.ZERO, 0.7, 30 + i)
				Dressing.stuck(g, SKP + "Skeleton_Shield_Small_A.gltf", Vector3(0.1, 0.12, 0), 0.0, -60.0, 0.8, STONE_DARK)
			1:
				amphora(g, Vector3(-0.25, 0, 0), 0.9)
				amphora(g, Vector3(0.22, 0, -0.2), 0.75, Color(0.86, 0.5, 0.3))
				amphora(g, Vector3(0.3, 0, 0.35), 0.8, Color(0.74, 0.38, 0.22), true)
			2:
				var st := ruin(g, D + "column.gltf", Vector3(0, 0.0, 0), 20.0, 0.62, 0.0, 0.12)
				st.name = "Stump"
				ruin(g, D + "rubble_half.gltf", Vector3(0.45, 0, 0.1), 40.0, 0.12, 0.0, 0.0, STONE_DARK)
	Dressing.front_row(fill, 5, 0.7)


# --- set pieces ----------------------------------------------------------------------------------------

## Set piece 0: the half-buried tomb gate. An arched gateway sunk at an angle into a sand mound,
## a broken wall and a decorated pillar leaning beside it, a dark stair going down under the
## arch and a giant skull over it.
static func tomb_gate(c: Node3D) -> void:
	drift(c, Vector3(0, -0.1, -0.5), 2.3, 3)
	var arch := ruin(c, D + "wall_archedwindow_open.gltf", Vector3(0, 0, -0.55), 0.0, 0.8, 3.0, 0.45)
	arch.name = "TombGate"
	# the dark way down inside the arch
	var dark := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.3)
	dark.mesh = q
	dark.material_override = Props.flat_material(Color(0.03, 0.02, 0.03), 1.0)
	dark.position = Vector3(0, 0.9, -0.62)
	dark.scale = Vector3(1.3, 1.35, 1.0)
	c.add_child(dark)
	var stairs := ruin(c, D + "stairs_wide.gltf", Vector3(0, 0, 0.35), 180.0, 0.2, 0.0, 0.85)
	stairs.name = "Stairs"
	var sk := Props.put(c, H + "skull.gltf", Vector3(0, 2.75, -0.35), 0.0, 1.3)
	sk.name = "GiantSkull"
	Props.tint(sk, Color(0.98, 0.9, 0.74), 0.5)
	ruin(c, D + "wall_broken.gltf", Vector3(-1.9, 0, -0.35), 32.0, 0.5, -8.0, 0.35)
	ruin(c, D + "pillar_decorated.gltf", Vector3(1.85, 0, -0.45), -20.0, 0.5, 11.0, 0.3)
	obelisk(c, Vector3(-1.95, 0, 0.95), 1.3, 17)
	amphora(c, Vector3(1.7, 0, 1.0), 0.95)
	amphora(c, Vector3(2.05, 0, 0.7), 0.8, Color(0.86, 0.5, 0.3), true)
	ruin(c, D + "column.gltf", Vector3(1.2, 0.28, 1.1), 70.0, 1.0, 90.0, 0.0)
	Dressing.stuck(c, SKP + "Skeleton_Shield_Large_B.gltf", Vector3(-1.1, 0.25, 1.1), 20.0, -55.0, 0.8, STONE_DARK)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 1.2
	l.omni_range = 3.5
	l.position = Vector3(0, 0.9, 0.2)
	c.add_child(l)


## Set piece 1: the great oasis. A turquoise pool with palms and reeds in a ring of broken
## columns, cool sparkle on the water.
static func great_oasis(c: Node3D) -> void:
	pool(c, Vector3(0, 0, 0), 1.35, 3, 77)
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.3
		if absf(sin(a) - 1.0) < 0.3:
			continue
		var k := 0.34 if i % 2 == 0 else 0.26
		ruin(c, D + "pillar.gltf", Vector3(cos(a) * 2.25, 0, sin(a) * 2.1), rad_to_deg(a), k, Dressing.rng.randf_range(-7.0, 7.0),
			0.1 if i % 3 != 2 else 0.6)
	var sp := Fx.elite_sparkle(c, Vector3(0, 0.1, 0), 1.2, 0.3)
	(sp.process_material as ParticleProcessMaterial).color = Color(0.75, 1.0, 1.0)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.95, 1.0)
	l.light_energy = 1.0
	l.omni_range = 3.5
	l.position = Vector3(0, 0.8, 0.4)
	c.add_child(l)


## Set piece 2: the colossus remains. A giant ribcage and skull half-buried in drifts, a toppled
## column and the lid of a buried sarcophagus.
static func colossus_remains(c: Node3D) -> void:
	drift(c, Vector3(-0.2, -0.1, -0.2), 2.2, 9)
	var rib := Props.put(c, H + "ribcage.gltf", Vector3(-0.3, 0.55, -0.35), 25.0, 2.4)
	rib.name = "Ribcage"
	rib.rotation.z = deg_to_rad(-12.0)
	Props.tint(rib, Color(0.97, 0.92, 0.78), 0.55)
	var sk := Props.put(c, H + "skull.gltf", Vector3(1.35, -0.12, 0.35), -35.0, 1.3)
	sk.name = "Skull"
	sk.rotation.x = deg_to_rad(-12.0)
	Props.tint(sk, Color(0.97, 0.92, 0.78), 0.55)
	var sar := ruin(c, H + "coffin_decorated.gltf", Vector3(-1.3, 0, 1.05), 65.0, 0.5, 0.0, 0.3, STONE_DARK)
	sar.name = "Sarcophagus"
	ruin(c, D + "column.gltf", Vector3(0.45, 0.26, 1.35), 10.0, 0.95, 90.0, 0.0)
	Props.put(c, H + "bone_A.gltf", Vector3(1.8, 0.05, -0.8), 40.0, 1.3)
	amphora(c, Vector3(-0.5, 0, 1.55), 0.85, Color(0.8, 0.44, 0.26), true)
	Dressing.stuck(c, SKP + "Skeleton_Golem_Axe_Large.gltf", Vector3(-1.6, 0.9, -0.9), 30.0, 18.0, 0.9)


# --- moat corners -----------------------------------------------------------------------------------

static func corner(holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> void:
	var g := Node3D.new()
	g.position = p
	g.rotation.y = deg_to_rad(yaw)
	holder.add_child(g)
	match Dressing.kit(2):
		0:
			g.name = "Stump"
			drift(g, Vector3.ZERO, 0.8, int(sx * 3 + sz * 5 + 20))
			ruin(g, D + "pillar.gltf", Vector3(0, 0, 0), 0.0, 0.32, 6.0 * sx, 0.9)
			ruin(g, D + "column.gltf", Vector3(0.55, 0.22, 0.3), 40.0, 0.8, 90.0, 0.0)
		1:
			g.name = "Bones"
			drift(g, Vector3.ZERO, 0.7, int(sx * 7 + sz * 3 + 30))
			DressBits.bone_pile(g, 0.75, null, BONE)
			Dressing.stuck(g, SKP + "Skeleton_Shield_Large_A.gltf", Vector3(-0.5, 0.2, -0.2), 0.0, -50.0, 0.65, STONE_DARK)
		2:
			g.name = "PalmPool"
			pool(g, Vector3.ZERO, 0.55, 1, int(sx * 5 + sz * 9 + 50))
