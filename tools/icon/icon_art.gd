extends Control
## App-icon art, rendered in-engine from the game's real assets (DieVisual + die shader,
## KayKit characters, board tiles). One Control fills the window; a SubViewport draws the 3D
## scene on a big lit floor plane (radial-gradient shader) that fills the frame, so every object
## rests ON a surface and casts a real shadow (the rejected v1 icon had dice sunk into a tile).
##
## `concept` picks the composition (see CONCEPTS). tools/icon_scenarios.gd exposes each as a
## scenario: app_icon (the final pick), icon_<concept> for the exploration sheet.
## Render square & in the background only:  tools/shoot.sh icon_hero /abs/out.png 1024x1024 --wait=2

const CONCEPTS := ["hero", "hero_dark", "solo", "tumble", "doubles", "knight", "orbit", "tile"]
## The 3D pick (scenario `app_icon`). Exploration only: the shipped icon is tools/icon/monogram.py.
const FINAL := "hero"

const INK := Color(0.043, 0.047, 0.1)
const OUTLINE_SHADER := preload("res://tools/icon/ink_outline.gdshader")

var concept := FINAL
var vp: SubViewport
var cam: Camera3D
var env: Environment
var _poses: Array = []  # [Character, clip, time]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(svc)
	vp = SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_8X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	vp.own_world_3d = true
	svc.add_child(vp)
	_base_world()
	call(&"_c_" + concept)
	_freeze_poses.call_deferred()


# --- shared rig ------------------------------------------------------------------------

func _base_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = INK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.7)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	cam = Camera3D.new()
	cam.fov = 28.0
	vp.add_child(cam)


## Camera + backdrop quad locked to the camera (fills the frame at distance `d`).
func _camera(from: Vector3, at: Vector3, fov := 28.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, at)


func _light(dir: Vector3, color: Color, energy: float, shadows := false) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.shadow_enabled = shadows
	l.shadow_blur = 1.5
	vp.add_child(l)
	l.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	return l


## A die: `rune` look, face `slot` up, extra tilt (euler radians), world position, scale.
## glow = gold marked-die shell (0..1.5), ink = dark sticker outline width (0 = none).
func _die(rune: String, slot: int, pos: Vector3, tilt: Vector3, s := 1.0, glow := 0.0,
		ink := 0.035, faces := [1, 2, 3, 4, 5, 6], glow_color := DieVisual.GLOW_COLOR) -> DieVisual:
	var d := DieVisual.new()
	vp.add_child(d)
	d.set_data({"faces": faces, "rune": rune})
	d.ring.visible = false
	d.position = pos
	d.scale = Vector3.ONE * s
	d.body.basis = Basis.from_euler(tilt) * DieMesh.up_basis(slot)
	d.set_process(false)
	d.outline.set_shader_parameter("strength", glow)
	d.outline.set_shader_parameter("color", glow_color)
	d.outline.set_shader_parameter("width", 0.05)
	d.mat.set_shader_parameter("glow", glow * 0.25)
	if ink > 0.0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("width", ink)
		o.set_shader_parameter("color", INK)
		o.render_priority = -2
		d.outline.next_pass = o
	return d


## Adds an ink outline pass to every mesh under `n` (props, characters).
func _ink(n: Node, width := 0.02) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var base := mi.get_active_material(s)
				if base == null:
					continue
				var m := base.duplicate() as Material
				var o := ShaderMaterial.new()
				o.shader = OUTLINE_SHADER
				o.set_shader_parameter("width", width)
				o.set_shader_parameter("color", INK)
				m.next_pass = o
				mi.set_surface_override_material(s, m)
	for c in n.get_children():
		_ink(c, width)


