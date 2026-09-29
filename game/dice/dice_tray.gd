class_name DiceTray
extends Control
## Bottom-of-screen dice tray: a 3D felt tray rendered in a SubViewport inside a walnut and
## gold frame. Dice are duck-typed (Dictionary or Object with `faces`, `rune`, `edited`).
##
##   tray.set_dice(run.dice)
##   tray.roll(values, [0, 1, 2]); await tray.settled
##   tray.die_pressed.connect(func(i): ...)
##
## `roll(values, indices)`: `values` is either one value per die in the pool (indexed by
## die index, e.g. CombatState.dice_values) or one value per entry of `indices`.

signal settled
signal die_pressed(idx: int)

const FRAME_PX := 13.0
const CORNER_PX := 26.0
const MIN_SPACING := 1.38
const MAX_SPACING := 1.9
const PITCH_DEG := 60.0
const FOV := 24.0

## Animation speed multiplier (game speed setting).
@export var speed_scale := 1.0
## Base throw duration in seconds at speed_scale 1.
@export var roll_duration := 1.05
## Play throw/land/select sounds through the Audio autoload.
@export var sfx_enabled := true

var dice: Array[DieVisual] = []
var interactive := true
## The Engineer's Clockwork Turret die: a 6th slot on a brass side stand at the right end of
## the row. Not part of `dice` (never picked, marked or cursed); null for other classes.
var turret: DieVisual = null
var _stand: Node3D = null
var _turret_label: Label = null
var _badge: Label = null
var _badge_icon: TextureRect = null

var _viewport := SubViewport.new()
var _view := TextureRect.new()
var _frame := ColorRect.new()
var _labels_root := Control.new()
var _labels: Array[Label] = []
var _camera := Camera3D.new()
var _dice_root := Node3D.new()
var _felt := MeshInstance3D.new()
var _felt_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _rolling := false
var _show_labels := false
var _spacing := MIN_SPACING
var _slots: Array[Vector3] = []
var _jitter: Array[Vector3] = []
var _last_land_ms := 0
var _land_count := 0
var _oversample := 1.0
var _half_w := 4.0
var _air := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	custom_minimum_size = Vector2(240, 180)
	_rng.randomize()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i(512, 256)
	_viewport.positional_shadow_atlas_size = 0
	add_child(_viewport)
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_view)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = preload("res://game/dice/frame.gdshader")
	_frame.material = fm
	add_child(_frame)
	_labels_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels_root)
	_build_world()
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.36, 0.5)
	sm.sky_horizon_color = Color(0.5, 0.42, 0.33)
	sm.ground_bottom_color = Color(0.08, 0.07, 0.06)
	sm.ground_horizon_color = Color(0.25, 0.2, 0.15)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.92, 0.8)
	key.light_energy = 1.35
	key.shadow_enabled = true
	key.shadow_blur = 1.6
	key.light_angular_distance = 2.5
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 40.0
	key.shadow_bias = 0.03
	_viewport.add_child(key)
	key.transform = Transform3D(Basis.looking_at(Vector3(0.5, -1.0, -0.4).normalized(), Vector3.UP), Vector3.ZERO)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.62, 0.72, 1.0)
	fill.light_energy = 0.3
	_viewport.add_child(fill)
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.8, -0.6, -0.3).normalized(), Vector3.UP), Vector3.ZERO)
	var back := DirectionalLight3D.new()
	back.light_color = Color(1.0, 0.85, 0.65)
	back.light_energy = 0.45
	_viewport.add_child(back)
	back.transform = Transform3D(Basis.looking_at(Vector3(-0.3, -0.6, 0.8).normalized(), Vector3.UP), Vector3.ZERO)

	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	_felt.mesh = pm
	_felt_mat = ShaderMaterial.new()
	_felt_mat.shader = preload("res://game/dice/felt.gdshader")
	_felt_mat.set_shader_parameter("noise_a", _noise_tex(0.02, 3, 11))
	_felt_mat.set_shader_parameter("noise_b", _noise_tex(0.08, 2, 29))
	_felt.material_override = _felt_mat
	_viewport.add_child(_felt)
	_camera.fov = FOV
	_camera.current = true
	_viewport.add_child(_camera)
	_viewport.add_child(_dice_root)


