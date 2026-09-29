class_name BotMeta
extends RefCounted
## Meta-layer policy for the greedy Bot (potions, minigames, minigame rewards, Camp spending,
## loadout). Bot.next_command() asks next_command() first; an empty result means "no meta
## action, carry on". Pure functions of the flow/profile state (no randomness of its own).

## "par": AUTO takes the par result without playing (review §5.4, the default for AUTO);
## "play": the bot plays the minigame (fossil probability hunt, largest bubble cluster,
## scratch in a seed-derived order, claw at the best prize centre).
static var minigame_mode := "par"

## HP ratio under which a big incoming hit triggers a Healing Draught in combat.
const POTION_HP := 0.35
## Before (turn 1 of) a boss or mini-boss fight, drink below this ratio.
const POTION_BOSS_HP := 0.6

static func next_command(f: GameFlow) -> Array:
	if f.is_over():
		return []
	match f.phase:
		GameFlow.Phase.MINIGAME:
			return minigame_command(f)
		GameFlow.Phase.DRAFT:
			if String(f.offer.get("kind", "")) == "reward":
				return ["pick_draft", pick_reward(f)]
		GameFlow.Phase.COMBAT:
			return _combat_potion(f)
		GameFlow.Phase.BOARD_READY:
			# a full belt at low HP: drink so the next potion isn't wasted
			if f.run.potions >= f.run.potion_cap and f.run.potion_cap > 0 and _hp(f) < 0.5 and f.run.belt.has("healing"):
				return ["use_potion", f.run.belt.find("healing")]
		GameFlow.Phase.SHOP:
			return _shop_potion(f)
	return []

static func _hp(f: GameFlow) -> float:
	return float(f.run.hp) / float(f.run.max_hp)

## Damage the hero takes this enemy phase if they only block what they have now.
static func incoming(f: GameFlow) -> int:
	var c := f.combat
	var dmg := 0
	for i in c.enemies.size():
		var e: Dictionary = c.enemies[i]
		if c.alive(i) and not bool(e.frozen) and ["attack", "chill", "drain"].has(String(e.intent.kind)):
			dmg += int(e.intent.value)
	return maxi(0, dmg - f.run.block) + c.hero_burn

static func _combat_potion(f: GameFlow) -> Array:
	var c := f.combat
	if f.run.belt.is_empty() or c.potion_turn == c.turn:
		return []
	var inc := incoming(f)
	var heal := f.run.belt.find("healing")
	if heal >= 0 and f.run.hp < f.run.max_hp:
		var lethal := inc >= f.run.hp
		var big := _hp(f) < POTION_HP and inc >= int(f.run.max_hp * 0.12)
		var boss_prep := (c.boss or c.miniboss) and c.turn == 1 and _hp(f) < POTION_BOSS_HP
		if lethal or big or boss_prep:
			return ["use_potion", heal]
	var stone := f.run.belt.find("stoneskin")
	if stone >= 0 and inc >= maxi(8, f.run.hp / 3):
		return ["use_potion", stone]
	var cleanse := f.run.belt.find("cleanse")
	if cleanse >= 0 and (c.hero_burn >= 4 or c.locked.count(true) >= 2):
		return ["use_potion", cleanse]
	var tonic := f.run.belt.find("reroll_tonic")
	if tonic >= 0 and (c.boss or c.miniboss) and c.rerolls_left == 0 and float(c.current_combo(f.run).mult) < 2.0:
		return ["use_potion", tonic]
	return []

## Buys a belt potion when there is room and gold to spare (after the Bot's own shop logic would
## have left); keeps at least one potion in the belt.
static func _shop_potion(f: GameFlow) -> Array:
	if f.run.potion_cap <= 0 or f.run.potions >= f.run.potion_cap:
		return []
	for i in f.offer.items.size():
		var it: Dictionary = f.offer.items[i]
		if String(it.id) == "potion" and not bool(it.sold) and int(it.price) <= f.run.gold \
				and (f.run.potions == 0 or _hp(f) < 0.8):
			return ["shop_buy", i, -1]
	return []

# ------------------------------------------------------------------ minigame rewards

