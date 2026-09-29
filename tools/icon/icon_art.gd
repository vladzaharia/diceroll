extends Control
## App-icon art, rendered in-engine from the game's real assets (DieVisual + die shader,
## KayKit characters/props/tiles). One Control fills the window; a SubViewport draws the
## 3D scene over a camera-locked gradient backdrop (so glow/tonemap see the real background).
##
## `concept` picks the composition (see CONCEPTS). tools/icon_scenarios.gd exposes each as a
## scenario: app_icon (the final pick), icon_<concept> for the exploration sheet.
## Render square & in the background only:  tools/shoot.sh icon_hero /abs/out.png 1024x1024 --wait=2

const CONCEPTS := ["hero", "doubles", "knight", "tile", "sword", "trails", "doubles_dark"]
## The concept the shipped icon uses (scenario `app_icon`).
const FINAL := "doubles"

const INK := Color(0.043, 0.047, 0.1)
const OUTLINE_SHADER := preload("res://tools/icon/ink_outline.gdshader")
const BACKDROP_SHADER := preload("res://tools/icon/backdrop.gdshader")

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


func _backdrop(inner: Color, mid: Color, outer: Color, center := Vector2(0.5, 0.45), radius := 0.62,
		mid_at := 0.35, rays := 0.0, ray_strength := 0.0, vignette := 0.35) -> void:
	var d := 60.0
	var h := 2.0 * d * tan(deg_to_rad(cam.fov * 0.5)) * 1.02
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(h, h)
	q.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = BACKDROP_SHADER
	m.render_priority = -100
	m.set_shader_parameter("inner", inner)
	m.set_shader_parameter("mid", mid)
	m.set_shader_parameter("outer", outer)
	m.set_shader_parameter("center", Vector2(center.x, center.y))
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("mid_at", mid_at)
	m.set_shader_parameter("rays", rays)
	m.set_shader_parameter("ray_strength", ray_strength)
	m.set_shader_parameter("vignette", vignette)
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = Vector3(0, 0, -d)
	cam.add_child(q)


func _light(dir: Vector3, color: Color, energy: float, shadows := false) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.shadow_enabled = shadows
	l.shadow_blur = 1.5
	vp.add_child(l)
	l.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	return l


func _omni(pos: Vector3, color: Color, energy: float, rng := 5.0) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.light_color = color
	o.light_energy = energy
	o.omni_range = rng
	o.position = pos
	vp.add_child(o)
	return o


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


func _prop(path: String, pos: Vector3, yaw := 0.0, s := 1.0) -> Node3D:
	var root := Node3D.new()
	vp.add_child(root)
	return Props.put(root, path, pos, yaw, s)


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


