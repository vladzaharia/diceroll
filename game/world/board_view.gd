class_name BoardView
extends Node3D
## The ring board on its floating-island biome, the hero and enemy previews. Any ring size
## 4(n-1) works (24 = 7x7, 28 = 8x8 default, 32 = 9x9); the size comes from the tile list.
##
##   var board := BoardView.new()
##   add_child(board)
##   board.build("glade", tiles)      # biome id; tiles: N x {type, enemies:Array[String], elite:bool}
##   board.show_targets([4, 7], [4, 7])
##   await board.hop_hero([1, 2, 3, 4])
##
## Ring layout: perimeter of an n x n grid, tile 0 (Start) at the front-left corner, running
## clockwise seen from above: up the left edge (corner q = Forge), right along the back (2q =
## Treasury), down the right edge (3q = Portal), back along the front. q = ring_size / 4.

signal hero_landed(idx: int)
## Emitted when set_hero_class() replaces the hero node (re-target cameras on it).
signal hero_changed(hero: Character)

## Ring size used when build() gets no tiles.
const DEFAULT_RING := Balance.BOARD_SIZE
const PITCH := 2.1                 ## tile centre spacing (world units)
const TILE_TOP := 0.5              ## y of a tile's top surface
const HERO_SCALE := 0.72
const PREVIEW_SCALE := 0.44
const TILE_MESH := "res://assets/kaykit/boardgame/tile_blue.gltf"
const TILE_SHADER := preload("res://game/world/shaders/atlas_tint.gdshader")

## Biome id being shown (see Biome.IDS).
var biome_id := "crypt"
## Number of ring tiles (4(n-1)) and the grid side n; set by build().
var ring_size := DEFAULT_RING
var side := DEFAULT_RING / 4 + 1
var tiles: Array = []
var hero: Character
var hero_class := "knight"
## Equipped skin (SkinDefs slot) and the A10 prestige overlay of the hero (HeroLook).
var hero_skin := "default"
var hero_prestige := false
var hero_idx := 0
## Seeds the biome's dressing variant (set before build(); see Biome.build / Dressing).
var variant_seed := 0
var biome: Node3D

var _tiles_root: Node3D
var _targets_root: Node3D
var _tile_nodes: Array[Node3D] = []
var _top_mats: Array[ShaderMaterial] = []
var _props: Array = []          # per tile: Node3D or null (prop + figures)
var _figures: Array = []        # per tile: Array[Character]
var _hero_turn_tween: Tween
var _hidden: Array[Node3D] = []
## Tiles whose top glows for the current move preview (cleared by clear_targets()).
var _path_lit: Array[int] = []
var _hidden_fx: Array[Node3D] = []


func _init() -> void:
	name = "BoardView"


## Builds (or rebuilds) the biome, the ring and the hero. `p_biome` is a biome id (an int is
## read as a legacy act number). `tiles` uses the core contract shape; missing entries
## default to empty tiles.
func build(p_biome: Variant, p_tiles: Array) -> void:
	biome_id = Biome.id_of(p_biome)
	for c in get_children():
		c.queue_free()
	_tile_nodes.clear()
	_top_mats.clear()
	_props.clear()
	_figures.clear()
	_hidden.clear()
	_hidden_fx.clear()
	_path_lit.clear()
	tiles = []
	ring_size = p_tiles.size() if p_tiles.size() >= 16 and p_tiles.size() % 4 == 0 else DEFAULT_RING
	side = ring_size / 4 + 1
	for i in ring_size:
		tiles.append(_norm(p_tiles[i] if i < p_tiles.size() else {}))
	biome = Biome.build(biome_id, ring_extent(), variant_seed)
	add_child(biome)
	_tiles_root = Node3D.new()
	_tiles_root.name = "Tiles"
	add_child(_tiles_root)
	_targets_root = Node3D.new()
	_targets_root.name = "Targets"
	add_child(_targets_root)
	for i in ring_size:
		_build_tile(i)
	_spawn_hero()


# --- geometry ---------------------------------------------------------------------------

## Grid cell of a ring index, centred on the board: x, z in -h..h with h = (side - 1) / 2
## (half-integers on even sides).
func grid_of(idx: int) -> Vector2:
	var q := ring_size / 4
	var h := q * 0.5
	var i := posmod(idx, ring_size)
	if i <= q:
		return Vector2(-h, h - i)
	if i <= 2 * q:
		return Vector2(-h + (i - q), -h)
	if i <= 3 * q:
		return Vector2(h, -h + (i - 2 * q))
	return Vector2(h - (i - 3 * q), h)


func is_corner(idx: int) -> bool:
	return posmod(idx, ring_size / 4) == 0


## Half-extent of the ring's outer tile edge (world units, BoardView-local).
func ring_extent() -> float:
	return (ring_size / 4) * 0.5 * PITCH + PITCH * 0.5


