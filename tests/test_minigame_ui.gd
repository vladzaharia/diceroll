extends "res://tests/test_case.gd"
## WP-E2 minigame presentation: the pure helpers the screens use (they only read public
## state) agree with the core rules, and AUTO takes the par result for every minigame.

const P := GameFlow.Phase


func _first(ev: Array, type: String) -> Dictionary:
	for e: Dictionary in ev:
		if String(e.get("type", "")) == type:
			return e
	return {}


## AUTO (Bot.decide / BotMeta par mode) must skip every untouched minigame with the par
## result (review §5.4: "AUTO plays at a par result of 85% of median"), the claw included.
func test_auto_takes_par_for_every_minigame() -> void:
	for game in MinigameDefs.IDS:
		var f := GameFlow.new_run("knight", 11, 28, {"profile": Profile.fresh().to_dict()})
		f.debug_open("minigame", game)
		assert_eq(BotMeta.minigame_command(f), ["minigame_auto"], game)
		var d := Bot.decide(f, AutoRules.all_on())
		assert_eq(d.cmd, ["minigame_auto"], game + " via Bot.decide")


## The public state handed to the presentation is a snapshot: a later action must not change
## a state the screen already holds (Array(typed) aliases the live array in Godot 4).
func test_public_state_is_a_snapshot() -> void:
	var args := {"fossil_hunter": [2, 2], "scratch_off": [4], "claw_machine": [0.5], "bubble_shooter": [60], "plinko": [4],
		"shell_game": [1, 0.5], "memory_match": [3], "fishing": ["cast", 1], "lucky_wheel": ["spin"], "high_low": ["higher"]}
	for game in MinigameDefs.IDS:
		var m := Minigames.create(game, 321, 1)
		var st := m.public_state()
		var before := JSON.stringify(st)
		var a: Array = args.get(game, [])
		if game == "bubble_breaker":
			var cl: Array = (m as BubbleBreaker).clusters()[0]
			a = [int(cl[0]) / BubbleBreaker.H, int(cl[0]) % BubbleBreaker.H]
		assert_true(m.action(a).has("info"), game)
		assert_eq(JSON.stringify(st), before, game)


## Bubble Breaker: the screen animates gravity with MgLogic.bubble_moves (old cell -> new
## cell) computed from the public grid and the popped cells; it must land exactly on the
## core's next grid.
func test_bubble_collapse_mapping_matches_core() -> void:
	for s in 40:
		var m := Minigames.create("bubble_breaker", 500 + s * 13, 1) as BubbleBreaker
		var guard := 0
		while not m.done and guard < 6:
			guard += 1
			var st := m.public_state().duplicate(true)
			var cls := m.clusters()
			if cls.is_empty():
				break
			var pick: Array = cls[(s + guard) % cls.size()]
			var cell := int(pick[0])
			var res := m.action([cell / BubbleBreaker.H, cell % BubbleBreaker.H])
			var moves := MgLogic.bubble_moves(st.grid, res.info.cells, int(st.w), int(st.h))
			var want: Array = m.public_state().grid
			var got: Array = []
			got.resize(want.size())
			got.fill(-1)
			for from in moves:
				got[int(moves[from])] = int(st.grid[int(from)])
			assert_eq(got, want, "seed %d tap %d" % [s, guard])


## The screens' cluster highlight equals the core's cluster.
func test_bubble_cluster_matches_core() -> void:
	var m := Minigames.create("bubble_breaker", 77, 1) as BubbleBreaker
	var st := m.public_state()
	for x in 6:
		for y in 6:
			var mine := MgLogic.bubble_cluster(st.grid, x, y, 6, 6)
			assert_eq(mine, Array(m.cluster(x, y)))


## The claw's scoop highlight uses the core's rule on public data.
func test_claw_aim_matches_core() -> void:
	for s in 20:
		var m := Minigames.create("claw_machine", 900 + s, 1) as ClawMachine
		var st := m.public_state()
		for k in 101:
			var x := k / 100.0
			assert_eq(MgLogic.claw_scoop(st.balls, x), ClawMachine.scoop(m.balls, x), "seed %d x %.2f" % [s, x])


## The claw sweep is deterministic: a constant-speed triangle wave from the left edge.
func test_claw_sweep_is_deterministic() -> void:
	assert_near(MgLogic.claw_x(0.0), MgLogic.CLAW_MIN)
	assert_near(MgLogic.claw_x(MgLogic.CLAW_SWEEP), MgLogic.CLAW_MAX)
	assert_near(MgLogic.claw_x(MgLogic.CLAW_SWEEP * 2.0), MgLogic.CLAW_MIN)
	assert_near(MgLogic.claw_x(MgLogic.CLAW_SWEEP * 0.5), (MgLogic.CLAW_MIN + MgLogic.CLAW_MAX) * 0.5)


## Scratch-off: the jackpot / match highlight reads only revealed faces.
func test_scratch_matches() -> void:
	assert_eq(MgLogic.scratch_best([0, 3, 0, 3, 0, 0, 0, 5, 0]), {"face": 3, "count": 2, "cells": [1, 3]})
	assert_eq(MgLogic.scratch_best([6, 0, 6, 0, 6, 0, 0, 0, 0]), {"face": 6, "count": 3, "cells": [0, 2, 4]})
	assert_eq(MgLogic.scratch_best([1, 2, 0, 0, 0, 0, 0, 0, 3]).count, 1)


