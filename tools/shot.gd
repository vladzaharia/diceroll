extends Node
## Screenshot/scenario harness (autoload `Shot`). Does nothing without user args.
##
##   godot --path . --resolution 720x1280 -- --scenario=actors --shot=/abs/out.png [--wait=1.5] [--frames=N]
##
## --scenario=<name>  replaces the main scene with Scenarios.build(name)
## --shot=<png>       after --wait seconds saves the viewport, prints "SHOT_SAVED <path>", quits
## --frames=N         additionally saves N more shots 0.25 s apart as <png>_1.._N
## --ui-scale=F       multiplies the window's content_scale_factor (UI zoom / OS scaling tests)
## --audit           after the shot, prints AUDIT_TEXT lines for visible text under 16 canvas px
##                   and AUDIT_TAP lines for buttons under 80 canvas px tall (44 pt on a phone),
##                   plus the no-spillover gate (UiAudit): AUDIT_OVERFLOW (rect outside its
##                   frame), AUDIT_SAFE (content outside the safe area), AUDIT_CLIP (text
##                   wider than its label); opt out per node with meta "allow_overflow"
## --hover=X,Y      moves the mouse to (X, Y) (fractions of the window) 0.6 s before the shot:
##                   desktop hover states (the GameButton hover keycap; use with --input=kbm)
## Without --shot the scenario just runs (handy for manual poking).
## --timeout=S      safety timer: force-quits S seconds after start (default wait + frames*0.25 + 10;
##                   CI software rendering (lavapipe) compiles shaders slowly, so tools/ci/shoot_ci.sh raises it)

const FRAME_GAP := 0.25

var args: Dictionary = {}
var scenario: Node


func _ready() -> void:
	args = parse_args(OS.get_cmdline_user_args())
	if not args.has("scenario"):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	if args.has("ui-scale"):
		get_window().content_scale_factor *= float(args["ui-scale"])
	var wait := float(args.get("wait", "1.5"))
	var frames := int(args.get("frames", "0"))
	if args.has("shot"):
		# Stay in the background: never take focus, and don't pace frames to the
		# display link (macOS throttles vsync for occluded/off-screen windows).
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var limit := float(args.get("timeout", str(wait + frames * FRAME_GAP + 10.0)))
		var guard := get_tree().create_timer(limit, true, false, true)
		guard.timeout.connect(func() -> void:
			push_error("Shot: safety timeout, quitting")
			get_tree().quit(2))
	_run.call_deferred(String(args["scenario"]), wait, frames)


static func parse_args(list: PackedStringArray) -> Dictionary:
	var out := {}
	for a in list:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out


func _run(name: String, wait: float, frames: int) -> void:
	var tree := get_tree()
	var missing := AssetCheck.run(true)
	if not missing.is_empty():
		push_error("Shot: required game assets are missing (%s); run tools/import_assets.sh" % ", ".join(missing))
		tree.quit(1)
		return
	if tree.current_scene:
		tree.current_scene.queue_free()
	scenario = Scenarios.build(name)
	if scenario == null:
		push_error("Shot: unknown scenario '%s' (known: %s)" % [name, ", ".join(Scenarios.names())])
		tree.quit(1)
		return
	tree.root.add_child(scenario)
	tree.current_scene = scenario
	print("SCENARIO_STARTED ", name)
	if not args.has("shot"):
		return
	var path := String(args["shot"])
	if args.has("hover"):
		var hv := String(args["hover"]).split(",")
		await tree.create_timer(maxf(wait - 0.6, 0.1), true, false, true).timeout
		var vs := get_viewport().get_visible_rect().size
		var m := InputEventMouseMotion.new()
		m.position = vs * Vector2(float(hv[0]), float(hv[1] if hv.size() > 1 else "0.5"))
		m.global_position = m.position
		m.relative = Vector2(4, 4)
		get_viewport().push_input(m, true)
		await tree.create_timer(0.6, true, false, true).timeout
	else:
		await tree.create_timer(wait, true, false, true).timeout
	await _save(path)
	if args.has("audit"):
		print("AUDIT_BEGIN")
		_audit(tree.root)
		# no-spillover gate: AUDIT_OVERFLOW / AUDIT_SAFE / AUDIT_CLIP (ui/theme/ui_audit.gd)
		for line in UiAudit.run(tree.root):
			print(line)
		print("AUDIT_END")
	for i in frames:
		await tree.create_timer(FRAME_GAP, true, false, true).timeout
		await _save("%s_%d.%s" % [path.get_basename(), i + 1, path.get_extension()])
	scenario.queue_free()
	Audio.stop_all()
	for i in 3:
		await tree.process_frame
	Character.clear_cache()
	tree.quit(0)


func _save(path: String) -> void:
	# frame_post_draw can stall while macOS throttles an occluded window; don't hang on it.
	var drawn := [false]
	var on_draw := func() -> void: drawn[0] = true
	RenderingServer.frame_post_draw.connect(on_draw, CONNECT_ONE_SHOT)
	var t := 0.0
	while not drawn[0] and t < 2.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if RenderingServer.frame_post_draw.is_connected(on_draw):
		RenderingServer.frame_post_draw.disconnect(on_draw)
		push_warning("Shot: window not drawing (occluded?), forcing a draw")
		RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	if err != OK:
		push_error("Shot: could not save %s (%s)" % [path, error_string(err)])
		return
	print("SHOT_SAVED ", path)


## Text-size and tap-target audit of what is on screen (canvas px, Control scale included).
func _audit(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Control:
		var c := n as Control
		var k := c.get_global_transform().get_scale().y
		var r := c.get_global_rect()
		var on_screen := r.intersects(Rect2(Vector2.ZERO, c.get_viewport_rect().size)) and c.modulate.a > 0.05
		if on_screen and n is Label and String((n as Label).text).strip_edges() != "":
			var l := n as Label
			var fs := l.label_settings.font_size if l.label_settings else l.get_theme_font_size("font_size")
			if fs * k < 16.0 - 0.01:
				print("AUDIT_TEXT %.1f \"%s\" %s" % [fs * k, l.text.left(40).replace("\n", " "), _short(l)])
		if on_screen and (n is BaseButton or n.get_class() == "Control" and n.has_signal("pressed")) and r.size.y < 80.0 - 0.01:
			print("AUDIT_TAP %.0fx%.0f %s" % [r.size.x, r.size.y, _short(c)])
	for ch in n.get_children():
		_audit(ch)


func _short(n: Node) -> String:
	var parts := []
	var p := n
	for i in 4:
		if p == null:
			break
		parts.push_front(String(p.name) if not String(p.name).begins_with("@") else p.get_class())
		p = p.get_parent()
	return "/".join(parts)
