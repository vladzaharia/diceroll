class_name GameFlow
extends RefCounted
## Top-level run state machine. Every command validates the phase; illegal calls return
## [{type:"error", msg}] and change nothing. Successful commands are appended to `commands`
## so a seed plus the log replays exactly (see apply()).

enum Phase { BOARD_READY, BOARD_ROLLED, COMBAT, DRAFT, SHOP, FORGE, EVENT, PORTAL, GAME_OVER, VICTORY }

const SAVE_VERSION := 1

var run: RunState
var phase: Phase = Phase.BOARD_READY
var combat: CombatState = null
var board_roll: Array[int] = []
var offer: Dictionary = {}
# extras
var board_rerolls_left: int = 0
## Queue of steps still to resolve after the current modal/combat closes.
## Step kinds: tile{idx}, shop, draft, rune_choice{source}, boss, next_act, victory.
var pending: Array[Dictionary] = []
## Successful commands in order: [name, args...].
var commands: Array = []

# ================================================================ construction

static func new_run(class_id: String, seed: int) -> GameFlow:
	var f := GameFlow.new()
	if not HeroDefs.DATA.has(class_id):
		class_id = "knight"
	f.run = RunState.create(class_id, seed)
	f.phase = Phase.BOARD_READY
	return f

static func phase_name(p: int) -> String:
	return Phase.keys()[p]

func is_over() -> bool:
	return phase == Phase.GAME_OVER or phase == Phase.VICTORY

# ================================================================ board

func roll_board() -> Array[Dictionary]:
	if phase != Phase.BOARD_READY:
		return _err("roll_board")
	_record(["roll_board"])
	run.stats.board_turns = int(run.stats.get("board_turns", 0)) + 1
	board_rerolls_left = run.board_rerolls
	phase = Phase.BOARD_ROLLED
	return _do_board_roll()

func board_reroll() -> Array[Dictionary]:
	if phase != Phase.BOARD_ROLLED:
		return _err("board_reroll")
	if board_rerolls_left <= 0:
		return [_e("no board rerolls left")]
	_record(["board_reroll"])
	board_rerolls_left -= 1
	return _do_board_roll()

func _do_board_roll() -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	board_roll.clear()
	var idx: Array[int] = []
	for i in run.dice.size():
		board_roll.append(run.dice[i].value(run.dice[i].roll(run.rng)))
		idx.append(i)
	ev.append({"type": "dice_rolled", "values": board_roll.duplicate(), "indices": idx, "context": "board"})
	# Doubles feed the Treasury bank: +value*2 per value rolled at least twice.
	var counts := {}
	for v in board_roll:
		counts[v] = int(counts.get(v, 0)) + 1
	var added := 0
	for v in counts:
		if counts[v] >= 2:
			added += int(v) * Balance.TREASURY_PAIR_MULT
	run.treasury += added
	ev.append({"type": "board_rolled", "values": board_roll.duplicate(), "targets": landing_preview(),
		"treasury_added": added, "treasury": run.treasury, "rerolls_left": board_rerolls_left})
	return ev

func landing_preview() -> Array[int]:
	var out: Array[int] = []
	for v in board_roll:
		if run.lap >= Balance.LAPS_PER_ACT and Board.crosses_start(run.pos, v):
			out.append(0)
		else:
			out.append(Board.landing(run.pos, v))
	return out

func choose_move(die_idx: int) -> Array[Dictionary]:
	if phase != Phase.BOARD_ROLLED:
		return _err("choose_move")
	if die_idx < 0 or die_idx >= board_roll.size():
		return [_e("bad die index")]
	_record(["choose_move", die_idx])
	var ev: Array[Dictionary] = []
	var steps := board_roll[die_idx]
	if run.dice[die_idx].rune == "gilded":
		_gold(ev, steps, "gilded")
		ev.insert(0, {"type": "rune_fired", "die_idx": die_idx, "rune": "gilded", "effect": "gold", "value": steps})
	board_roll.clear()
	ev.append_array(_move(steps, false))
	_advance(ev)
	return ev