## Fossil Hunter: bone cells link to orthogonal neighbours of the same public kind.
func test_fossil_bone_links() -> void:
	var cells: Array = []
	cells.resize(49)
	cells.fill("?")
	cells[8] = "bone"
	cells[9] = "bone"
	cells[10] = "bone"
	cells[16] = "hit"
	assert_eq(MgLogic.bone_links(cells, 9, 7), [true, false, true, false])  # left, up, right, down
	assert_eq(MgLogic.bone_links(cells, 16, 7), [false, false, false, false])


## Fossil Hunter (luck dig): the public state carries no hints, only dug cells; a dig reveals
## just its own cell; a mid-game save resumes identically; scores match the documented rule.
func test_fossil_luck_dig_rules() -> void:
	for s in 30:
		var m := Minigames.create("fossil_hunter", 4000 + s * 31, 1) as FossilHunter
		var st := m.public_state()
		assert_true(not st.has("hints"), "no hints")
		assert_eq(int(st.w), 7)
		assert_eq((st.cells as Array).count("?"), 49)
		assert_eq(m.actions_left, FossilHunter.DIGS)
		# hidden layout: 4 + 3 + 2 fossil cells and the treasures
		var fossil_cells := 0
		var treasure_cells := 0
		for c in m.cells:
			if c >= FossilHunter.TREASURE_BASE:
				treasure_cells += 1
			elif c >= 0:
				fossil_cells += 1
		assert_eq(fossil_cells, 9)
		assert_eq(treasure_cells, FossilHunter.TREASURES.size())
		var k := 0
		while not m.done and m.actions_left > 0:
			var before: Array = m.public_state().cells
			var c := BotMeta.fossil_pick(m.public_state())
			var res := m.action([c % 7, c / 7])
			assert_true(res.has("info"))
			var after: Array = m.public_state().cells
			var changed := 0
			for i in 49:
				if String(before[i]) != String(after[i]) and not (String(before[i]) == "hit" and String(after[i]) == "bone"):
					changed += 1
			assert_eq(changed, 1, "one dig reveals one cell")
			k += 1
			if k == 4:
				var copy := Minigames.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
				assert_eq(JSON.stringify(copy.public_state()), JSON.stringify(m.public_state()), "mid-game save")
		# score = fossil cells + completion bonus (size) + treasure points
		var want := 0
		var pub := m.public_state()
		for i in 49:
			match String(pub.cells[i]):
				"hit", "bone": want += 1
				"gem": want += 3
				"coin": want += 2
		for f: Dictionary in pub.fossils:
			if bool(f.found):
				want += int(f.size)
		assert_eq(int(m.score()), want)


## A full scripted play of each game through GameFlow reaches the reward and the board.
func test_scripted_play_reaches_reward_then_board() -> void:
	for game in MinigameDefs.IDS:
		var f := GameFlow.new_run("knight", 21, 28, {"profile": Profile.fresh().to_dict()})
		f.debug_open("minigame", game)
		var guard := 0
		while f.phase == P.MINIGAME and not bool(f.offer.done) and guard < 80:
			guard += 1
			BotMeta.minigame_mode = "play"
			var cmd := BotMeta.minigame_command(f)
			BotMeta.minigame_mode = "par"
			if cmd[0] != "minigame_action":
				break
			var ev := f.apply(cmd)
			assert_eq(String(ev[0].type), "minigame_update", game)
		var res := f.minigame_finish()
		assert_true(not _first(res, "minigame_result").is_empty(), game)
		assert_eq(f.offer.kind, "reward", game)
		f.pick_draft(0)
		assert_true(f.phase != P.MINIGAME, game)


## Claw Machine (capsule pile): contents stay hidden until won (no leak in the public state),
## a grab scoops at most 3 capsules, slips are deterministic from the seed, and saves resume.
func test_claw_capsule_rules() -> void:
	var slipped_any := false
	var multi := false
	for s in 40:
		var m := Minigames.create("claw_machine", 2000 + s * 17, 1) as ClawMachine
		var st := m.public_state()
		assert_eq((st.balls as Array).size(), ClawMachine.BALLS)
		for b: Dictionary in st.balls:
			assert_true(not b.has("kind") and not b.has("points"), "contents hidden")
		assert_eq((st.won as Array).size(), 0)
		var legend := -1
		for i in m.balls.size():
			if String(m.balls[i].tier) == "legendary":
				legend = i
		for i in m.balls.size():
			assert_true(float(m.balls[legend].depth) >= float(m.balls[i].depth) - 0.001 or String(m.balls[i].tier) == "legendary")
		var copy := Minigames.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
		var r := m.action([float(m.balls[legend].pos)])
		var held: Array = r.info.held
		assert_true(held.size() <= ClawMachine.MAX_HOLD)
		assert_eq((r.info.won as Array).size() + (r.info.slipped as Array).size(), held.size())
		multi = multi or held.size() >= 2
		slipped_any = slipped_any or not (r.info.slipped as Array).is_empty()
		var pts := 0
		for w: Dictionary in r.info.won:
			pts += int(w.points)
		assert_eq(int(m.score()), pts)
		# only won capsules show their contents
		var pub := m.public_state()
		for i in (pub.balls as Array).size():
			assert_true(not (pub.balls[i] as Dictionary).has("kind"))
		assert_eq((pub.won as Array).size(), (r.info.won as Array).size())
		m.action([0.5])
		copy.action([float(copy.public_state().balls[legend].pos)])
		copy.action([0.5])
		assert_eq(JSON.stringify(copy.public_state()), JSON.stringify(m.public_state()), "save resumes identically")
	assert_true(multi, "some grabs scoop several capsules")
	assert_true(slipped_any, "some capsules slip")
