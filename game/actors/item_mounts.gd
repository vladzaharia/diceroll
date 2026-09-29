class_name ItemMounts
extends RefCounted
## Presentation data for the real-item Armory (docs/design/2026-09-29-armory-items.md §8.1):
## where each weapon / off-hand / trinket model sits on a hero, plus the armor donor pieces
## (head / body / back, bound by game/actors/armor_binder.gd).
##
##   MOUNTS[model_id] = {scene, socket, pos, rot (degrees) | axes ([x, y, z] socket-space), scale, base}
##     socket: "handslot.r" | "handslot.l" | "back" | "belt" | "hip" (+ "hip2", the Belt Pouch)
##     pos / rot / scale are local to the socket (see SOCKETS for the socket offsets).
##     base: the base item type the model stands for (style + hands come from BASES).
##   ITEMS[item or variant id] = {model, base[, model_2h, hands, clip]}
##   BASES[base] = {slot, hands, style, clip}
##   HEADS / BODIES / BACKS[piece id] = {glb, parts[, ...]}  (donor meshes, §4)
##
## Core's ItemDefs (§10 step 1) owns the rules; this table only knows looks. A loadout value can
## be an ITEMS id (item or variant: "sword", "sword_saber") or a raw MOUNTS model id ("sword_C").

const ADV := "res://assets/kaykit/adventurers/weapons/"
const ADX := "res://assets/kaykit/adventurers_x/assets/"
const FWB := "res://assets/kaykit/weapons_x/"
const SKW := "res://assets/kaykit/foes/skeletons/weapons/"
const PAL := "res://assets/kaykit/foes/monthly/paladin/weapons/"
const NIN := "res://assets/kaykit/foes/monthly/ninja/weapons/"
const RPG := "res://assets/kaykit/tools/"
const CHR := "res://assets/kaykit/adventurers/characters/"
const CHX := "res://assets/kaykit/adventurers_x/characters/"
const SKL := "res://assets/kaykit/foes/skeletons/"
const MON := "res://assets/kaykit/foes/monthly/"

## Socket -> [bone, offset from the bone, rotation (degrees)]. Characters face +Z; their right is -X.
const SOCKETS := {
	"handslot.r": ["handslot.r", Vector3.ZERO, Vector3.ZERO],
	"handslot.l": ["handslot.l", Vector3.ZERO, Vector3.ZERO],
	# slung across the back (quivers)
	"back": ["chest", Vector3(0.05, 0.1, -0.46), Vector3(0.0, 0.0, -28.0)],
	# front-left of the belt (spellbook, smoke bomb, shuriken)
	"belt": ["hips", Vector3(0.28, 0.22, 0.36), Vector3.ZERO],
	# right hip (trinket 1), left-back hip (trinket 2)
	"hip": ["hips", Vector3(-0.42, 0.2, -0.1), Vector3.ZERO],
	"hip2": ["hips", Vector3(0.4, 0.2, -0.26), Vector3.ZERO],
}

