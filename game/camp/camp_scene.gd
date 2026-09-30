class_name CampScene
extends Node3D
## The Camp (spec §16), the game's home screen: a camp on a floating island at dusk that
## BUILDS OUT with the profile. Everything is data-driven from CampState.of(profile), so the
## same profile always gives the same camp; the scene is the progress bar:
##   * a campfire that grows with the runs played, the clearing widening around it;
##   * four stations (Armory, Dice Workshop, Pet Den, Arcade), each ruined -> under
##     construction -> built -> upgraded (CampStations), tappable and labelled by the UI;
##   * the chosen hero by the fire, every other unlocked class busy around camp (sitting by
##     the fire, sparring, reading, cheering), and a tent per class (dark until unlocked);
##   * the equipped pet beside the hero and every other owned pet roaming;
##   * milestone decorations: boss trophies, mini-boss skulls, biome souvenirs, class-win
##     banners, a golden chest, lantern posts and string lights with runs, fences with Crowns
##     spent, ascension banners.
## reveal(before, after) plays the build-out moments after a run (camera pan, dust, the new
## part popping in, a banner); skip_reveal() jumps to the end.
##
##   var camp := CampScene.new(); add_child(camp)
##   camp.apply_profile(profile)
##   await camp.reveal(CampState.of(old_profile), CampState.of(profile), overlay, speed)
##   var id := camp.pick_station(tap_pos)

signal layout_changed
signal reveal_finished

const HERO_SCALE := 0.85
const NPC_SCALE := 0.8
const FOREST := "res://assets/kaykit/forest/color%d/%s_Color%d.gltf"
const RES := "res://assets/kaykit/resources/"

const LOOK := {
	"sky_top": Color(0.04, 0.05, 0.15), "sky_horizon": Color(0.36, 0.2, 0.36), "sky_bottom": Color(0.04, 0.03, 0.08),
	"sky_glow": Color(1.0, 0.5, 0.32), "glow_strength": 0.55, "stars": 1.0,
	"ambient": Color(0.38, 0.4, 0.72), "ambient_energy": 0.42,
	"moon": Color(0.6, 0.68, 1.0), "moon_energy": 0.55,
	"cloud_deep": Color(0.07, 0.06, 0.16), "cloud_light": Color(0.22, 0.18, 0.36), "cloud_rim": Color(0.8, 0.45, 0.4),
	"island_top": Color(0.2, 0.3, 0.2), "island_side": Color(0.28, 0.2, 0.18), "island_bottom": Color(0.08, 0.06, 0.1),
}
const ISLAND_HALF := 16.0

## Station positions per orientation (the fire sits in front, the hero on its left).
const LAYOUT := {
	"landscape": {
		"armory": Vector3(-7.2, 0, -0.3), "workshop": Vector3(-3.2, 0, -4.9),
		"pet_den": Vector3(3.2, 0, -4.9), "arcade": Vector3(7.2, 0, -0.3),
	},
	"portrait": {
		"armory": Vector3(-3.5, 0, -3.0), "workshop": Vector3(-3.0, 0, -8.4),
		"pet_den": Vector3(3.0, 0, -8.4), "arcade": Vector3(3.5, 0, -3.0),
	},
}
const FIRE_POS := Vector3(0, 0, 1.8)
const STATION_SCALE := 1.5
const STATION_YAW := {"armory": 38.0, "workshop": 14.0, "pet_den": -14.0, "arcade": -38.0}
## Clearing radii (x, z) per camp stage.
const CLEARING := [Vector2(3.6, 2.9), Vector2(4.6, 3.6), Vector2(5.3, 4.1), Vector2(5.9, 4.6)]
## Activity slots for the other unlocked classes (relative to the fire): [offset, yaw, clip, seat].
const SLOTS := [
	[Vector3(2.25, 0, 0.55), -118.0, "Sit_Chair_Idle", "log"],
	[Vector3(0.15, 0, -2.3), 0.0, "Sit_Chair_Idle", "log"],
	[Vector3(-4.6, 0, 3.3), 60.0, "spar", "dummy"],
	[Vector3(4.4, 0, 3.4), -40.0, "Cheering", ""],
	[Vector3(-1.6, 0, 4.4), 160.0, "Sit_Floor_Idle", "book"],
	[Vector3(1.9, 0, 4.2), -160.0, "Waving", ""],
	[Vector3(-5.6, 0, 1.0), 90.0, "idle_b", ""],
	[Vector3(5.6, 0, 1.2), -90.0, "idle_b", ""],
]
## Homes of the roaming pets (relative to the fire).
const PET_HOMES := [Vector3(1.4, 0, 2.9), Vector3(-3.4, 0, 0.2), Vector3(3.6, 0, -1.2), Vector3(-0.6, 0, -3.3),
	Vector3(2.8, 0, 3.6), Vector3(-2.6, 0, 3.8)]