## Moves the hero `steps` tiles forward (or teleports), handling lap completion.
func _move(steps: int, teleport: bool) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var crossing := Board.crosses_start(run.pos, steps)
	var p := Board.path(run.pos, steps)
	if crossing and run.lap >= Balance.LAPS_PER_ACT:
		# stop on Start: act boss
		var cut: Array[int] = []
		for t in p:
			cut.append(t)
			if t == 0:
				break
		p = cut
	var dest: int = p.back()
	run.pos = dest
	ev.append({"type": "hero_moved", "path": ([dest] as Array[int]) if teleport else p, "teleport": teleport})
	if crossing:
		var healed := run.heal(run.pct_of_max(Balance.LAP_HEAL_PCT))
		var completed := run.lap
		if run.lap >= Balance.LAPS_PER_ACT:
			ev.append({"type": "lap_completed", "lap": completed, "healed": healed, "hp": run.hp, "boss": true})
			pending.push_front({"kind": "boss"})
			return ev
		run.lap += 1
		ev.append({"type": "lap_completed", "lap": completed, "healed": healed, "hp": run.hp, "boss": false})
		var changes := run.board.mutate(run.rng, run.act, run.lap, [dest])
		ev.append({"type": "board_mutated", "changes": changes})
		pending.push_back({"kind": "shop"})
	if dest != 0:
		pending.push_back({"kind": "tile", "idx": dest})
	return ev

# ================================================================ pending queue

## Resolves queued steps until one opens a modal/combat, or the queue empties.
func _advance(ev: Array[Dictionary]) -> void:
	while true:
		if is_over():
			return
		if phase in [Phase.COMBAT, Phase.DRAFT, Phase.SHOP, Phase.FORGE, Phase.EVENT, Phase.PORTAL]:
			return
		if pending.is_empty():
			phase = Phase.BOARD_READY
			offer = {}
			return
		var step: Dictionary = pending.pop_front()
		match String(step.kind):
			"tile":
				_trigger_tile(int(step.idx), ev)
			"shop":
				_open_shop(ev)
			"draft":
				_open_draft(ev)
			"rune_choice":
				_open_rune_choice(String(step.get("source", "reward")), ev)
			"boss":
				_start_combat([EnemyDefs.ACT_BOSS[run.act - 1]], false, true, 0, ev)
			"next_act":
				_next_act(ev)
			"victory":
				_finish(true, ev)

func _set_offer(o: Dictionary, p: Phase, ev: Array[Dictionary]) -> void:
	offer = o
	phase = p
	ev.append({"type": "offer_opened", "offer": o.duplicate(true)})

func _close_offer(ev: Array[Dictionary]) -> void:
	ev.append({"type": "offer_closed", "kind": String(offer.get("kind", ""))})
	offer = {}
	phase = Phase.BOARD_READY # transient; _advance picks the real next phase

# ================================================================ tiles

func _trigger_tile(idx: int, ev: Array[Dictionary]) -> void:
	var tile: Dictionary = run.board.tiles[idx]
	var type := String(tile.type)
	# The contract's tile `type` field would collide with the event `type`, so it is `tile_type`.
	ev.append({"type": "tile_triggered", "idx": idx, "tile_type": type})
	match type:
		"enemy", "elite":
			if not tile.enemies.is_empty():
				_start_combat(tile.enemies, bool(tile.elite), false, idx, ev)
		"chest":
			_consume(idx, ev)
			if run.rng.chance(Balance.CHEST_RUNE_CHANCE):
				_open_rune_choice("chest", ev)
			else:
				var g := int(round(run.rng.randi_range(Balance.CHEST_GOLD_MIN, Balance.CHEST_GOLD_MAX) * (1.0 + Balance.GOLD_ACT_STEP * (run.act - 1))))
				_gold(ev, g, "chest")
		"event":
			_consume(idx, ev)
			_open_event(ev)
		"campfire":
			_consume(idx, ev)
			var h := run.heal(run.pct_of_max(Balance.CAMPFIRE_HEAL_PCT))
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "campfire", "max_hp": run.max_hp})
		"trap":
			var roll := run.rng.randi_range(1, 6)
			var dodged := roll >= Balance.TRAP_DODGE_MIN
			var dmg := 0 if dodged else mini(run.hp, run.pct_of_max(Balance.TRAP_DAMAGE_PCT))
			run.hp -= dmg
			run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + dmg
			ev.append({"type": "trap", "roll": roll, "dodged": dodged, "damage": dmg})
			if dmg > 0:
				ev.append({"type": "hp_changed", "amount": -dmg, "total": run.hp, "source": "trap", "max_hp": run.max_hp})
			if run.hp <= 0:
				_finish(false, ev)
		"forge":
			_set_offer({"kind": "forge", "ops": ["raise", "mirror"], "source": "tile"}, Phase.FORGE, ev)
		"treasury":
			var amount := run.treasury
			run.treasury = Balance.TREASURY_START
			_gold(ev, amount, "treasury")
		"portal":
			_set_offer({"kind": "portal", "tiles": Array(Board.portal_targets(idx))}, Phase.PORTAL, ev)
		_:
			pass

