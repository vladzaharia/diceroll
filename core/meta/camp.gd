class_name Camp
extends RefCounted
## Meta commands over a Profile, in the same command -> events style as GameFlow. Illegal or
## unaffordable commands return [{type:"error", msg}] and change nothing.
##
## Commands (see apply() for the replay format):
##   buy_upgrade(track, id)     Crowns upgrades: workshop whetstone|starter_kit, armory
##                              potion_belt, arcade loadout_slot (UnlockDefs.UPGRADES)
##   level_gear(slot)           Armory: craft / level helm|blade|boots|charm (Crowns)
##   set_trait(slot, tier, id)  Armory: pick the L4 / L8 trait (free, switchable)
##   level_pet(id)              Pet Den: buy levels 6..10 (Crowns) once XP reached level 5
##   unlock(kind, id)           Spend Sigils to unlock early (classes, biomes, bosses,
##                              minibosses, pets, minigames, packs, gear, potions)
##   toggle_pool(kind, id, on)  Workshop pool toggle (runes|kinds|passives), <= 25% off
##   set_starter_kind(kind)     Workshop Starter Kit: kind of the 2nd starting die
##   set_loadout(minigames, pet)  up to loadout_slots() owned minigames, one owned pet or ""
##   set_class(id) / set_mode("standard"|"short") / set_ascension(n)
##   bank_run(stats)            banks a finished run (game_over.stats)
##   equip_skin(class, skin)    Wardrobe: equip an owned skin (free; prestige is a toggle)
##   buy_skin(class, skin)      Wardrobe: buy a non-prestige skin for SkinDefs.BUY_PRICE Crowns
##                              once every Crowns sink is maxed (Profile.crowns_capped())
##   set_prestige(class, on)    Wardrobe: show / hide the owned A10 prestige overlay
##   mark_skins_seen(class)     Wardrobe: clears the "new" dots of a class ("" = all)
##
## Events: crowns_changed {amount, total} · sigils_changed {amount, total} ·
##   upgrade_bought {track: "workshop"|"armory"|"arcade"|"pet_den", id, level} ·
##   trait_set {slot, tier, id} · unlocked {kind, id, source: "sigils"|"milestone"} ·
##   pool_toggled {kind, id, enabled} · starter_kind_set {kind} ·
##   loadout_changed {class, mode, minigames, pet} · ascension_changed {selected, unlocked} ·
##   milestone {id, desc, unlocks} · first {kind, id, sigils} · run_banked {crowns, sigils,
##   milestones, unlocked, ascension_unlocked, skins_unlocked} · skin_unlocked {class, skin,
##   source: "record"|"crowns"} · skin_equipped {class, skin} · prestige_set {class, on} ·
##   skins_seen {class} · error {msg}

var profile: Profile

func _init(p: Profile = null) -> void:
	profile = p if p != null else Profile.fresh()

# ------------------------------------------------------------------ commands

func buy_upgrade(track: String, id: String) -> Array[Dictionary]:
	var d := UnlockDefs.upgrade_def(track, id)
	if d.is_empty():
		return _err("unknown upgrade %s/%s" % [track, id])
	if int(profile.upgrades.get(id, 0)) >= 1:
		return _err("already bought")
	if d.has("requires") and not profile.owns("features", String(d.requires)):
		return _err("not unlocked yet")
	var cost: Dictionary = d.cost
	if not profile.can_afford(cost):
		return _err("not enough Crowns")
	var ev := _pay(cost)
	profile.upgrades[id] = 1
	ev.append({"type": "upgrade_bought", "track": track, "id": id, "level": 1})
	return ev

func level_gear(slot: String) -> Array[Dictionary]:
	if not GearDefs.DEFS.has(slot):
		return _err("unknown gear slot " + slot)
	if not profile.owns("gear", slot):
		return _err("gear not unlocked yet")
	var lvl := profile.gear_level(slot)
	var cost := GearDefs.cost(slot, lvl)
	if cost.is_empty():
		return _err("already at max level")
	if not profile.can_afford(cost):
		return _err("not enough Crowns")
	var ev := _pay(cost)
	profile.gear[slot] = lvl + 1
	ev.append({"type": "upgrade_bought", "track": "armory", "id": slot, "level": lvl + 1})
	return ev

func set_trait(slot: String, tier: String, id: String) -> Array[Dictionary]:
	var opts := GearDefs.trait_options(slot, tier)
	if not opts.has(id):
		return _err("bad trait")
	if profile.gear_level(slot) < int(tier):
		return _err("reach level %s first" % tier)
	var t: Dictionary = profile.gear_traits.get(slot, {})
	t[tier] = id
	profile.gear_traits[slot] = t
	return [{"type": "trait_set", "slot": slot, "tier": tier, "id": id}]

