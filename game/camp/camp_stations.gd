class_name CampStations
extends RefCounted
## Builds a Camp station's body for its CampState entry: ruined (rubble, broken timbers,
## overgrown), construction (scaffolding, crates, tools, a worker, and the basic version that
## already works) or built tiers 1..3 (the Armory's racks fill with weapons as gear levels rise,
## the Workshop fills with dice per pack, the Pet Den gets a bed per pet, the Arcade a booth per
## minigame). Local frame: the station faces +z, footprint about 3.4 x 2.6 (the CampScene scales
## stations up). Deterministic: the same entry always builds the same body.

const P := preload("res://game/camp/camp_props.gd")


static func build(id: String, st: Dictionary) -> Node3D:
	var b := Node3D.new()
	b.name = "Body"
	match String(st.get("state", "built")):
		"ruined":
			_ruin(b, id)
		"construction":
			_scaffold(b, id)
			match id:
				"armory": _armory_core(b, 0)
				"workshop": _workshop_core(b, st, 0)
				"pet_den": _pet_den_core(b, st, 0)
				"arcade": _arcade_core(b, st, 0)
		_:
			var tier := int(st.get("tier", 1))
			match id:
				"armory": _armory(b, st, tier)
				"workshop": _workshop(b, st, tier)
				"pet_den": _pet_den(b, st, tier)
				"arcade": _arcade(b, st, tier)
	return b


# ------------------------------------------------------------------ ruins & construction

static func _ruin(b: Node3D, id: String) -> void:
	var D := Props.DUN
	P.planks(b, Vector2(3.0, 2.2), Color(0.34, 0.26, 0.2), true)
	P.opt(b, D + "rubble_half.gltf", Vector3(-0.8, 0, -0.5), 20.0, 0.22)
	P.opt(b, D + "rubble_half.gltf", Vector3(0.9, 0, 0.3), -40.0, 0.18)
	P.forest(b, "Rock_3_C", 1, Vector3(-0.2, 0, -0.9), 50.0, 0.9)
	# a leaning broken post and a fallen beam
	P.box(b, Vector3(0.12, 1.2, 0.12), Vector3(-1.2, 0.55, -0.8), Color(0.34, 0.24, 0.17), Vector3(0, 0, 14))
	P.box(b, Vector3(0.12, 1.6, 0.12), Vector3(1.1, 0.12, -0.6), Color(0.32, 0.23, 0.16), Vector3(84, 30, 0))
	P.box(b, Vector3(0.12, 0.7, 0.12), Vector3(0.3, 0.3, -1.0), Color(0.36, 0.25, 0.18), Vector3(0, 0, -9))
	match id:
		"armory":
			P.opt(b, D + "sword_shield_broken.gltf", Vector3(0.2, 0.25, 0.6), 15.0, 0.5)
		"workshop":
			P.opt(b, D + "table_medium_broken.gltf", Vector3(0.1, 0, -0.1), 25.0, 0.6)
		"pet_den":
			P.opt(b, Props.HAL + "fence_broken.gltf", Vector3(0.0, 0, 0.6), 10.0, 0.7)
		"arcade":
			for k in 3:
				var t := Props.put(b, Props.BGB + ["tile_red.gltf", "tile_blue.gltf", "tile_yellow.gltf"][k],
					Vector3(-0.6 + 0.7 * k, 0.02, 0.4 - 0.25 * k), 25.0 * k, 0.6)
				t.rotation_degrees.x = 8.0 * (k - 1)
	# overgrowth
	P.forest(b, "Bush_1_C", 1, Vector3(-0.3, 0, 0.3), 30.0, 0.9)
	P.forest(b, "Bush_2_C", 2, Vector3(1.3, 0, -0.9), 80.0, 0.8)
	P.forest(b, "Bush_4_C", 4, Vector3(-1.5, 0, 0.8), 10.0, 0.7)
	P.forest(b, "Tree_Bare_1_A", 1, Vector3(1.4, 0, 0.9), 40.0, 0.7)
	P.forest(b, "Rock_1_B", 1, Vector3(0.6, 0, -0.2), 0.0, 0.8)


