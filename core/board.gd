class_name Board
extends RefCounted
## Ring board: the perimeter of an n x n grid, ring size 4(n-1). Supported sizes: 24 (7x7)
## and 32 (9x9); any 4(n-1) with n >= 5 works with proportionally scaled tile counts.
## Tile 0 is Start; the other corners (n-1, 2(n-1), 3(n-1)) are Forge, Treasury and Portal.
## Each tile: {type, enemies:Array[String], elite:bool}. Types: start forge treasury portal enemy
## elite miniboss chest event campfire trap empty. Presentation lays the ring out with
## side()/size()/corners(); tile i walks clockwise from Start.

const CORNER_TYPES := ["start", "forge", "treasury", "portal"]
## Edge tile counts per ring size. Mutation spawns MUTATE per lap and tops events back up to
## LAYOUTS[size].event.
const LAYOUTS := {
	24: {"enemy": 6, "chest": 3, "event": 3, "campfire": 2, "trap": 2, "empty": 4},
	32: {"enemy": 8, "chest": 4, "event": 4, "campfire": 3, "trap": 3, "empty": 6},
}
const MUTATE := {
	24: ["enemy", "enemy", "elite"],
	32: ["enemy", "enemy", "enemy", "elite"],
}

var tiles: Array[Dictionary] = []

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

## Edge tile counts for a ring size (table for 24/32, proportional otherwise).
static func layout_for(ring_size: int) -> Dictionary:
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

static func mutate_spawns_for(ring_size: int) -> Array:
	if MUTATE.has(ring_size):
		return MUTATE[ring_size]
	var out: Array = []
	for i in maxi(1, int(round(2.0 * (ring_size - 4) / 20.0))):
		out.append("enemy")
	out.append("elite")
	return out

# ---------------------------------------------------------------- generation

static func generate(rng: Rng, act: int, ring_size: int = Balance.BOARD_SIZE) -> Board:
	assert(ring_size % 4 == 0 and ring_size >= 16, "ring size must be 4(n-1)")
	var b := Board.new()
	var bag: Array[String] = []
	var layout := layout_for(ring_size)
	for type in layout:
		for i in layout[type]:
			bag.append(type)
	if act >= 2:
		bag.erase("enemy")
		bag.append("elite")
	# shuffle, then swap fights out of tiles 1 and 2 (deterministic and fast)
	rng.shuffle(bag)
	var corner_map := corners_for(ring_size)
	var edge: Array[int] = []
	for i in ring_size:
		if not corner_map.has(i):
			edge.append(i)
	# edge[0], edge[1] are tiles 1 and 2
	for slot in [0, 1]:
		if _is_fight(bag[slot]):
			for j in range(2, bag.size()):
				if not _is_fight(bag[j]):
					var t := bag[slot]
					bag[slot] = bag[j]
					bag[j] = t
					break
	b.tiles.resize(ring_size)
	for i in corner_map:
		b.tiles[i] = make_tile(corner_map[i])
	for k in edge.size():
		var type := bag[k]
		b.tiles[edge[k]] = _spawn(rng, type, act, 1)
	return b

static func _is_fight(type: String) -> bool:
	return type == "enemy" or type == "elite" or type == "miniboss"

static func _spawn(rng: Rng, type: String, act: int, lap: int) -> Dictionary:
	if type == "enemy":
		return make_tile("enemy", roll_enemies(rng, act, lap, false))
	if type == "elite":
		return make_tile("elite", roll_enemies(rng, act, lap, true), true)
	return make_tile(type)

static func roll_enemies(rng: Rng, act: int, lap: int, elite: bool) -> Array[String]:
	var band := EnemyDefs.band(act, lap)
	var pool: Array = EnemyDefs.POOLS[band]
	var out: Array[String] = []
	if elite:
		out.append("brute")
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
	tiles[idx] = _spawn(rng, type, act, lap)
	return change(idx)

func change(idx: int) -> Dictionary:
	return {"idx": idx, "type": tiles[idx].type, "enemies": tiles[idx].enemies.duplicate(), "elite": tiles[idx].elite}

## Lap mutation: cleared fight tiles become Empty, then mutate_spawns_for(size) (24: +2 Enemy
## +1 Elite; 32: +3 Enemy +1 Elite) go on random Empty tiles, then events are topped back up
## to the layout's event count. `protect` tiles are never changed.
func mutate(rng: Rng, act: int, lap: int, protect: Array = []) -> Array[Dictionary]:
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
	spawns.assign(mutate_spawns_for(size()))
	var events := 0
	for t in tiles:
		if t.type == "event":
			events += 1
	for k in range(events, int(layout_for(size()).event)):
		spawns.append("event")
	for type in spawns:
		if empties.is_empty():
			break
		var idx: int = empties.pop_back()
		set_tile(idx, type, rng, act, lap)
		# replace an earlier change entry for the same tile
		for c in range(changes.size() - 1, -1, -1):
			if changes[c].idx == idx:
				changes.remove_at(c)
		changes.append(change(idx))
	return changes

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

func to_dict() -> Dictionary:
	var t: Array = []
	for tile in tiles:
		var d := {"type": tile.type, "enemies": Array(tile.enemies).duplicate(), "elite": bool(tile.elite)}
		if tile.get("cleared", false):
			d["cleared"] = true
		t.append(d)
	return {"tiles": t, "size": size(), "side": side()}

static func from_dict(d: Dictionary) -> Board:
	var b := Board.new()
	for td in d.get("tiles", []):
		var enemies: Array = []
		for e in td.get("enemies", []):
			enemies.append(String(e))
		var tile := make_tile(String(td.type), enemies, bool(td.get("elite", false)))
		if td.get("cleared", false):
			tile["cleared"] = true
		b.tiles.append(tile)
	return b
