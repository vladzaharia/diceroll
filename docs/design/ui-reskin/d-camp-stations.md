# UI reskin, area (d): the Camp and its stations

Planner: area (d). Status: plan only (no code changed). Date: 2026-09-30.
Aligns with the lead's draft `docs/design/2026-09-30-ui-reskin.md` and `ui/icons/icon_map.json`
(branch `wp-ui-design`, in progress) and with the foundation APIs on `wp-ui-foundation`
(`Icons`, `UiSkin`, `UiSvg`, `ui/theme/ui_pack.json`, in progress). Where they have not decided
something yet, this doc proposes it and marks it **[LEAD]** (a design call) or **[FOUNDATION]**
(an API request).

Decided upstream, and assumed throughout this doc:

- Look "night navy + wood": modal = Frames/Nailed dark brown with a navy fill.
- Buttons = 3D Square 2.5 (primary yellow, secondary blue, danger red, success green, disabled
  grey). Icon-only buttons = 3D Round. Chips and pills = Flat Round 2.5.
- Cards = Containers/3D white modulated to NAVY_3, with a yellow Thin frame overlay when
  selected. Bars = Bars/Regular (the mastery bar is yellow, XP purple).
- Icons = `<Name> Outline.svg` full colour by default. `Flat White` + tint is used only for
  small tinted glyphs. SVG only.
- `Icons.rect/texture/tex` take the existing ids, and unmapped ids fall back to the drawn glyph.
  `tint: null` means the caller's tint is ignored.
- `UiSkin.stylebox(piece, state)` / `apply_panel` / `apply_button` read pieces from
  `ui/theme/ui_pack.json` and fall back to StyleBoxFlat when the art is missing.

Before-shots:
`/private/tmp/claude-501/-Users-vlad-Repos-diceroll/1bba73af-2ee7-40a8-8c95-50839b8aed16/scratchpad/ui-plan/d/before/<profile>/<scenario>__<device>.png`.
Candidate icon sheet: `.../scratchpad/ui-plan/d/d_candidate_icons.png`. (Scratch files are not
committed. See §5.1 for the shoot-script stall found while taking them.)

---

## 1. Inventory

All sizes are in canvas px. The project canvas is 720x1280 with `canvas_items` + `expand`. That
makes a phone in portrait 720 px wide (iPhone 17: 720x1566; Duo outer: 880x1280, the shortest),
iPad and desktop landscape 1280 px tall (1366x768 → 2277x1280), and iPhone landscape 2783x1280
(everything tiny).

### 1.1 Camp hub overlay: `ui/camp/camp_screen.gd` (`CampScreen`)

| Part | Structure / current style | Icon ids | Seen in |
|---|---|---|---|
| Vignette `_Shade` | top 16% / bottom 28% ink gradients | – | all camp shots |
| Currency header | `PanelContainer` + `UiTheme.panel_box("pill")` (r40, 2px GOLD_FAINT); `CampUi.crowns(0,30)` + `CampUi.sigils(0,30)` → `CampUi.amount` = `UiIcons.rect(icon, 1.15×size, tint)` + Lilita label; count-up tween + pop | `crown` (GOLD_BRIGHT), `star` tinted `c79bff` (= Sigil) | camp_first/mid/max, every station shot (the header stays above the modals) |
| Home / Settings | `GameButton.round_icon("home"/"gear", 84)`, `Kind.GHOST`, tint TEXT / GOLD | `home`, `gear` | all |
| Station tags (×4) `StationTag` | `PanelContainer`, `UiTheme.box(navy 0.88, r30, 2px station colour 0.7, shadow 10)`, pad 10/6, right 18. Row: `OptionCard.Medallion` 50px (icon + ring tinted in the station colour, TEXT_MUTED when locked) + name (Lilita 24) + sub (16px: blurb / lock text wrapped at 170 / "N ready to buy" in HEAL green). Red count badge `_dot` (box HP r14, 2px OUTLINE, 16px label) at (-2,-22) in a holder | `anvil`, `dice`, `heart`, `star` (`CampInfo.STATIONS`) | camp_first (Armory + Pet Den locked), camp_mid (4 badges: 4/3/11/4), camp_max, every station shot (the tags fade out when a modal opens) |
| Tag placement | `_process`: `cam.unproject_position(scene.station_anchor(id))`, x clamped to [8, W-8], y clamped between the header and the bottom panel. **No overlap resolution.** Hidden when `any_open()` or `revealing` | – | – |
| Bottom panel | `PanelContainer` box PANEL_SOFT r30 2px GOLD_FAINT shadow 18, pad 18/14, max width 620. Loadout row: class medallion 58 + name 28 + mode/asc 17 + pet badge (Medallion 52 + "L5") + minigame badges (Medallion 52) + Wardrobe `round_icon("wardrobe", 80)` SECONDARY tint `c79bff` + red `_Dot` 22px when skins are unseen. Buttons: CONTINUE (SECONDARY, 100 tall, `arrow_right`) + START RUN / NEW RUN (PRIMARY 40pt, `dice`) | `class_*`, `CampInfo.PET_ICON[pet]`, `CampInfo.MINIGAME_ICON[id]`, `wardrobe`, `arrow_right`, `dice` | all camp shots; camp_wardrobe (NEW dot) |
| Skip hint | label "TAP TO SKIP" 22 | – | camp_reveal |
| Welcome modal `WelcomeModal` (UiModal) | 2 paragraphs + a row of 4 station medallions (64) + LET'S GO (PRIMARY, `arrow_right`) | station icons | camp_first |

### 1.2 Shared builders: `ui/camp/camp_ui.gd` (`CampUi`) and `ui/camp/camp_modal.gd` (`CampModal`)

`CampUi` is also used by `ui/screens/summary_screen.gd` (15 calls), `ui/screens/class_select.gd` (3)
and `ui/widgets/class_card.gd` (2). **Those are file overlaps.**

