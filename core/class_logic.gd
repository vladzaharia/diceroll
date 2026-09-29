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
##   overgrowth (Druid)    each lap completion raises the lowest face of every "seed" die by 1
##                         (face_changed {source: "growth"}); each biome change tags the
##                         untagged die with the lowest face sum as a seed (max DRUID_MAX_SEEDS);
##                         Wild Bond: the pet starts every fight with +1 charge ("wild_bond")

const PALADIN_OATH_MULT := 0.5
const PALADIN_OATH_PIP := 1
## Sanctify uses per run (one per biome change; 2 in a standard run).
const PALADIN_SANCTIFY := 2
## Shop die-kind weight multipliers for the Paladin (only kinds in the unlocked pool).
const PALADIN_SHOP_KINDS := {"twin": 2.0, "even": 2.0}
const SET_COMBOS := ["pair", "two_pair", "three_kind", "full_house", "four_kind", "five_kind", "six_kind"]
const RANGER_AIM_MULT := 1.3
const RANGER_PIERCE_CARRIES := 1
const NINJA_REFUNDS_PER_TURN := 2
const NINJA_BOARD_REFUNDS := 1
const DRUID_GROWTH := 1
const DRUID_MAX_SEEDS := 3
const DRUID_PET_CHARGE := 1

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

## An enemy died (any source).
static func on_enemy_killed(_run: RunState, _c: CombatState, _i: int, _source: String) -> Array[Dictionary]:
	return []

## End of the enemy phase (the hero survived), before the next turn starts.
static func on_enemy_phase_end(_run: RunState, _c: CombatState) -> Array[Dictionary]:
	return []

## The fight was won.
static func on_fight_end(_run: RunState, _c: CombatState) -> Array[Dictionary]:
	return []

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
