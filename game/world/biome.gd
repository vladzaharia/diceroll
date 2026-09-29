class_name Biome
extends RefCounted
## Builds everything around the board for an act: sky/fog/post, lights, the floating
## island, edge dressing, the centre set piece and ambient particles.
##
##   var world := Biome.build("frost", board.ring_extent())
##   add_child(world)
##
## Biomes are picked by id (BiomeDefs ids: crypt, hollow, throne, glade, frost, magma, mines,
## warcamp, ruins, moonlit). An int is still accepted and read as a legacy act number (1 crypt,
## 2 hollow, 3 throne). The BlockBits biomes (glade, frost, magma and the four 2026-09-29 biomes)
## are dressed in BiomeBlocks.
##
## Each biome keeps a fixed frame (floor / terrain, walls, sky); the rest is seeded dressing
## (game/world/dressing/: set piece, side / front kits, moat corners, palettes, MultiMesh
## scatter) picked from `variant_seed`, so the same biome looks different between runs.
##
## Layout contract (world units): the dressing is authored for a 7x7 ring whose outer tile
## edge is at |x|,|z| = BASE_EXTENT (7.35). build() scales the layout to the real ring
## extent: dressing positions spread out by s = extent / BASE_EXTENT (walls and fences are
## stretched along their length so rows stay closed), the island and floor grow, and the
## centre set piece scales up a little. The set piece stays within r ~2.4 * s, so the moat
## between it and the ring (combat staging) is free.

## Legacy act number -> biome id (old saves, act-only callers).
const NAMES := {1: "crypt", 2: "hollow", 3: "throne"}
const IDS := ["glade", "crypt", "hollow", "frost", "throne", "magma", "mines", "warcamp", "ruins", "moonlit"]
const ISLAND_HALF := 11.0
## Outer ring edge the dressing layout was authored for (7x7 ring, PITCH 2.1).
const BASE_EXTENT := 7.35

## Layout scale for the biome being built (see build()).
static var _s := 1.0
## build() options for the biome being built (see build()).
static var _opts := {}

## Per-biome look. Colours are sRGB.
const LOOKS := {
	"crypt": {
		"sky_top": Color(0.09, 0.1, 0.22), "sky_horizon": Color(0.42, 0.27, 0.3),
		"sky_bottom": Color(0.07, 0.05, 0.1), "sky_glow": Color(1.0, 0.62, 0.35),
		"glow_strength": 0.35, "stars": 0.35,
		"fog": Color(0.2, 0.14, 0.2), "fog_density": 0.004, "fog_height_density": 0.0,
		"ambient": Color(0.5, 0.48, 0.72), "ambient_energy": 0.6,
		"key": Color(1.0, 0.8, 0.58), "key_energy": 1.35, "key_rot": Vector3(-56.0, -38.0, 0.0),
		"fill": Color(0.5, 0.6, 1.0), "fill_energy": 0.35,
		"exposure": 1.05, "saturation": 1.2, "contrast": 1.08,
		"island_top": Color(0.42, 0.38, 0.36), "island_side": Color(0.36, 0.3, 0.3),
		"island_bottom": Color(0.12, 0.09, 0.13),
		"particles": "dust", "light": Color(1.0, 0.6, 0.28),
		"cloud_deep": Color(0.2, 0.13, 0.22), "cloud_light": Color(0.5, 0.34, 0.42), "cloud_rim": Color(1.0, 0.6, 0.4),
	},
	"hollow": {
		"sky_top": Color(0.2, 0.15, 0.36), "sky_horizon": Color(0.98, 0.5, 0.26),
		"sky_bottom": Color(0.16, 0.08, 0.12), "sky_glow": Color(1.0, 0.72, 0.36),
		"glow_strength": 0.9, "stars": 0.0,
		"fog": Color(0.5, 0.27, 0.24), "fog_density": 0.004, "fog_height_density": 0.0,
		"ambient": Color(0.7, 0.5, 0.55), "ambient_energy": 0.55,
		"key": Color(1.0, 0.7, 0.45), "key_energy": 1.5, "key_rot": Vector3(-42.0, -150.0, 0.0),
		"fill": Color(0.55, 0.45, 1.0), "fill_energy": 0.45,
		"exposure": 1.02, "saturation": 1.18, "contrast": 1.08,
		"island_top": Color(0.42, 0.32, 0.26), "island_side": Color(0.4, 0.28, 0.22),
		"island_bottom": Color(0.16, 0.08, 0.1),
		"particles": "fireflies", "light": Color(1.0, 0.55, 0.2),
		"cloud_deep": Color(0.26, 0.12, 0.24), "cloud_light": Color(0.82, 0.46, 0.44), "cloud_rim": Color(1.0, 0.8, 0.5),
	},
	"throne": {
		"sky_top": Color(0.04, 0.04, 0.12), "sky_horizon": Color(0.12, 0.3, 0.38),
		"sky_bottom": Color(0.03, 0.03, 0.07), "sky_glow": Color(0.55, 0.35, 1.0),
		"glow_strength": 0.5, "stars": 1.0,
		"fog": Color(0.1, 0.12, 0.22), "fog_density": 0.004, "fog_height_density": 0.0,
		"ambient": Color(0.45, 0.5, 0.8), "ambient_energy": 0.6,
		"key": Color(0.7, 0.82, 1.0), "key_energy": 1.1, "key_rot": Vector3(-58.0, 35.0, 0.0),
		"fill": Color(0.75, 0.4, 1.0), "fill_energy": 0.5,
		"exposure": 1.08, "saturation": 1.2, "contrast": 1.08,
		"island_top": Color(0.3, 0.29, 0.36), "island_side": Color(0.26, 0.24, 0.32),
		"island_bottom": Color(0.06, 0.06, 0.12),
		"particles": "wisps", "light": Color(0.7, 0.4, 1.0),
		"cloud_deep": Color(0.06, 0.08, 0.18), "cloud_light": Color(0.2, 0.33, 0.5), "cloud_rim": Color(0.5, 0.4, 1.0),
	},
}


