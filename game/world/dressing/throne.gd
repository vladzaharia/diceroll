class_name DressThrone
extends RefCounted
## Bone Throne kits (violet night, royal tomb). The frame (tiled floor, back fence + arch,
## decorated pillars) stays in Biome._throne().
##  sides (kit(1)): 0 coffins + skull posts, 1 war trophies, 2 royal hall (banners + pillars);
##  set pieces (kit(0)): 0 mausoleum (Biome), 1 bone throne, 2 fallen king's statue;
##  moat corners (kit(2)): 0 skull candles, 1 skeleton weapon barrels, 2 bone piles.

const D := Props.DUN
const H := Props.HAL
const SKP := Dressing.SKP
## Violet tint for banners / cloth (alpha = strength).
const VIOLET := Color(0.46, 0.3, 0.72, 0.8)
const BONE := Color(0.9, 0.86, 0.78, 0.75)


static func sides(d: Node3D) -> void:
	var e := Dressing.extent
	var x0 := e + 1.0
	var k := Dressing.kit(1)
	for side in [-1.0, 1.0]:
		var face: float = -90.0 * side
		# the trees at the back corners (dead oaks, or pale snags)
		var tp := H + "tree_dead_large.gltf" if k != 1 else Dressing.FOREST + "Tree_Bare_2_B_Color5.gltf"
		var tree := Dressing.place(tp, Vector3(side * 9.5 * Dressing.s, 0, -6.4 * Dressing.s), side * 40.0, 1.0 if k != 1 else 0.85)
		if k == 1:
			Props.tint(tree, Color(0.62, 0.58, 0.72), 0.7)
		match k:
			0:
				Dressing.try_place(H + "post_skull.gltf", side * (x0 - 0.3), -e * 0.4, 0.0, 1.0)
				Dressing.try_place(H + "coffin_decorated.gltf", side * (x0 + 0.3), e * 0.08, 90.0, 0.8)
				Dressing.try_place(D + "pillar.gltf", side * (x0 + 0.8), e * 0.5, 0.0, 0.8)
				Dressing.try_place(H + "shrine_candles.gltf", side * (x0 + 0.3), -e * 0.95, 0.0, 0.9)
			1:
				var r := _group(side * (x0 + 0.2), -e * 0.55, 1.0, face)
				if r:
					DressBits.weapon_rack(r, 1.0, 1)
				var b := _group(side * (x0 + 0.1), e * 0.05, 0.6, face)
				if b:
					DressBits.weapon_barrel(b, 1.0, true)
				var sh := Dressing.try_place(H + "post.gltf", side * (x0 + 0.6), e * 0.45, face, 0.8)
				if sh:
					var shield := Props.put(sh, SKP + "Skeleton_Shield_Large_A.gltf", Vector3(0, 2.2, 0.35), 0.0, 1.0)
					shield.name = "Trophy"
				Dressing.try_place(H + "shrine_candles.gltf", side * (x0 + 0.3), -e * 0.95, 0.0, 0.9)
			2:
				Dressing.try_place(D + "pillar_decorated.gltf", side * (x0 + 0.9), -e * 0.72, 0.0, 0.62)
				var ban := Dressing.try_place(D + "banner_triple_white.gltf", side * (x0 + 1.25), -e * 0.2, face, 0.62)
				if ban:
					Props.tint(ban, Color(VIOLET.r, VIOLET.g, VIOLET.b), VIOLET.a)
				Dressing.try_place(D + "pillar_decorated.gltf", side * (x0 + 0.9), e * 0.35, 0.0, 0.62)
				Dressing.try_place(D + "candle_triple.gltf", side * (x0 - 0.2), -e * 0.45, 0.0, 1.0)
				Dressing.try_place(D + "candle_triple.gltf", side * (x0 - 0.2), e * 0.08, 0.0, 1.0)
		# ghostly candle glow for each side
		var cl := Biome.flicker_light(d, Vector3(side * (x0 - 0.2), 1.4, -e * 0.2), Color(0.7, 0.45, 1.0), 1.4, 4.5)
		cl.set_meta("prescaled", true)
	Dressing.scatter([H + "bone_A.gltf", H + "bone_B.gltf", H + "bone_C.gltf"], int(14 * Dressing.s), "border", Vector2(0.6, 0.9))
	Dressing.scatter([Dressing.FOREST + "Rock_5_A_Color1.gltf", Dressing.FOREST + "Rock_5_B_Color1.gltf"], int(18 * Dressing.s),
		"border", Vector2(0.6, 1.0), Color(0.5, 0.48, 0.62, 0.7))


