class_name Character
extends Node3D
## A KayKit character (mesh GLB) with animation clips retargeted from the Rig GLBs.
##
##   var hero := Character.create("knight")
##   add_child(hero)
##   hero.play("idle")
##   await hero.play_once("attack")          # returns to idle when done
##   await hero.play_once("death", "")       # holds the last frame
##   hero.set_tint(Color(0.93, 0.9, 0.82), 0.85)
##   hero.attach("handslot.r", "res://assets/kaykit/adventurers/weapons/sword_1handed.gltf")
##
## play()/play_once() accept an alias (see ALIASES) or a raw clip name ("Idle_B").

signal anim_finished(anim: String)

const ADV := "res://assets/kaykit/adventurers/"
const ANIM := "res://assets/kaykit/animations/"

## model id -> [mesh glb, rig ("medium"|"large"), attack alias set, default gear {slot: scene}]
const MODELS := {
	"knight": [ADV + "characters/Knight.glb", "medium", "melee_1h",
		{"handslot.r": ADV + "weapons/sword_1handed.gltf", "handslot.l": ADV + "weapons/shield_badge_color.gltf"}],
	"barbarian": [ADV + "characters/Barbarian.glb", "medium", "melee_2h",
		{"handslot.r": ADV + "weapons/axe_2handed.gltf"}],
	"mage": [ADV + "characters/Mage.glb", "medium", "magic",
		{"handslot.r": ADV + "weapons/staff.gltf"}],
	"rogue": [ADV + "characters/Rogue.glb", "medium", "dual",
		{"handslot.r": ADV + "weapons/dagger.gltf", "handslot.l": ADV + "weapons/dagger.gltf"}],
	"rogue_hooded": [ADV + "characters/Rogue_Hooded.glb", "medium", "dual",
		{"handslot.r": ADV + "weapons/dagger.gltf", "handslot.l": ADV + "weapons/dagger.gltf"}],
	"ranger": [ADV + "characters/Ranger.glb", "medium", "bow",
		{"handslot.l": ADV + "weapons/bow_withString.gltf"}],
	"mannequin": [ANIM + "mannequins/Mannequin_Medium.glb", "medium", "unarmed", {}],
	"mannequin_large": [ANIM + "mannequins/Mannequin_Large.glb", "large", "large", {}],
}

const RIG_FILES := {
	"medium": ["General", "MovementBasic", "MovementAdvanced", "CombatMelee", "CombatRanged",
		"Simulation", "Special", "Tools"],
	"large": ["General", "MovementBasic", "MovementAdvanced", "CombatMelee", "Simulation", "Special"],
}

## Clips that loop. Everything else plays once.
const LOOPING := ["Idle_A", "Idle_B", "Walking_A", "Walking_B", "Walking_C", "Running_A", "Running_B",
	"Jump_Idle", "Melee_2H_Idle", "Melee_Unarmed_Idle", "Melee_Blocking", "Ranged_Bow_Idle",
	"Ranged_Bow_Aiming_Idle", "Ranged_Magic_Spellcasting_Long", "Skeletons_Idle", "Skeletons_Walking",
	"Cheering", "Waving", "Lockpicking", "Holding_A", "Holding_B", "Holding_C", "Sneaking", "Crouching",
	"Crawling", "Running_HoldingBow", "Sit_Chair_Idle", "Sit_Floor_Idle", "Lie_Idle", "Flexing",
	"Skeletons_Inactive_Floor_Pose", "Skeletons_Inactive_Standing_Pose", "Fishing_Idle"]

## alias -> clip, per rig. Attack/cast/shoot depend on the model's attack set.
const ALIASES := {
	"medium": {
		"idle": "Idle_A", "idle_b": "Idle_B", "walk": "Walking_A", "run": "Running_A",
		"jump": "Jump_Full_Short", "hit": "Hit_A", "death": "Death_A", "cheer": "Cheering",
		"spawn": "Spawn_Ground", "interact": "Interact", "use": "Use_Item", "block": "Melee_Block",
		"skel_idle": "Skeletons_Idle", "skel_walk": "Skeletons_Walking",
		"skel_spawn": "Skeletons_Awaken_Standing", "skel_death": "Skeletons_Death", "taunt": "Skeletons_Taunt",
		"cast": "Ranged_Magic_Spellcasting", "shoot": "Ranged_Bow_Release",
	},
	"large": {
		"idle": "Idle_A", "idle_b": "Idle_B", "walk": "Walking_A", "run": "Running_A",
		"jump": "Dodge_Forward", "hit": "Hit_A", "death": "Death_A", "cheer": "Flexing",
		"spawn": "Melee_Unarmed_Smash", "interact": "Melee_Unarmed_Punch", "use": "Melee_Unarmed_Punch",
		"block": "Melee_Block", "skel_idle": "Idle_B", "skel_walk": "Walking_A", "skel_spawn": "Flexing",
		"skel_death": "Death_A", "taunt": "Flexing", "cast": "Melee_Unarmed_Smash", "shoot": "Melee_Unarmed_Punch",
	},
}
const ATTACKS := {
	"melee_1h": "Melee_1H_Attack_Chop", "melee_2h": "Melee_2H_Attack_Chop",
	"magic": "Ranged_Magic_Shoot", "dual": "Melee_Dualwield_Attack_Slice",
	"bow": "Ranged_Bow_Release", "unarmed": "Melee_Unarmed_Attack_Punch_A", "large": "Melee_2H_Slam",
}

