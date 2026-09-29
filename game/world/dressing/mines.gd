class_name DressMines
extends RefCounted
## Deep Mines kits (docs/design/2026-09-29-new-biomes.md §2). Frame (BiomeBlocks): slate cave
## floor, tall rock walls at the back and sides (terrain), low cave ambient, dark fog, dust motes.
## Here: gem veins glowing in the walls, timber props and lantern posts (many small warm lights),
## a mine-cart track, water drips, rubble and ore clutter, then the seeded kits:
##  set pieces (kit(0)): 0 the mine-shaft mouth (scaffold over the pit, gem cart), 1 the crystal
##                       cavern (a slate mound split by giant teal / magenta / gold crystals),
##                       2 the ore depot (rails, loaded carts, a bullion stack);
##  sides (kit(1)): 0 timber supports + crates, 1 miners' camp (tools, barrels, lantern bench),
##                  2 ore stockpile (nugget heaps, stone chunks, gem pallet);
##  moat corners (kit(2)): 0 a glowing vein rock, 1 a lantern post and crates, 2 a loaded cart.

const D := Props.DUN
const DX := Dressing.DX
const RES := Dressing.RES
const TX := Dressing.TX
const F := Dressing.FOREST
const SLATE := Color(0.64, 0.62, 0.68)
const WOOD := Color(0.44, 0.29, 0.17)
const LAMP := Color(1.0, 0.7, 0.38)
## Gem glints of the veins (teal, magenta, gold).
const GEMS := [Color(0.25, 0.95, 0.9), Color(1.0, 0.35, 0.85), Color(1.0, 0.74, 0.24)]
const ROCK_TINT := Color(0.34, 0.33, 0.37, 0.88)


static func dress(root: Node3D, d: Node3D, c: Node3D) -> void:
	var e := Dressing.extent
	var h := Dressing.half
	var s := Dressing.s
	_veins(d)
	# lantern posts down both sides and at the back corners (the cave's warm pools of light)
	for side in [-1.0, 1.0]:
		for z in [-e * 0.55, e * 0.15, e * 0.75]:
			_lantern_post(d, side * (e + 1.0 + Dressing.rng.randf_range(0.0, 0.5)), z + Dressing.rng.randf_range(-0.5, 0.5))
	_track(d, -1.0 if Dressing.chance(0.5) else 1.0)
	_sides(Dressing.kit(1))
	_front()
	# drips from the cave roof and slow dust (the ambient "dust" motes come from Biome)
	var dr := drips(d, Vector3(0, 6.0, -e * 0.6), Vector3(h * 0.8, 0.2, e * 0.5))
	dr.set_meta("prescaled", true)
	Dressing.scatter([RES + "Stone_Chunks_Small.gltf", F + "Rock_5_A_Color1.gltf", F + "Rock_5_B_Color1.gltf",
		F + "Rock_2_A_Color1.gltf"], int(40 * s * s), "border", Vector2(0.5, 1.0), ROCK_TINT)
	Dressing.scatter([RES + "Gold_Nugget_Small.gltf", RES + "Copper_Nugget_Small.gltf", RES + "Silver_Nugget_Small.gltf",
		RES + "Iron_Nugget_Small.gltf"], int(22 * s), "all", Vector2(0.9, 1.3))
	Dressing.scatter([F + "Rock_5_C_Color1.gltf", RES + "Stone_Chunks_Small.gltf"], int(10 * s), "moat", Vector2(0.4, 0.7), ROCK_TINT)
	match Dressing.kit(0):
		0:
			shaft(c)
		1:
			cavern(c)
		2:
			depot(c)


# --- frame pieces ---------------------------------------------------------------------------------

