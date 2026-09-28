class_name MetaPresets
extends RefCounted
## Canonical profiles for the sim, tests and screenshots (tools/sim.gd --profile=...).
##   fresh  a brand-new profile: Knight only, starter pack, Glade/Hollow/Throne, no pet,
##          Scratch-off + Claw Machine, belt 2 with 1 Healing Draught, no gear
##   mid    about runs 10-14 of a typical campaign: 3 classes, 5 biomes, 4 packs, gear L3-4
##          with the L4 traits, Skull Buddy at XP level 4, 3 minigames owned (2 equipped)
##   max    everything unlocked and maxed: all packs/classes/biomes/bosses, gear L8 with traits,
##          every pet L10, every minigame mastered, all Crowns upgrades, 3 minigame slots
## Ascension is 0 in every preset; pass the level separately (profile.ascension.selected).

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
		"classes": ["barbarian", "mage"], "biomes": ["crypt", "frost"], "minibosses": ["mini_grave_mage"],
		"pets": ["pumpkin_sprite", "skull_buddy"], "minigames": ["fossil_hunter"],
		"packs": ["gamblers_kit", "cold_steel", "numerology"], "gear": ["helm", "blade", "boots", "charm"],
		"potions": ["stoneskin"], "features": ["potion_belt"],
	}
	for kind in grants:
		for id in grants[kind]:
			p.grant(kind, id)
	p.gear = {"helm": 4, "blade": 4, "boots": 3, "charm": 2}
	p.pet_xp = {"pumpkin_sprite": 12, "skull_buddy": 30}
	p.minigame_plays = {"scratch_off": 20, "claw_machine": 20, "fossil_hunter": 8}
	p.upgrades = {"potion_belt": 1}
	p.loadout = {"class": "knight", "mode": "standard", "minigames": ["fossil_hunter", "claw_machine"], "pet": "skull_buddy"}
	p.crowns = 0
	return p

static func maxed() -> Profile:
	var p := Profile.fresh(false)
	for kind in UnlockDefs.KINDS:
		for id in UnlockDefs.all_ids(kind):
			p.grant(kind, String(id))
	for slot in GearDefs.SLOTS:
		p.gear[slot] = GearDefs.MAX_LEVEL
	p.gear_traits = {
		"helm": {"4": "helm_lap_heal", "8": "helm_last_stand"},
		"blade": {"4": "blade_pair", "8": "blade_boss_opener"},
		"boots": {"4": "boots_sure_foot", "8": "boots_pair_pick"},
		"charm": {"4": "charm_free_restock", "8": "charm_shop_potion"},
	}
	for id in PetDefs.IDS:
		p.pet_xp[id] = int(PetDefs.XP_LEVELS.back())
		p.pet_bought[id] = PetDefs.MAX_LEVEL
	for id in MinigameDefs.IDS:
		p.minigame_plays[id] = int(MinigameDefs.MASTERY_PLAYS.back())
	p.upgrades = {"whetstone": 1, "starter_kit": 1, "potion_belt": 1, "loadout_slot": 1}
	p.starter_kind = "loaded"
	p.loadout = {"class": "knight", "mode": "standard", "minigames": ["fossil_hunter", "claw_machine", "bubble_breaker"], "pet": "skull_buddy"}
	p.ascension = {"unlocked": UnlockDefs.MAX_ASCENSION, "selected": 0}
	return p
