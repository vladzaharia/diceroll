class_name CombatState
extends RefCounted
## One fight. Owned by GameFlow while phase == COMBAT. All methods take the RunState so
## dice, hero HP and the seeded Rng come from the run.

var enemies: Array[Dictionary] = []
var dice_values: Array[int] = []
var marked: Array[bool] = []
var locked: Array[bool] = []
var rerolls_left: int = 0
var target: int = 0
var turn: int = 0
var last_combo: Dictionary = {}
# extras
var dice_faces: Array[int] = []    # rolled face index per die
var rerolled: Array[bool] = []     # die rerolled at least once this turn
var boss: bool = false
var elite: bool = false
var tile: int = -1
var act: int = 1
var lap: int = 1
var pending_curse: int = 0         # dice to lock at the start of the next player turn
var chaos: Array[Dictionary] = []  # [{die, face, value}] original faces to restore after the fight
var result: String = ""            # "" | "won" | "lost"
var gold_reward: int = 0
var xp_reward: int = 0

# ---------------------------------------------------------------- setup

func begin(run: RunState, ids: Array, p_elite: bool, p_boss: bool, p_tile: int) -> Array[Dictionary]:
	elite = p_elite
	boss = p_boss
	tile = p_tile
	act = run.act
	lap = run.lap
	for id in ids:
		enemies.append(make_enemy(run.rng, String(id), act, lap, elite))
	var ev: Array[Dictionary] = []
	ev.append({"type": "combat_started", "enemies": enemies.duplicate(true), "boss": boss, "elite": elite, "tile": tile})
	for i in enemies.size():
		roll_intent(run.rng, i)
		ev.append({"type": "enemy_intent", "enemy_idx": i, "intent": enemies[i].intent.duplicate()})
	ev.append_array(start_turn(run))
	return ev

static func make_enemy(rng: Rng, id: String, p_act: int, p_lap: int, p_elite: bool, summoned := false) -> Dictionary:
	var is_boss := EnemyDefs.is_boss(id)
	var def := EnemyDefs.def(id)
	var scale := 1.0 if is_boss else Balance.enemy_scale(p_act, p_lap)
	var hp_mult := scale * (Balance.ELITE_HP_MULT if p_elite else 1.0)
	var atk_mult := scale * (Balance.ELITE_ATK_MULT if p_elite else 1.0)
	var hp := int(round(float(def.hp) * hp_mult))
	var step := 0
	if not is_boss and def.mode == "cycle":
		step = rng.randi_range(0, def.pattern.size() - 1)
	return {
		"id": id, "name": String(def.name), "hp": hp, "max_hp": hp, "block": 0, "atk_bonus": 0,
		"poison": 0, "frozen": false, "intent": {"kind": "aim", "value": 0}, "boss": is_boss, "phase": 1,
		"elite": p_elite, "atk_mult": atk_mult, "step": step, "summoned": summoned,
	}

func alive(i: int) -> bool:
	return i >= 0 and i < enemies.size() and int(enemies[i].hp) > 0

func alive_indices() -> Array[int]:
	var out: Array[int] = []
	for i in enemies.size():
		if alive(i):
			out.append(i)
	return out

func all_dead() -> bool:
	return alive_indices().is_empty()

func _summoned_alive() -> int:
	var n := 0
	for i in enemies.size():
		if alive(i) and not enemies[i].boss:
			n += 1
	return n

func roll_intent(rng: Rng, i: int) -> void:
	var e := enemies[i]
	var pattern: Array
	var mode := "cycle"
	if e.boss:
		pattern = EnemyDefs.BOSSES[e.id].phases[int(e.phase) - 1]
	else:
		pattern = EnemyDefs.ENEMIES[e.id].pattern
		mode = EnemyDefs.ENEMIES[e.id].mode
	var entry: Dictionary
	for attempt in pattern.size():
		if mode == "random":
			entry = rng.pick(pattern)
		else:
			entry = pattern[int(e.step) % pattern.size()]
			e.step = int(e.step) + 1
		if entry.kind == "summon" and _summoned_alive() >= Balance.MAX_SUMMONED_ALIVE:
			continue
		break
	if entry.kind == "summon" and _summoned_alive() >= Balance.MAX_SUMMONED_ALIVE:
		entry = {"kind": "block", "value": 8}
	var value := int(entry.value)
	match String(entry.kind):
		"attack":
			value = int(round(value * float(e.atk_mult))) + int(e.atk_bonus)
		"block":
			value = int(round(value * float(e.atk_mult)))
	e.intent = {"kind": String(entry.kind), "value": value}

