class_name CampScene
extends Node3D
## The Camp (spec §16): a cozy camp on a floating island at dusk. A campfire in the middle
## (flickering light, embers, smoke), the chosen hero sitting by the fire with the equipped
## pet beside them, and four building stations made from KayKit props:
##   Armory (anvil, weapon rack) · Dice Workshop (workbench, tools, big dice) ·
##   Pet Den (a cosy nook with pumpkins and lanterns) · Arcade (a claw-machine booth).
## Stations are tappable (pick_station) and labelled by the UI (station_anchor). Locked
## stations are dimmed. Decorations grow with milestones: boss trophies, class banners, a
## golden chest after the first win.
##
##   var camp := CampScene.new(); add_child(camp)
##   camp.apply_profile(profile)          # hero, pet, locks, trophies
##   camp.set_pet("pumpkin_sprite")       # hook for the pet familiar (placeholder model)
##   var id := camp.pick_station(tap_pos)

signal layout_changed

const HERO_SCALE := 0.85
const FOREST := "res://assets/kaykit/forest/color%d/%s_Color%d.gltf"
const RES := "res://assets/kaykit/resources/"
## Optional factory for real pet models (WP-E3): func(id: String) -> Node3D. When unset (or it
## returns null) a KayKit-prop placeholder stands in.
static var pet_factory: Callable

const LOOK := {
	"sky_top": Color(0.04, 0.05, 0.15), "sky_horizon": Color(0.36, 0.2, 0.36), "sky_bottom": Color(0.04, 0.03, 0.08),
	"sky_glow": Color(1.0, 0.5, 0.32), "glow_strength": 0.55, "stars": 1.0,
	"ambient": Color(0.38, 0.4, 0.72), "ambient_energy": 0.42,
	"moon": Color(0.6, 0.68, 1.0), "moon_energy": 0.55,
	"cloud_deep": Color(0.07, 0.06, 0.16), "cloud_light": Color(0.22, 0.18, 0.36), "cloud_rim": Color(0.8, 0.45, 0.4),
	"island_top": Color(0.2, 0.3, 0.2), "island_side": Color(0.28, 0.2, 0.18), "island_bottom": Color(0.08, 0.06, 0.1),
}
const ISLAND_HALF := 16.0

## Station positions per orientation (x, z) and the fire / hero spots.
const LAYOUT := {
	"landscape": {
		"armory": Vector3(-8.4, 0, -0.4), "workshop": Vector3(-3.7, 0, -5.4),
		"pet_den": Vector3(3.7, 0, -5.4), "arcade": Vector3(8.4, 0, -0.4),
	},
	"portrait": {
		"armory": Vector3(-4.5, 0, -1.3), "workshop": Vector3(-3.2, 0, -7.6),
		"pet_den": Vector3(3.2, 0, -7.6), "arcade": Vector3(4.5, 0, -1.3),
	},
}
const FIRE_POS := Vector3(0, 0, 1.8)
## Yaw each station turns to face the fire / camera.
const STATION_SCALE := 1.3
const STATION_YAW := {"armory": 38.0, "workshop": 14.0, "pet_den": -14.0, "arcade": -38.0}

var rig: CameraRig
var hero: Character
var hero_class := ""
var pet_id := ""
var stations: Dictionary = {}
var locked: Dictionary = {}
var portrait := false
var _pet_holder: Node3D
var _pet_model: Node3D
var _deco: Node3D
var _fire_light: OmniLight3D
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _built := false
var _stone_mat: StandardMaterial3D
var _paths: Node3D


func _init() -> void:
	name = "CampScene"


