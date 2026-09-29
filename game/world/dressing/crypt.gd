class_name DressCrypt
extends RefCounted
## The Crypt kits. The frame (tiled floor, arched back wall, side walls, torches, front
## barrier) stays in Biome._crypt(); this adds the seeded parts:
##  banner colour + pattern per run; side kits (kit(1)): 0 storeroom, 1 library, 2 armoury;
##  set pieces (kit(0)): 0 floating d20 dais (Biome), 1 paladin shrine, 2 treasure hoard;
##  moat corners (kit(2)): 0 candle pillars, 1 bone piles, 2 supply crates.

const D := Props.DUN
const DX := Dressing.DX
const COLORS := ["red", "blue", "green", "yellow", "white"]
const STYLES := ["patternA", "patternB", "patternC", "thin", "triple", ""]


## Banner set for this board: [side style, centre style, colour].
static func banners() -> Array:
	var col: String = COLORS[Dressing.rng.randi() % COLORS.size()]
	var side: String = Dressing.pick(["patternA", "patternB", "patternC", "thin"])
	var centre: String = Dressing.pick(["shield", "triple", "shield"])
	return [side, centre, col]


static func banner_path(style: String, col: String) -> String:
	return D + ("banner_%s_%s.gltf" % [style, col] if style != "" else "banner_%s.gltf" % col)


## Side dressing along both walls (final coordinates; walls stand at |x| = 9.9 * s).
static func sides(d: Node3D, col: String) -> void:
	var e := Dressing.extent
	var wall := 9.9 * Dressing.s
	var inner := wall - 0.75
	var k := Dressing.kit(1)
	for side in [-1.0, 1.0]:
		var face: float = 90.0 * side   # +x wall faces -x
		match k:
			0:  # storeroom
				Dressing.try_place(D + "barrel_large.gltf", side * inner, -e * 0.95, 20.0 * side, 0.7)
				var sup := func(g: Node3D) -> void: DressBits.supplies(g, int(Dressing.pick([0, 1, 2])), 0.85)
				_group_at(side * (inner - 0.2), -e * 0.45, 1.1, sup, -face)
				Dressing.try_place(D + "crates_stacked.gltf", side * (inner - 0.1), 0.2, 70.0, 0.62)
				Dressing.try_place(DX + "trunk_large_" + String(Dressing.pick(["A", "B", "C"])) + ".gltf",
					side * (inner - 0.1), e * 0.42, -face, 0.62)
				Dressing.try_place(D + "barrel_small.gltf", side * (inner - 0.2), e * 0.78, 0.0, 0.62)
			1:  # library
				Dressing.try_place(DX + "bookcase_double_decorated" + String(Dressing.pick(["A", "B"])) + ".gltf",
					side * (wall - 0.4), -e * 0.72, -face, 0.62)
				Dressing.try_place(DX + "bookcase_single_decorated" + String(Dressing.pick(["A", "B"])) + ".gltf",
					side * (wall - 0.4), -e * 0.15, -face, 0.62)
				_group_at(side * (inner - 0.4), e * 0.28, 1.0, _study, -face)
				Dressing.try_place(DX + "shelf_small_candles.gltf", side * (wall - 0.35), e * 0.62, -face, 0.62)
				Dressing.try_place(DX + "book_tan.gltf", side * (inner - 0.3), e * 0.82, Dressing.rng.randf() * 360.0, 0.8)
			2:  # armoury
				var rack := func(g: Node3D) -> void: DressBits.weapon_rack(g, 1.0, Dressing.rng.randi() % 3)
				_group_at(side * (inner - 0.15), -e * 0.8, 1.0, rack, -face)
				var barrel := func(g: Node3D) -> void: DressBits.weapon_barrel(g, 1.0, false)
				_group_at(side * (inner - 0.2), -e * 0.25, 0.6, barrel, -face)
				var ws := Props.put(d, D + "sword_shield.gltf", Vector3(side * (wall - 0.3), 1.8, -e * 0.5), -face, 0.7)
				ws.set_meta("prescaled", true)
				_group_at(side * (inner - 0.2), e * 0.3, 0.9, _trunk_shield, -face)
				Dressing.try_place(D + "barrel_small_stack.gltf", side * (inner - 0.3), e * 0.72, 90.0, 0.55)
		# a banner on each side wall (the run's colour)
		var b := Props.put(d, banner_path(String(Dressing.pick(["thin", "patternB", ""])), col),
			Vector3(side * (wall - 0.25), 0.2, -e * 0.62 + 0.2), -face, 0.8)
		b.set_meta("prescaled", true)
	# floor clutter: cracked tiles / pebbles and a few candles near the walls
	Dressing.scatter([Props.K + "forest/Rock_5_A_Color1.gltf", Props.K + "forest/Rock_5_B_Color1.gltf",
		Props.K + "forest/Rock_2_A_Color1.gltf"], int(22 * Dressing.s), "border", Vector2(0.6, 1.0),
		Color(0.55, 0.5, 0.52, 0.7))
	Dressing.scatter([Props.HAL + "bone_A.gltf", Props.HAL + "bone_B.gltf"], int(8 * Dressing.s), "border", Vector2(0.6, 0.8))