const TINT_SHADER := preload("res://game/actors/tint.gdshader")

## rig + bone-set key -> AnimationLibrary (shared between characters with the same skeleton).
static var _lib_cache: Dictionary = {}

var model_id: String
var model: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var current: String = ""

var _rig: String
var _attack_clip: String
var _token: int = 0
## Optional shader replacing tint.gdshader for this character's tinted surfaces (ghosts), and
## extra uniforms set on every tinted surface (crack glow, ghost alpha...).
var tint_shader: Shader = null
var tint_params: Dictionary = {}
var _orig_materials: Dictionary = {}  # MeshInstance3D -> Array[Material]
var _attachments: Dictionary = {}     # slot -> Array[Node3D]


static func create(id: String, with_gear := true) -> Character:
	assert(MODELS.has(id), "unknown character model id: %s" % id)
	var def: Array = MODELS[id]
	var c := Character.new()
	c.name = id.capitalize().replace(" ", "")
	c.model_id = id
	c._rig = def[1]
	c._attack_clip = ATTACKS[def[2]]
	c.model = (load(def[0]) as PackedScene).instantiate()
	c.add_child(c.model)
	c.skeleton = c.model.find_child("Skeleton3D", true, false)
	c.anim_player = AnimationPlayer.new()
	c.anim_player.name = "AnimationPlayer"
	c.add_child(c.anim_player)
	c.anim_player.root_node = c.anim_player.get_path_to(c.model)
	c.anim_player.add_animation_library("", _library_for(c._rig, c.skeleton, c.model.get_path_to(c.skeleton)))
	c.anim_player.playback_default_blend_time = 0.15
	if with_gear:
		var gear: Dictionary = def[3]
		for slot in gear:
			c.attach(slot, gear[slot])
	c.play("idle", 0.0)
	# Desync crowds a little so rows of idling characters don't move in lockstep.
	c.anim_player.seek(randf() * 0.8, true)
	return c


## Drops the shared animation libraries (call before quitting to avoid leak warnings).
static func clear_cache() -> void:
	_lib_cache.clear()


static func model_ids() -> PackedStringArray:
	return PackedStringArray(MODELS.keys())


## Every alias understood by play()/play_once().
static func alias_names() -> PackedStringArray:
	var names := PackedStringArray(ALIASES["medium"].keys())
	names.append("attack")
	return names


## Resolves an alias or clip name to a clip name present in the library ("" if none).
func resolve(anim: String) -> String:
	var clip := anim
	if anim == "attack":
		clip = _attack_clip
	elif ALIASES[_rig].has(anim):
		clip = ALIASES[_rig][anim]
	return clip if anim_player.has_animation(clip) else ""


func has_anim(anim: String) -> bool:
	return resolve(anim) != ""


## Clip length in seconds (0 if unknown).
func anim_length(anim: String) -> float:
	var clip := resolve(anim)
	return anim_player.get_animation(clip).length if clip != "" else 0.0


## Plays (cross-fading) an alias or clip. Re-playing the current looping clip is a no-op.
func play(anim: String, blend := 0.15, speed := 1.0) -> void:
	var clip := resolve(anim)
	if clip == "":
		push_warning("Character %s: no clip for '%s'" % [model_id, anim])
		return
	_token += 1
	if clip == current and anim_player.is_playing() and anim_player.get_animation(clip).loop_mode != Animation.LOOP_NONE:
		return
	current = clip
	anim_player.play(clip, blend, speed)


## Plays a clip once, then `then` (pass "" to hold the last frame). Await it:
## `await ch.play_once("attack")`. Emits anim_finished(anim) at the end, or early if
## another play() interrupts it.
func play_once(anim: String, then := "Idle_A", blend := 0.12, speed := 1.0) -> void:
	var clip := resolve(anim)
	if clip == "":
		push_warning("Character %s: no clip for '%s'" % [model_id, anim])
		anim_finished.emit(anim)
		return
	_token += 1
	var my := _token
	current = clip
	anim_player.play(clip, blend, speed)
	anim_player.seek(0.0, true)
	# Poll rather than wait on animation_finished so an interrupting play() can't hang us.
	while my == _token and is_inside_tree() and anim_player.is_playing() \
			and anim_player.current_animation == clip:
		await get_tree().process_frame
	if my == _token and then != "":
		play(then, 0.2)
	anim_finished.emit(anim)


