# Diceroll Build Plan

> **For agentic workers:** you own exactly the files listed in your work package (WP). Do not edit files owned by another WP, `project.godot`, or `main.gd`/`main.tscn`, unless your WP says so. Work TDD for `core/`: write a failing test in `tests/`, make it pass, then commit. Verify visual work with the screenshot harness and **look at the PNG** (Read tool) before claiming done. Commit early and often on your branch, and end commit messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

**Goal:** A beautiful, fully playable 3D dice roguelite (spec: `docs/specs/2026-09-28-diceroll-design.md`) running on macOS, iOS and Web from one Godot 4.7.2 project.

**Architecture:** `core/` is pure deterministic rules (RefCounted, no Nodes) driven by commands that return event lists. `game/` + `ui/` render state and play events back as animation. `tools/shot.gd` boots named scenarios and saves screenshots for visual verification.

**Tech:** Godot 4.7.2 (`/opt/homebrew/bin/godot`), GDScript with static types, KayKit CC0 glTF assets, Kenney CC0 audio, OFL fonts.

## Commands

- Tests: `./tests/run.sh` (wraps the runner; fails on SCRIPT ERROR). Contract additions from WP-A2 are listed in docs/plans/balance.md and core/game_flow.gd.
- Import after adding assets: `godot --headless --path . --import`
- Screenshot (ALWAYS use this; runs in the background, never steals focus): `tools/shoot.sh <scenario> <abs.png> [WxH] [--wait=2 --frames=N ...]`. From another checkout: `GODOT_PROJECT=$PWD /Users/vlad/Repos/diceroll/tools/shoot.sh ...`. Never launch a windowed `godot` directly.
  (a real window with a renderer is required, so do NOT pass `--headless`. It quits by itself after the shot.)
- Landscape check: same with `--resolution 1280x800`.
- Balance sim: `godot --headless --path . -s tools/sim.gd -- --runs=300 --class=knight`

## Core API contract (WP-A2 implements; everyone else codes against it)

```gdscript
# core/game_flow.gd
class_name GameFlow extends RefCounted
enum Phase { BOARD_READY, BOARD_ROLLED, COMBAT, DRAFT, SHOP, FORGE, EVENT, PORTAL, GAME_OVER, VICTORY }
var run: RunState          # all persistent run data
var phase: Phase
var combat: CombatState    # null unless phase == COMBAT
var board_roll: Array[int] # values of the current board roll (BOARD_ROLLED)
var offer: Dictionary      # current modal payload for DRAFT/SHOP/FORGE/EVENT/PORTAL (see below)

static func new_run(class_id: String, seed: int) -> GameFlow   # class_id: knight|barbarian|mage|rogue
static func from_dict(d: Dictionary) -> GameFlow
func to_dict() -> Dictionary

# Every command validates phase; illegal calls return [{type:"error", msg}] and change nothing.
func roll_board() -> Array[Dictionary]
func board_reroll() -> Array[Dictionary]
func choose_move(die_idx: int) -> Array[Dictionary]
func combat_toggle(die_idx: int) -> Array[Dictionary]     # mark/unmark for reroll
func combat_reroll() -> Array[Dictionary]
func combat_set_target(enemy_idx: int) -> Array[Dictionary]
func combat_attack() -> Array[Dictionary]
func pick_draft(i: int) -> Array[Dictionary]
func shop_buy(i: int, die_idx := -1) -> Array[Dictionary] # die_idx for rune / face purchases
func shop_reroll() -> Array[Dictionary]
func shop_leave() -> Array[Dictionary]
func forge_apply(die_idx: int, face_idx: int, op: String, src_face := -1) -> Array[Dictionary] # op: raise|mirror|skip
func event_choose(i: int) -> Array[Dictionary]
func portal_pick(tile_idx: int) -> Array[Dictionary]
func rune_assign(die_idx: int) -> Array[Dictionary]       # when offer.kind == "rune_assign"
func landing_preview() -> Array[int]                       # tile idx per die in board_roll
```

`RunState` fields: `class_id, seed, rng:Rng, hp, max_hp, atk, block, gold, xp, level, dice:Array[Die], combat_rerolls:int, board_rerolls:int, banked_rerolls:int, act:int(1..3), lap:int(1..3), pos:int(0..23), board:Board, treasury:int, stats:Dictionary`.
`Die`: `faces: PackedInt32Array` (6 values 1..6), `rune: String` ("" or rune id), `edited: PackedByteArray` (face edited flags). `Board`: `tiles: Array[Dictionary]` of `{type:String, enemies:Array[String], elite:bool}` with 24 entries. Tile types: `start forge treasury portal enemy elite chest event campfire trap empty`.
`CombatState`: `enemies: Array[Dictionary]` `{id, name, hp, max_hp, block, atk_bonus, poison, frozen, intent:{kind, value}, boss:bool, phase:int}`, `dice_values: Array[int]`, `marked: Array[bool]`, `locked: Array[bool]`, `rerolls_left: int`, `target: int`, `turn: int`, `last_combo: Dictionary`.

