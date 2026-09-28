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
## The two dice auto-selected to move (indices into board_roll) and their summed move.
var board_choice: Array[int] = []
var board_move: int = 0
# extras
var board_rerolls_left: int = 0
## Queue of steps still to resolve after the current modal/combat closes.
## Step kinds: tile{idx}, shop, draft, rune_choice{source}, passive_choice{source, tier}, boss,
## bonus_move{steps}, victory.
var pending: Array[Dictionary] = []
## Successful commands in order: [name, args...].
var commands: Array = []

# ================================================================ construction

## board_size: ring size, 24, 28 (default) or 32.
## opts (optional, scenarios/tests): {route:[tier1, tier2, tier3], miniboss:id, boss:id}.
## Without them the route (one biome per tier) and bosses are drawn from the seed.
static func new_run(class_id: String, seed: int, board_size: int = Balance.BOARD_SIZE, opts: Dictionary = {}) -> GameFlow:
	var f := GameFlow.new()
	if not HeroDefs.DATA.has(class_id):
		class_id = "knight"
	f.run = RunState.create(class_id, seed, board_size, opts)
	f.phase = Phase.BOARD_READY
	return f

## The run's route for presentation: {route:[{id, name, desc}], miniboss:{id, name},
## boss:{id, name}}.
func route_info() -> Dictionary:
	var r: Array = []
	for b in run.route:
		r.append({"id": b, "name": BiomeDefs.name_of(b), "desc": BiomeDefs.desc_of(b)})
	return {
		"route": r,
		"miniboss": {"id": run.miniboss_id, "name": String(EnemyDefs.def(run.miniboss_id).name)},
		"boss": {"id": run.boss_id, "name": String(EnemyDefs.def(run.boss_id).name)},
	}

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
	board_rerolls_left = run.board_rerolls + (1 if run.has_passive("pathfinder") else 0)
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
	var values: Array[int] = []
	var idx: Array[int] = []
	for i in run.dice.size():
		values.append(run.dice[i].value(run.dice[i].roll(run.rng)))
		idx.append(i)
	ev.append({"type": "dice_rolled", "values": values.duplicate(), "indices": idx, "context": "board"})
	_select_move(values)
	# Chosen doubles feed the Treasury bank: +value * TREASURY_PAIR_MULT.
	var added := 0
	if is_board_double():
		added = board_roll[board_choice[0]] * Balance.TREASURY_PAIR_MULT
	run.treasury += added
	ev.append({"type": "board_rolled", "values": board_roll.duplicate(), "chosen": board_choice.duplicate(),
		"move": board_move, "target": board_target(), "targets": landing_preview(), "double": is_board_double(),
		"treasury_added": added, "treasury": run.treasury, "rerolls_left": board_rerolls_left})
	return ev

## Sets the current board roll and auto-selects the two moving dice (see pick_move_dice).
func _select_move(values: Array[int]) -> void:
	board_roll = values.duplicate()
	board_choice = pick_move_dice(values, run.rng)
	board_move = 0
	for i in board_choice:
		board_move += board_roll[i]

## Movement rule: the pool rolls, then two dice are picked automatically.
## Blank faces (0) are ignored unless fewer than two dice show a value. The most frequent value
## wins: if some value shows at least twice, two dice of that value move (ties between values
## are broken at random). If every value is unique, two random dice move. A 2-die pool moves
## both. Returns the two dice indices, ascending. The move is their sum.
static func pick_move_dice(values: Array[int], rng: Rng) -> Array[int]:
	var n := values.size()
	var out: Array[int] = []
	if n <= 2:
		for i in n:
			out.append(i)
		return out
	var live: Array[int] = []
	var blanks: Array[int] = []
	for i in n:
		if values[i] > 0:
			live.append(i)
		else:
			blanks.append(i)
	if live.size() < 2:
		out.append_array(live)
		while out.size() < 2:
			var b: int = rng.pick(blanks)
			blanks.erase(b)
			out.append(b)
		out.sort()
		return out
	var by_val := {}
	for i in live:
		if not by_val.has(values[i]):
			by_val[values[i]] = [] as Array[int]
		(by_val[values[i]] as Array[int]).append(i)
	var best := 0
	for v in by_val:
		best = maxi(best, (by_val[v] as Array[int]).size())
	if best >= 2:
		var tied: Array = []
		for v in by_val:
			if (by_val[v] as Array[int]).size() == best:
				tied.append(v)
		tied.sort()
		var pick_v: int = tied[0] if tied.size() == 1 else int(rng.pick(tied))
		var group: Array[int] = by_val[pick_v]
		out.append(group[0])
		out.append(group[1])
		return out
	var pool := live.duplicate()
	var a: int = rng.pick(pool)
	pool.erase(a)
	var b2: int = rng.pick(pool)
	out.append(a)
	out.append(b2)
	out.sort()
	return out