func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func _build() -> void:
	if _built:
		return
	_built = true
	_rng.seed = 4242
	add_child(_environment())
	_lights()
	var island := MeshInstance3D.new()
	island.name = "Island"
	island.mesh = Biome.island_mesh(ISLAND_HALF, 12.0, LOOK.island_top, LOOK.island_side, LOOK.island_bottom, 911)
	add_child(island)
	# the walkable top: a finely subdivided plane with the camp ground shader (grass + clearing)
	var top := MeshInstance3D.new()
	top.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(ISLAND_HALF * 2.0, ISLAND_HALF * 2.0)
	pm.subdivide_width = 48
	pm.subdivide_depth = 48
	top.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://game/camp/camp_ground.gdshader")
	gm.set_shader_parameter("clear_center", Vector2(FIRE_POS.x, FIRE_POS.z - 0.9))
	gm.set_shader_parameter("clear_radius", Vector2(5.8, 4.5))
	gm.set_shader_parameter("island_half", ISLAND_HALF - 0.15)
	top.material_override = gm
	top.position.y = 0.004
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(top)
	add_child(Biome._cloud_sea(LOOK))
	_ground()
	_backdrop()
	_campfire()
	_pet_holder = Node3D.new()
	_pet_holder.name = "Pet"
	add_child(_pet_holder)
	for id in CampInfo.STATION_IDS:
		var s := _station(String(id))
		s.name = "Station_" + String(id)
		add_child(s)
		stations[id] = s
	_deco = Node3D.new()
	_deco.name = "Decorations"
	add_child(_deco)
	var ff := Biome.ambient_particles("fireflies")
	ff.amount = 40
	(ff.draw_pass_1 as QuadMesh).size = Vector2(0.08, 0.08)
	(ff.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(11.0, 1.6, 9.0)
	add_child(ff)
	rig = CameraRig.new()
	rig.fov = 36.0
	add_child(rig)
	set_hero("knight")


# ------------------------------------------------------------------ public API

## Applies a profile: hero = loadout class, pet = loadout pet, station locks, trophies.
func apply_profile(p: Profile) -> void:
	_build()
	set_hero(String(p.loadout.get("class", "knight")))
	set_pet(String(p.loadout.get("pet", "")))
	for id in CampInfo.STATION_IDS:
		set_locked(String(id), bool(CampInfo.station_state(p, String(id)).locked))
	_decorate(p)


func set_hero(class_id: String) -> void:
	if class_id == hero_class and hero != null:
		return
	hero_class = class_id
	if hero:
		hero.queue_free()
	var model := String(HeroDefs.DATA.get(class_id, HeroDefs.DATA.knight).model)
	hero = Character.create(model)
	hero.name = "Hero"
	hero.scale = Vector3.ONE * HERO_SCALE
	add_child(hero)
	_place_hero()
	hero.play("Sit_Chair_Idle")


## Equips the pet familiar shown next to the hero ("" = none).
func set_pet(id: String) -> void:
	_build()
	if id == pet_id and (_pet_model != null or id == ""):
		return
	pet_id = id
	if _pet_model:
		_pet_model.queue_free()
		_pet_model = null
	if id == "" or not PetDefs.has(id):
		return
	var m: Node3D = null
	if pet_factory.is_valid():
		m = pet_factory.call(id)
	if m == null:
		m = _pet_placeholder(id)
	_pet_model = m
	_pet_holder.add_child(m)


func set_locked(id: String, on: bool) -> void:
	if locked.get(id, null) == on:
		return
	locked[id] = on
	var s: Node3D = stations.get(id)
	if s == null:
		return
	var body: Node3D = s.get_node("Body")
	var cover: Node3D = s.get_node_or_null("Cover")
	if cover:
		cover.visible = on
	for l in s.find_children("*", "Light3D", true, false):
		(l as Light3D).visible = not on
	for pp in s.find_children("*", "GPUParticles3D", true, false):
		(pp as GPUParticles3D).emitting = not on
	body.visible = not on


## World point the UI hangs a station's label on.
func station_anchor(id: String) -> Vector3:
	var s: Node3D = stations.get(id)
	return s.global_position + Vector3.UP * (2.4 if id != "arcade" else 2.7) * STATION_SCALE if s else Vector3.ZERO


## Station under a screen point (3D picking against each station's footprint), or "".
func pick_station(screen_pos: Vector2) -> String:
	var cam := rig.camera
	var best := ""
	var best_d := INF
	for id in stations:
		var s: Node3D = stations[id]
		var base := s.global_position
		var a := cam.unproject_position(base + Vector3.UP * 0.2)
		var b := cam.unproject_position(base + Vector3.UP * 2.6)
		var r := cam.unproject_position(base + cam.global_basis.x * 1.9)
		var rad := maxf(40.0, a.distance_to(r))
		var d := _seg_dist(screen_pos, a, b)
		if d < rad and d < best_d:
			best_d = d
			best = String(id)
	return best


## Bounces a station (when its screen opens).
func bump(id: String) -> void:
	var s: Node3D = stations.get(id)
	if s == null:
		return
	var t := s.create_tween()
	t.tween_property(s, "scale", Vector3(1.08, 0.92, 1.08) * STATION_SCALE, 0.08)
	t.tween_property(s, "scale", Vector3.ONE * STATION_SCALE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Normalised screen rects the camp must fit into (the UI's free area).
func set_safe_rects(portrait_rect: Rect2, landscape_rect: Rect2) -> void:
	rig.safe_rect_portrait = portrait_rect
	rig.safe_rect_landscape = landscape_rect
	_frame(true)


func camera() -> Camera3D:
	return rig.camera


# ------------------------------------------------------------------ layout

func _on_resize() -> void:
	var vs := get_viewport().get_visible_rect().size
	var p := vs.y > vs.x * 0.9
	if p != portrait or not has_meta("laid_out"):
		portrait = p
		set_meta("laid_out", true)
		var lay: Dictionary = LAYOUT["portrait" if p else "landscape"]
		for id in stations:
			var s: Node3D = stations[id]
			s.position = lay[id]
			var yaw := float(STATION_YAW[id]) * (0.7 if p else 1.0)
			if p and id in ["armory", "arcade"]:
				yaw = 55.0 if id == "armory" else -55.0
			s.rotation.y = deg_to_rad(yaw)
		_place_deco_spots()
		_build_paths()
		layout_changed.emit()
	_frame(true)


## Stepping stones from the clearing to each station of the current layout.
func _build_paths() -> void:
	if _paths == null:
		return
	UiTheme.clear(_paths)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 if portrait else 98
	var from := FIRE_POS + Vector3(0, 0, -0.9)
	for id in stations:
		var to: Vector3 = (stations[id] as Node3D).position
		var dir := (to - from).normalized()
		var dist := from.distance_to(to)
		var k := 0
		var t := 3.2
		while t < dist - 1.9:
			var p := from + dir * t
			var st := MeshInstance3D.new()
			var sc := CylinderMesh.new()
			sc.top_radius = 0.32
			sc.bottom_radius = 0.38
			sc.height = 0.1
			sc.radial_segments = 7
			sc.rings = 1
			st.mesh = sc
			st.material_override = _stone_mat
			var side := Vector3(-dir.z, 0, dir.x) * (0.22 if k % 2 == 0 else -0.22)
			st.position = p + side + Vector3(0, 0.03, 0)
			st.rotation.y = rng.randf() * TAU
			st.scale = Vector3(1.0 + 0.25 * float(k % 3), 1.0, 0.85)
			_paths.add_child(st)
			t += 0.95
			k += 1


func _frame(instant := false) -> void:
	if rig == null:
		return
	var pts := PackedVector3Array()
	for id in stations:
		var s: Node3D = stations[id]
		var base: Vector3 = LAYOUT["portrait" if portrait else "landscape"][id]
		var side := 2.7 if id in ["armory", "arcade"] else 0.0
		pts.append(base + Vector3(-side if base.x < 0 else side, 0, 1.4))
		pts.append(base + Vector3.UP * 3.6)
	pts.append(FIRE_POS + Vector3(0, 0, 2.2))
	pts.append(_hero_spot() + Vector3(-0.4, 0, 1.4))
	rig.frame_points(pts, 0.0, 44.0 if portrait else 36.0, instant)


func _hero_spot() -> Vector3:
	return FIRE_POS + Vector3(-2.2, 0, 0.8)


func _place_hero() -> void:
	if hero == null:
		return
	hero.position = _hero_spot() + Vector3(0, 0.02, 0)
	# face the fire, three-quarter to the camera
	hero.rotation.y = deg_to_rad(62.0)
	_pet_holder.position = _hero_spot() + Vector3(0.55, 0, 1.45)


func _process(dt: float) -> void:
	_t += dt
	if _pet_model:
		_pet_model.position.y = 0.35 + sin(_t * 2.4) * 0.12
		_pet_model.rotation.y = sin(_t * 0.9) * 0.5 + 0.5
	if _fire_light:
		_fire_light.light_energy = 3.2 + sin(_t * 11.0) * 0.25 + sin(_t * 6.3 + 1.0) * 0.35 + sin(_t * 17.0) * 0.12


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ------------------------------------------------------------------ environment

func _environment() -> WorldEnvironment:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://game/world/shaders/sky.gdshader")
	sky_mat.set_shader_parameter("top_color", LOOK.sky_top)
	sky_mat.set_shader_parameter("horizon_color", LOOK.sky_horizon)
	sky_mat.set_shader_parameter("bottom_color", LOOK.sky_bottom)
	sky_mat.set_shader_parameter("glow_color", LOOK.sky_glow)
	sky_mat.set_shader_parameter("glow_strength", LOOK.glow_strength)
	sky_mat.set_shader_parameter("glow_dir", Vector3(0.3, 0.05, -1.0))
	sky_mat.set_shader_parameter("stars", LOOK.stars)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = LOOK.ambient
	env.ambient_light_energy = LOOK.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.08
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.4
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.12, 0.1, 0.22)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	return we


func _lights() -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = LOOK.moon
	moon.light_energy = LOOK.moon_energy
	moon.shadow_enabled = true
	moon.shadow_blur = 2.0
	moon.shadow_bias = 0.04
	moon.shadow_normal_bias = 1.2
	moon.directional_shadow_max_distance = 40.0
	moon.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	add_child(moon)
	var rim := DirectionalLight3D.new()
	rim.name = "Rim"
	rim.light_color = Color(0.95, 0.55, 0.45)
	rim.light_energy = 0.25
	rim.light_specular = 0.2
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	add_child(rim)
	# a big soft moon in the sky behind the camp
	var moon_disc := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(7, 7)
	moon_disc.mesh = q
	var mm := Props.glow_material(Color(1.0, 0.93, 0.8), true, 1.6)
	mm.albedo_texture = Props.particle_texture("dot")
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.no_depth_test = false
	moon_disc.material_override = mm
	moon_disc.position = Vector3(14.0, 17.0, -40.0)
	moon_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon_disc)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.6
	sm.height = 3.2
	core.mesh = sm
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1.0, 0.96, 0.86)
	core.material_override = cm
	core.position = moon_disc.position
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)


