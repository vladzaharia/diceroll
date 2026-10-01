# NEW RUN window (run setup) redesign

Status: wp-ux-newrun, 2026-10-01. Code: `ui/camp/run_setup_modal.gd`. Tests:
`tests/test_run_setup_ui.gd`. Mockup: `docs/design/new-run/mockup.png` (source `mockup.svg`).
It follows the reskin spec (`2026-09-30-ui-reskin.md`): one exit, containment, hover-only key
hints, pack icons.

## Audit of the old window

Shot with `tools/shoot_matrix.sh ui_run_setup <dir> all --wait=10 --audit` at the fresh, mid
and max profiles. It had zero audit findings, but plenty of design problems:

- **Layout.** A single 720 px column on every device. On desktop and iPad landscape, two thirds
  of the screen is unused and the window scrolls about three screens deep.
- **Primary action.** START RUN sits at the very bottom of the scroll. It is off-screen on
  every device until you scroll to it.
- **Hierarchy.** HERO, MODE, ASCENSION and LOADOUT are small centred gold labels that look like
  captions. The KIT card has the same weight as the hero card, and the 11 hero cards look the
  same as the loadout cards.
- **Density.** Each locked hero card prints its whole unlock sentence, which adds about 11
  paragraphs of grey text. The kit lists every item name in one long dotted line.
- **Text over symbols.** Words carry the meaning where icons would do: "15 laps · 3 biomes ·
  full Crowns", "PET · LEVEL 5", "MINIGAMES 2 / 2", and CHANGE buttons.
- **Selection.** Each class card has a rim in its own class colour, so the Barbarian card's
  orange rim reads as "selected" next to the gold-rimmed Knight.
- **Hidden information.** Nothing shows the biome pool, the potion belt or the dice pool.
  Ascension shows only the newest rule, not the rules that stack under it.
- **Consistency.** It mixes text buttons (ARMORY, CHANGE ×2) and arrow steppers. The reskin
  spec asks for round plus / minus steppers.

## Design

Order of importance:

1. **Hero.** A hero card with:
   - the turning portrait;
   - the name in the class colour;
   - stat pills (♥ HP, ⚔ ATK, ⟳ move rerolls, 🎲 fight rerolls), each with a tooltip;
   - the mechanic badge;
   - a KIT strip of item thumbnails with tier badges, plus a round Armory shortcut.

   Below the card is the hero picker: 4 columns of tiles, each a medallion over the name.
2. **Route.**
   - Two mode cards, Standard and Short Road. Each has its medallion and three icon stats:
     ⌛ laps, 🌳 biomes, 👑 Crowns %.
   - The biome pool. Standard shows the three stage pools separated by chevrons. Short Road
     shows two: stage 1, then the rest.
   - Ascension. Round − / + steppers sit around "ASCENSION N", with star pips for the unlocked
     levels and a "+N% 👑" chip. Under them is the list of **stacked rules**, numbered, with the
     newest rule highlighted. These rules are the run's modifiers, so there is no separate
     "challenges" section: the game has no other modifier, and an empty section is noise.
3. **Loadout.** Four tiles in a 2 × 2 grid. Each whole tile opens its station:
   - Pet: medallion, name and LV chip. Opens the Pet Den.
   - Minigames: medallions, then empty slots, then the locked third slot. Opens the Arcade.
   - Potion belt: potion icons, plus a locked slot. Opens the Armory.
   - Dice pool: owned pack icons and "+N". Opens the Workshop.

   A chevron marks each tile as a shortcut. This replaces the CHANGE buttons.
4. **START RUN.** A full-width primary button in a **footer outside the scroll**, so it is
   always visible. Its sub line summarises the choice ("Necromancer · Standard · Ascension 6").
   Enter presses it. The ENTER keycap shows only on hover.

Section headers are all built the same way: a pack icon (helmet / flag / pouch), a gold caps
title and a faint rule to the edge.

### States

| State | Look |
|---|---|
| selected | Gold rim (`card_box("selected")`), gold title, ✓ inside the corner. Unselected tiles have **no** coloured rim; the class colour lives on the medallion ring. |
| open | Plain card. Hover uses the `hover` card on desktop. |
| locked | Locked card with a greyed (saturation 0) medallion and a 🔒 inside the corner. Tapping it buzzes and selects nothing. |
| secret | The Monster Kid before its milestone: a "?" medallion, "???" and a mystery rim. |
| unlock hint | One inset line under the group: "🔒 Ranger: Reach the final boss with 4 different classes… Or 8 Sigils." It shows the first locked item by default, and switches to whichever one you hover (desktop) or tap (touch). Locked biomes work the same way. Locked minigame and potion slots and locked stations give their hint in a tooltip, or as the tile text. |

### Layout

- **Wide** (free canvas width ≥ 1180 logical px; desktop and iPad landscape): the panel is
  1320 wide with two columns. The left column is Hero; the right is Route, then Loadout. At
  1280 canvas height the mid and max profiles fit without scrolling.
- **Narrow** (phones, iPad portrait, Duo): one 720 column in the order Hero → Route → Loadout,
  and the body scrolls. The footer stays pinned.
- **Short canvases** (height < 1000: phone landscape, zoomed desktops): an 80 px footer and the
  smaller portrait.
- Tap targets: every tile is at least 88 canvas px tall (44 pt). Round buttons draw at 64 inside
  GameButton's 88 px hit rect. All text is 16 px or larger. The kit's tier badges now pass 16;
  `KitStrip` gained an optional `badge_font` argument whose default is unchanged.

### Keys (desktop, hints on hover only)

| Key | Action |
|---|---|
| Enter | START RUN |
| Esc / × | close (the one exit) |
| ← / → | previous / next unlocked hero (wraps) |
| ↑ / ↓ | Ascension +1 / −1 (the + / − tooltips name the keys) |

## Scenario args

`ui_run_setup` now also takes `--asc=N`, `--mode=short` and `--class=<id>` (in
`game/camp/scenarios.gd`), so the Ascension rules and Short Road can be shot.
