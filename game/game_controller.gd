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
## Set when the player leaves mid-playback; the EventPlayer stops at the next event.
var aborting := false

var _tray_layer: CanvasLayer
var _title_t := 0.0


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
	get_tree().paused = false
	stage.clear()
	stage.speed = speed
	tray.modulate.a = 1.0
	ui.combat_hud.modulate.a = 1.0
	overlay.vignette(0.0, 0.01)
	board.hero_class = f.run.class_id

	board.hero_idx = f.run.pos
	board.build(f.run.biome(), f.run.board.to_dict().tiles)
	if f.phase == GameFlow.Phase.BOARD_READY:
		rig.home(board.hero, true)
	else:
		rig.overview(board.ring_bounds(), true)
	tray.visible = true
	tray.set_dice(f.run.dice)
	if f.phase == GameFlow.Phase.BOARD_ROLLED and not f.board_roll.is_empty():
		tray.set_values(f.board_roll)
		tray.set_chosen(f.board_choice)
		var t := f.board_target()
		var steps := posmod(t - f.run.pos, f.run.board.size()) if f.board_move > 0 else 0
		show_move_target(t, steps if steps > 0 or f.board_move == 0 else f.run.board.size(), f.is_board_double())
	if f.phase == GameFlow.Phase.PORTAL:
		player._show_portal(f.offer)
	Audio.play_music(f.run.biome())
	overlay.set_black(true)
	overlay.fade_in(0.5)
	if f.phase == GameFlow.Phase.COMBAT and f.combat != null:
		await _restore_combat()
	_enter_idle()


## Re-stages a fight in progress (a run loaded mid-combat): living enemies rise again,
## the dice show their current values, marks and curses.
func _restore_combat() -> void:
	busy = true
	var c := flow.combat
	var tile := c.tile if c.tile >= 0 else flow.run.pos
	in_combat = true
	board.hero.anim_player.speed_scale = speed
	ui.sync(flow)
	ui.combat_hud.set_busy(true)
	await stage.begin_on_board(board, tile, c.enemies, rig)
	for i in c.enemies.size():
		if not c.alive(i):
			stage.enemies[i].visible = false
			stage.huds[i].visible = false
	stage.reframe()
	stage.set_target(c.target)
	tray.set_values(c.dice_values)
	for i in tray.dice.size():
		tray.set_marked(i, i < c.marked.size() and c.marked[i])
		tray.set_locked(i, i < c.locked.size() and c.locked[i])
	busy = false


func _on_menu(action: String, arg: Variant) -> void:
	match action:
		"new_run":
			show_class_select()
		"continue":
			continue_run()
		"class_chosen":
			new_run(String(arg))
		"back_to_title":
			leave_to_title()
		"pause":
			get_tree().paused = true
		"resume":
			get_tree().paused = false
		"abandon":
			get_tree().paused = false
			delete_save()
			leave_to_title()
		"speed":
			set_speed(float(arg))


## Returns to the title. If events are still playing, playback stops at the next event
## boundary (so no beat resumes on a cleared stage) and the title follows.
func leave_to_title() -> void:
	if busy:
		aborting = true
		overlay.fade_out(0.2)
		return
	show_title()


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
	if aborting:
		aborting = false
		show_title()
		return
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
	if tray.dice.size() != flow.run.dice.size():
		tray.set_dice(flow.run.dice)
	ui.sync(flow)
	match ph:
		GameFlow.Phase.BOARD_READY:
			board.clear_targets()
			tray.clear_highlight()
			tray.clear_chosen()
			for i in tray.dice.size():
				tray.set_marked(i, false)
				tray.set_locked(i, false)
			if not in_combat:
				rig.home(board.hero)
				clear_view()
		GameFlow.Phase.BOARD_ROLLED:
			board.restore_occluders()
			rig.overview(board.ring_bounds())
		GameFlow.Phase.PORTAL:
			rig.overview(board.ring_bounds())
		_:
			pass
	# Board phases: tapping a tray die opens the die inspector; combat: marks it for a reroll.
	tray.set_interactive(ph in [GameFlow.Phase.BOARD_READY, GameFlow.Phase.BOARD_ROLLED, GameFlow.Phase.COMBAT])
	if flow.is_over():
		tray.visible = false
		delete_save()
		run_over.emit(flow.phase == GameFlow.Phase.VICTORY)
	elif ph != GameFlow.Phase.COMBAT:
		save()
	idle.emit(ph)


func any_modal_open() -> bool:
	for m: UiModal in [ui.draft, ui.passive, ui.rune_assign, ui.shop, ui.forge, ui.event, ui.summary, ui.inspector]:
		if m.visible and m.is_open():
			return true
	return false


