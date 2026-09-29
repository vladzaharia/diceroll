class_name PetViewExt
extends RefCounted
## The six newer familiars (WP-E4) for PetView: their models, idle life and act animations.
## PetView dispatches here for these ids; the builders use PetView's own helpers (eyes,
## blush, glows) so the whole zoo shares one look.
##
##   pebble_golem  Pebble      rock golem with ore bits, floating fists and a mossy sprout
##                             act "block"/"thorns": fists slam, shield bubble + thorn spikes
##   frost_mote    Frost Mote  snowball sprite in a slowly turning snowflake
##                             act "freeze": frost beam, the target is encased in ice
##   wick          Wick        a chamberstick candle whose flame is its face
##                             act "burn": flame puff, a fire wave over every enemy
##   tinker_gear   Tinker      clockwork beetle: jewel shell, wind-up cog, goggle eyes
##                             act "fix": winds up and hops off to the tray (fixed_die hook)
##   grimoire      Grimoire    a spellbook with one big eye and page wings
##                             act "rune": pages flutter, a rune sigil flashes
##   cauldron      Bubbles     a bubbling cauldron on stubby legs with a ladle
##                             act "potion": stirs, a potion bottle pops out
##
## Per-pet moving parts live in `v.parts` (name -> Node3D / value).

const IDS := ["pebble_golem", "frost_mote", "wick", "tinker_gear", "grimoire", "cauldron"]
## Display names and meter sizes while the rules (PetDefs) don't have these pets yet.
const NAMES := {
	"pebble_golem": "Pebble", "frost_mote": "Frost Mote", "wick": "Wick", "tinker_gear": "Tinker",
	"grimoire": "Grimoire", "cauldron": "Bubbles",
}
const SIZES := {"pebble_golem": 5, "frost_mote": 5, "wick": 6, "tinker_gear": 4, "grimoire": 5, "cauldron": 6}
## Each pet's pet_acted effect (the older six too: galleries use it for --act=own).
const EFFECTS := {
	"pumpkin_sprite": "heal", "skull_buddy": "bite", "lantern_ghost": "poison", "crystal_wisp": "reroll",
	"guard_die": "block", "coin_mimic": "gold",
	"pebble_golem": "thorns", "frost_mote": "freeze", "wick": "burn", "tinker_gear": "fix", "grimoire": "rune",
	"cauldron": "potion",
}

const RES := "res://assets/kaykit/resource/"
const IRON_L := RES + "Iron_Nugget_Large.gltf"
const IRON_M := RES + "Iron_Nugget_Medium.gltf"
const COPPER_S := RES + "Copper_Nugget_Small.gltf"
const GOLD_S := RES + "Gold_Nugget_Small.gltf"
const COG := RES + "Parts_Cog.gltf"

const ICE := Color(0.78, 0.94, 1.0)
const FLAME := Color(1.0, 0.52, 0.16)
const FLAME_CORE := Color(1.0, 0.9, 0.45)
const BREW := Color(1.0, 0.45, 0.72)


static func has(id: String) -> bool:
	return IDS.has(id)


static func build(v: PetView) -> void:
	match v.pet_id:
		"pebble_golem": _build_pebble(v)
		"frost_mote": _build_frost(v)
		"wick": _build_wick(v)
		"tinker_gear": _build_tinker(v)
		"grimoire": _build_grimoire(v)
		"cauldron": _build_cauldron(v)


# ======================================================================= helpers

static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.scale = scl
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


