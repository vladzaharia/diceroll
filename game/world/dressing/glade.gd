class_name DressGlade
extends RefCounted
## Verdant Glade kits (Forest Nature trees / bushes / rocks, woodcutter and harvest props).
## Called by BiomeBlocks._glade() after the terrain; see Dressing for the rules.
##
## Palettes (Dressing.kit(1)): 0 meadow (round broadleaves + firs), 1 pinewood (deep-green
## firs and tiered pines), 2 sunny edge (lime umbrella trees with a few golden ones).
## Side vignettes follow the same kit: picnic spot, woodcutter's pile, berry harvest.
## Set pieces (kit(0)): 0 blossom oak + standing stones + campfire, 1 woodcutter's clearing,
## 2 standing-stone spring. Moat corners (kit(2)): bushes + flowers, log piles, cairns.

const F := Dressing.FOREST

## [trees (broad), trees (tall/pine), bush colour, accent colour, grass colour]
const PALETTES := [
	{"broad": ["Tree_1_A", "Tree_1_B", "Tree_7_A", "Tree_3_A"], "tall": ["Tree_5_A", "Tree_5_B", "Tree_5_D"],
		"c_broad": [1, 1, 3], "c_tall": [2], "bush": [1, 3], "bushes": ["Bush_1_C", "Bush_1_D", "Bush_3_B", "Bush_1_E"]},
	{"broad": ["Tree_1_A", "Tree_2_A", "Tree_6_A"], "tall": ["Tree_4_A", "Tree_4_B", "Tree_5_B", "Tree_5_E"],
		"c_broad": [3, 1], "c_tall": [2, 2, 4], "bush": [2, 1], "bushes": ["Bush_4_B", "Bush_4_C", "Bush_4_D", "Bush_1_C"]},
	{"broad": ["Tree_7_A", "Tree_7_B", "Tree_3_B", "Tree_1_B"], "tall": ["Tree_6_A", "Tree_6_B", "Tree_5_A"],
		"c_broad": [3, 3, 1, 5], "c_tall": [1, 3], "bush": [3, 1], "bushes": ["Bush_3_A", "Bush_3_B", "Bush_1_C", "Bush_1_D"]},
]


static func tree_path(name: String, color: int) -> String:
	return F + "%s_Color%d.gltf" % [name, color]


