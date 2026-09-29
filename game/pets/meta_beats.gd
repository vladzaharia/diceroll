class_name MetaBeats
extends RefCounted
## Presentation beats for the meta-layer events (EventPlayer dispatches here):
##   potion_gained, potion_used, pet_charged, pet_acted, level_up (auto), second_boss,
##   face_cursed, item_triggered (Armory items), crowns_pending.
## Like the EventPlayer it only reads events (and the flow for display), never mutates rules.
##
##   await MetaBeats.play(controller, ev)

const TYPES := ["potion_gained", "potion_used", "pet_charged", "pet_acted", "level_up", "second_boss",
	"face_cursed", "item_triggered", "crowns_pending"]
## Armory colour (the station's orange) for item callouts.
const ITEM_COLOR := Color("ffab6a")
## Bookkeeping effects that only prime a later trigger: shown without holding the beat.
const ITEM_QUIET := ["ambush_ready", "dominion_stack", "soul_stack"]
const THORN_COLOR := Color(1.0, 0.7, 0.4)

const DRINK_COLORS := {
	"healing": Color(1.0, 0.45, 0.55), "stoneskin": Color(0.72, 0.78, 0.9), "reroll_tonic": Color(1.0, 0.78, 0.3),
	"cleanse": Color(0.5, 0.9, 1.0),
}


static func handles(type: String) -> bool:
	return TYPES.has(type)


static func play(c: GameController, ev: Dictionary) -> void:
	match String(ev.get("type", "")):
		"potion_gained":
			await _potion_gained(c, ev)
		"potion_used":
			await _potion_used(c, ev)
		"pet_charged":
			await _pet_charged(c, ev)
		"pet_acted":
			await _pet_acted(c, ev)
		"level_up":
			await _level_up(c, ev)
		"second_boss":
			await _second_boss(c, ev)
		"face_cursed":
			await _face_cursed(c, ev)
		"item_triggered":
			await _item_triggered(c, ev)
		"crowns_pending":
			await _crowns(c, ev)


static func _hud(c: GameController) -> MetaHud:
	return c.ui.meta_hud if c.ui and "meta_hud" in c.ui else null


# ======================================================================= potions

static func _potion_gained(c: GameController, ev: Dictionary) -> void:
	var type := String(ev.get("potion", "healing"))
	var hud := _hud(c)
	var src := String(ev.get("source", ""))
	var from := c.hero_screen(1.8)
	if src == "pet" and c.pets and c.pets.view:
		from = c.pets.screen_point(0.1)
	elif src == "shop":
		var vs := c.get_viewport().get_visible_rect().size
		from = Vector2(vs.x * 0.5, vs.y * 0.45)
	c.overlay.popup(from + Vector2(0, -30), "+ " + PotionDefs.name_of(type), MetaHud.POTION_COLORS.get(type, UiPalette.HP_BRIGHT), "", 26)
	Audio.play_sfx("chest" if src == "chest" else "buff")
	if hud:
		await hud.fly_in(type, from, Array(ev.get("belt", [])), int(ev.get("cap", -1)))
	else:
		await c.wait(0.4)


