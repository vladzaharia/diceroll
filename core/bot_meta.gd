class_name BotMeta
extends RefCounted
## Meta-layer policy for the greedy Bot (potions, minigames, minigame rewards, Camp spending,
## loadout). Bot.next_command() asks next_command() first; an empty result means "no meta
## action, carry on". Pure functions of the flow/profile state (no randomness of its own).

## "par": take the par result without playing (review §5.4; the sim's stand-in for an average
## player — the in-game AUTO never plays minigames, Bot.decide pauses there);
## "play": the bot plays the minigame (fossil: follow bones, else a spread pattern; largest bubble cluster,
## scratch in a seed-derived order, claw at the best prize centre; the Minigames 2.0 set:
## bubble shooter's best angle, plinko's best-odds slot, the shell game's tracked cup (a Sharp
## Eye pick), memory in grid order (no memory of its own), fishing the deep spot with a quick
## strike, the wheel's richest brake, high-low by expected value).
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
			"sharpshooter": s = 8.0
			"rare_rune": s = 8.0
			"heart_gem": s = 6.5
			"mirror_forge": s = 7.0
			"potion_pair": s = 9.0 if f.run.potions < f.run.potion_cap else 4.0
			"passive_uncommon": s = 8.0
			"high_roller": s = 7.0
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
	var args := play_args(String(f.offer.id), st, f.run.seed)
	return ["minigame_finish"] if args.is_empty() else ["minigame_action", args]

## The bot's next input for a minigame from its public state (args for minigame_action), or []
## when it has nothing worth doing (cash in). Pure: public data plus the run seed.
static func play_args(id: String, st: Dictionary, run_seed := 0) -> Array:
	match id:
		"fossil_hunter":
			var c := fossil_pick(st)
			return [c % int(st.w), c / int(st.w)]
		"bubble_breaker":
			var cl := bubble_pick(st)
			if cl < 0:
				return []
			return [cl / int(st.h), cl % int(st.h)]
		"scratch_off":
			return [scratch_pick(st, run_seed)]
		"claw_machine":
			# aim at the richest-looking capsule (its tier colour is public)
			var best := -1
			for i in st.balls.size():
				var b: Dictionary = st.balls[i]
				if not bool(b.taken) and (best < 0 or ClawMachine.TIERS.find(String(b.tier)) > ClawMachine.TIERS.find(String(st.balls[best].tier))):
					best = i
			return [float(st.balls[best].pos) if best >= 0 else 0.5]
		"bubble_shooter":
			return [BubbleShooter.best_angle(st.grid, int(st.current))]
		"plinko":
			return [Plinko.best_slot(st.buckets, st.golden)]
		"shell_game":
			return [ShellGame.follow(int(st.start), st.swaps), 0.5]
		"memory_match":
			return [memory_pick(st)]
		"fishing":
			if String(st.phase) == "cast":
				return ["cast", 2]
			return ["hook", float(st.bite_at) + 0.2]
		"lucky_wheel":
			if String(st.phase) == "spin":
				return ["spin"]
			return ["stop", LuckyWheel.best_stop_for(st.segments, st.spin)]
		"high_low":
			return [high_low_pick(st)]
	return []

static func _untouched(st: Dictionary) -> bool:
	match String(st.get("id", "")):
		"fossil_hunter": return int(st.actions_left) == FossilHunter.DIGS
		"bubble_breaker": return int(st.actions_left) == BubbleBreaker.TAPS
		"scratch_off": return int(st.actions_left) == ScratchOff.SCRATCHES
		"claw_machine": return int(st.actions_left) == ClawMachine.GRABS
		"bubble_shooter": return int(st.actions_left) == BubbleShooter.SHOTS
		"plinko": return int(st.actions_left) == Plinko.DROPS
		"shell_game": return int(st.actions_left) == ShellGame.ROUNDS
		"memory_match": return int(st.open) < 0 and int(st.pairs) == 0 and int(st.actions_left) == MemoryMatch.MISSES
		"fishing": return int(st.actions_left) == Fishing.CASTS and String(st.phase) == "cast"
		"lucky_wheel": return int(st.actions_left) == LuckyWheel.SPINS and String(st.phase) == "spin"
		"high_low": return (st.history as Array).is_empty()
	return true

## Memory Match without a memory: the first face-down card (grid order) that isn't the open one.
static func memory_pick(st: Dictionary) -> int:
	var cards: Array = st.cards
	for i in cards.size():
		if int(cards[i]) == 0 and i != int(st.open):
			return i
	return 0

## High-Low: climb while the expected prize of a guess beats cashing the current rung.
static func high_low_pick(st: Dictionary) -> String:
	var die := int(st.die)
	var rung := int(st.rung)
	var g := HighLow.best_guess(die)
	var p := HighLow.win_odds(die, g)
	var up := float(HighLow.PRIZES[mini(rung + 1, HighLow.PRIZES.size() - 1)])
	var ev := p * up + (1.0 - p) * float(HighLow.PRIZES[HighLow.safety(rung)])
	return g if ev > float(HighLow.PRIZES[rung]) else "cash"