# ------------------------------------------------------------------ ground

func _ground() -> void:
	_stone_mat = StandardMaterial3D.new()
	_stone_mat.albedo_color = Color(0.56, 0.54, 0.58)
	_stone_mat.roughness = 0.95
	_paths = Node3D.new()
	_paths.name = "Paths"
	add_child(_paths)
	# grass tufts (forest pack grass) everywhere but the clearing and the stations
	var xs: Array = []
	var tries := 0
	while xs.size() < 700 and tries < 8000:
		tries += 1
		var x := _rng.randf_range(-ISLAND_HALF + 0.6, ISLAND_HALF - 0.6)
		var z := _rng.randf_range(-ISLAND_HALF + 0.6, ISLAND_HALF - 0.6)
		var r := pow(pow(absf(x) / (ISLAND_HALF - 0.5), 8.0) + pow(absf(z) / (ISLAND_HALF - 0.5), 8.0), 1.0 / 8.0)
		if r > 1.0:
			continue
		if Vector2((x - FIRE_POS.x) / 5.8, (z - FIRE_POS.z + 0.9) / 4.5).length() < 1.05:
			continue
		var near := false
		for lay in [LAYOUT.landscape, LAYOUT.portrait]:
			for id in lay:
				if Vector2(x, z).distance_to(Vector2(lay[id].x, lay[id].z)) < 1.9:
					near = true
		if near:
			continue
		xs.append(Vector3(x, 0, z))
	for variant in 2:
		var mesh := _mesh_of(FOREST % [1, "Grass_%d_A" % (variant + 1), 1])
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		var mine: Array = []
		for i in xs.size():
			if i % 2 == variant:
				mine.append(xs[i])
		mm.instance_count = mine.size()
		for i in mine.size():
			var sc := _rng.randf_range(0.45, 0.85)
			mm.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * sc), mine[i]))
			mm.set_instance_color(i, Color(1, 1, 1).darkened(_rng.randf_range(0.0, 0.25)))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Grass%d" % variant
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## The first mesh inside a glTF scene (for MultiMesh scattering).
func _mesh_of(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var n: Node = (load(path) as PackedScene).instantiate()
	var out: Mesh = null
	for m in n.find_children("*", "MeshInstance3D", true, false):
		out = (m as MeshInstance3D).mesh
		break
	n.free()
	return out


func _forest(parent: Node3D, name: String, color: int, pos: Vector3, yaw: float, scale: float) -> Node3D:
	var path := FOREST % [color, name, color]
	if not ResourceLoader.exists(path):
		return Node3D.new()
	return Props.put(parent, path, pos, yaw, scale)


# ------------------------------------------------------------------ backdrop

func _backdrop() -> void:
	var H := Props.HAL
	var d := Node3D.new()
	d.name = "Backdrop"
	add_child(d)
	# a wood of round trees and tall pines around the back and sides (greens, teal, a few autumn)
	var trees := [
		["Tree_3_B", 1, Vector3(-13.5, 0, -12.0)], ["Tree_5_C", 2, Vector3(-10.4, 0, -13.2)], ["Tree_1_B", 4, Vector3(-7.4, 0, -12.6)],
		["Tree_6_C", 2, Vector3(-5.0, 0, -13.6)], ["Tree_3_C", 1, Vector3(-1.2, 0, -13.4)], ["Tree_5_E", 4, Vector3(1.8, 0, -12.8)],
		["Tree_1_C", 2, Vector3(5.6, 0, -13.2)], ["Tree_6_B", 6, Vector3(8.4, 0, -12.2)], ["Tree_3_B", 4, Vector3(11.2, 0, -13.0)],
		["Tree_5_C", 1, Vector3(13.8, 0, -11.0)], ["Tree_1_B", 2, Vector3(-14.2, 0, -7.4)], ["Tree_2_C", 1, Vector3(14.4, 0, -6.6)],
		["Tree_7_B", 4, Vector3(-14.4, 0, -2.6)], ["Tree_3_A", 6, Vector3(14.6, 0, -1.8)], ["Tree_5_B", 2, Vector3(-14.0, 0, 2.4)],
		["Tree_1_A", 1, Vector3(14.2, 0, 3.0)], ["Tree_6_A", 4, Vector3(-13.2, 0, 7.6)], ["Tree_3_A", 2, Vector3(13.6, 0, 8.2)],
		["Tree_2_B", 6, Vector3(-9.8, 0, -9.6)], ["Tree_4_B", 1, Vector3(10.2, 0, -9.4)],
	]
	for t in trees:
		_forest(d, String(t[0]), int(t[1]), t[2], _rng.randf() * 360.0, _rng.randf_range(0.95, 1.2))
	var bushes := [Vector3(-11.5, 0, -8.6), Vector3(11.8, 0, -8.2), Vector3(-6.8, 0, -9.6), Vector3(6.6, 0, -9.8), Vector3(0.2, 0, -10.6),
		Vector3(-12.2, 0, -4.4), Vector3(12.4, 0, -3.8), Vector3(-11.8, 0, 4.6), Vector3(12.0, 0, 5.2), Vector3(-8.4, 0, 8.6),
		Vector3(8.8, 0, 8.2), Vector3(-2.8, 0, -10.2), Vector3(3.6, 0, -10.4), Vector3(-10.6, 0, 1.2), Vector3(10.8, 0, 1.6)]
	for i in bushes.size():
		_forest(d, "Bush_%d_%s" % [[1, 2, 4][i % 3], ["C", "D", "E"][i % 3]], [1, 2, 4][i % 3], bushes[i], _rng.randf() * 360.0, _rng.randf_range(1.0, 1.4))
	var rocks := [Vector3(-9.6, 0, 7.6), Vector3(9.9, 0, 7.0), Vector3(-12.6, 0, -1.0), Vector3(12.8, 0, -0.4), Vector3(-5.6, 0, 9.8),
		Vector3(6.2, 0, 9.6), Vector3(0.0, 0, -9.0)]
	for i in rocks.size():
		_forest(d, "Rock_%d_%s" % [[1, 3, 5][i % 3], ["A", "B", "C"][i % 3]], 1, rocks[i], _rng.randf() * 360.0, _rng.randf_range(1.2, 1.8))
	# two tents at the back, a woodpile and a cart of supplies
	_tent(d, Vector3(-6.2, 0, -9.4), 20.0, Color(0.86, 0.6, 0.36))
	_tent(d, Vector3(6.4, 0, -9.6), -18.0, Color(0.48, 0.6, 0.86))
	Props.put(d, RES + "Wood_Log_Stack.gltf", Vector3(-10.2, 0, -5.8), 70.0, 1.1)
	Props.put(d, RES + "Wood_Log_A.gltf", Vector3(-9.1, 0, -4.6), 10.0, 1.0)
	Props.put(d, RES + "Textiles_Stack_Large_Colored.gltf", Vector3(10.4, 0, -5.4), -30.0, 1.0)
	Props.put(d, Props.DUN + "crates_stacked.gltf", Vector3(11.2, 0, -3.4), -60.0, 0.8)
	# lantern posts around the clearing, string lights between them
	var posts := [Vector3(-5.6, 0, 4.4), Vector3(5.6, 0, 4.4), Vector3(-5.2, 0, -3.2), Vector3(5.2, 0, -3.2)]
	for p in posts:
		Props.put(d, H + "post_lantern.gltf", p, 90.0 if p.x < 0 else -90.0, 0.95)
		Biome.flicker_light(d, p + Vector3(0, 2.7, 0), Color(1.0, 0.72, 0.42), 1.5, 5.0)
	_string_lights(d, posts[0] + Vector3(0, 3.0, 0), posts[2] + Vector3(0, 3.0, 0), 8, Color(1.0, 0.8, 0.45))
	_string_lights(d, posts[1] + Vector3(0, 3.0, 0), posts[3] + Vector3(0, 3.0, 0), 8, Color(1.0, 0.65, 0.4))
	_string_lights(d, posts[2] + Vector3(0, 3.0, 0), posts[3] + Vector3(0, 3.0, 0), 11, Color(1.0, 0.75, 0.5))
	# flowers near the front edge
	BiomeBlocks._rng.seed = 77
	BiomeBlocks.flower_patch(d, Vector3(-8.5, 0, 9.4), 1.8, 22)
	BiomeBlocks.flower_patch(d, Vector3(8.8, 0, 9.0), 1.6, 18)
	BiomeBlocks.flower_patch(d, Vector3(-11.8, 0, -1.6), 1.2, 10)

func _tent(parent: Node3D, pos: Vector3, yaw: float, color: Color) -> void:
	var n := Node3D.new()
	n.name = "Tent"
	n.position = pos
	n.rotation.y = deg_to_rad(yaw)
	parent.add_child(n)
	var w := 1.25
	var h := 1.55
	var depth := 2.2
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(sqrt(w * w + h * h), 0.06, depth)
		mi.mesh = BiomeBlocks.faceted(bx, color if side < 0 else color.darkened(0.12), 0.0, 5)
		mi.position = Vector3(side * w * 0.5, h * 0.5, 0)
		mi.rotation.z = -side * atan2(h, w)
		n.add_child(mi)
	# back wall and a dark opening
	var back := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(color.darkened(0.3))
	for v in [Vector3(-w, 0, -depth * 0.5), Vector3(0, h, -depth * 0.5), Vector3(w, 0, -depth * 0.5)]:
		st.set_normal(Vector3.FORWARD)
		st.add_vertex(v)
	st.set_color(Color(0.06, 0.04, 0.05))
	for v in [Vector3(-w * 0.7, 0, depth * 0.48), Vector3(w * 0.7, 0, depth * 0.48), Vector3(0, h * 0.72, depth * 0.48)]:
		st.set_normal(Vector3.BACK)
		st.add_vertex(v)
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	back.mesh = m
	n.add_child(back)
	# a warm glow inside
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = 1.2
	l.omni_range = 2.4
	l.position = Vector3(0, 0.5, 0.2)
	n.add_child(l)
	# ridge pole
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.04
	cm.height = depth + 0.3
	cm.radial_segments = 5
	pole.mesh = cm
	pole.material_override = Props.flat_material(Color(0.4, 0.26, 0.16))
	pole.rotation.x = PI * 0.5
	pole.position = Vector3(0, h + 0.02, 0)
	n.add_child(pole)


func _string_lights(parent: Node3D, a: Vector3, b: Vector3, n: int, color: Color) -> void:
	var bulbs := MultiMesh.new()
	bulbs.transform_format = MultiMesh.TRANSFORM_3D
	bulbs.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 6
	sm.rings = 3
	bulbs.mesh = sm
	bulbs.instance_count = n
	var cols := [color, Color(1.0, 0.5, 0.5), Color(0.6, 0.85, 1.0), Color(0.7, 1.0, 0.6)]
	for k in n:
		var t := float(k + 1) / float(n + 1)
		var p := a.lerp(b, t) + Vector3.DOWN * sin(t * PI) * 0.45
		bulbs.set_instance_transform(k, Transform3D(Basis(), p))
		bulbs.set_instance_color(k, cols[k % cols.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = bulbs
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(2.2, 2.2, 2.2)
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


# ------------------------------------------------------------------ campfire

func _campfire() -> void:
	var fire := TileStyle.make_prop("campfire")
	fire.name = "Campfire"
	fire.position = FIRE_POS
	fire.scale = Vector3.ONE * 2.3
	add_child(fire)
	for l in fire.find_children("*", "OmniLight3D", true, false):
		(l as OmniLight3D).visible = false
	_fire_light = OmniLight3D.new()
	_fire_light.name = "FireLight"
	_fire_light.light_color = Color(1.0, 0.56, 0.24)
	_fire_light.light_energy = 3.2
	_fire_light.omni_range = 12.0
	_fire_light.omni_attenuation = 1.3
	_fire_light.shadow_enabled = true
	_fire_light.position = FIRE_POS + Vector3(0, 1.3, 0)
	add_child(_fire_light)
	Biome.flame(self, FIRE_POS + Vector3(0, 0.55, 0), Color(1.0, 0.45, 0.12), 0.9, 18)
	# embers rising into the night
	var e := GPUParticles3D.new()
	e.name = "Embers"
	e.amount = 28
	e.lifetime = 3.2
	e.preprocess = 3.0
	e.position = FIRE_POS + Vector3(0, 0.7, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0.08, 0.15, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 1.6
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.9, 0.5, 0.0), Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.35, 0.08, 0.9), Color(0.6, 0.1, 0.05, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	e.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = Props.particle_material("hard")
	e.draw_pass_1 = q
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))
	add_child(e)
	BiomeBlocks.smoke(self, FIRE_POS + Vector3(0, 1.4, 0), 0.8, Color(0.16, 0.14, 0.2, 0.35))
	# log seats around the fire
	Props.put(self, RES + "Wood_Log_B.gltf", _hero_spot() + Vector3(0.05, 0, 0), 62.0, 0.95)
	Props.put(self, RES + "Wood_Log_B.gltf", FIRE_POS + Vector3(2.2, 0, 0.6), -60.0, 0.95)
	Props.put(self, RES + "Wood_Log_A.gltf", FIRE_POS + Vector3(0.2, 0, -2.3), 90.0, 0.9)
	# a kettle and a few cosy bits
	var D := Props.DUN
	Props.put(self, D + "barrel_small.gltf", FIRE_POS + Vector3(3.2, 0, -0.9), 20.0, 0.9)
	Props.put(self, RES + "Wood_Log_Stack.gltf", FIRE_POS + Vector3(-3.3, 0, -1.6), -30.0, 0.8)
	Props.put(self, Props.TOOLS + "bucket_metal.gltf", FIRE_POS + Vector3(2.7, 0, 1.6), 0.0, 1.1)


# ------------------------------------------------------------------ stations

func _station(id: String) -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * STATION_SCALE
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	match id:
		"armory":
			_armory(body)
		"workshop":
			_workshop(body)
		"pet_den":
			_pet_den(body)
		"arcade":
			_arcade(body)
	var cover := _covered(id)
	cover.name = "Cover"
	cover.visible = false
	root.add_child(cover)
	return root


## A locked station: a tarp-covered pile with rope and a wooden sign.
func _covered(id: String) -> Node3D:
	var n := Node3D.new()
	var tarp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.2
	sm.radial_segments = 9
	sm.rings = 4
	sm.is_hemisphere = true
	var col := Color(0.42, 0.36, 0.3) if id == "armory" else Color(0.36, 0.34, 0.44)
	tarp.mesh = BiomeBlocks.faceted(sm, col, 0.1, 3 + id.length(), col.darkened(0.3), Vector3(1.25, 1.1, 0.95))
	n.add_child(tarp)
	for p in [Vector3(-1.1, 0, 0.5), Vector3(1.15, 0, 0.45), Vector3(0.0, 0, 1.05)]:
		var peg := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.08, 0.3, 0.08)
		peg.mesh = bx
		peg.material_override = Props.flat_material(Color(0.4, 0.28, 0.18))
		peg.position = p + Vector3.UP * 0.12
		n.add_child(peg)
	Props.put(n, RES + "Pallet_Wood.gltf", Vector3(-0.3, 0.0, 1.35), 12.0, 0.9)
	Props.put(n, RES + "Wood_Planks_Stack_Small.gltf", Vector3(-0.3, 0.3, 1.35), 100.0, 0.85)
	Props.put(n, RES + "Wood_Log_B.gltf", Vector3(1.2, 0.0, 1.0), 60.0, 0.7)
	n.scale = Vector3.ONE * 1.15
	return n


