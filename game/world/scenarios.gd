class_name BoardScenarios
extends RefCounted
## World / camera / combat scenarios for the screenshot harness (inline mock data).
##  board_act1..3   overview of each biome: hero, mixed tiles incl. enemies + elite, targets
##  board_follow    follow camera mid-hop
##  board_mutate    tiles popping to new types (use --frames)
##  board_portal    hero teleports from the portal corner (use --frames)
##  combat_act1     hero vs 3 enemies, intents/HP visible, mid-attack
##  boss_act1..3    boss fights (Bone Warden, Hollow King, Lich + minions)
##  fx_gallery      every FX firing in a loop on the act 1 board
##  enemy_gallery   every enemy look with its HUD, on the act 1 island
##  combat_sequence full beat loop (attack, hit, death, enemy attack, hero hit, summon, end)
## Optional args: --hero=<class>, --tile=<idx>.

const NAMES := ["board_glade", "board_crypt", "board_hollow", "board_frost", "board_throne", "board_magma",
	"board_act1", "board_act2", "board_act3", "board_follow", "board_mutate", "board_portal", "combat_act1",
	"combat_act2", "combat_act3", "boss_act1", "boss_act2", "boss_act3", "fx_gallery", "enemy_gallery", "combat_sequence"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var root := _Driver.new()
	root.name = "WorldScenario"
	root.scenario = name
	return root


## Tier (1..3) of a biome id.
static func tier_of(id: String) -> int:
	return int(BiomeDefs.DEFS[id].tier) if BiomeDefs.DEFS.has(id) else 1


## A real generated board for a biome (deterministic): the tier's third lap, with the
## route's mini-boss standing on tile 11 for tier-2 biomes.
static func biome_tiles(id: String, seed := 5) -> Array:
	var tier := tier_of(id)
	var lap := int(Balance.BIOME_LAPS[tier - 1]) + 2
	var b := Board.generate(Rng.new(seed), tier, Balance.BOARD_SIZE, lap, id)
	var tiles: Array = b.to_dict().tiles
	if tier == 2:
		var mb: Array = BiomeDefs.miniboss_candidates(["crypt", id, "throne"])
		tiles[11] = {"type": "miniboss", "enemies": [mb[0]], "elite": false}
	return tiles


## 28 tiles (8x8 ring, corners 0/7/14/21) in the contract shape for an act (deterministic).
## Act 2 also shows the mini-boss tile.
static func mock_tiles(act: int) -> Array:
	var pools := {
		1: [["skeleton_minion"], ["skeleton_warrior"], ["skeleton_archer", "skeleton_minion"], ["bandit"],
			["skeleton_minion", "skeleton_minion", "skeleton_archer"]],
		2: [["cultist"], ["bandit", "bandit"], ["brute"], ["skeleton_warrior", "cultist"], ["skeleton_archer"]],
		3: [["brute", "cultist"], ["skeleton_warrior", "skeleton_warrior"], ["cultist", "cultist", "bandit"],
			["brute"], ["skeleton_archer", "skeleton_warrior"]],
	}
	var layout := ["start", "empty", "chest", "enemy", "event", "campfire", "enemy", "forge", "enemy", "trap",
		"chest", "empty", "enemy", "event", "treasury", "empty", "enemy", "campfire", "elite", "chest", "trap",
		"portal", "event", "enemy", "chest", "empty", "enemy", "event"]
	if act == 2:
		layout[11] = "miniboss"
	var pool: Array = pools[clampi(act, 1, 3)]
	var out := []
	var e := 0
	for i in layout.size():
		var type: String = layout[i]
		var t := {"type": type, "enemies": [], "elite": type == "elite"}
		if type == "enemy":
			t.enemies = pool[e % pool.size()]
			e += 1
		elif type == "elite":
			t.enemies = [["skeleton_warrior"], ["brute"], ["cultist"]][clampi(act, 1, 3) - 1]
		elif type == "miniboss":
			t.enemies = ["mini_pumpkin_knight"]
		out.append(t)
	return out


static func mock_enemies(kind: String) -> Array:
	match kind:
		"act1":
			return [
				{"id": "skeleton_minion", "name": "Skeleton", "hp": 12, "max_hp": 12, "block": 0,
					"intent": {"kind": "attack", "value": 4}, "boss": false},
				{"id": "skeleton_warrior", "name": "Skeleton Warrior", "hp": 14, "max_hp": 20, "block": 6,
					"intent": {"kind": "block", "value": 6}, "boss": false},
				{"id": "skeleton_archer", "name": "Skeleton Archer", "hp": 9, "max_hp": 14, "block": 0,
					"intent": {"kind": "attack", "value": 8}, "boss": false, "poison": 3},
			]
		"act2":
			return [
				{"id": "cultist", "name": "Cultist", "hp": 16, "max_hp": 16, "block": 0,
					"intent": {"kind": "curse", "value": 1}, "boss": false},
				{"id": "brute", "name": "Brute", "hp": 30, "max_hp": 38, "block": 0,
					"intent": {"kind": "attack", "value": 12}, "boss": false},
				{"id": "bandit", "name": "Bandit", "hp": 18, "max_hp": 18, "block": 0,
					"intent": {"kind": "buff", "value": 2}, "boss": false, "frozen": true},
			]
		"act3":
			return [
				{"id": "brute", "name": "Brute", "hp": 51, "max_hp": 51, "block": 0,
					"intent": {"kind": "block", "value": 10}, "boss": false},
				{"id": "cultist", "name": "Cultist", "hp": 20, "max_hp": 22, "block": 0,
					"intent": {"kind": "attack", "value": 7}, "boss": false},
			]
		"boss_act1":
			return [{"id": "boss_bone_warden", "name": "Bone Warden", "hp": 96, "max_hp": 120, "block": 0,
				"intent": {"kind": "summon", "value": 1}, "boss": true}]
		"boss_act2":
			return [{"id": "boss_hollow_king", "name": "Hollow King", "hp": 180, "max_hp": 180, "block": 0,
				"intent": {"kind": "attack", "value": 14}, "boss": true}]
		"boss_act3":
			return [
				{"id": "skeleton_minion", "name": "Skeleton", "hp": 17, "max_hp": 17, "block": 0,
					"intent": {"kind": "attack", "value": 6}, "boss": false},
				{"id": "boss_lich", "name": "The Lich", "hp": 170, "max_hp": 260, "block": 12,
					"intent": {"kind": "curse", "value": 1}, "boss": true},
				{"id": "skeleton_minion", "name": "Skeleton", "hp": 11, "max_hp": 17, "block": 0,
					"intent": {"kind": "attack", "value": 6}, "boss": false},
			]
	return []


class _Driver extends Node3D:
	var scenario := ""
	var board: BoardView
	var rig: CameraRig
	var stage: CombatStage

	func _ready() -> void:
		var args: Dictionary = Shot.args if Shot else {}
		var wait := float(args.get("wait", "2.0"))
		var act := 1
		if scenario.ends_with("2"):
			act = 2
		elif scenario.ends_with("3"):
			act = 3
		var biome_id := String(Biome.NAMES[act])
		for id in Biome.IDS:
			if scenario.ends_with("_" + id):
				biome_id = id
				act = BoardScenarios.tier_of(id)
		biome_id = String(args.get("biome", biome_id))
		board = BoardView.new()
		add_child(board)
		board.hero_class = String(args.get("hero", ["knight", "barbarian", "mage"][act - 1]))
		board.hero_idx = int(args.get("tile", "0"))
		var tiles: Array = BoardScenarios.mock_tiles(act) if scenario.ends_with(str(act)) and not args.has("biome") \
			else BoardScenarios.biome_tiles(biome_id)
		board.build(biome_id, tiles)
		rig = CameraRig.new()
		add_child(rig)
		match scenario:
			"board_act1", "board_act2", "board_act3", "board_glade", "board_crypt", "board_hollow", "board_frost", "board_throne", "board_magma":
				board.place_hero(int(args.get("tile", "0")))
				rig.overview(board.ring_bounds(), true)
				var from := board.hero_idx
				var t: Array[int] = [from + 2, from + 5, from + 3]
				var v: Array[int] = [2, 5, 3]
				board.show_targets(t, v)
			"board_follow":
				board.place_hero(1)
				rig.follow(board.hero, true)
				await get_tree().create_timer(maxf(wait - 0.75, 0.3)).timeout
				var path: Array[int] = [2, 3, 4, 5, 6, 7]
				board.hop_hero(path)
			"board_mutate":
				board.place_hero(0)
				rig.overview(board.ring_bounds(), true)
				await get_tree().create_timer(maxf(wait - 0.2, 0.3)).timeout
				board.set_tile(1, {"type": "enemy", "enemies": ["skeleton_warrior"]})
				board.set_tile(2, {"type": "empty"})
				board.set_tile(15, {"type": "elite", "enemies": ["brute"]})
				board.set_tile(25, {"type": "chest"})
				board.pulse_tile(0)
			"board_portal":
				board.place_hero(21)
				rig.follow(board.hero, true)
				await get_tree().create_timer(maxf(wait - 0.4, 0.3)).timeout
				await board.teleport_hero(25)
				board.set_hero_class("rogue")
			"combat_act1", "combat_act2", "combat_act3", "boss_act1", "boss_act2", "boss_act3":
				await _combat(act, wait)
			"combat_sequence":
				await _sequence()
			"enemy_gallery":
				var ids := EnemyLooks.DEFS.keys()
				if String(args.get("only", "")) == "mini":
					# size ladder: elite brute < mini-bosses < the Lich
					ids = ["brute", "mini_bone_champion", "mini_pumpkin_knight", "mini_grave_mage", "boss_lich"]
				var pts := PackedVector3Array()
				for i in ids.size():
					var id: String = ids[i]
					var ch := EnemyLooks.create(id)
					ch.scale = Vector3.ONE * CombatStage.UNIT_SCALE * EnemyLooks.scale_of(id)
					var p := Vector3(-5.6 + (i % 5) * 2.8, 0.05, -1.5 + (i / 5) * 4.2)
					if ids.size() <= 5:
						p = Vector3(-5.2 + i * 2.6, 0.05, 0.6)

					ch.position = p
					add_child(ch)
					var hud := UnitHud.new()
					add_child(hud)
					hud.position = p + Vector3.UP * (2.2 * EnemyLooks.scale_of(id) + 0.2)
					hud.set_data({"hp": 10, "max_hp": 12, "block": 3 if i % 3 == 0 else 0, "boss": EnemyLooks.is_boss(id),
						"name": id, "intent": {"kind": ["attack", "block", "buff", "curse", "summon"][i % 5], "value": 5}}, false)
					pts.append(p)
					pts.append(p + Vector3.UP * 3.0)
				for c in board.biome.get_node("SetPiece").get_children():
					c.visible = false
				rig.frame_points(pts, 0.0, 28.0, true)
			"fx_gallery":
				board.place_hero(3)
				rig.follow(board.hero, true)
				await get_tree().create_timer(maxf(wait - 0.5, 0.2)).timeout
				_fx_all()

	func _process(_dt: float) -> void:
		if Shot and Shot.args.has("perf") and Engine.get_process_frames() % 60 == 0:
			print("PERF fps=%d draws=%d prims=%d objects=%d" % [Engine.get_frames_per_second(),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])

	func _combat(act: int, wait: float) -> void:
		var boss := scenario.begins_with("boss")
		var idx := 0 if boss else int(Shot.args.get("tile", "3"))
		board.place_hero(idx)
		var list: Array = BoardScenarios.mock_enemies(("boss_act%d" if boss else "act%d") % act)
		stage = CombatStage.new()
		add_child(stage)
		rig.overview(board.ring_bounds(), true)
		var start := Time.get_ticks_msec()
		var begin_done := [false]
		stage.began.connect(func() -> void: begin_done[0] = true, CONNECT_ONE_SHOT)
		stage.begin_on_board(board, idx, list, rig)
		rig.combat(board.hero.global_position, stage.enemy_positions(), true, stage.enemy_heights())
		while not begin_done[0]:
			await get_tree().process_frame
		var elapsed := (Time.get_ticks_msec() - start) / 1000.0
		var hit_at := maxf(wait - 0.75, elapsed + 0.1)
		await get_tree().create_timer(maxf(hit_at - elapsed - 0.6, 0.05)).timeout
		var tgt := 1 if list.size() > 2 else 0
		stage.set_target(tgt)
		await stage.hero_attack(tgt)
		stage.enemy_hit(tgt, 23 if boss else 9, boss)
		rig.shake(0.5, 0.3)
		if scenario == "combat_act1":
			Fx.flash(self, Color(1.0, 0.85, 0.5, 0.25))

	func _sequence() -> void:
		var idx := 9
		board.place_hero(idx)
		stage = CombatStage.new()
		add_child(stage)
		rig.overview(board.ring_bounds(), true)
		await get_tree().create_timer(0.3).timeout
		await stage.begin_on_board(board, idx, BoardScenarios.mock_enemies("act1"), rig)
		print("SEQ begun")
		await stage.hero_attack(0)
		await stage.enemy_hit(0, 12, false)
		await stage.enemy_die(0)
		print("SEQ enemy 0 died")
		stage.reframe()
		await stage.enemy_attack(1)
		await stage.hero_hit(6, 2)
		Fx.status_burst(stage, stage.enemy_position(2) + Vector3.UP, "poison")
		stage.set_enemy(2, {"poison": 2, "intent": {"kind": "block", "value": 5}})
		await stage.hero_attack(2, "magic")
		await stage.enemy_hit(2, 30, true, 0)
		await stage.enemy_die(2)
		var i := stage.add_enemy({"id": "skeleton_minion", "name": "Skeleton", "hp": 12, "max_hp": 12,
			"block": 0, "intent": {"kind": "attack", "value": 4}})
		stage.reframe()
		print("SEQ summoned ", i)
		await get_tree().create_timer(1.0).timeout
		Fx.level_up(stage, board.hero.global_position)
		Fx.coin_burst(stage, board.hero.global_position, 8)
		stage.end_on_board()
		print("SEQ ended")

	func _fx_all() -> void:
		var p := board.tile_position(3)
		Fx.damage_number(board, p + Vector3(0, 2.2, 0), 12)
		Fx.damage_number(board, p + Vector3(1.2, 2.4, 0), 48, true)
		Fx.coin_burst(board, board.tile_position(5), 10)
		Fx.hit_sparks(board, board.tile_position(1) + Vector3.UP, Color(1.0, 0.85, 0.5))
		Fx.heal_glow(board, board.tile_position(2))
		Fx.block_flash(board, board.tile_position(4) + Vector3.UP * 0.8)
		Fx.status_burst(board, board.tile_position(6) + Vector3.UP, "poison")
		Fx.status_burst(board, board.tile_position(7) + Vector3.UP, "frost")
		Fx.status_burst(board, board.tile_position(8) + Vector3.UP, "ember")
		Fx.level_up(board, board.tile_position(3))
		Fx.portal_swirl(board, board.tile_position(0) + Vector3.UP * 0.8, 0.8, true)
		Fx.flash(self, Color(1.0, 0.9, 0.5, 0.3))
