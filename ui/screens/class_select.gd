class_name ClassSelect
extends Control
## Class select: rotating 3D Character preview (SubViewport), class tabs, stats, starting
## dice with runes, Start. Portrait stacks preview over info; landscape puts them side by side.
## Emits class_chosen(class_id), back_pressed.

signal class_chosen(class_id: String)
signal back_pressed

const TAGLINES := ClassInfo.TAGLINES

var selected := "knight"
var start_btn: GameButton
var back_btn: GameButton
var _preview: SubViewportContainer
var _viewport: SubViewport
var _pivot: Node3D
var _hero: Node3D
var _tabs: Array[GameButton] = []
var _tabs_row: HBoxContainer
var _info: VBoxContainer
var _name: Label
var _tagline: Label
var _stats: HBoxContainer
var _dice_box: VBoxContainer
var _header: Label
var _panel: PanelContainer
var _bg: _Backdrop
var _cam: Camera3D


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	_bg = _Backdrop.new()
	add_child(UiTheme.full_rect(_bg))
	_build_preview()
	_header = UiTheme.label("CHOOSE YOUR HERO", 44, UiPalette.GOLD_BRIGHT, true, 10, true)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_header)
	back_btn = GameButton.round_icon("arrow_left", 88)
	back_btn.kind = GameButton.Kind.GHOST
	back_btn.icon_tint = UiPalette.TEXT
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back_btn)

	_panel = UiTheme.panel("main")
	add_child(_panel)
	_info = UiTheme.vbox(14)
	_panel.add_child(_info)
	_tabs_row = UiTheme.hbox(10)
	_info.add_child(_tabs_row)
	for id in HeroDefs.IDS:
		var b := GameButton.make(String(HeroDefs.DATA[id].name), UiIcons.class_icon(id), GameButton.Kind.SECONDARY, 22)
		b.toggle_mode = true
		b.toggle_primary = true
		b.pad_x = 10
		b.min_height = 88
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon_px = 34
		b.pressed.connect(select.bind(String(id)))
		_tabs_row.add_child(b)
		_tabs.append(b)
	_name = UiTheme.label("", 52, UiPalette.TEXT, true, 8, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_child(_name)
	_tagline = UiTheme.para("", 24, UiPalette.TEXT_DIM, 500)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_child(_tagline)
	_stats = UiTheme.hbox(10)
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_info.add_child(_stats)
	_info.add_child(UiModal.section_label("Starting dice"))
	_dice_box = UiTheme.vbox(8)
	_info.add_child(_dice_box)
	start_btn = GameButton.make("START RUN", "arrow_right", GameButton.Kind.PRIMARY, 44)
	start_btn.icon_tint = UiPalette.TEXT_DARK
	start_btn.min_height = 112
	start_btn.pressed.connect(func() -> void: class_chosen.emit(selected))
	_info.add_child(start_btn)
	resized.connect(_layout)
	_panel.minimum_size_changed.connect(_queue_layout)


var _layout_queued := false


func _queue_layout() -> void:
	if not _layout_queued:
		_layout_queued = true
		(func() -> void:
			_layout_queued = false
			_layout()).call_deferred()


func _ready() -> void:
	select(selected, false)
	_layout()


func _build_preview() -> void:
	_preview = SubViewportContainer.new()
	_preview.stretch = true
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_preview.add_child(_viewport)
	var world := Node3D.new()
	_viewport.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a86c0")
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe0b0")
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.shadow_enabled = true
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("7aa0ff")
	rim.light_energy = 1.2
	rim.rotation_degrees = Vector3(-20, 150, 0)
	world.add_child(rim)
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.05
	cm.bottom_radius = 1.2
	cm.height = 0.3
	cm.radial_segments = 48
	ped.mesh = cm
	ped.position.y = -0.15
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("3a3450")
	pm.roughness = 0.6
	ped.material_override = pm
	world.add_child(ped)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.08
	tm.outer_radius = 1.16
	tm.rings = 64
	ring.mesh = tm
	ring.position.y = 0.0
	var rm := StandardMaterial3D.new()
	rm.albedo_color = UiPalette.GOLD
	rm.emission_enabled = true
	rm.emission = UiPalette.GOLD
	rm.emission_energy_multiplier = 0.6
	ring.material_override = rm
	world.add_child(ring)
	_pivot = Node3D.new()
	world.add_child(_pivot)
	var cam := Camera3D.new()
	_cam = cam
	cam.fov = 32
	cam.position = Vector3(0, 1.35, 5.2)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.85, 0) - cam.position), cam.position)
	world.add_child(cam)
	cam.current = true