static func _noise_tex(freq: float, octaves: int, seed_v: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = seed_v
	var t := NoiseTexture2D.new()
	t.noise = n
	t.seamless = true
	t.width = 256
	t.height = 256
	t.generate_mipmaps = true
	return t


# --- public API -----------------------------------------------------------------------

## Replaces the dice (1..6). Existing dice keep their current face-up orientation.
func set_dice(new_dice: Array) -> void:
	var n := clampi(new_dice.size(), 0, 6)
	while dice.size() > n:
		var d: DieVisual = dice.pop_back()
		d.queue_free()
	while dice.size() < n:
		var d := DieVisual.new()
		d.landed.connect(_on_die_landed)
		_dice_root.add_child(d)
		dice.append(d)
		var start: Basis = DieMesh.up_basis(0)
		d.body.basis = start
		d.rest_basis = start
	for i in n:
		dice[i].set_data(new_dice[i])
	_jitter.resize(n)
	_rebuild_labels()
	_layout()
	for i in n:
		if not dice[i].is_rolling():
			dice[i].position = _slot_pos(i)


## A small chip in the tray's top-left corner (the Paladin's "OATH 4"); "" hides it.
func set_badge(text: String, color := Color(1.0, 0.82, 0.3), icon := "") -> void:
	if _badge == null:
		if text == "":
			return
		_badge = Label.new()
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf") else null
		if font:
			_badge.add_theme_font_override("font", font)
		_badge.add_theme_font_size_override("font_size", 20)
		_badge.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
		_badge.add_theme_constant_override("outline_size", 6)
		_badge_icon = TextureRect.new()
		_badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_badge.add_child(_badge_icon)
		add_child(_badge)
	_badge.visible = text != ""
	if text == "":
		return
	var has_icon := icon != "" and UiIcons.exists(icon)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.08, 0.82)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(color, 0.85)
	sb.content_margin_left = 40 if has_icon else 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_badge.add_theme_stylebox_override("normal", sb)
	_badge.add_theme_color_override("font_color", color.lightened(0.25))
	_badge.text = text
	_badge_icon.visible = has_icon
	if has_icon:
		_badge_icon.texture = UiIcons.tex(icon, 52)
		_badge_icon.position = Vector2(10, 4)
		_badge_icon.size = Vector2(24, 24)
	_badge.size = _badge.get_combined_minimum_size()
	_badge.position = Vector2(FRAME_PX + 8.0, FRAME_PX + 6.0)


## Shows (or removes, with null) the Engineer's turret die on its side stand.
func set_turret(d: Variant) -> void:
	if d == null:
		if turret:
			turret.queue_free()
			_stand.queue_free()
			_turret_label.queue_free()
			turret = null
			_layout()
		return
	if turret == null:
		turret = DieVisual.new()
		turret.name = "TurretDie"
		_dice_root.add_child(turret)
		var start: Basis = DieMesh.up_basis(0)
		turret.body.basis = start
		turret.rest_basis = start
		turret.scale = Vector3.ONE * 0.82
		_stand = _build_stand()
		_dice_root.add_child(_stand)
		_turret_label = Label.new()
		_turret_label.text = "TURRET"
		var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf") else null
		if font:
			_turret_label.add_theme_font_override("font", font)
		_turret_label.add_theme_font_size_override("font_size", 17)
		_turret_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
		_turret_label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
		_turret_label.add_theme_constant_override("outline_size", 6)
		_turret_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_turret_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_turret_label)
		turret.set_data(d)
		_layout()
	else:
		turret.set_data(d)
	_place_turret_label()


## Throws the turret die (it lands on its stand showing `value`).
func roll_turret(value: int) -> void:
	if turret == null:
		return
	var p := _turret_pos()
	turret.start_roll(value, p, _rng, 0.0, roll_duration * 0.7, Vector3(-0.1, 0.0, -0.2), 0.8 * _air)
	_play("dice_roll", -4.0)


## Screen (global canvas) rect of the turret die (Rect2() without one).
func get_turret_screen_rect() -> Rect2:
	if turret == null or not _camera.is_inside_tree():
		return Rect2()
	var c := turret.global_position + turret.pivot.position * turret.scale.x
	var a := _camera.unproject_position(c + Vector3(-0.45, 0.45, 0.0)) / _oversample
	var b := _camera.unproject_position(c + Vector3(0.45, -0.45, 0.0)) / _oversample
	var r := Rect2(a, Vector2.ZERO).expand(b)
	r.position += _view.global_position
	return r


