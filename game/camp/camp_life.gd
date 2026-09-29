class_name CampLife
extends Node
## Camp life: the unlocked classes (and the roaming pets) go about their evening. Each camper
## cycles through activities, walking between spots on a small nav graph: a ring path around
## the fire with spokes out to the spots, so nobody walks through the fire, a station or the
## decorations. Spots are reserved, so two campers never stand in the same place.
##   sit by the fire · spar in pairs (attack / block / hit, facing each other) or at the dummy ·
##   tinker at the Workshop · look over the weapons at the Armory · tend the pets at the Den ·
##   cheer at the Arcade · chat in pairs (gestures and emote bubbles) · nap by the fire
## Pets follow a favourite camper, wander the ring and hop near the fire.
## Deterministic enough to screenshot: one seeded Rng drives every choice; only the frame
## timing varies. `paused` freezes decisions (a Camp screen is open over the scene).

const WALK_SPEED := 1.7
## Ring path radius around the fire (outside the logs, inside the decorations).
const RING := 3.35
const ACTS := {
	"sit": {"weight": 4, "dur": [9.0, 15.0], "clip": "Sit_Chair_Idle"},
	"spar": {"weight": 3, "dur": [8.0, 12.0], "clip": "idle", "pair": true},
	"dummy": {"weight": 2, "dur": [6.0, 9.0], "clip": "idle"},
	"tinker": {"weight": 2, "dur": [6.0, 10.0], "clip": "Lockpicking", "station": "workshop"},
	"inspect": {"weight": 2, "dur": [5.0, 8.0], "clip": "idle_b", "station": "armory"},
	"pets": {"weight": 2, "dur": [6.0, 9.0], "clip": "Interact", "station": "pet_den"},
	"cheer": {"weight": 2, "dur": [4.0, 7.0], "clip": "Cheering", "station": "arcade"},
	"chat": {"weight": 3, "dur": [7.0, 11.0], "clip": "idle_b", "pair": true},
	"nap": {"weight": 1, "dur": [8.0, 12.0], "clip": "Lie_Idle"},
}
const BUBBLES := ["♪", "!", "...", "♥", "?", "ha!"]

var scene: Node3D
var fire := Vector3.ZERO
var paused := false
var agents: Array = []
var pets: Array = []
## spot name -> {pos, face (world point to look at), owner (agent or null), kind}
var spots: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _init(p_scene: Node3D, p_fire: Vector3) -> void:
	name = "CampLife"
	scene = p_scene
	fire = p_fire
	_rng.seed = 20260928


## Rebuilds the spot graph (layout / camp state changed). `stations` = {id: Node3D root} and
## `built` = {id: bool} (a ruined station has no work spot).
func set_spots(stations: Dictionary, built: Dictionary) -> void:
	for a in agents:
		a.spot = ""
	spots.clear()
	var seats := [Vector3(2.25, 0, 0.55), Vector3(0.15, 0, -2.3), Vector3(1.75, 0, -1.65)]
	for i in seats.size():
		_spot("seat%d" % i, fire + seats[i], fire, "sit")
	_spot("sparA", fire + Vector3(-5.2, 0, 3.0), fire + Vector3(-4.0, 0, 3.9), "spar")
	_spot("sparB", fire + Vector3(-4.0, 0, 3.9), fire + Vector3(-5.2, 0, 3.0), "spar")
	_spot("dummy", fire + Vector3(-5.9, 0, 4.5), fire + Vector3(-6.9, 0, 4.2), "dummy")
	_spot("chatA", fire + Vector3(-1.3, 0, 4.4), fire + Vector3(0.1, 0, 4.6), "chat")
	_spot("chatB", fire + Vector3(0.1, 0, 4.6), fire + Vector3(-1.3, 0, 4.4), "chat")
	_spot("chatC", fire + Vector3(3.9, 0, -2.0), fire + Vector3(4.7, 0, -1.0), "chat")
	_spot("chatD", fire + Vector3(4.7, 0, -1.0), fire + Vector3(3.9, 0, -2.0), "chat")
	_spot("nap", fire + Vector3(1.4, 0, 3.9), fire + Vector3(0, 0, 3.9), "nap")
	var acts := {"workshop": "tinker", "armory": "inspect", "pet_den": "pets", "arcade": "cheer"}
	for id in stations:
		if not bool(built.get(id, false)):
			continue
		var s: Node3D = stations[id]
		var front := s.global_transform * Vector3(0.9, 0, 1.55)
		_spot("work_" + String(id), front, s.global_position, String(acts[id]))