## True when the two chosen dice show the same non-blank value.
func is_board_double() -> bool:
	return board_choice.size() == 2 and board_roll[board_choice[0]] > 0 \
		and board_roll[board_choice[0]] == board_roll[board_choice[1]]

## Landing tile of the current move (Start on the final lap if the move crosses it).
func board_target() -> int:
	if run.lap >= Balance.TOTAL_LAPS and run.board.crosses_start(run.pos, board_move):
		return 0
	return run.board.landing(run.pos, board_move)

## [target] for the current board roll (kept as an array for the old contract).
func landing_preview() -> Array[int]:
	if board_roll.is_empty():
		return []
	return [board_target()] as Array[int]

## Executes the auto-selected move for the current board roll.
func confirm_move() -> Array[Dictionary]:
	if phase != Phase.BOARD_ROLLED:
		return _err("confirm_move")
	_record(["confirm_move"])
	var ev: Array[Dictionary] = []
	var steps := board_move
	for i in board_choice:
		if run.dice[i].rune == "gilded" and board_roll[i] > 0:
			ev.append({"type": "rune_fired", "die_idx": i, "rune": "gilded", "effect": "gold", "value": board_roll[i]})
			_gold(ev, board_roll[i], "gilded")
	var doubles := is_board_double()
	var hop := board_roll[board_choice[0]] if doubles else 0
	if doubles and run.has_passive("double_trouble") and run.banked_rerolls < Balance.MAX_BANKED_REROLLS:
		run.banked_rerolls += 1
		ev.append(_passive_ev("double_trouble", 1))
	board_roll.clear()
	board_choice.clear()
	board_move = 0
	ev.append_array(_move(steps, false))
	if doubles and steps > 0 and run.has_passive("fast_feet") and not _pending_has("boss"):
		pending.push_back({"kind": "bonus_move", "steps": hop})
	_advance(ev)
	return ev

## Deprecated: the move is chosen automatically now. Ignores `die_idx` and calls confirm_move().
func choose_move(_die_idx: int = 0) -> Array[Dictionary]:
	return confirm_move()

func _pending_has(kind: String) -> bool:
	for p in pending:
		if p.kind == kind:
			return true
	return false

