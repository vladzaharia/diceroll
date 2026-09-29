class_name EnemyLooks
extends RefCounted
## Enemy id -> dressed, tinted Character (spec §9) plus the clips it uses.
##
##   var ch := EnemyLooks.create("skeleton_warrior")          # full: lights, particles, aura
##   var fig := EnemyLooks.create("ember_imp", false)          # lite: board previews
##   ch.play(EnemyLooks.clip("skeleton_warrior", "idle"))
##   EnemyLooks.retint(ch, id, flash_emission)                 # hit flash, keeps part tints
##   EnemyLooks.shatter(ch)                                     # Magma Golem phase 2
##
## Looks follow docs/plans/balance.md "Presentation ids and look hints". Extras are built
## from simple procedural pieces on bone sockets (skulls, crowns, horns, thorns, fur, rock
## shell, glowing eyes) so every id reads at board-preview size.

const ADV := "res://assets/kaykit/adventurers/weapons/"
const WPN := "res://assets/kaykit/weapons/"
const BONE := Color(0.94, 0.9, 0.8)
const GHOST_SHADER := preload("res://game/actors/ghost.gdshader")

## id -> {model, tint, strength, emission, scale, gear{slot: path}, clips{role: clip}, extras[],
## parts{mesh-name fragment: [tint, strength]}, cracks: Color, aura: Color, eyes: Color, ...}
const DEFS := {
	"skeleton_minion": {"model": "mannequin", "tint": BONE, "strength": 0.92, "scale": 1.0, "skeleton": true,
		"gear": {}, "clips": {"attack": "Melee_Unarmed_Attack_Punch_A"}},
	"skeleton_warrior": {"model": "mannequin", "tint": Color(0.86, 0.84, 0.78), "strength": 0.9, "scale": 1.05,
		"skeleton": true, "gear": {"handslot.r": ADV + "sword_1handed.gltf", "handslot.l": ADV + "shield_round.gltf"},
		"clips": {"attack": "Melee_1H_Attack_Chop"}},
	"skeleton_archer": {"model": "mannequin", "tint": Color(0.9, 0.87, 0.74), "strength": 0.9, "scale": 1.0,
		"skeleton": true, "gear": {"handslot.r": ADV + "crossbow_1handed.gltf"},
		"clips": {"attack": "Ranged_1H_Shoot"}},
	"cultist": {"model": "mage", "tint": Color(0.3, 0.14, 0.36), "strength": 0.72, "scale": 1.0,
		"gear": {}, "clips": {"attack": "Ranged_Magic_Shoot"}},
	"bandit": {"model": "rogue_hooded", "tint": Color(0.5, 0.3, 0.25), "strength": 0.25, "scale": 1.0,
		"gear": {}, "clips": {}},
	"brute": {"model": "mannequin_large", "tint": Color(0.46, 0.56, 0.32), "strength": 0.95, "scale": 1.05,
		"gear": {}, "clips": {}},
	# --- biome regulars -------------------------------------------------------------------------
	"thorn_sprite": {"model": "mannequin", "tint": Color(0.38, 0.64, 0.27), "strength": 0.92, "scale": 0.8,
		"emission": Color(0.01, 0.03, 0.0), "gear": {}, "clips": {"attack": "Melee_Unarmed_Attack_Punch_A"},
		"extras": ["leaf_crown", "leaf_shoulders", "leaf_motes"], "light": Color(0.5, 1.0, 0.4), "eyes": Color(1.0, 0.95, 0.5)},
	"wolf_bandit": {"model": "rogue_hooded", "tint": Color(0.45, 0.31, 0.2), "strength": 0.8, "scale": 1.0,
		"gear": {}, "clips": {}, "extras": ["fur_collar", "wolf_ears"],
		"parts": {"Cape": [Color(0.56, 0.54, 0.54), 0.92], "Head": [Color(0.5, 0.48, 0.47), 0.85],
			"Mask": [Color(0.2, 0.16, 0.14), 0.9]}},
	"hollow_wisp": {"model": "mannequin", "tint": Color(0.45, 1.0, 0.86), "strength": 0.92, "scale": 1.0,
		"gear": {}, "clips": {"attack": "Ranged_Magic_Shoot"}, "ghost": true, "extras": ["float", "wisp_trail"],
		"light": Color(0.4, 1.0, 0.85), "eyes": Color(0.8, 1.0, 0.95)},
	"frost_skeleton": {"model": "mannequin", "tint": Color(0.72, 0.87, 1.0), "strength": 0.92, "scale": 1.05,
		"emission": Color(0.02, 0.05, 0.1), "skeleton": true, "gear": {"handslot.r": ADV + "axe_1handed.gltf"},
		"clips": {"attack": "Melee_1H_Attack_Chop"}, "extras": ["shoulder_ice", "frost_mist"], "eyes": Color(0.5, 0.9, 1.0),
		"skull_tint": Color(0.7, 0.86, 1.0)},
	"ice_archer": {"model": "mannequin", "tint": Color(0.86, 0.94, 1.0), "strength": 0.92, "scale": 1.0,
		"emission": Color(0.03, 0.06, 0.1), "gear": {"handslot.r": ADV + "crossbow_1handed.gltf"},
		"clips": {"attack": "Ranged_1H_Shoot"}, "extras": ["ice_crown", "frost_mist"]},
	"bone_knight": {"model": "knight", "tint": Color(0.9, 0.87, 0.78), "strength": 0.78, "scale": 1.05,
		"emission": Color(0.03, 0.0, 0.05), "gear": {"handslot.r": ADV + "sword_1handed.gltf",
		"handslot.l": ADV + "shield_spikes.gltf"}, "clips": {"attack": "Melee_1H_Attack_Chop"},
		"parts": {"Cape": [Color(0.3, 0.12, 0.42), 0.9]}, "eyes": Color(0.8, 0.45, 1.0)},
	"ember_imp": {"model": "mannequin", "tint": Color(0.2, 0.13, 0.12), "strength": 0.95, "scale": 0.75,
		"emission": Color(0.4, 0.11, 0.02), "cracks": Color(1.0, 0.45, 0.1, 1.0), "gear": {},
		"clips": {"attack": "Melee_Unarmed_Attack_Punch_A"}, "extras": ["horns", "head_flame"],
		"light": Color(1.0, 0.5, 0.15), "eyes": Color(1.0, 0.8, 0.3)},
	"magma_brute": {"model": "mannequin_large", "tint": Color(0.14, 0.12, 0.13), "strength": 0.95, "scale": 1.1,
		"cracks": Color(1.0, 0.42, 0.08, 1.0), "gear": {}, "clips": {}, "extras": ["embers"],
		"light": Color(1.0, 0.45, 0.12), "eyes": Color(1.0, 0.7, 0.2)},
	# --- mini-bosses: ~1.5x an elite, lit by an aura ------------------------------------------------
	"mini_pumpkin_knight": {"model": "knight", "tint": Color(0.22, 0.16, 0.14), "strength": 0.55, "scale": 1.5,
		"emission": Color(0.1, 0.03, 0.0), "gear": {"handslot.r": ADV + "sword_2handed_color.gltf",
		"handslot.l": ADV + "shield_spikes_color.gltf"}, "clips": {"attack": "Melee_2H_Attack_Chop"},
		"pumpkin": true, "pumpkin_scale": 0.8, "aura": Color(1.0, 0.5, 0.12), "miniboss": true},
	"mini_bone_champion": {"model": "knight", "tint": Color(0.93, 0.9, 0.8), "strength": 0.82, "scale": 1.5,
		"emission": Color(0.02, 0.02, 0.04), "gear": {"handslot.r": ADV + "axe_2handed.gltf",
		"handslot.l": ADV + "shield_round.gltf"}, "clips": {"attack": "Melee_2H_Attack_Chop"},
		"parts": {"Cape": [Color(0.24, 0.22, 0.3), 0.9]}, "hide": ["HelmetVisor"],
		"skull_face": "Knight_Head", "eyes": Color(0.55, 0.85, 1.0), "extras": ["bone_pauldrons", "stone_plates"],
		"aura": Color(0.75, 0.85, 1.0), "miniboss": true},
	"mini_grave_mage": {"model": "mage", "tint": Color(0.12, 0.26, 0.2), "strength": 0.82, "scale": 1.5,
		"emission": Color(0.01, 0.06, 0.03), "parts": {"Hat": [Color(0.1, 0.12, 0.12), 0.9], "Cape": [Color(0.2, 0.5, 0.3), 0.85]}, "gear": {"handslot.r": ADV + "staff.gltf", "handslot.l": ADV + "spellbook_open.gltf"},
		"clips": {"attack": "Ranged_Magic_Spellcasting"}, "skull_under_hat": true, "eyes": Color(0.45, 1.0, 0.6),
		"extras": ["hand_flame_green", "grave_candles"], "aura": Color(0.35, 1.0, 0.55), "miniboss": true},
	"mini_frost_warden": {"model": "knight", "tint": Color(0.64, 0.82, 1.0), "strength": 0.85, "scale": 1.5,
		"emission": Color(0.03, 0.07, 0.12), "gear": {"handslot.r": ADV + "sword_2handed_color.gltf"},
		"clips": {"attack": "Melee_2H_Attack_Chop"}, "parts": {"Cape": [Color(0.9, 0.96, 1.0), 0.9]},
		"extras": ["ice_crown", "shoulder_ice", "frost_mist"], "eyes": Color(0.6, 0.95, 1.0),
		"aura": Color(0.55, 0.88, 1.0), "miniboss": true},
	"mini_briar_beast": {"model": "mannequin_large", "tint": Color(0.27, 0.42, 0.19), "strength": 0.95, "scale": 1.4,
		"emission": Color(0.0, 0.0, 0.0), "gear": {}, "clips": {},
		"extras": ["bush_head", "thorns_back", "thorns_front", "leaf_shoulders", "leaf_motes", "bramble_ring"],
		"eyes": Color(1.0, 0.85, 0.3), "aura": Color(0.55, 1.0, 0.35), "miniboss": true},
	"mini_cinder_brute": {"model": "mannequin_large", "tint": Color(0.12, 0.1, 0.1), "strength": 0.95, "scale": 1.4,
		"cracks": Color(1.0, 0.45, 0.1, 1.0), "gear": {"handslot.r": WPN + "hammer_B.gltf"}, "clips": {},
		"extras": ["embers", "shoulder_flames"], "eyes": Color(1.0, 0.75, 0.2), "aura": Color(1.0, 0.45, 0.12),
		"miniboss": true},
	# --- bosses ----------------------------------------------------------------------------------
	"boss_bone_warden": {"model": "knight", "tint": Color(0.93, 0.89, 0.78), "strength": 0.8, "scale": 1.6,
		"emission": Color(0.03, 0.0, 0.05), "gear": {"handslot.r": ADV + "sword_2handed.gltf"},
		"clips": {"attack": "Melee_2H_Attack_Chop"}, "parts": {"Cape": [Color(0.32, 0.1, 0.45), 0.92]},
		"extras": ["bone_pauldrons", "skull_crest"], "eyes": Color(0.85, 0.5, 1.0), "light": Color(0.7, 0.4, 1.0),
		"skull_face": "Knight_Head", "hide": ["HelmetVisor"], "boss": true},
	"boss_hollow_king": {"model": "barbarian", "tint": Color(0.45, 0.3, 0.22), "strength": 0.3, "scale": 1.6,
		"gear": {}, "clips": {}, "boss": true, "pumpkin": true},
	"boss_lich": {"model": "mage", "tint": Color(0.5, 0.28, 0.85), "strength": 0.75, "scale": 1.6,
		"emission": Color(0.12, 0.04, 0.22), "gear": {}, "clips": {"attack": "Ranged_Magic_Spellcasting"},
		"boss": true, "glow": true, "eyes": Color(0.6, 1.0, 0.95)},
	"boss_cinder_king": {"model": "barbarian", "tint": Color(0.2, 0.12, 0.1), "strength": 0.78, "scale": 1.6,
		"emission": Color(0.12, 0.03, 0.0), "cracks": Color(1.0, 0.5, 0.12, 0.8),
		"gear": {"handslot.r": ADV + "axe_2handed.gltf"}, "clips": {"attack": "Melee_2H_Attack_Chop"},
		"hide": ["BearHat"], "extras": ["crown", "head_flame", "shoulder_flames", "embers"], "eyes": Color(1.0, 0.8, 0.3),
		"light": Color(1.0, 0.5, 0.15), "boss": true},
	"boss_magma_golem": {"model": "mannequin_large", "tint": Color(1.0, 0.42, 0.1), "strength": 0.85, "scale": 1.8,
		"emission": Color(0.7, 0.2, 0.02), "cracks": Color(1.0, 0.8, 0.35, 0.8), "gear": {}, "clips": {},
		"extras": ["rock_shell", "embers"], "eyes": Color(1.0, 0.85, 0.4), "eyes_offset": Vector3(0, 0.02, 0.12),
		"hide": ["MannequinLarge_Head"], "light": Color(1.0, 0.45, 0.12),
		"boss": true},
}


