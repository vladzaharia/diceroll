class_name Props
extends RefCounted
## Tiny helpers for instancing KayKit props and building simple procedural meshes.

const K := "res://assets/kaykit/"
const DUN := K + "dungeon/"
const HAL := K + "halloween/"
const BGB := K + "boardgame/"
const TOOLS := K + "tools/"
const WPN := K + "weapons/"
const PLAT := K + "platformer/"
const FONT_TITLE := "res://assets/fonts/LilitaOne-Regular.ttf"
const FONT_BODY := "res://assets/fonts/Fredoka-Variable.ttf"

static var _scenes: Dictionary = {}


## Instances a glTF/GLB (cached PackedScene). `path` may be absolute (res://) or relative to K.
static func inst(path: String, scale := 1.0, shadows := true) -> Node3D:
	var full := path if path.begins_with("res://") else K + path
	if not _scenes.has(full):
		_scenes[full] = load(full)
	var n: Node3D = (_scenes[full] as PackedScene).instantiate()
	if scale != 1.0:
		n.scale = Vector3.ONE * scale
	if not shadows:
		set_shadows(n, false)
	return n


## Instances and places a prop under `parent`.
static func put(parent: Node3D, path: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0,
		shadows := true) -> Node3D:
	var n := inst(path, scale, shadows)
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(n)
	return n


static func set_shadows(n: Node, on: bool) -> void:
	for m in n.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Applies `mat` as override on every surface of every mesh below `n`.
static func override_material(n: Node, mat: Material) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, mat)


## Re-colours every surface below `n` with the atlas-preserving tint shader.
static func tint(n: Node, color: Color, strength := 1.0, emission := Color.BLACK) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var base := mi.get_active_material(s) as BaseMaterial3D
			var sm := ShaderMaterial.new()
			sm.shader = preload("res://game/world/shaders/atlas_tint.gdshader")
			if base:
				sm.set_shader_parameter("albedo_tex", base.albedo_texture)
			sm.set_shader_parameter("tint", color)
			sm.set_shader_parameter("strength", strength)
			sm.set_shader_parameter("emission", emission)
			mi.set_surface_override_material(s, sm)


static func font(title := true) -> Font:
	return load(FONT_TITLE if title else FONT_BODY)


## Unshaded (optionally additive) material for glows.
static func glow_material(color: Color, additive := true, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


static func flat_material(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


## Soft radial dot / sparkle / ring textures for particles (generated once).
static var _tex: Dictionary = {}


static func particle_texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5) - c) / c
			var r := p.length()
			var a := 0.0
			match kind:
				"dot":
					a = pow(clampf(1.0 - r, 0.0, 1.0), 1.6)
				"hard":
					a = clampf((1.0 - r) * 4.0, 0.0, 1.0)
				"spark":
					var ax := absf(p.x)
					var ay := absf(p.y)
					var star := maxf(clampf(1.0 - (ax * 7.0 + ay * 1.1), 0.0, 1.0),
							clampf(1.0 - (ay * 7.0 + ax * 1.1), 0.0, 1.0))
					a = clampf(star + pow(clampf(1.0 - r * 2.2, 0.0, 1.0), 2.0), 0.0, 1.0)
				"ring":
					a = clampf(1.0 - absf(r - 0.8) * 9.0, 0.0, 1.0)
				"rounded":
					var q := Vector2(absf(p.x), absf(p.y)) - Vector2(0.62, 0.62)
					var dd := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 0.3
					a = clampf(-dd * 30.0, 0.0, 1.0)
				"flame":
					var q := Vector2(p.x * (1.2 + p.y * 0.6), p.y)
					a = pow(clampf(1.0 - q.length(), 0.0, 1.0), 1.2)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


## Additive billboard particle material using a generated texture and vertex colour.
static func particle_material(kind := "dot", additive := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = particle_texture(kind)
	m.disable_receive_shadows = true
	return m


static func quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return q


## World-space AABB of every visual instance below `n` (empty AABB if none).
static func world_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var list: Array = n.find_children("*", "VisualInstance3D", true, false)
	if n is VisualInstance3D:
		list.append(n)
	for v in list:
		if v is GPUParticles3D or v is Light3D or v is Label3D:
			continue
		var vi := v as VisualInstance3D
		var a := vi.global_transform * vi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out
