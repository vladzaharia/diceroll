extends RefCounted
## Camp scenarios for the screenshot harness (tools/shot.gd). They never touch the player's
## profile or run save (the controller's autosave and profile persistence are off).
##
##  camp_raw        the 3D CampScene alone (art iteration; --profile=fresh|mid|max, --pet=<id>)
##  camp_first      the Camp on a fresh profile, with the first-launch welcome
##  camp_mid / camp_max   the Camp on the mid / max preset profiles
##  camp_stage_0..3 the Camp as it builds out: fresh, and a realistic campaign's profile after
##                  runs 3, 10 and 25 (game/camp/stages/, made by tools/camp_stages.gd)
##  camp_reveal     the build-out moments after a fresh profile's first run (use --frames)
##  camp_life       camp life on --profile=stage_2|stage_3|max (default stage_3): campers walk,
##                  spar, chat and tinker, pets roam (use --frames; --clean hides the UI)
##  ui_armory / ui_workshop / ui_petden / ui_arcade / ui_run_setup   a Camp screen open
##                  (--profile=fresh|mid|max, default mid; --scroll=N scrolls the screen)
##  ui_results_win / ui_results_loss   the results screen after banking a run (the loss is a
##                  fresh profile's first run: milestone unlock cards; the win a mid profile)
##  flow_first_run  title -> PLAY -> Camp (welcome) -> START RUN -> setup -> START -> route
##                  card, one shot per step: <shot>_step_NN.png

const NAMES := ["camp_raw", "camp_first", "camp_mid", "camp_max", "ui_armory", "ui_workshop", "ui_petden", "ui_arcade",
	"ui_run_setup", "ui_results_win", "ui_results_loss", "flow_first_run", "camp_stage_0", "camp_stage_1", "camp_stage_2",
	"camp_stage_3", "camp_reveal", "camp_life"]
const SCREENS := {"ui_armory": "armory", "ui_workshop": "workshop", "ui_petden": "pet_den", "ui_arcade": "arcade",
	"ui_run_setup": "setup"}


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var d := _Driver.new()
	d.name = "CampScenario"
	d.scenario = name
	return d


## A preset profile by name, with a few extra touches so shots look lived-in.
static func preset(name: String) -> Profile:
	if name.begins_with("stage_"):
		if name == "stage_0":
			return Profile.fresh()
		return ProfileStore.load_profile("res://game/camp/stages/%s.json" % name)
	var p := Profile.from_dict(MetaPresets.get_preset(name))
	match name:
		"mid":
			p.crowns = 142
			p.sigils = 7
			p.records.runs = 10
			p.records.wins = 4
			p.records.firsts.boss = ["boss_lich"]
			p.records.firsts.class_win = ["knight"]
			p.milestones = ["first_steps", "lap_five", "wanderer", "brawler", "gate_crasher", "arcade_regular", "victor", "deep_delver"]
		"max":
			p.crowns = 1260
			p.sigils = 23
			p.records.runs = 80
			p.records.wins = 52
			p.records.firsts.boss = ["boss_lich", "boss_bone_warden", "boss_cinder_king", "boss_magma_golem"]
			p.records.firsts.class_win = ["knight", "barbarian", "mage", "rogue"]
			for m in UnlockDefs.MILESTONES:
				p.milestones.append(m.id)
	return p