static func def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["skeleton_minion"])


static func is_boss(id: String) -> bool:
	return bool(def(id).get("boss", false))


static func is_miniboss(id: String) -> bool:
	return bool(def(id).get("miniboss", false))


## Height of the HUD above the feet, in unit-scale model units (big rigs and crowns are taller).
static func hud_height(id: String) -> float:
	var d := def(id)
	var h := 2.2 * scale_of(id)
	if String(d.model) == "mannequin_large":
		h *= 1.42
	if "crown" in d.get("extras", []) or "skull_crest" in d.get("extras", []) or "bush_head" in d.get("extras", []):
		h += 0.35 * scale_of(id)
	return h


## Scale multiplier relative to a normal unit (bosses 1.6).
static func scale_of(id: String) -> float:
	return float(def(id).get("scale", 1.0))


## Clip for a role: idle | attack | hit | death | spawn.
static func clip(id: String, role: String) -> String:
	var d := def(id)
	var clips: Dictionary = d.get("clips", {})
	if clips.has(role):
		return clips[role]
	var skel := bool(d.get("skeleton", false))
	match role:
		"idle":
			return "skel_idle" if skel else "idle"
		"spawn":
			return "skel_spawn" if skel else "spawn"
		"death":
			return "skel_death" if skel else "death"
		"walk":
			return "skel_walk" if skel else "walk"
	return role


