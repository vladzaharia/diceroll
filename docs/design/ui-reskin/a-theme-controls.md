# UI reskin, area (a): theme and base controls

Status: plan (2026-09-30). Area planner (a). No code changes on this branch.

Aligned with:
- Lead draft `docs/design/2026-09-30-ui-reskin.md` on `wp-ui-design` (commit ef8b01f): "Night navy + wood", 3D Square 2.5 buttons, Nailed darkbrown modal frame, yellow plaque ribbon, Container 3D white modulated to navy for cards, Frame Thin darkbrown for tooltips, Bars Regular grey-darker track, Vector Pro `Outline` icons, SVG only.
- Foundation WIP on `wp-ui-foundation` (uncommitted when read): `UiSkin` (`ui/theme/ui_skin.gd`), `UiSvg` (DPITexture), `UiLayeredStyleBox`, manifest `ui/theme/ui_pack.json`, `Icons` registry plus `ui/icons/icon_map.json` from the lead.

Items marked **PROPOSAL** are my suggestions and still need the lead's decision.

Pack paths are relative to `third_party/rhosgfx/cartoony-ui-pack-full/`, written as `UI/...`. Icon paths are relative to `third_party/rhosgfx/vector-icon-pack-pro/`, written as `VIP/...`. Slice, content and expand values are in SVG viewBox units unless marked "px". "px" means logical canvas px on the 720x1280-based canvas.

Review aids (scratchpad, not committed):
- before shots: `/private/tmp/claude-501/-Users-vlad-Repos-diceroll/1bba73af-2ee7-40a8-8c95-50839b8aed16/scratchpad/ui-plan/a/before/`
- mockup: `.../ui-plan/a/mockup_a_components.png` (script `mockup.py` beside it)
- pack contact sheets: `.../ui-plan/a/pack/sheet_{frames,buttons,bars,icons}.png`

---

## 1. Inventory

### 1a. Factories in `ui/theme/ui_theme.gd` and the global Theme

| Component | Factory (file:line) | Current look | Used by (screens) | Call sites |
|---|---|---|---|---|
| `box()` raw StyleBoxFlat | ui_theme.gd:60 | rounded flat, optional border and shadow | everything drawn by hand (see 1c) | 130 in 35 files |
| `pad()` | ui_theme.gd:78 | content margins helper | many | (with box) |
| `panel_box("main")` modal | ui_theme.gd:91 | PANEL navy 0.92, r34, 3px GOLD_LINE, big shadow, pad 32/28 | UiModal (all 16 modals), class_select, combat_hud sheet, overlay mini_dice, minigame_screen result, Theme `PanelContainer`/`Panel` default | 4 direct + 3 `panel()` + 2 Theme + 16 subclasses |
| `panel_box("card")` | ui_theme.gd:94 | NAVY_2, r24, 2px white 8%, pad 20/18 | CampUi.card (run_setup, arcade, pet_den, workshop, armory, wardrobe, summary) | 1 direct, 21 via CampUi.card |
| `panel_box("card_hi")` | ui_theme.gd:97 | NAVY_3, 4px GOLD_BRIGHT, gold glow | CampUi.card(hi) | via CampUi.card |
| `panel_box("inset")` | ui_theme.gd:100 | ink 55%, r18, no border | forge, rune_assign, summary, dev_menu | 5 |
| `panel_box("hud")` | ui_theme.gd:103 | PANEL_SOFT, 2px GOLD_FAINT | combat_hud, update_banner | 2 |
| `panel_box("pill")` | ui_theme.gd:106 | ink 82%, r40, 2px GOLD_FAINT | hud_top (4, two cast `as StyleBoxFlat`), board_hud (2 incl. toast), camp_screen, overlay toast, minigame_screen (2), dev_menu toast, Counter default | 11 + Counter |
| `panel_box("tooltip")` | ui_theme.gd:109 | INK, r14, 2px GOLD_LINE | Theme `TooltipPanel` (10 files set `tooltip_text`) | 1 |
| Theme `Button` | ui_theme.gd:419-434 | SECONDARY flat, gold rim, Lilita 28 | only raw `Button` (missing_assets_screen styles its own); guard for strays | 0 live |
| Theme `HSlider` | ui_theme.gd:439-454 + `_knob_texture` :478 | dark track, gold fill, drawn gold knob 44px | settings_panel (3 volume), auto_settings_panel (HP threshold) | 2 creators, 4 sliders |
| Theme `V/HScrollBar` | ui_theme.gd:456-466 | 4% white track, gold-faint grabber | UiModal scroll, class_select scroll | 2 |
| Theme `TooltipPanel/Label` | ui_theme.gd:469-472 | as tooltip box, Fredoka 22 | desktop hover tooltips | 16 `tooltip_text` in 10 files |
| Fonts | ui_theme.gd:25 / :47 | Lilita One display, Fredoka variable body | everywhere | n/a (unchanged) |
| `UiTheme.TOUCH` | ui_theme.gd:17 | 88 px min tap | GameButton default | 1 (+45 `min_height =` overrides in 19 files) |
| `UiPalette` | ui/theme/palette.gd | gold on navy | everywhere | n/a |

