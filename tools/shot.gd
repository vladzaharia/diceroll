extends Node
## Screenshot/scenario harness (autoload `Shot`). Does nothing without user args.
##
##   godot --path . --resolution 720x1280 -- --scenario=actors --shot=/abs/out.png [--wait=1.5] [--frames=N]
##
## --scenario=<name>  replaces the main scene with Scenarios.build(name)
## --shot=<png>       after --wait seconds saves the viewport, prints "SHOT_SAVED <path>", quits
## --frames=N         additionally saves N more shots 0.25 s apart as <png>_1.._N
## --ui-scale=F       multiplies the window's content_scale_factor (UI zoom / OS scaling tests)
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
	await tree.create_timer(wait, true, false, true).timeout
	await _save(path)
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
