# UI reskin, area (c): modals and run screens

Status: plan (2026-09-30). Area planner (c). No code changes here; a later engineer implements this.

Aligned with:
- the lead's draft `docs/design/2026-09-30-ui-reskin.md` on `origin/wp-ui-design` (commit ef8b01f, "Night navy + wood", option D);
- the foundation WIP in `.claude/worktrees/wp-ui-foundation` (uncommitted): `UiSvg` (DPITexture, sanitised runtime paths), `UiSkin` (pieces in `ui/theme/ui_pack.json`, `stylebox()`, `apply_button/panel/progress/slider/toggle`, `texture()`, layered states through `UiLayeredStyleBox`), and `Icons` (drop-in superset of `UiIcons`, driven by `ui/icons/icon_map.json`, falling back to the legacy glyph).
- the pre-boss camp work in `.claude/worktrees/wp-preboss` (uncommitted): the Last Camp is an `EventModal` with `id == "camp"` plus a draft source `"camp"`. Both are covered below.

Items marked **[LEAD]** are proposals where the lead or the foundation has not decided yet.

Before-shots: `/private/tmp/claude-501/-Users-vlad-Repos-diceroll/1bba73af-2ee7-40a8-8c95-50839b8aed16/scratchpad/ui-plan/c/before/<scenario>/` (quick set: pc_1080p, pc_1366x768, iphone17_17pro, duo_outer, ipadpro13_land; plus `zoom_*` folders with the zoom and Duo sets for pause, results and settings).
Mockup: `.../scratchpad/ui-plan/c/mockup_c_draft.png` (the LEVEL UP draft on the 720 canvas, Nailed frame at 1.0 and 0.75). Icon candidates sheet: `.../scratchpad/ui-plan/c/icon_candidates.png`.

---

## 1. Inventory

Common base: every modal extends `UiModal` (`ui/widgets/ui_modal.gd`). It has a scrim `ColorRect` (`UiPalette.SCRIM`), then a `_frame` VBox (separation -26) holding a `Ribbon` (custom `_draw`: gold banner with folded tails, 38 px Lilita) and `panel` (`UiTheme.panel("main")`: `StyleBoxFlat` `PANEL`, radius 34, 3 px `GOLD_LINE` border, 28 px shadow, padding 32/28). Inside the panel are a `ScrollContainer` (vertical auto) and `body` (VBox, separation 18). Width is `min(max_width=680, avail)`. It never lays out narrower than `MIN_W = 620`; below that it scales the whole frame by `_fit` (0.6..1). A slightly too tall panel shrinks up to 20 % before it scrolls. The theme's scrollbar is a 12 px flat track (white at 4 %) with a `GOLD_FAINT` grabber.

Shared widgets used across my screens:
| widget | file | current look |
|---|---|---|
| `OptionCard` | `ui/widgets/option_card.gd` | custom `_draw`: navy rounded card, 2 px outline, top sheen, accent edge (rarity colour at 50 %), selected = 4 px `GOLD_BRIGHT` + glow; `premium` (boss tier) = gold double frame + corner studs + warm glow. Medallion 80 px on the left (`OptionCard.Medallion`: drawn disc, ring colour, icon), title 30 Lilita, tag chip (`StyleBoxFlat` in rarity colour at 16 %), description, optional price pill (`coin` icon + number), SOLD stamp |
| `Medallion` | inner class of `OptionCard` | drawn circle + ring + icon (`UiIcons.tex`) |
| `DieChip` | `ui/widgets/die_chip.gd` | drawn card: rune socket, name, 6 mini `DieFace`s; selected = gold 4 px |
| `RuneBadge` / `PassiveIcon` | `ui/widgets/rune_badge.gd`, `passive_icon.gd` | drawn gem-socket / relic ring + glyph |
| `GameButton` | `ui/widgets/game_button.gd` | drawn 3D button, kinds PRIMARY/SECONDARY/DANGER/SUCCESS/ROUND/GHOST, depth lip 8 px |
| `Counter` | `ui/widgets/counter.gd` | `panel_box("pill")` + icon + ticking number |
| `RouteStrip` | `ui/widgets/route_strip.gd` | biome medallions + arrows + lap pips; boss stops as `StyleBoxFlat` chips |
| `KitStrip` | `ui/widgets/kit_strip.gd` | item thumbnails in dark wells + tier chips |
| `CampUi.card / bar / sigils` | `ui/camp/camp_ui.gd` (area d) | `panel_box("card"/"card_hi")`, `ProgressPill`, star icon tinted violet |

### 1.1 Screens

