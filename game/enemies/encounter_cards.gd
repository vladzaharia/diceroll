class_name EncounterCards
extends RefCounted
## First-encounter cards (§3A.6): the first time a profile meets each affix and each new enemy
## id, a card shows the rule next to the live enemy model. Once per profile: the seen lists
## live in user://seen.json next to the profile (merged with Profile.records.seen when core
## records it). AUTO (and 4x playback) shows a toast instead and never stops.
##
##   await EncounterCards.after_combat_started(c, ev)   # EventPlayer, after the enemies rise
##   EncounterCards.cards_off = true                     # scenarios that must not stop

## The 2026-09-28 enemies (older ids never get a card: players know them).
const NEW_ENEMIES := ["bone_cutthroat", "bone_golem", "orc_raider", "orc_drummer", "werewolf", "fallen_paladin",
	"mini_moonfang", "mini_orc_warchief"]
## Seconds a card waits for a tap before it closes on its own.
const HOLD := 7.0

static var cards_off := false
static var _seen: Dictionary = {}
static var _path := ""


## Seen lists for the controller's profile: {enemies: [], affixes: []}.
static func seen(c: GameController) -> Dictionary:
	var path := c.profile_path.get_base_dir().path_join("seen.json") if c.persist_profile else ""
	if not _seen.is_empty() and path == _path:
		return _seen
	_path = path
	_seen = {"enemies": [], "affixes": []}
	if path != "" and FileAccess.file_exists(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary:
			for k in ["enemies", "affixes"]:
				for x in (d as Dictionary).get(k, []):
					(_seen[k] as Array).append(String(x))
	var rec: Variant = c.profile.records.get("seen", null) if c.profile else null
	if rec is Dictionary:
		for k in ["enemies", "affixes"]:
			var v: Variant = (rec as Dictionary).get(k, [])
			if v is Array:
				for x in v:
					if not (_seen[k] as Array).has(String(x)):
						(_seen[k] as Array).append(String(x))
	return _seen


static func _save() -> void:
	if _path == "":
		return
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_seen))


## Forgets everything seen (tests / scenarios).
static func reset() -> void:
	_seen = {}
	_path = ""


static func note_affix(c: GameController, a: String) -> void:
	var s := seen(c)
	if not (s.affixes as Array).has(a):
		(s.affixes as Array).append(a)
		_save()


## Cards (or toasts) for whatever this fight shows for the first time.
static func after_combat_started(c: GameController, ev: Dictionary) -> void:
	AffixTips.ensure(c)
	var s := seen(c)
	var items: Array = []
	for e: Dictionary in ev.get("enemies", []):
		var id := String(e.get("id", ""))
		if not (s.enemies as Array).has(id):
			(s.enemies as Array).append(id)
			if id in NEW_ENEMIES:
				items.append({"kind": "enemy", "id": id, "enemy": e})
		for a in e.get("affixes", []):
			if not (s.affixes as Array).has(String(a)):
				(s.affixes as Array).append(String(a))
				items.append({"kind": "affix", "id": String(a), "enemy": e})
	if items.is_empty():
		return
	_save()
	if cards_off:
		return
	var auto := (c.auto != null and c.auto.enabled) or c.condensed()
	for it: Dictionary in items:
		if auto:
			var nm := AffixDefs.name_of(it.id) if it.kind == "affix" else String(EnemyDefs.def(it.id).name)
			var icon := String(SkinRules.AFFIXES[it.id].icon) if it.kind == "affix" else "skull"
			c.overlay.toast("New %s: %s" % ["affix" if it.kind == "affix" else "foe", nm], icon,
				SkinRules.affix_color(it.id).lightened(0.3) if it.kind == "affix" else UiPalette.GOLD_BRIGHT)
		else:
			var card := Card.new()
			c.overlay.add_child(card)
			card.setup(c, it)
			await card.closed


