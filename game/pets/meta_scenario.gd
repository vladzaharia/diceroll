class_name MetaScenario
extends Node
## Driver for the WP-E3 run scenarios (see game/pets/scenarios.gd): the real game
## (GameController + GameFlow) started from the max meta profile, then pushed into a state.

var scenario := ""
var c: GameController
var args: Dictionary = {}


func _ready() -> void:
	args = Shot.args if Shot else {}
	c = GameController.new()
	c.autosave = false
	add_child(c)
	c.set_speed(float(args.get("speed", "1")))
	match scenario:
		"hud_potions":
			await _hud_potions()
		"board_pet":
			await _board_pet()
		"combat_pet_acts":
			await _combat_pet_acts()
		"level_up_auto":
			await _level_up()
		"events_misc":
			await _events_misc()


## Max-profile run with `pet` equipped (L`level`), on the board, no Whetstone forge.
static func meta_flow(pet: String, level := 10, seed := 7, cls := "knight", route: Array = ["crypt", "hollow", "throne"]) -> GameFlow:
	var prof := MetaPresets.get_preset("max")
	(prof.loadout as Dictionary)["pet"] = pet
	var f := GameFlow.new_run(cls, seed, Balance.BOARD_SIZE, {"profile": prof, "route": route})
	if pet != "" and level != PetDefs.MAX_LEVEL:
		(f.run.meta.pet as Dictionary)["level"] = level
	f.offer = {}
	f.phase = GameFlow.Phase.BOARD_READY
	return f


func _flow() -> GameFlow:
	var f := meta_flow(String(args.get("pet", "pumpkin_sprite")), int(args.get("level", "10")), int(args.get("seed", "7")),
		String(args.get("class", "knight")))
	return f


