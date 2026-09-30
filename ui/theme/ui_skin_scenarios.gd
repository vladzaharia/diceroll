extends RefCounted
## Screenshot scenarios for the RhosGFX skin machinery (UiSkin / Icons / UiSvg):
##
##   ui_skin_demo   buttons (every state), panels (layered + 9-slice at several sizes), bars,
##                  slider, toggles, checkboxes and ~30 icons (48 / 24 / 96 px, tinted,
##                  locked, badge, legacy fallback) through the new APIs; ui_pack.json +
##                  icon_map.demo.json. tools/shoot_matrix.sh ui_skin_demo <dir> quick --audit
##                  (--scroll=end: the bottom half, for phones)
##   ui_skin_bench  loads N SVG icons one way and prints BENCH lines (time, memory):
##                  --mode=dpi|raster|imported  --n=300  --dir=<res:// or absolute dir of .svg>
##                  (imported = res://<dir> already imported by Godot as CompressedTexture2D)

const NAMES := ["ui_skin_demo", "ui_skin_bench"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	match name:
		"ui_skin_demo":
			return _demo()
		"ui_skin_bench":
			return _bench()
	return null


static func _arg(key: String, def: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var shot := tree.root.get_node_or_null("Shot") if tree else null
	return def if shot == null else String(shot.get("args").get(key, def))


# ---------------------------------------------------------------- demo

static func _demo() -> Node:
	Icons.use_demo_map()
	var root := CanvasLayer.new()
	root.name = "UiSkinDemo"
	var bg := ColorRect.new()
	bg.color = UiPalette.INK
	UiTheme.full_rect(bg)
	root.add_child(bg)
	var ui := Control.new()
	ui.theme = UiTheme.get_theme()
	UiTheme.full_rect(ui)
	root.add_child(ui)
	# Phones can't fit it all: it scrolls (--scroll=end shoots the bottom half).
	var col := UiTheme.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(col)
	var m := UiTheme.margin(sc, 24, 24, 24, 24)
	UiTheme.full_rect(m)
	ui.add_child(m)
	if _arg("scroll", "") == "end":
		sc.ready.connect(func() -> void:
			await sc.get_tree().process_frame
			await sc.get_tree().process_frame
			sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value))
	col.ready.connect(func() -> void:
		var sm := UiTheme.safe_margins(col)
		m.add_theme_constant_override("margin_top", int(sm.top))
		m.add_theme_constant_override("margin_bottom", int(sm.bottom))
		m.add_theme_constant_override("margin_left", int(sm.left))
		m.add_theme_constant_override("margin_right", int(sm.right)))

	var head := UiTheme.label("UI SKIN DEMO  ·  %s" % ("DPITexture" if UiSvg.mode == UiSvg.Mode.DPI else "raster"),
		30, UiPalette.GOLD_BRIGHT, true, 6)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 40
	col.add_child(head)

	# Buttons: every state of every piece, as static boxes (a shot can't hover / press).
	var states := ["normal", "hover", "pressed", "disabled", "focus"]
	var brow := _flow()
	for piece in ["button_primary", "button_secondary", "button_danger", "button_success"]:
		for st in states:
			if piece != "button_primary" and st in ["hover", "focus"]:
				continue
			brow.add_child(_box(piece, st, st.to_upper() if piece == "button_primary" else piece.substr(7).to_upper(), Vector2(0, 88)))
	col.add_child(_section("Buttons  (UiSkin.stylebox / apply_button)", brow))

	# Live Buttons + 9-slice stretch.
	var live := _flow()
	var b := Button.new()
	b.text = "ROLL"
	b.custom_minimum_size = Vector2(260, 96)
	UiSkin.apply_button(b, "button_primary")
	live.add_child(b)
	var b2 := Button.new()
	b2.text = "Wide secondary button"
	b2.custom_minimum_size = Vector2(420, 72)
	UiSkin.apply_button(b2, "button_secondary")
	live.add_child(b2)
	var b3 := Button.new()
	b3.text = "Tall"
	b3.custom_minimum_size = Vector2(120, 150)
	UiSkin.apply_button(b3, "button_danger")
	live.add_child(b3)
	var b4 := Button.new()
	b4.text = "Tinted plaque"
	b4.custom_minimum_size = Vector2(240, 88)
	UiSkin.apply_button(b4, "button_primary", {"tint": UiPalette.class_color("mage")})
	live.add_child(b4)
	col.add_child(_section("Live Buttons: 9-slice at 260x96, 420x72, 120x150, per-use tint", live))

	# Panels.
	var prow := _flow()
	var pm := PanelContainer.new()
	UiSkin.apply_panel(pm, "panel_main")
	pm.custom_minimum_size = Vector2(340, 150)
	pm.add_child(UiTheme.para("panel_main: layered container + thin frame (UiLayeredStyleBox)", 22, UiPalette.TEXT))
	prow.add_child(pm)
	for spec in [["panel_card", "normal", Vector2(200, 110), {}], ["panel_card", "selected", Vector2(200, 110), {}],
			["panel_card", "normal", Vector2(120, 180), {"tint": UiPalette.class_color("druid").darkened(0.45)}],
			["panel_main", "normal", Vector2(110, 70), {}]]:
		var p := PanelContainer.new()
		UiSkin.apply_panel(p, spec[0], spec[1], spec[3])
		p.custom_minimum_size = spec[2]
		p.add_child(UiTheme.label(spec[1] if spec[3].is_empty() else "tint", 20, UiPalette.TEXT, false))
		prow.add_child(p)
	var fb := PanelContainer.new()
	fb.add_theme_stylebox_override("panel", UiSkin.stylebox("no_such_piece", "normal", UiTheme.panel_box("card")))
	fb.custom_minimum_size = Vector2(200, 110)
	fb.add_child(UiTheme.para("fallback: flat look", 20, UiPalette.TEXT_DIM))
	prow.add_child(fb)
	col.add_child(_section("Panels", prow))

	# Bars, slider, toggles.
	var wrow := _flow()
	var bars := UiTheme.vbox(10)
	for spec in [["bar_hp", 72.0], ["bar_xp", 35.0], ["bar_hp", 4.0]]:
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.value = spec[1]
		pb.custom_minimum_size = Vector2(320, 40)
		UiSkin.apply_progress(pb, spec[0])
		bars.add_child(pb)
	var sl := HSlider.new()
	sl.value = 60
	sl.custom_minimum_size = Vector2(320, 48)
	UiSkin.apply_slider(sl, "slider")
	bars.add_child(sl)
	wrow.add_child(bars)
	var tg := UiTheme.vbox(8)
	for on in [true, false]:
		var cb := CheckButton.new()
		cb.text = "Toggle " + ("on" if on else "off")
		cb.button_pressed = on
		UiSkin.apply_toggle(cb, "toggle", 64)
		tg.add_child(cb)
		var ck := CheckBox.new()
		ck.text = "Checkbox " + ("on" if on else "off")
		ck.button_pressed = on
		UiSkin.apply_toggle(ck, "checkbox", 40)
		tg.add_child(ck)
	wrow.add_child(tg)
	col.add_child(_section("Bars (apply_progress), slider (apply_slider), toggles (apply_toggle)", wrow))

	# Icons.
	var ids := Icons.load_map_file(Icons.DEMO_MAP_PATH).keys()
	var irow := _flow(10)
	for id in ids:
		irow.add_child(_icon_cell(Icons.rect(id, 48), id))
	irow.add_child(_icon_cell(Icons.rect("rune_ember", 48), "fallback"))
	irow.add_child(_icon_cell(Icons.rect("chest", 48, {"saturation": 0.0}), "locked"))
	irow.add_child(_icon_cell(Icons.rect("pause", 48, UiPalette.HP), "tint"))
	col.add_child(_section("Icons 48 px (Icons.rect; demo map; 'fallback' = unmapped glyph)", irow))
	var srow := _flow(6)
	for id in ["heart", "coin", "shield", "sword", "skull", "star", "potion", "gear", "key_space"]:
		srow.add_child(Icons.rect(id, 24))
	for id in ["heart", "coin", "crown", "trophy", "dice"]:
		srow.add_child(Icons.rect(id, 96))
	col.add_child(_section("Icons at 24 px and 96 px (crispness)", srow))

	# The SVG decision, side by side: DPITexture | 1x raster | 2x raster + mipmaps (UiIcons.tex).
	var crow := _flow(18)
	for spec in [["DPITexture", 0], ["1x raster", 1], ["2x + mips", 2]]:
		var cell := UiTheme.hbox(4)
		for id in ["crown", "coin", "trophy"]:
			for px in [24, 40]:
				var r: TextureRect
				if spec[1] == 0:
					r = Icons.rect(id, px)
				else:
					r = Icons.rect(id, px)
					r.texture = Icons.tex(id, px * int(spec[1]))
					if spec[1] == 2:
						r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				cell.add_child(r)
		cell.add_child(UiTheme.label(spec[0], 18, UiPalette.TEXT_MUTED, false))
		crow.add_child(cell)
	col.add_child(_section("Same art three ways (24 / 40 px)", crow))
	return root


static func _flow(sep: int = 12) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


static func _section(title: String, body: Control) -> Control:
	var v := UiTheme.vbox(6)
	v.add_child(UiTheme.para(title, 20, UiPalette.TEXT_DIM, 600))
	v.add_child(body)
	return v


static func _box(piece: String, state: String, text: String, min_size: Vector2) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.stylebox(piece, state))
	p.custom_minimum_size = min_size
	var l := UiTheme.label(text, 22, UiPalette.TEXT_DARK if piece == "button_primary" and state != "disabled" else UiPalette.TEXT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func _icon_cell(r: TextureRect, caption: String) -> Control:
	var v := UiTheme.vbox(2)
	v.custom_minimum_size.x = 66
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(r)
	var l := UiTheme.label(caption, 16, UiPalette.TEXT_MUTED, false, 0, false, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 66
	v.add_child(l)
	return v


# ---------------------------------------------------------------- bench

static func _bench() -> Node:
	var n := Control.new()
	n.name = "UiSkinBench"
	UiTheme.full_rect(n)
	n.ready.connect(_run_bench.bind(n), CONNECT_DEFERRED)
	return n


static func _svg_files(dir: String, out: PackedStringArray, limit: int) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		if out.size() >= limit:
			return
		if f.ends_with(".svg"):
			out.append(dir.path_join(f))
	for d in da.get_directories():
		_svg_files(dir.path_join(d), out, limit)


static func _run_bench(n: Control) -> void:
	var mode := _arg("mode", "dpi")
	var count := int(_arg("n", "300"))
	var px := int(_arg("px", "48"))
	var dir := _arg("dir", "res://assets/ui/icons")
	var files := PackedStringArray()
	_svg_files(dir, files, count)
	var tree := n.get_tree()
	for i in 3:
		await tree.process_frame
	var ram0 := Performance.get_monitor(Performance.MEMORY_STATIC)
	var t0 := Time.get_ticks_usec()
	var texs: Array[Texture2D] = []
	for f in files:
		var t: Texture2D
		match mode:
			"imported":
				t = load(f)
			"raster":
				t = UiSvg.raster(FileAccess.get_file_as_string(f), px * 2)
			_:
				var src := FileAccess.get_file_as_string(f)
				var sz := UiSvg.svg_size(src)
				t = DPITexture.create_from_string(src, float(px) / maxf(sz.x, sz.y))
		texs.append(t)
	var t_create := Time.get_ticks_usec() - t0
	var grid := GridContainer.new()
	grid.columns = 20
	n.add_child(grid)
	for t in texs:
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(px, px)
		if mode != "dpi":
			r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		grid.add_child(r)
	var t1 := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var t_draw := Time.get_ticks_usec() - t1
	for i in 3:
		await tree.process_frame
	var ram := Performance.get_monitor(Performance.MEMORY_STATIC) - ram0
	# VRAM of exactly these textures: what freeing them gives back (the harness frees the
	# previous scene around the same time, so a before/after delta is noise)
	var vram_a := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	grid.queue_free()
	texs.clear()
	for i in 4:
		await tree.process_frame
	var vram := vram_a - Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	print("BENCH mode=%s n=%d px=%d oversampling=%.3f create_ms=%.1f first_draw_ms=%.1f vram_kb=%.0f ram_kb=%.0f" % [
		mode, count if files.size() >= count else files.size(), px, n.get_viewport().get_oversampling(), t_create / 1000.0,
		t_draw / 1000.0, vram / 1024.0, ram / 1024.0])
