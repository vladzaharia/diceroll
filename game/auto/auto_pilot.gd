class_name AutoPilot
extends Node
## AUTO (spec §15 "Speed and AUTO"): while enabled, every time the controller goes idle it
## asks Bot.decide(flow, rules), shows the reason in the HUD ticker, highlights the control
## the step corresponds to (GO pulses, the die to reroll flashes, the chosen card lights up)
## and, after a short visible delay scaled by the game speed, plays the step through the
## normal GameController.run_command path.
##
##  * stop:true -> AUTO turns off and shows "AUTO PAUSED: <stop_reason>" (control handed back).
##  * Any command the player issues (button, key, die tap, enemy / portal tap) and any tap on
##    a game control turns AUTO off (GameController.manual_command + _input below).
##  * Never acts during event playback, a rolling tray, a modal's open/close animation, the
##    pause menu, settings or the die inspector: it waits until everything is still.
##  * Never persisted: a run always starts (or continues) with AUTO off.

signal changed(on: bool)
## Emitted when AUTO hands control back (stop:true, or a step it could not play).
signal stopped(reason: String)
## Emitted after each step AUTO plays: the command and Bot's reason.
signal stepped(cmd: Array, reason: String)

## Visible delay before a step at 1× (divided by the game speed).
const DELAY := 0.45
## Settle time after going idle, before deciding (lets the bottom bar / modal appear).
const SETTLE := 0.2
## Extra look time for picks inside a modal (the chosen card lights up first).
const PICK_EXTRA := 0.35
const MODAL_PHASES := [GameFlow.Phase.DRAFT, GameFlow.Phase.SHOP, GameFlow.Phase.FORGE, GameFlow.Phase.EVENT]

var c: GameController
var enabled := false
var rules: AutoRules
## Steps played since the controller was created (scenarios / tests).
var steps := 0
var last_decision: Dictionary = {}
var _gen := 0
var _pending := false


func _init(controller: GameController) -> void:
	c = controller
	name = "AutoPilot"
	rules = AutoConfig.load_rules()


func _ready() -> void:
	c.idle.connect(_on_idle)
	c.manual_command.connect(_on_manual)


func set_enabled(on: bool) -> void:
	if on == enabled:
		c.ui.auto_hud.set_auto(on)
		return
	enabled = on
	_gen += 1
	_pending = false
	c.ui.auto_hud.set_auto(on)
	if on:
		_kick()
	else:
		c.ui.auto_hud.clear_highlights()
	changed.emit(on)


func toggle() -> void:
	set_enabled(not enabled)


func set_rules(r: AutoRules) -> void:
	rules = r


## Hands control back to the player with a visible reason.
func stop(reason: String) -> void:
	set_enabled(false)
	if reason != "":
		c.ui.auto_hud.show_stop(reason)
	stopped.emit(reason)


func _on_idle(_phase: int) -> void:
	if enabled:
		_kick()


func _on_manual(_cmd: String) -> void:
	if enabled:
		set_enabled(false)


func _kick() -> void:
	if _pending or not enabled:
		return
	_pending = true
	_step(_gen)


func _step(gen: int) -> void:
	await _sleep(SETTLE)
	while gen == _gen and not can_act():
		await _sleep_real(0.08)
	if gen != _gen:
		return
	if c.flow == null or c.flow.is_over():
		_pending = false
		set_enabled(false)
		return
	var d := Bot.decide(c.flow, rules)
	last_decision = d
	if bool(d.get("stop", false)):
		_pending = false
		stop(_pretty(String(d.get("stop_reason", ""))))
		return
	var cmd: Array = d.get("cmd", [])
	if cmd.is_empty():
		_pending = false
		stop("Nothing to do.")
		return
	c.ui.auto_hud.show_reason(String(d.get("reason", "")))
	var look := _present(cmd)
	await _sleep(DELAY + look)
	if gen != _gen:
		return
	while gen == _gen and not can_act():
		await _sleep_real(0.08)
	if gen != _gen:
		return
	_pending = false
	var n := c.flow.commands.size()
	steps += 1
	c.from_auto = true
	c.run_command(String(cmd[0]), cmd.slice(1))
	c.from_auto = false
	if c.flow != null and c.flow.commands.size() == n and not c.busy:
		# the flow refused the step (should not happen): never loop on it
		stop("AUTO couldn't play %s." % String(cmd[0]).replace("_", " "))
		return
	stepped.emit(cmd, String(d.get("reason", "")))


## True when nothing is animating and the flow waits for a command.
func can_act() -> bool:
	if c == null or c.flow == null or c.mode != "run" or c.flow.is_over():
		return false
	if c.busy or get_tree().paused or c.tray.is_rolling():
		return false
	var ui := c.ui
	if ui.pause.visible or ui.settings.visible or ui.auto_settings.visible or ui.inspector.visible:
		return false
	var any_open := false
	for m: UiModal in [ui.draft, ui.passive, ui.rune_assign, ui.shop, ui.forge, ui.event, ui.minigame_reward]:
		if m.visible:
			# opening or closing: wait for the tween to finish
			if not m.is_open() or m.scrim.modulate.a < 0.99:
				return false
			any_open = true
	if c.flow.phase in MODAL_PHASES and not any_open:
		return false
	return true


## Shows what AUTO would do now (reason + highlight held for `hold` s) without acting.
## Screenshot scenarios use it to freeze the AUTO look.
func preview(hold := 30.0) -> Dictionary:
	var d := Bot.decide(c.flow, rules)
	c.ui.auto_hud.set_auto(true)
	if bool(d.get("stop", false)):
		c.ui.auto_hud.show_stop(_pretty(String(d.get("stop_reason", ""))))
	else:
		c.ui.auto_hud.show_reason(String(d.get("reason", "")))
		_present(d.cmd, hold)
	return d


