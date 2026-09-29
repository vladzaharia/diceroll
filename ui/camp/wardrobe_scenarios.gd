extends RefCounted
## Class select, Wardrobe, skin toasts and the secret hero, for the screenshot harness
## (tools/shot.gd via tools/scenarios.gd PROVIDERS). They never touch the player's profile.
##
##  ui_class_select  the class select screen (--class=<id>; --profile=fresh|mid|max|kid locks
##                   classes like a profile would: mid keeps the Monster Kid a "???" mystery)
##  ui_wardrobe      the Camp with the Wardrobe open. --profile=demo (default: owned, locked, NEW
##                   and prestige skins) | capped (every Crowns sink maxed: 250-Crown buy
##                   buttons) | fresh; --class=<id>, --preview=<skin> (a locked skin on the
##                   pedestal), --scroll=N
##  camp_wardrobe    the Camp hub on the demo profile (Wardrobe button with its NEW dot)
##  ui_results_skins the results screen after an A3 Paladin win: Victor + Ascendant skin toasts
##  ui_mk_reveal     the results screen of the run that finds the Monster Kid (the ??? card
##                   rattles, BOO!, the hero appears): use --frames
##  ui_mk_mystery    the run setup on a mid profile (the "???" card)

const CAMP := preload("res://game/camp/scenarios.gd")
const NAMES := ["ui_class_select", "ui_wardrobe", "camp_wardrobe", "ui_results_skins", "ui_mk_reveal", "ui_mk_mystery"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var d := _Driver.new()
	d.name = "WardrobeScenario"
	d.scenario = name
	return d


## A profile by name: the camp presets, plus demo / capped / kid.
static func profile(name: String) -> Profile:
	match name:
		"demo":
			var p := CAMP.preset("mid")
			p.loadout["class"] = "knight"
			p.cosmetics["owned"] = {"knight": ["victor", "ascendant", "prestige"], "paladin": ["victor"]}
			p.cosmetics["equipped"] = {"knight": "victor", "paladin": "victor"}
			p.cosmetics["prestige"] = {"knight": true}
			p.cosmetics["unseen"] = ["knight:ascendant", "paladin:victor"]
			p.records["best_asc_by_class"] = {"knight": 10, "paladin": 0, "barbarian": 1}
			p.records["bosses_by_class"] = {"knight": ["boss_lich", "boss_cinder_king"], "barbarian": ["boss_lich"]}
			return p
		"capped":
			var p := CAMP.preset("max")
			p.crowns = 1260
			for slot in GearDefs.SLOTS:
				p.gear[slot] = GearDefs.MAX_LEVEL
			for track in UnlockDefs.UPGRADES:
				for id in UnlockDefs.UPGRADES[track]:
					p.upgrades[id] = 1
			for id in p.unlocks.get("pets", []):
				p.pet_bought[id] = PetDefs.MAX_LEVEL
			p.loadout["class"] = "ranger"
			p.cosmetics["owned"] = {"ranger": ["victor"]}
			p.cosmetics["equipped"] = {"ranger": "victor"}
			p.records["best_asc_by_class"] = {"ranger": 2}
			return p
		"kid":
			# every other class owned, 39 runs banked: the next run finds the Monster Kid
			var p := CAMP.preset("max")
			(p.unlocks.classes as Array).erase("monster_kid")
			p.milestones = p.milestones.filter(func(m: Variant) -> bool: return String(m) != "trick_or_treat")
			p.records.runs = 39
			var cn: Dictionary = p.records.get("counters", {})
			cn["runs"] = 39
			cn["hollow_events"] = 36
			p.records["counters"] = cn
			p.loadout["class"] = "ninja"
			return p
		"none":
			return null
	if name == "fresh":
		return Profile.fresh()
	return CAMP.preset(name)


class _Driver extends Node:
	var scenario := ""
	var c: GameController
	var args: Dictionary = {}

	func _ready() -> void:
		var shot: Node = get_tree().root.get_node_or_null("Shot")
		args = shot.args if shot else {}
		match scenario:
			"ui_class_select":
				_class_select()
			"ui_wardrobe", "camp_wardrobe":
				await _wardrobe()
			"ui_results_skins":
				await _results("paladin", 3, "mid")
			"ui_mk_reveal":
				await _results("ninja", 0, "kid")
			"ui_mk_mystery":
				_controller()
				c.profile = _prof("mid")
				c.show_camp()
				await get_tree().create_timer(0.2).timeout
				c.ui.camp.open_station("setup")
				if args.has("scroll"):
					await get_tree().create_timer(0.5).timeout
					c.ui.camp.setup._scroll.scroll_vertical = int(args.scroll)

	func _prof(n: String) -> Profile:
		return load("res://ui/camp/wardrobe_scenarios.gd").profile(n)

	func _controller() -> void:
		c = GameController.new()
		c.autosave = false
		c.persist_profile = false
		add_child(c)

	func _class_select() -> void:
		var layer := CanvasLayer.new()
		add_child(layer)
		var cs := ClassSelect.new()
		layer.add_child(cs)
		var pn := String(args.get("profile", "none"))
		if pn != "none":
			cs.set_profile(_prof(pn))
		cs.select(String(args.get("class", "knight")), false)

	func _wardrobe() -> void:
		_controller()
		c.profile = _prof(String(args.get("profile", "demo")))
		print("WARDROBE_PROFILE capped=%s crowns=%d unseen=%s" % [str(c.profile.crowns_capped()), c.profile.crowns,
			str(c.profile.cosmetics.get("unseen", []))])
		c.show_camp()
		if scenario == "camp_wardrobe":
			return
		await get_tree().create_timer(1.2).timeout
		var w: WardrobeModal = c.ui.camp.wardrobe
		w.view_class = String(args.get("class", ""))
		w.preview_skin = String(args.get("preview", ""))
		c.ui.camp.open_station("wardrobe")
		if args.has("scroll"):
			await get_tree().create_timer(0.6).timeout
			w._scroll.scroll_vertical = int(args.scroll)

	## A won (or lost) run with `cls` at ascension `asc`, banked into the profile, then results.
	func _results(cls: String, asc: int, prof: String) -> void:
		_controller()
		c.profile = _prof(prof)
		var p := c.profile
		p.loadout["class"] = cls
		if not p.unlocks.classes.has(cls):
			(p.unlocks.classes as Array).append(cls)
		p.ascension["unlocked"] = maxi(int(p.ascension.get("unlocked", 0)), asc)
		p.ascension["selected"] = asc
		var f := GameFlow.new_run(cls, 11, Balance.BOARD_SIZE, {"profile": p.to_dict(), "route": ["crypt", "frost", "magma"]})
		c.start(f)
		await get_tree().create_timer(0.3).timeout
		var r := f.run
		var win := prof != "kid"
		r.lap = Balance.TOTAL_LAPS if win else 9
		r.act = 3 if win else 2
		r.gold = 120
		r.level = 7
		r.stats.merge({"fights_won": 22, "minibosses_won": 1, "minibosses_killed": [r.miniboss_id],
			"bosses_killed": [r.boss_id] if win else [], "damage_dealt": 2300, "gold_earned": 560, "boss_reached": win,
			"miniboss_reached": true, "max_act": r.act}, true)
		var ev: Array[Dictionary] = []
		f._finish(win, ev)
		await c.play_events(ev)
		if args.has("scroll"):
			await get_tree().create_timer(float(args.get("scroll_at", "0.8"))).timeout
			if String(args.get("finish", "1")) == "1":
				c.ui.summary.finish_now()
			c.ui.summary._scroll.scroll_vertical = int(args.scroll)
