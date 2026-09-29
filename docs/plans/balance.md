# Diceroll balance

Numbers live in `core/content/` (`balance.gd`, `heroes.gd`, `enemies.gd`, `biomes.gd`,
`dice_kinds.gd`, `passives.gd`, `shop.gd`, `events.gd`, and the meta tables `economy.gd`,
`gear.gd`, `pets.gd`, `potions.gd`, `minigames.gd`, `unlocks.gd`), `core/runes.gd`,
`core/combo.gd` and the profile presets in `core/meta/presets.gd`.

## Current balance (2026-09-28 meta rules + rebalance)

This section is authoritative. Later sections are kept as history; where they disagree with
this one (shop laps, XP, drafts, enemy scaling, combo multipliers, greedy win rates) this one
wins.

### How to measure

```
godot --headless --path . -s tools/sim.gd -- --runs=100 --class=all --seed=1 \
    --policy=greedy|realistic|expert --profile=fresh|mid|max [--asc=N] [--mode=standard|short]
godot --headless --path . -s tools/sim.gd -- --campaign=40 --campaigns=5 --policy=realistic [--snapshot=10]
```

- **Policies.** `greedy` is `Bot.next_command` (the naive floor). `realistic` is `Bot.decide`
  with `AutoRules.skill = "realistic"`: the smart policy with bounded rationality. Per decision it
  lapses with probability `Bot.real_heur` = **0.62** (combat, board, build) into a rule of
  thumb, otherwise it thinks with fewer samples and noisy near-best picks. It is AUTO's default
  and **the balance reference**. `expert` is the full smart policy.
- **Profiles.** `fresh` is a new profile: Knight only, starter pack, the Glade → Hollow → Throne
  route, no pet, no gear, a belt of 2 with 1 Healing Draught. `mid` is the realistic campaign
  at run 10 (`--campaign --snapshot=10`): 3 classes, all biomes, 5 packs, gear L4 with the L4
  traits, Starter Kit, Pumpkin Sprite L4, 3 minigames owned. `max` is everything unlocked and
  maxed, with the Pumpkin Sprite L10, 3 minigame slots and a belt of 3.
- The sim prints each class row machine-readably (`#row`, `#up`), so seed shards can be summed.
  Analysis flags: `--strip=` removes parts of a profile, `--tune-*` dials rescale enemies,
  bosses, gold and shop laps without code edits, `--real-heur=` sets the lapse rate, and
  `--items` prints win rates by held item. Per-class tables, route/boss tables and upgrades
  per run by source are printed as before.

### Targets and results (A0 unless noted, 28-tile board, random routes, all unlocked classes)

Targets (Vlad): realistic fresh 30–40%, mid 45–50%, max 55–65%, max A10 20–30%; greedy fresh
about 15–30%; expert fresh at or below about 75–80%.

Standard mode (15 laps, 3 biomes):

| profile | greedy | realistic | expert |
|---|---|---|---|
| fresh | 15.0% (1000 runs) | **35.8%** (500) | 79.7% (300) |
| mid | 23.3% (900) | **49.2%** (600) | 92.3% (300) |
| max | 32.6% (1200) | **60.8%** (800) | 96.2% (400) |
| max, A10 | 5.3% (1200) | **21.0%** (480) | 71.8% (400) |

Short Road (10 laps, 2 biomes, final boss at 75% HP):

| profile | greedy | realistic | expert |
|---|---|---|---|
| fresh | 20.7% (300) | **37.9%** (240) | 71.0% (100) |
| mid | 31.8% (900) | **52.1%** (720) | 82.0% (300) |
| max | 39.1% (1200) | **58.8%** (960) | 85.5% (400) |
| max, A10 | 5.8% (1200) | **17.3%** (480) | 56.2% (400) |

Short Road A10 sits a little under the standard ladder (fewer shops to absorb A3/A5). It pays
60% of the Crowns (`Economy.SHORT_CROWN_MULT`), with laps and biomes counted at their
standard-run equivalent.

Realistic deaths (fresh, 500 runs): act 1 45, act 2 4, act 3 141, final boss 131. Levels: a
winning run ends around level 6.8, so about 5–7 automatic level-ups.

### Upgrades per run by source (fresh profile, standard mode)

Kills give gold, XP and pet charge only. An "upgrade" is a die, a rune, a face edit, a passive,
+1 combat reroll or a stat blessing; potions and gold are not counted (`run.stats.upgrades`).

| source | greedy | realistic | expert |
|---|---|---|---|
| shop | 9.19 | 11.70 | 12.43 |
| chest (rune choice) | 3.52 | 3.80 | 4.15 |
| elite (passive choice) | 3.01 | 3.73 | 5.30 |
| event | 3.55 | 3.44 | 3.25 |
| Forge tile | 2.22 | 2.23 | 2.07 |
| mini-boss (boss passive) | 0.44 | 0.56 | 0.62 |
| minigame | 0.0 | 0.0 | 0.0 |
| **total** | **21.93** | **25.46** | **27.82** |

Minigame rewards are real but show as 0 here: AUTO's par result is silver, and the bots take the
potion or the gold. A played gold tier offers a rune, a die, a passive or +1 reroll (all counted).
Upgrades are the whole growth curve now: the old level-up drafts gave about 17 per run on top.

### Rule changes in this pass

- **No drafts from kills (Vlad).** Levels are automatic: XP thresholds 25/55/90/130/175/225,
  then +60. Each level gives +`LEVEL_MAX_HP` (4) max HP and heals 4 + 10% of max HP. The
  `level_up` event has `auto: true`, `max_hp_gained` and `healed`, and is followed by
  `hp_changed {source: "level"}`. There is no DRAFT phase after a fight. Elites still give a
  passive choice and the mini-boss a boss-passive choice.
- **Shops are the main source:** they open after laps 1, 3, 5, 6, 8, 10, 12 and 14
  (`Balance.SHOP_LAPS`), or 1, 3, 5, 7 and 9 on the Short Road.
- **Corrected board movement (Vlad).** The move uses one die of each of the two pip values shown
  by the most dice. Ties at any rank are broken with the run Rng. Blanks are ignored unless
  fewer than 2 dice show a value, and a single value moves two of its dice. **Doubles** = the
  most common value shows on 2+ dice. `pair_value` is the higher such value among the moving
  dice. It feeds the Treasury (pair value × 2), Fast Feet's hop, Double Trouble and Coin Mimic.
  The Boots L8 trait now breaks ties toward the higher value.
- **Enemy curve.** HP × (1.0 + 0.35·(lap−1)) and attack × (1.0 + 0.125·(lap−1)), which was
  1.2 + 0.105·(lap−1) for both. The start is gentle (2 dice, no drafts), and late fights are
  long rather than one-shots.

### Mechanic nerfs (degenerate combos)

| change | before | after | why |
|---|---|---|---|
| Four / Five / Six of a Kind | ×5 / ×10 / ×15 | **×4 / ×6 / ×8** | Wild + rerolls turned sets into one-shots (13.5% of expert attacks were Four of a Kind) |
| Resonance, Rune Echo | double every combo rune | **never double Heavy or Echo** | Heavy ×3 pips, Echo +1.0 per die stacking |
| Glass Cannon | ×1.5 damage | **×1.3** | top of the held-item win table |
| Starter Kit | any common kind | **sidegrades only** (Standard, Low, Odd) | Loaded as a starting die was about +5 pp |
| (kept) | | Wild caps at 1 die, Heavy only in the scoring group, each rune acts on at most 2 dice, Vampire heals only on a kill | earlier pass |

### Meta numbers (all deterministic; `core/content/*.gd`)

