class_name RenderedIcons
extends RefCounted
## "Rendered" UI icons: select KayKit 3D props (coins, gold bars, gems, chests, potions, keys)
## rendered to transparent PNGs, for spots where a real object reads richer than a flat glyph
## (currency counters, reward cards, the shop). The clean vector set (UiIcons) stays the
## default everywhere else; call sites opt in with a "3d:" prefix, which falls back to the
## matching vector glyph when a PNG is missing (fresh clone, EXTRA packs absent):
##
##   UiIcons.rect("3d:coins", 40)       # rendered coin pile, or the "coin" glyph
##
## The PNGs are derived from (partly paid) KayKit models, so they are git-ignored like the
## models themselves. Rebuild them after tools/import_assets.sh with:
##   tools/render_icons.sh               # = tools/shoot.sh render_icons ... + godot --import
## The render_icons scenario renders every SPECS entry into ui/icons/rendered/<id>.png
## (256 px, transparent) and shows them on a contact sheet for the screenshot.

const DIR := "res://ui/icons/rendered/"
const K := "res://assets/kaykit/"
const PX := 256

## id -> parts ([model path under K, position, yaw deg, scale]; the first model found in
## `alt` replaces a missing one), camera yaw / pitch (deg) and the vector fallback glyph.
const SPECS := {
	"coins": {"parts": [["dungeon/coin_stack_medium.gltf", Vector3.ZERO, 20.0, 1.0]],
		"yaw": 20.0, "pitch": 34.0, "fallback": "coin"},
	"gold_bars": {"parts": [["resources/Gold_Bars_Stack_Small.gltf", Vector3.ZERO, 25.0, 1.0]],
		"alt": "dungeon/coin_stack_large.gltf", "yaw": 30.0, "pitch": 30.0, "fallback": "chest"},
	"gem": {"parts": [["resources/Gem_Large.gltf", Vector3(0, 0.375, 0), 20.0, 1.0]], "yaw": 0.0, "pitch": 10.0, "fallback": "star"},
	"gems": {"parts": [["resources/Gems_Pile_Small.gltf", Vector3.ZERO, 0.0, 1.0]], "yaw": 30.0, "pitch": 32.0, "fallback": "star"},
	"chest": {"parts": [["dungeon_x/chest_large_gold.gltf", Vector3.ZERO, -25.0, 1.0]],
		"alt": "dungeon/chest_gold.gltf", "yaw": 0.0, "pitch": 24.0, "fallback": "chest"},
	"chest_gems": {"parts": [["resources/Gems_Chest.gltf", Vector3.ZERO, -25.0, 1.0]],
		"alt": "dungeon/chest.gltf", "yaw": 0.0, "pitch": 26.0, "fallback": "chest"},
	"potion_red": {"parts": [["potions/potion_medium_red.gltf", Vector3.ZERO, 20.0, 1.0]], "yaw": 0.0, "pitch": 14.0, "fallback": "potion"},
	"potion_blue": {"parts": [["potions/potion_medium_blue.gltf", Vector3.ZERO, 20.0, 1.0]], "yaw": 0.0, "pitch": 14.0, "fallback": "potion"},
	"potion_green": {"parts": [["potions/potion_medium_green.gltf", Vector3.ZERO, 20.0, 1.0]], "yaw": 0.0, "pitch": 14.0, "fallback": "potion"},
	"key": {"parts": [["dungeon_x/key_gold.gltf", Vector3.ZERO, 0.0, 1.0]], "alt": "dungeon/key.gltf",
		"yaw": 0.0, "pitch": 5.0, "roll": -35.0, "fallback": "star"},
}

static var _tex: Dictionary = {}
static var _sized: Dictionary = {}


static func ids() -> PackedStringArray:
	return PackedStringArray(SPECS.keys())


static func path_of(id: String) -> String:
	return DIR + id + ".png"


## Rendered texture for `id`, or null when it has not been rendered / imported.
static func texture(id: String) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	var t: Texture2D = null
	var p := path_of(id)
	if ResourceLoader.exists(p):
		t = load(p)
	_tex[id] = t
	return t


## The rendered icon resampled (Lanczos) to `px`, so small UI sizes stay clean without
## mipmaps (the canvas filter is plain linear). Null when not rendered.
static func texture_at(id: String, px: int) -> Texture2D:
	var key := "%s|%d" % [id, px]
	if _sized.has(key):
		return _sized[key]
	var t := texture(id)
	var out: Texture2D = null
	if t != null:
		var img := t.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			img = _tight(img)
			var s := clampi(px, 8, PX)
			if s != img.get_width():
				img.resize(s, s, Image.INTERPOLATE_LANCZOS)
			out = ImageTexture.create_from_image(img)
		else:
			out = t
	_sized[key] = out
	return out


