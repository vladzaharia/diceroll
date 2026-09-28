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
	for ev: Dictionary in events:
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		c.ui.on_event(ev, c.flow)
		await _one(ev)


func _wait(t: float) -> void:
	await c.wait(t)


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
			c.show_roll_targets(ev.targets, ev.values)
			c.rig.overview(c.board.ring_bounds())
			await _wait(0.25)
		"hero_moved":
			await _hero_moved(ev)
		"lap_completed":
			c.board.pulse_tile(0, Color(1.0, 0.85, 0.4))
			Fx.heal_glow(c.board, c.board.hero.position)
			Audio.play_sfx("heal")
			if bool(ev.get("boss", false)):
				c.overlay.announce("THE BOSS AWAITS", "Lap %d complete" % int(ev.lap), UiPalette.DANGER, 1.2)
				await _wait(1.3)
			else:
				await _wait(0.6)
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
			await _trap(ev)
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
			c.overlay.toast("New die added to your pool", "dice", UiPalette.GOLD_BRIGHT)
			Audio.play_sfx("dice_select")
			await _wait(0.3)
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
			await c.transition_to_act(int(ev.act), ev.board.tiles)
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
			Audio.play_sfx("death")
			await c.stage.enemy_die(int(ev.enemy_idx))
		"summon":
			c.stage.add_enemy(ev.enemy)
			c.stage.reframe()
			c.overlay.toast("A minion rises!", "skull", UiPalette.TEXT)
			await _wait(0.7)
		"boss_phase":
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
	c.tray.roll(values, idx)
	await c.tray.settled


func _hero_moved(ev: Dictionary) -> void:
	var path: Array = ev.path
	if path.is_empty():
		return
	c.board.clear_targets()
	if bool(ev.get("teleport", false)):
		c.rig.follow(c.board.hero)
		await c.board.teleport_hero(int(path[0]))
	else:
		c.rig.follow(c.board.hero)
		await c.board.hop_hero(path, 0.3 / c.speed)
	await _wait(0.15)


func _board_mutated(ev: Dictionary) -> void:
	var changes: Array = ev.get("changes", [])
	var n := 0
	for ch: Dictionary in changes:
		var idx := int(ch.idx)
		var cur: Dictionary = c.board.tiles[idx]
		var same := String(cur.type) == String(ch.type) and Array(cur.enemies) == Array(ch.enemies)
		if same:
			continue
		c.board.set_tile(idx, ch, true)
		n += 1
		await _wait(0.07)
	if n > 0:
		await _wait(0.3)


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
		"enemy", "elite":
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
		steps.append(posmod(int(t) - c.board.hero_idx, BoardView.RING))
	c.board.show_targets(tiles, steps)
	c.rig.overview(c.board.ring_bounds())


func _game_over(ev: Dictionary) -> void:
	var won := bool(ev.victory)
	c.tray.set_interactive(false)
	if won:
		Audio.play_sfx("win")
		c.board.hero.play_once("cheer", "idle")
		Fx.level_up(c.world_parent(), c.hero_pos())
		c.overlay.announce("VICTORY!", "The Bone Throne is yours", UiPalette.GOLD_BRIGHT, 1.4)
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
