class_name DevGesture
extends Control
## Hidden Developer-menu gesture: TAPS taps / clicks inside the SIZE x SIZE px bottom-right
## corner (inside the device safe area) within WINDOW_MS opens the DevMenu. Invisible, no
## hint, and it never blocks input: it only watches _input, so the screen below still gets
## every event. A tap outside the corner resets the count.
##
## Drop it onto whatever screen shows first at boot (title screen, missing-assets screen,
## and the future streaming loader, see docs/design/2026-09-29-content-streaming.md):
##   add_child(DevGesture.new())
##
## On unlock it shows a subtle toast, opens a DevMenu on its own CanvasLayer and emits
## `unlocked` (set auto_open = false to handle it yourself).

signal unlocked

const TAPS := 5
const WINDOW_MS := 3000
## Hit area edge (logical px).
const SIZE := 80.0
const LAYER := 110

var auto_open := true
var menu: DevMenu
var _taps: Array[int] = []
var _layer: CanvasLayer


func _init() -> void:
	name = "DevGesture"
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The hit square for a view of `view` size with a bottom-right device inset `inset`.
static func corner_rect(view: Vector2, inset := Vector2.ZERO) -> Rect2:
	return Rect2(view - inset - Vector2(SIZE, SIZE), Vector2(SIZE, SIZE))


## Real device safe-area inset at the bottom-right. UiTheme.safe_margins() never returns less
## than UiTheme.EDGE (layout breathing room); that padding isn't an inset, so it counts as 0.
static func safe_inset(node: Node) -> Vector2:
	var m := UiTheme.safe_margins(node)
	return Vector2(m.right if m.right > UiTheme.EDGE else 0.0, m.bottom if m.bottom > UiTheme.EDGE else 0.0)


## Gesture counter (pure; `now_ms` is a monotonic clock). Returns true on the tap that
## completes the gesture, then starts over. Taps outside the corner reset; taps older than
## WINDOW_MS drop out of the window.
func tap(pos: Vector2, now_ms: int, view: Vector2, inset := Vector2.ZERO) -> bool:
	if not corner_rect(view, inset).has_point(pos):
		_taps.clear()
		return false
	while not _taps.is_empty() and now_ms - _taps[0] > WINDOW_MS:
		_taps.pop_front()
	_taps.append(now_ms)
	if _taps.size() >= TAPS:
		_taps.clear()
		return true
	return false


func tap_count() -> int:
	return _taps.size()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or (menu != null and menu.is_open()):
		return
	var pos: Variant = null
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		# touch screens also send an emulated mouse click for every touch: count it once
		pos = event.position
	if pos == null:
		return
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * (pos as Vector2)
	if tap(local, Time.get_ticks_msec(), size, safe_inset(self)):
		unlock()


func unlock() -> void:
	unlocked.emit()
	if auto_open:
		open_menu()
		toast("Developer menu unlocked")


## Opens (creating on first use) the DevMenu above everything else.
func open_menu(instant := false) -> DevMenu:
	if menu == null:
		menu = DevMenu.new()
		_ensure_layer().add_child(menu)
	menu.refresh()
	if instant:
		menu.show_now()
	else:
		menu.open()
	return menu


func toast(text: String) -> void:
	DevMenu.toast(_ensure_layer(), text)


func _ensure_layer() -> CanvasLayer:
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.name = "DevLayer"
		_layer.layer = LAYER
		add_child(_layer)
	return _layer