| Builder | Current | Used by |
|---|---|---|
| `card(hi, accent)` | `panel_box("card"/"card_hi")`. An accent recolours the 2px border | every station, results |
| `locked_card()` | box(ink 0.9, r24, 2px white 0.06), pad 20/16 | locked pets / packs / minigames / ranks / Belt Pouch |
| `amount / crowns / sigils` | icon + number | header, results |
| `buy_button(verb, cost, affordable)` | `GameButton` PRIMARY / SECONDARY + currency icon, min h 72 (pickers use 60–64) | every purchase |
| `chip(text, bg, fg, size)` | box r12, pad 10/3, clamp 16px text | EQUIPPED, OWNED, NEW, TIER, KIT, 2H, STYLE, WORN, MAX, GOLD TIER, PREVIEW·LOCKED… (~25 call sites) |
| `lock_line(text)` | procedural `LockGlyph` + muted para | ~14 sites |
| `bar(cur, need, color)` | `ProgressPill` (drawn) | pet XP, mastery, blueprint progress |
| `pips(level, max, color, marks)` | `LevelPips` (drawn circles, gold diamonds at tiers) | ranks, pet levels, charge meter, minigame mastery |
| `title_row(icon, color, title, sub, px)` | `OptionCard.Medallion` + title 30 + sub 19 | rank cards, pouch, pet / pack / minigame / whetstone cards |
| `tile(...)` / `Tile` | box states (selected gold 3px / enabled / disabled), icon 26, check | arcade slots, workshop toggles and starter kind |
| `CampModal` | extends `UiModal` (ribbon + `panel_box("main")`); max width 720; close = `GameButton.round_icon("close", 72)` SECONDARY at the top right; `top_inset` keeps the currency header visible | all stations |
| `CampModal.heading(text, sub)` | `UiModal.section_label` (gold 20) + muted para 19 | all stations |

### 1.3 Armory: `ui/camp/armory_modal.gd` (1079 lines, the densest screen)

Wide layout when `w > 1.25h` (`max_width` 1180, doll / appearance / ranks on the left, picker on
the right). Otherwise one column, 720.

| Component | Structure / style | Icons / thumbs | Scenario |
|---|---|---|---|
| Class switcher `_classes` | row of `Medallion` 54 (64 when selected) | `class_*` | ui_armory (all) |
| Paper doll `_doll` | `CampUi.card(true, class colour)`, name 32 + "KIT +1 TIER" chip. 3 left + 4 right slot tiles (`_Tap`, box r18, gold 3px when selected), 96px (92 wide) + caption 16. Centre `HeroPortrait` (3D SubViewport, min w 150) | `ItemThumb.make(shown, px)`. Empty / Belt Pouch locked: `SLOT_ICONS` glyph (`sword shield helmet armor ring pouch cape`) at 22% white. Tier badge (roman numeral, `TIER_COLORS` border). Look badge `mirror` 18 in violet. NEW red dot (`WardrobeModal._Dot`). `LockGlyph` on the pouch | ui_armory, ui_armory_appearance |
| Picker `_picker` | heading + compact rank card + "Nothing" card (`close` 30) + item cards. `_card_box` (equipped gold 3px / focused accent 3px / owned / not owned) | item card: `_thumb_box(100)` well (box r16) + `ItemThumb` 96 (greyed when not owned) + `LockGlyph` + "NEW" chip; name 25; chips `STYLE` / `TIER n` / `RANK 0` / `★ KIT` / `2H` / `EQUIPPED`; rule para 18; mastery line + bar; `_acquire`: lock_line + BUY (crowns) + (sigils) buttons 60 tall | ui_armory_picker |
| Variants `_variants` | 3 columns (4 wide) of `_variant_chip` (box r16: worn gold / selected accent / craftable gold / owned / locked), `ItemThumb` 70, NEW chip, name 18, state line 17 (WORN / OWNED / CRAFT n / n / m fights / FEAT), mini bar 8 | 3D thumbs per variant | ui_armory_craft |
| Craft card `_variant_detail` | `CampUi.card(craftable)`, name 24 + tag chip, desc, 2H warning, CRAFT buy buttons (crowns + sigils), or lock_line + bar + cost text | – | ui_armory_craft |
| Appearance `_appearance` | 2 `card(false, c79bff)` rows, flow of `_look_chip` 64 (box r14, violet 3px when on). OWN = class Medallion 48 + "OWN". HIDE = `close` 34 + "HIDE". Items = `ItemThumb(value, 64, slot)` + green `_EqDot` + red "i" when the fit is bad | ui_armory_appearance |
| Ranks `_ranks` / `_rank_card` | `card(up)` / `locked_card`, `title_row(GROUP_ICONS, 48/56)`, RANK UP / FORGE buy (64 tall) or MAX chip, pips(8, marks 1/4/8), "Next:" line. `_flash` = a floating Lilita "RANK 5!" / "TIER II!" tag + pop | `sword shield armor ring` | ui_armory_rankup |
| Belt Pouch `_pouch_card` | card / locked, `title_row("pouch")`, BUY 400 or lock line | `pouch` | ui_armory_rankup, fresh |

### 1.4 Wardrobe: `ui/camp/wardrobe_modal.gd`

| Component | Structure | Icons | Scenario |
|---|---|---|---|
| Class carousel `_Pick` | grid of 6 columns; Medallion 64/72, name 16; locked = muted + dimmed; secret = `question`; red `_Dot` NEW | `class_*`, `question` | ui_wardrobe demo / fresh |
| Pedestal `_stand` | `card(true)`, `HeroPortrait` h 330 (280 wide), class name 32 + skin 26 + chip (WORN / PREVIEW · LOCKED) | – | ui_wardrobe |
| Skin swatches `_swatch` ×4 | 2-column grid; box (worn gold / previewed violet / owned class colour / locked); `HeroPortrait` h 170 (150 wide) spin 0; LockGlyph + name 24 + NEW chip; WORN chip / "Tap to wear" / condition + progress text + BUY 250 (capped profiles only) | LockGlyph | ui_wardrobe demo, `--profile=capped` |
| Prestige `_prestige` | `card(on)`, Medallion `crown` 60, title 24, ON / OFF `GameButton` (`check` / `close`) | `crown`, `check`, `close` | ui_wardrobe demo |

### 1.5 Pet Den: `ui/camp/pet_den_modal.gd`

One intro para, then 12 pet cards (`card(equipped, pet colour)` / `locked_card`).
`title_row(PET_ICON[id], 72)` + EQUIPPED (SUCCESS, `check`) / EQUIP / UNLOCK (sigils) button.
Charge meter = pips in a box. Four `_line` rows: a chip tag (Fires / Board / L5 / L10) + para 19.
Progress: `xp` icon + bar + "n / m fights to L+1", or pips(10, marks 5/10) + LEVEL n buy / MAX
LEVEL chip. **Today only 6 of the 12 pets have an entry in `CampInfo.PET_ICON`
(heart/skull/flame/reroll/shield/coin). The other 6 fall back to `heart`.** That is a real gap
the reskin fixes. Scenarios: ui_petden (mid default, fresh, max).