## Low clutter on the front strip.
static func front() -> void:
	var fill := func(g: Node3D, i: int) -> void:
		match Dressing.kit(1):
			0:
				Props.put(g, H + "candle_melted.gltf", Vector3.ZERO, 0.0, 0.9)
				Props.put(g, H + "bone_B.gltf", Vector3(0.45, 0.05, 0.2), 60.0, 0.8)
				Biome.flame(g, Vector3(0, 0.55, 0), Color(0.62, 0.4, 1.0), 0.14, 4)
			1:
				Dressing.lying(g, SKP + ["Skeleton_Blade.gltf", "Skeleton_Axe.gltf", "Skeleton_Crossbow.gltf"][i % 3], Vector3.ZERO,
					Dressing.rng.randf() * 360.0, 0.8)
				Dressing.stuck(g, SKP + "Skeleton_Arrow.gltf", Vector3(0.5, 0.15, 0.3), 30.0, 20.0, 0.9)
				Dressing.stuck(g, SKP + "Skeleton_Arrow_Broken.gltf", Vector3(-0.4, 0.15, 0.35), -40.0, -25.0, 0.9)
			2:
				for j in 3:
					Props.put(g, H + ["candle.gltf", "candle_thin.gltf", "candle_melted.gltf"][j],
						Vector3(0.25 * j - 0.25, 0, 0.18 * (j % 2)), 0.0, 0.8)
				Biome.flame(g, Vector3(-0.25, 0.72, 0.0), Color(0.62, 0.4, 1.0), 0.14, 4)
				Biome.flame(g, Vector3(0.25, 0.55, 0.0), Color(0.62, 0.4, 1.0), 0.12, 4)
	Dressing.front_row(fill, 4, 0.7)


static func _group(x: float, z: float, r: float, yaw: float) -> Node3D:
	if not Dressing.fits(x, z, r, 1.5):
		return null
	var g := Dressing.group("Vignette", x, z, r)
	g.rotation.y = deg_to_rad(yaw)
	return g


# --- set pieces ---------------------------------------------------------------------------------

## Set piece 1: the Bone Throne: a great bone-white chair on a stepped dais, a skull on each
## arm, a huge mace and shield leaning on it, violet banners behind and candles in front.
static func bone_throne(c: Node3D) -> void:
	for i in 2:
		var step := Props.put(c, D + "floor_foundation_allsides.gltf", Vector3(0, -1.55 + 0.35 * i, -0.2 - 0.15 * i), 0.0, 1.0)
		step.scale = Vector3(1.5 - 0.35 * i, 1.0, 1.3 - 0.35 * i)
	var y := 0.45 + 0.35
	var chair := Props.put(c, D + "chair.gltf", Vector3(0, y, -0.45), 0.0, 1.75)
	chair.name = "Throne"
	Props.tint(chair, Color(BONE.r, BONE.g, BONE.b), BONE.a)
	for sx in [-1.0, 1.0]:
		Props.put(c, H + "skull.gltf", Vector3(sx * 0.62, y + 0.95, -0.15), -sx * 20.0, 0.36)
		var b := Props.put(c, D + "banner_thin_white.gltf", Vector3(sx * 1.2, 0.45, -1.35), 0.0, 0.7)
		Props.tint(b, Color(VIOLET.r, VIOLET.g, VIOLET.b), VIOLET.a)
		Props.put(c, H + "skull_candle.gltf", Vector3(sx * 1.35, 0.45, 0.85), -sx * 25.0, 0.7)
		Biome.flame(c, Vector3(sx * 1.35, 1.25, 0.85), Color(0.6, 0.4, 1.0), 0.2, 5)
	var mace := Dressing.stuck(c, SKP + "Skeleton_Mace_Large.gltf", Vector3(0.95, y + 0.6, 0.15), -30.0, -18.0, 0.62)
	mace.name = "Mace"
	Dressing.stuck(c, SKP + "Skeleton_Shield_Large_B.gltf", Vector3(-0.95, y + 0.35, 0.2), 25.0, -16.0, 0.7)
	Props.put(c, H + "ribcage.gltf", Vector3(-0.55, 0.45 + 0.3, 1.0), 20.0, 0.62)
	Props.put(c, H + "bone_C.gltf", Vector3(0.45, 0.5, 1.1), 60.0, 0.8)
	var ring := Biome._rune_circle(Color(0.6, 0.35, 1.0), 2.8)
	ring.position = Vector3(0, 0.08, 0.1)
	c.add_child(ring)
	Biome.flicker_light(c, Vector3(0, 2.4, 1.6), Color(0.65, 0.4, 1.0), 3.0, 6.0)


