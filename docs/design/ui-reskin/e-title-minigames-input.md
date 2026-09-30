# UI reskin, area (e): title, class select, run setup, boot, minigames, input hints

Status: **plan** (area planner e, 2026-09-30). This document contains no code changes.
It aligns with the lead's draft `docs/design/2026-09-30-ui-reskin.md` (branch `wp-ui-design`, commit `ef8b01f`, "Night navy + wood", option D). It also aligns with the foundation WIP on `wp-ui-foundation`: `Icons` registry (`ui/icons/icon_registry.gd`), `UiSkin` (`ui/theme/ui_skin.gd`, manifest `ui/theme/ui_pack.json`) and `UiSvg` (`ui/theme/ui_svg.gd`, DPITexture, `recolor`, `compose`).

Items marked **[LEAD]** are proposals that need a decision from the lead designer.

Icon and pack paths are relative to `third_party/`, as in `icon_map.json`. The prefixes are abbreviated in tables:

| Short | Full |
|---|---|
| `VIP/` | `rhosgfx/vector-icon-pack-pro/` |
| `KBD/` | `rhosgfx/vector-keyboard-controls/` |
| `UIP/` | `rhosgfx/cartoony-ui-pack-full/` |
| `EMO/` | `rhosgfx/vector-emojis/SVG/` |
| `HAT/` | `rhosgfx/vector-hats/` |

Per the lead's rule, icons default to the `<Name> Outline.svg` full-colour variant. Every path listed below was checked against the pack.

---

## 0. Key findings (read first)

1. **Keyboard glyphs: 130 of the 152 "Outline" and "No Outline" key SVGs render blank in Godot.**
   - These keys draw their label as an SVG `<text>` element in the ARCO Typography font. Godot's ThorVG rasteriser (both `Image.load_svg_from_string` and `DPITexture`) drops `<text>`.
   - I verified this with Godot 4.7.2 headless: `r.svg`, `escape.svg` and `space_md.svg` come out as empty keycaps. Only the 22 icon keys (`arrow-*`, `enter-icon_*`, `shift-icon_*`, `tab-icon`, `backspace`, `home-icon`, `blank_*`, ...) render correctly.
   - The **White** and **Black** sets (152 each, files named `<key>_white.svg` / `<key>_black.svg`) are pure paths. Their label is knocked out of a single-colour cap, so they render fine and can be tinted through `UiSvg.recolor`, which already handles the short `#fff` form.
   - No other RhosGFX pack uses `<text>`. I grepped the icon, emoji, hat and UI packs: 0 hits.
   - Proof image: `scratchpad/ui-plan/e/svgtest/godot_raster.png`.
   - **Proposal:** a `KeyGlyph` widget that takes the key's own Outline SVG, strips its `<text>`, and draws the label itself in the game display font (details in §3.3). See the mockup `scratchpad/ui-plan/e/mock_key_hint.png`.
2. **There is no InputMap.** `project.godot` has no `[input]` section. Every shortcut is a hard-coded `KEY_*` in `game/game_controller.gd:643-681`, and it only applies in run mode.
   - **No minigame accepts keyboard input.** All 11 boards use `_gui_input` with a left mouse button. Touch only reaches them through the emulated mouse.
   - The title screen, class select, run setup, modals and Camp have no keys at all.
3. **The title "before" shots need `--wait` ≥ 6 when other agents are shooting in parallel.**
   - With `--wait=2`, the PLAY / CONTINUE / SETTINGS column was still at `modulate.a = 0`, because the 0.2 s delayed fade had not run yet on a loaded machine. The minigames need `--wait=9`, since the landing beat and intro run first.
   - This is a harness timing issue, not a game bug. It still matters for everyone's after-shots.
4. **The missing-assets screen must stay pack-free.**
   - The foundation copies pack SVGs to the git-ignored `res://assets/ui/{icons,pack}/`. If the RhosGFX units join `tools/ci/assets.lock.json`, then a missing pack is exactly the case where this screen shows.
   - It already builds itself from engine built-ins plus one tracked PNG. The plan keeps it that way and adds a small **tracked** SVG set (§1.3, §5 step 6).
5. **The current minigame icon stand-ins are weak, and the pack has a real icon for every game.**
   - `CampInfo.MINIGAME_ICON` uses stand-ins such as fishing → `snowflake`, plinko → `dice`, memory → `mirror`, high-low → `up`.
   - `MgLogic.ICONS` (shovel, bubble, ticket, claw, peg, cup, card, rod, wheel, ladder) is defined but never used.
   - The pack has a matching icon for all 11 games, including a prize wheel (`General/Spinner`). See §2.4.

---

## 1. Inventory

Screenshot dir: `/private/tmp/claude-501/-Users-vlad-Repos-diceroll/1bba73af-2ee7-40a8-8c95-50839b8aed16/scratchpad/ui-plan/e/before/<group>/<scenario>__<device>.png`.

### 1.1 Title screen

**Files**
- `ui/screens/title_screen.gd`
- `ui/widgets/logo.gd`: DICEROLL wordmark. Display font, ink outline 26, bronze rim 12, gradient fill shader, long drop shadow.
- `ui/widgets/dev_gesture.gd`
- `ui/widgets/game_button.gd`: self-drawn 3D-lip button.
- `ui/widgets/die_face.gd`: the two tumbling dice above the logo.

**Current styles**

| Element | Current style |
|---|---|
| PLAY | `GameButton.PRIMARY`, 46 px font, `min_height` 116, icon `campfire` tinted `TEXT_DARK` |
| CONTINUE | `SECONDARY`, 36 px, `min_height` 100, icon `arrow_right` in GOLD, sub text "no saved run" when disabled |
| SETTINGS | `GHOST`, 32 px, icon `gear` |
| Button column | 460 px wide, at y = 56% (portrait) or 52% (landscape) |
| Tag line | "A  DICE  ROGUELITE", 28 px |
| Footer | credits line, 18 px `TEXT_MUTED`. It needs "RhosGFX (CC0 / licensed)" added **[LEAD: credits wording]** |
| Vignette | `_Vignette` gradient over the 3D board backdrop |

**Icon ids:** `campfire`, `arrow_right`, `gear`.

**Dev gesture:** 5 taps inside an 80×80 bottom-right square, within the safe area and a 3 s window. It is invisible, listens in `_input`, and never blocks. It sits under the footer's right end.

**Scenarios:** `ui_title` (`ui/scenarios.gd`) and `camp_*` (`game/camp/scenarios.gd`), which use the title as step 0. The before set is `before/title/ui_title__*` on the full matrix (26 devices, `--wait=7`).

### 1.2 Class select and run setup

**Files**
- `ui/screens/class_select.gd`: 11 chips in a 4-column grid, header, back button, `HeroPortrait`, info scroll, START RUN.
- `ui/camp/run_setup_modal.gd`: NEW RUN modal. Hero card, kit card with ARMORY button, 2-column `ClassCard` grid, mode tiles, ascension ◀ ▶ stepper, loadout rows with CHANGE buttons, START RUN.
- `ui/widgets/class_card.gd`: open / selected / locked / secret states, medallion, check mark, lock text.
- `ui/widgets/class_detail.gd`: mechanic badge, stats row (4 chips), dice rows.
- `ui/widgets/class_info.gd`: taglines, `MECH_COLOR`.
- `ui/widgets/kit_strip.gd`: 3D item thumbs with tier bands in `TIER_COLORS`.
- `ui/widgets/secret_reveal.gd`: Monster Kid "???" card, rattle, BOO!, hero reveal. It appears on the results screen.
- `ui/camp/camp_ui.gd`: `locked_card`, `lock_line`, `tile`, `amount`.
- `ui/widgets/option_card.gd`: `Medallion`.

