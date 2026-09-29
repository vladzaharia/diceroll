class_name TwistBeats
extends RefCounted
## Presentation beats for the 2026-09-29 biome twists (docs/design/2026-09-29-new-biomes.md):
## Deep Mines ore / cave-ins, Orc Warcamp drums and their rally, Sunscorched Ruins heat and
## oases, Moonlit Woods moon phases, the moon rune chest, moon transforms, and the boss beats that
## are HUD-side: the Moon King's moon meter, Moonfall and the Sand Colossus's Bury. Called from
## EventPlayer; every wait goes through the controller (game speed aware). Never mutates rules.
## The board side (cave-in dust, smashed staves, drum thumps, the sky moon) is BoardView's.

const ORE := Color(0.37, 0.88, 0.82)
const DRUM := Color(0.91, 0.34, 0.2)
const HEAT := Color(1.0, 0.55, 0.16)
const COOL := Color(0.4, 0.88, 1.0)
const MOON := Color(0.78, 0.84, 1.0)
const BLOOD := Color(1.0, 0.36, 0.3)
const SAND := Color(0.92, 0.74, 0.42)
const PHASE_NAMES := {"crescent": "Crescent Moon", "half": "Half Moon", "full": "FULL MOON"}


# --- Deep Mines -----------------------------------------------------------------------------------

## ore_mined {idx, choice: "gold"|"raise", gold}: the pick strikes the vein (sparks, a ting); the
## gold arrives with its gold_changed, the Raise with the Forge offer that follows.
static func ore_mined(c: GameController, ev: Dictionary) -> void:
	var idx := int(ev.get("idx", c.board.hero_idx))
	var p := c.board.tile_position(idx)
	c.board.hero.play_once("attack", "idle", 0.05, 1.3)
	await c.wait(0.18)
	Audio.play_sfx("tin")
	Fx.burst(c.board, p + Vector3.UP * 0.5, {"amount": 20, "lifetime": 0.55, "speed": Vector2(2.0, 4.5), "size": 0.18,
		"color": ORE if String(ev.get("choice", "")) == "raise" else Color(1.0, 0.85, 0.35), "tex": "spark", "spread": 70.0})
	var raise := String(ev.get("choice", "")) == "raise"
	c.overlay.popup(c.hero_screen(2.3), "Smelted! Raise a face" if raise else "Ore mined!", ORE.lightened(0.2) if raise else UiPalette.GOLD_BRIGHT,
		"anvil" if raise else "ore", 32)
	await c.wait(0.35)


## tile_changed {source: "cave_in"}: the mined vein's ceiling comes down (a rumble, dust and a
## pebble trickle) and the tile is a trap for the rest of the biome.
static func cave_in(c: GameController, ev: Dictionary) -> void:
	var idx := int(ev.get("idx", c.board.hero_idx))
	Audio.play_sfx("trap")
	c.rig.shake(0.45, 0.6)
	c.board.cave_in(idx)
	await c.wait(0.3)
	c.overlay.popup(c.hero_screen(2.0), "CAVE-IN!  Now a trap", Color("c8bca8"), "skull", 30)
	await c.wait(0.55)


# --- Orc Warcamp ----------------------------------------------------------------------------------

## drum_smashed {idx, gold, drums}: the hero smashes the war drum into staves.
static func drum_smashed(c: GameController, ev: Dictionary) -> void:
	var idx := int(ev.get("idx", c.board.hero_idx))
	c.board.hero.play_once("attack", "idle", 0.05, 1.4)
	await c.wait(0.2)
	Audio.play_sfx("drum")
	Audio.play_sfx("trap")
	c.rig.shake(0.35, 0.3)
	await c.board.smash_drum(idx)
	var left := int(ev.get("drums", 0))
	c.overlay.popup(c.hero_screen(2.4), "DRUM SMASHED!", DRUM.lightened(0.25), "drum", 34)
	c.overlay.toast("No war drums left: foes fight unrallied" if left == 0 else "%d war drum%s still beat%s" % [left,
		"" if left == 1 else "s", "s" if left == 1 else ""], "drum", DRUM.lightened(0.3))
	await c.wait(0.45)


