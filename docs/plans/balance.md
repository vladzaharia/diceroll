# Diceroll balance

Numbers live in `core/content/` (`balance.gd`, `heroes.gd`, `enemies.gd`, `dice_kinds.gd`,
`passives.gd`, `shop.gd`, `events.gd`) and `core/runes.gd`.

Re-run the sim with:

```
godot --headless --path . -s tools/sim.gd -- --runs=300 --class=all --seed=1 [--board=24|28|32]
```

## Run structure (Heroll-style, 2026-09-28 revision)

- **One board, 15 laps.** A run is 15 laps ("floors") on one continuous ring. The default ring
  is **28 tiles** (8x8 perimeter, corners 0/7/14/21: Start, Forge, Treasury, Portal). Ring size
  is a parameter: `GameFlow.new_run(class, seed, board_size)` accepts 24 (7x7), 28 (8x8) and
  32 (9x9). Any 4(n-1) with n >= 5 works, with tile counts scaled from the 24 layout.
- **Biomes.** Act 1 = laps 1–5 (crypt), act 2 = laps 6–10 (hollow), act 3 = laps 11–15
  (throne). When lap 6 or lap 11 starts, the board is **regenerated** around the hero. The hero
  keeps their position, their landing tile is never a fight, and they heal 30%. `act_started`
  fires at that point.
- **Shop** after completing laps 3, 6, 9 and 12, and at each biome change (after laps 5 and 10).
- **Mini-boss.** When lap 7 starts, one `miniboss` tile appears (the Pumpkin Knight in the act 2
  biome). It lasts until it is beaten, or until lap 11 regenerates the board.
- **Final boss.** Completing lap 15 stops the hero on Start and starts the Lich. Winning is
  VICTORY. The act 1 and act 2 bosses are no longer in the run; their content ids are kept.
- **Movement is automatic.** `roll_board()` rolls the whole pool and picks two dice. The move is
  their sum (0..18). The only choice is to reroll or go (`board_reroll()` / `confirm_move()`).

## Final sim (greedy Bot, 300 runs per class, board 28, seed 1)

| class | win% | avg act | avg lap | avg board turns | avg combat turns | avg commands | avg level | avg fights won | deaths |
|---|---|---|---|---|---|---|---|---|---|
| knight | 35.0 | 2.89 | 13.9 | 47.1 | 48.7 | 419 | 14.8 | 18.6 | act1:7 act2:20 act3:101 boss:67 |
| barbarian | 31.3 | 2.86 | 13.7 | 45.6 | 44.0 | 385 | 14.2 | 18.0 | act1:7 act2:26 act3:110 boss:62 mini:1 |
| mage | 26.0 | 2.83 | 13.5 | 45.2 | 43.5 | 380 | 13.8 | 17.5 | act1:8 act2:31 act3:111 boss:69 mini:3 |
| rogue | 33.0 | 2.90 | 14.0 | 45.9 | 46.0 | 418 | 14.5 | 18.4 | act1:5 act2:19 act3:108 boss:69 |

Seed 4242 (a check against overfitting to one seed): knight 39.0, barbarian 35.0, mage 29.7,
rogue 33.3.

Other ring sizes (seed 1, same numbers otherwise):

| board | knight | barbarian | mage | rogue | avg board turns |
|---|---|---|---|---|---|
| 24 | 28.7 | 33.7 | 23.0 | 31.7 | ~39.5 |
| 28 (default) | 35.0 | 31.3 | 26.0 | 33.0 | ~46 |
| 32 | 30.0 | 34.3 | 29.3 | 28.0 | ~52 |

Every run finished with zero error events and zero command-cap hits. The sim exits 1 on either.

About the numbers:
- **"avg board turns"** counts every run, deaths included. A run that reaches the Lich takes
  about 15 × 28 / 8 ≈ 52 board turns on 28 tiles, which is the low end of the 50–70 target. On
  32 tiles it is about 60. If runs feel too short, the cheapest levers are a 32-tile board or
  more laps.
- **"avg act"** is the biome the run ended in. A victory counts as act 3.
- **Deaths** are keyed by where they happened: `act1` means a regular fight or trap in laps 1–5,
  `act2` laps 6–10, `act3` laps 11–15, `mini` the mini-boss and `boss` the Lich. About 2% of
  runs die in act 1, 7% in act 2, 35% in act 3, 22% at the Lich and under 1% at the mini-boss.
  Deaths cluster in act 3 but are spread across the run.

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
| The Lich HP | 800 | **1300** | The only boss is the run's climax |
| Hollow King / Bone Warden | in the run | **not used** (content kept) | Revision |
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
  shop's first item is a die and every level-up draft includes a New Die option.

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
   The hero heals 10% and the Lich fight starts. Any mini-boss tile is removed, with a
   `board_mutated` change to empty. There is no shop and no mutation.
9. **Biome change** (laps 6 and 11):
   - `act` goes up, the board is regenerated and the hero keeps their tile. If the new landing
     tile would be a fight, it becomes Empty.
   - The hero heals 30%, and Rune Bloom fires.
   - The treasury carries over, and the once-per-act reroll item becomes available again.
   - `act_started {act, biome, lap, board, treasury, pos}` fires between `lap_completed` and the
     shop.
10. **Mini-boss.** It spawns on an Empty or uncleared Enemy tile that is not a corner, not the
    landing tile, and more than 3 tiles (either way round) from the hero. It is scaled like a
    regular enemy (not an elite): Pumpkin Knight base 105 HP, which is about 2× an elite brute's
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
