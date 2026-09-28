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
## Ring size of every board in this run (24 or 32).
var board_size: int = Balance.BOARD_SIZE
var treasury: int = Balance.TREASURY_START
var stats: Dictionary = {}
## Extra: whether the +1 combat reroll shop item was bought this act.
var shop_reroll_bought: bool = false
## Owned passive ids (Passives.DEFS), in pickup order.
var passives: Array[String] = []
## Passive bookkeeping: second_wind_used:bool, phoenix_act:int (act the feather was spent in).
var passive_state: Dictionary = {}
## Biome per tier (BiomeDefs ids), picked at run start: [tier1, tier2, tier3].
var route: Array[String] = []
## Lap-7 mini-boss and lap-15 final boss, picked at run start from the route's candidates.
var miniboss_id: String = "mini_pumpkin_knight"
var boss_id: String = "boss_lich"
## Dice frozen by Frostpeak ice: they lock on turn 1 of the next fight.
var chill: int = 0

## opts (all optional, for scenarios/tests): route:[tier1, tier2, tier3], miniboss:id, boss:id.
## The route and bosses are always drawn from the run Rng first, so forcing them does not shift
## the rest of the random stream. Invalid overrides are ignored.
static func create(p_class_id: String, p_seed: int, p_board_size: int = Balance.BOARD_SIZE, opts: Dictionary = {}) -> RunState:
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
	r.board_size = p_board_size
	r.route = BiomeDefs.pick_route(r.rng)
	var forced: Array = opts.get("route", [])
	if BiomeDefs.valid_route(forced):
		r.route.assign(forced.map(func(x): return String(x)))
	r.miniboss_id = String(r.rng.pick(BiomeDefs.miniboss_candidates(r.route)))
	r.boss_id = String(r.rng.pick(BiomeDefs.boss_candidates(r.route)))
	var fm := String(opts.get("miniboss", ""))
	if EnemyDefs.MINIBOSSES.has(fm):
		r.miniboss_id = fm
	var fb := String(opts.get("boss", ""))
	if EnemyDefs.BOSSES.has(fb):
		r.boss_id = fb
	r.board = Board.generate(r.rng, 1, r.board_size, 1, r.route[0])
	r.stats = {
		"board_turns": 0, "combat_turns": 0, "fights_won": 0, "damage_dealt": 0, "damage_taken": 0,
		"gold_earned": 0, "best_combo": "", "best_mult": 0.0, "max_act": 1, "commands": 0,
	}
	return r

func has_passive(id: String) -> bool:
	return passives.has(id)

## Current biome id (the route's entry for the current act).
func biome() -> String:
	return route[clampi(act - 1, 0, route.size() - 1)]

## Pool cap: MAX_DICE, +1 with Extra Hand.
func max_dice() -> int:
	return Balance.MAX_DICE + (1 if has_passive("extra_hand") else 0)

## Called when a hit would drop HP to 0 or below: Phoenix Feather (once per act) then Second
## Wind (once per run) leave the hero at 1 HP. Returns the passive that saved them, or "".
func survive_lethal() -> String:
	if has_passive("phoenix") and int(passive_state.get("phoenix_act", 0)) != act:
		passive_state["phoenix_act"] = act
		hp = 1
		return "phoenix"
	if has_passive("second_wind") and not bool(passive_state.get("second_wind_used", false)):
		passive_state["second_wind_used"] = true
		hp = 1
		return "second_wind"
	return ""

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
		"act": act, "lap": lap, "pos": pos, "board": board.to_dict(), "board_size": board_size, "treasury": treasury,
		"stats": stats.duplicate(true), "shop_reroll_bought": shop_reroll_bought,
		"passives": Array(passives), "passive_state": passive_state.duplicate(true),
		"route": Array(route), "miniboss_id": miniboss_id, "boss_id": boss_id, "chill": chill,
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
	r.board_size = int(d.get("board_size", r.board.size()))
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
	for p in d.get("passives", []):
		r.passives.append(String(p))
	# Saves from before biome routes get the legacy route and bosses.
	r.route.clear()
	for b in d.get("route", BiomeDefs.DEFAULT_ROUTE):
		r.route.append(String(b))
	r.miniboss_id = String(d.get("miniboss_id", "mini_pumpkin_knight"))
	r.boss_id = String(d.get("boss_id", EnemyDefs.FINAL_BOSS))
	r.chill = int(d.get("chill", 0))
	var ps: Dictionary = d.get("passive_state", {})
	for k in ps:
		var v: Variant = ps[k]
		r.passive_state[k] = int(v) if v is float else v
	return r
