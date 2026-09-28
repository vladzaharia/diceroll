class_name Bot
extends RefCounted
## Autoplayers. next_command() is the greedy bot used by the balance sim (the balance
## reference) and the play_auto scenario: a pure function of the flow state (no randomness of
## its own). decide(flow, rules) is the player-facing AUTO policy (see "AUTO policy" below).
## Both return commands in GameFlow.apply() format: [name, args...].

const RUNE_SCORE := {
	"echo": 9, "wild": 9, "vampire": 7, "ember": 7, "blade": 6, "heavy": 6, "venom": 6,
	"thunder": 5, "lucky": 5, "frost": 5, "guard": 5, "gilded": 3,
}

## How much the bot wants a new die of each kind.
const KIND_SCORE := {
	"giant": 10, "high": 9, "twin": 7, "gambler": 6, "loaded": 7, "even": 7, "standard": 6, "odd": 5, "low": 4,
}

## How much the bot wants each passive.
const PASSIVE_SCORE := {
	"pair_master": 7, "full_house_party": 4, "straight_shooter": 5, "triple_threat": 7, "snake_eyes": 5,
	"boxcars": 6, "gold_tooth": 4, "steady_hand": 6, "loaded_hands": 5, "double_trouble": 4, "rune_echo": 6,
	"collector": 5, "pathfinder": 3, "treasure_sense": 3, "piggy_bank": 3, "haggler": 4, "scholar": 4,
	"blacksmith": 4, "thorns": 5, "iron_skin": 6, "bloodthirst": 5, "opening_salvo": 6, "second_wind": 7,
	"glass_cannon": 7,
	"extra_hand": 10, "crowd_pleaser": 10, "encore": 8, "rune_bloom": 9, "fast_feet": 6, "resonance": 10,
	"phoenix": 9, "midas_fist": 8,
}

static func next_command(f: GameFlow) -> Array:
	match f.phase:
		GameFlow.Phase.BOARD_READY:
			return ["roll_board"]
		GameFlow.Phase.BOARD_ROLLED:
			return _board(f)
		GameFlow.Phase.COMBAT:
			return _combat(f)
		GameFlow.Phase.DRAFT:
			if f.offer.kind == "rune_assign":
				return ["rune_assign", _die_for_rune(f, String(f.offer.rune))]
			return ["pick_draft", _best_draft(f)]
		GameFlow.Phase.SHOP:
			return _shop(f)
		GameFlow.Phase.FORGE:
			return _forge(f)
		GameFlow.Phase.EVENT:
			return ["event_choose", _event(f)]
		GameFlow.Phase.PORTAL:
			var best := -1
			var best_s := -INF
			for t in f.offer.tiles:
				var s := tile_score(f, int(t), int(t) < f.run.pos)
				if s > best_s:
					best_s = s
					best = int(t)
			return ["portal_pick", best]
	return ["roll_board"]

static func hp_ratio(f: GameFlow) -> float:
	return float(f.run.hp) / float(f.run.max_hp)

## Heuristic value of landing on tile idx.
static func tile_score(f: GameFlow, idx: int, crossing: bool) -> float:
	var r := hp_ratio(f)
	var t: Dictionary = f.run.board.tiles[idx]
	var s := 0.0
	match String(t.type):
		"enemy":
			if t.enemies.is_empty():
				s = 0.0
			elif r >= 0.6:
				s = 4.0
			elif r >= 0.35:
				s = 1.0
			else:
				s = -6.0
		"elite":
			if t.enemies.is_empty():
				s = 0.0
			elif r >= 0.75:
				s = 6.0
			else:
				s = -8.0
		"miniboss":
			if t.enemies.is_empty():
				s = 0.0
			elif r > 0.6:
				s = 7.0
			else:
				s = -9.0
		"chest":
			s = 5.0
		"event":
			s = 3.0
		"campfire":
			s = (1.0 - r) * 14.0
		"trap":
			s = -3.0
		"ice":
			s = -1.5
		"lava":
			s = -5.0
		"forge":
			s = 4.0
		"treasury":
			s = f.run.treasury / 4.0
		"portal":
			s = 2.0
		"start":
			s = 3.0
	if crossing and f.run.lap < Balance.TOTAL_LAPS:
		s += 3.0
	return s

## The move is automatic; the only choice is reroll-or-go.
static func _board(f: GameFlow) -> Array:
	var crossing := f.run.board.crosses_start(f.run.pos, f.board_move)
	var s := 0.0 if f.board_move <= 0 else tile_score(f, f.board_target(), crossing)
	if s < 1.0 and f.board_rerolls_left > 0:
		return ["board_reroll"]
	return ["confirm_move"]

static func _combat(f: GameFlow) -> Array:
	var c := f.combat
	# focus the weakest living enemy
	var tgt := c.target
	var low := 1 << 30
	for i in c.enemies.size():
		if c.alive(i) and int(c.enemies[i].hp) < low:
			low = int(c.enemies[i].hp)
			tgt = i
	if tgt != c.target:
		return ["combat_set_target", tgt]
	var want: Array[bool] = []
	want.resize(c.dice_values.size())
	want.fill(false)
	if c.rerolls_left > 0:
		var combo := c.current_combo(f.run)
		if float(combo.mult) < 3.0:
			var group: Array = combo.group
			var keep_hi: bool = combo.id == "high_roller"
			for i in c.dice_values.size():
				if c.locked[i] or group.has(i):
					continue
				if keep_hi and c.dice_values[i] >= 5:
					continue
				if f.run.dice[i].rune == "wild":
					continue
				want[i] = true
	for i in want.size():
		if want[i] != c.marked[i]:
			return ["combat_toggle", i]
	for m in c.marked:
		if m:
			return ["combat_reroll"]
	return ["combat_attack"]

static func _draft_score(f: GameFlow, o: Dictionary) -> float:
	match String(o.id):
		"new_die":
			return 9.0 + float(KIND_SCORE.get(String(o.get("kind", "standard")), 6)) / 5.0
		"rune":
			return float(RUNE_SCORE.get(String(o.get("rune", "")), 4))
		"combat_reroll":
			return 8.0
		"max_hp":
			return 4.0 + (4.0 if hp_ratio(f) < 0.5 else 0.0)
		"face_raise":
			return 3.0
	if Passives.DEFS.has(String(o.id)):
		return float(PASSIVE_SCORE.get(String(o.id), 4))
	return 0.0

static func _best_draft(f: GameFlow) -> int:
	var best := 0
	var best_s := -INF
	for i in f.offer.options.size():
		var s := _draft_score(f, f.offer.options[i])
		if s > best_s:
			best_s = s
			best = i
	return best

static func _die_for_rune(f: GameFlow, _rune: String) -> int:
	var best := 0
	var best_s := INF
	for i in f.run.dice.size():
		var r := f.run.dice[i].rune
		var s := 0.0 if r == "" else float(RUNE_SCORE.get(r, 4))
		if s < best_s:
			best_s = s
			best = i
	return best

static func _shop(f: GameFlow) -> Array:
	var best := -1
	var best_s := 0.0
	var has_free := false
	for d in f.run.dice:
		if d.rune == "":
			has_free = true
	for i in f.offer.items.size():
		var it: Dictionary = f.offer.items[i]
		if it.sold or int(it.price) > f.run.gold:
			continue
		var s := 0.0
		match String(it.id):
			"potion":
				s = 9.0 if hp_ratio(f) < 0.55 else 0.0
			"die":
				s = (8.0 + float(KIND_SCORE.get(String(it.get("kind", "standard")), 6)) / 5.0) if f.run.dice.size() < f.run.max_dice() else 0.0
			"rune":
				var rs := float(RUNE_SCORE.get(String(it.rune), 4))
				var target := _die_for_rune(f, String(it.rune))
				var cur := f.run.dice[target].rune
				var cur_s := 0.0 if cur == "" else float(RUNE_SCORE.get(cur, 4))
				s = rs - cur_s if (has_free or rs > cur_s) else 0.0
			"combat_reroll":
				s = 7.0
			"face_raise":
				s = 2.0
			"passive":
				s = float(PASSIVE_SCORE.get(String(it.passive), 4)) + 1.0
		if s > best_s:
			best_s = s
			best = i
	if best >= 0:
		var it: Dictionary = f.offer.items[best]
		var die_idx := -1
		if it.needs_die:
			if it.id == "rune":
				die_idx = _die_for_rune(f, String(it.rune))
			else:
				die_idx = _lowest_die(f)
			if die_idx < 0:
				return ["shop_leave"]
		return ["shop_buy", best, die_idx]
	return ["shop_leave"]

## Die whose lowest face is lowest (and below 6).
static func _lowest_die(f: GameFlow) -> int:
	var best := -1
	var best_v := 6
	for i in f.run.dice.size():
		var d := f.run.dice[i]
		var v := d.faces[d.lowest_face()]
		if v < best_v:
			best_v = v
			best = i
	return best

static func _forge(f: GameFlow) -> Array:
	var ops: Array = f.offer.get("ops", ["raise"])
	var d := _lowest_die(f)
	if d < 0:
		return ["forge_apply", 0, 0, "skip", -1]
	var die := f.run.dice[d]
	var lo := die.lowest_face()
	if ops.has("mirror"):
		var hi := 0
		for k in 6:
			if die.faces[k] > die.faces[hi]:
				hi = k
		if die.faces[hi] - die.faces[lo] > 1:
			return ["forge_apply", d, lo, "mirror", hi]
	return ["forge_apply", d, lo, "raise", -1]

