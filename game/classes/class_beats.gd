class_name ClassBeats
extends RefCounted
## Presentation for the class mechanics (docs/design/2026-09-28-classes-enemies-skins.md §1,
## docs/plans/balance.md "API for presentation"): class_triggered pops and FX per mechanic, the
## Pretend ★ face on the board, temporary Bone dice in the tray, the Engineer's turret shots and
## BOO!'s scared / cowering / fleeing enemies. EventPlayer routes the events here; like
## AffixBeats it only reads events (and, for display, the flow) and never touches rules.

const GOLD := Color(1.0, 0.82, 0.3)
const SOUL := Color(0.45, 1.0, 0.7)
const LEAF := Color(0.45, 0.92, 0.4)
const SHADOW := Color(0.55, 0.3, 0.85)
const BRASS := Color(1.0, 0.66, 0.28)
const SCARE := Color(0.62, 0.95, 0.4)

## The last board roll's dice whose ★ face showed (their value is what they copied).
static var _pretend: Array = []


# --- tray -------------------------------------------------------------------------------

## The dice the tray shows (ClassTray.pool).
static func pool(flow: GameFlow) -> Array:
	return ClassTray.pool(flow)


## Re-syncs the tray's dice (pool) and the Engineer's turret die.
static func sync_tray(c: GameController) -> void:
	if c.flow == null:
		return
	c.tray.set_dice(pool(c.flow))
	c.tray.set_turret(c.flow.run.turret)


## Board roll values as the tray should land them (ClassTray.board_values); remembers the ★ dice.
static func board_values(ev: Dictionary, values: Array[int]) -> Array[int]:
	_pretend = Array(ev.get("pretend", []))
	return ClassTray.board_values(ev, values)


## After the board roll settled: each ★ says which value it pretends to be.
static func after_board_roll(c: GameController) -> void:
	for i in _pretend:
		var v := int(c.flow.board_roll[int(i)]) if int(i) < c.flow.board_roll.size() else 0
		var r := c.tray.get_die_screen_rect(int(i))
		# under the die, inside the tray: the DOUBLES! pop owns the space above the dice
		var at := Vector2(r.get_center().x, r.end.y + 44.0) if r.size != Vector2.ZERO else c.tray.die_top_screen(int(i))
		c.overlay.popup(at, "★ = %d" % v, SCARE.lightened(0.2), "mech_boo", 28)
	if not _pretend.is_empty():
		Audio.play_sfx("pop")


## After a combat roll settled: Oath dice glint gold; a ★ face announces BOO!.
static func after_combat_roll(c: GameController) -> void:
	var cs := c.flow.combat
	if cs == null:
		return
	if cs.oath > 0:
		c.tray.set_badge("OATH %d" % cs.oath, GOLD, "mech_oath")
		var oath: Array[int] = []
		for i in cs.dice_values.size():
			if int(cs.dice_values[i]) == cs.oath:
				oath.append(i)
		if not oath.is_empty():
			c.tray.highlight_group(oath, GOLD)
	var star := cs.dice_values.find(Die.PRETEND)
	if star >= 0:
		var t := cs.attack_target if cs.attack_target >= 0 else cs.target
		var brave := t >= 0 and t < cs.enemies.size() and bool(cs.enemies[t].get("brave", false))
		c.overlay.popup(c.tray.die_top_screen(star), "★ BOO ready!" if not brave else "★ Wild", SCARE, "mech_boo", 26)


## A temporary die (Bone) joins the pool at a turn start.
static func die_added(c: GameController, ev: Dictionary) -> void:
	sync_tray(c)
	var di := int(ev.get("die_idx", c.tray.dice.size() - 1))
	c.tray.highlight_group([di] as Array[int], SOUL)
	var r := c.tray.get_die_screen_rect(di)
	if r.size != Vector2.ZERO:
		Fx.confetti(c.overlay, r.get_center(), 10)
	c.overlay.popup(c.tray.die_top_screen(di), "BONE DIE RISES", SOUL, "mech_bone_harvest", 26)
	Fx.burst(c.world_parent(), c.hero_pos() + Vector3.UP * 0.4, {"amount": 22, "lifetime": 0.9, "speed": Vector2(0.6, 2.0),
		"gravity": Vector3(0, 2.5, 0), "size": 0.3, "color": SOUL, "tex": "dot", "spread": 50.0})
	Audio.play_sfx("glass")
	await c.wait(0.55)
	c.tray.clear_highlight()


