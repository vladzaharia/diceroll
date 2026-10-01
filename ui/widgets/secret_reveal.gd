class_name SecretReveal
extends PanelContainer
## The secret hero's reveal card (results screen, when trick_or_treat unlocks the Monster Kid):
## it starts as the "???" mystery card with a dark silhouette, shakes harder and harder, then
## BOO!: a green flash, the comic burst, confetti, the dino hood drops (HeroLook.boo_head) and
## the hero cheers under "MONSTER KID  ·  NEW SECRET HERO".
##
##   var r := SecretReveal.make("monster_kid")
##   await r.play()          # or r.finish_now() for a still

const BOO_GREEN := Color("9cf05a")

var class_id := "monster_kid"
var revealed := false
var portrait: HeroPortrait
var _kicker: Label
var _name: Label
var _hint: Label
var _boo: Label
var _gen := 0
var _kicker_chip: PanelContainer


static func make(id: String) -> SecretReveal:
	var r := SecretReveal.new()
	r.class_id = id
	r._build()
	return r


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(false)
	var col := UiTheme.vbox(4)
	add_child(col)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 300)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	portrait = HeroPortrait.new()
	portrait.ring_color = Color(0.4, 0.35, 0.55)
	portrait.spin = 0.0
	portrait.zoom = 1.15
	portrait.set_hero(class_id, "default", false, false)
	portrait.silhouette = true
	holder.add_child(UiTheme.full_rect(portrait))
	_boo = UiTheme.label("BOO!", 96, BOO_GREEN, true, 16, true)
	_boo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boo.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_boo.visible = false
	holder.add_child(UiTheme.full_rect(_boo))
	# the kicker is a chip like the other unlock cards' tags: violet "secret", BOO green once known
	_kicker_chip = PanelContainer.new()
	_kicker_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kicker_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_kicker = UiTheme.label("A SECRET STIRS…", 18, Color("c79bff"), false, 0, false, 800)
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kicker_chip.add_child(_kicker)
	OptionCard.style_tag(_kicker_chip, _kicker, Color("c79bff"), 18)
	col.add_child(_kicker_chip)
	_name = UiTheme.label("???", 44, UiPalette.TEXT_MUTED, true, 8, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_name)
	_hint = UiTheme.para(ClassCard.secret_hint(class_id), 19, UiPalette.TEXT_DIM, 600)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)


func _style(on: bool) -> void:
	# a card like the other unlock cards (accent rim: BOO green once revealed, violet before)
	var sb := UiTheme.tile_box("normal", BOO_GREEN if on else Color(0.55, 0.45, 0.75))
	UiTheme.pad(sb, 16, 14)
	sb.content_margin_bottom = maxf(sb.content_margin_bottom, 14.0)
	add_theme_stylebox_override("panel", sb)


## The whole beat: rattle, BOO!, reveal (about 2.6 s).
func play() -> void:
	_gen += 1
	var gen := _gen
	pivot_offset = size * 0.5
	for k in 3:
		if gen != _gen or not is_inside_tree():
			return
		var amp := 2.0 + k * 2.5
		var t := create_tween()
		for j in 4:
			t.tween_property(self, "rotation_degrees", amp * (1.0 if j % 2 == 0 else -1.0), 0.05)
		t.tween_property(self, "rotation_degrees", 0.0, 0.05)
		UiTheme.sfx("dice_select")
		await get_tree().create_timer(0.42).timeout
	if gen != _gen or not is_inside_tree():
		return
	_reveal(true)


## Jumps to the revealed state (screenshots, a second look), without the burst.
func finish_now() -> void:
	_gen += 1
	_reveal(false)


func _reveal(burst: bool) -> void:
	revealed = true
	rotation_degrees = 0.0
	portrait.silhouette = false
	portrait.ring_color = BOO_GREEN
	portrait.spin = 0.35
	_style(true)
	_kicker.text = "NEW SECRET HERO"
	OptionCard.style_tag(_kicker_chip, _kicker, BOO_GREEN, 20)
	_name.text = String(HeroDefs.DATA[class_id].name).to_upper()
	_name.label_settings = UiTheme.label_settings(46, UiPalette.TEXT, true, 8, UiPalette.OUTLINE, true)
	_hint.text = ClassInfo.tagline(class_id)
	_boo.visible = true
	_boo.pivot_offset = _boo.size * 0.5
	if portrait.hero:
		HeroLook.boo_head(portrait.hero, true)
		portrait.hero.play_once("taunt" if portrait.hero.has_anim("taunt") else "cheer")
	if not burst or not is_inside_tree():
		_boo.modulate.a = 0.85
		return
	UiTheme.sfx("fanfare")
	Fx.flash(self, Color(0.6, 1.0, 0.4, 0.45), 0.4)
	var at := get_global_rect().get_center() - Vector2(0, 60)
	var ctl := _host_control()
	if ctl:
		Fx.confetti(ctl, at, 36)
	_boo.scale = Vector2(0.3, 0.3)
	_boo.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_boo, "scale", Vector2(1.25, 1.25), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_boo, "scale", Vector2.ONE, 0.18)
	t.tween_interval(0.9)
	t.tween_property(_boo, "modulate:a", 0.0, 0.4)
	UiTheme.pop(self, 1.06, 0.3)
	var gen := _gen
	await get_tree().create_timer(1.3).timeout
	if gen == _gen and portrait.hero and is_inside_tree():
		HeroLook.boo_head(portrait.hero, false)
		portrait.cheer()


## The topmost full-screen Control to throw confetti on.
func _host_control() -> Control:
	var n: Node = self
	var last: Control = null
	while n:
		if n is Control:
			last = n
		n = n.get_parent()
	return last
