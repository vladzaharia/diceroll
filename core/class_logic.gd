class_name ClassLogic
extends RefCounted
## Class mechanics (docs/design/2026-09-28-classes-enemies-skins.md §1), keyed by the run's
## class via HeroDefs.DATA[id].mechanic. Static like PetLogic: every hook is a no-op for classes
## without that mechanic, so the four original classes never touch the Rng here.
## Each hook returns events; class_triggered {id: mechanic id, class, value} mirrors
## passive_triggered so the UI can pulse the class badge.
##
## Mechanics:
##   oath (Paladin)        each fight swears an Oath value: the face value on the most faces
##                         of the pool (ties: higher; blanks never count); CombatState.oath and
##                         class_triggered {id: "oath"}. A set combo (Pair and up, not straights
##                         or High Roller) with 2+ scoring dice of the Oath value gets
##                         +PALADIN_OATH_MULT multiplier (once) and +PALADIN_OATH_PIP pip per
##                         Oath die in the group ("oath_kept"). Sanctify: each biome change sets
##                         the lowest non-Oath face of the die with the fewest Oath faces to the
##                         Oath (face_changed {source: "sanctify"}). Shops weight Twin/Even x2.
##   aim (Ranger)          no combat reroll this turn: the main attack deals xRANGER_AIM_MULT;
##                         overkill on the target carries once to the next living enemy
##                         (Piercing Shot, event id "piercing_shot")
##   shadow_step (Ninja)   a reroll after which a rerolled die matches another die's non-blank
##                         value is refunded (max NINJA_REFUNDS_PER_TURN per turn; never twice
##                         for one reroll, so Encore and Shadow Step don't stack); a board reroll
##                         that rolls doubles is refunded (max 1 per board turn)
##   bone_harvest (Necromancer)  each enemy death during the fight raises a temporary Bone die
##                         (faces 1 2 2 3 3 4, tag "bone") that joins the pool next turn (max
##                         BONE_MAX, pool max BONE_POOL_MAX); a fight that starts with a lone enemy
##                         raises one at the start of turns BONE_LONE_TURNS, and a boss drops one
##                         when phase 2 starts. Bones crumble when the fight is won, healing
##                         BONE_HEAL each. Events: die_added {die_idx, temporary: true, tag: "bone",
##                         die} and die_removed {die_idx, temporary: true}.
##   turret (Engineer)     RunState.turret, a die outside the pool: after each main attack it rolls
##                         (no rerolls, no combos, ignores curses) and shoots the target for pips x
##                         TURRET_T[biome tier - 1]. One rune, non-combo triggers only
##                         (TURRET_RUNES): guard Block = pips, heavy x2 shot, ember 6 to all on a
##                         6, frost freezes on a 1, gilded gold on the board move. Offers address
##                         it as die_idx GameFlow.TURRET (-2). turret_fired {value, damage, rune,
##                         target}.
##   overgrowth (Druid)    each lap completion raises the lowest face of every "seed" die by 1
##                         (face_changed {source: "growth"}); each biome change tags the
##                         untagged die with the lowest face sum as a seed (max DRUID_MAX_SEEDS);
##                         Wild Bond: the pet starts every fight with +1 charge ("wild_bond")

static var PALADIN_OATH_MULT := 0.5
static var PALADIN_OATH_PIP := 1
## Sanctify uses per run (one per biome change; 2 in a standard run).
static var PALADIN_SANCTIFY := 2
## Shop die-kind weight multipliers for the Paladin (only kinds in the unlocked pool).
const PALADIN_SHOP_KINDS := {"twin": 2.0, "even": 2.0}
const SET_COMBOS := ["pair", "two_pair", "three_kind", "full_house", "four_kind", "five_kind", "six_kind"]
static var RANGER_AIM_MULT := 1.3
static var RANGER_PIERCE_CARRIES := 1
static var NINJA_REFUNDS_PER_TURN := 2
static var NINJA_BOARD_REFUNDS := 1
static var DRUID_GROWTH := 1
static var DRUID_MAX_SEEDS := 3
static var DRUID_PET_CHARGE := 1
static var TURRET_T := [1.0, 2.0, 3.0]
const TURRET_RUNES := ["guard", "heavy", "ember", "frost", "gilded"]
static var BONE_MAX := 2
static var BONE_POOL_MAX := 6
static var BONE_HEAL := 2
static var BONE_LONE_TURNS := [3, 6]

