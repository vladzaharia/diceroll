class_name DieVisual
extends Node3D
## One die in the tray: rounded-cube body with the procedural die shader, a glow ring on
## the felt, optional curse chains, and a keyframe-free procedural tumble that always ends
## exactly on the requested face (no swaps, no snapping).
##
## Node layout:  DieVisual (at the floor, x/z only)
##                 Pivot (height)  > Squash (world-axis scale) > Body (orientation)
##                 Ring (on the felt)   Chains (follow Pivot, not its rotation)

signal landed(strength: float)

## Rune look: body, bevel/edge, pips, rim (emissive), metallic, roughness, clearcoat.
const RUNE_LOOKS := {
	"": [Color(0.96, 0.93, 0.85), Color(0.9, 0.82, 0.68), Color(0.08, 0.065, 0.06), Color(0, 0, 0), 0.0, 0.32, 0.65],
	"blade": [Color(0.8, 0.17, 0.14), Color(0.55, 0.08, 0.07), Color(0.99, 0.95, 0.88), Color(1.0, 0.35, 0.25), 0.0, 0.3, 0.6],
	"guard": [Color(0.22, 0.45, 0.85), Color(0.12, 0.26, 0.6), Color(0.99, 0.96, 0.9), Color(0.45, 0.72, 1.0), 0.0, 0.3, 0.6],
	"venom": [Color(0.28, 0.66, 0.3), Color(0.14, 0.4, 0.16), Color(0.98, 0.97, 0.88), Color(0.45, 1.0, 0.35), 0.0, 0.32, 0.6],
	"ember": [Color(0.97, 0.52, 0.15), Color(0.75, 0.26, 0.05), Color(0.2, 0.07, 0.02), Color(1.0, 0.55, 0.12), 0.0, 0.3, 0.6],
	"vampire": [Color(0.5, 0.05, 0.12), Color(0.28, 0.02, 0.06), Color(0.99, 0.93, 0.88), Color(1.0, 0.12, 0.25), 0.0, 0.26, 0.7],
	"lucky": [Color(0.97, 0.84, 0.36), Color(0.8, 0.6, 0.18), Color(0.1, 0.22, 0.08), Color(1.0, 0.86, 0.35), 0.0, 0.3, 0.6],
	"frost": [Color(0.78, 0.93, 0.99), Color(0.52, 0.77, 0.92), Color(0.06, 0.2, 0.42), Color(0.6, 0.93, 1.0), 0.0, 0.18, 0.85],
	"thunder": [Color(0.99, 0.88, 0.25), Color(0.85, 0.62, 0.08), Color(0.13, 0.1, 0.28), Color(1.0, 0.98, 0.45), 0.0, 0.3, 0.6],
	"echo": [Color(0.48, 0.3, 0.76), Color(0.28, 0.15, 0.5), Color(0.99, 0.96, 0.92), Color(0.78, 0.55, 1.0), 0.0, 0.28, 0.65],
	"heavy": [Color(0.5, 0.51, 0.54), Color(0.33, 0.34, 0.37), Color(0.97, 0.95, 0.9), Color(0.75, 0.78, 0.85), 0.2, 0.55, 0.2],
	"wild": [Color(0.97, 0.96, 0.99), Color(0.86, 0.84, 0.95), Color(0.1, 0.08, 0.14), Color(1, 1, 1), 0.0, 0.2, 0.8],
	"gilded": [Color(0.92, 0.68, 0.28), Color(0.7, 0.45, 0.14), Color(0.16, 0.08, 0.02), Color(1.0, 0.78, 0.35), 0.75, 0.3, 0.5],
}
const RIM_STRENGTH := 0.9
const MARK_LIFT := 0.34
const GLOW_COLOR := Color(1.0, 0.78, 0.35)
const LOCK_TINT := Color(0.46, 0.24, 0.68)

var faces := PackedInt32Array([1, 2, 3, 4, 5, 6])
var edited := PackedByteArray([0, 0, 0, 0, 0, 0])
var rune := ""

## Floor position the die rests at (x, 0, z); tray layout sets it.
var rest_pos := Vector3.ZERO
var rest_basis := Basis.IDENTITY
var marked := false
var locked := false
var hl_color := Color(1, 0.85, 0.4)
var hl_on := false

var pivot := Node3D.new()
var squash := Node3D.new()
var body := MeshInstance3D.new()
var ring := MeshInstance3D.new()
var chains := Node3D.new()
var mat: ShaderMaterial
var outline: ShaderMaterial
var ring_mat: ShaderMaterial

var _lift := 0.0
var _glow := 0.0
var _hl := 0.0
var _chain_scale := 0.0
var _time := 0.0
var _phase := 0.0

