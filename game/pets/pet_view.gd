class_name PetView
extends Node3D
## A 3D pet familiar built from KayKit props plus a few procedural bits (eyes, glows, teeth).
## Shared by the run (PetHost follows the hero with it) and the Camp's Pet Den:
##
##   var pet := PetView.create("coin_mimic", 7)
##   add_child(pet)                      # floats and bobs on its own, facing the camera
##   pet.set_charge(2, 3)                # charge pips orbiting it (size = PetDefs.size)
##   await pet.act("bite", enemy_pos)    # per-effect action (heal/bite/poison/reroll/block/gold/potion)
##
## The six newer pets (pebble_golem, frost_mote, wick, tinker_gear, grimoire, cauldron) are
## built and animated by PetViewExt; their acts take `opts` (targets, die_idx, face, color).
##
## Node layout:  PetView (ground anchor; `home` is where it drifts to when `follow` is on)
##                 Shadow (blob on the ground)
##                 Float (hover height + bob)  > Body (yaw toward the camera, squash, spins)
##                                                 Model (per-pet props)
##                                             > Pips (charge meter ring)  > Light

## Hover height of the body above the anchor (world units, before the level scale).
const HOVER := 0.95
const GEM_LARGE := "res://assets/kaykit/resource/Gem_Large.gltf"
const SKELETON := "res://assets/kaykit/skeletons/Skeleton_Minion.glb"
const GEM_SMALL := "res://assets/kaykit/resource/Gem_Small.gltf"
const PIP_RADIUS := 0.36
## Per pet: accent (pips, glow, light), light energy.
const LOOKS := {
	"pumpkin_sprite": [Color(1.0, 0.62, 0.2), 1.6],
	"skull_buddy": [Color(0.72, 1.0, 0.42), 1.1],
	"lantern_ghost": [Color(0.45, 1.0, 0.88), 1.8],
	"crystal_wisp": [Color(0.55, 0.85, 1.0), 1.7],
	"guard_die": [Color(0.5, 0.75, 1.0), 1.0],
	"coin_mimic": [Color(1.0, 0.82, 0.3), 1.0],
	"pebble_golem": [Color(1.0, 0.72, 0.5), 1.0],
	"frost_mote": [Color(0.72, 0.92, 1.0), 1.5],
	"wick": [Color(1.0, 0.55, 0.22), 1.8],
	"tinker_gear": [Color(0.45, 1.0, 0.8), 1.0],
	"grimoire": [Color(0.75, 0.52, 1.0), 1.4],
	"cauldron": [Color(1.0, 0.5, 0.78), 1.3],
}
## Every pet with a model, in gallery order (the rules' PetDefs.IDS may not list them all yet).
const ALL_IDS := ["pumpkin_sprite", "skull_buddy", "lantern_ghost", "crystal_wisp", "guard_die", "coin_mimic",
	"pebble_golem", "frost_mote", "wick", "tinker_gear", "grimoire", "cauldron"]

## Tinker's "fix" act reached the tray: the die to spin to `face` (-1 when unknown).
signal fixed_die(die_idx: int, face: int)

var pet_id := ""
var level := 1
var accent := Color.WHITE
## Charge meter.
var charge := 0
var size_pips := 0
## When true, the pet drifts toward `home` (global) every frame.
var follow := false
var home := Vector3.ZERO
## Follow stiffness (higher = snappier).
var stiffness := 5.0
## Presentation speed multiplier (game speed).
var speed := 1.0
## Face the active camera (yaw only) while idle.
var face_camera := true

var float_root := Node3D.new()
var body := Node3D.new()
var model := Node3D.new()
var pips_root := Node3D.new()
var light := OmniLight3D.new()
var shadow := MeshInstance3D.new()