## Base item types (§2, §3, §7.3). style: the Character.ATTACKS alias; clip: the attack clip.
const BASES := {
	# weapons
	"sword": {"slot": "weapon", "hands": 1, "style": "melee_1h", "clip": "Melee_1H_Attack_Slice_Diagonal"},
	"greatsword": {"slot": "weapon", "hands": 2, "style": "melee_2h", "clip": "Melee_2H_Attack_Slice"},
	"hand_axe": {"slot": "weapon", "hands": 1, "style": "melee_1h", "clip": "Melee_1H_Attack_Chop"},
	"great_axe": {"slot": "weapon", "hands": 2, "style": "melee_2h", "clip": "Melee_2H_Attack_Chop"},
	"warhammer": {"slot": "weapon", "hands": 1, "style": "melee_1h", "clip": "Melee_1H_Attack_Chop"},
	"spear": {"slot": "weapon", "hands": 2, "style": "spear", "clip": "Melee_2H_Attack_Stab"},
	"scythe": {"slot": "weapon", "hands": 2, "style": "scythe", "clip": "Melee_2H_Attack_Spin"},
	"dagger": {"slot": "weapon", "hands": 1, "style": "melee_1h", "clip": "Melee_1H_Attack_Stab"},
	"katana": {"slot": "weapon", "hands": 1, "style": "melee_1h", "clip": "Melee_1H_Attack_Slice_Horizontal"},
	"arcane_staff": {"slot": "weapon", "hands": 2, "style": "magic", "clip": "Ranged_Magic_Shoot"},
	"druid_staff": {"slot": "weapon", "hands": 2, "style": "magic", "clip": "Ranged_Magic_Spellcasting"},
	"wand": {"slot": "weapon", "hands": 1, "style": "magic", "clip": "Ranged_Magic_Shoot"},
	"hunting_bow": {"slot": "weapon", "hands": 2, "style": "bow", "clip": "Ranged_Bow_Release"},
	"crossbow": {"slot": "weapon", "hands": 1, "style": "crossbow", "clip": "Ranged_1H_Shoot"},
	"claws": {"slot": "weapon", "hands": 1, "style": "unarmed", "clip": "Melee_Unarmed_Attack_Punch_A"},
	"wrench": {"slot": "weapon", "hands": 1, "style": "melee_1h", "clip": "Melee_1H_Attack_Chop"},
	# off-hands: mount "hand" (blocked by 2H weapons), "belt" or "back"
	"round_shield": {"slot": "offhand", "mount": "hand"},
	"spiked_shield": {"slot": "offhand", "mount": "hand"},
	"oath_shield": {"slot": "offhand", "mount": "hand"},
	"parrying_dagger": {"slot": "offhand", "mount": "hand"},
	"spellbook": {"slot": "offhand", "mount": "belt"},
	"quiver": {"slot": "offhand", "mount": "back"},
	"smoke_bomb": {"slot": "offhand", "mount": "belt"},
	"shuriken": {"slot": "offhand", "mount": "belt"},
	# trinkets
	"tankard": {"slot": "trinket"}, "compass": {"slot": "trinket"}, "lantern": {"slot": "trinket"},
	"coin_purse": {"slot": "trinket"}, "traders_map": {"slot": "trinket"}, "healers_flask": {"slot": "trinket"},
	"skeleton_key": {"slot": "trinket"}, "loaded_die": {"slot": "trinket"},
}

