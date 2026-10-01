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
## Menus: title -> CAMP (the meta hub, 3D CampScene + CampScreen) -> run setup -> route card ->
## run -> RESULTS (the run is banked into the profile) -> Camp. Pause uses get_tree().paused;
## the UI layer keeps processing (PROCESS_MODE_ALWAYS) so the pause menu works.
##
## Profile: user://profile.json (ProfileStore), loaded on first use and created fresh on first
## launch; saved after every Camp command and after banking a run. Every run from the UI starts
## with GameFlow.new_run(class, seed, board, {profile, mode, ascension}); a loaded run save
## carries its own meta config (run.meta).

## Emitted every time playback ends and the flow waits for the player (phase = flow.phase).
signal idle(phase: int)
## Emitted when a run's events have been played for its end (victory or defeat).
signal run_over(victory: bool)
## Emitted when the player (not AUTO) issues a command: AUTO turns itself off.
signal manual_command(cmd: String)

const SAVE_PATH := "user://save.json"
const LIGHT_EVENTS := ["die_marked", "target_changed"]
## Screen-height fraction of Camp toasts (see _camp_toast).
const CAMP_TOAST_Y := 0.84

var flow: GameFlow
var world: Node3D
var board: BoardView
var rig: CameraRig
var stage: CombatStage
var tray: DiceTray
var ui: UiRoot
var overlay: GameOverlay
var player: EventPlayer
## AUTO (game/auto/auto_pilot.gd): plays Bot.decide steps while enabled.
var auto: AutoPilot
## The run's pet familiar in the world (game/pets/pet_host.gd).
var pets: PetHost
## Set by AutoPilot around its own run_command call (anything else counts as manual).
var from_auto := false

## Presentation speed (1x / 2x from settings; play_auto uses 3x).
var speed := 1.0
## False for scenarios / auto-play so they never touch the player's save.
var autosave := true
## True while events play (input locked).
var busy := false
## "title" | "class" | "camp" | "run"
var mode := "title"
var in_combat := false
## Set when the player leaves mid-playback; the EventPlayer stops at the next event.
var aborting := false

var _tray_layer: CanvasLayer
var _title_t := 0.0

## Meta profile (loaded by ensure_profile()) and the Camp command layer over it.
var profile: Profile
var camp: Camp
## Where the profile lives; false = never write it (scenarios).
var profile_path := ProfileStore.PATH
var persist_profile := true
## True when this launch created the profile (the Camp shows its welcome once).
var profile_is_new := false
## Plays minigame tiles on AUTO while no minigame screen exists (off for scripted drivers).
var minigame_fallback := true
## The 3D camp while in the hub (null otherwise).
var camp_scene: CampScene
## game_over stats of the run being presented, and whether they were banked.
var _game_over_stats: Dictionary = {}
var _banked := false
## CampState before the last banked run: the next show_camp() plays the build-out reveal.
var camp_before: Dictionary = {}


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
	overlay.framed_rect = func() -> Rect2:
		return tray.get_global_rect() if is_instance_valid(tray) and tray.is_visible_in_tree() else Rect2()

	player = EventPlayer.new(self)
	pets = PetHost.new(self)
	add_child(pets)
	auto = AutoPilot.new(self)
	add_child(auto)
	set_speed(SettingsPanel.game_speed())
	get_viewport().size_changed.connect(_layout_tray)
	_layout_tray()


# --- menus -------------------------------------------------------------------------------

func show_title() -> void:
	_leave_camp_world()
	mode = "title"
	auto.set_enabled(false)
	get_tree().paused = false
	flow = null
	busy = false
	in_combat = false
	stage.clear()
	tray.visible = false
	var rng := Rng.new(int(Time.get_unix_time_from_system()) % 100000 + 7)
	var b := Board.generate(rng, 1)
	# never the secret class on the title (it would spoil the Monster Kid)
	var shown := HeroDefs.IDS.filter(func(id: String) -> bool: return not bool(HeroDefs.DATA[id].get("secret", false)))
	board.hero_class = String(shown[randi() % shown.size()])
	board.hero_skin = "default"
	board.hero_prestige = false
	board.hero_look = {}
	board.hero_idx = 0
	board.variant_seed = randi()
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
	ui.class_select.set_profile(profile)
	ui.show_class_select()