## rally {source: "drum", value, drums} at fight start: the camp's drums thump (board rings, a
## camera nudge) and a war-cry card; the per-enemy flares follow (drum_rally_enemy).
static func drum_rally(c: GameController, ev: Dictionary) -> void:
	var v := int(ev.get("value", 0))
	var n := int(ev.get("drums", 1))
	for k in 2:
		Audio.play_sfx("drum")
		c.rig.shake(0.3, 0.16)
		await c.wait(0.2)
	c.board.drum_beat(2)
	c.overlay.announce("WAR DRUMS!" if n > 1 else "WAR DRUM!", "Every foe +%d ATK  ·  smash the drums!" % v,
		DRUM.lightened(0.2), 0.9, 0.42)
	await c.wait(0.5)


## One enemy's flare from the drums' rally (status buff {source: "drum", rally: true}).
static func drum_rally_enemy(c: GameController, ev: Dictionary, gain: int) -> void:
	var i := int(ev.target)
	if i >= c.stage.enemy_count():
		return
	var st := c.stage
	var pos := st.enemy_position(i) + Vector3.UP
	Fx.status_burst(st, pos, "buff")
	var ch: Character = st.enemies[i]
	ch.play_once("cheer" if ch.has_anim("cheer") else "hit", EnemyLooks.clip(String(st.data[i].get("id", "")), "idle"), 0.08)
	Fx.popup_text(st, pos + Vector3.UP * 0.9, "+%d ATK" % gain if gain > 0 else "ATK UP", DRUM.lightened(0.3), 0.7)
	await c.wait(0.12)


# --- Sunscorched Ruins ----------------------------------------------------------------------------

## heat {damage, cooled} at a Ruins lap's end: a scorching pulse (orange flash, shimmer) or, after
## an oasis, a cool relief beat.
static func heat(c: GameController, ev: Dictionary) -> void:
	if bool(ev.get("cooled", false)):
		Fx.burst(c.board, c.hero_pos() + Vector3.UP * 1.0, {"amount": 14, "lifetime": 0.8, "speed": Vector2(0.5, 1.4),
			"size": 0.16, "color": COOL, "tex": "hard", "gravity": Vector3(0, -2.0, 0)})
		c.overlay.popup(c.hero_screen(2.4), "The oasis kept you cool", COOL.lightened(0.2), "oasis", 30)
		await c.wait(0.5)
		return
	Audio.play_sfx("swoosh")
	Fx.flash(c, Color(1.0, 0.5, 0.1, 0.42), 0.6)
	c.overlay.vignette(0.35, 0.2)
	Fx.burst(c.board, c.hero_pos() + Vector3.UP * 0.9, {"amount": 18, "lifetime": 0.9, "speed": Vector2(0.6, 1.6),
		"size": 0.4, "color": Color(1.0, 0.62, 0.25, 0.8), "tex": "dot", "gravity": Vector3(0, 1.5, 0), "spread": 40.0})
	c.overlay.announce("SCORCHING HEAT", "-%d HP  ·  land on an oasis to stay cool" % int(ev.get("damage", 0)),
		HEAT.lightened(0.1), 0.8, 0.3)
	await c.wait(0.9)
	c.overlay.vignette(0.0, 0.5)


## oasis {idx, healed}: a splash and a cool ring; the lap is cooled (the HUD sun turns to water).
static func oasis(c: GameController, ev: Dictionary) -> void:
	Audio.play_sfx("heal")
	c.board.oasis_splash(int(ev.get("idx", c.board.hero_idx)))
	c.overlay.popup(c.hero_screen(2.4), "OASIS!  Cool this lap", COOL.lightened(0.2), "oasis", 32)
	await c.wait(0.4)


# --- Moonlit Woods --------------------------------------------------------------------------------

## moon_phase {phase, lap, laps_to_full}: the sky moon grows; the Full lap gets its own card.
static func moon_phase(c: GameController, ev: Dictionary) -> void:
	var ph := String(ev.get("phase", ""))
	c.board.set_moon_phase(ph, true)
	match ph:
		"full":
			if _full_lap != int(ev.get("lap", -1)):
				await full_moon(c, int(ev.get("lap", -1)))
		"half":
			c.overlay.toast("Half moon: werewolves turn at 65% HP", "biome_moonlit", MOON)
			await c.wait(0.4)
		"crescent":
			var n := int(ev.get("laps_to_full", -1))
			if n > 0:
				c.overlay.toast("Crescent moon: full in %d lap%s" % [n, "" if n == 1 else "s"], "biome_moonlit", MOON)
			else:
				c.overlay.toast("The moon wanes", "biome_moonlit", MOON)
			await c.wait(0.3)


