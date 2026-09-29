class_name GameFlow
extends RefCounted
## Top-level run state machine. Every command validates the phase; illegal calls return
## [{type:"error", msg}] and change nothing. Successful commands are appended to `commands`
## so a seed plus the log replays exactly (see apply()).

## MINIGAME (meta layer) is appended last so saved phase ints stay valid.
enum Phase { BOARD_READY, BOARD_ROLLED, COMBAT, DRAFT, SHOP, FORGE, EVENT, PORTAL, GAME_OVER, VICTORY, MINIGAME }

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
## Board rerolls refunded this board turn (Ninja Shadow Step; reset by roll_board).
var board_refunds: int = 0
## Queue of steps still to resolve after the current modal/combat closes.
## Step kinds: tile{idx}, shop, draft, rune_choice{source}, passive_choice{source, tier}, boss,
## bonus_move{steps}, victory.
var pending: Array[Dictionary] = []
## Successful commands in order: [name, args...].
var commands: Array = []
## The minigame being played (phase MINIGAME), else null. Holds hidden state: never show it;
## the presentation reads offer.state (public view) instead.
var minigame: Minigame = null

# ================================================================ construction

## board_size: ring size, 24, 28 (default) or 32.
## opts (optional, scenarios/tests): {route:[tier1, tier2, tier3], miniboss:id, boss:id}.
## Without them the route (one biome per tier) and bosses are drawn from the seed.
## opts.mode: "standard" (15 laps, 3 biomes) | "short" (Short Road: 10 laps, 2 biomes).
## opts.ascension: int 0..10, overrides the profile's selected ascension (meta runs only).
## opts.profile: a Profile.to_dict() snapshot (or opts.meta: a MetaRun.build() config) enables the
## meta layer (gear, traits, workshop, pet, potion belt, minigame loadout, unlocked pools, biomes
## and bosses, ascension). The run stores the derived config in run.meta, so saves and replays
## do not need the profile again. With a profile, a locked class falls back to the first owned
## class, and the mode defaults to the profile loadout's. With the Whetstone the run opens on a
## Forge "raise" offer (source "whetstone").
static func new_run(class_id: String, seed: int, board_size: int = Balance.BOARD_SIZE, opts: Dictionary = {}) -> GameFlow:
	var f := GameFlow.new()
	if not HeroDefs.DATA.has(class_id):
		class_id = "knight"
	if opts.has("profile"):
		var p := Profile.from_dict(opts.profile)
		if not p.class_allowed(class_id):
			class_id = String(p.unlocks.classes[0]) if not (p.unlocks.classes as Array).is_empty() else "knight"
		if not opts.has("mode"):
			opts = opts.duplicate()
			opts["mode"] = String(p.loadout.get("mode", "standard"))
	f.run = RunState.create(class_id, seed, board_size, opts)
	f.phase = Phase.BOARD_READY
	if int(f.run.meta.get("whetstone", 0)) > 0:
		f.offer = {"kind": "forge", "ops": ["raise"], "source": "whetstone"}
		f.phase = Phase.FORGE
	return f

