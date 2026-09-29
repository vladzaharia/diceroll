class_name EventPlayer
extends RefCounted
## Plays a GameFlow event list back as presentation, one event after another, awaiting
## each beat. Every wait is divided by the controller's game speed. Never mutates rules:
## it only reads the events (and, for display, the flow's current run state).
##
##   await player.play(flow.combat_attack())

var c: GameController

var _combo_mult := 1.0
var _combo_group: Array[int] = []
var _swung := false          # hero already swung at the target for this attack
var _pending_curse := false


func _init(controller: GameController) -> void:
	c = controller


func play(events: Array) -> void:
	if c.condensed():
		events = condense(events)
	for ev: Dictionary in events:
		if not is_instance_valid(c) or not c.is_inside_tree() or c.aborting:
			return
		c.ui.on_event(ev, c.flow)
		await _one(ev)


func _wait(t: float) -> void:
	await c.wait(t)


## 4x: merges consecutive damage events on the same target from the same source (and the
## same attacker) into one beat and one number: amounts / blocked add up, the last event's
## hp / block stand, lethal if any was.
static func condense(events: Array) -> Array:
	var out: Array = []
	for ev: Dictionary in events:
		if String(ev.get("type", "")) == "damage" and not out.is_empty():
			var prev: Dictionary = out[-1]
			if String(prev.get("type", "")) == "damage" and str(prev.get("target")) == str(ev.get("target")) \
					and String(prev.get("source", "")) == String(ev.get("source", "")) \
					and int(prev.get("attacker", -1)) == int(ev.get("attacker", -1)) and not bool(prev.get("lethal", false)):
				var m := ev.duplicate()
				m["amount"] = int(prev.get("amount", 0)) + int(ev.get("amount", 0))
				m["blocked"] = int(prev.get("blocked", 0)) + int(ev.get("blocked", 0))
				out[-1] = m
				continue
		out.append(ev)
	return out