func _consume(idx: int, ev: Array[Dictionary]) -> void:
	run.board.tiles[idx] = Board.make_tile("empty")
	ev.append({"type": "board_mutated", "changes": [run.board.change(idx)]})

func _gold(ev: Array[Dictionary], amount: int, source: String) -> void:
	run.gold += amount
	if amount > 0:
		run.stats.gold_earned = int(run.stats.get("gold_earned", 0)) + amount
	ev.append({"type": "gold_changed", "amount": amount, "total": run.gold, "source": source})

# ================================================================ combat

func _start_combat(ids: Array, elite: bool, boss: bool, tile: int, ev: Array[Dictionary]) -> void:
	combat = CombatState.new()
	phase = Phase.COMBAT
	ev.append_array(combat.begin(run, ids, elite, boss, tile))

func combat_toggle(die_idx: int) -> Array[Dictionary]:
	if phase != Phase.COMBAT:
		return _err("combat_toggle")
	var ev := combat.toggle(die_idx)
	if ev[0].type != "error":
		_record(["combat_toggle", die_idx])
	return ev

func combat_reroll() -> Array[Dictionary]:
	if phase != Phase.COMBAT:
		return _err("combat_reroll")
	var ev := combat.reroll(run)
	if ev[0].type != "error":
		_record(["combat_reroll"])
	return ev

func combat_set_target(enemy_idx: int) -> Array[Dictionary]:
	if phase != Phase.COMBAT:
		return _err("combat_set_target")
	var ev := combat.set_target(enemy_idx)
	if ev[0].type != "error":
		_record(["combat_set_target", enemy_idx])
	return ev

func combat_attack() -> Array[Dictionary]:
	if phase != Phase.COMBAT:
		return _err("combat_attack")
	_record(["combat_attack"])
	var ev := combat.attack(run)
	if combat.result == "lost":
		combat = null
		_finish(false, ev)
	elif combat.result == "won":
		_on_combat_won(ev)
		_advance(ev)
	return ev

func _on_combat_won(ev: Array[Dictionary]) -> void:
	var c := combat
	combat = null
	phase = Phase.BOARD_READY
	run.stats.fights_won = int(run.stats.get("fights_won", 0)) + 1
	if c.gold_reward > 0:
		_gold(ev, c.gold_reward, "combat")
	if c.tile >= 0 and not c.boss:
		run.board.clear_enemies(c.tile)
		ev.append({"type": "board_mutated", "changes": [run.board.change(c.tile)]})
	if c.boss and run.act >= Balance.ACTS:
		_finish(true, ev)
		return
	var front: Array[Dictionary] = []
	if c.elite:
		front.append({"kind": "rune_choice", "source": "elite"})
	run.xp += c.xp_reward
	while run.xp >= Balance.xp_for_level(run.level):
		run.level += 1
		ev.append({"type": "level_up", "level": run.level, "xp": run.xp, "next": Balance.xp_for_level(run.level)})
		front.append({"kind": "draft"})
	if c.boss:
		front.append({"kind": "next_act"})
	front.append_array(pending)
	pending = front

