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
	var args := {"fossil_hunter": [2, 2], "scratch_off": [4], "claw_machine": [0.5]}
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


## The claw's aim highlight uses the same "closest centre whose hitbox contains x" rule.
func test_claw_aim_matches_core() -> void:
	for s in 20:
		var m := Minigames.create("claw_machine", 900 + s, 1) as ClawMachine
		var st := m.public_state()
		for k in 101:
			var x := k / 100.0
			assert_eq(MgLogic.claw_target(st.prizes, x), m.prize_at(x), "seed %d x %.2f" % [s, x])


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
	cells.resize(25)
	cells.fill("?")
	cells[6] = "bone"
	cells[7] = "bone"
	cells[8] = "bone"
	cells[12] = "hit"
	assert_eq(MgLogic.bone_links(cells, 7, 5), [true, false, true, false])  # left, up, right, down
	assert_eq(MgLogic.bone_links(cells, 12, 5), [false, false, false, false])


## A full scripted play of each game through GameFlow reaches the reward and the board.
func test_scripted_play_reaches_reward_then_board() -> void:
	for game in MinigameDefs.IDS:
		var f := GameFlow.new_run("knight", 21, 28, {"profile": Profile.fresh().to_dict()})
		f.debug_open("minigame", game)
		var guard := 0
		while f.phase == P.MINIGAME and not bool(f.offer.done) and guard < 12:
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