## The run's route for presentation: {route:[{id, name, desc}], miniboss:{id, name},
## boss:{id, name}, mode, laps}. A Short Road route has 2 biomes.
func route_info() -> Dictionary:
	var r: Array = []
	for b in run.route:
		r.append({"id": b, "name": BiomeDefs.name_of(b), "desc": BiomeDefs.desc_of(b), "twist": BiomeDefs.twist_of(b), "look": BiomeDefs.look_of(b)})
	return {
		"route": r,
		"miniboss": {"id": run.miniboss_id, "name": String(EnemyDefs.def(run.miniboss_id).name)},
		"boss": {"id": run.boss_id, "name": String(EnemyDefs.def(run.boss_id).name)},
		"mode": run.mode, "laps": run.total_laps(),
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
	board_rerolls_left = run.board_rerolls + (1 if run.has_passive("pathfinder") else 0) + run.lap_rerolls
	board_refunds = 0
	phase = Phase.BOARD_ROLLED
	return _do_board_roll()

func board_reroll() -> Array[Dictionary]:
	if phase != Phase.BOARD_ROLLED:
		return _err("board_reroll")
	if board_rerolls_left <= 0:
		return [_e("no board rerolls left")]
	_record(["board_reroll"])
	board_rerolls_left -= 1
	# the lap pool (Boots, Crystal Wisp) is spent after the per-turn rerolls
	run.lap_rerolls = mini(run.lap_rerolls, board_rerolls_left)
	var ev := _do_board_roll()
	var refund := ClassLogic.on_board_reroll(run, self)
	if not refund.is_empty():
		ev.back()["rerolls_left"] = board_rerolls_left
		ev.append_array(refund)
	return ev

func _do_board_roll() -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var values: Array[int] = []
	var idx: Array[int] = []
	for i in run.dice.size():
		values.append(run.dice[i].value(run.dice[i].roll(run.rng)))
		idx.append(i)
	ev.append({"type": "dice_rolled", "values": values.duplicate(), "indices": idx, "context": "board"})
	_select_move(values)
	# Doubles feed the Treasury bank: +pair value * TREASURY_PAIR_MULT.
	var added := 0
	var pv := board_pair_value()
	if pv > 0:
		added = pv * Balance.TREASURY_PAIR_MULT
		if run.has_pet("coin_mimic"):
			added += 2
	run.treasury += added
	ev.append({"type": "board_rolled", "values": board_roll.duplicate(), "chosen": board_choice.duplicate(),
		"move": board_move, "target": board_target(), "targets": landing_preview(), "double": pv > 0, "pair_value": pv,
		"treasury_added": added, "treasury": run.treasury, "rerolls_left": board_rerolls_left})
	return ev

## Sets the current board roll and auto-selects the two moving dice (see pick_move_dice).
func _select_move(values: Array[int]) -> void:
	board_roll = values.duplicate()
	board_choice = pick_move_dice(values, run.rng, run.has_trait("boots_pair_pick"))
	board_move = 0
	for i in board_choice:
		board_move += board_roll[i]

## Movement rule (Vlad, 2026-09-28): the pool rolls, then two dice are picked automatically:
## ONE die of each of the two pip values shown by the most dice. Ties at any rank are broken at
## random with the run Rng (Boots L8 "Pathfinder's Eye": ties go to the higher value). Blank
## faces (0) are ignored unless fewer than two dice show a value. If only one value shows, two
## dice of it move. The move is the sum of the two picked dice.
## Examples: [2,2,2,5,6,6] -> 2 + 6 = 8 · [2,2,5,6] -> 2 + (5 or 6) · [1,3,4,5,6] -> two random
## values · [4,4,4] -> 4 + 4 · [0,0,3] -> 3 + 0. Returns the two dice indices, ascending (the
## first die showing each picked value). The Rng is only used when a tie decides the pick.
static func pick_move_dice(values: Array[int], rng: Rng, prefer_high := false) -> Array[int]:
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
			var b: int = blanks[0] if blanks.size() == 1 else int(rng.pick(blanks))
			blanks.erase(b)
			out.append(b)
		out.sort()
		return out
	var by_val := {}
	var order: Array = []   # distinct values, first-seen order
	for i in live:
		if not by_val.has(values[i]):
			by_val[values[i]] = [] as Array[int]
			order.append(values[i])
		(by_val[values[i]] as Array[int]).append(i)
	if order.size() == 1:
		var only: Array[int] = by_val[order[0]]
		out.append(only[0])
		out.append(only[1])
		return out
	var picked: Array = []
	while picked.size() < 2:
		var best := 0
		for v in order:
			if not picked.has(v):
				best = maxi(best, (by_val[v] as Array[int]).size())
		var tied: Array = []
		for v in order:
			if not picked.has(v) and (by_val[v] as Array[int]).size() == best:
				tied.append(v)
		tied.sort()
		var need := 2 - picked.size()
		if tied.size() <= need:
			picked.append_array(tied)
		elif prefer_high:
			picked.append_array(tied.slice(tied.size() - need))
		elif need == 1:
			picked.append(rng.pick(tied))
		else:
			rng.shuffle(tied)
			picked.append_array(tied.slice(0, need))
	for v in picked:
		out.append((by_val[v] as Array[int])[0])
	out.sort()
	return out

## The roll's pair value: when the most common non-blank value shows on 2+ dice (the roll holds
## a pair), the higher such value among the two moving dice; else 0. Feeds the Treasury
## (pair value x TREASURY_PAIR_MULT), Fast Feet's hop and every "doubles" effect.
static func pair_value_of(values: Array[int], choice: Array[int]) -> int:
	var counts := {}
	var top := 0
	for v in values:
		if v > 0:
			counts[v] = int(counts.get(v, 0)) + 1
			top = maxi(top, int(counts[v]))
	if top < 2:
		return 0
	var pv := 0
	for i in choice:
		if i >= 0 and i < values.size() and values[i] > 0 and int(counts.get(values[i], 0)) == top:
			pv = maxi(pv, values[i])
	return pv

## The current board roll's pair value (0 = no doubles).
func board_pair_value() -> int:
	return pair_value_of(board_roll, board_choice)

## Doubles: the board roll contains a pair (its most common value shows on 2+ dice).
func is_board_double() -> bool:
	return board_pair_value() > 0

## Landing tile of the current move (Start on the final lap if the move crosses it).
func board_target() -> int:
	if run.lap >= run.total_laps() and run.board.crosses_start(run.pos, board_move):
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
	var hop := board_pair_value()
	var doubles := hop > 0
	if doubles:
		ev.append_array(PetLogic.on_board_double(run))
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
	var final_lap := run.lap >= run.total_laps()
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
	if not teleport and run.has_trait("boots_treasury_step"):
		for k in range(0, p.size() - 1):
			if String(run.board.tiles[p[k]].type) == "treasury":
				run.treasury += int(GearDefs.TRAIT_BONUS.boots_treasury_step)
				ev.append({"type": "trait_triggered", "id": "boots_treasury_step", "value": int(GearDefs.TRAIT_BONUS.boots_treasury_step), "treasury": run.treasury})
	ev.append({"type": "hero_moved", "path": ([dest] as Array[int]) if teleport else p, "teleport": teleport})
	if not teleport:
		# Magma lava scorches every lava tile passed over (landing is handled by the tile).
		for k in range(0, p.size() - 1):
			if String(run.board.tiles[p[k]].type) == "lava":
				_lava(p[k], false, ev)
	if crossing:
		# Sunscorched Ruins: heat at the lap's end, before the lap heal (never lethal)
		_heat(run.lap, ev)
		var healed := run.heal(run.pct_of_max(run.lap_heal_pct()))
		var completed := run.lap
		if final_lap:
			run.stats.laps_completed = int(run.stats.get("laps_completed", 0)) + 1
			ev.append({"type": "lap_completed", "lap": completed, "healed": healed, "hp": run.hp, "boss": true})
			ev.append({"type": "hp_changed", "amount": healed, "total": run.hp, "source": "lap", "max_hp": run.max_hp})
			ev.append_array(ClassLogic.on_lap(run))
			pending.push_front({"kind": "boss"})
			return ev
		run.lap += 1
		run.lap_rerolls = run.lap_reroll_refill(run.act_for_lap(run.lap) != run.act)
		run.stats.laps_completed = int(run.stats.get("laps_completed", 0)) + 1
		ev.append({"type": "lap_completed", "lap": completed, "healed": healed, "hp": run.hp, "boss": false})
		ev.append({"type": "hp_changed", "amount": healed, "total": run.hp, "source": "lap", "max_hp": run.max_hp})
		ev.append_array(ClassLogic.on_lap(run))
		if run.act_for_lap(run.lap) != run.act:
			_new_biome(dest, ev)
		else:
			var extra: Array = ["elite"] if run.has_asc("extra_elite") else []
			if run.moon_phase() == "full":
				# Moonlit Woods: the mutation into the Full lap spawns +1 Elite
				extra.append("elite")
			var changes := run.board.mutate(run.rng, run.act, run.eff_lap(), [dest], extra)
			if run.lap == run.miniboss_lap():
				_add_change(changes, run.board.spawn_miniboss(run.rng, run.miniboss_id, dest, [dest]))
			run.roll_change_affixes(changes)
			_twist_mutation(dest, changes, ev)
			changes.append_array(run.place_minigames([dest]))
			ev.append({"type": "board_mutated", "changes": changes})
		_moon_event(ev)
		if run.has_passive("piggy_bank"):
			var interest := mini(Balance.PASSIVE_PIGGY_MAX, int(run.gold * Balance.PASSIVE_PIGGY_PCT))
			if interest > 0:
				ev.append(_passive_ev("piggy_bank", interest))
				_gold(ev, interest, "piggy_bank")
		if run.is_shop_lap(completed):
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
		if phase in [Phase.COMBAT, Phase.DRAFT, Phase.SHOP, Phase.FORGE, Phase.EVENT, Phase.PORTAL, Phase.MINIGAME]:
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
			"forge":
				_set_offer({"kind": "forge", "ops": ["raise"], "source": String(step.get("source", "reward"))}, Phase.FORGE, ev)

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
				_start_combat(tile.enemies, bool(tile.elite), false, idx, ev, false, run.board.affixes_of(idx))
		"miniboss":
			if not tile.enemies.is_empty():
				_start_combat(tile.enemies, false, false, idx, ev, true, run.board.affixes_of(idx))
		"chest":
			if bool(tile.get("moon", false)):
				_consume(idx, ev)
				_moon_chest(ev)
				return
			_consume(idx, ev)
			if run.potion_cap > 0 and run.rng.chance(Balance.CHEST_POTION_CHANCE):
				_gain_potion(ev, "chest")
			if run.rng.chance(Balance.CHEST_RUNE_CHANCE):
				_open_rune_choice("chest", ev)
			else:
				var roll := run.rng.randi_range(Balance.CHEST_GOLD_MIN, Balance.CHEST_GOLD_MAX)
				if run.has_pet("coin_mimic") and run.pet_level() >= 10:
					roll = maxi(roll, run.rng.randi_range(Balance.CHEST_GOLD_MIN, Balance.CHEST_GOLD_MAX))
				var g := run.gold_bonus(int(round(roll * Balance.gold_scale(run.eff_lap()))))
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
			if run.has_trait("helm_campfire"):
				pct += float(GearDefs.TRAIT_BONUS.helm_campfire)
			if run.has_pet("pumpkin_sprite"):
				pct += 0.05
			var h := run.heal(run.pct_of_max(pct))
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "campfire", "max_hp": run.max_hp})
		"trap":
			var roll := run.rng.randi_range(1, 6)
			var dodged := roll + _dodge_bonus() >= _dodge_min()
			var dmg := 0 if dodged else mini(run.hp, maxi(1, int(round(run.pct_of_max(Balance.TRAP_DAMAGE_PCT) * run.hazard_mult()))))
			var hp_before := run.hp
			run.hp -= dmg
			var saved := run.survive_lethal(hp_before) if run.hp <= 0 else ""
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
				_gold(ev, int(round(Balance.CRYPT_DODGE_GOLD * Balance.gold_scale(run.eff_lap()))), "crypt")
		"ice":
			# Frostpeak: slip (fail the dodge roll) and a die freezes for your next fight.
			var roll := run.rng.randi_range(1, 6)
			var dodged := roll + _dodge_bonus() >= _dodge_min()
			if not dodged:
				run.chill = mini(Balance.ICE_CHILL_MAX, run.chill + Balance.ICE_CHILL)
			ev.append({"type": "trap", "roll": roll, "dodged": dodged, "damage": 0, "ice": true, "chill": run.chill})
			if not dodged:
				ev.append({"type": "status", "target": "hero", "status": "chill", "value": run.chill, "pending": true})
		"lava":
			_lava(idx, true, ev)
		"ore":
			_open_ore(idx, ev)
		"drum":
			_smash_drum(idx, ev)
		"oasis":
			_oasis(idx, ev)
		"forge":
			_lift_curse(ev)
			var uses := 2 if run.has_passive("blacksmith") else 1
			_set_offer({"kind": "forge", "ops": ["raise", "mirror"], "source": "tile", "uses": uses}, Phase.FORGE, ev)
		"treasury":
			var amount := run.treasury
			if run.has_trait("charm_treasury"):
				amount = int(round(amount * float(GearDefs.TRAIT_BONUS.charm_treasury)))
			if amount > 0:
				run.stats.cashouts = int(run.stats.get("cashouts", 0)) + 1
			run.treasury = Balance.TREASURY_START
			_gold(ev, amount, "treasury")
			ev.back()["treasury"] = run.treasury
		"portal":
			_set_offer({"kind": "portal", "tiles": _portal_tiles(idx)}, Phase.PORTAL, ev)
		"minigame":
			var game := String(tile.get("game", ""))
			_consume(idx, ev)
			if MinigameDefs.has(game):
				_start_minigame(game, ev)
		_:
			pass