var _pips: Array[MeshInstance3D] = []
var _pip_on: StandardMaterial3D
var _pip_off: StandardMaterial3D
var _full_ring: MeshInstance3D
var _t := 0.0
var _acting := false
var _lid: Node3D          # coin mimic lid (chomps)
var _flame: Node3D        # lantern ghost flame (flickers)
var _glint: MeshInstance3D  # guard die shield glint
var _jaw: Node3D          # skull buddy jaw (chatters, bites)
var _orbiters: Node3D     # crystal wisp: small gems circling it
var _eyes: Array[Node3D] = []
var _blink := 2.0
var _scale := 1.0
var _look_at := Vector3.INF
## Moving parts of the PetViewExt pets.
var parts := {}


static func create(id: String, lvl := 1) -> PetView:
	var p := PetView.new()
	p.setup(id, lvl)
	return p


## Display name (PetDefs, else the model's own name for pets the rules don't know yet).
static func display_name(id: String) -> String:
	return PetDefs.name_of(id) if PetDefs.has(id) else String(PetViewExt.NAMES.get(id, id.capitalize()))


## Charge meter size (PetDefs, else a placeholder).
static func pips_for(id: String) -> int:
	return PetDefs.size(id) if PetDefs.has(id) else int(PetViewExt.SIZES.get(id, 4))


func _init() -> void:
	name = "Pet"
	add_child(shadow)
	add_child(float_root)
	float_root.add_child(body)
	body.add_child(model)
	float_root.add_child(pips_root)
	float_root.add_child(light)
	shadow.mesh = Props.quad(0.8)
	shadow.rotation.x = -PI * 0.5
	shadow.position.y = 0.03
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = Props.particle_texture("dot")
	sm.albedo_color = Color(0.05, 0.02, 0.1, 0.45)
	sm.disable_receive_shadows = true
	shadow.material_override = sm
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.omni_range = 1.6
	light.shadow_enabled = false
	_blink = randf_range(1.5, 3.5)
	_t = randf() * 10.0


func setup(id: String, lvl: int) -> void:
	pet_id = id
	level = clampi(lvl, 1, PetDefs.MAX_LEVEL)
	var look: Array = LOOKS.get(id, [Color.WHITE, 1.0])
	accent = look[0]
	light.light_color = accent
	light.light_energy = float(look[1]) * (1.0 + 0.04 * (level - 1))
	UiTheme.clear(model)
	_eyes.clear()
	parts.clear()
	match id:
		"pumpkin_sprite": _build_pumpkin()
		"skull_buddy": _build_skull()
		"lantern_ghost": _build_lantern()
		"crystal_wisp": _build_crystal()
		"guard_die": _build_die()
		"coin_mimic": _build_mimic()
		_:
			if PetViewExt.has(id):
				PetViewExt.build(self)
			else:
				_build_crystal()
	# levels: a little bigger, and a golden aura at L10 (L5+ a faint sparkle)
	_scale = 0.82 + 0.02 * (level - 1)
	body.scale = Vector3.ONE * _scale
	if level >= PetDefs.MAX_LEVEL:
		_build_aura()
	elif level >= 5:
		var sp := Fx.elite_sparkle(float_root, Vector3(0, -0.25, 0), 0.3, 0.5)
		sp.amount = 5
		(sp.process_material as ParticleProcessMaterial).color = accent.lightened(0.3)
	_build_pips(pips_for(id))
	set_charge(0, size_pips)
	Props.set_shadows(model, false)


func _ready() -> void:
	float_root.position.y = HOVER


# ======================================================================= builders

func _prop(path: String, s: float, pos := Vector3.ZERO) -> Node3D:
	var n := Props.inst(path, s, false)
	n.position = pos
	model.add_child(n)
	return n


## A cute eye: dark bead with a white glint, facing +Z.
func _eye(parent: Node3D, pos: Vector3, r := 0.05) -> Node3D:
	var e := Node3D.new()
	e.position = pos
	parent.add_child(e)
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 8
	b.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.05, 0.12)
	m.roughness = 0.2
	m.metallic_specular = 0.9
	b.material_override = m
	b.scale = Vector3(1.0, 1.15, 0.55)
	e.add_child(b)
	var g := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = r * 0.36
	gm.height = r * 0.72
	g.mesh = gm
	g.material_override = Props.glow_material(Color.WHITE, false, 1.0)
	g.position = Vector3(-r * 0.3, r * 0.38, r * 0.45)
	e.add_child(g)
	_eyes.append(e)
	return e


