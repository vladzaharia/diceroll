class_name CampInfo
extends RefCounted
## Read-only presentation helpers for the Camp and the results screen: display names and
## icons for every unlockable, the milestone that unlocks a thing, station lock states, and the
## "nearest goals" list (review §2.3 / §5.6). Everything reads core data; nothing mutates.

const KIND_LABEL := {
	"classes": "Class", "biomes": "Biome", "bosses": "Final boss", "minibosses": "Mini-boss", "pets": "Pet",
	"minigames": "Minigame", "packs": "Workshop pack", "gear": "Armory gear", "potions": "Potion",
	"features": "Camp upgrade",
}

const PET_ICON := {
	"pumpkin_sprite": "heart", "skull_buddy": "skull", "lantern_ghost": "flame", "crystal_wisp": "reroll",
	"guard_die": "shield", "coin_mimic": "coin",
}
const PET_COLOR := {
	"pumpkin_sprite": Color("ff9a3a"), "skull_buddy": Color("efe6d4"), "lantern_ghost": Color("8fe0c8"),
	"crystal_wisp": Color("9ad8f0"), "guard_die": Color("5aa7ff"), "coin_mimic": Color("ffc93d"),
}
const ROLE_LABEL := {"heal": "Healer", "attack": "Striker", "burn": "Poisoner", "tempo": "Tempo",
	"defense": "Guardian", "economy": "Treasurer"}
const CHARGE_TEXT := {
	"pair_plus": "+1 per attack with a Pair or better",
	"low_die": "+1 per die showing 2 or less when you attack",
	"six": "+1 per 6 when you attack",
	"kept": "+1 per die you never rerolled, when you attack",
	"attack_intent": "+1 per enemy attack intent",
	"board_double": "+1 per board move with doubles",
}
const MINIGAME_ICON := {"fossil_hunter": "skull", "bubble_breaker": "star", "scratch_off": "coin", "claw_machine": "trophy",
	"bubble_shooter": "bolt", "plinko": "dice", "shell_game": "chest", "memory_match": "mirror", "fishing": "snowflake",
	"lucky_wheel": "crown", "high_low": "up"}
const MINIGAME_COLOR := {"fossil_hunter": Color("e0b070"), "bubble_breaker": Color("6fc8ff"),
	"scratch_off": Color("ffc93d"), "claw_machine": Color("ff6fae"), "bubble_shooter": Color("7f8cff"), "plinko": Color("5fe0c0"),
	"shell_game": Color("e08a4a"), "memory_match": Color("b58cff"), "fishing": Color("4ac0e8"), "lucky_wheel": Color("ff7a5a"),
	"high_low": Color("9ae05a")}
const GEAR_ICON := {"helm": "shield", "blade": "sword", "boots": "speed", "charm": "coin",
	"weapon": "sword", "offhand": "shield", "armor": "shield", "trinket": "coin"}
## Armory rank groups (the "gear" unlock kind since the real-item Armory).
const GROUP_NAME := {"weapon": "Weapon rank", "offhand": "Off-hand rank", "armor": "Armor rank", "trinket": "Trinket rank"}
const FEATURE_NAME := {"potion_belt": "Third Potion Slot", "loadout_slot": "Third Minigame Slot"}

## Camp stations in display order: id -> {name, icon, color, blurb}.
const STATIONS := {
	"armory": {"name": "Armory", "icon": "anvil", "color": Color("ff9a5a"), "blurb": "Gear and traits"},
	"workshop": {"name": "Dice Workshop", "icon": "dice", "color": Color("7ad0ff"), "blurb": "Packs and pools"},
	"pet_den": {"name": "Pet Den", "icon": "heart", "color": Color("ffb45a"), "blurb": "Familiars"},
	"arcade": {"name": "Arcade", "icon": "star", "color": Color("ff6fd0"), "blurb": "Minigames"},
}
const STATION_IDS := ["armory", "workshop", "pet_den", "arcade"]


static func name_of(kind: String, id: String) -> String:
	match kind:
		"classes":
			return String(HeroDefs.DATA[id].name) if HeroDefs.DATA.has(id) else id
		"biomes":
			return BiomeDefs.name_of(id)
		"bosses", "minibosses":
			return String(EnemyDefs.def(id).get("name", id))
		"pets":
			return PetDefs.name_of(id)
		"minigames":
			return MinigameDefs.name_of(id)
		"packs":
			return String(UnlockDefs.PACKS[id].name) if UnlockDefs.PACKS.has(id) else id
		"gear":
			return String(GROUP_NAME.get(id, GearDefs.name_of(id)))
		"potions":
			return PotionDefs.name_of(id)
		"features":
			return String(FEATURE_NAME.get(id, id))
	return id


static func icon_of(kind: String, id: String) -> String:
	match kind:
		"classes": return UiIcons.class_icon(id)
		"biomes": return UiIcons.biome_icon(id)
		"bosses": return "crown"
		"minibosses": return "skull"
		"pets": return String(PET_ICON.get(id, "heart"))
		"minigames": return String(MINIGAME_ICON.get(id, "star"))
		"packs": return "dice"
		"gear": return String(GEAR_ICON.get(id, "anvil"))
		"potions": return "potion"
		"features": return "plus"
	return "star"


static func color_of(kind: String, id: String) -> Color:
	match kind:
		"biomes": return UiPalette.biome_color(id)
		"pets": return PET_COLOR.get(id, UiPalette.GOLD)
		"minigames": return MINIGAME_COLOR.get(id, UiPalette.GOLD)
		"bosses", "minibosses": return UiPalette.DANGER.lightened(0.2)
		"classes": return UiPalette.GOLD_BRIGHT
	return UiPalette.GOLD