## A temporary die crumbles at the fight's end (the tray still shows it until now).
static func die_removed(c: GameController, ev: Dictionary) -> void:
	var di := int(ev.get("die_idx", -1))
	if di >= 0 and di < c.tray.dice.size():
		c.tray.highlight_group([di] as Array[int], Color(0.6, 0.55, 0.45))
		c.overlay.popup(c.tray.die_top_screen(di), "CRUMBLE", Color(0.9, 0.85, 0.7), "mech_bone_harvest", 24)
	Audio.play_sfx("fwump")
	await c.wait(0.3)
	if c.flow:
		c.tray.set_dice(c.flow.run.dice)


## Druid growth / Paladin Sanctify: the changed die pops with its new face.
static func face_changed(c: GameController, ev: Dictionary) -> void:
	var src := String(ev.get("source", ""))
	if not src in ["growth", "sanctify"]:
		return
	var di := int(ev.get("die_idx", -1))
	if di < 0 or di >= c.tray.dice.size():
		return
	var col := LEAF if src == "growth" else GOLD
	c.tray.highlight_group([di] as Array[int], col)
	c.overlay.popup(c.tray.die_top_screen(di), ("GROWS → %d" if src == "growth" else "SANCTIFY → %d") % int(ev.get("value", 0)),
		col.lightened(0.2), "mech_overgrowth" if src == "growth" else "mech_oath", 24)
	await c.wait(0.3)


## Druid: a die becomes a seed (leaf mark).
static func die_tagged(c: GameController, ev: Dictionary) -> void:
	sync_tray(c)
	var di := int(ev.get("die_idx", -1))
	c.tray.highlight_group([di] as Array[int], LEAF)
	c.overlay.popup(c.tray.die_top_screen(di), "NEW SEED", LEAF.lightened(0.2), "mech_overgrowth", 28)
	Audio.play_sfx("pop")
	await c.wait(0.5)
	c.tray.clear_highlight()


# --- class_triggered -------------------------------------------------------------------

