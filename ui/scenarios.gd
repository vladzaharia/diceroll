extends RefCounted
## UI scenarios for the screenshot harness (tools/shot.gd). Each builds a real GameFlow in a
## representative state, a placeholder 3D board backdrop (for contrast), a placeholder dice
## tray where the real DiceTray will sit, and the screen under test.

const NAMES := ["ui_title", "ui_class", "ui_board_hud", "ui_board_ready", "ui_combat_hud", "ui_combat_sheet",
	"ui_combo_banner", "ui_draft", "ui_rune_choice", "ui_rune_assign", "ui_shop", "ui_shop_pick", "ui_forge",
	"ui_event", "ui_event_duel", "ui_portal", "ui_pause", "ui_settings", "ui_victory", "ui_defeat", "ui_icons"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var flow := _flow()
	var root := Node.new()
	root.name = "UiScenario"
	var backdrop := UiBackdrop.new()
	backdrop.flow = flow
	root.add_child(backdrop)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var ui := Control.new()
	ui.theme = UiTheme.get_theme()
	UiTheme.full_rect(ui)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	match name:
		"ui_title":
			backdrop.dim = 0.35
			var t := TitleScreen.new()
			ui.add_child(t)
			t.refresh()
		"ui_class":
			backdrop.visible = false
			var c := ClassSelect.new()
			ui.add_child(c)
		"ui_board_hud", "ui_board_ready":
			if name == "ui_board_hud":
				flow.roll_board()
			ui.add_child(TrayPlaceholder.make(flow))
			var h := BoardHud.new()
			ui.add_child(h)
			h.refresh(flow)
		"ui_combat_hud", "ui_combat_sheet", "ui_combo_banner":
			_combat(flow)
			backdrop.combat = true
			ui.add_child(TrayPlaceholder.make(flow))
			var h := CombatHud.new()
			ui.add_child(h)
			h.refresh(flow)
			if name == "ui_combat_sheet":
				h.show_sheet.call_deferred(true)
			if name == "ui_combo_banner":
				var b := ComboBanner.new()
				b.hold = _arg("hold", "1") == "1"
				ui.add_child(b)
				var mult := float(_arg("mult", "3.5"))
				b.play.call_deferred(String(_arg("combo", "Full House")), mult, int(_arg("total", "64")))
		"ui_draft", "ui_rune_choice":
			flow.debug_open("draft" if name == "ui_draft" else "rune_choice")
			_modal(ui, DraftModal.new(), flow)
		"ui_rune_assign":
			flow.debug_open("rune_assign", "frost")
			_modal(ui, RuneAssignModal.new(), flow)
		"ui_shop", "ui_shop_pick":
			flow.debug_open("shop")
			var m := ShopModal.new()
			_modal(ui, m, flow)
			if name == "ui_shop_pick":
				for i in flow.offer.items.size():
					if bool(flow.offer.items[i].needs_die):
						m.begin_pick.call_deferred(i)
						break
		"ui_forge":
			flow.debug_open("forge")
			var m := ForgeModal.new()
			_modal(ui, m, flow)
			m.preselect.call_deferred(1, 0, "raise")
		"ui_event", "ui_event_duel":
			flow.debug_open("event", "shrine" if name == "ui_event" else "duel")
			_modal(ui, EventModal.new(), flow)
		"ui_portal":
			flow.debug_open("portal")
			var h := BoardHud.new()
			ui.add_child(h)
			h.refresh(flow)
			var p := PortalBanner.new()
			ui.add_child(p)
			p.refresh(flow)
		"ui_pause":
			ui.add_child(TrayPlaceholder.make(flow))
			var h := BoardHud.new()
			ui.add_child(h)
			h.refresh(flow)
			var p := PauseMenu.new()
			ui.add_child(p)
			p.refresh(flow)
			p.show_now()
		"ui_settings":
			var s := SettingsPanel.new()
			ui.add_child(s)
			s.show_now()
		"ui_victory", "ui_defeat":
			backdrop.dim = 0.4
			_finish(flow, name == "ui_victory")
			var s := SummaryScreen.new()
			ui.add_child(s)
			s.refresh(flow)
			s.show_now()
		"ui_icons":
			backdrop.visible = false
			ui.add_child(IconSheet.new())
	return root


## Harness arg (--key=value) or default.
static func _arg(key: String, def: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var shot := tree.root.get_node_or_null("Shot") if tree else null
	if shot == null:
		return def
	return String(shot.get("args").get(key, def))


static func _modal(ui: Control, m: UiModal, flow: GameFlow) -> void:
	ui.add_child(TrayPlaceholder.make(flow))
	var h := BoardHud.new()
	ui.add_child(h)
	h.refresh(flow)
	ui.add_child(m)
	m.call("refresh", flow)
	if _arg("anim", "0") == "1":
		m.open.call_deferred()
	else:
		m.show_now()


## A mid-run flow: act 2 lap 2, some gold/xp, a 5-die pool with runes and an edited face.
static func _flow() -> GameFlow:
	var cls := _arg("class", "knight")
	var f := GameFlow.new_run(cls, int(_arg("seed", "7")))
	var r := f.run
	r.act = 1
	r.lap = 2
	r.level = 3
	r.xp = 34
	r.gold = 137
	r.treasury = 18
	r.hp = 41
	r.dice.append(Die.make("frost"))
	r.dice.append(Die.make("wild"))
	r.dice[1].rune = "blade"
	r.dice[2].raise_face(0)
	r.dice[2].raise_face(0)
	r.stats.fights_won = 14
	r.stats.damage_dealt = 1842
	r.stats.damage_taken = 311
	r.stats.gold_earned = 486
	r.stats.best_combo = "Four of a Kind"
	r.stats.best_mult = 5.0
	r.stats.board_turns = 38
	r.stats.combat_turns = 41
	return f


static func _combat(f: GameFlow) -> void:
	f.debug_open("combat", "skeleton_warrior,cultist,skeleton_archer")
	var c := f.combat
	# a readable, specific roll: pair of 5s + junk, two dice marked
	var vals: Array[int] = [5, 2, 5, 1, 6]
	for i in mini(vals.size(), c.dice_values.size()):
		c.dice_values[i] = vals[i]
	f.run.block = 6
	f.combat_toggle(1)
	f.combat_toggle(3)


static func _finish(f: GameFlow, victory: bool) -> void:
	f.run.act = 3 if victory else 2
	f.run.stats.max_act = f.run.act
	f.run.level = 9 if victory else 6
	f.run.stats.victory = victory
	f.phase = GameFlow.Phase.VICTORY if victory else GameFlow.Phase.GAME_OVER


# ============================================================ placeholder backdrop

class UiBackdrop:
	extends Node3D
	## Placeholder board: a ring of coloured tiles on a floating slab, warm key light,
	## dusk background. Only for judging UI contrast in screenshots.
	var flow: GameFlow
	var dim := 0.0
	var combat := false

	const TILE_COL := {
		"start": Color("e8c060"), "forge": Color("8a9bb0"), "treasury": Color("f0b040"), "portal": Color("9060e0"),
		"enemy": Color("c04848"), "elite": Color("d08a30"), "chest": Color("d8a048"), "event": Color("7a6ad0"),
		"campfire": Color("e07a3a"), "trap": Color("6a6a78"), "empty": Color("8a8070"),
	}

	func _ready() -> void:
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color("121430")
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color("5a5a90")
		e.ambient_light_energy = 0.6
		e.tonemap_mode = Environment.TONE_MAPPER_AGX
		e.glow_enabled = true
		e.fog_enabled = true
		e.fog_light_color = Color("1a1c40")
		e.fog_density = 0.02
		env.environment = e
		add_child(env)
		var sun := DirectionalLight3D.new()
		sun.light_color = Color("ffd9a0")
		sun.light_energy = 1.4
		sun.shadow_enabled = true
		sun.rotation_degrees = Vector3(-55, -35, 0)
		add_child(sun)
		var slab := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 7.2
		cm.bottom_radius = 5.5
		cm.height = 1.6
		slab.mesh = cm
		slab.position.y = -0.95
		slab.material_override = _mat(Color("3a3448"))
		add_child(slab)
		var tiles: Array = flow.run.board.tiles if flow else []
		for i in 24:
			var p := _grid(i)
			var t := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.92, 0.3, 0.92)
			t.mesh = bm
			t.position = Vector3(p.x - 3.0, 0.0, p.y - 3.0) * 1.05
			var type := String(tiles[i].type) if i < tiles.size() else "empty"
			t.material_override = _mat(TILE_COL.get(type, Color.GRAY))
			add_child(t)
		var centre := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(2.2, 2.0, 2.2)
		centre.mesh = pm
		centre.position.y = 0.9
		centre.material_override = _mat(Color("5a5068"))
		add_child(centre)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("ff9a50")
		lamp.omni_range = 6.0
		lamp.light_energy = 2.0
		lamp.position = Vector3(0, 2.5, 0)
		add_child(lamp)
		if flow:
			var hero := Character.create(flow.run.class_id)
			var hp := _grid(flow.run.pos)
			hero.position = Vector3(hp.x - 3.0, 0.15, hp.y - 3.0) * 1.05
			hero.scale = Vector3.ONE * 0.55
			add_child(hero)
			hero.play("idle")
		var cam := Camera3D.new()
		cam.fov = 50
		add_child(cam)
		cam.current = true
		var view := get_viewport().get_visible_rect().size
		var portrait := view.y > view.x
		var dist := 16.0 if portrait else 11.0
		if combat:
			cam.position = Vector3(-2.5, 4.5, 8.0)
			cam.look_at(Vector3(0, 0.5, 1.5))
		else:
			cam.position = Vector3(0, dist * 0.8, dist * 0.75)
			cam.look_at(Vector3(0, -0.5 if portrait else 0.0, 0.8 if portrait else 0.0))
		if dim > 0.0:
			var layer := CanvasLayer.new()
			layer.layer = -1
			add_child(layer)
			var r := ColorRect.new()
			r.color = Color(0.03, 0.03, 0.08, dim)
			UiTheme.full_rect(r)
			layer.add_child(r)

	func _grid(i: int) -> Vector2:
		# 7x7 perimeter, clockwise from bottom-left corner
		if i <= 6:
			return Vector2(i, 6)
		if i <= 12:
			return Vector2(6, 6 - (i - 6))
		if i <= 18:
			return Vector2(6 - (i - 12), 0)
		return Vector2(0, i - 18)

	func _mat(c: Color) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		return m


# ============================================================ placeholder dice tray

class TrayPlaceholder:
	extends Control
	## Stands in for game/dice DiceTray: bottom band with the current dice drawn as DieFaces.
	var values: Array[int] = []
	var runes: Array[String] = []
	var marked: Array[bool] = []

	static func make(flow: GameFlow) -> TrayPlaceholder:
		var t := TrayPlaceholder.new()
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTheme.full_rect(t)
		var vals: Array[int] = []
		if flow.combat != null:
			vals = flow.combat.dice_values.duplicate()
			t.marked = flow.combat.marked.duplicate()
		elif not flow.board_roll.is_empty():
			vals = flow.board_roll.duplicate()
		for i in flow.run.dice.size():
			t.values.append(vals[i] if i < vals.size() else 0)
			t.runes.append(flow.run.dice[i].rune)
		return t

	func _ready() -> void:
		resized.connect(_build)
		_build.call_deferred()

	func _build() -> void:
		for c in get_children():
			c.queue_free()
		var h := UiTheme.tray_height(size)
		var band := Panel.new()
		band.add_theme_stylebox_override("panel", UiTheme.box(Color(0.1, 0.07, 0.06, 0.9), 36, 3, Color(0.5, 0.35, 0.2, 0.7), 20))
		band.position = Vector2(12, size.y - h + 6)
		band.size = Vector2(size.x - 24, h - 18)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(band)
		var n := values.size()
		var px := minf(110.0, (minf(size.x, 900.0) - 60.0) / maxf(1, n) - 16.0)
		var total := n * px + (n - 1) * 18.0
		for i in n:
			var f := DieFace.make(maxi(1, values[i]), runes[i], false, px)
			f.star = runes[i] == "wild"
			f.glyph = "" if values[i] > 0 else "?"
			f.position = Vector2((size.x - total) * 0.5 + i * (px + 18.0), size.y - h * 0.5 - px * 0.5 - (22.0 if i < marked.size() and marked[i] else 0.0))
			f.size = Vector2(px, px)
			f.selected = i < marked.size() and marked[i]
			add_child(f)


# ============================================================ icon sheet

class IconSheet:
	extends Control

	func _ready() -> void:
		UiTheme.full_rect(self)
		var bg := ColorRect.new()
		bg.color = UiPalette.NAVY
		add_child(UiTheme.full_rect(bg))
		var grid := GridContainer.new()
		grid.columns = 6
		grid.position = Vector2(24, 24)
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 8)
		add_child(grid)
		var dir := DirAccess.open(UiIcons.DIR)
		var names: Array[String] = []
		for f in dir.get_files():
			if f.ends_with(".svg"):
				names.append(f.get_basename())
		names.sort()
		for n in names:
			var col := UiTheme.vbox(0)
			col.custom_minimum_size = Vector2(100, 0)
			col.add_child(UiIcons.rect(n, 56))
			var l := UiTheme.label(n, 14, UiPalette.TEXT_DIM, false)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(l)
			grid.add_child(col)
		var row := UiTheme.hbox(10)
		row.position = Vector2(24, 1100)
		add_child(row)
		for r in Runes.IDS:
			row.add_child(RuneBadge.make(r, 50))
