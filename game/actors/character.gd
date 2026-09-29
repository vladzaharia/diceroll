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
## Armory loadouts (docs/design/2026-09-29-armory-items.md §8): items replace the model's
## default gear, armor pieces replace its own parts (ArmorBinder), the attack follows the weapon:
##   var hero := Character.create("knight", "alt_A", Character.kit("mage"))
##   hero.equip({weapon = "sword_saber", offhand = "round_shield", head = "wizard_hat",
##       body = "ninja_gi", back = "mage_cape", trinket = "compass", trinket2 = "lantern"})
##   hero.style()     # "melee" | "ranged" | "magic" (combat_stage)
## Loadout values are ItemMounts ids (item / variant ids, or raw model ids). Left-out weapon /
## off-hand / trinket keys mean none; left-out head / body / back keys keep the model's own parts.
##
## play()/play_once() accept an alias (see ALIASES) or a raw clip name ("Idle_B").

signal anim_finished(anim: String)

const ADV := "res://assets/kaykit/adventurers/"
const ANIM := "res://assets/kaykit/animations/"
## Enemy roster models (EXTRA / Mystery Monthly packs, see tools/import_assets.sh).
const FOE := "res://assets/kaykit/foes/"

## model id -> [mesh glb, rig ("medium"|"large"), attack alias set, default gear {slot: scene},
## optional base texture (for GLBs shipped without one, e.g. the Orc Raider)].
## Every model below uses the KayKit Rig_Medium / Rig_Large bone set (23 bones with handslots),
## so the shared rig animation libraries drive them all.
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
	# --- enemy roster ------------------------------------------------------------------------
	"skel_minion": [FOE + "skeletons/Skeleton_Minion.glb", "medium", "unarmed", {}],
	"skel_warrior": [FOE + "skeletons/Skeleton_Warrior.glb", "medium", "melee_1h", {}],
	"skel_rogue": [FOE + "skeletons/Skeleton_Rogue.glb", "medium", "dual", {}],
	"skel_mage": [FOE + "skeletons/Skeleton_Mage.glb", "medium", "magic", {}],
	"skel_golem": [FOE + "skeletons/Skeleton_Golem.glb", "large", "large", {}],
	"necromancer": [FOE + "skeletons/Necromancer.glb", "medium", "magic", {}],
	"barbarian_large": [FOE + "adventurers/Barbarian_Large.glb", "large", "large", {}],
	"druid": [FOE + "adventurers/Druid.glb", "medium", "magic", {}],
	"orc": [FOE + "monthly/orc/OrcRaider.glb", "medium", "melee_1h", {}, FOE + "monthly/orc/textures/orc_texture_A.png"],
	"werewolf": [FOE + "monthly/werewolf/Werewolf_Wolf.glb", "medium", "melee_1h", {}],
	"werewolf_man": [FOE + "monthly/werewolf/Werewolf_Man.glb", "medium", "melee_1h", {}],
	"paladin": [FOE + "monthly/paladin/Paladin.glb", "medium", "melee_1h", {}],
	"paladin_helm": [FOE + "monthly/paladin/Paladin_with_Helmet.glb", "medium", "melee_1h", {}],
	"ninja": [FOE + "monthly/ninja/Ninja.glb", "medium", "dual", {}],
	"monster": [FOE + "monthly/monster/Monster.glb", "medium", "unarmed", {}],
	# --- Armory heroes without a roster entry (the Monster Kid wears the MonsterCostume head) ----
	"engineer": ["res://assets/kaykit/adventurers_x/characters/Engineer.glb", "medium", "melee_1h",
		{"handslot.r": "res://assets/kaykit/adventurers_x/assets/engineer_Wrench.gltf"}],
	"monster_kid": [FOE + "monthly/monster/MonsterCostume.glb", "medium", "unarmed", {}],
}