static func _event(f: GameFlow) -> int:
	var ch: Array = f.offer.choices
	match String(f.offer.id):
		"duel":
			return 2
		"merchant":
			return 0 if ch[0].enabled and hp_ratio(f) > 0.6 and f.run.max_hp > 45 else 1
		"idol":
			return 0 if ch[0].enabled and f.run.hp > 40 else 1
		"shrine":
			var best := 0
			var best_s := -1.0
			for i in ch.size():
				var sc := 5.0 if ch[i].get("blessing", "") == "atk" else 3.0
				if ch[i].has("passive"):
					sc = float(PASSIVE_SCORE.get(String(ch[i].passive), 4))
				if sc > best_s:
					best_s = sc
					best = i
			return best
		"dicesmith":
			if f.run.dice.size() < f.run.max_dice() or ch[0].kind in ["giant", "high", "twin"]:
				return 0 if float(KIND_SCORE.get(String(ch[0].kind), 5)) >= float(KIND_SCORE.get(String(ch[1].kind), 5)) else 1
			return 2
	for i in ch.size():
		if ch[i].enabled:
			return i
	return 0

# =============================================================================== AUTO policy
## Player-facing AUTO (spec §15): decide(flow, rules) returns ONE step
## {cmd: Array, reason: String, stop: bool, stop_reason: String}. stop:true hands control back
## (cmd is then []). All scoring is in "PV points": about one damage per combat turn for the
## rest of the run (see _pool_value). It never mutates the flow and never touches the run's Rng:
## every sample comes from a private Rng seeded from a hash of the relevant state.

enum { R_NONE, R_BLADE, R_GUARD, R_VENOM, R_GILDED, R_HEAVY, R_EMBER, R_VAMPIRE, R_LUCKY, R_FROST, R_THUNDER, R_ECHO, R_WILD }
const RUNE_CODE := {"": R_NONE, "blade": R_BLADE, "guard": R_GUARD, "venom": R_VENOM, "gilded": R_GILDED,
	"heavy": R_HEAVY, "ember": R_EMBER, "vampire": R_VAMPIRE, "lucky": R_LUCKY, "frost": R_FROST,
	"thunder": R_THUNDER, "echo": R_ECHO, "wild": R_WILD}
## Combo id codes for the hot loop.
enum { C_HIGH, C_PAIR, C_TWO_PAIR, C_SET, C_STRAIGHT, C_FULL }
const COMBO_CODE := {"high_roller": C_HIGH, "pair": C_PAIR, "two_pair": C_TWO_PAIR, "three_kind": C_SET,
	"four_kind": C_SET, "five_kind": C_SET, "six_kind": C_SET, "straight": C_STRAIGHT,
	"small_straight": C_STRAIGHT, "full_house": C_FULL}

## Per-focus weights: dmg scales damage items, def the worth of HP/Block, econ the worth of gold.
## pref multiplies draft/shop/passive values of the matching category.
const FOCUS := {
	"balanced": {"dmg": 1.0, "def": 1.3, "econ": 1.0, "pref": {"dmg": 1.0, "def": 1.2, "econ": 0.9}},
	"damage": {"dmg": 1.25, "def": 0.8, "econ": 0.8, "pref": {"dmg": 1.5, "def": 0.7, "econ": 0.6}},
	"defense": {"dmg": 0.9, "def": 1.5, "econ": 0.8, "pref": {"dmg": 0.8, "def": 1.6, "econ": 0.6}},
	"economy": {"dmg": 0.95, "def": 0.9, "econ": 1.8, "pref": {"dmg": 0.85, "def": 0.85, "econ": 2.2}},
}
const RUNE_CAT := {"blade": "dmg", "heavy": "dmg", "echo": "dmg", "wild": "dmg", "ember": "dmg", "thunder": "dmg",
	"venom": "dmg", "lucky": "dmg", "guard": "def", "vampire": "def", "frost": "def", "gilded": "econ"}
const PASSIVE_CAT := {
	"pair_master": "dmg", "full_house_party": "def", "straight_shooter": "dmg", "triple_threat": "dmg",
	"snake_eyes": "dmg", "boxcars": "dmg", "gold_tooth": "econ", "steady_hand": "dmg", "loaded_hands": "dmg",
	"double_trouble": "dmg", "rune_echo": "dmg", "collector": "def", "pathfinder": "econ",
	"treasure_sense": "econ", "piggy_bank": "econ", "haggler": "econ", "scholar": "econ", "blacksmith": "dmg",
	"thorns": "def", "iron_skin": "def", "bloodthirst": "def", "opening_salvo": "dmg", "second_wind": "def",
	"glass_cannon": "dmg", "extra_hand": "dmg", "crowd_pleaser": "dmg", "encore": "dmg", "rune_bloom": "dmg",
	"fast_feet": "econ", "resonance": "dmg", "phoenix": "def", "midas_fist": "econ",
}
## Passives whose effect the combat model simulates (value = pool value gained).
const MODELLED_PASSIVES := ["pair_master", "crowd_pleaser", "triple_threat", "straight_shooter", "snake_eyes",
	"boxcars", "steady_hand", "glass_cannon", "midas_fist", "resonance", "rune_echo", "full_house_party",
	"gold_tooth", "iron_skin", "opening_salvo"]

## Combat search budget: exact enumeration up to EXACT_MAX outcomes per keep-set, otherwise
## MC_SAMPLES common-random-number samples (fewer with 6 dice).
const EXACT_MAX := 36
const MC_SAMPLES := 96
const MC_SAMPLES_6 := 64
## Pool value samples (single roll).
const PV_SAMPLES := 120
## Board reroll lookahead samples.
const BOARD_SAMPLES := 96
## Worth of a whole run in PV points (death penalties).
const RUN_VALUE := 30.0

static var _combo_cache := {}
static var _fixed_cache := {}
static var _plan_cache := {}
static var _pv_cache := {}
static var _pv_samples := PackedInt32Array()

## Drops the memo caches (tests; decisions do not depend on them).
static func clear_cache() -> void:
	_combo_cache.clear()
	_fixed_cache.clear()
	_plan_cache.clear()
	_pv_cache.clear()

static func _result(cmd: Array, reason: String) -> Dictionary:
	return {"cmd": cmd, "reason": reason, "stop": false, "stop_reason": ""}

static func _stop(why: String) -> Dictionary:
	return {"cmd": [], "reason": "", "stop": true, "stop_reason": why}

static func _fw(rules: AutoRules) -> Dictionary:
	return FOCUS.get(rules.focus, FOCUS.balanced)

## One AUTO step for the current phase under `rules` (null = defaults). See the section header.
static func decide(f: GameFlow, rules: AutoRules = null) -> Dictionary:
	if rules == null:
		rules = AutoRules.new()
	if f.is_over():
		return _stop("The run is over.")
	var low := rules.stop_hp_below > 0.0 and hp_ratio(f) < rules.stop_hp_below
	var low_msg := "HP is below %d%%." % int(round(rules.stop_hp_below * 100.0))
	match f.phase:
		GameFlow.Phase.BOARD_READY:
			if not rules.board:
				return _stop("AUTO board moves are off.")
			if low:
				return _stop(low_msg)
			return _result(["roll_board"], "Rolling to move")
		GameFlow.Phase.BOARD_ROLLED:
			if not rules.board:
				return _stop("AUTO board moves are off.")
			if low:
				return _stop(low_msg)
			return _decide_board(f, rules)
		GameFlow.Phase.COMBAT:
			if not rules.combat:
				return _stop("AUTO combat is off.")
			if low:
				return _stop(low_msg)
			return _decide_combat(f, rules)
		GameFlow.Phase.DRAFT:
			if f.offer.kind == "passive" and rules.stop_on_boss_passive:
				for o in f.offer.options:
					if String(o.get("rarity", "")) == "boss":
						return _stop("A boss passive is on offer: your pick.")
			if not rules.drafts:
				return _stop("AUTO drafts are off.")
			if f.offer.kind == "rune_assign":
				return _decide_rune_assign(f, rules)
			return _decide_draft(f, rules)
		GameFlow.Phase.SHOP:
			if not rules.shop:
				if rules.stop_on_shop:
					return _stop("Shop: your call.")
				return _result(["shop_leave"], "AUTO shopping is off: leaving the shop")
			return _decide_shop(f, rules)
		GameFlow.Phase.FORGE:
			if not rules.forge:
				return _stop("AUTO forge is off.")
			return _decide_forge(f, rules)
		GameFlow.Phase.EVENT:
			if not rules.events:
				return _stop("AUTO events are off.")
			return _decide_event(f, rules)
		GameFlow.Phase.PORTAL:
			if not rules.portal:
				return _stop("AUTO portal jumps are off.")
			return _decide_portal(f, rules)
	return _stop("Nothing to do.")

# ------------------------------------------------------------------------------ combo memo

## Cached combo as [base_mult, group_mask, eff_values, combo_code, id]. Same result as
## Combo.evaluate (tests/test_bot_combat.gd checks it on random hands), about 4x faster.
static func _combo(vals: PackedInt32Array, wild_mask: int) -> Array:
	var n := vals.size()
	var key := wild_mask
	for i in n:
		# a Wild die's own face never matters (it is replaced), so it is not part of the key
		key = key * 10 + (0 if (wild_mask >> i) & 1 else vals[i])
	key = key * 8 + n
	var hit: Variant = _combo_cache.get(key)
	if hit != null:
		return hit
	var out: Array
	if wild_mask == 0:
		out = _eval_fixed(vals, n)
		out[2] = vals.duplicate()
	else:
		# Wild dice: every non-decreasing assignment of 1..WILD_MAX (first best wins), then a
		# Wild outside the scoring group shows WILD_MAX.
		var widx: Array[int] = []
		for i in n:
			if (wild_mask >> i) & 1:
				widx.append(i)
		var assign := PackedInt32Array()
		assign.resize(widx.size())
		assign.fill(1)
		var v := vals.duplicate()
		var best: Array = []
		var best_vals := PackedInt32Array()
		while true:
			for k in widx.size():
				v[widx[k]] = assign[k]
			var fk := 0
			for i in n:
				fk = fk * 10 + v[i]
			fk = fk * 8 + n
			var c: Array = _fixed_cache.get(fk, [])
			if c.is_empty():
				c = _eval_fixed(v, n)
				_fixed_cache[fk] = c
			if best.is_empty() or float(c[0]) > float(best[0]) or (float(c[0]) == float(best[0]) and int(c[5]) > int(best[5])):
				best = c.duplicate()
				best_vals = v.duplicate()
			var p := assign.size() - 1
			while p >= 0 and assign[p] == Combo.WILD_MAX:
				p -= 1
			if p < 0:
				break
			assign[p] += 1
			for q in range(p + 1, assign.size()):
				assign[q] = assign[p]
		for i in widx:
			if not ((int(best[1]) >> i) & 1):
				best_vals[i] = Combo.WILD_MAX
		best[2] = best_vals
		out = best
	out.resize(5)
	if _combo_cache.size() > 400000:
		_combo_cache.clear()
		_fixed_cache.clear()
	_combo_cache[key] = out
	return out