static func dress(root: Node3D, d: Node3D, c: Node3D) -> void:
	var pal: Dictionary = PALETTES[Dressing.kit(1)]
	var e := Dressing.extent
	var h := Dressing.half
	# back row on the hills: two staggered rows of trees
	var n := 9
	for i in n:
		var t := float(i) / float(n - 1)
		var x := lerpf(-h + 1.2, h - 1.2, t) + Dressing.rng.randf_range(-0.5, 0.5)
		var z := -h + 1.3 + Dressing.rng.randf_range(-0.3, 0.6)
		_tree(pal, x, z, i % 3 != 1, 0.78 + Dressing.rng.randf_range(-0.08, 0.12))
	for i in 5:
		var x := lerpf(-h + 2.6, h - 2.6, float(i) / 4.0) + Dressing.rng.randf_range(-0.6, 0.6)
		_tree(pal, x, -e - 1.2 + Dressing.rng.randf_range(-0.2, 0.2), i % 2 == 0, 0.6)
	# sides: trees toward the back, bushes along the ring, low stuff toward the front
	for side in [-1.0, 1.0]:
		for z in [-e + 0.6, -e * 0.45, -0.4]:
			_tree(pal, side * (h - 1.3 + Dressing.rng.randf_range(-0.3, 0.2)), z + Dressing.rng.randf_range(-0.6, 0.6),
				Dressing.chance(0.5), 0.62 + Dressing.rng.randf_range(0.0, 0.14))
		for z in [-e * 0.7, -e * 0.1, e * 0.35, e * 0.8]:
			_bush(pal, side * (e + 0.9 + Dressing.rng.randf_range(0.0, 1.2)), z + Dressing.rng.randf_range(-0.8, 0.8), 0.55)
		for z in [e * 0.55, e * 0.95]:
			var r: String = F + Dressing.pick(["Rock_2_B", "Rock_5_C", "Rock_5_D", "Rock_6_C"]) + "_Color1.gltf"
			Dressing.place_in(r, Rect2(side * (e + 2.4) - 1.0, z - 0.8, 2.0, 1.6), Dressing.rng.randf_range(0.55, 0.8))
	_side_vignettes(Dressing.kit(1))
	# front strip: low bushes and pebble clusters (no tall stuff on the camera side)
	for i in 6:
		var x := lerpf(-h + 1.6, h - 1.6, float(i) / 5.0) + Dressing.rng.randf_range(-0.6, 0.6)
		var z := Dressing.rng.randf_range(e + 1.0, h - 0.9)
		if i % 2 == 0:
			var b: String = F + Dressing.pick(["Bush_1_B", "Bush_1_C", "Bush_1_E", "Bush_1_C"]) + "_Color%d.gltf" % int(Dressing.pick(pal.bush))
			Dressing.try_place(b, x, z, Dressing.rng.randf() * 360.0, Dressing.rng.randf_range(0.8, 1.1))
		else:
			Dressing.try_place(F + Dressing.pick(["Rock_5_C", "Rock_5_E", "Rock_2_B"]) + "_Color1.gltf", x, z,
				Dressing.rng.randf() * 360.0, Dressing.rng.randf_range(0.45, 0.7))
	# ground: grass clumps and pebbles (MultiMesh)
	var gc := int(Dressing.pick(pal.bush))
	Dressing.scatter([F + "Grass_1_B_Color%d.gltf" % gc, F + "Grass_1_C_Color%d.gltf" % gc, F + "Grass_2_B_Color%d.gltf" % gc,
		F + "Grass_2_C_Color%d.gltf" % gc], int(60 * Dressing.s * Dressing.s), "border", Vector2(0.55, 0.9))
	Dressing.scatter([F + "Grass_1_A_Color%d.gltf" % gc, F + "Grass_1_B_Color%d.gltf" % gc], int(26 * Dressing.s), "moat",
		Vector2(0.5, 0.75))
	Dressing.scatter([F + "Rock_5_A_Color1.gltf", F + "Rock_5_B_Color1.gltf", F + "Rock_2_A_Color1.gltf"],
		int(28 * Dressing.s), "border", Vector2(0.7, 1.3))


static func _tree(pal: Dictionary, x: float, z: float, broad: bool, k: float) -> Node3D:
	var name: String = Dressing.pick(pal.broad if broad else pal.tall)
	var col: int = Dressing.pick(pal.c_broad if broad else pal.c_tall)
	return Dressing.place_near(tree_path(name, col), x, z, k, 1.3)


static func _bush(pal: Dictionary, x: float, z: float, k: float) -> Node3D:
	var b := F + String(Dressing.pick(pal.bushes)) + "_Color%d.gltf" % int(Dressing.pick(pal.bush))
	return Dressing.try_place(b, x, z, Dressing.rng.randf() * 360.0, k)


