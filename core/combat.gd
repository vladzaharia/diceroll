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
# meta layer (all 0/false in legacy runs)
var pet_block_carry: int = 0       # Guard Die L5: Block that lands again next turn
var wisp_free: int = 0             # Crystal Wisp L10: rerolls that don't mark dice as rerolled
var wisp_used: bool = false        # Crystal Wisp L10 used this fight
var potion_turn: int = 0           # turn a potion was last drunk (max one per combat turn)
var stoneskin: int = 0             # Stoneskin Block still to land at the next turn start
var boost: bool = false            # Bubble Breaker signature: +1 reroll every turn this fight
var pet_mult: float = 0.0          # Crystal Wisp: combo multiplier bonus for this turn's attack
# class mechanics (ClassLogic; all 0 for classes without them)
var rerolls_used_this_turn: int = 0 # combat rerolls spent this turn (Ranger Aim)
var refunds_this_turn: int = 0     # Ninja Shadow Step refunds this turn
var oath: int = 0                  # Paladin Oath value for this fight (0 = none)
var last_overkill: int = 0         # damage_enemy: overkill of the last lethal hit (0 otherwise)
# new biomes (docs/design/2026-09-29-new-biomes.md)
var moon: int = -99                # the Moon King's moon meter (MOON_NONE = no meter in this fight)
var transform_at: float = 0.5      # HP share at or below which transformers change (Half moon: 0.65)
var moon_full: bool = false        # fought on Moonlit's Full lap (gold x MOON_FULL_GOLD)

# ---------------------------------------------------------------- setup

## affixes (optional): per enemy, AffixDefs ids rolled at tile spawn (Board.affixes_of).
func begin(run: RunState, ids: Array, p_elite: bool, p_boss: bool, p_tile: int, p_miniboss := false, affixes: Array = []) -> Array[Dictionary]:
	elite = p_elite
	boss = p_boss
	miniboss = p_miniboss
	tile = p_tile
	act = run.act
	lap = run.eff_lap()
	for id in ids:
		enemies.append(make_enemy(run.rng, String(id), act, lap, elite))
	if run.mode == "short":
		# Short Road: fewer laps to build, so the final boss is lighter
		for e in enemies:
			if bool(e.boss):
				e.hp = maxi(1, int(round(int(e.hp) * Balance.SHORT_BOSS_HP)))
				e.max_hp = e.hp
	if not run.meta.is_empty():
		for e in enemies:
			meta_enemy(run, e)
	for k in enemies.size():
		if k < affixes.size() and not (affixes[k] as Array).is_empty() and not bool(enemies[k].boss):
			AffixDefs.apply(enemies[k], affixes[k], EnemyDefs.band(lap))
	var bev := _biome_begin(run)
	_note_seen(run)
	if not run.meta.is_empty():
		if int(run.pet_state.get("boost", 0)) > 0:
			boost = true
			run.pet_state["boost"] = int(run.pet_state.boost) - 1
		var runed := run.dice.size() >= Balance.MAX_DICE
		for d in run.dice:
			if d.rune == "":
				runed = false
		if runed:
			run.stats.full_rune_fights = int(run.stats.get("full_rune_fights", 0)) + 1
	for i in enemies.size():
		roll_intent(run.rng, i)
	var ev: Array[Dictionary] = []
	ev.append({"type": "combat_started", "enemies": enemies.duplicate(true), "boss": boss, "elite": elite, "miniboss": miniboss, "tile": tile})
	ev.append_array(bev)
	for i in enemies.size():
		ev.append({"type": "enemy_intent", "enemy_idx": i, "intent": enemies[i].intent.duplicate()})
	# Frostpeak ice: dice frozen on the board lock on the first turn of this fight.
	if run.chill > 0:
		pending_curse += run.chill
		ev.append({"type": "status", "target": "hero", "status": "chill", "value": run.chill})
		run.chill = 0
	ev.append_array(ClassLogic.on_combat_start(run, self))
	ev.append_array(start_turn(run))
	return ev

static func make_enemy(rng: Rng, id: String, p_act: int, p_lap: int, p_elite: bool, summoned := false) -> Dictionary:
	var is_boss := EnemyDefs.is_boss(id)
	var def := EnemyDefs.def(id)
	var scale := 1.0 if is_boss else Balance.enemy_scale(p_lap)
	var hp_mult := scale * (Balance.ELITE_HP_MULT if p_elite else 1.0) * Balance.tune_hp * (Balance.tune_boss if is_boss else 1.0)
	hp_mult *= float(EnemyDefs.tune_hp_by_id.get(id, 1.0))
	var atk_scale := 1.0 if is_boss else Balance.enemy_atk_scale(p_lap)
	var atk_mult := atk_scale * (Balance.ELITE_ATK_MULT if p_elite else 1.0) * Balance.tune_atk
	var hp := int(round(float(def.hp) * hp_mult))
	var step := 0
	if not is_boss and def.mode == "cycle":
		step = rng.randi_range(0, EnemyDefs.pattern(id, 1).size() - 1)
	return {
		"id": id, "name": String(def.name), "hp": hp, "max_hp": hp, "block": 0, "atk_bonus": 0,
		"poison": 0, "frozen": false, "intent": {"kind": "aim", "value": 0}, "boss": is_boss, "phase": 1,
		"elite": p_elite, "atk_mult": atk_mult, "step": step, "summoned": summoned,
		"miniboss": EnemyDefs.is_miniboss(id), "traits": EnemyDefs.traits(id, 1).duplicate(),
		"frenzy": 0, "form": EnemyDefs.form(id, 1),
		"affixes": [], "thorns_value": Balance.ENEMY_THORNS, "actions": 0, "chilled": false, "rallied": 0,
	}