const _KIND_MULT := [0.0, 0.0, 1.5, 2.5, 5.0, 10.0, 15.0]
const _KIND_ID := ["", "", "pair", "three_kind", "four_kind", "five_kind", "six_kind"]

## Mask of the first k dice showing value v.
static func _first(vals: PackedInt32Array, n: int, v: int, k: int) -> int:
	var m := 0
	for i in n:
		if k <= 0:
			break
		if vals[i] == v:
			m |= 1 << i
			k -= 1
	return m

## Combo._evaluate_fixed as [mult, group_mask, null, code, id, group_sum].
static func _eval_fixed(vals: PackedInt32Array, n: int) -> Array:
	var cnt := PackedInt32Array()
	cnt.resize(Combo.MAX_VALUE + 2)
	for i in n:
		var v := clampi(vals[i], 0, Combo.MAX_VALUE)
		if v > 0:
			cnt[v] += 1
	var bm := -1.0
	var bs := -1
	var bg := 0
	var bid := "high_roller"
	for v in range(1, Combo.MAX_VALUE + 1):
		var c := cnt[v]
		if c >= 2:
			var k := mini(c, 6)
			var m: float = _KIND_MULT[k]
			if m > bm or (m == bm and v * k > bs):
				bm = m
				bs = v * k
				bg = _first(vals, n, v, k)
				bid = _KIND_ID[k]
	for a in range(1, Combo.MAX_VALUE + 1):
		if cnt[a] < 2:
			continue
		for b in range(1, Combo.MAX_VALUE + 1):
			if b == a or cnt[b] < 2:
				continue
			if cnt[a] >= 3:
				var s := 3 * a + 2 * b
				if 3.5 > bm or (3.5 == bm and s > bs):
					bm = 3.5
					bs = s
					bg = _first(vals, n, a, 3) | _first(vals, n, b, 2)
					bid = "full_house"
			if a > b:
				var s2 := 2 * a + 2 * b
				if 2.0 > bm or (2.0 == bm and s2 > bs):
					bm = 2.0
					bs = s2
					bg = _first(vals, n, a, 2) | _first(vals, n, b, 2)
					bid = "two_pair"
	for start in range(1, Combo.MAX_VALUE + 1):
		if cnt[start] == 0:
			continue
		for length in [5, 4]:
			if start + length - 1 > Combo.MAX_VALUE:
				continue
			var ok := true
			var s3 := 0
			for v in range(start, start + length):
				if cnt[v] == 0:
					ok = false
					break
				s3 += v
			if not ok:
				continue
			var m3 := 3.0 if length == 5 else 2.5
			if m3 > bm or (m3 == bm and s3 > bs):
				bm = m3
				bs = s3
				bg = 0
				for v in range(start, start + length):
					bg |= _first(vals, n, v, 1)
				bid = "straight" if length == 5 else "small_straight"
	if n > 0:
		var hi := 0
		for i in n:
			if vals[i] > vals[hi]:
				hi = i
		if 1.0 > bm or (1.0 == bm and vals[hi] > bs):
			bm = 1.0
			bs = vals[hi]
			bg = 1 << hi
			bid = "high_roller"
	if bm < 0.0:
		bm = 1.0
		bs = 0
		bg = 0
	return [bm, bg, null, int(COMBO_CODE[bid]), bid, bs]

# ------------------------------------------------------------------------------ combat model

## Scores a final set of dice for one attack: expected damage to the best target (overkill
## wasted), kills (their attack this turn is prevented, plus their future threat), Block vs the
## incoming intents, poison/ember/thunder, heals, gold and banked rerolls. Units: damage ~ HP.
class CombatModel:
	var n := 0
	var faces: Array[PackedInt32Array] = []
	var dv: Array[PackedInt32Array] = []    # distinct face values per die
	var dw: Array[PackedFloat64Array] = []  # their probabilities
	var rune := PackedInt32Array()
	var wild_mask := 0
	var times_group := 1.0
	var atk := 0
	var factor := 1.0
	var midas := 0
	var pair_master := false
	var crowd := false
	var triple := false
	var steady := false
	var boxcars := false
	var snake := false
	var straight := false
	var fh_party := false
	var gold_tooth := false
	var lucky_room := 0
	var hero_hp := 1.0
	var hero_missing := 0.0
	var hero_block := 0.0
	var survive := false
	var ne := 0
	var e_idx := PackedInt32Array()
	var e_hp := PackedFloat64Array()
	var e_block := PackedFloat64Array()
	var e_poison := PackedFloat64Array()
	var e_hit := PackedFloat64Array()
	var e_pierce := PackedFloat64Array()
	var e_other := PackedFloat64Array()
	var e_future := PackedFloat64Array()
	var e_ward := PackedByteArray()
	var e_frozen := PackedByteArray()
	var e_thorns := PackedByteArray()
	var w_hp := 1.0
	var w_heal := 0.8
	var w_gold := 0.15
	var w_lucky := 3.0
	var win_bonus := 8.0
	var use_memo := true
	var memo := {}
	var h := PackedFloat64Array()
	var b := PackedFloat64Array()
	# outputs of the last non-memo score()
	var last_target := -1
	var last_total := 0
	var last_dmg := 0.0
	var last_kills := 0

	func set_dice(dice: Array) -> void:
		## dice: [[faces PackedInt32Array, rune String], ...]
		n = dice.size()
		faces.clear()
		dv.clear()
		dw.clear()
		rune.resize(n)
		wild_mask = 0
		for i in n:
			var fc: PackedInt32Array = dice[i][0]
			faces.append(fc)
			var cnt := {}
			for v in fc:
				cnt[v] = int(cnt.get(v, 0)) + 1
			var vs := PackedInt32Array()
			var ws := PackedFloat64Array()
			var keys := cnt.keys()
			keys.sort()
			for v in keys:
				vs.append(int(v))
				ws.append(float(cnt[v]) / 6.0)
			dv.append(vs)
			dw.append(ws)
			var rc := int(Bot.RUNE_CODE.get(String(dice[i][1]), 0))
			rune[i] = rc
			if rc == Bot.R_WILD:
				wild_mask |= 1 << i

	func set_passives(ps: Array, gold: int, first_turn: bool) -> void:
		pair_master = ps.has("pair_master")
		crowd = ps.has("crowd_pleaser")
		triple = ps.has("triple_threat")
		steady = ps.has("steady_hand")
		boxcars = ps.has("boxcars")
		snake = ps.has("snake_eyes")
		straight = ps.has("straight_shooter")
		fh_party = ps.has("full_house_party")
		gold_tooth = ps.has("gold_tooth")
		times_group = 2.0 if ps.has("resonance") else (1.0 + Balance.PASSIVE_RUNE_ECHO_CHANCE if ps.has("rune_echo") else 1.0)
		factor = 1.0
		if ps.has("glass_cannon"):
			factor *= Balance.PASSIVE_DAMAGE_MULT
		if ps.has("opening_salvo") and first_turn:
			factor *= Balance.PASSIVE_DAMAGE_MULT
		midas = mini(Balance.PASSIVE_MIDAS_MAX, gold / Balance.PASSIVE_MIDAS_GOLD) if ps.has("midas_fist") else 0

	func add_enemy(orig: int, hp: float, block: float, poison: float, hit: float, pierce: float, other: float,
			future: float, ward: bool, frozen: bool, thorns: bool) -> void:
		ne += 1
		e_idx.append(orig)
		e_hp.append(hp)
		e_block.append(block)
		e_poison.append(poison)
		e_hit.append(hit)
		e_pierce.append(pierce)
		e_other.append(other)
		e_future.append(future)
		e_ward.append(1 if ward else 0)
		e_frozen.append(1 if frozen else 0)
		e_thorns.append(1 if thorns else 0)
		h.append(0.0)
		b.append(0.0)

	func _hit(k: int, amount: float) -> float:
		if h[k] <= 0.0 or amount <= 0.0:
			return 0.0
		var a := amount
		if e_ward[k] == 1:
			a = ceilf(a / 2.0)
		var bl := minf(b[k], a)
		b[k] -= bl
		var d := minf(a - bl, h[k])
		h[k] -= d
		return d

	## vals: face values per die; rer: bitmask of dice rerolled at least once this turn.
	func score(vals: PackedInt32Array, rer: int) -> float:
		var key := 0
		if use_memo:
			for i in n:
				key = key * 10 + vals[i]
			key = key * 64 + rer
			var m: Variant = memo.get(key)
			if m != null:
				return m
		var cb: Array = Bot._combo(vals, wild_mask)
		var gm: int = cb[1]
		var eff: PackedInt32Array = cb[2]
		var code: int = cb[3]
		var mult: float = cb[0]
		if code == Bot.C_PAIR and crowd:
			mult = maxf(mult, 2.5)
		if (code == Bot.C_PAIR or code == Bot.C_TWO_PAIR) and pair_master:
			mult += Balance.PASSIVE_PAIR_BONUS
		if code == Bot.C_SET and triple:
			mult += Balance.PASSIVE_SET_BONUS
		var sum := 0.0
		var bonus := 0.0
		var flat := float(midas)
		var ember := 0.0
		var thunder := 0.0
		var venom := 0.0
		var guard := 0.0
		var vamp := 0.0
		var gold := 0.0
		var lucky := 0
		var frost := false
		for i in n:
			var p := eff[i]
			var rc := rune[i]
			var ing := ((gm >> i) & 1) == 1
			var rerolled := ((rer >> i) & 1) == 1
			var t := times_group if (ing and rc != 0) else 1.0
			if rc == Bot.R_HEAVY:
				sum += p * (1.0 + t)
			else:
				sum += p
			match rc:
				Bot.R_BLADE:
					if ing:
						bonus += p * t
				Bot.R_ECHO:
					if ing:
						mult += 0.5 * t
				Bot.R_EMBER:
					if p == 6:
						ember += 6.0 * t
				Bot.R_THUNDER:
					if rerolled:
						thunder += p * t
				Bot.R_VENOM:
					if ing:
						venom += p * t
				Bot.R_FROST:
					if p == 1:
						frost = true
				Bot.R_GUARD:
					guard += p * t
				Bot.R_VAMPIRE:
					if ing:
						vamp += p * t
				Bot.R_GILDED:
					if ing:
						gold += 2.0 * t
				Bot.R_LUCKY:
					if not rerolled:
						lucky += 1
			if steady and not rerolled:
				bonus += 1.0
			if boxcars and ing and p == 6:
				bonus += Balance.PASSIVE_BOXCARS
			if snake and p == 1:
				flat += Balance.PASSIVE_SNAKE_EYES
			if gold_tooth and p == 6:
				gold += 1.0
		if straight and code == Bot.C_STRAIGHT:
			flat += Balance.PASSIVE_STRAIGHT_DAMAGE
		var total := int(floor(((sum + bonus) * mult + flat) * factor)) + atk
		var heal_extra := float(Balance.PASSIVE_FULL_HOUSE_HEAL) if (fh_party and code == Bot.C_FULL) else 0.0
		var best := -INF
		var best_t := -1
		var best_dmg := 0.0
		var best_kills := 0
		for t in ne:
			for k in ne:
				h[k] = e_hp[k]
				b[k] = e_block[k]
			var dealt := 0.0
			var progress := 0.0
			var d0 := _hit(t, float(total))
			dealt += d0
			progress += d0 * 0.03 * (e_hit[t] + e_pierce[t] + e_other[t])
			if ember > 0.0:
				for k in ne:
					dealt += _hit(k, ember)
			if thunder > 0.0:
				var alive := 0
				for k in ne:
					if h[k] > 0.0:
						alive += 1
				if alive > 0:
					var share := thunder / alive
					for k in ne:
						if h[k] > 0.0:
							var d := minf(share, h[k] - 0.01)
							if d > 0.0:
								dealt += d
								h[k] -= d
			var val := dealt + progress
			var incoming := 0.0
			var pierce := 0.0
			var threat := 0.0
			var kills := 0
			var all_dead := true
			for k in ne:
				var pk := e_poison[k]
				if k == t:
					pk += venom
				if h[k] > 0.0 and pk >= h[k]:
					val += h[k] # poison finishes it before it acts
					h[k] = 0.0
				if h[k] <= 0.0:
					kills += 1
					val += e_future[k]
					continue
				all_dead = false
				if k == t and venom > 0.0:
					val += minf(h[k], venom * 1.5) * 0.7
				if e_frozen[k] == 1 or (frost and k == t):
					continue
				incoming += e_hit[k]
				pierce += e_pierce[k]
				threat += e_other[k]
			var heal := minf(vamp + heal_extra, hero_missing)
			if all_dead:
				val += win_bonus
			else:
				var loss := maxf(0.0, incoming - hero_block - guard) + pierce
				if e_thorns[t] == 1 and total > 0:
					loss += Balance.ENEMY_THORNS
				val -= w_hp * (loss + threat * 0.5)
				if loss >= hero_hp + heal:
					val -= 30.0 if survive else 400.0
			val += heal * w_heal + gold * w_gold + mini(lucky, lucky_room) * w_lucky
			if val > best:
				best = val
				best_t = t
				best_dmg = dealt
				best_kills = kills
		if ne == 0:
			best = float(total)
		last_target = e_idx[best_t] if best_t >= 0 else -1
		last_total = total
		last_dmg = best_dmg if ne > 0 else float(total)
		last_kills = best_kills
		if use_memo:
			memo[key] = best
		return best