func _finish(victory: bool, ev: Array[Dictionary]) -> void:
	combat = null
	offer = {}
	pending.clear()
	board_roll.clear()
	phase = Phase.VICTORY if victory else Phase.GAME_OVER
	run.stats.victory = victory
	ev.append({"type": "game_over", "victory": victory, "stats": _summary()})

func _summary() -> Dictionary:
	var s := run.stats.duplicate(true)
	s["class_id"] = run.class_id
	s["act"] = run.act
	s["lap"] = run.lap
	s["level"] = run.level
	s["gold"] = run.gold
	s["dice"] = run.dice.size()
	return s

func _next_act(ev: Array[Dictionary]) -> void:
	run.act += 1
	run.lap = 1
	run.pos = 0
	run.treasury = Balance.TREASURY_START
	run.shop_reroll_bought = false
	run.board = Board.generate(run.rng, run.act)
	run.stats.max_act = maxi(int(run.stats.get("max_act", 1)), run.act)
	ev.append({"type": "act_started", "act": run.act, "biome": EnemyDefs.ACT_BIOME[run.act - 1], "board": run.board.to_dict()})
	var h := run.heal(run.pct_of_max(Balance.ACT_START_HEAL_PCT))
	ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "act_start", "max_hp": run.max_hp})
	pending.push_front({"kind": "shop"})

# ================================================================ draft & runes

func _open_draft(ev: Array[Dictionary]) -> void:
	var ids: Array = ["rune", "max_hp", "face_raise"]
	if run.dice.size() < Balance.MAX_DICE:
		ids.append("new_die")
	if run.combat_rerolls < Balance.MAX_COMBAT_REROLLS:
		ids.append("combat_reroll")
	run.rng.shuffle(ids)
	var options: Array = []
	for k in 3:
		options.append(_draft_option(String(ids[k])))
	_set_offer({"kind": "draft", "options": options, "source": "level"}, Phase.DRAFT, ev)

func _draft_option(id: String) -> Dictionary:
	match id:
		"new_die":
			return {"id": id, "label": "New Die", "desc": "Add a plain die to your pool."}
		"rune":
			return Runes.option(Runes.random_rune(run.rng))
		"max_hp":
			return {"id": id, "label": "+%d Max HP" % Balance.DRAFT_MAX_HP, "desc": "Gain %d max HP and heal %d." % [Balance.DRAFT_MAX_HP, Balance.DRAFT_MAX_HP]}
		"combat_reroll":
			return {"id": id, "label": "+1 Combat Reroll", "desc": "One more reroll every combat turn."}
		_:
			return {"id": "face_raise", "label": "Face Raise", "desc": "Raise one face of one die by 1."}

func _open_rune_choice(source: String, ev: Array[Dictionary]) -> void:
	var options: Array = []
	for id in Runes.random_runes(run.rng, 3):
		options.append(Runes.option(id))
	_set_offer({"kind": "draft", "options": options, "source": source}, Phase.DRAFT, ev)

func pick_draft(i: int) -> Array[Dictionary]:
	if phase != Phase.DRAFT or offer.get("kind", "") != "draft":
		return _err("pick_draft")
	if i < 0 or i >= offer.options.size():
		return [_e("bad option")]
	_record(["pick_draft", i])
	var ev: Array[Dictionary] = []
	var opt: Dictionary = offer.options[i]
	_close_offer(ev)
	match String(opt.id):
		"new_die":
			_add_die(ev)
		"rune":
			_set_offer({"kind": "rune_assign", "rune": String(opt.rune)}, Phase.DRAFT, ev)
		"max_hp":
			run.max_hp += Balance.DRAFT_MAX_HP
			var h := run.heal(Balance.DRAFT_MAX_HP)
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "draft", "max_hp": run.max_hp})
		"combat_reroll":
			run.combat_rerolls = mini(Balance.MAX_COMBAT_REROLLS, run.combat_rerolls + 1)
			ev.append({"type": "stat_changed", "stat": "combat_rerolls", "value": run.combat_rerolls})
		"face_raise":
			_set_offer({"kind": "forge", "ops": ["raise"], "source": "draft"}, Phase.FORGE, ev)
	_advance(ev)
	return ev

