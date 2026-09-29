# Resume point (paused 2026-09-28; progress log at the bottom)

All agents were stopped on purpose by Vlad. Nothing is running. Each unfinished work package lives in its own git worktree, with a WIP checkpoint commit at its tip. Nothing below is merged to `main` yet.

Standing rules for every resumed agent:
- **Clean up:** heavy parallel sims are fine, but leave no stray processes (sims, servers, renders) behind.
- **Test across devices:** every visual change is verified with `tools/shoot_matrix.sh <scenario> <dir> [all|desktop|mobile|dpi|zoom|quick]`, not a single resolution. The matrix covers desktop 1280×720 → 1920×1080; iPhone 17 / 17 Pro and 17 Pro Max in portrait and landscape; iPad mini and iPad Pro 13" in both orientations; iPhone Duo outer (portrait) and inner (portrait and landscape); @1x/@2x density; and UI zoom 0.8–1.5 (`--ui-scale`). Notch and home-indicator insets are emulated with `--safe`.
- **Never launch a windowed Godot.** Use `tools/shoot.sh` for screenshots, running one at a time; from a worktree use `GODOT_PROJECT=$PWD /Users/vlad/Repos/diceroll/tools/shoot.sh ...`. Use `--headless` for tests and sims.
- **Commit with explicit paths only.** End commit messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Tests:** `./tests/run.sh`. Run `godot --headless --path . --import` first in a fresh worktree.
- **The spec is the source of truth:** `docs/specs/2026-09-28-diceroll-design.md`. §15, §16 and the "§16 decisions" override earlier sections.

## Merge order when resuming
1. **Meta rules** (core), then 2. **WP-D1** (biomes/enemies), then 3. **WP-D2** (speed/AUTO UI). After those merge:
4. Camp hub UI, 4 minigame UIs, potion belt in the HUD, pet familiars (models, orbit, charge meter UI), and removal of the level-up draft UI.
5. A UX/UI designer review of the whole game (read-only, screenshots, ranked report published as an artifact), then fixes.
6. A second game-design pass on the meta with real sim data.
7. Final exports (macOS, iOS device steps, web) and a full play_auto regression across routes and classes.

## 1. Meta rules + rebalance
Worktree `.claude/worktrees/agent-ac6530c2935949512`, branch `worktree-agent-ac6530c2935949512`, tip `0cb6d6e`. Main has already been merged in (it includes the smart AUTO bot).

The stopped agent's last words were: "Now measure all three policies at fresh after these changes". It was mid-balancing. Verify the state by running the tests and sims.

Full task:
- **A. Meta layer per §16:**
  - Profile: Crowns, Sigils, per-pet XP, unlocks, gear and traits, workshop packs and pool toggles, pets, loadout, ascension, records, mode.
  - Camp/MetaFlow commands and events.
  - `new_run` opts: profile, mode, ascension.
  - Run rewards banked into the profile; losses still pay.
- **B. Design-review changes** (`docs/reviews/2026-09-28-meta-design-review.md`):
  - Pets use charge meters that persist across fights, and fire automatically.
  - Potions: 30% heal, belt max 3, one per combat turn, 4 potion types.
  - Minigame fixes, with bronze/silver/gold reward tiers. One tile per equipped minigame. Skill band ±15%. AUTO plays at 85% of par.
  - Gear caps and traits; Workshop unlock packs and pool toggle.
  - Crowns payout table, with a leftover-gold cap of 5 and a catch-up bonus.
  - Ascension: 10 global levels, with a double final boss at A10.
- **C. User decisions:**
  - Currencies are Crowns + Sigils + pet XP; there are no themed materials.
  - A fresh profile has the Knight only. Unlocks are spread over runs 15–25 and validated with `sim --campaign=40`. Keep the `lock_classes` flag.
  - Short Road mode: 10 laps, 2 biomes, about 60% of the Crowns.
  - Save state at minigame entry.
- **D. Balance: luck stays, and the bot becomes realistic:**
  - Mechanic nerfs for Wild/Heavy stacking and any other degenerate combos.
  - `AutoRules.skill` is "realistic" (default, bounded rationality through the private RNG) or "expert".
  - Sim policies: greedy, realistic, expert.
  - Targets at A0, standard mode:

    | Profile | Realistic bot |
    |---|---|
    | Fresh | 30–40% |
    | Mid | 45–50% |
    | Maxed | 55–65% |
    | Maxed, A10 | 20–30% |

    Greedy on a fresh profile should land around 15–30%. Expert on a fresh profile should stay at or below about 75–80%.