## Sim-only analysis dial (tools/sim.gd --cl=<KNOB>=<value>): sets one of the knobs above.
## Returns false for an unknown knob. The defaults above ARE the shipped numbers.
static func tune_knob(knob: String, v: float) -> bool:
	match knob:
		"PALADIN_OATH_MULT": PALADIN_OATH_MULT = v
		"PALADIN_OATH_PIP": PALADIN_OATH_PIP = int(v)
		"PALADIN_SANCTIFY": PALADIN_SANCTIFY = int(v)
		"RANGER_AIM_MULT": RANGER_AIM_MULT = v
		"RANGER_PIERCE_CARRIES": RANGER_PIERCE_CARRIES = int(v)
		"NINJA_REFUNDS_PER_TURN": NINJA_REFUNDS_PER_TURN = int(v)
		"NINJA_BOARD_REFUNDS": NINJA_BOARD_REFUNDS = int(v)
		"DRUID_GROWTH": DRUID_GROWTH = int(v)
		"DRUID_MAX_SEEDS": DRUID_MAX_SEEDS = int(v)
		"DRUID_PET_CHARGE": DRUID_PET_CHARGE = int(v)
		"BONE_MAX": BONE_MAX = int(v)
		"TURRET_T3": TURRET_T = [TURRET_T[0], TURRET_T[1], v]
		"TURRET_T2": TURRET_T = [TURRET_T[0], v, TURRET_T[2]]
		"TURRET_T1": TURRET_T = [v, TURRET_T[1], TURRET_T[2]]
		"BONE_HEAL": BONE_HEAL = int(v)
		_: return false
	return true

static func mech(run: RunState) -> String:
	return HeroDefs.mechanic(run.class_id)

static func ev(run: RunState, id: String, value: int, extra := {}) -> Dictionary:
	var e := {"type": "class_triggered", "id": id, "class": run.class_id, "value": value}
	for k in extra:
		e[k] = extra[k]
	return e

# ------------------------------------------------------------------ combat

## Oath value of a pool given as face arrays: the value on the most faces (ties: higher), 0 if
## every face is blank. Values above 9 (the Monster Kid's pretend face) never count.
static func oath_of(face_sets: Array) -> int:
	var cnt := {}
	for fs in face_sets:
		for v in fs:
			if int(v) > 0 and int(v) <= DiceKinds.MAX_VALUE:
				cnt[int(v)] = int(cnt.get(int(v), 0)) + 1
	var best := 0
	var best_n := 0
	for v in cnt:
		if int(cnt[v]) > best_n or (int(cnt[v]) == best_n and int(v) > best):
			best = int(v)
			best_n = int(cnt[v])
	return best

static func pool_oath(dice: Array) -> int:
	var fs: Array = []
	for d in dice:
		fs.append(d.faces)
	return oath_of(fs)

## Oath bonus for a combo: [mult added, pips added]. `oath` 0 = none.
static func oath_bonus(oath: int, combo_id: String, group: Array, eff: Array) -> Array:
	if oath <= 0 or not SET_COMBOS.has(combo_id):
		return [0.0, 0]
	var n := 0
	for i in group:
		if int(eff[int(i)]) == oath:
			n += 1
	if n < 2:
		return [0.0, 0]
	return [PALADIN_OATH_MULT, PALADIN_OATH_PIP * n]

## Combo bonus of the class for this attack: [mult added once, pips added to the sum].
static func combo_bonus(run: RunState, c: CombatState, combo: Dictionary, out: Array[Dictionary]) -> Array:
	match mech(run):
		"oath":
			var b := oath_bonus(c.oath, String(combo.id), combo.group, combo.values)
			if int(b[1]) > 0:
				out.append(ev(run, "oath_kept", int(b[1]), {"oath": c.oath, "mult": float(b[0])}))
			return b
	return [0.0, 0]

## Die-kind weight multipliers for shop dice ({} = the normal odds).
static func shop_kind_bias(run: RunState) -> Dictionary:
	match mech(run):
		"oath":
			return PALADIN_SHOP_KINDS
	return {}