static func _dice_desc(dice: Array) -> Array:
	var out: Array = []
	for d in dice:
		out.append([PackedInt32Array(d.faces), String(d.rune)])
	return out

## Average damage an enemy's pattern deals per action (attack-like intents), scaled.
static func _avg_attack(id: String, atk_mult: float, atk_bonus: int) -> float:
	var def := EnemyDefs.def(id)
	var pats: Array = []
	if EnemyDefs.is_boss(id):
		for ph in def.phases:
			pats.append_array(ph)
	else:
		pats = def.pattern
	var s := 0.0
	for p in pats:
		match String(p.kind):
			"attack", "chill", "drain":
				s += float(p.value) * atk_mult + atk_bonus
			"burn":
				s += float(p.value) * 2.0
	return s / maxf(1.0, pats.size())

static func _combat_model(f: GameFlow, rules: AutoRules) -> CombatModel:
	var fw := _fw(rules)
	var c := f.combat
	var run := f.run
	var cm := CombatModel.new()
	cm.set_dice(_dice_desc(run.dice))
	cm.set_passives(Array(run.passives), run.gold, c.turn == 1)
	cm.atk = run.atk
	cm.lucky_room = maxi(0, Balance.MAX_BANKED_REROLLS - run.banked_rerolls)
	cm.hero_hp = float(run.hp)
	cm.hero_missing = float(run.max_hp - run.hp)
	cm.hero_block = float(run.block)
	cm.survive = (run.has_passive("phoenix") and int(run.passive_state.get("phoenix_act", 0)) != run.act) \
		or (run.has_passive("second_wind") and not bool(run.passive_state.get("second_wind_used", false)))
	var r := hp_ratio(f)
	cm.w_hp = float(fw.def) * (0.7 + 1.0 * (1.0 - r))
	cm.w_heal = cm.w_hp * 0.8
	cm.w_gold = 0.15 * float(fw.econ)
	var summons := 0
	for k in c.enemies.size():
		if c.alive(k) and bool(c.enemies[k].summoned):
			summons += 1
	for k in c.enemies.size():
		if not c.alive(k):
			continue
		var e: Dictionary = c.enemies[k]
		var v := float(e.intent.value)
		var hit := 0.0
		var pierce := 0.0
		var other := 0.0
		var pierces := CombatState.has_trait(e, "pierce")
		match String(e.intent.kind):
			"attack", "drain":
				hit = v
			"chill":
				hit = v
				other = 2.0
			"burn":
				pierce = minf(v * (v + 1.0) / 2.0, v * 3.0) * 0.8
			"heal":
				other = v * 0.6
			"block":
				other = v * 0.4
			"buff":
				other = v * 2.0
			"curse":
				other = 3.0 * v
			"summon":
				other = 6.0 * maxf(1.0, v)
			"scorch", "chaos":
				other = 4.0
		if pierces:
			pierce += hit
			hit = 0.0
		var future := _avg_attack(String(e.id), float(e.atk_mult), int(e.atk_bonus)) * 1.2 + 2.0
		cm.add_enemy(k, float(e.hp), float(e.block), float(e.poison), hit, pierce, other, future,
			CombatState.has_trait(e, "ward") and summons > 0, bool(e.frozen), CombatState.has_trait(e, "thorns"))
	return cm

## Private samples: face index per (sample, die) from an Rng seeded by `seed`.
static func _samples(seed: int, ns: int) -> PackedInt32Array:
	var rng := Rng.new(seed)
	var out := PackedInt32Array()
	out.resize(ns * 6)
	for k in ns * 6:
		out[k] = rng.randi_range(0, 5)
	return out

## Outcome list of rerolling the dice in `mask`: [values arrays, weights]. Exact when the
## distinct outcomes are few, else Monte-Carlo over `samples`.
static func _outcomes(cm: CombatModel, cur: PackedInt32Array, mask: int, samples: PackedInt32Array, ns: int) -> Array:
	var idx: Array[int] = []
	var count := 1
	for i in cm.n:
		if (mask >> i) & 1:
			idx.append(i)
			count *= cm.dv[i].size()
	var vals: Array[PackedInt32Array] = []
	var ws := PackedFloat64Array()
	if count <= EXACT_MAX:
		var pos := PackedInt32Array()
		pos.resize(idx.size())
		for o in count:
			var v := cur.duplicate()
			var w := 1.0
			for j in idx.size():
				var i := idx[j]
				v[i] = cm.dv[i][pos[j]]
				w *= cm.dw[i][pos[j]]
			vals.append(v)
			ws.append(w)
			var j2 := 0
			while j2 < idx.size():
				pos[j2] += 1
				if pos[j2] < cm.dv[idx[j2]].size():
					break
				pos[j2] = 0
				j2 += 1
	else:
		var w := 1.0 / ns
		for s in ns:
			var v := cur.duplicate()
			for i in idx:
				v[i] = cm.faces[i][samples[s * 6 + i]]
			vals.append(v)
			ws.append(w)
	return [vals, ws]

