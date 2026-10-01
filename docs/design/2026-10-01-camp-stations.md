# Camp stations: one card, one carousel, every station

Designer: UX/UI pass on the Camp station screens. Date: 2026-10-01. Branch `wp-ux-stations`
(from `main` at 997168f, after the modal pass). Mockup: `docs/design/camp-stations/mockup.png`
(source `mockup.svg`).

This pass follows the house conventions in `docs/reviews/2026-10-01-modal-pass.md`: the plaque
legend, the verb glossary, casing, numbers, icons and the spacing scale. Nothing here changes them.

User asks:

- "The dice workshop should be redesigned: each pack should be the same vertical size; the
  pack's card should consist of the same information, but use a carousel to show dice so as to
  not overwhelm with large packs."
- "Let's take a UX designer's stab at fixing it and other UIs to be equally informative and
  intuitive."

## 1. Audit (before)

Shot with `tools/shoot_matrix.sh <scenario> <dir> all --wait=10 --audit` (25 devices) at the
fresh, mid and max profiles: `ui_workshop`, `ui_petden`, `ui_arcade` (`--profile=fresh|mid|max`),
`ui_wardrobe` (demo, fresh, capped), `ui_armory` (fresh, mid, max), `ui_armory_picker`,
`ui_armory_craft` and `ui_armory_rankup`. The mechanical audit (overflow, safe area, clipping,
text under 16 px, taps under 80 px) was already clean after the modal pass: 0 findings on all
425 shots. The problems are about reading and using the screens.

