class_name BiomeExtents
extends RefCounted
## Layout guard: how far the walkable island floor reaches past the ring on each side.
##
##   var r := BiomeExtents.measure("magma", 28)
##   # r = {left, right, back, front (world units), extent, island_half, ok}
##
## The floor is what Biome.build() tags "walkable" (the paving / floor tiles and raised
## terrain blocks), clipped to the island top, minus anything tagged "hazard" (the Magma
## lava channel). Each side is measured along lanes spanning the ring's side: the distance
## from the ring's outer tile edge to the first point that is not floor, minimum over lanes.
## ok = every side reaches MIN_PITCHES (the floor's box contains the ring's box grown by that
## on all four sides; the island's rounded corners are not checked).

## Required floor past the ring's outer tile edge, in tile pitches.
const MIN_PITCHES := 1.25
const RES := 0.1          ## raster cell (world units)
const SPAN := 30.0        ## raster half size (world units)
const LANES := 17
const SIDES := ["left", "right", "back", "front"]
## BoardView.PITCH / DEFAULT_RING (BoardView itself needs the Audio autoload, which a bare
## `-s` script run does not have).
const PITCH := 2.1
const DEFAULT_RING := 28


static func min_margin() -> float:
	return MIN_PITCHES * PITCH


## Mirrors BoardView.ring_extent(): half-extent of the ring's outer tile edge.
static func ring_extent(ring_size: int) -> float:
	return (ring_size / 4) * 0.5 * PITCH + PITCH * 0.5


## Builds the biome for a ring of `ring_size` tiles (exactly as BoardView does), measures it
## and frees it.
static func measure(id: String, ring_size := DEFAULT_RING) -> Dictionary:
	var e := ring_extent(ring_size)
	var world := Biome.build(id, e)
	var r := measure_world(world, e)
	world.free()
	return r


static func measure_world(world: Node3D, e: float) -> Dictionary:
	var n := int(SPAN * 2.0 / RES)
	var grid := PackedByteArray()
	grid.resize(n * n)
	var hazards: Array = []
	for node in world.find_children("*", "Node3D", true, false):
		if node.has_meta("walkable"):
			for rect in _rects(node, world):
				_fill(grid, n, rect, 1)
		elif node.has_meta("hazard"):
			hazards.append(node)
	for node in hazards:
		for rect in _rects(node, world):
			_fill(grid, n, rect, 2)
	var half := 0.0
	var island := world.get_node_or_null("Island") as MeshInstance3D
	if island and island.mesh:
		half = island.mesh.get_aabb().size.x * 0.5
	var out := {"extent": e, "island_half": half}
	var need := min_margin()
	var ok := true
	for side in SIDES:
		var dir := {"left": Vector2(-1, 0), "right": Vector2(1, 0), "back": Vector2(0, -1), "front": Vector2(0, 1)}[side] as Vector2
		var along := Vector2(dir.y, dir.x).abs()
		var best := INF
		for k in LANES:
			var t := lerpf(-e + 0.05, e - 0.05, float(k) / float(LANES - 1))
			var d := 0.0
			while d < SPAN:
				var p := dir * (e + d + RES * 0.5) + along * t
				if not _floor_at(grid, n, half, p):
					break
				d += RES
			best = minf(best, d)
		out[side] = best
		if best < need - RES:
			ok = false
	out["ok"] = ok
	return out


## One printable line per result (margins in world units and tile pitches).
static func describe(id: String, r: Dictionary) -> String:
	var parts: Array[String] = []
	for side in SIDES:
		parts.append("%s %.2f (%.2fp)" % [side, float(r[side]), float(r[side]) / PITCH])
	return "%-7s %s  island %.2f  %s" % [id, "  ".join(parts), float(r.island_half),
		"OK" if r.ok else "SHORT"]


static func _floor_at(grid: PackedByteArray, n: int, half: float, p: Vector2) -> bool:
	if half > 0.0 and pow(pow(absf(p.x) / half, 8.0) + pow(absf(p.y) / half, 8.0), 1.0 / 8.0) > 1.0:
		return false
	var i := int(floor((p.x + SPAN) / RES))
	var j := int(floor((p.y + SPAN) / RES))
	if i < 0 or j < 0 or i >= n or j >= n:
		return false
	return grid[j * n + i] == 1


static func _fill(grid: PackedByteArray, n: int, r: Rect2, v: int) -> void:
	# floor / ceil: rects sharing an edge both claim the raster cell on it (no seams)
	var i0 := clampi(int(floor((r.position.x + SPAN) / RES)), 0, n)
	var i1 := clampi(int(ceil((r.end.x + SPAN) / RES)), 0, n)
	var j0 := clampi(int(floor((r.position.y + SPAN) / RES)), 0, n)
	var j1 := clampi(int(ceil((r.end.y + SPAN) / RES)), 0, n)
	for j in range(j0, j1):
		for i in range(i0, i1):
			if v == 2 or grid[j * n + i] == 0:
				grid[j * n + i] = v


## XZ footprints of the walkable / hazard surfaces under `node` (surfaces whose top is at
## ground level or above; sunk pieces under the lava channel do not count as floor).
static func _rects(node: Node3D, world: Node3D) -> Array:
	var out: Array = []
	if node.has_meta("cells"):
		# cell centres (MultiMesh transforms do not read back headless)
		var k := float(node.get_meta("cell_size")) * 0.5
		var xf := _xf(node, world)
		for c in node.get_meta("cells") as PackedVector2Array:
			var p := xf * Vector3(c.x, 0.0, c.y)
			out.append(Rect2(p.x - k, p.z - k, k * 2.0, k * 2.0))
		return out
	var list: Array = [node]
	list.append_array(node.find_children("*", "GeometryInstance3D", true, false))
	for g in list:
		if g is MultiMeshInstance3D:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			var xf := _xf(g, world)
			var a := mm.mesh.get_aabb()
			for k in mm.instance_count:
				_add(out, (xf * mm.get_instance_transform(k)) * a)
		elif g is MeshInstance3D and (g as MeshInstance3D).mesh:
			_add(out, _xf(g, world) * (g as MeshInstance3D).mesh.get_aabb())
	return out


static func _add(out: Array, b: AABB) -> void:
	if b.end.y < -0.25 and b.size.y > 0.05:
		return
	out.append(Rect2(b.position.x, b.position.z, b.size.x, b.size.z))


## Transform of `n` relative to `root` (works outside the scene tree).
static func _xf(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
