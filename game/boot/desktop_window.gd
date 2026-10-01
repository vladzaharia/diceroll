class_name DesktopWindow
extends RefCounted
## Desktop start-up window: landscape, a reasonable size, centred. Called first thing from
## main.gd. The game is portrait-first (720x1280 base viewport, canvas_items + expand); phones
## keep that. On macOS / Windows / Linux the window opens at 1600x900 (project.godot
## `window_*_override.pc`), and here it is fitted to the screen it opened on:
##
##   size = 1600x900, scaled down (16:9 kept) to fit 85 % of the usable screen area,
##          but never under 1280x720 unless the screen itself is smaller
##   min  = 1280x720 (or the 85 % fit on smaller screens), centred in the usable area
##
## Sizes are logical (x screen_get_scale(): macOS Retina reports pixels at 2x). Skipped when
## the size was chosen on purpose: --resolution (the window isn't the project size; tools/shot.gd
## / tools/shoot.sh always pass it, and --scenario runs are skipped anyway), --fullscreen /
## --maximized (not plain windowed), headless runs and the editor's embedded game view. The
## web build sizes its canvas from the page.

const TARGET := Vector2(1600, 900)
const MIN_SIZE := Vector2(1280, 720)
const SCREEN_FRACTION := 0.85


## Applies the start-up size to the main window. Returns the chosen rect (empty when skipped).
static func apply() -> Rect2i:
	if not should_apply(OS.get_cmdline_user_args(), DisplayServer.window_get_size()):
		return Rect2i()
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var r := fit(usable, DisplayServer.screen_get_scale(screen))
	DisplayServer.window_set_min_size(Vector2i(min_size(usable, DisplayServer.screen_get_scale(screen))))
	DisplayServer.window_set_size(r.size)
	DisplayServer.window_set_position(r.position)
	return r


## Godot consumes engine args (--resolution, --fullscreen, ...) before scripts run, so an
## explicit size shows as a window that isn't the project's desktop size; the screenshot
## harness (--scenario in the user args) is skipped outright.
static func should_apply(user_args: PackedStringArray, window_size: Vector2i) -> bool:
	if not OS.has_feature("pc") or OS.has_feature("web"):
		return false
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor():
		return false
	for a in user_args:
		if a.begins_with("--scenario"):
			return false
	if not is_project_size(window_size, DisplayServer.screen_get_scale(DisplayServer.window_get_current_screen())):
		return false
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED


## True when `window_size` is the size the engine opened from project.godot (the desktop
## override, in pixels or scaled by the screen), i.e. nobody passed --resolution.
static func is_project_size(window_size: Vector2i, scale := 1.0) -> bool:
	var w := int(ProjectSettings.get_setting_with_override("display/window/size/window_width_override"))
	var h := int(ProjectSettings.get_setting_with_override("display/window/size/window_height_override"))
	var p := Vector2i(w, h)
	return w > 0 and h > 0 and (window_size == p or window_size == Vector2i((Vector2(p) * scale).round()))


## The window rect (pixels) for a usable screen area `usable` (pixels) at `scale` px per
## logical px: TARGET fitted to SCREEN_FRACTION of it (16:9 kept), at least the minimum, centred.
static func fit(usable: Rect2i, scale := 1.0) -> Rect2i:
	var avail := Vector2(usable.size)
	var s := maxf(scale, 1.0)
	var k := minf(1.0, minf(avail.x * SCREEN_FRACTION / (TARGET.x * s), avail.y * SCREEN_FRACTION / (TARGET.y * s)))
	var size := (TARGET * s * k).max(min_size(usable, scale)).min(avail)
	var sz := Vector2i(size.round())
	return Rect2i(usable.position + (usable.size - sz) / 2, sz)


## MIN_SIZE (logical) in pixels, shrunk (16:9 kept) to SCREEN_FRACTION of a smaller screen.
static func min_size(usable: Rect2i, scale := 1.0) -> Vector2:
	var m := MIN_SIZE * maxf(scale, 1.0)
	var avail := Vector2(usable.size)
	if m.x <= avail.x and m.y <= avail.y:
		return m
	return m * minf(avail.x * SCREEN_FRACTION / m.x, avail.y * SCREEN_FRACTION / m.y)
