extends "res://tests/test_case.gd"
## Modal pass conventions (docs/reviews/2026-10-01-modal-pass.md, "Conventions"): the plaque
## colour legend, the dismiss mode of every modal in the spec 3.2 inventory, the button verb
## glossary, section header style, icons on every choice card and toast, and the shrink floor
## that keeps text >= 16 px and tap targets >= 80 px. Run Setup and the Developer menu are
## owned elsewhere and left out.

const MODAL_FILES := [
	"res://ui/modals/draft_modal.gd", "res://ui/modals/passive_modal.gd", "res://ui/modals/shop_modal.gd",
	"res://ui/modals/forge_modal.gd", "res://ui/modals/event_modal.gd", "res://ui/modals/rune_assign_modal.gd",
	"res://ui/modals/die_inspector.gd", "res://ui/modals/pause_menu.gd", "res://ui/modals/settings_panel.gd",
	"res://ui/modals/route_card.gd", "res://ui/auto/auto_settings_panel.gd", "res://ui/screens/summary_screen.gd",
	"res://ui/minigames/minigame_reward_modal.gd", "res://ui/camp/camp_screen.gd", "res://ui/camp/armory_modal.gd",
	"res://ui/camp/wardrobe_modal.gd", "res://ui/camp/pet_den_modal.gd", "res://ui/camp/workshop_modal.gd",
	"res://ui/camp/arcade_modal.gd", "res://ui/camp/camp_ui.gd", "res://ui/widgets/update_banner.gd",
]
## Button verb glossary: the first word of every text button label in a modal.
const VERBS := ["TAKE", "BIND", "BUY", "CRAFT", "UNLOCK", "RANK", "LEVEL", "RESTOCK", "FORGE", "RAISE", "MIRROR",
	"EQUIP", "SWAP", "REMOVE", "RESUME", "SETTINGS", "CONTROLS", "ABANDON", "KEEP", "BEGIN", "LET'S", "TO",
	"AUTO", "CHECK", "RESET", "RESTART", "DOWNLOAD", "UPDATE", "PICK", "CHOOSE", "CONTINUE", "START"]
## Labels that must never come back (one exit; vague verbs).
const BANNED := ["DONE", "CLOSE", "OK", "GET", "CLAIM", "LEAVE", "SKIP", "DEFAULTS"]


func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)


# ---------------------------------------------------------------- plaque legend

func test_every_plaque_uses_the_legend() -> void:
	var re := RegEx.create_from_string("set_title\\((.*)\\)\\s*(#.*)?$")
	for path in MODAL_FILES:
		for line in _src(path).split("\n"):
			var t := line.strip_edges()
			if not t.begins_with("set_title("):
				continue
			var m := re.search(t)
			assert_true(m != null, "%s: parse %s" % [path, t])
			if m == null:
				continue
			assert_true(m.get_string(1).contains("PLAQUE_"), "%s: plaque colour comes from the legend: %s" % [path, t])


func test_legend_families_are_skinned_or_fall_back() -> void:
	assert_eq(UiModal.PLAQUE_FAMILIES, ["yellow", "purple", "green", "red"])
	var d := DraftModal.new()
	d.set_title("LEVEL UP!", UiModal.PLAQUE_LEVEL)
	assert_eq(d.ribbon.plaque_family(), "purple")
	d.set_title("REWARD", UiModal.PLAQUE_DEFAULT)
	assert_eq(d.ribbon.plaque_family(), "yellow")
	d.free()


func test_grey_colour_plaques_never_draw_nothing() -> void:
	# steel / silver colours have no plaque art of their own: the white plaque x colour
	if not UiSkin.has("plaque_white"):
		return
	var sb := UiTheme.plaque_box(Color("aab4c8"))
	assert_true(not (sb is StyleBoxEmpty), "a grey plaque colour still draws a plaque")


func test_runtime_plaques() -> void:
	var f := GameFlow.new_run("knight", 7)
	f.debug_open("draft")
	var d := DraftModal.new()
	d.refresh(f)
	assert_eq(d.ribbon.plaque_family(), "purple", "level-up draft: purple")
	d.free()
	f.debug_open("forge")
	var fm := ForgeModal.new()
	fm.refresh(f)
	assert_eq(fm.ribbon.plaque_family(), "yellow", "forge: yellow (was an invisible steel plaque)")
	fm.free()
	for id in EventDefs.IDS:
		f.debug_open("event", id)
		var e := EventModal.new()
		e.refresh(f)
		assert_eq(e.ribbon.plaque_family(), "yellow", "event %s: yellow" % id)
		e.free()


# ---------------------------------------------------------------- one exit (spec 3.2 inventory)