## `full` adds lights, particles and the mini-boss aura (combat); board previews pass false.
static func create(id: String, full := true) -> Character:
	var d := def(id)
	var ch := Character.create(String(d.model), d.gear.is_empty() and not bool(d.get("skeleton", false)))
	ch.name = id.to_pascal_case()
	ch.set_meta("enemy_id", id)
	for slot in d.gear:
		ch.attach(slot, d.gear[slot])
	if bool(d.get("ghost", false)):
		ch.tint_shader = GHOST_SHADER
	var cracks: Color = d.get("cracks", Color(0, 0, 0, 0))
	if cracks.a > 0.0:
		ch.tint_params["crack_color"] = cracks
		ch.tint_params["crack_scale"] = float(d.get("crack_scale", 3.2 if String(d.model) == "mannequin_large" else 4.2))
		# board previews are tiny: fewer, simpler cracks so the figure keeps its silhouette
		ch.tint_params["crack_sparsity"] = 0.45 if full else 0.7
	for n in d.get("hide", []):
		_hide_meshes(ch, String(n))
	retint(ch, id)
	if bool(d.get("skeleton", false)):
		var sk := _skull_head(ch)
		if d.has("skull_tint"):
			if sk:
				Props.tint(sk, d.skull_tint, 0.6, Color(d.skull_tint) * 0.12)
	if bool(d.get("skeleton_head", false)):
		_skull_head(ch, true)
	if bool(d.get("skull_under_hat", false)):
		_skull_under_hat(ch)
	if d.has("skull_face"):
		_hide_meshes(ch, String(d.skull_face))
		var sf := ch.attach("head", "res://assets/kaykit/halloween/skull.gltf")
		if sf:
			sf.scale = Vector3.ONE * 0.86
			sf.position = Vector3(0, 0.02, 0.12)
			Props.tint(sf, Color(0.94, 0.9, 0.8), 0.5)
	if bool(d.get("pumpkin", false)):
		_pumpkin_head(ch, float(d.get("pumpkin_scale", 0.62)))
	if d.has("eyes"):
		_eyes(ch, d.eyes, d.get("eyes_offset", Vector3.ZERO))
	for e in d.get("extras", []):
		_extra(ch, id, String(e), full)
	if full:
		if d.has("aura"):
			_aura(ch, d.aura)
		if d.has("light"):
			var l := OmniLight3D.new()
			l.name = "BodyLight"
			l.light_color = d.light
			l.light_energy = 1.3 if is_boss(id) else 0.9
			l.omni_range = 3.2
			l.position = Vector3(0.0, 1.4, 0.9)
			ch.add_child(l)
		if bool(d.get("glow", false)):
			var l := OmniLight3D.new()
			l.light_color = Color(0.7, 0.4, 1.0)
			l.light_energy = 2.0
			l.omni_range = 3.0
			l.position = Vector3(0.6, 2.0, 0.6)
			ch.add_child(l)
	ch.play(clip(id, "idle"), 0.0)
	return ch


