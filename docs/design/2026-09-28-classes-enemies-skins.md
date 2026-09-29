# Diceroll: new classes, enemies, affixes and skins

Date: 2026-09-28 · Author: senior game design pass · Status: proposal. Numbers are starting values
for the sim, not final.
Reads with: docs/specs/2026-09-28-diceroll-design.md (§5–7, §15, §16 and "§16 decisions"),
docs/plans/balance.md ("Current balance" is authoritative) and
docs/reviews/2026-09-28-meta-design-review.md.

Constraints this design keeps:
- 2 starting dice, pool cap 5.
- Movement is automatic (the two most common values). The only board choice is GO or Reroll, so
  no class adds a movement choice.
- No drafts from kills.
- Everything is deterministic and never sold for money.
- Knight-only start.
- The balance reference is the **realistic** bot.
- Sim targets (A0, standard mode): fresh 30–40%, mid 45–50%, max 55–65%, max A10 20–30%, and the
  expert bot at or below about 80% on a fresh profile.

---

## 0. Summary

- **6 new classes in two waves.**
  - Wave 1: **Paladin, Ranger, Ninja, Druid** (S/M complexity).
  - Wave 2: **Necromancer, Engineer** (M/L).
  - Each one owns a build archetype that no current class covers, through one mechanic built on
    the dice.
- **Unlocks run across ~32 runs** (10 classes in total).
  - At most one new class every ~3–5 runs.
  - Each class has a thematic milestone plus a fallback of "or play N runs".
  - Sigil prices rise to 10/12 for the late classes, and Sigils can only buy the *next two*
    classes.
- **8 new enemy ids** from on-tone models:
  - 6 regulars/elites: skeleton Cutthroat and Golem, Orc Raider and Drummer, Werewolf, Fallen
    Paladin.
  - 2 mini-bosses: Moonfang and the Orc Warchief.
  - They need 3 small new mechanics: `frenzy`, `rally` and `transform`.
- **Enemy affixes (10)**:
  - They roll at tile spawn, so the board preview telegraphs them.
  - Their rates are gated by lap band and elite status, and they are off for the first ~3 runs.
  - The visual language is: **body texture = strength tier**, **overlay colour + prop + badge =
    rule**.
- **Skins**:
  - Each class has a default plus 3 alternates.
  - They unlock from class wins, class A3/A6 wins or "beat every final boss" with the class.
  - After the Crowns caps they can also be bought for 250 Crowns.
  - You equip them in a Camp **Wardrobe** (a mannequin stand).
  - One A10 prestige variant per class can never be bought.
- **Off-tone models are excluded:** Survivalist, Robot, Space Ranger, Driver, Action Figure,
  Clown, Animatronic and Monster Costume. Modern clothes, props and "Barry's Funhouse" shirts
  break the crypt/hollow fantasy.

---

## 1. New hero classes

### 1.1 Archetype map (why these six)

