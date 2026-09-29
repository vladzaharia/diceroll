class_name MinigameScenarios
extends RefCounted
## Minigame scenarios for the screenshot harness (tools/shot.gd, registered in
## tools/scenarios.gd PROVIDERS):
##
##  mg_fossil / mg_bubble / mg_scratch / mg_claw and mg_<id> for the Minigames 2.0 games
##  (mg_bubble_shooter, mg_plinko, mg_shell_game, mg_memory_match, mg_fishing, mg_lucky_wheel,
##  mg_high_low; their input goes through MgBoard.scripted_input)   the game screen over the dimmed board
##      --state=fresh   (default) just opened, after the landing beat and intro
##      --state=mid     a few actions played through real taps (injected mouse events)
##      --state=result  played to the end: the results beat held on screen
##      --state=reward  the reward modal after the results beat
##      --state=play    the whole flow by injected input: taps / scratch drags / a timed claw
##                      drop -> results -> tap the reward card + TAKE -> back on the board.
##                      Saves <shot>_step_NN.png per step, prints MG_PLAY_OK / MG_PLAY_FAIL
##                      and quits (exit 0 / 1).
##      --state=resume  two actions, then the run is JSON round-tripped and presented again
##                      (Continue mid-minigame); prints MG_RESUME
##      --aim=cluster   (claw) drop where the most capsules are in reach (multi-scoop shots)
##      --rig=three     (scratch) scratch three alike (harness peek, for the jackpot shots)
##      --auto=1        (fresh) press the screen's AUTO button (par result)
##      --state=anim    --actions=N actions after --delay=S seconds (frame sequences: pair it
##                      with --wait and --frames)
##  tile_minigames  a board with all four minigame tiles next to the hero (--close=1: close-up;
##                  --set=new: the seven Minigames 2.0 tiles; --game=<id>: that one tile)
##  mg_play_auto    a run with all four minigames equipped (opts.meta from the max profile,
##                  loadout = every minigame), played by AUTO through the real toggle
##                  (AutoPilot + Bot.decide); shots whenever a minigame starts / ends
##                  (<shot>_mg_NN.png), quits after --games=N minigames (default 4) or the run
##                  end. Prints MG_AUTO_PLAYED lines and MG_AUTO_DONE.
## Common: --seed=N --speed=N --class=<id>

const NAMES := ["mg_fossil", "mg_bubble", "mg_scratch", "mg_claw", "tile_minigames", "mg_play_auto", "mg_icons",
	"mg_bubble_shooter", "mg_plinko", "mg_shell_game", "mg_memory_match", "mg_fishing", "mg_lucky_wheel", "mg_high_low"]
const IDS := {"mg_fossil": "fossil_hunter", "mg_bubble": "bubble_breaker", "mg_scratch": "scratch_off", "mg_claw": "claw_machine",
	"mg_bubble_shooter": "bubble_shooter", "mg_plinko": "plinko", "mg_shell_game": "shell_game", "mg_memory_match": "memory_match",
	"mg_fishing": "fishing", "mg_lucky_wheel": "lucky_wheel", "mg_high_low": "high_low"}
