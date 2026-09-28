class_name HeroDefs
extends RefCounted
## Class definitions. `runes` lists the rune of each starting die ("" = plain).

const DATA := {
	"knight": {"name": "Knight", "model": "knight", "hp": 64, "atk": 0, "runes": ["guard", ""], "board_rerolls": 1},
	"barbarian": {"name": "Barbarian", "model": "barbarian", "hp": 60, "atk": 2, "runes": ["heavy", ""], "board_rerolls": 1},
	"mage": {"name": "Mage", "model": "mage", "hp": 60, "atk": 0, "runes": ["ember", "echo"], "board_rerolls": 1},
	"rogue": {"name": "Rogue", "model": "rogue", "hp": 58, "atk": 0, "runes": ["venom", "lucky"], "board_rerolls": 2},
}

const IDS := ["knight", "barbarian", "mage", "rogue"]