## Gem veins in the back wall: crystal clusters on the rock shelves, each with its glint light,
## and timber wall props with torches between them.
static func _veins(d: Node3D) -> void:
	var e := Dressing.extent
	var h := Dressing.half
	var n := 6
	for i in n:
		var x := lerpf(-h + 1.4, h - 1.4, (float(i) + 0.5) / float(n)) + Dressing.rng.randf_range(-0.6, 0.6)
		var z := -e - 1.0 - Dressing.rng.randf_range(0.0, 1.6)
		var y := Dressing.gy(x, z)
		var col: Color = GEMS[i % GEMS.size()]
		var g := Dressing.group("Vein", x, z, 0.7)
		var cl := BiomeBlocks.crystal_cluster(g, Vector3.ZERO, Dressing.rng.randf_range(0.55, 0.85), 5, 300 + i, false,
			TileStyle.gem_material(col, 1.2))
		cl.rotation.x = Dressing.rng.randf_range(-0.25, 0.1)
		if i % 2 == 0:
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 1.2
			l.omni_range = 4.0
			l.position = Vector3(0, 0.9, 0.8)
			g.add_child(l)
		if y < 0.1:
			BiomeBlocks.rock(g, Vector3(0.1, 0, -0.2), 0.5, SLATE, 320 + i, true)
	# more veins down the side walls (the back half of the cave)
	for side in [-1.0, 1.0]:
		for z in [-e * 0.75, -e * 0.3]:
			var x: float = side * (h - 1.2)
			var zz: float = z + Dressing.rng.randf_range(-0.5, 0.5)
			var col: Color = GEMS[int(absf(zz) * 3.0) % GEMS.size()]
			var g := Dressing.group("Vein", x, zz, 0.6)
			var cl := BiomeBlocks.crystal_cluster(g, Vector3.ZERO, Dressing.rng.randf_range(0.45, 0.7), 4, int(zz * 13.0) + 340,
				false, TileStyle.gem_material(col, 1.2))
			cl.rotation.z = -side * 0.35
	# the timber props holding the roof up, against the back rise, with their torches
	for x in [-e * 0.55, e * 0.05, e * 0.6]:
		var px: float = x + Dressing.rng.randf_range(-0.6, 0.6)
		var pz := -e - 0.55
		if not Dressing.fits(px, pz, 0.5, 4.0):
			continue
		var sc := Dressing.place(DX + "scaffold_pillar_wall_torch.gltf", Vector3(px, 0, pz), 0.0, 0.55)
		sc.name = "WallProp"
		Biome.flicker_light(Dressing.d, sc.position + Vector3(0, 1.9, 1.0), LAMP, 1.0, 4.5).set_meta("prescaled", true)
		Biome.flame(Dressing.d, sc.position + Vector3(0.62, 1.72, 0.25), LAMP, 0.28, 6).set_meta("prescaled", true)
		Biome.flame(Dressing.d, sc.position + Vector3(-0.62, 1.72, 0.25), LAMP, 0.28, 6).set_meta("prescaled", true)


## A lantern hanging from a short timber post, with its warm light.
static func _lantern_post(d: Node3D, x: float, z: float) -> void:
	if not Dressing.fits(x, z, 0.4, 2.2):
		return
	var g := Dressing.group("LanternPost", x, z, 0.4)
	lantern_post(g, 1.0)
	Biome.flicker_light(d, g.position + Vector3(0.35, 1.5, 0.3), LAMP, 1.3, 4.5).set_meta("prescaled", true)


## Post + arm + lantern at a group's origin (k = size).
static func lantern_post(g: Node3D, k := 1.0) -> void:
	var post := Props.put(g, DX + "post.gltf", Vector3.ZERO, 0.0, 0.5 * k)
	post.name = "Post"
	var arm := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.6, 0.1, 0.1) * k
	arm.mesh = BiomeBlocks.solid(bx, WOOD, 0.004, 3)
	arm.position = Vector3(0.25, 1.85, 0) * k
	g.add_child(arm)
	var lt := Props.put(g, TX + "lantern.gltf", Vector3(0.44, 1.38, 0) * k, 0.0, 0.5 * k)
	lt.name = "Lantern"
	var glow := MeshInstance3D.new()
	glow.mesh = BiomeBlocks._sphere(0.09 * k, 6, 4)
	glow.material_override = Props.glow_material(LAMP, false, 2.2)
	glow.position = Vector3(0.44, 1.56, 0) * k
	g.add_child(glow)


