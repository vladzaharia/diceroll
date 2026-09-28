class_name EventDefs
extends RefCounted
## Board events (§8). Choice logic lives in GameFlow; this is the text.

const DATA := {
	"shrine": {"title": "Blessing Shrine", "text": "A quiet shrine hums with old power. It offers one blessing."},
	"duel": {"title": "Dice Duel", "text": "A grinning gambler rattles two dice. \"Highest sum doubles the bet.\""},
	"outbreak": {"title": "Monster Outbreak", "text": "Bones rattle in the dark. The road ahead fills with the dead."},
	"garden": {"title": "Flower Garden", "text": "Petals drift over the path. Treasure blooms on the road ahead."},
	"merchant": {"title": "Wandering Merchant", "text": "\"A rare rune, friend. It costs only a little of your life.\""},
	"idol": {"title": "Cursed Idol", "text": "The idol demands blood. In return, your dice grow stronger."},
}

const IDS := ["shrine", "duel", "outbreak", "garden", "merchant", "idol"]

## Shrine blessings (pick 2 of these at random).
const BLESSINGS := {
	"atk": {"label": "+1 ATK", "desc": "Permanently deal +1 damage per attack."},
	"max_hp": {"label": "+10 Max HP", "desc": "Gain 10 max HP and heal 10."},
	"gold": {"label": "+15 Gold", "desc": "A small offering, returned."},
	"face": {"label": "Upgrade a Face", "desc": "A random face on a random die gets +1."},
}