func new_run(class_id := "", seed := -1) -> void:
	if seed < 0:
		seed = int(Time.get_unix_time_from_system()) % 1000000 + randi() % 1000
	start(GameFlow.new_run(class_id if class_id != "" else String(ensure_profile().loadout.get("class", "knight")), seed,
		Balance.BOARD_SIZE, run_opts()))
	# a new road every run: show it before the first roll
	busy = true
	await wait(0.45)
	await ui.show_route(flow)
	busy = false


func continue_run() -> bool:
	var f := load_save()
	if f == null:
		overlay.toast("No saved run", "", UiPalette.DANGER)
		return false
	start(f)
	return true


## Starts presenting `f` (a new or loaded run) from its current state.
func start(f: GameFlow) -> void:
	_leave_camp_world()
	flow = f
	mode = "run"
	_game_over_stats = {}
	_banked = false
	auto.set_enabled(false)
	busy = false
	in_combat = false
	get_tree().paused = false
	stage.clear()
	stage.speed = speed
	tray.modulate.a = 1.0
	ui.combat_hud.modulate.a = 1.0
	overlay.vignette(0.0, 0.01)
	board.hero_class = f.run.class_id
	board.hero_skin = f.run.skin
	board.hero_prestige = f.run.skin_prestige
	board.hero_look = ArmoryLook.of_meta(f.run.meta, f.run.class_id, f.run.skin, f.run.skin_prestige)
	# the item callouts show each item's 3D picture: render them ahead
	var pics: Array = []
	var its: Dictionary = f.run.meta.get("items", {})
	for slot in its:
		pics.append(ArmoryLook.shown_id(f.run.class_id, String(its[slot].id), String(its[slot].get("variant", ""))))
	ItemThumb.prewarm(pics)

	board.hero_idx = f.run.pos
	EnemyLooks.run_seed = f.run.seed  # per-run enemy variants
	board.variant_seed = hash([f.run.seed, f.run.biome()])
	board.moon_phase = f.run.moon_phase()
	board.build(f.run.biome(), f.run.board.to_dict().tiles)
	if f.phase == GameFlow.Phase.BOARD_READY:
		rig.home(board.hero, true)
	else:
		rig.overview(board.ring_bounds(), true)
	tray.visible = true
	tray.set_badge("")
	ClassBeats.sync_tray(self)
	if f.phase == GameFlow.Phase.BOARD_ROLLED and not f.board_roll.is_empty():
		tray.set_values(f.board_roll)
		tray.set_chosen(f.board_choice)
		var t := f.board_target()
		var steps := posmod(t - f.run.pos, f.run.board.size()) if f.board_move > 0 else 0
		show_move_target(t, steps if steps > 0 or f.board_move == 0 else f.run.board.size(), f.is_board_double())
	if f.phase == GameFlow.Phase.PORTAL:
		player._show_portal(f.offer)
	var boss_fight := f.phase == GameFlow.Phase.COMBAT and f.combat != null and f.combat.boss
	Audio.play_music("boss" if boss_fight else f.run.biome())
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
		"new_run", "camp":
			show_camp()
		"camp_cmd":
			camp_command(arg)
		"start_run":
			start_from_camp()
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
			abandon_to_camp()
		"speed":
			set_speed(float(arg))
		"auto":
			auto.set_enabled(bool(arg))
		"auto_rules":
			auto.set_rules(arg)


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
	# 4x also condenses beats: a quicker tray throw, shorter overlay holds (see wait())
	tray.speed_scale = speed * (1.3 if condensed() else 1.0)
	stage.speed = speed
	overlay.speed = speed * (1.35 if condensed() else 1.0)
	ui.auto_hud.set_speed(speed)


## True at 4x: repeated beats merge, long holds shorten, short hops keep the camera still.
func condensed() -> bool:
	return speed >= 3.9


func pause() -> void:
	if mode == "run" and flow and not flow.is_over() and not ui.pause.visible:
		ui.open_pause()


# --- commands & playback ---------------------------------------------------------------------

## Runs a GameFlow command and plays its events. Ignored while events play.
func run_command(cmd: String, args: Array = []) -> void:
	var manual := not from_auto
	from_auto = false
	if busy or flow == null or mode != "run" or flow.is_over():
		return
	if manual:
		manual_command.emit(cmd)
	if not flow.has_method(cmd):
		push_warning("GameController: unknown command %s" % cmd)
		return
	var evs: Array = flow.callv(cmd, args)
	if evs.size() == 1 and String(evs[0].get("type", "")) == "error":
		Audio.play_sfx("error")
		overlay.toast(String(evs[0].get("msg", "Not now")).capitalize(), "", UiPalette.HP_BRIGHT)
		print("CMD_ERROR %s %s: %s" % [cmd, str(args), String(evs[0].msg)])
		return
	await play_events(evs)


