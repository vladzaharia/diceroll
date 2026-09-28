# Diceroll meta layer: design review

Reviewer: senior roguelite / mobile meta designer. Date: 2026-09-28.
Scope: spec §15–16, `docs/plans/balance.md`, `docs/research/games.md`, `core/content/*.gd`.
Constraint honoured throughout: **no premium currency, no random rolls for power, deterministic upgrades.**

Numbers I lean on from the repo:
- **Run shape:** 15 laps on 28 tiles, and about 52 board turns to reach the boss. Move ≈ 8, so about 3.5 landings per lap.
- **Fight length:** about 19 fights won and about 48 combat turns per run. That is roughly **2–2.5 turns per regular fight**, and boss fights run longer.
- **Win rate today (greedy bot, no meta):** 27–38%. About two-thirds of deaths happen in act 3 or at the final boss.
- **Healing today:** 10% per lap (150% of max HP over a run), 30% at each of the 2 biome changes, campfires at 30% (consumed), and shop potions at 35%. The shop potion heals instantly; no potion belt exists in code yet.

---

## 1. Executive summary: the 5 recommendations that matter most

1. **Cut the currencies from 5 to 2 and remove the link between material and minigame.** Today, material X only comes from minigame X, which only appears if it's in your loadout. The loadout, meant to be a fun in-run choice, then becomes an economic rotation ("I must equip Fossil Hunter this week to afford Workshop"), and that is homework. Use **Crowns** (earned every run, pays for levels) plus **Sigils** (milestones only: bosses, first clears, achievements; pay for *unlocks*). This mirrors Hades' Darkness vs. Chthonic Keys split. If you want the four themed materials for flavour, see §3.3 for the only version I'd accept.
2. **Pets need a charge meter that persists across fights, not a turn cooldown.** A regular fight lasts about 2 turns, so a "every 3 turns" pet almost never acts outside bosses. Pets should charge from *dice events* (pairs, 6s, rerolls, kept dice), carry that charge between fights, and have one board-side effect each. That is also where the pet-dice synergy comes from.
3. **Give permanent stat power a hard budget of about +15–20 pp of bot win rate, and spend the rest of the meta on horizontal unlocks.** Concrete caps are in §4: gear gives at most +12 HP, +2 ATK, +1 board reroll per lap and +15% gold. Retarget §16's "maxed profile about 60%" to **about 50% at A0**. Past 50%, a 40-minute run with no tension is a bad trade.
4. **Ascension should be 10 levels of rule changes, not "+8% HP" ten times.** Each level should touch a different system: potions, shops, mini-boss, board, boss. A10 should be a double final boss (the route's other tier-3 candidate). Make it global, not per class. Players criticise per-deck and per-character ladders in Balatro and StS as padding.
5. **Gate content in the first 10 runs so every run unlocks something you can *see on the board*.** Runs 1–2 use a fixed route with 6 runes, 4 die kinds and 12 passives. Biomes, classes, pets and minigames unlock through play milestones (Balatro- and Luck be a Landlord-style), not Crowns. Losses pay at least 40% of a win's Crowns, and the first loss always unlocks something.

Also worth fixing early (small but sharp):
- **Leftover gold → Crowns punishes spending in-run.** Cap it at +5.
- **Potion strength is inconsistent:** the shop potion heals 35% and the belt potion 30%. Unify at 30%.
- **The belt should cap at 3, not 4.** 4 × 30% = 120% of burst healing at the final boss.
- **AUTO needs a policy for minigames, potions and pets** before any of them ship.

---

## 2. Core meta loop

### 2.1 Loop
Camp (spend, choose class + pet + 2–3 minigames) → run (35–45 min, 15 laps) → results (Crowns, Sigils, pet XP, unlock toasts) → Camp.

The risk specific to Diceroll is that **runs are long for a mobile roguelite.** Heroll stages are 10–15 floors, and its reviewers warn "make sure you have time to finish". A loss at the lap-15 boss after 40 minutes is the most common death (about one third of runs). So **the meta must make a late loss feel like progress**, and it must never make the player want to abandon a run early (no "quit to save materials" exploit).

### 2.2 Goals per horizon

| Horizon | What pulls | Built from |
|---|---|---|
| Within a session (1 run) | "I'm 40 Crowns from Blade L4", "one more lap to the mini-boss", minigame tiles as cute beats | Crowns meter on the HUD at lap ends; pet charge; visible unlock progress bars |
| Mid (5–20 runs) | New biome / boss discovered, new class, new pet, first win, first win per class | Milestone unlocks (Sigils), collection log with silhouettes |
| Long (20–100 runs) | Ascension ladder, win with every class × final boss, max a pet, master a minigame, all 32 route combinations seen | Ascension, achievements, cosmetic dice skins, run history |

### 2.3 "One more run" without monetisation pressure
- **Visible near-misses.** The results screen shows the 2–3 nearest goals ("Coin Mimic: 12/15 treasury cash-outs", "Helm L5: 18 Crowns short"). Balatro's unlock list shows progress toward conditions, and it works.
- **Novelty drip.** In the first 10 runs, *every* run should reveal something new (§6). After that, the 32 route × mini-boss × boss combinations carry variety, provided the route is shown at run start (already specced).
- **No timers, no energy, no dailies that punish absence.** The pull is curiosity and mastery, not fear of loss.

---

## 3. Economy design

### 3.1 Why 5 currencies is too many
- **Too much for the size of the game.** Crowns + Fossils + Pearls + Tickets + Tokens is 5 counters for about 5 buildings. That's a mid-core gacha ratio (Dicero: gold, gems, keys, crystals; Heroll: gold, diamonds, scrolls, stones, shards), which is the genre we are explicitly not copying.
- **The material-per-minigame link turns the loadout into a spreadsheet.** An ideal loadout choice is "which minigames do I *enjoy* and which *in-run* reward does my build want?". With one material per minigame it becomes "which building am I saving for?". Players will rotate minigames they dislike: a chore.
- **Four materials split the drip four ways.** Each material then trickles too slowly to feel good. With about 5 minigame plays a run, that's about 2.5 plays per material per run.

### 3.2 Recommended: Crowns + Sigils (plus pet XP)

| Currency | Faucets | Sinks | Feel |
|---|---|---|---|
| **Crowns** (soft) | Every run: laps, biome reached, mini-boss, boss, minigame bonus, achievements (small) | Gear levels, pet levels 6–10, Workshop starter kit, Arcade upgrades, potion belt, cosmetics after caps | "I always get some" |
| **Sigils** (milestone) | First mini-boss kill (each), first final-boss kill (each), first win per class, Ascension first-clears, specific achievements. Roughly 60 exist in total; they are not farmable. | *Unlocks*: pets, minigames, classes, rune/kind/passive packs into pools | "Big moment", never grindy |
| **Pet XP** (per pet) | Fights won with that pet equipped (Hades keepsakes rank by encounters: 25, then 75) | Pet levels 1–5 automatically | "Using it grows it" |

Minigames pay **in-run rewards plus a Crowns bonus (+2 to +4 per play)** and **mastery XP for themselves**: a minigame levels by being played, like a keepsake. The loadout then serves only fun and in-run strategy.

### 3.3 If you insist on the four themed materials (fallback)
Keep them, but make **every minigame drop a "Trinket" that the player assigns at Camp** to Fossils, Pearls, Tickets or Tokens, or allow a free 1:1 conversion. Flavour is preserved and the rotation chore is gone. Don't ship the strict 1:1 minigame↔material mapping.

### 3.4 Crowns faucet (proposed formula)
- **Base:** 2 per lap completed (max 30), 5 per biome reached (tier 2 and tier 3), 12 for a mini-boss kill, 30 for a final-boss win, 2–4 per minigame played.
- **Leftover gold:** 1 Crown per 25 gold, **cap 5**. The spec's uncapped version punishes in-run spending. Rogue Legacy has the same tension with Charon's gold toll.
- **Ascension:** +8% per level on the whole payout.

| Outcome | Crowns | vs. win |
|---|---|---|
| Death in act 1 (lap 4) | ~12 | 12% |
| Death in act 2 (lap 8) | ~26 | 27% |
| Death at the final boss (lap 15) | ~52 | **55%** |
| Win (with mini-boss) | ~95 | 100% |

Losses at the boss pay more than half a win, which is the right shape: a late loss is still a good session. An early death pays little, so it doesn't encourage suicide runs to farm, and it can't, because payout scales with laps.

### 3.5 Pacing targets (Crowns sink total ≈ 3,400)

| Milestone | Target run # | Crowns spent by then | Notes |
|---|---|---|---|
| First upgrade bought (Helm L1) | 1 | 10 | Guaranteed on a first-run loss |
| All 4 gear pieces at L2 | 4–5 | ~120 | Run 2 unlocks Blade, run 3 Boots, run 5 Charm |
| First win (human) | 5–10 | — | Bot fresh-profile target: 20% |
| 3rd potion slot | ~10 | 120 | |
| 3rd minigame loadout slot | ~15 | 150 | |
| All pets owned | ~20 | Sigils | Via milestones, not grind |
| All horizontal content in pools | ~30–40 | Sigils | |
| Gear maxed (L8 × 4) | ~45 | 1,640 | |
| All pets L10 | ~55 | ~900 | |
| Everything maxed | ~60 runs ≈ 40 h | ~3,400 | Then Ascension + cosmetics |

Proposed gear cost curve (L1–8): 10, 20, 30, 45, 60, 75, 80, 90 = 410 per piece.

### 3.6 Anti-grind and anti-chore rules
1. **No per-day caps and no dailies that reward presence** (Heroll caps diamonds at 100/day, a retention device).
2. **Nothing requires replaying a specific minigame, biome or class** except achievements, and those are optional.
3. **Catch-up:** after 3 consecutive losses, the next run pays +25% Crowns (max +50%). It's invisible compassion, not a streak mechanic. It resets on a win.
4. **Free respec of gear-trait choices.** Vampire Survivors lets you refund PowerUps and toggle them off; we should allow toggling any meta bonus off (see §7, "Bare Bones").
5. **After caps, Crowns buy only cosmetics.** Never add a new stat sink later just to absorb surplus.

---

## 4. Power vs. variety

### 4.1 Split
**About 30% of meta *value* should be vertical (stats), about 70% horizontal (options).** Hades is the reference: the Mirror is strong, but Heat and Routine Inspection let players remove it. Slay the Spire, Balatro, Peglin, Luck be a Landlord and Dicey Dungeons are almost entirely horizontal plus ascension, and they are the most replayed games on the list.

### 4.2 Vertical budget (hard caps, expressed as greedy-bot win %)

| Source | Cap | Est. bot Δ | Why this cap |
|---|---|---|---|
| Helm | +12 max HP (+20% of 60) | +4 pp | More HP only stretches a lap-15 death |
| Blade | +2 ATK | +4 pp | Flat ATK is added *after* the multiplier. +2 equals the Barbarian's whole class identity; more erases classes |
| Boots | +1 board reroll per lap (not per turn) | +2 pp | Per turn would duplicate Pathfinder and the Rogue |
| Charm | +15% gold | +3 pp | Gold compounds via shops |
| Potion belt | 3 slots, start with 1 | +3 pp | 4 slots = 120% burst healing at the boss |
| Pet (L10) | ≈ one rare passive | +4 pp | |
| Workshop starter kit | Sidegrades + at most 1 free Face Raise | +1 pp | |
| **Total** | | **≈ +20 pp** | Fresh 20% → maxed ~45–50% at A0 |

Revise §16's targets to **fresh profile 18–25%, mid profile ~33%, maxed profile ~45–50% at A0**. Base-game note: the current no-meta bot is at 27–38%, so either nerf the base by about 8 pp (e.g. lap heal 10% → 8%, or enemy base scale 1.2 → 1.25) or treat the curated starting pool as the handicap. Re-sim either way.

### 4.3 Horizontal unlocks (what "more" should mean)
- **Pool content:** 6 runes, 5 die kinds and 20 passives that start locked.
- **Classes:** 2 locked at start (§6).
- **Pets and minigames:** unlocked via Sigils.
- **Potion types:** 3 extra types (§5.5).
- **Routes:** Crypt, Frost and Magma start locked.

Use **Balatro's dilution lesson**: unlocking can make runs *worse* when the pool fills with win-more cards. Two fixes:
- A **"Pool" toggle in the Workshop**: once something is unlocked, the player may switch it off (up to 25% of each pool). Luck be a Landlord lets you toggle items; Vampire Survivors lets you toggle PowerUps.
- **Economy-only passives** (Gold Tooth, Piggy Bank, Treasure Sense, Haggler) should be offered in shops, not in elite rewards.

### 4.4 Ascension: global, 10 levels, one system per level

| A | Modifier | System touched | Est. bot Δ (maxed) |
|---|---|---|---|
| 1 | Lap mutation spawns +1 Elite | Board | −3 |
| 2 | Lap heal 10% → 6% | Healing | −4 |
| 3 | Shops cost +20%; restock 15g | Economy | −3 |
| 4 | The mini-boss gains a trait (armor / thorns / ward by biome), and skipping it adds +10% HP to the final boss | Mini-boss | −3 |
| 5 | Start with 0 potions; potion heal 30% → 25% | Potions | −4 |
| 6 | Enemies +12% HP and attack | Stats (only one stat level!) | −5 |
| 7 | Each biome change adds a Curse: one random face becomes a 1 until you visit a Forge | Dice | −4 |
| 8 | Traps and ice/lava deal ×1.5; +1 hazard per board | Board | −3 |
| 9 | The final boss starts in phase 2's trait set, with +15% HP | Boss | −5 |
| 10 | **Double final:** after your boss, face the route's other tier-3 candidate at 60% HP | Boss | −6 |

- **Target:** a maxed profile at A10 wins about 10–15% (bot); strong humans more.
- **Unlocking:** the next level unlocks when you win the current highest level with *any* class. Each class keeps a separate "highest A won" badge, which is a goal but not a gate.
- **Rewards:** +8% Crowns per level, a Sigil on each first clear, and a cosmetic dice skin at A3, A6 and A10. Hades pays Heat bounties in upgrade materials; ours should pay mostly cosmetics, because Sigils run out.
- **Later, after A10:** Heat-style *optional* modifier cards (§7).

---

## 5. Systems

### 5.1 Armory (gear)
- **Problem:** four pure stat sliders are the least interesting meta in the genre, and Heroll's players complain gear numbers are confusing to compare. Keep stats small and add **one binary trait choice at L4 and one at L8 per piece**. That's 8 total choices, freely re-selectable at Camp.

| Piece | Stat per level (cap) | L4 trait (pick 1) | L8 trait (pick 1) |
|---|---|---|---|
| Helm | +1.5 HP (+12) | Lap heal +2% · Campfires +10% | Once per run, a lethal hit leaves 1 HP *if HP was above 50%* · Block 5 on turn 1 of every fight |
| Blade | +0.25 ATK (+2) | +3 damage on Pair · +3 damage on High Roller (helps bad rolls) | First attack of the boss fight ×1.3 · Kills overflow 50% of excess damage to the next enemy |
| Boots | Unlocks at L1 +1 board reroll per lap; later levels add small bonuses | Portal range +2 · Traps: dodge on 3+ | Choose between the 2 highest pairs when moving (a tiny agency buff) · Passing Treasury banks +5 |
| Charm | +2% gold (+15%) | Shop restock 5g · One free restock per shop | Shop always offers 1 potion · Treasury cash-out ×1.25 |

- **Crafted "with Crowns and Tokens"** becomes Crowns only (or the Trinket fallback). Unlock each piece via a first-time milestone (§6), not a purchase.

### 5.2 Dice Workshop
- **Role:** the **horizontal hub**. It holds the pool unlocks plus the starting kit. Keep permanent starting-dice *upgrades* out of it: raised starting faces flatten the early game, which is where 2-dice fights are meant to be tense.
- **Unlock packs (Sigils):** ~8 packs of 3–5 items, each themed so the unlock is a build idea, not a stat:

| Pack | Contents | Unlocks after |
|---|---|---|
| Starter (owned) | Runes: Blade, Guard, Venom, Heavy, Vampire, Gilded · Kinds: Standard, Low, High, Loaded · 12 passives (commons + Second Wind) · Boss: Extra Hand, Crowd Pleaser, Phoenix | — |
| Gambler's Kit | Kind: Gambler · Rune: Lucky · Passives: Encore, Double Trouble | Reach the mini-boss |
| Cold Steel | Rune: Frost · Kind: Twin · Passive: Iron Skin, Thorns | Discover Frostpeak |
| Pyromancy | Rune: Ember · Passives: Boxcars, Opening Salvo, Glass Cannon | Win with the Mage |
| Storm | Rune: Thunder · Passives: Loaded Hands, Collector | 100 rerolls used |
| Numerology | Kinds: Odd, Even · Passives: Straight Shooter, Snake Eyes | Roll a Straight |
| Resonance | Rune: Echo · Passives: Rune Echo, Resonance (boss) | Have runes on all dice at once (5+) |
| Colossus | Kind: Giant · Rune: Wild · Passive: Triple Threat, Rune Bloom (boss) | First win |

- Class starting runes (Mage's Ember and Echo, Rogue's Lucky) work on the class die even while locked in the pool. The unlock only adds them to *drops*.
- **Starter kit (Crowns):** choose the *kind* of your second starting die among unlocked commons (Standard, Low, Loaded…). It's a sidegrade. One vertical item, "Whetstone: start with 1 Face Raise" (80 Crowns), is the only direct dice buff.

### 5.3 Pet Den
**Mechanic:**
- Each pet has a **charge meter (3–6 pips)** filled by a specific dice event. The meter **persists across fights and board turns**.
- When full, the pet fires automatically at the start of the next ATTACK resolution, or on tap for pets tagged "manual".
- Each pet also has one **board perk**.
- Levels 1–5 come from pet XP (fights won while equipped: 5 / 15 / 30 / 50). Levels 6–10 cost Crowns (40, 60, 80, 100, 120). L5 and L10 add a new *behaviour*, not only bigger numbers.

| Pet | Role | Charges on (synergy) | Fires | Board perk | L5 | L10 |
|---|---|---|---|---|---|---|
| **Pumpkin Sprite** (starter) | Heal | Each Pair or better (+1), size 4 | Heal 6% max HP (+1%/lvl) | Campfires +5% | Also removes Burn | Overheal becomes Block |
| **Skull Buddy** | Attack | Each die showing 1 or 0 (+1), size 4. Loves Low, Gambler and Snake Eyes | Deals 4× your *lowest* die (min 4) | Traps: +1 to the dodge roll | Hits all enemies at half | Blanks count as 1 for its hit and charge ×2 |
| **Lantern Ghost** | Burn / DoT | Each 6 rolled (+1), size 5. Loves High, Ember and Boxcars | Poison 4 (+1/lvl) on all enemies | Lava/ice damage −50% | Poison doesn't decay on the boss | Poisoned enemies take +1 from Thunder/Ember |
| **Crystal Wisp** | Tempo | Each die *kept* (not rerolled) (+1), size 6. Loves Lucky and Steady Hand | +1 reroll now (+1 banked at L5) | +1 board reroll on the first turn of each lap | Also unmarks a Curse | Once per fight, its free reroll does not count as "rerolled" for Steady Hand or Lucky |
| **Guard Die** | Defense | Each enemy intent that is an Attack (+1), size 3 | Rolls a d6 → Block = pips ×2 | Start each biome with 1 potion if the belt is empty | Block persists 1 extra turn | On 6, also stuns (Frozen) |
| **Coin Mimic** | Economy | Each double on the board (+1), size 3 | +8 gold; in combat bites for gold/20 dmg (max 10) | Treasury banks +2 per double | One free shop restock per shop | Chest gold opens as 1 of 2 choices |

- **Rhythm check:** with 2–2.5 turns per regular fight, a size-4 meter fed by pairs fires about once every 2 fights. In a boss fight (8–12 turns) it fires 2–4 times. That feels alive without dominating.
- **One pet per run** (keep it). Add **Pet Den "affinity"**: owning another pet at L5+ grants a tiny passive (a Hades Companion-style collection reward) such as +1 HP per L5 pet (max +5). It's optional collection value that doesn't break the budget.
- **Visual:** the pet hops beside the hero on the board. Heroll's pets are a marketed pillar, and the cute factor is doing half the job here.

### 5.4 Arcade and minigames
**Rules for every minigame:**
- 15–35 s, one-thumb.
- Its outcome is computed in core from the run RNG plus inputs (already specced).
- **Expected reward within ±10% across all minigames at median play.** Skill raises the result by at most +30% over median, and bad play drops it by at most −30%, so a loadout is never a trap.
- **AUTO plays at a "par" result of 85% of median** instantly. AUTO users then aren't punished much, and playing by hand is worth a small edge.

| Minigame | Skill:luck | Length | Current design risk | Fix / spec |
|---|---|---|---|---|
| **Fossil Hunter** | 60:40 | 20–30 s | Blind digging is pure luck | 5×5 grid, 2 fossils (1×2 and 1×3), 7 digs; each dug cell shows **distance hints** (Minesweeper-lite). Full fossil = big reward, partial = small |
| **Bubble Breaker** | 80:20 | 25–40 s | Can run long; analysis paralysis | 6×6, 4 colours, **5 taps**, ≥3 cluster only; a chain combo meter; hard 35 s timer only as a fallback |
| **Scratch-off** | 0:100 | 8–12 s | Pure luck: fine as a breather, bad if its EV is high | 3 of 9, match 3 symbols; **low variance**: worst result is still a small prize. Ties to dice: symbols are die faces, and three 6s = jackpot |
| **Claw Machine** | 70:30 | 15–25 s | Timing on touch plus 3D physics can feel unfair | Deterministic swing arc; 2 grabs; prizes visible so you *aim* for what your build needs. Heroll's claw puts the legendary at the bottom: keep that |

**Rewards (in-run, by performance tier: bronze / silver / gold):**

| Tier | Choose 1 of |
|---|---|
| Bronze | 10–15 gold (lap-scaled) · 1 Crown bonus |
| Silver | Potion · Face Raise · 25 gold |
| Gold | Rune of choice from 2 · Potion + 20 gold · *per-minigame signature*: Fossil → Die kind; Bubble → +1 combat reroll for next 3 fights; Claw → pick a passive of common rarity; Scratch → 60 gold |

**Board placement:**
- **One tile per equipped minigame** (2, or 3 with the 3rd slot). The tile is consumed when played and respawns on the next lap mutation.
- At about 3.5 landings per lap, each tile is hit with p ≈ 0.125 per lap, so **2 tiles ≈ 4 plays per run and 3 tiles ≈ 6 per run.** That is about 2–3.5 minutes of a 40-minute run, under 10%. Don't go above 3 tiles.
- A hidden "4th slot" would make the board feel like an arcade, not a dungeon.

**The loadout decision** should read as strategy: "I'm on a Gambler/High build, so Fossil Hunter (die kinds) + Claw (targeted passive)", or "fragile class, so Scratch-off for potions". Show each minigame's signature Gold reward on the loadout screen.

**Arcade sinks (Crowns and Sigils):**
- Unlock minigames 3 and 4 (Sigils).
- 3rd loadout slot (150 Crowns).
- Mastery levels 1–5 per minigame, earned by *playing* it: cosmetic plus QoL (hint charges in Fossil Hunter, a preview row in Bubble Breaker). Mastery never adds more than +10% reward.

**Future minigames** (dice-native, cheap, very Heroll):
- **High-Low Ladder:** push your luck, cash out anytime.
- **Race:** reach Start in 3 rolls (Heroll's corner).
- **Yahtzee Sprint:** one hand, 3 rerolls, the combo tier = reward tier.
- **Dice Duel:** already exists as an event; promote it.

### 5.5 Potions and healing across the run
**Healing budget per run** (fraction of max HP made *available*, not necessarily used):

| Source | Fresh profile | Maxed | Notes |
|---|---|---|---|
| Lap heal 10% × 15 | 150% | 150% | Keep; A2 cuts to 6% |
| Biome change 30% × 2 | 60% | 60% | Keep |
| Campfires (≈1.5 landed per run × 30%) | ~45% | ~55% | Helm trait +10% |
| Potions: start 1 + shop/minigame ≈ 3 | ~120% | ~150% | Belt 2 → 3 max |
| Pumpkin Sprite / heal passives | 0–40% | 0–60% | Build-dependent |

**Rules:**
- **Potion = 30% everywhere.** Change the shop potion from an instant 35% heal to a belt item; if the belt is full, it's drunk at once.
- **Potion belt:** 2 slots base, 3 via Armory/Arcade (120 Crowns). **No 4th slot.**
- **Use:** free action, **at most one per combat turn**. That stops 3-potion boss burst and keeps a potion a decision.
- **Deterministic potion types**, unlocked by milestone and bought in shop by name:
  - **Healing Draught** (30%)
  - **Stoneskin** (Block 15 this turn and next)
  - **Reroll Tonic** (+2 rerolls this turn)
  - **Cleanse** (remove Burn, Curse and Chill; heal 10%)
- **AUTO potion setting:** "drink below X% HP", default 35%, plus "save 1 for the boss".

### 5.6 Crowns rewards
- **Results screen order:** laps → biomes → bosses → minigames → leftover gold (capped) → Ascension bonus → **nearest goals** (3 progress bars). Animate each line; that's where the dopamine lives.
- **Show projected Crowns at every shop** ("If you die now: 26 Crowns") only in a settings toggle; some players find it stressful.
- **First-time bonuses paid in Sigils:**
  - first reach of each biome
  - first kill of each mini-boss and final boss
  - first win per class
  - first win per route (8)

  About 30 Sigils come from discovery alone.

---

## 6. Unlock sequencing: the first 10 runs

**Fresh profile:**
- Knight and Barbarian (a tank and a simple damage class).
- Route fixed at **Glade → Hollow → Throne**; mini-boss Pumpkin Knight; boss Lich (the most-won boss, 38.7%).
- Starter pool (§5.2).
- No pet on run 1.
- Minigames: Scratch-off + Claw (one luck, one skill; both instantly readable).

The first lap is a guided tutorial (roll, GO, reroll, one fight).

| Run | Expected result | Unlocks (trigger → reward) | Why it's exciting |
|---|---|---|---|
| 1 | Dies lap ~6–9 | **Camp opens** (any end); Armory Helm; **Pumpkin Sprite** (reach lap 5) | A pet! The results screen shows the Camp being built |
| 2 | Dies act 2 | Blade gear (reach biome 2); die kinds Low/High visible in Workshop; **Crypt** unlocked as tier-1 alternative (reach lap 6) | Route now varies: "which tier-1 will I get?" |
| 3 | Maybe reaches the mini-boss | **Mage** (reach the mini-boss) · **Gambler's Kit** pack · Boots gear | A new class with a different identity (Ember/Echo) |
| 4 | Reaches act 3 | **Frostpeak** (reach act 3 or kill the mini-boss) · **Fossil Hunter** · Cold Steel pack | New minigame and a new biome twist (ice) |
| 5 | Close boss loss | **Skull Buddy** (die to/at the final boss: the "consolation" unlock) · Charm gear · 3rd potion slot purchasable | Losing at the boss *gives* something |
| 6 | First win likely here | **First win:** Colossus pack (Giant die, Wild), **Rogue**, **Magma Depths** (Cinder King, Magma Golem), **Ascension 1** | The run the game "opens up" |
| 7 | Mixed | **Bubble Breaker** (play 8 minigames) · Numerology pack · **Lantern Ghost** (5 Burn/Poison kills) | Deeper builds (odd/even straights) |
| 8 | Mixed | Bone Warden boss enters rotation (first Throne win or 2nd visit) · **Crystal Wisp** (keep 30 dice) | New final boss changes Throne runs |
| 9 | Mixed | **3rd loadout slot** purchasable · Storm pack · Frost Warden/Bone Champion mini-bosses | More board variety |
| 10 | Mixed | **Guard Die** and **Coin Mimic** (via achievements) · Pyromancy/Resonance packs via class wins | Full pet roster by ~15 |

**Complexity onboarding rules:**
- **Run 1 pool:** 6 runes, 4 kinds and 15 passives, down from 12, 9 and 32. No boss-tier passive until the first mini-boss kill. Show a "NEW" badge the first time each rune, kind or passive appears.
- **Tooltips explain *why*, not only *what*.** This is the top Dicero complaint.
- **Traits** (armor, thorns, ward, pierce) get a one-time popup the first time they appear.
- **Mechanics are staged:** the pet charge meter hides until the pet unlocks, and the potion belt shows from run 1 with 1 potion.

---

## 7. Additional meta features (prioritised)

| # | Feature | Effort | Why | Monetisation-era trap to avoid |
|---|---|---|---|---|
| 1 | **Run history** (last 50: class, route, bosses, death, build snapshot, seed) | S | Seeds are deterministic; free replays and bragging | — |
| 2 | **Achievements → unlocks** (~40; each shows progress) | S–M | Drives §6; Balatro's model | Don't make any achievement require >2 h of repetition |
| 3 | **Collection log / bestiary** (enemies, bosses, runes, kinds, passives, pets, routes; silhouettes; "won with" stamps like Peglin's orbs recording the Cruciball level) | M | Completion drive for collectors | No "complete the set for a reward" that needs luck: all entries must be reachable deterministically |
| 4 | **Seed sharing** (type/copy a seed; custom runs don't count for progress, like StS) | S | Zero server cost | — |
| 5 | **Daily seeded run** (date-derived seed, offline, personal best only, one attempt *scored*, unlimited replays unscored) | M | A shared puzzle for friends | **No streaks, no login calendar, no daily-only rewards.** Reward: a cosmetic stamp in the log only |
| 6 | **Cosmetic dice skins** earned by play (Ascension, class wins, minigame mastery, all route combos) | M | A Crowns sink after caps | **Never random**: no capsule/gacha of skins, even free. Every skin has a stated condition or a fixed Crowns price |
| 7 | **Challenge modifiers** (Heat-style, after A10 or alongside it): "Bare Bones" (all meta off, like Routine Inspection), "One Die Wonder", "Blank Slate" (Gambler dice only), "Speedrun" (10 laps) | M | Replay for experts; lets purists turn vertical power off | — |
| 8 | **Class unlock quests** (5th and 6th class later: e.g. Ranger, Necromancer) | L | Horizontal growth | — |
| 9 | **Dicey-Dungeons-style class "episodes"**: 3 rule remixes per class ("Knight: your dice are all Twins"; "Mage: runes trigger on both 1 and 6") | L | The best horizontal content in the dice genre | — |
| 10 | **Camp decoration** from milestones (statues per boss killed, like Hades' Skelly statues) | M | Visual progress in the 3D camp | No build timers (Cult of the Lamb-style idle waits) |

**Patterns to flag and refuse** (with the non-predatory version):

| Pattern | Refuse | Instead |
|---|---|---|
| Energy/stamina (Dicero's "meat") | ✗ | Unlimited runs |
| Daily login calendar / streak loss | ✗ | Nothing; or a daily seed with no streak |
| Per-day earn caps (Heroll diamonds) | ✗ | Uncapped, but payout scales only with progress |
| Merge-3 gear rarity / random stat rolls | ✗ | Deterministic levels + chosen traits |
| Build/craft timers | ✗ | Instant purchases |
| Limited-time events / FOMO skins | ✗ | Evergreen conditions |
| "Double rewards" button / revive offers | ✗ | Second Wind / Phoenix exist in-run |
| Paid or gated speed-up (a top Heroll complaint) | ✗ | 1×/2×/4× free (already specced) |

---

## 8. Risks and open questions for Vlad

1. **Currencies.** Accept Crowns + Sigils (+ pet XP), or keep the 4 themed materials with the Trinket/assignment fallback? This is the biggest structural call.
2. **Run length.** 15 laps is about 35–45 minutes. On iOS, do you want a **"Short Road" mode** (10 laps, 2 biomes, Heroll's stage-1 length) that pays about 60% Crowns? It's recommended for mobile, but it's another balance surface.
3. **Classes locked at start?** The spec says all 4 are unlocked. I recommend 2 plus unlocks at runs 3 and 6 for onboarding and excitement. It's your call if you prefer immediate freedom.
4. **Maxed-profile target: 60% (spec) or 45–50% (this review)?** Higher feels generous; lower preserves tension. Ascension covers both, but the A0 experience for casual players is set here.
5. **Base-game nerf.** The no-meta bot is already at 27–38%, above the 15–25% fresh target. Should the fresh profile be harder than today's build (nerf the base), or accept a ~25–30% fresh profile and a smaller vertical budget?
6. **Global vs. per-class Ascension.** I recommend global plus per-class badges. Per-class multiplies content life but invites "padding" criticism.
7. **Is skill in minigames welcome?** Bubble Breaker and Claw reward dexterity; if you want Diceroll to stay a "thinking cozy" game, cap the skill bonus at +15% instead of +30%.
8. **The pet firing model: auto or tap?** Auto is cozier and AUTO-friendly; tap adds agency (Heroll's core complaint is no agency). My suggestion: auto by default, with a "hold charge" long-press for experts.
9. **Balance validation.** Every meta number above is an estimate. The sim needs a `--profile=fresh|mid|max` switch and `--ascension=N` before any of this is locked. It's a cheap addition since meta is data in `profile.json`.
10. **Save-scumming minigames.** Because outcomes are "run RNG + inputs", quitting mid-minigame and reloading must resume the same board state. Confirm auto-save happens *before* the minigame opens.

---

### Sources (brief)
- Hades Mirror of Night costs, keys and respec; Pact of Punishment, Heat bounties and Routine Inspection: hades.fandom.com/wiki/Mirror_of_Night, /Pact_of_Punishment. Keepsake ranks at 25/75 encounters and Companion uses: hades.fandom.com/wiki/Keepsakes, /Companions.
- Slay the Spire Ascension 1–20, per character, seeded runs excluded: slaythespire.wiki.gg/wiki/Ascension.
- Balatro locked Jokers (45/150), decks, per-deck stakes, dilution and padding complaints: balatrowiki.org/w/Unlockables, balatrogame.fandom.com/wiki/Stakes, Steam discussions.
- Rogue Legacy 2 Charon gold toll, Living Safe, Soul Shop, House Rules: rogue-legacy-2.fandom.com/wiki/Charon, /The_Soul_Shop.
- Vampire Survivors PowerUp refund and toggle: vampire-survivors.fandom.com/wiki/PowerUps.
- Peglin Cruciball (20 levels, per class, orbs record the level): peglin.wiki.gg/wiki/Cruciball.
- Dicey Dungeons episodes as rule remixes (Cavanagh interviews, itch devlogs): thexboxhub.com interview; terrycavanagh.itch.io devlogs.
- Luck be a Landlord floors, Essence unlock (Floor 6 win or 7 wins), item toggling: luck-be-a-landlord.fandom.com/wiki/Floors, /Essences.
- Cult of the Lamb tarot pool unlocks (15 at start) and permanent doctrine criticism: cult-of-the-lamb.fandom.com/wiki/Tarot_Cards; Steam threads.
- Heroll pets, minigames (a player review says you "can mix and match which [minigames] you encounter"), grind and ads complaints: minireview.io/role-playing/heroll-roguelike-rpg, Play Store listing, and `docs/research/games.md`.
- Dicero meta and monetisation: `docs/research/games.md`.
