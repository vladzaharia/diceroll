class_name DressFrost
extends RefCounted
## Frostpeak kits (snowbound pines, icy rocks, frozen camp). The terrain, crystals on the
## peaks, frozen ponds and mist stay in BiomeBlocks._frost().
##  trees (kit(1)): 0 frosted Halloween pines, 1 teal firs, 2 pale snags + tiered pines;
##  sides (kit(1)): 0 lanterns + crystals + snowman, 1 frozen supply camp, 2 frozen battlefield;
##  set pieces (kit(0)): 0 crystal altar (BiomeBlocks), 1 frozen greatsword, 2 ice spire;
##  moat corners (kit(2)): 0 crystals, 1 snowy crates, 2 icy rocks.

const H := Props.HAL
const F := Dressing.FOREST
const RES := Dressing.RES
const SNOW := Color(0.78, 0.85, 0.97, 0.62)    ## snowy re-tint for rocks / wood
const ICE := Color(0.62, 0.84, 1.0, 0.8)
const FROSTED := Color(0.82, 0.9, 1.0)
const PINE := Color(0.36, 0.52, 0.62)


static func _tree(x: float, z: float, k: float, idx: int) -> Node3D:
	var n: Node3D = null
	match Dressing.kit(1):
		0:
			var path: String = H + ["tree_pine_yellow_large.gltf", "tree_pine_orange_large.gltf", "tree_pine_yellow_medium.gltf"][idx % 3]
			n = Dressing.place_near(path, x, z, k)
			if n:
				Props.tint(n, PINE.lerp(FROSTED, 0.2 + 0.2 * float(idx % 3)), 0.92)
		1:
			var name: String = Dressing.pick(["Tree_5_A", "Tree_5_B", "Tree_5_D", "Tree_4_A"])
			n = Dressing.place_near(F + name + "_Color4.gltf", x, z, k * 0.75)
			if n:
				Props.tint(n, Color(0.5, 0.7, 0.8).lerp(FROSTED, 0.3 * float(idx % 3)), 0.55)
		2:
			if idx % 2 == 0:
				var name: String = Dressing.pick(["Tree_Bare_1_B", "Tree_Bare_2_A", "Tree_Bare_2_B"])
				n = Dressing.place_near(F + name + "_Color5.gltf", x, z, k * 0.85)
			else:
				var name: String = Dressing.pick(["Tree_4_A", "Tree_4_B"])
				n = Dressing.place_near(F + name + "_Color4.gltf", x, z, k * 0.72)
				if n:
					Props.tint(n, Color(0.55, 0.72, 0.8), 0.5)
	if n:
		n.name = "FrostPine"
	return n


static func _rock(x: float, z: float, k: float, tall := false) -> Node3D:
	var name: String = Dressing.pick(["Rock_1_D", "Rock_1_E", "Rock_1_G", "Rock_6_D", "Rock_6_E"] if tall
		else ["Rock_1_A", "Rock_1_B", "Rock_6_B", "Rock_6_C", "Rock_2_B"])
	return Dressing.place_near(F + name + "_Color1.gltf", x, z, k, 1.0, SNOW)


static func dress(d: Node3D) -> void:
	var e := Dressing.extent
	var h := Dressing.half
	# back peaks: a row of pines between icy rock spires
	var n := 8
	for i in n:
		var x := lerpf(-h + 1.2, h - 1.2, float(i) / float(n - 1)) + Dressing.rng.randf_range(-0.4, 0.4)
		var z := -h + 1.2 + 0.4 * float(i % 2)
		if i % 3 == 2:
			_rock(x, z, Dressing.rng.randf_range(0.7, 0.95), true)
		else:
			_tree(x, z, 1.05 + Dressing.rng.randf_range(-0.1, 0.15), i)
	for side in [-1.0, 1.0]:
		_tree(side * (h - 1.4), -e * 0.62, 1.0, 1)
		_tree(side * (h - 1.2), e * 0.3, 0.9, 2)
		_tree(side * (h - 1.3), e * 0.95, 0.85, 3)
		_rock(side * (h - 1.1), -e * 0.1, 0.75, true)
		_rock(side * (e + 1.0), e * 0.75, 0.6)
	_sides(d)
	# front: low snowy boulder clusters and drifts of pebbles (nothing tall on the camera side)
	for i in 5:
		var x := lerpf(-h + 1.8, h - 1.8, float(i) / 4.0) + Dressing.rng.randf_range(-0.6, 0.6)
		var name: String = Dressing.pick(["Rock_5_E", "Rock_5_G", "Rock_5_F", "Rock_5_D"])
		Dressing.place_near(F + name + "_Color1.gltf", x, Dressing.rng.randf_range(e + 1.2, h - 1.2), 0.5, 1.0, SNOW)
	# snowy pebbles and frozen grass
	Dressing.scatter([F + "Rock_5_A_Color1.gltf", F + "Rock_5_B_Color1.gltf", F + "Rock_6_A_Color1.gltf"],
		int(26 * Dressing.s), "all", Vector2(0.7, 1.2), SNOW)
	Dressing.scatter([F + "Grass_2_A_Color4.gltf", F + "Grass_2_B_Color4.gltf"], int(22 * Dressing.s), "border",
		Vector2(0.5, 0.75), Color(0.75, 0.86, 0.9, 0.55))


