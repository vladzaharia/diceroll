extends SceneTree

func _run(meta: Dictionary, n := 40) -> String:
	var wins := 0
	var turns := 0
	var lvl := 0
	for r in n:
		var opts := {"route": ["glade", "hollow", "throne"], "boss": "boss_lich"}
		if not meta.is_empty():
			opts["meta"] = meta
		var f := GameFlow.new_run("knight", 1 + r * 7919, 28, opts)
		var k := 0
		while not f.is_over() and k < 20000:
			f.apply(Bot.next_command(f))
			k += 1
		if f.phase == GameFlow.Phase.VICTORY:
			wins += 1
		turns += int(f.run.stats.board_turns)
		lvl += f.run.level
	return "win %d/%d turns %.1f lvl %.1f" % [wins, n, float(turns) / n, float(lvl) / n]

func _init() -> void:
	var base := MetaRun.build(MetaPresets.get_preset("fresh"))
	var d := base.duplicate(true)
	d.minigames = []
	d.potion_cap = 0
	d.potions = 0
	for k in ["runes", "kinds", "passives"]:
		var e := d.duplicate(true)
		for k2 in ["runes", "kinds", "passives"]:
			if k2 != k:
				e.pools[k2] = []
		print("only ", k, " ", _run(e))
	quit()