## Lap whose Full moon card already played (the moon chest beat plays it first, before its reveal).
static var _full_lap := -1


## The Full moon card: the sky moon fills, a silver flash and the lap's rules.
static func full_moon(c: GameController, lap: int) -> void:
	_full_lap = lap
	c.board.set_moon_phase("full", true)
	c.ui.board_hud.top._show_twist("moon:full:0", true)
	Audio.play_sfx("portal")
	Fx.flash(c, Color(0.75, 0.82, 1.0, 0.35), 0.6)
	c.overlay.announce("FULL MOON", "Wolves changed  ·  2× elites  ·  ×1.5 gold",
		MOON, 1.3, 0.28)
	await c.wait(1.4)


## tile_changed {source: "full_moon", moon: true}: the moon rune chest appears on the board (after
## the Full moon card, which it plays first: this event comes before moon_phase).
static func moon_chest(c: GameController, ev: Dictionary) -> void:
	if _full_lap != c.flow.run.lap:
		await full_moon(c, c.flow.run.lap)
	var idx := int(ev.get("idx", 0))
	var p := c.board.tile_global_position(idx)
	c.rig.frame_points(PackedVector3Array([p + Vector3(-3.0, 0, -2.2), p + Vector3(3.0, 0, 3.4), p + Vector3.UP * 3.0]), 0.0, 46.0)
	await c.wait(0.5)
	c.board.set_tile(idx, {"type": "chest", "moon": true}, true)
	var lp := c.board.tile_position(idx)
	Fx.burst(c.board, lp + Vector3.UP * 0.5, {"amount": 34, "lifetime": 1.0, "speed": Vector2(1.5, 4.0), "size": 0.26,
		"color": MOON, "tex": "spark", "spread": 70.0})
	Fx.shockwave(c.board, lp + Vector3.UP * 0.05, MOON, 2.4, 0.6)
	Audio.play_sfx("chest")
	c.overlay.toast("A moonlit rune chest: a Rare or Epic rune awaits", "chest", MOON)
	await c.wait(1.1)
	c.rig.home(c.board.hero)


## enemy_transformed {source: "moon"} at fight start: the Full moon has already changed them.
static func moon_transformed(c: GameController, ev: Dictionary, first: bool) -> void:
	if first:
		Fx.flash(c, Color(0.7, 0.78, 1.0, 0.3), 0.5)
		c.overlay.popup(c.hero_screen(2.8), "Under the full moon...", MOON, "biome_moonlit", 30)
	await AffixBeats.transformed(c, ev)


# --- boss beats (HUD side) -------------------------------------------------------------------------

## Index of the Moon King on the stage (-1 when absent).
static func moon_king(c: GameController) -> int:
	for k in c.stage.data.size():
		if String(c.stage.data[k].get("id", "")) == "boss_moon_king":
			return k
	return -1


