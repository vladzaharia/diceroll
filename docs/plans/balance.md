# Diceroll balance

Numbers live in `core/content/` (`balance.gd`, `heroes.gd`, `enemies.gd`, `biomes.gd`,
`dice_kinds.gd`, `passives.gd`, `shop.gd`, `events.gd`) and `core/runes.gd`.

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
- **Shop** after completing laps 3, 6, 9 and 12, and at each biome change (after laps 5 and 10).
- **Mini-boss.** When lap 7 starts, one `miniboss` tile appears with the run's mini-boss
  (`run.miniboss_id`, drawn at run start from the tier-2 biome's candidates). It lasts until it
  is beaten, or until lap 11 regenerates the board.
- **Final boss.** Completing lap 15 stops the hero on Start and starts the run's final boss
  (`run.boss_id`, drawn at run start from the tier-3 biome's candidates). Winning is VICTORY.
  The Hollow King is no longer in the run; its content id is kept.
- **Movement is automatic.** `roll_board()` rolls the whole pool and picks two dice. The move is
  their sum (0..18). The only choice is to reroll or go (`board_reroll()` / `confirm_move()`).

## Final sim (greedy Bot, 500 runs per class, board 28, seed 1, random routes)

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
