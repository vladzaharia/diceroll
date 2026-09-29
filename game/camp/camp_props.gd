class_name CampProps
extends RefCounted
## Small static builders for the Camp: optional KayKit props (EXTRA packs may be missing on a
## machine, so every EXTRA path is checked), faceted boxes and planks, NPC characters on the
## shared rigs, pet placeholders and particle bursts.

const FOREST := "res://assets/kaykit/forest/color%d/%s_Color%d.gltf"
const RES := "res://assets/kaykit/resources/"
const WX := "res://assets/kaykit/weapons_x/"
const ADX := "res://assets/kaykit/adventurers_x/"
const RX := "res://assets/kaykit/resources_x/"
const DX := "res://assets/kaykit/dungeon_x/"
const TX := "res://assets/kaykit/tools_x/"
const MM := "res://assets/kaykit/mystery/"
## Optional factory for real pet models (WP-E3's PetView): func(id: String, level: int) -> Node3D.
## When unset (or it returns null) a KayKit-prop placeholder stands in.
static var pet_factory: Callable


## Instances a prop if its file exists, else returns null.
static func opt(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	return Props.put(parent, path, pos, yaw, scale)


static func forest(parent: Node3D, name: String, color: int, pos: Vector3, yaw: float, scale: float) -> Node3D:
	return opt(parent, FOREST % [color, name, color], pos, yaw, scale)


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = size
	mi.mesh = BiomeBlocks.faceted(bx, color, 0.0, int(absf(pos.x) * 10.0 + absf(pos.z) * 7.0 + 3.0))
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## A plank deck.
static func planks(parent: Node3D, size: Vector2, color: Color, broken := false) -> void:
	var n := int(ceil(size.x / 0.34))
	for i in n:
		if broken and (i * 7) % 5 == 1:
			continue
		var c := color.lightened(0.06 * float(i % 3) - 0.04)
		var len := size.y * (0.55 + 0.1 * float(i % 3) if broken else 1.0)
		var pl := box(parent, Vector3(0.32, 0.08, len), Vector3(-size.x * 0.5 + 0.17 + i * 0.34, 0.04, (size.y - len) * 0.5 * (1.0 if i % 2 == 0 else -1.0)),
			c, Vector3(0, 0, (4.0 if i % 2 == 0 else -3.0) if broken else 0.0))
		pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func post(parent: Node3D, pos: Vector3, h: float, color := Color(0.44, 0.29, 0.18), w := 0.12) -> MeshInstance3D:
	return box(parent, Vector3(w, h, w), pos + Vector3.UP * h * 0.5, color)


## A class / keeper character: the Character.MODELS id when known, else an Adventurers EXTRA
## GLB of that name (Druid, Engineer...), else the mannequin. Null only if nothing loads.
static func npc(model: String, gear: Dictionary = {}, anim := "idle") -> Character:
	if Character.MODELS.has(model):
		var ch := Character.create(model)
		ch.play(anim, 0.0)
		return ch
	var glb := ADX + "characters/" + model.capitalize().replace(" ", "_") + ".glb"
	for cand in [glb, ADX + "characters/" + model + ".glb"]:
		if ResourceLoader.exists(cand):
			return glb_character(cand, "large" if model.to_lower().ends_with("large") else "medium", gear, anim)
	var m := Character.create("mannequin")
	m.play(anim, 0.0)
	return m


## A character from any GLB on the KayKit rigs (the Adventurers EXTRA keepers).
static func glb_character(path: String, rig: String, gear: Dictionary, anim: String) -> Character:
	if not ResourceLoader.exists(path):
		return null
	var c := Character.new()
	c.model_id = path.get_file().get_basename()
	c._rig = rig
	c._attack_clip = Character.ATTACKS["large" if rig == "large" else "melee_1h"]
	c.model = (load(path) as PackedScene).instantiate()
	c.add_child(c.model)
	c.skeleton = c.model.find_child("Skeleton3D", true, false)
	c.anim_player = AnimationPlayer.new()
	c.anim_player.name = "AnimationPlayer"
	c.add_child(c.anim_player)
	c.anim_player.root_node = c.anim_player.get_path_to(c.model)
	c.anim_player.add_animation_library("", Character._library_for(rig, c.skeleton, c.model.get_path_to(c.skeleton)))
	c.anim_player.playback_default_blend_time = 0.2
	for slot in gear:
		if ResourceLoader.exists(String(gear[slot])):
			c.attach(String(slot), String(gear[slot]))
	c.play(anim, 0.0)
	c.anim_player.seek(float(hash(path) % 97) / 97.0 * 0.8, true)
	return c


## Replays a one-shot clip every `every` seconds (hammering, sparring, cheering).
static func loop_clip(ch: Character, clip: String, every: float, back := "idle") -> void:
	if ch == null:
		return
	var t := Timer.new()
	t.wait_time = every
	t.autostart = true
	ch.add_child(t)
	t.timeout.connect(func() -> void:
		if is_instance_valid(ch) and ch.is_visible_in_tree() and ch.has_anim(clip):
			ch.play_once(clip, back))


## A pet familiar: WP-E3's model when available, else a KayKit prop with a soft light.
static func pet(id: String, level := 1) -> Node3D:
	if pet_factory.is_valid():
		var m: Node3D = pet_factory.call(id, level)
		if m != null:
			return m
	var n := Node3D.new()
	n.name = "Pet_" + id
	var H := Props.HAL
	var c := Color(1.0, 0.8, 0.4)
	match String(PetDefs.DEFS[id].model) if PetDefs.has(id) else "":
		"pumpkin":
			Props.put(n, H + "pumpkin_orange_jackolantern.gltf", Vector3.ZERO, 200.0, 0.62)
			c = Color(1.0, 0.55, 0.2)
		"skull":
			Props.put(n, H + "skull.gltf", Vector3.ZERO, 180.0, 0.9)
			c = Color(0.7, 0.9, 1.0)
		"lantern":
			Props.put(n, H + "lantern_standing.gltf", Vector3.ZERO, 0.0, 0.8)
			c = Color(0.5, 1.0, 0.85)
		"crystal":
			BiomeBlocks.crystal_cluster(n, Vector3.ZERO, 0.32, 4, 7)
			c = Color(0.6, 0.85, 1.0)
		"die":
			Props.put(n, Props.BGB + "D6_A_blue.gltf", Vector3(0, 0.35, 0), 20.0, 1.1)
			c = Color(0.5, 0.7, 1.0)
		"chest":
			Props.put(n, Props.DUN + "chest.gltf", Vector3.ZERO, 200.0, 0.45)
			c = Color(1.0, 0.8, 0.3)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 0.9
	l.omni_range = 1.8
	l.position = Vector3(0, 0.5, 0.3)
	n.add_child(l)
	return n


## A one-shot burst of dust and sparkles (build-out moments).
static func burst(parent: Node3D, pos: Vector3, color := Color(1.0, 0.85, 0.5), size := 1.0) -> void:
	for kind in ["dust", "spark"]:
		var p := GPUParticles3D.new()
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = 26 if kind == "dust" else 18
		p.lifetime = 1.3 if kind == "dust" else 1.0
		p.position = pos + Vector3.UP * 0.4
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.9 * size
		pm.direction = Vector3.UP
		pm.spread = 70.0 if kind == "dust" else 180.0
		pm.initial_velocity_min = 0.6 * size
		pm.initial_velocity_max = (1.6 if kind == "dust" else 3.0) * size
		pm.gravity = Vector3(0, -0.6 if kind == "dust" else -2.0, 0)
		pm.damping_min = 0.8
		pm.damping_max = 1.4
		pm.scale_min = 0.6
		pm.scale_max = 1.4
		var grad := Gradient.new()
		var col: Color = Color(0.72, 0.62, 0.5, 0.7) if kind == "dust" else color
		grad.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
		grad.colors = PackedColorArray([Color(col, 0.0), col, Color(col, col.a * 0.6), Color(col, 0.0)])
		var gt := GradientTexture1D.new()
		gt.gradient = grad
		pm.color_ramp = gt
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.5) * size if kind == "dust" else Vector2(0.16, 0.16) * size
		q.material = Props.particle_material("dot" if kind == "dust" else "spark", kind != "dust")
		p.draw_pass_1 = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(p)
		p.emitting = true
		p.finished.connect(p.queue_free)