func _turret_pos() -> Vector3:
	return (_slots[dice.size()] if _slots.size() > dice.size() else Vector3.ZERO) + Vector3.UP * 0.1


func _build_stand() -> Node3D:
	var root := Node3D.new()
	root.name = "TurretStand"
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.55, 0.24)
	brass.metallic = 0.85
	brass.roughness = 0.32
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.22, 0.18, 0.16)
	dark.metallic = 0.6
	dark.roughness = 0.45
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.66
	cm.bottom_radius = 0.74
	cm.height = 0.1
	cm.radial_segments = 24
	base.mesh = cm
	base.material_override = brass
	base.position.y = 0.05
	root.add_child(base)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.64
	tm.outer_radius = 0.72
	tm.rings = 24
	ring.mesh = tm
	ring.material_override = dark
	ring.position.y = 0.1
	root.add_child(ring)
	for k in 6:
		var bolt := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		bolt.mesh = sm
		bolt.material_override = dark
		var a := TAU * k / 6.0
		bolt.position = Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6)
		root.add_child(bolt)
	return root


func _place_turret_label() -> void:
	if turret == null or _turret_label == null or not is_inside_tree():
		return
	var r := get_turret_screen_rect()
	_turret_label.reset_size()
	var s := _turret_label.get_combined_minimum_size()
	_turret_label.size = s
	_turret_label.position = Vector2(r.get_center().x - s.x * 0.5, r.end.y + 12.0) - global_position
	_turret_label.position.y = minf(_turret_label.position.y, size.y - FRAME_PX - s.y)


## Shows values instantly (one per die). No animation, no signal.
func set_values(values: Array) -> void:
	for i in mini(values.size(), dice.size()):
		dice[i].show_value(int(values[i]), _rng)
		dice[i].position = _slot_pos(i)
	_update_labels()


## Throws the dice at `indices`; each ends showing its value. Emits `settled` when done.
func roll(values: Array[int], indices: Array[int]) -> void:
	var todo: Array[int] = []
	var vals: Array[int] = []
	for j in indices.size():
		var i := indices[j]
		if i < 0 or i >= dice.size():
			continue
		var v := 1
		if values.size() == dice.size():
			v = values[i]
		elif j < values.size():
			v = values[j]
		todo.append(i)
		vals.append(v)
	if todo.is_empty():
		_emit_settled.call_deferred()
		return
	_rolling = true
	_land_count = 0
	var throw_x := _rng.randf_range(0.25, 0.55) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var throw := Vector3(throw_x, 0.0, _rng.randf_range(-0.8, -0.45) * _air)
	var order := todo.duplicate()
	order.shuffle()
	for j in todo.size():
		var i := todo[j]
		var d := dice[i]
		_jitter[i] = Vector3(_rng.randf_range(-0.1, 0.1) * _spacing / MIN_SPACING, 0.0, _rng.randf_range(-0.14, 0.14))
		var drift := throw + Vector3(_rng.randf_range(-0.1, 0.1), 0.0, _rng.randf_range(-0.15, 0.15))
		# Keep the arc inside the visible felt for dice at the ends of the row.
		var mid_x := (d.position.x + _slot_pos(i).x) * 0.5
		drift.x -= mid_x * 0.12  # converge slightly toward the middle
		drift.x = clampf(mid_x + drift.x, -_half_w + 1.45, _half_w - 1.45) - mid_x
		var delay := 0.055 * float(order.find(i)) + _rng.randf_range(0.0, 0.03)
		var dur := roll_duration * _rng.randf_range(0.9, 1.12)
		var apex := _rng.randf_range(1.05, 1.35) * _air
		d.start_roll(vals[j], _slot_pos(i), _rng, delay, dur, drift, apex)
	_play("dice_roll", 0.0)


## Marked for reroll: lifts and glows.
func set_marked(idx: int, marked: bool) -> void:
	if idx >= 0 and idx < dice.size():
		dice[idx].marked = marked


## Cursed: chains + purple tint; the die cannot be marked while locked.
func set_locked(idx: int, locked: bool) -> void:
	if idx >= 0 and idx < dice.size():
		dice[idx].locked = locked