func _armory(b: Node3D) -> void:
	var D := Props.DUN
	var W := Props.WPN
	# platform of wooden planks
	var floor := Props.put(b, D + "floor_wood_small.gltf", Vector3(0, -0.02, 0), 0.0, 1.0)
	Props.set_shadows(floor, false)
	# anvil on a stump
	var stump := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.32
	cm.bottom_radius = 0.38
	cm.height = 0.5
	cm.radial_segments = 8
	cm.rings = 1
	stump.mesh = BiomeBlocks.faceted(cm, Color(0.46, 0.3, 0.2), 0.02, 4)
	stump.position = Vector3(0.35, 0.25, 0.45)
	b.add_child(stump)
	Props.put(b, Props.TOOLS + "anvil.gltf", Vector3(0.35, 0.5, 0.45), 90.0, 1.6)
	Props.put(b, Props.TOOLS + "hammer.gltf", Vector3(0.62, 0.02, 0.95), 40.0, 1.5)
	# weapon rack: two posts, two rails, weapons leaning in
	var wood := Color(0.44, 0.29, 0.18)
	for x in [-0.95, 0.35]:
		var post := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.12, 1.5, 0.12)
		post.mesh = BiomeBlocks.faceted(bx, wood, 0.0, 2)
		post.position = Vector3(x - 0.3, 0.75, -0.45)
		b.add_child(post)
	for y in [0.55, 1.3]:
		var rail := MeshInstance3D.new()
		var bx2 := BoxMesh.new()
		bx2.size = Vector3(1.55, 0.09, 0.1)
		rail.mesh = BiomeBlocks.faceted(bx2, wood.lightened(0.08), 0.0, 3)
		rail.position = Vector3(-0.6, y, -0.45)
		b.add_child(rail)
	var ws := [["sword_A.gltf", -1.0], ["axe_A.gltf", -0.62], ["sword_C.gltf", -0.26], ["hammer_B.gltf", 0.1]]
	for w in ws:
		var n := Props.put(b, W + String(w[0]), Vector3(float(w[1]), 0.1, -0.35), 0.0, 1.35)
		n.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	Props.put(b, W + "shield_A.gltf", Vector3(-0.5, 0.05, 0.25), 20.0, 1.3).rotation_degrees.x = -70.0
	Props.put(b, D + "barrel_small.gltf", Vector3(1.15, 0, -0.2), 30.0, 0.85)
	Props.put(b, D + "sword_shield.gltf", Vector3(1.1, 0.62, -0.2), 0.0, 0.8)
	var torch := Props.put(b, D + "torch_lit.gltf", Vector3(-1.3, 0, 0.5), 0.0, 1.1)
	torch.name = "Torch"
	Biome.flicker_light(b, Vector3(-1.3, 1.5, 0.5), Color(1.0, 0.6, 0.3), 1.6, 3.8)
	Props.put(b, D + "banner_patternA_red.gltf", Vector3(-0.6, 1.5, -0.55), 0.0, 0.75)


