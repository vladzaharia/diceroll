class_name ItemLogic
extends RefCounted
## Armory item rules in a run (docs/design/2026-09-29-armory-items.md §2-§7). Static like
## ClassLogic / PetLogic: every hook is a no-op without meta.items, so legacy runs and fresh
## profiles (all ranks R0) never touch the Rng here.
##
## run.meta.items = {slot: {id, variant, tier}} (MetaRun.build; only slots with tier >= 1 and a
## stat item). Numbers come from ItemDefs.num(item, key, tier, variant) (the Standard variant's
## x1.2 included); a variant's secondary numbers are fixed (ItemDefs.sec_num).
##
## Runtime state: run.item_state (across fights: ambush, dominion, soul, last_stand, key_act) and
## CombatState.item_state (this fight: attacks, rampage_t, rampage, spark, vanish, focus, ...).
##
## Every rule that fires emits item_triggered {id: base item, variant, slot, effect: rule or
## secondary id, value, ...extra}. Effects use the usual events (block_gained {source: "item"},
## hp_changed {source: "item"}, damage {source: "item"}, status, gold_changed {source: "item"},
## dice_rolled {context: "combat", source: "loaded_die"}, face_changed {source: "grove"}).

const SETS3 := ["three_kind", "full_house", "four_kind", "five_kind", "six_kind"]
const PAIRISH := ["pair", "two_pair"]

# ------------------------------------------------------------------ lookups

static func items(run: RunState) -> Dictionary:
	return run.meta.get("items", {})

## Slot holding base item `item` (tier >= 1), "" if none. Slot 1 wins over the Belt Pouch.
static func slot_of(run: RunState, item: String) -> String:
	var it := items(run)
	for slot in ItemDefs.STAT_SLOTS:
		var e: Dictionary = it.get(slot, {})
		if String(e.get("id", "")) == item and int(e.get("tier", 0)) > 0:
			return slot
	return ""

static func has(run: RunState, item: String) -> bool:
	return slot_of(run, item) != ""

static func tier(run: RunState, item: String) -> int:
	var s := slot_of(run, item)
	return 0 if s == "" else int((items(run)[s] as Dictionary).tier)

static func variant(run: RunState, item: String) -> String:
	var s := slot_of(run, item)
	return "" if s == "" else String((items(run)[s] as Dictionary).get("variant", item))

## A rule number of the equipped item (0 when it isn't equipped or active).
static func n(run: RunState, item: String, key: String) -> float:
	var t := tier(run, item)
	if t <= 0:
		return 0.0
	return ItemDefs.num(item, key, t, variant(run, item))

static func ni(run: RunState, item: String, key: String) -> int:
	return int(round(n(run, item, key)))

## True when variant `vid` (a VARIANTS id) is equipped and active.
static func sec(run: RunState, vid: String) -> bool:
	var it := items(run)
	if it.is_empty():
		return false
	for slot in it:
		var e: Dictionary = it[slot]
		if String(e.get("variant", "")) == vid and int(e.get("tier", 0)) > 0:
			return true
	return false

## Items whose Standard variant gives Block 2 on turn 1 (count-based rules), equipped as Standard.
static func std_block(run: RunState) -> Array:
	var out: Array = []
	var it := items(run)
	for slot in it:
		var e: Dictionary = it[slot]
		var id := String(e.get("id", ""))
		if int(e.get("tier", 0)) > 0 and String(e.get("variant", id)) == id and String(ItemDefs.def(id).get("std", "")) == "block2":
			out.append(id)
	return out

static func ev(run: RunState, item: String, effect: String, value: Variant, extra := {}) -> Dictionary:
	var e := {"type": "item_triggered", "id": item, "variant": variant(run, item), "slot": slot_of(run, item),
		"effect": effect, "value": value}
	for k in extra:
		e[k] = extra[k]
	return e

## Lap scaling of the Volley and Spare Arrows: x(1 + 0.15 per lap after the first).
static func lap_scale(lap: int) -> float:
	return 1.0 + 0.15 * (maxi(1, lap) - 1)

# ------------------------------------------------------------------ helpers (combat)