## Meta-layer enemy modifiers (ascension): A1 elites +15% HP; A6 +4% HP/attack (not bosses);
## the final boss gets A9 phase-2 traits and +5% HP, A4's +10% HP when the mini-boss was skipped,
## and 40% HP as A10's second boss (run.stats.boss_stage == 1); A4 gives the mini-boss a trait.
static func meta_enemy(run: RunState, e: Dictionary) -> void:
	var hp_m := 1.0
	if run.has_asc("enemy_stats") and not bool(e.boss):
		hp_m *= UnlockDefs.ASC_ENEMY_STATS
		e.atk_mult = float(e.atk_mult) * UnlockDefs.ASC_ENEMY_STATS
	if run.has_asc("extra_elite") and bool(e.get("elite", false)):
		hp_m *= UnlockDefs.ASC_ELITE_HP
	if bool(e.boss):
		var stage := int(run.stats.get("boss_stage", 0))
		if stage == 0 and run.has_asc("boss_phase"):
			hp_m *= UnlockDefs.ASC_BOSS_HP
			e.traits = EnemyDefs.traits(String(e.id), 2).duplicate()
		if stage == 0 and run.has_asc("miniboss_trait") and int(run.stats.get("minibosses_won", 0)) == 0:
			hp_m *= UnlockDefs.ASC_SKIP_MINIBOSS_BOSS_HP
		if stage >= 1:
			hp_m *= UnlockDefs.ASC_SECOND_BOSS_HP
	if hp_m != 1.0:
		e.hp = maxi(1, int(round(int(e.hp) * hp_m)))
		e.max_hp = e.hp

## Records enemy ids and affixes met this run (stats.seen_enemies / seen_affixes, for the
## Bestiary and first-encounter popups).
func _note_seen(run: RunState) -> void:
	var se: Array = run.stats.get("seen_enemies", [])
	var sa: Array = run.stats.get("seen_affixes", [])
	for e in enemies:
		if not se.has(String(e.id)):
			se.append(String(e.id))
		for a in e.get("affixes", []):
			if not sa.has(String(a)):
				sa.append(String(a))
	run.stats["seen_enemies"] = se
	run.stats["seen_affixes"] = sa

static func has_affix(e: Dictionary, a: String) -> bool:
	return (e.get("affixes", []) as Array).has(a)

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
		pattern = EnemyDefs.pattern(String(e.id), int(e.phase))
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
	if String(entry.kind) == "attack" and has_affix(e, "vampiric"):
		entry = {"kind": "drain", "value": entry.value}
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
	rerolls_used_this_turn = 0
	refunds_this_turn = 0
	var pev: Array[Dictionary] = []
	if run.has_passive("loaded_hands") and turn == 1:
		rerolls_left += 1
		pev.append(_passive("loaded_hands", 1))
	if run.has_passive("iron_skin"):
		run.block = Balance.PASSIVE_IRON_SKIN
		run.stats.block_gained = int(run.stats.get("block_gained", 0)) + run.block
		pev.append(_passive("iron_skin", run.block))
		pev.append({"type": "block_gained", "target": "hero", "amount": run.block, "total": run.block})
	if not run.meta.is_empty():
		var extra := 0
		if turn == 1 and run.has_trait("helm_bulwark"):
			extra += int(GearDefs.TRAIT_BONUS.helm_bulwark)
		if stoneskin > 0:
			extra += stoneskin
			stoneskin = 0
		if extra > 0:
			run.block += extra
			run.stats.block_gained = int(run.stats.get("block_gained", 0)) + extra
			pev.append({"type": "block_gained", "target": "hero", "amount": extra, "total": run.block})
		if boost:
			rerolls_left += 1
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
	ev.append_array(PetLogic.on_turn_start(run, self))
	ev.append_array(ClassLogic.on_turn_start(run, self))
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
	rerolls_used_this_turn += 1
	run.stats.rerolls_used = int(run.stats.get("rerolls_used", 0)) + 1
	var free := wisp_free > 0
	if free:
		wisp_free -= 1
	for i in idx:
		dice_faces[i] = run.dice[i].roll(run.rng)
		dice_values[i] = run.dice[i].value(dice_faces[i])
		if not free:
			rerolled[i] = true
		marked[i] = false
	var ev: Array[Dictionary] = []
	var refunded := false
	if run.has_passive("encore") and float(current_combo(run).mult) > before_mult:
		rerolls_left += 1
		refunded = true
		ev.append(_passive("encore", 1))
	ev.append_array(ClassLogic.on_reroll(run, self, idx, refunded))
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
	var left := Balance.WILD_MAX_DICE
	for d in run.dice:
		# anti-stacking: only the first WILD_MAX_DICE Wild dice act as Wild
		var w := d.rune == "wild" and left > 0
		if w:
			left -= 1
		wild.append(w)
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