## Per-model character parts by mesh node name (§8.4): head (the face / hood), headwear (hat,
## helmet, mask, crown), body (torso), arms, back (cape, cloak, backpack), quiver. ArmorBinder
## hides these when an equipped piece replaces them.
const PART_MAP := {
	"knight": {"head": ["Knight_Head"], "headwear": ["Knight_Helmet", "Knight_HelmetVisor"],
		"body": ["Knight_Body"], "arms": ["Knight_ArmLeft", "Knight_ArmRight"], "back": ["Knight_Cape"]},
	"barbarian": {"head": ["Barbarian_Head"], "headwear": ["Barbarian_BearHat"],
		"body": ["Barbarian_Body"], "arms": ["Barbarian_ArmLeft", "Barbarian_ArmRight"], "back": []},
	"mage": {"head": ["Mage_Head"], "headwear": ["Mage_Hat"],
		"body": ["Mage_Body"], "arms": ["Mage_ArmLeft", "Mage_ArmRight"], "back": ["Mage_Cape"]},
	"rogue": {"head": ["Rogue_Head"], "headwear": [],
		"body": ["Rogue_Body"], "arms": ["Rogue_ArmLeft", "Rogue_ArmRight"], "back": ["Rogue_Cape"]},
	"rogue_hooded": {"head": ["RogueHooded_Head"], "headwear": ["RogueHooded_Mask"],
		"body": ["RogueHooded_Body"], "arms": ["RogueHooded_ArmLeft", "RogueHooded_ArmRight"], "back": ["RogueHooded_Cape"]},
	"ranger": {"head": ["Ranger_Head"], "headwear": [],
		"body": ["Ranger_Body"], "arms": ["Ranger_ArmLeft", "Ranger_ArmRight"], "back": ["Ranger_Cape"],
		"quiver": ["Ranger_Quiver"]},
	"druid": {"head": ["Druid_Head"], "headwear": [],
		"body": ["Druid_Body"], "arms": ["Druid_ArmLeft", "Druid_ArmRight"], "back": ["Druid_Backpack"]},
	"engineer": {"head": ["Engineer_Head"], "headwear": ["Engineer_Goggles"],
		"body": ["Engineer_Body"], "arms": ["Engineer_ArmLeft", "Engineer_ArmRight"], "back": ["Engineer_Backpack"]},
	"paladin": {"head": ["Paladin_Head"], "headwear": [],
		"body": ["Paladin_Body"], "arms": ["Paladin_ArmLeft", "Paladin_ArmRight"], "back": ["Paladin_Cape"]},
	"paladin_helm": {"head": [], "headwear": ["Paladin_Helmet"],
		"body": ["Paladin_Body"], "arms": ["Paladin_ArmLeft", "Paladin_ArmRight"], "back": ["Paladin_Cape"]},
	"ninja": {"head": ["Ninja_Head"], "headwear": ["Ninja_Headband", "Ninja_Mask"],
		"body": ["Ninja_Chest"], "arms": ["Ninja_ArmLeft", "Ninja_ArmRight"], "back": []},
	"monster": {"head": ["Monster_Head"], "headwear": [],
		"body": ["MonsterCostume_Body"], "arms": ["MonsterCostume_ArmLeft", "MonsterCostume_ArmRight"], "back": []},
	"monster_kid": {"head": ["MonsterCostume_Head"], "headwear": [],
		"body": ["MonsterCostume_Body"], "arms": ["MonsterCostume_ArmLeft", "MonsterCostume_ArmRight"], "back": []},
	"mannequin": {"head": ["Mannequin_Medium_Head"], "headwear": [],
		"body": ["Mannequin_Medium_Body"], "arms": ["Mannequin_Medium_ArmLeft", "Mannequin_Medium_ArmRight"], "back": []},
	"mannequin_large": {"head": ["MannequinLarge_Head"], "headwear": [],
		"body": ["MannequinLarge_Body"], "arms": ["MannequinLarge_ArmLeft", "MannequinLarge_ArmRight"], "back": []},
	"necromancer": {"head": ["Necromancer_Head"], "headwear": ["Necromancer_Crown"],
		"body": ["Necromancer_Body"], "arms": ["Necromancer_ArmLeft", "Necromancer_ArmRight"], "back": []},
	"skel_minion": {"head": ["Skeleton_Minion_Head", "Skeleton_Minion_Jaw", "Skeleton_Minion_Eyes"], "headwear": [],
		"body": ["Skeleton_Minion_Body"], "arms": ["Skeleton_Minion_ArmLeft", "Skeleton_Minion_ArmRight"],
		"back": ["Skeleton_Minion_Cloak"]},
	"skel_warrior": {"head": ["Skeleton_Warrior_Head", "Skeleton_Warrior_Jaw", "Skeleton_Warrior_Eyes"],
		"headwear": ["Skeleton_Warrior_Helmet"], "body": ["Skeleton_Warrior_Body"],
		"arms": ["Skeleton_Warrior_ArmLeft", "Skeleton_Warrior_ArmRight"], "back": ["Skeleton_Warrior_Cloak"]},
	"skel_rogue": {"head": ["Skeleton_Rogue_Head", "Skeleton_Rogue_Jaw", "Skeleton_Rogue_Eyes"],
		"headwear": ["Skeleton_Rogue_Hood"], "body": ["Skeleton_Rogue_Body"],
		"arms": ["Skeleton_Rogue_ArmLeft", "Skeleton_Rogue_ArmRight"], "back": ["Skeleton_Rogue_Cape"]},
	"skel_mage": {"head": ["Skeleton_Mage_Skull", "Skeleton_Mage_Jaw", "Skeleton_Mage_Eyes"],
		"headwear": ["Skeleton_Mage_Hat"], "body": ["Skeleton_Mage_Body"],
		"arms": ["Skeleton_Mage_ArmLeft", "Skeleton_Mage_ArmRight"], "back": []},
	"skel_golem": {"head": ["Skeleton_Golem_Head", "Skeleton_Golem_Jaw", "Skeleton_Golem_Eyes"], "headwear": [],
		"body": ["Skeleton_Golem_Body"], "arms": ["Skeleton_Golem_ArmLeft", "Skeleton_Golem_ArmRight"], "back": []},
	"barbarian_large": {"head": ["Barbarian_Large_Head"], "headwear": ["Barbarian_Large_BearHat"],
		"body": ["Barbarian_Large_Body", "Barbarian_Large_ShoulderpadLeft", "Barbarian_Large_ShoulderpadRight"],
		"arms": ["Barbarian_Large_ArmLeft", "Barbarian_Large_ArmRight"], "back": ["Barbarian_Large_BearPelt"]},
	"orc": {"head": ["OrcRaider_Head"], "headwear": [],
		"body": ["OrcRaider_Body"], "arms": ["OrcRaider_ArmLeft", "OrcRaider_ArmRight"], "back": ["Orc_Warpack"]},
	"werewolf": {"head": ["Werewolf_Wolf_Head"], "headwear": [],
		"body": ["Werewolf_Wolf_Body"], "arms": ["Werewolf_Wolf_ArmLeft", "Werewolf_Wolf_ArmRight"], "back": []},
	"werewolf_man": {"head": ["Werewolf_Man_Head"], "headwear": [],
		"body": ["Werewolf_Man_Body"], "arms": ["Werewolf_Man_ArmLeft", "Werewolf_Man_ArmRight"], "back": []},
}