func _one(ev: Dictionary) -> void:
	var type := String(ev.get("type", ""))
	match type:
		"error":
			push_warning("GameFlow error event: %s" % String(ev.get("msg", "")))
			c.overlay.toast(String(ev.get("msg", "")).capitalize(), "", UiPalette.DANGER)
		# --- board -------------------------------------------------------------------
		"dice_rolled":
			await _dice_rolled(ev)
		"board_rolled":
			await _board_rolled(ev)
		"hero_moved":
			await _hero_moved(ev)
		"hero_stayed":
			c.tray.clear_chosen()
			c.board.clear_targets()
			c.board.hero.play_once("hit", "idle", 0.05)
			c.board.pulse_tile(c.board.hero_idx, Color(0.7, 0.7, 0.8))
			c.overlay.popup(c.hero_screen(2.2), "Blank! You stay put", UiPalette.TEXT_DIM, "", 30)
			Audio.play_sfx("error")
			await _wait(0.7)
		"lap_completed":
			c.board.pulse_tile(0, Color(1.0, 0.85, 0.4))
			Fx.heal_glow(c.board, c.board.hero.position)
			Audio.play_sfx("heal")
			var done := int(ev.lap)
			if bool(ev.get("boss", false)):
				c.overlay.vignette(0.55, 0.6)
				c.overlay.announce("THE BOSS AWAITS", "Lap %d of %d complete" % [done, Balance.TOTAL_LAPS], UiPalette.DANGER, 1.2)
				c.rig.shake(0.4, 0.8)
				await _wait(1.4)
			elif done + 1 == Balance.TOTAL_LAPS:
				c.overlay.announce("FINAL LAP", "The Lich waits at the Start", UiPalette.DANGER.lightened(0.2), 1.1)
				await _wait(1.2)
			elif not Balance.BIOME_LAPS.has(done + 1):
				c.overlay.popup(c.hero_screen(2.4), "LAP %d / %d" % [done + 1, Balance.TOTAL_LAPS], UiPalette.GOLD_BRIGHT, "flag", 34)
				await _wait(0.6)
			else:
				await _wait(0.4)
		"board_mutated":
			await _board_mutated(ev)
		"tile_triggered":
			await _tile_triggered(ev)
		"gold_changed":
			var amount := int(ev.get("amount", 0))
			if amount > 0:
				Fx.coin_burst(c.world_parent(), c.hero_pos(), clampi(amount / 3, 4, 14))
				Audio.play_sfx("coin")
				c.overlay.popup(c.hero_screen(1.9), "+%d" % amount, UiPalette.COIN, "coin", 34)
				await _wait(0.35)
		"hp_changed":
			var amount := int(ev.get("amount", 0))
			if amount > 0:
				Fx.heal_glow(c.world_parent(), c.hero_pos())
				Audio.play_sfx("heal")
				c.overlay.popup(c.hero_screen(2.1), "+%d" % amount, UiPalette.HEAL, "heart", 32)
				await _wait(0.3)
			elif amount < 0:
				c.board.hero.play_once("hit", "idle", 0.05)
				c.rig.shake(0.35, 0.3)
				Fx.damage_number(c.world_parent(), c.hero_pos() + Vector3.UP * 1.8, -amount, false, Fx.HERO_DAMAGE_COLOR)
				await _wait(0.45)
		"trap":
			if bool(ev.get("ice", false)):
				await BiomeBeats.trap_ice(c, ev)
			else:
				await _trap(ev)
		"lava":
			await BiomeBeats.lava(c, ev)
		"enemy_healed":
			await BiomeBeats.enemy_healed(c, ev)
		"duel":
			var mine: Array = ev.player
			var theirs: Array = ev.npc
			var o := int(ev.outcome)
			var res := "You win %d gold!" % int(ev.bet) if o > 0 else ("You lose %d gold" % int(ev.bet) if o < 0 else "A tie. Bet returned.")
			await c.overlay.mini_dice("DICE DUEL", [{"values": mine, "label": "YOU  %d" % (int(mine[0]) + int(mine[1]))},
				{"values": theirs, "label": "RIVAL  %d" % (int(theirs[0]) + int(theirs[1]))}], res,
				UiPalette.HEAL if o > 0 else (UiPalette.HP_BRIGHT if o < 0 else UiPalette.TEXT))
		"rune_fired":
			await _rune_fired(ev)
		"stat_changed":
			var stat := String(ev.get("stat", ""))
			var label := "+1 combat reroll" if stat == "combat_rerolls" else ("ATK %d" % int(ev.value) if stat == "atk" else stat)
			c.overlay.toast(label, "reroll" if stat == "combat_rerolls" else "sword", UiPalette.GOLD_BRIGHT)
			Audio.play_sfx("buff")
			await _wait(0.3)
		"die_added":
			c.tray.set_dice(c.flow.run.dice)
			var kind := String(ev.get("kind", "standard"))
			var di := int(ev.get("die_idx", c.tray.dice.size() - 1))
			c.overlay.toast("%s added to your pool" % DiceKinds.label(kind), "dice", UiPalette.kind_color(kind).lightened(0.3))
			c.tray.highlight_group([di] as Array[int], UiPalette.kind_color(kind))
			Audio.play_sfx("dice_select")
			await _wait(0.5)
			c.tray.clear_highlight()
		"die_changed":
			c.tray.set_dice(c.flow.run.dice)
			var kind := String(ev.get("kind", "standard"))
			var di := int(ev.get("die_idx", 0))
			c.overlay.toast("Die %d reforged: %s" % [di + 1, DiceKinds.label(kind)], "anvil", UiPalette.kind_color(kind).lightened(0.3))
			c.tray.highlight_group([di] as Array[int], UiPalette.kind_color(kind))
			Audio.play_sfx("buff")
			await _wait(0.5)
			c.tray.clear_highlight()
		"passive_gained":
			var pid := String(ev.get("id", ""))
			c.ui.add_passive(c.flow, pid)
			c.overlay.passive_card(pid)
			Audio.play_sfx("levelup" if String(ev.get("rarity", "")) == "boss" else "buff")
			if String(ev.get("rarity", "")) == "boss":
				Fx.level_up(c.world_parent(), c.hero_pos())
			await _wait(1.0)
		"passive_triggered":
			await _passive_triggered(ev)
		"rune_assigned":
			if c.flow.phase != GameFlow.Phase.SHOP:
				c.close_modals()
			c.tray.set_dice(c.flow.run.dice)
			var rn := String(ev.rune)
			c.overlay.toast("%s rune bound to die %d" % [String(Runes.DEFS[rn].name), int(ev.die_idx) + 1],
				UiIcons.rune_icon(rn), UiPalette.rune_color(rn))
			c.tray.highlight_group([int(ev.die_idx)] as Array[int], UiPalette.rune_color(rn))
			Audio.play_sfx("buff")
			await _wait(0.45)
			c.tray.clear_highlight()
		"face_changed":
			if c.flow.phase != GameFlow.Phase.SHOP and c.flow.phase != GameFlow.Phase.COMBAT:
				c.close_modals()
			c.tray.set_dice(c.flow.run.dice)
		"item_bought":
			Audio.play_sfx("coin")
		"offer_opened":
			if String(ev.offer.get("kind", "")) == "portal":
				_show_portal(ev.offer)
			await _wait(0.1)
		"offer_closed":
			c.close_modals()
		"level_up":
			Fx.level_up(c.world_parent(), c.hero_pos())
			Audio.play_sfx("levelup")
			c.overlay.announce("LEVEL UP!", "Level %d" % int(ev.level), UiPalette.XP.lightened(0.3), 0.9)
			await _wait(1.2)
		"act_started":
			await c.change_biome(ev)
		"game_over":
			await _game_over(ev)
		# --- combat --------------------------------------------------------------------
		"combat_started":
			await c.begin_combat(ev)
		"combat_turn_started":
			_swung = false
			c.tray.clear_highlight()
			var locked: Array = ev.get("locked", [])
			for i in c.tray.dice.size():
				c.tray.set_marked(i, false)
				c.tray.set_locked(i, locked.has(i))
			if not locked.is_empty():
				c.overlay.toast("Cursed! %d %s locked" % [locked.size(), "die" if locked.size() == 1 else "dice"],
					"curse", UiPalette.CURSE)
		"die_marked":
			c.tray.set_marked(int(ev.die_idx), bool(ev.marked))
		"target_changed":
			c.stage.set_target(int(ev.enemy_idx))
		"combo":
			await _combo(ev)
		"damage":
			await _damage(ev)
		"block_gained":
			await _block(ev)
		"status":
			await _status(ev)
		"enemy_intent":
			c.stage.set_enemy(int(ev.enemy_idx), {"intent": ev.intent})
		"enemy_died":
			await c.stage.enemy_die(int(ev.enemy_idx))
			var left := 0
			for d: Dictionary in c.stage.data:
				if int(d.get("hp", 0)) > 0:
					left += 1
			if left > 0:
				c.stage.reframe()
		"summon":
			c.stage.add_enemy(ev.enemy)
			c.stage.reframe()
			c.overlay.toast("A minion rises!", "skull", UiPalette.TEXT)
			await _wait(0.7)
		"boss_phase":
			if int(ev.enemy_idx) < c.stage.enemy_count():
				c.stage.set_enemy(int(ev.enemy_idx), {"traits": ev.get("traits", []), "phase": int(ev.phase)})
			c.rig.shake(0.9, 0.6)
			Fx.flash(c, Color(0.8, 0.2, 0.3, 0.45), 0.5)
			var nm := String(c.stage.data[int(ev.enemy_idx)].get("name", "The boss")) if int(ev.enemy_idx) < c.stage.data.size() else "The boss"
			c.overlay.announce("PHASE %d" % int(ev.phase), "%s grows furious!" % nm, UiPalette.DANGER, 1.0)
			await _wait(1.1)
		"combat_won":
			await c.end_combat(ev)
		_:
			pass


