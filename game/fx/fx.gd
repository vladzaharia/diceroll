class_name Fx
extends RefCounted
## One-shot and looping visual effects. Every spawner parents its nodes under `parent`
## (any Node3D in the world) and frees them when done.
##
##   Fx.damage_number(world, enemy_pos + Vector3.UP * 2.0, 17, true)
##   Fx.coin_burst(world, tile_pos, 8)
##   Fx.flash(self, Color(1, 0.9, 0.5, 0.6))      # full-screen flash (CanvasLayer)
##   await Fx.projectile(world, from, to, Color.VIOLET)

const DAMAGE_COLOR := Color(1.0, 0.96, 0.9)
const CRIT_COLOR := Color(1.0, 0.72, 0.16)
const HERO_DAMAGE_COLOR := Color(1.0, 0.36, 0.3)
const HEAL_COLOR := Color(0.45, 1.0, 0.45)
const BLOCK_COLOR := Color(0.45, 0.75, 1.0)
const GOLD := Color(1.0, 0.8, 0.25)

const STATUS_COLORS := {
	"poison": Color(0.45, 0.95, 0.3), "frost": Color(0.55, 0.9, 1.0), "frozen": Color(0.55, 0.9, 1.0),
	"ember": Color(1.0, 0.5, 0.15), "curse": Color(0.75, 0.35, 1.0), "buff": Color(1.0, 0.45, 0.3),
	"thunder": Color(1.0, 0.95, 0.4),
}


# --- floating text -------------------------------------------------------------------

## Bouncy damage number. Crits are bigger, gold and shake.
## `rise`: how far it floats up (world units); enemy hits keep it short so the number stays under
## the unit's HUD (intent badge, HP bar) instead of drifting through it.
static func damage_number(parent: Node3D, pos: Vector3, amount: int, crit := false,
		color := Color(0, 0, 0, 0), rise := 1.0) -> Label3D:
	var col := color if color.a > 0.0 else (CRIT_COLOR if crit else DAMAGE_COLOR)
	var text := str(amount) + ("!" if crit else "")
	# spec 4.2: only crits (and heals) get an icon prefix, so plain hits stay clean
	return popup_text(parent, pos, text, col, 1.3 if crit else 1.0, crit, rise, "crit" if crit else "")


## Floating label ("BLOCK", "+12", "MISS"...). size 1.0 ~ 0.55 world units tall; scaled by the
## world HUD's share of the UI size (UnitHud.world_ui_scale). `icon`: an optional pack icon
## (Icons.tex fixed raster) left of the text, only when the pack maps it.
static func popup_text(parent: Node3D, pos: Vector3, text: String, color: Color, size := 1.0,
		shake := false, rise := 1.0, icon := "") -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Props.font(true)
	l.font_size = 128
	l.pixel_size = 0.005 * size * UnitHud.world_ui_scale(parent)
	l.outline_size = 30
	l.outline_modulate = Color(UnitHud.OUTLINE_COL, 0.95)
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	l.double_sided = true
	l.position = pos
	l.scale = Vector3.ONE * 0.2
	parent.add_child(l)
	if icon != "" and Icons.is_mapped(icon):
		var sp := Sprite3D.new()
		sp.texture = Icons.tex(icon, 192)
		var h := 128.0 * l.pixel_size * 0.9
		sp.pixel_size = h / 192.0
		sp.no_depth_test = true
		sp.render_priority = 21
		sp.double_sided = true
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var w := l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size
		# billboarded like the label; the offset (sprite px) is in the screen-aligned plane
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.offset = Vector2(-(w * 0.5 + h * 0.6), h * 0.05) / sp.pixel_size
		l.add_child(sp)
		var fade := sp.create_tween()
		fade.tween_property(sp, "modulate:a", 0.0, 0.3).set_delay(0.25 + 0.25)
	var drift := Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.1, 0.1)) * minf(rise, 1.0)
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector3.ONE * 1.3, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(l, "position", pos + Vector3(0, rise, 0) + drift, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.25)
	t.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.3).set_delay(0.25)
	t.tween_callback(l.queue_free)
	if shake:
		var s := l.create_tween()
		for i in 5:
			s.tween_property(l, "rotation:z", deg_to_rad(10.0 if i % 2 == 0 else -10.0), 0.04)
		s.tween_property(l, "rotation:z", 0.0, 0.04)
	return l


