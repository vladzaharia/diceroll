# Diceroll balance

Produced by WP-A2. Numbers live in `core/content/` (`balance.gd`, `heroes.gd`, `enemies.gd`) and `core/runes.gd`.
Re-run the sim with: `godot --headless --path . -s tools/sim.gd -- --runs=300 --class=all --seed=1`

## Final sim (greedy `Bot`, 300 runs per class)

Seed 1:

| class | win% | avg act | avg board turns | avg combat turns | avg commands | avg level | avg fights won | deaths by act |
|---|---|---|---|---|---|---|---|---|
| knight | 35.7 | 2.88 | 48.1 | 45.8 | 298 | 10.0 | 19.5 | act1boss:1 act2:13 act2boss:21 act3:87 act3boss:71 |
| barbarian | 29.0 | 2.83 | 47.4 | 42.7 | 287 | 9.7 | 18.8 | act1boss:1 act2:22 act2boss:27 act3:84 act3boss:79 |
| mage | 28.7 | 2.78 | 46.6 | 41.7 | 282 | 9.4 | 18.1 | act1:1 act1boss:1 act2:29 act2boss:33 act3:71 act3boss:79 |
| rogue | 29.7 | 2.78 | 46.4 | 42.1 | 289 | 9.4 | 18.1 | act1boss:3 act2:22 act2boss:38 act3:85 act3boss:63 |

Seed 4242 (check against seed overfitting): knight 37.7, barbarian 37.0, mage 26.7, rogue 29.3.

Zero error events in all runs. Fights last about 2.3 player turns on average. Deaths cluster in Act 3, split roughly evenly between regular fights and the Lich, with Act 2's boss as the first real wall.
"avg act" is the act the run ended in, and a victory counts as act 3.

## Numbers changed from the spec

| what | spec | now | why |
|---|---|---|---|
| Enemy scaling | HP/ATK × (1 + 0.35·(act−1) + 0.1·(lap−1)) | × (1 + **1.0**·(act−1) + **0.25**·(lap−1)) | A 6-die pool with runes outgrows the spec curve: every class won 92–100% |
| Bone Warden HP | 120 | **200** | Bosses must be the climax of each act |
| Hollow King HP / attacks | 180 / Attack 14, Buff +2 | **450** / Attack **18** (P2 also **20**), Buff **+3** | same |
| Lich HP / attacks | 260 / (unspecified) | **800** / Attack **22** (P2 **26**), Block **30** | same |
| Knight HP | 70 | **64** | Guard block is strongest against big boss hits (knight was 43–45%) |
| Mage HP | 50 | **56** | Mage was ~20% with the lowest HP |

Unchanged from the spec: everything else. That covers the combo multipliers, rune effects, tile effects (15/30/12%), prices (die 40, rune 35/50/70, potion 20, face raise 25, reroll 90, restock 10), XP thresholds, and base enemy stats and patterns.
Numbers that the spec left open, chosen here: elite ×1.3 HP, ×1.15 attack, ×1.5 gold/XP; chest gold 12–24; gold per act ×(1 + 0.25·(act−1)); +50% max-HP heal at the start of a new act; enemy gold/XP (minion 4/3, archer 5/4, warrior 6/5, cultist 6/5, bandit 8/5, brute 12/9; bosses 40/20 and 60/30).

## Rules clarifications

Choices made where the spec was ambiguous.

**Board and movement**
1. **Passing Start mid-move.** The hero finishes the move (`hero_moved` carries the full path). Then the lap completes: heal 15%, `lap += 1`, and the board mutates (`lap_completed`, `board_mutated`). Next the **Shop** opens, and after the shop the **landing tile** resolves. Mutation never changes the tile the hero is landing on. Landing exactly on Start does the same, with no tile trigger.
2. **Lap 3 completion.** The move is cut short at Start, and `landing_preview()` already shows 0 for such dice. The hero heals 15% and the boss fight starts. There is no shop and no mutation.
3. **After a boss.** Any level-up drafts come first. Then the next act starts: a new board, the hero on Start at lap 1, the treasury reset to 10, the once-per-act reroll item available again, and a heal of 50% max HP. `act_started` carries the new board, and then the **Shop** opens. Beating the Act 3 boss goes straight to VICTORY with no drafts.
4. **Boards for Act 2 and 3** use the lap-1 layout, but one of the 6 Enemy tiles is an **Elite**.
5. **Enemies on a tile** are rolled when the tile is created, so the telegraph is honest. The difficulty band is `act + lap − 2` (0..4), and each band has its own enemy pool and count range (`EnemyDefs.POOLS/COUNTS`). An Elite is a Brute, plus one pool enemy from band 2 on. HP and attack scaling use the act and lap **at fight start**.
6. **Cleared fight tiles** keep their type until the next mutation but get `enemies: []` and `cleared: true`. Landing on one does nothing. At mutation they become Empty.
7. **Mutation.** +2 Enemy and +1 Elite go on random Empty tiles. "Events refresh" means Empty tiles become Events until there are 3 again. If there are not enough Empty tiles, fewer tiles spawn.
8. **Treasury.** In every board roll (rerolls included), each distinct value rolled 2 or more times adds `value × 2` to the bank. A triple counts once. Landing on the Treasury pays out the bank and resets it to 10.
9. **Portal** targets are the next 8 tiles, wrapping past Start. A teleport that passes Start completes the lap like walking does: Shop, or the boss on lap 3. `hero_moved.path` is `[destination]` with `teleport: true`.
10. **Board rolls** use each die's (edited) faces. Only Gilded does anything on the board: +pips gold for the chosen die. Wild shows its real face on the board.
11. **Outbreak and Garden** use the next 3 Empty tiles ahead in walking order. Corners are skipped, and the search wraps.
12. **Trap and Dice Duel** rolls are plain d6 rolls from the run Rng, not pool dice.

