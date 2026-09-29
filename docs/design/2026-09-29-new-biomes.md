# Diceroll: four new biomes

Date: 2026-09-29 · Status: **decisions resolved (§11)**; the user approved the four boards. Numbers are starting
values for the sim.
Reads with: `core/content/biomes.gd`, docs/plans/balance.md ("Biomes and routes", "Current
balance") and docs/design/2026-09-28-classes-enemies-skins.md, which has the new enemy ids,
affixes (§3A), the class unlock table (§2) and the Monster Kid.

---

## 0. Summary

**The four biomes:**

| id | name | tier | twist (short) | new tile | elite leader | mini-boss / final-boss candidates |
|---|---|---|---|---|---|---|
| `mines` | Deep Mines | **1** | Ore veins pay 15 gold or a Face Raise, then cave in and become traps | `ore` | **`rock_golem`** (new) | (tier 1: none used) |
| `warcamp` | Orc Warcamp | **2** | Each standing war drum Rallies every enemy +2 attack at fight start; landing smashes a drum | `drum` | brute (as an orc) | mini_orc_warchief, mini_cinder_brute |
| `ruins` | Sunscorched Ruins | **3** | Heat costs 5% max HP at each lap end unless you **landed** on an oasis that lap; oases heal 8% | `oasis` | bone_golem | **`boss_sand_colossus`** (new), boss_bone_warden |
| `moonlit` | Moonlit Woods | **3** | Moon phases over laps 11–15. On the Full lap (13), werewolves start transformed, elites double, fights pay ×1.5 gold, and a moon rune chest appears | – | werewolf | **`boss_moon_king`** (new), boss_lich |

**Tiers and routes:**
- Tier 1 has 3 biomes (glade, crypt, mines), tier 2 has 3 (hollow, frost, warcamp) and tier 3
  has 4 (throne, magma, ruins, moonlit).
- Standard routes go from **8 to 36** (3×3×4).
- The **Short Road** second biome is drawn from tier 2 ∪ tier 3 (7 biomes), so it has **21**
  routes (was 4).
- Standard combinations (route × mini-boss × final boss) go from 32 to **168** (§6).

**Two new final bosses:**
- **Sand Colossus** (Ruins): buries your dice.
- **The Moon King** (Moonlit): a moon meter that your **1s** push back. A full moon forces its
  transformation (Moonrise), then drops a piercing **Moonfall**.
- There are 6 final bosses in total, and each tier-3 biome has 2 candidates. Each existing
  Throne boss now appears in exactly 2 biomes: the Lich in Throne and Moonlit, the Bone Warden
  in Throne and Ruins.

**Moonfang** becomes a **Hollow mini-boss candidate**. This is the one exception to "home
biomes only" (§4.4). It is unlocked by the Moonlit milestone and also appears as Moonlit's
Short Road mini-boss.

**New content:**
- **3 new ids:** `rock_golem`, `boss_sand_colossus`, `boss_moon_king`.
- **2 new intents:** `bury`, `moonfall`.
- **3 new tile types:** `ore`, `drum`, `oasis`.
- Everything else reuses existing mechanics.

**Unlocks:** each biome has a milestone, plus a fallback of "or play N runs". Targets are runs
**8 / 12 / 17 / 21**, placed between the class unlocks under the one-major-unlock-per-run rule.

**Elevation** is a later, **cosmetic** pass (see the Elevation section).

---

## 1. Shared core additions

1. **`BiomeDefs.TIERS`** = `[["glade", "crypt", "mines"], ["hollow", "frost", "warcamp"],
   ["throne", "magma", "ruins", "moonlit"]]`.
   - `pick_route` and `all_routes` already work on any tier size.
   - The meta route pick already filters by unlocked biomes.
   - `valid_route` is unchanged.
   - The Rng draw count per tier is still one pick, so seeds stay comparable when the tiers are
     forced.
2. **New `BiomeDefs` fields:**
   - `twist` (the id handled in `GameFlow`: `"ore"`, `"drums"`, `"moon"`, `"heat"`)
   - `refill: {tile: n}`: at each lap mutation, Empty tiles are converted back up to n of that
     type, like the event top-up today
   - `look` (the presentation key).
3. **Tile registry:** `Board` tile types gain `ore`, `drum` and `oasis`.
   - `layout_for` already applies mix deltas, and Empty absorbs the difference.
   - Tiles 1–2 are never fights, and never drum or ore either.
   - Corners are never new tiles.
4. **Events:**
   - `ore_mined {idx, choice: "gold"|"raise", gold}`, then `tile_changed {idx, type: "trap",
     source: "cave_in"}`
   - `drum_smashed {idx, gold}`
   - `rally {source: "drum", value, drums}` at fight start
   - `moon_phase {phase, lap}` on `lap_completed` and `act_started`
   - `heat {damage, cooled}` on lap completion
   - `oasis {idx, healed}`
   - `act_started` gains `twist`.
   - All of these are serialised where they carry state: `RunState.cooled_lap` and the board tile
     types.
5. **Sim flags:** `--route=` accepts the new ids. `--twist=off` disables a biome's twist, which
   gives a per-twist pp measurement.

---

## 2. Deep Mines (`mines`, tier 1)

*"Veins of gold run through the dark. Every swing of the pick shakes the ceiling."*

| field | value |
|---|---|
| Name / desc | **Deep Mines**: "Ore veins pay out gold or a Face Raise, but each vein you mine caves in and becomes a trap." |
| Twist (`ore`) | **Landing on an `ore` tile** gives a choice: **15 gold** (× lap gold scale) **or 1 Face Raise** (the existing forge offer with `ops: ["raise"]`, `uses: 1`). The tile then **caves in**: it becomes a `trap` for the rest of the biome (roll 4+ to dodge, else 12% max HP, as today). **Lap mutation:** ore refills to **3** on Empty tiles, and traps are capped at **6** (no refill if that cap is reached). The Crypt's dodged-trap gold does **not** apply. |
| Tile mix (28) | `{"ore": 3, "chest": -1}` (Empty absorbs). Base traps are 2. Expect about 4–6 traps by lap 5. |
| Early pool (laps 1–3) | skeleton_minion ×2, skeleton_archer, bone_cutthroat |
| Late pool (laps 4–5) | skeleton_minion, bone_cutthroat, skeleton_warrior, orc_raider |
| Elite leader | **`rock_golem`** (new): HP 42, gold 14, xp 10, cycle **block 12 → attack 13**, trait **thorns**. A crystal-studded stone brute; hitting it hurts. Its gold is higher because it's the economy biome. |
| Affixes (§3A) | armored, piercing (+ **gilded at weight 3** here, instead of 1) |
| Mini-boss / boss candidates | tier 1: none used (`minibosses: ["mini_bone_champion"]` kept for future shuffles) |
| Look hint: skeleton_minion in the Mines | the existing look + `pickaxe` (Dungeon EXTRA) in the right hand; presentation only |
| Core hooks | `GameFlow` landing on `ore` → offer (a phase like FORGE) → `ore_mined` → `Board.set_type(idx, "trap")`. Mutation: `refill: {"ore": 3}` with a trap cap check. Bot: gold if the pool is at the cap and there is a shop next lap; otherwise take the Raise (same valuation as a Forge Raise). |

**Why tier 1:** an economy biome with more build growth early and more traps, a clear
risk/reward that teaches the Forge. Target: the Mines route delta should be within ±3 pp of the
tier-1 average. The Glade is currently the "easy" tier-1 biome, so if needed, tune ore gold 15 →
12 or the refill 3 → 2.

**Set piece and dressing (visual agent):**
- **Centre:** a mine-shaft mouth built from Dungeon EXTRA `scaffold_frame_large`,
  `scaffold_pillars_connected_torch` and `stairs_wood`, with `bucket_pickaxes` and a gem cart (a
  pile of `Gems_Pile_Large` + `Gold_Nuggets` on `Pallet_Wood`).
- **Island:** BlockBits `stone_dark`, `stone_with_gold`/`_silver`/`_copper` and `gravel` blocks,
  with rubble (`rubble_large`, `rocks_gold`).
- **Props:** RPGTools `lantern`, `pickaxe`, `shovel`, `rope_bundle`; ResourceBits
  `Stone_Chunks`, `Copper/Iron/Silver_Nuggets`, `Containers_Crate_*`.
- **Tiles:** ore tile = a glowing vein block (`stone_with_gold`) with a nugget pile. A cave-in
  trap = `rubble_half` + a dust puff when it converts.
- **Palette:** slate and charcoal, warm lantern amber, gem glints (teal, magenta).
- **Light:** low ambient, many small warm point lights, dark distance fog.
- **Particles:** dust motes, water drips, a pebble trickle on cave-ins.
- **Music:** muted plucked strings, a "ting" of picks on the off-beat, and a low drone.

---

## 3. Orc Warcamp (`warcamp`, tier 2)

*"Drums in the stockade. Every beat makes them braver. Smash the drums."*

| field | value |
|---|---|
| Name / desc | **Orc Warcamp**: "War drums rally every orc in earshot: enemies gain +2 attack per standing drum. Land on a drum to smash it." |
| Twist (`drums`) | There are **2 `drum` tiles**. At **every fight start** in the Warcamp, each living enemy is **Rallied +2 attack per standing drum** (unscaled; applied like the `rally` intent and shown as a buff badge). This covers regulars, elites and the mini-boss. **Landing on a drum** smashes it (no fight): it becomes Empty and you gain **10 gold** × gold scale. **Lap mutation:** if fewer than 2 drums stand, **one** is rebuilt on a random Empty tile, more than 3 tiles from the hero. The Warcamp therefore swings between 0 and 2 drums. |
| Tile mix (28) | `{"drum": 2, "enemy": 1, "event": -1}` |
| Early pool | orc_raider ×2, wolf_bandit (warg riders), bandit |
| Late pool | orc_raider, orc_drummer, brute, bandit |
| Elite leader | **brute** with the Warcamp look (war paint, horned helm, `Orc_Club`). No new id: the brute's green Mannequin_Large already reads as an orc. |
| Affixes | frenzied, thorned, piercing (+gilded) |
| Mini-boss candidates | **mini_orc_warchief** (home; its `rally 3` stacks on the drums, so smash the drums before lap 7), **mini_cinder_brute** (unused until now; reframed as the camp's forge-master) |
| Core hooks | `CombatState.begin`: count `run.board` drum tiles → `rally` event → add to every enemy's `atk_bonus`. Landing → `drum_smashed`. Mutation: rebuild rule. Bot: none needed (landing is automatic). Its board-reroll heuristic should value a drum landing like a Chest. |

Balance:
- 2 drums (+4 attack per enemy) is heavy at lap 6 (a regular hits for about 8–10). The expected
  standing-drum count is about 1.2, since you land on a drum about 25% of laps per drum.
- Tuning order: +2 → +1 per drum, then 2 drums → 1 drum + a stronger rally.
- The Orc Drummer's own `rally 2` stacks on top, which makes it a kill-priority target.
- Target: the Warcamp is within ±3 pp of the tier-2 average (hollow, frost).

**Set piece and dressing:**
- **Centre:** a giant war drum (`Orc_Wardrum` at 3×) on a log platform (`Wood_Log_Stack`,
  `Wood_Planks_Stack_Large`), with `Orc_WardrumStick` crossed.
- **Ring edge:** a palisade of vertical `Wood_Log` stakes (ResourceBits; the Werewolf pack's
  `log_A/B` for variety) with sharpened tops, and `banner_patternB_red`/`banner_triple_brown`
  (Dungeon EXTRA) on posts.
- **Clutter:** `Food_Barrel_*`, `Containers_Crate_*`, `Textiles_Stack` as tents' bedding,
  `sword_shield` racks, campfires, `Orc_Backpack` and `Orc_DrinkingHorn` lying around.
- **Drum tile:** a small drum on a tile-top plinth that pulses at fight start. When smashed it
  leaves broken staves.
- **Palette:** churned-mud brown, blood-red banners, bone white, torch orange, smoky dusk.
- **Light:** low late-afternoon sun through smoke, warm rim.
- **Particles:** smoke plumes, campfire sparks, dust. A camera micro-shake on the drum beat
  (Rally).
- **Music:** tribal percussion ostinato with low horns. Drum hits sync to the rally event.

---

## 4. Moonlit Woods (`moonlit`, tier 3)

*"The moon waxes as you walk the last road. When it's full, the woods stop pretending to be
quiet, and their king wakes."*

### 4.1 Biome

| field | value |
|---|---|
| Name / desc | **Moonlit Woods**: "The moon grows each lap. Under the full moon, werewolves are already changed, twice as many elites stalk the woods, fights pay 1.5× gold, and a moonlit rune chest appears." |
| Twist (`moon`) | **Phase = the lap's position in the biome:** 1 Crescent · 2 Half · **3 Full** · 4 Half · 5 Crescent. On the standard road that is **lap 11 Crescent, 12 Half, 13 Full, 14 Half, 15 Crescent**; the final boss follows lap 15. On the Short Road, the biome's laps 6–10 map the same way, so the Full lap is lap 8. **Half:** `transform` enemies change at **≤65% HP** instead of ≤50%. **Full:** see §4.2. **Crescent:** no effect. The HUD shows a moon icon with "Full moon in N laps". |
| Tile mix (28) | `{"event": 1, "trap": -1}` (fairy-ring events; no traps in the woods) |
| Early pool (laps 11–13) | werewolf, wolf_bandit, hollow_wisp, orc_raider |
| Late pool (laps 14–15) | werewolf ×2, brute, wolf_bandit |
| Elite leader | **werewolf** (elite; the "Silverback" texture B via skin_rules). This is now a tier-3 elite, with the lap-11+ scaling doing the work. |
| Affixes | vampiric, regenerating, frenzied, warded (+gilded) |
| Mini-boss candidates | `minibosses: ["mini_moonfang"]`. It is only drawn on the **Short Road** when Moonlit is the second biome (see §6.2); on the standard road the mini-boss always comes from tier 2. |
| Final-boss candidates | **`boss_moon_king`** (new, §4.3) and **`boss_lich`** (the night's sorcerer; it now appears in Throne and Moonlit) |
| Core hooks | `RunState.moon_phase()` is derived from lap and biome (no new state). `CombatState.begin`: if the enemy transforms and the phase is Full, start in phase 2 (emit `enemy_transformed {form: "wolf", source: "moon"}`). The transform threshold comes from the phase. `Board.mutate`: an extra elite and the moon chest when the next lap is Full. The gold mult is applied in `_win`. |

### 4.2 The Full lap (lap 13 standard, lap 8 Short Road)

At the **lap mutation into the Full lap** (on completing lap 12), in this order:
1. **Double elites:** the mutation spawns **+1 Elite** (2 in total).
2. **Moon rune chest:** the first Empty tile **3 to 8 tiles ahead** of the hero becomes a
   `chest` with `moon: true`. If there is none in range, use the nearest Empty tile anywhere
   ahead; if there are no Empty tiles, convert the nearest Event tile ahead.
   - Landing on it always offers a **1-of-3 rune choice** (never the gold roll), and **at least
     one of the three is Rare or Epic**. The draw uses the run Rng, restricted to the unlocked
     rune pool.
   - It is consumed on landing like any chest, and it persists until the biome ends.
   - Event `tile_changed {idx, type: "chest", moon: true, source: "full_moon"}`. The tile gets a
     silver moon glyph.
3. **Transformed:** werewolves (and Moonfang, if met on a Short Road) start their fights in wolf
   form.
4. **Payout:** fights on the Full lap pay **gold ×1.5**.

### 4.3 New final boss: `boss_moon_king`, "The Moon King"

| field | value |
|---|---|
| Model | Phase 1: **`Werewolf_Man` (texture B, grey/blue)** at **1.9×**, with a crown extra (reusing the `crown` procedural piece from the Cinder King), a dark cape tint and silver eyes. Phase 2: it swaps to **`Werewolf_Wolf` (texture B)** at 1.9× (the same transform presentation as the regular werewolf), with a red-silver rim light and a blood-moon sky tint. |
| HP | **1300** (Lich 1650, Colossus 1250, Cinder King 1200, Bone Warden 1150, Magma Golem 800) |
| Unique mechanic: **Moon meter** | The meter runs **0 → 4** and shows as a moon icon filling on the boss HUD. It gains **+1 at the end of every enemy phase** ("the tide"). **Clouds:** in your attack, each die showing **exactly 1** pushes it back **−1** (max −2 per turn, and not below 0). A Wild or ★ never counts as 1. Low/Odd dice and the Frost rune (which triggers on 1s) become counterplay. |
| Phase 1: "Lord of the Hunt" | attack 20 / block 24 / summon 1 (`wolf_bandit`, lap-scaled). **Moonrise:** if the meter reaches 4 in phase 1, it **immediately enters phase 2 regardless of HP** (its HP is unchanged), and the meter resets to 0. Otherwise phase 2 starts at ≤50% HP as usual. |
| Phase 2: "Blood Moon" | drain 18 / attack 24 / attack 20. The meter keeps rising. At 4 its next intent is replaced by **Moonfall: attack 40 with pierce**, and the meter resets to 0. |
| Why it's not a stat copy | The fight is a race between the tide and your dice: pushing the meter back with 1s delays the more dangerous wolf form and prevents Moonfall. It rewards a different build (low faces, Frost) from every other boss, which reward high damage (Lich), AoE (Warden), Cleanse (Cinder) or burst (Golem). |
| Ascension | **A9** (the final boss starts with its phase-2 traits and +5% HP): the Moon King has no traits, so instead **its meter starts at 2**. **A10** double final: the other candidate (the Lich) at 40% HP. |
| Core hooks | `CombatState.moon` (int, serialised; −1 = none). `_enemy_phase` end → +1 and `moon_meter {value, delta: +1, source: "tide"}`. `attack()` → count 1s → `moon_meter {delta, source: "clouds"}`. `boss_phase {forced: true, source: "moonrise"}` reuses the phase-switch code. New intent **`moonfall`** (attack N + pierce for that hit; icon: a falling moon). Summon id `wolf_bandit`. Short Road HP ×0.75 applies as for every boss. |
| Bot awareness | Keep 1s when the meter is ≥ 2 (their value = the Moonrise or Moonfall damage avoided). Don't reroll a 1 away in phase 2 when the meter is 3. Pour damage in when a Moonrise is imminent and the boss HP is just above 50%. |
| Target | boss-win% within **±5 pp** of the other five final bosses (`--boss=` table). Knobs: tide +1 per turn → +1 every other turn; Moonfall 40 → 34; clouds cap 2 → 3; HP 1300. |

### 4.4 Moonfang resolution

Moonfang (`mini_moonfang`, the werewolf mini-boss) can't be a lap-7 mini-boss from a tier-3 home.
I considered three options:

| option | verdict |
|---|---|
| A guaranteed elite on Moonlit's Full lap | Rejected. The Full lap already has double elites plus pre-transformed wolves; a 105-HP transformer on top would spike lap 13 deaths past the ≤1.5× per-lap cap. |
| A phase-2 summon of the Moon King | Rejected. A mini-boss-sized add in a final boss fight is a stat wall, and it dilutes the meter mechanic, which should be the fight's identity. |
| **A Hollow mini-boss candidate** (the one exception to "home biomes only") | **Chosen.** The Hollow is the Halloween biome, where a werewolf is canonical. Its lap-7 design (transform at half HP) is intact. The Hollow goes to 3 candidates (pumpkin_knight, grave_mage, moonfang), and it keeps the standard road's mini-boss variety up. Moonlit's `minibosses` list also names it, so on the **Short Road** (§6.2), a Moonlit second biome draws Moonfang as its mini-boss. It unlocks with the Moonlit milestone (`night_walker`), so meeting Moonfang foreshadows the woods. |

Cross-link: if the run's route has **Hollow + Moonlit** and you killed Moonfang, the Moon King's
meter **starts at −1**. It then needs 5 tides to rise, and the HUD says "Moonfang's fang dims the
moon". The effect is small (about 1 extra turn before the tide), deterministic and flavourful.
It can be cut if it complicates the sim.

### 4.5 Set piece and dressing

- **Centre:** a ring of tall standing stones (Forest `Rock_3_*` tall variants) around a huge
  gnarled `Tree_Bare` turned into a **throne of roots** (the Moon King's seat; empty until the
  final fight). Nearby: a woodcutter's stump with `axe` and `log_stacks` (Werewolf set).
- **Foliage:** Forest Nature trees and bushes in their **cool colour variants** (teal, blue,
  violet), plus grass tufts and `Rock_1_*` boulders.
- **Sky:** a big moon disc behind the island. Its fill and size animate by phase (crescent →
  full), and it turns blood-red in the Moon King's phase 2.
- **Palette:** deep indigo, silver-blue moonlight, teal foliage, warm firefly pinpoints.
- **Light:** a cool directional moon key, strong rim. Brightness rises by phase.
- **Particles:** fireflies, drifting leaves, low ground mist. A howl sting on Full and on
  Moonrise.
- **Music:** soft celesta and strings, distant howls, a swelling layer on the Full lap, and a
  boss theme with a heartbeat pulse that quickens as the meter fills.

---

## 5. Sunscorched Ruins (`ruins`, tier 3)

*"A buried empire of bone and sandstone. The sun takes its toll every lap; the oases give it
back."*

| field | value |
|---|---|
| Name / desc | **Sunscorched Ruins**: "The heat costs 5% of your max HP at the end of every lap unless you landed on an oasis during it. Oases heal 8%." |
| Twist (`heat`) | At **lap completion** in the Ruins (before the 10% lap heal), take **5% max HP** heat damage, unless `run.cooled_lap` is set. Like lava, it is **never lethal** (it stops at 1 HP). The A8 hazard ×1.5 applies. **Landing on an `oasis`** heals **8%** max HP and sets `cooled_lap` for the current lap. Oases persist and are never consumed. Because every lap passes every tile, only *landing* counts; the board Reroll is how you steer toward an oasis (the landing preview shows the target). |
| Tile mix (28) | `{"oasis": 3, "campfire": -1}` |
| Early pool | bone_cutthroat, skeleton_warrior, skeleton_archer, cultist |
| Late pool | bone_cutthroat, bone_golem, bone_knight, cultist |
| Elite leader | **bone_golem** (Ruins look: a sandstone tint) |
| Affixes | piercing, hexing, armored, frenzied (+gilded) |
| Final-boss candidates | **boss_sand_colossus** (new), **boss_bone_warden** (the tomb guardian and its bone legion; it also stays in the Throne). The Lich moved to Moonlit, so each existing Throne boss appears in exactly 2 biomes. |
| Core hooks | `GameFlow` lap completion → the heat check (before the heal, after `lap_completed`); `oasis` landing handler. Both reuse the lava damage path (`never lethal`, Phoenix and Second Wind don't trigger). |

**Heat maths:**
- P(landing on at least one of 3 oases in a lap) is about 35–40% without rerolls and about 50%
  with smart rerolls.
- The expected cost is about 3% per lap (about 15% over the biome) against the Magma Depths'
  lava, which costs about 12–18%.
- Target: the Ruins are within ±3 pp of the tier-3 average.
- Tuning: 5% → 4%, oasis heal 8% → 10%.

**New final boss: `boss_sand_colossus`, "Sand Colossus"**

| field | value |
|---|---|
| Model | Skeletons `Skeleton_Golem` (Rig_Large) at 1.8×, sandstone tint, with a buried-sarcophagus plinth. Phase 2 adds a swirling sand-storm aura. |
| HP | **1250** (Lich 1650, Moon King 1300, Cinder King 1200, Bone Warden 1150, Magma Golem 800) |
| Phase 1 | attack 20 / block 26 / summon 1 (`bone_cutthroat`, lap-scaled) |
| Phase 2 ("Sandstorm") | **bury 2** / attack 24 / attack 20; trait **pierce** |
| Unique mechanic | **Bury** (new intent): locks **N** of your dice for your next turn (as curse N) **and** gains **10 Block per die buried**. Burying dice limits your combos just as the Colossus raises its guard. Pierce in phase 2 punishes Block builds. |
| Core | `bury` = curse N + block (10·N), scaled like block. Intent icon: a die sinking into sand. |
| Target | its boss-win% within ±5 pp of the other five final bosses (the `--boss=` table) |

**Set piece and dressing:**
- **Centre:** a half-buried tomb gate: Dungeon EXTRA `wall_archedwindow_open`, `wall_broken`,
  `pillar_decorated` and `column` sunk at angles into BlockBits `sand`, and `stairs_wide`
  descending into darkness. A giant skull (Skeletons pack props or a scaled skull extra) over
  the arch.
- **Ring edge:** broken `pillar`/`column`, `rubble_large`, bleached `Tree_Bare` (Forest, dry
  Color variant), scattered Skeletons shields and weapons half in the sand.
- **Oasis tile:** a BlockBits `water` inset, a ring of `sand_with_grass`, one small green `Tree`
  and `Bush` (Forest, green Color) and a sparkle.
- **Palette:** bleached sand, terracotta, bone, turquoise oasis water, white-gold sun.
- **Light:** harsh high-noon key, short hard shadows, strong bloom, a heat-haze screen shader
  (subtle, off on the Mobile renderer if it's costly).
- **Particles:** drifting sand streams, dust devils, shimmer. When heat hits: a brief orange
  vignette.
- **Music:** sparse plucked strings and frame drums over wind, with a tense low pad.

---

## 6. Routes, tiers and Short Road

### 6.1 Tiers (standard road)

| tier | biomes | difficulty notes |
|---|---|---|
| 1 (laps 1–5) | glade (easy: heals), crypt (traps), **mines** (economy + traps) | all within ±3 pp of the tier mean |
| 2 (laps 6–10) | hollow (events), frost (ice locks), **warcamp** (rally) | mini-boss candidates: hollow 3 (pumpkin_knight, grave_mage, **moonfang**), frost 2 (frost_warden, bone_champion), warcamp 2 (orc_warchief, cinder_brute) |
| 3 (laps 11–15) | throne (elites), magma (lava), **ruins** (heat), **moonlit** (moon spike) | final bosses: throne [lich, bone_warden] · magma [cinder_king, magma_golem] · ruins [**sand_colossus**, bone_warden] · moonlit [**moon_king**, lich] |

Counts:
- Standard routes: **3 × 3 × 4 = 36**.
- Combinations (route × mini-boss × final boss): 3 (tier 1) × (3 + 2 + 2 mini-boss choices over
  the tier-2 biomes) × 4 (tier 3) × 2 (bosses per tier-3 biome) = **168** (was 32).
- Unique final bosses: **6**. Unique mini-bosses in standard runs: **7**.
- **Default new-profile route:** unchanged (Glade → Hollow → Throne).
- `firsts.route_win` Sigils: 36 possible route wins, still a one-time first each (1 Sigil). Watch
  the Sigil total in the campaign sim.

### 6.2 Short Road (10 laps, 2 biomes): the second biome comes from tier 2 ∪ tier 3

Today the Short Road route is [tier-1 biome, tier-3 biome], the mini-boss comes from the second
biome's `minibosses` list, and the boss comes from its `bosses` list. It uses the effective laps
`SHORT_EFF_LAPS` = [1, 2, 3, 4, 5, 7, 8, 9, 10, 11] (the second biome plays at standard-difficulty
laps 7–11), with the mini-boss at lap 6 and the boss at 75% HP.

**New rule:**
1. **Draws:**
   - `RunState.create` still draws the 3 standard tier picks (to keep the stream shape).
   - In short mode it then makes **one extra draw**: `second = rng.pick(unlocked(TIERS[1] +
     TIERS[2]))`, uniform over the 7 biomes (or the unlocked subset).
   - `route = [tier1_pick, second]`.
   - Short-mode seeds shift by one draw compared with today. Rebaseline the Short Road sim once.
2. **Mini-boss (lap 6):** drawn from `second.minibosses`.
   - Tier-2 biomes use their normal lists.
   - Tier-3 lists: throne [bone_champion], magma [cinder_brute], ruins [bone_champion], moonlit
     [**moonfang**].
3. **Final boss (after lap 10, 75% HP):**
   - Tier-3 second biome: its `bosses`.
   - Tier-2 second biome: a new field **`short_bosses`**, used only here:
     - hollow → [boss_lich, boss_bone_warden] (the spooky pair)
     - frost → [boss_bone_warden, boss_lich]
     - warcamp → [**boss_cinder_king**, boss_magma_golem] (the warlord's forge; the Cinder King
       reads as an orc warlord).
4. **Lap mapping and scaling:** unchanged. Whatever its tier, the second biome occupies laps
   6–10 at effective laps 7–11. Its pools switch early → late after 3 laps, as today. Twists run
   on the biome's own laps: Moonlit's Full lap is lap 8, and the Warcamp drums and Ruins heat
   work per lap as described.
5. **Short Road routes:** 3 × 7 = **21** (was 4). The fixed Short Road for a fresh profile
   (Short Road unlocks later) is unchanged in content, since the tiers only offer unlocked
   biomes.

Check: the Short Road's 21 routes within ±3 pp of their mean. In particular, a tier-2 finale
(Hollow, Frost, Warcamp) must not be easier than a tier-3 finale by more than 3 pp. If it is,
the tier-2 `short_bosses` keep 75% HP while tier-3 bosses go to 70%.

---

## 7. Unlock pacing

The existing biome unlocks are unchanged: Crypt (run ~2), Magma (~5, first win), Frost (~7).
Classes (from the classes doc) sit at 3, 6, 10, 13, 15, 19, 23, 27 and 32 (Monster Kid 20–25).
Biomes are "major" unlocks, so no run gets a biome and a class.

| biome | milestone id | condition | fallback | Sigil price | target run | neighbours |
|---|---|---|---|---|---|---|
| mines | `prospector` | **Cash out the Treasury 17 times** (existing `cashouts` counter; about 2.2 per run) | or play 12 runs | 5 | **8** | between Paladin (6) and Mage (10) |
| warcamp | `warpath` | **Defeat 380 enemies** (the `kills` counter from the classes doc; about 32 per run) | or play 16 runs | 5 | **12** | between Mage (10) and Ranger (13) |
| moonlit | `night_walker` | **Reach the third biome 16 times** (existing `act3_runs`; realistic runs reach act 3 about 90% of the time) | or play 22 runs | 5 | **17** | between Rogue (15) and Ninja (19) |
| ruins | `sun_seeker` | **Defeat 3 different final bosses** (`firsts.boss` size ≥ 3) | or play 26 runs | 5 | **21** | between Ninja (19) and Druid (23) |

The new mini-bosses and final boss follow their biome:
- mini_orc_warchief with `warpath`
- mini_moonfang (a Hollow candidate) and boss_moon_king with `night_walker`
- boss_sand_colossus with `sun_seeker`.

mini_cinder_brute and mini_briar_beast keep their existing `warden_slayer` unlock (they become
eligible once their host biome is also owned).

**Collisions to fix while implementing:** the current table has many minor unlocks at runs
14–24. Calibrate with `--campaign=40 --campaigns=5`:
- Pass: each biome median within ±2 runs of its target.
- Pass: no median run with 2 majors.
- If `sun_seeker` lands too late (needs 3 distinct final bosses), switch to "win 4 runs" (about
  run 20).

---

## 8. Balance and sim checks

```
godot --headless --path . -s tools/sim.gd -- --runs=300 --class=all --policy=realistic --profile=mid --route=<t1>,<t2>,<t3>
godot --headless --path . -s tools/sim.gd -- --runs=2000 --class=all --policy=realistic --profile=max          # random routes; prints per-route and per-boss tables
godot --headless --path . -s tools/sim.gd -- --runs=500 --class=all --policy=realistic --profile=max --twist=off --route=...,warcamp,...
godot --headless --path . -s tools/sim.gd -- --campaign=40 --campaigns=5 --policy=realistic
```

| check | target |
|---|---|
| every route (36) | win% within **±3 pp of the all-route mean** (realistic, mid and max). Use ≥ 150 runs per route; the table needs about 5,400 runs, so shard by seed. |
| each biome's marginal (routes containing it) | within ±3 pp of its tier mean |
| each twist alone (`--twist=off` delta) | costs or gives at most 4 pp (Mines should be about +1 to +2, Warcamp about −2, Moonlit about −1 to −2, Ruins about −2) |
| deaths by lap | no single lap with more than 1.5× the average deaths per lap (watch Moonlit lap 13 and Warcamp lap 6) |
| final bosses | Sand Colossus and Moon King boss-win% each within ±5 pp of the mean of all 6 |
| profile bands (unchanged) | realistic fresh 30–40% (the fresh route is unchanged), mid 45–50%, max 55–65%, max A10 20–30% |
| Short Road | the 21 routes within ±3 pp; tier-2 finales vs tier-3 finales ≤ 3 pp apart |
| campaign | biome unlock medians within ±2 runs of target; no run with 2 majors |

Interactions to watch:
- **Warcamp × Monster Kid:** Rally adds to attack intents, so BOO! gets more valuable. Fine, but
  check that the class stays within ±5 pp.
- **Warcamp drums × `frenzied` affix:** these stack attack. Cap the total attack bonus per enemy
  at **+8** (drums + frenzy + rally).
- **Ruins heat × Paladin:** the Paladin has no sustain now (its sets redesign), so check the
  Paladin on Ruins routes.
- **Mines × Druid:** ore Face Raises accelerate the Druid's growth, so check the Druid on Mines
  routes (≤ +5 pp over its mean).
- **Moonlit × Necromancer:** the double elite on the Full lap feeds Bone dice (good), and the
  transformed wolves start with drain.
- **Moon King × Druid:** the Druid's growing faces lose their 1s by lap 15, so it has less
  counterplay against the meter. Check the Druid's Moon King boss-win% is within ±8 pp of its
  mean vs other bosses; if not, raise the clouds cap to 3.

---

## 9. Elevation (later pass)

The Forest Nature `Hill_Top_*` and cliff pieces, plus Dungeon `stairs_*`, allow terraces, ramps
and bridges. **Proposal: purely cosmetic height per tile.** The rules stay a flat 1D ring.

- **Data:** `Board.heights: PackedFloat32Array` (presentation seed only; generated from the
  board seed + biome by `game/world`, never in core). Heights are in **0, 0.5, 1.0, 1.5** tile
  units.
  - Adjacent tiles differ by ≤ 0.5, so steps read as terraces.
  - Corners (Start, Forge, Treasury, Portal) sit at 0, so every lap reads as "back to the base
    camp".
- **Hop arcs:** the per-tile hop keeps its duration. The arc peak is max(h_a, h_b) + 0.35. Going
  down adds a small landing squash.
  - On a **ramp**, a 0.5 step uses a Walking step instead of a Jump.
  - A **bridge** (a gap between terraces) uses a plank mesh and a longer, flatter arc.
- **Camera:** the overview framing uses the ring's AABB, including heights (it already frames
  all landing targets). Follow mode biases pitch +5° when the hero is on a high terrace. Combat
  framing reads the tile height as the floor.
- **Readability rules:**
  1. The tile-top colour code and prop stay visible from the overview camera: no terrace may
     occlude a lower tile's top from the default pitch (check with the device matrix).
  2. Max 1.5 units of total relief.
  3. Ghost landing markers and enemy previews float at tile height.
  4. Portal and Start are never raised.
- **Which biomes:**
  - **Moonlit Woods:** a hill terrace ring around the standing stones.
  - **Deep Mines:** scaffold levels, with ladders or stairs between them.
  - **Warcamp:** a raised stockade walkway on one side, with a log bridge.
  - **Glade:** gentle hills.
  - Keep the Crypt, Throne, Ruins and Frost flat (their set pieces carry them).
- **Rules and height:** keep it cosmetic. The only idea strong enough to consider later is a
  **"high ground" tile flag** for the Warcamp stockade: landing there reveals the next lap's
  mutation spawns, a scouting preview with no stat change. It stays out of scope until the
  cosmetic pass ships and the UI can show it. Height-based damage or dodge was rejected: it adds
  hidden math to a board with no movement choice.

---

## 10. Implementation order

| step | work | layer | size |
|---|---|---|---|
| 1 | Tier lists, `twist`/`refill` fields, tile registry (`ore`, `drum`, `oasis`), events, `--twist` flag | core | S |
| 2 | Mines (ore offer, cave-in, `rock_golem`) + tests | core | S |
| 3 | Ruins (heat, oasis) + `boss_sand_colossus` + `bury` intent | core | M |
| 4 | Warcamp (drums → rally at fight start; rebuild) — needs `rally` from the classes/enemies doc step 7 | core | S |
| 5 | Moonlit (phases over laps 11–15, pre-transformed wolves, Full-lap elite and moon rune chest) — needs `transform` | core | S |
| 5b | **`boss_moon_king`** (moon meter, clouds, Moonrise forced phase, `moonfall` intent, A9 rule, Moonfang cross-link) + bot awareness | core | M |
| 5c | Short Road second-biome draw (tier 2 ∪ tier 3), `short_bosses`, tier-3 `minibosses` lists | core | S |
| 6 | Mini-boss homes (Warchief → Warcamp; Moonfang → Hollow candidate); milestones and pacing (§7); presets mid/max biomes | core/meta | S |
| 7 | Sim sweep (§8), then update `docs/plans/balance.md` "Biomes and routes" | sim/docs | M |
| 8 | Visuals per biome (set pieces, tiles, light, particles, music), in the order Mines, Ruins, Warcamp, Moonlit | presentation | L (4 × M) |
| 9 | Elevation (cosmetic) for Moonlit, Mines, Warcamp and Glade | presentation | M |

---

## 11. Decisions (resolved, user via the tech lead, 2026-09-29)

1. **Tiers are 3/3/4.** Moonlit Woods is **tier 3** (laps 11–15, Full lap = lap 13) with its own
   new final boss, **The Moon King** (§4.3), plus the Lich as its second candidate. The Ruins'
   second candidate becomes the Bone Warden, so each existing Throne boss appears in 2 biomes.
   Standard routes: 3×3×4 = **36**; combinations: **168**.
2. **Moonfang:** it is a **Hollow mini-boss candidate** (the single exception to "home biomes
   only"), plus Moonlit's Short Road mini-boss. The Full-lap elite and the phase-2 summon were
   rejected (§4.4).
3. **Short Road:** the second biome is drawn uniformly from the unlocked **tier 2 ∪ tier 3** set.
   Tier-2 finales use the new `short_bosses` lists, and lap mapping and scaling are unchanged.
   That gives **21** routes (§6.2).
4. **The Full-moon lap** also guarantees a **moon rune chest** (§4.2) on top of the 1.5× gold and
   the double elites.
5. **Accepted as proposed:** mini-bosses in their home biomes only (except Moonfang); heat is
   landing-only on oases; elevation stays cosmetic, with high-ground scouting as the only rule
   idea to revisit later.

