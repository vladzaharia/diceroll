class_name MetaRun
extends RefCounted
## Bridges the Profile and a run. build() turns a profile snapshot (Profile.to_dict()) into the
## run config stored in RunState.meta; it is serialised with the run, so save, load and replay
## are exact without the profile. rewards() computes the run-end Crowns.
##
## RunState.meta ({} = legacy run, no meta layer):
##   asc:int, asc_keys:[UnlockDefs.ASCENSION keys], catchup:float,
##   hp:int, atk:int, lap_rerolls:int, hazard_mult:float, gold_pct:float, traits:[] (legacy),
##   items:{slot: {id, variant, tier}} (Armory items with tier >= 1; ItemLogic), back:id,
##   appearance:{head, body}, ranks:{weapon, offhand, armor, trinket},
##   look: the full equipped loadout (Profile.loadout_for, inactive items too; presentation only),
##   potion_cap:int, potions:int (start), potion_types:[ids unlocked for shops],
##   whetstone:int, starter_kind:String, pet:{id, level} | {},
##   minigames:[loadout ids], mastery:{id: level},
##   pools:{runes, kinds, passives}, biomes:[ids], bosses:[ids], minibosses:[ids]

static func build(profile_dict: Dictionary, class_id := "") -> Dictionary:
	var p := Profile.from_dict(profile_dict)
	var cid := class_id if class_id != "" else String(p.loadout.get("class", "knight"))
	var items := p.resolve_items(cid)
	var g := armory_stats(p.armory.get("ranks", {}), items)
	var asc := int(p.ascension.get("selected", 0))
	var keys := UnlockDefs.ascension_keys(asc)
	var pet := {}
	var pid := String(p.loadout.get("pet", ""))
	if pid != "" and p.owns("pets", pid):
		pet = {"id": pid, "level": p.pet_level(pid)}
	var mg: Array = []
	var mastery := {}
	for id in p.loadout.get("minigames", []):
		if p.owns("minigames", String(id)) and mg.size() < mini(p.loadout_slots(), Balance.MINIGAME_TILES_MAX):
			mg.append(String(id))
			mastery[String(id)] = p.mastery(String(id))
	var cap := p.potion_cap()
	var potions := 0 if keys.has("potions") else Balance.POTION_START
	return {
		"asc": asc, "asc_keys": keys,
		"catchup": Economy.catchup(int(p.records.get("loss_streak", 0))),
		"hp": int(g.max_hp), "atk": int(g.atk), "lap_rerolls": int(g.lap_rerolls),
		"hazard_mult": float(g.hazard_mult), "gold_pct": float(g.gold_pct), "traits": [],
		"items": items, "back": String(p.loadout_for(cid).back), "appearance": p.appearance_of(cid),
		"look": p.loadout_for(cid),
		"ranks": (p.armory.get("ranks", {}) as Dictionary).duplicate(),
		"potion_cap": cap, "potions": mini(potions, cap), "potion_types": Array(p.unlocks.potions),
		"whetstone": int(p.upgrades.get("whetstone", 0)),
		"starter_kind": p.starter_kind if int(p.upgrades.get("starter_kit", 0)) >= 1 else "",
		"pet": pet, "minigames": mg, "mastery": mastery,
		"pools": {"runes": p.pool("runes"), "kinds": p.pool("kinds"), "passives": p.pool("passives")},
		"biomes": Array(p.unlocks.biomes), "bosses": Array(p.unlocks.bosses), "minibosses": Array(p.unlocks.minibosses),
		"affixes": p.owns("features", "affixes"),
		"skin": p.equipped_skin(class_id) if class_id != "" else "default",
		"prestige": p.prestige_on(class_id) if class_id != "" else false,
	}

