extends "res://tests/test_case.gd"
## Meta layer (spec §16 + decisions): Profile, Camp, run rewards, potions, pets, minigames,
## ascension, Short Road and the run options.

const P := GameFlow.Phase

func _types(ev: Array) -> Array:
	var out := []
	for e in ev:
		out.append(e.type)
	return out

func _first(ev: Array, type: String) -> Dictionary:
	for e in ev:
		if e.type == type:
			return e
	return {}

func _all(ev: Array, type: String) -> Array:
	var out := []
	for e in ev:
		if e.type == type:
			out.append(e)
	return out

## A meta run with `pet` equipped at `level` (XP levels only up to 5; bought levels above).
func _pet_flow(pet: String, level := 1, s := 1) -> GameFlow:
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

func _fight(f: GameFlow, ids := "skeleton_minion") -> void:
	f.debug_open("combat", ids)
	for e in f.combat.enemies:
		e.hp = 500
		e.max_hp = 500
		e.intent = {"kind": "attack", "value": 1}

func _stats(victory: bool, extra := {}) -> Dictionary:
	var s := {"rewards": {"crowns": 40}, "victory": victory, "class_id": "knight", "lap": 15 if victory else 8,
		"laps_completed": 14 if victory else 7, "fights_won": 20, "route": ["glade", "hollow", "throne"],
		"biomes_visited": ["glade", "hollow", "throne"] if victory else ["glade", "hollow"], "minibosses_killed": [],
		"bosses_killed": ["boss_lich"] if victory else [], "asc": 0, "mode": "standard", "max_act": 3 if victory else 2,
		"pet": "", "pet_fights": 0, "minigame_plays": {}}
	for k in extra:
		s[k] = extra[k]
	return s

# ================================================================ profile

func test_fresh_profile_is_knight_only() -> void:
	var p := Profile.fresh()
	assert_eq(p.unlocks.classes, ["knight"])
	assert_true(p.class_allowed("knight"))
	assert_true(not p.class_allowed("mage"), "classes locked by default")
	assert_eq(p.potion_cap(), Balance.POTION_CAP)
	assert_eq(p.loadout_slots(), 2)
	var pool := p.pool("runes")
	pool.sort()
	var starter: Array = UnlockDefs.PACKS.starter.runes.duplicate()
	starter.sort()
	assert_eq(pool, starter)
	var open := Profile.fresh(false)
	assert_true(open.class_allowed("mage"), "lock_classes flag off: every class")

func test_profile_round_trip_and_tolerant_loader() -> void:
	var p := Profile.from_dict(MetaPresets.get_preset("max", 3))
	var q := Profile.from_json(Profile.to_json(p))
	assert_eq(JSON.stringify(q.to_dict()), JSON.stringify(p.to_dict()), "JSON round trip")
	var d := p.to_dict()
	d.crowns = 12.0
	d.unlocks.pets.append("dragon")
	d.armory.ranks.armor = 99
	d.armory.owned.append("laser_sword")
	var r := Profile.from_dict(d)
	assert_eq(r.crowns, 12)
	assert_true(not r.owns("pets", "dragon"), "unknown ids dropped")
	assert_true(not r.owns_item("laser_sword"), "unknown items dropped")
	assert_eq(r.rank("armor"), ItemDefs.RANK_MAX, "ranks clamped")
	assert_eq(Profile.from_dict({}).unlocks.classes, ["knight"], "empty dict = fresh")

# ================================================================ camp

func test_camp_rank_levels_costs_and_caps() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	assert_eq(camp.rank_up("armor")[0].type, "error", "the Armor rank isn't unlocked yet")
	p.grant("gear", "armor")
	p.crowns = 10000
	var spent := 0
	for l in ItemDefs.RANK_MAX:
		var ev := camp.rank_up("armor")
		assert_eq(_first(ev, "upgrade_bought").level, l + 1)
		assert_eq(String(_first(ev, "upgrade_bought").id), "armor")
		spent += int(ItemDefs.RANK_COSTS[l])
	assert_eq(p.crowns, 10000 - spent)
	assert_eq(camp.rank_up("armor")[0].type, "error", "max rank")
	var st := ItemDefs.base_stats({"weapon": 8, "armor": 8})
	assert_eq(st.max_hp, ItemDefs.HP_CAP)
	assert_eq(st.atk, ItemDefs.ATK_BONUS)
	assert_eq(ItemDefs.base_stats({"weapon": 7, "armor": 3}).atk, 0)
	assert_eq(ItemDefs.base_stats({"armor": 4}).max_hp, mini(ItemDefs.HP_CAP, int(floor(4 * ItemDefs.HP_PER_RANK))))