func _blush(parent: Node3D, pos: Vector3, w := 0.07) -> void:
	for s in [-1.0, 1.0]:
		var q := MeshInstance3D.new()
		q.mesh = Props.quad(w)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = Props.particle_texture("dot")
		m.albedo_color = Color(1.0, 0.45, 0.6, 0.75)
		q.material_override = m
		q.scale = Vector3(1.0, 0.6, 1.0)
		q.position = Vector3(s * absf(pos.x), pos.y, pos.z)
		parent.add_child(q)


func _glow_sphere(parent: Node3D, pos: Vector3, r: float, color: Color, energy := 1.5, additive := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = Props.glow_material(color, additive, energy)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _halo(parent: Node3D, pos: Vector3, size: float, color: Color, alpha := 0.55) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.quad(size)
	var m := Props.glow_material(Color(color, alpha), true, 1.0)
	m.albedo_texture = Props.particle_texture("dot")
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Pumpkin Sprite: a small floating pumpkin with a cute face, a warm glow and leaf wings.
func _build_pumpkin() -> void:
	model.scale = Vector3.ONE * 1.18
	_prop(Props.HAL + "pumpkin_orange.gltf", 0.32, Vector3(0, -0.2, 0))
	_halo(model, Vector3(0, 0.0, -0.1), 0.85, Color(1.0, 0.55, 0.15), 0.22)
	_eye(model, Vector3(-0.085, 0.0, 0.215), 0.042)
	_eye(model, Vector3(0.085, 0.0, 0.215), 0.042)
	_blush(model, Vector3(0.15, -0.055, 0.2), 0.08)
	# a little glowing smile
	var smile := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.028
	tm.outer_radius = 0.04
	smile.mesh = tm
	smile.material_override = Props.glow_material(Color(1.0, 0.85, 0.3), false, 1.4)
	smile.position = Vector3(0, -0.06, 0.222)
	smile.rotation.x = PI * 0.5
	smile.scale = Vector3(1.0, 0.4, 0.5)
	model.add_child(smile)
	# two little leaf wings
	for s in [-1.0, 1.0]:
		var w := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.1
		sm.height = 0.2
		w.mesh = sm
		w.material_override = Props.flat_material(Color(0.42, 0.8, 0.32), 0.6)
		w.scale = Vector3(1.2, 0.3, 0.75)
		w.position = Vector3(s * 0.21, -0.02, -0.06)
		w.rotation = Vector3(0.0, -s * 0.5, s * 0.45)
		w.name = "Wing"
		model.add_child(w)


## Skull Buddy: a floating skull with glowing green eyes and a wisp trail.
func _build_skull() -> void:
	# the Skeletons pack's minion head + jaw + eyes (bind pose) when imported, else the
	# Halloween skull prop
	if ResourceLoader.exists(SKELETON):
		var src: Node3D = load(SKELETON).instantiate()
		var head := Node3D.new()
		head.scale = Vector3.ONE * 0.42
		head.position = Vector3(0, -0.66, 0.0)
		model.add_child(head)
		for part in ["Head", "Eyes", "Jaw"]:
			var mi := src.find_child("Skeleton_Minion_" + part, true, false) as MeshInstance3D
			if mi == null:
				continue
			var m := MeshInstance3D.new()
			m.mesh = mi.mesh
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if part == "Jaw":
				# pivot at the jaw hinge so bites can open it
				_jaw = Node3D.new()
				_jaw.position = Vector3(0, 1.45, -0.05)
				head.add_child(_jaw)
				m.position = -_jaw.position
				_jaw.add_child(m)
			else:
				head.add_child(m)
			if part == "Eyes":
				m.material_override = Props.glow_material(Color(0.55, 1.0, 0.3), false, 1.4)
		src.free()
	else:
		_prop(Props.HAL + "skull.gltf", 0.46, Vector3(0, -0.2, 0))
		for s in [-1.0, 1.0]:
			_glow_sphere(model, Vector3(s * 0.085, 0.02, 0.17), 0.04, Color(0.55, 1.0, 0.3), 1.2, false)
	_halo(model, Vector3(0, 0.0, -0.05), 0.8, Color(0.6, 1.0, 0.4), 0.2)
	_wisps(model, Vector3(0, -0.14, -0.1), Color(0.6, 1.0, 0.45, 0.7), 10)


## Lantern Ghost: a little lantern with a ghostly cyan flame spirit peeking out of its top.
func _build_lantern() -> void:
	_prop(Props.HAL + "lantern_standing.gltf", 0.42, Vector3(0, -0.34, 0))
	_flame = Node3D.new()
	_flame.position = Vector3(0, 0.12, 0.0)
	model.add_child(_flame)
	var f := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	f.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 1.0, 0.9, 0.82)
	fm.emission_enabled = true
	fm.emission = Color(0.3, 0.95, 0.8)
	fm.emission_energy_multiplier = 1.3
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.roughness = 0.3
	f.material_override = fm
	f.scale = Vector3(1.0, 1.0, 0.85)
	_flame.add_child(f)
	var tip := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.12
	cm.height = 0.22
	tip.mesh = cm
	tip.material_override = fm
	tip.position = Vector3(0, 0.17, -0.01)
	tip.rotation.z = 0.25
	_flame.add_child(tip)
	_glow_sphere(model, Vector3(0, -0.14, 0), 0.1, Color(0.4, 1.0, 0.85), 2.0)
	_halo(_flame, Vector3(0, 0.02, -0.05), 0.75, Color(0.4, 1.0, 0.85), 0.35)
	_eye(_flame, Vector3(-0.055, 0.02, 0.12), 0.034)
	_eye(_flame, Vector3(0.055, 0.02, 0.12), 0.034)