## Run stats from the Armory: base stats (ATK at Weapon R8, HP per Armor rank), item max HP
## (Steel Greatsword, Golem Axe, Bone Bulwark), the Compass's board reroll (Trinket R6+, slot 1),
## the Lantern's hazard cut and the Coin Purse's gold. {max_hp, atk, lap_rerolls, hazard_mult, gold_pct}.
static func armory_stats(ranks: Dictionary, items: Dictionary) -> Dictionary:
	var b := ItemDefs.base_stats(ranks)
	var hp := int(b.max_hp)
	for slot in items:
		var v := String(items[slot].get("variant", ""))
		hp += int(ItemDefs.sec_num(v, "max_hp"))
	var t1: Dictionary = items.get("trinket", {})
	var reroll := 1 if String(t1.get("id", "")) == "compass" and int(ranks.get("trinket", 0)) >= ItemDefs.COMPASS_REROLL_RANK else 0
	var haz := 1.0
	var gold := 0.0
	for slot in ["trinket", "trinket2"]:
		var e: Dictionary = items.get(slot, {})
		if String(e.get("id", "")) == "lantern":
			haz = 1.0 - ItemDefs.num("lantern", "pct", int(e.tier))
		if String(e.get("id", "")) == "coin_purse":
			gold = ItemDefs.num("coin_purse", "gold", int(e.tier))
	return {"max_hp": hp, "atk": int(b.atk), "lap_rerolls": reroll, "hazard_mult": haz, "gold_pct": gold}

## Normalises a meta config loaded from JSON (ints stay ints, arrays hold Strings).
static func normalize(m: Dictionary) -> Dictionary:
	if m.is_empty():
		return {}
	var out := m.duplicate(true)
	for k in ["asc", "hp", "atk", "lap_rerolls", "potion_cap", "potions", "whetstone"]:
		out[k] = int(out.get(k, 0))
	for k in ["catchup", "gold_pct"]:
		out[k] = float(out.get(k, 0.0))
	out.hazard_mult = float(out.get("hazard_mult", 1.0))
	out.affixes = bool(out.get("affixes", false))
	out.skin = String(out.get("skin", "default"))
	out.prestige = bool(out.get("prestige", false))
	out.starter_kind = String(out.get("starter_kind", ""))
	var its := {}
	var src_items: Dictionary = out.get("items", {})
	for slot in src_items:
		var e: Dictionary = src_items[slot]
		its[String(slot)] = {"id": String(e.id), "variant": String(e.get("variant", e.id)), "tier": int(e.tier)}
	if its.is_empty() and not (out.get("traits", []) as Array).is_empty():
		its = _legacy_items(out.traits)
	out.items = its
	out.back = String(out.get("back", ""))
	var ap: Dictionary = out.get("appearance", {})
	out.appearance = {"head": String(ap.get("head", "own")), "body": String(ap.get("body", "own"))}
	var lk := {}
	var src_look: Dictionary = out.get("look", {})
	for slot in src_look:
		var le: Variant = src_look[slot]
		lk[String(slot)] = {"id": String(le.get("id", "")), "variant": String(le.get("variant", ""))} if le is Dictionary else String(le)
	out.look = lk
	var rk := {}
	var src_r: Dictionary = out.get("ranks", {})
	for k in src_r:
		rk[String(k)] = int(src_r[k])
	out.ranks = rk
	for k in ["asc_keys", "traits", "potion_types", "minigames", "biomes", "bosses", "minibosses"]:
		out[k] = _strings(out.get(k, []))
	var pet: Dictionary = out.get("pet", {})
	out.pet = {} if pet.is_empty() else {"id": String(pet.id), "level": int(pet.level)}
	var ms := {}
	var src: Dictionary = out.get("mastery", {})
	for id in src:
		ms[String(id)] = int(src[id])
	out.mastery = ms
	var pools := {}
	var ps: Dictionary = out.get("pools", {})
	for k in ["runes", "kinds", "passives"]:
		pools[k] = _strings(ps.get(k, []))
	out.pools = pools
	return out