## Biome id for an id or a legacy act number (unknown ids fall back to the crypt).
static func id_of(b: Variant) -> String:
	if b is int or b is float:
		return String(NAMES[clampi(int(b), 1, 3)])
	var s := String(b)
	return s if LOOKS.has(s) or BiomeBlocks.LOOKS.has(s) else "crypt"


static func look(b: Variant) -> Dictionary:
	var id := id_of(b)
	return LOOKS[id] if LOOKS.has(id) else BiomeBlocks.LOOKS[id]


## Stable per-biome number (mesh seeds).
static func seed_of(id: String) -> int:
	return IDS.find(id) + 1


## `variant_seed` picks the seeded dressing (set piece, kits, palettes, scatter; see
## Dressing): the same seed always builds the same board, the game passes one derived from
## the run seed so every run looks different.
## `opts`: {moon_phase} (Moonlit Woods: the phase the sky moon starts in).
static func build(b: Variant, extent := BASE_EXTENT, variant_seed := 0, opts := {}) -> Node3D:
	var id := id_of(b)
	_opts = opts
	_s = maxf(extent / BASE_EXTENT, 0.6)
	var root := Node3D.new()
	root.name = "Biome_" + id
	var lk := look(id)
	root.add_child(make_environment(id))
	_add_lights(root, lk)
	var island := MeshInstance3D.new()
	island.name = "Island"
	var sd := seed_of(id)
	island.mesh = island_mesh(ISLAND_HALF * _s, 13.0 * sqrt(_s), lk.island_top, lk.island_side, lk.island_bottom, sd * 17)
	root.add_child(island)
	_add_floating_rocks(root, lk, sd, 0 if id == "magma" else variant_seed)
	root.add_child(_lava_sea() if String(lk.get("sea", "clouds")) == "lava" else _cloud_sea(lk))
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	root.add_child(dressing)
	var centre := Node3D.new()
	centre.name = "SetPiece"
	root.add_child(centre)
	Dressing.begin(id, variant_seed, _s, extent, dressing)
	match id:
		"crypt":
			_crypt(dressing, centre)
		"hollow":
			_hollow(dressing, centre)
		"throne":
			_throne(dressing, centre)
		_:
			BiomeBlocks.dress(id, root, dressing, centre)
	_spread(dressing)
	centre.scale = Vector3.ONE * minf(1.0 + (_s - 1.0) * 1.4, 1.45)
	if _s > 1.05:
		_inner_corners(root, id, centre.scale.x)
	Dressing.finish()
	var amb := ambient_particles(String(lk.particles))
	amb.scale = Vector3(_s, 1.0, _s)
	root.add_child(amb)
	return root


## Current layout scale (dressing spreads by it; see build()).
static func layout_scale() -> float:
	return _s


## build() option of the biome being built (e.g. "moon_phase").
static func opt(key: String, default: Variant = null) -> Variant:
	return _opts.get(key, default)


## Spreads authored dressing out to the real ring size: positions scale by _s in x/z and
## wall-like pieces stretch along their own length so rows stay closed. The floor is built
## at full size already and is skipped.
static func _spread(d: Node3D) -> void:
	if absf(_s - 1.0) < 0.001:
		return
	for c in d.get_children():
		var n := c as Node3D
		if n == null or n.name == "Floor" or n.has_meta("prescaled"):
			continue
		n.position.x *= _s
		n.position.z *= _s
		var path := String(n.scene_file_path)
		if path.contains("wall") or path.contains("fence") or path.contains("barrier"):
			n.scale.x *= _s
		if n is OmniLight3D:
			(n as OmniLight3D).omni_range *= sqrt(_s)


# --- environment -------------------------------------------------------------------

static func make_environment(b: Variant) -> WorldEnvironment:
	var lk := look(b)
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://game/world/shaders/sky.gdshader")
	sky_mat.set_shader_parameter("top_color", lk.sky_top)
	sky_mat.set_shader_parameter("horizon_color", lk.sky_horizon)
	sky_mat.set_shader_parameter("bottom_color", lk.sky_bottom)
	sky_mat.set_shader_parameter("glow_color", lk.sky_glow)
	sky_mat.set_shader_parameter("glow_strength", lk.glow_strength)
	sky_mat.set_shader_parameter("stars", lk.stars)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = lk.ambient
	env.ambient_light_energy = lk.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = lk.exposure
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = float(lk.get("glow", 0.7))
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# SSAO is Forward+ only (the Mobile renderer on iOS warns and ignores it).
	env.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = lk.fog
	env.fog_light_energy = 1.0
	env.fog_density = lk.fog_density
	env.fog_sky_affect = 0.0
	env.fog_height = -4.0
	env.fog_height_density = lk.fog_height_density
	env.adjustment_enabled = true
	env.adjustment_saturation = lk.saturation
	env.adjustment_contrast = lk.contrast
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	return we