## Crystal Wisp: a glowing crystal cluster with a face.
func _build_crystal() -> void:
	# KayKit ResourceBits EXTRA gems when imported (tools/import_assets.sh), else the
	# platformer diamond
	if ResourceLoader.exists(GEM_LARGE):
		var big := _prop(GEM_LARGE, 0.5, Vector3(0, 0.0, 0))
		Props.tint(big, Color(0.6, 0.92, 1.0), 0.15, Color(0.08, 0.22, 0.4))
		_orbiters = Node3D.new()
		model.add_child(_orbiters)
		for k in 2:
			var sm := Props.inst(GEM_SMALL, 0.36, false)
			var a := PI * k
			sm.position = Vector3(cos(a) * 0.27, -0.04, sin(a) * 0.27)
			Props.tint(sm, Color(0.75, 0.55, 1.0), 0.5, Color(0.25, 0.12, 0.5))
			_orbiters.add_child(sm)
		_eye(model, Vector3(-0.06, 0.02, 0.085), 0.038)
		_eye(model, Vector3(0.06, 0.02, 0.085), 0.038)
		_blush(model, Vector3(0.1, -0.045, 0.08), 0.07)
	else:
		var big := _prop(Props.PLAT + "blue/diamond_blue.gltf", 0.46, Vector3(0, 0.02, 0))
		big.scale = Vector3(0.36, 0.62, 0.36)
		for s in [-1.0, 1.0]:
			var sm := _prop(Props.PLAT + "blue/diamond_blue.gltf", 0.2, Vector3(s * 0.15, -0.12, -0.08))
			sm.scale = Vector3(0.14, 0.3, 0.14)
			sm.rotation.z = -s * 0.32
			Props.tint(sm, Color(0.7, 0.55, 1.0), 0.55, Color(0.25, 0.15, 0.5))
		Props.tint(big, Color(0.55, 0.9, 1.0), 0.1, Color(0.05, 0.2, 0.35))
		_eye(model, Vector3(-0.065, 0.03, 0.2), 0.036)
		_eye(model, Vector3(0.065, 0.03, 0.2), 0.036)
		_blush(model, Vector3(0.11, -0.03, 0.2), 0.07)
	_halo(model, Vector3(0, 0.0, -0.1), 0.8, Color(0.5, 0.85, 1.0), 0.2)
	var sp := Fx.elite_sparkle(model, Vector3(0, -0.2, 0), 0.26, 0.5)
	sp.amount = 6
	(sp.process_material as ParticleProcessMaterial).color = Color(0.7, 0.95, 1.0)