- **E. Clean-up:** delete the debug files (`tools/_batch.sh`, `tools/_dbg_meta.gd`). Update tests, sim and `balance.md`.
- **Mid-task corrections from Vlad** (may not be implemented yet):
  1. **No upgrade drafts from kills.**
     - Fights pay gold (and pet XP/charge) only.
     - Levels become automatic and slow: about 5–7 per run, each +4–6 max HP plus a heal, with no choice. The `level_up` event carries `auto:true`.
     - Upgrades come from shops (the main source), events, chests, minigames, elites and the mini-boss.
     - Retune the shop cadence and gold income. Report upgrades per run by source in `balance.md`.
  2. **Corrected board movement.**
     - The move uses the two pip values with the most dice, one die of each. Ties at any rank are broken randomly with the run RNG. Blanks (0) are ignored unless fewer than 2 non-zero dice remain. If only one value exists, two dice of it move.
     - Examples: [2,2,2,5,6,6] → 2 + 6 = 8; [2,2,5,6] → 2 plus a random pick of 5 or 6; [1,3,4,5,6] → two random values.
     - `double = true` when the most common value has 2 or more dice (the roll contains a pair). It feeds the Treasury (pair value × 2) and doubles passives and pets.
     - `board_rolled` gains `pair_value`.
     - Update tests, the bot and the sims.

## 2. WP-D1: new biomes, enemies, route card
Worktree `.claude/worktrees/agent-a956bea5634177d9c`, branch `worktree-agent-a956bea5634177d9c`, tip `f3b9a9e`.

Done (committed):
- Biomes are selected by id.
- Glade, Frostpeak and Magma built from BlockBits, with ice and lava tiles.
- **Magma rework:** calm basalt slabs, lava channel and falls, crust-plate lava sea, ash plinths with ember skirts, Cinder Forge set piece.
- Calm ground shader for the Glade (dirt path, flower patches) and the Frostpeak snowfield.
- Build, music and arrival card by biome id; route-aware lap chip; scenario passthrough for route, boss and mini-boss; `game_biome_change --to=`.

The stopped agent had just said it "accidentally discarded uncommitted edits; re-applying them". The WIP checkpoint may be missing part of that; check the diff.

Remaining / to verify:
- **Magma vs. the other biomes.** Vlad said Magma needed WAY better tiles. Re-shoot Magma side by side with Crypt and Hollow at 720×1280 and 1280×800, and iterate until it's at least as readable.
- **Enemy looks for all new ids** (thorn_sprite, wolf_bandit, hollow_wisp, frost_skeleton, ice_archer, bone_knight, ember_imp, magma_brute).
  - Mini-bosses: frost_warden, bone_champion (fix the goofy head), grave_mage (improve), briar_beast, cinder_brute, all at about 1.5× with an aura.
  - Bosses: bone_warden, cinder_king, magma_golem (1.8×, shell shatter in phase 2).
  - Icons for the new intents, traits and statuses.
  - Handle `enemy_healed`, warded/pierce, burn ticks, and shatter.
- **Route card** at run start from `route_info()`, plus the route on the pause menu and summary screen.
- **Scenarios** (board/combat/boss/mini per id, enemy_gallery, route_card, tiles_ice_lava), then full play_auto runs of glade→frost→magma and crypt→hollow→throne.
- **Bug reported by Vlad: the hero attacks from the wrong tile.** `CombatStage.begin()` sets `hero_home` from `combat_anchor(idx)` but never moves the hero there, and the lunges and `clear()` use `hero_home`. The fix:
  - Place the hero on `idx` in `begin_on_board` (with a warning if it had to move).
  - Snap the hero to `hero_home` in `begin`.
  - Compute every lunge and return from `hero_home`.
  - Fix the scenarios.
  - Add a position check.

## 3. WP-D2: speed pill and AUTO UI
Worktree `.claude/worktrees/agent-af88b4e005095bada`, branch `worktree-agent-af88b4e005095bada`, tip `07cfd06`. Main has been merged in, and the tree is clean.

Done (committed):
- The AUTO system (`game/auto`, `ui/auto`) with its controller hooks.
- A scenario compile fix, ticker sizing, the skill choice in AUTO settings, and guards for highlight rings.

Remaining / to verify:
- **Speed pill:** 1×/2×/4×, persisted. 4× condenses beats.
- **AUTO toggle:** plays `Bot.decide` steps with a visible delay, a reason ticker and element highlights. It stops on `stop:true` with a toast, turns off on any manual tap, and starts off after loading a save.
- **AUTO settings panel:** scopes, stops, focus, mini-boss fight, skill; saved under `[auto]`.
- **Scenarios:** ui_speed_auto, ui_auto_settings, game_auto, and `play_auto --ui-auto=1`.
- **Verification:** screenshots at both sizes, and a full run at 4× with no errors, confirming that stop conditions hand control back.

## Progress since resuming (2026-09-28)
- **Merged to main:**
  - Meta rules + rebalance (313 tests; realistic bot: fresh 36%, mid 49%, max 61%, A10 21%).
  - WP-D1: biomes, enemies, route card, and the hero-tile fix.
  - WP-D2: speed and AUTO UI, alignment fixes.
  - App icon "doubles" (with a single die below 114 px).
