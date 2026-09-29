extends "res://tests/test_case.gd"
## Class cards, the secret hero and the Wardrobe (presentation helpers over the profile).


func test_class_card_states() -> void:
	var p := Profile.fresh()
	assert_eq(ClassCard.state_for(p, "knight", "knight"), ClassCard.State.SELECTED)
	assert_eq(ClassCard.state_for(p, "paladin", "knight"), ClassCard.State.LOCKED)
	assert_eq(ClassCard.state_for(p, "monster_kid", "knight"), ClassCard.State.SECRET)
	assert_eq(ClassCard.state_for(null, "monster_kid", "knight"), ClassCard.State.OPEN, "no profile: everything open")
	p.grant("classes", "monster_kid")
	assert_eq(ClassCard.state_for(p, "monster_kid", "knight"), ClassCard.State.OPEN, "found: a normal card")


func test_secret_never_named_before_unlock() -> void:
	var p := Profile.fresh()
	var hint := ClassCard.unlock_text(p, "monster_kid")
	assert_true(hint != "" and not hint.contains("Monster"), "hint only: " + hint)
	var st := CampState.of(p)
	assert_true(not (st.locked_classes as Array).has("monster_kid"), "no tent for the secret class")
	for g in CampInfo.nearest_goals(p, 30):
		assert_true(not String(g.title).contains("Monster"), "goal never names the secret: " + String(g.title))
	var card := ClassCard.make("monster_kid", ClassCard.State.SECRET, hint)
	for l in card.find_children("*", "Label", true, false):
		assert_true(not (l as Label).text.contains("Monster"), "mystery card text: " + (l as Label).text)
	card.free()


func test_wardrobe_progress_text() -> void:
	var p := Profile.fresh()
	assert_eq(WardrobeModal.progress_text(p, "knight", "ascendant"), "No win yet")
	p.records["best_asc_by_class"] = {"knight": 2}
	p.records["bosses_by_class"] = {"knight": ["boss_lich"]}
	assert_eq(WardrobeModal.progress_text(p, "knight", "ascendant"), "Best win: A2")
	assert_eq(WardrobeModal.progress_text(p, "knight", "victor"), "")
	var bb := WardrobeModal.progress_text(p, "knight", "bossbane")
	assert_true(bb.begins_with("Final bosses: 1/4"), bb)


func test_wardrobe_commands_round_trip() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	p.grant_skin("knight", "victor")
	assert_true((p.cosmetics.unseen as Array).has("knight:victor"), "new skin waits unseen")
	camp.apply(["equip_skin", "knight", "victor"])
	assert_eq(p.equipped_skin("knight"), "victor")
	assert_eq((CampState.of(p).skins.knight as Array).slice(0, 2), ["victor", false], "the camp hero wears it")
	camp.apply(["mark_skins_seen", "knight"])
	assert_true((p.cosmetics.unseen as Array).is_empty(), "seen")
	var ev := camp.apply(["buy_skin", "knight", "ascendant"])
	assert_eq(String(ev[0].type), "error", "not for sale before the caps")