func _pause(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _hud_potions() -> void:
	var f := _flow()
	f.run.belt.assign(["healing", "stoneskin", "reroll_tonic"] if not args.has("belt") else Array(String(args.belt).split(",", false)))
	f.run.sync_potions()
	f.run.hp = int(f.run.max_hp * 0.6)
	f.run.pet_state["charge"] = int(args.get("charge", "4"))
	f.run.passives.assign(["pair_master", "iron_skin", "pathfinder", "rune_echo"])
	c.start(f)
	await _pause(0.5)
	if args.get("combat", "0") == "1":
		f.run.pos = 3
		c.board.place_hero(3)
		await c.play_events(f.debug_open("combat", "skeleton_warrior,skeleton_minion,skeleton_archer"))
	if args.has("shop"):
		# the shop with a potion of each owned type (they show their type)
		f.run.gold = 200
		var sev := f.debug_open("shop")
		var items: Array = f.offer.items
		items.clear()
		for t in ["healing", "stoneskin", "reroll_tonic", "cleanse"]:
			var it := f._shop_item("potion", {})
			it.potion = t
			it.label = PotionDefs.name_of(t)
			it.desc = "%s Goes on your belt; drunk at once if the belt is full." % String(PotionDefs.DEFS[t].desc)
			items.append(it)
		await c.play_events(sev)
	if args.has("tip"):
		await _pause(0.3)
		c.ui.meta_hud.show_slot_tip(int(args.tip))
	if args.has("meter_tip"):
		await _pause(0.3)
		c.ui.meta_hud.show_meter_tip()
	if args.has("use"):
		await _pause(0.4)
		# tap the belt slot like a player would
		c.ui.meta_hud._tap(int(args.use))
	if args.has("gain"):
		await _pause(0.4)
		var ev: Array[Dictionary] = []
		f.run.belt.clear()
		f.run.sync_potions()
		c.ui.meta_hud.refresh(f)
		f._gain_potion(ev, String(args.get("source", "chest")), String(args.gain))
		await c.play_events(ev)


func _board_pet() -> void:
	var f := _flow()
	f.run.pet_state["charge"] = 2
	c.start(f)
	await _pause(float(args.get("delay", "0.6")))
	if args.get("move", "1") == "1":
		await c.run_command("roll_board")
		await _pause(0.3)
		await c.run_command("confirm_move")


## Each pet in turn (or just --pet): equip it at L10, fill its meter and ATTACK, so the real
## rules fire it; enemies and hero get lots of HP so the fight lasts. A pet the rules don't
## know yet (PetDefs) rides on a known pet's run: its model replaces the familiar and a faked
## pet_charged + pet_acted (--effect=<e>, default its own effect) play through MetaBeats.
func _combat_pet_acts() -> void:
	var only := String(args.get("pet", ""))
	var ids: Array = PetViewExt.IDS if only == "new" else ([only] if only != "" else PetDefs.IDS)
	var run_pet := String(ids[0]) if PetDefs.has(String(ids[0])) else "guard_die"
	var f := meta_flow(run_pet, 10, int(args.get("seed", "7")))
	f.run.max_hp = 400
	f.run.hp = 300
	f.run.pos = 3
	c.start(f)
	await _pause(0.3)
	c.board.place_hero(3)
	var ev := f.debug_open("combat", String(args.get("enemies", "skeleton_warrior,skeleton_minion,skeleton_archer")))
	for e in f.combat.enemies:
		e.hp = 300
		e.max_hp = 300
	for e in ev:
		if String(e.type) == "combat_started":
			for d in e.enemies:
				d.hp = 300
				d.max_hp = 300
	await c.play_events(ev)
	for id in ids:
		if not PetDefs.has(String(id)):
			await _fake_pet_act(f, String(id))
			continue
		(f.run.meta.pet as Dictionary)["id"] = String(id)
		(f.run.meta.pet as Dictionary)["level"] = 10
		f.run.pet_state["charge"] = PetDefs.size(String(id))
		await _pause(0.6)
		print("PET_ACT ", id)
		if String(id) == "crystal_wisp":
			# fires at the start of the player's turn: attack once, it fires on the next turn
			await c.run_command("combat_attack")
		else:
			await c.run_command("combat_attack")
		await _pause(0.4)
		if f.phase != GameFlow.Phase.COMBAT:
			break


## Swaps the familiar for `id`'s model and plays a faked charge + pet_acted for it.
func _fake_pet_act(f: GameFlow, id: String) -> void:
	var old := c.pets.view
	var v := PetView.create(id, 10)
	v.name = "PetFamiliar"
	c.world.add_child(v)
	v.follow = true
	v.scale = old.scale if old else Vector3.ONE * PetHost.COMBAT_SCALE
	v.home = c.pets.home_position()
	v.snap()
	if old:
		old.queue_free()
	c.pets.view = v
	# the HUD refreshes from the run (the stand-in pet): keep the meter on this pet's portrait
	var keep := func() -> void: c.ui.meta_hud.meter.setup(id, 10)
	get_tree().process_frame.connect(keep)
	f.run.pet_state["charge"] = 0
	await _pause(0.6)
	# --act_at=<s>: start the charge at that time since launch (steady --frames strips)
	var at := int(float(args.get("act_at", "0")) * 1000.0)
	while Time.get_ticks_msec() < at:
		await get_tree().process_frame
	var n := v.size_pips
	var effect := String(args.get("effect", PetViewExt.EFFECTS.get(id, "block")))
	var cb := f.combat
	var ev: Array[Dictionary] = [{"type": "pet_charged", "pet": id, "charge": n, "size": n}]
	await c.play_events(ev)
	await _pause(0.4)
	var acted := {"type": "pet_acted", "pet": id, "effect": effect, "value": 6, "target": cb.target}
	if effect == "fix":
		# the lowest die spins to its best face
		var lo := 0
		for i in cb.dice_values.size():
			if cb.dice_values[i] < cb.dice_values[lo]:
				lo = i
		acted["die_idx"] = lo
		var best := 0
		for fc in f.run.dice[lo].faces:
			best = maxi(best, fc)
		acted["face"] = best
	elif effect == "rune":
		acted["die_idx"] = 0
	var aev: Array[Dictionary] = [acted]
	if effect == "potion":
		f._gain_potion(aev, "pet", String(args.get("potion", "healing")))
	print("PET_ACT ", id, " ", effect)
	await c.play_events(aev)
	await _pause(0.6)
	get_tree().process_frame.disconnect(keep)


func _level_up() -> void:

	var f := _flow()
	f.run.hp = int(f.run.max_hp * 0.7)
	c.start(f)
	await _pause(float(args.get("delay", "0.5")))
	f.run.xp = Balance.xp_for_level(f.run.level)
	var ev: Array[Dictionary] = []
	f._level_ups(ev)
	await c.play_events(ev)


## second_boss, face_cursed, trait_triggered, a doubles roll and a Crowns pop (--only=<one>).
func _events_misc() -> void:
	var only := String(args.get("only", ""))
	var f := _flow()
	if only == "" or only == "doubles":
		f = _double_seed(f)
	c.start(f)
	await _pause(0.5)
	if only == "" or only == "doubles":
		await c.run_command("roll_board")
		await _pause(1.2)
		if only == "doubles":
			return
	if only == "" or only == "trait":
		var tev: Array[Dictionary] = [{"type": "trait_triggered", "id": "boots_treasury_step", "value": 5, "treasury": f.run.treasury + 5}]
		f.run.treasury += 5
		await c.play_events(tev)
		await _pause(0.6)
		if only == "trait":
			return
	if only == "" or only == "face_cursed":
		var cev: Array[Dictionary] = []
		f._biome_curse(cev)
		await c.play_events(cev)
		await _pause(0.5)
		if only == "face_cursed":
			return
	if only == "" or only == "crowns":
		await c.play_events([{"type": "crowns_pending", "amount": 3, "total": 3}])
		await _pause(0.6)
		if only == "crowns":
			return
	if only == "" or only == "trait_combat":
		f.run.pos = 3
		c.board.place_hero(3)
		await c.play_events(f.debug_open("combat", "skeleton_warrior,skeleton_minion"))
		await _pause(0.3)
		await c.play_events([{"type": "trait_triggered", "id": "blade_pair", "value": 1}])
		await _pause(0.8)
		if only == "trait_combat":
			return
	if only == "" or only == "second_boss":
		f.run.pos = 0
		c.board.place_hero(0)
		var other := "boss_bone_warden" if f.run.boss_id != "boss_bone_warden" else "boss_lich"
		var sev: Array[Dictionary] = [{"type": "second_boss", "id": other, "name": String(EnemyDefs.def(other).name)}]
		sev.append_array(f.debug_open("boss", other))
		await c.play_events(sev)


## A copy of `f` re-seeded until its first board roll is a doubles roll.
func _double_seed(f: GameFlow) -> GameFlow:
	var base := int(args.get("seed", "7"))
	for s in range(base, base + 400):
		var g := meta_flow(f.run.pet_id(), f.run.pet_level(), s)
		var probe := GameFlow.from_dict(g.to_dict())
		probe.roll_board()
		if probe.is_board_double() and probe.board_move > 0:
			print("DOUBLE_SEED ", s)
			return g
	return f