func _spot(n: String, pos: Vector3, face: Vector3, kind: String) -> void:
	spots[n] = {"pos": pos, "face": face, "owner": null, "kind": kind}


## A camper joins; `start` is the spot kind it begins at (so a still shot matches the old look).
func add_agent(ch: Character, start := "sit") -> void:
	var a := {"ch": ch, "state": "idle", "path": [], "spot": "", "act": "", "t": _rng.randf_range(0.5, 3.0),
		"partner": null, "gesture": _rng.randf_range(2.0, 5.0)}
	agents.append(a)
	var sp := _free_spot(start)
	if sp != "":
		_take(a, sp)
		ch.global_position = spots[sp].pos
		_begin(a, start, _rng.randf_range(4.0, 9.0))


func add_pet(node: Node3D, fav_index: int) -> void:
	pets.append({"node": node, "fav": fav_index, "target": node.global_position, "t": _rng.randf_range(1.0, 4.0),
		"hop": _rng.randf() * TAU})


func clear() -> void:
	agents.clear()
	pets.clear()


func _process(dt: float) -> void:
	_t += dt
	if paused:
		return
	for a in agents:
		if not is_instance_valid(a.ch):
			continue
		match String(a.state):
			"walk":
				_walk(a, dt)
			"act", "idle", "wait":
				a.t -= dt
				_gesture(a, dt)
				if a.t <= 0.0 and String(a.state) != "wait":
					_next(a)
	for p in pets:
		_pet(p, dt)


# ------------------------------------------------------------------ decisions

func _next(a: Dictionary) -> void:
	# a pair activity ends for both
	var partner: Variant = a.partner
	_release(a)
	if partner != null:
		_release(partner)
		partner.partner = null
		partner.t = _rng.randf_range(0.3, 1.2)
		partner.state = "idle"
	a.partner = null
	var choices: Array = []
	var total := 0
	for k in ACTS:
		if k == String(a.act):
			continue
		if not _available(String(k)):
			continue
		choices.append(k)
		total += int(ACTS[k].weight)
	if choices.is_empty():
		a.t = 2.0
		return
	var roll := _rng.randi_range(0, total - 1)
	var pick := String(choices[0])
	for k in choices:
		roll -= int(ACTS[k].weight)
		if roll < 0:
			pick = String(k)
			break
	if bool(ACTS[pick].get("pair", false)):
		var mate: Variant = _find_mate(a)
		if mate == null:
			pick = "sit" if _available("sit") else "dummy"
		else:
			var ab := _pair_spots(pick)
			_release(mate)
			a.partner = mate
			mate.partner = a
			_go(a, ab[0], pick)
			_go(mate, ab[1], pick)
			return
	var sp := _free_spot(_kind_of(pick))
	if sp == "":
		a.t = 1.5
		return
	_go(a, sp, pick)


func _available(act: String) -> bool:
	match act:
		"spar":
			return _free_spot("spar") != "" and spots.has("sparA") and spots.sparA.owner == null and spots.sparB.owner == null and agents.size() > 1
		"chat":
			return agents.size() > 1 and (_pair_spots("chat").size() == 2)
	return _free_spot(_kind_of(act)) != ""


func _kind_of(act: String) -> String:
	return {"tinker": "tinker", "inspect": "inspect", "pets": "pets", "cheer": "cheer"}.get(act, act)


func _pair_spots(act: String) -> Array:
	if act == "spar":
		return ["sparA", "sparB"] if spots.has("sparA") and spots.sparA.owner == null and spots.sparB.owner == null else []
	for pair in [["chatA", "chatB"], ["chatC", "chatD"]]:
		if spots.has(pair[0]) and spots[pair[0]].owner == null and spots[pair[1]].owner == null:
			return pair
	return []


