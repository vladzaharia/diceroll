extends "res://tests/test_case.gd"
## The real-item Armory core (docs/design/2026-09-29-armory-items.md): ItemDefs data, tiers,
## Profile v3 (+ v2 migration), Camp commands, MetaRun.build, mastery / feats / blueprints, the
## item rules in combat and on the board (ItemLogic), saves and replays.

const P := GameFlow.Phase

var run: RunState
var c: CombatState

func _all(ev: Array, type: String, effect := "") -> Array:
	var out := []
	for e in ev:
		if String(e.type) == type and (effect == "" or String(e.get("effect", "")) == effect):
			out.append(e)
	return out

## A meta run of `cls` whose items are exactly `items` ({slot: [id, variant, tier]}).
func _run(cls: String, items: Dictionary, seed := 1) -> RunState:
	var meta := MetaRun.build(Profile.fresh(false).to_dict(), cls)
	var its := {}
	for slot in items:
		var e: Array = items[slot]
		its[slot] = {"id": String(e[0]), "variant": String(e[1]), "tier": int(e[2])}
	meta.items = its
	return RunState.create(cls, seed, Balance.BOARD_SIZE, {"meta": meta})

## A fight against `ids` with sturdy, passive enemies (100 HP, aiming).
func _fight(cls: String, items: Dictionary, ids: Array = ["skeleton_minion"], dice: Array = []) -> Array[Dictionary]:
	run = _run(cls, items)
	if not dice.is_empty():
		run.dice.clear()
		for d in dice:
			run.dice.append(Die.make(String(d[1]), String(d[0])))
	c = CombatState.new()
	var ev := c.begin(run, ids, false, false, 3)
	for e in c.enemies:
		e.hp = 100
		e.max_hp = 100
		e.intent = {"kind": "aim", "value": 0}
	return ev

func _dice(values: Array) -> void:
	c.dice_values.assign(values)
	c.rerolled.fill(false)

# ================================================================ ItemDefs

func test_item_tables_are_complete() -> void:
	var by_slot := {}
	for id in ItemDefs.IDS:
		assert_true(ItemDefs.ITEMS.has(id), "IDS lists unknown %s" % id)
		var s := ItemDefs.slot_of(String(id))
		by_slot[s] = int(by_slot.get(s, 0)) + 1
	for id in ItemDefs.ITEMS:
		assert_true(ItemDefs.IDS.has(id), "%s missing from IDS" % id)
		var d: Dictionary = ItemDefs.ITEMS[id]
		for k in ["name", "slot", "effect", "affinity", "std"]:
			assert_true(d.has(k), "%s lacks %s" % [id, k])
		if String(d.slot) == "back":
			assert_true(bool(d.cosmetic) and (d.effect as Dictionary).is_empty(), "%s: Back items are Style only" % id)
		else:
			assert_true(not (d.effect as Dictionary).is_empty(), "%s has a rule" % id)
			for key in (d.effect.n as Dictionary):
				assert_eq((d.effect.n[key] as Array).size(), 3, "%s.%s has I/II/III" % [id, key])
	# §0 content counts: 16 weapons, 8 off-hands, 8 heads, 10 bodies + the Dino Suit, 8 trinkets, 13 Back
	assert_eq(by_slot, {"weapon": 16, "offhand": 8, "head": 8, "body": 11, "trinket": 8, "back": 13})
	var var_count := {"weapon": 0, "offhand": 0, "head": 0}
	for id in ItemDefs.IDS:
		var s2 := ItemDefs.slot_of(String(id))
		if var_count.has(s2):
			var_count[s2] += ItemDefs.variants_of(String(id)).size()
	# the §5 tables (the §0 summary's 36 / 14 undercounts its own tables: they list 55 / 16)
	assert_eq(var_count, {"weapon": 55, "offhand": 16, "head": 12}, "variants incl. Standards (§5.2, §5.3)")
	for v in ItemDefs.VARIANTS:
		var vd: Dictionary = ItemDefs.VARIANTS[v]
		assert_true(ItemDefs.ITEMS.has(String(vd.item)), "%s: unknown base %s" % [v, vd.item])
		assert_true(not ItemDefs.ITEMS.has(v), "%s: a variant id can't be an item id" % v)
		var u: Dictionary = vd.unlock
		assert_true(u.has("mastery") or u.has("feat") or u.has("class"), "%s has an unlock" % v)
		if u.has("mastery"):
			assert_true(ItemDefs.MASTERY.has(int(u.mastery)), "%s mastery threshold" % v)
		if u.has("feat"):
			assert_true(ItemDefs.FEATS.has(String(u.feat)), "%s: unknown feat %s" % [v, u.feat])
		assert_true(ItemDefs.unlock_text(String(v)) != "", "%s unlock text" % v)
		assert_true(not ItemDefs.craft_cost(String(v)).is_empty(), "%s craft cost" % v)