func _add_die(ev: Array[Dictionary]) -> void:
	if run.dice.size() >= Balance.MAX_DICE:
		return
	run.dice.append(Die.new())
	ev.append({"type": "die_added", "die_idx": run.dice.size() - 1, "die": run.dice.back().to_dict()})

func rune_assign(die_idx: int) -> Array[Dictionary]:
	if phase != Phase.DRAFT or offer.get("kind", "") != "rune_assign":
		return _err("rune_assign")
	if die_idx < 0 or die_idx >= run.dice.size():
		return [_e("bad die index")]
	_record(["rune_assign", die_idx])
	var ev: Array[Dictionary] = []
	var rune := String(offer.rune)
	var old := run.dice[die_idx].rune
	run.dice[die_idx].rune = rune
	ev.append({"type": "rune_assigned", "die_idx": die_idx, "rune": rune, "replaced": old})
	_close_offer(ev)
	_advance(ev)
	return ev

# ================================================================ shop

func _open_shop(ev: Array[Dictionary]) -> void:
	_set_offer({"kind": "shop", "items": _shop_stock()}, Phase.SHOP, ev)

func _shop_stock() -> Array:
	var weights := {}
	for id in ShopDefs.ITEMS:
		if id == "die" and run.dice.size() >= Balance.MAX_DICE:
			continue
		if id == "combat_reroll" and (run.shop_reroll_bought or run.combat_rerolls >= Balance.MAX_COMBAT_REROLLS):
			continue
		weights[id] = ShopDefs.ITEMS[id].weight
	var n := run.rng.randi_range(Balance.SHOP_MIN_ITEMS, Balance.SHOP_MAX_ITEMS)
	var items: Array = []
	var used := {}
	for k in n:
		var id := String(run.rng.weighted(weights))
		if id != "rune":
			weights.erase(id) # at most one of each non-rune item
		items.append(_shop_item(id, used))
		if weights.is_empty():
			break
	return items

func _shop_item(id: String, used: Dictionary) -> Dictionary:
	var def: Dictionary = ShopDefs.ITEMS[id]
	var item := {"id": id, "label": String(def.label), "desc": String(def.desc), "price": 0, "needs_die": bool(def.needs_die), "sold": false}
	match id:
		"die":
			item.price = Balance.SHOP_DIE_PRICE
		"potion":
			item.price = Balance.SHOP_POTION_PRICE
		"face_raise":
			item.price = Balance.SHOP_FACE_RAISE_PRICE
		"combat_reroll":
			item.price = Balance.SHOP_REROLL_ITEM_PRICE
		"rune":
			var r := Runes.random_rune(run.rng)
			for attempt in 5:
				if not used.has(r):
					break
				r = Runes.random_rune(run.rng)
			used[r] = true
			item.rune = r
			item.label = "%s Rune" % Runes.DEFS[r].name
			item.desc = String(Runes.DEFS[r].desc)
			item.price = int(Balance.RUNE_PRICE[Runes.rarity(r)])
	return item

func shop_buy(i: int, die_idx := -1) -> Array[Dictionary]:
	if phase != Phase.SHOP:
		return _err("shop_buy")
	if i < 0 or i >= offer.items.size():
		return [_e("bad item")]
	var item: Dictionary = offer.items[i]
	if item.sold:
		return [_e("sold out")]
	if run.gold < int(item.price):
		return [_e("not enough gold")]
	if item.needs_die and (die_idx < 0 or die_idx >= run.dice.size()):
		return [_e("choose a die")]
	match String(item.id):
		"die":
			if run.dice.size() >= Balance.MAX_DICE:
				return [_e("dice pool is full")]
		"face_raise":
			if run.dice[die_idx].faces[run.dice[die_idx].lowest_face()] >= 6:
				return [_e("die is maxed")]
		"combat_reroll":
			if run.combat_rerolls >= Balance.MAX_COMBAT_REROLLS or run.shop_reroll_bought:
				return [_e("unavailable")]
	_record(["shop_buy", i, die_idx])
	var ev: Array[Dictionary] = []
	run.gold -= int(item.price)
	ev.append({"type": "gold_changed", "amount": -int(item.price), "total": run.gold, "source": "shop"})
	item.sold = true
	match String(item.id):
		"die":
			_add_die(ev)
		"rune":
			var old := run.dice[die_idx].rune
			run.dice[die_idx].rune = String(item.rune)
			ev.append({"type": "rune_assigned", "die_idx": die_idx, "rune": String(item.rune), "replaced": old})
		"potion":
			var h := run.heal(run.pct_of_max(Balance.SHOP_POTION_PCT))
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "potion", "max_hp": run.max_hp})
		"face_raise":
			var f := run.dice[die_idx].lowest_face()
			run.dice[die_idx].raise_face(f)
			ev.append(_face_ev(die_idx, f))
		"combat_reroll":
			run.combat_rerolls += 1
			run.shop_reroll_bought = true
			ev.append({"type": "stat_changed", "stat": "combat_rerolls", "value": run.combat_rerolls})
	ev.append({"type": "item_bought", "index": i, "item": item.duplicate(true)})
	return ev

