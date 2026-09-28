extends "res://tests/test_case.gd"
## Bot.decide(flow, rules): contract, purity, scopes and stop conditions.

func _keys_ok(d: Dictionary) -> bool:
	return d.has("cmd") and d.has("reason") and d.has("stop") and d.has("stop_reason")

## Plays up to `steps` smart decisions; checks after every decide() that the flow (and the run's
## rng) is untouched, and that every returned command applies without an error event.
func _play(cls: String, seed: int, steps: int, rules: AutoRules) -> GameFlow:
	var f := GameFlow.new_run(cls, seed)
	for n in steps:
		if f.is_over():
			break
		var before := f.to_dict()
		var rng_before := f.run.rng.state
		var d := Bot.decide(f, rules)
		assert_true(_keys_ok(d), "decide result has all keys")
		assert_eq(f.run.rng.state, rng_before, "run rng untouched at step %d" % n)
		var after := f.to_dict()
		if after != before:
			assert_true(false, "flow mutated by decide() at step %d phase %s" % [n, GameFlow.phase_name(f.phase)])
			return f
		if d.stop:
			assert_true(false, "unexpected stop: %s" % d.stop_reason)
			return f
		assert_true(String(d.reason) != "", "every decision has a reason")
		var ev := f.apply(d.cmd)
		for e in ev:
			if e.type == "error":
				assert_true(false, "cmd %s errored: %s (phase %s)" % [str(d.cmd), e.msg, GameFlow.phase_name(f.phase)])
				return f
	return f

func test_decide_never_mutates_flow_and_commands_are_legal() -> void:
	var f := _play("mage", 11, 700, AutoRules.all_on())
	assert_true(f.commands.size() > 300, "played a good chunk of the run")

func test_full_runs_finish() -> void:
	for cls in ["knight", "rogue"]:
		var f := _play(cls, 3, 20000, AutoRules.all_on("defense" if cls == "knight" else "economy"))
		assert_true(f.is_over(), "%s run finished" % cls)

func test_deterministic() -> void:
	var f := GameFlow.new_run("barbarian", 7)
	var rules := AutoRules.all_on()
	for n in 150:
		var a := Bot.decide(f, rules)
		Bot.clear_cache()
		var b := Bot.decide(f, rules)
		assert_eq(a, b, "same state, same decision (step %d)" % n)
		f.apply(a.cmd)

func test_game_over_stops() -> void:
	var f := GameFlow.new_run("knight", 1)
	f.phase = GameFlow.Phase.GAME_OVER
	var d := Bot.decide(f, AutoRules.new())
	assert_true(d.stop)
	assert_eq(d.cmd, [])

func test_scope_off_stops() -> void:
	var f := GameFlow.new_run("knight", 1)
	var rules := AutoRules.new()
	rules.board = false
	var d := Bot.decide(f, rules)
	assert_true(d.stop, "board off stops on the board")
	assert_true(String(d.stop_reason).to_lower().contains("board"), d.stop_reason)
	rules.board = true
	d = Bot.decide(f, rules)
	assert_true(not d.stop)
	assert_eq(d.cmd, ["roll_board"])
	f.debug_open("combat", "skeleton_minion")
	rules.combat = false
	d = Bot.decide(f, rules)
	assert_true(d.stop, "combat off stops in combat")
	rules.combat = true
	d = Bot.decide(f, rules)
	assert_true(not d.stop)
	for pair in [["forge", "forge"], ["event", "events"], ["portal", "portal"], ["draft", "drafts"]]:
		var g := GameFlow.new_run("knight", 2)
		g.debug_open(pair[0])
		var rr := AutoRules.new()
		assert_true(not Bot.decide(g, rr).stop, "%s on plays" % pair[0])
		rr.set(pair[1], false)
		assert_true(Bot.decide(g, rr).stop, "%s off stops" % pair[0])

func test_stop_hp_below() -> void:
	var f := GameFlow.new_run("knight", 1)
	var rules := AutoRules.new()
	rules.stop_hp_below = 0.3
	f.run.hp = int(f.run.max_hp * 0.25)
	var d := Bot.decide(f, rules)
	assert_true(d.stop, "HP below threshold stops")
	assert_true(String(d.stop_reason).contains("HP"), d.stop_reason)
	f.run.hp = f.run.max_hp
	assert_true(not Bot.decide(f, rules).stop)

## A board roll whose move crosses Start on the final lap starts the final boss.
func test_stop_before_boss() -> void:
	var f := GameFlow.new_run("knight", 1)
	f.run.lap = Balance.TOTAL_LAPS
	f.run.pos = f.run.board.size() - 3
	f.phase = GameFlow.Phase.BOARD_ROLLED
	f.board_roll.assign([3, 3])
	f.board_choice.assign([0, 1])
	f.board_move = 6
	f.board_rerolls_left = 0
	assert_eq(f.board_target(), 0)
	var rules := AutoRules.new()
	var d := Bot.decide(f, rules)
	assert_true(d.stop, "stops before the final boss")
	assert_true(String(d.stop_reason).to_lower().contains("boss"), d.stop_reason)
	rules.stop_before_boss = false
	d = Bot.decide(f, rules)
	assert_true(not d.stop)
	assert_eq(d.cmd, ["confirm_move"])

func _miniboss_flow() -> GameFlow:
	var f := GameFlow.new_run("knight", 1)
	var t := 5
	f.run.board.tiles[t] = Board.make_tile("miniboss", [f.run.miniboss_id])
	f.run.pos = 1
	f.phase = GameFlow.Phase.BOARD_ROLLED
	f.board_roll.assign([2, 2])
	f.board_choice.assign([0, 1])
	f.board_move = 4
	f.board_rerolls_left = 1
	return f

