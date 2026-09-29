class_name CampState
extends RefCounted
## What the Camp looks like for a profile: a pure, deterministic function of the Profile (the
## same profile always builds the same camp). The 3D CampScene renders it; the reveal after a
## run animates the diff between the state before and after banking.
##
## of(p) -> {
##   stage: 0..3 (camp size: 0 fresh, 1 runs 1-4, 2 runs 5-14, 3 runs 15+),
##   stations: {id: {state: "ruined"|"construction"|"built", tier: 0..3, ...station details}},
##   hero: class id (sits by the fire), classes: [unlocked class ids, content order],
##   locked_classes: [ids], pets: [owned pet ids], pet: equipped id | "",
##   bosses: [final bosses beaten], minibosses: [mini-bosses beaten], biomes: [biomes discovered],
##   class_wins: [class ids with a win], wins: int, runs: int,
##   fire: 0..3, lanterns: 0..4, fences: 0..3, asc: ascension unlocked }
##
## Station states:
##   ruined        locked and its unlock is still far off (rubble, overgrown)
##   construction  locked but its unlock is close (>= 50% of the milestone), or open but nothing
##                 invested yet (scaffolding, crates, a basic version that already works)
##   built         tier 1..3 by investment (gear levels, packs, pets, minigames)

const STAGE_RUNS := [1, 5, 15]


static func of(p: Profile) -> Dictionary:
	var runs := int(p.records.get("runs", 0))
	var stage := 0
	for t in STAGE_RUNS:
		if runs >= int(t):
			stage += 1
	var f: Dictionary = p.records.get("firsts", {})
	var classes: Array = []
	var locked: Array = []
	for id in HeroDefs.IDS:
		if p.class_allowed(String(id)):
			classes.append(String(id))
		elif not bool((HeroDefs.DATA[id] as Dictionary).get("secret", false)):
			locked.append(String(id))    # the secret class leaves no trace (no tent) until it is found
	var hero := String(p.loadout.get("class", "knight"))
	if not classes.has(hero) and not classes.is_empty():
		hero = String(classes[0])
	var spent := int(p.records.get("crowns_earned", 0)) - p.crowns
	return {
		"stage": stage,
		"stations": {"armory": _armory(p), "workshop": _workshop(p), "pet_den": _pet_den(p), "arcade": _arcade(p)},
		"hero": hero, "classes": classes, "locked_classes": locked, "skins": _skins(p, classes),
		"pets": (p.unlocks.get("pets", []) as Array).duplicate(), "pet": String(p.loadout.get("pet", "")),
		"pet_levels": _pet_levels(p),
		"bosses": (f.get("boss", []) as Array).duplicate(), "minibosses": (f.get("miniboss", []) as Array).duplicate(),
		"biomes": (f.get("biome", []) as Array).duplicate(), "class_wins": (f.get("class_win", []) as Array).duplicate(),
		"wins": int(p.records.get("wins", 0)), "runs": runs,
		"fire": stage,
		"lanterns": (1 if runs >= 2 else 0) + (1 if runs >= 5 else 0) + (1 if runs >= 10 else 0) + (1 if runs >= 20 else 0),
		"fences": (1 if spent >= 100 else 0) + (1 if spent >= 500 else 0) + (1 if spent >= 1500 else 0),
		"asc": int(p.ascension.get("unlocked", 0)),
	}


static func _pet_levels(p: Profile) -> Dictionary:
	var out := {}
	for id in p.unlocks.get("pets", []):
		out[String(id)] = p.pet_level(String(id))
	return out


## Milestone progress (0..1) toward the milestone that unlocks [kind, id].
static func _near(p: Profile, kind: String, id: String) -> float:
	var m := CampInfo.milestone_for(kind, id)
	if m.is_empty():
		return 0.0
	var pr := CampInfo.progress(p, m.cond)
	return float(pr[0]) / maxf(1.0, float(pr[1]))


## The Armory's racks (docs/design/2026-09-29-armory-items.md §8.3): what the profile owns, as
## display ids (ItemMounts ids; crafted variants hang next to their Standard), and the hero
## class's equipped kit (glows).
##   {ranks, levels (rank sum), pouch, weapons, shields (hand off-hands), table (trinkets + belt
##    and back off-hands), bodies, heads, backs, kit: [display ids worn by the hero class]}
static func _armory(p: Profile) -> Dictionary:
	var owned: Array = p.unlocks.get("gear", [])
	var ranks := {}
	var levels := 0
	for g in ItemDefs.GROUPS:
		ranks[String(g)] = p.rank(String(g))
		levels += p.rank(String(g))
	var weapons: Array = []
	var shields: Array = []
	var table: Array = []
	var bodies: Array = []
	var heads: Array = []
	var backs: Array = []
	for id in ItemDefs.IDS:
		var sid := String(id)
		if not p.owns_item(sid):
			continue
		match ItemDefs.slot_of(sid):
			"weapon":
				weapons.append_array(p.owned_variants(sid))
			"offhand":
				if ItemDefs.hand_mount(sid):
					shields.append_array(p.owned_variants(sid))
				else:
					table.append(sid)
			"trinket":
				table.append(sid)
			"body":
				bodies.append(sid)
			"head":
				heads.append_array(p.owned_variants(sid))
			"back":
				backs.append(sid)
	var hero := String(p.loadout.get("class", "knight"))
	var kit: Array = []
	if p.class_allowed(hero):
		var lo := p.loadout_for(hero)
		for slot in ["weapon", "offhand", "head"]:
			var e: Dictionary = lo[slot]
			if String(e.id) != "":
				kit.append(String(e.variant) if String(e.variant) != "" else String(e.id))
		for slot in ["body", "trinket", "trinket2", "back"]:
			if String(lo[slot]) != "":
				kit.append(String(lo[slot]))
	# the racks show the first pegs' worth: every base item before any variant (variety), the hero's
	# worn pieces first so they are always on show
	weapons = _rack_order(weapons, kit)
	shields = _rack_order(shields, kit)
	heads = _rack_order(heads, kit)
	var st := {"levels": levels, "ranks": ranks, "gear": owned.duplicate(), "pouch": int(p.armory.get("pouch", 0)),
		"weapons": weapons, "shields": shields, "table": table, "bodies": bodies, "heads": heads, "backs": backs,
		"kit": kit, "hero": hero, "belt": int(p.upgrades.get("potion_belt", 0))}
	if owned.is_empty():
		st.state = "construction" if _near(p, "gear", "armor") >= 0.5 else "ruined"
		st.tier = 0
	elif levels == 0:
		st.state = "construction"
		st.tier = 0
	else:
		st.state = "built"
		st.tier = 1 if levels < 8 else (2 if levels < 20 else 3)
	return st