func test_camp_legacy_gear_commands_are_gone() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	assert_eq(String(camp.apply(["level_gear", "helm"])[0].type), "error", "level_gear is gone: rank_up")
	assert_eq(String(camp.apply(["set_trait", "blade", "4", "blade_high"])[0].type), "error", "traits are item rules now")
	# an old (v2) file's gear piece ids still load as their rank groups
	var d := p.to_dict()
	d.erase("armory")
	d["version"] = 2
	d.unlocks["gear"] = ["blade", "helm"]
	d["gear"] = {"blade": 3, "helm": 1}
	var q := Profile.from_dict(d)
	assert_true(q.owns("gear", "weapon") and q.owns("gear", "armor"), "old pieces load as rank groups")
	assert_eq(q.rank("weapon"), 3)

func test_camp_sigil_unlocks_and_pool_toggle() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	assert_eq(camp.unlock("classes", "paladin")[0].type, "error", "no Sigils")
	p.sigils = 20
	assert_eq(camp.unlock("classes", "mage")[0].type, "error", "only the next two locked classes")
	var ev := camp.unlock("classes", "paladin")
	assert_eq(_first(ev, "unlocked"), {"type": "unlocked", "kind": "classes", "id": "paladin", "source": "sigils"})
	assert_eq(p.sigils, 20 - int(UnlockDefs.sigil_cost("classes", "paladin").sigils))
	assert_eq(camp.unlock("classes", "paladin")[0].type, "error", "already owned")
	assert_eq(UnlockDefs.buyable_classes(p.unlocks.classes), ["barbarian", "mage"])
	# pool toggle: at most 25% of each unlocked pool off
	var owned := p.pool("runes").size()
	var allowed := int(floor(owned * UnlockDefs.POOL_TOGGLE_MAX))
	var off := 0
	for id in UnlockDefs.PACKS.starter.runes:
		var r := camp.toggle_pool("runes", String(id), false)
		if r[0].type == "pool_toggled":
			off += 1
	assert_eq(off, allowed)
	assert_eq(p.pool("runes").size(), owned - allowed)
	assert_eq(camp.toggle_pool("runes", "wild", false)[0].type, "error", "not unlocked")
	camp.toggle_pool("runes", String(UnlockDefs.PACKS.starter.runes[0]), true)
	assert_eq(p.pool("runes").size(), owned - allowed + 1)

func test_camp_loadout_class_mode_ascension() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	assert_eq(camp.set_class("rogue")[0].type, "error", "locked class")
	assert_eq(camp.set_loadout(["scratch_off", "claw_machine", "fossil_hunter"], "")[0].type, "error", "2 slots")
	assert_eq(camp.set_loadout(["fossil_hunter"], "")[0].type, "error", "not owned")
	assert_eq(camp.set_loadout(["claw_machine"], "")[0].type, "loadout_changed")
	assert_eq(camp.set_mode("short")[0].mode, "short")
	assert_eq(camp.set_ascension(1)[0].type, "error", "A1 locked")
	p.ascension.unlocked = 2
	assert_eq(camp.set_ascension(2)[0], {"type": "ascension_changed", "selected": 2, "unlocked": 2})
	assert_eq(camp.apply(["set_ascension", 0])[0].selected, 0, "replay format")