## Guard Die: a small living die (the tray's die mesh and shader, guard-rune blue) with a
## blank face for its eyes and a shield glint.
func _build_die() -> void:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * 0.36
	model.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = DieMesh.get_mesh()
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/dice/die.gdshader")
	var look: Array = DieVisual.RUNE_LOOKS["guard"]
	m.set_shader_parameter("body_color", look[0])
	m.set_shader_parameter("edge_color", look[1])
	m.set_shader_parameter("pip_color", look[2])
	m.set_shader_parameter("rim_color", look[3])
	m.set_shader_parameter("rim_strength", 0.7)
	m.set_shader_parameter("metallic", look[4])
	m.set_shader_parameter("roughness", look[5])
	m.set_shader_parameter("clearcoat", look[6])
	m.set_shader_parameter("bevel", DieMesh.BEVEL)
	# slot 2 faces +Z (toward the camera): blank, it's the face
	var fv := PackedFloat32Array([6.0, 3.0, 0.0, 5.0, 4.0, 1.0])
	m.set_shader_parameter("face_vals", fv)
	m.set_shader_parameter("face_edit", PackedFloat32Array([0, 0, 0, 0, 0, 0]))
	mi.material_override = m
	holder.add_child(mi)
	holder.rotation = Vector3(deg_to_rad(-10.0), 0.0, deg_to_rad(4.0))
	_eye(holder, Vector3(-0.17, 0.08, 0.52), 0.1)
	_eye(holder, Vector3(0.17, 0.08, 0.52), 0.1)
	_blush(holder, Vector3(0.29, -0.1, 0.51), 0.17)
	# smile
	var smile := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.07
	tm.outer_radius = 0.1
	smile.mesh = tm
	smile.material_override = Props.flat_material(Color(0.08, 0.05, 0.12), 0.4)
	smile.position = Vector3(0, -0.12, 0.505)
	smile.rotation.x = PI * 0.5
	smile.scale = Vector3(1.0, 0.3, 0.6)
	holder.add_child(smile)
	_glint = MeshInstance3D.new()
	_glint.mesh = Props.quad(0.34)
	var gm := Props.glow_material(Color(0.8, 0.92, 1.0), true, 2.0)
	gm.albedo_texture = Props.particle_texture("spark")
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glint.material_override = gm
	_glint.position = Vector3(0.16, 0.16, 0.12)
	_glint.scale = Vector3.ONE * 0.01
	model.add_child(_glint)