## Worn pieces first, then Standards (base items), then crafted variants; content order within.
static func _rack_order(ids: Array, worn: Array) -> Array:
	var out: Array = []
	for id in ids:
		if worn.has(id):
			out.append(id)
	for id in ids:
		if not out.has(id) and ItemDefs.ITEMS.has(String(id)):
			out.append(id)
	for id in ids:
		if not out.has(id):
			out.append(id)
	return out


static func _workshop(p: Profile) -> Dictionary:
	var packs: Array = p.unlocks.get("packs", [])
	var ups := int(p.upgrades.get("starter_kit", 0)) + int(p.upgrades.get("whetstone", 0))
	var st := {"packs": packs.duplicate(), "whetstone": int(p.upgrades.get("whetstone", 0)), "starter_kit": int(p.upgrades.get("starter_kit", 0))}
	if packs.size() <= 1 and ups == 0:
		st.state = "construction"
		st.tier = 0
	else:
		st.state = "built"
		st.tier = 1 if packs.size() < 4 else (2 if packs.size() < 7 and int(st.whetstone) == 0 else 3)
	return st


static func _pet_den(p: Profile) -> Dictionary:
	var pets: Array = p.unlocks.get("pets", [])
	var high := 0
	for id in pets:
		high = maxi(high, p.pet_level(String(id)))
	var st := {"pets": pets.duplicate(), "high": high}
	if pets.is_empty():
		st.state = "construction" if _near(p, "pets", "pumpkin_sprite") >= 0.5 else "ruined"
		st.tier = 0
	else:
		st.state = "built"
		st.tier = 1 if pets.size() < 3 else (2 if pets.size() < 5 and high < 6 else 3)
	return st


static func _arcade(p: Profile) -> Dictionary:
	var games: Array = p.unlocks.get("minigames", [])
	var slot := int(p.upgrades.get("loadout_slot", 0))
	var st := {"games": games.duplicate(), "slot": slot}
	if games.size() <= 2 and slot == 0:
		st.state = "construction"
		st.tier = 0
	else:
		st.state = "built"
		st.tier = 1 if games.size() < 4 and slot == 0 else (2 if games.size() < 4 or slot == 0 else 3)
	return st


## The changes worth a build-out moment between two states, in reveal order:
## [{kind: "station"|"class"|"pet"|"boss"|"biome"|"stage", id, text}].
static func diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	if int(b.stage) > int(a.stage):
		out.append({"kind": "stage", "id": str(b.stage), "text": "The camp grows!"})
	for id in CampInfo.STATION_IDS:
		var sa: Dictionary = a.stations[id]
		var sb: Dictionary = b.stations[id]
		var name := String(CampInfo.STATIONS[id].name)
		if String(sa.state) != String(sb.state):
			match String(sb.state):
				"construction":
					out.append({"kind": "station", "id": id, "text": "Work begins on the %s" % name})
				"built":
					out.append({"kind": "station", "id": id, "text": ("The %s is rebuilt!" if String(sa.state) == "ruined" else "The %s is open!") % name})
		elif int(sb.tier) > int(sa.tier):
			out.append({"kind": "station", "id": id, "text": "The %s is upgraded" % name})
	for id in b.classes:
		if not (a.classes as Array).has(id):
			out.append({"kind": "class", "id": id, "text": "The %s joins your camp" % CampInfo.name_of("classes", String(id))})
	for id in b.pets:
		if not (a.pets as Array).has(id):
			out.append({"kind": "pet", "id": id, "text": "%s moves in" % PetDefs.name_of(String(id))})
	for id in b.bosses:
		if not (a.bosses as Array).has(id):
			out.append({"kind": "boss", "id": id, "text": "A trophy: %s" % CampInfo.name_of("bosses", String(id))})
	return out


## Worn look per owned class: {class: [skin, prestige]} (the Wardrobe's choice).
static func _skins(p: Profile, classes: Array) -> Dictionary:
	var out := {}
	for id in classes:
		var skin := p.equipped_skin(String(id))
		var pres := p.prestige_on(String(id))
		out[String(id)] = [skin, pres, ArmoryLook.of_profile(p, String(id), skin, pres)]
	return out