## Portal destinations from the hero's tile. On the last lap they stop at Start (the boss).
func _portal_tiles(from: int) -> Array:
	var out: Array = []
	var reach := run.board.portal_range() + (int(GearDefs.TRAIT_BONUS.boots_portal) if run.has_trait("boots_portal") else 0)
	for t in run.board.path(from, reach):
		out.append(t)
		if t == 0 and run.lap >= run.total_laps():
			break
	return out

## Magma lava: LAVA_PASS_PCT of max HP when passed over, LAVA_LAND_PCT when landed on. It
## never kills (leaves at least 1 HP). Emits lava {idx, damage, landed} + hp_changed.
func _lava(idx: int, landed: bool, ev: Array[Dictionary]) -> void:
	var raw := run.pct_of_max(Balance.LAVA_LAND_PCT if landed else Balance.LAVA_PASS_PCT)
	if not run.meta.is_empty():
		raw = int(round(raw * run.hazard_mult() * (0.5 if run.has_pet("lantern_ghost") else 1.0)))
	var dmg := mini(raw, run.hp - 1)
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

func _start_combat(ids: Array, elite: bool, boss: bool, tile: int, ev: Array[Dictionary], miniboss := false, affixes: Array = []) -> void:
	combat = CombatState.new()
	phase = Phase.COMBAT
	if miniboss:
		run.stats.miniboss_reached = true
	if boss:
		run.stats.boss_reached = true
	ev.append_array(combat.begin(run, ids, elite, boss, tile, miniboss, affixes))
	if combat.result == "won":
		# the pet finished the fight before the first attack
		_on_combat_won(ev)

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
	if c.elite:
		run.stats.elites_won = int(run.stats.get("elites_won", 0)) + 1
	if c.miniboss:
		run.stats.minibosses_won = int(run.stats.get("minibosses_won", 0)) + 1
		_stat_add(run.miniboss_id if c.enemies.is_empty() else String(c.enemies[0].id), "minibosses_killed")
	if run.pet_id() != "":
		run.stats.pet_fights = int(run.stats.get("pet_fights", 0)) + 1
	if c.gold_reward > 0:
		_gold(ev, run.gold_bonus(c.gold_reward), "combat")
	if c.tile >= 0 and not c.boss:
		run.board.clear_enemies(c.tile)
		ev.append({"type": "board_mutated", "changes": [run.board.change(c.tile)]})
	if c.boss:
		_stat_add(String(c.enemies[0].id), "bosses_killed")
		var second := _second_boss()
		if second != "":
			# A10 double final: the route's other final boss, at 60% HP.
			run.stats.boss_stage = 1
			ev.append({"type": "second_boss", "id": second, "name": String(EnemyDefs.def(second).name)})
			_start_combat([second], false, true, 0, ev)
			return
		_finish(true, ev)
		return
	var front: Array[Dictionary] = []
	run.xp += c.xp_reward
	_level_ups(ev)
	# Fights pay gold, XP and pet charge only (Vlad, 2026-09-28: no upgrade drafts from kills).
	# The upgrade rewards: the mini-boss gives 1 of 3 boss passives; elites give 1 of 3 regular
	# passives, or (ELITE_BOSS_PASSIVE_CHANCE) 1 of 3 boss passives.
	if c.miniboss:
		front.append({"kind": "passive_choice", "source": "miniboss"})
	elif c.elite:
		var chance := Balance.THRONE_ELITE_BOSS_PASSIVE_CHANCE if run.board.biome == "throne" else Balance.ELITE_BOSS_PASSIVE_CHANCE
		var tier := "boss" if run.rng.chance(chance) else "regular"
		front.append({"kind": "passive_choice", "source": "elite", "tier": tier})
	front.append_array(pending)
	pending = front

## Automatic, slow levels (no choice): each level gives LEVEL_MAX_HP max HP and heals
## LEVEL_MAX_HP + LEVEL_HEAL_PCT of max HP. Emits level_up {level, xp, next, auto:true,
## max_hp_gained, healed} + hp_changed {source:"level"} per level.
func _level_ups(ev: Array[Dictionary]) -> void:
	while run.xp >= Balance.xp_for_level(run.level):
		run.level += 1
		run.max_hp += Balance.LEVEL_MAX_HP
		var h := run.heal(Balance.LEVEL_MAX_HP + run.pct_of_max(Balance.LEVEL_HEAL_PCT))
		ev.append({"type": "level_up", "level": run.level, "xp": run.xp, "next": Balance.xp_for_level(run.level),
			"auto": true, "max_hp_gained": Balance.LEVEL_MAX_HP, "healed": h})
		ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "level", "max_hp": run.max_hp})

## Counts one in-run upgrade (die, rune, face edit, passive, reroll, stat) by source for the
## balance report: run.stats.upgrades {source: n}. Sources: shop, event, chest, minigame,
## elite, miniboss, forge (the Forge tile), whetstone, boss.
func _upgrade(source: String) -> void:
	var u: Dictionary = run.stats.get("upgrades", {})
	u[source] = int(u.get(source, 0)) + 1
	run.stats["upgrades"] = u

func _finish(victory: bool, ev: Array[Dictionary]) -> void:
	combat = null
	minigame = null
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
	s["mode"] = run.mode
	s["asc"] = int(run.meta.get("asc", 0))
	s["potions"] = run.potions
	s["pet"] = run.pet_id()
	s["max_act"] = run.act
	var visited: Array = []
	for k in mini(run.act, run.route.size()):
		visited.append(run.route[k])
	s["biomes_visited"] = visited
	for k in ["minibosses_killed", "bosses_killed"]:
		s[k] = (run.stats.get(k, []) as Array).duplicate()
	s["rewards"] = MetaRun.rewards(run, bool(run.stats.get("victory", false)))
	return s