## moon_meter {value, delta, source, max}: the boss HUD's moon fills with the tide, your 1s push it
## back (clouds), Moonrise / Moonfall empty it. The sky moon follows.
static func moon_meter(c: GameController, ev: Dictionary) -> void:
	var i := moon_king(c)
	var v := int(ev.get("value", 0))
	var mx := maxi(int(ev.get("max", EnemyDefs.MOON_MAX)), 1)
	var src := String(ev.get("source", ""))
	var blood := i >= 0 and int(c.stage.data[i].get("phase", 1)) >= 2
	if i >= 0:
		c.stage.set_enemy(i, {"moon": v, "moon_max": mx, "moon_blood": blood})
	c.board.set_moon_fill(clampf(float(v) / float(mx), 0.0, 1.0), src != "start")
	var at := _above(c, i)
	match src:
		"moonfang":
			c.overlay.toast("Moonfang's fang dims the moon", "biome_moonlit", MOON)
			await c.wait(0.4)
		"tide":
			Audio.play_sfx("portal")
			if i >= 0:
				# in the boss HUD's own frame, under the HP bar: a world popup rising from under the HUD
				# crossed the intent number and the HP bar
				c.stage.huds[i].flash_note("TIDE %d/%d" % [maxi(v, 0), mx], MOON if not blood else BLOOD.lightened(0.3))
			if v == mx - 1:
				c.overlay.toast("The moon is nearly full: roll 1s to push it back!", "biome_moonlit", MOON)
			await c.wait(0.45)
		"clouds":
			var ones: Array[int] = []
			for d in c.tray.dice.size():
				if c.tray.get_up_value(d) == 1:
					ones.append(d)
			if not ones.is_empty():
				c.tray.highlight_group(ones, MOON)
			Audio.play_sfx("block")
			if i >= 0:
				c.stage.huds[i].flash_note("CLOUDS %d" % int(ev.get("delta", 0)), MOON.lightened(0.2))
				Fx.burst(c.stage, at - Vector3.UP * 0.3, {"amount": 14, "lifetime": 0.8, "speed": Vector2(0.4, 1.2),
					"size": 0.5, "color": Color(0.7, 0.74, 0.9, 0.7), "tex": "dot", "additive": false, "gravity": Vector3(0, 0.5, 0)})
			c.overlay.popup(c.hero_screen(2.2), "Your 1s cloud the moon", MOON, "biome_moonlit", 28)
			await c.wait(0.55)
			c.tray.clear_highlight()
		"moonrise":
			# the forced phase switch played already (boss_phase {forced, source: "moonrise"})
			c.overlay.popup(c.hero_screen(2.6), "The meter resets", MOON, "biome_moonlit", 26)
			await c.wait(0.3)
		"moonfall":
			Audio.play_sfx("fanfare")
			c.rig.shake(0.5, 0.4)
			c.overlay.announce("MOONFALL", "Its next blow ignores Block", BLOOD.lightened(0.2) if blood else MOON, 1.0, 0.24)
			await c.wait(1.0)


## The Moonfall blow lands: the moon plunges from the sky onto the hero.
static func moonfall_strike(c: GameController) -> void:
	var to := c.hero_pos() + Vector3.UP * 0.8
	var from := to + Vector3(-3.0, 7.0, -3.0)
	await Fx.projectile(c.stage, from, to, Color(1.0, 0.55, 0.45), 0.35 / c.speed)
	Fx.shockwave(c.stage, c.hero_pos() + Vector3.UP * 0.05, Color(1.0, 0.5, 0.4), 2.6, 0.5)
	Fx.flash(c, Color(1.0, 0.55, 0.5, 0.4), 0.4)
	c.rig.shake(0.8, 0.5)


## Bury (status curse {bury: true}): the Sand Colossus drags dice into the sand for a turn.
static func bury(c: GameController, ev: Dictionary) -> void:
	var src := int(ev.get("source", -1))
	if src >= 0 and src < c.stage.enemy_count():
		var ch: Character = c.stage.enemies[src]
		ch.play_once("cast" if ch.has_anim("cast") else "attack", EnemyLooks.clip(String(c.stage.data[src].get("id", "")), "idle"), 0.08, 1.2)
		await Fx.projectile(c.stage, c.stage.enemy_position(src) + Vector3.UP * 1.2, c.hero_pos() + Vector3.UP * 0.4, SAND, 0.3 / c.speed)
	Fx.burst(c.stage, c.hero_pos() + Vector3.UP * 0.2, {"amount": 30, "lifetime": 0.9, "speed": Vector2(1.0, 3.0), "size": 0.3,
		"color": SAND, "tex": "dot", "additive": false, "spread": 70.0, "gravity": Vector3(0, -5.0, 0)})
	Audio.play_sfx("trap")
	var n := int(ev.get("value", 1))
	c.overlay.popup(c.hero_screen(2.2), "BURIED! %d %s locked next turn" % [n, "die" if n == 1 else "dice"], SAND.lightened(0.15),
		"intent_bury", 30)
	await c.wait(0.45)


static func _above(c: GameController, i: int) -> Vector3:
	if i < 0 or i >= c.stage.enemy_count():
		return c.hero_pos() + Vector3.UP * 2.0
	# just under the boss HUD, toward its moon meter (above it the top HUD covers it on phones)
	var right := Vector3.RIGHT
	var cam := c.get_viewport().get_camera_3d()
	if cam:
		right = cam.global_basis.x
	return c.stage.enemy_position(i) + Vector3.UP * (EnemyLooks.hud_height(String(c.stage.data[i].get("id", ""))) * CombatStage.UNIT_SCALE - 0.4) \
		+ right * 0.35
