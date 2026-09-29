class_name SkinRules
extends RefCounted
## What an enemy's look MEANS: the one table mapping gameplay facts to visuals, shared by the
## figures (EnemyLooks), the legend scenario (enemy_gallery --legend) and, later, a bestiary /
## tooltip UI. Core-driven modifiers extend it by adding a TRAITS entry (plus an overlay kind in
## EnemyLooks._trait_overlay) for each new rule.
##
## Layers, applied in this order over a family's base look (EnemyRoster.LOOKS):
##   1. cosmetic variant (EnemyRoster "variants": weapon / accessory / body swaps, picked per spawn
##      by hash so groups don't look cloned; never carries meaning)
##   2. tier: the lap band the fight belongs to (tier 1 = laps 1-5, 2 = 6-10, 3 = 11-15; the
##      board's biome tier). Each body model has an early / mid / late colourway (TIER_TEXTURES),
##      and late enemies are darkened with ember-red eyes, so a late minion outclasses an early one.
##   3. elite: gold-plated gear, gold eyes and a gold ring + motes at the feet (only elites).
##   4. traits: one overlay per trait, identical on every family (TRAITS).
##   5. affixes (core AffixDefs, §3A.5 of docs/design/2026-09-28-classes-enemies-skins.md):
##      body = how strong (layers 2-3), overlay = what rule. Each affix adds an eye colour, a
##      rim/emission accent and ONE prop on a fixed socket, plus a HUD badge (AFFIXES); it never
##      recolours the body. Trait-type affixes (armored, thorned, warded, piercing, frenzied) show
##      their trait's overlay as the prop, so the same rule always looks the same. Biome clash:
##      an affix whose colour is the biome's key colour (BIOME_CLASH) gets a +30% brighter rim.
## Mini-bosses and bosses keep their own unique colourways (layers 2 and 3 skip them); traits
## and affixes still show on them.

## Tier names (1-based), for labels and the legend.
const TIER_NAMES := ["", "early", "mid", "late"]
const TIER_DESC := ["",
	"Laps 1-5: the family's base colourway.",
	"Laps 6-10: the alternate colourway; tougher stats.",
	"Laps 11-15: a darkened colourway with ember-red eyes; the strongest regulars."]

const FOE := "res://assets/kaykit/foes/"
const ADT := FOE + "adventurers/textures/"
const SKIN_B := FOE + "skeletons/textures/skeleton_texture_B.png"

## Body model -> body texture per tier [early, mid, late] ("" = the model's own atlas).
## Adventurer bodies never use their default atlas (that is the player's hero look).
const TIER_TEXTURES := {
	"skel_minion": ["", SKIN_B, SKIN_B],
	"skel_warrior": ["", SKIN_B, SKIN_B],
	"skel_rogue": ["", SKIN_B, SKIN_B],
	"skel_mage": ["", SKIN_B, SKIN_B],
	"skel_golem": ["", SKIN_B, SKIN_B],
	"necromancer": ["", SKIN_B, SKIN_B],
	"orc": [FOE + "monthly/orc/textures/orc_texture_A.png", FOE + "monthly/orc/textures/orc_texture_B.png",
		FOE + "monthly/orc/textures/orc_texture_B.png"],
	"werewolf": [FOE + "monthly/werewolf/textures/werewolf_A.png", FOE + "monthly/werewolf/textures/werewolf_B.png",
		FOE + "monthly/werewolf/textures/werewolf_B.png"],
	# the Werewolf (transforming) keeps brown fur at every tier: the transform sells the menace;
	# its elites are the grey "Silverback" (ELITE_TEXTURES)
	"werewolf_man": [FOE + "monthly/werewolf/textures/werewolf_A.png", FOE + "monthly/werewolf/textures/werewolf_A.png",
		FOE + "monthly/werewolf/textures/werewolf_A.png"],
	# Fallen Paladin: the hero Paladin's dark atlas B under a heavy purple-black tint (hero skins
	# never read as enemy bodies)
	"paladin_helm": [FOE + "monthly/paladin/textures/paladin_texture_B.png", FOE + "monthly/paladin/textures/paladin_texture_B.png",
		FOE + "monthly/paladin/textures/paladin_texture_B.png"],
	"ninja": [FOE + "monthly/ninja/textures/ninja_texture_C.png", FOE + "monthly/ninja/textures/ninja_texture_B.png",
		FOE + "monthly/ninja/textures/ninja_texture_A.png"],
	"rogue_hooded": [ADT + "rogue_texture_alt_A.png", ADT + "rogue_texture_alt_B.png", ADT + "rogue_texture_alt_C.png"],
	"rogue": [ADT + "rogue_texture_alt_A.png", ADT + "rogue_texture_alt_B.png", ADT + "rogue_texture_alt_C.png"],
	"mage": [ADT + "mage_texture_alt_A.png", ADT + "mage_texture_alt_B.png", ADT + "mage_texture_alt_C.png"],
	"ranger": [ADT + "ranger_texture_alt_A.png", ADT + "ranger_texture_alt_B.png", ADT + "ranger_texture_alt_C.png"],
	"knight": [ADT + "knight_texture_alt_A.png", ADT + "knight_texture_alt_B.png", ADT + "knight_texture_alt_C.png"],
	"barbarian": [ADT + "barbarian_texture_alt_A.png", ADT + "barbarian_texture_alt_B.png", ADT + "barbarian_texture_alt_C.png"],
	"barbarian_large": [ADT + "barbarian_texture_alt_A.png", ADT + "barbarian_texture_alt_B.png", ADT + "barbarian_texture_alt_C.png"],
	"druid": [ADT + "druid_texture_alt_A.png", ADT + "druid_texture_alt_B.png", ADT + "druid_texture_alt_C.png"],
	"monster": [FOE + "monthly/monster/textures/monstercostume_texture_D.png",
		FOE + "monthly/monster/textures/monstercostume_texture_D.png",
		FOE + "monthly/monster/textures/monstercostume_texture_D.png"],
}
## Late tier: blend the body toward this (after the texture swap) and light the eyes ember-red.
const LATE_TINT := Color(0.16, 0.12, 0.14)
const LATE_TINT_STRENGTH := 0.55
const LATE_EYES := Color(1.0, 0.25, 0.12)
## Eye glow per tier for bodies with their own eye meshes (the skeletons): amber, teal, ember.
const TIER_EYES := [Color.BLACK, Color(1.0, 0.72, 0.28), Color(0.45, 0.9, 1.0), LATE_EYES]