| class | core archetype | what it wants from the run | who it overlaps with (and why it's still distinct) |
|---|---|---|---|
| Knight (existing) | Block / prevent | Guard, Iron Skin | – |
| Barbarian (existing) | Big pips, flat ATK | Heavy, Giant, High | – |
| Mage (existing) | AoE + multiplier | Ember, Echo, sixes | – |
| Rogue (existing) | Poison + banked rerolls | Venom, Lucky, board rerolls | – |
| **Paladin** | **Sustain: surplus Block becomes healing, then damage** | Twin dice, Guard, Iron Skin, Guard Die pet | Knight blocks to *prevent*; the Paladin over-blocks on turns when enemies don't attack, and converts the surplus |
| **Ranger** | **"Take what you roll": no-reroll precision, overkill carry** | Loaded/High/Even, Forge raises, Steady Hand, Opening Salvo | The exact opposite of the Ninja. It wants few rerolls, where the Rogue banks them |
| **Ninja** | **Reroll engine: rerolls that make matches are free** | Thunder, Encore, Crystal Wisp, Reroll Tonic | The Rogue banks rerolls for later; the Ninja spends them all turn long for Thunder procs |
| **Druid** | **Late scaling: dice grow every lap** | Low/Odd dice, Forge, Face Raise, Blacksmith, pets | The only class that is weak at lap 1 and strong at lap 15 |
| **Necromancer** | **Kill-chaining: kills add temporary Bone dice** | Ember/Thunder/Venom AoE, multi-enemy fights | It is a multi-enemy specialist; its single-target weakness is covered by the boss rules below |
| **Engineer** | **Out-of-combo damage: a Turret die** | SIX/ONE/ALWAYS runes (Ember, Frost, Guard, Heavy) on the turret, Forge | The only class whose extra damage never passes through combos |

Dropped or not used as a hero:
- **Necromancer skeleton model:** a skeleton hero reads as an enemy on Crypt and Throne boards.
  The class uses a living hooded human instead (see 1.2.5), and the model goes to an enemy.
- **Werewolf and Orc:** used as enemies.
- **Barbarian_Large:** used as a Barbarian prestige skin.

### 1.2 Class sheets

Stats sit next to the current K60 / B60 (+2 ATK) / M60 / R58 (+1 board reroll). The base is 2
combat rerolls and 1 board reroll.

#### 1.2.1 Paladin: "Dawnguard"

*Fantasy: a holy warrior whose shield glows brighter every time a blow doesn't land.*

| field | value |
|---|---|
| HP / ATK | **64 / 0** · combat rerolls 2 · board rerolls 1 |
| Starting pool | **Twin die (3 3 3 4 4 4) + Guard**, **Standard (plain)** |
| Mechanic | **Aegis of Dawn.** Block left over after the enemy phase heals you for **50%** of it (rounded down, **max 8 per turn**). **Radiance:** the amount healed by Aegis is added as **flat damage to your next main attack** (after the multiplier, before ATK), then cleared. |
| Interactions | Reading intents matters: on block, buff, curse or aim turns, stack Guard and Block for heal plus damage. Twin dice make Pairs likely (50% for 2 Twins) and make the board move steady at 6–8, which leads to frequent doubles (Treasury, Coin Mimic). Guard Die pet, Iron Skin and the Stoneskin potion all feed Aegis. |
| Build archetype | Block stacking, set dice (Twin/Even), Full House Party |
| Attack style | **Melee 1H**: hammer overhead chop (`Melee_1H_Attack_Chop`). Shield raise on block gain. |
| Model / gear | `Paladin.glb` (Mystery S4 #10), `paladin_hammer.gltf` in the right hand, `paladin_shield.gltf` in the left. The helmet variant is a skin. |
| Core hooks | `CombatState._enemy_phase` end: read the leftover `run.block` and heal before the Block reset in `start_turn`. Store `radiance` on CombatState (serialised) and add it in `attack()`. |
| Complexity | **S** |
| Tuning knobs | `PALADIN_AEGIS_PCT 0.5`, `PALADIN_AEGIS_CAP 8`, Radiance on/off |

#### 1.2.2 Ranger: "Deadeye"

*Fantasy: one breath, one arrow. The first roll is the right roll.*

| field | value |
|---|---|
| HP / ATK | **54 / 0** · combat rerolls 2 · board rerolls 1 |
| Starting pool | **Loaded die (1 2 3 4 6 6) + Blade**, **Standard (plain)** |
| Mechanic | **Aim:** if you use **no combat reroll** this turn, your main attack deals **×1.3** (it stacks multiplicatively with Glass Cannon and Opening Salvo). **Piercing Shot:** overkill damage (damage beyond the target's HP after its Block) **carries once** to the next living enemy (left to right). Warded and armor rules apply to the carried hit. |
| Interactions | Every turn asks a real question: reroll for the combo, or take ×1.3 now? Lucky (kept dice bank rerolls) and Steady Hand reward not rerolling, and Aim makes that a class identity. Overkill carry rewards one big hit into 2–3 enemy tiles. |
| Build archetype | Consistent faces: Loaded/High/Even kinds, Forge Raise, Whetstone, Steady Hand, Boxcars, Opening Salvo |
| Attack style | **Ranged**: `Ranged_Bow_Release` (the `bow` attack set already exists in `Character.MODELS.ranger`, and `combat_stage.gd` already maps `ranger` to the "ranged" style) |
| Model / gear | `Ranger.glb` (Adventurers EXTRA), `bow_withString.gltf` in the left hand, `quiver.gltf` on the back |
| Core hooks | CombatState keeps `rerolls_used_this_turn`, and `attack()` applies the Aim mult. `damage_enemy` returns the overkill, and the attack path carries it to the next alive index. |
| Complexity | **S** |
| Tuning knobs | `RANGER_AIM_MULT 1.3`, number of pierce carries (1) |

#### 1.2.3 Ninja: "Shadow Step"

*Fantasy: a blur of blades. Every throw that lands on a match costs nothing.*

| field | value |
|---|---|
| HP / ATK | **52 / 0** · **combat rerolls 3** · board rerolls 1 |
| Starting pool | **Standard + Thunder**, **Odd die (1 1 3 3 5 5, plain)** |
| Mechanic | **Shadow Step:** a reroll is **refunded** if, afterwards, any rerolled die shows the same non-blank value as another die. There are at most **2 refunds per combat turn**, and a reroll is refunded at most once (so Encore and Shadow Step don't double-refund). **On the board**, a board reroll that produces doubles is refunded (max 1 per board turn). |
| Interactions | Thunder fires on *rerolled* dice, so free rerolls mean more Thunder procs. The Odd die has 3 values, so a reroll matches often. Crystal Wisp, the Reroll Tonic and Encore all stack into the same engine. Its fragile HP is the price. |
| Build archetype | Reroll engine: Thunder, Encore, Loaded Hands, Wisp; sets over straights |
| Attack style | **Melee dual / fast**: katana slash (the existing `dual` set, `Melee_Dualwield_Attack_Slice`, or `Melee_1H_Attack_Chop` if a single katana reads better). Thunder procs play a shuriken throw (`Ranged_1H_Shoot`) with `Ninja_Shuriken.gltf`. |
| Model / gear | `Ninja.glb` (Mystery S4 #8), `Ninja_Katana.gltf` in the right hand. Textures A–D are the skins. |
| Core hooks | `CombatState.reroll()` compares values before and after, refunds via `rerolls_left += 1`, and keeps a per-turn counter. `GameFlow.board_reroll()` checks the new `double` and refunds. |
| Complexity | **S–M** (the bot's reroll EV must know about refunds) |
| Tuning knobs | `NINJA_REFUNDS_PER_TURN 2`, base combat rerolls 3 → 2 if it runs hot |

#### 1.2.4 Druid: "Overgrowth"

*Fantasy: plant a seed on lap one. Harvest a forest by the Throne.*

| field | value |
|---|---|
| HP / ATK | **62 / 0** · combat rerolls 2 · board rerolls 1 |
| Starting pool | **Low die (1 1 2 2 3 3) tagged `seed`**, **Standard (plain)** |
| Mechanic | **Overgrowth:** each **lap completion** raises the lowest face of every `seed` die by **+1** (up to its raise cap; a blank 0 becomes 1 first). At each **biome change**, the untagged die with the lowest face sum becomes a `seed` die (max **3** seeds). **Wild Bond:** your equipped pet starts every fight with **+1 charge**. |
| Interactions | The class works through the board: laps are its power curve. The Low starter grows from sum 12 to about 27 by lap 15 (about 4 4 4 5 5 5). Seed dice stay rune-free, so the rune slot is still open. Forge, Face Raise, Blacksmith and Whetstone speed the growth up. Raises land on edited faces, which get the gold rim. |
| Build archetype | Scaling / face economy; pets |
| Attack style | **Magic**: `Ranged_Magic_Spellcasting` with a vine and leaf burst |
| Model / gear | `Druid.glb` (Adventurers EXTRA), `druid_staff.gltf` in the right hand |
| Core hooks | **`Die.tags: PackedStringArray`** (new, serialised, generic, and reused by the Necromancer and Engineer). Hooks: `GameFlow` lap completion → `ClassLogic.on_lap(run)` emits `face_changed {source: "growth"}`; `act_started` → `on_biome(run)`; pet charge init in `PetLogic`. |
| Complexity | **M** (tags, UI leaf badge on seed dice) |
| Tuning knobs | growth per lap (1), max seeds (3), starting kind (Low vs Odd) |

#### 1.2.5 Necromancer: "Bone Harvest" (wave 2)

*Fantasy: every foe that falls gets back up, on your side of the table.*

| field | value |
|---|---|
| HP / ATK | **54 / 0** · combat rerolls 2 · board rerolls 1 |
| Starting pool | **Standard + Vampire**, **Standard (plain)** |
| Mechanic | **Bone Harvest:** each enemy that dies while you are acting (main attack, Ember, Thunder, Poison, pet) adds a **Bone die** (faces **1 2 2 3 3 4**, no rune, tag `bone`) to the pool **for the rest of the fight**. Max **2** Bone dice, and the combat pool is at most **6** dice. Bones roll from the next turn and join combos and runes' ALWAYS effects. When the fight ends, the bones crumble and each one **heals 2**. **Single-foe rule:** against a lone enemy (all bosses, a lone mini-boss) you raise a Bone die at the start of **turns 3 and 6**, and bosses drop one when **phase 2** starts. Summons killed drop bones normally, so the Bone Warden's legion becomes fuel. |
| Interactions | Kill order is a decision: kill the weak one first to gain a die. AoE runes snowball. Summons feed it. |
| Build archetype | Multi-enemy snowball: Ember, Thunder, Venom, Lantern Ghost, Skull Buddy L5 |
| Attack style | **Magic**: `Ranged_Magic_Spellcasting`, green soul flame. Bones rise with `Skeletons_Awaken_Standing`-style dice VFX. |
| Model / gear | **`Rogue_Hooded.glb` with the `rogue_texture_alt_C` palette** (dark magenta and black) plus the **Skeletons pack skull staff** in the right hand. The hero stays a readable living human. The Skeletons **Necromancer** model goes to the Grave Mage mini-boss (section 3). |
| Core hooks | This needs a **combat-local dice list**. Today `CombatState` indexes `run.dice`. Add `CombatState.extra_dice: Array[Die]` and make `dice_values`/`marked`/`locked` span `run.dice + extra_dice`. Emit `die_added {die_idx, temporary: true, tag: "bone"}` and `die_removed` at the fight's end. |
| Complexity | **M/L** (combat indexing touches the bot, UI tray and serialisation) |
| Tuning knobs | `BONE_MAX 2`, bone faces, lone-foe turns (3, 6), crumble heal 2 |

#### 1.2.6 Engineer: "Clockwork Turret" (wave 2)

*Fantasy: why roll one die when a machine can roll another for you?*

| field | value |
|---|---|
| HP / ATK | **58 / 0** · combat rerolls 2 · board rerolls 1 |
| Starting pool | **Standard + Gilded**, **Standard (plain)**, plus the **Turret die** (Standard faces, no rune), which sits outside the pool and doesn't count toward the cap of 5 |
| Mechanic | **Clockwork Turret:** after your main attack each turn, the Turret rolls. It has no rerolls, never joins a combo and ignores curses. It shoots the target for **pips × T**, where **T = 1 / 2 / 3 in tiers 1 / 2 / 3** (biomes). It can hold **one rune**, and only non-combo triggers work: ALWAYS (Guard: Block = pips; Heavy: ×2 shot), SIX (Ember), ONE (Frost), MOVE (Gilded, rolled with the board roll). Offers never propose COMBO/KEPT/REROLLED runes for the turret. The Forge and Face Raise can target the turret. |
| Interactions | Out-of-combo, guaranteed extra triggers each turn: Turret + Ember is one extra 6-check per turn, and Turret + Frost is a 1-in-6 freeze per turn. Gilded makes the economy good for buying runes. |
| Build archetype | Rune-trigger machine (SIX/ONE/ALWAYS), flat damage |
| Attack style | **Melee 1H** wrench bonk (`Melee_1H_Attack_Chop`). The turret has its own fire animation (recoil tween) and `Use_Item` on setup. |
| Model / gear | `Engineer.glb` (Adventurers EXTRA), `engineer_Wrench.gltf` in the right hand. The turret prop is **`turret_base.gltf`** (Adventurers EXTRA assets), placed beside the hero in combat and on the board. |
| Core hooks | `RunState.turret: Die` (serialised, null for other classes). `attack()` resolves the turret after the main hit and emits `turret_fired {value, damage, rune}`. Offer targets gain `"turret"` (rune bind, forge, face raise). The dice tray gets a 6th slot on a side stand. |
| Complexity | **L** (new entity across offers, forge, tray UI, bot valuation) |
| Tuning knobs | T per tier (1/2/3), allowed turret runes, starting turret faces |

### 1.3 Balance expectations and "none dominates"

| class | early (laps 1–5) | late (11–15) | vs final bosses | main risk | first knob to turn |
|---|---|---|---|---|---|
| Paladin | strong (64 HP, Twin pairs) | medium | good (long fights) | Iron Skin + Guard Die making Aegis a free 8/turn | Aegis cap 8 → 6 |
| Ranger | strong (Aim ×1.3 on 2 dice) | medium | good (pierce useless, Aim good) | Aim + Opening Salvo + Glass Cannon stacking | Aim 1.3 → 1.25 |
| Ninja | weak–medium (52 HP) | strong | medium | Encore + Wisp + 3 rerolls = Thunder machine gun | base rerolls 3 → 2 |
| Druid | weak (Low die) | strong | strong | deaths in act 1 with a Low starter | Low → Odd starter; HP 62 → 64 |
| Necromancer | medium | strong on 3-enemy tiles | weak–medium | boss fights | lone-foe bone turns (3, 6) → (2, 4) |
| Engineer | medium | medium–strong (T=3) | good | Turret + Ember/Heavy | T tier 3 → 2.5 |

Rules for every class:
- **Pass criterion:** realistic win% within **±5 pp of the class average** at fresh, mid and max,
  and expert at or below 80% (fresh).
- **Anti-stacking:** class mechanics never trigger Resonance or Rune Echo. They obey
  `RUNE_STACK_MAX` (2) and `WILD_MAX_DICE` (1).
- **Bot awareness is a prerequisite for measuring.** Otherwise the sim measures bot blind spots,
  not class power:
  - Ranger: reroll EV must price in losing Aim.
  - Ninja: reroll cost is below 1 when a refund is likely.
  - Necromancer: target the lowest effective HP first.
  - Engineer: turret rune valuation.
  - Druid: shop valuation of Face Raise ×1.3.
  - Paladin: prefer Guard dice in keeps on non-attack intents.

### 1.4 Shared core additions

- `HeroDefs.DATA[id]` gains:
  - `kinds` (a starting kind per die, parallel to `runes`)
  - `tags` (per die, e.g. `["seed", ""]`)
  - `combat_rerolls` (default `Balance.COMBAT_REROLLS`)
  - `mechanic` (id)
  - `style` (melee_1h / ranged / magic / dual) for presentation.
- **`core/class_logic.gd`** (static, like `PetLogic`) holds every hook, keyed by `run.class_id`:
  - `on_turn_start`, `on_reroll(before, after)`, `on_attack(dmg ctx)`, `on_enemy_killed`,
    `on_enemy_phase_end`, `on_fight_end`, `on_lap`, `on_biome`, `on_board_reroll`.
  - Each returns events. `class_triggered {id, value}` mirrors `passive_triggered`, so the UI
    can pulse the class badge.
- `Die.tags` (serialised; old saves → empty).
- `RunState.turret` (Engineer).
- `CombatState.extra_dice`, `radiance`, `refunds_this_turn`, `rerolls_used_this_turn` (all
  serialised).
- `HeroDefs.IDS` order = unlock order: knight, barbarian, paladin, mage, ranger, rogue, ninja,
  druid, engineer, necromancer.

---

## 2. Unlock pacing

### 2.1 Principles

1. Knight only on run 1. At most **one new class every ~3–5 runs**, and never two class unlocks
   from the same run's milestones.
2. The simpler classes come first:
   - Paladin: no decisions added.
   - Ranger: one decision.
   - The Ninja, Druid, Engineer and Necromancer change how you evaluate dice, so they come after
     the player knows the rune and kind pools (after Rogue at ~15).
3. Every class has a **thematic milestone** plus a **fallback run count**, so no one is ever
   stuck.
4. **Sigils can buy only the next two locked classes** in `HeroDefs.IDS` order (the Camp class
   shelf shows the rest as silhouettes with their milestone). This keeps the early Sigil burst
   (about 6.2 on run 1) from skipping onboarding.
5. New Sigil supply: **class_win first = 2 Sigils** for each new class (+12 in total), so the
   late prices are payable.

### 2.2 Extended class table (target = median run, realistic campaign bot, fresh profile)

| # | class | milestone id | condition | fallback | Sigil price | target run |
|---|---|---|---|---|---|---|
| 1 | Knight | – | starter | – | – | 1 |
| 2 | Barbarian | `brawler` (existing) | Win 45 fights | – | 8 | 1–3 |
| 3 | **Paladin** | `oathsworn` | **Win a run with the Knight** | or play 8 runs | 8 | **6** |
| 4 | Mage | `champion` (existing) | Defeat 7 mini-bosses | – | 8 | 10 |
| 5 | **Ranger** | `pathfinder_trail` | **Reach the final boss with 3 different classes** | or play 16 runs | 8 | **13** |
| 6 | Rogue | `veteran` (existing) | Win 8 runs, or play 15 | – | 8 | 15 |
| 7 | **Ninja** | `shadow_pact` | **Win a run with the Rogue**, or **use 1,800 combat rerolls** | or play 22 runs | 10 | **19** |
| 8 | **Druid** | `long_road` | **Complete 250 laps in total** | or play 26 runs | 10 | **23** |
| 9 | **Engineer** | `tinker_bench` | **Edit 60 die faces** (Forge edits + Face Raises, new counter `face_edits`) | or play 30 runs | 12 | **27** |
| 10 | **Necromancer** | `grave_calling` | **Defeat the Bone Warden twice**, or **defeat 1,000 enemies** (new counter `kills`) | or play 36 runs | 12 | **32** |

Notes:
- Estimates come from today's campaign rates:
  - rerolls about 92 per run (so 1,800 ≈ run 19–20)
  - laps about 11 per run (250 ≈ run 22–23)
  - Forge + raises about 2.5 per run (60 ≈ run 24–27; calibrate)
  - kills about 32 per run (1,000 ≈ run 31).
- Every threshold is a **sim-calibrated constant**. Run `--campaign=40 --campaigns=5` and adjust
  until the medians land within ±2 runs of the target.
- Other unlocks already sit at runs 14–24 (pets, packs, minibosses). Move **`warden_slayer`**
  (target 22) and **`rune_lord`** (24) so no run unlocks a class *and* 2+ other things. The rule
  is at most one "major" toast (class/pet/biome) plus one minor (pack/gear/potion) per run.
- **Pass criteria (campaign sim):**
  - All 10 classes by a median of **run ≤ 32**.
  - 90% of profiles have every class by **run 40**.
  - No run in the median campaign unlocks 2 classes.
- `core/meta/presets.gd` **mid** (run 10) becomes Knight, Barbarian, Paladin and Mage. **Max**
  has all 10.
- New `Profile.COUNTERS`: `face_edits`, `kills`, `classes_at_boss` (derived from the new
  `records.bosses_reached_by_class`), plus `wins_by_class` conditions. `_cond` gains the forms
  `{class_wins: id, min}` and `{boss_kills: id, min}` (backed by
  `records.boss_kills: {boss_id: n}`).
- `UnlockDefs.SIGIL_PRICE` gains a per-id override: `SIGIL_PRICE_BY_ID := {"classes": {"ninja":
  10, "druid": 10, "engineer": 12, "necromancer": 12}}`. `sigil_cost()` also enforces the
  next-two rule.

---

## 3. New enemies

All of these use existing mechanics except three scoped additions, which are reused by the
affixes in §3A:
- **`frenzy` trait:** after surviving a hit from your *main attack*, the enemy gains **+2
  attack** permanently for the fight (max **+6**). It shows the buff badge. Poison, Ember and
  Thunder don't trigger it.
- **`rally` intent:** every living enemy (the caster included) gets **+N attack** for the fight.
  It is the `buff` intent applied to all allies, and it scales like `buff`.
- **`transform`:** a regular enemy or mini-boss with `phases: [p1, p2]` switches pattern at
  ≤50% HP, once, reusing the boss phase code. On the switch it drops its Block, re-rolls its
  intent from p2 and emits `enemy_transformed {enemy_idx, form}`. Presentation swaps the model
  (Werewolf_Man → Werewolf_Wolf).

### 3.1 Roster (base stats before lap scaling; compare minion 12, warrior 20, bandit 18, brute 38, bone knight 34)

| id | name | model (texture) + gear | HP | gold / xp | pattern | trait / mechanic | placement |
|---|---|---|---|---|---|---|---|
| `bone_cutthroat` | Bone Cutthroat | Skeletons `Skeleton_Rogue` (tex A), skeleton dagger | 13 | 5 / 4 | cycle: attack 4 → attack 4 → block 3 | **pierce** (ignores your Block) | Crypt late (replaces cultist) |
| `bone_golem` | Bone Golem | Skeletons `Skeleton_Golem` (tex A), Rig_Large, skull axe | 44 | 13 / 10 | cycle: block 10 → aim → attack 16 | slow, telegraphed smash | **Crypt elite leader** (replaces brute) |
| `orc_raider` | Orc Raider | `OrcRaider.glb` (orc tex A), `Orc_Axe` | 22 | 7 / 5 | cycle: attack 5 → attack 7 | **frenzy** | Glade late (replaces bandit); Magma early (replaces bandit) |
| `orc_drummer` | Orc Drummer | `OrcRaider.glb` (orc tex B), `Orc_Wardrum` + stick | 20 | 7 / 5 | cycle: rally 2 → block 5 → attack 4 | **rally**: a kill-priority target | Frost late (replaces bandit) |
| `werewolf` | Werewolf | `Werewolf_Man` → `Werewolf_Wolf` (tex A), axe in man form | 26 | 8 / 6 | man: block 5 → attack 6; **wolf** (≤50%): attack 5 → drain 6 → attack 9 | **transform** | Hollow late (replaces skeleton_warrior) |
| `fallen_paladin` | Fallen Paladin | `Paladin_with_Helmet` (tex B) under a heavy dark tint (0.75, purple-black), purple eye glow, cracked shield | 40 | 12 / 9 | cycle: attack 9 → heal 6 (all) → block 8 | healer-tank leader | **Hollow elite leader** (replaces brute) |
| `mini_moonfang` | Moonfang | Werewolf (tex B, grey), 1.5×, moon-silver aura | 105 | 30 / 15 | man: block 10 → attack 9 → curse 1; **wolf**: attack 8 → drain 10 → attack 12 | **transform**: the phase switch drops its Block | **Hollow mini-boss candidate** (3rd) |
| `mini_orc_warchief` | Orc Warchief | OrcRaider (tex B), 1.5×, `Orc_Club`, war drum on the back | 100 | 30 / 15 | cycle: summon 1 (orc_raider) → rally 3 → attack 11 → block 8 | summons + rally | **Frost mini-boss candidate** (3rd) |

Presentation-only upgrade (no new id): **`mini_grave_mage` switches to the Skeletons
`Necromancer` model** (tex B), keeping its staff, book and green aura. This is the best fit in
the packs for that name.

Balance notes:
- Each regular *replaces* an existing pool entry, so pool sizes and counts per tile don't change.
  Each biome keeps 3 early and 4 late entries.
- Expected effect per biome is ±1 pp. Check the route table (`--route=...`): every route should
  stay within ±3 pp of the all-route mean.
- Frenzy punishes chip damage and rewards burst (Ranger, Barbarian). Pierce punishes pure Block
  (Knight, Paladin). Rally and heal create kill-priority decisions (Necromancer, Ranger pierce).
  Transform punishes slow finishing (a drain spike at half HP).
- Mini-boss candidates: Hollow goes from 2 to 3 and Frost from 2 to 3. `UnlockDefs.all_ids
  ("minibosses")` gains both. They unlock with `warden_slayer` (run ~22), not on fresh profiles.
- Considered but not in this wave: `bone_mender` (Skeleton_Mage healer for the Throne; overlaps
  the cultist/heal role), and a Skeleton Golem 1.8× as a third Throne final boss (the Throne
  already has two).

### 3.2 Updated pools (changes in bold)

| biome | early pool | late pool | elite leader | mini-boss candidates |
|---|---|---|---|---|
| glade | thorn_sprite, wolf_bandit, skeleton_minion | thorn_sprite, wolf_bandit, skeleton_archer, **orc_raider** | brute | (briar_beast) |
| crypt | skeleton_minion ×2, skeleton_archer | skeleton_minion, skeleton_archer, skeleton_warrior, **bone_cutthroat** | **bone_golem** | (bone_champion) |
| hollow | skeleton_archer, cultist, hollow_wisp, bandit | cultist, bandit, hollow_wisp, **werewolf** | **fallen_paladin** | pumpkin_knight, grave_mage, **moonfang** |
| frost | frost_skeleton, ice_archer, skeleton_warrior | frost_skeleton, ice_archer, skeleton_warrior, **orc_drummer** | brute | frost_warden, bone_champion, **orc_warchief** |
| throne | unchanged | unchanged | bone_knight | – |
| magma | ember_imp ×2, skeleton_warrior, **orc_raider** | unchanged | magma_brute | (cinder_brute) |

### 3A. Enemy modifiers (affixes) shown by skins (user direction)

#### 3A.1 Affix table (exact numbers)

An affix is an extra rule on one enemy. It is stored in the enemy dict as `affixes:
Array[String]` and implemented in `core/content/affixes.gd` (`AffixDefs`) plus hooks in
`CombatState`.

| id | name | rule | numbers | reward mult | excluded on |
|---|---|---|---|---|---|
| `armored` | Armored | the existing **armor** trait (Block never expires) + starting Block | starts the fight with Block = **20% of its max HP** | gold/xp ×1.5 | bone_knight, bone_champion (already armor) |
| `thorned` | Thorned | the existing **thorns** trait | reflect **3** (band 0–2) / **4** (band 3–4), never lethal | ×1.5 | mini_briar_beast |
| `warded` | Warded | a **ward** variant: half damage (rounded up) while **any other non-warded enemy** lives | 50% | ×1.5 | solo spawns (it only rolls on a tile with ≥2 enemies); at most 1 per tile |
| `piercing` | Piercing | the existing **pierce** trait | its attacks ignore your Block | ×1.5 | bone_cutthroat |
| `frenzied` | Frenzied | the new **frenzy** trait | +2 attack per main-attack hit survived, max +6 | ×1.5 | orc_raider |
| `regenerating` | Regenerating | at the start of its action, heals itself | **6% max HP** (min 1); **suppressed while it has Poison** | ×1.5 | thorn_sprite, mini_briar_beast |
| `vampiric` | Vampiric | its `attack` intents become `drain` (same value) | heals by the damage that got through | ×1.5 | hollow_wisp, werewolf (wolf form already drains) |
| `hexing` | Hexing | its 1st action each fight also **curses 1** (locks a die next turn); then every 3rd action | curse 1 | ×1.5 | cultist, frost_skeleton (already curse) |
| `frostbound` | Frostbound | its **first attack** each fight also **chills** (1 die locked next turn) | chill 1 | ×1.5 | ice_archer, mini_frost_warden |
| `gilded` | Gilded | a tougher, richer enemy | HP ×1.4; gold ×3; +2 pet charge on kill | gold ×3, xp ×1.5 | – |

Stacking rules:
1. If an affix would duplicate a trait the enemy already has, re-roll it (up to 3 tries, then
   none).
2. Regulars get at most **1** affix and elites at most **2**. Summons and final bosses never get
   affixes.
3. Trait-type affixes simply add to `traits` (`armor`, `thorns`, `pierce`, `frenzy`), so existing
   code paths handle them.
4. `warded` uses the new trait `ward_allies` (the existing `ward` stays summon-only for the Bone
   Warden).
5. Frost rune "skip next action" skips the affix trigger too (the hexing counter doesn't
   advance).
6. Affixes scale nothing on their own; HP/attack scaling stays the lap curve (Gilded's ×1.4 is
   applied after it).

#### 3A.2 Which affixes each biome can roll

Biome affixes have weight 3 each, and `gilded` has weight 1 everywhere.

| biome | affixes |
|---|---|
| glade | thorned, regenerating (+gilded) |
| crypt | armored, hexing (+gilded) |
| hollow | vampiric, hexing, warded (+gilded) |
| frost | frostbound, armored, piercing (+gilded) |
| throne | armored, warded, hexing, frenzied (+gilded) |
| magma | frenzied, piercing, thorned (+gilded) |

#### 3A.3 Spawn rates (lap band = (lap−1)/3)

| band (laps) | regular enemy: chance of 1 affix | elite leader | elite: 2nd affix | mini-boss |
|---|---|---|---|---|
| 0 (1–3) | 0% | 0% | – | – |
| 1 (4–6) | 6% | 50% | 0% | – |
| 2 (7–9) | 10% | 75% | 0% | A0–A3: none · **A4+: 1 affix from its biome's list** (replaces today's `ASC_MINIBOSS_TRAIT` map) |
| 3 (10–12) | 15% | 100% | 15% | – |
| 4 (13–15) | 20% | 100% | 30% | – |

- **Onboarding gate:** affixes are off until the feature unlock `affixes`. It is granted by the
  `brawler` milestone (run ~3) with a one-time popup. Fresh-profile sims see no affixes on runs
  1–3.
- **Expected volume** (realistic, standard): about 3.5 affixed regulars and 4 affixed elites per
  run.
- **Determinism:** affixes roll **when the tile's enemies are rolled** (`Board.roll_enemies`, at
  generation and mutation), so the board preview shows them. They use a **derived Rng**
  (`Rng.new(hash([run.seed, "affix", lap, tile_idx]))`), not the main stream. Adding affixes
  therefore doesn't shift any existing random draw. Old sim baselines and seeds stay comparable
  with affixes off, and saves without `affixes` load as none.

#### 3A.4 Balance implications

- Sim targets are **unchanged**: realistic fresh 30–40%, mid 45–50%, max 55–65%, max A10 20–30%,
  expert fresh ≤80%.
- Expected raw cost: −2 to −4 pp realistic at mid and max, and about −1 pp fresh (affixes start
  at band 1 and after run 3).
- Compensation happens in this order, stopping when the bands hold:
  1. Affix reward multipliers (already ×1.5 gold/xp).
  2. Lower rates (bands 3–4: 15/20% → 12/16%).
  3. Enemy HP curve 0.35 → 0.34 per lap.
- Don't touch Ascension. A6's +4% stays, and A4 now uses affixes.
- New sim flag `--affixes=off|on|force:<id>` measures each affix alone at 100% on elites, which
  gives a pp table like `--items`.
  - Target: no single affix costs more than **4 pp** when forced on every elite.
  - `warded` and `piercing` are the likely offenders, and piercing hits Knight and Paladin
    hardest. If the per-class spread from piercing exceeds 5 pp, cut its weight to 2.

#### 3A.5 Visual language (extends WP-F2's `game/enemies/skin_rules.gd`)

The rule: **body = how strong (tier), overlay = what rule (affix)**. A player learns two
independent channels.

**Channel 1: body texture by strength tier.** WP-F2 maps elite, tier and trait to a skin; this
extends it.

| model family | T0 (bands 0–1) | T1 "veteran" (bands 2–4) | Elite dress (any band) | Mini-boss |
|---|---|---|---|---|
| Skeletons (Minion/Warrior/Rogue/Mage/Golem) and the mannequin skeleton looks | skeleton **texture A** (blue-grey cloth, orange trim) | skeleton **texture B** (black cloth) | T1 texture + horned skull-helm prop + gold sparkle (existing) + scale ×1.1 | ×1.5 + aura (existing) |
| Orc Raider / Drummer | orc **A** (green skin, red paint) | orc **B** (blue-grey skin) | B + backpack/drum-horn prop + ×1.1 | Warchief: B, ×1.5, club + war drum |
| Werewolf | **A** (brown wolf, red flannel) | A (no change: transform already sells menace) | **B "Silverback"** (grey wolf, blue flannel) | Moonfang: B, ×1.5, silver aura |
| Paladin (Fallen) | – (elite only) | – | `Paladin_with_Helmet` tex B, dark tint 0.75 | – |
| Adventurers-mesh enemies (bandit and wolf_bandit on Rogue_Hooded, cultist on Mage, bone_knight on Knight) | default atlas under the existing tint | **`_alt_C` atlas** (the darkest palette) under a tint weakened by 0.1, so the pattern shows | `_alt_B` atlas (gold/dark trim) + sparkle | existing |
| Mannequin-only looks (brute, sprites, imps, wisps) | existing tint | tint value −15%, emission +20%, ×1.05 | existing sparkle + ×1.1 | existing |

**Channel 2: affix overlay.** Each affix gets a colour, one prop on a fixed socket and one HUD
badge. Overlays never recolour the body. They only add eye colour, a rim/emission accent and a
prop, so both channels read at the same time.

| affix | eye / rim colour | prop (socket) | badge icon |
|---|---|---|---|
| armored | slate grey rim | `stone_plates` extra (shoulders; exists) | stone shield |
| thorned | moss green rim | `bramble_ring` (feet; exists) | thorn ring |
| warded | violet rim | small shimmer dome (reuses the Bone Warden ward FX at 0.6×) | dome |
| piercing | red glint | red spear-tip glint on the weapon (handslot.r) | cracked shield (exists for the pierce trait) |
| frenzied | orange-red eyes | steam puffs (head) that intensify per stack | angry skull + stack count |
| regenerating | light green eyes | `leaf_motes` pulse (exists) | green plus in a circle |
| vampiric | crimson eyes | crimson cape/part tint only on `Cape` parts, plus red drip particles | fang + heart (the drain icon) |
| hexing | purple eyes | floating purple rune circle over the head | chained die |
| frostbound | ice-cyan eyes | `frost_mist` + ice-crystal weapon (exists) | snowflake die |
| gilded | gold eyes | coin sparkle + gold metallic tint on gear only | coin |

Rules for skin_rules.gd:
- **Hero skins are never enemy bodies.** Ninja A–D, the Paladin no-helmet textures, Ranger,
  Druid and Engineer atlases are hero-only. Enemies built on the Knight, Mage or Rogue meshes
  always keep a tint ≥ 0.6 plus glowing eyes, so a player's skin never looks like an enemy.
- **Biome clash rule:** if an affix colour matches the biome's key colour (frostbound in Frost,
  or thorned or regenerating in the Glade), the prop carries the read and the rim colour is
  brightened +30%.
- **Excluded from enemies:** Monster Costume A–D, Clown and Animatronic (off-tone modern
  costume/toy looks), and Ninja A–D (reserved for the Ninja hero).
- Proposed data shape:

```gdscript
# game/enemies/skin_rules.gd (WP-F2 owns the file; additions)
const TIER_TEXTURE := {       # family -> [T0 atlas, T1 atlas]
	"skeleton": ["skeleton_texture_A", "skeleton_texture_B"],
	"orc": ["orc_texture_A", "orc_texture_B"],
	"werewolf": ["werewolf_A", "werewolf_A"],
	"adv": ["default", "alt_C"],
}
const ELITE_DRESS := {"skeleton": {"extras": ["skull_helm"]}, "orc": {"texture": "orc_texture_B", "extras": ["orc_backpack"]},
	"werewolf": {"texture": "werewolf_B"}, "adv": {"texture": "alt_B"}}
const AFFIX_OVERLAY := {
	"armored": {"eyes": Color(0.6, 0.62, 0.66), "extras": ["stone_plates"], "icon": "affix_armored"},
	# ... one row per affix, as in the table above
}
static func look(enemy_id: String, band: int, elite: bool, affixes: Array) -> Dictionary
```

#### 3A.6 UI hooks

- **Enemy HUD:** up to 2 affix badges (32 px, 44 px touch target on phone) in a row under the HP
  bar, left of the intent icon. Hovering or long-pressing a badge opens a tooltip with the name,
  a one-line rule and the live value ("Frenzied +4/+6").
- **Board preview:** the enemy figures standing on tiles show the overlay prop and eyes
  (lite mode), plus a small badge chip above the tile. The affix is visible before the board
  Reroll/GO decision.
- **First-encounter popup:** the first time a profile meets each affix (and each new enemy id), a
  card shows the rule with the enemy model. It is shown once per profile; AUTO shows it as a
  toast and doesn't stop.
- **Bestiary (Camp):** a new Camp page with an entry per enemy id and affix. Unseen entries are
  silhouettes. An entry shows base stats, pattern and biomes (the affix list on biome pages).
  Encounter and kill counts come from records.
- **Events and fields (core):**
  - `combat_started.enemies[i].affixes`
  - `board_mutated.changes[i].affixes` (and board generation tiles gain a parallel
    `enemy_affixes`)
  - `affix_triggered {enemy_idx, affix, value}` on every proc (thorn reflect, regen heal, hex
    curse, frost chill, frenzy stack)
  - `enemy_transformed {enemy_idx, form}`
  - stats `affixed_kills`, `affixes_seen: [ids]`
  - `Profile.records.seen = {enemies: [], affixes: []}`.

---

## 4. Skins

### 4.1 Principles

- Never random, never sold for money, no FOMO. Every skin has a stated condition, visible from
  day one.
- Skins are cosmetic only: no stat, no Crowns bonus.
- **Crowns after caps:** once the profile has maxed every Crowns sink (all owned gear L8, all
  Crowns upgrades, owned pets L10), any **non-prestige** locked skin can be bought for **250
  Crowns** (about 3 runs at the measured 78 Crowns/run). This is the "after caps, Crowns buy only
  cosmetics" rule from the review §3.6.

### 4.2 Per-class skin table

The unlock condition slots are the same for every class:
- **Default:** owned with the class.
- **Victor:** first win with the class (any mode).
- **Ascendant:** win with the class at **A3+**.
- **Bossbane:** beat **each of the 4 final bosses** with the class (any ascension). A win at
  **A6+** with the class also grants Bossbane.
- **Prestige:** win with the class at **A10**. It adds a small gold crown prop plus gold trim
  emission to *any* equipped skin. It can't be bought.

| class | Default | Victor | Ascendant | Bossbane | Prestige (A10) |
|---|---|---|---|---|---|
| Knight | `knight_texture` (red) | alt_A (green) | alt_B (gold/black) | alt_C (crimson/black) | crown + gold trim |
| Barbarian | default | alt_A | alt_B | alt_C | **`Barbarian_Large` "Chieftain" mesh** (Rig_Large, scaled to fit the tile) |
| Mage | default (purple) | alt_A (blue) | alt_B (olive/orange) | alt_C | crown + gold trim |
| Rogue | default (green) | alt_A (blue) | alt_B (red) | alt_C (magenta) | **Rogue_Hooded mesh** "Shade" |
| Paladin | tex A, no helmet (gold/blue) | tex B, no helmet (silver/green) | **tex A + helmet** | **tex B + helmet** | golden-statue shader (from `paladin_statue`) |
| Ranger | default (blue) | alt_A (gold) | alt_B (olive) | alt_C (orange) | crown + gold trim |
| Ninja | tex A (black/red) | tex B (blue) | tex C (green) | tex D (white/gold) | crown + gold trim |
| Druid | default | alt_A | alt_B (autumn orange) | alt_C (teal) | crown + gold trim |
| Engineer | default | alt_A (green) | alt_B (blue) | alt_C (brass) | gold turret |
| Necromancer | Rogue_Hooded + rogue alt_C | + rogue alt_A | + rogue alt_B | + rogue default | crown + gold trim |

Palette names come from inspecting the atlases in
`third_party/kaykit/KayKit_Adventurers_2.0_EXTRA/Textures`. Verify each on the model with
`tools/shoot.sh` before naming them in UI.

Skins count: 10 classes × 4 = 40 wearable skins, plus 10 prestige overlays and 2 alternate
prestige meshes.

Pacing check: the Knight's Victor skin arrives at the first win (about run 5). That is the first
cosmetic, landing early and on the starter class. Ascendant needs A3 (mid-game), and Bossbane
needs all 4 bosses (long-term).

### 4.3 Wardrobe (Camp)

- **Diegetic station:** a **Wardrobe** stand in the Camp. It is a `Mannequin_Medium` display
  dummy next to a mirror or a rack of banners, beside the class-select board.
- Tapping it opens a panel:
  - a class carousel (owned classes; locked ones as silhouettes)
  - the hero rotating on a turntable
  - 4 swatches plus a prestige toggle.
- Locked swatches show a lock, the condition text and live progress, for example "Win at A3+
  with the Ranger · best: A1" or "Final bosses beaten: Lich, Cinder King (2/4)".
- When the profile has reached the caps, a "250 Crowns" button appears on the non-prestige locks.
- Equipping is free and instant, and saves per class. The class-select screen shows the equipped
  skin.
- **Toasts:** results screen: "New skin: Knight, Victor". A "new" dot on the Wardrobe stays
  until it is viewed.

### 4.4 Profile schema additions (Profile VERSION 1 → 2, tolerant loader)

```text
cosmetics: {
  owned:    {class_id: [skin_id, ...]}      # "default" is implicit for owned classes
  equipped: {class_id: skin_id}             # missing -> "default"
  prestige: {class_id: bool}                # A10 overlay toggle (owned iff the A10 class win)
  unseen:   ["knight:victor", ...]          # wardrobe "new" dots
}
records.best_asc_by_class: {class_id: int}          # highest ascension won with the class (-1)
records.bosses_by_class:   {class_id: [boss_id]}    # final bosses beaten with the class
records.bosses_reached_by_class: {class_id: int}    # for the Ranger milestone
records.boss_kills:        {boss_id: int}           # for the Necromancer milestone
records.seen:              {enemies: [id], affixes: [id]}
records.counters += face_edits, kills
loadout.skin is NOT stored; RunState gets `skin: String` (presentation-only, serialised for Continue)
```

- **Core:**
  - A new `core/content/skins.gd` (`SkinDefs.DATA[class] = [{id, name, texture, mesh?, helmet?,
    cond}]`, conds `{class_win}`, `{class_asc: 3}`, `{class_bosses: 4, or class_asc: 6}`,
    `{class_asc: 10, prestige: true}`).
  - `Profile.apply_run_result` evaluates skins after the records and returns `skins_unlocked:
    [[class, skin]]`.
  - `Camp.equip_skin(class, skin)` and `Camp.buy_skin(class, skin)` (caps check + 250 Crowns).
- **Presentation:**
  - `Character.create(model_id, skin := "")` swaps the albedo texture on the single atlased
    material. All KayKit characters use one atlas, so it is a single `material_override` or
    surface texture swap.
  - The mesh swaps (Paladin helmet, Chieftain, Shade) are MODELS entries.

---

## 5. Implementation order and core vs presentation

| step | work | layer | size | depends on | gate to pass before the next step |
|---|---|---|---|---|---|
| 1 | `ClassLogic` hook module, `Die.tags`, HeroDefs fields (`kinds`, `tags`, `combat_rerolls`, `mechanic`, `style`), `class_triggered` event | core | S | – | all tests green; the 4 old classes unchanged in the sim (±1 pp) |
| 2 | **Paladin + Ranger** mechanics + bot awareness (Aim EV, Guard keeps) + tests | core | S | 1 | sim rows within ±5 pp (see §5.1) |
| 3 | Paladin/Ranger models, attack styles, class-select cards, class badge UI | presentation | S | 2 | device-matrix screenshots |
| 4 | **Ninja + Druid** mechanics + bot (refund-aware reroll EV, Face Raise valuation) | core | M | 1 | sim ±5 pp |
| 5 | Ninja/Druid presentation (seed leaf badge, growth pulse, shuriken proc) | presentation | S | 4 | screenshots |
| 6 | Unlock table (§2): milestones, counters, `_cond` forms, per-id Sigil prices, next-two rule, presets mid/max | core/meta | S | 2, 4 | campaign sim: medians within ±2 runs of target |
| 7 | New mechanics `frenzy`, `rally`, `transform` + the 8 enemy ids + pools | core | M | – (parallel with 2–6) | route table spread ≤ ±3 pp; bands hold |
| 8 | Enemy looks (EnemyLooks rows, Orc/Werewolf/Skeleton model loads, transform swap, Grave Mage → Necromancer model) | presentation | M | 7 | screenshots |
| 9 | **Affixes** core: AffixDefs, derived-Rng rolls in `roll_enemies`, hooks, events, `--affixes` sim flag, `affixes` feature unlock | core | M | 7 | per-affix pp table; bands hold |
| 10 | Affix visuals + HUD badges + first-encounter popups + Bestiary (extends WP-F2's skin_rules.gd) | presentation | M | 9 | screenshots at board-preview size |
| 11 | **Skins** core (SkinDefs, profile v2, Camp commands) | core/meta | S | – (parallel) | profile round-trip tests, v1 → v2 migration test |
| 12 | Wardrobe station + texture swap + toasts | presentation | M | 11 | screenshots |
| 13 | **Necromancer** (combat-local `extra_dice`) + bot kill-order | core | M/L | 1 | sim ±5 pp; replay determinism tests |
| 14 | **Engineer** (turret entity, offer targets, tray 6th slot) + bot turret valuation | core + presentation | L | 1 | sim ±5 pp |
| 15 | Final full sweep (§5.1) + update `docs/plans/balance.md` "Current balance" | sim/docs | S | all | – |

Steps 7–10 and 11–12 can run in parallel with the class work. Steps 13–14 are wave 2 and can
ship later without blocking anything, since the unlock table simply shows them as "coming" until
they exist.

### 5.1 Sim targets to re-check

```
godot --headless --path . -s tools/sim.gd -- --runs=300 --class=<id> --seed=1 --policy=realistic --profile=fresh|mid|max
godot --headless --path . -s tools/sim.gd -- --runs=150 --class=<id> --policy=expert --profile=fresh
godot --headless --path . -s tools/sim.gd -- --runs=200 --class=all --policy=realistic --profile=max --asc=10
godot --headless --path . -s tools/sim.gd -- --campaign=40 --campaigns=5 --policy=realistic --snapshot=10
godot --headless --path . -s tools/sim.gd -- --runs=300 --class=all --policy=realistic --profile=max --affixes=force:<id>
```

For per-class rows at "fresh", the sim forces the class, as it does today with all unlocked
classes.

| check | target |
|---|---|
| each class, realistic, fresh / mid / max | within **±5 pp of the 10-class average** at each profile |
| class average, realistic | fresh 30–40%, mid 45–50%, max 55–65% (unchanged) |
| each class, expert, fresh | ≤ 80% |
| each class, realistic, max A10 | 15–30% (the all-class mean stays 20–30%) |
| each class, greedy, fresh | ≥ 10% (the naive floor; a class the greedy bot can't play at all is too fiddly) |
| deaths by act, per class | no class with more than 20% of its runs dying in act 1 (watch the Druid and Ninja) |
| routes | every route within ±3 pp of the mean after the new enemies |
| affixes | each forced affix costs ≤ 4 pp; overall bands hold with affixes on |
| campaign | all classes by a median run ≤ 32; 90% of profiles by run 40; no run unlocks 2 classes |
| Short Road | the same ±5 pp per-class rule |

---

## 6. Open questions for Vlad

1. **Class count:** is it all 6 (10 classes in total), or wave 1 only (8 classes) for now, with
   the Engineer and Necromancer later? The Engineer is the most expensive (L).
2. **Necromancer look:** it is a living hooded human (Rogue_Hooded + skull staff) for
   readability, and the skeleton Necromancer model goes to the Grave Mage enemy. Or do you want
   the skeleton model as the hero anyway?
3. **Paladin vs Knight:** both are defensive. Is "surplus Block heals, then smites" different
   enough, or should the Paladin lean to sets/Twin dice only?
4. **Class unlock fallbacks ("or play N runs"):** keep them (no one is stuck), or make classes
   pure achievements?
5. **Affix onboarding:** turn them on at run ~3 (`brawler`), or later (first win, ~run 5)?
6. **Off-tone models:** this doc excludes the Monster Costume, Clown, Animatronic, Survivalist,
   Robot, Space Ranger, Driver and Action Figure entirely, and reserves Ninja A–D for the hero
   instead of enemy affix skins. Is that OK, or do you want any of them as joke or secret
   cosmetics?
7. **Crowns-after-caps skin price** (250) and whether the prestige (A10) skins should stay
   impossible to buy.