## Class signature kits (§6) as loadouts; the default appearance is the class's own look.
## model: the Character model the class wears (the Necromancer hero is the hooded rogue).
const KITS := {
	"knight": {"model": "knight", "weapon": "sword", "offhand": "round_shield_badge", "head": "knight_helm",
		"body": "knight_plate", "back": "knight_cape", "trinket": "tankard"},
	"barbarian": {"model": "barbarian", "weapon": "great_axe", "head": "bear_hat", "body": "barbarian_harness",
		"back": "", "trinket": "tankard"},
	"mage": {"model": "mage", "weapon": "arcane_staff", "offhand": "spellbook", "head": "wizard_hat",
		"body": "mage_robe", "back": "mage_cape", "trinket": "tankard"},
	"rogue": {"model": "rogue", "weapon": "dagger", "offhand": "parrying_dagger", "head": "bandit_mask",
		"body": "rogue_leathers", "back": "rogue_cape", "trinket": "tankard", "appearance": {"head": "own"}},
	"paladin": {"model": "paladin", "weapon": "warhammer", "offhand": "oath_shield", "head": "paladin_helm",
		"body": "paladin_cuirass", "back": "paladin_cape", "trinket": "tankard", "appearance": {"head": "hidden"}},
	"ranger": {"model": "ranger", "weapon": "hunting_bow", "offhand": "quiver", "head": "",
		"body": "ranger_tunic", "back": "ranger_cape", "trinket": "tankard"},
	"ninja": {"model": "ninja", "weapon": "katana", "offhand": "shuriken", "head": "ninja_headband",
		"body": "ninja_gi", "back": "", "trinket": "tankard", "appearance": {"head": "own"}},
	"druid": {"model": "druid", "weapon": "druid_staff", "head": "", "body": "druid_robe",
		"back": "druid_backpack", "trinket": "tankard"},
	"engineer": {"model": "engineer", "weapon": "wrench", "head": "goggles", "body": "engineer_overalls",
		"back": "engineer_backpack", "trinket": "tankard"},
	"necromancer": {"model": "rogue_hooded", "weapon": "staff_bone", "head": "bone_crown", "body": "hooded_robe",
		"back": "hooded_cape", "trinket": "tankard", "skin": "alt_C"},
	"monster_kid": {"model": "monster_kid", "weapon": "claws", "body": "dino_suit", "back": "", "trinket": "tankard"},
}