## Biome change (laps 6 and 11): act += 1, the board is regenerated around the hero (who keeps
## their position; their landing tile is never a fight), 30% heal, Rune Bloom, reroll item
## available again. Emits act_started {act, biome, biome_name, biome_desc, lap, board, treasury,
## pos}; biome is the route's id for the new tier. Any mini-boss is gone.
func _new_biome(dest: int, ev: Array[Dictionary]) -> void:
	run.act = run.act_for_lap(run.lap)
	run.shop_reroll_bought = false
	# The Short Road's second biome starts at eff lap 7 whatever its tier (pools switch after 3 laps).
	var first := run.eff_lap() if run.mode == "short" else -1
	run.board = Board.generate(run.rng, run.act, run.board_size, run.eff_lap(), run.biome(), first)
	if not run.board.is_corner(dest) and Board._is_fight(String(run.board.tiles[dest].type)):
		run.board.tiles[dest] = Board.make_tile("empty")
	run.after_board_generated([dest])
	if run.lap == run.miniboss_lap():
		# Short Road: the mini-boss arrives with the second biome (lap 6)
		run.board.spawn_miniboss(run.rng, run.miniboss_id, dest, [dest])
	run.roll_board_affixes()
	run.stats.max_act = maxi(int(run.stats.get("max_act", 1)), run.act)
	ev.append({"type": "act_started", "act": run.act, "biome": run.biome(), "biome_name": BiomeDefs.name_of(run.biome()),
		"biome_desc": BiomeDefs.desc_of(run.biome()), "lap": run.lap, "twist": run.twist(), "look": BiomeDefs.look_of(run.biome()),
		"board": run.board.to_dict(), "treasury": run.treasury, "pos": run.pos})
	var h := run.heal(run.pct_of_max(Balance.BIOME_HEAL_PCT))
	ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "act_start", "max_hp": run.max_hp})
	if run.has_pet("guard_die") and run.belt.is_empty():
		ev.append({"type": "pet_acted", "pet": "guard_die", "effect": "potion", "value": 1, "target": "hero"})
		_gain_potion(ev, "pet")
	if run.has_asc("biome_curse"):
		_biome_curse(ev)
	if run.has_passive("rune_bloom"):
		_rune_bloom(ev)
	ev.append_array(ClassLogic.on_biome(run))

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
			var kind := _rand_kind()
			return {"id": id, "label": DiceKinds.label(kind), "desc": String(DiceKinds.DEFS[kind].desc), "kind": kind}
		"rune":
			return Runes.option(_rand_rune())
		"max_hp":
			return {"id": id, "label": "+%d Max HP" % Balance.DRAFT_MAX_HP, "desc": "Gain %d max HP and heal %d." % [Balance.DRAFT_MAX_HP, Balance.DRAFT_MAX_HP]}
		"combat_reroll":
			return {"id": id, "label": "+1 Combat Reroll", "desc": "One more reroll every combat turn."}
		_:
			return {"id": "face_raise", "label": "Face Raise", "desc": "Raise one face of one die by 1."}

func _open_rune_choice(source: String, ev: Array[Dictionary], n := 3) -> void:
	var options: Array = []
	for id in Runes.random_runes_in(run.rng, n, _rune_pool()):
		options.append(Runes.option(id))
	_set_offer({"kind": "draft", "options": options, "source": source}, Phase.DRAFT, ev)

# ================================================================ passives

## Offer {kind:"passive", options:[{id,label,desc,rarity,icon}], source} in phase DRAFT; the
## player picks with pick_draft(i). source "elite" rolls regular passives (tier "boss": boss
## passives); "miniboss" rolls boss passives (falling back to rares when fewer than 3 remain).
## Nothing left: no offer.
func _open_passive_choice(source: String, ev: Array[Dictionary], tier := "") -> void:
	var owned: Array = _passive_excluded(source == "elite" or source == "miniboss")
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
			_assign_rune(i, _rand_rune(), ev)

func pick_draft(i: int) -> Array[Dictionary]:
	if phase != Phase.DRAFT or not (offer.get("kind", "") in ["draft", "passive", "reward"]):
		return _err("pick_draft")
	if i < 0 or i >= offer.options.size():
		return [_e("bad option")]
	_record(["pick_draft", i])
	var ev: Array[Dictionary] = []
	var opt: Dictionary = offer.options[i]
	var is_passive := String(offer.kind) == "passive"
	var is_reward := String(offer.kind) == "reward"
	var source := String(offer.get("source", ""))
	_close_offer(ev)
	if is_reward:
		_pick_reward(opt, ev)
		_advance(ev)
		return ev
	if is_passive:
		if not run.has_passive(String(opt.id)):
			_upgrade(source)
		_gain_passive(String(opt.id), ev)
		_advance(ev)
		return ev
	if not ["rune", "face_raise"].has(String(opt.id)):
		_upgrade(source)
	match String(opt.id):
		"new_die":
			_add_die(ev, String(opt.get("kind", "standard")))
		"rune":
			_set_offer({"kind": "rune_assign", "rune": String(opt.rune), "source": source}, Phase.DRAFT, ev)
		"max_hp":
			run.max_hp += Balance.DRAFT_MAX_HP
			var h := run.heal(Balance.DRAFT_MAX_HP)
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "draft", "max_hp": run.max_hp})
		"combat_reroll":
			run.combat_rerolls = mini(Balance.MAX_COMBAT_REROLLS, run.combat_rerolls + 1)
			ev.append({"type": "stat_changed", "stat": "combat_rerolls", "value": run.combat_rerolls})
		"face_raise":
			_set_offer({"kind": "forge", "ops": ["raise"], "source": source if source != "" else "draft"}, Phase.FORGE, ev)
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
	_upgrade(String(offer.get("source", "")))
	_close_offer(ev)
	_assign_rune(die_idx, rune, ev)
	_advance(ev)
	return ev

# ================================================================ shop

func _open_shop(ev: Array[Dictionary]) -> void:
	var o := {"kind": "shop", "items": _shop_stock(), "restock_price": _restock_price()}
	o["free_restocks"] = (1 if run.has_trait("charm_free_restock") else 0) + (1 if run.has_pet("coin_mimic") and run.pet_level() >= 5 else 0)
	_set_offer(o, Phase.SHOP, ev)

## Restock price: A3 raises it, the Charm's Haggle trait lowers it.
func _restock_price() -> int:
	if run.has_trait("charm_cheap_restock"):
		return int(GearDefs.TRAIT_BONUS.charm_cheap_restock)
	return UnlockDefs.ASC_RESTOCK if run.has_asc("shop_tax") else Balance.SHOP_RESTOCK_PRICE

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
		if id == "passive" and Passives.roll_regular(Rng.new(1), 1, _passive_excluded()).is_empty():
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
	if run.has_trait("charm_shop_potion"):
		var has_potion := false
		for it in items:
			if it.id == "potion":
				has_potion = true
		if not has_potion:
			items.append(_shop_item("potion", used))
	return items