# --- board ---------------------------------------------------------------------------

func _dice_rolled(ev: Dictionary) -> void:
	var values: Array[int] = []
	for v in ev.values:
		values.append(int(v))
	var idx: Array[int] = []
	for v in ev.indices:
		idx.append(int(v))
	if c.tray.dice.size() != c.flow.run.dice.size():
		c.tray.set_dice(c.flow.run.dice)
	c.tray.clear_highlight()
	if String(ev.get("context", "")) == "board":
		# the camera pulls out while the dice tumble, so the landing tile is in view
		c.tray.clear_chosen()
		c.board.clear_targets()
		c.board.restore_occluders()
		c.rig.overview(c.board.ring_bounds())
	c.tray.roll(values, idx)
	await c.tray.settled



## After the tray settles: the two moving dice lift and glow (the rest dim), the target
## tile gets its marker, the camera pulls out to show it, and doubles celebrate.
func _board_rolled(ev: Dictionary) -> void:
	var chosen: Array = ev.get("chosen", [])
	var move := int(ev.get("move", 0))
	var target := int(ev.get("target", c.flow.run.pos))
	var steps := posmod(target - c.board.hero_idx, c.board.ring_size) if move > 0 else 0
	if move > 0 and steps == 0:
		steps = c.board.ring_size
	var double := bool(ev.get("double", false))
	c.tray.set_chosen(chosen)
	Audio.play_sfx("dice_select")
	c.rig.overview(c.board.ring_bounds())
	c.show_move_target(target, steps, double)
	if double:
		await _wait(0.15)
		await _doubles(ev)
	else:
		await _wait(0.25)