## Gives the hero Block from an item or rune (source "item" | "rune"); Steadfast adds its extra
## once per turn. Returns the events.
static func gain_block(run: RunState, c: CombatState, amount: int, item: String, effect: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if amount <= 0:
		return out
	var extra := 0
	if c != null and _steadfast_ok(run, c):
		extra = ni(run, "knight_helm", "extra")
	run.block += amount + extra
	run.stats.block_gained = int(run.stats.get("block_gained", 0)) + amount + extra
	if item != "":
		out.append(ev(run, item, effect, amount))
	out.append({"type": "block_gained", "target": "hero", "amount": amount + extra, "total": run.block, "source": "item" if item != "" else "rune"})
	if extra > 0:
		out.append(ev(run, "knight_helm", "steadfast", extra))
	return out

## Steadfast for Block that a rune already added (the Guard rune): extra Block once per turn.
static func steadfast(run: RunState, c: CombatState) -> Array[Dictionary]:
	if c == null or not _steadfast_ok(run, c):
		return []
	var x := ni(run, "knight_helm", "extra")
	run.block += x
	run.stats.block_gained = int(run.stats.get("block_gained", 0)) + x
	return [ev(run, "knight_helm", "steadfast", x), {"type": "block_gained", "target": "hero", "amount": x, "total": run.block, "source": "item"}]

## Steadfast: once per turn, `uses` turns per fight. Consumes a use when it returns true.
static func _steadfast_ok(run: RunState, c: CombatState) -> bool:
	if not has(run, "knight_helm") or int(c.item_state.get("steadfast_turn", 0)) == c.turn \
			or int(c.item_state.get("steadfast", 0)) >= ni(run, "knight_helm", "uses"):
		return false
	c.item_state["steadfast_turn"] = c.turn
	c.item_state["steadfast"] = int(c.item_state.get("steadfast", 0)) + 1
	return true

static func heal(run: RunState, item: String, effect: String, amount: int) -> Array[Dictionary]:
	if amount <= 0:
		return []
	var h := run.heal(amount)
	return [ev(run, item, effect, amount), {"type": "hp_changed", "amount": h, "total": run.hp, "source": "item", "max_hp": run.max_hp}]

## Extra poison on every application by the hero (Hooded Robe's Shroud).
static func shroud(run: RunState) -> int:
	return ni(run, "hooded_robe", "poison")

## Applies `amount` poison (+Shroud) to enemy t from an item effect.
static func poison(run: RunState, c: CombatState, t: int, amount: int, item: String, effect: String) -> Array[Dictionary]:
	if amount <= 0 or not c.alive(t):
		return []
	var p := amount + shroud(run)
	c.enemies[t].poison = int(c.enemies[t].poison) + p
	return [ev(run, item, effect, p, {"enemy_idx": t}),
		{"type": "status", "target": t, "status": "poison", "value": int(c.enemies[t].poison), "source": "item"}]

static func freeze(run: RunState, c: CombatState, t: int, item: String, effect: String) -> Array[Dictionary]:
	if not c.alive(t):
		return []
	if not bool(c.enemies[t].frozen):
		run.stats.freezes = int(run.stats.get("freezes", 0)) + 1
	c.enemies[t].frozen = true
	return [ev(run, item, effect, 1, {"enemy_idx": t}), {"type": "status", "target": t, "status": "frozen", "value": 1, "source": "item"}]

static func bank_reroll(run: RunState, item: String, effect: String, cap := Balance.MAX_BANKED_REROLLS) -> Array[Dictionary]:
	if run.banked_rerolls >= mini(cap, Balance.MAX_BANKED_REROLLS):
		return []
	run.banked_rerolls += 1
	return [ev(run, item, effect, 1, {"banked": run.banked_rerolls})]

## Ember bonus damage (Mage Robe).
static func rune_dmg(run: RunState) -> int:
	return ni(run, "mage_robe", "dmg")

## Thunder bonus damage (Mage Robe III).
static func thunder_dmg(run: RunState) -> int:
	return ni(run, "mage_robe", "thunder")

## Venom rune poison bonus (Mage Robe + Shroud).
static func venom_bonus(run: RunState) -> int:
	return ni(run, "mage_robe", "poison") + shroud(run)

## BOO!'s boss weaken with the Dino Suit.
static func boo_weaken(run: RunState) -> float:
	return maxf(ClassLogic.BOO_WEAKEN, n(run, "dino_suit", "weaken"))

## Value of the set in a scoring group: the most common value (ties: the higher).
static func set_value(eff: Array, group: Array) -> int:
	var cnt := {}
	for i in group:
		var v := int(eff[int(i)])
		if v > 0 and v <= DiceKinds.MAX_VALUE:
			cnt[v] = int(cnt.get(v, 0)) + 1
	var best := 0
	var bn := 0
	for v in cnt:
		if int(cnt[v]) > bn or (int(cnt[v]) == bn and int(v) > best):
			best = int(v)
			bn = int(cnt[v])
	return best

## The Crush die: the highest die of the scoring group that has no active Heavy rune (-1 none).
static func crush_die(pd: Array, eff: Array, group: Array, act: Array) -> int:
	var best := -1
	for i in group:
		var k := int(i)
		if pd[k].rune == "heavy" and bool(act[k]):
			continue
		if int(eff[k]) <= 0 or int(eff[k]) > DiceKinds.MAX_VALUE:
			continue
		if best < 0 or int(eff[k]) > int(eff[best]):
			best = k
	return best

static func crush_mult(run: RunState) -> float:
	var m := n(run, "warhammer", "crush")
	if sec(run, "hammer_mallet"):
		m += ItemDefs.sec_num("hammer_mallet", "crush")
	return m

# ------------------------------------------------------------------ fight and turn start

## Fight start (after intents, before turn 1): the Opening Volley. Returns the events.
static func on_combat_start(run: RunState, c: CombatState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if items(run).is_empty():
		return out
	c.item_state = {}
	if has(run, "hunting_bow"):
		out.append_array(_volley(run, c, 1.0))
	return out

static func _volley(run: RunState, c: CombatState, share: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var alive := c.alive_indices()
	if alive.is_empty():
		return out
	var dmg := n(run, "hunting_bow", "dmg") * lap_scale(c.lap) * share
	var t: int
	if sec(run, "bow_long"):
		t = alive[0]
		for k in alive:
			if int(c.enemies[k].hp) > int(c.enemies[t].hp):
				t = k
		dmg *= 1.0 + ItemDefs.sec_num("bow_long", "pct")
	else:
		t = int(run.rng.pick(alive))
	var d := int(round(dmg))
	out.append(ev(run, "hunting_bow", "opening_volley", d, {"enemy_idx": t, "share": share}))
	out.append_array(c.damage_enemy(t, d, "item", run, sec(run, "bow_composite")))
	return out

## Player turn setup, before combat_turn_started (rerolls_left and Block are set, dice not yet
## rolled). `prev_block`: the hero's Block before this turn's reset (Heraldic Shield's Rally).
static func turn_start(run: RunState, c: CombatState, prev_block: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if items(run).is_empty():
		return out
	for k in ["focus_turn", "shuriken_turn", "poise_turn", "radiant_turn", "blessed_turn"]:
		c.item_state[k] = 0
	c.item_state["focus_pip"] = 0
	var t := c.turn
	# rerolls
	var rr := 0
	if has(run, "dagger") and t <= ni(run, "dagger", "turns"):
		rr += 1
		out.append(ev(run, "dagger", "quick_hands", 1))
	if t == 1 and sec(run, "sword_training") and run.dice.size() <= int(ItemDefs.sec_num("sword_training", "dice")):
		rr += 1
		out.append(ev(run, "sword", "lesson", 1))
	if t == 1 and sec(run, "shield_plank"):
		rr += 1
		out.append(ev(run, "round_shield", "light", 1))
	if t == 1 and sec(run, "shield_tower"):
		rr += int(ItemDefs.sec_num("shield_tower", "rerolls"))
	c.rerolls_left = maxi(0, c.rerolls_left + rr)
	# Block
	if has(run, "round_shield"):
		var bw := ni(run, "round_shield", "block")
		if sec(run, "shield_plank"):
			bw += int(ItemDefs.sec_num("shield_plank", "block"))
		bw = maxi(0, bw)
		if t == 1:
			c.item_state["bulwark"] = bw
			c.item_state["bulwark_turn"] = 1
			out.append_array(gain_block(run, c, bw, "round_shield", "bulwark"))
		elif t == 2 and sec(run, "shield_tower"):
			var half := int(floor(bw * ItemDefs.sec_num("shield_tower", "share")))
			c.item_state["bulwark"] = half
			c.item_state["bulwark_turn"] = 2
			out.append_array(gain_block(run, c, half, "round_shield", "wall"))
		elif t == 2 and sec(run, "shield_heraldic"):
			var carry := mini(prev_block, int(c.item_state.get("bulwark", 0)))
			if carry > 0:
				c.item_state["bulwark_turn"] = 2
				c.item_state["bulwark"] = carry
				out.append_array(gain_block(run, c, carry, "round_shield", "rally"))
	if t == 1 and (c.elite or c.boss or c.miniboss):
		var sb := std_block(run)
		if not sb.is_empty():
			# count-based Standards don't stack: one Block on turn 1 however many are equipped
			out.append_array(gain_block(run, c, ItemDefs.STD_BLOCK, String(sb[0]), "standard"))
	# Plated: elite, mini-boss and boss fights only (whole-game balance pass: every fight read
	# +2.6 pp as a generic body and put the Knight +6 pp over the max average)
	if has(run, "knight_plate") and t <= ni(run, "knight_plate", "turns") and (c.elite or c.boss or c.miniboss):
		out.append_array(gain_block(run, c, ni(run, "knight_plate", "block"), "knight_plate", "plated"))
	if has(run, "dino_suit") and t <= ni(run, "dino_suit", "turns"):
		out.append_array(gain_block(run, c, ni(run, "dino_suit", "block"), "dino_suit", "thick_hide"))
	return out

## After the turn's dice are rolled: the Loaded Die (turn 1) and the Short Bow's second Volley
## (turn 2).
static func after_roll(run: RunState, c: CombatState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if items(run).is_empty():
		return out
	if c.turn == 1 and has(run, "loaded_die"):
		var left := ni(run, "loaded_die", "dice")
		var pd := c.pool_dice(run)
		var idx: Array[int] = []
		for i in c.dice_values.size():
			if left <= 0:
				break
			if c.locked[i] or c.dice_values[i] > 1 or c.dice_values[i] == Die.PRETEND:
				continue
			left -= 1
			c.dice_faces[i] = pd[i].roll(run.rng)
			c.dice_values[i] = pd[i].value(c.dice_faces[i])
			idx.append(i)
		if not idx.is_empty():
			out.append(ev(run, "loaded_die", "weighted", idx.size()))
			out.append({"type": "dice_rolled", "values": c.dice_values.duplicate(), "indices": idx, "context": "combat",
				"faces": c.dice_faces.duplicate(), "rerolls_left": c.rerolls_left, "source": "loaded_die"})
	if c.turn == 2 and sec(run, "bow_short") and has(run, "hunting_bow"):
		out.append_array(_volley(run, c, ItemDefs.sec_num("bow_short", "share")))
	return out

# ------------------------------------------------------------------ rerolls

## After a combat reroll of dice `idx` (values already updated).
static func on_reroll(run: RunState, c: CombatState, idx: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if items(run).is_empty():
		return out
	if idx.size() == 1 and has(run, "ninja_headband"):
		var per_turn := ni(run, "ninja_headband", "per_turn") > 0
		var key := "focus_turn" if per_turn else "focus"
		if int(c.item_state.get(key, 0)) < ni(run, "ninja_headband", "uses"):
			c.item_state[key] = int(c.item_state.get(key, 0)) + 1
			c.rerolls_left += 1
			out.append(ev(run, "ninja_headband", "focus", 1, {"die_idx": idx[0], "rerolls_left": c.rerolls_left}))
			if sec(run, "ninja_mask"):
				c.item_state["focus_pip"] = int(c.item_state.get("focus_pip", 0)) + 1
				out.append(ev(run, "ninja_headband", "silent", 1, {"die_idx": idx[0]}))
	if has(run, "shuriken"):
		var cap := ni(run, "shuriken", "max")
		var dmg := ni(run, "shuriken", "dmg")
		for i in idx:
			if int(c.item_state.get("shuriken", 0)) >= cap or c.all_dead():
				break
			c.item_state["shuriken"] = int(c.item_state.get("shuriken", 0)) + 1
			var t := int(run.rng.pick(c.alive_indices()))
			out.append(ev(run, "shuriken", "barrage", dmg, {"enemy_idx": t, "die_idx": i}))
			out.append_array(c.damage_enemy(t, dmg, "item", run))
	if has(run, "ninja_gi") and int(c.item_state.get("poise", 0)) < ni(run, "ninja_gi", "max") \
			and ClassLogic.rerolled_match(c.dice_values, idx):
		c.item_state["poise"] = int(c.item_state.get("poise", 0)) + 1
		out.append_array(heal(run, "ninja_gi", "poise", 1))
	return out

# ------------------------------------------------------------------ attack

## Wizard Hat's Arcana: on its turns the first rune trigger fires twice (never re-doubles a
## trigger Resonance or Rune Echo already doubled). Mutates `times`.
static func arcana(run: RunState, c: CombatState, pd: Array, act: Array, times: Array[int], out: Array[Dictionary]) -> void:
	if not has(run, "wizard_hat") or c.turn > ni(run, "wizard_hat", "turns"):
		return
	for i in act.size():
		if not bool(act[i]):
			continue
		if int(times[i]) > 1 or Balance.NO_DOUBLE_TRIGGER.has(pd[i].rune):
			return # the first trigger is already doubled (or can't be)
		times[i] = 2
		out.append(ev(run, "wizard_hat", "arcana", 1, {"die_idx": i, "rune": pd[i].rune}))
		if sec(run, "hat_grave"):
			out.append_array(heal(run, "wizard_hat", "grave_magic", int(ItemDefs.sec_num("hat_grave", "heal"))))
		return

## The attack's item bonuses: {mult, bonus (pips before the multiplier; unused, kept for the
## contract), flat (after the multiplier), factor}. Item "pips" (Crush, Flow, Channel, Steady,
## Dominion, Brawn, Brawl, Light, Silent) add after the multiplier: a pre-multiplier pip is worth
## the whole combo multiplier (x2-4 at max), far beyond every slot budget (docs/plans/balance.md,
## Armory). Rules marked "uses" fire that many times per fight. Called before the total is
## computed; records what fired in c.item_state for after_hit().
static func attack_mods(run: RunState, c: CombatState, cid: String, pd: Array, eff: Array, group: Array, act: Array,
		mult: float, out: Array[Dictionary]) -> Dictionary:
	var r := {"mult": 0.0, "bonus": 0, "flat": 0, "factor": 1.0}
	if items(run).is_empty():
		return r
	var t := c.target
	var e: Dictionary = c.enemies[t] if c.alive(t) else {}
	var first := int(c.item_state.get("attacks", 0)) == 0
	c.item_state["crush"] = -1
	c.item_state["spark_now"] = 0
	c.item_state["first_now"] = 1 if first else 0
	c.item_state["ambush_now"] = 0
	c.item_state["deadshot_now"] = 0
	c.item_state["rampage_now"] = 0
	var kept := 0
	var rerolled := 0
	for i in c.rerolled.size():
		if c.rerolled[i]:
			rerolled += 1
		else:
			kept += 1
	# weapon
	if has(run, "sword") and use_left(run, c, "sword"):
		var f := 0
		if PAIRISH.has(cid):
			f = ni(run, "sword", "flat")
		elif cid == "high_roller" and sec(run, "sword_rapier"):
			f = maxi(1, int(floor(n(run, "sword", "flat") * ItemDefs.sec_num("sword_rapier", "share"))))
		if f > 0:
			use(c, "sword")
			r.flat += f
			out.append(ev(run, "sword", "twin_edge", f))
	if has(run, "greatsword") and SETS3.has(cid):
		var m := maxf(0.0, n(run, "greatsword", "mult") + (ItemDefs.sec_num("greatsword_plain", "mult") if sec(run, "greatsword_plain") else 0.0))
		if m > 0.0:
			r.mult += m
			out.append(ev(run, "greatsword", "great_arc", m))
	if has(run, "great_axe") and c.alive(t):
		var same := int(c.item_state.get("rampage_t", -1)) == t or sec(run, "axe_golem")
		var st := int(c.item_state.get("rampage", 0)) if same else 0
		if st > 0:
			var f2 := st * ni(run, "great_axe", "per")
			r.flat += f2
			c.item_state["rampage_now"] = st
			out.append(ev(run, "great_axe", "rampage", f2, {"stacks": st, "enemy_idx": t}))
	if has(run, "warhammer") and use_left(run, c, "warhammer"):
		var k := crush_die(pd, eff, group, act)
		if k >= 0:
			var pips := int(eff[k])
			var extra := int(floor(pips * (crush_mult(run) - 1.0) + 0.0001))
			if pips == 6 and sec(run, "hammer_smith"):
				extra += int(ItemDefs.sec_num("hammer_smith", "pip"))
			if extra > 0:
				use(c, "warhammer")
				r.flat += extra
				c.item_state["crush"] = k
				out.append(ev(run, "warhammer", "crush", extra, {"die_idx": k}))
	if has(run, "spear") and first:
		var fac := n(run, "spear", "factor") + (n(run, "spear", "boss") if c.boss else 0.0)
		r.factor *= fac
		out.append(ev(run, "spear", "first_strike", int(round(fac * 100.0))))
	if has(run, "katana") and rerolled >= ni(run, "katana", "dice") and use_left(run, c, "katana"):
		use(c, "katana")
		r.flat += ni(run, "katana", "flat")
		out.append(ev(run, "katana", "flow", ni(run, "katana", "flat"), {"dice": rerolled}))
	if has(run, "arcane_staff") and use_left(run, c, "arcane_staff"):
		var runed := 0
		var plain := false
		for i in group:
			if pd[int(i)].rune != "":
				runed += 1
			else:
				plain = true
		var b := mini(runed, ni(run, "arcane_staff", "max")) * ni(run, "arcane_staff", "pip")
		if runed > 0 and plain and sec(run, "staff_quarter"):
			b += int(ItemDefs.sec_num("staff_quarter", "pip"))
		if b > 0:
			use(c, "arcane_staff")
			r.flat += b
			out.append(ev(run, "arcane_staff", "channel", b))
	if has(run, "wand") and int(c.item_state.get("spark", 0)) == 0 and mult >= 2.0:
		c.item_state["spark"] = 1
		c.item_state["spark_now"] = 1
		var m2 := n(run, "wand", "mult")
		r.mult += m2
		out.append(ev(run, "wand", "spark", m2))
	if has(run, "crossbow") and cid == "high_roller":
		var f3 := n(run, "crossbow", "flat")
		if sec(run, "crossbow_arbalest"):
			f3 *= 1.0 + ItemDefs.sec_num("crossbow_arbalest", "pct")
		r.flat += int(round(f3))
		c.item_state["deadshot_now"] = 1
		out.append(ev(run, "crossbow", "deadshot", int(round(f3))))
	if has(run, "claws"):
		var lows := 0
		var ones := 0
		for i in eff.size():
			if c.dice_values[i] == Die.PRETEND:
				continue
			var v := int(eff[i])
			if v == 1 or v == 2:
				lows += 1
			if v == 1:
				ones += 1
		if lows >= ni(run, "claws", "dice") and use_left(run, c, "claws"):
			use(c, "claws")
			var f4 := ni(run, "claws", "per")
			r.flat += f4
			out.append(ev(run, "claws", "scrap", f4, {"dice": lows}))
		if ones > 0 and sec(run, "claws_knuckles"):
			r.flat += 1
			out.append(ev(run, "claws", "brawl", 1))
	if sec(run, "axe_twinbit") and cid == "two_pair":
		r.flat += int(ItemDefs.sec_num("axe_twinbit", "flat"))
		out.append(ev(run, "hand_axe", "double_chop", int(ItemDefs.sec_num("axe_twinbit", "flat"))))
	if sec(run, "axe_cleaver") and c.turn == 1:
		r.flat += int(ItemDefs.sec_num("axe_cleaver", "flat"))
		out.append(ev(run, "hand_axe", "butcher", int(ItemDefs.sec_num("axe_cleaver", "flat"))))
	if sec(run, "dagger_bone") and not e.is_empty() and int(e.poison) > 0:
		r.flat += int(ItemDefs.sec_num("dagger_bone", "flat"))
		out.append(ev(run, "dagger", "shiv", int(ItemDefs.sec_num("dagger_bone", "flat"))))
	if sec(run, "staff_bone") and int(run.item_state.get("soul", 0)) > 0:
		var s := int(run.item_state.soul)
		run.item_state["soul"] = 0
		r.flat += s
		out.append(ev(run, "arcane_staff", "soul", s))
	# off-hand
	if has(run, "parrying_dagger") and kept >= ni(run, "parrying_dagger", "dice") and use_left(run, c, "parrying_dagger"):
		use(c, "parrying_dagger")
		r.flat += 1
		out.append(ev(run, "parrying_dagger", "steady", 1, {"kept": kept}))
	if sec(run, "dagger_leaf") and c.turn == 1 and kept >= int(ItemDefs.sec_num("dagger_leaf", "dice")):
		r.flat += 1
		out.append(ev(run, "dagger", "light", 1))
	if has(run, "spellbook") and int(c.item_state.get("attacks", 0)) == 2:
		var m3 := n(run, "spellbook", "mult")
		r.mult += m3
		out.append(ev(run, "spellbook", "tome", m3))
	# head
	if has(run, "bear_hat") and run.hp * 2 < run.max_hp:
		r.flat += ni(run, "bear_hat", "flat")
		out.append(ev(run, "bear_hat", "ferocity", ni(run, "bear_hat", "flat")))
	if has(run, "bandit_mask") and first and int(run.item_state.get("ambush", 0)) > 0:
		run.item_state["ambush"] = 0
		c.item_state["ambush_now"] = 1
		var fac2 := n(run, "bandit_mask", "factor")
		r.factor *= fac2
		out.append(ev(run, "bandit_mask", "ambush", int(round(fac2 * 100.0))))
	if has(run, "bone_crown") and int(run.item_state.get("dominion", 0)) > 0:
		var dm := int(run.item_state.dominion)
		run.item_state["dominion"] = 0
		r.flat += dm
		out.append(ev(run, "bone_crown", "dominion", dm))
	if int(c.item_state.get("focus_pip", 0)) > 0:
		r.flat += int(c.item_state.focus_pip)
		c.item_state["focus_pip"] = 0
	# body
	if has(run, "barbarian_harness"):
		var hv := 0
		for i in pd.size():
			if pd[i].rune == "heavy" and bool(act[i]):
				hv += 1
		hv = mini(hv, ni(run, "barbarian_harness", "dice"))
		if hv > 0:
			r.flat += hv * ni(run, "barbarian_harness", "pips")
			out.append(ev(run, "barbarian_harness", "brawn", hv * ni(run, "barbarian_harness", "pips")))
	if has(run, "ranger_tunic") and not e.is_empty() and int(e.hp) >= int(e.max_hp):
		r.flat += ni(run, "ranger_tunic", "flat")
		out.append(ev(run, "ranger_tunic", "hunter", ni(run, "ranger_tunic", "flat"), {"enemy_idx": t}))
	return r

## Per-fight uses of a rule with a "uses" number (0 = unlimited).
static func use_left(run: RunState, c: CombatState, item: String) -> bool:
	var u := ni(run, item, "uses")
	return u <= 0 or int(c.item_state.get("uses_" + item, 0)) < u

static func use(c: CombatState, item: String) -> void:
	c.item_state["uses_" + item] = int(c.item_state.get("uses_" + item, 0)) + 1

## Before the main hit lands: the Bone Mace's Bonebreak strips half the target's Block.
static func pre_hit(run: RunState, c: CombatState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := c.target
	if sec(run, "hammer_bone") and int(c.item_state.get("crush", -1)) >= 0 and c.alive(t) and int(c.enemies[t].block) > 0:
		var lost := int(floor(int(c.enemies[t].block) * ItemDefs.sec_num("hammer_bone", "pct")))
		if lost > 0:
			c.enemies[t].block = int(c.enemies[t].block) - lost
			out.append(ev(run, "warhammer", "bonebreak", lost, {"enemy_idx": t}))
			out.append({"type": "block_gained", "target": t, "amount": -lost, "total": int(c.enemies[t].block), "source": "item"})
	return out

## After the main hit on tgt0 for `total` (`soak` = its HP + Block before). Splashes, poison,
## freezes, Block, heals, banked rerolls and the per-fight counters.
static func after_hit(run: RunState, c: CombatState, tgt0: int, total: int, soak: int, cid: String, pd: Array,
		eff: Array, group: Array, act: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if items(run).is_empty():
		return out
	var killed := not c.alive(tgt0)
	# Cleave
	if has(run, "hand_axe") and killed and total > soak:
		var spill := int(floor((total - soak) * n(run, "hand_axe", "pct")))
		var nxt := _next_alive(c, tgt0)
		if spill > 0 and nxt >= 0:
			out.append(ev(run, "hand_axe", "cleave", spill, {"enemy_idx": nxt}))
			out.append_array(c.damage_enemy(nxt, spill, "cleave", run))
			if sec(run, "axe_bone"):
				out.append_array(poison(run, c, nxt, int(ItemDefs.sec_num("axe_bone", "poison")), "hand_axe", "grisly"))
	# splashes: Saber (Pairs), Zweihander (3 of a kind+), Halberd (First Strike)
	var splash := 0.0
	var why := ""
	if sec(run, "sword_saber") and cid == "pair":
		var o := _next_alive(c, tgt0)
		if o >= 0:
			var d := int(floor(total * ItemDefs.sec_num("sword_saber", "pct")))
			out.append(ev(run, "sword", "slash", d, {"enemy_idx": o}))
			out.append_array(c.damage_enemy(o, d, "item", run))
	if sec(run, "greatsword_zwei") and SETS3.has(cid):
		splash = ItemDefs.sec_num("greatsword_zwei", "pct")
		why = "reach"
	if sec(run, "spear_halberd") and int(c.item_state.get("first_now", 0)) == 1:
		splash = maxf(splash, ItemDefs.sec_num("spear_halberd", "pct"))
		why = "sweep"
	if splash > 0.0:
		var d2 := int(floor(total * splash))
		var item := "greatsword" if why == "reach" else "spear"
		for j in c.enemies.size():
			if j != tgt0 and c.alive(j) and d2 > 0:
				out.append(ev(run, item, why, d2, {"enemy_idx": j}))
				out.append_array(c.damage_enemy(j, d2, "item", run))
	# Crush secondaries
	if int(c.item_state.get("crush", -1)) >= 0:
		if sec(run, "hammer_morningstar"):
			var others: Array = []
			for j in c.alive_indices():
				if j != tgt0:
					others.append(j)
			if not others.is_empty():
				var o2 := int(run.rng.pick(others))
				out.append(ev(run, "warhammer", "spikes", int(ItemDefs.sec_num("hammer_morningstar", "dmg")), {"enemy_idx": o2}))
				out.append_array(c.damage_enemy(o2, int(ItemDefs.sec_num("hammer_morningstar", "dmg")), "item", run))
		if sec(run, "hammer_club"):
			out.append_array(poison(run, c, tgt0, int(ItemDefs.sec_num("hammer_club", "poison")), "warhammer", "rend"))
	# sword secondaries
	if sec(run, "sword_flame") and PAIRISH.has(cid):
		var sixes := 0
		for i in group:
			if int(eff[int(i)]) == 6:
				sixes += 1
		if sixes > 0:
			var d3 := sixes * int(ItemDefs.sec_num("sword_flame", "dmg"))
			out.append(ev(run, "sword", "burning", d3))
			for j in c.enemies.size():
				if c.alive(j):
					out.append_array(c.damage_enemy(j, d3, "item", run))
	if sec(run, "sword_frost") and cid == "pair" and int(c.item_state.get("chill", 0)) == 0 and c.alive(tgt0):
		var pv := set_value(eff, group)
		if pv == 1 or pv == 2:
			c.item_state["chill"] = 1
			out.append_array(freeze(run, c, tgt0, "sword", "chill"))
	if sec(run, "sword_knight") and cid == "pair":
		out.append_array(gain_block(run, c, int(ItemDefs.sec_num("sword_knight", "block")), "sword", "guarded"))
	# staff secondaries
	if sec(run, "staff_frost") and int(c.item_state.get("rime", 0)) == 0 and c.alive(tgt0):
		for i in pd.size():
			if pd[i].rune != "" and int(eff[i]) == 1 and c.dice_values[i] != Die.PRETEND:
				c.item_state["rime"] = 1
				out.append_array(freeze(run, c, tgt0, "arcane_staff", "rime"))
				break
	if sec(run, "staff_sun"):
		var runed := 0
		for i in group:
			if pd[int(i)].rune != "":
				runed += 1
		var hn := mini(runed, int(ItemDefs.sec_num("staff_sun", "max")) - int(c.item_state.get("radiant", 0)))
		if hn > 0:
			c.item_state["radiant"] = int(c.item_state.get("radiant", 0)) + hn
			out.append_array(heal(run, "arcane_staff", "radiant", hn))
	# poisons
	if sec(run, "dagger_venom") and PAIRISH.has(cid):
		out.append_array(poison(run, c, tgt0 if c.alive(tgt0) else c.target, int(ItemDefs.sec_num("dagger_venom", "poison")), "dagger", "venom"))
	if sec(run, "wand_orb") and int(c.item_state.get("spark_now", 0)) == 1:
		out.append_array(poison(run, c, tgt0, int(ItemDefs.sec_num("wand_orb", "poison")), "wand", "hex"))
	if sec(run, "hood_grave") and int(c.item_state.get("ambush_now", 0)) == 1:
		out.append_array(poison(run, c, tgt0, int(ItemDefs.sec_num("hood_grave", "poison")), "bandit_mask", "ambush_poison"))
	if sec(run, "axe_jagged") and int(c.item_state.get("rampage_now", 0)) > 0:
		out.append_array(poison(run, c, tgt0, int(c.item_state.rampage_now) * int(ItemDefs.sec_num("axe_jagged", "poison")), "great_axe", "bleed"))
	# Block
	if has(run, "oath_shield") and ClassLogic.SET_COMBOS.has(cid) and use_left(run, c, "oath_shield"):
		var b := int(floor(set_value(eff, group) * n(run, "oath_shield", "x") + 0.0001))
		if b > 0:
			use(c, "oath_shield")
			out.append_array(gain_block(run, c, b, "oath_shield", "aegis"))
	if sec(run, "claws_gauntlet"):
		var lows := 0
		for i in eff.size():
			if c.dice_values[i] != Die.PRETEND and (int(eff[i]) == 1 or int(eff[i]) == 2):
				lows += 1
		out.append_array(gain_block(run, c, lows * int(ItemDefs.sec_num("claws_gauntlet", "block")), "claws", "guard"))
	# heals
	if has(run, "paladin_helm") and SETS3.has(cid) and int(c.item_state.get("vow", 0)) < ni(run, "paladin_helm", "uses"):
		c.item_state["vow"] = int(c.item_state.get("vow", 0)) + 1
		out.append_array(heal(run, "paladin_helm", "vow", ni(run, "paladin_helm", "heal")))
	if has(run, "paladin_cuirass") and ClassLogic.SET_COMBOS.has(cid) and cid != "pair" and int(c.item_state.get("blessed", 0)) < ni(run, "paladin_cuirass", "uses"):
		c.item_state["blessed"] = int(c.item_state.get("blessed", 0)) + 1
		out.append_array(heal(run, "paladin_cuirass", "blessed", ni(run, "paladin_cuirass", "heal")))
	# banked rerolls
	var kept := 0
	for i in c.rerolled.size():
		if not c.rerolled[i]:
			kept += 1
	if has(run, "rogue_leathers") and kept >= 2 and int(c.item_state.get("nimble", 0)) < ni(run, "rogue_leathers", "max"):
		var nb := bank_reroll(run, "rogue_leathers", "nimble")
		if not nb.is_empty():
			c.item_state["nimble"] = int(c.item_state.get("nimble", 0)) + 1
		out.append_array(nb)
	if sec(run, "wand_sapphire") and int(c.item_state.get("spark_now", 0)) == 1:
		out.append_array(bank_reroll(run, "wand", "wand_focus"))
	if sec(run, "crossbow_bone") and int(c.item_state.get("deadshot_now", 0)) == 1 and killed and int(c.item_state.get("reload", 0)) == 0:
		var rl := bank_reroll(run, "crossbow", "reload")
		if not rl.is_empty():
			c.item_state["reload"] = 1
		out.append_array(rl)
	# Spare Arrows: every 3rd attack of the fight
	var attacks := int(c.item_state.get("attacks", 0)) + 1
	c.item_state["attacks"] = attacks
	if has(run, "quiver") and attacks % 3 == 0 and not c.all_dead():
		var qt := int(run.rng.pick(c.alive_indices()))
		var qd := int(round(n(run, "quiver", "dmg") * lap_scale(c.lap)))
		out.append(ev(run, "quiver", "spare_arrows", qd, {"enemy_idx": qt}))
		out.append_array(c.damage_enemy(qt, qd, "item", run, sec(run, "bow_composite")))
		if sec(run, "quiver_bone"):
			out.append_array(poison(run, c, qt, int(ItemDefs.sec_num("quiver_bone", "poison")), "quiver", "barbed"))
	# Rampage bookkeeping
	if has(run, "great_axe"):
		var cap := ni(run, "great_axe", "stacks")
		if sec(run, "axe_war"):
			cap = int(ItemDefs.sec_num("axe_war", "stacks"))
		if killed:
			c.item_state["rampage"] = 0
			c.item_state["rampage_t"] = -1
		else:
			var same := int(c.item_state.get("rampage_t", -1)) == tgt0 or sec(run, "axe_golem")
			c.item_state["rampage"] = mini(cap, (int(c.item_state.get("rampage", 0)) if same else 0) + 1)
			c.item_state["rampage_t"] = tgt0
	return out

static func _next_alive(c: CombatState, not_i: int) -> int:
	for j in c.enemies.size():
		if j != not_i and c.alive(j):
			return j
	return -1

## An enemy died (any source): Reap, Gilded, Harvest, Dominion, Soul, and the kill counters.
static func on_kill(run: RunState, c: CombatState, i: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if run.meta.is_empty():
		return out
	var id := String(c.enemies[i].id)
	var kb: Dictionary = run.stats.get("kills_by_id", {})
	kb[id] = int(kb.get(id, 0)) + 1
	run.stats["kills_by_id"] = kb
	if ItemDefs.SKELETONS.has(id):
		run.stats.skeleton_kills = int(run.stats.get("skeleton_kills", 0)) + 1
	if items(run).is_empty():
		return out
	if has(run, "scythe") and use_left(run, c, "scythe"):
		use(c, "scythe")
		out.append_array(heal(run, "scythe", "reap", ni(run, "scythe", "heal")))
		if sec(run, "scythe_bone"):
			var ch := PetLogic.add_charge(run, int(ItemDefs.sec_num("scythe_bone", "charge")))
			if not ch.is_empty():
				out.append(ev(run, "scythe", "harvest", 1))
				out.append_array(ch)
	if sec(run, "spear_trident"):
		var g := int(ItemDefs.sec_num("spear_trident", "gold"))
		run.gold += g
		run.stats.gold_earned = int(run.stats.get("gold_earned", 0)) + g
		out.append(ev(run, "spear", "gilded", g))
		out.append({"type": "gold_changed", "amount": g, "total": run.gold, "source": "item"})
	if has(run, "bone_crown"):
		var cap := ni(run, "bone_crown", "max")
		if int(run.item_state.get("dominion", 0)) < cap:
			run.item_state["dominion"] = int(run.item_state.get("dominion", 0)) + 1
			out.append(ev(run, "bone_crown", "dominion_stack", int(run.item_state.dominion)))
	if sec(run, "staff_bone"):
		var mx := int(ItemDefs.sec_num("staff_bone", "max"))
		var s := mini(mx, int(run.item_state.get("soul", 0)) + int(ItemDefs.sec_num("staff_bone", "per")))
		if s != int(run.item_state.get("soul", 0)):
			run.item_state["soul"] = s
			out.append(ev(run, "arcane_staff", "soul_stack", s))
	return out

# ------------------------------------------------------------------ enemy phase

## Incoming attack value from enemy i after Vanish (the first enemy attack of the fight).
static func incoming(run: RunState, c: CombatState, _i: int, v: int, out: Array[Dictionary]) -> int:
	if not has(run, "smoke_bomb") or int(c.item_state.get("vanish", 0)) == 1 or v <= 0:
		return v
	c.item_state["vanish"] = 1
	var cut := mini(ni(run, "smoke_bomb", "max"), int(round(v * minf(0.9, n(run, "smoke_bomb", "pct")))))
	out.append(ev(run, "smoke_bomb", "vanish", cut, {"enemy_idx": _i}))
	return v - cut

## After enemy i's attack hit the hero (the hero survived): Thorns, Horned, Rattle, Catch.
static func after_enemy_hit(run: RunState, c: CombatState, i: int, blocked: int, dealt: int, block_before: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if items(run).is_empty() or not c.alive(i):
		return out
	if has(run, "spiked_shield"):
		var th := ni(run, "spiked_shield", "thorns") + (int(ItemDefs.sec_num("shield_bone_large", "thorns")) if sec(run, "shield_bone_large") else 0)
		if th > 0:
			out.append(ev(run, "spiked_shield", "thorns", th, {"enemy_idx": i}))
			out.append_array(c.damage_enemy(i, th, "thorns", run))
			if sec(run, "shield_dragon"):
				out.append_array(poison(run, c, i, int(ItemDefs.sec_num("shield_dragon", "poison")), "spiked_shield", "scorch"))
	if sec(run, "helm_bone") and block_before > 0 and c.alive(i):
		out.append(ev(run, "knight_helm", "horned", 1, {"enemy_idx": i}))
		out.append_array(c.damage_enemy(i, int(ItemDefs.sec_num("helm_bone", "dmg")), "thorns", run))
	if sec(run, "shield_bone") and blocked > 0 and run.block == 0 and c.alive(i) and int(c.item_state.get("bulwark_turn", 0)) == c.turn \
			and int(c.item_state.get("rattle", 0)) == 0:
		c.item_state["rattle"] = 1
		out.append(ev(run, "round_shield", "rattle", int(ItemDefs.sec_num("shield_bone", "dmg")), {"enemy_idx": i}))
		out.append_array(c.damage_enemy(i, int(ItemDefs.sec_num("shield_bone", "dmg")), "thorns", run))
	if sec(run, "parry_sai") and blocked > 0 and dealt == 0:
		out.append_array(bank_reroll(run, "parrying_dagger", "catch"))
	return out

# ------------------------------------------------------------------ board and economy

## Extra flat lap heal (Druid Robe's Bark).
static func lap_heal_flat(run: RunState) -> int:
	return ni(run, "druid_robe", "heal")

## Lap heal percent bonus (Tankard).
static func lap_heal_pct(run: RunState) -> float:
	return n(run, "tankard", "lap")

static func campfire_pct(run: RunState) -> float:
	return n(run, "tankard", "campfire")

static func portal_bonus(run: RunState) -> int:
	return ni(run, "compass", "portal")

## Compass II tie-break on the board move: 1 = the higher value, -1 = the lower one, 0 = random.
static func pair_pick(run: RunState) -> int:
	return ni(run, "compass", "pair_pick")

## Trap / ice dodge target (Lantern III: 3+), 0 = no change.
static func dodge_min(run: RunState) -> int:
	return ni(run, "lantern", "dodge")

static func treasury_step(run: RunState) -> int:
	return ni(run, "coin_purse", "treasury_step")

static func cashout_mult(run: RunState) -> float:
	var m := n(run, "coin_purse", "cashout")
	return m if m > 0.0 else 1.0

## Restock price override (Trader's Map), -1 = none.
static func restock_price(run: RunState) -> int:
	return ni(run, "traders_map", "restock") if has(run, "traders_map") else -1

static func free_restocks(run: RunState) -> int:
	return ni(run, "traders_map", "free")

static func shop_extra_items(run: RunState) -> int:
	return ni(run, "traders_map", "items")

static func shop_potion(run: RunState) -> bool:
	return has(run, "healers_flask")

static func potion_heal_bonus(run: RunState) -> float:
	return n(run, "healers_flask", "heal")

## Chest rune choices (Skeleton Key: 4), 0 = unchanged.
static func chest_choices(run: RunState) -> int:
	return ni(run, "skeleton_key", "choices")

static func chest_gold_mult(run: RunState) -> float:
	var m := n(run, "skeleton_key", "gold")
	return m if m > 0.0 else 1.0

## Skeleton Key III: true for the first chest of each biome (and marks it used).
static func force_rune_chest(run: RunState) -> bool:
	if ni(run, "skeleton_key", "first_rune") <= 0 or int(run.item_state.get("key_act", 0)) == run.act:
		return false
	run.item_state["key_act"] = run.act
	return true

## Shop price factor for dice and Face Raises (Engineer Goggles).
static func appraise(run: RunState) -> float:
	return 1.0 - n(run, "goggles", "pct")

## Shop Face Raise price override (Wrench tier II+), -1 = none.
static func face_raise_price(run: RunState) -> int:
	var p := ni(run, "wrench", "raise_price")
	return p if p > 0 else -1

static func forge_edits(run: RunState) -> int:
	return ni(run, "wrench", "edits")

## A board move on doubles (Bandit Mask's Ambush is primed).
static func on_board_double(run: RunState) -> Array[Dictionary]:
	if not has(run, "bandit_mask") or int(run.item_state.get("ambush", 0)) > 0:
		return []
	run.item_state["ambush"] = 1
	return [ev(run, "bandit_mask", "ambush_ready", 1)]

## A new biome started: the Druid Staff's Grove (and the Living Staff's Bloom).
static func on_biome(run: RunState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not has(run, "druid_staff"):
		return out
	var picked: Array[int] = []
	for k in ni(run, "druid_staff", "dice"):
		var best := -1
		for i in run.dice.size():
			if picked.has(i):
				continue
			var d := run.dice[i]
			if not d.can_raise(d.lowest_face()):
				continue
			if best < 0 or d.faces[d.lowest_face()] < run.dice[best].faces[run.dice[best].lowest_face()]:
				best = i
		if best < 0:
			break
		picked.append(best)
		var d2 := run.dice[best]
		var f := d2.lowest_face()
		d2.raise_face(f)
		run.stats.face_edits = int(run.stats.get("face_edits", 0)) + 1
		out.append(ev(run, "druid_staff", "grove", 1, {"die_idx": best, "face_idx": f}))
		out.append({"type": "face_changed", "die_idx": best, "face_idx": f, "value": d2.faces[f], "faces": Array(d2.faces), "source": "grove"})
		if sec(run, "staff_living"):
			out.append_array(heal(run, "druid_staff", "bloom", int(ItemDefs.sec_num("staff_living", "heal"))))
	return out

## A fight was won: Patchwork.
static func on_fight_won(run: RunState) -> Array[Dictionary]:
	if not has(run, "engineer_overalls"):
		return []
	return heal(run, "engineer_overalls", "patchwork", ni(run, "engineer_overalls", "heal"))

## Round Shield III: Last Stand is available.
static func last_stand(run: RunState) -> bool:
	return ni(run, "round_shield", "last_stand") > 0
