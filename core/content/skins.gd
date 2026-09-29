class_name SkinDefs
extends RefCounted
## Hero skins (docs/design/2026-09-28-classes-enemies-skins.md §4). Cosmetic only, never random,
## never sold for money. Every class has the same five slots:
##   default    owned with the class
##   victor     first win with the class (any mode)            cond {class_win: 1}
##   ascendant  a win with the class at A3+                     cond {class_asc: 3}
##   bossbane   4 different final bosses beaten with the class, or a win at A6+
##                                                              cond {class_bosses: 4, or_class_asc: 6}
##   prestige   a win at A10: an overlay on any equipped skin, never buyable
##                                                              cond {class_asc: 10, prestige: true}
## Non-prestige skins can also be bought for BUY_PRICE Crowns once the profile has maxed every
## Crowns sink (Profile.crowns_capped()). Presentation fields: texture (atlas name, "" = the
## model's own), mesh (a Character MODELS id override), helmet (Paladin helmet variant), overlay
## (prestige: "crown" = gold crown + trim, "statue" = golden-statue shader, "gold_turret").

const SLOTS := ["default", "victor", "ascendant", "bossbane", "prestige"]
const BUY_PRICE := 250
const BOSSES_FOR_BOSSBANE := 4

const NAMES := {"default": "Default", "victor": "Victor", "ascendant": "Ascendant", "bossbane": "Bossbane", "prestige": "Prestige"}

const CONDS := {
	"default": {},
	"victor": {"class_win": 1},
	"ascendant": {"class_asc": 3},
	"bossbane": {"class_bosses": BOSSES_FOR_BOSSBANE, "or_class_asc": 6},
	"prestige": {"class_asc": 10, "prestige": true},
}

## Per class, per slot: {texture, mesh?, helmet?, overlay?}.
const LOOKS := {
	"knight": {"default": {"texture": "knight_texture"}, "victor": {"texture": "knight_texture_alt_A"},
		"ascendant": {"texture": "knight_texture_alt_B"}, "bossbane": {"texture": "knight_texture_alt_C"}, "prestige": {"overlay": "crown"}},
	"barbarian": {"default": {"texture": "barbarian_texture"}, "victor": {"texture": "barbarian_texture_alt_A"},
		"ascendant": {"texture": "barbarian_texture_alt_B"}, "bossbane": {"texture": "barbarian_texture_alt_C"},
		"prestige": {"mesh": "barbarian_large", "overlay": "chieftain"}},
	"mage": {"default": {"texture": "mage_texture"}, "victor": {"texture": "mage_texture_alt_A"},
		"ascendant": {"texture": "mage_texture_alt_B"}, "bossbane": {"texture": "mage_texture_alt_C"}, "prestige": {"overlay": "crown"}},
	"rogue": {"default": {"texture": "rogue_texture"}, "victor": {"texture": "rogue_texture_alt_A"},
		"ascendant": {"texture": "rogue_texture_alt_B"}, "bossbane": {"texture": "rogue_texture_alt_C"},
		"prestige": {"mesh": "rogue_hooded", "overlay": "shade"}},
	"paladin": {"default": {"texture": "paladin_texture_A"}, "victor": {"texture": "paladin_texture_B"},
		"ascendant": {"texture": "paladin_texture_A", "helmet": true}, "bossbane": {"texture": "paladin_texture_B", "helmet": true},
		"prestige": {"overlay": "statue"}},
	"ranger": {"default": {"texture": "ranger_texture"}, "victor": {"texture": "ranger_texture_alt_A"},
		"ascendant": {"texture": "ranger_texture_alt_B"}, "bossbane": {"texture": "ranger_texture_alt_C"}, "prestige": {"overlay": "crown"}},
	"ninja": {"default": {"texture": "ninja_texture_A"}, "victor": {"texture": "ninja_texture_B"},
		"ascendant": {"texture": "ninja_texture_C"}, "bossbane": {"texture": "ninja_texture_D"}, "prestige": {"overlay": "crown"}},
	"druid": {"default": {"texture": "druid_texture"}, "victor": {"texture": "druid_texture_alt_A"},
		"ascendant": {"texture": "druid_texture_alt_B"}, "bossbane": {"texture": "druid_texture_alt_C"}, "prestige": {"overlay": "crown"}},
	"engineer": {"default": {"texture": "engineer_texture"}, "victor": {"texture": "engineer_texture_alt_A"},
		"ascendant": {"texture": "engineer_texture_alt_B"}, "bossbane": {"texture": "engineer_texture_alt_C"}, "prestige": {"overlay": "gold_turret"}},
	"necromancer": {"default": {"texture": "rogue_texture_alt_C"}, "victor": {"texture": "rogue_texture_alt_A"},
		"ascendant": {"texture": "rogue_texture_alt_B"}, "bossbane": {"texture": "rogue_texture"}, "prestige": {"overlay": "crown"}},
	"monster_kid": {"default": {"texture": "monstercostume_texture_A"}, "victor": {"texture": "monstercostume_texture_B"},
		"ascendant": {"texture": "monstercostume_texture_C"}, "bossbane": {"texture": "monstercostume_texture_D"},
		"prestige": {"overlay": "full_suit"}},
}

## Every skin of a class: [{id, name, texture, mesh, helmet, overlay, cond, prestige, buyable}].
static func of(class_id: String) -> Array:
	var out: Array = []
	var looks: Dictionary = LOOKS.get(class_id, {})
	for id in SLOTS:
		var l: Dictionary = looks.get(id, {})
		var cond: Dictionary = CONDS[id]
		out.append({"id": id, "name": NAMES[id], "texture": String(l.get("texture", "")), "mesh": String(l.get("mesh", "")),
			"helmet": bool(l.get("helmet", false)), "overlay": String(l.get("overlay", "")), "cond": cond.duplicate(),
			"prestige": bool(cond.get("prestige", false)), "buyable": id != "default" and not bool(cond.get("prestige", false))})
	return out

static func has(class_id: String, skin: String) -> bool:
	return LOOKS.has(class_id) and SLOTS.has(skin)

static func def(class_id: String, skin: String) -> Dictionary:
	for s in of(class_id):
		if s.id == skin:
			return s
	return {}

static func is_prestige(skin: String) -> bool:
	return bool(CONDS.get(skin, {}).get("prestige", false))

## Condition text for the Wardrobe lock ("Win with the Ranger at A3+").
static func cond_text(class_id: String, skin: String) -> String:
	var cname := String(HeroDefs.DATA[class_id].name) if HeroDefs.DATA.has(class_id) else class_id
	match skin:
		"victor":
			return "Win a run with the %s." % cname
		"ascendant":
			return "Win with the %s at Ascension 3+." % cname
		"bossbane":
			return "Beat 4 different final bosses with the %s (or win at Ascension 6+)." % cname
		"prestige":
			return "Win with the %s at Ascension 10." % cname
	return "Owned with the class."
