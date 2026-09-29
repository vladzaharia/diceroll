# Diceroll content model audit, and a design for data-only content packs

Date: 2026-09-29. Repo: `/home/user/diceroll` @ `4e78bb6` (read-only; nothing in the repo was modified).
Engine: Godot 4.7.2 (verified locally, `godot --version` = `4.7.2.stable.official.ed1daf0bf`).
Companion docs: `docs/design/2026-09-29-content-streaming.md` (asset packs, loader, manifest schema 2),
`docs/design/2026-09-29-armory-items.md`, `docs/design/2026-09-29-new-biomes.md`,
`docs/design/2026-09-28-classes-enemies-skins.md`.

Goal under review: "maps, classes, monsters, heroes, tools, weapons… easily updatable; content packs can
contain new weapons without core updates; small packs, delta-updatable, new packs added later."

---

## 0. Executive summary

**Where we are.** Content *numbers and names* are already clean data: every `const` dictionary in
`core/content/*.gd` is JSON-compatible. I dumped all of them through Godot: 0 non-JSON values, 77.5 KB
compact JSON, 22 KB gzipped, 3.3 ms to parse (appendix B). Content *behaviour* is not data. The rules
layer dispatches on **content ids**, not on the rule ids the data declares:

- **Armory items**: `ItemDefs.ITEMS[*].effect.rule` (51 rule ids) is **display-only**. Nothing in code
  reads `.rule`. `core/item_logic.gd` branches on **51 item ids** (`has(run, "sword")`, …) and
  **51 variant ids** (`sec(run, "sword_rapier")`, …). The same holds in `core/bot.gd` (29 item
  refs in the AUTO combat model) and `core/meta/meta_run.gd:57-73` (Compass, Lantern, Coin Purse).
  So **a pack cannot add a weapon today, even one that reuses an existing rule with different numbers.**
- **Passives** (32), **pets** (fire, perk, L5 and L10 per id), **potions** (4, with a silent
  "heal" fallback for unknown ids), **runes** (`trigger` is declared but combat matches on the rune id),
  **events** (7), **non-trait affixes** (5), **older biome twists** (Glade, Crypt, Hollow, Throne) and
  **the Moon King** are all hard-wired by id.
- **Generic already**: enemy intents and traits, enemy modes/phases/forms, biome mix/pools/candidates, the
  new-biome twist ids (`ore`, `drums`, `moon`, `heat`), class **mechanics** (dispatch on
  `HeroDefs.mechanic`, not on the class id), pet **charge_on**, dice kinds, milestone/feat/skin
  conditions, and minigame **signatures**.
- **Presentation** is mostly data-shaped tables written in code (`EnemyRoster.LOOKS`, `ItemMounts.*`,
  `Character.MODELS`, `Biome.LOOKS`, palettes, taglines, music). Biome **dressing** and **pet bodies** are
  procedural code, and so are **minigames** (rules and props).
- **Saves are destructive toward unknown ids.** `Profile.from_dict` drops every id it doesn't know
  (`core/meta/profile.gd:497-607`, `grant()` at `:253`, `_load_armory()` at `:869`). If a pack is missing
  at load time, the next save **permanently erases** that pack's unlocks, items and skins.
  This must be fixed before any pack ships.
- **No localization system exists** (no `tr()`, no TranslationServer, no locale settings). English strings
  live in `core/content/*`, `core/game_flow.gd` and `ui/**`.

**Recommendation.**

1. **Format: JSON plus JSON Schema.** I verified on 4.7.2 that the alternatives execute code. `ConfigFile.load()`
   and `str_to_var()` instantiate objects and scripts, and `.tres` runs embedded GDScript or scripts from
   `user://` on `load()` (appendix A).
2. **Registry: a core `ContentDB`** that merges base and pack JSON deterministically. Official ids stay bare and
   are globally unique, enforced by an append-only id ledger. Any non-official namespace uses `ns:id`.
   Packs can `add`, `patch` (schema-gated merge patch) and edit lists (`$add`/`$remove`). Order is by
   layer, then order, then id, never by download order. The DB gets a content fingerprint.
3. **Refactor the rules to dispatch on declared rule ids with parameters.** Items go by rule and secondary
   id, passives and runes by effect primitives, potions by effect lists, pets by fire/perk ids, twists by
   parameterized ids, and events by event kinds. Then a new weapon is data whenever it uses existing
   primitives.
4. **`content_api` capabilities.** Core publishes `{kind: {primitive: version}}`. A pack's `requires`
   is computed by CI (`effect:bleed@1`, `intent:drain@1`, `look.extra:crown@1`). The feed and the client hide
   packs the binary can't run.
5. **Presentation moves into per-pack `looks` JSON.** It references asset paths inside asset packs and a
   vocabulary of presentation primitives. Biome dressing becomes declarative, or a pack reuses an existing
   look.
6. **Packs split by domain and release, append-only.** Definition packs are 1–15 KB each (`weapons-base`,
   `weapons-2026-10`, `foes-base`, `biome-<id>`, `balance-<date>`…) and ride on the streaming doc's asset
   packs, which are grouped by source unit. New art lands in *new* asset units, so existing packs never
   change hash.
7. **Effort:** the minimum path to "ship a weapons pack with no core update" is about 4–5 agent-weeks.
   Everything (incl. declarative dressing, looks, i18n groundwork) is about 9–13 agent-weeks. About 70% of it
   needs no assets: core, tests and sim are asset-free.

---

## 1. Content inventory: definition, schema, id hard-wiring, classification

Legend for the classification (today → after the refactor in §8f):

- **A**: pure data. A new entry works if the dict is loaded from a pack.
- **B**: data, but presentation (or meta plumbing) is keyed by id in code and must move to data.
- **C**: needs new rule primitives, or is hard-wired by id in rules.

### 1.1 Summary table

| Type | Defined at | Rules dispatch | Today | After refactor |
|---|---|---|---|---|
| Heroes / classes | `core/content/heroes.gd:11` `DATA`, `:42` `IDS` | by **mechanic id** (`core/class_logic.gd:157-489`) | **B** (new class with existing mechanic); **C** for a new mechanic | B→A (existing mechanic); C (new mechanic) |
| Enemies (regular) | `core/content/enemies.gd:22` `ENEMIES` | by **intent kind / trait** (`core/combat.gd:212-240, 938-1020`) | **B** | A (+looks) |
| Mini-bosses | `enemies.gd:139` `MINIBOSSES` | same as enemies | **B** (+ `UnlockDefs.all_ids` hard list `unlocks.gd:95`) | A |
| Bosses | `enemies.gd:76` `BOSSES` | phases/traits generic; **Moon King by id** (`combat.gd:1127-1150`) | **B**; **C** for moon-meter-like mechanics | A; C (new boss mechanic) |
| Biomes / maps | `core/content/biomes.gd:24` `DEFS`, `:20` `TIERS` | new twists by twist id; **old twists by biome id** | **B/C** (dressing is code) | A for rules; B/C for dressing |
| Board layouts / tiles | `core/board.gd:16-26` `LAYOUTS`/`MUTATE`; tile types in `game_flow.gd:452-560` | tile **type** is a closed vocabulary | layouts A; new tile types **C** | same |
| Weapons, off-hands, armor, trinkets, back | `core/content/items.gd:106` `ITEMS`, `:336` `VARIANTS`, `:463` `FEATS`, `:77` `KITS` | **by item id and variant id** (`core/item_logic.gd`) | **C** | A (existing rules) / C (new rule) |
| Gear (legacy v2) | `core/content/gear.gd` | migration only (`profile.gd:933`), some UI | frozen | freeze / delete |
| "Tools" | *no such type*; see §1.8 | — | — | — |
| Pets | `core/content/pets.gd:36` `DEFS` | `charge_on` generic; **fire/perk/L5/L10 by pet id** | **C** | A (existing fire/perk primitives) |
| Potions | `core/content/potions.gd:11` | **by id** (`game_flow.gd:1675-1700`, unknown → heal) | **C** | A |
| Dice kinds | `core/content/dice_kinds.gd:9` | faces/rarity/price/cap generic | **A** (bot score, palette are B) | A |
| Runes | `core/runes.gd:7` | **by rune id** (`combat.gd:408-432, 616-660`) | **C** | A (trigger + effect) |
| Affixes | `core/content/affixes.gd:17` | trait-affixes generic; 5 others **by id** | **B/C** | A |
| Passives | `core/content/passives.gd:8` | **by id** (32 `has_passive("…")` sites) | **C** | A (rule + params) |
| Events | `core/content/events.gd:5` | **by id** (`game_flow.gd:1243-1390`) | **C** | A (event kinds) |
| Skins | `core/content/skins.gd:17-60` | slots/conds generic; looks per class | **A/B** | A |
| Minigames | defs `core/content/minigames.gd:33`; rules `core/minigames/<id>.gd` (factory `core/minigames/minigames.gd:17`) | **code per game** | **C always** | C (numbers/rewards are data) |
| Unlocks / milestones / feats | `core/content/unlocks.gd:45-256`, `items.gd:463` | conditions generic; some **counters per id** | **B** | A |
| Shop | `core/content/shop.gd:6` | shop kinds closed (`game_flow.gd:1045-1100`) | weights/prices A; kinds C | same |
| Economy / balance | `core/content/economy.gd`, `balance.gd` | constants (`const`, not patchable at runtime) | **B** | A (DB-backed static vars) |
| Combos | `core/combo.gd:9` `TABLE` | detection code | mults A, combos C | same |
| Ascension | `unlocks.gd:299-331` | keys closed vocabulary | numbers A, keys C | same |

### 1.2 Heroes / classes

**Schema** (`heroes.gd:11-39`):

```
{name, model, hp, atk, runes:[rune|""], kinds:[kind], tags:[tag], board_rerolls, combat_rerolls,
 mechanic: ""|oath|aim|shadow_step|overgrowth|bone_harvest|turret|boo,
 style: melee_1h|melee_2h|ranged|magic|dual|unarmed, secret?, turret_rune?}
```

Other class tables:

- `IDS` (`:42`) is the **unlock order**. It drives the Sigil "next two" rule (`unlocks.gd:33-41`) and the class shelf.
- `MECHANIC_NAMES` (`:45`).

**Rules dispatch.** The rules key on the mechanic (`ClassLogic.mech(run)`, `class_logic.gd:110`; every hook
does `match mech(run)`). That is good: a new class that reuses a mechanic is mostly data. But:

- **Mechanic numbers are global, not per class.** `class_logic.gd:55-81` holds PALADIN_*, RANGER_*, NINJA_*,
  DRUID_*, TURRET_T, BONE_*, BOO_*, `PALADIN_SHOP_KINDS`, `TURRET_RUNES`. A second "oath" class would share
  the Paladin's numbers. They need to move into `mechanic_params` on the class.
- The turret is special-cased at creation: `run_state.gd:94-96` (`turret_rune`).

**Hard-wired by class id:**

*Core rules:*

- `profile.gd:425` `mage_wins` counter. It is used by the milestone `archmage` (`unlocks.gd:188`).
- `unlocks.gd:24` `SIGIL_PRICE_BY_ID.classes`, and `:46` `STARTER.classes = ["knight"]`.
- `items.gd:77-99` `KITS` (every class needs a kit: `tests/test_armory.gd:111`), `:100` `APPEARANCE_DEFAULT` (paladin), `:102` `LOCKED_ARMOR`
  (monster_kid), `:710` the Arcane Staff counts as kit for the necromancer too.
