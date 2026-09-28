class_name ShopDefs
extends RefCounted
## Shop stock definitions. Weights control how often each kind appears in a stock roll.

const ITEMS := {
	"die": {"label": "New Die", "desc": "Add a plain die to your pool.", "needs_die": false, "weight": 3},
	"rune": {"label": "Rune", "desc": "", "needs_die": true, "weight": 4},
	"potion": {"label": "Potion", "desc": "Heal 35% of max HP.", "needs_die": false, "weight": 2},
	"face_raise": {"label": "Face Raise", "desc": "The lowest face of a die gets +1.", "needs_die": true, "weight": 2},
	"combat_reroll": {"label": "+1 Combat Reroll", "desc": "One more reroll every combat turn (once per act).", "needs_die": false, "weight": 1},
}