## Model rows. Grip notes (verified in the weapon_grips scenario on a Knight and a Rogue):
## - Adventurers and FantasyWeapons (FWB) blades share the grip convention (grip at the origin,
##   blade up +Y) but FWB pieces run longer (sword_E/F 2.2-2.8 vs 1.4): they get 0.75-0.85.
## - FWB bows lie along X (Adventurers bows along Z): rotated 90 degrees about Y.
## - Fist weapons wrap the hand: pushed back toward the wrist.
## - Trinkets are props at world scale (the gem sack is 1.4 tall): scaled to ~0.35 on the hip.
const MOUNTS := {
	# --- Adventurers weapons ------------------------------------------------------------------
	"sword_1handed": {"scene": ADV + "sword_1handed.gltf", "socket": "handslot.r", "base": "sword"},
	"sword_2handed": {"scene": ADV + "sword_2handed.gltf", "socket": "handslot.r", "base": "greatsword"},
	"sword_2handed_color": {"scene": ADV + "sword_2handed_color.gltf", "socket": "handslot.r", "base": "greatsword"},
	"axe_1handed": {"scene": ADV + "axe_1handed.gltf", "socket": "handslot.r", "base": "hand_axe"},
	"axe_2handed": {"scene": ADV + "axe_2handed.gltf", "socket": "handslot.r", "base": "great_axe"},
	"dagger": {"scene": ADV + "dagger.gltf", "socket": "handslot.r", "base": "dagger"},
	"staff": {"scene": ADV + "staff.gltf", "socket": "handslot.r", "base": "arcane_staff"},
	"druid_staff": {"scene": ADX + "druid_staff.gltf", "socket": "handslot.r", "base": "druid_staff"},
	"wand": {"scene": ADV + "wand.gltf", "socket": "handslot.r", "base": "wand"},
	"bow_withString": {"scene": ADV + "bow_withString.gltf", "socket": "handslot.l", "base": "hunting_bow"},
	"crossbow_1handed": {"scene": ADV + "crossbow_1handed.gltf", "socket": "handslot.r", "base": "crossbow"},
	"crossbow_2handed": {"scene": ADV + "crossbow_2handed.gltf", "socket": "handslot.r", "base": "crossbow"},
	"engineer_Wrench": {"scene": ADX + "engineer_Wrench.gltf", "socket": "handslot.r", "base": "wrench"},
	# --- Adventurers off-hands ----------------------------------------------------------------
	"shield_round": {"scene": ADV + "shield_round.gltf", "socket": "handslot.l", "base": "round_shield"},
	"shield_round_color": {"scene": ADV + "shield_round_color.gltf", "socket": "handslot.l", "base": "round_shield"},
	"shield_badge_color": {"scene": ADV + "shield_badge_color.gltf", "socket": "handslot.l", "base": "round_shield"},
	"shield_spikes_color": {"scene": ADV + "shield_spikes_color.gltf", "socket": "handslot.l", "base": "spiked_shield"},
	"shield_square_color": {"scene": ADV + "shield_square_color.gltf", "socket": "handslot.l", "base": "round_shield"},
	# held open in front, pages up-forward (hand frame in idle: X up, Y forward, Z outward)
	"spellbook_open": {"scene": ADV + "spellbook_open.gltf", "socket": "handslot.l", "base": "spellbook",
		"pos": Vector3(0.12, 0.1, -0.05), "axes": [Vector3(0.0, 0.0, 1.0), Vector3(0.87, -0.5, 0.0), Vector3(0.5, 0.87, 0.0)],
		"scale": 0.75},
	"spellbook_closed": {"scene": ADV + "spellbook_closed.gltf", "socket": "belt", "base": "spellbook",
		"rot": Vector3(0.0, 90.0, 0.0), "scale": 0.7},
	"quiver": {"scene": ADV + "quiver.gltf", "socket": "back", "base": "quiver", "rot": Vector3(0.0, 180.0, 0.0)},
	"smokebomb": {"scene": ADV + "smokebomb.gltf", "socket": "belt", "base": "smoke_bomb", "scale": 0.6},
	# --- FantasyWeapons EXTRA -----------------------------------------------------------------
	"sword_A": {"scene": FWB + "sword_A.gltf", "socket": "handslot.r", "base": "sword"},
	"sword_B": {"scene": FWB + "sword_B.gltf", "socket": "handslot.r", "base": "sword"},
	"sword_C": {"scene": FWB + "sword_C.gltf", "socket": "handslot.r", "base": "sword", "scale": 0.9},
	"sword_D": {"scene": FWB + "sword_D.gltf", "socket": "handslot.r", "base": "sword", "scale": 0.9},
	"sword_E": {"scene": FWB + "sword_E.gltf", "socket": "handslot.r", "base": "greatsword", "scale": 0.75},
	"sword_F": {"scene": FWB + "sword_F.gltf", "socket": "handslot.r", "base": "sword", "scale": 0.75},
	"sword_G": {"scene": FWB + "sword_G.gltf", "socket": "handslot.r", "base": "sword", "scale": 0.8},
	"axe_A": {"scene": FWB + "axe_A.gltf", "socket": "handslot.r", "base": "hand_axe"},
	"axe_B": {"scene": FWB + "axe_B.gltf", "socket": "handslot.r", "base": "great_axe"},
	"axe_C": {"scene": FWB + "axe_C.gltf", "socket": "handslot.r", "base": "hand_axe"},
	"axe_D": {"scene": FWB + "axe_D.gltf", "socket": "handslot.r", "base": "great_axe"},
	"hammer_A": {"scene": FWB + "hammer_A.gltf", "socket": "handslot.r", "base": "warhammer"},
	"hammer_B": {"scene": FWB + "hammer_B.gltf", "socket": "handslot.r", "base": "warhammer", "scale": 0.9},
	"hammer_C": {"scene": FWB + "hammer_C.gltf", "socket": "handslot.r", "base": "warhammer", "scale": 0.9},
	"hammer_D": {"scene": FWB + "hammer_D.gltf", "socket": "handslot.r", "base": "warhammer"},
	"staff_A": {"scene": FWB + "staff_A.gltf", "socket": "handslot.r", "base": "arcane_staff"},
	"staff_B": {"scene": FWB + "staff_B.gltf", "socket": "handslot.r", "base": "arcane_staff"},
	"staff_C": {"scene": FWB + "staff_C.gltf", "socket": "handslot.r", "base": "druid_staff"},
	"staff_D": {"scene": FWB + "staff_D.gltf", "socket": "handslot.r", "base": "arcane_staff", "scale": 0.85},
	"wand_A": {"scene": FWB + "wand_A.gltf", "socket": "handslot.r", "base": "wand"},
	"wand_B": {"scene": FWB + "wand_B.gltf", "socket": "handslot.r", "base": "wand"},
	"bow_A_withString": {"scene": FWB + "bow_A_withString.gltf", "socket": "handslot.l", "base": "hunting_bow",
		"rot": Vector3(0.0, 90.0, 0.0)},
	"bow_B_withString": {"scene": FWB + "bow_B_withString.gltf", "socket": "handslot.l", "base": "hunting_bow",
		"rot": Vector3(0.0, 90.0, 0.0)},
	"bow_C_withString": {"scene": FWB + "bow_C_withString.gltf", "socket": "handslot.l", "base": "hunting_bow",
		"rot": Vector3(0.0, 90.0, 0.0), "scale": 0.8},
	"dagger_A": {"scene": FWB + "dagger_A.gltf", "socket": "handslot.r", "base": "dagger"},
	"dagger_B": {"scene": FWB + "dagger_B.gltf", "socket": "handslot.r", "base": "parrying_dagger"},
	"dagger_C": {"scene": FWB + "dagger_C.gltf", "socket": "handslot.r", "base": "dagger"},
	"spear_A": {"scene": FWB + "spear_A.gltf", "socket": "handslot.r", "base": "spear", "pos": Vector3(0.0, -0.35, 0.0)},
	"spear_B": {"scene": FWB + "spear_B.gltf", "socket": "handslot.r", "base": "spear", "pos": Vector3(0.0, -0.15, 0.0), "scale": 0.85},
	"halberd": {"scene": FWB + "halberd.gltf", "socket": "handslot.r", "base": "spear", "pos": Vector3(0.0, -0.2, 0.0)},
	"scythe": {"scene": FWB + "scythe.gltf", "socket": "handslot.r", "base": "scythe"},
	# FWB fist weapons point along -X; the right handslot's +X runs down the fist, so they turn
	# 180 degrees (the left hand mirrors the same row, see Character.equip)
	"fistweapon_A": {"scene": FWB + "fistweapon_A.gltf", "socket": "handslot.r", "base": "claws",
		"axes": [Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0)], "scale": 1.15},
	"fistweapon_B": {"scene": FWB + "fistweapon_B.gltf", "socket": "handslot.r", "base": "claws",
		"rot": Vector3(0.0, 180.0, 0.0)},
	"fistweapon_C_right": {"scene": FWB + "fistweapon_C_right.gltf", "socket": "handslot.r", "base": "claws", "scale": 0.85},
	"fistweapon_C_left": {"scene": FWB + "fistweapon_C_left.gltf", "socket": "handslot.l", "base": "claws", "scale": 0.85},
	"shield_A": {"scene": FWB + "shield_A.gltf", "socket": "handslot.l", "base": "round_shield"},
	"shield_B": {"scene": FWB + "shield_B.gltf", "socket": "handslot.l", "base": "round_shield", "scale": 0.85},
	"shield_C": {"scene": FWB + "shield_C.gltf", "socket": "handslot.l", "base": "round_shield", "scale": 0.85},
	"shield_D": {"scene": FWB + "shield_D.gltf", "socket": "handslot.l", "base": "spiked_shield", "scale": 0.75},
	# --- Skeletons EXTRA ----------------------------------------------------------------------
	"Skeleton_Axe": {"scene": SKW + "Skeleton_Axe.gltf", "socket": "handslot.r", "base": "hand_axe"},
	"Skeleton_Golem_Axe": {"scene": SKW + "Skeleton_Golem_Axe.gltf", "socket": "handslot.r", "base": "great_axe"},
	"Skeleton_Mace": {"scene": SKW + "Skeleton_Mace.gltf", "socket": "handslot.r", "base": "warhammer", "scale": 0.9},
	"Skeleton_Scythe": {"scene": SKW + "Skeleton_Scythe.gltf", "socket": "handslot.r", "base": "scythe"},
	"Skeleton_Dagger": {"scene": SKW + "Skeleton_Dagger.gltf", "socket": "handslot.r", "base": "dagger"},
	"Skeleton_Staff": {"scene": SKW + "Skeleton_Staff.gltf", "socket": "handslot.r", "base": "arcane_staff"},
	"Skeleton_Crossbow": {"scene": SKW + "Skeleton_Crossbow.gltf", "socket": "handslot.r", "base": "crossbow"},
	"Skeleton_Blade": {"scene": SKW + "Skeleton_Blade.gltf", "socket": "handslot.r", "base": "sword"},
	"Skeleton_Shield_Small_A": {"scene": SKW + "Skeleton_Shield_Small_A.gltf", "socket": "handslot.l", "base": "round_shield"},
	"Skeleton_Shield_Large_A": {"scene": SKW + "Skeleton_Shield_Large_A.gltf", "socket": "handslot.l", "base": "spiked_shield"},
	"Skeleton_Quiver": {"scene": SKW + "Skeleton_Quiver.gltf", "socket": "back", "base": "quiver", "rot": Vector3(0.0, 180.0, 0.0)},
	# --- Mystery Monthly S4: Paladin, Ninja -----------------------------------------------------
	"paladin_hammer": {"scene": PAL + "paladin_hammer.gltf", "socket": "handslot.r", "base": "warhammer"},
	"paladin_shield": {"scene": PAL + "paladin_shield.gltf", "socket": "handslot.l", "base": "oath_shield"},
	"Ninja_Katana": {"scene": NIN + "Ninja_Katana.gltf", "socket": "handslot.r", "base": "katana"},
	"Ninja_Shuriken": {"scene": NIN + "Ninja_Shuriken.gltf", "socket": "belt", "base": "shuriken",
		"rot": Vector3(90.0, 0.0, 0.0), "scale": 0.7},
	# --- trinkets (hip) -------------------------------------------------------------------------
	"mug_full": {"scene": ADV + "mug_full.gltf", "socket": "hip", "base": "tankard", "scale": 0.8},
	"compass_base": {"scene": RPG + "compass_base.gltf", "socket": "hip", "base": "compass",
		"rot": Vector3(90.0, 0.0, 0.0), "scale": 0.6},
	"lantern": {"scene": RPG + "lantern.gltf", "socket": "hip", "base": "lantern", "pos": Vector3(0.0, -0.28, 0.0), "scale": 0.45},
	"map_rolled": {"scene": RPG + "map_rolled.gltf", "socket": "hip", "base": "traders_map",
		"rot": Vector3(0.0, 0.0, 0.0), "scale": 0.5},
	"Gems_Sack": {"scene": "res://assets/kaykit/resources/Gems_Sack.gltf", "socket": "hip", "base": "coin_purse",
		"pos": Vector3(0.0, -0.22, 0.0), "scale": 0.36},
	"potion_medium_red": {"scene": ADX + "potion_medium_red.gltf", "socket": "hip", "base": "healers_flask",
		"pos": Vector3(0.0, 0.05, 0.0), "scale": 0.85},
	"potion_small_red": {"scene": ADX + "potion_small_red.gltf", "socket": "hip", "base": "healers_flask", "scale": 1.0},
	"potion_large_red": {"scene": ADX + "potion_large_red.gltf", "socket": "hip", "base": "healers_flask", "scale": 0.7},
	"potion_medium_blue": {"scene": ADX + "potion_medium_blue.gltf", "socket": "hip", "base": "healers_flask", "scale": 0.85},
	"potion_medium_green": {"scene": ADX + "potion_medium_green.gltf", "socket": "hip", "base": "healers_flask", "scale": 0.85},
	"key_gold": {"scene": "res://assets/kaykit/dungeon_x/key_gold.gltf", "socket": "hip", "base": "skeleton_key",
		"rot": Vector3(0.0, 0.0, -90.0), "scale": 0.55},
	"D6_A_red": {"scene": "res://assets/kaykit/boardgame/D6_A_red.gltf", "socket": "hip", "base": "loaded_die",
		"rot": Vector3(20.0, 30.0, 0.0), "scale": 0.38},
}