- `skins.gd:32-59` `LOOKS` per class. `skins.gd:86` `cond_text` uses the class name.
- `"knight"` fallbacks: `run_state.gd:5`, `game_flow.gd:52-56`, `meta_run.gd:19`, `profile.gd:100,532`, `camp.gd:494`.
  These are benign.

*Presentation:*

- `game/actors/character.gd:35-73` `MODELS`, `:75` `PART_MAP`, `:136` `KITS`, `:161` `SKIN_TEX`.
- `game/actors/hero_look.gd:25,38,48,281`: necromancer shade, monster_kid.
- `game/actors/armor_binder.gd:67` (druid donor) and `game/enemies/skin_rules.gd:44-66`.
- `ui/theme/palette.gd:80-83` `CLASS`, `ui/widgets/class_info.gd:6-18` `TAGLINES` + `:20` `MECH_COLOR` + `:41-60` rule text
  per mechanic.
- `ui/icons/ui_icons.gd:118`: only 4 classes are mapped, the rest fall back to "sword".
- `game/camp/camp_scene.gd:659` (4 class colours).
- `ui/screens/class_select.gd:16,95,132`.

**Classification:** B for a class with an existing mechanic; C for a new mechanic. A mechanic is rule code
plus presentation code: `game/classes/class_beats.gd:136`, `ui/widgets/class_badge.gd`, `class_detail.gd`.

### 1.3 Enemies, mini-bosses, bosses

**Schema** (`enemies.gd:22-157`):

```
ENEMIES[id] = {name, hp, gold, xp, mode: random|cycle, pattern:[{kind, value}], traits?:[…],
               forms?:[…], phases?:[[…],[…]] (transformers), summon?: enemy id}
BOSSES[id]  = {name, hp, gold, xp, phases:[[…],[…]], traits?:[[p1],[p2]], summon?, forms?}
MINIBOSSES  = like ENEMIES (single phase, scaled)
```

Globals:

- `POOLS` (`:171`) and `COUNTS` (`:179`) are the legacy band pools.
- `SUMMON_ID` (`:168`), and `ACT_*`/`FINAL_BOSS` (`:161-167`) are legacy defaults.
- Numbers: `BURY_BLOCK`, `MOON_*`, `FRENZY_*`, `ATK_BONUS_CAP`.

Lookups go through `EnemyDefs.def(id)` (`:226`). It **crashes** on an unknown id (`ENEMIES[id]`).

**Generic rules (good).** Intents are dispatched by kind (`combat.gd:938-1020`, 15 kinds), traits by
trait id (`combat.gd:190`, `has_trait`), transform by `phases` + `forms`, and summon by the `summon` field
(`combat.gd:999`).

**Hard-wired by enemy id:**

- **Moon King**:
  - `combat.gd:1127-1150` (`moon_king()`, moon meter start, and the Moonfang + route bonus: `route.has("hollow") and route.has("moonlit")` + `"mini_moonfang"`)
  - `game/enemies/boss_beats.gd:24,35` (Moon King, Sand Colossus)
  - `game/flow/twist_beats.gd:198`
- `items.gd:71` `SKELETONS` list → `skeleton_kills` counter (`item_logic.gd:745`), feat `skeletons_300`,
  milestone `bone_collector`.
- `affixes.gd:17-36` `exclude` lists and `:41-54` biome affix lists reference ids. That is data, fine.
- `unlocks.gd:94-95` `all_ids("bosses"/"minibosses")` are **hand-written lists**. A pack boss or miniboss
  can't be granted (`profile.gd:258` rejects ids not in `all_ids`), so `_allowed()` (`run_state.gd:155`) filters
  it out of the route candidates.
- `board.gd` elite fallback `"brute"` (in `roll_enemies`); `game_flow.gd:1936` debug default.
- Presentation:
  - `game/enemies/roster.gd:48` `LOOKS` (required for every id: `tests/test_enemy_looks.gd:13`) and `:395` `BIOME_LOOKS`
  - `game/enemies/encounter_cards.gd:12` `NEW_ENEMIES`, `:120` `RULES`
  - `game/world/enemy_looks.gd:799,1071`, `game/actors/character.gd` (werewolf models), `game/enemies/skin_rules.gd`

**Classification:** B (regular enemies, minibosses, plain bosses). C for bosses with a bespoke mechanic.
The fix is a boss-level `mechanic: "moon_meter"` primitive plus params.

### 1.4 Biomes, maps, board layouts and tiles

**Schema** (`biomes.gd:7-18, 24-120`):

```
{name, tier, desc, mix:{tile:Δ}, trap_tile?, pools:[[early],[late]], elite, minibosses:[], bosses:[],
 short_bosses?, short_boss_hp?, mutate_elites?, twist?: ore|drums|moon|heat, refill?:{tile:n}, look?}
```

`TIERS` (`:20`) is a **separate list**. A biome's `tier` field is duplicated there. Twist numbers are **global
static vars** (`:125-144`: `ORE_GOLD`, `DRUM_*`, `HEAT_PCT`, `MOON_*`), not per biome.

**Hard-wired by biome id (rules):**

- **Glade**: campfire 45% at `game_flow.gd:488` (and the bot copy at `bot.gd:2326`).
- **Crypt**: dodge gold at `game_flow.gd:512-514` (bot copy `bot.gd:2333`).
- **Throne**: elite boss-passive chance at `game_flow.gd:690`.
- **Hollow**: event heal plus the `hollow_events` counter at `game_flow.gd:1376-1381`.
- Profile counters `frost_visits`, `throne_wins`, `hollow_events` (`profile.gd:422-428`), used by milestones
  `frostbitten`, `cold_snap`, `throne_breaker`, `trick_or_treat` (`unlocks.gd`).
- `combat.gd:1131` (hollow + moonlit route bonus).
- `unlocks.gd:25` Sigil prices, `:47` starter biomes, `:324` `ASC_MINIBOSS_TRAIT`, which is keyed by 6 of the 10 biomes and
  appears unused by the current A4 path (`AffixDefs.roll_miniboss`).
- `affixes.gd:41-55` `BIOME` and `GILDED_BY_BIOME`, `enemies.gd:167` `ACT_BIOME`.

**Presentation by biome id:**

- `game/world/biome.gd:27` `IDS` (and `seed_of(id) = IDS.find(id)+1` at `:97-99`: index-based, so a pack biome gets
  seed 0), `:38` `LOOKS`, `:129` `match id` (crypt/hollow/throne dressing).
- `game/world/biome_blocks.gd:22` `LOOKS`, `:139` `TERRAIN`, `:184,203,246+` `match id`.
- `game/world/dressing/<biome>.gd`: **procedural code**, 172–514 lines each.
- `game/audio/audio_bus.gd:82-98` `MUSIC`, `ui/theme/palette.gd:119` `BIOME`, `ui/icons/biome_<id>.svg`.
- `game/world/tile_style.gd:35` `BASE`, `game/enemies/roster.gd:395` `BIOME_LOOKS`, `game/camp/camp_scene.gd`.

**Board:**

- `board.gd:16-26` `LAYOUTS` (ring sizes 24/28/32) and `MUTATE`, and `CORNER_TYPES`. `layout_for`
  (`:67-98`) applies biome `mix`, `trap_tile`, `TWIST_TILES`.
- **Tile types are a closed vocabulary** handled in `GameFlow._trigger_tile` (`game_flow.gd:452-560`), with
  presentation in `game/world/tile_style.gd:9-160`: start, forge, treasury, portal, enemy, elite, miniboss,
  chest(+moon), event, campfire, trap, empty, ice, lava, ore, drum, oasis, minigame.

**Classification:**

- Rules are **B** once the four old twists become parameterized twist ids and `TIERS` is derived from `tier`.
- A "new map" still needs **dressing**, which is code today. It is **C** until a declarative dressing format exists, or a
  pack reuses an existing `look` (dressing) id.
- New tile *behaviour* is C.

### 1.5 Armory items (weapons, off-hands, head, body, trinkets, back) and variants

**Schema** (`items.gd:15-21, 106-321, 336-459`):

```
ITEMS[id] = {name, slot: weapon|offhand|head|body|trinket|back, hands?, mount?: hand|belt|back, style?,
             model, affinity:[class], std: "x1.2"|"block2"|"", effect:{rule, name, desc (with {key}/{key%}),
             n:{key:[I,II,III]}, scale:[keys]}, cosmetic?, locks_head?, class_only?}
VARIANTS[vid] = {item, name, model, sec, sec_name, desc, unlock:{mastery}|{feat}|{class, or_mastery}, hands?, n:{…}}
FEATS[id] = {desc, cond:{counter,min}|{boss,with}|{win_with,asc}|{class_win,asc}|{kills,min}}
```

Plus `KITS`, `PRICES` (`:68`), `BACK_FEATS` (`:481`), `STARTER_ITEMS`, and the rank/craft/price constants (`:31-73`).

**Rules: hard-wired by id (the main blocker).**

`ItemLogic` hooks, all keyed by item or variant id:

- `on_combat_start` `:214`, `turn_start` `:245`, `after_roll` `:301`, `on_reroll` `:329`
- `attack_mods` `:383`, `after_hit` `:576`, `on_kill` `:737`
- `incoming` `:779`, `after_enemy_hit` `:788`
- the board/economy getters `:813-929`, `on_biome` `:893`, `on_fight_won` `:922`

The count: **51 distinct item ids** via `has/n/ni/use_left` and **51 variant ids** via `sec()`.
`effect.rule` is never read (only `.effect.n/.desc/.scale`).

Other id-keyed code:

- `ItemDefs.style` special-cases `hammer_mallet` (`items.gd:546-549`), and `rule_text` special-cases `spear` (`:629`).
- `price` special-cases `dino_suit` and `arcane_staff`/necromancer (`:705,710`). `std_scale` is keyed by
  *param names* (`factor`, `crush`, `x`, `mult`, `pct`; `:599-606`). That is fine, but implicit.
- `MetaRun.armory_stats` (`meta_run.gd:57-73`): Compass reroll, Lantern hazard, Coin Purse gold, by id.
  The v2→v3 migration (`meta_run.gd:124-127`, `profile.gd:933-980`) is legacy and can stay as code.
- `core/bot.gd:1280-1330` AUTO combat model: 29 `ItemLogic.n/sec(run, "<id>")`. `bot_meta.gd:283-295` prefs
  `TRINKET_PREF`, `BEST`.
- Duplicate secondary id: `"light"` is used by both `dagger_leaf` (`items.gd:389`) and `shield_plank` (`:431`), with
  different semantics.

**Presentation:**

- `game/actors/item_mounts.gd:31` `SOCKETS`, `:44` `BASES` (per base item: slot, hands, style, clip), `:83`
  `MOUNTS` (per model: scene, socket, pos/rot/axes/scale, base), `:199` `ITEMS`, `:304` `HEADS`, `:320` `BODIES`, `:338`
  `BACKS`.
- `game/actors/armor_binder.gd` (donor parts), `game/actors/character.gd:210` `ATTACKS`.

These tables are already data-shaped, and tests cross-check them (`tests/test_armory.gd:88`).

**Classification: C today.** After §8f step 4a (dispatch by `effect.rule` + `sec`) a new weapon that uses
existing rules is **A (rules) + B (looks → JSON)**.

### 1.6 Pets

**Schema** (`pets.gd:36-86`):

```
{name, role, charge_on, size, model, fires, perk, l5, l10}
```

`fires`, `perk`, `l5` and `l10` are **text only**. The per-level numbers are functions (`pets.gd:121-178`).

**Rules:**

