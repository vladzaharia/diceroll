class_name Bot
extends RefCounted
## Greedy autoplayer used by the balance sim and the play_auto scenario.
## next_command() returns a command in GameFlow.apply() format: [name, args...].
## It is a pure function of the flow state (no randomness of its own).

const RUNE_SCORE := {
	"echo": 9, "wild": 9, "vampire": 7, "ember": 7, "blade": 6, "heavy": 6, "venom": 6,
	"thunder": 5, "lucky": 5, "frost": 5, "guard": 5, "gilded": 3,
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
		"chest":
			s = 5.0
		"event":
			s = 3.0
		"campfire":
			s = (1.0 - r) * 14.0
		"trap":
			s = -3.0
		"forge":
			s = 4.0
		"treasury":
			s = f.run.treasury / 4.0
		"portal":
			s = 2.0
		"start":
			s = 3.0
	if crossing and f.run.lap < Balance.LAPS_PER_ACT:
		s += 3.0
	return s

static func _board(f: GameFlow) -> Array:
	var best := 0
	var best_s := -INF
	var targets := f.landing_preview()
	for i in f.board_roll.size():
		var crossing := Board.crosses_start(f.run.pos, f.board_roll[i])
		var s := tile_score(f, targets[i], crossing)
		if s > best_s:
			best_s = s
			best = i
	if best_s < 1.0 and f.board_rerolls_left > 0:
		return ["board_reroll"]
	return ["choose_move", best]

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
			return 10.0
		"rune":
			return float(RUNE_SCORE.get(String(o.get("rune", "")), 4))
		"combat_reroll":
			return 8.0
		"max_hp":
			return 4.0 + (4.0 if hp_ratio(f) < 0.5 else 0.0)
		"face_raise":
			return 3.0
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
				s = 8.0 if f.run.dice.size() < Balance.MAX_DICE else 0.0
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
			for i in ch.size():
				if ch[i].get("blessing", "") == "atk":
					return i
			return 0
	for i in ch.size():
		if ch[i].enabled:
			return i
	return 0
