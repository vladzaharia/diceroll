class_name Profile
extends RefCounted
## Persistent meta state (§16 + design review + user decisions). Pure data; the presentation
## layer owns the file (user://profile.json) and uses to_dict()/from_dict() (or to_json /
## from_json). Mutations go through Camp (command -> events), except apply_run_result().
##
## Schema (version 2; version-1 files load through the tolerant loader, see from_dict):
##   crowns:int, sigils:int
##   flags: {lock_classes: bool (default true: a fresh profile has the Knight only)}
##   unlocks: {classes, biomes, bosses, minibosses, pets, minigames, packs, gear, potions,
##             features}: owned ids, in content order (UnlockDefs.all_ids)
##   disabled: {runes, kinds, passives}: pool-toggled-off ids (<= 25% of each pool)
##   gear: {slot: level 0..8} for unlocked pieces; gear_traits: {slot: {"4": id, "8": id}}
##   upgrades: {whetstone, starter_kit, potion_belt, loadout_slot: 0|1}; starter_kind: String
##   pet_xp: {pet: fights won while equipped}; pet_bought: {pet: bought level 6..10}
##   minigame_plays: {minigame: plays} (mastery)
##   loadout: {class, mode: "standard"|"short", minigames: [ids], pet: id | ""}
##   ascension: {unlocked: 0..10, selected}
##   milestones: [ids reached]
##   records: {runs, wins, best_lap, loss_streak, crowns_earned, sigils_earned,
##             best_ascension_win, wins_by_class:{}, runs_by_class:{}, counters:{...},
##             firsts:{biome, miniboss, boss, class_win, route_win, asc_clear, short_win: [ids]},
##             best_asc_by_class:{class: highest ascension won (-1 none)},
##             bosses_by_class:{class: [final boss ids beaten]}, bosses_reached_by_class:{class: runs},
##             boss_kills:{boss id: n}, seen:{enemies: [ids], affixes: [ids]}}
##   cosmetics (v2): {owned: {class: [skin ids]} ("default" implicit), equipped: {class: skin},
##             prestige: {class: bool} (A10 overlay toggle), unseen: ["class:skin"] (Wardrobe dots)}

const VERSION := 2

const COUNTERS := ["runs", "laps", "fights", "minigames", "rerolls", "kept", "poison_kills", "cashouts", "block",
	"straights", "minibosses_reached", "minibosses_killed", "bosses_reached", "wins", "act2_runs", "act3_runs",
	"frost_visits", "throne_wins", "mage_wins", "full_runes", "face_edits", "kills", "hollow_events"]

var crowns: int = 0
var sigils: int = 0
var flags: Dictionary = {}
var unlocks: Dictionary = {}
var disabled: Dictionary = {}
var gear: Dictionary = {}
var gear_traits: Dictionary = {}
var upgrades: Dictionary = {}
var starter_kind: String = ""
var pet_xp: Dictionary = {}
var pet_bought: Dictionary = {}
var minigame_plays: Dictionary = {}
var loadout: Dictionary = {}
var ascension: Dictionary = {}
var milestones: Array = []
var records: Dictionary = {}
var cosmetics: Dictionary = {}

static func fresh(lock_classes := true) -> Profile:
	var p := Profile.new()
	p.flags = {"lock_classes": lock_classes}
	p.unlocks = {}
	for k in UnlockDefs.KINDS:
		p.unlocks[k] = (UnlockDefs.STARTER.get(k, []) as Array).duplicate()
	if not lock_classes:
		p.unlocks.classes = HeroDefs.IDS.duplicate()
	p.disabled = {"runes": [], "kinds": [], "passives": []}
	p.gear = {}
	p.gear_traits = {}
	p.upgrades = {}
	p.loadout = {"class": "knight", "mode": "standard", "minigames": (UnlockDefs.STARTER.minigames as Array).duplicate(), "pet": ""}
	p.ascension = {"unlocked": 0, "selected": 0}
	p.milestones = []
	var counters := {}
	for c in COUNTERS:
		counters[c] = 0
	var firsts := {}
	for k in Economy.SIGIL_FIRST:
		firsts[k] = []
	p.records = {"runs": 0, "wins": 0, "best_lap": 0, "loss_streak": 0, "crowns_earned": 0, "sigils_earned": 0,
		"best_ascension_win": -1, "wins_by_class": {}, "runs_by_class": {}, "counters": counters, "firsts": firsts,
		"best_asc_by_class": {}, "bosses_by_class": {}, "bosses_reached_by_class": {}, "boss_kills": {},
		"seen": {"enemies": [], "affixes": []}}
	p.cosmetics = {"owned": {}, "equipped": {}, "prestige": {}, "unseen": []}
	return p

