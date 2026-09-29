extends RefCounted
## The Armory's screens and beats for the screenshot harness (tools/shot.gd via tools/scenarios.gd
## PROVIDERS). They never touch the player's profile or run save.
##
##  ui_armory             the Armory open. --profile=demo (default) | fresh | mid | max,
##                        --class=<id>, --slot=<slot>, --focus=<item>, --chip=<variant>,
##                        --at=picker|variants|appearance|ranks (scrolls it into view), --scroll=N
##  ui_armory_picker      the Weapon picker on the demo profile: item cards, 3D previews, mastery
##  ui_armory_craft       a craftable blueprint opened (Training Sword): CRAFT for Crowns / Sigils
##  ui_armory_rankup      the Ranks section right after a Weapon rank-up (toast), Belt Pouch ready
##  ui_armory_appearance  the Knight wearing the Knight Helm's look with the Bear Hat's rules
##  camp_armory_fresh / camp_armory_mid / camp_armory_max   the Camp's Armory racks up close
##                        (--clean hides the Camp UI)
##  run_item_triggered    a Knight fight with item callouts (Twin Edge, Bulwark) over the hero
##  ui_results_items      the results screen of a won run: item mastery and a new blueprint
##  ui_pause_loadout      the pause menu of a run: the loadout with tiers

