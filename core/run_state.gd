class_name RunState
extends RefCounted
## All persistent run data (hero, pool, economy, position, board).

var class_id: String = "knight"
var seed: int = 0
var rng: Rng
var hp: int = 1
var max_hp: int = 1
var atk: int = 0
var block: int = 0
var gold: int = 0
var xp: int = 0
var level: int = 1
var dice: Array[Die] = []
var combat_rerolls: int = Balance.COMBAT_REROLLS
var board_rerolls: int = 1
var banked_rerolls: int = 0
var act: int = 1
var lap: int = 1
var pos: int = 0
var board: Board
## Ring size of every board in this run (24 or 32).
var board_size: int = Balance.BOARD_SIZE
var treasury: int = Balance.TREASURY_START
var stats: Dictionary = {}
## Extra: whether the +1 combat reroll shop item was bought this act.
var shop_reroll_bought: bool = false
## Owned passive ids (Passives.DEFS), in pickup order.
var passives: Array[String] = []
## Passive bookkeeping: second_wind_used:bool, phoenix_act:int (act the feather was spent in).
var passive_state: Dictionary = {}
## Biome per tier (BiomeDefs ids), picked at run start: [tier1, tier2, tier3].
var route: Array[String] = []
## Lap-7 mini-boss and lap-15 final boss, picked at run start from the route's candidates.
var miniboss_id: String = "mini_pumpkin_knight"
var boss_id: String = "boss_lich"
## Dice frozen by Frostpeak ice: they lock on turn 1 of the next fight.
var chill: int = 0
## Meta-layer run config (MetaRun.build; {} = legacy run without the meta layer).
var meta: Dictionary = {}
## Run mode: "standard" (15 laps, 3 biomes) or "short" (Short Road: 10 laps, 2 biomes, see
## Balance.SHORT_*). A short run's `route` has 2 entries: [tier-1 biome, second biome], the second
## drawn from tier 2 + tier 3 (docs/design/2026-09-29-new-biomes.md §6.2).
var mode: String = "standard"
## Potion belt: potion type ids carried (PotionDefs), belt size, and the count (== belt.size()).
var belt: Array[String] = []
var potion_cap: int = 0
var potions: int = 0
## Pet runtime: charge (meter pips, persists across fights), fights (won with the pet),
## boost (fights left with Bubble Breaker's +1 reroll), last_stand (used), lap_bonus (lap of the
## last Wisp board perk). All ints.
var pet_state: Dictionary = {}
## Board rerolls left in this lap's pool (Boots, Crystal Wisp perk); refilled on every lap.
var lap_rerolls: int = 0
## The Engineer's Turret die (outside the pool, not counted toward the cap); null otherwise.
var turret: Die = null
## Equipped skin (SkinDefs slot id) and the A10 prestige overlay: presentation only.
var skin: String = "default"
var skin_prestige: bool = false
## A7 biome curse: faces set to 1 until the next Forge visit: [{die, face, value}].
var cursed_faces: Array[Dictionary] = []
## Sunscorched Ruins: the lap in which the hero landed on an oasis (0 = none); that lap's heat is
## skipped.
var cooled_lap: int = 0
## The finale (after the Last Camp): every tile is a boss tile and the next board roll is the
## final roll into the boss fight (GameFlow._final_roll).
var finale: bool = false
## Armory item state across fights (ItemLogic): ambush (primed), dominion (stacks), soul (bonus),
## key_act (Skeleton Key's first chest), last_stand (used). All ints.
var item_state: Dictionary = {}

