class_name ItemThumb
extends TextureRect
## A real 3D preview of an Armory item (docs/design/2026-09-29-armory-items.md §8.3): every
## thumbnail comes from one shared off-screen SubViewport that renders each model once and caches
## the picture, so a picker full of items costs one render per model, not a live viewport each.
##
##   var t := ItemThumb.make("sword_saber", 96)            # weapon / off-hand / trinket / variant
##   var h := ItemThumb.make("wizard_hat", 96)             # head, body and back pieces too
##   ItemThumb.prewarm(["sword", "round_shield_badge"])     # render ahead (run start)
##
## Ids are ItemMounts ids (items, variants, raw models) or armor piece ids. Weapons lie on the
## diagonal, flat pieces (shields, books) face the camera; armor is shown worn on an invisible
## mannequin (its own parts hidden), heads and bodies three-quarter, back pieces from behind.
## Until the picture is ready (or with no renderer: headless) the slot's glyph stands in.

## Pixel size of the cached renders.
const PX := 256
## Glyph per slot while a render is pending.
const SLOT_ICON := {"weapon": "sword", "offhand": "shield", "head": "helmet", "body": "armor", "trinket": "ring",
	"trinket2": "ring", "back": "cape"}

static var _cache: Dictionary = {}
## Failed renders per key (a busy frame can return no image): retried up to twice.
static var _fails: Dictionary = {}
static var _renderer: _Renderer

var id := ""
var slot := ""


## A thumbnail of `p_id` at `px` logical px. `p_slot` ("" = from ItemDefs) picks the framing.
static func make(p_id: String, px := 96, p_slot := "") -> ItemThumb:
	var t := ItemThumb.new()
	t.custom_minimum_size = Vector2(px, px)
	t.set_item(p_id, p_slot)
	return t


## The slot an id belongs to (items, variants, armor pieces, raw models).
static func slot_for(p_id: String) -> String:
	var base := ItemDefs.base_of(p_id)
	if base != "":
		return ItemDefs.slot_of(base)
	if ItemMounts.HEADS.has(p_id):
		return "head"
	if ItemMounts.BODIES.has(p_id):
		return "body"
	if ItemMounts.BACKS.has(p_id):
		return "back"
	var b := String(ItemMounts.item(p_id).get("base", ""))
	return ItemDefs.slot_of(b) if b != "" else ""


## Renders `ids` ahead of time (e.g. the run's loadout, so a trigger pop has its picture).
static func prewarm(ids: Array) -> void:
	for i in ids:
		if String(i) != "":
			_request(String(i), slot_for(String(i)))


static func cached(p_id: String, p_slot := "") -> Texture2D:
	var s := p_slot if p_slot != "" else slot_for(p_id)
	return _cache.get(_key(p_id, s), null)


static func _key(p_id: String, p_slot: String) -> String:
	return p_id + "|" + ("head" if p_slot == "head" else ("body" if p_slot == "body" else ("back" if p_slot == "back" else "prop")))


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_item(p_id: String, p_slot := "") -> void:
	id = p_id
	slot = p_slot if p_slot != "" else slot_for(p_id)
	if id == "":
		texture = null
		return
	var k := _key(id, slot)
	var tex: Variant = _cache.get(k, null)
	if tex is Texture2D:
		_show(tex)
		return
	_placeholder()
	if _cache.has(k):
		return    # tried before and nothing came back (no renderer): keep the glyph
	_request(id, slot)
	_connect()


func _placeholder() -> void:
	texture = UiIcons.tex(String(SLOT_ICON.get(slot, "star")), 96, Color(1, 1, 1, 0.3))
	modulate = Color(1, 1, 1, 0.8)


func _show(tex: Texture2D) -> void:
	texture = tex
	modulate = Color.WHITE


func _enter_tree() -> void:
	_connect()


func _connect() -> void:
	if _renderer and is_instance_valid(_renderer) and not _renderer.done.is_connected(_on_done):
		_renderer.done.connect(_on_done)


func _exit_tree() -> void:
	if _renderer and _renderer.done.is_connected(_on_done):
		_renderer.done.disconnect(_on_done)


func _on_done(k: String, tex: Texture2D) -> void:
	if k == _key(id, slot) and tex != null:
		_show(tex)