## Item and variant ids (§2, §3, §5, §7.3) -> model. hands / clip override the base's.
const ITEMS := {
	# Arming Sword
	"sword": {"base": "sword", "model": "sword_1handed"},
	"sword_training": {"base": "sword", "model": "sword_A"},
	"sword_knight": {"base": "sword", "model": "sword_B"},
	"sword_saber": {"base": "sword", "model": "sword_C"},
	"sword_rapier": {"base": "sword", "model": "sword_D"},
	"sword_flame": {"base": "sword", "model": "sword_F"},
	"sword_frost": {"base": "sword", "model": "sword_G"},
	# Greatsword
	"greatsword": {"base": "greatsword", "model": "sword_2handed_color"},
	"greatsword_plain": {"base": "greatsword", "model": "sword_2handed"},
	"greatsword_zwei": {"base": "greatsword", "model": "sword_E"},
	# Hand Axe
	"hand_axe": {"base": "hand_axe", "model": "axe_1handed"},
	"axe_twinbit": {"base": "hand_axe", "model": "axe_A"},
	"axe_cleaver": {"base": "hand_axe", "model": "axe_C"},
	"axe_bone": {"base": "hand_axe", "model": "Skeleton_Axe"},
	# Great Axe
	"great_axe": {"base": "great_axe", "model": "axe_2handed"},
	"axe_war": {"base": "great_axe", "model": "axe_B"},
	"axe_jagged": {"base": "great_axe", "model": "axe_D"},
	"axe_golem": {"base": "great_axe", "model": "Skeleton_Golem_Axe"},
	# Warhammer
	"warhammer": {"base": "warhammer", "model": "paladin_hammer"},
	"hammer_smith": {"base": "warhammer", "model": "hammer_A"},
	"hammer_morningstar": {"base": "warhammer", "model": "hammer_B"},
	"hammer_club": {"base": "warhammer", "model": "hammer_C"},
	"hammer_mallet": {"base": "warhammer", "model": "hammer_D", "hands": 2, "style": "melee_2h",
		"clip": "Melee_2H_Attack_Chop"},
	"hammer_bone": {"base": "warhammer", "model": "Skeleton_Mace"},
	# Spear
	"spear": {"base": "spear", "model": "spear_A"},
	"spear_halberd": {"base": "spear", "model": "halberd"},
	"spear_trident": {"base": "spear", "model": "spear_B"},
	# Scythe
	"scythe": {"base": "scythe", "model": "scythe"},
	"scythe_bone": {"base": "scythe", "model": "Skeleton_Scythe"},
	# Dagger
	"dagger": {"base": "dagger", "model": "dagger"},
	"dagger_leaf": {"base": "dagger", "model": "dagger_A"},
	"dagger_venom": {"base": "dagger", "model": "dagger_C"},
	"dagger_bone": {"base": "dagger", "model": "Skeleton_Dagger"},
	# Katana
	"katana": {"base": "katana", "model": "Ninja_Katana"},
	# Arcane Staff
	"arcane_staff": {"base": "arcane_staff", "model": "staff"},
	"staff_quarter": {"base": "arcane_staff", "model": "staff_A"},
	"staff_frost": {"base": "arcane_staff", "model": "staff_B"},
	"staff_sun": {"base": "arcane_staff", "model": "staff_D"},
	"staff_bone": {"base": "arcane_staff", "model": "Skeleton_Staff"},
	# Druid Staff
	"druid_staff": {"base": "druid_staff", "model": "druid_staff"},
	"staff_living": {"base": "druid_staff", "model": "staff_C"},
	# Wand
	"wand": {"base": "wand", "model": "wand"},
	"wand_sapphire": {"base": "wand", "model": "wand_A"},
	"wand_orb": {"base": "wand", "model": "wand_B"},
	# Hunting Bow
	"hunting_bow": {"base": "hunting_bow", "model": "bow_withString"},
	"bow_short": {"base": "hunting_bow", "model": "bow_A_withString"},
	"bow_composite": {"base": "hunting_bow", "model": "bow_B_withString"},
	"bow_long": {"base": "hunting_bow", "model": "bow_C_withString"},
	# Crossbow
	"crossbow": {"base": "crossbow", "model": "crossbow_1handed"},
	"crossbow_arbalest": {"base": "crossbow", "model": "crossbow_2handed", "hands": 2, "clip": "Ranged_2H_Shoot"},
	"crossbow_bone": {"base": "crossbow", "model": "Skeleton_Crossbow"},
	# Claws (the left claw is added when the off hand is free)
	"claws": {"base": "claws", "model": "fistweapon_C_right", "model_left": "fistweapon_C_left"},
	"claws_knuckles": {"base": "claws", "model": "fistweapon_A", "model_left": "fistweapon_A"},
	"claws_gauntlet": {"base": "claws", "model": "fistweapon_B", "model_left": "fistweapon_B"},
	# Wrench
	"wrench": {"base": "wrench", "model": "engineer_Wrench"},
	# --- off-hands ----------------------------------------------------------------------------
	"round_shield": {"base": "round_shield", "model": "shield_round_color"},
	"round_shield_badge": {"base": "round_shield", "model": "shield_badge_color"},
	"shield_plank": {"base": "round_shield", "model": "shield_A"},
	"shield_heraldic": {"base": "round_shield", "model": "shield_B"},
	"shield_tower": {"base": "round_shield", "model": "shield_C"},
	"shield_bone": {"base": "round_shield", "model": "Skeleton_Shield_Small_A"},
	"spiked_shield": {"base": "spiked_shield", "model": "shield_spikes_color"},
	"shield_dragon": {"base": "spiked_shield", "model": "shield_D"},
	"shield_bone_large": {"base": "spiked_shield", "model": "Skeleton_Shield_Large_A"},
	"oath_shield": {"base": "oath_shield", "model": "paladin_shield"},
	"parrying_dagger": {"base": "parrying_dagger", "model": "dagger"},
	"parry_sai": {"base": "parrying_dagger", "model": "dagger_B"},
	# the open book in the free hand; closed on the belt behind a 2H weapon
	"spellbook": {"base": "spellbook", "model": "spellbook_open", "model_2h": "spellbook_closed"},
	"quiver": {"base": "quiver", "model": "quiver"},
	"quiver_bone": {"base": "quiver", "model": "Skeleton_Quiver"},
	"smoke_bomb": {"base": "smoke_bomb", "model": "smokebomb"},
	"shuriken": {"base": "shuriken", "model": "Ninja_Shuriken"},
	# --- trinkets -----------------------------------------------------------------------------
	"tankard": {"base": "tankard", "model": "mug_full"},
	"compass": {"base": "compass", "model": "compass_base"},
	"lantern": {"base": "lantern", "model": "lantern"},
	"coin_purse": {"base": "coin_purse", "model": "Gems_Sack"},
	"traders_map": {"base": "traders_map", "model": "map_rolled"},
	"healers_flask": {"base": "healers_flask", "model": "potion_medium_red"},
	"skeleton_key": {"base": "skeleton_key", "model": "key_gold"},
	"loaded_die": {"base": "loaded_die", "model": "D6_A_red"},
}

