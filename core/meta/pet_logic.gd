class_name PetLogic
extends RefCounted
## Pet runtime (PetDefs has the table). The charge lives in run.pet_state.charge and persists
## across fights and board turns. Every function is a no-op without a pet, so legacy runs
## never touch the Rng here.
## Events: pet_charged {pet, charge, size, gained} · pet_acted {pet, effect, value, target}
## (effect: heal | bite | poison | reroll | block | gold | brew, target: "hero" | enemy idx | "all").
## New pets: pebble_golem "block" (+ a second pet_acted "thorns" {value}) · frost_mote "freeze"
## {target, value} · wick "burn" {target: "all", value} · tinker_gear "fix" {die_idx, face} ·
## grimoire "rune" {rune, die_idx, value} · cauldron "potion" {potion} (fires after a won fight).

static func _charge(run: RunState, amount: int) -> Array[Dictionary]:
	var id := run.pet_id()
	if id == "" or amount <= 0:
		return []
	var size := PetDefs.size(id)
	var before := int(run.pet_state.get("charge", 0))
	var now := mini(size, before + amount)
	run.pet_state["charge"] = now
	if now == before:
		return []
	return [{"type": "pet_charged", "pet": id, "charge": now, "size": size, "gained": now - before}]

## Adds charge from outside the pet rules (the Druid's Wild Bond). Returns pet_charged or [].
static func add_charge(run: RunState, amount: int) -> Array[Dictionary]:
	return _charge(run, amount)

static func is_full(run: RunState) -> bool:
	var id := run.pet_id()
	return id != "" and int(run.pet_state.get("charge", 0)) >= PetDefs.size(id)

static func _acted(run: RunState, effect: String, value: int, target: Variant) -> Dictionary:
	run.pet_state["charge"] = 0
	run.stats.pet_actions = int(run.stats.get("pet_actions", 0)) + 1
	return {"type": "pet_acted", "pet": run.pet_id(), "effect": effect, "value": value, "target": target}

## Board double (confirm_move with doubles): Coin Mimic charges.
static func on_board_double(run: RunState) -> Array[Dictionary]:
	if run.pet_id() != "coin_mimic":
		return []
	return _charge(run, 1)

## Start of a player turn: Guard Die charges from attack intents, Crystal Wisp fires, Guard Die's
## L5 carried Block lands.
static func on_turn_start(run: RunState, c: CombatState) -> Array[Dictionary]:
	var id := run.pet_id()
	var ev: Array[Dictionary] = []
	if id == "":
		return ev
	var lvl := run.pet_level()
	if id == "guard_die":
		if c.pet_block_carry > 0:
			run.block += c.pet_block_carry
			run.stats.block_gained = int(run.stats.get("block_gained", 0)) + c.pet_block_carry
			ev.append({"type": "block_gained", "target": "hero", "amount": c.pet_block_carry, "total": run.block, "source": "pet"})
			c.pet_block_carry = 0
		var n := 0
		for i in c.enemies.size():
			if c.alive(i) and ["attack", "chill", "drain"].has(String(c.enemies[i].intent.kind)):
				n += 1
		ev.append_array(_charge(run, n))
	elif id == "crystal_wisp" and is_full(run):
		c.rerolls_left += PetDefs.WISP_REROLLS
		c.pet_mult += PetDefs.wisp_mult(lvl)
		ev.append(_acted(run, "reroll", PetDefs.WISP_REROLLS, "hero"))
		if lvl >= 5:
			if run.banked_rerolls < Balance.MAX_BANKED_REROLLS:
				run.banked_rerolls += 1
			for i in c.locked.size():
				if c.locked[i]:
					c.locked[i] = false
					ev.append({"type": "status", "target": "hero", "status": "curse", "value": 0, "die_idx": i, "source": "pet"})
					break
		if lvl >= 10 and not c.wisp_used:
			c.wisp_used = true
			c.wisp_free = 1
		ev.append({"type": "rerolls_changed", "rerolls_left": c.rerolls_left})
	return ev

