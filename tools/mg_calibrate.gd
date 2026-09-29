extends SceneTree
## Minigame calibration (balance.md "Minigame calibration"): plays every minigame N times with a
## human-like player (its own RandomNumberGenerator for the human noise; the game itself stays
## deterministic from its seed) and prints median / quartiles / mean, the tier shares at the
## current MinigameDefs.MEDIAN and the expected reward value (review §5.4 parity: every game
## within ±10% of the mean at median play).
##   godot --headless --path . -s tools/mg_calibrate.gd -- [--n=3000] [--game=<id>] [--policy=human|expert|random]

## Reward value per tier in gold equivalents (bronze 12 gold, silver 25 gold, gold ~ rune of
## choice / potion + 20 gold / the signature); gold rewards scale with the skill band.
const TIER_VALUE := {"bronze": 12.0, "silver": 25.0, "gold": 45.0}

## Seconds per action at 1x for a typical player (think + the screen's animation), for the
## duration estimate (actions/play x this). Estimates from the screens' timings.
const SECS_PER_ACTION := {"fossil_hunter": 2.0, "bubble_breaker": 4.5, "scratch_off": 3.0, "claw_machine": 6.0,
	"bubble_shooter": 2.6, "plinko": 5.0, "shell_game": 6.5, "memory_match": 1.3, "fishing": 3.0, "lucky_wheel": 3.3,
	"high_low": 2.8}

var policy := "human"
## --measured: tiers at the measured median instead of MinigameDefs.MEDIAN (to pick MEDIAN).
var auto_med := false
var hist := false


func _init() -> void:
	var n := 3000
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = a.substr(4).to_int()
		elif a.begins_with("--game="):
			only = a.substr(7)
		elif a == "--hist":
			hist = true
		elif a == "--measured":
			auto_med = true
		elif a.begins_with("--policy="):
			policy = a.substr(9)
	var hp := MgHuman.new(12345, policy)
	var evs := {}
	print("game            median  q25  q75   mean   bronze silver gold   E[value]  (policy %s, n=%d)" % [policy, n])
	for id in MinigameDefs.IDS:
		if only != "" and id != only:
			continue
		var scores: Array = []
		var actions := 0
		for s in n:
			var m := Minigames.create(id, 7000 + s * 13, 1)
			actions += hp.play(m)
			scores.append(m.score())
		scores.sort()
		var med := float(MinigameDefs.MEDIAN[id]) if not auto_med else _q(scores, 0.5)
		var tiers := {"bronze": 0, "silver": 0, "gold": 0}
		var ev := 0.0
		var mean := 0.0
		for sc in scores:
			var r := float(sc) / med
			var t := MinigameDefs.tier_for(r)
			tiers[t] += 1
			ev += TIER_VALUE[t] * (MinigameDefs.skill_mult(r, id) if t == "gold" else 1.0)
			mean += float(sc)
		ev /= n
		mean /= n
		evs[id] = ev
		if hist:
			var c := {}
			for sc in scores:
				c[int(sc)] = int(c.get(int(sc), 0)) + 1
			var line := ""
			for k in c:
				line += "%d:%.1f%% " % [k, 100.0 * c[k] / n]
			print("   hist " + line)
		var apg := float(actions) / n
		print("%-15s %6.1f %4.0f %4.0f %6.2f   %5.1f%% %5.1f%% %5.1f%%   %6.2f   actions/play %.1f  est %.0f s  median/MEDIAN %.2f  mean/MEDIAN %.2f" % [id,
			_q(scores, 0.5), _q(scores, 0.25), _q(scores, 0.75), mean, 100.0 * tiers.bronze / n, 100.0 * tiers.silver / n,
			100.0 * tiers.gold / n, ev, apg, apg * float(SECS_PER_ACTION.get(id, 3.0)), _q(scores, 0.5) / float(MinigameDefs.MEDIAN[id]),
			mean / float(MinigameDefs.MEDIAN[id])])
	if evs.size() > 1:
		var avg := 0.0
		for k in evs:
			avg += float(evs[k])
		avg /= evs.size()
		for k in evs:
			print("  parity %-15s %+5.1f%%" % [k, 100.0 * (float(evs[k]) / avg - 1.0)])
	quit()


static func _q(a: Array, q: float) -> float:
	return float(a[clampi(int(q * (a.size() - 1)), 0, a.size() - 1)])
