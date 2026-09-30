# 13. Rules as data: a declarative effect system for Diceroll

Date: 2026-09-30. Status: research and design input for Vlad; nothing in the repo was changed.
Scope: make practically every content domain (weapons and the rest of the Armory, relics/passives,
runes, dice kinds, pets, potions, affixes, classes, enemies and bosses, biomes/maps and tiles,
twists, events, shop/draft/reward tables, ascension and future daily/seasonal modifiers,
minigame variants, unlocks, camp upgrades) addable or changeable by **downloaded data**, with
behaviour expressed in a closed, declarative, non-Turing-complete vocabulary that core code
interprets. Store policy (Apple 2.5.2, Google Play Device and Network Abuse) forbids downloading
executable code; declarative data interpreted by reviewed code is allowed.

Inputs: `/home/user/diceroll/docs/design/2026-09-29-distribution-v2.md` §4 (content model, §4.4
caps, §4.9 data vs code), its plan step 2.3 (`docs/plans/2026-09-29-distribution-v2-plan.md`), and
the content audit `docs/research/distribution-2026-09/02-content-model.md` (§1 inventory, §2 primitives, §8 design,
appendix C). All `file:line` references are to the repo at commit `3209adf` (read-only).

Prototype (scratch, outside the repo):
`rules-prototype/` in this folder (the throwaway scratch projects themselves were not kept)
(`A/` = copy of `core/` unchanged, `B/` = the same core with a rules evaluator and 41 rules of
content re-expressed as JSON; `golden.gd`, `replay.gd`, `micro.gd` are the harnesses). Appendix A has
the details and how to rerun it.

---

## 0. Summary

**Verdict: feasible, and the prototype says so with numbers.** A rule engine of the shape
"trigger → condition → effects, with limits, chance, priority and named resources", fed by JSON and
compiled into typed node objects at load, can express essentially all of today's content behaviour.
It keeps the game's exact semantics, including float accumulation order, RNG draw order, event order
and `elif`-style exclusivity. What stays in code is a **library of native primitives**: the combo
evaluator, damage and status resolution, enemy intent execution, board generation and movement, offer
UI flows, minigame state machines and presentation builders. Data calls these by name with
parameters. New primitives ship in core releases, and data then recombines them.

**What the prototype proved** (Godot 4.7.2, headless, against copies of `core/`):

| Test | Result |
|---|---|
| Content re-expressed as data | 25 passives (pair_master, crowd_pleaser, triple_threat, steady_hand, boxcars, snake_eyes, straight_shooter, midas_fist, glass_cannon, opening_salvo, gold_tooth, full_house_party, bloodthirst, thorns, loaded_hands, iron_skin, encore, phoenix, second_wind, piggy_bank, treasure_sense, haggler, scholar, resonance, rune_echo); rune activation for all 12 runes plus the ember, echo and vampire effects; the Arming Sword's Twin Edge plus 5 variants (Rapier, Saber, Flame, Frost, Knight's); ascension `shop_tax`; **the Moon King's moon meter as a boss resource** (start / Moonfang / A9 start, tide, clouds, Moonrise, Moonfall). 41 rules, 249 nodes |
| Behaviour equivalence (event-stream + final-state SHA-256, greedy bot, forced passives/runes/variants) | **220 runs (4 configs × 11 classes × 5 seeds, 72,695 commands, 9,321 attacks, 90,078 rule evaluations): all hashes identical** between original and data-driven cores |
| Real `tools/sim.gd`, natural content acquisition | `--policy=greedy --profile=max` 66 runs: output **identical**; `--policy=realistic --profile=max` 44 runs: output **identical** (only the `decide()` timing line differs) |
| Per-rule cost | ~0.7–1.4 µs per expression node, **~7 µs per firing rule** (with its announce event), 1.3 µs for a hook with no listeners; the 5-passive "pips" stage costs **35 µs as data vs 10.6 µs native (3.3×)** |
| Engine-only cost (replay of 54,869 recorded commands, no bot) | +15–20 % engine time with 3–8 forced passives and runes on most dice (the prototype, unoptimised beyond specialised node classes) |
| End-to-end sim cost | **+3.4 %** wall time (realistic bot, 44 runs), **+3.5 %** (greedy bot, 66 runs); +11 % in the golden harness with heavy forcing and hashing |
| Compile cost at full-content scale | 615 rules / 3,735 nodes: 14 ms JSON parse + 29 ms compile (desktop); 168 KB JSON, 5.8 KB gzip |

**Coverage of today's content (§4):** of the **271 behavioural content entries**, **256 (94.5 %)**
are expressible with the core vocabulary (§2) and **267 (98.5 %)** with about ten small generic
additions (§2.12): passives 32/32, Armory rules 51/51 and variants 51/51, runes 11/12, pets 11/12,
potions 4/4, affixes 10/10, enemies 36/36 (intents become op compositions), biome rules 10/10, tiles
18/18, events 7/7, ascension 10/10, class mechanics 6/7. The exceptions are named native primitives:
the Wild rune and the Monster Kid's ★ face (combo-evaluator wildcards) and the Grimoire's rune
re-fire. **Minigames stay code** (11 state machines), but their variants, rewards and signatures are
data, and four generic templates would let new minigames in those families ship as data (§3.1).
Presentation is a separate axis: generic beats and meters cover data content; bespoke VFX, pet bodies
and dressing kits stay code builders.

**Cost of getting there:** this replaces plan step 2.3 ("rules dispatch on rule ids", 20–29 d) with a
rule engine plus per-domain conversions: **about 54–75 agent-days in total**, or roughly +31–42 d
over 2.3 + 2.4. The payoff is that the conversions stop being per-domain rule-id switches and become
data, so each later content drop needs no core work for anything within the vocabulary.
**Minimal path to "a new class, a new biome, a new pet, new relics and new weapons ship as data":
about 62–83 agent-days of effort, about 26–35 working days elapsed with four lanes**, including the
plan's M1, 2.1, 2.5, 2.6 and the kit part of 2.7 (§7.3).

**Recommendations**

1. Adopt the rule engine as the target of M2 (replace 2.3) and keep 2.1/2.2/2.4–2.9 as planned.
2. Build the engine core (R0) and wire **hook points** into `combat.gd`, `game_flow.gd`, `run_state.gd`
   and `board.gd` first (R1). Then migrate domain by domain behind the golden harness, using
   **priority bands** so that native code and data rules interleave in exactly today's order (the
   prototype's technique).
3. Freeze behaviour during migration (goldens identical). Only then do one deliberate
   **normalisation** release that re-baselines goldens once: per-owner RNG streams, canonical event
   shapes and generic limit/resource keys.
4. Give the AUTO bot a **model compiler** (pipeline rule shapes → `CombatModel` vectors) and `ai`
   hints on every owner. Id tables in `bot.gd`/`bot_meta.gd` go away.
5. Validate every set in CI: schema, semantic types, hook/op compatibility, trigger-cycle detection
   and caps. Add grammar-based fuzzing. Ship a **rule trace** in the dev menu.

---

## 1. The engine's execution model today

Everything below is deterministic and single-threaded. A player command (`GameFlow.apply`,
`core/game_flow.gd:1947`) mutates `RunState`/`CombatState` and returns an **event list** that the
presentation replays (`game/flow/event_player.gd:22`). All randomness comes from **one** seeded
stream, `run.rng` (xorshift64*, `core/rng.gd:1`). The only exceptions are affix rolls, which use a
derived `Rng(hash([seed,"affix",lap,idx,ids]))` (`core/run_state.gd:201`), and each minigame's own
Rng, seeded with one draw from `run.rng` (`core/game_flow.gd:1713`). So **the number and order of RNG
draws is part of the behaviour**, and a rule that draws must draw at the same point.

Content behaviour runs at the hook points below. "Owner" says who hard-codes behaviour there today
(P passives, I items, R runes, Pet pets, C class mechanics via `ClassLogic.mech()`, B biome/twist,
E enemy/affix/boss, A ascension, Pot potions, Ev events).

### 1.1 Run lifecycle

| Phase | Where | What runs | Owners |
|---|---|---|---|
| Run build | `MetaRun.build` `core/meta/meta_run.gd:17`; `armory_stats` `:57` | profile → run config: items, pet, pools, asc keys, belt, **Compass/Lantern/Coin Purse by id** (`:62-72`) | I, A, Pet |
| Run start | `RunState.create` `core/run_state.gd:77` → `MetaRun.apply_start` `meta_run.gd:143` → `Board.generate` `:145` → `after_board_generated` `:166` (A8 hazard tile, minigame tiles) → `roll_board_affixes` `:216` | starting dice from class (`kinds`, `runes`, `tags`), turret die (`:94`), route/boss draws (`:110-143`) | C, A |
| Run start offer | `GameFlow.new_run` `core/game_flow.gd:62` | Whetstone forge offer | camp upgrade |
| Run end | `_finish` `game_flow.gd:735`, `_summary` `:747`, `MetaRun.rewards` `meta_run.gd:173` | Crowns, stats | — |
| Profile banking | `Profile.apply_run_result` `core/meta/profile.gd:276`, `_count` `:401`, milestones `_cond` `:463`, feats `feat_met` `:800` | counters (5 id-specific: `frost_visits`, `throne_wins`, `mage_wins`, `hollow_events`, `skeleton_kills`) | B, C, E |

### 1.2 Board turn

| Step | Where | Content that hooks here |
|---|---|---|
| Roll pool | `roll_board` `game_flow.gd:106` (board rerolls = class + **Pathfinder** + lap pool) → `_do_board_roll` `:132` | ★ face value (`ClassLogic.pretend_board_value` `:144`); doubles feed Treasury (+2 **Coin Mimic** `:152`) |
| Move pick | `_select_move` `:161` → `pick_move_dice` `:176` (native algorithm; Compass III tie-break via `ItemLogic.pair_pick`) | I |
| Board reroll | `board_reroll` `:116` → `ClassLogic.on_board_reroll` `:126` (Shadow Step refund) | C |
| Confirm move | `confirm_move` `:277`: Gilded rune MOVE gold per moving die `:284`, Turret's Gilded `:287`; doubles → `PetLogic.on_board_double` `:296`, `ItemLogic.on_board_double` (Ambush primed) `:297`, **Double Trouble** `:298`, **Fast Feet** queues a bonus move `:305` | R, C, Pet, I, P |
| Path | `_move` `:324`: Coin Purse treasury step on passed Treasury tiles `:343`; lava on passed tiles `:351` | I, B |
| Lap end | `_move` crossing: **heat** `_heat` `:357`/`:1448`, lap heal (`lap_heal_pct` `run_state.gd:300` + Bark `:358`), `ClassLogic.on_lap` (Overgrowth) `:364/:372` | B, I, C, A |
| Lap start | new biome `_new_biome` `:783` **or** mutation `board.mutate` `:380` (+A1/Full-moon extra elites `:376-379`), mini-boss spawn `:381`, affix rolls `:383`, `_twist_mutation` (drum rebuild, moon chest) `:384`/`:1416`, minigame tiles `:385`; `_moon_event` `:387`; **Piggy Bank** `:388`; shop laps `:393` | B, A, P |
| Biome start | `_new_biome` `:783`: regenerate board, 30 % heal `:800`, **Guard Die** perk potion `:802`, A7 curse `:805`, **Rune Bloom** `:807`, `ClassLogic.on_biome` (Sanctify, seeds) `:809`, `ItemLogic.on_biome` (Grove) `:810` | Pet, A, P, C, I |
| Pending queue | `_advance` `:402`: tile, shop, draft, rune_choice, boss, passive_choice, bonus_move, victory, forge | — |
| Tile land | `_trigger_tile` `:452`, `match type` over 18 tile types (`:457-558`): fights `:458-463`; **chest** (moon chest, potion chance, Skeleton Key forced rune, Grimoire 4 runes, Coin Mimic L10 double roll, **Treasure Sense**) `:464-482`; event `:483`; **campfire** (Glade 45 %, Tankard, Pumpkin) `:486-493`; **trap** (dodge roll, Lantern min, Skull Buddy +1, Pebble ½, A8 hazard mult, survive_lethal, **Crypt** dodge gold) `:494-514`; **ice** (Frost Mote) `:515-525`; lava `:526`/`:572`; ore `:528`/`:1490`; drum `:530`/`:1475`; oasis `:532`/`:1465`; **forge** (lift A7 curse, **Blacksmith**, Wrench edits) `:534-539`; treasury (Coin Purse cashout) `:540-549`; portal (Compass bonus) `:550`/`:561`; minigame `:552` | B, P, I, Pet, A |

### 1.3 Combat

Fight start, `CombatState.begin` (`core/combat.gd:61`):
`make_enemy` (lap scaling, per-id sim tune) `:115` → `meta_enemy` (A1/A4/A6/A9/A10 HP and traits)
`:140` → `AffixDefs.apply` `:81` → `_biome_begin` (Warcamp drum rally, Moonlit half/full moon,
**Moon King meter start**) `:82`/`:1098` → pet reroll boost `:85` → roll intents `:94` → Frostpeak chill
→ pending curse `:102` → `ClassLogic.on_combat_start` (Oath, Wild Bond) `:106` →
`ItemLogic.on_combat_start` (Opening Volley) `:107` → win check → `start_turn` `:112`.

Player turn, `start_turn` `:245`: `ClassLogic.before_turn` (Bone dice join) `:249` → block reset,
rerolls = class + banked `:252-255` → **Loaded Hands**, **Iron Skin** `:261-268` → Stoneskin carry,
Bubble Breaker boost, `ItemLogic.turn_start` (Quick Hands, Lesson, Plank, Tower, Bulwark,
Heraldic, Standard block, Plated, Thick Hide) `:269-280` → curse locks (RNG shuffle) `:291-297` → roll
each die (RNG) `:305-307` → `ItemLogic.after_roll` (Loaded Die, Short Bow) `:310` →
`PetLogic.on_turn_start` (Guard Die carry/charge, **Crystal Wisp fires**) `:311` →
`ClassLogic.on_turn_start` (empty) `:312`.

Reroll, `reroll` `:325`: re-roll marked dice (RNG, Wisp free reroll) `:342` → **Encore** `:350` →
`ClassLogic.on_reroll` (Shadow Step) `:354` → `ItemLogic.on_reroll` (Focus, Shuriken, Poise) `:355` →
`PetLogic.on_reroll` (Tinker charge) `:356`.

Attack, `attack` `:435`. This is the ordered pipeline that matters most:

| # | Stage | Line | Content | Accumulator |
|---|---|---|---|---|
| 1 | pet fires | `:438` `PetLogic.fire_at_attack` | 11 pets' fire (Wisp fires at turn start) | state/events |
| 2 | combo detect | `:443` `current_combo` → `Combo.evaluate` `core/combo.gd:29` | Wild rune / ★ face wildcards (cap `WILD_MAX_DICE`) | `combo` |
| 3 | combo mult | `:447` `passive_mult` `:395` | **Crowd Pleaser** (`max`), **Pair Master** (+), **Triple Threat** (+), then + Wisp `pet_mult` | `mult` float |
| 4 | class combo bonus | `:456` `ClassLogic.combo_bonus` | Oath kept | `mult` +, `bonus` + |
| 5 | rune times | `:459-469` | **Resonance** (×2) else **Rune Echo** (25 % RNG ×2, per die); Heavy/Echo never doubled (`NO_DOUBLE_TRIGGER`) | `times[i]` |
| 6 | rune activation | `:473` `rune_active` `:408` | per rune: trigger by **rune id** (not the declared `trigger`), cap 2 per rune (Wild 1) | `act[i]` |
| 7 | Arcana | `:474` `ItemLogic.arcana` | first active rune ×2 on Wizard Hat turns | `times` |
| 8 | per-die score | `:486-513` | Heavy (pips×(1+times)), Blade (+bonus), **Echo** (+0.5×times mult), Wild event; passives counted: Steady, Boxcars, Snake Eyes | `sum`, `bonus`, `mult` |
| 9 | pips stage | `:514-530` | **Steady Hand**, **Boxcars** (bonus); **Snake Eyes**, **Straight Shooter**, **Midas Fist** (flat) | `bonus`, `flat` |
| 10 | item mods | `:533` `ItemLogic.attack_mods` `item_logic.gd:383` | 25 item/variant rules (Twin Edge, Great Arc, Rampage, Crush, First Strike, Flow, Channel, Spark, Deadshot, Scrap, Tome, Ferocity, Ambush, Dominion, Brawn, Hunter…) | `mult`, `flat`, `factor` |
| 11 | factors | `:545-551` | **Glass Cannon**, **Opening Salvo**, `ClassLogic.attack_factor` (Aim) | `factor` |
| 12 | total | `:552` | `floor(((sum + bonus) * mult + flat) * factor) + atk` | fixed native formula |
| 13 | pre-hit | `:564` `ItemLogic.pre_hit` | Bonebreak | enemy block |
| 14 | main hit | `:566` `damage_enemy(target,total,"attack")` | → §1.3.1 | |
| 15 | after main hit | `:567` `ClassLogic.after_main_hit` | Piercing Shot (overkill chain) | |
| 16 | after hit | `:569` `ItemLogic.after_hit` `item_logic.gd:576` | Cleave, Saber, Reach/Sweep splash, Crush secondaries, sword/staff/dagger secondaries, poisons, Aegis, Vow, Blessed, Nimble, Reload, Spare Arrows, Rampage bookkeeping | |
| 17 | enemy reactions | `:570-580` | trait **frenzy**, trait **thorns** reflect | |
| 18 | runes after hit | `:582-600` | **Ember** (all), **Thunder** (random enemy, RNG) | |
| 19 | after runes | `:601-614` | **Gold Tooth**, **Full House Party** | |
| 20 | runes after attack | `:617-658` | Venom, Frost, Guard (+Steadfast), **Vampire** (only if the attack killed), Gilded, Lucky; per die × times, in pool order | |
| 21 | after attack | `:659` `ClassLogic.after_attack` | Turret fires (RNG), BOO! scare | |
| 22 | attack resolved | `:660` `PetLogic.on_attack_resolved` `pet_logic.gd:290` | pet charge (12 `charge_on` kinds), Grimoire memory | |
| 23 | attack end | `:661` `_moon_clouds` `:1176` | **Moon King** clouds | |
| 24 | win / enemy phase / next turn | `:662-668` | | |