- **Crowns per run:** 2 per lap (cap 30), 5 per biome after the first, 12 for the mini-boss,
  30 for a win, 2/3/4 per minigame (bronze/silver/gold, plus a bronze "+1 Crown" pick), and
  leftover gold at 1 per 25 (**cap 5**). Then ×(1 + 8% per ascension) × (1 + catch-up). Catch-up
  is +25% from the 3rd loss in a row, capped at +50%, and a win resets it. Short Road pays 60%.
  Measured with the realistic campaign: about **78 Crowns per run**.
- **Crowns sink ≈ 5,930:** gear 15/25/40/70/100/130/160/190 per level (730 per piece), pet
  levels 6–10 at 40/60/80/100/120 each, Whetstone 220, Starter Kit 40, 3rd potion slot 150,
  3rd minigame slot 200. At 78 per run, gear and upgrades are maxed around run 45 and everything
  around run 76.
- **Sigils** come from firsts only (biome 1, mini-boss 1, final boss 2, class win 2, route win 1,
  ascension clear 2, Short Road win 1). Unlock prices: class 8, pet/minigame/pack 6, biome 5,
  boss/mini-boss/gear/potion 4.
- **Gear (caps):** Helm +0.5 HP per level (max +4). Blade +1 ATK at L8. Boots: traps and lava
  −5% per level, and at L6 +1 board reroll per biome (worth about 6 pp on its own). Charm +1.5%
  gold per level (max +12%). Trait pairs at L4 and L8, free to switch: Hearty lap heal +0.5% or
  Camper campfires +10% · Last Stand or Bulwark (Block 4 on turn 1) · Twin Edge +1 on Pair or Long
  Edge +3 on High Roller · Opener ×1.3 or Cleave 50% · Long Stride portal +2 or Sure Foot 3+ ·
  Pathfinder's Eye or Tithe · Haggle (restock 7) or Regular (1 free restock) · Apothecary or
  Interest.
- **Pets** (charge meters persist across fights, fire automatically, and most power comes from
  levels; XP levels at 15/45/90/150 fights won with the pet):

| pet | charges on | size | fires (level L) | acts/run at L10 | max-profile win% at L10 (none: 48.9%) |
|---|---|---|---|---|---|
| Pumpkin Sprite | Pair or better | 6 | heal 2% + 0.4%·(L−1) of max HP | 8.3 | 61.1 |
| Skull Buddy | each die ≤ 2 | 4 | bite 30% + 4%·(L−1) of the hand's combo damage (L5: all enemies at half) | 7.3 | 58.6 |
| Lantern Ghost | each 6 | 5 | poison L on every enemy | 13.1 | 63.3 |
| Crystal Wisp | each kept die | 8 | turn start: +1 reroll and combo ×+(0.1 + 0.03·(L−1)) | 15.7 | 65.8 |
| Guard Die | each attack intent | 6 | Block d6 + (L−1)/2 (L5: half again next turn) | 8.2 | 58.6 |
| Coin Mimic | each board double | 3 | +8 + 3·(L−1) gold and a small bite | 7.6 | 62.2 |

- **Potions:** 30% heal, a belt of 2 (3 with the Armory upgrade, never 4), 1 at run start, and
  at most one per combat turn. Four types: Healing Draught, Stoneskin (Block 15 now and next
  turn), Reroll Tonic (+2 rerolls), and Cleanse (clears Burn, Curse and Chill, heals 10%). A shop
  potion goes on the belt, or is drunk at once when the belt is full.
- **Minigames:** one tile per equipped minigame (2 slots, 3 with the Arcade upgrade), and each
  tile respawns on lap mutation. The score is compared with `MinigameDefs.MEDIAN`: below 0.8 is
  bronze, 0.8 to 1.2 is silver, and 1.2+ is gold. Gold rewards scale by ±15% (the skill band).
  **Players play every minigame (user decision 2026-09-29):** the in-game AUTO pauses on a
  minigame tile ("Your turn: play the minigame") and resumes when switched back on; the screen
  has no AUTO button. The sim and headless bots still take the par result of 0.85 (silver,
  `minigame_auto`) as a stand-in for an average player, which is why the minigame reward rows
  in the tables above count as "par". The run is saved when a minigame starts
  (`minigame_started.save_point`).
- **Fossil Hunter is a luck dig (user decision, no Minesweeper hints):** 7x7 site, three fossils
  (4, 3, 2 long) plus a gem (3 pts) and two coin pouches (2 pts), 10 digs; a dig reveals only its
  own cell. Score = fossil cells dug + each complete fossil's size again + treasure points.
  MEDIAN 8 = the follow-the-bone bot's median (3,000 boards: q25 6, q75 10; tiers 32% bronze /
  36% silver / 31% gold; random digging medians 3). Its gold rewards move only ±5% with the
  score (`MinigameDefs.SKILL_BAND_BY_ID`), the others ±15%.
- **Claw Machine is a capsule pile (user direction, supersedes the fluff/two-claw drafts):**
  18 capsules (10 common, 5 rare, 2 epic, 1 legendary, deeper by tier); the tier colour is
  public, the prize inside is hidden until won (common coins/potion 2-3, rare nugget/gem 3-4,
  epic figure/robot 6, legendary chest 10). A drop scoops up to 3 capsules whose reach
  (0.075 x (1 - 0.8 x depth)) contains it; each held capsule slips out with 0.14 per extra
  capsule held + 0.22 x depth (minigame Rng). 2 grabs. MEDIAN 10: a human-ish aimer (sigma 0.045)
  medians 10 (mean 10.6, q25 6, q75 15); perfect aim medians 17.

### Minigames 2.0 (WP-E5, spec §16 "More minigames")

Seven more Arcade games, all in `core/minigames/<id>.gd` (deterministic from the minigame Rng +
inputs, public state only, save/load mid-game; played by the player, never by AUTO). Every MEDIAN below is calibrated with
`tools/mg_calibrate.gd` (a human-like player with its own noise Rng, 2,000 games each; `--policy=
expert|random` for the bounds), so median play = ratio 1.0 = silver at 1.0x, like the first four.
E[value] = expected prize in gold equivalents (bronze 12, silver 25, gold 45 x skill band); the
review's parity rule (±10% of the mean) holds for all seven new games (mean of all 11 = 29.2).

| game | rules (one thumb) | MEDIAN | human q25-q75 | tiers b/s/g | E[value] | expert / random median | skill band | gold signature |
|---|---|---|---|---|---|---|---|---|
| Bubble Shooter | hex cluster 8 wide, 4 colours, 10 shots aimed with a quantised angle (121 steps, walls bounce); pop 3+ = 1/bubble, dropped = 2/bubble, clear +10 | 43 | 30-54 | 33/36/31 | 29.1 (-0.6%) | 55 / 10 | ±15% | Sharpshooter: +1 ATK (shrine value) |
| Plinko | 8 peg rows, 9 shuffled buckets (1,1,2,2,3,3,5,6,10), pick a slot, 3 drops; golden peg x2 | 16 | 10-22 | 34/35/31 | 27.5 (-5.9%) | 17 / 11 | ±5% | Rare rune for a die |
| Shell Game | 3 cups, 3 rounds: 5/8/11 swaps at 0.46/0.34/0.25 s; right pick 2/3/4, x2 within 1.2 s of the shuffle (Sharp Eye) | 11 | 8-14 | 30/35/34 | 30.3 (+3.5%) | 18 / 3 | ±15% | Heart Gem: +10 max HP (shrine value) |
| Memory Match | 4x4, 8 pairs (faces 1-6, Star, Skull), 6 misses; 2 per pair, +1 per miss left on a clear | 9 | 6-12 | 33/32/35 | 30.2 (+3.4%) | 18 / 0 | ±15% | Mirror Forge: 2 edits, raise or mirror |
| Fishing | 3 casts at shallows / reeds / deep; strike in the bite window (0.8/0.62/0.48 s), fake nibbles before; fish 1-10, perfect strike +1 | 11 | 7-14 | 33/41/26 | 27.1 (-7.2%) | 16 / 0 | ±10% | The Catch: Healing Draught + another potion |
| Lucky Wheel | 12 shuffled segments (2..12), 2 spins, one brake tap in the last 1.1 s | 13 | 10-17 | 28/38/35 | 29.1 (-0.5%) | 16 / 10 | ±5% | Uncommon passive (1 of 3) |
| High-Low Ladder | d6 higher/lower, ladder 2,5,6,7,9,11,14,18,24, safety rungs 0/1/3/5, push on equal, cash out any time | 6 | 5-7 | 21/54/24 | 28.2 (-3.5%) | 5 / 2 | ±10% | High Roller: every die's lowest face +1 |