func test_dismiss_modes_match_the_inventory() -> void:
	# dismissible: header x + Esc + backdrop
	var dismissible: Array = [SettingsPanel.new(), AutoSettingsPanel.new(), DieInspector.new(), ShopModal.new(),
		ForgeModal.new(), ArmoryModal.new(), WardrobeModal.new(), PetDenModal.new(), WorkshopModal.new(), ArcadeModal.new()]
	for m: UiModal in dismissible:
		assert_true(m.dismissible, "%s: dismissible" % m.get_script().resource_path)
		m.free()
	# forced: no x, no Esc, no backdrop
	var forced: Array = [DraftModal.new(), PassiveModal.new(), EventModal.new(), RuneAssignModal.new(), RouteCard.new(),
		MinigameRewardModal.new(), SummaryScreen.new(), PauseMenu.new(), CampScreen.WelcomeModal.new()]
	for m: UiModal in forced:
		assert_true(not m.dismissible, "%s: forced" % m.get_script().resource_path)
		m.free()


func test_pause_and_confirm_exits() -> void:
	var p := PauseMenu.new()
	assert_eq(p.primary_action, p._resume, "pause: RESUME is the exit")
	assert_eq(p.cancel_action, p._resume, "pause: Esc = RESUME")
	p._ask()
	assert_eq(p.cancel_action, p._keep, "abandon confirm: Esc = KEEP PLAYING")
	assert_eq(p.ribbon.plaque_family(), "red", "abandon confirm: red plaque")
	assert_true(p._keep.size_flags_horizontal != Control.SIZE_EXPAND_FILL, "the cancel is normal width")
	p.free()


func test_update_banner_close_is_the_red_round_button() -> void:
	var b: Control = load("res://ui/widgets/update_banner.gd").new()
	var close: GameButton = b.get("_close")
	assert_true(close.is_round(), "round close")
	assert_eq(close.round_family, "red")
	b.free()


# ---------------------------------------------------------------- text

func test_button_labels_follow_the_verb_glossary() -> void:
	var re := RegEx.create_from_string("(?:GameButton\\.make|buy_button)\\(\"([^\"]+)\"")
	for path in MODAL_FILES:
		for m in re.search_all(_src(path)):
			var label := m.get_string(1)
			if label.contains("%"):
				label = label.split("%")[0].strip_edges()
			if label == "":
				continue
			assert_eq(label, label.to_upper(), "%s: button labels are UPPERCASE (%s)" % [path, label])
			var verb := label.split(" ", false)[0]
			assert_true(VERBS.has(verb), "%s: '%s' is in the verb glossary" % [path, label])
			assert_true(not BANNED.has(verb), "%s: banned label %s" % [path, label])


func test_section_headers_have_no_exclamation_or_colon() -> void:
	var re := RegEx.create_from_string("(?:section_label|heading)\\(\"([^\"]+)\"")
	for path in MODAL_FILES:
		for m in re.search_all(_src(path)):
			var t := m.get_string(1)
			assert_true(not t.contains("!") and not t.ends_with(":"), "%s: section header '%s'" % [path, t])


func test_prices_are_never_spelled_in_buttons() -> void:
	# "10 gold" in a button: prices are the currency icon + a number
	for path in MODAL_FILES:
		assert_true(not _src(path).contains("sub_text = \"%d gold\""), "%s: price as icon + number" % path)


# ---------------------------------------------------------------- icons

func test_every_event_choice_card_has_an_icon() -> void:
	var f := GameFlow.new_run("knight", 7)
	for id in EventDefs.IDS:
		f.debug_open("event", id)
		var e := EventModal.new()
		e.refresh(f)
		for c in e.find_children("*", "OptionCard", true, false):
			var oc := c as OptionCard
			assert_true(oc._medal_holder.visible and oc._medal_holder.get_child_count() > 0,
				"event %s: choice '%s' has an icon" % [id, oc._title.text])
		e.free()


func test_shrine_passives_read_as_passive_cards() -> void:
	var f := GameFlow.new_run("knight", 7)
	f.debug_open("event", "shrine")
	var e := EventModal.new()
	e.refresh(f)
	for c in e.find_children("*", "OptionCard", true, false):
		var oc := c as OptionCard
		if oc._tag.text != "":
			assert_true(oc._tag.text.ends_with("PASSIVE"), "shrine card tag: %s" % oc._tag.text)
	e.free()


func test_every_toast_has_an_icon() -> void:
	for col in [UiPalette.TEXT, UiPalette.DANGER, UiPalette.HEAL, UiPalette.GOLD_BRIGHT]:
		var t := Toast.make("Not enough Crowns", "", col)
		assert_true(t.find_children("*", "TextureRect", true, false).size() >= 1, "toast %s has an icon" % col.to_html())
		t.free()
	assert_eq(Toast.type_icon("danger"), "warning")
	assert_eq(Toast.type_icon("heal"), "heart")


# ---------------------------------------------------------------- sizes

func test_shrink_floor_keeps_text_and_taps_readable() -> void:
	var d := DraftModal.new()
	# a 16 px tag and an 80 px button in the body: the panel may not shrink at all
	d.body.add_child(UiTheme.label("TAG", 16))
	assert_near(d._shrink_floor(), 1.0, 0.001, "16 px text: no shrink")
	d.free()
	var s := SettingsPanel.new()
	for b in s._speed_btns:
		assert_true(b.custom_minimum_size.y >= 80.0, "segmented control rows are 80 px tall")
	s.free()