## Which dice's runes act this attack (Balance.RUNE_STACK_MAX anti-stacking): per rune, the first
## rune_cap(rune) dice in pool order whose trigger fires (combo runes: in the scoring group;
## Ember: shows 6; Frost: shows 1; Thunder: rerolled; Lucky: kept; Guard: always).
func rune_active(run: RunState, group: Array, eff: Array) -> Array[bool]:
	var out: Array[bool] = []
	var used := {}
	for i in run.dice.size():
		var r := run.dice[i].rune
		var ok := false
		match r:
			"blade", "venom", "vampire", "echo", "heavy", "gilded":
				ok = group.has(i)
			"ember":
				ok = int(eff[i]) == 6
			"frost":
				ok = int(eff[i]) == 1
			"thunder":
				ok = rerolled[i]
			"lucky":
				ok = not rerolled[i]
			"guard":
				ok = true
		if ok and int(used.get(r, 0)) < Balance.rune_cap(r):
			used[r] = int(used.get(r, 0)) + 1
		else:
			ok = false
		out.append(ok)
	return out

func attack(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	ev.append_array(PetLogic.fire_at_attack(run, self))
	if all_dead():
		ev.append_array(_win(run))
		return ev
	_fix_target()
	var combo := current_combo(run)
	var eff: Array = combo.values
	var group: Array = combo.group
	var cid := String(combo.id)
	var mult := passive_mult(run, cid, float(combo.mult)) + pet_mult
	pet_mult = 0.0
	if cid == "pair" and run.has_passive("crowd_pleaser"):
		ev.append(_passive("crowd_pleaser", 0))
	if (cid == "pair" or cid == "two_pair") and run.has_passive("pair_master"):
		ev.append(_passive("pair_master", 0))
	if cid in ["three_kind", "four_kind", "five_kind", "six_kind"] and run.has_passive("triple_threat"):
		ev.append(_passive("triple_threat", 0))
	# Class combo bonus (Paladin Oath): [mult added once, pips added before the multiplier]
	var cls_bonus := ClassLogic.combo_bonus(run, self, combo, ev)
	mult += float(cls_bonus[0])
	# How many times each die's rune triggers (Resonance: combo dice x2; Rune Echo: 25% x2).
	var times: Array[int] = []
	for i in run.dice.size():
		var t := 1
		# anti-stacking: the multiplier runes (Heavy, Echo) never trigger twice
		if run.dice[i].rune != "" and group.has(i) and not Balance.NO_DOUBLE_TRIGGER.has(run.dice[i].rune):
			if run.has_passive("resonance"):
				t = 2
			elif run.has_passive("rune_echo") and run.rng.chance(Balance.PASSIVE_RUNE_ECHO_CHANCE):
				t = 2
				ev.append(_passive("rune_echo", i))
		times.append(t)
	var sum := 0
	var bonus := int(cls_bonus[1])
	var flat := 0
	var act := rune_active(run, group, eff)
	var wild_left := Balance.WILD_MAX_DICE
	var steady := 0
	var boxcars := 0
	var snakes := 0
	for i in run.dice.size():
		var pips := int(eff[i])
		var rune := run.dice[i].rune
		var in_group := group.has(i)
		if rune == "heavy" and act[i]:
			# anti-stacking: Heavy doubles only inside the scoring group, at most 2 dice
			sum += pips * (1 + times[i])
			for k in times[i]:
				ev.append(_rune(i, rune, "double_pips", pips))
		else:
			sum += pips
		if rune == "blade" and act[i]:
			bonus += pips * times[i]
			for k in times[i]:
				ev.append(_rune(i, rune, "bonus_damage", pips))
		if rune == "echo" and act[i]:
			mult += 0.5 * times[i]
			for k in times[i]:
				ev.append(_rune(i, rune, "mult", 0))
		if rune == "wild" and wild_left > 0:
			wild_left -= 1
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
	if not run.meta.is_empty():
		if cid == "pair" and run.has_trait("blade_pair"):
			flat += int(GearDefs.TRAIT_BONUS.blade_pair)
			ev.append({"type": "trait_triggered", "id": "blade_pair", "value": int(GearDefs.TRAIT_BONUS.blade_pair)})
		if cid == "high_roller" and run.has_trait("blade_high"):
			flat += int(GearDefs.TRAIT_BONUS.blade_high)
			ev.append({"type": "trait_triggered", "id": "blade_high", "value": int(GearDefs.TRAIT_BONUS.blade_high)})
		if boss and turn == 1 and run.has_trait("blade_boss_opener") and int(run.stats.get("boss_stage", 0)) == 0:
			factor *= float(GearDefs.TRAIT_BONUS.blade_boss_opener)
			ev.append({"type": "trait_triggered", "id": "blade_boss_opener", "value": 0})
		for i in rerolled.size():
			if not rerolled[i]:
				run.stats.kept_dice = int(run.stats.get("kept_dice", 0)) + 1
		if cid == "straight" or cid == "small_straight":
			run.stats.straights = int(run.stats.get("straights", 0)) + 1
	if run.has_passive("glass_cannon"):
		factor *= Balance.PASSIVE_GLASS_MULT
		ev.append(_passive("glass_cannon", 0))
	if run.has_passive("opening_salvo") and turn == 1:
		factor *= Balance.PASSIVE_DAMAGE_MULT
		ev.append(_passive("opening_salvo", 0))
	factor *= ClassLogic.attack_factor(run, self, ev)
	var total :=int(floor(((sum + bonus) * mult + flat) * factor)) + run.atk
	last_combo = {"id": combo.id, "name": combo.name, "mult": mult, "base_mult": float(combo.mult), "group": group.duplicate(), "total": total, "values": eff.duplicate()}
	ev.append({"type": "combo", "id": combo.id, "name": combo.name, "mult": mult, "group": group.duplicate(), "total": total, "values": eff.duplicate(), "sum": sum + bonus})
	if mult > float(run.stats.get("best_mult", 0.0)):
		run.stats.best_mult = mult
		run.stats.best_combo = combo.name
	var alive_before := alive_indices().size()
	var thorny := alive(target) and has_trait(enemies[target], "thorns")
	var soak := int(enemies[target].hp) + int(enemies[target].block) if alive(target) else 0
	var tgt0 := target
	ev.append_array(damage_enemy(target, total, "attack", run))
	ev.append_array(ClassLogic.after_main_hit(run, self, tgt0, last_overkill))
	if run.has_trait("blade_overflow") and not alive(tgt0) and total > soak:
		var spill := int(floor((total - soak) * float(GearDefs.TRAIT_BONUS.blade_overflow)))
		var nxt := -1
		for j in enemies.size():
			if alive(j):
				nxt = j
				break
		if spill > 0 and nxt >= 0:
			ev.append({"type": "trait_triggered", "id": "blade_overflow", "value": spill})
			ev.append_array(damage_enemy(nxt, spill, "cleave", run))
	if alive(tgt0) and total > 0 and has_trait(enemies[tgt0], "frenzy"):
		ev.append_array(_frenzy(tgt0))
	if thorny and total > 0:
		# Briar thorns: reflect damage to the hero, never lethal.
		var th := mini(int(enemies[tgt0].get("thorns_value", Balance.ENEMY_THORNS)), run.hp - 1)
		if th > 0 and has_affix(enemies[tgt0], "thorned"):
			ev.append({"type": "affix_triggered", "enemy_idx": tgt0, "affix": "thorned", "value": th})
		if th > 0:
			run.hp -= th
			run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + th
			ev.append({"type": "damage", "target": "hero", "amount": th, "blocked": 0, "source": "thorns", "attacker": target, "lethal": false, "hp": run.hp, "max_hp": run.max_hp, "block": run.block})
	# Ember (SIX): 6 to all
	for i in run.dice.size():
		if run.dice[i].rune == "ember" and act[i]:
			for k in times[i]:
				ev.append(_rune(i, "ember", "damage_all", 6))
				for j in enemies.size():
					if alive(j):
						ev.append_array(damage_enemy(j, 6, "ember", run))
	# Thunder (REROLLED): pips to a random enemy
	for i in run.dice.size():
		if run.dice[i].rune == "thunder" and act[i]:
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
	var killed := alive_before - alive_indices().size()
	_fix_target()
	for i in run.dice.size():
		var rune := run.dice[i].rune
		var pips := int(eff[i])
		if not act[i]:
			continue
		for k in times[i]:
			match rune:
				"venom":
					if alive(target):
						enemies[target].poison = int(enemies[target].poison) + pips
						ev.append(_rune(i, rune, "poison", pips))
						ev.append({"type": "status", "target": target, "status": "poison", "value": int(enemies[target].poison)})
				"frost":
					if alive(target):
						enemies[target].frozen = true
						ev.append(_rune(i, rune, "freeze", 1))
						ev.append({"type": "status", "target": target, "status": "frozen", "value": 1})
				"guard":
					run.block += pips
					run.stats.block_gained = int(run.stats.get("block_gained", 0)) + pips
					ev.append(_rune(i, rune, "block", pips))
					ev.append({"type": "block_gained", "target": "hero", "amount": pips, "total": run.block})
				"vampire":
					# lifesteal on a kill: only when this attack killed an enemy
					if killed > 0:
						var healed := run.heal(pips)
						ev.append(_rune(i, rune, "heal", healed))
						ev.append({"type": "hp_changed", "amount": healed, "total": run.hp, "source": "vampire"})
				"gilded":
					run.gold += 2
					run.stats.gold_earned = int(run.stats.get("gold_earned", 0)) + 2
					ev.append(_rune(i, rune, "gold", 2))
					ev.append({"type": "gold_changed", "amount": 2, "total": run.gold, "source": "gilded"})
				"lucky":
					if run.banked_rerolls < Balance.MAX_BANKED_REROLLS:
						run.banked_rerolls += 1
						ev.append(_rune(i, rune, "bank_reroll", 1))
	ev.append_array(PetLogic.on_attack_resolved(run, self, cid, eff))
	ev.append_array(_moon_clouds(run))
	if all_dead():
		ev.append_array(_win(run))
		return ev
	ev.append_array(_enemy_phase(run))
	if result == "":
		ev.append_array(start_turn(run))
	return ev

func damage_enemy(i: int, amount: int, source: String, run: RunState, ignore_block := false) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	last_overkill = 0
	if not alive(i) or amount <= 0:
		return ev
	var e := enemies[i]
	if (source == "thunder" or source == "ember") and int(e.poison) > 0 and run.has_pet("lantern_ghost") and run.pet_level() >= 10:
		amount += 1
	var warded := false
	if has_trait(e, "ward") and _summons_alive() > 0:
		# Bone Warden's legion: half damage while any summoned ally stands.
		amount = int(ceil(amount / 2.0))
		warded = true
	elif has_trait(e, "ward_allies") and _unwarded_others(i) > 0:
		# Warded affix: half damage while any other non-warded enemy stands.
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
		if source == "poison":
			run.stats.poison_kills = int(run.stats.get("poison_kills", 0)) + 1
		last_overkill = maxi(0, amount - blocked - dealt)
		e.poison = 0
		e.frozen = false
		ev.append({"type": "enemy_died", "enemy_idx": i, "id": e.id})
		run.stats.kills = int(run.stats.get("kills", 0)) + 1
		if not (e.get("affixes", []) as Array).is_empty():
			run.stats.affixed_kills = int(run.stats.get("affixed_kills", 0)) + 1
			if has_affix(e, "gilded"):
				var gc := PetLogic.add_charge(run, AffixDefs.GILDED_PET_CHARGE)
				if not gc.is_empty():
					ev.append({"type": "affix_triggered", "enemy_idx": i, "affix": "gilded", "value": AffixDefs.GILDED_PET_CHARGE})
					ev.append_array(gc)
		if run.has_passive("bloodthirst"):
			var h := run.heal(Balance.PASSIVE_BLOODTHIRST)
			ev.append(_passive("bloodthirst", Balance.PASSIVE_BLOODTHIRST))
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "bloodthirst", "max_hp": run.max_hp})
		var ok := last_overkill
		ev.append_array(ClassLogic.on_enemy_killed(run, self, i, source))
		last_overkill = ok
	elif not e.boss and int(e.phase) == 1 and float(e.hp) <= float(e.max_hp) * transform_at and EnemyDefs.transforms(String(e.id)):
		# transform: once at <= 50% HP; drops its Block and re-rolls its intent from phase 2
		e.phase = 2
		e.step = 0
		e.form = EnemyDefs.form(String(e.id), 2)
		if int(e.block) > 0:
			var lost2 := int(e.block)
			e.block = 0
			ev.append({"type": "block_gained", "target": i, "amount": -lost2, "total": 0, "source": "transform"})
		roll_intent(run.rng, i)
		ev.append({"type": "enemy_transformed", "enemy_idx": i, "form": String(e.form), "id": String(e.id)})
		ev.append({"type": "enemy_intent", "enemy_idx": i, "intent": e.intent.duplicate()})
	elif e.boss and int(e.phase) == 1 and int(e.hp) * 2 <= int(e.max_hp):
		ev.append_array(_boss_phase2(i))
	return ev

