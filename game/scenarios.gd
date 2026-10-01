extends RefCounted
## Integration scenarios for the screenshot harness (tools/shot.gd): the real game
## (GameController + GameFlow) in a given state. They never touch the player's save.
##
##  game_title    title screen over the orbiting act 1 board
##  game_board    fresh run, BOARD_READY (--passives=N shows N passives in the HUD bar;
##                --affixes=a,b,... deals affixes to the fight tiles: preview overlays + chips)
##  game_rolled   after ROLL: the two moving dice lifted, the rest dimmed, the move pill,
##                the target marker and GO. 4 dice by default (--dice=N, 2..5); --double=1
##                searches seeds for a doubles roll (celebration + treasury)
##  game_combat   mid-fight, dice marked for a reroll (--tile=N, --enemies=a,b,c). Enemy affixes:
##                --affixes=thorned,warded,-,gilded+hexing (one per enemy in order; "-" none, "+"
##                two), --elite=1. --cards=0 skips the first-encounter cards (on by default: a
##                fresh profile meets everything), --tip=I[:K] opens enemy I's affix badge K
##                tooltip, --turns=N plays N ATTACK turns (procs, rally, transform)
##  game_combo    mid-fight right after ATTACK (combo banner held on screen)
##  game_shop     shop with a die kind and a passive card (+ the regular stock)
##  game_draft / game_forge / game_event / game_portal   modals and picks
##  game_passive  passive reward modal (--source=miniboss|elite|boss; miniboss = boss tier)
##  game_die_inspect   die inspector on a Giant die with a rune (--die=N)
##  game_miniboss the lap 7 mini-boss appearing on the board (--fight=1: fight it)
##  game_biome_change  lap 6 starts mid-move: tier 1 sinks, tier 2 rises (--to=<biome id>
##                picks the arriving biome; tier 3 ids start at lap 11). Use --wait and --frames.
##  game_boss     final boss fight with its intro (--act=1..3)
##  game_victory / game_defeat   summary screens (with passives and the route)
##  route_card    the run-start route card (--route=a,b,c --boss --miniboss)
##  game_pause    pause menu mid-run with the route strip (--lap=N, default 8)
##  game_continue runs --steps=N bot commands, JSON round-trips the run and presents it
##  game_manual   drives the UI like a player (ROLL -> GO -> fight -> ATTACK -> draft),
##                saving a shot per step: <shot>_step_NN.png
##  play_auto     full run driven by Bot through the real presentation; periodic shots
##                <shot>_NN.png (--shots=N --every=S), final shot <shot>_final.png, quits at
##                game end or --timeout. Run it with a large --wait (e.g. --wait=5000).
##                Runs start from a profile (--profile=fresh|mid|max, --profile-file=<json>)
##                and are banked; --runs=N chains runs through results -> Camp (see _auto()).
##                --ui-auto=1 drives it through the real AUTO toggle (AutoPilot + Bot.decide)
##                instead (--auto-rules=all|default, --stop=boss,miniboss,passive,shop).
##  ui_speed_auto / ui_auto_settings / game_auto   see game/auto/auto_scenarios.gd
##
## Common args: --class=knight|barbarian|mage|rogue --seed=N --act=N --speed=N
##   --route=a,b,c --biome=<id> --boss=<id> --miniboss=<id> (new_run opts)

const NAMES := ["game_title", "game_board", "game_rolled", "game_combat", "game_combo", "game_shop", "game_draft",
	"game_forge", "game_event", "game_portal", "game_boss", "game_victory", "game_defeat", "game_manual", "game_continue",
	"play_auto", "game_passive", "game_die_inspect", "game_miniboss", "game_biome_change", "route_card", "game_pause"]
## Passives shown by --passives=N (a mix of rarities, boss tier last).
const DEMO_PASSIVES := ["pair_master", "iron_skin", "pathfinder", "rune_echo", "treasure_sense", "fast_feet", "midas_fist"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES + AutoScenarios.NAMES)


static func build(name: String) -> Node:
	if AutoScenarios.NAMES.has(name):
		return AutoScenarios.build(name)
	if not NAMES.has(name):
		return null
	var d := _Driver.new()
	d.name = "GameScenario"
	d.scenario = name
	return d


