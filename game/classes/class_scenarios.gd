extends RefCounted
## Class presentation scenarios (classes, mechanics, skins, Wardrobe), served through
## tools/scenarios.gd PROVIDERS.
##
##  class_looks     every class hero (HeroLook) in a row; --skins=1: one row per class with its
##                  5 looks (default, victor, ascendant, bossbane, prestige overlay);
##                  --class=<id>: that class's skins only. --view=front|three, --anim=<alias>
##  class_moment    the real game (GameController + GameFlow) frozen on a class mechanic moment:
##                  --class=<id> --moment=<m> (--hold=S: seconds after the moment's event before
##                  the freeze, --skin=<slot> --prestige=1). Moments:
##                    paladin: oath (the Oath is sworn), oath_kept (an Oath pair attack)
##                    ranger: aim (no-reroll attack: the reticle), pierce (overkill carries on)
##                    ninja: shadow_step (a reroll that lands a match is refunded)
##                    druid: overgrowth (a lap grows the seed die), seed (a biome change plants one)
##                    engineer: turret (the turret fires after the attack), board (hero + turret)
##                    necromancer: bones (a kill raises a Bone die), bone_die (it joins the tray)
##                    monster_kid: boo (★ attack scares the target), cower (it skips its turn),
##                      flee (a weak scared foe runs off), star_board (★ on a board roll)
##                    any class: idle (a fight mid-turn: class badge, tray, preview)
##  elite_affixed   an affixed elite line-up (game_combat): Gilded+Hexing Bone Golem leader, a
##                  Warded warrior, with affix badge K of enemy I's tooltip open (--tip=I:K, 0:0)
##  elite_affix_card  a fresh profile meets the Fallen Paladin (Frenzied + Vampiric) and a Thorned
##                  Werewolf: the first-encounter card over the fight

const ARM := preload("res://game/actors/armory_scenarios.gd")
const ACT := preload("res://game/actors/scenarios.gd")

const NAMES := ["class_looks", "class_moment", "elite_affixed", "elite_affix_card"]
## game_combat args behind the affix scenarios (explicit command-line args win).
const ELITES := {
	"elite_affixed": {"elite": "1", "enemies": "bone_golem,skeleton_warrior,skeleton_minion", "affixes": "gilded+hexing,warded,-",
		"cards": "0", "tip": "0:0"},
	"elite_affix_card": {"elite": "1", "enemies": "fallen_paladin,werewolf", "affixes": "frenzied+vampiric,thorned"},
}


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var args: Dictionary = Shot.args if Shot else {}
	match name:
		"class_looks":
			return _looks(args)
		"elite_affixed", "elite_affix_card":
			if Shot:
				for k in ELITES[name]:
					if not Shot.args.has(k):
						Shot.args[k] = ELITES[name][k]
			return load("res://game/scenarios.gd").build("game_combat")
		"class_moment":
			var d := _Moment.new()
			d.name = "ClassMoment"
			return d
	return null