# ------------------------------------------------------------------ queries

func owns(kind: String, id: String) -> bool:
	return (unlocks.get(kind, []) as Array).has(id)

func class_allowed(id: String) -> bool:
	return not bool(flags.get("lock_classes", true)) or owns("classes", id)

## Unlocked drop pool ("runes" | "kinds" | "passives") from owned packs, minus toggled-off ids.
func pool(kind: String) -> Array:
	var out: Array = []
	var off: Array = disabled.get(kind, [])
	for id in UnlockDefs.pool_from_packs(unlocks.get("packs", []), kind):
		if not off.has(id):
			out.append(id)
	return out

func pet_level(id: String) -> int:
	if not owns("pets", id):
		return 0
	return maxi(PetDefs.xp_level(int(pet_xp.get(id, 0))), int(pet_bought.get(id, 0)))

func mastery(id: String) -> int:
	return MinigameDefs.mastery_level(int(minigame_plays.get(id, 0)))

func loadout_slots() -> int:
	return 2 + int(upgrades.get("loadout_slot", 0))

func potion_cap() -> int:
	return mini(Balance.POTION_MAX_CAP, Balance.POTION_CAP + int(upgrades.get("potion_belt", 0)))

func gear_level(slot: String) -> int:
	return int(gear.get(slot, 0))

## Active gear traits (the chosen option per unlocked tier).
func active_traits() -> Array:
	var out: Array = []
	for slot in GearDefs.SLOTS:
		var lvl := gear_level(slot)
		var t: Dictionary = gear_traits.get(slot, {})
		for tier in ["4", "8"]:
			if lvl >= int(tier):
				var opts := GearDefs.trait_options(slot, tier)
				var pick := String(t.get(tier, opts[0]))
				out.append(pick if opts.has(pick) else String(opts[0]))
	return out

func counter(stat: String) -> int:
	match stat:
		"best_lap":
			return int(records.get("best_lap", 0))
		"classes_at_boss":
			var n := 0
			var r: Dictionary = records.get("bosses_reached_by_class", {})
			for k in r:
				if int(r[k]) > 0:
					n += 1
			return n
		"classes_owned":
			return (unlocks.get("classes", []) as Array).size()
	return int((records.get("counters", {}) as Dictionary).get(stat, 0))

## True once every Crowns sink is maxed: owned gear at L8, every Crowns upgrade bought and every
## owned pet at L10 (skins can then be bought for SkinDefs.BUY_PRICE Crowns).
func crowns_capped() -> bool:
	for slot in GearDefs.SLOTS:
		if gear_level(slot) < GearDefs.MAX_LEVEL:
			return false
	for track in UnlockDefs.UPGRADES:
		for id in UnlockDefs.UPGRADES[track]:
			if int(upgrades.get(id, 0)) < 1:
				return false
	for id in unlocks.get("pets", []):
		if pet_level(String(id)) < PetDefs.MAX_LEVEL:
			return false
	return true

func owns_skin(class_id: String, skin: String) -> bool:
	if skin == "default":
		return owns("classes", class_id) or not bool(flags.get("lock_classes", true))
	return ((cosmetics.get("owned", {}) as Dictionary).get(class_id, []) as Array).has(skin)

func equipped_skin(class_id: String) -> String:
	var s := String((cosmetics.get("equipped", {}) as Dictionary).get(class_id, "default"))
	return s if owns_skin(class_id, s) and not SkinDefs.is_prestige(s) else "default"

func prestige_on(class_id: String) -> bool:
	return owns_skin(class_id, "prestige") and bool((cosmetics.get("prestige", {}) as Dictionary).get(class_id, true))

## Grants a skin (no cost). Returns false if already owned or unknown.
func grant_skin(class_id: String, skin: String) -> bool:
	if not SkinDefs.has(class_id, skin) or skin == "default" or owns_skin(class_id, skin):
		return false
	var owned: Dictionary = cosmetics.get("owned", {})
	var have: Array = owned.get(class_id, [])
	have.append(skin)
	owned[class_id] = have
	cosmetics["owned"] = owned
	var un: Array = cosmetics.get("unseen", [])
	un.append("%s:%s" % [class_id, skin])
	cosmetics["unseen"] = un
	return true

