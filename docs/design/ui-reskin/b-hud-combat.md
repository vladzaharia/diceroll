# UI reskin, area (b): in-run HUD, combat and dice tray

Status: plan (2026-09-30). Planner only; no code changed. An engineer implements it after
the theme slice (area a) and the foundation APIs (`Icons`, `UiSkin`, `UiSvg`) land.

This plan follows these sources:

- Lead draft `docs/design/2026-09-30-ui-reskin.md` (branch `wp-ui-design`, commit ef8b01f):
  - "Night navy + wood" look;
  - `<Name> Outline.svg` icons by default, `Flat White` only for tinted glyphs of 24 px or less;
  - 3D Square 2.5 buttons; `Buttons/Flat/Round 2.5` pills; `Bars/Regular` bars;
  - die kind marks stay procedural.
- Lead icon map `ui/icons/icon_map.json` (uncommitted draft in the `wp-ui-design` worktree; 388 ids).
- Foundation, work in progress (`wp-ui-foundation`, uncommitted):
  - `Icons.texture/tex/rect` in `ui/icons/icon_registry.gd`;
  - `UiSkin.stylebox/apply_*` in `ui/theme/ui_skin.gd`;
  - `UiSvg.raster/recolor/make_texture` in `ui/theme/ui_svg.gd`;
  - `UiLayeredStyleBox`.
- Area (a) plan `docs/design/ui-reskin/a-theme-controls.md` (`origin/wp-ui-plan-a`). It provides these factories:
  - `panel_box(kind, accent)`, `callout_box(rim)`, `chip_box`;
  - `bar_boxes(kind)`, `toast_box()`;
  - the skinned `GameButton`, `StatBar` and `Counter`.
- Pre-boss finale (`wp-preboss`, uncommitted). See §1g.

Where the lead has not decided, this doc marks the item **PROPOSAL (lead)**.

Before shots and contact sheets are in the session scratchpad (not committed, since they show pack art):
`/private/tmp/claude-501/-Users-vlad-Repos-diceroll/1bba73af-2ee7-40a8-8c95-50839b8aed16/scratchpad/ui-plan/b/`

| What | Path under that dir |
|---|---|
| 20 scenarios × quick matrix (+ zoom, duo) | `before/<scenario>/*.png` |
| Per-scenario strips | `sheets/<scenario>.png` |
| Candidate icons (outline / flat-on-disc / 28 px / alternate) | `icon_candidates_b.png` |
| World badge style comparison (A / B / C, see §3) | `world_badge_options.png` |
| UI pack pieces overview | `ui_pack_sheet.png` |

---

## 1. Inventory

The line numbers are for `origin/main` @ 6969723.

"Drawn" is how the element renders today:

- **Ctl**: Control/Label nodes.
- **SBF**: `UiTheme.box`/`panel_box` StyleBoxFlat.
- **_draw**: custom CanvasItem drawing.
- **shader2D**: canvas_item shader.
- **shader3D**: spatial shader on a quad.
- **L3D**: Label3D.
- **mesh**: 3D mesh.
- **gen**: the icon is a `ui/icons/*.svg` produced by `ui/icons/gen_icons.py` (or `ui/hud/gen_hud_icons.py`) and rasterised by `UiIcons`.

Scenario keys (all shot, see §6):

| Key | Scenario |
|---|---|
| B | `game_board --passives=5` |
| R | `game_rolled` |
| C | `game_combat --cards=0` |
| C3 | the same with `--turns=3` |
| K | `game_combo` |
| E | `elite_affixed` |
| M | `twist_moon_meter` |
| MF | `fight_moon_king_moonfall` |
| SS | `fight_sand_colossus_sandstorm` |
| BO | `game_boss --act=1` |
| RC | `route_card` |
| P | `hud_potions --combat=1` |
| BOO | `class_moment --class=monster_kid --moment=boo` |
| BN | `class_moment --class=necromancer --moment=bone_die` |
| T | `class_moment --class=engineer --moment=turret` |
| D | `dice_kinds` |
| PO | `game_portal` |
| EV | `events_misc --only=item_triggered` |

### 1a. Top HUD (`ui/widgets/hud_top.gd`, shared by BoardHud and CombatHud)

| Element | file:line | Drawn | Icon id today | Scenarios |
|---|---|---|---|---|
| Scrim gradient behind the HUD | hud_top.gd:73-78, :225 | TextureRect gradient | none | all |
| Level medallion + XP ring | level_badge.gd:11, _draw :42-68 | _draw (circles, draw_string) | none | all |
| HP bar (ghost drain, value text) | hud_top.gd:92-94; stat_bar.gd:26, _draw :79-103 | _draw with SBF boxes | none | all |
| Heart over the HP bar end | hud_top.gd:95-97 | Ctl TextureRect | `heart` (gen) | all |
| Hero block shield + number | hud_top.gd:98-108, :480 | Ctl TextureRect + Label | `shield` (gen) | C, C3, BO |
| Hero burn badge + stacks | hud_top.gd:109-119, :300 | Ctl | `intent_burn` (gen, tinted) | Magma fights |
| Gold counter | hud_top.gd:124; counter.gd:18-28 | SBF `pill` + icon + Label | `3d:coins` (rendered PNG, glyph fallback `coin`) | all |
| Treasury counter (board only) | hud_top.gd:126 | SBF `pill` | `3d:chest` | B, R |
| Pause button | hud_top.gd:132-137 | GameButton ROUND GHOST | `pause` (gen) | all |
| Twist chip (moon / heat / drums / ore) | hud_top.gd:146-163, :523-588 | SBF `pill` (cast `as StyleBoxFlat` :584, border recoloured) | `sun`/`oasis`/`drum`/`ore` (gen); moon = `_MoonGlyph` _draw :655-676 | M, MF, SS, twist_* |
| Lap chip "LAP 6/15" + pips | hud_top.gd:139-171, :370-382, :503-514 | SBF `pill` (cast :379); `_Pip` _draw :679-705 (boss lap = red diamond) | none | all |
| Passives bar + tooltip | hud_top.gd:173-188, :416-471; passive_icon.gd _draw :61-86 | HFlow + _draw ring + gen glyph; tip = SBF :445 | `passive_*` (gen) | B (`--passives=5`) |
| Class badge (mechanic + live state) | class_badge.gd:25-44, :123 | SBF + Ctl | `mech_*` / `class_*` (gen) | all (BOO, BN, T show states) |
| Pet + potion strip (meta HUD) | meta_hud.gd:58 (strip), :323/:517 (potion slot, _draw :529), :593 (pet portrait, _draw :632-666), :336/:389/:449 (pops, tips) | SBF + _draw | `potion_*`, `pet_*` (gen_hud_icons.py, multi-colour) | P |
| Speed pill 1×/2×/4× | speed_pill.gd:60, _draw :100-121 | _draw (GameButton recipe) | `speed` (gen) | all |
| AUTO toggle | auto_button.gd:67, _draw :134-164 | _draw | `auto` (gen) | all |
| AUTO settings gear | auto_hud.gd:57 | GameButton ROUND | `gear` (gen) | all |
| AUTO ticker / stop card / highlight ring | auto_hud.gd:68-90, _draw :317-338 | SBF + _draw | `auto`, `pause` | `ui_speed_auto`, `game_auto` |