## Loaded at runtime: these reach autoloads (Audio) that ui/check_scripts.gd does not have.
const CAMP_PATH := "res://game/camp/scenarios.gd"
const CONTROLLER := "res://game/game_controller.gd"
const NAMES := ["ui_armory", "ui_armory_picker", "ui_armory_craft", "ui_armory_rankup", "ui_armory_appearance",
	"camp_armory_fresh", "camp_armory_mid", "camp_armory_max", "run_item_triggered", "ui_results_items", "ui_pause_loadout"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var d := _Driver.new()
	d.name = "ArmoryScenario"
	d.scenario = name
	return d


## Profiles: the camp presets, plus "demo" (a lived-in mid profile: Crowns to spend, a craftable
## blueprint, mastery in progress, NEW items, Trinket rank 5 for the Belt Pouch) and "first" (the
## first Armory purchase: the Knight kit at Armor rank 1).
static func profile(name: String) -> Profile:
	match name:
		"demo":
			var p: Profile = load(CAMP_PATH).preset("mid")
			p.loadout["class"] = "knight"
			p.crowns = 520
			p.sigils = 9
			p._ranks()["trinket"] = 5
			p.armory["mastery"] = {"sword": 22, "round_shield": 17, "knight_helm": 16, "knight_plate": 22, "tankard": 22,
				"hand_axe": 18, "great_axe": 9}
			p.add_blueprint("sword", "sword_training")
			p.add_blueprint("round_shield", "shield_plank")
			p.grant_variant("hand_axe", "axe_twinbit")
			p.armory["seen_new"] = ["sword_training", "shield_plank", "coin_purse"]
			return p
		"first":
			var p := Profile.fresh()
			p.grant("gear", "armor")
			p._ranks()["armor"] = 1
			p.records["runs"] = 2
			return p
		"fresh":
			return Profile.fresh()
	return load(CAMP_PATH).preset(name)


class _Driver extends Node:
	var scenario := ""
	var c: Node
	var args: Dictionary = {}
	## Fires just before the harness takes its picture (same clock as its --wait timer).
	var _pre_shot: SceneTreeTimer

	func _ready() -> void:
		var shot: Node = get_tree().root.get_node_or_null("Shot")
		args = shot.args if shot else {}
		_pre_shot = get_tree().create_timer(maxf(0.1, float(args.get("wait", "1.5")) - 0.6), true, false, true)
		c = load(CONTROLLER).new()
		c.autosave = false
		c.persist_profile = false
		add_child(c)
		match scenario:
			"ui_armory":
				await _armory(String(args.get("profile", "demo")), String(args.get("class", "")), String(args.get("slot", "weapon")),
					String(args.get("focus", "")), String(args.get("chip", "")), String(args.get("at", "")))
			"ui_armory_picker":
				await _armory("demo", "knight", "weapon", "sword", "", "picker")
			"ui_armory_craft":
				await _armory("demo", "knight", "weapon", "sword", "sword_training", "variants")
			"ui_armory_rankup":
				await _armory("demo", "knight", "weapon", "", "", "ranks")
				await get_tree().create_timer(0.3, true, false, true).timeout
				c.camp_command(["rank_up", "weapon"])
			"ui_armory_appearance":
				await _appearance()
			"camp_armory_fresh":
				await _camp("first")
			"camp_armory_mid":
				await _camp("demo")
			"camp_armory_max":
				await _camp("max")
			"run_item_triggered":
				await _fight()
			"ui_results_items":
				await _results()
			"ui_pause_loadout":
				await _pause()

	func _prof(n: String) -> Profile:
		return load("res://ui/camp/armory_ui_scenarios.gd").profile(n)

	func _armory(pn: String, cls: String, slot: String, focus: String, chip: String, at: String) -> void:
		c.profile = _prof(pn)
		if cls != "":
			c.profile.loadout["class"] = cls
		c.show_camp()
		await get_tree().create_timer(0.6, true, false, true).timeout
		var a: ArmoryModal = c.ui.camp.armory
		a.view_class = cls
		a.sel_slot = slot
		a.focus = focus
		a.chip = chip
		c.ui.camp.open_station("armory")
		await _scroll_to(a, at)

	func _scroll_to(a: ArmoryModal, at: String) -> void:
		if at == "" and not args.has("scroll"):
			return
		await get_tree().create_timer(0.7, true, false, true).timeout
		# let the rebuild from mark_items_seen (it restores its scroll two frames later) settle
		for i in 4:
			await get_tree().process_frame
		if args.has("scroll"):
			a._scroll.scroll_vertical = int(args.scroll)
			return
		var target: Control = null
		match at:
			"picker":
				target = a._picker_head
			"variants", "appearance", "ranks":
				var key := {"variants": "VARIANTS", "appearance": "Appearance", "ranks": "Ranks"}[at] as String
				target = _find_label(a.body, key)
		if target == null:
			return
		if a._wide() and at in ["picker", "variants"]:
			# landscape: the picker is its own column; bring the variants row up
			if at == "picker":
				return
		var top := target.get_global_rect().position.y - a._scroll.get_global_rect().position.y
		a._scroll.scroll_vertical = int(a._scroll.scroll_vertical + top - 10.0)

	func _find_label(n: Node, prefix: String) -> Control:
		for ch in n.get_children():
			if ch is Label and String((ch as Label).text).to_upper().begins_with(prefix.to_upper()):
				return ch
			var f := _find_label(ch, prefix)
			if f != null:
				return f
		return null

	## Bear Hat rules, the Knight Helm's look; the Mage Robe worn as the body.
	func _appearance() -> void:
		c.profile = _prof("demo")
		var p: Profile = c.profile
		p.grant_item("bear_hat")
		var camp := Camp.new(p)
		camp.equip_item("knight", "head", "bear_hat", "bear_hat")
		camp.set_appearance("knight", "head", "knight_helm")
		camp.equip_item("knight", "body", "mage_robe", "mage_robe")
		camp.set_appearance("knight", "body", "mage_robe")
		c.show_camp()
		await get_tree().create_timer(0.6, true, false, true).timeout
		var a: ArmoryModal = c.ui.camp.armory
		a.view_class = "knight"
		a.sel_slot = "head"
		c.ui.camp.open_station("armory")
		await _scroll_to(a, String(args.get("at", "")))

	func _camp(pn: String) -> void:
		c.profile = _prof(pn)
		c.show_camp()
		await get_tree().create_timer(0.8, true, false, true).timeout
		var sc: Node3D = c.camp_scene
		if sc == null:
			return
		sc.skip_reveal()
		var st: Node3D = (sc.get("stations") as Dictionary).get("armory")
		if st:
			# head-on to the station's front, the whole station in view
			var bb := ItemMounts.local_bounds(sc)
			var body: Node3D = st.get_node_or_null("Body")
			var pts := PackedVector3Array()
			var k := float(args.get("radius", "1.0"))
			for mi in (body if body else st).find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				if m.mesh == null or not m.is_visible_in_tree():
					continue
				var g := m.global_transform * m.get_aabb()
				pts.append(st.global_position + (g.position - st.global_position) * k)
				pts.append(st.global_position + (g.end - st.global_position) * k)
			var rig: Node = sc.get("rig")
			rig.set("smooth_time", 0.01)
			rig.call("frame_points", pts, st.global_rotation_degrees.y + float(args.get("yaw", "0")), float(args.get("pitch", "30")), true)
			if bb.size == Vector3.ZERO:
				pass
		if args.has("clean"):
			c.ui.camp.visible = false
		else:
			c.ui.camp._bottom.visible = false

	## A Knight fight on the demo profile: its items call out over the hero, again and again.
	func _fight() -> void:
		c.profile = _prof("demo")
		var p: Profile = c.profile
		var f := GameFlow.new_run("knight", 11, Balance.BOARD_SIZE, {"profile": p.to_dict()})
		c.start(f)
		await get_tree().create_timer(0.6, true, false, true).timeout
		f.run.pos = 3
		c.board.place_hero(3)
		await c.play_events(f.debug_open("combat", "skeleton_warrior,skeleton_minion"))
		await get_tree().create_timer(0.4, true, false, true).timeout
		var evs: Array = [
			{"type": "item_triggered", "id": "sword", "variant": "sword", "slot": "weapon", "effect": "twin_edge", "value": 3},
			{"type": "item_triggered", "id": "round_shield", "variant": "round_shield", "slot": "offhand", "effect": "bulwark", "value": 5},
		]
		var beats: Script = load("res://game/pets/meta_beats.gd")
		# fire the callouts just before the harness takes its picture (then keep them coming)
		if _pre_shot.time_left <= 0.0:
			print("ITEM_BEATS: the fight took longer than --wait; raise it")
		while is_inside_tree():
			if _pre_shot.time_left > 0.0:
				await _pre_shot.timeout
			for e in evs:
				c.overlay.item_pop(c.hero_screen(2.4), ArmoryLook.shown_id("knight", String(e.id), String(e.variant)),
					beats.item_text(e), beats.ITEM_COLOR, c.ui.combat_hud.top.content_bottom(),
					c.tray.get_global_rect().position.y - 4.0 if c.tray.is_visible_in_tree() else 0.0, beats.hud_rects(c))
				await get_tree().create_timer(0.25, true, false, true).timeout
			_pre_shot = get_tree().create_timer(1.2, true, false, true)

	## A won run on the demo profile: +22 fights, the Knight's Sword blueprint from mastery.
	func _results() -> void:
		c.profile = _prof("demo")
		var p: Profile = c.profile
		p.armory["mastery"]["sword"] = 30
		var f := GameFlow.new_run("knight", 11, Balance.BOARD_SIZE, {"profile": p.to_dict(), "route": ["crypt", "frost", "magma"]})
		c.start(f)
		await get_tree().create_timer(0.3, true, false, true).timeout
		var r := f.run
		r.lap = Balance.TOTAL_LAPS
		r.act = 3
		r.gold = 120
		r.level = 7
		r.stats.merge({"fights_won": 22, "minibosses_won": 1, "minibosses_killed": [r.miniboss_id], "bosses_killed": [r.boss_id],
			"damage_dealt": 2300, "gold_earned": 560, "boss_reached": true, "miniboss_reached": true, "max_act": 3}, true)
		var ev: Array[Dictionary] = []
		f._finish(true, ev)
		await c.play_events(ev)
		await get_tree().create_timer(float(args.get("scroll_at", "0.8"))).timeout
		c.ui.summary.finish_now()
		if args.has("scroll"):
			c.ui.summary._scroll.scroll_vertical = int(args.scroll)
		else:
			await get_tree().create_timer(0.2, true, false, true).timeout
			var lab := _find_label(c.ui.summary.body, "ITEMS")
			if lab:
				var top: float = lab.get_global_rect().position.y - c.ui.summary._scroll.get_global_rect().position.y
				c.ui.summary._scroll.scroll_vertical = int(c.ui.summary._scroll.scroll_vertical + top - 10.0)

	func _pause() -> void:
		c.profile = _prof("demo")
		var f := GameFlow.new_run("knight", 11, Balance.BOARD_SIZE, {"profile": c.profile.to_dict()})
		c.start(f)
		# the run fades in first (the pause freezes tweens)
		await get_tree().create_timer(3.5, true, false, true).timeout
		c.overlay.fade_in(0.01)
		c.ui.open_pause()
		c.ui.pause.show_now()