## Start of attack resolution: every pet but Crystal Wisp fires here when its meter is full.
static func fire_at_attack(run: RunState, c: CombatState) -> Array[Dictionary]:
	var id := run.pet_id()
	var ev: Array[Dictionary] = []
	if id == "" or id == "crystal_wisp" or not is_full(run):
		return ev
	var lvl := run.pet_level()
	c._fix_target()
	match id:
		"pumpkin_sprite":
			var amt := run.pct_of_max(PetDefs.heal_pct(lvl))
			var h := run.heal(amt)
			ev.append(_acted(run, "heal", h, "hero"))
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "pet", "max_hp": run.max_hp})
			if lvl >= 5 and c.hero_burn > 0:
				c.hero_burn = 0
				ev.append({"type": "status", "target": "hero", "status": "burn", "value": 0, "source": "pet"})
			if lvl >= 10 and amt > h:
				run.block += amt - h
				run.stats.block_gained = int(run.stats.get("block_gained", 0)) + amt - h
				ev.append({"type": "block_gained", "target": "hero", "amount": amt - h, "total": run.block, "source": "pet"})
		"skull_buddy":
			var cb := c.current_combo(run)
			var pips := 0
			for v in cb.values:
				pips += maxi(1 if lvl >= 10 else 0, int(v))
			var dmg := maxi(PetDefs.BITE_MIN, int(round(PetDefs.bite_pct(lvl) * pips * float(cb.mult))))
			var tgt := c.target
			ev.append(_acted(run, "bite", dmg, "all" if lvl >= 5 else tgt))
			ev.append_array(c.damage_enemy(tgt, dmg, "pet", run))
			if lvl >= 5:
				for j in c.enemies.size():
					if j != tgt and c.alive(j):
						ev.append_array(c.damage_enemy(j, maxi(1, dmg / 2), "pet", run))
		"lantern_ghost":
			var p := PetDefs.poison(lvl)
			ev.append(_acted(run, "poison", p, "all"))
			for j in c.enemies.size():
				if c.alive(j):
					c.enemies[j].poison = int(c.enemies[j].poison) + p
					ev.append({"type": "status", "target": j, "status": "poison", "value": int(c.enemies[j].poison), "source": "pet"})
		"guard_die":
			var pips := run.rng.randi_range(1, 6)
			var b := pips + PetDefs.block_bonus(lvl)
			run.block += b
			run.stats.block_gained = int(run.stats.get("block_gained", 0)) + b
			ev.append(_acted(run, "block", b, "hero"))
			ev.append({"type": "block_gained", "target": "hero", "amount": b, "total": run.block, "source": "pet", "roll": pips})
			if lvl >= 5:
				c.pet_block_carry = b / 2
			if lvl >= 10 and pips == 6 and c.alive(c.target):
				c.enemies[c.target].frozen = true
				ev.append({"type": "status", "target": c.target, "status": "frozen", "value": 1, "source": "pet"})
		"pebble_golem":
			var b := PetDefs.pebble_block(lvl)
			run.block += b
			c.pet_block_turn += b
			c.pet_thorns = PetDefs.pebble_thorns(lvl)
			run.stats.block_gained = int(run.stats.get("block_gained", 0)) + b
			ev.append(_acted(run, "block", b, "hero"))
			ev.append({"type": "block_gained", "target": "hero", "amount": b, "total": run.block, "source": "pet"})
			ev.append({"type": "pet_acted", "pet": id, "effect": "thorns", "value": c.pet_thorns, "target": "hero"})
		"frost_mote":
			var tgt := c.target
			var targets: Array[int] = [tgt]
			if lvl >= 5:
				var big := -1
				var big_v := -1
				for j in c.enemies.size():
					if j != tgt and c.alive(j) and ["attack", "chill", "drain"].has(String(c.enemies[j].intent.kind)) and int(c.enemies[j].intent.value) > big_v:
						big_v = int(c.enemies[j].intent.value)
						big = j
				if big >= 0:
					targets.append(big)
			ev.append(_acted(run, "freeze", PetDefs.frost_damage(lvl), tgt))
			for j in targets:
				if not c.alive(j):
					continue
				c.enemies[j].frozen = true
				run.stats.freezes = int(run.stats.get("freezes", 0)) + 1
				ev.append({"type": "status", "target": j, "status": "frozen", "value": 1, "source": "pet"})
				if lvl >= 10 and int(c.enemies[j].block) > 0:
					var lost := int(c.enemies[j].block)
					c.enemies[j].block = 0
					ev.append({"type": "block_gained", "target": j, "amount": -lost, "total": 0, "source": "pet"})
				ev.append_array(c.damage_enemy(j, PetDefs.frost_damage(lvl), "pet", run))
		"wick":
			var dmg := PetDefs.wick_damage(lvl)
			ev.append(_acted(run, "burn", dmg, "all"))
			for j in c.enemies.size():
				if c.alive(j):
					ev.append_array(c.damage_enemy(j, dmg, "pet", run, lvl >= 10))
		"tinker_gear":
			var n := 2 if lvl >= 5 else 1
			var fixed := 0
			var order: Array = []
			for i in c.dice_values.size():
				if not c.locked[i]:
					order.append(i)
			order.sort_custom(func(a, b): return c.dice_values[a] < c.dice_values[b])
			var first := true
			for i in order:
				if fixed >= n:
					break
				var dd := c.die_at(run, int(i))
				var hi := 0
				for f in 6:
					if dd.faces[f] <= DiceKinds.MAX_VALUE and dd.faces[f] > dd.faces[hi]:
						hi = f
				if dd.faces[hi] <= c.dice_values[i]:
					continue
				c.dice_faces[i] = hi
				c.dice_values[i] = dd.faces[hi]
				fixed += 1
				if first:
					ev.append(_acted(run, "fix", dd.faces[hi], "hero"))
					ev.back()["die_idx"] = int(i)
					ev.back()["face"] = dd.faces[hi]
					first = false
				else:
					ev.append({"type": "pet_acted", "pet": id, "effect": "fix", "value": dd.faces[hi], "target": "hero", "die_idx": int(i), "face": dd.faces[hi]})
			if fixed == 0:
				ev.append(_acted(run, "fix", 0, "hero"))
			c.pet_mult += PetDefs.tinker_mult(lvl)
			if lvl >= 10 and run.banked_rerolls < Balance.MAX_BANKED_REROLLS:
				run.banked_rerolls += 1
			ev.append({"type": "dice_rolled", "values": c.dice_values.duplicate(), "indices": [], "context": "combat",
				"faces": c.dice_faces.duplicate(), "rerolls_left": c.rerolls_left, "source": "pet"})
		"grimoire":
			var runes: Array = []
			var vals: Array = []
			for k in [["rune", "rune_v"], ["rune2", "rune2_v"]]:
				var code := int(run.pet_state.get(k[0], -1))
				if code >= 0 and code < Runes.IDS.size():
					runes.append(String(Runes.IDS[code]))
					vals.append(int(run.pet_state.get(k[1], 0)))
			if lvl < 5:
				runes = runes.slice(0, 1)
			if runes.is_empty():
				ev.append(_acted(run, "rune", 0, "hero"))
			for k in runes.size():
				var r := String(runes[k])
				var v := int(round(int(vals[k]) * PetDefs.grimoire_mult(lvl)))
				if k == 0:
					ev.append(_acted(run, "rune", v, c.target))
				else:
					ev.append({"type": "pet_acted", "pet": id, "effect": "rune", "value": v, "target": c.target})
				ev.back()["rune"] = r
				ev.back()["die_idx"] = int(run.pet_state.get("rune_die" if k == 0 else "rune2_die", -1))
				ev.append_array(_refire(run, c, r, v))
		"coin_mimic":
			var g := run.gold_bonus(PetDefs.mimic_gold(lvl))
			run.gold += g
			run.stats.gold_earned = int(run.stats.get("gold_earned", 0)) + g
			ev.append(_acted(run, "gold", g, "hero"))
			ev.append({"type": "gold_changed", "amount": g, "total": run.gold, "source": "pet"})
			var bite := mini(10, run.gold / 20)
			if bite > 0:
				ev.append_array(c.damage_enemy(c.target, bite, "pet", run))
	return ev