Notes: Memory Match's and High-Low's scores are lumpy (even pair scores; ladder rungs), so their
MEDIAN sits between the two central outcomes (memory 8|10 -> 9; high-low's rungs map bust -> bronze,
rungs 1-3 -> silver, 4+ -> gold). The human models: shooter best-looking shot 65% else a decent
one, aim noise sd 2 steps; plinko best-odds slot 50%, above the top bucket 30%, random 20%;
shell loses track per gem-moving swap 2.5/6/11% and taps at once 70% when sure; memory forgets
a seen card with 0.97 x 0.9^turns; fishing deep 45% / reeds 35% / shallows 20%, fooled by a
nibble 12%, reaction 0.34 ± 0.09 s; wheel brakes on the best window segment 65% (± 0.09 s);
high-low cashes at a personal nerve (rung 4-7, or 2-4 when the die shows 3 or 4).
The first four keep their numbers; for reference the same tool measures them at fossil 27.8,
bubble breaker 38.0 (its bot always takes the biggest cluster: a perfect player), scratch-off
21.9 (only 3.5% gold by design) and claw 32.4.

**Arcade unlocks (minor unlocks, one milestone each, Sigils 6 as before):** the realistic
campaign (`--campaign=30 --campaigns=8`) gets them at the median runs below, spread between the
class/biome majors (never two minigames on one run).

| minigame | milestone | condition | target run | campaign median |
|---|---|---|---|---|
| Plinko | arcade_newbie | Play 6 minigames | 2 | 2 |
| (Fossil Hunter) | arcade_regular | Play 14 minigames | 5 | 4 |
| High-Low Ladder | lucky_streak | Cash out the Treasury 12 times | 6 | 5 |
| Fishing | angler | Complete 105 laps in total | 8 | 8 |
| Memory Match | sharp_memory | Keep 1,350 dice unrerolled | 9 | 10 |
| Bubble Shooter | arcade_ace | Play 30 minigames | 11 | 11 |
| (Bubble Breaker) | arcade_fan | Play 40 minigames | 13 | 14 |
| Shell Game | sleight_of_hand | Use 1,500 combat rerolls | 16 | 17 |
| Lucky Wheel | high_roller | Play 56 minigames | 20 | 21 |

### Ascension (global, 10 levels, max profile, realistic bot, standard mode)

| A | rule | win% |
|---|---|---|
| 0 | none | 60.8 |
| 1 | lap mutations spawn +1 Elite, and elites have +15% HP | 58.5 |
| 2 | lap heal 10% → 8% | 56.4 |
| 3 | shops +10%, restock 12 | 52.2 |
| 4 | the mini-boss gains a trait, and skipping it gives the boss +10% HP | 49.7 |
| 5 | start with 0 potions | 44.4 |
| 6 | enemies (not bosses) +4% HP and attack | 37.3 |
| 7 | each new biome curses a face to 1 until you use a Forge | 32.8 |
| 8 | traps, ice and lava ×1.5, and +1 hazard tile | 29.4 |
| 9 | the final boss starts with its phase-2 traits and +5% HP | 27.2 |
| 10 | double final: the route's other boss at 40% HP | 21.0 |

A win at the highest unlocked level unlocks the next one. The game is very sensitive to enemy
stats: +12% HP and attack at A6 once cost 15 pp.

### Unlock pacing (fresh profiles, realistic bot, `--campaign=40`, 40 profiles × 40 runs)

The campaign bot plays the least-played class, equips owned minigames and the highest-level pet,
and after each run spends greedily. It buys the cheapest item first, with one-off Camp upgrades
at half weight, and spends Sigils in class → pack → pet → minigame → biome order. The table
gives the median run at which each unlock arrived, whether by milestone or by Sigils, whichever
came first.

| run | unlocks |
|---|---|
| 1 | Helm, Pumpkin Sprite, Barbarian (Sigils), and on a first win Colossus pack, Magma, Cinder King, Magma Golem |
| 2 | Blade gear, Crypt |
| 3–5 | Gambler's Kit, Boots, Stoneskin, Cold Steel, Fossil Hunter |
| 6–7 | Frostpeak, 3rd potion slot (purchasable), Charm, Skull Buddy, Numerology |
| 9–12 | Reroll Tonic, Mage (11.5), Storm, Grave Mage |
| 14–15 | Crystal Wisp, Bubble Breaker, 3rd minigame slot (purchasable), Cleanse, Rogue (15), Resonance |
| 15.5–19.5 | Lantern Ghost, Coin Mimic, Pyromancy, Guard Die, Bone Champion, Bone Warden |
| 20–24 | Frost Warden, Briar Beast, Cinder Brute |

The campaign's win rate by run is about 45–55% over runs 1–5, 55–70% over runs 8–25, and
60–70% after run 30. Crowns run about 70–87 per run, and Sigils go from 6.2 on run 1 to under
1 per run after run 10.

### Tools and sweep notes

- The pp values measured by `--strip` at max: all packs beyond the starter about −12, belt 3 about −6,
  Whetstone about −6, a L10 pet +10–17, and gear L5–8 about −4. The mid profile (run 10) moved
  from 72% to 49% after these fixes: the Boots reroll moved to L6, Hearty went to +0.5%,
  Whetstone to 220 Crowns, Haggle to restock 7, and pet power was backloaded to levels 6–10.
- `Bot.danger_lo/hi` (0.8 / 1.2): the greedy bot rerolls away from fights that would cost about
  that share of its HP in two enemy turns.

## History (earlier passes)

Re-run the sim with:

```
godot --headless --path . -s tools/sim.gd -- --runs=300 --class=all --seed=1 [--board=24|28|32]
    [--route=glade,frost,magma] [--boss=boss_lich]
```

Without `--route` every run draws its own route and bosses from its seed. The sim prints the
class table, then win% per route, per final boss, per route + boss (with "reached boss%" and
"boss win%" = wins / runs that reached the boss) and the mini-boss fight win%.

## Run structure (Heroll-style, 2026-09-28 revision)

- **One board, 15 laps.** A run is 15 laps ("floors") on one continuous ring. The default ring
  is **28 tiles** (8x8 perimeter, corners 0/7/14/21: Start, Forge, Treasury, Portal). Ring size
  is a parameter: `GameFlow.new_run(class, seed, board_size)` accepts 24 (7x7), 28 (8x8) and
  32 (9x9). Any 4(n-1) with n >= 5 works, with tile counts scaled from the 24 layout.
- **Biomes (routes).** Act 1 = laps 1–5 (tier 1), act 2 = laps 6–10 (tier 2), act 3 = laps
  11–15 (tier 3). At run start one biome per tier is drawn: tier 1 `glade`/`crypt`, tier 2
  `hollow`/`frost`, tier 3 `throne`/`magma` (8 routes; see "Biomes and routes" below). When
  lap 6 or lap 11 starts, the board is **regenerated** in the route's next biome around the hero.
  The hero keeps their position, their landing tile is never a fight, and they heal 30%.
  `act_started` fires at that point.