## Drips of water falling from the cave roof (a thin, sparse particle rain).
static func drips(parent: Node3D, pos: Vector3, box: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Drips"
	p.amount = 18
	p.lifetime = 1.4
	p.preprocess = 2.0
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3.DOWN
	pm.spread = 2.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.1, 0.85, 1.0])
	grad.colors = PackedColorArray([Color(0.6, 0.8, 1.0, 0.0), Color(0.7, 0.85, 1.0, 0.8), Color(0.7, 0.85, 1.0, 0.6),
		Color(0.7, 0.85, 1.0, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.22)
	var m := Props.particle_material("dot")
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-16, -8, -10), Vector3(32, 10, 20))
	parent.add_child(p)
	return p


# --- mine carts and rails ------------------------------------------------------------------------

## Straight rails (two steel rails on timber sleepers) of `length` along local z at a group origin.
static func rails(g: Node3D, length: float, k := 1.0) -> void:
	var steel := Props.flat_material(Color(0.42, 0.42, 0.46), 0.4)
	steel.metallic = 0.6
	var n := int(length / (0.55 * k))
	for i in n + 1:
		var sl := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.9, 0.07, 0.18) * k
		sl.mesh = BiomeBlocks.solid(bx, WOOD.darkened(0.1 * (i % 2)), 0.006, 40 + i)
		sl.position = Vector3(0, 0.035 * k, -length * 0.5 + float(i) * length / maxf(n, 1))
		sl.rotation.y = deg_to_rad(Dressing.rng.randf_range(-4.0, 4.0))
		g.add_child(sl)
	for sx in [-1.0, 1.0]:
		var rl := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.06, 0.07, length) * k
		rl.mesh = bx
		rl.material_override = steel
		rl.position = Vector3(sx * 0.3 * k, 0.1 * k, 0)
		g.add_child(rl)


## A mine cart (timber box with iron bands on four wheels) heaped with `load` ("Gold", "Copper",
## "Iron", "Silver", "stone" or "gems"), facing along local z.
static func cart(g: Node3D, load := "Gold", k := 1.0) -> Node3D:
	var n := Node3D.new()
	n.name = "MineCart"
	n.scale = Vector3.ONE * k
	g.add_child(n)
	var body := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.7, 0.46, 0.95)
	body.mesh = BiomeBlocks.solid(bx, WOOD, 0.01, 7, WOOD.darkened(0.3), Vector3(1.0, 1.0, 1.0))
	body.position = Vector3(0, 0.44, 0)
	n.add_child(body)
	var iron := Props.flat_material(Color(0.3, 0.3, 0.34), 0.5)
	iron.metallic = 0.5
	for z in [-0.34, 0.34]:
		var band := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.74, 0.5, 0.06)
		band.mesh = bb
		band.material_override = iron
		band.position = Vector3(0, 0.44, z)
		n.add_child(band)
	for sx in [-1.0, 1.0]:
		for z in [-0.3, 0.3]:
			var w := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.13
			cy.bottom_radius = 0.13
			cy.height = 0.07
			cy.radial_segments = 8
			w.mesh = cy
			w.material_override = iron
			w.rotation.z = PI * 0.5
			w.position = Vector3(sx * 0.37, 0.16, z)
			n.add_child(w)
	match load:
		"stone":
			Props.put(n, RES + "Stone_Chunks_Small.gltf", Vector3(0, 0.62, 0), 20.0, 0.55)
		"gems":
			Props.put(n, RES + "Gems_Pile_Small.gltf", Vector3(0, 0.62, 0), 20.0, 0.6)
		_:
			Props.put(n, RES + load + "_Nuggets.gltf", Vector3(0, 0.6, 0.0), 10.0, 0.66)
			Props.put(n, RES + load + "_Nugget_Large.gltf", Vector3(0.12, 0.78, 0.16), 40.0, 0.7)
	return n