func _workshop(b: Node3D) -> void:
	var D := Props.DUN
	var T := Props.TOOLS
	var B := Props.BGB
	var floor := Props.put(b, D + "floor_wood_small.gltf", Vector3(0, -0.02, 0), 0.0, 1.0)
	Props.set_shadows(floor, false)
	Props.put(b, D + "table_medium.gltf", Vector3(0, 0, -0.1), 0.0, 1.0)
	var top := 0.95
	Props.put(b, T + "saw.gltf", Vector3(-0.55, top, -0.25), 20.0, 1.2)
	Props.put(b, T + "wrench_A.gltf", Vector3(-0.2, top, 0.15), 60.0, 1.3)
	Props.put(b, T + "blueprint.gltf", Vector3(0.15, top, -0.2), -10.0, 1.1)
	Props.put(b, T + "pencil_A_long.gltf", Vector3(0.3, top + 0.02, 0.05), 30.0, 1.3)
	var lamp := Props.put(b, T + "lantern.gltf", Vector3(0.62, top, -0.35), 0.0, 1.2)
	lamp.name = "Lamp"
	Biome.flicker_light(b, Vector3(0.62, top + 0.6, -0.2), Color(1.0, 0.8, 0.5), 1.4, 3.4)
	# big showcase dice
	var d1 := Props.put(b, B + "D6_A_blue.gltf", Vector3(0.9, 0.0, 0.55), 25.0, 3.4)
	d1.name = "BigDie"
	Props.put(b, B + "D6_B_red.gltf", Vector3(-0.95, 0.0, 0.65), -15.0, 2.6)
	Props.put(b, B + "D20_yellow.gltf", Vector3(-0.2, top, 0.3), 0.0, 1.8)
	Props.put(b, B + "D6_A_green.gltf", Vector3(1.28, 0.0, 0.05), 50.0, 2.0)
	Props.put(b, D + "box_small.gltf", Vector3(-1.2, 0, -0.35), 10.0, 0.9)
	Props.put(b, D + "shelf_small_candles.gltf", Vector3(0.0, 0, -0.85), 0.0, 1.0)
	Props.put(b, T + "handdrill.gltf", Vector3(-1.2, 0.72, -0.3), 0.0, 1.3)


