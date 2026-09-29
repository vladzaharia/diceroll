class_name DressWarcamp
extends RefCounted
## Orc Warcamp kits (docs/design/2026-09-29-new-biomes.md §3). Frame (BiomeBlocks): churned mud,
## a raised bank at the back, late-afternoon sun through smoke, drifting ash. Here: the palisade of
## sharpened stakes round the back and sides with its gate towers, war banners on poles, campfires
## with smoke plumes, then the seeded kits:
##  set pieces (kit(0)): 0 the great war drum on a log platform, 1 the warchief's tent with a
##                       trophy totem, 2 the fighting pit (a ring of skull stakes round a war totem);
##  sides (kit(1)): 0 tents, 1 supply depot (barrels, crates, bedding), 2 weapon racks + dummies;
##  moat corners (kit(2)): 0 a campfire with log seats, 1 a banner pole and barrels, 2 a skull stake
##                       and dropped weapons.

const D := Props.DUN
const RES := Dressing.RES
const ORC := Dressing.ORC
const WOOD_D := Props.K + "mystery/woodcutter/"
const SKP := Dressing.SKP
const WX := Dressing.WX
const WOOD := Color(0.46, 0.31, 0.19)
const STAKE := Color(0.52, 0.36, 0.22)
const FIRE := Color(1.0, 0.55, 0.2)
const SMOKE := Color(0.32, 0.27, 0.26, 0.55)
## Tent cloths: blood red, hide brown, bone.
const CLOTHS := [Color(0.62, 0.14, 0.1), Color(0.5, 0.36, 0.24), Color(0.84, 0.78, 0.64)]
## Banners by kit(1) (colour, pattern): the camp's war colours.
const BANNERS := [["red", "patternB"], ["brown", "triple"], ["red", "triple"]]


static func dress(root: Node3D, d: Node3D, c: Node3D) -> void:
	var e := Dressing.extent
	var h := Dressing.half
	var s := Dressing.s
	# the palisade: sharpened stakes along the back and down the sides, with a gate in the middle
	var bz := -e - 1.7
	_palisade(d, Vector3(-e - 0.9, 0, bz), Vector3(-1.9, 0, bz))
	_palisade(d, Vector3(1.9, 0, bz), Vector3(e + 0.9, 0, bz))
	for side in [-1.0, 1.0]:
		_palisade(d, Vector3(side * (h - 0.9), 0, -h + 1.0), Vector3(side * (h - 0.9), 0, e * 0.35))
		_palisade(d, Vector3(side * (h - 0.9), 0, bz), Vector3(side * (e + 0.9), 0, bz))
	_gate(d, bz)
	# banners on poles along the back rise and the sides
	var ban: Array = BANNERS[Dressing.kit(1)]
	for p in [Vector2(-e * 0.8, -e - 1.4), Vector2(e * 0.8, -e - 1.4), Vector2(-e - 1.5, -e * 0.3), Vector2(e + 1.5, -e * 0.3)]:
		banner_pole(d, p.x, p.y, String(ban[0]), String(ban[1]))
	# campfires with smoke plumes on both sides
	for side in [-1.0, 1.0]:
		var z := e * Dressing.rng.randf_range(0.1, 0.45)
		_campfire(d, side * (e + 1.6 + Dressing.rng.randf_range(0.0, 0.6)), z)
	_sides(Dressing.kit(1))
	_front()
	Dressing.scatter([Dressing.FOREST + "Rock_5_A_Color1.gltf", Dressing.FOREST + "Rock_5_B_Color1.gltf",
		RES + "Wood_Plank_A.gltf"], int(26 * s * s), "border", Vector2(0.4, 0.8), Color(0.45, 0.38, 0.32, 0.6))
	Dressing.scatter([Props.HAL + "bone_A.gltf", Props.HAL + "bone_B.gltf", Props.HAL + "bone_C.gltf"], int(10 * s), "all",
		Vector2(0.5, 0.8), Color(0.85, 0.8, 0.7, 0.4))
	BiomeBlocks.scatter_tufts(d, Color(0.62, 0.52, 0.26), int(70 * s * s))
	match Dressing.kit(0):
		0:
			great_drum(c)
		1:
			chief_tent(c)
		2:
			fighting_pit(c)


