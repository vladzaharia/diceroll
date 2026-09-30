extends SceneTree
## A/B golden harness for the rules-as-data prototype. Plays greedy-bot runs (Bot.next_command)
## per class and config, with forced passives / runes / sword variants so the converted rules
## are exercised, and hashes every event list plus the final flow state. Identical output in
## project A (original core) and project B (rules evaluator) = behaviour-preserving.
## Usage: godot --headless --path . -s golden.gd -- --runs=N [--cfg=legacy,max] [--quiet]

const FORCE_PASSIVES := ["pair_master", "snake_eyes", "steady_hand", "boxcars", "straight_shooter", "midas_fist",
	"glass_cannon", "opening_salvo", "gold_tooth", "full_house_party", "bloodthirst", "thorns", "iron_skin",
	"second_wind", "phoenix", "piggy_bank", "treasure_sense", "haggler", "scholar", "crowd_pleaser", "triple_threat",
	"rune_echo", "resonance", "loaded_hands", "encore"]
const FORCE_RUNES := ["ember", "echo", "vampire", "blade", "heavy", "guard", "venom", "frost", "thunder", "lucky", "gilded"]
const SWORDS := ["sword", "sword_saber", "sword_rapier", "sword_knight", "sword_flame"]

func _init() -> void:
	var runs := 4
	var cfgs := ["legacy", "max"]
	var quiet := false
	var dump := ""
	var logs_path := ""
	var logs: Array = []
	var only_cls := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.substr(7))
		elif a.begins_with("--cfg="):
			cfgs = Array(a.substr(6).split(",", false))
		elif a.begins_with("--dump="):
			dump = a.substr(7)
		elif a.begins_with("--logs="):
			logs_path = a.substr(7)
		elif a.begins_with("--class="):
			only_cls = a.substr(8)
		elif a == "--quiet":
			quiet = true
	var all := HashingContext.new()
	all.start(HashingContext.HASH_SHA256)
	var t_all := Time.get_ticks_usec()
	var n_cmds := 0
	var n_attacks := 0
	var max_prof := MetaPresets.get_preset("max")
	for cfg in cfgs:
		for cls in HeroDefs.IDS:
			if only_cls != "" and cls != only_cls:
				continue
			var hc := HashingContext.new()
			hc.start(HashingContext.HASH_SHA256)
			var wins := 0
			for s in runs:
				var seed := 1000 + s * 7919 + HeroDefs.IDS.find(cls) * 131
				var opts := {}
				if cfg == "max" or cfg == "a10" or cfg == "moon":
					var meta := MetaRun.build(max_prof, cls)
					var sw := String(SWORDS[s % SWORDS.size()])
					meta.items["weapon"] = {"id": "sword", "variant": sw, "tier": 1 + (s % 3)}
					opts["meta"] = meta
					if cfg == "a10":
						opts["ascension"] = 10
					if cfg == "moon":
						opts["route"] = [["glade", "crypt", "mines"][s % 3], ["hollow", "frost", "warcamp"][(s / 3) % 3], "moonlit"]
						opts["boss"] = "boss_moon_king"
						if s % 4 == 1:
							opts["ascension"] = 9
				var f := GameFlow.new_run(cls, seed, 28, opts)
				var frng := Rng.new(seed * 3 + 17)
				var k := 3 + frng.randi_range(0, 5)
				for j in k:
					var p := String(frng.pick(FORCE_PASSIVES))
					if not f.run.passives.has(p):
						f.run.passives.append(p)
				for i in f.run.dice.size():
					if frng.chance(0.7):
						f.run.dice[i].rune = String(frng.pick(FORCE_RUNES))
				if cfg == "moon":
					f.run.max_hp = 260 + s * 23
					f.run.hp = f.run.max_hp
					for dd in 3:
						f.run.dice.append(Die.make(["", "blade", "heavy"][dd], ["standard", "high", "twin"][dd]))
					if s % 2 == 1:
						f.run.stats["minibosses_killed"] = ["mini_moonfang"]
					var ev0 := f.debug_open("boss", "boss_moon_king")
					hc.update(JSON.stringify(ev0).to_utf8_buffer())
					for e0 in ev0:
						if String(e0.type) == "moon_meter":
							print("  moon start s=%d %s" % [s, JSON.stringify(e0)])
				var r: Variant = load("res://core/rules/rules.gd") if ResourceLoader.exists("res://core/rules/rules.gd") else null
				if r != null:
					r.invalidate(f.run)
				var cmds := 0
				var df: FileAccess = FileAccess.open(dump + "_%s_%s_%d.txt" % [cfg, cls, s], FileAccess.WRITE) if dump != "" else null
				while not f.is_over() and cmds < 20000:
					var cmd := Bot.next_command(f)
					if String(cmd[0]) == "combat_attack":
						n_attacks += 1
					var ev := f.apply(cmd)
					cmds += 1
					hc.update(JSON.stringify(ev).to_utf8_buffer())
					if df != null:
						df.store_line(JSON.stringify(cmd))
						for e in ev:
							df.store_line("  " + JSON.stringify(e))
				n_cmds += cmds
				if logs_path != "":
					logs.append({"cfg": cfg, "cls": cls, "s": s, "seed": seed, "cmds": f.commands.duplicate(true)})
				if f.phase == GameFlow.Phase.VICTORY:
					wins += 1
				hc.update(JSON.stringify(f.to_dict()).to_utf8_buffer())
			var h := hc.finish().hex_encode()
			all.update(h.to_utf8_buffer())
			if not quiet:
				print("%s %-12s wins %d/%d %s" % [cfg, cls, wins, runs, h.substr(0, 16)])
	var dt := Time.get_ticks_usec() - t_all
	if logs_path != "":
		var lf := FileAccess.open(logs_path, FileAccess.WRITE)
		lf.store_string(JSON.stringify(logs))
	print("TOTAL %s  cmds %d  attacks %d  time %.2f s  (%.1f us/cmd)" % [all.finish().hex_encode().substr(0, 16), n_cmds, n_attacks, dt / 1e6, float(dt) / maxi(1, n_cmds)])
	var r2: Variant = load("res://core/rules/rules.gd") if ResourceLoader.exists("res://core/rules/rules.gd") else null
	if r2 != null:
		print(r2.stats_line())
	quit()