## Skin textures per model ("%s" = the skin id: alt_A.. for Adventurers, A..D for the monthlies).
const SKIN_TEX := {
	"knight": FOE + "adventurers/textures/knight_texture_%s.png",
	"barbarian": FOE + "adventurers/textures/barbarian_texture_%s.png",
	"mage": FOE + "adventurers/textures/mage_texture_%s.png",
	"rogue": FOE + "adventurers/textures/rogue_texture_%s.png",
	"rogue_hooded": FOE + "adventurers/textures/rogue_texture_%s.png",
	"ranger": FOE + "adventurers/textures/ranger_texture_%s.png",
	"druid": FOE + "adventurers/textures/druid_texture_%s.png",
	"engineer": FOE + "adventurers/textures/engineer_texture_%s.png",
	"ninja": FOE + "monthly/ninja/textures/ninja_texture_%s.png",
	"paladin": FOE + "monthly/paladin/textures/paladin_texture_%s.png",
	"paladin_helm": FOE + "monthly/paladin/textures/paladin_texture_%s.png",
	"monster": FOE + "monthly/monster/textures/monstercostume_texture_%s.png",
	"monster_kid": FOE + "monthly/monster/textures/monstercostume_texture_%s.png",
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
	"Skeletons_Inactive_Floor_Pose", "Skeletons_Inactive_Standing_Pose", "Fishing_Idle", "Ranged_1H_Aiming",
	"Ranged_2H_Aiming"]

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
	"crossbow": "Ranged_1H_Shoot", "spear": "Melee_2H_Attack_Stab", "scythe": "Melee_2H_Attack_Spin",
}
## Attack alias -> combat_stage style (melee: run in and swing; ranged / magic: shoot from home).
const STAGE_STYLE := {"magic": "magic", "bow": "ranged", "crossbow": "ranged"}

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
var _retextured: Dictionary = {}      # MeshInstance3D -> true (base materials are overrides)
## Per-character alias -> clip (or Array of clips, one picked per play) overrides, checked
## before the rig aliases: enemy looks set idle/attack/hit/death/spawn per weapon and body.
var clip_overrides: Dictionary = {}
## The equipped loadout ({} = the model's default gear) and what it resolved to.
var loadout: Dictionary = {}
## While true, "idle" resolves to the weapon's combat idle (2H: Melee_2H_Idle, bows:
## Ranged_Bow_Idle). combat_stage sets it for the fight.
var in_combat := false
var _style: String = ""          # ATTACKS alias of the current attack
var _combat_idle: String = ""
var _parts: Dictionary = {}      # own part name -> MeshInstance3D (built on first use)
var _part_vis: Dictionary = {}   # own part name -> visibility before equip()
var _worn: Array[Node] = []      # bound donor parts (ArmorBinder)