var rig: CameraRig
var hero: Character
var hero_class := ""
var pet_id := ""
var stations: Dictionary = {}
var locked: Dictionary = {}
var portrait := false
## The CampState currently shown.
var state: Dictionary = {}
var revealing := false

var _pet_holder: Node3D
var _pet_model: Node3D
var _npcs: Node3D
var _pets: Node3D
var _deco: Node3D
var _fire: Node3D
var _fire_light: OmniLight3D
var _fire_level := -1
var _ground_mat: ShaderMaterial
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _built := false
var _stone_mat: StandardMaterial3D
var _paths: Node3D
var _skip := false
var _focus := PackedVector3Array()
var _life: CampLife


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
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = preload("res://game/camp/camp_ground.gdshader")
	_ground_mat.set_shader_parameter("clear_center", Vector2(FIRE_POS.x, FIRE_POS.z - 0.9))
	_ground_mat.set_shader_parameter("clear_radius", CLEARING[3])
	_ground_mat.set_shader_parameter("island_half", ISLAND_HALF - 0.15)
	top.material_override = _ground_mat
	top.position.y = 0.004
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(top)
	add_child(Biome._cloud_sea(LOOK))
	_ground()
	_backdrop()
	_fire = Node3D.new()
	_fire.name = "Fire"
	add_child(_fire)
	_camp_furniture()
	_pet_holder = Node3D.new()
	_pet_holder.name = "Pet"
	add_child(_pet_holder)
	for id in CampInfo.STATION_IDS:
		var s := Node3D.new()
		s.name = "Station_" + String(id)
		s.scale = Vector3.ONE * STATION_SCALE
		add_child(s)
		stations[id] = s
	_npcs = Node3D.new()
	_npcs.name = "Campers"
	add_child(_npcs)
	_pets = Node3D.new()
	_pets.name = "Pets"
	add_child(_pets)
	_deco = Node3D.new()
	_deco.name = "Decorations"
	add_child(_deco)
	_life = CampLife.new(self, FIRE_POS)
	add_child(_life)
	_bats()
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

## Shows the camp for a profile.
func apply_profile(p: Profile) -> void:
	apply_state(CampState.of(p))


## Rebuilds everything that depends on the profile from a CampState.
func apply_state(s: Dictionary) -> void:
	_build()
	state = s
	set_hero(String(s.hero))
	set_pet(String(s.pet))
	for id in CampInfo.STATION_IDS:
		_set_station(String(id), s.stations[id])
	_set_fire(int(s.fire))
	_set_clearing(int(s.stage))
	_build_decor(s)
	_build_paths()
	_build_campers(s)


func set_hero(class_id: String) -> void:
	var look := str((state.get("skins", {}) as Dictionary).get(class_id, []))
	if class_id == hero_class and hero != null and look == String(hero.get_meta("look", "")):
		return
	hero_class = class_id
	if hero:
		hero.queue_free()
	hero = _class_npc(class_id, "Sit_Chair_Idle")
	hero.set_meta("look", look)
	hero.name = "Hero"
	hero.scale = Vector3.ONE * HERO_SCALE
	add_child(hero)
	_place_hero()
	if state.has("classes"):
		_build_campers(state)


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
	_pet_model = CampProps.pet(id, int((state.get("pet_levels", {}) as Dictionary).get(id, 1)))
	_pet_holder.add_child(_pet_model)


## Legacy lock toggle (the state decides now); kept for callers that only know "locked".
func set_locked(id: String, on: bool) -> void:
	locked[id] = on


## World point the UI hangs a station's label on.
func station_anchor(id: String) -> Vector3:
	var s: Node3D = stations.get(id)
	var h := 2.7 if id != "arcade" else 2.9
	var st: Dictionary = (state.get("stations", {}) as Dictionary).get(id, {})
	if String(st.get("state", "built")) == "ruined":
		h = 1.7
	return s.global_position + Vector3.UP * h * STATION_SCALE if s else Vector3.ZERO


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