- **Shop** after completing laps 1, 3, 5, 6, 8, 10, 12 and 14 (2026-09-28 rebalance; it was laps
  3, 6, 9 and 12 plus the biome changes).
- **Mini-boss.** When lap 7 starts, one `miniboss` tile appears with the run's mini-boss
  (`run.miniboss_id`, drawn at run start from the tier-2 biome's candidates). It lasts until it
  is beaten, or until lap 11 regenerates the board.
- **Final boss.** Completing lap 15 stops the hero on Start and starts the run's final boss
  (`run.boss_id`, drawn at run start from the tier-3 biome's candidates). Winning is VICTORY.
  The Hollow King is no longer in the run; its content id is kept.
- **Movement is automatic.** `roll_board()` rolls the whole pool and picks two dice. The move is
  their sum (0..18). The only choice is to reroll or go (`board_reroll()` / `confirm_move()`).

## Final sim of the pre-meta pass (greedy Bot, 500 runs per class, board 28, seed 1, random routes; superseded)

| class | win% | avg act | avg lap | avg board turns | avg combat turns | avg commands | avg level | avg fights won | deaths |
|---|---|---|---|---|---|---|---|---|---|
| knight | 37.6 | 2.94 | 14.3 | 48.1 | 49.6 | 416 | 15.0 | 19.1 | act1:5 act2:17 act3:155 boss:134 mini:1 |
| barbarian | 34.8 | 2.94 | 14.3 | 47.8 | 46.8 | 398 | 14.7 | 18.8 | act1:7 act2:15 act3:151 boss:150 mini:3 |
| mage | 27.2 | 2.89 | 14.0 | 47.1 | 45.8 | 393 | 14.4 | 18.4 | act1:15 act2:24 act3:148 boss:175 mini:2 |
| rogue | 35.8 | 2.94 | 14.4 | 48.4 | 48.7 | 423 | 14.9 | 19.2 | act1:4 act2:19 act3:114 boss:180 mini:4 |

Win% per route, per final boss and per route + final boss, over all classes. "reached boss%"
is the share of runs that got to the lap-15 fight; "boss win%" is wins / runs that reached it.

| route | win% | runs | reached boss% | boss win% |
|---|---|---|---|---|
| crypt,frost,magma | 29.7 | 232 | 68.1 | 43.7 |
| crypt,frost,throne | 32.1 | 252 | 67.5 | 47.6 |
| crypt,hollow,magma | 39.2 | 232 | 67.7 | 58.0 |
| crypt,hollow,throne | 33.6 | 220 | 64.5 | 52.1 |
| glade,frost,magma | 32.1 | 280 | 67.9 | 47.4 |
| glade,frost,throne | 36.6 | 292 | 64.7 | 56.6 |
| glade,hollow,magma | 32.7 | 248 | 62.5 | 52.3 |
| glade,hollow,throne | 34.4 | 244 | 63.5 | 54.2 |

| final boss | win% | runs | reached boss% | boss win% |
|---|---|---|---|---|
| boss_bone_warden | 29.8 | 496 | 63.1 | 47.3 |
| boss_cinder_king | 33.5 | 516 | 66.1 | 50.7 |
| boss_lich | 38.7 | 512 | 67.0 | 57.7 |
| boss_magma_golem | 33.2 | 476 | 67.0 | 49.5 |

| route / final boss | win% | runs | reached boss% | boss win% |
|---|---|---|---|---|
| crypt,frost,magma / boss_cinder_king | 30.7 | 88 | 69.3 | 44.3 |
| crypt,frost,magma / boss_magma_golem | 29.2 | 144 | 67.4 | 43.3 |
| crypt,frost,throne / boss_bone_warden | 26.8 | 112 | 64.3 | 41.7 |
| crypt,frost,throne / boss_lich | 36.4 | 140 | 70.0 | 52.0 |
| crypt,hollow,magma / boss_cinder_king | 40.4 | 136 | 66.9 | 60.4 |
| crypt,hollow,magma / boss_magma_golem | 37.5 | 96 | 68.8 | 54.5 |
| crypt,hollow,throne / boss_bone_warden | 28.4 | 116 | 63.8 | 44.6 |
| crypt,hollow,throne / boss_lich | 39.4 | 104 | 65.4 | 60.3 |
| glade,frost,magma / boss_cinder_king | 31.1 | 148 | 67.6 | 46.0 |
| glade,frost,magma / boss_magma_golem | 33.3 | 132 | 68.2 | 48.9 |
| glade,frost,throne / boss_bone_warden | 32.9 | 164 | 62.2 | 52.9 |
| glade,frost,throne / boss_lich | 41.4 | 128 | 68.0 | 60.9 |
| glade,hollow,magma / boss_cinder_king | 31.2 | 144 | 61.8 | 50.6 |
| glade,hollow,magma / boss_magma_golem | 34.6 | 104 | 63.5 | 54.5 |
| glade,hollow,throne / boss_bone_warden | 29.8 | 104 | 62.5 | 47.7 |
| glade,hollow,throne / boss_lich | 37.9 | 140 | 64.3 | 58.9 |

The bot wins its optional mini-boss fights about 98–100% of the time (it only walks onto the
skull tile above 60% HP), for every mini-boss.

Seed 4242 (300 runs per class): knight 36.0, barbarian 35.7, mage 28.0, rogue 34.3; bosses:
Bone Warden 35.4, Cinder King 33.7, Lich 38.2, Magma Golem 27.7.

Other ring sizes (seed 1, 300 runs per class):

| board | knight | barbarian | mage | rogue |
|---|---|---|---|---|
| 24 | 39.7 | 31.3 | 24.7 | 25.7 |
| 28 (default) | 37.6 | 34.8 | 27.2 | 35.8 |
| 32 | 40.7 | 32.7 | 24.3 | 29.0 |

Every run finished with zero error events and zero command-cap hits. The sim exits 1 on either.

About the numbers:
- **"avg board turns"** counts every run, deaths included. A run that reaches the final boss
  takes about 15 × 28 / 8 ≈ 52 board turns on 28 tiles.
- **"avg act"** is the biome the run ended in. A victory counts as act 3.
- **Deaths** are keyed by where they happened: `act1` means a regular fight or trap in laps 1–5,
  `act2` laps 6–10, `act3` laps 11–15, `mini` the mini-boss and `boss` the final boss. About a
  third of all runs die in act 3 and a third at the final boss.
- Tier-3 boards are balanced so both reach the boss about 65% of the time: Magma's lava and
  burns cost HP on the way, the Bone Throne's extra elites and bone knights fight harder.

## AUTO policy (smart bot) vs greedy

The player-facing AUTO (`Bot.decide(flow, rules)`, rules in `core/auto_rules.gd`) plays far
better than the greedy `Bot.next_command()`. The greedy bot stays the balance reference; content
was **not** rebalanced for the smart bot. Re-run with:

    godot --headless --path . -s tools/sim.gd -- --runs=300 --class=all --seed=1 --policy=smart [--focus=balanced|damage|defense|economy]

The sim plays AUTO with `AutoRules.all_on(focus)` (every scope on, no stop conditions) and prints
decide() timings. 300 runs per class, board 28, seed 1, random routes:

| class | greedy win% | smart balanced | smart damage | smart defense | smart economy |
|---|---|---|---|---|---|
| knight | 37.3 | 89.0 | 79.7 | 95.3 | 81.7 |
| barbarian | 35.3 | 88.3 | 74.7 | 97.3 | 86.0 |
| mage | 24.7 | 90.0 | 75.7 | 95.0 | 85.3 |
| rogue | 34.7 | 91.3 | 76.0 | 96.7 | 81.3 |

- Smart deaths are almost all in act 3 regular fights; it rarely loses to the final boss (greedy
  loses a third of its runs there).
- **Wild and Heavy stacking dominates.** Smart runs end with mostly Heavy (≈2.5 per run) and
  Wild (≈1.8 per run) dice. Several Wild dice turn every roll into Four/Five/Six of a Kind
  (×5/×10/×15): over 120 smart runs, runs ending with 3+ Wild dice won 35/36, with none 13/20.
  If AUTO should not out-play humans this much, the lever is Wild (epic rune weight, or capping
  the Wild multiplier), not the bot.
- Defense focus beats balanced: HP is the binding constraint in act 3. Balanced already weighs HP
  1.3x (`Bot.FOCUS`); damage focus trades HP for kill speed and loses more act-3 runs.

How AUTO decides (all scoring in "PV points" ~ one damage per combat turn for the rest of the run):

- **Combat:** every keep-set of the free dice (not cursed, not Wild) is valued by expected value
  over the remaining rerolls: exact enumeration up to 36 outcomes, else 96 common-random-number
  samples (64 with 6 dice); V1 = E[S], Vr = E[max(S, V(r-1))]. S scores a final hand against the
  best target: damage (overkill wasted, ward/Block applied), kills (prevents that enemy's intent
  now plus its future threat), Guard Block vs incoming intents, poison, Ember, Thunder, Frost,
  heals, gold and Lucky banks, with a death penalty. One step per call: mark dice one at a time,
  reroll, set the target, attack.
- **Board:** reroll-or-go compares the landing tile's value with the expected value of a reroll
  (96 simulated pool rolls through `GameFlow.pick_move_dice`). Tile values: fights by rewards vs
  estimated HP loss and death risk, campfires by missing HP, traps/lava/ice by expected damage,
  the mini-boss per `fight_miniboss`, the final boss by missing HP.
- **Drafts, shop, forge, events, runes, passives:** deltas of pool value (a single-roll
  simulation of the pool against two dummy enemies), so synergy is automatic: Echo/Wild gain with
  pool size, Heavy/Blade go on high-face dice, face raises/mirrors on dice that form combos.
  Non-combat passives use estimates. Focus multiplies each category (damage, defense, economy).
  The shop buys the best value per gold, keeps 40 gold for the next shop's die while the pool has
  room, restocks once when rich, then leaves.
- **Purity:** decide() never mutates the flow or advances the run's Rng; samples come from a
  private Rng seeded by a hash of the state. Decisions are deterministic.
- **Timing** (tests/test_bot_perf.gd, cold caches, single process on the dev Mac): combat
  decide() median 1–13 ms with 5 dice and 17–23 ms with 6; a whole run averages ~1.4 ms per call
  with a 15 ms max. With 16 sims running in parallel the max per call rose to ~50–65 ms.

## Biomes and routes (`core/content/biomes.gd`)

Each run draws one biome per tier with the run Rng (`run.route`, serialised), then its mini-boss
from the tier-2 biome's candidates and its final boss from the tier-3 biome's candidates
(`run.miniboss_id`, `run.boss_id`, serialised). The draws always happen, so forcing a route
(`new_run(class, seed, size, {route, miniboss, boss})`) does not shift the rest of the random
stream. That gives 8 routes × 2 mini-bosses × 2 final bosses = 32 combinations.

| tier (laps) | id | name | tile mix vs base (28 tiles) | twist (`biome_desc`) | mini-boss candidates | final-boss candidates |
|---|---|---|---|---|---|---|
| 1 (1–5) | `glade` | Verdant Glade | +1 campfire, +1 chest (3 / 5) | Campfires heal 45% instead of 30%. | (`mini_briar_beast`, unused) | – |
| 1 (1–5) | `crypt` | The Crypt | +2 trap (4) | A dodged trap (roll 4+) drops 6 gold (× lap gold scale). | (`mini_bone_champion`, unused) | – |
| 2 (6–10) | `hollow` | The Hollow | +2 event (6; lap top-up also refills to 6) | Finishing an event heals 8% max HP. | `mini_pumpkin_knight`, `mini_grave_mage` | – |
| 2 (6–10) | `frost` | Frostpeak | traps become **`ice`**, +1 (3 ice, 0 trap) | Ice: roll 4+ dodges; otherwise 1 die (max 2 banked) is locked on turn 1 of the next fight. No damage. | `mini_frost_warden`, `mini_bone_champion` | – |
| 3 (11–15) | `throne` | Bone Throne | +1 elite −1 enemy (2 elites with the act-3 swap); lap mutation spawns 2 elites + 1 enemy | Elites roll a boss-tier passive 30% of the time (15% elsewhere). | – | `boss_lich`, `boss_bone_warden` |
| 3 (11–15) | `magma` | Magma Depths | +3 **`lava`** | Lava: 2% max HP per lava tile passed over, 6% when landed on. Never lethal (stops at 1 HP). Persistent. | (`mini_cinder_brute`, unused) | `boss_cinder_king`, `boss_magma_golem` |

- Tile mixes are deltas on the base layout; Empty absorbs the difference (24 and 32 tiles work).
  `Board.layout_for(size, biome)` returns the counts. A board built without a biome (`biome`
  "") uses the base layout and the legacy band pools, so old scenarios still work.
- Enemy pools: the biome's `pools[0]` for the tier's first 3 laps, `pools[1]` for the last 2.
  Elite tiles lead with the biome's `elite` (plus one pool enemy from band 2 on). Counts per
  tile still follow `EnemyDefs.COUNTS` by lap band.

| biome | early pool | late pool | elite leader |
|---|---|---|---|
| glade | thorn_sprite, wolf_bandit, skeleton_minion | thorn_sprite, wolf_bandit, skeleton_archer, bandit | brute |
| crypt | skeleton_minion ×2, skeleton_archer | skeleton_minion, skeleton_archer, skeleton_warrior, cultist | brute |
| hollow | skeleton_archer, cultist, hollow_wisp, bandit | cultist, bandit, hollow_wisp, skeleton_warrior | brute |
| frost | frost_skeleton, ice_archer, skeleton_warrior | frost_skeleton, ice_archer, skeleton_warrior, bandit | brute |
| throne | skeleton_warrior, bone_knight, cultist, brute | bone_knight ×2, brute, cultist | bone_knight |
| magma | ember_imp ×2, skeleton_warrior, bandit | ember_imp, magma_brute, brute, cultist | magma_brute |

## Enemies, mini-bosses and final bosses (`core/content/enemies.gd`)

New intents: `heal` (heals every living enemy by N, scaled like Block), `drain` (attack; the
enemy heals by the damage that got through), `burn` (adds N Burn stacks to the hero; scales at
half the attack rate), `chill` (attack, then 1 of your dice is locked next turn), `scorch` (one
of your non-blank faces becomes 0 for the fight; restored after a win, like Chaos).

Traits (enemy dict field `traits: Array[String]`; bosses change traits per phase):
`armor` (its Block never expires), `thorns` (your main attack on it reflects 3 damage to you,
never lethal), `ward` (takes half damage, rounded up, while any summoned ally lives), `pierce`
(its attacks ignore your Block).

Hero Burn: stacks tick at the **end of every enemy phase**, ignoring Block (damage = stacks,
then stacks −1). Burn can kill (Phoenix/Second Wind apply). It ends with the fight.

Regular enemies (14; base stats before lap scaling):

| id | name | HP | pattern | biomes |
|---|---|---|---|---|
| skeleton_minion | Skeleton Minion | 12 | random: attack 4 / attack 5 | glade, crypt |
| skeleton_warrior | Skeleton Warrior | 20 | random: attack 6 / block 6 | crypt, hollow, frost, throne, magma |
| skeleton_archer | Skeleton Archer | 14 | cycle: aim → attack 8 | glade, crypt, hollow |
| cultist | Cultist | 16 | cycle: curse 1 → attack 5 | crypt, hollow, throne, magma |
| bandit | Bandit | 18 | cycle: attack 7 → buff 2 | glade, hollow, frost, magma |
| brute | Brute | 38 | cycle: block 8 → attack 12 | elite leader; throne, magma |
| **thorn_sprite** | Thorn Sprite | 10 | cycle: heal 4 (all allies) → attack 4 | glade |
| **wolf_bandit** | Wolf Bandit | 15 | cycle: attack 3 → attack 4 → attack 9 (pounce) | glade |
| **hollow_wisp** | Hollow Wisp | 12 | cycle: drain 5 → block 4 | hollow |
| **frost_skeleton** | Frost Skeleton | 18 | cycle: curse 2 → attack 6 → block 5 | frost |
| **ice_archer** | Ice Archer | 13 | cycle: aim → chill 7 | frost |
| **bone_knight** | Bone Knight | 34 | cycle: block 6 → attack 10 → buff 2; trait armor | throne (elite leader) |
| **ember_imp** | Ember Imp | 11 | random: burn 2 / attack 5 | magma |
| **magma_brute** | Magma Brute | 36 | cycle: burn 2 → block 8 → attack 12 | magma (elite leader) |

Mini-bosses (scaled like regular enemies; 1 of 3 boss-tier passives as the reward):

| id | name | HP | pattern | mechanic | used by |
|---|---|---|---|---|---|
| mini_pumpkin_knight | Pumpkin Knight | 105 | curse 1 → attack 9 → attack 11 → buff 2 | escalates: curses, then buffs its attack | hollow |
| mini_grave_mage | Grave Mage | 100 | summon → attack 10 → chaos → attack 12 | summons minions, Chaos turns a face to 1 | hollow |
| mini_frost_warden | Frost Warden | 105 | chill 8 → curse 2 → attack 11 → block 8 | locks your dice every other turn | frost |
| mini_bone_champion | Bone Champion | 110 | attack 9 → block 10 → attack 12; trait armor | Block piles up (armor) | frost |
| mini_briar_beast | Briar Beast | 110 | attack 8 → heal 10 → attack 10; trait thorns | reflects 3 per hit, regrows | (glade candidate, unused while mini-bosses come from tier 2) |
| mini_cinder_brute | Cinder Brute | 110 | burn 3 → attack 11 → block 10 | Burn damage over time | (magma candidate, unused) |

Final bosses (unscaled; phase 2 at or below half HP):

| id | name | HP | phase 1 | phase 2 | unique mechanic | biome |
|---|---|---|---|---|---|---|
| boss_lich | The Lich | 1650 | attack 22 / curse 1 / block 30 | attack 26 / chaos / attack 22 / curse 1 | Chaos: one of your faces becomes 1 for the fight | throne |
| boss_bone_warden | Bone Warden | 1150 | attack 20 / block 28 / summon 1 | summon 2 / attack 24 / attack 20 / block 24; trait ward | Bone Legion: summons lap-scaled Skeleton Warriors; half damage while any stands | throne |
| boss_cinder_king | Cinder King | 1200 | burn 4 / attack 20 / block 24 | scorch / attack 24 / burn 5 / attack 20 | Burns you; Scorch turns one of your faces to 0 (blank) for the fight | magma |
| boss_magma_golem | Magma Golem | 800 | block 32 / attack 22 / attack 26; trait armor | attack 24 / attack 28 / buff 3; trait pierce | Molten shell: its Block never expires. Phase 2 the shell shatters (all Block lost) and its attacks pierce your Block | magma |
| boss_hollow_king | Hollow King | 380 | – | – | unused (content kept) | – |

## Presentation ids and look hints

Every new id the presentation layer needs, with a look hint (KayKit meshes + tints; BlockBits
terrain for new biome visuals).

| kind | id | look hint |
|---|---|---|
| biome | glade | Verdant Glade: BlockBits grass, bright greens, flowers and trees, warm daylight, fireflies |
| biome | crypt | The Crypt: existing Dungeon look (grey stone, torches, banners) |
| biome | hollow | The Hollow: existing Halloween look (autumn trees, graves, pumpkins, orange dusk) |
| biome | frost | Frostpeak: BlockBits snow + ice, pale blue fog, cold rim light, snowfall particles |
| biome | throne | Bone Throne: existing act-3 look (purple/teal night, crypt building, bones) |
| biome | magma | Magma Depths: BlockBits lava + dark basalt, red-orange glow, rising embers, heat haze |
| tile | ice | slick pale-blue ice slab with frost sparkle (Frostpeak's trap); on a slip, a snowflake pops onto one die |
| tile | lava | glowing orange lava block, bubbling, ember particles; flashes red when passed over |
| enemy | thorn_sprite | small (0.8×) Mannequin_Medium tinted leaf green, vine/leaf particles; green glow on heal |
| enemy | wolf_bandit | Rogue_Hooded tinted forest brown with a grey fur cloak |
| enemy | hollow_wisp | Mannequin_Medium, translucent ghostly teal, floating, soft glow |
| enemy | frost_skeleton | skeleton (Skeletons_* anims) tinted icy blue |
| enemy | ice_archer | Mannequin_Medium + crossbow, frosted white-blue tint |
| enemy | bone_knight | Knight tinted bone white with dark purple trim, sword + shield |
| enemy | ember_imp | small (0.75×) Mannequin tinted charcoal with an orange emissive glow |
| enemy | magma_brute | Mannequin_Large tinted basalt black with glowing orange cracks |
| mini-boss | mini_frost_warden | Knight at 1.3×, icy blue tint, frost aura particles |
| mini-boss | mini_briar_beast | Mannequin_Large tinted moss green with brown thorns |
| mini-boss | mini_cinder_brute | Mannequin_Large tinted charred black with orange embers |
| mini-boss | mini_bone_champion | (existing) bone-white knight; its Block persists, so show a stacking stone-plate shield |
| boss | boss_bone_warden | Knight tinted bone white, Large rig, 1.6×; phase 2: purple ward shimmer while minions stand |
| boss | boss_cinder_king | Barbarian tinted ember orange/black with a crown, flame particles |
| boss | boss_magma_golem | Mannequin_Large at 1.8×, grey rock shell over lava glow; phase 2: shell cracks off, glowing orange |
| intent | heal | green plus |
| intent | drain | red fang dripping into a heart |
| intent | burn | flame with the stack count |
| intent | chill | sword + snowflake (attack, then a die locks) |
| intent | scorch | flame over a die face |
| status | burn (hero) | flame badge with stacks on the hero HP bar |
| status | chill (hero) | snowflake on the die that will lock |
| status | scorch | the affected face drawn blackened as a blank (0) with embers |
| trait | armor | stone plating on the enemy's Block badge |
| trait | thorns | bramble ring around the enemy |
| trait | ward | shimmering shield dome while minions live |
| trait | pierce | cracked-shield icon on the enemy's attack intent |

## Contract additions (biomes and routes)

- `GameFlow.new_run(class_id, seed, board_size = 28, opts = {})`: `opts` may carry `route`
  ([tier1, tier2, tier3] ids), `miniboss` and `boss` ids. Invalid values are ignored.
  `GameFlow.replay(class_id, seed, log, board_size, opts)` takes the same `opts`.
- `GameFlow.route_info() -> {route: [{id, name, desc}] ×3, miniboss: {id, name}, boss: {id, name}}`.
- `RunState.route: Array[String]`, `miniboss_id`, `boss_id`, `chill` (dice to lock on the next
  fight's turn 1) and `biome()` (current biome id); all serialised. Old saves load with the
  legacy route (crypt, hollow, throne), the Pumpkin Knight and the Lich.
- `Board.biome` (serialised in `to_dict().biome`), `Board.generate(rng, act, size, lap, biome)`,
  `Board.layout_for(size, biome)`, `Board.mutate_spawns_for(size, biome)`,
  `Board.enemy_pool(lap, biome)`, `Board.roll_enemies(rng, act, lap, elite, biome)`.
- `debug_open("boss", id)` and `debug_open("miniboss", id)` (default: the run's picks).
- Events:
  - `act_started` gains `biome_name`, `biome_desc`; `biome` is the route's id (any of the 6).
  - `trap` on an ice tile: `{roll, dodged, damage: 0, ice: true, chill}`, plus
    `status {target: "hero", status: "chill", value, pending: true}` on a slip.
  - `lava {idx, damage, landed}` + `hp_changed {source: "lava"}` (passing tiles fire after
    `hero_moved`, in path order).
  - `status {target: "hero", status: "chill", value}` at combat start when frozen dice lock.
  - `status {target: "hero", status: "burn", value: stacks}`, `damage {target: "hero", source:
    "burn"}`; `status {status: "scorch", die_idx, face_idx}` (restored by `face_changed` after a
    win); `status {status: "curse", chill: true}` from chill attacks.
  - `enemy_healed {enemy_idx, amount, hp, max_hp, source: "heal"|"drain"}`.
  - `damage` gains `warded` (enemy targets) and `pierce` (hero target); thorns reflect is
    `damage {target: "hero", source: "thorns"}`.
  - `boss_phase` gains `traits`; `block_gained {source: "shatter"}` when the Golem's shell breaks.
  - `gold_changed {source: "crypt"}`, `hp_changed {source: "hollow"}`.
  - `game_over.stats` gains `route`, `boss_id`, `miniboss_id`.
- Enemy dictionaries gain `traits`; `CombatState` gains `hero_burn` (serialised).

## Numbers changed in this revision

| what | before | now | why |
|---|---|---|---|
| Starting dice / max pool | 3 / 6 | **2 / 5** | Revision §15. The pool grows through drafts, the shop and the Dicesmith. |
| Board | 24 tiles × 3 laps × 3 acts | **28 tiles × 15 laps**, biomes at laps 6/11 | Heroll-style run |
| Movement | pick one die | **automatic pair, move = sum** | Revision |
| Enemy scaling | 1 + 1.0·(act−1) + 0.25·(lap−1) | **1.2 + 0.105·(lap−1)**, laps 1..15 (1.2 → 2.67) | Smooth by lap. Early fights matter with 2 dice. |
| Enemy bands | act + lap − 2 | **(lap − 1) / 3** → 0..4 | Smooth by lap |
| Band 0 enemies per tile | 1–2 | **2** | Early threat |
| Gold scaling | ×(1 + 0.25·(act−1)) | **×(1 + 0.05·(lap−1))** | By lap |
| Lap heal | 15% | **10%** | 15 laps of healing |
| New-act heal | 50% | **30% at a biome change** | Revision |
| XP thresholds | 10/25/45/70/100, +30 | **6/14/24/36/50, +18** | Fewer fights per lap with automatic movement |
| The Lich HP | 800 | **1650** (1300 before routes) | The final boss; biome twists made heroes stronger |
| Bone Warden | act 1 boss, 200 HP | **Bone Throne final boss, 1150 HP**, warded phase 2 | Boss rotation |
| Hollow King | in the run | **not used** (content kept) | Revision |
| Mini-boss / final boss | fixed | **drawn per run** from the route's biomes | Replayability |
| Hero HP | K64 B60 M56 R55 | **K60 B60 M60 R58** | Class parity |
| Shop dice | "New Die" 40 | **per kind, 20–65** (see die kinds) | Die kinds |

Unchanged: combo multipliers, rune effects, campfire 30%, trap 12%, rune prices 35/50/70,
potion 20, face raise 25, reroll item 90, restock 10, elite ×1.3 HP / ×1.15 attack / ×1.5 gold
and XP, base enemy stats and patterns.

## Die kinds (`core/content/dice_kinds.gd`)

| kind | faces | rarity | price | raise cap |
|---|---|---|---|---|
| standard | 1 2 3 4 5 6 | common | 30 | 6 |
| low | 1 1 2 2 3 3 | common | 20 | 6 |
| odd | 1 1 3 3 5 5 | common | 25 | 6 |
| even | 2 2 4 4 6 6 | common | 35 | 6 |
| loaded | 1 2 3 4 6 6 | common | 35 | 6 |
| twin | 3 3 3 4 4 4 | rare | 40 | 6 |
| high | 4 4 5 5 6 6 | rare | 50 | 6 |
| gambler | 0 0 6 6 6 6 | rare | 45 | 6 |
| giant | 4 5 6 7 8 9 | epic | 65 | **9** |

- Face values range from 0 to 9. **0 is a blank face.** A blank adds 0 pips, never joins a combo,
  and never counts as a double. Blanks are skipped when the two moving dice are picked (see rule 1
  below).
- The random kind is rolled by rarity weight: common 60, rare 30, epic 10.
- Sources: the shop, drafts and the Dicesmith event. While the pool is below its cap, every
  shop's first item is a die and every level-up draft includes a New Die option. *(Level-up
  drafts were removed 2026-09-28; minigame gold rewards and events can still add dice.)*

## Passives (`core/content/passives.gd`)

There are 32 passives: 24 regular and 8 boss-tier. Regular passives come from elites, the shop's
passive slot (common 60, uncommon 80, rare 110) and the Blessing Shrine. Boss-tier passives come
**only** from the mini-boss (1 of 3) and from elites, which have a 15% chance to offer a
boss-tier choice instead of a regular one. Owned passives are never offered again. A boss-tier
roll with fewer than 3 boss passives left fills the remaining slots with rares, then with any
regular passive.

| id | name | rarity | effect |
|---|---|---|---|
| pair_master | Pair Master | common | Pair and Two Pair multipliers +0.5 |
| full_house_party | Full House Party | uncommon | Full House heals 8 |
| straight_shooter | Straight Shooter | uncommon | Straights and Small Straights +8 damage (after the multiplier) |
| triple_threat | Triple Threat | rare | Three, Four and Five of a Kind multiplier +1 |
| snake_eyes | Snake Eyes | common | +5 damage per die showing 1 (after the multiplier) |
| boxcars | Boxcars | uncommon | +3 pips per 6 in the combo |
| gold_tooth | Gold Tooth | common | +1 gold per die showing 6 on attack |
| steady_hand | Steady Hand | common | +1 pip per die not rerolled this turn |
| loaded_hands | Loaded Hands | uncommon | +1 reroll on turn 1 of every fight |
| double_trouble | Double Trouble | uncommon | Moving on doubles banks +1 combat reroll (max 2 banked) |
| rune_echo | Rune Echo | rare | Each rune on a combo die has a 25% chance to trigger twice (run Rng) |
| collector | Collector | uncommon | +5 max HP per rune owned when picked up, and +5 each time a blank die gains a rune |
| pathfinder | Pathfinder | uncommon | +1 board reroll per turn |
| treasure_sense | Treasure Sense | common | Chest gold ×1.5 |
| piggy_bank | Piggy Bank | uncommon | Completing a lap pays 10% of your gold (max 15) |
| haggler | Haggler | common | Shop items −20% |
| scholar | Scholar | common | Fight XP ×1.25 |
| blacksmith | Blacksmith | uncommon | The Forge tile allows 2 edits (offer.uses = 2) |
| thorns | Thorns | common | An enemy that damages you takes 3 |
| iron_skin | Iron Skin | common | 3 Block at the start of every combat turn |
| bloodthirst | Bloodthirst | uncommon | Heal 3 whenever an enemy dies |
| opening_salvo | Opening Salvo | uncommon | First attack of each fight ×1.5 |
| second_wind | Second Wind | rare | Once per run, survive a lethal hit at 1 HP |
| glass_cannon | Glass Cannon | rare | Attacks ×1.5, −20% max HP on pickup |
| extra_hand | Extra Hand | boss | Pool cap 6; gain a Standard die now |
| crowd_pleaser | Crowd Pleaser | boss | A Pair scores ×2.5 |
| encore | Encore | boss | A reroll that raises the combo multiplier is refunded |
| rune_bloom | Rune Bloom | boss | Every die without a rune gets a random rune now and at each biome change |
| fast_feet | Fast Feet | boss | Moving on doubles: after landing, hop again by one die's value |
| resonance | Resonance | boss | Runes on combo dice trigger twice |
| phoenix | Phoenix Feather | boss | Once per act, survive a lethal hit at 1 HP (checked before Second Wind) |
| midas_fist | Midas Fist | boss | +1 damage per 8 gold held (max +15) |

Damage with passives:
`floor(((pips + Heavy + Blade + Steady Hand + Boxcars) × (combo mult + passive bonus + 0.5 per Echo) + Snake Eyes + Straight Shooter + Midas) × Glass Cannon × Opening Salvo) + ATK`.

## Rules clarifications

**Board and movement**

1. **Automatic movement.** `roll_board()` rolls every die, then picks two with the run Rng.
   - Blank faces (0) are ignored, unless fewer than two dice show a value. In that case the live
     dice move, plus random blank dice to make two.
   - If some value appears at least twice, two dice of the most frequent value move. The two
     are the lowest indices. Ties between values are broken at random.
   - If every value is unique, two random dice move. A 2-die pool always moves both dice.
   - The move is the sum of the two dice. `board_rolled` carries `values`, `chosen:[i, j]`,
     `move`, `target`, `targets:[target]`, `double`, `treasury_added`, `treasury` and
     `rerolls_left`.
   - `board_reroll()` rerolls all dice and picks again. `confirm_move()` moves the hero.
     `choose_move(i)` is a deprecated alias that ignores `i`.
2. **Doubles** means the two chosen dice show the same non-blank value. Doubles add value × 2 to
   the Treasury bank on every roll, rerolls included. Double Trouble and Fast Feet also key off
   the chosen doubles.
3. **Move 0** (both chosen dice blank) keeps the hero in place. It emits `hero_stayed {pos}`, not
   `hero_moved`, and the tile does not trigger again.
4. **Passing Start.** The move finishes, and then the lap completes:
   - The hero heals 10% (`lap_completed {lap: completed lap 1..15}`) and the lap count goes up.
   - If a biome change is due, the board regenerates (`act_started`). Otherwise the board
     mutates (`board_mutated`). When lap 7 starts, the mini-boss is added to that same
     `board_mutated` change list.
   - On shop laps the shop opens. Then the landing tile resolves.
   - Mutation never changes the landing tile.
5. **Mutation.** Cleared fight tiles become Empty. Then 2 Enemy and 1 Elite go on random Empty
   tiles (32 tiles: 3 Enemy and 1 Elite). After that, Empty tiles become Events until the event
   count matches the layout again.
6. **Layouts** (edge tiles): on 24 tiles, 6 enemy, 3 chest, 3 event, 2 campfire, 2 trap and 4
   empty. On 28, 7/4/4/2/2/5. On 32, 8/4/4/3/3/6. Tiles 1 and 2 are never fights. A regenerated
   board in act 2 or 3 turns one Enemy into an Elite, and its enemies use the current lap's band.
7. **Portal** targets are the next `size / 3` tiles (8 on 24, 9 on 28, 10 on 32), wrapping past
   Start. On the final lap they stop at Start.
8. **Final lap.** Completing lap 15 cuts the move short at Start (`landing_preview` shows 0).
   The hero heals 10% and the run's final boss fight starts. Any mini-boss tile is removed, with a
   `board_mutated` change to empty. There is no shop and no mutation.
9. **Biome change** (laps 6 and 11):
   - `act` goes up, the board is regenerated and the hero keeps their tile. If the new landing
     tile would be a fight, it becomes Empty.
   - The hero heals 30%, and Rune Bloom fires.
   - The treasury carries over, and the once-per-act reroll item becomes available again.
   - `act_started {act, biome, biome_name, biome_desc, lap, board, treasury, pos}` fires between `lap_completed` and the
     shop.
10. **Mini-boss.** It spawns on an Empty or uncleared Enemy tile that is not a corner, not the
    landing tile, and more than 3 tiles (either way round) from the hero. It is scaled like a
    regular enemy (not an elite): mini-bosses have 105–110 base HP (Pumpkin Knight 105), which is about 2× an elite brute's
    HP at that lap. `combat_started` and `combat_won` carry `miniboss: true`. The reward is gold,
    XP and a choice of 1 of 3 boss-tier passives, which comes after any level-up drafts.
11. **Treasury, Outbreak/Garden, traps and the Dice Duel** work as before. A trap that would kill
    triggers Phoenix Feather or Second Wind first.

**Combat**

12. **Combos over 0..9.** Sets (pairs, three or more of a kind, full house, two pair) use equal
    non-zero values. Straights are runs of consecutive non-zero values, so 5-6-7-8-9 is a
    Straight. Blanks are ignored. Ties between equal multipliers go to the higher group pip sum.
13. **Wild** becomes a value from 1 to 6, never 0 and never 7–9, to keep Giant dice from
    breaking sets. So 9-9-Wild is a pair of 9s plus a free 6, while 7-8-9-Wild is a 6-9 Small
    Straight. A free Wild shows 6.
14. **Triggers.** Ember fires on exactly 6, Frost on exactly 1, and a Giant die's 7–9 triggers
    neither.
15. **Triggering twice.** When Resonance or Rune Echo makes a rune trigger twice, the rune
    applies its effect twice. Heavy then counts its pips ×3, Blade adds its bonus twice, Echo adds
    +1.0, Guard gives Block twice, Ember and Thunder hit twice, Venom poisons twice, Vampire heals
    twice, Gilded pays twice and Lucky banks twice (up to the cap).
16. **Rewards.** The order is level-up drafts first, then any passive choice (elite or mini-boss).
    *(Superseded 2026-09-28: level-ups are automatic, so only the passive choice remains.)*
    Elites no longer offer a rune choice. Chests still do.
17. All earlier rules not replaced here still apply: block and poison timing, curse, chaos,
    summons, Lucky, and the event text and choices. The Blessing Shrine now offers 2 regular
    passives. Its flat blessings are used only when no passives are left.

**Events and contract additions**

18. `die_added {die_idx, kind, die}`, `die_changed {die_idx, kind, die}` (Dicesmith on a full
    pool reforges the weakest die into the new kind and keeps its rune), `hero_stayed {pos}`,
    `passive_gained {id, name, rarity}` and `passive_triggered {id, value}`.
19. **Offers.**
    - Passive choice: `{kind: "passive", options: [{id, label, desc, rarity, icon}], source:
      "elite"|"miniboss"}` in phase DRAFT, picked with `pick_draft(i)`.
    - Shop die: `{id: "die", kind, label: "<Kind> Die", price, ...}`. Shop passive: `{id:
      "passive", passive, rarity, label, desc, price}`.
    - Draft New Die: `{id: "new_die", kind, label, desc}`.
    - Forge: `{kind: "forge", ops, source, uses}`.
20. `dice_rolled` and `board_rolled` values can include 0 and values above 6.
