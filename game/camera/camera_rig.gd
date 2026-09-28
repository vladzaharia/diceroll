class_name CameraRig
extends Node3D
## Aspect-aware camera: overview (whole ring), follow (hero, damped) and combat (side 3/4),
## with smooth transitions and trauma-based shake.
##
##   var rig := CameraRig.new()
##   add_child(rig)
##   rig.overview(board.ring_bounds(), true)       # true = snap
##   rig.follow(board.hero)
##   rig.combat(hero_pos, [e1, e2, e3])
##   rig.shake(0.6, 0.4)
##
## Framing solves for the closest camera position that keeps a set of world points inside
## a normalised screen rect ("safe rect"), which by default reserves the bottom ~30% of a
## portrait screen (dice tray + HUD) and ~24% of a landscape one.

enum Mode { OVERVIEW, FOLLOW, COMBAT, POINTS }

## Normalised (0..1, top-left origin) screen rects the framed content must fit into.
@export var safe_rect_portrait := Rect2(0.035, 0.05, 0.93, 0.62)
@export var safe_rect_landscape := Rect2(0.14, 0.045, 0.72, 0.70)
@export var fov := 34.0
## Seconds-ish to settle after a mode change (exponential damping).
@export var smooth_time := 0.55
## Follow mode keeps following at this (faster) rate once settled.
@export var follow_smooth_time := 0.3
## Degrees the combat camera swings from a pure side view toward the hero's back
## (portrait needs a more over-the-shoulder view to fit the enemy row across the screen).
@export var combat_swing_portrait := 60.0
@export var combat_swing_landscape := 38.0

var camera: Camera3D
var mode := Mode.OVERVIEW

var _bounds := AABB(Vector3(-7.4, 0, -7.4), Vector3(14.8, 1.8, 14.8))
var _follow_target: Node3D
var _points: PackedVector3Array = PackedVector3Array()
var _yaw := 0.0
var _pitch := 52.0
var _desired := Transform3D.IDENTITY
var _current := Transform3D.IDENTITY
var _smooth := 0.55
var _trauma := 0.0
var _trauma_decay := 1.5
var _shake_strength := 0.0
var _t := 0.0
var _snap := true


func _init() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = fov
	camera.near = 0.3
	camera.far = 200.0
	add_child(camera)


func _ready() -> void:
	camera.fov = fov
	camera.current = true
	get_viewport().size_changed.connect(_on_resize)
	_recompute()
	_current = _desired
	_apply(Vector3.ZERO, Vector3.ZERO)


func _on_resize() -> void:
	_recompute()
	_current = _desired


# --- modes ------------------------------------------------------------------------------

## Frames the whole board AABB (use BoardView.ring_bounds()).
func overview(bounds := AABB(), instant := false) -> void:
	if bounds.size != Vector3.ZERO:
		_bounds = bounds
	mode = Mode.OVERVIEW
	_follow_target = null
	_begin(instant)


## Tracks a node (the hero) with a closer framing.
func follow(target: Node3D, instant := false) -> void:
	_follow_target = target
	mode = Mode.FOLLOW
	_begin(instant)


## Side 3/4 framing of the hero and enemies (world positions of their feet). The camera
## looks across the fight from the hero's side: hero lower-left, enemies to the right.
## `enemy_heights` (optional, per enemy) is how far above the feet the framing must reach
## (e.g. the top of a boss's HUD); default 2.4.
func combat(hero_pos: Vector3, enemy_positions: Array, instant := false, enemy_heights: Array = []) -> void:
	var pts := PackedVector3Array()
	var feet: Array[Vector3] = [hero_pos]
	var heights: Array[float] = [1.9]
	for i in enemy_positions.size():
		feet.append(enemy_positions[i])
		heights.append(float(enemy_heights[i]) if i < enemy_heights.size() else 2.4)
	for k in feet.size():
		var p: Vector3 = feet[k]
		for c in [Vector3(-0.9, 0, -0.9), Vector3(0.9, 0, -0.9), Vector3(-0.9, 0, 0.9), Vector3(0.9, 0, 0.9)]:
			pts.append(p + c)
		pts.append(p + Vector3.UP * heights[k])
	_points = pts
	var centre := Vector3.ZERO
	for e in enemy_positions:
		centre += e
	centre = centre / maxf(enemy_positions.size(), 1)
	var axis := centre - hero_pos
	axis.y = 0.0
	if axis.length() < 0.01:
		axis = Vector3.FORWARD
	axis = axis.normalized()
	var back := axis.cross(Vector3.UP)  # camera +Z for a pure side view (enemies to the right)
	back = back.rotated(Vector3.UP, deg_to_rad(-(combat_swing_portrait if is_portrait() else combat_swing_landscape)))
	_yaw = atan2(back.x, back.z)
	mode = Mode.COMBAT
	_follow_target = null
	_begin(instant)