**Current styles**
- Chips are `GameButton.SECONDARY` toggle buttons that turn PRIMARY when pressed: 18 px text, 30 px class icon, `min_height` 76, `pad_x` 6.
- Mechanic badge: `UiTheme.box`, mechanic colour darkened 0.8, border at 0.65 alpha, radius 18.
- Stat chips: `NAVY_2` box, radius 16. Captions are 16 px dim (UX-pass item 16).
- Kit tier colours: grey, silver, blue, gold.
- Secret card: `CampUi.locked_card` plus a hint in `#c9b6ea`. Secret name is "???" in `TEXT_MUTED`.
- BOO! is 96 px `#9cf05a`. The kicker is "A SECRET STIRS…" in `#c79bff`.

**Icon ids**

| Group | Ids |
|---|---|
| Class icons | `class_druid`, `class_engineer`, `class_monster_kid`, `class_necromancer`, `class_ninja`, `class_paladin`, `class_ranger` |
| Class fallbacks | knight → `shield`, barbarian → `axe`, mage → `staff`, rogue → `dagger` |
| Mechanic icons | `mech_oath`, `mech_aim`, `mech_shadow_step`, `mech_overgrowth`, `mech_bone_harvest`, `mech_turret`, `mech_boo` |
| Rune icons (classes with no mechanic) | `rune_*` |
| Stats | `heart`, `sword`, `reroll`, `dice` |
| Other | `question` (secret chip), `check`, `arrow_left`, `arrow_right`, `anvil` (ARMORY), `flag` / `speed` (mode tiles), `CampInfo.MINIGAME_ICON` values (loadout) |

**Scenarios (before shots)**

| Scenario | What it shows | Before shots |
|---|---|---|
| `ui_class_select` | knight, no profile | `before/class_select/` |
| `ui_class_select --profile=mid --class=monster_kid` | the "???" chip and card | `before/class_select_mid/` |
| `ui_mk_mystery` | run setup, mid profile, "???" card | `before/mk_mystery/` |
| `ui_mk_reveal --frames=N` | the reveal (results screen) | shared with area (c)/(d) results; I did not shoot it |
| `ui_class` | older ClassSelect scenario | — |
| `ui_wardrobe --class=…` | reuses ClassDetail | — |

### 1.3 Missing-assets boot screen

**Files:** `game/boot/missing_assets_screen.gd`, `game/boot/asset_check.gd`. Scenario `asset_missing` (`game/boot/scenarios.gd`).

**Current build**
- Engine built-ins only: `ThemeDB.fallback_font` plus `FontVariation` embolden, a system mono font, `GradientTexture2D`, and `StyleBoxFlat` buttons (radius 16, 5 px bottom lip).
- Lockup: tracked `res://assets/icon/logo_doubles.png`, with a drawn gold die as fallback, next to "DICE" in gold and "ROLL" in red.
- Card with eyebrow, title, body `RichTextLabel` (shell commands), "Read the build guide" (primary), Quit, and the README link.
- Hosts `DevGesture`.
- There are no icons today. UX-pass item 17 notes that Quit / Readme are 64 px, below the 80 px touch target.

**Before shots:** `before/asset_missing/` (quick set).

### 1.4 Minigames

**Shared frame: `ui/minigames/minigame_screen.gd`**
- Background: full-screen scrim `(0.02, 0.02, 0.07, 0.86)` plus a pulsing glow in `MgLogic.GAME_COLORS[id]`.
- Title: `Ribbon.make("", 42, GOLD)`, tinted with the game colour.
- **Instruction line:** `_hint = UiTheme.para("", 22, TEXT_DIM, 600)`, at most 640 px wide. It gets no emphasis and sits right against the ribbon and the pills.
- Stats pills: `UiTheme.panel("pill")` with a unit (20 px) and a number (34 px display). An extra status pill shows `board.status_text()` at 22 px `GOLD_BRIGHT`.
- `MgWidgets.ParMeter`: drawn bronze / silver / gold zones, 17 px labels.
- Buttons: DROP! only (claw), `GameButton` PRIMARY, 250×84. There is no exit, skip or AUTO button.
- Landscape: a side column scaled ×1.0–1.55.

**Result beat** (`minigame_screen.gd:296-387`)
- `panel("main")` card, at most 560 px wide.
- `MgWidgets.Medal` (drawn, 170×190).
- Tier title "GOLD!" / "SILVER" / "BRONZE" at 64 px.
- Score line at 28 px, a ParMeter, and `crown` icon with "+N Crowns".
- "Tap to continue" at 20 px `TEXT_MUTED`.

**Reward modal:** `ui/minigames/minigame_reward_modal.gd`
- UiModal titled "<TIER> PRIZE", with a 96×108 Medal.
- 2–3 `OptionCard`s. Icons: `coin`, `crown`, `potion`, `anvil`, `star`, `reroll`, `trophy`, `sword`, `heart`, `mirror`, `up`, or a die.
- TAKE button (`check`).

**Other shared files**
- `game/minigames/minigame_beats.gd`: tile landing, and the "+N Crown banked" toast with a `crown` icon.
- `ui/minigames/model_icons.gd`: prizes inside boards are **3D KayKit renders**, not vector icons.
- `ui/minigames/mg_board.gd`: all board chrome is drawn with `rrect()` / `box()`, cached inline `StyleBoxFlat` (`:225-245`).

**Per board**

All boards use `_gui_input` with `MOUSE_BUTTON_LEFT` (plus motion where noted), with no key input. Their chrome is drawn in `_draw`. Hint text comes from `MgLogic.HINTS`.

| # | Board file | Game id / scenario | Verb | Hint text (22 px) | Status / in-board text | Prize art (3D) |
|---|---|---|---|---|---|---|
| 1 | `fossil_board.gd` | fossil_hunter / `mg_fossil` | tap a mound | "Dig for 3 fossils and hidden treasure. Hit a bone? Dig beside it!" | "Fossils n / 3", "FOSSIL! +N", "BONE! +1", "Just dirt" | GEM_SMALL, COINS |
| 2 | `bubble_board.gd` | bubble_breaker / `mg_bubble` | press to highlight, release to pop | "Only 3 taps! Pop groups of 3+…" | "Chain xN", "Need 3+", "No more groups!" | none (vector bubbles) |
| 3 | `scratch_board.gd` | scratch_off / `mg_scratch` | press or drag to scratch | "Scratch 3 faces: win their pips…" | "LUCKY SIX", "SCRATCH", "PAIR!", "JACKPOT!!" | GEM_CHEST, GEM |
| 4 | `claw_board.gd` | claw_machine / `mg_claw` | tap anywhere or DROP! | "Tap to drop. Every capsule hides a prize…" | "CAPSULE CLAW", "PRIZE", "WON: -", "SLIPPED!" | 7 prize models |
| 5 | `shooter_board.gd` | bubble_shooter / `mg_bubble_shooter` | drag to aim, release to shoot | "Drag to aim, release to shoot…" | "DRAG TO AIM - RELEASE TO SHOOT", "RELEASE TO CANCEL", "NEXT", "SHOTS" | GEM_CHEST |
| 6 | `plinko_board.gd` | plinko / `mg_plinko` | hover or drag to aim, release to drop | "Pick a slot and drop…" | "PLINKO", bucket values, "x2" | coin, gem, bar models |
| 7 | `shell_board.gd` | shell_game / `mg_shell_game` | click a cup | "Watch the gem, follow the cups, tap its cup…" | "WATCH THE GEM!", "SHARP EYE x2", "Round n/3" | GEM |
| 8 | `memory_board.gd` | memory_match / `mg_memory_match` | click a card | "Flip two cards a turn…" | "n / 8 pairs", heart pips, "ALL PAIRS!" | GEM, star, skull |
| 9 | `fishing_board.gd` | fishing / `mg_fishing` | click a spot, click to strike | "Pick a spot and cast. Strike when the bobber plunges…" | "TAP A SPOT TO CAST", "STRIKE! TAP!", "SHALLOWS / REEDS / DEEP" | fish barrel, tacklebox |
| 10 | `wheel_board.gd` | lucky_wheel / `mg_lucky_wheel` | click anywhere: SPIN, then BRAKE | "Three spins! As it slows, tap BRAKE…" | drawn "SPIN!", "BRAKE!", "WAIT...", "SPIN n" slots | 9 money / gem models |
| 11 | `ladder_board.gd` | high_low / `mg_high_low` | click HIGHER / LOWER / CASH OUT | "Higher or lower? … Cash out before you bust!" | drawn HIGHER / LOWER with odds pills, "CASH OUT +N", "BUST!" | 9 rung models, pawn |