## One vignette per side, mid-way down (on the flat meadow just outside the ring).
static func _side_vignettes(k: int) -> void:
	var e := Dressing.extent
	for side in [-1.0, 1.0]:
		var x: float = side * (e + 1.9)
		var z := Dressing.rng.randf_range(-e * 0.15, e * 0.25)
		if not Dressing.fits(x, z, 1.1, 0.9):
			continue
		var g := Dressing.group("Vignette", x, z, 1.2)
		g.rotation.y = deg_to_rad(90.0 * side + Dressing.rng.randf_range(-15.0, 15.0))
		match k:
			0:
				Props.put(g, Props.HAL + "bench.gltf", Vector3(0, 0, 0), 0.0, 0.62)
				Props.put(g, Dressing.RES + "Food_Basket_A_Berries.gltf", Vector3(0.9, 0, 0.45), 30.0, 0.7)
				Props.put(g, Props.DUN + "barrel_small.gltf", Vector3(-1.0, 0, 0.3), 30.0, 0.55)
				Props.put(g, Dressing.RES + "Food_Apple_Red.gltf", Vector3(0.55, 0.2, 0.75), 0.0, 0.6)
			1:
				Props.put(g, Dressing.WOOD + "log_stacks.gltf", Vector3(-0.3, 0, 0), 0.0, 0.5)
				var stump := Props.put(g, Dressing.WOOD + "log_A.gltf", Vector3(0.75, 0.3, 0.35), 0.0, 0.6)
				stump.scale.y = 0.3
				Dressing.stuck(g, Dressing.WOOD + "axe.gltf", Vector3(0.75, 0.62, 0.35), 40.0, -25.0, 0.62)
				Props.put(g, Dressing.RES + "Wood_Log_A.gltf", Vector3(0.1, 0.18, 0.9), 70.0, 0.55)
			2:
				Props.put(g, Dressing.RES + "Food_Crate_Large_Apples.gltf", Vector3(-0.35, 0, 0), 10.0, 0.75)
				Props.put(g, Dressing.RES + "Food_Basket_B_Berries.gltf", Vector3(0.6, 0, 0.3), -20.0, 0.7)
				Props.put(g, Dressing.RES + "Food_Crate_Small_Berries.gltf", Vector3(-0.2, 0.6, 0.0), 30.0, 0.7)
				Props.put(g, Dressing.RES + "Food_Flour.gltf", Vector3(0.45, 0, -0.45), 0.0, 0.8)
		Props.set_shadows(g, true)


# --- set pieces ---------------------------------------------------------------------------------

## Set piece 1: woodcutter's clearing (chopping stump + axe, log pile, a young tree, lantern).
static func clearing(c: Node3D) -> void:
	var col := int(Dressing.pick([1, 3]))
	var t := Props.put(c, tree_path("Tree_1_B", col), Vector3(0.35, 0, -0.9), 30.0, 0.62)
	t.name = "Tree"
	Props.put(c, F + "Bush_1_D_Color%d.gltf" % col, Vector3(-0.9, 0, -1.3), 0.0, 0.8)
	Props.put(c, Dressing.WOOD + "log_stacks.gltf", Vector3(-1.35, 0, -0.1), 60.0, 0.55)
	var stump := Props.put(c, Dressing.WOOD + "log_B.gltf", Vector3(0.3, 0.26, 0.85), 0.0, 1.0)
	stump.scale.y = 0.48
	stump.name = "Stump"
	Dressing.stuck(c, Dressing.WOOD + "axe.gltf", Vector3(0.3, 0.7, 0.85), 20.0, -28.0, 0.9)
	for i in 3:
		Props.put(c, Dressing.WOOD + "log_split.gltf", Vector3(0.95 + 0.18 * i, 0.1, 1.2 - 0.05 * i), 90.0 + i * 12.0, 0.8) \
			.rotation.z = deg_to_rad(90.0)
	Props.put(c, Dressing.RES + "Wood_Log_Stack.gltf", Vector3(1.4, 0, -0.35), -70.0, 0.55)
	var lamp := Props.put(c, Props.HAL + "lantern_standing.gltf", Vector3(-0.7, 0, 1.2), 0.0, 0.9)
	lamp.name = "Lantern"
	Biome.flicker_light(c, Vector3(-0.7, 0.8, 1.3), Color(1.0, 0.7, 0.35), 1.4, 4.0)
	var fl := BiomeBlocks.flower_patch(c, Vector3(0.0, 0.0, 0.0), 2.0, 14)
	fl.name = "Flowers"
	var halo := Biome._rune_circle(Color(1.0, 0.85, 0.45), 2.6)
	halo.position = Vector3(0, 0.03, 0)
	(halo.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.35)
	c.add_child(halo)


