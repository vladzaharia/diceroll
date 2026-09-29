class_name Passives
extends RefCounted
## Passive abilities ("relics"). The dice are the equipment; passives bend how they score,
## reroll, move and pay. `icon` is a hint for the presentation layer's glyph.
## Regular passives (common/uncommon/rare) come from elites, the shop and the Blessing Shrine.
## Boss passives (rarity "boss") come ONLY from mini-bosses and the Act 1/2 bosses.

const DEFS := {
	# ---- combos
	"pair_master": {"name": "Pair Master", "rarity": "common", "icon": "pair",
		"desc": "Pair and Two Pair multipliers +0.5."},
	"full_house_party": {"name": "Full House Party", "rarity": "uncommon", "icon": "house",
		"desc": "Full House: heal 8 HP."},
	"straight_shooter": {"name": "Straight Shooter", "rarity": "uncommon", "icon": "arrow",
		"desc": "Straights and Small Straights deal +8 damage."},
	"triple_threat": {"name": "Triple Threat", "rarity": "rare", "icon": "triangle",
		"desc": "Three, Four and Five of a Kind: multiplier +1."},
	# ---- specific pips
	"snake_eyes": {"name": "Snake Eyes", "rarity": "common", "icon": "snake",
		"desc": "Each die showing 1 deals +5 damage."},
	"boxcars": {"name": "Boxcars", "rarity": "uncommon", "icon": "six",
		"desc": "Each 6 in your combo adds +3 pips."},
	"gold_tooth": {"name": "Gold Tooth", "rarity": "common", "icon": "tooth",
		"desc": "+1 gold for each die showing 6 when you attack."},
	# ---- rerolls
	"steady_hand": {"name": "Steady Hand", "rarity": "common", "icon": "hand",
		"desc": "Each die you never rerolled this turn adds +1 pip."},
	"loaded_hands": {"name": "Loaded Hands", "rarity": "uncommon", "icon": "dice",
		"desc": "+1 reroll on the first turn of every fight."},
	"double_trouble": {"name": "Double Trouble", "rarity": "uncommon", "icon": "double",
		"desc": "Moving on doubles banks +1 combat reroll for your next fight."},
	# ---- runes
	"rune_echo": {"name": "Rune Echo", "rarity": "rare", "icon": "echo",
		"desc": "Runes on combo dice have a 25% chance to trigger twice."},
	"collector": {"name": "Collector", "rarity": "uncommon", "icon": "gem",
		"desc": "+5 max HP for every rune on your dice, now and later."},
	# ---- board and economy
	"pathfinder": {"name": "Pathfinder", "rarity": "uncommon", "icon": "boot",
		"desc": "+1 board reroll every turn."},
	"treasure_sense": {"name": "Treasure Sense", "rarity": "common", "icon": "chest",
		"desc": "Chests give +50% gold."},
	"piggy_bank": {"name": "Piggy Bank", "rarity": "uncommon", "icon": "pig",
		"desc": "Completing a lap pays 10% interest on your gold (max 15)."},
	"haggler": {"name": "Haggler", "rarity": "common", "icon": "tag",
		"desc": "Shop items cost 20% less."},
	"scholar": {"name": "Scholar", "rarity": "common", "icon": "book",
		"desc": "+25% XP from fights."},
	"blacksmith": {"name": "Blacksmith", "rarity": "uncommon", "icon": "anvil",
		"desc": "The Forge tile lets you edit 2 faces."},
	# ---- defense and tempo
	"thorns": {"name": "Thorns", "rarity": "common", "icon": "thorns",
		"desc": "When an enemy hits you, it takes 3 damage."},
	"iron_skin": {"name": "Iron Skin", "rarity": "common", "icon": "shield",
		"desc": "Start every combat turn with 3 Block."},
	"bloodthirst": {"name": "Bloodthirst", "rarity": "uncommon", "icon": "drop",
		"desc": "Heal 3 HP whenever an enemy dies."},
	"opening_salvo": {"name": "Opening Salvo", "rarity": "uncommon", "icon": "burst",
		"desc": "Your first attack in each fight deals x1.5 damage."},
	"second_wind": {"name": "Second Wind", "rarity": "rare", "icon": "wind",
		"desc": "Once per run, survive a lethal hit with 1 HP."},
	"glass_cannon": {"name": "Glass Cannon", "rarity": "rare", "icon": "glass",
		"desc": "Attacks deal x1.5 damage. Lose 20% max HP."},
	# ---- boss tier (build-defining; only from mini-bosses and Act 1/2 bosses)
	"extra_hand": {"name": "Extra Hand", "rarity": "boss", "icon": "hand_plus",
		"desc": "Your pool can hold a 6th die. Gain a Standard die now."},
	"crowd_pleaser": {"name": "Crowd Pleaser", "rarity": "boss", "icon": "crown",
		"desc": "Every Pair scores as Three of a Kind (x2.5)."},
	"encore": {"name": "Encore", "rarity": "boss", "icon": "loop",
		"desc": "A reroll that improves your combo is refunded."},
	"rune_bloom": {"name": "Rune Bloom", "rarity": "boss", "icon": "bloom",
		"desc": "Every die without a rune gains a random rune now and at the start of each act."},
	"fast_feet": {"name": "Fast Feet", "rarity": "boss", "icon": "wing",
		"desc": "Moving on doubles: after landing, hop forward again by the pair value."},
	"resonance": {"name": "Resonance", "rarity": "boss", "icon": "wave",
		"desc": "Runes on dice in your combo trigger twice."},
	"phoenix": {"name": "Phoenix Feather", "rarity": "boss", "icon": "feather",
		"desc": "Once per act, survive a lethal hit with 1 HP."},
	"midas_fist": {"name": "Midas Fist", "rarity": "boss", "icon": "fist",
		"desc": "Attacks deal +1 damage per 8 gold you hold (max +15)."},
}