**Board-drawn verbs:** "TAP A SPOT TO CAST", "STRIKE! TAP!", "DRAG TO AIM - RELEASE TO SHOOT" and the "Tap" in the hints are touch words. Desktop players click.

**Scenarios:** `mg_<id>` with `--state=fresh|mid|result|reward|play|resume|anim`. Also `tile_minigames` (board tiles), `mg_play_auto` and `mg_icons` (ModelIcons sheet).

**Before shots**
- 11 × `before/mg/*` on iphone17_17pro, pc_1366x768 and iphone17_land, at `--wait=9`.
- `mg_claw --state=result` in `before/mg_result/` and `mg_claw --state=reward` in `before/mg_reward/`. At `--wait=12` and `--wait=14`, both still captured the game in play, not the result beat or the reward modal. Retake them with a longer wait, or with `--state=play` step shots (`<shot>_step_NN.png`).

**Visible issues in the before shots**
- UX-pass item 22 is confirmed: the hint is 22 px `TEXT_DIM` and wraps to 2 lines on phones.
- In iPhone landscape (`mg_fossil__iphone17_land`), the side column's hint renders at about 11 px physical and reads as noise.

### 1.5 Input (every shortcut in the game today)

| Where | Input | Effect | Source |
|---|---|---|---|
| Run (any phase) | Esc, P | pause menu | `game_controller.gd:661` |
| Run, BOARD_READY | Space, Enter | `roll_board` | `:667` |
| Run, BOARD_ROLLED | Space, Enter | `confirm_move` | `:667` |
| Run, COMBAT | Space, Enter | `combat_attack` | `:667` |
| Run, BOARD_ROLLED | R | `board_reroll` | `:674` |
| Run, COMBAT | R | `combat_reroll` | `:674` |
| Run, COMBAT | 1–6 | `combat_toggle` die N (mark for reroll) | `:679` |
| Run, PORTAL | left click on a tile | `portal_pick` | `_tap` |
| Run, COMBAT | left click on an enemy | `combat_set_target` | `_tap` |
| Camp | left click on a station | open station; during a reveal, skip it | `_camp_input` `:1021` |
| AUTO on | a click or touch on a game control | AUTO off (manual takeover) | `game/auto/auto_pilot.gd:282` |
| Title / any boot screen | 5 taps bottom-right | Developer menu | `ui/widgets/dev_gesture.gd` |
| Everything else | mouse / touch only | — | `_gui_input` in widgets, modals and minigames |

Notes:
- The keys are ignored while `busy`, while the pause menu is open, or while any modal is open. Esc / P still pauses.
- There are no gamepad handlers and no `InputEventJoypad*` anywhere.
- `project.godot` leaves `emulate_mouse_from_touch` at its default (on). Emulated clicks carry `device == InputEvent.DEVICE_ID_EMULATION`, which `DevGesture` already relies on.

---

## 2. Proposed mapping

The same icon id applies wherever it appears, so the lead's `icon_map.json` wins on shared ids (`heart`, `sword`, `coin`, …). The ids new to this area are marked **new**.

### 2.1 Title

| Element | Proposal |
|---|---|
| PLAY | Pack primary button, 3D Square 2.5 yellow (`UiSkin` piece `button_primary`). Icon `campfire` → `VIP/Items/Bonfire/Bonfire Outline.svg` in full colour. Drop the `TEXT_DARK` tint: the pack icon carries its own ink outline. |
| CONTINUE | `button_secondary` (blue). Icon `arrow_right` → `VIP/UI/Arrow/Arrow Right Outline.svg`. **[LEAD, from UX-pass item 21]** Hide CONTINUE entirely when there is no save, rather than showing a greyed button. The column then shrinks to PLAY and SETTINGS and the logo breathes. |
| SETTINGS | The GHOST kind has no pack equivalent. Use `button_secondary` at a smaller height, or a round icon button (`Buttons/3D/Round/…`) with `gear` → `VIP/General/Settings/Gear Outline.svg`. **[LEAD]** I prefer a full-width secondary button: on phones the title is the only place to reach Settings before a run. |
| Logo lockup | Keep `Logo` as is. The gold gradient with ink outline already matches the pack's thick-outline cartoon style, and the pack has no wordmark. Check: the yellow PLAY plate sits 0.56·h below the logo, so two warm golds stack. The logo's bronze rim `#7a3a10` plus its ink outline separate them. Verify in the after shots on `iphone17_land` and `duo_outer`, where the gap is smallest. If they merge, move PLAY to the blue primary **[LEAD]** or darken the logo's bottom gradient stop. |
| Tag line / footer | Unchanged fonts. Footer: add the RhosGFX credit. |
| Dev gesture | No visual. Keep the 80 px corner clear: the footer is centred, so it doesn't collide. No hint glyph ever (it's hidden). |
| Key hints (desktop) | PLAY: `Enter`. SETTINGS: none. Esc on the title does nothing, and nothing quits from the title on desktop. See §3.2. |

### 2.2 Class select and run setup