| screen | file(s) | structure | styles now | icon ids now | scenarios |
|---|---|---|---|---|---|
| **Draft / upgrade picker** (LEVEL UP, ELITE SPOILS, TREASURE, REWARD, pre-boss "BY THE FIRE") | `ui/modals/draft_modal.gd` | ribbon (XP purple for level, gold otherwise), subtitle, 3 `OptionCard`s (rune: `RuneBadge` + "<RARITY> RUNE" tag; die: `DieFace` + 6 faces + "<RARITY> DIE"; boon: medallion + "BOON"), TAKE (PRIMARY, check) | UiModal main, OptionCard | `dice`, `heart`, `reroll`, `anvil`, `star`, `check`, `rune_*` | `game_draft`, `ui_draft`, `ui_rune_choice`, `game_manual` step shots |
| **Passive reward** | `ui/modals/passive_modal.gd` | ribbon (UNCOMMON green / BOSS), subtitle, 3 passive cards (premium frame on boss tier), a radial warm glow behind, TAKE | OptionCard premium | `passive_*`, `check` | `game_passive` (`--source=miniboss|elite|boss`) |
| **Shop** | `ui/modals/shop_modal.gd` | ribbon "SHOP", header row [gold `Counter` pill, RESTOCK SECONDARY with sub-text], item cards with price pills and SOLD, an inline die picker (section label + 3-col grid of `DieChip`), footer [LEAVE SECONDARY, BUY PRIMARY expand] | OptionCard, Counter "pill" | `3d:coins`, `reroll`, `dice`, `3d:potion_red`, `potion_*`, `anvil`, `rune_*`, `passive_*`, `arrow_right`, `coin` | `game_shop`, `ui_shop`, `ui_shop_pick` |
| **Forge (face picker)** | `ui/modals/forge_modal.gd` | ribbon "FORGE"/"FACE RAISE" (steel grey), section labels "1 · Choose a die" / "2 · Choose a face", row of `_DieTab`s (drawn cards), row of `_FaceButton`s (`DieFace` 84), RAISE +1 / MIRROR toggle buttons, "Copy from face" row, inset preview panel (Before → After), SKIP (GHOST) + FORGE (PRIMARY) | `panel_box("inset")`, drawn tabs | `up`, `mirror`, `arrow_right`, `anvil`, `rune_*` | `game_forge`, `ui_forge` |
| **Events** (shrine, duel, outbreak, garden, merchant, idol, **ore**, pre-boss **camp**) | `ui/modals/event_modal.gd` | ribbon in the event rim colour (violet default, ore teal `3fb8aa`, camp orange `ff9a4a`), 132 px Medallion art, flavour text, choice `OptionCard`s (LOCKED tag when disabled); camp adds a "RESTED +N HP" pill (`StyleBoxFlat` HEAL) | OptionCard | art: `star`, `dice`, `skull`, `rune_lucky`, `coin`, `curse`, `ore`, `campfire`; choices: `sword`, `heart`, `3d:coins`, `anvil`, `coin`, `arrow_right`, `rune_wild`, `3d:chest_gems`, camp: `potion_healing`, `rune_wild`, `reroll` | `game_event`, `ui_event`, `ui_event_duel`, `twist_ore`, `twist_cave_in`, `game_last_camp` (wp-preboss only) |
| **Rune assign** | `ui/modals/rune_assign_modal.gd` | ribbon "BIND <RUNE>", inset hero row (RuneBadge 96 + name + rarity + desc), "Choose a die", 3-col `DieChip` grid, note line, BIND RUNE PRIMARY | inset, DieChip | `rune_*`, `check` | `ui_rune_assign` |
| **Die inspector** | `ui/modals/die_inspector.gd` | ribbon in the kind colour, nav row (round GHOST arrows + "n / N"), head (DieFace 116, kind name + rarity tag, desc, rune row), "Faces" unfolded net (4-col grid of `DieFace` 84), notes, CLOSE SECONDARY | tag `StyleBoxFlat` | `arrow_left`, `arrow_right`, `close`, `rune_*` | `game_die_inspect` (`--die=N`) |
| **Pause** | `ui/modals/pause_menu.gd` (max_width 560) | ribbon PAUSED / ABANDON? (DANGER), info line, `RouteStrip` (compact), `KitStrip` + item names, passives `HFlowContainer` (`PassiveIcon` 48), RESUME PRIMARY, SETTINGS SECONDARY, ABANDON RUN DANGER; inline confirm (KEEP PLAYING / ABANDON) | main | `arrow_right`, `gear`, `flag`, `skull`, `biome_*`, `check`, boss icons | `game_pause` (`--lap=N`), `ui_pause`, `ui_pause_loadout` |
| **Settings** | `ui/modals/settings_panel.gd` (max_width 600) | 3 volume rows (icon + label + % + `HSlider`), game speed row (1× 2× 4× toggle chips), **UI size row** (90/100/115/130 % toggle chips), auto-update row (ON/OFF toggle + CHECK), AUTO SETTINGS, DONE | theme HSlider (flat track + gold fill + drawn knob), GameButton toggles | `speaker`, `music`, `bolt`, `speed`, `plus`, `gear`, `auto`, `check` | `ui_settings`, `settings_path` |
| **Developer menu** (hidden) | `ui/modals/dev_menu.gd`, `dev_menu_scenarios.gd` | sections (section labels), channel row (gear + STABLE/BETA chips), CHECK NOW / RESET buttons, a build info list (`panel("pill")`), confirm sub-view, CLOSE | main, pill | `gear`, `check`, `close`, `reroll`, `arrow_left` | `dev_menu`, `dev_menu_confirm`, `dev_menu_store`, `dev_menu_boot` |
| **Route card** | `ui/modals/route_card.gd` | ribbon, full `RouteStrip`, BEGIN PRIMARY | main | `biome_*`, `arrow_right`, `skull`, `crown` | `route_card` |
| **Portal banner** | `ui/modals/portal_banner.gd` | non-modal pill: violet `StyleBoxFlat` (radius 30, glow), portal icon 64, two lines, pulsing | custom | `portal` | `game_portal`, `ui_portal` |
| **Results** (victory / defeat) | `ui/screens/summary_screen.gd` (max_width 700; own `_layout` with the footer outside the scroll) | ribbon VICTORY!/DEFEATED, headline, hero row (class Medallion 80 + name + sub line), `RouteStrip` (compact, bosses beaten), **Crowns table** (section label + inset panel: rows [icon 32, label, detail, "+N" counted up] + separator + TOTAL row with crown 44), **Firsts** (flow of violet chips with sigil counts), **pet XP** card (`CampUi.card` + medallion + `CampUi.bar`), **Items and mastery** (`CampUi.card`: `ItemThumb` 56 rows + mastery bar), blueprint / feat item cards, **Unlocked!** cards (`CampUi.card(true)`: medallion 64 or `ItemThumb` + "NEW <KIND>" + name + why; `SecretReveal` for the ??? class; ascension card), **New skins!** cards (`HeroPortrait` 110×130 + wardrobe kicker), **Nearest goals** (3 × `CampUi.card` with icon, title, n/m, bar, detail). Footer under the panel: home (SECONDARY, round-ish) + TO CAMP (PRIMARY, campfire) | inset, CampUi cards, chips | `flag`, `portal`, `skull`, `trophy`, `star`, `coin`, `up`, `crown`, `wardrobe`, `class_*`, `biome_*`, pet icons, minigame icons, slot icons, `question`, `home`, `campfire` | `game_victory`, `game_defeat`, `ui_victory`, `ui_defeat`, `ui_results_win`, `ui_results_loss`, `ui_results_items`, `ui_results_skins`, `ui_mk_reveal` |
| **Tooltips** (4 builders + native) | `ui/widgets/hud_top.gd` `_text_tip` (passives, class badge), `ui/hud/meta_hud.gd` `_show_tip` (potion belt, pet meter), `game/enemies/affix_tips.gd` `show_tip` (affix badge), `UiTheme` `TooltipPanel` (native `tooltip_text`: treasury, lap chip, twist chip, kit wells) | same recipe copied 3 times: `StyleBoxFlat` ink 0.97, radius 16, 2 px border **in the accent colour** (rarity / potion / affix), pad 16/10; title 26 Lilita in accent, tag 16, body 21 | | affix icons, none in text tips | `elite_affixed` / `game_combat --tip=I:K`, `hud_potions --tip=N`, `game_board --passives=N` (tap) |
| **First-encounter (affix) cards** | `game/enemies/encounter_cards.gd` | full-screen dim, a card (`StyleBoxFlat` radius 28, 4 px border in the affix/enemy colour, glow), a live 3D enemy model, "NEW FOE"/affix caption with icon 44, name, rule text, stats line, "Tap to continue" | custom | `affix_*` | `elite_affix_card`, `game_combat` (cards on for a fresh profile) |
| **Toasts / popups / reward cards** | `game/flow/overlay.gd`: `toast()` (`panel_box("pill")` + icon 36 + text), `popup()` (floating text + icon), `passive_card()` (passive gained banner, border in rarity colour), `item_pop()` (item callout), `mini_dice()` (duel result, `panel_box("main")`) | pill / custom boxes | whatever the caller passes (`reroll`, `sword`, `flag`, `heart`, `rune_*`, `coin`...) | `level_up_auto`, `events_misc`, `run_item_triggered`, `ui_event_duel` |

Out of scope for (c), but touching it: `announce()`, `boss_card()` and `biome_card()` in `overlay.gd`, the HUD belt in `meta_hud.gd`, and the HUD itself (area b). There is also `ui/auto/auto_settings_panel.gd` (a UiModal opened from Settings), which I suggest (c) takes, because it is a settings sheet **[LEAD]**.

### 1.2 Before-shot observations
- In-game modals (`game_*`) need `--wait=10` on a loaded machine. With `--wait=3` the frame is still fading in and only the scrim is captured. The test plan uses 10.
- `ui_pause_loadout` renders black on iPhone, Duo and iPad in the quick set, even at `--wait=20`. At 1080p the whole pause (panel included) sits under a second dim layer. This is a pre-existing scenario issue. Fix it or replace it before the after-shots.
- `hud_potions --tip=0` needs `--wait=6`, because the tip fades after 2.8 s. With `level_up_auto` I did not catch the toast. Use `--frames`, or add a held toast scenario (§5).
- **Pre-existing bug:** `ui_results_win` on `iphone17_z125` (UI size 125 %, a 576 px logical canvas) overflows the screen on the right. `SummaryScreen._layout()` overrides `UiModal._layout()` without the `MIN_W` / `_fit` shrink, so wide content (route strip, first chips) pushes the frame past the screen edge. Thicker frames make this worse. Fix it as step 1 of results (§4).

---

## 2. Proposed mapping

Pack paths are relative to `third_party/rhosgfx/cartoony-ui-pack-full/`. 9-slice margins are in viewBox units, taken from the lead's measurements, and "scale" is logical px per unit (the `UiSkin` `scale` key).

### 2.1 Frames and panels (pieces for `ui/theme/ui_pack.json`)

