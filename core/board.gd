class_name Board
extends RefCounted
## Ring board: the perimeter of an n x n grid, ring size 4(n-1). Supported sizes: 24 (7x7)
## and 32 (9x9); any 4(n-1) with n >= 5 works with proportionally scaled tile counts.
## Tile 0 is Start; the other corners (n-1, 2(n-1), 3(n-1)) are Forge, Treasury and Portal.
## Each tile: {type, enemies:Array[String], elite:bool} (+ enemy_affixes: [[ids] per enemy] when
## any enemy has an affix; see AffixDefs and RunState.roll_affixes). Types: start forge treasury portal enemy
## elite miniboss chest event campfire trap empty, plus biome tiles ice (Frostpeak traps) and
## lava (Magma Depths), the new-biome tiles ore (Deep Mines), drum (Orc Warcamp) and oasis
## (Sunscorched Ruins), a chest may carry moon:true (the Moonlit Woods' Full-moon rune chest), and
## meta-layer minigame tiles ({type:"minigame", game:<minigame id>}).
## Presentation lays the ring out with side()/size()/corners(); tile i walks clockwise from Start. `biome` ("" = none) sets the tile mix and the enemy roster.

const CORNER_TYPES := ["start", "forge", "treasury", "portal"]
## Edge tile counts per ring size. Mutation spawns MUTATE per lap and tops events back up to
## LAYOUTS[size].event.
const LAYOUTS := {
	24: {"enemy": 6, "chest": 3, "event": 3, "campfire": 2, "trap": 2, "empty": 4},
	28: {"enemy": 7, "chest": 4, "event": 4, "campfire": 2, "trap": 2, "empty": 5},
	32: {"enemy": 8, "chest": 4, "event": 4, "campfire": 3, "trap": 3, "empty": 6},
}
const MUTATE := {
	24: ["enemy", "enemy", "elite"],
	28: ["enemy", "enemy", "elite"],
	32: ["enemy", "enemy", "enemy", "elite"],
}

var tiles: Array[Dictionary] = []
## Biome id (BiomeDefs) this board was generated for; "" = the legacy mix and band pools.
var biome: String = ""
## Effective lap at which this board's biome started for pool purposes (-1 = its tier's first
## lap, BiomeDefs tier -> Balance.BIOME_LAPS). The Short Road's second biome starts at eff lap 7.
var first_lap: int = -1

static func make_tile(type: String, enemies: Array = [], elite: bool = false) -> Dictionary:
	return {"type": type, "enemies": enemies.duplicate(), "elite": elite}

# ---------------------------------------------------------------- geometry

## Grid side length n for a ring of `ring_size` tiles.
static func side_for(ring_size: int) -> int:
	return ring_size / 4 + 1

## {tile index: corner type} for a ring of `ring_size` tiles.
static func corners_for(ring_size: int) -> Dictionary:
	var q := ring_size / 4
	return {0: "start", q: "forge", 2 * q: "treasury", 3 * q: "portal"}

func size() -> int:
	return tiles.size()

func side() -> int:
	return side_for(size())

func corners() -> Dictionary:
	return corners_for(size())

func is_corner(idx: int) -> bool:
	return size() >= 4 and idx % (size() / 4) == 0

## Portal reach: a third of the ring (8 on 24, 10 on 32).
func portal_range() -> int:
	return size() / 3

## Edge tile counts for a ring size (table for 24/28/32, proportional otherwise), with the
## biome's mix deltas applied (Empty absorbs the difference; traps become the biome's trap tile).
static func layout_for(ring_size: int, p_biome := "") -> Dictionary:
	var base := _base_layout(ring_size)
	if not BiomeDefs.has(p_biome):
		return base
	var def: Dictionary = BiomeDefs.DEFS[p_biome]
	var out := {}
	for type in base:
		out[type] = int(base[type])
	var mix: Dictionary = def.get("mix", {})
	for type in mix:
		out[type] = maxi(0, int(out.get(type, 0)) + int(mix[type]))
	# a switched-off twist (sim --twist=off) leaves its tiles Empty
	var tt := String(BiomeDefs.TWIST_TILES.get(String(def.get("twist", "")), ""))
	if tt != "" and BiomeDefs.twist_of(p_biome) == "":
		out.erase(tt)
	var trap_tile := String(def.get("trap_tile", "trap"))
	if trap_tile != "trap":
		out[trap_tile] = int(out.get(trap_tile, 0)) + int(out.get("trap", 0))
		out["trap"] = 0
	var used := 0
	for type in out:
		if type != "empty":
			used += int(out[type])
	out["empty"] = maxi(0, ring_size - 4 - used)
	return out

