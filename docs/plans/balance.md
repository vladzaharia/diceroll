# Diceroll balance

Numbers live in `core/content/` (`balance.gd`, `heroes.gd`, `enemies.gd`, `biomes.gd`,
`dice_kinds.gd`, `passives.gd`, `shop.gd`, `events.gd`, and the meta tables `economy.gd`,
`items.gd` (the Armory; `gear.gd` is legacy, read only for the v2 migration), `pets.gd`,
`potions.gd`, `minigames.gd`, `unlocks.gd`), `core/runes.gd`, `core/combo.gd`,
`core/item_logic.gd` and the profile presets in `core/meta/presets.gd`.

## Whole-game balance pass (2026-09-29, `wp-balance`)

This section is authoritative. It re-measures every target on `main` with the Armory, the 11
classes, 12 pets, 10 affixes, 10 biomes, 6 final bosses, the Short Road, Ascension and the 11
minigames in, then changes the fewest levers it could. The sections below are history where they
disagree with this one.

### How this was measured

- Realistic policy (the reference), A0, standard mode, 28-tile board unless a row says otherwise.
  "Before" is `main` at the start of the pass (1308a07; the UX pass merged since changed no
  numbers). Every before/after pair uses the same seeds, so the rows are paired.
- **Class rows:** 600 runs per class (seeds 1001, 2001, …, 6001 × 100): standard error ±2.0 pp
  per row, ±0.6 pp on the 11-class average. The "after" mid and max rows are pooled over 1,200
  runs per class (seeds up to 12001: ±1.4 pp per row, ±0.4 pp average); the table under them
  gives the 600-run rows on the before seeds. A10: 300 runs per class (±2.5 pp per row).
- **Skill rows:** greedy fresh 300 (before) and 600 (after) runs per class, expert max 200 per
  class (±1 pp at 97%), expert fresh 100 per class.
- **Route sweep:** max, `--class=all --runs=28` at seeds 50001 and 100001 for each of the 36
  routes: 616 runs per route (±1.9 pp), 22,176 runs. Biome marginals: 5,544–7,392 runs each
  (±0.6 pp). Boss-win%: 2,400–4,600 fights reached per boss (±0.7–0.9 pp).
- **Short Road sweep:** the same seeds over the 21 routes (12,936 runs). Short Road class cells:
  300 runs (before) and 600 (after: ±2 pp).
- **Campaign:** `--campaign=100 --campaigns=1 --seed=1+k·104729`, 16 fresh profiles before and 32
  after (runs 1–100).
- Sim dials added for this pass: `--biome-hp=<biome>:<mult>` (the new biome lever, below). The
  analysis dials used for the rejected levers (boss attack, a lap cap on enemy scaling, the
  Blade/Heavy pip share and stack cap, the per-build-decision lapse rate) were kept out of the
  shipped code; their numbers are recorded below.

### Levers changed (and why)

| lever | was | now | target it fixes |
|---|---|---|---|
| **Biome enemy HP** (new `BiomeDefs` field `enemy_hp`, regular and elite enemies only; mini-bosses and final bosses keep theirs) | 1.0 everywhere | Crypt 1.03, **Mines 0.92**, **Hollow 1.05**, **Warcamp 0.92**, Ruins 0.97, Moonlit 1.02 | Standard routes: the tier-1 and tier-2 spreads (Mines −2.3, Hollow +2.6, Warcamp −2.6) added up across a route. One number per biome moves only the routes through it. |
| The Lich | HP 1650 | **1720** | Bosses: the Lich was +3.4 pp boss-win, the only boss outside ±3. |
| Magma Golem | HP 960 | **935** | Bosses: the lowest boss (−2.0, then −2.6 after the Lich change). |
| Knight Plate (Plated) | Block 1 on turn 1 of every fight | **elite and boss fights only** | Classes: the Knight was +6.3 at max (over ±6), +3.3 at mid and +10.8 on the Short Road max. Turn-1 Block in every fight is worth about 2 pp per point (the Plate or the Helm's Steadfast off: Knight −4.3 max, −4.4 mid). The Plate also read +2.6 as a generic body, above the 2 pp body cap. |
| Rogue | HP 54 | **55** | Greedy fresh: the Rogue was 9.3% (floor 10%). |
| Druid | HP 56 | **58** | Classes: the Druid was −4.4 at mid before the pass and fell to −5.9 once the Hollow got harder. |
| Warcamp Short Road finale | ×0.75 | **×0.80** (`short_boss_hp`) | Short Road: the easier Warcamp put its finales +2 to +6 pp over the Short Road mean. |
| **Crowns payouts** (`Economy`) | lap 2 (cap 30), biome 5, mini-boss 12, win 30, minigames 2/3/4, leftover gold cap 5 | **×1.5:** lap 3 (cap 45), biome 8, mini-boss 18, win 45, minigames 3/5/6, gold cap 8 | Campaign: the Armory raised the Crowns sink to 14,170, about 183 runs at 77 Crowns a run. |
| Variant crafts (`ItemDefs.CRAFT_COSTS`, `FEAT_CRAFT`) | 60 / 90 / 120, feats 120 | **20 / 30 / 40, feats 40** | Campaign: variants are sidegrades (within ±3 pp of their Standard), so this is a collection sink, not power. |
| Pet levels 6–10 (`PetDefs.LEVEL_COSTS`) | 40 / 60 / 80 / 100 / 120 | **20 / 30 / 40 / 50 / 60** | Campaign: 12 pets × 400 was a third of the sink, for pets a player equips one at a time. |
| `trick_or_treat` (Monster Kid) | 36 Hollow events | **30** | Unlock pacing: the Monster Kid arrived at run 27.5 (target 20–25). |
| Mage Sigil price (`SIGIL_PRICE_BY_ID`) | 8 | **11** | Unlock pacing: with the richer early Crowns the campaign reached mini-bosses and firsts sooner, and bought the Mage at run 6.5 (target 10). |

The whole Crowns sink is now **8,850** (ranks 2,920, Belt Pouch 400, items 1,060, crafts 1,460,
Camp upgrades 610, pet levels 2,400).

### Class bands (realistic)

| class | fresh | mid | max | max A10 |
|---|---|---|---|---|
| Knight | 37.2 → **36.2** | 51.2 → **44.5** | 69.0 → **61.6** | 23.7 → **25.7** |
| Barbarian | 39.8 → **35.3** | 44.0 → **46.1** | 61.2 → **62.4** | 22.3 → **22.0** |
| Paladin | 40.7 → **34.5** | 52.3 → **50.3** | 59.7 → **60.8** | 21.0 → **18.3** |
| Mage | 40.5 → **36.0** | 52.8 → **48.9** | 63.3 → **67.4** | 23.0 → **22.7** |
| Ranger | 36.2 → **34.3** | 46.7 → **45.7** | 67.0 → **66.0** | 21.7 → **27.0** |
| Rogue | 37.2 → **38.5** | 47.7 → **48.8** | 64.7 → **65.7** | 28.7 → **27.0** |
| Ninja | 38.5 → **36.3** | 47.7 → **45.3** | 66.7 → **66.8** | 30.0 → **30.3** |
| Druid | 38.2 → **38.2** | 43.5 → **48.9** | 61.3 → **61.8** | 16.3 → **20.3** |
| Engineer | 41.2 → **38.0** | 46.7 → **47.3** | 59.7 → **61.2** | 26.3 → **24.7** |
| Necromancer | 38.0 → **33.5** | 47.5 → **43.7** | 59.5 → **61.1** | 22.7 → **18.7** |
| Monster Kid | 42.2 → **38.5** | 46.5 → **45.7** | 57.8 → **58.4** | 18.7 → **21.0** |
| **average** | 39.0 → **36.3** | 47.9 → **46.8** | 62.7 → **63.0** | 23.1 → **23.4** |
| target | 30–40 | 45–50 | 55–65 | 20–30 |
| spread (target ±5 / ±5 / ±6) | −2.9 / +3.1 → **−2.8 / +2.2** | −4.4 / +5.0 → **−3.2 / +3.5** | −4.9 / +6.3 → **−4.6 / +4.4** | −6.8 / +6.9 → **−5.1 / +6.9** |

On the before seeds alone (600 runs per class), the after rows read mid **47.1** (−3.3 / +3.6) and
max **62.6** (−4.6 / +5.7; the Ranger 68.3 and the Mage 67.0 are the top, both within ±6).

- **Every band and every class target is met.** The only class that missed before, the Knight at
  max (+6.3), is now −1.4. Mid no longer has a class at the ±5 edge (the Mage was +5.0).
- **Fresh fell 2.7 pp** to 36.3, the middle of its band. The fresh route runs through the Hollow
  and ends on the Throne, so the Hollow's HP and the Lich's HP land there. It was 0.1 pp from the
  top of the band before.
- **A10** has no class rule; its spread is −5.1 / +6.9 (the Ninja 30.3).

### Skill floor and ceiling

| policy | before | after | target |
|---|---|---|---|
| greedy fresh (lowest class) | 14.7 (Rogue **9.3**) | 14.2 (Ninja 10.5, Paladin 10.7) | every class ≥ 10 |
| expert max | **97.4** (94.5–99.0) | **97.1** (94.5–99.0) | about 80, at most 85 |
| expert fresh | 86.3 (77–91) | 86.7 (79–96) | ≤ 80 (spec §16) |
| realistic → expert at max | **+34.7** | **+34.1** | +15 to +25 |

- **The greedy floor is met** (the Rogue's +1 HP). The Ninja at 10.5 is within noise (±1.2 pp)
  of the floor.
- **The expert ceiling and the skill gap are not met, and no lever tested could meet them without
  breaking the bands.** The gap belongs to the bot policies more than to the game. Removing the
  realistic bot's lapses one scope at a time (max, seeds 1001, 1,100 runs each, realistic 63.4):

| lapses removed | win% | Δ |
|---|---|---|
| none (realistic) | 63.4 | |
| combat | 74.2 | +10.8 |
| board | 69.5 | +6.1 |
| build (drafts, rune assignment, shop, Forge, events) | 82.4 | **+19.0** |
| – drafts only | 68.9 | +5.5 |
| – rune assignment only | 64.7 | +1.3 |
| – shop only | 71.8 | +8.4 |
| – Forge only | 66.6 | +3.2 |
| – events only | 69.0 | +5.6 |
| all three | 92.4 | +29.0 |
| expert | 97.4 | +34 |

  The build rule of thumb (the greedy bot's static tastes, taken 62% of the time) is half the
  gap. The expert's builds are Blade and Heavy (1.58 and 1.44 per run vs the realistic bot's 1.02
  and 0.95), and it almost never takes Ember, Venom or Vampire, which the realistic bot takes in
  40–44% of runs. Game levers tried against the ceiling (realistic / expert at max, 1,100 runs
  each; base 63.4 / 97.4):

| lever (sim dial, not shipped) | realistic | expert | why rejected |
|---|---|---|---|
| final bosses ×0.6 HP, ×1.5 attack (shorter, spikier boss fights) | 69.6 | 97.6 | no compression |
| enemy HP step 0.35 → 0.25, attack step 0.125 → 0.18 per lap | 66.3 | 95.0 | compresses a little (expert −2.4, realistic +2.9); pushing it further trades the "long late fights" curve Vlad chose for one-shots and raises the lap-14/15 deaths |
| Blade and Heavy at half their pips | 43.7 | 81.1 | the whole game gets harder, not the expert |
| same + enemy HP ×0.82 | 68.8 | 93.3 | gap +24.5, but the ceiling is still 93 |
| Blade and Heavy at ¾ + enemy HP ×0.92 | 64.6 | 92.2 | gap +27.6 |
| Blade and Heavy act on 1 die each (stack cap 2 → 1) | 61.4 | 96.4 | no compression |

  Even halving the two core runes and easing every enemy to compensate leaves the expert at 93.
  Reaching 80–85 would need either a design change to the build economy (fewer, flatter build
  choices) or a different reference: the realistic bot's build tastes are what separate the two
  policies. That is a decision for Vlad, so nothing here ships for it.

### Final bosses (max, route sweep; boss-win% = won / reached)

| boss | HP | before | after |
|---|---|---|---|
| The Lich | 1650 → **1720** | 77.8 (+3.4) | 77.6 (+1.9) |
| Bone Warden | 1000 | 75.0 (+0.6) | 75.6 (−0.1) |
| Cinder King | 1800 | 73.3 (−1.1) | 77.4 (+1.7) |
| Magma Golem | 960 → **935** | 72.4 (−2.0) | 73.1 (−2.6) |
| Sand Colossus | 1180 | 73.9 (−0.5) | 75.4 (−0.3) |
| The Moon King | 860 | 73.9 (−0.5) | 75.2 (−0.5) |
| **spread around the mean** | | −2.0 / **+3.4** | **−2.6 / +1.9** |

Every boss is now within ±3 pp of the mean (range 4.5 pp). The Cinder King's +4.1 is unchanged
content: runs reach it stronger through the easier Mines and Warcamp. It stays inside ±3.

### Standard routes (max)

Overall 63.2% → **64.8%**. Win% per route after (delta from the route mean):

| tier 1 / tier 2 | throne | magma | ruins | moonlit |
|---|---|---|---|---|
| glade / hollow | 70.0 (+5.2) | 67.5 (+2.8) | 63.1 (−1.6) | 69.2 (+4.4) |
| glade / frost | 62.5 (−2.3) | 66.7 (+1.9) | 64.0 (−0.8) | 65.4 (+0.6) |
| glade / warcamp | 64.4 (−0.3) | 65.4 (+0.6) | 65.6 (+0.8) | 65.9 (+1.1) |
| crypt / hollow | 62.7 (−2.1) | 64.0 (−0.8) | 62.7 (−2.1) | 66.7 (+1.9) |
| crypt / frost | 62.0 (−2.8) | 62.7 (−2.1) | 62.7 (−2.1) | 64.4 (−0.3) |
| crypt / warcamp | 62.3 (−2.4) | 64.3 (−0.5) | 66.9 (+2.1) | 64.4 (−0.3) |
| mines / hollow | 66.9 (+2.1) | 68.2 (+3.4) | 66.2 (+1.5) | 68.8 (+4.0) |
| mines / frost | 62.3 (−2.4) | 64.4 (−0.3) | 63.1 (−1.6) | 63.6 (−1.1) |
| mines / warcamp | 63.0 (−1.8) | 62.5 (−2.3) | 64.3 (−0.5) | 63.1 (−1.6) |

**32 of 36 routes are within ±3 pp** (before: 22 of 36), and the range is −2.8 / +5.2 (before:
−8.4 / +5.1). The four misses are Hollow routes at +3.4 to +5.2. With a route's standard error of
1.9 pp, about 2 of 36 routes land outside ±3 by noise alone.

| tier | biome | enemy HP | win% before → after | Δ tier before → after |
|---|---|---|---|---|
| 1 | glade | 1.00 | 64.2 → 65.8 | +0.9 → **+1.0** |
| 1 | crypt | 1.03 | 64.6 → 63.8 | +1.4 → **−1.0** |
| 1 | mines | 0.92 | 60.9 → 64.7 | −2.3 → **−0.1** |
| 2 | hollow | 1.05 | 65.8 → 66.3 | +2.6 → **+1.5** |
| 2 | frost | 1.00 | 63.2 → 63.7 | −0.0 → **−1.1** |
| 2 | warcamp | 0.92 | 60.7 → 64.4 | −2.6 → **−0.4** |
| 3 | throne | 1.00 | 63.1 → 64.0 | −0.1 → **−0.8** |
| 3 | magma | 1.00 | 62.9 → 65.1 | −0.3 → **+0.3** |
| 3 | ruins | 0.97 | 61.6 → 64.3 | −1.6 → **−0.5** |
| 3 | moonlit | 1.02 | 65.3 → 65.7 | +2.1 → **+1.0** |

- Every biome is now within ±1.5 pp of its tier (before: −2.6 to +2.6).
- **The Hollow is the remaining edge.** A first try at ×1.08 read +1.0 and put 35 of 36 routes
  inside ±3, but it cost the fresh profile (the Hollow is on the fresh route) and three classes
  fell under the greedy 10% floor (Knight 8.7, Ranger 9.3, Ninja 9.7 at 300 runs). ×1.05 keeps
  the floor.
- Sensitivity, for the next pass: every enemy at ×1.1 HP is −11 pp at max (52.1 vs 63.4). One
  biome at ×0.92 moved the routes through it by +3.7 pp (Warcamp, Mines), against +1.6 overall.

### Short Road (max)

- **Tier-2 vs tier-3 finales: 60.3% vs 61.2%, 0.9 pp apart** (target ≤ 3; before 60.7 vs 59.5).
- Routes within ±3 pp of the Short Road mean: 16 of 21 (before: 12 of 21).
- Overall 60.0% → 60.8%. Bosses (boss-win%): Cinder King 72.1, Sand Colossus 73.1, Magma Golem
  70.1, Bone Warden 70.3, Moon King 69.5, Lich 68.0.

Per class (before 300 runs per cell, after 600):

| class | fresh | mid | max |
|---|---|---|---|
| Knight | 45.7 → **42.8** | 57.3 → **57.7** | 73.3 → **66.8** |
| Barbarian | 47.0 → **37.5** | 53.3 → **49.8** | 69.0 → **60.3** |
| Paladin | 36.3 → **30.7** | 51.0 → **47.0** | 59.0 → **57.7** |
| Mage | 40.7 → **36.2** | 54.3 → **51.0** | 61.3 → **61.3** |
| Ranger | 36.7 → **29.0** | 49.0 → **45.3** | 58.7 → **62.3** |
| Rogue | 37.7 → **34.5** | 53.7 → **49.0** | 62.7 → **60.8** |
| Ninja | 38.7 → **34.3** | 49.7 → **47.3** | 64.7 → **62.0** |
| Druid | 41.7 → **36.7** | 47.3 → **46.2** | 58.3 → **59.8** |
| Engineer | 42.3 → **38.0** | 49.0 → **49.0** | 58.3 → **61.5** |
| Necromancer | 41.0 → **31.3** | 51.0 → **48.8** | 66.0 → **58.2** |
| Monster Kid | 48.7 → **39.7** | 49.0 → **45.7** | 57.0 → **57.0** |
| **average** | 41.5 → **35.5** | 51.3 → **48.8** | 62.6 → **60.7** |
| spread | −5.2 / +7.2 → **−6.5 / +7.3** | −4.0 / +6.0 → **−3.5 / +8.9** | −5.6 / +10.8 → **−3.7 / +6.1** |

- **4 of 33 cells miss ±5 (before: 7 of 33):** the Knight in all three columns (+7.3, +8.9,
  +6.1) and the Ranger at fresh (−6.5).
- **The Knight is a Short Road class, not an Armory one.** It is +7.3 even at fresh, where every
  rank is R0 and the kit does nothing, while its standard rows are all within 2.3 pp of the
  average. A Knight nerf big enough for the Short Road would push its standard mid row to about
  −5. Fixing it needs a Short Road-only Knight number, like the Druid's ×1.5 seed growth. That was
  left as a design call.
- The Ranger's fresh Short Road cell is its low HP (52) meeting the harder Hollow and Lich of the
  fresh route: its standard fresh row is −2.0.
- The fresh Short Road average fell 6 pp. The fresh Short Road ends on the Lich or the Bone Warden
  after the Hollow or the Throne, so it takes the full Hollow and Lich changes. The Short Road has
  no band of its own.

### Deaths by lap (max) — not met

| lap | L3 | L5 | L12 | L13 | L14 | L15 |
|---|---|---|---|---|---|---|
| before (× the average lap death rate) | 1.20 | 1.67 | 0.85 | 1.34 | **2.87** | **4.50** |
| after | 0.94 | 1.88 | 0.80 | 1.33 | **3.04** | **4.68** |

(Route sweep, 22,176 runs; deaths in laps 1–15 are 15% of runs and the final boss another 21%.)

The spike is the same on every tier-3 biome (L15: Throne 5.7% of runs, Ruins 5.0, Magma 4.2,
Moonlit 3.7) and follows the enemy curve: HP ×5.9 and attack ×2.75 at lap 15, with no shop after
lap 14. Laps 1, 2 and 6 have almost no deaths (the start, and the 30% heal at the biome change),
so a ratio of 1.5 would mean moving about 1,250 of the 3,450 lap deaths (over a third) out of
laps 14–15.
Measured without shipping:

| lever | max win% | L14 | L15 |
|---|---|---|---|
| none (seeds 1001–2001) | 62.0 | 2.8× | 4.6× |
| enemy scaling capped at lap 13 | 68.5 | 2.0× | 2.9× |
| enemy scaling capped at lap 12 | 72.4 | 2.1× | 2.4× |

Even the lap-12 cap, which adds 10 pp at max, leaves both laps over 2×, because late deaths are
attrition built up over the tier-3 biome as well as the lap's own fights. Meeting 1.5× would need
a different late-run structure (for example a shop or heal before lap 15, and the difficulty
moved into the final boss). That is a design change, so it was left.

### Minigames and the economy

| | before | after |
|---|---|---|
| in-run reward EV per play (gold equivalents, `MinigameDefs.CALIBRATION`) | 28.6 | 28.6 (unchanged) |
| plays per run (fresh / mid / max) | 2.94 / 2.75 / 3.69 | 2.94 / 2.74 / 3.69 |
| gold earned per run (max) | 871 | 869 |
| minigame share of in-run gold (max) | ~12% | ~12% |
| Crowns per play (tier mix 33/36/31) | 2.98 | 4.65 |
| minigame share of a run's Crowns (max) | 14.1% | 14.5% |
| Crowns per run (fresh / mid / max class sims) | 66.8 / 69.4 / 77.9 | 100.3 / 104.6 / 118.5 |

The minigames stay in line. Their in-run value is unchanged, and the Armory changed no shop
price. Their Crowns scale with the other payouts, so they keep the same share, and one play is
now 0.05% of the sink (was 0.02% of 14,170).

### Campaign pacing (realistic campaign; before 16 profiles, after 32)

| unlock | target | median before | median after |
|---|---|---|---|
| Deep Mines | 8 | 7 | 6 |
| Orc Warcamp | 12 | 12 | 12 |
| Moonlit Woods | 17 | 17 | 17 |
| Sunscorched Ruins | 21 | 22 | 22 |
| Paladin / Mage / Ranger / Rogue | 6 / 10 / 13 / 15 | 8 / 10 / 12 / 15 | 8 / **9** / 11.5 / 15 |
| Ninja / Druid / Engineer / Necromancer | 19 / 23 / 27 / ≤ 32 | 20 / 25 / 26 / 29 | 20 / 24.5 / 26 / 29 |
| Monster Kid | 20–25 | **27.5** | **22.5** |
| items: wanderer / gate_crasher / boss_seen / bone_collector | 2 / 4 / 6 / 20 | 2 / 3 / 7 / 21 | 2 / 3 / 7 / 21.5 |

- Every class, biome and item unlock is within ±2 runs of its target. The Paladin (+2) and the
  Druid (+1.5) are the closest to the edge. No run unlocks two classes (0 of 3,200).
- Before the Mage Sigil price change, the richer early Crowns had moved the Mage to run 6.5.
- **Outside this pass's scope** (packs, pets and bosses, all but one already off before the
  pass): `straight_talk` (Numerology) 7.5 vs 11, `plague` (Lantern Ghost) 18 vs 14, `archmage`
  (Pyromancy, usually bought with Sigils first) 48 vs 20, `rune_lord` (Resonance) 16 vs 24, and
  `throne_breaker` (the Bone Warden) 20.5 vs 17 (was 16.5; a Throne win now needs the tougher
  Lich or the Bone Warden).

| Crowns | before | after |
|---|---|---|
| Crowns per run (campaign average, runs 1–100) | 77.4 | 121 |
| sink | 14,170 | **8,850** |
| run at which a profile has earned the whole sink | none within 100 runs (about 183) | **median 73** (p10 69, p90 79) |

- **The Crowns side now finishes around run 73** (target 60–80). An A-level player earns 8% more
  per level.
- The campaign bot itself never "buys everything". It equips one pet and one kit per class, so
  most pets never reach level 5 (the Crowns levels start there) and many variant blueprints never
  unlock (mastery). At run 90 it holds about 4,500 unspent Crowns. That is gating by play style,
  not Crowns.
- **Sigils:** every Sigil unlock is done by run ~32 (the last class at 29, the last pet at 31);
  Sigils pace unlocks, not a late sink.
- **Power pacing:** by run 10 the campaign has earned about 1,100 Crowns (was 700) and holds R3–R4
  in every rank (4 snapshots; was R3). The mid preset's R4 had been a rank ahead of the campaign;
  now it matches the upper half.

### Rejected or measured levers (not shipped)

- **Knight Last Stand off** (`--item=round_shield.last_stand=0/0/0`): 69.0 → 69.0 at max. It
  never fires in the sim, so it was not the Knight's edge.
- **Knight Plate Block 0 or Knight Helm Steadfast 0:** each −4.3 at max and −4.4 at mid (the same
  number, since each removes one turn-1 Block). Removing a whole rule was more than needed. The
  shipped version keeps the Plate for elite and boss fights.
- **Hollow ×1.08:** routes 35/36 within ±3, but the fresh profile fell and three greedy rows went
  under 10% (above).
- **The expert-ceiling and lap-death levers:** the tables above.
- **Crowns alone ×1.8 with the sink untouched:** not run. At 77 × 1.8 = 139 a run, 14,170 is still
  run 102, and early ranks would come twice as fast.

## Armory (2026-09-29: the real-item Armory, `wp-armory-core`)

*Superseded where the whole-game pass above differs (the bands, the Knight Plate, crafting prices).*
This section is authoritative for the Armory and for the profile bands: the four abstract gear
pieces and their traits are gone, so the band table of the combined section below describes
the old gear. Design: `docs/design/2026-09-29-armory-items.md`. Code: `core/content/items.gd`
(`ItemDefs`), `core/item_logic.gd` (`ItemLogic`), `Profile.armory` (v3), the Camp commands,
`MetaRun.build` (`meta.items`), `tools/sim.gd` (`--armory`, `--variant`, `--kit`, `--item`).

### How this was measured

- Realistic policy, A0, standard mode, 28-tile board. Band rows: 600 runs per class (seeds
  1001, 2001, …, 6001 × 100); A10: 300 runs per class.
- **The realistic loadout** is each class's default kit (§6 of the design, with the signature
  variants) and the Tankard. At max the Belt Pouch is bought but empty. This is the design's
  "default kit on realistic". The expert bot can pick `BotMeta.best_loadout` (`--kit=best`).