## Scaffolding at the back, a pallet of planks, crates and tools, and a worker.
static func _scaffold(b: Node3D, id: String) -> void:
	var wood := Color(0.52, 0.38, 0.24)
	for x in [-1.5, 1.5]:
		for z in [-1.15, -0.45]:
			P.post(b, Vector3(x, 0, z), 2.4, wood, 0.09)
	for y in [1.1, 2.2]:
		P.box(b, Vector3(3.2, 0.1, 0.8), Vector3(0, y, -0.8), wood.lightened(0.05))
	P.box(b, Vector3(0.07, 2.9, 0.07), Vector3(-0.2, 1.2, -0.42), wood, Vector3(0, 0, 50))
	P.opt(b, P.RES + "Pallet_Wood.gltf", Vector3(1.3, 0, 0.75), 12.0, 0.6)
	P.opt(b, P.RES + "Wood_Planks_Stack_Small.gltf", Vector3(1.3, 0.2, 0.75), 100.0, 0.6)
	P.opt(b, Props.DUN + "box_small.gltf", Vector3(-1.45, 0, 0.8), 15.0, 0.5)
	P.opt(b, Props.DUN + "box_small.gltf", Vector3(-1.45, 0.5, 0.8), 40.0, 0.45)
	Props.put(b, Props.TOOLS + "hammer.gltf", Vector3(0.9, 0.02, 1.1), 70.0, 0.7)
	Props.put(b, Props.TOOLS + "saw.gltf", Vector3(-0.9, 0.02, 1.15), 20.0, 0.6)
	P.opt(b, Props.TOOLS + "rope_bundle_A.gltf", Vector3(-1.1, 1.18, -0.8), 0.0, 0.6)
	var worker := P.npc("engineer" if id != "workshop" else "Engineer", {"handslot.r": Props.TOOLS + "hammer.gltf"}, "Lockpicking")
	if worker:
		worker.name = "Worker"
		worker.position = Vector3(0.35, 0, 0.65)
		worker.rotation.y = deg_to_rad(-30.0)
		worker.scale = Vector3.ONE * 0.56
		b.add_child(worker)


# ------------------------------------------------------------------ armory

static func _armory_core(b: Node3D, tier: int) -> void:
	var stump := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.36
	cm.height = 0.45
	cm.radial_segments = 8
	cm.rings = 1
	stump.mesh = BiomeBlocks.faceted(cm, Color(0.46, 0.3, 0.2), 0.02, 4)
	stump.position = Vector3(0.35, 0.22, 0.55)
	b.add_child(stump)
	Props.put(b, Props.TOOLS + "anvil.gltf", Vector3(0.35, 0.45, 0.55), 90.0, 0.85)
	Props.put(b, Props.TOOLS + "tongs.gltf", Vector3(0.95, 0.02, 0.95), 70.0, 1.0)


