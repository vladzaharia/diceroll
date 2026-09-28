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
var miniboss: bool = false
var tile: int = -1
var act: int = 1
var lap: int = 1
var pending_curse: int = 0         # dice to lock at the start of the next player turn
var chaos: Array[Dictionary] = []  # [{die, face, value}] original faces to restore after the fight (Chaos, Scorch)
var hero_burn: int = 0             # Burn stacks on the hero: ticks at the end of each enemy phase
var result: String = ""            # "" | "won" | "lost"
var gold_reward: int = 0
var xp_reward: int = 0

# ---------------------------------------------------------------- setup

func begin(run: RunState, ids: Array, p_elite: bool, p_boss: bool, p_tile: int, p_miniboss := false) -> Array[Dictionary]:
	elite = p_elite
	boss = p_boss
	miniboss = p_miniboss
	tile = p_tile
	act = run.act
	lap = run.lap
	for id in ids:
		enemies.append(make_enemy(run.rng, String(id), act, lap, elite))
	for i in enemies.size():
		roll_intent(run.rng, i)
	var ev: Array[Dictionary] = []
	ev.append({"type": "combat_started", "enemies": enemies.duplicate(true), "boss": boss, "elite": elite, "miniboss": miniboss, "tile": tile})
	for i in enemies.size():
		ev.append({"type": "enemy_intent", "enemy_idx": i, "intent": enemies[i].intent.duplicate()})
	# Frostpeak ice: dice frozen on the board lock on the first turn of this fight.
	if run.chill > 0:
		pending_curse += run.chill
		ev.append({"type": "status", "target": "hero", "status": "chill", "value": run.chill})
		run.chill = 0
	ev.append_array(start_turn(run))
	return ev

static func make_enemy(rng: Rng, id: String, p_act: int, p_lap: int, p_elite: bool, summoned := false) -> Dictionary:
	var is_boss := EnemyDefs.is_boss(id)
	var def := EnemyDefs.def(id)
	var scale := 1.0 if is_boss else Balance.enemy_scale(p_lap)
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
		"miniboss": EnemyDefs.is_miniboss(id), "traits": EnemyDefs.traits(id, 1).duplicate(),
	}

static func has_trait(e: Dictionary, t: String) -> bool:
	return (e.get("traits", []) as Array).has(t)

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
		pattern = EnemyDefs.def(e.id).pattern
		mode = EnemyDefs.def(e.id).mode
	var entry: Dictionary
	if mode == "random":
		entry = rng.pick(pattern)
	else:
		entry = pattern[int(e.step) % pattern.size()]
		e.step = int(e.step) + 1
	# At the summon cap the step is spent on Block 8 instead (rule 21).
	if entry.kind == "summon" and _summoned_alive() >= Balance.MAX_SUMMONED_ALIVE:
		entry = {"kind": "block", "value": 8}
	var value := int(entry.value)
	match String(entry.kind):
		"attack", "chill", "drain":
			value = int(round(value * float(e.atk_mult))) + int(e.atk_bonus)
		"block", "heal":
			value = int(round(value * float(e.atk_mult)))
		"burn":
			# Burn stacks decay by 1 per tick, so they scale at half the attack rate.
			value = int(round(value * (1.0 + (float(e.atk_mult) - 1.0) * Balance.BURN_SCALE)))
	e.intent = {"kind": String(entry.kind), "value": value}

# ---------------------------------------------------------------- player turn