func test_item_ids_match_the_presentation_tables() -> void:
	for id in ItemDefs.IDS:
		var s := ItemDefs.slot_of(String(id))
		if s == "back":
			assert_true(ItemMounts.BACKS.has(id), "ItemMounts.BACKS lacks %s" % id)
		elif s == "head":
			assert_true(ItemMounts.HEADS.has(id), "ItemMounts.HEADS lacks %s" % id)
		elif s == "body":
			assert_true(ItemMounts.BODIES.has(id), "ItemMounts.BODIES lacks %s" % id)
		else:
			assert_true(ItemMounts.ITEMS.has(id), "ItemMounts.ITEMS lacks %s" % id)
	for v in ItemDefs.VARIANTS:
		var s2 := ItemDefs.slot_of(String(ItemDefs.VARIANTS[v].item))
		assert_true(ItemMounts.HEADS.has(v) if s2 == "head" else ItemMounts.ITEMS.has(v), "no look for variant %s" % v)
		if ItemDefs.VARIANTS[v].has("hands"):
			assert_eq(ItemMounts.hands(String(v)), int(ItemDefs.VARIANTS[v].hands), "%s hands" % v)
	for id in ItemMounts.BASES:
		assert_true(ItemDefs.has(String(id)), "look without rules: %s" % id)
		if ItemMounts.BASES[id].has("hands"):
			assert_eq(ItemDefs.hands(String(id)), int(ItemMounts.BASES[id].hands), "%s hands" % id)
		if ItemMounts.BASES[id].has("style"):
			assert_eq(ItemDefs.style(String(id)), String(ItemMounts.BASES[id].style), "%s style" % id)

func test_kits_are_valid_and_every_class_has_one() -> void:
	for cid in HeroDefs.IDS:
		assert_true(ItemDefs.KITS.has(cid), "kit for %s" % cid)
		for id in ItemDefs.kit_items(String(cid)):
			assert_true(ItemDefs.has(String(id)), "%s kit: %s" % [cid, id])
		var p := Profile.fresh(false)
		var lo := p.loadout_for(String(cid))
		var w: Dictionary = lo.weapon
		assert_true(String(w.id) != "", "%s has a weapon" % cid)
		assert_true(ItemDefs.affinity(String(w.id), String(cid)), "%s: its weapon is its signature" % cid)
		if ItemDefs.hands(String(w.id), String(w.variant)) >= 2:
			assert_true(not ItemDefs.hand_mount(String(lo.offhand.id)), "%s: 2H weapon with a hand off-hand" % cid)
	assert_eq(String(Profile.fresh(false).loadout_for("necromancer").weapon.variant), "staff_bone", "the skull staff")
	var mk := Profile.fresh(false).loadout_for("monster_kid")
	assert_eq(String(mk.body), "dino_suit")
	assert_eq(String(mk.head.id), "", "the Dino Suit covers the head")

func test_tiers_affinity_and_the_pouch() -> void:
	assert_eq([ItemDefs.rank_tier(0), ItemDefs.rank_tier(1), ItemDefs.rank_tier(3), ItemDefs.rank_tier(4), ItemDefs.rank_tier(7), ItemDefs.rank_tier(8)],
		[0, 1, 1, 2, 2, 3])
	assert_eq(ItemDefs.tier_for("sword", "weapon", "knight", 0), 0, "R0: no effect, even with affinity")
	assert_eq(ItemDefs.tier_for("sword", "weapon", "knight", 1), 2, "affinity +1")
	assert_eq(ItemDefs.tier_for("sword", "weapon", "knight", 8), 3, "cap III")
	assert_eq(ItemDefs.tier_for("sword", "weapon", "mage", 1), 1)
	assert_eq(ItemDefs.tier_for("arcane_staff", "weapon", "necromancer", 4), 3, "the Staff is Mage and Necromancer")
	assert_eq(ItemDefs.tier_for("compass", "trinket2", "knight", 8), 2, "pouch: a tier lower")
	assert_eq(ItemDefs.tier_for("compass", "trinket2", "knight", 5), 1, "pouch: min I")
	assert_eq(ItemDefs.tier_for("knight_cape", "back", "knight", 8), 0, "Back: no stats")
	# the Standard variant's x1.2
	var gm: float = ItemDefs.ITEMS.greatsword.effect.n.mult[0]
	assert_near(ItemDefs.num("greatsword", "mult", 1, "greatsword"), gm * 1.2)
	assert_near(ItemDefs.num("greatsword", "mult", 1, "greatsword_zwei"), gm, 0.0001, "variants keep the base numbers")
	var sf: float = ItemDefs.ITEMS.spear.effect.n.factor[2]
	assert_near(ItemDefs.num("spear", "factor", 3, "spear"), 1.0 + (sf - 1.0) * 1.2, 0.0001, "a factor scales its bonus")
	assert_near(ItemDefs.num("dagger", "turns", 3, "dagger"), float(ItemDefs.ITEMS.dagger.effect.n.turns[2]), 0.0001,
		"count rules keep their numbers (the Standard gives Block instead)")
	assert_true(ItemDefs.std_text("dagger").begins_with("Standard: Block %d on turn 1" % ItemDefs.STD_BLOCK))
	assert_true(ItemDefs.rule_text("sword", 3, "sword_saber").begins_with("Pair or Two Pair: +%d damage" % int(ItemDefs.num("sword", "flat", 3, "sword_saber"))),
		"rule text carries the tier's numbers")
	assert_true(not ItemDefs.rule_text("sword", 3).contains("{"), "no placeholder left")
	assert_eq(ItemDefs.rule_text("knight_cape", 3), "Style")

