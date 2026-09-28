class_name BoardScenarios
extends RefCounted
## World / camera / combat scenarios for the screenshot harness (inline mock data).
##  board_act1..3   overview of each biome: hero, mixed tiles incl. enemies + elite, targets
##  board_follow    follow camera mid-hop
##  board_mutate    tiles popping to new types (use --frames)
##  combat_act1     hero vs 3 enemies, intents/HP visible, mid-attack
##  boss_act1..3    boss fights (Bone Warden, Hollow King, Lich + minions)
##  fx_gallery      every FX firing in a loop on the act 1 board
## Optional args: --hero=<class>, --tile=<idx>.

const NAMES := ["board_act1", "board_act2", "board_act3", "board_follow", "board_mutate", "combat_act1",
	"combat_act2", "combat_act3", "boss_act1", "boss_act2", "boss_act3", "fx_gallery"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var root := _Driver.new()
	root.name = "WorldScenario"
	root.scenario = name
	return root


## 24 tiles in the contract shape for an act (deterministic).
static func mock_tiles(act: int) -> Array:
	var pools := {
		1: [["skeleton_minion"], ["skeleton_warrior"], ["skeleton_archer", "skeleton_minion"], ["bandit"],
			["skeleton_minion", "skeleton_minion", "skeleton_archer"]],
		2: [["cultist"], ["bandit", "bandit"], ["brute"], ["skeleton_warrior", "cultist"], ["skeleton_archer"]],
		3: [["brute", "cultist"], ["skeleton_warrior", "skeleton_warrior"], ["cultist", "cultist", "bandit"],
			["brute"], ["skeleton_archer", "skeleton_warrior"]],
	}
	var layout := ["start", "empty", "chest", "enemy", "event", "campfire", "forge", "enemy", "trap", "chest",
		"enemy", "event", "treasury", "empty", "enemy", "campfire", "elite", "trap", "portal", "event", "enemy",
		"chest", "empty", "enemy"]
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
		board = BoardView.new()
		add_child(board)
		board.hero_class = String(args.get("hero", ["knight", "barbarian", "mage"][act - 1]))
		board.hero_idx = int(args.get("tile", "0"))
		board.build(act, BoardScenarios.mock_tiles(act))
		rig = CameraRig.new()
		add_child(rig)
		match scenario:
			"board_act1", "board_act2", "board_act3":
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
				board.set_tile(13, {"type": "elite", "enemies": ["brute"]})
				board.set_tile(22, {"type": "chest"})
				board.pulse_tile(0)
			"combat_act1", "combat_act2", "combat_act3", "boss_act1", "boss_act2", "boss_act3":
				await _combat(act, wait)
			"fx_gallery":
				board.place_hero(3)
				rig.follow(board.hero, true)
				await get_tree().create_timer(maxf(wait - 0.5, 0.2)).timeout
				_fx_all()

	func _combat(act: int, wait: float) -> void:
		var boss := scenario.begins_with("boss")
		var idx := 0 if boss else int(Shot.args.get("tile", "3"))
		board.place_hero(idx)
		board.set_tile_dressing_visible(idx, false)
		var anchor := board.combat_anchor(idx)
		var list: Array = BoardScenarios.mock_enemies(("boss_act%d" if boss else "act%d") % act)
		stage = CombatStage.new()
		add_child(stage)
		# camera frames the final line-up right away (positions are deterministic)
		rig.overview(board.ring_bounds(), true)
		var start := Time.get_ticks_msec()
		stage.begin(board.hero, anchor, list)
		rig.combat(board.hero.global_position, stage.enemy_positions(), true, stage.enemy_heights())
		var focus: Array = stage.enemy_positions()
		focus.append(board.hero.global_position)
		var centre := Vector3.ZERO
		for f: Vector3 in focus:
			centre += f
		board.clear_area(centre / focus.size(), 4.2)
		var vs := get_viewport().get_visible_rect().size
		board.hide_occluders(rig.desired_transform(), rig.camera.fov, vs.x / vs.y, focus)
		await stage.began
		var elapsed := (Time.get_ticks_msec() - start) / 1000.0
		var hit_at := maxf(wait - 0.3, elapsed + 0.1)
		await get_tree().create_timer(maxf(hit_at - elapsed - 0.6, 0.05)).timeout
		var tgt := 1 if list.size() > 2 else 0
		stage.set_target(tgt)
		await stage.hero_attack(tgt)
		stage.enemy_hit(tgt, 23 if boss else 9, boss)
		rig.shake(0.5, 0.3)
		if scenario == "combat_act1":
			Fx.flash(self, Color(1.0, 0.85, 0.5, 0.25))

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