func _shop_item(id: String, used: Dictionary) -> Dictionary:
	var def: Dictionary = ShopDefs.ITEMS[id]
	var item := {"id": id, "label": String(def.label), "desc": String(def.desc), "price": 0, "needs_die": bool(def.needs_die), "sold": false}
	match id:
		"die":
			var kind := _shop_kind()
			for attempt in 5:
				if not used.has("die:" + kind):
					break
				kind = _shop_kind()
			used["die:" + kind] = true
			item.kind = kind
			item.label = DiceKinds.label(kind)
			item.desc = String(DiceKinds.DEFS[kind].desc)
			item.price = int(DiceKinds.DEFS[kind].price)
		"potion":
			item.price = Balance.SHOP_POTION_PRICE
			if run.potion_cap > 0:
				var types: Array = run.meta.get("potion_types", ["healing"])
				var pt := String(types[0]) if types.size() <= 1 else String(run.rng.pick(types))
				item.potion = pt
				item.label = PotionDefs.name_of(pt)
				item.desc = "%s Goes on your belt; drunk at once if the belt is full." % String(PotionDefs.DEFS[pt].desc)
		"face_raise":
			item.price = Balance.SHOP_FACE_RAISE_PRICE
		"combat_reroll":
			item.price = Balance.SHOP_REROLL_ITEM_PRICE
		"rune":
			var r := _rand_rune()
			for attempt in 5:
				if not used.has(r):
					break
				r = _rand_rune()
			used[r] = true
			item.rune = r
			item.label = "%s Rune" % Runes.DEFS[r].name
			item.desc = String(Runes.DEFS[r].desc)
			item.price = int(Balance.RUNE_PRICE[Runes.rarity(r)])
		"passive":
			var pid: String = Passives.roll_regular(run.rng, 1, _passive_excluded())[0]
			var pd: Dictionary = Passives.DEFS[pid]
			item.passive = pid
			item.rarity = String(pd.rarity)
			item.label = String(pd.name)
			item.desc = String(pd.desc)
			item.price = int(Balance.PASSIVE_PRICE[pd.rarity])
	if run.has_passive("haggler"):
		item.price = int(round(item.price * Balance.PASSIVE_HAGGLE))
	if run.has_asc("shop_tax"):
		item.price = int(round(item.price * UnlockDefs.ASC_SHOP_TAX))
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
	if String(item.id) != "potion":
		_upgrade("shop")
	match String(item.id):
		"die":
			_add_die(ev, String(item.get("kind", "standard")))
		"rune":
			_assign_rune(die_idx, String(item.rune), ev)
		"passive":
			_gain_passive(String(item.passive), ev)
		"potion":
			if run.potion_cap > 0:
				var pt := String(item.get("potion", "healing"))
				if not _gain_potion(ev, "shop", pt):
					ev.append_array(_drink(pt, "shop"))
			else:
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
	var free := int(offer.get("free_restocks", 0))
	var price := 0 if free > 0 else int(offer.get("restock_price", Balance.SHOP_RESTOCK_PRICE))
	if run.gold < price:
		return [_e("not enough gold")]
	_record(["shop_reroll"])
	var ev: Array[Dictionary] = []
	run.gold -= price
	ev.append({"type": "gold_changed", "amount": -price, "total": run.gold, "source": "shop_reroll"})
	var o := {"kind": "shop", "items": _shop_stock(), "restock_price": int(offer.get("restock_price", Balance.SHOP_RESTOCK_PRICE))}
	o["free_restocks"] = maxi(0, free - 1)
	_set_offer(o, Phase.SHOP, ev)
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
	if op != "skip":
		var fs := String(offer.get("source", "tile"))
		_upgrade("forge" if fs == "tile" else fs)
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
			for pid in Passives.roll_regular(run.rng, 2, _passive_excluded()):
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
			var tries := 0
			while kinds.size() < 2 and tries < 200:
				tries += 1
				var k := _rand_kind()
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
	if String(offer.get("kind", "")) == "ore":
		_mine_ore(choice, ev)
		_advance(ev)
		return ev
	var id := String(offer.id)
	_close_offer(ev)
	if (id == "shrine" and String(choice.get("blessing", "")) != "gold") or (id == "dicesmith" and choice.has("kind")) or (id == "idol" and i == 0):
		_upgrade("event")
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
				changes.append(run.board.set_tile(idx, type, run.rng, run.act, run.eff_lap()))
			run.roll_change_affixes(changes)
			ev.append({"type": "board_mutated", "changes": changes})
		"merchant":
			if i == 0:
				var loss := run.pct_of_max(Balance.MERCHANT_HP_PCT)
				run.max_hp -= loss
				var before := run.hp
				run.hp = mini(run.hp, run.max_hp)
				ev.append({"type": "hp_changed", "amount": run.hp - before, "total": run.hp, "source": "merchant", "max_hp": run.max_hp})
				_set_offer({"kind": "rune_assign", "rune": _rand_rune("rare"), "source": "event"}, Phase.DRAFT, ev)
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

# ================================================================ new biomes (docs/design/2026-09-29-new-biomes.md)

## Adds a change to a board_mutated list, replacing an earlier entry for the same tile.
static func _add_change(changes: Array, c: Dictionary) -> void:
	if c.is_empty():
		return
	for k in range(changes.size() - 1, -1, -1):
		if changes[k].idx == c.idx:
			changes.remove_at(k)
	changes.append(c)

## Twist rules of a lap mutation (after the regular spawns): the Warcamp rebuilds one drum while
## fewer than WARCAMP_DRUMS stand (change source "rebuild"); the mutation into Moonlit's Full lap
## places the moon rune chest (tile_changed {idx, type:"tile_changed", tile_type:"chest",
## moon:true, source:"full_moon"}).
func _twist_mutation(dest: int, changes: Array, ev: Array[Dictionary]) -> void:
	match run.twist():
		"drums":
			if run.board.count("drum") < BiomeDefs.WARCAMP_DRUMS:
				var c := run.board.rebuild_drum(run.rng, dest, [dest])
				if not c.is_empty():
					c["source"] = "rebuild"
					_add_change(changes, c)
		"moon":
			if run.moon_phase() == "full":
				var c := run.board.place_moon_chest(dest, [dest])
				if not c.is_empty():
					c["source"] = "full_moon"
					_add_change(changes, c)
					ev.append(_tile_changed(c))

## A tile_changed event from a board change (the tile's type goes to `tile_type`).
static func _tile_changed(c: Dictionary) -> Dictionary:
	var tc := c.duplicate(true)
	tc["tile_type"] = String(c.type)
	tc["type"] = "tile_changed"
	return tc

## moon_phase {phase, lap, laps_to_full} when the current lap is in an active Moonlit biome.
func _moon_event(ev: Array[Dictionary]) -> void:
	var ph := run.moon_phase()
	if ph != "":
		ev.append({"type": "moon_phase", "phase": ph, "lap": run.lap, "laps_to_full": run.laps_to_full_moon()})

## Sunscorched Ruins heat at the end of lap `completed`: HEAT_PCT of max HP (x hazard mult), never
## lethal, skipped when the hero landed on an oasis that lap. Emits heat {damage, cooled, lap}
## (+ hp_changed {source:"heat"}).
func _heat(completed: int, ev: Array[Dictionary]) -> void:
	if run.twist() != "heat":
		return
	var cooled := run.cooled_lap == completed
	var dmg := 0
	if not cooled:
		var raw := run.pct_of_max(BiomeDefs.HEAT_PCT)
		if not run.meta.is_empty():
			raw = int(round(raw * run.hazard_mult()))
		dmg = maxi(0, mini(raw, run.hp - 1))
		run.hp -= dmg
		run.stats.damage_taken = int(run.stats.get("damage_taken", 0)) + dmg
	ev.append({"type": "heat", "damage": dmg, "cooled": cooled, "lap": completed})
	if dmg > 0:
		ev.append({"type": "hp_changed", "amount": -dmg, "total": run.hp, "source": "heat", "max_hp": run.max_hp})