`offer` payloads: DRAFT `{kind:"draft", options:[{id, label, desc, rune?}]}` · SHOP `{kind:"shop", items:[{id, label, desc, price, needs_die:bool, sold:bool}]}` · FORGE `{kind:"forge"}` · EVENT `{kind:"event", id, title, text, choices:[{label, desc, enabled:bool}]}` · PORTAL `{kind:"portal", tiles:[int]}` · RUNE_ASSIGN `{kind:"rune_assign", rune}` (phase DRAFT).

### Events (exact `type` strings; extra fields allowed)

| type | fields |
|---|---|
| `board_rolled` | values:Array[int], targets:Array[int] |
| `hero_moved` | path:Array[int] (tile indices visited, in order, excluding start), teleport:bool |
| `lap_completed` | lap:int, healed:int |
| `board_mutated` | changes:Array[{idx, type, enemies}] |
| `tile_triggered` | idx, type |
| `gold_changed` | amount (+/-), total, source:String |
| `hp_changed` | amount, total, source |
| `trap` | roll:int, dodged:bool, damage:int |
| `combat_started` | enemies (copy), boss:bool |
| `combat_turn_started` | turn, rerolls_left |
| `dice_rolled` | values:Array[int], indices:Array[int] (which dice changed), context:"board"|"combat" |
| `die_marked` | die_idx, marked:bool |
| `combo` | name:String, mult:float, group:Array[int], total:int |
| `rune_fired` | die_idx, rune, effect:String, value:int |
| `damage` | target:"hero"|int, amount, blocked:int, source:String, lethal:bool |
| `block_gained` | target, amount |
| `status` | target, status:"poison"|"frozen"|"curse"|"buff", value |
| `enemy_intent` | enemy_idx, intent |
| `enemy_died` | enemy_idx |
| `summon` | enemy (Dictionary), enemy_idx |
| `boss_phase` | enemy_idx, phase |
| `combat_won` | gold, xp |
| `level_up` | level |
| `offer_opened` | offer (Dictionary) |
| `offer_closed` | kind |
| `act_started` | act, biome:"crypt"|"hollow"|"throne" |
| `game_over` | victory:bool, stats |
| `error` | msg |

## Work packages

### Wave A (parallel, separate worktrees)