## Elite: one language for every family.
const ELITE := {
	"label": "Elite", "desc": "Gold-plated weapons and shields, gold eyes, a gold ring at its feet. More HP and damage; drops a passive.",
	"gear_tint": Color(1.0, 0.76, 0.26), "gear_strength": 0.75, "gear_emission": Color(0.28, 0.16, 0.0),
	"eyes": Color(1.0, 0.85, 0.3), "ring": Color(1.0, 0.78, 0.25), "scale": 1.08,
}

## Elite body texture per tier key (over the tier colourway): the grey Silverback werewolf.
const ELITE_TEXTURES := {
	"werewolf_man": FOE + "monthly/werewolf/textures/werewolf_B.png",
}

## Traits (core/content/enemies.gd): each has ONE overlay, identical on every family.
##   overlay: armor = steel pauldrons + chest plate; thorns = bramble spikes on the back and arms +
##   a bramble ring; ward = a blue rune circle + orbiting blue glyph motes; pierce = crimson
##   spiked vambrace on the weapon arm and a red-hot weapon edge.
const TRAITS := {
	"armor": {"label": "Armored", "desc": "Steel pauldrons and chest plate: its Block never expires.",
		"color": Color(0.72, 0.76, 0.82)},
	"thorns": {"label": "Thorns", "desc": "Bramble spikes and a thorn ring: hitting it with your attack hurts you.",
		"color": Color(0.62, 0.2, 0.14)},
	"ward": {"label": "Warded", "desc": "Blue rune circle: takes half damage while any of its summons stand.",
		"color": Color(0.35, 0.65, 1.0)},
	"pierce": {"label": "Piercing", "desc": "Crimson spiked vambrace and a red-hot edge: its attacks ignore your Block.",
		"color": Color(1.0, 0.18, 0.12)},
	"frenzy": {"label": "Frenzy", "desc": "Steam from its head that thickens per stack: +2 attack each time it survives your attack (max +6).",
		"color": Color(1.0, 0.42, 0.18)},
	"ward_allies": {"label": "Warded", "desc": "A violet shimmer dome: half damage while any other non-warded enemy stands.",
		"color": Color(0.7, 0.45, 1.0)},
}