static func _sides(d: Node3D) -> void:
	var e := Dressing.extent
	var x0 := e + 1.1
	for side in [-1.0, 1.0]:
		var face: float = -90.0 * side
		match Dressing.kit(1):
			0:
				var c := Dressing.group("Crystals", side * x0, -e * 0.3, 0.6)
				if c:
					BiomeBlocks.crystal_cluster(c, Vector3.ZERO, 0.75, 5, int(side * 9 + 30))
				var l := Dressing.try_place(H + "lantern_standing.gltf", side * (x0 - 0.3), e * 0.15, 0.0, 0.85)
				if l:
					Biome.flicker_light(d, l.position + Vector3(0, 0.75, 0), Color(1.0, 0.72, 0.4), 1.2, 3.6).set_meta("prescaled", true)
				if side < 0.0 and Dressing.fits(side * x0, e * 0.6, 0.5, 1.2):
					Dressing.occupy(side * x0, e * 0.6, 0.5)
					var sm := BiomeBlocks.snowman(d, Vector3(side * x0, Dressing.gy(side * x0, e * 0.6), e * 0.6), 30.0, 0.95)
					sm.set_meta("prescaled", true)
			1:
				var g := _group(side * x0, -e * 0.45, 1.0, face)
				if g:
					DressBits.supplies(g, int(Dressing.pick([0, 1])), 0.8, SNOW)
				Dressing.try_place(RES + "Wood_Log_Stack.gltf", side * (x0 + 0.2), e * 0.05, face, 0.6, SNOW)
				var l := Dressing.try_place(H + "lantern_standing.gltf", side * (x0 - 0.4), e * 0.35, 0.0, 0.85)
				if l:
					Biome.flicker_light(d, l.position + Vector3(0, 0.75, 0), Color(1.0, 0.72, 0.4), 1.3, 3.8).set_meta("prescaled", true)
				Dressing.try_place(Props.DUN + "barrel_small.gltf", side * x0, e * 0.65, 0.0, 0.6, SNOW)
			2:
				var g := _group(side * x0, -e * 0.4, 0.9, face)
				if g:
					DressBits.bone_pile(g, 0.85, null, Color(0.78, 0.86, 0.95, 0.5))
				var st := _group(side * (x0 + 0.2), e * 0.1, 0.5, face)
				if st:
					Dressing.stuck(st, Dressing.WX + "sword_C.gltf", Vector3(0, 0.3, 0), 20.0, 10.0, 0.9, ICE)
					Dressing.stuck(st, Dressing.WX + "shield_D.gltf", Vector3(0.35, 0.45, 0.35), -20.0, -25.0, 0.6, SNOW)
				var c := Dressing.group("Crystals", side * (x0 - 0.1), e * 0.55, 0.5)
				if c:
					BiomeBlocks.crystal_cluster(c, Vector3.ZERO, 0.55, 4, int(side * 9 + 31), false)


static func _group(x: float, z: float, r: float, yaw: float) -> Node3D:
	if not Dressing.fits(x, z, r, 1.3):
		return null
	var g := Dressing.group("Vignette", x, z, r)
	g.rotation.y = deg_to_rad(yaw)
	return g


# --- set pieces ---------------------------------------------------------------------------------