### 1b. Combat panel (`ui/screens/combat_hud.gd`) and combo splash

| Element | file:line | Drawn | Icon id today | Scenarios |
|---|---|---|---|---|
| Combo panel (COMBO caption, name, ×mult, class tag) | combat_hud.gd:52-73 | SBF `hud` + Labels | none | C, K, BOO, BN, T |
| Damage chip | combat_hud.gd:74-83 | SBF (dark red, own colours) | `sword` (gen) | C, K |
| Combo cheat-sheet button + popover | combat_hud.gd:84-91, :128-177 | GameButton ROUND GHOST toggle; sheet `panel_box("main")`, row highlight SBF :224 | `question` (gen) | `game_combat` + tap ? |
| Reroll pips | combat_hud.gd:230-235 | TextureRects | `reroll` (gen, gold / grey) | C |
| Tap-to-reroll hint | combat_hud.gd:100, :239-244 | Label | none | C |
| REROLL button (+ "2 left") | combat_hud.gd:106-111 | GameButton SECONDARY | `reroll` | C |
| ATTACK button | combat_hud.gd:112-118 | GameButton PRIMARY | `sword` | C |
| Combo splash (rays, name, ×mult, damage) | combo_banner.gd:23-48, `_Rays` _draw :149-161 | Ctl + _draw | none | K |
| Board ROLL / GO / REROLL + move pill ("5 + 5 = 10", DOUBLES) | board_hud.gd (bottom bar), toast :195-219 | GameButton + SBF `pill` | `dice`, `reroll`, toast `skull` | B, R |

### 1c. Dice tray and die faces

| Element | file:line | Drawn | Icon id today | Scenarios |
|---|---|---|---|---|
| Tray frame (walnut + gold inlay, inner shadow) | dice_tray.gd:80-84; `game/dice/frame.gdshader` | shader2D ColorRect | none | all |
| Felt | dice_tray.gd:148-153; `felt.gdshader` | shader3D in SubViewport (MSAA 4×, :69) | none | all |
| 3D die faces (pips, 7-9 numerals, blank, Wild star, **★ Pretend face**, kind corner mark, seed tag, gold rim) | `game/dice/die.gdshader` (star :187-221, `sd_kind` :136); die_visual.gd:130-196 | shader3D SDF | none | all; ★ in BOO / `star_board` |
| Bone die look | die_visual.gd:171-172 | shader3D uniforms | none | BN |
| Cursed / buried die: chains + padlock | die_visual.gd:202-259 | mesh | none | SS (bury), cursed faces |
| Marked glow ring / outline shell | `ring.gdshader`, `die_outline.gdshader` | shader3D | none | C |
| Class badge in the tray corner ("OATH 4", "BONE DIE RISES") | dice_tray.gd:203-243 (own StyleBoxFlat :225) | Label + SBF + icon | `mech_*` | BN, paladin oath |
| Turret die slot + "TURRET" label | dice_tray.gd:247-282, :353 | 3D DieVisual + Label | none | T |
| Die value labels (optional) | dice_tray.gd:44, :195 | Label | none | dice_tray scenarios |
| 2D DieFace (modals, previews, overlay mini dice) | die_face.gd _draw :109-181; kind mark :75-106 | _draw | star `star` :165, lock `curse` :179 | D, forge/shop/inspector (other areas) |
| DieChip (six mini faces) | die_chip.gd _draw :77 | _draw | rune glyph | forge / rune assign (area c) |

### 1d. World-space unit HUD (`game/world/unit_hud.gd`)

This is a Node3D billboard that is re-oriented every frame (`_process` :137-141). It is created in combat_stage.gd:230-233 at scale 1.0, or 1.1 for a miniboss and 1.2 for a boss.

| Element | file:line | Drawn | Icon today | Scenarios |
|---|---|---|---|---|
| HP bar (fill, ghost, shield frame, boss phase ticks) | unit_hud.gd:70-80; `hp_bar.gdshader` | shader3D SDF | none | C, E, M, BO |
| HP numbers "12/12" | unit_hud.gd:81-84 | L3D (font 52, outline 14) | none | all fights |
| Name plate (boss / miniboss) | unit_hud.gd:116-119 | L3D | none | M, MF, BO |
| Intent badge + value | unit_hud.gd:85-92, :200-214; `intent_icon.gdshader` (19 SDF kinds, :4-9, :71-176) | shader3D SDF glyph | *none*: `INTENT_KINDS` ints, not the `intent_*.svg` | all fights |
| Block badge + number | unit_hud.gd:93-102 | shader3D kind 1 + L3D | none | C (shield intents) |
| Trait chips (armor, thorns, ward, pierce) | unit_hud.gd:10, :277-302 | shader3D SDF kinds 13-16 | none (frenzy / ward_allies use affix glyphs, :21) | elite / trait foes |
| Affix badges (≤2, frenzy stacks) | unit_hud.gd:306-331, `affix_badge()` :347-357; `affix_badge.gdshader` | shader3D sampling `UiIcons.tex(icon, 96)` | `affix_*` (gen) | E |
| Board affix chips over fight tiles | affix_looks.gd:328-346 (billboard=1) | same shader | `affix_*` | `game_board --affixes=…` |
| Status line (POISON n, FROZEN, SPOOKED, FRENZY +n) | unit_hud.gd:103-105, :171-187 | L3D text only | none | C3, BOO |
| Scare badge (cower) + Brave chip | unit_hud.gd:106-115, :262-273 | affix_badge shader | `intent_cower`, `trait_brave` (gen) | BOO |
| Moon meter (disc, terminator fill, tide pips, blood) | unit_hud.gd:120-130, :219-234; `moon_meter.gdshader` | shader3D procedural | none | M, MF |
| Flash note "TIDE 2/4", "CLOUDS -1" | unit_hud.gd:131-134, :238-253; callers twist_beats.gd:224, :237 | L3D | none | M |
| Opacity fade (dimmed foes) | unit_hud.gd:360-374 | uniforms | n/a | combat transitions |

### 1e. Floating combat text and popups