## Moves the hero `steps` tiles forward (or teleports), handling lap completion.
## Passing Start completes a lap: heal, lap += 1, then either a new biome (laps 6 and 11:
## regenerated board, act_started) or a board mutation (plus the mini-boss when lap 7 starts),
## then the shop on shop laps. Completing the final lap stops on Start for the final boss.
func _move(steps: int, teleport: bool) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if steps <= 0:
		# A blank face (0) keeps the hero in place; the current tile does not trigger again.
		ev.append({"type": "hero_stayed", "pos": run.pos})
		return ev
	var crossing := run.board.crosses_start(run.pos, steps)
	var p := run.board.path(run.pos, steps)
	var final_lap := run.lap >= Balance.TOTAL_LAPS
	if crossing and final_lap:
		# stop on Start: final boss
		var cut: Array[int] = []
		for t in p:
			cut.append(t)
			if t == 0:
				break
		p = cut
	var dest: int = p.back()
	run.pos = dest
	ev.append({"type": "hero_moved", "path": ([dest] as Array[int]) if teleport else p, "teleport": teleport})
	if not teleport:
		# Magma lava scorches every lava tile passed over (landing is handled by the tile).
		for k in range(0, p.size() - 1):
			if String(run.board.tiles[p[k]].type) == "lava":
				_lava(p[k], false, ev)
	if crossing:
		var healed := run.heal(run.pct_of_max(Balance.LAP_HEAL_PCT))
		var completed := run.lap
		if final_lap:
			ev.append({"type": "lap_completed", "lap": completed, "healed": healed, "hp": run.hp, "boss": true})
			ev.append({"type": "hp_changed", "amount": healed, "total": run.hp, "source": "lap", "max_hp": run.max_hp})
			pending.push_front({"kind": "boss"})
			return ev
		run.lap += 1
		ev.append({"type": "lap_completed", "lap": completed, "healed": healed, "hp": run.hp, "boss": false})
		ev.append({"type": "hp_changed", "amount": healed, "total": run.hp, "source": "lap", "max_hp": run.max_hp})
		if Balance.act_for_lap(run.lap) != run.act:
			_new_biome(dest, ev)
		else:
			var changes := run.board.mutate(run.rng, run.act, run.lap, [dest])
			if run.lap == Balance.MINIBOSS_LAP:
				var mb := run.board.spawn_miniboss(run.rng, run.miniboss_id, dest, [dest])
				if not mb.is_empty():
					for c in range(changes.size() - 1, -1, -1):
						if changes[c].idx == mb.idx:
							changes.remove_at(c)
					changes.append(mb)
			ev.append({"type": "board_mutated", "changes": changes})
		if run.has_passive("piggy_bank"):
			var interest := mini(Balance.PASSIVE_PIGGY_MAX, int(run.gold * Balance.PASSIVE_PIGGY_PCT))
			if interest > 0:
				ev.append(_passive_ev("piggy_bank", interest))
				_gold(ev, interest, "piggy_bank")
		if Balance.is_shop_lap(completed):
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
				var gone := run.board.remove_minibosses()
				if not gone.is_empty():
					ev.append({"type": "board_mutated", "changes": gone})
				_start_combat([run.boss_id], false, true, 0, ev)
			"passive_choice":
				_open_passive_choice(String(step.get("source", "elite")), ev, String(step.get("tier", "")))
			"bonus_move":
				ev.append(_passive_ev("fast_feet", int(step.steps)))
				ev.append_array(_move(int(step.steps), false))
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
		"miniboss":
			if not tile.enemies.is_empty():
				_start_combat(tile.enemies, false, false, idx, ev, true)
		"chest":
			_consume(idx, ev)
			if run.rng.chance(Balance.CHEST_RUNE_CHANCE):
				_open_rune_choice("chest", ev)
			else:
				var g := int(round(run.rng.randi_range(Balance.CHEST_GOLD_MIN, Balance.CHEST_GOLD_MAX) * Balance.gold_scale(run.lap)))
				if run.has_passive("treasure_sense"):
					g = int(round(g * Balance.PASSIVE_TREASURE_MULT))
					ev.append(_passive_ev("treasure_sense", g))
				_gold(ev, g, "chest")
		"event":
			_consume(idx, ev)
			_open_event(ev)
		"campfire":
			_consume(idx, ev)
			var pct := Balance.GLADE_CAMPFIRE_HEAL_PCT if run.board.biome == "glade" else Balance.CAMPFIRE_HEAL_PCT
			var h := run.heal(run.pct_of_max(pct))
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "campfire", "max_hp": run.max_hp})
		"trap":
			var roll := run.rng.randi_range(1, 6)
			var dodged := roll >= Balance.TRAP_DODGE_MIN
			var dmg := 0 if dodged else mini(run.hp, run.pct_of_max(Balance.TRAP_DAMAGE_PCT))
			run.hp -= dmg
			var saved := run.survive_lethal() if run.hp <= 0 else ""
			if saved != "":
				dmg -= 1
			run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + dmg
			ev.append({"type": "trap", "roll": roll, "dodged": dodged, "damage": dmg})
			if dmg > 0:
				ev.append({"type": "hp_changed", "amount": -dmg, "total": run.hp, "source": "trap", "max_hp": run.max_hp})
			if saved != "":
				ev.append(_passive_ev(saved, 1))
			if run.hp <= 0:
				_finish(false, ev)
			elif dodged and run.board.biome == "crypt":
				# Crypt twist: a dodged trap drops coins.
				_gold(ev, int(round(Balance.CRYPT_DODGE_GOLD * Balance.gold_scale(run.lap))), "crypt")
		"ice":
			# Frostpeak: slip (fail the dodge roll) and a die freezes for your next fight.
			var roll := run.rng.randi_range(1, 6)
			var dodged := roll >= Balance.TRAP_DODGE_MIN
			if not dodged:
				run.chill = mini(Balance.ICE_CHILL_MAX, run.chill + Balance.ICE_CHILL)
			ev.append({"type": "trap", "roll": roll, "dodged": dodged, "damage": 0, "ice": true, "chill": run.chill})
			if not dodged:
				ev.append({"type": "status", "target": "hero", "status": "chill", "value": run.chill, "pending": true})
		"lava":
			_lava(idx, true, ev)
		"forge":
			var uses := 2 if run.has_passive("blacksmith") else 1
			_set_offer({"kind": "forge", "ops": ["raise", "mirror"], "source": "tile", "uses": uses}, Phase.FORGE, ev)
		"treasury":
			var amount := run.treasury
			run.treasury = Balance.TREASURY_START
			_gold(ev, amount, "treasury")
			ev.back()["treasury"] = run.treasury
		"portal":
			_set_offer({"kind": "portal", "tiles": _portal_tiles(idx)}, Phase.PORTAL, ev)
		_:
			pass