## Low clutter on the front strip (between the ring and the front barrier).
static func front() -> void:
	var fill := func(g: Node3D, i: int) -> void:
		match Dressing.kit(1):
			0:
				Props.put(g, Dressing.RES + ["Food_Flour.gltf", "Containers_Box_Small.gltf", "Containers_Crate_Small_Grey.gltf"][i % 3],
					Vector3.ZERO, Dressing.rng.randf() * 360.0, 0.85)
				Props.put(g, Dressing.RES + "Containers_Box_Small.gltf", Vector3(0.5, 0, 0.2), 30.0, 0.7)
			1:
				for j in 3:
					Props.put(g, DX + ["candle_lit.gltf", "candle_melted.gltf", "candle_thin_lit.gltf"][j],
						Vector3(0.22 * j - 0.2, 0, 0.15 * (j % 2)), 0.0, 0.55)
				Props.put(g, DX + ["book_brown.gltf", "book_grey.gltf", "book_tan.gltf"][i % 3], Vector3(0.45, 0, -0.1), 30.0, 0.8)
				Biome.flame(g, Vector3(-0.2, 0.62, 0.0), Color(1.0, 0.6, 0.25), 0.14, 4)
			2:
				Props.put(g, DX + "rocks_small.gltf", Vector3.ZERO, Dressing.rng.randf() * 360.0, 0.45)
				Dressing.lying(g, Dressing.WX + ["sword_B.gltf", "axe_A.gltf", "shield_A.gltf"][i % 3], Vector3(0.6, 0, 0.2),
					Dressing.rng.randf() * 360.0, 0.7)
	Dressing.front_row(fill, 4, 0.8)


static func _study(g: Node3D) -> void:
	Props.put(g, D + "table_small_decorated_A.gltf", Vector3.ZERO, 0.0, 0.62)
	Props.put(g, D + "chair.gltf", Vector3(0.0, 0, 0.62), 180.0, 0.62)
	Props.put(g, DX + "candle_lit.gltf", Vector3(0.28, 0.62, -0.2), 0.0, 0.6).name = "Candle"


static func _trunk_shield(g: Node3D) -> void:
	Props.put(g, DX + "trunk_medium_B.gltf", Vector3.ZERO, 0.0, 0.7)
	Dressing.stuck(g, Dressing.WX + "shield_C.gltf", Vector3(0.1, 0.45, 0.45), 0.0, -15.0, 0.55)


static func _group_at(x: float, z: float, r: float, fill: Callable, yaw := 0.0) -> Node3D:
	if not Dressing.fits(x, z, r, 1.5):
		return null
	var g := Dressing.group("Vignette", x, z, r)
	g.rotation.y = deg_to_rad(yaw)
	fill.call(g)
	return g


# --- set pieces ---------------------------------------------------------------------------------

## Set piece 1: a paladin statue on the dais between banner poles, candles and a rune ring.
static func shrine(c: Node3D, col: String) -> void:
	var dais := Props.put(c, D + "floor_foundation_allsides.gltf", Vector3(0, -1.55, 0), 0.0, 1.0)
	dais.scale = Vector3(1.5, 1.0, 1.5)
	var statue := Props.put(c, Dressing.PAL + "paladin_statue.gltf", Vector3(0, 0.45, -0.3), 0.0, 1.05)
	statue.name = "Statue"
	Props.tint(statue, Color(0.74, 0.72, 0.78), 0.72)
	for sx in [-1.0, 1.0]:
		var col_n := Props.put(c, D + "column.gltf", Vector3(sx * 1.45, 0.45, -0.95), 0.0, 0.62)
		col_n.name = "Column"
		Props.put(c, D + "candle_triple.gltf", Vector3(sx * 1.45, 0.45 + 0.87, -0.95), 0.0, 0.7)
		Biome.flame(c, Vector3(sx * 1.45, 1.95, -0.95), Color(1.0, 0.6, 0.25), 0.18, 5)
		Props.put(c, D + "candle_triple.gltf", Vector3(sx * 1.2, 0.45, 1.05), 0.0, 0.9)
		Biome.flame(c, Vector3(sx * 1.2, 1.3, 1.05), Color(1.0, 0.6, 0.25), 0.2, 5)
	# the run's banner hangs behind the statue
	Props.put(c, banner_path("shield", col), Vector3(0, 0.45, -1.3), 0.0, 0.7).name = "Banner"
	Props.put(c, D + "coin_stack_small.gltf", Vector3(0.45, 0.45, 0.75), 20.0, 0.7)
	Props.put(c, DX + "book_grey.gltf", Vector3(-0.45, 0.45, 0.8), -30.0, 0.8)
	Biome.flicker_light(c, Vector3(0, 2.4, 1.6), Color(1.0, 0.7, 0.4), 2.2, 6.0)
	var halo := Biome._rune_circle(Color(1.0, 0.75, 0.35), 2.2)
	halo.position = Vector3(0, 0.46, 0)
	c.add_child(halo)