func level_pet(id: String) -> Array[Dictionary]:
	if not profile.owns("pets", id):
		return _err("pet not owned")
	var lvl := profile.pet_level(id)
	if lvl < PetDefs.XP_LEVEL_MAX:
		return _err("levels 1-5 come from fights won with the pet")
	var cost := PetDefs.level_cost(lvl)
	if cost.is_empty():
		return _err("already at max level")
	if not profile.can_afford(cost):
		return _err("not enough Crowns")
	var ev := _pay(cost)
	profile.pet_bought[id] = lvl + 1
	ev.append({"type": "upgrade_bought", "track": "pet_den", "id": id, "level": lvl + 1})
	return ev

func unlock(kind: String, id: String) -> Array[Dictionary]:
	if profile.owns(kind, id):
		return _err("already unlocked")
	var cost := UnlockDefs.sigil_cost(kind, id, profile.unlocks.get("classes", []))
	if cost.is_empty():
		return _err("can't be bought: %s/%s" % [kind, id])
	if not profile.can_afford(cost):
		return _err("not enough Sigils")
	var ev := _pay(cost)
	profile.grant(kind, id)
	ev.append({"type": "unlocked", "kind": kind, "id": id, "source": "sigils"})
	return ev

func toggle_pool(kind: String, id: String, enabled: bool) -> Array[Dictionary]:
	if not ["runes", "kinds", "passives"].has(kind):
		return _err("bad pool " + kind)
	var owned := UnlockDefs.pool_from_packs(profile.unlocks.packs, kind)
	if not owned.has(id):
		return _err("not unlocked")
	var off: Array = profile.disabled.get(kind, [])
	if enabled:
		off.erase(id)
	elif not off.has(id):
		if off.size() + 1 > int(floor(owned.size() * UnlockDefs.POOL_TOGGLE_MAX)):
			return _err("at most %d%% of a pool can be off" % int(UnlockDefs.POOL_TOGGLE_MAX * 100))
		off.append(id)
	profile.disabled[kind] = off
	return [{"type": "pool_toggled", "kind": kind, "id": id, "enabled": enabled}]

func set_starter_kind(kind: String) -> Array[Dictionary]:
	if int(profile.upgrades.get("starter_kit", 0)) < 1:
		return _err("buy the Starter Kit first")
	if kind != "" and not UnlockDefs.starter_kinds(profile.pool("kinds")).has(kind):
		return _err("pick an unlocked sidegrade kind (%s)" % ", ".join(UnlockDefs.STARTER_KINDS))
	profile.starter_kind = kind
	return [{"type": "starter_kind_set", "kind": kind}]

func set_loadout(minigames: Array, pet: String) -> Array[Dictionary]:
	if minigames.size() > profile.loadout_slots():
		return _err("only %d loadout slots" % profile.loadout_slots())
	var mg: Array = []
	for m in minigames:
		var id := String(m)
		if not profile.owns("minigames", id):
			return _err("minigame not unlocked: " + id)
		if mg.has(id):
			return _err("duplicate minigame " + id)
		mg.append(id)
	if pet != "" and not profile.owns("pets", pet):
		return _err("pet not owned: " + pet)
	profile.loadout.minigames = mg
	profile.loadout.pet = pet
	return [_loadout_ev()]

func set_class(id: String) -> Array[Dictionary]:
	if not HeroDefs.DATA.has(id) or not profile.class_allowed(id):
		return _err("class locked: " + id)
	profile.loadout["class"] = id
	return [_loadout_ev()]

func set_mode(mode: String) -> Array[Dictionary]:
	if mode != "standard" and mode != "short":
		return _err("bad mode " + mode)
	profile.loadout["mode"] = mode
	return [_loadout_ev()]

func set_ascension(n: int) -> Array[Dictionary]:
	if n < 0 or n > int(profile.ascension.get("unlocked", 0)):
		return _err("ascension %d is locked" % n)
	profile.ascension.selected = n
	return [{"type": "ascension_changed", "selected": n, "unlocked": int(profile.ascension.unlocked)}]