## A few bats crossing the sky now and then (dark flapping silhouettes on long loops).
func _bats() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.05, 0.04, 0.09)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 4:
		var bat := Node3D.new()
		bat.name = "Bat%d" % i
		add_child(bat)
		for side in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.45, 0.2)
			w.mesh = q
			w.material_override = m
			w.position = Vector3(side * 0.22, 0, 0)
			w.rotation.x = -PI * 0.5
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bat.add_child(w)
			var flap := w.create_tween().set_loops()
			flap.tween_property(w, "rotation:z", side * 0.9, 0.12 + 0.02 * i)
			flap.tween_property(w, "rotation:z", -side * 0.5, 0.12 + 0.02 * i)
		var y := 7.5 + 1.2 * i
		var z := -8.0 - 3.0 * i
		var a := Vector3(-24.0, y, z)
		var b := Vector3(24.0, y + 2.0, z + 5.0)
		bat.position = a
		bat.rotation.y = atan2(b.x - a.x, b.z - a.z)
		var fly := bat.create_tween().set_loops()
		fly.tween_interval(3.0 + 5.0 * i)
		fly.tween_property(bat, "position", b, 9.0 + i).set_trans(Tween.TRANS_SINE)
		fly.tween_callback(func() -> void: bat.position = a)


## Pauses camp life's decisions (a Camp screen is open over the scene).
func set_life_paused(on: bool) -> void:
	if _life:
		_life.paused = on