func start_turn(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	turn += 1
	run.stats.combat_turns = int(run.stats.get("combat_turns", 0)) + 1
	run.block = 0
	rerolls_left = run.combat_rerolls + run.banked_rerolls
	run.banked_rerolls = 0
	var pev: Array[Dictionary] = []
	if run.has_passive("loaded_hands") and turn == 1:
		rerolls_left += 1
		pev.append(_passive("loaded_hands", 1))
	if run.has_passive("iron_skin"):
		run.block = Balance.PASSIVE_IRON_SKIN
		pev.append(_passive("iron_skin", run.block))
		pev.append({"type": "block_gained", "target": "hero", "amount": run.block, "total": run.block})
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
	ev.append({"type": "combat_turn_started", "turn": turn, "rerolls_left": rerolls_left, "locked": lock_list, "hero_block": run.block})
	ev.append_array(pev)
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
	var before_mult := float(current_combo(run).mult)
	rerolls_left -= 1
	for i in idx:
		dice_faces[i] = run.dice[i].roll(run.rng)
		dice_values[i] = run.dice[i].value(dice_faces[i])
		rerolled[i] = true
		marked[i] = false
	var ev: Array[Dictionary] = []
	if run.has_passive("encore") and float(current_combo(run).mult) > before_mult:
		rerolls_left += 1
		ev.append(_passive("encore", 1))
	ev.push_front({"type": "dice_rolled", "values": dice_values.duplicate(), "indices": idx, "context": "combat", "faces": dice_faces.duplicate(), "rerolls_left": rerolls_left})
	return ev

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

## Combo multiplier after combo passives (Crowd Pleaser, Pair Master, Triple Threat).
static func passive_mult(run: RunState, combo_id: String, base: float) -> float:
	var m := base
	if combo_id == "pair" and run.has_passive("crowd_pleaser"):
		m = maxf(m, float(Combo.TABLE.three_kind.mult))
	if (combo_id == "pair" or combo_id == "two_pair") and run.has_passive("pair_master"):
		m += Balance.PASSIVE_PAIR_BONUS
	if combo_id in ["three_kind", "four_kind", "five_kind", "six_kind"] and run.has_passive("triple_threat"):
		m += Balance.PASSIVE_SET_BONUS
	return m

func attack(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	_fix_target()
	var combo := current_combo(run)
	var eff: Array = combo.values
	var group: Array = combo.group
	var cid := String(combo.id)
	var mult := passive_mult(run, cid, float(combo.mult))
	if cid == "pair" and run.has_passive("crowd_pleaser"):
		ev.append(_passive("crowd_pleaser", 0))
	if (cid == "pair" or cid == "two_pair") and run.has_passive("pair_master"):
		ev.append(_passive("pair_master", 0))
	if cid in ["three_kind", "four_kind", "five_kind", "six_kind"] and run.has_passive("triple_threat"):
		ev.append(_passive("triple_threat", 0))
	# How many times each die's rune triggers (Resonance: combo dice x2; Rune Echo: 25% x2).
	var times: Array[int] = []
	for i in run.dice.size():
		var t := 1
		if run.dice[i].rune != "" and group.has(i):
			if run.has_passive("resonance"):
				t = 2
			elif run.has_passive("rune_echo") and run.rng.chance(Balance.PASSIVE_RUNE_ECHO_CHANCE):
				t = 2
				ev.append(_passive("rune_echo", i))
		times.append(t)
	var sum := 0
	var bonus := 0
	var flat := 0
	var steady := 0
	var boxcars := 0
	var snakes := 0
	for i in run.dice.size():
		var pips := int(eff[i])
		var rune := run.dice[i].rune
		var in_group := group.has(i)
		if rune == "heavy":
			sum += pips * (1 + times[i])
			for k in times[i]:
				ev.append(_rune(i, rune, "double_pips", pips))
		else:
			sum += pips
		if rune == "blade" and in_group:
			bonus += pips * times[i]
			for k in times[i]:
				ev.append(_rune(i, rune, "bonus_damage", pips))
		if rune == "echo" and in_group:
			mult += 0.5 * times[i]
			for k in times[i]:
				ev.append(_rune(i, rune, "mult", 0))
		if rune == "wild":
			ev.append(_rune(i, rune, "wild", pips))
		if run.has_passive("steady_hand") and not rerolled[i]:
			steady += 1
		if run.has_passive("boxcars") and in_group and pips == 6:
			boxcars += Balance.PASSIVE_BOXCARS
		if run.has_passive("snake_eyes") and pips == 1:
			snakes += Balance.PASSIVE_SNAKE_EYES
	if steady > 0:
		bonus += steady
		ev.append(_passive("steady_hand", steady))
	if boxcars > 0:
		bonus += boxcars
		ev.append(_passive("boxcars", boxcars))
	if snakes > 0:
		flat += snakes
		ev.append(_passive("snake_eyes", snakes))
	if run.has_passive("straight_shooter") and (cid == "straight" or cid == "small_straight"):
		flat += Balance.PASSIVE_STRAIGHT_DAMAGE
		ev.append(_passive("straight_shooter", Balance.PASSIVE_STRAIGHT_DAMAGE))
	if run.has_passive("midas_fist"):
		var m := mini(Balance.PASSIVE_MIDAS_MAX, run.gold / Balance.PASSIVE_MIDAS_GOLD)
		if m > 0:
			flat += m
			ev.append(_passive("midas_fist", m))
	var factor := 1.0
	if run.has_passive("glass_cannon"):
		factor *= Balance.PASSIVE_DAMAGE_MULT
		ev.append(_passive("glass_cannon", 0))
	if run.has_passive("opening_salvo") and turn == 1:
		factor *= Balance.PASSIVE_DAMAGE_MULT
		ev.append(_passive("opening_salvo", 0))
	var total := int(floor(((sum + bonus) * mult + flat) * factor)) + run.atk
	last_combo = {"id": combo.id, "name": combo.name, "mult": mult, "base_mult": float(combo.mult), "group": group.duplicate(), "total": total, "values": eff.duplicate()}
	ev.append({"type": "combo", "id": combo.id, "name": combo.name, "mult": mult, "group": group.duplicate(), "total": total, "values": eff.duplicate(), "sum": sum + bonus})
	if mult > float(run.stats.get("best_mult", 0.0)):
		run.stats.best_mult = mult
		run.stats.best_combo = combo.name
	var thorny := alive(target) and has_trait(enemies[target], "thorns")
	ev.append_array(damage_enemy(target, total, "attack", run))
	if thorny and total > 0:
		# Briar thorns: reflect damage to the hero, never lethal.
		var th := mini(Balance.ENEMY_THORNS, run.hp - 1)
		if th > 0:
			run.hp -= th
			run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + th
			ev.append({"type": "damage", "target": "hero", "amount": th, "blocked": 0, "source": "thorns", "attacker": target, "lethal": false, "hp": run.hp, "max_hp": run.max_hp, "block": run.block})
	# Ember (SIX): 6 to all
	for i in run.dice.size():
		if run.dice[i].rune == "ember" and int(eff[i]) == 6:
			for k in times[i]:
				ev.append(_rune(i, "ember", "damage_all", 6))
				for j in enemies.size():
					if alive(j):
						ev.append_array(damage_enemy(j, 6, "ember", run))
	# Thunder (REROLLED): pips to a random enemy
	for i in run.dice.size():
		if run.dice[i].rune == "thunder" and rerolled[i]:
			for k in times[i]:
				var a := alive_indices()
				if a.is_empty():
					break
				var j: int = run.rng.pick(a)
				ev.append(_rune(i, "thunder", "damage_random", int(eff[i])))
				ev.append_array(damage_enemy(j, int(eff[i]), "thunder", run))
	if run.has_passive("gold_tooth"):
		var sixes := 0
		for i in run.dice.size():
			if int(eff[i]) == 6:
				sixes += 1
		if sixes > 0:
			run.gold += sixes
			run.stats.gold_earned = int(run.stats.get("gold_earned", 0)) + sixes
			ev.append(_passive("gold_tooth", sixes))
			ev.append({"type": "gold_changed", "amount": sixes, "total": run.gold, "source": "gold_tooth"})
	if run.has_passive("full_house_party") and cid == "full_house":
		var fh := run.heal(Balance.PASSIVE_FULL_HOUSE_HEAL)
		ev.append(_passive("full_house_party", Balance.PASSIVE_FULL_HOUSE_HEAL))
		ev.append({"type": "hp_changed", "amount": fh, "total": run.hp, "source": "full_house_party", "max_hp": run.max_hp})
	_fix_target()
	for i in run.dice.size():
		var rune := run.dice[i].rune
		var pips := int(eff[i])
		var in_group := group.has(i)
		for k in times[i]:
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
	var warded := false
	if has_trait(e, "ward") and _summons_alive() > 0:
		# Bone Warden's legion: half damage while any summoned ally stands.
		amount = int(ceil(amount / 2.0))
		warded = true
	var blocked := 0
	if not ignore_block:
		blocked = mini(int(e.block), amount)
		e.block = int(e.block) - blocked
	var dealt := mini(amount - blocked, int(e.hp))
	e.hp = int(e.hp) - dealt
	run.stats.damage_dealt = int(run.stats.get("damage_dealt", 0)) + dealt
	var lethal := int(e.hp) <= 0
	ev.append({"type": "damage", "target": i, "amount": dealt, "blocked": blocked, "source": source, "lethal": lethal, "hp": int(e.hp), "max_hp": int(e.max_hp), "block": int(e.block), "warded": warded})
	if lethal:
		e.poison = 0
		e.frozen = false
		ev.append({"type": "enemy_died", "enemy_idx": i, "id": e.id})
		if run.has_passive("bloodthirst"):
			var h := run.heal(Balance.PASSIVE_BLOODTHIRST)
			ev.append(_passive("bloodthirst", Balance.PASSIVE_BLOODTHIRST))
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "bloodthirst", "max_hp": run.max_hp})
	elif e.boss and int(e.phase) == 1 and int(e.hp) * 2 <= int(e.max_hp):
		var was_armored := has_trait(e, "armor")
		e.phase = 2
		e.step = 0
		e.traits = EnemyDefs.traits(String(e.id), 2).duplicate()
		ev.append({"type": "boss_phase", "enemy_idx": i, "phase": 2, "traits": e.traits.duplicate()})
		if was_armored and not has_trait(e, "armor") and int(e.block) > 0:
			# Magma Golem: the shell shatters and its stored Block is gone.
			var lost := int(e.block)
			e.block = 0
			ev.append({"type": "block_gained", "target": i, "amount": -lost, "total": 0, "source": "shatter"})
	return ev

