# 14. Rules as data: precedents from shipped games, the store-policy boundary, and a plan for Diceroll

Date: 2026-09-30. Scope: research only. Nothing in the repo was changed.
Context: Diceroll is a Godot 4.7.2 / GDScript dice roguelite board game shipping on iOS/iPadOS, Android, macOS, Windows, Linux and Web.
The plan under study is a declarative "rules as data" layer. Content entities (weapons, classes, biomes, pets, relics, runes,
enemies, bosses, events, potions) carry rules made of **triggers**, **structured conditions**, **closed-set effects**,
**targets**, **counters/resources**, **limits** and **structured arithmetic values**. The format is JsonLogic-like JSON and is
not Turing-complete. Core code interprets it, and new primitives ship in core releases.

Companion docs in this folder: `02-content-model.md` (ContentDB, JSON + schema, capabilities), `04-apple.md`
(Apple distribution, Background Assets), `11-content-patterns.md` (pack patterns, store policy for data packs).
This doc goes deeper on **how expressive the rule data can be** and **how other games did it**.

**Evidence tags.**
- **[V]**: verified against the cited page during this research. Quotes are verbatim from a fetch.
- **[S]**: secondary source (press, fan wiki, community reverse-engineering, vendor claim). The page was seen to say it, but it isn't the developer's own statement.
- **[U]**: uncertain. This covers my inference, estimates and recommendations.

---

## 0. Executive summary

1. **Nearly every successful card, ability or item game splits the work the same way.** A **closed vocabulary of
   engine primitives** is written in native code. **Content composes those primitives in data**, and a **native escape
   hatch** covers the rest. The variants:
   - Hearthstone: "tags" on entities, designers script cards in internal tools.
   - MTG Arena: a parser compiles card text into CLIPS rules. About 80% of new cards work automatically.
   - Overwatch: Statescript graphs are data assets over C++ nodes.
   - League of Legends: BlockBuilder blocks.
   - Monster Train, Wildfrost and Brotato: effect classes with parameters.
   - Unreal GAS: "data-only" Gameplay Effects plus native Executions and Components.
   - Luck be a Landlord (a Godot game): a comparisons/effects dictionary vocabulary that grew over updates.

   Games that keep content in code (Slay the Spire 1/2, Balatro) iterate fast on PC but can't ship new behaviour
   without a build.
2. **What needs a client update is consistent across precedents.**
   - A **new primitive** (trigger, effect or condition variable).
   - A **new kind of player choice or UI**. MTG Arena needed Duel Scene client work for one card.
   - **New presentation that isn't asset data.**

   Numbers, pools, compositions of existing primitives, and ability rewrites within the vocabulary ship as data:
   - Marvel Snap: biweekly "OTA"s.
   - Hearthstone: server-side patches.
   - Legends of Runeterra: a "data-only update" that activates a pre-downloaded client.
   - Supercell: content updates behind maintenance breaks.
   - Pokémon TCG Pocket: expansions shipped as data downloads.
3. **Store policy.**
   - Apple 2.5.2 bans downloaded code that "introduces or changes features or functionality".
   - DPLA §3.3.1(B) (updated 2026-08-18) *permits* downloaded **interpreted code** as long as it (a) doesn't change
     the app's primary purpose, (b) doesn't bypass OS security, and (c) doesn't create a storefront.
   - Google Play exempts code running in "a virtual machine or an interpreter" with indirect API access, but
     runtime-loaded interpreted code "must not allow potential violations of Google Play policies".
   - Microsoft Store 10.2.2 forbids using dynamic code to "fundamentally change or extend its described functionality".
   - Enforcement history goes after **runtime patching of native code** (JSPatch/Rollout, 2017), **bait-and-switch or
     hidden switches** (2.3.1), and, in 2026, **apps that run arbitrary generated software** (Replit, Vibecode).
     JS OTA (CodePush, EAS Update) is tolerated within the "fixes and improvements within advertised purpose" reading.
4. **A practical line for Diceroll.**
   - **Clearly data:** a closed-set, non-Turing-complete rule tree that references only whitelisted primitives. It
     evaluates in bounded time, has no I/O and no reflection, and can only express game content within the advertised
     game. That includes arithmetic and comparisons over named variables. It is materially *narrower* than the JS OTA
     that Apple tolerates.
   - **Grey:** a string-parsed formula language, persistent state machines in data, data-defined macros/functions,
     large "new mode" features assembled remotely, and remotely activating dormant mechanics without disclosure.
   - **Clearly code:** downloaded GDScript; `.tres`/`.tscn`/`.res`/PCK files that can embed scripts; GDExtension/WASM/Lua/JS
     runtimes executing downloaded programs; Godot's `Expression` on downloaded strings; any op that calls methods by
     name, loads paths, does I/O, or touches purchases.
5. **Dormant mechanics are OK if disclosed.** Shipping primitives ahead of the content that uses them is defensible
   when the **core release's Review Notes** describe the new mechanics "with specificity" and say that seasonal content
   using them arrives as data. The mechanic must also be **accessible for review**. The simplest way is to ship at least
   one base-game item that uses each new primitive. Guideline 2.3.1(a) literally requires both. Residual risk is low
   but non-zero **[U]**. The literal text of DPLA §3.3.1(C), "may not provide, unlock or enable additional features or
   functionality through distribution mechanisms other than the App Store", is the clause to keep in mind. Its usual
   reading targets unlock keys and outside sales, not content data **[U]**.
6. **Top recommendations** (§3).
   - Rules as **JSON ASTs** (not strings) validated by **JSON Schema** and a semantic linter.
   - A versioned **op registry** (`op@version`) that publishes capabilities.
   - Content declares `requires`, computed by CI.
   - A **pure, deterministic interpreter**: integer math, named RNG streams, stable ordering, cascade depth and budget
     limits, re-entrancy guards.
   - **Generated rules text.**
   - **Golden replays** and **grammar-based fuzzing**.
   - **Bot-driven balance bands** (the repo already has `core/bot.gd`, `core/rng.gd` and `tests/fixtures`).
   - An **in-game rule trace**.
   - Expressiveness in **phases**: parametric families first, then trigger→condition→effect lists, then values and
     counters, then bounded collection ops and delayed effects, and only much later custom events.

---

## 1. Precedents

### 1.1 Summary table