## Plays an event list with input locked, then waits for the player.
func play_events(evs: Array) -> void:
	_note_game_over(evs)
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
	if condensed() and t > 0.6:
		t = 0.6 + (t - 0.6) * 0.5
	await get_tree().create_timer(t / speed, false).timeout


func _enter_idle() -> void:
	if flow == null:
		return
	if flow.is_over():
		bank_run()
	ui.board_hud.busy = false
	ui.combat_hud.busy = false
	var ph := flow.phase
	if tray.dice.size() != ClassBeats.pool(flow).size():
		ClassBeats.sync_tray(self)
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
	_minigame_fallback(ph)
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
	Audio.play_music("boss", 1.2)
	ui.combat_hud.visible = true
	ui.combat_hud.modulate.a = 0.0
	var ht := ui.combat_hud.create_tween()
	ht.tween_property(ui.combat_hud, "modulate:a", 1.0, 0.4 / speed)
	var tt2 := tray.create_tween()
	tt2.tween_property(tray, "modulate:a", 1.0, 0.4 / speed)

	stage.set_target(flow.combat.target if flow.combat else 0)
	await wait(0.3)


func end_combat(ev: Dictionary) -> void:
	tray.set_badge("")
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
		if flow:
			Audio.play_music(flow.run.biome(), 1.5)
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
	board.variant_seed = hash([flow.run.seed, bid])
	board.moon_phase = flow.run.moon_phase()
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
	if mode == "camp":
		_camp_input(event)
		return
	if mode != "run" or flow == null or get_tree().paused:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if busy:
			return
		_tap(mb.position)
		return
	if event is InputEventKey:
		_key(event)


## Run shortcuts, routed through the InputMap actions of ui/input/input_actions.gd
## (pause = Esc / P, primary = Space / Enter, reroll = R, die_1..die_6 = 1-6).
func _key(event: InputEvent) -> void:
	if InputActions.pressed(event, InputActions.PAUSE):
		pause()
		return
	if busy or ui.pause.visible or any_modal_open():
		return
	var ph := flow.phase
	if InputActions.pressed(event, InputActions.PRIMARY):
		if ph == GameFlow.Phase.BOARD_READY:
			run_command("roll_board")
		elif ph == GameFlow.Phase.BOARD_ROLLED:
			run_command("confirm_move")
		elif ph == GameFlow.Phase.COMBAT:
			run_command("combat_attack")
	elif InputActions.pressed(event, InputActions.REROLL):
		if ph == GameFlow.Phase.BOARD_ROLLED:
			run_command("board_reroll")
		elif ph == GameFlow.Phase.COMBAT:
			run_command("combat_reroll")
	elif ph == GameFlow.Phase.COMBAT:
		# combat only: mark / unmark die N for a reroll (the board move is automatic)
		var n := InputActions.pressed_index(event, InputActions.DIE)
		if n >= 0:
			run_command("combat_toggle", [n])


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
	var r := UiTheme.tray_rect(vs, UiTheme.safe_margins(tray))
	tray.position = r.position
	tray.size = r.size
	_update_combat_rect()


## The camera frames the board / fight in the space the HUD leaves, measured live.
func _update_combat_rect() -> void:
	if ui == null or rig.insets_source.is_valid():
		return
	rig.insets_source = func() -> Dictionary:
		return ScreenInsets.measure(ui, get_viewport().get_visible_rect().size)


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


# --- camp & profile (meta layer) ---------------------------------------------------------------

## The profile, loaded (or created fresh on first launch) on first use.
func ensure_profile() -> Profile:
	if profile == null:
		profile = ProfileStore.load_profile(profile_path) if persist_profile else null
		if profile == null:
			profile = Profile.fresh()
			profile_is_new = true
			save_profile()
	if camp == null or camp.profile != profile:
		camp = Camp.new(profile)
	return profile


func save_profile() -> void:
	if persist_profile and profile != null:
		ProfileStore.save(profile, profile_path)


## new_run opts from the profile: the meta layer, the chosen mode and ascension.
func run_opts() -> Dictionary:
	var p := ensure_profile()
	return {"profile": p.to_dict(), "mode": String(p.loadout.get("mode", "standard")),
		"ascension": int(p.ascension.get("selected", 0))}


