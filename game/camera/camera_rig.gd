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
## a normalised screen rect ("safe rect"). With `insets_source` set (the game does, via
## ScreenInsets.measure) the rects are rebuilt live from the actual HUD / tray rects, so the
## framing follows safe areas, the UI-size setting and HUD changes (passives, AUTO row).
## In a tall free area the overview looks down more steeply and the follow/home box grows
## in depth, so the board fills the height instead of leaving an empty band.

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
@export var combat_swing_portrait := 46.0
@export var combat_swing_landscape := 38.0
## Normalised screen rects the combat framing must fit into (the integration layer narrows
## them to the space left between the top HUD and the combat panel + dice tray).
@export var combat_rect_portrait := Rect2(0.07, 0.1, 0.86, 0.56)
@export var combat_rect_landscape := Rect2(0.18, 0.08, 0.64, 0.62)

## Optional live HUD measurement (ScreenInsets.measure-shaped Dictionary, canvas px). When
## set, the safe / combat rects are rebuilt from it whenever the HUD or the view changes,
## so the framing always fits the space the UI actually leaves (safe areas, UI size).
var insets_source: Callable
var camera: Camera3D
var mode := Mode.OVERVIEW

var _bounds := AABB(Vector3(-7.4, 0, -7.4), Vector3(14.8, 1.8, 14.8))
var _follow_target: Node3D
## Follow framing radius multiplier (1 = close hop-by-hop follow, >1 = "home" framing).
var _follow_wide := 1.0
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
var _defaults: Array[Rect2] = []
var _insets_key := ""
## Cached fill search (follow box depth factor / overview pitch) for the current layout.
var _fill_key := ""
var _fill_val := 1.0


func _init() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = fov
	camera.near = 0.3
	camera.far = 200.0
	add_child(camera)


func _ready() -> void:
	_defaults = [safe_rect_portrait, safe_rect_landscape, combat_rect_portrait, combat_rect_landscape]
	camera.fov = fov
	camera.current = true
	get_viewport().size_changed.connect(_on_resize)
	_recompute()
	_current = _desired
	_apply(Vector3.ZERO, Vector3.ZERO)


func _on_resize() -> void:
	_poll_insets()
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
	_follow_wide = 1.0
	mode = Mode.FOLLOW
	_begin(instant)


## Resting board framing (between turns): the whole ring always fits, leaning toward the
## hero's side; steeper on tall screens so the ring fills the free area.
func home(target: Node3D, instant := false) -> void:
	_follow_target = target
	_follow_wide = 1.75
	mode = Mode.FOLLOW
	_begin(instant)


## Yaw (radians) of the current framing (e.g. the fight's yaw right after combat()).
func combat_yaw() -> float:
	return _yaw


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


# --- HUD-aware rects -------------------------------------------------------------------

## Rebuilds the framing rects from insets_source; true when they changed.
func _poll_insets() -> bool:
	if not insets_source.is_valid():
		return false
	var d: Dictionary = insets_source.call()
	var key := str(d)
	if key == _insets_key:
		return false
	_insets_key = key
	if d.is_empty():
		if _defaults.size() == 4:
			safe_rect_portrait = _defaults[0]
			safe_rect_landscape = _defaults[1]
			combat_rect_portrait = _defaults[2]
			combat_rect_landscape = _defaults[3]
		return true
	var v: Vector2 = d.view
	if v.x <= 0.0 or v.y <= 0.0:
		return false
	var top := float(d.top) / v.y
	var l := float(d.left) / v.x
	var r := float(d.right) / v.x
	# portrait: the whole width (the board is width-bound); landscape: keep the far sides
	# free (floating island edges) - the board reads better centred
	var side_p := maxf(0.03, l)
	var side_l := maxf(0.1, maxf(l, r) + 0.02)
	safe_rect_portrait = _rect(side_p, top, 1.0 - side_p - maxf(0.03, r), float(d.board_bottom) / v.y)
	safe_rect_landscape = _rect(side_l, top, 1.0 - side_l * 2.0, float(d.board_bottom) / v.y)
	combat_rect_portrait = _rect(maxf(0.05, l), top, 1.0 - maxf(0.05, l) - maxf(0.05, r), float(d.combat_bottom) / v.y)
	combat_rect_landscape = _rect(side_l, top, 1.0 - side_l * 2.0, float(d.combat_bottom) / v.y)
	return true


static func _rect(x: float, top: float, w: float, bottom: float) -> Rect2:
	return Rect2(x, top, w, maxf(bottom - top, 0.25))