## Living summoned allies.
func _summons_alive() -> int:
	var n := 0
	for k in enemies.size():
		if alive(k) and bool(enemies[k].summoned):
			n += 1
	return n

func _enemy_phase(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var count := enemies.size()
	for i in count:
		if not alive(i):
			continue
		var e := enemies[i]
		var old_block := int(e.block)
		if old_block > 0 and not has_trait(e, "armor"):
			e.block = 0
			ev.append({"type": "block_gained", "target": i, "amount": -old_block, "total": 0})
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
			if all_dead():
				ev.append_array(_win(run))
				return ev
			if not alive(i):
				continue
		roll_intent(run.rng, i)
		ev.append({"type": "enemy_intent", "enemy_idx": i, "intent": e.intent.duplicate()})
	ev.append_array(_tick_burn(run))
	return ev

## Burn on the hero: at the end of the enemy phase the hero takes damage equal to the stacks
## (ignoring Block), then the stacks drop by 1.
func _tick_burn(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if hero_burn <= 0 or result != "":
		return ev
	var dmg := mini(hero_burn, run.hp)
	run.hp -= dmg
	var saved := ""
	if run.hp <= 0:
		saved = run.survive_lethal()
		if saved != "":
			dmg -= 1
	run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + dmg
	ev.append({"type": "damage", "target": "hero", "amount": dmg, "blocked": 0, "source": "burn", "lethal": run.hp <= 0, "hp": run.hp, "max_hp": run.max_hp, "block": run.block})
	if saved != "":
		ev.append(_passive(saved, 1))
	hero_burn -= 1
	ev.append({"type": "status", "target": "hero", "status": "burn", "value": hero_burn})
	if run.hp <= 0:
		result = "lost"
	return ev

## Enemy i hits the hero for v (Block absorbs it unless the enemy pierces). Returns the events
## and the damage dealt through `out_dealt[0]` when given.
func _hit_hero(run: RunState, i: int, v: int, out_dealt: Array = []) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var e := enemies[i]
	var pierce := has_trait(e, "pierce")
	var blocked := 0 if pierce else mini(run.block, v)
	run.block -= blocked
	var dealt := mini(v - blocked, run.hp)
	run.hp -= dealt
	var saved := ""
	if run.hp <= 0:
		saved = run.survive_lethal()
		if saved != "":
			dealt -= 1
	run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + dealt
	ev.append({"type": "damage", "target": "hero", "amount": dealt, "blocked": blocked, "source": String(e.id), "attacker": i, "lethal": run.hp <= 0, "hp": run.hp, "max_hp": run.max_hp, "block": run.block, "pierce": pierce})
	if saved != "":
		ev.append(_passive(saved, 1))
	if run.hp <= 0:
		result = "lost"
	elif dealt > 0 and run.has_passive("thorns"):
		ev.append(_passive("thorns", Balance.PASSIVE_THORNS))
		ev.append_array(damage_enemy(i, Balance.PASSIVE_THORNS, "thorns", run))
	out_dealt.append(dealt)
	return ev

func _heal_enemy(i: int, amount: int, source: String) -> Array[Dictionary]:
	var e := enemies[i]
	var h := mini(amount, int(e.max_hp) - int(e.hp))
	if h <= 0 or not alive(i):
		return []
	e.hp = int(e.hp) + h
	return [{"type": "enemy_healed", "enemy_idx": i, "amount": h, "hp": int(e.hp), "max_hp": int(e.max_hp), "source": source}]

func _execute_intent(run: RunState, i: int) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var e := enemies[i]
	var v := int(e.intent.value)
	match String(e.intent.kind):
		"attack":
			ev.append_array(_hit_hero(run, i, v))
		"chill":
			ev.append_array(_hit_hero(run, i, v))
			if result == "":
				pending_curse += 1
				ev.append({"type": "status", "target": "hero", "status": "curse", "value": 1, "source": i, "pending": true, "chill": true})
		"drain":
			var dealt: Array = []
			ev.append_array(_hit_hero(run, i, v, dealt))
			if result == "" and alive(i) and int(dealt[0]) > 0:
				ev.append_array(_heal_enemy(i, int(dealt[0]), "drain"))
		"heal":
			for k in enemies.size():
				if alive(k):
					ev.append_array(_heal_enemy(k, v, "heal"))
		"burn":
			hero_burn += v
			ev.append({"type": "status", "target": "hero", "status": "burn", "value": hero_burn, "source": i})
		"scorch":
			var opts: Array = []
			for d in run.dice.size():
				for f in 6:
					if run.dice[d].faces[f] > 0:
						opts.append([d, f])
			if not opts.is_empty():
				var pk: Array = run.rng.pick(opts)
				var sd: int = pk[0]
				var sf: int = pk[1]
				chaos.append({"die": sd, "face": sf, "value": run.dice[sd].faces[sf]})
				run.dice[sd].faces[sf] = 0
				ev.append({"type": "status", "target": "hero", "status": "scorch", "value": 0, "die_idx": sd, "face_idx": sf, "source": i})
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
			var sdef := EnemyDefs.def(String(e.id))
			var sid := String(sdef.get("summon", EnemyDefs.SUMMON_ID))
			var slap := lap if sdef.has("summon") else 1
			for k in maxi(1, v):
				if _summoned_alive() >= Balance.MAX_SUMMONED_ALIVE:
					break
				var m := make_enemy(run.rng, sid, act, slap, false, true)
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
	var gold_mult := Balance.gold_scale(lap)
	var g := 0.0
	var x := 0.0
	for e in enemies:
		if e.summoned:
			continue
		var def := EnemyDefs.def(e.id)
		var m := Balance.ELITE_REWARD_MULT if e.elite else 1.0
		g += float(def.gold) * m * (1.0 if e.boss else gold_mult)
		x += float(def.xp) * m
	if run.has_passive("scholar"):
		x *= Balance.PASSIVE_SCHOLAR
	gold_reward = int(round(g))
	xp_reward = int(round(x))
	var ev: Array[Dictionary] = [{"type": "combat_won", "gold": gold_reward, "xp": xp_reward, "boss": boss, "elite": elite, "miniboss": miniboss}]
	ev.append_array(restore_chaos(run))
	return ev

## Restores faces set to 1 by Chaos; one face_changed event per restored face.
func restore_chaos(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	for k in range(chaos.size() - 1, -1, -1):
		var c: Dictionary = chaos[k]
		var d := int(c.die)
		var f := int(c.face)
		run.dice[d].faces[f] = int(c.value)
		ev.append({"type": "face_changed", "die_idx": d, "face_idx": f, "value": int(c.value), "faces": Array(run.dice[d].faces)})
	chaos.clear()
	return ev

static func _passive(id: String, value: int) -> Dictionary:
	return {"type": "passive_triggered", "id": id, "value": value}

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
		"boss": boss, "elite": elite, "miniboss": miniboss, "tile": tile, "act": act, "lap": lap, "pending_curse": pending_curse,
		"chaos": chaos.duplicate(true), "result": result, "gold_reward": gold_reward, "xp_reward": xp_reward,
		"hero_burn": hero_burn,
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
	c.miniboss = bool(d.get("miniboss", false))
	c.result = String(d.result)
	c.hero_burn = int(d.get("hero_burn", 0))
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
		"summoned": bool(ed.summoned), "miniboss": bool(ed.get("miniboss", false)),
		"traits": _strings(ed.get("traits", [])),
	}

static func _strings(a: Array) -> Array:
	var out: Array = []
	for x in a:
		out.append(String(x))
	return out

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