# --- building blocks --------------------------------------------------------------------------------

static var _stake_mesh: ArrayMesh


## One sharpened stake (log + point), unit height 1, base at y = 0.
static func stake_mesh() -> ArrayMesh:
	if _stake_mesh:
		return _stake_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.13
	cm.bottom_radius = 0.15
	cm.height = 0.82
	cm.radial_segments = 6
	cm.rings = 1
	st.append_from(BiomeBlocks.solid(cm, STAKE, 0.01, 3, STAKE.darkened(0.35)), 0, Transform3D(Basis(), Vector3(0, 0.41, 0)))
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.13
	tip.height = 0.2
	tip.radial_segments = 6
	tip.rings = 1
	st.append_from(BiomeBlocks.solid(tip, Color(0.72, 0.58, 0.4)), 0, Transform3D(Basis(), Vector3(0, 0.92, 0)))
	_stake_mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	_stake_mesh.surface_set_material(0, m)
	return _stake_mesh


## A row of sharpened stakes from `a` to `b` (final x/z; y follows the terrain), lashed with a
## rail, as one MultiMesh.
static func _palisade(d: Node3D, a: Vector3, b: Vector3) -> void:
	var len := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	if len < 0.5:
		return
	var n := int(len / 0.3)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = stake_mesh()
	mm.instance_count = n
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var p := a.lerp(b, t)
		var y := Dressing.gy(p.x, p.z)
		var hgt := Dressing.rng.randf_range(1.9, 2.4)
		var tilt := Basis().rotated(Vector3.UP, Dressing.rng.randf() * TAU).rotated(Vector3(1, 0, 0), Dressing.rng.randf_range(-0.05, 0.05))
		mm.set_instance_transform(i, Transform3D(tilt.scaled(Vector3(1.0, hgt, 1.0)), Vector3(p.x, y - 0.05, p.z)))
		Dressing.occupy(p.x, p.z, 0.2)
	var mi := MultiMeshInstance3D.new()
	mi.name = "Palisade"
	mi.multimesh = mm
	mi.set_meta("prescaled", true)
	d.add_child(mi)


## The gate: two lookout towers of stakes with a skull on each, the gap between them open.
static func _gate(d: Node3D, bz: float) -> void:
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.55
		var g := Dressing.group("GateTower", x, bz, 0.6)
		for k in 4:
			var a := TAU * float(k) / 4.0 + 0.4
			var mi := MeshInstance3D.new()
			mi.mesh = stake_mesh()
			mi.scale = Vector3(1.2, 3.2, 1.2)
			mi.position = Vector3(cos(a) * 0.28, -0.05, sin(a) * 0.28)
			g.add_child(mi)
		var deck := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(1.0, 0.12, 1.0)
		deck.mesh = BiomeBlocks.solid(bx, WOOD, 0.01, 9)
		deck.position.y = 2.5
		g.add_child(deck)
		var sk := Props.put(g, Props.HAL + "skull.gltf", Vector3(0, 2.56, 0.2), sx * -15.0, 0.42)
		sk.name = "Skull"
		Biome.flame(g, Vector3(sx * 0.35, 2.75, 0.3), FIRE, 0.3, 6)
		Biome.flicker_light(d, g.position + Vector3(0, 2.6, 0.8), FIRE, 1.3, 5.0).set_meta("prescaled", true)