# --- update -------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_t += dt
	if _poll_insets() and mode != Mode.FOLLOW:
		_recompute()
	if mode == Mode.FOLLOW and _follow_target and is_instance_valid(_follow_target):
		_recompute()
	elif mode == Mode.FOLLOW and _follow_target != null:
		_follow_target = null
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
	var rect := safe_rect()
	if mode == Mode.COMBAT:
		rect = combat_rect_portrait if portrait else combat_rect_landscape
	var view := _viewport_size()
	var pts := PackedVector3Array()
	match mode:
		Mode.OVERVIEW:
			_yaw = 0.0
			_pitch = 56.0 if portrait else 50.0
			for i in 8:
				pts.append(_bounds.get_endpoint(i))
			if portrait:
				# a tall free area leaves a band under a width-bound board: look down more
				# steeply (up to 72°) until the ring fills the height too
				var key := "o|%s|%s|%s" % [rect, view, _bounds]
				if key != _fill_key:
					_fill_key = key
					_fill_val = _search_fill(func(p: float) -> Array: return [pts, p], 56.0, 72.0, rect, view)
				_pitch = _fill_val
		Mode.FOLLOW:
			_yaw = 0.0
			_pitch = 50.0 if portrait else 44.0
			var c := _follow_target.global_position if _follow_target and is_instance_valid(_follow_target) else Vector3.ZERO
			var r := (3.6 if portrait else 3.4) * _follow_wide
			if _follow_wide > 1.0:
				_pitch = 54.0 if portrait else 48.0
				# home view: lean toward the board centre so the ring ahead is in view, not
				# the empty island edge behind the hero
				var bc0 := _bounds.get_center()
				c = c.lerp(Vector3(bc0.x, c.y, bc0.z), 0.38)

			# on the far side of the ring look down more steeply, over the centre set piece
			var bc := _bounds.get_center()
			var far := clampf((bc.z - c.z) / maxf(_bounds.size.z * 0.5, 0.1), 0.0, 1.0)
			_pitch += 12.0 * far
			if _follow_wide > 1.0:
				# home: the whole ring always fits (every aspect, 0.46 .. 2.4), plus the box
				# around the hero; on a tall free area look down more steeply to fill it
				var hp := _follow_box(c, r * 0.5, 0.8)
				for i in 8:
					hp.append(_bounds.get_endpoint(i))
				pts = hp
				if portrait:
					var hkey := "h|%s|%s|%s|%d" % [rect, view, _bounds, int(_pitch * 4.0)]
					if hkey != _fill_key:
						_fill_key = hkey
						var p1 := _pitch
						_fill_val = _search_fill(func(p: float) -> Array: return [hp, p], p1, maxf(p1, 72.0), rect, view)
					_pitch = _fill_val
				_desired = solve_framing(pts, _yaw, deg_to_rad(_pitch), rect, view, camera.fov)
				return
			# the framed box's depth grows (0.8r .. 1.7r) until it fills a tall free area,
			# so phones show more of the ring instead of an empty band
			var key := "f|%s|%s|%d|%.2f" % [rect, view, int(_pitch * 4.0), _follow_wide]
			if key != _fill_key:
				_fill_key = key
				var p0 := _pitch
				_fill_val = _search_fill(func(k: float) -> Array: return [_follow_box(Vector3.ZERO, r, k), p0], 0.8, 1.7, rect, view)
			pts = _follow_box(c, r, _fill_val)
		Mode.COMBAT:
			_pitch = 36.0 if portrait else 30.0
			pts = _points
		Mode.POINTS:
			pts = _points
	if pts.is_empty():
		return
	_desired = solve_framing(pts, _yaw, deg_to_rad(_pitch), rect, view, camera.fov)


static func _follow_box(c: Vector3, r: float, zk: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			pts.append(c + Vector3(x * r, 0.0, z * r * zk))
			pts.append(c + Vector3(x * r, 1.6, z * r * zk))
	return pts


## Smallest parameter in [lo, hi] (searched by bisection) whose framing fills the rect's
## height as well as its width. `build(param)` returns [points, pitch_deg]. Returns hi when
## even hi leaves vertical slack, lo when lo is already height-bound.
func _search_fill(build: Callable, lo: float, hi: float, rect: Rect2, view: Vector2) -> float:
	if _fill_h(build.call(lo), rect, view) >= 0.985:
		return lo
	if _fill_h(build.call(hi), rect, view) < 0.985:
		return hi
	for i in 7:
		var mid := (lo + hi) * 0.5
		if _fill_h(build.call(mid), rect, view) >= 0.985:
			hi = mid
		else:
			lo = mid
	return hi


func _fill_h(spec: Array, rect: Rect2, view: Vector2) -> float:
	var pts: PackedVector3Array = spec[0]
	var xf := solve_framing(pts, _yaw, deg_to_rad(float(spec[1])), rect, view, camera.fov)
	return framing_fill(pts, xf, rect, view, camera.fov).y


## Fraction (x, y) of `rect` that `points` span on screen through camera transform `xf`.
static func framing_fill(points: PackedVector3Array, xf: Transform3D, rect: Rect2, size: Vector2,
		fov_deg: float) -> Vector2:
	var ty := tan(deg_to_rad(fov_deg) * 0.5)
	var tx := ty * size.x / maxf(size.y, 1.0)
	var inv := xf.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		var v := inv * p
		var depth := maxf(-v.z, 0.01)
		var n := Vector2(v.x / (depth * tx), v.y / (depth * ty))
		lo = lo.min(n)
		hi = hi.max(n)
	return Vector2((hi.x - lo.x) / maxf(rect.size.x * 2.0, 1e-4), (hi.y - lo.y) / maxf(rect.size.y * 2.0, 1e-4))


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
