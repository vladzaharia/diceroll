# Diceroll — Game Design & Technical Spec

Date: 2026-09-28 · Engine: Godot 4.7.2 · Targets: macOS, iOS (primary), Web (secondary)
Inputs: `docs/research/games.md` (Heroll + Dicero), `docs/research/assets.md` (KayKit inventory).

## 1. Pitch

A cozy-but-tense 3D dice roguelite. Your hero walks a looping **Heroll-style ring board**, and a **Dicero-style dice pool** drives both movement and combat. You roll your pool to pick where to land. When a fight breaks out on that tile, you roll the same dice for Yahtzee-style combos. Between fights you build the pool: add dice, bind **runes** to individual dice, and forge their **faces**.

We fix Heroll's biggest complaint, that there's no agency ("just tapping roll"). The player always chooses which die to move by, and every reroll is a real decision. Dicero's paywalls are removed. There's pause and auto-save, and speed-up is free.

## 2. Run structure

- **Run** = 3 Acts. Each Act has its own biome, board and boss. Clearing Act 3's boss wins the run. Target length is 25–35 min.
  - Act 1 **The Crypt** (KayKit Dungeon): grey stone, torches, banners, warm torchlight.
  - Act 2 **The Hollow** (KayKit Halloween): autumn trees, graves, pumpkins, orange dusk.
  - Act 3 **The Bone Throne** (Dungeon + Halloween, purple/teal night palette, crypt building).
- **Board** = a square ring of **24 tiles** (the perimeter of a 7×7 grid). Tile 0 is Start, and the 4 corners are special.
- **Lap** = one trip around the ring. Each Act lasts **3 laps**. Passing or landing on Start completes a lap. When lap 3 completes, the hero **stops on Start** and the **Act boss** fight begins.
- **Board mutation per lap** (Heroll): cleared enemy tiles become Empty. Then +2 Enemy tiles and +1 Elite spawn on random Empty tiles, events refresh, and enemy tier rises with the lap.

## 3. Board turn (movement)

1. Press **ROLL**. Every die in the pool is thrown into the dice tray.
2. Each die's result previews its destination tile on the board (ghost markers labelled with the die value).
3. Optionally spend a **board reroll** (1 per board turn, and it rerolls all dice).
4. **Tap a die** to move by its value. The hero hops tile by tile (Jump animation, camera follows).
5. Tiles passed over: only Start (lap completion) triggers when passed. All other tiles trigger on landing only.
6. **Doubles** in the board roll feed the **Treasury** corner's bank (+ the pair value × 2 gold).
7. Runes with the MOVE trigger fire for the chosen die.

## 4. Tiles

| Tile | Effect |
|---|---|
| **Start** (corner 0) | Pass/land: heal 15% max HP, lap +1, board mutates, **Shop** opens. On lap 3 completion: boss fight. |
| **Forge** (corner 6) | Edit one face of one die: **Raise** (+1, max 6) or **Mirror** (copy another face of the same die). |
| **Treasury** (corner 12) | Landing cashes out the bank (starts at 10 gold, +pair×2 per board double). |
| **Portal** (corner 18) | Choose any tile within the next 8 and teleport there, then trigger it. |
| Enemy | Fight 1–3 enemies (count and tier scale with act/lap). Win: gold + XP. |
| Elite | Golden-sparkle enemy tile, tougher fight, guaranteed rune reward. |
| Chest | Gold, or 1 of 3 rune choices (50/50). Consumed (becomes Empty). |
| Event | Random from the event table (§8). Consumed. |
| Campfire | Heal 30% max HP. Consumed. |
| Trap | Roll 1 die: 4+ dodges, otherwise take 12% max HP. Persists. |
| Empty | Nothing. |

Act 1 lap 1 layout of the 20 edge tiles: 6 Enemy, 3 Chest, 3 Event, 2 Campfire, 2 Trap, 4 Empty. Shuffled, but no Enemy in the 2 tiles after Start.

## 5. Dice

- A **Die** has 6 faces. Each face has a **value** of 1–6, and the default is 1..6. A die may carry **one rune**.
- The pool starts with **3 dice** and holds at most **6**.
- Dice are rendered as our own rounded-cube mesh with per-face textures. Pips are drawn in code. Edited faces get a gold rim, and a rune tints the die body in its rune colour.

