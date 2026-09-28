class_name Board
extends RefCounted
## 24-tile ring (perimeter of a 7x7 grid). Tile 0 is Start; corners 6/12/18 are Forge,
## Treasury and Portal. Each tile: {type, enemies:Array[String], elite:bool}.

const SIZE := 24
const CORNERS := {0: "start", 6: "forge", 12: "treasury", 18: "portal"}
const LAYOUT := {"enemy": 6, "chest": 3, "event": 3, "campfire": 2, "trap": 2, "empty": 4}
const EVENT_TARGET := 3

var tiles: Array[Dictionary] = []

static func make_tile(type: String, enemies: Array = [], elite: bool = false) -> Dictionary:
	return {"type": type, "enemies": enemies.duplicate(), "elite": elite}

static func is_corner(idx: int) -> bool:
	return CORNERS.has(idx)

static func generate(rng: Rng, act: int) -> Board:
	var b := Board.new()
	var bag: Array[String] = []
	for type in LAYOUT:
		for i in LAYOUT[type]:
			bag.append(type)
	if act >= 2:
		bag.erase("enemy")
		bag.append("elite")
	# shuffle until tiles 1 and 2 are not fights (swap-fix keeps it deterministic and fast)
	rng.shuffle(bag)
	var edge: Array[int] = []
	for i in SIZE:
		if not is_corner(i):
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
	b.tiles.resize(SIZE)
	for i in SIZE:
		if is_corner(i):
			b.tiles[i] = make_tile(CORNERS[i])
	for k in edge.size():
		var type := bag[k]
		b.tiles[edge[k]] = _spawn(rng, type, act, 1)
	return b

static func _is_fight(type: String) -> bool:
	return type == "enemy" or type == "elite"

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

## Tile index after moving `steps` from `pos`.
static func landing(pos: int, steps: int) -> int:
	return (pos + steps) % SIZE

## Tiles visited in order, excluding the starting tile.
static func path(pos: int, steps: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(1, steps + 1):
		out.append((pos + i) % SIZE)
	return out

## True if moving passes or lands on Start.
static func crosses_start(pos: int, steps: int) -> bool:
	return pos + steps >= SIZE

static func portal_targets(pos: int) -> Array[int]:
	return path(pos, Balance.PORTAL_RANGE)

func clear_enemies(idx: int) -> void:
	tiles[idx]["enemies"] = []
	tiles[idx]["cleared"] = true

## First `n` tiles of `type` strictly ahead of `pos` (not wrapping past Start twice).
func next_of_type(pos: int, type: String, n: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(1, SIZE):
		var idx := (pos + i) % SIZE
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

## Lap mutation: cleared fight tiles become Empty, +2 Enemy and +1 Elite on random Empty
## tiles, then events are topped back up to 3. `protect` tiles are never changed.
func mutate(rng: Rng, act: int, lap: int, protect: Array = []) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for i in SIZE:
		if _is_fight(tiles[i].type) and tiles[i].get("cleared", false):
			tiles[i] = make_tile("empty")
			changes.append(change(i))
	var empties: Array[int] = []
	for i in SIZE:
		if tiles[i].type == "empty" and not protect.has(i):
			empties.append(i)
	rng.shuffle(empties)
	var spawns: Array[String] = ["enemy", "enemy", "elite"]
	var events := 0
	for t in tiles:
		if t.type == "event":
			events += 1
	for k in range(events, EVENT_TARGET):
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

func to_dict() -> Dictionary:
	var t: Array = []
	for tile in tiles:
		var d := {"type": tile.type, "enemies": Array(tile.enemies).duplicate(), "elite": bool(tile.elite)}
		if tile.get("cleared", false):
			d["cleared"] = true
		t.append(d)
	return {"tiles": t}

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