## The cart track down one side of the ring (flat ground only), with a loaded cart on it.
static func _track(d: Node3D, side: float) -> void:
	var e := Dressing.extent
	var x := side * (e + 1.25)
	var z0 := -0.6
	var z1 := e + 1.6
	var len := z1 - z0
	for k in 5:
		if not Dressing.fits(x, lerpf(z0, z1, float(k) / 4.0), 0.5, 0.3):
			return
	var g := Dressing.group("Track", x, (z0 + z1) * 0.5, 0.2)
	rails(g, len, 1.0)
	for k in 5:
		Dressing.occupy(x, lerpf(z0, z1, float(k) / 4.0), 0.55)
	var ct := cart(g, String(Dressing.pick(["Gold", "Copper", "Silver"])), 1.0)
	ct.position.z = Dressing.rng.randf_range(-len * 0.3, len * 0.1)


# --- sides and front ---------------------------------------------------------------------------------

static func _sides(kit: int) -> void:
	var e := Dressing.extent
	var h := Dressing.half
	for side in [-1.0, 1.0]:
		var x: float = side * (e + 1.9)
		var face: float = -90.0 * side
		match kit:
			0:  # timber supports + crates
				for z in [-e * 0.35, e * 0.45]:
					if Dressing.fits(x, z, 1.2, 2.3):
						var sc := Dressing.place(DX + "scaffold_frame_small.gltf", Vector3(x, 0, z), face, 0.5)
						sc.name = "Scaffold"
				Dressing.place_near(RES + "Containers_Crate_Medium_Wood.gltf", x + side * 0.4, e * 0.05, 0.7, 1.0)
				Dressing.place_near(RES + "Containers_Crate_Small_Grey.gltf", x - side * 0.2, e * 0.9, 0.8, 0.8)
			1:  # miners' camp
				var g := Dressing.group("Camp", x, e * 0.1, 1.0)
				g.rotation.y = deg_to_rad(face)
				Props.put(g, DX + "bucket_pickaxes.gltf", Vector3(-0.5, 0, 0), 20.0, 0.62)
				Props.put(g, D + "barrel_small.gltf", Vector3(0.55, 0, -0.2), 0.0, 0.55)
				Dressing.stuck(g, TX + "shovel.gltf", Vector3(0.1, 0.45, 0.5), 30.0, 12.0, 0.9)
				Dressing.place_near(DX + "bench.gltf", x, -e * 0.4, 0.55, 1.0)
				Dressing.place_near(RES + "Containers_Box_Large.gltf", x, e * 0.75, 0.6, 1.0)
			2:  # ore stockpile
				var g := Dressing.group("Ore", x, -e * 0.2, 1.0)
				g.rotation.y = deg_to_rad(face)
				DressBits.ore_heap(g, String(Dressing.pick(["Gold", "Copper", "Silver", "Iron"])), 1.1)
				Dressing.place_near(RES + "Stone_Chunks_Large.gltf", x, e * 0.55, 0.62, 1.0, ROCK_TINT)
				var p := Dressing.group("GemPallet", x, e * 0.1 if side < 0 else e * 0.95, 0.8)
				if p:
					Props.put(p, RES + "Pallet_Wood.gltf", Vector3.ZERO, 10.0, 0.6)
					Props.put(p, RES + "Gems_Pile_Small.gltf", Vector3(0, 0.18, 0), 0.0, 0.8)