## A war banner on a tall pole with a crossbar (colour "red" | "brown" | ..., pattern "patternB" |
## "triple" | "thin").
static func banner_pole(d: Node3D, x: float, z: float, color: String, pattern: String) -> void:
	if not Dressing.fits(x, z, 0.5, 3.0):
		return
	var g := Dressing.group("Banner", x, z, 0.5)
	g.rotation.y = deg_to_rad(Dressing.rng.randf_range(-15.0, 15.0))
	banner(g, color, pattern, 1.0)


## Pole + crossbar + banner at a group origin (k = size).
static func banner(g: Node3D, color: String, pattern: String, k := 1.0) -> void:
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.07
	cm.height = 3.0
	cm.radial_segments = 6
	pole.mesh = BiomeBlocks.solid(cm, WOOD, 0.01, 11)
	pole.position.y = 1.5
	pole.scale = Vector3.ONE * k
	pole.position *= k
	g.add_child(pole)
	var bar := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(1.0, 0.07, 0.07)
	bar.mesh = BiomeBlocks.solid(bx, WOOD, 0.004, 12)
	bar.position = Vector3(0, 2.8, 0.06) * k
	bar.scale = Vector3.ONE * k
	g.add_child(bar)
	var file := "banner_%s_%s.gltf" % [pattern, color] if pattern != "" else "banner_%s.gltf" % color
	var bn := Props.put(g, D + file, Vector3(0, 2.84 * k - 3.7 * 0.3 * k, 0.08 * k), 0.0, 0.3 * k)
	bn.name = "Banner"
	if pattern == "triple":
		bn.scale.x *= 0.62
	var sk := Props.put(g, Props.HAL + "skull.gltf", Vector3(0, 3.0 * k, 0.04), 0.0, 0.2 * k)
	sk.name = "PoleSkull"


## A campfire (the tile prop, bigger) with log seats and a smoke plume.
static func _campfire(d: Node3D, x: float, z: float) -> void:
	if not Dressing.fits(x, z, 0.9, 1.0):
		return
	var g := Dressing.group("Campfire", x, z, 0.9)
	fire_ring(g)
	BiomeBlocks.smoke(d, g.position + Vector3(0, 0.8, 0), 1.2, SMOKE).set_meta("prescaled", true)


## Campfire + two log seats at a group origin.
static func fire_ring(g: Node3D) -> void:
	var f := TileStyle.make_prop("campfire")
	f.scale = Vector3.ONE * 1.2
	g.add_child(f)
	BiomeBlocks.log_seat(g, Vector3(-0.85, 0, 0.35), 70.0)
	BiomeBlocks.log_seat(g, Vector3(0.8, 0, -0.45), -60.0)


## An A-frame hide tent (cloth colour, size k) facing +z at a group origin, with its poles and a
## darker door flap.
static func tent(g: Node3D, cloth: Color, k := 1.0) -> Node3D:
	var n := Node3D.new()
	n.name = "Tent"
	n.scale = Vector3.ONE * k
	g.add_child(n)
	# two sloped hide panels meeting at the ridge
	for sx in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.06, 1.5, 1.9)
		panel.mesh = BiomeBlocks.solid(bx, cloth.darkened(0.32 if sx > 0 else 0.0), 0.02, 13 + int(sx))
		panel.position = Vector3(sx * 0.42, 0.62, 0)
		panel.rotation.z = sx * deg_to_rad(34.0)
		n.add_child(panel)
	var door := MeshInstance3D.new()
	var dm := PrismMesh.new()
	dm.size = Vector3(0.62, 0.8, 0.02)
	door.mesh = BiomeBlocks.solid(dm, cloth.darkened(0.55))
	door.position = Vector3(0, 0.4, 0.96)
	n.add_child(door)
	for z in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.045
		cm.height = 1.55
		cm.radial_segments = 5
		pole.mesh = BiomeBlocks.solid(cm, WOOD)
		pole.position = Vector3(0, 0.78, z * 0.98)
		n.add_child(pole)
	# hide patches and a painted stripe
	var stripe := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.9, 0.08, 1.92)
	stripe.mesh = sb
	stripe.material_override = Props.flat_material(Color(0.86, 0.8, 0.66) if cloth.r < 0.7 else Color(0.62, 0.14, 0.1))
	stripe.position = Vector3(0.43, 0.62, 0)
	stripe.rotation.z = deg_to_rad(-55.0)
	n.add_child(stripe)
	return n