func shop_reroll() -> Array[Dictionary]:
	if phase != Phase.SHOP:
		return _err("shop_reroll")
	if run.gold < Balance.SHOP_RESTOCK_PRICE:
		return [_e("not enough gold")]
	_record(["shop_reroll"])
	var ev: Array[Dictionary] = []
	run.gold -= Balance.SHOP_RESTOCK_PRICE
	ev.append({"type": "gold_changed", "amount": -Balance.SHOP_RESTOCK_PRICE, "total": run.gold, "source": "shop_reroll"})
	_set_offer({"kind": "shop", "items": _shop_stock()}, Phase.SHOP, ev)
	return ev

func shop_leave() -> Array[Dictionary]:
	if phase != Phase.SHOP:
		return _err("shop_leave")
	_record(["shop_leave"])
	var ev: Array[Dictionary] = []
	_close_offer(ev)
	_advance(ev)
	return ev

# ================================================================ forge

func forge_apply(die_idx: int, face_idx: int, op: String, src_face := -1) -> Array[Dictionary]:
	if phase != Phase.FORGE:
		return _err("forge_apply")
	if op != "skip":
		if not Array(offer.get("ops", [])).has(op):
			return [_e("operation not allowed: " + op)]
		if die_idx < 0 or die_idx >= run.dice.size() or face_idx < 0 or face_idx > 5:
			return [_e("bad die or face")]
		var d := run.dice[die_idx]
		if op == "raise" and d.faces[face_idx] >= 6:
			return [_e("face is already 6")]
		if op == "mirror" and (src_face < 0 or src_face > 5 or src_face == face_idx or d.faces[src_face] == d.faces[face_idx]):
			return [_e("bad mirror source")]
	_record(["forge_apply", die_idx, face_idx, op, src_face])
	var ev: Array[Dictionary] = []
	if op == "raise":
		run.dice[die_idx].raise_face(face_idx)
		ev.append(_face_ev(die_idx, face_idx))
	elif op == "mirror":
		run.dice[die_idx].mirror_face(face_idx, src_face)
		ev.append(_face_ev(die_idx, face_idx))
	_close_offer(ev)
	_advance(ev)
	return ev

func _face_ev(die_idx: int, face_idx: int) -> Dictionary:
	return {"type": "face_changed", "die_idx": die_idx, "face_idx": face_idx, "value": run.dice[die_idx].faces[face_idx], "faces": Array(run.dice[die_idx].faces)}

# ================================================================ events