## Grimoire: one rune effect again (never doubled by Resonance / Rune Echo).
static func _refire(run: RunState, c: CombatState, r: String, v: int) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	c._fix_target()
	var t := c.target
	match r:
		"blade", "heavy", "echo", "wild", "lucky":
			ev.append_array(c.damage_enemy(t, maxi(1, v), "pet", run))
		"ember":
			for j in c.enemies.size():
				if c.alive(j):
					ev.append_array(c.damage_enemy(j, maxi(6, v), "pet", run))
		"thunder":
			var a := c.alive_indices()
			if not a.is_empty():
				ev.append_array(c.damage_enemy(int(run.rng.pick(a)), maxi(1, v), "pet", run))
		"venom":
			if c.alive(t):
				c.enemies[t].poison = int(c.enemies[t].poison) + maxi(1, v)
				ev.append({"type": "status", "target": t, "status": "poison", "value": int(c.enemies[t].poison), "source": "pet"})
		"frost":
			if c.alive(t):
				c.enemies[t].frozen = true
				ev.append({"type": "status", "target": t, "status": "frozen", "value": 1, "source": "pet"})
		"guard":
			run.block += maxi(1, v)
			c.pet_block_turn += maxi(1, v)
			ev.append({"type": "block_gained", "target": "hero", "amount": maxi(1, v), "total": run.block, "source": "pet"})
		"vampire":
			var h := run.heal(maxi(1, v))
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "pet", "max_hp": run.max_hp})
		"gilded":
			run.gold += 2
			ev.append({"type": "gold_changed", "amount": 2, "total": run.gold, "source": "pet"})
	return ev