## True when the records meet a skin's condition (SkinDefs.CONDS).
func skin_earned(class_id: String, skin: String) -> bool:
	var cond: Dictionary = SkinDefs.CONDS.get(skin, {})
	var best := int((records.get("best_asc_by_class", {}) as Dictionary).get(class_id, -1))
	var wins := int((records.get("wins_by_class", {}) as Dictionary).get(class_id, 0))
	if cond.has("class_win") and wins < int(cond.class_win):
		return false
	if cond.has("class_bosses"):
		var beaten: Array = (records.get("bosses_by_class", {}) as Dictionary).get(class_id, [])
		return beaten.size() >= int(cond.class_bosses) or best >= int(cond.get("or_class_asc", 99))
	if cond.has("class_asc") and best < int(cond.class_asc):
		return false
	return not cond.is_empty() or skin == "default"

## Skins newly earned by the records: grants them and returns [[class, skin]].
func check_skins() -> Array:
	var out: Array = []
	for cid in HeroDefs.IDS:
		for skin in SkinDefs.SLOTS:
			if skin != "default" and not owns_skin(cid, skin) and skin_earned(cid, skin):
				grant_skin(cid, skin)
				out.append([cid, skin])
	return out

func can_afford(cost: Dictionary) -> bool:
	if cost.is_empty():
		return false
	return crowns >= int(cost.get("crowns", 0)) and sigils >= int(cost.get("sigils", 0))

## Adds an unlock (no cost). Returns false if already owned or unknown.
func grant(kind: String, id: String) -> bool:
	if owns(kind, id) or not UnlockDefs.all_ids(kind).has(id):
		return false
	var owned: Array = []
	for x in UnlockDefs.all_ids(kind):
		if x == id or owns(kind, String(x)):
			owned.append(x)
	unlocks[kind] = owned
	if kind == "gear" and not gear.has(id):
		gear[id] = 0
	return true

# ------------------------------------------------------------------ run results

## Banks a finished run (the game_over event's stats): Crowns, pet XP, minigame mastery,
## records and counters, first-time Sigils, milestone unlocks, skins and the ascension ladder.
## At most one class unlocks from milestones per run: a second class milestone waits for the
## next banked run. Returns {crowns, sigils, firsts:[[kind, id]], milestones:[ids],
## unlocked:[[kind, id]], ascension_unlocked:int (-1 = none), skins_unlocked:[[class, skin]]}.
func apply_run_result(stats: Dictionary) -> Dictionary:
	var r: Dictionary = stats.get("rewards", {})
	var victory := bool(stats.get("victory", false))
	var cls := String(stats.get("class_id", ""))
	var c := int(r.get("crowns", 0))
	crowns += c
	records.crowns_earned = int(records.get("crowns_earned", 0)) + c
	# pet XP and minigame mastery
	var pet := String(stats.get("pet", ""))
	if pet != "" and owns("pets", pet):
		pet_xp[pet] = int(pet_xp.get(pet, 0)) + int(stats.get("pet_fights", 0))
	var mp: Dictionary = stats.get("minigame_plays", {})
	for id in mp:
		minigame_plays[String(id)] = int(minigame_plays.get(id, 0)) + int(mp[id])
	# records
	records.runs = int(records.get("runs", 0)) + 1
	var rbc: Dictionary = records.get("runs_by_class", {})
	rbc[cls] = int(rbc.get(cls, 0)) + 1
	records.runs_by_class = rbc
	records.best_lap = maxi(int(records.get("best_lap", 0)), int(stats.get("lap", 0)))
	var asc := int(stats.get("asc", 0))
	var unlocked_asc := -1
	if victory:
		records.wins = int(records.get("wins", 0)) + 1
		records.loss_streak = 0
		var wbc: Dictionary = records.get("wins_by_class", {})
		wbc[cls] = int(wbc.get(cls, 0)) + 1
		records.wins_by_class = wbc
		records.best_ascension_win = maxi(int(records.get("best_ascension_win", -1)), asc)
		var bac: Dictionary = records.get("best_asc_by_class", {})
		bac[cls] = maxi(int(bac.get(cls, -1)), asc)
		records.best_asc_by_class = bac
		if asc >= int(ascension.get("unlocked", 0)) and asc < UnlockDefs.MAX_ASCENSION:
			ascension.unlocked = asc + 1
			unlocked_asc = asc + 1
	else:
		records.loss_streak = int(records.get("loss_streak", 0)) + 1
	_count(stats, victory)
	_class_records(stats, cls)
	# first-time Sigils
	var firsts: Array = []
	var s := 0
	var route: Array = stats.get("route", [])
	for b in stats.get("biomes_visited", []):
		s += _first("biome", String(b), firsts)
	for m in stats.get("minibosses_killed", []):
		s += _first("miniboss", String(m), firsts)
	for b in stats.get("bosses_killed", []):
		s += _first("boss", String(b), firsts)
	if victory:
		s += _first("class_win", cls, firsts)
		if String(stats.get("mode", "standard")) == "short":
			s += _first("short_win", "short", firsts)
		else:
			s += _first("route_win", ",".join(route), firsts)
		if asc > 0:
			s += _first("asc_clear", str(asc), firsts)
	sigils += s
	records.sigils_earned = int(records.get("sigils_earned", 0)) + s
	# milestones
	var hit: Array = []
	var unlocked: Array = []
	var class_given := false
	for m in UnlockDefs.MILESTONES:
		if milestones.has(m.id) or not _cond(m.cond):
			continue
		var gives_class := false
		for u in m.unlocks:
			if String(u[0]) == "classes" and not owns("classes", String(u[1])) and UnlockDefs.all_ids("classes").has(String(u[1])):
				gives_class = true
		if gives_class and class_given:
			continue # one class per run: this milestone fires on a later banked run
		class_given = class_given or gives_class
		milestones.append(m.id)
		hit.append(m.id)
		for u in m.unlocks:
			if grant(String(u[0]), String(u[1])):
				unlocked.append([String(u[0]), String(u[1])])
	var skins := check_skins()
	return {"crowns": c, "sigils": s, "firsts": firsts, "milestones": hit, "unlocked": unlocked, "ascension_unlocked": unlocked_asc,
		"skins_unlocked": skins}

