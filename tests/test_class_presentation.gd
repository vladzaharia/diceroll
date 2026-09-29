extends "res://tests/test_case.gd"
## Class presentation (game/actors/hero_look.gd, game/classes/class_beats.gd, ui/widgets/class_badge.gd,
## ui/widgets/class_info.gd, the dice tray's ★ face / Bone dice / turret slot).


func _assets() -> bool:
	return ResourceLoader.exists(String(Character.MODELS["knight"][0]))


func test_every_class_has_text_and_icons() -> void:
	for id in HeroDefs.IDS:
		assert_true(ClassInfo.tagline(String(id)) != "", "tagline for %s" % id)
		assert_true(UiIcons.exists(UiIcons.class_icon(String(id))), "class icon for %s" % id)
		var m := HeroDefs.mechanic(String(id))
		if m != "":
			assert_true(ClassInfo.rule(m) != "", "rule for %s" % m)
			assert_true(ClassInfo.mechanic_name(m) != "", "badge name for %s" % m)
			assert_true(UiIcons.exists(UiIcons.mechanic_icon(m)), "mechanic icon for %s" % m)


func test_trigger_texts() -> void:
	assert_eq(ClassInfo.trigger_text({"id": "oath", "value": 4}), "OATH OF 4")
	assert_eq(ClassInfo.trigger_text({"id": "aim", "value": 130}), "STEADY AIM ×1.3")
	assert_eq(ClassInfo.trigger_text({"id": "boo"}), "BOO!")


func test_hero_looks_build_for_every_class_and_skin() -> void:
	if not _assets():
		return
	for id in HeroDefs.IDS:
		for skin in ["default", "victor", "ascendant", "bossbane"]:
			var ch := HeroLook.create(String(id), skin, skin == "bossbane")
			assert_true(ch is Character, "%s %s builds" % [id, skin])
			assert_eq(String(ch.get_meta("class_id")), String(id))
			ch.free()


func test_necromancer_is_the_hooded_human_and_engineer_has_a_turret() -> void:
	if not _assets():
		return
	var n := HeroLook.create("necromancer")
	assert_eq(n.model_id, "rogue_hooded", "the Necromancer hero is never the skeleton model")
	n.free()
	var e := HeroLook.create("engineer")
	assert_true(HeroLook.turret_of(e) != null, "engineer turret prop")
	e.free()
	var k := HeroLook.create("knight")
	assert_true(HeroLook.turret_of(k) == null)
	k.free()


func test_paladin_helmet_skin_shows_the_helm() -> void:
	var lo := HeroLook.loadout("paladin", "ascendant")
	assert_eq(String((lo.get("appearance", {}) as Dictionary).get("head", "")), "piece")
	var plain := HeroLook.loadout("paladin", "default")
	assert_eq(String((plain.get("appearance", {}) as Dictionary).get("head", "")), "hidden")


func test_prestige_mesh_swaps() -> void:
	assert_eq(String(HeroLook.loadout("barbarian", "default", true).model), "barbarian_large")
	assert_eq(String(HeroLook.loadout("rogue", "default", true).model), "rogue_hooded")
	assert_eq(String(HeroLook.loadout("monster_kid", "default", true).model), "monster")


func test_star_face_survives_the_die_visual() -> void:
	var dv := DieVisual.new()
	dv.set_data({"faces": [1, 2, 3, 4, 5, Die.PRETEND], "kind": "pretend", "rune": ""})
	assert_eq(dv.faces[5], Die.PRETEND, "the ★ face is not clamped to a number")
	assert_eq(dv.slots_for(Die.PRETEND), [5] as Array[int])
	# a board value the die doesn't carry is its ★ copy
	var rng := RandomNumberGenerator.new()
	assert_eq(dv.pick_slot(6, rng), 5)
	dv.free()


func test_board_values_show_the_star() -> void:
	var out := ClassTray.board_values({"pretend": [1], "indices": [0, 1]}, [4, 4] as Array[int])
	assert_eq(out, [4, Die.PRETEND] as Array[int])
	var none := ClassTray.board_values({"indices": [0, 1]}, [2, 5] as Array[int])
	assert_eq(none, [2, 5] as Array[int])


func test_class_badge_state() -> void:
	var f := GameFlow.new_run("paladin", 3)
	assert_eq(String(ClassBadge.state_text(f)[0]), "OATH %d" % ClassLogic.pool_oath(f.run.dice))
	var n := GameFlow.new_run("necromancer", 3)
	n.debug_open("combat", "skeleton_minion")
	assert_eq(String(ClassBadge.state_text(n)[0]), "BONES 0/%d" % ClassLogic.BONE_MAX)
	var k := GameFlow.new_run("knight", 3)
	assert_eq(String(ClassBadge.state_text(k)[0]), "KNIGHT")


func test_combat_pool_includes_bone_dice() -> void:
	var f := GameFlow.new_run("necromancer", 5)
	f.debug_open("combat", "skeleton_minion,skeleton_minion")
	var d := Die.make("", "bone")
	f.combat.extra_dice.append(d)
	assert_eq(ClassTray.pool(f).size(), f.run.dice.size() + 1)
