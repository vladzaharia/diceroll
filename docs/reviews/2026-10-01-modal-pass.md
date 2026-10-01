# Modal pass: every popup, one look, one voice

Reviewer: UX/UI designer pass. Date: 2026-10-01. Branch `wp-ux-modals` (from `main` at ea81a02, merged with 1206b6d).

This pass covers every popup, modal, toast and card in the game. It has three goals:
- they all look good;
- they use icons and text well;
- they share one visual style and one voice.

Out of scope: the Run Setup / New Run window and the Developer menu, which are being redesigned separately. They are not edited here.

Shared factories changed (all small, additive):
- `UiTheme.tile_box` with the `tile` and `tile_accent` pieces;
- `UiModal` plaque constants, `subsection_label` and a shrink floor;
- `Toast.type_icon`;
- the `OptionCard` icon size and tint;
- `UiTheme.plaque_box`;
- the hover-keycap minimum size.

They are listed under "Kit changes".

## Method

- **Inventory:** `tools/scenarios.gd` and every provider. Two missing scenarios were added:
  - `ui_pause --confirm=1`: the abandon confirm;
  - `game_event --event=ore --biome=mines`: the Deep Mines ore vein.

  The update banner uses main's `update_banner` / `update_banner_ready` scenarios.
- **Shots:** each scenario was shot with `tools/shoot_matrix.sh <scenario> <dir> quick --wait=10 --audit` on five devices: 1080p, 1366x768, iPhone 17, Duo outer and iPad Pro 13 landscape. The densest six were also shot on the `zoom` set: shop pick, Settings, AUTO settings, results, Armory picker, pause loadout, plus the draft.
  - The audit wrapper also prints `AUDIT_TEXT` (text under 16 canvas px) and `AUDIT_TAP` (taps under 80 px), not just the overflow, safe-area and clip lines.
  - Every PNG was reviewed one by one.
- **Before/after:** before is `main` at ea81a02; after is this branch. Files are in `…/scratchpad/modal/{before,after}/<modal>/<scenario>__<device>.png`. The scenarios that are new on this branch were shot "before" from a scratch worktree of ea81a02 plus the scenario files only.
- **Severity:**
  - blocker: breaks a flow or hides essential information;
  - major: players notice it and get confused;
  - minor: a visible inconsistency;
  - polish: nice to have.

## Conventions (settled before fixing)

### Plaque colour legend
A plaque's colour has a meaning. It never carries an identity: identity lives in medallions, rims and icons.

| Plaque | Meaning | Used by |
|---|---|---|
| **yellow** (`PLAQUE_DEFAULT`) | every modal by default: places, tools, choices, rewards, settings, pause | Shop, Forge, Face Raise, events, Last Camp, rune choice, passive trophies, minigame prizes, rune assign, Your Dice, Paused, Settings, AUTO Settings, Your Route, Welcome, all Camp stations |
| **purple** (`PLAQUE_LEVEL`) | the hero levels up | LEVEL UP! only |
| **green** (`PLAQUE_WIN`) | a won run | VICTORY! only |
| **red** (`PLAQUE_DANGER`) | a lost run or a destructive confirm | DEFEATED, ABANDON RUN? |

There are no tinted (white × colour) plaques and no blue or pink ones. `tests/test_modal_conventions.gd` checks that every `set_title` in a modal file uses a `PLAQUE_*` constant.

### Surfaces: tiles never look like buttons (user rule)
1. **Only buttons carry the 3D lip:** TAKE, BUY, CRAFT, EQUIP, RESUME, and the round icon buttons.
2. **Tiles and cards are flat.** `UiTheme.tile_box(state, accent)`, with the pieces `tile` and `tile_accent`, uses `Containers/Flat`: no lip, no bottom shadow.
   - The rim is the flat art in the rim colour, laid under the face art inset by 2–3 px, so it follows the rounded corners.
   - States: `normal`, `hover`, `selected`, `worn`, `on`, `craftable`, `owned`, `locked`, `dim`.
3. **Selectable tiles** (draft, shop, reward and event options, Armory, Wardrobe, Arcade and loadout tiles):
   - hover lightens the face and rim;
   - selected shows the yellow rim;
   - the cursor is the pointer.

   Their call to action stays a real button: the price button, TAKE.