func test_camp_upgrades_and_starter_kit() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	p.crowns = 1000
	assert_eq(camp.buy_upgrade("armory", "potion_belt")[0].type, "error", "needs its milestone")
	p.grant("features", "potion_belt")
	camp.buy_upgrade("armory", "potion_belt")
	assert_eq(p.potion_cap(), Balance.POTION_MAX_CAP)
	assert_eq(camp.set_starter_kind("odd")[0].type, "error", "buy the kit first")
	camp.buy_upgrade("workshop", "starter_kit")
	assert_eq(camp.set_starter_kind("loaded")[0].type, "error", "Loaded is strictly better: not a sidegrade")
	assert_eq(camp.set_starter_kind("low")[0].type, "starter_kind_set")
	var f := GameFlow.new_run("knight", 1, 28, {"profile": p.to_dict()})
	assert_eq(f.run.dice[1].kind, "low")

func test_pet_levels_from_xp_then_crowns() -> void:
	assert_eq(PetDefs.xp_level(0), 1)
	assert_eq(PetDefs.xp_level(int(PetDefs.XP_LEVELS.back())), PetDefs.XP_LEVEL_MAX)
	var p := Profile.fresh()
	var camp := Camp.new(p)
	p.grant("pets", "guard_die")
	p.crowns = 10000
	assert_eq(camp.level_pet("guard_die")[0].type, "error", "levels 1-5 come from fights")
	p.pet_xp.guard_die = int(PetDefs.XP_LEVELS.back())
	for l in range(PetDefs.XP_LEVEL_MAX, PetDefs.MAX_LEVEL):
		assert_eq(_first(camp.level_pet("guard_die"), "upgrade_bought").level, l + 1)
	assert_eq(p.pet_level("guard_die"), PetDefs.MAX_LEVEL)
	assert_eq(camp.level_pet("guard_die")[0].type, "error")

# ================================================================ banking a run

func test_bank_run_pays_crowns_sigils_milestones() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	var ev := camp.bank_run(_stats(true))
	assert_eq(p.crowns, 40)
	assert_eq(p.records.wins, 1)
	var firsts := _all(ev, "first")
	var kinds := {}
	for e in firsts:
		kinds[e.kind] = true
	assert_true(kinds.has("biome") and kinds.has("boss") and kinds.has("class_win") and kinds.has("route_win"))
	assert_true(p.sigils > 0)
	assert_true(p.milestones.has("first_steps") and p.milestones.has("victor"))
	assert_true(p.owns("biomes", "magma"), "first win unlocks Magma")
	assert_eq(p.ascension.unlocked, 1, "a win unlocks the next ascension")
	var banked := _first(ev, "run_banked")
	assert_eq(banked.crowns, 40)
	# the same firsts never pay twice
	var before := p.sigils
	camp.bank_run(_stats(true))
	assert_eq(p.sigils, before)

func test_losses_pay_and_catch_up() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	for k in 3:
		camp.bank_run(_stats(false))
	assert_eq(p.crowns, 120, "losses still pay")
	assert_eq(p.records.loss_streak, 3)
	assert_near(MetaRun.build(p.to_dict()).catchup, Economy.CATCHUP_STEP)
	for k in 5:
		camp.bank_run(_stats(false))
	assert_near(Economy.catchup(int(p.records.loss_streak)), Economy.CATCHUP_MAX, 0.0001, "capped")
	camp.bank_run(_stats(true))
	assert_eq(p.records.loss_streak, 0, "a win resets it")

func test_crowns_payout_table() -> void:
	var f := GameFlow.new_run("knight", 1, 28, {"profile": Profile.fresh().to_dict()})
	var r := f.run
	r.lap = 8
	r.act = 2
	r.gold = 999
	var res := MetaRun.rewards(r, false)
	var parts := {}
	for x in res.breakdown:
		parts[x[0]] = int(x[1])
	assert_eq(parts.laps, 7 * Economy.CROWNS_PER_LAP)
	assert_eq(parts.biomes, Economy.CROWNS_PER_BIOME)
	assert_eq(parts.gold, Economy.GOLD_CROWN_CAP, "leftover gold capped")
	assert_eq(parts.victory, 0)
	r.lap = 15
	r.act = 3
	var win := MetaRun.rewards(r, true)
	assert_true(int(win.crowns) > int(res.crowns) * 1.5, "a win pays much more than an act-2 death")
	var s := GameFlow.new_run("knight", 1, 28, {"profile": Profile.fresh().to_dict(), "mode": "short"})
	s.run.lap = 10
	s.run.act = 2
	var short_win := MetaRun.rewards(s.run, true)
	assert_true(absf(float(short_win.crowns) / float(win.crowns) - Economy.SHORT_CROWN_MULT) < 0.1, "Short Road ~60%")
	var legacy := GameFlow.new_run("knight", 1)
	assert_eq(MetaRun.rewards(legacy.run, true).crowns, 0, "no meta, no Crowns")