# Roll animation state.
var _rolling := false
var _t := 0.0
var _dur := 1.0
var _delay := 0.0
var _p0 := Vector3.ZERO
var _p1 := Vector3.ZERO
var _ctrl := Vector3.ZERO
var _q0 := Quaternion.IDENTITY
var _q1 := Quaternion.IDENTITY
var _spin_axis := Vector3.RIGHT
var _spin := TAU
var _wobble_axis := Vector3.RIGHT
var _h0 := 0.0
var _apex := 1.3
var _land_next := 0

const LANDS := [0.46, 0.68, 0.81]
const BOUNCE := [1.0, 0.3, 0.075]


func _init() -> void:
	name = "Die"
	add_child(pivot)
	pivot.add_child(squash)
	squash.add_child(body)
	body.mesh = DieMesh.get_mesh()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mat = ShaderMaterial.new()
	mat.shader = preload("res://game/dice/die.gdshader")
	outline = ShaderMaterial.new()
	outline.shader = preload("res://game/dice/die_outline.gdshader")
	outline.set_shader_parameter("color", GLOW_COLOR)
	outline.render_priority = -1
	mat.next_pass = outline
	body.material_override = mat
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.9, 1.9)
	ring.mesh = pm
	ring_mat = ShaderMaterial.new()
	ring_mat.shader = preload("res://game/dice/ring.gdshader")
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.012
	add_child(ring)
	add_child(chains)
	_build_chains()
	chains.scale = Vector3.ONE * 0.001
	chains.visible = false
	_phase = randf() * TAU
	mat.set_shader_parameter("time_offset", randf())
	pivot.position.y = 0.5


## Accepts a Dictionary or Object with faces / rune / edited.
func set_data(d: Variant) -> void:
	var f: Variant = d.get("faces") if d != null else null
	var r: Variant = d.get("rune") if d != null else null
	var e: Variant = d.get("edited") if d != null else null
	faces = PackedInt32Array([1, 2, 3, 4, 5, 6])
	if f != null:
		for i in mini(6, f.size()):
			faces[i] = clampi(int(f[i]), 1, 6)
	rune = String(r) if r != null else ""
	if not RUNE_LOOKS.has(rune):
		rune = ""
	edited = PackedByteArray([0, 0, 0, 0, 0, 0])
	if e != null:
		for i in mini(6, e.size()):
			edited[i] = 1 if e[i] else 0
	_apply_look()


func _apply_look() -> void:
	var look: Array = RUNE_LOOKS[rune]
	mat.set_shader_parameter("body_color", look[0])
	mat.set_shader_parameter("edge_color", look[1])
	mat.set_shader_parameter("pip_color", look[2])
	mat.set_shader_parameter("rim_color", look[3])
	mat.set_shader_parameter("rim_strength", 0.0 if rune == "" else RIM_STRENGTH)
	mat.set_shader_parameter("metallic", look[4])
	mat.set_shader_parameter("roughness", look[5])
	mat.set_shader_parameter("clearcoat", look[6])
	mat.set_shader_parameter("wild", 1.0 if rune == "wild" else 0.0)
	mat.set_shader_parameter("bevel", DieMesh.BEVEL)
	var fv := PackedFloat32Array()
	var fe := PackedFloat32Array()
	for i in 6:
		fv.append(float(faces[i]))
		fe.append(float(edited[i]))
	mat.set_shader_parameter("face_vals", fv)
	mat.set_shader_parameter("face_edit", fe)
	mat.set_shader_parameter("lock_tint", LOCK_TINT)


func _build_chains() -> void:
	var link_mat := StandardMaterial3D.new()
	link_mat.albedo_color = Color(0.3, 0.27, 0.34)
	link_mat.metallic = 0.9
	link_mat.roughness = 0.35
	link_mat.emission_enabled = true
	link_mat.emission = LOCK_TINT
	link_mat.emission_energy_multiplier = 0.35
	var torus := TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.085
	torus.rings = 12
	torus.ring_segments = 6
	var half := 0.6
	var per_side := 5
	for side in 4:
		for k in per_side:
			var t := (float(k) + 0.5) / per_side * 2.0 - 1.0
			var local := Vector3(t * half, 0.0, half)
			var rot := Basis(Vector3.UP, side * PI * 0.5)
			var link := MeshInstance3D.new()
			link.mesh = torus
			link.material_override = link_mat
			var along := rot * Vector3.RIGHT
			var outward := rot * Vector3.BACK
			var b: Basis
			if k % 2 == 0:
				b = Basis(along * 1.3, outward, along.cross(outward))
			else:
				b = Basis(along * 1.3, Vector3.UP, along.cross(Vector3.UP))
			link.transform = Transform3D(b, rot * local + Vector3(0.0, 0.04 * sin(float(k) * 1.7 + side), 0.0))
			chains.add_child(link)
	# Padlock on the front.
	var lock := Node3D.new()
	lock.position = Vector3(0.0, -0.08, half + 0.06)
	var body_m := BoxMesh.new()
	body_m.size = Vector3(0.24, 0.2, 0.08)
	var lb := MeshInstance3D.new()
	lb.mesh = body_m
	var lock_mat := StandardMaterial3D.new()
	lock_mat.albedo_color = Color(0.55, 0.36, 0.72)
	lock_mat.metallic = 0.8
	lock_mat.roughness = 0.3
	lock_mat.emission_enabled = true
	lock_mat.emission = Color(0.6, 0.3, 0.9)
	lock_mat.emission_energy_multiplier = 0.6
	lb.material_override = lock_mat
	lock.add_child(lb)
	var shackle := MeshInstance3D.new()
	var sm := TorusMesh.new()
	sm.inner_radius = 0.06
	sm.outer_radius = 0.09
	shackle.mesh = sm
	shackle.material_override = link_mat
	shackle.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	shackle.position = Vector3(0.0, 0.1, 0.0)
	lock.add_child(shackle)
	chains.add_child(lock)