static func _armory(b: Node3D, st: Dictionary, tier: int) -> void:
	var D := Props.DUN
	var W := P.WX if ResourceLoader.exists(P.WX + "sword_F.gltf") else Props.WPN
	var levels := int(st.get("levels", 0))
	P.planks(b, Vector2(3.4, 2.6), Color(0.46, 0.32, 0.22))
	_armory_core(b, tier)
	# the forge: a stone brazier with a fire
	var braz := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.42
	bc.bottom_radius = 0.5
	bc.height = 0.55
	bc.radial_segments = 8
	bc.rings = 1
	braz.mesh = BiomeBlocks.faceted(bc, Color(0.42, 0.4, 0.44), 0.03, 21, Color(0.26, 0.24, 0.28))
	braz.position = Vector3(1.25, 0.28, -0.55)
	b.add_child(braz)
	var coals := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.36
	cs.height = 0.2
	coals.mesh = cs
	coals.material_override = Props.glow_material(Color(1.0, 0.4, 0.1), false, 2.2)
	coals.position = Vector3(1.25, 0.56, -0.55)
	b.add_child(coals)
	Biome.flame(b, Vector3(1.25, 0.7, -0.55), Color(1.0, 0.5, 0.15), 0.55, 12)
	Biome.flicker_light(b, Vector3(1.25, 1.3, -0.35), Color(1.0, 0.55, 0.25), 2.0, 4.5)
	# weapon rack along the back: fills up as the gear levels rise (2..6 weapons)
	var wood := Color(0.44, 0.29, 0.18)
	for x in [-1.55, 0.35]:
		P.post(b, Vector3(x, 0, -0.95), 1.7, wood)
	for y in [0.6, 1.45]:
		P.box(b, Vector3(2.05, 0.09, 0.1), Vector3(-0.6, y, -0.95), wood.lightened(0.08))
	var ws := ["sword_F.gltf", "axe_D.gltf", "halberd.gltf", "sword_G.gltf", "spear_B.gltf", "hammer_D.gltf"]
	var n := clampi(2 + levels / 3, 2, ws.size())
	for i in n:
		var path := W + String(ws[i])
		if not ResourceLoader.exists(path):
			path = Props.WPN + "sword_A.gltf"
		var w := Props.put(b, path, Vector3(-1.35 + 0.31 * i, 0.12, -0.85), 0.0, 0.85)
		w.rotation_degrees = Vector3(-10.0, 90.0, 0.0)
	if tier >= 2:
		var sh := ["shield_B.gltf", "shield_C.gltf", "shield_D.gltf"]
		for i in clampi(levels / 7, 1, 3):
			P.opt(b, W + String(sh[i]), Vector3(-1.25 + 0.62 * i, 1.35, -0.84), 0.0, 0.62)
		P.opt(b, P.TX + "grindstone.gltf", Vector3(-1.35, 0, 0.8), 30.0, 0.5)
		Props.put(b, D + "barrel_small.gltf", Vector3(-1.45, 0, -0.1), 30.0, 0.62)
		for k in 2:
			var s := Props.put(b, Props.WPN + "sword_A.gltf", Vector3(-1.52 + 0.14 * k, 1.05, -0.12), 0.0, 0.7)
			s.rotation_degrees = Vector3(8.0 - 16.0 * k, 20.0, 180.0)
	if tier >= 3:
		P.opt(b, P.MM + "paladin/paladin_statue.gltf", Vector3(1.55, 0, 0.55), -35.0, 0.55)
		P.opt(b, D + "banner_patternA_red.gltf", Vector3(-0.6, 1.72, -1.05), 0.0, 0.3)
	# the owned gear pieces on a little table: Helm (shield), Blade (sword), Boots (compass),
	# Charm (gems); a piece at L8 glows
	var table := Node3D.new()
	table.name = "GearTable"
	table.position = Vector3(-0.45, 0, 0.35)
	b.add_child(table)
	P.box(table, Vector3(0.9, 0.08, 0.55), Vector3(0, 0.62, 0), Color(0.5, 0.34, 0.22))
	for x in [-0.38, 0.38]:
		P.box(table, Vector3(0.08, 0.62, 0.08), Vector3(x, 0.31, 0), Color(0.4, 0.26, 0.16))
	var looks := {"helm": [P.ADX + "assets/shield_badge_color.gltf", Vector3(-0.3, 0.66, 0.0), Vector3(-70, 0, 0), 0.5],
		"blade": [P.ADX + "assets/sword_2handed_color.gltf", Vector3(-0.05, 0.68, 0.05), Vector3(90, 0, 70), 0.42],
		"boots": [Props.TOOLS + "compass_base.gltf", Vector3(0.18, 0.66, -0.1), Vector3.ZERO, 0.7],
		"charm": [P.RX + "Gems_Pile_Small.gltf", Vector3(0.32, 0.66, 0.12), Vector3.ZERO, 0.45]}
	var gl: Dictionary = st.get("gear_levels", {})
	for slot in GearDefs.SLOTS:
		if int(gl.get(slot, 0)) <= 0:
			continue
		var d: Array = looks[slot]
		var it := P.opt(table, String(d[0]), d[1], 0.0, float(d[3]))
		if it:
			it.rotation_degrees = d[2]
		if int(gl.get(slot, 0)) >= GearDefs.MAX_LEVEL:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.85, 0.4)
			l.light_energy = 0.8
			l.omni_range = 0.9
			l.position = d[1] + Vector3.UP * 0.25
			table.add_child(l)
	var smith := P.glb_character(P.ADX + "characters/Barbarian_Large.glb", "large", {}, "idle")
	if smith:
		smith.name = "Keeper"
		smith.position = Vector3(0.35, 0, -0.25)
		smith.scale = Vector3.ONE * 0.5
		b.add_child(smith)
		P.loop_clip(smith, "Melee_2H_Attack_Chop", 2.4)


# ------------------------------------------------------------------ workshop

static func _workshop_core(b: Node3D, st: Dictionary, tier: int) -> void:
	var T := Props.TOOLS
	Props.put(b, Props.DUN + "table_medium.gltf", Vector3(-0.15, 0, 0.1), 0.0, 0.6)
	Props.put(b, T + "blueprint.gltf", Vector3(-0.15, 0.6, 0.1), -10.0, 0.5)
	Props.put(b, Props.BGB + "D6_A_blue.gltf", Vector3(0.1, 0.72, 0.2), 25.0, 0.3)


