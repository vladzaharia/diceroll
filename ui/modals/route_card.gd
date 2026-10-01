class_name RouteCard
extends UiModal
## Run-start route card: this run's three biomes (one per tier, with their twist), the lap-7
## mini-boss and the lap-15 final boss, then BEGIN. Emits begin_pressed (and closes).
## Auto-dismisses after `auto_close` seconds when > 0 (AUTO play, scenarios).

signal begin_pressed

var auto_close := 0.0
var _strip_holder: VBoxContainer
var _sub: Label
var _timer: SceneTreeTimer


func _build() -> void:
	set_title("YOUR ROUTE", PLAQUE_DEFAULT)
	max_width = 680.0
	_sub = UiTheme.label("", 22, UiPalette.TEXT_DIM, false, 0, false, 600)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_sub)
	_strip_holder = UiTheme.vbox(0)
	body.add_child(_strip_holder)
	var go := GameButton.make("BEGIN", "arrow_right", GameButton.Kind.PRIMARY, 38)
	go.icon_tint = UiPalette.TEXT_DARK
	go.pressed.connect(_begin)
	body.add_child(go)
	# forced (spec 3.2): BEGIN is the act's one exit (Enter)
	primary_action = go


func refresh(flow: GameFlow) -> void:
	var cls: Dictionary = HeroDefs.DATA.get(flow.run.class_id, HeroDefs.DATA.knight)
	_sub.text = "%s  ·  %d laps  ·  a new road every run" % [String(cls.name), Balance.TOTAL_LAPS]
	UiTheme.clear(_strip_holder)
	_strip_holder.add_child(RouteStrip.make(flow.route_info(), 0, 0, false))
	relayout()


func open() -> void:
	super.open()
	if auto_close > 0.0 and is_inside_tree():
		_timer = get_tree().create_timer(auto_close)
		_timer.timeout.connect(func() -> void:
			_begin())


func _begin() -> void:
	if not is_open():
		return
	close()
	begin_pressed.emit()