## Title / rule lines for an item.
static func text_for(it: Dictionary) -> Dictionary:
	if it.kind == "affix":
		var cd := AffixDefs.card(it.id)
		return {"caption": "NEW AFFIX", "title": String(cd.name), "body": String(cd.desc),
			"extra": "Look for it: %s" % String(SkinRules.AFFIX_LOOK.get(it.id, "")), "color": SkinRules.affix_color(it.id)}
	var d := EnemyDefs.def(it.id)
	var e: Dictionary = it.get("enemy", {})
	var lines := PackedStringArray()
	lines.append("%d HP" % int(e.get("max_hp", d.hp)))
	var pat := PackedStringArray()
	for q: Dictionary in EnemyDefs.pattern(it.id, 1):
		pat.append("%s %d" % [String(q.kind).capitalize(), int(q.value)] if int(q.value) > 0 else String(q.kind).capitalize())
	lines.append(" > ".join(pat))
	return {"caption": "MINI-BOSS" if EnemyDefs.is_miniboss(it.id) else "NEW FOE", "title": String(d.name),
		"body": String(RULES.get(it.id, "")), "extra": "  ·  ".join(lines), "color": UiPalette.GOLD_BRIGHT}


## One line per new enemy: what makes it different.
const RULES := {
	"bone_cutthroat": "Pierce: its attacks ignore your Block.",
	"bone_golem": "Slow and telegraphed: it braces, takes aim, then smashes for 16.",
	"orc_raider": "Frenzy: +2 attack each time it survives your attack (max +6). Kill it in one blow.",
	"orc_drummer": "Rally: its drum gives EVERY enemy +2 attack for the fight. Kill it first.",
	"werewolf": "At half HP it turns into a wolf: drops its Block, then drains and bites harder.",
	"fallen_paladin": "Heals every enemy for 6, then raises its shield. A healer-tank leader.",
	"mini_moonfang": "Turns into a silver wolf at half HP: its Block drops, then it drains for 10.",
	"mini_orc_warchief": "Summons Orc Raiders and rallies them with its war drum.",
}