## Expected-value reroll plan. Every legal keep-set (subsets of the free dice) is valued as the
## expected best outcome over the remaining rerolls: V1 = E[S], Vr = E[max(S, V(r-1))] (reroll
## the same dice again if the result is worse than trying again). Returns
## {mask, value, now, chase:String, chance:float}.
static func _plan_rerolls(cm: CombatModel, cur: PackedInt32Array, rer_prev: int, free_mask: int, rerolls: int, seed: int) -> Dictionary:
	var ns := MC_SAMPLES_6 if cm.n >= 6 else MC_SAMPLES
	var samples := _samples(seed, ns)
	var now := cm.score(cur, rer_prev)
	var best_v := now
	var best_mask := 0
	var v := cur.duplicate()
	var sc := PackedFloat64Array()
	var ws := PackedFloat64Array()
	var pos := PackedInt32Array()
	for mask in range(1, 1 << cm.n):
		if mask & ~free_mask:
			continue
		var idx: Array[int] = []
		var count := 1
		for i in cm.n:
			if (mask >> i) & 1:
				idx.append(i)
				count *= cm.dv[i].size()
		var rm := rer_prev | mask
		var ev := 0.0
		if count <= EXACT_MAX:
			sc.resize(count)
			ws.resize(count)
			pos.resize(idx.size())
			pos.fill(0)
			for o in count:
				var w := 1.0
				for j in idx.size():
					var i := idx[j]
					v[i] = cm.dv[i][pos[j]]
					w *= cm.dw[i][pos[j]]
				var x := cm.score(v, rm)
				sc[o] = x
				ws[o] = w
				ev += x * w
				var j2 := 0
				while j2 < idx.size():
					pos[j2] += 1
					if pos[j2] < cm.dv[idx[j2]].size():
						break
					pos[j2] = 0
					j2 += 1
		else:
			sc.resize(ns)
			ws.resize(ns)
			var w := 1.0 / ns
			for s in ns:
				for i in idx:
					v[i] = cm.faces[i][samples[s * 6 + i]]
				var x := cm.score(v, rm)
				sc[s] = x
				ws[s] = w
				ev += x * w
		for i in idx:
			v[i] = cur[i]
		for r in range(1, rerolls):
			var nv := 0.0
			for k in sc.size():
				nv += maxf(sc[k], ev) * ws[k]
			ev = nv
		if ev > best_v + 0.05:
			best_v = ev
			best_mask = mask
	var plan := {"mask": best_mask, "value": best_v, "now": now, "chase": "", "chance": 0.0}
	if best_mask != 0:
		# the combo worth chasing: max mult x P(reaching at least that mult)
		var cur_mult: float = _combo(cur, cm.wild_mask)[0]
		var by_mult := {}
		var names := {}
		var best_out := _outcomes(cm, cur, best_mask, samples, ns)
		var vals2: Array[PackedInt32Array] = best_out[0]
		var ws2: PackedFloat64Array = best_out[1]
		for k in vals2.size():
			var cb := _combo(vals2[k], cm.wild_mask)
			var m: float = cb[0]
			by_mult[m] = float(by_mult.get(m, 0.0)) + ws2[k]
			names[m] = cb[4]
		var best_score := 0.0
		for m in by_mult:
			if float(m) <= cur_mult:
				continue
			var p := 0.0
			for m2 in by_mult:
				if float(m2) >= float(m):
					p += float(by_mult[m2])
			p = 1.0 - pow(1.0 - p, rerolls)
			if float(m) * p > best_score and p >= 0.05:
				best_score = float(m) * p
				plan.chase = String(Combo.TABLE[names[m]].name)
				plan.chance = p
	return plan

static func _combat_key(f: GameFlow, rules: AutoRules) -> int:
	var c := f.combat
	var en: Array = []
	for e in c.enemies:
		en.append([e.hp, e.block, e.poison, e.frozen, e.intent.kind, e.intent.value, e.atk_bonus, e.traits])
	var dd: Array = []
	for d in f.run.dice:
		dd.append([d.faces, d.rune])
	return hash([f.run.seed, int(f.run.stats.get("combat_turns", 0)), c.turn, c.rerolls_left, c.dice_values,
		c.locked, c.rerolled, en, dd, f.run.hp, f.run.max_hp, f.run.block, f.run.gold, f.run.passives,
		f.run.banked_rerolls, rules.focus])

static func _enemy_name(f: GameFlow, i: int) -> String:
	return String(f.combat.enemies[i].name) if i >= 0 and i < f.combat.enemies.size() else "?"

static func _combat_plan(f: GameFlow, rules: AutoRules) -> Dictionary:
	var key := _combat_key(f, rules)
	var hit: Variant = _plan_cache.get(key)
	if hit != null:
		return hit
	var c := f.combat
	var cm := _combat_model(f, rules)
	var cur := PackedInt32Array(c.dice_values)
	var rer_prev := 0
	var free_mask := 0
	for i in cm.n:
		if c.rerolled[i]:
			rer_prev |= 1 << i
		# a Wild die already counts as its best value, and a one-value die can't change: never
		# worth a reroll (this also halves the search)
		if not c.locked[i] and cm.rune[i] != R_WILD and (cm.dv[i].size() > 1 or cm.rune[i] == R_THUNDER):
			free_mask |= 1 << i
	var plan := {"mask": 0, "chase": "", "chance": 0.0}
	if c.rerolls_left > 0 and free_mask != 0:
		plan = _plan_rerolls(cm, cur, rer_prev, free_mask, c.rerolls_left, key)
	var out := {"mask": int(plan.mask), "target": -1}
	if int(plan.mask) != 0:
		var k := 0
		for i in cm.n:
			if (int(plan.mask) >> i) & 1:
				k += 1
		var what := "Rerolling %d %s" % [k, "die" if k == 1 else "dice"]
		if String(plan.chase) != "":
			out.reason = "%s to chase %s (%d%%)" % [what, plan.chase, int(round(float(plan.chance) * 100.0))]
		else:
			out.reason = "%s for more damage" % what
	else:
		cm.use_memo = false
		cm.score(cur, rer_prev)
		out.target = cm.last_target
		var cb := _combo(cur, cm.wild_mask)
		var name := String(Combo.TABLE[cb[4]].name)
		var t := _enemy_name(f, cm.last_target)
		var kill := ""
		if cm.last_target >= 0 and cm.last_dmg >= float(c.enemies[cm.last_target].hp):
			kill = ", lethal"
		out.reason = "Attacking %s with %s for %d%s" % [t, name, cm.last_total, kill]
		if cm.last_target >= 0 and cm.last_target != c.target:
			var e: Dictionary = c.enemies[cm.last_target]
			var why := "can kill it" if kill != "" else "biggest threat"
			if String(e.intent.kind) in ["attack", "drain", "chill"] and kill != "":
				why = "can kill it before it hits for %d" % int(e.intent.value)
			out.target_reason = "Targeting %s: %s" % [t, why]
	if _plan_cache.size() > 64:
		_plan_cache.clear()
	_plan_cache[key] = out
	return out

static func _decide_combat(f: GameFlow, rules: AutoRules) -> Dictionary:
	var c := f.combat
	var plan := _combat_plan(f, rules)
	var mask := int(plan.mask)
	if mask != 0 and c.rerolls_left > 0:
		for i in c.marked.size():
			var want := ((mask >> i) & 1) == 1
			if want != c.marked[i] and not c.locked[i]:
				return _result(["combat_toggle", i], String(plan.reason))
		return _result(["combat_reroll"], String(plan.reason))
	for i in c.marked.size():
		if c.marked[i] and not c.locked[i]:
			return _result(["combat_toggle", i], "Keeping die %d: no reroll beats this hand" % (i + 1))
	var t := int(plan.target)
	if t >= 0 and t != c.target and c.alive(t):
		return _result(["combat_set_target", t], String(plan.get("target_reason", "Targeting %s" % _enemy_name(f, t))))
	return _result(["combat_attack"], String(plan.reason))

# ------------------------------------------------------------------------------ pool value

## Pool value (PV): the expected worth of one combat turn with these dice, from a single roll
## against two sturdy dummy enemies (damage + Block + heals + gold, focus-weighted). Deltas of
## PV score new dice, runes, face edits and combat passives, so synergies come for free (Echo
## with a big pool, Heavy on high faces, raises on dice that form combos).
static func _pool_value(dice: Array, passives: Array, run: RunState, rules: AutoRules, gold := -1, atk := -9999) -> float:
	var sc := _pv_scores(dice, passives, run, rules, gold, atk)
	var s := 0.0
	for x in sc:
		s += x
	return s / sc.size() * _pv_scale(rules)

static func _pv_scale(rules: AutoRules) -> float:
	return 0.85 + 0.15 * float(_fw(rules).dmg)

static func _pv_model(dice: Array, passives: Array, run: RunState, rules: AutoRules, g: int, a: int) -> CombatModel:
	var fw := _fw(rules)
	var cm := CombatModel.new()
	cm.set_dice(dice)
	cm.set_passives(passives, g, false)
	if passives.has("opening_salvo"):
		cm.factor *= 1.0 + (Balance.PASSIVE_DAMAGE_MULT - 1.0) * 0.4 # first turn of ~2.5
	cm.atk = a
	cm.use_memo = false
	cm.lucky_room = 1
	cm.w_lucky = 1.5
	cm.hero_hp = 1.0e6
	cm.hero_missing = run.max_hp * 0.3
	cm.hero_block = Balance.PASSIVE_IRON_SKIN if passives.has("iron_skin") else 0.0
	cm.w_hp = 0.7 * float(fw.def)
	cm.w_heal = cm.w_hp * 0.6
	cm.w_gold = 0.15 * float(fw.econ)
	cm.win_bonus = 0.0
	for k in 2:
		cm.add_enemy(k, 1.0e6, 0.0, 0.0, 7.0, 0.0, 0.0, 0.0, false, false, false)
	return cm