## Head pieces (§4.1, §5.3): donor GLB + mesh node names. covers_head: the piece replaces the
## whole head (the Paladin helmet ships without a face under it), so the hero's head hides too.
const HEADS := {
	"knight_helm": {"glb": CHR + "Knight.glb", "parts": ["Knight_Helmet", "Knight_HelmetVisor"]},
	"paladin_helm": {"glb": MON + "paladin/Paladin_with_Helmet.glb", "parts": ["Paladin_Helmet"], "covers_head": true},
	"wizard_hat": {"glb": CHR + "Mage.glb", "parts": ["Mage_Hat"]},
	"bear_hat": {"glb": CHR + "Barbarian.glb", "parts": ["Barbarian_BearHat"]},
	"goggles": {"glb": CHX + "Engineer.glb", "parts": ["Engineer_Goggles"]},
	"ninja_headband": {"glb": MON + "ninja/Ninja.glb", "parts": ["Ninja_Headband"]},
	"ninja_mask": {"glb": MON + "ninja/Ninja.glb", "parts": ["Ninja_Mask", "Ninja_Headband"]},
	"bandit_mask": {"glb": CHR + "Rogue_Hooded.glb", "parts": ["RogueHooded_Mask"]},
	"bone_crown": {"glb": SKL + "Necromancer.glb", "parts": ["Necromancer_Crown"]},
	"helm_bone": {"glb": SKL + "Skeleton_Warrior.glb", "parts": ["Skeleton_Warrior_Helmet"]},
	"hat_grave": {"glb": SKL + "Skeleton_Mage.glb", "parts": ["Skeleton_Mage_Hat"]},
	"hood_grave": {"glb": SKL + "Skeleton_Rogue.glb", "parts": ["Skeleton_Rogue_Hood"]},
}