## Wraps a tile index onto the ring.
func wrap_idx(idx: int) -> int:
	return posmod(idx, ring_size)


## Top-surface centre of a tile in BoardView-local space.
func tile_position(idx: int) -> Vector3:
	var g := grid_of(idx)
	return Vector3(g.x * PITCH, TILE_TOP, g.y * PITCH)


## Top-surface centre in world space.
func tile_global_position(idx: int) -> Vector3:
	return to_global(tile_position(idx))


## Unit direction of travel leaving tile `idx`.
func tile_forward(idx: int) -> Vector3:
	return (tile_position(idx + 1) - tile_position(idx)).normalized()


## Unit direction from a tile toward the island centre (for combat staging).
func tile_inward(idx: int) -> Vector3:
	var p := tile_position(idx)
	var g := grid_of(idx)
	var h := (ring_size / 4) * 0.5
	var v := Vector3(-signf(g.x) if absf(absf(g.x) - h) < 0.01 else 0.0, 0.0, -signf(g.y) if absf(absf(g.y) - h) < 0.01 else 0.0)
	if p.length() < 0.01:
		return Vector3.FORWARD
	return v.normalized()


## World-space AABB of the ring including standing figures (camera overview framing).
func ring_bounds() -> AABB:
	var h := ring_extent()
	var a := AABB(Vector3(-h, 0.0, -h), Vector3(h * 2.0, 1.8, h * 2.0))
	return global_transform * a


## Where combat happens for a tile: the hero stays on the tile, enemies line up inward.
## Returns {hero: Vector3, facing: Vector3 (hero -> enemies), side: Vector3} in world space.
func combat_anchor(idx: int) -> Dictionary:
	var inward := tile_inward(idx)
	var side := inward.cross(Vector3.UP).normalized()
	return {"hero": tile_global_position(idx), "facing": global_basis * inward,
		"side": global_basis * side, "ground_y": to_global(Vector3.ZERO).y + 0.05,
		"distance": 3.3 if is_corner(idx) else 2.7}


# --- tiles ------------------------------------------------------------------------------

func _norm(t: Dictionary) -> Dictionary:
	var type := String(t.get("type", "empty"))
	if type == "":
		type = "empty"
	var enemies: Array = t.get("enemies", [])
	# affixes: board tiles carry `enemy_affixes`, board_mutated changes `affixes` (parallel to enemies)
	var affixes: Array = t.get("enemy_affixes", t.get("affixes", []))
	return {"type": type, "enemies": enemies.duplicate(), "elite": bool(t.get("elite", type == "elite")),
		"game": String(t.get("game", "")), "enemy_affixes": affixes.duplicate(true)}


func _build_tile(i: int) -> void:
	var root := Node3D.new()
	root.name = "Tile%02d" % i
	var p := tile_position(i)
	root.position = Vector3(p.x, 0.0, p.z)
	_tiles_root.add_child(root)
	var corner := is_corner(i)
	var base := Props.inst(TILE_MESH)
	base.name = "Base"
	var bw := 2.02 if corner else 1.94
	base.scale = Vector3(bw, 1.9 if corner else 1.75, bw)
	var bmat := _tile_material(Color(0.8, 0.62, 0.34) if corner else TileStyle.base_color(biome_id), base)
	bmat.set_shader_parameter("roughness", 0.95)
	root.add_child(base)
	var top := Props.inst(TILE_MESH)
	top.name = "Top"
	var tw := 1.7 if corner else 1.6
	top.scale = Vector3(tw, 0.75, tw)
	top.position.y = TILE_TOP - 0.15
	var tmat := _tile_material(TileStyle.color(tiles[i].type), top)
	root.add_child(top)
	Props.set_shadows(base, true)
	Props.set_shadows(top, false)
	if corner:
		base.position.y = -0.03
	var glow: Variant = Biome.look(biome_id).get("tile_glow", null)
	if glow is Color:
		root.add_child(TileStyle.glow_skirt(glow, bw))
	_tile_nodes.append(root)
	_top_mats.append(tmat)
	_props.append(null)
	_figures.append([])
	_dress_tile(i, false)


func _tile_material(color: Color, n: Node3D) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = TILE_SHADER
	var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
	var base := mi.get_active_material(0) as BaseMaterial3D
	if base:
		sm.set_shader_parameter("albedo_tex", base.albedo_texture)
	sm.set_shader_parameter("tint", color)
	sm.set_shader_parameter("strength", 1.0)
	sm.set_shader_parameter("roughness", 0.7)
	Props.override_material(n, sm)
	return sm