func up_slot() -> int:
	return DieMesh.up_slot(body.global_basis if body.is_inside_tree() else body.basis)


func up_value() -> int:
	return faces[DieMesh.up_slot(body.basis)]


func is_rolling() -> bool:
	return _rolling


## Face slots that show `value` (empty if none).
func slots_for(value: int) -> Array[int]:
	var out: Array[int] = []
	for k in 6:
		if faces[k] == value:
			out.append(k)
	return out


## Picks the slot to show `value`; falls back to the closest value with a warning.
func pick_slot(value: int, rng: RandomNumberGenerator) -> int:
	var s := slots_for(value)
	if s.is_empty():
		push_warning("DieVisual: value %d not on faces %s, using closest" % [value, faces])
		var best := 0
		for k in 6:
			if absi(faces[k] - value) < absi(faces[best] - value):
				best = k
		return best
	return s[rng.randi_range(0, s.size() - 1)]


## Resting orientation showing `slot` up, square to the camera (tiny yaw jitter).
func target_basis(slot: int, rng: RandomNumberGenerator, from: Basis) -> Basis:
	var base := DieMesh.up_basis(slot)
	var yaw := rng.randf_range(-0.09, 0.09)
	if rune != "wild":
		# Pip layouts are symmetric under a half-turn: pick whichever is closer to `from`.
		var alt := Basis(Vector3.UP, PI) * base
		var q := from.get_rotation_quaternion()
		if absf(q.dot(alt.get_rotation_quaternion())) > absf(q.dot(base.get_rotation_quaternion())):
			base = alt
	return Basis(Vector3.UP, yaw) * base


## Instantly shows `value` (no animation).
func show_value(value: int, rng: RandomNumberGenerator) -> void:
	_rolling = false
	rest_basis = target_basis(pick_slot(value, rng), rng, body.basis)
	body.basis = rest_basis
	pivot.position = Vector3(0.0, 0.5 + _lift, 0.0)
	squash.scale = Vector3.ONE


## Starts a throw that ends at `end_pos` (floor x/z, relative to the tray) showing `value`.
func start_roll(value: int, end_pos: Vector3, rng: RandomNumberGenerator, delay: float, duration: float, drift: Vector3, apex: float) -> void:
	_p0 = position
	_h0 = pivot.position.y - DieMesh.support_down(body.basis)
	_q0 = body.basis.get_rotation_quaternion()
	var tb := target_basis(pick_slot(value, rng), rng, body.basis)
	# Pre-rotate the target by the tumble we'll unwind, so the unwinding lands exactly on it.
	_q1 = tb.get_rotation_quaternion()
	if _q0.dot(_q1) < 0.0:
		_q1 = -_q1
	_p1 = end_pos
	_ctrl = (_p0 + _p1) * 0.5 + drift
	var travel := _p1 - _ctrl
	travel.y = 0.0
	if travel.length() < 0.05:
		travel = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
	_spin_axis = travel.normalized().cross(Vector3.UP).normalized()
	_spin_axis = (_spin_axis + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.35, 0.35))).normalized()
	_spin = TAU * float(rng.randi_range(1, 2))
	_wobble_axis = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	_dur = maxf(duration, 0.05)
	_delay = delay
	_apex = apex
	_t = 0.0
	_land_next = 0
	_rolling = true
	rest_pos = end_pos
	rest_basis = tb