## Set piece 2: a ring of standing stones around a spring pool with an umbrella tree.
static func spring(c: Node3D) -> void:
	var pool := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 1.05
	cy.bottom_radius = 0.95
	cy.height = 0.06
	cy.radial_segments = 14
	cy.rings = 1
	pool.mesh = cy
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.62, 0.78, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = Color(0.2, 0.45, 0.55)
	m.emission_energy_multiplier = 0.35
	pool.material_override = m
	pool.position = Vector3(0.1, 0.03, 0.3)
	pool.name = "Spring"
	c.add_child(pool)
	for i in 9:
		var a := TAU * float(i) / 9.0
		var p := Vector3(cos(a) * 1.3, 0, sin(a) * 1.1 + 0.3)
		Props.put(c, F + ["Rock_5_B", "Rock_5_C", "Rock_2_B"][i % 3] + "_Color1.gltf", p, a * 57.0, 0.55 + 0.1 * (i % 2))
	var tree := Props.put(c, tree_path("Tree_3_B", int(Dressing.pick([1, 3]))), Vector3(-0.9, 0, -0.9), 20.0, 0.62)
	tree.name = "Tree"
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.4
		var p := Vector3(cos(a) * 2.25, 0, sin(a) * 2.1)
		if p.z > 1.4 and absf(p.x) < 1.0:
			continue
		var st := Props.put(c, F + ["Rock_4_B", "Rock_4_C", "Rock_4_A"][i % 3] + "_Color1.gltf", p, -a * 57.0, 0.5)
		st.name = "Stone"
	Props.put(c, F + "Grass_2_C_Color1.gltf", Vector3(1.2, 0, -0.6), 0.0, 0.8)
	Props.put(c, F + "Grass_2_B_Color3.gltf", Vector3(-1.3, 0, 0.9), 0.0, 0.8)
	Props.put(c, F + "Bush_1_C_Color1.gltf", Vector3(1.0, 0, -1.4), 0.0, 0.7)
	var fl := BiomeBlocks.flower_patch(c, Vector3(0.0, 0.0, 0.3), 2.2, 14)
	fl.name = "Flowers"
	var motes := Fx.elite_sparkle(c, Vector3(0.1, 0.3, 0.3), 1.0, 2.0)
	(motes.process_material as ParticleProcessMaterial).color = Color(0.7, 1.0, 0.9)
	Biome.flicker_light(c, Vector3(0.1, 1.0, 0.8), Color(0.55, 0.9, 1.0), 1.2, 4.0)


# --- moat corners -------------------------------------------------------------------------------

static func corner(holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> void:
	var pal: Dictionary = PALETTES[Dressing.kit(1)]
	var col := int(pal.bush[0])
	match Dressing.kit(2):
		0:
			var b := Props.put(holder, F + "Bush_1_D_Color%d.gltf" % col, p + Vector3(-sx * 0.15, 0, -sz * 0.1), yaw, 0.9)
			b.name = "Bush"
			var f := BiomeBlocks.flower_patch(holder, p, 1.0, 9)
			f.name = "Flowers"
			Props.put(holder, F + "Rock_5_C_Color1.gltf", p + Vector3(-sx * 0.75, 0, sz * 0.05), yaw, 0.55)
		1:
			var g := Node3D.new()
			g.name = "Logs"
			g.position = p
			g.rotation.y = deg_to_rad(yaw)
			holder.add_child(g)
			Props.put(g, Dressing.RES + "Wood_Log_A.gltf", Vector3(0, 0.2, 0), 0.0, 0.7)
			Props.put(g, Dressing.RES + "Wood_Log_B.gltf", Vector3(0.35, 0.16, 0.2), 20.0, 0.7)
			Props.put(g, Dressing.RES + "Wood_Log_B.gltf", Vector3(0.15, 0.5, 0.1), 10.0, 0.62)
			Props.put(g, F + "Grass_2_B_Color%d.gltf" % col, Vector3(-0.6, 0, 0.1), 0.0, 0.7)
			var f := BiomeBlocks.flower_patch(holder, p + Vector3(-sx * 0.5, 0, sz * 0.3), 0.6, 6)
			f.name = "Flowers"
		2:
			Props.put(holder, F + "Rock_5_H_Color1.gltf", p, yaw, 0.45).name = "Cairn"
			Props.put(holder, F + "Bush_4_B_Color%d.gltf" % col, p + Vector3(-sx * 0.7, 0, sz * 0.1), yaw, 0.7)
			Props.put(holder, F + "Grass_2_C_Color%d.gltf" % col, p + Vector3(sx * 0.1, 0, -sz * 0.6), yaw, 0.6)
			var f := BiomeBlocks.flower_patch(holder, p + Vector3(-sx * 0.2, 0, -sz * 0.2), 0.8, 7)
			f.name = "Flowers"
