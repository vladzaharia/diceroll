class_name EnemyLooks
extends RefCounted
## Enemy id -> dressed, tinted Character (spec §9) plus the clips it uses.
##
##   var ch := EnemyLooks.create("skeleton_warrior")
##   ch.play(EnemyLooks.clip("skeleton_warrior", "idle"))

const ADV := "res://assets/kaykit/adventurers/weapons/"
const BONE := Color(0.94, 0.9, 0.8)

## id -> {model, tint, strength, emission, scale, gear{slot: path}, clips{role: clip}}
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
	# Mini-bosses: clearly stronger than elites (bigger, armoured, lit), smaller than the Lich.
	"mini_pumpkin_knight": {"model": "knight", "tint": Color(0.22, 0.16, 0.14), "strength": 0.55, "scale": 1.45,
		"emission": Color(0.1, 0.03, 0.0), "gear": {"handslot.r": ADV + "sword_2handed_color.gltf",
		"handslot.l": ADV + "shield_spikes_color.gltf"}, "clips": {"attack": "Melee_2H_Attack_Chop"},
		"pumpkin": true, "aura": Color(1.0, 0.5, 0.12), "miniboss": true},
	"mini_bone_champion": {"model": "barbarian", "tint": Color(0.93, 0.9, 0.8), "strength": 0.85, "scale": 1.45,
		"skeleton_head": true, "gear": {"handslot.r": ADV + "axe_2handed.gltf"},
		"clips": {"attack": "Melee_2H_Attack_Chop"}, "aura": Color(0.75, 0.85, 1.0), "miniboss": true},
	"mini_grave_mage": {"model": "mage", "tint": Color(0.16, 0.36, 0.26), "strength": 0.7, "scale": 1.45,
		"emission": Color(0.02, 0.12, 0.06), "gear": {"handslot.r": ADV + "staff.gltf", "handslot.l": ADV + "spellbook_open.gltf"},
		"clips": {"attack": "Ranged_Magic_Spellcasting"}, "skeleton_head": true, "aura": Color(0.35, 1.0, 0.55),
		"miniboss": true},
	"boss_bone_warden": {"model": "knight", "tint": Color(0.93, 0.89, 0.78), "strength": 0.8, "scale": 1.6,
		"gear": {}, "clips": {}, "boss": true},
	"boss_hollow_king": {"model": "barbarian", "tint": Color(0.45, 0.3, 0.22), "strength": 0.3, "scale": 1.6,
		"gear": {}, "clips": {}, "boss": true, "pumpkin": true},
	"boss_lich": {"model": "mage", "tint": Color(0.5, 0.28, 0.85), "strength": 0.75, "scale": 1.6,
		"emission": Color(0.12, 0.04, 0.22), "gear": {}, "clips": {"attack": "Ranged_Magic_Spellcasting"},
		"boss": true, "glow": true},
}


static func def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["skeleton_minion"])


static func is_boss(id: String) -> bool:
	return bool(def(id).get("boss", false))


static func is_miniboss(id: String) -> bool:
	return bool(def(id).get("miniboss", false))


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


static func create(id: String) -> Character:
	var d := def(id)
	var ch := Character.create(String(d.model), d.gear.is_empty() and not bool(d.get("skeleton", false)))
	ch.name = id.to_pascal_case()
	for slot in d.gear:
		ch.attach(slot, d.gear[slot])
	ch.set_tint(d.tint, float(d.strength), d.get("emission", Color.BLACK))
	if bool(d.get("skeleton", false)):
		_skull_head(ch)
	if bool(d.get("skeleton_head", false)):
		_skull_head(ch, true)
	if bool(d.get("pumpkin", false)):
		_pumpkin_head(ch)
	if d.has("aura"):
		_aura(ch, d.aura)
	if bool(d.get("glow", false)):
		var l := OmniLight3D.new()
		l.light_color = Color(0.7, 0.4, 1.0)
		l.light_energy = 2.0
		l.omni_range = 3.0
		l.position = Vector3(0.6, 2.0, 0.6)
		ch.add_child(l)
	ch.play(clip(id, "idle"), 0.0)
	return ch


static func _skull_head(ch: Character, replace := false) -> void:
	if replace:
		for m in ch.model.find_children("*", "MeshInstance3D", true, false):
			var n := String(m.name).to_lower()
			if n.contains("head") or n.contains("hat") or n.contains("hood") or n.contains("helmet"):
				(m as MeshInstance3D).visible = false
	var p := ch.attach("head", "res://assets/kaykit/halloween/skull.gltf")
	if p:
		p.scale = Vector3.ONE * (1.25 if replace else 1.12)
		p.position = Vector3(0, 0.08 if replace else 0.02, 0.06)


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




static func _pumpkin_head(ch: Character) -> void:
	for m in ch.model.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name).to_lower()
		if n.contains("head") or n.contains("hat") or n.contains("helmet"):
			(m as MeshInstance3D).visible = false
	var p := ch.attach("head", "res://assets/kaykit/halloween/pumpkin_orange_jackolantern.gltf")
	if p:
		p.scale = Vector3.ONE * 0.62
		p.position = Vector3(0, 0.1, 0.05)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.15)
		l.light_energy = 1.5
		l.omni_range = 2.5
		l.position = Vector3(0, 0.5, 0.9)
		p.add_child(l)