## Set piece 1: a giant frozen greatsword driven into a snow mound, crystals growing round it.
static func sword(c: Node3D) -> void:
	# a stepped stone plinth capped with snow
	var y := 0.0
	for i in 3:
		var k: float = [2.1, 1.5, 1.0][i]
		var hgt: float = [0.34, 0.3, 0.26][i]
		var b := BiomeBlocks.block(c, "stone" if i < 2 else "snow", Vector3(0, y + hgt * 0.5, 0), 1.0, 30.0 * i)
		b.scale = Vector3(k, hgt, k) * 0.5
		y += hgt
	var blade := Dressing.stuck(c, Dressing.WX + "sword_E.gltf", Vector3(0.0, y + 0.6, 0.0), 15.0, 4.0, 1.0)
	blade.name = "Greatsword"
	Props.tint(blade, Color(0.45, 0.72, 1.0), 0.55, Color(0.1, 0.35, 0.7))
	BiomeBlocks.crystal_cluster(c, Vector3(0.45, y, 0.3), 0.55, 5, 311)
	BiomeBlocks.crystal_cluster(c, Vector3(-0.5, y, -0.25), 0.45, 4, 312, false)
	for p in [Vector3(-1.9, 0, 1.2), Vector3(1.9, 0, -1.3), Vector3(-1.7, 0, -1.6), Vector3(1.8, 0, 1.5)]:
		var r := Props.put(c, F + "Rock_6_C_Color1.gltf", p, p.x * 40.0, 0.6)
		Props.tint(r, Color(SNOW.r, SNOW.g, SNOW.b), SNOW.a)
	var ring := Biome._rune_circle(Color(0.45, 0.85, 1.0), 2.6)
	ring.position = Vector3(0, 0.04, 0)
	c.add_child(ring)
	Biome.flicker_light(c, Vector3(0, 2.4, 1.2), Color(0.5, 0.85, 1.0), 2.2, 6.0)
	var motes := Fx.elite_sparkle(c, Vector3(0, 1.4, 0), 1.0, 2.6)
	(motes.process_material as ParticleProcessMaterial).color = Color(0.7, 0.95, 1.0)


## Set piece 2: a tall icy rock spire in a ring of lanterns and small crystals.
static func spire(c: Node3D) -> void:
	var sp := Props.put(c, F + "Rock_1_O_Color1.gltf", Vector3(0, 0, -0.2), 20.0, 0.7)
	sp.name = "Spire"
	Props.tint(sp, Color(0.8, 0.9, 1.0), 0.75)
	var base := Props.put(c, F + "Rock_1_E_Color1.gltf", Vector3(0.9, 0, 0.3), -40.0, 0.62)
	Props.tint(base, Color(SNOW.r, SNOW.g, SNOW.b), SNOW.a)
	BiomeBlocks.crystal_cluster(c, Vector3(-0.75, 0.0, 0.55), 0.62, 5, 321)
	BiomeBlocks.crystal_cluster(c, Vector3(0.1, 1.9, 0.2), 0.45, 3, 322, false)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var p := Vector3(cos(a) * 2.1, 0, sin(a) * 1.9)
		Props.put(c, H + "lantern_standing.gltf", p, 0.0, 0.8)
		Biome.flicker_light(c, p + Vector3(0, 0.7, 0), Color(1.0, 0.72, 0.4), 0.9, 3.0)
	var ring := Biome._rune_circle(Color(0.45, 0.85, 1.0), 2.5)
	ring.position = Vector3(0, 0.04, 0)
	(ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.6)
	c.add_child(ring)
	Biome.flicker_light(c, Vector3(0, 2.8, 1.2), Color(0.5, 0.85, 1.0), 1.8, 6.0)


# --- moat corners -------------------------------------------------------------------------------

static func corner(holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> void:
	match Dressing.kit(2):
		0:
			BiomeBlocks.crystal_cluster(holder, p, 0.72, 4)
			BiomeBlocks.rock(holder, p + Vector3(-sx * 0.7, 0, sz * 0.1), 0.34, Color(0.92, 0.95, 1.0))
		1:
			var g := Node3D.new()
			g.name = "Crates"
			g.position = p
			g.rotation.y = deg_to_rad(yaw + 30.0)
			holder.add_child(g)
			DressBits.supplies(g, 0, 0.55, SNOW)
			var l := Props.put(holder, H + "lantern_standing.gltf", p + Vector3(-sx * 0.75, 0, -sz * 0.3), 0.0, 0.7)
			l.name = "Lantern"
			Biome.flicker_light(holder, p + Vector3(-sx * 0.75, 0.6, -sz * 0.3), Color(1.0, 0.72, 0.4), 1.0, 3.0)
		2:
			var r := Props.put(holder, F + "Rock_6_D_Color1.gltf", p, yaw, 0.6)
			Props.tint(r, Color(SNOW.r, SNOW.g, SNOW.b), SNOW.a)
			var r2 := Props.put(holder, F + "Rock_5_C_Color1.gltf", p + Vector3(-sx * 0.7, 0, sz * 0.15), yaw, 0.6)
			Props.tint(r2, Color(SNOW.r, SNOW.g, SNOW.b), SNOW.a)
			BiomeBlocks.crystal_cluster(holder, p + Vector3(sx * 0.1, 0, -sz * 0.65), 0.42, 3, 44, false)