func _open_event(ev: Array[Dictionary], forced_id := "") -> void:
	var id := forced_id if forced_id != "" else String(run.rng.pick(EventDefs.IDS))
	var def: Dictionary = EventDefs.DATA[id]
	var choices: Array = []
	match id:
		"shrine":
			var keys: Array = EventDefs.BLESSINGS.keys()
			run.rng.shuffle(keys)
			for k in 2:
				var b: Dictionary = EventDefs.BLESSINGS[keys[k]]
				choices.append({"label": b.label, "desc": b.desc, "enabled": true, "blessing": keys[k]})
		"duel":
			choices.append({"label": "Bet 10 gold", "desc": "Win: +10. Lose: -10.", "enabled": run.gold >= 10, "bet": 10})
			choices.append({"label": "Bet 25 gold", "desc": "Win: +25. Lose: -25.", "enabled": run.gold >= 25, "bet": 25})
			choices.append({"label": "Walk away", "desc": "Keep your gold.", "enabled": true, "bet": 0})
		"outbreak":
			choices.append({"label": "Brace yourself", "desc": "The next 3 empty tiles ahead become enemies.", "enabled": true})
		"garden":
			choices.append({"label": "Gather the blooms", "desc": "The next 3 empty tiles ahead become chests.", "enabled": true})
		"merchant":
			var loss := run.pct_of_max(Balance.MERCHANT_HP_PCT)
			choices.append({"label": "Trade %d max HP" % loss, "desc": "Receive a random Rare rune.", "enabled": run.max_hp - loss >= 10})
			choices.append({"label": "Decline", "desc": "Keep walking.", "enabled": true})
		"idol":
			choices.append({"label": "Offer blood", "desc": "Take %d damage. The lowest face of every die gets +1." % Balance.IDOL_DAMAGE, "enabled": run.hp > Balance.IDOL_DAMAGE})
			choices.append({"label": "Leave", "desc": "Nothing happens.", "enabled": true})
	_set_offer({"kind": "event", "id": id, "title": def.title, "text": def.text, "choices": choices}, Phase.EVENT, ev)

func event_choose(i: int) -> Array[Dictionary]:
	if phase != Phase.EVENT:
		return _err("event_choose")
	if i < 0 or i >= offer.choices.size():
		return [_e("bad choice")]
	var choice: Dictionary = offer.choices[i]
	if not choice.enabled:
		return [_e("choice disabled")]
	_record(["event_choose", i])
	var ev: Array[Dictionary] = []
	var id := String(offer.id)
	_close_offer(ev)
	match id:
		"shrine":
			match String(choice.blessing):
				"atk":
					run.atk += Balance.SHRINE_ATK
					ev.append({"type": "stat_changed", "stat": "atk", "value": run.atk})
				"max_hp":
					run.max_hp += Balance.SHRINE_MAX_HP
					var h := run.heal(Balance.SHRINE_MAX_HP)
					ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "shrine", "max_hp": run.max_hp})
				"gold":
					_gold(ev, Balance.SHRINE_GOLD, "shrine")
				"face":
					var opts: Array = []
					for d in run.dice.size():
						for f in 6:
							if run.dice[d].faces[f] < 6:
								opts.append([d, f])
					if not opts.is_empty():
						var p: Array = run.rng.pick(opts)
						run.dice[p[0]].raise_face(p[1])
						ev.append(_face_ev(p[0], p[1]))
		"duel":
			var bet := int(choice.bet)
			if bet > 0:
				var mine: Array = [run.rng.randi_range(1, 6), run.rng.randi_range(1, 6)]
				var theirs: Array = [run.rng.randi_range(1, 6), run.rng.randi_range(1, 6)]
				var a: int = mine[0] + mine[1]
				var b: int = theirs[0] + theirs[1]
				var outcome := 1 if a > b else (-1 if a < b else 0)
				ev.append({"type": "duel", "player": mine, "npc": theirs, "outcome": outcome, "bet": bet})
				if outcome != 0:
					_gold(ev, bet * outcome, "duel")
		"outbreak", "garden":
			var type := "enemy" if id == "outbreak" else "chest"
			var changes: Array[Dictionary] = []
			for idx in run.board.next_of_type(run.pos, "empty", 3):
				changes.append(run.board.set_tile(idx, type, run.rng, run.act, run.lap))
			ev.append({"type": "board_mutated", "changes": changes})
		"merchant":
			if i == 0:
				var loss := run.pct_of_max(Balance.MERCHANT_HP_PCT)
				run.max_hp -= loss
				var before := run.hp
				run.hp = mini(run.hp, run.max_hp)
				ev.append({"type": "hp_changed", "amount": run.hp - before, "total": run.hp, "source": "merchant", "max_hp": run.max_hp})
				_set_offer({"kind": "rune_assign", "rune": Runes.random_rune(run.rng, "rare")}, Phase.DRAFT, ev)
		"idol":
			if i == 0:
				run.hp -= Balance.IDOL_DAMAGE
				run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + Balance.IDOL_DAMAGE
				ev.append({"type": "hp_changed", "amount": -Balance.IDOL_DAMAGE, "total": run.hp, "source": "idol", "max_hp": run.max_hp})
				for d in run.dice.size():
					var f := run.dice[d].lowest_face()
					if run.dice[d].raise_face(f):
						ev.append(_face_ev(d, f))
	_advance(ev)
	return ev

