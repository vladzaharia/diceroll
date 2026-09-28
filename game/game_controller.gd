class_name GameController
extends Node
## Integration hub. Owns the run (GameFlow), the 3D world (BoardView, CameraRig,
## CombatStage), the DiceTray, the UiRoot and a screen overlay, and wires them:
##
##   UI signal / tray tap / 3D tap / key  ->  run_command(name, args)  ->  GameFlow
##   GameFlow events  ->  EventPlayer (sequential, awaited, scaled by game speed)
##   end of playback  ->  _enter_idle(): ui.sync(flow), input unlocked, auto-save
##
## Input is locked while events play and unlocked once the flow awaits a player command.
## Menus: title -> class select -> run -> summary -> title. Pause uses get_tree().paused;
## the UI layer keeps processing (PROCESS_MODE_ALWAYS) so the pause menu works.

## Emitted every time playback ends and the flow waits for the player (phase = flow.phase).
signal idle(phase: int)
## Emitted when a run's events have been played for its end (victory or defeat).
signal run_over(victory: bool)

const SAVE_PATH := "user://save.json"
const LIGHT_EVENTS := ["die_marked", "target_changed"]

var flow: GameFlow
var world: Node3D
var board: BoardView
var rig: CameraRig
var stage: CombatStage
var tray: DiceTray
var ui: UiRoot
var overlay: GameOverlay
var player: EventPlayer

## Presentation speed (1x / 2x from settings; play_auto uses 3x).
var speed := 1.0
## False for scenarios / auto-play so they never touch the player's save.
var autosave := true
## True while events play (input locked).
var busy := false
## "title" | "class" | "run"
var mode := "title"
var in_combat := false

var _tray_layer: CanvasLayer
var _title_t := 0.0
var _last_phase := -1


func _init() -> void:
	name = "GameController"


func _ready() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	board = BoardView.new()
	world.add_child(board)
	rig = CameraRig.new()
	world.add_child(rig)
	stage = CombatStage.new()
	world.add_child(stage)

	_tray_layer = CanvasLayer.new()
	_tray_layer.name = "TrayLayer"
	_tray_layer.layer = 1
	add_child(_tray_layer)
	tray = DiceTray.new()
	tray.name = "DiceTray"
	_tray_layer.add_child(tray)
	tray.die_pressed.connect(_on_die_pressed)

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UiLayer"
	ui_layer.layer = 2
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)
	ui = UiRoot.new()
	ui_layer.add_child(ui)
	ui.command.connect(func(n: String, a: Array) -> void: run_command(n, a))
	ui.menu.connect(_on_menu)

	var ov_layer := CanvasLayer.new()
	ov_layer.name = "OverlayLayer"
	ov_layer.layer = 3
	add_child(ov_layer)
	overlay = GameOverlay.new()
	ov_layer.add_child(overlay)
	overlay.modal_check = any_modal_open

	player = EventPlayer.new(self)
	set_speed(SettingsPanel.game_speed())
	get_viewport().size_changed.connect(_layout_tray)
	_layout_tray()


# --- menus -------------------------------------------------------------------------------

func show_title() -> void:
	mode = "title"
	get_tree().paused = false
	flow = null
	busy = false
	in_combat = false
	stage.clear()
	tray.visible = false
	var rng := Rng.new(int(Time.get_unix_time_from_system()) % 100000 + 7)
	var b := Board.generate(rng, 1)
	board.hero_class = HeroDefs.IDS[randi() % HeroDefs.IDS.size()]
	board.hero_idx = 0
	board.build(1, b.to_dict().tiles)
	board.clear_targets()
	_title_t = 0.0
	_title_camera(true)
	ui.show_title()
	Audio.play_music("title")
	overlay.set_black(false)


func show_class_select() -> void:
	mode = "class"
	tray.visible = false
	ui.show_class_select()


func new_run(class_id: String, seed := -1) -> void:
	if seed < 0:
		seed = int(Time.get_unix_time_from_system()) % 1000000 + randi() % 1000
	start(GameFlow.new_run(class_id, seed))


func continue_run() -> bool:
	var f := load_save()
	if f == null:
		overlay.toast("No saved run", "", UiPalette.DANGER)
		return false
	start(f)
	return true


## Starts presenting `f` (a new or loaded run) from its current state.
func start(f: GameFlow) -> void:
	flow = f
	mode = "run"
	busy = false
	in_combat = false
	_last_phase = -1
	get_tree().paused = false
	stage.clear()
	stage.speed = speed
	board.hero_class = f.run.class_id
	board.hero_idx = f.run.pos
	board.build(f.run.act, f.run.board.to_dict().tiles)
	rig.overview(board.ring_bounds(), true)
	tray.visible = true
	tray.set_dice(f.run.dice)
	if f.phase == GameFlow.Phase.BOARD_ROLLED and not f.board_roll.is_empty():
		tray.set_values(f.board_roll)
		show_roll_targets(f.landing_preview(), f.board_roll)
	if f.phase == GameFlow.Phase.PORTAL:
		player._show_portal(f.offer)
	Audio.play_music("act%d" % f.run.act)
	overlay.set_black(true)
	overlay.fade_in(0.5)
	_enter_idle()


