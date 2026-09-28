class_name TileStyle
extends RefCounted
## Tile colours and the small 3D prop that identifies each tile type.

const TYPES := ["start", "forge", "treasury", "portal", "enemy", "elite", "chest", "event", "campfire",
	"trap", "empty"]

## Inset top colour per type (sRGB).
const COLORS := {
	"start": Color(0.98, 0.84, 0.46),
	"forge": Color(0.95, 0.5, 0.22),
	"treasury": Color(1.0, 0.76, 0.18),
	"portal": Color(0.62, 0.4, 0.98),
	"enemy": Color(0.9, 0.26, 0.24),
	"elite": Color(0.66, 0.1, 0.22),
	"chest": Color(0.28, 0.6, 0.98),
	"event": Color(0.24, 0.8, 0.78),
	"campfire": Color(0.46, 0.82, 0.3),
	"trap": Color(0.5, 0.44, 0.52),
	"empty": Color(0.7, 0.66, 0.6),
}

## Plinth (base) colour per act.
const BASE := {1: Color(0.46, 0.42, 0.42), 2: Color(0.42, 0.34, 0.3), 3: Color(0.34, 0.33, 0.42)}


static func color(type: String) -> Color:
	return COLORS.get(type, COLORS["empty"])


static func glyph(type: String) -> String:
	match type:
		"event":
			return "?"
	return ""


## Builds the identifying prop for a tile type. Props sit around y = 0 (the tile top) and
## fit inside ~1.4 x 1.4. Enemy figures are not included (BoardView adds Characters).
static func make_prop(type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Prop_" + type
	match type:
		"start":
			var f := Props.put(root, Props.BGB + "flag_A_yellow.gltf", Vector3(-0.42, 0, -0.42), 30.0, 0.85)
			f.name = "Flag"
			var f2 := Props.put(root, Props.BGB + "flag_B_red.gltf", Vector3(0.45, 0, -0.45), -20.0, 0.6)
			f2.name = "Flag2"
		"forge":
			Props.put(root, Props.TOOLS + "anvil.gltf", Vector3(0.0, 0, -0.35), 15.0, 0.62)
			Props.put(root, Props.TOOLS + "hammer.gltf", Vector3(0.45, 0.02, 0.2), 80.0, 0.5)
			var spark := Biome.flame(root, Vector3(0.0, 0.55, -0.35), Color(1.0, 0.6, 0.2), 0.14, 5)
			spark.name = "Sparks"
		"treasury":
			Props.put(root, Props.DUN + "coin_stack_large.gltf", Vector3(-0.1, 0, -0.3), 20.0, 0.55)
			Props.put(root, Props.DUN + "coin_stack_small.gltf", Vector3(0.5, 0, 0.2), -40.0, 0.5)
			Props.put(root, Props.DUN + "coin.gltf", Vector3(-0.5, 0, 0.35), 0.0, 0.8)
		"portal":
			var arch := Props.put(root, Props.HAL + "arch.gltf", Vector3(0, 0, -0.25), 0.0, 0.34)
			arch.name = "Arch"
			var swirl := Fx.portal_swirl(root, Vector3(0, 0.72, -0.25), 0.62, false)
			swirl.name = "Swirl"
		"chest":
			Props.put(root, Props.DUN + "chest.gltf", Vector3(0, 0, -0.2), -12.0, 0.5)
		"event":
			var stone := Props.put(root, Props.HAL + "shrine.gltf", Vector3(-0.4, 0, -0.4), 20.0, 0.36)
			stone.name = "Shrine"
			root.add_child(_question_mark())
		"campfire":
			root.add_child(_campfire())
		"trap":
			var spikes := Props.put(root, Props.DUN + "floor_tile_big_spikes.gltf", Vector3(0, -0.03, 0), 0.0, 0.34)
			spikes.scale = Vector3(0.36, 0.3, 0.36)
		"enemy":
			pass
		"elite":
			pass
	Props.set_shadows(root, true)
	return root


## A chunky gold "?" that bobs and turns (event tiles).
static func _question_mark() -> Node3D:
	var n := Node3D.new()
	n.name = "Glyph"
	var tm := TextMesh.new()
	tm.text = "?"
	tm.font = Props.font(true)
	tm.font_size = 64
	tm.pixel_size = 0.02
	tm.depth = 0.2
	tm.curve_step = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.82, 0.3)
	m.metallic = 0.5
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.15)
	m.emission_energy_multiplier = 0.5
	mi.material_override = m
	n.add_child(mi)
	n.position = Vector3(0.15, 0.95, 0.05)
	var t := n.create_tween().set_loops()
	t.tween_property(n, "position:y", 1.1, 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:y", 0.95, 1.1).set_trans(Tween.TRANS_SINE)
	mi.rotation.y = deg_to_rad(-25.0)
	var r := mi.create_tween().set_loops()
	r.tween_property(mi, "rotation:y", deg_to_rad(25.0), 1.6).set_trans(Tween.TRANS_SINE)
	r.tween_property(mi, "rotation:y", deg_to_rad(-25.0), 1.6).set_trans(Tween.TRANS_SINE)
	return n


## Stones, crossed logs, flame particles and a warm light.
static func _campfire() -> Node3D:
	var n := Node3D.new()
	n.name = "Campfire"
	var stone_mat := Props.flat_material(Color(0.5, 0.48, 0.5))
	for i in 8:
		var a := TAU * i / 8.0
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.18
		sm.radial_segments = 6
		sm.rings = 3
		s.mesh = sm
		s.material_override = stone_mat
		s.position = Vector3(cos(a) * 0.42, 0.06, sin(a) * 0.42)
		s.rotation.y = a
		n.add_child(s)
	var log_mat := Props.flat_material(Color(0.45, 0.27, 0.16))
	for i in 3:
		var l := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.08
		cm.height = 0.7
		cm.radial_segments = 6
		l.mesh = cm
		l.material_override = log_mat
		l.rotation = Vector3(deg_to_rad(62.0), TAU * i / 3.0, 0.0)
		l.position = Vector3(0, 0.2, 0)
		n.add_child(l)
	var ember := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.2
	em.height = 0.16
	ember.mesh = em
	ember.material_override = Props.glow_material(Color(1.0, 0.45, 0.1), false, 2.0)
	ember.position = Vector3(0, 0.06, 0)
	n.add_child(ember)
	Biome.flame(n, Vector3(0, 0.25, 0), Color(1.0, 0.5, 0.15), 0.5, 14)
	Biome.flicker_light(n, Vector3(0, 0.8, 0), Color(1.0, 0.55, 0.2), 1.4, 3.2)
	return n