# ================================================================ profile

func test_fresh_profile_owns_the_knight_kit_at_rank_zero() -> void:
	var p := Profile.fresh()
	for id in ["sword", "round_shield", "knight_helm", "knight_plate", "knight_cape", "tankard"]:
		assert_true(p.owns_item(id), "fresh owns %s" % id)
	assert_true(not p.owns_item("great_axe"))
	for g in ItemDefs.GROUPS:
		assert_eq(p.rank(g), 0)
	assert_eq(p.resolve_items("knight"), {}, "R0: nothing active")
	var m := MetaRun.build(p.to_dict(), "knight")
	assert_eq(m.items, {})
	assert_eq(int(m.hp), 0)
	assert_eq(String(m.back), "knight_cape")

func test_class_unlock_grants_the_kit() -> void:
	var p := Profile.fresh()
	assert_true(p.grant("classes", "necromancer"))
	for id in ["arcane_staff", "bone_crown", "hooded_robe", "hooded_cape"]:
		assert_true(p.owns_item(id), "necromancer kit: %s" % id)
	assert_true(p.owns_variant("arcane_staff", "staff_bone"), "with the Bone Staff")
	p.grant("classes", "monster_kid")
	assert_true(p.owns_item("dino_suit") and p.owns_item("claws"))

func test_v3_round_trip_is_idempotent() -> void:
	var p := Profile.from_dict(MetaPresets.get_preset("max"))
	var q := Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(JSON.stringify(q.to_dict()), JSON.stringify(p.to_dict()), "round trip")
	var r := Profile.from_dict(q.to_dict())
	assert_eq(JSON.stringify(r.to_dict()), JSON.stringify(p.to_dict()), "idempotent")
	assert_eq(int(p.to_dict().version), 3)
	assert_true(not p.to_dict().has("gear") and not p.to_dict().has("gear_traits"), "v2 fields gone")

func _v2(gear: Dictionary, traits: Dictionary, classes := ["knight", "mage"]) -> Dictionary:
	var d := Profile.fresh().to_dict()
	d.version = 2
	d.erase("armory")
	d.unlocks.gear = gear.keys()
	d.unlocks.classes = classes
	d["gear"] = gear
	d["gear_traits"] = traits
	return JSON.parse_string(JSON.stringify(d))

func test_v2_gear_migrates_to_ranks_and_items() -> void:
	var d := _v2({"helm": 5, "blade": 8, "boots": 6, "charm": 5},
		{"helm": {"4": "helm_campfire"}, "blade": {"4": "blade_high", "8": "blade_boss_opener"},
		"boots": {"4": "boots_portal", "8": "boots_pair_pick"}, "charm": {"4": "charm_cheap_restock", "8": "charm_treasury"}})
	var p := Profile.from_dict(d)
	assert_eq([p.rank("weapon"), p.rank("armor"), p.rank("offhand"), p.rank("trinket")], [8, 5, 6, 6], "levels -> ranks (Trinket raised to 6 for the Boots reroll)")
	for id in ["round_shield", "tankard", "sword", "hand_axe", "crossbow", "compass", "lantern", "coin_purse", "traders_map",
			"healers_flask", "spear"]:
		assert_true(p.owns_item(id), "migrated %s" % id)
	assert_true(p.has_pouch(), "boots and charm both L5+: the Belt Pouch is free")
	assert_eq(String(p.loadout_for("knight").trinket), "compass", "Boots R6: the Compass keeps its reroll in slot 1")
	assert_true(String(p.loadout_for("mage").trinket2) != "", "slot 2 gets the next trait carrier")
	assert_true(p.owns_item("wizard_hat") and p.owns_item("mage_robe"), "owned classes -> kits")
	var m := MetaRun.build(p.to_dict(), "knight")
	assert_eq(int(m.lap_rerolls), 1, "the board reroll survives migration day")
	assert_eq(int(m.atk), ItemDefs.ATK_BONUS)
	# idempotent: the migrated profile saves as v3 and reloads unchanged
	var q := Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(JSON.stringify(q.to_dict()), JSON.stringify(p.to_dict()))

func test_v2_pouch_rule_needs_both_at_five() -> void:
	var p := Profile.from_dict(_v2({"helm": 2, "blade": 3, "boots": 5, "charm": 4}, {"boots": {"4": "boots_sure_foot"}}))
	assert_true(not p.has_pouch(), "charm L4: no free pouch")
	assert_eq(String(p.loadout_for("knight").trinket), "lantern", "Sure Foot -> the Lantern")
	var v1 := _v2({}, {}, ["knight"])
	v1.version = 1
	var q := Profile.from_dict(v1)
	assert_eq(q.rank("weapon"), 0)
	assert_true(q.owns_item("sword") and q.owns_item("tankard"))

# ================================================================ camp