# --- particles -----------------------------------------------------------------------

## Generic one-shot burst. cfg keys: amount, lifetime, speed(Vector2 min/max), spread,
## gravity(Vector3), size, color / colors(PackedColorArray gradient), tex, radius, dir, damping.
static func burst(parent: Node3D, pos: Vector3, cfg: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = float(cfg.get("explosiveness", 0.95))
	p.amount = int(cfg.get("amount", 16))
	p.lifetime = float(cfg.get("lifetime", 0.7))
	p.position = pos
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = cfg.get("dir", Vector3.UP)
	pm.spread = float(cfg.get("spread", 180.0))
	var sp: Vector2 = cfg.get("speed", Vector2(2.0, 4.0))
	pm.initial_velocity_min = sp.x
	pm.initial_velocity_max = sp.y
	pm.gravity = cfg.get("gravity", Vector3(0, -6.0, 0))
	pm.damping_min = float(cfg.get("damping", 1.0))
	pm.damping_max = float(cfg.get("damping", 1.0)) * 1.5
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = float(cfg.get("radius", 0.1))
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(0.6, 0.8))
	sc.add_point(Vector2(1.0, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	if cfg.has("colors"):
		var cs: PackedColorArray = cfg["colors"]
		var offs := PackedFloat32Array()
		for i in cs.size():
			offs.append(float(i) / float(max(cs.size() - 1, 1)))
		grad.offsets = offs
		grad.colors = cs
	else:
		var c: Color = cfg.get("color", Color.WHITE)
		grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		grad.colors = PackedColorArray([c.lightened(0.4), c, Color(c, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	var size := float(cfg.get("size", 0.2))
	q.size = Vector2(size, size)
	q.material = Props.particle_material(String(cfg.get("tex", "spark")), bool(cfg.get("additive", true)))
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	parent.add_child(p)
	p.emitting = true
	_free_later(p, p.lifetime + 0.6)
	return p


static func hit_sparks(parent: Node3D, pos: Vector3, color := Color(1.0, 0.85, 0.5), amount := 18) -> void:
	burst(parent, pos, {"amount": amount, "lifetime": 0.45, "speed": Vector2(3.0, 6.5), "gravity": Vector3(0, -9, 0),
		"size": 0.28, "color": color, "tex": "spark", "damping": 4.0})
	burst(parent, pos, {"amount": 1, "lifetime": 0.18, "speed": Vector2.ZERO, "gravity": Vector3.ZERO,
		"size": 1.4, "color": Color(color, 0.9), "tex": "dot"})


## A quick crescent swipe + sparks at `pos`, oriented across `dir` (melee hits).
static func slash(parent: Node3D, pos: Vector3, dir: Vector3, color := Color(1.0, 0.95, 0.8)) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.8, 1.8)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/fx/shaders/slash.gdshader")
	m.set_shader_parameter("color", color)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var cam := parent.get_viewport().get_camera_3d()
	if cam:
		mi.global_basis = cam.global_basis
	mi.rotate_object_local(Vector3.BACK, randf_range(-0.6, 0.2))
	var t := mi.create_tween()
	t.tween_method(func(k: float) -> void: m.set_shader_parameter("progress", k), 0.0, 1.0, 0.22)
	t.tween_callback(mi.queue_free)
	hit_sparks(parent, pos, color.lerp(GOLD, 0.4), 12)


static func coin_burst(parent: Node3D, pos: Vector3, count := 8) -> void:
	for i in count:
		var c := Props.inst(Props.BGB + "coin_gold.gltf", 0.24, false)
		c.position = pos
		parent.add_child(c)
		var a := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var dist := randf_range(0.5, 1.2)
		var target := pos + Vector3(cos(a) * dist, 0.0, sin(a) * dist)
		var h := randf_range(1.0, 1.8)
		var dur := randf_range(0.5, 0.7)
		var t := c.create_tween()
		t.tween_method(func(k: float) -> void:
			if is_instance_valid(c):
				c.position = pos.lerp(target, k) + Vector3.UP * (4.0 * h * k * (1.0 - k)), 0.0, 1.0, dur)
		t.parallel().tween_property(c, "rotation", Vector3(TAU * 2.0, randf() * TAU, 0.3), dur)
		t.tween_interval(0.25)
		t.tween_property(c, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(c.queue_free)
	burst(parent, pos + Vector3.UP * 0.4, {"amount": 14, "lifetime": 0.6, "speed": Vector2(1.5, 3.5),
		"size": 0.22, "color": GOLD, "tex": "spark", "gravity": Vector3(0, -3, 0)})


static func heal_glow(parent: Node3D, pos: Vector3) -> void:
	shockwave(parent, pos + Vector3.UP * 0.05, HEAL_COLOR, 1.3)
	burst(parent, pos + Vector3.UP * 0.4, {"amount": 22, "lifetime": 1.0, "speed": Vector2(0.4, 1.2),
		"gravity": Vector3(0, 2.2, 0), "spread": 40.0, "radius": 0.5, "size": 0.26, "color": HEAL_COLOR,
		"tex": "spark", "explosiveness": 0.6})
	_glow_light(parent, pos + Vector3.UP, HEAL_COLOR, 2.5, 0.6)


static func block_flash(parent: Node3D, pos: Vector3, radius := 0.95) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/fx/shaders/shield.gdshader")
	m.set_shader_parameter("color", BLOCK_COLOR)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * 0.6
	parent.add_child(mi)
	var t := mi.create_tween()
	t.tween_property(mi, "scale", Vector3.ONE * 1.08, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.15)
	t.tween_method(func(a: float) -> void: m.set_shader_parameter("alpha", a), 1.0, 0.0, 0.35)
	t.tween_callback(mi.queue_free)
	burst(parent, pos, {"amount": 10, "lifetime": 0.4, "speed": Vector2(1.5, 3.0), "size": 0.2,
		"color": BLOCK_COLOR, "gravity": Vector3.ZERO})


## poison | frost | frozen | ember | curse | buff | thunder
static func status_burst(parent: Node3D, pos: Vector3, kind: String) -> void:
	var col: Color = STATUS_COLORS.get(kind, Color.WHITE)
	match kind:
		"poison":
			burst(parent, pos, {"amount": 16, "lifetime": 1.1, "speed": Vector2(0.3, 0.9), "spread": 50.0,
				"gravity": Vector3(0, 1.6, 0), "radius": 0.4, "size": 0.24, "color": col, "tex": "ring",
				"explosiveness": 0.5})
		"frost", "frozen":
			burst(parent, pos, {"amount": 20, "lifetime": 0.6, "speed": Vector2(2.0, 4.0),
				"gravity": Vector3(0, -2, 0), "size": 0.3, "color": col, "tex": "spark", "damping": 3.0})
			shockwave(parent, pos + Vector3.DOWN * (pos.y - 0.1) * 0.0, col, 1.2)
		"ember":
			burst(parent, pos, {"amount": 24, "lifetime": 0.9, "speed": Vector2(1.0, 3.0), "spread": 60.0,
				"gravity": Vector3(0, 2.0, 0), "size": 0.26, "color": col, "tex": "flame"})
		"thunder":
			burst(parent, pos + Vector3.UP * 1.0, {"amount": 1, "lifetime": 0.15, "speed": Vector2.ZERO,
				"gravity": Vector3.ZERO, "size": 3.0, "color": col, "tex": "dot"})
			hit_sparks(parent, pos, col, 24)
		_:
			burst(parent, pos, {"amount": 16, "lifetime": 0.8, "speed": Vector2(0.6, 1.6), "spread": 70.0,
				"gravity": Vector3(0, 1.2, 0), "size": 0.26, "color": col, "tex": "spark"})
	_glow_light(parent, pos, col, 2.0, 0.45)


static func level_up(parent: Node3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.9
	cm.height = 6.0
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/fx/shaders/beam.gdshader")
	m.set_shader_parameter("color", GOLD)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3.UP * 3.0
	mi.scale = Vector3(0.1, 1.0, 0.1)
	parent.add_child(mi)
	var t := mi.create_tween()
	t.tween_property(mi, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.6)
	t.tween_method(func(a: float) -> void: m.set_shader_parameter("alpha", a), 1.0, 0.0, 0.6)
	t.tween_callback(mi.queue_free)
	shockwave(parent, pos + Vector3.UP * 0.05, GOLD, 2.0)
	burst(parent, pos + Vector3.UP * 0.8, {"amount": 36, "lifetime": 1.3, "speed": Vector2(1.0, 3.5),
		"gravity": Vector3(0, 1.0, 0), "spread": 70.0, "radius": 0.5, "size": 0.3, "color": GOLD, "tex": "spark",
		"explosiveness": 0.7})
	_glow_light(parent, pos + Vector3.UP * 1.5, GOLD, 4.0, 1.0)


## Expanding ground ring.
static func shockwave(parent: Node3D, pos: Vector3, color: Color, radius := 1.5, time := 0.5) -> void:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(2.0, 2.0)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Props.particle_texture("ring")
	m.albedo_color = color
	m.disable_receive_shadows = true
	m.no_depth_test = false
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * 0.2
	parent.add_child(mi)
	var t := mi.create_tween()
	t.tween_property(mi, "scale", Vector3.ONE * radius, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(m, "albedo_color:a", 0.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(mi.queue_free)


## Spinning vortex disc facing +Z (portal tiles, teleports). one_shot pops in and out.
static func portal_swirl(parent: Node3D, pos: Vector3, radius := 0.8, one_shot := true,
		flat := false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/fx/shaders/swirl.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if flat:
		mi.rotation.x = -PI * 0.5
	root.add_child(mi)
	parent.add_child(root)
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.45, 1.0)
	l.light_energy = 1.2
	l.omni_range = radius * 3.5
	l.position = Vector3(0, 0, radius * 0.4) if not flat else Vector3(0, radius * 0.5, 0)
	root.add_child(l)
	if one_shot:
		root.scale = Vector3.ONE * 0.05
		var t := root.create_tween()
		t.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.5)
		t.tween_property(root, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(root.queue_free)
		burst(parent, pos, {"amount": 20, "lifetime": 0.7, "speed": Vector2(1.0, 2.5), "gravity": Vector3.ZERO,
			"size": 0.2, "colors": PackedColorArray([Color(0.8, 0.7, 1.0), Color(0.55, 0.3, 1.0), Color(0.3, 0.9, 1.0, 0.0)]),
			"tex": "spark"})
	return root


## Persistent golden sparkles around an elite (radius ~ figure footprint).
static func elite_sparkle(parent: Node3D, pos: Vector3, radius := 0.5, height := 1.2) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "EliteSparkle"
	p.amount = 14
	p.lifetime = 1.4
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = radius * 0.7
	pm.emission_ring_height = height
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.0))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color = Color(1.0, 0.85, 0.35)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.26, 0.26)
	q.material = Props.particle_material("spark")
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.preprocess = 1.5
	parent.add_child(p)
	return p


## A glowing orb that flies from -> to on an arc; await it.
static func projectile(parent: Node3D, from: Vector3, to: Vector3, color: Color, time := 0.35) -> void:
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	orb.mesh = sm
	orb.material_override = Props.glow_material(color.lightened(0.3), false, 3.0)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.position = from
	parent.add_child(orb)
	var trail := burst(orb, Vector3.ZERO, {"amount": 24, "lifetime": 0.35, "speed": Vector2(0.1, 0.4),
		"gravity": Vector3.ZERO, "size": 0.3, "color": color, "tex": "dot", "explosiveness": 0.0})
	trail.one_shot = false
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 1.5
	l.omni_range = 2.5
	orb.add_child(l)
	var t := orb.create_tween()
	t.tween_method(func(k: float) -> void:
		if is_instance_valid(orb):
			orb.position = from.lerp(to, k) + Vector3.UP * (1.2 * k * (1.0 - k)), 0.0, 1.0, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	orb.queue_free()
	hit_sparks(parent, to, color, 16)


# --- screen-level juice ----------------------------------------------------------------

## Full-screen colour flash on a top CanvasLayer (combo hook).
static func flash(any: Node, color := Color(1.0, 0.95, 0.8, 0.55), duration := 0.35) -> void:
	ScreenFlash.get_for(any).flash(color, duration)


## 2D confetti burst at a canvas point under `parent` (doubles, celebrations).
static func confetti(parent: Control, at: Vector2, count := 16) -> void:
	var cols := [Color("ffdc7a"), Color("ff7a7f"), Color("7ad0ff"), Color("9cf08a"), Color("d49aff"), Color("fff3d6")]
	for i in count:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.color = cols[i % cols.size()]
		var sz := randf_range(7.0, 13.0)
		r.size = Vector2(sz, sz * randf_range(0.45, 0.8))
		r.pivot_offset = r.size * 0.5
		r.position = at - r.size * 0.5
		r.rotation = randf() * TAU
		parent.add_child(r)
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		var v := randf_range(90.0, 210.0)
		var peak := at + Vector2(cos(a), sin(a)) * v
		var land := peak + Vector2(randf_range(-30.0, 30.0), randf_range(70.0, 140.0))
		var t := r.create_tween()
		t.tween_property(r, "position", peak - r.size * 0.5, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(r, "rotation", r.rotation + randf_range(-6.0, 6.0), 0.9)
		t.tween_property(r, "position", land - r.size * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(r, "modulate:a", 0.0, 0.6).set_delay(0.15)
		t.tween_callback(r.queue_free)


## 2D coins flying along an arc from `from` to `to` (canvas points) under `parent`.
static func fly_coins(parent: Control, from: Vector2, to: Vector2, count := 6, time := 0.55) -> void:
	for i in count:
		var c := UiIcons.rect("coin", 30)
		c.position = from - Vector2(15, 15) + Vector2(randf_range(-24.0, 24.0), randf_range(-10.0, 10.0))
		c.size = Vector2(30, 30)
		c.pivot_offset = Vector2(15, 15)
		parent.add_child(c)
		var start := c.position
		var end := to - Vector2(15, 15)
		var ctrl := (start + end) * 0.5 + Vector2(randf_range(-80.0, 80.0), -120.0)
		var t := c.create_tween()
		t.tween_interval(0.04 * i)
		t.tween_method(func(u: float) -> void:
			var a := start.lerp(ctrl, u)
			var b := ctrl.lerp(end, u)
			c.position = a.lerp(b, u)
			c.scale = Vector2.ONE * lerpf(1.1, 0.7, u), 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(c.queue_free)


## Brief global slow-down for impact (restores the previous time scale).

static func hit_stop(any: Node, duration := 0.07, scale := 0.05) -> void:
	var prev := Engine.time_scale
	if prev < 0.2:
		return
	Engine.time_scale = scale
	await any.get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = prev


static func _glow_light(parent: Node3D, pos: Vector3, color: Color, energy: float, time: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 3.5
	l.position = pos
	parent.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, time).set_trans(Tween.TRANS_SINE)
	t.tween_callback(l.queue_free)


static func _free_later(n: Node, time: float) -> void:
	var t := n.create_tween()
	t.tween_interval(time)
	t.tween_callback(n.queue_free)