## opts (all optional, for scenarios/tests): route:[tier1, tier2, tier3], miniboss:id, boss:id.
## opts.mode: "standard" (default) | "short".
## opts.profile (a Profile.to_dict() snapshot) or opts.meta (a MetaRun.build() config) turns on
## the meta layer: gear, workshop, pet, potions, loadout minigame tiles, unlock pools, locked
## biomes/bosses, ascension.
## The route and bosses are always drawn from the run Rng first, so forcing them does not shift
## the rest of the random stream. Invalid overrides are ignored.
static func create(p_class_id: String, p_seed: int, p_board_size: int = Balance.BOARD_SIZE, opts: Dictionary = {}) -> RunState:
	var r := RunState.new()
	var def: Dictionary = HeroDefs.def(p_class_id)
	r.class_id = p_class_id
	r.seed = p_seed
	r.rng = Rng.new(p_seed)
	r.max_hp = int(def.hp)
	r.hp = r.max_hp
	r.atk = int(def.atk)
	r.board_rerolls = int(def.board_rerolls)
	r.combat_rerolls = int(HeroDefs.field(p_class_id, "combat_rerolls"))
	var kinds: Array = HeroDefs.field(p_class_id, "kinds")
	var tags: Array = HeroDefs.field(p_class_id, "tags")
	for k in (def.runes as Array).size():
		var die := Die.make(String(def.runes[k]), String(kinds[k]))
		die.add_tag(String(tags[k]))
		r.dice.append(die)
	if HeroDefs.mechanic(p_class_id) == "turret":
		r.turret = Die.make(String(HeroDefs.def(p_class_id).get("turret_rune", "")), "standard")
		r.turret.add_tag("turret")
	r.board_size = p_board_size
	r.mode = "short" if String(opts.get("mode", "standard")) == "short" else "standard"
	if opts.has("meta"):
		r.meta = MetaRun.normalize(opts.meta)
	elif opts.has("profile"):
		r.meta = MetaRun.build(opts.profile, p_class_id)
	if opts.has("ascension") and not r.meta.is_empty():
		# explicit ascension (0..MAX_ASCENSION) overrides the profile's selected level
		var asc := clampi(int(opts.ascension), 0, UnlockDefs.MAX_ASCENSION)
		r.meta.asc = asc
		r.meta.asc_keys = UnlockDefs.ascension_keys(asc)
		r.meta.potions = 0 if r.meta.asc_keys.has("potions") else mini(Balance.POTION_START, int(r.meta.potion_cap))
	if r.meta.is_empty():
		r.route = BiomeDefs.pick_route(r.rng)
	else:
		# One pick per tier among unlocked biomes (the same Rng draws as pick_route).
		for tier in BiomeDefs.TIERS:
			var ok: Array = []
			for b in tier:
				if (r.meta.biomes as Array).has(b):
					ok.append(b)
			r.route.append(String(r.rng.pick(ok if not ok.is_empty() else tier)))
	var forced: Array = opts.get("route", [])
	if BiomeDefs.valid_route(forced):
		r.route.assign(forced.map(func(x): return String(x)))
	if r.mode == "short":
		# Short Road: one extra draw for the second biome, uniform over the unlocked tier-2 and
		# tier-3 biomes. A forced 3-biome route keeps its tier-3 biome; a forced [t1, second] route
		# is used as is.
		var cands: Array = []
		for b in BiomeDefs.short_second_biomes():
			if r.meta.is_empty() or (r.meta.biomes as Array).has(b):
				cands.append(b)
		var second := String(r.rng.pick(cands if not cands.is_empty() else BiomeDefs.short_second_biomes()))
		if BiomeDefs.valid_route(forced):
			second = r.route[2]
		r.route = [r.route[0], second] as Array[String]
		if BiomeDefs.valid_short_route(forced):
			r.route.assign(forced.map(func(x): return String(x)))
	r.miniboss_id = String(r.rng.pick(_allowed(BiomeDefs.DEFS[r.route[1]].minibosses, r.meta.get("minibosses", []))))
	r.boss_id = String(r.rng.pick(_allowed(BiomeDefs.final_boss_candidates(r.route.back()), r.meta.get("bosses", []))))
	var fm := String(opts.get("miniboss", ""))
	if EnemyDefs.MINIBOSSES.has(fm):
		r.miniboss_id = fm
	var fb := String(opts.get("boss", ""))
	if EnemyDefs.BOSSES.has(fb):
		r.boss_id = fb
	MetaRun.apply_start(r)
	r.board = Board.generate(r.rng, 1, r.board_size, r.eff_lap(1), r.route[0])
	r.after_board_generated([])
	r.roll_board_affixes()
	r.stats = {
		"board_turns": 0, "combat_turns": 0, "fights_won": 0, "damage_dealt": 0, "damage_taken": 0,
		"gold_earned": 0, "best_combo": "", "best_mult": 0.0, "max_act": 1, "commands": 0,
	}
	return r