func test_camp_ranks_pouch_and_shop() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	p.crowns = 5000
	p.sigils = 10
	assert_eq(String(camp.buy_pouch()[0].type), "error", "needs Trinket rank 5")
	p.grant("gear", "trinket")
	for k in 5:
		camp.rank_up("trinket")
	var ev := camp.buy_pouch()
	assert_eq(String(ev.back().type), "upgrade_bought")
	assert_eq(String(ev.back().id), "pouch")
	assert_true(p.has_pouch())
	var before := p.crowns
	ev = camp.buy_item("greatsword")
	assert_eq(String(ev.back().type), "item_unlocked")
	assert_eq(p.crowns, before - int(ItemDefs.PRICES.greatsword))
	assert_eq(String(camp.buy_item("greatsword")[0].type), "error", "owned")
	assert_eq(String(camp.buy_item("sword")[0].type), "error", "kit of an owned class: not for sale")
	assert_eq(int(ItemDefs.price("great_axe", p.unlocks.classes).crowns), ItemDefs.KIT_PRICE, "another class's kit piece")
	assert_eq(int(ItemDefs.price("mage_cape", p.unlocks.classes).crowns), ItemDefs.BACK_PRICE)
	ev = camp.buy_item("loaded_die", "sigils")
	assert_eq(p.sigils, 10 - ItemDefs.ITEM_SIGILS)
	assert_true(p.owns_item("loaded_die"))

func test_camp_equip_rules() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	p.grant("classes", "barbarian")
	p.grant_item("greatsword")
	assert_eq(String(camp.equip_item("knight", "weapon", "wand")[0].type), "error", "not owned")
	assert_eq(String(camp.equip_item("knight", "offhand", "sword")[0].type), "error", "wrong slot")
	var ev := camp.equip_item("knight", "weapon", "greatsword")
	assert_eq(String(ev[0].type), "item_equipped")
	assert_eq(String(p.loadout_for("knight").offhand.id), "", "a 2H weapon drops the shield")
	assert_eq(String(camp.equip_item("knight", "offhand", "round_shield")[0].type), "error", "no hand free")
	camp.equip_item("knight", "weapon", "sword")
	assert_eq(String(camp.equip_item("knight", "offhand", "round_shield")[0].type), "item_equipped")
	assert_eq(String(camp.equip_item("knight", "trinket2", "tankard")[0].type), "error", "needs the Belt Pouch")
	p.armory.pouch = 1
	p.grant_item("compass")
	camp.equip_item("knight", "trinket2", "compass")
	camp.equip_item("knight", "trinket", "compass")
	var lo := p.loadout_for("knight")
	assert_eq([String(lo.trinket), String(lo.trinket2)], ["compass", ""], "never the same trinket twice")
	assert_eq(String(camp.unequip_item("knight", "head")[0].type), "item_equipped")
	assert_eq(String(p.loadout_for("knight").head.id), "")
	assert_eq(String(camp.equip_item("barbarian", "body", "knight_plate")[0].type), "item_equipped", "armor is shared")
	assert_eq(String(p.loadout_for("barbarian").body), "knight_plate")
	p.grant("classes", "monster_kid")
	assert_eq(String(camp.equip_item("monster_kid", "head", "knight_helm")[0].type), "error", "Dino Suit locked")
	assert_eq(String(camp.equip_item("knight", "body", "dino_suit")[0].type), "error", "class-only")
	assert_eq(String(camp.set_appearance("knight", "head", "hidden")[0].type), "appearance_set")
	assert_eq(p.appearance_of("knight").head, "hidden")
	assert_eq(p.appearance_of("paladin").head, "hidden", "the Paladin's default look is helmet-less")
	assert_eq(String(camp.set_appearance("knight", "body", "hidden")[0].type), "error", "only heads hide")
	# the replay format
	assert_eq(String(camp.apply(["equip_item", "knight", "weapon", "sword", "sword"])[0].type), "item_equipped")

func test_mastery_blueprints_and_crafting() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	p.crowns = 1000
	var st := {"victory": false, "class_id": "knight", "loadout": {"weapon": {"id": "sword", "variant": "sword"},
		"offhand": {"id": "round_shield", "variant": "round_shield"}}, "item_fights": 9, "fights_won": 9}
	camp.bank_run(st)
	assert_eq(p.item_mastery("sword"), 9)
	assert_true(not p.has_blueprint("sword", "sword_training"))
	assert_eq(String(camp.craft_variant("sword", "sword_training")[0].type), "error", "blueprint locked")
	var ev := camp.bank_run(st)
	assert_eq(p.item_mastery("sword"), 18)
	var bps := _all(ev, "blueprint_unlocked")
	assert_true(bps.size() >= 2, "15 fights: the Training Sword and the Plank Shield")
	assert_true(p.has_blueprint("sword", "sword_training"))
	var ms := _all(ev, "mastery_changed")
	assert_true(not ms.is_empty() and int(ms[0].next) == 45, "next blueprint at 45")
	ev = camp.craft_variant("sword", "sword_training")
	assert_eq(String(ev.back().type), "variant_crafted")
	assert_eq(p.crowns, 1000 - ItemDefs.CRAFT_COSTS[0])
	assert_true(p.owns_variant("sword", "sword_training") and not p.has_blueprint("sword", "sword_training"))
	assert_eq(String(camp.equip_item("knight", "weapon", "sword", "sword_training")[0].type), "item_equipped")
	assert_eq(String(p.loadout_for("knight").weapon.variant), "sword_training")