#### 1.3.1 Damage, kills, thresholds (`damage_enemy`, `combat.gd:670`)

Lantern Ghost L10 +1 on poisoned (`:676`) → trait **ward** / **ward_allies** halve (`:679-686`) →
block absorbs unless `ignore_block` (`:687-690`) → HP. On a lethal hit: poison kill counter,
overkill, **gilded** affix pet charge (`:706`), **Bloodthirst** (`:711`),
`ClassLogic.on_enemy_killed` (Bone harvest) (`:716`), `ItemLogic.on_kill` (`kills_by_id`,
**skeleton_kills by id list** `item_logic.gd:745`, Reap, Harvest, Trident gold, Dominion, Soul)
(`:717`). Otherwise the **transform** threshold for regular enemies and mini-bosses (`transform_at`,
Half moon 0.65) re-rolls the intent (RNG) (`:719-730`), and the **boss phase 2** at ≤ 50 % runs
`_boss_phase2` → `ClassLogic.on_boss_phase` (`:731-756`). Damage may cascade: a thorns hit can kill,
the kill heals, and so on. Re-entrancy is bounded only by the content.

#### 1.3.2 Enemy phase (`_enemy_phase`, `combat.gd:788`)

Per living enemy, in index order: block decays unless trait **armor** (`:796`) → **poison** tick
(ignores block; decays by 1, except a boss with Lantern Ghost L5) (`:799-810`) → skip if **frozen**
or **cower** (`:811-818`) → **affix pre-action** (regenerating, hexing, frostbound) (`:819`/`:908`) →
**intent execution** (`:820`/`:930`): attack/chill/drain via `_hit_hero`, heal, burn, scorch, block,
buff, rally, curse, bury, moonfall, summon, chaos → re-roll intent (RNG; summon cap → block 8;
**vampiric** turns attack into drain) (`:828`/`:212`). After all enemies: **burn** tick on the hero
(Wick perk −1) (`:830`/`:839`), **moon tide** (`:832`/`:1152`), `ClassLogic.on_enemy_phase_end`
(empty) (`:834`).

Hero hit, `_hit_hero` (`:863`): `ItemLogic.incoming` (Vanish) → pierce or block →
`survive_lethal` (`run_state.gd:384`: **Phoenix** per act, then **Second Wind** per run, then **Last
Stand** per run with HP-before > 50 %, first wins) → passive **Thorns** (only if the hero lives and
took damage) (`:886`) → `ItemLogic.after_enemy_hit` (Spiked Shield, Horned, Rattle, Catch) (`:890`) →
Pebble thorns (`:891`).

#### 1.3.3 Fight end

`_win` (`:1029`): gold and XP per enemy (elite ×, affix `reward_mult`, fled ×0.5), **Scholar** (XP),
Moonlit full ×1.5 gold, restore Chaos/Scorch faces, `ClassLogic.on_fight_end` (bone crumble).
Then `GameFlow._on_combat_won` (`game_flow.gd:645`): block reset, stats, **pet** `on_fight_won`
(Bubbles charge and brew) (`:659-663`), gold (Charm %), `ItemLogic.on_fight_won` (Patchwork)
(`:666`), board clear, boss → `_second_boss` (A10) or victory (`:670-680`), XP → `_level_ups`
(`:718`), and the reward queue: mini-boss → boss passives; elite → regular passives or (15 %,
**Throne** 30 %) boss passives (`:687-692`).

### 1.4 Economy, offers, consumables