static func pick_reward(f: GameFlow) -> int:
	var opts: Array = f.offer.options
	var best := 0
	var best_s := -INF
	for i in opts.size():
		var o: Dictionary = opts[i]
		var s := 0.0
		match String(o.id):
			"gold": s = float(o.amount) / 5.0
			"crown": s = 1.0
			"potion": s = 7.0 if f.run.potions < f.run.potion_cap else 3.0
			"potion_gold": s = (7.0 if f.run.potions < f.run.potion_cap else 3.0) + float(o.amount) / 5.0
			"face_raise": s = 4.0
			"rune_choice": s = 7.0
			"new_die": s = 12.0 if f.run.dice.size() < f.run.max_dice() else 5.0
			"reroll_boost": s = 8.0
			"passive_common": s = 7.5
		if s > best_s:
			best_s = s
			best = i
	return best

# ------------------------------------------------------------------ minigames

static func minigame_command(f: GameFlow) -> Array:
	var st: Dictionary = f.offer.get("state", {})
	if minigame_mode == "par" and int(st.get("actions_left", 0)) > 0 and not bool(st.get("done", false)) and _untouched(st):
		return ["minigame_auto"]
	if bool(st.get("done", false)) or int(st.get("actions_left", 0)) <= 0:
		return ["minigame_finish"]
	match String(f.offer.id):
		"fossil_hunter":
			var c := fossil_pick(st)
			return ["minigame_action", [c % int(st.w), c / int(st.w)]]
		"bubble_breaker":
			var cl := bubble_pick(st)
			if cl < 0:
				return ["minigame_finish"]
			return ["minigame_action", [cl / int(st.h), cl % int(st.h)]]
		"scratch_off":
			return ["minigame_action", [scratch_pick(st, f.run.seed)]]
		"claw_machine":
			var best := -1
			for i in st.prizes.size():
				var p: Dictionary = st.prizes[i]
				if not bool(p.taken) and (best < 0 or int(p.points) > int(st.prizes[best].points)):
					best = i
			return ["minigame_action", [float(st.prizes[best].pos) if best >= 0 else 0.5]]
	return ["minigame_finish"]

static func _untouched(st: Dictionary) -> bool:
	match String(st.get("id", "")):
		"fossil_hunter": return int(st.actions_left) == FossilHunter.DIGS
		"bubble_breaker": return int(st.actions_left) == BubbleBreaker.TAPS
		"scratch_off": return int(st.actions_left) == ScratchOff.SCRATCHES
		"claw_machine": return int(st.actions_left) == ClawMachine.GRABS
	return true

## Probability hunt: the undug cell covered by the most fossil layouts consistent with the
## public state (hits, misses, distance hints, completed fossils).
static func fossil_pick(st: Dictionary) -> int:
	var w := int(st.w)
	var h := int(st.h)
	var cells: Array = st.cells
	var hints: Array = st.hints
	var places: Array = []
	for size in FossilHunter.SIZES:
		var ps: Array = []
		for horiz in [true, false]:
			for y in range(0, h - (0 if horiz else int(size) - 1)):
				for x in range(0, w - (int(size) - 1 if horiz else 0)):
					var p: Array = []
					for k in int(size):
						p.append((y + (0 if horiz else k)) * w + x + (k if horiz else 0))
					ps.append(p)
		places.append(ps)
	var counts: Array = []
	counts.resize(w * h)
	counts.fill(0)
	var any := false
	for a in places[0]:
		for b in places[1]:
			var cover := {}
			var overlap := false
			for i in a:
				cover[i] = 0
			for i in b:
				if cover.has(i):
					overlap = true
				cover[i] = 1
			if overlap or not _fossil_ok(cells, hints, cover, a, b, w):
				continue
			any = true
			for i in cover:
				if String(cells[i]) == "?":
					counts[i] += 1
	var best := -1
	for i in cells.size():
		if String(cells[i]) != "?":
			continue
		if best < 0 or int(counts[i]) > int(counts[best]):
			best = i
	if not any or best < 0:
		for i in cells.size():
			if String(cells[i]) == "?":
				return i
	return best

static func _fossil_ok(cells: Array, hints: Array, cover: Dictionary, a: Array, b: Array, w: int) -> bool:
	var fossils := [a, b]
	for i in cells.size():
		var c := String(cells[i])
		if c == "?":
			continue
		if c == ".":
			if cover.has(i):
				return false
			var d := 99
			for j in cover:
				d = mini(d, absi(int(j) % w - i % w) + absi(int(j) / w - i / w))
			if d != int(hints[i]):
				return false
		else:
			if not cover.has(i):
				return false
			var complete := true
			for j in fossils[cover[i]]:
				if String(cells[j]) == "?":
					complete = false
			if (c == "bone") != complete:
				return false
	return true