func test_feats_unlock_blueprints_and_back_items() -> void:
	var p := Profile.fresh()
	var st := {"victory": true, "class_id": "knight", "asc": 0, "bosses_killed": ["boss_cinder_king"],
		"minibosses_killed": ["mini_orc_warchief"], "kills_by_id": {"mini_orc_warchief": 1},
		"loadout": {"weapon": {"id": "sword", "variant": "sword"}}, "item_fights": 1}
	var res := p.apply_run_result(st)
	assert_true(p.has_blueprint("sword", "sword_flame"), "the Cinder King with a Sword")
	assert_true(p.owns_item("orc_warpack"), "the Orc Warchief: the Orc Warpack")
	assert_true(not res.items_unlocked.is_empty())
	assert_eq(int(ItemDefs.craft_cost("sword_flame").crowns), ItemDefs.FEAT_CRAFT)
	p.records.counters.skeleton_kills = 299
	p.apply_run_result({"class_id": "knight", "skeleton_kills": 1})
	assert_true(p.owns_item("bone_cloak") and p.owns_item("grave_cape"), "Bone Collector")
	assert_true(p.has_blueprint("knight_helm", "helm_bone"), "300 skeletons: the bone set")

func test_catalog_lists_ranks_items_and_crafts() -> void:
	var p := Profile.from_dict(MetaPresets.get_preset("mid"))
	p.crowns = 10000
	p._ranks()["trinket"] = ItemDefs.POUCH_RANK
	var cmds := {}
	for it in Camp.new(p).catalog():
		cmds[String(it.cmd[0])] = true
	for k in ["rank_up", "buy_pouch", "buy_item"]:
		assert_true(cmds.has(k), "catalog has %s" % k)
	assert_true(Camp.total_crowns_sink() > 2920 + 400, "ranks + pouch + items + variants")
	p.add_blueprint("sword", "sword_knight")
	var found := false
	for it in Camp.new(p).catalog():
		if String(it.cmd[0]) == "craft_variant" and String(it.cmd[2]) == "sword_knight":
			found = true
	assert_true(found, "blueprints are craftable from the catalog")

# ================================================================ run build

func test_build_resolves_items_and_stats() -> void:
	var m := MetaRun.build(MetaPresets.get_preset("max"), "knight")
	assert_eq(int(m.atk), ItemDefs.ATK_BONUS)
	assert_eq(int(m.hp), ItemDefs.HP_CAP)
	assert_eq(String(m.items.weapon.id), "sword")
	assert_eq(int(m.items.weapon.tier), 3)
	assert_eq(String(m.items.trinket.id), "tankard", "the realistic max: the default kit")
	assert_true(not m.items.has("trinket2"), "the Belt Pouch starts empty")
	var s1 := MetaRun.armory_stats({"trinket": 6}, {"trinket": {"id": "compass", "variant": "compass", "tier": 2}})
	assert_eq(int(s1.lap_rerolls), 1, "Compass R6+ in slot 1")
	assert_eq(ItemDefs.tier_for("compass", "trinket2", "knight", 8), 2, "the pouch works a tier lower")
	var s2 := MetaRun.armory_stats({"trinket": 8}, {"trinket2": {"id": "compass", "variant": "compass", "tier": 2}})
	assert_eq(int(s2.lap_rerolls), 0, "never from slot 2")
	var s3 := MetaRun.armory_stats({"weapon": 1}, {"weapon": {"id": "greatsword", "variant": "greatsword_plain", "tier": 1}})
	assert_eq(int(s3.max_hp), 3, "Steel: +3 max HP")
	var nm := MetaRun.build(MetaPresets.get_preset("max"), "necromancer")
	assert_eq(String(nm.items.weapon.variant), "staff_bone")
	var mk := MetaRun.build(MetaPresets.get_preset("max"), "monster_kid")
	assert_eq(String(mk.items.body.id), "dino_suit")
	assert_true(not mk.items.has("head"))
	var f := GameFlow.new_run("paladin", 4, Balance.BOARD_SIZE, {"profile": MetaPresets.get_preset("max")})
	var back := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	assert_eq(back.run.meta.items, f.run.meta.items, "items survive a save")

func test_legacy_runs_have_no_items() -> void:
	var f := GameFlow.new_run("knight", 7)
	f.debug_open("combat", "skeleton_minion")
	var ev: Array[Dictionary] = []
	for k in 40:
		if f.phase != P.COMBAT:
			break
		ev.append_array(f.apply(Bot.next_command(f)))
	assert_eq(_all(ev, "item_triggered").size(), 0)

# ================================================================ combat rules