## Body pieces (§4.2, §4.3): torso + both arms as one set. The Dino Suit also takes the head.
const BODIES := {
	"knight_plate": {"glb": CHR + "Knight.glb", "parts": ["Knight_Body", "Knight_ArmLeft", "Knight_ArmRight"]},
	"paladin_cuirass": {"glb": MON + "paladin/Paladin.glb", "parts": ["Paladin_Body", "Paladin_ArmLeft", "Paladin_ArmRight"]},
	"barbarian_harness": {"glb": CHR + "Barbarian.glb", "parts": ["Barbarian_Body", "Barbarian_ArmLeft", "Barbarian_ArmRight"]},
	"mage_robe": {"glb": CHR + "Mage.glb", "parts": ["Mage_Body", "Mage_ArmLeft", "Mage_ArmRight"]},
	"rogue_leathers": {"glb": CHR + "Rogue.glb", "parts": ["Rogue_Body", "Rogue_ArmLeft", "Rogue_ArmRight"]},
	"ranger_tunic": {"glb": CHR + "Ranger.glb", "parts": ["Ranger_Body", "Ranger_ArmLeft", "Ranger_ArmRight"]},
	"ninja_gi": {"glb": MON + "ninja/Ninja.glb", "parts": ["Ninja_Chest", "Ninja_ArmLeft", "Ninja_ArmRight"]},
	"druid_robe": {"glb": CHX + "Druid.glb", "parts": ["Druid_Body", "Druid_ArmLeft", "Druid_ArmRight"]},
	"engineer_overalls": {"glb": CHX + "Engineer.glb", "parts": ["Engineer_Body", "Engineer_ArmLeft", "Engineer_ArmRight"]},
	"hooded_robe": {"glb": CHR + "Rogue_Hooded.glb", "parts": ["RogueHooded_Body", "RogueHooded_ArmLeft", "RogueHooded_ArmRight"]},
	"dino_suit": {"glb": MON + "monster/MonsterCostume.glb",
		"parts": ["MonsterCostume_Body", "MonsterCostume_ArmLeft", "MonsterCostume_ArmRight", "MonsterCostume_Head"],
		"covers_head": true},
}

