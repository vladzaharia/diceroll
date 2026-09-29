class_name DressHollow
extends RefCounted
## Hollow kits (autumn / harvest / graveyard). The frame (dirt floor, back fence and gate,
## side fences, lantern posts, front broken fences) stays in Biome._hollow().
##  trees (kit(1)): 0 Halloween autumn pines, 1 orange / gold broadleaves, 2 bare snags;
##  sides (kit(1)): 0 graveyard, 1 harvest stores, 2 battlefield remains;
##  set pieces (kit(0)): 0 haunted tree + graves (Biome), 1 harvest bonfire, 2 fallen giant;
##  moat corners (kit(2)): 0 jack-o'-lanterns, 1 apple baskets, 2 skeleton remains.

const H := Props.HAL
const F := Dressing.FOREST
const RES := Dressing.RES

## The Biome._hollow() tree spots (authored 7x7 coords) and their size.
const SPOTS := [
	[Vector3(-9.0, 0, -9.4), 1.0], [Vector3(-4.8, 0, -10.0), 1.1], [Vector3(-1.0, 0, -10.2), 1.0],
	[Vector3(3.2, 0, -9.6), 1.0], [Vector3(6.4, 0, -10.0), 1.0], [Vector3(9.6, 0, -8.6), 0.95],
	[Vector3(-9.8, 0, -4.4), 0.9], [Vector3(9.8, 0, -3.6), 0.9], [Vector3(-9.4, 0, 1.0), 1.0],
	[Vector3(9.6, 0, 1.6), 1.0], [Vector3(-9.3, 0, 7.0), 0.9], [Vector3(9.4, 0, 8.0), 0.9],
]


## The tree line (final coords, prescaled).
static func trees(d: Node3D) -> void:
	var k := Dressing.kit(1)
	for i in SPOTS.size():
		var at: Vector3 = SPOTS[i][0]
		var sz: float = SPOTS[i][1]
		var front := at.z > 5.0
		var p := Vector3(at.x * Dressing.s + Dressing.rng.randf_range(-0.3, 0.3), 0, at.z * Dressing.s + Dressing.rng.randf_range(-0.3, 0.3))
		var path := ""
		var scale := sz
		match k:
			0:
				path = H + ["tree_pine_orange_large.gltf", "tree_dead_large.gltf", "tree_pine_yellow_large.gltf",
					"tree_pine_orange_medium.gltf", "tree_dead_large_decorated.gltf", "tree_pine_yellow_large.gltf",
					"tree_pine_orange_medium.gltf", "tree_pine_yellow_medium.gltf", "tree_dead_medium.gltf",
					"tree_pine_orange_small.gltf", "tree_pine_yellow_small.gltf", "tree_pine_orange_small.gltf"][i]
			1:
				var name: String = Dressing.pick(["Tree_5_B", "Tree_5_A", "Tree_1_B", "Tree_5_E", "Tree_2_A"] if not front else ["Tree_5_A", "Tree_1_A"])
				path = F + "%s_Color%d.gltf" % [name, int(Dressing.pick([6, 6, 5]))]
				scale = sz * (0.78 if not front else 0.62)
				if name == "Tree_5_E":
					scale *= 0.75
			2:
				if i % 3 == 1:
					path = H + String(Dressing.pick(["tree_dead_large.gltf", "tree_dead_medium.gltf"]))
				else:
					var name: String = Dressing.pick(["Tree_Bare_1_B", "Tree_Bare_1_C", "Tree_Bare_2_B"] if not front else ["Tree_Bare_1_A", "Tree_Bare_1_B"])
					path = F + "%s_Color%d.gltf" % [name, int(Dressing.pick([1, 2]))]
					scale = sz * 0.8
		if front:
			# the camera-side corners frame the board: keep them small
			scale = minf(scale, 0.8 if k == 0 else 0.5)
		Dressing.place(path, p, Dressing.rng.randf() * 360.0, scale)
	# autumn ground cover under the trees (orange bushes, leaf piles)
	var bush_col := 6 if k != 2 else 5
	for side in [-1.0, 1.0]:
		for z in [-Dressing.extent * 0.8, -Dressing.extent * 0.1, Dressing.extent * 0.6]:
			Dressing.place_in(F + String(Dressing.pick(["Bush_1_C", "Bush_1_D", "Bush_3_A"])) + "_Color%d.gltf" % bush_col,
				Rect2(side * (Dressing.extent + 0.6) - (1.6 if side < 0 else 0.0), z - 0.8, 1.6, 1.6), 0.6)