## Front strip: low rubble and ore spills (the camera side stays open).
static func _front() -> void:
	var fill := func(g: Node3D, i: int) -> void:
		match (i + Dressing.kit(1)) % 3:
			0:
				var rb := Props.put(g, D + "rubble_half.gltf", Vector3.ZERO, 0.0, 0.22)
				rb.scale.y = 0.12
				Props.tint(rb, Color(0.42, 0.4, 0.44), 0.6)
			1:
				Props.put(g, RES + "Stone_Chunks_Small.gltf", Vector3.ZERO, 0.0, 0.7)
				Props.put(g, RES + "Copper_Nuggets.gltf", Vector3(0.5, 0, 0.2), 30.0, 0.6)
			2:
				Dressing.lying(g, TX + "pickaxe.gltf", Vector3(0, 0, 0), 30.0, 0.75)
				Props.put(g, RES + "Iron_Nuggets.gltf", Vector3(-0.45, 0, 0.1), 0.0, 0.55)
	Dressing.front_row(fill, 4, 0.7)
	# two lanterns set on the ground at the front corners (warm pools of light on the camera side)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (Dressing.extent - 0.6)
		var z := Dressing.extent + 1.4
		if Dressing.fits(x, z, 0.45, 0.8):
			var g := Dressing.group("GroundLantern", x, z, 0.45)
			Props.put(g, TX + "lantern.gltf", Vector3.ZERO, 0.0, 0.62)
			Props.put(g, RES + "Containers_Crate_Small_Grey.gltf", Vector3(0.5 * sx, 0, -0.2), 20.0, 0.5)
			Biome.flicker_light(Dressing.d, g.position + Vector3(0, 0.7, 0.2), LAMP, 1.2, 4.0).set_meta("prescaled", true)


# --- set pieces ----------------------------------------------------------------------------------------

## A dark shaft: a black pit with a timber rim (the centre of the mine-shaft mouth).
static func _pit(c: Node3D, radius: float) -> void:
	var pit := MeshInstance3D.new()
	pit.name = "Pit"
	var cy := CylinderMesh.new()
	cy.top_radius = radius
	cy.bottom_radius = radius
	cy.height = 0.04
	cy.radial_segments = 10
	pit.mesh = cy
	pit.material_override = Props.flat_material(Color(0.01, 0.01, 0.015), 1.0)
	pit.position = Vector3(0, 0.02, 0)
	c.add_child(pit)
	for i in 4:
		var bm := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(radius * 2.2, 0.16, 0.22)
		bm.mesh = BiomeBlocks.solid(bx, WOOD, 0.01, 60 + i)
		var a := PI * 0.5 * i
		bm.position = Vector3(cos(a) * radius, 0.08, sin(a) * radius)
		bm.rotation.y = -a + PI * 0.5
		c.add_child(bm)


## Set piece 0: the mine-shaft mouth. A timber headframe over the dark pit, the lift bucket of
## pickaxes, a gem cart on a pallet and lanterns; warm light spills from the shaft.
static func shaft(c: Node3D) -> void:
	_pit(c, 1.05)
	var fr := Props.put(c, DX + "scaffold_frame_large.gltf", Vector3(0, 0, 0), 0.0, 0.34)
	fr.name = "Headframe"
	fr.scale.y = 0.62
	var top := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.22, 0.22, 2.6)
	top.mesh = BiomeBlocks.solid(bx, WOOD, 0.01, 8)
	top.position = Vector3(0, 2.62, 0)
	c.add_child(top)
	var wheel := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.42
	cy.bottom_radius = 0.42
	cy.height = 0.1
	cy.radial_segments = 10
	wheel.mesh = BiomeBlocks.solid(cy, Color(0.36, 0.34, 0.38), 0.0, 9)
	wheel.rotation.z = PI * 0.5
	wheel.position = Vector3(0, 2.85, 0)
	wheel.name = "Winch"
	c.add_child(wheel)
	var spin := wheel.create_tween().set_loops()
	spin.tween_property(wheel, "rotation:x", TAU, 6.0).from(0.0)
	var bucket := Props.put(c, DX + "bucket_pickaxes.gltf", Vector3(0, 1.1, 0), 20.0, 0.5)
	bucket.name = "LiftBucket"
	var bob := bucket.create_tween().set_loops()
	bob.tween_property(bucket, "position:y", 1.5, 3.0).set_trans(Tween.TRANS_SINE)
	bob.tween_property(bucket, "position:y", 0.9, 3.0).set_trans(Tween.TRANS_SINE)
	var pal := Node3D.new()
	pal.name = "GemCart"
	pal.position = Vector3(-1.75, 0, 1.05)
	pal.rotation.y = 0.5
	c.add_child(pal)
	Props.put(pal, RES + "Pallet_Wood.gltf", Vector3.ZERO, 0.0, 0.62)
	Props.put(pal, RES + "Gems_Pile_Large.gltf", Vector3(0, 0.18, 0), 20.0, 0.6)
	Props.put(pal, RES + "Gold_Nuggets.gltf", Vector3(0.3, 0.2, 0.3), 0.0, 0.6)
	var ct := Node3D.new()
	ct.position = Vector3(1.8, 0, 0.85)
	ct.rotation.y = -0.4
	c.add_child(ct)
	cart(ct, "Gold", 0.95)
	for p in [Vector3(-1.55, 0, -1.5), Vector3(1.6, 0, -1.4)]:
		var g := Node3D.new()
		g.position = p
		c.add_child(g)
		lantern_post(g, 0.9)
		Biome.flicker_light(c, p + Vector3(0.4, 1.4, 0.3), LAMP, 1.4, 4.0)
	# light up out of the shaft
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 2.2
	l.omni_range = 4.5
	l.position = Vector3(0, 0.3, 0)
	c.add_child(l)
	var glow := Biome._rune_circle(Color(1.0, 0.6, 0.25), 2.3)
	glow.position = Vector3(0, 0.05, 0)
	(glow.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.35)
	c.add_child(glow)


