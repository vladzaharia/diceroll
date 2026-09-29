class_name BossBeats
extends RefCounted
## Presentation of a final boss changing phase (boss_phase {enemy_idx, phase, traits, form, forced,
## source}); called from EventPlayer. Every boss keeps the shared beat (shake, flash, PHASE 2 banner);
## the 2026-09-29 bosses add theirs (docs/design/2026-09-29-new-biomes.md):
##  - The Moon King swaps to his wolf form (the look's `forms`), the sky turns to a blood moon, and a
##    forced phase (the meter filled: source "moonrise") is announced as MOONRISE.
##  - The Sand Colossus raises its sandstorm aura.
## Never mutates rules.

const BLOOD := Color(1.0, 0.28, 0.24)
const SAND := Color(1.0, 0.78, 0.45)


static func boss_phase(c: GameController, ev: Dictionary) -> void:
	var i := int(ev.get("enemy_idx", 0))
	var on_stage := i < c.stage.enemy_count()
	var id := String(c.stage.data[i].get("id", "")) if on_stage else ""
	var nm := String(c.stage.data[i].get("name", "The boss")) if on_stage else "The boss"
	if on_stage:
		c.stage.set_enemy(i, {"traits": ev.get("traits", []), "phase": int(ev.get("phase", 2))})
	var moonrise := bool(ev.get("forced", false)) and String(ev.get("source", "")) == "moonrise"
	match id:
		"boss_moon_king":
			c.rig.shake(1.0, 0.7)
			Fx.flash(c, Color(BLOOD, 0.5), 0.6)
			c.board.set_blood_moon(true)
			Audio.play_sfx("portal")
			_swap_form(c, i, id, String(ev.get("form", "")))
			if moonrise:
				c.overlay.announce("MOONRISE!", "The full moon drags %s into his wolf form" % nm, BLOOD.lightened(0.15), 1.2)
			else:
				c.overlay.announce("BLOOD MOON", "%s bares his fangs!" % nm, BLOOD.lightened(0.15), 1.0)
			await c.wait(1.3)
		"boss_sand_colossus":
			c.rig.shake(0.9, 0.6)
			Fx.flash(c, Color(SAND, 0.45), 0.5)
			Audio.play_sfx("swoosh")
			if on_stage:
				var ch: Character = c.stage.enemies[i]
				EnemyLooks.sandstorm(ch)
				Fx.burst(c.stage, ch.global_position + Vector3.UP * 1.2, {"amount": 40, "lifetime": 1.1, "speed": Vector2(1.5, 4.5),
					"size": 0.5, "color": Color(0.95, 0.8, 0.55, 0.8), "tex": "dot", "additive": false, "spread": 90.0,
					"gravity": Vector3(0, -1.0, 0)})
			c.overlay.announce("SANDSTORM", "%s rises from the dunes!" % nm, SAND, 1.0)
			await c.wait(1.1)
		_:
			c.rig.shake(0.9, 0.6)
			Fx.flash(c, Color(0.8, 0.2, 0.3, 0.45), 0.5)
			_swap_form(c, i, id, String(ev.get("form", "")))
			c.overlay.announce("PHASE %d" % int(ev.get("phase", 2)), "%s grows furious!" % nm, UiPalette.DANGER, 1.0)
			await c.wait(1.1)


## The boss' model changes form in place when its look has one (the Moon King's wolf).
static func _swap_form(c: GameController, i: int, id: String, form: String) -> void:
	if form == "" or i >= c.stage.enemy_count() or not EnemyLooks.forms_of(id).has(form):
		return
	if String(c.stage.data[i].get("form", "")) == form:
		return
	c.stage.transform_enemy(i, form)
