class_name Profile
extends RefCounted
## Persistent meta state (§16 + design review + user decisions). Pure data; the presentation
## layer owns the file (user://profile.json) and uses to_dict()/from_dict() (or to_json /
## from_json). Mutations go through Camp (command -> events), except apply_run_result().
##
## Schema (version 3; version-1 and -2 files load through the tolerant loader, see from_dict):
##   crowns:int, sigils:int
##   flags: {lock_classes: bool (default true: a fresh profile has the Knight only)}
##   unlocks: {classes, biomes, bosses, minibosses, pets, minigames, packs, gear, potions,
##             features}: owned ids, in content order (UnlockDefs.all_ids). "gear" holds the
##             Armory rank groups the player may craft (weapon, offhand, armor, trinket).
##   disabled: {runes, kinds, passives}: pool-toggled-off ids (<= 25% of each pool)
##   armory (v3, docs/design/2026-09-29-armory-items.md §7.4):
##     ranks: {weapon, offhand, armor, trinket: 0..8}, pouch: 0|1 (the 2nd trinket slot),
##     owned: [item ids] (ItemDefs.IDS order), variants: {item: [crafted variant ids]} (the
##     Standard is implicit), blueprints: {item: [unlocked, not yet crafted]},
##     mastery: {item: fights won with it equipped}, feats: [ItemDefs.FEATS ids reached],
##     equipped: {class: {weapon: {id, variant}, offhand: {id, variant}, head: {id, variant},
##                body: id, trinket: id, trinket2: id, back: id}} ("" = empty; a missing class
##                uses its signature kit), appearance: {class: {head: id|"own"|"hidden", body: id|"own"}},
##     seen_new: [item / variant ids not yet seen in the Armory]
##   gear / gear_traits (v2) are gone; from_dict migrates them (and old unlocks.gear piece ids)
##   into the ranks ({helm: armor, blade: weapon, boots: offhand, charm: trinket}).
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

const VERSION := 3

const COUNTERS := ["runs", "laps", "fights", "minigames", "rerolls", "kept", "poison_kills", "cashouts", "block",
	"straights", "minibosses_reached", "minibosses_killed", "bosses_reached", "wins", "act2_runs", "act3_runs",
	"frost_visits", "throne_wins", "mage_wins", "full_runes", "face_edits", "kills", "hollow_events",
	"freezes", "sets3", "rune_triggers", "potions", "high_rollers", "skeleton_kills"]

var crowns: int = 0
var sigils: int = 0
var flags: Dictionary = {}
var unlocks: Dictionary = {}
var disabled: Dictionary = {}
var armory: Dictionary = {}
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
	p.armory = fresh_armory()
	for cid in p.unlocks.classes:
		p.grant_kit(String(cid))
	for id in ItemDefs.STARTER_ITEMS:
		p.grant_item(String(id))
	p.armory.seen_new = []
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
	if kind == "items":
		return owns_item(id)
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

func counter(stat: String) -> int:
	match stat:
		"best_lap":
			return int(records.get("best_lap", 0))
		"boss_kinds":
			# distinct final bosses defeated (the Sigil firsts list)
			return ((records.get("firsts", {}) as Dictionary).get("boss", []) as Array).size()
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

## True once every Crowns sink is maxed: the four Armory ranks at R8 and the Belt Pouch, every
## Crowns upgrade bought and every owned pet at L10 (skins can then be bought for
## SkinDefs.BUY_PRICE Crowns). Items and variants don't count (they are collections).
func crowns_capped() -> bool:
	for g in ItemDefs.GROUPS:
		if rank(String(g)) < ItemDefs.RANK_MAX:
			return false
	if int(armory.get("pouch", 0)) < 1:
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

## Adds an unlock (no cost). Returns false if already owned or unknown. "items" grants an
## Armory item; a class also brings its signature kit (§6).
func grant(kind: String, id: String) -> bool:
	if kind == "items":
		return grant_item(id)
	if owns(kind, id) or not UnlockDefs.all_ids(kind).has(id):
		return false
	var owned: Array = []
	for x in UnlockDefs.all_ids(kind):
		if x == id or owns(kind, String(x)):
			owned.append(x)
	unlocks[kind] = owned
	if kind == "classes":
		grant_kit(id)
	return true

# ------------------------------------------------------------------ run results