func _doubles(ev: Dictionary) -> void:
	var chosen: Array = ev.get("chosen", [])
	Audio.play_sfx("chest")
	for i in chosen:
		var r := c.tray.get_die_screen_rect(int(i))
		if r.size != Vector2.ZERO:
			Fx.confetti(c.overlay, r.get_center(), 18)
	var mid := Vector2.ZERO
	for i in chosen:
		mid += c.tray.die_top_screen(int(i))
	mid /= maxf(chosen.size(), 1)
	c.overlay.popup(mid - Vector2(0, 20), "DOUBLES!", UiPalette.GOLD_BRIGHT, "star", 54)
	var added := int(ev.get("treasury_added", 0))
	if added > 0:
		var to := c.ui.board_hud.top.treasury.get_global_rect().get_center()
		Fx.fly_coins(c.overlay, mid, to, clampi(added / 2, 4, 10), 0.55 / c.speed)
		await _wait(0.55)
		c.ui.board_hud.top.treasury.set_value(int(ev.get("treasury", c.flow.run.treasury)), true)
		c.overlay.popup(to + Vector2(0, 74), "+%d" % added, UiPalette.GOLD_BRIGHT, "chest", 28)
		Audio.play_sfx("coin")
	await _wait(0.35)


func _passive_triggered(ev: Dictionary) -> void:
	var pid := String(ev.get("id", ""))
	if not Passives.DEFS.has(pid):
		return
	var v := int(ev.get("value", 0))
	var text := String(Passives.DEFS[pid].name)
	match pid:
		"piggy_bank", "treasure_sense", "gold_tooth":
			text = "+%d gold" % v if v > 0 else text
		"collector":
			text = "+%d max HP" % v
		"fast_feet":
			text = "Fast Feet! +%d" % v
		"double_trouble":
			text = "+1 banked reroll"
		"blacksmith":
			text = "Forge again!"
		"bloodthirst", "full_house_party":
			text = "+%d HP" % v if v > 0 else text
		"thorns":
			text = "Thorns %d" % v if v > 0 else text
		"iron_skin":
			text = "+%d Block" % v if v > 0 else text
		"snake_eyes", "straight_shooter", "midas_fist":
			text = "+%d DMG" % v if v > 0 else text
		"boxcars", "steady_hand":
			text = "+%d pips" % v if v > 0 else text
		"second_wind", "phoenix":
			text = "Saved at 1 HP!"
	c.ui.flash_passive(pid)
	# pops rise from above the hero (they stack if several fire together)
	c.overlay.passive_pop(c.hero_screen(2.6), pid, text)

	Audio.play_sfx("buff")
	if pid in ["second_wind", "phoenix"]:
		Fx.flash(c, Color(1.0, 0.7, 0.3, 0.45), 0.5)
		Fx.level_up(c.world_parent(), c.hero_pos())
		await _wait(0.9)
	elif pid == "fast_feet":
		await _wait(0.6)
	else:
		await _wait(0.25)