func close_modals() -> void:
	for m: UiModal in [ui.draft, ui.passive, ui.rune_assign, ui.shop, ui.forge, ui.event]:
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


## Sinks set pieces / dressing that would hide the hero from the camera's current target
## framing (close follow / home views on the far side of the island). Undone by the next
## overview (board.restore_occluders()).
func clear_view() -> void:
	if in_combat or board.hero == null:
		return
	board.restore_occluders()
	var vs := get_viewport().get_visible_rect().size
	board.hide_occluders(rig.desired_transform(), rig.camera.fov, vs.x / maxf(vs.y, 1.0), [board.hero.global_position])


## The single landing marker for the current board move (tile + move size).
func show_move_target(target: int, move: int, double := false) -> void:
	board.show_move_target(target, move, double)


func begin_combat(ev: Dictionary) -> void:
	board.clear_targets()
	var tile := int(ev.get("tile", flow.run.pos))
	if tile < 0:
		tile = flow.run.pos
	var enemies: Array = ev.get("enemies", [])
	var boss := bool(ev.get("boss", false))
	var mini := bool(ev.get("miniboss", false))
	in_combat = true
	stage.speed = speed
	board.hero.anim_player.speed_scale = speed
	ui.sync(flow)
	ui.combat_hud.set_busy(true)
	if boss:
		await _boss_intro(tile, enemies)
		return
	if mini:
		var nm := String(enemies[0].get("name", "Mini-boss")) if not enemies.is_empty() else "Mini-boss"
		overlay.announce(nm.to_upper(), "MINI-BOSS  ·  Boss-tier reward", Color("ff9a3a"), 1.1)
		Audio.play_sfx("fanfare")
		rig.shake(0.5, 0.4)
	elif bool(ev.get("elite", false)):
		overlay.announce("ELITE", "Tougher foes, passive reward", UiPalette.GOLD_BRIGHT, 0.9)
	await stage.begin_on_board(board, tile, enemies, rig)
	stage.set_target(flow.combat.target if flow.combat else 0)


## Final boss entrance: the screen darkens, the Lich rises in a storm of light, then a
## name card slams in. The camera starts close on the boss and eases to combat framing.
func _boss_intro(tile: int, enemies: Array) -> void:
	var nm := String(enemies[0].get("name", "Boss")) if not enemies.is_empty() else "Boss"
	Audio.play_music("calm", 0.6)
	overlay.vignette(0.85, 0.6)
	# cinematic: no HUD bottom bar or tray while the boss rises
	ui.combat_hud.visible = false
	var tt := tray.create_tween()
	tt.tween_property(tray, "modulate:a", 0.0, 0.3 / speed)
	await wait(0.4)
	var begun := [false]
	stage.began.connect(func() -> void: begun[0] = true, CONNECT_ONE_SHOT)
	stage.begin_on_board(board, tile, enemies, rig)
	# frame the boss's rise tight, from low, then settle into the fight framing
	var bp := stage.enemy_position(0)
	var pts := PackedVector3Array([bp + Vector3(-1.4, 0, -1.4), bp + Vector3(1.4, 0, 1.4), bp + Vector3.UP * 4.2])
	rig.frame_points(pts, rad_to_deg(rig.combat_yaw()), 14.0, true)
	Fx.flash(self, Color(0.75, 0.55, 1.0, 0.5), 0.5)
	rig.shake(0.8, 1.2)
	Audio.play_sfx("portal")
	await wait(0.9)
	Audio.play_sfx("fanfare")
	overlay.boss_card(nm.to_upper(), "Lord of the Bone Throne" if nm == "The Lich" else "Final boss", UiPalette.DANGER)
	rig.shake(0.9, 0.5)
	await wait(1.6)
	while not begun[0] and is_inside_tree():
		await get_tree().process_frame
	stage.reframe()
	overlay.vignette(0.0, 0.8)
	Audio.play_music(flow.run.biome(), 1.2)
	ui.combat_hud.visible = true
	ui.combat_hud.modulate.a = 0.0
	var ht := ui.combat_hud.create_tween()
	ht.tween_property(ui.combat_hud, "modulate:a", 1.0, 0.4 / speed)
	var tt2 := tray.create_tween()
	tt2.tween_property(tray, "modulate:a", 1.0, 0.4 / speed)

	stage.set_target(flow.combat.target if flow.combat else 0)
	await wait(0.3)