class _Driver extends Node:
	var scenario := ""
	var c: GameController
	var args: Dictionary = {}
	var _shot_base := ""
	var _t0 := 0

	func _ready() -> void:
		args = Shot.args if Shot else {}
		_shot_base = String(args.get("shot", "user://auto.png")).get_basename()
		c = GameController.new()
		c.autosave = false
		c.persist_profile = false
		c.minigame_fallback = false
		EncounterCards.reset()
		EncounterCards.cards_off = String(args.get("cards", "1")) == "0"
		add_child(c)
		c.set_speed(float(args.get("speed", "3" if scenario == "play_auto" else "1")))
		match scenario:
			"game_title":
				c.show_title()
			"play_auto":
				await _auto()
			"game_manual":
				await _manual()
			"game_continue":
				_continue()
			_:
				await _state()

	func _flow() -> GameFlow:
		var cls := String(args.get("class", "knight"))
		var seed := int(args.get("seed", "7"))
		var f := GameFlow.new_run(cls, seed, Balance.BOARD_SIZE, run_opts())
		var act := int(args.get("act", "1"))
		if args.has("biome"):
			act = BoardScenarios.tier_of(String(args.biome))
		if act > 1:
			f.run.act = act
			f.run.lap = int(Balance.BIOME_LAPS[act - 1]) + 1
			f.run.board = Board.generate(f.run.rng, act, Balance.BOARD_SIZE, f.run.lap, f.run.biome())
			f.run.level = 2 + act * 3
			f.run.max_hp += 16 * (act - 1)
			f.run.hp = f.run.max_hp
			for k in ["high", "giant", "twin"].slice(0, act):
				f.run.dice.append(Die.make("", k))
		for k in int(args.get("passives", "0")):
			f.run.passives.append(DEMO_PASSIVES[k % DEMO_PASSIVES.size()])
		return f

	## new_run opts from the args: --route=glade,frost,magma (or --biome=<id>, which puts that
	## biome on a default route), --boss=<id>, --miniboss=<id>.
	func run_opts() -> Dictionary:
		var o := {}
		var route: Array = ["crypt", "hollow", "throne"]
		if args.has("route"):
			route = Array(String(args.route).split(",", false))
		if args.has("biome"):
			var b := String(args.biome)
			route[BoardScenarios.tier_of(b) - 1] = b
		if args.has("route") or args.has("biome"):
			o["route"] = route
		if args.has("boss"):
			o["boss"] = String(args.boss)
		if args.has("miniboss"):
			o["miniboss"] = String(args.miniboss)
		if args.has("profile"):
			# meta layer on: --profile=fresh|mid|max [--pet=<id>] [--asc=N]
			var prof := MetaPresets.get_preset(String(args.profile), int(args.get("asc", "0")))
			if args.has("pet"):
				(prof.loadout as Dictionary)["pet"] = String(args.pet)
			o["profile"] = prof
		return o

	## A die pool of `n` (2..5) with a spread of kinds (and one rune) for dice-heavy shots.
	func _pool(f: GameFlow, n: int) -> void:
		var kinds := ["standard", "standard", "giant", "low", "gambler"]
		f.run.dice.clear()
		for k in clampi(n, 2, 5):
			f.run.dice.append(Die.make("", kinds[k]))
		if n >= 3:
			f.run.dice[2].rune = "blade"

	func _state() -> void:
		var f := _flow()
		match scenario:
			"game_portal":
				f.run.pos = f.run.board.size() * 3 / 4
			"game_boss":
				f.run.pos = 0
				f.run.lap = Balance.TOTAL_LAPS
			"game_rolled":
				_pool(f, int(args.get("dice", "4")))
				if args.get("double", "0") == "1":
					f = _double_seed(f)
			"game_die_inspect":
				_pool(f, 4)
				f.run.dice[2].rune = "ember"
				f.run.dice[2].raise_face(0)
			"game_shop":
				_pool(f, 3)
		if scenario == "game_board" and args.has("affixes"):
			# --affixes=a,b,...: dealt round-robin to the fight tiles' leaders (board preview chips)
			var al: Array = Array(String(args.affixes).split(",", false))
			var n := 0
			for t: Dictionary in f.run.board.tiles:
				if String(t.type) in ["enemy", "elite", "miniboss"] and not (t.enemies as Array).is_empty():
					var ea: Array = []
					for k in (t.enemies as Array).size():
						ea.append([String(al[n % al.size()])] if k == 0 else [])
					t["enemy_affixes"] = ea
					n += 1
		c.start(f)
		await get_tree().create_timer(0.3).timeout
		match scenario:
			"game_rolled":
				await c.run_command("roll_board")
			"game_passive":
				await c.play_events(f.debug_open("passive", String(args.get("source", "miniboss"))))
			"game_die_inspect":
				await get_tree().create_timer(0.4).timeout
				c.inspect_die(int(args.get("die", "2")))
			"game_miniboss":
				await _miniboss(f)
			"game_biome_change":
				await _biome_change(f)
			"game_combat", "game_combo":
				var ids := String(args.get("enemies", "skeleton_warrior,skeleton_minion,skeleton_archer"))
				f.run.pos = int(args.get("tile", "3"))
				c.board.place_hero(f.run.pos)
				if args.has("affixes") or args.has("elite"):
					var affs: Array = []
					for part in String(args.get("affixes", "")).split(",", true):
						affs.append(Array(part.split("+", false)).filter(func(x: String) -> bool: return AffixDefs.DATA.has(x)))
					var ev: Array[Dictionary] = []
					f._start_combat(Array(ids.split(",", false)), args.has("elite"), false, f.run.pos, ev, false, affs)
					await c.play_events(ev)
				else:
					await c.play_events(f.debug_open("combat", ids))
				for t in int(args.get("turns", "0")):
					if f.combat == null or f.phase != GameFlow.Phase.COMBAT:
						break
					await c.run_command("combat_attack")
				# mark dice for a reroll like a player would (bot choice), stop before ATTACK
				for k in 8:
					var cmd := Bot.next_command(f)
					if cmd[0] != "combat_toggle" and cmd[0] != "combat_set_target":
						break
					await c.run_command(cmd[0], cmd.slice(1))
				if args.has("tip") and AffixTips.of(c):
					var tp := String(args.tip).split(":")
					AffixTips.of(c).show_tip(int(tp[0]), int(tp[1]) if tp.size() > 1 else 0, 60.0)
				if scenario == "game_combo":
					c.ui.banner.hold = true
					if f.combat.rerolls_left > 0 and f.combat.marked.has(true):
						await c.run_command("combat_reroll")
					await c.run_command("combat_attack")
			"game_shop":
				f.run.gold = 160
				var ev := f.debug_open("shop")
				# make sure the stock shows a die kind and a passive card
				var items: Array = f.offer.items
				var die_item := f._shop_item("die", {})
				die_item.kind = "giant"
				die_item.label = DiceKinds.label("giant")
				die_item.desc = String(DiceKinds.DEFS.giant.desc)
				die_item.price = int(DiceKinds.DEFS.giant.price)
				var pas := f._shop_item("passive", {})
				items.clear()
				items.append(die_item)
				items.append(pas)
				items.append(f._shop_item("rune", {}))
				items.append(f._shop_item("potion", {}))
				await c.play_events(ev)
			"game_draft":
				await c.play_events(f.debug_open("draft"))
			"game_forge":
				await c.play_events(f.debug_open("forge"))
			"game_event":
				await c.play_events(f.debug_open("event", String(args.get("event", "duel"))))
			"game_portal":
				await c.play_events(f.debug_open("portal"))
			"route_card":
				c.ui.show_route(f)
			"game_pause":
				f.run.lap = int(args.get("lap", "8"))
				f.run.act = Balance.act_for_lap(f.run.lap)
				c.ui.sync(f)
				# finish the run's fade-in first: the pause freezes the overlay's tweens, which
				# left a half-faded dim over the whole pause menu
				c.overlay.fade_in(0.01)
				await get_tree().create_timer(0.1, true, false, true).timeout
				c.ui.open_pause()
			"game_boss":
				await c.play_events(f.debug_open("boss", String(args.get("boss", ""))))
			"game_victory", "game_defeat":
				f.run.stats.merge({"fights_won": 21, "damage_dealt": 2140, "damage_taken": 388, "gold_earned": 512,
					"best_combo": "Full House", "best_mult": 4.0, "board_turns": 47, "max_act": 3 if scenario == "game_victory" else 2}, true)
				var ev: Array[Dictionary] = []
				f._finish(scenario == "game_victory", ev)
				await c.play_events(ev)

	## A copy of `f` re-seeded until its first board roll is a doubles roll (so the scenario
	## shows the doubles celebration). Falls back to `f`.
	func _double_seed(f: GameFlow) -> GameFlow:
		var base := int(args.get("seed", "7"))
		for s in range(base, base + 400):
			var g := GameFlow.new_run(f.run.class_id, s)
			g.run.dice = f.run.dice
			var probe := GameFlow.from_dict(g.to_dict())
			probe.roll_board()
			if probe.is_board_double() and probe.board_move > 0:
				print("DOUBLE_SEED ", s)
				return g
		return f

	## Lap 7 begins: the mini-boss tile bursts onto the act 2 board (--fight=1: then fight it).
	func _miniboss(f: GameFlow) -> void:
		await get_tree().create_timer(0.5).timeout
		f.run.lap = Balance.MINIBOSS_LAP
		var mb := f.run.board.spawn_miniboss(f.run.rng, f.run.miniboss_id, f.run.pos, [f.run.pos])
		if mb.is_empty():
			return
		await c.play_events([{"type": "board_mutated", "changes": [mb]}])
		if args.get("fight", "0") == "1":
			f.run.pos = int(mb.idx)
			c.board.place_hero(f.run.pos)
			var ev: Array[Dictionary] = []
			f._start_combat(f.run.board.tiles[f.run.pos].enemies, false, false, f.run.pos, ev, true)
			await c.play_events(ev)

	## The hero crosses Start into lap 6 (or 11): the biome changes around them. --to=<biome
	## id> picks the arriving biome (tier 2 -> lap 6, tier 3 -> lap 11); --to=2|3 as before.
	func _biome_change(f: GameFlow) -> void:
		var to_arg := String(args.get("to", "2"))
		var tier := int(to_arg) if to_arg.is_valid_int() else BoardScenarios.tier_of(to_arg)
		tier = clampi(tier, 2, 3)
		if not to_arg.is_valid_int():
			f.run.route[tier - 1] = to_arg
		if tier == 3:
			f.run.act = 2
			f.run.board = Board.generate(f.run.rng, 2, Balance.BOARD_SIZE, 10, f.run.biome())
			c.board.build(f.run.biome(), f.run.board.to_dict().tiles)
		f.run.lap = int(Balance.BIOME_LAPS[tier - 1]) - 1
		var n := f.run.board.size()
		f.run.pos = n - 3
		c.board.place_hero(f.run.pos)
		c.ui.sync(f)
		c.rig.home(c.board.hero, true)
		await get_tree().create_timer(0.6).timeout
		var ev := f._move(5, false)
		f._advance(ev)
		await c.play_events(ev)
	## the save does) and presents the loaded copy: checks Continue for mid-run phases.
	func _continue() -> void:
		var f := _flow()
		for k in int(args.get("steps", "60")):
			if f.is_over():
				break
			f.apply(Bot.next_command(f))
		var loaded := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
		print("CONTINUE phase=%s act=%d lap=%d pos=%d" % [GameFlow.phase_name(loaded.phase), loaded.run.act, loaded.run.lap, loaded.run.pos])
		c.start(loaded)

	# --- manual-style drive through the UI signals ------------------------------------------

	func _manual() -> void:
		var f := _flow()
		# Make the edge tiles 1..12 enemies so any 2-dice roll lands in a fight.
		for i in range(1, 13):
			if not f.run.board.is_corner(i):
				f.run.board.tiles[i] = Board.make_tile("enemy", ["skeleton_minion"])
		f.run.xp = Balance.xp_for_level(1) - 1  # the first win levels up -> draft
		c.start(f)
		var step := 0
		await _pause(0.8)
		step = await _step(step, "board ready")
		c.ui.board_hud.roll_pressed.emit()
		await c.idle
		step = await _step(step, "rolled")
		# the move is automatic: press GO
		c.ui.board_hud.go_pressed.emit()
		await c.idle

		step = await _step(step, "fight started")
		var guard := 0
		while f.phase == GameFlow.Phase.COMBAT and guard < 30:
			guard += 1
			c.ui.combat_hud.attack_pressed.emit()
			await c.idle
			step = await _step(step, "after attack %d (phase %s)" % [guard, GameFlow.phase_name(f.phase)])
		if f.phase == GameFlow.Phase.DRAFT:
			await _pause(0.6)
			step = await _step(step, "draft open")
			c.ui.draft.draft_picked.emit(0)
			await c.idle
			step = await _step(step, "after draft pick (phase %s)" % GameFlow.phase_name(f.phase))
		print("MANUAL_DONE phase=%s hp=%d gold=%d level=%d" % [GameFlow.phase_name(f.phase), f.run.hp, f.run.gold, f.run.level])
		await _quit(0)

	func _step(n: int, what: String) -> int:
		await _pause(0.35)
		var path := "%s_step_%02d.png" % [_shot_base, n]
		await _save(path)
		print("STEP %02d %s -> %s" % [n, what, path])
		return n + 1

	# --- full auto run ------------------------------------------------------------------------

	## play_auto: runs start from a meta profile (never the legacy no-profile path) and are
	## banked into it. --profile=fresh|mid|max (default fresh) picks the starting profile;
	## --profile-file=<abs path> loads it from (and saves it back to) a JSON file, creating it from
	## the preset the first time, so separate invocations continue one campaign. --runs=N plays N
	## runs back to back through the results screen and the Camp (shots <shot>_results_NN.png and
	## <shot>_camp_NN.png), spending Crowns / Sigils between runs with BotMeta (--spend=0 skips).
	func _auto() -> void:
		var pf := String(args.get("profile-file", ""))
		c.profile = ProfileStore.load_profile(pf) if pf != "" else null
		if c.profile == null:
			c.profile = load("res://game/camp/scenarios.gd").preset(String(args.get("profile", "fresh")))
			if String(args.get("profile", "fresh")) == "fresh":
				c.profile = Profile.fresh()
		c.persist_profile = pf != ""
		if pf != "":
			c.profile_path = pf
			c.save_profile()
		c.ensure_profile()
		var runs := maxi(1, int(args.get("runs", "1")))
		var code := 0
		for k in runs:
			if args.has("class"):
				c.profile.loadout["class"] = String(args["class"])
			var f := GameFlow.new_run(String(c.profile.loadout.get("class", "knight")), int(args.get("seed", "7")) + k,
				Balance.BOARD_SIZE, c.run_opts().merged(run_opts(), true))
			print("AUTO_PROFILE run=%d/%d runs_banked=%d crowns=%d sigils=%d classes=%s pets=%s gear=%s meta=%s" % [k + 1, runs,
				int(c.profile.records.get("runs", 0)), c.profile.crowns, c.profile.sigils, str(c.profile.unlocks.classes),
				str(c.profile.unlocks.pets), str(c.profile.armory.get("ranks", {})), str(not f.run.meta.is_empty())])
			if String(args.get("ui-auto", "0")) == "1":
				code = await AutoScenarios.run_ui_auto(self, c, f, args, _shot_base)
			else:
				code = await _auto_run(f)
			if code != 0:
				break
			await _pause(3.5)
			await _save("%s_results_%02d.png" % [_shot_base, k + 1] if runs > 1 else "%s_final.png" % _shot_base)
			if runs > 1:
				await c.show_camp()
				await _pause(0.8)
				if String(args.get("spend", "1")) == "1":
					_spend()
				await _pause(1.6)
				await _save("%s_camp_%02d.png" % [_shot_base, k + 1])
		print("AUTO_CAMPAIGN_END runs=%d crowns=%d sigils=%d milestones=%s unlocked_classes=%s pets=%s gear=%s" % [
			int(c.profile.records.get("runs", 0)), c.profile.crowns, c.profile.sigils, str(c.profile.milestones),
			str(c.profile.unlocks.classes), str(c.profile.unlocks.pets), str(c.profile.armory.get("ranks", {}))])
		await _quit(code)

	## Between runs: spend like the campaign bot, then pick the loadout (least-played class).
	func _spend() -> void:
		var bought := BotMeta.spend(c.camp)
		var lo := BotMeta.choose_loadout(c.profile)
		c.camp.set_loadout(lo[0], String(lo[1]))
		var best := String(c.profile.loadout.get("class", "knight"))
		var rbc: Dictionary = c.profile.records.get("runs_by_class", {})
		for id in HeroDefs.IDS:
			if c.profile.class_allowed(String(id)) and int(rbc.get(id, 0)) < int(rbc.get(best, 0)):
				best = String(id)
		c.camp.set_class(best)
		c.save_profile()
		c.camp_scene.apply_profile(c.profile)
		c.ui.camp.show_profile(c.profile, false)
		print("AUTO_SPEND bought=%s loadout=%s class=%s crowns_left=%d sigils_left=%d" % [str(bought), str(lo), best,
			c.profile.crowns, c.profile.sigils])

	## One run driven by the greedy Bot through the real presentation; 0 = finished.
	func _auto_run(f: GameFlow) -> int:
		var shots := int(args.get("shots", "25"))
		var every := float(args.get("every", "8"))
		var timeout := float(args.get("timeout", "1500"))
		_t0 = Time.get_ticks_msec()
		print("AUTO_START class=%s seed=%d speed=%.1f" % [f.run.class_id, f.run.seed, c.speed])
		c.start(f)
		_shooter(shots, every)
		var last_phase := -1
		var last_act := 0
		var errors := 0
		var stuck := 0
		while not f.is_over():
			if _elapsed() > timeout:
				print("AUTO_TIMEOUT after %.0fs phase=%s" % [_elapsed(), GameFlow.phase_name(f.phase)])
				return 3
			if f.phase != last_phase or f.run.act != last_act:
				last_phase = f.phase
				last_act = f.run.act
				print("PHASE %s act=%d lap=%d pos=%d hp=%d/%d gold=%d lvl=%d dice=%d t=%.0fs" % [GameFlow.phase_name(f.phase),
					f.run.act, f.run.lap, f.run.pos, f.run.hp, f.run.max_hp, f.run.gold, f.run.level, f.run.dice.size(), _elapsed()])
			if c.busy:
				await get_tree().process_frame
				continue
			var cmd := Bot.next_command(f)
			var n := f.commands.size()
			var evs: Array = f.apply(cmd)
			for ev: Dictionary in evs:
				if String(ev.get("type", "")) == "error":
					errors += 1
					print("ERROR_EVENT %s -> %s" % [str(cmd), String(ev.get("msg", ""))])
				elif String(ev.get("type", "")) == "level_up" and c.ui.draft.visible:
					print("LEVEL_UP_DRAFT_OPENED (should never happen)")
			if f.commands.size() == n:
				stuck += 1
				if stuck > 5:
					print("AUTO_STUCK on %s" % str(cmd))
					return 4
			else:
				stuck = 0
			if args.has("trace"):
				print("EVENTS ", ",".join(evs.map(func(e: Dictionary) -> String: return String(e.get("type", "")))))
			await c.play_events(evs)
			# a real player needs a beat to look; keep it short at auto speed
			await c.wait(0.15)
		var won := f.phase == GameFlow.Phase.VICTORY
		print("AUTO_END %s act=%d lap=%d lvl=%d commands=%d errors=%d t=%.0fs" % ["VICTORY" if won else "GAME_OVER",
			f.run.act, f.run.lap, f.run.level, f.commands.size(), errors, _elapsed()])
		return 0

	func _shooter(n: int, every: float) -> void:
		for i in n:
			await get_tree().create_timer(every, true, false, true).timeout
			if not is_inside_tree():
				return
			await _save("%s_%02d.png" % [_shot_base, i + 1])

	func _elapsed() -> float:
		return (Time.get_ticks_msec() - _t0) / 1000.0

	func _pause(t: float) -> void:
		await get_tree().create_timer(t, true, false, true).timeout

	func _save(path: String) -> void:
		if Shot and Shot.has_method("_save"):
			await Shot._save(path)

	func _quit(code: int) -> void:
		Audio.stop_all()
		c.queue_free()
		for i in 3:
			await get_tree().process_frame
		Character.clear_cache()
		get_tree().quit(code)