## Set piece 1: the crystal cavern. A slate mound split by giant teal, magenta and gold crystals,
## pickaxes driven into it, ore spilled around, coloured light.
static func cavern(c: Node3D) -> void:
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var r := BiomeBlocks.rock(c, Vector3(cos(a) * 0.7, -0.1, sin(a) * 0.6), 0.8 - 0.1 * (i % 2), SLATE.lightened(0.04 * i), 500 + i, true)
		r.scale.y *= 1.1
	BiomeBlocks.rock(c, Vector3(0, 0.2, -0.1), 1.0, SLATE, 510, true)
	var big := BiomeBlocks.crystal_cluster(c, Vector3(0, 0.7, -0.2), 1.35, 7, 511, false, TileStyle.gem_material(GEMS[0], 1.3))
	big.name = "TealCrystal"
	var mg := BiomeBlocks.crystal_cluster(c, Vector3(-1.1, 0.25, 0.4), 0.8, 5, 512, false, TileStyle.gem_material(GEMS[1], 1.3))
	mg.rotation.z = 0.35
	var gd := BiomeBlocks.crystal_cluster(c, Vector3(1.15, 0.2, 0.35), 0.75, 5, 513, false, TileStyle.gem_material(GEMS[2], 1.2))
	gd.rotation.z = -0.4
	for p in [[Vector3(0, 2.0, 0.8), GEMS[0], 2.4], [Vector3(-1.4, 1.0, 1.0), GEMS[1], 1.4], [Vector3(1.4, 1.0, 1.0), GEMS[2], 1.4]]:
		var l := OmniLight3D.new()
		l.light_color = p[1]
		l.light_energy = p[2]
		l.omni_range = 4.0
		l.position = p[0]
		c.add_child(l)
	Dressing.stuck(c, TX + "pickaxe.gltf", Vector3(0.7, 0.75, 0.75), -30.0, 35.0, 0.9)
	Dressing.stuck(c, DX + "pickaxe_gold.gltf", Vector3(-0.6, 0.7, 0.85), 40.0, 30.0, 0.55)
	for p in [Vector3(-1.9, 0, 1.3), Vector3(1.9, 0, 1.2)]:
		var g := Node3D.new()
		g.position = p
		g.rotation.y = p.x * 0.4
		c.add_child(g)
		DressBits.ore_heap(g, "Gold" if p.x < 0 else "Silver", 0.75)
	var motes := Fx.elite_sparkle(c, Vector3(0, 0.6, 0), 1.6, 2.4)
	(motes.process_material as ParticleProcessMaterial).color = Color(0.6, 1.0, 0.95)