| Element | Proposal |
|---|---|
| Class chips | Pack **flat round pill** (`Buttons/Flat/Round/…-2.5`, the lead's "chips/pills") instead of 3D Square. The grid is 4×3 at ~85 px per chip on a 402 pt phone. A 3D lip (19 SVG units at the bottom) would cost about 8 px of an already tight 76 px chip. Unselected = blue-dark (or grey-darker for locked). Selected = yellow-regular. Locked = grey plus `lock` badge (`VIP/General/Lock/Lock Outline.svg`, 18 px) in the top-right corner instead of 0.7 alpha. |
| Class icons | See the table below. Full-colour Outline variants. Locked classes: `UiSvg.recolor(saturation=0)` via an `Icons` tint "desaturate" **[LEAD: add a `saturation` key to icon_map entries, like UiSkin has]**. |
| Secret chip / card | `question` → `VIP/UI/Question Mark/Question Mark Outline.svg`, purple-tinted frame (`Frames/Thin/7. Purple`). Secret hint card: `Containers/3D` purple-dark. |
| Mechanic badge | Pack `Containers/Flat/0. White`, modulated to the mechanic colour darkened 0.8 (keeps the colour coding), with a medallion that uses the mechanic icon (below). |
| Stats row | Chips = `Containers/Flat` navy. Icons: `heart` → `VIP/General/Heart/Heart Outline.svg`, `sword` → `VIP/Weapons/Sword/Sword Outline.svg`, `reroll` → `VIP/UI/Redo/Redo Outline.svg`, `dice` → `VIP/Items/Dice/Dice Outline.svg`. Rename the caption "MOVE REROLL" to "MOVE REROLLS" for consistency (copy nit). |
| Section labels "Kit" / "Starting dice" | `UiModal.section_label`. Use the global skin, nothing local. |
| Kit strip | 3D item thumbnails stay: they are renders, not icons. Tier band colours stay (they are data colours). The cell frame becomes `Frames/Inset` grey-darker at small size. |
| Dice rows | DieFace stays drawn. Dice are game pieces, not UI icons. |
| START RUN | `button_primary`, icon `arrow_right`. Desktop hint: `Enter`. |
| Back (class select) | Round 3D icon button, `arrow_left` → `VIP/UI/Arrow Back/Arrow Back Outline.svg` (the curved back arrow reads as "back" better than the plain arrow). Desktop hint: `Esc` badge. |
| Run setup: ARMORY, CHANGE, mode tiles, ascension ◀ ▶ | Secondary pack buttons. `anvil` → `VIP/Tools/Anvil/Anvil Outline.svg`. `flag` → `VIP/Items/Flag/Flag Outline.svg`. `speed` → `VIP/Player/Speed/Speed Outline.svg`. Ascension steppers: `Arrow Left/Right Outline`. Desktop hints on the steppers: `←` / `→` (`arrow-left.svg` / `arrow-right.svg`, which render natively). This is optional (§3.2). |
| Loadout minigame icons | Switch `CampInfo.MINIGAME_ICON` to the new `mg_*` ids (§2.4). |
| Monster Kid reveal (SecretReveal) | Keep the drawn BOO! comic burst. Optional emoji flavour: see §2.6. |

**Class and mechanic icon candidates** (other areas, e.g. the HUD class badge, use these too; the lead owns the final map):

| id | Candidate SVG | Alt |
|---|---|---|
| `class_knight` (now falls back to `shield`) | `VIP/Weapons/Shield/Shield Outline.svg` | `Shield Silver Outline` |
| `class_barbarian` (`axe`) | `VIP/Weapons/Battleaxe/Battleaxe Outline.svg` | `Weapons/Axe/…` |
| `class_paladin` | `VIP/Weapons/Warhammer/Warhammer Outline.svg` | `General/Halo/Halo Outline.svg` |
| `class_mage` (`staff`) | `VIP/Weapons/Wizard Staff/Wizard Staff Outline.svg` | `HAT/Wizard Hat/wizard-hat-purple-outline.svg` |
| `class_ranger` | `VIP/Weapons/Bow/Bow Outline.svg` | — |
| `class_rogue` (`dagger`) | `VIP/Weapons/Dagger/Dagger Outline.svg` | `Dagger 2` |
| `class_ninja` | `VIP/Weapons/Shuriken/Shuriken Outline.svg` | — |
| `class_druid` | `VIP/Nature/Leaf/Leaf Outline.svg` | `Nature/Sprout` |
| `class_engineer` | `VIP/Tools/Wrench/Wrench Outline.svg` | `Tools/Hammer` |
| `class_necromancer` | `VIP/General/Horned Skull/Horned Skull Black Outline.svg` | `Holiday/Tombstone/Tombstone Outline.svg` |
| `class_monster_kid` | `VIP/Holiday/Ghost/Ghost Green Outline.svg` (the BOO! green) | `Holiday/Treat Bag/Treat Bag Outline.svg` |
| `mech_oath` | `VIP/General/Halo/Halo Outline.svg` | — |
| `mech_aim` | `VIP/Weapons/Target/Target Outline.svg` | — |
| `mech_shadow_step` | `VIP/Player/Speed/Speed Outline.svg` | `Player/Run` |
| `mech_overgrowth` | `VIP/Nature/Sprout/Sprout Outline.svg` | — |
| `mech_bone_harvest` | `VIP/Items/Bone/Bone Outline.svg` | — |
| `mech_turret` | `VIP/Tools/Hammer/Hammer Outline.svg` | `Weapons/Target` |
| `mech_boo` | `VIP/Holiday/Ghost/Ghost Green Outline.svg` | — |
| `question` | `VIP/UI/Question Mark/Question Mark Outline.svg` | — |
| `lock` (**new**) | `VIP/General/Lock/Lock Outline.svg` | — |
| `check` | `VIP/UI/Check Mark/Check Mark Outline.svg` | — |

The mechanic colour coding (`ClassInfo.MECH_COLOR`) lives on the badge frame. Full-colour icons would clash with it, so the mechanic medallion may be the one place for `Flat White` plus a tint **[LEAD]**.

### 2.3 Missing-assets screen (built-in fallbacks)

Hard rule: this screen must render with **no** `res://assets/ui/**`, no fonts, no KayKit files, and no `third_party/`. Plan:

- **Keep** the `StyleBoxFlat` buttons and card, but restyle them to *echo* the pack so the boot screen doesn't look like a different game:
  - Primary: yellow `#fdaf18` face, `#fc9504` lip, `#f15a24` 4 px outline. These are the pack's yellow-regular colours, read from `button-square-3d-2.5-yellow-regular_standard.svg`.
  - Card: navy fill with a 6 px `#5a3a22` wood-brown border, echoing the lead's Nailed dark-brown frame.
  - These are constants in the file. They add no dependency.
- **Raise Quit and Readme to 80 px** (UX-pass item 17).
- **Icons:** add three tiny *tracked* SVGs under `game/boot/icons/`:
  - `book.svg` for "Read the build guide"
  - `door.svg` for Quit
  - `warning.svg` for the eyebrow
- **Source of those three SVGs:**
  - Option A: hand-simplified single-path glyphs drawn by us (tracked, CC0-clean). **Recommended.**
  - Option B: copies of `VIP/Items/Book`, `VIP/General/Door/Door Open`, `VIP/UI/Warning` Flat White. **[LEAD / licence]** The Vector Icon Pack Pro is a *paid* pack, and the repo's rule is "nothing third-party committed". So A, unless the licence allows redistribution of a few files. The keyboard pack (CC0) could be committed, but it has no book or door icon.
- Load them with `Image.load_svg_from_string` straight from `FileAccess`, not through `Icons` or `UiSkin`. If they fail, skip the icon; the button still works.
- **Lockup:** unchanged. The logo PNG is tracked, with the drawn die as fallback.
- **Input hints:** on desktop, show an `Esc` glyph next to Quit and an `Enter` glyph on the primary button. These also come from tracked copies of 2 CC0 key SVGs: `KBD/Keyboard Keys/White/SVG/escape_white.svg` and `enter-icon_sm_white.svg` (paths, render fine, CC0 allows committing). Add the actual Esc / Enter handling (`_unhandled_key_input`) so the glyphs are true.

### 2.4 Minigames

**New icon ids** (one per game). They replace `CampInfo.MINIGAME_ICON` and the unused `MgLogic.ICONS`, and they appear on board tiles, the loadout, the Arcade modal, the minigame ribbon and the reward modal.

| New id | Game | Candidate SVG | Alt |
|---|---|---|---|
| `mg_fossil_hunter` | Fossil Hunter | `VIP/Tools/Shovel/Shovel Wood Outline.svg` | `Items/Bone/Bone Outline.svg` |
| `mg_bubble_breaker` | Bubble Breaker | `VIP/Nature/Bubble/Bubble Blue Outline.svg` | — |
| `mg_scratch_off` | Scratch-off | `VIP/Items/Ticket/Ticket Yellow Outline.svg` | — |
| `mg_claw_machine` | Claw Machine | `VIP/Player/Grab/Grab Yellow Outline.svg` | `Items/Lucky Block/…` |
| `mg_bubble_shooter` | Bubble Shooter | `VIP/Weapons/Target/Target Outline.svg` | `Nature/Bubble/Bubble Purple Outline.svg` |
| `mg_plinko` | Plinko | `VIP/General/Luck/Luck Outline.svg` (clover, "the lucky drop") | `Currency/Coin Stack/Coin Stack Gold Outline.svg` |
| `mg_shell_game` | Shell Game | `VIP/Items/Plastic Cup/Plastic Cup Outline.svg` | — |
| `mg_memory_match` | Memory Match | `VIP/Items/Card/Card Outline.svg` | `Items/Deck of Cards/…` |
| `mg_fishing` | Fishing | `VIP/Tools/Fishing Rod/Fishing Rod Outline.svg` | `Items/Fish/Fish Outline.svg` |
| `mg_lucky_wheel` | Lucky Wheel | `VIP/General/Spinner/Spinner Outline.svg` (a prize wheel) | — |
| `mg_high_low` | High-Low | `VIP/Tools/Ladder/Ladder Outline.svg` | `UI/Arrow/Arrow Up Outline` |

**Frame and HUD**

| Element | Proposal |
|---|---|
| Scrim + glow | Keep. They are scene FX, not UI chrome. |
| Title ribbon | Use the lead's "title ribbon" plaque (3D Square 2.5 yellow) tinted to the game colour via a `modulate`, with the new `mg_*` icon on the left. **[LEAD]** Game-coloured plaques use the 9 pack colours: pick the nearest per game (fossil → brown, bubble → blue, scratch → purple, claw → pink, shooter → blue, plinko → forest green, shell → brown, memory → purple, fishing → blue, wheel → red, high-low → green). This avoids `modulate` on multi-tone art. |
| **Instruction line** (UX item 22) | Put it in its own **instruction card**: pack `Containers/Flat` navy-dark, full width up to 640 px, 12/10 px content margins, and **26 px** (from 22) weight 600 `TEXT`, not `TEXT_DIM`. Lead with a **verb glyph row**. Touch: `VIP/UI/Pointing Hand/Pointing Hand Outline.svg` + "Tap". Desktop: mouse glyph + key glyph (see §3.4). In landscape, the side column must not scale the card below 20 px effective. Clamp the column scale and wrap instead. |
| Stat pills | Pack flat round pill (`chip` piece), unit 20 px, number 34 px, unchanged. Put a small unit icon before the unit: `Tools/Hourglass/Hourglass Outline` for actions left, `General/Star/Star Outline` for score. |
| Status pill | Same pill, `GOLD_BRIGHT` text. |
| ParMeter | Replace the drawn bar with the `Bars/Regular` container (grey-darker) and three coloured zone fills (brown / grey / yellow). Tier labels: small trophy icons `General/Trophy/Trophy Bronze Outline`, `Trophy Silver Outline`, `Trophy Outline` (gold) instead of the words BRONZE / SILVER / GOLD, or next to them **[LEAD]**. |
| DROP! (claw) | `button_primary`, with desktop key badge `Space`. |
| Result beat card | Nailed frame (the global modal look). `MgWidgets.Medal` → the pack trophies above at 150 px (`Trophy` gold "1", `Trophy Silver` "2", `Trophy Bronze` "3"). This drops ~70 lines of medal `_draw`. Keep confetti. Crowns: `crown` → `VIP/Clothing/Crown/Crown Outline.svg`. "Tap to continue" becomes input-aware: "Click or press Space to continue", with glyphs, on desktop. |
| Reward modal | Global UiModal skin. Medal → trophy icon (96 px). Option-card icons come from the shared map: `coin`, `crown`, `potion`, `anvil`, `star`, `reroll`, `trophy`, `sword`, `heart`, `mirror`, `up`. `mirror` has no good pack match; for "die" rewards use `Items/Dice/Dice Outline` **[LEAD: mirror]**. TAKE: `button_primary` with `check` → `Check Mark Outline` and an `Enter` badge. |
| In-board chrome (`MgBoard.rrect` / `box`) | **Out of scope for the pack.** Boards are themed cabinets (pink claw machine, teal plinko, …) drawn to their own art direction, and the 3D prize renders stay. Two small changes only: (a) swap the `"?"` and `"!"` glyph text for `question` / `UI/Exclamation Mark` icons where they are UI-like (fossil cracks, fishing bobber: optional); (b) the touch verbs drawn inside boards become input-aware strings (§3.4). |
| Banked-crown toast (`minigame_beats.gd`) | Shared toast skin, `crown` icon. |

### 2.5 Summary of new icon ids requested from `icon_map.json`

- **Games:** `mg_fossil_hunter`, `mg_bubble_breaker`, `mg_scratch_off`, `mg_claw_machine`, `mg_bubble_shooter`, `mg_plinko`, `mg_shell_game`, `mg_memory_match`, `mg_fishing`, `mg_lucky_wheel`, `mg_high_low`
- **Tiers:** `trophy_gold`, `trophy_silver`, `trophy_bronze`
- **General:** `lock`, `hourglass`, `tap` (Pointing Hand), `back` (Arrow Back)
- **Input glyphs:** the `kbd_*` and `mouse_*` ids (§3.3). These live in a separate `input_glyphs` section **[LEAD / foundation]**, because they aren't single-SVG icons.

### 2.6 Emojis and hats

**Emojis (`vector-emojis`, CC0, 112 faces, SVG Outline / No Outline).** They are well drawn but have an emoji-app look. Used everywhere, they would cheapen the cartoon-fantasy tone. I propose **three tasteful, bounded uses**:

1. **Minigame result flavour.** A single emoji pops beside the tier title on the result beat:
   - GOLD: `EMO/Outline/Star-struck.svg`
   - SILVER: `Smiling face with sunglasses.svg`
   - BRONZE: `Grinning face.svg`
   - Bust / zero: `Face with spiral eyes.svg`
   - Jackpot (scratch / plinko x2): `Money mouth face.svg`

   It is 64 px, pops once, and has no text.
2. **Monster Kid reveal.** On the BOO! frame, flash `Face screaming in fear.svg` (the skeletons' reaction) beside the burst. This fits the tagline "The skeletons aren't sure whether to laugh or run".
3. **Run results / defeat** (area c/d, proposal only): `Skull.svg` on defeat and `Partying face.svg` on a win, as a small stamp.

Do **not** use emojis for buttons, stats or hints. **[LEAD: yes / no on the whole idea. My default is only use 1.]**

**Hats (`vector-hats`, 19 hats, colour variants, SVG + outline).**
- The Wardrobe skins are 3D. Hats as 2D icons would only fit as **cosmetic category icons**: the Wardrobe tab / button (`wardrobe` id → `HAT/Top Hat/top-hat-outline.svg`), and the Camp Wardrobe station marker. `HAT/Wizard Hat/wizard-hat-purple-outline.svg` could serve as the mage alt icon.
- In my area: **none needed**. Class select shows the 3D hero wearing the look.
- A later cosmetic feature (hats on the hero) would need 3D hats, not these.

---

## 3. Input-hint design

### 3.1 Principles

- Hints appear **only when the last-used input is keyboard/mouse**, and hide instantly on touch.
- They never add layout height on touch. Badges overlay; instruction glyphs replace the touch verb.
- Every hint must be *true*: only show a key that does something in that context. So the plan also adds a few missing bindings (Enter / Esc on menus, keys in minigames), marked **new** below.
- Keys come from one table (InputMap actions), so the glyphs and the handlers can't drift apart.

### 3.2 Actions → glyph → where shown

Create the InputMap actions in code at boot (`InputHints.ensure_actions()`, called from `main.gd`). Moving them to `project.godot [input]` is equivalent. `game_controller._key` then switches to `event.is_action_pressed(...)`.

| Action (new InputMap name) | Default binding(s) | Glyph SVG(s) | Shown where |
|---|---|---|---|
| `ui_pause` | Esc, P | `KBD/Keyboard Keys/Outline/SVG/escape.svg` (text stripped, label "ESC") | Pause button in the run HUD (area b/c: badge); controls page |
| `primary` | Space, Enter | `…/Outline/SVG/space_md.svg` ("SPACE"); Enter alt: `…/Outline/SVG/enter-icon_sm.svg` (renders natively) | ROLL / GO / ATTACK buttons (HUD, area b/c); **new:** title PLAY, class-select and run-setup START RUN, minigame DROP! / SPIN / BRAKE / strike, result "continue", reward TAKE, modal primary |
| `reroll` | R | `…/Outline/SVG/r.svg` ("R") | REROLL buttons (board and combat, area b/c) |
| `die_1` … `die_6` | 1–6 | `…/Outline/SVG/1.svg` … `6.svg` | Small corner badge on each combat tray die (area b/c); controls page |
| `back` (**new**) | Esc | `escape.svg` | Class-select back, modal close X (global), run-setup close |
| `nav_left` / `nav_right` (**new**, optional) | ← → | `…/Outline/SVG/arrow-left.svg` / `arrow-right.svg` (natively rendered) | Ascension stepper, class chip cycling on class select |
| `controls_help` (**new**, optional) | F1 or ? | `…/Outline/SVG/f1.svg` ("F1") | "Controls" row in the pause menu |
| Left click: target | mouse left | `KBD/Mouse Controls/Outline/SVG/LeftClick-Blue.svg` | Controls page ("Click an enemy to target"); combat hint line (area b/c) |
| Left click: pick | mouse left | `LeftClick-Blue.svg` | Portal pick hint, Camp ("Click a station") |
| Drag to aim | left click + move | `LeftClick-Blue.svg` + `…/Mouse Controls/Outline/SVG/Move.svg` | Shooter, plinko instructions |
| Scroll | wheel | `…/Mouse Controls/Outline/SVG/Scroll-Blue.svg` | Controls page (scroll lists), if lists scroll by wheel |

**Minigames: new keyboard play (proposal)**

This makes the hints honest and fixes an accessibility gap. Each board already has `scripted_input(args)` for the harness, so the key handler can reuse it.

| Game | Keys | Glyphs |
|---|---|---|
| Claw | Space = drop | `space_md` |
| Lucky Wheel | Space = spin / brake | `space_md` |
| Fishing | 1 / 2 / 3 = cast at shallows / reeds / deep; Space = strike | `1`, `2`, `3`, `space_md` |
| Shell Game | 1 / 2 / 3 = pick cup | `1`–`3` |
| High-Low | ↑ = higher, ↓ = lower, C = cash out | `arrow-up`, `arrow-down`, `c` |
| Plinko | ← → = move dropper, Space = drop | `arrow-left`, `arrow-right`, `space_md` |
| Shooter | ← → = aim, Space = shoot | same |
| Fossil, Bubble, Memory, Scratch | grid games: mouse only (arrow-cursor navigation is overkill) | the hint shows the mouse glyph only |

**[LEAD]** Approve keyboard minigame play or not. If not, the minigame hints show only the mouse glyph and "Click".

**Controls reference**
- **Settings panel "Controls" section** (desktop mode only). One row per action: glyph(s), then a label, e.g. "[SPACE] / [ENTER]  Roll · Move · Attack".
- It is built from the action table, so it can't go stale.
- A "Controls" button in the pause menu opens that section, with an F1 badge.
- No separate overlay screen. It's one list, and Settings already scrolls.

### 3.3 Glyph rendering: `KeyGlyph` widget

`ui/widgets/key_glyph.gd`, `class_name KeyGlyph extends Control`:

- `KeyGlyph.make(key: String, height_px := 34)`, where `key` is a `KBD` file stem ("r", "escape", "space_md", "arrow-up", "enter-icon_sm") or a mouse id ("mouse_left", "mouse_move", "mouse_scroll").
- **Keycap art:** the key's own `Keyboard Keys/Outline/SVG/<key>.svg`, run through a new `UiSvg.strip_text(svg) -> [svg_without_text, label]`.
  - The helper is a regex on `<text…>(.*?)</text>`.
  - The label is the file's own text: "esc", "r", "space", "Ctrl". Upper-case it.
  - Keys that have no `<text>` (arrows, enter-icon, blank_*) pass through unchanged.
- **Label:** drawn in `_draw` in `UiTheme.display_font()` (Lilita One), colour `#476475` (the pack's own label colour).
  - Font size ≈ 0.44 × height for 1 character, 0.34 × height for 3–5 characters.
  - Centre it on the white key face, which spans y 4..46 of the 63-unit viewBox. That means centre y ≈ 0.40 × height, not 0.5, because of the lip.
- **Compact mode** for inline text ≤ 22 px: the White set `Keyboard Keys/White/SVG/<key>_white.svg`, tinted via `UiSvg.recolor` to `TEXT` or `GOLD`. It is pure paths, so it needs no label drawing. Note the naming quirks: `shift-icon_sm_1white.svg`, `spage_lg.svg` (a typo for space_lg in the Outline set).
- **Mouse glyphs:** `Mouse Controls/Outline/SVG/{LeftClick-Blue,RightClick-Blue,Move,Scroll-Blue}.svg` (96×96, paths only). Compact: `Mouse Controls/White/SVG/*_White.svg`.
- **Fallback when the pack is not imported:** draw a rounded rectangle with a 3 px ink outline, a `#cef` face, a `#96dbff` lip and the same label. That is ~20 lines, and the glyph never disappears.
- **Import:** the foundation's `tools/import_assets.sh` copies files referenced by manifests. Add an `input_glyphs` list in `ui/icons/icon_map.json` (or a small `ui/icons/input_glyphs.json`) naming the ~25 KBD files used, so they are imported under `res://assets/ui/icons/vector-keyboard-controls/…` like any icon. **[FOUNDATION]** The `UiSvg.strip_text` helper and `kind "icons"` covering the KBD pack. KBD is CC0, so committing a handful of glyphs is also legal. That is what the boot screen does (§2.3).

**`KeyBadge`** (button decoration): a `KeyGlyph` at ~30 px anchored to a `GameButton`'s top-right corner, offset (-6, -14), overlapping the frame like a notification badge. It lives on a child Control with `top_level = false` and `mouse_filter = IGNORE`, so the button's hit rect and layout size don't change.
- API: `GameButton.key_hint = "primary"` (action name). The badge resolves the glyph from the action's first key event.
- It shows and hides with `InputMode.changed`.
- See `scratchpad/ui-plan/e/mock_key_hint.png`, top row: ROLL with SPACE, REROLL with R, and the touch variant without a badge.

**Inline glyphs in text:** `InputHints.rich(label: RichTextLabel, template: String)`.
- Replaces tokens such as `{primary}`, `{click}`, `{drag}` and `{1-3}` with `RichTextLabel.add_image(texture, w, h)`, which accepts runtime Texture2D (DPITexture) with no resource path.
- On touch, tokens map to words ("Tap", "Drag") or to the pointing-hand icon.

### 3.4 Instruction copy per input mode

Change `MgLogic.HINTS` from `{id: String}` to `{id: {touch: String, kbm: String}}`, or keep one template with tokens.

| Game | Touch | Desktop |
|---|---|---|
| Claw | "Tap to drop. Every capsule hides a prize…" | "{click} or {primary} to drop. Every capsule hides a prize…" |
| Fishing | "Tap a spot to cast. Tap to strike when the bobber plunges, not on a nibble!" | "{click} a spot or press {1}{2}{3} to cast. {primary} strikes on the plunge!" |
| Shooter | "Drag to aim, release to shoot…" | "{drag} to aim, release to shoot, or {left}{right} + {primary}…" |

The board-drawn prompts ("TAP A SPOT TO CAST", "STRIKE! TAP!", "DRAG TO AIM - RELEASE TO SHOOT", "Tap to continue") read `InputMode.verb("tap")`, which returns "TAP" or "CLICK". The drawn prompts stay text-only: no glyphs inside the cabinets, because they are drawn with `draw_string`.

### 3.5 Input-mode detection: `InputMode`

`ui/input/input_mode.gd`: a static class plus a tiny listener Node added once by `UiRoot` (and by `MissingAssetsScreen` for itself). There is no new autoload.

```
enum Mode { TOUCH, KBM, GAMEPAD }
static var mode: Mode        # current
signal changed(mode)         # on the listener node (InputMode.bus)
```

**Initial mode**
- `TOUCH` if `OS.has_feature("mobile")`, `web_ios` or `web_android`.
- Otherwise `TOUCH` if `DisplayServer.is_touchscreen_available()` **and** there is no mouse (desktop web on a tablet).
- Otherwise `KBM`.

**Switching** happens in `_input(event)`, which only observes and never consumes:

| Event | Result |
|---|---|
| `InputEventScreenTouch` / `ScreenDrag` | → TOUCH |
| `InputEventMouseButton` / `MouseMotion` with `device != InputEvent.DEVICE_ID_EMULATION` (the touch-emulated mouse must not flip the mode, same trick as `DevGesture`), and motion ≥ 4 px so a stray jitter doesn't count | → KBM |
| `InputEventKey` (pressed) | → KBM. An iPad with a Magic Keyboard gets hints. |
| `InputEventJoypadButton` / `JoypadMotion` over the deadzone | → GAMEPAD. There's no gamepad support today, so treat it like KBM for the Controls page, but hide key badges. Reserved for later. |

**Other behaviour**
- Debounce: at most one `changed` per 0.25 s.
- **Settings override:** "Key hints: Auto / Always / Never", stored next to UI size in the user settings file. "Never" is for streamers and purists.
- **Harness:** add a `--input=touch|kbm` shot flag that forces the mode, so both variants get screenshot coverage. Desktop matrix shots default to KBM, phone and iPad entries to TOUCH. Pass the flag from `shoot_matrix.sh` per row: add a 5th column, or derive it from the safe-area column being non-zero.

---

## 4. Layout risks across the device matrix

| Risk | Where | Mitigation / check |
|---|---|---|
| Logo and yellow PLAY plate merge (two warm golds), or PLAY's taller 3D lip pushes the column into the footer | `iphone17_land` (874×402), `duo_inner_land`, `pc_720p` | Today the column fits: the before shot `ui_title__iphone17_land` shows the canvas_items stretch shrinking everything. But the column fills the bottom half, and a pack lip (19/64 of the height) adds height to each button. **Plan:** if the after shot crowds the footer in landscape at h < 500, put PLAY / CONTINUE / SETTINGS in a **row**, or hide CONTINUE when there is no save (item 21). Check the after shots of `ui_title` on the full matrix. |
| Chip labels truncate ("Necromancer", "Monster Kid" at 18 px) in 85 px chips with 9-slice side margins | `iphone17_17pro` (402), `duo_outer` (466), `iphone17_z125` | Flat pill with 3-slice 27-unit caps at scale ~0.5 ≈ 13 px per side. Keep `pad_x` 6 and let labels shrink to 16 px (autosize), or drop the icon below 90 px chip width. |
| Class-select panel height grows (pack frames have thicker margins: Nailed 24/27/24/34) and squeezes the portrait below its 30% floor | phones portrait, `ipadmini_z125` | `_layout` already reserves `avail*0.3`. Recompute `chrome` with the skin's content margins (`UiSkin` content margins, not constants). |
| START RUN plus key badge overlaps the panel's top edge / scroll | all desktop | The badge overlays with a negative offset inside the button rect's top-right. Verify it isn't clipped by `ScrollContainer` (START is outside the scroll: OK) or by modal `clip_contents` (run setup: START is inside the modal body scroll, so badges need `clip_children` off, or an inward offset). |
| Key badge on small round buttons (68 px ascension steppers, 88 px back) covers the icon | desktop | Badge size = min(30, 0.4 × button height). Corner anchoring. |
| Minigame instruction card at 26 px wraps to 3 lines and pushes the board down | `iphone17_17pro`, `duo_outer` | The card goes above the pills. The board holder's height is computed after it (the existing `_layout` flow). Accept 3 lines on the 402 pt phone. Measure `mg_scratch` (longest hint) and `mg_bubble`. |
| Landscape side column scaled ×1.55 on big desktops, but still ~11 px effective on phone landscape | `iphone17_land`, `duo_inner_land` | Clamp so the hint renders at ≥ 18 px effective. Let the column scroll or shrink the ParMeter instead. |
| Inline glyphs in RichTextLabel change line height | all desktop | Glyph height = font size × 1.15, `INLINE_ALIGNMENT_CENTER`. Line separation +4. |
| Zoom 0.8 / 1.25 / 1.5: DPITexture glyphs stay crisp, but the label font inside KeyGlyph must scale with the glyph | zoom set | The label is drawn in the same Control, so it scales with the canvas. OK. |
| Missing-assets screen: the new 80 px buttons plus an icon plus an Esc glyph overflow a 402 pt card | `iphone17_17pro`, `duo_outer` | The button row already stretches (1 : 0.55). Hide key glyphs on touch. Stack the buttons vertically below 440 pt card width. |
| Hints wrongly visible on iPhone / iPad shots (harness runs on a Mac, so it would detect KBM) | all mobile matrix rows | The `--input=` flag (§3.5), derived per matrix row. |
| DevGesture corner vs. key badges / footer | title, boot | Nothing is placed in the bottom-right 80 px. Keep it that way. The footer is centred. |

---

## 5. Implementation plan

The steps are ordered. Dependencies: **F** = foundation (`wp-ui-foundation`), **L** = lead map / spec, **B/C** = the HUD area planners (for badges on run buttons).

1. **`InputMode` + actions** (no art dependency).
   - `ui/input/input_mode.gd` and `ui/input/input_hints.gd` (the action table, `ensure_actions()`, `glyph_for(action)`, `rich()`, `verb()`).
   - Switch `game_controller._key` to the actions.
   - Add the `--input=` harness flag in `tools/shot.gd` and the matrix column in `shoot_matrix.sh`.
   - Unit tests (headless): mode switching on synthetic events, including emulated-mouse events being ignored.
2. **`KeyGlyph` / `KeyBadge`** (depends on F: `UiSvg`, the importer).
   - `UiSvg.strip_text` (F owns `ui_svg.gd`; propose the helper to them or add it with a test).
   - The glyph list in the manifest (L/F), and the drawn fallback.
   - A `GameButton.key_hint` property. `GameButton` is the shared widget, so coordinate with whoever reskins it (F/L).
3. **New bindings:** Enter / Esc on title, class select, run setup and modals. The action `back` closes the top UiModal (global: coordinate with the modal area planner). Optional arrows on class select and ascension.
4. **Title reskin** (depends on L: the `button_primary` / `button_secondary` pieces, and on `icon_map` entries `campfire`, `arrow_right`, `gear`).
   - Landscape row layout at h < 500.
   - CONTINUE hidden when there's no save (L decision).
   - PLAY badge `Enter`.
   - Footer credit.
5. **Class select and run setup** (depends on L: `chip` piece, container pieces, class / mech icon map).
   - Chips → flat pill, lock badge, desaturated locked icons.
   - Mechanic badge → container.
   - Stat chips.
   - Back → round button with the Esc badge.
   - START → Enter badge.
   - `CampInfo.MINIGAME_ICON` → `mg_*` ids.
6. **Missing-assets screen** (no dependency, and must not take one).
   - Pack-echo colours, 80 px buttons.
   - Tracked `game/boot/icons/{book,door,warning}.svg` (hand-drawn, option A).
   - Tracked CC0 `escape_white.svg` / `enter-icon_sm_white.svg` with the Esc / Enter handlers.
   - Test: run the scenario with `res://assets/ui/` renamed away and the fonts missing (the scenario already builds without them). Assert that it has no `Icons` / `UiSkin` references (grep test in `ui/check_scripts.gd` or a unit test).
7. **Minigame frame** (depends on L: ribbon plaque, containers, bars, trophy / crown / mg icon map).
   - Instruction card (26 px, glyph row).
   - Pill icons, ParMeter → bars.
   - Medal → trophies (result and reward).
   - DROP! badge, input-aware "continue".
8. **Minigame copy and keys.**
   - `MgLogic.HINTS` → per-mode templates.
   - Board-drawn verbs via `InputHints.verb`.
   - Optional keyboard play per §3.2 (L approval), routed through each board's `scripted_input`.
9. **Controls page:** a Settings "Controls" section plus a pause-menu button (coordinate with the settings / pause owner). Built from the action table.
10. **Emoji flavour** (L approval): the result-beat emoji and the BOO! reaction.
11. **After-shots and review gallery** (§6).

Rough size: steps 1–3 ≈ 1 day, 4–6 ≈ 1 day, 7–8 ≈ 1.5 days, 9–10 ≈ 0.5 day.

**Blocked on** L for the button, chip, container, frame and bar piece names and the final icon map. Steps 1, 3 and 6 can start now.

---

## 6. Test plan

**Automated (headless, `godot --headless`)**
- `InputMode`:
  - touch → TOUCH
  - an emulated mouse (`device == DEVICE_ID_EMULATION`) doesn't flip the mode
  - real mouse motion ≥ 4 px → KBM
  - key → KBM
  - joypad → GAMEPAD
  - the Settings override wins
- `InputHints`:
  - every action in the table has a binding and a glyph that exists in the manifest
  - `glyph_for("primary") == "space_md"`
  - rebinding an action changes the glyph
- `UiSvg.strip_text`:
  - `r.svg` → the label is "r" and the SVG has no `<text>`
  - `arrow-up.svg` → unchanged
  - a rasterised stripped key isn't empty (alpha > 0 on the cap)
- `KeyGlyph` fallback: with the map pointing at a missing file, the widget still has a non-zero min size and draws.
- Missing-assets screen: it builds with no `res://assets/ui`, and a source grep finds no `Icons.` or `UiSkin.` in `game/boot/`.
- Existing: `ui/check_scripts.gd` compiles, the `tests/` suite passes, and `mg_* --state=play` prints `MG_PLAY_OK` for all 11 games (input rework regression). Add a `--state=play --input=kbm --keys=1` variant for the games with keyboard play.

**Screenshots (after = before scenarios, plus both input modes)**
- Use `tools/shoot_matrix.sh`, with `--wait=7` for the title and `--wait=9` for the minigames, since agents shoot in parallel.

| Scenario | Set | Checks |
|---|---|---|
| `ui_title` | `all` | Logo vs PLAY; landscape row; footer; dev corner clear |
| `ui_title --input=kbm` | `desktop` | Enter badge |
| `ui_class_select` | `quick` + `zoom` | Chip labels, lock badges |
| `ui_class_select --profile=mid --class=monster_kid` | `quick` | — |
| `ui_mk_mystery` | `quick` | — |
| `ui_mk_reveal --frames=6` | `iphone17_17pro` | Emoji flavour |
| `asset_missing` | `all`, also with the pack folder renamed away | — |
| `mg_<11 ids>` | iphone17_17pro, pc_1366x768, iphone17_land, duo_outer | Instruction card size and lines |
| `mg_<11 ids> --input=kbm` | pc_1366x768 | Glyphs in hints, DROP! badge |
| `mg_claw --state=result` / `--state=reward` | as above | Trophies, TAKE badge |
| `ui_settings --input=kbm` | desktop | Controls section |
| `ui_pause --input=kbm` | desktop | — |

- Show the before / after pairs to Vlad as a gallery page (the memory note on review artifacts).

**Manual (desktop build)**
- Play one run with the keyboard only: Space, R, 1–6, Esc.
- Play claw, wheel, fishing and high-low with the keyboard.
- Switch between the trackpad and the keyboard: badges appear. Touch on a touchscreen Mac or an iPad simulator: badges disappear with no layout jump.

---

## Appendix A: artifacts

**Scratchpad root:** `/private/tmp/claude-501/-Users-vlad-Repos-diceroll/1bba73af-2ee7-40a8-8c95-50839b8aed16/scratchpad/ui-plan/e/`

| Path under the root | Contents |
|---|---|
| `before/` | Before shots, grouped by `title/`, `class_select/`, `class_select_mid/`, `mk_mystery/`, `asset_missing/`, `mg/`, `mg_result/`, `mg_reward/` |
| `mock_key_hint.png` | Mockup: pack buttons with key badges (desktop vs touch), minigame instruction strip, and the three glyph sources compared (drawn label vs White set vs Outline in Godot) |
| `svgtest/godot_raster.png` | Godot 4.7.2 rasterisation of the Outline / White / Black keys and mouse glyphs. Shows the empty Outline keycaps. |
| `icon_candidates.png` | Contact sheet of the candidate icons (full-colour variants) |
| `emoji_hats.png` | Emoji and hat samples |

## Appendix B: proposals for the lead (collected)

1. Input glyphs: approve the `KeyGlyph` approach (Outline cap with its text stripped, plus a game-font label; White set for compact inline). Add an `input_glyphs` section to the map, and the `UiSvg.strip_text` helper (F).
2. Hide CONTINUE with no save (UX item 21). Put the landscape title buttons in a row.
3. SETTINGS on the title: a secondary pack button (the GHOST kind goes away).
4. Class chips: flat round pills, not 3D Square. Lock badge. Add a `saturation` key to icon map entries for locked states.
5. Mechanic medallions: Flat White plus the mechanic tint, rather than full colour.
6. New ids: `mg_*` ×11, `trophy_gold/silver/bronze`, `lock`, `hourglass`, `tap`, `back`. `mirror` needs a pick.
7. Minigame ribbons: per-game pack colour variants rather than `modulate`.
8. Medal widget → pack trophies (result beat and reward modal).
9. Keyboard play in minigames (claw, wheel, fishing, shell, high-low, plinko, shooter).
10. Missing-assets screen: hand-drawn tracked icons (paid-pack licence), pack-echo colours, 80 px buttons.
11. Emojis: only on the minigame result beat, plus the BOO! reaction. Hats: Wardrobe category icon only.
12. Footer credit line for RhosGFX.