func _pet_den(b: Node3D) -> void:
	var H := Props.HAL
	var D := Props.DUN
	# a little lean-to roof over a soft bed
	var wood := Color(0.46, 0.3, 0.2)
	for x in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.12, 1.55, 0.12)
		post.mesh = BiomeBlocks.faceted(bx, wood, 0.0, 6)
		post.position = Vector3(x, 0.78, 0.45)
		b.add_child(post)
	var roof := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(2.5, 0.1, 1.9)
	roof.mesh = BiomeBlocks.faceted(rb, Color(0.72, 0.36, 0.26), 0.0, 8, Color(0.5, 0.22, 0.16))
	roof.position = Vector3(0, 1.45, -0.15)
	roof.rotation.x = deg_to_rad(-16.0)
	b.add_child(roof)
	var back := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(2.3, 1.2, 0.1)
	back.mesh = BiomeBlocks.faceted(bb, wood.darkened(0.15), 0.0, 9)
	back.position = Vector3(0, 0.6, -0.95)
	b.add_child(back)
	Props.put(b, D + "bed_floor.gltf", Vector3(0, 0, -0.25), 0.0, 0.85)
	Props.put(b, H + "pumpkin_orange_jackolantern.gltf", Vector3(-1.05, 0, 0.9), 20.0, 1.3)
	Props.put(b, H + "pumpkin_yellow_small.gltf", Vector3(-0.6, 0, 1.15), -30.0, 1.2)
	Props.put(b, H + "pumpkin_orange.gltf", Vector3(1.1, 0, 0.95), 10.0, 1.0)
	Biome.flicker_light(b, Vector3(-1.05, 0.5, 1.0), Color(1.0, 0.55, 0.2), 1.1, 2.4)
	var lan := Props.put(b, H + "lantern_hanging.gltf", Vector3(0.8, 1.3, 0.55), 0.0, 1.1)
	lan.name = "Lantern"
	Biome.flicker_light(b, Vector3(0.8, 1.1, 0.7), Color(1.0, 0.72, 0.4), 1.2, 3.2)
	Props.put(b, H + "candle_triple.gltf", Vector3(1.25, 0, -0.4), 0.0, 1.0)
	# a food bowl
	Props.put(b, D + "plate_food_A.gltf", Vector3(0.55, 0, 0.9), 0.0, 1.0)


