extends RefCounted
## Actor scenarios for the screenshot harness.
##  actors        all 8 models idling + a bone-tinted skeleton mannequin (skel_idle)
##  actors_anims  same line-up, each model looping a different alias (attack, cast, hit...)
## Optional `--anim=<alias>` plays that alias on everyone (e.g. --anim=attack).

const LINEUP := [
	# [model id, label, alias, tint, grid col, grid row (0 = back)]
	["mannequin_large", "Mannequin L", "idle", null, 0, 0],
	["mage", "Mage", "idle", null, 1, 0],
	["barbarian", "Barbarian", "idle", null, 2, 0],
	["ranger", "Ranger", "idle", null, 0, 1],
	["knight", "Knight", "idle", null, 1, 1],
	["rogue_hooded", "Rogue (hooded)", "idle", null, 2, 1],
	["rogue", "Rogue", "idle", null, 0, 2],
	["mannequin", "Skeleton", "skel_idle", "bone", 1, 2],
	["mannequin", "Mannequin", "idle", null, 2, 2],
]
const ACTIONS := ["attack", "cast", "attack", "shoot", "attack", "hit", "attack", "skel_walk", "cheer"]
const BONE := Color(0.93, 0.9, 0.8)
const SPACING := Vector2(2.5, 3.3)


static func names() -> PackedStringArray:
	return PackedStringArray(["actors", "actors_anims"])


static func build(name: String) -> Node:
	if not names().has(name):
		return null
	var root := Node3D.new()
	root.name = "ActorsStage"
	_add_environment(root)
	_add_floor(root)
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var forced := String(Shot.args.get("anim", ""))
	for i in LINEUP.size():
		var e: Array = LINEUP[i]
		var ch := Character.create(e[0])
		var x := (float(e[4]) - 1.0) * SPACING.x
		var z := (float(e[5]) - 1.0) * SPACING.y
		ch.position = Vector3(x, 0.0, z)
		ch.rotation.y = deg_to_rad(-12.0 * (float(e[4]) - 1.0))
		root.add_child(ch)
		if e[3] == "bone":
			ch.set_tint(BONE, 0.9)
		var alias: String = e[2]
		if name == "actors_anims":
			alias = ACTIONS[i]
		if forced != "":
			alias = forced
		_loop(ch, alias)
		var label := Label3D.new()
		label.text = "%s\n%s" % [e[1], alias]
		label.font = font
		label.font_size = 56
		label.pixel_size = 0.005
		label.outline_size = 14
		label.outline_modulate = Color(0.08, 0.06, 0.1, 0.9)
		label.modulate = Color(1.0, 0.86, 0.5)
		label.position = Vector3(x, 0.05, z + 0.95)
		label.rotation_degrees.x = -90.0
		root.add_child(label)
	var cam := _FitCamera.new()
	root.add_child(cam)
	cam.current = true
	# Audio smoke test: a test sfx and the title bed.
	Audio.play_sfx("dice_roll")
	Audio.play_music("title", 0.5)
	print("AUDIO_OK sfx=dice_roll music=title")
	return root


## Loops an alias: looping clips just play, one-shots replay after a short pause.
static func _loop(ch: Character, alias: String) -> void:
	var clip := ch.resolve(alias)
	if clip == "":
		push_warning("actors: %s has no '%s'" % [ch.model_id, alias])
		return
	if ch.anim_player.get_animation(clip).loop_mode != Animation.LOOP_NONE:
		ch.play(alias, 0.0)
		return
	ch.ready.connect(func() -> void: _repeat(ch, alias), CONNECT_ONE_SHOT)


static func _repeat(ch: Character, alias: String) -> void:
	while is_instance_valid(ch) and ch.is_inside_tree():
		await ch.play_once(alias, "idle")
		if not is_instance_valid(ch) or not ch.is_inside_tree():
			return
		await ch.get_tree().create_timer(0.35).timeout


static func _add_environment(root: Node3D) -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.2, 0.36)
	sky_mat.sky_horizon_color = Color(0.55, 0.47, 0.52)
	sky_mat.ground_horizon_color = Color(0.3, 0.24, 0.26)
	sky_mat.ground_bottom_color = Color(0.08, 0.07, 0.1)
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.36, 0.3, 0.38)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color(1.0, 0.86, 0.68)
	key.light_energy = 1.7
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 30.0
	key.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	root.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.55, 0.68, 1.0)
	fill.light_energy = 0.45
	fill.rotation_degrees = Vector3(-30.0, 150.0, 0.0)
	root.add_child(fill)

	var rim := OmniLight3D.new()
	rim.light_color = Color(1.0, 0.55, 0.3)
	rim.light_energy = 2.0
	rim.omni_range = 9.0
	rim.position = Vector3(0.0, 3.5, -5.5)
	root.add_child(rim)


static func _add_floor(root: Node3D) -> void:
	var tile: PackedScene = load("res://assets/kaykit/dungeon/floor_tile_large.gltf")
	var alt: PackedScene = load("res://assets/kaykit/dungeon/floor_tile_small_decorated.gltf")
	for gx in range(-5, 5):
		for gz in range(-7, 3):
			var t: Node3D = tile.instantiate()
			t.position = Vector3(gx * 4.0 + 2.0, -0.15, gz * 4.0 + 2.0)
			root.add_child(t)
	for p in [Vector3(-5.0, 0.0, -1.0), Vector3(5.0, 0.0, 1.0)]:
		var a: Node3D = alt.instantiate()
		a.position = p + Vector3(0, -0.14, 0)
		root.add_child(a)
	var props := {
		"res://assets/kaykit/dungeon/torch_lit.gltf": [Vector3(-4.2, 0.0, -4.6), Vector3(4.2, 0.0, -4.6)],
		"res://assets/kaykit/dungeon/barrel_large.gltf": [Vector3(-4.6, 0.0, -2.2)],
		"res://assets/kaykit/dungeon/chest_gold.gltf": [Vector3(4.4, 0.0, -2.4)],
		"res://assets/kaykit/dungeon/crates_stacked.gltf": [Vector3(-5.8, 0.0, -5.4)],
	}
	for path in props:
		var ps: PackedScene = load(path)
		for p in props[path]:
			var n: Node3D = ps.instantiate()
			n.position = p
			root.add_child(n)


## Camera that frames the 3x3 line-up for both portrait and landscape windows.
class _FitCamera extends Camera3D:
	func _ready() -> void:
		fov = 42.0
		get_viewport().size_changed.connect(_fit)
		_fit()

	func _fit() -> void:
		var s := get_viewport().get_visible_rect().size
		var portrait := s.y > s.x
		keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
		var target := Vector3(0.0, 1.0, 0.4)
		var dist := 13.5 if portrait else 12.0
		var pitch := deg_to_rad(40.0 if portrait else 32.0)
		position = target + Vector3(0.0, sin(pitch), cos(pitch)) * dist
		look_at(target)