func _on_menu(action: String, arg: Variant) -> void:
	match action:
		"new_run":
			show_class_select()
		"continue":
			continue_run()
		"class_chosen":
			new_run(String(arg))
		"back_to_title":
			show_title()
		"pause":
			get_tree().paused = true
		"resume":
			get_tree().paused = false
		"abandon":
			get_tree().paused = false
			delete_save()
			show_title()
		"speed":
			set_speed(float(arg))


func set_speed(s: float) -> void:
	speed = maxf(s, 0.25)
	tray.speed_scale = speed
	stage.speed = speed
	overlay.speed = speed


func pause() -> void:
	if mode == "run" and flow and not flow.is_over() and not ui.pause.visible:
		ui.open_pause()


# --- commands & playback ---------------------------------------------------------------------

## Runs a GameFlow command and plays its events. Ignored while events play.
func run_command(cmd: String, args: Array = []) -> void:
	if busy or flow == null or mode != "run" or flow.is_over():
		return
	if not flow.has_method(cmd):
		push_warning("GameController: unknown command %s" % cmd)
		return
	var evs: Array = flow.callv(cmd, args)
	if evs.size() == 1 and String(evs[0].get("type", "")) == "error":
		Audio.play_sfx("error")
		overlay.toast(String(evs[0].get("msg", "Not now")).capitalize(), "", UiPalette.HP_BRIGHT, 0.5)
		print("CMD_ERROR %s %s: %s" % [cmd, str(args), String(evs[0].msg)])
		return
	await play_events(evs)


## Plays an event list with input locked, then waits for the player.
func play_events(evs: Array) -> void:
	var light := true
	for ev: Dictionary in evs:
		if not LIGHT_EVENTS.has(String(ev.get("type", ""))):
			light = false
			break
	if light:
		await player.play(evs)
		if flow.phase == GameFlow.Phase.COMBAT:
			ui.combat_hud.refresh(flow)
		idle.emit(flow.phase)
		return
	busy = true
	tray.set_interactive(false)
	ui.board_hud.set_busy(true)
	ui.combat_hud.set_busy(true)
	await player.play(evs)
	if not is_inside_tree():
		return
	busy = false
	_enter_idle()


## Scaled, pause-aware wait.
func wait(t: float) -> void:
	if t <= 0.0:
		return
	await get_tree().create_timer(t / speed, false).timeout


func _enter_idle() -> void:
	if flow == null:
		return
	ui.board_hud.busy = false
	ui.combat_hud.busy = false
	var ph := flow.phase
	if ph != _last_phase:
		_last_phase = ph
	if tray.dice.size() != flow.run.dice.size():
		tray.set_dice(flow.run.dice)
	ui.sync(flow)
	match ph:
		GameFlow.Phase.BOARD_READY:
			board.clear_targets()
			tray.clear_highlight()
			for i in tray.dice.size():
				tray.set_marked(i, false)
				tray.set_locked(i, false)
			if not in_combat:
				rig.overview(board.ring_bounds())
		GameFlow.Phase.BOARD_ROLLED:
			rig.overview(board.ring_bounds())
		GameFlow.Phase.PORTAL:
			rig.overview(board.ring_bounds())
		_:
			pass
	tray.set_interactive(ph == GameFlow.Phase.BOARD_ROLLED or ph == GameFlow.Phase.COMBAT)
	if flow.is_over():
		tray.visible = false
		delete_save()
		run_over.emit(flow.phase == GameFlow.Phase.VICTORY)
	elif ph != GameFlow.Phase.COMBAT:
		save()
	idle.emit(ph)


func any_modal_open() -> bool:
	for m: UiModal in [ui.draft, ui.rune_assign, ui.shop, ui.forge, ui.event, ui.summary]:
		if m.visible and m.is_open():
			return true
	return false


func close_modals() -> void:
	for m: UiModal in [ui.draft, ui.rune_assign, ui.shop, ui.forge, ui.event]:
		if m.visible:
			m.close()


# --- world beats used by the EventPlayer ------------------------------------------------------

func world_parent() -> Node3D:
	return stage if in_combat else board


func hero_pos() -> Vector3:
	return board.hero.global_position if board.hero else Vector3.ZERO