## Side kits (between the ring and the side fences; final coords).
static func sides(d: Node3D) -> void:
	var e := Dressing.extent
	var x0 := e + 1.0
	for side in [-1.0, 1.0]:
		var face: float = -90.0 * side
		match Dressing.kit(1):
			0:  # graveyard
				Dressing.try_place(H + "grave_A.gltf", side * (x0 + 0.5), -e * 0.72, face, 0.8)
				Dressing.try_place(H + "gravestone.gltf", side * (x0 + 0.3), e * 0.42, face, 0.8)
				Dressing.try_place(H + "gravemarker_B.gltf", side * (x0 + 0.9), -e * 0.2, face + 15.0, 0.9)
				Dressing.try_place(H + "candle_melted.gltf", side * (x0 - 0.2), -e * 0.35, 0.0, 1.0)
				Dressing.try_place(H + "grave_A_destroyed.gltf", side * (x0 + 0.6), e * 0.08, face, 0.7)
			1:  # harvest stores
				Dressing.try_place(RES + "Food_Crate_Large_Apples.gltf", side * (x0 + 0.2), -e * 0.7, face, 0.8)
				Dressing.try_place(RES + "Food_Pile_Medium.gltf", side * (x0 + 0.5), -e * 0.25, face, 0.7)
				Dressing.try_place(H + "pumpkin_orange.gltf", side * (x0 - 0.1), e * 0.08, Dressing.rng.randf() * 360.0, 0.7)
				Dressing.try_place(RES + "Wood_Log_Stack.gltf", side * (x0 + 0.6), e * 0.42, face, 0.62)
				Dressing.try_place(RES + "Food_Basket_A_Berries.gltf", side * (x0 - 0.2), -e * 0.45, 0.0, 0.7)
			2:  # battlefield remains
				var g := _group(side * (x0 + 0.2), -e * 0.55, 0.9)
				if g:
					DressBits.bone_pile(g, 0.85)
				var n := Dressing.try_place(Dressing.SKP + "Skeleton_Shield_Large_B.gltf", side * (x0 + 0.5), -e * 0.1, face, 0.8)
				if n:
					n.rotation.x = deg_to_rad(-65.0)
					n.position.y += 0.25
				var st := _group(side * (x0 + 0.3), e * 0.3, 0.5)
				if st:
					Dressing.stuck(st, Dressing.SKP + "Skeleton_Blade.gltf", Vector3(0, 0.25, 0), face, 12.0, 0.9)
					Dressing.stuck(st, Dressing.SKP + "Skeleton_Arrow.gltf", Vector3(0.4, 0.15, 0.3), 30.0, 25.0, 0.9)
				Dressing.try_place(H + "skull.gltf", side * (x0 - 0.2), e * 0.05, face, 0.4)
	# leaf litter and small pumpkins on the ground
	Dressing.scatter([F + "Rock_5_A_Color1.gltf", F + "Rock_5_B_Color1.gltf", F + "Rock_2_A_Color1.gltf"],
		int(22 * Dressing.s), "border", Vector2(0.7, 1.1), Color(0.55, 0.45, 0.42, 0.6))
	Dressing.scatter([F + "Grass_1_B_Color6.gltf", F + "Grass_1_C_Color5.gltf", F + "Grass_2_B_Color6.gltf"],
		int(30 * Dressing.s), "all", Vector2(0.5, 0.8))


