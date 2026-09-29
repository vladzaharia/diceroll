class_name ItemDefs
extends RefCounted
## The real-item Armory (docs/design/2026-09-29-armory-items.md): every item, variant, rank and
## price. Pure data plus lookups; the rules live in core/item_logic.gd (ItemLogic), the profile
## side in core/meta/profile.gd (Profile.armory) and core/meta/camp.gd, the run side in
## MetaRun.build (meta.items). Presentation looks live in game/actors/item_mounts.gd and use the
## same ids.
##
## Slots: weapon, offhand, head, body, trinket, trinket2 (the Belt Pouch), back (Style only).
## Rank groups (R0..8, 730 Crowns each): weapon, offhand, armor (head + body), trinket. A group at
## R0 is not crafted: its items are shown but do nothing. Tier: I at R1-3, II at R4-7, III at R8;
## class affinity +1 tier (cap III) on the class's own kit; the 2nd trinket works a tier lower
## (min I) with no rank breakpoints.
##
## ITEMS[id] = {name, slot, hands (weapons), mount (off-hands: hand|belt|back), style (weapons),
##   model, affinity: [class ids], std: "x1.2" | "block2" | "" (what the Standard variant adds),
##   effect: {rule, name, desc, n: {key: [I, II, III]}, scale: [keys the Standard x1.2 scales]}
##   ({} for Back items), cosmetic (Back items), part (armor donor part names, presentation)}
## VARIANTS[variant id] = {item, name, model, sec, sec_name, desc, unlock, [hands], [n]}
##   unlock: {mastery: 15|45|90} | {feat: id} | {class: id, or_mastery: n} (the class's kit)
##   The Standard variant of an item has the item's own id (implicit, never in VARIANTS).

const SLOTS := ["weapon", "offhand", "head", "body", "trinket", "trinket2", "back"]
const STAT_SLOTS := ["weapon", "offhand", "head", "body", "trinket", "trinket2"]
const GROUPS := ["weapon", "offhand", "armor", "trinket"]
const GROUP_OF := {"weapon": "weapon", "offhand": "offhand", "head": "armor", "body": "armor",
	"trinket": "trinket", "trinket2": "trinket"}
## Legacy gear piece -> rank group (profile v2 -> v3 and the old "gear" unlock ids).
const LEGACY_GROUP := {"blade": "weapon", "helm": "armor", "boots": "offhand", "charm": "trinket"}

const RANK_MAX := 8
const RANK_COSTS := [15, 25, 40, 70, 100, 130, 160, 190]
## Base stats: +1 ATK at Weapon R8; +0.5 max HP per Armor rank (cap +4).
## The Weapon rank's base stat: the design's +1 ATK at R8 measured +4.4 pp by itself (the design
## budgeted 2-3 pp for ATK and HP together), which left the max band no room for the items; the
## weapon's tier is the Weapon rank's reward instead (docs/plans/balance.md, Armory).
const ATK_RANK := 8
static var ATK_BONUS := 0
## Armor rank: max HP per rank and the cap (the design's 0.5 / +4, halved for the same budget).
static var HP_PER_RANK := 0.25
static var HP_CAP := 2
## Sim-only analysis dials (tools/sim.gd --strip=affinity / --strip=pouch-tier): class affinity
## tiers and the Belt Pouch's tier penalty. The defaults ARE the shipped rules.
static var AFFINITY := 1
static var POUCH_TIER := 1
## Sim-only number overrides (tools/sim.gd --item=<item>.<key>=I/II/III or <variant>.<key>=v):
## "item.key" -> [I, II, III] rule numbers, "variant.key" -> a secondary number.
static var TUNE := {}
## The Standard variant of a count-based item: Block on turn 1 of elite, mini-boss and boss fights
## (one Block total however many such Standards are equipped). The design's Block 2 on every
## fight's turn 1 measured +2-3 pp per item, above every variant (docs/plans/balance.md, Armory).
static var STD_BLOCK := 1
## Belt Pouch: the 2nd trinket slot.
const POUCH_COST := 400
const POUCH_RANK := 5
## Compass: +1 board reroll per biome from this Trinket rank, in slot 1 only.
const COMPASS_REROLL_RANK := 6
## Mastery: fights won with the base item equipped; blueprint thresholds and their craft costs.
const MASTERY := [15, 45, 90]
const CRAFT_COSTS := [60, 90, 120]
const FEAT_CRAFT := 120
const CRAFT_SIGILS := 2
## Shop prices (Crowns) and the Sigil alternative.
const ITEM_SIGILS := 4
const KIT_PRICE := 150
const BACK_PRICE := 60
const BACK_SIGILS := 2
const PRICES := {"greatsword": 120, "spear": 120, "scythe": 120, "wand": 100, "spiked_shield": 100,
	"smoke_bomb": 100, "traders_map": 100, "skeleton_key": 140, "loaded_die": 160}
## Skeleton enemies (the "skeleton_kills" counter: Bone Collector, the bone variants).
const SKELETONS := ["skeleton_minion", "skeleton_warrior", "skeleton_archer", "frost_skeleton", "bone_cutthroat",
	"bone_knight", "bone_golem"]
const SKELETON_KILLS := 300

## Class signature kits (§6): weapon [id, variant], off-hand, head, body, back. "" = empty.
## Appearance defaults: Paladin head hidden (helmet-less look), everyone else "own".
const KITS := {
	"knight": {"weapon": ["sword", "sword"], "offhand": ["round_shield", "round_shield"], "head": ["knight_helm", "knight_helm"],
		"body": "knight_plate", "back": "knight_cape"},
	"barbarian": {"weapon": ["great_axe", "great_axe"], "offhand": ["", ""], "head": ["bear_hat", "bear_hat"],
		"body": "barbarian_harness", "back": ""},
	"mage": {"weapon": ["arcane_staff", "arcane_staff"], "offhand": ["spellbook", "spellbook"], "head": ["wizard_hat", "wizard_hat"],
		"body": "mage_robe", "back": "mage_cape"},
	"rogue": {"weapon": ["dagger", "dagger"], "offhand": ["parrying_dagger", "parrying_dagger"], "head": ["bandit_mask", "bandit_mask"],
		"body": "rogue_leathers", "back": "rogue_cape"},
	"paladin": {"weapon": ["warhammer", "warhammer"], "offhand": ["oath_shield", "oath_shield"], "head": ["paladin_helm", "paladin_helm"],
		"body": "paladin_cuirass", "back": "paladin_cape"},
	"ranger": {"weapon": ["hunting_bow", "hunting_bow"], "offhand": ["quiver", "quiver"], "head": ["", ""],
		"body": "ranger_tunic", "back": "ranger_cape"},
	"ninja": {"weapon": ["katana", "katana"], "offhand": ["shuriken", "shuriken"], "head": ["ninja_headband", "ninja_headband"],
		"body": "ninja_gi", "back": ""},
	"druid": {"weapon": ["druid_staff", "druid_staff"], "offhand": ["", ""], "head": ["", ""],
		"body": "druid_robe", "back": "druid_backpack"},
	"engineer": {"weapon": ["wrench", "wrench"], "offhand": ["", ""], "head": ["goggles", "goggles"],
		"body": "engineer_overalls", "back": "engineer_backpack"},
	"necromancer": {"weapon": ["arcane_staff", "staff_bone"], "offhand": ["", ""], "head": ["bone_crown", "bone_crown"],
		"body": "hooded_robe", "back": "hooded_cape"},
	"monster_kid": {"weapon": ["claws", "claws"], "offhand": ["", ""], "head": ["", ""], "body": "dino_suit", "back": ""},
}
const APPEARANCE_DEFAULT := {"paladin": {"head": "hidden"}}
## The class whose Head and Body are locked to one combined piece.
const LOCKED_ARMOR := {"monster_kid": "dino_suit"}
## Fresh-profile items (the Knight kit comes with the Knight class) and the milestone grants.
const STARTER_ITEMS := ["tankard"]