## Highlights what the step will touch; returns extra look time (1× seconds).
func _present(cmd: Array, hold := 0.0) -> float:
	var hud := c.ui.auto_hud
	var ui := c.ui
	var dur := hold if hold > 0.0 else (DELAY + 0.25) / c.speed
	var a := cmd.slice(1)
	match String(cmd[0]):
		"roll_board":
			hud.highlight(ui.board_hud.roll_btn, dur)
		"confirm_move":
			hud.highlight(ui.board_hud.go_btn, dur)
		"board_reroll":
			hud.highlight(ui.board_hud.reroll_btn, dur)
		"combat_toggle":
			var r := c.tray.get_die_screen_rect(int(a[0]))
			if r.size != Vector2.ZERO:
				hud.highlight(r.grow(-4.0), dur)
		"combat_reroll":
			hud.highlight(ui.combat_hud.reroll_btn, dur)
		"combat_attack":
			hud.highlight(ui.combat_hud.attack_btn, dur)
		"combat_set_target":
			var e := int(a[0])
			if e < c.stage.enemy_count():
				var p := c.rig.camera.unproject_position(c.stage.enemy_position(e) + Vector3.UP * 0.9)
				hud.highlight(Rect2(p - Vector2(56, 70), Vector2(112, 140)), dur, UiPalette.HP_BRIGHT)
		"portal_pick":
			var t := int(a[0])
			c.board.pulse_tile(t)
			var p := c.rig.camera.unproject_position(c.board.tile_global_position(t))
			hud.highlight(Rect2(p - Vector2(60, 44), Vector2(120, 88)), dur)
		"pick_draft":
			var kind := String(c.flow.offer.get("kind", ""))
			var m: UiModal = ui.passive if kind == "passive" else (ui.minigame_reward if kind == "reward" else ui.draft)
			return _pick_card(m, int(a[0]), dur)
		"minigame_auto", "minigame_finish":
			hud.highlight(ui.minigame.auto_btn, dur)
		"rune_assign":
			ui.rune_assign.select(int(a[0]))
			hud.highlight(_nth(ui.rune_assign.get("_chips"), int(a[0])), dur + PICK_EXTRA / c.speed)
			hud.highlight(ui.rune_assign.get("_bind"), dur + PICK_EXTRA / c.speed)
			return PICK_EXTRA
		"shop_buy":
			ui.shop.select(int(a[0]))
			if a.size() > 1 and int(a[1]) >= 0:
				ui.shop.call("_pick_die", int(a[1]))
				hud.highlight(_nth(ui.shop.get("_chips"), int(a[1])), dur + PICK_EXTRA / c.speed)
			hud.highlight(_nth(ui.shop.get("_cards"), int(a[0])), dur + PICK_EXTRA / c.speed)
			return PICK_EXTRA
		"shop_reroll":
			hud.highlight(ui.shop.get("_restock"), dur)
		"shop_leave":
			hud.highlight(ui.shop.get("_leave"), dur)
		"forge_apply":
			if String(a[2]) == "skip":
				hud.highlight(ui.forge.get("_skip"), dur)
			else:
				ui.forge.preselect(int(a[0]), int(a[1]), String(a[2]), int(a[3]) if a.size() > 3 else -1)
				hud.highlight(ui.forge.get("_apply"), dur + PICK_EXTRA / c.speed)
				return PICK_EXTRA
		"event_choose":
			var box: Node = ui.event.get("_choices")
			var i := int(a[0])
			if box and i < box.get_child_count():
				var card := box.get_child(i) as OptionCard
				if card:
					card.selected = true
				hud.highlight(card, dur + PICK_EXTRA / c.speed)
			return PICK_EXTRA
	return 0.0


func _pick_card(m: UiModal, i: int, dur: float) -> float:
	m.call("select", i)
	c.ui.auto_hud.highlight(_nth(m.get("_cards"), i), dur + PICK_EXTRA / c.speed)
	c.ui.auto_hud.highlight(m.get("_take"), dur + PICK_EXTRA / c.speed)
	return PICK_EXTRA


static func _nth(arr: Variant, i: int) -> Control:
	if arr is Array and i >= 0 and i < (arr as Array).size():
		return (arr as Array)[i] as Control
	return null


## "The final boss is next." -> "The final boss is next" (the card adds its own framing).
static func _pretty(s: String) -> String:
	s = s.strip_edges()
	if s.ends_with("."):
		s = s.left(s.length() - 1)
	return s


## Scaled, pause-aware wait (the game speed divides it).
func _sleep(t: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(t / maxf(c.speed, 0.25), false).timeout


func _sleep_real(t: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(t, false).timeout


# --- manual takeover: a tap on any game control turns AUTO off -----------------------------

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if not pressed:
		return
	var h := get_viewport().gui_get_hovered_control()
	if h != null and _is_game_control(h):
		set_enabled(false)


## A button inside the bottom bars or a phase modal (not the AUTO layer, top HUD, help).
func _is_game_control(ctl: Control) -> bool:
	var ui := c.ui
	var btn: Node = ctl
	while btn != null and not (btn is BaseButton):
		btn = btn.get_parent()
	if btn == null:
		return false
	if ui.auto_hud.is_ancestor_of(btn) or btn == ui.combat_hud.help_btn:
		return false
	if ui.board_hud.top.is_ancestor_of(btn) or ui.combat_hud.top.is_ancestor_of(btn):
		return false
	for root: Control in [ui.board_hud, ui.combat_hud, ui.draft, ui.passive, ui.rune_assign, ui.shop, ui.forge, ui.event, ui.portal]:
		if root.visible and root.is_ancestor_of(btn):
			return true
	return false