## Portal destinations from the hero's tile. On the last lap they stop at Start (the boss).
func _portal_tiles(from: int) -> Array:
	var out: Array = []
	for t in run.board.portal_targets(from):
		out.append(t)
		if t == 0 and run.lap >= Balance.TOTAL_LAPS:
			break
	return out

## Magma lava: LAVA_PASS_PCT of max HP when passed over, LAVA_LAND_PCT when landed on. It
## never kills (leaves at least 1 HP). Emits lava {idx, damage, landed} + hp_changed.
func _lava(idx: int, landed: bool, ev: Array[Dictionary]) -> void:
	var dmg := mini(run.pct_of_max(Balance.LAVA_LAND_PCT if landed else Balance.LAVA_PASS_PCT), run.hp - 1)
	dmg = maxi(0, dmg)
	run.hp -= dmg
	run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + dmg
	ev.append({"type": "lava", "idx": idx, "damage": dmg, "landed": landed})
	if dmg > 0:
		ev.append({"type": "hp_changed", "amount": -dmg, "total": run.hp, "source": "lava", "max_hp": run.max_hp})

func _consume(idx: int, ev: Array[Dictionary]) -> void:
	run.board.tiles[idx] = Board.make_tile("empty")
	ev.append({"type": "board_mutated", "changes": [run.board.change(idx)]})

func _gold(ev: Array[Dictionary], amount: int, source: String) -> void:
	run.gold += amount
	if amount > 0:
		run.stats.gold_earned = int(run.stats.get("gold_earned", 0)) + amount
	ev.append({"type": "gold_changed", "amount": amount, "total": run.gold, "source": source})

# ================================================================ combat

func _start_combat(ids: Array, elite: bool, boss: bool, tile: int, ev: Array[Dictionary], miniboss := false) -> void:
	combat = CombatState.new()
	phase = Phase.COMBAT
	ev.append_array(combat.begin(run, ids, elite, boss, tile, miniboss))

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
	if run.block > 0:
		var old_block := run.block
		run.block = 0
		ev.append({"type": "block_gained", "target": "hero", "amount": -old_block, "total": 0})
	run.stats.fights_won = int(run.stats.get("fights_won", 0)) + 1
	if c.gold_reward > 0:
		_gold(ev, c.gold_reward, "combat")
	if c.tile >= 0 and not c.boss:
		run.board.clear_enemies(c.tile)
		ev.append({"type": "board_mutated", "changes": [run.board.change(c.tile)]})
	if c.boss:
		_finish(true, ev)
		return
	var front: Array[Dictionary] = []
	run.xp += c.xp_reward
	while run.xp >= Balance.xp_for_level(run.level):
		run.level += 1
		ev.append({"type": "level_up", "level": run.level, "xp": run.xp, "next": Balance.xp_for_level(run.level)})
		front.append({"kind": "draft"})
	# After the level-up drafts: the mini-boss gives 1 of 3 boss passives; elites give 1 of 3
	# regular passives, or (ELITE_BOSS_PASSIVE_CHANCE) 1 of 3 boss passives.
	if c.miniboss:
		front.append({"kind": "passive_choice", "source": "miniboss"})
	elif c.elite:
		var chance := Balance.THRONE_ELITE_BOSS_PASSIVE_CHANCE if run.board.biome == "throne" else Balance.ELITE_BOSS_PASSIVE_CHANCE
		var tier := "boss" if run.rng.chance(chance) else "regular"
		front.append({"kind": "passive_choice", "source": "elite", "tier": tier})
	front.append_array(pending)
	pending = front

func _finish(victory: bool, ev: Array[Dictionary]) -> void:
	combat = null
	offer = {}
	pending.clear()
	board_roll.clear()
	board_choice.clear()
	board_move = 0
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
	s["route"] = Array(run.route)
	s["miniboss_id"] = run.miniboss_id
	s["boss_id"] = run.boss_id
	return s