- **Magma margin change:** made, then reverted at Vlad's request. He prefers the original Magma.
- **In progress (worktrees):**
  - WP-E1: Camp hub, profile persistence and meta flow, results screen. It uses the new packs: Armory weapons (FantasyWeapons EXTRA), a built-up camp (Forest Nature, ResourceBits, RPGTools EXTRA, Dungeon EXTRA), NPC keepers (Adventurers EXTRA).
  - WP-E2: the 4 minigame UIs and minigame tiles. Fossil Hunter is changed to luck-based: no number hints, bigger grid (Vlad).
  - WP-E3: potion belt, pet familiars, auto level-ups, remaining new events.
  - (merged) WP-F1: level scene variety. Seed-driven dressing kits per biome using the new packs; Magma keeps its tight framing.
  - (merged) WP-F2: enemy variety. Real KayKit Skeletons, Adventurers EXTRA, Mystery Monthly characters; 2–4 variants per enemy id.
  - (merged) WP-F3: UI and board polish with the new assets, plus responsive layout. Fixes the matrix bugs (iPhone empty band, narrow tray at 1080p, HUD overlap at 150% zoom) and adds a UI-size setting.
- **Classes, enemies and skins** (Vlad): a design agent is writing `docs/design/2026-09-28-classes-enemies-skins.md` covering 4–6 new classes (Ranger, Druid, Engineer, Paladin, Ninja, Necromancer…), 4–8 new enemies (Orc Raider, Werewolf, …), and milestone-earned skins from the alt textures. After Vlad reviews it, the order is: core rules and balance, then presentation (models, class select, Camp wardrobe). WP-F2 already uses the recolours for enemy variants.
- **Also in progress:**
  - **Core: classes, enemies, affixes, skins.** Follows docs/design/2026-09-28-classes-enemies-skins.md (final at 8a3a508/f512d8d): 7 new classes including the secret Monster Kid, the Paladin "Oathbound", 8 enemies, 10 affixes, skins (profile v2). It also adds 6 new pets (pebble_golem, frost_mote, wick, tinker_gear, grimoire, cauldron), for 12 in total.
  - (merged) **WP-E4:** models for the 6 new pets.
  - (merged) **WP-E1 additions:** a progressive camp (ruins → built, NPCs per unlocked class, roaming pets, milestone decor, reveal moments), an animated "camp life" (NPC schedules, walking, sparring, chatting, pets playing, ambient life), and a data-driven Pet Den and classes.
- **New biomes (approved):** Orc Warcamp, Deep Mines, Moonlit Woods, Sunscorched Ruins. Design: docs/design/2026-09-29-new-biomes.md. Vlad's decisions: tiers 3/3/4 with Moonlit in T3 and a new 6th final boss; the Short Road's 2nd biome drawn from T2 ∪ T3; the Full moon adds a rune chest; mini-bosses in home biomes; landing-only oasis; cosmetic elevation. The designer is updating the doc. Then: rules by a SEPARATE agent, branched after the core agent's enemies+affixes commit lands on main (both touch biomes.gd and board.gd); visuals after WP-F1 merges. After that, **elevation boards** (terraces/ramps/bridges).
- **Running (manual worktrees):** (merged: G1 enemy looks + affixes) and wp-b2-new-biomes (core rules for Mines/Warcamp/Moonlit/Ruins + Moon King + Sand Colossus + Short Road draw).
- (merged) WP-E2 minigames and Minigames 2.0 (11 games, no AUTO, cross-game balance). TODO for polish: the Camp Arcade booth shows only the original 4 games. Bubble Shooter, Plinko, Shell Game, Memory Match, Fishing, Lucky Wheel and High-Low Ladder (core rules + UIs + Arcade unlocks), reusing E2's framework.
- **Real-item Armory:** design in docs/design/2026-09-29-armory-items.md. Vlad's decisions: 3 slots, a 2nd trinket slot, +1-tier affinity, the Necromancer keeps its skull staff, and variants carry properties; the design is final. (merged) the armor binder + item mounts (ItemMounts, ArmorBinder, Character loadouts, HEAD_FIT). Core items implementation is queued after the classes/skins core work merges, because both touch the profile schema.
- **No AUTO in minigames:** being done by the Minigames 2.0 agent.
- **CI/CD release pipeline (running, worktree wp-ci-release):** GitHub Actions for CI (tests, sim smoke, screenshot matrix + artifacts), release (macOS, iOS/iPadOS, Android, Windows, Linux x64/arm64, Web → GitHub Release), store uploads disabled by default, a private encrypted asset bundle for the paid assets, conventional commits + dev changelog + an LLM user-facing changelog. The user authorized E2E: private GitHub repos vladzaharia/diceroll + vladzaharia/diceroll-assets (per-unit encrypted asset bundles, incremental), push + green CI, a private pre-release. Plus in-game auto-updates (signed PCK patches + binary updates on desktop, a store prompt on mobile).
- **Assets:** everything third-party lives in git-ignored `third_party/` (docs/ASSETS.md). A fresh worktree needs `THIRD_PARTY=/Users/vlad/Repos/diceroll/third_party tools/import_assets.sh`.
- **Next:**
  1. Merge E1 → E2 → E3.
  2. UX/UI designer review of the whole game, then fixes.
  3. A second meta-design pass with real sim data.
  4. Final exports and regression runs.