## Another camper free to join (sitting / idling, not walking, not paired).
func _find_mate(a: Dictionary) -> Variant:
	var best: Variant = null
	for b in agents:
		if b == a or b.partner != null or String(b.state) == "walk":
			continue
		if String(b.act) in ["sit", "dummy", "nap", "", "cheer", "inspect"]:
			best = b
			break
	return best


func _free_spot(kind: String) -> String:
	var names := spots.keys()
	names.sort()
	var free: Array = []
	for n in names:
		if String(spots[n].kind) == kind and spots[n].owner == null:
			free.append(n)
	if free.is_empty():
		return ""
	return String(free[_rng.randi_range(0, free.size() - 1)])


func _take(a: Dictionary, sp: String) -> void:
	spots[sp].owner = a
	a.spot = sp


func _release(a: Dictionary) -> void:
	var sp := String(a.spot)
	if spots.has(sp) and spots[sp].owner == a:
		spots[sp].owner = null
	a.spot = ""


# ------------------------------------------------------------------ walking

func _go(a: Dictionary, sp: String, act: String) -> void:
	_release(a)
	_take(a, sp)
	a.act = act
	a.path = _route(a.ch.global_position, spots[sp].pos)
	a.state = "walk"
	a.ch.play("walk", 0.2)


## Ring-and-spokes route: out to the ring, around it (never through the fire), in to the spot.
func _route(from: Vector3, to: Vector3) -> Array:
	var f := Vector2(from.x - fire.x, from.z - fire.z)
	var t := Vector2(to.x - fire.x, to.z - fire.z)
	if f.length() < 0.01:
		f = Vector2(0, 1)
	var a0 := f.angle()
	var a1 := t.angle()
	var d := wrapf(a1 - a0, -PI, PI)
	var out: Array = []
	out.append(fire + Vector3(cos(a0) * RING, 0, sin(a0) * RING))
	var steps := int(ceil(absf(d) / deg_to_rad(20.0)))
	for i in range(1, steps):
		var ang := a0 + d * float(i) / float(steps)
		out.append(fire + Vector3(cos(ang) * RING, 0, sin(ang) * RING))
	out.append(fire + Vector3(cos(a1) * RING, 0, sin(a1) * RING))
	out.append(to)
	# skip ring points that would walk backwards from a spot already outside the ring
	if f.length() > RING + 0.5 and t.length() > RING + 0.5 and (to - from).length() < 2.2:
		return [to]
	return out


func _walk(a: Dictionary, dt: float) -> void:
	var ch: Character = a.ch
	if (a.path as Array).is_empty():
		_arrive(a)
		return
	var target: Vector3 = a.path[0]
	var pos := ch.global_position
	var to := Vector3(target.x - pos.x, 0, target.z - pos.z)
	var dist := to.length()
	# simple avoidance: wait a beat if another walker is right ahead
	for b in agents:
		if b != a and String(b.state) == "walk" and is_instance_valid(b.ch):
			var off: Vector3 = b.ch.global_position - pos
			if off.length() < 0.7 and off.dot(to) > 0.0 and agents.find(b) < agents.find(a):
				return
	var step := WALK_SPEED * dt
	if dist <= step:
		ch.global_position = Vector3(target.x, pos.y, target.z)
		(a.path as Array).pop_front()
	else:
		ch.global_position = pos + to / dist * step
	if dist > 0.05:
		ch.rotation.y = lerp_angle(ch.rotation.y, atan2(to.x, to.z), minf(1.0, dt * 10.0))


func _arrive(a: Dictionary) -> void:
	var sp: Dictionary = spots.get(String(a.spot), {})
	if sp.is_empty():
		a.state = "idle"
		a.t = 1.0
		return
	var face: Vector3 = sp.face
	var ch: Character = a.ch
	ch.rotation.y = atan2(face.x - ch.global_position.x, face.z - ch.global_position.z)
	var partner: Variant = a.partner
	if partner != null and String(partner.state) == "walk":
		# wait for the partner to arrive, then both start together
		a.state = "wait"
		ch.play("idle", 0.2)
		return
	var dur := _rng.randf_range(float(ACTS[a.act].dur[0]), float(ACTS[a.act].dur[1]))
	_begin(a, String(a.act), dur)
	if partner != null:
		_begin(partner, String(a.act), dur)