func bank_run(stats: Dictionary) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var res := profile.apply_run_result(stats)
	if int(res.crowns) != 0:
		ev.append({"type": "crowns_changed", "amount": int(res.crowns), "total": profile.crowns})
	for f in res.firsts:
		ev.append({"type": "first", "kind": String(f[0]), "id": String(f[1]), "sigils": int(Economy.SIGIL_FIRST.get(f[0], 0))})
	if int(res.sigils) != 0:
		ev.append({"type": "sigils_changed", "amount": int(res.sigils), "total": profile.sigils})
	for m in res.milestones:
		var md := UnlockDefs.milestone(String(m))
		ev.append({"type": "milestone", "id": String(m), "desc": String(md.desc), "unlocks": (md.unlocks as Array).duplicate(true)})
	for u in res.unlocked:
		ev.append({"type": "unlocked", "kind": String(u[0]), "id": String(u[1]), "source": "milestone"})
	if int(res.ascension_unlocked) > 0:
		ev.append({"type": "ascension_changed", "selected": int(profile.ascension.selected), "unlocked": int(profile.ascension.unlocked)})
	for sk in res.skins_unlocked:
		ev.append({"type": "skin_unlocked", "class": String(sk[0]), "skin": String(sk[1]), "source": "record"})
	ev.append({"type": "run_banked", "crowns": int(res.crowns), "sigils": int(res.sigils), "milestones": res.milestones,
		"unlocked": res.unlocked, "ascension_unlocked": int(res.ascension_unlocked), "skins_unlocked": res.skins_unlocked})
	return ev

func equip_skin(class_id: String, skin: String) -> Array[Dictionary]:
	if not SkinDefs.has(class_id, skin):
		return _err("unknown skin %s/%s" % [class_id, skin])
	if SkinDefs.is_prestige(skin):
		return set_prestige(class_id, true)
	if not profile.owns_skin(class_id, skin):
		return _err("skin locked: " + SkinDefs.cond_text(class_id, skin))
	var eq: Dictionary = profile.cosmetics.get("equipped", {})
	eq[class_id] = skin
	profile.cosmetics["equipped"] = eq
	return [{"type": "skin_equipped", "class": class_id, "skin": skin}]

func buy_skin(class_id: String, skin: String) -> Array[Dictionary]:
	if not SkinDefs.has(class_id, skin):
		return _err("unknown skin %s/%s" % [class_id, skin])
	if profile.owns_skin(class_id, skin):
		return _err("already owned")
	if skin == "default" or SkinDefs.is_prestige(skin):
		return _err("the prestige skin can't be bought")
	if not profile.crowns_capped():
		return _err("skins are for sale once every Crowns upgrade is maxed")
	var cost := {"crowns": SkinDefs.BUY_PRICE}
	if not profile.can_afford(cost):
		return _err("not enough Crowns")
	var ev := _pay(cost)
	profile.grant_skin(class_id, skin)
	ev.append({"type": "skin_unlocked", "class": class_id, "skin": skin, "source": "crowns"})
	return ev

func set_prestige(class_id: String, on: bool) -> Array[Dictionary]:
	if not profile.owns_skin(class_id, "prestige"):
		return _err("skin locked: " + SkinDefs.cond_text(class_id, "prestige"))
	var pr: Dictionary = profile.cosmetics.get("prestige", {})
	pr[class_id] = on
	profile.cosmetics["prestige"] = pr
	return [{"type": "prestige_set", "class": class_id, "on": on}]

func mark_skins_seen(class_id := "") -> Array[Dictionary]:
	var keep: Array = []
	for u in profile.cosmetics.get("unseen", []):
		if class_id != "" and not String(u).begins_with(class_id + ":"):
			keep.append(u)
	profile.cosmetics["unseen"] = keep
	return [{"type": "skins_seen", "class": class_id}]

## Replays one command: [name, args...].
func apply(cmd: Array) -> Array[Dictionary]:
	match String(cmd[0]):
		"buy_upgrade": return buy_upgrade(String(cmd[1]), String(cmd[2]))
		"level_gear": return level_gear(String(cmd[1]))
		"set_trait": return set_trait(String(cmd[1]), String(cmd[2]), String(cmd[3]))
		"level_pet": return level_pet(String(cmd[1]))
		"unlock": return unlock(String(cmd[1]), String(cmd[2]))
		"toggle_pool": return toggle_pool(String(cmd[1]), String(cmd[2]), bool(cmd[3]))
		"set_starter_kind": return set_starter_kind(String(cmd[1]))
		"set_loadout": return set_loadout(cmd[1], String(cmd[2]))
		"set_class": return set_class(String(cmd[1]))
		"set_mode": return set_mode(String(cmd[1]))
		"set_ascension": return set_ascension(int(cmd[1]))
		"equip_skin": return equip_skin(String(cmd[1]), String(cmd[2]))
		"buy_skin": return buy_skin(String(cmd[1]), String(cmd[2]))
		"set_prestige": return set_prestige(String(cmd[1]), bool(cmd[2]))
		"mark_skins_seen": return mark_skins_seen(String(cmd[1]) if cmd.size() > 1 else "")
	return _err("unknown command " + str(cmd[0]))

