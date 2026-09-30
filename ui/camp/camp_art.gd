class_name CampArt
extends RefCounted
## Pack icons and small ornaments for the Camp and its stations (UI reskin, slice d):
## medallions (the icon on a 3D Round disc in an accent colour), title rows, count badges,
## NEW dots, tier stars and chips with an icon. Everything draws the RhosGFX art through
## `Icons` / `UiSkin` and falls back to today's drawn glyphs and flat boxes when the paid pack
## is absent (fresh clone), so no Camp screen ever renders an empty icon.
##
##   CampArt.medal("petg_wick", 64, CampInfo.PET_COLOR.wick)          # accent disc + pack glyph
##   CampArt.medal("mg_plinko", 64, col, true)                          # locked: greyed
##   CampArt.title_row("pack_storm", ACCENT, "Storm", "3 ITEMS", 56)
##   CampArt.count_badge(3)    # red count, 1..3; above that a dot (station tags)
##   CampArt.icon("lock", 22)  # any id; unmapped pack ids use the legacy glyph

## Pack id -> today's drawn glyph (ui/icons/*.svg), used when the pack art is not imported.
## "" = a drawn padlock (CampUi.LockGlyph).
const LEGACY := {
	"station_armory": "anvil", "station_workshop": "dice", "station_pet_den": "heart", "station_arcade": "star",
	"station_wardrobe": "wardrobe", "station_setup": "flag", "wardrobe_hats": "wardrobe", "wardrobe": "wardrobe",
	"sigil": "star", "crown": "crown", "skin_prestige": "crown",
	"petg_pumpkin_sprite": "heart", "petg_skull_buddy": "skull", "petg_lantern_ghost": "flame",
	"petg_crystal_wisp": "reroll", "petg_guard_die": "shield", "petg_coin_mimic": "coin", "petg_pebble_golem": "heart",
	"petg_frost_mote": "heart", "petg_wick": "heart", "petg_tinker_gear": "heart", "petg_grimoire": "heart",
	"petg_cauldron": "heart",
	"mg_fossil_hunter": "skull", "mg_bubble_breaker": "star", "mg_scratch_off": "coin", "mg_claw_machine": "trophy",
	"mg_bubble_shooter": "bolt", "mg_plinko": "dice", "mg_shell_game": "chest", "mg_memory_match": "mirror",
	"mg_fishing": "snowflake", "mg_lucky_wheel": "crown", "mg_high_low": "up",
	"pack": "dice", "pack_starter": "dice", "pack_gamblers_kit": "dice", "pack_cold_steel": "dice",
	"pack_pyromancy": "dice", "pack_storm": "dice", "pack_numerology": "dice", "pack_resonance": "dice",
	"pack_colossus": "dice",
	"upgrade_starter_kit": "dice", "upgrade_whetstone": "anvil", "upgrade_loadout_slot": "plus",
	"upgrade_potion_belt": "potion",
	"slot_weapon": "sword", "slot_offhand": "shield", "slot_head": "helmet", "slot_body": "armor",
	"slot_trinket": "ring", "slot_trinket2": "pouch", "cape": "cape",
	"tier_1": "star", "tier_2": "star", "tier_3": "star", "kit": "star",
	"look_hidden": "close", "bad_fit": "", "lock": "", "unlock": "star", "craft": "anvil", "blueprint": "star",
	"feat": "trophy", "mastery": "star", "rank": "up", "pet_charge": "bolt", "pet_xp": "xp", "boss": "crown",
	"new": "star", "skip": "speed",
}

## Tier star per tier (1..3): bronze, silver, gold.
const TIER_ICON := ["", "tier_1", "tier_2", "tier_3"]
## Tier colours (numeral text, fallbacks): none, bronze, silver, gold.
const TIER_COLORS := [Color("7d7896"), Color("e0925a"), Color("d6dde9"), Color("ffc24a")]
const TIER_NAMES := ["", "I", "II", "III"]
## Disc colour of a locked medallion.
const LOCKED_RING := Color("5b6072")