### 1.6 Dice Workshop: `ui/camp/workshop_modal.gd`

- Unlock packs ×8: `title_row("dice")` for every pack (no per-pack icon), OWNED chip or UNLOCK,
  then a flow of item chips: rune icons, `dice` per kind, `PassiveIcon.make(id, 28)`.
- Drop pools ×3: `Tile` toggles (rune / `dice` / passive glyph), "OFF" in red, "n / m off".
- Starter kit: `title_row("dice")` + BUY + kind tiles (`dice` tinted by kind).
- Whetstone: `title_row("anvil")`.

Rune, passive and die-kind icons belong to the lead's map (groups rune / passive / die_kind).
This screen only consumes them. Scenario: ui_workshop (mid, max, fresh).

### 1.7 Arcade: `ui/camp/arcade_modal.gd`

- Loadout: 3 `Tile`s (minigame icon + "Tap to remove" / "Empty slot" `plus` / third slot
  `locked_card` with a buy or lock line).
- 11 minigame cards: `title_row(MINIGAME_ICON, 64)` + EQUIPPED / EQUIP / SWAP IN / UNLOCK,
  description, a "GOLD TIER" chip + signature text, and MASTERY pips + "+n% gold · n / m plays".

Today `MINIGAME_ICON` reuses generic glyphs (skull, star, coin, trophy, bolt, dice, chest,
mirror, snowflake, crown, up). Scenario: ui_arcade (mid, fresh).

### 1.8 Run setup: `ui/camp/run_setup_modal.gd` (a Camp modal, opened by START RUN)