## The Camp hub: the 3D camp, the Crowns / Sigils header and the station screens.
func show_camp() -> void:
	ensure_profile()
	mode = "camp"
	auto.set_enabled(false)
	get_tree().paused = false
	flow = null
	busy = false
	aborting = false
	in_combat = false
	stage.clear()
	tray.visible = false
	_enter_camp_world()
	ui.show_camp(profile, TitleScreen.has_save())
	Audio.play_music("calm")
	overlay.set_black(true)
	overlay.fade_in(0.5)
	await _camp_reveal()
	if profile_is_new:
		profile_is_new = false
		await wait(0.6)
		if mode == "camp":
			ui.camp.show_welcome()


## A Camp toast: low on the screen, so it never lands on the station heading or the row the
## player just tapped (the rank-up toast sat on the Ranks heading at mid-screen).
func _camp_toast(text: String, icon := "", color: Color = UiPalette.TEXT) -> void:
	# on the Camp screen itself: above its bottom panel and over its station screens
	if ui and ui.camp and ui.camp.visible and ui.camp.is_inside_tree():
		ui.camp.toast(text, icon, color)
		return
	overlay.toast(text, icon, color, CAMP_TOAST_Y)


## Applies a Camp command (Camp.apply format), saves the profile and refreshes the hub.
func camp_command(cmd: Array) -> void:
	ensure_profile()
	var evs := camp.apply(cmd)
	if evs.size() == 1 and String(evs[0].get("type", "")) == "error":
		Audio.play_sfx("error")
		_camp_toast(String(evs[0].get("msg", "Not now")).capitalize(), "", UiPalette.HP_BRIGHT)
		return
	save_profile()
	for e: Dictionary in evs:
		match String(e.get("type", "")):
			"upgrade_bought":
				Audio.play_sfx("levelup")
				_camp_toast(_upgrade_text(e), "rank", UiPalette.HEAL)
			"unlocked":
				Audio.play_sfx("fanfare")
				_camp_toast("Unlocked: %s" % CampInfo.name_of(String(e.kind), String(e.id)),
					CampInfo.glyph_of(String(e.kind), String(e.id)), UiPalette.GOLD_BRIGHT)
			"pool_toggled", "starter_kind_set", "ascension_changed", "loadout_changed":
				Audio.play_sfx("dice_select")
			"item_unlocked":
				Audio.play_sfx("fanfare")
				_camp_toast("New item: %s" % ItemDefs.name_of(String(e.id)), CampInfo.item_icon(String(e.id)), UiPalette.GOLD_BRIGHT)
			"variant_crafted":
				Audio.play_sfx("levelup")
				_camp_toast("Crafted: %s" % ItemDefs.name_of(String(e.variant)), "craft", UiPalette.GOLD_BRIGHT)
			"item_equipped":
				Audio.play_sfx("buff")
			"appearance_set":
				Audio.play_sfx("dice_select")
			"skin_equipped", "prestige_set":
				Audio.play_sfx("buff")
			"skin_unlocked":
				Audio.play_sfx("fanfare")
				_camp_toast("New skin: %s, %s" % [CampInfo.name_of("classes", String(e["class"])), String(SkinDefs.NAMES.get(String(e.skin), e.skin))],
					"wardrobe_hats", Color("c79bff"))
	if camp_scene:
		camp_scene.apply_profile(profile)
	ui.camp.show_profile(profile, TitleScreen.has_save())


func _upgrade_text(e: Dictionary) -> String:
	var id := String(e.id)
	match String(e.track):
		"armory":
			if ItemDefs.GROUPS.has(id):
				var t := ItemDefs.rank_tier(int(e.level))
				var up := t > ItemDefs.rank_tier(int(e.level) - 1)
				return "%s %d" % [CampInfo.name_of("gear", id), int(e.level)] + ("  ·  Tier %s!" % ["", "I", "II", "III"][t] if up else "")
			if id == "pouch":
				return "Belt Pouch bought: a 2nd trinket slot!"
			return CampInfo.name_of("features", id) + " bought!"
		"pet_den":
			return "%s  Level %d" % [PetDefs.name_of(id), int(e.level)]
	return String(UnlockDefs.upgrade_def(String(e.track), id).get("name", id)) + " bought!"


## START from the run setup: a new run with the profile's loadout (replaces any run save).
func start_from_camp() -> void:
	ensure_profile()
	delete_save()
	await new_run(String(profile.loadout.get("class", "knight")))


## Leaves a run from the pause menu: it is banked as a loss (a loss always pays, so quitting
## never pays more than playing on), then the results screen shows.
func abandon_to_camp() -> void:
	if flow == null or flow.is_over() or mode != "run":
		leave_to_title()
		return
	if busy:
		aborting = true
		overlay.fade_out(0.2)
		return
	var ev: Array[Dictionary] = []
	flow._finish(false, ev)
	await play_events(ev)


