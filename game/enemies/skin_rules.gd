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
## Mini-bosses and bosses keep their own unique colourways (layers 2 and 3 skip them); traits
## still show on them.

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
}


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
	return out