func _hero_moved(ev: Dictionary) -> void:
	var path: Array = ev.path
	if path.is_empty():
		return
	c.board.clear_targets()
	c.tray.clear_chosen()
	if bool(ev.get("teleport", false)):
		c.rig.follow(c.board.hero)
		await c.board.teleport_hero(int(path[0]))
	else:
		# 4x: short hops keep the overview camera still (no follow swoop)
		if not (c.condensed() and path.size() <= 4):
			c.rig.follow(c.board.hero)
		await c.board.hop_hero(path, 0.3 / c.speed)
	c.clear_view()
	await _wait(0.15)



func _board_mutated(ev: Dictionary) -> void:
	var changes: Array = ev.get("changes", [])
	var n := 0
	var mini := -1
	for ch: Dictionary in changes:
		var idx := int(ch.idx)
		var cur: Dictionary = c.board.tiles[idx]
		var same := String(cur.type) == String(ch.type) and Array(cur.enemies) == Array(ch.enemies)
		if same:
			continue
		if String(ch.type) == "miniboss":
			mini = idx
			continue
		c.board.set_tile(idx, ch, true)
		n += 1
		await _wait(0.07)
	if mini >= 0:
		for ch: Dictionary in changes:
			if int(ch.idx) == mini:
				await _miniboss_appears(mini, ch)
	if n >= 3:
		var foes := 0
		var chests := 0
		for ch: Dictionary in changes:
			if String(ch.type) in ["enemy", "elite"] and not Array(ch.get("enemies", [])).is_empty():
				foes += 1
			elif String(ch.type) == "chest":
				chests += 1
		if foes > 0:
			c.overlay.toast("New foes appear on the board!", "skull", UiPalette.HP_BRIGHT)
		elif chests > 0:
			c.overlay.toast("Chests bloom on the board!", "chest", UiPalette.GOLD_BRIGHT)
	if n > 0:
		await _wait(0.3)


## Lap 7: the camera swoops to the new mini-boss tile, it bursts up with a warning, then
## the view returns.
func _miniboss_appears(idx: int, ch: Dictionary) -> void:
	var p := c.board.tile_global_position(idx)
	var pts := PackedVector3Array([p + Vector3(-3.2, 0, -2.4), p + Vector3(3.2, 0, 3.6), p + Vector3.UP * 3.0])
	c.rig.frame_points(pts, 0.0, 44.0)
	await _wait(0.55)
	c.overlay.vignette(0.5, 0.3)
	Audio.play_sfx("trap")
	c.board.set_tile(idx, ch, true)
	Fx.shockwave(c.board, c.board.tile_position(idx) + Vector3.UP * 0.05, Color(1.0, 0.35, 0.2), 2.6, 0.6)
	Fx.burst(c.board, c.board.tile_position(idx) + Vector3.UP * 0.3, {"amount": 30, "lifetime": 0.9,
		"speed": Vector2(1.5, 4.0), "size": 0.3, "color": Color(1.0, 0.45, 0.25), "tex": "spark", "spread": 70.0})
	c.rig.shake(0.55, 0.5)
	var ids: Array = ch.get("enemies", [])
	var nm := String(EnemyDefs.def(String(ids[0])).name) if not ids.is_empty() else "A mini-boss"
	await _wait(0.25)
	Audio.play_sfx("fanfare")
	c.overlay.announce("MINI-BOSS!", "%s appears on the board" % nm, Color("ff8a4a"), 1.2, 0.6)
	c.overlay.toast("Optional fight: beat it for a boss-tier passive", "skull", Color("ffb070"), 0.7)

	await _wait(1.6)
	c.overlay.vignette(0.0, 0.4)
	c.rig.home(c.board.hero)