## Banks the finished run into the profile once (Camp.bank_run) and hands the results screen
## what it needs. With persist_profile off (scenarios) it banks into the in-memory profile only.
func bank_run() -> void:
	if _banked or flow == null or not flow.is_over():
		return
	_banked = true
	ensure_profile()
	var stats := _game_over_stats if not _game_over_stats.is_empty() else flow._summary()
	var before := profile.to_dict()
	camp_before = CampState.of(profile)
	var evs := camp.bank_run(stats)
	save_profile()
	ui.summary.results = {"stats": stats, "events": evs, "before": before, "after": profile}
	var last: Dictionary = evs.back()
	print("RUN_BANKED victory=%s crowns=%d sigils=%d total_crowns=%d total_sigils=%d runs=%d unlocked=%s" % [
		str(bool(stats.get("victory", false))), int(last.get("crowns", 0)), int(last.get("sigils", 0)), profile.crowns,
		profile.sigils, int(profile.records.get("runs", 0)), str(last.get("unlocked", []))])


func _note_game_over(evs: Array) -> void:
	for ev: Dictionary in evs:
		if String(ev.get("type", "")) == "game_over":
			_game_over_stats = (ev.get("stats", {}) as Dictionary).duplicate(true)


## Until the minigame screens exist (WP-E2 adds UiRoot.minigame), a minigame tile is played
## on AUTO (par result) so a manual run never stalls in the MINIGAME phase.
func _minigame_fallback(ph: int) -> void:
	if not minigame_fallback or ph != GameFlow.Phase.MINIGAME or auto.enabled or ui.get("minigame") != null:
		return
	overlay.toast("%s: played on AUTO" % String(flow.offer.get("name", "Minigame")), "star", UiPalette.GOLD_BRIGHT)
	run_command.call_deferred("minigame_auto")


func _enter_camp_world() -> void:
	if board.get_parent() == world:
		world.remove_child(board)
	if camp_scene == null:
		camp_scene = CampScene.new()
		world.add_child(camp_scene)
	camp_scene.apply_profile(profile)
	camp_scene.camera().make_current()
	ui.camp.scene = camp_scene


func _leave_camp_world() -> void:
	if camp_scene != null:
		ui.camp.scene = null
		camp_scene.queue_free()
		camp_scene = null
	if board.get_parent() == null:
		world.add_child(board)
		world.move_child(board, 0)
	rig.camera.make_current()


## The build-out moments for what the last run unlocked (camera pans, the camp grows).
## Tapping skips; game speed (2x / 4x) speeds it up.
func _camp_reveal() -> void:
	if camp_before.is_empty() or camp_scene == null:
		return
	var before := camp_before
	camp_before = {}
	if CampState.diff(before, CampState.of(profile)).is_empty():
		return
	ui.camp.set_revealing(true)
	await camp_scene.reveal(before, CampState.of(profile), overlay, speed)
	if is_inside_tree() and mode == "camp":
		ui.camp.set_revealing(false)


func _camp_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_camp_key(event)
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or camp_scene == null:
		return
	if camp_scene.revealing:
		camp_scene.skip_reveal()
		return
	if get_tree().paused or ui.camp.any_open():
		return
	var id := camp_scene.pick_station(mb.position)
	if id != "":
		ui.camp.open_station(id)


## Camp keys (no station or modal open): Enter = START RUN (opens run setup), Esc = home
## (back to the title). Open stations and modals handle their own Enter / Esc (UiModal).
func _camp_key(event: InputEvent) -> void:
	if camp_scene == null or get_tree().paused or ui.camp.any_open():
		return
	if camp_scene.revealing:
		if InputActions.pressed(event, InputActions.CONFIRM) or InputActions.pressed(event, InputActions.BACK):
			camp_scene.skip_reveal()
			get_viewport().set_input_as_handled()
		return
	if InputActions.pressed(event, InputActions.CONFIRM) and ui.camp.start_btn.is_visible_in_tree() \
			and not ui.camp.start_btn.disabled:
		get_viewport().set_input_as_handled()
		ui.camp.start_btn.pressed.emit()
	elif InputActions.pressed(event, InputActions.BACK) and ui.camp.home_btn.is_visible_in_tree():
		get_viewport().set_input_as_handled()
		ui.camp.home_btn.pressed.emit()