## Coin Mimic: a small chest with teeth, eyes and a tongue; the lid chomps.
func _build_mimic() -> void:
	var c := _prop(Props.DUN + "chest.gltf", 0.26, Vector3(0, -0.2, -0.02))
	_lid = c.find_child("chest_lid", true, false) as Node3D
	var tooth_m := Props.flat_material(Color(1.0, 0.98, 0.92), 0.4)
	# lid-local coordinates (x2 for the 0.26 scale -> the teeth read at the lid's front rim)
	if _lid:
		for k in 6:
			var t := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.07
			cm.bottom_radius = 0.0
			cm.height = 0.2
			cm.radial_segments = 6
			t.mesh = cm
			t.material_override = tooth_m
			t.position = Vector3(-0.62 + k * 0.248, -0.2, 1.18)
			_lid.add_child(t)
		_eye(_lid, Vector3(-0.33, 0.33, 1.2), 0.17)
		_eye(_lid, Vector3(0.33, 0.33, 1.2), 0.17)
		for s in [-1.0, 1.0]:
			var brow := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(0.3, 0.06, 0.06)
			brow.mesh = bx
			brow.material_override = Props.flat_material(Color(0.12, 0.07, 0.1), 0.5)
			brow.position = Vector3(s * 0.33, 0.58, 1.2)
			brow.rotation.z = -s * 0.35
			_lid.add_child(brow)
	for k in 5:
		var t := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.018
		cm.height = 0.05
		cm.radial_segments = 6
		t.mesh = cm
		t.material_override = tooth_m
		t.position = Vector3(-0.13 + k * 0.065, -0.05, 0.155)
		model.add_child(t)
	var tongue := MeshInstance3D.new()
	var tsm := SphereMesh.new()
	tsm.radius = 0.07
	tsm.height = 0.14
	tongue.mesh = tsm
	tongue.material_override = Props.flat_material(Color(1.0, 0.42, 0.55), 0.5)
	tongue.scale = Vector3(1.3, 0.35, 1.0)
	tongue.position = Vector3(0, -0.06, 0.06)
	model.add_child(tongue)
	var coin := Props.inst(Props.BGB + "coin_gold.gltf", 0.12, false)
	coin.position = Vector3(0.05, -0.04, 0.02)
	coin.rotation = Vector3(0.4, 0.3, 0.2)
	model.add_child(coin)
	_glow_sphere(model, Vector3(0, -0.05, 0.04), 0.07, Color(1.0, 0.8, 0.3), 1.2)