func _arcade(b: Node3D) -> void:
	var B := Props.BGB
	var P := Props.PLAT
	# checkered booth floor of coloured game tiles
	var tiles := ["tile_red.gltf", "tile_blue.gltf", "tile_yellow.gltf", "tile_green.gltf"]
	for ix in 3:
		for iz in 3:
			var t := Props.put(b, B + tiles[(ix + iz * 2) % 4], Vector3(-0.72 + ix * 0.72, -0.08, -0.5 + iz * 0.72), 0.0, 0.72)
			Props.set_shadows(t, false)
	# claw machine: cabinet, glass case, prize pile, claw, marquee
	var cab := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(1.1, 0.9, 1.0)
	cab.mesh = BiomeBlocks.faceted(bx, Color(0.9, 0.3, 0.62), 0.0, 1, Color(0.55, 0.16, 0.4))
	cab.position = Vector3(0, 0.45, -0.2)
	b.add_child(cab)
	var glass := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(1.04, 1.0, 0.94)
	glass.mesh = gb
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.7, 0.9, 1.0, 0.18)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.1
	gm.metallic_specular = 0.9
	glass.material_override = gm
	glass.position = Vector3(0, 1.4, -0.2)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(glass)
	for x in [-0.53, 0.53]:
		for z in [-0.66, 0.26]:
			var pole := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(0.06, 1.0, 0.06)
			pole.mesh = pb
			pole.material_override = Props.flat_material(Color(0.95, 0.85, 0.4), 0.4)
			pole.position = Vector3(x, 1.4, z)
			b.add_child(pole)
	var roof := MeshInstance3D.new()
	var rbx := BoxMesh.new()
	rbx.size = Vector3(1.2, 0.34, 1.1)
	roof.mesh = BiomeBlocks.faceted(rbx, Color(0.45, 0.3, 0.85), 0.0, 3, Color(0.3, 0.18, 0.6))
	roof.position = Vector3(0, 2.05, -0.2)
	b.add_child(roof)
	var marquee := MeshInstance3D.new()
	var mq := BoxMesh.new()
	mq.size = Vector3(1.0, 0.18, 0.04)
	marquee.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.85, 0.35)
	mm.emission_enabled = true
	mm.emission = Color(1.0, 0.75, 0.3)
	mm.emission_energy_multiplier = 2.2
	marquee.material_override = mm
	marquee.position = Vector3(0, 2.05, 0.36)
	b.add_child(marquee)
	# prizes
	var prizes := [[P + "yellow/star_yellow.gltf", Vector3(-0.25, 1.0, -0.3), 0.55], [P + "red/heart_red.gltf", Vector3(0.22, 0.98, -0.05), 0.5],
		[P + "blue/diamond_blue.gltf", Vector3(0.05, 1.0, -0.45), 0.5], [B + "coin_gold.gltf", Vector3(-0.3, 0.93, 0.05), 1.2],
		[B + "D6_A_red.gltf", Vector3(0.3, 0.92, -0.42), 1.5]]
	for pz in prizes:
		var n := Props.put(b, String(pz[0]), pz[1], _rng.randf() * 360.0, float(pz[2]))
		n.rotation.x = _rng.randf_range(-0.3, 0.3)
	# the claw
	var claw := Node3D.new()
	claw.name = "Claw"
	claw.position = Vector3(0.1, 1.82, -0.2)
	b.add_child(claw)
	var rope := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.015
	rc.bottom_radius = 0.015
	rc.height = 0.35
	rope.mesh = rc
	rope.material_override = Props.flat_material(Color(0.8, 0.8, 0.85), 0.3)
	claw.add_child(rope)
	for k in 3:
		var prong := MeshInstance3D.new()
		var pbm := BoxMesh.new()
		pbm.size = Vector3(0.04, 0.2, 0.04)
		prong.mesh = pbm
		prong.material_override = Props.flat_material(Color(0.85, 0.85, 0.9), 0.25)
		var a := TAU * k / 3.0
		prong.position = Vector3(cos(a) * 0.07, -0.25, sin(a) * 0.07)
		prong.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
		claw.add_child(prong)
	var sway := claw.create_tween().set_loops()
	sway.tween_property(claw, "position:x", -0.2, 2.2).set_trans(Tween.TRANS_SINE)
	sway.tween_property(claw, "position:x", 0.25, 2.2).set_trans(Tween.TRANS_SINE)
	# coin slot panel + joystick
	var knob := MeshInstance3D.new()
	var ks := SphereMesh.new()
	ks.radius = 0.08
	ks.height = 0.16
	knob.mesh = ks
	knob.material_override = Props.flat_material(Color(1.0, 0.25, 0.3), 0.3)
	knob.position = Vector3(-0.25, 1.02, 0.28)
	b.add_child(knob)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.85)
	glow.light_energy = 1.6
	glow.omni_range = 3.2
	glow.position = Vector3(0, 1.5, 0.4)
	b.add_child(glow)
	Props.put(b, B + "flag_A_yellow.gltf", Vector3(-0.95, 0, 0.55), 0.0, 1.2)
	Props.put(b, B + "flag_B_blue.gltf", Vector3(0.95, 0, 0.55), 0.0, 1.2)
	Props.put(b, B + "coin_10_gold.gltf", Vector3(0.7, 0.0, 0.8), 30.0, 1.4)
	Props.put(b, B + "coin_5_silver.gltf", Vector3(0.95, 0.0, 0.6), 0.0, 1.4)