## Bounces a station (when its screen opens) and the hero turns to it and waves.
func bump(id: String) -> void:
	var s: Node3D = stations.get(id)
	if s == null:
		return
	if hero and not revealing:
		var to := s.global_position - hero.global_position
		var tw := hero.create_tween()
		tw.tween_property(hero, "rotation:y", atan2(to.x, to.z), 0.25)
		hero.play_once("Waving" if hero.has_anim("Waving") else "cheer", "Sit_Chair_Idle")
		tw.tween_interval(1.6)
		tw.tween_property(hero, "rotation:y", deg_to_rad(62.0), 0.4)
	var t := s.create_tween()
	t.tween_property(s, "scale", Vector3(1.08, 0.92, 1.08) * STATION_SCALE, 0.08)
	t.tween_property(s, "scale", Vector3.ONE * STATION_SCALE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Normalised screen rects the camp must fit into (the UI's free area).
func set_safe_rects(portrait_rect: Rect2, landscape_rect: Rect2) -> void:
	rig.safe_rect_portrait = portrait_rect
	rig.safe_rect_landscape = landscape_rect
	if not revealing:
		_frame(true)


func camera() -> Camera3D:
	return rig.camera


# ------------------------------------------------------------------ build-out reveal

## Plays the build-out moments between two CampStates (CampState.diff): for each change the
## camera pans to the spot, dust and sparkles burst, the new part pops in (a rebuilt station,
## a class walking in, a pet, a trophy) and `overlay` announces it. `speed` scales every beat
## (2x / 4x); skip_reveal() jumps to the final state. Returns when done.
func reveal(before: Dictionary, after: Dictionary, overlay: Node = null, speed := 1.0) -> void:
	var items := CampState.diff(before, after)
	if items.is_empty():
		apply_state(after)
		return
	revealing = true
	_skip = false
	apply_state(before)
	speed = maxf(speed, 0.25)
	await _wait(0.5 / speed)
	var cur := before.duplicate(true)
	for it in items:
		if _skip or not is_inside_tree():
			break
		var kind := String(it.kind)
		var id := String(it.id)
		var at := _reveal_spot(kind, id)
		_focus_on(at, {"stage": 5.0, "station": 2.7}.get(kind, 2.0))
		await _wait(0.7 / speed)
		if _skip:
			break
		CampProps.burst(self, at, Color(1.0, 0.85, 0.5), 1.4 if kind == "station" else 0.9)
		UiTheme.sfx("fanfare" if kind in ["station", "class"] else "buff")
		match kind:
			"station":
				cur.stations[id] = after.stations[id]
				_set_station(id, after.stations[id], true)
			"class":
				(cur.classes as Array).append(id)
				_build_campers(cur, id)
			"pet":
				(cur.pets as Array).append(id)
				_build_pets(cur, id)
			"boss":
				(cur.bosses as Array).append(id)
				_build_decor(cur, true)
			"stage":
				cur.stage = after.stage
				cur.fire = after.fire
				_set_fire(int(after.fire), true)
				_set_clearing(int(after.stage), true)
		if overlay and overlay.has_method("announce"):
			overlay.announce(String(it.text).to_upper(), "", UiPalette.GOLD_BRIGHT, 1.0 / speed)
		await _wait(1.5 / speed)
	apply_state(after)
	revealing = false
	_frame(false)
	reveal_finished.emit()


## Ends a running reveal at its final state.
func skip_reveal() -> void:
	_skip = true


func _reveal_spot(kind: String, id: String) -> Vector3:
	match kind:
		"station":
			return (stations[id] as Node3D).position
		"class":
			var others := _others(state)
			var k := maxi(0, others.find(id))
			return FIRE_POS + (SLOTS[k % SLOTS.size()][0] as Vector3)
		"pet":
			return FIRE_POS + (PET_HOMES[maxi(0, (state.pets as Array).find(id)) % PET_HOMES.size()] as Vector3)
		"boss":
			return FIRE_POS + Vector3(0, 0, -3.9)
	return FIRE_POS


func _focus_on(p: Vector3, r: float) -> void:
	var pts := PackedVector3Array()
	for x in [-r, r]:
		for z in [-r * 0.8, r * 0.8]:
			pts.append(p + Vector3(x, 0, z))
	pts.append(p + Vector3.UP * r * 1.4)
	rig.smooth_time = 0.5
	rig.frame_points(pts, 0.0, 38.0 if portrait else 32.0, false)


func _wait(t: float) -> void:
	if t <= 0.0 or not is_inside_tree():
		return
	var left := t
	while left > 0.0 and not _skip and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()


# ------------------------------------------------------------------ stations

func _set_station(id: String, st: Dictionary, animate := false) -> void:
	var s: Node3D = stations.get(id)
	if s == null:
		return
	var old := s.get_node_or_null("Body")
	if old:
		old.name = "Old"
		old.queue_free()
	var body := CampStations.build(id, st)
	s.add_child(body)
	if animate:
		body.scale = Vector3(0.2, 0.05, 0.2)
		var t := body.create_tween()
		t.tween_property(body, "scale", Vector3(1.1, 1.15, 1.1), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(body, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ campers (classes)

## Unlocked classes other than the hero, in content order.
func _others(s: Dictionary) -> Array:
	var out: Array = []
	for id in s.get("classes", []):
		if String(id) != String(s.get("hero", hero_class)):
			out.append(String(id))
	return out


## A class character in its equipped look (HeroLook: the equipped Armory items, Wardrobe skin, prestige).
func _class_npc(class_id: String, anim: String) -> Character:
	var look: Array = (state.get("skins", {}) as Dictionary).get(class_id, ["default", false])
	var ch := HeroLook.create(class_id, String(look[0]), bool(look[1]), look[2] if look.size() > 2 else {})
	ch.play("idle", 0.0)
	if ch.has_anim(anim):
		ch.play(anim, 0.0)
	return ch


func _build_campers(s: Dictionary, arriving := "") -> void:
	if _npcs == null:
		return
	UiTheme.clear(_npcs)
	_life.clear()
	_update_spots()
	var starts := ["sit", "sit", "dummy", "chat", "sit", "nap", "chat", "sit"]
	var others := _others(s)
	for k in others.size():
		var id := String(others[k])
		var ch := _class_npc(id, "idle")
		ch.name = "Camper_" + id
		ch.scale = Vector3.ONE * HERO_SCALE
		_npcs.add_child(ch)
		_life.add_agent(ch, String(starts[k % starts.size()]))
		if id == arriving:
			# walks in from the edge of the clearing to where camp life put them
			var pos := ch.global_position
			var from := pos + (pos - FIRE_POS).normalized() * 4.5
			ch.global_position = from
			ch.rotation.y = atan2(pos.x - from.x, pos.z - from.z)
			ch.play("walk")
			var t := ch.create_tween()
			t.tween_property(ch, "global_position", pos, 1.3)
			t.tween_callback(func() -> void: ch.play("idle"))
	_build_pets(s)


## Rebuilds camp life's spot graph for the current layout and station states.
func _update_spots() -> void:
	if _life == null or not is_inside_tree():
		return
	var built := {}
	for id in stations:
		var st: Dictionary = (state.get("stations", {}) as Dictionary).get(id, {})
		built[id] = String(st.get("state", "ruined")) == "built"
	_life.set_spots(stations, built)


## A training dummy: a post, a cross-bar and a sack head.
func _dummy(parent: Node3D, pos: Vector3) -> void:
	CampProps.post(parent, pos, 1.3, Color(0.45, 0.3, 0.2))
	CampProps.box(parent, Vector3(0.8, 0.1, 0.1), pos + Vector3(0, 1.0, 0), Color(0.45, 0.3, 0.2))
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	head.mesh = BiomeBlocks.faceted(sm, Color(0.8, 0.7, 0.5), 0.02, 3)
	head.position = pos + Vector3(0, 1.4, 0)
	parent.add_child(head)
	CampProps.opt(parent, Props.WPN + "shield_A.gltf", pos + Vector3(0, 0.8, 0.12), 0.0, 0.5)


# ------------------------------------------------------------------ pets

func _build_pets(s: Dictionary, arriving := "") -> void:
	if _pets == null:
		return
	UiTheme.clear(_pets)
	_life.pets.clear()
	var k := 0
	for id in s.get("pets", []):
		if String(id) == String(s.get("pet", "")):
			continue
		var home: Vector3 = FIRE_POS + (PET_HOMES[k % PET_HOMES.size()] as Vector3)
		var holder := Node3D.new()
		holder.name = "Roam_" + String(id)
		_pets.add_child(holder)
		holder.global_position = home
		var m := CampProps.pet(String(id), int((s.get("pet_levels", {}) as Dictionary).get(id, 1)))
		m.scale = Vector3.ONE * 0.85
		holder.add_child(m)
		_life.add_pet(holder, k)
		k += 1
		if String(id) == arriving:
			m.scale = Vector3.ONE * 0.05
			var pop := m.create_tween()
			pop.tween_property(m, "scale", Vector3.ONE * 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop.tween_property(m, "scale", Vector3.ONE * 0.85, 0.2)


# ------------------------------------------------------------------ decorations

## Trophies, souvenirs, banners, tents, lanterns and fences from the CampState.
func _build_decor(s: Dictionary, animate := false) -> void:
	if _deco == null:
		return
	UiTheme.clear(_deco)
	var H := Props.HAL
	var D := Props.DUN
	# boss trophies (skull posts) and mini-boss skulls along the back of the clearing
	var bosses: Array = s.get("bosses", [])
	var grid := [Vector3(-0.8, 0, -4.2), Vector3(0.0, 0, -4.35), Vector3(0.8, 0, -4.2), Vector3(-0.8, 0, -5.1), Vector3(0.0, 0, -5.25),
		Vector3(0.8, 0, -5.1), Vector3(-0.8, 0, -6.0), Vector3(0.0, 0, -6.15), Vector3(0.8, 0, -6.0)]
	for i in mini(bosses.size(), grid.size()):
		var t := Props.put(_deco, H + "post_skull.gltf", FIRE_POS + (grid[i] as Vector3), 90.0, 0.62)
		if animate and i == bosses.size() - 1:
			t.scale = Vector3.ONE * 0.05
			t.create_tween().tween_property(t, "scale", Vector3.ONE * 0.62, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var minis: Array = s.get("minibosses", [])
	for i in mini(minis.size(), grid.size() - bosses.size()):
		Props.put(_deco, H + "post_skull.gltf", FIRE_POS + (grid[bosses.size() + i] as Vector3), 70.0 + 15.0 * i, 0.42)
	# biome souvenirs on a little shelf by the fire
	var biomes: Array = s.get("biomes", [])
	if not biomes.is_empty():
		var shelf := FIRE_POS + Vector3(4.3, 0, 2.9)
		CampProps.box(_deco, Vector3(1.9, 0.1, 0.5), shelf + Vector3(0, 0.45, 0), Color(0.5, 0.34, 0.22), Vector3(0, 25, 0))
		for x in [-0.8, 0.8]:
			CampProps.box(_deco, Vector3(0.1, 0.45, 0.1), shelf + Vector3(x * 0.9, 0.22, x * 0.42), Color(0.4, 0.26, 0.16))
		for i in biomes.size():
			_souvenir(String(biomes[i]), shelf + Vector3(-0.72 + 0.29 * i, 0.5, 0.34 - 0.13 * i))
	# a golden chest after the first win
	if int(s.get("wins", 0)) > 0:
		Props.put(_deco, D + "chest_gold.gltf", FIRE_POS + Vector3(2.6, 0, 4.4), -35.0, 0.7)
	# a tent per class along the back: open and lit once the class is unlocked, closed before
	var all_classes: Array = (s.get("classes", []) as Array) + (s.get("locked_classes", []) as Array)
	var ordered: Array = []
	for id in HeroDefs.IDS:
		if all_classes.has(id):
			ordered.append(String(id))
	var n := ordered.size()
	var span := minf(14.0, 3.2 * float(n))
	for i in n:
		var id := String(ordered[i])
		var x := -span * 0.5 + span * (float(i) + 0.5) / float(n)
		var open: bool = (s.get("classes", []) as Array).has(id)
		var won: bool = (s.get("class_wins", []) as Array).has(id)
		_tent(_deco, Vector3(x, 0, -10.6 - 0.4 * float(i % 2)), 180.0 + (x * -2.0), _class_color(id), open, won)
	# lantern posts and string lights with the runs played
	var posts := [Vector3(-5.0, 0, -2.4), Vector3(5.0, 0, -2.4), Vector3(0.0, 0, -8.6), Vector3(-6.4, 0, 4.2)]
	var lit := int(s.get("lanterns", 0))
	for i in mini(lit, posts.size()):
		var p: Vector3 = posts[i]
		Props.put(_deco, H + "post_lantern.gltf", p, 90.0 if p.x <= 0 else -90.0, 0.95)
		Biome.flicker_light(_deco, p + Vector3(0, 2.7, 0), Color(1.0, 0.72, 0.42), 1.5, 5.0)
	if lit >= 3:
		_string_lights(_deco, posts[0] + Vector3(0, 3.0, 0), posts[2] + Vector3(0, 3.2, 0), 10, Color(1.0, 0.8, 0.45))
		_string_lights(_deco, posts[1] + Vector3(0, 3.0, 0), posts[2] + Vector3(0, 3.2, 0), 10, Color(1.0, 0.65, 0.4))
	# fences along the front edge with the Crowns spent
	var fences := int(s.get("fences", 0))
	for i in fences * 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var k := i / 2
		Props.put(_deco, H + "fence.gltf", Vector3(side * (8.2 + 2.0 * k), 0, 9.6 - 0.8 * k), side * 12.0, 0.8)
	# ascension banners on poles at the back left
	var asc := int(s.get("asc", 0))
	var colors := ["red", "blue", "green", "yellow", "white"]
	for i in mini(asc, 10):
		var at := Vector3(-9.5 + 0.9 * float(i % 5), 0, -7.8 - 0.9 * float(i / 5))
		CampProps.post(_deco, at, 2.6, Color(0.4, 0.28, 0.18), 0.1)
		Props.put(_deco, D + "banner_thin_%s.gltf" % colors[i % colors.size()], at + Vector3(0, 1.0, 0.1), 0.0, 0.4)
	# early camps are overgrown: bushes and rocks crowd the clearing until the camp grows
	var stage := int(s.get("stage", 0))
	var growth := [[Vector3(-4.6, 0, 3.6), "Bush_1_D"], [Vector3(4.9, 0, 4.0), "Bush_2_D"], [Vector3(-2.2, 0, -3.4), "Bush_4_C"],
		[Vector3(2.4, 0, -3.1), "Rock_3_B"], [Vector3(-5.2, 0, -1.2), "Rock_1_C"], [Vector3(5.4, 0, -0.8), "Bush_1_C"],
		[Vector3(-0.4, 0, 5.4), "Bush_2_C"]]
	for i in growth.size():
		if i < (3 - stage) * 3:
			var g: Array = growth[i]
			CampProps.forest(_deco, String(g[1]), [1, 2, 4][i % 3], FIRE_POS + (g[0] as Vector3), 40.0 * i, 0.95)


func _souvenir(biome: String, at: Vector3) -> void:
	var H := Props.HAL
	match biome:
		"glade":
			CampProps.forest(_deco, "Bush_1_B", 1, at, 0.0, 0.35)
		"crypt":
			Props.put(_deco, H + "gravestone.gltf", at, 0.0, 0.18)
		"hollow":
			Props.put(_deco, H + "pumpkin_orange_small.gltf", at, 0.0, 0.3)
		"frost":
			BiomeBlocks.crystal_cluster(_deco, at, 0.12, 3, 5)
		"throne":
			Props.put(_deco, H + "skull_candle.gltf", at, 0.0, 0.3)
		"magma":
			var r := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.1
			sm.height = 0.16
			r.mesh = sm
			r.material_override = Props.glow_material(Color(1.0, 0.4, 0.1), false, 2.0)
			r.position = at + Vector3.UP * 0.06
			_deco.add_child(r)


static func _class_color(id: String) -> Color:
	var cols := {"knight": Color(0.48, 0.6, 0.86), "barbarian": Color(0.86, 0.46, 0.36), "mage": Color(0.62, 0.48, 0.86),
		"rogue": Color(0.45, 0.72, 0.5)}
	if cols.has(id):
		return cols[id]
	return Color.from_hsv(float(hash(id) % 360) / 360.0, 0.45, 0.8)


# ------------------------------------------------------------------ fire & clearing

func _set_fire(level: int, animate := false) -> void:
	if level == _fire_level:
		return
	_fire_level = level
	UiTheme.clear(_fire)
	var k := 1.5 + 0.3 * level
	var fire := TileStyle.make_prop("campfire")
	fire.name = "Campfire"
	fire.position = FIRE_POS
	fire.scale = Vector3.ONE * k
	_fire.add_child(fire)
	for l in fire.find_children("*", "OmniLight3D", true, false):
		(l as OmniLight3D).visible = false
	_fire_light = OmniLight3D.new()
	_fire_light.name = "FireLight"
	_fire_light.light_color = Color(1.0, 0.56, 0.24)
	_fire_light.light_energy = 3.2
	_fire_light.omni_range = 8.0 + 1.4 * level
	_fire_light.omni_attenuation = 1.3
	_fire_light.shadow_enabled = true
	_fire_light.position = FIRE_POS + Vector3(0, 1.3, 0)
	_fire.add_child(_fire_light)
	Biome.flame(_fire, FIRE_POS + Vector3(0, 0.25 * k, 0), Color(1.0, 0.45, 0.12), 0.4 * k, 12 + 3 * level)
	var e := GPUParticles3D.new()
	e.name = "Embers"
	e.amount = 14 + 6 * level
	e.lifetime = 3.2
	e.preprocess = 3.0
	e.position = FIRE_POS + Vector3(0, 0.3 * k, 0)
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
	pm.emission_sphere_radius = 0.15 * k
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
	_fire.add_child(e)
	BiomeBlocks.smoke(_fire, FIRE_POS + Vector3(0, 0.6 * k, 0), 0.35 * k, Color(0.16, 0.14, 0.2, 0.35))
	if animate:
		fire.scale = Vector3.ONE * (k - 0.3)
		fire.create_tween().tween_property(fire, "scale", Vector3.ONE * k, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_clearing(stage: int, animate := false) -> void:
	var r: Vector2 = CLEARING[clampi(stage, 0, CLEARING.size() - 1)]
	if animate:
		var from: Vector2 = _ground_mat.get_shader_parameter("clear_radius")
		var t := create_tween()
		t.tween_method(func(v: Vector2) -> void: _ground_mat.set_shader_parameter("clear_radius", v), from, r, 0.8)
	else:
		_ground_mat.set_shader_parameter("clear_radius", r)


## Logs, a woodpile and the kettle corner around the fire (the hero's log is always there).
## (Everything stays off camp life's ring path, r = CampLife.RING around the fire.)
func _camp_furniture() -> void:
	Props.put(self, RES + "Wood_Log_B.gltf", _hero_spot() + Vector3(0.05, 0, 0), 62.0, 0.95)
	# the seats camp life uses: right, back and back-right of the fire
	for seat in [[Vector3(2.25, 0, 0.55), -28.0], [Vector3(0.15, 0, -2.3), 90.0], [Vector3(1.75, 0, -1.65), 45.0]]:
		Props.put(self, RES + "Wood_Log_B.gltf", FIRE_POS + (seat[0] as Vector3) + Vector3(0, 0, 0), float(seat[1]), 0.95)
	# the woodpile and chopping block sit in the front-left supplies corner, clear of the Armory
	# (in landscape its anvil stands at about fire + (-5.3, 0, -2.0); a pile there hid it)
	Props.put(self, RES + "Wood_Log_Stack.gltf", FIRE_POS + Vector3(-3.6, 0, 2.5), -20.0, 0.8)
	Props.put(self, Props.DUN + "barrel_small.gltf", FIRE_POS + Vector3(-4.4, 0, 0.3), 20.0, 0.9)
	Props.put(self, Props.TOOLS + "bucket_metal.gltf", FIRE_POS + Vector3(-4.2, 0, 1.3), 0.0, 1.1)
	CampProps.opt(self, CampProps.MM + "werewolf/log_split.gltf", FIRE_POS + Vector3(-5.0, 0, 1.9), 30.0, 0.9)
	CampProps.opt(self, CampProps.MM + "werewolf/axe.gltf", FIRE_POS + Vector3(-5.0, 0.35, 1.9), 30.0, 0.9)
	_dummy(self, FIRE_POS + Vector3(-6.9, 0, 4.2))


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
				yaw = 32.0 if id == "armory" else -32.0
			s.rotation.y = deg_to_rad(yaw)
		if not state.is_empty():
			_build_decor(state)
			_build_campers(state)
		_build_paths()
		layout_changed.emit()
	if not revealing:
		_frame(true)


## Stepping stones from the clearing to each station that stands (not ruined).
func _build_paths() -> void:
	if _paths == null:
		return
	UiTheme.clear(_paths)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 if portrait else 98
	var from := FIRE_POS + Vector3(0, 0, -0.9)
	var r0: Vector2 = CLEARING[clampi(int(state.get("stage", 3)), 0, 3)]
	for id in stations:
		var st: Dictionary = (state.get("stations", {}) as Dictionary).get(id, {})
		if String(st.get("state", "built")) == "ruined":
			continue
		var to: Vector3 = (stations[id] as Node3D).position
		var dir := (to - from).normalized()
		var dist := from.distance_to(to)
		var k := 0
		var t := r0.y * 0.75
		while t < dist - 1.9:
			var p := from + dir * t
			var st_m := MeshInstance3D.new()
			var sc := CylinderMesh.new()
			sc.top_radius = 0.32
			sc.bottom_radius = 0.38
			sc.height = 0.1
			sc.radial_segments = 7
			sc.rings = 1
			st_m.mesh = sc
			st_m.material_override = _stone_mat
			var side := Vector3(-dir.z, 0, dir.x) * (0.22 if k % 2 == 0 else -0.22)
			st_m.position = p + side + Vector3(0, 0.03, 0)
			st_m.rotation.y = rng.randf() * TAU
			st_m.scale = Vector3(1.0 + 0.25 * float(k % 3), 1.0, 0.85)
			_paths.add_child(st_m)
			t += 0.95
			k += 1


func _frame(instant := false) -> void:
	if rig == null:
		return
	var pts := PackedVector3Array()
	# a tall free area (phone portrait) is width-bound: framing the side stations' full depth
	# left a dead band under the fire and kept the Armory rack tiny, so tall views frame the
	# side stations tighter (their outer edge may crop) and come closer
	var vs := get_viewport().get_visible_rect().size
	var fr := rig.safe_rect_portrait
	var tall := portrait and fr.size.x * vs.x < fr.size.y * vs.y * 0.8
	for id in stations:
		var base: Vector3 = LAYOUT["portrait" if portrait else "landscape"][id]
		var side := (1.5 if tall else 2.7) if id in ["armory", "arcade"] else 0.0
		pts.append(base + Vector3(-side if base.x < 0 else side, 0, 1.4))
		pts.append(base + Vector3.UP * 3.6)
	pts.append(FIRE_POS + Vector3(0, 0, 2.2))
	pts.append(_hero_spot() + Vector3(-0.4, 0, 1.4))
	rig.smooth_time = 0.55
	rig.frame_points(pts, 0.0, 48.0 if portrait else 36.0, instant)


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
	if _pet_model and not (_pet_model is PetView):
		_pet_model.position.y = 0.35 + sin(_t * 2.4) * 0.12
		_pet_model.rotation.y = sin(_t * 0.9) * 0.5 + 0.5
	if _fire_light and is_instance_valid(_fire_light):
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
	# a woodpile and a cart of supplies
	Props.put(d, RES + "Wood_Log_Stack.gltf", Vector3(-10.2, 0, -5.8), 70.0, 1.1)
	Props.put(d, RES + "Wood_Log_A.gltf", Vector3(-9.1, 0, -4.6), 10.0, 1.0)
	Props.put(d, RES + "Textiles_Stack_Large_Colored.gltf", Vector3(10.4, 0, -5.4), -30.0, 1.0)
	Props.put(d, Props.DUN + "crates_stacked.gltf", Vector3(11.2, 0, -3.4), -60.0, 0.8)
	# flowers near the front edge
	BiomeBlocks._rng.seed = 77
	BiomeBlocks.flower_patch(d, Vector3(-8.5, 0, 9.4), 1.8, 22)
	BiomeBlocks.flower_patch(d, Vector3(8.8, 0, 9.0), 1.6, 18)
	BiomeBlocks.flower_patch(d, Vector3(-11.8, 0, -1.6), 1.2, 10)

## A class tent: open with a warm glow (and a banner once the class has won), or closed and dark
## while the class is locked.
func _tent(parent: Node3D, pos: Vector3, yaw: float, color: Color, open := true, won := false) -> void:
	if not open:
		color = color.darkened(0.55).lerp(Color(0.3, 0.3, 0.36), 0.5)
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
	l.visible = open
	n.add_child(l)
	if not open:
		# a closed flap over the opening
		var flap := MeshInstance3D.new()
		var fst := SurfaceTool.new()
		fst.begin(Mesh.PRIMITIVE_TRIANGLES)
		fst.set_color(color.darkened(0.15))
		for v in [Vector3(-w * 0.72, 0, depth * 0.5), Vector3(w * 0.72, 0, depth * 0.5), Vector3(0, h * 0.74, depth * 0.5)]:
			fst.set_normal(Vector3.BACK)
			fst.add_vertex(v)
		var fm := fst.commit()
		var fmat := StandardMaterial3D.new()
		fmat.vertex_color_use_as_albedo = true
		fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		fm.surface_set_material(0, fmat)
		flap.mesh = fm
		n.add_child(flap)
	if won:
		CampProps.post(n, Vector3(w + 0.3, 0, depth * 0.3), 2.3, Color(0.42, 0.3, 0.2), 0.08)
		Props.put(n, Props.DUN + "banner_thin_yellow.gltf", Vector3(w + 0.3, 0.9, depth * 0.3 + 0.08), 0.0, 0.38)
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



