class_name UiPalette
extends RefCounted
## Colour palette for all UI. Warm gold on deep navy; semantic colours for stats.

# Surfaces
const INK := Color("0b0c1a")            # deepest background / outlines
const NAVY := Color("141630")           # panel base
const NAVY_2 := Color("1d2042")         # raised panel / card
const NAVY_3 := Color("2a2e5a")         # hover / inset highlight
const PANEL := Color(0.078, 0.086, 0.19, 0.92)
const PANEL_SOFT := Color(0.078, 0.086, 0.19, 0.78)
const SCRIM := Color(0.02, 0.02, 0.06, 0.62)
const OUTLINE := Color("1b1530")         # icon outline + text outline

# Gold accents
const GOLD := Color("f2b84b")
const GOLD_BRIGHT := Color("ffdc7a")
const GOLD_DEEP := Color("b8761f")
const GOLD_DARK := Color("6e4214")
const GOLD_LINE := Color(0.95, 0.72, 0.29, 0.85)
const GOLD_FAINT := Color(0.95, 0.72, 0.29, 0.28)

# Text
const TEXT := Color("fbf3e2")
const TEXT_DIM := Color("b7b0c8")
const TEXT_MUTED := Color("7d7896")
const TEXT_DARK := Color("2a1606")

# Semantic
const HP := Color("ea4b57")
const HP_BRIGHT := Color("ff7a7f")
const HP_DARK := Color("7a1c2a")
const HEAL := Color("5fd068")
const BLOCK := Color("5aa7ff")
const BLOCK_DARK := Color("1d4f96")
const XP := Color("b284ff")
const XP_DARK := Color("4b2a8a")
const COIN := Color("ffc93d")
const POISON := Color("7ad35a")
const FROST := Color("9ad8f0")
const CURSE := Color("b060e8")
const DANGER := Color("e8484f")
const DANGER_DARK := Color("8a1f2a")
const PRIMARY := Color("ffab32")
const PRIMARY_DARK := Color("b85a14")
const SECONDARY := Color("2f3470")
const SECONDARY_DARK := Color("161a42")
const DISABLED := Color("3a3b52")
const DISABLED_DARK := Color("22233a")

# Rarity frames
const COMMON := Color("aab4c8")
const RARE := Color("4aa8ff")
const EPIC := Color("c070ff")
const LEGENDARY := Color("ffb02e")

const RARITY := {"common": COMMON, "rare": RARE, "epic": EPIC}

## Die body colours.
const DIE_BODY := Color("f7efe0")
const DIE_EDGE := Color("c9b99a")
const DIE_PIP := Color("24193a")

## Intent kind -> [icon, colour]
const INTENT := {
	"attack": ["intent_attack", Color("ff6b5e")],
	"block": ["intent_block", BLOCK],
	"buff": ["intent_buff", Color("ffb43d")],
	"curse": ["intent_curse", CURSE],
	"summon": ["intent_summon", Color("b8e0d8")],
	"chaos": ["intent_chaos", Color("e060c8")],
	"aim": ["intent_aim", Color("c8c8d8")],
}


static func rune_color(rune: String) -> Color:
	if rune == "" or not Runes.DEFS.has(rune):
		return DIE_BODY
	return Color(String(Runes.DEFS[rune].color))


static func rarity_color(rarity: String) -> Color:
	return RARITY.get(rarity, COMMON)


## Readable text colour on top of `bg`.
static func on(bg: Color) -> Color:
	return TEXT_DARK if bg.get_luminance() > 0.55 else TEXT
