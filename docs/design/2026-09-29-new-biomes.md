# Diceroll: four new biomes

Date: 2026-09-29 · Status: proposal (the user approved the four boards; numbers are starting
values for the sim).
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
| `moonlit` | Moonlit Woods | **2** | Moon phases by lap; at the Full Moon, werewolves start transformed and elites double (and fights pay ×1.5 gold) | – | werewolf | mini_moonfang, mini_briar_beast |
| `ruins` | Sunscorched Ruins | **3** | Heat costs 5% max HP at each lap end unless you **landed** on an oasis that lap; oases heal 8% | `oasis` | bone_golem | **`boss_sand_colossus`** (new), boss_lich |

**Tiers and routes:**
- Tier 1 has 3 biomes (glade, crypt, mines), tier 2 has 4 (hollow, frost, warcamp, moonlit) and
  tier 3 has 3 (throne, magma, ruins).
- Routes go from **8 to 36** standard (3×4×3), and on the Short Road (tier 1 × tier 3) from
  **4 to 9**.
- With the mini-boss and final-boss draws, standard runs go from 32 to **144** combinations.

**New content:**
- **2 new ids:** `rock_golem` (Mines elite) and `boss_sand_colossus` (Ruins final boss).
- **1 new intent:** `bury`.
- **3 new tile types:** `ore`, `drum`, `oasis`.
- Everything else reuses existing mechanics: rally, transform, traps, the lava-style "never lethal"
  damage and lap-mutation refills.

**Mini-boss homes:** Moonfang and the Orc Warchief move to their home biomes (Moonlit, Warcamp).
This supersedes the earlier doc, which added them to Hollow and Frost as third candidates. Every
tier-2 biome now has 2 candidates.

**Unlocks:** each biome has a milestone, plus a fallback of "or play N runs". Targets are runs
**8 / 12 / 17 / 21**, placed between the class unlocks (runs 6, 10, 13, 15, 19, 23, …) under the
one-major-unlock-per-run rule.

**Elevation** is a later, **cosmetic** pass (see the Elevation section). Good fits: Moonlit
Woods, Deep Mines, Warcamp.

---

## 1. Shared core additions

1. **`BiomeDefs.TIERS`** = `[["glade", "crypt", "mines"], ["hollow", "frost", "warcamp",
   "moonlit"], ["throne", "magma", "ruins"]]`.
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
- Target: the Warcamp is within ±3 pp of the tier-2 average (hollow, frost, moonlit).

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

## 4. Moonlit Woods (`moonlit`, tier 2)

*"The moon waxes as you walk. When it's full, the woods stop pretending to be quiet."*

| field | value |
|---|---|
| Name / desc | **Moonlit Woods**: "The moon grows each lap. Under the full moon, werewolves are already changed, twice as many elites stalk the woods, and every fight pays 1.5× gold." |
| Twist (`moon`) | **Phase = the lap's position in the biome:** 1 Crescent · 2 Half · **3 Full** · 4 Half · 5 Crescent (laps 6–10 on the standard road). **Half:** `transform` enemies change at **≤65% HP** instead of ≤50%. **Full:** `transform` enemies (werewolf, Moonfang) **start the fight in their second form**. The lap mutation *into* the Full lap spawns **+1 Elite** (2 in total). Fights on the Full lap pay **gold ×1.5**. **Crescent:** no effect. The HUD shows a moon icon with "Full moon in N laps". |
| Tile mix (28) | `{"event": 1, "trap": -1}` (fairy-ring events; no traps in the woods) |
| Early pool | wolf_bandit, thorn_sprite, werewolf, hollow_wisp |
| Late pool | werewolf ×2, wolf_bandit, bandit |
| Elite leader | **werewolf** (elite; uses the "Silverback" texture B via skin_rules) |
| Affixes | vampiric, regenerating, frenzied, warded (+gilded) |
| Mini-boss candidates | **mini_moonfang** (home; on the Full lap it spawns already transformed if it is still up), **mini_briar_beast** (unused until now; the woods suit it) |
| Core hooks | `RunState.moon_phase()` is derived from lap and biome (no new state). `CombatState.begin`: if transform and Full, start in phase 2 (emit `enemy_transformed {form: "wolf", source: "moon"}`). Transform threshold from phase. `Board.mutate`: extra elite when the next lap is Full. Gold mult in `_win`. |