## Builds the prop + enemy figures for tile i from tiles[i].
func _dress_tile(i: int, animate: bool) -> void:
	var t: Dictionary = tiles[i]
	var holder := Node3D.new()
	holder.name = "Dressing"
	holder.position = Vector3(0, TILE_TOP, 0)
	_tile_nodes[i].add_child(holder)
	var type := String(t.type)
	holder.add_child(TileStyle.make_prop(type, String(t.get("game", ""))))
	var figs: Array[Character] = []
	var ids: Array = t.enemies
	var affs: Array = t.get("enemy_affixes", [])
	if type == "miniboss" and not ids.is_empty():
		figs.append(_dress_miniboss(holder, String(ids[0]), i, affs[0] if not affs.is_empty() else []))
	if (type == "enemy" or type == "elite") and ids.is_empty():
		ids = ["skeleton_minion"]
	if type == "enemy" or type == "elite":
		var n := mini(ids.size(), 3)
		var spots: Array = [[Vector3(0, 0, -0.05)], [Vector3(-0.36, 0, -0.18), Vector3(0.36, 0, 0.12)],
			[Vector3(-0.45, 0, 0.12), Vector3(0.45, 0, 0.12), Vector3(0, 0, -0.38)]][n - 1]
		var elite := bool(t.elite) or type == "elite"
		for k in n:
			var id := String(ids[k])
			# same variant / tier / elite skin as the fight on this tile (EnemyLooks.spawn_context)
			var ctx := EnemyLooks.spawn_context({"id": id, "affixes": affs[k] if k < affs.size() else []}, i, ids.slice(0, k), biome_id, elite)
			var ch := EnemyLooks.create(id, false, ctx)
			var s := PREVIEW_SCALE * (1.0 if n == 1 else 0.85) * (1.15 if elite else 1.0)
			s *= clampf(EnemyLooks.scale_of(id), 1.0, 1.25)
			if EnemyLooks.is_large(id, ctx):
				s *= 0.72
			ch.scale = Vector3.ONE * s
			ch.position = spots[k]
			ch.rotation.y = deg_to_rad(randf_range(-25.0, 25.0))
			holder.add_child(ch)
			figs.append(ch)
		AffixLooks.tile_chips(holder, affs.slice(0, n))
		if elite:
			Fx.elite_sparkle(holder, Vector3(0, 0.1, 0), 0.62, 1.1)
			var crown := Props.put(holder, Props.PLAT + "yellow/star_yellow.gltf", Vector3(0.55, 0.25, 0.55), 0.0, 0.28)
			crown.name = "EliteStar"
			var spin := crown.create_tween().set_loops()
			spin.tween_property(crown, "rotation:y", TAU, 3.0).from(0.0)
	_props[i] = holder
	_figures[i] = figs
	if animate:
		holder.scale = Vector3.ONE * 0.01
		var tw := holder.create_tween()
		tw.tween_property(holder, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Mini-boss tile: a larger preview figure between two skull posts with red flames, a
## hovering skull emblem and a slow red ground glow. Returns the figure.
func _dress_miniboss(holder: Node3D, id: String, idx := -1, affixes: Array = []) -> Character:
	var ch := EnemyLooks.create(id, false, EnemyLooks.spawn_context({"id": id, "affixes": affixes}, idx, [], biome_id))
	AffixLooks.tile_chips(holder, [affixes], 2.0)
	ch.scale = Vector3.ONE * PREVIEW_SCALE * 1.35 * EnemyLooks.scale_of(id) / 1.3
	ch.position = Vector3(0, 0, 0.02)
	ch.rotation.y = deg_to_rad(12.0)
	holder.add_child(ch)
	for sx in [-1.0, 1.0]:
		var post := Props.put(holder, Props.HAL + "post_skull.gltf", Vector3(sx * 0.62, 0, -0.52), sx * -18.0, 0.55)
		post.name = "SkullPost"
		Biome.flame(holder, Vector3(sx * 0.62, 0.98, -0.5), Color(1.0, 0.3, 0.15), 0.2, 6)
	var glow := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.9, 1.9)
	glow.mesh = pm
	var gm := Props.glow_material(Color(1.0, 0.25, 0.18), true, 1.4)
	gm.albedo_texture = Props.particle_texture("ring")
	glow.material_override = gm
	glow.position.y = 0.03
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(glow)
	var gt := glow.create_tween().set_loops()
	gt.tween_property(glow, "scale", Vector3.ONE * 1.12, 0.8).set_trans(Tween.TRANS_SINE)
	gt.tween_property(glow, "scale", Vector3.ONE * 0.94, 0.8).set_trans(Tween.TRANS_SINE)
	var emblem := Node3D.new()
	emblem.name = "Emblem"
	emblem.position = Vector3(0, 2.25, -0.25)
	holder.add_child(emblem)
	var skull := Props.put(emblem, Props.HAL + "skull.gltf", Vector3.ZERO, 0.0, 0.46)
	Props.tint(skull, Color(1.0, 0.86, 0.7), 0.35, Color(0.6, 0.12, 0.05))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.35, 0.2)
	l.light_energy = 1.6
	l.omni_range = 2.6
	l.position = Vector3(0, 0.1, 0.4)
	emblem.add_child(l)
	var bob := emblem.create_tween().set_loops()
	bob.tween_property(emblem, "position:y", 2.4, 1.0).set_trans(Tween.TRANS_SINE)
	bob.tween_property(emblem, "position:y", 2.22, 1.0).set_trans(Tween.TRANS_SINE)
	var spin := skull.create_tween().set_loops()
	spin.tween_property(skull, "rotation:y", deg_to_rad(35.0), 1.4).set_trans(Tween.TRANS_SINE)
	spin.tween_property(skull, "rotation:y", deg_to_rad(-35.0), 1.4).set_trans(Tween.TRANS_SINE)
	Fx.elite_sparkle(holder, Vector3(0, 0.1, 0), 0.7, 1.3)
	return ch