func _sparkles(center: Vector3, radius: float, count: int, color: Color, size := 0.08, seed := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = Props.particle_texture("spark")
	mat.albedo_color = color * 2.2
	for i in count:
		var q := MeshInstance3D.new()
		q.mesh = Props.quad(size * rng.randf_range(0.6, 1.5))
		q.material_override = mat
		var a := rng.randf() * TAU
		var r := radius * sqrt(rng.randf_range(0.35, 1.0))
		q.position = center + Vector3(cos(a) * r, sin(a) * r * 0.9, rng.randf_range(-0.3, 0.3))
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vp.add_child(q)


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


# --- concepts ---------------------------------------------------------------------------
# Face slots: DieMesh.up_basis(slot) shows face `slot` (value slot+1 on a 1..6 die) on top.

## A: one hero die, gold-rimmed, on a navy field with a warm gold burst.
func _c_hero() -> void:
	_camera(Vector3(0, 2.2, 6.2), Vector3(0, 0.02, 0))
	_backdrop(Color(1.0, 0.78, 0.36), Color(0.55, 0.25, 0.3), Color(0.06, 0.06, 0.16), Vector2(0.5, 0.48), 0.7, 0.3, 12.0, 0.18)
	_light(Vector3(0.5, -0.9, -0.6), Color(1.0, 0.94, 0.84), 1.5)
	_light(Vector3(-0.6, -0.2, 0.9), Color(1.0, 0.7, 0.35), 1.1)
	_light(Vector3(0.8, 0.1, 0.5), Color(0.5, 0.6, 1.0), 0.6)
	var d := _die("", 5, Vector3(0, -0.52, 0), Vector3(0.36, 0.72, -0.2), 1.75, 0.9)
	d.pivot.position.y = 0.5


## B: doubles (the pick). A red Blade die and a gilded die both showing six, on a teal
## board tile (teal separates from red + gold at 29 px), gold burst over navy-plum.
func _c_doubles(dark := false) -> void:
	_camera(Vector3(0, 6.3, 6.7), Vector3(0, 0.32, 0.05), 25.0)
	if dark:
		_backdrop(Color(0.2, 0.14, 0.1), Color(0.06, 0.05, 0.1), Color(0.02, 0.02, 0.04), Vector2(0.5, 0.36), 0.8, 0.3, 0.0, 0.0, 0.3)
	else:
		_backdrop(Color(1.0, 0.72, 0.34), Color(0.24, 0.16, 0.38), Color(0.035, 0.04, 0.12), Vector2(0.5, 0.36), 0.8, 0.3, 14.0, 0.09, 0.5)
	_light(Vector3(0.4, -1.0, -0.55), Color(1.0, 0.93, 0.82), 1.35, true)
	_light(Vector3(-0.3, -0.25, 1.0), Color(1.0, 0.68, 0.32), 1.2)
	_light(Vector3(0.9, -0.15, 0.3), Color(0.45, 0.55, 1.0), 0.55)
	_light(Vector3(0.0, -0.35, 1.0).rotated(Vector3.UP, PI), Color(1.0, 0.85, 0.6), 0.9)  # back rim
	var t := _tile(Vector3(0, -0.5, 0), Color(0.16, 0.6, 0.62), Color(0.5, 0.33, 0.18), 1.3)
	var y: float = t.position.y + float(t.get_meta("top_y")) - 0.05
	_die("blade", 5, Vector3(-0.68, y, 0.16), Vector3(0, 0.36, 0), 1.06, 0.7)
	_die("gilded", 5, Vector3(0.68, y, -0.12), Vector3(0, -0.3, 0), 1.06, 0.7)
	if dark:
		return
	_sparkles(Vector3(0, y + 1.5, -0.6), 1.25, 9, Color(1.0, 0.82, 0.45), 0.2)


## C: the knight cheering under a big glowing die.
## iOS 18 dark-appearance variant of the pick: same objects, near-black field, no burst.
func _c_doubles_dark() -> void:
	_c_doubles(true)


func _c_knight() -> void:
	_camera(Vector3(0.2, 1.9, 6.4), Vector3(0, 1.45, 0), 30.0)
	_backdrop(Color(1.0, 0.76, 0.36), Color(0.5, 0.22, 0.28), Color(0.05, 0.05, 0.14), Vector2(0.5, 0.3), 0.75, 0.3)
	_light(Vector3(0.4, -0.8, -0.7), Color(1.0, 0.93, 0.84), 1.5, true)
	_light(Vector3(-0.3, -0.3, 1.0), Color(1.0, 0.7, 0.35), 1.4)
	_light(Vector3(0.9, 0.0, 0.3), Color(0.45, 0.55, 1.0), 0.6)
	var k := _character("knight", "cheer", 0.55, Vector3(0, -0.2, 0.3), 12.0, 1.05)
	_ink(k, 0.012)
	_die("", 4, Vector3(0.05, 2.02, -0.3), Vector3(0.45, 0.6, -0.25), 1.05, 1.1)
	_halo(Vector3(0.05, 2.6, -0.6), 3.2, Color(1.0, 0.7, 0.3, 0.55))


## D: a die bouncing onto a red enemy tile guarded by a skull.
func _c_tile() -> void:
	_camera(Vector3(0, 4.2, 6.0), Vector3(0, 0.7, 0), 28.0)
	_backdrop(Color(0.55, 0.45, 0.85), Color(0.2, 0.16, 0.4), Color(0.04, 0.04, 0.12), Vector2(0.5, 0.35), 0.8, 0.35)
	_light(Vector3(0.45, -1.0, -0.5), Color(1.0, 0.93, 0.82), 1.6, true)
	_light(Vector3(-0.5, -0.3, 1.0), Color(1.0, 0.6, 0.35), 1.0)
	var t := _tile(Vector3(0, -0.5, 0.2), TileStyle.color("enemy"), Color(0.46, 0.42, 0.42), 1.3)
	var y: float = t.position.y + float(t.get_meta("top_y")) - 0.05
	var sk := _prop(Props.HAL + "skull.gltf", Vector3(0.55, y, 0.55), -25.0, 1.1)
	_ink(sk, 0.02)
	_die("", 5, Vector3(-0.4, y + 1.1, -0.2), Vector3(0.5, 0.4, 0.6), 1.15, 0.9)


## E: a crest: a die with a sword crossed behind it.
func _c_sword() -> void:
	_camera(Vector3(0, 0.4, 7.0), Vector3(0, 0.1, 0), 28.0)
	_backdrop(Color(0.3, 0.33, 0.72), Color(0.12, 0.13, 0.32), Color(0.04, 0.04, 0.1), Vector2(0.5, 0.5), 0.7, 0.3, 0.0, 0.0, 0.5)
	_light(Vector3(0.4, -0.8, -0.8), Color(1.0, 0.93, 0.84), 1.6)
	_light(Vector3(-0.6, -0.2, 0.8), Color(1.0, 0.72, 0.35), 1.2)
	var sw := _prop(Character.ADV + "weapons/sword_1handed.gltf", Vector3(0, 0, -0.8), 0.0, 3.0)
	sw.rotation = Vector3(0, PI * 0.5, deg_to_rad(-45))
	sw.position = Vector3(0.9, -1.1, -0.9)
	_ink(sw, 0.012)
	_die("gilded", 5, Vector3(0, -0.6, 0), Vector3(0.5, 0.7, -0.3), 1.45, 0.6)


## F: two rune dice tumbling in with glowing motion trails.
func _c_trails() -> void:
	_camera(Vector3(0, 1.6, 7.0), Vector3(0, 0.2, 0), 28.0)
	_backdrop(Color(0.35, 0.2, 0.55), Color(0.13, 0.1, 0.3), Color(0.03, 0.03, 0.09), Vector2(0.5, 0.45), 0.8, 0.35)
	_light(Vector3(0.4, -0.8, -0.7), Color(1.0, 0.93, 0.84), 1.4)
	_light(Vector3(-0.5, -0.2, 0.9), Color(0.9, 0.7, 1.0), 0.9)
	var a := _die("ember", 5, Vector3(-0.6, -0.65, 0.3), Vector3(0.5, 0.6, -0.4), 1.25, 1.0, 0.035, [1, 2, 3, 4, 5, 6], Color(1.0, 0.55, 0.15))
	var b := _die("frost", 5, Vector3(0.75, 0.35, -0.6), Vector3(-0.3, 1.1, 0.5), 1.0, 1.0, 0.035, [1, 2, 3, 4, 5, 6], Color(0.5, 0.85, 1.0))
	_trail(a.position + Vector3(0, 0.5 * 1.25, 0), Vector3(-1, 0.55, 0).normalized(), Color(1.0, 0.5, 0.15), 1.1)
	_trail(b.position + Vector3(0, 0.5, 0), Vector3(-1, 0.6, 0).normalized(), Color(0.45, 0.8, 1.0), 0.9)


func _trail(from: Vector3, dir: Vector3, color: Color, w: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := Vector3(-dir.y, dir.x, 0).normalized()
	var n := 3
	for k in n:
		var off := side * (float(k) - 1.0) * w * 0.34
		var ww := w * (0.16 if k != 1 else 0.24)
		var p0 := from + off
		var p1 := from + off + dir * (3.2 - absf(float(k) - 1.0) * 0.8)
		var c0 := Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.9)
		var c1 := Color(color.r, color.g, color.b, 0.0)
		var v := [p0 - side * ww, p0 + side * ww, p1 + side * ww * 0.2, p1 - side * ww * 0.2]
		var cs := [c0, c0, c1, c1]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(cs[i])
			st.add_vertex(v[i] + Vector3(0, 0, -0.9))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(mi)
