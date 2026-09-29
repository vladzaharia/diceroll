extends SceneTree
## Builds the Camp stage fixtures (game/camp/stages/stage_N.json): one campaign from a fresh
## profile played by AUTO's realistic policy, spending like the campaign bot after every run
## (tools/sim.gd --campaign), with the profile saved after runs 3, 10 and 25.
##
##   godot --headless --path . -s tools/camp_stages.gd [-- --seed=11 --runs=3,10,25]

const OUT := "res://game/camp/stages/"


func _init() -> void:
	var seed0 := 11
	var marks: Array = [3, 10, 25]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed0 = a.substr(7).to_int()
		elif a.begins_with("--runs="):
			marks = []
			for x in a.substr(7).split(","):
				marks.append(int(x))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var p := Profile.fresh()
	var camp := Camp.new(p)
	var rules := AutoRules.all_on()
	var last: int = marks.max()
	for r in last:
		var lo := BotMeta.choose_loadout(p)
		camp.set_class(_least_played(p))
		camp.set_loadout(lo[0], String(lo[1]))
		var f := GameFlow.new_run(String(p.loadout["class"]), seed0 + r * 7919, Balance.BOARD_SIZE, {"profile": p.to_dict()})
		var guard := 0
		while not f.is_over() and guard < 6000:
			guard += 1
			var d := Bot.decide(f, rules)
			var cmd: Array = d.cmd if not bool(d.get("stop", false)) and not (d.cmd as Array).is_empty() else Bot.next_command(f)
			f.apply(cmd)
		camp.bank_run(f._summary())
		BotMeta.spend(camp)
		print("run %d: %s lap %d  crowns %d sigils %d classes %s pets %s packs %d" % [r + 1,
			"WIN " if f.phase == GameFlow.Phase.VICTORY else "loss", f.run.lap, p.crowns, p.sigils, str(p.unlocks.classes),
			str(p.unlocks.pets), (p.unlocks.packs as Array).size()])
		var k := marks.find(r + 1)
		if k >= 0:
			var path := OUT + "stage_%d.json" % (k + 1)
			var fa := FileAccess.open(path, FileAccess.WRITE)
			fa.store_string(Profile.to_json(p))
			fa.close()
			print("saved ", path)
	quit(0)


func _least_played(p: Profile) -> String:
	var best := "knight"
	var rbc: Dictionary = p.records.get("runs_by_class", {})
	var n := 1 << 30
	for id in HeroDefs.IDS:
		if p.class_allowed(String(id)) and int(rbc.get(id, 0)) < n:
			n = int(rbc.get(id, 0))
			best = String(id)
	return best