func _tile_triggered(ev: Dictionary) -> void:

	var idx := int(ev.idx)
	var type := String(ev.get("tile_type", ""))
	c.board.pulse_tile(idx)
	match type:
		"chest":
			Audio.play_sfx("chest")
			c.overlay.popup(c.hero_screen(2.2), "Chest!", UiPalette.GOLD_BRIGHT, "chest", 34)
		"campfire":
			c.overlay.popup(c.hero_screen(2.2), "Campfire", Color("ffb36a"), "campfire", 34)
		"event":
			Audio.play_sfx("page")
		"forge":
			Audio.play_sfx("open")
		"treasury":
			Audio.play_sfx("coin")
		"portal":
			Audio.play_sfx("portal")
			Fx.portal_swirl(c.board, c.board.tile_position(idx) + Vector3.UP * 0.7, 0.8, true)
		"enemy", "elite", "miniboss":
			Audio.play_sfx("swing")
	await _wait(0.3)


func _trap(ev: Dictionary) -> void:
	var dodged := bool(ev.dodged)
	Audio.play_sfx("trap")
	Fx.burst(c.board, c.board.tile_position(c.board.hero_idx) + Vector3.UP * 0.2, {"amount": 18, "lifetime": 0.5,
		"speed": Vector2(2.0, 4.0), "size": 0.2, "color": Color(0.8, 0.8, 0.85), "tex": "spark", "spread": 25.0})
	await c.overlay.mini_dice("TRAP!  Roll 4+ to dodge", [{"values": [int(ev.roll)], "label": ""}],
		"Dodged!" if dodged else "-%d HP" % int(ev.damage), UiPalette.HEAL if dodged else UiPalette.HP_BRIGHT)
	if not dodged:
		Fx.hit_sparks(c.board, c.hero_pos() + Vector3.UP * 0.6, Color(1.0, 0.45, 0.35), 18)


func _show_portal(offer: Dictionary) -> void:
	var tiles: Array = offer.get("tiles", [])
	var steps: Array = []
	for t in tiles:
		steps.append(posmod(int(t) - c.board.hero_idx, c.board.ring_size))

	c.board.show_targets(tiles, steps)
	c.rig.overview(c.board.ring_bounds())


func _game_over(ev: Dictionary) -> void:
	var won := bool(ev.victory)
	c.tray.set_interactive(false)
	if won:
		Audio.play_sfx("win")
		c.board.hero.play_once("cheer", "idle")
		Fx.level_up(c.world_parent(), c.hero_pos())
		var r := c.flow.run
		c.overlay.announce("VICTORY!", "%s is yours" % BiomeDefs.name_of(String(r.route[2]) if r.route.size() >= 3 else "throne"),
			UiPalette.GOLD_BRIGHT, 1.4)
	else:
		Audio.play_sfx("lose")
		c.board.hero.play_once("death", "")
		c.rig.shake(0.5, 0.5)
		c.overlay.announce("DEFEATED", "", UiPalette.DANGER, 1.4)
	Audio.play_music("calm")
	await _wait(1.9)


# --- combat --------------------------------------------------------------------------