4. **Informational tiles** (results rows, the rune card, route boss chips, Workshop packs, pet cards) have no hover.
5. Modal frame: the Nailed wood. Insets and wells: the flat INK inset. Chips: flat round pills.

### Spacing scale (user: "more padding between sections")
These are `UiModal` constants, in logical px on the 1280-tall canvas. `spacing_k()` scales them down to 0.6 on short canvases (landscape phones, small windows), so extra air never forces a scroll.

| Constant | px | Where |
|---|---|---|
| `GAP_SECTION` | 36 | between sections. Every `section_label` carries `GAP_SECTION - GAP_ITEM` above itself; `section_gap()` separates header-less sections |
| `GAP_ITEM` | 18 | between items in a section (the body's separation) |
| `GAP_HEAD` | 12 | header to content inside composite headers |
| `GAP_TOP` | 30 | under the plaque, above the first section |
| `GAP_ACTIONS` | 36 | above the bottom action row: `action_gap()` before TAKE, BUY, FORGE, BIND RUNE, BEGIN, RESUME, LET'S GO, RESET |

### Button verb glossary
All button labels are UPPERCASE Lilita. The first word must be one of these (checked by a test).

| Verb | Meaning | Kind | Icon |
|---|---|---|---|
| TAKE | accept a free reward (draft, passive, prize, rune choice) | SUCCESS | check |
| BIND RUNE | apply a free rune to a die | SUCCESS | check |
| BUY · CRAFT · UNLOCK · RANK UP · LEVEL UP · RESTOCK | spend currency: `VERB  N` with the currency icon | PRIMARY (grey when unaffordable) | coin / crown / sigil |
| FORGE | apply the forge edit | PRIMARY | anvil |
| RAISE +1 · MIRROR | pick the forge operation (toggle pair) | toggles | up / mirror |
| EQUIP · SWAP IN | put an owned thing in the loadout | PRIMARY | none |
| REMOVE | take it out again (next to the purple EQUIPPED chip) | GHOST | none |
| BEGIN · LET'S GO · RESUME · KEEP PLAYING · TO CAMP | move on | PRIMARY (KEEP PLAYING: SECONDARY) | arrow_right (TO CAMP: campfire) |
| ABANDON RUN · ABANDON | destructive | DANGER | flag |
| SETTINGS · CONTROLS · AUTO SETTINGS | open a sub-screen | SECONDARY | gear / keyboard key / auto |
| RESET TO DEFAULTS | reset a sub-screen | GHOST | reroll |
| RESTART · DOWNLOAD · UPDATE · CHECK | update banner and Settings | PRIMARY / SECONDARY | download |

Banned: DONE, CLOSE, OK, GET, CLAIM, LEAVE, SKIP. Leaving is the header × with a tooltip that names the consequence ("Leave shop", "Skip the forge").

The decline choice of every event is the card **"Walk away"** with an arrow. It used to read "Leave", "Decline" or "Walk away" depending on the event.

### Casing and copy
- **Plaque titles:** UPPERCASE, 1–3 words. "!" is used only for celebration: LEVEL UP!, TREASURE!, VICTORY!. A confirm plaque asks the question: ABANDON RUN?.
- **Section headers** (`UiModal.section_label`): UPPERCASE, gold, 20 px, centred, with no "!" and no colon. Numbered steps are allowed: "1 · CHOOSE A DIE".
- **Group headers inside a section** (`UiModal.subsection_label`): UPPERCASE, muted, 18 px, left-aligned. Example: the Controls list's RUN / COMBAT.
- **Card titles:** Title Case for things (Odd Die, Blade Rune). Sentence case for actions (Offer blood, Walk away).
- **Body and prompts:** sentence case. A prompt is a short phrase with no full stop ("Choose one upgrade"). A sentence ends with a full stop.
- **Tags and chips:** UPPERCASE, ≥16 px. Use words, not jargon: CROWNS, not META; ATTACK, not ATK.
- Never repeat the plaque in the body. Example: the die inspector used to show "GIANT DIE" on the plaque and "Giant Die" in the header.

### Numbers and prices
- A price is the currency icon followed by a bare number, in a button or price face: `[coin] 50`, `BUY [crown] 120`. It is never spelled out ("10 gold") in a button. Prose may say "10 gold".
- Counters are `N/M` with no spaces: Lap 2/15, RANK 4/8, 24/45 Saber, 3/6 off. The exception is values drawn on bars (HP `60 / 60`).
- Deltas are signed: +22, -10. Percentages use %: 35%. Multipliers use ×. Thousands take a comma: 1,250.
- Use "Die 3 of 4" for a pager.

### Icons
1. Every choice card has an icon. Passive, rune and die choices use their own icon and tag (`set_passive`, `set_rune`, `set_die`) in every modal, including shrine events.
2. **Choice icons are compact.** 60 px, top-aligned with the title, never filling the card height (user rule). The text gets the width.
3. Every toast leads with an icon. With none given, the toast type picks one: danger = warning, heal = heart, reward = star, info = info.
4. A Flat White action glyph on navy (arrow, check, info) is drawn in TEXT, never in its default button-ink.
5. One icon, one meaning:

   | Concept | Icon |
   |---|---|
   | boss | horned skull (`boss`) |
   | crowns (currency) | crown |
   | sigils | purple gem |
   | gold amounts and prices | `coin` |
   | the HUD/shop wallet | coin stack (`3d:coins`) |
   | passive reward | trophy |
   | settings | gear |
   | update | bell / download |
   | controls | keyboard key |
   | move on | arrow_right |
   | confirm | check |

6. No emoji or unicode glyphs as icons. "×" stays as typography in multipliers.
7. Station medallions are captioned (Welcome).

### One exit
This follows the spec 3.2 inventory exactly. The changes are:
- Results lost its round Home: TO CAMP is the only exit, and the Camp has its own Home.
- The update banner's × is the red round close, like every modal.

`tests/test_modal_conventions.gd::test_dismiss_modes_match_the_inventory` checks the modes:
- **dismissible** (header ×, Esc, backdrop): Settings, AUTO Settings, Die inspector, Shop (= leave), Forge (= skip), Armory, Wardrobe, Pet Den, Workshop, Arcade;
- **forced:** Draft, Passive, Event (and the Last Camp), Rune assign, Route card, Minigame prize, Results, Welcome;
- **Pause:** RESUME, Esc = RESUME;
- **Abandon confirm:** KEEP PLAYING (normal width, Esc) + ABANDON.

### Sizes
- Text is ≥16 px on the canvas. Tap targets are ≥80 px (44 pt).
- A modal may shrink to fit only while it stays above both floors (`UiModal._shrink_floor`). Past that it scrolls, or lays out at the real width, at full size.

## Findings

| # | Sev | Modal(s) | Finding | Fix |
|---|---|---|---|---|
| 1 | blocker | Forge, Face Raise, die inspector (standard dice), silver minigame prize | The plaque was invisible. A steel or silver colour resolved to `plaque_grey`, which has no art, so only the title text floated over the frame. | `plaque_box` falls back to the white plaque × colour; all modal plaques now use the legend (yellow). |
| 2 | major | All modal tiles | Tiles used the 3D container with a lip and shadow, so they looked like buttons (user rule). | Flat `tile_box` everywhere in modals; hover only on selectable tiles. |
| 3 | major | All choice popups | The 96 px icon filled the card's height, so cards were tall and the shop scrolled on phones (user). | 60 px icon, top-aligned; the shop fits an iPhone. |
| 4 | major | Events (shrine, all "walk away" choices) | Shrine passives and every decline showed an ink arrow, nearly invisible on navy, instead of the passive's icon and rarity. | `set_passive` / `set_die` for passive and dice offers; action glyphs in TEXT; one decline label and icon. |
| 5 | major | Plaques | Plaque colour meant nothing: events were purple like LEVEL UP, AUTO was blue, Workshop blue, Arcade pink, Wardrobe purple, passives green or orange, prizes and dice tinted. | The legend (yellow / purple / green / red). |
| 6 | major | Shop (pick), all modals at 1366x768 and 125% zoom | Shrink-to-fit pushed tags to 13.6 px, rune names to 15.3 px, and BUY / RESTOCK / × to 69–77 px. | The shrink floor; the narrow layout instead of shrinking. |
| 7 | major | AUTO settings | "A boss passive is offe…" was truncated at 1080p. Rows were 54 px, chips 60 px, segments 76 px. | Shorter copy ("Boss passive offered"); 80 px rows, chips and segments. |
| 8 | major | Results | Two exits to two places: TO CAMP and a round Home to the title (user). | Home removed. |
| 9 | major | Modal frame (phones) | At 0.75 scale the Nailed wood read as a thin rust-red line (tech lead). | Frame scale 1.0 on phones too (spec 3). |
| 10 | minor | Pet Den, Arcade | "EQUIPPED" was a green disabled-looking button that actually unequipped. The Armory and Wardrobe use a purple chip. | Purple EQUIPPED chip plus a ghost REMOVE. |
| 11 | minor | Settings | Segmented rows were 76 px (under the tap floor). Auto-update used the gear (= Settings). The Controls group headers looked like section headers. | 80 px; `download`; `subsection_label`. |
| 12 | minor | Toasts | Errors and info ("Not enough Crowns", "No saved run", "Not now", "Diagnostics copied") had no icon. | `Toast.type_icon` default. |
| 13 | minor | Armory | The first buy of a rank group said FORGE (the run Forge's verb). Sigil price buttons had no verb ("[sigil] 2"). | UNLOCK; BUY / CRAFT on both currencies. |
| 14 | minor | Pet Den | LEVEL 6 (a number, not a verb). The MAX LEVEL chip used the crown (= currency). | LEVEL UP; star. |
| 15 | minor | Shop | RESTOCK showed its price as a sub-line "10 gold", unlike BUY [coin] 50. | `RESTOCK [coin] 10`. |
| 16 | minor | Pause, abandon confirm | ABANDON? plaque + "Abandon this run?" heading (said twice). CONTROLS had no icon while its neighbours did. The info line wrapped "Level 3" alone. | ABANDON RUN? plaque with the consequence as body; keyboard-key glyph; segments wrap only at the dots. |
| 17 | minor | Die inspector | "GIANT DIE" plaque + "Giant Die" header + "3 / 4". | YOUR DICE plaque, "Die 3 of 4" pager, the kind in the header. |
| 18 | minor | AUTO settings | Final boss used the crown (= currency); boss passive used a star; Drafts used a star; title "AUTO" (the button says AUTO SETTINGS); "Reset to defaults" in sentence case. | boss / trophy / level icons; AUTO SETTINGS; RESET TO DEFAULTS. |
| 19 | minor | Rune assign | BIND RUNE was PRIMARY, while the other "accept a free reward" action, TAKE, is SUCCESS. | SUCCESS. |
| 20 | minor | Minigame prize | Tags META / ATK / BOOST were jargon. | CROWNS / ATTACK / REROLLS. |
| 21 | minor | Results | Item mastery lines at 15 px; "UNLOCKED!" and "NEW SKINS!" section headers. | 16 px, N/M; no "!". |
| 22 | minor | Pause loadout | Tier numerals 14 px. | 16 px. |
| 23 | minor | Card rims | Rarity, accent and selected rims were square Thin frames on rounded cards (tech lead). | Rims are the card art underlaid in the rim colour (rounded); on flat tiles the same technique. |
| 24 | minor | Boss-tier cards | The Ornate overlay at 0.45 stretched its straight edges into thick orange bars (tech lead). | 0.3. |
| 25 | minor | Hover keycaps | At 1366x768 a 26 px cap was ~15 real px, and "ENTER" was unreadable (tech lead). | Never under 22 real px; multi-letter labels 0.38 of the cap. |
| 26 | polish | Medallions | The round disc read as an egg because of its lip (tech lead). | 60/64 width. |
| 27 | polish | Welcome | Station medallions had no captions. | Captioned. |
| 28 | polish | Arcade | "SKILL : LUCK 20:80". | "SKILL 20% · LUCK 80%". |
| 29 | polish | Update banner | Gear icon, grey 56 px close, 64 px action. | Bell, red round close, 80 px DOWNLOAD / RESTART with an icon. |
| 30 | polish | Missing-assets screen | The README link was a 24 px tap row. | 80 px row (the screen stays pack-free). |
| 31 | polish | HUD under modals (Last Camp, ore) | The twist chip made the whole top row shrink: WANING 15.1 px, pause 66 px. | The chip drops its word, then the lap pips, before the row shrinks (both stay in tooltips). |
| 32 | major | All modals | Sections were packed tight: 18 px everywhere, with the action row 20 px under the cards (user). | The spacing scale. |
| 33 | major | Shop pick, pause, AUTO settings, results at 125% UI size on phones | Content wider than the 576 px canvas made the panel shrink to 0.85–0.93, putting tags at 13.6 px and taps at 68 px. | Title/tag and die faces flow; slimmer segment pills; compact route columns 120 px; the fit snaps near 1. |
| 35 | major | All modals on canvases narrower than 620 px | The panel was shrunk to fit instead of reflowing (option cards, die-chip grids, long detail lines). | Lay out at the real width: `grid_columns()`, flowing card titles and faces, `wrap_wide_labels()`. |
| 34 | minor | Camp bottom panel (max profile, Ascension 10, 125%) | The loadout row pushed past the safe area: 6 AUDIT_SAFE (tech lead). | The name trims and the mode line wraps. |

Every finding is fixed.

## Per-modal checklist (after)
Columns:
- **V:** visual consistency (plaque, frame, tiles, buttons, spacing, headers, chips)
- **I:** iconography
- **T:** text
- **X:** one exit
- **C:** containment
- **P:** phone hierarchy and readability

✓ = passes the conventions above. Numbers refer to the findings fixed.

| Modal | Scenario | V | I | T | X | C | P | Fixed |
|---|---|---|---|---|---|---|---|---|
| Draft / level up | `ui_draft`, `game_draft` | ✓ | ✓ | ✓ | forced, TAKE | ✓ | ✓ | 2, 3 |
| Rune choice (chest) | `ui_rune_choice` | ✓ | ✓ | ✓ | forced, TAKE | ✓ | ✓ | 2, 3, 5 |
| Passive reward | `game_passive` | ✓ | ✓ | ✓ | forced, TAKE | ✓ | ✓ | 2, 3, 5, 24 |
| Shop / die pick | `ui_shop`, `ui_shop_pick`, `game_shop` | ✓ | ✓ | ✓ | × = leave | ✓ | ✓ | 2, 3, 6, 15 |
| Forge / Face Raise | `ui_forge` | ✓ | ✓ | ✓ | × = skip | ✓ | ✓ | 1, 2 |
| Events (shrine, duel, idol, merchant, garden, outbreak, dicesmith) | `ui_event*`, `game_event --event=*` | ✓ | ✓ | ✓ | forced | ✓ | ✓ | 3, 4, 5 |
| Ore vein | `game_event --event=ore --biome=mines` | ✓ | ✓ | ✓ | forced | ✓ | ✓ | 4, 5, 31 |
| The Last Camp | `game_last_camp` | ✓ | ✓ | ✓ | forced | ✓ | ✓ | 2, 3, 31 |
| Rune assign | `ui_rune_assign` | ✓ | ✓ | ✓ | forced, BIND RUNE | ✓ | ✓ | 2, 19 |
| Potion tooltip | `hud_potions --tip=0` | ✓ | ✓ | ✓ | n/a | ✓ | ✓ | – |
| Die inspector | `game_die_inspect` | ✓ | ✓ | ✓ | × | ✓ | ✓ | 1, 17 |
| Pause | `ui_pause`, `game_pause`, `ui_pause_loadout` | ✓ | ✓ | ✓ | RESUME | ✓ | ✓ | 16, 22 |
| Abandon confirm | `ui_pause --confirm=1` | ✓ | ✓ | ✓ | KEEP PLAYING + ABANDON | ✓ | ✓ | 16 |
| Settings (+ Controls) | `ui_settings` | ✓ | ✓ | ✓ | × | ✓ | ✓ | 11 |
| AUTO settings | `ui_auto_settings` | ✓ | ✓ | ✓ | × (back) | ✓ | ✓ | 5, 7, 18 |
| Results (win, loss, items, skins, secret hero) | `ui_victory`, `ui_defeat`, `ui_results_*`, `ui_mk_reveal` | ✓ | ✓ | ✓ | TO CAMP only | ✓ | ✓ | 2, 8, 21, 32, 33 |
| Minigame prize | `mg_fossil --state=reward` | ✓ | ✓ | ✓ | forced, TAKE | ✓ | ✓ | 1, 3, 20 |
| Route card | `route_card` | ✓ | ✓ | ✓ | BEGIN | ✓ | ✓ | 2 |
| Armory (picker, craft, rank-up, looks) | `ui_armory*` | ✓ | ✓ | ✓ | × | ✓ | ✓ | 2, 5, 13 |
| Wardrobe | `ui_wardrobe` | ✓ | ✓ | ✓ | × | ✓ | ✓ | 2, 5 |
| Pet Den | `ui_petden` | ✓ | ✓ | ✓ | × | ✓ | ✓ | 2, 10, 14 |
| Dice Workshop | `ui_workshop` | ✓ | ✓ | ✓ | × | ✓ | ✓ | 2, 5 |
| Arcade | `ui_arcade` | ✓ | ✓ | ✓ | × | ✓ | ✓ | 2, 5, 10, 28 |
| Welcome | `camp_first` | ✓ | ✓ | ✓ | forced, LET'S GO | ✓ | ✓ | 27 |
| Update banner | `update_banner`, `update_banner_ready` | ✓ | ✓ | ✓ | red × | ✓ | ✓ | 29 |
| Missing assets | `asset_missing` | exempt (pack-free) | ✓ | ✓ | n/a | ✓ | ✓ | 30 |
| Affix / encounter card, affix tooltip | `elite_affix_card`, `elite_affixed --tip=0:0` | ✓ | ✓ | ✓ | tap | ✓ | ✓ | – |
| Toasts | `camp_toasts`, `camp_toasts --toast=error`, `level_up_auto` | ✓ | ✓ | ✓ | n/a | ✓ | ✓ | 12 |
| Portal banner | `ui_portal` | ✓ | ✓ | ✓ | n/a | ✓ | ✓ | – |

## Kit changes (shared factories)
- **`ui_pack.json`:**
  - new `tile` and `tile_accent` pieces;
  - `panel_card` / `card_accent` rims underlaid, so they are rounded;
  - `panel_main` frame scale 1.0;
  - `frame_ornate` scale 0.3.
- **`UiTheme`:**
  - `tile_box(state, accent)` (new);
  - `plaque_box` white fallback.
- **`UiModal`:**
  - `PLAQUE_*` legend constants;
  - `subsection_label`;
  - `_shrink_floor` (text 16 / tap 80) used by the height and width fits.
- **`OptionCard`:**
  - `ICON_PX` 60, top-aligned;
  - action glyphs default to TEXT;
  - tiles via `tile_box`;
  - Medallion 60/64 width.
- **`CampUi`:** `card`, `locked_card` and `Tile` are flat tiles (`Tile` gains hover).
- **`RunSetupModal.surface()`:** now a single line on `UiTheme.tile_box` (tech lead request), so the New Run window shares the tile.
- **`UiModal` spacing:** `GAP_*` constants, `spacing_k()`, `action_gap()`, `section_gap()`.
- **`OptionCard`:** title/tag and the die faces are flow containers (they wrap on narrow cards).
- **`Toast`:** `type_icon(rim)` default icon.
- **`GameButton`:** `KEYCAP_MIN_SCREEN` 22. **`KeyGlyph`:** multi-letter label 0.38.
- **`icon_map.json`:** `controls` (Technology / Keyboard Key Flat White, new SVG; bundles re-packed, lock updated).

## Audit
Results after the pass:
- **Quick set** (55 scenarios × 5 devices): zero `AUDIT_OVERFLOW`, `AUDIT_SAFE`, `AUDIT_CLIP`, `AUDIT_TEXT` and `AUDIT_TAP` findings.
- **Zoom set** (0.8–1.5 UI zoom, 6 devices) for shop pick, Settings, AUTO settings, results, Armory picker, pause loadout, draft and the max-profile Workshop at Ascension 10: zero findings.

Before the pass:
- shop pick: 40 findings
- AUTO settings: 74
- Settings: 35
- pause loadout: 25
- results: 16
- Last Camp HUD: 2
- missing assets: 5

Tests:
- `tests/run.sh`: 792 passed, 0 failed, including `tests/test_modal_conventions.gd`.
- `ui/check_scripts.gd`: UI_SCRIPTS_OK.
- `assets.py verify`: all units match the lock.