- **Item rows** equip the item for every class (`--armory=<slot>:<item>`, Standard variant,
  tier III at max; the kit piece of its own class gets its affinity) and compare with the slot
  left empty (`--strip=slot:<slot>`). They use 200 runs per class (seeds 1001 and 2001), so
  2,200 runs per item. Weapons and off-hands are measured with both hand slots empty, so a
  two-handed weapon never costs a shield. The difference of two rows carries about ±1.4 pp of
  noise.
- **Variant rows**: 100 runs per class (seed 1001, 1,100 runs), against the Standard on the
  same seed (about ±2.8 pp).

### Results

| class | fresh | mid | max | max A10 |
|---|---|---|---|---|
| Knight | 37.2 | 51.2 | 69.0 | 23.7 |
| Barbarian | 39.8 | 44.0 | 61.2 | 22.3 |
| Paladin | 40.7 | 52.3 | 59.7 | 21.0 |
| Mage | 40.5 | 52.8 | 63.3 | 23.0 |
| Ranger | 36.2 | 46.7 | 67.0 | 21.7 |
| Rogue | 37.2 | 47.7 | 64.7 | 28.7 |
| Ninja | 38.5 | 47.7 | 66.7 | 30.0 |
| Druid | 38.2 | 43.5 | 61.3 | 16.3 |
| Engineer | 41.2 | 46.7 | 59.7 | 26.3 |
| Necromancer | 38.0 | 47.5 | 59.5 | 22.7 |
| Monster Kid | 42.2 | 46.5 | 57.8 | 18.7 |
| **average** | **39.1** | **47.9** | **62.7** | **23.1** |
| before (old gear) | 39.0 | 45.3 | 62.8 | 22.7 |
| target | 30–40 | 45–50 | 55–65 | 20–30 |
| spread | −2.9 / +3.1 | −4.4 / +4.9 | −4.9 / +6.3 | −6.8 / +6.9 |

- **Fresh is exactly the combined-section table.** Every rank starts at R0, so the owned
  Knight kit and Tankard do nothing yet. The seeds match, so every row is identical.
- **Mid: 45.3 → 47.9**, the middle of its band. Every class is within ±5 pp.
  - The Mage (+4.9) is near the edge on these seeds. Six more shards (seeds 7001–12001) read
    48.0, so the pooled estimate is 50.4 (+2.5).
  - The Druid is the low end (−4.4), as it was before (−3.3). The Barbarian (−3.9) lost the
    old Blade trait's uncapped +1 on every Pair.
  - A Druid Robe with Bark III at 3 lifted the Druid by only +0.8 but read +3.8 as a generic
    body piece, so it stays at 2.
- **Max: 62.8 → 62.7**, inside the band.
  - The max spread moved from −3.8 / +6.2 to −4.9 / +6.3: the Knight has Last Stand, the only
    max-only kit rule left; the Monster Kid, Necromancer and Paladin are low.
  - The ±5 pp rule covers fresh and mid only. The order at mid is different (the Paladin tops
    mid and sits near the bottom of max), so fixing max would move mid.
- **A10: 22.7 → 23.1.**
- **The whole armory** is +8.8 pp at max (noarmory 53.9 → 62.7), within the design's +15
  budget:
  - The Armor HP base stat (+2 at R8) reads +3.9 (base 57.8 with every slot empty).
  - The kit and the Tankard add +4.9.
  - The expert loadout (`--kit=best`) reads 67.1, +4.4 over the realistic kit.
- **The campaign** (8 fresh profiles × 40 runs, realistic) had no errors, and the class unlock
  medians are unchanged: Paladin 8, Mage 10.5, Ranger 11.5, Rogue 15, Ninja 20, Druid 25,
  Engineer 26, Necromancer 29.5, Monster Kid 28.5.
  - `bone_collector` fires at a median of run 22.
  - At run 10 the bot holds R3 in every rank. It has also bought most Back pieces and a few
    items; the mid preset keeps R4, the old gear-L4 spend.
  - The Crowns sink is now 14,170: ranks 2,920, pouch 400, shop items, every blueprint, and
    the old upgrades and pets.

### What the design's starting numbers did, and the levers used

The design's numbers, played by the realistic bot, put **max at 80.0%** (band 55–65).

- **One slot removed at a time** from that full kit:
  - weapon −5.6
  - body −3.4
  - off-hand −2.9
  - Belt Pouch (Coin Purse II) −2.1
  - head −1.9
  - Removing the Compass raised max by 3.6.
- **One slot added at a time** to the base (ranks R8, every slot empty, 61.0): weapon +9,
  off-hand +4, body +4, head +2.7, Compass +5.7.

Four findings drove the rework:

1. **Flat damage and Block are worth far more than the design assumed.**
   - The R8 +1 ATK alone was +4.4 pp; the design budgeted 2–3 pp for ATK and HP together.
   - A Block of 1 on turn 1 of every fight is about +2 pp.
   - A "+1 pip" before the multiplier is worth the whole combo multiplier (×2–4).
   - At the design's numbers the Knight's head and body alone were +11 pp, and the Smoke
     Bomb's −30% on the first hit was +12.7.
2. **The Compass's tie-break is a trap.**
   - "Value ties move the higher value" is the old Boots trait *Pathfinder's Eye*, which the
     old max preset had. It is **−5 pp**: faster moves skip tiles, so a run has fewer fights,
     less XP and less gold.
   - The lower value instead is +5 pp, which would make it a must-pick.
   - The old max band hid this −5 pp. Without it, +1 ATK, +4 HP and the Compass reroll alone
     reach 66.
3. **Mid is the binding constraint.** Affinity puts a mid profile's kit (R4 = tier II, +1) at
   tier III, the same as max. Mid sits nearer 50%, where every item is worth the most, so the
   items can add only about +3 pp there.
4. **Every-attack rules are what decides boss fights** (10+ attacks), so those were cut
   hardest. Once-a-fight rules are cheap.

Levers, in the order applied (each one measured):