static func _base_layout(ring_size: int) -> Dictionary:
	if LAYOUTS.has(ring_size):
		return LAYOUTS[ring_size]
	var base: Dictionary = LAYOUTS[24]
	var edge := ring_size - 4
	var out := {}
	var used := 0
	for type in base:
		if type == "empty":
			continue
		out[type] = int(round(float(base[type]) * edge / 20.0))
		used += int(out[type])
	out["empty"] = maxi(0, edge - used)
	return out

static func mutate_spawns_for(ring_size: int, p_biome := "") -> Array:
	var out: Array = []
	if MUTATE.has(ring_size):
		out = (MUTATE[ring_size] as Array).duplicate()
	else:
		for i in maxi(1, int(round(2.0 * (ring_size - 4) / 20.0))):
			out.append("enemy")
		out.append("elite")
	if BiomeDefs.has(p_biome):
		for k in int(BiomeDefs.DEFS[p_biome].get("mutate_elites", 0)):
			var e := out.find("enemy")
			if e >= 0:
				out[e] = "elite"
	return out

# ---------------------------------------------------------------- generation

## act >= 2 swaps one Enemy for an Elite; `lap` sets the enemy band on the new tiles.
## `p_biome` ("" = legacy) sets the tile mix and the enemy roster.
## `p_first` (optional): see first_lap.
static func generate(rng: Rng, act: int, ring_size: int = Balance.BOARD_SIZE, lap: int = 1, p_biome := "", p_first := -1) -> Board:
	assert(ring_size % 4 == 0 and ring_size >= 16, "ring size must be 4(n-1)")
	var b := Board.new()
	b.biome = p_biome if BiomeDefs.has(p_biome) else ""
	b.first_lap = p_first
	var bag: Array[String] = []
	var layout := layout_for(ring_size, b.biome)
	for type in layout:
		for i in layout[type]:
			bag.append(type)
	if act >= 2 and bag.has("enemy"):
		bag.erase("enemy")
		bag.append("elite")
	# shuffle, then swap fights (and drums / ore) out of tiles 1 and 2 (deterministic and fast)
	rng.shuffle(bag)
	var corner_map := corners_for(ring_size)
	var edge: Array[int] = []
	for i in ring_size:
		if not corner_map.has(i):
			edge.append(i)
	# edge[0], edge[1] are tiles 1 and 2
	for slot in [0, 1]:
		if _is_fight(bag[slot]) or NOT_NEAR_START.has(bag[slot]):
			for j in range(2, bag.size()):
				if not _is_fight(bag[j]) and not NOT_NEAR_START.has(bag[j]):
					var t := bag[slot]
					bag[slot] = bag[j]
					bag[j] = t
					break
	b.tiles.resize(ring_size)
	for i in corner_map:
		b.tiles[i] = make_tile(corner_map[i])
	for k in edge.size():
		var type := bag[k]
		b.tiles[edge[k]] = _spawn(rng, type, act, lap, b.biome, b.first_lap)
	return b

## Tile types that never sit on tiles 1 and 2 (besides fights).
const NOT_NEAR_START := ["drum", "ore"]

static func _is_fight(type: String) -> bool:
	return type == "enemy" or type == "elite" or type == "miniboss"

static func _spawn(rng: Rng, type: String, act: int, lap: int, p_biome := "", p_first := -1) -> Dictionary:
	if type == "enemy":
		return make_tile("enemy", roll_enemies(rng, act, lap, false, p_biome, p_first))
	if type == "elite":
		return make_tile("elite", roll_enemies(rng, act, lap, true, p_biome, p_first), true)
	return make_tile(type)