## A grid of heroes: cells [{class, skin, prestige, label}].
static func _looks(args: Dictionary) -> Node:
	var cells: Array = []
	var cols := 6
	if args.has("class"):
		var cid := String(args["class"])
		for s in ["default", "victor", "ascendant", "bossbane"]:
			cells.append({"class": cid, "skin": s, "prestige": false, "label": SkinDefs.NAMES[s]})
		cells.append({"class": cid, "skin": "default", "prestige": true, "label": "Prestige"})
		cols = 5
	elif String(args.get("skins", "0")) == "1":
		var ids: Array = HeroDefs.IDS.slice(int(args.get("from", "0")), int(args.get("to", "11")))
		for cid in ids:
			for s in ["default", "victor", "ascendant", "bossbane"]:
				cells.append({"class": cid, "skin": s, "prestige": false, "label": "%s %s" % [HeroDefs.DATA[cid].name, SkinDefs.NAMES[s]]})
			cells.append({"class": cid, "skin": "default", "prestige": true, "label": "Prestige"})
		cols = 5
	else:
		for cid in HeroDefs.IDS:
			cells.append({"class": cid, "skin": "default", "prestige": false, "label": String(HeroDefs.DATA[cid].name)})
	cols = int(args.get("cols", str(cols)))
	var root := Node3D.new()
	root.name = "ClassLooks"
	ACT._add_environment(root)
	ARM._add_floor(root)
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var sx := float(args.get("sx", "2.3"))
	var sz := float(args.get("sz", "3.4"))
	var rows := int(ceil(float(cells.size()) / float(cols)))
	var view := String(args.get("view", "front"))
	var yaw := {"front": 0.0, "three": 35.0, "back": 180.0, "side": 90.0}.get(view, 0.0) as float
	var anim := String(args.get("anim", "idle"))
	var pts: Array[Vector3] = []
	for i in cells.size():
		var c: Dictionary = cells[i]
		var pos := Vector3((float(i % cols) - (cols - 1) * 0.5) * sx, 0.0, (float(i / cols) - (rows - 1) * 0.5) * sz)
		var ch := HeroLook.create(String(c["class"]), String(c.skin), bool(c.prestige))
		ch.position = pos
		ch.rotation.y = deg_to_rad(yaw)
		root.add_child(ch)
		ACT._loop(ch, anim)
		var label := Label3D.new()
		label.text = String(c.label)
		label.font = font
		label.font_size = int(args.get("font", "64"))
		label.pixel_size = 0.0045
		label.outline_size = 12
		label.outline_modulate = Color(0.08, 0.06, 0.1, 0.9)
		label.modulate = Color(1.0, 0.86, 0.5)
		label.position = pos + Vector3(0.0, 0.05, 0.75)
		label.rotation_degrees.x = -90.0
		label.width = 420.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(label)
		var head := String(args.get("zoom", "")) == "head"
		for dx in [-0.75, 0.75]:
			for dz in ([-0.2, 0.3] if head else [-0.4, 1.1]):
				pts.append(pos + Vector3(dx, 1.2 if head else 0.0, dz))
				pts.append(pos + Vector3(dx, 3.1 if head else 2.9, dz))
	var cam := ArmoryScenarios._GridCamera.new()
	cam.points = pts
	var tall := (Engine.get_main_loop() as SceneTree).root.size.y > (Engine.get_main_loop() as SceneTree).root.size.x
	cam.pitch = float(args.get("pitch", "50" if tall else "30"))
	root.add_child(cam)
	cam.current = true
	return root