# ================================================================ run options

func test_new_run_options() -> void:
	var p := Profile.fresh()
	var f := GameFlow.new_run("mage", 1, 28, {"profile": p.to_dict()})
	assert_eq(f.run.class_id, "knight", "locked class falls back to an owned one")
	assert_eq(f.run.route, ["glade", "hollow", "throne"] as Array[String], "fresh route is fixed by the unlocks")
	assert_eq(f.run.boss_id, "boss_lich")
	assert_eq(f.run.belt, ["healing"] as Array[String], "one Healing Draught to start")
	var a := GameFlow.new_run("knight", 1, 28, {"profile": p.to_dict(), "ascension": 5})
	assert_eq(int(a.run.meta.asc), 5)
	assert_true(a.run.has_asc("potions"))
	assert_true(a.run.belt.is_empty(), "A5: no starting potion")
	var m := Profile.fresh()
	m.loadout.mode = "short"
	var s := GameFlow.new_run("knight", 1, 28, {"profile": m.to_dict()})
	assert_eq(s.run.mode, "short", "mode defaults to the profile loadout's")
	assert_eq(s.run.total_laps(), Balance.SHORT_LAPS)
	assert_eq(s.run.route.size(), 2)
	assert_eq(s.run.miniboss_lap(), Balance.SHORT_MINIBOSS_LAP)
	assert_true(s.run.is_shop_lap(1) and not s.run.is_shop_lap(2))

# ================================================================ potions

func test_potion_belt_rules() -> void:
	var f := _pet_flow("pumpkin_sprite")
	f.run.meta.erase("pet")
	f.run.hp = 50
	var ev := f.use_potion()
	assert_eq(_first(ev, "potion_used").healed, 30, "30% of 100")
	assert_eq(f.use_potion()[0].type, "error", "belt empty")
	f.run.belt.assign(["stoneskin", "healing"])
	f.run.sync_potions()
	assert_eq(f.use_potion(0)[0].type, "error", "Stoneskin is combat-only")
	_fight(f)
	f.run.hp = 50
	assert_eq(f.use_potion(0)[0].type, "potion_used")
	assert_eq(f.run.block, PotionDefs.STONESKIN_BLOCK)
	assert_eq(f.use_potion(0)[0].type, "error", "one potion per combat turn")
	# a full belt drinks a new potion at once
	f.run.belt.assign(["healing", "healing"])
	f.run.sync_potions()
	var ev2: Array[Dictionary] = []
	assert_true(not f._gain_potion(ev2, "shop"), "belt full")
	assert_eq(Balance.POTION_MAX_CAP, 3)

func test_potion_types_exist() -> void:
	assert_eq(PotionDefs.IDS, ["healing", "stoneskin", "reroll_tonic", "cleanse"])
	var f := _pet_flow("pumpkin_sprite")
	_fight(f)
	f.run.belt.assign(["reroll_tonic"])
	f.run.sync_potions()
	var r0 := f.combat.rerolls_left
	f.use_potion(0)
	assert_eq(f.combat.rerolls_left, r0 + PotionDefs.TONIC_REROLLS)

# ================================================================ pets