## A training dummy: a post with a straw-stuffed sack and a crossbar.
static func dummy(g: Node3D, k := 1.0) -> void:
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.06
	cm.height = 1.4
	cm.radial_segments = 5
	post.mesh = BiomeBlocks.solid(cm, WOOD)
	post.position.y = 0.7 * k
	post.scale = Vector3.ONE * k
	g.add_child(post)
	var sack := MeshInstance3D.new()
	sack.mesh = BiomeBlocks.solid(BiomeBlocks._sphere(0.26, 7, 4), Color(0.78, 0.66, 0.42), 0.04, 21, Color(0.6, 0.5, 0.3),
		Vector3(1.0, 1.35, 1.0))
	sack.position.y = 1.05 * k
	sack.scale = Vector3.ONE * k
	g.add_child(sack)
	var arm := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.8, 0.07, 0.07)
	arm.mesh = BiomeBlocks.solid(bx, WOOD)
	arm.position.y = 1.15 * k
	arm.scale = Vector3.ONE * k
	g.add_child(arm)
	var head := MeshInstance3D.new()
	head.mesh = BiomeBlocks.solid(BiomeBlocks._sphere(0.14, 6, 4), Color(0.78, 0.66, 0.42), 0.02, 22)
	head.position.y = 1.5 * k
	head.scale = Vector3.ONE * k
	g.add_child(head)


# --- sides and front ----------------------------------------------------------------------------------

static func _sides(kit: int) -> void:
	var e := Dressing.extent
	for side in [-1.0, 1.0]:
		var x: float = side * (e + 2.0)
		var face: float = -90.0 * side
		match kit:
			0:  # tents
				var tx: float = side * (e + 1.35)
				for z in [-e * 0.55, e * 0.3]:
					var zz: float = z + Dressing.rng.randf_range(-0.4, 0.4)
					if Dressing.fits(tx, zz, 0.8, 1.6):
						var g := Dressing.group("Tent", tx, zz, 0.8)
						g.rotation.y = deg_to_rad(face + Dressing.rng.randf_range(-12.0, 12.0))
						tent(g, CLOTHS[int(absf(zz)) % CLOTHS.size()], 0.72)
				Dressing.place_near(RES + "Textiles_Stack_Large_Colored.gltf", x - side * 0.3, e * 0.85, 0.5, 0.8)
			1:  # supply depot
				Dressing.place_near(RES + "Food_Barrel_Fish.gltf", x, -e * 0.5, 0.55, 1.0)
				Dressing.place_near(RES + "Food_Barrel_Empty.gltf", x + side * 0.4, -e * 0.2, 0.55, 1.0)
				Dressing.place_near(RES + "Containers_Crate_Medium_Wood.gltf", x, e * 0.35, 0.65, 1.0)
				Dressing.place_near(RES + "Textiles_Stack_Large.gltf", x, e * 0.8, 0.5, 0.8)
				Dressing.place_near(RES + "Wood_Log_Stack.gltf", x + side * 0.3, -e * 0.85, 0.6, 0.8)
			2:  # weapon racks and training dummies
				var g := Dressing.group("Rack", side * (e + 1.3), -e * 0.45, 0.9)
				g.rotation.y = deg_to_rad(face)
				DressBits.weapon_rack(g, 0.95, 0)
				for z in [e * 0.2, e * 0.6]:
					var zz: float = z + Dressing.rng.randf_range(-0.3, 0.3)
					if Dressing.fits(side * (e + 1.3), zz, 0.5, 1.7):
						var dg := Dressing.group("Dummy", side * (e + 1.3), zz, 0.5)
						dg.rotation.y = deg_to_rad(face)
						dummy(dg, 1.0)
				Dressing.place_near(D + "sword_shield.gltf", x + side * 0.2, e * 0.9, 0.4, 0.8)


