class_name CampInfo
extends RefCounted
## Read-only presentation helpers for the Camp and the results screen: display names and
## icons for every unlockable, the milestone that unlocks a thing, station lock states, and the
## "nearest goals" list (review §2.3 / §5.6). Everything reads core data; nothing mutates.

const KIND_LABEL := {
	"classes": "Class", "biomes": "Biome", "bosses": "Final boss", "minibosses": "Mini-boss", "pets": "Pet",
	"minigames": "Minigame", "packs": "Workshop pack", "gear": "Armory rank", "potions": "Potion",
	"features": "Camp upgrade", "items": "Armory item",
}

const PET_ICON := {
	"pumpkin_sprite": "heart", "skull_buddy": "skull", "lantern_ghost": "flame", "crystal_wisp": "reroll",
	"guard_die": "shield", "coin_mimic": "coin",
}
const PET_COLOR := {
	"pumpkin_sprite": Color("ff9a3a"), "skull_buddy": Color("efe6d4"), "lantern_ghost": Color("8fe0c8"),
	"crystal_wisp": Color("9ad8f0"), "guard_die": Color("5aa7ff"), "coin_mimic": Color("ffc93d"),
	"pebble_golem": Color("b8a890"), "frost_mote": Color("a8e4ff"), "wick": Color("ffb45a"),
	"tinker_gear": Color("d8b46a"), "grimoire": Color("b58cff"), "cauldron": Color("7fd08a"),
}
const ROLE_LABEL := {"heal": "Healer", "attack": "Striker", "burn": "Poisoner", "tempo": "Tempo",
	"defense": "Guardian", "economy": "Treasurer", "armor": "Bulwark", "control": "Controller", "burst": "Blaster",
	"fixing": "Fixer", "runes": "Runecaster", "sustain": "Brewer"}
const CHARGE_TEXT := {
	"pair_plus": "+1 per attack with a Pair or better",
	"low_die": "+1 per die showing 2 or less when you attack",
	"six": "+1 per 6 when you attack",
	"kept": "+1 per die you never rerolled, when you attack",
	"attack_intent": "+1 per enemy attack intent",
	"board_double": "+1 per board move with doubles",
	"block": "+1 per 3 Block you hold when you attack",
	"one": "+1 per die showing 1 when you attack",
	"set3": "+1 per attack with Three of a Kind or better",
	"reroll": "+1 per combat reroll",
	"rune": "+1 per attack where a rune triggers",
	"win": "+1 per fight won",
}
const MINIGAME_ICON := {"fossil_hunter": "skull", "bubble_breaker": "star", "scratch_off": "coin", "claw_machine": "trophy",
	"bubble_shooter": "bolt", "plinko": "dice", "shell_game": "chest", "memory_match": "mirror", "fishing": "snowflake",
	"lucky_wheel": "crown", "high_low": "up"}
const MINIGAME_COLOR := {"fossil_hunter": Color("e0b070"), "bubble_breaker": Color("6fc8ff"),
	"scratch_off": Color("ffc93d"), "claw_machine": Color("ff6fae"), "bubble_shooter": Color("7f8cff"), "plinko": Color("5fe0c0"),
	"shell_game": Color("e08a4a"), "memory_match": Color("b58cff"), "fishing": Color("4ac0e8"), "lucky_wheel": Color("ff7a5a"),
	"high_low": Color("9ae05a")}
const GEAR_ICON := {"weapon": "sword", "offhand": "shield", "armor": "armor", "trinket": "ring"}
## Glyph per Armory slot (items without a 3D thumbnail at hand).
const SLOT_ICON := {"weapon": "sword", "offhand": "shield", "head": "helmet", "body": "armor", "trinket": "ring",
	"trinket2": "pouch", "back": "cape"}
## Armory rank groups (the "gear" unlock kind since the real-item Armory).
const GROUP_NAME := {"weapon": "Weapon rank", "offhand": "Off-hand rank", "armor": "Armor rank", "trinket": "Trinket rank"}
const FEATURE_NAME := {"potion_belt": "Third Potion Slot", "loadout_slot": "Third Minigame Slot"}

## Camp stations in display order: id -> {name, icon, color, blurb}.
const STATIONS := {
	"armory": {"name": "Armory", "icon": "anvil", "color": Color("ff9a5a"), "blurb": "Weapons and armor"},
	"workshop": {"name": "Dice Workshop", "icon": "dice", "color": Color("7ad0ff"), "blurb": "Packs and pools"},
	"pet_den": {"name": "Pet Den", "icon": "heart", "color": Color("ffb45a"), "blurb": "Familiars"},
	"arcade": {"name": "Arcade", "icon": "star", "color": Color("ff6fd0"), "blurb": "Minigames"},
}
const STATION_IDS := ["armory", "workshop", "pet_den", "arcade"]

# ---------------------------------------------------------------- pack icon ids (UI reskin, d)
# The legacy tables above (PET_ICON, MINIGAME_ICON, SLOT_ICON, GEAR_ICON, icon_of) stay on the
# drawn glyphs for screens that still draw through UiIcons (results, OptionCard.Medallion);
# Camp screens draw these pack ids through CampArt (which falls back to the glyphs when the pack
# is absent). Every id below is mapped in ui/icons/icon_map.json (tests/test_camp_icons_d.gd).

## Station medallions (the Armory is the anvil: station != slot).
const STATION_ICON := {"armory": "station_armory", "workshop": "station_workshop", "pet_den": "station_pet_den",
	"arcade": "station_arcade", "wardrobe": "wardrobe_hats", "setup": "station_setup"}