## Blends every surface toward `color` (0 = original look, 1 = fully tinted, shading kept).
func set_tint(color: Color, strength: float, emission := Color.BLACK) -> void:
	for mi in _orig_materials.keys():
		if not is_instance_valid(mi):
			_orig_materials.erase(mi)
	for mi in _meshes():
		if not _orig_materials.has(mi):
			var mats: Array[Material] = []
			for s in mi.mesh.get_surface_count():
				mats.append(mi.get_active_material(s))
			_orig_materials[mi] = mats
		var originals: Array = _orig_materials[mi]
		for s in originals.size():
			if strength <= 0.0 and emission == Color.BLACK:
				mi.set_surface_override_material(s, null)
				continue
			var m := _tinted(originals[s], color, strength, emission)
			if tint_shader:
				m.shader = tint_shader
			for k in tint_params:
				m.set_shader_parameter(k, tint_params[k])
			mi.set_surface_override_material(s, m)


## Attaches a scene to a bone slot ("handslot.r", "handslot.l", "head", or any bone).
## Falls back from handslot.* to hand.* on skeletons without hand slots. Returns the instance.
func attach(slot: String, scene_path: String) -> Node3D:
	var bone := slot
	if skeleton.find_bone(bone) < 0 and bone.begins_with("handslot."):
		bone = "hand." + bone.get_extension()
	if skeleton.find_bone(bone) < 0:
		push_warning("Character %s: no bone '%s'" % [model_id, slot])
		return null
	var ba := BoneAttachment3D.new()
	ba.name = "Attach_" + slot.replace(".", "_")
	ba.bone_name = bone
	skeleton.add_child(ba)
	var inst: Node3D = (load(scene_path) as PackedScene).instantiate()
	ba.add_child(inst)
	if not _attachments.has(slot):
		_attachments[slot] = []
	_attachments[slot].append(ba)
	return inst


## Removes attachments from one slot, or every slot when `slot` is "".
func clear_attachments(slot := "") -> void:
	for s in _attachments.keys():
		if slot == "" or s == slot:
			for n in _attachments[s]:
				n.queue_free()
			_attachments.erase(s)


## Tintable meshes: the model's own and attached scenes' (weapons, skull heads). Procedural
## extras built in code (glowing eyes, ice crystals, rock plates; no owner) keep their own
## materials, so a hit flash never turns an eye or a crystal into a flat tinted blob.
func _meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		if n.mesh and n.owner != null:
			out.append(n)
	return out


static func _tinted(base: Material, color: Color, strength: float, emission: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TINT_SHADER
	var sm := base as BaseMaterial3D
	if sm:
		m.set_shader_parameter("albedo_tex", sm.albedo_texture)
		m.set_shader_parameter("albedo_color", sm.albedo_color)
		m.set_shader_parameter("roughness", sm.roughness)
		m.set_shader_parameter("metallic", sm.metallic)
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("strength", clampf(strength, 0.0, 1.0))
	m.set_shader_parameter("emission", emission)
	return m


## Builds (once per rig + bone set) a library with every clip from the rig GLBs, with
## bone tracks re-pointed at `skel_path` (relative to the model root) and tracks for
## bones the skeleton lacks dropped (Mannequin_Medium has no handslot bones).
static func _library_for(rig: String, skel: Skeleton3D, skel_path: NodePath) -> AnimationLibrary:
	var bones := PackedStringArray()
	for i in skel.get_bone_count():
		bones.append(skel.get_bone_name(i))
	var key := "%s|%s|%s" % [rig, skel_path, ",".join(bones)]
	if _lib_cache.has(key):
		return _lib_cache[key]
	var lib := AnimationLibrary.new()
	var dir := "rig_%s/Rig_%s_" % [rig, rig.capitalize()]
	for part in RIG_FILES[rig]:
		var scene: Node = (load(ANIM + dir + part + ".glb") as PackedScene).instantiate()
		var src: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		for clip in src.get_animation_list():
			if lib.has_animation(clip) or clip == "T-Pose":
				continue
			var a: Animation = src.get_animation(clip).duplicate(true)
			for t in range(a.get_track_count() - 1, -1, -1):
				var p := a.track_get_path(t)
				var bone := p.get_concatenated_subnames()
				if bone == "" or not bones.has(bone):
					a.remove_track(t)
				else:
					a.track_set_path(t, NodePath("%s:%s" % [skel_path, bone]))
			a.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(clip) else Animation.LOOP_NONE
			lib.add_animation(clip, a)
		scene.free()
	_lib_cache[key] = lib
	return lib