## Low clutter on the front strip (between the ring and the broken front fences).
static func front() -> void:
	var fill := func(g: Node3D, i: int) -> void:
		match Dressing.kit(1):
			0:
				Props.put(g, H + ["gravemarker_A.gltf", "candle_melted.gltf", "pumpkin_yellow_small.gltf"][i % 3], Vector3.ZERO, 0.0, 0.62)
				Props.put(g, F + "Grass_2_B_Color6.gltf", Vector3(0.4, 0, 0.2), 0.0, 0.6)
			1:
				Props.put(g, RES + ["Food_Crate_Small_Berries.gltf", "Food_Basket_B_Berries.gltf", "Food_Apple_Red.gltf"][i % 3],
					Vector3.ZERO, 0.0, 0.8)
				Props.put(g, H + "pumpkin_orange_small.gltf", Vector3(0.5, 0, 0.25), 30.0, 0.8)
			2:
				Props.put(g, H + "skull.gltf", Vector3.ZERO, Dressing.rng.randf() * 360.0, 0.35)
				Dressing.stuck(g, Dressing.SKP + "Skeleton_Arrow.gltf", Vector3(0.45, 0.15, 0.2), 30.0, 22.0, 0.9)
				Props.put(g, H + "bone_A.gltf", Vector3(-0.35, 0.05, 0.3), 60.0, 0.7)
	Dressing.front_row(fill, 4, 0.7)


static func _group(x: float, z: float, r: float) -> Node3D:
	if not Dressing.fits(x, z, r, 1.2):
		return null
	var g := Dressing.group("Vignette", x, z, r)
	g.rotation.y = Dressing.rng.randf() * TAU
	return g


# --- set pieces ---------------------------------------------------------------------------------

## Set piece 1: a harvest bonfire ringed by pumpkins, apple crates and a log pile.
static func bonfire(c: Node3D) -> void:
	var fire := TileStyle.make_prop("campfire")
	fire.scale = Vector3.ONE * 1.9
	fire.position = Vector3(0, 0, 0.1)
	c.add_child(fire)
	Biome.flame(c, Vector3(0, 0.3, 0.1), Color(1.0, 0.55, 0.15), 0.8, 14)
	var sm := BiomeBlocks.smoke(c, Vector3(0, 1.3, 0.1), 0.9, Color(0.3, 0.24, 0.26, 0.4))
	sm.name = "Smoke"
	Props.put(c, Dressing.WOOD + "log_stacks.gltf", Vector3(-1.5, 0, -0.9), 40.0, 0.6)
	Props.put(c, RES + "Food_Crate_Large_Apples.gltf", Vector3(1.5, 0, -0.9), -30.0, 0.9)
	Props.put(c, RES + "Food_Crate_Small_Berries.gltf", Vector3(1.55, 0.62, -0.95), -10.0, 0.8)
	Props.put(c, RES + "Food_Pile_Small.gltf", Vector3(1.6, 0, 0.6), 0.0, 0.8)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var p := Vector3(cos(a) * 2.0, 0, sin(a) * 1.8)
		if absf(p.x) > 1.2 and p.z < 0.0:
			continue
		var big := i % 3 == 0
		Props.put(c, H + ("pumpkin_orange_jackolantern.gltf" if big else ["pumpkin_orange_small.gltf", "pumpkin_yellow_small.gltf"][i % 2]),
			p, rad_to_deg(-a) + 90.0, 0.6 if big else 0.9)
	Props.put(c, Dressing.WOOD + "log_A.gltf", Vector3(-1.05, 0.2, 0.9), 0.0, 0.9).rotation = Vector3(0, deg_to_rad(60.0), PI * 0.5)
	Props.put(c, Dressing.WOOD + "log_B.gltf", Vector3(1.0, 0.2, 1.0), 0.0, 0.9).rotation = Vector3(0, deg_to_rad(-60.0), PI * 0.5)
	Biome.flicker_light(c, Vector3(0, 1.4, 0.6), Color(1.0, 0.55, 0.2), 3.0, 7.0)