class _Driver extends Node:
	var scenario := ""
	var c: GameController
	var args: Dictionary = {}

	func _ready() -> void:
		var shot: Node = get_tree().root.get_node_or_null("Shot")
		args = shot.args if shot else {}
		if scenario == "camp_raw":
			var camp := CampScene.new()
			add_child(camp)
			var p := _preset(String(args.get("profile", "mid")))
			camp.apply_profile(p)
			if args.has("pet"):
				camp.set_pet(String(args.pet))
			camp.camera().make_current()
			return
		c = GameController.new()
		c.autosave = false
		c.persist_profile = false
		add_child(c)
		match scenario:
			"camp_first":
				c.profile = Profile.fresh()
				c.profile_is_new = true
				c.show_camp()
			"camp_mid", "camp_max", "camp_stage_0", "camp_stage_1", "camp_stage_2", "camp_stage_3":
				c.profile = _preset(scenario.substr(5))
				c.show_camp()
			"camp_life":
				c.profile = _preset(String(args.get("profile", "stage_3")))
				c.show_camp()
				if args.has("clean"):
					c.ui.camp.visible = false
			"camp_reveal":
				# a fresh profile's first run (lost on lap 6) is banked, then the Camp builds out
				c.profile = Profile.fresh()
				c.ensure_profile()
				c.camp_before = CampState.of(c.profile)
				var f := GameFlow.new_run("knight", 5, Balance.BOARD_SIZE, {"profile": c.profile.to_dict()})
				f.run.lap = 6
				f.run.act = 2
				f.run.stats.merge({"fights_won": 12, "max_act": 2}, true)
				var ev: Array[Dictionary] = []
				f._finish(false, ev)
				c.camp.bank_run(ev.back().stats)
				c.set_speed(float(args.get("speed", "1")))
				c.show_camp()
			"ui_results_win", "ui_results_loss":
				await _results(scenario == "ui_results_win")
			"flow_first_run":
				await _first_run()
			_:
				c.profile = _preset(String(args.get("profile", "mid")))
				c.show_camp()
				await get_tree().create_timer(0.2).timeout
				c.ui.camp.open_station(String(SCREENS[scenario]))
				if args.has("debug"):
					await get_tree().create_timer(1.0).timeout
					var dm: CampModal = c.ui.camp.modal(String(SCREENS[scenario]))
					print("DEBUG frame pos=%s size=%s mod=%s scale=%s panel=%s inner=%s scroll=%s vis=%s" % [dm._frame.position, dm._frame.size,
						dm._frame.modulate, dm._frame.scale, dm.panel.size, dm._inner.get_combined_minimum_size(), dm._scroll.custom_minimum_size, dm.visible])
				if args.has("scroll"):
					await get_tree().create_timer(0.5).timeout
					var m: CampModal = c.ui.camp.modal(String(SCREENS[scenario]))
					m._scroll.scroll_vertical = int(args.scroll)

	func _preset(n: String) -> Profile:
		return load("res://game/camp/scenarios.gd").preset(n)

	## A finished run banked into a profile, then the results screen.
	func _results(win: bool) -> void:
		c.profile = _preset("mid" if win else "fresh")
		var p := c.profile
		var f := GameFlow.new_run(String(p.loadout.get("class", "knight")), 11, Balance.BOARD_SIZE,
			{"profile": p.to_dict(), "route": ["glade", "hollow", "throne"] if not win else ["crypt", "frost", "magma"]})
		c.start(f)
		await get_tree().create_timer(0.3).timeout
		var r := f.run
		if win:
			r.lap = Balance.TOTAL_LAPS
			r.act = 3
			r.gold = 164
			r.level = 7
			r.stats.merge({"fights_won": 24, "minibosses_won": 1, "minibosses_killed": [r.miniboss_id], "bosses_killed": [r.boss_id],
				"minigames_played": 4, "minigame_crowns": 13, "pet_fights": 22, "minigame_plays": {"fossil_hunter": 2, "claw_machine": 2},
				"damage_dealt": 2480, "gold_earned": 610, "boss_reached": true, "miniboss_reached": true, "max_act": 3,
				"straights": 9, "rerolls_used": 140, "kept_dice": 260, "block_gained": 180, "cashouts": 4}, true)
		else:
			r.lap = 8
			r.act = 2
			r.gold = 71
			r.level = 4
			r.stats.merge({"fights_won": 12, "minigames_played": 2, "minigame_crowns": 5, "minigame_plays": {"scratch_off": 1, "claw_machine": 1},
				"damage_dealt": 910, "gold_earned": 240, "max_act": 2, "rerolls_used": 60}, true)
		var ev: Array[Dictionary] = []
		f._finish(win, ev)
		await c.play_events(ev)

	func _first_run() -> void:
		c.profile = null
		c.profile_is_new = false
		c.show_title()
		c.profile = Profile.fresh()
		c.profile_is_new = true
		await _step(0, "title", 1.2)
		c.ui.title.new_run_pressed.emit()
		await _step(1, "camp + welcome", 1.6)
		c.ui.camp.welcome.close()
		await _step(2, "camp", 0.8)
		c.ui.camp.start_btn.pressed.emit()
		await _step(3, "run setup", 0.9)
		c.ui.camp.setup.start_pressed.emit()
		await _step(4, "route card", 1.6)
		print("FLOW_FIRST_RUN mode=%s phase=%s class=%s meta=%s" % [c.mode, GameFlow.phase_name(c.flow.phase) if c.flow else "-",
			c.flow.run.class_id if c.flow else "-", str(not c.flow.run.meta.is_empty()) if c.flow else "-"])
		await get_tree().create_timer(0.3).timeout
		Audio.stop_all()
		get_tree().quit(0)

	func _step(n: int, what: String, wait: float) -> void:
		await get_tree().create_timer(wait).timeout
		var shot: Node = get_tree().root.get_node_or_null("Shot")
		var base := String(args.get("shot", "user://flow.png")).get_basename()
		var path := "%s_step_%02d.png" % [base, n]
		if shot:
			await shot._save(path)
		print("STEP %02d %s -> %s" % [n, what, path])