# ================================================================ portal

func portal_pick(tile_idx: int) -> Array[Dictionary]:
	if phase != Phase.PORTAL:
		return _err("portal_pick")
	if not Array(offer.get("tiles", [])).has(tile_idx):
		return [_e("tile out of portal range")]
	_record(["portal_pick", tile_idx])
	var ev: Array[Dictionary] = []
	_close_offer(ev)
	var steps := (tile_idx - run.pos + Board.SIZE) % Board.SIZE
	ev.append_array(_move(steps, true))
	_advance(ev)
	return ev

# ================================================================ replay & serialisation

## Replays one logged command: [name, args...].
func apply(cmd: Array) -> Array[Dictionary]:
	var a := cmd.slice(1)
	for k in a.size():
		if a[k] is float:
			a[k] = int(a[k])
	match String(cmd[0]):
		"roll_board": return roll_board()
		"board_reroll": return board_reroll()
		"choose_move": return choose_move(a[0])
		"combat_toggle": return combat_toggle(a[0])
		"combat_reroll": return combat_reroll()
		"combat_set_target": return combat_set_target(a[0])
		"combat_attack": return combat_attack()
		"pick_draft": return pick_draft(a[0])
		"shop_buy": return shop_buy(a[0], a[1] if a.size() > 1 else -1)
		"shop_reroll": return shop_reroll()
		"shop_leave": return shop_leave()
		"forge_apply": return forge_apply(a[0], a[1], String(a[2]), a[3] if a.size() > 3 else -1)
		"event_choose": return event_choose(a[0])
		"portal_pick": return portal_pick(a[0])
		"rune_assign": return rune_assign(a[0])
	return [_e("unknown command " + str(cmd[0]))]

## Replays a whole command log from a fresh run.
static func replay(class_id: String, seed: int, log_: Array) -> GameFlow:
	var f := GameFlow.new_run(class_id, seed)
	for cmd in log_:
		f.apply(cmd)
	return f

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "run": run.to_dict(), "phase": int(phase),
		"combat": combat.to_dict() if combat != null else null,
		"board_roll": Array(board_roll), "offer": offer.duplicate(true),
		"board_rerolls_left": board_rerolls_left, "pending": pending.duplicate(true),
		"commands": commands.duplicate(true),
	}

static func from_dict(d: Dictionary) -> GameFlow:
	var f := GameFlow.new()
	f.run = RunState.from_dict(d.run)
	f.phase = int(d.phase) as Phase
	if d.get("combat") != null:
		f.combat = CombatState.from_dict(d.combat)
	for v in d.get("board_roll", []):
		f.board_roll.append(int(v))
	f.offer = _intify(d.get("offer", {}))
	f.board_rerolls_left = int(d.get("board_rerolls_left", 0))
	for p in d.get("pending", []):
		f.pending.append(_intify(p))
	f.commands = _intify(d.get("commands", []))
	return f

## Converts integral floats (from JSON) back to ints, recursively.
static func _intify(v: Variant) -> Variant:
	if v is float and v == floor(v):
		return int(v)
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_intify(x))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _intify(v[k])
		return out
	return v

# ================================================================ helpers

func _record(cmd: Array) -> void:
	commands.append(cmd)
	run.stats.commands = int(run.stats.get("commands", 0)) + 1

func _err(cmd: String) -> Array[Dictionary]:
	return [_e("%s is not allowed in phase %s" % [cmd, phase_name(phase)])]

static func _e(msg: String) -> Dictionary:
	return {"type": "error", "msg": msg}