## Set piece 2: the ore depot. A timber loading deck with a rail spur, two loaded carts, the
## bullion stack, a scale of crates and lanterns.
static func depot(c: Node3D) -> void:
	var deck := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(3.2, 0.2, 2.2)
	deck.mesh = BiomeBlocks.solid(bx, WOOD.lightened(0.05), 0.02, 20)
	deck.position = Vector3(0, 0.1, -0.5)
	c.add_child(deck)
	for i in 6:
		var plank := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.05, 0.02, 2.2)
		plank.mesh = pb
		plank.material_override = Props.flat_material(WOOD.darkened(0.35))
		plank.position = Vector3(-1.35 + 0.54 * i, 0.21, -0.5)
		c.add_child(plank)
	var spur := Node3D.new()
	spur.position = Vector3(0, 0, 1.05)
	spur.rotation.y = PI * 0.5
	c.add_child(spur)
	rails(spur, 4.2, 1.0)
	var c1 := cart(spur, "Gold", 0.9)
	c1.position.z = -1.1
	var c2 := cart(spur, "Copper", 0.9)
	c2.position.z = 1.05
	var bars := Props.put(c, RES + "Gold_Bars_Stack_Large.gltf", Vector3(-0.7, 0.2, -0.7), 15.0, 0.55)
	bars.name = "Bullion"
	Props.put(c, RES + "Silver_Bars_Stack_Medium.gltf", Vector3(0.35, 0.2, -0.95), -20.0, 0.6)
	Props.put(c, RES + "Containers_Crate_Medium_Wood.gltf", Vector3(1.05, 0.2, -0.6), 10.0, 0.62)
	Props.put(c, RES + "Containers_Crate_Small_Grey.gltf", Vector3(1.1, 0.8, -0.65), 35.0, 0.6)
	var g := Node3D.new()
	g.position = Vector3(-1.45, 0.2, -1.35)
	c.add_child(g)
	lantern_post(g, 0.9)
	Biome.flicker_light(c, Vector3(-1.05, 1.7, -1.0), LAMP, 1.6, 4.5)
	Biome.flicker_light(c, Vector3(0.9, 1.4, 0.4), LAMP, 1.2, 4.0)
	var gl := Fx.elite_sparkle(c, Vector3(-0.7, 0.6, -0.7), 0.5, 0.6)
	(gl.process_material as ParticleProcessMaterial).color = Color(1.0, 0.85, 0.4)


# --- moat corners -----------------------------------------------------------------------------------

static func corner(holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> void:
	var g := Node3D.new()
	g.position = p
	g.rotation.y = deg_to_rad(yaw)
	holder.add_child(g)
	match Dressing.kit(2):
		0:
			g.name = "Vein"
			BiomeBlocks.rock(g, Vector3(0, -0.05, 0), 0.6, SLATE, int(sx * 3 + sz * 7 + 40), true)
			var col: Color = GEMS[int(sx + 1.0 + (sz + 1.0) * 0.5) % GEMS.size()]
			BiomeBlocks.crystal_cluster(g, Vector3(0.1, 0.35, 0.1), 0.5, 4, int(sx * 5 + sz * 11 + 60), false,
				TileStyle.gem_material(col, 1.2))
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 0.9
			l.omni_range = 2.6
			l.position = Vector3(0, 0.9, 0.4)
			g.add_child(l)
		1:
			g.name = "LanternCrates"
			lantern_post(g, 0.75)
			Props.put(g, RES + "Containers_Crate_Small_Grey.gltf", Vector3(-0.45, 0, 0.35), 20.0, 0.62)
			Biome.flicker_light(holder, p + Vector3(0, 1.2, 0), LAMP, 1.0, 3.2)
		2:
			g.name = "Cart"
			rails(g, 1.5, 0.8)
			cart(g, "stone" if sx < 0 else "Iron", 0.75)
			Biome.flicker_light(holder, p + Vector3(0, 1.0, 0), LAMP, 0.7, 3.0)