## Banks a finished run (the game_over event's stats): Crowns, pet XP, minigame mastery,
## records and counters, first-time Sigils, milestone unlocks, skins and the ascension ladder.
## At most one MAJOR unlock (a class, pet or biome: UnlockDefs.MAJOR_KINDS) comes from milestones
## per run: a second major milestone waits for the next banked run. Returns {crowns, sigils, firsts:[[kind, id]], milestones:[ids],
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
	var arm := _armory_result(stats, victory, cls)
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
	var major_given := false
	for m in UnlockDefs.MILESTONES:
		if milestones.has(m.id) or not _cond(m.cond):
			continue
		var gives_major := false
		for u in m.unlocks:
			var uk := String(u[0])
			if UnlockDefs.MAJOR_KINDS.has(uk) and not owns(uk, String(u[1])) and UnlockDefs.all_ids(uk).has(String(u[1])):
				gives_major = true
		if gives_major and major_given:
			continue # one major unlock per run: this milestone fires on a later banked run
		major_given = major_given or gives_major
		milestones.append(m.id)
		hit.append(m.id)
		for u in m.unlocks:
			if grant(String(u[0]), String(u[1])):
				unlocked.append([String(u[0]), String(u[1])])
	var skins := check_skins()
	return {"crowns": c, "sigils": s, "firsts": firsts, "milestones": hit, "unlocked": unlocked, "ascension_unlocked": unlocked_asc,
		"skins_unlocked": skins, "blueprints": arm.blueprints, "items_unlocked": arm.items, "mastery": arm.mastery}

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
	var kb: Dictionary = records.get("kills_by_id", {})
	var sk: Dictionary = st.get("kills_by_id", {})
	for id in sk:
		kb[String(id)] = int(kb.get(String(id), 0)) + int(sk[id])
	records.kills_by_id = kb
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
	add.call("freezes", int(st.get("freezes", 0)))
	add.call("sets3", int(st.get("sets3", 0)))
	add.call("rune_triggers", int(st.get("rune_triggers", 0)))
	add.call("potions", int(st.get("potions_used", 0)))
	add.call("high_rollers", int(st.get("high_rollers", 0)))
	add.call("skeleton_kills", int(st.get("skeleton_kills", 0)))
	records.counters = c

## [current, needed] toward a milestone condition, for progress bars: every form of _cond ({stat},
## {class_wins}, {boss_kills}, {any}: the closest branch, {all}: the furthest branch).
func cond_progress(cond: Dictionary) -> Array:
	if cond.has("any") or cond.has("all"):
		var subs: Array = cond.get("any", cond.get("all", []))
		var pick := [0, 1]
		var pick_r := -1.0 if cond.has("any") else 2.0
		for sub in subs:
			var pr := cond_progress(sub)
			var r := float(pr[0]) / maxf(1.0, float(pr[1]))
			if (cond.has("any") and r > pick_r) or (cond.has("all") and r < pick_r):
				pick_r = r
				pick = pr
		return pick
	var need := int(cond.get("min", 1))
	var cur := 0
	if cond.has("class_wins"):
		cur = int((records.get("wins_by_class", {}) as Dictionary).get(String(cond.class_wins), 0))
	elif cond.has("boss_kills"):
		cur = int((records.get("boss_kills", {}) as Dictionary).get(String(cond.boss_kills), 0))
	else:
		cur = counter(String(cond.get("stat", "")))
	return [mini(cur, need), need]

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
		"unlocks": unlocks.duplicate(true), "disabled": disabled.duplicate(true), "armory": armory.duplicate(true),
		"upgrades": upgrades.duplicate(true), "starter_kind": starter_kind,
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
			# v1/v2 files list the old gear pieces (helm, blade, boots, charm): their rank groups
			var uid := String(ItemDefs.LEGACY_GROUP.get(String(id), id)) if kind == "gear" else String(id)
			p.grant(kind, uid)
	var dis: Dictionary = d.get("disabled", {})
	for kind in ["runes", "kinds", "passives"]:
		var a: Array = []
		for id in dis.get(kind, []):
			if UnlockDefs.all_ids(kind).has(String(id)):
				a.append(String(id))
		p.disabled[kind] = a
	if int(d.get("version", 1)) >= 3 or d.has("armory"):
		p._load_armory(d.get("armory", {}))
	else:
		p._migrate_gear(d.get("gear", {}), d.get("gear_traits", {}))
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

# ------------------------------------------------------------------ Armory (v3)