# ------------------------------------------------------------------ catalogue (UI + bot)

## Everything that can be bought right now or later: [{cmd, track, kind, id, name, level, max,
## cost, affordable}]. Owned / maxed entries are left out; `cmd` is an apply() command.
func catalog() -> Array:
	var out: Array = []
	for slot in GearDefs.SLOTS:
		if profile.owns("gear", slot):
			var lvl := profile.gear_level(slot)
			_cat(out, ["level_gear", slot], "armory", "", slot, GearDefs.name_of(slot), lvl, GearDefs.MAX_LEVEL, GearDefs.cost(slot, lvl))
	for track in UnlockDefs.UPGRADES:
		for id in UnlockDefs.UPGRADES[track]:
			var d: Dictionary = UnlockDefs.UPGRADES[track][id]
			if int(profile.upgrades.get(id, 0)) >= 1:
				continue
			if d.has("requires") and not profile.owns("features", String(d.requires)):
				continue
			_cat(out, ["buy_upgrade", track, id], track, "", id, String(d.name), 0, 1, d.cost)
	for id in profile.unlocks.pets:
		var lvl := profile.pet_level(id)
		_cat(out, ["level_pet", id], "pet_den", "", id, PetDefs.name_of(id), lvl, PetDefs.MAX_LEVEL, PetDefs.level_cost(lvl))
	for kind in UnlockDefs.SIGIL_PRICE:
		for id in UnlockDefs.all_ids(kind):
			if not profile.owns(kind, String(id)):
				_cat(out, ["unlock", kind, id], "sigils", kind, String(id), String(id), 0, 1,
					UnlockDefs.sigil_cost(kind, String(id), profile.unlocks.get("classes", [])))
	if profile.crowns_capped():
		for cid in profile.unlocks.get("classes", []):
			for s in SkinDefs.of(String(cid)):
				if bool(s.buyable) and not profile.owns_skin(String(cid), String(s.id)):
					_cat(out, ["buy_skin", cid, s.id], "wardrobe", "skins", "%s:%s" % [cid, s.id], String(s.name), 0, 1,
						{"crowns": SkinDefs.BUY_PRICE})
	return out

func _cat(out: Array, cmd: Array, track: String, kind: String, id: String, name: String, lvl: int, mx: int, cost: Dictionary) -> void:
	if cost.is_empty():
		return
	out.append({"cmd": cmd, "track": track, "kind": kind, "id": id, "name": name, "level": lvl, "max": mx,
		"cost": cost.duplicate(), "affordable": profile.can_afford(cost)})

## Crowns still needed to buy every Crowns item (gear to L8, upgrades, pet levels 6-10 of every
## pet), assuming every feature and pet gets unlocked.
static func total_crowns_sink() -> int:
	var t := 0
	for slot in GearDefs.SLOTS:
		for l in GearDefs.MAX_LEVEL:
			t += int(GearDefs.COSTS[l])
	for track in UnlockDefs.UPGRADES:
		for id in UnlockDefs.UPGRADES[track]:
			t += int(UnlockDefs.UPGRADES[track][id].cost.crowns)
	for c in PetDefs.LEVEL_COSTS:
		t += int(c) * PetDefs.IDS.size()
	return t

# ------------------------------------------------------------------ helpers

func _loadout_ev() -> Dictionary:
	return {"type": "loadout_changed", "class": String(profile.loadout.get("class", "knight")),
		"mode": String(profile.loadout.get("mode", "standard")),
		"minigames": (profile.loadout.minigames as Array).duplicate(), "pet": String(profile.loadout.pet)}

func _pay(cost: Dictionary) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var c := int(cost.get("crowns", 0))
	if c > 0:
		profile.crowns -= c
		ev.append({"type": "crowns_changed", "amount": -c, "total": profile.crowns})
	var s := int(cost.get("sigils", 0))
	if s > 0:
		profile.sigils -= s
		ev.append({"type": "sigils_changed", "amount": -s, "total": profile.sigils})
	return ev

static func _err(msg: String) -> Array[Dictionary]:
	return [{"type": "error", "msg": msg}]
