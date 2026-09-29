extends "res://tests/test_case.gd"
## Pets 7-12 (2026-09-29): charge rules, firing, L5/L10 behaviours, board perks, card data.

func _all(ev: Array, type: String, effect := "") -> Array:
	var out := []
	for e in ev:
		if e.type == type and (effect == "" or String(e.get("effect", "")) == effect):
			out.append(e)
	return out

func _flow(pet: String, level := 1, s := 1) -> GameFlow:
	var p := Profile.fresh()
	p.grant("pets", pet)
	if level > 1:
		p.pet_xp[pet] = int(PetDefs.XP_LEVELS[mini(level, PetDefs.XP_LEVEL_MAX) - 2])
	if level > PetDefs.XP_LEVEL_MAX:
		p.pet_bought[pet] = level
	p.loadout.pet = pet
	var f := GameFlow.new_run("knight", s, 28, {"profile": p.to_dict()})
	f.run.max_hp = 100
	f.run.hp = 60
	return f

func _fight(f: GameFlow, ids := "skeleton_minion,skeleton_minion") -> void:
	f.debug_open("combat", ids)
	for e in f.combat.enemies:
		e.hp = 500
		e.max_hp = 500
		e.intent = {"kind": "attack", "value": 3}

func _full(f: GameFlow) -> void:
	f.run.pet_state.charge = PetDefs.size(f.run.pet_id())

func test_twelve_pets_with_cards() -> void:
	assert_eq(PetDefs.IDS.size(), 12)
	for id in PetDefs.IDS:
		var c := PetDefs.card(id, 1)
		for k in ["fires", "perk", "l5", "l10"]:
			assert_true(String(c[k]) != "", "%s %s" % [id, k])
		var new_pet := PetDefs.IDS.find(id) >= 6
		assert_true(PetDefs.size(id) >= 3 and PetDefs.size(id) <= (6 if new_pet else 9), id)
		assert_true(UnlockDefs.all_ids("pets").has(id))
	var by := {}
	for m in UnlockDefs.MILESTONES:
		for u in m.unlocks:
			if u[0] == "pets":
				by[u[1]] = m.id
	for id in PetDefs.IDS:
		assert_true(by.has(id), id + " has a milestone")

func test_pebble_charges_on_block_and_fires_block_and_thorns() -> void:
	var f := _flow("pebble_golem")
	_fight(f)
	f.run.block = 10
	f.combat.dice_values.assign([1, 3])
	var ev := f.combat_attack()
	assert_true(_all(ev, "pet_charged").size() >= 1)
	_full(f)
	f.run.block = 0
	f.combat.dice_values.assign([1, 3])
	ev = f.combat_attack()
	assert_eq(_all(ev, "pet_acted", "block").size(), 1)
	assert_true(_all(ev, "pet_acted", "thorns").size() >= 1, "thorns announced and dealt to attackers")

func test_pebble_l10_doubles_block_and_trap_perk() -> void:
	assert_eq(PetDefs.pebble_block(10), 2 * (3 + 9 / 2))
	var f := _flow("pebble_golem")
	f.run.board.tiles[5] = Board.make_tile("trap")
	f.run.pos = 5
	var hp := f.run.hp
	var ev: Array[Dictionary] = []
	var tries := 0
	while tries < 30:
		ev.clear()
		f._trigger_tile(5, ev)
		if not bool(ev[1].dodged):
			break
		tries += 1
	var trap: Dictionary = ev[1]
	if not bool(trap.dodged):
		assert_eq(int(trap.damage), maxi(1, int(round(f.run.pct_of_max(Balance.TRAP_DAMAGE_PCT) * 0.5))))

func test_frost_mote_charges_on_ones_and_freezes() -> void:
	var f := _flow("frost_mote", 5)
	_fight(f)
	f.combat.dice_values.assign([1, 1])
	var ev := f.combat_attack()
	assert_eq(int(f.run.pet_state.charge), 2)
	_full(f)
	f.combat.enemies[1].intent = {"kind": "attack", "value": 9}
	f.combat.target = 0
	f.combat.dice_values.assign([4, 5])
	ev = f.combat_attack()
	assert_eq(_all(ev, "pet_acted", "freeze").size(), 1)
	assert_eq(int(f.run.stats.freezes), 2, "L5: the target and the biggest attacker")