## Regular enemy pool for a lap: the biome's early pool for the first 3 laps of its tier, its
## late pool after; the legacy band pools without a biome. `p_first` (>= 0) overrides the tier's
## first lap (the Short Road's second biome).
static func enemy_pool(lap: int, p_biome := "", p_first := -1) -> Array:
	if not BiomeDefs.has(p_biome):
		return EnemyDefs.POOLS[EnemyDefs.band(lap)]
	var def: Dictionary = BiomeDefs.DEFS[p_biome]
	var first := p_first if p_first >= 0 else int(Balance.BIOME_LAPS[int(def.tier) - 1])
	return def.pools[0] if lap - first < 3 else def.pools[1]

static func roll_enemies(rng: Rng, act: int, lap: int, elite: bool, p_biome := "", p_first := -1) -> Array[String]:
	var band := EnemyDefs.band(lap)
	var pool: Array = enemy_pool(lap, p_biome, p_first)
	var out: Array[String] = []
	if elite:
		out.append(String(BiomeDefs.DEFS[p_biome].elite) if BiomeDefs.has(p_biome) else "brute")
		if band >= 2:
			out.append(String(rng.pick(pool)))
		return out
	var range_: Array = EnemyDefs.COUNTS[band]
	var n := rng.randi_range(range_[0], range_[1])
	for i in n:
		out.append(String(rng.pick(pool)))
	return out

## Tile index after moving `steps` from `pos` (0 steps = stay).
func landing(pos: int, steps: int) -> int:
	return (pos + steps) % size()