# ---------------------------------------------------------------- player turn

func start_turn(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	turn += 1
	run.stats.combat_turns = int(run.stats.get("combat_turns", 0)) + 1
	run.block = 0
	rerolls_left = run.combat_rerolls + run.banked_rerolls
	run.banked_rerolls = 0
	var n := run.dice.size()
	marked.resize(n)
	marked.fill(false)
	locked.resize(n)
	locked.fill(false)
	rerolled.resize(n)
	rerolled.fill(false)
	dice_values.resize(n)
	dice_faces.resize(n)
	var lock_list: Array[int] = []
	if pending_curse > 0:
		var idx: Array = range(n)
		run.rng.shuffle(idx)
		for k in mini(pending_curse, n):
			locked[idx[k]] = true
			lock_list.append(idx[k])
		pending_curse = 0
	lock_list.sort()
	ev.append({"type": "combat_turn_started", "turn": turn, "rerolls_left": rerolls_left, "locked": lock_list, "hero_block": 0})
	for i in lock_list:
		ev.append({"type": "status", "target": "hero", "status": "curse", "value": 1, "die_idx": i})
	var all: Array[int] = []
	for i in n:
		dice_faces[i] = run.dice[i].roll(run.rng)
		dice_values[i] = run.dice[i].value(dice_faces[i])
		all.append(i)
	ev.append({"type": "dice_rolled", "values": dice_values.duplicate(), "indices": all, "context": "combat", "faces": dice_faces.duplicate(), "rerolls_left": rerolls_left})
	return ev

func toggle(i: int) -> Array[Dictionary]:
	if i < 0 or i >= dice_values.size():
		return [_err("bad die index")]
	if locked[i]:
		return [_err("die is cursed")]
	if rerolls_left <= 0 and not marked[i]:
		return [_err("no rerolls left")]
	marked[i] = not marked[i]
	return [{"type": "die_marked", "die_idx": i, "marked": marked[i]}]

func reroll(run: RunState) -> Array[Dictionary]:
	if rerolls_left <= 0:
		return [_err("no rerolls left")]
	var idx: Array[int] = []
	for i in marked.size():
		if marked[i]:
			idx.append(i)
	if idx.is_empty():
		return [_err("no dice marked")]
	rerolls_left -= 1
	for i in idx:
		dice_faces[i] = run.dice[i].roll(run.rng)
		dice_values[i] = run.dice[i].value(dice_faces[i])
		rerolled[i] = true
		marked[i] = false
	return [{"type": "dice_rolled", "values": dice_values.duplicate(), "indices": idx, "context": "combat", "faces": dice_faces.duplicate(), "rerolls_left": rerolls_left}]

func set_target(i: int) -> Array[Dictionary]:
	if not alive(i):
		return [_err("invalid target")]
	target = i
	return [{"type": "target_changed", "enemy_idx": i}]

## Best combo for the current dice (Wild aware), without resolving anything.
func current_combo(run: RunState) -> Dictionary:
	var wild: Array[bool] = []
	for d in run.dice:
		wild.append(d.rune == "wild")
	return Combo.evaluate(dice_values, wild)

func _fix_target() -> void:
	if not alive(target):
		var a := alive_indices()
		target = a[0] if not a.is_empty() else 0

# ---------------------------------------------------------------- resolution

func attack(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	_fix_target()
	var combo := current_combo(run)
	var eff: Array = combo.values
	var group: Array = combo.group
	var mult := float(combo.mult)
	var sum := 0
	var bonus := 0
	for i in run.dice.size():
		var pips := int(eff[i])
		var rune := run.dice[i].rune
		var in_group := group.has(i)
		if rune == "heavy":
			sum += pips * 2
			ev.append(_rune(i, rune, "double_pips", pips))
		else:
			sum += pips
		if rune == "blade" and in_group:
			bonus += pips
			ev.append(_rune(i, rune, "bonus_damage", pips))
		if rune == "echo" and in_group:
			mult += 0.5
			ev.append(_rune(i, rune, "mult", 0))
		if rune == "wild":
			ev.append(_rune(i, rune, "wild", pips))
	var total := int(floor((sum + bonus) * mult)) + run.atk
	last_combo = {"id": combo.id, "name": combo.name, "mult": mult, "base_mult": float(combo.mult), "group": group.duplicate(), "total": total, "values": eff.duplicate()}
	ev.append({"type": "combo", "id": combo.id, "name": combo.name, "mult": mult, "group": group.duplicate(), "total": total, "values": eff.duplicate(), "sum": sum + bonus})
	if mult > float(run.stats.get("best_mult", 0.0)):
		run.stats.best_mult = mult
		run.stats.best_combo = combo.name
	ev.append_array(damage_enemy(target, total, "attack", run))
	# Ember (SIX): 6 to all
	for i in run.dice.size():
		if run.dice[i].rune == "ember" and int(eff[i]) == 6:
			ev.append(_rune(i, "ember", "damage_all", 6))
			for j in enemies.size():
				if alive(j):
					ev.append_array(damage_enemy(j, 6, "ember", run))
	# Thunder (REROLLED): pips to a random enemy
	for i in run.dice.size():
		if run.dice[i].rune == "thunder" and rerolled[i]:
			var a := alive_indices()
			if a.is_empty():
				break
			var j: int = run.rng.pick(a)
			ev.append(_rune(i, "thunder", "damage_random", int(eff[i])))
			ev.append_array(damage_enemy(j, int(eff[i]), "thunder", run))
	_fix_target()
	for i in run.dice.size():
		var rune := run.dice[i].rune
		var pips := int(eff[i])
		var in_group := group.has(i)
		match rune:
			"venom":
				if in_group and alive(target):
					enemies[target].poison = int(enemies[target].poison) + pips
					ev.append(_rune(i, rune, "poison", pips))
					ev.append({"type": "status", "target": target, "status": "poison", "value": int(enemies[target].poison)})
			"frost":
				if pips == 1 and alive(target):
					enemies[target].frozen = true
					ev.append(_rune(i, rune, "freeze", 1))
					ev.append({"type": "status", "target": target, "status": "frozen", "value": 1})
			"guard":
				run.block += pips
				ev.append(_rune(i, rune, "block", pips))
				ev.append({"type": "block_gained", "target": "hero", "amount": pips, "total": run.block})
			"vampire":
				if in_group:
					var healed := run.heal(pips)
					ev.append(_rune(i, rune, "heal", healed))
					ev.append({"type": "hp_changed", "amount": healed, "total": run.hp, "source": "vampire"})
			"gilded":
				if in_group:
					run.gold += 2
					run.stats.gold_earned = int(run.stats.get("gold_earned", 0)) + 2
					ev.append(_rune(i, rune, "gold", 2))
					ev.append({"type": "gold_changed", "amount": 2, "total": run.gold, "source": "gilded"})
			"lucky":
				if not rerolled[i] and run.banked_rerolls < Balance.MAX_BANKED_REROLLS:
					run.banked_rerolls += 1
					ev.append(_rune(i, rune, "bank_reroll", 1))
	if all_dead():
		ev.append_array(_win(run))
		return ev
	ev.append_array(_enemy_phase(run))
	if result == "":
		ev.append_array(start_turn(run))
	return ev

func damage_enemy(i: int, amount: int, source: String, run: RunState, ignore_block := false) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if not alive(i) or amount <= 0:
		return ev
	var e := enemies[i]
	var blocked := 0
	if not ignore_block:
		blocked = mini(int(e.block), amount)
		e.block = int(e.block) - blocked
	var dealt := mini(amount - blocked, int(e.hp))
	e.hp = int(e.hp) - dealt
	run.stats.damage_dealt = int(run.stats.get("damage_dealt", 0)) + dealt
	var lethal := int(e.hp) <= 0
	ev.append({"type": "damage", "target": i, "amount": dealt, "blocked": blocked, "source": source, "lethal": lethal, "hp": int(e.hp), "max_hp": int(e.max_hp), "block": int(e.block)})
	if lethal:
		e.poison = 0
		e.frozen = false
		ev.append({"type": "enemy_died", "enemy_idx": i, "id": e.id})
	elif e.boss and int(e.phase) == 1 and int(e.hp) * 2 <= int(e.max_hp):
		e.phase = 2
		e.step = 0
		ev.append({"type": "boss_phase", "enemy_idx": i, "phase": 2})
	return ev

func _enemy_phase(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var count := enemies.size()
	for i in count:
		if not alive(i):
			continue
		var e := enemies[i]
		e.block = 0
		if int(e.poison) > 0:
			var p := int(e.poison)
			ev.append_array(damage_enemy(i, p, "poison", run, true))
			if alive(i):
				e.poison = p - 1
				ev.append({"type": "status", "target": i, "status": "poison", "value": int(e.poison)})
			else:
				if all_dead():
					ev.append_array(_win(run))
					return ev
				continue
		if bool(e.frozen):
			e.frozen = false
			ev.append({"type": "status", "target": i, "status": "frozen", "value": 0, "skipped": true})
		else:
			ev.append_array(_execute_intent(run, i))
			if result == "lost":
				return ev
		roll_intent(run.rng, i)
		ev.append({"type": "enemy_intent", "enemy_idx": i, "intent": e.intent.duplicate()})
	return ev

func _execute_intent(run: RunState, i: int) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var e := enemies[i]
	var v := int(e.intent.value)
	match String(e.intent.kind):
		"attack":
			var blocked := mini(run.block, v)
			run.block -= blocked
			var dealt := mini(v - blocked, run.hp)
			run.hp -= dealt
			run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + dealt
			ev.append({"type": "damage", "target": "hero", "amount": dealt, "blocked": blocked, "source": String(e.id), "attacker": i, "lethal": run.hp <= 0, "hp": run.hp, "max_hp": run.max_hp, "block": run.block})
			if run.hp <= 0:
				result = "lost"
		"block":
			e.block = int(e.block) + v
			ev.append({"type": "block_gained", "target": i, "amount": v, "total": int(e.block)})
		"buff":
			e.atk_bonus = int(e.atk_bonus) + v
			ev.append({"type": "status", "target": i, "status": "buff", "value": int(e.atk_bonus)})
		"curse":
			pending_curse += v
			ev.append({"type": "status", "target": "hero", "status": "curse", "value": v, "source": i, "pending": true})
		"summon":
			for k in maxi(1, v):
				if _summoned_alive() >= Balance.MAX_SUMMONED_ALIVE:
					break
				var m := make_enemy(run.rng, EnemyDefs.SUMMON_ID, act, 1, false, true)
				enemies.append(m)
				var idx := enemies.size() - 1
				roll_intent(run.rng, idx)
				ev.append({"type": "summon", "enemy": m.duplicate(true), "enemy_idx": idx, "source": i})
				ev.append({"type": "enemy_intent", "enemy_idx": idx, "intent": m.intent.duplicate()})
		"chaos":
			var options: Array = []
			for d in run.dice.size():
				for f in 6:
					if run.dice[d].faces[f] > 1:
						options.append([d, f])
			if not options.is_empty():
				var pick: Array = run.rng.pick(options)
				var d: int = pick[0]
				var f: int = pick[1]
				chaos.append({"die": d, "face": f, "value": run.dice[d].faces[f]})
				run.dice[d].faces[f] = 1
				ev.append({"type": "status", "target": "hero", "status": "chaos", "value": 1, "die_idx": d, "face_idx": f, "source": i})
		_:
			pass # aim: nothing
	return ev

func _win(run: RunState) -> Array[Dictionary]:
	result = "won"
	var gold_mult := 1.0 + Balance.GOLD_ACT_STEP * (act - 1)
	var g := 0.0
	var x := 0.0
	for e in enemies:
		if e.summoned:
			continue
		var def := EnemyDefs.def(e.id)
		var m := Balance.ELITE_REWARD_MULT if e.elite else 1.0
		g += float(def.gold) * m * (1.0 if e.boss else gold_mult)
		x += float(def.xp) * m
	gold_reward = int(round(g))
	xp_reward = int(round(x))
	restore_chaos(run)
	return [{"type": "combat_won", "gold": gold_reward, "xp": xp_reward, "boss": boss, "elite": elite}]

func restore_chaos(run: RunState) -> void:
	for c in chaos:
		run.dice[int(c.die)].faces[int(c.face)] = int(c.value)
	chaos.clear()

func _rune(i: int, rune: String, effect: String, value: int) -> Dictionary:
	return {"type": "rune_fired", "die_idx": i, "rune": rune, "effect": effect, "value": value}

static func _err(msg: String) -> Dictionary:
	return {"type": "error", "msg": msg}

# ---------------------------------------------------------------- serialisation

func to_dict() -> Dictionary:
	return {
		"enemies": enemies.duplicate(true), "dice_values": Array(dice_values), "marked": Array(marked),
		"locked": Array(locked), "rerolls_left": rerolls_left, "target": target, "turn": turn,
		"last_combo": last_combo.duplicate(true), "dice_faces": Array(dice_faces), "rerolled": Array(rerolled),
		"boss": boss, "elite": elite, "tile": tile, "act": act, "lap": lap, "pending_curse": pending_curse,
		"chaos": chaos.duplicate(true), "result": result, "gold_reward": gold_reward, "xp_reward": xp_reward,
	}

static func from_dict(d: Dictionary) -> CombatState:
	var c := CombatState.new()
	for ed in d.enemies:
		c.enemies.append(_norm_enemy(ed))
	for v in d.dice_values:
		c.dice_values.append(int(v))
	for v in d.dice_faces:
		c.dice_faces.append(int(v))
	for v in d.marked:
		c.marked.append(bool(v))
	for v in d.locked:
		c.locked.append(bool(v))
	for v in d.rerolled:
		c.rerolled.append(bool(v))
	for k in ["rerolls_left", "target", "turn", "tile", "act", "lap", "pending_curse", "gold_reward", "xp_reward"]:
		c.set(k, int(d[k]))
	c.boss = bool(d.boss)
	c.elite = bool(d.elite)
	c.result = String(d.result)
	c.last_combo = _norm_combo(d.last_combo)
	for ch in d.chaos:
		c.chaos.append({"die": int(ch.die), "face": int(ch.face), "value": int(ch.value)})
	return c

static func _norm_enemy(ed: Dictionary) -> Dictionary:
	return {
		"id": String(ed.id), "name": String(ed.name), "hp": int(ed.hp), "max_hp": int(ed.max_hp),
		"block": int(ed.block), "atk_bonus": int(ed.atk_bonus), "poison": int(ed.poison), "frozen": bool(ed.frozen),
		"intent": {"kind": String(ed.intent.kind), "value": int(ed.intent.value)}, "boss": bool(ed.boss),
		"phase": int(ed.phase), "elite": bool(ed.elite), "atk_mult": float(ed.atk_mult), "step": int(ed.step),
		"summoned": bool(ed.summoned),
	}

static func _norm_combo(lc: Dictionary) -> Dictionary:
	if lc.is_empty():
		return {}
	var g: Array = []
	for v in lc.group:
		g.append(int(v))
	var vals: Array = []
	for v in lc.values:
		vals.append(int(v))
	return {"id": String(lc.id), "name": String(lc.name), "mult": float(lc.mult), "base_mult": float(lc.base_mult),
		"group": g, "total": int(lc.total), "values": vals}