## Luck dig (no hints): follow an unfinished fossil first (extend a line of two hits, else try
## a hit's neighbours), otherwise dig the next cell of a fixed spread-out pattern.
static func fossil_pick(st: Dictionary) -> int:
	var w := int(st.w)
	var h := int(st.h)
	var cells: Array = st.cells
	var open := func(x: int, y: int) -> bool:
		return x >= 0 and x < w and y >= 0 and y < h and String(cells[y * w + x]) == "?"
	var hit := func(x: int, y: int) -> bool:
		return x >= 0 and x < w and y >= 0 and y < h and String(cells[y * w + x]) == "hit"
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	# 1. a line of hits: dig past either end
	for i in cells.size():
		if String(cells[i]) != "hit":
			continue
		var x := i % w
		var y := i / w
		for d: Vector2i in dirs:
			if hit.call(x + d.x, y + d.y):
				var k := 1
				while hit.call(x + d.x * k, y + d.y * k):
					k += 1
				if open.call(x + d.x * k, y + d.y * k):
					return (y + d.y * k) * w + x + d.x * k
				if open.call(x - d.x, y - d.y):
					return (y - d.y) * w + x - d.x
	# 2. a lone hit: try its neighbours
	for i in cells.size():
		if String(cells[i]) != "hit":
			continue
		for d: Vector2i in dirs:
			if open.call(i % w + d.x, i / w + d.y):
				return (i / w + d.y) * w + i % w + d.x
	# 3. spread: every other cell of a diagonal lattice first, then the rest
	for pass_i in 2:
		for k in cells.size():
			var i := (k * 17 + 3) % cells.size()
			if String(cells[i]) == "?" and ((i % w + i / w) % 2 == 0) == (pass_i == 0):
				return i
	return 0

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
	var order := ["fossil_hunter", "claw_machine", "bubble_breaker", "bubble_shooter", "plinko", "fishing", "memory_match",
		"shell_game", "high_low", "lucky_wheel", "scratch_off"]
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

## Trinket preference of the campaign bot (a player equips the trinket they like best): the
## Compass once its board reroll is on (Trinket R6), else the Coin Purse, the Tankard...
const TRINKET_PREF := ["compass", "coin_purse", "tankard", "lantern", "healers_flask", "traders_map", "skeleton_key", "loaded_die"]
## "Best by table" (--kit=best, expert): per slot, the items in preference order (the measured
## per-item deltas at max, docs/plans/balance.md Armory; one-handed weapons first so the shield
## stays); a slot keeps the kit piece when nothing listed is owned.
const BEST := {
	"weapon": ["wand", "dagger", "hand_axe", "spear", "greatsword"],
	"offhand": ["round_shield", "spiked_shield"],
	"head": ["bandit_mask", "ninja_headband"],
	"body": ["knight_plate", "hooded_robe", "druid_robe"],
}
const BEST_TRINKETS := ["coin_purse", "traders_map", "healers_flask", "compass", "lantern", "tankard"]

## Camp commands that equip the campaign bot's trinkets for class `cid` (kit pieces stay).
static func equip_cmds(p: Profile, cid: String) -> Array:
	var want := _trinkets(p)
	var lo := p.loadout_for(cid)
	var out: Array = []
	if want.size() > 0 and String(lo.trinket) != String(want[0]):
		out.append(["equip_item", cid, "trinket", want[0], ""])
	if want.size() > 1 and p.has_pouch() and String(lo.trinket2) != String(want[1]):
		out.append(["equip_item", cid, "trinket2", want[1], ""])
	return out

static func _trinkets(p: Profile) -> Array:
	var order: Array = []
	for id in TRINKET_PREF:
		if p.owns_item(String(id)):
			order.append(String(id))
	if order.has("compass") and p.rank("trinket") < ItemDefs.COMPASS_REROLL_RANK:
		order.erase("compass")
		order.insert(mini(1, order.size()), "compass")
	return order

## The expert loadout for class `cid`: BEST per slot (else the kit; the Dino Suit stays), trinkets
## by BEST_TRINKETS.
static func best_loadout(p: Profile, cid: String) -> Dictionary:
	var lo := p.loadout_for(cid)
	for slot in BEST:
		if ItemDefs.LOCKED_ARMOR.has(cid) and slot in ["head", "body"]:
			continue
		for id in BEST[slot]:
			if p.owns_item(String(id)) and ItemDefs.fits(String(id), String(slot)):
				if slot in ["weapon", "offhand", "head"]:
					lo[slot] = {"id": String(id), "variant": String(id)}
				else:
					lo[slot] = String(id)
				break
	var t: Array = []
	for id in BEST_TRINKETS:
		if p.owns_item(String(id)):
			t.append(String(id))
	if t.size() > 0:
		lo["trinket"] = t[0]
	if t.size() > 1 and p.has_pouch():
		lo["trinket2"] = t[1]
	return lo

## Spends Crowns and Sigils greedily: the cheapest affordable item each step, Sigil unlocks in
## CLASS -> PACK -> PET -> MINIGAME -> BIOME order, gear traits keep their default. A player who
## just got a major unlock (class, pet or biome) from a milestone enjoys it before buying another
## (`got_major`). Returns the commands applied.
static func spend(camp: Camp, got_major := false) -> Array:
	var done: Array = []
	for guard in 200:
		var best: Dictionary = {}
		for it in camp.catalog():
			if not bool(it.affordable):
				continue
			if got_major and UnlockDefs.MAJOR_KINDS.has(String(it.kind)):
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
## {cmd, reason, stop, stop_reason}. (Bot.decide stops before this in phase MINIGAME: the
## player plays minigames; the minigame reward pick stays AUTO's.)
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