## Set piece 2: a treasure hoard: a large gold chest, coin heaps, gold bars and gems, with
## the d20 floating above it.
static func hoard(c: Node3D) -> void:
	var dais := Props.put(c, D + "floor_foundation_allsides.gltf", Vector3(0, -1.55, 0), 0.0, 1.0)
	dais.scale = Vector3(1.6, 1.0, 1.6)
	var y := 0.45
	var chest := Props.put(c, DX + "chest_large_gold.gltf", Vector3(0, y, -0.55), 0.0, 0.7)
	chest.name = "Chest"
	Props.put(c, Dressing.RES + "Gold_Nuggets.gltf", Vector3(-0.85, y, 0.35), 30.0, 1.0)
	Props.put(c, Dressing.RES + "Gold_Bars_Stack_Medium.gltf", Vector3(1.05, y, -0.45), 15.0, 0.8)
	Props.put(c, Dressing.RES + "Gold_Bars.gltf", Vector3(0.75, y, 0.6), -25.0, 0.8)
	Props.put(c, Dressing.RES + "Gems_Pile_Small.gltf", Vector3(0.15, y, 0.85), 0.0, 0.7)
	Props.put(c, D + "coin_stack_large.gltf", Vector3(-1.1, y, -0.7), 0.0, 0.7)
	Props.put(c, D + "coin_stack_medium.gltf", Vector3(-0.4, y, 1.05), 0.0, 0.7)
	var die := Props.put(c, Props.BGB + "D20_red.gltf", Vector3(0, 2.7, 0), 0.0, 1.5)
	Biome._spin_bob(die, 2.7)
	var motes := Fx.elite_sparkle(c, Vector3(0, 0.9, 0), 1.2, 3.0)
	(motes.process_material as ParticleProcessMaterial).color = Color(1.0, 0.85, 0.4)
	Biome.flicker_light(c, Vector3(0, 2.2, 1.6), Color(1.0, 0.72, 0.35), 2.4, 6.0)
	var halo := Biome._rune_circle(Color(1.0, 0.7, 0.25), 2.3)
	halo.position = Vector3(0, 0.46, 0)
	c.add_child(halo)


# --- moat corners -------------------------------------------------------------------------------

static func corner(holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> void:
	match Dressing.kit(2):
		0:
			Props.put(holder, D + "pillar.gltf", p, yaw, 0.32)
			Props.put(holder, D + "candle_triple.gltf", p + Vector3(0, 1.28, 0), yaw, 0.7)
			Biome.flame(holder, p + Vector3(0, 1.9, 0), Color(1.0, 0.6, 0.25), 0.18, 5)
			Props.put(holder, D + "barrel_small.gltf", p + Vector3(-sx * 0.75, 0, sz * 0.15), yaw, 0.55)
		1:
			var g := Node3D.new()
			g.name = "Bones"
			g.position = p
			g.rotation.y = deg_to_rad(yaw)
			holder.add_child(g)
			DressBits.bone_pile(g, 0.8)
			Props.put(holder, D + "candle_melted.gltf", p + Vector3(-sx * 0.8, 0, sz * 0.1), yaw, 0.8)
			Biome.flame(holder, p + Vector3(-sx * 0.8, 0.62, sz * 0.1), Color(1.0, 0.6, 0.25), 0.14, 4)
		2:
			var g := Node3D.new()
			g.name = "Crates"
			g.position = p
			g.rotation.y = deg_to_rad(yaw + 45.0)
			holder.add_child(g)
			DressBits.supplies(g, 0, 0.6)
			Props.put(holder, Props.HAL + "lantern_standing.gltf", p + Vector3(-sx * 0.7, 0, -sz * 0.4), yaw, 0.7)
			Biome.flicker_light(holder, p + Vector3(-sx * 0.7, 0.6, -sz * 0.4), Color(1.0, 0.65, 0.3), 1.0, 3.0)