## Re-applies the look's tint (and per-part tints) with an optional emission override (hit
## flash). Use instead of Character.set_tint for enemies.
static func retint(ch: Character, id: String, flash := Color.BLACK) -> void:
	var d := def(id)
	var em: Color = flash if flash != Color.BLACK else d.get("emission", Color.BLACK)
	if ch.has_meta("shattered"):
		em = Color(1.0, 0.35, 0.04) if flash == Color.BLACK else flash
	ch.set_tint(d.tint, float(d.strength), em)
	var parts: Dictionary = d.get("parts", {})
	if parts.is_empty():
		return
	for mi in ch.model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for key in parts:
			if String(m.name).contains(String(key)):
				var pt: Array = parts[key]
				for s in m.mesh.get_surface_count():
					var base: Material = m.get_surface_override_material(s)
					if base is ShaderMaterial:
						var sm := (base as ShaderMaterial).duplicate() as ShaderMaterial
						sm.set_shader_parameter("tint", pt[0])
						sm.set_shader_parameter("strength", float(pt[1]))
						m.set_surface_override_material(s, sm)


# --- sockets & procedural pieces ----------------------------------------------------------------

static func _socket(ch: Character, bone: String) -> Node3D:
	if ch.skeleton.find_bone(bone) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.name = "Socket_" + bone.replace(".", "_")
	ba.bone_name = bone
	ch.skeleton.add_child(ba)
	return ba


static func _hide_meshes(ch: Character, fragment: String) -> void:
	for m in ch.model.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).contains(fragment):
			(m as MeshInstance3D).visible = false