### 1b. Shared widgets (`ui/widgets/`, `ui/camp/camp_ui.gd`)

| Component | Factory (file:line) | Current look | Used by | Call sites |
|---|---|---|---|---|
| GameButton PRIMARY | game_button.gd:56 `make`, draw :287, colours :260 | orange face, 8px lip, gloss, rim | every screen | `make` 61 in 26 files; PRIMARY 33 in 25 |
| GameButton SECONDARY | same | navy face, gold rim | every screen | 35 in 18 |
| GameButton DANGER | same | red | pause_menu (abandon), dev_menu | 3 in 2 |
| GameButton SUCCESS | same | green | 3 files | 3 in 3 |
| GameButton GHOST | same | translucent ink, faint rim | die_inspector, camp_screen, hud_top, title, combat_hud, class_select, forge, auto_hud | 13 in 9 |
| GameButton ROUND (icon-only) | game_button.gd:67 `round_icon` | navy circle + icon | close: camp_modal:22, update_banner:49; back: class_select:45; home/settings: camp_screen:123/128; wardrobe camp_screen:292; pause hud_top:132; help combat_hud:84; gear auto_hud:57; prev/next die_inspector:26/35, run_setup:125/142 | 13 in 9 |
| GameButton toggle (segmented) | `toggle_mode` + `toggle_primary` | PRIMARY when on, SECONDARY when off | settings (speed, UI size, auto-update ON/OFF), auto_settings (3), forge (2), combat_hud, class_select, dev_menu | 11 in 6 |
| GameButton disabled | `set_enabled(false)` / `_colors()` :262 | DISABLED grey | buy buttons, TAKE, etc. | many |
| UiModal | ui_modal.gd:32 (`_init`), layout :141, chrome :155-156, ribbon overlap `vbox(-26)` :43 | SCRIM + Ribbon + panel("main") + ScrollContainer | 16 subclasses: draft, event, shop, forge, passive, pause, settings, rune_assign, route_card, die_inspector, dev_menu, auto_settings, minigame_reward, camp_modal (camp screens), camp_screen, summary_screen | 16 |
| `UiModal.section_label` | ui_modal.gd:189 | gold caps 20 | modals | (small) |
| Ribbon | ribbon.gd:17 / draw :32 | procedural gold banner with tails | UiModal title (all modals), minigame_screen:64 | 3 |
| StatBar (HP) | stat_bar.gd:26 / draw :79 | pill track, glossy fill, ghost drain, centred text | hud_top:92 (HP) | 1 |
| CampUi.ProgressPill (XP/goal/mastery) | camp_ui.gd:94 `bar`, class ~:209 | thin pill + gloss | armory, pet_den, summary | 7 |
| MgWidgets.ParMeter | mg_widgets.gd:9 | pill meter | minigames (area e) | 1 |
| LevelBadge | level_badge.gd:11 / draw :42 | drawn medallion + XP ring | hud_top:81 | 1 |
| Counter | counter.gd:18 | icon + number in `pill` | hud_top (gold, treasury), shop_modal | 4 |
| CampUi.card / locked_card | camp_ui.gd:13 / :26 | panel_box card / dim card | 7 camp and results screens | 21 / 9 |
| CampUi.chip ("NEW", "EQUIPPED", "L4") | camp_ui.gd:68 | flat rounded r12 | arcade, workshop, armory, wardrobe, class_card, pet_den | 24 |
| CampUi.tile (selectable) | camp_ui.gd:143 (styles :164-168) | card with selected / enabled states | arcade, run_setup, workshop | 4 |
| CampUi.pips | camp_ui.gd:105 | drawn dots and diamonds | arcade, pet_den, armory | 4 |
| CampUi.lock_line + LockGlyph | camp_ui.gd:81, glyph ~:262 | drawn padlock + text | armory, arcade, pet_den, workshop, class_card, class_select | 14 |
| CampUi.buy_button | camp_ui.gd:55 | PRIMARY / disabled SECONDARY, 72 px | arcade, armory, wardrobe, pet_den, workshop | 14 |
| Toasts (4 implementations) | overlay.gd:402, board_hud.gd:195, dev_menu.gd:412 (static), dev_gesture.gd:104 | `pill` panel + label (+ icon) | game_controller, event_player, *_beats, encounter_cards, dev menu | about 10 caller files |
| Update banner | update_banner.gd:29 | `hud` panel + PRIMARY + round close | Updater | 1 |
| Toggle switch (hand-drawn) | auto_settings_panel.gd:253 `_SwitchRow` (draw :316-323) | drawn pill track | auto settings | 3 rows |

### 1c. Styles built by hand outside the theme (swap targets for areas b to e)

These call `UiTheme.box(...)` or `StyleBoxFlat.new()` directly. A theme swap does not reach them. Section 5 adds shared factories so each one becomes a one-line change.