static func class_triggered(c: GameController, ev: Dictionary) -> void:
	var id := String(ev.get("id", ""))
	var mech := HeroDefs.mechanic(c.flow.run.class_id) if c.flow else ""
	var col := ClassInfo.mechanic_color(mech)
	var text := ClassInfo.trigger_text(ev)
	var fight := c.flow != null and c.flow.phase == GameFlow.Phase.COMBAT and c.stage.enemy_count() > 0
	var wp := c.world_parent()
	match id:
		"oath":
			c.tray.set_badge("OATH %d" % int(ev.get("value", 0)), GOLD, "mech_oath")
			Fx.level_up(wp, c.hero_pos())
			Fx.shockwave(wp, c.hero_pos() + Vector3.UP * 0.05, GOLD, 1.8, 0.6)
			Audio.play_sfx("bell")
			c.overlay.popup(c.hero_screen(2.5), text, GOLD.lightened(0.25), "mech_oath", 40)
			await c.wait(0.8)
		"oath_kept":
			Fx.flash(c, Color(1.0, 0.85, 0.4, 0.3), 0.3)
			Fx.burst(wp, c.hero_pos() + Vector3.UP * 1.2, {"amount": 30, "lifetime": 0.9, "speed": Vector2(1.5, 3.5),
				"gravity": Vector3(0, 1.0, 0), "size": 0.26, "color": GOLD, "tex": "spark", "spread": 180.0})
			Audio.play_sfx("bell")
			c.overlay.popup(c.hero_screen(2.6), text, GOLD.lightened(0.25), "mech_oath", 36)
			await c.wait(0.45)
		"sanctify":
			Fx.level_up(wp, c.hero_pos())
			c.overlay.toast("Sanctify: a face swears to the Oath (%d)" % int(ev.get("value", 0)), "mech_oath", GOLD)
			Audio.play_sfx("bell")
			await c.wait(0.4)
		"aim":
			if fight:
				var t := c.stage.target
				_reticle(c, t, col)
			c.overlay.popup(c.hero_screen(2.5), text, col.lightened(0.2), "mech_aim", 34)
			Audio.play_sfx("tick")
			await c.wait(0.45)
		"piercing_shot":
			if fight:
				var a := int(ev.get("from", 0))
				var b := int(ev.get("enemy_idx", 0))
				if a < c.stage.enemy_count() and b < c.stage.enemy_count():
					var pa := c.stage.enemy_position(a) + Vector3.UP * 0.9
					var pb := c.stage.enemy_position(b) + Vector3.UP * 0.9
					Audio.play_sfx("swing")
					await Fx.projectile(c.stage, pa, pb, col, 0.22 / c.speed)
					Fx.hit_sparks(c.stage, pb, col, 20)
					Fx.popup_text(c.stage, pb + Vector3.UP * 0.9, "PIERCE!", col.lightened(0.2), 0.8)
			await c.wait(0.15)
		"shadow_step":
			var at := c.hero_pos()
			Fx.burst(wp, at + Vector3.UP * 0.6, {"amount": 28, "lifetime": 0.7, "speed": Vector2(1.0, 2.6), "size": 0.42,
				"colors": PackedColorArray([Color(0.2, 0.1, 0.3, 0.9), SHADOW, Color(0.1, 0.05, 0.15, 0.0)]), "tex": "dot",
				"additive": false, "spread": 180.0, "gravity": Vector3(0, 1.2, 0)})
			_afterimage(c)
			Audio.play_sfx("portal")
			var where := c.hero_screen(2.5)
			if c.tray.is_visible_in_tree() and not c.tray.dice.is_empty():
				where = c.tray.get_global_rect().get_center() + Vector2(0.0, -c.tray.size.y * 0.12)
			c.overlay.popup(where, "SHADOW STEP · FREE REROLL", col.lightened(0.25), "mech_shadow_step", 28)
			await c.wait(0.45)
		"overgrowth":
			Fx.burst(wp, c.hero_pos() + Vector3.UP * 0.5, {"amount": 26, "lifetime": 1.0, "speed": Vector2(1.0, 3.0),
				"size": 0.3, "color": LEAF, "tex": "spark", "spread": 70.0, "gravity": Vector3(0, -2.0, 0)})
			Audio.play_sfx("heal")
			c.overlay.popup(c.hero_screen(2.4), text, LEAF.lightened(0.2), "mech_overgrowth", 34)
			await c.wait(0.4)
		"seed":
			pass    # die_tagged pops the die itself
		"wild_bond":
			c.overlay.popup(c.hero_screen(2.3), text, LEAF.lightened(0.2), "mech_overgrowth", 28)
			await c.wait(0.2)
		"bone_harvest":
			Fx.burst(wp, c.hero_pos() + Vector3.UP * 0.2, {"amount": 26, "lifetime": 1.1, "speed": Vector2(0.4, 1.8),
				"gravity": Vector3(0, 3.0, 0), "size": 0.34, "color": SOUL, "tex": "dot", "spread": 30.0})
			Fx.shockwave(wp, c.hero_pos() + Vector3.UP * 0.05, SOUL, 1.6, 0.6)
			Audio.play_sfx("glass")
			var why := String(ev.get("reason", "kill"))
			c.overlay.popup(c.hero_screen(2.5), "BONES RISE" if why == "kill" else ("THE GRAVE STIRS" if why == "lone" else "BONES RISE"),
				SOUL, "mech_bone_harvest", 32)
			c.overlay.toast("A Bone die joins next turn (this fight only)", "mech_bone_harvest", SOUL)
			await c.wait(0.5)
		"bone_crumble":
			c.overlay.popup(c.hero_screen(2.4), text, Color(0.92, 0.86, 0.7), "mech_bone_harvest", 30)
			await c.wait(0.25)
		"boo":
			await _boo(c, int(ev.get("enemy_idx", -1)))
		_:
			if text != "":
				c.overlay.popup(c.hero_screen(2.4), text, col, UiIcons.mechanic_icon(mech), 30)
				await c.wait(0.3)