static func _mat(color: Color, emission := Color.BLACK, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 1.5
	return m


static func _blob(parent: Node3D, pos: Vector3, r: float, color: Color, seed := 1, squash := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BiomeBlocks.faceted(BiomeBlocks._sphere(r, 7, 4), color, r * 0.15, seed, color.darkened(0.3), squash)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cone(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Two small glowing eyes on the face (skulls, visors, spirits).
static func _eyes(ch: Character, color: Color, offset := Vector3.ZERO) -> void:
	var head := _socket(ch, "head")
	if head == null:
		return
	head.name = "Eyes"
	var big := ch.model_id == "mannequin_large"
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lightened(0.3)
	var y := 0.42 if not big else 0.36
	var z := 0.4 if not big else 0.36
	var dx := 0.15 if not big else 0.13
	match ch.model_id:
		"knight":
			y = 0.5
			z = 0.44
		"mage":
			y = 0.4
			z = 0.42
		"barbarian":
			y = 0.46
			z = 0.44
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.055
		sm.height = 0.08
		sm.radial_segments = 8
		sm.rings = 4
		e.mesh = sm
		e.material_override = m
		e.position = Vector3(sx * dx, y, z) + offset
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(e)


static func _extra(ch: Character, id: String, kind: String, full: bool) -> void:
	match kind:
		"leaf_crown":
			var h := _socket(ch, "head")
			for i in 6:
				var a := TAU * i / 6.0
				var leaf := _blob(h, Vector3(cos(a) * 0.36, 0.78 + 0.05 * (i % 2), sin(a) * 0.36), 0.16,
					Color(0.36, 0.7, 0.24).lightened(0.08 * (i % 2)), 40 + i, Vector3(1.0, 0.55, 1.0))
				leaf.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
			var bloom := _blob(h, Vector3(0.0, 0.92, 0.1), 0.14, Color(1.0, 0.55, 0.72), 9)
			bloom.name = "Bloom"
			_blob(h, Vector3(0.0, 0.98, 0.14), 0.07, Color(1.0, 0.9, 0.35), 10)
		"leaf_shoulders":
			for b in ["upperarm.l", "upperarm.r"]:
				var s := _socket(ch, b)
				if s:
					_blob(s, Vector3(0, 0.1, 0), 0.26, Color(0.3, 0.56, 0.2), b.length(), Vector3(1.0, 0.7, 1.0))
					_blob(s, Vector3(0.12, 0.22, -0.05), 0.16, Color(0.38, 0.64, 0.24), 3)
		"leaf_motes":
			if full:
				var p := Fx.elite_sparkle(ch, Vector3(0, 0.3, 0), 0.5, 1.6)
				(p.process_material as ParticleProcessMaterial).color = Color(0.6, 1.0, 0.4)
		"fur_collar":
			var c := _socket(ch, "chest")
			var fur := Color(0.6, 0.6, 0.62)
			for i in 9:
				var a := TAU * i / 9.0
				_blob(c, Vector3(cos(a) * 0.3, 0.32 + 0.04 * (i % 2), sin(a) * 0.26 - 0.02), 0.17,
					fur.lightened(0.08 * (i % 3)), 60 + i, Vector3(1.0, 0.8, 1.0))
		"wolf_ears":
			var h := _socket(ch, "head")
			var m := _mat(Color(0.52, 0.5, 0.52))
			for sx in [-1.0, 1.0]:
				_cone(h, Vector3(sx * 0.26, 0.9, 0.0), 0.12, 0.3, m, Vector3(0, 0, -sx * 0.35))
		"float":
			_hide_meshes(ch, "LegLeft")
			_hide_meshes(ch, "LegRight")
			ch.model.position.y = 0.45
			var t := ch.model.create_tween().set_loops()
			t.tween_property(ch.model, "position:y", 0.62, 1.3).set_trans(Tween.TRANS_SINE)
			t.tween_property(ch.model, "position:y", 0.45, 1.3).set_trans(Tween.TRANS_SINE)
		"wisp_trail":
			if full:
				var p := Fx.elite_sparkle(ch, Vector3(0, 0.3, 0), 0.35, 0.8)
				(p.process_material as ParticleProcessMaterial).color = Color(0.5, 1.0, 0.9)
		"shoulder_ice":
			for b in ["upperarm.l", "upperarm.r"]:
				var s := _socket(ch, b)
				if s:
					var cc := BiomeBlocks.crystal_cluster(s, Vector3(0, 0.12, 0), 0.32, 3, b.length() * 3, false)
					cc.rotation.z = 0.3 if b.ends_with("l") else -0.3
		"ice_crown":
			var h := _socket(ch, "head")
			var y := 0.95 if ch.model_id == "knight" else 0.8
			for i in 5:
				var a := TAU * i / 5.0
				var cr := MeshInstance3D.new()
				cr.mesh = BiomeBlocks.crystal_mesh()
				cr.material_override = BiomeBlocks.crystal_material()
				var k := 0.5 if i == 0 else 0.34
				cr.scale = Vector3(k, k * (1.3 if i == 0 else 1.0), k)
				cr.position = Vector3(cos(a) * 0.22, y - 0.1, sin(a) * 0.22) if i > 0 else Vector3(0, y, 0)
				cr.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35) if i > 0 else Vector3.ZERO
				h.add_child(cr)
		"frost_mist":
			if full:
				var p := Fx.elite_sparkle(ch, Vector3(0, 0.1, 0), 0.55, 1.2)
				(p.process_material as ParticleProcessMaterial).color = Color(0.75, 0.92, 1.0)
		"horns":
			var h := _socket(ch, "head")
			var m := _mat(Color(0.12, 0.08, 0.08), Color(0.3, 0.08, 0.0))
			for sx in [-1.0, 1.0]:
				_cone(h, Vector3(sx * 0.3, 0.85, 0.05), 0.14, 0.52, m, Vector3(0.25, 0, -sx * 0.6))
		"head_flame":
			if full:
				var h := _socket(ch, "head")
				Biome.flame(h, Vector3(0, 0.95, 0), Color(1.0, 0.5, 0.12), 0.35, 10)
		"hand_flame_green":
			if full:
				var s := _socket(ch, "handslot.l")
				if s:
					Biome.flame(s, Vector3(0, 0.25, 0), Color(0.4, 1.0, 0.55), 0.3, 8)
		"embers":
			if full:
				var p := Fx.elite_sparkle(ch, Vector3(0, 0.2, 0), 0.6, 2.0)
				(p.process_material as ParticleProcessMaterial).color = Color(1.0, 0.5, 0.15)
		"shoulder_flames":
			for b in ["upperarm.l", "upperarm.r"]:
				var s := _socket(ch, b)
				if s and full:
					Biome.flame(s, Vector3(0, 0.25, 0), Color(1.0, 0.5, 0.12), 0.3, 8)
		"thorns_back":
			var c := _socket(ch, "chest")
			var m := _mat(Color(0.42, 0.28, 0.16))
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in 9:
				var a := lerpf(-1.2, 1.2, float(i) / 8.0)
				var y := 0.25 + 0.3 * float(i % 3)
				_cone(c, Vector3(sin(a) * 0.45, y, -cos(a) * 0.3 - 0.1), 0.07, 0.42, m,
					Vector3(-1.1 + rng.randf() * 0.3, 0, sin(a) * 0.9))
			for b in ["lowerarm.l", "lowerarm.r"]:
				var s := _socket(ch, b)
				if s:
					for k in 2:
						_cone(s, Vector3(0, 0.1 + 0.18 * k, -0.12), 0.05, 0.26, m, Vector3(-1.2, 0, 0))
		"bone_pauldrons":
			for b in ["upperarm.l", "upperarm.r"]:
				var s := _socket(ch, b)
				if s:
					var sk := Props.put(s, Props.HAL + "skull.gltf", Vector3(0, 0.12, 0), 0.0, 0.42)
					sk.rotation.y = PI * (0.5 if b.ends_with("l") else -0.5)
		"skull_crest":
			var h := _socket(ch, "head")
			var sk := Props.put(h, Props.HAL + "skull.gltf", Vector3(0, 1.0, 0.05), 0.0, 0.36)
			sk.name = "Crest"
		"bush_head":
			_hide_meshes(ch, "Head")
			var h := _socket(ch, "head")
			var leaf := Color(0.4, 0.62, 0.24)
			_blob(h, Vector3(0, 0.46, 0.0), 0.62, leaf, 71, Vector3(1.1, 0.95, 1.0))
			for i in 8:
				var a := TAU * i / 8.0
				_blob(h, Vector3(cos(a) * 0.52, 0.6 + 0.14 * (i % 2), sin(a) * 0.44), 0.3,
					leaf.lightened(0.07 * (i % 3)), 80 + i, Vector3(1.0, 0.8, 1.0))
			var m := _mat(Color(0.5, 0.3, 0.14))
			for i in 7:
				var a := lerpf(-2.4, 2.4, float(i) / 6.0)
				_cone(h, Vector3(sin(a) * 0.55, 0.85 + 0.12 * (i % 2), cos(a) * 0.36 - 0.08), 0.09, 0.5, m,
					Vector3(-0.5 * cos(a), 0, sin(a) * 0.9))
			# a dark maw and two glowing eyes peering out of the bush
			var eye := StandardMaterial3D.new()
			eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			eye.albedo_color = Color(1.0, 0.86, 0.3)
			for sx in [-1.0, 1.0]:
				var e := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.075
				sm.height = 0.1
				e.mesh = sm
				e.material_override = eye
				e.position = Vector3(sx * 0.2, 0.5, 0.6)
				h.add_child(e)
		"thorns_front":
			var m := _mat(Color(0.52, 0.32, 0.15))
			for b in ["upperarm.l", "upperarm.r", "upperleg.l", "upperleg.r"]:
				var s := _socket(ch, b)
				if s:
					for k in 3:
						var a := float(k) * 2.1
						_cone(s, Vector3(cos(a) * 0.2, 0.1 + 0.14 * k, sin(a) * 0.2), 0.08, 0.42, m,
							Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2))
			var c := _socket(ch, "chest")
			for k in 5:
				var x := lerpf(-0.36, 0.36, float(k) / 4.0)
				_cone(c, Vector3(x, 0.3 + 0.14 * (k % 2), 0.42), 0.09, 0.44, m, Vector3(1.3, 0, 0))
		"stone_plates":
			pass
		"bramble_ring":
			# Thorns trait: a ring of brambles on the ground around the figure
			var ring := Node3D.new()
			ring.name = "Brambles"
			ch.add_child(ring)
			var m := _mat(Color(0.4, 0.24, 0.12))
			var vine := _mat(Color(0.22, 0.36, 0.14))
			for k in 14:
				var a := TAU * k / 14.0
				var r := 1.15 + 0.08 * float(k % 3)
				_blob(ring, Vector3(cos(a) * r, 0.08, sin(a) * r), 0.16, Color(0.24, 0.38, 0.15).lightened(0.05 * (k % 2)), 120 + k,
					Vector3(1.3, 0.6, 1.0))
				_cone(ring, Vector3(cos(a) * r, 0.2, sin(a) * r), 0.06, 0.36 + 0.12 * float(k % 2), m,
					Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5))
			ring.set_meta("vine", vine)
		"grave_candles":
			if full:
				for k in 3:
					var a := TAU * k / 3.0 + 0.5
					var cd := Props.put(ch, Props.HAL + "candle_triple.gltf", Vector3(cos(a) * 0.9, 0, sin(a) * 0.9), 0.0, 0.5)
					cd.name = "Candle%d" % k
					Biome.flame(cd, Vector3(0, 0.5, 0), Color(0.45, 1.0, 0.55), 0.12, 4)
		"crown":
			_crown(ch)
		"rock_shell":
			_rock_shell(ch)