static func _workshop(b: Node3D, st: Dictionary, tier: int) -> void:
	var D := Props.DUN
	var T := Props.TOOLS
	var B := Props.BGB
	P.planks(b, Vector2(3.4, 2.6), Color(0.5, 0.36, 0.24))
	var bench := P.opt(b, P.DX + "table_long_decorated_A.gltf", Vector3(-0.15, 0, -0.35), 0.0, 0.62)
	if bench == null:
		Props.put(b, D + "table_medium.gltf", Vector3(-0.15, 0, -0.35), 0.0, 0.62)
	var top := 0.62
	Props.put(b, T + "saw.gltf", Vector3(-0.85, top, -0.4), 20.0, 0.7)
	Props.put(b, T + "blueprint.gltf", Vector3(0.1, top, -0.35), -10.0, 0.6)
	Props.put(b, T + "hammer.gltf", Vector3(-0.45, top + 0.12, -0.2), 70.0, 0.6)
	Props.put(b, T + "wrench_A.gltf", Vector3(0.45, top + 0.1, -0.2), 20.0, 0.6)
	Props.put(b, T + "lantern.gltf", Vector3(0.62, top, -0.55), 0.0, 0.65)
	Biome.flicker_light(b, Vector3(0.62, top + 0.7, -0.35), Color(1.0, 0.8, 0.5), 1.6, 3.8)
	# one showcase die per unlock pack
	var dice := [["D6_A_blue.gltf", Vector3(1.05, 0.34, 0.55), 0.9], ["D6_B_red.gltf", Vector3(-1.2, 0.3, 0.6), 0.8],
		["D20_yellow.gltf", Vector3(-1.5, 0.3, -0.1), 0.62], ["D6_A_green.gltf", Vector3(-0.8, top + 0.14, -0.55), 0.36],
		["D8_red.gltf", Vector3(-0.2, top + 0.14, -0.55), 0.36], ["D6_C_yellow.gltf", Vector3(0.55, 0.27, 1.05), 0.7],
		["D4_green.gltf", Vector3(-0.55, 0.2, 1.1), 0.6], ["D20_blue.gltf", Vector3(1.55, 0.3, -0.35), 0.55]]
	var packs := (st.get("packs", []) as Array).size()
	for i in clampi(packs, 1, dice.size()):
		var d: Array = dice[i]
		P.opt(b, B + String(d[0]), d[1], 25.0 * i, float(d[2]))
	if tier >= 2:
		P.opt(b, P.RX + "Containers_Crate_Medium_Wood.gltf", Vector3(-1.45, 0, -0.6), 10.0, 0.62)
		Props.put(b, P.RES + "Parts_Pile_Small.gltf", Vector3(0.9, 0, 1.0), 30.0, 0.7)
	if tier >= 3:
		P.opt(b, P.TX + "grindstone.gltf", Vector3(1.5, 0, 0.9), -40.0, 0.45)
		P.opt(b, D + "shelf_small_candles.gltf", Vector3(-0.2, 0, -1.2), 0.0, 0.7)
	var eng := P.glb_character(P.ADX + "characters/Engineer.glb", "medium", {"handslot.r": P.ADX + "assets/engineer_Wrench.gltf"}, "Lockpicking")
	if eng:
		eng.name = "Keeper"
		eng.position = Vector3(1.05, 0, -0.25)
		eng.rotation.y = deg_to_rad(-60.0)
		eng.scale = Vector3.ONE * 0.58
		b.add_child(eng)


# ------------------------------------------------------------------ pet den

static func _pet_den_core(b: Node3D, st: Dictionary, tier: int) -> void:
	Props.put(b, Props.DUN + "bed_floor.gltf", Vector3(0.1, 0, -0.35), 90.0, 0.5)