## Fight start (after enemies and intents, before turn 1).
static func on_combat_start(run: RunState, c: CombatState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match mech(run):
		"oath":
			c.oath = pool_oath(run.dice)
			if c.oath > 0:
				out.append(ev(run, "oath", c.oath))
		"overgrowth":
			if run.pet_id() != "":
				var ch := PetLogic.add_charge(run, DRUID_PET_CHARGE)
				if not ch.is_empty():
					out.append(ev(run, "wild_bond", DRUID_PET_CHARGE))
					out.append_array(ch)
	return out

## Before a player turn's dice are sized and rolled: temporary dice join the pool (Bone dice
## raised last turn; the lone-foe rule raises one right away on turns BONE_LONE_TURNS).
static func before_turn(run: RunState, c: CombatState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match mech(run):
		"bone_harvest":
			if c.turn in BONE_LONE_TURNS and c.enemies.size() == 1 and not c.all_dead():
				out.append_array(_raise_bone(run, c, "lone"))
			while c.pending_bones > 0:
				c.pending_bones -= 1
				var d := Die.make("", "bone")
				d.add_tag("bone")
				c.extra_dice.append(d)
				var idx := run.dice.size() + c.extra_dice.size() - 1
				out.append({"type": "die_added", "die_idx": idx, "kind": "bone", "temporary": true, "tag": "bone", "die": d.to_dict()})
	return out

## Queues a Bone die (it joins at the next turn start) when the caps allow. `why`: kill | lone | phase.
static func _raise_bone(run: RunState, c: CombatState, why: String) -> Array[Dictionary]:
	if c.bones_raised >= BONE_MAX or run.dice.size() + c.extra_dice.size() + c.pending_bones >= BONE_POOL_MAX:
		return []
	c.bones_raised += 1
	c.pending_bones += 1
	return [ev(run, "bone_harvest", c.bones_raised, {"reason": why})]

## A boss entered phase 2.
static func on_boss_phase(run: RunState, c: CombatState, _i: int) -> Array[Dictionary]:
	if mech(run) == "bone_harvest":
		return _raise_bone(run, c, "phase")
	return []

## Player turn start (after the dice are rolled).
static func on_turn_start(_run: RunState, _c: CombatState) -> Array[Dictionary]:
	return []

## After a combat reroll of dice `idx`. `refunded`: another effect (Encore) already refunded it.
static func on_reroll(run: RunState, c: CombatState, idx: Array[int], refunded: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match mech(run):
		"shadow_step":
			if refunded or c.refunds_this_turn >= NINJA_REFUNDS_PER_TURN:
				return out
			if rerolled_match(c.dice_values, idx):
				c.refunds_this_turn += 1
				c.rerolls_left += 1
				out.append(ev(run, "shadow_step", 1, {"rerolls_left": c.rerolls_left, "refunds_left": NINJA_REFUNDS_PER_TURN - c.refunds_this_turn}))
	return out

## True when any die in `idx` shows the same non-blank value as another die.
static func rerolled_match(values: Array, idx: Array) -> bool:
	for i in idx:
		var v := int(values[i])
		if v <= 0:
			continue
		for j in values.size():
			if j != int(i) and int(values[j]) == v:
				return true
	return false

## Damage factor for this turn's main attack (after the multiplier and passives' factors).
static func attack_factor(run: RunState, c: CombatState, out: Array[Dictionary]) -> float:
	match mech(run):
		"aim":
			if c.rerolls_used_this_turn == 0:
				out.append(ev(run, "aim", int(round(RANGER_AIM_MULT * 100.0))))
				return RANGER_AIM_MULT
	return 1.0

## After the main attack hit enemy `tgt` for `total`; `overkill` is the damage left after its
## HP and Block (0 when it lived).
static func after_main_hit(run: RunState, c: CombatState, tgt: int, overkill: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match mech(run):
		"aim":
			var carry := overkill
			var from := tgt
			for k in RANGER_PIERCE_CARRIES:
				if carry <= 0:
					break
				var nxt := -1
				for j in c.enemies.size():
					if j != from and c.alive(j):
						nxt = j
						break
				if nxt < 0:
					break
				out.append(ev(run, "piercing_shot", carry, {"from": from, "enemy_idx": nxt}))
				out.append_array(c.damage_enemy(nxt, carry, "pierce_shot", run))
				carry = c.last_overkill
				from = nxt
	return out

## After the main attack and its runes (enemies may be dead): the Engineer's Turret fires.
static func after_attack(run: RunState, c: CombatState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if mech(run) != "turret" or run.turret == null or c.all_dead():
		return out
	c._fix_target()
	var t := c.target
	var v := run.turret.value(run.turret.roll(run.rng))
	var r := run.turret.rune
	var tier := int(BiomeDefs.DEFS[run.biome()].tier) if BiomeDefs.has(run.biome()) else run.act
	var mult := float(TURRET_T[clampi(tier, 1, 3) - 1]) * (2.0 if r == "heavy" else 1.0)
	var dmg := int(round(v * mult))
	out.append({"type": "turret_fired", "value": v, "damage": dmg, "rune": r, "target": t})
	out.append_array(c.damage_enemy(t, dmg, "turret", run))
	match r:
		"guard":
			if v > 0:
				run.block += v
				run.stats.block_gained = int(run.stats.get("block_gained", 0)) + v
				out.append({"type": "block_gained", "target": "hero", "amount": v, "total": run.block, "source": "turret"})
		"ember":
			if v == 6:
				for j in c.enemies.size():
					if c.alive(j):
						out.append_array(c.damage_enemy(j, 6, "ember", run))
		"frost":
			if v == 1 and c.alive(t):
				if not bool(c.enemies[t].frozen):
					run.stats.freezes = int(run.stats.get("freezes", 0)) + 1
				c.enemies[t].frozen = true
				out.append({"type": "status", "target": t, "status": "frozen", "value": 1, "source": "turret"})
	return out

## An enemy died (any source).
static func on_enemy_killed(run: RunState, c: CombatState, _i: int, _source: String) -> Array[Dictionary]:
	if mech(run) == "bone_harvest" and not c.all_dead():
		return _raise_bone(run, c, "kill")
	return []

## End of the enemy phase (the hero survived), before the next turn starts.
static func on_enemy_phase_end(_run: RunState, _c: CombatState) -> Array[Dictionary]:
	return []

## The fight was won.
static func on_fight_end(run: RunState, c: CombatState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match mech(run):
		"bone_harvest":
			var n := c.extra_dice.size()
			for k in range(n - 1, -1, -1):
				out.append({"type": "die_removed", "die_idx": run.dice.size() + k, "temporary": true, "tag": "bone"})
			c.extra_dice.clear()
			c.pending_bones = 0
			if n > 0:
				var h := run.heal(BONE_HEAL * n)
				out.append(ev(run, "bone_crumble", n))
				out.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "bones", "max_hp": run.max_hp})
	return out

# ------------------------------------------------------------------ board

## A lap was completed (the hero passed Start and a new lap begins).
static func on_lap(run: RunState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match mech(run):
		"overgrowth":
			var grew := 0
			for i in run.dice.size():
				var d := run.dice[i]
				if not d.has_tag("seed"):
					continue
				for g in DRUID_GROWTH:
					var f := d.lowest_face()
					if d.raise_face(f):
						grew += 1
						out.append({"type": "face_changed", "die_idx": i, "face_idx": f, "value": d.faces[f],
							"faces": Array(d.faces), "source": "growth"})
			if grew > 0:
				out.push_front(ev(run, "overgrowth", grew))
	return out

## A new biome started (act_started).
static func on_biome(run: RunState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match mech(run):
		"oath":
			var used := int(run.passive_state.get("sanctify", 0))
			if used >= PALADIN_SANCTIFY:
				return out
			var o := pool_oath(run.dice)
			if o <= 0:
				return out
			var best := -1
			var best_n := 7
			for i in run.dice.size():
				var d := run.dice[i]
				if o > d.raise_cap():
					continue
				var n := 0
				for v in d.faces:
					if int(v) == o:
						n += 1
				if n < 6 and n < best_n:
					best_n = n
					best = i
			if best < 0:
				return out
			var d2 := run.dice[best]
			var lo := -1
			for f in 6:
				if d2.faces[f] != o and d2.faces[f] <= DiceKinds.MAX_VALUE and (lo < 0 or d2.faces[f] < d2.faces[lo]):
					lo = f
			if lo < 0:
				return out
			run.passive_state["sanctify"] = used + 1
			d2.faces[lo] = o
			d2.edited[lo] = 1
			out.append(ev(run, "sanctify", o, {"die_idx": best, "face_idx": lo}))
			out.append({"type": "face_changed", "die_idx": best, "face_idx": lo, "value": o, "faces": Array(d2.faces), "source": "sanctify"})
		"overgrowth":
			var seeds := 0
			for d in run.dice:
				if d.has_tag("seed"):
					seeds += 1
			if seeds >= DRUID_MAX_SEEDS:
				return out
			var best := -1
			for i in run.dice.size():
				if run.dice[i].has_tag("seed"):
					continue
				if best < 0 or run.dice[i].face_sum() < run.dice[best].face_sum():
					best = i
			if best >= 0:
				run.dice[best].add_tag("seed")
				out.append(ev(run, "seed", best, {"die_idx": best}))
				out.append({"type": "die_tagged", "die_idx": best, "tag": "seed", "tags": Array(run.dice[best].tags)})
	return out

## After a board reroll rolled (board_rolled already emitted). Returns the refund events.
static func on_board_reroll(run: RunState, flow: GameFlow) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match mech(run):
		"shadow_step":
			if flow.board_refunds < NINJA_BOARD_REFUNDS and flow.is_board_double():
				flow.board_refunds += 1
				flow.board_rerolls_left += 1
				out.append(ev(run, "shadow_step", 1, {"board": true, "rerolls_left": flow.board_rerolls_left}))
	return out