- `charge_on` is generic: `pet_logic.gd:314-344`, with 12 triggers.
- **Firing** matches the pet id (`pet_logic.gd:81-240`). Crystal Wisp has a special turn-start path
  (`:44-78`); Coin Mimic charges on board doubles (`:37-41`).
- **Perks** are keyed by `has_pet("…")` at `game_flow.gd:152,473,476,490,498,519,1002,1061,1605` and
  `combat.gd:676,803,843`. `pet_logic.gd:278,285` also checks ids.
- Grimoire stores **rune indices** (`Runes.IDS.find`) in `pet_state` (`pet_logic.gd:213,297,306`). That is
  index-based serialization, and it breaks if runes are added or reordered.

**Presentation:** per-pet builders are code (`game/pets/pet_view.gd:141`, `pet_view_ext.gd:55,510,571`), plus
`LOOKS` (`pet_view.gd:27`) and `camp_info.gd:13-30`.

**Bot:** `bot_meta.gd:274-275` preference list.

**Classification: C.** After the refactor, a pet is A when `fire`, `perk`, `l5` and `l10` are rule ids with params
from existing primitives. The body is B if built from a declarative "props + eyes + glow" look, else C.

### 1.7 Potions, dice kinds, runes, affixes, passives, events, skins, minigames

- **Potions**:
  - Schema (`potions.gd:11-20`): `{name, combat_only, icon, desc}`. Numbers are file constants.
  - Rules (`game_flow.gd:1675-1700`) `match type` with a **`_:` default that heals**. An unknown pack potion would silently act as healing.
  - Presentation: `ui/hud/meta_hud.gd:438` `POTION_COLORS`.
  - **C → A** with `effects:[{op:"heal_pct", v:0.3}]`.
- **Dice kinds**:
  - Schema (`dice_kinds.gd:9-33`): `{name, faces[6], rarity, price, cap, class_only?, desc}`. Generic, **A**.
  - Id lists: `IDS` (`:35`, the draw order), `bot.gd:14` `KIND_SCORE`, `class_logic.gd:59` `PALADIN_SHOP_KINDS`,
    `unlocks.gd:282` `STARTER_KINDS`, `unlocks.gd:60-74` workshop packs, `ui/theme/palette.gd:64` `KIND`.
- **Runes**:
  - Schema (`runes.gd:7-20`): `{name, color, trigger: COMBO|ALWAYS|SIX|ONE|KEPT|REROLLED|MOVE, rarity, desc}`.
  - Combat ignores `trigger`: `combat.gd:408-432` and `:616-660` match the rune id. `Balance.rune_cap`
    (`balance.gd:59`) special-cases `wild`. `NO_DOUBLE_TRIGGER` (`balance.gd:~132`), `ClassLogic.TURRET_RUNES`,
    `item_logic.gd:197` (`heavy`), `bot.gd:8,386,403`.
  - **C → A** (trigger + effect primitive + params).
- **Affixes**:
  - Schema (`affixes.gd:17-36`): `{name, trait?, desc, exclude:[enemy ids], group?}`, and `BIOME` weights by biome id.
  - Trait-affixes are generic via `trait`.
  - `regenerating`, `vampiric`, `hexing`, `frostbound` and `gilded` are hard-wired: `AffixDefs.apply` `:163-181` (`match id`),
    `reward_mult` `:183`, and `combat.gd:230` (vampiric) plus the hexing/frostbound/regen hooks.
  - Presentation: `ui/icons/affix_<id>.svg`, `game/enemies/affix_looks.gd`, `affix_tips.gd`.
  - **B/C**.
- **Passives**:
  - Schema (`passives.gd:8-80`): `{name, rarity, icon, desc}`. **All 32 are hard-wired** by `has_passive("<id>")` across
    `combat.gd`, `game_flow.gd`, `run_state.gd`. Numbers are in `Balance.PASSIVE_*` (`balance.gd:~111-135`).
  - Bot: `bot.gd:19,405,413`.
  - **C**.
- **Events**:
  - Schema (`events.gd:5-21`): `{title, text}` plus `BLESSINGS`.
  - Picked by `rng.pick(EventDefs.IDS)` (`game_flow.gd:1244`). Choices and outcomes are built per id (`:1247-1290`) and resolved per id (`:1311-1382`).
  - Presentation: `ui/modals/event_modal.gd:8-15` `ART`/`CHOICE_ICONS`.
  - **C**.
- **Skins**:
  - `SLOTS` (5 fixed), `CONDS` (generic vocabulary: `class_win`, `class_asc`, `class_bosses`, `or_class_asc`, `prestige`), `LOOKS[class][slot] = {texture, mesh?, helmet?, overlay?}`.
  - `cond_text` is per slot.
  - Presentation: `character.gd:161` `SKIN_TEX`, `hero_look.gd`, `wardrobe_modal.gd:209` (`PRESTIGE_NAMES`).
  - **A/B**: new skins for a new class are data; new overlay kinds need presentation code.
- **Minigames**:
  - Defs (`minigames.gd:33-67`): `{name, skill, signature, desc, signature_desc}` + `MEDIAN`, `CALIBRATION`, `SKILL_BAND_BY_ID`, `SHORT_BY_DESIGN`.
  - Rules are one GDScript class per game (`core/minigames/*.gd`), wired by the factory `match` (`core/minigames/minigames.gd:17-30`).
    Props: `game/minigames/props/*_prop.gd`. UI boards: `ui/minigames/*_board.gd`.
  - **C, always.** A new minigame is code by definition, so it ships in a binary update.
  - Packs can tune numbers and rewards, and later add *variants* of an existing game if that game exposes parameters (board size, shots).
- **Unlocks / milestones / feats**:
  - `MILESTONES` (`unlocks.gd:144-256`): `{id, run, desc, cond, unlocks:[[kind, id]], hidden?, hint?}`.
  - Condition vocabulary: `{stat,min}`, `{class_wins,min}`, `{boss_kills,min}`, `{any}`, `{all}` (`profile.gd:463`). `stat` is one of
    `Profile.COUNTERS` (`profile.gd:42-45`, 29 counters, several **id-specific**: `frost_visits`, `throne_wins`, `mage_wins`,
    `hollow_events`, `skeleton_kills`).
  - `STARTER`, workshop `PACKS`, `UPGRADES`, `ASCENSION`, `SIGIL_PRICE(_BY_ID)` are data.
  - `all_ids()` (`:86-105`) hard-codes the boss and miniboss lists and the features list.
  - **B**.
- **Shop**:
  - `ShopDefs.ITEMS` (`shop.gd:6-12`) `{label, desc, needs_die, weight}` over the closed kinds die, rune, potion, face_raise,
    passive, combat_reroll (`game_flow.gd:1009-1100`).
  - Weights and prices are A. New shop kinds are C.
- **Economy / balance**:
  - Pure numbers (`economy.gd`, `balance.gd`, `unlocks.gd:312-324`, `gear.gd`, and per-type constants).
  - They are GDScript `const`, so they can't be patched at runtime. Many are already `static var` for the sim
    (`balance.gd:163-172`, `items.gd:38-52`, `biomes.gd:125-136`, `enemies.gd:128-131`, `class_logic.gd:55-81`).
  - **B → A** by making all of them DB-backed static vars.

### 1.8 What "tools" means here

There is **no "tool" content type**. The closest meanings:

1. **Trinkets.** These are utility items in the Armory (Compass, Lantern, Coin Purse, Trader's Map, Healer's Flask,
   Skeleton Key, Loaded Die, Tankard; `items.gd:279-306`) and the natural "tools" category.
2. **Consumables.** Potions (§1.7) and the shop's Face Raise and combat reroll.
3. **Legacy `GearDefs`** (helm/blade/boots/charm; `gear.gd`). It is v2, migrated away in profile v3 and still read by some Camp
   UI (`ui/camp/armory_modal.gd:17-50`, `camp_state.gd:78`, `camp_stations.gd:177`).
4. **The Engineer's Wrench / Forge.**
5. **KayKit `tools`, `tools_x` and `tools_extra` asset units.** These are props (`Props.TOOLS`, dressing `TX`), not content.

**In the taxonomy (§8e), "tools" = trinkets + consumables.**

---

## 2. Rule-primitive vocabulary available today

"Generic" means a data entry can reference it with parameters. "One-off" means it exists for exactly one
content id, with no parameters beyond a fixed id.

