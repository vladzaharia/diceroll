# Research: Heroll (111%) and Dicero (HABBY)

Tags: [V] verified from a primary/near-primary source (fan wiki API dump, store listing, official-derived guide, in-game cheat sheet quoted by a reviewer); [R] reported secondhand (reviews, guides, forum quotes); [I] inferred by us.
Source caveat: several SEO sites (iosgames.net, iofreeonline.com, peppagame, iofreeonline "Dicero" page) contain AI-generated text that contradicts the real games (e.g. "Soul Shards", "The Frozen One" relic, "reforge dice faces", "willpower", "branching map"). Ignored here. Heroll fandom wiki was reachable via `heroll.fandom.com/api.php?action=parse` (Exa/WebFetch blocked). No first-hand play was possible.

---------------------------------------------------------------
## 1. HEROLL / "Rolling Hero" (111% / Percent Games; iOS name "Heroll : Dice Roguelike")

### Identity
- iOS release 25 Feb 2025 [V, Game Solver/App Store]; Android pkg com.percent.aos.rollinghero, ~4.6 stars, 76K reviews [V, Play listing]. Same studio as Lucky Defense [R].
- PC sequel "Heroll: IF" by OFFMOON, Steam, 2 Nov 2026: "roll TWO dice", each pass of Start adds new enemies/events to the board, gear + blessings + "augments", town rebuild as meta, pets [V, Steam page]. So mobile may also use 2 dice ("roll a set of dice" [R]); unconfirmed for mobile [I].
- Pixel art, one-thumb, "one-button Monopoly" [R].

### Core loop and run structure
- Tap ROLL, hero token auto-walks the rolled number of tiles around a looped board (Monopoly-like square ring) [V/R: iosvizor "circle, or rather a square of cells"]. Landing tile triggers its effect. Passing the Start tile = clear a "floor" (one lap = one floor) [V, wiki: "Reaching this tile moves the hero to the next floor"].
- Stage = N floors (most stages 15; stage 1 = 10, stage 9 = 13, stage 14 = 13, stage 17 = 13) ending in a stage boss whose "boss event" tiles take over the board [V, wiki Stages/Tiles; R Check-App: "boss spawns and takes over the board"]. Losing = run over (no mid-run save; quitting means restart at floor 1) [R, TapTap/Play reviews].
- Board grows per lap: new enemies/events are added when passing Start [V for Heroll: IF; R for mobile via Check-App "each round enemies/events added"]. Board is procedurally generated per run [R].
- 20 stages listed (each named after its boss): 1 Doombringer, 2 Stonecalibur, 3 Red Dragon, 4 Big Axe, 5 Queen Kraken, 6 Lord of Gluttony, 7 Two Face, 8 Forgotten Hero, 9 White Requiem, 10 Frost Heart, 11 Last Maestro, 12 Count Dracula, 13 Deokja & Mochi, 14 Merciless Angel, 15 Prisoner No. 24601, 16 Hero of Oblivion, 17 Empress of Mirrors ("copies and scatters tiles"), 18 Saintess of Stigma, 19 King's Nursemaid, 20 Abyssal Cube [V, wiki]. Clearing unlocks next stage. Per-floor rewards: gold, diamonds (1/floor, cap 100/day), scrolls, upgrade stones [V].
- Session length: a stage run is 10-15 laps; reviewers call it long enough that "make sure you have time to finish" [R, TapTap]. Rough 10-30 min guess [I]. Game speed/fast-forward is a paid feature, which players resent [R].