static func _potion_used(c: GameController, ev: Dictionary) -> void:
	var type := String(ev.get("potion", "healing"))
	var slot := int(ev.get("slot", -1))
	var hud := _hud(c)
	var col: Color = DRINK_COLORS.get(type, Color.WHITE)
	var to := c.hero_screen(1.3)
	if slot >= 0 and hud and hud.visible:
		await hud.fly_out(slot, type, to, Array(ev.get("belt", [])))
	elif hud:
		hud.set_belt(Array(ev.get("belt", hud.belt)))
	var world := c.world_parent()
	var hp := c.hero_pos()
	# the drink: a gulp hop, a splash of the potion's colour, then the effect's own shimmer
	if c.board.hero:
		c.board.hero.play_once("cheer" if c.board.hero.has_anim("cheer") else "hit", "idle", 0.08, 1.6)
	Audio.play_sfx("heal" if type in ["healing", "cleanse"] else "buff")
	Fx.burst(world, hp + Vector3.UP * 1.3, {"amount": 20, "lifetime": 0.7, "speed": Vector2(1.0, 2.6), "spread": 60.0,
		"gravity": Vector3(0, -3.5, 0), "size": 0.2, "color": col, "tex": "dot"})
	_bottle_tip(c, world, hp, col)
	var label := PotionDefs.name_of(type).to_upper()
	if slot < 0:
		label += "  (drunk at once)"
	c.overlay.popup(c.hero_screen(2.4), label, col.lightened(0.2), "", 28)
	match type:
		"stoneskin":
			# stone shimmer: a grey shell forms, then turns to the blue block shield
			Fx.shockwave(world, hp + Vector3.UP * 0.05, Color(0.75, 0.8, 0.9), 1.5, 0.5)
			Fx.burst(world, hp + Vector3.UP * 0.8, {"amount": 26, "lifetime": 0.6, "speed": Vector2(0.4, 1.2), "radius": 0.7,
				"gravity": Vector3(0, -1.0, 0), "size": 0.2, "color": Color(0.8, 0.82, 0.88), "tex": "hard"})
			await c.wait(0.2)
			Fx.block_flash(world, hp + Vector3.UP * 0.8, 1.15)
		"reroll_tonic":
			Fx.burst(world, hp + Vector3.UP * 1.0, {"amount": 26, "lifetime": 0.9, "speed": Vector2(1.5, 3.0),
				"gravity": Vector3(0, 1.0, 0), "size": 0.26, "color": col, "tex": "spark"})
			_fly_icons(c, "reroll", c.hero_screen(1.2), c.ui.combat_hud.pips.get_global_rect().get_center()
				if c.ui.combat_hud.visible else c.hero_screen(3.0), 2, col)
		"cleanse":
			Fx.shockwave(world, hp + Vector3.UP * 0.05, col, 1.6, 0.6)
			Fx.burst(world, hp + Vector3.UP * 0.6, {"amount": 30, "lifetime": 1.0, "speed": Vector2(0.6, 1.8), "spread": 35.0,
				"gravity": Vector3(0, 2.4, 0), "radius": 0.6, "size": 0.24, "color": col, "tex": "spark", "explosiveness": 0.5})
			for i in c.tray.dice.size():
				c.tray.set_locked(i, false)
		_:
			Fx.burst(world, hp + Vector3.UP * 0.4, {"amount": 16, "lifetime": 1.0, "speed": Vector2(0.3, 1.0), "spread": 40.0,
				"gravity": Vector3(0, 1.8, 0), "radius": 0.45, "size": 0.26, "color": col, "tex": "dot", "explosiveness": 0.4})
	await c.wait(0.35)


## A little 3D bottle (KayKit dungeon) in the potion's colour tips up over the hero's head.
static func _bottle_tip(c: GameController, world: Node3D, hp: Vector3, col: Color) -> void:
	var b := Props.inst(Props.DUN + "bottle_A_labeled_green.gltf", 0.42, false)
	Props.tint(b, col, 0.75, col * 0.35)
	b.position = hp + Vector3.UP * 1.55
	b.scale = Vector3.ONE * 0.05
	world.add_child(b)
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector3.ONE * 0.42, 0.14 / c.speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "rotation:z", 2.3, 0.3 / c.speed).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(b, "position:y", hp.y + 1.85, 0.3 / c.speed)
	t.tween_property(b, "scale", Vector3.ONE * 0.01, 0.16 / c.speed)
	t.tween_callback(b.queue_free)