static func _pet_den(b: Node3D, st: Dictionary, tier: int) -> void:
	var H := Props.HAL
	var D := Props.DUN
	var wood := Color(0.46, 0.3, 0.2)
	for x in [-1.25, 1.25]:
		P.post(b, Vector3(x, 0, 0.55), 1.75, wood)
		P.post(b, Vector3(x, 0, -1.0), 2.1, wood)
	var roof := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(2.9, 0.1, 2.0)
	roof.mesh = BiomeBlocks.faceted(rb, Color(0.74, 0.36, 0.26), 0.0, 8, Color(0.5, 0.22, 0.16))
	roof.position = Vector3(0, 1.98, -0.2)
	roof.rotation.x = deg_to_rad(-12.0)
	b.add_child(roof)
	P.box(b, Vector3(2.6, 1.2, 0.1), Vector3(0, 0.6, -1.05), wood.darkened(0.15))
	# a bed and a food bowl per pet that lives here
	var pets: Array = st.get("pets", [])
	for i in mini(pets.size(), 6):
		var x := -0.9 + 0.62 * float(i % 4)
		var z := -0.45 + 0.75 * float(i / 4)
		var bed := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.26
		cyl.bottom_radius = 0.28
		cyl.height = 0.12
		cyl.radial_segments = 10
		cyl.rings = 1
		bed.mesh = cyl
		var bc: Color = CampInfo.PET_COLOR.get(String(pets[i]), Color(0.8, 0.5, 0.4))
		bed.material_override = Props.flat_material(bc.darkened(0.25).lerp(Color(0.6, 0.45, 0.4), 0.4))
		bed.position = Vector3(x, 0.06, z)
		b.add_child(bed)
		Props.put(b, D + "plate_small.gltf", Vector3(x + 0.22, 0, z + 0.3), 0.0, 0.35)
	Props.put(b, H + "pumpkin_orange.gltf", Vector3(1.25, 0, 1.05), 10.0, 0.62)
	var lan := Props.put(b, H + "lantern_hanging.gltf", Vector3(0.9, 1.75, 0.55), 0.0, 0.7)
	lan.name = "Lantern"
	Biome.flicker_light(b, Vector3(0.9, 1.35, 0.7), Color(1.0, 0.72, 0.4), 1.4, 3.4)
	if tier >= 2:
		Props.put(b, H + "pumpkin_orange_jackolantern.gltf", Vector3(-1.2, 0, 1.0), 20.0, 0.62)
		Props.put(b, H + "pumpkin_yellow_small.gltf", Vector3(-0.75, 0, 1.2), -30.0, 0.8)
		Biome.flicker_light(b, Vector3(-1.2, 0.5, 1.1), Color(1.0, 0.55, 0.2), 1.2, 2.6)
		P.opt(b, P.RX + "Food_Basket_A_Berries.gltf", Vector3(0.65, 0, 1.05), 0.0, 0.7)
	if tier >= 3:
		Props.put(b, H + "candle_triple.gltf", Vector3(1.2, 0, -0.55), 0.0, 0.8)
		P.opt(b, P.RX + "Food_Crate_Small_Berries.gltf", Vector3(-1.35, 0, -0.35), 20.0, 0.6)
		P.opt(b, P.DX + "bench.gltf", Vector3(0.0, 0, 1.25), 0.0, 0.5)
	var druid := P.glb_character(P.ADX + "characters/Druid.glb", "medium", {"handslot.r": P.ADX + "assets/druid_staff.gltf"}, "idle_b")
	if druid:
		druid.name = "Keeper"
		druid.position = Vector3(-0.55, 0, 0.35)
		druid.rotation.y = deg_to_rad(25.0)
		druid.scale = Vector3.ONE * 0.58
		b.add_child(druid)


# ------------------------------------------------------------------ arcade