## Oasis landing: heals OASIS_HEAL_PCT and cools the current lap. Emits oasis {idx, healed, lap}.
func _oasis(idx: int, ev: Array[Dictionary]) -> void:
	if run.twist() != "heat":
		return
	run.cooled_lap = run.lap
	var h := run.heal(run.pct_of_max(BiomeDefs.OASIS_HEAL_PCT))
	ev.append({"type": "oasis", "idx": idx, "healed": h, "lap": run.lap})
	ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "oasis", "max_hp": run.max_hp})

## Orc Warcamp: landing smashes the drum (it becomes Empty) for DRUM_GOLD x gold scale.
## Emits board_mutated, drum_smashed {idx, gold, drums} (drums = still standing), gold_changed.
func _smash_drum(idx: int, ev: Array[Dictionary]) -> void:
	if run.twist() != "drums":
		return
	var g := run.gold_bonus(int(round(BiomeDefs.DRUM_GOLD * Balance.gold_scale(run.eff_lap()))))
	_consume(idx, ev)
	ev.append({"type": "drum_smashed", "idx": idx, "gold": g, "drums": run.board.count("drum")})
	_gold(ev, g, "drum")

## Deep Mines ore gold for the current lap.
func ore_gold() -> int:
	return run.gold_bonus(int(round(BiomeDefs.ORE_GOLD * Balance.gold_scale(run.eff_lap()))))

## Deep Mines: landing on ore opens offer {kind:"ore", id:"ore", idx, title, text, gold,
## choices:[{label, desc, enabled, ore:"gold", gold}, {label, desc, enabled, ore:"raise"}]} in phase
## EVENT, answered with event_choose(i).
func _open_ore(idx: int, ev: Array[Dictionary]) -> void:
	if run.twist() != "ore":
		return
	var g := ore_gold()
	var can_raise := false
	for d in run.dice:
		for fi in 6:
			if d.can_raise(fi):
				can_raise = true
	var choices: Array = [
		{"label": "Take %d gold" % g, "desc": "Pocket the ore.", "enabled": true, "ore": "gold", "gold": g},
		{"label": "Face Raise", "desc": "Smelt it: raise one face of one die by 1.", "enabled": can_raise, "ore": "raise"},
	]
	_set_offer({"kind": "ore", "id": "ore", "idx": idx, "title": "Ore Vein",
		"text": "A vein of ore glitters in the rock. Mining it will bring the ceiling down.", "gold": g,
		"choices": choices}, Phase.EVENT, ev)

## Resolves an ore choice: ore_mined {idx, choice, gold}, the cave-in (tile_changed {idx,
## tile_type:"trap", source:"cave_in"} + board_mutated), then the gold or a Forge "raise" offer
## (source "ore").
func _mine_ore(choice: Dictionary, ev: Array[Dictionary]) -> void:
	var idx := int(offer.get("idx", run.pos))
	var kind := String(choice.get("ore", "gold"))
	var g := int(choice.get("gold", 0)) if kind == "gold" else 0
	_close_offer(ev)
	ev.append({"type": "ore_mined", "idx": idx, "choice": kind, "gold": g})
	var c := run.board.set_type(idx, "trap")
	c["source"] = "cave_in"
	ev.append(_tile_changed(c))
	ev.append({"type": "board_mutated", "changes": [c]})
	if kind == "gold":
		_gold(ev, g, "ore")
	else:
		pending.push_front({"kind": "forge", "source": "ore"})

## Moonlit Woods moon rune chest: a 1-of-3 rune choice (source "moon_chest") with at least one
## Rare or Epic rune (restricted to the unlocked rune pool).
func _moon_chest(ev: Array[Dictionary]) -> void:
	var pool := _rune_pool()
	var ids: Array[String] = Runes.random_runes_in(run.rng, 3, pool)
	var shiny := false
	for id in ids:
		if Runes.rarity(id) != "common":
			shiny = true
	if not shiny and not ids.is_empty():
		var rare: Array = []
		for id in (pool if not pool.is_empty() else Runes.IDS):
			if Runes.rarity(String(id)) != "common" and not ids.has(String(id)):
				rare.append(String(id))
		if not rare.is_empty():
			ids[ids.size() - 1] = String(run.rng.pick(rare))
	var options: Array = []
	for id in ids:
		options.append(Runes.option(id))
	_set_offer({"kind": "draft", "options": options, "source": "moon_chest"}, Phase.DRAFT, ev)

# ================================================================ meta layer: pools, potions, pets

## Random rune / die kind / passive exclusions honouring the run's unlocked pools (meta layer).
## Legacy runs (no meta) draw from everything, exactly as before.
func _rand_rune(rarity := "") -> String:
	return Runes.random_rune_in(run.rng, _rune_pool(), rarity)

## The rune drop pool: the run's unlocked runes (all in legacy runs), minus every rune the pool
## already holds Balance.rune_cap(rune) times (another copy would do nothing).
func _rune_pool() -> Array:
	var p := run.pool("runes")
	var out: Array = []
	for id in (p if not p.is_empty() else Runes.IDS):
		if run.dice_with_rune(String(id)).size() < Balance.rune_cap(String(id)):
			out.append(id)
	return out if not out.is_empty() else (p if not p.is_empty() else Runes.IDS.duplicate())

func _rand_kind() -> String:
	return DiceKinds.random_kind_in(run.rng, run.pool("kinds"))

## Shop die kind: _rand_kind() with the class's kind weighting (Paladin: Twin/Even x2).
func _shop_kind() -> String:
	var bias := ClassLogic.shop_kind_bias(run)
	if bias.is_empty():
		return _rand_kind()
	return DiceKinds.random_kind_biased(run.rng, run.pool("kinds"), bias)

## Owned passives plus every passive not unlocked in the profile. `reward` (elite and mini-boss
## rewards) also keeps the economy-only passives out in meta runs.
func _passive_excluded(reward := false) -> Array:
	var out: Array = Array(run.passives).duplicate()
	var allowed := run.pool("passives")
	if not allowed.is_empty():
		for id in Passives.IDS:
			if (not allowed.has(id) or (reward and UnlockDefs.ECONOMY_PASSIVES.has(id))) and not out.has(id):
				out.append(id)
	return out

## Records `id` in the stats list `key` (minibosses_killed, bosses_killed).
func _stat_add(id: String, key: String) -> void:
	var a: Array = run.stats.get(key, [])
	a.append(id)
	run.stats[key] = a

## A10: the route's other final-boss candidate, once, after the first final boss falls.
func _second_boss() -> String:
	if not run.has_asc("double_boss") or int(run.stats.get("boss_stage", 0)) != 0:
		return ""
	for b in run.boss_candidates():
		if String(b) != run.boss_id:
			return String(b)
	return ""

## Trap / ice dodge: roll + bonus >= min (Sure Foot trait: 3+; Skull Buddy perk: +1 to the roll).
func _dodge_min() -> int:
	return int(GearDefs.TRAIT_BONUS.boots_sure_foot) if run.has_trait("boots_sure_foot") else Balance.TRAP_DODGE_MIN

func _dodge_bonus() -> int:
	return 1 if run.has_pet("skull_buddy") else 0