| Pattern | Where (file:line) |
|---|---|
| Selectable card states (normal, selected, locked, owned) | armory_modal.gd:226-232 (slot tile), :395-404 `_card_box`, :656-668 variant chip, :851-857 look chip; class_card.gd:75-84; camp_ui.gd:162-168 tile; wardrobe_modal.gd:118; die_chip.gd:80-86; option_card.gd:192-227 (drawn, with glow) |
| Chips / tags | armory_modal.gd:253 (L badge), :303-306 `_tier_badge`; class_card.gd:131-135 `mechanic_chip`; class_detail.gd:14 `mechanic_badge`; option_card.gd:86 (price), :156 (tag); kit_strip.gd:109 |
| Insets / stat wells | class_detail.gd:55, :87; kit_strip.gd:93; armory_modal.gd:410-414 `_thumb_box`; meta_hud.gd:532 slot |
| Callouts / tooltips (coloured rim) | affix_tips.gd:116; meta_hud.gd:336, :389, :449; overlay.gd:213 (passive card), :250 (biome card), :324 (item pop); encounter_cards.gd:150 |
| HUD strips | meta_hud.gd:58; auto_hud.gd:68, :85; hud_top.gd:379-380 and :584-585 (`panel_box("pill")` cast `as StyleBoxFlat`, then border recoloured) |
| Custom-drawn buttons | auto_button.gd:134-158, speed_pill.gd:100-114 (same face/lip/gloss recipe as GameButton) |
| Bars | stat_bar.gd:79-96; camp_ui.gd ProgressPill; mg_widgets.gd:38-52; auto_settings `_SwitchRow` track |
| Exempt (must work without the paid pack) | game/boot/missing_assets_screen.gd:144-298 (own StyleBoxFlat, raw `Button`); dice_tray.gd:225 (world tray, area b/c) |

Totals: 130 `UiTheme.box(` in 35 files, 75 `add_theme_stylebox_override` in 32 files, 65 `draw_style_box(` in 15 files, 7 `StyleBoxFlat.new()` in 4 files.

---

## 2. Proposed mapping

### 2a. Measured 9-slice margins (from the SVG geometry)

| Asset | viewBox | Slice L/T/R/B | Face / hole | Notes |
|---|---|---|---|---|
| Buttons/3D/Square 2.5 `_standard`, `_hover`, `_focus` | 160x64 | **9/9/9/19** | face y4-50, lip 50-60, outline 4 | agrees with lead. Foundation seed has 10/10/10/20 on the `-1` asset; either works, but use 9/9/9/19 for the 2.5 art |
| Buttons/3D/Square 2.5 `_pressed` | 160x64 | **9/15/9/13** | face y10-56, outline starts y6 | the 6-unit sink comes from the content margins; no code sink needed |
| Buttons/3D/Round `-1` (icon-only) | 64x64 | not sliced (fixed size) | outline x5-59 (54 wide: slightly oval), face centre y=27 | put the icon centre at 27/64 of the height, not 1/2 |
| Buttons/3D/Round 2.5 (if used) | 160x64 | **27/26/27/37** | radius 27 | leaves a 1-unit stretch band; t+b must stay below the height |
| Buttons/Flat/Round 2.5 (chips) | 160x64 | **32/31/32/32** | radius 32 (full pill) | 1-unit stretch row; see risk R6 |
| Frames/Nailed darkbrown | 128 | **24/27/24/34** | hole x22-106, y27-96 | nails sit at x11/21 and y11/21/97: the slices must contain them (agrees with lead) |
| Frames/Thin | 128 | **22/22/22/22** | hole 22-106 | |
| Frames/Basic | 128 | 22/27/22/32 | hole x17-111, y22-101 | |
| Containers/3D | 128 | **15/15/15/25** | face y5-113, lip 113-123 | foundation seed uses 18/18/18/26 (fine, just not tight) |
| Containers/Flat | 128 | 10/10/10/10 | r10 | |
| Bars/Regular container | 128x20 | 8/8/8/8 | inner inset 4, 12 tall | |
| Bars/Wide container | 128x24 | 8/8/8/8 | inset 4, 16 tall | grey-darker file is misnamed `progress-containerwide-grey-darker.svg` (no dash) |
| Bars/Thin container | 128x16 | 8/7/8/8 | inset 4, 8 tall, full radius | 1-unit band |
| Bars fill (Regular / Wide / Thin) | 60x12 / 60x16 / 60x8 | 4/4/4/4 (Thin: 4/3/4/4) | | |
| Widgets/Toggles round | 44x24 | 12/11/12/12 | inner inset 4 | knob = `Bars/Handles/handle-round.svg` (24x28) |
| Checkbox / Radio | 24x24 | not sliced | | glyph overlays: `Widgets/Checkboxes/checkbox-{tick,cross,dot}.svg` (white) |
| Widgets/Cursor/cursor-focus | 128 | 50/50/50/50, `draw_center:false` | corner brackets | keyboard focus ring |

### 2b. Per-component mapping (`ui_pack.json` pieces)