const IDS := [
	"pair_master", "full_house_party", "straight_shooter", "triple_threat", "snake_eyes", "boxcars",
	"gold_tooth", "steady_hand", "loaded_hands", "double_trouble", "rune_echo", "collector",
	"pathfinder", "treasure_sense", "piggy_bank", "haggler", "scholar", "blacksmith", "thorns",
	"iron_skin", "bloodthirst", "opening_salvo", "second_wind", "glass_cannon",
	"extra_hand", "crowd_pleaser", "encore", "rune_bloom", "fast_feet", "resonance", "phoenix", "midas_fist",
]

## Rarity weights for regular passive rolls (elites, shop, shrine).
const RARITY_WEIGHTS := {"common": 55, "uncommon": 32, "rare": 13}

static func rarity(id: String) -> String:
	return String(DEFS[id].rarity)

static func is_boss(id: String) -> bool:
	return rarity(id) == "boss"

static func of_rarity(r: String) -> Array[String]:
	var out: Array[String] = []
	for id in IDS:
		if DEFS[id].rarity == r:
			out.append(id)
	return out

static func option(id: String) -> Dictionary:
	var d: Dictionary = DEFS[id]
	return {"id": id, "label": String(d.name), "desc": String(d.desc), "rarity": String(d.rarity), "icon": String(d.icon)}

## n distinct regular passives not in `owned`, rolled by rarity weight.
static func roll_regular(rng: Rng, n: int, owned: Array) -> Array[String]:
	var out: Array[String] = []
	var left := 0
	for id in IDS:
		if not is_boss(id) and not owned.has(id):
			left += 1
	var guard := 0
	while out.size() < mini(n, left) and guard < 200:
		guard += 1
		var r := String(rng.weighted(RARITY_WEIGHTS))
		var pool: Array[String] = []
		for id in of_rarity(r):
			if not owned.has(id) and not out.has(id):
				pool.append(id)
		if not pool.is_empty():
			out.append(String(rng.pick(pool)))
	return out

## n distinct boss passives not in `owned`; if fewer remain, fill with rare (then any) regulars.
static func roll_boss(rng: Rng, n: int, owned: Array) -> Array[String]:
	var pool: Array = []
	for id in of_rarity("boss"):
		if not owned.has(id):
			pool.append(id)
	rng.shuffle(pool)
	var out: Array[String] = []
	for id in pool:
		if out.size() < n:
			out.append(String(id))
	if out.size() < n:
		var rares: Array = []
		for id in of_rarity("rare"):
			if not owned.has(id):
				rares.append(id)
		rng.shuffle(rares)
		for id in rares:
			if out.size() < n:
				out.append(String(id))
	if out.size() < n:
		var skip: Array = owned.duplicate()
		skip.append_array(out)
		out.append_array(roll_regular(rng, n - out.size(), skip))
	return out