**WP-A1 Assets, harness, actors** (Opus). Owns `assets/**`, `tools/shot.gd`, `tools/scenarios.gd`, `tools/import_assets.sh`, `game/actors/**`, `game/audio/**`.
1. `tools/import_assets.sh` copies the needed KayKit glTF/glb/png sets from `~/Downloads` into `assets/kaykit/<pack>/…`. Include: Adventurers characters, Rig_Medium + Rig_Large animation GLBs, Mannequins, BoardGameBits tiles/dice/coins/tokens, the Dungeon set, the Halloween set, and weapons. The script must be idempotent. Run it and commit the assets (keep the total under ~60 MB, dropping unneeded packs).
2. Download fonts (Fredoka variable and Lilita One, OFL, from Google Fonts GitHub) into `assets/fonts/`. Download Kenney CC0 audio (Casino Audio, RPG Audio, Impact Sounds, Interface Sounds; https://kenney.nl/assets) into `assets/audio/sfx/`. Copy `~/Downloads/**/mixkit-*.mp3` music into `assets/audio/music/`. Keep license files.
3. `game/actors/character.gd` (`class_name Character extends Node3D`): `static func create(model_id: String) -> Character`. Model ids: knight, barbarian, mage, rogue, rogue_hooded, ranger, mannequin, mannequin_large. It loads the mesh GLB, builds an AnimationLibrary from the rig GLBs (bind by bone name), and adds an `AnimationPlayer` + API: `play(anim: String, blend := 0.15)`, `play_once(anim, then := "Idle_A")` returning when finished (await-able signal `anim_finished`), `set_tint(color: Color, strength: float)`, `attach(slot: "handslot.r"|"handslot.l"|"head", scene_path: String)`. Clip aliases: idle, walk, run, jump, attack (class-appropriate), cast, shoot, hit, death, cheer, spawn, skel_idle, skel_walk, skel_spawn.
4. `game/audio/audio_bus.gd` (autoload `Audio`): `play_sfx(id: String, pitch_var := 0.05)`, `play_music(id: String, fade := 1.0)`, and volume setters persisted in `user://settings.cfg`. Buses Master/Music/SFX are created in code. Ids map to files in one dictionary: dice_roll, dice_land, dice_select, step, coin, hit, crit, block, heal, levelup, click, open, error, win, lose, portal, trap, chest.
5. `tools/shot.gd` (autoload `Shot`): parses `--scenario=`, `--shot=`, `--wait=` (default 1.5) from `OS.get_cmdline_user_args()`. When `--scenario` is present it clears the main scene, instantiates the scenario from the registry in `tools/scenarios.gd` (`static func build(name: String) -> Node`), waits, saves `get_viewport().get_texture().get_image().save_png(path)`, prints `SHOT_SAVED <path>` and quits. It does nothing without args. `--frames=N` also saves N shots 0.25 s apart (suffix _1.._N) for animation review.
6. Register scenario `actors`: a lit test stage with all 8 models idling in a row plus one skeleton-tinted mannequin running `skel_idle`. Screenshot it and inspect. Characters must be textured (not grey or pink) and animated.
Done when the screenshot shows correctly textured, animated characters and `Audio` plays a test sfx without errors.

**WP-A2 Core rules** (Opus). Owns `core/**`, `tests/test_*.gd` (not the runner), `tools/sim.gd`. It implements the full contract above and the spec's §2–§9 numbers.
Order (TDD each): `rng.gd` (xorshift64*, `randi_range`, `randf`, `pick`, `shuffle`, serialisable; same seed gives the same sequence) → `die.gd` → `combo.gd` (every combo in the table incl. Wild, group selection, tie-break) → `content/` (heroes, enemies, bosses, runes, events, shop tables as const Dictionaries) → `board.gd` (generation rules, mutation, landing, portal range) → `combat.gd` (turn flow, runes, intents, poison/freeze/curse/block, boss phases/summon) → `run_state.gd` (serialise round-trip) → `game_flow.gd` (phase machine + pending queue: landing → fight → level-up draft(s) → next; Start: lap → shop; boss on lap-3 completion; act transition; victory) → `tools/sim.gd` (greedy bot: moves to best tile by heuristic, rerolls toward the best combo, buys dice and runes, picks drafts by a simple score). Tune the numbers in `content/` until the sim gives a 20–45% win rate for every class. Record the final sim table in `docs/plans/balance.md`.
Done when all tests pass, the sim runs 300 runs per class with no errors, and replaying a recorded command log from a seed reproduces an identical `to_dict()`.

### Wave B (parallel after Wave A merges)

**WP-B1 World & camera** (Opus). Owns `game/world/**`, `game/camera/**`, `game/fx/**`. Board view built from a `Board` (§10): per-act biome dressing, environment/lighting/post per act, tile props, enemy previews on tiles (using `Character`), tile highlight/ghost markers API, hero hop along a path, camera rig (overview/follow/combat framing, shake). FX library: damage numbers, coin burst, hit sparks, heal glow, level-up burst, portal swirl. Scenarios: `board_act1`, `board_act2`, `board_act3`, `combat_stage_act1` (hero vs 3 enemies in combat framing), `boss_act3`.
**WP-B2 Dice tray** (Opus). Owns `game/dice/**`. SubViewport tray rendered into a `Control` (`DiceTray extends Control`): `set_dice(dice: Array[Die])`, `roll(values: Array[int], indices: Array[int]) -> signal settled`, mark/lock visuals, tap → `die_pressed(idx)` signal, combo highlight of group, rune tint + icon, gold rim on edited faces, Wild ★ face. Tumble must end on the given value with no visible swap. Scenario `dice_tray` (6 dice, mixed runes, mid-roll frames via `--frames`).
**WP-B3 UI** (Opus). Owns `ui/**`. Theme (fonts, panels, buttons, colours), Title (New Run / Continue / Settings), Class Select (3D character preview via `Character`), Board HUD (HP, gold, XP bar, act/lap, dice pool strip, Roll/Reroll buttons), Combat HUD (enemy HP bars and intent icons over units are world-anchored in B1; this owns the bottom panel with Reroll/Attack, combo cheat-sheet popover, reroll pips), modals (Draft, Shop, Forge with face picker, Event, Rune assign, Portal hint), Pause/Settings, Victory/Defeat summary. Drawn icon set: rune glyphs and intent icons as SVG (hand-authored) or FontAwesome-free-style shapes you draw. Each screen has a scenario (`ui_title`, `ui_class`, `ui_board_hud`, `ui_combat_hud`, `ui_draft`, `ui_shop`, `ui_forge`, `ui_event`, `ui_summary`) using a real `GameFlow` seeded state. Check portrait 720×1280 and landscape 1280×800.

### Wave C

**WP-C1 Integration** (Opus). Owns `game/game_controller.gd`, `main.gd`, `main.tscn`, save/continue. Wires GameFlow commands ↔ UI signals ↔ event playback (a sequential event player with awaits, sped up by game speed). Adds combat presentation: enemies rise, attack/hit/death animations, dice → combo splash → damage, and boss intro. Scenario `play_auto` runs the sim bot through the real presentation at 4× speed and screenshots every N seconds.

### Wave D — Polish & QA (loop until good)

- Visual review (Opus, read-only): screenshot every scenario at both resolutions and critique against §10. Output a ranked fix list, which then goes to fix agents.
- Code review (`superpowers:code-reviewer`) per wave.
- Playtest: `play_auto` across 20 seeds with no errors in the log, and the run completes.

### Wave E — Ship

macOS export (`build/Diceroll.app`), iOS Xcode project + Simulator run with a screenshot via `xcrun simctl io booted screenshot`, Web export smoke test in Playwright. App icon generated from a rendered die + hero.