| Game / system | How abilities are defined | Expressiveness of the data | What needs a client/code update | Content/hotfix speed | Evidence |
|---|---|---|---|---|---|
| **Hearthstone** (Blizzard, Unity, server-authoritative) | Entities are "a key-value store of properties … 'tags'". Designers do "scripting and implementing cards using internal tools". Engineers "build gameplay systems for new cards and their associated mechanics, utilizing C# and C++". | High inside the internal scripting system, which isn't publicly documented. Card logic runs on the server. | New mechanics need engineers. Client *display* data can lag server logic. | Same-day **server-side patches** for balance and bugs, sometimes with client text stale until the next client patch. | [V] HearthSim protocol; [V] job postings; [V] 30.2.1 patch notes |
| **MTG Arena** (Wizards) | **GRE** (C++ plus **CLIPS** rules). The **GRP** (Python) "takes raw English rules text … and converts them into one or more CLIPS rules". | Very high: a production rule system. | ~20% of new cards need GRP/GRE work. New choice UIs need client ("Duel Scene") work. Sets ship with numbered client patches. | Per set, with a client patch. | [V] Wizards dev article; [V] patch notes |
| **Legends of Runeterra** (Riot) | "Almost all code … C#. Designers are able to use Python to create scripted content such as cards and quests." Content authored in Riot Game Data Server with Layers. | Scripted (Python) on top of a C# engine. | Anything not expressible in existing scripting or engine systems. | Biweekly: client-only deploy on Tuesday, then "a **data-only update** that enables the new changes" on Wednesday. | [V] Riot tech blog; [S] Riot patch notes quoted by Out of Games |
| **League of Legends** (Riot) | Designers use **BlockBuilder**: "stringing together blocks … distance between points, spawning minions, dealing damage … script flow control", stored as Lua tables. | High (flow control). "400,000 lines of script". | "We average a new Building Block every ~3–4 days." | Biweekly client patches. | [V] Riot "Taxonomy of Tech Debt" |
| **Overwatch** (Blizzard) | **Statescript**: "a proprietary visual scripting language" of graphs. Graph assets are "Structured Data (stu)". Each node is a C++ `StatescriptState` class. | High: state machines, variables, subgraphs, imperative and declarative styles. | New node types (C++). "New heroes can quickly be taken from prototype to shippable with **little to no new code**." | Client patches. | [V] GDC Vault abstract; [V] talk slides (DocsLib copy) |
| **Marvel Snap** (Second Dinner, Unity) | Not public **[U]**. Balance ships as **OTA**: "we can change the game without a big download". OTAs rewrite abilities (e.g. "Moveable Once. When this moves … afflict an enemy card there with -3 Power"). | At least parameters plus ability rewrites within the existing vocabulary. | New cards/art via monthly builds with Addressables and Unity CCD ("a new version … every month"). | Balance OTAs about every 2 weeks. New content weekly. | [V] marvelsnap.com; [V] Unity case study |
| **Supercell** (Clash Royale, Brawl Stars, Clash of Clans) | `csv_logic/*.csv` (abilities, characters, spells…). Clients receive a content fingerprint and download assets from a CDN. | Parameters and tables over hard-coded behaviours. | New mechanics/cards → app update. | Balance "live after a maintenance break". | [V] Supercell blog; [S] community asset tools |
| **Pokémon TCG Pocket** | Not public. | — | Some expansions needed "no app update", only additional data (about 300 MB). Others needed large app updates (e.g. a Unity upgrade). | Per expansion. | [S] fan site quoting official notices |
| **Monster Train** (Shiny Shoe, Unity) | `CardData` holds a list of `CardEffectData`. Each names a C# `CardEffectState` class (`"effectStateName": "CardEffectDamage"`) plus generic params (`paramInt`, `paramStatusEffects`, `targetMode`…). `CharacterTriggerData` holds a trigger enum and effects. | Medium-high: trigger → effect list, target modes, filters, multipliers, "test" gates. | New effect/trigger classes (C#). | Client patches. | [V] Trainworks wikis; [V] MonsterTrainGameData dumps; [S] Trainworks-Reloaded docs |
| **Wildfrost** (Deadpan/Gaziter, Unity) | Cards compose `StatusEffectData` subclasses, e.g. `StatusEffectApplyXOnKill` with `effectToApply` and `applyToFlags`, plus traits, TargetConstraints and "ScriptableAmounts". | Medium-high: generic "Apply X on Y" templates. | New `StatusEffectData` classes. | Client patches. | [S] community modding docs |
| **Slay the Spire 1** | Java class per card. `use()` enqueues actions (`DamageAction`…). | Full code. | Everything. | Steam patches. | [V] BaseMod wiki |
| **Slay the Spire 2** (Godot + C#) | "800+ concrete card implementations" as C# classes overriding hooks. A `Hook` dispatcher with "~100+" methods. | Full code. | Everything. | Steam patches (Early Access). | [S] decompilation-based wikis |
| **Balatro** (LÖVE/Lua) | Data table `P_CENTERS` (config numbers) plus a `Card:calculate_joker(context)` "god function" (about 1,770 lines, per community analysis) that branches on joker **name**. | Full code, with parametric families (Jolly/Zany/Mad Joker share logic, differing config). | Everything behavioural. | Patches. | [S] decompiled source mirrors, community analysis |
| **Dicey Dungeons** (Terry Cavanagh) | `equipment.csv` rows with script columns (`Script: On Execute`, `Script: On Dodge`…) holding **hscript** (Haxe). Tags column. | Full scripting in data files. | Core API additions. | PC patches. | [V] official mod migration guide; [V] v0.16 post |
| **Luck be a Landlord** (TrampolineTales, **Godot**) | Mod script files set data fields including `effects = [{"comparisons": [{"a": "destroyed", "b": true}], "value_to_change": "value_bonus", "diff": 5}]`. | Medium: comparisons (with `not`), a closed set of variables, `value_to_change`, `diff`, effect types. | The vocabulary grew in updates: "Added `not` for comparison dictionaries", "Added coins for comparisons", etc. | Patches. | [V] developer patch notes; [S] fan wiki example |
| **Brotato** (Blobfish, **Godot**) | Items are `.tres` resources with `effects` arrays. `effect.gd` holds `key` (stat), `value`, `custom_key` (special behaviour), `text_key`. | Low-medium: stat keys plus about 100 effect keys. | New effect keys. Patch 0.8 removed 16 effect scripts into a generic `effect.gd` and added 20 keys. | Patches. | [S] Brotato wiki modding pages; [V] ModLoader migration doc |
| **Unreal GAS** (engine framework) | Gameplay Effects are immutable "data-only" assets. Native escape hatches: **Executions** "for complex equations" and **GE Components** ("limits the implementation … to native code"). | Medium: modifiers, tags, durations, stacking. | New Executions/Components. | — | [V] Epic docs |
| **China hot-update stack** (xLua, ILRuntime, HybridCLR; HoYoverse games) | Downloaded Lua or C# IL, interpreted. HybridCLR claims "over a thousand" titles on App Store/Google Play and "nearly 100" of the iOS top-500 free games. | Turing-complete code. | Almost nothing; native code only. | Minutes (anecdotal: "17 minutes"). | [V] xLua docs; [S] HybridCLR vendor claims; [S] Genshin Lua decompiler repo |

### 1.2 Notes per precedent

**Hearthstone.**
- The public model is a **bucket of entities whose state is integer "tags"**: "Almost every single property on every
  single entity is represented as a tag: A GameTag key, with an integer value." [V] https://hearthsim.info/docs/gamestate-protocol/
- Actions nest as `BLOCK_START`/`BLOCK_END` of types POWER, TRIGGER, DEATHS… "Blocks may be nested, in cases where
  actions trigger other actions."
- Job postings say designers do "Scripting and implementing cards using internal tools" and engineers "prototype and
  build gameplay systems for new cards and their associated mechanics, utilizing C# and C++ within the Unity
  environment" [V] https://gamejobs.co/Game-Designer-Card-Design-Hearthstone-Irvine-CA-at-Blizzard-Entertainment,
  https://gamejobs.co/Senior-Software-Engineer-Gameplay-Hearthstone-Temporary-at-Blizzard-Entertainment. That is the
  two-tier split Diceroll wants: designers compose, engineers add mechanics.
- **Server-side hotfix lesson.** Patch 30.2.1 was "a server-side patch".
  - Dev comment: "Because this is only a server-side change, these cost changes won't show up when you hover over the
    Trinkets, but they WILL reflect in the gameplay … we'll clean that up in our next client patch." [V]
    https://us.forums.blizzard.com/en/hearthstone/t/3021-patch-notes/133884/1
  - For Diceroll, all logic runs on the client, so text and logic must come from **the same data**. Otherwise tooltips
    drift from behaviour.
- **Trigger-cascade lesson.** Blizzard's 22.2 known-issues post said "the combination of Tentacle of C'Thun … and
  Titanic Guardian … could cause an infinite loop that resulted in a game crash. After today's hotfix, neither Buddy
  will trigger off the other gaining stats." [S] (Blizzard CM post mirrored at
  https://outof.games/devtracker/hearthstone/hearthstone-forums-us/hearthstone-forums-us/20526)

**MTG Arena.** This is the best primary source on vocabulary economics. From Alex Werner's article
([V] https://magic.wizards.com/en/news/mtg-arena/on-whiteboards-naps-and-living-breakthrough):
- The GRE is "written in a combination of C++ and a language called CLIPS". CLIPS rules "make all the specific
  abilities of individual Magic cards work".
- The GRP "takes raw English rules text of Magic cards and converts them into one or more CLIPS rules. It's what allows
  **80% or so of newly written Magic cards to just work** in MTG Arena automatically. It's also what we have to update,
  modify, and improve to get the other 20% to work."
- One new card (Living Breakthrough) needed new GRP code, several rule rewrites for edge cases (X spells, cast without
  paying, object identity), and a **client UI change**. "Have the player pick an X value … and a list of values that
  are specifically not allowed" needed the Duel Scene team.
- **Generalize primitives:** "almost none of the work we ever do is just for one card … it was to support cards which
  forbid a player from casting a spell with a specific mana value … it should just work straight out of the card file."
- Sets ship with client patches that include new UI affordances. For example, 2026.58.0 added "Prepared spells … are
  now indicated by a spellbook graphic" [V] https://mtgarena-support.wizards.com/hc/en-us/articles/48215493589396-Patch-Notes-2026-58-0.
- The 2017 marketing claim of "sophisticated machine learning that can read any card" [V]
  https://magic.wizards.com/en/news/feature/everything-you-need-know-about-magic-gathering-arena-2017-09-07 is really
  a parser. Magic's strict **templating** is what makes text→rules feasible [S] https://hudecekpetr.cz/a-formal-grammar-for-magic-the-gathering/.

**Legends of Runeterra.**
- Riot says "Almost all code — both client and server — is written in C#… Designers are able to use Python to create
  scripted content such as cards and quests." [V] https://www.riotgames.com/en/news/bringing-features-life-legends-runeterra
- Content lives in Riot Game Data Server. **Layers** keep unfinished content out of live builds while it stays
  playtestable. Any designer can deploy their own environment "no engineer required".
- Patch mechanics from 1.2 on:
  - Tuesday: deploy a client "client-only, with no visible changes".
  - Wednesday: "push a **data-only update that enables the new changes** … We'll also force-update everyone" [S]
    (Riot patch notes quoted at https://outof.games/news/1300-legends-of-runeterra-patches-move-away-from-treating-mobile-players-like-second-class-citizens-unlike-its-competitor-hearthstone/).
  - **This is exactly the "ship dormant primitives, activate by data" pattern**, used to sync mobile store latency.

**League of Legends.** Brian Bossé / Riot, "A Taxonomy of Tech Debt" [V] https://www.riotgames.com/en/news/taxonomy-tech-debt:
- BlockBuilder: "the set of operations designers choose from is varied but limited, and the parameters for each
  operation are constrained". The blocks were stored "as arrays and tables in the powerful … entirely-too-complex-for-this-purpose
  lua language". **Lesson: store the rule AST in a simple, constrained format that matches the data.**
- "We average a new Building Block every ~3–4 days". That is the rate of vocabulary growth for a live game with about
  140 champions.
- **Data debt:** a parameter-naming bug doubled values. "Any of 400,000 lines of script in *LoL* might have any of their
  numerical parameters being doubled by this bug … those scripts are 'behaving correctly' in that the game is balanced
  and tuned around those potentially doubled values."
  - The fix was toggleable on live.
  - Data debt is "extraordinarily contagious": copy/paste of data, "data is rarely subjected to technical review",
    fixes need human verification.
  - Determinism helped: "letting us confirm that the server produces the same results before and after a change."
- "The Future of League's Engine" (2019) says League sits "uncomfortably" between engine-heavy (script as configuration)
  and engine-light (script as programming), with "high complexity everywhere". It recommends moving **engine-heavy**
  [V] https://www.riotgames.com/en/news/future-leagues-engine. **Diceroll's plan is deliberately engine-heavy.**

**Overwatch Statescript.** Is it data or code? **Both.**
- GDC 2017 (Dan Reed): "a proprietary visual scripting language called Statescript to execute the high-level state
  machines used throughout the game, including the logic driving hero weapons and abilities … an ever-growing library
  of code-backed building blocks … new heroes can quickly be taken from prototype to shippable with little to no new
  code." [V] https://gdcvault.com/play/1024653/Networking-Scripted-Weapons-and-Abilities, [V] https://www.gamedeveloper.com/design/attend-gdc-and-see-how-blizzard-scripts-i-overwatch-i-s-weapons-and-powers
- Implementation from the slides [V] https://docslib.org/doc/474379/networking-scripted-weapons-and-abilities-in-overwatch:
  - Graph assets are "defined by Structured Data (stu)". Each node type has a `.stu` data schema and a C++ runtime class
    (e.g. `StatescriptStateWait` with `m_timeout`).
  - Variables live in "VarBags". Graphs support "Imperative … and Declarative … logic styles" and subgraphs.
  - Scripts are server-authoritative, with automatic prediction and rollback.
- So Statescript is **data interpreted by native nodes**, but the data can express general state machines. Under an
  App Store lens it would sit at the grey edge. It wasn't downloaded to clients outside patches, as far as we know **[U]**.

**Marvel Snap.**
- The first OTA post: "Welcome to the new world of regular balance updates using OTA! OTA stands for 'Over-the-Air,'
  which means we can change the game without a big download." [V] https://marvelsnap.com/april-27th-ota-balance-updates/
- 2026 OTAs rewrite ability text, not just numbers. From 2026-07-16 [V] https://marvelsnap.com/balance-update-july-16-2026/:
  - "[Old] 5/9 – The first time this moves to any location, destroy an enemy card there. [New] 4/5 – Moveable Once.
    When this moves to a location, afflict an enemy card there with -3 Power".
  - "the instance of *card* has been turned into *character*" on nine cards.
  - So the ability vocabulary (Moveable, afflict, character filters) is data-composable.
- The Unity case study [V] https://unity.com/resources/marvel-snap:
  - "200+ base cards and 1,000+ collectible variants, with new content added weekly".
  - Addressables with "local and remote tags". Mobile loads remote assets at runtime.
  - "Second Dinner launches a new version of MARVEL SNAP every month using Unity Cloud Content Delivery".
- How card logic is implemented isn't public **[U]**.

**Supercell.**
- Official posts say balance changes "WILL BE LIVE AFTER A MAINTENANCE BREAK" [V]
  https://supercell.com/en/games/clashroyale/blog/release-notes/january-balance-changes/
- Community tools show the mechanism [S] https://github.com/123456abcdef/sc-assets-download,
  https://github.com/Draggie306/DraggieTools, https://github.com/smlbiobot/cr-csv/commit/f68c68238d12c286d46381e0fbfc1f18f472036f:
  - The client sends `contentHash` in `ClientHello`.
  - The server replies with a `Fingerprint` message and asset URLs.
  - The client downloads changed files, including `csv_logic/*.csv` (abilities, characters, spells, globals…), from a
    CDN keyed by SHA.
  - This is "logic tables as data". New *kinds* of behaviour ship in app updates.

**Monster Train.** This is the clearest **trigger → effect-list with native effect classes** design
([V] https://github.com/brandonandzeus/Trainworks2/wiki/Modifying-an-Existing-Card,
https://github.com/KittenAqua/TrainworksModdingTools/wiki/Custom-Spell-Cards, https://github.com/brandonandzeus/MonsterTrainGameData):
- Frozen Lance is `{"effectStateName":"CardEffectDamage","targetMode":2,"paramInt":6}`.
- Characters have triggers (e.g. `OnHit` → "Revenge") whose effect lists reuse the same `CardEffectData`.
- Lessons:
  1. **Generic param slots are a smell.** "Card effects all use their parameters differently; some effects might not use
     `ParamInt`". The community schema lists `param_int`, `param_int_2`, `param_int_3`… and a table of deprecated aliases
     (including a typo field `supress_pyre_room_focus`) [S] https://deepwiki.com/Monster-Train-2-Modding-Group/Trainworks-Reloaded/4.4-card-effect-system.
     **Use named, typed, per-op parameters.**
  2. **Preview mode is a real requirement.** One effect "is presumed to be bugged … since the state of the Characters
     Triggers isn't cached for combat previews … it will duplicate the triggers" [V] https://github.com/brandonandzeus/Trainworks2/wiki/Base-Game-CardEffects.
     Rules must run safely on a cloned state for previews and AI.
  3. **Generated text:** descriptions use templates like `"Deal [effect0.power] damage"`.

**Wildfrost.** Status effects are generic templates:
- `StatusEffectApplyXOnKill` with `effectToApply = "Increase Attack"` and `applyToFlags = Self`.
- The text template is "Gain {0} on kill" with `<keyword=attack>` inserts.
- An `eventPriority` field "influences the order in which effects activate".
- [S] https://github.com/rspforhp/WildfrostModdingDocumentation/wiki/StatusEffectDataBuilder
- "Apply X on Y" is the most reusable composition shape in these games.

**Slay the Spire 1 and 2.**
- StS1 cards are Java classes whose `use()` enqueues actions [V] https://github.com/daviscook477/BaseMod/wiki/Custom-Cards.
- StS2 moved to **Godot 4 + C#** ("all game logic lives in a C#/.NET 8 DLL") [S] https://github.com/ptrlrd/spire-codex/blob/main/README.md.
  - Every card, relic and power is a class inheriting `AbstractModel`, registered by a source generator into `ModelDb`.
  - About 100+ `Hook` methods (OnCardPlayed, ModifyDamageAdditive…) [S] https://deepwiki.com/hanmi255/STS2SourceCode/2.2-abstractmodel-and-hook-event-system.
- **Lesson:** even code-first games converge on a **hook/trigger taxonomy** plus a **command queue**. That taxonomy is
  what Diceroll's trigger vocabulary should copy. The code-first choice is what Diceroll can't make on mobile.

**Balatro.**
- `P_CENTERS` holds config numbers. Behaviour is one `calculate_joker(context)` branching on names, dispatched by
  **context** flags (`joker_main`, `individual`, `end_of_round`, `selling_self`…) [S] https://tulip4attoo.github.io/balatro-p3/,
  https://github-wiki-see.page/m/Pheubel/Steamodded/wiki/Guide-%E2%80%90-Joker-Calculation.
- Lessons:
  - **Parametric families.** Jolly, Zany, Mad, Crazy and Droll Joker are one behaviour with different `t_mult`/`type`
    config. Many "new" items are new parameters on an old family.
  - **Contexts are an ordered pipeline.** Upgrade jokers go first, per-card effects next, then global effects.
    Ordering is part of the rules.

**Dicey Dungeons** (a dice game, so especially relevant).
- Equipment rows in `equipment.csv` carry script hooks: `Script: On Execute`, a new `Script: On Dodge`, `Before Start
  Turn`, `On Any Equipment Use`…
- A `Tags` column replaced four boolean columns and was "intended as a future-proof way to add features to the modding
  api without breaking backwards compatibility" [V] https://github.com/TerryCavanagh/diceydungeons.com/blob/master/modmigrationguide.md.
- Version 0.16 "moves a huge amount of new things into scripts and data files … uses hscript powered scripting" [V]
  https://diceydungeons.com/blog/2019/02/27/version-16.html
- AI pitfall: "the AI will not be able to correctly handle executing skills. You should wrap … in `if(!simulation)`"
  [V] https://mods.diceydungeons.com/doku.php?id=doingthingsthehardway. Opaque scripts break AI look-ahead.
- A fan port (Dicey Wastelands, by TheMysticSword and AgentCucco) instead used a **closed command DSL**:
  - Commands: `attack:4|inflictself:shock`, `var`/`varadd`, `callifelse`.
  - Special args: `d` (dice total), `rd`, `@var`, `$status`, `hp`, `targethp`.
  - [S] https://itch.io/t/444008/adding-your-own-equipment-enemies-characters. It is a near-exact precedent for
    Diceroll's non-Turing-complete design, and shows how far a small command set goes for dice equipment.

**Luck be a Landlord (Godot).** This is the closest engine and genre precedent for a **declarative effect dictionary**:
- `effects = [{"comparisons": [{"a": "destroyed", "b": true}], "value_to_change": "value_bonus", "diff": 5}]` [S]
  https://wikiwiki.jp/yuruku_lbal/Mod%E5%B0%8E%E5%85%A5%E3%83%BB%E4%BD%9C%E6%88%90
- The "Magnificent Modding Update" (2023–24) added dozens of vocabulary items [V] https://blog.trampolinetales.com/the-magnificent-modding-update-patch-notes/:
  - "Added `not` for comparison dictionaries".
  - "Added coins / reroll_tokens / rent_due / spins_left … for comparisons".
  - "Added rent_paid / symbol_added / item_added for effect_type".
- It also fixed interpreter crashes on malformed data: "the game would crash if … an effect had comparison array
  without an `a` variable".
- **Lessons:** (a) the vocabulary grows steadily in core releases, (b) validate data before it reaches the interpreter,
  (c) a sandbox save lets authors set up the board to test an item [S].

**Brotato (Godot).**
- Items are `.tres` with `effects` whose `key` is a stat or an effect key. `custom_key` selects special behaviour
  (e.g. Anvil's `upgrade_random_weapon`) [S] https://brotato.wiki.spellsandguns.com/Modding_Effects.
- In 0.8 the developer **consolidated 16 bespoke effect scripts into one generic `effect.gd`** and added 20 new effect
  keys [V] https://github.com/BrotatoMods/Brotato-ModLoader/blob/main/Mod-Migration-v0.8.0.0.md.
- **Lesson:** expect to refactor the vocabulary as it grows. Version your ops so old content keeps working.
- Also note that Brotato's `.tres` items are fine *in the shipped PCK*, but `.tres` can't be the format for
  **downloaded** content (see §2.4).

**Unreal GAS** is the engine-framework version of the plan [V] https://dev.epicgames.com/documentation/en-us/unreal-engine/gameplay-effects-for-the-gameplay-ability-system-in-unreal-engine:
- "Gameplay Effects are assets and therefore are immutable at runtime." "GEComponents live within a Gameplay Effect, a
  data-only Blueprint asset."
- Escape hatches: "Executions … are particularly useful for defining complex equations that aren't adequately covered by
  Modifiers", and custom GE Components, which "limits the implementation of Gameplay Effect Components to native code."

**Unity Addressables and ScriptableObject data.**
- Remote bundles carry data and assets, **not code**. Serialized objects reference script classes that "still need to be
  available" in the player. In the words of a Unity forum regular: "You can't make compiled code into an assetbundle …
  write your code in a data-oriented pattern so you don't need to update the actual code, just update the values that
  the code consumes." [S] https://discussions.unity.com/t/addressable-to-latest-c-files/797304,
  https://discussions.unity.com/t/how-can-i-re-attach-scripts-to-addressables-between-projects/1635931/1
- Marvel Snap uses exactly this (above). The Godot analogue: JSON data plus imported assets in PCKs, with **no scripts**
  in downloaded packs (see `02-content-model.md` appendix A).

**China hot-update frameworks and HoYoverse.**
- xLua can "use xLua's code logic to replace the original C# logic" at method granularity
  (`xlua.hotfix(CS.HotfixCalc, 'Add', function(self, a, b) return a + b end)`) [V] https://github.com/Tencent/xLua/blob/master/Assets/XLua/Doc/Hotfix_EN.md.
- HybridCLR interprets downloaded C# IL on IL2CPP and claims "over a thousand" titles live on App Store/Google Play [S]
  https://github.com/focus-creative-games/hybridclr.
- Genshin Impact ships compiled Lua 5.3 with modified opcodes per a community decompiler [S]
  https://github.com/Project-x64/genshin-luadec.
- Tencent's **InjectFix** was deliberately limited to *fixing existing functions*. A Chinese engineer explains that
  limit "更符合苹果的热更新条款" ("fits Apple's hot-update terms better") [S] https://www.cnblogs.com/heweiwei/p/12554627.html.
- **How do they pass review?** No official statement exists **[U]**. The observable reality:
  - Apple doesn't ban interpreters (DPLA §3.3.1(B)).
  - Machine review sometimes flags them. An xLua user got a Guideline 2.1 "Information Needed" letter listing
    "2.3.0 … significant concept changes after approval" and "2.3.1 … hidden 'switches'". Removing xLua "重新提审就过了"
    ("passed on resubmission"). Another commenter saw no correlation [S] https://github.com/Tencent/xLua/issues/610.
  - Some studios use outright evasion: an "AB包" (A/B build) that shows reviewers a different game, then switches
    [S] https://forum.cocos.org/t/topic/175137. That is exactly the 2.3.1 bait-and-switch Apple terminates accounts for.
  - **Tolerance of the practice isn't permission.** Diceroll shouldn't imitate the Turing-complete end of this.

**Not covered with solid sources:** Backpack Hero (no public data/scripting docs found), and the internals of Pokémon
TCG Live/Pocket and Marvel Snap card logic **[U]**.

### 1.3 Cross-cutting design lessons

1. **Vocabulary size and growth.**
   - League adds a building block every ~3–4 days on a mature game [V].
   - MTG Arena needs parser/engine work on ~20% of new cards [V].
   - Overwatch heroes need "little to no new code" [V].
   - LBaL and Brotato added about 20–40 vocabulary items in single updates [V/S].
   - Expect Diceroll's vocabulary to start at **about 25 triggers, 40–60 effects, 30–50 condition variables and about 15
     target selectors**, and grow by a few items per core release **[U]**.
2. **Composition patterns that recur.**
   - (a) **Effect lists** (Monster Train, GAS, Brotato).
   - (b) **Trigger → [condition] → effect list** (Monster Train triggers, Wildfrost "Apply X on Y", LBaL comparisons →
     value change, Hearthstone TRIGGER blocks).
   - (c) **Context-ordered pipelines** (Balatro contexts, StS2 hooks such as `ModifyDamageAdditive` then
     `ModifyDamageMultiplicative`).
   - (d) **State machines / behaviour graphs** (Statescript, BlockBuilder flow control).
   - (e) **Production rules** (CLIPS).

   Diceroll's plan is (a)+(b)+(c). Avoid (d) and (e) in downloadable data. They are where "data" becomes a general
   program, and where the policy and debugging risk concentrates.
3. **Escape hatches are native code shipped in releases** (GAS Executions/Components, Monster Train effect classes,
   Statescript nodes, Wildfrost StatusEffectData subclasses, MTGA GRP/GRE code). None of the precedents downloads
   the escape hatch to mobile. The China stack does, and that is its policy exposure.
4. **Generalize every new primitive** (MTGA: "almost none of the work we ever do is just for one card").
5. **Text must be generated from the same data** (Monster Train `[effect0.power]`, Wildfrost `{0}` inserts, Hearthstone
   30.2.1's stale tooltip) [V].
6. **New player choices need UI work.** MTGA's X-value restriction needed client work [V]. In Diceroll, a new *kind of
   prompt* ("choose a die", "choose a tile") is always a core primitive.
7. **Previews and AI need pure, simulatable rules** (Monster Train preview duplication, Dicey Dungeons `if(!simulation)`) [V].
8. **Data needs code-review discipline and determinism-based regression tests** (League data debt, 400k lines; League
   determinism "same results before and after a change") [V].
9. **Ship in two steps:** client first, data activation later (LoR's Tuesday client / Wednesday data) [S].
10. **Use named, typed params. Never use generic slots** (Monster Train `paramInt` aliases) [V/S].

---

## 2. The store-policy boundary for expressive data

### 2.1 Current texts (fetched 2026-09-30)

**Apple App Review Guidelines** (page footer "Last Updated: June 8, 2026") [V] https://developer.apple.com/app-store/review/guidelines/

- **2.5.2:** "Apps should be self-contained in their bundles, and may not read or write data outside the designated
  container area, nor may they download, install, or execute code which introduces or changes features or
  functionality of the app, including other apps. Educational apps designed to teach, develop, or allow students to
  test executable code may, in limited circumstances, download code provided that such code is not used for other
  purposes. Such apps must make the source code provided by the app completely viewable and editable by the user."
- **2.3.1(a):** "Don't include any hidden, dormant, or undocumented features in your app; your app's functionality
  should be clear to end users and App Review. All new features, functionality, and product changes must be described
  with specificity in the Notes for Review section of App Store Connect (generic descriptions will be rejected) and
  accessible for review. Similarly, marketing your app in a misleading way … is grounds for removal of your app from
  the App Store or a block from installing via alternative distribution and termination of your developer account."
  **(b):** "Egregious or repeated behavior is grounds for removal from the Apple Developer Program…"
- **4.7** (Mini apps, mini games, streaming games, chatbots, plug-ins, and game emulators): "Apps may offer certain
  software that is not embedded in the binary, specifically HTML5 and JavaScript mini apps and mini games, streaming
  games, chatbots, and plug-ins… You are responsible for all such software offered in your app…"
  - 4.7.1–4.7.5 add privacy, content filtering/reporting, IAP, "may not extend or expose native platform APIs … without
    prior permission", per-software consent, an index with universal links, and age gating.
  - **Diceroll's rule data isn't "software" in 4.7's sense**, and framing packs as "mini games" would *import* 4.7's
    obligations. Don't **[U]**.
- **4.2.3(ii):** "If your app needs to download additional resources in order to function on initial launch, disclose
  the size of the download and prompt users before doing so." [V]
- **3.1.1:** unlocking "features or functionality … game levels, access to premium content" requires IAP. "Apps may not
  use their own mechanisms to unlock content or functionality." [V]

**Apple Developer Program License Agreement** (agreement page states "Developer Program License Agreement, including its
Schedule 1 last updated August 18, 2026") [V] https://developer.apple.com/support/terms/apple-developer-program-license-agreement/

- **§3.3.1(B) Executable Code:** "Except as set forth in the next paragraph, an Application may not download or install
  executable code. Interpreted code may be downloaded to an Application but only so long as such code: (a) does not
  change the primary purpose of the Application by providing features or functionality that are inconsistent with the
  intended and advertised purpose of the Application (b) does not bypass signing, sandbox, or other security features
  of the OS; and (c) for Applications distributed on the App Store, does not create a store or storefront for other
  Applications."
  - The next paragraph covers programming-learning apps: ≤80% screen, a visible indicator, no storefront, source
    viewable and editable.
  - Formerly §3.3.2. Pre-2017 text limited interpreted code to WebKit/JavaScriptCore. A vendor history says the current
    engine-agnostic wording arrived in June 2017 [S] https://patchrelease.com/blog/what-apple-allows-ota-updates.
- **§3.3.1(C) Additional Features or Functionality:** "Without Apple's prior written approval or as permitted under
  Section 3.3.9(A) (In-App Purchase API), an Application may not provide, unlock or enable additional features or
  functionality through distribution mechanisms other than the App Store, Custom App Distribution or TestFlight."
  - Read literally, this reaches remote enabling. The common reading targets unlock keys and outside sales. Keep
    rule-data releases framed as **content for existing features** **[U]**.

**Google Play, Device and Network Abuse** [V] https://support.google.com/googleplay/android-developer/answer/9888379
- "An app distributed via Google Play may not modify, replace, or update itself using any method other than Google
  Play's update mechanism. Likewise, an app may not download executable code (such as dex, JAR, .so files) from a
  source other than Google Play. This restriction does not apply to code that runs in a virtual machine or an
  interpreter where either provides indirect access to Android APIs (such as JavaScript in a webview or browser)."
- "Apps or third-party code, like SDKs, with interpreted languages (JavaScript, Python, Lua, etc.) loaded at run time
  (for example, not packaged with the app) must not allow potential violations of Google Play policies."

**Microsoft Store Policies v7.20** (ms.date 2026-09-14), **10.2.2**: "Your product must not attempt to fundamentally change
or extend its described functionality or introduce features or functionality that are in violation of Store Policies
through any form of dynamic inclusion of code. Your product should not, for example, download a remote script and
subsequently execute that script in a manner that is not consistent with the described functionality" [V]
https://learn.microsoft.com/en-us/windows/apps/publish/store-policies

Steam, itch and Web have no comparable restriction that I found **[U]**. Web builds still run under browser CSP. Keep one
policy for all platforms, so behaviour doesn't fork per store.

### 2.2 Enforcement evidence

- **March 2017, "hot code push".** Apple's email: "Your app, extension, and/or linked framework appears to contain code
  designed explicitly with the capability to change your app's behavior or functionality after App Review approval,
  which is not in compliance with section 3.3.2 … and App Store Review Guideline 2.5.2. This code, combined with a
  remote resource, can facilitate significant changes to your app's behavior compared to when it was initially
  reviewed" [V] https://9to5mac.com/2017/03/07/apple-cracks-down-on-hot-push-code-sdks/.
  - The fuller text named "code which passes arbitrary parameters to dynamic methods such as dlopen(), dlsym(),
    respondsToSelector:, performSelector:, method_exchangeImplementations(), and running remote scripts in order to
    change app behavior or call SPI" and cited MITM risk [S]
    https://medium.com/@isaacacasanova/apple-rolls-back-rollout-io-6a9a6cd9702f, https://apple.slashdot.org/story/17/03/08/1355246/apple-begins-rejecting-apps-with-hot-code-push-feature.
  - The targets were JSPatch and Rollout.io (runtime patching of native methods). React Native bundles survived
    [S] https://bitrise.io/blog/post/what-app-stores-allow-with-ota-updates-apple-and-google-policy-explained.
- **JS OTA in 2025–2026.**
  - Expo: "EAS Update usage falls under store guidelines for downloading interpreted code" [V]
    https://expo.dev/blog/eas-update-best-practices. And "you need to follow the rules of the platforms and app
    stores … This usually means changes to your app's behavior need to be reviewed" [V] https://docs.expo.dev/eas-update/introduction.
  - Microsoft's CodePush service was retired with App Center. Self-hosted and third-party successors continue.
  - A 2026 industry summary: Apple "applies a functional test: not whether code was pushed, but whether it changed what
    the app fundamentally does". It lists bug fixes, copy, assets and "content updates via existing features" as
    allowed, and "features that change the app's core purpose" and payment-flow changes as not allowed [S]
    https://bitrise.io/blog/post/what-app-stores-allow-with-ota-updates-apple-and-google-policy-explained.
- **March 2026, vibe-coding apps.**
  - Apple blocked Replit and Vibecode updates and "pointed to App Review Guideline 2.5.2". Apple also quoted the
    DPLA's "does not change the primary purpose" [V] https://www.macrumors.com/2026/03/18/apple-blocks-updates-for-vibe-coding-apps/.
  - Heise reports Apple cited "Guideline 2.5.2 and Section 3.3.1(B)" [S] https://www.heise.de/en/news/Apple-blocks-updates-for-vibe-coding-apps-11216835.html.
  - The trigger was **running arbitrary generated apps** in-app.
- **Hidden switches.** Apple's machine-review "Information Needed" letter lists "2.3.1 - Have hidden or undocumented
  features, including hidden 'switches' that redirect to a gambling or lottery website" and "2.3.0 - Undergo
  significant concept changes after approval" [S] https://github.com/Tencent/xLua/issues/610.
- **Remote config.** Firebase's own guidance: "Don't use Remote Config to make app updates that should require a user's
  authorization" and "Don't attempt to circumvent the requirements of your app's target platform using Remote Config."
  [V] https://firebase.google.com/docs/remote-config
- **JsonLogic-style rule data.** There is no public Apple ruling on JsonLogic-like data **[U]**. By construction,
  JsonLogic "has no setters, no loops, no functions or gotos. One rule leads to one decision, with no side effects and
  deterministic computation time … We never `eval()`" [V] https://jsonlogic.com/.
  - Google's CEL is designed the same way: "CEL evaluates in linear time, is mutation free, and not Turing-complete"
    and is intended for evaluating untrusted expressions [V] https://github.com/google/cel-spec.
  - These are **strictly less powerful** than the JS bundles Apple tolerates, and they can't reach any API the binary
    doesn't expose as a primitive.

### 2.3 Analysis: is Diceroll's rule data "code"?

2.5.2 targets *code* that "introduces or changes features or functionality". §3.3.1(B) gives a safe harbour for
*interpreted code* within the advertised purpose. Apple's 2017 and 2026 enforcement targeted (1) paths to native code
or private APIs, (2) arbitrary programs (generated apps), and (3) concealment. These five tests place a given data
design **[U: my synthesis]**:

| Test | Data-like (safe) | Code-like (risky) |
|---|---|---|
| **Computational power** | Finite tree, no loops or recursion, bounded evaluation cost | Loops, recursion, user-defined functions, unbounded state machines |
| **Reach** | Only whitelisted game primitives. No I/O, network, reflection or asset loading by path | Method-by-name calls, `load(path)`, script instantiation, file or network ops |
| **Scope of change** | New *content* inside existing features (a relic, an enemy, a biome built from existing mechanics) | New *features*: new modes, menus, flows, monetization, anything outside "a dice roguelite board game" |
| **Transparency** | Mechanics disclosed in Review Notes and visible to players (generated rules text) | Dormant switches, reviewer-specific behaviour, concealed toggles |
| **Integrity** | Signed, schema-validated, fails closed | Unsigned or unauthenticated downloads (the 2017 MITM concern) |

Even under the strictest reading, where a rule interpreter counts as "interpreted code", a design that passes all five
tests sits inside §3.3.1(B)(a)–(c). It is narrower than the JS OTA that shipped apps use every day. The residual risks
are **2.3.1 (hidden or dormant features)** and **perception**: a reviewer seeing an "expression language" in marketing
or Review Notes. Describe it as "data-driven content (items, enemies, events) using the game's built-in rules", not as
"scripting" **[U]**.

### 2.4 The practical line for Diceroll

**Green: clearly data** (ship between releases on every platform):
- Numbers, curves, drop tables, prices, pools, weights, schedules (seasons, dailies), feature on/off for *content*.
- New entities composed from **existing** ops: `trigger` + `conditions` + `effects[]` + `targets` + `limits` + `counters`
  + params.
- **Structured** (JSON AST) arithmetic and comparisons over **whitelisted named variables** (`event.face`,
  `owner.hp`, `run.gold`, `self.counter.charge`):
  - add, sub, mul, floor_div, min, max, clamp, abs;
  - eq, lt, all, any, not;
  - `if(cond, a, b)`;
  - `count`/`sum`/`any`/`all` over **finite game sets** (dice in hand, enemies, adjacent tiles).
  - Evaluation is bounded by node count and depth.
- Localized text, descriptions (generated), art, audio, and meshes/textures in imported data formats.
- Enabling/disabling content ids and hotfix overrides of params.

**Amber: defensible, but constrain, document and disclose:**
- A **string** formula syntax (`"2*pips+1"`). Semantically the same as an AST, but it *looks* like code. Prefer
  compiling strings to AST in CI and shipping only the AST.
- **Persistent state machines** in data (multi-step "quests", boss phase graphs with arbitrary transitions),
  **data-defined reusable sub-rules/macros**, **custom events** that rules emit and other rules consume (a cascade
  amplifier), delayed or scheduled effects. Allow these, but keep them bounded (see §3.7) and introduce them late.
- **Activating pre-shipped dormant mechanics by data.** OK if disclosed and reviewable (§2.5).
- **Remote assembly of a new "mode"** from existing primitives (e.g. a new challenge format). Fine when it's clearly the
  same game. Mention the capability in Review Notes.
- **A/B tests of rules.** Fine within the advertised game. Never a reviewer-specific variant.

**Red: code. Never download on store builds:**
- `.gd` GDScript, or `.tres`/`.res`/`.tscn`/**PCK** containing scripts (Godot resources "support code execution",
  including embedded scripts) [S] https://www.gdquest.com/library/save_game_godot4/, [V]
  https://github.com/godotengine/godot/pull/98168. Also `ConfigFile`/`str_to_var` on remote data (object instantiation;
  verified on 4.7.2 in `02-content-model.md`).
  - `FileAccess.get_var` with `allow_objects` is covered too: "Deserialized objects can contain code which gets
    executed" [V] https://docs.godotengine.org/en/stable/classes/class_fileaccess.html.
- **Godot `Expression` on downloaded strings.** "An expression can be made of any arithmetic operation, built-in math
  function call, method call of a passed instance, or built-in type construction call" [V]
  https://docs.godotengine.org/en/stable/classes/class_expression.html. That's a method-call surface. Write a
  purpose-built evaluator instead.
- GDExtension libraries, WASM/Lua/JS runtimes executing downloaded programs.
- Any op taking a method name, class name, node path or resource path from data (`call`, `ClassDB.instantiate`, `load`).
- Loops, recursion, or user-defined functions with parameters. Anything that makes the rule language Turing-complete.
- Anything that changes purchases or entitlements, adds storefronts, or unlocks paid content outside IAP (3.1.1), or
  anything that changes the game's nature (gambling-like mechanics toggled remotely: 2.3.1, 5.3).
- Reviewer-detection or "review mode" behaviour differences (the "AB包" pattern).

### 2.5 Answers to the two specific questions

**Is a small declarative expression language acceptable?** Yes **[U: reasoned from the texts and enforcement above]**, if:
1. It is **non-Turing-complete**: no loops, recursion or user functions.
2. It is **side-effect-free**: effects are separate closed ops.
3. It is **bounded**: node, depth and cost caps are enforced at load time.
4. It is **read-only over a whitelist** of named variables.
5. It is **shipped as a JSON AST, signed and schema-validated**.
6. It is **incapable of reaching any engine API** except through registered primitives.

This matches JsonLogic's and CEL's safety properties. It is narrower than §3.3.1(B)'s allowance and Google's interpreter
carve-out (it can't cause a Play policy violation because it has no policy-relevant reach). `11-content-patterns.md`
recommended "no formulas". The refinement: **structured formulas are fine, free-text formulas are optional sugar
compiled in CI**.

**Is enabling pre-shipped-but-dormant mechanics by data OK if disclosed?** Yes, with three conditions:
1. **Describe with specificity** in the Notes for Review of the core release that adds them. Guideline 2.3.1(a) says
   "generic descriptions will be rejected". Example: "Adds rule primitives *Echo* (repeat the last die effect),
   *Frost* (a status that lowers die faces), and *Ferry* (moves the hero along river tiles). Items, enemies and biomes
   using these arrive as signed data content between releases."
2. Make each mechanic **accessible for review**. Best: ship ≥1 base-content entity that uses each new primitive in the
   same release. Alternatively, a visible "Codex / practice board" that demonstrates it. Don't hide a debug toggle.
3. Keep the **scope** "content inside existing features" (the §3.3.1(C) literal-text caution).

This is what LoR does routinely (client first, data activation a day later), and seasonal live-ops games do it
constantly. Residual risk: low **[U]**.

### 2.6 Compliance checklist (operational)

- Signed manifests plus hash-pinned content (see `10-security-signing.md`). Fail closed. The 2017 email cited MITM.
- Loader accepts **JSON only** for rules. Assets only in engine-imported formats. The PCK export filter excludes
  `*.gd`, `*.gdc`, `*.tscn`, `*.tres`, `*.res` from downloadable packs, and **CI rejects** any pack containing them.
- No op in the registry takes free-form method, class, node or path strings. CI asserts this with a registry audit.
- Review Notes template per core release (primitives added, examples, where to see them, statement that data content
  follows).
- App Store description says "new items, enemies and events are added regularly".
- 4.2.3: prompt with size before any initial-launch download.
- Any paid pack goes through IAP and restore (3.1.1). Content lists in metadata (2.3.2).
- Kill switch: a data flag can **disable** a content id or rule (safe direction), but never enable an unreviewed
  primitive.

---

## 3. Recommendations for Diceroll

### 3.1 Shape of a rule (illustrative)

```json
{
  "id": "ember_charm",
  "kind": "relic",
  "requires": ["trigger:die_rolled@1", "effect:damage@1", "target:random@1", "value:floor_div@1"],
  "params": { "base": 2, "per_turn": 3 },
  "rules": [
    {
      "id": "burn_on_six",
      "on": { "event": "die_rolled", "scope": "owner" },
      "if": { "all": [
        { "eq": [ { "var": "event.face" }, 6 ] },
        { "gte": [ { "var": "owner.hp" }, 1 ] }
      ]},
      "limit": { "per_turn": { "param": "per_turn" } },
      "do": [
        { "op": "damage@1",
          "target": { "pick": "random", "from": "enemies", "n": 1, "rng": "relic" },
          "amount": { "add": [ { "param": "base" },
                               { "floor_div": [ { "var": "run.relics_owned" }, 3 ] } ] } }
      ]
    }
  ],
  "text": { "template": "relic.ember_charm", "args": { "base": { "param": "base" }, "n": { "param": "per_turn" } } }
}
```

Notes:
- `requires` is **computed by CI**, not hand-written, and matched against the binary's published capability map. This
  follows `02-content-model.md` §content_api.
- Limits, counters and RNG streams are **first-class fields**, not expressions. This keeps common patterns declarative
  and analysable.
- The "Apply X on Y" family (Wildfrost) and parametric families (Balatro) should be **templates**. A content entity can
  say `"use": "on_event_apply_status"` with params, and the template expands to a rule at load.

### 3.2 Vocabulary design principles

1. **Copy the hook taxonomy, not the code.** Derive triggers from Diceroll's actual flow in `core/game_flow.gd`,
   `combat.gd`, `board.gd` and `die.gd`:
   `run_start, floor_enter, tile_enter, tile_reveal, combat_start, turn_start, dice_rolled, die_rolled, die_rerolled,
   dice_committed, combo_scored, damage_dealt, damage_taken, status_applied, enemy_killed, hero_downed, turn_end,
   combat_end, shop_enter, item_bought, potion_used, pet_charged, boss_phase, run_end`.
   This matches StS2 hooks and Balatro contexts.
2. **Split *modify* hooks from *react* hooks.**
   - Value-modification pipelines (`modify:damage_out`, `modify:die_face`, `modify:price`) run in a fixed, documented
     order: additive, then multiplicative, then clamps. That's StS2's `ModifyDamageAdditive`/`Multiplicative`.
   - React triggers run after the fact and enqueue commands.
   - This alone removes most ordering bugs.
3. **Closed sets, typed params, one meaning per field.**
   - Every op has a JSON Schema with named params. No `paramInt2`. Everything is enums or ids validated against the
     ContentDB. The Monster Train alias table is the anti-example.
4. **Parametric families before new ops.** Before adding an op, ask whether the item is a new *parameterization* of an
   existing family (Balatro jokers, Brotato `key`/`custom_key`).
5. **Generalize each primitive (MTGA).**
   - "Forbid die faces equal to X" rather than "Frost Totem's effect".
   - Name ops after mechanics, not items.
6. **Keep effects atomic and commands queued.**
   - Effects produce commands on a queue (StS/Hearthstone action queues).
   - Presentation (VFX/SFX/animation) is keyed off command types plus optional `fx` ids in data, so logic stays pure.
7. **Player choices are primitives.** `choose_die`, `choose_tile`, `choose_enemy` and `choose_option` each come with a UI
   contract. A new choice kind always ships in core (MTGA lesson).
8. **AI-awareness is part of the op contract.** Each op declares how `core/bot.gd` evaluates it. At minimum the bot can
   run rules on a **cloned state** (Dicey Dungeons, Monster Train previews). Prefer pure evaluation, so previews
   ("this will deal 7") and bots come for free.
9. **Text is generated.**
   - Each op contributes a localized fragment. Each entity has a template with typed args.
   - The linter fails if a param isn't referenced in text, or text references a missing param.
   - This prevents the Hearthstone 30.2.1 drift.
10. **Version everything.**
    - `op@N`. Semantics of `op@N` never change. A fix that changes numbers is `op@N+1` plus data migration, or a
      toggle (League's parameter-bug fix was toggleable on live).
    - Old ops stay until no shipped content uses them.

### 3.3 Escape-hatch policy (native primitives)

- **Definition.** A native primitive is a GDScript class in `core/rules/ops/` registered as `kind:name@version`. It
  ships with:
  1. a param JSON Schema;
  2. a doc entry;
  3. a text fragment;
  4. unit tests;
  5. a golden fixture;
  6. a bot/preview evaluation hook;
  7. presentation hooks (fx/sfx ids);
  8. a capability entry.
- **When to add one** (any of):
  - (a) The design can't be expressed.
  - (b) The expression would exceed a readability budget, e.g. >25 AST nodes or >2 nested collection ops. That's a sign
    of a missing concept.
  - (c) A performance hotspot.
  - (d) A new player choice or UI.
  - (e) Cross-cutting ordering semantics.
- **Cadence.** Batch primitives into **core releases every 2–6 weeks**. Each release's Review Notes list them (§2.5).
  Keep a "primitive backlog" fed by designers' "can't express" tickets. MTGA's 20% and League's block-per-3–4-days
  rates suggest this backlog never empties.
- **Dark-shipping.** A primitive may ship before content uses it only if it's disclosed and reviewable. Content using it
  declares `requires`, and older binaries hide that content.
- **Never** add a generic "call function X" or "run snippet" primitive. That is the one escape hatch that turns data
  into code.

### 3.4 Phasing expressiveness

| Phase | Adds | Unlocks | Main risk |
|---|---|---|---|
| **P0 Refactor** (prerequisite; see `02-content-model.md`) | Dispatch on declared rule ids + params instead of item ids. Registry. Capabilities. Save-safe unknown ids. | New items as new params on existing rules | Behaviour drift during refactor → golden replays first |
| **P1 Families** | Templates such as `on_event_apply_status`, `stat_mod`, `gain_on_kill` with typed params | 50–70% of typical relics, potions and runes as data **[U]** | Over-fitting templates |
| **P2 Rules** | `on` / `if` (comparisons, all/any/not over whitelisted vars) / `do[]` / `target` / `limit` | Most "Whenever X, if Y, do Z" content | Ordering bugs → modify vs react split |
| **P3 Values and counters** | Arithmetic AST, per-entity counters with reset scopes, first-class RNG streams | Scaling items, charge mechanics, "every 3rd roll" | Determinism, overflow → integer math and clamps |
| **P4 Collections and time** | Bounded `count`/`sum`/`any`/`all` over finite sets. `delay` (N turns/rolls). `duration` statuses | Board-aware and multi-turn effects | Cost blow-up → cost model and caps |
| **P5 (optional, late)** | Custom events emitted by rules. Small data-defined state machines for bosses/events | Boss phases and event chains as data | Cascades, grey policy zone → strict caps, disclose |

Diceroll's current state (`02-content-model.md`): items dispatch on 51 item ids and 51 variant ids, and passives, pets,
potions, runes and events are hard-wired. P0 and P1 therefore deliver most of the value. Don't start with the AST.

### 3.5 Testing and validation

1. **Schema plus semantic lint in CI** (JSON Schema 2020-12 for structure, then a GDScript/Python linter):
   - ids resolve; params within declared ranges;
   - var paths valid *for that trigger*, so `event.face` only on die events;
   - no unreachable conditions; text/param agreement;
   - `requires` computed; AST node, depth and cost caps;
   - no forbidden file types in packs.
2. **Golden replays** (League determinism):
   - Record `seed + inputs + content fingerprint` for a corpus of runs (bot runs plus hand-made fixtures in
     `tests/fixtures`).
   - Re-simulate headless (`godot --headless`) and compare a per-turn state hash.
   - Intentional changes update the goldens in the same PR, with the diff shown.
   - Run on every core and content change.
3. **Grammar-based fuzzing of rule data.**
   - Generate schema-valid random rules from the registry schemas.
   - Mutate existing content (numbers, targets, triggers).
   - Invariants: no crash, no NaN, limits enforced, cascade caps respected, determinism (same seed → same hash), save →
     load → same state.
   - LBaL's crash-on-malformed-data fixes are the cautionary tale.
4. **Interaction fuzzing.**
   - Random subsets of 3–8 entities in the same run under bot play, hunting cascade-cap hits and infinite loops.
   - That is the Hearthstone C'Thun and Titanic Guardian case.
   - Any cap hit in CI fails the build unless the content is allow-listed with a reason.
5. **Simulation balance bands** (`core/bot.gd`, `core/bot_meta.gd` exist):
   - Per new entity, run N thousand seeded bot runs with and without it.
   - Track win-rate delta, damage and gold per floor, run length, pick/offer ratio, max cascade depth, and evaluation
     time per event.
   - Gate on bands (e.g. win-rate delta within ±3 pp for commons, ±6 pp for rares) **[U: starting thresholds; tune]**.
   - Hotfix params the same way. The bot is also the regression oracle for "is this item a no-op?".
6. **Property tests for ops**, e.g. `damage(x)` never heals and `clamp` bounds hold.
7. **Device smoke tests** of the evaluator on the slowest supported phone and on Web/wasm.

### 3.6 Authoring tools

- **JSON Schema** generated from the op registry, the single source of truth, so docs, editor and validator never
  drift. Hook it into VS Code for autocomplete and hover docs.
- **Content CLI** (`tools/`): `validate`, `lint`, `requires`, `sim --entity X --runs 5000`, `golden --update`, `pack`
  (sign and hash).
- **In-game rule trace** (dev builds, and optionally a "why did that happen?" player view):
  - Per event, list matched rules, each condition with evaluated values, effects applied with computed amounts, RNG
    draws (stream, value), and cascade depth.
  - Exportable as JSON for bug reports and replays.
- **Rules playground scene:** load packs, set a board state (LBaL's sandbox save), fire events, watch the trace.
- Later, a Godot **EditorPlugin** form editor over the schema. Maybe a small web editor that reuses the schema.
  Designers shouldn't hand-edit JSON forever.
- **Review data like code:** PRs for content, CODEOWNERS, generated diffs of rules text. League: "data is rarely
  subjected to technical review".

### 3.7 Pitfalls and mitigations

1. **Trigger cascades and infinite loops.**
   - Caps: max cascade depth (e.g. 8), max commands per root action (e.g. 256), per-rule re-entrancy guard (a rule can't
     trigger itself inside its own cascade unless `reentrant: true`), per-rule `limit`s.
   - On a cap hit: stop the cascade deterministically, log to the trace, count in telemetry.
   - CI interaction fuzzing enforces caps are never hit by shipped content **[U: numbers are starting points]**.
2. **Determinism.**
   - Integer math, with explicit `floor_div`/`round_half_up` ops. No transcendental floats in rules.
   - Named RNG streams derived from the run seed (`core/rng.gd`), one per purpose, so adding a relic doesn't shift map
     generation.
   - Stable ordering by (phase, priority, owner slot order, entity index, rule index).
   - Never iterate in network-arrival order. The ContentDB sorts. Also see `11-content-patterns.md` §5.4 on seed
     stability.
3. **Performance in GDScript.**
   - Compile the JSON AST once at load into typed node objects or Callables.
   - Index rules by trigger: `Dictionary[trigger] → Array[RuleInstance]`.
   - Evaluate conditions cheapest-first, with no allocations in the hot path.
   - Budget per event on the slowest device, for example p95 < 0.2 ms, measured **[U]**.
   - Bot simulations double as a benchmark.
4. **Save compatibility.**
   - Rule state is keyed by stable `(entity id, rule id, counter id)`.
   - Unknown ids are preserved, not dropped (fixes the destructive `Profile.from_dict` issue in `02-content-model.md`).
   - **Pin the content snapshot per run** (fingerprint in the save). Hotfixes apply to new runs unless flagged
     `live_safe`.
   - Migrations for `op@N → op@N+1`. Ids are append-only, with tombstones.
5. **Text/behaviour drift:** generated text, and client and logic from the same data (Hearthstone 30.2.1).
6. **Data debt:** templates/inheritance instead of copy-paste. Lint for duplicated rule bodies. Deprecate ops with
   automated migrations (League).
7. **Vocabulary sprawl:** periodic consolidation passes (Brotato 0.8). Everything versioned so consolidation doesn't
   break packs.
8. **UI debt:** each new choice kind or status needs icons, tooltips and prompts. Keep status and keyword glossaries in
   data, and ship prompt kinds in core (MTGA).
9. **Security:** JSON only, signed, schema-validated, size caps. Never Godot `Expression`, `str_to_var`, `ConfigFile` or
   `.tres` on remote data. Fail closed.
10. **Policy drift:** re-check 2.5.2, 2.3.1, the DPLA and the Play policy at each release. Keep the red list (§2.4) as a
    CI-enforced registry audit.

### 3.8 How much new content will need code?

Data points [V unless marked]:
- MTGA ~20% of new cards need parser/engine work.
- Overwatch: new heroes with "little to no new code".
- League: a new block every ~3–4 days across ~140 champions.
- LoR: Python scripting for cards, so a large share needs *scripting* but not engine work **[S]**.
- Hearthstone: designers script most cards; engineers build "new cards and their associated mechanics".

Estimate for Diceroll **[U]**:
- Right after P0–P2: about 40–60% of *novel-feeling* content ideas still need a primitive. Pure rebalances, variants and
  reskins need 0%.
- After 6–12 months of vocabulary growth: about 10–25%, concentrated in new player choices, new board or tile
  mechanics, boss behaviours and minigames.
- Plan core releases on that assumption: data weekly, primitives every few weeks.

---

## 4. Sources

Primary (developer, platform or official), all fetched or seen 2026-09-30:
- Apple App Review Guidelines (Last Updated June 8, 2026): https://developer.apple.com/app-store/review/guidelines/
- Apple DPLA (Schedule 1 last updated Aug 18, 2026): https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
- Google Play Device and Network Abuse: https://support.google.com/googleplay/android-developer/answer/9888379
- Microsoft Store Policies v7.20: https://learn.microsoft.com/en-us/windows/apps/publish/store-policies
- Firebase Remote Config policy: https://firebase.google.com/docs/remote-config
- Expo EAS Update: https://docs.expo.dev/eas-update/introduction, https://expo.dev/blog/eas-update-best-practices
- MacRumors on the vibe-coding block (with Apple statement): https://www.macrumors.com/2026/03/18/apple-blocks-updates-for-vibe-coding-apps/
- 9to5Mac, 2017 hot-code-push email: https://9to5mac.com/2017/03/07/apple-cracks-down-on-hot-push-code-sdks/
- JsonLogic: https://jsonlogic.com/ · CEL: https://github.com/google/cel-spec
- Godot Expression: https://docs.godotengine.org/en/stable/classes/class_expression.html · FileAccess: https://docs.godotengine.org/en/stable/classes/class_fileaccess.html · ResourceLoader safety PR: https://github.com/godotengine/godot/pull/98168
- Unreal GAS Gameplay Effects: https://dev.epicgames.com/documentation/en-us/unreal-engine/gameplay-effects-for-the-gameplay-ability-system-in-unreal-engine
- MTG Arena GRE/GRP: https://magic.wizards.com/en/news/mtg-arena/on-whiteboards-naps-and-living-breakthrough · https://magic.wizards.com/en/news/feature/everything-you-need-know-about-magic-gathering-arena-2017-09-07 · https://mtgarena-support.wizards.com/hc/en-us/articles/48215493589396-Patch-Notes-2026-58-0
- Riot: https://www.riotgames.com/en/news/taxonomy-tech-debt · https://www.riotgames.com/en/news/future-leagues-engine · https://www.riotgames.com/en/news/bringing-features-life-legends-runeterra · https://www.riotgames.com/en/news/determinism-league-legends-introduction
- Overwatch Statescript (GDC 2017): https://gdcvault.com/play/1024653/Networking-Scripted-Weapons-and-Abilities · https://www.gamedeveloper.com/design/attend-gdc-and-see-how-blizzard-scripts-i-overwatch-i-s-weapons-and-powers · slides copy: https://docslib.org/doc/474379/networking-scripted-weapons-and-abilities-in-overwatch
- Hearthstone: https://hearthsim.info/docs/gamestate-protocol/ (community, documents the protocol) · https://us.forums.blizzard.com/en/hearthstone/t/3021-patch-notes/133884/1 · https://us.forums.blizzard.com/en/hearthstone/t/3161-patch-notes/142347 · job postings: https://gamejobs.co/Game-Designer-Card-Design-Hearthstone-Irvine-CA-at-Blizzard-Entertainment, https://gamejobs.co/Senior-Software-Engineer-Gameplay-Hearthstone-Temporary-at-Blizzard-Entertainment
- Marvel Snap: https://marvelsnap.com/april-27th-ota-balance-updates/ · https://marvelsnap.com/balance-update-july-16-2026/ · https://marvelsnap.com/balance-update-september-10-2026/ · https://unity.com/resources/marvel-snap
- Supercell: https://supercell.com/en/games/clashroyale/blog/release-notes/january-balance-changes/
- Dicey Dungeons: https://github.com/TerryCavanagh/diceydungeons.com/blob/master/modmigrationguide.md · https://diceydungeons.com/blog/2019/02/27/version-16.html · https://mods.diceydungeons.com/doku.php?id=doingthingsthehardway
- Luck be a Landlord: https://blog.trampolinetales.com/the-magnificent-modding-update-patch-notes/ · https://github.com/TrampolineTales/LBAL-Modding-Docs
- Brotato ModLoader migration: https://github.com/BrotatoMods/Brotato-ModLoader/blob/main/Mod-Migration-v0.8.0.0.md
- Slay the Spire BaseMod: https://github.com/daviscook477/BaseMod/wiki/Custom-Cards
- xLua hotfix docs: https://github.com/Tencent/xLua/blob/master/Assets/XLua/Doc/Hotfix_EN.md

Secondary or community (used for mechanism detail; tagged [S] above):
- Monster Train: https://github.com/brandonandzeus/Trainworks2/wiki/Modifying-an-Existing-Card · https://github.com/brandonandzeus/Trainworks2/wiki/Base-Game-CardEffects · https://github.com/KittenAqua/TrainworksModdingTools/wiki/Custom-Spell-Cards · https://github.com/brandonandzeus/MonsterTrainGameData · https://deepwiki.com/Monster-Train-2-Modding-Group/Trainworks-Reloaded/4.4-card-effect-system
- Wildfrost: https://github.com/rspforhp/WildfrostModdingDocumentation/wiki/StatusEffectDataBuilder
- Slay the Spire 2: https://github.com/ptrlrd/spire-codex/blob/main/README.md · https://deepwiki.com/hanmi255/STS2SourceCode/2.2-abstractmodel-and-hook-event-system · https://deepwiki.com/hanmi255/STS2SourceCode/4.1-cards-and-card-pools
- Balatro: https://tulip4attoo.github.io/balatro-p3/ · https://github-wiki-see.page/m/Pheubel/Steamodded/wiki/Guide-%E2%80%90-Joker-Calculation
- Brotato wiki: https://brotato.wiki.spellsandguns.com/Modding_Effects
- LBaL example: https://wikiwiki.jp/yuruku_lbal/Mod%E5%B0%8E%E5%85%A5%E3%83%BB%E4%BD%9C%E6%88%90
- Dicey Wastelands DSL: https://itch.io/t/444008/adding-your-own-equipment-enemies-characters
- Supercell asset mechanism: https://github.com/123456abcdef/sc-assets-download · https://github.com/Draggie306/DraggieTools · https://github.com/smlbiobot/cr-csv/commit/f68c68238d12c286d46381e0fbfc1f18f472036f
- LoR patch schedule quote: https://outof.games/news/1300-legends-of-runeterra-patches-move-away-from-treating-mobile-players-like-second-class-citizens-unlike-its-competitor-hearthstone/
- Hearthstone infinite-loop CM post: https://outof.games/devtracker/hearthstone/hearthstone-forums-us/hearthstone-forums-us/20526
- OTA policy summaries: https://bitrise.io/blog/post/what-app-stores-allow-with-ota-updates-apple-and-google-policy-explained · https://patchrelease.com/blog/what-apple-allows-ota-updates · https://docs.patchrelease.com/apple-compliance/
- 2017 email full text: https://medium.com/@isaacacasanova/apple-rolls-back-rollout-io-6a9a6cd9702f · https://apple.slashdot.org/story/17/03/08/1355246/apple-begins-rejecting-apps-with-hot-code-push-feature
- Heise (vibe coding, §3.3.1(B) citation): https://www.heise.de/en/news/Apple-blocks-updates-for-vibe-coding-apps-11216835.html
- China hot update: https://github.com/Tencent/xLua/issues/610 · https://www.cnblogs.com/heweiwei/p/12554627.html · https://github.com/focus-creative-games/hybridclr · https://github.com/Project-x64/genshin-luadec · https://forum.cocos.org/t/topic/175137
- Unity Addressables and code: https://discussions.unity.com/t/addressable-to-latest-c-files/797304 · https://discussions.unity.com/t/how-can-i-re-attach-scripts-to-addressables-between-projects/1635931/1
- Godot resources can execute code: https://www.gdquest.com/library/save_game_godot4/ · https://github.com/godotengine/godot-proposals/issues/4925
- Pokémon TCG Pocket data-only expansions: ptcgpocket.gg notices via search (weak; treat as [S]/[U])
- MTG templating/grammar: https://hudecekpetr.cz/a-formal-grammar-for-magic-the-gathering/
