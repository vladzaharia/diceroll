extends "res://tests/test_case.gd"
## Armory presentation: the hero wearing the equipped items (ArmoryLook), the run's worn look
## (meta.look), the in-run callout text, the Camp racks' state, the kit strip and the Armory
## screen's equip / look-follows-the-piece commands.


func _mid() -> Profile:
	return Profile.from_dict(MetaPresets.get_preset("mid"))


func test_look_is_the_equipped_kit() -> void:
	var p := _mid()
	var lo := ArmoryLook.of_profile(p, "knight")
	assert_eq(String(lo.model), "knight")
	assert_eq(String(lo.weapon), "sword")
	assert_eq(String(lo.offhand), "round_shield_badge", "the Knight's Standard shield wears its badge look")
	assert_eq(String(lo.head), "knight_helm")
	assert_eq(String(lo.body), "knight_plate")
	assert_eq(String(lo.trinket), "tankard")
	assert_true(not lo.has("appearance"), "the kit shows as authored")
	var pal := ArmoryLook.of_profile(p, "paladin")
	assert_eq(String((pal.get("appearance", {}) as Dictionary).get("head", "")), "hidden", "the Paladin stays helmet-less")


func test_look_follows_the_equipped_piece_and_the_appearance() -> void:
	var p := _mid()
	p.grant_item("bear_hat")
	var camp := Camp.new(p)
	camp.equip_item("knight", "head", "bear_hat", "bear_hat")
	var lo := ArmoryLook.of_profile(p, "knight")
	assert_eq(String(lo.head), "bear_hat")
	assert_eq(String((lo.get("appearance", {}) as Dictionary).get("head", "")), "own", "a new piece shows the own look until chosen")
	camp.set_appearance("knight", "head", "bear_hat")
	lo = ArmoryLook.of_profile(p, "knight")
	assert_eq(String((lo.get("appearance", {}) as Dictionary).get("head", "")), "bear_hat")
	camp.set_appearance("knight", "head", "knight_helm")
	lo = ArmoryLook.of_profile(p, "knight")
	assert_eq(String(lo.head), "bear_hat", "rules from the Bear Hat")
	assert_eq(String((lo.get("appearance", {}) as Dictionary).get("head", "")), "knight_helm", "the Knight Helm's look")
	assert_eq(ArmoryLook.shown_look(p, "knight", "head"), "knight_helm")
	p.grant_variant("hand_axe", "axe_twinbit")
	camp.equip_item("knight", "weapon", "hand_axe", "axe_twinbit")
	assert_eq(String(ArmoryLook.of_profile(p, "knight").weapon), "axe_twinbit", "variants wear their own model")


func test_monster_kid_wears_the_dino_suit() -> void:
	var p := Profile.from_dict(MetaPresets.get_preset("max"))
	var lo := ArmoryLook.of_profile(p, "monster_kid")
	assert_eq(String(lo.body), "dino_suit")
	assert_true(not lo.has("head"), "the suit covers the head")


func test_run_meta_carries_the_worn_look() -> void:
	var p := Profile.fresh()
	var m := MetaRun.normalize(MetaRun.build(p.to_dict(), "knight"))
	assert_true((m.items as Dictionary).is_empty(), "rank 0: no active items")
	assert_eq(String((m.look.weapon as Dictionary).id), "sword", "the worn look still has the kit")
	var lo := ArmoryLook.of_meta(m, "knight")
	assert_eq(String(lo.weapon), "sword")
	assert_eq(String(lo.head), "knight_helm")
	# an old save without meta.look falls back to the active items and the kit armor
	var old := m.duplicate(true)
	old.erase("look")
	old["items"] = {"weapon": {"id": "hand_axe", "variant": "hand_axe", "tier": 1}}
	var lo2 := ArmoryLook.of_meta(old, "knight")
	assert_eq(String(lo2.weapon), "hand_axe")
	assert_eq(String(lo2.body), "knight_plate")


func test_callout_text() -> void:
	assert_eq(ArmoryLook.callout_text({"id": "sword", "variant": "sword", "effect": "twin_edge", "value": 3}), "Twin Edge +3")
	assert_eq(ArmoryLook.callout_text({"id": "round_shield", "variant": "round_shield", "effect": "bulwark", "value": 5}), "Bulwark +5 Block")
	assert_eq(ArmoryLook.callout_text({"id": "sword", "variant": "sword_knight", "effect": "guarded", "value": 2}), "Guarded +2 Block")
	assert_eq(ArmoryLook.callout_text({"id": "bone_crown", "variant": "bone_crown", "effect": "dominion_stack", "value": 0, "stacks": 2}), "Dominion ×2")
	assert_eq(ArmoryLook.callout_text({"id": "bandit_mask", "effect": "ambush_ready"}), "Ambush ready")
	assert_eq(ArmoryLook.callout_text({"id": "paladin_helm", "variant": "paladin_helm", "effect": "vow", "value": 2}), "Vow +2 HP")
	# every rule and secondary gets a readable name
	for id in ItemDefs.IDS:
		var eff: Dictionary = ItemDefs.def(String(id)).get("effect", {})
		if not eff.is_empty():
			var t := ArmoryLook.callout_text({"id": id, "variant": id, "effect": eff.rule, "value": 1})
			assert_true(t.begins_with(String(eff.name)), "callout for %s: %s" % [id, t])
	for v in ItemDefs.VARIANTS:
		var vd: Dictionary = ItemDefs.VARIANTS[v]
		var t2 := ArmoryLook.callout_text({"id": vd.item, "variant": v, "effect": vd.sec, "value": 0})
		assert_eq(t2, String(vd.sec_name), "secondary callout for %s" % v)


