class_name UiRoot
extends Control
## Convenience host for every UI screen, for the integration layer.
##
##   var ui := UiRoot.new(); canvas_layer.add_child(ui)
##   ui.command.connect(func(name, args): play(flow.callv(name, args)))   # GameFlow commands
##   ui.menu.connect(_on_menu)                                            # navigation intents
##   ui.show_title()
##   ...after every command / event batch: ui.sync(flow); for ev in events: ui.on_event(ev, flow)
##
## The screens stay usable on their own (each has signals + refresh(flow)); UiRoot only wires
## them to two signals and shows the right one for flow.phase. It never calls GameFlow itself.

## A GameFlow command to run: name is the GameFlow method, args its arguments.
## roll_board, board_reroll, confirm_move, combat_reroll, combat_attack, pick_draft[i], rune_assign[die],
## shop_buy[i, die], shop_reroll, shop_leave, forge_apply[die, face, op, src], event_choose[i].
signal command(name: String, args: Array)
## Navigation: new_run, continue, class_chosen(class_id), back_to_title, resume, pause,
## abandon, speed(float).
signal menu(action: String, arg: Variant)

var title: TitleScreen
var class_select: ClassSelect
var board_hud: BoardHud
var combat_hud: CombatHud
var banner: ComboBanner
var draft: DraftModal
var passive: PassiveModal
var inspector: DieInspector
var rune_assign: RuneAssignModal
var shop: ShopModal
var forge: ForgeModal
var event: EventModal
var portal: PortalBanner
var pause: PauseMenu
var settings: SettingsPanel
var summary: SummaryScreen

var _flow: GameFlow
var _modals: Array[UiModal] = []


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_hud = BoardHud.new()
	combat_hud = CombatHud.new()
	portal = PortalBanner.new()
	banner = ComboBanner.new()
	draft = DraftModal.new()
	passive = PassiveModal.new()
	inspector = DieInspector.new()
	rune_assign = RuneAssignModal.new()
	shop = ShopModal.new()
	forge = ForgeModal.new()
	event = EventModal.new()
	summary = SummaryScreen.new()
	title = TitleScreen.new()
	class_select = ClassSelect.new()
	pause = PauseMenu.new()
	settings = SettingsPanel.new()
	for c in [board_hud, combat_hud, portal, banner, draft, passive, rune_assign, shop, forge, event, summary, inspector, title, class_select, pause, settings]:
		add_child(c)
	_modals = [draft, passive, rune_assign, shop, forge, event, summary]
	board_hud.visible = false
	combat_hud.visible = false
	title.visible = false
	class_select.visible = false

	board_hud.roll_pressed.connect(_cmd.bind("roll_board", []))
	board_hud.reroll_pressed.connect(_cmd.bind("board_reroll", []))
	board_hud.go_pressed.connect(_cmd.bind("confirm_move", []))
	board_hud.pause_pressed.connect(open_pause)
	combat_hud.reroll_pressed.connect(_cmd.bind("combat_reroll", []))
	combat_hud.attack_pressed.connect(_cmd.bind("combat_attack", []))
	combat_hud.pause_pressed.connect(open_pause)
	draft.draft_picked.connect(func(i: int) -> void: _cmd("pick_draft", [i]))
	passive.passive_picked.connect(func(i: int) -> void: _cmd("pick_draft", [i]))
	rune_assign.rune_assign.connect(func(d: int) -> void: _cmd("rune_assign", [d]))
	shop.shop_buy.connect(func(i: int, d: int) -> void: _cmd("shop_buy", [i, d]))
	shop.shop_reroll_pressed.connect(_cmd.bind("shop_reroll", []))
	shop.shop_leave_pressed.connect(_cmd.bind("shop_leave", []))
	forge.forge_apply.connect(func(d: int, f: int, op: String, s: int) -> void: _cmd("forge_apply", [d, f, op, s]))
	event.event_chosen.connect(func(i: int) -> void: _cmd("event_choose", [i]))
	title.new_run_pressed.connect(func() -> void: menu.emit("new_run", null))
	title.continue_pressed.connect(func() -> void: menu.emit("continue", null))
	title.settings_pressed.connect(open_settings)
	class_select.class_chosen.connect(func(id: String) -> void: menu.emit("class_chosen", id))
	class_select.back_pressed.connect(func() -> void: menu.emit("back_to_title", null))
	pause.resume_pressed.connect(func() -> void:
		pause.close()
		menu.emit("resume", null))
	pause.settings_pressed.connect(open_settings)
	pause.abandon_confirmed.connect(func() -> void:
		pause.close()
		menu.emit("abandon", null))
	settings.speed_changed.connect(func(s: float) -> void: menu.emit("speed", s))
	summary.new_run_pressed.connect(func() -> void: menu.emit("new_run", null))
	summary.title_pressed.connect(func() -> void: menu.emit("back_to_title", null))