func test_pet_charge_persists_across_fights_and_fires_automatically() -> void:
	var f := _pet_flow("pumpkin_sprite")
	_fight(f)
	f.combat.dice_values.assign([3, 3])
	var ev := f.combat_attack()
	assert_eq(_first(ev, "pet_charged").charge, 1, "a Pair charges the Sprite")
	# end the fight and start another: the charge is still there
	f.combat.enemies[0].hp = 1
	f.combat.dice_values.assign([6, 6])
	f.combat_attack()
	var carried := int(f.run.pet_state.charge)
	assert_eq(carried, 2)
	_fight(f)
	assert_eq(int(f.run.pet_state.charge), carried, "charge persists across fights")
	f.run.pet_state.charge = PetDefs.size("pumpkin_sprite")
	f.run.hp = 50
	f.combat.dice_values.assign([1, 5])
	ev = f.combat_attack()
	var acted := _first(ev, "pet_acted")
	assert_eq(acted.effect, "heal", "fires by itself when full")
	assert_eq(int(f.run.pet_state.charge), 0)

func test_every_pet_acts() -> void:
	var expect := {"pumpkin_sprite": "heal", "skull_buddy": "bite", "lantern_ghost": "poison", "guard_die": "block",
		"coin_mimic": "gold", "crystal_wisp": "reroll", "pebble_golem": "block", "frost_mote": "freeze", "wick": "burn",
		"tinker_gear": "fix", "grimoire": "rune", "cauldron": "potion"}
	for pet in PetDefs.IDS:
		var f := _pet_flow(pet, 10)
		assert_eq(f.run.pet_level(), 10)
		_fight(f, "skeleton_minion,skeleton_minion")
		f.run.pet_state.charge = PetDefs.size(pet)
		f.run.pet_state["rune"] = Runes.IDS.find("blade")
		f.run.pet_state["rune_v"] = 4
		f.combat.dice_values.assign([4, 4])
		var ev: Array[Dictionary] = []
		if pet == "cauldron":
			# Bubbles charges per fight won and brews right after the fight
			f.run.pet_state.charge = PetDefs.size(pet) - 1
			f.combat.enemies[0].hp = 1
			f.combat.enemies[1].hp = 0
			f.combat.target = 0
			ev = f.combat_attack()
		elif pet == "crystal_wisp":
			ev = f.combat.start_turn(f.run)
		else:
			ev = f.combat_attack()
		var acted := _first(ev, "pet_acted")
		assert_eq(acted.get("effect", ""), expect[pet], pet)

func test_pet_xp_banks_after_the_run() -> void:
	var p := Profile.fresh()
	p.grant("pets", "skull_buddy")
	var camp := Camp.new(p)
	camp.bank_run(_stats(false, {"pet": "skull_buddy", "pet_fights": 12}))
	assert_eq(int(p.pet_xp.skull_buddy), 12)

# ================================================================ minigames

func test_minigame_tiles_one_per_equipped_game() -> void:
	var p := Profile.fresh()
	var f := GameFlow.new_run("knight", 3, 28, {"profile": p.to_dict()})
	var games := []
	for t in f.run.board.tiles:
		if t.type == "minigame":
			games.append(String(t.game))
	games.sort()
	assert_eq(games, ["claw_machine", "scratch_off"])

func test_minigame_tiers_skill_band_and_par() -> void:
	assert_eq(MinigameDefs.tier_for(0.5), "bronze")
	assert_eq(MinigameDefs.tier_for(MinigameDefs.PAR), "silver")
	assert_eq(MinigameDefs.tier_for(1.3), "gold")
	assert_near(MinigameDefs.skill_mult(2.0), 1.0 + MinigameDefs.SKILL_BAND)
	assert_near(MinigameDefs.skill_mult(0.1), 1.0 - MinigameDefs.SKILL_BAND)
	assert_near(MinigameDefs.PAR, 1.0)
	var f := GameFlow.new_run("knight", 1, 28, {"profile": Profile.fresh().to_dict()})
	f.debug_open("minigame", "claw_machine")
	assert_eq(f.phase, P.MINIGAME)
	var ev := f.minigame_auto()
	var res := _first(ev, "minigame_result")
	assert_eq(res.auto, true)
	# the sims' average player: a tier drawn from the calibrated split, at that tier's ratio
	assert_eq(String(res.tier), MinigameDefs.tier_for(float(res.ratio)))
	assert_near(float(res.ratio), float(MinigameDefs.SIM_RATIO[res.tier]), 0.001)
	assert_eq(f.offer.kind, "reward")
	assert_eq(f.offer.tier, res.tier)
	f.pick_draft(0)
	assert_true(f.phase != P.MINIGAME)