Balance:
- The Full lap is a spike (2 elites plus pre-transformed wolves) paid back by gold ×1.5 and more
  elite passive drops. That is a push-your-luck lap: board rerolls to dodge elite tiles matter.
- The tier-2 check is within ±3 pp. Watch deaths on lap 8 specifically: they should be at most
  1.5× the tier-2 average per lap.
- Tuning order: remove the +1 elite first, then the Half threshold.

**Set piece and dressing:**
- **Centre:** a ring of tall standing stones (Forest `Rock_3_*` tall variants) around a huge
  gnarled `Tree_Bare`, with a woodcutter's stump + `axe` and `log_stacks` (Werewolf set) nearby.
- **Foliage:** Forest Nature trees and bushes in their **cool colour variants** (the teal, blue
  and violet Color sets) for moonlit hues, grass tufts and some `Rock_1_*` boulders.
- **Sky:** a big moon disc behind the island. Its fill and size animate by phase (crescent →
  full).
- **Palette:** deep indigo, silver-blue moonlight, teal foliage, warm firefly pinpoints. At Full,
  the moon tints slightly red-silver.
- **Light:** a cool directional moon key, strong rim. Brightness rises by phase; at Full, a
  subtle bloom and red rim on enemies.
- **Particles:** fireflies, drifting leaves, low ground mist. A howl sting on Full.
- **Music:** soft celesta and strings, distant howls; a swelling layer on the Full lap.

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
| Final-boss candidates | **boss_sand_colossus** (new), **boss_lich** (the tomb-lich reading; it also stays in the Throne) |
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
| HP | **1250** (Lich 1650, Bone Warden 1150, Cinder King 1200, Magma Golem 800) |
| Phase 1 | attack 20 / block 26 / summon 1 (`bone_cutthroat`, lap-scaled) |
| Phase 2 ("Sandstorm") | **bury 2** / attack 24 / attack 20; trait **pierce** |
| Unique mechanic | **Bury** (new intent): locks **N** of your dice for your next turn (as curse N) **and** gains **10 Block per die buried**. Burying dice limits your combos just as the Colossus raises its guard. Pierce in phase 2 punishes Block builds. |
| Core | `bury` = curse N + block (10·N), scaled like block. Intent icon: a die sinking into sand. |
| Target | its boss-win% within ±5 pp of the other four final bosses (the `--boss=` table) |

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

| tier | biomes | difficulty notes |
|---|---|---|
| 1 (laps 1–5) | glade (easy: heals), crypt (traps), **mines** (economy + traps) | all within ±3 pp of the tier mean |
| 2 (laps 6–10) | hollow (events), frost (ice locks), **warcamp** (rally), **moonlit** (Full-moon spike) | warcamp and moonlit are the "aggressive" pair, and hollow and frost the "attrition" pair. Watch that the tier-2 spread stays ≤ 6 pp |
| 3 (laps 11–15) | throne (elites), magma (lava), **ruins** (heat) | final bosses: lich (throne, ruins), bone_warden (throne), cinder_king and magma_golem (magma), **sand_colossus** (ruins) |

Counts:
- Standard routes: **36** (was 8). Mini-boss candidates: **8** (2 per tier-2 biome). Final
  bosses: **5**.
- Standard combinations: 36 × 2 × 2 = **144**.
- **Short Road** (tier 1 + tier 3; it has no tier-2 biome, so the Warcamp and Moonlit never
  appear): **9** routes. Its mini-boss still comes from the tier-2 list, as today.