`scale` is logical px per SVG unit. Colour families use the pack's own folders (`3. Yellow`, `6. Blue`, ...). "white×T" means the `0. White` asset with `tint: palette:T` baked in (UiSkin `tint` = multiply in the vector: crisp). When the white variant is tinted, its face, lip and outline come out as about 1.0, 0.83 and 0.4 times T. That keeps the 3-tone look in any palette colour (checked in the mockup).

| Piece | normal | hover | pressed | disabled | focus | scale | content (px) |
|---|---|---|---|---|---|---|---|
| `button_primary` | 3D/Square/3. Yellow/`button-square-3d-2.5-yellow-regular_standard` | `..._hover` | `..._pressed` (slice 9/15/9/13) | `1. Grey/...grey-regular_standard` | `..._focus` (white outline) | 1.25 | 24/13/24/26; pressed 24/21/24/18 |
| `button_secondary` | **PROPOSAL** `6. Blue/...blue-dark_*` (lead: blue-regular) | blue-dark_hover | blue-dark_pressed | grey-regular | blue-dark_focus | 1.25 | same |
| `button_danger` | `2. Red/...red-regular_*` | hover | pressed | grey-regular | focus | 1.25 | same |
| `button_success` | `4. Green/...green-regular_*` | hover | pressed | grey-regular | focus | 1.25 | same |
| `button_ghost` (**PROPOSAL**) | Flat/Square/0. White `button-square-flat-2.5-white_standard` white×NAVY_3, modulate a=0.85 | white×SECONDARY | `_pressed` | a=0.5 | none | 1.0 | 20/10/20/10 |
| `button_small_*` (72 px and under: buy, CHECK, ON/OFF, 1x/2x) | same art as the kind | | | | | **1.0** (lip 10 px) | 16/10/16/21 |
| `button_round_<kind>` (icon-only) | 3D/Round/<colour>/`button-round-3d-1-<colour>-regular_standard` | `_hover` | `_pressed` | grey | `_focus` | px/64 | icon 46% of px, centred at y=27/64 |
| close X | round **red**-regular + icon `close` | | | | | | |
| back, home, settings, pause, help, prev/next | round **blue-dark** + icon | | | | | | |
| `panel_main` (modal) | layers: Containers/3D/0. White `container-3d-white` white×NAVY (inset: expand −8 px) under Frames/Nailed/9. Brown `frame-nailed-darkbrown` | n/a | | | | 1.0 phone / desktop | 38/36/38/42 |
| `ribbon` (plaque) | 3D/Square/3. Yellow 2.5 `_standard`, text white + OUTLINE 6; other colours: white×color | | | | | h/64 (about 1.05 at font 38) | 40/9/40/19 units |
| `panel_card` | Containers/3D white×NAVY_2 | white×NAVY_3 | | locked: white×INK, saturation 0, modulate a=.7 | | **0.8** | 18/14/18/22 |
| `panel_card` selected | layers: white×NAVY_3 + Frames/Thin/3. Yellow `frame-thin-yellow` (scale 0.4) | | | | | | |
| `panel_card` accent (rarity / class) | layers: card + Frames/Thin/0. White ×accent a=.6 (scale 0.35) | | | | | | |
| `panel_inset` | Containers/Flat/0. White white×INK modulate a=.55 | | | | | 1.0 | 16/12/16/12 |
| `panel_hud` / `pill` | Buttons/Flat/Round 2.5 white×INK a=.82 (pill); Containers/Flat white×PANEL_SOFT (hud) | | | | | pill: h/64 | 18/8/18/8 |
| `chip` (NEW, EQUIPPED, L4, tier, mechanic) | Buttons/Flat/Round 2.5 in the pack colour (NEW = `2. Red`, EQUIPPED = `7. Purple`, level = `4. Green`) or white×color | | | | | h/64 (about 0.5) | 10/2/10/2 px |
| `tooltip` / `callout` | layers: Containers/Flat white×INK a=.97 + Frames/Thin/9. Brown `frame-thin-darkbrown` (callout: Frames/Thin/0. White ×rim colour) | | | | | frame 0.5 | 18/14/18/14 |
| `bar_hp` | bg Bars/Wide/1. Grey `progress-containerwide-grey-darker`; fill Bars/Wide/2. Red `progress-bar-wide-red-regular`; ghost fill `3. Yellow ...yellow-lighter` | | | | | h/24 (HUD 44 px: 1.83) | fill expand −4·s |
| `bar_xp` | same bg; fill `7. Purple ...purple-regular` | | | | | | |
| `bar_mastery` / goal | Bars/Regular grey-darker + `3. Yellow ...yellow-regular` (or any accent via white×) | | | | | h/20 | |
| `bar_loading` | Bars/Thin grey-darker + `6. Blue ...blue-regular` | | | | | h/16 | |
| `slider` | track Bars/Regular grey-darker; fill `3. Yellow ...yellow-regular`; grabber `Bars/Handles/handle-round` | | | disabled: saturation 0 | | 1.5 (track 30 px), grabber 44x51 px | |
| `toggle` | off: Toggles/1. Grey `toggle-container-round-grey` + handle left; on: `3. Yellow` + handle right | | | saturation 0 | | 2.0 (88x48 px) | |
| `checkbox` | `Widgets/Checkboxes/3. Yellow/checkbox-empty-yellow` / `checkbox-tick-yellow` | | | grey | | 2.0 (48 px) | |
| `radio` | `Widgets/Radio Buttons/3. Yellow/radio-off-yellow` / `radio-on-yellow` | | | | | 2.0 | |
| `new_dot` | `Widgets/Radio Buttons/2. Red/radio-on-red` | | | | | 18-20 px | |
| `scrollbar` | **PROPOSAL** keep StyleBoxFlat (the pack has no vertical bar; rotating art needs a UiSvg `rotate` key) with colours from the Bars grey-darker / yellow | | | | | | |
| `tabs` (TabBar, none live yet) | selected Flat/Square 2.5 yellow; unselected Flat/Square blue-dark | | | | | | |
| Focus ring (keyboard / gamepad, desktop only) | `Widgets/Cursor/cursor-focus` overlay, draw_center false, expand 6 px | | | | | 0.5 | |