## Front strip: packs, horns, logs and a barrel (all low).
static func _front() -> void:
	var fill := func(g: Node3D, i: int) -> void:
		match (i + Dressing.kit(1)) % 4:
			0:
				Props.put(g, ORC + "Orc_Backpack.gltf.glb", Vector3(0, 0.25, 0), 0.0, 0.55)
				Dressing.lying(g, ORC + "Orc_DrinkingHorn.gltf.glb", Vector3(0.5, 0, 0.2), 40.0, 0.7)
			1:
				Props.put(g, RES + "Wood_Log_A.gltf", Vector3(0, 0.1, 0), 20.0, 0.5)
				Props.put(g, RES + "Wood_Log_B.gltf", Vector3(0.3, 0.1, 0.35), -30.0, 0.45)
			2:
				Props.put(g, RES + "Food_Barrel_Empty.gltf", Vector3.ZERO, 0.0, 0.42)
				Dressing.lying(g, ORC + "Orc_Axe.gltf.glb", Vector3(0.5, 0, 0.1), 60.0, 0.8)
			3:
				Props.put(g, RES + "Textiles_A.gltf", Vector3.ZERO, 0.0, 0.7)
				Props.put(g, Props.HAL + "skull.gltf", Vector3(0.45, 0, 0.1), 30.0, 0.3)
	Dressing.front_row(fill, 5, 0.7)


# --- set pieces ----------------------------------------------------------------------------------------

## A low log platform (a raft of logs with a plank deck) of radius r; returns the deck height.
static func _platform(c: Node3D, r: float) -> float:
	for i in 5:
		var z := -r + (float(i) + 0.5) * r * 2.0 / 5.0
		var lg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.2
		cm.height = r * 2.0 * (0.9 + 0.1 * float(i % 2))
		cm.radial_segments = 7
		lg.mesh = BiomeBlocks.solid(cm, WOOD.lightened(0.04 * (i % 2)), 0.01, 70 + i)
		lg.rotation.z = PI * 0.5
		lg.position = Vector3(0, 0.2, z)
		c.add_child(lg)
	var deck := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(r * 1.7, 0.08, r * 1.8)
	deck.mesh = BiomeBlocks.solid(bx, Color(0.58, 0.42, 0.28), 0.01, 79)
	deck.position.y = 0.44
	c.add_child(deck)
	return 0.48