| Vocabulary | Values | Where | Generic? |
|---|---|---|---|
| Enemy intent kinds | attack, block, buff, curse, summon, chaos, aim, heal, drain, burn, chill, scorch, rally, bury, (moonfall: produced internally) | `combat.gd:212-240, 938-1020` | **Generic** (`value` param; summon → `summon` field) |
| Enemy traits | armor, thorns, ward, pierce, frenzy, ward_allies | `combat.gd:190`, `enemies.gd:10-15` | Generic, but numbers are global (`Balance.ENEMY_THORNS`, `EnemyDefs.FRENZY_*`) |
| Enemy behaviour | mode random/cycle; transform (`phases` + `forms`, 50% or Half-moon 65%); boss 2 phases with per-phase traits; summon cap (`Balance.MAX_SUMMONED_ALIVE`) | `enemies.gd:193-230` | Generic |
| Boss mechanics | moon meter (Moon King) | `combat.gd:1098-1180` | **One-off by id** |
| Biome twists (new) | ore, drums, moon, heat (+ `TWIST_TILES`) | `game_flow.gd:1416-1530`, `combat.gd:1113` | Generic by twist id, but **params are global** (`biomes.gd:125-144`) |
| Biome twists (old) | Glade campfire+, Crypt dodge gold, Hollow event heal, Throne elite boss-passive; Frost = `trap_tile: ice`, Magma = `mix.lava` | `game_flow.gd:488,512,690,1376` | **One-off by biome id** (ice/lava are generic tile types) |
| Tile types | start, forge, treasury, portal, enemy, elite, miniboss, chest (moon flag), event, campfire, trap, empty, ice, lava, ore, drum, oasis, minigame | `game_flow.gd:452-560`, `board.gd:1-12` | Closed vocabulary; generic by type |
| Class mechanics | oath, aim, shadow_step, overgrowth, bone_harvest, turret, boo | `class_logic.gd` | Generic by mechanic id; **params global** |
| Rune triggers | COMBO, ALWAYS, SIX, ONE, KEPT, REROLLED, MOVE | `runes.gd:3-5` | **Declared, not used by rules** |
| Rune effects | blade, guard, venom, gilded, heavy, ember, vampire, lucky, frost, thunder, echo, wild | `combat.gd:408-660` | **One-off by rune id** |
| Item effect rules (51) | twin_edge, great_arc, cleave, rampage, crush, first_strike, reap, quick_hands, flow, channel, grove, spark, opening_volley, deadshot, scrap, tinker, bulwark, thorns, aegis, steady, tome, spare_arrows, vanish, barrage, steadfast, vow, arcana, ferocity, appraise, focus, ambush, dominion, plated, blessed, brawn, rune_woven, nimble, hunter, poise, bark, patchwork, shroud, thick_hide, hearty, wayfinder, lamplight, thrift, haggle, apothecary, unlock, weighted | `items.gd` `effect.rule`; logic in `item_logic.gd` | **Declared, not dispatched** (the code dispatches by item id); each rule is one-off but parameterised by `n` |
| Variant secondaries (50 unique) | lesson, guarded, slash, precision, burning, chill, steel, reach, double_chop, butcher, grisly, frenzy, bleed, crushing, tempered, spikes, rend, heavy_swing, bonebreak, sweep, gilded, harvest, light (×2), venom, shiv, unbound, rime, radiant, soul, bloom, wand_focus, hex, quick_draw, piercing, marksman, arbalest, reload, brawl, guard, rally, wall, rattle, scorch, bulk, catch, barbed, horned, grave_magic, ambush_poison, silent | `items.gd:336-459` | Declared; dispatched **by variant id** |
| Standard variant bonus | "x1.2", "block2", "" | `items.gd:593,639`, `item_logic.gd:69` | Generic |
| Passives (32) | one rule each (pair_master … midas_fist) | `has_passive` sites | **One-off by id**; numbers in `Balance.PASSIVE_*` |
| Pet charge triggers | pair_plus, low_die, six, kept, attack_intent, board_double, block, one, set3, reroll, rune, win | `pet_logic.gd:314` | **Generic** |
| Pet fire / perk / L5 / L10 | 12 fires (heal, bite, poison-all, tempo, block-roll, gold-bite, block+thorns, freeze+chill, burn-all, fix-lowest, refire-rune, brew) and 12 perks | `pet_logic.gd:81-240`, `game_flow.gd` | **One-off by pet id** |
| Potion effects | heal %, stoneskin (block now + next turn), reroll tonic, cleanse+heal | `game_flow.gd:1675` | **One-off by id**, easy to generalise |
| Affix rules | trait-affixes (via `trait`), regenerating, vampiric, hexing, frostbound, gilded | `affixes.gd:163`, `combat.gd` | Mixed |
| Event kinds | shrine (2 passives/blessings), duel (bet), outbreak/garden (convert next 3 Empty → enemy/chest), merchant (max-HP for rare rune), dicesmith (2 kinds, add/reforge), idol (HP for +1 lowest faces) | `game_flow.gd:1243-1390` | **One-off by id** (id = kind today) |
| Shrine blessings | atk, max_hp, gold, face | `events.gd:18` | Generic keys |
| Minigame ids | fossil_hunter, bubble_breaker, scratch_off, claw_machine, bubble_shooter, plinko, shell_game, memory_match, fishing, lucky_wheel, high_low | `core/minigames/minigames.gd:17` | Code |
| Minigame signatures (reward primitives) | new_die, reroll_boost, gold_60 (fallback gold), passive_common, sharpshooter, rare_rune, heart_gem, mirror_forge, potion_pair, passive_uncommon, high_roller | `game_flow.gd:1796-1823` | **Generic** (reusable by any game) |
| Minigame tier rewards | gold, crown, potion, face_raise, rune_choice, potion_gold | `game_flow.gd:1779-1795` | Generic |
| Draft options | new_die, rune, max_hp, face_raise, combat_reroll | `game_flow.gd:813-830` | Closed |
| Shop kinds | die, rune, potion, face_raise, passive, combat_reroll | `shop.gd`, `game_flow.gd:1045` | Closed; weights generic |
| Unlock kinds | classes, biomes, bosses, minibosses, pets, minigames, packs, gear, potions, features (+ items) | `unlocks.gd:13`, `profile.gd:253` | Generic (but `all_ids` hand lists) |
| Milestone conditions | {stat,min}, {class_wins,id,min}, {boss_kills,id,min}, {any:[]}, {all:[]} | `profile.gd:439-480` | Generic |
| Milestone stats | 29 `Profile.COUNTERS` (`profile.gd:42`) + best_lap, classes_at_boss, classes_owned, boss_kinds, sets3, … | `profile.gd:401-437` | Generic, but 5 counters are **id-specific** |
| Feat conditions | {counter,min}, {boss,with,[min]}, {win_with,asc}, {class_win,asc}, {kills,min} | `items.gd:463`, `profile.gd:800` | Generic |
| Variant unlocks | {mastery:15/45/90}, {feat:id}, {class:id, or_mastery} | `items.gd:20` | Generic |
| Skin conditions | class_win, class_asc, class_bosses, or_class_asc, prestige | `skins.gd:23` | Generic |
| Ascension keys | extra_elite, lap_heal, shop_tax, miniboss_trait, potions, enemy_stats, biome_curse, hazards, boss_phase, double_boss | `unlocks.gd:299` | Closed |
| Combos | high_roller, pair, two_pair, three_kind, small_straight, straight, full_house, four/five/six_kind | `combo.gd:9` | Closed; mults are data |

---

## 3. Presentation data: how looks, anims, icons, sfx, music and dressing are chosen

**Chokepoints.**

- Everything loads by **path string** at runtime; there is no `preload("res://assets…")`. This is
  confirmed in streaming doc §1.
- `Props.has/inst` (`game/world/props.gd:18-34`) is the prop chokepoint.
- `ResourceLoader.exists` guards give FREE-asset fallbacks.

Ids map to looks through the tables below.

| Content | Table(s) today | What a pack entry must carry instead |
|---|---|---|
| Hero model / rig / attack | `Character.MODELS` `character.gd:35` ([glb, rig medium/large, attack alias, default gear, base texture]); `PART_MAP` `:75`; `KITS` `:136`; `SKIN_TEX` `:161`; `ATTACKS` `:210`, `ALIASES` `:193` | `look.model` = existing model id **or** `{glb, rig, attack, gear{socket:path}, texture}`; `parts {head, headwear, body, arms, back}` mesh-name lists; skin textures per slot; colour; icon |
| Skins | `SkinDefs.LOOKS` `skins.gd:32` + `HeroLook` overlays (`crown`, `statue`, `chieftain`, `shade`, `gold_turret`, `full_suit`) | `skins[slot] = {texture, mesh?, helmet?, overlay: <overlay primitive>}` |
| Enemy look | `EnemyRoster.LOOKS` `roster.gd:48` (model, texture, tint+strength, emission, scale, gear{socket:path}, gear_xf, clips{role}, undead, ranged, shot, parts, hide, **extras** (33 procedural bits, `enemy_looks.gd:614-790`), eyes, light, aura, hud, forms{}, variants[]), `BIOME_LOOKS` `:395`, `SkinRules` tiers/traits (`skin_rules.gd:94`), `AffixLooks` | the same dict, JSON-encoded (Color → `"#rrggbbaa"`, Vector3 → `[x,y,z]`); `extras` from a registered vocabulary; per-biome overrides live in the *biome's* pack |
| Weapon / off-hand / trinket model | `ItemDefs.model` + `ItemMounts.MOUNTS` `item_mounts.gd:83` (scene, socket, pos/rot/axes/scale, base) + `ITEMS` `:199` + `BASES` `:44` (slot, hands, style, clip) | `look = {scene, socket, pos, rot|axes, scale, base_style, clip, model_2h?}` |
| Armor pieces | `ItemMounts.HEADS/BODIES/BACKS` `:304-338` + `ArmorBinder` donors | `look = {glb, parts[], …}` |
| Biome world | `Biome.LOOKS` `biome.gd:38` (sky, fog, lights, island colours, `particles`, cloud colours) and `BiomeBlocks.LOOKS/TERRAIN` `biome_blocks.gd:22,139` (floor, path, `floor_shader`, top, fill, sea) + **code dressing** `game/world/dressing/<id>.gd` + `Biome.build` `match id` `biome.gd:129` | `look = {frame: "blocks"|"crypt"…, sky{…}, terrain{…}, particles, sea, dressing: {kit: <existing look id>} | {declarative spec}}` |
| Biome audio / colour / icon | `AudioBus.MUSIC` `audio_bus.gd:82`, `UiPalette.BIOME` `palette.gd:119`, `ui/icons/biome_<id>.svg`, `TileStyle.BASE` `tile_style.gd:35` | `music: <path or id>`, `accent: "#…"`, `icon: <svg path in pack>`, `tile_base` |
| Pets | `PetDefs.model` (hint), `PetView.LOOKS` `pet_view.gd:27`, per-pet builder code `pet_view.gd:141`, `pet_view_ext.gd:55` | `look = {builder: <existing builder id>}` or a declarative `{props:[…], eyes, glow, pips_color}` |
| Potions | `icon` field; `meta_hud.gd:438` `POTION_COLORS`; rendered icons `rendered_icons.gd:23` | `look = {icon, color, model}` |
| Class badge / text | `ClassInfo.TAGLINES/MECH_COLOR` `class_info.gd:6,20`; `UiIcons.class_icon` `ui_icons.gd:115` | `text.tagline`, `look.color`, `look.icon` |
| Encounter cards | `EncounterCards.NEW_ENEMIES/RULES` `encounter_cards.gd:12,120` | `text.card` (+ `card: true`) |
| Intents / traits HUD | `UiPalette.INTENT/TRAIT` `palette.gd:92,111`, `UnitHud` `unit_hud.gd:7-21` | stays in core presentation (closed vocabularies) |
| SFX | `AudioBus.SFX` `audio_bus.gd:23` (by event id) | optional `look.sfx = {hit: <sfx id>}` choosing from existing ids |

**Presentation primitive vocabulary** (these become `look.*` capabilities, §8c):

- model ids: `Character.MODELS`, 26 entries.
- rigs: medium/large. Attack aliases: melee_1h, melee_2h, magic, dual, bow, unarmed, large, crossbow, spear, scythe.
- clip aliases: `character.gd:193`. Sockets: `handslot.r/l`, back, belt, hip, hip2.
- enemy extras: 33 (leaf_crown … blood_motes). Skin overlays: 6.
- particles: ash, dust, embers, fireflies, pollen, sand, snow, wisps. Floor shaders: cave, meadow, mud, night_meadow, sand, snow.
- sea: clouds/lava. Dressing kits: 10 biome dressers.

All of these can be referenced by data. New ones need a binary update.

**Fallbacks.** Missing assets already degrade gracefully (Props/FREE fallbacks, AudioBus guards). The
ContentDB should add a per-kind `fallback_look`: the mannequin for a model, the glyph for an icon, the
`crypt` frame for a biome.

---

## 4. Determinism

**RNG** (`core/rng.gd`) is a seeded xorshift64* with splitmix seeding. State is serialised as a decimal string.

- `pick(arr)` is index-based.
- `weighted(dict)` "iterates keys in insertion order" (`rng.gd:64-74`).
- `shuffle` is Fisher–Yates.
- One run stream: `RunState.rng`, `run_state.gd:82`.
- Derived streams:
  - affixes: `Rng.new(hash([seed,"affix",lap,idx,ids]))` at `run_state.gd:201`. **Enemy id strings are
    inside the hash.**
  - minigames: own Rng.
  - bot: `hash([...])` at `bot.gd:465,1582,2415`, including `class_id`.
  - presentation variants: `enemy_looks.gd:80`.

**Content order feeds the stream.** Every one of these draws depends on list order or dictionary insertion
order:

| Draw | Source order |
|---|---|
| Route | `BiomeDefs.TIERS` order via `rng.pick(tier)` (`biomes.gd:181`, `run_state.gd:113-118`); the meta path picks among unlocked, in tier order |
| Mini-boss / boss | biome candidate list order (`run_state.gd:136-137`) |
| Board bag | `Board.layout_for` dict order (`LAYOUTS` then the biome's `mix` keys) → `rng.shuffle` (`board.gd:130-146`) |
| Enemies | biome `pools` arrays (explicit, good) via `rng.pick` (`board.gd:197-202`) |
| Events | `rng.pick(EventDefs.IDS)` (`game_flow.gd:1244`): **adding an event re-maps every event draw** |
| Runes / kinds / passives | `for id in IDS` builds the weight dicts (`runes.gd:61-90`, `dice_kinds.gd:74-100`, `passives.gd:111-153`) |
| Affixes | `AffixDefs.BIOME[b]` order + "gilded" (`affixes.gd:88-94`) |
| Shop | `ShopDefs.ITEMS` insertion order (`game_flow.gd:1012`) |
| Potion types | `meta.potion_types` = profile unlock order (`game_flow.gd:1064`) |

**Where content order leaks into state:**

- Profile `unlocks[kind]` is rebuilt "in content order" (`profile.gd:261-265`).
- Grimoire stores `Runes.IDS.find()` indices (`pet_logic.gd:297-306`).
- `Biome.seed_of` uses the `IDS` index (`biome.gd:97`). This one is presentation only.

**Consequences when packs add entries:**

1. Same seed, different installed packs → different runs.
   - Meta runs partly insulate themselves: pools for runes, kinds, passives, biomes, bosses and minibosses are
     filtered by the profile's unlocks (`meta_run.gd:48-51`).
   - Nothing filters events, affix weight lists, the shop, legacy (non-meta) runs or the sims.
2. Replays (`GameFlow.replay`, `game_flow.gd:1975`; save = seed + command log) are only exact against identical content.
   - A balance patch changes replays. So does inserting a rune, because it shifts the Grimoire indices.
3. There are **no daily seeds today** (grep: none). Any future daily or leaderboard must pin a content set.
4. `hash()` of arrays is stable for identical inputs within an engine version. Official ids must therefore
   **never be renamed or namespaced retroactively**, because that would change affix rolls and bot decisions.

**Rules to adopt:**

- **R1. Explicit, sorted pools.**
  - Every draw over content goes through `ContentDB.pool(kind, filter, run.content)`. It returns ids sorted by
    `(order, id)`.
  - `order` is an integer assigned once in the id ledger. Base content keeps today's order exactly (so seeds are
    unchanged), and new packs get increasing orders.
  - The result is independent of pack load or download order.
- **R2. Design-relevant pools stay explicit in data** (biome `pools`, candidates, tiers, affix lists, event
  pools per biome with weights). No "all enemies of tag X" at draw time unless materialised and sorted.