**Combat**
13. **Wild.** The value chosen for the combo is the die's effective value everywhere: the damage sum, Heavy, and SIX/ONE triggers. With several Wild dice, the best joint assignment wins. Ties go to the higher group sum, so a free Wild becomes 6.
14. **Damage** = `floor((pip sum with Heavy ×2 + Blade bonuses) × (combo mult + 0.5 per Echo in group)) + ATK`. Main damage, Ember and Thunder are absorbed by enemy Block. Poison ignores Block.
15. **Targets.** When the target dies, the first living enemy becomes the target. Venom and Frost then apply to that new target. Order at ATTACK: combo → main hit → Ember → Thunder → Venom/Frost → Guard → Vampire → Gilded → Lucky.
16. **Block.** Hero block resets at the start of each player turn. **Enemy block resets at the start of that enemy's own action**, so a Block intent protects it through the player's next attack.
17. **Poison** ticks at the start of each enemy's action (damage = stacks, then −1), even while the enemy is frozen. **Freeze** skips one action, and the enemy then rolls a fresh intent.
18. **Curse N** locks N random dice at the start of the next player turn. They roll but cannot be marked. Hollow King's "Curse ×2" is `curse` with value 2.
19. **Lucky** banked rerolls live on `RunState.banked_rerolls`. They carry over to the next fight (max 2) and are used up at the next combat turn start.
20. **Enemy patterns.** Minion and Warrior pick randomly each turn. Archer cycles `aim` (does nothing) then Attack 8. Cultist cycles Curse/Attack. Bandit cycles Attack/Buff. Brute cycles Block 8 (the "charge") then Attack 12. Cycles start at a random point. Attack intents already include scaling and any Buff, so `intent.value` is exactly what will hit.
21. **Bosses** are not scaled by act or lap. Phase 2 starts at ≤50% HP (`boss_phase`), and the boss switches to its phase-2 pattern. Summon adds a Skeleton Minion, capped at 3 living non-boss enemies (otherwise the boss Blocks 8). Summoned minions give no rewards. **Chaos** (the Lich in phase 2) sets a random face above 1 on a random die to 1 for the rest of the fight. The face is restored when the fight is won.
22. **Rewards.** Gold is multiplied by (1 + 0.25·(act−1)) for regular enemies. Elites give ×1.5 gold and XP, plus a guaranteed 1-of-3 rune choice (a DRAFT offer with `source: "elite"`). XP thresholds are cumulative totals.

**Progression and modals**
23. **Draft "Rune".** The option names a specific random rune. Picking it opens `rune_assign`, which may replace a die's existing rune. **Draft "Face Raise"** opens a raise-only Forge (`ops: ["raise"]`), and you may skip it.
24. **Shop.** It has 3–4 items, with at most one of each non-rune item and distinct runes. A Face Raise item raises the chosen die's **lowest** face. The +1 combat reroll can be bought once per act, up to the cap of 4. The shop also opens at the start of Acts 2 and 3.
25. **Chest.** 50% gold, 50% a 1-of-3 rune choice (`source: "chest"`). Chests, Events and Campfires become Empty when used. Traps stay.
26. **Events.** In the Dice Duel, the bet choices are disabled without enough gold, a tie returns the bet, and there is always a "Walk away" choice. In the Merchant, the HP loss is `round(10% max HP)` off max HP, and HP is capped to the new max. The Cursed Idol is disabled at HP ≤ 15, so it can never kill. The Shrine offers 2 of its 4 blessings.
27. **HP percentages** round to the nearest whole number, minimum 1.

**Event and contract notes**
28. `tile_triggered` carries the tile type as **`tile_type`**, because a `type` field would collide with the event's own `type` key.
29. Damage to the hero in combat emits `damage` (`target: "hero"`, with `hp` after). HP changes outside combat, and heals, emit `hp_changed`.