## Switches boss i to phase 2 (HP threshold, or forced by the Moon King's Moonrise):
## boss_phase {enemy_idx, phase, traits, form, forced, source}.
func _boss_phase2(i: int, forced := false) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var e := enemies[i]
	var was_armored := has_trait(e, "armor")
	e.phase = 2
	e.step = 0
	e.traits = EnemyDefs.traits(String(e.id), 2).duplicate()
	e.form = EnemyDefs.form(String(e.id), 2)
	var bp := {"type": "boss_phase", "enemy_idx": i, "phase": 2, "traits": e.traits.duplicate(), "form": String(e.form)}
	if forced:
		bp["forced"] = true
		bp["source"] = "moonrise"
	ev.append(bp)
	if was_armored and not has_trait(e, "armor") and int(e.block) > 0:
		# Magma Golem: the shell shatters and its stored Block is gone.
		var lost := int(e.block)
		e.block = 0
		ev.append({"type": "block_gained", "target": i, "amount": -lost, "total": 0, "source": "shatter"})
	return ev

## Frenzy: +FRENZY_STEP attack after surviving a main-attack hit, up to +FRENZY_MAX per fight.
func _frenzy(i: int) -> Array[Dictionary]:
	var e := enemies[i]
	var gain := mini(EnemyDefs.FRENZY_STEP, EnemyDefs.FRENZY_MAX - int(e.get("frenzy", 0)))
	gain = mini(gain, _bonus_room(e))
	if gain <= 0:
		return []
	e.frenzy = int(e.get("frenzy", 0)) + gain
	e.atk_bonus = int(e.atk_bonus) + gain
	var out: Array[Dictionary] = [{"type": "status", "target": i, "status": "frenzy", "value": int(e.frenzy), "max": EnemyDefs.FRENZY_MAX}]
	if (e.get("affixes", []) as Array).has("frenzied"):
		out.append({"type": "affix_triggered", "enemy_idx": i, "affix": "frenzied", "value": int(e.frenzy)})
	return out