# ------------------------------------------------------------------ pet + decorations

func _pet_placeholder(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Pet_" + id
	var H := Props.HAL
	match String(PetDefs.DEFS[id].model):
		"pumpkin":
			Props.put(n, H + "pumpkin_orange_jackolantern.gltf", Vector3.ZERO, 200.0, 0.62)
			_pet_light(n, Color(1.0, 0.55, 0.2))
		"skull":
			Props.put(n, H + "skull.gltf", Vector3.ZERO, 180.0, 0.9)
			_pet_light(n, Color(0.7, 0.9, 1.0))
		"lantern":
			Props.put(n, H + "lantern_standing.gltf", Vector3.ZERO, 0.0, 0.8)
			_pet_light(n, Color(0.5, 1.0, 0.85))
		"crystal":
			BiomeBlocks.crystal_cluster(n, Vector3.ZERO, 0.32, 4, 7)
			_pet_light(n, Color(0.6, 0.85, 1.0))
		"die":
			Props.put(n, Props.BGB + "D6_A_blue.gltf", Vector3(0, 0.35, 0), 20.0, 1.1)
			_pet_light(n, Color(0.5, 0.7, 1.0))
		"chest":
			Props.put(n, Props.DUN + "chest.gltf", Vector3.ZERO, 200.0, 0.45)
			_pet_light(n, Color(1.0, 0.8, 0.3))
	return n


func _pet_light(n: Node3D, c: Color) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 0.9
	l.omni_range = 1.8
	l.position = Vector3(0, 0.5, 0.3)
	n.add_child(l)


## Milestone decorations: a skull trophy per final boss beaten, a banner per class that has
## won, a golden chest after the first win, a flag per biome discovered beyond the start.
func _decorate(p: Profile) -> void:
	UiTheme.clear(_deco)
	var f: Dictionary = p.records.get("firsts", {})
	var bosses: Array = f.get("boss", [])
	var classes: Array = f.get("class_win", [])
	for i in bosses.size():
		var t := Props.put(_deco, Props.HAL + "post_skull.gltf", Vector3.ZERO, 0.0, 0.62)
		t.set_meta("spot", "trophy")
		t.set_meta("i", i)
	var colors := {"knight": "blue", "barbarian": "red", "mage": "white", "rogue": "green"}
	for i in classes.size():
		var c := String(classes[i])
		var bn := Props.put(_deco, Props.DUN + "banner_shield_%s.gltf" % String(colors.get(c, "yellow")), Vector3.ZERO, 0.0, 0.7)
		bn.set_meta("spot", "banner")
		bn.set_meta("i", i)
	if int(p.records.get("wins", 0)) > 0:
		var ch := Props.put(_deco, Props.DUN + "chest_gold.gltf", Vector3.ZERO, 0.0, 0.7)
		ch.set_meta("spot", "chest")
		ch.set_meta("i", 0)
	_place_deco_spots()


func _place_deco_spots() -> void:
	if _deco == null:
		return
	for n in _deco.get_children():
		var i := int(n.get_meta("i", 0))
		match String(n.get_meta("spot", "")):
			"trophy":
				n.position = FIRE_POS + Vector3(-1.6 + i * 1.05, 0, -3.9)
				n.rotation.y = deg_to_rad(90.0)
			"banner":
				n.position = Vector3(-2.3 + i * 1.55, 0.0, -11.2)
			"chest":
				n.position = FIRE_POS + Vector3(3.2, 0, 2.5) if not portrait else FIRE_POS + Vector3(2.8, 0, 2.8)
				n.rotation.y = deg_to_rad(-35.0)
