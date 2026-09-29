class_name PetLogic
extends RefCounted
## Pet runtime (PetDefs has the table). The charge lives in run.pet_state.charge and persists
## across fights and board turns. Every function is a no-op without a pet, so legacy runs
## never touch the Rng here.
## Events: pet_charged {pet, charge, size, gained} · pet_acted {pet, effect, value, target}
## (effect: heal | bite | poison | reroll | block | gold | brew, target: "hero" | enemy idx | "all").

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

## After an attack resolved: charge from its dice (pair_plus, low_die, six, kept).
static func on_attack_resolved(run: RunState, c: CombatState, combo_id: String, values: Array) -> Array[Dictionary]:
	var id := run.pet_id()
	if id == "":
		return []
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
	return _charge(run, n)