## Living enemies other than i without the Warded affix.
func _unwarded_others(i: int) -> int:
	var n := 0
	for k in enemies.size():
		if k != i and alive(k) and not has_trait(enemies[k], "ward_allies"):
			n += 1
	return n

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
				var keep := bool(e.boss) and run.has_pet("lantern_ghost") and run.pet_level() >= 5
				e.poison = p if keep else p - 1
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
			ev.append_array(_affix_before_action(run, i))
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
	if result == "":
		ev.append_array(_moon_tide(run))
	if result == "":
		ev.append_array(ClassLogic.on_enemy_phase_end(run, self))
	return ev

## Burn on the hero: at the end of the enemy phase the hero takes damage equal to the stacks
## (ignoring Block), then the stacks drop by 1.
func _tick_burn(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if hero_burn <= 0 or result != "":
		return ev
	var dmg := mini(hero_burn, run.hp)
	var hp_before := run.hp
	run.hp -= dmg
	var saved := ""
	if run.hp <= 0:
		saved = run.survive_lethal(hp_before)
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
func _hit_hero(run: RunState, i: int, v: int, out_dealt: Array = [], force_pierce := false) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var e := enemies[i]
	var pierce := force_pierce or has_trait(e, "pierce")
	var blocked := 0 if pierce else mini(run.block, v)
	run.block -= blocked
	var dealt := mini(v - blocked, run.hp)
	var hp_before := run.hp
	run.hp -= dealt
	var saved := ""
	if run.hp <= 0:
		saved = run.survive_lethal(hp_before)
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

## Affix procs when enemy i acts (a frozen enemy skips them): Regenerating heals unless
## poisoned; Hexing curses on its 1st action and every HEX_EVERY-th after; Frostbound chills
## with its first attack.
func _affix_before_action(run: RunState, i: int) -> Array[Dictionary]:
	var e := enemies[i]
	var ev: Array[Dictionary] = []
	if (e.get("affixes", []) as Array).is_empty():
		return ev
	e["actions"] = int(e.get("actions", 0)) + 1
	if has_affix(e, "regenerating") and int(e.poison) <= 0:
		var h := _heal_enemy(i, maxi(1, int(round(int(e.max_hp) * AffixDefs.REGEN_PCT))), "regenerating")
		if not h.is_empty():
			ev.append({"type": "affix_triggered", "enemy_idx": i, "affix": "regenerating", "value": int(h[0].amount)})
			ev.append_array(h)
	if has_affix(e, "hexing") and (int(e.actions) - 1) % AffixDefs.HEX_EVERY == 0:
		pending_curse += 1
		ev.append({"type": "affix_triggered", "enemy_idx": i, "affix": "hexing", "value": 1})
		ev.append({"type": "status", "target": "hero", "status": "curse", "value": 1, "source": i, "pending": true})
	if has_affix(e, "frostbound") and not bool(e.get("chilled", false)) and ["attack", "chill", "drain"].has(String(e.intent.kind)):
		e["chilled"] = true
		pending_curse += 1
		ev.append({"type": "affix_triggered", "enemy_idx": i, "affix": "frostbound", "value": 1})
		ev.append({"type": "status", "target": "hero", "status": "curse", "value": 1, "source": i, "pending": true, "chill": true})
	return ev

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
		"rally":
			# every living enemy (the caster included) gains +v attack for the fight
			for k in enemies.size():
				if alive(k):
					var g := _rally(k, v)
					if g > 0:
						ev.append({"type": "status", "target": k, "status": "buff", "value": int(enemies[k].atk_bonus), "source": i, "rally": true})
		"curse":
			pending_curse += v
			ev.append({"type": "status", "target": "hero", "status": "curse", "value": v, "source": i, "pending": true})
		"bury":
			# Sand Colossus: locks v dice next turn and gains BURY_BLOCK Block per die buried
			pending_curse += v
			ev.append({"type": "status", "target": "hero", "status": "curse", "value": v, "source": i, "pending": true, "bury": true})
			var bb := int(round(EnemyDefs.BURY_BLOCK * v * float(e.atk_mult)))
			e.block = int(e.block) + bb
			ev.append({"type": "block_gained", "target": i, "amount": bb, "total": int(e.block), "source": "bury"})
		"moonfall":
			# the Moon King: a piercing blow; the meter was spent when the intent was set
			ev.append_array(_hit_hero(run, i, v, [], true))
		"summon":
			var sdef := EnemyDefs.def(String(e.id))
			var sid := String(sdef.get("summon", EnemyDefs.SUMMON_ID))
			var slap := lap if sdef.has("summon") else 1
			for k in maxi(1, v):
				if _summoned_alive() >= Balance.MAX_SUMMONED_ALIVE:
					break
				var m := make_enemy(run.rng, sid, act, slap, false, true)
				if not run.meta.is_empty():
					meta_enemy(run, m)
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
		var am := AffixDefs.reward_mult(e.get("affixes", []))
		g += float(def.gold) * m * (1.0 if e.boss else gold_mult) * float(am[0])
		x += float(def.xp) * m * float(am[1])
	if run.has_passive("scholar"):
		x *= Balance.PASSIVE_SCHOLAR
	if moon_full:
		g *= BiomeDefs.MOON_FULL_GOLD
	gold_reward = int(round(g * Balance.tune_gold))
	xp_reward = int(round(x))
	var ev: Array[Dictionary] = [{"type": "combat_won", "gold": gold_reward, "xp": xp_reward, "boss": boss, "elite": elite, "miniboss": miniboss}]
	ev.append_array(restore_chaos(run))
	ev.append_array(ClassLogic.on_fight_end(run, self))
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

# ---------------------------------------------------------------- new biomes

## No moon meter in this fight.
const MOON_NONE := -99

## Attack an enemy may still gain from Frenzy, Rally and drums (EnemyDefs.ATK_BONUS_CAP).
static func _bonus_room(e: Dictionary) -> int:
	return maxi(0, EnemyDefs.ATK_BONUS_CAP - int(e.get("frenzy", 0)) - int(e.get("rallied", 0)))

## Rallies enemy k by up to v attack (capped). Returns the attack gained.
func _rally(k: int, v: int) -> int:
	var e := enemies[k]
	var g := mini(v, _bonus_room(e))
	if g <= 0:
		return 0
	e["rallied"] = int(e.get("rallied", 0)) + g
	e.atk_bonus = int(e.atk_bonus) + g
	return g

## Biome rules at fight start (before the first intents are rolled):
## - Orc Warcamp: every non-boss enemy is Rallied DRUM_RALLY per standing drum:
##   rally {source:"drum", value, drums} + status buff {target, value, source:"drum", rally:true}.
## - Moonlit Woods: the Half moon raises the transform threshold; on the Full lap transformers
##   start changed (enemy_transformed {enemy_idx, form, id, source:"moon"}) and fights pay more.
## - The Moon King's meter (moon_meter {value, delta:0, source:"start", max}).
func _biome_begin(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	moon = MOON_NONE
	var ph := run.moon_phase()
	if ph == "half":
		transform_at = BiomeDefs.MOON_HALF_TRANSFORM
	if ph == "full" and not boss:
		moon_full = true
		for i in enemies.size():
			var e := enemies[i]
			if not bool(e.boss) and EnemyDefs.transforms(String(e.id)):
				e.phase = 2
				e.step = 0
				e.form = EnemyDefs.form(String(e.id), 2)
				ev.append({"type": "enemy_transformed", "enemy_idx": i, "form": String(e.form), "id": String(e.id), "source": "moon"})
	if run.twist() == "drums":
		var drums := run.board.count("drum")
		if drums > 0:
			var v := BiomeDefs.DRUM_RALLY * drums
			var out: Array[Dictionary] = []
			for k in enemies.size():
				if bool(enemies[k].boss):
					continue
				if _rally(k, v) > 0:
					out.append({"type": "status", "target": k, "status": "buff", "value": int(enemies[k].atk_bonus), "source": "drum", "rally": true})
			if not out.is_empty():
				ev.append({"type": "rally", "source": "drum", "value": v, "drums": drums})
				ev.append_array(out)
	for i in enemies.size():
		if String(enemies[i].id) == "boss_moon_king":
			moon = 0
			if run.has_asc("boss_phase") and int(run.stats.get("boss_stage", 0)) == 0:
				moon = EnemyDefs.MOON_A9_START
			if run.route.has("hollow") and run.route.has("moonlit") and (run.stats.get("minibosses_killed", []) as Array).has("mini_moonfang"):
				moon += EnemyDefs.MOON_FANG_START
				ev.append({"type": "moon_meter", "value": moon, "delta": 0, "source": "moonfang", "max": EnemyDefs.MOON_MAX})
			else:
				ev.append({"type": "moon_meter", "value": moon, "delta": 0, "source": "start", "max": EnemyDefs.MOON_MAX})
			break
	return ev

## Index of the living Moon King, or -1.
func moon_king() -> int:
	if moon == MOON_NONE:
		return -1
	for i in enemies.size():
		if alive(i) and String(enemies[i].id) == "boss_moon_king":
			return i
	return -1

## The tide: +MOON_TIDE at the end of every enemy phase (moon_meter {source:"tide"}). A full meter
## in phase 1 forces phase 2 (Moonrise: boss_phase {forced, source:"moonrise"}, a fresh phase-2
## intent); in phase 2 it turns the next intent into Moonfall (enemy_intent {kind:"moonfall"}).
## Either way the meter resets to 0 (moon_meter {source:"moonrise"|"moonfall"}).
func _moon_tide(_run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var i := moon_king()
	if i < 0:
		return ev
	moon += EnemyDefs.MOON_TIDE
	ev.append({"type": "moon_meter", "value": moon, "delta": EnemyDefs.MOON_TIDE, "source": "tide", "max": EnemyDefs.MOON_MAX})
	if moon < EnemyDefs.MOON_MAX:
		return ev
	var e := enemies[i]
	var was := moon
	moon = 0
	if int(e.phase) == 1:
		ev.append_array(_boss_phase2(i, true))
		roll_intent(_run.rng, i)
		ev.append({"type": "moon_meter", "value": 0, "delta": -was, "source": "moonrise", "max": EnemyDefs.MOON_MAX})
	else:
		e.intent = {"kind": "moonfall", "value": EnemyDefs.MOONFALL + int(e.atk_bonus)}
		ev.append({"type": "moon_meter", "value": 0, "delta": -was, "source": "moonfall", "max": EnemyDefs.MOON_MAX})
	ev.append({"type": "enemy_intent", "enemy_idx": i, "intent": e.intent.duplicate()})
	return ev

## Clouds: each die showing exactly 1 in the attack (a Wild die never counts) pushes the meter back
## 1, at most MOON_CLOUDS_MAX per turn and never below 0 (moon_meter {source:"clouds", ones}).
func _moon_clouds(run: RunState) -> Array[Dictionary]:
	if moon_king() < 0 or moon <= 0:
		return []
	var ones := moon_ones(run)
	var nv := maxi(0, moon - mini(ones, EnemyDefs.MOON_CLOUDS_MAX))
	if nv == moon:
		return []
	var d := nv - moon
	moon = nv
	return [{"type": "moon_meter", "value": moon, "delta": d, "source": "clouds", "ones": ones, "max": EnemyDefs.MOON_MAX}]

## Dice currently showing exactly 1 (not Wild).
func moon_ones(run: RunState) -> int:
	var n := 0
	for k in dice_values.size():
		if dice_values[k] == 1 and k < run.dice.size() and run.dice[k].rune != "wild":
			n += 1
	return n

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
		"hero_burn": hero_burn, "pet_block_carry": pet_block_carry, "wisp_free": wisp_free, "wisp_used": wisp_used,
		"potion_turn": potion_turn, "stoneskin": stoneskin, "boost": boost, "pet_mult": pet_mult,
		"rerolls_used_this_turn": rerolls_used_this_turn, "refunds_this_turn": refunds_this_turn, "oath": oath,
		"moon": moon, "transform_at": transform_at, "moon_full": moon_full,
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
	c.pet_block_carry = int(d.get("pet_block_carry", 0))
	c.wisp_free = int(d.get("wisp_free", 0))
	c.wisp_used = bool(d.get("wisp_used", false))
	c.potion_turn = int(d.get("potion_turn", 0))
	c.stoneskin = int(d.get("stoneskin", 0))
	c.boost = bool(d.get("boost", false))
	c.pet_mult = float(d.get("pet_mult", 0.0))
	c.rerolls_used_this_turn = int(d.get("rerolls_used_this_turn", 0))
	c.refunds_this_turn = int(d.get("refunds_this_turn", 0))
	c.oath = int(d.get("oath", 0))
	c.moon = int(d.get("moon", MOON_NONE))
	c.transform_at = float(d.get("transform_at", 0.5))
	c.moon_full = bool(d.get("moon_full", false))
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
		"frenzy": int(ed.get("frenzy", 0)), "form": String(ed.get("form", "")),
		"affixes": _strings(ed.get("affixes", [])), "thorns_value": int(ed.get("thorns_value", Balance.ENEMY_THORNS)),
		"actions": int(ed.get("actions", 0)), "chilled": bool(ed.get("chilled", false)),
		"rallied": int(ed.get("rallied", 0)),
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