func test_frost_mote_perk_ice_never_chills() -> void:
	var f := _flow("frost_mote")
	f.run.board.tiles[5] = Board.make_tile("ice")
	for k in 20:
		var ev: Array[Dictionary] = []
		f._trigger_tile(5, ev)
	assert_eq(f.run.chill, 0)

func test_wick_charges_on_sets_and_burns_all() -> void:
	var f := _flow("wick")
	_fight(f)
	f.run.dice.append(Die.make())
	f.combat.dice_values.assign([3, 3, 3])
	f.combat.rerolled.assign([false, false, false])
	f.combat.marked.assign([false, false, false])
	f.combat.locked.assign([false, false, false])
	f.combat.dice_faces.assign([2, 2, 2])
	f.combat_attack()
	assert_eq(int(f.run.pet_state.charge), 1)
	_full(f)
	f.combat.dice_values.assign([1, 2, 5])
	var ev := f.combat_attack()
	var w := _all(ev, "pet_acted", "burn")
	assert_eq(w.size(), 1)
	assert_eq(w[0].target, "all")
	assert_eq(int(w[0].value), PetDefs.wick_damage(1))

func test_tinker_charges_per_reroll_and_fixes_the_lowest_die() -> void:
	var f := _flow("tinker_gear")
	_fight(f)
	f.combat.toggle(0)
	f.combat_reroll()
	assert_eq(int(f.run.pet_state.charge), 1)
	_full(f)
	f.combat.dice_values.assign([1, 4])
	f.combat.dice_faces.assign([0, 3])
	var ev := f.combat_attack()
	var fx := _all(ev, "pet_acted", "fix")
	assert_eq(fx.size(), 1)
	assert_eq(int(fx[0].die_idx), 0)
	assert_eq(int(fx[0].face), 6)

func test_grimoire_remembers_and_refires_the_last_rune() -> void:
	var f := _flow("grimoire")
	_fight(f)
	f.run.dice[0].rune = "guard"
	f.combat.dice_values.assign([4, 2])
	f.combat_attack()
	assert_eq(int(f.run.pet_state.rune), Runes.IDS.find("guard"))
	_full(f)
	var block0 := f.run.block
	f.combat.dice_values.assign([5, 2])
	var ev := f.combat_attack()
	var g := _all(ev, "pet_acted", "rune")
	assert_eq(g.size(), 1)
	assert_eq(g[0].rune, "guard")

func test_grimoire_chest_perk() -> void:
	var f := _flow("grimoire")
	var ev: Array[Dictionary] = []
	f._open_rune_choice("chest", ev, 4 if f.run.has_pet("grimoire") else 3)
	assert_eq((f.offer.options as Array).size(), 4)

func test_bubbles_brews_after_fights() -> void:
	var f := _flow("cauldron", 10)
	f.run.belt.clear()
	f.run.sync_potions()
	_fight(f, "skeleton_minion")
	f.run.pet_state.charge = PetDefs.size("cauldron") - 1
	f.combat.enemies[0].hp = 1
	var ev := f.combat_attack()
	assert_eq(_all(ev, "pet_acted", "potion").size(), 1)
	assert_eq(f.run.belt.size(), 2, "L10 brews two")
	assert_eq(int(f.run.pet_state.charge), 0)

func test_bubbles_and_tinker_shop_perks() -> void:
	var f := _flow("cauldron")
	f.debug_open("shop")
	var used := {}
	assert_eq(int(f._shop_item("potion", used).price), Balance.SHOP_POTION_PRICE - PetDefs.CAULDRON_POTION_OFF)
	var t := _flow("tinker_gear")
	assert_eq(t._restock_price(), Balance.SHOP_RESTOCK_PRICE - PetDefs.TINKER_RESTOCK_OFF)

func test_new_pets_play_full_runs() -> void:
	for pet in ["pebble_golem", "frost_mote", "wick", "tinker_gear", "grimoire", "cauldron"]:
		var f := _flow(pet, 10, 4)
		f.run.max_hp = 60
		f.run.hp = 60
		var n := 0
		var acts := 0
		while not f.is_over() and n < 5000:
			var ev := f.apply(Bot.next_command(f))
			for e in ev:
				assert_true(e.type != "error", "%s: %s" % [pet, str(e)])
			acts += _all(ev, "pet_acted").size()
			n += 1
		assert_true(f.is_over(), pet)
		assert_true(acts > 0, pet + " acted")
		var r := GameFlow.replay("knight", 4, f.commands, 28, {"meta": f.run.meta})
		assert_eq(r.run.gold, f.run.gold, pet + " replay")