### Runes (bound to one die, Dicero "materials")

Triggers are evaluated when you ATTACK, except START (before the roll) and MOVE (board).

| Rune | Colour | Trigger | Effect |
|---|---|---|---|
| Blade | red | COMBO (die is part of the scoring group) | +pips bonus damage |
| Guard | blue | ALWAYS | gain Block = pips |
| Venom | green | COMBO | apply Poison = pips to target |
| Ember | orange | SIX | 6 damage to ALL enemies |
| Vampire | crimson | COMBO | heal = pips |
| Lucky | gold | KEPT (never rerolled this turn) | +1 reroll next combat turn (max +2 banked) |
| Frost | ice | ONE | target skips its next action (Frozen) |
| Thunder | yellow | REROLLED (rerolled ≥1 this turn) | pips damage to a random enemy |
| Echo | violet | COMBO | combo multiplier +0.5 |
| Heavy | stone | ALWAYS | this die's pips count ×2 in the damage sum |
| Wild | rainbow | ALWAYS | counts as the best value for combo detection (value shown as ★) |
| Gilded | amber | MOVE / COMBO | +pips gold on MOVE; +2 gold on COMBO |

Rarity: Common (Blade, Guard, Venom, Gilded, Heavy), Rare (Ember, Vampire, Lucky, Frost, Thunder), Epic (Echo, Wild).

## 6. Combat (Dicero-style, in place on the board)

- The fight happens **on the landed tile**. Enemies rise out of the ground in a row facing the hero, and the camera dollies to a 3/4 side view. There is no separate screen.
- **Turn:** START runes fire → all dice roll → up to **2 rerolls** (tap dice to mark them, then press Reroll; unmarked dice are kept) → **ATTACK**.
- **Combo table** (on the dice actually rolled; Wild counts as the best value):
  - Five-of-a-kind and above: Six ×15, Five ×10, Four ×5.
  - Full House ×3.5, Straight (5) ×3, Small Straight (4) ×2.5, Three ×2.5, Two Pair ×2, Pair ×1.5.
  - High Roller ×1.
  - "Scoring group" = the dice forming the combo (both pairs for Two Pair, all 5 for Full House/Straight). For High Roller the group is the single highest die. The best combo is chosen by multiplier; ties go to the higher group pip sum.