## One booth per owned minigame, on a row across the booth floor.
static func _arcade_core(b: Node3D, st: Dictionary, tier: int) -> void:
	var games: Array = st.get("games", [])
	var spots := {"claw_machine": Vector3(0.25, 0, -0.35), "scratch_off": Vector3(1.3, 0, 0.35),
		"fossil_hunter": Vector3(-1.2, 0, 0.35), "bubble_breaker": Vector3(-1.05, 0, -0.75)}
	for g in games:
		var at: Vector3 = spots.get(String(g), Vector3.ZERO)
		match String(g):
			"claw_machine":
				var claw := Node3D.new()
				claw.position = at
				claw.scale = Vector3.ONE * 0.95
				b.add_child(claw)
				_claw_machine(claw)
			"scratch_off":
				var pod := P.opt(b, P.MM + "clown/circus_podium.gltf", at, 0.0, 0.55)
				var top := 0.6 if pod else 0.0
				Props.put(b, Props.BGB + "tile_yellow.gltf", at + Vector3(0, top + 0.28, 0), 0.0, 0.5).rotation_degrees.x = 75.0
				Props.put(b, Props.BGB + "coin_10_gold.gltf", at + Vector3(0.3, 0, 0.45), 30.0, 0.6)
			"fossil_hunter":
				var mound := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.55
				sm.height = 0.5
				sm.is_hemisphere = true
				mound.mesh = BiomeBlocks.faceted(sm, Color(0.46, 0.34, 0.24), 0.05, 5, Color(0.36, 0.26, 0.18), Vector3(1.2, 0.8, 1.0))
				mound.position = at
				b.add_child(mound)
				Props.put(b, Props.HAL + "bone_A.gltf", at + Vector3(0.1, 0.3, 0.1), 40.0, 0.7)
				Props.put(b, Props.HAL + "skull.gltf", at + Vector3(-0.25, 0.22, 0.25), 20.0, 0.35)
				Props.put(b, Props.TOOLS + "shovel.gltf", at + Vector3(0.45, 0.0, -0.1), 0.0, 0.8).rotation_degrees.z = 15.0
			"bubble_breaker":
				var tank := MeshInstance3D.new()
				var bx := BoxMesh.new()
				bx.size = Vector3(0.8, 0.9, 0.6)
				tank.mesh = bx
				var gm := StandardMaterial3D.new()
				gm.albedo_color = Color(0.5, 0.85, 1.0, 0.28)
				gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				gm.roughness = 0.1
				tank.material_override = gm
				tank.position = at + Vector3(0, 0.45 + 0.35, 0)
				tank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				b.add_child(tank)
				P.box(b, Vector3(0.9, 0.35, 0.7), at + Vector3(0, 0.17, 0), Color(0.3, 0.55, 0.9))
				var cols := [Color(1, 0.35, 0.4), Color(0.35, 0.8, 1), Color(1, 0.85, 0.3), Color(0.5, 1, 0.5)]
				for k in 8:
					var bub := MeshInstance3D.new()
					var s := SphereMesh.new()
					s.radius = 0.1
					s.height = 0.2
					bub.mesh = s
					var bm := StandardMaterial3D.new()
					bm.albedo_color = cols[k % 4]
					bm.emission_enabled = true
					bm.emission = cols[k % 4]
					bm.emission_energy_multiplier = 0.5
					bub.material_override = bm
					bub.position = at + Vector3(-0.25 + 0.17 * float(k % 4), 0.45 + 0.12 + 0.2 * float(k / 4), -0.1 + 0.1 * float(k % 2))
					b.add_child(bub)


static func _arcade(b: Node3D, st: Dictionary, tier: int) -> void:
	var B := Props.BGB
	var tiles := ["tile_red.gltf", "tile_blue.gltf", "tile_yellow.gltf", "tile_green.gltf"]
	for ix in 4:
		for iz in 3:
			var t := Props.put(b, B + tiles[(ix + iz * 2) % 4], Vector3(-1.2 + ix * 0.8, -0.1, -0.8 + iz * 0.8), 0.0, 0.8)
			Props.set_shadows(t, false)
	_arcade_core(b, st, tier)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.85)
	glow.light_energy = 1.6
	glow.omni_range = 3.4
	glow.position = Vector3(0, 1.6, 0.6)
	b.add_child(glow)
	if tier >= 2:
		var bunch := Node3D.new()
		bunch.name = "Balloons"
		bunch.position = Vector3(1.55, 0, -0.9)
		b.add_child(bunch)
		var cols := ["red", "yellow", "blue", "green"]
		for i in cols.size():
			var bl := P.opt(bunch, P.MM + "clown/balloon_%s.gltf" % cols[i], Vector3(0.18 * cos(i * 1.6), 1.6 + 0.2 * (i % 2), 0.18 * sin(i * 1.6)), 0.0, 0.55)
			if bl:
				var bob := bl.create_tween().set_loops()
				bob.tween_property(bl, "position:y", bl.position.y + 0.12, 1.3 + 0.2 * i).set_trans(Tween.TRANS_SINE)
				bob.tween_property(bl, "position:y", bl.position.y, 1.3 + 0.2 * i).set_trans(Tween.TRANS_SINE)
		P.opt(b, P.MM + "orc/Orc_Wardrum.gltf.glb", Vector3(-1.55, 0, 1.0), 30.0, 0.45)
	if tier >= 3:
		P.opt(b, P.MM + "clown/circus_hoop.gltf", Vector3(1.6, 0, 0.9), 70.0, 0.5)
		for i in 3:
			P.opt(b, P.MM + "clown/juggling_pin_%s.gltf" % ["red", "yellow", "green"][i], Vector3(0.75 + 0.16 * i, 0, 1.15), 0.0, 0.6)
		Props.put(b, B + "flag_A_yellow.gltf", Vector3(-1.65, 0, -1.1), 0.0, 0.9)
		Props.put(b, B + "flag_B_blue.gltf", Vector3(1.65, 0, -1.1), 0.0, 0.9)
	var barker := P.glb_character(P.ADX + "characters/Rogue_Hooded.glb", "medium", {}, "Waving")
	if barker:
		barker.name = "Keeper"
		barker.position = Vector3(-0.35, 0, 0.8)
		barker.rotation.y = deg_to_rad(20.0)
		barker.scale = Vector3.ONE * 0.58
		b.add_child(barker)