## Tiles visited in order, excluding the starting tile (empty for 0 steps).
func path(pos: int, steps: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(1, steps + 1):
		out.append((pos + i) % size())
	return out

## True if moving passes or lands on Start.
func crosses_start(pos: int, steps: int) -> bool:
	return steps > 0 and pos + steps >= size()

func portal_targets(pos: int) -> Array[int]:
	return path(pos, portal_range())

func clear_enemies(idx: int) -> void:
	tiles[idx]["enemies"] = []
	tiles[idx].erase("enemy_affixes")
	tiles[idx]["cleared"] = true

## First `n` tiles of `type` strictly ahead of `pos` (not wrapping past Start twice).
func next_of_type(pos: int, type: String, n: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(1, size()):
		var idx := (pos + i) % size()
		if tiles[idx].type == type and not is_corner(idx):
			out.append(idx)
			if out.size() >= n:
				break
	return out

func set_tile(idx: int, type: String, rng: Rng, act: int, lap: int) -> Dictionary:
	tiles[idx] = _spawn(rng, type, act, lap, biome, first_lap)
	return change(idx)

func change(idx: int) -> Dictionary:
	var c := {"idx": idx, "type": tiles[idx].type, "enemies": tiles[idx].enemies.duplicate(), "elite": tiles[idx].elite}
	# affixes: parallel to enemies ([] per enemy without one); present on every tile with enemies
	if not tiles[idx].enemies.is_empty():
		c["affixes"] = affixes_of(idx)
	if tiles[idx].has("game"):
		c["game"] = String(tiles[idx].game)
	if tiles[idx].get("moon", false):
		c["moon"] = true
	return c

## Lap mutation: cleared fight tiles become Empty, then mutate_spawns_for(size) (24: +2 Enemy
## +1 Elite; 32: +3 Enemy +1 Elite) go on random Empty tiles, then events are topped back up
## to the layout's event count. `protect` tiles are never changed.
func mutate(rng: Rng, act: int, lap: int, protect: Array = [], extra: Array = []) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for i in size():
		if _is_fight(tiles[i].type) and tiles[i].get("cleared", false):
			tiles[i] = make_tile("empty")
			changes.append(change(i))
	var empties: Array[int] = []
	for i in size():
		if tiles[i].type == "empty" and not protect.has(i):
			empties.append(i)
	rng.shuffle(empties)
	var spawns: Array[String] = []
	spawns.assign(mutate_spawns_for(size(), biome))
	for x in extra:
		spawns.append(String(x))
	var events := 0
	for t in tiles:
		if t.type == "event":
			events += 1
	for k in range(events, int(layout_for(size(), biome).event)):
		spawns.append("event")
	# biome refill (Deep Mines ore), unless the trap cap is reached
	if BiomeDefs.has(biome) and BiomeDefs.twist_of(biome) != "":
		var refill: Dictionary = BiomeDefs.DEFS[biome].get("refill", {})
		for type in refill:
			if type == "ore" and count(trap_type()) >= BiomeDefs.MINES_TRAP_CAP:
				continue
			for k in range(count(String(type)), int(refill[type])):
				spawns.append(String(type))
	for type in spawns:
		if empties.is_empty():
			break
		var idx: int = empties.pop_back()
		if NOT_NEAR_START.has(type) and idx <= 2:
			# drums and ore never go on tiles 1 and 2: take another Empty tile if there is one
			var alt := -1
			for e in range(empties.size() - 1, -1, -1):
				if empties[e] > 2:
					alt = e
					break
			if alt < 0:
				empties.push_back(idx)
				continue
			var j: int = empties[alt]
			empties[alt] = idx
			idx = j
		set_tile(idx, type, rng, act, lap)
		# replace an earlier change entry for the same tile
		for c in range(changes.size() - 1, -1, -1):
			if changes[c].idx == idx:
				changes.remove_at(c)
		changes.append(change(idx))
	return changes

## One minigame tile ({type:"minigame", game:<id>}) for each id in `games` that has none on the
## board, on random Empty, non-corner tiles outside `protect` (tiles 1 and 2 stay free).
## Returns the changes. No Rng use when every game already has a tile.
func place_minigames(rng: Rng, games: Array, protect: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var missing: Array = []
	for g in games:
		var found := false
		for t in tiles:
			if t.type == "minigame" and String(t.get("game", "")) == String(g):
				found = true
				break
		if not found:
			missing.append(String(g))
	if missing.is_empty():
		return out
	var empties: Array[int] = []
	for i in size():
		if tiles[i].type == "empty" and not is_corner(i) and not protect.has(i) and i > 2:
			empties.append(i)
	rng.shuffle(empties)
	for g in missing:
		if empties.is_empty():
			break
		var idx: int = empties.pop_back()
		tiles[idx] = make_tile("minigame")
		tiles[idx]["game"] = String(g)
		out.append(change(idx))
	return out

## Turns one Empty or uncleared Enemy tile into the act's mini-boss tile. The tile is not a
## corner, not in `protect`, and more than 3 tiles (either way round) from `hero_pos`.
## Returns the change, or {} when no tile qualifies.
func spawn_miniboss(rng: Rng, id: String, hero_pos: int, protect: Array = []) -> Dictionary:
	var n := size()
	var cands: Array[int] = []
	for i in n:
		var d := (i - hero_pos + n) % n
		if mini(d, n - d) <= 3 or is_corner(i) or protect.has(i):
			continue
		var t: Dictionary = tiles[i]
		if t.type == "empty" or (t.type == "enemy" and not t.get("cleared", false)):
			cands.append(i)
	if cands.is_empty():
		return {}
	var idx: int = rng.pick(cands)
	tiles[idx] = make_tile("miniboss", [id])
	return change(idx)

## Removes any undefeated mini-boss (the act boss is starting). Returns the changes.
func remove_minibosses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in size():
		if tiles[i].type == "miniboss":
			tiles[i] = make_tile("empty")
			out.append(change(i))
	return out

# ---------------------------------------------------------------- new-biome helpers

## Number of tiles of `type` on the board.
func count(type: String) -> int:
	var n := 0
	for t in tiles:
		if String(t.type) == type:
			n += 1
	return n

## The tile type this biome's traps use ("trap", Frostpeak "ice").
func trap_type() -> String:
	return String(BiomeDefs.DEFS[biome].get("trap_tile", "trap")) if BiomeDefs.has(biome) else "trap"

## Turns tile idx into a plain tile of `type` (no enemies). Returns the change.
func set_type(idx: int, type: String) -> Dictionary:
	tiles[idx] = make_tile(type)
	return change(idx)

## Orc Warcamp rebuild: one drum on a random Empty, non-corner tile more than 3 tiles (either way
## round) from `hero_pos`, never tiles 1-2 or `protect`. Returns the change ({} when none fits).
func rebuild_drum(rng: Rng, hero_pos: int, protect: Array = []) -> Dictionary:
	var n := size()
	var cands: Array[int] = []
	for i in n:
		var d := (i - hero_pos + n) % n
		if mini(d, n - d) <= 3 or is_corner(i) or protect.has(i) or i <= 2:
			continue
		if String(tiles[i].type) == "empty":
			cands.append(i)
	if cands.is_empty():
		return {}
	return set_type(int(rng.pick(cands)), "drum")

## Moonlit Woods Full-moon rune chest: the first Empty tile 3 to 8 tiles ahead of `hero_pos`, else
## the nearest Empty tile anywhere ahead, else the nearest Event tile ahead. `protect` tiles are
## skipped. Returns the change (with moon:true), or {} when nothing qualifies.
func place_moon_chest(hero_pos: int, protect: Array = []) -> Dictionary:
	var n := size()
	var pick := -1
	var lo := int(BiomeDefs.MOON_CHEST_AHEAD[0])
	var hi := int(BiomeDefs.MOON_CHEST_AHEAD[1])
	for pass_ in 3:
		for d in range(1, n):
			var i := (hero_pos + d) % n
			if is_corner(i) or protect.has(i):
				continue
			var ty := String(tiles[i].type)
			if pass_ == 0 and ty == "empty" and d >= lo and d <= hi:
				pick = i
			elif pass_ == 1 and ty == "empty":
				pick = i
			elif pass_ == 2 and ty == "event":
				pick = i
			if pick >= 0:
				break
		if pick >= 0:
			break
	if pick < 0:
		return {}
	tiles[pick] = make_tile("chest")
	tiles[pick]["moon"] = true
	return change(pick)

## Affixes of tile idx's enemies: one array per enemy (AffixDefs ids; [] = none).
func affixes_of(idx: int) -> Array:
	var t: Dictionary = tiles[idx]
	var a: Array = t.get("enemy_affixes", [])
	var out: Array = []
	for k in (t.enemies as Array).size():
		out.append((a[k] as Array).duplicate() if k < a.size() else [])
	return out

func to_dict() -> Dictionary:
	var t: Array = []
	for tile in tiles:
		var d := {"type": tile.type, "enemies": Array(tile.enemies).duplicate(), "elite": bool(tile.elite)}
		if tile.has("enemy_affixes"):
			d["enemy_affixes"] = (tile.enemy_affixes as Array).duplicate(true)
		if tile.get("cleared", false):
			d["cleared"] = true
		if tile.has("game"):
			d["game"] = String(tile.game)
		if tile.get("moon", false):
			d["moon"] = true
		t.append(d)
	var out := {"tiles": t, "size": size(), "side": side(), "biome": biome}
	if first_lap >= 0:
		out["first_lap"] = first_lap
	return out

static func from_dict(d: Dictionary) -> Board:
	var b := Board.new()
	b.biome = String(d.get("biome", ""))
	b.first_lap = int(d.get("first_lap", -1))
	for td in d.get("tiles", []):
		var enemies: Array = []
		for e in td.get("enemies", []):
			enemies.append(String(e))
		var tile := make_tile(String(td.type), enemies, bool(td.get("elite", false)))
		if td.get("cleared", false):
			tile["cleared"] = true
		if td.has("game"):
			tile["game"] = String(td.game)
		if td.get("moon", false):
			tile["moon"] = true
		if td.has("enemy_affixes"):
			var ea: Array = []
			for lst in td.enemy_affixes:
				var one: Array = []
				for x in lst:
					one.append(String(x))
				ea.append(one)
			tile["enemy_affixes"] = ea
		b.tiles.append(tile)
	return b