- **R3. Content sets per run.**
  - A run records `meta.content = {packs: {id: hash}, fp: <sha256>}`.
  - Draws only see content from that set (and the profile's unlocks).
  - New content never enters a run silently. It enters when a pack is enabled *and* unlocked, and runs started
    before that keep their set.
- **R4. Pinned fingerprints.**
  - Sims, CI balance baselines, replays, dailies and leaderboards pin `fp`.
  - `tools/sim.gd --packs=base,weapons-2026-10` reports `fp` in its output.
- **R5. Ids, never indices, in any serialised state.** Fix `pet_state.rune/rune2` and `Biome.seed_of`
  (use `hash(id)`).
- **R6. Weight dicts are built from sorted pools only.** Never iterate a merged `Dictionary` whose insertion order
  depends on pack merge order.
- **R7. Balance patches bump `fp`.** An in-progress run keeps its pinned pack versions (the store keeps
  those hashes until the run ends), so a run's rules never change mid-run.

---

## 5. Saves and profile

**Files.**

- Profile: `user://profile.json` (`game/camp/profile_store.gd`).
- In-progress run: `user://save.json` (`game/game_controller.gd:27,774-793`), which holds `GameFlow.to_dict()`.

**Versioning.**

- `Profile.VERSION := 3` (`profile.gd:40`). It has migrations v1→v2 (records, cosmetics; `:577-583`) and v2→v3
  (gear → Armory; `_migrate_gear` `:933-980`).
- `GameFlow.SAVE_VERSION := 1` (`game_flow.gd:10`). `from_dict` has no migration logic beyond defaults
  (`run_state.gd:433-495`).

**How ids are stored:**

- **Profile.**
  - `unlocks{kind:[ids]}`, `disabled{runes,kinds,passives}`.
  - `armory{owned, variants, blueprints, mastery, feats, equipped{class:{slot:{id,variant}}}, appearance, seen_new}`.
  - `pet_xp{pet}`, `pet_bought`, `minigame_plays{id}`, `loadout{class, minigames, pet}`, `milestones[]`.
  - `records` (by class, boss, route, `firsts{biome, miniboss, boss, class_win, route_win…}`, `seen{enemies, affixes}`), `cosmetics{owned{class:[skin]}}`.
- **Run.**
  - `class_id`, `route`, `miniboss_id`, `boss_id`.
  - board tiles `{type, enemies[ids], enemy_affixes, game}`.
  - dice `{faces, rune, kind, tags}`, `passives[]`, `belt[]`.
  - `meta` (items `{slot:{id, variant, tier}}`, pools, pet, minigames, biomes/bosses…).
  - `pet_state` (incl. rune **indices**), `item_state`, the combat state with enemy dicts, the minigame state, and the **command log**.

**What happens when a pack is missing or removed (today, as the code is written):**

- **Profile: silent, permanent data loss.** `from_dict` routes every id through `grant()`, which returns false for
  ids not in `UnlockDefs.all_ids()` (`profile.gd:258`).
  - `disabled` is filtered the same way (`:511-517`), as are milestones (`:537-539`) and skins (`SkinDefs.has`, `:584-606`).
  - The armory drops unknown owned items, variants, mastery, feats and classes (`:869-930`: `grant_item`, `ItemDefs.has`, `HeroDefs.DATA.has`).
  - `loadout.pet` and `minigames` reset (`:526-533`).
  - The next `to_dict()` writes the reduced profile. A player who opens the game while a pack is unmounted (not yet
    downloaded, incompatible, Web lazy-load) loses the purchases and unlocks tied to it.
- **Run save.** Unknown ids either **crash** or **silently substitute**:
  - `EnemyDefs.def` → `ENEMIES[id]` crashes.
  - `Runes.DEFS[r]` and `PetDefs.DEFS[id]` crash.
  - `HeroDefs.def` → Knight, `DiceKinds.def` → Standard, `_drink` unknown → heal, `ItemDefs.def` → `{}` (the item does nothing).
  - Continuing would diverge from the command log.

**Required changes (before any pack ships):**

1. **Non-destructive loading.**
   - Unknown ids go into `profile.dormant = {kind: [ids], armory: {...}, …}` (or stay in place and are
     simply skipped by consumers).
   - Nothing is ever dropped, and dormant ids are re-merged when their pack mounts.
   - A test must assert that `from_dict(to_dict(p))` with a pack unmounted, then remounted, is lossless.
2. **A profile v4** that adds:
   - `content: {seen_packs: {id: version}, dormant: {...}}`;
   - generic counters `biome_visits:{id}`, `biome_wins:{id}`, `biome_events:{id}`, `kills_by_tag:{tag}`, keeping the old
     counter names as derived aliases for existing milestones.
3. **Run save v2** records `content {packs:{id:hash}, fp}`. On load:
   - if every pinned pack is available (same hash), continue;
   - if a pack is missing, show "Continue needs *Pack X* (downloading 12 KB…)", never delete, never migrate;
   - if a pack is only available at a newer hash, keep the old one: the pack store keeps pinned hashes (streaming doc
     §5.4 eviction rule) until the run ends.
4. **Retire, don't delete.**
   - Content removed from the game becomes `retired: true`: loadable, never offered, never dropped.
   - Its id is never reused (id ledger, §8b).

---

## 6. Localization

- **None today.**
  - No `tr()`, `tr_n()`, `TranslationServer`, `.po` or `.csv`.
  - No `locale` or `internationalization` keys in `project.godot`.
- **Where display strings live:**
  - **Core content:** `name`, `desc`, `title`/`text`, pet `fires`/`perk`/`l5`/`l10`, item `effect.desc` templates with
    `{key}`/`{key%}` placeholders (`items.gd:619-631`), `sec_name`, feat `desc`, milestone `desc`/`hint`, workshop pack names,
    ascension `desc`.
  - **Core-generated text:**
    - `skins.gd:86` `cond_text` and `items.gd:639-657` `std_text`/`unlock_text`;
    - `game_flow.gd` inline labels (event choices `:1260-1290`, rewards `:1785-1823`, shop labels);
    - `DiceKinds.label` (`"%s Die"`).
  - **Presentation:** `ui/widgets/class_info.gd` (taglines, mechanic rules, trigger pops),
    `game/enemies/encounter_cards.gd:120`, `ui/theme/palette.gd:111` (trait names/rules), `ui/camp/camp_info.gd` labels,
    `ui/modals/*` titles, `ui/minigames/*` text, `game/flow/twist_beats.gd:17`.
- **Recommendation (cheap now, expensive later):**
  - Pack JSON carries text under `text` with a string key per field, plus `strings/<locale>.json` in the pack
    (`"en"` required).
  - At mount, ContentDB builds `Translation` objects (`Translation.add_message`, which is data-only) and registers
    them with `TranslationServer`.
  - Core rules never format player text. They emit events and ids, and the UI formats with `tr(key).format(params)`.
    Item `desc` templates already work this way.
  - Step 1 is only: *all new pack content uses keys*, and the base content keeps English literals until an i18n pass.

---

## 7. Tests and sim: current references and how they'd validate packs

- **Runner.** `tests/run.sh` runs `tests/run_tests.gd`, which is headless and discovers `test_*.gd` (627 test methods;
  largest: `test_flow.gd` 71, `test_passives.gd` 52, `test_combat.gd` 42, `test_armory.gd` 34).
- **How tests reference content:**
  1. **Literal ids everywhere** (classes, routes, items, pets).
  2. **Pinned counts:** `test_armory.gd:66` asserts `{"weapon":16, "offhand":8, "head":8, "body":11, "trinket":8,
     "back":13}` and variant counts `{"weapon":55, …}` (`:75`).
  3. **Coverage checks that are already "pack validators" in miniature:**
     - `test_armory.gd:49` (table completeness, 3 tiers per number, feats exist, unlock text);
     - `test_armory.gd:88` (every item has a mount/look, BASES hands/style agree);
     - `test_armory.gd:111` (every class has a valid kit);
     - `test_enemy_looks.gd:13` (every enemy has a roster look) and `:19` (every trait has a SkinRules entry);
     - `test_enemy_looks.gd:103` (every affix has badge art).
  4. **Self-consistency replays:**
     - `test_flow.gd:650,668,989` and `test_biomes.gd:169` (`replay == original` for every route) and
       `test_armory.gd:558`;
     - these compare a run to its own replay, not to golden outcomes.
- **Sim:** `tools/sim.gd` (792 lines).
  - Content is chosen by id flags: `--class`, `--route`, `--boss`, `--pet`, `--armory=<slot>:<item>[:<variant>]`,
    `--variant`, `--item=<item>.<key>=…`, `--hero=<class>.<field>=…`, `--enemy-hp=<id>:<m>`, `--affixes=force:<id>`,
    `--twist=off:<biome>`, `--cl=<KNOB>`, `--tune-*`, `--bnum`, `--moon`.
  - Sim dials are static vars (`HeroDefs.tune`, `ItemDefs.TUNE`, `EnemyDefs.tune_hp_by_id`, `BiomeDefs.twist_off`, `Balance.tune_*`).
  - Balance targets are in `balance.gd:208-216`.
- **How packs would be validated.** CI runs these per pack and on the merged set:
  1. **Schema:** `python -m jsonschema` / `check-jsonschema` against `content/schema/*.schema.json`. The repo already runs
     Python in CI (`tools/ci/*.py`).
  2. **ContentDB validate:** a headless `tools/content_validate.gd` checks:
     - referential integrity (pools → enemies, kits → items, variants → items, feats → counters, unlock refs);
     - id ledger (new ids unique, no reuse);
     - `requires` ⊆ core caps;
     - patch targets exist and are `patchable`;
     - text keys exist in `en`.
  3. **Looks** (needs the asset units, which CI already decrypts): every path in `looks` resolves inside the
     declared asset packs, and every `extras`/`builder`/`kit` is registered. This generalises `test_armory.gd:88` and
     `test_enemy_looks.gd:13,75`.
  4. **Sim smoke per pack:**
     - N bot runs per class with the pack enabled and its content forced (`--packs=`, `--armory=`, `--route=`);
     - zero error events, `replay == run`;
     - a determinism check that the pack load order is shuffled and gives the same `fp`.
  5. **Balance guard:** win-rate deltas vs the baseline `fp` within the `balance.gd:208-216` bands (non-blocking warning
     for content packs, blocking for `balance-*` packs).
  6. **Split the tests:**
     - engine tests run against a **fixture content set** (`tests/fixtures/content/`), independent of shipped content;
     - "base content snapshot" tests keep the pinned counts and gain **golden fingerprints** (§8f step 0).

---

## 8. Design proposal

### 8a. Definition format: JSON vs ConfigFile vs `.tres`

I verified these points on Godot 4.7.2 in a scratch project (appendix A). The repo was not touched.

| Criterion | **JSON (+ JSON Schema)** | Godot **ConfigFile** | **`.tres` custom Resources** (scripts in core) |
|---|---|---|---|
| Store policy (no code) | **Safe.** `JSON.parse_string` only yields String/float/bool/Array/Dictionary/null. Verified: `"Object(RefCounted)"` stays a String | **Unsafe.** `ConfigFile.load()` parses values with the VariantParser. Verified: `Resource("res://payload.gd")` **loads and runs the script** (`_static_init` + `_init`), and `Object(RefCounted,"script":…)` instantiates it | **Unsafe.** Verified: a `.tres` with an embedded `[sub_resource type="GDScript"]` **runs its `_static_init`/`_init` on `load()`**, and an `ext_resource` pointing at `user://dropped.gd` loads and runs a downloaded script |
| Code-injection mitigation | none needed | forbid `Resource(`/`Object(`/`ExtResource`/`SubResource` tokens: a pre-parser you have to maintain | a custom "safe loader" that text-scans for `type="GDScript"`/`Script`, allowlists `ext_resource` script paths to `res://core/content/schema/*.gd`, rejects `user://` and binary `.res`. Fragile. `ResourceLoader.get_dependencies` does **not** list embedded scripts (verified) |
| Tooling | any editor; JSON Schema gives IDE completion and validation; Python in CI | Godot-only syntax; no schema tooling | best in-editor (inspector, typed exports), but needs the Godot editor; hard to validate outside Godot |
| CI validation | `check-jsonschema` + a headless Godot semantic pass | custom | headless Godot only |
| Merge-ability / diffability | good with one entry per block, sorted keys, 2-space pretty print; better still with one file per entity in source | fine for flat keys; nested dicts are single long lines | poor: sub_resource ids renumber, `load_steps` changes, UIDs churn |
| Load speed | measured: all current defs (77.5 KB) parse in **3.3 ms**; a `var_to_bytes` cache gives 2.2 ms (not worth it) | similar | fast (binary) but needs import; also clobbers the class cache when shipped in PCKs (streaming doc appendix A exp. 3) |
| Engine coupling | none | low | high (resource format versions, UIDs, class cache) |
| Types | numbers become float (verified), so normalise to int where the schema says so. The codebase already does this (`GameFlow._intify`, `Profile._int_map`, `MetaRun.normalize`) | native Color/Vector3 | native |

**Pick: JSON plus JSON Schema** for everything a pack can contain: definitions, looks, strings and the manifest.

- Engine types are encoded as `"#rrggbb[aa]"` and `[x,y,z]`, decoded by one `ContentCodec` in core.
- Never use `str_to_var`, `ConfigFile`, `bytes_to_var_with_objects`, `Expression` or `.tres`/`.tscn` on pack content.
- `bytes_to_var` (without objects) is safe: verified, it returns `ERR_UNAUTHORIZED` on object payloads. It could serve
  as a cache format if ever needed.
- Keep the DSL **declarative and non-Turing-complete**: enumerated primitives with numeric params and closed
  condition enums, and no formula strings. That keeps packs clearly "data" under Apple 2.5.2 and Google Play's
  Device and Network Abuse policy.

**Asset PCKs are also a code vector.** A PackedScene (`.scn`) can embed a GDScript. Verified: the bytes contain
`GDScript`, and `get_dependencies` returns `[]`. The streaming doc's PCKPacker pipeline therefore needs a CI gate:

- reject any `.gd`/`.gdc`/`.cs`;
- byte-scan every packed resource for the `GDScript`/`CSharpScript`/`Script` class names;
- allowlist path prefixes;
- the runtime mounts only signed-manifest sha256-verified packs with `replace_files=false` (streaming doc §5.2/§5.5).

**Authoring layout.**

- Source: `content/src/<domain>/<id>.json`, one entity per file for merge-friendliness.
- Build: CI bundles each pack into `defs.json` + `looks.json` + `strings/en.json` + `manifest.json`, with canonical
  (sorted-key) serialisation so pack hashes are reproducible.

### 8b. ContentDB: registry, ids, merge, overrides

**Placement.** `core/content/content_db.gd` (class `ContentDB`), pure core (no `game/` dependencies).

- It loads base packs from `res://content/base/<pack>/` (shipped in the code pack), then mounted packs from the pack
  store.
- The existing `*Defs` classes stay as **facades**: `ItemDefs.def(id)`, `EnemyDefs.def(id)`, `HeroDefs.IDS`…
  now read `ContentDB`. That keeps the ~600 call sites and the sim/test API.
- GDScript `const` can't be filled at runtime. The facades expose `static var` (or getters) populated by a
  lazy `ContentDB.ensure()`. This matters for headless tests and sims, which have no autoloads.

**Ids.**

- **Official content keeps bare ids**, and they are globally unique across all official packs forever.
  - An **append-only id ledger** (`content/ids.lock.json`: `{id: {kind, order, first_pack, retired?}}`) is enforced by
    CI.
  - This keeps every existing save, replay, affix hash and bot hash valid.
- **Canonical form is `ns:id`.**
  - The official namespace is implicit, so `"sword"` ≡ `"dr:sword"`.
  - Any other namespace (future partner or UGC content, if ever allowed) must be explicit (`"acme:flail"`).
  - Ids match `^([a-z][a-z0-9_]*:)?[a-z][a-z0-9_]*$`.
- **Ids are independent of packs.** Content may move between packs (e.g. `weapons-2026-10` folded into
  `weapons-base` in a later major) without changing ids.
- `order` (from the ledger) drives every sorted pool and display order (R1, §4).

**Pack contents (operations):**

```jsonc
// defs.json
{
  "format": 1,
  "add":   { "item": { "flail": { ... full entry ... } }, "variant": { "flail_morning": { ... } } },
  "patch": { "item": { "sword": { "effect": { "n": { "flat": [1, 1, 2] } } } } },       // RFC 7386 merge patch
  "edit":  { "biome": { "crypt": { "pools": { "1": { "$add": ["bone_flailer"] } } } },  // list membership edits
             "tiers": { "1": { "$add": ["sunken"] } } },
  "constants": { "Balance.CAMPFIRE_HEAL_PCT": 0.32 },                                   // typed, allowlisted
  "retire": { "event": ["idol"] }                                                       // tombstone, never delete
}
```

**Semantics.**

- **`add`**: the id must be new in the DB. A duplicate `add` makes the *whole pack* rejected (logged; CI prevents it).
- **`patch`**:
  - JSON Merge Patch on an existing entry;
  - only on fields the schema marks `"patchable": true` (numbers, weights, text keys, `look`, pools);
  - identity fields (`slot`, `kind`, `effect.rule`, `sec`, `tier`) are not patchable, and are redesigned only via a
    major content version.
  - **So yes, a balance pack can patch existing numbers**, including `Balance`/`Economy` constants via
    `constants`, once those become DB-backed static vars.
- **`edit`**: order-insensitive membership ops `$add`/`$remove` for pools, tiers, candidates, workshop packs and affix
  lists. Order-sensitive lists (intent patterns, phases, `n:[I,II,III]`) are only replaced whole via `patch`.
- **`retire`**: the entry stays loadable (saves), is never offered and is never dropped.

**Load order (deterministic, independent of download order):**

1. Sort packs by `(layer, order, pack_id)`, where layer is `core`=0, `content`=1, `balance`=2, `hotfix`=3.
2. Apply all `add` (any order; conflicts are errors), then `edit` in sorted order, then `patch` and `constants` in
   sorted order, then `retire`.
3. Validate: references, caps and schema types. Any invalid pack is disabled as a unit, with its dependents.
4. Freeze, then compute `fp = sha256(canonical_json(merged DB))`. Also keep `set_id = sha256(sorted pack id@hash)` for
   quick comparisons.

**Conflicts.** Two patches to the same field: the later one wins at runtime (with a warning), and CI **fails** for
official channels. A pack may declare `"after": ["weapons-base"]` and `"conflicts": [...]`.

**Per-run activation.** `RunState.meta.content` records the pack set (§4 R3). `ContentDB.view(content_set)` gives the
run a stable, filtered view: sorted pools that exclude disabled packs.

### 8c. `content_api` and capabilities

**Core side** (`core/content/content_api.gd`):

```gdscript
const FORMAT := 1            # JSON schema major the binary understands
const CAPS := {              # kind -> {primitive: max version supported}
  "effect":   {"twin_edge": 1, "cleave": 1, "thorns": 1, ...},   # item rules (by rule id)
  "sec":      {"slash": 1, "precision": 1, ...},                  # variant secondaries
  "passive":  {...}, "rune_trigger": {"COMBO": 1, ...}, "rune_effect": {...},
  "intent":   {"attack": 1, ..., "bury": 1}, "trait": {...}, "boss_mech": {"moon_meter": 1},
  "twist":    {"ore": 1, "drums": 1, "moon": 1, "heat": 1, "campfire_bonus": 1, ...},
  "tile":     {...}, "mechanic": {...}, "pet_charge": {...}, "pet_fire": {...}, "pet_perk": {...},
  "potion_op":{...}, "event_kind": {...}, "signature": {...}, "cond": {...}, "stat": {...},
  "look.model": {...}, "look.extra": {...}, "look.overlay": {...}, "look.particles": {...},
  "look.floor": {...}, "look.dressing": {...}, "look.pet_builder": {...}, "look.style": {...},
}
```

**Pack side** (`manifest.json`):

```json
{"id": "weapons-2026-10", "version": "1.0.0", "layer": "content", "order": 120,
 "requires": {"format": 1, "caps": ["effect:cleave@1", "effect:rampage@1", "sec:bleed@1", "look.style:melee_2h@1"],
              "assets": ["extra", "art-weapons-2026-10"]},
 "provides": {"item": ["flail", "war_pick"], "variant": ["flail_morning"]},
 "min_core": "0.6.0"}
```

**Rules:**

- `requires.caps` is **computed by CI** from the pack (walk every rule/intent/trait/look reference). Authors can't forget
  or under-declare.
- A cap version bumps only on an incompatible change of a primitive's params or semantics.
  - Prefer adding a *new* primitive (`thorns_all`) over bumping, so old packs keep working.
  - Core may support ranges (`"thorns": [1, 2]`).
- **Feed filtering.** Update manifest schema 2 (streaming doc §5.4) gains `content_packs: {id: {hash, url, sha256, size,
  requires}}`. The client drops packs whose `requires` it can't meet before downloading, and re-checks after.
- **UI.**
  - Unsupported packs show "Update the game to get *Pack X*" (not hidden, if the player owns content from it).
  - Saves referencing such content stay dormant (§5).
- **Policy nuance (Apple 2.3.1 "hidden/dormant features").** New *primitives* ship in a binary update, and
  preferably with at least one base use or a changelog line. Packs then *combine* them. Don't dark-ship whole modes
  that a pack switches on.

### 8d. Where presentation mapping lives

- It sits **in the same pack as the content, in a separate file** (`looks.json`), so core rules, sims and tests never
  load presentation. `ContentDB.look(kind, id)` is read only by `game/**` and `ui/**`.
- Paths:
  - must lie under the asset prefixes of the packs listed in `requires.assets`;
  - CI verifies they resolve;
  - at runtime `Content.available(id)` (streaming doc §5.3) = rules loaded ∧ asset packs mounted.
- Existing tables become JSON in the base packs:
  - roster → `foes-base/looks.json`;
  - `ItemMounts` → `armory-*-base/looks.json`;
  - `Character.MODELS`/`PART_MAP`/`KITS`/`SKIN_TEX` → `heroes-base/looks.json`;
  - `Biome.LOOKS`/`BiomeBlocks.LOOKS`/`TERRAIN`, music and palette → `biomes-base/looks.json`;
  - taglines and encounter texts → strings.
- Code keeps only the **builders** (procedural extras, pet builders, dressing kits, overlays). They are registered as `look.*`
  caps.
- **Biome dressing.** Two tiers:
  1. `"dressing": {"kit": "moonlit"}`: reuse an existing code dresser with a new sky, terrain and palette. Available
     after the refactor, no new art needed.
  2. `"dressing": {"spec": {...}}`: a declarative interpreter over the existing `Dressing` API (`game/world/dressing/dressing.gd`:
     `scatter`, `place_near`, `place_in`, `front_row`, `group`, `mm`).
     - Spec contents: `{frame, walls, set_pieces:[[{path, at, yaw, k, tint}]], kits:[...], scatter:[{paths, count, where, k, tint}], lights:[...]}`.
     - This is what makes **new maps** shippable by data.
- **Fallbacks:** `fallback_look` per kind (mannequin, glyph, crypt frame), so missing assets never block rules.

### 8e. Pack taxonomy (by domain and change frequency)

There are two kinds of pack, linked by `requires.assets`:

- **Definition packs** (JSON, tiny, per domain). These change often.
- **Asset packs** (PCK, per source unit, from the streaming doc §5.1). These change rarely.

Sizes: the definition estimates are scaled from the measured 22 KB gz for all current rules content, plus ~25 KB gz for
the looks tables. The asset sizes come from streaming doc §2.2.

| Pack | Layer | Contents | Change freq | ≈ size (gz) | Needs asset packs |
|---|---|---|---|---|---|
| `core-defs` (in code pack) | core | Balance/Economy constants, combos, board layouts, shop weights, ascension numbers, currencies, tile/intent/trait registries | per binary | ~4 KB | — |
| `heroes-base` | content | 11 classes, mechanic params, skins, kits refs, taglines + looks | rare | ~4 + 3 KB | core3d, foes, extra |
| `foes-base` | content | 23 enemies, 8 mini-bosses, 7 bosses, affixes, encounter texts + roster looks | rare | ~6 + 6 KB | foes |
| `biomes-base` | content | 10 biomes, tiers, twist params, pools, music refs + LOOKS/TERRAIN | rare | ~4 + 6 KB | core3d, nature, audio |
| `weapons-base` | content | 16 weapons + 36 variants + feats | rare | ~6 + 3 KB | core3d, extra |
| `offhands-base` / `armor-base` / `trinkets-base` ("tools") | content | 8 + 9 variants / 8 head + 11 body + 13 back + 4 variants / 8 trinkets | rare | ~2 / ~3 / ~1.5 KB | core3d, extra, foes |
| `pets-base`, `dice-base` (kinds + runes), `passives-base`, `potions-base`, `events-base`, `minigames-base` (defs of code games) | content | as named | rare | 1–3.5 KB each | extra (pets, minigames) |
| `meta-base` | content | milestones, feats, workshop packs, upgrades, starter | medium | ~6 KB | — |
| **`weapons-2026-10`** (example drop) | content | e.g. 4 weapons + 8 variants reusing existing rules | once, append-only | ~2 KB defs + ~1 KB looks | extra (+ `art-weapons-2026-10` if new meshes: ~0.1–0.5 MB; KayKit weapon glTFs ≈ 10–30 KB each) |
| `foes-2026-11`, `biome-sunken` (examples) | content | new enemies / one biome (defs + looks + dressing spec) | once | 2–6 KB | foes / nature (+ `art-biome-sunken` 1–5 MB for original art) |
| `balance-2026-10-15` (example) | balance | `patch` + `constants` only | frequent | < 1 KB | — |
| `hotfix-*` | hotfix | emergency numbers/text | rare | < 1 KB | — |
| Asset packs (streaming doc §5.1) | — | ui 1.8, core3d 17.3, audio 9.8, foes 5.7, nature 12–20, extra 13.6 MB | per art change | as listed | — |
| `art-<drop>` (new) | — | new art only, as a **new unit folder** (`assets/packs/<drop>/…`) | once | 0.1–5 MB | — |

**Principles:**

- **Append-only.**
  - Base packs are frozen per release line. New content lands in **new** packs (`weapons-2026-10`, then
    `weapons-2027-01`).
  - Adding a weapon never touches `weapons-base`, so its hash, and the player's cache of it, don't change.
- **Delta by granularity.**
  - Definition packs are 1–15 KB, so replacing a whole pack *is* the delta (e.g. a text fix in `weapons-2026-10`
    re-downloads ~3 KB).
  - Numeric tweaks to base content ship as `balance-*` patches.
- **New art in new units.** Existing asset units never change for a content drop, so the 5–20 MB packs stay cached (the
  streaming doc's content-hash scheme). Per-drop art packs are the "per-biome packs for original art" in streaming Phase 4.
- **Consolidation.** At a major version, CI may fold drops into the base packs. Ids are unchanged (ids ≠ packs), and the
  old pack ids become aliases in the feed.
- **One code pack pins nothing about content packs** except caps, `FORMAT` and `min_core`. Content packs are released
  independently of binaries: that is the goal. Asset hashes are pinned by the content pack's `requires.assets`
  (`{id: hash}`), not by the code pack.

### 8f. Refactor plan

The plan is ordered, with effort in agent-days. "No assets" means it can be done and tested on this checkout
without the KayKit folders: core, tests and sim are asset-free.

| # | Step | Files touched | Effort | Assets? |
|---|---|---|---|---|
| 0 | **Safety net.** (a) Canonical JSON dump of all defs (prototype in appendix B) → golden `defs.fp`. (b) Golden end-state hashes for N bot runs × class × route × profile preset (`core/meta/presets.gd`) → `tests/test_content_golden.gd`. Every later step must keep these identical until a deliberate change | new `tools/content_export.gd`, `tests/test_content_golden.gd` | 1–2 | no |
| 1 | **Non-destructive saves.** Dormant ids in the profile (v4), lossless round-trip with packs absent; Grimoire rune ids instead of indices; `Biome.seed_of` → `hash(id)` | `core/meta/profile.gd`, `core/meta/pet_logic.gd`, `game/world/biome.gd`, tests | 2–3 | no |
| 2 | **ContentDB + base JSON.** Generate `res://content/base/*/defs.json` from the consts (one-time, byte-identical data); loader, merger, validator, codec; `*Defs` facades read the DB; `IDS` derived from ledger `order`; id ledger; add `content/*` to `include_filter` | new `core/content/content_db.gd`, `content_codec.gd`, `content/base/**`, all `core/content/*.gd` (become thin), `export_presets.cfg` | 4–5 | no |
| 3 | **Constants to DB.** `Balance`, `Economy`, `UnlockDefs.ASC_*`, per-type constants → static vars seeded from `core-defs`; `constants` patch op with a typed allowlist | `core/content/balance.gd`, `economy.gd`, `unlocks.gd`, `pets.gd`, `affixes.gd`, `biomes.gd`, `enemies.gd` | 2 | no |
| 4a | **Items by rule.** `ItemLogic` resolves the equipped entry by `effect.rule` (and `sec`), not by item id: `has_rule(run, "twin_edge") -> {item, tier, variant}`; numbers from that entry; rename the duplicate `sec:"light"`; remove the `hammer_mallet`/`spear`/`dino_suit`/`arcane_staff` special cases (→ fields `style_override`, `text_params`, `buyable:false`, `kit_for:[…]`); `MetaRun.armory_stats` by rule; bot CombatModel by rule; `PRICES` → per-item `price` | `core/item_logic.gd` (929 lines), `core/content/items.gd`, `core/meta/meta_run.gd`, `core/bot.gd:1280-1330`, `core/bot_meta.gd` | 5–7 | no |
| 4b | **Passives by rule** (`rule` defaults to id; numbers from `Balance.PASSIVE_*` → `n`) | `combat.gd`, `game_flow.gd`, `run_state.gd`, `passives.gd`, `bot.gd` | 2–3 | no |
| 4c | **Runes by trigger + effect** (use the declared `trigger`; `effect` + `n`; `cap` field replaces `rune_cap`/`NO_DOUBLE_TRIGGER`) | `combat.gd:408-660`, `runes.gd`, `balance.gd`, `class_logic.gd`, `bot.gd` | 2 | no |
| 4d | **Potions by effect list** (heal_pct, block_now_and_next, add_rerolls, cleanse); unknown op → validation error, not heal | `game_flow.gd:1675`, `potions.gd` | 1 | no |
| 4e | **Pets by fire/perk/l5/l10 rule ids** with params; perks via a `PetLogic.perk(run, "trap_mult")` query instead of `has_pet("pebble_golem")` | `pet_logic.gd`, `game_flow.gd` (9 sites), `combat.gd` (3), `pets.gd`, `bot_meta.gd` | 2–3 | no |
| 4f | **Biomes.** Old twists → twist ids with params (`campfire_bonus`, `trap_dodge_gold`, `event_heal`, `elite_boss_passive`); per-biome `twist_params`; `TIERS` from `tier` + `order`; generic counters `biome_visits/wins/events:{id}` (milestones rewritten, old names aliased); `ASC_MINIBOSS_TRAIT` removed or moved into the biome | `game_flow.gd`, `bot.gd:2326-2333`, `biomes.gd`, `combat.gd:1131`, `profile.gd:401-437`, `unlocks.gd` | 2–3 | no |
| 4g | **Enemies.** `tags` (`skeleton`) replace `ItemDefs.SKELETONS`; boss `mechanic:"moon_meter"` + params; `all_ids` from DB (`unlockable:true`); `def()` unknown-id guard | `enemies.gd`, `combat.gd:1098-1180`, `unlocks.gd:86-105`, `item_logic.gd:745` | 1–2 | no |
| 4h | **Classes.** `mechanic_params` (moves the `class_logic.gd:55-81` statics into class defs; sim `--cl` keeps working), `sigils` per entry, `unlock_order` | `class_logic.gd`, `heroes.gd`, `unlocks.gd`, `ui/widgets/class_info.gd` (reads params) | 1–2 | no |
| 4i | **Events by kind** (`gamble`, `convert_ahead{type,n}`, `trade_maxhp{pct,reward}`, `offer_passives`, `dice_offer`, `blood_for_faces`) + weighted, optionally biome-scoped pools replacing `rng.pick(EventDefs.IDS)` (keep the base order for identical seeds) | `game_flow.gd:1243-1390`, `events.gd`, `ui/modals/event_modal.gd` | 2 | no |
| 5 | **Capabilities + manifest + CI.** `content_api.gd`; pack manifest schema; `tools/content_validate.gd`; Python `jsonschema` step; `requires` auto-computation; id-ledger check; asset-PCK script scan (§8a) | new files, `tools/ci/*` | 3–4 | no |
| 6 | **Run content sets.** `meta.content` + `fp` in run saves (SAVE_VERSION 2); `ContentDB.view(set)`; sorted pools (R1–R6); `tools/sim.gd --packs=` and `fp` in the output; replay pins the set | `run_state.gd`, `game_flow.gd`, `meta_run.gd`, `game_controller.gd`, `tools/sim.gd` | 2–3 | no |
| 7 | **Presentation → looks JSON** (roster, item mounts, character models/parts/kits/skin textures, skins, palette colours, icons, music map, encounter texts, pet LOOKS; builders registered as `look.*` caps) | `game/enemies/roster.gd`, `game/actors/{item_mounts,character,hero_look,armor_binder}.gd`, `game/world/{biome,biome_blocks,tile_style}.gd`, `game/audio/audio_bus.gd`, `ui/theme/palette.gd`, `ui/widgets/class_info.gd`, `game/enemies/encounter_cards.gd`, `game/pets/pet_view*.gd` | 5–8 | code no; **visual verification yes** (screenshots) |
| 8 | **Declarative biome dressing** (spec interpreter over `Dressing`), port one biome as proof | `game/world/dressing/*`, `game/world/biome*.gd` | 6–10 | **yes** |
| 9 | **Delivery.** Content packs in manifest schema 2, per-pack store, mount-time merge, Camp "new content"/"needs update" badges, lazy availability (with streaming Phases 1–3) | `game/update/*`, new `game/content/content_packs.gd`, `ui/camp/*` | 4–6 | partly |
| 10 | **i18n groundwork** (keys for pack text, `Translation` from JSON, `tr()` in the UI paths that show content text) | `ui/**`, `core/content/*` | 2–4 | no |
| 11 | **Tests.** Fixture content set, base snapshot, per-pack validation + sim smoke + load-order shuffle | `tests/**`, `tools/sim.gd` | 3–5 | mostly no |

**Totals.**

- **Minimum path to "a weapons pack with no core update":** steps 0, 1, 2, 4a, 5, 6, and step 7 for item looks only,
  plus minimal delivery (9) ≈ **20–28 agent-days (4–5 weeks)**.
- **Everything:** ≈ **45–65 agent-days (9–13 weeks)**.
- About 70% needs no assets. Only steps 7 (visual checks) and 8 do, plus the look-resolution tests in 11.

**Sequencing notes:**

- Step 1 ships **before** any pack can be mounted, even in a beta.
- Steps 2–4 are behaviour-preserving by construction and gated by step 0's goldens. Item ids equal their rule's
  owner today, so every hash stays identical.
- Step 4 sub-steps are independent and can run in parallel worktrees.

### 8g. Risks

1. **Silent behaviour drift during the refactor.** The code moves from id dispatch to rule dispatch across ~1,000 lines
   of `item_logic.gd` and `bot.gd`. *Mitigation:* the step-0 golden fingerprints and replays, compared on every PR.
2. **Primitive granularity limits "new weapons".**
   - After 4a a pack can only *recombine* the 51 item rules and 50 secondaries, with new numbers.
   - Genuinely new weapon mechanics still need a binary update. Over time, generic composable primitives widen what
     packs can do: trigger (`on_pair`, `on_kill`, `turn_n`…) × condition × effect (`flat_damage`, `mult`, `poison`,
     `block`, `heal`, `bank_reroll`, `splash`), with per-fight use caps.
   - The trade-off: more expressiveness means more test surface and a DSL that must stay non-Turing-complete to remain
     clearly "data" for store policy.
3. **Save corruption from missing packs.** A live risk today (§5). Must land first.
4. **Determinism across pack sets.**
   - Same-seed comparisons, sims, balance baselines and any future daily or leaderboard are invalid unless the
     content set is pinned (`fp`).
   - Also, `hash()` of arrays is engine-version-dependent in principle. It is stable for identical inputs within one
     engine version, so re-baseline goldens on engine bumps.
5. **Balance and AUTO quality.**
   - The player-facing AUTO bot values content by id (`bot.gd:8-27,403-417`, `bot_meta.gd`). Pack content needs `ai`
     hints (`{score, cat}`), and the CombatModel must model rules, not items. Otherwise AUTO under-values new items.
   - The per-pack sim guard catches regressions.
6. **Code in "data" packs.**
   - Scene PCKs can embed GDScript (verified). CI byte-scan + signed manifest + `replace_files=false` + path allowlist
     are mandatory.
   - Never accept `.tres`/`.tscn`/ConfigFile/`str_to_var` from packs (all verified to execute code).
7. **App Store / Play.**
   - Data referencing existing primitives is fine. New features activated remotely, or dark-shipped primitives, can
     trip Apple 2.3.1/2.5.2 review, so ship new primitives with release notes and a base use.
   - If packs are **sold**, IAP rules apply (Apple 3.1.1; Play Billing).
8. **Engine or format coupling.** JSON defs are engine-agnostic, but asset PCKs are engine-bound (streaming doc §12). A
   content pack whose art is not rebuilt for a new engine becomes "unavailable". Rules still load, and presentation falls
   back.
9. **Performance.** Negligible for definitions: ~3 ms desktop to parse everything today, maybe 10–30 ms on low-end
   mobile. Web: definitions are tiny, so assets dominate.
10. **Test brittleness.** Pinned counts (`test_armory.gd:66,75`) and literal-id tests will fight packs until they are split
    into fixture-based engine tests plus base-content snapshots.
11. **Localization debt.** Adding packs before string keys exist multiplies the later i18n work. Require keys for all new
    pack text from day one.
12. **Scope creep in dressing.** A declarative dressing DSL can balloon. Start with `{"kit": <existing>}` reuse and a
    small spec (scatter + set-piece placements) proven on one biome.

---

## Appendix A: security experiments (Godot 4.7.2, scratch project outside the repo)

Location: a throwaway scratch project (not kept). The script is `run.gd`, and the output is shown verbatim below.

| Test | Result |
|---|---|
| `load("res://evil.tres")` with `[sub_resource type="GDScript"]` whose source prints in `_static_init`/`_init` | **Printed `EVIL_TRES_STATIC_INIT_RAN` and `EVIL_TRES_INIT_RAN`**: code runs on load |
| `.tres` with `[ext_resource type="Script" path="user://dropped.gd"]` (the file was written at runtime, i.e. "downloaded") | **Printed `USER_DROPPED_SCRIPT_RAN`**: arbitrary script paths including `user://` are honoured |
| `ConfigFile.load()` of `look=Resource("res://payload.gd")`, `obj=Object(RefCounted,"script":Resource(...))` | **Printed `PAYLOAD_STATIC_INIT_RAN`, `PAYLOAD_INIT_RAN`**; `get_value` returned a GDScript and an object |
| `str_to_var('Object(RefCounted,"script":Resource("res://payload.gd"))')` | **Printed `PAYLOAD_INIT_RAN`**, returned an object |
| `JSON.parse_string('{"zeta":1,"alpha":2,"mid":{"b":3,"a":4},…}')` | keys in file order `["zeta","alpha","mid",…]`; numbers are `TYPE_FLOAT`; the string `"Object(RefCounted)"` stays a String |
| `bytes_to_var(var_to_bytes_with_objects(obj))` | `ERR_UNAUTHORIZED` ("!p_allow_objects"), returns null: safe |
| `ResourceLoader.get_dependencies` on `.tres` with embedded GDScript / binary `.scn` with an embedded script | `[]` for both (it does **not** reveal embedded scripts); the `.scn` bytes **do** contain `GDScript`, so a byte scan works |

## Appendix B: content-as-JSON feasibility (real data)

Location: a throwaway scratch project (not kept). It uses a copy of `core/` and `dump.gd`.

I dumped these to a single JSON document:

- `HeroDefs.DATA/IDS`, `EnemyDefs.ENEMIES/MINIBOSSES/BOSSES`, `BiomeDefs.DEFS/TIERS`;
- `ItemDefs.ITEMS/IDS/VARIANTS/FEATS/KITS`, `PetDefs`, `PotionDefs`, `DiceKinds`, `Runes`, `AffixDefs.DATA/BIOME`, `Passives`, `EventDefs`;
- `SkinDefs.LOOKS`, `MinigameDefs.DEFS/CALIBRATION`, `UnlockDefs.MILESTONES/PACKS/UPGRADES/ASCENSION`, `ShopDefs`, `Combo.TABLE`.

| Measure | Value |
|---|---|
| Non-JSON-typed values found | **0** |
| Pretty JSON | 110,381 bytes |
| Compact JSON | 77,536 bytes |
| gzip of pretty | **21,946 bytes** |
| `JSON.parse_string` (compact), headless desktop | **3.25 ms** per load |
| `var_to_bytes` binary cache | 130,952 bytes, 2.17 ms decode (not worth it) |

For comparison, the GDScript sources of `core/content/*.gd` total 168 KB, or 56 KB gzipped (they include code and comments).

## Appendix C: quick index of id hard-wiring (rules layer)

- **Item ids / variant ids:**
  - `core/item_logic.gd`: 51 + 51 distinct.
  - `core/bot.gd:1280-1330`: 29 refs. `core/meta/meta_run.gd:57-73,124-127`.
  - `core/content/items.gd:547,629,705,710`. `core/game_flow.gd:348,538,544` (`ItemLogic.ev` by id).
- **Passive ids:** 32 `has_passive("…")` in `core/combat.gd`, `core/game_flow.gd`, `core/run_state.gd`.
- **Pet ids:** `core/meta/pet_logic.gd:39,62,84,88-240,278,285` (plus `core/item_logic.gd:745` for skeleton kills). `core/game_flow.gd:152,473,476,490,498,519,1002,1061,1605`.
  `core/combat.gd:676,803,843`. `core/bot_meta.gd:274`.
- **Rune ids:** `core/combat.gd:415-427,623-660`. `core/content/balance.gd:59`. `core/class_logic.gd:77`.
  `core/item_logic.gd:197`. `core/meta/pet_logic.gd:213,297,306` (indices).
- **Potion ids:** `core/game_flow.gd:1675-1700`.
- **Event ids:** `core/game_flow.gd:1244-1382`.
- **Biome ids:** `core/game_flow.gd:488,512,690,1376-1381`. `core/bot.gd:2326,2333`. `core/combat.gd:1131`.
  `core/meta/profile.gd:422-428`. `core/content/unlocks.gd:25,47,324`. `core/content/affixes.gd:41-55`.
- **Enemy/boss ids:** `core/combat.gd:1127,1131,1144`. `core/content/items.gd:71`. `core/content/unlocks.gd:94-95`.
  `core/run_state.gd:468-469` (legacy defaults).
- **Class ids:** `core/meta/profile.gd:425`. `core/content/unlocks.gd:24,46`. `core/content/items.gd:77-102,710`.
  "knight" fallbacks (benign).
- **Minigame ids:** `core/minigames/minigames.gd:17-30` (factory; by design).