## Back pieces (§4.5): no stats yet. large: Rig_Large donor (fit-tested, see ArmorBinder);
## texture: the donor GLB has no embedded atlas.
const BACKS := {
	"knight_cape": {"glb": CHR + "Knight.glb", "parts": ["Knight_Cape"]},
	"mage_cape": {"glb": CHR + "Mage.glb", "parts": ["Mage_Cape"]},
	"ranger_cape": {"glb": CHR + "Ranger.glb", "parts": ["Ranger_Cape"]},
	"rogue_cape": {"glb": CHR + "Rogue.glb", "parts": ["Rogue_Cape"]},
	"hooded_cape": {"glb": CHR + "Rogue_Hooded.glb", "parts": ["RogueHooded_Cape"]},
	"paladin_cape": {"glb": MON + "paladin/Paladin.glb", "parts": ["Paladin_Cape"]},
	"druid_backpack": {"glb": CHX + "Druid.glb", "parts": ["Druid_Backpack"]},
	"engineer_backpack": {"glb": CHX + "Engineer.glb", "parts": ["Engineer_Backpack"]},
	"bone_cloak": {"glb": SKL + "Skeleton_Warrior.glb", "parts": ["Skeleton_Warrior_Cloak"]},
	"tattered_cloak": {"glb": SKL + "Skeleton_Minion.glb", "parts": ["Skeleton_Minion_Cloak"]},
	"grave_cape": {"glb": SKL + "Skeleton_Rogue.glb", "parts": ["Skeleton_Rogue_Cape"]},
	# OrcRaider.glb ships without its atlas (Character.MODELS.orc sets it too)
	"orc_warpack": {"glb": MON + "orc/OrcRaider.glb", "parts": ["Orc_Warpack"],
		"texture": MON + "orc/textures/orc_texture_A.png"},
	"bear_pelt": {"glb": CHX + "Barbarian_Large.glb", "parts": ["Barbarian_Large_BearPelt"], "large": true},
}