## A combat reroll: Tinker charges.
static func on_reroll(run: RunState) -> Array[Dictionary]:
	if run.pet_id() != "tinker_gear":
		return []
	return _charge(run, 1)

## A fight was won: Bubbles charges and brews when full. Returns its events (GameFlow applies
## the potion through `gain_potion` / `drink`, callables taking (ev, source, type)).
static func on_fight_won(run: RunState) -> Array[Dictionary]:
	if run.pet_id() != "cauldron":
		return []
	return _charge(run, 1)

## After an attack resolved: charge from its dice (pair_plus, low_die, six, kept).
static func on_attack_resolved(run: RunState, c: CombatState, combo_id: String, values: Array) -> Array[Dictionary]:
	var id := run.pet_id()
	if id == "":
		return []
	if c.last_runes.size() > 0:
		# Grimoire memory: the last rune that triggered (and the last different one before it)
		var last: Dictionary = c.last_runes.back()
		var code := Runes.IDS.find(String(last.rune))
		var prev := int(run.pet_state.get("rune", -1))
		if prev != code and prev >= 0:
			run.pet_state["rune2"] = prev
			run.pet_state["rune2_v"] = int(run.pet_state.get("rune_v", 0))
			run.pet_state["rune2_die"] = int(run.pet_state.get("rune_die", -1))
		for k in range(c.last_runes.size() - 2, -1, -1):
			var o: Dictionary = c.last_runes[k]
			if String(o.rune) != String(last.rune):
				run.pet_state["rune2"] = Runes.IDS.find(String(o.rune))
				run.pet_state["rune2_v"] = int(o.value)
				run.pet_state["rune2_die"] = int(o.die)
				break
		run.pet_state["rune"] = code
		run.pet_state["rune_v"] = int(last.value)
		run.pet_state["rune_die"] = int(last.die)
	var n := 0
	match PetDefs.charge_on(id):
		"pair_plus":
			n = 0 if combo_id == "high_roller" or combo_id == "" else 1
		"low_die":
			for v in values:
				if int(v) == 0:
					n += 2 if run.pet_level() >= 10 else 1
				elif int(v) <= PetDefs.LOW_DIE_MAX:
					n += 1
		"six":
			for v in values:
				if int(v) == 6:
					n += 1
		"kept":
			for i in c.rerolled.size():
				if not c.rerolled[i]:
					n += 1
		"block":
			n = maxi(0, run.block - c.pet_block_turn) / PetDefs.BLOCK_PER_CHARGE
		"one":
			for v in values:
				if int(v) == 1:
					n += 1
		"set3":
			var sets := ["three_kind", "full_house", "four_kind", "five_kind", "six_kind"]
			if run.pet_level() >= 5:
				sets.append("two_pair")
			n = 1 if sets.has(combo_id) else 0
		"rune":
			n = 1 if c.last_runes.size() > 0 else 0
	return _charge(run, n)
