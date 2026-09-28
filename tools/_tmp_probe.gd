extends SceneTree

func _run(meta: Dictionary, n := 200) -> String:
	var wins := 0
	for r in n:
		var opts := {"route": ["glade", "hollow", "throne"], "boss": "boss_lich", "miniboss": "mini_pumpkin_knight"}
		if not meta.is_empty():
			opts["meta"] = meta
		var f := GameFlow.new_run("knight", 1 + r * 7919, 28, opts)
		var k := 0
		while not f.is_over() and k < 20000:
			f.apply(Bot.next_command(f))
			k += 1
		if f.phase == GameFlow.Phase.VICTORY:
			wins += 1
	return "%.1f%%" % (100.0 * wins / n)

func _init() -> void:
	var base := MetaRun.build(MetaPresets.get_preset("fresh"))
	var d := base.duplicate(true)
	for pool in [["blade","guard","venom","heavy","gilded"], ["blade","guard","venom","heavy","gilded","vampire","ember","lucky","frost","thunder"], ["vampire"], ["guard"], ["blade"], ["heavy"], ["venom"], ["gilded"]]:
		d = base.duplicate(true); d.pools.runes = pool; print(pool, ": ", _run(d))
	quit()