## One PV sample: half the samples count as kept dice (Lucky, Steady Hand), half as rerolled
## (Thunder). The constant keeps scores positive (the dummies' hits are always taken).
static func _pv_sample(cm: CombatModel, v: PackedInt32Array, k: int) -> float:
	for i in cm.n:
		v[i] = cm.faces[i][_pv_samples[k * 6 + i]]
	return cm.score(v, 0 if k % 2 == 0 else (1 << cm.n) - 1) + 7.0 * 2.0 * cm.w_hp

## Per-sample PV scores (cached by pool, passives and focus).
static func _pv_scores(dice: Array, passives: Array, run: RunState, rules: AutoRules, gold := -1, atk := -9999) -> PackedFloat64Array:
	var g := run.gold if gold < 0 else gold
	var a := run.atk if atk == -9999 else atk
	var key := hash([dice, passives, g / 8, a, rules.focus, run.max_hp])
	var hit: Variant = _pv_cache.get(key)
	if hit != null:
		return hit
	if _pv_samples.is_empty():
		_pv_samples = _samples(0x5eed, PV_SAMPLES)
	var cm := _pv_model(dice, passives, run, rules, g, a)
	var v := PackedInt32Array()
	v.resize(cm.n)
	var sc := PackedFloat64Array()
	sc.resize(PV_SAMPLES)
	for k in PV_SAMPLES:
		sc[k] = _pv_sample(cm, v, k)
	if _pv_cache.size() > 20000:
		_pv_cache.clear()
	_pv_cache[key] = sc
	return sc

## PV gained by setting face fi of die i to `value`: only the samples showing that face change.
static func _face_gain(f: GameFlow, rules: AutoRules, i: int, fi: int, value: int) -> float:
	var dd := _dice_desc(f.run.dice)
	var base := _pv_scores(dd, Array(f.run.passives), f.run, rules)
	var fc: PackedInt32Array = dd[i][0]
	fc[fi] = value
	dd[i][0] = fc
	var cm := _pv_model(dd, Array(f.run.passives), f.run, rules, f.run.gold, f.run.atk)
	var v := PackedInt32Array()
	v.resize(cm.n)
	var d := 0.0
	for k in PV_SAMPLES:
		if _pv_samples[k * 6 + i] == fi:
			d += _pv_sample(cm, v, k) - base[k]
	return d / PV_SAMPLES * _pv_scale(rules)

static func _pv_run(f: GameFlow, rules: AutoRules) -> float:
	return _pool_value(_dice_desc(f.run.dice), Array(f.run.passives), f.run, rules)

## Combat turns left in the run (rough), used to price one-off HP.
static func _turns_left(f: GameFlow) -> float:
	return maxf(6.0, 3.3 * float(Balance.TOTAL_LAPS - f.run.lap + 1))

## PV worth of one HP (one-off), higher when HP is low or the run is near its end.
static func _hp_pt(f: GameFlow, rules: AutoRules) -> float:
	var r := hp_ratio(f)
	return float(_fw(rules).def) / (0.4 * _turns_left(f)) * (1.0 + 2.0 * (1.0 - r) * (1.0 - r))

static func _gold_pt(f: GameFlow, rules: AutoRules) -> float:
	var late := 1.0 if f.run.lap < Balance.TOTAL_LAPS - 2 else 0.4 # little left to buy
	return 0.04 * float(_fw(rules).econ) * late

static func _pref(rules: AutoRules, cat: String) -> float:
	return float(_fw(rules).pref.get(cat, 1.0))

## PV gained by giving die i rune r (replacing its rune).
static func _rune_gain(f: GameFlow, rules: AutoRules, i: int, r: String, base: float) -> float:
	var dd := _dice_desc(f.run.dice)
	dd[i][1] = r
	return _pool_value(dd, Array(f.run.passives), f.run, rules) - base

static func _best_rune_die(f: GameFlow, rules: AutoRules, r: String) -> Array:
	var base := _pv_run(f, rules)
	var best := 0
	var best_g := -INF
	for i in f.run.dice.size():
		var g := _rune_gain(f, rules, i, r, base)
		if g > best_g + 1e-6:
			best_g = g
			best = i
	return [best, best_g]

static func _new_die_gain(f: GameFlow, rules: AutoRules, kind: String) -> float:
	if f.run.dice.size() >= f.run.max_dice():
		return -INF
	var dd := _dice_desc(f.run.dice)
	var base := _pool_value(dd, Array(f.run.passives), f.run, rules)
	dd.append([DiceKinds.faces(kind), ""])
	return _pool_value(dd, Array(f.run.passives), f.run, rules) - base

## Best single face edit: [die, face, op, src, gain]. ops: allowed ops ("raise", "mirror").
## lowest_only: the shop's Face Raise always raises the die's lowest face.
static func _best_face_edit(f: GameFlow, rules: AutoRules, ops: Array, lowest_only := false) -> Array:
	var best: Array = [-1, 0, "skip", -1, -INF]
	for i in f.run.dice.size():
		var d := f.run.dice[i]
		var tried := {}
		for fi in 6:
			if lowest_only and fi != d.lowest_face():
				continue
			if ops.has("raise") and d.can_raise(fi) and not tried.has("r%d" % d.faces[fi]):
				tried["r%d" % d.faces[fi]] = true
				var g := _face_gain(f, rules, i, fi, d.faces[fi] + 1)
				if g > float(best[4]) + 1e-6:
					best = [i, fi, "raise", -1, g]
			if ops.has("mirror") and fi == d.lowest_face():
				for src in 6:
					if d.faces[src] <= d.faces[fi] or tried.has("m%d" % d.faces[src]):
						continue
					tried["m%d" % d.faces[src]] = true
					var g2 := _face_gain(f, rules, i, fi, d.faces[src])
					if g2 > float(best[4]) + 1e-6:
						best = [i, fi, "mirror", src, g2]
	return best

## PV worth of a passive (combat ones simulated; the rest estimated), focus-weighted.
static func _passive_value(f: GameFlow, rules: AutoRules, id: String) -> float:
	var run := f.run
	var ps := Array(run.passives)
	if ps.has(id):
		return -INF
	var pv := _pv_run(f, rules)
	var laps_left := float(Balance.TOTAL_LAPS - run.lap + 1)
	var frac := laps_left / Balance.TOTAL_LAPS
	var hp_pt := _hp_pt(f, rules)
	var gold_pt := _gold_pt(f, rules)
	var reroll_v := 0.18 * pv
	var v := 0.0
	if MODELLED_PASSIVES.has(id):
		var ps2 := ps.duplicate()
		ps2.append(id)
		v = _pool_value(_dice_desc(run.dice), ps2, run, rules) - pv
		if id == "glass_cannon":
			v -= run.max_hp * Balance.PASSIVE_GLASS_HP_PCT * hp_pt * 2.0
	else:
		match id:
			"loaded_hands":
				v = reroll_v * 0.4
			"double_trouble":
				v = reroll_v * 0.3
			"encore":
				v = reroll_v * 0.5
			"collector":
				var runes := 0
				for d in run.dice:
					if d.rune != "":
						runes += 1
				v = Balance.PASSIVE_COLLECTOR_HP * (runes + 2.0 * frac) * hp_pt * 1.5
			"pathfinder":
				v = 1.0 * frac
			"treasure_sense":
				v = 9.0 * 1.5 * laps_left * gold_pt
			"piggy_bank":
				v = minf(15.0, run.gold * 0.1 + 5.0) * laps_left * gold_pt
			"haggler":
				v = 0.2 * 70.0 * laps_left / 3.0 * gold_pt
			"scholar":
				v = 0.25 * 8.0 * frac * 2.0
			"blacksmith":
				v = 0.4 * laps_left * 0.3
			"thorns":
				v = 1.5
			"bloodthirst":
				v = 1.5 * float(_fw(rules).def)
			"second_wind":
				v = 30.0 * hp_pt
			"phoenix":
				v = 30.0 * hp_pt * minf(3.0, float(Balance.ACTS - run.act + 1))
			"extra_hand":
				var dd := _dice_desc(run.dice)
				dd.append([DiceKinds.faces("standard"), ""])
				v = _pool_value(dd, ps, run, rules) - pv
				if run.dice.size() < run.max_dice():
					v *= 0.5 # the room would have been filled anyway
			"rune_bloom":
				var bare := 0
				for d in run.dice:
					if d.rune == "":
						bare += 1
				v = 1.2 * (bare + float(Balance.ACTS - run.act))
			"fast_feet":
				v = 0.6 * frac
			_:
				v = 0.5
	return v * _pref(rules, String(PASSIVE_CAT.get(id, "dmg")))