func test_twin_edge_and_standard_bonus() -> void:
	_fight("knight", {"weapon": ["sword", "sword", 3]}, ["skeleton_minion"], [["standard", ""], ["standard", ""], ["standard", ""]])
	_dice([5, 5, 2])
	c.target = 0
	var ev := c.attack(run)
	var te := _all(ev, "item_triggered", "twin_edge")
	assert_eq(te.size(), 1)
	assert_eq(int(te[0].value), int(ItemDefs.num("sword", "flat", 3, "sword")))
	var combo: Dictionary = _all(ev, "combo")[0]
	assert_eq(int(combo.total), int(floor((5 + 5 + 2) * float(combo.mult))) + int(te[0].value) + run.atk)

func test_bulwark_plated_and_steadfast() -> void:
	var ev := _fight("knight", {"offhand": ["round_shield", "round_shield", 3], "body": ["knight_plate", "knight_plate", 3],
		"head": ["knight_helm", "knight_helm", 3]})
	var bw := int(ItemDefs.num("round_shield", "block", 3, "round_shield"))
	var pl := int(ItemDefs.num("knight_plate", "block", 3))
	var sf := int(ItemDefs.num("knight_helm", "extra", 3, "knight_helm"))
	assert_eq(run.block, bw + pl + sf, "turn 1: Bulwark + Plated + Steadfast once")
	assert_eq(_all(ev, "item_triggered", "steadfast").size(), 1, "once per turn")
	_dice([1, 3, 6])
	c.target = 0
	c.attack(run)
	var pl2 := pl if 2 <= int(ItemDefs.num("knight_plate", "turns", 3)) else 0
	assert_eq(run.block, pl2 + (sf if pl2 > 0 else 0), "turn 2: Plated only on its turns")

func test_last_stand_at_tier_three() -> void:
	run = _run("knight", {"offhand": ["round_shield", "round_shield", 3]})
	run.hp = run.max_hp
	var hp0 := run.hp
	run.hp = -5
	assert_eq(run.survive_lethal(hp0), "last_stand")
	assert_eq(run.hp, 1)
	run.hp = -5
	assert_eq(run.survive_lethal(hp0), "", "once per run")
	var r2 := _run("knight", {"offhand": ["round_shield", "round_shield", 2]})
	r2.hp = -1
	assert_eq(r2.survive_lethal(r2.max_hp), "", "tier II: no Last Stand")

func test_opening_volley_and_quick_draw() -> void:
	var ev := _fight("ranger", {"weapon": ["hunting_bow", "bow_short", 2]}, ["skeleton_minion", "skeleton_warrior"])
	var v := _all(ev, "item_triggered", "opening_volley")
	assert_eq(v.size(), 1)
	assert_eq(int(v[0].value), int(round(ItemDefs.num("hunting_bow", "dmg", 2, "bow_short") * ItemLogic.lap_scale(c.lap))))
	_dice([1, 3, 6])
	c.target = 0
	var ev2 := c.attack(run)
	assert_eq(_all(ev2, "item_triggered", "opening_volley").size(), 1, "the Short Bow fires again on turn 2")

func test_volley_can_win_before_turn_one() -> void:
	run = _run("ranger", {"weapon": ["hunting_bow", "hunting_bow", 3]})
	c = CombatState.new()
	run.stats["x"] = 0
	var ev := c.begin(run, ["skeleton_minion"], false, false, 3)
	# a Skeleton Minion has 12 HP at lap 1: the Standard Volley at III deals 8
	if int(c.enemies[0].hp) <= 0:
		assert_eq(c.result, "won")
		assert_eq(_all(ev, "combat_turn_started").size(), 0)
	else:
		assert_eq(c.result, "")

func test_rampage_stacks_and_resets() -> void:
	_fight("barbarian", {"weapon": ["great_axe", "great_axe", 1]}, ["skeleton_minion", "skeleton_warrior"])
	var per := int(ItemDefs.num("great_axe", "per", 1, "great_axe"))
	var flats := []
	for k in 3:
		_dice([1, 3, 6])
		c.target = 0
		var ev := c.attack(run)
		var r := _all(ev, "item_triggered", "rampage")
		flats.append(int(r[0].value) if not r.is_empty() else 0)
	var cap := int(ItemDefs.num("great_axe", "stacks", 1, "great_axe"))
	assert_eq(flats, [0, per, mini(2, cap) * per], "consecutive hits stack (to the cap)")
	_dice([1, 3, 6])
	c.target = 1
	var ev3 := c.attack(run)
	assert_eq(_all(ev3, "item_triggered", "rampage").size(), 0, "a target change resets")

func test_crush_never_on_heavy_and_cleave_carries() -> void:
	_fight("paladin", {"weapon": ["warhammer", "warhammer", 2]}, ["skeleton_minion"], [["standard", "heavy"], ["standard", ""], ["standard", ""]])
	_dice([6, 6, 4])
	c.target = 0
	var ev := c.attack(run)
	var cr := _all(ev, "item_triggered", "crush")
	assert_eq(cr.size(), 1)
	assert_eq(int(cr[0].die_idx), 1, "the Heavy die is skipped")
	_fight("knight", {"weapon": ["hand_axe", "hand_axe", 3]}, ["skeleton_minion", "skeleton_warrior"])
	c.enemies[0].hp = 3
	_dice([6, 6, 5])
	c.target = 0
	var ev2 := c.attack(run)
	assert_eq(_all(ev2, "item_triggered", "cleave").size(), 1)