Hero card + kit + class cards (`ClassCard`, which is another area's widget), mode tiles,
ascension stepper (`arrow_left/right` round 68), pet card (`title_row(PET_ICON)`), minigame
card (`UiIcons.rect(MINIGAME_ICON, 26)`), START. It is in scope only for the icon ids it shares
(pet, minigame, station colours) and the `CampModal` frame. Its class-card styling belongs to
the class-select owner. Scenario: ui_run_setup, ui_mk_mystery.

### 1.9 Camp info, milestone / unlock lists, toasts

- `ui/camp/camp_info.gd` (`CampInfo`) is the single source of the Camp icon vocabulary:
  `PET_ICON`, `MINIGAME_ICON`, `GEAR_ICON`, `SLOT_ICON`, `STATIONS`, `icon_of(kind, id)`
  (classes → class icon, biomes → biome, bosses → `crown`, minibosses → `skull`, pets, minigames,
  packs → `dice`, gear → group glyph, items → slot glyph, potions → `potion`, features → `plus`).
  `nearest_goals()` also emits `question` (a secret) and `crown` (a Crowns goal).
  **Consumers outside this area:** `summary_screen.gd` (goals list, unlock cards),
  `game_controller.gd` (toasts), `run_setup_modal.gd`, `class_select.gd`.
- Camp toasts: `GameController._camp_toast` → `overlay.toast(text, icon, color, 0.84)`
  (`game/flow/overlay.gd` is not in this area). The icons are "Unlocked: X" = `CampInfo.icon_of`,
  "New item: X" = slot glyph, "Crafted" = `anvil`, "New skin" = `wardrobe`, upgrades = `up`,
  errors = none.
- Build-out reveal: `camp_scene.reveal` → `overlay.announce(text)` ("THE ARMORY IS OPEN!",
  "… MOVES IN"). Text only.
- Armory `_flash` ("RANK 5!", "TIER II!", "NEW SLOT!"): a Lilita label that rises off the card.
  In `before/demo/ui_armory_rankup__duo_outer.png` the "RANK 5!" tag lands on the RANKS heading
  rather than on the card (visible partly under the "Ranks" subheading).

---

## 2. Proposed mapping

### 2.1 Frames, cards, buttons: pieces this area needs in `ui_pack.json`

**[LEAD]** Please adopt these piece names (or rename them). They let `CampUi` stop hand-building
`UiTheme.box` (there are 36 raw `UiTheme.box` calls in `ui/camp/*.gd`). Each piece needs
`UiSkin.stylebox` + a StyleBoxFlat fallback equal to today's look, so the switch is safe before
the art lands.

| Piece (proposed) | Art | Replaces |
|---|---|---|
| `panel_main` (lead) | Frames/Nailed dark brown + navy fill | `CampModal` panel, `WelcomeModal` |
| `card` / `card_hi` (lead) | Containers/3D white → NAVY_2/3; `card_hi` + Frames/Thin yellow overlay | `CampUi.card` |
| `card_locked` | Containers/Flat grey-darker, modulate 0.85, saturation 0.3 | `CampUi.locked_card` |
| `card_accent_<colour>` **or** a runtime `modulate` override | Containers/3D white with the border tinted by the accent | `CampUi.card(false, accent)`: pet, minigame and class colours. **[FOUNDATION]** needs a `UiSkin.stylebox(piece, state, overrides := {modulate, tint})` so we don't need 20 pieces |
| `select_worn` / `select_on` / `select_craftable` / `select_owned` / `select_off` | Containers/Flat navy + Frames/Thin (yellow / purple / orange / navy-light / none) | armory `_card_box`, `_variant_chip`, `_look_chip`, slot tiles, wardrobe `_swatch`, `CampUi.Tile` states (same five states everywhere) |
| `well` | Frames/Inset navy-darker (slice 34/39/34/44 at scale ≈0.35) | `_thumb_box`, the pet charge-meter box, holders around 3D thumbs |
| `chip` + colour states (`chip_green` EQUIPPED/WORN/OWNED, `chip_red` NEW, `chip_gold` TIER III / MAX / GOLD TIER, `chip_blue` TIER II, `chip_grey` TIER I / RANK 0, `chip_violet` STYLE / look) | Buttons/Flat/Round 2.5 (3-slice, 27 L/R) at scale ≈0.45 so the height stays ≈26 | `CampUi.chip` (~25 sites) |
| `pill_hud` | Buttons/Flat/Round darker navy + Thin yellow rim | currency header (`panel_box("pill")`) |
| `tag_station` | Containers/Flat darker + Frames/Thin in the station colour (orange / blue / yellow / pink rows exist in the pack) | `StationTag` |
| `badge_count` | Buttons/3D/Round/2. Red, 1:1, min 30 | tag count dot, NEW dots (`WardrobeModal._Dot`, `_EqDot` → green) |
| `bar_mastery` / `bar_xp` (lead: Bars/Regular) | Bars/Regular yellow / purple, Bars/Thin for the 8–12 px mini bars | `CampUi.bar` → a `ProgressBar` with `UiSkin.apply_progress` |
| Buttons | lead's `button_primary/secondary/success/danger`; round 3D for `round_icon` | `buy_button`, EQUIP / EQUIPPED, prestige ON/OFF, Home / Settings / Wardrobe / close |

Pips (`LevelPips`) and the charge meter stay procedural (the lead's missing list keeps
`level_badge` procedural too). They get recoloured with pack colours: a filled pip = the
yellow-regular fill, an empty pip = navy-darker, and tier marks = the gold Star glyph (see tiers
below) instead of drawn diamonds.

### 2.2 Icon ids: what each Camp concept should use

Use the lead's ids from `icon_map.json` wherever they exist. **Bold** = a change or an addition
this area proposes. Paths are relative to `third_party/rhosgfx/vector-icon-pack-pro/` unless
noted.

**Currencies and HUD**

| Concept | id | SVG | Note |
|---|---|---|---|
| Crowns | `crown` | Clothing/Crown/Crown Outline.svg | lead ✔ |
| Sigils | `sigil` | Currency/Star Gem/Star Gem Purple Outline.svg | lead ✔. `CampUi.SIGIL_ICON` → `"sigil"`, and drop the SIGIL_COLOR tint (full colour) |
| Home / Settings | `home` / `gear` | General/Home, General/Settings (Flat White on 3D Round) | lead ✔ |
| Close | `close` | UI/X Flat White on red round | lead ✔ |

**Stations**

| Concept | id | SVG | Note |
|---|---|---|---|
| Armory | `station_armory` | lead: Armor Helmet. **Proposal: Tools/Anvil/Anvil Outline.svg** | **[LEAD]** The helmet is also `slot_head` inside the Armory, and the 3D station is a forge with an anvil. The anvil keeps "station ≠ slot" |
| Workshop | `station_workshop` | Items/Dice/Dice Outline.svg | lead ✔ |
| Pet Den | `station_pet_den` | General/Paw/Paw Outline.svg | lead ✔ |
| Arcade | `station_arcade` | Technology/Joystick/Joystick Outline.svg | lead ✔ |
| Wardrobe | `station_wardrobe` / `wardrobe` | Clothing/Outfits/Outfits Outline.svg | lead ✔ |
| Run setup | **`station_setup`** | Items/Flag/Flag Checkered Outline.svg (= `flag`) | new id, or reuse `flag` |

**Locks, NEW, states**

| Concept | id | SVG | Note |
|---|---|---|---|
| Lock | `lock` | General/Lock/Lock Outline.svg | replaces `CampUi.LockGlyph` (≈17 sites here) |
| Unlocked moment | `unlock` | General/Lock/Unlock Outline.svg | the unlock toast |
| NEW | lead: red text chip + dot; `new` = Sparkle | General/Sparkle | NEW chips → `chip_red`; the dots → `badge_count` with no text |
| Equipped / worn | `check` | UI/Check Mark | on EQUIPPED buttons |
| Hidden look | **`look_hidden`** | UI/Blocked/Blocked Outline.svg | replaces `close` on the HIDE chip (close means "dismiss" everywhere else) |
| Other look shown | `mirror` | Weapons/Shield/Shield Mirror Outline.svg | lead ✔ (the violet look badge) |
| Bad fit "i" | **`info`** (Outline variant) | UI/Info/Info Outline.svg | replaces the drawn red "i" |
| Secret | `class_locked` / `question` | UI/Question Mark Outline | lead ✔ |

**Tiers.** **[LEAD]** Proposal: keep the roman numerals as text, which is the source of truth.
Draw them on a `chip_grey` / `chip_blue` / `chip_gold` pill, and put a `tier_1/2/3` glyph in the
slot-tile corner badge:

- `tier_1` = General/Star/Star Bronze Outline.svg
- `tier_2` = Star Silver Outline.svg
- `tier_3` = Star Gold Outline.svg

That matches the pack's own Bronze / Silver / Gold metal language. It also means pips can use
the gold star as the tier mark. `TIER_COLORS` becomes bronze / silver / gold (today it is grey /
steel / blue / gold). The pips' tier marks at ranks 1 / 4 / 8 are drawn with the matching star.

**Slots**

| Concept | id | SVG |
|---|---|---|
| Weapon | `slot_weapon` | Weapons/Sword Outline |
| Off-hand | `slot_offhand` | Weapons/Shield/Shield Wood Outline |
| Head | `slot_head` | Clothing/Armor Helmet Outline |
| Body | `slot_body` | Clothing/Armor Chestplate Outline |
| Trinket | `slot_trinket` | Clothing/Ring Outline |
| Belt Pouch | `slot_trinket2` | Items/Pouch Outline |
| Back | `cape` | lead: Outfits PB (weak) |

For empty and pending slots, render the `Flat White` variant of the same art at 22% alpha. That
is the one tinted use: an empty slot must read as a ghost, not as an item. **[FOUNDATION]**
needs a variant or saturation request (see §4.2).

Rank groups reuse the slot glyphs: weapon / offhand / armor = `slot_body` / trinket. `rank` =
General/Upgrade is used on the RANK UP button.

**Crafting**

| Concept | id |
|---|---|
| Blueprint | `blueprint` = Items/Scroll 2 |
| Craft | `craft` = Tools/Hammer (was `anvil`) |
| Feat | `feat` = Trophy Silver |
| Kit | `kit` = Star Gold (replaces the "★" character in "★ KIT") |
| Mastery | `mastery` = General/Stats |
| Preview attack | `preview_attack` = UI/Spectate |
| Two-handed | text chip (lead: no pack icon) |

**Pets: 12 ids.** The lead's glyphs are good. See the contact sheet for my alternates:
Jack O Lantern Lit for the Pumpkin Sprite, Ghost Green for the Lantern Ghost, OvershieldBlue for
the Guard Die, Fire for the Wick. Either set works.

**Id collision [LEAD, important].** `pet_<id>` is already the id of our own **pet portrait
SVGs** (`ui/icons/pet_*.svg`). `meta_hud.gd:593` and `game/pets/meta_beats.gd` use them for the
in-run pet HUD and popups. The lead's missing list says to keep those portraits. But mapping
`pet_pumpkin_sprite` in `icon_map.json` makes `Icons` return the pack glyph for them too.
Proposal: name the pack glyphs **`petg_<id>`** (glyph), or rename the portraits to
`pet_portrait_<id>`, and point `CampInfo.PET_ICON` at the chosen ids. For the Camp (Pet Den card
medallion, bottom loadout badge, run setup, results): **use the pack glyph for all 12 pets**.
This fixes the 6 pets that fall back to `heart` today.

**Minigames: 11 ids.** Use the lead's `mg_*` set. It is better than mine for Fossil Hunter
(shovel), Shell Game (cup) and Memory Match (card). High / Low = a Ladder is weak: I suggest
**Items/Card/Card Diamond Outline + UI/Arrow Up badge**, or the pack's Double Arrows. Plinko is
weak in both sets (lead's missing list).

**Dice packs: 8 ids. [LEAD]** The lead has one `pack` = Gift Box. Proposal: keep `pack` for the
generic "Workshop pack" unlock, and add **per-pack ids** so the 8 pack cards stop being eight
identical dice:

| id | SVG |
|---|---|
| `pack_starter` | Shapes/Gaming Dice/D6 Outline |
| `pack_gamblers_kit` | Items/Lucky Block/Lucky Block Green Outline |
| `pack_cold_steel` | Materials/Ice/Ice Outline |
| `pack_pyromancy` | Nature/Fire/Fire Outline |
| `pack_storm` | Nature/Storm/Storm Outline |
| `pack_numerology` | UI/Numbers/7/7 Outline |
| `pack_resonance` | Music/Tuning Fork/Tuning Fork Outline |
| `pack_colossus` | Shapes/Gaming Dice/D20 Outline |

Whetstone and the starter kit use the lead's `upgrade_whetstone` / `upgrade_starter_kit`.

**Wardrobe**

| Concept | id |
|---|---|
| Prestige medallion | `skin_prestige` = Crown (lead) |
| Prestige overlays in the title | text only |

Skin swatches stay 3D portraits (see §2.3). The `vector-hats` pack is not needed for skins:
skins are whole-body KayKit looks.

**Items: 64 base ids.** The lead maps 40 as `item_<id>` fallback glyphs, and the rest (8 bodies,
3 heads, 13 backs, all variants) keep the 3D thumbnail + slot glyph. I agree. Add one helper:
**`CampInfo.item_icon(id)`** = `"item_" + ItemDefs.base_of(id)` if `Icons.is_mapped` it, else
`SLOT_ICON[slot]`. `icon_of("items", id)` and the "New item" toast call it.

**`CampInfo.icon_of` retarget**

| Kind | Now | New |
|---|---|---|
| bosses | `crown` | `boss` (the lead freed `crown` for the currency) |
| minibosses | `skull` | `skull` (unchanged) |
| packs | `dice` | `pack_<id>` / `pack` |
| gear | group glyph | `slot_*` |
| features | `plus` | `upgrade_<id>` |
| potions | `potion` | `potion_<id>` |

### 2.3 Thumbnails: replace or complement? Decision table

Principle: **a pack SVG replaces a drawn glyph. It never replaces a 3D render that shows the
exact model the player will wear or see in the camp.** Pack icons are generic ("a sword").
Our 3D thumbnails are specific (the Saber vs the Rapier vs the Flame Sword), which is the whole
point of the Armory.

| Where | Today | Decision | Why |
|---|---|---|---|
| Doll slot tile, equipped | `ItemThumb` 96 | **Keep 3D**. Pack slot glyph (Flat White 22%) only when empty or the render is pending / headless. Frame the tile with `select_*` + `well` | The variant model is the information. ~50 variants have no distinct pack art |
| Picker item card | `ItemThumb` 96 in `_thumb_box` | **Keep 3D** in a `well` (Frames/Inset). Locked = the 3D thumb desaturated + a `lock` glyph 26 at the bottom right | Same. The inset frame gives the render the "pack" feel without redrawing the item |
| Variant chips | `ItemThumb` 70 | **Keep 3D** | Variants differ only in model |
| Appearance look chips | `ItemThumb` 64 + class Medallion | **Keep 3D**. OWN = class icon, HIDE = `look_hidden` | Looks are visual by definition |
| Craft card | text | **Add** `blueprint` / `craft` glyphs to the heading and the CRAFT button | New affordance, no 3D there |
| Rank / Belt Pouch cards | Medallion + group glyph | **Replace** with the pack slot glyph in a round medallion | It was a drawn glyph |
| "New item" / "Crafted" toast | slot glyph / `anvil` | **Complement**: `ItemThumb.cached(id)` if the render is in the cache, else `item_<base>` / `slot_*`; "Crafted" → `craft` | Toasts must be instant. The pack glyph is a crisp fallback |
| Results item cards (summary_screen, another area) | ItemThumb | Keep 3D (flag to that planner) | – |
| Pet Den / loadout pet badge | Medallion + generic glyph | **Replace** with the pack pet glyph (`petg_*`) | No 3D pet thumb exists, and 6 pets currently show a heart. A future `PetView` thumbnail could complement it; out of scope |
| Wardrobe swatches / pedestal | `HeroPortrait` 3D | **Keep 3D** | Skins are whole-hero looks |
| Class medallions (switcher, carousel, loadout) | class glyph | Use the lead's `class_*` ids | Owned by the class-icon mapping |
| Minigames, packs, stations | drawn glyphs | **Replace** with pack icons | Pure glyphs |
| Currency header / buy buttons | `crown` / tinted `star` | **Replace**: `crown`, `sigil` full colour | – |
| KayKit `3d:*` rendered props | not used in the Camp | – | – |

### 2.4 Station tags and the "N ready to buy" badge (crowding fix)

This follows up UX-pass item 20: "tags crowd the rooftops; Pet Den badge 11 is a nag number".
It is visible in `before/mid/camp_mid__iphone17_17pro.png` and
`before/demo/ui_armory_rankup__duo_outer.png`: the Dice Workshop and Pet Den tags sit on the
header row, and the Armory and Arcade tags overlap the rooftops.

1. **Skin**
   - Tag = `tag_station` (Containers/Flat darker navy + Frames/Thin in the station colour).
   - Medallion = the pack station icon on a 3D Round button face (46).
   - Name = Lilita 24.
   - The sub line is dropped by default.
2. **Badge**
   - Tag badge = `badge_count` (3D round red) with the number. Show "9+" above 9, or just a dot.
   - **[LEAD]** Proposal: show a number only for 1–3 ready items and a pulsing dot above that. The
     "N ready to buy" text moves into the modal (a line under the station ribbon), not the tag.
3. **Compact mode**
   - Trigger: the tag's canvas-px height is > 6% of the viewport height, or the tags collide.
   - Show medallion + name only. The locked text also moves to the tap feedback (a toast
     "Reach lap 5 to open the Pet Den") instead of a 170 px wrapped paragraph on the tag.
4. **Overlap resolver in `CampScreen._process`**
   - Project all four tags, sort them by y, then relax them for 2–3 iterations: push
     overlapping rects apart vertically, keeping each within ±60 px of its anchor.
   - Clamp them to `free_rects()` so they never touch the header, the Home / Settings buttons or
     the bottom panel.
   - Draw a small stem (Frames/Pointed tip, or a 2 px line) from the tag to the anchor when it
     was displaced by more than 24 px.
   - Also keep the tags out of the top-right close-button zone. They fade on `any_open()`, but
     during the fade they sit under the close button.
5. **iPhone landscape (2783x1280 canvas)**: the tags render at about 7 pt. Give the whole
   `CampScreen` a `ui_scale` ≥ 1.4 when `size.x / size.y > 1.9`. **[LEAD]** This is a global
   policy question for the whole landscape phone layout, not just the tags.

### 2.5 Toasts and floating tags

- `_camp_toast` icon ids are retargeted as in §2.2: `unlock` or the item's icon, `craft`,
  `wardrobe`, `rank`.
- The toast panel skin itself belongs to the overlay owner (a pill / container piece).
- The Armory `_flash` label: Lilita gold with an 8 px outline, unchanged, plus a small Sparkle
  (`new`) burst. Anchor it to the card's top edge, not its centre, so it clears the section
  heading.

---

## 3. Layout risks

The numbers below come from the current code and the lead's measured 9-slice margins (SVG
units; the logical px depend on the per-piece `scale`, which the lead has not fixed yet).

| # | Risk | Where | Evidence / numbers | Mitigation |
|---|---|---|---|---|
| R1 | **Nested thick frames eat width on phone.** Panel (Nailed, 24 L/R units) → card (Container 3D, 15 L/R) → well (Inset, 34 L/R) → a 96 px thumb. At scale 1.0 that is 24+15+34 = 73 px per side vs today's 32+12+2 = 46 | Armory picker item card, variant chips, Pet Den line rows | Phone content width today: 720 − 2×32 = 656; the card text column is ≈508. At scale 1 the column drops to ≈450 and the rule text wraps to 4–5 lines | Inner pieces at **scale ≈0.35–0.5** (the well rim ≤ 12 px, the card rim ≤ 8 px). Only the outer modal frame is thick. **Rule: a frame piece's rim is ≤ 12 px at every nesting level below the panel** |
| R2 | The paper-doll row: slot tiles 96+12 on both sides + portrait ≥150 | Armory doll, one column (the `wide` check fails below 1.25:1) | 620 content − 2×108 − 20 gaps = 384 for the portrait today. With `select_*` frames of 8 px per side, 352. OK. At Frames/Thin scale 1 (22 units), 296: the hero gets small | Keep `select_*` rims ≤ 8 px. If needed, the slot tiles drop to 88 on canvases narrower than 700 |
| R3 | **Duo outer** (880x1280, 111 px notch + 64 home) has the least height: header 70 + bottom panel ≈230 → the 3D free rect ≈ 750 px, and four tags live in it | Camp hub | `before/demo/ui_armory_rankup__duo_outer.png`: the tags touch the header. Modal frames also lose height to the Nailed bottom rim (34 units) | Tag compact mode + resolver (§2.4). The modal bottom rim ≤ 24 px. The `top_inset` is computed from the new header height |
| R4 | Chips: Flat Round pills need a 3-slice ≥ 27 units L/R. At scale 1 a "2H" chip is 54 px wide before text | Armory item head row (up to 5 chips: TIER, ★KIT, 2H, EQUIPPED, STYLE), `HFlowContainer` | Today a chip is ≈ text + 20 px | Chip scale ≈0.45 → 12 px caps. Fold "★ KIT" into a `kit` glyph-only chip (24 px) |
| R5 | Buy buttons: the 3D square button bottom lip is 19–20 units | RANK UP (compact rank card at 1.25 zoom already truncates "Weapon r…", UX-pass item 24), pet LEVEL n, BUY 400 | The button grows ≈ +8 px in height; the rank-card title loses width | Stack the button under the title when the card's content width is < 460 (this also fixes UX #24). Keep `min_height` 64 but count the lip in it |
| R6 | 1366x768 / ipadmini landscape (wide layout at 2277x1280 / 1133x744) | Armory wide 1180, Wardrobe | Fine on width. The Nailed frame's top and bottom rims (27 + 34) plus the ribbon plaque reduce the scroll area by ≈40 px | – |
| R7 | **Zoom 1.25 / 1.5** (`content_scale_factor`): on a phone the effective canvas is 576 → `UiModal.MIN_W` 620 → the panel shrinks to ≈0.93. At 1.5 on 1080p the modal is 720 logical, fine | All modals | DPITexture keeps the art crisp. Rims scale with the panel, so the relative density is unchanged | – |
| R8 | iPhone landscape: everything is at 0.314 scale (24 px → 7.5 pt) | Camp hub, all modals | `before/max/camp_max__iphone17_land.png`: the tags and bottom panel are tiny | Global policy **[LEAD]**. Not solvable per screen |
| R9 | **World-space tags vs the 3D scene**: pack colours (bright orange / pink containers) compete with the lit camp. The tags hover over rooftops and props. The stage-3/max camp is busier (banners, string lights) | Camp hub | `before/max/*` | Use the **darker** container variants, a 2 px black outline (pack style), and a soft drop shadow. The `_Shade` top gradient ends at 16%. Extend it to cover the tag band on tall phones (≈22%) |
| R10 | Full-colour icons ignore the caller's tint (the `Icons` contract). Locked stations, locked pets and minigames currently rely on a TEXT_MUTED tint | Station tags, Pet Den, Arcade, Workshop, Wardrobe carousel | Without a fix, locked cards show bright colour icons | **[FOUNDATION]** `Icons.rect(id, px, tint, {saturation})` or a `locked := true` flag that desaturates (`UiSvg.recolor(svg, null, 0.15)`) + modulate 0.7. Otherwise, locked = the Flat White variant tinted TEXT_MUTED (needs a `variant` arg). Pick one API; the whole reskin needs it |
| R11 | The 3D `ItemThumb` / `HeroPortrait` are rendered on navy. Inside a lighter Inset well the dark-steel helms (the Paladin Helm was nearly black, UX #9) may lose contrast again | Picker, doll | – | The `well` uses the *darker* navy variant. Re-check `ui_armory --slot=head` after the change |
| R12 | Scrolling containers inside a Nailed frame: the scrollbar sits against the nails | All modals | – | The theme's scrollbar gets a content inset ≥ the right rim (lead / slice a) |

---

## 4. Implementation plan

### 4.1 Steps (one engineer, in order)

1. **Wait for the prerequisites.** These are (a) `Icons` + `UiSkin` + `UiSvg` merged
   (foundation), (b) the lead's `icon_map.json` with the ids used here, and (c) slice (a)
   theme: `panel_main`, buttons, `GameButton` / `UiModal` / `Ribbon` / `OptionCard.Medallion`
   reskinned. The Camp inherits the modal frame, ribbon, buttons and medallion from (a) for free.
2. **`camp_info.gd`: the icon vocabulary.**
   - `STATIONS[*].icon` → the `station_*` ids.
   - `PET_ICON` → the 12 pet glyph ids (resolve the §2.2 collision first).
   - `MINIGAME_ICON` → the `mg_*` ids.
   - `SLOT_ICON` / `GEAR_ICON` → `slot_*`.
   - Add `PACK_ICON` and `item_icon(id)`.
   - Retarget `icon_of` (bosses → `boss`, packs, features, potions).
   - `nearest_goals` keeps `question` / `crown`.
   - Unit-testable headless: every id that `icon_of` / `PET_ICON` / `MINIGAME_ICON` returns
     must be `Icons.exists`.
3. **`camp_ui.gd`: the style gateway.**
   - `card` / `locked_card` / `chip` / `Tile` / `bar` / `amount` / `buy_button` switch to
     `UiSkin` pieces (§2.1).
   - Add `CampUi.select_box(state)` (worn / on / craftable / owned / off) and
     `CampUi.well(px)`.
   - `LockGlyph` → `Icons.rect("lock")` (keep the class as a deprecated shim for
     summary / class_select until they migrate).
   - `ProgressPill` → a `ProgressBar` + `UiSkin.apply_progress("bar_mastery" | "bar_xp")`.
   - `LevelPips` keeps drawing but takes pack colours and star tier marks.
   - `SIGIL_ICON` = `"sigil"`.
4. **`camp_screen.gd`**
   - Header → `pill_hud`.
   - `StationTag` → `tag_station` + `badge_count` + compact mode + the overlap resolver and stem
     (§2.4).
   - Loadout badges → the new ids.
   - The Wardrobe dot → `badge_count`.
   - `_Shade` band height.
   - `WelcomeModal` gets the station icons.
5. **`armory_modal.gd`** (largest)
   - Replace the 16 `UiTheme.box` calls with `CampUi.select_box` / `well`.
   - Tier badge → a star glyph + a numeral chip.
   - Slot glyph fallback → the Flat White slot art.
   - Look badge `mirror`, HIDE `look_hidden`, bad-fit `info`.
   - NEW → `chip_red` / `badge_count`.
   - Craft → `craft` / `blueprint` glyphs.
   - Rank card: stack the button when narrow (R5).
   - `_flash` anchor fix.
   - Also update `ItemThumb.SLOT_ICON` (its pending glyph) to the `slot_*` ids (a
     `ui/widgets/item_thumb.gd` touch-up; shared with results / kit strip).
6. **`wardrobe_modal.gd`**: the `_Pick` / `_swatch` boxes → `select_box`, `LockGlyph` → `lock`,
   `_Dot` → `badge_count`, prestige `skin_prestige`, the ON / OFF toggle → the lead's success /
   secondary buttons (or the pack Toggle widget, **[LEAD]**).
7. **`pet_den_modal.gd`**: pet glyph ids, the `_line` tag chips → `chip`, the charge meter →
   `well` + pips, the XP bar → `bar_xp` with the `pet_xp` icon, "Fires" with `pet_charge`.
8. **`workshop_modal.gd`**: `PACK_ICON` per pack, the item and passive chips → `chip` style, the
   pool `Tile`s → `select_box`, OFF = `chip_red`.
9. **`arcade_modal.gd`**: `mg_*` ids, GOLD TIER → `chip_gold`, the slots → `select_box`.
10. **`run_setup_modal.gd`**: the ids only (pet / minigame / station colours). The class cards
    belong to their owner.
11. **`game_controller.gd` `camp_command` toasts**: the icon ids (§2.5). The text is unchanged.
12. **Shoot the after set** (§5) and compare side by side. Fix R1–R5 regressions before the PR.

### 4.2 Dependencies and API requests

- Slice (a) theme: `panel_main`, the ribbon plaque, `GameButton` kinds, `round_icon`, the
  `OptionCard.Medallion` redraw with the pack glyph, `UiModal.section_label`, the scrollbar.
  **Steps 3–9 visibly depend on (a).** They can land before it, but they will look mixed.
- **[FOUNDATION]** Requests:
  1. **Desaturated / locked icons.** `Icons.rect(id, px, tint := null, opts := {saturation,
     variant: "flat_white"})`, or `Icons.locked(id, px)`. This is needed for R10.
  2. **Per-instance overrides.** `UiSkin.stylebox(piece, state, {modulate, tint})` so accent
     colours (pets, minigames, classes, stations) don't need a piece each.
  3. **A pack-piece texture at a size.** `UiSkin.texture("badge_count", "normal", 30)` exists
     already; confirm it composes layers.
  4. **`Icons.is_mapped`** for `CampInfo.item_icon` (exists ✔).
- **[LEAD]** decisions:
  1. `station_armory` = Anvil (vs Helmet).
  2. The `pet_*` id collision (`petg_*` or renaming the portraits).
  3. Per-pack icons.
  4. Tiers as bronze / silver / gold stars.
  5. The ready-count policy on tags (number ≤ 3, else a dot).
  6. The iPhone-landscape UI scale.
  7. The Wardrobe prestige ON/OFF as a pack Toggle.
  8. The new piece names in §2.1.

### 4.3 File overlaps (coordinate before editing)

| File | Also touched by | Overlap |
|---|---|---|
| `ui/camp/camp_ui.gd` | results / summary planner (15 calls), class select (3), class card (2) | Keep the signatures. Only styles change. Announce `LockGlyph` deprecation |
| `ui/camp/camp_info.gd` | results (goals, unlock cards), game_controller toasts | Id changes ripple into the results screen: coordinate the ids, not the code |
| `ui/widgets/item_thumb.gd` | results, kit strip (run HUD), overlay | `SLOT_ICON` only |
| `ui/camp/wardrobe_modal.gd` `_Dot` | camp_screen, armory (they use `WardrobeModal._Dot`) | Replace it with a `CampUi.dot()` |
| `game/game_controller.gd` | run HUD / flow planners | Only the `camp_command` toast icon ids (≈6 lines) |
| `game/flow/overlay.gd` (`toast`, `announce`, `popup`) | overlay / HUD planner | Not edited here. The toast skin is theirs |
| `ui/widgets/option_card.gd` (`Medallion`), `game_button.gd`, `ui_modal.gd`, `ribbon.gd` | slice (a) | Consumed, not edited |
| `ui/widgets/class_card.gd`, `ui/screens/class_select.gd` | class-select planner | Run setup consumes them |
| `ui/icons/icon_map.json`, `ui/theme/ui_pack.json` | lead / foundation | Send the requested ids and pieces to the lead. Don't edit them in this WP |

---

## 5. Test plan

### 5.1 Harness note: the shoot scripts currently stall (found while taking the before-shots)

On 2026-09-30, **every modal rendered invisible** in `tools/shoot.sh` shots: only the scrim, the
camp HUD and a floating close button appeared. This happened in my runs and in another agent's
`scratchpad/current/` batch, for the Camp modals and the in-run shop alike.

A headless probe (same scenario, 3 s) shows the modal open with its frame at alpha 1. The cause
is that the windowed process draws almost no frames: `--print-fps` printed nothing in a 4 s run.
Tweens and `_process` never advance, while the harness timer fires, so the modal's entrance
tween is still at alpha 0. This is probably macOS throttling the off-screen / occluded window's
vsync-driven loop, with about 15 Godot instances running.

**Workaround used for the before-shots:** the same scripts with engine flags
`--fixed-fps 30 --disable-vsync` added before `--`. Frame-stepped time makes `--wait` frame
based, and every shot then rendered correctly. The patched copies are in
`scratchpad/ui-plan/d/tools/`. **Recommend** adding these flags to `tools/shoot.sh` (or a
`SHOOT_FIXED_FPS` env switch) for the whole reskin effort. Otherwise every before/after
comparison of a modal is empty.

### 5.2 Scenarios (before = taken; after = the same commands on the reskin branch)

The profiles cover fresh / mid / max, plus the Armory "demo" (NEW items, a craftable blueprint,
Trinket rank 5, 520 Crowns) and the Wardrobe "demo" (owned / locked / NEW / prestige skins).

| Screen | Commands (`tools/shoot_matrix.sh <scenario> <dir> <set> …`) | Sets | Checks |
|---|---|---|---|
| Camp hub | `camp_first` (fresh + welcome), `camp_mid`, `camp_max`, `camp_wardrobe` (NEW dot), `camp_stage_2` | all / quick / all / quick / quick | Tags don't overlap each other, the header, Home / Settings or the bottom panel. The badge reads. Locked tags look locked. The icons on the 3D scene read (R9). Duo outer, iPhone landscape |
| Armory | `ui_armory` (demo), `ui_armory --profile=fresh`, `--profile=max`, `ui_armory_picker`, `ui_armory_craft`, `ui_armory_rankup` (`--frames=4` for the flash), `ui_armory_appearance`, `ui_armory --slot=head` (dark helm, R11), `ui_armory --slot=trinket2` (pouch locked), `ui_armory --class=barbarian --slot=offhand` (2H blocked) | all for demo, quick for the rest, plus the `zoom` set for demo | R1, R2, R4, R5. The text column is ≥ 440 px on the phone. Chips wrap to ≤ 2 rows. Tier badges read at 16 px. Thumbnails keep their contrast |
| Wardrobe | `ui_wardrobe` (demo), `--profile=fresh`, `--profile=capped` (BUY 250), `--preview=bossbane` | all / quick / quick / quick | The carousel grid (6 columns) fits at 720. Swatch portraits aren't cramped by the frames. The prestige toggle |
| Pet Den | `ui_petden` (mid), `--profile=fresh` (all locked), `--profile=max` (MAX LEVEL), `--scroll=1400` | all / quick / quick / quick | All 12 pet glyphs are distinct (no heart fallback). The locked look (R10) |
| Workshop | `ui_workshop` mid / max / fresh, `--scroll=1200` (pools) | quick | 8 distinct pack icons. Toggle states. OFF chips |
| Arcade | `ui_arcade` mid / fresh / max | quick | The slot tiles fit 3 across at 720. The GOLD TIER chip. The mastery pips |
| Run setup | `ui_run_setup` mid, `ui_mk_mystery` | quick | Pet / minigame icons consistent with the Den / Arcade |
| Toasts | `ui_armory_rankup --frames=6`; add a scenario `camp_toasts` (**new, proposed**) that fires unlock / new item / crafted / new skin / error toasts on the camp, one frame each | quick | The toast icons resolve. The 0.84 position stays clear of the bottom panel |
| Results goals (read-only check; owned elsewhere) | `ui_results_loss` (fresh: milestone cards), `ui_results_win` | quick | The `CampInfo.icon_of` retarget shows the right glyphs |

Pass criteria:

- No text under 16 canvas px (`--audit`).
- No tap target under 80 px (`--audit`).
- No element overlapping another (the tag resolver).
- Every Camp icon id resolves to a mapped pack SVG (a headless test: iterate `CampInfo` maps
  and `ItemDefs` → `Icons.is_mapped`, allowing the listed 3D-only fallbacks).
- The side-by-side before / after gallery has been shown to Vlad (memory: show review
  artifacts).