## Frames arbitrary points at a given yaw/pitch (degrees).
func frame_points(points: PackedVector3Array, yaw_deg: float, pitch_deg: float, instant := false) -> void:
	_points = points
	_yaw = deg_to_rad(yaw_deg)
	_pitch = pitch_deg
	mode = Mode.POINTS
	_begin(instant)


## Adds camera shake. strength ~0.2 (tap) .. 1.0 (boss slam); duration in seconds.
func shake(strength := 0.5, duration := 0.35) -> void:
	_shake_strength = maxf(_shake_strength * _trauma, strength)
	_trauma = 1.0
	_trauma_decay = 1.0 / maxf(duration, 0.05)


## Current framing target transform (useful for tests and UI anchoring).
func desired_transform() -> Transform3D:
	return _desired


func _begin(instant: bool) -> void:
	_smooth = smooth_time
	_snap = instant
	_recompute()
	if instant:
		_current = _desired
		_apply(Vector3.ZERO, Vector3.ZERO)


# --- update -------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_t += dt
	if mode == Mode.FOLLOW and _follow_target and is_instance_valid(_follow_target):
		_recompute()
	var k := 1.0 - exp(-dt * 3.0 / maxf(_smooth, 0.01))
	var pos := _current.origin.lerp(_desired.origin, k)
	var q := Quaternion(_current.basis.orthonormalized()).slerp(Quaternion(_desired.basis.orthonormalized()), k)
	_current = Transform3D(Basis(q), pos)
	if mode == Mode.FOLLOW and _current.origin.distance_to(_desired.origin) < 0.5:
		_smooth = move_toward(_smooth, follow_smooth_time, dt)
	var off := Vector3.ZERO
	var rot := Vector3.ZERO
	if _trauma > 0.0:
		_trauma = maxf(_trauma - dt * _trauma_decay, 0.0)
		var a := _trauma * _trauma * _shake_strength
		off = Vector3(_noise(1.0), _noise(2.0), _noise(3.0)) * a * 0.35
		rot = Vector3(_noise(4.0), _noise(5.0), _noise(6.0)) * a * 0.025
	_apply(off, rot)


func _apply(off: Vector3, rot: Vector3) -> void:
	var b := _current.basis
	var shaken := b * Basis.from_euler(rot)
	camera.global_transform = Transform3D(shaken, _current.origin + b * off)


func _noise(seed: float) -> float:
	return sin(_t * 37.0 + seed * 11.3) * 0.6 + sin(_t * 23.0 + seed * 5.1) * 0.4


func _viewport_size() -> Vector2:
	if not is_inside_tree():
		return Vector2(720, 1280)
	return get_viewport().get_visible_rect().size


func is_portrait() -> bool:
	var s := _viewport_size()
	return s.y > s.x


func safe_rect() -> Rect2:
	return safe_rect_portrait if is_portrait() else safe_rect_landscape