## `cands` filtered to `allowed` (unfiltered when allowed is empty or nothing matches).
static func _allowed(cands: Array, allowed: Array) -> Array:
	if allowed.is_empty():
		return cands
	var out: Array = []
	for c in cands:
		if allowed.has(c):
			out.append(c)
	return out if not out.is_empty() else cands

## Meta additions to a freshly generated board: A8 extra hazard tile, then one minigame tile
## per equipped minigame. No Rng use in legacy runs. Returns the changes.
func after_board_generated(protect: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if meta.is_empty():
		return out
	if has_asc("hazards"):
		var empties: Array[int] = []
		for i in board.size():
			if board.tiles[i].type == "empty" and not board.is_corner(i) and not protect.has(i) and i > 2:
				empties.append(i)
		if not empties.is_empty():
			var idx: int = rng.pick(empties)
			board.tiles[idx] = Board.make_tile(String(BiomeDefs.DEFS[board.biome].get("trap_tile", "trap")) if BiomeDefs.has(board.biome) else "trap")
			out.append(board.change(idx))
	out.append_array(place_minigames(protect))
	return out

# ------------------------------------------------------------------ affixes

## "" (affixes off), "on" or "force:<id>" (sim). Meta runs turn them on with the `affixes`
## feature (the brawler milestone); legacy runs never have them.
func affix_mode() -> String:
	if AffixDefs.sim_mode == "off":
		return ""
	if AffixDefs.sim_mode != "":
		return AffixDefs.sim_mode
	return "on" if bool(meta.get("affixes", false)) else ""

## Rolls the affixes of tile idx's enemies (derived Rng: the run stream is never touched).
## The mini-boss tile gets one biome affix at A4+ (whatever the affix mode).
func roll_affixes(idx: int) -> void:
	var t: Dictionary = board.tiles[idx]
	t.erase("enemy_affixes")
	var ids: Array = t.enemies
	if ids.is_empty():
		return
	var rng := Rng.new(hash([seed, "affix", lap, idx, ids]))
	var out: Array = []
	if String(t.type) == "miniboss":
		if has_asc("miniboss_trait"):
			out = [AffixDefs.roll_miniboss(rng, String(ids[0]), board.biome)]
	else:
		var mode := affix_mode()
		if mode == "":
			return
		out = AffixDefs.roll_tile(rng, ids, board.biome, EnemyDefs.band(eff_lap()), bool(t.elite), mode)
	for a in out:
		if not (a as Array).is_empty():
			t["enemy_affixes"] = out
			return

func roll_board_affixes() -> void:
	for i in board.size():
		roll_affixes(i)

## Rolls affixes for the tiles in board `changes` and writes them into each change's `affixes`.
func roll_change_affixes(changes: Array) -> void:
	for c in changes:
		var idx := int(c.idx)
		if not (board.tiles[idx].enemies as Array).is_empty():
			roll_affixes(idx)
			c["affixes"] = board.affixes_of(idx)

# ------------------------------------------------------------------ mode helpers

func total_laps() -> int:
	return Balance.SHORT_LAPS if mode == "short" else Balance.TOTAL_LAPS

func biome_laps() -> Array:
	return Balance.SHORT_BIOME_LAPS if mode == "short" else Balance.BIOME_LAPS

func miniboss_lap() -> int:
	return Balance.SHORT_MINIBOSS_LAP if mode == "short" else Balance.MINIBOSS_LAP

## Act (biome index, 1-based) for a lap in this run's mode.
func act_for_lap(l: int) -> int:
	var a := 1
	var bl := biome_laps()
	for k in bl.size():
		if l >= int(bl[k]):
			a = k + 1
	return a

func is_shop_lap(completed_lap: int) -> bool:
	if Balance.tune_shop != "":
		return Array(Balance.tune_shop.split(",")).has(str(completed_lap))
	return (Balance.SHOP_LAPS_SHORT if mode == "short" else Balance.SHOP_LAPS).has(completed_lap)

## The lap whose completion opens the Last Camp (the second-to-last lap; 0 = camp off).
func camp_lap() -> int:
	return total_laps() - 1 if Balance.camp_on else 0

func is_camp_lap(completed_lap: int) -> bool:
	return camp_lap() > 0 and completed_lap == camp_lap()

## The Last Camp's heal share of max HP (A2+ "lap_heal": smaller).
func camp_heal_pct() -> float:
	return Balance.camp_asc_heal if has_asc("lap_heal") else Balance.camp_heal

## The standard-run lap of equal difficulty (enemy scaling, pools, gold). == lap in standard.
func eff_lap(l: int = -1) -> int:
	var x := lap if l < 0 else l
	if mode != "short":
		return x
	return int(Balance.SHORT_EFF_LAPS[clampi(x, 1, Balance.SHORT_LAPS) - 1])

# ------------------------------------------------------------------ meta helpers

## Minigame ids equipped for this run (empty in legacy runs).
func loadout() -> Array:
	return meta.get("minigames", [])

## One minigame tile per equipped minigame that has none on the board (on random Empty,
## non-corner tiles outside `protect`). No Rng use with an empty loadout.
func place_minigames(protect: Array = []) -> Array[Dictionary]:
	var lo := loadout()
	if lo.is_empty():
		return []
	return board.place_minigames(rng, lo, protect)

## Unlocked pool for "runes" | "kinds" | "passives" (empty = everything, legacy runs).
func pool(kind: String) -> Array:
	return (meta.get("pools", {}) as Dictionary).get(kind, [])

func pet_id() -> String:
	return String((meta.get("pet", {}) as Dictionary).get("id", ""))

func pet_level() -> int:
	return int((meta.get("pet", {}) as Dictionary).get("level", 0))

func has_pet(id: String) -> bool:
	return pet_id() == id

## True when ascension rule `key` (UnlockDefs.ASCENSION) is active.
func has_asc(key: String) -> bool:
	return (meta.get("asc_keys", []) as Array).has(key)

## Legacy (profile v2) gear traits: always false since the Armory items replaced them (kept so
## old callers compile; old saves map their traits to items in MetaRun.normalize).
func has_trait(_id: String) -> bool:
	return false

## The equipped Armory item of a slot: {id, variant, tier} ({} = empty or inactive).
func item(slot: String) -> Dictionary:
	return (meta.get("items", {}) as Dictionary).get(slot, {})

func lap_heal_pct() -> float:
	if meta.is_empty():
		return Balance.LAP_HEAL_PCT
	var p := UnlockDefs.ASC_LAP_HEAL if has_asc("lap_heal") else Balance.LAP_HEAL_PCT
	return p + ItemLogic.lap_heal_pct(self)

func potion_pct() -> float:
	return (UnlockDefs.ASC_POTION_HEAL if has_asc("potions") else Balance.POTION_HEAL_PCT) + ItemLogic.potion_heal_bonus(self)

## Damage multiplier for traps and lava (Boots, A8).
func hazard_mult() -> float:
	var m := float(meta.get("hazard_mult", 1.0))
	if has_asc("hazards"):
		m *= UnlockDefs.ASC_HAZARD_MULT
	return m

## Gold from fights, chests and minigames with the Charm bonus (legacy: unchanged).
func gold_bonus(amount: int) -> int:
	var p := float(meta.get("gold_pct", 0.0))
	if p <= 0.0 or amount <= 0:
		return amount
	return int(round(amount * (1.0 + p)))

## Board reroll pool refill when a lap starts. The Compass's reroll (meta.lap_rerolls) refills
## only when a new biome starts (from the 2nd biome: MetaRun.apply_start starts the pool empty);
## unused Compass rerolls carry over within the biome. The Crystal Wisp perk adds +1 for each lap
## (lost if unused).
func lap_reroll_refill(new_biome := true) -> int:
	var boots := int(meta.get("lap_rerolls", 0))
	var kept := boots if new_biome else mini(lap_rerolls, boots)
	return kept + (1 if has_pet("crystal_wisp") else 0)

## Syncs the potion count with the belt.
func sync_potions() -> void:
	potions = belt.size()

func has_passive(id: String) -> bool:
	return passives.has(id)

## Current biome id (the route's entry for the current act).
func biome() -> String:
	return route[clampi(act - 1, 0, route.size() - 1)]

# ------------------------------------------------------------------ new-biome twists

## The current biome's active twist ("ore", "drums", "moon", "heat"; "" = none).
func twist() -> String:
	return BiomeDefs.twist_of(board.biome if board != null else biome())

## Lap `l`'s position in its biome (1..5).
func biome_lap_pos(l: int = -1) -> int:
	var x := lap if l < 0 else l
	var bl := biome_laps()
	return x - int(bl[act_for_lap(x) - 1]) + 1

## Moonlit Woods phase of lap `l` ("crescent", "half", "full"; "" outside an active Moonlit
## biome). Derived from the lap and route; no state.
func moon_phase(l: int = -1) -> String:
	var x := lap if l < 0 else l
	var b := route[clampi(act_for_lap(x) - 1, 0, route.size() - 1)]
	if BiomeDefs.twist_of(b) != "moon":
		return ""
	var ph: Array = BiomeDefs.MOON_PHASES
	return String(ph[clampi(biome_lap_pos(x) - 1, 0, ph.size() - 1)])

## Laps until the Full moon (0 on the Full lap, -1 when it has passed or outside Moonlit).
func laps_to_full_moon() -> int:
	if moon_phase() == "":
		return -1
	var d := BiomeDefs.MOON_PHASES.find("full") + 1 - biome_lap_pos()
	return d if d >= 0 else -1

## Final-boss candidates of this run (tier-3 bosses, a tier-2 Short Road biome's short_bosses).
func boss_candidates() -> Array:
	return BiomeDefs.final_boss_candidates(route.back())

## Pool cap: MAX_DICE, +1 with Extra Hand.
func max_dice() -> int:
	return Balance.MAX_DICE + (1 if has_passive("extra_hand") else 0)

## Called when a hit would drop HP to 0 or below: Phoenix Feather (once per act) then Second
## Wind (once per run) leave the hero at 1 HP, then the Round Shield III's Last Stand (once per run,
## only if HP before the hit was above 50%: pass it as `hp_before`). Returns the passive or
## trait that saved them, or "".
func survive_lethal(hp_before := -1) -> String:
	if has_passive("phoenix") and int(passive_state.get("phoenix_act", 0)) != act:
		passive_state["phoenix_act"] = act
		hp = 1
		return "phoenix"
	if has_passive("second_wind") and not bool(passive_state.get("second_wind_used", false)):
		passive_state["second_wind_used"] = true
		hp = 1
		return "second_wind"
	if ItemLogic.last_stand(self) and int(pet_state.get("last_stand", 0)) == 0 and hp_before * 2 > max_hp:
		pet_state["last_stand"] = 1
		hp = 1
		return "last_stand"
	return ""

## Heals up to max; returns the amount actually healed.
func heal(amount: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + maxi(0, amount))
	return hp - before

func pct_of_max(p: float) -> int:
	return maxi(1, int(round(max_hp * p)))

func dice_with_rune(rune_id: String) -> Array[int]:
	var out: Array[int] = []
	for i in dice.size():
		if dice[i].rune == rune_id:
			out.append(i)
	return out

func to_dict() -> Dictionary:
	var dd: Array = []
	for d in dice:
		dd.append(d.to_dict())
	return {
		"class_id": class_id, "seed": str(seed), "rng": rng.to_dict(), "hp": hp, "max_hp": max_hp,
		"atk": atk, "block": block, "gold": gold, "xp": xp, "level": level, "dice": dd,
		"combat_rerolls": combat_rerolls, "board_rerolls": board_rerolls, "banked_rerolls": banked_rerolls,
		"act": act, "lap": lap, "pos": pos, "board": board.to_dict(), "board_size": board_size, "treasury": treasury,
		"stats": stats.duplicate(true), "shop_reroll_bought": shop_reroll_bought,
		"passives": Array(passives), "passive_state": passive_state.duplicate(true),
		"route": Array(route), "miniboss_id": miniboss_id, "boss_id": boss_id, "chill": chill,
		"meta": meta.duplicate(true), "mode": mode, "belt": Array(belt), "potions": potions, "potion_cap": potion_cap,
		"pet_state": pet_state.duplicate(true), "lap_rerolls": lap_rerolls, "cursed_faces": cursed_faces.duplicate(true),
		"cooled_lap": cooled_lap, "item_state": item_state.duplicate(true), "finale": finale,
		"skin": skin, "skin_prestige": skin_prestige, "turret": turret.to_dict() if turret != null else null,
	}

static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new()
	r.class_id = String(d.class_id)
	r.seed = String(d.seed).to_int()
	r.rng = Rng.from_dict(d.rng)
	for k in ["hp", "max_hp", "atk", "block", "gold", "xp", "level", "combat_rerolls", "board_rerolls",
			"banked_rerolls", "act", "lap", "pos", "treasury"]:
		r.set(k, int(d[k]))
	r.dice.clear()
	for dd in d.dice:
		r.dice.append(Die.from_dict(dd))
	r.board = Board.from_dict(d.board)
	r.board_size = int(d.get("board_size", r.board.size()))
	r.stats = {}
	var st: Dictionary = d.get("stats", {})
	for k in st:
		var v: Variant = st[k]
		if k == "best_mult":
			r.stats[k] = float(v)
		elif v is float:
			r.stats[k] = int(v)
		elif v is Dictionary:
			var m := {}
			for mk in v:
				m[String(mk)] = int(v[mk])
			r.stats[k] = m
		else:
			r.stats[k] = v
	r.shop_reroll_bought = bool(d.get("shop_reroll_bought", false))
	for p in d.get("passives", []):
		r.passives.append(String(p))
	# Saves from before biome routes get the legacy route and bosses.
	r.route.clear()
	for b in d.get("route", BiomeDefs.DEFAULT_ROUTE):
		r.route.append(String(b))
	r.miniboss_id = String(d.get("miniboss_id", "mini_pumpkin_knight"))
	r.boss_id = String(d.get("boss_id", EnemyDefs.FINAL_BOSS))
	r.chill = int(d.get("chill", 0))
	r.meta = MetaRun.normalize(d.get("meta", {}))
	r.mode = String(d.get("mode", "standard"))
	for b in d.get("belt", []):
		r.belt.append(String(b))
	r.sync_potions()
	r.potion_cap = int(d.get("potion_cap", 0))
	r.lap_rerolls = int(d.get("lap_rerolls", 0))
	r.cooled_lap = int(d.get("cooled_lap", 0))
	r.finale = bool(d.get("finale", false))
	var ist: Dictionary = d.get("item_state", {})
	for k in ist:
		r.item_state[String(k)] = int(ist[k])
	r.skin = String(d.get("skin", "default"))
	if d.get("turret") != null:
		r.turret = Die.from_dict(d.turret)
	r.skin_prestige = bool(d.get("skin_prestige", false))
	for c in d.get("cursed_faces", []):
		r.cursed_faces.append({"die": int(c.die), "face": int(c.face), "value": int(c.value)})
	var pst: Dictionary = d.get("pet_state", {})
	for k in pst:
		r.pet_state[k] = int(pst[k])
	var ps: Dictionary = d.get("passive_state", {})
	for k in ps:
		var v: Variant = ps[k]
		r.passive_state[k] = int(v) if v is float else v
	return r
