class_name BiomeBeats
extends RefCounted
## Presentation beats for the biome mechanics (Frostpeak ice, Magma lava / burn / scorch,
## Glade and Hollow heals and drains, traits: thorns, ward, pierce, the Golem's shatter).
## Called from EventPlayer so its own match stays small; every wait goes through the
## controller (game speed aware). Never mutates rules.

const ICE := Color(0.62, 0.88, 1.0)
const EMBER := Color(1.0, 0.5, 0.15)
const HEAL := Color(0.45, 1.0, 0.5)
const DRAIN := Color(0.9, 0.2, 0.35)
const WARD := Color(0.72, 0.5, 1.0)


## Frostpeak ice tile: a 4+ roll keeps your footing; a slip freezes dice for the next fight.
static func trap_ice(c: GameController, ev: Dictionary) -> void:
	var dodged := bool(ev.dodged)
	Audio.play_sfx("block")
	var p := c.board.tile_position(c.board.hero_idx) + Vector3.UP * 0.3
	Fx.status_burst(c.board, p, "frost")
	await c.overlay.mini_dice("ICE!  Roll 4+ to keep your footing", [{"values": [int(ev.roll)], "label": ""}],
		"Steady!" if dodged else "Slipped! %d %s freeze next fight" % [int(ev.get("chill", 1)), "die" if int(ev.get("chill", 1)) == 1 else "dice"],
		UiPalette.HEAL if dodged else ICE)
	if not dodged:
		c.board.hero.play_once("hit", "idle", 0.05)
		Fx.status_burst(c.board, c.hero_pos() + Vector3.UP, "frost")


## Magma lava tile: the tile flares red and embers burst (landing burns more than passing).
static func lava(c: GameController, ev: Dictionary) -> void:
	var idx := int(ev.idx)
	var p := c.board.tile_position(idx)
	c.board.pulse_tile(idx, Color(1.0, 0.25, 0.08))
	Fx.burst(c.board, p + Vector3.UP * 0.2, {"amount": 26 if bool(ev.get("landed", false)) else 12, "lifetime": 0.7,
		"speed": Vector2(1.5, 4.5), "size": 0.22, "color": EMBER, "tex": "spark", "spread": 35.0})
	Audio.play_sfx("trap")
	if bool(ev.get("landed", false)):
		c.overlay.popup(c.hero_screen(2.4), "LAVA!", Color("ff6a2a"), "flame", 34)
	await c.wait(0.15)


## An enemy heals (Heal intent on all allies, or Drain's lifesteal).
static func enemy_healed(c: GameController, ev: Dictionary) -> void:
	var i := int(ev.enemy_idx)
	if i >= c.stage.enemy_count():
		return
	var drain := String(ev.get("source", "")) == "drain"
	var pos := c.stage.enemy_position(i)
	Fx.heal_glow(c.stage, pos)
	if drain:
		await Fx.projectile(c.stage, c.hero_pos() + Vector3.UP, pos + Vector3.UP * 1.2, DRAIN, 0.25 / c.speed)
	Fx.popup_text(c.stage, pos + Vector3.UP * (EnemyLooks.hud_height(String(c.stage.data[i].get("id", ""))) * CombatStage.UNIT_SCALE + 0.9),
		"+%d" % int(ev.amount), DRAIN.lightened(0.3) if drain else HEAL, 0.8)
	Audio.play_sfx("heal")
	c.stage.set_enemy(i, {"hp": int(ev.hp), "max_hp": int(ev.max_hp)})
	await c.wait(0.35)