func _rune_fired(ev: Dictionary) -> void:
	var rune := String(ev.rune)
	var i := int(ev.die_idx)
	var col := UiPalette.rune_color(rune)
	var v := int(ev.get("value", 0))
	if v <= 0 and String(ev.get("effect", "")) in ["heal", "block", "gold", "bonus_damage", "poison"]:
		return
	var text := String(Runes.DEFS[rune].name) if Runes.DEFS.has(rune) else rune
	match String(ev.get("effect", "")):
		"bonus_damage": text = "+%d DMG" % v
		"double_pips": text = "×2 PIPS"
		"mult": text = "+0.5 MULT"
		"wild": text = "WILD %d" % v
		"damage_all": text = "EMBER!"
		"damage_random": text = "THUNDER!"
		"poison": text = "POISON %d" % v
		"freeze": text = "FREEZE!"
		"block": text = "+%d BLOCK" % v
		"heal": text = "+%d HP" % v
		"gold": text = "+%d GOLD" % v
		"bank_reroll": text = "+1 REROLL"
	var r := c.tray.get_die_screen_rect(i)
	if r.size != Vector2.ZERO:
		c.overlay.popup(Vector2(r.get_center().x, r.position.y), text, col.lightened(0.25), UiIcons.rune_icon(rune), 26)
	c.tray.highlight_group([i] as Array[int], col)
	await _wait(0.16)


func _combo(ev: Dictionary) -> void:
	_combo_mult = float(ev.mult)
	_combo_group.clear()
	for g in ev.group:
		_combo_group.append(int(g))
	c.tray.highlight_group(_combo_group, Color(1.0, 0.82, 0.35))
	var tier := ComboBanner.tier_for(_combo_mult)
	if tier >= 1:
		c.rig.shake(0.2 + 0.2 * tier, 0.3)
	await _wait(0.75 + 0.15 * tier)


func _damage(ev: Dictionary) -> void:
	var tgt: Variant = ev.target
	var amount := int(ev.amount)
	var blocked := int(ev.get("blocked", 0))
	var source := String(ev.get("source", ""))
	if tgt is String:
		# enemy hits hero
		var attacker := int(ev.get("attacker", -1))
		if BiomeBeats.hero_damage(c, ev):
			attacker = -1
		if attacker >= 0:
			await c.stage.enemy_attack(attacker)
		await c.stage.hero_hit(amount, blocked)
		if bool(ev.get("lethal", false)):
			c.board.hero.play_once("death", "")
			await _wait(0.6)
		return
	var i := int(tgt)
	if i >= c.stage.enemy_count():
		return
	match source:
		"attack":
			if not _swung:
				_swung = true
				await c.stage.hero_attack(i)
			var tier := ComboBanner.tier_for(_combo_mult)
			var crit := _combo_mult >= 3.0
			await c.stage.enemy_hit(i, amount, crit, blocked)
			if tier >= 2:
				Fx.flash(c, Color(1.0, 0.85, 0.5, 0.35), 0.35)
				c.rig.shake(0.9, 0.45)
			elif tier == 1:
				c.rig.shake(0.45, 0.3)
		"ember":
			Fx.status_burst(c.stage, c.stage.enemy_position(i) + Vector3.UP, "ember")
			await c.stage.enemy_hit(i, amount, false, blocked)
		"thunder":
			await Fx.projectile(c.stage, c.hero_pos() + Vector3.UP * 2.5, c.stage.enemy_position(i) + Vector3.UP,
				Fx.STATUS_COLORS["thunder"], 0.2 / c.speed)
			await c.stage.enemy_hit(i, amount, false, blocked)
		"poison":
			Fx.status_burst(c.stage, c.stage.enemy_position(i) + Vector3.UP, "poison")
			await c.stage.enemy_hit(i, amount, false, 0)
		_:
			await c.stage.enemy_hit(i, amount, false, blocked)
	if ev.has("hp"):
		c.stage.set_enemy(i, {"hp": int(ev.hp), "block": int(ev.get("block", 0))})
	BiomeBeats.enemy_damage(c, ev)