## Biome change (laps 6 and 11): act += 1, the board is regenerated around the hero (who keeps
## their position; their landing tile is never a fight), 30% heal, Rune Bloom, reroll item
## available again. Emits act_started {act, biome, biome_name, biome_desc, lap, board, treasury,
## pos}; biome is the route's id for the new tier. Any mini-boss is gone.
func _new_biome(dest: int, ev: Array[Dictionary]) -> void:
	run.act = Balance.act_for_lap(run.lap)
	run.shop_reroll_bought = false
	run.board = Board.generate(run.rng, run.act, run.board_size, run.lap, run.biome())
	if not run.board.is_corner(dest) and Board._is_fight(String(run.board.tiles[dest].type)):
		run.board.tiles[dest] = Board.make_tile("empty")
	run.stats.max_act = maxi(int(run.stats.get("max_act", 1)), run.act)
	ev.append({"type": "act_started", "act": run.act, "biome": run.biome(), "biome_name": BiomeDefs.name_of(run.biome()),
		"biome_desc": BiomeDefs.desc_of(run.biome()), "lap": run.lap,
		"board": run.board.to_dict(), "treasury": run.treasury, "pos": run.pos})
	var h := run.heal(run.pct_of_max(Balance.BIOME_HEAL_PCT))
	ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "act_start", "max_hp": run.max_hp})
	if run.has_passive("rune_bloom"):
		_rune_bloom(ev)

# ================================================================ draft & runes

## Level-up draft: 3 options. While the pool is below MAX_DICE a New Die (random kind) is
## always one of them, so growing the pool is the early priority.
func _open_draft(ev: Array[Dictionary]) -> void:
	var ids: Array = ["rune", "max_hp", "face_raise"]
	if run.combat_rerolls < Balance.MAX_COMBAT_REROLLS:
		ids.append("combat_reroll")
	run.rng.shuffle(ids)
	if run.dice.size() < run.max_dice():
		ids.insert(run.rng.randi_range(0, 2), "new_die")
	var options: Array = []
	for k in 3:
		options.append(_draft_option(String(ids[k])))
	_set_offer({"kind": "draft", "options": options, "source": "level"}, Phase.DRAFT, ev)

func _draft_option(id: String) -> Dictionary:
	match id:
		"new_die":
			var kind := DiceKinds.random_kind(run.rng)
			return {"id": id, "label": DiceKinds.label(kind), "desc": String(DiceKinds.DEFS[kind].desc), "kind": kind}
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

# ================================================================ passives

## Offer {kind:"passive", options:[{id,label,desc,rarity,icon}], source} in phase DRAFT; the
## player picks with pick_draft(i). source "elite" rolls regular passives (tier "boss": boss
## passives); "miniboss" rolls boss passives (falling back to rares when fewer than 3 remain).
## Nothing left: no offer.
func _open_passive_choice(source: String, ev: Array[Dictionary], tier := "") -> void:
	var owned: Array = Array(run.passives)
	var ids: Array[String]
	if tier == "boss" or source == "boss" or source == "miniboss":
		ids = Passives.roll_boss(run.rng, 3, owned)
	else:
		ids = Passives.roll_regular(run.rng, 3, owned)
	if ids.is_empty():
		return
	var options: Array = []
	for id in ids:
		options.append(Passives.option(id))
	_set_offer({"kind": "passive", "options": options, "source": source}, Phase.DRAFT, ev)

func _gain_passive(id: String, ev: Array[Dictionary]) -> void:
	if run.has_passive(id) or not Passives.DEFS.has(id):
		return
	run.passives.append(id)
	var d: Dictionary = Passives.DEFS[id]
	ev.append({"type": "passive_gained", "id": id, "name": String(d.name), "rarity": String(d.rarity)})
	match id:
		"glass_cannon":
			var loss := int(round(run.max_hp * Balance.PASSIVE_GLASS_HP_PCT))
			run.max_hp -= loss
			var before := run.hp
			run.hp = mini(run.hp, run.max_hp)
			ev.append({"type": "hp_changed", "amount": run.hp - before, "total": run.hp, "source": "glass_cannon", "max_hp": run.max_hp})
		"collector":
			var n := 0
			for die in run.dice:
				if die.rune != "":
					n += 1
			_collector_hp(n, ev)
		"extra_hand":
			_add_die(ev, "standard")
		"rune_bloom":
			_rune_bloom(ev)