## A shrinking targeting ring on enemy `i` (Ranger Aim).
static func _reticle(c: GameController, i: int, col: Color) -> void:
	if i < 0 or i >= c.stage.enemy_count():
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	mi.mesh = q
	var m := Props.glow_material(col, true, 2.0)
	m.albedo_texture = Props.particle_texture("ring")
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.stage.add_child(mi)
	mi.global_position = c.stage.enemy_position(i) + Vector3.UP * 0.9
	mi.scale = Vector3.ONE * 1.6
	var t := mi.create_tween()
	t.tween_property(mi, "scale", Vector3.ONE * 0.5, 0.35 / c.speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_interval(0.25 / c.speed)
	t.tween_property(m, "albedo_color:a", 0.0, 0.2 / c.speed)
	t.tween_callback(mi.queue_free)


## Ninja Shadow Step: the hero blinks out and back (a fading afterimage flicker).
static func _afterimage(c: GameController) -> void:
	var h: Character = c.board.hero
	if h == null:
		return
	var t := h.create_tween()
	for k in 3:
		t.tween_callback(func() -> void: h.visible = false)
		t.tween_interval(0.05)
		t.tween_callback(func() -> void: h.visible = true)
		t.tween_interval(0.06)


# --- Monster Kid: BOO! and the scared enemies -----------------------------------------------

## BOO!: the dino hood comes down, the kid roars, the screen jolts.
static func _boo(c: GameController, i: int) -> void:
	var h: Character = c.board.hero
	HeroLook.boo_head(h, true)
	h.play_once("taunt" if h.has_anim("taunt") else "cheer", "idle", 0.05, 1.2)
	Audio.play_sfx("drum")
	Audio.play_sfx("fwump")
	c.rig.shake(0.6, 0.35)
	var at := c.hero_pos() + Vector3.UP * 1.6
	Fx.burst(c.world_parent(), at, {"amount": 20, "lifetime": 0.6, "speed": Vector2(3.0, 6.0), "size": 0.3,
		"color": SCARE, "tex": "spark", "spread": 60.0, "dir": Vector3.UP, "gravity": Vector3.ZERO})
	if i >= 0 and i < c.stage.enemy_count():
		var from := c.hero_pos() + Vector3.UP * 1.2
		var to := c.stage.enemy_position(i) + Vector3.UP * 1.0
		Fx.shockwave(c.stage, c.stage.enemy_position(i) + Vector3.UP * 0.05, SCARE, 1.4, 0.45)
		_boo_word(c, from.lerp(to, 0.45))
	else:
		_boo_word(c, at)
	await c.wait(0.75)
	HeroLook.boo_head(h, false)


## A big comic "BOO!" in world space that punches in and wobbles.
static func _boo_word(c: GameController, pos: Vector3) -> void:
	var l := Fx.popup_text(c.world_parent(), pos, "BOO!", SCARE.lightened(0.15), 2.1, true)
	l.outline_modulate = Color(0.1, 0.2, 0.05, 1.0)


## enemy_scared {enemy_idx, effect: cower | flee | weaken}.
static func enemy_scared(c: GameController, ev: Dictionary) -> void:
	var i := int(ev.get("enemy_idx", -1))
	if i < 0 or i >= c.stage.enemy_count():
		return
	var st := c.stage
	var ch: Character = st.enemies[i]
	var eff := String(ev.get("effect", "cower"))
	var top := st.enemy_position(i) + Vector3.UP * (EnemyLooks.hud_height(String(st.data[i].get("id", ""))) * CombatStage.UNIT_SCALE - 0.2)
	match eff:
		"cower":
			st.set_enemy(i, {"cower": true, "brave": true})
			_tremble(ch, 0.8)
			ch.play_once("hit", EnemyLooks.clip(String(st.data[i].get("id", "")), "idle"), 0.05)
			_sweat(st, st.enemy_position(i) + Vector3.UP * 1.4)
			Fx.popup_text(st, top, "SCARED!", SCARE.lightened(0.1), 0.9, true)
			await c.wait(0.45)
		"weaken":
			st.set_enemy(i, {"weakened": true, "brave": true})
			_tremble(ch, 0.5)
			_sweat(st, st.enemy_position(i) + Vector3.UP * 2.0)
			Fx.popup_text(st, top, "SPOOKED! -%d%%" % int(round(ClassLogic.BOO_WEAKEN * 100.0)), SCARE.lightened(0.1), 0.85, true)
			await c.wait(0.45)
		"flee":
			st.set_enemy(i, {"brave": true})
			_tremble(ch, 0.35)
			_sweat(st, st.enemy_position(i) + Vector3.UP * 1.4)
			Fx.popup_text(st, top, "EEK!", SCARE.lightened(0.1), 1.0, true)
			await c.wait(0.3)


## enemy_fled {enemy_idx, gold, id}: it turns tail and runs off the board.
static func enemy_fled(c: GameController, ev: Dictionary) -> void:
	var i := int(ev.get("enemy_idx", -1))
	if i < 0 or i >= c.stage.enemy_count():
		return
	var st := c.stage
	var pos := st.enemy_position(i)
	var g := int(ev.get("gold", 0))
	Fx.popup_text(st, pos + Vector3.UP * 1.6, "FLED!", SCARE.lightened(0.2), 1.0)
	if g > 0:
		Fx.coin_burst(st, pos + Vector3.UP * 0.5, clampi(g / 2, 3, 8))
		Audio.play_sfx("coin")
	await st.enemy_flee(i)
	var left := 0
	for d: Dictionary in st.data:
		if int(d.get("hp", 0)) > 0:
			left += 1
	if left > 0:
		st.reframe()


## status {status: "cower", skipped: true}: the scared enemy hides instead of acting.
static func cower(c: GameController, ev: Dictionary) -> void:
	var i := int(ev.get("target", -1))
	if i < 0 or i >= c.stage.enemy_count():
		return
	var st := c.stage
	var ch: Character = st.enemies[i]
	st.set_enemy(i, {"cower": false})
	ch.play_once("block" if ch.has_anim("block") else "hit", EnemyLooks.clip(String(st.data[i].get("id", "")), "idle"), 0.05)
	_tremble(ch, 0.9)
	_sweat(st, st.enemy_position(i) + Vector3.UP * 1.4)
	Fx.popup_text(st, st.enemy_position(i) + Vector3.UP * 1.9, "COWERS!", SCARE.lightened(0.1), 0.85)
	Audio.play_sfx("fwump")
	await c.wait(0.6)


## A quick side-to-side shiver.
static func _tremble(n: Node3D, time: float) -> void:
	var base := n.rotation.y
	var t := n.create_tween()
	var steps := int(time / 0.05)
	for k in steps:
		t.tween_property(n, "rotation:y", base + (0.12 if k % 2 == 0 else -0.12), 0.05)
	t.tween_property(n, "rotation:y", base, 0.05)


## Blue sweat drops flying off a scared enemy's head.
static func _sweat(parent: Node3D, pos: Vector3) -> void:
	Fx.burst(parent, pos, {"amount": 10, "lifetime": 0.7, "speed": Vector2(1.5, 3.0), "size": 0.16,
		"color": Color(0.55, 0.85, 1.0), "tex": "dot", "spread": 55.0, "gravity": Vector3(0, -9.0, 0), "additive": false})


# --- Engineer: the Clockwork Turret ----------------------------------------------------------

## turret_fired {value, damage, rune, target}: the turret swivels, recoils and shoots; the tray's
## turret die rolls the shot. The damage event that follows shows the number.
static func turret_fired(c: GameController, ev: Dictionary) -> void:
	var v := int(ev.get("value", 0))
	var t := int(ev.get("target", 0))
	c.tray.roll_turret(v)
	var tur := HeroLook.turret_of(c.board.hero)
	var from := c.hero_pos() + Vector3.UP * 0.9
	if tur:
		from = tur.global_position + Vector3.UP * 0.55
	var to := from + Vector3.FORWARD * 3.0
	if t >= 0 and t < c.stage.enemy_count():
		to = c.stage.enemy_position(t) + Vector3.UP * 0.9
	if tur:
		var look := to - tur.global_position
		look.y = 0.0
		var model := tur.get_node_or_null("Model") as Node3D
		if model and look.length() > 0.01:
			var yaw := atan2(look.x, look.z) - c.board.hero.global_rotation.y
			var tw := model.create_tween()
			tw.tween_property(model, "rotation:y", yaw, 0.12 / c.speed)
			tw.tween_property(model, "position", -Vector3(sin(yaw), 0.0, cos(yaw)) * 0.12, 0.05 / c.speed)
			tw.tween_property(model, "position", Vector3.ZERO, 0.18 / c.speed).set_trans(Tween.TRANS_BACK)
	Audio.play_sfx("whirr")
	await c.wait(0.28)
	Fx.burst(c.world_parent(), from, {"amount": 12, "lifetime": 0.3, "speed": Vector2(2.0, 4.0), "size": 0.22,
		"color": BRASS, "tex": "spark", "spread": 40.0, "gravity": Vector3.ZERO})
	Audio.play_sfx("clink")
	await Fx.projectile(c.stage, from, to, BRASS, 0.22 / c.speed)
	var r := c.tray.get_turret_screen_rect()
	if r.size != Vector2.ZERO:
		var tier_t := float(ev.get("damage", 0)) / maxf(float(v), 1.0)
		c.overlay.popup(Vector2(r.get_center().x, r.position.y), "%d ×%s" % [v, ClassInfo._num(tier_t)] if v > 0 else "JAM", BRASS.lightened(0.2), "mech_turret", 24)