## Screen point above the hero (height in world units).
func hero_screen(height := 2.0) -> Vector2:
	return rig.camera.unproject_position(hero_pos() + Vector3.UP * height)


## Landing markers for a board roll; identical (tile, value) pairs are shown once.
func show_roll_targets(targets: Array, values: Array) -> void:
	var t: Array = []
	var v: Array = []
	var seen := {}
	for k in targets.size():
		var key := "%d:%d" % [int(targets[k]), int(values[k])]
		if seen.has(key):
			continue
		seen[key] = true
		t.append(int(targets[k]))
		v.append(int(values[k]))
	board.show_targets(t, v)


func begin_combat(ev: Dictionary) -> void:
	board.clear_targets()
	var tile := int(ev.get("tile", flow.run.pos))
	if tile < 0:
		tile = flow.run.pos
	var enemies: Array = ev.get("enemies", [])
	if bool(ev.get("boss", false)):
		var nm := String(enemies[0].get("name", "Boss")) if not enemies.is_empty() else "Boss"
		overlay.announce(nm.to_upper(), "BOSS FIGHT", UiPalette.DANGER, 1.3)
		Audio.play_sfx("fanfare")
	elif bool(ev.get("elite", false)):
		overlay.announce("ELITE", "Tougher foes, rune reward", UiPalette.GOLD_BRIGHT, 0.9)
	in_combat = true
	stage.speed = speed
	board.hero.anim_player.speed_scale = speed
	ui.sync(flow)
	ui.combat_hud.set_busy(true)
	await stage.begin_on_board(board, tile, enemies, rig)
	stage.set_target(flow.combat.target if flow.combat else 0)


func end_combat(ev: Dictionary) -> void:
	# swap to the board HUD (bottom bar stays hidden while the rest of the batch plays)
	ui.combat_hud.visible = false
	ui.board_hud.set_busy(true)
	ui.board_hud.visible = true
	ui.board_hud.refresh(flow)
	tray.clear_highlight()
	for i in tray.dice.size():
		tray.set_marked(i, false)
		tray.set_locked(i, false)
	board.hero.play_once("cheer", "idle")
	Audio.play_sfx("win")
	Fx.coin_burst(stage, hero_pos(), 10)
	var parts := PackedStringArray()
	if int(ev.get("gold", 0)) > 0:
		parts.append("+%d gold" % int(ev.gold))
	if int(ev.get("xp", 0)) > 0:
		parts.append("+%d XP" % int(ev.xp))
	overlay.announce("BOSS DEFEATED!" if bool(ev.get("boss", false)) else "VICTORY", "  ·  ".join(parts),
		UiPalette.GOLD_BRIGHT, 0.9)
	await wait(1.3)
	board.hero.anim_player.speed_scale = 1.0
	stage.end_on_board(true)
	in_combat = false
	await wait(0.2)


## Fade to black, rebuild the board for the new act, fade back in with the act title.
func transition_to_act(act: int, tiles: Array) -> void:
	await overlay.fade_out(0.5)
	stage.clear()
	in_combat = false
	board.hero_idx = 0
	board.build(act, tiles)
	rig.overview(board.ring_bounds(), true)
	Audio.play_music("act%d" % act)
	await wait(0.2)
	overlay.fade_in(0.7)
	overlay.announce("ACT %s" % ["I", "II", "III"][clampi(act - 1, 0, 2)], String(SummaryScreen.ACT_NAMES[clampi(act - 1, 0, 2)]),
		UiPalette.GOLD_BRIGHT, 1.3)
	await wait(1.6)


# --- input -----------------------------------------------------------------------------------

func _on_die_pressed(idx: int) -> void:
	if busy or flow == null:
		return
	match flow.phase:
		GameFlow.Phase.BOARD_ROLLED:
			run_command("choose_move", [idx])
		GameFlow.Phase.COMBAT:
			run_command("combat_toggle", [idx])


func _unhandled_input(event: InputEvent) -> void:
	if mode != "run" or flow == null or get_tree().paused:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if busy:
			return
		_tap(mb.position)
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		_key(k.keycode)


func _key(code: int) -> void:
	if code == KEY_ESCAPE or code == KEY_P:
		pause()
		return
	if busy or ui.pause.visible:
		return
	var ph := flow.phase
	if code == KEY_SPACE or code == KEY_ENTER:
		if ph == GameFlow.Phase.BOARD_READY:
			run_command("roll_board")
		elif ph == GameFlow.Phase.COMBAT:
			run_command("combat_attack")
	elif code == KEY_R:
		if ph == GameFlow.Phase.BOARD_ROLLED:
			run_command("board_reroll")
		elif ph == GameFlow.Phase.COMBAT:
			run_command("combat_reroll")
	elif code >= KEY_1 and code <= KEY_6:
		_on_die_pressed(code - KEY_1)