func _passive_ev(id: String, value: int) -> Dictionary:
	return {"type": "passive_triggered", "id": id, "value": value}

func _collector_hp(runes: int, ev: Array[Dictionary]) -> void:
	if runes <= 0:
		return
	var gain := runes * Balance.PASSIVE_COLLECTOR_HP
	run.max_hp += gain
	var h := run.heal(gain)
	ev.append(_passive_ev("collector", gain))
	ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "collector", "max_hp": run.max_hp})

## Puts `rune` on a die (replacing any rune). Collector adds max HP when a blank die gains one.
func _assign_rune(die_idx: int, rune: String, ev: Array[Dictionary]) -> void:
	var old := run.dice[die_idx].rune
	run.dice[die_idx].rune = rune
	ev.append({"type": "rune_assigned", "die_idx": die_idx, "rune": rune, "replaced": old})
	if old == "" and run.has_passive("collector"):
		_collector_hp(1, ev)

## Rune Bloom: every die without a rune gets a random rune.
func _rune_bloom(ev: Array[Dictionary]) -> void:
	for i in run.dice.size():
		if run.dice[i].rune == "":
			ev.append(_passive_ev("rune_bloom", i))
			_assign_rune(i, Runes.random_rune(run.rng), ev)

func pick_draft(i: int) -> Array[Dictionary]:
	if phase != Phase.DRAFT or not (offer.get("kind", "") in ["draft", "passive"]):
		return _err("pick_draft")
	if i < 0 or i >= offer.options.size():
		return [_e("bad option")]
	_record(["pick_draft", i])
	var ev: Array[Dictionary] = []
	var opt: Dictionary = offer.options[i]
	var is_passive := String(offer.kind) == "passive"
	_close_offer(ev)
	if is_passive:
		_gain_passive(String(opt.id), ev)
		_advance(ev)
		return ev
	match String(opt.id):
		"new_die":
			_add_die(ev, String(opt.get("kind", "standard")))
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

func _add_die(ev: Array[Dictionary], kind := "standard") -> void:
	if run.dice.size() >= run.max_dice():
		return
	run.dice.append(Die.make("", kind))
	ev.append({"type": "die_added", "die_idx": run.dice.size() - 1, "kind": kind, "die": run.dice.back().to_dict()})

## Replaces die `idx` with a fresh die of `kind`, keeping its rune (Dicesmith on a full pool).
func _reforge_die(ev: Array[Dictionary], idx: int, kind: String) -> void:
	run.dice[idx] = Die.make(run.dice[idx].rune, kind)
	ev.append({"type": "die_changed", "die_idx": idx, "kind": kind, "die": run.dice[idx].to_dict()})

## Index of the die with the lowest face sum (first on ties).
func _weakest_die() -> int:
	var best := 0
	for i in run.dice.size():
		if run.dice[i].face_sum() < run.dice[best].face_sum():
			best = i
	return best

func rune_assign(die_idx: int) -> Array[Dictionary]:
	if phase != Phase.DRAFT or offer.get("kind", "") != "rune_assign":
		return _err("rune_assign")
	if die_idx < 0 or die_idx >= run.dice.size():
		return [_e("bad die index")]
	_record(["rune_assign", die_idx])
	var ev: Array[Dictionary] = []
	var rune := String(offer.rune)
	_close_offer(ev)
	_assign_rune(die_idx, rune, ev)
	_advance(ev)
	return ev

# ================================================================ shop

func _open_shop(ev: Array[Dictionary]) -> void:
	_set_offer({"kind": "shop", "items": _shop_stock()}, Phase.SHOP, ev)

## 3-4 items. While the pool is below MAX_DICE the first item is always a die (random kind);
## at most 2 dice per stock (distinct kinds), runes repeat (distinct), anything else once.
func _shop_stock() -> Array:
	var weights := {}
	var pool_open := run.dice.size() < run.max_dice()
	for id in ShopDefs.ITEMS:
		if id == "die" and not pool_open:
			continue
		if id == "combat_reroll" and (run.shop_reroll_bought or run.combat_rerolls >= Balance.MAX_COMBAT_REROLLS):
			continue
		if id == "passive" and Passives.roll_regular(Rng.new(1), 1, Array(run.passives)).is_empty():
			continue
		weights[id] = ShopDefs.ITEMS[id].weight
	var n := run.rng.randi_range(Balance.SHOP_MIN_ITEMS, Balance.SHOP_MAX_ITEMS)
	var items: Array = []
	var used := {}
	var dice := 0
	if pool_open:
		items.append(_shop_item("die", used))
		dice = 1
	while items.size() < n and not weights.is_empty():
		var id := String(run.rng.weighted(weights))
		if id == "die":
			dice += 1
			if dice >= Balance.SHOP_MAX_DICE_ITEMS:
				weights.erase(id)
		elif id != "rune":
			weights.erase(id) # at most one of each other non-rune item
		items.append(_shop_item(id, used))
	return items