const ITEMS := {
	# ---------------------------------------------------------------- weapons (§2)
	"sword": {"name": "Arming Sword", "slot": "weapon", "hands": 1, "style": "melee_1h", "model": "sword_1handed",
		"affinity": ["knight"], "std": "x1.2",
		"effect": {"rule": "twin_edge", "name": "Twin Edge", "desc": "Pair or Two Pair: +{flat} damage after the multiplier ({uses} per fight).",
			"n": {"flat": [1, 1, 1], "uses": [1, 1, 1]}, "scale": ["flat"]}},
	"greatsword": {"name": "Greatsword", "slot": "weapon", "hands": 2, "style": "melee_2h", "model": "sword_2handed_color",
		"affinity": [], "std": "x1.2",
		"effect": {"rule": "great_arc", "name": "Great Arc", "desc": "Three of a Kind or better: combo multiplier +{mult}.",
			"n": {"mult": [0.05, 0.05, 0.1]}, "scale": ["mult"]}},
	"hand_axe": {"name": "Hand Axe", "slot": "weapon", "hands": 1, "style": "melee_1h", "model": "axe_1handed",
		"affinity": [], "std": "x1.2",
		"effect": {"rule": "cleave", "name": "Cleave", "desc": "A kill carries {pct%} of the excess damage to the next enemy.",
			"n": {"pct": [0.1, 0.15, 0.2]}, "scale": ["pct"]}},
	"great_axe": {"name": "Great Axe", "slot": "weapon", "hands": 2, "style": "melee_2h", "model": "axe_2handed",
		"affinity": ["barbarian"], "std": "x1.2",
		"effect": {"rule": "rampage", "name": "Rampage",
			"desc": "Each consecutive attack on the same target: +{per} damage, stacking to {stacks}; resets on a target change or kill.",
			"n": {"per": [1, 1, 1], "stacks": [1, 2, 3]}, "scale": []}},
	"warhammer": {"name": "Warhammer", "slot": "weapon", "hands": 1, "style": "melee_1h", "model": "paladin_hammer",
		"affinity": ["paladin"], "std": "x1.2",
		"effect": {"rule": "crush", "name": "Crush",
			"desc": "The highest die in the scoring group (never a Heavy die) counts x{crush}; the extra pips add after the multiplier ({uses} per fight).",
			"n": {"crush": [1.15, 1.2, 1.25], "uses": [1, 1, 1]}, "scale": ["crush"]}},
	"spear": {"name": "Spear", "slot": "weapon", "hands": 2, "style": "spear", "model": "spear_A",
		"affinity": [], "std": "x1.2",
		"effect": {"rule": "first_strike", "name": "First Strike",
			"desc": "The first attack of each fight deals x{factor} (x{boss_factor} against a final boss).",
			"n": {"factor": [1.02, 1.03, 1.05], "boss": [0.03, 0.03, 0.05]}, "scale": ["factor"]}},
	"scythe": {"name": "Scythe", "slot": "weapon", "hands": 2, "style": "scythe", "model": "scythe",
		"affinity": [], "std": "x1.2",
		"effect": {"rule": "reap", "name": "Reap", "desc": "The first kill of each fight heals {heal}.",
			"n": {"heal": [1, 1, 1], "uses": [1, 1, 1]}, "scale": ["heal"]}},
	"dagger": {"name": "Dagger", "slot": "weapon", "hands": 1, "style": "melee_1h", "model": "dagger",
		"affinity": ["rogue"], "std": "block2",
		"effect": {"rule": "quick_hands", "name": "Quick Hands", "desc": "+1 combat reroll on turns 1-{turns}.",
			"n": {"turns": [1, 1, 1]}, "scale": []}},
	"katana": {"name": "Katana", "slot": "weapon", "hands": 1, "style": "melee_1h", "model": "Ninja_Katana",
		"affinity": ["ninja"], "std": "block2",
		"effect": {"rule": "flow", "name": "Flow", "desc": "A turn with {dice}+ dice rerolled: +{flat} damage after the multiplier ({uses} per fight).",
			"n": {"dice": [2, 2, 2], "flat": [1, 1, 1], "uses": [1, 1, 1]}, "scale": []}},
	"arcane_staff": {"name": "Arcane Staff", "slot": "weapon", "hands": 2, "style": "magic", "model": "staff",
		"affinity": ["mage", "necromancer"], "std": "x1.2",
		"effect": {"rule": "channel", "name": "Channel", "desc": "Runed dice in the scoring group: +{pip} damage each after the multiplier (max {max}; {uses} per fight).",
			"n": {"pip": [1, 1, 1], "max": [1, 1, 1], "uses": [1, 1, 1]}, "scale": []}},
	"druid_staff": {"name": "Druid Staff", "slot": "weapon", "hands": 2, "style": "magic", "model": "druid_staff",
		"affinity": ["druid"], "std": "block2",
		"effect": {"rule": "grove", "name": "Grove", "desc": "At each biome change, raise the lowest face of {dice} dice by 1.",
			"n": {"dice": [1, 1, 1]}, "scale": []}},
	"wand": {"name": "Wand", "slot": "weapon", "hands": 1, "style": "magic", "model": "wand",
		"affinity": [], "std": "x1.2",
		"effect": {"rule": "spark", "name": "Spark", "desc": "The first attack each fight with a multiplier of 2+: +{mult} multiplier.",
			"n": {"mult": [0.05, 0.1, 0.15]}, "scale": ["mult"]}},
	"hunting_bow": {"name": "Hunting Bow", "slot": "weapon", "hands": 2, "style": "bow", "model": "bow_withString",
		"affinity": ["ranger"], "std": "x1.2",
		"effect": {"rule": "opening_volley", "name": "Opening Volley",
			"desc": "At fight start, shoot a random enemy for {dmg} (+15% per lap after the first).",
			"n": {"dmg": [1, 1, 2]}, "scale": ["dmg"]}},
	"crossbow": {"name": "Crossbow", "slot": "weapon", "hands": 1, "style": "crossbow", "model": "crossbow_1handed",
		"affinity": [], "std": "x1.2",
		"effect": {"rule": "deadshot", "name": "Deadshot", "desc": "High Roller: +{flat} damage after the multiplier.",
			"n": {"flat": [1, 1, 2]}, "scale": ["flat"]}},
	"claws": {"name": "Claws", "slot": "weapon", "hands": 1, "style": "unarmed", "model": "fistweapon_C_right",
		"affinity": ["monster_kid"], "std": "x1.2",
		"effect": {"rule": "scrap", "name": "Scrap", "desc": "2+ dice showing 1 or 2: +{per} damage after the multiplier ({uses} per fight).",
			"n": {"dice": [2, 2, 2], "per": [1, 1, 2], "uses": [1, 2, 2]}, "scale": []}},
	"wrench": {"name": "Wrench", "slot": "weapon", "hands": 1, "style": "melee_1h", "model": "engineer_Wrench",
		"affinity": ["engineer"], "std": "block2",
		"effect": {"rule": "tinker", "name": "Tinker",
			"desc": "Shop Face Raises cost {raise_price}.",
			"n": {"edits": [0, 0, 0], "raise_price": [22, 20, 20]}, "scale": []}},
	# ---------------------------------------------------------------- off-hands (§3)
	"round_shield": {"name": "Round Shield", "slot": "offhand", "mount": "hand", "model": "shield_round_color",
		"affinity": ["knight"], "std": "x1.2",
		"effect": {"rule": "bulwark", "name": "Bulwark",
			"desc": "Block {block} on turn 1. Tier III: Last Stand (once per run, survive a lethal hit at 1 HP from above 50%).",
			"n": {"block": [1, 1, 1], "last_stand": [0, 0, 1]}, "scale": ["block"]}},
	"spiked_shield": {"name": "Spiked Shield", "slot": "offhand", "mount": "hand", "model": "shield_spikes_color",
		"affinity": [], "std": "x1.2",
		"effect": {"rule": "thorns", "name": "Thorns", "desc": "An enemy whose attack hits you or your Block takes {thorns}.",
			"n": {"thorns": [1, 1, 1]}, "scale": ["thorns"]}},
	"oath_shield": {"name": "Oath Shield", "slot": "offhand", "mount": "hand", "model": "paladin_shield",
		"affinity": ["paladin"], "std": "x1.2",
		"effect": {"rule": "aegis", "name": "Aegis", "desc": "A Pair or better grants Block = the set's value x{x} ({uses} per fight).",
			"n": {"x": [0.1, 0.15, 0.2], "uses": [1, 1, 1]}, "scale": ["x"]}},
	"parrying_dagger": {"name": "Parrying Dagger", "slot": "offhand", "mount": "hand", "model": "dagger",
		"affinity": ["rogue"], "std": "block2",
		"effect": {"rule": "steady", "name": "Steady", "desc": "Keep {dice}+ dice unrerolled: +1 damage after the multiplier ({uses} per fight).",
			"n": {"dice": [3, 3, 3], "uses": [1, 1, 1]}, "scale": []}},
	"spellbook": {"name": "Spellbook", "slot": "offhand", "mount": "belt", "model": "spellbook_open",
		"affinity": ["mage"], "std": "x1.2",
		"effect": {"rule": "tome", "name": "Tome", "desc": "The 3rd attack of each fight: combo multiplier +{mult}.",
			"n": {"mult": [0.05, 0.05, 0.1]}, "scale": ["mult"]}},
	"quiver": {"name": "Quiver", "slot": "offhand", "mount": "back", "model": "quiver",
		"affinity": ["ranger"], "std": "x1.2",
		"effect": {"rule": "spare_arrows", "name": "Spare Arrows",
			"desc": "Every 3rd attack also shoots a random enemy for {dmg} (+15% per lap after the first).",
			"n": {"dmg": [1, 1, 2]}, "scale": ["dmg"]}},
	"smoke_bomb": {"name": "Smoke Bomb", "slot": "offhand", "mount": "belt", "model": "smokebomb",
		"affinity": [], "std": "x1.2",
		"effect": {"rule": "vanish", "name": "Vanish", "desc": "The first enemy attack of each fight deals {pct%} less (max {max}).",
			"n": {"pct": [0.2, 0.25, 0.3], "max": [1, 1, 1]}, "scale": ["pct"]}},
	"shuriken": {"name": "Shuriken", "slot": "offhand", "mount": "belt", "model": "Ninja_Shuriken",
		"affinity": ["ninja"], "std": "x1.2",
		"effect": {"rule": "barrage", "name": "Barrage",
			"desc": "Each rerolled die deals {dmg} to a random enemy, max {max} per fight.",
			"n": {"dmg": [1, 1, 1], "max": [1, 1, 1]}, "scale": []}},
	# ---------------------------------------------------------------- head (§4.1)
	"knight_helm": {"name": "Knight Helm", "slot": "head", "model": "Knight_Helmet", "affinity": ["knight"], "std": "x1.2",
		"effect": {"rule": "steadfast", "name": "Steadfast",
			"desc": "When a rune or item gives you Block: +{extra} more (once per turn, {uses} turn(s) per fight).",
			"n": {"extra": [1, 1, 1], "uses": [1, 1, 1]}, "scale": []}},
	"paladin_helm": {"name": "Paladin Helm", "slot": "head", "model": "Paladin_Helmet", "affinity": ["paladin"], "std": "x1.2",
		"effect": {"rule": "vow", "name": "Vow", "desc": "Three of a Kind or better heals {heal}, {uses} time(s) per fight.",
			"n": {"heal": [1, 1, 1], "uses": [1, 1, 1]}, "scale": []}},
	"wizard_hat": {"name": "Wizard Hat", "slot": "head", "model": "Mage_Hat", "affinity": ["mage"], "std": "block2",
		"effect": {"rule": "arcana", "name": "Arcana",
			"desc": "On turns 1-{turns} the first rune trigger fires twice (never re-doubles Resonance or Rune Echo).",
			"n": {"turns": [1, 1, 1]}, "scale": []}},
	"bear_hat": {"name": "Bear Hat", "slot": "head", "model": "Barbarian_BearHat", "affinity": ["barbarian"], "std": "x1.2",
		"effect": {"rule": "ferocity", "name": "Ferocity", "desc": "Below 50% HP: +{flat} damage.",
			"n": {"flat": [1, 2, 2]}, "scale": ["flat"]}},
	"goggles": {"name": "Engineer Goggles", "slot": "head", "model": "Engineer_Goggles", "affinity": ["engineer"], "std": "x1.2",
		"effect": {"rule": "appraise", "name": "Appraise", "desc": "Shop dice cost {pct%} less.",
			"n": {"pct": [0.05, 0.1, 0.1]}, "scale": ["pct"]}},
	"ninja_headband": {"name": "Ninja Headband", "slot": "head", "model": "Ninja_Headband", "affinity": ["ninja"], "std": "block2",
		"effect": {"rule": "focus", "name": "Focus",
			"desc": "A reroll of exactly one die is free, {uses} per fight.",
			"n": {"uses": [1, 1, 1], "per_turn": [0, 0, 0]}, "scale": []}},
	"bandit_mask": {"name": "Bandit Mask", "slot": "head", "model": "RogueHooded_Mask", "affinity": ["rogue"], "std": "x1.2",
		"effect": {"rule": "ambush", "name": "Ambush", "desc": "After a board move on doubles, the next fight's first attack deals x{factor}.",
			"n": {"factor": [1.02, 1.03, 1.04]}, "scale": ["factor"]}},
	"bone_crown": {"name": "Bone Crown", "slot": "head", "model": "Necromancer_Crown", "affinity": ["necromancer"], "std": "x1.2",
		"effect": {"rule": "dominion", "name": "Dominion",
			"desc": "Each kill: +1 damage on your next attack, stacking to {max}.",
			"n": {"max": [1, 2, 2]}, "scale": ["max"]}},
	# ---------------------------------------------------------------- body (§4.2, §4.3; one mesh each, no variants)
	"knight_plate": {"name": "Knight Plate", "slot": "body", "model": "Knight_Body", "affinity": ["knight"], "std": "",
		"effect": {"rule": "plated", "name": "Plated", "desc": "Block {block} at the start of combat turns 1-{turns}.",
			"n": {"block": [1, 1, 1], "turns": [1, 1, 1]}, "scale": []}},
	"paladin_cuirass": {"name": "Paladin Cuirass", "slot": "body", "model": "Paladin_Body", "affinity": ["paladin"], "std": "",
		"effect": {"rule": "blessed", "name": "Blessed", "desc": "Two Pair or better heals {heal}, {uses} time(s) per fight.",
			"n": {"heal": [1, 1, 1], "uses": [1, 1, 1]}, "scale": []}},
	"barbarian_harness": {"name": "Barbarian Harness", "slot": "body", "model": "Barbarian_Body", "affinity": ["barbarian"], "std": "",
		"effect": {"rule": "brawn", "name": "Brawn", "desc": "Heavy dice in the attack: +{pips} damage each after the multiplier (max {dice}).",
			"n": {"pips": [1, 1, 1], "dice": [2, 2, 2]}, "scale": []}},
	"mage_robe": {"name": "Mage Robe", "slot": "body", "model": "Mage_Body", "affinity": ["mage"], "std": "",
		"effect": {"rule": "rune_woven", "name": "Rune-woven", "desc": "Ember deals +{dmg}; tier III: Thunder too.",
			"n": {"dmg": [1, 1, 1], "thunder": [0, 0, 1], "poison": [0, 0, 0]}, "scale": []}},
	"rogue_leathers": {"name": "Rogue Leathers", "slot": "body", "model": "Rogue_Body", "affinity": ["rogue"], "std": "",
		"effect": {"rule": "nimble", "name": "Nimble", "desc": "Keep 2+ dice all turn: bank +1 reroll, {max} time(s) per fight.",
			"n": {"max": [1, 1, 1]}, "scale": []}},
	"ranger_tunic": {"name": "Ranger Tunic", "slot": "body", "model": "Ranger_Body", "affinity": ["ranger"], "std": "",
		"effect": {"rule": "hunter", "name": "Hunter", "desc": "+{flat} damage against enemies at full HP.",
			"n": {"flat": [1, 1, 1]}, "scale": []}},
	"ninja_gi": {"name": "Ninja Gi", "slot": "body", "model": "Ninja_Chest", "affinity": ["ninja"], "std": "",
		"effect": {"rule": "poise", "name": "Poise", "desc": "A reroll that creates a match heals 1, max {max} per fight.",
			"n": {"max": [1, 1, 1]}, "scale": []}},
	"druid_robe": {"name": "Druid Robe", "slot": "body", "model": "Druid_Body", "affinity": ["druid"], "std": "",
		"effect": {"rule": "bark", "name": "Bark", "desc": "Completing a lap heals +{heal} HP.",
			"n": {"heal": [1, 2, 2]}, "scale": []}},
	"engineer_overalls": {"name": "Engineer Overalls", "slot": "body", "model": "Engineer_Body", "affinity": ["engineer"], "std": "",
		"effect": {"rule": "patchwork", "name": "Patchwork", "desc": "After each fight won, heal {heal}.",
			"n": {"heal": [1, 1, 1]}, "scale": []}},
	"hooded_robe": {"name": "Hooded Robe", "slot": "body", "model": "RogueHooded_Body", "affinity": ["necromancer"], "std": "",
		"effect": {"rule": "shroud", "name": "Shroud", "desc": "Poison you apply +{poison}.",
			"n": {"poison": [1, 1, 2]}, "scale": []}},
	"dino_suit": {"name": "Dino Suit", "slot": "body", "model": "MonsterCostume_Body", "affinity": ["monster_kid"], "std": "",
		"locks_head": true, "class_only": "monster_kid",
		"effect": {"rule": "thick_hide", "name": "Thick Hide",
			"desc": "Block {block} on combat turns 1-{turns}; BOO!'s boss weaken becomes {weaken%}.",
			"n": {"block": [1, 1, 1], "turns": [1, 2, 3], "weaken": [0.35, 0.4, 0.4]}, "scale": []}},
	# ---------------------------------------------------------------- trinkets (§7.3; tier from the Trinket rank)
	"tankard": {"name": "Tankard", "slot": "trinket", "model": "mug_full", "affinity": [], "std": "",
		"effect": {"rule": "hearty", "name": "Hearty", "desc": "Lap heal +{lap%}; tier III: campfires heal +{campfire%} more.",
			"n": {"lap": [0.005, 0.005, 0.01], "campfire": [0.0, 0.0, 0.05]}, "scale": []}},
	"compass": {"name": "Compass", "slot": "trinket", "model": "compass_base", "affinity": [], "std": "",
		"effect": {"rule": "wayfinder", "name": "Wayfinder",
			"desc": "Portal range +{portal}; Trinket rank 6+ (slot 1 only): +1 board reroll in each biome after the first.",
			"n": {"portal": [2, 3, 4], "pair_pick": [0, 0, 0]}, "scale": []}},
	"lantern": {"name": "Lantern", "slot": "trinket", "model": "lantern", "affinity": [], "std": "",
		"effect": {"rule": "lamplight", "name": "Lamplight", "desc": "Traps, lava and heat hurt {pct%} less; tier III: dodge traps and ice on 3+.",
			"n": {"pct": [0.2, 0.35, 0.5], "dodge": [0, 0, 3]}, "scale": []}},
	"coin_purse": {"name": "Coin Purse", "slot": "trinket", "model": "Gems_Sack", "affinity": [], "std": "",
		"effect": {"rule": "thrift", "name": "Thrift",
			"desc": "Gold +{gold%}; tier II: passing the Treasury banks +{treasury_step}; tier III: cash-outs x1.25.",
			"n": {"gold": [0.03, 0.05, 0.08], "treasury_step": [0, 3, 5], "cashout": [1.0, 1.0, 1.25]}, "scale": []}},
	"traders_map": {"name": "Trader's Map", "slot": "trinket", "model": "map_rolled", "affinity": [], "std": "",
		"effect": {"rule": "haggle", "name": "Haggle", "desc": "Restocks cost 7; tier II: 1 free restock per shop; tier III: shops +1 item.",
			"n": {"restock": [7, 7, 7], "free": [0, 1, 1], "items": [0, 0, 1]}, "scale": []}},
	"healers_flask": {"name": "Healer's Flask", "slot": "trinket", "model": "potion_medium_red", "affinity": [], "std": "",
		"effect": {"rule": "apothecary", "name": "Apothecary", "desc": "Every shop offers a potion; tier III: potions heal +{heal%}.",
			"n": {"heal": [0.0, 0.0, 0.03]}, "scale": []}},
	"skeleton_key": {"name": "Skeleton Key", "slot": "trinket", "model": "key_gold", "affinity": [], "std": "",
		"effect": {"rule": "unlock", "name": "Unlock",
			"desc": "Chest runes: 1 of 4; tier II: chest gold x1.25; tier III: the first chest per biome is a rune chest.",
			"n": {"choices": [4, 4, 4], "gold": [1.0, 1.25, 1.25], "first_rune": [0, 0, 1]}, "scale": []}},
	"loaded_die": {"name": "Loaded Die", "slot": "trinket", "model": "D6_A_red", "affinity": [], "std": "",
		"effect": {"rule": "weighted", "name": "Weighted",
			"desc": "At the first combat roll of each fight, {dice} dice showing 0 or 1 reroll free.",
			"n": {"dice": [1, 1, 2]}, "scale": []}},
	# ---------------------------------------------------------------- back (§4.5: Style items, no stats yet)
	"knight_cape": {"name": "Knight Cape", "slot": "back", "model": "Knight_Cape", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"mage_cape": {"name": "Mage Cape", "slot": "back", "model": "Mage_Cape", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"ranger_cape": {"name": "Ranger Cape", "slot": "back", "model": "Ranger_Cape", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"rogue_cape": {"name": "Rogue Cape", "slot": "back", "model": "Rogue_Cape", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"hooded_cape": {"name": "Hooded Cape", "slot": "back", "model": "RogueHooded_Cape", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"paladin_cape": {"name": "Paladin Cape", "slot": "back", "model": "Paladin_Cape", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"druid_backpack": {"name": "Druid Backpack", "slot": "back", "model": "Druid_Backpack", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"engineer_backpack": {"name": "Engineer Backpack", "slot": "back", "model": "Engineer_Backpack", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"bone_cloak": {"name": "Bone Cloak", "slot": "back", "model": "Skeleton_Warrior_Cloak", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"tattered_cloak": {"name": "Tattered Cloak", "slot": "back", "model": "Skeleton_Minion_Cloak", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"grave_cape": {"name": "Grave Cape", "slot": "back", "model": "Skeleton_Rogue_Cape", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"orc_warpack": {"name": "Orc Warpack", "slot": "back", "model": "Orc_Warpack", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
	"bear_pelt": {"name": "Bear Pelt", "slot": "back", "model": "Barbarian_Large_BearPelt", "cosmetic": true, "effect": {}, "affinity": [], "std": ""},
}

## Every item id in content order (the Armory's display order).
const IDS := ["sword", "greatsword", "hand_axe", "great_axe", "warhammer", "spear", "scythe", "dagger", "katana",
	"arcane_staff", "druid_staff", "wand", "hunting_bow", "crossbow", "claws", "wrench",
	"round_shield", "spiked_shield", "oath_shield", "parrying_dagger", "spellbook", "quiver", "smoke_bomb", "shuriken",
	"knight_helm", "paladin_helm", "wizard_hat", "bear_hat", "goggles", "ninja_headband", "bandit_mask", "bone_crown",
	"knight_plate", "paladin_cuirass", "barbarian_harness", "mage_robe", "rogue_leathers", "ranger_tunic", "ninja_gi",
	"druid_robe", "engineer_overalls", "hooded_robe", "dino_suit",
	"tankard", "compass", "lantern", "coin_purse", "traders_map", "healers_flask", "skeleton_key", "loaded_die",
	"knight_cape", "mage_cape", "ranger_cape", "rogue_cape", "hooded_cape", "paladin_cape", "druid_backpack",
	"engineer_backpack", "bone_cloak", "tattered_cloak", "grave_cape", "orc_warpack", "bear_pelt"]

## Variants (§5): one fixed secondary property each (not tier-scaled). ⚖ trade-offs carry
## negative numbers. `n` holds the secondary's numbers.
const VARIANTS := {
	# Arming Sword
	"sword_training": {"item": "sword", "name": "Training Sword", "model": "sword_A", "sec": "lesson", "sec_name": "Lesson",
		"desc": "While you have 3 dice or fewer: +1 combat reroll on turn 1.", "unlock": {"mastery": 15}, "n": {"rerolls": 1, "dice": 3}},
	"sword_knight": {"item": "sword", "name": "Knight's Sword", "model": "sword_B", "sec": "guarded", "sec_name": "Guarded",
		"desc": "Scoring a Pair also grants 2 Block.", "unlock": {"mastery": 45}, "n": {"block": 2}},
	"sword_saber": {"item": "sword", "name": "Saber", "model": "sword_C", "sec": "slash", "sec_name": "Slash",
		"desc": "Pairs also hit a second enemy for 25% of the attack.", "unlock": {"mastery": 90}, "n": {"pct": 0.25}},
	"sword_rapier": {"item": "sword", "name": "Rapier", "model": "sword_D", "sec": "precision", "sec_name": "Precision",
		"desc": "High Roller also counts for Twin Edge at half value.", "unlock": {"feat": "high_rollers_200"}, "n": {"share": 0.5}},
	"sword_flame": {"item": "sword", "name": "Flame Sword", "model": "sword_F", "sec": "burning", "sec_name": "Burning",
		"desc": "Each 6 in a scoring Pair deals 3 to all enemies.", "unlock": {"feat": "cinder_king_sword"}, "n": {"dmg": 3}},
	"sword_frost": {"item": "sword", "name": "Frost Cleaver", "model": "sword_G", "sec": "chill", "sec_name": "Chill",
		"desc": "A Pair of 1s or 2s Freezes the target (once per fight).", "unlock": {"feat": "frost_warden_sword"}, "n": {}},
	# Greatsword
	"greatsword_plain": {"item": "greatsword", "name": "Steel Greatsword", "model": "sword_2handed", "sec": "steel", "sec_name": "Steel",
		"desc": "+3 max HP; Great Arc -0.05.", "unlock": {"mastery": 15}, "n": {"max_hp": 3, "mult": -0.05}},
	"greatsword_zwei": {"item": "greatsword", "name": "Zweihander", "model": "sword_E", "sec": "reach", "sec_name": "Reach",
		"desc": "Three of a Kind or better also splashes 5% to the other enemies.", "unlock": {"mastery": 45}, "n": {"pct": 0.05}},
	# Hand Axe
	"axe_twinbit": {"item": "hand_axe", "name": "Twinbit Axe", "model": "axe_A", "sec": "double_chop", "sec_name": "Double Chop",
		"desc": "Two Pair: +3 damage after the multiplier.", "unlock": {"mastery": 15}, "n": {"flat": 3}},
	"axe_cleaver": {"item": "hand_axe", "name": "Cleaver", "model": "axe_C", "sec": "butcher", "sec_name": "Butcher",
		"desc": "+2 damage on turn 1.", "unlock": {"mastery": 45}, "n": {"flat": 2}},
	"axe_bone": {"item": "hand_axe", "name": "Bone Axe", "model": "Skeleton_Axe", "sec": "grisly", "sec_name": "Grisly",
		"desc": "Cleave's carried damage also applies 2 Poison.", "unlock": {"feat": "skeletons_300"}, "n": {"poison": 2}},
	# Great Axe
	"axe_war": {"item": "great_axe", "name": "War Axe", "model": "axe_B", "sec": "frenzy", "sec_name": "Frenzy",
		"desc": "Rampage stacks to 4.", "unlock": {"mastery": 15}, "n": {"stacks": 4}},
	"axe_jagged": {"item": "great_axe", "name": "Jagged Axe", "model": "axe_D", "sec": "bleed", "sec_name": "Bleed",
		"desc": "Each Rampage stack also applies 1 Poison.", "unlock": {"mastery": 45}, "n": {"poison": 1}},
	"axe_golem": {"item": "great_axe", "name": "Golem Axe", "model": "Skeleton_Golem_Axe", "sec": "crushing", "sec_name": "Crushing",
		"desc": "Rampage resets only on a kill (not on a target change); -1 max HP.", "unlock": {"feat": "bone_golem_10"}, "n": {"max_hp": -1}},
	# Warhammer
	"hammer_smith": {"item": "warhammer", "name": "Smith's Hammer", "model": "hammer_A", "sec": "tempered", "sec_name": "Tempered",
		"desc": "A Crush die showing 6 counts +1 pip more.", "unlock": {"mastery": 15}, "n": {"pip": 1}},
	"hammer_morningstar": {"item": "warhammer", "name": "Morningstar", "model": "hammer_B", "sec": "spikes", "sec_name": "Spikes",
		"desc": "Crush also deals 3 to a random other enemy.", "unlock": {"mastery": 45}, "n": {"dmg": 3}},
	"hammer_club": {"item": "warhammer", "name": "Spiked Club", "model": "hammer_C", "sec": "rend", "sec_name": "Rend",
		"desc": "Crush applies 2 Poison.", "unlock": {"mastery": 90}, "n": {"poison": 2}},
	"hammer_mallet": {"item": "warhammer", "name": "Great Mallet", "model": "hammer_D", "sec": "heavy_swing", "sec_name": "Heavy Swing",
		"desc": "Two-handed; Crush +0.3 more.", "unlock": {"feat": "warhammer_a3_win"}, "hands": 2, "n": {"crush": 0.3}},
	"hammer_bone": {"item": "warhammer", "name": "Bone Mace", "model": "Skeleton_Mace", "sec": "bonebreak", "sec_name": "Bonebreak",
		"desc": "Crush against an enemy with Block ignores 50% of it.", "unlock": {"feat": "bone_champion_3"}, "n": {"pct": 0.5}},
	# Spear
	"spear_halberd": {"item": "spear", "name": "Halberd", "model": "halberd", "sec": "sweep", "sec_name": "Sweep",
		"desc": "The First Strike attack splashes 25% to all other enemies.", "unlock": {"mastery": 15}, "n": {"pct": 0.25}},
	"spear_trident": {"item": "spear", "name": "Golden Trident", "model": "spear_B", "sec": "gilded", "sec_name": "Gilded",
		"desc": "+3 gold per kill.", "unlock": {"feat": "spear_win"}, "n": {"gold": 3}},
	# Scythe
	"scythe_bone": {"item": "scythe", "name": "Bone Scythe", "model": "Skeleton_Scythe", "sec": "harvest", "sec_name": "Harvest",
		"desc": "Kills also give +1 pet charge.", "unlock": {"mastery": 15}, "n": {"charge": 1}},
	# Dagger
	"dagger_leaf": {"item": "dagger", "name": "Leaf Dagger", "model": "dagger_A", "sec": "light", "sec_name": "Light",
		"desc": "Keep 2+ dice on turn 1: +1 damage.", "unlock": {"mastery": 15}, "n": {"dice": 2}},
	"dagger_venom": {"item": "dagger", "name": "Venom Dagger", "model": "dagger_C", "sec": "venom", "sec_name": "Venom",
		"desc": "Attacks with a Pair apply 2 Poison.", "unlock": {"mastery": 45}, "n": {"poison": 2}},
	"dagger_bone": {"item": "dagger", "name": "Bone Shiv", "model": "Skeleton_Dagger", "sec": "shiv", "sec_name": "Shiv",
		"desc": "+2 damage against poisoned enemies.", "unlock": {"feat": "poison_kills_100"}, "n": {"flat": 2}},
	# Arcane Staff
	"staff_quarter": {"item": "arcane_staff", "name": "Quarterstaff", "model": "staff_A", "sec": "unbound", "sec_name": "Unbound",
		"desc": "Channel also counts one un-runed die in the group (+1 damage).", "unlock": {"mastery": 15}, "n": {"pip": 1}},
	"staff_frost": {"item": "arcane_staff", "name": "Frost Staff", "model": "staff_B", "sec": "rime", "sec_name": "Rime",
		"desc": "A runed die showing 1 Freezes the target (once per fight).", "unlock": {"mastery": 45}, "n": {}},
	"staff_sun": {"item": "arcane_staff", "name": "Sun Staff", "model": "staff_D", "sec": "radiant", "sec_name": "Radiant",
		"desc": "Each runed die in the group heals 1 (max 1 per fight).", "unlock": {"feat": "lich_staff"}, "n": {"max": 1}},
	"staff_bone": {"item": "arcane_staff", "name": "Bone Staff", "model": "Skeleton_Staff", "sec": "soul", "sec_name": "Soul",
		"desc": "Each kill adds +1 damage to your next attack (max +3).", "unlock": {"class": "necromancer", "or_mastery": 90},
		"n": {"per": 1, "max": 3}},
	# Druid Staff
	"staff_living": {"item": "druid_staff", "name": "Living Staff", "model": "staff_C", "sec": "bloom", "sec_name": "Bloom",
		"desc": "Each Grove raise also heals 3.", "unlock": {"mastery": 15}, "n": {"heal": 3}},
	# Wand
	"wand_sapphire": {"item": "wand", "name": "Sapphire Wand", "model": "wand_A", "sec": "wand_focus", "sec_name": "Focus",
		"desc": "The Spark turn also banks +1 reroll.", "unlock": {"mastery": 15}, "n": {"rerolls": 1}},
	"wand_orb": {"item": "wand", "name": "Orb Wand", "model": "wand_B", "sec": "hex", "sec_name": "Hex",
		"desc": "The Spark attack also applies 3 Poison.", "unlock": {"mastery": 45}, "n": {"poison": 3}},
	# Hunting Bow
	"bow_short": {"item": "hunting_bow", "name": "Short Bow", "model": "bow_A_withString", "sec": "quick_draw", "sec_name": "Quick Draw",
		"desc": "The Volley also fires on turn 2 at half damage.", "unlock": {"mastery": 15}, "n": {"share": 0.5}},
	"bow_composite": {"item": "hunting_bow", "name": "Composite Bow", "model": "bow_B_withString", "sec": "piercing", "sec_name": "Piercing",
		"desc": "The Volley and Spare Arrows ignore Block.", "unlock": {"mastery": 45}, "n": {}},
	"bow_long": {"item": "hunting_bow", "name": "Longbow", "model": "bow_C_withString", "sec": "marksman", "sec_name": "Marksman",
		"desc": "The Volley targets the highest-HP enemy and deals +25%.", "unlock": {"feat": "bow_a3_win"}, "n": {"pct": 0.25}},
	# Crossbow
	"crossbow_arbalest": {"item": "crossbow", "name": "Arbalest", "model": "crossbow_2handed", "sec": "arbalest", "sec_name": "Arbalest",
		"desc": "Two-handed; Deadshot +50%.", "unlock": {"mastery": 15}, "hands": 2, "n": {"pct": 0.5}},
	"crossbow_bone": {"item": "crossbow", "name": "Bone Crossbow", "model": "Skeleton_Crossbow", "sec": "reload", "sec_name": "Reload",
		"desc": "A Deadshot kill banks +1 reroll for next turn (once per fight).", "unlock": {"mastery": 45}, "n": {"rerolls": 1}},
	# Claws
	"claws_knuckles": {"item": "claws", "name": "Knuckles", "model": "fistweapon_A", "sec": "brawl", "sec_name": "Brawl",
		"desc": "A die showing 1: +1 damage.", "unlock": {"mastery": 15}, "n": {}},
	"claws_gauntlet": {"item": "claws", "name": "Gauntlet", "model": "fistweapon_B", "sec": "guard", "sec_name": "Guard",
		"desc": "Each die showing 1 or 2 also gives 1 Block.", "unlock": {"mastery": 45}, "n": {"block": 1}},
	# Round Shield
	"shield_plank": {"item": "round_shield", "name": "Plank Shield", "model": "shield_A", "sec": "light", "sec_name": "Light",
		"desc": "+1 combat reroll on turn 1.", "unlock": {"mastery": 15}, "n": {"rerolls": 1, "block": 0}},
	"shield_heraldic": {"item": "round_shield", "name": "Heraldic Shield", "model": "shield_B", "sec": "rally", "sec_name": "Rally",
		"desc": "Bulwark Block left after turn 1 carries into turn 2.", "unlock": {"mastery": 45}, "n": {}},
	"shield_tower": {"item": "round_shield", "name": "Tower Shield", "model": "shield_C", "sec": "wall", "sec_name": "Wall",
		"desc": "Bulwark also on turn 2; -1 reroll on turn 1.", "unlock": {"mastery": 90}, "n": {"share": 1.0, "rerolls": -1}},
	"shield_bone": {"item": "round_shield", "name": "Bone Buckler", "model": "Skeleton_Shield_Small_A", "sec": "rattle", "sec_name": "Rattle",
		"desc": "Bulwark Block broken by an attack deals 2 back.", "unlock": {"feat": "skeletons_300"}, "n": {"dmg": 2}},
	# Spiked Shield
	"shield_dragon": {"item": "spiked_shield", "name": "Dragon Shield", "model": "shield_D", "sec": "scorch", "sec_name": "Scorch",
		"desc": "Thorns also apply 1 Poison.", "unlock": {"feat": "magma_golem_shield"}, "n": {"poison": 1}},
	"shield_bone_large": {"item": "spiked_shield", "name": "Bone Bulwark", "model": "Skeleton_Shield_Large_A", "sec": "bulk", "sec_name": "Bulk",
		"desc": "+4 max HP; Thorns -1.", "unlock": {"mastery": 15}, "n": {"max_hp": 4, "thorns": -1}},
	# Parrying Dagger
	"parry_sai": {"item": "parrying_dagger", "name": "Sai", "model": "dagger_B", "sec": "catch", "sec_name": "Catch",
		"desc": "A fully blocked enemy attack banks +1 reroll for next turn.", "unlock": {"mastery": 15}, "n": {"rerolls": 1}},
	# Quiver
	"quiver_bone": {"item": "quiver", "name": "Bone Quiver", "model": "Skeleton_Quiver", "sec": "barbed", "sec_name": "Barbed",
		"desc": "Spare Arrows apply 1 Poison.", "unlock": {"mastery": 15}, "n": {"poison": 1}},
	# Heads
	"helm_bone": {"item": "knight_helm", "name": "Bone Helm", "model": "Skeleton_Warrior_Helmet", "sec": "horned", "sec_name": "Horned",
		"desc": "Thorns 1 while you have Block.", "unlock": {"feat": "skeletons_300"}, "n": {"dmg": 1}},
	"hat_grave": {"item": "wizard_hat", "name": "Grave Hat", "model": "Skeleton_Mage_Hat", "sec": "grave_magic", "sec_name": "Grave Magic",
		"desc": "The doubled Arcana trigger also heals 1.", "unlock": {"mastery": 15}, "n": {"heal": 1}},
	"hood_grave": {"item": "bandit_mask", "name": "Grave Hood", "model": "Skeleton_Rogue_Hood", "sec": "ambush_poison", "sec_name": "Ambush Poison",
		"desc": "The Ambush attack applies 2 Poison.", "unlock": {"mastery": 15}, "n": {"poison": 2}},
	"ninja_mask": {"item": "ninja_headband", "name": "Ninja Mask", "model": "Ninja_Mask", "sec": "silent", "sec_name": "Silent",
		"desc": "A Focus reroll also adds +1 damage to this turn's attack.", "unlock": {"mastery": 15}, "n": {"pip": 1}},
}

## Feats that unlock variant blueprints (and Back items): {desc, cond}. cond (see Profile.feat_met):
## {counter, min} | {boss: id, with: item, [min]} | {win_with: item, [asc]} | {class_win: id, asc}.
const FEATS := {
	"high_rollers_200": {"desc": "Score 200 High Rollers.", "cond": {"counter": "high_rollers", "min": 200}},
	"cinder_king_sword": {"desc": "Defeat the Cinder King with a Sword equipped.", "cond": {"boss": "boss_cinder_king", "with": "sword"}},
	"frost_warden_sword": {"desc": "Defeat the Frost Warden with a Sword equipped.", "cond": {"boss": "mini_frost_warden", "with": "sword"}},
	"skeletons_300": {"desc": "Defeat 300 skeletons.", "cond": {"counter": "skeleton_kills", "min": SKELETON_KILLS}},
	"bone_golem_10": {"desc": "Defeat the Bone Golem 10 times.", "cond": {"kills": "bone_golem", "min": 10}},
	"warhammer_a3_win": {"desc": "Win a run with a Warhammer at A3+.", "cond": {"win_with": "warhammer", "asc": 3}},
	"bone_champion_3": {"desc": "Defeat the Bone Champion 3 times.", "cond": {"kills": "mini_bone_champion", "min": 3}},
	"spear_win": {"desc": "Win a run with a Spear.", "cond": {"win_with": "spear", "asc": 0}},
	"poison_kills_100": {"desc": "Kill 100 enemies with Poison.", "cond": {"counter": "poison_kills", "min": 100}},
	"lich_staff": {"desc": "Defeat the Lich with an Arcane Staff.", "cond": {"boss": "boss_lich", "with": "arcane_staff"}},
	"bow_a3_win": {"desc": "Win at A3+ with a Hunting Bow.", "cond": {"win_with": "hunting_bow", "asc": 3}},
	"magma_golem_shield": {"desc": "Defeat the Magma Golem with a Spiked Shield.", "cond": {"boss": "boss_magma_golem", "with": "spiked_shield"}},
	"orc_warchief": {"desc": "Defeat the Orc Warchief.", "cond": {"kills": "mini_orc_warchief", "min": 1}},
	"barbarian_a6_win": {"desc": "Win with the Barbarian at A6+.", "cond": {"class_win": "barbarian", "asc": 6}},
}
## Back items granted by feats (Bone Collector grants all three skeleton cloaks).
## (The skeleton cloaks come from the Bone Collector milestone, UnlockDefs.MILESTONES.)
const BACK_FEATS := {"orc_warpack": "orc_warchief", "bear_pelt": "barbarian_a6_win"}

# ------------------------------------------------------------------ lookups

static func has(id: String) -> bool:
	return ITEMS.has(id)

static func def(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func name_of(id: String) -> String:
	if ITEMS.has(id):
		return String(ITEMS[id].name)
	if VARIANTS.has(id):
		return String(VARIANTS[id].name)
	return ""

static func slot_of(id: String) -> String:
	return String(def(id).get("slot", ""))

## True for items that fit `slot` (a trinket fits both trinket slots).
static func fits(id: String, slot: String) -> bool:
	var s := slot_of(id)
	return s != "" and (s == slot or (s == "trinket" and slot == "trinket2"))

static func is_cosmetic(id: String) -> bool:
	return bool(def(id).get("cosmetic", false))

## Items of a slot in content order.
static func of_slot(slot: String) -> Array:
	var out: Array = []
	for id in IDS:
		if fits(String(id), slot):
			out.append(id)
	return out

## Base item of an item or variant id ("" if unknown).
static func base_of(id: String) -> String:
	if ITEMS.has(id):
		return id
	if VARIANTS.has(id):
		return String(VARIANTS[id].item)
	return ""

## The variant ids of an item: its Standard (the item id) first, then VARIANTS in table order.
static func variants_of(item: String) -> Array:
	var out: Array = [item] if ITEMS.has(item) else []
	for v in VARIANTS:
		if String(VARIANTS[v].item) == item:
			out.append(v)
	return out

static func is_variant_of(variant: String, item: String) -> bool:
	return variant == item or (VARIANTS.has(variant) and String(VARIANTS[variant].item) == item)

## Hands of a weapon given its variant (the Great Mallet and the Arbalest are 2H).
static func hands(item: String, variant := "") -> int:
	if VARIANTS.has(variant) and VARIANTS[variant].has("hands"):
		return int(VARIANTS[variant].hands)
	return int(def(item).get("hands", 1))

## True for off-hands held in the hand (blocked by a two-handed weapon).
static func hand_mount(item: String) -> bool:
	return String(def(item).get("mount", "")) == "hand"

static func style(item: String, variant := "") -> String:
	if variant == "hammer_mallet":
		return "melee_2h"
	return String(def(item).get("style", ""))

static func affinity(item: String, class_id: String) -> bool:
	return (def(item).get("affinity", []) as Array).has(class_id)

## Rank tier: 0 at R0, I at R1-3, II at R4-7, III at R8.
static func rank_tier(rank: int) -> int:
	if rank <= 0:
		return 0
	if rank >= RANK_MAX:
		return 3
	return 2 if rank >= 4 else 1

## Effective tier of `item` in `slot` for `class_id` at group rank `rank` (0 = no effect).
static func tier_for(item: String, slot: String, class_id: String, rank: int) -> int:
	var t := rank_tier(rank)
	if t <= 0 or is_cosmetic(item):
		return 0
	if slot == "trinket2":
		return maxi(1, t - POUCH_TIER)
	if slot in ["weapon", "offhand", "head", "body"] and affinity(item, class_id):
		t += AFFINITY
	return mini(3, t)

## Crowns to go from rank `r` to r + 1; {} at max.
static func rank_cost(r: int) -> Dictionary:
	if r < 0 or r >= RANK_MAX:
		return {}
	return {"crowns": int(RANK_COSTS[r])}

static func base_stats(ranks: Dictionary) -> Dictionary:
	var armor := int(ranks.get("armor", 0))
	return {"atk": ATK_BONUS if int(ranks.get("weapon", 0)) >= ATK_RANK else 0,
		"max_hp": mini(HP_CAP, int(floor(HP_PER_RANK * armor)))}

## A rule number of `item` at `tier` (1..3) for `variant` (the Standard scales `scale` keys x1.2).
static func num(item: String, key: String, tier: int, variant := "") -> float:
	var eff: Dictionary = def(item).get("effect", {})
	var arr: Array = (eff.get("n", {}) as Dictionary).get(key, [])
	if not TUNE.is_empty() and TUNE.has(item + "." + key):
		arr = TUNE[item + "." + key]
	if arr.is_empty() or tier <= 0:
		return 0.0
	var v := float(arr[clampi(tier, 1, 3) - 1])
	if variant == item and String(def(item).get("std", "")) == "x1.2" and (eff.get("scale", []) as Array).has(key):
		v = std_scale(key, v)
	return v

## The Standard variant's x1.2: factors scale their bonus part (x1.15 -> x1.18), multipliers and
## percents scale exactly, small counts round.
static func std_scale(key: String, v: float) -> float:
	if key in ["factor", "crush"]:
		return 1.0 + (v - 1.0) * 1.2
	if key in ["x"]:
		return v * 1.2
	if key in ["mult", "pct"]:
		return snappedf(v * 1.2, 0.001)
	return float(int(round(v * 1.2)))

## A variant's secondary number (fixed, not tier-scaled).
static func sec_num(variant: String, key: String, fallback := 0.0) -> float:
	if not TUNE.is_empty() and TUNE.has(variant + "." + key):
		return float(TUNE[variant + "." + key])
	return float((VARIANTS.get(variant, {}).get("n", {}) as Dictionary).get(key, fallback))

## The secondary id of a variant ("" for Standards).
static func sec_of(variant: String) -> String:
	return String(VARIANTS.get(variant, {}).get("sec", ""))

## Rule text with the numbers of `tier` filled in ({key} and {key%} placeholders).
static func rule_text(item: String, tier: int, variant := "") -> String:
	var eff: Dictionary = def(item).get("effect", {})
	if eff.is_empty():
		return "Style"
	var s := String(eff.get("desc", ""))
	var t := maxi(1, tier)
	for key in (eff.get("n", {}) as Dictionary):
		var v := num(item, String(key), t, variant)
		s = s.replace("{%s%%}" % key, "%s%%" % _fmt(snappedf(v * 100.0, 0.1)))
		s = s.replace("{%s}" % key, _fmt(v))
	if item == "spear":
		s = s.replace("{boss_factor}", _fmt(num(item, "factor", t, variant) + num(item, "boss", t, variant)))
	return s

static func _fmt(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return String.num(v, 3).rstrip("0").rstrip(".")

## What the Standard variant adds, as text.
static func std_text(item: String) -> String:
	match String(def(item).get("std", "")):
		"x1.2": return "Standard: base numbers x1.2."
		"block2": return "Standard: Block %d on turn 1 of elite and boss fights (doesn't stack)." % STD_BLOCK
	return ""

## How a variant is earned, as text (for locked chips).
static func unlock_text(variant: String) -> String:
	if ITEMS.has(variant):
		return "Comes with the item."
	var u: Dictionary = VARIANTS.get(variant, {}).get("unlock", {})
	if u.has("mastery"):
		return "Win %d fights with the %s equipped." % [int(u.mastery), name_of(String(VARIANTS[variant].item))]
	if u.has("feat"):
		return String(FEATS.get(String(u.feat), {}).get("desc", ""))
	if u.has("class"):
		return "Comes with the %s; or win %d fights with the %s." % [String(HeroDefs.def(String(u["class"])).get("name", u["class"])),
			int(u.get("or_mastery", 90)), name_of(String(VARIANTS[variant].item))]
	return ""

## Crowns to craft an unlocked blueprint: mastery blueprints 60 / 90 / 120 by threshold, feats 120.
static func craft_cost(variant: String, sigils := false) -> Dictionary:
	if not VARIANTS.has(variant):
		return {}
	if sigils:
		return {"sigils": CRAFT_SIGILS}
	var u: Dictionary = VARIANTS[variant].unlock
	if u.has("mastery"):
		return {"crowns": int(CRAFT_COSTS[maxi(0, MASTERY.find(int(u.mastery)))])}
	if u.has("or_mastery"):
		return {"crowns": int(CRAFT_COSTS[maxi(0, MASTERY.find(int(u.or_mastery)))])}
	return {"crowns": FEAT_CRAFT}

## The class whose kit contains `item` ("" if none; the Arcane Staff answers "mage").
static func kit_class(item: String) -> String:
	for cid in HeroDefs.IDS:
		if kit_items(String(cid)).has(item):
			return String(cid)
	return ""

## Every item id in a class kit (weapon, off-hand, head, body, back; "" skipped).
static func kit_items(class_id: String) -> Array:
	var k: Dictionary = KITS.get(class_id, {})
	var out: Array = []
	for slot in ["weapon", "offhand", "head"]:
		var e: Array = k.get(slot, ["", ""])
		if String(e[0]) != "":
			out.append(String(e[0]))
	for slot in ["body", "back"]:
		if String(k.get(slot, "")) != "":
			out.append(String(k[slot]))
	return out

## Kit variants owned with the class (the Necromancer's Bone Staff).
static func kit_variants(class_id: String) -> Array:
	var out: Array = []
	for slot in ["weapon", "offhand", "head"]:
		var e: Array = (KITS.get(class_id, {}) as Dictionary).get(slot, ["", ""])
		if String(e[1]) != "" and String(e[1]) != String(e[0]):
			out.append([String(e[0]), String(e[1])])
	return out

## Buy price of an item for a profile's owned classes ({} = not for sale; the caller checks
## ownership). Kit pieces of unowned classes: 150 (Back pieces 60); a kit piece of an owned class
## comes with the class. `sigils` asks for the Sigil price.
static func price(item: String, owned_classes: Array, sigils := false) -> Dictionary:
	if not ITEMS.has(item) or item == "dino_suit":
		return {}
	var kc := kit_class(item)
	if PRICES.has(item):
		return {"sigils": ITEM_SIGILS} if sigils else {"crowns": int(PRICES[item])}
	if kc != "" and not owned_classes.has(kc) and not (item == "arcane_staff" and owned_classes.has("necromancer")):
		if slot_of(item) == "back":
			return {"sigils": BACK_SIGILS} if sigils else {"crowns": BACK_PRICE}
		return {"sigils": ITEM_SIGILS} if sigils else {"crowns": KIT_PRICE}
	return {}