| piece (proposed name) | used by | art | scale | notes |
|---|---|---|---|---|
| `panel_modal` | UiModal panel (all modals, results, pause, settings, dev) | layers: navy fill (`Containers/Flat/0. White/container-flat-white.svg` modulate `NAVY` 0.96, expand -10) + `Frames/Nailed/9. Brown/frame-nailed-darkbrown.svg` (24/27/24/34) | **0.75** on the 720 canvas (18/20/18/26 border), 1.0 when the canvas is ≥ 1000 logical px tall and wide **[LEAD]** | Lead's option D. In the mockup at 1.0, the plain `darkbrown` reads rust-orange against navy. `darkbrown-dark` is closer to "wood". **[LEAD]** Content margin = slice × scale + 12. |
| `title_plaque` | `Ribbon` | `Buttons/3D/Square/0. White/button-square-3d-2.5-white_standard.svg` (9/9/9/19), `modulate` = the ribbon colour at draw time | 1.25 | One white piece keeps every existing ribbon colour (XP purple, gold, DANGER, event violet / teal / camp orange, forge steel, kind colours). Needs a runtime modulate: `sb.modulate_color = color` on the duplicate `UiSkin.stylebox()` returns. That works for single-layer pieces with no new API. |
| `card` / `card_hi` | OptionCard, DieChip, `_DieTab`, results cards (via `CampUi.card`), rune-assign hero | `Containers/3D/0. White/container-3d-white.svg` (15/15/15/25) modulate `NAVY_2` (hi: `NAVY_3`) | 0.9 | `card_hi` adds a layer `Frames/Thin/3. Yellow/frame-thin-yellow.svg` (22) at scale 0.45, expand 4 = the selected ring (see mockup). |
| `card_accent` | OptionCard rarity edge, event rim, results `CampUi.card(false, accent)` | `Frames/Thin/0. White/frame-thin-white.svg` at 0.3, modulate = accent at 0.55 | 0.3 | Keeps the rarity colour language (common grey / uncommon green / rare blue / epic violet / boss gold). |
| `card_premium` | boss-tier passive cards | `Frames/Ornate/3. Yellow/frame-ornate-yellow.svg` (≈40/46/40/40) | 0.45 | The only use of Ornate: the thick ornate border only works as a thin overlay. |
| `inset` | Crowns table, forge preview, rune-assign hero, dev build info | `Containers/Flat/0. White/container-flat-white.svg` (10) modulate `INK` α 0.55 | 1.0 | **Not** `Frames/Inset` (34/39/34/44 costs about 80 px of height per inset on the phone). |
| `chip` | OptionCard tag, die-inspector rarity tag, results "Firsts" chips, camp "RESTED +N HP" pill, boss-stop chips in RouteStrip | `Buttons/Flat/Round/0. White/button-round-flat-2.5-white_standard.svg` (3-slice 27 L/R) modulate accent | 0.5 | The lead's "Chips/pills = button-round-flat-2.5". |
| `price_pill` / `pill` | OptionCard price, shop gold Counter, toasts | `Buttons/Flat/Round/1. Grey/button-round-flat-2.5-grey-darker_standard.svg` | 0.6 | `pill` is shared with the HUD (area b), so agree the name. |
| `medallion` | `OptionCard.Medallion` (event art, boons, unlock cards, class hero, goal heads) | `Buttons/3D/Round/0. White/button-round-3d-1-white_standard.svg`, modulate ring colour | px/64 | Replaces the drawn disc; icon on top, full colour. `RuneBadge` / `PassiveIcon` stay drawn in (c), because they are HUD widgets too (area b decides). **[LEAD]** |
| `tooltip` | all 4 tooltip builders + `TooltipPanel` | layers: `container-flat-white` modulate `INK` 0.97 + `Frames/Thin/0. White/frame-thin-white.svg` at 0.3, modulate accent | 0.3 | The lead says "Frames/Thin darkbrown". I propose **Thin white × accent** so the rarity / affix / potion colour stays (that is the information). Fall back to darkbrown when there is no accent. **[LEAD]** |
| `encounter_card` | EncounterCards | layers: navy fill + `Frames/Pointed/0. White/frame-pointed-white.svg` (32) modulate affix colour | 0.6 | Pointed = enemy / danger family. The same piece could serve `boss_card` (area b). **[LEAD]** |
| `portal_banner` | PortalBanner | `Containers/Flat/7. Purple/container-flat-purple-darker.svg` + `Frames/Thin/7. Purple/frame-thin-purple.svg` 0.35 | | |
| `scroll_track` / `scroll_grabber` | theme VScrollBar (slice a) | track `container-flat-white` modulate `INK` α 0.5 at 0.4 (radius ≈ 4); grabber `Containers/3D/9. Brown/container-3d-lightbrown-regular.svg` at 0.35 (hover: `-light`) | 0.35–0.4 | See §3.3. |
| `slider` | Settings volume sliders | track `Bars/Regular/1. Grey/progress-container-regular-grey-darker.svg`, fill `Bars/Regular/3. Yellow/progress-bar-regular-yellow-regular.svg`, grabber `Bars/Handles/handle-round.svg` (24×28 → 44 px) | | `UiSkin.apply_slider()` already exists. The theme default belongs to slice (a). |
| `toggle` | Settings auto-update ON/OFF | `Widgets/Toggles/3. Yellow/toggle-container-round-yellow.svg` + `Widgets/Handles/handle-round.svg` | | Replaces the ON/OFF GameButton with a real toggle. `apply_toggle()` needs checked / unchecked art, so compose two states **[LEAD]**. |
| `bar_goal` | results goals / pet XP / mastery (`CampUi.bar`) | `Bars/Thin/1. Grey/progress-container-thin-grey-darker.svg` (8) + `Bars/Thin/<colour>/progress-bar-thin-*` (4) | | This is `CampUi` (area d). I only need it to exist. |

### 2.2 Buttons (the lead's decision, applied to my screens)
Implemented once in `GameButton` by slice (a): 3D Square 2.5 per kind. My call sites keep their `Kind`:
- PRIMARY (yellow): TAKE, BUY, FORGE, BIND RUNE, RESUME, DONE, BEGIN, TO CAMP, CLOSE (dev), SWITCH.
- SECONDARY (blue): RESTOCK, LEAVE, SETTINGS, CLOSE (inspector), AUTO SETTINGS, KEEP PLAYING, CHECK, the toggle chips when off.
- DANGER (red): ABANDON RUN, ABANDON.
- GHOST: SKIP (forge), the inspector arrows. **[LEAD]** The lead's list has no ghost. I propose `Buttons/Flat/Square/1. Grey/button-square-flat-2.5-grey-darker` at alpha 0.8.
- ROUND icon-only (inspector arrows, the results home button): `Buttons/3D/Round/.../button-round-3d-1-*`.
- **Toggle chips** (1× 2× 4×, 90/100/115/130 %, STABLE/BETA, RAISE/MIRROR): toggle-on = PRIMARY yellow, off = SECONDARY blue (current behaviour). These chips are 84 tall and 60–90 wide, so use the **square 3D "1" aspect** art (9-sliced), not 2.5, to keep the corner radius. On the Settings UI-size row there are 4 chips + icon + label in 536 px of content. Check that "130%" at 24 px still fits once the 9/9/9/19 slices add ≈ 6 px per chip (§3).