## Pack glyph per pet (petg_*; the pet_* ids stay the in-run portraits).
const PET_GLYPH := {
	"pumpkin_sprite": "petg_pumpkin_sprite", "skull_buddy": "petg_skull_buddy", "lantern_ghost": "petg_lantern_ghost",
	"crystal_wisp": "petg_crystal_wisp", "guard_die": "petg_guard_die", "coin_mimic": "petg_coin_mimic",
	"pebble_golem": "petg_pebble_golem", "frost_mote": "petg_frost_mote", "wick": "petg_wick",
	"tinker_gear": "petg_tinker_gear", "grimoire": "petg_grimoire", "cauldron": "petg_cauldron",
}
const MINIGAME_GLYPH := {"fossil_hunter": "mg_fossil_hunter", "bubble_breaker": "mg_bubble_breaker",
	"scratch_off": "mg_scratch_off", "claw_machine": "mg_claw_machine", "bubble_shooter": "mg_bubble_shooter",
	"plinko": "mg_plinko", "shell_game": "mg_shell_game", "memory_match": "mg_memory_match", "fishing": "mg_fishing",
	"lucky_wheel": "mg_lucky_wheel", "high_low": "mg_high_low"}
## One icon per Workshop pack ("pack" = the generic unlock).
## Workshop packs: the build idea in one line (the Workshop card's description).
const PACK_BLURB := {
	"starter": "The core runes, dice and passives every run draws from.",
	"gamblers_kit": "Blank-or-six dice, banked rerolls and lucky streaks.",
	"cold_steel": "Freeze foes, start turns with Block and hit back.",
	"pyromancy": "Sixes that burn every enemy and huge opening hits.",
	"storm": "Rerolls that strike back and runes that add max HP.",
	"numerology": "Odd and even dice for straights and snake eyes.",
	"resonance": "Runes that trigger twice.",
	"colossus": "Giant dice, wild faces and boss-grade passives.",
}
const PACK_ICON := {"starter": "pack_starter", "gamblers_kit": "pack_gamblers_kit", "cold_steel": "pack_cold_steel",
	"pyromancy": "pack_pyromancy", "storm": "pack_storm", "numerology": "pack_numerology", "resonance": "pack_resonance",
	"colossus": "pack_colossus"}
const SLOT_GLYPH := {"weapon": "slot_weapon", "offhand": "slot_offhand", "head": "slot_head", "body": "slot_body",
	"trinket": "slot_trinket", "trinket2": "slot_trinket2", "back": "cape"}
## Armory rank groups reuse the slot glyphs (armor = the chestplate).
const GROUP_GLYPH := {"weapon": "slot_weapon", "offhand": "slot_offhand", "armor": "slot_body", "trinket": "slot_trinket"}
const UPGRADE_ICON := {"starter_kit": "upgrade_starter_kit", "whetstone": "upgrade_whetstone",
	"loadout_slot": "upgrade_loadout_slot", "potion_belt": "upgrade_potion_belt"}


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
			return String(GROUP_NAME.get(id, id))
		"items":
			return ItemDefs.name_of(id)
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
		"items": return String(SLOT_ICON.get(ItemDefs.slot_of(ItemDefs.base_of(id)), "anvil"))
		"potions": return "potion"
		"features": return "plus"
	return "star"


## Pack icon id for an unlockable (the icon_of retarget: bosses -> boss, packs -> pack_*,
## gear -> slot_*, features -> upgrade_*, potions -> potion_*, items -> item_icon).
static func glyph_of(kind: String, id: String) -> String:
	match kind:
		"classes": return Icons.class_icon(id)
		"biomes": return Icons.biome_icon(id)
		"bosses": return "boss"
		"minibosses": return "skull"
		"pets": return String(PET_GLYPH.get(id, "station_pet_den"))
		"minigames": return String(MINIGAME_GLYPH.get(id, "station_arcade"))
		"packs": return String(PACK_ICON.get(id, "pack"))
		"gear": return String(GROUP_GLYPH.get(id, "station_armory"))
		"items": return item_icon(id)
		"potions": return "potion_" + id if Icons.is_mapped("potion_" + id) else "potion"
		"features": return String(UPGRADE_ICON.get(id, "unlock_feature"))
	return "star"


## An item's pack glyph ("item_<base>") when the map has one, else its slot glyph.
static func item_icon(id: String) -> String:
	var base := ItemDefs.base_of(id)
	if Icons.is_mapped("item_" + base):
		return "item_" + base
	return String(SLOT_GLYPH.get(ItemDefs.slot_of(base), "station_armory"))


static func color_of(kind: String, id: String) -> Color:
	match kind:
		"biomes": return UiPalette.biome_color(id)
		"pets": return PET_COLOR.get(id, UiPalette.GOLD)
		"minigames": return MINIGAME_COLOR.get(id, UiPalette.GOLD)
		"bosses", "minibosses": return UiPalette.DANGER.lightened(0.2)
		"classes": return UiPalette.GOLD_BRIGHT
		"items", "gear": return Color("ff9a5a")
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
		if bool(m.get("hidden", false)):
			# a secret: only its hint, never what it unlocks
			goals.append({"title": "A secret", "detail": String(m.get("hint", "Keep exploring.")), "cur": int(pr[0]),
				"need": int(pr[1]), "icon": "question", "color": Color("c79bff"), "ratio": float(pr[0]) / maxf(1.0, float(pr[1]))})
			continue
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
		if String(cheapest.cmd[0]) == "rank_up":
			title = "%s %d" % [title, int(cheapest.level) + 1]
		elif String(cheapest.cmd[0]) == "level_pet":
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