static func fresh_armory() -> Dictionary:
	var ranks := {}
	for g in ItemDefs.GROUPS:
		ranks[g] = 0
	return {"ranks": ranks, "pouch": 0, "owned": [], "variants": {}, "blueprints": {}, "mastery": {}, "feats": [],
		"equipped": {}, "appearance": {}, "seen_new": []}

func _ranks() -> Dictionary:
	if not armory.has("ranks"):
		armory["ranks"] = fresh_armory().ranks
	return armory.ranks

## Rank of a group (weapon | offhand | armor | trinket): 0..8.
func rank(group: String) -> int:
	return int((armory.get("ranks", {}) as Dictionary).get(group, 0))

func has_pouch() -> bool:
	return int(armory.get("pouch", 0)) >= 1

func owns_item(id: String) -> bool:
	return (armory.get("owned", []) as Array).has(id)

## Crafted variants of an item, the Standard (the item id) first when the item is owned.
func owned_variants(item: String) -> Array:
	var out: Array = [item] if owns_item(item) else []
	for v in (armory.get("variants", {}) as Dictionary).get(item, []):
		out.append(String(v))
	return out

func owns_variant(item: String, variant: String) -> bool:
	if variant == "" or variant == item:
		return owns_item(item)
	return ((armory.get("variants", {}) as Dictionary).get(item, []) as Array).has(variant)

func has_blueprint(item: String, variant: String) -> bool:
	return ((armory.get("blueprints", {}) as Dictionary).get(item, []) as Array).has(variant)

func item_mastery(item: String) -> int:
	return int((armory.get("mastery", {}) as Dictionary).get(item, 0))

## Adds an item to the collection (no cost). False if already owned or unknown.
func grant_item(id: String) -> bool:
	if not ItemDefs.has(id) or owns_item(id):
		return false
	var owned: Array = []
	for x in ItemDefs.IDS:
		if x == id or owns_item(String(x)):
			owned.append(x)
	armory["owned"] = owned
	_new(id)
	return true

## Adds a crafted variant (no cost; the base item comes with it). False if already owned.
func grant_variant(item: String, variant: String) -> bool:
	if not ItemDefs.is_variant_of(variant, item):
		return false
	grant_item(item)
	if owns_variant(item, variant):
		return false
	var vs: Dictionary = armory.get("variants", {})
	var have: Array = vs.get(item, [])
	have.append(variant)
	vs[item] = have
	armory["variants"] = vs
	var bp: Dictionary = armory.get("blueprints", {})
	if bp.has(item):
		(bp[item] as Array).erase(variant)
	_new(variant)
	return true

## Unlocks a variant blueprint (craftable). False if already a blueprint or crafted.
func add_blueprint(item: String, variant: String) -> bool:
	if not ItemDefs.VARIANTS.has(variant) or owns_variant(item, variant) or has_blueprint(item, variant):
		return false
	var bp: Dictionary = armory.get("blueprints", {})
	var have: Array = bp.get(item, [])
	have.append(variant)
	bp[item] = have
	armory["blueprints"] = bp
	_new(variant)
	return true

func _new(id: String) -> void:
	var sn: Array = armory.get("seen_new", [])
	if not sn.has(id):
		sn.append(id)
	armory["seen_new"] = sn

## A class's signature kit (§6), including its signature variant (the Necromancer's Bone Staff).
func grant_kit(class_id: String) -> void:
	for id in ItemDefs.kit_items(class_id):
		grant_item(String(id))
	for kv in ItemDefs.kit_variants(class_id):
		grant_variant(String(kv[0]), String(kv[1]))

## The class's default loadout: its kit (owned pieces only), the Tankard if owned, no 2nd trinket.
func default_loadout(class_id: String) -> Dictionary:
	var k: Dictionary = ItemDefs.KITS.get(class_id, {})
	var out := {}
	for slot in ["weapon", "offhand", "head"]:
		var e: Array = k.get(slot, ["", ""])
		var id := String(e[0])
		var v := String(e[1]) if owns_variant(id, String(e[1])) else id
		out[slot] = {"id": id if owns_item(id) else "", "variant": v if owns_item(id) else ""}
	var body := String(k.get("body", ""))
	out["body"] = body if owns_item(body) else ""
	out["trinket"] = "tankard" if owns_item("tankard") else ""
	out["trinket2"] = ""
	var back := String(k.get("back", ""))
	out["back"] = back if owns_item(back) else ""
	return out