## The id to draw: the pack id when its art is imported (or a legacy glyph of that name
## exists), else its legacy glyph ("" = the drawn padlock).
static func resolve(id: String) -> String:
	if id == "" or Icons.is_mapped(id):
		return id
	if not LEGACY.has(id) and UiIcons.exists(id):
		return id
	if id.begins_with("kind_"):
		return "dice"
	return String(LEGACY.get(id, "star"))


## True when `id` draws pack art (so full-colour: caller tints are ignored).
static func is_pack(id: String) -> bool:
	return id != "" and Icons.is_mapped(id)


## A TextureRect for any icon id. `locked` = desaturated (pack) / muted (legacy glyph);
## `tint` only applies to legacy glyphs (pack art keeps its own colours).
static func icon(id: String, px: int, tint: Variant = null, locked := false) -> Control:
	var r := resolve(id)
	if r == "":
		var lk := CampUi.LockGlyph.new()
		lk.custom_minimum_size = Vector2(px, px)
		lk.size = Vector2(px, px)
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return lk
	var rect: TextureRect
	if is_pack(r):
		rect = Icons.rect(r, px, {"saturation": 0.0} if locked else null)
		if locked:
			rect.modulate = Color(1, 1, 1, 0.85)
	else:
		var c: Variant = UiPalette.TEXT_MUTED if locked else tint
		rect = Icons.rect(r, px, c)
	rect.size = Vector2(px, px)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


## Puts an icon at the start of a CampUi.Tile's title row (CampUi.Tile draws legacy glyphs only).
static func tile_icon(t: Control, ic: Control) -> void:
	var col := t.get_child(0) if t.get_child_count() > 0 else null
	var row := col.get_child(0) if col != null and col.get_child_count() > 0 else null
	if row is HBoxContainer:
		row.add_child(ic)
		row.move_child(ic, 0)


## The padlock (pack Lock, or the drawn one).
static func lock_icon(px: int) -> Control:
	return icon("lock", px)


## A medallion (OptionCard.Medallion: the icon on a 3D Round disc tinted with `ring`);
## `locked` greys the disc and the icon. `tint` colours legacy glyphs only.
static func medal(id: String, px: float, ring: Color, locked := false, tint: Variant = null) -> OptionCard.Medallion:
	var r := resolve(id)
	# locked: a slate disc (the disc's tint survives the saturation pass) + the greyed icon
	var rc := LOCKED_RING if locked else ring
	var m := OptionCard.Medallion.make(r, px, null if is_pack(r) else (UiPalette.TEXT_MUTED if locked else (tint if tint is Color else ring)),
		rc, 0.0 if locked else 1.0)
	m.size = Vector2(px, px)
	return m


## Medallion + title + sub line (CampUi.title_row with pack icons).
static func title_row(id: String, color: Color, title: String, sub := "", px := 64, locked := false) -> HBoxContainer:
	var row := UiTheme.hbox(14)
	var m := medal(id, px, color, locked, color)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(m)
	var col := UiTheme.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var t := UiTheme.label(title, 30, UiPalette.TEXT_DIM if locked else UiPalette.TEXT, true, 6)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size.x = 60
	col.add_child(t)
	if sub != "":
		var sc := UiPalette.TEXT_MUTED if locked else color.lerp(UiPalette.TEXT_DIM, 0.35)
		var s := UiTheme.label(sub, 19, sc, false, 0, false, 700)
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s.custom_minimum_size.x = 60
		col.add_child(s)
	return row