## Set piece 0: the great war drum (Orc_Wardrum at 3x) on a log platform, crossed beaters, log and
## plank stacks, a war banner each side and fire bowls. It thumps on the rally.
static func great_drum(c: Node3D) -> void:
	var y := _platform(c, 1.45)
	var drum := Props.put(c, ORC + "Orc_Wardrum.gltf.glb", Vector3(0, y, -0.1), 15.0, 1.75)
	drum.name = "GreatDrum"
	var st1 := Props.put(c, ORC + "Orc_WardrumStick.gltf.glb", Vector3(-0.5, y + 1.85, 0.3), 0.0, 1.6)
	st1.rotation = Vector3(0.2, 0.3, deg_to_rad(40.0))
	var st2 := Props.put(c, ORC + "Orc_WardrumStick.gltf.glb", Vector3(0.5, y + 1.85, 0.3), 0.0, 1.6)
	st2.rotation = Vector3(0.2, -0.3, deg_to_rad(-40.0))
	Props.put(c, RES + "Wood_Log_Stack.gltf", Vector3(-1.75, 0, 0.75), 30.0, 0.62)
	Props.put(c, RES + "Wood_Planks_Stack_Large.gltf", Vector3(1.75, 0, 0.8), -25.0, 0.55)
	for sx in [-1.0, 1.0]:
		var g := Node3D.new()
		g.position = Vector3(sx * 1.7, 0, -1.25)
		c.add_child(g)
		banner(g, "red", "patternB", 0.85)
		var bz := Props.put(c, D + "torch_lit.gltf", Vector3(sx * 1.25, y, 1.0), 0.0, 0.9)
		bz.name = "FireBowl"
		Biome.flame(c, Vector3(sx * 1.25, y + 0.7, 1.0), FIRE, 0.32, 7)
	Biome.flicker_light(c, Vector3(0, 2.6, 1.4), FIRE, 2.2, 6.0)
	var t := drum.create_tween().set_loops()
	t.tween_interval(1.6)
	t.tween_property(drum, "scale", Vector3(1.85, 1.62, 1.85), 0.06)
	t.tween_property(drum, "scale", Vector3.ONE * 1.75, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Set piece 1: the warchief's tent: a big red tent on a rug with the trophy totem (a stake of
## skulls and a shield) before it, weapon racks and a brazier.
static func chief_tent(c: Node3D) -> void:
	var rug := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(3.4, 0.04, 2.8)
	rug.mesh = BiomeBlocks.solid(bx, Color(0.46, 0.14, 0.1), 0.0, 3)
	rug.position = Vector3(0, 0.02, 0.1)
	c.add_child(rug)
	var tg := Node3D.new()
	tg.position = Vector3(0, 0, -0.55)
	c.add_child(tg)
	var t := tent(tg, CLOTHS[0], 1.55)
	t.name = "ChiefTent"
	for sx in [-1.0, 1.0]:
		var g := Node3D.new()
		g.position = Vector3(sx * 1.7, 0, -0.9)
		c.add_child(g)
		banner(g, "brown" if sx < 0 else "red", "triple", 0.8)
	_totem(c, Vector3(0.95, 0, 1.2), 0.8)
	var rk := Node3D.new()
	rk.position = Vector3(-1.2, 0, 1.15)
	rk.rotation.y = 0.35
	c.add_child(rk)
	DressBits.weapon_rack(rk, 0.7, 0)
	Props.put(c, ORC + "Orc_Backpack.gltf.glb", Vector3(1.6, 0.26, 0.2), -40.0, 0.5)
	var bz := Props.put(c, D + "torch_lit.gltf", Vector3(0, 0, 1.5), 0.0, 1.0)
	bz.name = "Brazier"
	Biome.flame(c, Vector3(0, 0.78, 1.5), FIRE, 0.35, 8)
	Biome.flicker_light(c, Vector3(0, 1.6, 1.9), FIRE, 2.0, 5.5)


## A trophy totem: a tall stake with skulls, horns and a shield lashed on.
static func _totem(c: Node3D, pos: Vector3, k := 1.0) -> void:
	var g := Node3D.new()
	g.name = "Totem"
	g.position = pos
	c.add_child(g)
	var mi := MeshInstance3D.new()
	mi.mesh = stake_mesh()
	mi.scale = Vector3(1.1, 2.6, 1.1) * k
	g.add_child(mi)
	for i in 3:
		var sk := Props.put(g, Props.HAL + "skull.gltf", Vector3(0.05 * (i % 2), (0.8 + 0.55 * i) * k, 0.12 * k), 0.0,
			(0.3 - 0.04 * i) * k)
		sk.rotation.y = deg_to_rad(-20.0 + 20.0 * i)
	Dressing.stuck(g, ORC + "Orc_DrinkingHorn.gltf.glb", Vector3(0.18, 2.1 * k, 0.05), 90.0, 0.0, 0.8 * k)
	var sh := Props.put(g, SKP + "Skeleton_Shield_Large_A.gltf", Vector3(0, 1.1 * k, -0.16 * k), 0.0, 0.7 * k)
	sh.name = "Shield"


## Set piece 2: the fighting pit: a ring of skull stakes around the war totem, trampled mud,
## weapons in the dirt and two fire posts.
static func fighting_pit(c: Node3D) -> void:
	var ring := Biome._rune_circle(Color(1.0, 0.35, 0.18), 2.7)
	ring.position = Vector3(0, 0.03, 0)
	(ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.35)
	c.add_child(ring)
	var n := 12
	for i in n:
		var a := TAU * float(i) / float(n)
		if absf(sin(a) - 1.0) < 0.12:
			continue    # an opening toward the camera
		var mi := MeshInstance3D.new()
		mi.mesh = stake_mesh()
		mi.scale = Vector3(1.0, 1.3 + 0.2 * float(i % 3), 1.0)
		mi.position = Vector3(cos(a) * 2.15, -0.05, sin(a) * 2.15)
		c.add_child(mi)
		if i % 3 == 0:
			Props.put(c, Props.HAL + "skull.gltf", Vector3(cos(a) * 2.15, 1.3 + 0.2 * float(i % 3), sin(a) * 2.15),
				rad_to_deg(-a) + 90.0, 0.26)
	_totem(c, Vector3(0, 0, -0.2), 1.1)
	Dressing.stuck(c, ORC + "Orc_Axe.gltf.glb", Vector3(-0.8, 0.35, 0.6), 30.0, 25.0, 0.9)
	Dressing.stuck(c, ORC + "Orc_Club.gltf.glb", Vector3(0.9, 0.4, 0.4), -40.0, -20.0, 0.9)
	Dressing.lying(c, SKP + "Skeleton_Shield_Small_A.gltf", Vector3(0.5, 0, 1.0), 20.0, 0.7)
	for sx in [-1.0, 1.0]:
		var bz := Props.put(c, D + "torch_lit.gltf", Vector3(sx * 1.2, 0, -1.2), 0.0, 1.0)
		bz.name = "FirePost"
		Biome.flame(c, Vector3(sx * 1.2, 0.78, -1.2), FIRE, 0.35, 8)
	Biome.flicker_light(c, Vector3(0, 2.0, 1.2), FIRE, 2.2, 6.0)


# --- moat corners -----------------------------------------------------------------------------------

static func corner(holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> void:
	var g := Node3D.new()
	g.position = p
	g.rotation.y = deg_to_rad(yaw)
	holder.add_child(g)
	match Dressing.kit(2):
		0:
			g.name = "Campfire"
			fire_ring(g)
			g.scale = Vector3.ONE * 0.8
		1:
			g.name = "BannerBarrels"
			banner(g, "red" if sx < 0 else "brown", "thin", 0.6)
			Props.put(g, RES + "Food_Barrel_Empty.gltf", Vector3(0.5, 0, 0.3), 0.0, 0.42)
			Props.put(g, D + "barrel_small.gltf", Vector3(-0.4, 0, 0.45), 0.0, 0.45)
			Biome.flicker_light(holder, p + Vector3(0, 1.2, 0), FIRE, 0.8, 3.0)
		2:
			g.name = "SkullStake"
			var mi := MeshInstance3D.new()
			mi.mesh = stake_mesh()
			mi.scale = Vector3(1.0, 1.5, 1.0)
			g.add_child(mi)
			Props.put(g, Props.HAL + "skull.gltf", Vector3(0, 1.45, 0.05), 0.0, 0.3)
			Dressing.lying(g, ORC + "Orc_Club.gltf.glb", Vector3(0.5, 0, 0.3), 40.0, 0.7)
			Dressing.lying(g, SKP + "Skeleton_Shield_Small_B.gltf", Vector3(-0.45, 0, 0.35), -30.0, 0.6)
			Biome.flicker_light(holder, p + Vector3(0, 1.0, 0), FIRE, 0.6, 3.0)