func _recompute() -> void:
	var portrait := is_portrait()
	var pts := PackedVector3Array()
	match mode:
		Mode.OVERVIEW:
			_yaw = 0.0
			_pitch = 56.0 if portrait else 50.0
			for i in 8:
				pts.append(_bounds.get_endpoint(i))
		Mode.FOLLOW:
			_yaw = 0.0
			_pitch = 50.0 if portrait else 44.0
			var c := _follow_target.global_position if _follow_target else Vector3.ZERO
			var r := 3.6 if portrait else 3.4
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					pts.append(c + Vector3(x * r, 0.0, z * r * 0.8))
					pts.append(c + Vector3(x * r, 1.6, z * r * 0.8))
		Mode.COMBAT:
			_pitch = 36.0 if portrait else 30.0
			pts = _points
		Mode.POINTS:
			pts = _points
	if pts.is_empty():
		return
	var rect := safe_rect()
	if mode == Mode.COMBAT and portrait:
		rect = Rect2(0.07, 0.1, 0.86, 0.56)
	elif mode == Mode.COMBAT:
		rect = Rect2(0.18, 0.08, 0.64, 0.62)
	_desired = solve_framing(pts, _yaw, deg_to_rad(_pitch), rect, _viewport_size(), camera.fov)


## Closest camera transform (fixed yaw/pitch) that keeps every point inside `rect`
## (normalised, top-left origin) for a camera with vertical `fov_deg` and viewport `size`.
## Exact: for a fixed orientation the constraints are linear in (offset_x, offset_y, dist),
## so we binary-search the smallest feasible distance and centre the slack.
static func solve_framing(points: PackedVector3Array, yaw: float, pitch: float, rect: Rect2,
		size: Vector2, fov_deg: float) -> Transform3D:
	var basis := Basis.from_euler(Vector3(-pitch, yaw, 0.0))
	var right := basis.x
	var up := basis.y
	var back := basis.z
	var centre := Vector3.ZERO
	for p in points:
		centre += p
	centre /= float(points.size())
	var ty := tan(deg_to_rad(fov_deg) * 0.5)
	var tx := ty * size.x / maxf(size.y, 1.0)
	# screen ndc bounds (x right, y up) from the rect
	var sx0 := rect.position.x * 2.0 - 1.0
	var sx1 := rect.end.x * 2.0 - 1.0
	var sy0 := 1.0 - rect.end.y * 2.0
	var sy1 := 1.0 - rect.position.y * 2.0
	var q := []
	for p in points:
		var v := p - centre
		q.append(Vector3(v.dot(right), v.dot(up), v.dot(back)))
	var lo := 0.5
	var hi := 400.0
	for it in 48:
		var mid := (lo + hi) * 0.5
		if _feasible(q, mid, tx, ty, sx0, sx1, sy0, sy1).x > 0.5:
			hi = mid
		else:
			lo = mid
	var sol := _feasible(q, hi, tx, ty, sx0, sx1, sy0, sy1)
	var origin := centre + right * sol.y + up * sol.z + back * hi
	return Transform3D(basis, origin)


## Returns Vector3(feasible 1/0, offset_x, offset_y) for camera distance d.
static func _feasible(q: Array, d: float, tx: float, ty: float, sx0: float, sx1: float,
		sy0: float, sy1: float) -> Vector3:
	var ox_lo := -INF
	var ox_hi := INF
	var oy_lo := -INF
	var oy_hi := INF
	for v: Vector3 in q:
		var depth := d - v.z
		if depth <= 0.05:
			return Vector3(0, 0, 0)
		# sx*depth*tx = v.x - ox  ->  ox in [v.x - sx1*depth*tx, v.x - sx0*depth*tx]
		ox_lo = maxf(ox_lo, v.x - sx1 * depth * tx)
		ox_hi = minf(ox_hi, v.x - sx0 * depth * tx)
		oy_lo = maxf(oy_lo, v.y - sy1 * depth * ty)
		oy_hi = minf(oy_hi, v.y - sy0 * depth * ty)
	if ox_lo > ox_hi or oy_lo > oy_hi:
		return Vector3(0, 0, 0)
	return Vector3(1, (ox_lo + ox_hi) * 0.5, (oy_lo + oy_hi) * 0.5)