func _tap(pos: Vector2) -> void:
	match flow.phase:
		GameFlow.Phase.BOARD_ROLLED:
			var t := pick_tile(pos)
			if t < 0:
				return
			var targets := flow.landing_preview()
			for i in targets.size():
				if targets[i] == t:
					run_command("choose_move", [i])
					return
		GameFlow.Phase.PORTAL:
			var t := pick_tile(pos)
			if t >= 0 and Array(flow.offer.get("tiles", [])).has(t):
				run_command("portal_pick", [t])
		GameFlow.Phase.COMBAT:
			var e := pick_enemy(pos)
			if e >= 0 and flow.combat and e != flow.combat.target and flow.combat.alive(e):
				run_command("combat_set_target", [e])


## Ring tile under a viewport point (ray vs the tile-top plane), or -1.
func pick_tile(pos: Vector2) -> int:
	var cam := rig.camera
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var best := -1
	var best_d := INF
	# Test the tile-top plane and a plane at figure height (tapping a prop / enemy preview).
	for h: float in [BoardView.TILE_TOP, BoardView.TILE_TOP + 0.6]:
		var y := board.to_global(Vector3(0, h, 0)).y
		if absf(dir.y) < 1e-4:
			continue
		var t := (y - from.y) / dir.y
		if t <= 0.0:
			continue
		var p := board.to_local(from + dir * t)
		for i in BoardView.RING:
			var tp := board.tile_position(i)
			var d := Vector2(p.x - tp.x, p.z - tp.z).length()
			if d < BoardView.PITCH * 0.55 and d < best_d:
				best_d = d
				best = i
		if best >= 0:
			return best
	return best


## Living enemy whose on-screen body is nearest to a viewport point (within reach), or -1.
func pick_enemy(pos: Vector2) -> int:
	var cam := rig.camera
	var best := -1
	var best_d := 90.0
	for i in stage.enemy_count():
		var ch: Character = stage.enemies[i]
		if not ch.visible or int(stage.data[i].get("hp", 0)) <= 0:
			continue
		var feet := ch.global_position
		var s := EnemyLooks.scale_of(String(stage.data[i].get("id", "")))
		var a := cam.unproject_position(feet)
		var b := cam.unproject_position(feet + Vector3.UP * 1.9 * s)
		var d := _seg_dist(pos, a, b)
		if d < best_d:
			best_d = d
			best = i
	return best


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- layout & per-frame ---------------------------------------------------------------------

func _layout_tray() -> void:
	var vs := get_viewport().get_visible_rect().size
	var th := UiTheme.tray_height(vs)
	var portrait := vs.y > vs.x
	var w := vs.x - 24.0 if portrait else minf(vs.x - 48.0, 920.0)
	tray.position = Vector2((vs.x - w) * 0.5, vs.y - th + 4.0)
	tray.size = Vector2(w, th - 16.0)
	_update_combat_rect()


## Keeps the combat framing between the top HUD and the combat panel above the tray.
func _update_combat_rect() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.y <= 0.0 or ui == null:
		return
	var bottom := (ui.combat_hud.content_top(vs) - 14.0) / vs.y
	if vs.y > vs.x:
		var top := 0.12
		rig.combat_rect_portrait = Rect2(0.05, top, 0.9, maxf(bottom - top, 0.3))
	else:
		var top := 0.12
		rig.combat_rect_landscape = Rect2(0.2, top, 0.6, maxf(bottom - top, 0.3))
		# board overview: keep the ring above the ROLL bar (it sits right above the tray)
		var bar_top := (vs.y - UiTheme.tray_height(vs) - 20.0 - 124.0) / vs.y
		rig.safe_rect_landscape = Rect2(0.12, 0.1, 0.76, maxf(bar_top - 0.1, 0.3))


func _process(dt: float) -> void:
	if mode == "title":
		_title_t += dt
		_title_camera(false)


## Slow orbit over the board behind the title screen.
func _title_camera(instant: bool) -> void:
	var b := board.ring_bounds()
	var pts := PackedVector3Array()
	for i in 8:
		pts.append(b.get_endpoint(i))
	rig.frame_points(pts, sin(_title_t * 0.12) * 22.0, 38.0, instant)


# --- save ----------------------------------------------------------------------------------

func save() -> void:
	if not autosave or flow == null or flow.is_over():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameController: cannot write save (%s)" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(flow.to_dict()))
	f.close()


static func load_save() -> GameFlow:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var d: Variant = JSON.parse_string(txt)
	if not (d is Dictionary) or not (d as Dictionary).has("run"):
		push_warning("GameController: save is unreadable, ignoring it")
		return null
	return GameFlow.from_dict(d)


func delete_save() -> void:
	if not autosave:
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
