class_name LuckyWheel
extends Minigame
## Lucky Wheel: a prize wheel of SEGMENTS segments (a shuffled SEGMENT_VALUES layout, public).
## SPINS spins, each two actions:
##   ["spin"]       the minigame Rng picks the spin: duration, turns and where it would come to
##                  rest (public: the screen animates the exact curve angle_at()).
##   ["stop", t]    the one nudge: t = seconds after the spin started when the player tapped
##                  the brake (-1 = no tap). In the last NUDGE_WINDOW seconds the brake holds
##                  and the wheel stops on the segment under the pointer at t; earlier taps
##                  slip (too fast) and the wheel coasts to its natural stop. Mostly luck: the
##                  window only covers the last two or three segments.
## Angles are in degrees; the pointer is at the top and reads segment floor(angle / SEG_DEG)
## (angle mod 360, segments laid out clockwise from the pointer). Score = the segments won.
## actions_left = spins left (spent by the stop).
## Public: {segments, angle (rest angle), phase "spin" | "spinning", spin {from, total, dur,
##          window} (while spinning), results [{segment, value, nudged, t}]}.
## Info: spin {spin: true, from, total, dur, window}; stop {stop: true, t, nudged, angle,
##          segment, value, natural (the segment it would have coasted to)}.

const SEGMENTS := 12
const SEG_DEG := 30.0
const SPINS := 3
const SEGMENT_VALUES := [2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 9, 12]
const NUDGE_WINDOW := 1.1
const DUR := [4.2, 5.0]
const TURNS := [3, 4]

var segments: Array[int] = []
var angle := 0.0
var phase := "spin"
var spin: Dictionary = {}
var results: Array[Dictionary] = []

func _init() -> void:
	id = "lucky_wheel"

func _setup() -> void:
	actions_left = SPINS
	var vals: Array = SEGMENT_VALUES.duplicate()
	rng.shuffle(vals)
	segments.clear()
	for v in vals:
		segments.append(int(v))
	angle = snappedf(rng.randf() * 360.0, 0.01)
	phase = "spin"
	spin = {}
	results.clear()

## Wheel angle t seconds into a spin (ease-out: the wheel decelerates evenly to rest at dur).
static func angle_at(sp: Dictionary, t: float) -> float:
	var d := float(sp.dur)
	var k := clampf(t / d, 0.0, 1.0)
	return float(sp.from) + float(sp.total) * (1.0 - (1.0 - k) * (1.0 - k))

static func segment_at(a: float) -> int:
	return int(floor(fposmod(a, 360.0) / SEG_DEG)) % SEGMENTS

## Segments the pointer passes during the nudge window, in order (bot / hints).
static func window_segments(sp: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var d := float(sp.dur)
	var steps := 40
	for k in steps + 1:
		var s := segment_at(angle_at(sp, d - float(sp.window) + float(sp.window) * k / steps))
		if out.is_empty() or out.back() != s:
			out.append(s)
	return out

func _action(args: Array) -> Dictionary:
	if args.is_empty():
		return {"error": "wheel needs [\"spin\"] or [\"stop\", t]"}
	match String(args[0]):
		"spin":
			if phase != "spin":
				return {"error": "already spinning"}
			var dur := snappedf(lerpf(float(DUR[0]), float(DUR[1]), rng.randf()), 0.01)
			var turns := rng.randi_range(int(TURNS[0]), int(TURNS[1]))
			var target := rng.randi_range(0, SEGMENTS - 1)
			var rest := (target + lerpf(0.12, 0.88, rng.randf())) * SEG_DEG
			var total := snappedf(turns * 360.0 + fposmod(rest - angle, 360.0), 0.01)
			spin = {"from": angle, "total": total, "dur": dur, "window": NUDGE_WINDOW}
			phase = "spinning"
			var info := spin.duplicate()
			info["spin"] = true
			return {"info": info}
		"stop":
			if phase != "spinning" or args.size() < 2:
				return {"error": "spin first"}
			var t := snappedf(float(args[1]), 0.001)
			var d := float(spin.dur)
			var natural := segment_at(angle_at(spin, d))
			var nudged := t >= d - NUDGE_WINDOW and t <= d
			var a := angle_at(spin, t if nudged else d)
			angle = snappedf(fposmod(a, 360.0), 0.01)
			var seg := segment_at(angle)
			var r := {"segment": seg, "value": segments[seg], "nudged": nudged, "t": t}
			results.append(r)
			actions_left -= 1
			phase = "spin"
			spin = {}
			var info := r.duplicate()
			info.merge({"stop": true, "angle": angle, "natural": natural})
			return {"info": info}
	return {"error": "unknown wheel action"}

func score() -> float:
	var s := 0
	for r in results:
		s += int(r.value)
	return float(s)

## The best tap time for a spin: the middle of the pointer's stay on the richest segment the
## window passes (bot play). -1 when coasting is at least as good.
func best_stop(sp: Dictionary) -> float:
	return best_stop_for(segments, sp)

## best_stop() on public data (the segment layout and the spin).
static func best_stop_for(segs: Array, sp: Dictionary) -> float:
	var d := float(sp.dur)
	var w := float(sp.window)
	var natural := segment_at(angle_at(sp, d))
	# runs of the pointer over segments during the window: [segment, from, to]
	var runs: Array = []
	var steps := 80
	for k in steps + 1:
		var t := d - w + w * k / steps
		var s := segment_at(angle_at(sp, t))
		if runs.is_empty() or int(runs.back()[0]) != s:
			runs.append([s, t, t])
		else:
			runs.back()[2] = t
	var best_t := -1.0
	var best_v := int(segs[natural])
	for r: Array in runs:
		# skip slivers the pointer only grazes (too short to hit by hand)
		if float(r[2]) - float(r[1]) < 0.06 or int(r[0]) == natural:
			continue
		if int(segs[int(r[0])]) > best_v:
			best_v = int(segs[int(r[0])])
			best_t = (float(r[1]) + float(r[2])) * 0.5
	return snappedf(best_t, 0.001)

func _public() -> Dictionary:
	return {"segments": Array(segments).duplicate(), "angle": angle, "phase": phase, "spin": spin.duplicate(),
		"results": results.duplicate(true)}

func _save() -> Dictionary:
	return {"segments": Array(segments), "angle": angle, "phase": phase, "spin": spin.duplicate(), "results": results.duplicate(true)}

func _load(d: Dictionary) -> void:
	segments = Minigame.ints(d.get("segments", []))
	angle = snappedf(float(d.get("angle", 0.0)), 0.01)
	phase = String(d.get("phase", "spin"))
	var sp: Dictionary = d.get("spin", {})
	spin = {} if sp.is_empty() else {"from": snappedf(float(sp.from), 0.01), "total": snappedf(float(sp.total), 0.01),
		"dur": snappedf(float(sp.dur), 0.01), "window": float(sp.window)}
	results.clear()
	for r in d.get("results", []):
		results.append({"segment": int(r.segment), "value": int(r.value), "nudged": bool(r.nudged), "t": snappedf(float(r.t), 0.001)})