func test_smoke_bomb_thorns_and_catch() -> void:
	_fight("rogue", {"offhand": ["smoke_bomb", "smoke_bomb", 3]})
	c.enemies[0].intent = {"kind": "attack", "value": 10}
	run.block = 0
	var hp0 := run.hp
	_dice([1, 3, 6])
	c.target = 0
	var ev := c.attack(run)
	var cut := mini(int(ItemDefs.num("smoke_bomb", "max", 3, "smoke_bomb")), int(round(10 * ItemDefs.num("smoke_bomb", "pct", 3, "smoke_bomb"))))
	assert_eq(hp0 - run.hp, 10 - cut, "Vanish cuts the first hit")
	assert_eq(_all(ev, "item_triggered", "vanish").size(), 1)
	_fight("knight", {"offhand": ["spiked_shield", "shield_dragon", 2]})
	c.enemies[0].intent = {"kind": "attack", "value": 4}
	var e_hp := int(c.enemies[0].hp)
	_dice([1, 3, 6])
	c.target = 1
	var ev2 := c.attack(run)
	assert_eq(_all(ev2, "item_triggered", "thorns").size(), 1)
	assert_eq(_all(ev2, "item_triggered", "scorch").size(), 1, "Dragon Shield poisons")
	assert_true(int(c.enemies[0].hp) < e_hp)

func test_focus_refunds_a_single_die_reroll() -> void:
	_fight("knight", {"head": ["ninja_headband", "ninja_mask", 1]})
	var left := c.rerolls_left
	c.marked.fill(false)
	c.marked[0] = true
	var ev := c.reroll(run)
	assert_eq(_all(ev, "item_triggered", "focus").size(), 1)
	assert_eq(_all(ev, "item_triggered", "silent").size(), 1, "Ninja Mask")
	assert_eq(c.rerolls_left, left, "refunded")
	c.marked[0] = true
	c.reroll(run)
	assert_eq(c.rerolls_left, left - 1, "tier I: once per fight")

func test_loaded_die_rerolls_low_faces_on_the_first_roll() -> void:
	run = _run("knight", {"trinket": ["loaded_die", "loaded_die", 3]})
	run.dice.clear()
	for k in 3:
		var d := Die.make("", "standard")
		d.faces = PackedInt32Array([1, 1, 1, 1, 1, 1] if k == 0 else [6, 6, 6, 6, 6, 6])
		run.dice.append(d)
	c = CombatState.new()
	var ev := c.begin(run, ["skeleton_minion"], false, false, 3)
	assert_eq(_all(ev, "item_triggered", "weighted").size(), 1)
	var rolled := []
	for e in ev:
		if String(e.type) == "dice_rolled" and String(e.get("source", "")) == "loaded_die":
			rolled.append(e)
	assert_eq(rolled.size(), 1)

func test_trinkets_on_the_board_and_in_shops() -> void:
	var f := GameFlow.new_run("knight", 11)
	f.run = _run("knight", {"trinket": ["traders_map", "traders_map", 3], "trinket2": ["compass", "compass", 2]}, 11)
	f.debug_open("shop")
	assert_eq(int(f.offer.restock_price), int(ItemDefs.num("traders_map", "restock", 3)))
	assert_eq(int(f.offer.free_restocks), 1)
	assert_eq(ItemLogic.pair_pick(f.run), 0, "the move tie-break stays random (see balance.md)")
	assert_eq(ItemLogic.portal_bonus(f.run), int(ItemDefs.num("compass", "portal", 2)))
	f.run = _run("knight", {"trinket": ["tankard", "tankard", 3], "body": ["druid_robe", "druid_robe", 2]}, 11)
	assert_near(f.run.lap_heal_pct(), Balance.LAP_HEAL_PCT + ItemDefs.num("tankard", "lap", 3))
	assert_eq(ItemLogic.lap_heal_flat(f.run), int(ItemDefs.num("druid_robe", "heal", 2)))
	f.run = _run("engineer", {"weapon": ["wrench", "wrench", 2], "head": ["goggles", "goggles", 3]}, 11)
	f.debug_open("shop")
	for it in f.offer.items:
		if String(it.id) == "face_raise":
			assert_eq(int(it.price), int(ItemDefs.num("wrench", "raise_price", 2)), "Tinker")
		if String(it.id) == "die":
			assert_true(int(it.price) < int(DiceKinds.DEFS[String(it.kind)].price), "Appraise")

func test_grove_raises_faces_on_a_new_biome() -> void:
	run = _run("druid", {"weapon": ["druid_staff", "staff_living", 3]})
	var before := 0
	for d in run.dice:
		before += d.face_sum()
	run.hp = 5
	var ev := ItemLogic.on_biome(run)
	assert_eq(_all(ev, "item_triggered", "grove").size(), int(ItemDefs.num("druid_staff", "dice", 3)))
	assert_eq(_all(ev, "item_triggered", "bloom").size(), int(ItemDefs.num("druid_staff", "dice", 3)), "Living Staff heals")
	var after := 0
	for d in run.dice:
		after += d.face_sum()
	assert_eq(after - before, int(ItemDefs.num("druid_staff", "dice", 3)))