## The claw-machine cabinet: glass case, prize pile, swaying claw, marquee.
static func _claw_machine(b: Node3D) -> void:
	var B := Props.BGB
	var PL := Props.PLAT
	P.box(b, Vector3(1.1, 0.9, 1.0), Vector3(0, 0.45, 0), Color(0.9, 0.3, 0.62))
	var glass := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(1.04, 1.0, 0.94)
	glass.mesh = gb
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.7, 0.9, 1.0, 0.18)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.1
	glass.material_override = gm
	glass.position = Vector3(0, 1.4, 0)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(glass)
	for x in [-0.53, 0.53]:
		for z in [-0.46, 0.46]:
			var pole := P.box(b, Vector3(0.06, 1.0, 0.06), Vector3(x, 1.4, z), Color(0.95, 0.85, 0.4))
			pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	P.box(b, Vector3(1.2, 0.34, 1.1), Vector3(0, 2.05, 0), Color(0.45, 0.3, 0.85))
	var marquee := MeshInstance3D.new()
	var mq := BoxMesh.new()
	mq.size = Vector3(1.0, 0.18, 0.04)
	marquee.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.85, 0.35)
	mm.emission_enabled = true
	mm.emission = Color(1.0, 0.75, 0.3)
	mm.emission_energy_multiplier = 2.2
	marquee.material_override = mm
	marquee.position = Vector3(0, 2.05, 0.56)
	b.add_child(marquee)
	var prizes := [[PL + "yellow/star_yellow.gltf", Vector3(-0.25, 1.0, -0.1), 0.55], [PL + "red/heart_red.gltf", Vector3(0.22, 0.98, 0.15), 0.5],
		[PL + "blue/diamond_blue.gltf", Vector3(0.05, 1.0, -0.25), 0.5], [B + "coin_gold.gltf", Vector3(-0.3, 0.93, 0.25), 1.2],
		[B + "D6_A_red.gltf", Vector3(0.3, 0.92, -0.22), 1.5]]
	for i in prizes.size():
		var pz: Array = prizes[i]
		var n := Props.put(b, String(pz[0]), pz[1], 70.0 * i, float(pz[2]))
		n.rotation.x = 0.2 * float(i % 3 - 1)
	var claw := Node3D.new()
	claw.name = "Claw"
	claw.position = Vector3(0.1, 1.82, 0)
	b.add_child(claw)
	P.box(claw, Vector3(0.03, 0.35, 0.03), Vector3.ZERO, Color(0.8, 0.8, 0.85))
	for k in 3:
		var a := TAU * k / 3.0
		P.box(claw, Vector3(0.04, 0.2, 0.04), Vector3(cos(a) * 0.07, -0.25, sin(a) * 0.07), Color(0.85, 0.85, 0.9),
			Vector3(rad_to_deg(sin(a) * 0.5), 0, rad_to_deg(-cos(a) * 0.5)))
	var sway := claw.create_tween().set_loops()
	sway.tween_property(claw, "position:x", -0.2, 2.2).set_trans(Tween.TRANS_SINE)
	sway.tween_property(claw, "position:x", 0.25, 2.2).set_trans(Tween.TRANS_SINE)
	var knob := MeshInstance3D.new()
	var ks := SphereMesh.new()
	ks.radius = 0.08
	ks.height = 0.16
	knob.mesh = ks
	knob.material_override = Props.flat_material(Color(1.0, 0.25, 0.3), 0.3)
	knob.position = Vector3(-0.25, 1.02, 0.48)
	b.add_child(knob)