## Largest poppable cluster (cell index x * H + y), or -1.
static func bubble_pick(st: Dictionary) -> int:
	var b := BubbleBreaker.new()
	b.grid = Minigame.ints(st.grid)
	var cl := b.clusters()
	return int(cl[0][0]) if not cl.is_empty() else -1

static func scratch_pick(st: Dictionary, run_seed: int) -> int:
	var cells: Array = st.cells
	var start := absi(run_seed) % ScratchOff.CELLS
	for k in ScratchOff.CELLS:
		var i := (start + k * 4) % ScratchOff.CELLS
		if int(cells[i]) == 0:
			return i
	return 0

# ------------------------------------------------------------------ camp

## Loadout for the next run: the owned minigames (up to the slots, Fossil and Claw first since
## their gold signatures help builds), and the highest-level owned pet (ties: content order).
static func choose_loadout(p: Profile) -> Array:
	var order := ["fossil_hunter", "claw_machine", "bubble_breaker", "scratch_off"]
	var mg: Array = []
	for id in order:
		if p.owns("minigames", id) and mg.size() < p.loadout_slots():
			mg.append(id)
	var pet := ""
	var pref := ["skull_buddy", "guard_die", "lantern_ghost", "pumpkin_sprite", "crystal_wisp", "coin_mimic",
		"wick", "frost_mote", "pebble_golem", "grimoire", "tinker_gear", "cauldron"]
	for id in pref:
		if p.owns("pets", id) and (pet == "" or p.pet_level(id) > p.pet_level(pet)):
			pet = id
	return [mg, pet]

## Spends Crowns and Sigils greedily: the cheapest affordable item each step, Sigil unlocks in
## CLASS -> PACK -> PET -> MINIGAME -> BIOME order, gear traits keep their default. A player who
## just got a class from a milestone plays it before buying another (`got_class`). Returns the
## commands applied.
static func spend(camp: Camp, got_class := false) -> Array:
	var done: Array = []
	for guard in 200:
		var best: Dictionary = {}
		for it in camp.catalog():
			if not bool(it.affordable):
				continue
			if got_class and String(it.kind) == "classes":
				continue
			if best.is_empty() or _spend_rank(it) < _spend_rank(best):
				best = it
		if best.is_empty():
			break
		var ev := camp.apply(best.cmd)
		if ev.is_empty() or String(ev[0].type) == "error":
			break
		done.append(best.cmd)
	return done

static func _spend_rank(it: Dictionary) -> float:
	var c: Dictionary = it.cost
	if int(c.get("sigils", 0)) > 0:
		var order := ["classes", "packs", "pets", "minigames", "biomes", "potions", "gear", "minibosses", "bosses"]
		return 10000.0 + order.find(String(it.kind)) * 10.0 + int(c.sigils)
	# one-off Camp upgrades (belt, whetstone, starter kit, 3rd slot) count at half price, so
	# they get bought alongside the gear levels instead of after them
	var cr := float(c.get("crowns", 0))
	return cr * 0.5 if String(it.cmd[0]) == "buy_upgrade" else cr

# ------------------------------------------------------------------ AUTO (Bot.decide)

## The meta part of Bot.decide(): {} when there is nothing meta to do, else a decide() result
## {cmd, reason, stop, stop_reason}. Minigames always use AUTO's par result.
static func decide(f: GameFlow, rules: AutoRules) -> Dictionary:
	var cmd := next_command(f)
	if cmd.is_empty():
		if f.phase == GameFlow.Phase.MINIGAME:
			return _res(["minigame_finish"], "Finishing the minigame")
		return {}
	match String(cmd[0]):
		"minigame_auto":
			return _res(cmd, "Minigame: taking the par result")
		"minigame_finish":
			return _res(cmd, "Minigame: cashing in")
		"minigame_action":
			return _res(cmd, "Minigame: playing")
		"pick_draft":
			if not rules.drafts:
				return {"cmd": [], "reason": "", "stop": true, "stop_reason": "AUTO drafts are off."}
			return _res(cmd, "Minigame reward: " + String(f.offer.options[int(cmd[1])].label))
		"use_potion":
			return _res(cmd, "Drinking a %s" % PotionDefs.name_of(f.run.belt[int(cmd[1])]))
		"shop_buy":
			if not rules.shop:
				return {}
			return _res(cmd, "Buying a potion for the belt")
	return _res(cmd, "")

static func _res(cmd: Array, reason: String) -> Dictionary:
	return {"cmd": cmd, "reason": reason, "stop": false, "stop_reason": ""}