## Per-class and per-boss records (skins, class milestones, Bestiary).
func _class_records(st: Dictionary, cls: String) -> void:
	if bool(st.get("boss_reached", false)):
		var r: Dictionary = records.get("bosses_reached_by_class", {})
		r[cls] = int(r.get(cls, 0)) + 1
		records.bosses_reached_by_class = r
	var bk: Dictionary = records.get("boss_kills", {})
	var bbc: Dictionary = records.get("bosses_by_class", {})
	var mine: Array = bbc.get(cls, [])
	for b in st.get("bosses_killed", []):
		bk[String(b)] = int(bk.get(String(b), 0)) + 1
		if not mine.has(String(b)):
			mine.append(String(b))
	bbc[cls] = mine
	records.boss_kills = bk
	records.bosses_by_class = bbc
	var seen: Dictionary = records.get("seen", {"enemies": [], "affixes": []})
	for k in [["seen_enemies", "enemies"], ["seen_affixes", "affixes"]]:
		var have: Array = seen.get(k[1], [])
		for id in st.get(k[0], []):
			if not have.has(String(id)):
				have.append(String(id))
		seen[k[1]] = have
	records.seen = seen

func _first(kind: String, id: String, out: Array) -> int:
	var f: Dictionary = records.get("firsts", {})
	var have: Array = f.get(kind, [])
	if have.has(id):
		return 0
	have.append(id)
	f[kind] = have
	records.firsts = f
	out.append([kind, id])
	return int(Economy.SIGIL_FIRST.get(kind, 0))