## Hero-target damage extras. Returns true when the beat replaced the attacker's lunge
## (thorns reflect, burn tick: no enemy swings).
static func hero_damage(c: GameController, ev: Dictionary) -> bool:
	match String(ev.get("source", "")):
		"burn":
			Fx.status_burst(c.stage, c.hero_pos() + Vector3.UP, "ember")
			c.overlay.popup(c.hero_screen(2.6), "BURN", Color("ff8a3a"), "flame", 28)
			return true
		"thorns":
			var a := int(ev.get("attacker", -1))
			if a >= 0 and a < c.stage.enemy_count():
				Fx.burst(c.stage, c.stage.enemy_position(a) + Vector3.UP * 0.8, {"amount": 14, "lifetime": 0.5,
					"speed": Vector2(2.0, 4.0), "size": 0.16, "color": Color(0.5, 0.8, 0.3), "tex": "spark", "spread": 60.0})
			c.overlay.popup(c.hero_screen(2.6), "THORNS", Color("8fcf5a"), "trait_thorns", 26)
			return true
	if bool(ev.get("pierce", false)) and int(ev.get("amount", 0)) > 0:
		c.overlay.popup(c.hero_screen(2.9), "PIERCE", Color("ff7a4a"), "trait_pierce", 26)
	return false


## Enemy-target damage extras (after the hit): ward halves damage while minions stand.
static func enemy_damage(c: GameController, ev: Dictionary) -> void:
	var i := int(ev.target)
	if bool(ev.get("warded", false)) and i < c.stage.enemy_count():
		c.stage.flash_ward(i)
		Fx.popup_text(c.stage, c.stage.enemy_position(i) + Vector3.UP * 2.2, "WARDED", WARD, 0.7)


## Hero statuses from the biome intents. Returns true when handled.
static func hero_status(c: GameController, ev: Dictionary) -> bool:
	var st := String(ev.status)
	var src := int(ev.get("source", -1))
	match st:
		"burn":
			if src >= 0 and src < c.stage.enemy_count():
				var ch: Character = c.stage.enemies[src]
				ch.play_once("cast" if ch.has_anim("cast") else "attack", EnemyLooks.clip(String(c.stage.data[src].get("id", "")), "idle"), 0.08, 1.2)
				await Fx.projectile(c.stage, c.stage.enemy_position(src) + Vector3.UP * 1.2, c.hero_pos() + Vector3.UP, EMBER, 0.28 / c.speed)
				Fx.status_burst(c.stage, c.hero_pos() + Vector3.UP, "ember")
				c.overlay.popup(c.hero_screen(2.2), "BURN %d" % int(ev.value), Color("ff8a3a"), "flame", 32)
				Audio.play_sfx("hit")
				await c.wait(0.4)
			return true
		"scorch":
			if src >= 0 and src < c.stage.enemy_count():
				await Fx.projectile(c.stage, c.stage.enemy_position(src) + Vector3.UP * 1.4, c.hero_pos() + Vector3.UP, EMBER, 0.3 / c.speed)
			c.tray.set_dice(c.flow.run.dice)
			var r := c.tray.get_die_screen_rect(int(ev.get("die_idx", 0)))
			c.overlay.popup(Vector2(r.get_center().x, r.position.y) if r.size != Vector2.ZERO else c.hero_screen(2.2),
				"SCORCHED! A face becomes blank", Color("ff6a2a"), "intent_scorch", 28)
			await c.wait(0.5)
			return true
		"chill":
			# frozen on the ice: dice lock on this fight's first turn
			Fx.status_burst(c.stage, c.hero_pos() + Vector3.UP, "frost")
			c.overlay.toast("Frozen! %d %s locked this turn" % [int(ev.value), "die" if int(ev.value) == 1 else "dice"], "snowflake", ICE)
			await c.wait(0.3)
			return true
		"curse":
			if bool(ev.get("chill", false)) and bool(ev.get("pending", false)):
				Fx.status_burst(c.stage, c.hero_pos() + Vector3.UP, "frost")
				c.overlay.popup(c.hero_screen(2.2), "CHILLED", ICE, "snowflake", 32)
				await c.wait(0.4)
				return true
	return false


## The Golem's shell breaks (phase 2): plates fly off, the body flares.
static func shatter(c: GameController, i: int) -> void:
	if i >= c.stage.enemy_count():
		return
	EnemyLooks.shatter(c.stage.enemies[i])
	c.rig.shake(0.8, 0.5)
	Audio.play_sfx("crit")
	Fx.popup_text(c.stage, c.stage.enemy_position(i) + Vector3.UP * 3.0, "SHELL SHATTERED", EMBER, 1.0)
	await c.wait(0.6)