| Element | file:line | Drawn | Icon | Scenarios |
|---|---|---|---|---|
| Damage numbers (crit gold, hero red) | fx.gd:30-34; combat_stage.gd:444, :620; event_player.gd:117 | L3D `popup_text` fx.gd:38-73 | none | C3, K |
| "BLOCK" / "FROZEN" / "ATK UP" pops | combat_stage.gd:458, :617; event_player.gd:752, :758 | L3D | none | C3 |
| Affix beats ("+2 ATK", "WARDED", "SHELL SHATTERED") | affix_beats.gd:55-148; biome_beats.gd:52-133; twist_beats.gd:93 | L3D | none | E, SS, twist_drum_rally |
| Class beats: "BOO!", "SCARED!", "SPOOKED! -25%", "FLEES!", "COWERS!", "PIERCE!" | class_beats.gd:173, :289, :322-371 | L3D | none | BOO |
| Tray-corner class callout | class_beats.gd:59, :138 → dice_tray.gd:203 | Label + SBF | `mech_oath` etc. | paladin, BN |
| item_triggered pill (3D item render + rule) | meta_beats.gd:392-441 → overlay.gd:322-368 (SBF :324) | Ctl + SBF | rendered item thumb | EV |
| Passive trigger pop | overlay.gd:295-316 | Ctl | `passive_*` | combat with passives |
| Screen popup (rune triggers over tray dice) | overlay.gd:438-471 (stacking :474) | Ctl + optional icon | varies (`rune_*`) | rune fights |
| Toast (twist and biome events) | overlay.gd:402-436; twist_beats.gd:276 (`intent_bury`); biome_beats.gd:108 (`intent_scorch`) | SBF `pill` + icon | `intent_*` | SS, Magma |
| Announce / boss card / passive card / biome card | overlay.gd:370, :144, :206, :247 | Ctl + SBF | `biome_*`, `passive_*` | BO, act change (**shared with the modal/overlay area**) |
| Pet / potion pops | meta_hud.gd:336-395; meta_beats.gd:140, :318 | SBF + icon | `heart`, `potion_*`, `pet_*` | P |
| 2D fly-coins | fx.gd:435-453 | TextureRect | `coin` | rewards |

### 1f. Board overlays

| Element | file:line | Drawn | Icon | Scenarios |
|---|---|---|---|---|
| Landing target markers (value badge, beam, chevron, dotted trail) | board_view.gd:491-660 (`_make_marker` :566, badge quads :615-635, Label3D :636-650) | mesh + StandardMaterial + L3D | none | R, `board_follow` |
| Move pill "5 + 5 = 10" / DOUBLES / BOSS! | board_hud.gd:165-178 | SBF + Labels + DieFace | none | R |
| Route card (run start) | ui/modals/route_card.gd (UiModal) + route_strip.gd:40, :68, :105-109 | UiModal + Medallion + SBF | `arrow_right`, `biome_*`, `check` | RC |
| Portal hint banner | portal_banner.gd:16-21 | SBF (own purple) + icon | `portal` | PO |
| Tile type identity | tile_style.gd props | 3D props | none | B |

The codebase has **no hover tooltip on board tiles** (no InputEventMouseMotion on the board). "Tile hover/landing labels" therefore means the landing markers and the move pill. A hover tile label would be a new feature and is out of scope.

### 1g. Pre-boss finale (`wp-preboss`, uncommitted diff), HUD needs

| Change | Where | What area (b) must support |
|---|---|---|
| Skull icon on the lap chip when `lap >= total` ("BOSS NEXT"), and "FINAL ROLL" during the finale; chip pops on entering the final lap; red rim | hud_top.gd +`_boss_icon` (`UiIcons.rect("skull", 28)`), `set_lap` | Lap chip must hold icon + label + pips; the red accent goes through `panel_box("pill", accent)` (area a R10), not a StyleBoxFlat cast |
| `_total` laps (Short Road = 10) and `SHORT_BIOME_LAPS` | hud_top.gd `_set_laps` | Pip row width varies (5 pips); keep the pip art size-agnostic |
| ROLL button reads "FINAL ROLL"; REROLL hidden in the finale | board_hud.gd:131-133 | Button label is about 1.8× longer. Check that the 2.5 button piece and 402 pt width fit it |
| "BOSS!" tag in the move pill when finale | board_hud.gd:176-177 | pill tag style |
| New tile type `boss` (crimson sigil + skull prop) | tile_style.gd | 3D only; no HUD icon |
| `finale_started` event | hud_top.gd on_event | re-sync lap chip |

---

## 2. Proposed mapping

### 2a. Pack component per element

These are area (a) pieces and factories. Only the few extra pieces area (b) needs are new; they are marked **NEW**.

| Element | Pack component (`third_party/rhosgfx/cartoony-ui-pack-full/…`) | Via |
|---|---|---|
| HP bar (hero) | `Bars/Regular/1. Grey/progress-container-regular-grey-darker.svg` + `Bars/Regular/2. Red/progress-bar-regular-red-regular.svg`; ghost = the `red-lighter` bar | `StatBar` → `UiTheme.bar_boxes("hp")` (a) |
| Block shield on HP bar / burn badge | icons only (no plate); number over the icon | `Icons.rect` |
| Level medallion + XP ring | stays procedural (lead: `level_badge` in `missing`). Ring colour = the XP bar purple. Inner disc = the `Buttons/3D/Round/…-1-…` purple "darker" circle drawn with `draw_texture_rect` **PROPOSAL (lead)** | `UiSkin.texture("round_disc_xp")` NEW |
| Gold / treasury counters, lap chip, twist chip | `Buttons/Flat/Round/…-2.5-…` pill (lead: pills), white × INK | `panel_box("pill", accent)` (a) |
| Pause / gear | `Buttons/3D/Round/…/button-round-3d-1-*` | `GameButton.round_icon` (a) |
| Speed pill, AUTO toggle | today `_draw` recipes. Replace the face/lip/gloss with `UiSkin.stylebox("button_ghost", state)` / `("button_auto_on")`. AUTO on = `Buttons/3D/Round/5. Forest Green` or `6. Blue` (teal is not in the pack; tint the white round pill with ACCENT `46d9c4`) **PROPOSAL (lead)** | `draw_style_box(UiSkin.stylebox(…))` |
| Passive icons | pack glyph + procedural rarity ring (lead) | `Icons.tex` in `_draw` |
| Class badge | `chip_box(accent = class colour)` (a) | a |
| Pet / potion strip | strip = `panel_box("hud")`; slots = `UiTheme.inset_box()` (a); tips = `callout_box(rim)` (a) | a |
| Combo panel | `panel_box("hud")` (Containers/Flat white × PANEL_SOFT) | a |
| Damage chip | `Buttons/Flat/Round/2. Red/…-2.5-red-darker` as a chip | `chip_box(UiPalette.DANGER)` |
| ? cheat sheet | round icon button + `panel_box("main")` (Frames/Nailed) | a |
| REROLL / ATTACK | 3D Square 2.5 **blue** (secondary) / **yellow** (primary), 112 px tall | `GameButton` (a) |
| Reroll pips | icons | `Icons.rect("reroll", 30, tint)` (Flat White: tinted gold / grey) |
| Combo splash | keep rays; name/mult use the display font with outline; add a `Frames/Ornate` darkbrown plaque behind the name for x3+ combos **PROPOSAL** | Ctl |
| Tray frame | `Frames/Nailed/9. Brown/frame-nailed-darkbrown.svg` 9-slice over the SubViewport (margins 24/27/24/34). This replaces frame.gdshader; the inner shadow stays as a thin shader overlay. **PROPOSAL (lead)**: the walnut shader already matches the "wood" direction; the nailed frame is the consistent choice | `UiSkin.stylebox("frame_tray")` NEW (NinePatchRect / Panel over the viewport) |
| Tray corner badge | `chip_box(accent)` | a |
| Turret label | chip under the stand (`chip_box`) | a |
| DieFace 2D body | stays procedural (die art, not UI chrome). Only the ★ and lock glyphs come from the pack (below) | Icons |
| Landing marker badge | today it is a flat quad + rim quad. Sample `Containers/3D/3. Yellow/container-3d-yellow-regular.svg` rasterised (see §3) on the badge quad, with the value as a Label3D | shader3D |
| Route card | UiModal (a); strip pills `chip_box`; medallions (c) | a / c |
| Portal banner | `callout_box(Color("a56bff"))` | a |
| Toasts / popups / item pill / tooltips | `toast_box()`, `callout_box(rim)` | a |
| Floating damage text | stays Label3D, display font; see §3 for the icon prefix | fx.gd |