## Set piece 2: a fallen giant: a huge skeleton axe driven into a grave mound, shields,
## bones and grave lanterns around it.
static func giant(c: Node3D) -> void:
	Props.put(c, H + "floor_dirt_grave.gltf", Vector3(0.0, -0.49, 0.0), 0.0, 0.6)
	# head buried in the mound, the long haft slanting up
	var axe := Dressing.stuck(c, Dressing.SKP + "Skeleton_Golem_Axe_Large.gltf", Vector3(0.1, 2.15, -0.3), 25.0, 0.0, 1.1)
	axe.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(25.0), PI)
	axe.name = "GiantAxe"
	var skull := Props.put(c, H + "skull.gltf", Vector3(-0.75, 0.0, 0.55), 30.0, 1.0)
	skull.name = "Skull"
	Props.put(c, H + "ribcage.gltf", Vector3(0.75, 0.35, 0.4), -20.0, 1.25)
	Props.put(c, H + "bone_C.gltf", Vector3(-0.2, 0.1, 1.2), 70.0, 1.2)
	Props.put(c, H + "bone_A.gltf", Vector3(1.4, 0.1, -0.5), 10.0, 1.2)
	var sh := Dressing.stuck(c, Dressing.SKP + "Skeleton_Shield_Large_A.gltf", Vector3(-1.4, 0.45, -0.6), 40.0, -20.0, 1.1)
	sh.name = "Shield"
	Dressing.lying(c, Dressing.SKP + "Skeleton_Shield_Small_B.gltf", Vector3(1.3, 0, 1.0), 20.0, 0.9)
	for p in [Vector3(-2.0, 0, 1.3), Vector3(2.0, 0, 1.2), Vector3(-1.9, 0, -1.6), Vector3(2.0, 0, -1.5)]:
		Props.put(c, H + "gravemarker_A.gltf", p, rad_to_deg(atan2(p.x, p.z)) + 180.0, 0.8)
	Props.put(c, H + "lantern_standing.gltf", Vector3(-0.4, 0, 1.7), 0.0, 0.9)
	Biome.flicker_light(c, Vector3(-0.4, 0.8, 1.9), Color(1.0, 0.6, 0.25), 1.8, 5.0)
	Props.put(c, H + "candle_triple.gltf", Vector3(0.7, 0, 1.6), 0.0, 1.0)
	var mist := Biome._rune_circle(Color(0.5, 1.0, 0.6), 2.4)
	mist.position = Vector3(0, 0.05, 0)
	(mist.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.5)
	c.add_child(mist)
	Biome.flicker_light(c, Vector3(0.0, 2.2, 0.8), Color(0.55, 1.0, 0.65), 1.4, 5.0)


# --- moat corners -------------------------------------------------------------------------------

static func corner(holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> void:
	match Dressing.kit(2):
		0:
			Props.put(holder, H + "pumpkin_orange_jackolantern.gltf", p, yaw, 0.62)
			Props.put(holder, H + "gravemarker_A.gltf", p + Vector3(-sx * 0.2, 0, -sz * 0.75), yaw + 10.0, 0.7)
			Props.put(holder, H + "pumpkin_yellow_small.gltf", p + Vector3(-sx * 0.7, 0, sz * 0.1), yaw, 0.7)
			Biome.flicker_light(holder, p + Vector3(0, 0.7, 0), Color(1.0, 0.5, 0.15), 1.2, 3.2)
		1:
			Props.put(holder, RES + "Food_Basket_A_Berries.gltf", p, yaw, 0.8)
			Props.put(holder, RES + "Food_Crate_Small_Berries.gltf", p + Vector3(-sx * 0.65, 0, sz * 0.1), yaw + 20.0, 0.9)
			Props.put(holder, H + "pumpkin_orange_small.gltf", p + Vector3(-sx * 0.1, 0, -sz * 0.7), yaw, 0.9)
			Props.put(holder, RES + "Food_Apple_Red.gltf", p + Vector3(sx * 0.1, 0.18, sz * 0.5), 0.0, 0.7)
			Props.put(holder, H + "lantern_standing.gltf", p + Vector3(-sx * 0.8, 0, -sz * 0.6), yaw, 0.7)
			Biome.flicker_light(holder, p + Vector3(-sx * 0.8, 0.6, -sz * 0.6), Color(1.0, 0.6, 0.25), 1.0, 3.0)
		2:
			var g := Node3D.new()
			g.name = "Remains"
			g.position = p
			g.rotation.y = deg_to_rad(yaw)
			holder.add_child(g)
			DressBits.bone_pile(g, 0.75)
			var a := Dressing.stuck(holder, Dressing.SKP + "Skeleton_Arrow.gltf", p + Vector3(-sx * 0.7, 0.2, sz * 0.2), yaw, 22.0, 1.0)
			a.name = "Arrow"
			Props.put(holder, H + "candle_melted.gltf", p + Vector3(-sx * 0.3, 0, -sz * 0.75), yaw, 0.9)
			Biome.flame(holder, p + Vector3(-sx * 0.3, 0.55, -sz * 0.75), Color(1.0, 0.6, 0.25), 0.14, 4)