func _begin(a: Dictionary, act: String, dur: float) -> void:
	a.act = act
	a.state = "act"
	a.t = dur
	a.gesture = _rng.randf_range(0.8, 2.0)
	var ch: Character = a.ch
	var clip := String(ACTS[act].clip) if ACTS.has(act) else "idle"
	if ch.has_anim(clip):
		ch.play(clip, 0.25)
	else:
		ch.play("idle", 0.25)


# ------------------------------------------------------------------ gestures & interactions

func _gesture(a: Dictionary, dt: float) -> void:
	if String(a.state) != "act":
		return
	a.gesture -= dt
	if a.gesture > 0.0:
		return
	var ch: Character = a.ch
	match String(a.act):
		"spar":
			# alternate: one swings, the other blocks (or takes the hit)
			var mate: Variant = a.partner
			a.gesture = 1.6
			if mate != null and agents.find(a) < agents.find(mate):
				var swing_first := int(_t / 1.6) % 2 == 0
				var att: Dictionary = a if swing_first else mate
				var def: Dictionary = mate if swing_first else a
				att.ch.play_once("attack", "idle")
				def.ch.play_once("block" if _rng.randf() < 0.7 else "hit", "idle")
		"dummy":
			a.gesture = 1.9
			ch.play_once("attack", "idle")
		"chat":
			a.gesture = _rng.randf_range(2.0, 3.5)
			if _rng.randf() < 0.5 and ch.has_anim("Waving"):
				ch.play_once("Waving", "Idle_B")
			_bubble(ch, String(BUBBLES[_rng.randi_range(0, BUBBLES.size() - 1)]))
		"inspect":
			a.gesture = 3.0
			if ch.has_anim("Use_Item"):
				ch.play_once("Use_Item", "Idle_B")
		"pets":
			a.gesture = 3.2
			_bubble(ch, "♥")
		"sit":
			a.gesture = _rng.randf_range(5.0, 9.0)
			if _rng.randf() < 0.35:
				_bubble(ch, "♪")
		_:
			a.gesture = 4.0


## A little emote bubble that floats up over a character and fades.
func _bubble(ch: Character, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Props.font(true)
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 14
	l.outline_modulate = Color(0.1, 0.07, 0.15)
	l.modulate = Color(1.0, 0.95, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = ch.global_position + Vector3.UP * 2.6
	scene.add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y + 0.6, 1.4)
	t.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.6)
	t.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------------ pets

func _pet(p: Dictionary, dt: float) -> void:
	var n: Node3D = p.node
	if not is_instance_valid(n):
		return
	p.t -= dt
	var fav: Variant = agents[int(p.fav) % agents.size()] if not agents.is_empty() else null
	var target: Vector3 = p.target
	if fav != null and is_instance_valid(fav.ch) and String(fav.state) == "walk":
		# trot after the favourite camper
		var back: Vector3 = fav.ch.global_transform.basis.z * -0.9
		target = fav.ch.global_position + back + Vector3(0.5, 0, 0)
	elif p.t <= 0.0:
		p.t = _rng.randf_range(3.0, 6.0)
		if fav != null and is_instance_valid(fav.ch) and _rng.randf() < 0.6:
			target = fav.ch.global_position + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(0.6, 1.2))
		else:
			var ang := _rng.randf() * TAU
			target = fire + Vector3(cos(ang), 0, sin(ang)) * (RING + _rng.randf_range(-0.3, 0.6))
		p.target = target
	var to := target - n.global_position
	to.y = 0.0
	if to.length() > 0.08:
		n.global_position += to.normalized() * minf(to.length(), 1.9 * dt)
	# hop near the fire
	if not (n is PetView):
		p.hop += dt * 7.0
		var near := fire.distance_to(n.global_position) < RING + 1.0
		n.position.y = absf(sin(p.hop)) * (0.3 if near else 0.12)