### 2.3 Icons
All icons come from `vector-icon-pack-pro`, in the full-colour **`<Name> Outline.svg`** variant (the lead's default). The only exception is `potion_empty`, which uses Flat White because it is a dimmed silhouette. Every path below exists; I verified each file. The rendered sheet is `scratchpad/ui-plan/c/icon_candidates.png`.

Notes for the map:
- The pack has **no chest icon with a colour variant** in the Vector pack (`Items/Chest` has only Flat Black / Flat White). The candidates use the UI pack's bonus `[THANK YOU!] Icons/Chest 2` SVGs **[LEAD: allowed, since the rule is "every icon from the Vector packs"?]**. Otherwise use `Items/Chest/Chest Flat White.svg` tinted gold.
- There is no cape icon (`cape` → Sweater) and no mirror icon (`mirror` → Shield Mirror; alt `UI/Double Arrows`) **[LEAD]**.
- `rune_vampire` and `passive_bloodthirst` both want "blood", so bloodthirst takes the Scythe. `affix_armored` and `armor` share the chestplate, and `affix_thorned` and `passive_thorns` share the cactus. Sharing is fine (same rule), unless the lead wants them unique.
- `General/Eye` has a lowercase file name (`eye Blue Outline.svg`), so `UiSvg.sanitize` must keep that path working (it lowercases anyway).
- The Flat White SVGs use `fill:#fff`, not `#FFFFFF`. Legacy `UiIcons.TINT_SLOT` will not match them. This is for the foundation's `UiSvg.recolor` (it probably already handles it).
- **`3d:` ids** (`3d:coins`, `3d:potion_red`, `3d:chest_gems` in shop / event / Counter): the foundation's `Icons.texture()` always routes `3d:` to the rendered 3D prop, so the map cannot override them. Proposal: the map gets entries keyed by the `3d:` id and `Icons` consults the map first **[FOUNDATION]**. The fallback is renaming the call sites to `coins` / `potion_red` / `chest_gems`.
- New id **`sigil`**: Sigils are drawn today as `star` tinted violet (`CampUi.SIGIL_ICON`). With full-colour icons the tint is ignored, so Sigils would become a gold star, the same as the Minigames line. The proposal is `sigil` → `Currency/Star Gem/Star Gem Purple Outline.svg`, which needs `CampUi.SIGIL_ICON = "sigil"` (area d file).
- Tint semantics: full-colour icons ignore caller tints. Call sites in my area that *mean* something through the tint: the route-strip `check` (HEAL green: fine, the Check Mark is green); goal heads tinted `g.color` (fine, the icon itself identifies the goal); Medallion tints (move the colour to the medallion disc, not the glyph); the settings row icons tinted GOLD (lost, which is fine). `potion_*` icons are passed `Color.WHITE` explicitly; that also becomes a no-op.

Candidate map (paste into `ui/icons/icon_map.json` as `{"svg": <path>, "tint": null}`):

#### Runes

| id | candidate SVG (relative to `third_party/`) | meaning / note |
|---|---|---|
| `rune_blade` | `rhosgfx/vector-icon-pack-pro/Weapons/Sword/Sword Outline.svg` | combo bonus dmg |
| `rune_guard` | `rhosgfx/vector-icon-pack-pro/Weapons/Shield/Shield Blue Outline.svg` | block |
| `rune_venom` | `rhosgfx/vector-icon-pack-pro/Tools/Poison/Poison Outline.svg` | poison |
| `rune_gilded` | `rhosgfx/vector-icon-pack-pro/Currency/Coin/Coin Outline.svg` | gold |
| `rune_heavy` | `rhosgfx/vector-icon-pack-pro/Sports/Kettlebell/Kettlebell Outline.svg` | double pips |
| `rune_ember` | `rhosgfx/vector-icon-pack-pro/Nature/Fire/Fire Outline.svg` | fire to all |
| `rune_vampire` | `rhosgfx/vector-icon-pack-pro/Materials/Blood/Blood Outline.svg` | lifesteal |
| `rune_lucky` | `rhosgfx/vector-icon-pack-pro/General/Luck/Luck Outline.svg` | clover |
| `rune_frost` | `rhosgfx/vector-icon-pack-pro/Nature/Snowflake/Snowflake Outline.svg` | skip action |
| `rune_thunder` | `rhosgfx/vector-icon-pack-pro/General/Lightning Bolt/Lightning Bolt Yellow Outline.svg` | reroll zap |
| `rune_echo` | `rhosgfx/vector-icon-pack-pro/UI/Sound/Sound Outline.svg` | echo waves (alt Music/Tuning Fork) |
| `rune_wild` | `rhosgfx/vector-icon-pack-pro/Currency/Star Gem/Star Gem Outline.svg` | wildcard (alt General/Sparkle) |

The rune glyphs also sit inside `RuneBadge` sockets and on die faces (area b, dice). The **die-face rune glyph** is drawn small (≈ 20 px) on a coloured die body, where full-colour art can get muddy. The proposal is the `Flat White` variant of the same icon, tinted by the rune colour, for the die face only. **[LEAD]**

#### Passives

| id | candidate SVG (relative to `third_party/`) | meaning / note |
|---|---|---|
| `passive_pair_master` | `rhosgfx/vector-icon-pack-pro/Player/Friends 2/Friends 2 Outline.svg` | pairs |
| `passive_full_house_party` | `rhosgfx/vector-icon-pack-pro/General/Party Popper/Party Popper Outline.svg` | full house |
| `passive_straight_shooter` | `rhosgfx/vector-icon-pack-pro/Weapons/Bow/Bow Outline.svg` | straights |
| `passive_triple_threat` | `rhosgfx/vector-icon-pack-pro/Weapons/Trident/Trident Outline.svg` | 3-of-a-kind |
| `passive_snake_eyes` | `rhosgfx/vector-icon-pack-pro/General/Eye/eye Blue Outline.svg` | 1s |
| `passive_boxcars` | `rhosgfx/vector-icon-pack-pro/Transport/Steam Train/Steam Train Outline.svg` | 6s (boxcars) |
| `passive_gold_tooth` | `rhosgfx/vector-icon-pack-pro/Items/Teeth/Teeth Outline.svg` | gold on 6 |
| `passive_steady_hand` | `rhosgfx/vector-icon-pack-pro/Player/Hand/Hand Outline.svg` | kept dice |
| `passive_loaded_hands` | `rhosgfx/vector-icon-pack-pro/Player/Fist/Fist Outline.svg` | first-turn reroll |
| `passive_double_trouble` | `rhosgfx/vector-icon-pack-pro/Shapes/Gaming Dice/D6 Outline.svg` | doubles bank |
| `passive_rune_echo` | `rhosgfx/vector-icon-pack-pro/Music/Tuning Fork/Tuning Fork Outline.svg` | runes twice 25% |
| `passive_collector` | `rhosgfx/vector-icon-pack-pro/Items/Storage Box/Storage Box Outline.svg` | HP per rune |
| `passive_pathfinder` | `rhosgfx/vector-icon-pack-pro/Tools/Compass/Compass Outline.svg` | board reroll |
| `passive_treasure_sense` | `rhosgfx/vector-icon-pack-pro/Tools/Magnifying Glass/Magnifying Glass Outline.svg` | chests |
| `passive_piggy_bank` | `rhosgfx/vector-icon-pack-pro/Items/Piggy Bank/Piggy Bank Outline.svg` | interest |
| `passive_haggler` | `rhosgfx/vector-icon-pack-pro/General/Tag/Tag Outline.svg` | discount |
| `passive_scholar` | `rhosgfx/vector-icon-pack-pro/Items/Book/Book Outline.svg` | XP |
| `passive_blacksmith` | `rhosgfx/vector-icon-pack-pro/Tools/Hammer/Hammer Outline.svg` | forge x2 |
| `passive_thorns` | `rhosgfx/vector-icon-pack-pro/Nature/Cactus/Cactus Outline.svg` | thorns |
| `passive_iron_skin` | `rhosgfx/vector-icon-pack-pro/Weapons/Shield/Shield Silver Outline.svg` | block |
| `passive_bloodthirst` | `rhosgfx/vector-icon-pack-pro/Weapons/Scythe/Scythe Outline.svg` | heal on kill |
| `passive_opening_salvo` | `rhosgfx/vector-icon-pack-pro/Weapons/Dynamite/Dynamite Outline.svg` | first attack |
| `passive_second_wind` | `rhosgfx/vector-icon-pack-pro/General/Revive/Revive Outline.svg` | survive once |
| `passive_glass_cannon` | `rhosgfx/vector-icon-pack-pro/Weapons/Bomb/Bomb Outline.svg` | glass cannon |
| `passive_extra_hand` | `rhosgfx/vector-icon-pack-pro/Player/Hand 2/Hand 2 Yellow Outline.svg` | 6th die |
| `passive_crowd_pleaser` | `rhosgfx/vector-icon-pack-pro/General/Applause/Applause Outline.svg` | pair->3oak |
| `passive_encore` | `rhosgfx/vector-icon-pack-pro/UI/Redo/Redo Outline.svg` | refund reroll |
| `passive_rune_bloom` | `rhosgfx/vector-icon-pack-pro/Nature/Flower/Flower Outline.svg` | runes everywhere |
| `passive_fast_feet` | `rhosgfx/vector-icon-pack-pro/Player/Run/Run Outline.svg` | hop again |
| `passive_resonance` | `rhosgfx/vector-icon-pack-pro/Music/Cymbal/Cymbal Outline.svg` | runes twice |
| `passive_phoenix` | `rhosgfx/vector-icon-pack-pro/Items/Feather/Feather Outline.svg` | phoenix feather |
| `passive_midas_fist` | `rhosgfx/vector-icon-pack-pro/Player/Strong Arm/Strong Arm Outline.svg` | gold dmg |

#### Shared glyphs (upgrade types, reward types, currencies, events, buttons, settings, slots)

| id | candidate SVG (relative to `third_party/`) | meaning / note |
|---|---|---|
| `dice` | `rhosgfx/vector-icon-pack-pro/Items/Dice/Dice Outline.svg` | upgrade: new die; unlock kind: packs |
| `heart` | `rhosgfx/vector-icon-pack-pro/General/Heart/Heart Outline.svg` | upgrade: max HP |
| `reroll` | `rhosgfx/vector-icon-pack-pro/General/Rebirth/Rebirth Outline.svg` | upgrade: combat reroll (alt UI/Redo) |
| `anvil` | `rhosgfx/vector-icon-pack-pro/Tools/Anvil/Anvil Outline.svg` | upgrade: face raise; forge; gear unlocks |
| `coin` | `rhosgfx/vector-icon-pack-pro/Currency/Coin/Coin Outline.svg` | currency: gold; Crowns line "leftover gold" |
| `3d:coins` | `rhosgfx/vector-icon-pack-pro/Currency/Coin Stack/Coin Stack Gold Outline.svg` | gold pile (shop counter, event gold) |
| `crown` | `rhosgfx/vector-icon-pack-pro/Clothing/Crown/Crown Outline.svg` | currency: Crowns; unlock kind: final bosses |
| `sigil` (new) | `rhosgfx/vector-icon-pack-pro/Currency/Star Gem/Star Gem Purple Outline.svg` | currency: Sigils (was `star` tinted violet) |
| `xp` | `rhosgfx/vector-icon-pack-pro/General/XP/XP Purple Outline.svg` | XP |
| `star` | `rhosgfx/vector-icon-pack-pro/General/Star/Star Outline.svg` | generic; Crowns line "minigames" |
| `flag` | `rhosgfx/vector-icon-pack-pro/Items/Flag/Flag Outline.svg` | Crowns line "laps"; abandon |
| `portal` | `rhosgfx/vector-icon-pack-pro/Transport/Portal/Portal Purple Outline.svg` | Crowns line "biomes"; portal banner |
| `skull` | `rhosgfx/vector-icon-pack-pro/General/Skull/Skull Outline.svg` | Crowns line "mini-boss"; unlock kind: mini-bosses; ascension |
| `trophy` | `rhosgfx/vector-icon-pack-pro/General/Trophy/Trophy Outline.svg` | Crowns line "final boss" |
| `up` | `rhosgfx/vector-icon-pack-pro/General/Upgrade/Upgrade Outline.svg` | Crowns line "bonus"; RAISE +1 |
| `mirror` | `rhosgfx/vector-icon-pack-pro/Weapons/Shield/Shield Mirror Outline.svg` | MIRROR op (no mirror icon; alt UI/Double Arrows) |
| `sword` | `rhosgfx/vector-icon-pack-pro/Weapons/Sword/Sword Outline.svg` | ATK blessing; weapon slot |
| `curse` | `rhosgfx/vector-icon-pack-pro/General/Horned Skull/Horned Skull Red Outline.svg` | idol event; cursed face |
| `ore` | `rhosgfx/vector-icon-pack-pro/Materials/Ore/Ore Amethyst Outline.svg` | ore vein event art |
| `campfire` | `rhosgfx/vector-icon-pack-pro/Items/Bonfire/Bonfire Outline.svg` | Last Camp art; TO CAMP |
| `chest` | `rhosgfx/cartoony-ui-pack-full/[THANK YOU!] Icons/Chest 2/Chest Medium 2 Outline.svg` | chest (UI-pack bonus icon, see notes) |
| `3d:chest_gems` | `rhosgfx/cartoony-ui-pack-full/[THANK YOU!] Icons/Chest 2/Chest Large 2 Outline.svg` | garden choice |
| `gear` | `rhosgfx/vector-icon-pack-pro/General/Settings/Gear Outline.svg` | SETTINGS; auto-update; dev |
| `speaker` | `rhosgfx/vector-icon-pack-pro/UI/Sound/Sound Outline.svg` | master volume |
| `music` | `rhosgfx/vector-icon-pack-pro/UI/Music/Music Outline.svg` | music volume |
| `bolt` | `rhosgfx/vector-icon-pack-pro/General/Lightning Bolt/Lightning Bolt Outline.svg` | sfx volume |
| `speed` | `rhosgfx/vector-icon-pack-pro/UI/Skip Forward/Skip Forward Outline.svg` | game speed |
| `plus` | `rhosgfx/vector-icon-pack-pro/UI/Arrows Expand/Arrows Expand Outline.svg` | UI size row (the id is also "features" unlocks; split to `ui_size` if the lead wants `plus` literal) |
| `auto` | `rhosgfx/vector-icon-pack-pro/UI/Recycle/Recycle Outline.svg` | AUTO SETTINGS |
| `check` | `rhosgfx/vector-icon-pack-pro/UI/Check Mark/Check Mark Outline.svg` | TAKE / BIND / DONE / beaten stops |
| `close` | `rhosgfx/vector-icon-pack-pro/UI/X/X Outline.svg` | CLOSE |
| `arrow_right` | `rhosgfx/vector-icon-pack-pro/UI/Arrow/Arrow Right Outline.svg` | LEAVE / RESUME / BEGIN / route arrows |
| `arrow_left` | `rhosgfx/vector-icon-pack-pro/UI/Arrow/Arrow Left Outline.svg` | inspector prev |
| `home` | `rhosgfx/vector-icon-pack-pro/General/Home/Home Outline.svg` | results: title |
| `wardrobe` | `rhosgfx/vector-icon-pack-pro/Clothing/Shirt/Shirt Outline.svg` | NEW SKIN kicker |
| `question` | `rhosgfx/vector-icon-pack-pro/UI/Question Mark/Question Mark Outline.svg` | secret-class goal |
| `pouch` | `rhosgfx/vector-icon-pack-pro/Items/Pouch/Pouch Outline.svg` | slot trinket2 |
| `ring` | `rhosgfx/vector-icon-pack-pro/Clothing/Ring/Ring Outline.svg` | slot trinket |
| `helmet` | `rhosgfx/vector-icon-pack-pro/Clothing/Armor Helmet/Armor Helmet Outline.svg` | slot head |
| `armor` | `rhosgfx/vector-icon-pack-pro/Clothing/Armor Chestplate/Armor Chestplate Outline.svg` | slot body |
| `shield` | `rhosgfx/vector-icon-pack-pro/Weapons/Shield/Shield Outline.svg` | slot offhand |
| `cape` | `rhosgfx/vector-icon-pack-pro/Clothing/Sweater/Sweater Outline.svg` | slot back (no cape icon) |

#### Potions

| id | candidate SVG (relative to `third_party/`) | meaning / note |
|---|---|---|
| `3d:potion_red` | `rhosgfx/vector-icon-pack-pro/Tools/Potion 1/Potion 1 Pink Outline.svg` | shop potion (untyped) |
| `potion` | `rhosgfx/vector-icon-pack-pro/Tools/Potion 1/Potion Outline.svg` | unlock kind: potions |
| `potion_healing` | `rhosgfx/vector-icon-pack-pro/Tools/Potion 1/Potion 1 Pink Outline.svg` | healing (MetaHud colour ff7a86) |
| `potion_stoneskin` | `rhosgfx/vector-icon-pack-pro/Tools/Potion 2/Potion 2 White Outline.svg` | stoneskin (b8c6dc) |
| `potion_reroll_tonic` | `rhosgfx/vector-icon-pack-pro/Tools/Potion 3/Potion 3 Yellow Outline.svg` | reroll tonic (ffc24a) |
| `potion_cleanse` | `rhosgfx/vector-icon-pack-pro/Tools/Potion 1/Potion 1 Blue Outline.svg` | cleanse (7fe0ff) |
| `potion_empty` | `rhosgfx/vector-icon-pack-pro/Tools/Potion 1/Potion Flat White.svg` | empty belt slot (tint dim) |

#### Affixes (first-encounter cards, affix tooltips, HUD badges)

| id | candidate SVG (relative to `third_party/`) | meaning / note |
|---|---|---|
| `affix_armored` | `rhosgfx/vector-icon-pack-pro/Clothing/Armor Chestplate/Armor Chestplate Outline.svg` | armored |
| `affix_thorned` | `rhosgfx/vector-icon-pack-pro/Nature/Cactus/Cactus Outline.svg` | thorned |
| `affix_warded` | `rhosgfx/vector-icon-pack-pro/Weapons/Overshield/OvershieldBlue Outline.svg` | warded |
| `affix_piercing` | `rhosgfx/vector-icon-pack-pro/Weapons/Spear/Spear Outline.svg` | piercing |
| `affix_frenzied` | `rhosgfx/vector-icon-pack-pro/General/Fight Cloud/Fight Cloud Outline.svg` | frenzied |
| `affix_regenerating` | `rhosgfx/vector-icon-pack-pro/Nature/Sprout/Sprout Outline.svg` | regenerating |
| `affix_vampiric` | `rhosgfx/vector-icon-pack-pro/Holiday/Bat/Bat Outline.svg` | vampiric |
| `affix_hexing` | `rhosgfx/vector-icon-pack-pro/Items/Crystal Ball/Crystal Ball Purple Outline.svg` | hexing |
| `affix_frostbound` | `rhosgfx/vector-icon-pack-pro/Materials/Ice/Ice Outline.svg` | frostbound |
| `affix_gilded` | `rhosgfx/vector-icon-pack-pro/Currency/Ingots/Gold Outline.svg` | gilded |

#### Unlock kinds and goals (results "Unlocked!" and "Nearest goals")
`CampInfo.icon_of(kind, id)` (area d file) resolves them. The ids are covered above or by other areas:
classes → `class_*` (area d / class select), biomes → `biome_*` (area b / route strip), bosses → `crown`, minibosses → `skull`, pets → `CampInfo.PET_ICON` (today `heart`/`skull`/`flame`/...; **proposal:** switch to the `pet_*` ids the pet area maps), minigames → `CampInfo.MINIGAME_ICON` (area e), packs → `dice`, gear → `sword`/`shield`/`armor`/`ring`, items → slot icons above, potions → `potion`, features → `plus`, ascension card → `skull`, secret goal → `question`, crowns goal → `crown`.

---

## 3. Content-density risks

Canvas facts: the project is 720×1280 with `canvas_items` / `expand`. Phones have a 720-wide logical canvas. The iPhone 17 (402×874 pt) is 720×1565 logical. The **Duo outer** (466×678) is **720×1048** logical, with safe insets of ≈ 91 top and 52 bottom, which leaves ≈ 905 px. **1366×768** is 2277×1280 logical (height-bound). At **125 % zoom** (`--ui-scale=1.25` / UI size 125 %), 1366×768 becomes ≈ 1821×1024 and an iPhone becomes **576×1252**, narrower than `UiModal.MIN_W` (620), so the frame scales down via `_fit`.

### 3.1 What thicker frames cost (measured from the code, logical px)
| surface | now | proposed | delta |
|---|---|---|---|
| modal panel content margin (L/T/R/B) | 32/28/32/28 | Nailed @0.75: 18/20/18/26 + 12 inner = 30/32/30/38 (@1.0: 36/39/36/46) | @0.75: −4 width, **+14 height**; @1.0: +8 width, +29 height |
| title (ribbon → plaque) | 38×1.75 = 66.5 tall, overlaps 26 | plaque 76 tall at 1.25 (bottom lip 19×1.25) | +10 |
| card (OptionCard / CampUi.card) | pad 18–20, border 2 | Container 3D @0.9: 13.5/13.5/13.5/22.5 + ~6 = 20/20/20/29 | **+11 per card** (the 3D bottom lip) |
| button (GameButton) | min 88, depth 8 | 3D square: lip 19×scale; at ~1.0 about +11 | +5..+11 per button (slice a) |
| inset (Crowns table) | 16/12 | Container Flat 10 + 6 = 16/16 | +8 |
| tooltip | pad 16/10 | Thin @0.3 = 6.6 + 10 = 17/17 | +14 height |

On the phone this means:
- **Draft / passive / event / shop:** about +14 (panel) +10 (plaque) +33 (3 cards) +10 (button), so **≈ +65 px** on a 1565-tall canvas. That is fine on iPhone. On the **Duo outer** (905 px available) the shop with 5 items plus the die picker already scrolls today; +90 px only means more scrolling. The draft (≈ 640 px today) stays unscrolled.
- **Pause:** today it fits the Duo outer without scrolling (see `before/zoom_game_pause/game_pause__duo_outer.png`). +14 +10 + 3 buttons × ~8 comes to ≈ +50 px. It still fits, but it is within ≈ 60 px of the point where `UiModal` starts the 0.8 shrink. With loadout and passives present (`ui_pause_loadout`, 2 extra rows) it will shrink on the Duo outer and on iPhone at 125 %. Mitigation: the passives row and the kit names line (16 px) sit in one row; the kit strip thumbs go 58 → 52 when `size.y < 1100`.
- **Results:** the long case (`game_victory`: 5 unlock cards + firsts + goals, about 12 cards). Every card gains +11 and the Crowns inset +8, so the scroll content grows **≈ +150 px** (≈ +8 %). On the Duo outer the visible scroll window is ≈ 905 − footer 138 − plaque/chrome ≈ 60 = **≈ 700 px, about 25 px less than today**. That is acceptable, because results is designed to scroll (footer outside). Keep the scale-0.75 frame on phones; 1.0 would cost another ≈ 15 px of the viewport.
- **Settings:** the UI-size row has an icon (40) + "UI size" (30 Lilita, about 110) + 4 chips. Today each chip is 20 pad + label ≈ 72 wide, with separation 10. The 3D art adds ≈ 4 px of side slice per chip, so the row is ≈ 40 + 10 + 110 + 4 × 80 + 40 = **520 of 536 content px**. That is tight. On the iPhone at 125 % (576 canvas, frame scaled by `_fit`) it still fits, because the frame scales, not reflows. Mitigation if it wraps: chip font 24 → 22, or put the "%" in a smaller sub-label.
- **1366×768 and zoom:** the canvas is 1280 tall (1024 at 125 %), so no width risk. Modals are width-capped at 560–700, so the frame is never scaled. At 1366 @125 % the results window is ≈ 1024 − 150 = 870 of scroll, which is fine.
- **Zoom 150 % at 1080p:** 1280×720 logical, height-bound. Pause needs ≈ 700 natural, so the `UiModal` 0.8 shrink kicks in. That is fine, but the 3D plaque and frame textures are then drawn at 0.8. `DPITexture` re-rasterises, so they stay crisp; verify in the after-shots.
- **iPhone at 125 % (576 wide):** `UiModal` handles it with `_fit`, but **`SummaryScreen._layout()` does not** (the existing overflow bug above). The fix is required before the reskin: copy the `MIN_W` / `_fit` block into the summary's `_layout()`, keeping the footer outside the scroll.

### 3.2 Nine-slice and texture risks
- The **Nailed** frame's nails sit in the corners, so they stay put with 9-slice. The straight edges have plank seams, which **stretch**: use `axis: "tile_fit"` for H and V on `panel_modal` (the `UiSkin` `axis` key) so tall results panels don't smear the planks. Check at 1.0 and 0.75.
- **Container 3D** cards are 9-sliced with a 25-unit bottom lip. Very short cards (the firsts chips, ≈ 36 px tall) must use the flat round chip instead, never the 3D container.
- The **title plaque** as a 3D button looks like a button (tappable) on a modal header. The mockup shows it still reads as a title, but consider `Containers/3D` (no pressed-state look) as the plaque **[LEAD]**.
- **Scrim + navy fill:** the Nailed frame hole is transparent, so a navy fill layer must sit under it (expand −10 so it doesn't poke past the rounded outer edge). The lead writes "hole baked-filled"; `UiSkin` layers do exactly this.

### 3.3 Scrollbars and scroll regions
- Today there is a 12 px bar inside the panel's content rect. The panel content margin is the only gutter, so on results the bar sits 32 px inside the frame, next to the cards.
- **Proposal (slice a owns the theme; (c) owns the UiModal gutter):**
  - `VScrollBar` "scroll": `Containers/Flat/0. White/container-flat-white.svg` at 0.4 (radius 4), modulate `INK` α 0.5, width 12.
  - "grabber": `Containers/3D/9. Brown/container-3d-lightbrown-regular.svg` at 0.35 (wood, matching the Nailed frame); `grabber_highlight` and `grabber_pressed` use `-light`.
  - Minimum grab height 48. The pack's `Bars/Handles` are 24×28 slider knobs, too wide for a scroll grabber, and the `Bars/*` art is horizontal only (a `StyleBoxTexture` cannot rotate). A rotate key in `UiSkin` / `UiSvg.compose` would make a vertical Bars/Thin track possible **[FOUNDATION, optional]**.
- The `UiModal._scroll` gets a right gutter: set `_inner` margin right = 0 and instead `add_theme_constant_override` on the ScrollContainer, or keep the bar overlaying the Nailed frame's inner edge. Proposal: the bar sits in the frame's inner 18 px band (bars "embedded in the wood"), which saves 12 px of content width on phones.
- Scroll affordance: results relies on the fold. With the thicker frame, add a bottom fade (a gradient `TextureRect`, `NAVY` → transparent, 24 px) inside the frame hole when `_scroll` can scroll further. It is cheap and makes the cut-off readable.
- `ScrollContainer` panel stays `StyleBoxEmpty`. Mobile drag-scrolling is unchanged.

---

## 4. Implementation plan

### 4.0 Dependencies (must land first)
1. **Foundation** (`wp-ui-foundation`): `UiSvg`, `UiSkin`, `UiLayeredStyleBox`, `Icons`, and `tools/import_assets.sh` copying the referenced SVGs into `assets/ui/{pack,icons}/`. Requests from (c):
   - (a) the icon map may override `3d:` ids;
   - (b) a runtime colour on a skin stylebox: `modulate_color` on the returned duplicate is enough for single-layer pieces. Layered pieces need either a helper `UiSkin.stylebox_mod(piece, state, color, layer_idx)` or a documented way to reach `UiLayeredStyleBox.layers[i]`;
   - (c) optionally a `rotate` key for vertical bar art.
2. **Lead**: `ui/theme/ui_pack.json` with the pieces in §2.1 (names can change, but agree them), and `ui/icons/icon_map.json` including the ids in §2.3.
3. **Slice (a) theme**: the `GameButton` reskin (kinds → 3D square 2.5; ROUND → round 3D 1; GHOST decision; toggle chips on the square "1" art), the `UiTheme.get_theme()` Button / HSlider / VScrollBar / TooltipPanel entries, `UiTheme.panel_box()` kinds rerouted to `UiSkin` pieces ("main", "card", "card_hi", "inset", "pill", "tooltip"), and `Counter`. Much of (c) then changes "for free" via `panel_box`. The steps below cover only what `panel_box` does not reach (custom `_draw`s and inline `StyleBoxFlat`s).
4. **wp-preboss merged** before touching `event_modal.gd` and `draft_modal.gd` (it edits both).

### 4.1 Steps (each a reviewable commit, with before/after shots)
1. **Results layout fix** (independent, can go first): add the `MIN_W` / `_fit` shrink to `SummaryScreen._layout()`. Shoot `ui_results_win --ui-scale=1.25` on the iPhone.
2. **UiModal + Ribbon** (`ui/widgets/ui_modal.gd`, `ui/widgets/ribbon.gd`):
   - `panel` uses `UiSkin.stylebox("panel_modal")`; the chrome computation already reads the stylebox content margins.
   - The -26 overlap becomes `-(plaque lip)`.
   - `Ribbon._draw` draws `title_plaque` (modulated by `color`) plus the same Lilita text with outline; keep `Ribbon.make` / `.color` / `.text`.
   - Scroll gutter and bottom fade (§3.3).
   - Pick the frame scale by canvas (0.75 when `size.x < 1000` logical) **[LEAD]**.
   - Shoot every modal scenario (they all move).
3. **OptionCard + Medallion** (`ui/widgets/option_card.gd`):
   - `_draw` → `draw_style_box(UiSkin.stylebox("card"|"card_hi"))`, then the accent overlay (`card_accent`, modulate) or the premium Ornate overlay.
   - Tag → `chip`; price → `price_pill`; SOLD stays a label.
   - `Medallion._draw` → `medallion` texture modulated by the ring, with the icon from `Icons.tex` (full colour).
   - Keep the hover lighten (modulate).
   - Consumers: draft, passive, shop, event, results, and the camp (area d) medallions.
4. **DieChip / forge `_DieTab` / `_FaceButton` selected ring** → `card` / `card_hi` pieces (`ui/widgets/die_chip.gd`, `ui/modals/forge_modal.gd`). The forge preview uses the `inset` panel (via `panel_box` once slice (a) lands).
5. **Per-modal inline styles:**
   - Event: the camp "RESTED" pill → `chip` HEAL; the rim colour → plaque modulate and card accent.
   - Die inspector: rarity tag → `chip`.
   - Portal banner: `portal_banner` piece.
   - Rune assign: hero → `inset`.
   - Dev menu: build list → `inset`; channel chips → toggle chips.
   - Pause: nothing inline (buttons and route strip only).
6. **Settings:**
   - volume sliders via the theme (slice a), or `UiSkin.apply_slider(s, "slider")` locally if (a) keeps sliders flat;
   - auto-update ON/OFF → `toggle` art (a `CheckButton` with `apply_toggle`), keeping `Updater` calls;
   - speed and UI-size chips on the square-1 art;
   - verify the UI-size row width at 100 % and 125 % (§3.1).
7. **Results body** (`ui/screens/summary_screen.gd`):
   - Crowns inset: `inset`; the separator `ColorRect` becomes a wood line (`container-3d-lightbrown` at 2 px, or keep `GOLD_FAINT`).
   - First chips → `chip` with the sigil modulate.
   - The home button → ROUND; `_skin_card` / `_asc_card` / unlock cards through `CampUi.card` (area d). If (d) hasn't landed, use a local `UiSkin` override so results isn't blocked.
   - Goals bars through `CampUi.bar` (d).
8. **Tooltips:** add `ui/widgets/ui_tooltip.gd` (`UiTooltip.box(accent: Color) -> StyleBox` and `UiTooltip.fill(panel, title, tag, body, accent, status)`) and switch the 3 copies to it:
   - `hud_top.gd` `_text_tip` (area b file);
   - `meta_hud.gd` `_show_tip` (area b file);
   - `affix_tips.gd` `show_tip`;
   - plus theme `TooltipPanel` (slice a).
9. **Toasts / popups / passive card / item pop** (`game/flow/overlay.gd`): `toast()` → `pill` piece; `passive_card()` → `card` + `card_accent` rarity; `item_pop()` → `tooltip` piece with the item colour; `mini_dice()` → `panel_modal`. Leave `announce` / `boss_card` / `biome_card` to area (b) **[LEAD: confirm the split]**.
10. **Encounter cards** (`game/enemies/encounter_cards.gd`): `encounter_card` piece modulated by the affix / enemy colour; caption icon via `Icons.rect`.
11. **Icons migration:** rename `UiIcons.rect/tex/exists/class_icon/biome_icon/...` → `Icons.*` in every file I own. The grep list is `ui/modals/*`, `ui/screens/summary_screen.gd`, `ui/widgets/{option_card,die_chip,route_strip,counter}.gd`, `game/flow/overlay.gd`, `game/enemies/{encounter_cards,affix_tips}.gd`. Then:
    - replace `CampUi.SIGIL_ICON` → `sigil` (d);
    - drop GOLD / WHITE tints that no longer matter;
    - for full-colour icons that sat on a tinted disc (medallions), move the colour to the disc.
12. **Pre-boss camp:** after wp-preboss merges, give the camp event its own plaque colour (camp orange), `campfire` art, the RESTED chip, and the choice icons (`potion_healing`, `rune_wild`, `reroll`), plus the draft `"camp"` source (title "BY THE FIRE"). This needs no extra work beyond steps 2–5, but must be shot.

### 4.2 File overlaps with other areas
| file | overlap | proposal |
|---|---|---|
| `ui/widgets/ui_modal.gd`, `ribbon.gd` | base of camp modals (area d) and minigame modals (e) too | (c) owns and lands it early; (d)/(e) inherit **[LEAD]** |
| `ui/widgets/option_card.gd` (`Medallion`) | camp (d) and class select use `OptionCard.Medallion` | (c) owns |
| `ui/widgets/game_button.gd`, `counter.gd`, `ui/theme/ui_theme.gd` | everyone | slice (a) owns; (c) only consumes |
| `ui/camp/camp_ui.gd` (`card`, `bar`, `sigils`, `SIGIL_ICON`), `ui/camp/camp_info.gd` (icon maps) | results depend on them | area (d) owns; (c) asks for `card`/`bar` on `UiSkin` pieces and `SIGIL_ICON = "sigil"` |
| `ui/widgets/hud_top.gd`, `ui/hud/meta_hud.gd` | tooltips live in HUD files | (c) provides `UiTooltip`; (b) swaps the two call sites (or (c) does it with (b)'s OK) |
| `game/flow/overlay.gd` | toasts (c) vs announce / boss / biome cards (b) | split by function |
| `ui/widgets/route_strip.gd`, `kit_strip.gd`, `passive_icon.gd`, `rune_badge.gd`, `die_face.gd`, `item_thumb.gd` | shared with HUD / camp / dice | owners: route/kit strip → (c) (pause, results, route card are the main users); passive icon / rune badge / die face → (b) |
| `ui/modals/dev_menu.gd` | area (a) shot it too | (c) listed it; decide the owner **[LEAD]** |
| `ui/modals/event_modal.gd`, `draft_modal.gd` | wp-preboss edits both | rebase after preboss |
| `ui/icons/icon_map.json`, `ui/theme/ui_pack.json` | lead-owned | (c) sends rows (§2) |

---

## 5. Test plan

Commands (background, never windowed; `--wait=10` for `game_*`):
```
tools/shoot_matrix.sh <scenario> <out>/<scenario> quick --wait=10
tools/shoot_matrix.sh <scenario> <out>/zoom_<scenario> zoom --wait=10
tools/shoot_matrix.sh <scenario> <out>/zoom_<scenario> duo --wait=10
./tests/run.sh
```

Scenarios (the before set is already shot, see the path at the top):
| group | scenarios | sets |
|---|---|---|
| draft / rewards | `game_draft`, `ui_rune_choice`, `game_passive --source=boss` (premium frame), `game_passive --source=elite` | quick |
| shop | `game_shop`, `ui_shop_pick` (die picker) | quick + duo |
| forge | `game_forge`, `ui_forge` | quick |
| events | `game_event`, `ui_event_duel`, `twist_ore --wait=12`, `game_last_camp` (after wp-preboss merges) | quick |
| rune / inspector | `ui_rune_assign`, `game_die_inspect` | quick |
| pause | `game_pause`, `ui_pause_loadout` (fix the scenario first: black on phones) | quick + zoom + duo |
| settings | `ui_settings` (UI-size row width!), `ui_auto_settings` | quick + zoom + duo |
| dev | `dev_menu`, `dev_menu_confirm` | quick |
| route / portal | `route_card`, `game_portal` | quick |
| results | `game_victory` (longest list), `game_defeat`, `ui_results_win`, `ui_results_loss` (milestone cards), `ui_results_items`, `ui_results_skins`, `ui_mk_reveal --frames=6` | quick + zoom + duo; also `ui_results_win --ui-scale=1.25` at 402×874 (overflow fix) |
| tooltips | `hud_potions --tip=0 --wait=6`, `elite_affixed` (affix tip 0:0), `game_board --passives=4` + passive tip | quick |
| encounter / toasts | `elite_affix_card`, `level_up_auto --frames=8`, `events_misc`, `run_item_triggered` | quick |

Recommended additions:
- a **`ui_tips`** scenario that holds all four tooltip kinds plus a toast and a popup on one screen (no timing race), so tooltips and toasts are reviewable in one shot.
- a headless test `tests/test_icon_map_c.gd` that asserts every icon id the (c) files use (the constants in `draft_modal`, `shop_modal`, `event_modal`, `summary_screen.LINES`, `CampInfo` icon maps, `Passives.DEFS`, `Runes.DEFS`, `SkinRules.AFFIXES`) is in `icon_map.json`, and that its SVG is imported when the pack is present. It skips when absent, like the foundation's fallback.

Acceptance checks on the after-shots:
- no text clipped or wrapped in the UI-size row;
- results footer never overlaps content, and the scroll bottom fade is visible on Duo outer and iPhone;
- the plaque is centred and not cut off by the safe area on duo_outer (top inset 0.087);
- the Nailed planks don't smear on the tall results panel (`tile_fit`);
- premium, selected and accent card states are distinguishable in greyscale (rarity is not colour-only: tag text stays);
- no `UiIcons: missing icon` / `UiSkin: unknown piece` warnings in the shot logs;
- 1080p @150 % and 1366 @125 % stay crisp (DPITexture).

Review artefact: put before/after pairs in one gallery page for Vlad (per the "show review artifacts" preference), per scenario × device.