## PV worth of one draft/shop option (no price).
static func _option_value(f: GameFlow, rules: AutoRules, o: Dictionary) -> Array:
	## -> [value, reason, die_idx]
	var run := f.run
	var pv := _pv_run(f, rules)
	match String(o.id):
		"new_die", "die":
			var kind := String(o.get("kind", "standard"))
			var g := _new_die_gain(f, rules, kind)
			return [g * _pref(rules, "dmg"), "%s: another die means bigger combos" % DiceKinds.label(kind), -1]
		"rune":
			var r := String(o.rune)
			var bd := _best_rune_die(f, rules, r)
			var cat := String(RUNE_CAT.get(r, "dmg"))
			var why := "fits %s focus" % rules.focus if rules.focus != "balanced" and _pref(rules, cat) > 1.0 else _rune_why(f, r, int(bd[0]))
			return [float(bd[1]) * _pref(rules, cat), "%s Rune: %s" % [Runes.DEFS[r].name, why], int(bd[0])]
		"combat_reroll":
			if run.combat_rerolls >= Balance.MAX_COMBAT_REROLLS:
				return [-INF, "", -1]
			return [0.18 * pv * _pref(rules, "dmg"), "+1 combat reroll: more chances at big combos", -1]
		"max_hp":
			var hp_pt := _hp_pt(f, rules)
			var gain := Balance.DRAFT_MAX_HP * (1.0 + 0.6 * _turns_left(f) / 50.0) + minf(Balance.DRAFT_MAX_HP, run.max_hp - run.hp)
			return [gain * hp_pt * _pref(rules, "def"), "+%d max HP: staying alive" % Balance.DRAFT_MAX_HP, -1]
		"face_raise":
			var e := _best_face_edit(f, rules, ["raise"], String(o.id) == "face_raise" and o.has("price"))
			return [float(e[4]) * _pref(rules, "dmg"), "Face Raise on die %d" % (int(e[0]) + 1), int(e[0])]
		"potion":
			var heal := minf(run.pct_of_max(Balance.SHOP_POTION_PCT), run.max_hp - run.hp)
			return [heal * _hp_pt(f, rules), "Potion: heal %d" % int(heal), -1]
		"passive":
			var pid := String(o.passive)
			return [_passive_value(f, rules, pid), "%s: %s" % [Passives.DEFS[pid].name, _cat_why(rules, String(PASSIVE_CAT.get(pid, "dmg")))], -1]
	if Passives.DEFS.has(String(o.id)):
		var pid2 := String(o.id)
		return [_passive_value(f, rules, pid2), "%s: %s" % [Passives.DEFS[pid2].name, _cat_why(rules, String(PASSIVE_CAT.get(pid2, "dmg")))], -1]
	return [0.0, String(o.get("label", "?")), -1]

static func _cat_why(rules: AutoRules, cat: String) -> String:
	if rules.focus != "balanced" and _pref(rules, cat) > 1.0:
		return "fits %s focus" % rules.focus
	return {"dmg": "more damage", "def": "better defense", "econ": "more gold"}.get(cat, "best value")

static func _rune_why(f: GameFlow, r: String, i: int) -> String:
	var d := f.run.dice[i]
	match r:
		"heavy", "blade":
			return "on die %d (avg %.1f)" % [i + 1, d.face_sum() / 6.0]
		"echo", "wild":
			return "%d dice make combos often" % f.run.dice.size()
		"ember":
			return "on die %d (most sixes)" % [i + 1]
	return "on die %d" % [i + 1]

# ------------------------------------------------------------------------------ drafts

static func _decide_draft(f: GameFlow, rules: AutoRules) -> Dictionary:
	var best := 0
	var best_v := -INF
	var why := ""
	for i in f.offer.options.size():
		var ov := _option_value(f, rules, f.offer.options[i])
		if float(ov[0]) > best_v:
			best_v = float(ov[0])
			best = i
			why = String(ov[1])
	return _result(["pick_draft", best], "Picking %s" % why)

static func _decide_rune_assign(f: GameFlow, rules: AutoRules) -> Dictionary:
	var r := String(f.offer.rune)
	var bd := _best_rune_die(f, rules, r)
	var i := int(bd[0])
	var old := f.run.dice[i].rune
	var msg := "%s Rune on die %d" % [Runes.DEFS[r].name, i + 1]
	if old != "":
		msg += " (replaces %s)" % Runes.DEFS[old].name
	return _result(["rune_assign", i], msg + ": " + _rune_why(f, r, i))

# ------------------------------------------------------------------------------ shop

## Shop: buys the best value-per-gold item worth its price; keeps a reserve for the next shop's
## die while the pool has room; restocks once when rich and nothing is worth it; then leaves.
static func _decide_shop(f: GameFlow, rules: AutoRules) -> Dictionary:
	var run := f.run
	var room := run.dice.size() < run.max_dice()
	var reserve := 40 if room else 0
	var best := -1
	var best_ratio := 0.0
	var best_die := -1
	var best_why := ""
	var gold_pt := _gold_pt(f, rules)
	for i in f.offer.items.size():
		var it: Dictionary = f.offer.items[i]
		if it.sold or int(it.price) > run.gold:
			continue
		if String(it.id) == "passive" and run.has_passive(String(it.passive)):
			continue
		if String(it.id) == "combat_reroll" and (run.shop_reroll_bought or run.combat_rerolls >= Balance.MAX_COMBAT_REROLLS):
			continue
		var ov := _option_value(f, rules, it)
		var v := float(ov[0])
		var price := float(it.price)
		if String(it.id) != "die" and run.gold - price < reserve:
			continue
		if v <= price * gold_pt * 0.35 or v <= 0.1:
			continue
		var die_idx := int(ov[2])
		if bool(it.needs_die):
			if die_idx < 0:
				continue
			if String(it.id) == "face_raise" and not run.dice[die_idx].can_raise(run.dice[die_idx].lowest_face()):
				continue
		var ratio := v / maxf(1.0, price)
		if ratio > best_ratio:
			best_ratio = ratio
			best = i
			best_die = die_idx if bool(it.needs_die) else -1
			best_why = String(ov[1])
	if best >= 0:
		return _result(["shop_buy", best, best_die], "Buying %s" % best_why)
	# one restock per visit when rich
	var restocks := 0
	for k in range(f.commands.size() - 1, -1, -1):
		var cmd: Array = f.commands[k]
		if cmd[0] == "shop_reroll":
			restocks += 1
		elif not (cmd[0] in ["shop_buy", "shop_reroll"]):
			break
	if restocks == 0 and run.gold >= 110 + reserve:
		return _result(["shop_reroll"], "Restocking: nothing here is worth buying (%d gold)" % run.gold)
	var msg := "Leaving the shop"
	if room and run.gold > 0:
		msg += ": saving gold for a die"
	return _result(["shop_leave"], msg)

# ------------------------------------------------------------------------------ forge

static func _decide_forge(f: GameFlow, rules: AutoRules) -> Dictionary:
	var ops: Array = f.offer.get("ops", ["raise"])
	var e := _best_face_edit(f, rules, ops)
	if int(e[0]) < 0:
		return _result(["forge_apply", 0, 0, "skip", -1], "Every face is maxed: skipping")
	var d := f.run.dice[int(e[0])]
	var msg := ""
	if String(e[2]) == "mirror":
		msg = "Mirroring a %d onto die %d's %d" % [d.faces[int(e[3])], int(e[0]) + 1, d.faces[int(e[1])]]
	else:
		msg = "Raising die %d's %d to %d" % [int(e[0]) + 1, d.faces[int(e[1])], d.faces[int(e[1])] + 1]
	return _result(["forge_apply", int(e[0]), int(e[1]), String(e[2]), int(e[3])], msg)

# ------------------------------------------------------------------------------ events

static func _decide_event(f: GameFlow, rules: AutoRules) -> Dictionary:
	var run := f.run
	var ch: Array = f.offer.choices
	var id := String(f.offer.id)
	var vals: Array[float] = []
	var whys: Array[String] = []
	var hp_pt := _hp_pt(f, rules)
	var gold_pt := _gold_pt(f, rules)
	for i in ch.size():
		var c: Dictionary = ch[i]
		var v := 0.0
		var why := String(c.label)
		match id:
			"shrine":
				if c.has("passive"):
					v = _passive_value(f, rules, String(c.passive))
					why = "%s: %s" % [c.label, _cat_why(rules, String(PASSIVE_CAT.get(String(c.passive), "dmg")))]
				else:
					match String(c.get("blessing", "")):
						"atk":
							v = float(Balance.SHRINE_ATK) * _pref(rules, "dmg")
						"max_hp":
							v = Balance.SHRINE_MAX_HP * 2.0 * hp_pt
						"gold":
							v = Balance.SHRINE_GOLD * gold_pt
						"face":
							v = 0.4
			"duel":
				v = 0.0 if int(c.bet) == 0 else -0.05 # fair odds with ties: not worth it
				if int(c.bet) == 0:
					why = "Walking away: the duel is a coin flip"
			"merchant":
				if i == 0:
					var gain := 0.0
					for r in Runes.of_rarity("rare"):
						gain += float(_best_rune_die(f, rules, r)[1]) * _pref(rules, String(RUNE_CAT.get(r, "dmg")))
					gain /= Runes.of_rarity("rare").size()
					v = gain - run.pct_of_max(Balance.MERCHANT_HP_PCT) * hp_pt * 2.5
					why = "Trading max HP for a Rare rune"
				else:
					why = "Keeping my max HP"
			"idol":
				if i == 0:
					var dd := _dice_desc(run.dice)
					for k in dd.size():
						var fc: PackedInt32Array = dd[k][0]
						var lo := run.dice[k].lowest_face()
						if run.dice[k].can_raise(lo):
							fc[lo] += 1
						dd[k][0] = fc
					v = _pool_value(dd, Array(run.passives), run, rules) - _pv_run(f, rules)
					v -= Balance.IDOL_DAMAGE * hp_pt
					if run.hp - Balance.IDOL_DAMAGE < run.max_hp * 0.35:
						v -= RUN_VALUE * 0.1
					why = "Blood for better faces on every die"
				else:
					why = "Too risky to bleed now"
			"dicesmith":
				if c.has("kind"):
					var kind := String(c.kind)
					if run.dice.size() < run.max_dice():
						v = _new_die_gain(f, rules, kind)
					else:
						var dd2 := _dice_desc(run.dice)
						var weakest := 0
						for k in run.dice.size():
							if run.dice[k].face_sum() < run.dice[weakest].face_sum():
								weakest = k
						dd2[weakest][0] = DiceKinds.faces(kind)
						v = _pool_value(dd2, Array(run.passives), run, rules) - _pv_run(f, rules)
					why = String(c.label)
		if not bool(c.enabled):
			v = -INF
		vals.append(v)
		whys.append(why)
	var best := -1
	for i in vals.size():
		if best < 0 or vals[i] > vals[best]:
			best = i
	if best < 0 or vals[best] == -INF:
		best = 0
		for i in ch.size():
			if bool(ch[i].enabled):
				best = i
				break
	return _result(["event_choose", best], whys[best] if best < whys.size() else "Choosing")