## The class's effective loadout: the stored choice (or the default kit), validated: owned items
## and variants only, the right slot, two-handed weapons drop hand off-hands, the Monster Kid's
## Head/Body stay the Dino Suit (and nobody else wears it), the 2nd trinket needs the Belt Pouch
## and can't repeat the 1st. Shape: {weapon: {id, variant}, offhand, head: {id, variant},
## body: id, trinket: id, trinket2: id, back: id} ("" = empty).
func loadout_for(class_id: String) -> Dictionary:
	var eq: Dictionary = (armory.get("equipped", {}) as Dictionary).get(class_id, {})
	var base := default_loadout(class_id)
	var out := {}
	for slot in ["weapon", "offhand", "head"]:
		var e: Variant = eq.get(slot, base[slot])
		var id := String(e.get("id", "")) if e is Dictionary else String(e)
		var v := String(e.get("variant", id)) if e is Dictionary else id
		if id != "" and (not owns_item(id) or not ItemDefs.fits(id, slot)):
			id = ""
		if id != "" and not owns_variant(id, v):
			v = id
		out[slot] = {"id": id, "variant": v if id != "" else ""}
	for slot in ["body", "trinket", "trinket2", "back"]:
		var e2: Variant = eq.get(slot, base[slot])
		var id2 := String(e2.get("id", "")) if e2 is Dictionary else String(e2)
		if id2 != "" and (not owns_item(id2) or not ItemDefs.fits(id2, slot)):
			id2 = ""
		out[slot] = id2
	var w: Dictionary = out.weapon
	if String(w.id) != "" and ItemDefs.hands(String(w.id), String(w.variant)) >= 2 and ItemDefs.hand_mount(String(out.offhand.id)):
		out["offhand"] = {"id": "", "variant": ""}
	var locked := String(ItemDefs.LOCKED_ARMOR.get(class_id, ""))
	if locked != "":
		out["head"] = {"id": "", "variant": ""}
		out["body"] = locked if owns_item(locked) else ""
	elif String(out.body) != "" and String(ItemDefs.def(String(out.body)).get("class_only", "")) not in ["", class_id]:
		out["body"] = ""
	if not has_pouch() or String(out.trinket2) == String(out.trinket):
		out["trinket2"] = ""
	return out

## The run-time items of a class: {slot: {id, variant, tier}} for stat slots whose item is active
## (tier >= 1). The Dino Suit sits in "body" (it covers the head too).
func resolve_items(class_id: String) -> Dictionary:
	var lo := loadout_for(class_id)
	var out := {}
	for slot in ItemDefs.STAT_SLOTS:
		var e: Variant = lo[slot]
		var id := String(e.id) if e is Dictionary else String(e)
		var v := String(e.variant) if e is Dictionary else id
		if id == "":
			continue
		var t := ItemDefs.tier_for(id, slot, class_id, rank(String(ItemDefs.GROUP_OF[slot])))
		if t > 0:
			out[slot] = {"id": id, "variant": v, "tier": t}
	return out

## Appearance of a class: {head: id | "own" | "hidden", body: id | "own"} (defaults: the class's
## own look; the Paladin's head hidden).
func appearance_of(class_id: String) -> Dictionary:
	var d: Dictionary = (ItemDefs.APPEARANCE_DEFAULT.get(class_id, {}) as Dictionary)
	var a: Dictionary = (armory.get("appearance", {}) as Dictionary).get(class_id, {})
	return {"head": String(a.get("head", d.get("head", "own"))), "body": String(a.get("body", d.get("body", "own")))}

## True when a feat's condition is met by the records (counters, kills) or by this run's stats
## (boss kills with an item equipped, wins with an item at an ascension, class wins).
func feat_met(feat: String, st: Dictionary = {}) -> bool:
	var cond: Dictionary = (ItemDefs.FEATS.get(feat, {}) as Dictionary).get("cond", {})
	if cond.has("counter"):
		return counter(String(cond.counter)) >= int(cond.min)
	if cond.has("kills"):
		return int((records.get("kills_by_id", {}) as Dictionary).get(String(cond.kills), 0)) >= int(cond.min)
	if st.is_empty():
		return false
	var lo: Dictionary = st.get("loadout", {})
	var with_item := func(item: String) -> bool:
		for slot in lo:
			if String((lo[slot] as Dictionary).get("id", "")) == item:
				return true
		return false
	var victory := bool(st.get("victory", false))
	if cond.has("boss"):
		var killed: Array = (st.get("bosses_killed", []) as Array) + (st.get("minibosses_killed", []) as Array)
		return killed.has(String(cond.boss)) and with_item.call(String(cond["with"]))
	if cond.has("win_with"):
		return victory and int(st.get("asc", 0)) >= int(cond.asc) and with_item.call(String(cond.win_with))
	if cond.has("class_win"):
		return victory and String(st.get("class_id", "")) == String(cond.class_win) and int(st.get("asc", 0)) >= int(cond.asc)
	return false