## Drives the real game to one class mechanic moment and freezes the tree there.
class _Moment extends Node:
	var c: GameController
	var f: GameFlow
	var args: Dictionary = {}
	var cls := "knight"
	var moment := "idle"

	func _ready() -> void:
		args = Shot.args if Shot else {}
		cls = String(args.get("class", "knight"))
		moment = String(args.get("moment", "idle"))
		c = GameController.new()
		c.autosave = false
		c.persist_profile = false
		c.minigame_fallback = false
		EncounterCards.reset()
		EncounterCards.cards_off = true
		add_child(c)
		c.set_speed(float(args.get("speed", "1")))
		f = _flow(int(args.get("seed", "7")))
		match moment:
			"star_board":
				f = _star_seed()
			"shadow_step":
				f = _refund_seed()
		c.start(f)
		await _pause(0.4)
		match moment:
			"board":
				await _pause(0.6)
			"star_board":
				await _cmd("roll_board", [], "board_rolled", 0.6)
			"overgrowth":
				await _lap()
			"seed":
				await _biome()
			_:
				await _fight()
		print("CLASS_MOMENT %s %s" % [cls, moment])

	func _flow(seed: int) -> GameFlow:
		var o := {}
		var g := GameFlow.new_run(cls, seed, Balance.BOARD_SIZE, o)
		g.run.skin = String(args.get("skin", "default"))
		g.run.skin_prestige = String(args.get("prestige", "0")) == "1"
		return g

	## A seed whose first board roll shows the Monster Kid's ★ face.
	func _star_seed() -> GameFlow:
		for s in range(7, 400):
			var g := _flow(s)
			var probe := GameFlow.from_dict(g.to_dict())
			for e: Dictionary in probe.roll_board():
				if String(e.get("type", "")) == "dice_rolled" and not (e.get("pretend", []) as Array).is_empty():
					return g
		return f

	## A seed where rerolling the first die of the first fight refunds (Shadow Step).
	func _refund_seed() -> GameFlow:
		for s in range(7, 400):
			var g := _flow(s)
			var probe := GameFlow.from_dict(g.to_dict())
			probe.debug_open("combat", _enemies())
			probe.combat_toggle(0)
			for e: Dictionary in probe.combat_reroll():
				if String(e.get("type", "")) == "class_triggered" and String(e.get("id", "")) == "shadow_step":
					print("REFUND_SEED ", s)
					return g
		return f

	func _enemies() -> String:
		var d := "skeleton_warrior,skeleton_minion"
		match moment:
			"pierce", "bones", "bone_die":
				d = "skeleton_minion,skeleton_warrior"
			"boo", "cower":
				d = "skeleton_warrior,skeleton_minion"
			"flee":
				d = "skeleton_minion,skeleton_warrior"
		return String(args.get("enemies", d))

	func _fight() -> void:
		f.run.pos = int(args.get("tile", "3"))
		c.board.place_hero(f.run.pos)
		var ev := f.debug_open("combat", _enemies())
		if moment == "oath":
			await _play_until(ev, "class_triggered", 0.55)
			return
		await c.play_events(ev)
		var cs := f.combat
		match moment:
			"idle":
				_force(_idle_values())
				await _pause(0.9)
				_freeze()
			"oath_kept":
				_force(_fill([cs.oath, cs.oath], 2))
				await _pause(0.6)
				await _cmd("combat_attack", [], "combo", 0.5)
			"aim":
				_force(_fill([6, 6], 3))
				await _pause(0.5)
				await _cmd("combat_attack", [], "class_triggered", 0.3)
			"pierce":
				cs.enemies[0].hp = 3
				c.stage.set_enemy(0, {"hp": 3})
				_force(_fill([6, 6], 3))
				await _pause(0.5)
				await _cmd("combat_attack", [], "class_triggered", 0.28, "piercing_shot")
			"shadow_step":
				await c.run_command("combat_toggle", [0])
				await _pause(0.3)
				await _cmd("combat_reroll", [], "class_triggered", 0.3, "shadow_step")
			"turret":
				_force(_fill([3, 3], 2))
				await _pause(0.5)
				await _cmd("combat_attack", [], "turret_fired", 0.5)
			"bones", "bone_die":
				cs.enemies[0].hp = 2
				c.stage.set_enemy(0, {"hp": 2})
				_force(_fill([5, 5], 2))
				await _pause(0.5)
				if moment == "bones":
					await _cmd("combat_attack", [], "class_triggered", 0.45, "bone_harvest")
				else:
					await _cmd("combat_attack", [], "die_added", 0.8)
			"boo", "cower", "flee":
				if moment == "flee":
					# a Pair of 1s (★ + 1) hits for 3: the foe drops under a quarter of its HP
					cs.enemies[0].hp = mini(int(cs.enemies[0].max_hp), int(floor(cs.enemies[0].max_hp * ClassLogic.FLEE_PCT)) + 2)
					c.stage.set_enemy(0, {"hp": int(cs.enemies[0].hp)})
				cs.target = 0
				c.stage.set_target(0)
				_force(_fill([Die.PRETEND, 1], 2))
				await _pause(0.9)
				var key := {"boo": "enemy_scared", "cower": "status", "flee": "enemy_fled"}[moment] as String
				await _cmd("combat_attack", [], key, {"boo": 0.35, "cower": 0.3, "flee": 0.9}[moment] as float,
					"cower" if moment == "cower" else "")
			_:
				_freeze()

	## Dice values for the idle shot: the class's moment on show (Oath dice, a ★, bones).
	func _idle_values() -> Array:
		var cs := f.combat
		match HeroDefs.mechanic(cls):
			"oath":
				return _fill([cs.oath, cs.oath], 2)
			"boo":
				return _fill([Die.PRETEND, 5], 2)
			"bone_harvest":
				for k in 2:
					var d := Die.make("", "bone")
					d.add_tag("bone")
					cs.extra_dice.append(d)
				cs.bones_raised = 2
				ClassBeats.sync_tray(c)
				return _fill([4, 2, 3, 2], 4)
		return cs.dice_values.duplicate()

	## `vals` first, then the dice's current values, sized to the combat pool.
	func _fill(vals: Array, _n: int) -> Array:
		var cs := f.combat
		var out: Array = cs.dice_values.duplicate()
		var size := cs.pool_dice(f.run).size()
		out.resize(size)
		for i in size:
			if i < vals.size():
				out[i] = int(vals[i])
			elif out[i] == null:
				out[i] = 1
		return out

	## Puts values on the combat dice (as if rolled) and shows them.
	func _force(vals: Array) -> void:
		var cs := f.combat
		cs.dice_values.resize(vals.size())
		for i in vals.size():
			cs.dice_values[i] = int(vals[i])
		for arr in [cs.marked, cs.locked, cs.rerolled]:
			(arr as Array).resize(vals.size())
			for i in vals.size():
				if arr[i] == null:
					arr[i] = false
		ClassBeats.sync_tray(c)
		c.tray.set_values(cs.dice_values)
		c.ui.combat_hud.refresh(f)
		c.ui.combat_hud.top.class_badge.sync(f)
		ClassBeats.after_combat_roll(c)

	## Board: the hero crosses Start (a lap completes: seeds grow).
	func _lap() -> void:
		f.run.lap = 2
		var n := f.run.board.size()
		f.run.pos = n - 2
		c.board.place_hero(f.run.pos)
		c.ui.sync(f)
		c.rig.home(c.board.hero, true)
		await _pause(0.5)
		_calm_tile(posmod(f.run.pos + 4, n))
		var ev := f._move(4, false)
		f._advance(ev)
		await _play_until(ev, "face_changed", 0.35)

	## Board: a biome change (lap 5 -> 6) plants a seed.
	func _biome() -> void:
		f.run.lap = int(Balance.BIOME_LAPS[1]) - 1
		var n := f.run.board.size()
		f.run.pos = n - 2
		c.board.place_hero(f.run.pos)
		c.ui.sync(f)
		c.rig.home(c.board.hero, true)
		await _pause(0.5)
		_calm_tile(posmod(f.run.pos + 4, n))
		var ev := f._move(4, false)
		f._advance(ev)
		await _play_until(ev, "die_tagged", 0.45)

	## Makes the landing tile an empty one (no modal over the board moment).
	func _calm_tile(i: int) -> void:
		if i != 0:
			f.run.board.tiles[i] = Board.make_tile("empty")
			c.board.set_tile(i, f.run.board.tiles[i], false)

	## Plays `ev` one by one; on the first event of `type`, starts it and freezes `hold` later.
	func _play_until(ev: Array, type: String, hold: float, id := "") -> void:
		for e: Dictionary in ev:
			if moment in ["overgrowth", "seed"] and String(e.get("type", "")) in ["offer_opened", "minigame_started"]:
				continue
			if String(e.get("type", "")) == type and (id == "" or String(e.get("id", e.get("status", ""))) == id):
				c.play_events([e])
				await _pause(float(args.get("hold", str(hold))))
				if moment in ["overgrowth", "seed"]:
					c.close_modals()
				_freeze()
				return
			await c.play_events([e])
		_freeze()

	## Applies a command to the flow and plays its events like _play_until.
	func _cmd(cmd: String, cargs: Array, type: String, hold: float, id := "") -> void:
		var evs: Array = f.callv(cmd, cargs)
		await _play_until(evs, type, hold, id)

	func _freeze() -> void:
		print("FREEZE %s" % moment)
		get_tree().paused = true

	func _pause(t: float) -> void:
		await get_tree().create_timer(t).timeout