## `skin`: "" | a skin id (SKIN_TEX: "alt_A", "B"...) | a texture path. A bool is the legacy
## `with_gear` flag. `loadout` ({} = MODELS default gear): see equip().
static func create(id: String, skin: Variant = "", p_loadout: Dictionary = {}) -> Character:
	assert(MODELS.has(id), "unknown character model id: %s" % id)
	var with_gear: bool = skin if skin is bool else true
	var skin_id: String = "" if skin is bool else String(skin)
	var def: Array = MODELS[id]
	var c := Character.new()
	c.name = id.capitalize().replace(" ", "")
	c.model_id = id
	c._rig = def[1]
	c._style = def[2]
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
	if def.size() > 4:
		c.set_texture(load(def[4]))
	if not p_loadout.is_empty():
		c.equip(p_loadout)
	elif with_gear:
		var gear: Dictionary = def[3]
		for slot in gear:
			c.attach(slot, gear[slot])
	if skin_id != "":
		c.set_texture(load(skin_texture(id, skin_id)) if ResourceLoader.exists(skin_texture(id, skin_id)) else null)
	c.play("idle", 0.0)
	# Desync crowds a little so rows of idling characters don't move in lockstep.
	c.anim_player.seek(randf() * 0.8, true)
	return c


## Drops the shared animation libraries (call before quitting to avoid leak warnings).
static func clear_cache() -> void:
	_lib_cache.clear()
	ArmorBinder.clear_cache()


## A class's signature kit (§6) as a loadout for create()/equip() (Knight's if unknown).
## kit(c).model is the model to create; kit(c).skin its default skin ("" = the model's own).
static func kit(class_id: String) -> Dictionary:
	return (KITS.get(class_id, KITS.knight) as Dictionary).duplicate(true)


## Texture path of a skin id for a model ("" if the model has no skin table).
static func skin_texture(id: String, skin: String) -> String:
	if skin.begins_with("res://"):
		return skin
	return String(SKIN_TEX[id]) % skin if SKIN_TEX.has(id) else ""


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
	if clip_overrides.has(anim):
		var o: Variant = clip_overrides[anim]
		if o is Array:
			# several clips: pick one that exists (attack variety between swings)
			var ok := (o as Array).filter(func(x: String) -> bool: return anim_player.has_animation(x))
			return String(ok.pick_random()) if not ok.is_empty() else ""
		clip = String(o)
	elif anim == "attack":
		clip = _attack_clip
	elif anim == "idle" and in_combat and _combat_idle != "":
		clip = _combat_idle
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
				mi.set_surface_override_material(s, originals[s] if _retextured.has(mi) else null)
				continue
			var m := _tinted(originals[s], color, strength, emission)
			if tint_shader:
				m.shader = tint_shader
			for k in tint_params:
				m.set_shader_parameter(k, tint_params[k])
			mi.set_surface_override_material(s, m)


## Re-tints only the meshes `filter` accepts (eyes, cloaks, gear) over their base materials,
## on top of whatever set_tint() did. roughness / metallic < 0 keep the material's own.
func tint_where(filter: Callable, color: Color, strength: float, emission := Color.BLACK,
		roughness := -1.0, metallic := -1.0) -> void:
	for mi in _meshes():
		if not filter.call(mi):
			continue
		if not _orig_materials.has(mi):
			var mats: Array[Material] = []
			for s in mi.mesh.get_surface_count():
				mats.append(mi.get_active_material(s))
			_orig_materials[mi] = mats
		var originals: Array = _orig_materials[mi]
		for s in originals.size():
			var m := _tinted(originals[s], color, strength, emission)
			if tint_shader:
				m.shader = tint_shader
			for k in tint_params:
				m.set_shader_parameter(k, tint_params[k])
			if roughness >= 0.0:
				m.set_shader_parameter("roughness", roughness)
			if metallic >= 0.0:
				m.set_shader_parameter("metallic", metallic)
			mi.set_surface_override_material(s, m)