## A gold crown with glowing ember gems (Cinder King).
static func _crown(ch: Character) -> void:
	var h := _socket(ch, "head")
	h.name = "Crown"
	var gold := _mat(Color(1.0, 0.72, 0.2), Color(0.4, 0.18, 0.0), 0.3)
	gold.metallic = 0.8
	var band := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.36
	cm.height = 0.16
	cm.radial_segments = 10
	cm.rings = 1
	band.mesh = cm
	band.material_override = gold
	band.position = Vector3(0, 0.8, 0)
	h.add_child(band)
	var gem := _mat(Color(1.0, 0.3, 0.05), Color(1.0, 0.35, 0.05))
	for i in 7:
		var a := TAU * i / 7.0
		_cone(h, Vector3(cos(a) * 0.37, 0.98, sin(a) * 0.37), 0.08, 0.26 if i % 2 == 0 else 0.18, gold)
		if i % 2 == 0:
			var g := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.1
			g.mesh = sm
			g.material_override = gem
			g.position = Vector3(cos(a) * 0.4, 0.8, sin(a) * 0.4)
			h.add_child(g)


## Grey faceted rock plates over the Golem's glowing body; each piece is tagged so shatter()
## can throw them off.
static func _rock_shell(ch: Character) -> void:
	var rock := Color(0.52, 0.47, 0.46)
	# sized for the Large rig (its chest is ~2 units wide): plates sit proud of the body so the
	# lava glow shows only in the gaps between them
	var pieces := {
		"chest": [[Vector3(0, 0.3, 0.42), 0.62, Vector3(1.35, 1.0, 0.62)], [Vector3(0, 0.45, -0.4), 0.62, Vector3(1.3, 1.0, 0.6)],
			[Vector3(0.55, 0.7, 0.05), 0.42, Vector3.ONE], [Vector3(-0.55, 0.7, 0.05), 0.42, Vector3.ONE]],
		"spine": [[Vector3(0, 0.05, 0.4), 0.5, Vector3(1.3, 0.7, 0.62)]],
		"head": [[Vector3(0, 0.36, 0.02), 0.46, Vector3(1.0, 0.9, 1.0)]],
		"upperarm.l": [[Vector3(0, 0.2, 0), 0.44, Vector3.ONE]], "upperarm.r": [[Vector3(0, 0.2, 0), 0.44, Vector3.ONE]],
		"lowerarm.l": [[Vector3(0, 0.3, 0), 0.36, Vector3(0.95, 1.2, 0.95)]], "lowerarm.r": [[Vector3(0, 0.3, 0), 0.36, Vector3(0.95, 1.2, 0.95)]],
		"upperleg.l": [[Vector3(0, -0.25, 0.08), 0.34, Vector3(1.0, 1.3, 1.0)]], "upperleg.r": [[Vector3(0, -0.25, 0.08), 0.34, Vector3(1.0, 1.3, 1.0)]],
		"lowerleg.l": [[Vector3(0, -0.2, 0.1), 0.3, Vector3(1.0, 1.2, 1.0)]], "lowerleg.r": [[Vector3(0, -0.2, 0.1), 0.3, Vector3(1.0, 1.2, 1.0)]],
	}
	var k := 0
	for b in pieces:
		var s := _socket(ch, String(b))
		if s == null:
			continue
		for p in pieces[b]:
			var mi := _blob(s, p[0], float(p[1]), rock.lightened(0.05 * (k % 3)), 200 + k, p[2])
			mi.name = "Shell%d" % k
			if b != "head":
				# the rock head stays on after the shatter (the eyes live on it)
				mi.add_to_group("golem_shell")
				mi.set_meta("shell", true)
			k += 1