## Crops to the opaque pixels and re-centres them in a square, so flat objects (a coin
## pile) fill a UI slot as well as tall ones (a potion).
static func _tight(img: Image) -> Image:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var r := img.get_used_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		return img
	var side := maxi(r.size.x, r.size.y) + 4
	var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(img, r, Vector2i((side - r.size.x) / 2, (side - r.size.y) / 2))
	return out


## Vector glyph to show instead when the PNG is missing.
static func fallback(id: String) -> String:
	return String(SPECS.get(id, {}).get("fallback", "star"))


# ------------------------------------------------------------------------------------ render

## Scenario provider hook (tools/scenarios.gd): "render_icons".
static func names() -> PackedStringArray:
	return PackedStringArray(["render_icons"])


static func build(name: String) -> Node:
	if name != "render_icons":
		return null
	return _Renderer.new()


## Builds one icon's 3D set: the props (centred on their bounds), lights and a camera.
static func make_stage(id: String) -> Node3D:
	var spec: Dictionary = SPECS[id]
	var root := Node3D.new()
	var props := Node3D.new()
	root.add_child(props)
	for part: Array in spec.parts:
		var path := K + String(part[0])
		if not ResourceLoader.exists(path):
			if spec.has("alt") and ResourceLoader.exists(K + String(spec.alt)):
				path = K + String(spec.alt)
			else:
				continue
		var n: Node3D = (load(path) as PackedScene).instantiate()
		n.position = part[1]
		n.rotation.y = deg_to_rad(float(part[2]))
		n.scale = Vector3.ONE * float(part[3])
		props.add_child(n)
		if path == K + String(spec.get("alt", "")):
			break
	props.rotation.z = deg_to_rad(float(spec.get("roll", 0.0)))
	return root


class _Renderer:
	extends Control
	## Renders every icon in a transparent SubViewport, saves the PNGs, shows a sheet.

	var _grid: GridContainer

	func _ready() -> void:
		UiTheme.full_rect(self)
		var bg := ColorRect.new()
		bg.color = Color(0.09, 0.08, 0.16)
		add_child(UiTheme.full_rect(bg))
		_grid = GridContainer.new()
		_grid.columns = 4
		_grid.add_theme_constant_override("h_separation", 16)
		_grid.add_theme_constant_override("v_separation", 16)
		_grid.position = Vector2(24, 24)
		add_child(_grid)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
		for id in RenderedIcons.ids():
			var img := await _render(id)
			if img == null:
				continue
			var out := ProjectSettings.globalize_path(RenderedIcons.path_of(id))
			img.save_png(out)
			print("RENDERED_ICON ", out)
			var col := UiTheme.vbox(4)
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.custom_minimum_size = Vector2(150, 150)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			col.add_child(tr)
			var small := HBoxContainer.new()
			for px in [24, 36, 48]:
				var s := TextureRect.new()
				s.texture = tr.texture
				s.custom_minimum_size = Vector2(px, px)
				s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				small.add_child(s)
			col.add_child(small)
			col.add_child(UiTheme.label(id, 18))
			_grid.add_child(col)

	func _render(id: String) -> Image:
		var spec: Dictionary = RenderedIcons.SPECS[id]
		var vp := SubViewport.new()
		vp.size = Vector2i(RenderedIcons.PX, RenderedIcons.PX)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var stage := RenderedIcons.make_stage(id)
		vp.add_child(stage)
		var props: Node3D = stage.get_child(0)
		if props.get_child_count() == 0:
			vp.queue_free()
			return null
		# lights + flat ambient (no sky, so the background stays transparent)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.7, 0.68, 0.85)
		e.ambient_light_energy = 0.42
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.environment = e
		stage.add_child(env)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-48, 40, 0)
		key.light_energy = 1.25
		key.shadow_enabled = true
		stage.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-20, 200, 0)
		rim.light_energy = 0.7
		rim.light_color = Color(0.85, 0.8, 1.0)
		stage.add_child(rim)
		# frame the props' bounds (perspective, 3/4 view)
		var box := _bounds(props)
		var cam := Camera3D.new()
		cam.fov = 22.0
		stage.add_child(cam)
		var pts := PackedVector3Array()
		for i in 8:
			pts.append(box.get_endpoint(i))
		var xf := CameraRig.solve_framing(pts, deg_to_rad(float(spec.yaw)), deg_to_rad(float(spec.pitch)),
			Rect2(0.07, 0.07, 0.86, 0.86), Vector2(RenderedIcons.PX, RenderedIcons.PX), cam.fov)
		cam.global_transform = xf
		cam.current = true
		for i in 4:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		vp.queue_free()
		return img

	static func _bounds(n: Node3D) -> AABB:
		var box := AABB()
		var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var b := mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		return box