## Looping soft motes drifting up (skull trail).
func _wisps(parent: Node3D, pos: Vector3, color: Color, n: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = 0.9
	p.position = pos
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3(0, 0.3, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color = color
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	q.material = Props.particle_material("dot")
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


func _build_aura() -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.13
	tm.outer_radius = 0.16
	ring.mesh = tm
	ring.material_override = Props.glow_material(Color(1.0, 0.85, 0.35), false, 2.2)
	ring.position = Vector3(0, 0.36, 0)
	ring.rotation.x = 0.25
	ring.name = "Halo"
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(ring)
	var sp := Fx.elite_sparkle(float_root, Vector3(0, -0.3, 0), 0.34, 0.7)
	sp.amount = 10
	_halo(float_root, Vector3(0, 0, -0.15), 0.95, Color(1.0, 0.8, 0.35), 0.14)


func _build_pips(n: int) -> void:
	for p in _pips:
		p.queue_free()
	_pips.clear()
	size_pips = n
	_pip_on = Props.glow_material(accent.lightened(0.25), false, 1.6)
	_pip_off = StandardMaterial3D.new()
	_pip_off.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pip_off.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pip_off.albedo_color = Color(1.0, 1.0, 1.0, 0.3)
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	sm.radial_segments = 10
	sm.rings = 6
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = _pip_off
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * float(i) / float(n)
		mi.position = Vector3(cos(a) * PIP_RADIUS, 0.0, sin(a) * PIP_RADIUS)
		pips_root.add_child(mi)
		_pips.append(mi)
	pips_root.position.y = -0.2
	if _full_ring == null:
		_full_ring = MeshInstance3D.new()
		_full_ring.mesh = Props.quad(PIP_RADIUS * 2.9)
		var m := Props.glow_material(accent, true, 0.65)
		m.albedo_texture = Props.particle_texture("ring")
		_full_ring.material_override = m
		_full_ring.rotation.x = -PI * 0.5
		_full_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pips_root.add_child(_full_ring)
	_full_ring.visible = false


# ======================================================================= charge

## Shows `c` of `n` pips lit. animate pops the newly lit pips (and the ring when full).
func set_charge(c: int, n: int, animate := false) -> void:
	if n != size_pips and n > 0:
		_build_pips(n)
	var was := charge
	charge = clampi(c, 0, size_pips)
	for i in _pips.size():
		var on := i < charge
		_pips[i].material_override = _pip_on if on else _pip_off
		if animate and on and i >= was and is_inside_tree():
			_pips[i].scale = Vector3.ONE * 2.2
			var t := _pips[i].create_tween()
			t.tween_property(_pips[i], "scale", Vector3.ONE, 0.35 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var full := charge >= size_pips and size_pips > 0
	_full_ring.visible = full
	if animate and full and was < charge and is_inside_tree():
		hop(0.18)
		Fx.shockwave(self, float_root.position + Vector3(0, -0.2, 0), accent, 0.9, 0.45)


func is_full() -> bool:
	return size_pips > 0 and charge >= size_pips


# ======================================================================= per-frame

func _process(dt: float) -> void:
	_t += dt * speed
	var bob := sin(_t * 2.4) * 0.06
	float_root.position.y = HOVER * _scale + bob
	shadow.scale = Vector3.ONE * (0.9 - bob * 1.5) * _scale
	pips_root.rotation.y += dt * speed * (2.2 if is_full() else 0.7)
	if is_full():
		var k := 1.0 + 0.18 * sin(_t * 9.0)
		for p in _pips:
			p.scale = Vector3.ONE * k
		_full_ring.scale = Vector3.ONE * (1.0 + 0.08 * sin(_t * 6.0))
	if follow and not _acting:
		var w := 1.0 - exp(-dt * stiffness * speed)
		global_position = global_position.lerp(home, w)
	if face_camera and not _acting:
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var target := _look_at
		if target == Vector3.INF and cam:
			target = cam.global_position
		if target != Vector3.INF:
			var d := target - global_position
			var yaw := atan2(d.x, d.z) + sin(_t * 0.9) * 0.18
			body.rotation.y = lerp_angle(body.rotation.y, yaw, 1.0 - exp(-dt * 6.0))
	body.rotation.z = sin(_t * 1.7) * 0.08
	# per-pet idle life
	if _lid and not _acting:
		var ch := maxf(0.0, sin(_t * 1.6))
		_lid.rotation.x = -pow(ch, 6.0) * 0.55
	if _flame:
		_flame.scale = Vector3(1.0 + 0.06 * sin(_t * 11.0), 1.0 + 0.1 * sin(_t * 7.3 + 1.0), 1.0)
		light.light_energy = 1.8 + 0.4 * sin(_t * 9.0)
	if _orbiters:
		_orbiters.rotation.y = _t * 1.6
	if _jaw and not _acting:
		_jaw.rotation.x = maxf(0.0, sin(_t * 3.1)) * 0.18
	if not parts.is_empty():
		PetViewExt.idle(self, dt)
	if _glint:
		var g := fmod(_t, 2.6)
		_glint.scale = Vector3.ONE * (sin(clampf(g / 0.35, 0.0, 1.0) * PI) * 1.0 + 0.01)
	_blink -= dt
	if _blink <= 0.0:
		_blink = randf_range(2.0, 4.5)
		for e in _eyes:
			var t := e.create_tween()
			t.tween_property(e, "scale:y", 0.1, 0.06)
			t.tween_property(e, "scale:y", 1.0, 0.08)


## Idle yaw target (global). Vector3.INF = the active camera.
func look_toward(p: Vector3) -> void:
	_look_at = p


func snap() -> void:
	global_position = home


# ======================================================================= actions

## A happy little hop (non-blocking).
func hop(h := 0.25) -> void:
	var t := body.create_tween()
	t.tween_property(body, "position:y", h, 0.14 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(body, "position:y", 0.0, 0.2 / speed).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	squash(0.3)


func squash(time := 0.25) -> void:
	var s := Vector3.ONE * _scale
	var t := create_tween()
	t.tween_property(body, "scale", Vector3(s.x * 1.25, s.y * 0.75, s.z * 1.25), time * 0.35 / speed)
	t.tween_property(body, "scale", s, time * 0.65 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Full spin (360 on y, or tumble on x for the die).
func spin(time := 0.45) -> void:
	var t := create_tween()
	if pet_id == "guard_die":
		var r := model.rotation
		t.tween_property(model, "rotation:x", r.x + TAU, time / speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_callback(func() -> void: model.rotation.x = r.x)
	else:
		var r := model.rotation.y
		t.tween_property(model, "rotation:y", r + TAU, time / speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_callback(func() -> void: model.rotation.y = r)
	await t.finished


## Opens wide (mimic lid / big squash) for a chomp.
func chomp() -> void:
	if _jaw:
		var tj := _jaw.create_tween()
		tj.tween_property(_jaw, "rotation:x", 0.7, 0.1 / speed)
		tj.tween_property(_jaw, "rotation:x", 0.0, 0.08 / speed)
		tj.tween_property(_jaw, "rotation:x", 0.5, 0.08 / speed)
		tj.tween_property(_jaw, "rotation:x", 0.0, 0.08 / speed)
	if _lid:
		var t := _lid.create_tween()
		t.tween_property(_lid, "rotation:x", -1.0, 0.1 / speed).set_trans(Tween.TRANS_QUAD)
		t.tween_property(_lid, "rotation:x", 0.0, 0.08 / speed)
		t.tween_property(_lid, "rotation:x", -0.6, 0.08 / speed)
		t.tween_property(_lid, "rotation:x", 0.0, 0.08 / speed)
	squash(0.3)


## Flies to `to` (global point, body height) on a little arc; await.
func dash_to(to: Vector3, time := 0.28) -> void:
	_acting = true
	var from := global_position
	var dest := to - Vector3.UP * (HOVER * _scale)
	var d := dest - from
	body.rotation.y = atan2(d.x, d.z)
	var t := create_tween()
	t.tween_method(func(u: float) -> void:
		if is_instance_valid(self):
			global_position = from.lerp(dest, u) + Vector3.UP * (0.8 * u * (1.0 - u)), 0.0, 1.0, time / speed) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## Drifts back to `home` and resumes following (non-blocking unless awaited).
func return_home(time := 0.35) -> void:
	var from := global_position
	var t := create_tween()
	t.tween_method(func(u: float) -> void:
		if is_instance_valid(self):
			global_position = from.lerp(home, u) + Vector3.UP * (0.5 * u * (1.0 - u)), 0.0, 1.0, time / speed) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	_acting = false


## World point of the pet's body centre.
func body_position() -> Vector3:
	return float_root.global_position


## Plays the action for a pet_acted effect. `target` is a world point (bite target, heal
## target) or Vector3.INF. Resolves at the impact moment; the pet drifts home on its own.
## opts (PetViewExt pets): targets (Array of world points), die_idx, face, color.
func act(effect: String, target := Vector3.INF, opts := {}) -> void:
	if PetViewExt.has(pet_id):
		await PetViewExt.act(self, effect, target, opts)
		return
	match effect:
		"bite":
			if target == Vector3.INF:
				await spin()
				return
			await dash_to(target + Vector3(0, 0.1, 0))
			chomp()
			Fx.hit_sparks(get_parent_node_3d() if get_parent_node_3d() else self, target, accent, 18)
			return_home(0.4)
		"heal":
			hop(0.3)
			Fx.burst(self, float_root.position, {"amount": 18, "lifetime": 0.8, "speed": Vector2(0.6, 1.6),
				"gravity": Vector3(0, 1.2, 0), "size": 0.22, "color": Fx.HEAL_COLOR, "tex": "spark"})
			if target != Vector3.INF:
				await Fx.projectile(get_parent_node_3d(), body_position(), target, Fx.HEAL_COLOR, 0.3 / speed)
		"poison":
			hop(0.2)
			await spin(0.35)
		"reroll":
			hop(0.3)
			Fx.burst(self, float_root.position, {"amount": 24, "lifetime": 0.8, "speed": Vector2(1.0, 2.4),
				"gravity": Vector3.ZERO, "size": 0.24, "color": accent, "tex": "spark"})
			await spin(0.4)
		"block":
			hop(0.35)
			await spin(0.45)
		"gold":
			chomp()
			hop(0.25)
			Fx.coin_burst(get_parent_node_3d() if get_parent_node_3d() else self, body_position(), 7)
			await get_tree().create_timer(0.25 / speed).timeout
		_:
			hop(0.3)
			await get_tree().create_timer(0.25 / speed).timeout