# ------------------------------------------------------------------------------ board

## Rough expected HP lost fighting `ids` now (enemies die weakest first at our damage rate).
static func _fight_loss(f: GameFlow, rules: AutoRules, ids: Array, elite: bool) -> float:
	var run := f.run
	var dpt := _dpt(f, rules)
	var hps: Array = []
	var atks: Array = []
	for id in ids:
		var sid := String(id)
		var boss := EnemyDefs.is_boss(sid)
		var scale := 1.0 if boss else Balance.enemy_scale(run.lap)
		var hm := scale * (Balance.ELITE_HP_MULT if elite else 1.0)
		var am := scale * (Balance.ELITE_ATK_MULT if elite else 1.0)
		hps.append(float(EnemyDefs.def(sid).hp) * hm)
		atks.append(_avg_attack(sid, am, 0))
	var order := range(hps.size())
	order.sort_custom(func(a, b): return hps[a] < hps[b])
	var cum := 0.0
	var loss := 0.0
	var t_all := 0.0
	for k in order:
		cum += float(hps[k])
		var acts := maxf(0.0, ceilf(cum / dpt) - 1.0)
		loss += acts * float(atks[k]) * 0.8
		t_all = acts + 1.0
	var guard := 0.0
	for d in run.dice:
		if d.rune == "guard":
			guard += d.face_sum() / 6.0
	if run.has_passive("iron_skin"):
		guard += Balance.PASSIVE_IRON_SKIN
	return maxf(0.0, loss - guard * t_all * 0.8)

## Expected damage per combat turn (single roll, plus a bit for rerolls).
static func _dpt(f: GameFlow, rules: AutoRules) -> float:
	var pv := _pv_run(f, rules)
	return maxf(3.0, pv * (0.8 + 0.1 * f.run.combat_rerolls))

static func _fight_value(f: GameFlow, rules: AutoRules, t: Dictionary) -> float:
	var run := f.run
	var ids: Array = t.enemies
	if ids.is_empty():
		return 0.0
	var elite := bool(t.elite)
	var mini_ := String(t.type) == "miniboss"
	if mini_:
		if rules.fight_miniboss == "always":
			return 100.0
		if rules.fight_miniboss == "never":
			return -100.0
	var gold := 0.0
	var xp := 0.0
	for id in ids:
		var def := EnemyDefs.def(String(id))
		var m := Balance.ELITE_REWARD_MULT if elite else 1.0
		gold += float(def.gold) * m * Balance.gold_scale(run.lap)
		xp += float(def.xp) * m
	var xp_pt := 2.2 / maxf(6.0, float(Balance.xp_for_level(run.level) - (Balance.xp_for_level(run.level - 1) if run.level > 1 else 0)))
	var v := gold * _gold_pt(f, rules) + xp * xp_pt
	if elite:
		v += 2.0
	if mini_:
		v += 5.0
	var loss := _fight_loss(f, rules, ids, elite)
	v -= loss * _hp_pt(f, rules)
	var q := loss / maxf(1.0, float(run.hp))
	v -= RUN_VALUE * pow(clampf((q - 0.45) / 0.8, 0.0, 1.0), 2.0)
	return v

## PV worth of landing on tile idx (crossing: the move passes Start).
static func _tile_value(f: GameFlow, rules: AutoRules, idx: int, crossing: bool, portal_ok := true) -> float:
	var run := f.run
	var t: Dictionary = run.board.tiles[idx]
	var hp_pt := _hp_pt(f, rules)
	var gold_pt := _gold_pt(f, rules)
	var v := 0.0
	if crossing and run.lap >= Balance.TOTAL_LAPS:
		# the final boss: go in as healthy as possible
		return -float(run.max_hp - run.hp) * hp_pt * 0.5
	match String(t.type):
		"enemy", "elite", "miniboss":
			v = _fight_value(f, rules, t)
		"chest":
			v = 0.5 * 1.5 + 0.5 * 18.0 * Balance.gold_scale(run.lap) * gold_pt * (1.5 if run.has_passive("treasure_sense") else 1.0)
		"event":
			v = 0.9
		"campfire":
			var pct := Balance.GLADE_CAMPFIRE_HEAL_PCT if run.board.biome == "glade" else Balance.CAMPFIRE_HEAL_PCT
			v = minf(run.pct_of_max(pct), run.max_hp - run.hp) * hp_pt
		"trap":
			var dmg := float(run.pct_of_max(Balance.TRAP_DAMAGE_PCT))
			v = -0.5 * dmg * hp_pt
			if dmg >= run.hp:
				v -= 0.5 * RUN_VALUE
			if run.board.biome == "crypt":
				v += 0.5 * Balance.CRYPT_DODGE_GOLD * gold_pt
		"ice":
			v = -0.5 * 0.4
		"lava":
			v = -float(run.pct_of_max(Balance.LAVA_LAND_PCT)) * hp_pt
		"forge":
			v = 0.6 * (2.0 if run.has_passive("blacksmith") else 1.0)
		"treasury":
			v = run.treasury * gold_pt
		"portal":
			if portal_ok:
				var best := 0.0
				for p in f._portal_tiles(idx):
					best = maxf(best, _tile_value(f, rules, int(p), int(p) <= idx, false))
				v = best * 0.9
	if crossing:
		v += 0.15
	return v

## Value of the current board roll's landing (incl. lava passed on the way).
static func _move_value(f: GameFlow, rules: AutoRules, move: int, memo: Dictionary) -> float:
	if memo.has(move):
		return memo[move]
	var run := f.run
	var v := 0.0
	if move > 0:
		var crossing := run.board.crosses_start(run.pos, move)
		var target := 0 if (crossing and run.lap >= Balance.TOTAL_LAPS) else run.board.landing(run.pos, move)
		v = _tile_value(f, rules, target, crossing)
		var p := run.board.path(run.pos, move)
		for k in range(0, p.size() - 1):
			if String(run.board.tiles[p[k]].type) == "lava":
				v -= float(run.pct_of_max(Balance.LAVA_PASS_PCT)) * _hp_pt(f, rules)
			if p[k] == 0:
				break
	memo[move] = v
	return v

static func _tile_label(f: GameFlow, idx: int) -> String:
	var t: Dictionary = f.run.board.tiles[idx]
	var ty := String(t.type)
	if (ty == "enemy" or ty == "elite") and t.enemies.is_empty():
		return "a cleared tile"
	return {"enemy": "a fight", "elite": "an elite fight", "miniboss": "the mini-boss", "chest": "a chest",
		"event": "an event", "campfire": "a campfire", "trap": "a trap", "ice": "ice", "lava": "lava",
		"forge": "the Forge", "treasury": "the Treasury", "portal": "the Portal", "start": "Start",
		"empty": "an empty tile"}.get(ty, ty)

static func _decide_board(f: GameFlow, rules: AutoRules) -> Dictionary:
	var run := f.run
	var target := f.board_target()
	var crossing := run.board.crosses_start(run.pos, f.board_move)
	var boss_next := f.board_move > 0 and crossing and run.lap >= Balance.TOTAL_LAPS
	var tile: Dictionary = run.board.tiles[target]
	var mini_next: bool = f.board_move > 0 and String(tile.type) == "miniboss" and not tile.enemies.is_empty()
	if boss_next and rules.stop_before_boss:
		return _stop("The final boss is next.")
	if mini_next and rules.stop_before_miniboss:
		return _stop("The mini-boss is next.")
	var memo := {}
	var cur := _move_value(f, rules, f.board_move, memo)
	var label := "the boss" if boss_next else _tile_label(f, target)
	if f.board_rerolls_left > 0:
		# distribution of the next roll's move (private Rng)
		var rng := Rng.new(hash([run.seed, run.stats.get("board_turns", 0), f.board_rerolls_left, run.pos, f.board_roll]))
		var moves: Array[int] = []
		var vals: Array[int] = []
		vals.resize(run.dice.size())
		for s in BOARD_SAMPLES:
			for i in run.dice.size():
				vals[i] = run.dice[i].faces[rng.randi_range(0, 5)]
			var pick := GameFlow.pick_move_dice(vals, rng)
			var m := 0
			for i in pick:
				m += vals[i]
			moves.append(m)
		var sc := PackedFloat64Array()
		var ev := 0.0
		for m in moves:
			var mv := _move_value(f, rules, m, memo)
			sc.append(mv)
			ev += mv
		ev /= moves.size()
		for r in range(1, f.board_rerolls_left):
			var nv := 0.0
			for x in sc:
				nv += maxf(x, ev)
			ev = nv / sc.size()
		if ev > cur + 0.05:
			return _result(["board_reroll"], "Rerolling: %s is worse than an average roll" % label)
	return _result(["confirm_move"], "Moving %d to %s" % [f.board_move, label])

static func _decide_portal(f: GameFlow, rules: AutoRules) -> Dictionary:
	var run := f.run
	var best := -1
	var best_v := -INF
	for t in f.offer.tiles:
		var ti := int(t)
		var v := _tile_value(f, rules, ti, ti < run.pos or ti == 0, false)
		if v > best_v:
			best_v = v
			best = ti
	var tile: Dictionary = run.board.tiles[best]
	if best == 0 and run.lap >= Balance.TOTAL_LAPS and rules.stop_before_boss:
		return _stop("The final boss is next.")
	if String(tile.type) == "miniboss" and not tile.enemies.is_empty() and rules.stop_before_miniboss:
		return _stop("The mini-boss is in portal range.")
	return _result(["portal_pick", best], "Jumping to %s" % ("the boss" if best == 0 and run.lap >= Balance.TOTAL_LAPS else _tile_label(f, best)))