## Set piece 2: the fallen king: a violet-stone statue over his decorated coffin, crossed
## weapons and a ring of candles.
static func kings_tomb(c: Node3D) -> void:
	var dais := Props.put(c, D + "floor_foundation_allsides.gltf", Vector3(0, -1.55, -0.2), 0.0, 1.0)
	dais.scale = Vector3(1.5, 1.0, 1.4)
	var statue := Props.put(c, Dressing.PAL + "paladin_statue.gltf", Vector3(0, 0.45, -0.85), 0.0, 1.0)
	statue.name = "Statue"
	Props.tint(statue, Color(0.52, 0.5, 0.66), 0.85)
	var coffin := Props.put(c, H + "coffin_decorated.gltf", Vector3(0, 0.45, 0.45), 0.0, 0.55)
	coffin.name = "Coffin"
	Dressing.lying(c, Dressing.WX + "sword_E.gltf", Vector3(0, 0.45 + 0.5, 0.45), 0.0, 0.5)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var p := Vector3(cos(a) * 2.2, 0, sin(a) * 1.9 + 0.1)
		Props.put(c, H + ("candle_triple.gltf" if i % 2 == 0 else "candle_thin.gltf"), p, rad_to_deg(a), 0.9)
		if i % 2 == 0:
			Biome.flame(c, p + Vector3(0, 0.82, 0), Color(0.65, 0.4, 1.0), 0.18, 4)
	var ring := Biome._rune_circle(Color(0.55, 0.4, 1.0), 2.6)
	ring.position = Vector3(0, 0.06, 0.1)
	c.add_child(ring)
	Biome.flicker_light(c, Vector3(0, 2.2, 1.4), Color(0.65, 0.45, 1.0), 2.8, 6.0)


# --- moat corners -------------------------------------------------------------------------------

static func corner(holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> void:
	match Dressing.kit(2):
		0:
			Props.put(holder, H + "skull_candle.gltf", p, yaw, 0.85)
			Props.put(holder, H + "bone_B.gltf", p + Vector3(-sx * 0.6, 0, sz * 0.2), yaw + 40.0, 0.7)
			Biome.flame(holder, p + Vector3(0, 1.15, 0), Color(0.62, 0.4, 1.0), 0.18, 5)
			Biome.flicker_light(holder, p + Vector3(0, 1.3, 0), Color(0.65, 0.4, 1.0), 1.2, 3.2)
		1:
			var g := Node3D.new()
			g.name = "WeaponBarrel"
			g.position = p
			g.rotation.y = deg_to_rad(yaw)
			holder.add_child(g)
			DressBits.weapon_barrel(g, 0.8, true)
			Props.put(holder, H + "candle.gltf", p + Vector3(-sx * 0.65, 0, sz * 0.2), yaw, 0.8)
			Biome.flame(holder, p + Vector3(-sx * 0.65, 0.72, sz * 0.2), Color(0.62, 0.4, 1.0), 0.14, 4)
			Biome.flicker_light(holder, p + Vector3(0, 1.1, 0), Color(0.65, 0.4, 1.0), 0.9, 3.0)
		2:
			var g := Node3D.new()
			g.name = "Bones"
			g.position = p
			g.rotation.y = deg_to_rad(yaw)
			holder.add_child(g)
			DressBits.bone_pile(g, 0.8)
			Props.put(holder, H + "candle_melted.gltf", p + Vector3(-sx * 0.75, 0, -sz * 0.2), yaw, 0.9)
			Biome.flame(holder, p + Vector3(-sx * 0.75, 0.55, -sz * 0.2), Color(0.62, 0.4, 1.0), 0.14, 4)
			Biome.flicker_light(holder, p + Vector3(0, 1.0, 0), Color(0.65, 0.4, 1.0), 0.9, 3.0)