## Item row for an ITEMS id or a raw MOUNTS model id ({} if unknown).
static func item(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	if MOUNTS.has(id):
		return {"base": String(MOUNTS[id].get("base", "")), "model": id}
	return {}


## Base row of an item id / model id ({} if unknown).
static func base_of(id: String) -> Dictionary:
	return BASES.get(String(item(id).get("base", "")), {})


## Hands (1 | 2) of a weapon id; 0 when unknown / not a weapon.
static func hands(id: String) -> int:
	var it := item(id)
	if it.is_empty():
		return 0
	return int(it.get("hands", base_of(id).get("hands", 0)))


## Character.ATTACKS alias of a weapon id ("" when unknown).
static func style(id: String) -> String:
	var it := item(id)
	return String(it.get("style", base_of(id).get("style", "")))


## Attack clip of a weapon id ("" when unknown).
static func clip(id: String) -> String:
	var it := item(id)
	return String(it.get("clip", base_of(id).get("clip", "")))


## Mount row for a model: {scene, socket, xform (socket-local Transform3D)}. `socket` overrides
## the row's own (a dagger in the off hand goes to handslot.l).
static func mount(model_id: String, socket := "") -> Dictionary:
	var r: Dictionary = MOUNTS.get(model_id, {})
	if r.is_empty():
		return {}
	var rot: Vector3 = r.get("rot", Vector3.ZERO)
	var s := float(r.get("scale", 1.0))
	var basis := _basis(rot, s)
	if r.has("axes"):
		basis = Basis(r.axes[0], r.axes[1], r.axes[2]).orthonormalized().scaled(Vector3.ONE * s)
	return {"scene": String(r.scene), "socket": socket if socket != "" else String(r.socket),
		"xform": Transform3D(basis, r.get("pos", Vector3.ZERO))}


## [bone, Transform3D] of a socket (an unknown socket is a bone name with no offset).
static func socket(name: String) -> Array:
	var r: Array = SOCKETS.get(name, [name, Vector3.ZERO, Vector3.ZERO])
	return [String(r[0]), Transform3D(_basis(r[2], 1.0), r[1])]


static func _basis(rot_deg: Vector3, s: float) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))).scaled(Vector3.ONE * s)


## Armor piece row for a slot ("head" | "body" | "back"), {} if unknown.
static func piece(slot: String, id: String) -> Dictionary:
	match slot:
		"head":
			return HEADS.get(id, {})
		"body":
			return BODIES.get(id, {})
		"back":
			return BACKS.get(id, {})
	return {}


## Every scene path referenced here (MOUNTS scenes + armor donor GLBs), for asset checks.
static func all_scenes() -> PackedStringArray:
	var out := PackedStringArray()
	for m in MOUNTS:
		out.append(String(MOUNTS[m].scene))
	for t in [HEADS, BODIES, BACKS]:
		for id in t:
			if not out.has(String(t[id].glb)):
				out.append(String(t[id].glb))
	return out
