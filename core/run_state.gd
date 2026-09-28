class_name RunState
extends RefCounted
## All persistent run data (hero, pool, economy, position, board).

var class_id: String = "knight"
var seed: int = 0
var rng: Rng
var hp: int = 1
var max_hp: int = 1
var atk: int = 0
var block: int = 0
var gold: int = 0
var xp: int = 0
var level: int = 1
var dice: Array[Die] = []
var combat_rerolls: int = Balance.COMBAT_REROLLS
var board_rerolls: int = 1
var banked_rerolls: int = 0
var act: int = 1
var lap: int = 1
var pos: int = 0
var board: Board
var treasury: int = Balance.TREASURY_START
var stats: Dictionary = {}
## Extra: whether the +1 combat reroll shop item was bought this act.
var shop_reroll_bought: bool = false

static func create(p_class_id: String, p_seed: int) -> RunState:
	var r := RunState.new()
	var def: Dictionary = HeroDefs.DATA[p_class_id]
	r.class_id = p_class_id
	r.seed = p_seed
	r.rng = Rng.new(p_seed)
	r.max_hp = int(def.hp)
	r.hp = r.max_hp
	r.atk = int(def.atk)
	r.board_rerolls = int(def.board_rerolls)
	for rune_id in def.runes:
		r.dice.append(Die.make(String(rune_id)))
	r.board = Board.generate(r.rng, 1)
	r.stats = {
		"board_turns": 0, "combat_turns": 0, "fights_won": 0, "damage_dealt": 0, "damage_taken": 0,
		"gold_earned": 0, "best_combo": "", "best_mult": 0.0, "max_act": 1, "commands": 0,
	}
	return r

## Heals up to max; returns the amount actually healed.
func heal(amount: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + maxi(0, amount))
	return hp - before

func pct_of_max(p: float) -> int:
	return maxi(1, int(round(max_hp * p)))

func dice_with_rune(rune_id: String) -> Array[int]:
	var out: Array[int] = []
	for i in dice.size():
		if dice[i].rune == rune_id:
			out.append(i)
	return out

func to_dict() -> Dictionary:
	var dd: Array = []
	for d in dice:
		dd.append(d.to_dict())
	return {
		"class_id": class_id, "seed": str(seed), "rng": rng.to_dict(), "hp": hp, "max_hp": max_hp,
		"atk": atk, "block": block, "gold": gold, "xp": xp, "level": level, "dice": dd,
		"combat_rerolls": combat_rerolls, "board_rerolls": board_rerolls, "banked_rerolls": banked_rerolls,
		"act": act, "lap": lap, "pos": pos, "board": board.to_dict(), "treasury": treasury,
		"stats": stats.duplicate(true), "shop_reroll_bought": shop_reroll_bought,
	}

static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new()
	r.class_id = String(d.class_id)
	r.seed = String(d.seed).to_int()
	r.rng = Rng.from_dict(d.rng)
	for k in ["hp", "max_hp", "atk", "block", "gold", "xp", "level", "combat_rerolls", "board_rerolls",
			"banked_rerolls", "act", "lap", "pos", "treasury"]:
		r.set(k, int(d[k]))
	r.dice.clear()
	for dd in d.dice:
		r.dice.append(Die.from_dict(dd))
	r.board = Board.from_dict(d.board)
	r.stats = {}
	var st: Dictionary = d.get("stats", {})
	for k in st:
		var v: Variant = st[k]
		if k == "best_mult":
			r.stats[k] = float(v)
		elif v is float:
			r.stats[k] = int(v)
		else:
			r.stats[k] = v
	r.shop_reroll_bought = bool(d.get("shop_reroll_bought", false))
	return r