func select(id: String, animate := true) -> void:
	selected = id
	var def: Dictionary = HeroDefs.DATA[id]
	for i in _tabs.size():
		_tabs[i].set_pressed_no_signal(HeroDefs.IDS[i] == id)
		_tabs[i].call("_refresh")
	_name.text = String(def.name)
	_tagline.text = TAGLINES.get(id, "")
	UiTheme.clear(_stats)
	_stats.add_child(_stat("heart", "%d" % int(def.hp), "HP", UiPalette.HP))
	_stats.add_child(_stat("sword", "+%d" % int(def.atk), "ATK", UiPalette.TEXT))
	_stats.add_child(_stat("reroll", "%d" % int(def.board_rerolls), "MOVE REROLL", UiPalette.GOLD_BRIGHT))
	_stats.add_child(_stat("dice", "%d" % Balance.COMBAT_REROLLS, "FIGHT REROLLS", UiPalette.DIE_BODY))
	UiTheme.clear(_dice_box)
	var runes: Array = def.runes
	for r in runes:
		_dice_box.add_child(_die_row(String(r)))
	_swap_hero(String(def.model))
	if animate:
		UiTheme.pop(_name, 1.1, 0.25)
		_layout.call_deferred()


func _stat(icon: String, value: String, label: String, col: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(UiPalette.NAVY_2, 18, 2, Color(1, 1, 1, 0.06)), 12, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiTheme.vbox(0)
	p.add_child(v)
	var r := UiTheme.hbox(6)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(r)
	r.add_child(UiIcons.rect(icon, 30))
	r.add_child(UiTheme.label(value, 30, col, true, 0))
	var l := UiTheme.label(label, 15, UiPalette.TEXT_MUTED, false, 0, false, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return p


func _die_row(rune: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.03, 0.03, 0.09, 0.45), 16), 12, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(14)
	p.add_child(row)
	var f := DieFace.make(6, rune, false, 52)
	f.star = rune == "wild"
	row.add_child(f)
	var col := UiTheme.vbox(-2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	if rune == "":
		col.add_child(UiTheme.label("Plain die", 26, UiPalette.TEXT, true, 0))
		col.add_child(UiTheme.label("Faces 1 to 6, no rune.", 20, UiPalette.TEXT_MUTED, false, 0, false, 500))
	else:
		var d: Dictionary = Runes.DEFS[rune]
		col.add_child(UiTheme.label("%s Rune" % d.name, 26, UiPalette.rune_color(rune).lightened(0.15), true, 0))
		var desc := UiTheme.para(String(d.desc), 20, UiPalette.TEXT_DIM)
		col.add_child(desc)
		row.add_child(RuneBadge.make(rune, 46))
	return p


func _swap_hero(model: String) -> void:
	if _hero:
		_hero.queue_free()
	_hero = Character.create(model)
	_pivot.add_child(_hero)
	if _hero.has_method("play"):
		_hero.call("play", "idle")
	_pivot.rotation.y = deg_to_rad(-25.0)
	_hero.scale = Vector3(0.6, 0.6, 0.6)
	var t := create_tween()
	t.tween_property(_hero, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_inside_tree() and _hero.has_method("play_once"):
		_hero.call("play_once", "cheer")


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotation.y += delta * 0.45


func _layout() -> void:
	if size.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	var portrait := UiTheme.is_portrait(size)
	back_btn.reset_size()
	back_btn.position = Vector2(safe.left, safe.top)
	_header.size = Vector2(size.x, 88)
	_header.position = Vector2(0, safe.top)
	if portrait:
		var w := minf(UiTheme.MODAL_MAX_W, size.x - safe.left - safe.right)
		_panel.reset_size()
		_panel.size.x = w
		var ph := _panel.get_combined_minimum_size().y
		_panel.size = Vector2(w, ph)
		_panel.position = Vector2((size.x - w) * 0.5, size.y - safe.bottom - ph)
		var top := safe.top + 90.0
		var avail := _panel.position.y - top + 30.0
		_preview.position = Vector2(0, top)
		_preview.size = Vector2(size.x, maxf(200.0, avail))
		_cam.fov = 32
	else:
		var w := minf(UiTheme.MODAL_MAX_W, size.x * 0.46)
		_panel.reset_size()
		_panel.size.x = w
		var ph := _panel.get_combined_minimum_size().y
		_panel.size = Vector2(w, ph)
		var x := size.x * 0.5 + (size.x * 0.5 - w) * 0.35
		_panel.position = Vector2(x, maxf(safe.top + 90.0, (size.y - ph) * 0.5 + 40.0))
		_preview.position = Vector2(size.x * 0.04, safe.top)
		_preview.size = Vector2(size.x * 0.48, size.y - safe.top - safe.bottom)
		_cam.fov = 40
		_header.size = Vector2(w, 88)
		_header.position = Vector2(x, _panel.position.y - 100.0)


class _Backdrop:
	extends Control
	## Radial dusk gradient behind the class preview.
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0e0f24"))
		var c := Vector2(size.x * (0.5 if size.y > size.x else 0.26), size.y * 0.36)
		var r := maxf(size.x, size.y) * 0.62
		for i in 28:
			var k := float(i) / 28.0
			draw_circle(c, r * (1.0 - k), Color("2a2560").lerp(Color("5a3a7a"), k * k).darkened(0.1) * Color(1, 1, 1, 0.08 + k * 0.05))
		var g := Vector2(c.x, size.y * 0.36 + 60)
		for i in 10:
			draw_circle(g, 180.0 - i * 16.0, Color(1.0, 0.72, 0.3, 0.025))