| # | Station | Finding | Kind |
|---|---|---|---|
| A1 | Workshop | The Starter card lists 25 chips and is about 4× as tall as the 4-item packs. Pack heights vary 180–520 px. On a phone the first screen is one pack. | inconsistent heights, wall of chips |
| A2 | Workshop | A chip is a name only. What a rune, die or passive *does* is nowhere on the screen. Dice show no faces. | missing information |
| A3 | Workshop | A locked pack says how to earn it but not how far along you are. An owned pack doesn't say it is in your drops, or which of its items are switched off. | unclear state |
| A4 | Workshop | Drop pools: the passive pool is a wall of up to 31 toggles. The OFF state is a small red chip on a dark pill. | wall of chips |
| A5 | Workshop | The Starter Kit kinds are full-width tiles, each repeating its description. The Whetstone puts its description in the uppercase sub-line. | inconsistent |
| B1 | Pet Den | The "charge meter" is a row of empty stars with no meaning. Six of the twelve pets (Pebble, Frost Mote, Wick, Tinker, Grimoire, Bubbles) show "Fills " with no rule: their charge triggers had no text. Their roles showed raw ids ("ARMOR", "BURST"). | missing information (bug) |
| B2 | Pet Den | Four labelled text rows (Fires, Board, L5, L10) per pet, all in the same muted style. The charge rule and the next level-up aren't findable at a glance. Card heights vary with text length. | wall of text |
| B3 | Pet Den | The level-up cost is only a button deep in the card; the XP route (levels 1-5 from fights) is a bar without a label until you read the small print. | unclear |
| C1 | Arcade | What a game pays is only its gold-tier signature. Crowns per tier and the bronze / silver options are not shown anywhere at the Camp. | missing information |
| C2 | Arcade | "SWAP IN" silently replaces the *last* loadout slot. The loadout tiles say "Tap to remove". | unclear |
| C3 | Arcade | Card heights vary with the description (2–3 lines) and with the mastery row (owned only). | inconsistent heights |
| D1 | Wardrobe | Four big swatches in a 2×2 grid under a big pedestal: on a phone the locked skins and their conditions are two screens down. | too much at once |
| D2 | Wardrobe | A locked swatch's condition and progress are 16 px lines under the portrait, in two different colours; the buy button (capped profile) makes that swatch taller than the others. | inconsistent heights |
| E1 | Armory picker | The focused item expands into a 3-column variant grid (7 variants = 3 rows) plus a detail card: the item list jumps by 400 px when you tap an item. | inconsistent heights |
| E2 | Armory picker | "4 variants · 2 owned ▸": a unicode glyph as an icon (convention: no unicode glyphs). The variant tile says "CRAFT 20" with no currency icon (convention: a price is the currency icon and a bare number). | convention |
| E3 | Armory ranks | Rank cards vary in height (the Armor rank's "Next: tier III at rank 8, +2 max HP at rank 8" wraps), its sub-line is trimmed ("RANK 4/8 · TIER II · +…"), the Belt Pouch's too ("A 2ND TRINKET, ONE TIE…"). | inconsistent heights, trimmed info |

## 2. The station card

One builder, `StationCard` (`ui/camp/station_card.gd`), used by every station. Five rows, top to bottom:

| Row | Holds | Height |
|---|---|---|
| HEAD | medallion (64) · name (Lilita 26, one line) + short description (Fredoka 18, `desc_lines`, default 2) · on the right **one** of: a state chip (OWNED, EQUIPPED) or the card's action (UNLOCK / BUY / EQUIP) | max(88, name + description lines): a priced button's hit rect fits |
| PILLS | key stats as icon pills (`CampArt.chip` with an icon), one line | 34. Pills that don't fit drop off the end (most important first), never wrap |
| CONTENTS | the preview: a `Carousel`, a pet's rule tiles, a minigame's payout tiles | fixed per station (`Spec.contents_h`) |
| FOOTER | the status line (lock hint + live progress, "In your drops", XP to the next level) on the left; then the carousel's indicator row, or a second action (LEVEL UP, REMOVE) | 88 when a button or the carousel arrows can sit there, else 48 |

Rules:

- **Fixed height per station.** A station passes one `StationCard.Spec` to all its cards. No row
  grows with its content: text has a line budget (`max_lines_visible` + ellipsis, the full text
  is in the tooltip or the detail), pills drop instead of wrapping, carousels page. So every pack
  card is the same height, every pet card is the same height, and so on.
  `tests/test_station_ui.gd` checks that each row stays inside its budget and that the cards match.
- **State is the rim and the chip.** Normal = the station accent rim. Equipped / worn = the
  yellow rim + the purple EQUIPPED chip. Locked = the dimmed locked tile + the greyed medallion +
  a padlock status line with progress (`Reach lap 10 in one run. (6/10)`).
- **One priced action per card.** UNLOCK [sigil] N, BUY [crown] N, LEVEL UP [crown] N (verb
  glossary). Free actions (EQUIP, REMOVE, a carousel's arrows) don't count. Taps on tiles never
  spend.
- **Flat tiles, real buttons.** Cards and item tiles are `UiTheme.tile_box` (flat). Only the
  actions and the round arrows have the 3D lip.
- **Wide canvases get two columns** (landscape: width > 1.25 × height, the Armory's rule). Equal
  heights make the grid tidy. Phones and portrait tablets stay at one column.
- Spacing is the modal pass's scale: `GAP_ITEM` between cards, `section_label` headers,
  `GAP_HEAD` inside composite headers; 16 px card padding, 12 px between rows.

## 3. The carousel

`Carousel` (`ui/widgets/carousel.gd`) is a reusable widget:

- A clipped strip of fixed-height tiles, as many per page as fit (`tile_min_w`). The strip takes
  the full width; filler slots keep every tile the width of a full page, so short packs and last
  pages don't stretch.
- The indicator row: "N ITEMS", then the prev arrow, page dots (≤ 6 pages) or "N/M" (more),
  then the next arrow. The arrows are icon-only round GameButtons (grey). Their keyboard hint
  lives in the tooltip ("Next (→)"), so it shows on hover only. With one page the arrows hide.
  `StationCard.set_carousel()` moves this row into the card's footer next to the status line,
  so the strip gets the contents slot's full height.
- Input:
  - tap / click the arrows;
  - ←/→ (and `ui_left` / `ui_right`) page the focused carousel, which is the last one hovered,
    swiped or paged;
  - a sideways drag on the strip swipes, with rubber-banding and a 48 px threshold. A vertical
    drag still scrolls the screen.
  - Taps on tiles still work: a tap is a release within 18 px of the press.
- A carousel with a `key` remembers its page and the keyboard focus across rebuilds, so buying,
  toggling or equipping never sends you back to page 1.
- `Carousel.ItemTile` is the flat item tile: a 48 px visual (icon, a die's six faces, a 3D
  thumbnail), the name (16 px, up to two lines) and a detail line (rarity, ON / OFF, WORN, a
  price, progress). Hover lightens it (pointer cursor). It emits `pressed`.
- Tapping an item shows its rule in the shared `UiTooltip`, placed under the tile (or above when
  there's no room), through `CampModal.show_tip()`. The same tile, any other tap, a page turn,
  scrolling or a rebuild hides it.

## 4. Per station

### Dice Workshop (A1–A5)

- **Unlock packs**: one card per pack, all the same height.
  - Medallion: the pack icon.
  - Name and the pack's build idea in one line. These are new short blurbs in
    `CampInfo.PACK_BLURB`, for example "Blank-or-six dice, banked rerolls and lucky streaks."
  - Pills: what the pack adds to the drops: `[card] 6 RUNES` `[die] 4 DICE` `[trophy] 15 PASSIVES`.
  - Contents: a carousel of every item. Runes show their icon and rarity, dice their six faces
    and rarity, passives their badge and rarity. Tap for the rule ("Gambler Die · DIE · RARE ·
    Faces 0,0,6,6,6,6…").
  - Head: OWNED, or UNLOCK [sigil] 6 (grey when you can't afford it).
  - Footer: "In your drops · 2 switched off", or the milestone with its live progress.
  - Switched-off items show OFF in the pack's carousel.
- **Drop pools**: three cards (Runes, Die kinds, Passives), each with pills `N IN POOL` and
  `n/cap OFF` (red at the cap). The contents are a carousel of toggle tiles: tap to switch an item
  off or on; the tile says ON / OFF. A tile you can't switch off (pool at its cap) explains why in
  the tooltip.
- **Starting kit**: the Starter Kit card's carousel holds the kinds you can start with (IN USE /
  PICK). The Whetstone card states what it does and how many Crowns are still missing.

### Pet Den (B1–B3)

- Card per pet:
  - Pills: `CHARGE n`, `LEVEL L/10` and the role.
  - Contents: four rule tiles in a row (two by two on a phone): FILLS (the charge rule), FIRES,
    L5, L10. Each is a flat tile with a 3-line budget; reached tiers are lit and a tap shows the
    full text.
  - Footer: the level route. Levels 1-5 show an XP bar ("12/15 fights to L2"); levels 5-9 show
    LEVEL UP [crown] N; level 10 shows a MAX LEVEL chip.
  - Head: EQUIP, or the EQUIPPED chip (REMOVE moves to the footer), or UNLOCK [sigil] 6.
- The six missing charge rules and role names are written (`CampInfo.CHARGE_TEXT`, `ROLE_LABEL`).

### Arcade (C1–C3)

- **Loadout**: the slots as before. Each slot is a tile with the game's icon and name; tap it
  to remove the game. The 3rd slot shows its milestone or BUY.
- Card per minigame:
  - Pills: `SKILL 20% · LUCK 80%`, the average length (`~20 S`, from the calibration), and
    `MASTERY 2/5` (owned).
  - Contents: **what it pays**. Three tier tiles:
    - BRONZE [crown] 3: gold or +1 Crown;
    - SILVER [crown] 5: potion, Face Raise or gold;
    - GOLD [crown] 6: the game's signature.
    The Crowns figures come from `Economy.CROWNS_MINIGAME`. The options come from the same table
    `GameFlow._reward_options` uses.
  - Footer: mastery (`+2% gold · 6/8 plays to mastery 3`) or the milestone that unlocks the game.
  - Head: EQUIP / SWAP IN (it names the game it replaces in its tooltip and in the footer) /
    EQUIPPED / UNLOCK.

### Wardrobe (D1, D2)

- The class picker and the pedestal stay.
- The 2×2 swatches become a **skins carousel per class**: the four skins plus Prestige as
  same-height tiles. Each tile has a portrait, the name and a state line: WORN, WEAR, or the
  condition's progress ("2/4 BOSSES", "BEST A3"). Tap a tile to wear it (owned) or preview it on
  the pedestal (locked). The previewed skin's full condition, and its BUY [crown] 250 (capped
  profiles), sit in one detail line under the strip. That keeps the tiles one height.

### Armory (E1–E3)

- **Picker**: the focused item's variants become a carousel of variant tiles (thumbnail, name,
  and WORN / OWNED / `[crown] 20` CRAFT / `22/45 FIGHTS` / FEAT). Its height is fixed, so tapping
  an item no longer reflows the list. The opened variant's detail card (property, blueprint,
  CRAFT [crown] / CRAFT [sigil]) stays under the strip. The "▸" glyph is replaced by the
  chevron icon.
- **Ranks**: rank cards share one height. RANK n/8, TIER and +HP become pills, so they are never
  trimmed. The footer has "Next: …" (2-line budget) and RANK UP [crown] N. The Belt Pouch is a
  card of the same height.