# ================================================================ whole runs

func test_max_runs_replay_exactly_with_items() -> void:
	for cid in ["knight", "paladin", "ranger", "ninja", "necromancer", "monster_kid"]:
		var opts := {"profile": MetaPresets.get_preset("max")}
		var f := GameFlow.new_run(cid, 21, Balance.BOARD_SIZE, opts)
		var n := 0
		var fired := 0
		while not f.is_over() and n < 3000:
			var ev := f.apply(Bot.next_command(f))
			fired += _all(ev, "item_triggered").size()
			for e in ev:
				assert_true(String(e.type) != "error", "%s: %s" % [cid, str(e.get("msg", ""))])
			n += 1
		assert_true(fired > 0, "%s: items fired" % cid)
		var g := GameFlow.replay(cid, 21, f.commands, Balance.BOARD_SIZE, opts)
		assert_eq(g.run.hp, f.run.hp, cid + " replay hp")
		assert_eq(g.run.gold, f.run.gold, cid + " replay gold")
		assert_eq(g.phase, f.phase, cid + " replay phase")

func test_game_over_stats_carry_the_loadout() -> void:
	var f := GameFlow.new_run("knight", 5, Balance.BOARD_SIZE, {"profile": MetaPresets.get_preset("mid")})
	f.run.stats.fights_won = 7
	var ev: Array[Dictionary] = []
	f._finish(false, ev)
	var st: Dictionary = ev.back().stats
	assert_eq(String(st.loadout.weapon.id), "sword")
	assert_eq(int(st.item_fights), 7)

func test_presentation_views() -> void:
	var f := GameFlow.new_run("necromancer", 5, Balance.BOARD_SIZE, {"profile": MetaPresets.get_preset("max")})
	var li := f.loadout_info()
	assert_eq(String(li.items.weapon.variant), "staff_bone")
	assert_eq(String(li.style), "magic")
	assert_true(String(li.items.weapon.text).contains("uned dice"), "rule text with numbers")
	assert_eq(String(li.back), "hooded_cape")
	assert_eq(GameFlow.new_run("knight", 5).loadout_info().items, {}, "legacy run")
	var p := Profile.fresh()
	var camp := Camp.new(p)
	var chips := camp.variant_chips("sword")
	assert_eq(chips.size(), ItemDefs.variants_of("sword").size())
	assert_eq(String(chips[0].state), "owned", "the Standard")
	assert_eq(String(chips[1].state), "locked")
	assert_eq(chips[1].mastery, [0, 15])
	p.add_blueprint("sword", "sword_training")
	assert_eq(String(camp.variant_chips("sword")[1].state), "craftable")
	assert_eq(int(camp.variant_chips("sword")[1].cost.crowns), ItemDefs.CRAFT_COSTS[0])

func test_compass_reroll_starts_with_the_second_biome() -> void:
	var p := Profile.from_dict(MetaPresets.get_preset("max"))
	Camp.new(p).equip_item("knight", "trinket", "compass")
	var f := GameFlow.new_run("knight", 9, Balance.BOARD_SIZE, {"profile": p.to_dict()})
	assert_eq(int(f.run.meta.lap_rerolls), 1)
	assert_eq(f.run.lap_rerolls, 0, "none in the first biome")
	assert_eq(f.run.lap_reroll_refill(true), 1, "a new biome refills it")

func test_old_saves_keep_their_traits_as_items() -> void:
	var m := MetaRun.normalize({"asc": 0, "traits": ["blade_pair", "helm_last_stand", "boots_pair_pick", "charm_cheap_restock"]})
	assert_eq(String(m.items.weapon.id), "sword")
	assert_eq(String(m.items.offhand.id), "round_shield")
	assert_eq(String(m.items.trinket.id), "traders_map")
	assert_eq(MetaRun.normalize({"asc": 0}).items, {}, "no traits, no items")

func test_bot_meta_loadouts() -> void:
	var p := Profile.from_dict(MetaPresets.get_preset("max"))
	var camp := Camp.new(p)
	for cmd in BotMeta.equip_cmds(p, "knight"):
		assert_eq(String(camp.apply(cmd)[0].type), "item_equipped", str(cmd))
	var lo := p.loadout_for("knight")
	assert_eq(String(lo.trinket), String(BotMeta.TRINKET_PREF[0]), "the campaign bot's favourite trinket")
	assert_true(String(lo.trinket2) != "" and String(lo.trinket2) != String(lo.trinket), "the pouch gets the next one")
	var best := BotMeta.best_loadout(p, "mage")
	assert_true(String(best.weapon.id) != "", "a weapon")
	var fresh := Profile.fresh()
	assert_eq(BotMeta.equip_cmds(fresh, "knight"), [], "the Tankard is already on")
