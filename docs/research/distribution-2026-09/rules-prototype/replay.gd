extends SceneTree
## Replays recorded command logs (no bot, no hashing) and times the engine alone.
const FORCE_PASSIVES := ["pair_master", "snake_eyes", "steady_hand", "boxcars", "straight_shooter", "midas_fist",
	"glass_cannon", "opening_salvo", "gold_tooth", "full_house_party", "bloodthirst", "thorns", "iron_skin",
	"second_wind", "phoenix", "piggy_bank", "treasure_sense", "haggler", "scholar", "crowd_pleaser", "triple_threat",
	"rune_echo", "resonance", "loaded_hands", "encore"]
const FORCE_RUNES := ["ember", "echo", "vampire", "blade", "heavy", "guard", "venom", "frost", "thunder", "lucky", "gilded"]
const SWORDS := ["sword", "sword_saber", "sword_rapier", "sword_knight", "sword_flame"]

func _init() -> void:
	var path := ""
	var reps := 3
	var no_force := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--logs="):
			path = a.substr(7)
		elif a.begins_with("--reps="):
			reps = int(a.substr(7))
		elif a == "--no-force":
			no_force = true
	var logs: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var max_prof := MetaPresets.get_preset("max")
	var best := 1 << 62
	var n_cmd := 0
	var n_att := 0
	var chk := 0
	for rep in reps:
		var t_eng := 0
		n_cmd = 0
		n_att = 0
		chk = 0
		for L in logs:
			var cls := String(L.cls)
			var s := int(L.s)
			var seed := int(L.seed)
			var opts := {}
			if String(L.cfg) != "legacy":
				var meta := MetaRun.build(max_prof, cls)
				meta.items["weapon"] = {"id": "sword", "variant": String(SWORDS[s % SWORDS.size()]), "tier": 1 + (s % 3)}
				opts["meta"] = meta
				if String(L.cfg) == "a10":
					opts["ascension"] = 10
			var f := GameFlow.new_run(cls, seed, 28, opts)
			var frng := Rng.new(seed * 3 + 17)
			var k := 3 + frng.randi_range(0, 5)
			for j in k:
				var p := String(frng.pick(FORCE_PASSIVES))
				if not f.run.passives.has(p) and not no_force:
					f.run.passives.append(p)
			for i in f.run.dice.size():
				if frng.chance(0.7):
					var rr := String(frng.pick(FORCE_RUNES))
					if not no_force:
						f.run.dice[i].rune = rr
			var r: Variant = load("res://core/rules/rules.gd") if ResourceLoader.exists("res://core/rules/rules.gd") else null
			if r != null:
				r.invalidate(f.run)
			var t0 := Time.get_ticks_usec()
			for cmd in L.cmds:
				if String(cmd[0]) == "combat_attack":
					n_att += 1
				var ev := f.apply(cmd)
				chk += ev.size()
				n_cmd += 1
			t_eng += Time.get_ticks_usec() - t0
		best = mini(best, t_eng)
	print("replay: %d cmds, %d attacks, %d events; best of %d: %.1f ms engine (%.2f us/cmd, %.2f us/attack-equivalent)" % [
		n_cmd, n_att, chk, reps, best / 1000.0, float(best) / n_cmd, float(best) / maxi(1, n_att)])
	var r2: Variant = load("res://core/rules/rules.gd") if ResourceLoader.exists("res://core/rules/rules.gd") else null
	if r2 != null:
		print(r2.stats_line())
	quit()
