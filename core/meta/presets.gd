class_name MetaPresets
extends RefCounted
## Canonical profiles for the sim, tests and screenshots (tools/sim.gd --profile=...).
##   fresh  a brand-new profile: Knight only, starter pack, Glade/Hollow/Throne, no pet,
##          Scratch-off + Claw Machine, belt 2 with 1 Healing Draught; the Knight kit and the
##          Tankard owned but every Armory rank at R0 (items shown, no effect)
##   mid    run 10 of a typical campaign (tools/sim.gd --campaign --snapshot=10, realistic bot):
##          4 classes (Knight, Barbarian, Paladin, Mage), the biomes owned by run 10 (not Warcamp/Moonlit/Ruins), 5 packs,
##          Armory ranks MID_RANKS (the old gear L4 x4 spend), the run-10 milestone items (Hand Axe, Coin
##          Purse, Compass, Lantern, Crossbow, Healer's Flask) + the class kits, default kits
##          equipped with MID_TRINKET, belt 2, Starter Kit,
##          Pumpkin Sprite at XP level 5 (155 XP: the combined-game campaign median at run 10 is 154,
##          about 70% of profiles at 150+), 7 minigames owned (2 equipped)
##   max    everything unlocked and maxed: all packs/classes/biomes/bosses, every Armory rank R8 +
##          the Belt Pouch, every item and variant owned, each class's default kit equipped
##          (signature variants, the Tankard, the Belt Pouch empty: the realistic loadout),
##          every pet L10, every minigame mastered, all Crowns upgrades, 3 minigame slots
## Ascension is 0 in every preset; pass the level separately (profile.ascension.selected).

## Armory numbers of the presets (tools/sim.gd --strip / --armory override them).
const MID_RANKS := {"weapon": 4, "offhand": 4, "armor": 4, "trinket": 4}
const MID_ITEMS := ["hand_axe", "coin_purse", "compass", "lantern", "crossbow", "healers_flask"]
const MID_TRINKET := "tankard"
const MAX_TRINKETS := ["tankard"]

static func names() -> Array:
	return ["fresh", "mid", "max"]

static func get_preset(name: String, asc := 0) -> Dictionary:
	var p: Profile
	match name:
		"mid": p = mid()
		"max": p = maxed()
		_: p = Profile.fresh()
	p.ascension = {"unlocked": maxi(int(p.ascension.unlocked), asc), "selected": asc}
	return p.to_dict()

static func mid() -> Profile:
	var p := Profile.fresh()
	var grants := {
		"classes": ["barbarian", "paladin", "mage"], "biomes": ["crypt", "frost", "magma", "mines"], "minibosses": ["mini_grave_mage"],
		"bosses": ["boss_cinder_king", "boss_magma_golem"],
		"pets": ["pumpkin_sprite", "skull_buddy"], "minigames": ["fossil_hunter", "plinko", "fishing", "high_low", "memory_match"],
		"packs": ["gamblers_kit", "cold_steel", "numerology", "colossus"], "gear": ["armor", "weapon", "offhand", "trinket"],
		"potions": ["stoneskin", "reroll_tonic"], "features": ["potion_belt", "affixes"],
	}
	for kind in grants:
		for id in grants[kind]:
			p.grant(kind, id)
	for g in MID_RANKS:
		p._ranks()[g] = int(MID_RANKS[g])
	for id in MID_ITEMS:
		p.grant_item(String(id))
	equip_all(p, [MID_TRINKET])
	p.armory.seen_new = []
	p.pet_xp = {"pumpkin_sprite": 155, "skull_buddy": 5}
	p.minigame_plays = {"scratch_off": 12, "claw_machine": 12, "fossil_hunter": 6}
	p.upgrades = {"starter_kit": 1}
	p.loadout = {"class": "knight", "mode": "standard", "minigames": ["fossil_hunter", "claw_machine"], "pet": "pumpkin_sprite"}
	p.crowns = 0
	return p

static func maxed() -> Profile:
	var p := Profile.fresh(false)
	for kind in UnlockDefs.KINDS:
		for id in UnlockDefs.all_ids(kind):
			p.grant(kind, String(id))
	for g in ItemDefs.GROUPS:
		p._ranks()[g] = ItemDefs.RANK_MAX
	p.armory.pouch = 1
	for id in ItemDefs.IDS:
		p.grant_item(String(id))
	for v in ItemDefs.VARIANTS:
		p.grant_variant(String(ItemDefs.VARIANTS[v].item), String(v))
	equip_all(p, MAX_TRINKETS)
	p.armory.seen_new = []
	for id in PetDefs.IDS:
		p.pet_xp[id] = int(PetDefs.XP_LEVELS.back())
		p.pet_bought[id] = PetDefs.MAX_LEVEL
	for id in MinigameDefs.IDS:
		p.minigame_plays[id] = int(MinigameDefs.MASTERY_PLAYS.back())
	p.upgrades = {"whetstone": 1, "starter_kit": 1, "potion_belt": 1, "loadout_slot": 1}
	p.starter_kind = "standard"
	p.loadout = {"class": "knight", "mode": "standard", "minigames": ["fossil_hunter", "claw_machine", "bubble_breaker"], "pet": "pumpkin_sprite"}
	p.ascension = {"unlocked": UnlockDefs.MAX_ASCENSION, "selected": 0}
	return p

## Every class keeps its default kit (rows hold only the trinkets, so classes granted later still
## get their kit) with `trinkets` ([slot 1, slot 2]; owned ones only).
static func equip_all(p: Profile, trinkets: Array) -> void:
	var eq: Dictionary = p.armory.get("equipped", {})
	for cid in HeroDefs.IDS:
		var row: Dictionary = eq.get(String(cid), {})
		if trinkets.size() > 0 and p.owns_item(String(trinkets[0])):
			row["trinket"] = String(trinkets[0])
		if trinkets.size() > 1 and p.owns_item(String(trinkets[1])):
			row["trinket2"] = String(trinkets[1])
		eq[String(cid)] = row
	p.armory["equipped"] = eq