func end_combat(ev: Dictionary) -> void:
	# swap to the board HUD (bottom bar stays hidden while the rest of the batch plays); its
	# top bar takes over the combat HUD's numbers so rewards animate from there
	ui.combat_hud.visible = false
	ui.board_hud.set_busy(true)
	ui.board_hud.visible = true
	ui.board_hud.top.copy_from(ui.combat_hud.top)
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
	var title := "VICTORY"
	if bool(ev.get("boss", false)):
		title = "BOSS DEFEATED!"
	elif bool(ev.get("miniboss", false)):
		title = "MINI-BOSS SLAIN!"
	overlay.announce(title, "  ·  ".join(parts), UiPalette.GOLD_BRIGHT, 0.9)
	await wait(1.3)
	board.hero.anim_player.speed_scale = 1.0
	stage.end_on_board(false)
	in_combat = false
	await wait(0.2)


## Biome change (laps 6 and 11): the old board sinks tile by tile, a swirling dissolve
## covers the screen in the new biome's colours, the island is rebuilt around the hero
## (who keeps their tile), the new tiles rise in a wave from the hero and the new music
## and title come in.
func change_biome(ev: Dictionary) -> void:
	var act := int(ev.get("act", flow.run.act))
	var lap := int(ev.get("lap", flow.run.lap))
	var pos := int(ev.get("pos", flow.run.pos))
	var bid := String(ev.get("biome", flow.run.biome()))
	var tiles: Array = ev.board.tiles
	stage.clear()
	in_combat = false
	rig.overview(board.ring_bounds())
	await wait(0.25)
	await board.sink_wave(pos, 0.9 / speed)
	var look := Biome.look(bid)
	Audio.play_sfx("portal")
	var vs := get_viewport().get_visible_rect().size
	var centre := hero_screen(0.8) / Vector2(maxf(vs.x, 1.0), maxf(vs.y, 1.0))
	await overlay.dissolve(true, Color(look.sky_top).lerp(Color(look.sky_glow), 0.25), Color(look.sky_glow), 0.7, centre)
	board.hero_idx = pos
	board.build(bid, tiles)
	board.hide_tiles()
	rig.overview(board.ring_bounds(), true)
	Audio.play_music(bid, 1.2)
	await wait(0.15)
	centre = hero_screen(0.8) / Vector2(maxf(vs.x, 1.0), maxf(vs.y, 1.0))
	overlay.dissolve(false, Color(look.sky_top), Color(look.sky_glow), 0.9, centre)

	await wait(0.25)
	board.rise_wave(pos, 1.1 / speed)
	var name := String(ev.get("biome_name", BiomeDefs.name_of(bid)))
	var tier: String = ["I", "II", "III"][clampi(act - 1, 0, 2)]
	overlay.biome_card(bid, name, "Tier %s  ·  Lap %d of %d" % [tier, lap, Balance.TOTAL_LAPS],
		String(ev.get("biome_desc", BiomeDefs.desc_of(bid))), 2.2)
	Audio.play_sfx("fanfare")
	await wait(2.6)


# --- input -----------------------------------------------------------------------------------

func _on_die_pressed(idx: int) -> void:
	if busy or flow == null or any_modal_open():
		return
	match flow.phase:
		GameFlow.Phase.BOARD_READY, GameFlow.Phase.BOARD_ROLLED:
			inspect_die(idx)
		GameFlow.Phase.COMBAT:
			run_command("combat_toggle", [idx])


## Opens the die inspector (six faces, kind, rune) for pool die `idx`.
func inspect_die(idx: int) -> void:
	if flow == null or idx < 0 or idx >= flow.run.dice.size():
		return
	ui.inspect_die(flow, idx)


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
	if busy or ui.pause.visible or any_modal_open():
		return
	var ph := flow.phase
	if code == KEY_SPACE or code == KEY_ENTER:
		if ph == GameFlow.Phase.BOARD_READY:
			run_command("roll_board")
		elif ph == GameFlow.Phase.BOARD_ROLLED:
			run_command("confirm_move")
		elif ph == GameFlow.Phase.COMBAT:
			run_command("combat_attack")
	elif code == KEY_R:
		if ph == GameFlow.Phase.BOARD_ROLLED:
			run_command("board_reroll")
		elif ph == GameFlow.Phase.COMBAT:
			run_command("combat_reroll")
	elif code >= KEY_1 and code <= KEY_6 and ph == GameFlow.Phase.COMBAT:
		# combat only: mark / unmark die N for a reroll (the board move is automatic)
		run_command("combat_toggle", [code - KEY_1])


func _tap(pos: Vector2) -> void:
	match flow.phase:
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
		for i in board.ring_size:
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
	var w := UiTheme.tray_width(vs)
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
		# the bottom controls sit beside the tray: the world gets everything above it
		var top := 0.1
		rig.combat_rect_landscape = Rect2(0.1, top, 0.8, maxf(bottom - top, 0.3))
		var bar_top := (ui.board_hud.content_top(vs) - 6.0) / vs.y
		rig.safe_rect_landscape = Rect2(0.12, 0.09, 0.76, maxf(bar_top - 0.09, 0.3))



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