### Tile types (wiki "Tiles") [V]
Enemy, Good Event, Bad Event, Boss Event, Corner, Blessing, Empty.
- Enemy: fight 1-4 enemies; golden sparkle = win grants a legendary "sub-equipment" piece.
- Good events: Chest (3 random sub-equipment); Dice Battle (blackjack-21 with dice vs NPC Deoksoon, 10 pts first win, option to continue); Golden Wagon (deal damage to it for points/potions/gear, damage persists between events); Forge (start with a common item; try to upgrade rarity: Rare 80%, Epic 50%, Legendary 10%; failure destroys it); Lucky Scratch (1/10/30 pts); Claw Machine (2 plays; legendary item at tank bottom); Dicereel (slots: potions, common gear, good event tiles, blessings); Beat Drop (rhythm timing -> gear rarity by score); Drawing Lots (draw spoons, jackpot 15 pts, escalating win odds 20/25/33/50/100%); Amplification Star (enhance a random bonus on an item; +10 pts if you hold only commons).
- Bad events: Prison (must roll above a threshold that drops by 1 each try; fail damage 10%/15%/20% max HP; 3 fails ends it; fatal damage leaves 1 HP); Monster Outbreak (next X tiles become enemy tiles); Tile Lock (locks a random tile; landing removes lock but effect does not fire).
- Boss event: stage-specific.
- Corners (special tiles at the four corners) [V]: Start (next floor; shop appears here every 3 floors; also ~+30% HP heal when passing [R Check-App]); Flower Garden (next row's tiles all become chests); Race (reach Start within 3 rolls -> legendary item); Housing Support (roll two dice, build that many houses in next row, points by count); Warp (teleport to random tile); Wall of Thorns (-1 enemy on every enemy tile in next row); Piggy Bank (doubles rolled add pips to bank; landing on it cashes out); Black Market (pricier shop, no reroll).
- Blessing tile: grants a random blessing. Empty: nothing.
- Key design point: many tiles REWRITE OTHER TILES ("next row/next X tiles"), i.e. the board is a mutable resource [V].

### Dice and movement
- Player has no choice besides when to tap roll; movement is automatic [R]. Doubles matter (Piggy Bank), "roll two dice" wording appears in Housing Support, so >=2 dice exist on board [V]. Blessings named "Protection Dice, Dice of Recharge, Dice of Odds, Lucky Dice, Healing Dice, Miracle Dice, Urban Planning, Thrill" indicate roll-linked effects [V names; effects mostly not recorded on wiki].
- Reviews: pure luck, "press a button... die at level 10 of 15" [R]; "some dev-set determinism" accusation [R]; an achievement "it's rigged" [R].

### Combat [V/R]
- Auto-battle, real-time, short fights (seconds) on a separate battle screen; hero has one life; enemies attack automatically [R Check-App, iosvizor]. Player interventions: tap POTION to heal (potion count = capacity, recovery % upgraded in shop), tap dropped gear to equip mid-battle (battle pauses; only 8 gear slots displayed) [V wiki Pillager note; R].
- Stats: ATK, ATK SPD, Accuracy, Crit rate, Defense (DEF, flat-ish decimals), Max HP, Evasion, Counter rate, Lifesteal, HP regen, Kill Recovery, True DMG [V wiki Equipment; R]. Evasion considered "dead stat" by mid-game [V wiki].
- Gear: 4 slots (weapon = ATK/ATK SPD, head = ACC/Crit, shield = DEF/Counter, body = HP/Eva) [V]. Weapon classes: Spear (+SPD -ATK), Sword, Axe (+ATK -SPD). Each item has rarity-gated passive effects (e.g. Blazing Ember Sword: 30% burn on hit; Soul Reaper Axe: +1% base ATK per kill up to 20%; Thornmail reflects 10%; Rogue's Robe throws a dagger on evade). Drops in a run are "sub-equipment" with substats (lifesteal, regen, crit, evasion, max HP) that you compare and swap; a lower-tier item with better substats can beat higher [R Check-App]. Complaint: replacing a "legendary 6" with a "gray 7" - unclear comparison numbers [R].
- Run economy: "points" (in-run currency) spent at the shop (every 3 floors at Start, black market corner). Shop sells permanent-for-run upgrades: Potion Recovery+, Potion Capacity, and special effects like "on potion: +300% ATK" or "attacks reduce enemy DEF 30%" [R Check-App]. Blessings can be bought (e.g. Pillager 18 pts, Potion of Rage 18, Auto-Recharge Potion 15, Soul Absorption 17: +10 max HP per kill; Potion of Lightning 15) [V wiki]. 40 blessings listed: Pillager, Potion of Rage, Auto-Recharge Potion, Soul Absorption, Potion of Lightning, Blood Drain, Potion Plunder, Protection Dice, Guardian Strike, Potion of Balance/Defense/Growth/Reversal, Warmonger, Weakness Exploit, Dice of Recharge, Subsidy, Quality Over Quantity, Guardian Spirit, Recuperation, Thunder Call, Charisma, Opening Strike, Dice of Odds, ATK Booster, ATK SPD Booster, Corrosive Strike, Urban Planning, Lucky Dice, Healing Dice, Ignite, Too Slow, Persistent Life, Gambler's Potion, Last Stand, The More The Better, Population Control, Miracle Dice, Embers, Thrill [V names].
- Dismantle spare gear into "rubies" (shop currency) [R].
- No XP-level-up skill draft in-run; power = gear drops + blessings + shop buys [I from sources].

### Meta progression [V wiki unless noted]
- Hero base upgrades with Gold + Scrolls (ATK +1, HP +6, ACC +2, DEF +0.3 per level).
- Equipment: gacha "Mimic Hunt" (diamonds/keys; chests 20/50/100 dia; pity 20 draws legendary / 50 draws S-legendary); 3 identical -> next rarity; rarities Common, Rare, Epic, Legendary (0-2 stars), Mythic (0-3 stars), Eternal; level caps 5..50; "S" tier gear = special.
- Relics: 4 types (ATK/HP/ACC/DEF), one each; drawn at Relic Appraisers with Relic Shards (Hair 100 shards, Bald 500); merge 3->1.
- Pets: companions with active skills on cooldown + passive stat (Freezing Froggy, Darkness Catniss execute, Sniper Raccoon, Super Beam Peng, Shark Cannon, Arrow Foxy, Bang Bang Ducky, Inferno Drakey, Healing Bunny, Dino Dice, Mini Doombringer...); leveled 1-20; mounts also exist [Play listing].
- Modes: Arena (PvP-ish), Daily Dungeon, Destiny, Patrol, Mimic Hunt, Pet Sanctuary, 1st Anniversary event; minigames (Dice Battle, Spin the Treasure). Energy gates runs but "generous" [R]. Monetization: optional rewarded ads (no forced ads originally; later reports of forced ads change [wiki link]) + VIP/passes; IAP $2-40 [V App Store].

### Presentation
- 2D pixel art, portrait, board seen top-down as a ring of tiles with the hero token walking it; encounters open a side-view auto-battle panel [R]. Cheerful, jokey tone ("Hero... what's wrong with you?!"), lots of little minigames. UI reported cramped/small icons, no stat sheet [R].

### Praise
- Rolling loop is instantly readable and "one more roll" addictive; variety of tiles and minigames; optional ads; free rewards generous; can restart a run fast [R: Play/App Store reviews].
- Board-as-ring makes risk visible (bad tiles ahead, boss influence) and "cheerful chaos" [R].
### Complaints
- Player agency ~ zero ("just tapping roll", "Casino pretending to be a game") [R SNAPP, App Store].
- Balance: gear swaps confusing; boss-influenced tile kills feel unfair; hard walls in later stages [R].
- No pause/save mid-run; animations slow; fast-forward paywalled; two speed sliders requested [R].
- Melee-only (players ask for ranged/magic) [R]; ad density complaints on Android; chat toxicity; lack of stat screen [R].

---------------------------------------------------------------
## 2. DICERO! (HABBY; Archero/Archero 2/Survivor.io/Capybara Go studio)

### Identity
- Soft launch ~Mar 2026 (Huxiu), global launch April 2026 iOS/Android [V]. >$100K-150K/day IAP in first weeks [R Gamigion, Friendly GameDev/AppMagic]. Android pkg com.bailing.lark.roll.dev (dev id) [given]. Pixel-shader art with 3D-ish sprites; anime-flavored characters. Gamigion calls it "an iteration on Balatro: dice poker instead of poker"; also notes Habby REMOVED rewarded ads, inventory merge is 1-to-4, 6 gear slots [R].
- Note: dicero.app and dicero.wiki are fan/SEO sites (codes, calculator), useful but unofficial [I].

### Core loop and structure
- Chapter -> stages (early chapters long; later 10-20 stages per run) [R]. Each stage in a run is a "phase": small enemy waves, random chest, bonus NPC, boss at end [V Huxiu; R].
- Turn-based: enemies visibly walk down a lane toward the hero; you must kill them before they arrive and deplete HP [V NY Game Critics; R]. Turn = auto-roll dice at start, up to 3 rerolls (tap individual dice to reroll only those), press ATTACK [V].
- Stamina ("meat", 10 to start) per stage attempt [V]. One-hand portrait play [R]. Session: a stage ~1-3 min; a chapter run longer [I].
- "No revive unless taken as a skill" creates tension [R Friendly GameDev]. Revive skill considered the biggest run-defining pick [R].

### Dice: count, faces, values
- Standard d6 with pips 1-6 [V; "6-value dice"]. Damage from dice points: dice attack = pips (scaled by talent "dice point attack" levels + gear "Pip Attack") plus panel attack, then multiplied by combo multiplier and skill multipliers [R dicero.app calculator, Huxiu "sum of all dice pips = damage"]. Defense reduces enemy damage; combo bonuses are computed after enemy defense [V FAQ].
- Dice count: start with 2 (of 5 slots) [R]; skills "Dice Unlock (Battle Dice +1)" grow to 5 (some reports up to 6 "Battle Dice") [R]. Early stages prioritise adding dice up to 5 [V Huxiu].
- Rerolls: 3 per turn [V multiple]; skills "More Chances", "Roll Surge" add rerolls/effects [R].
- Combo table (in-game cheat sheet, quoted) [V NY Game Critics]: High Roller x1; One Pair x1.5; Two Pair x2; Three of a Kind x2.5; Straight x3; Full House x3.5; Four of a Kind x5; Five of a Kind x10. All five matching dice glow purple.
- Hand-level state: no "hold" button - you choose which dice to reroll, so unchosen ones are kept [R].

### Dice-building (what is actually customizable)
- Faces are NOT reported as editable in verified sources; one aggregator (Gamigion) says you can "put multiple same pips on the sides of dice" [R, single source, possibly wrong]. The verified customization layer = attaching skills/"materials" to individual dice [V Huxiu, Mobi.gg, Gaming on Phone]. Treat face editing as unconfirmed [I].
- Materials (aka dice modifiers): earned on level-up (EXP); each is bound to a die and has a trigger window. They convert your basic attack into an archetype form and add damage. Triggers: Turn start; Dice combo (the carrying die must be part of the pair/two-pair/3/4 group [V]); Reroll use; Kept/Lost if rerolled; Specific face (e.g. shows a 6); Rerolls reach zero; Reroll same-or-higher; Does not enter play (die unused) [V dicero.app + progression guide].
- Skills: passive/active, drawn from Treasure chests, "toad Roulette", the Angel; rarities vary [R]. Skill priority per source: Revive > archetype skills > multiplier skills > poison > HP [R].
- Each die can be leveled (poison example: "each die upgraded to lvl 5 -> up to 45 stacks") [R].

### Archetypes and named effects [V unless noted]
Weapons unlock archetypes: Greatsword (single target, low-HP scaling), Hammer/Greathammer (AoE, full damage to every enemy), Staff/Orb (multi-hit bouncing orbs; damage split among targets; scales over battle). Any-weapon: Swordwave/Sword Aura (default; many small hits, "dozens to hundreds of hits per turn") and Poison (stacks; needs long fights).
- Greatsword materials [V Mobi.gg]: "on reroll: attack becomes Greatsword +11%"; "turn start: basic attack +22%"; "on combo: becomes Greatsword +33%"; "reroll same-or-higher value: +22%". Skills: Berserk (+50% Greatsword dmg, +5% per 5% HP lost), Blood Blade (+100% Greatsword dmg), Rage (+30% crit chance); 9 skills in the build.
- Swordwave: "Sword Will: when forming a dice combo, gain 3 Swordwave stacks"; "Sword Oath: gain Swordwaves = this die's number"; "Sword Shadow" [V NY Game Critics, Gaming on Phone]. Best triggers: Combo > Turn start > Reroll use >>> Die shows 6 [R].
- Orb: "Mirage" (upgrade gives 3 orbs if die not rerolled; "Lost if reroll" is the key orb skill); triggers ranked Lost-if-reroll > turn start > combo > rerolls hit 0 [R].
- Hammer: reroll-count scaling (+8/16/24% by rerolls used); "up to +32% if a die is not rerolled" [R Treyex]. 
- Poison: one stack per die at turn start (5 dice -> 5 stacks); scaling by dice count [R].
- Utility: Dice Unlock, More Chances, Roll Surge, Light of Redemption (revive-like), First Strike talent (extra Battle Die at run start), Dexterity (dodge), Direct Hit (crit) [R].
- Design pattern (Huxiu): "attack transforms into Greatsword after combo, unlocking Greatsword-only multipliers -> several-hundred-fold damage" [V/R].

### Enemies, bosses
- Enemies walk a lane and hit on arrival; hero has HP + defense + dodge + crit [V/R]. Bosses have multiple health bars (10+ late), heal and add shields each turn, and can disturb dice: Ice/Frosthorn Minotaur adds "chaos dice"/swaps dice [V FAQ, R]. No explicit "intent icons" verified [I: not reported].
- Late chapters hit an HP wall around chapter 4-5 (needs gear/talents/money) [R].

### Meta progression [R unless noted]
- Gear: 6 slots (weapon, scarf, necklace, boots, jewelry, armor); merge duplicates (common->green->blue->epic..., legendary needs same-type); "S gear" goal; Outfits (prebuilt gear w/ skills). Gacha keys (silver/gold).
- Talents: permanent stats (crit, dodge, ATK, dice-point attack levels), bought with gold + talent crystals; rarity roll-dependent.
- Pets (unlock ch.15-5), Asterites (ch.25-1; rerollable stat slots, silver/gold crown effects), Curios via co-op (set bonuses; blessings), Dragon Lair (turn-limited damage race, no energy), Star Challenge (replay stages for missing stars), co-op mode (shared archetype skills when switching characters) [V FAQ].
- Monetization: gems, keys, monthly passes, packs; rewarded ads removed [R Gamigion]. Complaints: paywall-ish wall around ch.5, resource scarcity [R].

### Presentation
- Portrait, hero and enemy lane at top/middle, five die slots and big ATTACK button at bottom, a combo cheat-sheet book icon, skill icons attached to dice, tap-to-select targets [V NY Game Critics]. Pixel-art characters with lots of small animations; strong boss designs; fast loop [R QTE Gamers].

### Praise
- Simple to learn, deep decisions on reroll vs keep, Yahtzee/Balatro-style payoff, satisfying purple 5-of-a-kind, boss fights, art [R].
- Fast sessions, one-handed play, low frustration vs Archero (turn-based = low pressure) [R Huxiu].
### Complaints
- Tutorial explains what, not why; skill wording vague; hidden trigger rules [R QTE Gamers].
- "Not enough depth / don't need to think" for some [R]; difficulty wall ~ch.5, monetization pressure [R].
- Early stage very RNG; poison "debated" as too dominant [R].

---------------------------------------------------------------
## 3. Mechanics worth borrowing (for a Heroll-board + Dicero-dice game)

### From Heroll
1. Looped board = one floor; passing Start = floor clear + heal + shop every N floors. Clear rhythm and a natural "stage timer" [V].
2. Board grows/mutates each lap (add enemies/events) so risk rises predictably [V Heroll: IF].
3. Tiles that rewrite other tiles ("next row becomes chests", "-1 enemy in next row", "monster outbreak", "tile lock", "warp") - makes movement strategically interesting [V].
4. Corner tiles as designed set-pieces with distinct rules (Race: reach Start in 3 rolls; Piggy Bank: doubles feed it; Prison: roll-over-X escape) - all dice-native [V].
5. Enemy tile with 1-4 monsters + "golden sparkle" telegraph for jackpot fights [V].
6. Risk-reward gear gambling (Forge 80/50/10% with break on fail), minigame tiles (21 dice battle, drawing lots, claw) as pacing variety [V].
7. Boss "takes over the board" (converts tiles; Empress of Mirrors clones tiles) - boss as board mutator [V/R].
8. Shop at Start every 3 laps; black market corner [V].
9. Pass-the-Start heal (~30%) [R] to reward completing laps rather than tile luck.
10. Fix from complaints: let players make choices (see below), show comparison numbers, allow pause/save.

### From Dicero
1. Roll -> up to 3 rerolls -> commit; reroll individual dice; kept dice remain. [V]
2. Yahtzee-style combo multipliers (x1, 1.5, 2, 2.5, 3, 3.5, 5, 10) - transparent, cheat-sheet UI [V].
3. Skills bound to specific dice with trigger windows (turn start / combo / reroll used / kept / lost on reroll / shows 6 / rerolls hit 0); "carrier die must be in the combo" rule; creates real reroll tradeoffs [V].
4. Archetype conversion: combo turns basic attack into a "form" (Greatsword/Hammer/Orb) that unlocks form-specific multipliers; 5 archetype families with counterplay roles (AoE, single-target, scaling, poison) [V].
5. Dice count growth 2 -> 5 as first-priority upgrade; more dice = higher combos and more trigger slots [V].
6. Material/skill draft on level-up; multiple sources (chest, roulette, angel) [R].
7. Revive as a build-defining, scarce skill [R].
8. Boss disruption of dice (chaos dice) [V].

### Proposed synthesis (our inference [I])
- One shared dice pool drives BOTH movement and combat: the hand you build each turn is split or read two ways. Example: pips sum = tiles moved; combo tier = combat multiplier on the tile you land on. This creates the core tension "roll for the tile I want vs. roll for the combo I need".
- Rerolls become a scarce per-turn resource used for positioning (land on shop/chest, skip enemy tile) and for combos; some skills convert leftover rerolls into damage/heal.
- Reroll-triggered/kept-die skills (Dicero) + tile-rewriting events (Heroll) = deep synergies: e.g. a die "Warp" material teleports on doubles; "Sweep" die converts an enemy tile ahead into a chest on a pair; Piggy-Bank tile pays out combo tier.
- Land on an enemy tile -> combat resolves as a short Dicero-style hit using the current hand (auto or one-more-reroll window), so combat needs no separate screen; boss laps use multiple hits with shields (bosses that alter dice).
- Keep the Heroll ring board (one lap = one floor, board grows per lap) with a visible boss timer; tile types as the "enemy intent" surface (telegraph danger ahead).
- Build layer: 3-6 dice, each with a slot for a material (trigger windows as above), floor-end shop to add dice / rework materials / swap faces (face edits = new, our own idea since Dicero does not verify it).
- Meta: gear + talents + pets (both games) as light layer; avoid gacha walls that both games get criticised for; add run save/pause and fast-forward as free.