## A7: a random face of a random die becomes 1 until the next Forge visit.
func _biome_curse(ev: Array[Dictionary]) -> void:
	var opts: Array = []
	for d in run.dice.size():
		for f in 6:
			if run.dice[d].faces[f] > 1:
				opts.append([d, f])
	if opts.is_empty():
		return
	var pk: Array = run.rng.pick(opts)
	run.cursed_faces.append({"die": int(pk[0]), "face": int(pk[1]), "value": run.dice[pk[0]].faces[pk[1]]})
	run.dice[pk[0]].faces[pk[1]] = 1
	ev.append({"type": "face_cursed", "die_idx": int(pk[0]), "face_idx": int(pk[1]), "value": 1, "faces": Array(run.dice[pk[0]].faces)})

func _lift_curse(ev: Array[Dictionary]) -> void:
	for k in range(run.cursed_faces.size() - 1, -1, -1):
		var c: Dictionary = run.cursed_faces[k]
		run.dice[int(c.die)].faces[int(c.face)] = int(c.value)
		ev.append(_face_ev(int(c.die), int(c.face)))
	run.cursed_faces.clear()

## Puts a potion of `type` on the belt. Emits potion_gained {potions, cap, belt, potion, source}.
## Returns false (and changes nothing) when the belt is full or the run has no belt.
func _gain_potion(ev: Array[Dictionary], source: String, type := "healing") -> bool:
	if run.potions >= run.potion_cap:
		return false
	run.belt.append(type)
	run.sync_potions()
	ev.append({"type": "potion_gained", "potions": run.potions, "cap": run.potion_cap, "belt": Array(run.belt),
		"potion": type, "source": source})
	return true

## Drinks a potion from the belt: a free action in every phase except GAME_OVER/VICTORY (board,
## combat on the player's turn, all modals), at most one per combat turn. `slot` indexes
## run.belt (-1 = the first Healing Draught, else slot 0). Stoneskin and Reroll Tonic are
## combat-only. Emits potion_used {potion, slot, healed, hp, potions, belt} and the effect events.
func use_potion(slot := -1) -> Array[Dictionary]:
	if is_over():
		return _err("use_potion")
	if run.belt.is_empty():
		return [_e("no potions")]
	if slot < 0:
		slot = maxi(0, run.belt.find("healing"))
	if slot >= run.belt.size():
		return [_e("bad potion slot")]
	var type := run.belt[slot]
	if PotionDefs.combat_only(type) and phase != Phase.COMBAT:
		return [_e("%s only works in combat" % PotionDefs.name_of(type))]
	if phase == Phase.COMBAT and combat.potion_turn == combat.turn:
		return [_e("one potion per turn")]
	if type == "healing" and run.hp >= run.max_hp:
		return [_e("HP is full")]
	_record(["use_potion", slot])
	run.belt.remove_at(slot)
	run.sync_potions()
	if phase == Phase.COMBAT:
		combat.potion_turn = combat.turn
	run.stats.potions_used = int(run.stats.get("potions_used", 0)) + 1
	var ev := _drink(type, "belt")
	var used := {"type": "potion_used", "potion": type, "slot": slot, "healed": 0, "hp": run.hp, "max_hp": run.max_hp,
		"potions": run.potions, "belt": Array(run.belt)}
	for e in ev:
		if e.type == "hp_changed":
			used.healed = int(e.amount)
	ev.push_front(used)
	return ev

## A potion's effect (shared by the belt and "drunk at once" overflow).
func _drink(type: String, source: String) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	match type:
		"stoneskin":
			if combat != null:
				run.block += PotionDefs.STONESKIN_BLOCK
				combat.stoneskin = PotionDefs.STONESKIN_BLOCK
				run.stats.block_gained = int(run.stats.get("block_gained", 0)) + PotionDefs.STONESKIN_BLOCK
				ev.append({"type": "block_gained", "target": "hero", "amount": PotionDefs.STONESKIN_BLOCK, "total": run.block, "source": "potion"})
		"reroll_tonic":
			if combat != null:
				combat.rerolls_left += PotionDefs.TONIC_REROLLS
				ev.append({"type": "rerolls_changed", "rerolls_left": combat.rerolls_left, "source": "potion"})
		"cleanse":
			run.chill = 0
			if combat != null:
				combat.hero_burn = 0
				combat.pending_curse = 0
				for i in combat.locked.size():
					combat.locked[i] = false
			ev.append({"type": "status", "target": "hero", "status": "cleansed", "value": 0, "source": "potion"})
			var hc := run.heal(run.pct_of_max(PotionDefs.CLEANSE_HEAL_PCT))
			ev.append({"type": "hp_changed", "amount": hc, "total": run.hp, "source": "potion", "max_hp": run.max_hp})
		_:
			var h := run.heal(run.pct_of_max(run.potion_pct()))
			ev.append({"type": "hp_changed", "amount": h, "total": run.hp, "source": "potion", "max_hp": run.max_hp})
	if source != "belt":
		ev.push_front({"type": "potion_used", "potion": type, "slot": -1, "healed": 0, "hp": run.hp, "max_hp": run.max_hp,
			"potions": run.potions, "belt": Array(run.belt), "source": source})
	return ev

# ================================================================ meta layer: minigames

## Opens a minigame (phase MINIGAME). Its Rng is seeded from the run Rng (one draw), so a save
## taken on entry resumes identically. Offer: {kind:"minigame", id, name, state (public view),
## actions_left, done, par}.
func _start_minigame(id: String, ev: Array[Dictionary]) -> void:
	var lvl := int((run.meta.get("mastery", {}) as Dictionary).get(id, 1))
	minigame = Minigames.create(id, run.rng.next_u32(), lvl)
	run.stats.minigames_played = int(run.stats.get("minigames_played", 0)) + 1
	var plays: Dictionary = run.stats.get("minigame_plays", {})
	plays[id] = int(plays.get(id, 0)) + 1
	run.stats["minigame_plays"] = plays
	# save_point: the presentation auto-saves here (spec decision: save at minigame entry), so
	# quitting mid-game and reloading resumes the same board (no save-scumming).
	ev.append({"type": "minigame_started", "id": id, "name": MinigameDefs.name_of(id), "state": minigame.public_state(),
		"actions_left": minigame.actions_left, "save_point": true})
	_set_offer(_minigame_offer(), Phase.MINIGAME, ev)

func _minigame_offer() -> Dictionary:
	return {"kind": "minigame", "id": minigame.id, "name": MinigameDefs.name_of(minigame.id),
		"state": minigame.public_state(), "actions_left": minigame.actions_left, "done": minigame.done,
		"median": float(MinigameDefs.MEDIAN[minigame.id])}

## One minigame input: fossil_hunter [x, y] · bubble_breaker [x, y] · scratch_off [idx] ·
## claw_machine [position 0..1]. Emits minigame_update {id, state, actions_left, done, info}.
func minigame_action(args: Array) -> Array[Dictionary]:
	if phase != Phase.MINIGAME or minigame == null:
		return _err("minigame_action")
	var res := minigame.action(args)
	if res.has("error"):
		return [_e(String(res.error))]
	_record(["minigame_action", args.duplicate()])
	offer = _minigame_offer()
	return [{"type": "minigame_update", "id": minigame.id, "state": offer.state.duplicate(true),
		"actions_left": minigame.actions_left, "done": minigame.done, "info": res.get("info", {})}]