func _block(ev: Dictionary) -> void:
	var tgt: Variant = ev.target
	var amount := int(ev.amount)
	if tgt is String:
		if amount > 0:
			Fx.block_flash(c.stage, c.hero_pos() + Vector3.UP * 0.8, 0.85)
			Audio.play_sfx("block")
			await _wait(0.15)
		return
	var i := int(tgt)
	c.stage.set_enemy(i, {"block": int(ev.get("total", 0))})
	if String(ev.get("source", "")) == "shatter":
		await BiomeBeats.shatter(c, i)
		return
	if amount > 0 and i < c.stage.enemy_count():
		var ch: Character = c.stage.enemies[i]
		ch.play_once("block" if ch.has_anim("block") else "hit", EnemyLooks.clip(String(c.stage.data[i].get("id", "")), "idle"), 0.08)
		Fx.block_flash(c.stage, c.stage.enemy_position(i) + Vector3.UP * 0.8, 0.9)
		Audio.play_sfx("block")
		await _wait(0.4)


func _status(ev: Dictionary) -> void:
	var tgt: Variant = ev.target
	var st := String(ev.status)
	var v := int(ev.get("value", 0))
	if tgt is String:
		if await BiomeBeats.hero_status(c, ev):
			return
		match st:
			"curse":
				if bool(ev.get("pending", false)):
					var src := int(ev.get("source", -1))
					if src >= 0 and src < c.stage.enemy_count():
						var ch: Character = c.stage.enemies[src]
						ch.play_once("cast" if ch.has_anim("cast") else "attack", EnemyLooks.clip(String(c.stage.data[src].get("id", "")), "idle"), 0.08, 1.2)
						await Fx.projectile(c.stage, c.stage.enemy_position(src) + Vector3.UP * 1.2, c.hero_pos() + Vector3.UP,
							Fx.STATUS_COLORS["curse"], 0.3 / c.speed)
					Fx.status_burst(c.stage, c.hero_pos() + Vector3.UP, "curse")
					c.overlay.popup(c.hero_screen(2.2), "CURSED", UiPalette.CURSE, "curse", 32)
					await _wait(0.4)
				elif ev.has("die_idx"):
					c.tray.set_locked(int(ev.die_idx), true)
			"chaos":
				var src := int(ev.get("source", -1))
				if src >= 0 and src < c.stage.enemy_count():
					await Fx.projectile(c.stage, c.stage.enemy_position(src) + Vector3.UP * 1.4, c.hero_pos() + Vector3.UP,
						Color(0.4, 1.0, 0.8), 0.3 / c.speed)
				c.tray.set_dice(c.flow.run.dice)
				var r := c.tray.get_die_screen_rect(int(ev.get("die_idx", 0)))
				c.overlay.popup(Vector2(r.get_center().x, r.position.y) if r.size != Vector2.ZERO else c.hero_screen(2.2),
					"CHAOS! A face becomes 1", Color(0.5, 1.0, 0.85), "curse", 28)
				await _wait(0.5)
		return
	var i := int(tgt)
	if i >= c.stage.enemy_count():
		return
	var pos := c.stage.enemy_position(i) + Vector3.UP
	match st:
		"poison":
			c.stage.set_enemy(i, {"poison": v})
			if v > 0 and not ev.has("skipped"):
				Fx.status_burst(c.stage, pos, "poison")
				await _wait(0.2)
		"frozen":
			c.stage.set_enemy(i, {"frozen": v > 0})
			if v > 0:
				Fx.status_burst(c.stage, pos, "frost")
				Audio.play_sfx("block")
				await _wait(0.3)
			elif bool(ev.get("skipped", false)):
				Fx.popup_text(c.stage, pos + Vector3.UP * 1.2, "FROZEN", Fx.STATUS_COLORS["frost"], 0.8)
				await _wait(0.5)
		"buff":
			var ch: Character = c.stage.enemies[i]
			ch.play_once("cheer" if ch.has_anim("cheer") else "hit", EnemyLooks.clip(String(c.stage.data[i].get("id", "")), "idle"), 0.08)
			Fx.status_burst(c.stage, pos, "buff")
			Fx.popup_text(c.stage, pos + Vector3.UP * 1.2, "ATK UP", Fx.STATUS_COLORS["buff"], 0.8)
			Audio.play_sfx("buff")
			await _wait(0.55)