## Advances animation and state visuals. Returns true when a roll finished this frame.
func tick(dt: float, speed: float) -> bool:
	_time += dt
	var finished := false
	var in_air := 0.0
	if _rolling:
		if _delay > 0.0:
			_delay -= dt * speed
		else:
			_t += dt * speed
			var s := clampf(_t / _dur, 0.0, 1.0)
			_pose(s)
			in_air = 1.0 if s < LANDS[2] else 0.0
			while _land_next < LANDS.size() and s >= LANDS[_land_next]:
				landed.emit(BOUNCE[_land_next])
				_land_next += 1
			if s >= 1.0:
				_rolling = false
				finished = true
				position = rest_pos
				body.basis = rest_basis
				squash.scale = Vector3.ONE
	var k := 1.0 - exp(-dt * 12.0)
	var lift_target := MARK_LIFT if marked and not locked else 0.0
	_lift = lerpf(_lift, lift_target, k)
	if not _rolling:
		var bob := sin(_time * 2.6 + _phase) * 0.03 * (_lift / MARK_LIFT)
		pivot.position = Vector3(0.0, 0.5 + _lift + bob, 0.0)
	_glow = lerpf(_glow, 1.0 if marked and not locked else 0.0, k)
	var pulse := 0.75 + 0.25 * sin(_time * 5.0 + _phase)
	var hl_target := (0.55 + 0.45 * sin(_time * 7.0)) if hl_on else 0.0
	_hl = lerpf(_hl, hl_target, 1.0 - exp(-dt * 16.0))
	mat.set_shader_parameter("glow", _glow * 0.6 * pulse)
	outline.set_shader_parameter("strength", _glow * 0.9 * pulse + _hl * 0.8)
	outline.set_shader_parameter("color", GLOW_COLOR.lerp(hl_color, clampf(_hl * 2.0, 0.0, 1.0) if hl_on else 0.0))
	mat.set_shader_parameter("hl", _hl)
	mat.set_shader_parameter("hl_color", hl_color)
	mat.set_shader_parameter("locked", 1.0 if locked else 0.0)
	var ring_col := GLOW_COLOR.lerp(hl_color, 1.0 if hl_on else 0.0)
	ring_mat.set_shader_parameter("color", ring_col)
	ring_mat.set_shader_parameter("strength", maxf(_glow * pulse * 0.9, _hl * 1.1) * (1.0 - in_air * 0.7))
	ring.position = Vector3(pivot.position.x, 0.012, pivot.position.z)
	var chain_target := 1.0 if locked and not _rolling else 0.0
	_chain_scale = lerpf(_chain_scale, chain_target, 1.0 - exp(-dt * 14.0))
	chains.visible = _chain_scale > 0.02
	chains.position = pivot.position
	chains.scale = Vector3.ONE * maxf(_chain_scale, 0.001)
	return finished


func _pose(s: float) -> void:
	# Horizontal: quadratic Bezier start -> drift control -> end, easing out.
	var hs := clampf(s / LANDS[2], 0.0, 1.0)
	var e := 1.0 - pow(1.0 - hs, 2.0)
	var a := _p0.lerp(_ctrl, e)
	var b := _ctrl.lerp(_p1, e)
	var hp := a.lerp(b, e)
	# Height: launch arc then decaying bounces.
	var h := 0.0
	if s < LANDS[0]:
		var u := s / LANDS[0]
		# Anticipation dip in the first few percent, then a parabola from h0 to the floor.
		h = _h0 * (1.0 - u) + _apex * 4.0 * u * (1.0 - u) * (1.0 - 0.15 * (1.0 - u))
	elif s < LANDS[1]:
		var u := (s - LANDS[0]) / (LANDS[1] - LANDS[0])
		h = _apex * BOUNCE[1] * 4.0 * u * (1.0 - u)
	elif s < LANDS[2]:
		var u := (s - LANDS[1]) / (LANDS[2] - LANDS[1])
		h = _apex * BOUNCE[2] * 4.0 * u * (1.0 - u)
	# Rotation: unwind whole extra turns while blending toward the target.
	var g := 1.0 - pow(1.0 - clampf(s / 0.9, 0.0, 1.0), 2.6)
	var q := Quaternion(_spin_axis, _spin * (1.0 - g)) * _q0.slerp(_q1, g)
	if s > LANDS[1]:
		var w := (s - LANDS[1]) / (1.0 - LANDS[1])
		var ang := 0.13 * sin(w * PI * 3.0) * pow(1.0 - w, 2.0)
		q = Quaternion(_wobble_axis, ang) * q
	var bs := Basis(q.normalized())
	body.basis = bs
	# Squash on impacts (world-axis scale on the parent of the rotating body).
	var sq := 0.0
	for i in LANDS.size():
		var dtl: float = (s - LANDS[i]) / 0.035
		sq += BOUNCE[i] * 0.16 * exp(-dtl * dtl)
	if s < 0.08:
		sq += 0.07 * sin(s / 0.08 * PI)
	squash.scale = Vector3(1.0 + sq * 0.55, 1.0 - sq, 1.0 + sq * 0.55)
	var support := DieMesh.support_down(bs) * (1.0 - sq)
	position = Vector3(hp.x, 0.0, hp.z)
	pivot.position = Vector3(0.0, support + h, 0.0)