## A pre-Armory save's gear traits as items (tier II Standard pieces), so a run saved before the
## update keeps roughly the same bonuses.
static func _legacy_items(traits: Array) -> Dictionary:
	var map := {"blade_pair": ["weapon", "sword"], "blade_high": ["weapon", "crossbow"], "blade_boss_opener": ["weapon", "spear"],
		"blade_overflow": ["weapon", "hand_axe"], "helm_bulwark": ["offhand", "round_shield"], "helm_last_stand": ["offhand", "round_shield"],
		"helm_lap_heal": ["trinket", "tankard"], "helm_campfire": ["trinket", "tankard"], "boots_portal": ["trinket2", "compass"],
		"boots_pair_pick": ["trinket2", "compass"], "charm_cheap_restock": ["trinket", "traders_map"]}
	var out := {}
	for t in traits:
		var m: Array = map.get(String(t), [])
		if not m.is_empty() and not out.has(m[0]):
			out[String(m[0])] = {"id": String(m[1]), "variant": String(m[1]), "tier": 2}
	return out

static func _strings(a: Variant) -> Array:
	var out: Array = []
	if a is Array:
		for x in a:
			out.append(String(x))
	return out

## Applies the start-of-run meta bonuses to a freshly created RunState (no Rng use).
static func apply_start(r: RunState) -> void:
	var m := r.meta
	if m.is_empty():
		return
	r.max_hp += int(m.hp)
	r.hp = r.max_hp
	r.atk += int(m.atk)
	r.potion_cap = int(m.potion_cap)
	r.belt.clear()
	for k in mini(int(m.potions), r.potion_cap):
		r.belt.append("healing")
	r.potions = r.belt.size()
	# the Compass's board reroll starts with the 2nd biome (the pets' per-lap perk starts at once)
	r.lap_rerolls = r.lap_reroll_refill(false)
	r.skin = String(m.get("skin", "default"))
	r.skin_prestige = bool(m.get("prestige", false))
	var sk := String(m.starter_kind)
	if sk != "" and r.dice.size() >= 2 and UnlockDefs.STARTER_KINDS.has(sk):
		var tags := r.dice[1].tags
		r.dice[1] = Die.make(r.dice[1].rune, sk)
		r.dice[1].tags = tags

# ------------------------------------------------------------------ Crowns

## Run-end Crowns (Economy constants): laps (3 each, cap 45), biomes reached beyond the first
## (8 each), the mini-boss kill (18), the win (45), minigames (3-6 by tier, plus bronze Crown
## picks), leftover gold (1 per 25, cap 8); then x(1 + 8% per ascension) x(1 + catch-up).
## Short Road runs count laps and biomes at their standard-run equivalent (x1.5 laps, the
## tier-3 biome counts as 2) and then pay SHORT_CROWN_MULT of that.
## Returns {crowns, breakdown: [[label, amount]]}. Legacy runs (no meta) pay nothing.
static func rewards(r: RunState, victory: bool) -> Dictionary:
	if r.meta.is_empty():
		return {"crowns": 0, "breakdown": []}
	var st := r.stats
	var laps := r.lap - 1 + (1 if victory else 0)
	var biomes := r.act - 1
	if r.mode == "short":
		laps = int(round(laps * float(Balance.TOTAL_LAPS) / Balance.SHORT_LAPS))
		biomes *= 2
	var parts: Array = []
	parts.append(["laps", mini(Economy.CROWNS_LAP_CAP, Economy.CROWNS_PER_LAP * laps)])
	parts.append(["biomes", Economy.CROWNS_PER_BIOME * biomes])
	parts.append(["mini-boss", Economy.CROWNS_MINIBOSS if int(st.get("minibosses_won", 0)) > 0 else 0])
	parts.append(["victory", Economy.CROWNS_WIN if victory else 0])
	parts.append(["minigames", int(st.get("minigame_crowns", 0))])
	parts.append(["gold", mini(Economy.GOLD_CROWN_CAP, r.gold / Economy.GOLD_PER_CROWN)])
	var base := 0
	for p in parts:
		base += int(p[1])
	var mult := (1.0 + Economy.ASC_CROWN_BONUS * int(r.meta.get("asc", 0))) * (1.0 + float(r.meta.get("catchup", 0.0)))
	if r.mode == "short":
		mult *= Economy.SHORT_CROWN_MULT
	var total := int(round(base * mult))
	parts.append(["bonus", total - base])
	return {"crowns": total, "breakdown": parts}