## Pulses the given dice (combo group) in `color`.
func highlight_group(indices: Array[int], color: Color = Color(1.0, 0.82, 0.35)) -> void:
	for i in dice.size():
		dice[i].hl_on = indices.has(i)
		dice[i].hl_color = color


func clear_highlight() -> void:
	for d in dice:
		d.hl_on = false


## Board move: lifts and glows the moving dice and dims the rest. Empty clears it.
func set_chosen(indices: Array) -> void:
	for i in dice.size():
		dice[i].chosen = indices.has(i)
		dice[i].dimmed = not indices.is_empty() and not indices.has(i)


func clear_chosen() -> void:
	set_chosen([])


## Screen (global canvas) point centred above die `idx` (for popups).
func die_top_screen(idx: int) -> Vector2:
	var r := get_die_screen_rect(idx)
	return Vector2(r.get_center().x, r.position.y) if r.size != Vector2.ZERO else global_position + Vector2(size.x * 0.5, 0)


func set_interactive(on: bool) -> void:
	interactive = on


func is_rolling() -> bool:
	return _rolling


## Screen (global canvas) rect around die `idx`, for anchoring UI.
func get_die_screen_rect(idx: int) -> Rect2:
	if idx < 0 or idx >= dice.size() or not _camera.is_inside_tree():
		return Rect2()
	var d := dice[idx]
	var c := d.global_position + d.pivot.position
	var r := Rect2()
	var first := true
	for x in [-0.5, 0.5]:
		for y in [-0.5, 0.5]:
			for z in [-0.5, 0.5]:
				var sp := _camera.unproject_position(c + Vector3(x, y, z)) / _oversample
				if first:
					r = Rect2(sp, Vector2.ZERO)
					first = false
				else:
					r = r.expand(sp)
	r.position += _view.global_position
	return r


## Value currently facing up on die `idx` (from its actual orientation).
func get_up_value(idx: int) -> int:
	return dice[idx].up_value() if idx >= 0 and idx < dice.size() else 0


## Alignment of die `idx`'s up face with world up (1.0 = perfectly flat).
func get_up_alignment(idx: int) -> float:
	var d := dice[idx]
	var b := d.body.basis
	return (b * DieMesh.DIRS[DieMesh.up_slot(b)]).normalized().dot(Vector3.UP)


func show_values_labels(on: bool) -> void:
	_show_labels = on
	_labels_root.visible = on
	_update_labels()


# --- internals ------------------------------------------------------------------------

func _emit_settled() -> void:
	settled.emit()


func _process(dt: float) -> void:
	for d in dice:
		d.tick(dt, speed_scale)
	if turret:
		turret.tick(dt, speed_scale)
	if _rolling:
		var any := false
		for d in dice:
			if d.is_rolling():
				any = true
				break
		if not any:
			_rolling = false
			_update_labels()
			settled.emit()
	if _show_labels:
		_update_labels()


func _on_die_landed(strength: float) -> void:
	var now := Time.get_ticks_msec()
	if strength < 0.2 and now - _last_land_ms < 90:
		return
	if now - _last_land_ms < 45:
		return
	_last_land_ms = now
	_land_count += 1
	_play("dice_land", linear_to_db(clampf(strength, 0.15, 1.0)) - (2.0 if _land_count > 3 else 0.0))


func _play(id: String, vol_db: float) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio and sfx_enabled:
		audio.play_sfx(id, 0.08, vol_db)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var idx := _pick(mb.position)
		if idx >= 0:
			accept_event()
			_play("dice_select", 0.0)
			die_pressed.emit(idx)


## Ray-picks a die under a local (control) point. -1 if none.
func _pick(local_pos: Vector2) -> int:
	var vp_pos := (local_pos - _view.position) * _oversample
	var from := _camera.project_ray_origin(vp_pos)
	var dir := _camera.project_ray_normal(vp_pos)
	var best := -1
	var best_t := INF
	for i in dice.size():
		var d := dice[i]
		var xf := Transform3D(d.body.global_basis, d.body.global_position)
		var inv := xf.affine_inverse()
		var o := inv * from
		var v := inv.basis * dir
		var t := _ray_box(o, v, 0.62)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = i
	return best