## The card: a dimmed screen, the enemy model turning in a little stage, the rule. Tap closes.
class Card extends Control:
	signal closed
	var _done := false

	func setup(c: GameController, it: Dictionary) -> void:
		theme = UiTheme.get_theme()
		UiTheme.full_rect(self)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var view := c.overlay.size
		var portrait := view.x < view.y * 0.9
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.0, 0.05, 0.6)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(UiTheme.full_rect(dim))
		var t := EncounterCards.text_for(it)
		var col: Color = t.color
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.06, 0.05, 0.13, 0.97), 28, 4, col, 22, Color(col, 0.35), Vector2.ZERO), 26, 20))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		var row: BoxContainer = UiTheme.vbox(10) if portrait else UiTheme.hbox(22)
		p.add_child(row)
		var w := minf(view.x - 110.0, 470.0) if portrait else minf(view.x * 0.42, 520.0)
		var stage_px := Vector2(minf(w * 0.7, 300.0), minf(w * 0.7, 300.0) * 1.1) if portrait else Vector2(280, 320)
		row.add_child(_model(it, stage_px, col, c.board.biome_id if c.board else ""))
		var colm := UiTheme.vbox(6)
		colm.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(colm)
		var cap := UiTheme.hbox(10)
		if it.kind == "affix":
			cap.add_child(UiIcons.rect(String(SkinRules.AFFIXES[it.id].icon), 44, col.lightened(0.2)))
		cap.add_child(UiTheme.label(String(t.caption), 22, col.lightened(0.3), false, 0, false, 800))
		colm.add_child(cap)
		var fs := 56
		var tw := UiTheme.display_font().get_string_size(String(t.title), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.4
		if tw > w:
			fs = int(fs * w / tw)
		colm.add_child(UiTheme.label(String(t.title).to_upper(), fs, col.lerp(UiPalette.GOLD_BRIGHT, 0.3), true, int(fs * 0.16)))
		var body := UiTheme.para(String(t.body), 26, UiPalette.TEXT, 600)
		body.custom_minimum_size.x = w
		colm.add_child(body)
		if String(t.extra) != "":
			var ex := UiTheme.para(String(t.extra), 21, UiPalette.TEXT_DIM, 500)
			ex.custom_minimum_size.x = w
			colm.add_child(ex)
		colm.add_child(UiTheme.spacer(4))
		colm.add_child(UiTheme.label("Tap to continue", 20, UiPalette.TEXT_MUTED, false, 0, false, 700))
		p.reset_size()
		var s := p.get_combined_minimum_size()
		p.size = s
		p.position = (view - s) * 0.5 - Vector2(0, view.y * 0.04)
		p.pivot_offset = s * 0.5
		p.scale = Vector2(0.6, 0.6)
		modulate.a = 0.0
		var tw2 := create_tween()
		tw2.tween_property(self, "modulate:a", 1.0, 0.15)
		tw2.parallel().tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Audio.play_sfx("page")
		get_tree().create_timer(EncounterCards.HOLD, false).timeout.connect(_close)

	## A small 3D stage (own world) with the enemy (and its affix overlay) turning slowly.
	func _model(it: Dictionary, px: Vector2, col: Color, biome: String) -> Control:
		var box := SubViewportContainer.new()
		box.stretch = true
		box.custom_minimum_size = px
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		box.add_child(vp)
		var e: Dictionary = it.get("enemy", {})
		var id := String(e.get("id", it.id))
		var ctx := EnemyLooks.spawn_context(e if not e.is_empty() else id, -1, [], biome)
		var ch := EnemyLooks.create(id, true, ctx)
		var pivot := Node3D.new()
		vp.add_child(pivot)
		pivot.add_child(ch)
		var h := EnemyLooks.hud_height(id)
		var k := 1.0 / maxf(EnemyLooks.scale_of(id), 1.0)
		ch.scale = Vector3.ONE * k
		var spin := pivot.create_tween().set_loops()
		spin.tween_property(pivot, "rotation:y", deg_to_rad(25.0), 2.4).from(deg_to_rad(-25.0)).set_trans(Tween.TRANS_SINE)
		spin.tween_property(pivot, "rotation:y", deg_to_rad(-25.0), 2.4).set_trans(Tween.TRANS_SINE)
		var cam := Camera3D.new()
		cam.fov = 30.0
		var top := h * k
		cam.position = Vector3(0, top * 0.62, top * 2.3 + 1.2)
		cam.look_at_from_position(cam.position, Vector3(0, top * 0.45, 0))
		vp.add_child(cam)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, 30, 0)
		sun.light_energy = 1.3
		vp.add_child(sun)
		var rim := OmniLight3D.new()
		rim.light_color = col
		rim.light_energy = 2.0
		rim.omni_range = 5.0
		rim.position = Vector3(0, top, -1.6)
		vp.add_child(rim)
		var env := WorldEnvironment.new()
		var en := Environment.new()
		en.background_mode = Environment.BG_CLEAR_COLOR
		en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		en.ambient_light_color = Color(0.55, 0.52, 0.62)
		en.ambient_light_energy = 0.9
		env.environment = en
		vp.add_child(env)
		var floor := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(2.4, 2.4)
		floor.mesh = pm
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.albedo_texture = Props.particle_texture("dot")
		fm.albedo_color = Color(col, 0.5)
		floor.material_override = fm
		floor.position.y = 0.01
		vp.add_child(floor)
		return box

	func _gui_input(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if (mb and mb.pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			accept_event()
			_close()

	func _close() -> void:
		if _done or not is_inside_tree():
			return
		_done = true
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.2)
		t.tween_callback(func() -> void:
			closed.emit()
			queue_free())