func _cmd(name: String, args: Array) -> void:
	command.emit(name, args)


func show_title() -> void:
	_hide_run()
	class_select.visible = false
	title.visible = true
	title.refresh()


func show_class_select() -> void:
	_hide_run()
	title.visible = false
	class_select.visible = true


func _hide_run() -> void:
	board_hud.visible = false
	combat_hud.visible = false
	portal.visible = false
	if inspector.visible:
		inspector.close()
	for m in _modals:
		if m.visible:
			m.close()


func open_pause() -> void:
	if _flow:
		pause.refresh(_flow)
	pause.open()
	menu.emit("pause", null)


func open_settings() -> void:
	settings.refresh()
	settings.open()


## Opens the die inspector on pool die `idx`.
func inspect_die(flow: GameFlow, idx: int) -> void:
	inspector.show_die(flow, idx)


## A passive was gained: pops it into both HUD passive bars.
func add_passive(_flow: GameFlow, id: String) -> void:
	board_hud.top.add_passive(id)
	combat_hud.top.add_passive(id)


## A passive triggered: flashes its icon in the visible HUD bar.
func flash_passive(id: String) -> void:
	board_hud.top.flash_passive(id)
	combat_hud.top.flash_passive(id)


## Shows the HUD and modal matching flow.phase. Call after every command.
func sync(flow: GameFlow) -> void:
	_flow = flow
	title.visible = false
	class_select.visible = false
	var ph := flow.phase
	var in_combat := ph == GameFlow.Phase.COMBAT
	var over := flow.is_over()
	board_hud.visible = not in_combat and not over
	combat_hud.visible = in_combat
	if board_hud.visible:
		board_hud.refresh(flow)
	if in_combat:
		combat_hud.refresh(flow)
	portal.refresh(flow)
	var want: UiModal = null
	var kind := String(flow.offer.get("kind", ""))
	match ph:
		GameFlow.Phase.DRAFT:
			if kind == "rune_assign":
				want = rune_assign
			elif kind == "passive":
				want = passive
			else:
				want = draft
		GameFlow.Phase.SHOP:
			want = shop
		GameFlow.Phase.FORGE:
			want = forge
		GameFlow.Phase.EVENT:
			want = event
		GameFlow.Phase.GAME_OVER, GameFlow.Phase.VICTORY:
			want = summary
	for m in _modals:
		if m != want and m.visible:
			m.close()
	if want and inspector.visible:
		inspector.close()
	if want:

		want.call("refresh", flow)
		if not want.visible:
			want.open()


## Feeds one gameplay event to the widgets that animate it.
func on_event(ev: Dictionary, flow: GameFlow) -> void:
	match String(ev.get("type", "")):
		"combo":
			banner.on_event(ev)
		"gold_changed":
			if shop.visible:
				shop.on_event(ev)
	if combat_hud.visible:
		combat_hud.on_event(ev, flow)
	elif board_hud.visible:
		board_hud.on_event(ev, flow)