## Swaps the body's texture (KayKit alt colourways / skins share one UV atlas layout).
## Only the skinned body meshes change; attached weapons keep their own atlas. Call before
## the first set_tint(), or it re-captures the base materials itself.
func set_texture(tex: Texture2D) -> void:
	if tex == null:
		return
	# only the main atlas: some bodies have a second one (the Paladin's metal parts)
	var main: Texture2D = null
	var found := false
	for mi in _meshes():
		if mi.get_parent() == skeleton and mi.mesh.get_surface_count() > 0 and not mi.has_meta("donor"):
			var b := mi.get_active_material(0) as BaseMaterial3D
			if b:
				main = b.albedo_texture
				found = true
				break
	if not found:
		return
	# donor armor keeps its own atlas unless it is the same texture family (Rogue <-> Rogue_Hooded)
	var family := _atlas_family(main)
	for mi in _meshes():
		if mi.get_parent() != skeleton:
			continue
		var donor := mi.has_meta("donor")
		for s in mi.mesh.get_surface_count():
			var base := mi.get_active_material(s) as BaseMaterial3D
			if base == null:
				continue
			if donor:
				if family == "" or _atlas_family(base.albedo_texture) != family:
					continue
			elif base.albedo_texture != main:
				continue
			var m := base.duplicate() as BaseMaterial3D
			m.albedo_texture = tex
			m.albedo_color = Color.WHITE
			mi.set_surface_override_material(s, m)
		_retextured[mi] = true
		_orig_materials.erase(mi)


## "Knight_knight_texture.png" -> "knight_texture.png" (the atlas a skin palette targets).
static func _atlas_family(tex: Texture2D) -> String:
	if tex == null or tex.resource_path == "":
		return ""
	var re := RegEx.create_from_string("[a-z]+_texture.*$")
	var m := re.search(tex.resource_path.get_file().to_lower())
	return m.get_string() if m else ""


## Equips a loadout {weapon, offhand, trinket, trinket2, head, body, back, appearance}, replacing
## the default gear and any earlier loadout. Rules (§1, §3, §8): a 2H weapon blocks hand
## off-hands (the Spellbook then hangs closed on the belt); Claws add the left claw when the off
## hand is free; the Ranger keeps its own quiver mesh for the Quiver. The attack clip, style()
## and the combat idle follow the weapon.
func equip(p_loadout: Dictionary) -> void:
	unequip()
	loadout = p_loadout.duplicate(true)
	var weapon := String(loadout.get("weapon", ""))
	var off := String(loadout.get("offhand", ""))
	var two_h := ItemMounts.hands(weapon) == 2
	var left_used := false
	var wi := ItemMounts.item(weapon)
	if not wi.is_empty():
		var wm := ItemMounts.mount(String(wi.model))
		left_used = wm.socket == "handslot.l"
		mount_item(wm)
	var oi := ItemMounts.item(off)
	var own_quiver := false
	if not oi.is_empty():
		var kind := String(ItemMounts.base_of(off).get("mount", "hand"))
		var model := String(oi.get("model_2h", oi.model)) if two_h else String(oi.model)
		if String(oi.base) == "quiver" and model == "quiver" and has_parts(PART_MAP.get(model_id, {}).get("quiver", [])):
			own_quiver = true
		elif kind != "hand" or not (two_h or left_used):
			var om := ItemMounts.mount(model, "handslot.l" if String(ItemMounts.MOUNTS[model].socket) == "handslot.r" else "")
			left_used = left_used or om.socket == "handslot.l"
			mount_item(om)
	if wi.has("model_left") and not left_used:
		var lm := ItemMounts.mount(String(wi.model_left), "handslot.l")
		if wi.model_left == wi.model:
			lm.xform = Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO) * lm.xform
		mount_item(lm)
	show_parts(PART_MAP.get(model_id, {}).get("quiver", []), own_quiver)
	for pair in [["trinket", "hip"], ["trinket2", "hip2"]]:
		var ti := ItemMounts.item(String(loadout.get(pair[0], "")))
		if not ti.is_empty():
			mount_item(ItemMounts.mount(String(ti.model), pair[1]))
	ArmorBinder.apply(self, loadout)
	# attack style follows the weapon (the model's own set without one)
	var def: Array = MODELS[model_id]
	_style = String(def[2])
	_attack_clip = ATTACKS[_style]
	_combat_idle = ""
	if not wi.is_empty():
		_style = ItemMounts.style(weapon)
		_attack_clip = ItemMounts.clip(weapon)
		if String(wi.base) == "dagger" and String(oi.get("base", "")) in ["parrying_dagger", "shuriken"]:
			_style = "dual"
			_attack_clip = ATTACKS.dual
		if _style == "bow":
			_combat_idle = "Ranged_Bow_Idle"
		elif two_h:
			_combat_idle = "Melee_2H_Idle"