- **Default new-profile route:** unchanged (Glade → Hollow → Throne).
- `firsts.route_win` Sigils: 36 possible route wins (was 8). That is still a first-per-route
  reward of 1 Sigil, and no Sigil inflation risk, because each route is a one-time first.
  Watch the Sigil total in the campaign sim anyway.

---

## 7. Unlock pacing

The existing biome unlocks are unchanged: Crypt (run ~2), Magma (~5, first win), Frost (~7).
Classes (from the classes doc) sit at 3, 6, 10, 13, 15, 19, 23, 27 and 32 (Monster Kid 20–25).
Biomes are "major" unlocks, so no run gets a biome and a class.

| biome | milestone id | condition | fallback | Sigil price | target run | neighbours |
|---|---|---|---|---|---|---|
| mines | `prospector` | **Cash out the Treasury 17 times** (existing `cashouts` counter; about 2.2 per run) | or play 12 runs | 5 | **8** | between Paladin (6) and Mage (10) |
| warcamp | `warpath` | **Defeat 380 enemies** (the `kills` counter from the classes doc; about 32 per run) | or play 16 runs | 5 | **12** | between Mage (10) and Ranger (13) |
| moonlit | `night_walker` | **Reach the second biome 16 times** (existing `act2_runs`) | or play 22 runs | 5 | **17** | between Rogue (15) and Ninja (19) |
| ruins | `sun_seeker` | **Defeat 3 different final bosses** (`firsts.boss` size ≥ 3) | or play 26 runs | 5 | **21** | between Ninja (19) and Druid (23) |

The new mini-bosses and final boss follow their biome:
- mini_orc_warchief with `warpath`
- mini_moonfang with `night_walker`
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
| deaths by lap | no single lap with more than 1.5× the average deaths per lap (watch Moonlit lap 8 and Warcamp lap 6) |
| final bosses | Sand Colossus boss-win% within ±5 pp of the other four |
| profile bands (unchanged) | realistic fresh 30–40% (the fresh route is unchanged), mid 45–50%, max 55–65%, max A10 20–30% |
| Short Road | the 9 routes within ±3 pp |
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
| 5 | Moonlit (phases, pre-transformed wolves, Full-lap elite) — needs `transform` | core | S |
| 6 | Mini-boss home moves; milestones and pacing (§7); presets mid/max biomes | core/meta | S |
| 7 | Sim sweep (§8), then update `docs/plans/balance.md` "Biomes and routes" | sim/docs | M |
| 8 | Visuals per biome (set pieces, tiles, light, particles, music), in the order Mines, Ruins, Warcamp, Moonlit | presentation | L (4 × M) |
| 9 | Elevation (cosmetic) for Moonlit, Mines, Warcamp and Glade | presentation | M |

---

## 11. Open questions for the user

1. **Tier placement:** is 3/4/3 (Mines in tier 1, Warcamp and Moonlit in tier 2, Ruins in tier
   3) right? Or should Moonlit be tier 3 with its own new final boss, which would give
   3/3/4 and a 6th boss?
2. **Short Road:** tier-2 biomes never appear there (it is tier 1 + tier 3). Should the Short
   Road instead draw its second biome from tiers 2 and 3 so the Warcamp and Moonlit show up?
3. **Moonfang and the Orc Warchief** move to their home biomes (removed from Hollow and Frost).
   OK, or do you want them in both?
4. **Full-moon upside:** is gold ×1.5 enough of a reward for the double-elite lap, or should the
   Full lap also guarantee a rune chest?
5. **Heat is landing-only** (you pass every tile each lap, so "pass an oasis" would be free).
   Is steering with the board reroll the fantasy you want, or do you prefer a softer version
   where landing on an oasis cools you for 2 laps?
6. **Elevation** stays cosmetic, with "high ground scouting" as the only rule idea. Is that
   acceptable?