## Affixes (core AffixDefs): eye / rim colour, the prop (socket) and the HUD badge icon. `trait`:
## the core trait it grants (its trait overlay is the prop). Colours follow §3A.5.
const AFFIXES := {
	"armored": {"color": Color(0.6, 0.64, 0.72), "prop": "armor", "socket": "shoulders", "icon": "affix_armored", "trait": "armor"},
	"thorned": {"color": Color(0.46, 0.78, 0.3), "prop": "thorns", "socket": "feet", "icon": "affix_thorned", "trait": "thorns"},
	"warded": {"color": Color(0.7, 0.45, 1.0), "prop": "ward_dome", "socket": "body", "icon": "affix_warded", "trait": "ward_allies"},
	"piercing": {"color": Color(1.0, 0.22, 0.16), "prop": "pierce", "socket": "handslot.r", "icon": "affix_piercing", "trait": "pierce"},
	"frenzied": {"color": Color(1.0, 0.42, 0.14), "prop": "steam", "socket": "head", "icon": "affix_frenzied", "trait": "frenzy"},
	"regenerating": {"color": Color(0.55, 1.0, 0.45), "prop": "leaf_motes", "socket": "feet", "icon": "affix_regenerating"},
	"vampiric": {"color": Color(0.9, 0.08, 0.2), "prop": "blood_drips", "socket": "cape", "icon": "affix_vampiric"},
	"hexing": {"color": Color(0.72, 0.35, 1.0), "prop": "hex_circle", "socket": "head", "icon": "affix_hexing"},
	"frostbound": {"color": Color(0.55, 0.92, 1.0), "prop": "ice_weapon", "socket": "handslot.r", "icon": "affix_frostbound"},
	"gilded": {"color": Color(1.0, 0.8, 0.25), "prop": "coin_halo", "socket": "head", "icon": "affix_gilded"},
}
## Legend / tooltip text for each affix's look (the rule text comes from AffixDefs).
const AFFIX_LOOK := {
	"armored": "Slate rim + steel plates.", "thorned": "Moss-green rim + a bramble ring.",
	"warded": "Violet rim + a shimmer dome.", "piercing": "Red glint + a spiked vambrace.",
	"frenzied": "Orange eyes + steam that thickens per stack.", "regenerating": "Light-green eyes + rising leaf motes.",
	"vampiric": "Crimson eyes, a blood-red cape + drips.", "hexing": "Purple eyes + a rune circle over its head.",
	"frostbound": "Ice-cyan eyes + an ice-crystal weapon.", "gilded": "Gold eyes, gilded gear + a coin halo.",
}
## Biome clash: affixes whose colour is the biome's key colour. The prop carries the read and
## the rim is brightened by CLASH_BRIGHTEN.
const BIOME_CLASH := {"frost": ["frostbound"], "glade": ["thorned", "regenerating"]}
const CLASH_BRIGHTEN := 0.3
## Rim accent strength (fresnel emission on the body; never an albedo change).
const AFFIX_RIM := 0.6


## Tier (1..3) of a fight: the board biome's tier; `lap` (when known) wins.
static func tier_for(biome := "", lap := -1) -> int:
	if lap > 0:
		var t := 1
		for k in Balance.BIOME_LAPS.size():
			if lap >= int(Balance.BIOME_LAPS[k]):
				t = k + 1
		return clampi(t, 1, 3)
	if BiomeDefs.has(biome):
		return clampi(int(BiomeDefs.DEFS[biome].tier), 1, 3)
	return 1


## Eye / rim colour of affix `id` in `biome` (brightened on a biome clash).
static func affix_color(id: String, biome := "") -> Color:
	var c: Color = AFFIXES[id].color if AFFIXES.has(id) else Color.WHITE
	if id in (BIOME_CLASH.get(biome, []) as Array):
		c = c.lightened(CLASH_BRIGHTEN)
	return c


## True when affix `id` clashes with the biome's key colour.
static func clashes(id: String, biome: String) -> bool:
	return id in (BIOME_CLASH.get(biome, []) as Array)


## Traits granted by a list of affixes (their overlays are drawn by the affix layer).
static func affix_traits(affixes: Array) -> Array:
	var out := []
	for a in affixes:
		var t := String((AFFIXES.get(String(a), {}) as Dictionary).get("trait", ""))
		if t != "":
			out.append(t)
	return out


## Body texture for a model at a tier ("" = its own atlas, null = no entry: stylised bodies).
static func tier_texture(model: String, tier: int) -> Variant:
	if not TIER_TEXTURES.has(model):
		return null
	return String(TIER_TEXTURES[model][clampi(tier, 1, 3) - 1])


## Legend rows for a bestiary / the gallery: [{id, label, desc}] in display order.
static func legend() -> Array:
	var out := []
	for t in [1, 2, 3]:
		out.append({"id": "tier%d" % t, "label": String(TIER_NAMES[t]).capitalize(), "desc": TIER_DESC[t]})
	out.append({"id": "elite", "label": ELITE.label, "desc": ELITE.desc})
	for k in TRAITS:
		out.append({"id": k, "label": TRAITS[k].label, "desc": TRAITS[k].desc})
	for a in AFFIXES:
		out.append({"id": "affix_" + a, "affix": a, "label": AffixDefs.name_of(a),
			"desc": "%s  %s" % [String(AFFIX_LOOK.get(a, "")), String(AffixDefs.card(a).desc)], "icon": String(AFFIXES[a].icon),
			"color": AFFIXES[a].color})
	return out