## Banks the Armory part of a run: mastery for every equipped base item (+ fights won), then
## blueprints (mastery thresholds, feats) and feat Back items. Returns {blueprints: [[item,
## variant, source]], items: [[id, source]], mastery: {item: total}}.
func _armory_result(st: Dictionary, _victory: bool, _cls: String) -> Dictionary:
	var bps: Array = []
	var its: Array = []
	var ms := {}
	var fights := int(st.get("item_fights", 0))
	var lo: Dictionary = st.get("loadout", {})
	var mastery: Dictionary = armory.get("mastery", {})
	var done := {}
	for slot in lo:
		var id := String((lo[slot] as Dictionary).get("id", ""))
		if id == "" or done.has(id) or fights <= 0:
			continue
		done[id] = true
		mastery[id] = int(mastery.get(id, 0)) + fights
		ms[id] = int(mastery[id])
	armory["mastery"] = mastery
	var feats: Array = armory.get("feats", [])
	for f in ItemDefs.FEATS:
		if not feats.has(f) and feat_met(String(f), st):
			feats.append(f)
	armory["feats"] = feats
	for v in ItemDefs.VARIANTS:
		var vd: Dictionary = ItemDefs.VARIANTS[v]
		var item := String(vd.item)
		var u: Dictionary = vd.unlock
		var src := ""
		var need := int(u.get("mastery", u.get("or_mastery", 0)))
		if need > 0 and item_mastery(item) >= need:
			src = "mastery"
		elif u.has("feat") and feats.has(String(u.feat)):
			src = "feat"
		if src != "" and add_blueprint(item, String(v)):
			bps.append([item, String(v), src])
	for b in ItemDefs.BACK_FEATS:
		if feats.has(String(ItemDefs.BACK_FEATS[b])) and grant_item(String(b)):
			its.append([String(b), "feat"])
	return {"blueprints": bps, "items": its, "mastery": ms}

# ------------------------------------------------------------------ Armory serialisation

## Loads a v3 armory (tolerant: unknown ids dropped, ranks clamped). Kits granted by the owned
## classes stay owned.
func _load_armory(a: Dictionary) -> void:
	var r: Dictionary = a.get("ranks", {})
	for g in ItemDefs.GROUPS:
		_ranks()[g] = clampi(int(r.get(g, 0)), 0, ItemDefs.RANK_MAX)
	armory["pouch"] = 1 if int(a.get("pouch", 0)) >= 1 else 0
	for id in a.get("owned", []):
		grant_item(String(id))
	var vs: Dictionary = a.get("variants", {})
	for item in vs:
		for v in vs[item]:
			grant_variant(String(item), String(v))
	var bp: Dictionary = a.get("blueprints", {})
	for item in bp:
		for v in bp[item]:
			add_blueprint(String(item), String(v))
	var ms := {}
	var am: Dictionary = a.get("mastery", {})
	for item in am:
		if ItemDefs.has(String(item)):
			ms[String(item)] = int(am[item])
	armory["mastery"] = ms
	var feats: Array = []
	for f in a.get("feats", []):
		if ItemDefs.FEATS.has(String(f)) and not feats.has(String(f)):
			feats.append(String(f))
	armory["feats"] = feats
	var eq := {}
	var ae: Dictionary = a.get("equipped", {})
	for cid in ae:
		if not HeroDefs.DATA.has(String(cid)):
			continue
		var e: Dictionary = ae[cid]
		var row := {}
		for slot in ["weapon", "offhand", "head"]:
			if e.has(slot):
				var x: Variant = e[slot]
				var id := String(x.get("id", "")) if x is Dictionary else String(x)
				row[slot] = {"id": id, "variant": String(x.get("variant", id)) if x is Dictionary else id}
		for slot in ["body", "trinket", "trinket2", "back"]:
			if e.has(slot):
				var y: Variant = e[slot]
				row[slot] = String(y.get("id", "")) if y is Dictionary else String(y)
		eq[String(cid)] = row
	armory["equipped"] = eq
	var ap := {}
	var aa: Dictionary = a.get("appearance", {})
	for cid in aa:
		var row2 := {}
		for k in ["head", "body"]:
			if (aa[cid] as Dictionary).has(k):
				row2[k] = String(aa[cid][k])
		ap[String(cid)] = row2
	armory["appearance"] = ap
	var sn: Array = []
	for x in a.get("seen_new", []):
		sn.append(String(x))
	armory["seen_new"] = sn

