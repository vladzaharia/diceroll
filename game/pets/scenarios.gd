extends RefCounted
## WP-E3 scenarios (in-run meta presentation) for the screenshot harness (tools/shot.gd).
##
##  pets_gallery     all 6 pets at L1 (front row) and L10 (back row), charge pips part-full
##                   (--act=<effect> loops that action on every pet)
##  hud_potions      the run HUD with a max-profile belt of 3 potion types and the pet meter
##                   (--tip=N opens the tooltip of belt slot N; --combat=1 in a fight)
##  board_pet        a pet following the hero along a hop (--pet=<id>, default pumpkin_sprite)
##  combat_pet_acts  a fight where each pet (or --pet=<id>) fires its effect in turn
##  level_up_auto    an automatic level-up (+max HP toast, level badge pulse)
##  events_misc      second_boss, face_cursed, trait_triggered, a doubles board roll and a
##                   Crowns pop, one after another (--only=<event> plays just that one)
##
## Every run scenario starts from the max meta profile (MetaPresets) so the belt holds 3
## slots and a pet is equipped. Common args: --pet=<id> --level=N --seed=N --speed=N.

const NAMES := ["pets_gallery", "hud_potions", "board_pet", "combat_pet_acts", "level_up_auto", "events_misc"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	if name == "pets_gallery":
		return _gallery()
	var d := MetaScenario.new()
	d.name = "MetaScenario"
	d.scenario = name
	return d


# ======================================================================= gallery

static func _gallery() -> Node3D:
	var root := Node3D.new()
	root.name = "PetsGallery"
	var actors: Script = load("res://game/actors/scenarios.gd")
	actors._add_environment(root)
	actors._add_floor(root)
	var args: Dictionary = Shot.args if Shot else {}
	var act := String(args.get("act", ""))
	var cam := _GalleryCam.new()
	root.add_child(cam)
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var pets: Array[PetView] = []
	var ids: Array = PetDefs.IDS
	if args.has("pet"):
		ids = [String(args.pet)]
		cam.close = true
	for i in ids.size():
		for lv in [1, 10]:
			var id := String(ids[i])
			var p := PetView.create(id, lv)
			root.add_child(p)
			p.set_charge(PetDefs.size(id) if lv == 10 else PetDefs.size(id) / 2, PetDefs.size(id))
			pets.append(p)
			var l := Label3D.new()
			l.text = "%s\nL%d" % [PetDefs.name_of(id), lv]
			l.font = font
			l.font_size = 44
			l.pixel_size = 0.004
			l.outline_size = 12
			l.outline_modulate = Color(0.08, 0.06, 0.1, 0.9)
			l.modulate = Color(1.0, 0.86, 0.5) if lv == 10 else Color(0.9, 0.9, 1.0)
			l.rotation.x = -PI * 0.5
			p.add_child(l)
			l.position = Vector3(0, 0.02, 0.62)
	cam.pets = pets
	if act != "":
		root.ready.connect(func() -> void: _loop_act(root, pets, act), CONNECT_ONE_SHOT)
	return root


static func _loop_act(root: Node3D, pets: Array[PetView], act: String) -> void:
	while root.is_inside_tree():
		for p in pets:
			p.home = p.global_position
			var tgt := p.global_position + Vector3(0.0, PetView.HOVER, -1.2)
			p.act(act, tgt if act in ["bite", "heal"] else Vector3.INF)
		await root.get_tree().create_timer(1.6).timeout


## Lays the pets out (portrait: 3 columns x 4 rows; landscape: 6 x 2) and frames them.
class _GalleryCam extends Camera3D:
	var pets: Array[PetView] = []
	var close := false

	func _ready() -> void:
		fov = 24.0
		get_viewport().size_changed.connect(_fit)
		_fit.call_deferred()

	func _fit() -> void:
		var s := get_viewport().get_visible_rect().size
		var portrait := s.y > s.x
		keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
		if close:
			# one pet, L1 and L10 side by side, filling the frame
			for k in pets.size():
				pets[k].position = Vector3((k - 0.5) * 1.3, 0.0, 0.0)
			var t := Vector3(0.0, 0.85, 0.2)
			var dd := 5.0 if portrait else 4.4
			var pp := deg_to_rad(24.0)
			position = t + Vector3(0.0, sin(pp), cos(pp)) * dd
			look_at(t)
			return
		var cols := 3 if portrait else 6
		var rows := 4 if portrait else 2
		var gap := Vector2(1.3, 2.0) if portrait else Vector2(1.25, 2.2)
		for k in pets.size():
			var pet_i := k / 2
			var lv_i := k % 2
			var col := pet_i % cols
			var row := (pet_i / cols) * 2 + lv_i
			pets[k].position = Vector3((col - (cols - 1) * 0.5) * gap.x, 0.0, (row - (rows - 1) * 0.5) * gap.y)
		var target := Vector3(0.0, 0.75, 0.2)
		var dist := 11.0 if portrait else 12.5
		var pitch := deg_to_rad(46.0 if portrait else 42.0)
		position = target + Vector3(0.0, sin(pitch), cos(pitch)) * dist
		look_at(target)
