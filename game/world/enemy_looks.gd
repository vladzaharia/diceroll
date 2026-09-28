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
	if bool(d.get("pumpkin", false)):
		_pumpkin_head(ch)
	if bool(d.get("glow", false)):
		var l := OmniLight3D.new()
		l.light_color = Color(0.7, 0.4, 1.0)
		l.light_energy = 2.0
		l.omni_range = 3.0
		l.position = Vector3(0.6, 2.0, 0.6)
		ch.add_child(l)
	ch.play(clip(id, "idle"), 0.0)
	return ch


static func _skull_head(ch: Character) -> void:
	var p := ch.attach("head", "res://assets/kaykit/halloween/skull.gltf")
	if p:
		p.scale = Vector3.ONE * 1.12
		p.position = Vector3(0, 0.02, 0.06)


static func _pumpkin_head(ch: Character) -> void:
	for m in ch.model.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name).to_lower()
		if n.contains("head") or n.contains("hat"):
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