## The milestone that unlocks [kind, id], or {} (starter content / Sigils only).
static func milestone_for(kind: String, id: String) -> Dictionary:
	for m in UnlockDefs.MILESTONES:
		for u in m.unlocks:
			if String(u[0]) == kind and String(u[1]) == id:
				return m
	return {}


## How a locked thing unlocks: the milestone text, plus the Sigil price when it can be bought.
static func lock_text(kind: String, id: String, p: Profile = null) -> String:
	var m := milestone_for(kind, id)
	var parts := PackedStringArray()
	if not m.is_empty():
		parts.append(String(m.desc))
	var cost := UnlockDefs.sigil_cost(kind, id, p.unlocks.get("classes", []) if p != null else null)
	if not cost.is_empty():
		parts.append("or %d Sigils" % int(cost.sigils))
	return "  ".join(parts) if not parts.is_empty() else "Locked"


## [current, needed] toward a milestone condition ({stat, min} or {any: [...]}: best branch).
static func progress(p: Profile, cond: Dictionary) -> Array:
	return p.cond_progress(cond)


## Station lock state: {locked, text}. The Armory opens with the first gear piece, the Pet Den
## with the first pet; the Workshop and Arcade are open from the start.
static func station_state(p: Profile, id: String) -> Dictionary:
	match id:
		"armory":
			if (p.unlocks.get("gear", []) as Array).is_empty():
				return {"locked": true, "text": String(milestone_for("gear", "armor").get("desc", "Finish a run."))}
		"pet_den":
			if (p.unlocks.get("pets", []) as Array).is_empty():
				return {"locked": true, "text": String(milestone_for("pets", "pumpkin_sprite").get("desc", "Reach lap 5."))}
	return {"locked": false, "text": ""}


## Names of a milestone's rewards ("Barbarian", "Gambler's Kit + Boots").
static func rewards_text(m: Dictionary) -> String:
	var names := PackedStringArray()
	for u in m.get("unlocks", []):
		names.append(name_of(String(u[0]), String(u[1])))
	return " + ".join(names)


## Up to `n` goals the player is closest to: unmet milestones by progress ratio, plus the
## cheapest Crowns purchase not yet affordable. Each: {title, detail, cur, need, icon, color}.
static func nearest_goals(p: Profile, n := 3) -> Array:
	var goals: Array = []
	for m in UnlockDefs.MILESTONES:
		if p.milestones.has(m.id):
			continue
		var pr := progress(p, m.cond)
		if int(pr[0]) >= int(pr[1]):
			continue
		var first: Array = (m.unlocks as Array)[0]
		goals.append({"title": rewards_text(m), "detail": String(m.desc), "cur": int(pr[0]), "need": int(pr[1]),
			"icon": icon_of(String(first[0]), String(first[1])), "color": color_of(String(first[0]), String(first[1])),
			"ratio": float(pr[0]) / maxf(1.0, float(pr[1]))})
	goals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.ratio) > float(b.ratio))
	var out: Array = goals.slice(0, n)
	# one Crowns goal: the cheapest thing still out of reach (a near-miss, not a chore list)
	var cheapest := {}
	for item in Camp.new(p).catalog():
		var c := int((item.cost as Dictionary).get("crowns", 0))
		if c <= 0 or bool(item.affordable):
			continue
		if cheapest.is_empty() or c < int(cheapest.cost.crowns):
			cheapest = item
	if not cheapest.is_empty():
		var c := int(cheapest.cost.crowns)
		var title := String(cheapest.name)
		if String(cheapest.cmd[0]) in ["level_gear", "level_pet"]:
			title = "%s L%d" % [title, int(cheapest.level) + 1]
		var g := {"title": title, "detail": "%d Crowns short" % (c - p.crowns), "cur": p.crowns, "need": c,
			"icon": "crown", "color": UiPalette.GOLD, "ratio": float(p.crowns) / float(c)}
		if out.size() >= n:
			out[n - 1] = g
		else:
			out.append(g)
	return out


## Pet XP toward the next XP level: [xp into this level, xp span] (span 0 at XP level 5).
static func pet_xp_bar(p: Profile, id: String) -> Array:
	var xp := int(p.pet_xp.get(id, 0))
	var lvl := PetDefs.xp_level(xp)
	if lvl >= PetDefs.XP_LEVEL_MAX:
		return [0, 0]
	var lo := 0 if lvl <= 1 else int(PetDefs.XP_LEVELS[lvl - 2])
	var hi := int(PetDefs.XP_LEVELS[lvl - 1])
	return [xp - lo, hi - lo]


## Short gear stat line for a level ("+2 max HP", "-20% hazards · +1 reroll/biome").
static func gear_stat(slot: String, level: int) -> String:
	var s := GearDefs.stats({slot: level})
	match slot:
		"helm":
			return "+%d max HP" % int(s.max_hp)
		"blade":
			return "+%d ATK" % int(s.atk)
		"boots":
			var t := "-%d%% trap & lava damage" % int(round((1.0 - float(s.hazard_mult)) * 100.0))
			if int(s.lap_rerolls) > 0:
				t += "  ·  +1 reroll per biome"
			return t
		"charm":
			return "+%s%% gold" % _pct(float(s.gold_pct) * 100.0)
	return ""


static func _pct(v: float) -> String:
	return str(int(v)) if absf(v - round(v)) < 0.05 else "%.1f" % v