func _shop_item(id: String, used: Dictionary) -> Dictionary:
	var def: Dictionary = ShopDefs.ITEMS[id]
	var item := {"id": id, "label": String(def.label), "desc": String(def.desc), "price": 0, "needs_die": bool(def.needs_die), "sold": false}
	match id:
		"die":
			var kind := DiceKinds.random_kind(run.rng)
			for attempt in 5:
				if not used.has("die:" + kind):
					break
				kind = DiceKinds.random_kind(run.rng)
			used["die:" + kind] = true
			item.kind = kind
			item.label = DiceKinds.label(kind)
			item.desc = String(DiceKinds.DEFS[kind].desc)
			item.price = int(DiceKinds.DEFS[kind].price)
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
		"passive":
			var pid: String = Passives.roll_regular(run.rng, 1, Array(run.passives))[0]
			var pd: Dictionary = Passives.DEFS[pid]
			item.passive = pid
			item.rarity = String(pd.rarity)
			item.label = String(pd.name)
			item.desc = String(pd.desc)
			item.price = int(Balance.PASSIVE_PRICE[pd.rarity])
	if run.has_passive("haggler"):
		item.price = int(round(item.price * Balance.PASSIVE_HAGGLE))
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
			if run.dice.size() >= run.max_dice():
				return [_e("dice pool is full")]
		"face_raise":
			if not run.dice[die_idx].can_raise(run.dice[die_idx].lowest_face()):
				return [_e("die is maxed")]
		"combat_reroll":
			if run.combat_rerolls >= Balance.MAX_COMBAT_REROLLS or run.shop_reroll_bought:
				return [_e("unavailable")]
		"passive":
			if run.has_passive(String(item.passive)):
				return [_e("already owned")]
	_record(["shop_buy", i, die_idx])
	var ev: Array[Dictionary] = []
	run.gold -= int(item.price)
	ev.append({"type": "gold_changed", "amount": -int(item.price), "total": run.gold, "source": "shop"})
	item.sold = true
	match String(item.id):
		"die":
			_add_die(ev, String(item.get("kind", "standard")))
		"rune":
			_assign_rune(die_idx, String(item.rune), ev)
		"passive":
			_gain_passive(String(item.passive), ev)
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
		if op == "raise" and not d.can_raise(face_idx):
			return [_e("face is already at its cap (%d)" % d.raise_cap())]
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
	var uses := int(offer.get("uses", 1))
	if op != "skip" and uses > 1:
		# Blacksmith: the Forge stays open for another edit
		var again := offer.duplicate(true)
		again["uses"] = uses - 1
		_close_offer(ev)
		ev.append(_passive_ev("blacksmith", uses - 1))
		_set_offer(again, Phase.FORGE, ev)
		return ev
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
			# Two regular passives; flat blessings only fill in when passives run out.
			for pid in Passives.roll_regular(run.rng, 2, Array(run.passives)):
				var pd: Dictionary = Passives.DEFS[pid]
				choices.append({"label": String(pd.name), "desc": String(pd.desc), "enabled": true, "passive": pid, "rarity": String(pd.rarity)})
			var keys: Array = EventDefs.BLESSINGS.keys()
			run.rng.shuffle(keys)
			var k := 0
			while choices.size() < 2:
				var b: Dictionary = EventDefs.BLESSINGS[keys[k]]
				choices.append({"label": b.label, "desc": b.desc, "enabled": true, "blessing": keys[k]})
				k += 1
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
		"dicesmith":
			# Two different kinds. With room the die is added; on a full pool it reforges the
			# weakest die (lowest face sum) into that kind, keeping its rune.
			var full := run.dice.size() >= run.max_dice()
			var kinds: Array[String] = []
			while kinds.size() < 2:
				var k := DiceKinds.random_kind(run.rng)
				if k != "standard" and not kinds.has(k):
					kinds.append(k)
			for k in kinds:
				var dk: Dictionary = DiceKinds.DEFS[k]
				var lbl := ("Reforge into %s" if full else "Take the %s") % DiceKinds.label(k)
				choices.append({"label": lbl, "desc": String(dk.desc), "enabled": true, "kind": k})
			choices.append({"label": "Walk away", "desc": "Keep your dice as they are.", "enabled": true})
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
			if choice.has("passive"):
				_gain_passive(String(choice.passive), ev)
			match String(choice.get("blessing", "")):
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
							if run.dice[d].can_raise(f):
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
		"dicesmith":
			if choice.has("kind"):
				if run.dice.size() < run.max_dice():
					_add_die(ev, String(choice.kind))
				else:
					_reforge_die(ev, _weakest_die(), String(choice.kind))
		"idol":
			if i == 0:
				run.hp -= Balance.IDOL_DAMAGE
				run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + Balance.IDOL_DAMAGE
				ev.append({"type": "hp_changed", "amount": -Balance.IDOL_DAMAGE, "total": run.hp, "source": "idol", "max_hp": run.max_hp})
				for d in run.dice.size():
					var f := run.dice[d].lowest_face()
					if run.dice[d].raise_face(f):
						ev.append(_face_ev(d, f))
	if run.board.biome == "hollow" and run.hp > 0:
		# Hollow twist: restless spirits mend you after every event.
		var hh := run.heal(run.pct_of_max(Balance.HOLLOW_EVENT_HEAL_PCT))
		ev.append({"type": "hp_changed", "amount": hh, "total": run.hp, "source": "hollow", "max_hp": run.max_hp})
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
	var n := run.board.size()
	var steps := (tile_idx - run.pos + n) % n
	ev.append_array(_move(steps, true))
	_advance(ev)
	return ev

