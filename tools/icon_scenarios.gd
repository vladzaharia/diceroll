extends RefCounted
## App-icon scenario for the screenshot harness (tools/shot.gd).
##  app_icon  a red Blade die and a gilded die tumbling over a warm radial gradient.
##            Render square:  tools/shoot.sh app_icon /abs/icon.png 1024x1024 --wait=1.5
##            (tools/export.sh icon does this and writes assets/icon/icon.png).


static func names() -> PackedStringArray:
	return PackedStringArray(["app_icon"])


static func build(name: String) -> Node:
	if name != "app_icon":
		return null
	return _Icon.new()


class _Icon:
	extends Control

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var bg := TextureRect.new()
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.72, 0.36), Color(0.78, 0.3, 0.12), Color(0.3, 0.07, 0.08)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 512
		gt.height = 512
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.42)
		gt.fill_to = Vector2(1.15, 1.1)
		bg.texture = gt
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(svc)
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.own_world_3d = true
		svc.add_child(vp)
		_build_world(vp)

	func _build_world(vp: SubViewport) -> void:
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color(0.5, 0.42, 0.36)
		sm.sky_horizon_color = Color(0.85, 0.55, 0.3)
		sm.ground_bottom_color = Color(0.2, 0.08, 0.05)
		sm.ground_horizon_color = Color(0.5, 0.25, 0.12)
		sky.sky_material = sm
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.8
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_intensity = 0.5
		env.glow_hdr_threshold = 1.3
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)

		var key := DirectionalLight3D.new()
		key.light_color = Color(1.0, 0.93, 0.82)
		key.light_energy = 1.5
		key.shadow_enabled = true
		vp.add_child(key)
		key.transform = Transform3D(Basis.looking_at(Vector3(0.45, -1.0, -0.55).normalized(), Vector3.UP), Vector3.ZERO)
		var rim := DirectionalLight3D.new()
		rim.light_color = Color(1.0, 0.7, 0.45)
		rim.light_energy = 0.9
		vp.add_child(rim)
		rim.transform = Transform3D(Basis.looking_at(Vector3(-0.4, -0.3, 1.0).normalized(), Vector3.UP), Vector3.ZERO)

		var cam := Camera3D.new()
		cam.fov = 30.0
		vp.add_child(cam)
		cam.look_at_from_position(Vector3(0.0, 4.4, 6.6), Vector3(0.12, 0.62, 0.0))

		# Gold die behind (top right), red Blade die in front (bottom left): the hero.
		_die(vp, "gilded", 3, Vector3(0.8, 0.95, -0.7), Vector3(0.35, 0.9, 0.2), 0.95)
		_die(vp, "blade", 0, Vector3(-0.38, 0.1, 0.45), Vector3(-0.3, 0.6, -0.45), 1.35)

	## Adds a die showing face `slot` up, tumbled by `tilt` (euler, radians), scaled by `s`.
	func _die(vp: SubViewport, rune: String, slot: int, pos: Vector3, tilt: Vector3, s: float) -> void:
		var d := DieVisual.new()
		vp.add_child(d)
		d.set_data({"faces": [6, 5, 4, 3, 2, 1] if rune == "blade" else [1, 2, 3, 4, 5, 6], "rune": rune})
		d.ring.visible = false
		d.position = pos
		d.scale = Vector3.ONE * s
		d.body.basis = Basis.from_euler(tilt) * DieMesh.up_basis(slot)
		d.set_process(false)