## A chip (Flat Round pill) with an optional icon: `fam` is a pack family ("red" NEW,
## "purple" EQUIPPED, "green" KIT / OWNED, "yellow" GOLD TIER / MAX, "grey" tiers) or a Color.
static func chip(text: String, fam: Variant = "grey", icon_id := "", size := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var skin := UiTheme.skinned("chip_white")
	var sb := UiTheme.chip_box(fam)
	UiTheme.pad(sb, 12 if skin else 9, 2)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := UiTheme.hbox(5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	if icon_id != "":
		row.add_child(icon(icon_id, size + 6))
	var face: Color = fam if fam is Color else UiTheme.family_color(String(fam))
	var fg := UiPalette.on(Color(face, 1.0)) if skin else UiPalette.TEXT
	if not skin and String(fam) == "grey":
		fg = UiPalette.TEXT
	row.add_child(UiTheme.label(text, maxi(size, 16), fg, false, 0, false, 700))
	return p


## "TIER II" chip: the bronze / silver / gold star and the numeral as text.
static func tier_chip(tier: int, size := 16) -> PanelContainer:
	if tier <= 0:
		return chip("RANK 0", "red", "", size)
	return chip("TIER " + String(TIER_NAMES[clampi(tier, 1, 3)]), "grey", String(TIER_ICON[clampi(tier, 1, 3)]), size)


## Slot-tile corner badge: star + numeral on a dark chip (anchored bottom-right by the caller).
static func tier_badge(tier: int, font := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var col: Color = TIER_COLORS[clampi(tier, 0, 3)]
	var sb := UiTheme.chip_box("grey") if UiTheme.skinned("chip_grey") else UiTheme.box(Color(0.05, 0.05, 0.12, 0.95), 10, 2, col)
	UiTheme.pad(sb, 5, 0)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	if is_pack(String(TIER_ICON[clampi(tier, 1, 3)])):
		row.add_child(icon(String(TIER_ICON[clampi(tier, 1, 3)]), font + 2))
	var l := UiTheme.label(String(TIER_NAMES[clampi(tier, 0, 3)]), font, col, true, 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(l)
	return p


## Count badge: a red pill with the number for 1..3 ready items; a plain dot above that
## (the tag says "something is ready", the station screen says how many).
static func count_badge(n: int) -> Control:
	if n > 3:
		return new_dot(22)
	var p := PanelContainer.new()
	var fb := UiTheme.pad(UiTheme.box(UiPalette.HP, 14, 2, UiPalette.OUTLINE), 7, 1)
	var sb := UiSkin.stylebox("badge_count", "normal", fb)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.custom_minimum_size = Vector2(28, 28)
	var l := UiTheme.label(str(n), 18, UiPalette.TEXT_DARK if UiSkin.has("badge_count") else UiPalette.TEXT, true, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## The red NEW dot (radio-on-red), `px` wide. Place it inside its card, 8 px from the corner.
static func new_dot(px := 20) -> Control:
	var d := Dot.new()
	d.custom_minimum_size = Vector2(px, px)
	d.size = Vector2(px, px)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return d


## Anchors `c` (already sized, e.g. a dot or a badge) to a corner of its parent, `inset` px in.
## corner: "tr" | "tl" | "br" | "bl".
static func pin(c: Control, corner := "tr", inset := 8.0) -> Control:
	var right := corner.ends_with("r")
	var bottom := corner.begins_with("b")
	c.anchor_left = 1.0 if right else 0.0
	c.anchor_right = c.anchor_left
	c.anchor_top = 1.0 if bottom else 0.0
	c.anchor_bottom = c.anchor_top
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	c.offset_left = -inset if right else inset
	c.offset_right = c.offset_left
	c.offset_top = -inset if bottom else inset
	c.offset_bottom = c.offset_top
	return c


## The red NEW dot.
class Dot:
	extends Control
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var tex := UiSkin.texture("new_dot", "normal", s)
		if tex:
			draw_texture_rect(tex, Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s)), false)
			return
		var r := s * 0.5
		draw_circle(size * 0.5, r, UiPalette.OUTLINE)
		draw_circle(size * 0.5, r - 2.5, UiPalette.HP)