## Swaps tile idx to a new {type, enemies, elite} with a pop.
func set_tile(idx: int, tile: Dictionary, animate := true) -> void:
	idx = posmod(idx, ring_size)
	tiles[idx] = _norm(tile)
	var old: Node3D = _props[idx]
	if old:
		if animate:
			var t := old.create_tween()
			t.tween_property(old, "scale", Vector3.ONE * 0.01, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.tween_callback(old.queue_free)
		else:
			old.queue_free()
	var col := TileStyle.color(tiles[idx].type)
	if animate:
		var mat := _top_mats[idx]
		var tw := create_tween()
		tw.tween_interval(0.12)
		tw.tween_method(func(c: Color) -> void: mat.set_shader_parameter("tint", c),
			mat.get_shader_parameter("tint"), col, 0.25)
		_bounce(_tile_nodes[idx], 0.12)
		Fx.burst(self, tile_position(idx) + Vector3.UP * 0.2, {"amount": 12, "lifetime": 0.5,
			"speed": Vector2(1.0, 2.5), "size": 0.22, "color": col.lightened(0.3), "tex": "spark"})
		await get_tree().create_timer(0.14).timeout
	else:
		_top_mats[idx].set_shader_parameter("tint", col)
	_dress_tile(idx, animate)


## Enemy preview figures standing on a tile (e.g. to hide them when a fight starts there).
func tile_figures(idx: int) -> Array:
	return _figures[posmod(idx, ring_size)]


func set_tile_dressing_visible(idx: int, on: bool) -> void:
	var n: Node3D = _props[posmod(idx, ring_size)]
	if n:
		n.visible = on


## Short glow + bounce on a tile (landing feedback).
func pulse_tile(idx: int, color := Color(0, 0, 0, 0)) -> void:
	idx = posmod(idx, ring_size)
	var col := color if color.a > 0.0 else TileStyle.color(tiles[idx].type)
	var mat := _top_mats[idx]
	var tw := create_tween()
	tw.tween_method(func(e: float) -> void: mat.set_shader_parameter("emission", col * e), 0.9, 0.0, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bounce(_tile_nodes[idx], 0.1)
	Fx.shockwave(self, tile_position(idx) + Vector3.UP * 0.03, col.lightened(0.35), 1.6, 0.45)


func _bounce(n: Node3D, depth: float) -> void:
	var t := n.create_tween()
	t.tween_property(n, "position:y", -depth, 0.07).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --- landing targets ------------------------------------------------------------------------

## Glowing ghost markers on each target tile, labelled with the die value(s) that land there.
## Accepts typed or untyped arrays of ints.
func show_targets(targets: Array, values: Array) -> void:
	clear_targets()
	var by_tile := {}
	for k in targets.size():
		var idx := posmod(int(targets[k]), ring_size)
		if not by_tile.has(idx):
			by_tile[idx] = []
		by_tile[idx].append(int(values[k]) if k < values.size() else 0)
	var n := 0
	for idx in by_tile:
		var vals: Array = by_tile[idx]
		vals.sort()
		_targets_root.add_child(_make_marker(idx, vals, n))
		n += 1


## The single landing marker of an automatic board move: a tall beam and a big badge
## with the step count on `target`, plus a dotted trail over the tiles on the way.
## `double` makes it gold-sparkly. Steps 0 marks the hero's own tile.
func show_move_target(target: int, steps: int, double := false) -> void:
	clear_targets()
	target = wrap_idx(target)
	var col := Color(1.0, 0.8, 0.3) if double else Color(1.0, 0.9, 0.55)
	var m := _make_marker(target, [steps], 0, 1.8, col)
	_targets_root.add_child(m)
	# a bouncing chevron between the badge and the tile
	var arrow := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.62, 0.5, 0.16)
	arrow.mesh = pm
	var am := StandardMaterial3D.new()
	am.albedo_color = col
	am.emission_enabled = true
	am.emission = col
	am.emission_energy_multiplier = 1.4
	am.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	arrow.material_override = am
	arrow.rotation.z = PI
	arrow.position.y = 1.2
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(arrow)
	var at := arrow.create_tween().set_loops()
	at.tween_property(arrow, "position:y", 0.95, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	at.tween_property(arrow, "position:y", 1.3, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if double:
		Fx.elite_sparkle(m, Vector3(0, 0.2, 0), 0.8, 1.6)
	# the tiles on the way light up in a quick wave, the target stays lit brighter
	_path_lit.clear()
	for k in range(1, steps + 1):
		var idx := wrap_idx(hero_idx + k)
		var last := idx == target or k == steps
		var mat := _top_mats[idx]
		var glow := col * (0.9 if last else 0.5)
		_path_lit.append(idx)
		var tw := create_tween()
		tw.tween_interval(0.045 * k)
		tw.tween_method(func(e: float) -> void: mat.set_shader_parameter("emission", glow * e), 2.2, 1.0, 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if last:
			break


func clear_targets() -> void:
	if _targets_root == null:
		return
	for c in _targets_root.get_children():
		c.queue_free()
	for idx in _path_lit:
		if idx < _top_mats.size():
			_top_mats[idx].set_shader_parameter("emission", Color.BLACK)
	_path_lit.clear()


func _make_marker(idx: int, vals: Array, order: int, big := 1.0, col := Color(1.0, 0.86, 0.45)) -> Node3D:
	var root := Node3D.new()
	root.name = "Target%02d" % idx
	root.position = tile_position(idx)
	# pulsing ground ring
	var ring := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.9, 1.9)
	ring.mesh = pm
	var rm := Props.glow_material(col, true, 1.6 + (big - 1.0) * 2.5)
	rm.albedo_texture = Props.particle_texture("ring")
	ring.material_override = rm
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var rt := ring.create_tween().set_loops()
	rt.tween_property(ring, "scale", Vector3.ONE * 1.08, 0.6).set_trans(Tween.TRANS_SINE)
	rt.tween_property(ring, "scale", Vector3.ONE * 0.9, 0.6).set_trans(Tween.TRANS_SINE)
	# soft light pillar
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.62
	cm.bottom_radius = 0.72
	cm.height = 2.4 * big
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://game/fx/shaders/beam.gdshader")
	bm.set_shader_parameter("color", col)
	bm.set_shader_parameter("alpha", 0.45 + 0.2 * (big - 1.0))
	beam.material_override = bm
	beam.position.y = 1.2 * big
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	# die-face badge with the value(s)
	var badge := Node3D.new()
	var bh := 1.45 + 0.35 * (big - 1.0)
	badge.position.y = bh
	badge.scale = Vector3.ONE * 1.9 * big
	root.add_child(badge)
	var chars := 0
	for v in vals:
		chars += str(v).length()
	var w := 0.62 + 0.36 * float(vals.size() - 1) + 0.24 * float(chars - vals.size())
	var face := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, 0.62)
	face.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = Props.particle_texture("rounded")
	fm.albedo_color = Color(1.0, 0.97, 0.9)
	fm.no_depth_test = true
	fm.render_priority = 14
	face.material_override = fm
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	badge.add_child(face)
	var rim := MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(w + 0.1, 0.72)
	rim.mesh = q2
	var rim_m := fm.duplicate() as StandardMaterial3D
	rim_m.albedo_color = Color(0.85, 0.55, 0.12)
	rim_m.render_priority = 13
	rim.material_override = rim_m
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	badge.add_child(rim)
	var lbl := Label3D.new()
	var parts := PackedStringArray()
	for v in vals:
		parts.append(str(v))
	lbl.text = " ".join(parts)
	lbl.font = Props.font(true)
	lbl.font_size = 120
	lbl.pixel_size = 0.0036
	lbl.modulate = Color(0.24, 0.12, 0.1)
	lbl.outline_size = 0
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 15
	lbl.position.y = -0.01
	badge.add_child(lbl)
	var bt := badge.create_tween().set_loops()
	bt.tween_property(badge, "position:y", bh + 0.1, 0.7).set_trans(Tween.TRANS_SINE)
	bt.tween_property(badge, "position:y", bh - 0.07, 0.7).set_trans(Tween.TRANS_SINE)
	# pop in, staggered
	root.scale = Vector3.ONE * 0.01
	var pt := root.create_tween()
	pt.tween_interval(0.06 * order)
	pt.tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


# --- biome change waves -----------------------------------------------------------------------

## Ring distance of tile i from `from` (either way round).
func _ring_dist(i: int, from: int) -> int:
	var d := posmod(i - from, ring_size)
	return mini(d, ring_size - d)


## The board sinks away tile by tile, outward from `from` (the hero keeps standing).
func sink_wave(from: int, duration := 0.9) -> void:
	clear_targets()
	var half := ring_size / 2
	for i in ring_size:
		if i == hero_idx:
			continue
		var n := _tile_nodes[i]
		var delay := duration * 0.7 * float(_ring_dist(i, from)) / float(half)
		var t := n.create_tween()
		t.tween_interval(delay)
		t.tween_property(n, "position:y", 0.12, 0.08)
		t.tween_property(n, "position:y", -2.2, duration * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(n, "scale", Vector3.ONE * 0.6, duration * 0.3)
	var hp: Node3D = _props[hero_idx]
	if hp:
		var ht := hp.create_tween()
		ht.tween_interval(duration * 0.4)
		ht.tween_property(hp, "scale", Vector3.ONE * 0.01, 0.2)
	await get_tree().create_timer(duration + 0.1).timeout


## Hides every tile but the hero's (use before rise_wave()).
func hide_tiles() -> void:
	for i in ring_size:
		if i == hero_idx:
			continue
		_tile_nodes[i].position.y = -2.2
		_tile_nodes[i].scale = Vector3.ONE * 0.6
		_tile_nodes[i].visible = false


## The new board rises tile by tile, outward from `from`, each landing with a puff.
func rise_wave(from: int, duration := 1.1) -> void:
	var half := ring_size / 2
	for i in ring_size:
		var n := _tile_nodes[i]
		if i == hero_idx:
			pulse_tile(i)
			continue
		var delay := duration * 0.75 * float(_ring_dist(i, from)) / float(half)
		var col := TileStyle.color(String(tiles[i].type))
		var pos := tile_position(i)
		var t := n.create_tween()
		t.tween_interval(delay)
		t.tween_callback(func() -> void: n.visible = true)
		t.tween_property(n, "position:y", 0.18, duration * 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(n, "scale", Vector3.ONE, duration * 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(n, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.tween_callback(func() -> void:
			Fx.burst(self, pos + Vector3.UP * 0.15, {"amount": 10, "lifetime": 0.45, "speed": Vector2(0.8, 2.0),
				"size": 0.2, "color": col.lightened(0.35), "tex": "spark"}))
	await get_tree().create_timer(duration + 0.45).timeout


# --- hero -----------------------------------------------------------------------------------

func _spawn_hero() -> void:
	hero = HeroLook.create(hero_class, hero_skin, hero_prestige)
	hero.name = "Hero"
	hero.scale = Vector3.ONE * HERO_SCALE
	add_child(hero)
	var holder := Node3D.new()
	holder.name = "HeroRing"
	holder.position.y = 0.03
	hero.add_child(holder)
	var ring := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.9, 1.9)
	ring.mesh = pm
	var m := Props.glow_material(Color(1.0, 0.85, 0.45), true, 1.3)
	m.albedo_texture = Props.particle_texture("ring")
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring)
	var rt := ring.create_tween().set_loops()
	rt.tween_property(ring, "scale", Vector3.ONE * 1.12, 0.9).set_trans(Tween.TRANS_SINE)
	rt.tween_property(ring, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_SINE)
	place_hero(hero_idx)


## Swaps the hero model (knight | barbarian | mage | rogue), keeping its tile.
func set_hero_class(id: String) -> void:
	hero_class = id
	var rot := hero.rotation.y if hero else 0.0
	if hero:
		hero.queue_free()
	_spawn_hero()
	hero.rotation.y = rot
	hero_changed.emit(hero)


## Puts the hero on a tile instantly, turned toward the camera.
func place_hero(idx: int) -> void:
	hero_idx = posmod(idx, ring_size)
	hero.position = tile_position(hero_idx)
	hero.rotation.y = _rest_yaw(hero_idx)
	_shift_dressing_for_hero()


## Hops the hero tile by tile along `path` (tile indices, excluding the current one).
func hop_hero(path: Array, step_time := 0.28) -> void:
	if path.is_empty():
		return
	clear_targets()
	_restore_dressing(hero_idx)
	_show_hero_ring(false)
	for k in path.size():
		var to_idx := posmod(int(path[k]), ring_size)
		var from := hero.position
		var to := tile_position(to_idx)
		var dir := to - from
		dir.y = 0.0
		if dir.length() > 0.01:
			_turn_hero(atan2(dir.x, dir.z), 0.1)
		# one short jump clip per tile (skip the wind-up, fit the rest into the hop)
		if hero.anim_player.has_animation("Jump_Full_Short"):
			var jl := hero.anim_player.get_animation("Jump_Full_Short").length
			hero.current = "Jump_Full_Short"
			hero.anim_player.play("Jump_Full_Short", 0.04, (jl - 0.22) / (step_time * 1.1))
			hero.anim_player.seek(0.22, true)
		var t := create_tween()
		var h := 0.75
		t.tween_method(func(u: float) -> void:
			hero.position = from.lerp(to, u) + Vector3.UP * (4.0 * h * u * (1.0 - u)), 0.0, 1.0, step_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await t.finished
		hero_idx = to_idx
		Audio.play_sfx("step")
		_squash(hero, 0.1)
		var bump := _tile_nodes[to_idx].create_tween()
		bump.tween_property(_tile_nodes[to_idx], "position:y", -0.06, 0.05)
		bump.tween_property(_tile_nodes[to_idx], "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if k < path.size() - 1:
			await get_tree().create_timer(step_time * 0.12).timeout
	hero.play_once("Jump_Land", "idle", 0.05, 1.4)
	_show_hero_ring(true)
	pulse_tile(hero_idx)
	_turn_hero(_rest_yaw(hero_idx), 0.35)
	_shift_dressing_for_hero()
	hero_landed.emit(hero_idx)


## Teleports the hero to a tile through a portal swirl.
func teleport_hero(idx: int) -> void:
	idx = posmod(idx, ring_size)
	Audio.play_sfx("portal")
	_restore_dressing(hero_idx)
	Fx.portal_swirl(self, hero.position + Vector3.UP * 0.7, 0.8, true)
	var s := Vector3.ONE * HERO_SCALE
	var t := create_tween()
	t.tween_property(hero, "scale", Vector3(0.01, s.y * 1.4, 0.01), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(hero, "rotation:y", hero.rotation.y + TAU, 0.3)
	await t.finished
	hero_idx = idx
	hero.position = tile_position(idx)
	Fx.portal_swirl(self, hero.position + Vector3.UP * 0.7, 0.8, true)
	await get_tree().create_timer(0.15).timeout
	var t2 := create_tween()
	t2.tween_property(hero, "scale", s, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.parallel().tween_property(hero, "rotation:y", _rest_yaw(idx), 0.35)
	await t2.finished
	pulse_tile(idx, Color(0.62, 0.4, 0.98))
	_shift_dressing_for_hero()
	hero_landed.emit(idx)


## Idle facing on a tile: toward the camera side (+Z), angled along the ring.
func _rest_yaw(idx: int) -> float:
	var f := tile_forward(idx)
	var v := (f * 0.6 + Vector3(0, 0, 1.0)).normalized()
	return atan2(v.x, v.z)


func _show_hero_ring(on: bool) -> void:
	var ring := hero.get_node_or_null("HeroRing") as Node3D
	if ring == null:
		return
	ring.visible = true
	var t := ring.create_tween()
	t.tween_property(ring, "scale", Vector3.ONE * (1.0 if on else 0.01), 0.15)
	if not on:
		t.tween_callback(func() -> void: ring.visible = false)


func _turn_hero(yaw: float, time: float) -> void:
	if _hero_turn_tween:
		_hero_turn_tween.kill()
	var cur := hero.rotation.y
	var target := cur + wrapf(yaw - cur, -PI, PI)
	_hero_turn_tween = create_tween()
	_hero_turn_tween.tween_property(hero, "rotation:y", target, time).set_trans(Tween.TRANS_SINE)


func _squash(n: Node3D, time: float) -> void:
	var s := Vector3.ONE * HERO_SCALE
	var t := n.create_tween()
	t.tween_property(n, "scale", Vector3(s.x * 1.15, s.y * 0.82, s.z * 1.15), time * 0.5)
	t.tween_property(n, "scale", s, time * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Nudges the hero's tile dressing to the back so it doesn't overlap the hero.
func _shift_dressing_for_hero() -> void:
	var n: Node3D = _props[hero_idx]
	if n == null:
		return
	var type := String(tiles[hero_idx].type)
	if type == "enemy" or type == "elite" or type == "miniboss":
		return
	var t := n.create_tween()
	t.tween_property(n, "position", Vector3(0.0, TILE_TOP, -0.35), 0.25).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(n, "scale", Vector3.ONE * 0.75, 0.25)


func _restore_dressing(idx: int) -> void:
	var n: Node3D = _props[posmod(idx, ring_size)]
	if n == null:
		return
	var t := n.create_tween()
	t.tween_property(n, "position", Vector3(0.0, TILE_TOP, 0.0), 0.25).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(n, "scale", Vector3.ONE, 0.25)


# --- occlusion ------------------------------------------------------------------------------

## Sinks dressing / tile props that would sit between a camera at `cam_xform` and the
## `focus` points (e.g. the combat line-up). Undo with restore_occluders().
func hide_occluders(cam_xform: Transform3D, fov_deg: float, aspect: float, focus: Array) -> void:
	if focus.is_empty():
		return
	var inv := cam_xform.affine_inverse()
	var ty := tan(deg_to_rad(fov_deg) * 0.5)
	var tx := ty * aspect
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var near := INF
	for p: Vector3 in focus:
		for h: float in [0.0, 1.8]:
			var v := inv * (p + Vector3.UP * h)
			var d := -v.z
			if d <= 0.1:
				continue
			var s := Vector2(v.x / (d * tx), v.y / (d * ty))
			lo = lo.min(s)
			hi = hi.max(s)
			near = minf(near, d)
	lo -= Vector2(0.12, 0.12)
	hi += Vector2(0.12, 0.25)
	var candidates: Array[Node3D] = []
	var fx: Array[Node3D] = []
	for holder_name in ["Dressing", "SetPiece", "InnerCorners"]:
		var holder := biome.get_node_or_null(holder_name)
		if holder:
			for c in holder.get_children():
				if c.name == "Floor":
					continue
				if c is Light3D or c is GPUParticles3D:
					fx.append(c)
				elif c is Node3D:
					candidates.append(c)
	var sunk: Array[AABB] = []
	for i in ring_size:
		if _props[i] and i != hero_idx:
			candidates.append(_props[i])
	for n in candidates:
		var box := Props.world_aabb(n)
		if box.size == Vector3.ZERO:
			continue
		var slo := Vector2(INF, INF)
		var shi := Vector2(-INF, -INF)
		var dmax := -INF
		for k in 8:
			var v := inv * box.get_endpoint(k)
			var d := maxf(-v.z, 0.1)
			dmax = maxf(dmax, -v.z)
			var sp := Vector2(v.x / (d * tx), v.y / (d * ty))
			slo = slo.min(sp)
			shi = shi.max(sp)
		# 1) anything fully in front of the fighters that overlaps them on screen
		var hit := dmax < near - 0.2 and slo.x < hi.x and shi.x > lo.x and slo.y < hi.y and shi.y > lo.y
		# 2) tall foreground clutter anywhere in the frame (walls, pillars, trees)
		if not hit and box.size.y > 1.6:
			var vc := inv * box.get_center()
			var on_screen := slo.x < 1.0 and shi.x > -1.0 and slo.y < 1.0 and shi.y > -1.0
			hit = on_screen and -vc.z < near - 0.8
			# 3) tall props level with the nearest fighter that overlap the fight on screen
			# (lantern posts, gallows and trees right beside the hero)
			if not hit:
				var dmin := INF
				for k in 8:
					dmin = minf(dmin, -(inv * box.get_endpoint(k)).z)
				var g := 0.15
				var overlap := slo.x < hi.x + g and shi.x > lo.x - g and slo.y < hi.y + g and shi.y > lo.y - g
				hit = overlap and dmin < near + 0.6

		if hit:
			_sink(n)
			sunk.append(box.grow(0.9))
	for f in fx:
		if not f.visible:
			continue
		for b in sunk:
			if b.has_point(f.global_position):
				_hidden_fx.append(f)
				f.visible = false
				break


## Sinks tile dressing (props + enemy previews) within `radius` of a world point, except the
## hero's tile. Undo with restore_occluders().
func clear_area(center: Vector3, radius: float) -> void:
	# moat-corner dressing standing in the fight
	var inner := biome.get_node_or_null("InnerCorners") if biome else null
	if inner:
		for c in inner.get_children():
			var n := c as Node3D
			if n == null or not n.visible or _hidden.has(n):
				continue
			var p := n.global_position
			if Vector2(p.x - center.x, p.z - center.z).length() < radius * 0.8:
				if n is Light3D or n is GPUParticles3D:
					_hidden_fx.append(n)
					n.visible = false
				else:
					_sink(n)
	for i in ring_size:
		var n: Node3D = _props[i]
		if n == null or i == hero_idx or _hidden.has(n) or not n.visible:
			continue
		var p := tile_global_position(i)
		if Vector2(p.x - center.x, p.z - center.z).length() > radius:
			continue
		_sink(n)


func _sink(n: Node3D) -> void:
	if _hidden.has(n):
		return
	_hidden.append(n)
	n.set_meta("occl_scale", n.scale)
	var t := n.create_tween()
	t.tween_property(n, "scale", Vector3(n.scale.x, 0.01, n.scale.z), 0.25).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: n.visible = false)


func restore_occluders() -> void:
	for f in _hidden_fx:
		if is_instance_valid(f):
			f.visible = true
	_hidden_fx.clear()
	for n in _hidden:
		if not is_instance_valid(n):
			continue
		n.visible = true
		var t := n.create_tween()
		t.tween_property(n, "scale", n.get_meta("occl_scale", Vector3.ONE), 0.3).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	_hidden.clear()