func test_miniboss_rules() -> void:
	var f := _miniboss_flow()
	var rules := AutoRules.new()
	rules.stop_before_miniboss = true
	var d := Bot.decide(f, rules)
	assert_true(d.stop, "stops before the mini-boss")
	rules.stop_before_miniboss = false
	rules.fight_miniboss = "always"
	d = Bot.decide(f, rules)
	assert_eq(d.cmd, ["confirm_move"], "always fights")
	rules.fight_miniboss = "never"
	d = Bot.decide(f, rules)
	assert_eq(d.cmd, ["board_reroll"], "never: rerolls away from it")

func test_stop_on_boss_passive() -> void:
	var f := GameFlow.new_run("knight", 1)
	f.debug_open("passive", "miniboss")
	var rules := AutoRules.new()
	var d := Bot.decide(f, rules)
	assert_true(d.stop, "boss passive offered: stop")
	rules.stop_on_boss_passive = false
	d = Bot.decide(f, rules)
	assert_true(not d.stop)
	assert_eq(String(d.cmd[0]), "pick_draft")
	# regular passives never stop
	var g := GameFlow.new_run("knight", 1)
	g.debug_open("passive", "elite")
	assert_true(not Bot.decide(g, AutoRules.new()).stop)

func test_shop_modes() -> void:
	var f := GameFlow.new_run("knight", 1)
	f.run.gold = 200
	f.debug_open("shop")
	var rules := AutoRules.new()
	var d := Bot.decide(f, rules)
	assert_true(d.stop, "shop off + stop_on_shop: hand back")
	rules.stop_on_shop = false
	d = Bot.decide(f, rules)
	assert_eq(d.cmd, ["shop_leave"], "shop off without stop: leave")
	rules.shop = true
	rules.stop_on_shop = true
	d = Bot.decide(f, rules)
	assert_true(not d.stop, "shop on: AUTO shops")
	assert_eq(String(d.cmd[0]), "shop_buy", "buys something with 200 gold")

## Keeps a gold reserve for the next shop's die while the pool has room.
func test_shop_reserve_for_die() -> void:
	var f := GameFlow.new_run("knight", 1)
	f.debug_open("shop")
	f.offer.items = [
		{"id": "face_raise", "label": "Face Raise", "desc": "", "price": 25, "needs_die": true, "sold": false},
	]
	f.run.gold = 45
	var d := Bot.decide(f, AutoRules.all_on())
	assert_eq(d.cmd, ["shop_leave"], "keeps the reserve for a die: " + String(d.reason))
	f.run.gold = 200
	d = Bot.decide(f, AutoRules.all_on())
	assert_eq(String(d.cmd[0]), "shop_buy", "plenty of gold: buys")

func test_rune_assign_synergy() -> void:
	var f := GameFlow.new_run("knight", 1)
	f.run.dice.clear()
	f.run.dice.append(Die.make("", "low"))
	f.run.dice.append(Die.make("", "giant"))
	f.run.dice.append(Die.make("", "standard"))
	f.debug_open("rune_assign", "heavy")
	var d := Bot.decide(f, AutoRules.new())
	assert_eq(d.cmd, ["rune_assign", 1], "Heavy goes on the Giant die")

func test_draft_prefers_new_die_early() -> void:
	var f := GameFlow.new_run("knight", 1)
	f.debug_open("draft")
	f.offer.options = [
		{"id": "max_hp", "label": "+8 Max HP", "desc": ""},
		{"id": "new_die", "label": "Standard Die", "desc": "", "kind": "standard"},
		{"id": "face_raise", "label": "Face Raise", "desc": ""},
	]
	var d := Bot.decide(f, AutoRules.new())
	assert_eq(d.cmd, ["pick_draft", 1], "a 3rd die beats the rest")

func test_focus_changes_draft() -> void:
	var f := GameFlow.new_run("knight", 1)
	f.debug_open("passive", "elite")
	f.offer.options = [Passives.option("iron_skin"), Passives.option("piggy_bank"), Passives.option("pair_master")]
	var picks := {}
	for fo in ["defense", "economy", "damage"]:
		var r := AutoRules.new()
		r.focus = fo
		picks[fo] = int(Bot.decide(f, r).cmd[1])
	assert_eq(picks.defense, 0, "defense takes Iron Skin")
	assert_eq(picks.economy, 1, "economy takes Piggy Bank")
	assert_eq(picks.damage, 2, "damage takes Pair Master")

func test_board_seeks_campfire_when_low() -> void:
	var f := GameFlow.new_run("knight", 1)
	var b := f.run.board
	b.tiles[5] = Board.make_tile("trap")
	f.run.pos = 1
	f.run.hp = 10
	f.phase = GameFlow.Phase.BOARD_ROLLED
	f.board_roll.assign([2, 2])
	f.board_choice.assign([0, 1])
	f.board_move = 4
	f.board_rerolls_left = 1
	for k in range(2, b.size()):
		if k != 5 and not b.is_corner(k):
			b.tiles[k] = Board.make_tile("campfire")
	var d := Bot.decide(f, AutoRules.new())
	assert_eq(d.cmd, ["board_reroll"], "low HP on a trap with campfires around: reroll")
	f.board_move = 3
	d = Bot.decide(f, AutoRules.new())
	assert_eq(d.cmd, ["confirm_move"], "campfire when low: go")