func _count(st: Dictionary, victory: bool) -> void:
	var c: Dictionary = records.get("counters", {})
	var add := func(k: String, v: int) -> void:
		c[k] = int(c.get(k, 0)) + v
	add.call("runs", 1)
	add.call("laps", int(st.get("laps_completed", 0)))
	add.call("fights", int(st.get("fights_won", 0)))
	add.call("minigames", int(st.get("minigames_played", 0)))
	add.call("rerolls", int(st.get("rerolls_used", 0)))
	add.call("kept", int(st.get("kept_dice", 0)))
	add.call("poison_kills", int(st.get("poison_kills", 0)))
	add.call("cashouts", int(st.get("cashouts", 0)))
	add.call("block", int(st.get("block_gained", 0)))
	add.call("straights", int(st.get("straights", 0)))
	add.call("full_runes", 1 if int(st.get("full_rune_fights", 0)) > 0 else 0)
	add.call("minibosses_reached", 1 if bool(st.get("miniboss_reached", false)) else 0)
	add.call("minibosses_killed", (st.get("minibosses_killed", []) as Array).size())
	add.call("bosses_reached", 1 if bool(st.get("boss_reached", false)) else 0)
	add.call("wins", 1 if victory else 0)
	add.call("act2_runs", 1 if int(st.get("max_act", 1)) >= 2 else 0)
	add.call("act3_runs", 1 if int(st.get("max_act", 1)) >= 3 else 0)
	add.call("frost_visits", 1 if (st.get("biomes_visited", []) as Array).has("frost") else 0)
	var route: Array = st.get("route", [])
	add.call("throne_wins", 1 if victory and route.has("throne") else 0)
	add.call("mage_wins", 1 if victory and String(st.get("class_id", "")) == "mage" else 0)
	add.call("face_edits", int(st.get("face_edits", 0)))
	add.call("kills", int(st.get("kills", 0)))
	add.call("hollow_events", int(st.get("hollow_events", 0)))
	records.counters = c

## Milestone conditions: {stat, min} (counter), {class_wins: id, min}, {boss_kills: id, min},
## {any: [conds]}, {all: [conds]}.
func _cond(cond: Dictionary) -> bool:
	if cond.has("any"):
		for sub in cond.any:
			if _cond(sub):
				return true
		return false
	if cond.has("all"):
		for sub in cond.all:
			if not _cond(sub):
				return false
		return true
	if cond.has("class_wins"):
		return int((records.get("wins_by_class", {}) as Dictionary).get(String(cond.class_wins), 0)) >= int(cond.min)
	if cond.has("boss_kills"):
		return int((records.get("boss_kills", {}) as Dictionary).get(String(cond.boss_kills), 0)) >= int(cond.min)
	return counter(String(cond.stat)) >= int(cond.min)

# ------------------------------------------------------------------ serialisation

func to_dict() -> Dictionary:
	return {
		"version": VERSION, "crowns": crowns, "sigils": sigils, "flags": flags.duplicate(true),
		"unlocks": unlocks.duplicate(true), "disabled": disabled.duplicate(true), "gear": gear.duplicate(true),
		"gear_traits": gear_traits.duplicate(true), "upgrades": upgrades.duplicate(true), "starter_kind": starter_kind,
		"pet_xp": pet_xp.duplicate(true), "pet_bought": pet_bought.duplicate(true),
		"minigame_plays": minigame_plays.duplicate(true), "loadout": loadout.duplicate(true),
		"ascension": ascension.duplicate(true), "milestones": milestones.duplicate(), "records": records.duplicate(true),
		"cosmetics": cosmetics.duplicate(true),
	}