| Flow | Where | Content hard-wired there |
|---|---|---|
| Shop open | `_open_shop` `:995`, restock `_restock_price` `:1001` (A3, Trader's Map, Tinker −3) | A, I, Pet |
| Shop stock | `_shop_stock` `:1009`: weights `ShopDefs.ITEMS`, gating, n (+Trader's Map), Healer's Flask forced potion | I |
| Shop item | `_shop_item` `:1045`: die kind (Paladin bias `ClassLogic.shop_kind_bias` `:1568`), potion price (Bubbles −5), face raise (Wrench), rune rarity price, passive price; **Appraise**, **Haggler**, **A3 tax** | C, Pet, I, P, A |
| Buy | `shop_buy` `:1101` (closed kinds: die, rune, passive, potion, face_raise, combat_reroll) | — |
| Draft | `_open_draft` `:816` / `_draft_option` `:828` (closed ids) | — |
| Rune choice | `_open_rune_choice` `:842`, pools/caps `_rune_pool` `:1555` | — |
| Passive choice | `_open_passive_choice` `:854` | — |
| Gain passive | `_gain_passive` `:868`: **Glass Cannon** HP loss, **Collector**, **Extra Hand** (add die), **Rune Bloom** | P |
| Assign rune | `_assign_rune` `:905` (**Collector** +HP) | P |
| Forge | `forge_apply` `:1187` (raise/mirror; Blacksmith extra use) | P |
| Events | `_open_event` `:1243` (`match id` builds choices), `event_choose` `:1293` (`match id` resolves); **Hollow** heal and counter `:1376-1381` | Ev, B |
| Ore offer | `_open_ore` `:1490`, `_mine_ore` `:1510` | B |
| Potions | `use_potion` `:1643`, `_drink` `:1675` (`match type`, **unknown → heal**) | Pot |
| Minigames | `_start_minigame` `:1711`, result `:1762`, `_reward_options` by tier + signature `:1779`, `_pick_reward` `:1825`, `_pick_signature` `:1867` | minigame |

### 1.5 Pets

The charge meter lives in `run.pet_state.charge` and persists across fights. Charge sources:
`PetLogic.on_board_double` (Coin Mimic) `pet_logic.gd:38`; `on_turn_start` (Guard Die: attack
intents) `:45`; `on_reroll` (Tinker) `:277`; `on_fight_won` (Bubbles) `:284`;
`on_attack_resolved` (the 12 `charge_on` kinds) `:290`; `add_charge` from outside (Wild Bond, Bone
Scythe, gilded affix) `:25`. Firing: `fire_at_attack` `:81` (`match id`, 10 pets), `on_turn_start`
(Crystal Wisp) `:62`, `_cauldron_brew` `game_flow.gd:698`. **Perks** (always on) are spread over 14
`has_pet(id)` sites (appendix C of the audit). L5/L10 are `pet_level() >= n` branches inside those
sites.

### 1.6 Meta and camp

`core/meta/camp.gd` holds Camp commands in the same command → events style (`:6-47`): ranks,
pouch, item buy/craft/equip, pet levels, Sigil unlocks, pool toggles, starter kit, loadout, class,
mode, ascension, bank run, skins. Upgrades (`UnlockDefs.UPGRADES` `core/content/unlocks.gd`) take
effect through `MetaRun.build` fields (`whetstone`, `starter_kind`, belt cap, loadout slots). The
Camp scene is procedural code: stations in `game/camp/camp_stations.gd:13`, a stage per unlock tier,
and `game/camp/stages/stage_*.json`, which are profile snapshots for screenshots, not content.

### 1.7 Ordering rules that matter (the evaluator must reproduce these)

1. **Damage formula and stages** (`combat.gd:552`): `floor(((sum + bonus) * mult + flat) * factor) +
   atk`. "Pips" before the multiplier are worth ×mult, which is why the Armory adds item pips *after*
   the multiplier (`item_logic.gd:377-382`). A data rule must name its stage (`bonus` vs `flat`).
2. **Within a stage**: integer adds commute, but **float accumulation order does not** (`mult` sums
   non-dyadic values such as Wisp's 0.05 + 0.01·L and Spark's 0.05). A `max` (Crowd Pleaser) must come
   before the adds (Pair Master). The prototype keeps exact parity by giving rules priorities equal to
   today's code order.
3. **Rune order**: `times` (Resonance, then Rune Echo's RNG), then activation caps in *pool order*
   (first two dice per rune), then Arcana doubles the *first* active trigger. Effects come in three
   passes: per-die score (Heavy, Blade, Echo), after hit (Ember, then Thunder), after attack (Venom,
   Frost, Guard, Vampire, Gilded, Lucky), each per die in pool order and per `times`.
4. **First-wins chains**: `survive_lethal` (Phoenix, Second Wind, Last Stand); `rune.times`
   (Resonance `elif` Rune Echo); intent overrides (summon cap → block, vampiric → drain).
5. **RNG draw order**: rolls, curse lock shuffle, Rune Echo chance, Thunder target, Shuriken and
   Spare Arrows targets, Opening Volley target, intents and summons, pet Guard Die d6, Turret roll,
   and board draws. A condition must short-circuit *before* a chance draw exactly as today
   (`elif run.has_passive("rune_echo") and run.rng.chance(...)`).
6. **Integer casting**: `int(round(x))` for Standard-scaled numbers (`ItemLogic.ni`),
   `int(floor(x))` for splash and overkill shares, `int(x)` truncation for Piggy Bank, `mini`/`maxi`
   caps. The vocabulary makes these explicit (`round`, `floor`, `trunc`); the validator rejects
   implicit float→int on int-typed effects.
7. **Event order and shape** are consumed by `EventPlayer`: the announce (`passive_triggered`,
   `item_triggered`, `rune_fired`, `class_triggered`) comes before the effect's own events. Shapes are
   inconsistent today: Vampire's `hp_changed` has no `max_hp`; Iron Skin's `block_gained` has no
   `source`. JSON key order does not matter; Godot's `JSON.stringify` sorts keys.
8. **Anti-stacking caps** are part of rules: `RUNE_STACK_MAX`, `WILD_MAX_DICE`, `HEAVY_MAX`,
   `MAX_BANKED_REROLLS`, `ATK_BONUS_CAP`, `MAX_SUMMONED_ALIVE`, per-fight "uses".

### 1.8 Hidden coupling a data model must absorb

- **The AUTO bot duplicates rules.** `bot.gd` `CombatModel` (`:741`) re-implements the damage formula
  with flags per passive (`pair_master`, `snake`…), per item (`_item_model` `:1280`, 29 id reads) and
  per mechanic (`_class_model` `:1354`), plus the Moon King (`_moon_model` `:1343`). Tile values copy
  twist rules (`bot.gd:2320-2333`: Glade campfire, Crypt dodge gold, Treasure Sense). Greedy tastes are
  id tables (`RUNE_SCORE`, `KIND_SCORE`, `PASSIVE_SCORE` `:8-27`; `bot_meta.gd:274,283-293`).
- **Presentation keys on event types and ids.** `EventPlayer._one` matches on event `type`
  (`event_player.gd:57`). `ClassBeats.class_triggered` matches on mechanic event ids
  (`game/classes/class_beats.gd:136`). Twist beats key on twist event types (`twist_beats.gd`).
- **Saves and state** hold rule bookkeeping under ad-hoc keys: `run.passive_state`
  (`phoenix_act`, `second_wind_used`, `sanctify`), `run.item_state`, `CombatState.item_state`
  (`uses_<item>`, `rampage`, `spark`, `chill`…), per-mechanic fields on `CombatState` (`oath`,
  `moon`, `bones_raised`, `wisp_free`…) (`combat.gd:29-56`).

---

## 2. The vocabulary

### 2.1 Principles

- **Closed and typed.** Every hook, variable, operator, effect op, selector and native primitive is a
  name the core publishes, with a version (`caps`, §6.8). Data can only reference names the core
  knows. Unknown names fail validation, and at runtime the set is dropped (never a silent default:
  today an unknown potion silently heals, `game_flow.gd:1698`).
- **Declarative and non-Turing-complete.** There are no loops except the engine's bounded iteration
  over fixed collections (the dice pool ≤ 7, enemies ≤ ~6, board ≤ 32 tiles), no recursion, no
  user-defined functions, no strings evaluated as code, no `Expression`. Expression depth is ≤ 8;
  `repeat` ≤ 8; hook re-entrancy depth ≤ 6 (damage → kill → heal → …); `invoke` targets only
  same-owner sub-rules, is acyclic and depth 1. The validator proves termination statically
  (§6.5).
- **Deterministic.** Rules run in a total order (hook, stage, priority, owner order, rule index).
  Randomness comes only from named, seeded streams. Floats combine in declared order. Integer casts
  are explicit.
- **Data owns numbers and composition; code owns primitives.** A primitive is anything with an
  algorithm (combo detection, move selection, board generation, damage resolution, an intent's
  execution, a UI flow, a minigame). Data calls primitives by name with parameters.
- **One engine for all domains.** Passives, items, runes, pets, classes, biomes, tiles, enemies,
  affixes, ascension keys, events, potions and modifiers are all **owners** of rules. Only the owner
  *kind* differs: how an owner becomes active, and where its parameters and state live.

### 2.2 Rule shape

```jsonc
{
  "id": "twin_edge",                 // unique within the owner (trace, limits, caps, balance patches)
  "on": "attack.mods",               // trigger (hook) from the catalogue (§2.3)
  "prio": 310,                       // order within the hook; engine publishes bands per domain
  "let": {"k": <value>},             // optional named sub-expressions, evaluated once, in order
  "if": <condition>,                 // optional
  "limit": {"per": "fight", "max": {"param": "uses"}, "group": "twin_edge"},
  "chance": <value 0..1>,            // drawn from the owner's RNG stream after `if` and `limit`
  "do": [ <effect>, ... ],           // closed op set (§2.5); each effect may carry its own "if"
  "announce": {"effect": "twin_edge", "value": "$result", "extra": {"enemy_idx": "$target"}, "fx": "slash"},
  "stop": false,                     // first-wins chains (e.g. hero.lethal, rune.times)
  "repeat": {"var": "rune.times"}    // bounded (<= 8): Ember fires once per trigger
}
```

Owners carry `params` (numbers, tier arrays `[I, II, III]`, level arrays `[L1..L10]`, or
`{"lin": [base, per_level]}`), `resources` (§2.8), `rules`, and presentation and bot blocks (`look`,
`text`, `ai`). The engine resolves an owner *instance* (the equipped tier and variant, the pet level,
the die carrying a rune, the enemy index) and **folds its parameters into constants when it builds
the dispatch table**, so `{"param": "flat"}` costs nothing at run time.

`announce` is sugar for "emit this owner's trigger event, then the effects' events". Values bind to
`$result` (the first effect's computed value), `$value` (a query's output) or `$target` (the
resolved target). Explicit `{"op": "emit"}` covers custom ordering (the Warcamp drum emits
`board_mutated`, then `drum_smashed`, then `gold_changed`).

Syntax is JsonLogic-shaped: single-key objects whose value is the operand list, e.g.
`{"in": [{"var": "combo.id"}, ["pair", "two_pair"]]}`. `and`/`or` are accepted as aliases of
`all`/`any`.

### 2.3 Triggers (hook catalogue v1)

Each hook declares its **context** (what `var`s exist), whether it is a **pipeline** (effects write
accumulators) or a **query** (pure: `set_value` only, cacheable, the bot may call it) or an
**event** (side effects allowed), and which effect groups are legal there. About 60 hooks cover
today's content. Payload variables are listed; common variables (§2.4) are always available.

| Hook | Kind | Fires at (today's site) | Payload vars |
|---|---|---|---|
| `run.start` | event | after `RunState.create` / `apply_start` (`run_state.gd:144`) | — |
| `run.end` | event | `_finish` (`game_flow.gd:735`) | `victory` |
| `owner.gained` | event | passive gained, item equipped at start, pet assigned, rune assigned (`game_flow.gd:868,905`) | `owner`, `replaced` |
| `board.generated` | event | `after_board_generated` (`run_state.gd:166`) | `protect[]` |
| `board.roll` | event | `_do_board_roll` after the move is selected (`game_flow.gd:146`) | `values[]`, `pair_value`, `double` |
| `board.reroll` | event | `board_reroll` (`:126`) | `double` |
| `board.move` | event | `confirm_move` before moving (`:282-300`) | `moving[]`, `steps`, `double`, `pair_value` |
| `tile.pass` | event | per passed tile in `_move` (`:343-354`) | `tile.idx`, `tile.kind` |
| `tile.land` | event | `_trigger_tile` (`:452`), dispatched to the **tile kind's** rules | `tile.*` |
| `lap.completed` | event | crossing Start (`:355-372`) | `lap`, `final` |
| `lap.start` / `lap.mutation` | event | after the lap mutation (`:376-386`) | `changes[]` |
| `biome.start` | event | `_new_biome` (`:783-810`) | `biome`, `act` |
| `fight.setup` | event | `begin` before intents (`combat.gd:82`) | `fight.kind`, `enemies[]` |
| `fight.start` | event | `begin` after intents (`:106-107`) | as above |
| `turn.before` | event | `start_turn` before sizing (`:249`) | `turn` |
| `turn.setup` | event | after block/reroll reset (`:261-280`) | `turn`, `prev_block` |
| `turn.rolled` | event | after the roll (`:310-312`) | `turn`, `values[]` |
| `reroll` | event | `reroll` (`:350-356`) | `rerolled[]`, `count`, `mult_before`, flag `refunded` |
| `attack.begin` | event | `attack` start (`:438`) | `combo.preview.*` |
| `attack.combo_mult` | pipeline `mult` | `:447-457` | `combo.*` |
| `rune.times` | pipeline `times` (per die) | `:459-469` | `die.*` |
| `rune.active` | predicate (per die) | `rune_active` (`:408`) | `die.*` (the rune's `when`) |
| `attack.dice` | pipeline `pips/bonus/mult` (per die) | `:486-513` | `die.*`, `rune.times` |
| `attack.pips` | pipeline `bonus/flat` | `:514-530` | `combo.*` |
| `attack.mods` | pipeline `mult/bonus/flat/factor` | `attack_mods` (`:533`) | `combo.*`, `target.*` |
| `attack.factor` | pipeline `factor` | `:545-551` | `combo.*` |
| `attack.pre_hit` | event | `:564` | `target.*`, flags |
| `hit.main` | event | `:567-580` (after the main hit) | `total`, `soak`, `overkill`, `killed`, `target` |
| `rune.after_hit` | event (per active die) | `:582-600` | `die.*`, `times` |
| `attack.after_runes` | event | `:601-614` | `combo.*` |
| `rune.after_attack` | event (per active die × times) | `:617-658` | `die.*`, `killed` |
| `attack.after` | event | `:659` | `attack_target` |
| `attack.resolved` | event | `:660` | `combo.*`, `values[]`, `runes_fired[]` |
| `attack.end` | event | `:661` | — |
| `damage.enemy` | query `amount` | `damage_enemy` before block (`:676-686`) | `enemy`, `source` |
| `enemy.killed` | event | lethal branch (`:696-718`) | `enemy`, `source`, `overkill` |
| `enemy.hp_threshold` | event | transform / phase checks (`:719-732`) | `enemy`, `hp_pct` |
| `boss.phase` | event | `_boss_phase2` (`:737`) | `enemy`, `forced`, `source` |
| `enemy.turn_start` | event | block decay and poison tick (`:795-810`) | `self` |
| `enemy.before_action` | event | `_affix_before_action` (`:908`) | `self`, `actions` |
| `intent.rolled` | query `intent` | `roll_intent` (`:212-241`) | `self`, `entry` |
| `hero.incoming` | query `amount` | `_hit_hero` (`:868`) | `attacker`, `pierce` |
| `hero.damaged` | event | `_hit_hero` after damage, hero alive (`:886-893`) | `attacker`, `dealt`, `blocked`, `block_before` |
| `hero.lethal` | first-wins | `survive_lethal` (`run_state.gd:384`) | `hp_before` |
| `block.gained` | event | hero Block from item/rune/pet (`item_logic.gd:94`, `combat.gd:638`) | `amount`, `source` |
| `status.tick` | query | poison tick, hero burn tick (`combat.gd:799`, `:839`) | `status`, `self`, `stacks` |
| `enemy_phase.end` | event | `:830-834` | — |
| `fight.won` | event | `_win` and `_on_combat_won` (`combat.gd:1029`, `game_flow.gd:645`) | `fight.kind` |
| `reward.gold` / `reward.xp` | query | `_win` (`combat.gd:1041-1049`) | `enemy` |
| `shop.open` | event + queries | `_open_shop`/`_shop_stock` (`game_flow.gd:995-1043`) | — |
| `query.shop_price` | query | `_shop_item` (`:1093-1098`) | `item.kind`, `item.*` |
| `query.restock_price`, `query.shop_items`, `query.free_restocks`, `query.shop_kind_weights` | query | `:1001-1020`, `:1568` | — |
| `query.chest_gold`, `query.chest_choices`, `query.chest_rune_chance` | query | `:470-482` | — |
| `query.campfire_heal`, `query.lap_heal`, `query.biome_heal`, `query.potion_heal` | query | `:486-493`, `run_state.gd:300-307` | — |
| `query.dodge_min`, `query.dodge_bonus`, `query.hazard_mult` | query | `:1600-1605`, `run_state.gd:310` | `tile.kind` |
| `query.board_rerolls`, `query.move_tiebreak`, `query.portal_range`, `query.forge_uses`, `query.max_dice`, `query.transform_at`, `query.treasury_cashout` | query | various | — |
| `potion.drink` | event | `_drink` (`:1675`) | `potion`, `source` |
| `event.open` / `event.choose` | offer | `_open_event`, `event_choose` (`:1243`, `:1293`) | `choice.*` |
| `offer.options` | query | drafts, rewards, signatures (`:816`, `:1779`) | `offer.kind`, `tier` |
| `pet.fire` | event | resource-threshold dispatch (§2.8) | — |

The stage names (`attack.combo_mult` → `attack.dice` → `attack.pips` → `attack.mods` →
`attack.factor`) fix the damage-formula semantics. Within a stage, **priority bands** reserve room
per domain, for example 0–99 passives, 100–199 class, 200–299 pets, 300–499 items, 500–599 enemy and
biome, 900+ modifiers. Priorities default to today's code order, so migration is behaviour-neutral.

### 2.4 Conditions and values

**Operators** (all compile to one node class each; the prototype measured 0.1–0.2 µs of dispatch
per node plus the work):

| Group | Operators |
|---|---|
| Logic | `all` (`and`), `any` (`or`), `not`, `if` (ternary `[cond, a, b]`) |
| Compare | `eq`, `ne`, `lt`, `lte`, `gt`, `gte`, `between` `[x, lo, hi]`, `in` `[x, list]`, `has` `[list, x]` |
| Arithmetic | `add`, `sub`, `mul`, `div` (float), `idiv` (int), `mod`, `min`, `max`, `neg`, `abs`, `sign` |
| Casts | `floor`, `round`, `trunc`, `ceil` (explicit; required before int-typed effects) |
| Domain helpers | `pct_of_max_hp` `[pct]`, `lap_scale` `[step]` (1 + step × (lap − 1)), `gold_scale`, `gold_bonus` `[amount]` (the Charm %), `roll` `[n, sides]` (from the owner stream), `query` `[hook, base]` (runs a query pipeline), `biome_param` `[key]`, `die_var` `[die, field]`, `die_faces_eq` `[value]` (v1.1) |
| Lists | `sum`, `count`, `concat`, `map_max` `[list, floor]`, literal lists |
| Leaves | numbers, strings, bools, literal lists; `{"var": name}`, `{"param": key}`, `{"sec": key}`, `{"res": name}`, `{"flag": name}`, `{"asc": key}`, `{"arg": name}` (invoke arguments), `{"native": name}` (named native value, §2.9) |
| Aggregates over selectors | `{"count_dice": filter}`, `{"sum_dice": {filter, "of": "pips"}}`, `{"count_enemies": filter}`, `{"board_count": kind}`, `{"pick_die": selector}` → index or −1, `{"pick_enemy": selector}`, `{"pick_face": selector}` |

**Closed variable set** (versioned like ops; about 90 names):

- **Combat**: `turn`, `attack.index` (nth attack this fight), `fight.kind` (regular | elite | miniboss | boss),
  `fight.all_dead`, `enemies.count`, `enemies.alive`, `rerolls_left`, `rerolls_used`, `pool.size`,
  `pool.base_size`, `pool.runed`.
- **Combo**: `combo.id`, `combo.mult`, `combo.base_mult`, `combo.group_size`, `combo.sum`,
  `combo.set_value`, `combo.preview.mult`, `combo.preview.values`, `mult_before`.
- **Hit**: `total`, `soak`, `overkill`, `killed` (count this attack), `dealt`, `blocked`,
  `block_before`, `hp_before`.
- **Die** (per-die hooks and selectors): `die`, `die.eff`, `die.shown`, `die.face`, `die.rune`,
  `die.rune_active`, `die.kind`, `die.tags`, `die.rerolled`, `die.locked`, `die.in_group`, `die.cap`,
  `die.temp`, `die.pips`, `rune.times`.
- **Enemy** (`self`, `target`, `attacker`, `enemy`): `.hp`, `.max_hp`, `.hp_pct`, `.block`,
  `.poison`, `.frozen`, `.phase`, `.form`, `.intent.kind`, `.intent.value`, `.atk_bonus`, `.traits`,
  `.affixes`, `.tags`, `.boss`, `.elite`, `.miniboss`, `.summoned`, `.alive`, `.actions`.
- **Hero and run**: `hero.hp`, `hero.max_hp`, `hero.hp_pct`, `hero.block`, `gold`, `atk`, `level`,
  `lap`, `act`, `biome`, `biome.lap_pos`, `biome.phase`, `biome.phase_next` (from the biome's `phases` table), `biome.trap_tile`, `twist`, `run.route`, `run.mode`, `run.class`, `asc`,
  `boss_stage`, `pet.level`, `run.minibosses_killed`, `stats.<counter>`.
- **Board**: `tile.idx`, `tile.kind`, `tile.dist_hero`, `pos`, `treasury`.
- **Query**: `value` (the value being piped); also `item.kind` in shop queries.

### 2.5 Effects (closed op set v1)

Each op has a typed parameter schema and a list of hook kinds where it is legal. For example,
pipeline ops only run on pipeline hooks, and state-changing ops are illegal on query hooks.

| Group | Ops |
|---|---|
| Pipeline accumulators | `mult_add`, `mult_floor`, `bonus_add`, `flat_add`, `factor_mul`, `pips_mult` (per die, Heavy), `times_set` (rune triggers), `set_value` (queries), `weights_mul` (weight tables) |
| Hero | `heal`, `heal_pct`, `damage_hero` (`never_lethal`, `pierce`), `block`, `max_hp_add` (`heal`), `atk_add`, `gold`, `xp`, `survive` (first-wins on `hero.lethal`), `status_hero` (burn/chill/curse add or clear), `cleanse`, `lock_dice` (n, random from stream), `unlock_die` |
| Enemies | `damage` (to, amount, source, `ignore_block`), `heal_enemy`, `status` (poison, freeze, cower, weaken, brave…), `strip_block` (pct or amount), `block_enemy`, `atk_add` (`cap: "atk_bonus_cap"`, rally/buff), `trait_add`, `trait_remove`, `set_intent`, `roll_intent`, `intent_event`, `transform`, `boss_phase`, `summon` (id, n, cap), `flee` (gold share), `kill` |
| Dice | `reroll_dice` (selector), `set_face` (die, face, value, `source`), `raise_face` (die selector, face selector, n), `mirror_face`, `curse_face` (until forge or until fight end), `add_temp_die` (kind, tags, join now/next turn, caps), `remove_temp_dice` (tag), `add_die` (kind), `reforge_die` (idx, kind), `assign_rune` (die, rune or a `draw` from the rune pool), `tag_die` |
| Rerolls | `rerolls_add` (this turn), `bank_reroll` (cap), `combat_rerolls_add` (permanent, cap), `board_rerolls_add` |
| Board | `convert_tiles` (selector → kind), `place_tile` (kind, placement selector), `consume_tile`, `spawn_fight` (tile, pool), `treasury_add`, `queue_move` (v1.1) |
| Offers and flow | `offer_draft` (source: rune_choice n / rarity floor / kinds), `offer_passives` (tier, n, exclude), `offer_forge` (ops, uses), `offer_choice` (an inline event), `open_shop`, `start_minigame`, `gain_potion` (type or draw), `start_combat` (v1.1: second boss) |
| Resources | `res_add` (floor/cap, `skip_zero`), `res_set`, `res_event` |
| Pets | `pet_charge` (n), `pet_reset` |
| Meta | `stat_add` (a declared counter, keyed: `{"counter": "biome_visits", "key": "frost"}`), `record_seen` |
| Control | `emit` (custom event with fields), `show` (presentation-only fx event), `schedule` (v1.1), `invoke` (same-owner sub-rule, acyclic), `native` (call a named native primitive with params, §2.9) |

Flags on any effect: `if` (a per-effect condition), `skip_zero` (a zero value cancels the rule: no
announce, no limit use; this replaces the duplicated "if count > 0" guards and was used in the
prototype), `as` (names the result for later effects), `source` (event source label).

### 2.6 Targets and selectors

- **Enemies**: `"target"`, `"self"`, `"attacker"`, `"killed"`, `{"enemies": "all"}` (alive-checked at
  each application, like the native loops), `{"enemies": "others"}`,
  `{"enemy": "next_alive", "after": "target"}`, `{"enemy": "random", "except": "target"}` (owner
  stream), `{"pick_enemy": {"where": cond, "by": "hp" | "intent.value", "order": "max"}}`, plus filters
  `boss`, `elite`, `summoned`, `has_status`, `trait`, `tag`.
- **Dice**: `{"dice": {filters}, "pick": "all" | "first" | "lowest" | "highest" | "random", "n": k, "by": "eff" | "shown" | "face_sum" | "lowest_face"}`.
  Filters: `in_group`, `eff`, `shown`, `eff_lte`, `runed`, `rune`, `rune_not`, `rune_active`,
  `rerolled`, `locked`, `kind`, `tag`, `temp`, `base_pool`, `pretend`. Ties resolve to pool order,
  as every native loop does today.
- **Faces**: `{"pick_face": {"die": d, "where": cond, "by": "value", "order": "min"}}`, plus
  `lowest`, `highest`, `random_raisable`.
- **Tiles**: `"current"`, `{"tiles": "next_of_kind", "kind": "empty", "n": 3}`,
  `{"tiles": "kind", "kind": "empty", "not_corner": true, "min_index": 3, "min_dist_hero": 4, "exclude": "protect"}`
  with `pick: "random"`, and `{"first_of": [sel1, sel2, sel3]}` for fallback placement (v1.1, the
  moon chest).

### 2.7 Limits, chance, priority, stop, repeat

- `limit`: `per` ∈ `turn | fight | lap | biome | act | run`, `max` (a value; ≤ 0 = unlimited),
  `group` (a counter shared by several rules; the Arming Sword's base rule and the Rapier share
  "twin_edge"). Several limits may stack (Steadfast: once per turn **and** `uses` turns per fight).
  State lives in `CombatState.rule_state` or `RunState.rule_state` under
  `"<owner_kind>:<owner_id>:<group>"`. A `legacy_key` shim maps today's keys (`phoenix_act`,
  `second_wind_used`, `uses_sword`, `chill`…) during migration; the prototype does exactly this.
- `chance`: evaluated **after** `if` and `limit` (today's short-circuit order); draws from the
  owner's stream.
- `prio`: total order within a hook; ties go to owner order (kind order, then slot order, then
  acquisition order), then rule index.
- `stop`: the first rule that fires ends the hook (first-wins chains).
- `repeat`: bounded (≤ 8) value; the body runs `n` times (Ember per trigger).

### 2.8 Resources: named counters with thresholds

A resource is a typed integer (or small float) owned by an owner instance, with a scope and bounds:

```json
"resources": {
  "moon":   {"scope": "fight", "min": 0, "max": {"param": "max"}, "event": "moon_meter",
             "ui": {"meter": "moon", "icon": "moon", "color": "#c8d4ff"},
             "ai": {"threat": {"full_cost": {"param": "fall"}}, "counter": {"dice_shown": 1, "per_turn": {"param": "clouds_max"}}}},
  "charge": {"scope": "run", "max": {"param": "size"}, "ui": {"meter": "pet"}},
  "oath":   {"scope": "fight", "ui": {"badge": "OATH {v}"}},
  "raised": {"scope": "fight"}, "pending": {"scope": "fight"},
  "stacks": {"scope": "fight", "keyed_by": "target"}
}
```

- **Scopes**: `turn` (reset in `turn.setup`), `fight`, `lap`, `biome`, `run`. `keyed_by: "target"`
  gives one counter per enemy index (Rampage).
- **Ops**: `res_add` / `res_set` / `res_event`; `{"res": name}` reads. Threshold behaviour is written
  as ordinary rules with `gte` conditions and priorities (the prototype's Moonrise/Moonfall), or as
  sugar: `"thresholds": [{"at": {"param": "max"}, "do": [...], "reset": true}]`.
- **Presentation**: the `ui` block drives one generic **meter/badge widget** (the Moon King's meter,
  the Oath badge, bone count, pet charge, rampage pips). This replaces per-mechanic HUD code for new
  content.
- **Migration**: `bind` maps a resource onto an existing field (`CombatState.moon`, `oath`,
  `bones_raised`, `run.pet_state.charge`), so today's bot and presentation keep reading the same
  place. The prototype binds the moon meter to `CombatState.moon`.

This one concept expresses class mechanics (Oath value, Bone Harvest counters, Druid seeds as die
tags plus counts), boss meters, pet charge, item stacks (Rampage, Dominion, Soul, Ambush primed) and
twist state (Ruins' "cooled this lap").

### 2.9 Native primitives (called from data by name and params)

Values: `pool_mode_face` (the Oath value; `ClassLogic.oath_of` `class_logic.gd:123`),
`combo.set_value` (`ItemLogic.set_value` `item_logic.gd:178`), `rerolled_match`
(`ClassLogic.rerolled_match` `:237`), `pretend_board_value` (`:352`), `combo.preview` (the current
combo without resolving), `moon_ones`-style counts (expressible as `count_dice`), `lap_scale`,
`gold_scale`, `enemy_scale`.

Effects and flows: `refire_rune` (Grimoire, `pet_logic.gd:241`), `pick_move_dice`
(`game_flow.gd:176`), `board.generate`/`mutate` (`board.gd:130,257`, parameterised by data),
`combo.evaluate` with the wildcard rules (`combo.gd:29`), damage resolution `damage_enemy`, hero
damage `_hit_hero` + `survive_lethal` ordering, the intent execution ops, status ticks, the offer UI
flows and minigame state machines.

### 2.10 Queries versus events

Queries (`query.*`, `damage.enemy`, `hero.incoming`, `intent.rolled`, `reward.*`, `status.tick`) are
value pipelines. They start from the native base value, apply `set_value` rules in priority order,
and may announce (Treasure Sense announces its new chest gold) but not change state. Because they
are pure, the **bot uses the same queries** instead of copying rules. Today `bot.gd:2326` copies
"Glade campfire 45 %"; it would instead call `Rules.query(run, "query.campfire_heal", base)`. Event
hooks may change state and emit events.

### 2.11 Presentation and bot blocks on owners

```json
"look": {"icon": "pair", "fx": {"twin_edge": "slash_small"}, "color": "#e0a030"},
"text": {"name_key": "passive.pair_master.name", "desc_key": "passive.pair_master.desc"},
"ai":   {"cat": "dmg", "score": 7, "pv": {"model": "auto"}}
```

The engine emits a generic announce (`rule_triggered {kind, id, rule, effect, value, target, fx}`).
During migration it keeps today's shapes (`passive_triggered`, `item_triggered`, `rune_fired`,
`class_triggered`, `pet_acted`). Presentation gets a generic beat keyed by the `fx` hint (§5).

### 2.12 Small generic additions (v1.1) that today's content needs

| Addition | Needed by | Size |
|---|---|---|
| `schedule` (delayed effects at a later hook in scope: next `turn.setup`, next `fight.start`) | Stoneskin, Guard Die L5 | S |
| `queue_move` (bonus move after landing, not before a boss) | Fast Feet | XS |
| `status.tick` / decay query | Lantern Ghost L5 (poison doesn't decay on bosses), Wick perk (burn −1) | S |
| `free_reroll` (the next reroll doesn't mark dice rerolled) | Crystal Wisp L10 | XS |
| **side dice** (dice outside the pool: roll after attack, own rune subset) | Engineer's Turret | M |
| `first_of` placement selector | Moonlit moon chest | XS |
| `start_combat` flow op | A10 double boss | S |
| `rune.times[]` read and "first active rune" | Wizard Hat Arcana | XS |
| face-count selectors (`die_faces_eq`) | Paladin Sanctify | XS |
| `invoke` (same-owner sub-rule, acyclic) | Bone Harvest "raise" from three triggers | XS |
| combo pattern specs (`{"sets": [3, 2]}`, `{"run": 5}`) | only *new* combos (optional) | M |

---

## 3. Entity shapes per domain

Every entity is an **owner** in the defs catalog (distribution design §4.3: sets, `add`/`patch`/
`edit`/`retire`, ledger ids). The common envelope is:

```jsonc
{"id": "…", "params": {…}, "resources": {…}, "rules": [ … ], "look": {…}, "text": {…}, "ai": {…},
 "tags": […], "unlock": {…}}
```

Balance sets patch `params` only. Rule structure (`on`, ops) is an identity field; changing it
means a new rule id. Each shape below lists what the engine activates and where state lives.

| Domain | Owner activation | Shape (beyond the envelope) |
|---|---|---|
| **Items** (weapon, offhand, head, body, trinket, back) | equipped slot with tier ≥ 1 (`MetaRun.build`), variant selected | `slot, hands, mount, style, affinity[], std: {kind: "x1.2"\|"block2", scale: {key: "round"\|"bonus_part"\|"mul"\|"mul_snap"}}, params: {key: [I,II,III]}, rules, variants: {vid: {sec, params_set, params_add, rules, stats: {max_hp}, hands, style, unlock, look}}, price, kit_for[], buyable, text: {desc_key, desc_args}`. Today's special cases become fields: `hammer_mallet` style, `spear` boss factor text arg, `dino_suit` not buyable, the Arcane Staff counting as Necromancer kit (`items.gd:546,629,705,710`) |
| **Passives / relics** | `run.passives` | `rarity` (common…boss), `pools` (Workshop packs), `economy: bool` (kept out of rewards), params, rules (incl. `owner.gained` for Glass Cannon/Collector/Extra Hand/Rune Bloom) |
| **Runes** | the die carrying it (rune rules run per die) | `rarity, color, when: <die predicate>, cap: 2, no_double, wild: bool, side_die_ok (Turret), rules (rune.dice / rune.after_hit / rune.after_attack / board.move), refire: [effects]` (for Grimoire) |
| **Dice kinds** | die kind | `faces[6], cap, rarity, price, class_only, face_flags: {"5": "pretend"}` |
| **Pets** | loadout pet with level | `role, size, resources: {charge}, charge: [rules], fire: {at: "attack.begin"\|"turn.rolled"\|"fight.won", rules}, perks: [rules], params with by-level arrays, look: {builder}` |
| **Potions** | belt entry | `combat_only, icon, rules on potion.drink` |
| **Affixes** | enemy spawn roll | `trait?, exclude[], group, reward: {gold, xp}, rules` (enemy-owned: `enemy.before_action`, `intent.rolled`, `enemy.killed`, spawn stats) |
| **Heroes / classes** | run class | `hp, atk, dice: [{kind, rune, tags}], board_rerolls, combat_rerolls, mechanic, mechanic_params (per-class overrides: fixes the "PALADIN_* are global" issue, audit §1.2), style, secret, unlock_order, kit, skins` |
| **Class mechanics** | via the class | `resources, params, rules, ui: {badge, meter}, ai` |
| **Enemies / mini-bosses / bosses** | in the fight (per-fight index, rebuilt on summon) | `hp, gold, xp, tags[] (e.g. "skeleton", replacing ItemDefs.SKELETONS), mode, pattern[] / phases[][], forms[], transform: {at, drop_block}, traits[] (per phase for bosses), summon, resources, rules, unlockable: bool` |
| **Intents** | referenced by patterns | `telegraph (look), scale: "atk"\|"block"\|"burn"\|"none", do: [enemy ops]` (§4.10) |
| **Biomes / maps** | the current act's biome | `tier, order, mix{}, trap_tile, pools[[early],[late]], elite, minibosses[], bosses[], short_bosses[], short_boss_hp, mutate_elites, refill{}, phases (e.g. moon by lap position), params, rules (active while current), affixes: {weights, gilded}, counters: ["visits","wins","events"], look: {kit \| spec, sky, palette, music}` |
| **Tile kinds** | board tiles | `corner, consumable, not_near_start, twist, rules (tile.land / tile.pass), look: {style, icon, prop}, ai: {value}` |
| **Twists** | biome rules (no separate kind) | old twists become biome rules; new twists are biome rules plus owned tile kinds |
| **Events** | event tile draw (weighted, optionally biome-scoped) | `weight, biomes[], available: cond, text, choices: [{label_key, args, desc_key, enabled, upgrade, let, do}], look: {art}` |
| **Shop / draft / reward tables** | the offer builders | `shop_items: {id: {weight, needs_die, price, available, max_per_stock, do}}`, `draft_options`, `reward_tiers: {bronze: [...], silver: [...], gold: [...]}`, `signatures: {id: option}` |
| **Ascension keys, daily/season modifiers** | `meta.asc_keys`; a modifier list pinned by the run | `level, desc_key, params, rules`; modifiers: `active: {daily: date} \| {season: id}` |
| **Minigames** | loadout tile | `template, params, median, calibration, rewards, signature, look: {props, board}` (§3.1) |
| **Unlocks / milestones / feats / skins** | profile | conditions over keyed counters (`{"counter": "biome_visits", "key": "frost", "min": 1}`) |
| **Camp upgrades** | profile | `track, cost, requires, rules on run.start` (Whetstone forge offer, Starter Kit die kind, belt cap, loadout slots) |

### 3.1 Minigames: what can be data

The eleven games are state machines in code (`core/minigames/*.gd`, factory `minigames.gd:17`) with
their own props (`game/minigames/props/*`) and boards (`ui/minigames/*`). Already data (or trivially
so): numbers, `MEDIAN`, calibration, skill band, reward tiers, signatures (`game_flow.gd:1779-1895`),
mastery. Four families would each work as a **template** parameterised by data, so that a new game in
the family is data plus a prop skin:

| Template | Today's members | Data parameters |
|---|---|---|
| `grid_reveal` | Fossil Hunter, Scratch-off, Memory Match | grid size, hidden contents distribution, actions, scoring table (pairs/sets/adjacency), reveal rules |
| `push_your_luck` | High-Low Ladder | prize ladder, safe rungs, the random source (d6, card, coin), guess types |
| `spin_stop` | Lucky Wheel, (Fishing) | segments and values, spin count, brake window |
| `drop_board` | Plinko | peg layout, buckets, drops, golden peg |

Claw Machine, Bubble Breaker, Bubble Shooter and Shell Game are bespoke (physics, aim, animation).
A new *template* is code: rules, UI board, prop builder, bot play function
(`BotMeta.play_args` `bot_meta.gd:132`).

---

## 4. Coverage: today's content re-expressed

Verdicts: **Full (v1)** = the core vocabulary of §2.1–2.11 expresses it; **Full (v1.1)** = needs
one of the small generic additions of §2.12; **Native** = stays a named native primitive. ✔ marks
entries that the prototype actually ran through the A/B goldens.

### 4.1 Weapons

**Arming Sword + 5 variants ✔ Full (v1).** This is the JSON the prototype ran; the item metadata is
abbreviated.

```json
"sword": {
  "slot": "weapon", "hands": 1, "style": "melee_1h", "affinity": ["knight"],
  "std": {"kind": "x1.2", "scale": {"flat": "round"}},
  "params": {"flat": [1, 1, 1], "uses": [1, 1, 1]},
  "rules": [
    {"id": "twin_edge", "on": "attack.mods", "prio": 310,
     "if": {"in": [{"var": "combo.id"}, ["pair", "two_pair"]]},
     "limit": {"per": "fight", "max": {"param": "uses"}, "group": "twin_edge"},
     "do": [{"op": "flat_add", "v": {"round": {"param": "flat"}}}],
     "announce": {"effect": "twin_edge", "value": "$result"}}
  ],
  "variants": {
    "sword_rapier": {"sec": "precision", "params": {"share": 0.5}, "unlock": {"feat": "high_rollers_200"}, "rules": [
      {"id": "precision", "on": "attack.mods", "prio": 311, "if": {"eq": [{"var": "combo.id"}, "high_roller"]},
       "limit": {"per": "fight", "max": {"param": "uses"}, "group": "twin_edge"},
       "do": [{"op": "flat_add", "v": {"max": [1, {"floor": {"mul": [{"param": "flat"}, {"sec": "share"}]}}]}}],
       "announce": {"effect": "twin_edge", "value": "$result"}}]},
    "sword_saber": {"sec": "slash", "params": {"pct": 0.25}, "unlock": {"mastery": 90}, "rules": [
      {"id": "slash", "on": "hit.main", "prio": 200, "if": {"eq": [{"var": "combo.id"}, "pair"]},
       "do": [{"op": "damage", "to": {"enemy": "next_alive", "after": "target"}, "source": "item",
               "v": {"floor": {"mul": [{"var": "total"}, {"sec": "pct"}]}}}],
       "announce": {"effect": "slash", "value": "$result", "extra": {"enemy_idx": "$target"}}}]},
    "sword_flame": {"sec": "burning", "params": {"dmg": 3}, "unlock": {"feat": "cinder_king_sword"}, "rules": [
      {"id": "burning", "on": "hit.main", "prio": 500,
       "if": {"all": [{"in": [{"var": "combo.id"}, ["pair", "two_pair"]]}, {"gt": [{"count_dice": {"in_group": true, "eff": 6}}, 0]}]},
       "do": [{"op": "damage", "to": {"enemies": "all"}, "source": "item",
               "v": {"mul": [{"count_dice": {"in_group": true, "eff": 6}}, {"sec": "dmg"}]}}],
       "announce": {"effect": "burning", "value": "$result"}}]},
    "sword_frost": {"sec": "chill", "unlock": {"feat": "frost_warden_sword"}, "rules": [
      {"id": "chill", "on": "hit.main", "prio": 510,
       "if": {"all": [{"eq": [{"var": "combo.id"}, "pair"]}, {"var": "target.alive"}, {"in": [{"native": "combo.set_value"}, [1, 2]]}]},
       "limit": {"per": "fight", "max": 1},
       "do": [{"op": "status", "status": "freeze", "to": "target", "source": "item"}],
       "announce": {"effect": "chill", "value": 1, "extra": {"enemy_idx": "$target"}}}]},
    "sword_knight": {"sec": "guarded", "params": {"block": 2}, "unlock": {"mastery": 45}, "rules": [
      {"id": "guarded", "on": "hit.main", "prio": 520, "if": {"eq": [{"var": "combo.id"}, "pair"]},
       "do": [{"op": "block", "v": {"sec": "block"}, "via": "item", "effect": "guarded"}]}]},
    "sword_training": {"sec": "lesson", "params": {"rerolls": 1, "dice": 3}, "unlock": {"mastery": 15}, "rules": [
      {"id": "lesson", "on": "turn.setup", "prio": 301, "if": {"all": [{"eq": [{"var": "turn"}, 1]}, {"lte": [{"var": "pool.base_size"}, {"sec": "dice"}]}]},
       "do": [{"op": "rerolls_add", "v": 1}], "announce": {"effect": "lesson", "value": 1}}]}
  }
}
```

**Warhammer + 5 variants: Full (v1). This is the tricky one: a *selected die*, a flag read by
three later hooks, and variants that only change params.** It reproduces `crush_die`/`crush_mult`
(`item_logic.gd:192-209`), `attack_mods` Crush (`:428-439`), `pre_hit` Bonebreak (`:563-572`) and
the Crush secondaries (`:614-625`).

```json
"warhammer": {
  "slot": "weapon", "hands": 1, "style": "melee_1h", "affinity": ["paladin"],
  "std": {"kind": "x1.2", "scale": {"crush": "bonus_part"}},
  "params": {"crush": [1.15, 1.2, 1.25], "uses": [1, 1, 1],
             "tempered_pip": 0, "spikes_dmg": 0, "rend_poison": 0, "bonebreak_pct": 0},
  "rules": [
    {"id": "crush", "on": "attack.mods", "prio": 340,
     "let": {"k": {"pick_die": {"dice": {"in_group": true, "eff_between": [1, 9],
                                         "not": {"all": [{"eq": [{"var": "die.rune"}, "heavy"]}, {"var": "die.rune_active"}]}},
                                "pick": "highest", "by": "eff"}},
             "pips": {"die_var": [{"var": "k"}, "eff"]}},
     "if": {"gte": [{"var": "k"}, 0]},
     "limit": {"per": "fight", "max": {"param": "uses"}},
     "do": [{"op": "flat_add", "skip_zero": true,
             "v": {"add": [{"floor": {"add": [{"mul": [{"var": "pips"}, {"sub": [{"param": "crush"}, 1]}]}, 0.0001]}},
                           {"if": [{"eq": [{"var": "pips"}, 6]}, {"param": "tempered_pip"}, 0]}]}},
            {"op": "set_flag", "name": "crush_die", "v": {"var": "k"}}],
     "announce": {"effect": "crush", "value": "$result", "extra": {"die_idx": {"var": "k"}}}},
    {"id": "bonebreak", "on": "attack.pre_hit",
     "if": {"all": [{"gt": [{"param": "bonebreak_pct"}, 0]}, {"flag": "crush_die"}, {"gt": [{"var": "target.block"}, 0]}]},
     "do": [{"op": "strip_block", "to": "target", "skip_zero": true,
             "v": {"floor": {"mul": [{"var": "target.block"}, {"param": "bonebreak_pct"}]}}}],
     "announce": {"effect": "bonebreak", "value": "$result", "extra": {"enemy_idx": "$target"}}},
    {"id": "spikes", "on": "hit.main", "prio": 450, "if": {"all": [{"gt": [{"param": "spikes_dmg"}, 0]}, {"flag": "crush_die"}]},
     "do": [{"op": "damage", "to": {"enemy": "random", "except": "target"}, "source": "item", "v": {"param": "spikes_dmg"}}],
     "announce": {"effect": "spikes", "value": {"param": "spikes_dmg"}, "extra": {"enemy_idx": "$target"}}},
    {"id": "rend", "on": "hit.main", "prio": 451, "if": {"all": [{"gt": [{"param": "rend_poison"}, 0]}, {"flag": "crush_die"}]},
     "do": [{"op": "status", "status": "poison", "to": "target", "v": {"param": "rend_poison"}}],
     "announce": {"effect": "rend", "value": "$result", "extra": {"enemy_idx": "$target"}}}
  ],
  "variants": {
    "hammer_smith":       {"sec": "tempered",    "params_set": {"tempered_pip": 1},     "unlock": {"mastery": 15}},
    "hammer_morningstar": {"sec": "spikes",      "params_set": {"spikes_dmg": 3},       "unlock": {"mastery": 45}},
    "hammer_club":        {"sec": "rend",        "params_set": {"rend_poison": 2},      "unlock": {"mastery": 90}},
    "hammer_mallet":      {"sec": "heavy_swing", "params_add": {"crush": 0.3}, "hands": 2, "style": "melee_2h", "unlock": {"feat": "warhammer_a3_win"}},
    "hammer_bone":        {"sec": "bonebreak",   "params_set": {"bonebreak_pct": 0.5},  "unlock": {"feat": "bone_champion_3"}}
  }
}
```

The pattern "variants set params that base rules read" covers most of the 50 secondaries without
extra rules (Steel Greatsword `mult −0.05`, War Axe `stacks 4`, Bone Bulwark `thorns −1`…). Poison
applied by the hero passes through `query.poison_applied`, where the Hooded Robe's Shroud adds, so
Rend gets Shroud exactly as `ItemLogic.poison` does today (`item_logic.gd:139`).

**Great Axe + 3 variants: Full (v1). The other tricky shape is per-target stacks**
(`item_logic.gd:420-427`, `:668-669`, `:716-727`):

```json
"great_axe": {
  "slot": "weapon", "hands": 2, "style": "melee_2h", "affinity": ["barbarian"], "std": {"kind": "x1.2", "scale": {}},
  "params": {"per": [1, 1, 1], "stacks": [1, 2, 3], "sticky": 0, "bleed": 0},
  "resources": {"stacks": {"scope": "fight"}, "on": {"scope": "fight", "start": -1}},
  "rules": [
    {"id": "rampage", "on": "attack.mods", "prio": 330,
     "let": {"st": {"if": [{"any": [{"eq": [{"res": "on"}, {"var": "target"}]}, {"gt": [{"param": "sticky"}, 0]}]}, {"res": "stacks"}, 0]}},
     "if": {"all": [{"var": "target.alive"}, {"gt": [{"var": "st"}, 0]}]},
     "do": [{"op": "flat_add", "v": {"mul": [{"var": "st"}, {"param": "per"}]}}, {"op": "set_flag", "name": "rampage_now", "v": {"var": "st"}}],
     "announce": {"effect": "rampage", "value": "$result", "extra": {"stacks": {"var": "st"}, "enemy_idx": {"var": "target"}}}},
    {"id": "bleed", "on": "hit.main", "prio": 460, "if": {"all": [{"gt": [{"param": "bleed"}, 0]}, {"gt": [{"flag": "rampage_now"}, 0]}]},
     "do": [{"op": "status", "status": "poison", "to": "target", "v": {"mul": [{"flag": "rampage_now"}, {"param": "bleed"}]}}],
     "announce": {"effect": "bleed", "value": "$result", "extra": {"enemy_idx": "$target"}}},
    {"id": "track", "on": "hit.main", "prio": 499, "do": [
      {"op": "res_set", "res": "stacks", "quiet": true, "v": {"if": [{"var": "target.killed"}, 0,
        {"min": [{"param": "stacks"}, {"add": [{"if": [{"any": [{"eq": [{"res": "on"}, {"var": "target"}]}, {"gt": [{"param": "sticky"}, 0]}]}, {"res": "stacks"}, 0]}, 1]}]}]}},
      {"op": "res_set", "res": "on", "quiet": true, "v": {"if": [{"var": "target.killed"}, -1, {"var": "target"}]}}]}
  ],
  "variants": {
    "axe_war":    {"sec": "frenzy",   "params_set": {"stacks": 4}, "unlock": {"mastery": 15}},
    "axe_jagged": {"sec": "bleed",    "params_set": {"bleed": 1},  "unlock": {"mastery": 45}},
    "axe_golem":  {"sec": "crushing", "params_set": {"sticky": 1}, "stats": {"max_hp": -1}, "unlock": {"feat": "bone_golem_10"}}
  }
}
```

### 4.2 Passives / relics

All four requested passives, and 21 more, ran in the prototype ✔ **Full (v1)**:

```json
"pair_master": {"rarity": "common", "params": {"bonus": 0.5}, "rules": [
  {"id": "pairs", "on": "attack.combo_mult", "prio": 20, "if": {"in": [{"var": "combo.id"}, ["pair", "two_pair"]]},
   "do": [{"op": "mult_add", "v": {"param": "bonus"}}], "announce": {"value": 0}}]},

"snake_eyes": {"rarity": "common", "params": {"per": 5}, "rules": [
  {"id": "ones", "on": "attack.pips", "prio": 30,
   "do": [{"op": "flat_add", "skip_zero": true, "v": {"mul": [{"count_dice": {"eff": 1}}, {"param": "per"}]}}],
   "announce": {"value": "$result"}}]},

"second_wind": {"rarity": "rare", "rules": [
  {"id": "save", "on": "hero.lethal", "prio": 20, "stop": true, "limit": {"per": "run"}, "do": [{"op": "survive"}]}]},

"piggy_bank": {"rarity": "uncommon", "economy": true, "params": {"pct": 0.1, "max": 15}, "rules": [
  {"id": "interest", "on": "lap.completed",
   "do": [{"op": "gold", "skip_zero": true, "v": {"min": [{"param": "max"}, {"trunc": {"mul": [{"var": "gold"}, {"param": "pct"}]}}]}}],
   "announce": {"value": "$result"}}]}
```

Two passives need extra structure. **Collector** is Full (v1): `owner.gained` adds 5 max HP per
runed die, and `owner.gained` of a rune on a blank die adds 5. **Fast Feet** is **Full (v1.1)**: it
needs `queue_move` to hop by `pair_value` after landing, unless a boss is pending. Passive score and
category tables (`bot.gd:19-27, 405-417`) move into `ai`.

### 4.3 Runes

Ember, Echo and Vampire, plus the activation predicates of all 12 runes, ran in the prototype ✔
**Full (v1)**. Two declared triggers are wrong today and data fixes them: Heavy is declared ALWAYS
but only acts in the scoring group, and Gilded is declared MOVE but also pays in combos
(`runes.gd:8-20` vs `combat.gd:416`).

```json
"ember": {"rarity": "rare", "color": "#f08030", "cap": 2,
  "when": {"all": [{"eq": [{"var": "die.eff"}, 6]}, {"not": {"var": "die.pretend"}}]},
  "rules": [{"id": "blast", "on": "rune.after_hit", "repeat": {"var": "rune.times"},
    "do": [{"op": "damage", "to": {"enemies": "all"}, "source": "ember", "v": {"query": ["query.rune_amount", 6]}}],
    "announce": {"effect": "damage_all", "value": "$result"}}],
  "refire": [{"op": "damage", "to": {"enemies": "all"}, "source": "pet", "v": {"max": [6, {"var": "refire.value"}]}}]},

"echo": {"rarity": "epic", "color": "#9a60e0", "cap": 2, "no_double": true, "when": {"var": "die.in_group"},
  "rules": [{"id": "resonate", "on": "attack.dice", "do": [{"op": "mult_add", "v": {"mul": [0.5, {"var": "rune.times"}]}}],
            "announce": {"effect": "mult", "value": 0, "count": {"var": "rune.times"}}}]},

"vampire": {"rarity": "rare", "color": "#a01830", "cap": 2, "when": {"var": "die.in_group"},
  "rules": [{"id": "lifesteal", "on": "rune.after_attack", "if": {"gt": [{"var": "killed"}, 0]},
    "do": [{"op": "heal", "v": {"var": "die.eff"}, "source": "vampire"}], "announce": {"effect": "heal", "value": "$result"}}]}
```

The Mage Robe's +damage to Ember/Thunder and +poison to Venom becomes item rules on
`query.rune_amount` (filtered by `rune`). The prototype called the native `rune_dmg` here, as a
bridge. **Wild stays Native**: it is a wildcard inside `Combo.evaluate` (`combo.gd:29`) and shares
`WILD_MAX_DICE` with the ★ face. Its data is just `"wild": true`.

### 4.4 Pets

**Pumpkin Sprite: Full (v1)**, including the fire, the L5 and L10 behaviours and the perk
(`pet_logic.gd:89-100`, `game_flow.gd:490`):

```json
"pumpkin_sprite": {
  "role": "heal", "look": {"builder": "pumpkin"},
  "params": {"size": 6, "heal_pct": {"lin": [0.02, 0.005]}, "campfire_bonus": 0.05},
  "resources": {"charge": {"scope": "run", "max": {"param": "size"}, "event": "pet_charged", "ui": {"meter": "pet"}}},
  "charge": [{"id": "pair_plus", "on": "attack.resolved", "if": {"not": {"in": [{"var": "combo.id"}, ["high_roller", ""]]}},
              "do": [{"op": "res_add", "res": "charge", "v": 1, "cap": {"param": "size"}}]}],
  "fire": {"at": "attack.begin", "rules": [
    {"id": "heal", "if": {"gte": [{"res": "charge"}, {"param": "size"}]},
     "let": {"amt": {"pct_of_max_hp": {"param": "heal_pct"}}},
     "do": [{"op": "res_set", "res": "charge", "v": 0, "quiet": true},
            {"op": "heal", "v": {"var": "amt"}, "source": "pet", "as": "healed"},
            {"op": "status_hero", "status": "burn", "clear": true, "source": "pet",
             "if": {"all": [{"gte": [{"var": "pet.level"}, 5]}, {"gt": [{"var": "hero.burn"}, 0]}]}},
            {"op": "block", "source": "pet", "skip_zero": true, "if": {"gte": [{"var": "pet.level"}, 10]},
             "v": {"sub": [{"var": "amt"}, {"var": "healed"}]}}],
     "announce": {"effect": "heal", "value": {"var": "healed"}, "target": "hero"}}]},
  "perks": [{"id": "campfire", "on": "query.campfire_heal", "prio": 60,
             "do": [{"op": "set_value", "v": {"add": [{"var": "value"}, {"param": "campfire_bonus"}]}}]}]
}
```

**Skull Buddy: Full (v1)**, including the L10 charge ×2 for blanks and blanks counted as 1 in the
bite (`pet_logic.gd:101-113`, `:317-322`, perk `game_flow.gd:1605`):

```json
"skull_buddy": {
  "role": "attack", "params": {"size": 4, "bite_pct": {"lin": [0.30, 0.05]}, "bite_min": 8, "low_max": 2},
  "resources": {"charge": {"scope": "run", "max": {"param": "size"}, "event": "pet_charged"}},
  "charge": [{"id": "low_die", "on": "attack.resolved", "do": [{"op": "res_add", "res": "charge", "cap": {"param": "size"},
    "v": {"add": [{"count_dice": {"eff_between": [1, {"param": "low_max"}]}},
                  {"mul": [{"count_dice": {"eff": 0}}, {"if": [{"gte": [{"var": "pet.level"}, 10]}, 2, 1]}]}]}}]}],
  "fire": {"at": "attack.begin", "rules": [
    {"id": "bite", "if": {"gte": [{"res": "charge"}, {"param": "size"}]},
     "let": {"pips": {"sum": {"map_max": [{"var": "combo.preview.values"}, {"if": [{"gte": [{"var": "pet.level"}, 10]}, 1, 0]}]}},
             "dmg": {"max": [{"param": "bite_min"}, {"round": {"mul": [{"param": "bite_pct"}, {"var": "pips"}, {"var": "combo.preview.mult"}]}}]}},
     "do": [{"op": "res_set", "res": "charge", "v": 0, "quiet": true},
            {"op": "damage", "to": "target", "v": {"var": "dmg"}, "source": "pet"},
            {"op": "damage", "to": {"enemies": "others"}, "source": "pet", "if": {"gte": [{"var": "pet.level"}, 5]},
             "v": {"max": [1, {"idiv": [{"var": "dmg"}, 2]}]}}],
     "announce": {"effect": "bite", "value": {"var": "dmg"}, "target": {"if": [{"gte": [{"var": "pet.level"}, 5]}, "all", "$target"]}}}]},
  "perks": [{"id": "sure_foot", "on": "query.dodge_bonus", "do": [{"op": "set_value", "v": {"add": [{"var": "value"}, 1]}}]}]
}
```

Across the other ten pets, Lantern Ghost L5 and Wick's perk need the `status.tick` query, Crystal
Wisp L10 needs `free_reroll` and Guard Die L5 needs `schedule` (all **v1.1**). **Grimoire stays
Native**: `refire_rune` re-runs each rune's declared `refire` effects with the remembered value. Its
memory is stored by **rune id**, which fixes the index-based storage `pet_logic.gd:213,297` flagged by
the audit.

### 4.5 Class mechanics

**Oath (Paladin): Full (v1.1)** (`class_logic.gd:123-163`, `:166-170`, `:173-179`, `:422-456`);
Sanctify needs the face-count selector:

```json
"oath": {
  "params": {"mult": 0.5, "pip": 0, "sanctify": 2, "shop_bias": {"twin": 2.0, "even": 2.0},
             "set_combos": ["pair", "two_pair", "three_kind", "full_house", "four_kind", "five_kind", "six_kind"]},
  "resources": {"oath": {"scope": "fight", "ui": {"badge": "OATH {v}", "icon": "mech_oath"}}},
  "rules": [
    {"id": "swear", "on": "fight.start", "prio": 100, "let": {"o": {"native": "pool_mode_face"}},
     "if": {"gt": [{"var": "o"}, 0]}, "do": [{"op": "res_set", "res": "oath", "v": {"var": "o"}, "quiet": true}],
     "announce": {"effect": "oath", "value": {"var": "o"}}},
    {"id": "oath_kept", "on": "attack.combo_mult", "prio": 150,
     "let": {"n": {"count_dice": {"in_group": true, "eff": {"res": "oath"}}}},
     "if": {"all": [{"gt": [{"res": "oath"}, 0]}, {"in": [{"var": "combo.id"}, {"param": "set_combos"}]}, {"gte": [{"var": "n"}, 2]}]},
     "do": [{"op": "mult_add", "v": {"param": "mult"}}, {"op": "bonus_add", "v": {"mul": [{"param": "pip"}, {"var": "n"}]}}],
     "announce": {"effect": "oath_kept", "value": {"mul": [{"param": "pip"}, {"var": "n"}]}, "extra": {"oath": {"res": "oath"}, "mult": {"param": "mult"}}}},
    {"id": "sanctify", "on": "biome.start", "limit": {"per": "run", "max": {"param": "sanctify"}},
     "let": {"o": {"native": "pool_mode_face"},
             "d": {"pick_die": {"dice": {"base_pool": true, "where": {"all": [{"lte": [{"var": "o"}, {"var": "die.cap"}]}, {"lt": [{"die_faces_eq": {"var": "o"}}, 6]}]}},
                                "pick": "lowest", "by": {"die_faces_eq": {"var": "o"}}}},
             "f": {"pick_face": {"die": {"var": "d"}, "where": {"all": [{"ne": [{"var": "face.value"}, {"var": "o"}]}, {"lte": [{"var": "face.value"}, 9]}]}, "pick": "lowest"}}},
     "if": {"all": [{"gt": [{"var": "o"}, 0]}, {"gte": [{"var": "d"}, 0]}, {"gte": [{"var": "f"}, 0]}]},
     "do": [{"op": "set_face", "die": {"var": "d"}, "face": {"var": "f"}, "v": {"var": "o"}, "source": "sanctify"}],
     "announce": {"effect": "sanctify", "value": {"var": "o"}, "extra": {"die_idx": {"var": "d"}, "face_idx": {"var": "f"}}}},
    {"id": "favoured_kinds", "on": "query.shop_kind_weights", "do": [{"op": "weights_mul", "v": {"param": "shop_bias"}}]}
  ],
  "ai": {"model": {"oath_face": {"res": "oath"}}, "kind_bonus": {"twin": 1.3, "even": 1.3}}
}
```

**Bone Harvest (Necromancer): Full (v1)** (`class_logic.gd:190-217`, `:367-390`). The temporary dice
use `add_temp_die`, and the raise step is shared through `invoke`, or written three times without it:

```json
"bone_harvest": {
  "params": {"max": 2, "pool_max": 6, "heal": 2, "lone_turns": [3, 6]},
  "resources": {"raised": {"scope": "fight", "ui": {"pips": 2, "icon": "bone"}}, "pending": {"scope": "fight"}},
  "rules": [
    {"id": "raise", "on": "none",
     "if": {"all": [{"lt": [{"res": "raised"}, {"param": "max"}]}, {"lt": [{"add": [{"var": "pool.size"}, {"res": "pending"}]}, {"param": "pool_max"}]}]},
     "do": [{"op": "res_add", "res": "raised", "v": 1, "quiet": true}, {"op": "res_add", "res": "pending", "v": 1, "quiet": true}],
     "announce": {"effect": "bone_harvest", "value": {"res": "raised"}, "extra": {"reason": {"arg": "why"}}}},
    {"id": "lone", "on": "turn.before", "prio": 110,
     "if": {"all": [{"in": [{"var": "turn"}, {"param": "lone_turns"}]}, {"eq": [{"var": "enemies.count"}, 1]}, {"not": {"var": "fight.all_dead"}}]},
     "do": [{"op": "invoke", "rule": "raise", "args": {"why": "lone"}}]},
    {"id": "join", "on": "turn.before", "prio": 120, "repeat": {"res": "pending"},
     "do": [{"op": "res_add", "res": "pending", "v": -1, "quiet": true}, {"op": "add_temp_die", "kind": "bone", "tags": ["bone"]}]},
    {"id": "kill", "on": "enemy.killed", "prio": 110, "if": {"not": {"var": "fight.all_dead"}}, "do": [{"op": "invoke", "rule": "raise", "args": {"why": "kill"}}]},
    {"id": "phase", "on": "boss.phase", "prio": 110, "do": [{"op": "invoke", "rule": "raise", "args": {"why": "phase"}}]},
    {"id": "crumble", "on": "fight.won", "prio": 110, "let": {"n": {"count_dice": {"temp": true, "tag": "bone"}}},
     "do": [{"op": "remove_temp_dice", "tag": "bone"}, {"op": "res_set", "res": "pending", "v": 0, "quiet": true},
            {"op": "heal", "source": "bones", "skip_zero": true, "v": {"mul": [{"param": "heal"}, {"var": "n"}]}}],
     "announce": {"effect": "bone_crumble", "value": {"var": "n"}, "if": {"gt": [{"var": "n"}, 0]}}}
  ],
  "ai": {"kill_value": 6}
}
```

Other mechanics: Aim, Shadow Step and Overgrowth are **Full (v1)**. The Turret is **Full (v1.1)**
with side dice. BOO!'s scare, cower, flee and weaken rules are v1, but the ★ Pretend face (a Wild in
combat, the most common other value on the board) is **Native**, the same primitive as the Wild rune.

### 4.6 Potion

**Stoneskin: Full (v1.1)** (`game_flow.gd:1678-1683`, `combat.gd:270-277`); Cleanse is Full (v1):

```json
"stoneskin": {"combat_only": true, "params": {"block": 15}, "look": {"icon": "shield"}, "rules": [
  {"id": "drink", "on": "potion.drink", "if": {"var": "in_combat"},
   "do": [{"op": "block", "v": {"param": "block"}, "source": "potion"},
          {"op": "schedule", "at": "turn.setup", "scope": "fight", "prio": 30, "do": [{"op": "block", "v": {"param": "block"}}]}]}]},
"cleanse": {"combat_only": false, "params": {"heal_pct": 0.10}, "rules": [
  {"id": "drink", "on": "potion.drink",
   "do": [{"op": "cleanse", "what": ["chill", "burn", "curse_pending", "locks"], "source": "potion"},
          {"op": "heal_pct", "v": {"param": "heal_pct"}, "source": "potion"}]}]}
```

### 4.7 Event

**Dice Duel: Full (v1)** (`game_flow.gd:1260-1263`, `:1335-1345`). The RNG draw order is the same:
the player's two dice, then the rival's.

```json
"duel": {"weight": 1, "text": {"title_key": "event.duel.title", "text_key": "event.duel.text"}, "look": {"art": "dice"},
 "choices": [
  {"label_key": "event.duel.bet", "args": {"n": 10}, "desc_key": "event.duel.bet_desc", "enabled": {"gte": [{"var": "gold"}, 10]},
   "let": {"mine": {"roll": [2, 6]}, "theirs": {"roll": [2, 6]},
           "o": {"sign": {"sub": [{"sum": {"var": "mine"}}, {"sum": {"var": "theirs"}}]}}},
   "do": [{"op": "emit", "event": "duel", "fx": "dice_duel",
           "fields": {"player": {"var": "mine"}, "npc": {"var": "theirs"}, "outcome": {"var": "o"}, "bet": 10}},
          {"op": "gold", "skip_zero": true, "source": "duel", "v": {"mul": [10, {"var": "o"}]}}]},
  {"label_key": "event.duel.bet", "args": {"n": 25}, "enabled": {"gte": [{"var": "gold"}, 25]}, "let": "…same with 25…"},
  {"label_key": "event.duel.walk", "do": []}]}
```

The other six events (Shrine offers, Outbreak/Garden `convert_tiles`, Merchant, Dicesmith with
`reforge_die` on the weakest die, Idol) are Full (v1). The Hollow's heal and counter after events
become a biome rule on `event.choose`. The bespoke duel animation is presentation: the `fx:
"dice_duel"` builder.

### 4.8 Twists

**Glade (old twist): Full (v1)** (`game_flow.gd:488`, bot copy `bot.gd:2326`):

```json
"glade": {"tier": 1, "mix": {"campfire": 1, "chest": 1}, "elite": "brute", "minibosses": ["mini_briar_beast"], "bosses": [],
  "pools": [["thorn_sprite", "wolf_bandit", "skeleton_minion"], ["thorn_sprite", "wolf_bandit", "skeleton_archer", "orc_raider"]],
  "params": {"campfire_pct": 0.45},
  "rules": [{"id": "sunlit_campfires", "on": "query.campfire_heal", "prio": 10, "do": [{"op": "set_value", "v": {"param": "campfire_pct"}}]}],
  "affixes": {"weights": {"thorned": 3, "regenerating": 3}}, "look": {"kit": "glade"}}
```

The Crypt (dodged trap → gold, on `tile.resolved` with `trap.dodged`), the Hollow (`event.choose` →
heal 3 % and the `biome_events` counter) and the Throne (`query.elite_boss_passive_chance`) follow
the same pattern.

**Warcamp drums (new twist): Full (v1)** (`combat.gd:1113-1125`, `game_flow.gd:1418-1423`,
`:1475-1481`, `board.gd:390`):

```json
"warcamp": {"tier": 2, "mix": {"drum": 1}, "tiles": {"drum": {"count": {"param": "drums"}}},
  "params": {"rally": 1, "drum_gold": 14, "drums": 1},
  "rules": [
    {"id": "war_drums", "on": "fight.setup", "prio": 510,
     "let": {"n": {"board_count": "drum"}, "v": {"mul": [{"var": "n"}, {"param": "rally"}]}},
     "if": {"gt": [{"var": "n"}, 0]},
     "do": [{"op": "atk_add", "to": {"enemies": "all", "where": {"not": {"var": "enemy.boss"}}}, "v": {"var": "v"}, "cap": "atk_bonus_cap", "source": "drum", "rally": true}],
     "announce": {"event": "rally", "if_events": true, "fields": {"source": "drum", "value": {"var": "v"}, "drums": {"var": "n"}}}},
    {"id": "rebuild", "on": "lap.mutation", "prio": 510, "if": {"eq": [{"board_count": "drum"}, 0]},
     "do": [{"op": "place_tile", "kind": "drum", "source": "rebuild",
             "where": {"tiles": "kind", "kind": "empty", "not_corner": true, "min_index": 3, "min_dist_hero": 4, "exclude": "protect"}, "pick": "random"}]}
  ]},
"drum": {"not_near_start": true, "twist": "drums", "look": {"style": "drum"}, "ai": {"value": 5},
  "rules": [{"id": "smash", "on": "tile.land",
    "let": {"g": {"gold_bonus": {"round": {"mul": [{"biome_param": "drum_gold"}, {"gold_scale": []}]}}}},
    "do": [{"op": "consume_tile"},
           {"op": "emit", "event": "drum_smashed", "fields": {"idx": {"var": "tile.idx"}, "gold": {"var": "g"}, "drums": {"board_count": "drum"}}},
           {"op": "gold", "v": {"var": "g"}, "source": "drum"}]}]}
```

### 4.9 Tile kinds

**Campfire: Full (v1)** (`game_flow.gd:486-493`). The base heal is a query, so the Glade, the
Tankard and Pumpkin each add their own rule:

```json
"campfire": {"consumable": true, "params": {"base_pct": 0.30}, "look": {"style": "campfire"},
  "rules": [{"id": "rest", "on": "tile.land", "do": [{"op": "consume_tile"},
    {"op": "heal", "source": "campfire", "v": {"pct_of_max_hp": {"query": ["query.campfire_heal", {"param": "base_pct"}]}}}]}],
  "ai": {"value": {"heal_pct": {"query": ["query.campfire_heal", {"param": "base_pct"}]}}}}
```

**Ore: Full (v1)** (`game_flow.gd:1490-1523`), an inline choice offer:

```json
"ore": {"not_near_start": true, "twist": "ore", "params": {"gold": 20}, "look": {"style": "ore"},
  "rules": [{"id": "vein", "on": "tile.land",
    "let": {"g": {"gold_bonus": {"round": {"mul": [{"param": "gold"}, {"gold_scale": []}]}}}},
    "do": [{"op": "offer_choice", "offer": "ore", "title_key": "tile.ore.title", "text_key": "tile.ore.text", "fields": {"gold": {"var": "g"}},
      "choices": [
        {"label_key": "tile.ore.take", "args": {"n": {"var": "g"}}, "do": [
          {"op": "emit", "event": "ore_mined", "fields": {"idx": {"var": "tile.idx"}, "choice": "gold", "gold": {"var": "g"}}},
          {"op": "convert_tiles", "tiles": "current", "kind": "trap", "source": "cave_in"},
          {"op": "gold", "v": {"var": "g"}, "source": "ore"}]},
        {"label_key": "tile.ore.smelt", "enabled": {"native": "any_face_raisable"}, "do": [
          {"op": "emit", "event": "ore_mined", "fields": {"idx": {"var": "tile.idx"}, "choice": "raise", "gold": 0}},
          {"op": "convert_tiles", "tiles": "current", "kind": "trap", "source": "cave_in"},
          {"op": "offer_forge", "ops": ["raise"], "source": "ore", "queue": "front"}]}]}]}]}
```

All 18 tile types are **Full (v1)**. Fights, forge, treasury and portal call native offer or fight
ops. Start's lap logic is the engine.

### 4.10 Enemy with phases / transform, and intents as data

The **Werewolf** is already data today. Only the threshold becomes a query, so the Moonlit's Half
moon (`combat.gd:1101-1103`) is a biome rule, **Full (v1)**:

```json
"werewolf": {"hp": 26, "gold": 8, "xp": 6, "tags": ["beast"], "mode": "cycle", "forms": ["man", "wolf"],
  "phases": [[{"intent": "block", "v": 5}, {"intent": "attack", "v": 6}],
             [{"intent": "attack", "v": 5}, {"intent": "drain", "v": 6}, {"intent": "attack", "v": 9}]],
  "transform": {"at": {"query": ["query.transform_at", 0.5]}, "drop_block": true}},
"moonlit": {"tier": 3, "phases": {"moon": ["crescent", "half", "full", "half", "crescent"]}, "rules": [
  {"id": "half_moon", "on": "query.transform_at", "if": {"eq": [{"var": "biome.phase"}, "half"]}, "do": [{"op": "set_value", "v": 0.65}]},
  {"id": "full_moon", "on": "fight.setup", "prio": 520, "if": {"all": [{"eq": [{"var": "biome.phase"}, "full"]}, {"ne": [{"var": "fight.kind"}, "boss"]}]},
   "do": [{"op": "set_flag", "name": "moon_full"},
          {"op": "transform", "to": {"enemies": "all", "where": {"all": [{"not": {"var": "enemy.boss"}}, {"var": "enemy.transforms"}]}}, "source": "moon"}]},
  {"id": "full_moon_gold", "on": "reward.gold", "if": {"flag": "moon_full"}, "do": [{"op": "set_value", "v": {"mul": [{"var": "value"}, 1.5]}}]},
  {"id": "full_moon_elite", "on": "query.mutation_spawns", "if": {"eq": [{"var": "biome.phase_next"}, "full"]}, "do": [{"op": "set_value", "v": {"concat": [{"var": "value"}, ["elite"]]}}]}]}
```

**Intents become op compositions** over a native library of enemy ops (`hit_hero`, `heal_self`,
`heal_allies`, `block_enemy`, `atk_add`, `lock_dice`, `status_hero`, `curse_face`, `summon`). All 14
intent kinds in `_execute_intent` (`combat.gd:930-1027`) are **Full (v1)**, for example:

```json
"intents": {
  "chill": {"telegraph": "attack", "scale": "atk", "do": [{"op": "hit_hero", "v": {"var": "intent.value"}},
            {"op": "lock_dice", "n": 1, "pending": true, "chill": true, "if": {"var": "hero.alive"}}]},
  "drain": {"telegraph": "attack", "scale": "atk", "do": [{"op": "hit_hero", "v": {"var": "intent.value"}, "as": "dealt"},
            {"op": "heal_enemy", "to": "self", "v": {"var": "dealt"}, "source": "drain", "if": {"all": [{"var": "hero.alive"}, {"var": "self.alive"}]}}]},
  "bury":  {"telegraph": "curse", "scale": "none", "do": [{"op": "lock_dice", "n": {"var": "intent.value"}, "pending": true, "bury": true},
            {"op": "block_enemy", "to": "self", "source": "bury", "v": {"round": {"mul": [{"param": "bury_block"}, {"var": "intent.value"}, {"var": "self.atk_mult"}]}}}]}
}
```

The 6 **traits** become enemy rules (armor: `query.block_decay`; ward: `damage.enemy`; thorns:
`hit.main` on self; frenzy: survived main hit), and the 10 **affixes** become enemy rules too, all
**Full (v1)**. That makes 36/36 enemies data, and **new intents become data**. A genuinely new
enemy *op* (for example "steal a rune") is a core release.

### 4.11 The Moon King's moon meter ✔ Full (v1)

This is the prototype's JSON (compacted). It replaces `combat.gd:1126-1137`, `:1152-1172` and
`:1176-1185`, and all three `moon_meter` sources, both first-fight modifiers (A9, Moonfang route),
Moonrise and Moonfall matched the goldens:

```json
"boss_moon_king": {
  "params": {"max": 4, "tide": 1, "clouds_max": 2, "fall": 34, "a9_start": 2, "fang_start": -1},
  "resources": {"moon": {"scope": "fight", "bind": "moon", "event": "moon_meter", "max_param": "max", "ui": {"meter": "moon"}}},
  "rules": [
    {"on": "fight.setup", "prio": 10, "if": "$FANG",
     "do": [{"op": "res_set", "res": "moon", "delta": 0, "source": "moonfang", "v": {"add": ["$A9", {"param": "fang_start"}]}}]},
    {"on": "fight.setup", "prio": 11, "if": {"not": "$FANG"},
     "do": [{"op": "res_set", "res": "moon", "delta": 0, "source": "start", "v": "$A9"}]},
    {"on": "enemy_phase.end", "prio": 10, "if": {"var": "self.alive"},
     "do": [{"op": "res_add", "res": "moon", "source": "tide", "v": {"param": "tide"}}]},
    {"on": "enemy_phase.end", "prio": 20,
     "if": {"all": [{"var": "self.alive"}, {"gte": [{"res": "moon"}, {"param": "max"}]}, {"eq": [{"var": "self.phase"}, 1]}]},
     "do": [{"op": "res_set", "res": "moon", "v": 0, "quiet": true, "save_as": "was"}, {"op": "boss_phase"}, {"op": "roll_intent"},
            {"op": "res_event", "res": "moon", "source": "moonrise", "delta": {"sub": [0, {"var": "was"}]}}, {"op": "intent_event"}]},
    {"on": "enemy_phase.end", "prio": 30,
     "if": {"all": [{"var": "self.alive"}, {"gte": [{"res": "moon"}, {"param": "max"}]}, {"eq": [{"var": "self.phase"}, 2]}]},
     "do": [{"op": "res_set", "res": "moon", "v": 0, "quiet": true, "save_as": "was"},
            {"op": "set_intent", "name": "moonfall", "v": {"add": [{"param": "fall"}, {"var": "self.atk_bonus"}]}},
            {"op": "res_event", "res": "moon", "source": "moonfall", "delta": {"sub": [0, {"var": "was"}]}}, {"op": "intent_event"}]},
    {"on": "attack.end", "prio": 10, "if": {"all": [{"var": "self.alive"}, {"gt": [{"res": "moon"}, 0]}]},
     "do": [{"op": "res_add", "res": "moon", "source": "clouds", "floor": 0, "skip_zero": true,
             "v": {"sub": [0, {"min": [{"count_dice": {"shown": 1, "base_pool": true, "rune_not": "wild"}}, {"param": "clouds_max"}]}]},
             "extra": {"ones": {"count_dice": {"shown": 1, "base_pool": true, "rune_not": "wild"}}}}]}
  ],
  "macros": {"$FANG": {"all": [{"has": [{"var": "run.route"}, "hollow"]}, {"has": [{"var": "run.route"}, "moonlit"]}, {"has": [{"var": "run.minibosses_killed"}, "mini_moonfang"]}]},
             "$A9": {"if": [{"all": [{"asc": "boss_phase"}, {"eq": [{"var": "boss_stage"}, 0]}]}, {"param": "a9_start"}, 0]}},
  "ai": {"resource": "moon", "threat_full": {"param": "fall"}, "counter": {"dice_shown": 1}}
}
```

(`macros` is a compile-time textual expansion; the file the prototype ran spells them out:
`rules-exp/B/core/rules/rules_base.json`.) The bot's `_moon_model` (`bot.gd:1343`) becomes a generic
"resource threat" model driven by `ai.resource`.

### 4.12 Ascension key

**`shop_tax` (A3) ✔ Full (v1)** (in the prototype). **`hazards` (A8): Full (v1)**
(`run_state.gd:170-178`, `:310-314`):

```json
"hazards": {"level": 8, "desc_key": "asc.hazards", "params": {"mult": 1.5}, "rules": [
  {"id": "hurt_more", "on": "query.hazard_mult", "do": [{"op": "set_value", "v": {"mul": [{"var": "value"}, {"param": "mult"}]}}]},
  {"id": "extra_hazard", "on": "board.generated", "prio": 10,
   "do": [{"op": "place_tile", "kind": {"var": "biome.trap_tile"}, "pick": "random",
           "where": {"tiles": "kind", "kind": "empty", "not_corner": true, "min_index": 3, "exclude": "protect"}}]}]}
```

Nine of the ten keys are Full (v1). A10's double boss needs `start_combat` (**v1.1**). Daily and
seasonal modifiers are the same owner kind, activated by the run's pinned modifier list.

### 4.13 Per-domain coverage (current entries expressible as generic data)

| Domain | Entries | Dispatch today | Full (v1) | Full (v1.1) | Native | Notes |
|---|---|---|---|---|---|---|
| Passives / relics | 32 | by id, 36 `has_passive` sites | 31 | **32** | 0 | Fast Feet: `queue_move` |
| Armory item rules | 51 | by item id | 50 | **51** | 0 | Arcana: `rune.times[]` |
| Variants (secondaries) | 51 | by variant id | **51** | 51 | 0 | Heraldic carry reads `turn.setup`'s `prev_block` |
| Back items (Style) | 13 | cosmetic | 13 | 13 | 0 | looks only |
| Runes | 12 | by id | 11 | 11 | 1 | Wild (combo wildcard) |
| Dice kinds | 11 | generic | 10 | 10 | 1 | Pretend ★ face |
| Pets | 12 | by id (fire, perk, L5, L10) | 7 | **11** | 1 | Grimoire `refire_rune` |
| Potions | 4 | by id (unknown → heal) | 3 | **4** | 0 | Stoneskin: `schedule` |
| Affixes | 10 | 5 trait, 5 by id | **10** | 10 | 0 | |
| Class mechanics (11 classes) | 7 | by mechanic | 4 | **6** | 1 | Oath (face count), Turret (side dice); BOO! ★ face |
| Enemies, mini-bosses, bosses | 36 | intents/traits generic, Moon King by id | **36** | 36 | 0 | intents = op compositions |
| Biome rules (twists, pools) | 10 | 4 old by biome id, 4 new by twist id | 9 | **10** | 0 | Moonlit chest: `first_of` |
| Tile kinds | 18 | closed `match` | **18** | 18 | 0 | offers stay native flows |
| Events | 7 | by id | **7** | 7 | 0 | fx builders are presentation |
| Ascension keys | 10 | closed | 9 | **10** | 0 | A10: `start_combat` |
| **Behavioural total** | **271** | | **256 (94.5 %)** | **267 (98.5 %)** | **4** | back items excluded (13/13 data) |
| Shop kinds / draft / reward tiers / signatures | 6 / 5 / 3 / 11 | closed | all | all | 0 | the offer *flows* are native |
| Milestones / feats / skin conditions | 48 / 14 / 55 | generic, 5 id-specific counters | all (keyed counters) | all | 0 | skin overlays are presentation |
| Camp upgrades | 4 (+ ranks, pouch) | via MetaRun fields | all | all | 0 | stations are UI code |
| Combos | 10 | detection code | multipliers | patterns (optional) | detection | |
| Minigames | 11 | code per game | params, rewards, signatures | 4 templates → new variants | 11 games | §3.1 |

### 4.14 Behaviours that should remain native primitives (callable from data by name + params)

1. **Combo evaluation** with wildcard dice (the Wild rune, the ★ face) and `WILD_MAX_DICE` sharing
   (`combo.gd:29`, `combat.gd:367-385`).
2. **Move selection** `pick_move_dice` and pair value (`game_flow.gd:176-254`); tie-break via query.
3. **Board generation / mutation / placement** (`board.gd:67-309`), parameterised by biome, tile
   kind and modifier data.
4. **Damage resolution** `damage_enemy` (block, ward query, overkill, kill and threshold dispatch)
   and **hero damage** `_hit_hero` with the survive chain.
5. **Status engine behaviours**: poison DoT (ignores block, decays), freeze (skip action), cower,
   weaken, hero burn, curse/lock (pending → locked at turn start), face edits restored at fight end,
   A7 curse until Forge.
6. **Enemy ops** used by data intents (`hit_hero`, heals, block, `atk_add` with cap, `lock_dice`,
   `curse_face`, `summon` with cap and lap scaling), intent rolling (cycle/random), enemy scaling.
7. **Rune activation loop** (predicates, caps, `times`) and dice-pool / temporary-dice / side-dice
   management.
8. **Named values**: `pool_mode_face`, `combo.set_value`, `rerolled_match`, `pretend_board_value`,
   `combo.preview`, `any_face_raisable`.
9. **Named effects**: `refire_rune` (Grimoire).
10. **Offer / UI flows**: draft, rune choice, passive choice, rune assign, forge (raise/mirror),
    portal, shop stock algorithm, event choice, reward, minigame.
11. **Minigame state machines** (11), and templates for data variants.
12. **Formulas**: gold/XP rewards, level-ups, lap scaling (their numbers are data).
13. **Presentation builders**: fx, beats, meters, dressing kits, pet bodies, skin overlays, attack
    styles.

---

## 5. What still needs code after this

Data **recombines** reviewed primitives. Anything that needs a new primitive is a core release.
Honestly, that is:

| Needs a core release | Examples | How to widen what data can do |
|---|---|---|
| **New hook points** | "when a die is marked", "when a face is edited", "when the pet charges", "on shop leave", "on portal pick" | Publish a broad catalogue up front (~60 hooks, §2.3). Add **observer hooks** `on: "event:<type>"` for a whitelist of emitted events (read-only payload, re-entrancy bounded, validated for cycles). That one mechanism turns every existing event into a trigger |
| **New effect ops, selectors, variables, native values** | "steal a rune", "swap two dice", "split an enemy in two", "teleport the hero to a tile kind" | Design each generically (`move_rune {from, to}`, not "the Thief affix"). Keep a primitive backlog (below) |
| **New status types with new behaviour** | "shock: the next hit ×1.5", "bleed on action", "regen on the hero" | Build statuses on a **status framework**: a status = a resource on an entity + rules on existing hooks + a badge look. Then new statuses that combine existing hooks are data, and only a new *behaviour hook* is code (do this in R8) |
| **New offer / UI flows and screens** | a "pick a tile to transform" modal, card drafts, a new Camp station, a new HUD widget beyond meter/badge/pips | A generic `offer_choice` (already v1) covers text choices. Spatial or visual picks need UI code |
| **New minigame kinds or templates** | anything outside grid-reveal / push-your-luck / spin-stop / drop-board | Templates (§3.1); a template is code once, then its variants are data |
| **New presentation builders** | VFX kinds, procedural pet bodies (`game/pets/pet_view*.gd`), dressing kits (`game/world/dressing/*`), skin overlay kinds, attack styles, arena effects, shaders | Looks as data (plan 2.6) with a builder registry (`look.*` caps). New art in art packs. Only new *builder kinds* are code |
| **Board topology and movement** | branching paths, non-ring boards, different move-pick rules | parameters only (ring size, corners, layouts) |
| **New combo types** | "three pairs", "odd straight" | optional v1.1 combo pattern spec (`{"sets": [2,2,2]}`, `{"run": 5, "parity": "odd"}`) |
| **New run structures or modes** | endless, boss rush, daily seeds, leaderboards | modifiers cover rule changes; the mode shell is code |
| **New meta systems or currencies** | a second crafting currency, a new unlock kind | new *kinds* are code; new entries of existing kinds are data |
| **Bot quality for novel shapes** | a rule the model compiler can't fold | the `ai.pv` hint plus calibration sims keep AUTO sane; better modelling is code |
| **Save-format changes** | persistent state beyond resources/flags/limits (e.g. per-die memories) | resources with `scope: run` and generic `rule_state` cover most |
| **Text functions** | plural rules, number formatting | the i18n groundwork (plan 2.8) |

**Keeping the list shrinking**

1. **Primitive backlog.** Every content idea that fails validation, or whose PR needs core code, is
   logged with the missing primitive. Each core release ships the top items, each with **at least
   one base use** and a release-notes line (Apple 2.3.1, distribution design §4.4).
2. **Generic first.** A primitive request is rewritten as the most general op that covers it, and
   reviewed against the vocabulary's principles (closed, bounded, deterministic).
3. **Promote patterns.** Twice a year, mine the content for repeated rule patterns. Promote them to
   **archetype macros** (compile-time templates in data, e.g. `{"archetype": "combo_mult_bonus",
   "combos": [...], "bonus": 0.5}`) for authoring ergonomics, or to native nodes for speed.
4. **Measure.** Track: the share of content PRs merged without core changes, idea-to-live time, and
   primitives added per release. The target is ≥ 90 % of drops needing no core release after R13.
5. **Widest-impact additions first:** observer hooks, the status framework, the choice-offer
   framework, side dice and `schedule`.

---

## 6. Engineering

### 6.1 Evaluator architecture (GDScript)

```
core/rules/
  rule_hooks.gd     hook catalogue: name → int id, kind (event|pipeline|query|first_wins),
                    context vars, legal op groups, priority bands
  rule_compiler.gd  JSON → node objects; macro expansion; type inference; constant folding;
                    errors carry JSON pointer paths
  rule_nodes.gd     one class per operator (Const, Var, Param, CEq, AAdd, CIn, CountDice, …)
  rule_ops.gd       one class per effect op (EFlatAdd, EDamage, ERes, EBossPhase, …)
  rule_index.gd     per-run and per-fight dispatch tables of owner instances, params folded
  rules.gd          API: fire(hook, ctx), query(hook, base), first(hook), fire_die(...),
                    preview(...); pooled contexts; AttackCalc (typed accumulators)
  rule_state.gd     limits, resources, flags (RunState.rule_state / CombatState.rule_state),
                    serialisation, legacy-key bindings for migration
  rule_rng.gd       named streams
  rule_trace.gd     ring buffer + "explain last attack"
core/content/content_api.gd   FORMAT + CAPS (hooks, ops, vars, selectors, natives, statuses, offers, look.*)
```

- **Load**: `ContentDB.ensure()` merges sets (distribution design §4.3), then compiles every rule
  once into immutable shared objects (measured 29 ms for 615 rules on desktop; mobile can compile
  lazily per owner at first activation). Compile errors disable the set, never crash.
- **Index**: built at run start and whenever owners change (passive gained, rune assigned,
  equipment fixed at run build, pet assigned, fight begin, summon). The prototype uses a cheap stamp
  (`passives.size()`); production uses an explicit `owners_changed` notification. Each hook maps to
  an array of owner instances **pre-sorted** by (prio, owner order, rule index), with owner params
  folded into constants.
- **Call sites** stay one line: `if run.rules.has(H): Rules.fire(H, ctx)`. `has` is a byte-array
  lookup by int hook id; contexts are pooled on `CombatState`/`GameFlow`.
- **Pipelines** accumulate into a typed `AttackCalc {sum, bonus, flat, mult, factor, times[],
  act[]}` instead of dictionaries.
- **Order**: hook stages fixed by the engine → prio → owner order (kind, slot, acquisition) →
  rule index. No iteration over mutable dictionaries decides order.
- **Speed-ups beyond the prototype** (target ≤ 1.5× native): fold params at index build (the
  prototype still looks them up); specialised nodes for single-filter `count_dice` and
  small-constant `in`; **per-combo lookup tables** for `attack.combo_mult` rules whose only
  condition is a combo set (N rules collapse into one array lookup plus announce list); int op ids;
  no announce dictionaries in bot/preview mode.

### 6.2 Measured cost (prototype, desktop headless, Godot 4.7.2)

| Measure | Value |
|---|---|
| GDScript primitives | virtual call 0.12 µs; `dict.get` 0.13 µs; `match` on a string (10th case) 0.53 µs vs int 0.39 µs; 3-key dict literal 0.47 µs |
| First prototype (string-dispatched nodes) | 14 µs per rule |
| Specialised node classes (final prototype) | `in(var, list)` 0.70 µs; `count_dice` 1.29 µs; `min(15, idiv(var, 8))` 1.38 µs; `Ctx.new` 2.99 µs |
| Hook with no listeners | 1.26 µs (0 with the `has` byte check) |
| 5 passives on `attack.pips` (4 fire) | **34.9 µs data vs 10.6 µs native** (7.0 µs per firing rule incl. its event) |
| 3 passives on `attack.combo_mult` (2 fire) | 17.2 µs |
| Engine-only replay (54,869 commands, heavy forcing) | A 7.03–7.34 s, B 8.32–8.64 s: **+15–20 %** (≈ 130 → 155 µs per command) |
| Real sim, greedy, 66 runs `--profile=max` | 8.5–8.7 s → 8.8–9.0 s: **+3.5 %** |
| Real sim, realistic AUTO, 44 runs `--profile=max` | 40.6 s → 42.0 s wall: **+3.4 %** |
| Golden harness, greedy + forcing, 220 runs | 23.0 s → 25.7 s: +11 % (includes JSON hashing) |
| Compile | 41 rules / 249 nodes: 3.4 ms incl. parse; **615 rules / 3,735 nodes: 14 ms parse + 29 ms compile** |

**Projection for full conversion.** A late-game run has about 40–70 active rules (≤ 10 passives,
6 slots × 1–4 item rules, ≤ 6 runed dice, a pet, a class, a biome, the fight's enemies, ≤ 10 keys),
of which 10–25 evaluate per attack. That is **≈ 50–150 µs per attack** before the §6.1 speed-ups:
+10–20 % engine time, and a few percent on sims, because bot decisions dominate (`decide()` averages
1.6 ms). Interactive play is unaffected: even at 5× slower mobile CPUs, rule evaluation is ~1 ms
per command against multi-second animations. Web (GDScript in WASM) has the same headroom.

### 6.3 Determinism and RNG streams

- **During migration**: rules draw from `run.rng` at the same points as today (the prototype did,
  and 220/220 goldens matched, including Rune Echo's chance and random targets).
- **Normalisation release (R13)**: move to named streams derived with an explicit hash (not
  Godot's `hash()`; plan 1.3): `dice` (combat and board rolls), `enemy` (intents, summons, enemy
  randomness), `board` (generation, mutation, placement), `loot` (chests, shop stock, drafts,
  rewards), `event`, `minigame` (seed per play), plus **one stream per rule owner**
  `hash(seed, kind, id, rule)` advanced per draw. Adding a passive then never shifts any other draw,
  which is the plan's M1.3 goal extended to rules. One golden re-baseline.
- Chance draws come after `if` and `limit`; random selectors draw from the owner stream; `roll`
  draws `n` values in order.
- No wall-clock, OS or locale variables exist in the vocabulary. Float order follows priorities.
  Casts are explicit. Runs and replays record the ruleset fingerprint (plan 2.5).

### 6.4 How the AUTO bot values data-defined content

Today the bot copies rules (`CombatModel` flags, `_item_model`, `_class_model`, `_moon_model`,
tile values) and keys taste tables by id (§1.8). With data:

1. **The same queries, not copies.** Tile, shop, heal, dodge and hazard values call the query
   hooks (`query.campfire_heal`, `query.shop_price`, `query.dodge_min`…). The copies at
   `bot.gd:2320-2340` disappear.
2. **Model compiler.** `_combat_model` (`bot.gd:1213`) walks the active pipeline rules and folds
   known shapes into `CombatModel` features, generalising today's per-id flags into vectors:
   per-combo mult adds and floors (Pair Master, Crowd Pleaser, Oath, Great Arc…), per-combo flats
   (Twin Edge, Deadshot, Straight Shooter), per-face-value flats and bonuses (`count_dice eff = v`:
   Snake Eyes, Boxcars, Brawl), kept/rerolled counts (Steady Hand, Steady, Flow), runed-in-group
   counts (Channel), first-attack and turn-1 factors (First Strike, Opening Salvo, Ambush), constant
   flats (Midas at the current gold), per-target flats (resources keyed by target: Rampage), and
   resource threats (`ai.resource`: the Moon King's meter). The hot keep-set search stays in packed
   arrays; no rule is interpreted per sample.
3. **`ai` hints** for what the model can't see, in the **same value language** evaluated by the same
   evaluator with bot variables (`pv`, `laps_left`, `frac`, `hp_pt`, `gold_pt`, `reroll_v`). This is
   exactly what `_passive_value` hand-codes per id today (`bot.gd:1879-1948`). Treasure Sense
   becomes `{"pv": {"mul": [13.5, {"var": "laps_left"}, {"var": "gold_pt"}]}}`. `ai.cat` and
   `ai.score` replace `RUNE_SCORE`, `KIND_SCORE`, `PASSIVE_SCORE`, `PASSIVE_CAT`, `TRINKET_PREF` and
   `BEST`.
4. **Preview.** `Rules.preview_attack(state, values)` runs the pipeline hooks without side effects
   (announce off, chance → expectation, limits read-only). At ~35 µs per 5 rules it is fine for
   pool valuation (120 samples ≈ 4 ms, cached per state key), not for the per-sample search.
5. **Calibration.** `tools/ai_calibrate.gd` runs A/B sims with and without a new owner and suggests
   its `ai.pv`. CI warns when a set adds an owner with neither a foldable shape nor an `ai` hint.

### 6.5 Validation in CI (content train)

1. **JSON Schema**, generated from `rule_hooks.gd` and `content_api.gd`, so it can't drift from the
   engine (Python `check-jsonschema`).
2. **Semantic pass** `tools/content_validate.gd` (headless, the real compiler):
   - unknown hooks, ops, vars and natives;
   - **type inference** on every node (int, float, bool, string, list, die, enemy, tile); int-typed
     effects need an explicit cast;
   - **hook/op compatibility**: pipeline ops only on pipelines, no state changes on queries,
     combat-only ops only in combat;
   - selector validity in context; `limit` and `resources` sanity;
   - budgets: depth ≤ 8, ≤ 64 nodes per rule, ≤ 16 rules per owner, `repeat` ≤ 8;
   - references: enemy ids, tile kinds, runes, string keys and look paths; tier arrays of 3, level
     arrays of 10;
   - `requires_caps` computation.
3. **Trigger-cycle analysis.** Build a graph of hook → the ops its rules run → the hooks those ops
   can cause (`damage` → `damage.enemy`, `enemy.killed`, `boss.phase`; `block` → `block.gained`; an
   observer → its event type). Any rule on a cycle must carry a `limit`. This proves termination on
   top of the runtime depth guard.
4. **Fuzz.**
   - *Grammar fuzz*: random rules generated from the catalogue, run against random states. The
     evaluator must never crash, must stay within budgets, and must be deterministic.
   - *Owner fuzz*: each new owner runs in ~200 fight and board states snapshotted from sims. HP,
     gold and dice stay within bounds, and event shapes validate.
5. **Sim guard.** N runs per class with the set vs without it; the win-rate delta must stay in
   band; PV calibration (§6.4).
6. **Goldens** for base sets (§6.6); fixture sets per kind (plan 2.9).

### 6.6 How the sim and goldens guard the migration

The prototype harness is the template for plan 1.1:

- `tests/test_rules_golden.gd`: greedy bot over class × config (legacy, max profile, A10, forced
  boss fights) × seeds, with **forced content** (random passives and runes per run, rotating item
  variants, forced routes and bosses) so that every converted owner fires. It hashes every event
  list and the final `GameFlow.to_dict()` with SHA-256. The prototype's 220-run set takes 23 s.
- `tools/golden_dump.gd`: dumps per-command events for one run so that two builds can be diffed to
  the first divergence. The prototype found a real hazard this way: a `match` wildcard `_:` placed
  before the Gilded and Lucky cases silently swallowed them. The goldens caught it on the first run.
- Each migration step must leave `tools/sim.gd` output **byte-identical** (except timing lines) for
  `--policy=greedy` and `--policy=realistic` on a fixed seed, as the prototype showed.
- A **coverage counter** per owner (rule firings during the golden run) must be > 0 for every
  converted owner. The prototype fired 90,078 evaluations.
- **Priority bands** let native code and data rules interleave in exactly today's order while a
  domain is half-converted (`Rules.fire(hook, ctx, lo, hi)` at each native site). The prototype
  used bands 200–299 and 500–599 inside `ItemLogic.after_hit`.

### 6.7 Debugging tools

- **Rule trace** (ring buffer, ~500 entries): hook, owner instance, rule id, outcome (condition
  false, limit, chance miss, fired), `let` values, effect results, events emitted.
- **Dev menu "Rules" section** through the existing registry (`ui/modals/dev_menu.gd:43-59`
  `register_section`/`register_row`):
  - live trace filtered by owner;
  - **"explain last attack"**: sum, bonus, mult, flat and factor with each rule's contribution;
  - active owners with their folded params and resource values;
  - "copy state" (a snapshot for `rule_play`).
- `tools/rules_trace.gd --log=<replay> [--owner=passive:snake_eyes]` replays a command log with
  tracing. `tools/rule_play.gd --rule=<set>/<owner>#<rule> --state=<snapshot>` runs one rule
  against a snapshot.
- Validator messages carry a JSON pointer, the hook's variable list and a "did you mean".
- An unknown `fx` falls back to a generic popup; a debug overlay shows owner ids on beats.

### 6.8 Versioning of primitives (`caps@version`)

- `content_api.gd`: `FORMAT` (the rule syntax major) and `CAPS` = `{"hook": {"attack.pips": 1, …},
  "op": {"damage": 1, …}, "var": {"combo.set_value": 1, …}, "sel": {…}, "native": {"refire_rune": 1,
  …}, "status": {…}, "offer": {…}, "look.fx": {…}}`. This extends the design's `{kind: {primitive:
  version}}` (§4.4) from rule ids to the vocabulary itself.
- CI computes a set's `requires_caps` by walking its compiled rules. Authors never write it.
- A semantics change bumps the version; the core may support ranges (`[1, 2]`); new names are
  preferred. A primitive is never removed while a supported set uses it.
- The client drops sets whose caps it can't meet before downloading their packs, and shows
  "Update the game to get *Set X*" (design §4.4). Runs pin their ruleset fingerprint (plan 2.5).
- Balance sets may patch only `params`; rule structure (`on`, ops, `if`) is an identity field, so a
  change is `retire` + `add` of a rule id.

### 6.9 Store policy

The vocabulary interprets closed JSON: no scripting language, no downloaded GDScript, no
`Expression`, no loops or recursion, and bounded evaluation (§2.1, §6.5). That keeps sets "data"
under Apple 2.5.2 and Google Play's Device and Network Abuse policy (research files 04 and 05).
Apple 2.3.1 concerns (hidden features switched on remotely) are handled as the design already says:
**primitives ship in reviewed binaries with a base use**, and data only recombines them. Don't
dark-ship primitives with no base content.

---

## 7. Refactor plan (replaces plan step 2.3)

### 7.1 Steps

| Id | Step | Main files | Agent-days | Depends | Done when |
|---|---|---|---|---|---|
| **R0** | Engine core: hook catalogue, compiler, nodes, ops v1, selectors, limits, chance, resources, flags, index, contexts, `AttackCalc`, legacy-RNG mode, trace buffer, unit tests | new `core/rules/*`, `core/content/content_api.gd`, `tests/test_rules_engine.gd` | 6–8 | 1.1, 2.1 | engine tests green; compiles the prototype's 41 rules |
| **R1** | Hook points wired at every §1 site (~60), native owners untouched | `core/combat.gd`, `game_flow.gd`, `run_state.gd`, `board.gd` | 3–4 | R0 | goldens identical; empty-listener cost ≤ 1 % |
| **R2** | Passives → data (32); `Balance.PASSIVE_*` → params; `has_passive` sites gone | `combat.gd`, `game_flow.gd`, `run_state.gd`, `core/content/passives.gd`, base set JSON | 2.5–3.5 | R1 | goldens identical; `grep has_passive(` = 0 outside the bot |
| **R3** | Runes → data (12): `when`, caps, `no_double`, effects, `refire`; Grimoire memory by id | `combat.gd:408-658`, `runes.gd`, `balance.gd`, `pet_logic.gd`, `class_logic.gd` (Turret runes) | 1.5–2 | R1 | goldens identical |
| **R4** | Armory → data (51 rules, 51 variants, 13 back): params, std scaling modes, variant param mods, special-case fields, `MetaRun.armory_stats` via `run.start` rules; `ItemLogic` keeps only helpers | `item_logic.gd`, `items.gd`, `meta_run.gd`, `combat.gd` | 7–9 (two lanes: weapons + off-hands / armour + trinkets) | R1, R3 | goldens identical; `ItemLogic.has/sec(` = 0 outside the bot |
| **R5** | Potions, affixes, ascension, events (choice trees), shop/draft/reward/signature tables, offers | `game_flow.gd` (`_drink`, `_open_event`, `_shop_*`, `_reward_options`), `affixes.gd`, `unlocks.gd`, `combat.gd` | 4–6 | R1 | goldens identical; unknown potion = validation error |
| **R6** | Pets → data: charge resource, fire, perks, L5/L10; `schedule`, `status.tick`, `free_reroll` | `pet_logic.gd`, `game_flow.gd` (9 sites), `combat.gd` (3), `pets.gd` | 3–4 | R1, R3 | goldens identical; `has_pet(` = 0 |
| **R7** | Biomes and tiles: twists as biome rules, tile-kind registry (`tile.land`/`tile.pass`), moon phases, board-gen params, keyed counters (`biome_visits`…) | `game_flow.gd:452-560,1401-1545`, `board.gd`, `biomes.gd`, `profile.gd:401-437`, `unlocks.gd` | 4.5–6 | R1 | goldens identical; fixture biome with a new tile kind plays |
| **R8** | Enemies: traits and affixes as enemy rules, intents as op compositions over native enemy ops, the status framework, boss mechanics as resources (moon meter), `tags` replace `SKELETONS`, `all_ids` from DB | `combat.gd:115-1193`, `enemies.gd`, `affixes.gd`, `item_logic.gd:745`, `unlocks.gd:86-105` | 3.5–5 | R1 | goldens identical; fixture enemy with a new intent composition plays |
| **R9** | Classes: 7 mechanics as resources + rules, `mechanic_params` per class, side dice (Turret), ★ face native | `class_logic.gd`, `heroes.gd`, `run_state.gd:94`, `die.gd` | 4.5–6 | R1, R3, R6 (Wild Bond) | goldens identical; fixture class reusing Oath with other params plays |
| **R10** | Bot: model compiler, query reuse, `ai` hints and PV expressions, preview, calibration tool; id tables removed | `bot.gd`, `bot_meta.gd`, new `tools/ai_calibrate.gd` | 5–8 | R2–R9 (incremental) | realistic sim unchanged on base content; fixture owners valued sanely (±10 % of calibrated PV) |
| **R11** | CI: generated schemas, semantic validator, cycle analysis, caps, grammar and owner fuzz, per-set sim guard | `tools/content_validate.gd`, `tools/ci/*`, `ci.yml` | 4–5 | R0 (grows with each domain) | fixture sets with each error class fail with a clear message |
| **R12** | Presentation: generic `rule_triggered` beat with `fx` hints, generic resource meter/badge/pips widget, dev-menu Rules section, "explain last attack" | `game/flow/event_player.gd`, `game/classes/class_beats.gd`, `ui/hud/*`, `ui/modals/dev_menu.gd` | 3–5 | R1 | screenshot matrix unchanged; a fixture owner with an unknown fx shows the generic beat |
| **R13** | Normalisation: RNG streams, canonical event shapes, generic limit/resource keys, save migration; **one** golden re-baseline | `core/rng.gd`, `rules/*`, `run_state.gd`, `profile.gd`, presentation handlers | 2–3 | R2–R9 | a new passive added to a fixture leaves existing seeds unchanged |
| | **Total** | | **≈ 54–75** | | |

Compared with the plan's 2.3 (20–29 d) plus 2.4 (3–4 d), that is about **+31–42 agent-days**. In
exchange, there is one engine instead of eleven per-domain rule-id switches. New content in any
domain is data, the bot and presentation become generic, and every later primitive is a small,
versioned addition.

The other M2 steps stay, with small changes:

- 2.1 (ContentDB): unchanged.
- 2.2 (constants): engine formulas only; owner numbers live in owner `params`.
- 2.4 (caps and CI): absorbed into R11, with vocabulary caps.
- 2.5 (runs pin sets): unchanged.
- 2.6 (looks): adds `fx` hints and resource `ui`.
- 2.7 (dressing): unchanged.
- 2.8 (strings): adds rule-text templates.
- 2.9 (tests): fixture owners per kind.

### 7.2 Parallelism

- **Serial spine**: M1.1 goldens → 2.1 ContentDB → R0 → R1.
- **After R1, in parallel worktrees**, each gated by the goldens:
  - lane A: R2 → R3 → R4-a (weapons, off-hands);
  - lane B: R4-b (armour, trinkets) → R5;
  - lane C: R6 → R9;
  - lane D: R7 → R8.
- R11 grows alongside every lane: each domain adds its validators. R12 and R10 start once two
  domains are converted. R13 goes last.
- Assets are needed only for R12's visual checks and the plan's 2.6/2.7.

### 7.3 Minimal path: "a new class, a new map/biome, a new pet, new relics and new weapons all ship as data"

| Step | Why it's on the path | Days |
|---|---|---|
| M1: 1.1 goldens (the prototype harness), 1.2 saves never drop content, 1.3 stable seeds | safety net; pack content must not erase saves | 4–6 |
| 2.1 ContentDB + base sets in JSON | where data lives | 4–5 |
| 2.5 runs pin their content set | replays and sims | 2–3 |
| R0, R1 | the engine | 9–12 |
| R2 relics, R3 runes | relics; items and pets reference runes | 4–5.5 |
| R4 Armory | weapons | 7–9 |
| R6 pets | pets | 3–4 |
| R7 biomes and tiles | a new map (rules) | 4.5–6 |
| R9 classes | a new class (mechanic from resources + rules, or reuse one with new params) | 4.5–6 |
| 2.6 looks as data (items, classes, pets via existing builders, biome kit) + 2.7 kit reuse | visuals from JSON | 7–11 |
| 2.8-lite string keys for pack text | new text | 1–2 |
| R10-lite (model compiler for pipeline shapes + `ai` hints), R11-lite (schema + semantic + caps), R12-lite (generic beat + meter) | AUTO, CI and presentation for new content | 7.5–10.5 |
| Pilot sets (one per domain) through CI to `dev` | proof | 2–3 |
| **Total** | | **≈ 62–83 agent-days** |

The critical path is 1.1/1.3 → 2.1 → R0 → R1 → R4 → R12-lite → pilot, about **26–35 working days
elapsed** with four lanes. R8 (new enemies with new intents) and R5 (events, potions, ascension) are
not on this path: new enemies from today's intents are already data after 2.1 plus looks, and new
events can wait. The shortcut of shipping new data items **alongside** today's id-dispatched ones
(skipping R4's conversion) saves ~5 d but leaves two item systems and a bot that models only the
native ones. It is not recommended.

---

## 8. Risks and open questions

| Risk | Mitigation |
|---|---|
| **The DSL grows into a programming language** (store review, complexity) | Closed catalogue, budgets, no loops or recursion, cycle analysis (§2.1, §6.5); new power comes as named primitives, reviewed in binaries |
| **Authoring burden**: JSON rules are verbose | archetype macros (§5), per-kind templates in `content/schema/`, the validator's "did you mean", the rule trace, `rule_play` |
| **Behaviour drift during migration** | goldens with forced content, byte-identical sims, priority bands, R13 as the only re-baseline (§6.6) |
| **Performance on low-end mobile and Web** | measured headroom (§6.2), §6.1 speed-ups, lazy compile, the model compiler keeps the bot off the interpreter |
| **AUTO undervalues new content** | query reuse, model compiler, `ai.pv`, calibration sims, CI warning (§6.4) |
| **Event-shape inconsistencies leak into data** (Vampire without `max_hp`, Iron Skin without `source`) | legacy shims only during migration; canonical shapes in R13 with a presentation audit |
| **Hidden-feature review risk** (Apple 2.3.1) | primitives ship with base content and release notes (§6.9) |
| Open: `invoke` and `let` add power; keep `invoke` or duplicate rules? | keep `invoke` acyclic and depth 1; revisit after R9 |
| Open: observer hooks on every event type? | start with a whitelist (gold, block, hp, status, die_added, face_changed, rune_assigned); expand on demand |

---

## Appendix A: the prototype

Location: `rules-prototype/` in this folder (the throwaway scratch projects themselves were not kept).
The repo was not touched. Both projects are plain Godot projects holding a copy of `core/` (which
is asset-free) and `tools/sim.gd`.

| Path | What |
|---|---|
| `A/core/` | `core/` at `3209adf`, unchanged |
| `B/core/rules/rules.gd` | the evaluator (893 lines): node classes, effect classes, compiler, per-run index, per-enemy dispatch, limits, resources with `bind`, announce, native values |
| `B/core/rules/rules_base.json` | 41 rules: 25 passives, 12 rune activation predicates + ember/echo/vampire, the Arming Sword + 5 variants, ascension `shop_tax`, the Moon King |
| `B/core/{combat,item_logic,game_flow,run_state}.gd` | native blocks replaced by `Rules.fire(...)` calls at the same sites: 224 lines removed, 142 added (`diff -ru A/core B/core --exclude=rules`) |
| `patch_b.py` | most of the B edits as exact-string patches (the Moon King edits were applied inline) |
| `A/golden.gd` = `B/golden.gd` | A/B harness: greedy bot, configs `legacy`, `max` (max-preset meta, Arming Sword variants rotating), `a10`, `moon` (forced Moonlit route and Moon King boss, A9 and Moonfang variants); forced random passives and runes; SHA-256 over every event list and the final state; `--dump=` for first-divergence diffs; `--logs=` records command logs |
| `A/replay.gd` = `B/replay.gd` | replays recorded logs and times the engine alone |
| `B/micro.gd`, `B/prim.gd`, `B/compile_bench.gd` | micro-benchmarks (§6.2) |
| `outA.txt`/`outB.txt`, `finalA.txt`/`finalB.txt`, `outA_moon.txt`/`outB_moon.txt`, `simA_g.txt`/`simB_g.txt`, `simA_r.txt`/`simB_r.txt` | results |

Rerun (from `rules-exp/A` or `rules-exp/B`; import once with `godot --headless --import --path .`):

```
godot --headless --path . -s golden.gd -- --runs=5 --cfg=legacy,max,a10,moon
godot --headless --path . -s replay.gd -- --logs=../logs.json --reps=3
godot --headless --path . -s tools/sim.gd -- --runs=4 --class=all --seed=11 --profile=max --policy=realistic --items
godot --headless --path . -s micro.gd          # B only
```

Final results:

- `golden.gd --runs=5 --cfg=legacy,max,a10,moon`: A `TOTAL db08be0edebe79c3`, B
  `TOTAL db08be0edebe79c3`; 72,695 commands, 9,321 attacks; B fired 90,078 rule evaluations.
- `sim.gd` greedy (66 runs) and realistic (44 runs): identical output apart from `time=` and the
  `decide()` timing line.
- Moon King fights: every `moon_meter` source (`start`, `moonfang`, A9 start 2, `tide` ×867,
  `clouds` ×154, `moonrise` ×126, `moonfall` ×83 over 88 fights) matched.

What the prototype taught (it all feeds §2 and §6):

1. Parity needs the **same float order, RNG draw points and `elif` semantics**. Priorities plus
   `stop` reproduce them without special cases.
2. **Event shapes and state keys are behaviour**, to the bot and to presentation. They need a legacy
   shim now (`legacy_key`, `shape: "no_max"`, resource `bind`) and a clean-up later (R13).
3. `skip_zero` removes the most common authoring duplication ("if count > 0 then add count").
4. The first naive evaluator (string `match` dispatch) cost 14 µs per rule. One class per operator
   halved it. Folding params and per-combo tables are the next steps.
5. Goldens with forced content catch migration slips immediately (the misplaced `match` wildcard).

---

## Appendix B: migration shims the prototype needed (to remove in R13)

| Shim | Why | Clean-up |
|---|---|---|
| limit `key` = `uses_sword`, `chill` (in `CombatState.item_state`), `phoenix_act` (an act number), `second_wind_used` (a bool) (in `run.passive_state`) | today's bot and saves read these keys (`bot.gd:1225`, `item_logic.gd:555`) | generic `rule_state` keys + save migration |
| resource `bind: "moon"` | `bot.gd:1343` and `CombatState.moon_king()` read `CombatState.moon` | generic resources + `ai.resource` model |
| `shape: "no_max"` on heal | Vampire's `hp_changed` lacks `max_hp` (`combat.gd:649`) | canonical `hp_changed` |
| block without `source` | Iron Skin's `block_gained` has none (`combat.gd:268`) | canonical `source` = owner |
| announce value from `$result` vs a param | Vampire announces the healed amount, Bloodthirst the nominal 3 | keep both, documented |
| priority bands inside native functions | half-converted `ItemLogic.after_hit` | removed when the domain is fully data |
| `run.rng` for chance and random targets | seed parity | per-owner streams (§6.3) |