# ================================================================ scenarios (presentation/testing aid)

## Jumps straight into a modal or fight for screenshot scenarios. Not recorded in `commands`,
## so a flow touched by this cannot be replayed from its log. kind: shop | draft | rune_choice |
## rune_assign | passive | forge | event | portal | combat | boss | miniboss. arg: event id, rune
## id, or comma separated enemy ids for combat, or the passive source ("elite" | "miniboss" |
## "boss" = an elite's boss-tier roll), or a boss / mini-boss id (default: the run's).
func debug_open(kind: String, arg := "") -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	combat = null
	offer = {}
	board_roll.clear()
	board_choice.clear()
	board_move = 0
	phase = Phase.BOARD_READY
	match kind:
		"shop": _open_shop(ev)
		"draft": _open_draft(ev)
		"rune_choice": _open_rune_choice("chest", ev)
		"passive": _open_passive_choice(arg if arg != "" else "elite", ev, "boss" if arg == "boss" else "")
		"rune_assign": _set_offer({"kind": "rune_assign", "rune": arg if arg != "" else "blade"}, Phase.DRAFT, ev)
		"forge": _set_offer({"kind": "forge", "ops": ["raise", "mirror"], "source": "tile"}, Phase.FORGE, ev)
		"event": _open_event(ev, arg if EventDefs.DATA.has(arg) else "")
		"portal": _set_offer({"kind": "portal", "tiles": _portal_tiles(run.pos)}, Phase.PORTAL, ev)
		"combat":
			var ids: Array = Array(arg.split(",", false)) if arg != "" else ["skeleton_minion", "skeleton_archer"]
			_start_combat(ids, false, false, run.pos, ev)
		"boss": _start_combat([arg if EnemyDefs.BOSSES.has(arg) else run.boss_id], false, true, 0, ev)
		"miniboss": _start_combat([arg if EnemyDefs.MINIBOSSES.has(arg) else run.miniboss_id], false, false, run.pos, ev, true)
		_: return [_e("unknown debug kind " + kind)]
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
		"confirm_move", "choose_move": return confirm_move()
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
static func replay(class_id: String, seed: int, log_: Array, board_size: int = Balance.BOARD_SIZE, opts: Dictionary = {}) -> GameFlow:
	var f := GameFlow.new_run(class_id, seed, board_size, opts)
	for cmd in log_:
		f.apply(cmd)
	return f

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "run": run.to_dict(), "phase": int(phase),
		"combat": combat.to_dict() if combat != null else null,
		"board_roll": Array(board_roll), "board_choice": Array(board_choice), "board_move": board_move,
		"offer": offer.duplicate(true),
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
	for v in d.get("board_choice", []):
		f.board_choice.append(int(v))
	f.board_move = int(d.get("board_move", 0))
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