static func _add_lights(root: Node3D, lk: Dictionary) -> void:
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = lk.key
	key.light_energy = lk.key_energy
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.2
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = 48.0
	key.rotation_degrees = lk.key_rot
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = lk.fill
	fill.light_energy = lk.fill_energy
	fill.light_specular = 0.2
	fill.rotation_degrees = Vector3(-35.0, float(lk.key_rot.y) + 170.0, 0.0)
	root.add_child(fill)


# --- island ------------------------------------------------------------------------

## A low-poly floating island: squircle top (edge exponent 8) with a short vertical lip,
## then a jagged rock mass tapering to a point. Flat-shaded, vertex-coloured.
static func island_mesh(half: float, depth: float, top: Color, side: Color, bottom: Color,
		seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var seg := 40
	# [y, radius scale, jitter]
	var levels := [
		[0.0, 1.0, 0.0], [-0.9, 1.0, 0.0], [-1.1, 0.985, 0.01], [-3.0, 0.9, 0.05],
		[-5.6, 0.72, 0.08], [-8.4, 0.46, 0.1], [-11.0, 0.2, 0.12], [-depth, 0.0, 0.0],
	]
	var rings: Array = []
	for li in levels.size():
		var l: Array = levels[li]
		var ring: Array[Vector3] = []
		for i in seg:
			var a := TAU * float(i) / float(seg) + (0.0 if li < 2 else 0.035 * li)
			var c := cos(a)
			var s := sin(a)
			var r := half / pow(pow(absf(c), 8.0) + pow(absf(s), 8.0), 1.0 / 8.0)
			r *= float(l[1]) * (1.0 + rng.randf_range(-1.0, 1.0) * float(l[2]))
			var y := float(l[0]) + (rng.randf_range(-0.5, 0.5) * float(l[2]) * 6.0 if li > 1 else 0.0)
			ring.append(Vector3(c * r, y, s * r))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# top cap
	for i in seg:
		var a: Vector3 = rings[0][i]
		var b: Vector3 = rings[0][(i + 1) % seg]
		st.set_color(top)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(b)
		st.add_vertex(a)
	# sides
	for li in levels.size() - 1:
		var t0 := float(li) / float(levels.size() - 1)
		var t1 := float(li + 1) / float(levels.size() - 1)
		var c0 := side.lerp(bottom, pow(t0, 0.8)) if li > 0 else side.lightened(0.08)
		var c1 := side.lerp(bottom, pow(t1, 0.8))
		for i in seg:
			var a: Vector3 = rings[li][i]
			var b: Vector3 = rings[li][(i + 1) % seg]
			var c: Vector3 = rings[li + 1][i]
			var d: Vector3 = rings[li + 1][(i + 1) % seg]
			var shade := 1.0 + rng.randf_range(-0.06, 0.06)
			st.set_color(c0 * shade)
			st.add_vertex(a)
			st.add_vertex(b)
			st.set_color(c1 * shade)
			st.add_vertex(c)
			st.set_color(c0 * shade)
			st.add_vertex(b)
			st.set_color(c1 * shade)
			st.add_vertex(d)
			st.add_vertex(c)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	return mesh


static func _cloud_sea(lk: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "CloudSea"
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/world/shaders/clouds.gdshader")
	m.set_shader_parameter("deep_color", lk.cloud_deep)
	m.set_shader_parameter("light_color", lk.cloud_light)
	m.set_shader_parameter("rim_color", lk.cloud_rim)
	mi.material_override = m
	mi.position.y = -13.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The glowing lava ocean under the Magma island (replaces the cloud sea).
static func _lava_sea() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "LavaSea"
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/world/shaders/lava_sea.gdshader")
	# far below the island the sea is a calm backdrop: mostly crusted over, finer plates,
	# a few hot rivers (the channel around the ring carries the bright lava)
	m.set_shader_parameter("scale", 0.16)
	m.set_shader_parameter("speed", 0.025)
	m.set_shader_parameter("seam", 0.035)
	m.set_shader_parameter("energy", 1.0)
	m.set_shader_parameter("hot_share", 0.22)
	m.set_shader_parameter("crust_seam", 0.08)
	m.set_shader_parameter("plate_heat", 0.06)
	m.set_shader_parameter("crust_color", Color(0.05, 0.035, 0.045))
	m.set_shader_parameter("warm_crust", Color(0.09, 0.035, 0.035))
	m.set_shader_parameter("fade_near", 13.0)
	m.set_shader_parameter("fade_far", 30.0)
	m.set_shader_parameter("far_glow", 0.12)
	m.set_shader_parameter("haze_color", Color(0.06, 0.02, 0.045))
	m.set_shader_parameter("haze_near", 12.0)
	m.set_shader_parameter("haze_far", 40.0)
	m.set_shader_parameter("haze_max", 0.85)
	mi.material_override = m
	mi.position.y = -12.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.4, 0.12)
	l.light_energy = 1.0
	l.omni_range = 16.0
	l.omni_attenuation = 1.2
	l.position = Vector3(0, 2.5, 0)
	mi.add_child(l)
	return mi


## Floating rock islets around the island (background silhouettes). `variant_seed` shifts,
## resizes and sometimes adds or drops them so the skyline differs between boards (0 = the
## authored layout).
static func _add_floating_rocks(root: Node3D, lk: Dictionary, sd: int, variant_seed := 0) -> void:
	var spots := [Vector3(-15.5, -3.5, -9.0), Vector3(15.0, -5.0, -12.0), Vector3(-13.0, -7.0, 9.0),
		Vector3(16.5, -2.0, 4.0), Vector3(-6.0, -4.0, -17.0), Vector3(8.0, -6.5, -18.0)]
	var sizes := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	if variant_seed != 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sd, variant_seed, "rocks"])
		if rng.randf() < 0.5:
			spots.append(Vector3(rng.randf_range(-4.0, 4.0), -3.0, -19.0))
			sizes.append(0.0)
		if rng.randf() < 0.3:
			spots.remove_at(rng.randi() % 4)
			sizes.remove_at(0)
		for i in spots.size():
			var a := atan2(spots[i].z, spots[i].x) + rng.randf_range(-0.28, 0.28)
			var r := Vector2(spots[i].x, spots[i].z).length() * rng.randf_range(0.92, 1.1)
			spots[i] = Vector3(cos(a) * r, spots[i].y + rng.randf_range(-1.5, 1.5), sin(a) * r)
			sizes[i] = rng.randf_range(-0.25, 0.45)
	for i in spots.size():
		spots[i] = Vector3(spots[i].x * _s, spots[i].y, spots[i].z * _s)
		var mi := MeshInstance3D.new()
		var h := 0.9 + 0.35 * float(i % 3) + float(sizes[i])
		mi.mesh = island_mesh(h, h * 2.2, lk.island_top, lk.island_side, lk.island_bottom, sd * 31 + i)
		mi.position = spots[i]
		mi.rotation.y = float(i) * 1.3
		mi.set_meta("bob", i)
		root.add_child(mi)
		var bob := mi.create_tween().set_loops()
		bob.tween_property(mi, "position:y", spots[i].y + 0.35, 2.4 + 0.3 * i).set_trans(Tween.TRANS_SINE)
		bob.tween_property(mi, "position:y", spots[i].y - 0.35, 2.4 + 0.3 * i).set_trans(Tween.TRANS_SINE)