| lever | design | now |
|---|---|---|
| Weapon rank base stat | +1 ATK at R8 | none (`ItemDefs.ATK_BONUS` = 0; measured +4.4 pp) |
| Armor rank base stat | +0.5 max HP per rank, cap +4 | +0.25 per rank, cap +2 (the design's own "Armor HP" lever, in reverse) |
| item "pips" (Crush, Flow, Channel, Steady, Dominion, Brawn, Brawl, Light, Silent) | before the multiplier | after the multiplier |
| per-attack or per-turn rules (Twin Edge, Crush, Flow, Channel, Scrap, Steady, Aegis, Vow, Blessed, Reap, Barrage, Poise, Nimble, Steadfast, Radiant) | every attack or turn | `uses` per fight (mostly 1, 2 at III for a few) |
| count-rule Standards (Dagger, Katana, Druid Staff, Parrying Dagger, Ninja Headband, Wrench, Wizard Hat) | Block 2 on turn 1 each | Block 1 on turn 1 of elite, mini-boss and boss fights, not stacking (every fight was +2–4 pp, above every variant) |
| Plated / Thick Hide / Bulwark | Block every turn / 3-5-7 | Block 1 on turn 1 / turns 1–3 / turn 1 |
| Compass | ties move the higher value; board reroll per biome from R6 | no tie-break; Portal +2/+3/+4; the reroll starts with the 2nd biome (2 per run) |
| Smoke Bomb | −30/50/70% of the first hit | −20/25/30%, at most 1 |
| Healer's Flask | potions +5% / +10% | +3% at III only |
| Mage Robe | Ember/Thunder +1/2/3, Venom +1/1/2 | Ember +1, Thunder +1 at III, no Venom |
| Wrench | Forge +1 / raises 18 / Forge +2 | Face Raises 22/20/20, no Forge edits (the Engineer was +11 pp at mid) |
| Paladin Cuirass / Helm | heal every Pair / every set | Two Pair or better / Three of a Kind or better, once per fight |
| Engineer Goggles | dice and Face Raises −10/15/20% | dice only, −5/10/10% |
| Tankard | lap +0.5/1/1.5%, campfires +10% at III | lap +0.5/0.5/1%, campfires +5% at III (+2.8 pp before) |
| variants | see §5 | Sun Staff once per fight (+15.9 → +1.2); Zweihander 25% → 5% (+7.6 → +0.5); Cleaver has no reroll or HP cost (−7.6 → 0); Tower Shield keeps the full Bulwark on turn 2; the Plank Shield has no Bulwark cost; the Golem Axe is −1 max HP; the Bone Crossbow's Reload is once per fight; the Bone Quiver poisons 1 |
| realistic max preset | (the doc's example: Compass III + Coin Purse II) | the default kit + Tankard, Belt Pouch empty |

The final numbers are in the item table below.
- Most kit rules now read "1 per fight".
- Tier I and III often carry the same numbers, because the budget leaves no room for three
  integer steps. Where the tiers differ, it is in `uses`, `turns`, `stacks`, `max` or the
  fractional rules.

### Per-item deltas (max, tier III, vs the slot empty)

Rows marked † were re-measured after a fix (seed 1001 only: 1,100 runs, ±2.8 pp); the values before the fix are in brackets.

| weapon (vs no weapon and no off-hand, 62.1) | Δ pp |
|---|---|
| Wand | +3.3 |
| Druid Staff † | +3.3 (+4.8) |
| Greatsword | +3.0 |
| Spear | +3.0 |
| Hand Axe | +3.0 |
| Hunting Bow | +1.4 |
| Katana | +1.2 |
| Scythe | +1.2 |
| Wrench | +0.9 |
| Dagger † | +0.5 (+3.2) |
| Arming Sword | +0.5 |
| Warhammer | +0.3 |
| Claws | +0.0 |
| Great Axe | −0.0 |
| Arcane Staff | −0.1 |
| Crossbow | −0.8 |

| off-hand (same baseline) | Δ pp |
|---|---|
| Spiked Shield | +1.9 |
| Round Shield | +1.9 |
| Parrying Dagger † | +1.5 (+0.6) |
| Oath Shield | +0.8 |
| Quiver | +0.7 |
| Smoke Bomb † | +0.0 (+12.7) |
| Shuriken | −0.3 |
| Spellbook | −0.5 |

| head (vs no head, 63.3) | Δ pp |
|---|---|
| Ninja Headband † | +2.8 (+2.3) |
| Bandit Mask | +2.4 |
| Paladin Helm | +1.3 |
| Wizard Hat | +1.2 |
| Knight Helm | +1.1 |
| Engineer Goggles | +1.1 |
| Bear Hat | +1.0 |
| Bone Crown | +0.8 |

| body (vs no body, 61.9) | Δ pp |
|---|---|
| Knight Plate | +2.6 |
| Hooded Robe | +2.2 |
| Druid Robe | +2.1 |
| Engineer Overalls | +1.9 |
| Rogue Leathers | +1.8 |
| Mage Robe † | +1.5 (+3.3) |
| Ranger Tunic | +1.3 |
| Ninja Gi | +1.1 |
| Paladin Cuirass | +0.9 |
| Barbarian Harness | +0.8 |

| trinket, slot 1 (vs empty, 62.9) | Δ pp |
|---|---|
| Coin Purse | +3.2 |
| Trader's Map | +1.9 |
| Healer's Flask † | +1.8 (+5.8) |
| Compass | +1.6 |
| Lantern | +1.2 |
| Tankard | +0.9 |
| Skeleton Key | +0.4 |
| Loaded Die | −0.2 |

| Belt Pouch, slot 2 (vs empty, Tankard in slot 1, 63.7) | Δ pp |
|---|---|
| Lantern | +1.5 |
| Loaded Die | +1.2 |
| Coin Purse | −0.1 |
| Compass | −1.2 (no reroll in slot 2) |

- **No must-pick.** Every item is inside its design cap within the noise: weapon ≤ 4,
  off-hand ≤ 3, head ≤ 2, body ≤ 2, trinket 1 ≤ 3 (Compass ≤ 6) and trinket 2 ≤ 2.
  - The Knight Plate (+2.6) and Ninja Headband (+2.8) sit 0.6–0.8 pp over, well inside the
    ±1.4 pp noise.
  - The four outliers were fixed (the † rows).
- **Horizontal spread per slot** (budget ≤ 4 pp):
  - weapon 4.1 pp (Wand +3.3 to Crossbow −0.8)
  - off-hand 2.4 pp
  - head 2.0 pp
  - body 1.8 pp
  - trinket 3.4 pp
- **Items that read ~0 are class tools, not generic upgrades.** When every class carries them:
  - The Crossbow needs a High Roller.
  - The Arcane Staff needs runed dice.
  - The Great Axe needs repeated hits on one target.
  - The Claws need low dice.
- **Affinity check** (a signature piece at II vs the best non-signature piece at mid): not
  measured separately. At mid the kit is tier III and every class sits within ±5 pp.

### Variants (vs the Standard of the same item, seed 1001; ±2.8 pp)

| item | Standard | variants (Δ pp vs the Standard) |
|---|---|---|
| Arming Sword | 62.7 | Training +0.8, Knight's +2.7, Saber +1.5, Rapier −0.4, Flame +1.8, Frost −1.3 |
| Greatsword | 66.3 | Steel +0.6, Zweihander † +0.5 (+7.6) |
| Hand Axe | 65.6 | Twinbit +0.5, Cleaver † −3.8 (−7.6 with the reroll cost, −5.0 with −2 HP), Bone −0.5 |
| Great Axe | 61.7 | War −0.2, Jagged +3.4, Golem −2.1 (at −3 HP; now −1) |
| Warhammer | 63.9 | Smith +0.2, Morningstar −0.5, Club +0.4, Mallet +0.8, Bone −2.2 |
| Spear | 66.5 | Halberd +2.1, Trident +0.0 |
| Scythe | 66.1 | Bone −1.0 |
| Dagger † | 61.5 | Leaf −0.3, Venom +2.9, Bone +1.8 |
| Arcane Staff | 63.3 | Quarterstaff +1.1, Frost +2.6, Sun † +1.2 (+15.9), Bone +2.0 |
| Druid Staff † | 64.3 | Living −0.4 |
| Wand | 67.2 | Sapphire −3.1, Orb −2.3 |
| Hunting Bow | 63.0 | Short −0.5, Composite +0.9, Long +1.7 |
| Crossbow | 59.2 | Arbalest +2.0, Bone † +2.9 (+4.3) |
| Claws | 62.5 | Knuckles +2.2, Gauntlet +1.6 |
| Round Shield | 63.5 | Plank † +1.2 (−2.2), Heraldic +1.7, Tower † −0.4 (−5.0), Bone +2.5 |
| Spiked Shield | 63.8 | Dragon −0.5, Bone Bulwark +2.2 |
| Parrying Dagger † | 62.5 | Sai +0.6 |
| Quiver | 61.7 | Bone † +1.2 (+3.9) |
| Knight Helm | 63.8 | Bone +0.0 |
| Wizard Hat | 66.2 | Grave −1.0 |
| Bandit Mask | 67.8 | Grave Hood +0.2 |
| Ninja Headband † | 66.3 | Ninja Mask −2.0 |

- Within each base type, every variant but three is within 3 pp of its Standard.
- **The three exceptions** are borderline at this noise level:
  - the Jagged Axe (+3.4)
  - the Wand's Standard vs the Sapphire Wand (3.1 apart)
  - the Cleaver (−3.8). It is now the base rule plus +2 on turn 1, a strict upgrade apart from
    the Standard's ×1.2 Cleave, so most of that gap is noise.
- **Spreads above 3 pp** are all under 1.5× the noise of a single row:
  - the Arming Sword (Knight's +2.7 to Frost −1.3)
  - the Round Shield
  - the Great Axe

### Deviations from the design doc (and why)

- **Numbers:** everything above. The design calls them starting values for the sim, and the
  bands decide.
- **Content counts:** the §0 summary says 36 weapon and 14 off-hand variants, but its own §5
  tables list 55 and 16. The tables were implemented.
- **Standards:**
  - The Wizard Hat's Standard is a count-rule Standard (Block), because Arcana counts turns.
  - The ×1.2 Standard still scales the fractional rules: multipliers, factors, percents,
    Crush and the Volley.
  - With small integers ×1.2 often rounds back to the same number, e.g. the Arcane Staff and
    Twin Edge.
- **Compass:**
  - The tie-break is removed (measured −5 pp; the "lower" version was +5 pp).
  - The board reroll starts with the 2nd biome.
  - Migration raises the Trinket rank to 6 for anyone whose old Boots had the reroll, so it
    survives migration day.
- **Base stats:** no +1 ATK at R8, and the Armor HP is halved (+2 max).
- **Rule shapes:**
  - Per-attack and per-turn rules have a per-fight limit, and item pips add after the
    multiplier.
  - The Mage Robe, Wrench, Goggles, Smoke Bomb (a cap), Healer's Flask, Paladin Cuirass and
    Paladin Helm are reshaped (see the levers table).
  - The Cleaver lost its ⚖ costs: every reroll or max-HP cost measured −5 to −8 pp.
- **Dino Suit:** its weaken is −35/40/40%, because the class's BOO! is already −35%, not the
  design's −30%.
- **Variant rules:** the Great Mallet and the Arbalest are two-handed, as designed. The Bone
  Mace's "armored enemy" is an enemy with Block.
- **Back items:**
  - **Bone Collector** is a milestone (`bone_collector`, 300 skeletons) that grants the three
    skeleton cloaks.
  - The Orc Warpack and the Bear Pelt come from feats (`ItemDefs.BACK_FEATS`).
  - The Bear Pelt's Large-rig fit test is presentation work; core only grants it.
- **Migration:**
  - Only trinket traits auto-equip, for every owned class. The weapon, off-hand and head trait
    carriers are granted but not equipped: a Sword on every class would replace its signature
    kit.
  - The Opener trait grants the Spear. The Belt Pouch is free when the old Boots and Charm
    were both L5+.
  - Old in-run saves map their traits to tier-II items (`MetaRun._legacy_items`).
- **`crowns_capped()`** (skins for Crowns) needs the four ranks at R8 and the Belt Pouch.
  Items and variants are collections and don't count.
- **Old UI shims:** `Profile.gear` (read-only legacy view), `Camp.level_gear` (maps to
  `rank_up`) and `CampInfo` names for the rank groups keep the current Armory modal compiling
  until the presentation pass replaces it. `set_trait` returns an error.

### Sim flags (`tools/sim.gd`)

- `--armory=<slot>:<item>[:<variant>],…` equips an item for every class. The sim grants it,
  and `trinket2` buys the Belt Pouch.
- `--variant=<item>:<variant>` switches every class holding the item to that variant.
- `--kit=best` uses `BotMeta.best_loadout`: `BotMeta.BEST` per slot, then `BEST_TRINKETS`,
  from the table above.
- `--item=<item>.<key>=I/II/III` or `<variant>.<key>=v` overrides numbers (`ItemDefs.TUNE`).
- `--strip=armory|gear` sets every rank to R0 with no pouch.
- `--strip=atk|hp|affinity|pouch` switches off one part: the ATK or HP base stat, affinity,
  or the pouch.
- `--strip=slot:<slot>` empties a slot for every class.
- `--strip=rank:<group>:<n>` sets one rank.
- The campaign bot equips `BotMeta.TRINKET_PREF` (Compass first once Trinket R6 turns its
  reroll on) and buys ranks, items and crafts from `Camp.catalog()`.
- `tools/items_table.gd` prints the item tables below.

### Item numbers (I / II / III; the Standard's ×1.2 not applied; `ItemDefs.ITEMS`)

| weapon | rule | I | II | III | Standard |
|---|---|---|---|---|---|
| Arming Sword | Twin Edge: Pair or Two Pair: +1 damage after the multiplier (1 per fight). | flat 1, uses 1 | flat 1, uses 1 | flat 1, uses 1 | base numbers x1.2. |
| Greatsword | Great Arc: Three of a Kind or better: combo multiplier +0.1. | mult 0.05 | mult 0.05 | mult 0.1 | base numbers x1.2. |
| Hand Axe | Cleave: A kill carries 20% of the excess damage to the next enemy. | pct 0.1 | pct 0.15 | pct 0.2 | base numbers x1.2. |
| Great Axe | Rampage: Each consecutive attack on the same target: +1 damage, stacking to 3; resets on a target change or kill. | per 1, stacks 1 | per 1, stacks 2 | per 1, stacks 3 | base numbers x1.2. |
| Warhammer | Crush: The highest die in the scoring group (never a Heavy die) counts x1.25; the extra pips add after the multiplier (1 per fight). | crush 1.15, uses 1 | crush 1.2, uses 1 | crush 1.25, uses 1 | base numbers x1.2. |
| Spear | First Strike: The first attack of each fight deals x1.05 (x1.1 against a final boss). | factor 1.02, boss 0.03 | factor 1.03, boss 0.03 | factor 1.05, boss 0.05 | base numbers x1.2. |
| Scythe | Reap: The first kill of each fight heals 1. | heal 1, uses 1 | heal 1, uses 1 | heal 1, uses 1 | base numbers x1.2. |
| Dagger | Quick Hands: +1 combat reroll on turns 1-1. | turns 1 | turns 1 | turns 1 | Block 1 on turn 1 of elite and boss fights (doesn't stack). |
| Katana | Flow: A turn with 2+ dice rerolled: +1 damage after the multiplier (1 per fight). | dice 2, flat 1, uses 1 | dice 2, flat 1, uses 1 | dice 2, flat 1, uses 1 | Block 1 on turn 1 of elite and boss fights (doesn't stack). |
| Arcane Staff | Channel: Runed dice in the scoring group: +1 damage each after the multiplier (max 1; 1 per fight). | pip 1, max 1, uses 1 | pip 1, max 1, uses 1 | pip 1, max 1, uses 1 | base numbers x1.2. |
| Druid Staff | Grove: At each biome change, raise the lowest face of 1 dice by 1. | dice 1 | dice 1 | dice 1 | Block 1 on turn 1 of elite and boss fights (doesn't stack). |
| Wand | Spark: The first attack each fight with a multiplier of 2+: +0.15 multiplier. | mult 0.05 | mult 0.1 | mult 0.15 | base numbers x1.2. |
| Hunting Bow | Opening Volley: At fight start, shoot a random enemy for 2 (+15% per lap after the first). | dmg 1 | dmg 1 | dmg 2 | base numbers x1.2. |
| Crossbow | Deadshot: High Roller: +2 damage after the multiplier. | flat 1 | flat 1 | flat 2 | base numbers x1.2. |
| Claws | Scrap: 2+ dice showing 1 or 2: +2 damage after the multiplier (2 per fight). | dice 2, per 1, uses 1 | dice 2, per 1, uses 2 | dice 2, per 2, uses 2 | base numbers x1.2. |
| Wrench | Tinker: Shop Face Raises cost 20. | edits 0, raise_price 22 | edits 0, raise_price 20 | edits 0, raise_price 20 | Block 1 on turn 1 of elite and boss fights (doesn't stack). |

| offhand | rule | I | II | III | Standard |
|---|---|---|---|---|---|
| Round Shield | Bulwark: Block 1 on turn 1. Tier III: Last Stand (once per run, survive a lethal hit at 1 HP from above 50%). | block 1, last_stand 0 | block 1, last_stand 0 | block 1, last_stand 1 | base numbers x1.2. |
| Spiked Shield | Thorns: An enemy whose attack hits you or your Block takes 1. | thorns 1 | thorns 1 | thorns 1 | base numbers x1.2. |
| Oath Shield | Aegis: A Pair or better grants Block = the set's value x0.2 (1 per fight). | x 0.1, uses 1 | x 0.15, uses 1 | x 0.2, uses 1 | base numbers x1.2. |
| Parrying Dagger | Steady: Keep 3+ dice unrerolled: +1 damage after the multiplier (1 per fight). | dice 3, uses 1 | dice 3, uses 1 | dice 3, uses 1 | Block 1 on turn 1 of elite and boss fights (doesn't stack). |
| Spellbook | Tome: The 3rd attack of each fight: combo multiplier +0.1. | mult 0.05 | mult 0.05 | mult 0.1 | base numbers x1.2. |
| Quiver | Spare Arrows: Every 3rd attack also shoots a random enemy for 2 (+15% per lap after the first). | dmg 1 | dmg 1 | dmg 2 | base numbers x1.2. |
| Smoke Bomb | Vanish: The first enemy attack of each fight deals 30% less (max 1). | pct 0.2, max 1 | pct 0.25, max 1 | pct 0.3, max 1 | base numbers x1.2. |
| Shuriken | Barrage: Each rerolled die deals 1 to a random enemy, max 1 per fight. | dmg 1, max 1 | dmg 1, max 1 | dmg 1, max 1 | base numbers x1.2. |

| head | rule | I | II | III | Standard |
|---|---|---|---|---|---|
| Knight Helm | Steadfast: When a rune or item gives you Block: +1 more (once per turn, 1 turn(s) per fight). | extra 1, uses 1 | extra 1, uses 1 | extra 1, uses 1 | base numbers x1.2. |
| Paladin Helm | Vow: Three of a Kind or better heals 1, 1 time(s) per fight. | heal 1, uses 1 | heal 1, uses 1 | heal 1, uses 1 | base numbers x1.2. |
| Wizard Hat | Arcana: On turns 1-1 the first rune trigger fires twice (never re-doubles Resonance or Rune Echo). | turns 1 | turns 1 | turns 1 | Block 1 on turn 1 of elite and boss fights (doesn't stack). |
| Bear Hat | Ferocity: Below 50% HP: +2 damage. | flat 1 | flat 2 | flat 2 | base numbers x1.2. |
| Engineer Goggles | Appraise: Shop dice cost 10% less. | pct 0.05 | pct 0.1 | pct 0.1 | base numbers x1.2. |
| Ninja Headband | Focus: A reroll of exactly one die is free, 1 per fight. | uses 1, per_turn 0 | uses 1, per_turn 0 | uses 1, per_turn 0 | Block 1 on turn 1 of elite and boss fights (doesn't stack). |
| Bandit Mask | Ambush: After a board move on doubles, the next fight's first attack deals x1.04. | factor 1.02 | factor 1.03 | factor 1.04 | base numbers x1.2. |
| Bone Crown | Dominion: Each kill: +1 damage on your next attack, stacking to 2. | max 1 | max 2 | max 2 | base numbers x1.2. |

| body | rule | I | II | III | Standard |
|---|---|---|---|---|---|
| Knight Plate | Plated: Block 1 at the start of combat turns 1-1. | block 1, turns 1 | block 1, turns 1 | block 1, turns 1 |  |
| Paladin Cuirass | Blessed: Two Pair or better heals 1, 1 time(s) per fight. | heal 1, uses 1 | heal 1, uses 1 | heal 1, uses 1 |  |
| Barbarian Harness | Brawn: Heavy dice in the attack: +1 damage each after the multiplier (max 2). | pips 1, dice 2 | pips 1, dice 2 | pips 1, dice 2 |  |
| Mage Robe | Rune-woven: Ember deals +1; tier III: Thunder too. | dmg 1, thunder 0, poison 0 | dmg 1, thunder 0, poison 0 | dmg 1, thunder 1, poison 0 |  |
| Rogue Leathers | Nimble: Keep 2+ dice all turn: bank +1 reroll, 1 time(s) per fight. | max 1 | max 1 | max 1 |  |
| Ranger Tunic | Hunter: +1 damage against enemies at full HP. | flat 1 | flat 1 | flat 1 |  |
| Ninja Gi | Poise: A reroll that creates a match heals 1, max 1 per fight. | max 1 | max 1 | max 1 |  |
| Druid Robe | Bark: Completing a lap heals +2 HP. | heal 1 | heal 2 | heal 2 |  |
| Engineer Overalls | Patchwork: After each fight won, heal 1. | heal 1 | heal 1 | heal 1 |  |
| Hooded Robe | Shroud: Poison you apply +2. | poison 1 | poison 1 | poison 2 |  |
| Dino Suit | Thick Hide: Block 1 on combat turns 1-3; BOO!'s boss weaken becomes 40%. | block 1, turns 1, weaken 0.35 | block 1, turns 2, weaken 0.4 | block 1, turns 3, weaken 0.4 |  |

| trinket | rule | I | II | III | Standard |
|---|---|---|---|---|---|
| Tankard | Hearty: Lap heal +1%; tier III: campfires heal +5% more. | lap 0.005, campfire 0 | lap 0.005, campfire 0 | lap 0.01, campfire 0.05 |  |
| Compass | Wayfinder: Portal range +4; Trinket rank 6+ (slot 1 only): +1 board reroll in each biome after the first. | portal 2, pair_pick 0 | portal 3, pair_pick 0 | portal 4, pair_pick 0 |  |
| Lantern | Lamplight: Traps, lava and heat hurt 50% less; tier III: dodge traps and ice on 3+. | pct 0.2, dodge 0 | pct 0.35, dodge 0 | pct 0.5, dodge 3 |  |
| Coin Purse | Thrift: Gold +8%; tier II: passing the Treasury banks +5; tier III: cash-outs x1.25. | gold 0.03, treasury_step 0, cashout 1 | gold 0.05, treasury_step 3, cashout 1 | gold 0.08, treasury_step 5, cashout 1.25 |  |
| Trader's Map | Haggle: Restocks cost 7; tier II: 1 free restock per shop; tier III: shops +1 item. | restock 7, free 0, items 0 | restock 7, free 1, items 0 | restock 7, free 1, items 1 |  |
| Healer's Flask | Apothecary: Every shop offers a potion; tier III: potions heal +3%. | heal 0 | heal 0 | heal 0.03 |  |
| Skeleton Key | Unlock: Chest runes: 1 of 4; tier II: chest gold x1.25; tier III: the first chest per biome is a rune chest. | choices 4, gold 1, first_rune 0 | choices 4, gold 1.25, first_rune 0 | choices 4, gold 1.25, first_rune 1 |  |
| Loaded Die | Weighted: At the first combat roll of each fight, 2 dice showing 0 or 1 reroll free. | dice 1 | dice 1 | dice 2 |  |

| variant | base | secondary | unlock | craft |
|---|---|---|---|---|
| Training Sword (`sword_training`) | Arming Sword | Lesson: While you have 3 dice or fewer: +1 combat reroll on turn 1. | Win 15 fights with the Arming Sword equipped. | 60 Crowns / 2 Sigils |
| Knight's Sword (`sword_knight`) | Arming Sword | Guarded: Scoring a Pair also grants 2 Block. | Win 45 fights with the Arming Sword equipped. | 90 Crowns / 2 Sigils |
| Saber (`sword_saber`) | Arming Sword | Slash: Pairs also hit a second enemy for 25% of the attack. | Win 90 fights with the Arming Sword equipped. | 120 Crowns / 2 Sigils |
| Rapier (`sword_rapier`) | Arming Sword | Precision: High Roller also counts for Twin Edge at half value. | Score 200 High Rollers. | 120 Crowns / 2 Sigils |
| Flame Sword (`sword_flame`) | Arming Sword | Burning: Each 6 in a scoring Pair deals 3 to all enemies. | Defeat the Cinder King with a Sword equipped. | 120 Crowns / 2 Sigils |
| Frost Cleaver (`sword_frost`) | Arming Sword | Chill: A Pair of 1s or 2s Freezes the target (once per fight). | Defeat the Frost Warden with a Sword equipped. | 120 Crowns / 2 Sigils |
| Steel Greatsword (`greatsword_plain`) | Greatsword | Steel: +3 max HP; Great Arc -0.05. | Win 15 fights with the Greatsword equipped. | 60 Crowns / 2 Sigils |
| Zweihander (`greatsword_zwei`) | Greatsword | Reach: Three of a Kind or better also splashes 5% to the other enemies. | Win 45 fights with the Greatsword equipped. | 90 Crowns / 2 Sigils |
| Twinbit Axe (`axe_twinbit`) | Hand Axe | Double Chop: Two Pair: +3 damage after the multiplier. | Win 15 fights with the Hand Axe equipped. | 60 Crowns / 2 Sigils |
| Cleaver (`axe_cleaver`) | Hand Axe | Butcher: +2 damage on turn 1. | Win 45 fights with the Hand Axe equipped. | 90 Crowns / 2 Sigils |
| Bone Axe (`axe_bone`) | Hand Axe | Grisly: Cleave's carried damage also applies 2 Poison. | Defeat 300 skeletons. | 120 Crowns / 2 Sigils |
| War Axe (`axe_war`) | Great Axe | Frenzy: Rampage stacks to 4. | Win 15 fights with the Great Axe equipped. | 60 Crowns / 2 Sigils |
| Jagged Axe (`axe_jagged`) | Great Axe | Bleed: Each Rampage stack also applies 1 Poison. | Win 45 fights with the Great Axe equipped. | 90 Crowns / 2 Sigils |
| Golem Axe (`axe_golem`) | Great Axe | Crushing: Rampage resets only on a kill (not on a target change); -1 max HP. | Defeat the Bone Golem 10 times. | 120 Crowns / 2 Sigils |
| Smith's Hammer (`hammer_smith`) | Warhammer | Tempered: A Crush die showing 6 counts +1 pip more. | Win 15 fights with the Warhammer equipped. | 60 Crowns / 2 Sigils |
| Morningstar (`hammer_morningstar`) | Warhammer | Spikes: Crush also deals 3 to a random other enemy. | Win 45 fights with the Warhammer equipped. | 90 Crowns / 2 Sigils |
| Spiked Club (`hammer_club`) | Warhammer | Rend: Crush applies 2 Poison. | Win 90 fights with the Warhammer equipped. | 120 Crowns / 2 Sigils |
| Great Mallet (`hammer_mallet`) | Warhammer | Heavy Swing: Two-handed; Crush +0.3 more. | Win a run with a Warhammer at A3+. | 120 Crowns / 2 Sigils |
| Bone Mace (`hammer_bone`) | Warhammer | Bonebreak: Crush against an enemy with Block ignores 50% of it. | Defeat the Bone Champion 3 times. | 120 Crowns / 2 Sigils |
| Halberd (`spear_halberd`) | Spear | Sweep: The First Strike attack splashes 25% to all other enemies. | Win 15 fights with the Spear equipped. | 60 Crowns / 2 Sigils |
| Golden Trident (`spear_trident`) | Spear | Gilded: +3 gold per kill. | Win a run with a Spear. | 120 Crowns / 2 Sigils |
| Bone Scythe (`scythe_bone`) | Scythe | Harvest: Kills also give +1 pet charge. | Win 15 fights with the Scythe equipped. | 60 Crowns / 2 Sigils |
| Leaf Dagger (`dagger_leaf`) | Dagger | Light: Keep 2+ dice on turn 1: +1 damage. | Win 15 fights with the Dagger equipped. | 60 Crowns / 2 Sigils |
| Venom Dagger (`dagger_venom`) | Dagger | Venom: Attacks with a Pair apply 2 Poison. | Win 45 fights with the Dagger equipped. | 90 Crowns / 2 Sigils |
| Bone Shiv (`dagger_bone`) | Dagger | Shiv: +2 damage against poisoned enemies. | Kill 100 enemies with Poison. | 120 Crowns / 2 Sigils |
| Quarterstaff (`staff_quarter`) | Arcane Staff | Unbound: Channel also counts one un-runed die in the group (+1 damage). | Win 15 fights with the Arcane Staff equipped. | 60 Crowns / 2 Sigils |
| Frost Staff (`staff_frost`) | Arcane Staff | Rime: A runed die showing 1 Freezes the target (once per fight). | Win 45 fights with the Arcane Staff equipped. | 90 Crowns / 2 Sigils |
| Sun Staff (`staff_sun`) | Arcane Staff | Radiant: Each runed die in the group heals 1 (max 1 per fight). | Defeat the Lich with an Arcane Staff. | 120 Crowns / 2 Sigils |
| Bone Staff (`staff_bone`) | Arcane Staff | Soul: Each kill adds +1 damage to your next attack (max +3). | Comes with the Necromancer; or win 90 fights with the Arcane Staff. | 120 Crowns / 2 Sigils |
| Living Staff (`staff_living`) | Druid Staff | Bloom: Each Grove raise also heals 3. | Win 15 fights with the Druid Staff equipped. | 60 Crowns / 2 Sigils |
| Sapphire Wand (`wand_sapphire`) | Wand | Focus: The Spark turn also banks +1 reroll. | Win 15 fights with the Wand equipped. | 60 Crowns / 2 Sigils |
| Orb Wand (`wand_orb`) | Wand | Hex: The Spark attack also applies 3 Poison. | Win 45 fights with the Wand equipped. | 90 Crowns / 2 Sigils |
| Short Bow (`bow_short`) | Hunting Bow | Quick Draw: The Volley also fires on turn 2 at half damage. | Win 15 fights with the Hunting Bow equipped. | 60 Crowns / 2 Sigils |
| Composite Bow (`bow_composite`) | Hunting Bow | Piercing: The Volley and Spare Arrows ignore Block. | Win 45 fights with the Hunting Bow equipped. | 90 Crowns / 2 Sigils |
| Longbow (`bow_long`) | Hunting Bow | Marksman: The Volley targets the highest-HP enemy and deals +25%. | Win at A3+ with a Hunting Bow. | 120 Crowns / 2 Sigils |
| Arbalest (`crossbow_arbalest`) | Crossbow | Arbalest: Two-handed; Deadshot +50%. | Win 15 fights with the Crossbow equipped. | 60 Crowns / 2 Sigils |
| Bone Crossbow (`crossbow_bone`) | Crossbow | Reload: A Deadshot kill banks +1 reroll for next turn (once per fight). | Win 45 fights with the Crossbow equipped. | 90 Crowns / 2 Sigils |
| Knuckles (`claws_knuckles`) | Claws | Brawl: A die showing 1: +1 damage. | Win 15 fights with the Claws equipped. | 60 Crowns / 2 Sigils |
| Gauntlet (`claws_gauntlet`) | Claws | Guard: Each die showing 1 or 2 also gives 1 Block. | Win 45 fights with the Claws equipped. | 90 Crowns / 2 Sigils |
| Plank Shield (`shield_plank`) | Round Shield | Light: +1 combat reroll on turn 1. | Win 15 fights with the Round Shield equipped. | 60 Crowns / 2 Sigils |
| Heraldic Shield (`shield_heraldic`) | Round Shield | Rally: Bulwark Block left after turn 1 carries into turn 2. | Win 45 fights with the Round Shield equipped. | 90 Crowns / 2 Sigils |
| Tower Shield (`shield_tower`) | Round Shield | Wall: Bulwark also on turn 2; -1 reroll on turn 1. | Win 90 fights with the Round Shield equipped. | 120 Crowns / 2 Sigils |
| Bone Buckler (`shield_bone`) | Round Shield | Rattle: Bulwark Block broken by an attack deals 2 back. | Defeat 300 skeletons. | 120 Crowns / 2 Sigils |
| Dragon Shield (`shield_dragon`) | Spiked Shield | Scorch: Thorns also apply 1 Poison. | Defeat the Magma Golem with a Spiked Shield. | 120 Crowns / 2 Sigils |
| Bone Bulwark (`shield_bone_large`) | Spiked Shield | Bulk: +4 max HP; Thorns -1. | Win 15 fights with the Spiked Shield equipped. | 60 Crowns / 2 Sigils |
| Sai (`parry_sai`) | Parrying Dagger | Catch: A fully blocked enemy attack banks +1 reroll for next turn. | Win 15 fights with the Parrying Dagger equipped. | 60 Crowns / 2 Sigils |
| Bone Quiver (`quiver_bone`) | Quiver | Barbed: Spare Arrows apply 1 Poison. | Win 15 fights with the Quiver equipped. | 60 Crowns / 2 Sigils |
| Bone Helm (`helm_bone`) | Knight Helm | Horned: Thorns 1 while you have Block. | Defeat 300 skeletons. | 120 Crowns / 2 Sigils |
| Grave Hat (`hat_grave`) | Wizard Hat | Grave Magic: The doubled Arcana trigger also heals 1. | Win 15 fights with the Wizard Hat equipped. | 60 Crowns / 2 Sigils |
| Grave Hood (`hood_grave`) | Bandit Mask | Ambush Poison: The Ambush attack applies 2 Poison. | Win 15 fights with the Bandit Mask equipped. | 60 Crowns / 2 Sigils |
| Ninja Mask (`ninja_mask`) | Ninja Headband | Silent: A Focus reroll also adds +1 damage to this turn's attack. | Win 15 fights with the Ninja Headband equipped. | 60 Crowns / 2 Sigils |

### API for presentation (Armory core; 2026-09-29)

Everything is in `core/`. The ids match `game/actors/item_mounts.gd` (a test checks it).

**Data (`ItemDefs`, `core/content/items.gd`).**
- `ItemDefs.IDS` (display order), `ITEMS[id]` = `{name, slot, hands, mount, style, model,
  affinity, std, effect: {rule, name, desc, n, scale}, cosmetic}`. Back items have
  `effect: {}` and `cosmetic: true` (show "Style").
- `VARIANTS[vid]` = `{item, name, model, sec, sec_name, desc, unlock, [hands], n}`. The Standard
  variant's id is the item id.
- Slots `SLOTS` (weapon, offhand, head, body, trinket, trinket2, back); rank groups `GROUPS`
  (weapon, offhand, armor, trinket); `GROUP_OF[slot]`.
- Helpers: `name_of(id)` (items and variants), `slot_of`, `fits(id, slot)`, `of_slot(slot)`,
  `variants_of(item)`, `base_of(id)`, `hands(item, variant)`, `hand_mount(item)`,
  `style(item, variant)`, `affinity(item, class)`, `rank_tier(rank)`,
  `tier_for(item, slot, class, rank)`, `num(item, key, tier, variant)`,
  `rule_text(item, tier, variant)` (the rule with that tier's numbers), `std_text(item)`,
  `sec_of(variant)`, `unlock_text(variant)`, `craft_cost(variant, sigils)`,
  `price(item, owned_classes, sigils)`, `kit_items(class)`, `kit_class(item)`,
  `rank_cost(rank)`, `base_stats(ranks)`.
- Tables: `KITS` (class kits, §6), `APPEARANCE_DEFAULT`, `LOCKED_ARMOR` (Monster Kid →
  Dino Suit), `FEATS`, `BACK_FEATS`, `PRICES`, `MASTERY` (15/45/90), `CRAFT_COSTS`,
  `RANK_COSTS`, `POUCH_COST` (400), `POUCH_RANK` (5), `COMPASS_REROLL_RANK` (6), `SKELETONS`.

**Profile v3 (`Profile.armory`).**
- `{ranks, pouch, owned, variants, blueprints, mastery, feats, equipped, appearance, seen_new}`.
  Version 1 and 2 files migrate on load (`_migrate_gear`, §7.5).
- Queries: `rank(group)`, `has_pouch()`, `owns_item(id)` (also `owns("items", id)`),
  `owned_variants(item)`, `owns_variant(item, v)`, `has_blueprint(item, v)`,
  `item_mastery(item)`, `default_loadout(class)`, `loadout_for(class)` (validated:
  `{weapon: {id, variant}, offhand, head, body, trinket, trinket2, back}`),
  `resolve_items(class)` (`{slot: {id, variant, tier}}`, active items only),
  `appearance_of(class)` (`{head, body}`), `feat_met(feat, run_stats)`.
- Legacy: `gear` is a read-only view of the ranks (`helm` = armor, `blade` = weapon, `boots` =
  offhand, `charm` = trinket); `gear_traits` and `active_traits()` are empty; `grant("gear",
  "helm")` grants the Armor rank group.
- `records.counters` gains `high_rollers` and `skeleton_kills`; `records.kills_by_id` counts
  every enemy id defeated (feats).
- `apply_run_result()` returns `blueprints: [[item, variant, "mastery"|"feat"]]`,
  `items_unlocked: [[id, source]]` and `mastery: {item: fights}`.

**Camp commands** (`camp.apply([...])` replay names in brackets):
- `rank_up(group)` ["rank_up", group]; `buy_pouch()` ["buy_pouch"]
- `buy_item(id, currency = "crowns"|"sigils")` ["buy_item", id, currency]
- `craft_variant(item, variant, currency)` ["craft_variant", item, variant, currency]
- `equip_item(class, slot, id, variant = "")` ["equip_item", class, slot, id, variant]; id ""
  empties the slot; `unequip_item(class, slot)`
- `set_appearance(class, slot, value)` (head: item | "own" | "hidden"; body: item | "own")
- `mark_items_seen()`
- `variant_chips(item)`: the variant picker rows `{id, name, secondary, desc, state:
  owned|craftable|locked, unlock, cost, mastery: [fights, needed]}`
- Legacy: `level_gear(helm|blade|boots|charm)` maps to `rank_up`; `set_trait` is an error.
- `catalog()` lists `rank_up`, `buy_pouch`, `buy_item` (Crowns) and `craft_variant` entries.

**Camp events.**
- `upgrade_bought {track: "armory", id: group | "pouch", level}`
- `item_unlocked {id, source: crowns | sigils | feat}`; milestone items come as
  `unlocked {kind: "items", id, source: "milestone"}`
- `variant_crafted {item, variant, source: crowns | sigils}`
- `blueprint_unlocked {item, variant, source: mastery | feat}`
- `mastery_changed {item, fights, next}` (next = the next threshold, 0 when all are done)
- `item_equipped {class, slot, id, variant, loadout}`, `appearance_set {class, slot, value}`,
  `items_seen {}`
- `run_banked` carries `blueprints` and `items_unlocked`.

**Unlocks.** `UnlockDefs.all_ids("gear")` = the rank groups. Milestones grant items with
`["items", id]`: `wanderer` (Hand Axe, Coin Purse), `gate_crasher` (Compass, Lantern),
`boss_seen` (Crossbow, Healer's Flask), `bone_collector` (new: 300 skeletons → the three
skeleton cloaks). A class unlock grants its kit.

**Run.**
- `run.meta.items` = `{slot: {id, variant, tier}}`; `meta.back`, `meta.appearance`,
  `meta.ranks`. `RunState.item(slot)`.
- `run.meta.look` = the full worn loadout (`Profile.loadout_for`, inactive rank-0 items too),
  presentation only: the run hero wears it (`ArmoryLook.of_meta`).
- `GameFlow.loadout_info()` = `{items: {slot: {id, variant, tier, name, variant_name, rule,
  text, secondary, style, hands}}, back, appearance, style}` (style = the weapon's attack
  style; "" = the class default).
- `RunState.item_state` (ambush, dominion, soul, key_act) and `CombatState.item_state` (this
  fight's counters) are serialised.
- `game_over.stats` gains `loadout` (`{slot: {id, variant}}`), `item_fights`, `high_rollers`,
  `skeleton_kills` and `kills_by_id`.

**Run events.**
- `item_triggered {id: base item, variant, slot, effect, value, ...}` for every rule that
  fires. Effects: the rule ids (twin_edge, great_arc, cleave, rampage, crush, first_strike,
  reap, quick_hands, flow, channel, grove, spark, opening_volley, deadshot, scrap, tinker,
  bulwark, thorns, aegis, steady, tome, spare_arrows, vanish, barrage, steadfast, vow, arcana,
  ferocity, focus, ambush, ambush_ready, dominion, dominion_stack, plated, blessed, brawn,
  hunter, poise, patchwork, thick_hide, treasury_step, cashout, weighted), the variants'
  secondaries (lesson, guarded, slash, burning, chill, reach, double_chop, grisly, bleed,
  spikes, rend, bonebreak, sweep, gilded, harvest, light, venom, shiv, unbound, rime,
  radiant, soul, soul_stack, bloom, wand_focus, hex, quick_draw via opening_volley with
  share 0.5, reload, brawl, guard, rally, wall, rattle, scorch, catch, barbed, horned,
  grave_magic, ambush_poison, silent) and "standard" (the count-based Standard's Block).
  Extras: `enemy_idx`, `die_idx`, `stacks`, `dice`, `kept`, `rerolls_left`, `banked`,
  `treasury`, `share`.
- Effects also use the usual events: `block_gained {source: "item"}`,
  `hp_changed {source: "item"}`, `damage {source: "item" | "cleave" | "thorns"}`,
  `status {source: "item"}`, `gold_changed {source: "item"}`,
  `dice_rolled {context: "combat", source: "loaded_die"}`, `face_changed {source: "grove"}`.
- A fight can end before turn 1 (the Opening Volley): `combat_won` right after
  `combat_started`.
- `passive_triggered {id: "last_stand"}` when the Round Shield III saves the hero.

## Current balance (2026-09-29 combined: 11 classes + new biomes)

This section is authoritative except for the profile bands and the gear, which the Armory
section above replaces. It covers the merge of the 11-class work (`main`) with the new
biomes (`wp-b2-new-biomes`). Both sections below it are kept as history: the 11-class pass was
tuned against the old final bosses, and the new-biomes pass never saw the new classes. Where
either disagrees with this section, this section wins. Designs:
`docs/design/2026-09-28-classes-enemies-skins.md` and `docs/design/2026-09-29-new-biomes.md`.

### How this was measured

- Realistic policy, A0, standard mode, 28-tile board, unless a row says otherwise.
- **Class rows:** 600 runs per class (6 seed shards of 100, `--seed=1001, 2001, …, 6001`). About
  ±2 pp of noise per row; the 11-class average is about ±0.6 pp.
- **A10 rows:** 300 runs per class (`--asc=10`, seeds 1001–3001).
- **Route sweep:** max profile, `--class=all --runs=28` at seeds 50001 and 100001 for each route:
  616 runs per route, 22,176 in all.
- **Short Road sweep:** the same seeds, `--mode=short --route=<tier 1>,<second>`: 616 runs per
  route, 12,936 in all.
- **"Before" numbers:** the merge commit with no retuning.
- **Reading route rows:** a route row's standard error is about 2 pp. Even with every route
  truly equal, about 1 route in 7 lands outside ±3 pp by noise alone. The biome marginals
  (7,392 runs per tier-1 or tier-2 biome) are the better signal.

### What changed in this pass, and why

| lever | was | now | why |
|---|---|---|---|
| mid preset: Pumpkin Sprite XP | 140 (L4) | **155 (L5)** | The mid preset models run 10 of the realistic campaign. In the combined game, the median run-10 profile has 154 XP and 22 of 32 profiles are at 150+ (L5). L5 adds "removes Burn", so the preset understated mid by about 3 pp. It was 10 XP short of the level that answers the Cinder King. |
| mid preset: minigames owned | fossil_hunter (+ defaults) | + plinko, fishing, high_low, memory_match | Fidelity only: every run-10 snapshot owns these. They are not equipped, so the sim is unchanged. |
| Cinder King | HP 1560, Burn 4 / 5 | **HP 1800, Burn 2 / 3** | Burn is a flat, Block-ignoring clock. It is mild at max, where the L10 Pumpkin Sprite cleanses it and the hero has a big HP pool, but brutal at mid. At mid the Cinder King won 46% vs the Lich's 62%, and it is 1 of the 3 bosses mid can meet. With the boss forced, removing Burn entirely raised its boss-win by 33 pp at mid but only 17 pp at max, so less Burn and more HP helps mid without moving max. |
| The Moon King | HP 900 | **860** | It sat −3 pp below the other five at max once the classes were in. |
| Orc Warcamp | elite leader `brute`, 2 drums | **elite `orc_raider`, 1 drum** (`WARCAMP_DRUMS`) | The Warcamp was −3.5 pp vs its tier, from deaths in laps 7–10 (4.2% of runs vs the Hollow's 0.8%): Brute elites with rallied orcs. Either change alone was noise; together they gave +2 to +4 pp on Warcamp routes. |
| Deep Mines | ore 15 gold | **20** (`ORE_GOLD`) | The Mines were −2.0 pp vs their tier. Ore is the only economy in the biome, and the cave-in traps cost HP. |
| Short Road finale HP | Warcamp ×0.68, Moonlit ×0.72 | **Warcamp ×0.75, Moonlit ×0.70** | The Warcamp and Cinder King changes made Warcamp finales too easy (+6 to +9 pp). Moonlit finales were −4 to −7 pp. |
| New-biome Sigil price | 5 | **8** (`SIGIL_PRICE_BY_ID.biomes`) | With the 11-class Sigil prices, the campaign bot bought the Deep Mines at run 4 (target 8). The merge alone caused this. |
| `prospector` | 20 cash-outs or 12 runs | **15 cash-outs or 10 runs** | Once the Mines could no longer be bought early, the milestone landed at run 10.5. |

Tried and rejected (paired seeds, 1,850–5,300 runs each; every effect within noise unless noted):
- **Hollow:** event heal 3% → 0% and the event mix 2 → 1. The Hollow got *better* (+0.6 and
  +2.0), so its edge comes from its weak enemy pools, not from its events.
- **Warcamp:** Orc Drummer and Warchief rally 2 → 1, `ATK_BONUS_CAP` 8 → 5, drum gold 14 → 22
  or 24, no drum rebuild, a campfire in the mix. The Brute at ×0.8 HP did help (+3), but the
  Brute is shared with 6 other biomes.
- **Magma Golem:** phase-1 Block 32 → 24, with or without +80 HP. No mid effect.
- **Economy:** `--tune-gold=1.1` moved mid by −0.8 (noise) and max by +1.6.
- **Affixes:** off at mid was −0.4. Removing the Mines from the mid preset was +0.4.
- **Pyromancy in the mid preset** (16 of 32 run-10 profiles own it): +0.9. Left out as a coin
  flip.

Unchanged from the two passes: every class number, pet, affix and minigame, the Lich, the Bone
Warden, the Magma Golem, the Sand Colossus, the Ruins, the Moonlit twist, the Hollow and every
other biome.

### Targets and results per class (11 classes)

Targets (Vlad): realistic class average fresh 30–40%, mid 45–50%, max 55–65%, max A10 20–30%;
every class within ±5 pp of the average at fresh and mid.

| class | fresh | mid | max | max A10 | act-1 deaths (fresh) |
|---|---|---|---|---|---|
| Knight | 37.2 | 45.3 | 62.3 | 22.0 | 6% |
| Barbarian | 39.8 | 48.0 | 62.2 | 24.7 | 4% |
| Paladin | 40.7 | 48.2 | 62.7 | 19.7 | 13% |
| Mage | 40.5 | 44.2 | 62.7 | 25.7 | 4% |
| Ranger | 36.2 | 45.7 | 69.0 | 28.0 | 7% |
| Rogue | 37.2 | 46.2 | 61.0 | 21.3 | 3% |
| Ninja | 38.5 | 45.3 | 65.0 | 22.3 | 8% |
| Druid | 38.2 | 42.0 | 63.8 | 21.3 | 17% |
| Engineer | 41.2 | 45.5 | 62.2 | 21.7 | 6% |
| Necromancer | 38.0 | 44.0 | 61.0 | 20.3 | 4% |
| Monster Kid | 42.2 | 44.5 | 59.0 | 22.7 | 7% |
| **average** | **39.0** | **45.3** | **62.8** | **22.7** | |
| spread | −2.8 / +3.2 | −3.3 / +2.9 | −3.8 / +6.2 | −3.0 / +5.3 | |

**Before this pass** (the merge commit, the same seeds), the averages were fresh 39.0, mid
**40.5** (out of band), max 60.6 and A10 21.4. Mid ran from 35.7 (Necromancer, −4.8) to 44.2
(Paladin).

The fresh column did not move: the fresh route (Glade, Hollow, Throne, the Lich, no pet) holds
none of the levers.

Notes:
- **Ranger at max: +6.2** on these seeds. On 1,200 fresh seeds (7001–14001) it is 64.0% vs
  63.0% before, so most of the jump is seed luck. The pooled estimate is about +3.
- **Druid act-1 deaths:** 17% at fresh, unchanged from main (15% there, target ≤ 20%).
- **Greedy and expert policies:** not re-measured. The expert ceiling is deferred to the
  whole-game pass.

### Profile bands

| profile | before | after | target |
|---|---|---|---|
| fresh | 39.0 | **39.0** | 30–40 |
| mid | 40.5 | **45.3** | 45–50 |
| max | 60.6 | **62.8** | 55–65 |
| max A10 | 21.4 | **22.7** | 20–30 |

- **Mid is in band but near its floor.** Measurement noise is about ±0.6 pp, and a second
  2,640-run sample read 45.7.
- **Mid bosses (boss-win%)** before → after: Cinder King 46.3 → **62.5**, Lich 62.5 → 64.8,
  Magma Golem 59.0 → 60.7. Mid meets only these three.
- **Profile gaps.** Before, the Cinder King was 23 pp harder at mid than at max, while the Lich
  and the Golem were about 10 pp harder. Now all three are 8–11 pp harder at mid.

### Final bosses (max)

Boss-win% = won / reached. The route-sweep column covers the 36 routes and has the larger sample.

| boss | HP | before (route sweep) | after (route sweep) | after (class sweep) |
|---|---|---|---|---|
| The Lich | 1650 | 73.6 | 73.3 | 73.1 |
| Bone Warden | 1000 | 71.3 | 71.6 | 73.2 |
| Cinder King | **1800** (Burn 2 / 3) | 69.5 | 73.1 | 73.2 |
| Magma Golem | 960 | 68.7 | 70.2 | 70.3 |
| Sand Colossus | 1180 | 70.3 | 70.1 | 73.1 |
| The Moon King | **860** | 68.5 | 72.8 | 71.7 |
| **spread** | | −2.6 / +2.5 | **−1.8 / +1.5** | −2.1 / +0.8 |

The target was ±3 pp around the mean, and it is met.

### Standard routes (max)

Overall **62.3%** across 22,176 runs (before: 60.7%). Win% per route, with the delta from the
route mean in brackets:

| tier 1 / tier 2 | throne | magma | ruins | moonlit |
|---|---|---|---|---|
| glade / hollow | 67.7 (+5.4) | 67.2 (+4.9) | 64.1 (+1.8) | 68.7 (+6.4) |
| glade / frost | 62.2 (−0.1) | 63.6 (+1.4) | 62.5 (+0.2) | 65.1 (+2.8) |
| glade / warcamp | 59.3 (−3.0) | 62.0 (−0.3) | 59.4 (−2.9) | 58.6 (−3.7) |
| crypt / hollow | 65.6 (+3.3) | 65.7 (+3.5) | 64.9 (+2.7) | 67.7 (+5.4) |
| crypt / frost | 60.1 (−2.2) | 63.8 (+1.5) | 57.1 (−5.1) | 65.1 (+2.8) |
| crypt / warcamp | 58.1 (−4.2) | 58.1 (−4.2) | 58.8 (−3.5) | 59.7 (−2.5) |
| mines / hollow | 60.6 (−1.7) | 62.7 (+0.4) | 63.0 (+0.7) | 61.2 (−1.1) |
| mines / frost | 61.0 (−1.2) | 60.9 (−1.4) | 59.1 (−3.2) | 64.8 (+2.5) |
| mines / warcamp | 61.4 (−0.9) | 63.5 (+1.2) | 57.3 (−5.0) | 61.7 (−0.6) |

**23 of 36 routes are within ±3 pp** (before: 17), and the range is −5.1 to +6.4 (before: −8.3
to +7.0). **The ±3 pp aim is not met.**
- About 5 of the 13 misses are noise at 616 runs per route. `crypt / frost / ruins` is −5.1 and
  none of its content changed.
- The rest is the tier-2 spread, Hollow +2.6 vs Warcamp −2.5, which adds to the tier-1 spread
  (Glade +1.1, Mines −0.9).

Biome marginals (routes containing the biome, vs its tier mean):

| tier | biome | win% | Δ tier (before) | Δ tier (after) | reached boss% | boss-win% |
|---|---|---|---|---|---|---|
| 1 | glade | 63.4 | +2.2 | +1.1 | 87.7 | 72.2 |
| 1 | crypt | 62.1 | −0.3 | −0.2 | 86.4 | 71.8 |
| 1 | mines | 61.4 | −2.0 | −0.9 | 85.5 | 71.8 |
| 2 | hollow | 64.9 | +3.1 | +2.6 | 87.7 | 74.0 |
| 2 | frost | 62.1 | +0.4 | −0.2 | 87.1 | 71.3 |
| 2 | warcamp | 59.8 | −3.5 | −2.5 | 84.9 | 70.5 |
| 3 | throne | 61.8 | −0.0 | −0.5 | 81.5 | 75.8 |
| 3 | magma | 63.1 | −0.8 | +0.8 | 88.0 | 71.7 |
| 3 | ruins | 60.7 | −0.4 | −1.6 | 88.7 | 68.4 |
| 3 | moonlit | 63.6 | +1.2 | +1.3 | 88.0 | 72.3 |

- **Next lever:** the Hollow's edge. Its pools (Wisp, Cultist, Bandit, Werewolf) are the weakest
  tier-2 pools.
- **Constraint:** the Hollow is on the fresh route and in half of the mid routes, so a Hollow
  nerf costs mid about 0.7 pp. It needs a mid lever to go with it.

### Short Road (max)

Overall **62.4%** across 12,936 runs (before: 60.9%). Win% per route, with the delta from the
route mean in brackets:

| tier 1 | hollow | frost | warcamp | throne | magma | ruins | moonlit |
|---|---|---|---|---|---|---|---|
| glade | 64.1 (+1.8) | 62.7 (+0.3) | 66.9 (+4.5) | 63.1 (+0.8) | 68.2 (+5.8) | 64.1 (+1.8) | 64.4 (+2.1) |
| crypt | 63.3 (+1.0) | 59.1 (−3.3) | 60.2 (−2.1) | 62.3 (−0.0) | 63.5 (+1.1) | 60.4 (−2.0) | 60.4 (−2.0) |
| mines | 60.6 (−1.8) | 59.9 (−2.5) | 63.5 (+1.1) | 61.4 (−1.0) | 60.6 (−1.8) | 60.9 (−1.5) | 59.9 (−2.5) |

- **Tier-2 vs tier-3 finales:** 62.2% vs 62.4%, **0.2 pp apart** (target ≤ 3; before 61.3 vs
  60.6).
- **Routes within ±3 pp:** 18 of 21 (before: 16), range −3.3 to +5.8 (before: −6.2 to +6.0).
  `glade / magma` +5.8 is unchanged content and was +6.0 before.
- **Short Road bosses (boss-win%):** Cinder King 73.8, Sand Colossus 72.0, Moon King 72.7,
  Magma Golem 67.7, Lich 68.6, Bone Warden 68.1.

Per class (300 runs per cell; the before column is the merge commit):

| class | fresh | mid | max |
|---|---|---|---|
| Knight | 45.7 | 51.3 | 66.0 |
| Barbarian | 47.0 | 49.7 | 64.7 |
| Paladin | 36.3 | 46.7 | 61.7 |
| Mage | 40.7 | 50.3 | 67.0 |
| Ranger | 36.7 | 46.3 | 60.7 |
| Rogue | 37.7 | 49.0 | 57.3 |
| Ninja | 38.7 | 45.7 | 67.0 |
| Druid | 41.7 | 43.0 | 62.7 |
| Engineer | 42.3 | 51.3 | 59.7 |
| Necromancer | 41.0 | 45.3 | 63.3 |
| Monster Kid | 48.7 | 49.3 | 62.0 |
| **average** | **41.5** | **48.0** | **62.9** |
| before | 41.5 | 45.1 | 61.1 |

The Short Road misses the ±5 pp per-class rule in 5 cells:
- fresh: Monster Kid +7.2, Barbarian +5.5, Paladin −5.2
- mid: Druid −5.0
- max: Rogue −5.6

The fresh Short Road average is 41.5. On main it was 33.1, before the new-biomes Short Road
finale multipliers. The Short Road has no band of its own, so this is left for the whole-game
pass.

### Unlock pacing (realistic campaign, 16 fresh profiles × 40 runs)

| unlock | target | median before (merge) | median after |
|---|---|---|---|
| Deep Mines | 8 | **4** (bought with 5 Sigils) | 8 |
| Orc Warcamp | 12 | 11.5 | 11 |
| Moonlit Woods | 17 | 17.5 | 17.5 |
| Sunscorched Ruins | 21 | 16 | 22 |
| Paladin / Mage / Ranger / Rogue | 6 / 10 / 13 / 15 | 8 / 10.5 / 12.5 / – | 8 / 8.5 / 11 / 15 |
| Ninja / Druid / Engineer / Necromancer / Monster Kid | 19 / 23 / 27 / ≤ 32 / 20–25 | – | 20.5 / 24 / 26 / 28.5 / 24.5 |

- **Double unlocks:** no run unlocks 2 classes (0 of 640). 64 of 640 runs unlock two majors
  (class, pet or biome), as on main, where they all involved a biome.
- **Run-10 snapshot** (32 profiles):
  - Unlocked: Mines 88%, Warcamp 47%, Ruins 16%, Bone Warden 13%.
  - Classes: Mage 78%, Ranger 31%.
  - Pyromancy pack: 50%.
  - Pumpkin Sprite XP median: 154.
  - Minigame plays: Claw Machine 14, Fossil Hunter 6 (as the preset has them).
  - This is why the mid preset keeps the Mines and leaves out the Warcamp, Ruins and Moonlit.

### API notes for presentation

- **Placeholder looks.** `game/enemies/roster.gd` has placeholder looks for `rock_golem`,
  `boss_sand_colossus` and `boss_moon_king`, labelled "(placeholder)". They exist so that
  `test_enemy_looks` passes, and the presentation pass should replace them.
- **Warcamp elite.** The Warcamp's elite leader is now `orc_raider` (with the elite flag and
  affixes), and the Warcamp shows **1** drum.
- **Mini-boss homes follow the biomes design:**
  - The Orc Warchief is a Warcamp mini-boss (not Frost) and unlocks with `warpath`.
  - Moonfang is a Hollow candidate and unlocks with `night_walker`.
  - The 11-class section below says "both unlock with `warden_slayer`". That is superseded.
- **Bossbane** still needs 4 distinct final bosses per class, of the 6 that now exist.

## 11-class pass (2026-09-29: 11 classes, new enemies, affixes, 12 pets, skins; superseded where the combined section differs)

This was the authoritative section before the merge with the new biomes. Its class, boss and
route numbers were measured against the old four final bosses. The design behind it is
`docs/design/2026-09-28-classes-enemies-skins.md`.

### How to measure

```
godot --headless --path . -s tools/sim.gd -- --runs=300 --class=<id>[,<id>...] --seed=1 \
    --policy=greedy|realistic|expert --profile=fresh|mid|max [--asc=N] [--mode=standard|short]
godot --headless --path . -s tools/sim.gd -- --runs=100 --class=all --force --profile=fresh ...
godot --headless --path . -s tools/sim.gd -- --campaign=40 --campaigns=5 --policy=realistic [--snapshot=10]
godot --headless --path . -s tools/sim.gd -- --runs=100 --class=all --profile=max --affixes=off|on|force:<id>
godot --headless --path . -s tools/sim.gd -- --runs=100 --class=all --profile=max --pet=<id>|none
```

- **Policies.**
  - `greedy` is `Bot.next_command`, the naive floor.
  - `realistic` is `Bot.decide` with `AutoRules.skill = "realistic"`. Per decision it lapses
    with probability `Bot.real_heur` = 0.62 into a rule of thumb. It is AUTO's default and **the
    balance reference**.
  - `expert` is the full smart policy.
- **Profiles.**
  - `fresh` is a new profile. An explicit `--class=` (or `--force`) grants the class, so every
    class has a fresh row.
  - `mid` is the realistic campaign at run 10: Knight, Barbarian, Paladin and Mage, all biomes,
    5 packs, gear L4, the Pumpkin Sprite at L4, and affixes on.
  - `max` is everything unlocked and maxed: all 11 classes, the Pumpkin Sprite L10 and affixes on.
- **Sim flags and output.**
  - Machine-readable lines: `#row`, `#death`, `#route`, `#up`, and in campaigns `#u`, `#ms` and
    `#camp`. Seed shards can be summed.
  - `--hero=<class>.<field>=<value>` and `--cl=<ClassLogic knob>=<value>` are analysis dials; the
    shipped numbers are in `heroes.gd` and `class_logic.gd`.
  - The campaign report adds per-class and per-pet median/p90 unlock runs, "runs unlocking 2+
    classes" and "every class by run 40".
- **Sample sizes.** Seed-set noise is about ±4 pp at 300 runs, so class rows below use 600 runs
  (about ±2 pp) and pet/affix rows 1,100 runs (11 classes × 100). All rows are A0, standard mode
  and the realistic policy unless noted.

### Targets and results per class (11 classes)

Targets (Vlad, unchanged):
- Realistic class average: fresh 30–40%, mid 45–50%, max 55–65%, max A10 20–30%.
- Every class within **±5 pp of the 11-class average** at each profile.
- Greedy fresh ≥ 10% per class; expert fresh ≤ 80%.
- No class above 20% act-1 deaths.

| class | fresh | mid | max | act-1 deaths (fresh) | greedy fresh | expert fresh | max A10 |
|---|---|---|---|---|---|---|---|
| Knight | 40.8 | 46.3 | 62.2 | 7% | 20.0 | 78.0 | 26.5 |
| Barbarian | 36.8 | 48.3 | 61.7 | 2% | 18.3 | 91.3 | 21.5 |
| Paladin | 38.5 | 52.3 | 56.8 | 14% | 14.7 | 86.7 | 24.5 |
| Mage | 40.7 | 52.0 | 60.3 | 4% | 13.7 | 86.7 | 22.5 |
| Ranger | 37.3 | 47.3 | 59.0 | 6% | 10.7 | 85.3 | 26.5 |
| Rogue | 39.0 | 49.8 | 60.5 | 4% | 13.0 | 90.0 | 28.0 |
| Ninja | 41.0 | 45.0 | 64.2 | 8% | 9.0 | 92–95 | 23.0 |
| Druid | 41.0 | 45.7 | 62.2 | 15% | 19.3 | 83.3 | 19.5 |
| Engineer | 41.5 | 48.5 | 57.0 | 6% | 15.7 | 93.3 | 27.0 |
| Necromancer | 39.0 | 44.0 | 55.7 | 5% | 17.0 | 86.0 | 22.0 |
| Monster Kid | 44.5 | 43.7 | 54.3 | 6% | 18.0 | 90.0 | 20.0 |
| **average** | **40.0** | **47.5** | **59.4** | | **15.5** | **87** | **24** |

Status:
- **Met:**
  - Every class average is in band, and every class is within ±5 pp at fresh and mid.
  - At max every class is within ±5 pp except the Monster Kid (−5.1, inside the noise).
  - A10: every class is 19.5–28%.
  - Act-1 deaths are ≤ 15% for every class.
- **Not met:**
  - Ninja greedy is 9.0% (about ±1.7 pp noise).
  - Expert fresh is 78–95%. The Knight-only baseline was 80%, and the old Barbarian, Mage and
    Rogue show the same gap, so this is a skill-ceiling property of the policy rather than of
    the new classes. It is left for the planned whole-game pass (luck and expert ceiling).
- Fresh-profile class average: 40.0%. The old Knight-only fresh number was 35.8%.

**Short Road** (10 laps, 300 runs per row; target: the same ±5 pp per-class rule):

| class | fresh | mid | max |
|---|---|---|---|
| Knight | 40.7 | 52.3 | 59.7 |
| Barbarian | 34.3 | 53.0 | 54.0 |
| Paladin | 28.0 | 43.7 | 55.0 |
| Mage | 34.0 | 52.7 | 58.7 |
| Ranger | 25.3 | 45.7 | 58.3 |
| Rogue | 32.0 | 48.0 | 47.3 |
| Ninja | 30.3 | 48.0 | 59.0 |
| Druid | 31.3 | 39.0 | 51.0 |
| Engineer | 35.7 | 48.0 | 54.7 |
| Necromancer | 35.3 | 46.7 | 52.3 |
| Monster Kid | 37.0 | 46.7 | 52.7 |
| **average** | **33.1** | **47.7** | **54.8** |

Short Road misses the ±5 pp rule in 6 cells:
- fresh: Knight +7.6, Ranger −7.8, Paladin −5.1
- mid: Druid −8.7, Barbarian +5.3
- max: Rogue −7.5

The Druid grows ×1.5 per lap and plants two seeds at its single biome change on the Short Road,
which took it from 22/29/43 to 31/39/51. The rest is left for the whole-game pass.

### Classes (`core/content/heroes.gd`, `core/class_logic.gd`)

| class | HP | starting pool | rerolls | mechanic (shipped numbers) |
|---|---|---|---|---|
| Knight | 62 | Standard+Guard, Standard | 2 | – |
| Barbarian | 60 (+2 ATK) | Standard+Heavy, Standard | 2 | – |
| Paladin | 60 | **Twin**, Standard | 2 | Oath = the pool's most common face (ties high). Oath sets: +0.5 mult, +0 pip per Oath die. Sanctify ×2 per run. Shop Twin/Even ×2 |
| Mage | 64 | Standard+Ember, Standard+Echo | 2 | – |
| Ranger | 52 | Loaded+Blade, Standard | 2 | Aim ×1.3 with ≤3 dice, ×1.15 with more (no reroll this turn). Piercing Shot carries 50% of the overkill once |
| Rogue | 54 | Standard+Venom, Standard+Lucky | 2 (+1 board) | – |
| Ninja | 55 | Standard+Thunder, Odd | 3 | Shadow Step: 2 refunds per turn, 1 board refund on doubles |
| Druid | 56 | **Odd** (seed), Standard | 2 | +1 lowest seed face per lap (×1.5 on the Short Road). A new seed per biome change (2 on the Short Road), max 3. Pet +1 charge per fight |
| Engineer | 54 | Standard, Standard + Turret (Gilded) | 2 | Turret shot = pips × 0.25 / 0.75 / 1.0 by biome tier. Turret runes: guard, heavy, ember, frost, gilded |
| Necromancer | 54 | Standard+Vampire, Standard | 2 | Bone die (1 2 2 3 3 4) per kill, max 2, pool max 6. Lone foe: turns 3 and 6. Boss phase 2: one. Heal 2 each at the end |
| Monster Kid | 60 | Pretend (1 2 3 4 5 ★), Standard | 2 | ★ = Wild in combat (shares the Wild cap), the mode on the board. BOO!: cower, flee ≤25% (50% gold), bosses −35% |

Changes from the design's starting values, with why:
- **Paladin:** the Twin+Twin starter with +0.5 and +1 pip won 57/73/75%. Twin+Standard with
  +0.5 and no pip bonus keeps the Twin/sets identity.
- **Ranger:** HP 54 → 52 and the pierce carry halved (it scaled with the meta). Aim is steadier
  with a small pool.
- **Engineer:** the turret was worth about 16 pp at T=1 in tier 1, so T is 0.25/0.75/1.0 and the
  Gilded rune moved from a pool die onto the turret.
- **Druid:** the Low starter caused 25% act-1 deaths, so it starts with an Odd seed.
- **HP changes:** Knight 60 → 62, Mage 60 → 64, Rogue 58 → 54, Ninja 52 → 55, Monster Kid
  56 → 60. This brought the old four into the ±5 pp band. At 600 runs, 2 HP is worth about
  2–4 pp.

### Enemies and affixes (`core/content/enemies.gd`, `biomes.gd`, `affixes.gd`)

- **New enemies:** 8 ids, plus the `frenzy` trait (+2 attack per main-attack hit survived, max
  +6), the `rally` intent and `transform` (a once-only phase switch at ≤50% HP that drops Block).
- **Pools:** the 3.2 table of the design. Crypt's elite leader is the Bone Golem and Hollow's is
  the Fallen Paladin. Moonfang is a Hollow mini-boss candidate and the Orc Warchief a Frost one;
  both unlock with `warden_slayer`.
- **Affixes:**
  - They roll at tile spawn from a derived Rng, and are off until the `affixes` feature (the
    `brawler` milestone, run ~3).
  - Rates by lap band: regular 0/6/10/15/20%; elite leader 0/50/75/100/100% with a second affix
    0/0/0/15/30%.
  - Reward ×1.5 gold/XP per affix (Gilded: ×3 gold, ×1.5 XP, ×1.4 HP).
  - Thorned reflects **2/3** (the design said 3/4; forced it cost 5 pp).
  - At A4+ the mini-boss gets one biome affix. This replaces `ASC_MINIBOSS_TRAIT`.

Forced on every elite leader (max, 1,100 runs per row; off = 61.4%, on at normal rates = 62.5%):

| affix | Δ pp | affix | Δ pp |
|---|---|---|---|
| armored | +2.2 | regenerating | +0.2 |
| thorned | −2.9 | vampiric | −3.3 |
| warded | +1.9 | hexing | +1.4 |
| piercing | +2.3 | frostbound | +2.4 |
| frenzied | +1.7 | gilded | −2.1 |

Every affix is within ±4 pp (target ≤ 4 pp cost), because the ×1.5 rewards roughly pay for the
extra danger. With affixes on, the bands hold at mid and max.

**Routes** (max, 6,600 runs; target ±3 pp of the mean):

| route | Δ pp |
|---|---|
| crypt, frost, magma | +7.5 |
| crypt, frost, throne | −11.0 |
| crypt, hollow, magma | +14.9 |
| crypt, hollow, throne | −13.8 |
| glade, frost, magma | +12.8 |
| glade, frost, throne | −11.8 |
| glade, hollow, magma | +12.3 |
| glade, hollow, throne | −10.9 |

**This gate is not met, and the gap was already there.** On the old four classes before any of
this work, every Throne route was 42–50% and every Magma route 69–79% (±15 pp). The tier-3
final bosses (Lich and Bone Warden vs Cinder King and Magma Golem) set it, and the new enemies
and affixes did not change the shape. The boss retune belongs to the new-biomes pass.

### Pets (`core/content/pets.gd`, `core/meta/pet_logic.gd`)

There are 12 pets, each with a meter of 3–9 (the new six have 3–6). They fire automatically; XP
levels 1–5 come from fights won and Crowns buy levels 6–10.

| pet | charges on | size | fires (level L) | Δ pp at L10 (max, none = 48.3%) |
|---|---|---|---|---|
| Pumpkin Sprite | Pair or better | 6 | heal 2% + 0.5%·(L−1) | +11.3 |
| Skull Buddy | each die ≤ 2 | 4 | bite 30% + 5%·(L−1) of the combo damage | +11.3 |
| Lantern Ghost | each 6 | 5 | poison 1 + 0.7·(L−1) on every enemy | +11.6 |
| Crystal Wisp | each kept die | 9 | turn start: +1 reroll, combo ×+(0.05 + 0.01·(L−1)) | +12.6 |
| Guard Die | each attack intent | 6 | Block d6 + (L−1)/3 | +11.7 |
| Coin Mimic | each board double | 3 | +8 + 2·(L−1) gold and a bite | +11.0 |
| Pebble | 1 per 3 Block held at the attack | 4 | Block 3 + (L−1)/2 (L10 ×2), Thorns 3 + (L−1)/2 this turn | +9.1 |
| Frost Mote | each die showing 1 | 3 | freeze the target, chill it for 3 + 3·(L−1) (L5: also the biggest attacker) | +7.1 |
| Wick | Three of a Kind or better (L5: Two Pair) | 3 | 3 + 1.5·(L−1) to every enemy (L10: ignores Block) | +11.5 |
| Tinker | each combat reroll | 6 | your lowest die → its highest face (L5: two dice, L10: +1 banked reroll) | +14.8 |
| Grimoire | an attack with a rune trigger | 5 | re-fire the last rune at 1 + 0.05·(L−1) (L5: the last two, L10 ×1.25) | +12.4 |
| Bubbles | each fight won | 4 | brew a potion (L5: any type, L10: two), heal 1.5%·L | +13.7 |

- **Perks:** Pebble halves trap damage, Frost Mote stops ice freezing your dice, Wick lowers
  Burn ticks by 1, Tinker makes restocks −3, Grimoire makes chests offer 4 runes, and Bubbles
  makes shop potions −5.
- **Band:** every pet is +7 to +15 pp at L10 (before this pass the six pets were +10 to +17).
  Pet rows carry about ±3 pp of noise.

### Unlock pacing (`core/content/unlocks.gd`; realistic campaign, 20 fresh profiles × 40 runs)

Rules:
- **Classes by Sigils:** Sigils buy only the **next two** locked classes (`buyable_classes`).
  Prices are 8, with Paladin 12, Ninja and Druid 10, Engineer and Necromancer 12. The secret
  Monster Kid is never for sale.
- **One major per run:** at most **one major unlock (a class or pet)** comes from milestones per
  run; the rest wait for the next banked run. The campaign bot also doesn't buy a class or pet
  in a run that just gave one.

| class | milestone (condition, or play N runs) | target | median | p90 |
|---|---|---|---|---|
| Barbarian | brawler: win 45 fights | 1–3 | 3 | 3 |
| Paladin | oathsworn: win 3 runs with the Knight, or 8 runs | 6 | 8 | 8 |
| Mage | champion: defeat **5** mini-bosses | 10 | 10 | 13 |
| Ranger | pathfinder_trail: reach the final boss with **4** classes, or 16 | 13 | 11 | 16 |
| Rogue | veteran: win 8 runs, or 15 | 15 | 15 | 15 |
| Ninja | shadow_pact: win 2 runs with the Rogue, or **1,700** rerolls, or 22 | 19 | 21 | 23 |
| Druid | long_road: **320** laps, or 26 | 23 | 25 | 26 |
| Engineer | tinker_bench: **125** face edits, or 30 | 27 | 27 | 30 |
| Necromancer | grave_calling: Bone Warden ×2, or 1,000 kills, or 36 | ≤ 32 | 30 | 32 |
| Monster Kid (secret) | trick_or_treat: **36** Hollow events while owning 6 classes, or 40 | 20–25, ≤ 26 | 25 | 30 |

Pets arrive at:
- Pumpkin Sprite 1
- Skull Buddy 6
- Crystal Wisp 14
- Frost Mote, Lantern Ghost and Coin Mimic 18
- Guard Die 19
- Wick 21
- Grimoire 24
- Pebble 26
- Tinker 28
- Bubbles 30

The new pets' milestones are Frost Mote "visit Frostpeak 6 times", Wick "500 Three of a Kinds",
Grimoire "3,300 rune triggers", Pebble "3,600 Block", Tinker "2,600 rerolls" and Bubbles "drink
95 potions".

Pass criteria:
- Every class is within ±2 runs of its target: Paladin and Ninja are +2, Druid +2, and the rest
  closer.
- Every class arrives by a median of run ≤ 30, and all 20 profiles own every class by run 40.
- **No run unlocks 2 classes (0 of 800).**
- 35 of 800 runs unlock two majors (class, pet or biome). All of these involve a biome, which
  arrives bundled with a win.

### Meta numbers (all deterministic; `core/content/*.gd`)

- **Crowns per run:** unchanged from the previous pass: about 78 per run in the realistic
  campaign.
- **Crowns sink ≈ 8,330.** It was 5,930; the 6 new pets add levels 6–10.
- **Skins:**
  - Four per class plus an A10 prestige variant (`SkinDefs`). Victor = first win, Ascendant = an
    A3+ win, Bossbane = all 4 final bosses or an A6+ win, Prestige = an A10 win.
  - After every Crowns sink is maxed, any non-prestige skin costs 250 Crowns. Prestige skins can
    never be bought.
  - The Profile is version 2; v1 files load, and wins recorded before v2 still earn Victor.
- **Sigils:** as before, plus the per-id class prices and the next-two rule above.
- **Unchanged:** potions, minigames, gear and ascension. The ascension ladder table of the
  previous pass still describes the rules. A4 now gives the mini-boss one biome affix instead of
  a fixed trait.

### Tools and sweep notes

- The parallel runners used for this pass sharded the sim by seed:
  - class rows: `--class=<id> --runs=30 --seed=1+k·30·7919`
  - campaigns: one process per profile, `--campaigns=1 --seed=1+k·104729`
- **HP is the strongest single lever.** +4 HP moved the Knight and Mage by 7–12 pp at mid.
  Mechanic numbers like Aim moved rows by only 1–3 pp.
- Pre-existing, not changed:
  - `Bot.danger_lo/hi` (0.8 / 1.2).
  - The upgrades-per-run table of the previous pass (Knight-only fresh profile).

### API for presentation (classes, enemies, affixes, skins, pets; 2026-09-29)

All additions; no contract name was renamed. Everything below is in `core/`.

**Classes (`HeroDefs.DATA[id]`).** New fields on every class: `kinds` and `tags` (one entry per
starting die, parallel to `runes`), `combat_rerolls`, `mechanic` (a `ClassLogic` id, "" for the
old four), `style` (`melee_1h | melee_2h | ranged | magic | dual | unarmed`) and `secret` (the
Monster Kid). The Engineer also has `turret_rune`. `HeroDefs.IDS` is the unlock order: knight,
barbarian, paladin, mage, ranger, rogue, ninja, druid, engineer, necromancer, monster_kid.
`HeroDefs.MECHANIC_NAMES[mechanic]` names the class badge. Models: `model` = paladin, ranger,
ninja, druid, engineer, necromancer, monster_kid.

**Class events.**
- `class_triggered {id, class, value, ...}` pulses the class badge. Ids:
  - Paladin: `oath` (value = the Oath), `oath_kept` {oath, mult}, `sanctify` {die_idx, face_idx}
  - Ranger: `aim` (value = ×100), `piercing_shot` {from, enemy_idx}
  - Ninja: `shadow_step` {rerolls_left, refunds_left | board: true}
  - Druid: `overgrowth`, `seed` {die_idx}, `wild_bond`
  - Necromancer: `bone_harvest` {reason: kill | lone | phase}, `bone_crumble`
  - Monster Kid: `boo` {enemy_idx}
- `face_changed.source`: "growth" (Druid) and "sanctify" (Paladin).
- `die_tagged {die_idx, tag, tags}` (Druid seed).
- `die_added {die_idx, kind: "bone", temporary: true, tag: "bone", die}` when a Bone die joins at
  a turn start, and `die_removed {die_idx, temporary: true, tag}` when it crumbles.
- `turret_fired {value, damage, rune, target}`. Turret runes also emit `rune_fired` with
  `die_idx: -2, turret: true`, and `rune_assigned` carries `turret`.
- `enemy_scared {enemy_idx, effect: cower | flee | weaken}`, `enemy_fled {enemy_idx, gold, id}`,
  and `status {status: "cower", skipped: true}` when a scared enemy skips its action.
- `board_rolled` / `dice_rolled` (board): `pretend: [die indices whose ★ face showed]`. Board
  values are already resolved.

**Class state.**
- `Die.tags` (PackedStringArray; `has_tag`, `add_tag`). `Die.PRETEND` = 10 is the ★ face value
  (kind `pretend`, faces 1 2 3 4 5 ★; draw it as a ★, never as a numeral). Kind `bone`
  (1 2 2 3 3 4).
- `RunState.turret: Die` (null unless Engineer). It is addressed as die index
  `GameFlow.TURRET` (-2) in `rune_assign`, `shop_buy` (runes and Face Raise) and
  `forge_apply`. Allowed turret runes: `ClassLogic.TURRET_RUNES` (guard, heavy, ember, frost,
  gilded).
- `CombatState`: `oath`, `rerolls_used_this_turn`, `refunds_this_turn`, `extra_dice`
  (temporary dice; the combat pool is `pool_dice(run)` = `run.dice + extra_dice`, and
  `dice_values`, `marked`, `locked` and `rerolled` span it; `die_at(run, i)`),
  `pending_bones`, `bones_raised`, `attack_target`, `pet_thorns`, `pet_block_turn`,
  `last_runes`. All serialised. `GameFlow.board_refunds`.
- `ClassLogic.pool_oath(dice)` gives the "→ Oath" hint for the Forge.
  `ClassLogic.pretend_board_value(values, idx)` shows what a ★ copies on the board.
- `RunState.skin` and `RunState.skin_prestige` (for Continue).

**Enemies.**
- New ids:
  - regulars: `bone_cutthroat`, `orc_raider`, `orc_drummer`, `werewolf`
  - elites: `bone_golem` (Crypt), `fallen_paladin` (Hollow)
  - mini-bosses: `mini_moonfang` (Hollow), `mini_orc_warchief` (Frost)
- New traits: `frenzy` and `ward_allies`. New intent: `rally`.
- Enemy dicts gain `frenzy` (attack gained), `form` ("man" / "wolf" for transformers),
  `affixes`, `thorns_value`, `actions`, `chilled`, `brave`, `cower`, `weakened` and `fled`.
- Events:
  - `enemy_transformed {enemy_idx, form, id}` (followed by the new `enemy_intent`)
  - `status {status: "frenzy", value, max}`
  - `status {status: "buff", rally: true, source}` for each rallied enemy
- `EnemyDefs.pattern(id, phase)`, `transforms(id)` and `form(id, phase)`.

**Affixes.**
- `AffixDefs.IDS` (armored, thorned, warded, piercing, frenzied, regenerating, vampiric,
  hexing, frostbound, gilded); `AffixDefs.card(id)` gives {id, name, desc}; `AffixDefs.BIOME`.
- Board tiles carry `enemy_affixes` (one array per enemy, only when any are present).
  `Board.affixes_of(idx)` always returns the parallel list. Every board change dict with
  enemies has `affixes` (generation, `board_mutated`, events). `combat_started.enemies[i].affixes`.
- Procs emit `affix_triggered {enemy_idx, affix, value}`: thorned reflect, regenerating heal,
  hexing curse, frostbound chill, frenzied stack, gilded pet charge. A Warded hit shows
  `damage.warded: true`.
- Run stats: `seen_enemies`, `seen_affixes`, `affixed_kills`, `kills`. Profile
  `records.seen {enemies, affixes}` feeds the Bestiary and first-encounter popups.
- Feature unlock `affixes` (the `brawler` milestone): show the one-time popup on
  `unlocked {kind: "features", id: "affixes"}`.

**Pets 7–12.**
- Ids: `pebble_golem`, `frost_mote`, `wick`, `tinker_gear`, `grimoire`, `cauldron`.
  `PetDefs.card()` has `model` hints: pebble, frost, candle, gear, book, cauldron.
- `pet_acted` effects:
  - Pebble `block`, plus a second `pet_acted` `thorns` {value} (again with target = attacker
    when thorns hit)
  - Frost Mote `freeze` {target, value}
  - Wick `burn` {target: "all", value}
  - Tinker `fix` {die_idx, face}; a `dice_rolled {source: "pet"}` follows with the fixed values
  - Grimoire `rune` {rune, die_idx, value}
  - Bubbles `potion` {potion} (after a won fight)

**Meta.**
- Unlock and Sigil rules:
  - `UnlockDefs.buyable_classes(owned)` gives the next-two rule; `SIGIL_PRICE_BY_ID`.
  - `sigil_cost(kind, id, owned_classes)` returns {} for a class outside the next two and for
    secret classes.
  - Milestones may be `hidden` with a `hint` (`trick_or_treat`).
  - Only one class unlocks from milestones per banked run.
- Profile v2 (`Profile.VERSION = 2`; v1 files load and are migrated):
  - `cosmetics {owned, equipped, prestige, unseen}`
  - new records `best_asc_by_class`, `bosses_by_class`, `bosses_reached_by_class`, `boss_kills`,
    `seen`
  - new counters `face_edits`, `kills`, `hollow_events`, `freezes`, `sets3`, `rune_triggers`,
    `potions`; derived counters `classes_at_boss` and `classes_owned`
  - helpers `owns_skin`, `equipped_skin`, `prestige_on`, `crowns_capped`
- `SkinDefs.of(class)`: {id, name, texture, mesh, helmet, overlay, cond, prestige, buyable} for
  slots default, victor, ascendant, bossbane and prestige. Also `SkinDefs.cond_text(class,
  skin)` and `BUY_PRICE` (250).
- Camp commands:
  - `equip_skin(class, skin)`
  - `buy_skin(class, skin)` (only when `crowns_capped()`; never the prestige skin)
  - `set_prestige(class, on)`
  - `mark_skins_seen(class = "")`
- Camp events: `skin_unlocked {class, skin, source: record | crowns}`, `skin_equipped`,
  `prestige_set`, `skins_seen`. `run_banked` and `apply_run_result()` carry
  `skins_unlocked: [[class, skin]]`. `catalog()` lists `buy_skin` entries after the caps.

## Previous pass (2026-09-28 meta rules + rebalance; superseded where the current section differs)

Kept for its rule changes, the upgrades-per-run table, the mechanic nerfs and the ascension
ladder, which still hold. Its win-rate tables were Knight-only (fresh) or four classes.

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

Minigame rewards are real but show as 0 here: the sims' average-player result is usually
silver (see "Minigame calibration"), and the bots take the potion or the gold. A played gold tier offers a rune, a die, a passive or +1 reroll (all counted).
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
  bronze, 0.8 to 1.2 is silver, and 1.2+ is gold. Gold rewards scale by the skill band (±15%,
  luck games less). **Players play every minigame (user decision 2026-09-29):** the in-game
  AUTO pauses on a minigame tile ("Your turn: play the minigame") and resumes when switched
  back on; the screen has no AUTO button. The sims and headless bots use `minigame_auto` as a
  stand-in for an average player: it draws the tier from the game's calibrated split
  (`MinigameDefs.CALIBRATION[id].tiers`) with the minigame's own Rng (the run Rng is untouched)
  at a typical ratio per tier (bronze 0.65, silver 1.0, gold 1.35). The run is saved when a
  minigame starts (`minigame_started.save_point`).

### Minigame calibration (all 11 games, 2026-09-29 balance pass)

Rules in `core/minigames/<id>.gd` (deterministic from the minigame Rng + inputs, public state
only, save/load mid-game). Every number below comes from `tools/mg_calibrate.gd`: the
human-like `MgHuman` player (its own noise Rng; `--policy=expert|random` for the bounds), 2,000
games per game, stored in `MinigameDefs.CALIBRATION` and checked by
`test_minigames2.gd::test_parity_bounds_from_the_stored_calibration` and a live sample test.
EV = the expected prize in gold equivalents (bronze 12, silver 25, gold 45 x skill band); the
mean over the 11 games is 28.6 and every game is within ±6% of it (target ±10%). No game gives
gold to more than 36% or bronze to more than 35% of players (limits 40% / 45%). Seconds = play
time at 1x, actions x a per-game think + animation estimate (intro and results beat not
counted).

| game | actions | est. seconds | MEDIAN (human median) | tier split b/s/g | reward EV | skill band | expert / random median |
|---|---|---|---|---|---|---|---|
| Fossil Hunter | 10 digs | 20 | 8 (8) | 33/36/32 | 27.8 (-3%) | ±5% | - |
| Bubble Breaker | 3 taps (2.9) | 13 * | 17 (17) | 33/36/31 | 28.9 (+1%) | ±15% | 19 / 14 |
| Scratch-off | 3 scratches | 9 * | 13 (13) | 25/47/28 | 29.1 (+2%) | ±15% | luck |
| Claw Machine | 3 grabs | 18 | 16 (16) | 34/34/32 | 29.1 (+2%) | ±15% | - |
| Bubble Shooter | 10 shots (9.6) | 25 | 43 (43) | 34/35/31 | 29.0 (+1%) | ±15% | 55 / 10 |
| Plinko | 3 drops | 15 | 16 (15) | 33/36/30 | 27.4 (-4%) | ±5% | 17 / 11 |
| Shell Game | 3 picks | 20 | 11 (11) | 31/34/35 | 30.2 (+5%) | ±15% | 18 / 3 |
| Memory Match | ~21 flips | 27 | 9 (8) | 34/30/35 | 30.0 (+5%) | ±15% | 18 / 0 |
| Fishing | 3 casts (6 actions) | 18 | 11 (10) | 35/39/27 | 27.0 (-6%) | ±10% | 16 / 0 |
| Lucky Wheel | 3 spins (6 actions) | 20 | 20 (20) | 22/50/28 | 28.3 (-1%) | ±5% | 25 / 15 |
| High-Low Ladder | ~4 guesses | 10 * | 6 (5) | 21/55/24 | 28.0 (-2%) | ±10% | 5 / 2 |

\* Short by design (`MinigameDefs.SHORT_BY_DESIGN`): Scratch-off is the breather, Bubble
Breaker has 3 taps (user feedback), High-Low ends when the player cashes out.

**Changes in the 2026-09-29 pass:**
- **Bubble Breaker:** 5 taps -> **3** (user feedback: fewer lives). Big clusters and chains
  matter more: the big-cluster bonus starts at 5 (was 6: +1 per bubble from the 5th) and each
  chained big pop (4+ right after another) adds +2 (was +1). MEDIAN 17 for a human who takes
  the biggest group about half the time (the old 17/5-tap number was a perfect bot's).
- **Scratch-off:** the flat prizes (7 / 10 / 13 / 15) gave 31/66/4 and EV -25%. Now the score
  is the pips scratched + 4 for a pair + 10 for three alike (three 6s = 28, the jackpot):
  MEDIAN 13, 25/47/28.
- **Claw Machine:** 2 grabs -> **3** (18 s) and flatter capsule prizes (common 3/3/4, rare
  4/5, epic 6, legendary chest 8; was 2/2/3, 3/4, 6, 10), because the two-grab pile gave
  39/15/47 (gold-heavy, EV +11%). MEDIAN 16 (a human-ish aimer, sigma 0.045).
- **Lucky Wheel:** 2 spins -> **3** (20 s), MEDIAN 20.
- **MEDIAN notes:** Memory Match's, High-Low's and Fishing's scores are lumpy (even pair
  scores, ladder rungs), so their MEDIAN sits between the two central outcomes (memory 8|10 ->
  9; high-low's rungs map bust -> bronze, rungs 1-3 -> silver, 4+ -> gold).

**Rules and signatures of the seven new games (WP-E5, spec §16 "More minigames"):**

| game | rules (one thumb) | gold signature |
|---|---|---|
| Bubble Shooter | hex cluster 8 wide, 4 colours, 10 shots aimed with a quantised angle (121 steps, walls bounce); pop 3+ = 1/bubble, dropped = 2/bubble, clear +10 | Sharpshooter: +1 ATK (shrine value) |
| Plinko | 8 peg rows, 9 shuffled buckets (1,1,2,2,3,3,5,6,10), pick a slot, 3 drops; golden peg x2 | Rare rune for a die |
| Shell Game | 3 cups, 3 rounds: 5/8/11 swaps at 0.46/0.34/0.25 s; right pick 2/3/4, x2 within 1.2 s of the shuffle (Sharp Eye) | Heart Gem: +10 max HP (shrine value) |
| Memory Match | 4x4, 8 pairs (faces 1-6, Star, Skull), 6 misses; 2 per pair, +1 per miss left on a clear | Mirror Forge: 2 edits, raise or mirror |
| Fishing | 3 casts at shallows / reeds / deep; strike in the bite window (0.8/0.62/0.48 s), fake nibbles before; fish 1-10, perfect strike +1 | The Catch: Healing Draught + another potion |
| Lucky Wheel | 12 shuffled segments (2,2,3,3,4,4,5,5,6,7,9,12), 3 spins, one brake tap in the last 1.1 s | Uncommon passive (1 of 3) |
| High-Low Ladder | d6 higher/lower, ladder 2,5,6,7,9,11,14,18,24, safety rungs 0/1/3/5, push on equal, cash out any time | High Roller: every die's lowest face +1 |

The human models (`core/minigames/mg_human.gd`): fossil follows the bones like the bot; bubble
breaker takes the biggest group 55% of the time, else one of the three biggest; scratch is pure
luck; the claw aims at the best capsule with sigma 0.045; shooter best-looking shot 65% else a
decent one, aim noise sd 2 steps; plinko best-odds slot 50%, above the top bucket 30%, random
20%; shell loses track per gem-moving swap 2.5/6/11% and taps at once 70% when sure; memory
forgets a seen card with 0.97 x 0.9^turns; fishing deep 45% / reeds 35% / shallows 20%, fooled
by a nibble 12%, reaction 0.34 ± 0.09 s; wheel brakes on the best window segment 65% (± 0.09
s); high-low cashes at a personal nerve (rung 4-7, or 2-4 when the die shows 3 or 4).
Fossil Hunter: 7x7 site, three fossils (4, 3, 2 long) plus a gem (3 pts) and two coin pouches
(2 pts), 10 digs, no hints (a dig reveals only its own cell). Claw Machine: 18 capsules (10
common, 5 rare, 2 epic, 1 legendary, deeper by tier), the tier colour public and the prize
hidden until won; a drop scoops up to 3 capsules whose reach (0.075 x (1 - 0.8 x depth))
contains it; each slips with 0.14 per extra capsule held + 0.22 x depth.

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

### New biomes (2026-09-29: Deep Mines, Orc Warcamp, Sunscorched Ruins, Moonlit Woods)

*Superseded where the combined section at the top differs. This pass never saw the 11 classes.
The merge retuned the Cinder King, Moon King, Warcamp, Mines ore, Short Road finales and Sigil
prices listed there.*

Design: docs/design/2026-09-29-new-biomes.md. Tiers are now 3/3/4 (glade, crypt, mines ·
hollow, frost, warcamp · throne, magma, ruins, moonlit): 36 standard routes, 6 final bosses, and
a Short Road whose second biome is drawn from tier 2 ∪ tier 3 (21 routes). All numbers below are
the realistic bot, 28-tile board, A0, measured with `tools/sim.gd` shards (seed per shard; the
route sweep forces each route with `--route=` so every route plays the same seeds).

**Shipped numbers** (the design's starting values in brackets):

| thing | value |
|---|---|
| Deep Mines | ore 15 gold (× lap gold scale) or 1 Face Raise, then a cave-in trap; ore refills to 3 per lap unless 6 traps stand; mix `{ore: 3}` [`chest −1` dropped] |
| Rock Golem (Mines elite) | HP **24** [42], block 12 → attack **11** [13], thorns |
| Orc Warcamp | **+1** attack per standing drum [+2] (capped with Frenzy and Rally at +8); drum smash **14** gold [10]; a drum is rebuilt only once **every** drum is smashed [while fewer than 2 stand]; mix `{drum: 2}` [+1 enemy −1 event]; early pool orc_raider, wolf_bandit, bandit, skeleton_archer; late pool orc_raider, orc_drummer, wolf_bandit, skeleton_warrior |
| Orc Warchief | rally **2** [3] |
| Sunscorched Ruins | heat **8%** [5%] at each lap end unless you landed on an oasis that lap, never lethal; oasis heal **5%** [8%]; early pool bone_cutthroat, skeleton_warrior, bone_knight, cultist; late pool bone_cutthroat, bone_golem, bone_knight, brute |
| Moonlit Woods | as designed: Half moon transforms at ≤65%, Full lap (13; Short Road 8) pre-transformed, +1 elite, moon rune chest, fight gold ×1.5 |
| The Hollow (old biome) | event heal **3%** [8%]; early pool skeleton_archer → werewolf |
| Short Road finale HP | tier-3 second biome **×0.65** [0.75]; Moonlit ×0.72; Hollow ×0.88, Frost ×0.85, Warcamp ×0.68 (`short_boss_hp`) |

**Final bosses.** Before this pass the old four ranged from 42% (Bone Warden) to 84% (Cinder
King) boss-win at max, so the route spread was about ±15 pp before any new content. Every boss
was retuned toward the Lich (unchanged, so the fresh route keeps its numbers):

| boss | HP (was) | other changes | boss-win% (max, 36-route sweep) |
|---|---|---|---|
| The Lich | 1650 | – | 73.3 |
| Bone Warden | **1000** (1150) | phase 2 summons 1 warrior (was 2) | 70.6 |
| Cinder King | **1560** (1200) | – | 71.0 |
| Magma Golem | **960** (800) | – | 70.0 |
| Sand Colossus (new) | **1180** [1250] | bury 2 (curse + 10 Block per die), pierce in phase 2 | 72.6 |
| The Moon King (new) | **900** [1300] | Moonfall **34** [40]; phase 2 drain 16 / attack 22 / attack 18 [18/24/20]; meter 0→4, clouds cap 2 | 69.7 |

Mean 71.2; every boss within ±2.1 pp (target ±5). The Moon King's meter makes it much deadlier
per HP point than its stat line: at 1300 HP it won 30–39%.

**Standard routes, max profile** (600 runs per route, 21,600 runs; overall **60.6%**, baseline
main before this work 60.6%). Win% (delta vs the 60.6 route mean):

| tier 1 / tier 2 | throne | magma | ruins | moonlit |
|---|---|---|---|---|
| glade / hollow | 61.5 (+0.9) | 64.2 (+3.6) | 63.5 (+2.9) | 68.3 (+7.7) |
| glade / frost | 61.7 (+1.1) | 60.8 (+0.2) | 65.7 (+5.1) | 66.3 (+5.7) |
| glade / warcamp | 60.2 (−0.4) | 60.2 (−0.4) | 59.8 (−0.8) | 58.3 (−2.3) |
| crypt / hollow | 63.5 (+2.9) | 61.2 (+0.6) | 65.0 (+4.4) | 66.0 (+5.4) |
| crypt / frost | 57.7 (−2.9) | 60.2 (−0.4) | 58.3 (−2.3) | 59.3 (−1.3) |
| crypt / warcamp | 55.0 (−5.6) | 57.5 (−3.1) | 56.8 (−3.8) | 60.5 (−0.1) |
| mines / hollow | 59.5 (−1.1) | 61.5 (+0.9) | 59.3 (−1.3) | 64.5 (+3.9) |
| mines / frost | 59.5 (−1.1) | 62.5 (+1.9) | 60.0 (−0.6) | 60.3 (−0.3) |
| mines / warcamp | 52.8 (−7.8) | 56.8 (−3.8) | 57.7 (−2.9) | 55.2 (−5.4) |

23 of 36 routes are within ±3 pp (range −7.8 to +7.7; before the pass −23 to +25). At 600 runs a
route's standard error is about 2 pp, so about 5 routes land outside ±3 pp by noise alone; the
rest is the additive tier-1 + tier-2 spread (Warcamp and Hollow). Biome marginals (routes
containing the biome) vs their tier mean:

| tier | biome | win% | Δ tier | reached boss% | boss-win% |
|---|---|---|---|---|---|
| 1 | glade | 62.5 | +2.0 | 86.8 | 72.0 |
| 1 | crypt | 60.1 | −0.5 | 84.8 | 70.8 |
| 1 | mines | 59.1 | −1.4 | 82.9 | 71.3 |
| 2 | hollow | 63.2 | +2.6 | 86.5 | 73.0 |
| 2 | frost | 61.0 | +0.4 | 86.1 | 70.9 |
| 2 | warcamp | 57.6 | −3.0 | 82.0 | 70.2 |
| 3 | throne | 59.0 | −1.6 | 79.7 | 74.1 |
| 3 | magma | 60.5 | −0.1 | 85.8 | 70.5 |
| 3 | ruins | 60.7 | +0.1 | 86.8 | 69.9 |
| 3 | moonlit | 62.1 | +1.5 | 87.1 | 71.3 |

**Twists alone** (`--twist=off`, same seeds, 800 runs each, max): Mines −1.8 pp (the ore choice vs
no ore tiles), Warcamp −3.0, Ruins −0.9, Moonlit +0.7. All within ±4 pp.

**Short Road** (21 routes × 600 runs, max, overall **59.3%**; before: 58.8% on the 4 old routes):

| tier 1 | hollow | frost | warcamp | throne | magma | ruins | moonlit |
|---|---|---|---|---|---|---|---|
| glade | 63.3 (+4.0) | 62.5 (+3.2) | 65.5 (+6.2) | 60.2 (+0.8) | 63.0 (+3.7) | 59.5 (+0.2) | 57.2 (−2.2) |
| crypt | 58.5 (−0.8) | 58.8 (−0.5) | 60.0 (+0.7) | 57.8 (−1.5) | 55.5 (−3.8) | 57.2 (−2.2) | 56.8 (−2.5) |
| mines | 60.2 (+0.8) | 59.5 (+0.2) | 60.0 (+0.7) | 57.0 (−2.3) | 57.8 (−1.5) | 60.8 (+1.5) | 55.0 (−4.3) |

15 of 21 within ±3 pp; tier-2 finales average 60.9% vs tier-3 finales 58.2% (2.7 pp apart, target
≤ 3). The Short Road now also spawns its mini-boss at lap 6 (it never did: lap 6 is a biome change,
which skipped the mutation that places it).

**Profile bands** (standard mode): fresh **39.4%** (800; target 30–40; the fresh route is
unchanged), max **60.6%** (55–65), max A10 **21.2%** (480; 20–30), mid **40.2%** (810; target
45–50, **out of band**). Mid was already 44.4% on main before this work (other in-flight changes);
the rest comes from the Cinder King and Magma Golem, the soft bosses mid used to lean on (mid owns
only the Lich, the Cinder King and the Magma Golem). Fixing mid needs either a stronger mid preset
or a mid-specific lever; lowering every boss would push max above 65%.

**Deaths by lap** (max, standard): L3 0.7×, L5 1.9×, L6 0.04×, L13 1.4×, L14 2.8×, L15 4.2× the
per-lap average. The late spike is structural and older than this work (main before it: L14 3.7×,
L15 4.7×). The two laps the design flagged are fine: Moonlit's Full lap (13) has fewer deaths than
the Throne's lap 13 (58 vs 160 per 5,400 runs), and Warcamp lap 6 has 8 deaths in 7,200 runs.

**Campaign** (`--campaign=40 --campaigns=8`, realistic): Mines median run 9 (target 8), Warcamp 11
(12), Moonlit 17 (17), Ruins 22 (21), all within ±2 runs. With the current class table (Mage 14,
Rogue 15) no median run unlocks two majors. Milestones: `prospector` = 20 Treasury cash-outs or 12
runs (17 cash-outs landed on run 8, the same run as Frostpeak), `warpath` = 380 kills or 16 runs,
`night_walker` = 16 act-3 runs or 22 runs, `sun_seeker` = **4** different final bosses or **22**
runs (3 bosses came by run 11: a first win unlocks the Cinder King and Magma Golem at run 1).

**Sim dials added:** `--twist=off[:<biome>,...]`, `--route=<t1>,<second>` with `--mode=short`,
`--enemy-hp=<id>:<mult>`, `--moon=max:N,tide:N,clouds:N,fall:N`, `--bnum=<BiomeDefs number>:<v>`
(ORE_GOLD, MINES_TRAP_CAP, DRUM_RALLY, DRUM_GOLD, WARCAMP_DRUMS, HEAT_PCT, OASIS_HEAL_PCT). The sim
prints per-biome (`#biome`), per-boss (`#boss`) and death-lap (`#dlap`) lines for shard sums.

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

> Since 2026-09-29 the tiers are 3/3/4 with four new biomes, 36 routes and 6 final bosses; see
> "New biomes" under Current balance for the new biomes, the retuned bosses and the Short Road.
> The tables below describe the six original biomes.

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