## Removes every equipped item and bound armor piece and restores the model's own parts.
func unequip() -> void:
	clear_attachments()
	for n in _worn:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	_worn.clear()
	for p in _part_vis:
		_parts[p].visible = _part_vis[p]
	_part_vis.clear()
	loadout = {}


## Combat staging style: "melee" | "ranged" | "magic" (from the weapon, else the model).
func style() -> String:
	return String(STAGE_STYLE.get(_style, "melee"))


## The ATTACKS alias of the current attack (melee_1h, spear, bow, dual...).
func attack_style() -> String:
	return _style


## True when the model has every named own part.
func has_parts(names: Array) -> bool:
	if names.is_empty():
		return false
	_index_parts()
	for n in names:
		if not _parts.has(String(n)):
			return false
	return true


## Shows / hides own parts by name (remembering their original visibility for unequip()).
func show_parts(names: Array, on: bool) -> void:
	_index_parts()
	for n in names:
		var mi: Node3D = _parts.get(String(n))
		if mi == null:
			continue
		if not _part_vis.has(String(n)):
			_part_vis[String(n)] = mi.visible
		mi.visible = on


## Own-part visibility by name (false if missing), for tests and scenarios.
func part_visible(part: String) -> bool:
	_index_parts()
	var mi: Node3D = _parts.get(part)
	return mi != null and mi.is_visible_in_tree()


## Keeps nodes to free on unequip() (ArmorBinder donors).
func track_worn(nodes: Array) -> void:
	for n in nodes:
		_worn.append(n)


## Bound donor meshes currently worn.
func worn_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in _worn:
		if n is MeshInstance3D:
			out.append(n)
		for c in n.find_children("*", "MeshInstance3D", true, false):
			out.append(c)
	return out


func _index_parts() -> void:
	if not _parts.is_empty():
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not mi.has_meta("donor"):
			_parts[String(mi.name)] = mi


## Mounts an ItemMounts.mount() row on its socket bone (with the socket offset). Returns the
## item instance; tracked like attach() so clear_attachments() / unequip() remove it.
func mount_item(row: Dictionary) -> Node3D:
	if row.is_empty():
		return null
	var sock: Array = ItemMounts.socket(String(row.socket))
	var bone := String(sock[0])
	if skeleton.find_bone(bone) < 0 and bone.begins_with("handslot."):
		bone = "hand." + bone.get_extension()
	if skeleton.find_bone(bone) < 0 or not ResourceLoader.exists(String(row.scene)):
		push_warning("Character %s: can't mount %s on %s" % [model_id, row.scene, row.socket])
		return null
	var ba := BoneAttachment3D.new()
	ba.name = "Attach_" + String(row.socket).replace(".", "_")
	ba.bone_name = bone
	skeleton.add_child(ba)
	var inst: Node3D = (load(String(row.scene)) as PackedScene).instantiate()
	inst.transform = (sock[1] as Transform3D) * (row.xform as Transform3D)
	ba.add_child(inst)
	if not _attachments.has(String(row.socket)):
		_attachments[String(row.socket)] = []
	_attachments[String(row.socket)].append(ba)
	return inst


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
				if is_instance_valid(n):
					n.get_parent().remove_child(n)
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
		# a strong tint repaints the surface: drop most of its metal sheen (dark without reflections)
		m.set_shader_parameter("metallic", sm.metallic * (1.0 - 0.8 * clampf(strength, 0.0, 1.0)))
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
