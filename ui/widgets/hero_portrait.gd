class_name HeroPortrait
extends SubViewportContainer
## A class hero on a small lit pedestal (own 3D world in a SubViewport), turning slowly: the
## class-select preview, the run-setup hero card, the Wardrobe turntable and the reveal card.
##
##   var p := HeroPortrait.new()
##   p.custom_minimum_size = Vector2(220, 260)
##   p.set_hero("paladin", "ascendant", true)     # HeroLook look
##   p.silhouette = true                           # locked: a dark shape with a rim glow

## Radians per second of the turntable (0 = still, facing three-quarter).
var spin := 0.45
## Draw the hero as a dark silhouette (locked / secret classes).
var silhouette := false:
	set(v):
		silhouette = v
		_apply_silhouette()
## Framing: 1 = full body, larger = closer (head and shoulders).
var zoom := 1.0:
	set(v):
		zoom = v
		_frame()
## Pedestal ring colour.
var ring_color: Color = UiPalette.GOLD:
	set(v):
		ring_color = v
		if _ring_mat:
			_ring_mat.albedo_color = v
			_ring_mat.emission = v

var hero: Character
var class_id := ""
var skin := "default"
var prestige := false

var _viewport: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _ring_mat: StandardMaterial3D
var _ped: Node3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var world := Node3D.new()
	_viewport.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a86c0")
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe0b0")
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.shadow_enabled = true
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("7aa0ff")
	rim.light_energy = 1.2
	rim.rotation_degrees = Vector3(-20, 150, 0)
	world.add_child(rim)
	_ped = Node3D.new()
	world.add_child(_ped)
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.05
	cm.bottom_radius = 1.2
	cm.height = 0.3
	cm.radial_segments = 48
	ped.mesh = cm
	ped.position.y = -0.15
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("3a3450")
	pm.roughness = 0.6
	ped.material_override = pm
	_ped.add_child(ped)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.08
	tm.outer_radius = 1.16
	tm.rings = 64
	ring.mesh = tm
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = ring_color
	_ring_mat.emission_enabled = true
	_ring_mat.emission = ring_color
	_ring_mat.emission_energy_multiplier = 0.6
	ring.material_override = _ring_mat
	_ped.add_child(ring)
	_pivot = Node3D.new()
	_pivot.rotation.y = deg_to_rad(-25.0)
	world.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = 32
	world.add_child(_cam)
	_cam.current = true
	_frame()


## Shows `id`'s hero in a Wardrobe look (rebuilds only when something changed).
func set_hero(id: String, p_skin := "default", p_prestige := false, pop := true) -> void:
	if hero and id == class_id and p_skin == skin and p_prestige == prestige:
		return
	class_id = id
	skin = p_skin
	prestige = p_prestige
	if hero:
		hero.queue_free()
	hero = HeroLook.create(id, p_skin, p_prestige)
	_pivot.add_child(hero)
	hero.play("idle", 0.0)
	_apply_silhouette()
	if pop and is_inside_tree():
		hero.scale = Vector3.ONE * 0.6
		var t := hero.create_tween()
		t.tween_property(hero, "scale", Vector3.ONE * hero_scale(), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		hero.scale = Vector3.ONE * hero_scale()


## Cheer (or another alias) once, then idle.
func cheer(alias := "cheer") -> void:
	if hero and not silhouette and hero.has_method("play_once"):
		hero.play_once(alias)


func hero_scale() -> float:
	# the Chieftain (Rig_Large) is scaled by its overlay already
	return hero.scale.x if hero and hero.has_meta("prestige") and String(hero.get_meta("prestige")) == "chieftain" else 1.0


func _apply_silhouette() -> void:
	if hero == null:
		return
	if silhouette:
		hero.set_tint(Color(0.02, 0.015, 0.05), 1.0, Color(0.1, 0.06, 0.2))
	else:
		hero.set_tint(Color.WHITE, 0.0)


func _frame() -> void:
	if _cam == null:
		return
	var z := clampf(zoom, 1.0, 2.2)
	var look := Vector3(0, lerpf(1.0, 1.6, (z - 1.0) / 1.2), 0)
	var pos := Vector3(0, lerpf(1.45, 1.8, (z - 1.0) / 1.2), 6.3 / z)
	_cam.transform = Transform3D(Basis.looking_at(look - pos), pos)


func _process(delta: float) -> void:
	if _pivot and spin != 0.0 and is_visible_in_tree():
		_pivot.rotation.y += delta * spin