func test_camp_racks_follow_the_profile() -> void:
	var fresh := CampState.of(Profile.fresh())
	assert_eq(String(fresh.stations.armory.state), "ruined")
	var mid := CampState.of(_mid())
	var a: Dictionary = mid.stations.armory
	assert_eq(String(a.state), "built")
	assert_true((a.weapons as Array).has("sword") and (a.weapons as Array).has("hand_axe"), "owned weapons on the rack")
	assert_true((a.shields as Array).has("round_shield"), "shields on the wall")
	assert_true((a.table as Array).has("tankard") and (a.table as Array).has("spellbook"), "trinkets and books on the table")
	assert_true((a.bodies as Array).has("knight_plate"), "bodies for the mannequins")
	assert_true((a.kit as Array).has("sword") and (a.kit as Array).has("knight_plate"), "the hero's kit glows")
	var mx: Dictionary = CampState.of(Profile.from_dict(MetaPresets.get_preset("max"))).stations.armory
	assert_eq(int(mx.tier), 3)
	assert_true((mx.weapons as Array).size() > (a.weapons as Array).size(), "the rack fills as the profile grows")
	assert_true((mx.weapons as Array).has("sword_flame"), "crafted variants hang too")


func test_camp_racks_build() -> void:
	var st: Dictionary = CampState.of(Profile.from_dict(MetaPresets.get_preset("max"))).stations.armory
	var body := CampStations.build("armory", st)
	var rack := body.get_node_or_null("WeaponRack")
	assert_true(rack != null, "a weapon rack")
	var props := 0
	for ch in rack.get_children():
		if String(ch.name).begins_with("Prop_"):
			props += 1
	assert_eq(props, 12 + 5, "12 pegs and 5 shields at tier 3")
	assert_true(body.get_node_or_null("Mannequin2") != null, "three mannequins at tier 3")
	assert_true(body.find_children("*KitGlow*", "", true, false).size() >= 3, "the equipped kit glows")
	body.free()
	Character.clear_cache()


func test_kit_strip() -> void:
	var p := _mid()
	var s := KitStrip.of_profile(p, "knight")
	var slots: Array = []
	for e in s.entries:
		slots.append(String(e.slot))
	assert_eq(slots, ["weapon", "offhand", "head", "body", "trinket", "back"])
	assert_eq(int(s.entries[0].tier), 3, "R4 + kit affinity = tier III")
	assert_true(s.names_text().begins_with("Arming Sword"))
	s.free()
	var k := KitStrip.of_kit("necromancer")
	assert_eq(String(k.entries[0].shown), "staff_bone", "the Necromancer's skull staff")
	k.free()


## The Armory screen: tapping an item equips it; the head's look follows the new piece unless
## another look was chosen on purpose; a craft emits craft_variant.
func test_armory_screen_commands() -> void:
	var p := _mid()
	p.grant_item("bear_hat")
	p.crowns = 500
	var camp := Camp.new(p)
	var sent: Array = []
	var m := ArmoryModal.new()
	m.camp_command.connect(func(c: Array) -> void:
		sent.append(c)
		camp.apply(c))
	m.profile = p
	m.view_class = "knight"
	m.sel_slot = "head"
	m.rebuild(p)
	assert_true(m.body.get_child_count() >= 4, "classes, doll, picker, look, ranks")
	m._equip("bear_hat", "bear_hat")
	assert_eq(String(p.loadout_for("knight").head.id), "bear_hat")
	assert_eq(p.appearance_of("knight").head, "bear_hat", "the look follows the new piece")
	camp.set_appearance("knight", "head", "knight_helm")
	m._equip("wizard_hat", "wizard_hat")
	assert_eq(String(p.loadout_for("knight").head.id), "wizard_hat")
	assert_eq(p.appearance_of("knight").head, "knight_helm", "a chosen look stays")
	# the paladin's helmet-less default follows too
	m.view_class = "paladin"
	m._equip("wizard_hat", "wizard_hat")
	assert_eq(p.appearance_of("paladin").head, "wizard_hat")
	m._equip("paladin_helm", "paladin_helm")
	assert_eq(p.appearance_of("paladin").head, "own", "back to the kit: the own look")
	var types: Array = []
	for c in sent:
		types.append(String(c[0]))
	assert_true(types.has("equip_item") and types.has("set_appearance"))
	m.free()
	Character.clear_cache()


## Picker rule text: "tier III:" clauses show tier III's numbers, tier-I prose reads naturally.
func test_picker_rule_text() -> void:
	for id in ItemDefs.IDS:
		for t in [1, 2, 3]:
			var s := ArmoryModal.rule_text(String(id), t, String(id))
			assert_true(not s.contains("{"), "placeholders filled: %s %d: %s" % [id, t, s])
			assert_true(not s.contains("+0%") and not s.contains("(s)") and not s.contains("turns 1-1"), "reads naturally: %s %d: %s" % [id, t, s])
	assert_eq(ArmoryModal.rule_text("knight_cape", 1), "Style")