## Tolerant loader: missing fields take fresh defaults, unknown ids are dropped, JSON floats
## become ints. Version 1 -> 2: the new records start empty (best_asc_by_class is seeded from
## wins_by_class at A0 and best_ascension_win for the wins' classes is unknown, so it stays
## conservative), cosmetics start empty, and skins already earned by the old records are granted.
static func from_dict(d: Dictionary) -> Profile:
	var fl: Dictionary = d.get("flags", {})
	var p := Profile.fresh(bool(fl.get("lock_classes", true)))
	if d.is_empty():
		return p
	for k in fl:
		p.flags[String(k)] = fl[k]
	p.crowns = int(d.get("crowns", 0))
	p.sigils = int(d.get("sigils", 0))
	var un: Dictionary = d.get("unlocks", {})
	for kind in UnlockDefs.KINDS:
		for id in un.get(kind, []):
			p.grant(kind, String(id))
	var dis: Dictionary = d.get("disabled", {})
	for kind in ["runes", "kinds", "passives"]:
		var a: Array = []
		for id in dis.get(kind, []):
			if UnlockDefs.all_ids(kind).has(String(id)):
				a.append(String(id))
		p.disabled[kind] = a
	var g: Dictionary = d.get("gear", {})
	for s in GearDefs.SLOTS:
		if p.owns("gear", s):
			p.gear[s] = clampi(int(g.get(s, 0)), 0, GearDefs.MAX_LEVEL)
	var gt: Dictionary = d.get("gear_traits", {})
	for s in gt:
		if GearDefs.DEFS.has(String(s)):
			var t := {}
			for tier in gt[s]:
				t[String(tier)] = String(gt[s][tier])
			p.gear_traits[String(s)] = t
	p.upgrades = _int_map(d.get("upgrades", {}))
	p.starter_kind = String(d.get("starter_kind", ""))
	p.pet_xp = _int_map(d.get("pet_xp", {}))
	p.pet_bought = _int_map(d.get("pet_bought", {}))
	p.minigame_plays = _int_map(d.get("minigame_plays", {}))
	var lo: Dictionary = d.get("loadout", {})
	var mg: Array = []
	for id in lo.get("minigames", p.loadout.minigames):
		if p.owns("minigames", String(id)) and not mg.has(String(id)) and mg.size() < p.loadout_slots():
			mg.append(String(id))
	var pet := String(lo.get("pet", ""))
	p.loadout = {"class": String(lo.get("class", "knight")), "mode": String(lo.get("mode", "standard")),
		"minigames": mg, "pet": pet if p.owns("pets", pet) else ""}
	var asc: Dictionary = d.get("ascension", {})
	var unl := clampi(int(asc.get("unlocked", 0)), 0, UnlockDefs.MAX_ASCENSION)
	p.ascension = {"unlocked": unl, "selected": clampi(int(asc.get("selected", 0)), 0, unl)}
	for m in d.get("milestones", []):
		if not UnlockDefs.milestone(String(m)).is_empty() and not p.milestones.has(String(m)):
			p.milestones.append(String(m))
	var rec: Dictionary = d.get("records", {})
	for k in rec:
		var v: Variant = rec[k]
		if k in ["bosses_by_class", "seen"]:
			var lists := {}
			for lk in v:
				var a2: Array = []
				for x in v[lk]:
					a2.append(String(x))
				lists[String(lk)] = a2
			if k == "seen":
				for lk in ["enemies", "affixes"]:
					if not lists.has(lk):
						lists[lk] = []
			p.records[k] = lists
		elif k == "firsts":
			var f := {}
			for fk in v:
				var a: Array = []
				for x in v[fk]:
					a.append(String(x))
				f[String(fk)] = a
			for fk in p.records.firsts:
				if not f.has(fk):
					f[fk] = []
			p.records.firsts = f
		elif v is Dictionary:
			var m := _int_map(v)
			if k == "counters":
				for ck in p.records.counters:
					if not m.has(ck):
						m[ck] = 0
			p.records[k] = m
		elif v is float:
			p.records[k] = int(v)
		else:
			p.records[k] = v
	if int(d.get("version", 1)) < 2:
		# v1: a class win means at least an A0 win with it
		var bac: Dictionary = p.records.get("best_asc_by_class", {})
		for cid in (p.records.get("wins_by_class", {}) as Dictionary):
			if int(p.records.wins_by_class[cid]) > 0:
				bac[cid] = maxi(int(bac.get(cid, -1)), 0)
		p.records.best_asc_by_class = bac
	var cz: Dictionary = d.get("cosmetics", {})
	var owned := {}
	var co: Dictionary = cz.get("owned", {})
	for cid in co:
		var lst: Array = []
		for sk in co[cid]:
			if SkinDefs.has(String(cid), String(sk)) and String(sk) != "default" and not lst.has(String(sk)):
				lst.append(String(sk))
		owned[String(cid)] = lst
	var eq := {}
	var ce: Dictionary = cz.get("equipped", {})
	for cid in ce:
		if SkinDefs.has(String(cid), String(ce[cid])):
			eq[String(cid)] = String(ce[cid])
	var pr := {}
	var cp: Dictionary = cz.get("prestige", {})
	for cid in cp:
		pr[String(cid)] = bool(cp[cid])
	var unseen: Array = []
	for x in cz.get("unseen", []):
		unseen.append(String(x))
	p.cosmetics = {"owned": owned, "equipped": eq, "prestige": pr, "unseen": unseen}
	p.check_skins()
	return p

static func _int_map(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in v:
			out[String(k)] = int(v[k])
	return out

## Static helpers for the presentation layer's file IO (JSON text <-> Profile).
static func to_json(p: Profile) -> String:
	return JSON.stringify(p.to_dict(), "\t")

static func from_json(text: String) -> Profile:
	var v: Variant = JSON.parse_string(text)
	return Profile.from_dict(v if v is Dictionary else {})