## Ends the minigame (unused actions are forfeited) and scores it.
func minigame_finish() -> Array[Dictionary]:
	if phase != Phase.MINIGAME or minigame == null:
		return _err("minigame_finish")
	_record(["minigame_finish"])
	return _minigame_result(float(minigame.score()) / float(MinigameDefs.MEDIAN[minigame.id]), false)

## AUTO: skips the game and takes the par result (MinigameDefs.PAR of median).
func minigame_auto() -> Array[Dictionary]:
	if phase != Phase.MINIGAME or minigame == null:
		return _err("minigame_auto")
	_record(["minigame_auto"])
	return _minigame_result(MinigameDefs.PAR, true)

## Emits minigame_result {id, score, ratio, tier, mult, auto, crowns, state} + offer_closed, banks
## the tier's Crowns, then opens the reward choice: offer {kind:"reward", source:"minigame", id,
## tier, options:[{id, label, desc, ...}]} in phase DRAFT, picked with pick_draft(i).
func _minigame_result(ratio: float, auto: bool) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var id := minigame.id
	var tier := MinigameDefs.tier_for(ratio)
	var mult := MinigameDefs.skill_mult(ratio) * MinigameDefs.mastery_mult(minigame.level)
	var crowns := int(Economy.CROWNS_MINIGAME[tier])
	run.stats.minigame_crowns = int(run.stats.get("minigame_crowns", 0)) + crowns
	ev.append({"type": "minigame_result", "id": id, "score": minigame.score(), "ratio": snappedf(ratio, 0.001), "tier": tier,
		"mult": snappedf(mult, 0.001), "auto": auto, "crowns": crowns, "state": minigame.public_state()})
	minigame = null
	_close_offer(ev)
	var options := _reward_options(id, tier, mult)
	_set_offer({"kind": "reward", "source": "minigame", "id": id, "tier": tier, "options": options}, Phase.DRAFT, ev)
	return ev

## Reward choices by tier (MinigameDefs): bronze {gold, crown}, silver {potion, face raise,
## gold}, gold {rune choice of 2, potion + gold, the minigame's signature}.
func _reward_options(id: String, tier: String, mult: float) -> Array:
	var gs := Balance.gold_scale(run.eff_lap()) * mult
	var g := func(base: int) -> int:
		return run.gold_bonus(int(round(base * gs)))
	match tier:
		"bronze":
			var a: int = g.call(MinigameDefs.BRONZE_GOLD)
			return [{"id": "gold", "amount": a, "label": "%d gold" % a, "desc": "Take the coins."},
				{"id": "crown", "amount": 1, "label": "+1 Crown", "desc": "Banked at the end of the run."}]
		"silver":
			var b: int = g.call(MinigameDefs.SILVER_GOLD)
			return [{"id": "potion", "potion": "healing", "label": "Healing Draught", "desc": "A potion for your belt."},
				{"id": "face_raise", "label": "Face Raise", "desc": "Raise one face of one die by 1."},
				{"id": "gold", "amount": b, "label": "%d gold" % b, "desc": "Take the coins."}]
	var c: int = g.call(MinigameDefs.GOLD_POTION_GOLD)
	var opts: Array = [{"id": "rune_choice", "label": "Rune of choice", "desc": "Pick 1 of 2 runes."},
		{"id": "potion_gold", "potion": "healing", "amount": c, "label": "Potion + %d gold" % c, "desc": "A Healing Draught and coins."}]
	match MinigameDefs.signature(id):
		"new_die":
			var kind := _rand_kind()
			opts.append({"id": "new_die", "kind": kind, "label": DiceKinds.label(kind), "desc": String(DiceKinds.DEFS[kind].desc)})
		"reroll_boost":
			opts.append({"id": "reroll_boost", "fights": MinigameDefs.REROLL_BOOST_FIGHTS, "label": "+1 Reroll x3",
				"desc": "+1 combat reroll every turn for the next %d fights." % MinigameDefs.REROLL_BOOST_FIGHTS})
		"passive_common":
			opts.append({"id": "passive_common", "label": "Common passive", "desc": "Pick 1 of 3 common passives."})
		_:
			var d: int = g.call(MinigameDefs.SIGNATURE_GOLD)
			opts.append({"id": "gold", "amount": d, "label": "%d gold" % d, "desc": "The jackpot purse."})
	return opts

func _pick_reward(opt: Dictionary, ev: Array[Dictionary]) -> void:
	match String(opt.id):
		"gold":
			_gold(ev, int(opt.amount), "minigame")
		"crown":
			run.stats.minigame_crowns = int(run.stats.get("minigame_crowns", 0)) + int(opt.amount)
			ev.append({"type": "crowns_pending", "amount": int(opt.amount), "total": int(run.stats.minigame_crowns)})
		"potion", "potion_gold":
			if not _gain_potion(ev, "minigame", String(opt.get("potion", "healing"))):
				ev.append_array(_drink(String(opt.get("potion", "healing")), "minigame"))
			if opt.id == "potion_gold":
				_gold(ev, int(opt.amount), "minigame")
		"face_raise":
			pending.push_front({"kind": "forge", "source": "minigame"})
		"rune_choice":
			_open_rune_choice("minigame", ev, 2)
		"new_die":
			_upgrade("minigame")
			if run.dice.size() < run.max_dice():
				_add_die(ev, String(opt.kind))
			else:
				_reforge_die(ev, _weakest_die(), String(opt.kind))
		"reroll_boost":
			_upgrade("minigame")
			run.pet_state["boost"] = int(opt.get("fights", MinigameDefs.REROLL_BOOST_FIGHTS))
			ev.append({"type": "stat_changed", "stat": "reroll_boost", "value": int(run.pet_state.boost)})
		"passive_common":
			var skip := _passive_excluded()
			for pid in Passives.IDS:
				if Passives.rarity(pid) != "common" and not skip.has(pid):
					skip.append(pid)
			var ids := Passives.roll_regular(run.rng, 3, skip)
			if not ids.is_empty():
				var options: Array = []
				for pid in ids:
					options.append(Passives.option(pid))
				_set_offer({"kind": "passive", "options": options, "source": "minigame"}, Phase.DRAFT, ev)

# ================================================================ scenarios (presentation/testing aid)

## Jumps straight into a modal or fight for screenshot scenarios. Not recorded in `commands`,
## so a flow touched by this cannot be replayed from its log. kind: shop | draft | rune_choice |
## rune_assign | passive | forge | event | portal | combat | boss | miniboss. arg: event id, rune
## id, or comma separated enemy ids for combat, or the passive source ("elite" | "miniboss" |
## "boss" = an elite's boss-tier roll), or a boss / mini-boss id (default: the run's).
func debug_open(kind: String, arg := "") -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	combat = null
	minigame = null
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
		"minigame": _start_minigame(arg if MinigameDefs.has(arg) else "fossil_hunter", ev)
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
		"use_potion": return use_potion(a[0] if a.size() > 0 else -1)
		"minigame_action": return minigame_action(a[0] if a.size() > 0 and a[0] is Array else a)
		"minigame_finish": return minigame_finish()
		"minigame_auto": return minigame_auto()
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
		"board_rerolls_left": board_rerolls_left, "board_refunds": board_refunds, "pending": pending.duplicate(true),
		"commands": commands.duplicate(true),
		"minigame": minigame.to_dict() if minigame != null else null,
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
	f.board_refunds = int(d.get("board_refunds", 0))
	for p in d.get("pending", []):
		f.pending.append(_intify(p))
	f.commands = _intify(d.get("commands", []))
	if d.get("minigame") != null:
		f.minigame = Minigames.from_dict(d.minigame)
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