static func _request(p_id: String, p_slot: String) -> void:
	var k := _key(p_id, p_slot)
	if _cache.has(k):
		return
	if _renderer == null or not is_instance_valid(_renderer):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null or DisplayServer.get_name() == "headless":
			_cache[k] = null
			return
		_renderer = _Renderer.new()
		_renderer.name = "ItemThumbRenderer"
		tree.root.add_child.call_deferred(_renderer)
	_renderer.enqueue(k, p_id, p_slot)


## The shared off-screen renderer: one SubViewport, one model at a time.
## Lifts the shadows of a render that is mostly near-black (the Paladin Helm's dark steel read
## as a hole in the card): when over DARK_SHARE of the opaque pixels are darker than DARK_LUMA,
## a screen blend raises blacks to LIFT grey, keeping hue, highlights and alpha.
const DARK_LUMA := 0.1
const DARK_SHARE := 0.35
const LIFT := 0.22


static func lift_dark(img: Image) -> void:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var dark := 0
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				n += 1
				if c.get_luminance() < DARK_LUMA:
					dark += 1
	if n == 0 or float(dark) / float(n) < DARK_SHARE:
		return
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(1.0 - (1.0 - c.r) * (1.0 - LIFT), 1.0 - (1.0 - c.g) * (1.0 - LIFT),
					1.0 - (1.0 - c.b) * (1.0 - LIFT * 0.8), c.a))