static func _ray_box(o: Vector3, v: Vector3, h: float) -> float:
	var tmin := -INF
	var tmax := INF
	for a in 3:
		if absf(v[a]) < 1e-6:
			if absf(o[a]) > h:
				return -1.0
			continue
		var t1 := (-h - o[a]) / v[a]
		var t2 := (h - o[a]) / v[a]
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
	if tmax < maxf(tmin, 0.0):
		return -1.0
	return maxf(tmin, 0.0)


func _slot_pos(i: int) -> Vector3:
	if i < _slots.size():
		return _slots[i] + (_jitter[i] if i < _jitter.size() else Vector3.ZERO)
	return Vector3.ZERO


func _layout() -> void:
	var sz := size
	if sz.x < 8.0 or sz.y < 8.0:
		return
	var inset := FRAME_PX - 3.0
	_view.position = Vector2(inset, inset)
	_view.size = sz - Vector2(inset, inset) * 2.0
	_frame.position = Vector2.ZERO
	_frame.size = sz
	var fm := _frame.material as ShaderMaterial
	fm.set_shader_parameter("size", sz)
	fm.set_shader_parameter("radius", CORNER_PX)
	fm.set_shader_parameter("frame", FRAME_PX)
	_labels_root.position = Vector2.ZERO
	_labels_root.size = sz
	var screen_scale := 1.0
	if is_inside_tree():
		screen_scale = get_viewport().get_final_transform().get_scale().x
	_oversample = clampf(screen_scale, 1.0, 3.0)
	_viewport.size = Vector2i(maxi(8, int(_view.size.x * _oversample)), maxi(8, int(_view.size.y * _oversample)))

	# Camera: fit the dice row (at least 4 wide) horizontally and a fixed height band.
	var n := dice.size()
	var slots_n := n + (1 if turret else 0)
	var aspect := _view.size.x / _view.size.y
	var tan_v := tan(deg_to_rad(FOV * 0.5))
	var need_w := (float(maxi(slots_n, 4)) * MIN_SPACING) * 0.5 + 0.3
	var need_h := 1.6
	var dist := maxf(need_w / (tan_v * aspect), need_h / tan_v)
	var pitch := deg_to_rad(PITCH_DEG)
	var target := Vector3(0.0, 0.55, -0.12)
	_camera.position = target + Vector3(0.0, sin(pitch), cos(pitch)) * dist
	_camera.rotation = Vector3(-pitch, 0.0, 0.0)
	var vis_w := dist * tan_v * aspect * 2.0
	_half_w = vis_w * 0.5
	# Short (landscape) trays get lower arcs so dice stay inside the frame.
	_air = clampf((dist * tan_v - 0.9) / 1.0, 0.5, 1.0)
	_spacing = clampf((vis_w - 1.1) / maxf(float(slots_n), 1.0), MIN_SPACING, MAX_SPACING)
	_slots.clear()
	for i in slots_n:
		_slots.append(Vector3((float(i) - (slots_n - 1) * 0.5) * _spacing, 0.0, 0.0))
	if turret:
		var tp := _turret_pos()
		_stand.position = tp - Vector3.UP * 0.1
		if not turret.is_rolling():
			turret.position = tp
			turret.rest_pos = tp
	for i in n:
		if not dice[i].is_rolling():
			dice[i].position = _slot_pos(i)
			dice[i].rest_pos = _slot_pos(i)
	_felt_mat.set_shader_parameter("falloff", maxf(vis_w * 0.55, 4.0))
	_update_labels()
	_place_turret_label.call_deferred()


func _rebuild_labels() -> void:
	for l in _labels:
		l.queue_free()
	_labels.clear()
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf") else null
	for i in dice.size():
		var l := Label.new()
		if font:
			l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
		l.add_theme_constant_override("outline_size", 8)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_labels_root.add_child(l)
		_labels.append(l)
	_labels_root.visible = _show_labels


func _update_labels() -> void:
	if not _show_labels or not is_inside_tree():
		return
	for i in mini(_labels.size(), dice.size()):
		var l := _labels[i]
		var r := get_die_screen_rect(i)
		l.visible = not dice[i].is_rolling()
		l.text = str(get_up_value(i))
		l.size = Vector2(60, 40)
		l.position = Vector2(r.get_center().x - 30.0, r.position.y - 38.0) - global_position