## v1/v2 gear -> v3 (§7.5, one-time, no refunds): levels become ranks (blade -> Weapon, helm ->
## Armor, boots -> Off-hand, charm -> Trinket); owned pieces grant the items that carry their
## traits; the chosen traits' trinkets auto-equip for every class (slot 1 by the old level order,
## the Compass first when the old Boots had the R6 board reroll, with the Trinket rank raised to 6
## so the reroll survives); the Belt Pouch is free when the old Boots and Charm were both L5+; the
## Opener trait grants the Spear.
func _migrate_gear(g: Dictionary, gt: Dictionary) -> void:
	for old in ItemDefs.LEGACY_GROUP:
		var grp := String(ItemDefs.LEGACY_GROUP[old])
		if g.has(old):
			grant("gear", grp)
			_ranks()[grp] = clampi(int(g[old]), 0, ItemDefs.RANK_MAX)
	var grants := {"helm": ["round_shield", "tankard"], "blade": ["sword", "hand_axe", "crossbow"],
		"boots": ["compass", "lantern"], "charm": ["coin_purse", "traders_map", "healers_flask"]}
	for old in grants:
		if g.has(old):
			for id in grants[old]:
				grant_item(String(id))
	# chosen traits -> the trinket that carries each, weighted by the old piece's level
	var carrier := {"helm_lap_heal": "tankard", "helm_campfire": "tankard", "boots_portal": "compass",
		"boots_pair_pick": "compass", "boots_sure_foot": "lantern", "boots_treasury_step": "coin_purse",
		"charm_cheap_restock": "traders_map", "charm_free_restock": "traders_map", "charm_shop_potion": "healers_flask",
		"charm_treasury": "coin_purse"}
	var cands: Array = [] # [level, item]
	for old in ["boots", "charm", "helm"]:
		var lvl := int(g.get(old, 0))
		var t: Dictionary = gt.get(old, {})
		for tier in ["4", "8"]:
			if lvl < int(tier):
				continue
			var opts := GearDefs.trait_options(old, tier)
			var pick := String(t.get(tier, opts[0]))
			if not opts.has(pick):
				pick = String(opts[0])
			if carrier.has(pick):
				cands.append([lvl, String(carrier[pick])])
	if String((gt.get("blade", {}) as Dictionary).get("8", "")) == "blade_boss_opener" and int(g.get("blade", 0)) >= 8:
		grant_item("spear")
	cands.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var order: Array = []
	if int(g.get("boots", 0)) >= GearDefs.BOOTS_REROLL_LEVEL and owns_item("compass"):
		order.append("compass")
	for cnd in cands:
		if not order.has(String(cnd[1])):
			order.append(String(cnd[1]))
	if int(g.get("boots", 0)) >= 5 and int(g.get("charm", 0)) >= 5:
		armory["pouch"] = 1
	if int(g.get("boots", 0)) >= GearDefs.BOOTS_REROLL_LEVEL and owns_item("compass"):
		# the old Boots' board reroll moves to the Compass, which needs Trinket R6 in slot 1
		grant("gear", "trinket")
		_ranks()["trinket"] = maxi(rank("trinket"), ItemDefs.COMPASS_REROLL_RANK)
	if order.is_empty():
		return
	var eq: Dictionary = armory.get("equipped", {})
	for cid in unlocks.get("classes", []):
		var lo := loadout_for(String(cid))
		lo["trinket"] = String(order[0])
		if has_pouch() and order.size() > 1:
			lo["trinket2"] = String(order[1])
		eq[String(cid)] = lo
	armory["equipped"] = eq
	armory["seen_new"] = []