static func _floor(p_parent: Node3D, paths: Array, y: float, half := 10.0, step := 4.0,
		seed := 3, tint := Color(0, 0, 0, 0)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var parent := Node3D.new()
	parent.name = "Floor"
	p_parent.add_child(parent)
	half *= _s
	var n := int(ceil(half * 2.0 / step - 0.2))
	half = n * step * 0.5
	for ix in n:
		for iz in n:
			var p := Vector3(-half + step * (ix + 0.5), y, -half + step * (iz + 0.5))
			var path: String = paths[rng.randi() % paths.size()]
			var f := Props.put(parent, path, p, 90.0 * (rng.randi() % 4))
			Props.set_shadows(f, false)
			if tint.a > 0.0:
				Props.tint(f, tint, tint.a)


## A warm point light that flickers gently (torches, lanterns, candles).
static func flicker_light(parent: Node3D, pos: Vector3, color: Color, energy := 1.6, range := 5.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range
	l.omni_attenuation = 1.4
	l.position = pos
	l.shadow_enabled = false
	parent.add_child(l)
	var t := l.create_tween().set_loops()
	var p := randf_range(0.12, 0.2)
	t.tween_property(l, "light_energy", energy * 1.18, p).set_trans(Tween.TRANS_SINE)
	t.tween_property(l, "light_energy", energy * 0.85, p * 1.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(l, "light_energy", energy, p).set_trans(Tween.TRANS_SINE)
	return l


## Small flame particles (torches, candles, campfire).
static func flame(parent: Node3D, pos: Vector3, color := Color(1.0, 0.55, 0.2), size := 0.35,
		amount := 10) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.7
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	curve.curve = c
	pm.scale_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	grad.set_color(1, Color(color.r, color.g * 0.5, color.b * 0.3, 0.0))
	grad.add_point(0.35, Color(color.r, color.g, color.b, 0.9))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = Props.particle_material("flame")
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


static func ambient_particles(kind: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Ambient_" + kind
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(12.0, 2.5, 12.0)
	pm.gravity = Vector3.ZERO
	pm.direction = Vector3.UP
	pm.spread = 180.0
	p.position = Vector3(0, 2.5, 0)
	var size := 0.12
	var col := Color(1.0, 0.8, 0.55)
	var tex := "dot"
	match kind:
		"dust":
			p.amount = 90
			p.lifetime = 9.0
			pm.initial_velocity_min = 0.05
			pm.initial_velocity_max = 0.2
			pm.gravity = Vector3(0.02, 0.04, 0.0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.4
			pm.turbulence_noise_scale = 3.0
			col = Color(1.0, 0.78, 0.5, 0.55)
			size = 0.09
		"fireflies":
			p.amount = 60
			p.lifetime = 7.0
			pm.initial_velocity_min = 0.1
			pm.initial_velocity_max = 0.35
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 1.4
			pm.turbulence_noise_scale = 2.0
			pm.emission_box_extents = Vector3(11.0, 1.6, 11.0)
			p.position = Vector3(0, 1.8, 0)
			col = Color(1.0, 0.8, 0.3, 1.0)
			size = 0.13
			tex = "hard"
		"pollen":
			p.amount = 70
			p.lifetime = 9.0
			pm.initial_velocity_min = 0.05
			pm.initial_velocity_max = 0.2
			pm.gravity = Vector3(0.04, 0.02, 0.0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.7
			pm.turbulence_noise_scale = 2.5
			col = Color(1.0, 0.95, 0.65, 0.8)
			size = 0.08
		"snow":
			p.amount = 260
			p.lifetime = 9.0
			p.position = Vector3(0, 7.0, 0)
			pm.emission_box_extents = Vector3(13.0, 1.0, 13.0)
			pm.direction = Vector3.DOWN
			pm.spread = 20.0
			pm.initial_velocity_min = 0.6
			pm.initial_velocity_max = 1.0
			pm.gravity = Vector3(0.12, -0.25, 0.05)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.35
			pm.turbulence_noise_scale = 3.0
			col = Color(1.0, 1.0, 1.0, 0.95)
			size = 0.11
			tex = "hard"
		"embers":
			p.amount = 110
			p.lifetime = 6.0
			p.position = Vector3(0, 0.5, 0)
			pm.direction = Vector3.UP
			pm.spread = 25.0
			pm.initial_velocity_min = 0.4
			pm.initial_velocity_max = 1.1
			pm.gravity = Vector3(0.05, 0.25, 0.0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.9
			pm.turbulence_noise_scale = 2.2
			col = Color(1.0, 0.55, 0.15, 1.0)
			size = 0.1
			tex = "hard"
		"ash":
			# Orc Warcamp: grey ash and a few sparks drifting up from the fires
			p.amount = 80
			p.lifetime = 8.0
			p.position = Vector3(0, 0.8, 0)
			pm.direction = Vector3.UP
			pm.spread = 35.0
			pm.initial_velocity_min = 0.15
			pm.initial_velocity_max = 0.45
			pm.gravity = Vector3(0.12, 0.08, 0.04)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.7
			pm.turbulence_noise_scale = 2.6
			col = Color(0.72, 0.66, 0.62, 0.7)
			size = 0.08
		"sand":
			# Sunscorched Ruins: sand streaming low across the island on the wind
			p.amount = 140
			p.lifetime = 5.0
			p.position = Vector3(0, 0.6, 0)
			pm.emission_box_extents = Vector3(13.0, 0.6, 12.0)
			pm.direction = Vector3(1.0, 0.05, 0.25)
			pm.spread = 10.0
			pm.initial_velocity_min = 1.4
			pm.initial_velocity_max = 2.6
			pm.gravity = Vector3(0.2, -0.05, 0.0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.35
			pm.turbulence_noise_scale = 3.5
			col = Color(1.0, 0.88, 0.62, 0.55)
			size = 0.07
		"wisps":
			p.amount = 70
			p.lifetime = 8.0
			pm.initial_velocity_min = 0.1
			pm.initial_velocity_max = 0.3
			pm.gravity = Vector3(0, 0.12, 0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.8
			pm.turbulence_noise_scale = 2.5
			col = Color(0.5, 0.95, 0.9, 0.9)
			size = 0.12
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	grad.colors = PackedColorArray([Color(col, 0.0), col, col, Color(col, 0.0)])
	if kind == "embers":
		grad.colors = PackedColorArray([Color(1.0, 0.9, 0.5, 0.0), Color(1.0, 0.75, 0.3, 1.0),
			Color(1.0, 0.35, 0.08, 0.9), Color(0.6, 0.1, 0.05, 0.0)])
	if kind == "ash":
		grad.colors = PackedColorArray([Color(0.7, 0.66, 0.62, 0.0), Color(0.72, 0.66, 0.62, 0.7),
			Color(0.95, 0.55, 0.3, 0.5), Color(0.4, 0.36, 0.34, 0.0)])
	if kind == "wisps":
		grad.colors = PackedColorArray([Color(0.6, 0.4, 1.0, 0.0), Color(0.6, 0.45, 1.0, 0.9),
			Color(0.4, 1.0, 0.9, 0.8), Color(0.4, 1.0, 0.9, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	p.process_material = pm
	p.preprocess = 8.0
	p.visibility_aabb = AABB(Vector3(-14, -9, -14), Vector3(28, 18, 28))
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = Props.particle_material(tex)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# --- act 1: the crypt ----------------------------------------------------------------

static func _crypt(d: Node3D, c: Node3D) -> void:
	var D := Props.DUN
	_floor(d, [D + "floor_tile_large.gltf"], 0.0, 10.0, 4.0, 3, Color(0.6, 0.53, 0.52, 0.55))
	# back wall with arches, windows, torches and banners
	var walls := [D + "wall_arched.gltf", D + "wall.gltf", D + "wall_archedwindow_open.gltf", D + "wall.gltf",
		D + "wall_arched.gltf"]
	for i in walls.size():
		Props.put(d, walls[i], Vector3(-8.0 + 4.0 * i, 0.0, -9.9))
	for x in [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]:
		Props.put(d, D + "pillar.gltf", Vector3(x, 0.0, -9.7))
	for x in [-4.0, 4.0]:
		Props.put(d, D + "torch_mounted.gltf", Vector3(x, 2.2, -9.35))
		flame(d, Vector3(x, 3.05, -9.05))
		flicker_light(d, Vector3(x, 3.0, -8.6), Color(1.0, 0.6, 0.28), 2.2, 7.0)
	# the run's banner colour and patterns (see DressCrypt)
	var ban := DressCrypt.banners()
	Props.put(d, DressCrypt.banner_path(ban[0], ban[2]), Vector3(-8.0, 0.2, -9.75))
	Props.put(d, DressCrypt.banner_path(ban[0], ban[2]), Vector3(8.0, 0.2, -9.75))
	Props.put(d, DressCrypt.banner_path(ban[1], ban[2]), Vector3(0.0, 0.2, -9.75))
	# side walls, stepping down toward the camera
	for side in [-1.0, 1.0]:
		Props.put(d, D + "wall.gltf", Vector3(side * 9.9, 0.0, -6.0), 90.0)
		Props.put(d, D + "wall_half.gltf", Vector3(side * 9.9, 0.0, -2.0), 90.0)
		Props.put(d, D + "wall_broken.gltf", Vector3(side * 9.9, 0.0, 2.0), 90.0)
		Props.put(d, D + "pillar.gltf", Vector3(side * 9.7, 0.0, -8.0), 90.0)
		Props.put(d, D + "column.gltf", Vector3(side * 9.0, 0.0, 8.6))
		Props.put(d, D + "candle_triple.gltf", Vector3(side * 9.0, 1.4, 8.6))
		flame(d, Vector3(side * 9.0, 2.3, 8.6), Color(1.0, 0.6, 0.25), 0.22, 6)
		flicker_light(d, Vector3(side * 9.0, 2.5, 8.6), Color(1.0, 0.6, 0.3), 1.4, 5.0)
		Props.put(d, D + "torch_lit.gltf", Vector3(side * 8.4, 0.4, -6.0))
		flame(d, Vector3(side * 8.4, 1.1, -6.0))
		flicker_light(d, Vector3(side * 8.2, 1.6, -6.0), Color(1.0, 0.6, 0.28), 1.8, 6.0)
		Dressing.occupy(side * 8.4 * _s, -6.0 * _s, 0.5)
		Dressing.occupy(side * 9.0 * _s, 8.6 * _s, 0.6)
		Dressing.occupy(side * 9.7 * _s, -8.0 * _s, 0.9)
	for x in [-6.0, -2.0, 2.0, 6.0]:
		Props.put(d, D + "barrier.gltf", Vector3(x, 0.0, 10.2), 180.0)
	# storeroom / library / armoury along the side walls (seeded kits)
	DressCrypt.sides(d, ban[2])
	for i in 17:
		Dressing.occupy((-8.0 + i) * _s, 10.2 * _s, 0.45)
	DressCrypt.front()
	match Dressing.kit(0):
		1:
			DressCrypt.shrine(c, ban[2])
			return
		2:
			DressCrypt.hoard(c)
			return
	# set piece: a stone dais with a giant floating die
	var dais := Props.put(c, D + "floor_foundation_allsides.gltf", Vector3(0, -1.55, 0), 0.0, 1.0)
	dais.scale = Vector3(1.7, 1.0, 1.7)
	for p in [Vector3(-1.5, 0.45, -1.5), Vector3(1.5, 0.45, -1.5), Vector3(-1.5, 0.45, 1.5), Vector3(1.5, 0.45, 1.5)]:
		Props.put(c, D + "candle_triple.gltf", p, Dressing.rng.randf() * 360.0, 0.9)
		flame(c, p + Vector3(0, 0.85, 0), Color(1.0, 0.6, 0.25), 0.2, 5)
	var die := Props.put(c, Props.BGB + "D20_red.gltf", Vector3(0, 2.4, 0), 0.0, 2.1)
	_spin_bob(die, 2.4)
	flicker_light(c, Vector3(0, 2.6, 1.6), Color(1.0, 0.45, 0.35), 2.5, 6.0)
	var halo := _rune_circle(Color(1.0, 0.55, 0.3), 2.2)
	halo.position = Vector3(0, 0.46, 0)
	c.add_child(halo)


# --- act 2: the hollow ---------------------------------------------------------------

static func _hollow(d: Node3D, c: Node3D) -> void:
	var H := Props.HAL
	_floor(d, [H + "floor_dirt.gltf"], 0.0, 10.0, 4.0, 3, Color(0.62, 0.46, 0.36, 0.45))
	for x in [-5.0, 0.5, 5.5]:
		Props.put(d, H + "fence_seperate_broken.gltf", Vector3(x, 0, 10.1), 180.0 + Dressing.rng.randf_range(-6.0, 6.0), 0.9)
	for p in [Vector3(-3.0, 0, 9.0), Vector3(2.8, 0, 9.3), Vector3(7.6, 0, 9.0)]:
		Props.put(d, H + "pumpkin_orange_small.gltf", p, Dressing.rng.randf() * 360.0, 0.9)
	# the tree line (autumn pines / broadleaves / bare snags; see DressHollow)
	DressHollow.trees(d)
	for x in [-6.0, -2.0, 2.0]:
		Props.put(d, H + "fence.gltf", Vector3(x, 0, -8.1))
	Props.put(d, H + "fence_broken.gltf", Vector3(6.0, 0, -8.1))
	for side in [-1.0, 1.0]:
		Props.put(d, H + "fence_seperate.gltf", Vector3(side * 8.2, 0, -5.8), 90.0)
		Props.put(d, H + "post_lantern.gltf", Vector3(side * 8.3, 0, -1.4), 90.0 if side < 0 else -90.0)
		flicker_light(d, Vector3(side * 7.8, 2.6, -1.4), Color(1.0, 0.6, 0.25), 2.0, 6.5)
		Props.put(d, H + "pumpkin_orange_jackolantern.gltf", Vector3(side * 8.4, 0, 8.4), side * -30.0, 0.8)
		flicker_light(d, Vector3(side * 8.4, 0.9, 8.9), Color(1.0, 0.5, 0.15), 1.4, 4.0)
		Props.put(d, H + "pumpkin_yellow_small.gltf", Vector3(side * 7.8, 0, 9.3), 40.0, 0.9)
		Props.put(d, H + "lantern_standing.gltf", Vector3(side * 8.3, 0, 6.2), 0.0, 0.9)
		flicker_light(d, Vector3(side * 8.3, 0.7, 6.2), Color(1.0, 0.65, 0.3), 1.0, 3.0)
	Props.put(d, H + "arch_gate.gltf", Vector3(0.0, 0, -8.3), 0.0, 0.9)
	for side in [-1.0, 1.0]:
		for at in [Vector3(8.2, 0, -5.8), Vector3(8.3, 0, -1.4), Vector3(8.4, 0, 8.4), Vector3(8.3, 0, 6.2)]:
			Dressing.occupy(side * at.x * _s, at.z * _s, 0.7)
	for x in [-5.0, 0.5, 5.5]:
		for i in 4:
			Dressing.occupy((x - 1.5 + i) * _s, 10.1 * _s, 0.45)
	for p in [Vector3(-3.0, 0, 9.0), Vector3(2.8, 0, 9.3), Vector3(7.6, 0, 9.0)]:
		Dressing.occupy(p.x * _s, p.z * _s, 0.5)
	DressHollow.sides(d)
	DressHollow.front()
	match Dressing.kit(0):
		1:
			DressHollow.bonfire(c)
			return
		2:
			DressHollow.giant(c)
			return
	# set piece: a haunted dead tree over a ring of graves and glowing pumpkins
	Props.put(c, H + "tree_dead_large_decorated.gltf", Vector3(0.2, 0, -0.6), 20.0, 1.3)
	Props.put(c, H + "floor_dirt_grave.gltf", Vector3(0.0, -0.49, 0.2), 0.0, 0.55)
	for p in [Vector3(-2.3, 0, -2.2), Vector3(2.3, 0, -2.2), Vector3(-2.3, 0, 2.2), Vector3(2.3, 0, 2.2)]:
		Props.put(c, H + "fence_pillar.gltf", p, 0.0, 0.8)
	Props.put(c, H + "gravemarker_B.gltf", Vector3(1.9, 0, -0.4), -30.0, 0.9)
	Props.put(c, H + "candle_melted.gltf", Vector3(-1.9, 0, 1.4), 0.0, 1.2)
	Props.put(c, H + "gravestone.gltf", Vector3(-1.6, 0, 0.3), 25.0, 0.8)
	Props.put(c, H + "grave_B.gltf", Vector3(1.5, 0, 0.5), -20.0, 0.8)
	Props.put(c, H + "gravemarker_A.gltf", Vector3(-0.9, 0, -1.9), 10.0, 0.9)
	Props.put(c, H + "pumpkin_orange_jackolantern.gltf", Vector3(0.9, 0, 1.6), -15.0, 0.7)
	Props.put(c, H + "pumpkin_yellow_jackolantern.gltf", Vector3(-0.7, 0, 1.7), 20.0, 0.55)
	Props.put(c, H + "candle_triple.gltf", Vector3(1.8, 0, -1.2), 0.0, 1.0)
	flicker_light(c, Vector3(0.1, 1.0, 2.3), Color(1.0, 0.5, 0.15), 2.2, 5.0)
	Props.put(c, H + "lantern_hanging.gltf", Vector3(-1.2, 2.4, -0.3), 0.0, 0.8)
	flicker_light(c, Vector3(-1.2, 2.0, -0.2), Color(1.0, 0.65, 0.3), 1.2, 4.0)


# --- act 3: the bone throne ------------------------------------------------------------

static func _throne(d: Node3D, c: Node3D) -> void:
	var D := Props.DUN
	var H := Props.HAL
	_floor(d, [D + "floor_tile_large.gltf"], 0.0, 10.0, 4.0, 5,
		Color(0.52, 0.5, 0.66, 0.7))
	for i in 5:
		var x := -8.0 + 4.0 * i
		Props.put(d, H + "fence.gltf" if i != 2 else H + "arch.gltf", Vector3(x, 0, -9.6), 0.0,
			1.0 if i != 2 else 0.95)
	for x in [-10.0, 10.0]:
		Props.put(d, D + "pillar_decorated.gltf", Vector3(x, 0, -9.4))
	for side in [-1.0, 1.0]:
		Props.put(d, H + "skull_candle.gltf", Vector3(side * 8.6, 0, 7.8), side * 20.0, 0.9)
		flame(d, Vector3(side * 8.6, 1.2, 7.8), Color(0.6, 0.4, 1.0), 0.22, 6)
		flicker_light(d, Vector3(side * 8.6, 1.5, 7.8), Color(0.7, 0.45, 1.0), 1.6, 4.5)
		Props.put(d, H + "bone_A.gltf", Vector3(side * 8.0, 0, 5.8), 60.0, 0.9)
		Props.put(d, H + "ribcage.gltf", Vector3(side * 9.2, 0, -8.4), 30.0, 0.9)
		flicker_light(d, Vector3(side * 8.4, 1.6, -7.6), Color(1.0, 0.6, 0.3), 1.2, 4.0)
		for at in [Vector3(8.6, 0, 7.8), Vector3(8.0, 0, 5.8), Vector3(9.2, 0, -8.4), Vector3(10.0, 0, -9.4)]:
			Dressing.occupy(side * at.x * _s, at.z * _s, 0.6)
	# coffins / war trophies / royal hall along the sides (seeded kits, see DressThrone)
	DressThrone.sides(d)
	for p in [Vector3(-4.5, 0, 9.4), Vector3(0.5, 0, 9.8), Vector3(5.0, 0, 9.3), Vector3(-7.0, 0, 9.6), Vector3(7.0, 0, 9.6)]:
		Dressing.occupy(p.x * _s, p.z * _s, 0.7)
	DressThrone.front()
	for p in [Vector3(-4.5, 0, 9.4), Vector3(0.5, 0, 9.8), Vector3(5.0, 0, 9.3)]:
		Props.put(d, [H + "bone_B.gltf", H + "bone_C.gltf", H + "skull.gltf"][int(absf(p.x)) % 3], p, Dressing.rng.randf() * 360.0, 0.8)
	for x in [-7.0, 7.0]:
		Props.put(d, H + "gravestone.gltf", Vector3(x, 0, 9.6), 180.0 + x * 2.0, 0.8)
	match Dressing.kit(0):
		1:
			DressThrone.bone_throne(c)
			return
		2:
			DressThrone.kings_tomb(c)
			return
	# set piece: the crypt with a purple rune circle and candles
	Props.put(c, H + "crypt.gltf", Vector3(0, 0, 0.1), 0.0, 0.46)
	for p in [Vector3(-2.2, 0, 1.7), Vector3(2.2, 0, 1.7), Vector3(-2.2, 0, -2.0), Vector3(2.2, 0, -2.0)]:
		Props.put(c, H + "candle_triple.gltf", p, Dressing.rng.randf() * 360.0, 1.0)
		flame(c, p + Vector3(0, 0.9, 0), Color(0.65, 0.4, 1.0), 0.2, 5)
	var ring := _rune_circle(Color(0.6, 0.35, 1.0), 2.8)
	ring.position = Vector3(0, 0.08, 0.2)
	c.add_child(ring)
	flicker_light(c, Vector3(0, 1.5, 2.6), Color(0.65, 0.4, 1.0), 3.0, 6.0)


## Larger rings leave a wider moat: low, lit props on its four inner corners keep it
## dressed (they sit off the combat lanes and are sunk by the occluder pass if needed).
## The vignette comes from the board's corner kit (Dressing.kit(2); see game/world/dressing).
static func _inner_corners(root: Node3D, id: String, k: float) -> void:
	var holder := Node3D.new()
	holder.name = "InnerCorners"
	root.add_child(holder)
	var r := 3.55 * k
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * r, 0.0, sz * r)
			var yaw := rad_to_deg(atan2(-sx, -sz))
			match id:
				"crypt":
					DressCrypt.corner(holder, p, yaw, sx, sz)
				"hollow":
					DressHollow.corner(holder, p, yaw, sx, sz)
				"throne":
					DressThrone.corner(holder, p, yaw, sx, sz)
				_:
					BiomeBlocks.inner_corner(id, holder, p, yaw, sx, sz)


static func _spin_bob(n: Node3D, y: float) -> void:

	var spin := n.create_tween().set_loops()
	spin.tween_property(n, "rotation:y", TAU, 12.0).from(0.0)
	var tilt := n.create_tween().set_loops()
	tilt.tween_property(n, "position:y", y + 0.25, 2.0).set_trans(Tween.TRANS_SINE)
	tilt.tween_property(n, "position:y", y - 0.1, 2.0).set_trans(Tween.TRANS_SINE)
	n.rotation.x = 0.35
	n.rotation.z = 0.2


## A glowing, slowly turning magic circle on the ground.
static func _rune_circle(color: Color, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/world/shaders/rune_circle.gdshader")
	m.set_shader_parameter("color", color)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