### 2b. Icon concepts: candidate SVGs

All paths are relative to `third_party/rhosgfx/`. They mostly **agree with `icon_map.json`**. "Map" = what the lead mapped; **bold** = where this plan disagrees or fills a gap (a proposal for the lead).

Render sheets:

- `icon_candidates_b.png` has, per concept: full-colour, Flat White on a colour disc, the same at 28 px, and the alternate.
- `world_badge_options.png` has the lead's intent / trait / affix picks as styles A / B / C (see §3).

**Intents** (world badge + 2D toasts). The world style is C (see §3).

| id | Map (primary) | Alternates / note |
|---|---|---|
| intent_attack | vector-icon-pack-pro/Weapons/Sword/Sword Outline.svg | Weapons/Dagger |
| intent_block | Weapons/Shield/Shield Blue Outline.svg | Weapons/Overshield/OvershieldBlue |
| intent_buff | Player/Strong Arm/Strong Arm Outline.svg | General/Upgrade (arrows; closer to today's "up") |
| intent_rally | Tools/Megaphone/Megaphone Outline.svg | **Music/Drum/Drum Outline.svg**: rally is the Warcamp drums' mechanic, so the drum ties to the twist chip |
| intent_curse | Holiday/Monkey's Paw/Monkey's Paw Outline.svg | General/Lock (today's padlock; see status_locked) |
| intent_summon | Holiday/Zombie Hand/Zombie Hand Outline.svg | Holiday/Tombstone |
| intent_unknown | UI/Question Mark/Question Mark Outline.svg | |
| intent_aim | UI/Crosshair/Crosshair Outline.svg | Weapons/Target (used for mech_aim; keep them distinct) |
| intent_chaos | Nature/Tornado/Tornado Outline.svg | Nature/Black Hole/Black Hole Purple |
| intent_heal | Items/Medpack/Medpack Red Outline.svg | UI/Plus (reads better at 20 px) |
| intent_drain | Materials/Blood/Blood Outline.svg | Items/Teeth; drain today = fang over heart |
| intent_burn | Nature/Fire/Fire Outline.svg | |
| intent_chill | Nature/Snowflake/Snowflake Outline.svg | Nature/Snowflake 2 |
| intent_scorch | General/Explosion/Explosion Outline.svg | **Nature/Volcano/Volcano Outline.svg**: Explosion is wanted for crits (below). Scorch = "flame on a die", so a volcano/fire reads closer |
| intent_bury | Tools/Shovel/Shovel Stone Outline.svg | Materials/Sand |
| intent_moonfall | Nature/Moon Phases/Moon Full Outline.svg | **Nature/Moon/Moon Outline.svg (crescent)**: a full moon is also the moon meter's "full" state, so the intent would read as "meter full". Today's glyph is a falling crescent |
| intent_cower | vector-emojis/SVG/Outline/Fearful face.svg | Face screaming in fear |

**Traits, affixes and the scare chips** (world badges; the same ids feed encounter cards and affix tips):

| id | Map | Note |
|---|---|---|
| trait_armor | Weapons/Shield/Shield Silver Outline.svg | is a shield; **Clothing/Armor Chestplate** differs more from block's shield (affix_armored also uses Chestplate; either works, but not Shield next to a block badge) |
| trait_thorns | Nature/Cactus/Cactus Outline.svg | |
| trait_ward / trait_ward_allies | Weapons/Overshield/OvershieldBlue / OvershieldGreen Outline.svg | |
| trait_pierce | Weapons/Arrow/Arrow Outline.svg | |
| trait_brave | Player/Fist/Fist Outline.svg | |
| trait_frenzy / affix_frenzied | vector-emojis/SVG/Outline/Face with steam from nose.svg | |
| affix_armored | Clothing/Armor Chestplate/Armor Chestplate Outline.svg | |
| affix_thorned | Nature/Cactus/Cactus Outline.svg | same glyph as trait_thorns (intended: the affix grants the trait) |
| affix_warded | Weapons/Overshield/OvershieldGreen Outline.svg | |
| affix_piercing | Weapons/Spear/Spear Outline.svg | |
| affix_regenerating | Items/Bandaid/Bandaid Outline.svg | Nature/Sprout reads as "grows back" |
| affix_vampiric | Items/Dragon Tooth/Dragon Tooth Outline.svg | Holiday/Bat is clearer as "vampire" |
| affix_hexing | Items/Crystal Ball/Crystal Ball Purple Outline.svg | Holiday/Cauldron |
| affix_frostbound | Materials/Ice/Ice Outline.svg | |
| affix_gilded | Currency/Coin Stack/Coin Stack Gold Outline.svg | |

**Statuses** (hero and enemy). Today enemy statuses are text only (`POISON 3  FROZEN`). **PROPOSAL (lead)**: turn the status line into icon pips with a count. Ids are new unless noted.

| id (new) | Candidate | Note |
|---|---|---|
| status_poison | Tools/Poison/Poison Outline.svg | = map `poison` |
| status_frozen | Materials/Ice/Ice Outline.svg | Tools/Frozen Clock ("skips a turn") |
| status_spooked | vector-emojis/SVG/Outline/Anxious face with sweat.svg | distinct from cower (Fearful face) |
| status_frenzy | = trait_frenzy | pip with "+n" |
| status_burn (hero badge, Magma) | Nature/Fire/Fire Outline.svg | hud_top.gd:114 uses `intent_burn`; same art |
| status_curse (cursed face) | Holiday/Monkey's Paw (map `curse`) | |
| status_locked (buried / locked die, DieFace :179) | **General/Lock/Lock Outline.svg** | DieFace draws `curse` for a *locked* die; with the map that becomes a monkey's paw. Locked needs a padlock (the 3D chains already have one) |
| moon phases (twist chip + meter art) | Nature/Moon Phases/Moon {New, Waxing Crescent, First Quarter, Waxing Gibbous, Full} Outline.svg | replaces `_MoonGlyph` (hud_top.gd:655) by phase |

**Dice kinds** (lead: corner marks stay procedural; icons used only in 2D lists, shop, inspector, tray badge):

| id | Map | Problem / proposal |
|---|---|---|
| kind_standard | Shapes/Gaming Dice/D6 Outline.svg | ok |
| kind_low, kind_high, kind_even, kind_odd, kind_loaded, kind_twin, kind_pretend | all `D6 Flat White.svg` tinted per kind | **Seven kinds differ by hue only.** This fails colour-blind players and small sizes. **PROPOSAL (lead)**: composite D6 Flat White + the procedural corner mark (DieFace.draw_kind_mark) as the icon, **or** distinct glyphs: low = UI/Chevrons Down, high = UI/Chevrons Up, loaded = Sports/Kettlebell, twin = Items/Dice (two dice), gambler = General/Luck (clover), giant = Clothing/Crown, pretend = General/Paw (dino print) |
| kind_gambler | Items/Lucky Block/Lucky Block Green Outline.svg | ok |
| kind_giant | Shapes/Gaming Dice/D20 Outline.svg | D20 reads "big die"; ok |
| kind_bone | Items/Bone/Bone Outline.svg | ok |
| kind_seed (Druid tag) | not mapped | **Nature/Sprout/Sprout Outline.svg** (= mech_overgrowth) |
| ★ Pretend face (DieFace star, die.gdshader :211) | `star` = General/Star/Star Gold Outline.svg | 2D DieFace: sample the pack star (full colour). 3D die face stays SDF (it is engraved into the die; the lead's "kind_marks procedural" rule) |
| turret slot label | mech_turret = Technology/Satellite Dish (weak, per the lead) | **Tools/Wrench/Wrench Outline.svg** + "TURRET". A wrench reads as "Engineer"; there is no cannon in the pack |

**Combo, combat panel and floating text**

| Concept | Candidate | Note |
|---|---|---|
| Combo caption | `dice` = Items/Dice/Dice Outline.svg next to "COMBO" | combos themselves stay text (lead) |
| Damage chip | `sword` = Weapons/Sword/Sword Outline.svg | |
| Crit number prefix / flash | **General/Explosion/Explosion Outline.svg** | only if intent_scorch moves off Explosion |
| Heal number | UI/Plus/Plus Flat White.svg tinted HEAL | |
| Block pop | Weapons/Shield/Shield Blue Outline.svg | |
| Reroll button + pips | `reroll` = UI/Recycle/Recycle Outline.svg (map) | pips need a tinted on/off state. **Use UI/Redo/Redo Flat White.svg for the pips** (single arrow; Recycle's three arrows blur at 30 px) and keep Recycle on the button |
| ? help | `question` = UI/Question Mark Flat White (TEXT_DARK) | |
| ATTACK | `sword` | |

**HUD currencies and controls**

| Concept | Map | Note |
|---|---|---|
| HP heart | General/Heart/Heart Outline.svg | Heart Empty (UI pack thank-you icon) for 0 HP flash is optional |
| Gold (`3d:coins`) | Currency/Coin Stack/Coin Stack Gold Outline.svg | the HUD counter calls `3d:coins`; the map covers it |
| Treasury (`3d:chest`) | Items/Piggy Bank/Piggy Bank Gold Outline.svg | ok ("bank") |
| XP | General/XP Orb/XP Orb Outline.svg | level medallion ring only |
| Block shield | `shield` = Shield Blue Outline | |
| Speed | UI/Double Arrows/Double Arrows Right Flat White (TEXT_DARK) | on a dark pill the tint must be GOLD, not TEXT_DARK: pass an explicit tint (hot = orange) |
| AUTO | UI/Redo/Redo Flat White (TEXT_DARK) | on-state spin keeps working (rotate the TextureRect) |
| Pause | UI/Pause/Pause Flat White | tint TEXT on the ghost button |
| Settings gear | General/Settings/Gear Flat White | |
| Lap boss (pip + preboss skull) | `skull` = General/Skull/Skull Outline.svg | **General/Horned Skull/Horned Skull Red Outline.svg** for the *final boss* (lap pip diamond, "BOSS NEXT", route card boss row). The plain skull stays for summon / trap toasts |
| Lap flag | `flag` = Items/Flag/Flag Checkered Outline.svg | ok for the lap chip |
| Twist: sun / oasis / drum / ore | Nature/Sun, Nature/Palm Tree, Music/Drum, Materials/Ore/Ore Emerald Outline | ok |
| Portal hint | Transport/Portal/Portal Purple Outline.svg | ok |

---

## 3. World-space specifics (unit HUD, board markers, tray)

### How SVG gets onto 3D quads crisply

- `DPITexture` (foundation's default) re-rasterises only for **canvas** oversampling. A spatial shader samples it at its base size, so in 3D it behaves like a fixed raster. For every 3D consumer, use the foundation's **fixed raster**: `Icons.tex(id, px, tint)` → `UiSvg.raster()` → an ImageTexture with mipmaps. That is the same contract as today's `UiIcons.tex(icon, 96)`.
- **Pick `px` from the worst case.** Measured from the before shots:
  - intent badge (0.46 world units) ≈ 62 px on screen at 1080p;
  - boss HUD (scale 1.2) ≈ 75 px;
  - 150 % zoom does **not** scale 3D;
  - ipadpro13 landscape ≈ 70 px;
  - @2x DPI doubles it.

  Rasterise badge glyphs at **256 px** and trait / affix / status pips at **192 px**. Use mipmaps with trilinear filtering (`filter_linear_mipmap`, already on `affix_badge.gdshader`), and **add anisotropic** because the billboard faces the camera. Per icon that is 256 KB at RGBA8 × about 45 ids ≈ 11 MB. Acceptable, but cache per (id, px, tint) as Icons already does, and never raster per unit.
- **Unify intent, trait, scare, brave and affix into one shader:** `game/world/shaders/badge.gdshader`, grown from `affix_badge.gdshader`. It takes these uniforms:
  - `icon` (sampler), `bg_color`, `rim_color`, `style` (see below);
  - `glow`, `opacity`, `billboard`, `offset`.

  `intent_icon.gdshader`'s 19 SDF kinds are dropped from the default path. Keep it behind a fallback flag, which the lead's `missing` list suggests for web performance and for clones without the pack (`Icons` falls back to the legacy glyph anyway, so the fallback is automatic). `UnitHud.INTENT_KINDS`/`TRAIT_KINDS` become `UiPalette.INTENT` icon ids, which already exist (palette.gd:92-108). That removes today's two parallel intent icon systems (SDF in 3D, `intent_*.svg` in 2D toasts).
- **Badge style, PROPOSAL (lead), see `world_badge_options.png`:**
  - **A. Full-colour Outline glyph on an intent-coloured disc.** Same-hue clashes: block (blue shield on blue), drain, burn, gilded, summon, vampiric. Rejected.
  - **B. Flat White glyph on a coloured disc.** Today's look; the best legibility at 28 px, but it drops the pack's colour art.
  - **C. Full-colour Outline glyph on a dark navy disc with a 4 px intent-coloured rim.** Keeps the pack art, keeps the colour code and has no clashes.

  **Recommend C** for intent / affix / trait badges of 40 px or more on screen. Use **B** for status pips and board affix chips of 28 px or less. B also matches the lead's "Flat White ≤ 24 px" rule.
- **The disc itself:** keep it procedural (an SDF circle + rim, crisp at any distance), coloured from the palette. Optional: sample `Buttons/3D/Round/0. White/button-round-3d-1-white_standard.svg` as the disc for the pack's bevel/lip, tinted by `bg_color`. A 64-unit art rasterised at 256 is fine; the rim thickness then scales with the badge.
- **Label3D text** (HP "12/12", intent value, block, notes, damage numbers) stays Label3D, with `font` = the theme display font from area (a). Area (a) keeps the fonts, so `Props.font(true)` keeps working. Raise the outline from 12-14 to 16 for contrast (see §4).
- **HP bar:** keep `hp_bar.gdshader` (ghost / shield / segments animate per frame, and a 3-slice texture would need 3 samplers plus UV math). Restyle it to the pack bar instead:
  - frame = darkbrown outline `#3b1a10`-ish (lead palette), 2-tone fill;
  - the fill's top highlight band matches `progress-bar-regular-red-regular`: flat top band, no gloss gradient;
  - well = `grey-darker`.

  **PROPOSAL**: expose the colours as uniforms read from `UiSkin`-adjacent palette constants so that area (a)'s palette owns them.
- **Moon meter:** keep the procedural terminator (a continuous tween between phases and the blood tint are gameplay feedback; the 5 phase SVGs would snap). Change the art:
  1. the `moon_lit` colour comes from sampling `Nature/Moon Phases/Moon Full Outline.svg` rasterised at 256 into a new `moon_tex` uniform. The terminator mask multiplies it (dark side = texture × `moon_dark`);
  2. blood = hue-multiply the sample;
  3. the tide pips stay SDF, restyled to the pack outline colour;
  4. the rim is the same as the badge style C.

  The meter then shows pack art at every fill level.
- **Board landing badge** (board_view.gd:615-650): swap the two flat quads (face + rim) for one quad with `badge.gdshader` style "plaque", sampling a 3-slice of `Containers/3D/3. Yellow/container-3d-yellow-regular.svg`. Or simpler: rasterise the container at the badge's aspect ratio for each digit count (1, 2 and 3 values, so only 3 textures). The value stays a Label3D. Board affix chips (affix_looks.gd:346) use badge style B with billboard=1.
- **Tray:** the dice are rendered in a SubViewport (MSAA 4×), and the frame is a 2D overlay. So the Nailed frame is a plain 2D `StyleBoxTexture` (DPITexture: crisp), sitting over the viewport rect at `DiceTray.FRAME_PX`. FRAME_PX grows from 13 to ~24 (the art's 24/27/24/34 slice at scale 1). **The felt area shrinks**, so recheck `MIN_SPACING` and the 5-die + turret row on 402 pt.
- **Tray corner badge and turret label** stay 2D Controls over the viewport.
- **Performance:** in the worst fight there are 3 enemies × (intent + block + 2 affix + 4 traits + scare + brave + moon) = about 30 badge quads. That is the same count as today; one shader replaces two. The `icon` textures are shared across units through the Icons cache.

---

## 4. Layout risks

| # | Risk | Evidence | Mitigation |
|---|---|---|---|
| L1 | **Phone portrait: world HUD is tiny.** On iPhone 17 the intent discs are about 16-18 pt and "12/12" is about 9 pt. The pack's outlined art has thicker outlines, so its interiors shrink further | `before/combat/game_combat__iphone17_17pro.png` | Add a portrait size floor. In `CombatStage` / `UnitHud`, scale by `clamp(ref_h / view_h_pts …)`, or compute a screen-size target (≥ 28 pt disc) from the camera distance each frame (`UnitHud._process` already has the camera). Use badge style B below 28 pt |
| L2 | **`--ui-scale` does not reach 3D.** At 150 % the 2D HUD grows but the unit HUDs do not, so the gap between them widens | `before/combat_zoom/game_combat__pc_1080p_z150.png` | Multiply the UnitHud / board-marker / popup_text scale by the UI scale factor (`get_window().content_scale_factor / base`). One helper, `UiTheme.world_ui_scale()` NEW |
| L3 | **Notch / Dynamic Island.** HudTop starts at `safe.top`; the pack pills are taller (64-unit art: a 22 px label in a pill of about 48 px vs about 40 today). On iPhone portrait the row already shrinks via `_fit` (0.6-1.0) | `before/board/game_board__iphone17_17pro.png` | Keep `_fit`. Budget the row height: medallion 100 → 92 if the pack pill pushes the chips row past it. Test `iphone17promax` + `duo_outer` in the mobile set |
| L4 | **iPhone Duo outer (466×678, 0.087 top inset).** The screen is short, and 9-slice frames eat vertical space: Nailed bottom slice 34 + top 27 on the tray, 3D button lip 19 | `before/combat/game_combat__duo_outer.png`: tray + buttons + combo panel already take about 50 % of the height | On `is_short(view)` (new, h < 720 pt): tray frame = `Frames/Thin` (22) instead of Nailed; REROLL/ATTACK `min_height` 112 → 96 (still ≥ 88 hit target per area a R7); the combo panel caption "COMBO" hides |
| L5 | **1366×768 desktop.** The 3D-square 2.5 buttons have a 19-unit lip, and the combo panel + buttons stack in the side slot | `before/combat/game_combat__pc_1366x768.png` | Check `side_slot` height vs `_bottom` min size; the sheet popover must fit above (`combat_hud._layout` :195-200) |
| L6 | **Twist chip + lap chip + (preboss) skull on one row.** On narrow screens "FULL IN 2" + "BOSS NEXT" + skull + 5 pips overflow and trigger `_fit` shrink | M on iphone17 | Put the pips under the label in tall layouts, or drop the pips when `_fit < 0.8` (the tooltip still has the lap) |
| L7 | **Small-size readability of pack icons.** Many Outline icons carry fine interior detail (Recycle, Tornado, Monkey's Paw, Crystal Ball) that turns to mush at 24-30 px | `icon_candidates_b.png` 28 px column | Lead rule: Flat White ≤ 24 px. Area (b) sizes of 30 px or less: reroll pips (30), passive glyphs (44 → OK), tray badge (24), status pips (≤ 28), board chips. Swap in single-shape alternates there (Redo for Recycle) |
| L8 | **Contrast over busy 3D boards.** Moonlit and Magma boards are dark / saturated; Ruins is bright sand. The Label3D outlines are dark on dark in Moonlit, and the scrim covers only the top | `before/moon`, `before/sandstorm` | Badge style C (dark disc) guarantees a local ground for glyphs. Raise the Label3D outline to 16 and use a navy (not brown) outline colour. Keep HudTop's scrim, and add a matching bottom scrim behind the combat panel on light biomes (Ruins) |
| L9 | **StyleBoxFlat casts break.** hud_top.gd:379 and :584 cast `panel_box("pill")` to StyleBoxFlat; this becomes null with UiSkin | code | area (a) owns the fix (`panel_box(kind, accent)`); area (b) must not merge before it |
| L10 | **Tray felt shrinks with the thicker frame.** 5 dice + turret on 402 pt | `before/turret/*iphone17*` | Recompute spacing; accept a smaller die, or use Thin on phones (L4) |
| L11 | **Popup stacking vs taller pills.** `overlay._stack` and `item_pop` avoid rects assume the current pill height | EV | Take the heights from `toast_box().get_minimum_size()`, not constants |

---

## 5. Implementation plan

The steps assume area (a)'s factories exist (they may have fallback bodies) and the foundation's `Icons`/`UiSkin` are merged. The steps are in order and each can be shipped on its own. Every step keeps today's look when the pack is absent, through the `Icons` and `UiSkin` fallbacks.

1. **Icon call-site rename (mechanical).** In all area (b) files, change `UiIcons.rect/tex/exists/...` → `Icons.rect/tex/exists/...`. Use `Icons.texture` for Controls and `Icons.tex(id, px)` for `_draw` code and shader uniforms. Files:
   - hud_top.gd, combat_hud.gd, board_hud.gd, counter.gd, class_badge.gd, passive_icon.gd;
   - speed_pill.gd, auto_button.gd, auto_hud.gd, meta_hud.gd;
   - die_face.gd, dice_tray.gd, unit_hud.gd;
   - overlay.gd (popup, toast, item_pop, passive_pop), fx.gd:437;
   - route_strip.gd, portal_banner.gd, meta_beats.gd, affix_looks.gd, twist_beats.gd, biome_beats.gd.

   Depends on: foundation. Shoot: quick matrix of B, C.
2. **Map the missing ids** (a PR to the lead's `icon_map.json`, or ask the lead):
   - `status_poison/frozen/spooked/frenzy/locked`, `kind_seed`, `boss_final`, `moon_new..moon_full`;
   - the swaps accepted from §2b: moonfall, scorch, rally, locked, the turret and reroll pips.
3. **Unit HUD badge shader** (§3):
   - create `badge.gdshader` (styles B/C, disc, rim, glow, billboard);
   - rewrite `UnitHud._badge`/`affix_badge` to take an icon id;
   - replace `INTENT_KINDS`/`TRAIT_KINDS` with `UiPalette.INTENT` ids + `Icons.tex(id, 256)`;
   - keep `intent_icon.gdshader` only as the fallback (`Icons.is_mapped(id) == false` and no legacy svg).

   Move affix_looks.gd:346 board chips to style B. Shoot: C, E, BOO, M, SS, `game_board --affixes=thorned,warded`.
4. **Status pips:**
   - replace the `status_label` text line (unit_hud.gd:171-187) with an icon row (style B, 0.24 units) + a count Label3D;
   - keep the text as the tooltip / encounter card.

   Shoot: C3 (`--turns=3` with poison / freeze runes), BOO (spooked).
5. **Moon meter and HP bar restyle** (§3): the `moon_tex` uniform and the palette-driven bar colours. Shoot: M, MF, BO.
6. **World scale helpers** (L1, L2):
   - `UiTheme.world_ui_scale()`;
   - a UnitHud screen-size floor;
   - apply the scale to `Fx.popup_text`, the board markers and UnitHud.

   Shoot: zoom set + iphone17 + duo_outer for C and R.
7. **Top HUD reskin:**
   - lap chip / twist chip / counters → `panel_box("pill", accent)` (after area a's R10 fix);
   - `_MoonGlyph` → moon-phase icons;
   - `_Pip` restyle: done = pack flag-coloured dot; boss = Horned Skull icon at 16 px, replacing the diamond;
   - merge `wp-preboss`'s skull / "BOSS NEXT" / "FINAL ROLL" (it touches the same functions; rebase whichever lands second);
   - speed pill + AUTO: draw `UiSkin.stylebox` instead of the face/lip/gloss recipe;
   - level medallion inner disc (optional);
   - burn / block badges.

   Shoot: B, P, M, and the preboss scenario once it is on main (`test_last_camp` / a `game_board --lap=15 --finale`-style scenario from that branch).
8. **Combat panel:**
   - the combo panel via `panel_box("hud")` (automatic after a) and the damage chip via `chip_box`;
   - reroll pips via Redo Flat White;
   - cheat sheet row highlight → `chip_box(GOLD)`;
   - combo splash: the optional plaque.

   Shoot: C, K, the sheet open, the zoom set.
9. **Dice tray:**
   - frame → Nailed 9-slice (Thin on short screens), `FRAME_PX` from the stylebox margins, spacing re-check;
   - the corner badge + turret label → `chip_box`;
   - DieFace ★ and lock via the pack icons.

   Shoot: C, BN, T, BOO, D, R on the full matrix.
10. **Popups and floating text:**
    - toasts via `toast_box()` (area a flips them);
    - `item_pop`/`passive_pop`/pet pops via `callout_box(rim)`;
    - damage / crit / heal / block pops get an optional pack icon prefix (a Sprite3D, or a Label3D with an icon quad beside it; **PROPOSAL (lead)**: only crit and heal get icons, so plain hits stay clean);
    - class beats keep the text (BOO!, SCARED!), with a larger outline.

    Shoot: EV, K, BOO, C3.
11. **Board overlays:**
    - the landing badge plaque (board_view.gd:615-650), the move pill tags (`chip_box`);
    - portal banner → `callout_box`;
    - route strip → chips (with area c, which owns route_card's modal).

    Shoot: R, PO, RC.
12. **Clean-up:**
    - remove the now-unused `ui/icons/intent_*.svg`/`affix_*`/`trait_*` generators from `gen_icons.py` **only after** the lead confirms the legacy fallback policy (clones without the paid pack still need them; keep them per the foundation header);
    - update `ui/icons/rendered` fallbacks.

**Dependencies:**

- **Foundation:**
  - `Icons.texture/tex/rect/exists/is_mapped`, `UiSvg.raster`, `UiSkin.stylebox/texture/has`;
  - the 3D need: `Icons.tex` must accept `px` ≥ 256 and return mipmapped textures (it does, via `UiSvg.raster` → `generate_mipmaps`);
  - request: an `Icons.tex_aniso(id, px)`, or document that consumers set `texture_filter` in the shader.
- **Area (a):**
  - `panel_box(kind, accent)` (R10 fix), `chip_box`, `callout_box`, `toast_box`, `inset_box`, `bar_boxes("hp")`;
  - the skinned `GameButton` (REROLL/ATTACK/ROLL/GO, round pause / gear / ?), `StatBar`, `Counter`, the display font.
- **Lead:** decisions §2b (bold) and §3 badge style; map entries in step 2.

**File overlap with other areas:**

| File | Also touched by | Rule |
|---|---|---|
| hud_top.gd | area (a) R10 (:379-380, :584-585); `wp-preboss` (lap chip) | (a) lands first; (b) rebases; preboss merges into (b)'s version of `set_lap` |
| board_hud.gd | `wp-preboss` (FINAL ROLL), area (a) toast | preboss first |
| overlay.gd | area (a) toasts; modal/overlay area (announce, boss_card, biome_card, passive_card, mini_dice) | (b) owns popup / item_pop / passive_pop / toast call sites only |
| stat_bar.gd, counter.gd, game_button.gd, level_badge.gd | area (a) | (b) only passes parameters |
| die_face.gd, die_chip.gd | area (c) (forge / shop / rune assign use them) | (b) owns the DieFace glyph swap; (c) owns the chip card |
| route_card.gd / route_strip.gd | area (c) modals, pause's route strip | (b) the strip chips; (c) the modal |
| affix_tips.gd, encounter_cards.gd | area (c) (cards) | same icon ids; (b) owns only the world badge |
| meta_hud.gd | camp / meta area (pets, potions) | (b) owns the strip in the run HUD |
| palette.gd | area (a) | (b) adds none; it reads INTENT/KIND |
| `ui/icons/icon_map.json` | lead | (b) proposes; the lead edits |

---

## 6. Test plan

Run from the worktree with `GODOT_PROJECT=$PWD tools/shoot_matrix.sh <scenario> <dir> <set> …`, in the background only. Copy `assets/{audio,fonts,kaykit}` and `.godot` into the worktree first.

**Waits matter.** Shots taken at `--wait=3` catch the fade into combat (every first-round "before" shot was a dimmed board). Use the waits below; they were verified. Running three chains in parallel costs about 25 % more time.

| Scenario + args | Sets | Wait | What to check |
|---|---|---|---|
| `game_board --passives=5` | quick, zoom | 8 | top HUD row, passives bar, counters, lap pips, scrim |
| `game_rolled` | quick | 10 | move pill, landing marker plaque, GO / REROLL, tray frame |
| `game_combat --cards=0` | all (desktop + mobile + duo + dpi + zoom) | 14 | combat panel, REROLL / ATTACK, reroll pips, intent badges (C style), HP bars, notch, 1366, duo outer |
| `game_combat --cards=0 --turns=3` | quick | 26 | damage numbers mid-flight, statuses, block pops, ghost HP |
| `game_combo --cards=0` | quick | 18 | combo splash, crit colour |
| `elite_affixed` | quick | 14 | affix badges, frenzy count, affix tooltip (callout_box) |
| `game_board --affixes=thorned,warded,-,gilded+hexing` | quick | 8 | board affix chips (style B, billboard) |
| `twist_moon_meter` (+ `--beat=clouds`) | quick | 24 | moon meter art, TIDE / CLOUDS notes, twist chip moon phase |
| `fight_moon_king_moonfall` | quick | 24 | moonfall intent (crescent), blood meter |
| `fight_sand_colossus_sandstorm` | quick | 24 | bury intent, locked dice (chains + DieFace lock), bright-biome contrast |
| `game_boss --act=1 --cards=0` | quick | 16 | boss HUD scale 1.2, name plate, phase ticks |
| `class_moment --class=monster_kid --moment=boo` / `cower` / `star_board` | quick | 20 | ★ face (3D + 2D), cower badge, BOO! / SCARED! text |
| `class_moment --class=necromancer --moment=bone_die` | quick | 20 | bone die, tray corner badge |
| `class_moment --class=engineer --moment=turret` | mobile | 20 | turret slot + label with the thicker frame on 402 pt |
| `class_moment --class=paladin --moment=oath` / `ranger --moment=aim` | quick | 20 | class tag in the combo panel, tray badge |
| `hud_potions --combat=1` (`--tip=0`) | quick | 14 | pet / potion strip, slot insets, tip callout |
| `events_misc --only=item_triggered` | quick | 12 | item pill callout, avoid rects |
| `game_portal` | quick | 10 | portal banner (callout_box), numbered target tiles |
| `route_card` | quick | 12 | strip chips; boss rows (today: skull for the mini-boss, crown for the final boss); at 6 s the card has not opened yet |
| `dice_kinds`, `dice_tray_gallery` | desktop | 4 | 2D DieFace glyphs, kind marks unchanged |
| preboss: its finale scenario once merged | quick + duo | tbd | skull + "BOSS NEXT"/"FINAL ROLL" chip, FINAL ROLL button width on duo_outer |

Also run with `--audit`: every `AUDIT_TEXT` under 16 px and `AUDIT_TAP` under 80 px must be no worse than before. Run a no-pack check (rename `assets/ui` away) on C and B: the look must equal the before shots, which proves the fallbacks. Compare each after shot side by side with the before strip in `sheets/<scenario>.png`, and put the pairs on a gallery page for Vlad (memory rule: show the images).

**Automated:**

- extend `tests/test_ui_skin.gd` (foundation) so that every id area (b) requests resolves: `Icons.exists(id)` for `UiPalette.INTENT` icons, `SkinRules.AFFIXES[*].icon`, the trait ids and the status ids;
- `game/dice/check_dice_tray.gd`: the headless tray layout with the new FRAME_PX still fits 5 dice + turret at 402 pt.

---

## Proposals for the lead (summary)

1. World badges: style C (full-colour glyph, dark disc, intent-coloured rim) at ≥ 40 px; style B (Flat White on a colour disc) ≤ 28 px. Style A clashes (§3, `world_badge_options.png`).
2. intent_moonfall → the crescent `Nature/Moon`, not Moon Full (which reads as a full meter).
3. intent_scorch → `Nature/Volcano`; keep Explosion for crits.
4. intent_rally → `Music/Drum` (ties to the Warcamp twist chip).
5. The locked/buried die needs `General/Lock` (DieFace uses the `curse` id, now a monkey's paw).
6. The kind_* icons differ by tint only: composite them with the procedural mark, or use distinct glyphs.
7. Final-boss skull → `Horned Skull Red` (lap pip, preboss "BOSS NEXT", route card).
8. mech_turret / turret label → `Tools/Wrench`.
9. Reroll pips → `UI/Redo` Flat White (Recycle blurs at 30 px).
10. The enemy status line becomes icon pips (new `status_*` ids).
11. Tray frame → `Frames/Nailed` darkbrown (Thin on short screens); drop `frame.gdshader`.
12. Speed / AUTO tints: explicit GOLD / ACCENT on dark pills (the map's TEXT_DARK default is for light buttons).
