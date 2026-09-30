class_name ClassInfo
extends RefCounted
## Player-facing class text (class cards, the class badge and its tooltip, mechanic pops).
## Numbers are read from ClassLogic / HeroDefs so the text follows the balance knobs.

const TAGLINES := {
	"knight": "Sturdy and steady. His Guard die blocks every turn.",
	"barbarian": "Hits hard: a Heavy die and +2 ATK on every attack.",
	"mage": "Ember scorches every foe, Echo boosts combos.",
	"rogue": "Venom stacks poison, Lucky banks extra rerolls.",
	"paladin": "Sworn to one holy number. Matching dice strike truer.",
	"ranger": "One breath, one arrow. The first roll is the right roll.",
	"ninja": "A blur of blades. Rerolls that land a match are free.",
	"druid": "Plant a seed on lap one, harvest a forest by the Throne.",
	"engineer": "Why roll one die when a machine can roll another?",
	"necromancer": "Every foe that falls gets back up, on your side.",
	"monster_kid": "A village kid in a dino suit. The skeletons aren't sure whether to laugh or run.",
}

## Mechanic badge colours.
const MECH_COLOR := {
	"oath": Color("ffd257"), "aim": Color("b6e36a"), "shadow_step": Color("ff6a7c"), "overgrowth": Color("5fe08a"),
	"bone_harvest": Color("7cf0b8"), "turret": Color("f0a64a"), "boo": Color("9cf05a"),
}


static func tagline(class_id: String) -> String:
	return String(TAGLINES.get(class_id, ""))


static func mechanic(class_id: String) -> String:
	return HeroDefs.mechanic(class_id)


static func mechanic_name(mech: String) -> String:
	return String(HeroDefs.MECHANIC_NAMES.get(mech, ""))


static func mechanic_color(mech: String) -> Color:
	return MECH_COLOR.get(mech, UiPalette.GOLD_BRIGHT)


## One line: what the mechanic does (class cards, badge tooltip).
static func rule(mech: String) -> String:
	match mech:
		"oath":
			return "Each fight you swear an Oath to your pool's most common value. Sets of that value get +%s multiplier." % _num(ClassLogic.PALADIN_OATH_MULT)
		"aim":
			return "Attack without rerolling: ×%s damage (×%s with 4+ dice). Overkill pierces to the next foe." % [
				_num(ClassLogic.RANGER_AIM_SMALL), _num(ClassLogic.RANGER_AIM_MULT)]
		"shadow_step":
			return "A reroll that lands a match is free (%d per turn). Board rerolls that roll doubles are free too." % ClassLogic.NINJA_REFUNDS_PER_TURN
		"overgrowth":
			return "Seed dice grow +%d on their lowest face every lap. Each new biome plants another seed." % ClassLogic.DRUID_GROWTH
		"bone_harvest":
			return "Each kill raises a Bone die for the rest of the fight (max %d). Bones crumble and heal %d each." % [
				ClassLogic.BONE_MAX, ClassLogic.BONE_HEAL]
		"turret":
			return "After every attack your Clockwork Turret rolls and shoots. It grows stronger in each biome."
		"boo":
			return "Attack with the star face showing: BOO! The target cowers and skips its turn. Weak foes run away."
	return ""


## Short label shown on the mechanic badge pop for a class_triggered event ("" = no pop).
static func trigger_text(ev: Dictionary) -> String:
	var v := int(ev.get("value", 0))
	match String(ev.get("id", "")):
		"oath":
			return "OATH OF %d" % v
		"oath_kept":
			return "OATH KEPT! +%s" % _num(float(ev.get("mult", 0.5)))
		"sanctify":
			return "SANCTIFY → %d" % v
		"aim":
			return "STEADY AIM ×%s" % _num(v / 100.0)
		"piercing_shot":
			return "PIERCE %d" % v
		"shadow_step":
			return "SHADOW STEP! Free reroll"
		"overgrowth":
			return "OVERGROWTH +%d" % v
		"seed":
			return "NEW SEED"
		"wild_bond":
			return "WILD BOND +%d" % v
		"bone_harvest":
			return "BONES RISE"
		"bone_crumble":
			return "BONES CRUMBLE"
		"boo":
			return "BOO!"
	return ""


static func _num(f: float) -> String:
	var s := "%.2f" % f
	while s.ends_with("0"):
		s = s.left(s.length() - 1)
	return s.trim_suffix(".")