- **Damage** = (sum of all dice pips, where Heavy counts ×2 + Blade bonuses) × (combo multiplier + Echo bonuses) + hero ATK flat. It goes to the **targeted** enemy (tap to retarget; default is the front enemy). Ember, Thunder and Poison deal their own damage separately.
- Block absorbs enemy damage and resets at the start of the player's turn.
- **Enemy phase:** each living enemy executes its shown **intent**, then rolls its next one. Poison ticks at the start of each enemy's action (damage = stacks, then stacks −1).
- **Intents:** Attack N · Block N · Buff (+2 attack permanently) · Curse (locks 1 random player die for the next turn: it rolls but can't be rerolled) · Summon (boss only).
- **Win:** gold + XP, and the hero does a Cheering animation. **Lose** (HP 0): run over, with a summary screen.
- **Flee:** not allowed. (Positioning is how you avoid fights.)

## 7. Hero and progression

- **Classes** (all unlocked). Each has its own KayKit model and starting setup:
  - **Knight**: 70 HP, 3 dice, one with Guard.
  - **Barbarian**: 60 HP, 3 dice, one with Heavy, +2 ATK.
  - **Mage**: 50 HP, 3 dice, one with Ember and one with Echo, weapon staff.
  - **Rogue**: 55 HP, 3 dice, one with Venom and one with Lucky, +1 board reroll.
- **XP / Level:** fights give XP, with thresholds at 10, 25, 45, 70, 100, … (+30 each). Each level-up is a **draft: choose 1 of 3**: New Die (if the pool has fewer than 6) · Rune for a die · +8 max HP (and heal 8) · +1 combat reroll (max 4) · Face Raise.
- **Gold:** spent at the **Shop** (Start). Stock (3–4 random offers): Die 40g, Rune 35–70g by rarity, Potion (heal 35%) 20g, Face Raise 25g, +1 combat reroll 90g (once per act). Reroll the shop stock for 10g.
- **Meta:** local records only (best act reached, wins per class). No currencies or gacha (explicitly out of scope).

## 8. Events (consumed on landing; presented as a modal card with 1–3 choices)

- **Blessing Shrine:** pick 1 of 2 random rune-free buffs: +1 ATK · +10 max HP · +15 gold · upgrade a random face.
- **Dice Duel:** bet 10/25 gold. You roll 2 dice vs an NPC's 2; higher sum doubles the bet.
- **Monster Outbreak:** the next 3 Empty tiles ahead become Enemy.
- **Flower Garden:** the next 3 Empty tiles ahead become Chests.
- **Wandering Merchant:** trade 10% max HP for a Rare rune.
- **Cursed Idol:** take 15 damage, and your lowest face on every die gets +1.

## 9. Enemies and bosses

All 3D. They use Adventurers/Mannequin meshes with tinted materials, plus the `Rig_Medium`/`Rig_Large` animation clips, including `Skeletons_*`.

| Enemy | Look | HP | Pattern |
|---|---|---|---|
| Skeleton Minion | Mannequin_Medium bone-white, Skeletons_* anims | 12 | Attack 4 / Attack 5 |
| Skeleton Warrior | Mannequin_Medium + sword + shield | 20 | Attack 6 / Block 6 |
| Skeleton Archer | Mannequin_Medium + crossbow | 14 | Attack 8 every other turn |
| Cultist | Mage tinted dark | 16 | Curse / Attack 5 |
| Bandit | Rogue_Hooded | 18 | Attack 7 / Buff |
| Brute | Mannequin_Large tinted | 38 | Attack 12 (charge: Block then Attack) |

Scaling: HP × (1 + 0.35·(act−1) + 0.1·(lap−1)), and attack scales the same way.

**Bosses** (large, 1.6× scale, 2 HP phases, shown as a segmented bar):
- **Bone Warden** (Act 1): Knight tinted bone-white, Large rig. 120 HP. Attack 10 / Block 12 / Summon Minion.
- **Hollow King** (Act 2): Barbarian scaled, with a jack-o'-lantern prop as the head. 180 HP. Attack 14 / Curse ×2 / Buff.
- **The Lich** (Act 3): Mage tinted purple, glowing staff. 260 HP. Phase 2 adds "Chaos": turns one of your dice's faces to 1 for the fight.

## 10. Presentation

- **Camera:** 3/4 perspective at ~50° pitch. Board-overview framing that softly follows the hero. It dollies into a side 3/4 view for combat. Framing adapts to aspect ratio (portrait phone and landscape Mac).
- **Board look:** chunky raised tiles (KayKit BoardGameBits tiles scaled, with colour-coded tops per tile type). A small 3D prop sits on each tile (chest, anvil, banner/skull, campfire/torch, spikes, portal). Enemies are visible **standing on enemy tiles** as a preview (the telegraph). The ring sits on a floating island dressed with the biome's props. The ring's centre holds a hero-facing set piece (crypt, graves or throne).
- **Hero:** KayKit character scaled to fit on a tile. It uses Idle / Jump (hop per tile) / attack by class / Hit / Death / Cheering.
- **Dice tray:** a persistent 3D tray in the bottom HUD (SubViewport). Dice tumble physically-plausibly and settle on the value decided by game logic (never a visible texture swap). Tap to select, marked dice lift and glow, and the combo name and multiplier pop in big type.
- **Lighting and post:** warm key light plus cool fill and soft shadows. Glow and filmic/AgX tonemap, per-act colour grading, subtle fog, ambient particles (dust, embers, fireflies). Forward+ on desktop, Mobile renderer on iOS.
- **UI:** chunky rounded UI in the KayKit style: Fredoka / Lilita One (OFL, downloaded), dark translucent panels with warm gold accents, and big tappable buttons (≥88 px on phone). Floating damage numbers, HP bars over units, and intent icons over enemies.
- **Juice:** hit-stop, camera shake on big combos, coins flying to the HUD counter, a screen flash for ×5+ combos, and tile pulse on landing.
- **Audio:** Kenney CC0 packs (Casino for dice, RPG/Impact/Interface for UI and combat) plus the `mixkit-*.mp3` music beds found in Downloads, one per act. There are Master, Music and SFX volume settings.

## 11. Screens

Title → Class Select → Run (Board HUD / Combat HUD / modal: Draft, Shop, Forge, Event, Portal pick) → Victory / Defeat summary → Title. Pause menu has Resume, Settings (volumes, game speed 1×/2×) and Abandon run.
Auto-save after every resolved board turn, with **Continue** on the title screen.

## 12. Architecture (Godot)

```
project.godot
core/            # pure logic, RefCounted, no Nodes, no rendering → headless-testable
  rng.gd         # seeded xorshift, serialisable
  die.gd         # faces[6], rune id; roll(rng) -> face index
  combo.gd       # evaluate(values[], wild_mask[]) -> {name, mult, group_idx[]}
  runes.gd       # rune defs + trigger resolution helpers
  combat.gd      # CombatState: enemies, intents, player turn API, resolve -> Array[Event]
  board.gd       # 24-tile ring, tile types, mutation, landing options
  run_state.gd   # hero, pool, gold, xp, act, lap, serialise/deserialise
  content/       # data: heroes.gd, enemies.gd, events.gd, shop.gd (const dictionaries)
  game_flow.gd   # top-level run state machine: phases + commands -> events
game/            # presentation: Nodes, listens to events, never mutates rules
  world/         # board_view, biome builder, tile props, environment/lighting
  actors/        # character loader (mesh + retargeted anim libs), hero_view, enemy_view
  dice/          # dice_tray SubViewport, die3d mesh/faces, roll animation
  camera/        # camera rig
  fx/            # particles, damage numbers, shake, hit-stop
  audio/         # AudioBus autoload
ui/              # Theme, HUD, screens, modals
tools/           # screenshot harness autoload, scenario loader, balance sim
tests/           # headless test runner + core tests
assets/          # copied subset of KayKit gltf/glb/png, fonts, audio
```

**Contract:** `core/game_flow.gd` exposes commands (`roll_board()`, `choose_move(die_idx)`, `toggle_reroll(die_idx)`, `reroll()`, `attack(target)`, `pick_draft(i)`, `shop_buy(i)`, …). Each returns `Array[Dictionary]` **events** (`{type:"hero_moved", path:[…]}`, `{type:"combo", name, mult}`, `{type:"damage", target, amount}`…). `game/` plays events back as animations, and the UI binds to state. Presentation never decides outcomes. All randomness goes through the run's seeded RNG, so a seed plus a command log replays exactly.

**Verification harness:** `godot --path . -- --scenario=<name> --shot=<png> [--wait=<sec>]` boots straight into a scenario (e.g. `board_act1`, `combat_act2_boss`, `shop`, `draft`, `title`), waits, saves a screenshot and quits. Every visual task is verified with it. `godot --headless --path . -s tests/run_tests.gd` runs the core tests. `tools/sim.gd` plays N runs with a greedy bot and prints win rate and act reached per class.

## 13. Out of scope (documented follow-ups)

Meta currencies, gear, pets, online features, more than 4 classes, Ranger class, localisation, controller support, archetype "forms" (Greatsword/Hammer/Orb), and extra minigames (claw machine, race).

## 14. Definition of done

- A full run is playable on macOS (the Godot run and an exported .app) and in the iOS Simulator, from title through 3 acts to victory or defeat, with no errors in the log.
- All core tests pass. The balance sim shows a greedy-bot win rate of roughly 20–45% per class.
- Screenshots of every screen and scenario are reviewed and look polished: consistent lighting, no clipping or placeholder art, readable UI at phone and desktop sizes.

## 15. Revisions (2026-09-28, from Vlad)

- **Dice pool:** every class starts with **2 dice**, and the pool maxes out at **5**. This supersedes §5 and §7.
- **Die kinds with unusual faces:** each die has a `kind` whose face set can be any values from 0 to 9, for example Low 1,1,2,2,3,3 · High 4,4,5,5,6,6 · Even · Odd · Loaded · Twin · Gambler 0,0,6,6,6,6 · Giant 4–9.
  - **0 is a blank face:** it moves 0 tiles and never forms a combo. Values above 6 are drawn as numerals.
  - Kinds are sold in the shop and offered in drafts.
  - Combos work over any values: sets use equal non-zero values, and straights use consecutive non-zero values.
- **Board:** a 9×9 ring of **32 tiles**, with corners at 0/8/16/24, replaces the 24-tile ring. Size is a parameter in the rules and the board view.
- **Camera:** the camera zooms in and out with the flow: overview when dice are rolled (all landing targets visible), follow while the hero moves, combat framing for fights, then back.
- **Upgrade pillars, no equipment:** the dice are the equipment. Roguelike growth comes from three things: (a) **dice abilities** (runes), (b) **pip changes** (forge, face upgrades, die kinds), and (c) **passive abilities** ("relics", about 32: about 24 regular plus 8 more powerful **boss-only** passives offered only as boss-kill rewards). Passives come from elites, bosses, the shop and shrine events.
- **Board size:** 9×9 perimeter = 32 tiles (between the 8×8 = 28 and 10×10 = 36 options). It's a parameter, so it's cheap to change.
- **Mini-bosses:** each act spawns one mini-boss on a skull tile ahead of the hero after lap 1 (optional fight; it vanishes when the act boss starts). Mini-bosses and the Act 1/2 bosses reward a choice of 1 of 3 **boss-tier passives**. The Act 3 boss ends the run.
- **Run structure (supersedes §2 acts):** Heroll-style. One run is **15 laps** on a continuous **28-tile board (8×8)**. The biome changes at laps 6 and 11 (Crypt → Hollow → Bone Throne). The **mini-boss appears at lap 7**, and the **final boss comes at lap 15**. The shop opens every 3 laps and at biome changes. Boss-tier passives come from the mini-boss and rare elite drops. Target is about 90–110 board turns per run; auto-save makes long runs fine.
- **Board movement (supersedes §3):** no die choice. Roll the whole pool, and the game auto-selects **two dice**, preferring the most common value (a pair, or two of a set). Ties between values are broken randomly, blank faces are ignored, and if every value is unique it picks 2 random dice. The hero moves by their **sum**. Doubles (the two chosen dice are equal) feed the Treasury and doubles passives. The only player choice is **GO** or a board **Reroll** (rerolls the whole pool). A bigger pool means more doubles, not more control.
- **Replayability, with a new combination every run:** 6 biomes in 3 tiers, one picked per tier each run. Tier 1: Verdant Glade / Crypt · Tier 2: Hollow / Frostpeak · Tier 3: Bone Throne / Magma Depths.
  - Each biome has its own tile mix, a gameplay twist and an enemy roster.
  - The lap-7 mini-boss comes from the tier-2 biome's candidates, and the lap-15 final boss from the tier-3 biome's candidates. There are at least 4 final bosses, each with a unique 2-phase mechanic.
  - The route is shown at run start and on the summary.
  - New biome visuals use KayKit BlockBits terrain (snow, ice, lava, grass, sand) and RPGTools props.
- **Speed and AUTO:** a HUD speed pill cycles 1×/2×/4× (persisted; 4× also condenses repeated beats). An **AUTO** toggle plays decisions with a short visible delay and shows a one-line reason ("Rerolling 2 dice to chase Full House"). Its policy is configurable in Auto settings:
  - Scope toggles: board, combat, drafts, shop, forge, events, portal.
  - Stop conditions: HP below X%, before the mini-boss or boss, when a boss-tier passive is offered, at shops.
  - Focus: balanced, damage, defense or economy.
  - Tapping any game control turns AUTO off.
  - Combat choices use expected value, computed with a private RNG that never touches the run's RNG.

## 16. Meta layer (2026-09-28, from Vlad): Camp, minigames, pets, potions. Non-monetized

Principles: no premium currency, no paid or random rolls for power. Every upgrade has a known cost and a deterministic result. Meta power is bounded, and wins unlock **Ascension** levels to counter it.

- **Potions (in-run):** a potion belt holds 2 (the meta layer upgrades it to 4). A run starts with 1. Using one is a free action at any time, on the board or in combat, and heals 30% max HP. Sources: shop, chests, minigames, pets. Other heals: the lap heal (Heroll-style), campfires, and heal passives.
- **Minigames:** Fossil Hunter (dig grid, find hidden fossils with limited digs), Bubble Breaker (pop same-colour clusters with limited taps), Scratch-off (reveal 3 of 9), Claw Machine (timing grab).
  - Owned minigames are equipped in a **loadout of 2 per run** (a 3rd slot unlocks through meta), and they appear as **minigame tiles** on the board.
  - Each pays an in-run reward (gold, potions, face upgrades) plus its own meta material: Fossils (Workshop), Pearls (Pet Den), Tickets (Arcade), Tokens (Armory).
  - Rules and outcomes are in core and deterministic from the run RNG plus the player's inputs.
- **Camp (hub between runs):** a 3D camp scene. Title → Camp → Start Run (class, pet and minigame loadout) → run → results (Crowns and materials earned) → Camp.
  - **Armory:** Helm (+HP), Blade (+ATK), Boots (+board reroll / move), Charm (+gold). Crafted and levelled with Crowns and Tokens.
  - **Dice Workshop:** permanent starting-dice upgrades. It also unlocks runes, die kinds and passives into the drop pools; a fresh profile starts with a curated subset.
  - **Pet Den:** about 6 pets (familiars built from KayKit props: Pumpkin Sprite heal · Skull Buddy attack · Lantern Ghost burn · Crystal Wisp +reroll · Guard Die block · Coin Mimic gold). One is equipped per run. Each acts in combat on a cooldown and levels up with Pearls.
  - **Arcade:** unlock and upgrade minigames and loadout slots with Tickets and Crowns.
- **Crowns:** awarded at the end of every run from laps, bosses, mini-boss kills and leftover gold. A loss still pays.
- **Profile:** `user://profile.json`, separate from the run save. It holds meta state, unlocks, ascension and records.
- **Balance targets (greedy bot):** fresh profile 15–25% win, mid profile about 35%, maxed profile about 60% at Ascension 0. Each Ascension level adds about 8% enemy HP/attack or removes a heal.

### §16 decisions (Vlad, after the design review `docs/reviews/2026-09-28-meta-design-review.md`)
- **Currencies:** Crowns (every run; levels) + Sigils (milestones only; unlocks) + per-pet XP. The four themed materials are removed.
- **Targets:** maxed profile 45–50% win at Ascension 0; fresh profile about 22–30% (no base-game nerf).
- **Classes:** a fresh profile starts with the **Knight only**. Other classes, biomes, pets, minigames and packs unlock over roughly the **first 15–25 runs**.
- **Minigame skill:** capped at ±15% around par. AUTO plays at 85% of median.
- **Short Road mode:** 10 laps, 2 biomes, pays about 60% Crowns.
- **Pets** fire automatically from charge meters.
- **Adopted from the review:** gear caps and traits; the Workshop holds unlock packs plus a pool toggle; potions heal 30%, belt max 3, one per turn, 4 potion types; one tile per equipped minigame; loss-scaled Crowns with a leftover-gold cap; catch-up bonus; Ascension as 10 global rule levels.
- **Luck and bot realism (Vlad):** the game keeps a real element of luck; even expert play should lose sometimes (expert-bot ceiling about 75–80% on a fresh profile). Balance targets reference a **realistic** bot (the smart policy with human-like imperfection), which is also AUTO's default. Degenerate combos (Wild/Heavy stacking) get mechanic nerfs. There are no broad difficulty hikes aimed at the expert bot.
- **No upgrade per kill (Vlad):** fights pay gold, and pet XP/charge, only. Level-ups are automatic small stat gains (max HP) with no draft. Upgrades come from **shops** (the main source), events, chests, minigames, elites and the mini-boss. The shop cadence and gold income are tuned so the build still grows steadily.
- **Board movement, corrected (Vlad; supersedes the earlier movement bullet):** the move uses the **two pip values with the most dice, one die of each**. Ties are broken randomly, and blanks are ignored. Example: [2,2,2,5,6,6] moves 2 + 6 = 8. If only one value exists, two dice of it move. **Doubles** means the roll contains a pair; doubles feed the Treasury and doubles passives, so bigger pools make doubles more common.