## A board tile: plinth + coloured inset top, like BoardView._build_tile.
func _tile(pos: Vector3, top_color: Color, base_color := Color(0.8, 0.62, 0.34), w := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	vp.add_child(root)
	var base := Props.inst(BoardView.TILE_MESH)
	base.scale = Vector3(2.02 * w, 1.9, 2.02 * w)
	Props.tint(base, base_color, 1.0)
	root.add_child(base)
	var top := Props.inst(BoardView.TILE_MESH)
	top.scale = Vector3(1.7 * w, 0.75, 1.7 * w)
	var aabb := Props.world_aabb(base)
	top.position.y = aabb.end.y - root.position.y - 0.08
	Props.tint(top, top_color, 1.0)
	root.add_child(top)
	root.set_meta("top_y", aabb.end.y - pos.y + 0.0)
	return root


func _character(id: String, clip: String, t: float, pos: Vector3, yaw: float, s: float) -> Character:
	var c := Character.create(id)
	vp.add_child(c)
	c.position = pos
	c.rotation.y = deg_to_rad(yaw)
	c.scale = Vector3.ONE * s
	_poses.append([c, clip, t])
	return c


func _freeze_poses() -> void:
	for p in _poses:
		var c: Character = p[0]
		var clip := c.resolve(p[1])
		c.anim_player.play(clip, 0.0)
		c.anim_player.seek(p[2], true)
		c.anim_player.pause()


## Additive glow disc (soft halo) facing the camera.
func _halo(pos: Vector3, size: float, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = Props.particle_texture("dot")
	mat.albedo_color = color
	mat.no_depth_test = false
	var q := MeshInstance3D.new()
	q.mesh = Props.quad(size)
	q.material_override = mat
	q.position = pos
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(q)


func _glow_ring(pos: Vector3, size: float, color: Color, strength := 1.2) -> void:
	var ring := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	ring.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/dice/ring.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("strength", strength)
	ring.material_override = m
	ring.position = pos
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(ring)


# --- grounded rig (v2) ---------------------------------------------------------------------
# Every object rests ON the floor (or the thing below it) with a real shadow: dice use
# DieMesh.support_down() so a tilted die touches the surface with its lowest point exactly.

const FLOOR_SHADER := preload("res://tools/icon/floor.gdshader")


## A big lit ground plane that fills the frame (receives shadows), radial inner -> outer.
func _floor(inner: Color, outer: Color, radius := 6.0, y := 0.0, falloff := 1.4) -> void:
	var f := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	f.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = FLOOR_SHADER
	m.set_shader_parameter("inner", inner)
	m.set_shader_parameter("outer", outer)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("falloff", falloff)
	f.material_override = m
	f.position.y = y
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(f)


func _key(dir: Vector3, color: Color, energy: float) -> DirectionalLight3D:
	var l := _light(dir, color, energy, true)
	l.shadow_blur = 2.2
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	l.directional_shadow_max_distance = 30.0
	l.shadow_bias = 0.02
	l.shadow_normal_bias = 0.6
	return l


## A die resting on the surface at height `y`: face `slot` up, yawed, optionally tipped
## (tilt = rotation about the die's own axes before it rests; the lowest point touches y).
## `lift` raises it off the surface on purpose (mid-bounce).
func _die_on(rune: String, slot: int, x: float, z: float, y: float, yaw: float, s := 1.0,
		tilt := Vector3.ZERO, lift := 0.0, glow := 0.0, ink := 0.0) -> DieVisual:
	var d := _die(rune, slot, Vector3(x, y, z), Vector3.ZERO, s, glow, ink)
	d.body.basis = Basis(Vector3.UP, yaw) * Basis.from_euler(tilt) * DieMesh.up_basis(slot)
	d.pivot.position.y = DieMesh.support_down(d.body.basis) + lift
	return d


# --- concepts -------------------------------------------------------------------------------

## G1 Solo: one big cream die resting on a warm gold floor, three faces visible (5 / 3 / 2).
func _c_solo() -> void:
	_camera(Vector3(0, 5.4, 6.0), Vector3(0, 0.6, 0), 26.0)
	_floor(Color(1.0, 0.72, 0.3), Color(0.72, 0.3, 0.12), 5.5)
	_key(Vector3(0.55, -1.0, -0.35), Color(1.0, 0.95, 0.86), 1.5)
	_light(Vector3(-0.6, -0.3, 0.8), Color(1.0, 0.8, 0.55), 0.5)
	_die_on("", 4, 0, 0, 0, 0.62, 1.55)


## G2 Tumble: a single die mid-bounce on one edge, its shadow below it, over a navy floor.
func _c_tumble() -> void:
	_camera(Vector3(0, 5.0, 7.2), Vector3(0, 1.0, 0), 28.0)
	_floor(Color(0.13, 0.14, 0.34), Color(0.03, 0.035, 0.09), 6.0)
	_key(Vector3(0.2, -1.0, -0.25), Color(1.0, 0.95, 0.86), 1.6)
	_light(Vector3(-0.6, -0.2, 0.8), Color(1.0, 0.7, 0.35), 0.7)
	_die_on("", 4, 0, 0, 0, 0.5, 1.45, Vector3(0.0, 0.0, 0.62), 0.55, 0.5)


## G3 Doubles: two dice resting side by side on navy felt, both showing five, gold rings under.
func _c_doubles() -> void:
	_camera(Vector3(0, 6.0, 5.2), Vector3(0, 0.35, 0), 25.0)
	_floor(Color(0.12, 0.13, 0.32), Color(0.03, 0.035, 0.09), 5.0)
	_key(Vector3(0.45, -1.0, -0.45), Color(1.0, 0.95, 0.86), 1.5)
	_light(Vector3(-0.6, -0.3, 0.8), Color(1.0, 0.72, 0.4), 0.6)
	_glow_ring(Vector3(-0.72, 0.01, 0.1), 2.0, Color(1.0, 0.78, 0.35), 0.55)
	_glow_ring(Vector3(0.72, 0.01, -0.1), 2.0, Color(1.0, 0.78, 0.35), 0.55)
	_die_on("", 4, -0.72, 0.1, 0, 0.35, 1.1)
	_die_on("blade", 4, 0.72, -0.1, 0, -0.3, 1.1)


## G4 Hero: the knight standing on top of a giant die (the die is his stage), cheering.
func _c_knight() -> void:
	_camera(Vector3(0.0, 5.4, 9.6), Vector3(0, 2.02, 0), 27.0)
	_floor(Color(0.95, 0.5, 0.2), Color(0.42, 0.1, 0.12), 6.0)
	_key(Vector3(0.45, -1.0, -0.55), Color(1.0, 0.95, 0.86), 1.5)
	_light(Vector3(-0.5, -0.2, -0.9), Color(1.0, 0.75, 0.45), 0.7)
	_light(Vector3(0.2, -0.3, 1.0), Color(1.0, 0.85, 0.6), 0.8)  # rim
	var s := 1.85
	_die_on("", 4, 0, 0, 0, 0.62, s, Vector3.ZERO, 0.0, 0.0, 0.03)
	var k := _character("knight", "cheer", 0.55, Vector3(0.0, s, 0.05), 14.0, 0.92)
	_ink(k, 0.014)


## THE PICK. The hero standing on a giant die: the die is his stage (you roll to move),
## brand navy with a warm gold pool of light, everything grounded with real shadows.
## dark = iOS dark-appearance variant (near-black stage, dimmer pool).
func _c_hero(dark := false) -> void:
	_camera(Vector3(0.0, 4.7, 9.6), Vector3(0, 2.02, 0), 30.0)
	if dark:
		_floor(Color(0.62, 0.4, 0.17), Color(0.02, 0.02, 0.035), 3.4, 0.0, 0.7)
		env.ambient_light_color = Color(0.5, 0.48, 0.6)
	else:
		_floor(Color(1.0, 0.7, 0.3), Color(0.09, 0.1, 0.27), 3.9, 0.0, 0.75)
		env.ambient_light_color = Color(0.6, 0.58, 0.78)
	# soft gold halo behind the hero's head: separates the grey helmet from the navy
	_halo(Vector3(0.0, 3.25, -2.2), 4.3, Color(1.0, 0.8, 0.42, 0.3 if dark else 0.36))
	# key from the front-right, above: shadows fall to the back-left onto the floor
	_key(Vector3(-0.45, -1.0, -0.2), Color(1.0, 0.94, 0.84), 1.1)
	_light(Vector3(0.7, -0.3, -0.6), Color(1.0, 0.78, 0.5), 0.5)
	_light(Vector3(-0.2, -0.35, 1.0), Color(0.7, 0.8, 1.0), 1.15)  # cool back rim
	var s := 1.62
	# yaw 45 deg: two equal faces, the widest (most solid) die silhouette
	_die_on("", 4, 0, 0, 0, deg_to_rad(39.0), s)
	var k := _character("knight", "cheer", 0.55, Vector3(0.0, s, 0.0), 14.0, 1.12)
	_ink(k, 0.018)


func _c_hero_dark() -> void:
	_c_hero(true)


## Orbit: the looping board as a ring of chunky tiles, one die resting in the middle.
func _c_orbit() -> void:
	_camera(Vector3(0, 8.4, 7.2), Vector3(0, -0.1, 0.2), 30.0)
	_floor(Color(0.13, 0.14, 0.34), Color(0.03, 0.035, 0.09), 5.5, -0.5)
	_key(Vector3(0.45, -1.0, -0.45), Color(1.0, 0.95, 0.86), 1.4)
	_light(Vector3(-0.6, -0.3, 0.8), Color(1.0, 0.72, 0.4), 0.5)
	var types := ["treasury", "enemy", "chest", "event", "treasury", "enemy", "chest", "event"]
	var n := types.size()
	for i in n:
		var a := TAU * float(i) / n + PI * 0.5
		var p := Vector3(cos(a) * 2.15, -0.5, sin(a) * 2.15)
		var t := _tile(p, TileStyle.color(types[i]), Color(0.36, 0.3, 0.42), 0.46)
		t.rotation.y = -a
	_die_on("", 4, 0, 0, -0.5, 0.62, 1.5)


## G5 Tile: one die resting squarely on a chunky board tile (die bottom == tile top).
func _c_tile() -> void:
	_camera(Vector3(0, 5.6, 5.8), Vector3(0, 0.5, 0), 26.0)
	_floor(Color(0.12, 0.13, 0.32), Color(0.03, 0.035, 0.09), 5.0, -0.9)
	_key(Vector3(0.45, -1.0, -0.4), Color(1.0, 0.95, 0.86), 1.5)
	_light(Vector3(-0.6, -0.3, 0.8), Color(1.0, 0.72, 0.4), 0.6)
	var t := _tile(Vector3(0, -0.9, 0), Color(0.16, 0.6, 0.62), Color(0.5, 0.33, 0.18), 1.35)
	var top_y := _top_y(t)
	_die_on("", 4, 0, 0, top_y, 0.6, 1.25)


## Highest world y of any mesh under `n` (the surface a die can rest on).
func _top_y(n: Node) -> float:
	var y := -INF
	for c in n.get_children():
		if c is MeshInstance3D:
			y = maxf(y, Props.world_aabb(c).end.y)
		y = maxf(y, _top_y(c))
	return y