class _Renderer:
	extends Node
	signal done(key: String, tex: Texture2D)

	var _queue: Array = []
	var _busy := false
	var _vp: SubViewport
	var _world: Node3D
	var _cam: Camera3D

	func _ready() -> void:
		_vp = SubViewport.new()
		_vp.size = Vector2i(PX, PX)
		_vp.own_world_3d = true
		_vp.transparent_bg = true
		_vp.msaa_3d = Viewport.MSAA_4X
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_vp)
		_world = Node3D.new()
		_vp.add_child(_world)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color("9a96cc")
		e.ambient_light_energy = 0.9
		e.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.environment = e
		_vp.add_child(env)
		var key := DirectionalLight3D.new()
		key.light_color = Color("fff0d8")
		key.light_energy = 1.5
		key.rotation_degrees = Vector3(-40, -35, 0)
		_vp.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.light_color = Color("8fb0ff")
		rim.light_energy = 1.6
		rim.rotation_degrees = Vector3(-15, 160, 0)
		_vp.add_child(rim)
		# a soft fill from the camera side: dark-atlas pieces (the Paladin Helm's near-black
		# steel) read as a black blob on the navy card with the key light alone
		var fill := DirectionalLight3D.new()
		fill.light_color = Color("dfe6ff")
		fill.light_energy = 0.9
		fill.rotation_degrees = Vector3(-8, 20, 0)
		_vp.add_child(fill)
		_cam = Camera3D.new()
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_vp.add_child(_cam)
		_cam.current = true
		if not _queue.is_empty():
			_run()

	func enqueue(k: String, p_id: String, p_slot: String) -> void:
		for q in _queue:
			if String(q[0]) == k:
				return
		_queue.append([k, p_id, p_slot])
		if is_inside_tree() and not _busy:
			_run()

	func _run() -> void:
		_busy = true
		while not _queue.is_empty():
			var q: Array = _queue.pop_front()
			var k := String(q[0])
			if ItemThumb._cache.get(k, null) is Texture2D:
				continue
			var tex := await _render(String(q[1]), String(q[2]))
			if tex != null or int(ItemThumb._fails.get(k, 0)) >= 2:
				ItemThumb._cache[k] = tex
			else:
				ItemThumb._fails[k] = int(ItemThumb._fails.get(k, 0)) + 1
				_queue.append(q)
			done.emit(k, tex)
		_busy = false

	func _render(p_id: String, p_slot: String) -> Texture2D:
		var node: Node3D = null
		var frame := AABB()
		var armor := p_slot in ["head", "body", "back"] and not ItemMounts.piece(p_slot, p_id).is_empty()
		if armor:
			node = _armor(p_id, p_slot)
		else:
			node = _prop(p_id)
		if node == null:
			return null
		_world.add_child(node)
		if node is Character:
			(node as Character).anim_player.seek(0.3, true)
			await get_tree().process_frame
			if not is_instance_valid(node):
				return null
			(node as Character).anim_player.pause()
			frame = _bounds(node, true)
			if p_slot == "head":
				# hats sit on the head: frame the piece, a little room under it
				frame = frame.grow(frame.get_longest_axis_size() * 0.05)
		else:
			frame = _bounds(node, false)
		if frame.size == Vector3.ZERO:
			_world.remove_child(node)
			node.free()
			return null
		var c := frame.get_center()
		var span := maxf(frame.size.x, frame.size.y)
		_cam.size = span * 1.12
		_cam.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, c.y, frame.end.z + 4.0))
		_cam.near = 0.05
		_cam.far = frame.size.z + 10.0
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image() if is_instance_valid(_vp) else null
		if is_instance_valid(node):
			_world.remove_child(node)
			node.free()
		if img == null or img.is_empty():
			return null
		ItemThumb.lift_dark(img)
		img.generate_mipmaps()
		return ImageTexture.create_from_image(img)

	## A weapon / off-hand / trinket model posed for its icon: long weapons on the diagonal (grip
	## bottom-left), everything turned a little so it reads as 3D.
	func _prop(p_id: String) -> Node3D:
		var up := ItemMounts.upright(p_id)
		if up == null:
			return null
		var holder := Node3D.new()
		holder.add_child(up)
		var e := ItemMounts.local_bounds(up).size
		var long := e.y > maxf(e.x, e.z) * 1.6
		var tilt := Basis(Vector3.BACK, deg_to_rad(-38.0)) if long else Basis.IDENTITY
		holder.transform = Transform3D(tilt * Basis(Vector3.UP, deg_to_rad(-26.0)) * Basis(Vector3.RIGHT, deg_to_rad(10.0)), Vector3.ZERO)
		return holder

	## An armor piece worn by an invisible mannequin (idle pose), turned for its slot.
	func _armor(p_id: String, p_slot: String) -> Node3D:
		var lo := {p_slot: p_id}
		if p_slot == "back":
			lo = {"back": p_id}
		var ch := Character.create("mannequin", "", lo)
		for mi in ch.model.find_children("*", "MeshInstance3D", true, false):
			if not mi.has_meta("donor"):
				(mi as MeshInstance3D).visible = false
		for mi in ch.worn_meshes():
			mi.visible = true
		ch.rotation_degrees.y = 180.0 + 28.0 if p_slot == "back" else 28.0
		ch.rotation_degrees.x = 8.0 if p_slot != "back" else 0.0
		return ch

	## World-space bounds of the visible meshes under `n` (`worn`: only donor pieces).
	func _bounds(n: Node, worn: bool, rel: Variant = null) -> AABB:
		var out := AABB()
		var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if not m.visible or m.mesh == null:
				continue
			if worn and not m.has_meta("donor") and not _under_donor(m):
				continue
			var xf: Transform3D = (rel as Transform3D) * _local_xf(m, n) if rel is Transform3D else m.global_transform
			var bb := xf * m.get_aabb()
			if m.skin != null and m.skeleton != NodePath():
				bb = _skinned_bounds(m)
			if first:
				out = bb
				first = false
			else:
				out = out.merge(bb)
		return out

	func _under_donor(m: Node) -> bool:
		var p := m.get_parent()
		while p != null and not (p is Character):
			if p.has_meta("donor"):
				return true
			p = p.get_parent()
		return false

	func _local_xf(m: Node3D, root: Node) -> Transform3D:
		var xf := m.transform
		var p := m.get_parent()
		while p != null and p != root and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		return xf

	## Bounds of a skinned mesh in its posed position: its vertices moved by the bound bones.
	func _skinned_bounds(m: MeshInstance3D) -> AABB:
		var skel := m.get_node_or_null(m.skeleton) as Skeleton3D
		if skel == null:
			return m.global_transform * m.get_aabb()
		var skin := m.skin
		var out := AABB()
		var first := true
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			if bones.is_empty():
				continue
			var per := bones.size() / maxi(verts.size(), 1)
			var step := maxi(1, verts.size() / 400)
			for i in range(0, verts.size(), step):
				var v := verts[i]
				var best := 0
				for j in per:
					if weights[i * per + j] > weights[i * per + best]:
						best = j
				var bi := bones[i * per + best]
				if bi >= skin.get_bind_count():
					continue
				var bone := skel.find_bone(skin.get_bind_name(bi)) if skin.get_bind_name(bi) != &"" else skin.get_bind_bone(bi)
				if bone < 0:
					continue
				var p := skel.global_transform * skel.get_bone_global_pose(bone) * skin.get_bind_pose(bi) * v
				if first:
					out = AABB(p, Vector3.ZERO)
					first = false
				else:
					out = out.expand(p)
		return out if not first else m.global_transform * m.get_aabb()