**Recolour rule (PROPOSAL):** use the native pack colour when one matches the role: yellow = primary / gold, red = danger / HP / NEW, green = success / heal, blue = secondary / block, purple = XP / epic, grey = disabled / tracks. Use `0. White` + `tint` (baked multiply) for palette-only colours: navy surfaces, class accents, rarity rims, biome colours, ribbon colours other than gold. Use `modulate` only for alpha, since it is applied at draw time and costs nothing extra. Never use `CanvasItem.modulate` on the control, because it also tints the label and icon.

**Label colours on the new faces:**
- On yellow, keep TEXT_DARK (as now).
- On blue-dark, red and green, use TEXT plus a 5-6 px OUTLINE. The new faces are lighter than the old navy, so labels need the outline to stay readable. GameButton currently draws labels with shadow only.
- On grey (disabled), use `#e4ebee` with no shadow.

---

## 3. Icons for area (a) components

The lead's `icon_map.json` already has entries (`close`, `arrow_left`, `arrow_right`, `home`, `gear`, `check`, `lock`, `pause`, `question`, `plus`, `new`). My candidates are below. The first listed is my pick.

| Need | Candidates (`VIP/...`) | Note |
|---|---|---|
| close | `UI/X/X Flat White.svg` on a red round button (pick); `UI/X/X Outline.svg`; `UI/X Button/X Button Outline.svg` (lead's pick: self-contained red button, use bare, without a GameButton face) | lead's X Button already *is* a button, so on a red round button use the plain X |
| back | `UI/Arrow/Arrow Left Flat White.svg` (pick, on blue round); `UI/Arrow 2/Arrow 2 Left Outline.svg` (lead); `UI/Arrow Back/Arrow Back Outline.svg` (U-turn, reads as "undo") | |
| prev / next | `UI/Arrow/Arrow {Left,Right} Outline.svg`; `UI/Chevrons {Left,Right}/Chevrons * Outline.svg` | |
| home | `General/Home/Home Outline.svg` (pick); `General/Home 2/Home 2 Yellow Outline.svg` | |
| settings | `General/Settings/Gear Outline.svg` (pick); `General/Settings 2/Gear 2 Outline.svg` | |
| check / done | `UI/Check Mark/Check Mark Outline.svg` (green, pick); `Check Mark Flat White.svg` on a green button | checkbox tick comes from the UI pack (`Widgets/Checkboxes/checkbox-tick.svg`) |
| lock / unlock | `General/Lock/Lock Outline.svg`, `General/Lock/Unlock Outline.svg` | replaces `CampUi.LockGlyph` (14 lock_line calls) |
| NEW | a text chip (Flat Round red + "NEW") plus the `radio-on-red` dot (pick). Icon alternates: `General/Sparkle/Sparkle Outline.svg`, `UI/Exclamation Mark/Exclamation Mark Outline.svg` (lead's `new`) | **PROPOSAL:** keep "NEW" as text; use the sparkle for "new unlock" moments |
| arrows up / down | `UI/Arrow/Arrow {Up,Down} Outline.svg`; `UI/Double Arrows/*` for speed | |
| pause / help / info | `UI/Pause/Pause Outline.svg`, `UI/Question Mark/Question Mark Outline.svg`, `UI/Info/Info Outline.svg` | |
| plus / minus (steppers) | `UI/Plus/Plus Outline.svg`, `UI/Minus/Minus Outline.svg` | run_setup steppers currently use arrows |
| sound / music | `UI/Sound/Sound Outline.svg`, `UI/Music/Music Outline.svg` (and the `Off` variants) | settings rows |

On coloured round buttons, prefer `Flat White` glyphs (they read like the pack's own `[THANK YOU!] Icons/X Button` look). Use `Outline` (full colour) when the glyph sits on navy. At 24 px and under, use `Flat White` with a tint (lead rule).

---

## 4. Layout and sizing risks

- **R1 Modal chrome grows.** Nailed frame at scale 1.0 has 22-34 px borders plus padding, so content margins go from 32/28/32/28 to about 38/36/38/42.
  - On the 620-px layout floor (`UiModal.MIN_W`), content width drops from 556 to 544 px (−2%). OK.
  - Vertical chrome grows +22 px, which makes the 0.8 shrink / scroll path in `UiModal._layout` trigger earlier on iPhone landscape (874x402) and duo_outer.
  - Do not go above scale 1.0 on phones. On a desktop with a height of 1080 or more, 1.25 would be allowed but is not needed.
- **R2 Ribbon overlap is hard-coded.** `UiModal` uses `vbox(-26)` (ui_modal.gd:43), and chrome subtracts 26 (:156). The plaque is about 66 px tall, so the overlap should be about half of it, and the nailed top border is 27 px. Make it `-round(ribbon_h * 0.5)` and use the same value in `_layout`.
- **R3 Buttons: the lip is thicker.**
  - At scale 1.25 the lip is 12.5 px against the current `DEPTH` of 8, so labels sit 2-3 px higher. The face area of an 88 px button is 88 − 35 = 53 px, which is enough for Lilita 36 (cap about 25).
  - Buttons of 64 px and under (die_inspector prev/next 64, update_banner close 56, settings toggles 72) must use scale 1.0. Otherwise 28 units × 1.25 = 35 px of fixed slices leaves a 21 px face.
- **R4 Round buttons are oval.** The `-1` round art is 54 of 64 units wide. As a square 88 px control it shows about 74x88 and centres the icon 5 units high. The hit area stays the full rect, so tap size is unaffected. If round must look circular, use the round 2.5 art 9-sliced to w=h (27+27 units = 54 < 64, fine).
- **R5 Cards get taller.** Container 3D has a 10-unit lip at the bottom, so at scale 0.8 each card grows about 8 px. Draft, shop and event option lists of 3-4 cards grow 24-32 px. That is fine in portrait, but check `ui_draft` / `ui_shop` on iphone17_land and duo_outer.
- **R6 Full-radius art needs a stretch band.** In pills, toggles and Thin bars, top + bottom slices equal the whole height. A 9-slice then has no middle row, which shows as a gap or line (reproduced in the first mockup render). Rule: always leave at least 1 unit (use 32/31/32/32, 12/11/12/12, 8/7/8/8). Alternatively, render pills at exactly art height × scale.
- **R7 Thin screens (720-wide canvas and under).** Phones are 720 logical wide in portrait, so 1 px is about 0.56 pt on iPhone 17.
  - 88 px min tap = 49 pt. At UI size 90% (settings) it is 44 pt: exactly the limit. **Do not lower `TOUCH` or any `min_height` below 88 for primary actions.**
  - Current sub-88 overrides are 84 (settings toggles, which is 42 pt at 90%: flag), 72 (buy, CHECK, ON/OFF: 40 pt, 36 pt at 90%), 64 / 68 (steppers), 56 (update close).
  - **PROPOSAL:** keep the visuals small but give those controls an 88 px hit rect (grow the Control, draw the stylebox inset, or use `expand_margin` negative on the stylebox).
- **R8 Density: @1x, @2x, @3x and `--ui-scale`.**
  - Foundation uses `DPITexture`, which re-rasterises at viewport oversampling (stretch × content_scale_factor × density), so it is crisp at every scale. The worst case is iPad Pro 13 portrait × UI 130% ≈ 2.2 × 1.3 = 2.8 physical px per logical px.
  - If the RASTER escape hatch is ever used, `RASTER_OVERSAMPLE = 2` blurs on iPads and at 150% zoom. It would need 3.
  - Check fractional-scale seams at slice borders at 1366x768 (0.6x) and 1.25 zoom. StyleBoxTexture margins become fractional physical px.
- **R9 Slider handle is not square.** It is 24x28; set the icon to 44x51 px and keep `center_grabber`. The track at scale 1.5 is 30 px, and the knob overhangs it by about 10 px top and bottom, so the row height stays 56 (settings_panel.gd:139 already reserves 56).
- **R10 Mutating panel_box breaks.** `panel_box()` returns `StyleBoxFlat` today and callers mutate it:
  - camp_ui.gd:17-18 sets `border_color` / `set_border_width_all`.
  - hud_top.gd:379-380 and :584-585 do `as StyleBoxFlat` then `border_color`. A StyleBoxTexture cast gives null, and the script errors.
  - These must move to the new `accent` parameter **in the same change** that swaps panel_box.
- **R11 CSS in pack SVGs.** Every pressed 3D button has an invisible 160x64 white rect hidden by a CSS class (`.cls-3{opacity:0}`). The pack styles everything via `<style>` classes. Verify that Godot's ThorVG honours class-based opacity. If it does not, pressed buttons render as white blocks. Foundation's importer could inline the styles or strip `opacity:0` elements.
- **R12 Pack naming quirks.** The manifest has to use these exact names:
  - `Bars/Wide/1. Grey/progress-containerwide-grey-darker.svg` (missing dash).
  - Brown has `-darkest` plus `darkbrown` / `lightbrown` families.
  - Grey toggles also have `toggle-round-grey.svg` and `toggle-round-black.svg`, which are not containers.
- **R13 Contrast of the new secondary.**
  - White on `#37b9ff` (blue-regular) is about 2:1. The lead's blue-regular secondary needs outlined labels, or blue-dark (face `#1778ff`, about 3.9:1).
  - Grey disabled needs light text (the mockup's first render showed TEXT_MUTED on grey was unreadable).
  - The grey-darker bar track is teal-slate against navy panels. Acceptable, or use white×INK for tracks.

---

## 5. Migration strategy

**Principle.** Swap at the factory level:
- `UiTheme.panel_box()` / `panel()` / `get_theme()`.
- `GameButton._draw()`.
- `UiModal` / `Ribbon`.
- `StatBar` / `CampUi` builders.

That covers most screens with no screen edits. Everything stays behind `UiSkin.has(piece)` fallbacks, so a clone without the paid pack keeps today's look.

### 5a. Changes that update screens automatically

| Change | Reaches |
|---|---|
| `UiTheme.panel_box(kind)` returns `UiSkin.stylebox("panel_"+kind)` (return type `StyleBox`), with the current flat box as fallback | 16 modals, class_select, combat_hud, overlay, minigame_screen, dev_menu, all `pill` / `inset` / `hud` users, CampUi.card, Counter, toasts |
| `get_theme()`: Button, PanelContainer, Panel, HSlider, CheckBox, CheckButton, TooltipPanel, (TabBar), ProgressBar via `UiSkin.set_theme_type` / `apply_*`; knob via the `slider/grabber` texture | 4 sliders, tooltips in 10 files, any stray Button |
| `GameButton._draw()` draws `UiSkin.stylebox("button_"+kind, state)` (state from disabled / `_held` / hover / toggled). `DEPTH` becomes the art's lip (slice-derived); `_place_content` uses the stylebox content margins; ROUND kind uses the round piece; `toggle_primary` switches piece. Keep hover pop, press squash, sfx | 61 `make` + 13 `round_icon` + 11 toggles + 14 buy buttons across 26 files |
| `Ribbon._draw()` draws the plaque stylebox + text | every modal title, minigame header |
| `StatBar._draw()` / `CampUi.ProgressPill._draw()` use `bar_*` background + fill boxes (ghost = second fill) | HP, XP, goals, mastery, pet XP |
| `CampUi.chip / card / locked_card / tile / lock_line` use `chip`, `panel_card` states, the `lock` icon | 7 camp screens + results + class select |
| `DevMenu.toast`, `BoardHud.toast`, `GameOverlay.toast`, `DevGesture.toast` use one `UiTheme.toast_box()` (pill) | all toasts |

### 5b. New shared factories (area a adds; areas b to e call them)

- `UiTheme.panel_box(kind, accent := null)`: the accent draws a white×accent Thin frame layer. This replaces the hud_top and camp_ui border mutation (R10).
- `UiTheme.card_box(state: "normal"|"selected"|"locked"|"owned"|"dim", accent := null) -> StyleBox`: for armory, class_card, CampUi.tile, wardrobe, die_chip, option_card.
- `UiTheme.chip_box(color_or_family) -> StyleBox`: for CampUi.chip, mechanic_chip, tier badge, option_card tag and price, kit_strip badge.
- `UiTheme.callout_box(rim: Color) -> StyleBox`: for affix_tips, meta_hud tips, overlay cards and pops, encounter_cards.
- `UiTheme.inset_box()`: for class_detail, kit_strip, `_thumb_box`, meta_hud slot.
- `UiTheme.bar_boxes(kind) -> {bg, fill, ghost}`: for StatBar, ProgressPill, ParMeter.
- `UiTheme.toast_box()` and one `Toast.show(host, text, icon, color)` helper.
- `ToggleSwitch` widget (`ui/widgets/toggle_switch.gd`, a CheckButton themed with `toggle`): replaces the settings ON/OFF GameButton and auto_settings `_SwitchRow`.
- `NewDot` (radio-on-red texture) plus `UiTheme.new_chip()`.

### 5c. By hand (area a owns)

1. hud_top.gd:379-380, :584-585 and camp_ui.gd:17-18 move to `panel_box(kind, accent)` (R10).
2. ui_modal.gd:43 / :156: ribbon overlap derived from the plaque height (R2).
3. game_button.gd: rewrite `_draw`, `_colors`, `DEPTH`, `_place_content`, and label outline on non-yellow faces. The API stays the same (no call-site changes).
4. Sub-88 `min_height` overrides: settings_panel (84, 72), update_banner (64, 56), die_inspector (64), run_setup (68), buy_button (72). Use the small piece and an 88 px hit rect (R7).
5. settings_panel `_update_row` → ToggleSwitch; auto_settings_panel `_SwitchRow` → ToggleSwitch.
6. The four toast implementations → one helper.
7. `UiTheme._knob_texture` is deleted once the grabber art is in, but kept as the fallback.

Area a does **not** touch the 1c call sites. Those stay with the areas that own the screens, which switch them to the 5b factories.

### 5d. Step order

1. **Foundation lands** (`wp-ui-foundation`: UiSvg, UiSkin, layered stylebox, import script, manifest schema). *Blocking.*
2. **Area a, PR 1: manifest and factories, no visuals changed yet.**
   - Fill `ui_pack.json` with the pieces in 2b.
   - Add the 5b factories: they return the skin when present and the current flat look otherwise.
   - Add `panel_box(kind, accent)` and fix R10.
   - Check fallback parity by shooting before and after with the pack absent (`third_party/rhosgfx` renamed): the two sets must be pixel-identical.
3. **Area a, PR 2: automatic swap.** Flip panel_box / get_theme / GameButton / Ribbon / UiModal / StatBar / CampUi / toasts to the skin. Shoot the full test plan.
4. **Area a, PR 3: hand fixes** (min_height hit rects, ToggleSwitch, icon names via the Icons registry).
5. **Areas b to e** migrate their 1c call sites to the 5b factories, in parallel.

**What b to e need before they start:**
- the step 2 factory signatures (`card_box`, `chip_box`, `callout_box`, `inset_box`, `bar_boxes`, `toast_box`, `panel_box(kind, accent)`), even with fallback bodies;
- the piece names in `ui_pack.json`;
- the R10 fix.

Once step 2 is merged, b to e can start without waiting for the visuals.

---

## 6. Test plan

Shoot with `tools/shoot_matrix.sh <scenario> <dir> quick` (pc_1080p, pc_1366x768, iphone17_17pro, duo_outer, ipadpro13_land). For the two marked scenarios, also run the `zoom` and `dpi` sets. Before shots from origin/main 6969723 are in the scratchpad (88 PNGs).

| Scenario | Covers |
|---|---|
| `ui_settings` (+zoom, dpi) | sliders, segmented toggles, auto-update toggle, secondary / primary buttons, modal + ribbon |
| `ui_draft` (+zoom, dpi) | modal frame, OptionCard, disabled TAKE, ribbon colour (purple LEVEL UP) |
| `ui_pause` | primary / secondary / danger, route pills |
| `ui_title` | title buttons, ghost |
| `ui_shop`, `ui_forge`, `ui_event` | cards, Counter pill, buy / disabled buttons, inset |
| `ui_combat_hud`, `ui_board_hud` | HP StatBar, LevelBadge, pause round button, HUD pills, toasts (board) |
| `ui_victory` / `ui_results_win` | summary modal, ProgressPill, cards |
| `ui_run_setup`, `ui_workshop`, `ui_armory` | CampUi card / tile / chip / NEW / lock_line / pips / buy, stepper round buttons |
| `ui_class_select` | back round button, class cards, scroll bar |
| `dev_menu`, `dev_menu_confirm` | dev toast, inset panels, danger |
| `game_die_inspect` | prev / next 64 px round buttons |
| `asset_missing` | must be unchanged (exempt screen) |

Also check:
1. **Fallback parity:** run step 2 shots with the pack absent; they must match the before shots.
2. **Hit targets:** a headless check that walks every GameButton and slider in each scenario and asserts `get_global_rect().size.y ≥ 88` (logical) for primary actions.
3. **Contrast:** check label vs face luminance for each button kind (R13).
4. **Seams:** zoom in on slice borders at pc_1366x768 and pc_1080p_z125 (R8).
5. **Pressed state:** a scenario arg or unit test that renders GameButton in all 5 states per kind (R11 visual check).
6. **Review gallery:** put before and after side by side on one page for Vlad.

---

## Decisions proposed to the lead

1. Secondary = **blue-dark**, not blue-regular (contrast, R13). Labels on non-yellow faces get a dark outline.
2. Ghost kind = Flat Square white×NAVY_3, alpha 0.85. It has no native pack equivalent.
3. Small buttons (≤72 px) use scale 1.0; standard buttons use 1.25. Sub-88 visuals keep an 88 px hit rect.
4. Recolour rule: native colour family when the role matches, `0. White` + baked `tint` for palette-only colours, `modulate` only for alpha.
5. Cards at scale 0.8. Selected cards get a yellow Thin frame; accent / rarity cards get a white Thin frame × accent.
6. NEW = a red text chip plus a `radio-on-red` dot, not the exclamation icon.
7. Scrollbars stay flat until UiSvg gets a `rotate` key.
8. Close uses the plain X glyph on a red round button, not the self-contained `X Button` icon (it would put a button on top of a button).

## Notes for the foundation engineer

- `UiSkin.texture()` / `apply_toggle()` only use layer 0. The seeded `toggle` piece is layered (track + knob), so the knob would disappear. Bake layers into one texture, or render toggles as a stylebox + separate knob.
- The seeded `toggle` pieces use an `offset` key that is not in `LAYER_KEYS`.
- Verify ThorVG handles `<style>` class `opacity:0` (R11).
- Seeded slices differ from the measured values (button 10/10/10/20 vs 9/9/9/19 on the 2.5 art; container 18/18/18/26 vs 15/15/15/25). The manifest in PR 1 will use the measured values.