## Small icons flying across the screen (reroll pips, Crowns).
static func _fly_icons(c: GameController, icon: String, from: Vector2, to: Vector2, n: int, tint: Color) -> void:
	for i in n:
		var r := UiIcons.rect(icon, 34, tint)
		r.size = Vector2(34, 34)
		r.pivot_offset = r.size * 0.5
		r.position = from - r.size * 0.5 + Vector2(randf_range(-20, 20), randf_range(-10, 10))
		c.overlay.add_child(r)
		var start := r.position
		var end := to - r.size * 0.5
		var ctrl := (start + end) * 0.5 + Vector2(randf_range(-60, 60), -90)
		var t := r.create_tween()
		t.tween_interval(0.06 * i)
		t.tween_method(func(u: float) -> void:
			r.position = start.lerp(ctrl, u).lerp(ctrl.lerp(end, u), u)
			r.rotation = u * TAU, 0.0, 1.0, 0.5 / c.speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(r.queue_free)


# ======================================================================= pets

static func _pet_charged(c: GameController, ev: Dictionary) -> void:
	var ch := int(ev.get("charge", 0))
	var n := int(ev.get("size", 1))
	var full := ch >= n
	if c.pets and c.pets.view:
		c.pets.view.set_charge(ch, n, true)
	var hud := _hud(c)
	if hud:
		hud.set_charge(ch, n, true)
	if full:
		Audio.play_sfx("buff")
		c.overlay.popup(c.pets.screen_point(0.35) if c.pets else c.hero_screen(2.4), "CHARGED!",
			PetView.LOOKS.get(String(ev.get("pet", "")), [UiPalette.GOLD_BRIGHT])[0], "", 24)
		await c.wait(0.3)
	else:
		await c.wait(0.08)


static func _pet_acted(c: GameController, ev: Dictionary) -> void:
	var pet := String(ev.get("pet", ""))
	var effect := String(ev.get("effect", ""))
	var v := int(ev.get("value", 0))
	var tgt: Variant = ev.get("target", "hero")
	var accent: Color = PetView.LOOKS.get(pet, [UiPalette.GOLD_BRIGHT])[0]
	var hud := _hud(c)
	if hud:
		hud.fire()
	var view: PetView = c.pets.view if c.pets else null
	var text := PetView.display_name(pet)
	match effect:
		"heal": text = "%s: HEAL" % text
		"bite": text = "BITE!"
		"poison": text = "POISON %d" % v
		"reroll": text = "+%d REROLL" % v
		"block": text = "BLOCK %d" % v
		"gold": text = "+%d GOLD" % v
		"potion": text = "A POTION!"
		"thorns": text = "THORNS %d" % v if v > 0 else "THORNS!"
		"freeze": text = "FREEZE!"
		"burn": text = "BURN %d" % v if v > 0 else "BURN!"
		"fix": text = "FIXED!"
		"rune": text = "RUNE ECHO!"
	var at := c.pets.screen_point(0.45) if c.pets else c.hero_screen(2.4)
	c.overlay.popup(at, text, accent.lightened(0.3), "pet_" + pet if UiIcons.exists("pet_" + pet) else "", 28)
	Audio.play_sfx("buff")
	if view == null:
		await c.wait(0.4)
		return
	view.set_charge(0, view.size_pips, false)
	var world := c.world_parent()
	match effect:
		"bite":
			Audio.play_sfx("swing")
			await view.act("bite", c.pets.target_point(tgt))
		"heal":
			await view.act("heal", c.hero_pos() + Vector3.UP * 0.9)
		"poison":
			view.act("poison")
			var any := false
			for i in c.stage.enemy_count():
				if c.in_combat and int(c.stage.data[i].get("hp", 0)) > 0:
					Fx.projectile(world, view.body_position(), c.stage.enemy_position(i) + Vector3.UP * 0.9,
						Fx.STATUS_COLORS["poison"], 0.35 / c.speed)
					any = true
			if any:
				await c.wait(0.4)
		"reroll":
			await view.act("reroll")
			if c.ui.combat_hud.visible:
				_fly_icons(c, "reroll", c.pets.screen_point(0.0), c.ui.combat_hud.pips.get_global_rect().get_center(), v, accent)
				c.overlay.popup(c.ui.combat_hud.pips.get_global_rect().get_center() + Vector2(0, -30),
					"×+%.2f" % PetDefs.wisp_mult(c.flow.run.pet_level()) if c.flow else "", UiPalette.GOLD_BRIGHT, "", 24)
			await c.wait(0.25)
		"block":
			await view.act("block")
			Fx.projectile(world, view.body_position(), c.hero_pos() + Vector3.UP * 0.8, Fx.BLOCK_COLOR, 0.25 / c.speed)
			await c.wait(0.2)
		"thorns":
			# Pebble: its slam raises a thorned shield; the thorns then settle on the hero
			await view.act("thorns")
			Fx.projectile(world, view.body_position(), c.hero_pos() + Vector3.UP * 0.8, THORN_COLOR, 0.25 / c.speed)
			await c.wait(0.25)
			Fx.block_flash(world, c.hero_pos() + Vector3.UP * 0.8, 1.0)
			Fx.burst(world, c.hero_pos() + Vector3.UP * 0.8, {"amount": 14, "lifetime": 0.4, "speed": Vector2(2.0, 3.5),
				"gravity": Vector3.ZERO, "damping": 4.0, "size": 0.24, "color": THORN_COLOR, "tex": "spark"})
			await c.wait(0.15)
		"freeze":
			await view.act("freeze", c.pets.target_point(tgt))
			await c.wait(0.3)
		"burn":
			var pts := _enemy_points(c)
			await view.act("burn", pts[0] if not pts.is_empty() else c.pets.target_point(tgt), {"targets": pts})
			await c.wait(0.35)
		"fix":
			await _pet_fix(c, view, ev, accent)
		"rune":
			await view.act("rune")
			var ri := int(ev.get("die_idx", -1))
			if ri >= 0 and ri < c.tray.dice.size():
				c.tray.highlight_group([ri] as Array[int], accent)
				c.overlay.popup(c.tray.die_top_screen(ri), "ECHO", accent.lightened(0.3), "", 22)
				await c.wait(0.45)
				c.tray.clear_highlight()
		"gold":
			await view.act("gold")
		"potion":
			var pcol: Color = MetaHud.POTION_COLORS.get(String(ev.get("potion", "healing")), UiPalette.HP_BRIGHT)
			if PetViewExt.has(pet):
				# Bubbles: the bottle pops out of the brew before the belt fly-in
				await view.act("potion", Vector3.INF, {"color": pcol})
			else:
				view.act("potion")
				await c.wait(0.25)
		_:
			await view.act(effect)
	await c.wait(0.1)


## World points (body height) of the living enemies in the current fight.
static func _enemy_points(c: GameController) -> Array:
	var out := []
	if not c.in_combat:
		return out
	for i in c.stage.enemy_count():
		if c.flow == null or c.flow.combat == null or c.flow.combat.alive(i):
			out.append(c.stage.enemy_position(i) + Vector3.UP * 0.9)
	return out


## Tinker's fix: it hops off toward the tray, then the die (event die_idx) spins to its best
## face (event face; falls back to the die's highest face) with a little flourish.
static func _pet_fix(c: GameController, view: PetView, ev: Dictionary, accent: Color) -> void:
	var di := int(ev.get("die_idx", ev.get("die", -1)))
	var face := int(ev.get("face", ev.get("to", 0)))
	if face <= 0 and c.flow and di >= 0 and di < c.flow.run.dice.size():
		var fs: PackedInt32Array = c.flow.run.dice[di].faces
		for f in fs:
			face = maxi(face, f)
	var from := c.pets.screen_point(0.1)
	await view.act("fix", Vector3.INF, {"die_idx": di, "face": face})
	if di < 0 or di >= c.tray.dice.size() or not c.tray.is_visible_in_tree():
		await c.wait(0.3)
		return
	# a little beetle icon scurries to the die
	var r := c.tray.get_die_screen_rect(di)
	var to := r.get_center() if r.size != Vector2.ZERO else c.tray.die_top_screen(di)
	await _hop_icon(c, "pet_" + String(ev.get("pet", "")), from, to)
	c.tray.highlight_group([di] as Array[int], accent)
	Audio.play_sfx("buff")
	var vals: Array[int] = [face]
	var idx: Array[int] = [di]
	c.tray.roll(vals, idx)
	await c.tray.settled
	c.overlay.popup(c.tray.die_top_screen(di) + Vector2(0, -10), "→ %d" % face, accent.lightened(0.3), "", 26)
	await c.wait(0.35)
	c.tray.clear_highlight()


## A pet portrait that hops along an arc from -> to (screen), then pops.
static func _hop_icon(c: GameController, icon: String, from: Vector2, to: Vector2) -> void:
	var r := UiIcons.rect(icon, 72, Color.WHITE) if UiIcons.exists(icon) else UiIcons.rect("star", 40, UiPalette.GOLD_BRIGHT)
	r.size = Vector2(72, 72)
	r.pivot_offset = r.size * 0.5
	r.position = from - r.size * 0.5
	c.overlay.add_child(r)
	var start := r.position
	var end := to - r.size * 0.5
	var ctrl := (start + end) * 0.5 + Vector2(0, -160)
	var t := r.create_tween()
	t.tween_method(func(u: float) -> void:
		r.position = start.lerp(ctrl, u).lerp(ctrl.lerp(end, u), u)
		r.rotation = sin(u * PI * 3.0) * 0.3, 0.0, 1.0, 0.45 / c.speed).set_trans(Tween.TRANS_SINE)
	t.tween_property(r, "scale", Vector2(1.4, 0.6), 0.06 / c.speed)
	t.tween_property(r, "scale", Vector2.ONE * 0.01, 0.12 / c.speed)
	t.tween_callback(r.queue_free)
	await t.finished


# ======================================================================= level-ups

static func _level_up(c: GameController, ev: Dictionary) -> void:
	var lv := int(ev.get("level", 1))
	var hp := int(ev.get("max_hp_gained", Balance.LEVEL_MAX_HP))
	Fx.level_up(c.world_parent(), c.hero_pos())
	Audio.play_sfx("levelup")
	if c.pets and c.pets.view:
		c.pets.view.hop(0.35)
	var hud := _hud(c)
	if hud and hud.visible:
		hud.level_toast(lv, hp, int(ev.get("healed", 0)))
	else:
		c.overlay.popup(c.hero_screen(2.6), "LEVEL %d  ·  +%d MAX HP" % [lv, hp], UiPalette.XP.lightened(0.3), "xp", 30)
	await c.wait(0.6)


# ======================================================================= other events

## A10 double final: the first boss falls, the route's other final boss joins.
static func _second_boss(c: GameController, ev: Dictionary) -> void:
	var nm := String(ev.get("name", "Another boss"))
	c.overlay.vignette(0.75, 0.4)
	Fx.flash(c, Color(0.9, 0.2, 0.25, 0.5), 0.5)
	c.rig.shake(0.8, 0.8)
	Audio.play_sfx("trap")
	await c.wait(0.35)
	Audio.play_sfx("fanfare")
	c.overlay.announce("DOUBLE FINAL!", "%s joins the fight" % nm, UiPalette.DANGER.lightened(0.15), 1.3, 0.34)
	c.overlay.toast("Ascension 10: a second final boss", "skull", Color("ffb070"), 0.62)
	await c.wait(1.7)


## A7: a random face of a random die becomes 1 until the next Forge visit.
static func _face_cursed(c: GameController, ev: Dictionary) -> void:
	var di := int(ev.get("die_idx", 0))
	ClassBeats.sync_tray(c)
	c.tray.highlight_group([di] as Array[int], UiPalette.CURSE)
	c.tray.set_locked(di, true)
	var r := c.tray.get_die_screen_rect(di)
	var at := Vector2(r.get_center().x, r.position.y) if r.size != Vector2.ZERO else c.hero_screen(2.2)
	Fx.flash(c, Color(0.55, 0.2, 0.8, 0.35), 0.4)
	Audio.play_sfx("trap")
	c.overlay.popup(at, "CURSED FACE → 1", UiPalette.CURSE.lightened(0.3), "curse", 28)
	var hud := _hud(c)
	if hud and r.size != Vector2.ZERO:
		hud._ring(r.get_center() - hud.global_position, UiPalette.CURSE, 20.0, 80.0)
	c.overlay.toast("Die %d: a face is cursed to 1 until you Forge" % (di + 1), "curse", UiPalette.CURSE.lightened(0.35), 0.6)
	await c.wait(1.1)
	c.tray.set_locked(di, false)
	c.tray.clear_highlight()


## An Armory item fired: a pill with the item's 3D picture and its rule name / amount pops
## over the hero, kept under the top HUD and above the dice tray's frame (never across it or
## over an enemy's intent badge).
static func _item_triggered(c: GameController, ev: Dictionary) -> void:
	var text := item_text(ev)
	if text == "":
		return
	var id := String(ev.get("id", ""))
	var shown := ArmoryLook.shown_id(c.flow.run.class_id if c.flow else "", id, String(ev.get("variant", id)))
	var at := c.hero_screen(2.4)
	var top := 0.0
	if c.in_combat and c.ui and c.ui.combat_hud and c.ui.combat_hud.visible:
		top = c.ui.combat_hud.top.content_bottom()
	elif c.ui and c.ui.board_hud and c.ui.board_hud.visible:
		top = c.ui.board_hud.top.content_bottom()
	var floor_y := 0.0
	if is_instance_valid(c.tray) and c.tray.is_visible_in_tree():
		floor_y = c.tray.get_global_rect().position.y - 4.0
	c.overlay.item_pop(at, shown, text, ITEM_COLOR, top, floor_y, hud_rects(c))
	if String(ev.get("effect", "")) in ITEM_QUIET:
		return
	Audio.play_sfx("buff")
	await c.wait(0.3)


## Screen rects of the enemy HUDs in a fight (intent badge, HP bar, numbers), for callouts to
## keep off.
static func hud_rects(c: GameController) -> Array:
	var out: Array = []
	if not c.in_combat or c.stage == null or c.rig == null:
		return out
	var cam: Camera3D = c.rig.camera
	for h in c.stage.huds:
		if not is_instance_valid(h) or not h.is_visible_in_tree():
			continue
		var r := Rect2()
		var first := true
		for n in [h.bar, h.intent_badge, h.intent_label, h.hp_label]:
			var n3 := n as Node3D
			if n3 == null or not n3.is_visible_in_tree() or cam.is_position_behind(n3.global_position):
				continue
			var p := cam.unproject_position(n3.global_position)
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
		if not first:
			out.append(r.grow_individual(86.0, 34.0, 86.0, 24.0))
	return out


## Callout text of an item_triggered event (ArmoryLook.callout_text).
static func item_text(ev: Dictionary) -> String:
	return ArmoryLook.callout_text(ev)


## Minigame Crowns (banked at run end): a small crown pop.
static func _crowns(c: GameController, ev: Dictionary) -> void:
	var n := int(ev.get("amount", 0))
	var vs := c.get_viewport().get_visible_rect().size
	var at := Vector2(vs.x * 0.5, vs.y * 0.38)
	# on the overlay layer: minigame screens sit above the run HUD
	c.overlay.popup(at, "+%d CROWN%s" % [n, "" if n == 1 else "S"], UiPalette.GOLD_BRIGHT, "crown", 34)
	Fx.confetti(c.overlay, at, 14)
	Audio.play_sfx("coin")
	await c.wait(0.45)