func test_minigame_save_at_entry_resumes_identically() -> void:
	for game in MinigameDefs.IDS:
		var f := GameFlow.new_run("knight", 5, 28, {"profile": Profile.fresh().to_dict()})
		var ev := f.debug_open("minigame", game)
		assert_eq(_first(ev, "minigame_started").save_point, true)
		var saved := JSON.stringify(f.to_dict())
		var g := GameFlow.from_dict(JSON.parse_string(saved))
		for k in 8:
			if f.phase != P.MINIGAME:
				break
			var cmd := BotMeta.minigame_command(f)
			if cmd[0] == "minigame_auto":
				BotMeta.minigame_mode = "play"
				cmd = BotMeta.minigame_command(f)
				BotMeta.minigame_mode = "par"
			var a := f.apply(cmd)
			var b := g.apply(cmd)
			assert_eq(JSON.stringify(a), JSON.stringify(b), "%s step %d" % [game, k])

func test_minigame_medians_are_calibrated() -> void:
	# luck/deduction games: the bot's played median sits near MinigameDefs.MEDIAN; dexterity and
	# tracking games (claw, bubbles, shooter, shell, fishing): the bot's perfect play scores at
	# least the human median. Memory Match is skipped: the bot has no memory (tools/mg_calibrate
	# models the human one; test_minigames2 checks a perfect memory clears the board).
	var skill := ["claw_machine", "bubble_breaker", "bubble_shooter", "shell_game", "fishing"]
	for game in MinigameDefs.IDS:
		if game == "memory_match":
			continue
		var scores: Array = []
		for s in (60 if game != "bubble_shooter" else 12):
			var m := Minigames.create(game, 1000 + s * 7, 1)
			var guard := 0
			while not m.done and m.actions_left > 0 and guard < 40:
				guard += 1
				var cmd := BotMeta.play_args(game, m.public_state(), s)
				if game == "claw_machine":
					cmd = [(m as ClawMachine).best_target()]
				if cmd.is_empty():
					break
				m.action(cmd)
			scores.append(m.score())
		scores.sort()
		var med := float(scores[scores.size() / 2]) / float(MinigameDefs.MEDIAN[game])
		if skill.has(game):
			assert_true(med >= 0.9, "%s perfect-aim median ratio %.2f" % [game, med])
		else:
			assert_true(med > 0.7 and med < 1.35, "%s played median ratio %.2f" % [game, med])

# ================================================================ ascension

func test_ascension_ladder() -> void:
	assert_eq(UnlockDefs.ascension_keys(0), [])
	assert_eq(UnlockDefs.ascension_keys(10).size(), 10)
	assert_eq(UnlockDefs.ascension_keys(99).size(), UnlockDefs.MAX_ASCENSION)
	var keys := {}
	for a in UnlockDefs.ASCENSION:
		keys[a.key] = true
	assert_eq(keys.size(), 10, "one system per level")

func test_a10_double_final_boss() -> void:
	var p := Profile.fresh()
	var f := GameFlow.new_run("knight", 1, 28, {"profile": p.to_dict(), "ascension": 10})
	f.debug_open("boss")
	f.combat.enemies[0].hp = 1
	f.combat.enemies[0].block = 0
	f.combat.dice_values.assign([6, 6])
	var ev := f.combat_attack()
	var second := _first(ev, "second_boss")
	assert_true(not second.is_empty(), "A10: a second final boss follows")
	assert_eq(f.phase, P.COMBAT)
	var e: Dictionary = f.combat.enemies[0]
	assert_eq(String(e.id), String(second.id))
	var full := int(EnemyDefs.def(String(e.id)).hp)
	assert_true(int(e.max_hp) < full, "at reduced HP")
	var a0 := GameFlow.new_run("knight", 1, 28, {"profile": p.to_dict()})
	a0.debug_open("boss")
	a0.combat.enemies[0].hp = 1
	a0.combat.enemies[0].block = 0
	a0.combat.dice_values.assign([6, 6])
	a0.combat_attack()
	assert_eq(a0.phase, P.VICTORY, "A0: one boss")
