class_name MinigameBeats
extends RefCounted
## EventPlayer arms for the minigame events (called from EventPlayer._one):
##
##  minigame_started  the save point (the run is saved BEFORE the screen opens: quitting
##                    mid-game resumes the same board), a landing beat on the tile (pulse,
##                    sparkle burst, the hero cheers), then the minigame screen's intro
##  minigame_update   the screen animates the action (dig, pop, scratch, grab)
##  minigame_result   the results beat (medal, score, par meter, Crowns), screen closes;
##                    the reward modal opens at idle (UiRoot.sync)
##  crowns_pending    a bronze "+1 Crown" pick: a toast


static func play(c: GameController, ev: Dictionary) -> void:
	var scr := c.ui.minigame
	scr.speed = c.speed
	if scr.has_meta("watch"):
		(scr.get_meta("watch") as Callable).call(ev)
	match String(ev.get("type", "")):
		"minigame_started":
			await _started(c, ev)
		"minigame_update":
			await scr.play_update(ev)
		"minigame_result":
			await scr.play_result(ev)
		"crowns_pending":
			c.overlay.toast("+%d Crown banked (%d this run)" % [int(ev.get("amount", 1)), int(ev.get("total", 0))], "crown", UiPalette.GOLD_BRIGHT)
			Audio.play_sfx("coin")
			await c.wait(0.4)


static func _started(c: GameController, ev: Dictionary) -> void:
	# save point first: nothing of the game is on screen yet
	c.save()
	var id := String(ev.get("id", ""))
	var col: Color = MgLogic.GAME_COLORS.get(id, UiPalette.GOLD)
	var idx := c.board.hero_idx
	c.board.pulse_tile(idx, col)
	var at := c.board.tile_position(idx)
	Fx.burst(c.board, at + Vector3.UP * 0.4, {"amount": 26, "lifetime": 0.8, "speed": Vector2(1.5, 3.5), "size": 0.22,
		"color": col.lightened(0.3), "tex": "spark", "spread": 60.0})
	Fx.shockwave(c.board, at + Vector3.UP * 0.05, col.lightened(0.2), 2.2, 0.5)
	if c.board.hero:
		c.board.hero.play_once("cheer", "idle")
	Audio.play_sfx("fanfare")
	await c.wait(0.7)
	await c.ui.minigame.open_game(ev)