## The Minigames 2.0 set (tile_minigames --set=new).
const NEW_IDS := ["bubble_shooter", "plinko", "shell_game", "memory_match", "fishing", "lucky_wheel", "high_low"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var d := _Driver.new()
	d.name = "MinigameScenario"
	d.scenario = name
	return d


## A run with the meta layer on and every minigame equipped (4 tiles).
static func all_games_flow(seed: int, cls := "knight") -> GameFlow:
	var meta := MetaRun.build(MetaPresets.get_preset("max"), cls)
	meta.minigames = MinigameDefs.IDS.duplicate()
	meta.whetstone = 0  # no opening Forge offer: straight to the board
	for id in MinigameDefs.IDS:
		meta.mastery[id] = 5
	return GameFlow.new_run(cls, seed, Balance.BOARD_SIZE, {"meta": meta})


class _Driver extends Node:
	var scenario := ""
	var c: GameController
	var args: Dictionary = {}
	var _shot_base := ""
	var _step := 0
	var _fail := ""

	func _ready() -> void:
		var shot: Node = get_tree().root.get_node_or_null("Shot")
		args = shot.args if shot else {}
		_shot_base = String(args.get("shot", "user://mg.png")).get_basename()
		c = GameController.new()
		c.autosave = false
		add_child(c)
		c.set_speed(float(args.get("speed", "1")))
		match scenario:
			"mg_icons":
				_icons()
			"tile_minigames":
				await _tiles()
			"mg_play_auto":
				await _play_auto()
			_:
				await _game(String(IDS[scenario]))

	func _flow() -> GameFlow:
		return MinigameScenarios.all_games_flow(int(args.get("seed", "7")), String(args.get("class", "knight")))

	# --- one game ------------------------------------------------------------------------

	func _game(id: String) -> void:
		var f := _flow()
		c.start(f)
		await _pause(0.5)
		var st := String(args.get("state", "fresh"))
		var ev := f.debug_open("minigame", id)
		await c.play_events(ev)
		if st == "fresh":
			if args.get("auto", "0") == "1":
				await _pause(0.6)
				_click_control(c.ui.minigame.auto_btn)
			return
		var scr := c.ui.minigame
		if st == "result":
			scr.set_meta("hold", 999.0)
		var n := {"mid": int(args.get("actions", "2")), "resume": 2, "anim": int(args.get("actions", "1")), "result": 99, "reward": 99, "play": 99}.get(st, 2) as int
		if args.has("delay"):
			await _pause(float(args.delay))
		if st == "play":
			await _snap("opened")
		var played := 0
		while f.phase == GameFlow.Phase.MINIGAME and not bool(f.offer.done) and played < n:
			await _idle()
			if not await _input_action(id, f):
				_fail = "input did not reach the core (%s)" % id
				break
			played += 1
			await _idle()
			if st == "play":
				await _snap("after action %d" % played)
		if st == "mid" or st == "anim":
			return
		if st == "resume":
			# quit mid-game and Continue: the save (JSON) resumes the same board
			var loaded := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
			c.start(loaded)
			print("MG_RESUME phase=%s same_state=%s" % [GameFlow.phase_name(loaded.phase),
				JSON.stringify(loaded.minigame.public_state()) == JSON.stringify(f.minigame.public_state())])
			return
		# the screen cashes the game in by itself once the board settles
		var guard := 0
		while f.phase == GameFlow.Phase.MINIGAME and guard < 200:
			guard += 1
			await _pause(0.05)
		if st == "result":
			return
		await _idle()
		await _pause(0.5)
		if st == "play" or st == "reward":
			await _snap("reward modal (tier %s)" % String(f.offer.get("tier", "?")))
		if st == "reward":
			return
		# pick the reward with real clicks: a card, then TAKE
		var rew := c.ui.minigame_reward
		var pick := 0
		var opts: Array = f.offer.get("options", [])
		for i in opts.size():
			if String(opts[i].id) in ["gold", "potion", "crown", "potion_gold"]:
				pick = i
				break
		var nc := f.commands.size()
		_click_control(rew._cards[pick])
		await _pause(0.3)
		_click_control(rew._take)
		await _idle()
		if f.commands.size() == nc:
			_fail = "reward pick did not reach the core"
		# anything the reward opened (a forge raise, a rune) resolves like a player would
		guard = 0
		while f.phase != GameFlow.Phase.BOARD_READY and not f.is_over() and guard < 10:
			guard += 1
			await c.run_command(Bot.next_command(f)[0], Bot.next_command(f).slice(1))
			await _idle()
		await _pause(0.6)
		await _snap("back on the board (phase %s)" % GameFlow.phase_name(f.phase))
		var ok := _fail == "" and f.phase == GameFlow.Phase.BOARD_READY and not c.ui.minigame.visible
		print("%s %s phase=%s commands=%s %s" % ["MG_PLAY_OK" if ok else "MG_PLAY_FAIL", id, GameFlow.phase_name(f.phase),
			str(f.commands), _fail])
		await _quit(0 if ok else 1)

	## Plays one action through injected mouse input. Returns true when the core took it.
	func _input_action(id: String, f: GameFlow) -> bool:
		var scr := c.ui.minigame
		var b := scr.board
		var st: Dictionary = f.offer.state
		var n := f.commands.size()
		BotMeta.minigame_mode = "play"
		var cmd := BotMeta.minigame_command(f)
		BotMeta.minigame_mode = "par"
		if cmd[0] != "minigame_action":
			return false
		var a: Array = cmd[1]
		var o := b.get_global_rect().position
		match id:
			"fossil_hunter":
				var fb := b as FossilBoard
				var p := o + fb.cell_rect(int(a[1]) * int(st.w) + int(a[0])).get_center()
				if args.has("debug"):
					print("CLICK ", p, " board ", b.get_global_rect(), " locked ", b.locked, " hovered ", get_viewport().gui_get_hovered_control())
				_click(p)
			"bubble_breaker":
				var bb := b as BubbleBoard
				_click(o + bb.to_screen(Vector2(int(a[0]), int(a[1]))))
			"scratch_off":
				var sb := b as ScratchBoard
				if args.get("rig", "") == "three":
					# screenshot aid only (the harness peeks, the screen never does): scratch the
					# highest face's three copies -> three alike, the jackpot when it is a 6
					var sm := f.minigame as ScratchOff
					var top := 0
					for v in sm.faces:
						top = maxi(top, int(v))
					for i in sm.faces.size():
						if int(sm.faces[i]) == top and sm.revealed[i] == 0:
							a = [i]
							break
				var r := sb.cell_rect(int(a[0]))
				# a zig-zag scratch across the cell
				var pts: Array = []
				for k in 9:
					pts.append(o + r.position + r.size * Vector2(0.15 + 0.7 * float(k % 2), 0.15 + 0.7 * k / 8.0))
				await _drag(pts)
			"claw_machine":
				var cb := b as ClawBoard
				if args.get("aim", "") == "cluster":
					# screenshot aid: the drop that scoops the most capsules (public data)
					var bx := 0.5
					var bn := -1
					for k in 101:
						var n2 := MgLogic.claw_scoop(st.balls, k / 100.0).size()
						if n2 > bn:
							bn = n2
							bx = k / 100.0
					a = [bx]
				var target := float(a[0]) + float(args.get("claw-offset", "0"))
				# wait for the sweep to pass over the target, then tap
				var guard := 0
				while guard < 600:
					guard += 1
					await get_tree().process_frame
					if absf(MgLogic.claw_x(cb._swing) - target) < 0.012:
						break
				_click(o + cb.size * 0.5)
			_:
				# (assign first: `if not await b.scripted_input(...)` miscompiles in 4.7.2 when the
				# override awaits)
				var ok: bool = await b.scripted_input(a, self)
				if not ok:
					print("MG_INPUT_UNSUPPORTED %s %s" % [id, str(a)])
					return false
		for k in 160:
			if f.commands.size() > n:
				return true
			await _pause(0.05)
		print("MG_INPUT_MISSED %s %s" % [id, str(a)])
		return false

	# --- model icons ---------------------------------------------------------------------

	## Every ModelIcons texture on a grid (checks the 3D -> 2D icon renders).
	func _icons() -> void:
		var paths := [ModelIcons.GEM, ModelIcons.GEM_SMALL, ModelIcons.COINS, ModelIcons.COIN_STACK, ModelIcons.GEM_CHEST,
			ModelIcons.NUGGET, ModelIcons.BALLOON_DOG, ModelIcons.ROBOT, ModelIcons.ACTION_FIGURE, ModelIcons.SHOVEL,
			ModelIcons.PICKAXE, ModelIcons.MAGNIFIER]
		var bg := ColorRect.new()
		bg.color = Color("2a1745")
		bg.size = Vector2(4000, 4000)
		add_child(bg)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.position = Vector2(20, 20)
		add_child(grid)
		for pth in paths:
			var tr := TextureRect.new()
			tr.custom_minimum_size = Vector2(220, 220)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.texture = ModelIcons.get_icon(pth, float(args.get("yaw", "30")))
			grid.add_child(tr)
		if args.get("keep", "0") != "1":
			c.queue_free()
		else:
			c.start(_flow())

	# --- tiles ---------------------------------------------------------------------------

	func _tiles() -> void:
		var f := _flow()
		# the four games on the tiles right after the hero
		var ids: Array = MinigameDefs.IDS.slice(0, 4)
		if args.get("set", "") == "new":
			ids = NEW_IDS.duplicate()
		if args.has("game"):
			ids = [String(args.game)]
		var at: Array = []
		for k in ids.size():
			at.append(k + 1)
			var t := Board.make_tile("minigame")
			t["game"] = String(ids[k])
			f.run.board.tiles[k + 1] = t
		c.start(f)
		await _pause(0.4)
		if args.get("close", "0") == "1":
			var pts := PackedVector3Array()
			for i in at:
				var p := c.board.tile_global_position(i)
				pts.append(p + Vector3(-1.4, 0, -1.4))
				pts.append(p + Vector3(1.4, 1.4, 1.4))
			c.rig.frame_points(pts, float(args.get("yaw", "0")), float(args.get("pitch", "48")), true)
		else:
			c.rig.overview(c.board.ring_bounds(), true)
		if args.get("land", "0") == "1":
			await _pause(0.6)
			# the landing beat on the fossil tile (started event only)
			f.run.pos = 1
			c.board.place_hero(1)
			var ev := f.debug_open("minigame", "fossil_hunter")
			await c.play_events(ev)

	# --- AUTO ----------------------------------------------------------------------------

	func _play_auto() -> void:
		var f := _flow()
		c.set_speed(float(args.get("speed", "3")))
		var want := int(args.get("games", "4"))
		var played := [0]
		var shots := [0]
		var ended := [false]
		# watch the event stream through UiRoot.on_event (the same feed the widgets get)
		var watcher := func(ev: Dictionary) -> void:
			match String(ev.get("type", "")):
				"minigame_started":
					print("MG_AUTO_STARTED %s lap=%d t=%.0fs" % [String(ev.id), f.run.lap, _el()])
					_shot_later("%s_mg_%02d_start.png" % [_shot_base, played[0] + 1], 1.4, shots)
				"minigame_result":
					played[0] += 1
					print("MG_AUTO_PLAYED %s tier=%s auto=%s score=%.1f crowns=%d" % [String(ev.id), String(ev.tier), str(ev.auto),
						float(ev.score), int(ev.crowns)])
					_shot_later("%s_mg_%02d_result.png" % [_shot_base, played[0]], 0.5, shots)
		_t0 = Time.get_ticks_msec()
		c.ui.minigame.set_meta("watch", watcher)
		c.auto.set_rules(AutoScenarios.rules_from(args))
		c.start(f)
		await get_tree().process_frame
		AutoScenarios.toggle_on(c)
		var timeout := float(args.get("timeout", "900"))
		var last_n := -1
		var last_change := 0.0
		while not f.is_over() and played[0] < want:
			await _pause(0.2)
			if _el() > timeout:
				print("MG_AUTO_TIMEOUT played=%d" % played[0])
				break
			if f.commands.size() != last_n:
				last_n = f.commands.size()
				last_change = _el()
			elif _el() - last_change > 30.0:
				print("MG_AUTO_STUCK phase=%s enabled=%s busy=%s" % [GameFlow.phase_name(f.phase), c.auto.enabled, c.busy])
				break
			if not c.auto.enabled and not c.busy and c.auto.can_act() and not f.is_over():
				AutoScenarios.toggle_on(c)
		await _pause(2.0)
		await _save("%s_final.png" % _shot_base)
		print("MG_AUTO_DONE played=%d phase=%s lap=%d commands=%d t=%.0fs" % [played[0], GameFlow.phase_name(f.phase), f.run.lap,
			f.commands.size(), _el()])
		await _quit(0 if played[0] >= mini(want, 1) else 1)

	var _t0 := 0

	func _el() -> float:
		return (Time.get_ticks_msec() - _t0) / 1000.0

	func _shot_later(path: String, delay: float, counter: Array) -> void:
		if counter[0] >= 12:
			return
		counter[0] += 1
		await _pause(delay)
		await _save(path)

	# --- helpers -------------------------------------------------------------------------

	## For MgBoard.scripted_input: mouse input at a global position.
	func click(p: Vector2) -> void:
		_click(p)

	func press(p: Vector2) -> void:
		_button(p, true)

	func release(p: Vector2) -> void:
		_button(p, false)

	func move(p: Vector2, held := true) -> void:
		var m := InputEventMouseMotion.new()
		m.position = p
		m.global_position = p
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
		get_viewport().push_input(m, true)

	func drag(pts: Array) -> void:
		await _drag(pts)

	func _button(p: Vector2, down: bool) -> void:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = p
		e.global_position = p
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		get_viewport().push_input(e, true)

	func _click(p: Vector2) -> void:
		for down in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = down
			e.position = p
			e.global_position = p
			e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			get_viewport().push_input(e, true)

	func _click_control(ctl: Control) -> void:
		if ctl:
			_click(ctl.get_global_rect().get_center())

	func _drag(pts: Array) -> void:
		var d := InputEventMouseButton.new()
		d.button_index = MOUSE_BUTTON_LEFT
		d.pressed = true
		d.position = pts[0]
		d.global_position = pts[0]
		d.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(d, true)
		for k in range(1, pts.size()):
			await get_tree().process_frame
			await get_tree().process_frame
			var m := InputEventMouseMotion.new()
			m.position = pts[k]
			m.global_position = pts[k]
			m.relative = Vector2(pts[k]) - Vector2(pts[k - 1])
			m.button_mask = MOUSE_BUTTON_MASK_LEFT
			get_viewport().push_input(m, true)
		var u := InputEventMouseButton.new()
		u.button_index = MOUSE_BUTTON_LEFT
		u.pressed = false
		u.position = pts[-1]
		u.global_position = pts[-1]
		get_viewport().push_input(u, true)

	func _idle() -> void:
		for i in 400:
			await _pause(0.05)
			if not c.busy:
				return

	func _snap(what: String) -> void:
		await _pause(0.35)
		var path := "%s_step_%02d.png" % [_shot_base, _step]
		await _save(path)
		print("STEP %02d %s -> %s" % [_step, what, path])
		_step += 1

	func _pause(t: float) -> void:
		await get_tree().create_timer(t, true, false, true).timeout

	func _save(path: String) -> void:
		var shot: Node = get_tree().root.get_node_or_null("Shot")
		if shot and shot.has_method("_save"):
			await shot._save(path)

	func _quit(code: int) -> void:
		Audio.stop_all()
		c.queue_free()
		for i in 3:
			await get_tree().process_frame
		Character.clear_cache()
		get_tree().quit(code)