static func _sphere(r: float, seg := 16, rings := 8, hemi := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * (1.0 if hemi else 2.0)
	s.radial_segments = seg
	s.rings = rings
	s.is_hemisphere = hemi
	return s


static func _cyl(top: float, bottom: float, h: float, seg := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 10
	return t


static func _metal(color: Color, metallic := 0.6, rough := 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	return m


static func _glassy(color: Color, emission: Color, energy := 0.6, alpha := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	m.roughness = 0.15
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.3
	return m


## A dark little smile arc (torus squashed), like the Guard Die's.
static func _smile(parent: Node3D, pos: Vector3, r: float, color := Color(0.08, 0.05, 0.12)) -> MeshInstance3D:
	var s := _mi(parent, _torus(r * 0.7, r), Props.flat_material(color, 0.4), pos, Vector3(1.0, 0.35, 0.6),
		Vector3(PI * 0.5, 0.0, 0.0))
	return s


static func _world(v: PetView) -> Node3D:
	var p := v.get_parent_node_3d()
	return p if p else v


static func _wait(v: PetView, t: float) -> void:
	await v.get_tree().create_timer(t / v.speed).timeout


## Looping particles under `parent` (bubbles, embers, snow).
static func _stream(parent: Node3D, pos: Vector3, cfg: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(cfg.get("amount", 8))
	p.lifetime = float(cfg.get("lifetime", 1.0))
	p.position = pos
	p.local_coords = bool(cfg.get("local", false))
	p.preprocess = p.lifetime
	var pm := ParticleProcessMaterial.new()
	pm.direction = cfg.get("dir", Vector3.UP)
	pm.spread = float(cfg.get("spread", 20.0))
	var sp: Vector2 = cfg.get("speed", Vector2(0.1, 0.3))
	pm.initial_velocity_min = sp.x
	pm.initial_velocity_max = sp.y
	pm.gravity = cfg.get("gravity", Vector3.ZERO)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = float(cfg.get("radius", 0.08))
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var sc := Curve.new()
	for pt in cfg.get("curve", [Vector2(0.0, 0.3), Vector2(0.2, 1.0), Vector2(1.0, 0.0)]):
		sc.add_point(pt)
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color = cfg.get("color", Color.WHITE)
	p.process_material = pm
	var q := QuadMesh.new()
	var size := float(cfg.get("size", 0.12))
	q.size = Vector2(size, size)
	q.material = Props.particle_material(String(cfg.get("tex", "dot")), bool(cfg.get("additive", true)))
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


# ======================================================================= builders

## Pebble: a round rock with a face, copper and gold ore bits, a mossy sprout on top, two
## floating rock fists and a ridge of little amber thorns on its back.
static func _build_pebble(v: PetView) -> void:
	var m := v.model
	var rock := v._prop(IRON_L, 0.95, Vector3(0, -0.02, 0))
	Props.tint(rock, Color(0.86, 0.8, 0.72), 0.6)
	# ore bits
	var ore := [[COPPER_S, Vector3(0.17, 0.06, 0.08), 0.95], [GOLD_S, Vector3(-0.17, -0.1, 0.08), 0.95],
		[COPPER_S, Vector3(-0.1, 0.16, 0.02), 0.7]]
	for o in ore:
		var n := v._prop(String(o[0]), float(o[2]), o[1])
		n.rotation = Vector3(0.6, 0.8, 0.3)
	# moss cap + sprout
	var moss := Props.flat_material(Color(0.42, 0.72, 0.3), 0.8)
	for b in [[Vector3(0.02, 0.2, -0.01), 0.1], [Vector3(-0.06, 0.19, 0.02), 0.055], [Vector3(0.09, 0.18, 0.02), 0.05]]:
		_mi(m, _sphere(float(b[1]), 10, 5), moss, b[0], Vector3(1.2, 0.45, 1.1))
	var sprout := Node3D.new()
	sprout.position = Vector3(0.03, 0.23, 0.0)
	m.add_child(sprout)
	_mi(sprout, _cyl(0.008, 0.012, 0.08, 6), moss, Vector3(0, 0.04, 0))
	for s in [-1.0, 1.0]:
		_mi(sprout, _sphere(0.04, 10, 5), Props.flat_material(Color(0.5, 0.86, 0.36), 0.6),
			Vector3(s * 0.035, 0.085, 0.0), Vector3(1.0, 0.35, 0.6), Vector3(0.0, 0.0, s * 0.5))
	v.parts["sprout"] = sprout
	# face
	v._eye(m, Vector3(-0.07, 0.03, 0.215), 0.04)
	v._eye(m, Vector3(0.07, 0.03, 0.215), 0.04)
	v._blush(m, Vector3(0.125, -0.035, 0.205), 0.075)
	_smile(m, Vector3(0.0, -0.04, 0.22), 0.026)
	# thorns: a ridge of amber crystal spikes on the back
	var thorns := Node3D.new()
	thorns.name = "Thorns"
	m.add_child(thorns)
	var tm := _glassy(Color(1.0, 0.72, 0.45), Color(0.6, 0.3, 0.1), 0.5, 1.0)
	var spots := [Vector3(0.0, 0.16, -0.14), Vector3(-0.13, 0.1, -0.12), Vector3(0.13, 0.1, -0.12),
		Vector3(-0.19, -0.02, -0.06), Vector3(0.19, -0.02, -0.06)]
	var list: Array[Node3D] = []
	for p in spots:
		var t := Node3D.new()
		t.position = p
		thorns.add_child(t)
		var out: Vector3 = (p - Vector3(0, -0.05, 0.05)).normalized()
		var cone := _mi(t, _cyl(0.0, 0.035, 0.12, 5), tm, out * 0.05)
		cone.basis = Basis(Quaternion(Vector3.UP, out))
		list.append(t)
	v.parts["thorns"] = list
	# floating fists
	var fists: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var f := Node3D.new()
		f.position = Vector3(s * 0.29, -0.1, 0.06)
		m.add_child(f)
		var fr := Props.inst(IRON_M, 0.62, false)
		fr.rotation = Vector3(0.3, s * 0.7, 0.2)
		Props.tint(fr, Color(0.86, 0.8, 0.72), 0.6)
		f.add_child(fr)
		fists.append(f)
	v.parts["fists"] = fists
	v._halo(m, Vector3(0, 0.0, -0.12), 0.8, Color(1.0, 0.75, 0.5), 0.14)


## Frost Mote: a round snowball sprite with a face, set in a six-armed snowflake that turns
## slowly behind it; a few flakes drift down.
static func _build_frost(v: PetView) -> void:
	var m := v.model
	var ice := _glassy(Color(0.82, 0.95, 1.0), Color(0.35, 0.7, 1.0), 0.7, 0.9)
	var flake := Node3D.new()
	flake.position = Vector3(0, 0.0, -0.05)
	m.add_child(flake)
	for k in 6:
		var arm := Node3D.new()
		arm.rotation.z = TAU * k / 6.0
		flake.add_child(arm)
		_mi(arm, _box(Vector3(0.036, 0.22, 0.03)), ice, Vector3(0, 0.2, 0))
		for s in [-1.0, 1.0]:
			_mi(arm, _box(Vector3(0.026, 0.085, 0.024)), ice, Vector3(s * 0.03, 0.235, 0), Vector3.ONE,
				Vector3(0, 0, -s * 0.8))
		# a little crystal bead at the tip
		_mi(arm, _sphere(0.032, 4, 2), _glassy(Color(0.92, 0.98, 1.0), Color(0.5, 0.85, 1.0), 1.2, 1.0),
			Vector3(0, 0.325, 0), Vector3(0.8, 1.4, 0.8))
	v.parts["flake"] = flake
	# the snowball body
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.94, 0.98, 1.0)
	snow.roughness = 0.6
	snow.emission_enabled = true
	snow.emission = Color(0.4, 0.6, 0.85)
	snow.emission_energy_multiplier = 0.25
	snow.rim_enabled = true
	snow.rim = 0.8
	snow.rim_tint = 0.6
	_mi(m, _sphere(0.15, 20, 10), snow, Vector3(0, 0, 0.02))
	# a little frosty tuft on top
	_mi(m, _cyl(0.0, 0.04, 0.09, 6), ice, Vector3(0.02, 0.17, 0.02), Vector3.ONE, Vector3(0, 0, -0.3))
	_mi(m, _cyl(0.0, 0.03, 0.06, 6), ice, Vector3(-0.035, 0.15, 0.02), Vector3.ONE, Vector3(0, 0, 0.5))
	v._eye(m, Vector3(-0.058, 0.02, 0.155), 0.036)
	v._eye(m, Vector3(0.058, 0.02, 0.155), 0.036)
	v._blush(m, Vector3(0.1, -0.035, 0.145), 0.07)
	_smile(m, Vector3(0, -0.045, 0.165), 0.018)
	v._halo(m, Vector3(0, 0.0, -0.12), 0.95, Color(0.55, 0.85, 1.0), 0.22)
	# snowfall
	_stream(v.float_root, Vector3(0, -0.1, 0), {"amount": 7, "lifetime": 1.3, "dir": Vector3.DOWN, "speed": Vector2(0.05, 0.15),
		"gravity": Vector3(0, -0.25, 0), "radius": 0.28, "size": 0.09, "color": Color(0.9, 0.97, 1.0, 0.9), "tex": "spark",
		"curve": [Vector2(0.0, 0.2), Vector2(0.2, 1.0), Vector2(1.0, 0.1)]})


## Wick: a fat candle in a little brass chamberstick; its flame is its face.
static func _build_wick(v: PetView) -> void:
	var m := v.model
	m.scale = Vector3.ONE * 1.15
	var brass := _metal(Color(0.9, 0.68, 0.32), 0.7, 0.3)
	# the chamberstick: a dish and a ring handle
	_mi(m, _cyl(0.17, 0.13, 0.04, 20), brass, Vector3(0, -0.3, 0))
	_mi(m, _torus(0.028, 0.05), brass, Vector3(0.19, -0.29, 0.0), Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
	var candle := v._prop(Props.HAL + "candle.gltf", 1.0, Vector3(0, -0.29, 0))
	candle.scale = Vector3(0.72, 0.36, 0.72)
	Props.tint(candle, Color(1.0, 0.9, 0.95), 0.35)
	# wax drips down the front
	var wax := Props.flat_material(Color(1.0, 0.95, 0.9), 0.5)
	for d in [[-0.06, 0.07], [0.04, 0.1], [0.08, 0.05]]:
		_mi(m, _cyl(0.018, 0.018, float(d[1]), 8), wax, Vector3(float(d[0]), -0.02 - float(d[1]) * 0.5, 0.1))
		_mi(m, _sphere(0.019, 8, 4), wax, Vector3(float(d[0]), -0.02 - float(d[1]), 0.1))
	v._blush(m, Vector3(0.07, -0.12, 0.112), 0.06)
	# the wick and the living flame
	_mi(m, _cyl(0.008, 0.01, 0.05, 6), Props.flat_material(Color(0.15, 0.1, 0.1)), Vector3(0, -0.005, 0))
	var flame := Node3D.new()
	flame.position = Vector3(0, 0.12, 0.0)
	m.add_child(flame)
	var fm := _glassy(Color(1.0, 0.42, 0.08), Color(1.0, 0.3, 0.02), 0.7, 0.95)
	fm.rim = 0.1
	_mi(flame, _sphere(0.125, 18, 10), fm, Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	var tip := _mi(flame, _cyl(0.0, 0.1, 0.2, 14), fm, Vector3(0.0, 0.15, -0.01), Vector3(1.0, 1.0, 0.8), Vector3(0, 0, 0.18))
	tip.name = "Tip"
	var core := _glassy(Color(1.0, 0.82, 0.3), Color(1.0, 0.62, 0.1), 0.6, 1.0)
	_mi(flame, _sphere(0.08, 14, 8), core, Vector3(0, -0.035, 0.035), Vector3(1.0, 1.1, 0.75))
	v._halo(flame, Vector3(0, 0.03, -0.06), 0.8, Color(1.0, 0.55, 0.2), 0.35)
	v._eye(flame, Vector3(-0.045, 0.0, 0.1), 0.03)
	v._eye(flame, Vector3(0.045, 0.0, 0.1), 0.03)
	_smile(flame, Vector3(0, -0.045, 0.1), 0.015, Color(0.35, 0.08, 0.05))
	v.parts["flame"] = flame
	# rising embers
	_stream(flame, Vector3(0, 0.12, 0), {"amount": 6, "lifetime": 0.8, "speed": Vector2(0.15, 0.35), "gravity": Vector3(0, 0.3, 0),
		"radius": 0.05, "size": 0.07, "color": Color(1.0, 0.7, 0.3), "tex": "dot"})


## Tinker: a clockwork beetle with a jewel-teal shell, a brass wind-up cog on its back,
## goggle eyes, antennae and six stubby legs.
static func _build_tinker(v: PetView) -> void:
	var m := v.model
	m.position.y = -0.04
	var brass := _metal(Color(0.92, 0.7, 0.34), 0.75, 0.28)
	var dark := _metal(Color(0.2, 0.17, 0.22), 0.4, 0.5)
	# the cog (wind-up gear), upright behind the shell
	var cog := Props.inst(COG, 0.72, false)
	Props.tint(cog, Color(0.95, 0.72, 0.35), 0.7)
	var cogp := Node3D.new()
	cogp.position = Vector3(0, 0.15, -0.12)
	cogp.add_child(cog)
	m.add_child(cogp)
	v.parts["cog"] = cogp
	# shell: two teal wing cases with a brass seam and rivets
	var shell := _metal(Color(0.16, 0.66, 0.6), 0.55, 0.22)
	_mi(m, _sphere(0.2, 20, 10, true), shell, Vector3(0, -0.07, -0.02), Vector3(1.0, 0.95, 1.12))
	_mi(m, _cyl(0.2, 0.2, 0.025, 20), dark, Vector3(0, -0.075, -0.02), Vector3(1.02, 1.0, 1.14))
	for k in 3:
		for s in [-1.0, 1.0]:
			_mi(m, _sphere(0.014, 8, 4), brass, Vector3(s * 0.1, 0.07 - 0.02 * k, -0.1 + 0.09 * k))
	# spots on the shell
	for p in [Vector3(-0.1, 0.06, 0.06), Vector3(0.1, 0.06, 0.06), Vector3(-0.12, 0.02, -0.1), Vector3(0.12, 0.02, -0.1)]:
		_mi(m, _sphere(0.03, 10, 5), Props.flat_material(Color(0.95, 0.88, 0.5), 0.4), p, Vector3(1.0, 0.4, 1.0))
	# legs
	var legs: Array[Node3D] = []
	for k in 3:
		for s in [-1.0, 1.0]:
			var l := Node3D.new()
			l.position = Vector3(s * 0.15, -0.08, 0.08 - k * 0.1)
			l.rotation.z = s * 0.7
			m.add_child(l)
			_mi(l, _cyl(0.014, 0.018, 0.1, 6), dark, Vector3(0, -0.05, 0))
			_mi(l, _sphere(0.022, 8, 4), brass, Vector3(0, -0.1, 0))
			legs.append(l)
	v.parts["legs"] = legs
	# head with goggle eyes
	var head := Node3D.new()
	head.position = Vector3(0, -0.02, 0.19)
	m.add_child(head)
	_mi(head, _sphere(0.11, 18, 9), dark, Vector3.ZERO, Vector3(1.1, 0.9, 0.9))
	for s in [-1.0, 1.0]:
		_mi(head, _torus(0.036, 0.052), brass, Vector3(s * 0.052, 0.02, 0.085), Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
		_mi(head, _sphere(0.037, 12, 6), Props.flat_material(Color(0.95, 0.97, 1.0), 0.3), Vector3(s * 0.052, 0.02, 0.08),
			Vector3(1.0, 1.0, 0.5))
		v._eye(head, Vector3(s * 0.052, 0.018, 0.095), 0.026)
	_mi(head, _box(Vector3(0.03, 0.012, 0.02)), brass, Vector3(0, 0.03, 0.09))
	v._blush(head, Vector3(0.085, -0.035, 0.08), 0.055)
	_smile(head, Vector3(0, -0.04, 0.095), 0.014)
	# antennae
	for s in [-1.0, 1.0]:
		var a := Node3D.new()
		a.position = Vector3(s * 0.04, 0.08, 0.02)
		a.rotation = Vector3(-0.4, 0.0, -s * 0.45)
		head.add_child(a)
		_mi(a, _cyl(0.007, 0.009, 0.12, 6), dark, Vector3(0, 0.06, 0))
		_mi(a, _sphere(0.02, 10, 5), brass, Vector3(0, 0.125, 0))
	v.parts["head"] = head
	v._halo(m, Vector3(0, -0.02, -0.2), 0.8, Color(0.45, 1.0, 0.8), 0.09)


## Grimoire: a violet leather spellbook standing on its spine-edge, one big eye on the cover,
## a glowing rune below it and fanned page wings.
static func _build_grimoire(v: PetView) -> void:
	var m := v.model
	var book := v._prop(Props.TOOLS + "journal_closed.gltf", 0.56, Vector3(0, 0.02, 0.0))
	book.rotation.y = -PI * 0.5
	Props.tint(book, Color(0.62, 0.4, 0.95), 0.55)
	# page wings: three fanned pages per side hinged at the book's edge
	var page := Props.flat_material(Color(1.0, 0.96, 0.86), 0.7)
	var line := Props.flat_material(Color(0.62, 0.5, 0.72), 0.7)
	var wings: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(s * 0.1, 0.03, -0.02)
		m.add_child(w)
		for k in 3:
			var p := Node3D.new()
			p.rotation.z = s * (0.15 + 0.32 * k) - s * 0.25
			w.add_child(p)
			var q := _mi(p, _box(Vector3(0.2, 0.11, 0.008)), page, Vector3(s * 0.11, 0.0, -0.012 * k))
			q.rotation.y = -s * 0.12
			for r in 2:
				_mi(q, _box(Vector3(0.12, 0.008, 0.01)), line, Vector3(s * 0.01, 0.025 - r * 0.04, 0.0))
		wings.append(w)
	v.parts["wings"] = wings
	# the big eye (sclera, violet iris, pupil), in a golden rim
	var eye := Node3D.new()
	eye.position = Vector3(0, 0.08, 0.125)
	m.add_child(eye)
	_mi(eye, _torus(0.07, 0.085), _metal(Color(0.95, 0.75, 0.35), 0.7, 0.3), Vector3.ZERO, Vector3(1.0, 1.0, 1.0),
		Vector3(PI * 0.5, 0.0, 0.0))
	_mi(eye, _sphere(0.072, 18, 9), Props.flat_material(Color(1.0, 0.98, 0.95), 0.3), Vector3(0, 0, -0.01), Vector3(1.0, 1.0, 0.45))
	var iris := Node3D.new()
	iris.position = Vector3(0, -0.004, 0.022)
	eye.add_child(iris)
	_mi(iris, _sphere(0.042, 16, 8), Props.glow_material(Color(0.62, 0.35, 1.0), false, 1.1), Vector3.ZERO, Vector3(1.0, 1.0, 0.3))
	var e := v._eye(iris, Vector3(0, 0, 0.008), 0.024)
	v._eyes.erase(e)
	v._eyes.append(eye)
	v.parts["iris"] = iris
	# lashes
	for k in 3:
		var a := -0.5 + 0.5 * k
		_mi(eye, _box(Vector3(0.01, 0.035, 0.01)), Props.flat_material(Color(0.12, 0.07, 0.15)),
			Vector3(sin(a) * 0.085, cos(a) * 0.085 + 0.012, 0.0), Vector3.ONE, Vector3(0, 0, -a))
	# the rune below the eye
	var rune := Node3D.new()
	rune.position = Vector3(0, -0.1, 0.125)
	m.add_child(rune)
	var rg := Props.glow_material(Color(0.8, 0.55, 1.0), false, 1.8)
	_mi(rune, _torus(0.032, 0.042), rg, Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
	_mi(rune, _box(Vector3(0.032, 0.032, 0.01)), rg, Vector3.ZERO, Vector3(1.0, 1.3, 1.0), Vector3(0, 0, PI * 0.25))
	v.parts["rune"] = rune
	# bookmark ribbon
	_mi(m, _box(Vector3(0.025, 0.1, 0.006)), Props.flat_material(Color(0.95, 0.3, 0.4), 0.6), Vector3(0.05, -0.27, 0.0),
		Vector3.ONE, Vector3(0, 0, 0.15))
	v._halo(m, Vector3(0, 0.0, -0.12), 0.9, Color(0.7, 0.45, 1.0), 0.2)


## Bubbles: a round iron cauldron on stubby legs, pink brew bubbling in it, a ladle, a face.
static func _build_cauldron(v: PetView) -> void:
	var m := v.model
	var iron := _metal(Color(0.26, 0.24, 0.32), 0.45, 0.45)
	var rim := _metal(Color(0.38, 0.35, 0.46), 0.5, 0.35)
	var pot := _mi(m, _sphere(0.2, 22, 11, true), iron, Vector3(0, 0.06, 0), Vector3(1.0, 1.25, 1.0), Vector3(PI, 0.0, 0.0))
	pot.name = "Pot"
	_mi(m, _torus(0.165, 0.205), rim, Vector3(0, 0.06, 0))
	var brew := _glassy(Color(1.0, 0.36, 0.68), Color(1.0, 0.16, 0.5), 0.75, 1.0)
	var surf := _mi(m, _cyl(0.175, 0.175, 0.02, 22), brew, Vector3(0, 0.055, 0))
	v.parts["brew"] = surf
	# legs
	for k in 3:
		var a := TAU * k / 3.0 + PI * 0.5 + PI / 3.0
		_mi(m, _cyl(0.025, 0.035, 0.08, 8), iron, Vector3(cos(a) * 0.12, -0.22, sin(a) * 0.12))
	# side lugs
	for s in [-1.0, 1.0]:
		_mi(m, _torus(0.018, 0.034), rim, Vector3(s * 0.21, 0.02, 0), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	# bubbles on the surface (they swell and pop in idle)
	var bubbles: Array[Node3D] = []
	var bm := _glassy(Color(1.0, 0.75, 0.9), Color(1.0, 0.4, 0.7), 0.9, 0.85)
	for p in [Vector3(-0.06, 0.07, 0.05), Vector3(0.07, 0.07, -0.03), Vector3(-0.02, 0.07, -0.08)]:
		bubbles.append(_mi(m, _sphere(0.035, 12, 6), bm, p))
	v.parts["bubbles"] = bubbles
	# the ladle (pivot at the pot's centre so stirring swings it round)
	var stir := Node3D.new()
	stir.position = Vector3(0, 0.06, 0)
	m.add_child(stir)
	var ladle := Node3D.new()
	ladle.position = Vector3(0.09, 0.0, -0.05)
	ladle.rotation = Vector3(0.25, 0.0, -0.4)
	stir.add_child(ladle)
	var wood := Props.flat_material(Color(0.72, 0.48, 0.28), 0.7)
	_mi(ladle, _cyl(0.013, 0.013, 0.3, 8), wood, Vector3(0, 0.1, 0))
	_mi(ladle, _sphere(0.02, 8, 4), wood, Vector3(0, 0.25, 0))
	v.parts["stir"] = stir
	# face on the belly
	v._eye(m, Vector3(-0.072, -0.05, 0.178), 0.04)
	v._eye(m, Vector3(0.072, -0.05, 0.178), 0.04)
	v._blush(m, Vector3(0.12, -0.1, 0.16), 0.07)
	_smile(m, Vector3(0, -0.11, 0.18), 0.022)
	v._halo(m, Vector3(0, 0.1, -0.1), 0.8, Color(1.0, 0.5, 0.8), 0.18)
	# steam-bubbles rising from the brew
	_stream(v.float_root, Vector3(0, 0.1, 0), {"amount": 7, "lifetime": 0.9, "speed": Vector2(0.15, 0.35),
		"gravity": Vector3(0, 0.2, 0), "radius": 0.1, "size": 0.08, "color": Color(1.0, 0.7, 0.88, 0.9), "tex": "ring",
		"additive": false})


# ======================================================================= idle

static func idle(v: PetView, dt: float) -> void:
	var t := v._t
	match v.pet_id:
		"pebble_golem":
			var fists: Array = v.parts.get("fists", [])
			if not v._acting:
				for k in fists.size():
					var f: Node3D = fists[k]
					f.position.y = -0.1 + sin(t * 2.4 + k * 1.7) * 0.025
			var sp: Node3D = v.parts.get("sprout")
			if sp:
				sp.rotation.z = sin(t * 2.0) * 0.18
		"frost_mote":
			var fl: Node3D = v.parts.get("flake")
			if fl and not v._acting:
				fl.rotation.z += dt * v.speed * 0.6
		"wick":
			var fl: Node3D = v.parts.get("flame")
			if fl and not v._acting:
				fl.scale = Vector3(1.0 + 0.05 * sin(t * 11.0), 1.0 + 0.09 * sin(t * 7.3 + 1.0), 1.0)
				fl.rotation.z = sin(t * 3.1) * 0.08
			v.light.light_energy = 1.6 + 0.45 * sin(t * 9.0) + 0.2 * sin(t * 23.0)
		"tinker_gear":
			var cog: Node3D = v.parts.get("cog")
			if cog:
				cog.rotation.z -= dt * v.speed * (9.0 if v._acting else 1.2)
			var legs: Array = v.parts.get("legs", [])
			for k in legs.size():
				var l: Node3D = legs[k]
				l.rotation.x = sin(t * 7.0 + k * 1.3) * 0.35
			var head: Node3D = v.parts.get("head")
			if head:
				head.rotation.z = sin(t * 1.3) * 0.08
		"grimoire":
			var wings: Array = v.parts.get("wings", [])
			var f := 12.0 if v._acting else 5.0
			for k in wings.size():
				var w: Node3D = wings[k]
				var s := -1.0 if k == 0 else 1.0
				w.rotation.z = s * sin(t * f) * 0.45
			var iris: Node3D = v.parts.get("iris")
			if iris:
				iris.position.x = sin(t * 0.7) * 0.018
				iris.position.y = -0.004 + cos(t * 1.1) * 0.008
			var rune: Node3D = v.parts.get("rune")
			if rune and not v._acting:
				rune.scale = Vector3.ONE * (1.0 + 0.08 * sin(t * 3.0))
		"cauldron":
			var stir: Node3D = v.parts.get("stir")
			if stir and not v._acting:
				stir.rotation.y = sin(t * 1.2) * 0.6
			var bubbles: Array = v.parts.get("bubbles", [])
			for k in bubbles.size():
				var b: Node3D = bubbles[k]
				var ph := fmod(t * 0.9 + k * 0.37, 1.0)
				b.scale = Vector3.ONE * (ph * 1.1 if ph < 0.9 else 0.01)


# ======================================================================= acts

## The per-pet action for a pet_acted effect. `target` is the (primary) world point or
## Vector3.INF; opts: targets (Array of world points), die_idx, face, color.
static func act(v: PetView, effect: String, target: Vector3, opts: Dictionary) -> void:
	match v.pet_id:
		"pebble_golem":
			await _act_pebble(v, effect)
		"frost_mote":
			await _act_frost(v, target)
		"wick":
			await _act_wick(v, target, opts)
		"tinker_gear":
			await _act_tinker(v, opts)
		"grimoire":
			await _act_grimoire(v)
		"cauldron":
			await _act_cauldron(v, opts)


## Wind-up, slam, then a shield bubble and the thorns stabbing out.
static func _act_pebble(v: PetView, effect: String) -> void:
	v._acting = true
	var fists: Array = v.parts.get("fists", [])
	var sp := v.speed
	var t := v.create_tween().set_parallel()
	for f in fists:
		t.tween_property(f, "position:y", 0.22, 0.16 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(v.body, "position:y", 0.12, 0.16 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	var t2 := v.create_tween().set_parallel()
	for f in fists:
		t2.tween_property(f, "position:y", -0.26, 0.08 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t2.tween_property(v.body, "position:y", -0.12, 0.08 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t2.finished
	var world := _world(v)
	var ground := v.global_position + Vector3.UP * 0.06
	Fx.shockwave(world, ground, Color(0.85, 0.75, 0.6), 1.3, 0.45)
	Fx.burst(world, ground + Vector3.UP * 0.1, {"amount": 14, "lifetime": 0.55, "speed": Vector2(1.0, 2.2), "spread": 70.0,
		"gravity": Vector3(0, -6.0, 0), "size": 0.14, "color": Color(0.7, 0.64, 0.58), "tex": "hard", "additive": false})
	v.squash(0.3)
	var t3 := v.create_tween().set_parallel()
	for f in fists:
		t3.tween_property(f, "position:y", -0.1, 0.25 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t3.tween_property(v.body, "position:y", 0.0, 0.25 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# the shield bubble and the thorns
	Fx.block_flash(world, v.body_position(), 0.62 * v.scale.x)
	var big := 2.4 if effect == "thorns" else 1.8
	for th in v.parts.get("thorns", []):
		var n: Node3D = th
		var tt := n.create_tween()
		tt.tween_property(n, "scale", Vector3.ONE * big, 0.1 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tt.tween_interval(0.35 / sp)
		tt.tween_property(n, "scale", Vector3.ONE, 0.25 / sp).set_trans(Tween.TRANS_SINE)
	Fx.burst(world, v.body_position(), {"amount": 16 if effect == "thorns" else 8, "lifetime": 0.45, "speed": Vector2(2.0, 3.5),
		"gravity": Vector3.ZERO, "damping": 4.0, "size": 0.2, "color": Color(1.0, 0.72, 0.4), "tex": "spark"})
	await _wait(v, 0.2)
	v._acting = false


## A frost beam to the target, then an ice block closes around it.
static func _act_frost(v: PetView, target: Vector3) -> void:
	var sp := v.speed
	var fl: Node3D = v.parts.get("flake")
	v.hop(0.15)
	if fl:
		var t := fl.create_tween()
		t.tween_property(fl, "rotation:z", fl.rotation.z + TAU * 1.5, 0.45 / sp).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var world := _world(v)
	var from := v.body_position()
	Fx.burst(world, from, {"amount": 14, "lifetime": 0.4, "speed": Vector2(0.4, 1.0), "gravity": Vector3.ZERO,
		"radius": 0.35, "size": 0.18, "color": ICE, "tex": "spark"})
	await _wait(v, 0.18)
	if target == Vector3.INF:
		target = from + v.body.global_basis.z.normalized() * 1.5
	# the beam: a glowing cylinder stretched from the pet to the target
	var beam := MeshInstance3D.new()
	beam.mesh = _cyl(0.09, 0.09, 1.0, 10)
	var bm := Props.glow_material(Color(0.7, 0.92, 1.0), true, 2.2)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(beam)
	var d := target - from
	beam.global_position = from + d * 0.5
	beam.look_at(target, Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	beam.scale = Vector3(0.2, d.length(), 0.2)
	_mi(beam, _cyl(0.035, 0.035, 1.0, 8), Props.glow_material(Color(1, 1, 1), true, 2.0))
	# frost motes streaming along it
	for k in 5:
		Fx.burst(world, from.lerp(target, (k + 0.5) / 5.0), {"amount": 5, "lifetime": 0.4, "speed": Vector2(0.2, 0.8),
			"gravity": Vector3.ZERO, "size": 0.18, "color": ICE, "tex": "spark"})
	var bt := beam.create_tween()
	bt.tween_property(beam, "scale:x", 1.3, 0.08 / sp)
	bt.parallel().tween_property(beam, "scale:z", 1.3, 0.08 / sp)
	bt.tween_interval(0.14 / sp)
	bt.tween_property(beam, "scale:x", 0.01, 0.16 / sp)
	bt.parallel().tween_property(beam, "scale:z", 0.01, 0.16 / sp)
	bt.tween_callback(beam.queue_free)
	await _wait(v, 0.1)
	encase(world, target, sp)
	await _wait(v, 0.25)


## An ice block that forms around a world point (body height), holds, then shatters.
static func encase(world: Node3D, at: Vector3, sp := 1.0) -> void:
	var root := Node3D.new()
	world.add_child(root)
	var ground := at - Vector3.UP * 0.9
	root.global_position = ground
	var ice := _glassy(Color(0.72, 0.9, 1.0), Color(0.25, 0.55, 0.9), 0.5, 0.55)
	ice.cull_mode = BaseMaterial3D.CULL_DISABLED
	ice.rim = 1.0
	var block := _mi(root, _box(Vector3(1.0, 1.5, 1.0)), ice, Vector3(0, 0.75, 0))
	# a few crystal shards around the base
	var shard := _glassy(Color(0.85, 0.96, 1.0), Color(0.4, 0.75, 1.0), 0.8, 0.9)
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		var c := _mi(root, _cyl(0.0, 0.1, 0.45, 5), shard, Vector3(cos(a) * 0.55, 0.18, sin(a) * 0.55))
		c.rotation = Vector3(sin(a) * 0.5, 0.0, -cos(a) * 0.5)
	root.scale = Vector3(0.2, 0.05, 0.2)
	Fx.status_burst(world, at, "frozen")
	var t := root.create_tween()
	t.tween_property(root, "scale", Vector3.ONE, 0.18 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.75 / sp)
	t.tween_callback(func() -> void:
		Fx.burst(world, at, {"amount": 22, "lifetime": 0.6, "speed": Vector2(1.5, 3.5), "gravity": Vector3(0, -7.0, 0),
			"size": 0.2, "color": Color(0.85, 0.95, 1.0), "tex": "hard", "additive": false}))
	t.tween_property(root, "scale", Vector3(1.15, 1.05, 1.15), 0.06 / sp)
	t.tween_property(block.material_override, "albedo_color:a", 0.0, 0.14 / sp)
	t.parallel().tween_property(root, "scale", Vector3(1.3, 0.2, 1.3), 0.14 / sp)
	t.tween_callback(root.queue_free)


## The flame puffs up, then a wave of fire rolls over every target.
static func _act_wick(v: PetView, target: Vector3, opts: Dictionary) -> void:
	var sp := v.speed
	v._acting = true
	var fl: Node3D = v.parts.get("flame")
	var t := v.create_tween()
	if fl:
		t.tween_property(fl, "scale", Vector3(1.5, 1.8, 1.5), 0.16 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	v.hop(0.25)
	var world := _world(v)
	var from := v.body_position() + Vector3.UP * 0.2
	Fx.burst(world, from, {"amount": 18, "lifetime": 0.5, "speed": Vector2(0.8, 2.0), "gravity": Vector3(0, 2.0, 0),
		"size": 0.22, "color": FLAME, "tex": "flame"})
	v.light.light_energy = 4.0
	await _wait(v, 0.18)
	var targets: Array = opts.get("targets", [])
	if targets.is_empty():
		targets = [target if target != Vector3.INF else from + v.body.global_basis.z.normalized() * 1.5]
	for i in targets.size():
		var to: Vector3 = targets[i]
		_fire_wave(world, from, to, sp, 0.05 * i)
	if fl:
		var t2 := v.create_tween()
		t2.tween_property(fl, "scale", Vector3.ONE, 0.3 / sp).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await _wait(v, 0.32)
	v._acting = false


## A rolling ball of fire from -> to that bursts into flames around the target.
static func _fire_wave(world: Node3D, from: Vector3, to: Vector3, sp: float, delay: float) -> void:
	if delay > 0.0:
		await world.get_tree().create_timer(delay / sp).timeout
	if not is_instance_valid(world):
		return
	# a fireball (orange, not the white-hot generic projectile) with a flame trail
	var ball := Node3D.new()
	world.add_child(ball)
	ball.global_position = from
	_mi(ball, _sphere(0.13, 14, 8), Props.glow_material(Color(1.0, 0.45, 0.1), false, 1.2))
	_mi(ball, _sphere(0.08, 12, 6), Props.glow_material(FLAME_CORE, false, 1.3), Vector3(0, 0, 0))
	var trail := Fx.burst(ball, Vector3.ZERO, {"amount": 20, "lifetime": 0.3, "speed": Vector2(0.1, 0.4), "gravity": Vector3(0, 1.0, 0),
		"size": 0.3, "colors": PackedColorArray([FLAME_CORE, FLAME, Color(0.9, 0.2, 0.05, 0.0)]), "tex": "flame",
		"explosiveness": 0.0})
	trail.one_shot = false
	var t := ball.create_tween()
	t.tween_method(func(k: float) -> void:
		if is_instance_valid(ball):
			ball.global_position = from.lerp(to, k) + Vector3.UP * (0.9 * k * (1.0 - k)), 0.0, 1.0, 0.28 / sp) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	ball.queue_free()
	if not is_instance_valid(world):
		return
	var ground := to - Vector3.UP * 0.85
	Fx.shockwave(world, ground, FLAME, 1.3, 0.45)
	Fx.burst(world, ground + Vector3.UP * 0.15, {"amount": 34, "lifetime": 0.8, "speed": Vector2(0.8, 2.6), "spread": 25.0,
		"gravity": Vector3(0, 1.5, 0), "radius": 0.45, "size": 0.55, "colors": PackedColorArray([Color(1.0, 0.62, 0.15),
		Color(0.95, 0.3, 0.04), Color(0.6, 0.1, 0.02, 0.0)]), "tex": "flame", "explosiveness": 0.75})
	Fx.hit_sparks(world, to, FLAME, 14)
	Fx.status_burst(world, to, "ember")


## Winds up (cog whirs, sparks), hops and dives off toward the tray; fires `fixed_die`.
static func _act_tinker(v: PetView, opts: Dictionary) -> void:
	var sp := v.speed
	v._acting = true
	var world := _world(v)
	Fx.burst(world, v.body_position() + Vector3.UP * 0.2, {"amount": 12, "lifetime": 0.4, "speed": Vector2(1.5, 3.0),
		"gravity": Vector3(0, -4.0, 0), "size": 0.16, "color": Color(1.0, 0.85, 0.4), "tex": "spark"})
	v.squash(0.25)
	await _wait(v, 0.22)
	# the hop: up, a flip, and down past the ground (toward the tray)
	var t := v.create_tween()
	t.tween_property(v.body, "position:y", 0.55, 0.18 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(v.model, "rotation:x", -TAU, 0.3 / sp).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(v.body, "position:y", -0.4, 0.14 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(v.body, "scale", Vector3.ONE * v._scale * 0.2, 0.14 / sp)
	await t.finished
	v.model.rotation.x = 0.0
	v.fixed_die.emit(int(opts.get("die_idx", -1)), int(opts.get("face", 0)))
	# pops back in beside its spot
	var t2 := v.create_tween()
	t2.tween_interval(0.25 / sp)
	t2.tween_property(v.body, "position:y", 0.0, 0.25 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.parallel().tween_property(v.body, "scale", Vector3.ONE * v._scale, 0.25 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_callback(func() -> void: v._acting = false)


## Pages flutter (flying paper), then the rune sigil flashes big.
static func _act_grimoire(v: PetView) -> void:
	var sp := v.speed
	v._acting = true
	var world := _world(v)
	v.hop(0.2)
	Fx.burst(world, v.body_position(), {"amount": 10, "lifetime": 0.7, "speed": Vector2(0.8, 1.8), "spread": 80.0,
		"gravity": Vector3(0, -1.0, 0), "size": 0.14, "color": Color(1.0, 0.97, 0.88), "tex": "rounded", "additive": false,
		"damping": 2.0})
	await _wait(v, 0.3)
	var rune: Node3D = v.parts.get("rune")
	if rune:
		var t := rune.create_tween()
		t.tween_property(rune, "scale", Vector3.ONE * 2.2, 0.12 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(rune, "scale", Vector3.ONE, 0.3 / sp)
	# the big sigil: a ring with a star, in front of the book, facing the camera
	var sig := Node3D.new()
	v.float_root.add_child(sig)
	sig.position = Vector3(0, 0.05, 0.1)
	sig.rotation.y = v.body.rotation.y
	var col := Color(0.8, 0.55, 1.0)
	_mi(sig, _torus(0.3, 0.34), Props.glow_material(col, true, 2.0), Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	_mi(sig, _torus(0.2, 0.22), Props.glow_material(col, true, 1.6), Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	var star := MeshInstance3D.new()
	star.mesh = Props.quad(0.7)
	var sm := Props.glow_material(Color(1.0, 0.85, 1.0), true, 2.0)
	sm.albedo_texture = Props.particle_texture("spark")
	star.material_override = sm
	sig.add_child(star)
	sig.scale = Vector3.ONE * 0.2
	var t2 := sig.create_tween()
	t2.tween_property(sig, "scale", Vector3.ONE * 1.1, 0.16 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.parallel().tween_property(sig, "rotation:z", 0.8, 0.5 / sp)
	t2.tween_property(sig, "scale", Vector3.ONE * 1.5, 0.3 / sp)
	t2.parallel().tween_method(func(a: float) -> void:
		for c in sig.get_children():
			var mm := (c as MeshInstance3D).material_override as StandardMaterial3D
			mm.albedo_color.a = a, 1.0, 0.0, 0.3 / sp)
	t2.tween_callback(sig.queue_free)
	Fx.burst(world, v.body_position(), {"amount": 16, "lifetime": 0.6, "speed": Vector2(1.0, 2.4), "gravity": Vector3.ZERO,
		"damping": 2.0, "size": 0.2, "color": col, "tex": "spark"})
	await _wait(v, 0.25)
	v._acting = false


## Stirs (the ladle goes round twice, bubbles boil), then a potion bottle pops out.
static func _act_cauldron(v: PetView, opts: Dictionary) -> void:
	var sp := v.speed
	v._acting = true
	var world := _world(v)
	var stir: Node3D = v.parts.get("stir")
	if stir:
		var t := stir.create_tween()
		t.tween_property(stir, "rotation:y", stir.rotation.y + TAU * 2.0, 0.5 / sp).set_trans(Tween.TRANS_SINE)
	var body := v.body
	var bt := body.create_tween()
	for k in 4:
		bt.tween_property(body, "rotation:z", 0.12 if k % 2 == 0 else -0.12, 0.06 / sp)
	bt.tween_property(body, "rotation:z", 0.0, 0.06 / sp)
	Fx.burst(world, v.body_position() + Vector3.UP * 0.15, {"amount": 14, "lifetime": 0.6, "speed": Vector2(0.4, 1.2),
		"spread": 30.0, "gravity": Vector3(0, 0.8, 0), "radius": 0.15, "size": 0.14, "color": Color(1.0, 0.7, 0.9),
		"tex": "ring", "additive": false})
	await _wait(v, 0.45)
	# pop!
	var col: Color = opts.get("color", BREW)
	var b := Props.inst(Props.DUN + "bottle_A_labeled_green.gltf", 0.05, false)
	Props.tint(b, col, 0.75, col * 0.35)
	world.add_child(b)
	var at := v.body_position() + Vector3.UP * 0.1
	b.global_position = at
	v.squash(0.3)
	Fx.burst(world, at + Vector3.UP * 0.1, {"amount": 18, "lifetime": 0.5, "speed": Vector2(1.2, 2.6), "spread": 40.0,
		"gravity": Vector3(0, -4.0, 0), "size": 0.16, "color": col, "tex": "dot"})
	var s := v.scale.x
	var t2 := b.create_tween()
	t2.tween_property(b, "scale", Vector3.ONE * 0.32 * s, 0.14 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.parallel().tween_property(b, "global_position", at + Vector3.UP * 0.7 * s, 0.3 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t2.parallel().tween_property(b, "rotation:z", TAU, 0.3 / sp)
	t2.tween_interval(0.12 / sp)
	t2.tween_property(b, "scale", Vector3.ONE * 0.01, 0.14 / sp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t2.tween_callback(b.queue_free)
	await _wait(v, 0.3)
	v._acting = false