## Magma Golem phase 2: the rock shell cracks off (pieces fly out and fall), the body flares.
static func shatter(ch: Character) -> void:
	if not is_instance_valid(ch) or ch.has_meta("shattered"):
		return
	ch.set_meta("shattered", true)
	var world := ch.get_parent() as Node3D
	for mi in ch.find_children("Shell*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.has_meta("shell"):
			continue
		var gt := m.global_transform
		m.get_parent().remove_child(m)
		if world == null:
			m.queue_free()
			continue
		world.add_child(m)
		m.global_transform = gt
		var out := (gt.origin - ch.global_position)
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
		var dest := gt.origin + out * randf_range(1.2, 2.2) + Vector3.UP * randf_range(0.3, 0.9)
		var t := m.create_tween()
		t.set_parallel(true)
		t.tween_property(m, "global_position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "rotation", m.rotation + Vector3(randf_range(-2, 2), randf_range(-2, 2), 0), 0.9)
		t.chain().tween_property(m, "global_position:y", ch.global_position.y - 0.2, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.chain().tween_property(m, "scale", Vector3.ONE * 0.01, 0.4)
		t.chain().tween_callback(m.queue_free)
	var id := String(ch.get_meta("enemy_id", "boss_magma_golem"))
	retint(ch, id)
	if world:
		Fx.burst(world, ch.global_position + Vector3.UP * 1.6, {"amount": 40, "lifetime": 1.0, "speed": Vector2(2.0, 6.0),
			"gravity": Vector3(0, -9, 0), "size": 0.3, "color": Color(1.0, 0.5, 0.15), "tex": "spark", "spread": 80.0})


static func _skull_head(ch: Character, replace := false) -> Node3D:
	if replace:
		for m in ch.model.find_children("*", "MeshInstance3D", true, false):
			var n := String(m.name).to_lower()
			if n.contains("head") or n.contains("hat") or n.contains("hood") or n.contains("helmet"):
				(m as MeshInstance3D).visible = false
	var p := ch.attach("head", "res://assets/kaykit/halloween/skull.gltf")
	if p:
		p.scale = Vector3.ONE * (1.0 if replace else 1.12)
		p.position = Vector3(0, 0.05 if replace else 0.02, 0.06)
	return p


## Grave Mage: a skull face under the mage's own hat (the hat keeps the silhouette).
static func _skull_under_hat(ch: Character) -> void:
	_hide_meshes(ch, "Mage_Head")
	var p := ch.attach("head", "res://assets/kaykit/halloween/skull.gltf")
	if p:
		p.scale = Vector3.ONE * 0.86
		p.position = Vector3(0, 0.02, 0.04)
		Props.tint(p, Color(0.8, 0.86, 0.72), 0.5)


## Mini-boss aura: a coloured rim light and slow rising motes around the figure.
static func _aura(ch: Character, color: Color) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 1.6
	l.omni_range = 3.2
	l.position = Vector3(0.0, 1.6, -0.9)
	ch.add_child(l)
	var motes := Fx.elite_sparkle(ch, Vector3(0, 0.1, 0), 0.75, 2.2)
	(motes.process_material as ParticleProcessMaterial).color = color.lightened(0.2)
	var ring := Biome._rune_circle(color, 1.05)
	ring.name = "AuraRing"
	ring.position.y = 0.04
	(ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.7)
	ch.add_child(ring)


static func _pumpkin_head(ch: Character, k := 0.62) -> void:
	for m in ch.model.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name).to_lower()
		if n.contains("head") or n.contains("hat") or n.contains("helmet"):
			(m as MeshInstance3D).visible = false
	var p := ch.attach("head", "res://assets/kaykit/halloween/pumpkin_orange_jackolantern.gltf")
	if p:
		p.scale = Vector3.ONE * k
		p.position = Vector3(0, 0.1, 0.05)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.15)
		l.light_energy = 1.5
		l.omni_range = 2.5
		l.position = Vector3(0, 0.5, 0.9)
		p.add_child(l)
