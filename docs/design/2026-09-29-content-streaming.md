# Content streaming, content packs and the bootstrapper (investigation)

Date: 2026-09-29. Status: **proposal for Vlad's decision.** Nothing here is implemented.
Scope: should Diceroll split its content into downloadable, updatable packs (core, characters,
foes, biome dressing, audio, EXTRA props…) and bootstrap itself Fortnite-launcher style, or keep
relying on store, Steam and itch updates plus the signed full-PCK updater that's being built now?

Inputs: spec §15–16 (release pipeline bullet), `docs/ASSETS.md`, `tools/import_assets.sh`,
`docs/plans/RESUME.md`, the updater (`game/update/*` in worktrees `wp-updater` / `wp-ci-release`),
the CI asset units (`tools/ci/assets.py`, `tools/ci/assets.lock.json`), the missing-assets screen
(`game/boot/asset_check.gd` and `missing_assets_screen.gd` in worktree `wp-free-assets`), plus
headless Godot 4.7.2 experiments (appendix A) and web research (sources at the end).

---

## 0. Executive recommendation

**Build packs and the loader as one universal system. Let each channel choose where the packs
come from: embedded, downloaded or store-delivered. Roll it out in phases, not as a big-bang
"bootstrapper everywhere".**

The measurements settle most of the debate:

- All game content is **~73 MB** as a PCK (**~64 MB** compressed), and it's the same on every
  platform, because textures are only ~5 MB of it. Every store threshold is far away: the Play
  base module is 200 MB, iOS cellular downloads are 200 MB, Steam and itch have no practical
  limit. **Install size alone doesn't justify streaming on any store channel.**
- The real wins are elsewhere:
  1. **Update size.** Today the updater re-downloads a ~73 MB PCK for a one-line fix. Split the
     code/UI into its own ~4–5 MB pack, make assets content-hashed packs that stay cached across
     versions, and a typical update drops to **~5 MB**. This builds directly on the updater.
  2. **Web first load.** Today it's ~9 MB (compressed wasm) + ~64 MB before the title shows. With
     staged packs it's about 15 MB to an interactive title, and the rest streams.
  3. **The product feel Vlad wants.** A tiny shell boots, upgrades itself in place as packs mount,
     and morphs into the main menu.
  4. **Deterrence for the paid KayKit EXTRA meshes.** This is optional and low value, because
     every KayKit pack is CC0; see §7.
- **Policy:** packs are **data-only everywhere** (no GDScript in any pack), and all GDScript
  ships inside the binary or main pack. Then one codebase and one IPA can serve SideStore,
  TestFlight and the App Store (Apple 2.5.2), and Play (Device and Network Abuse policy).
  Self-updating *code* stays where it already is: the desktop/sideload `--main-pack` updater.

**Verdict:** "lean core + content packs" is **worth doing, but after the updater and CI release
work merge**. The **"structure now"** step (§10) is cheap (about 1 day) and should happen now so
the option stays open. A **full bootstrapper on every channel is not recommended.** On Steam, itch
and Google Play it duplicates what the platform already does. On the App Store, a "downloader"
first launch adds review risk for ~50 MB of savings. **Encryption with custom export templates is
deferred** (large CI cost, deterrence only).

Phases (details in §11):

| Phase | What | When | Size |
|---|---|---|---|
| 0 | Structure now: pack map (units → packs), content-id → pack table, tests that forbid hard-wiring, 2 cheap size wins | now | S (~1 day) |
| 1 | Split build: code pack + data-only unit packs (PCKPacker), manifest schema 2, per-pack cache in the updater's store; packs **embedded** in every build | after `wp-ci-release` merges | M (~4–6 days) |
| 2 | Loader "gradual upgrade" boot shell + staged mounting (runs on every channel; flashes by when packs are embedded) | with/after 1 | M (~4–5 days) |
| 3 | **Remote** packs where they pay off: Web (lazy HTTP), desktop/Android sideload "lean installer", SideStore IPA option; download UX, resume, eviction | after 2 | M (~4–6 days) |
| 4 (optional) | Encrypted packs (custom templates), Play Asset Delivery, Apple-hosted Background Assets, per-biome packs for new original art | only if a need appears | L each |

---

## 1. What already exists (and what this design builds on)

- **Updater (`game/update/*`, worktrees `wp-updater` → merged into `wp-ci-release`).**
  - Signed manifest `update-<channel>.json` + `.sig` (RSA PKCS#1 v1.5 SHA-256, key in
    `update_keys.gd`), schema 1: `version, engine, min_binary, min_supported, pack{url,sha256,size},
    binaries{}, stores{}`.
  - Desktop GitHub builds download **one full PCK** into `user://updates/{staged,current,previous}`,
    then **relaunch with `--main-pack`**, with boot-attempt rollback. Binary updates open a URL.
  - iOS and Android store builds only prompt. Web, itch, Steam and dev builds never check.
  - `tools/export.sh pck` exports that full PCK from the Linux preset (S3TC/BPTC).
- **CI asset units (`tools/ci/assets.py`).**
  - 31 content-hashed units, one per runtime folder: `assets/kaykit/<x>`, `assets/audio/sfx/<pack>`,
    `assets/audio/music`, `assets/fonts`, `ui/icons/rendered`.
  - They're stored age-encrypted in the private `diceroll-assets` repo and pinned by the public
    `tools/ci/assets.lock.json`.
  - **This unit = folder = hash structure is exactly what player content packs need.** Folder
    prefixes already are the bundle boundaries.
- **Optional-pack tolerance in code.**
  - `Props.has()`/`Props.inst()` (`game/world/props.gd`) are a chokepoint for most prop loads.
  - Roughly 20 call sites guard with `ResourceLoader.exists()` and fall back to FREE models when an
    EXTRA pack is absent (camp, minigame props, pets, weapons).
  - The game is already built to **degrade gracefully when optional content is missing**. That's
    the key property streaming needs.
- **Boot gate (`wp-free-assets`).**
  - `AssetCheck` checks the lock's units at boot (source checkouts only).
  - `MissingAssetsScreen` is a designed screen made only from **engine built-ins plus the tracked
    logo** (`res://assets/icon/logo_doubles.png`): dark radial gradient, DICE|ROLL lockup, a card,
    safe areas.
  - **That screen is the visual and technical seed of the loader** (§6).
- **How content is referenced.**
  - No `preload()` of `res://assets/**`, and no `.tscn`/`.tres` referencing assets. Everything is
    runtime `load()` of path strings, built from ~25 base constants (`Props.K`, `Character.ADV/ANIM/FOE`,
    `Roster.FOE/WPN`, `AudioBus.S/M`, `UiTheme.DISPLAY_PATH`, dressing `FOREST`…).
  - Paths are used, never `uid://` strings. That's ideal: mounting packs before first use is enough,
    and nothing has to be rewritten to a new addressing scheme.
  - Content ids live in `core/content/*.gd` (heroes, enemies, biomes, pets, gear, minigames,
    unlocks). Presentation maps ids to models in `game/actors/character.gd`, `game/enemies/roster.gd`,
    `game/world/enemy_looks.gd`, `game/world/dressing/<biome>.gd`, `game/camp/*`, `game/pets/*`,
    `game/minigames/props/*`, `game/audio/audio_bus.gd`.

## 2. Size analysis (measured 2026-09-29, main @ f6f95bc, Godot 4.7.2)

### 2.1 Full export today

| Artifact | Size | Note |
|---|---|---|
| Full PCK, Linux preset (S3TC) | **73.2 MB** | `--export-pack Linux`, headless, scratch copy |
| Full PCK, iOS preset (ETC2/ASTC) | 73.2 MB | differs by 64 bytes: textures are negligible |
| Full PCK, Android preset | 73.2 MB | same |
| gzip -6 of any of them | **64.2 MB** | only −12%: `.scn` meshes are already compressed, mp3/ogg don't compress |
| `.godot/imported` referenced by `.import` files | 68.9 MB | assets only; the rest (~4.3 MB) is scripts, UI, shaders, icons |
| Old `build/` (2026-09-28, before the Camp/Armory/foes art) | PCK 29 MB; macOS universal binary 163 MB; web `index.wasm` 38 MB (~9 MB compressed) | binaries are engine templates, content-independent |

The PCK grew **29 → 73 MB in one day of content work**. It will keep growing with the new biomes
(`docs/design/2026-09-29-new-biomes.md`), the Armory items, pets and music. A reasonable 1.0
projection is **90–130 MB**, still under every store threshold.

### 2.2 Per unit (imported bytes, which is what goes into a PCK)

| Unit | MB | Kind | Used by |
|---|---|---|---|
| kaykit/forest (EXTRA) | **19.8** | meshes | Camp, Glade and Moonlit dressing, Crypt rocks |
| audio/music | 7.9 | mp3 | title, biomes, camp |
| kaykit/animations | 5.3 | anim libs | every character |
| kaykit/foes (EXTRA + Monthly) | 5.2 | characters | enemy roster |
| kaykit/resources | 3.8 | meshes | camp, minigames, tiles |
| audio/sfx (6 Kenney packs) | 3.7 | ogg | everything |
| kaykit/dungeon | 3.4 | meshes | Crypt/Throne dressing, tiles |
| kaykit/boardgame | 2.8 | meshes + tex | board, dice, coins |
| kaykit/dungeon_x (EXTRA) | 2.7 | meshes | tile props, camp |
| kaykit/adventurers_x (EXTRA) | 2.1 | characters | camp keepers, classes |
| kaykit/adventurers | 1.9 | characters | heroes |
| kaykit/mystery (EXTRA) | 1.7 | meshes | set pieces, minigame prizes |
| kaykit/weapons_x (EXTRA) | 1.6 | meshes | Armory items |
| 14 small units (weapons, tools(_x/_extra), halloween, icon, resources_x, blocks, skeleton_props, skeletons, resource, fonts, platformer, potions) | 7.0 | | |

**Cheap size wins that need no streaming:**

- **Forest is duplicated.** `import_assets.sh` now syncs all six colours flat into `forest/`, but
  the Camp still loads `forest/color%d/…` (`camp_props.gd`, `camp_scene.gd`). There are four
  3.1 MB (source) colour sub-folders on top of the flat copy. Pointing the Camp at the flat folder
  and dropping `color*/` saves roughly **5–8 MB** of PCK.
- **Everything is exported.** Every preset uses `export_filter="all_resources"`, so every imported
  forest variant ships even if unused. A "used-paths" audit could trim more. That audit is only
  safe once there's the registry from §10.

### 2.3 Estimated install and download size per platform (today's content)

| Platform | Engine/binary | Content | ≈ Download | Threshold | Streaming saves |
|---|---|---|---|---|---|
| macOS (universal .app, zipped/DMG) | 163 MB raw, ~60 MB compressed | 64 MB | ~125 MB | none | ~50 MB on first download, if lean |
| Windows / Linux / Steam Deck | ~70–90 MB raw | 64 MB | ~90 MB | none | same |
| iOS IPA (arm64 device) | ~25–35 MB compressed (estimate) | 64 MB | ~95 MB | 200 MB cellular prompt | nothing needed; lean IPA ~45 MB |
| Android AAB/APK (arm64) | ~20–25 MB compressed (estimate) | 64 MB | ~85 MB | 200 MB base module | nothing needed |
| Web | wasm ~9 MB (br/gz) + js | 64 MB, all before title | **~73 MB before first frame of title** | user patience | **~55 MB off the critical path** |
| Update (desktop GitHub, today) | — | full PCK | **~64–73 MB per update** | — | **→ ~5 MB** with split packs |

Conclusion: bundling mainly pays off in **update size** (everywhere we self-update) and **Web time
to first interaction**. It doesn't pay off in store install sizes at this scale.

## 3. Options

| | A. Standard updates only | B. Lean core + content packs (recommended) | C. Full bootstrapper everywhere (Fortnite model) |
|---|---|---|---|
| What ships | full binary + full PCK | binary + code/UI pack + packs (embedded or remote per channel) | tiny shell; everything else downloaded on first launch |
| Update size (self-updating channels) | ~70 MB | ~5 MB typical | ~5 MB typical |
| First launch offline | yes | yes where packs are embedded (stores, Steam, itch, default installers) | **no** |
| App Store risk | none | low (data-only packs; base playable) | **real** (4.2.3(ii) disclosure plus minimum functionality; "just a downloader") |
| Play policy | fine | fine (data-only) | fine (data-only), but duplicates PAD |
| Steam / itch | native | native (packs just sit in the depot) | redundant: depots/butler already delta-patch |
| Web | ~73 MB before title | ~15 MB to title, rest lazy | same as B |
| Build/CI complexity | lowest | medium (per-pack builds, manifest v2) | medium-high (+ first-run downloader on every platform) |
| Testing matrix | 1 | packs present/missing × channel | same as B plus first-run network states on every store |

**C as a UX is adopted, and as a distribution rule it's rejected.** The "gradual upgrade" loader
(§6) runs on every channel. Whether it *downloads* depends on the channel (§4). Fortnite can
bootstrap because it owns its launcher. On the stores the platform is the launcher.

## 4. Distribution matrix (per channel)

Legend. **Embedded**: packs are files inside the app/depot, mounted at boot, no network needed.
**Remote**: fetched over HTTPS from the pack CDN. **Scripts in packs**: always **no** by policy.
The column shows what the channel *would* allow.

| Channel | Base binary contains | Packs | Scripts allowed in downloads? | Update mechanism | Signing / notarization |
|---|---|---|---|---|---|
| **macOS direct** (GitHub Releases, zip/DMG) | engine + main pack (code, UI, loader) | embedded (default "full" download); optional "lean" download fetches remote | yes (sideload) | Updater: code pack via `--main-pack` relaunch + changed unit packs; binary → open URL (later Sparkle) | Developer ID + notarization ($99/yr) to avoid Gatekeeper; packs live in `user://`, outside the bundle, so the signature stays valid. Today: ad-hoc |
| **Windows direct** | same | same | yes | same (later WinSparkle/Velopack for the exe) | Authenticode optional (SmartScreen reputation) |
| **Linux x64/arm64, Steam Deck direct** | same (tar/AppImage) | same | yes | same | none |
| **Android APK sideload** (GitHub + Obtainium) | APK with engine + main pack | embedded default; lean APK optional | yes (not Play) | Updater for code/data packs; APK updates via Obtainium tracking GitHub Releases (**same keystore forever**) | release keystore (never debug); F-Droid main repo is impossible (non-free assets), a self-hosted F-Droid repo is possible |
| **iOS SideStore / AltStore** | **the same IPA as the App Store**, unsigned (the user's tool re-signs it) | embedded (default) or lean IPA + remote data packs | technically yes (no App Review), **but no: one codebase** | binary via an **AltStore source JSON** (hosted at the `channels` release URL or GitHub Pages); data packs via the in-app downloader | none from us; free Apple IDs: 7-day refresh, 3 apps, 10 App IDs/week, so a smaller IPA helps |
| **iOS TestFlight** | same IPA, distribution-signed | embedded (all content in the IPA) | **no** (2.5.2) | TestFlight | App Store Connect, Beta App Review |
| **iOS App Store** | same IPA | embedded v1; later optional remote **data** packs (self-hosted, then Apple-hosted Background Assets on iOS 26+) | **no** | App Store + existing "update available" prompt | App Store distribution |
| **Google Play** (internal → prod) | AAB: base module + install-time asset pack (Godot does this automatically for AAB) | install-time (everything); PAD fast-follow/on-demand only if base > ~150 MB | **no** (policy bans downloaded dex/so; GDScript is interpreted, a grey zone we avoid) | Play updates + existing prompt | Play App Signing |
| **Steam** (Win/Linux/Deck/macOS) | depot = binary + main pack + pack files | embedded in depot | n/a | SteamPipe delta updates; **our downloader disabled** (`distribution=steam`) | Steamworks; macOS still needs notarization |
| **itch.io** (desktop) | butler channel per platform | embedded | n/a | itch app (wharf patching); downloader disabled | none |
| **Web** (GitHub Pages / itch HTML5) | `index.wasm` + small `index.pck` (code, UI, loader, core) | **remote, lazy** over same-origin HTTP → `user://` (IndexedDB) → mount | n/a (always latest) | always latest; packs cached by hash in IndexedDB | HTTPS only |

**One flag set per build** (extends `build_info.json`, which CI already stamps):

```json
{"distribution": "github|sideload-ios|testflight|appstore|play|steam|itch|web",
 "packs": {"source": "embedded|remote|mixed", "downloads": true,
           "required_embedded": ["ui","core3d","foes","nature"], "scripts_in_packs": false}}
```

The same iOS binary behaves correctly on SideStore, TestFlight and the App Store because only
`build_info.json` differs, and even that can stay identical by defaulting `downloads` to
`false` on iOS. `scripts_in_packs` is `false` on every channel, and a CI check enforces it by
listing each pack with `godotpcktool` and failing on `.gd`, `.gdc` or `.remap` to a script.

**iOS minimum functionality:** the IPA always contains enough for a complete run offline (§5.1:
`base + ui + core3d + foes + nature` covers the fresh-profile Knight and Glade/Hollow/Throne).
For v1 we ship **all** content in the IPA, since ~95 MB is under the cellular limit. If a lean IPA
is ever used, the first-launch download of optional packs must **disclose the size and ask first**
(4.2.3(ii)).

## 5. Architecture

### 5.1 Pack taxonomy (grouping the 31 CI units)

Packs group **source units** (KayKit pack folders). They aren't split per biome, because one biome
uses several packs (Glade = forest + blocks; Crypt = dungeon + forest rocks + halloween). Re-foldering
the assets by consumer would duplicate meshes and churn every path for ~1–3 MB per biome. Per-biome
packs only make sense for future *original* biome-specific art (Phase 4).

| Stage | Pack | Units | ≈ MB | Required for | Offline fallback |
|---|---|---|---|---|---|
| 0 | **base** (main pack / in binary) | all GDScript, `ui/**` (scripts, vector icons, shaders), `assets/icon/**` (logo), `build_info.json` | 4.3 | loader, all logic | — |
| 1 | **ui** | fonts, sfx interface-sounds, casino-audio, digital-audio, music-jingles, rendered-icons | ~1.8 | themed UI | default font; vector glyphs (exists today) |
| 2 | **core3d** | boardgame, animations, adventurers, platformer, potions, blocks, halloween, tools, weapons, skeletons, resource, dungeon | ~17.3 | title backdrop, board, heroes, Crypt/Throne | none (required) |
| 3 | **audio** | music, sfx impact-sounds, rpg-audio | ~9.8 | music, combat sfx | silence (AudioBus already guards `exists()`) |
| 4 | **foes** | foes, skeleton_props | ~5.7 | enemy looks | none (required for runs) |
| 5 | **nature** | forest (after dedupe) | ~12–20 | Glade/Moonlit/Camp dressing | sparse dressing (fallback helpers exist) |
| 6 | **extra** | dungeon_x, resources, resources_x, tools_x, tools_extra, weapons_x, adventurers_x, mystery | ~13.6 | Camp keepers, Armory items, tile props, minigame prizes | FREE props (the free-assets mode that exists today) |

"Playable" means stages 0–2 and 4, plus 5 if the route needs it (~33–49 MB). "Complete" means all
of them (~73 MB). A new character or biome later becomes either a new unit folder mapped into an
existing pack, or its own pack (`characters_new1`) if it's big and optional. The map is data
(§5.3), so that's a one-line change.

**Texture formats:** one universal pack per unit, containing both S3TC/BPTC and ETC2/ASTC
`.ctex` variants (~+3 MB total). Per-format packs aren't worth the matrix until textures matter.

### 5.2 How packs are built (validated, appendix A)

- **Base/main pack:** a preset with `exclude_filter` adding `assets/**` (and `ui/icons/rendered/*.png`).
  Code stays compiled into it (`script_export_mode=2`).
- **Unit/content packs:** built by a headless tool script with **`PCKPacker`** straight from the
  import cache. For each file in the pack's unit folders, add `<file>.import` plus its
  `[deps] dest_files` from `.godot/imported/`.
  - Result: **data-only packs with no scripts, no `project.binary`, no `uid_cache.bin` and no
    `global_script_class_cache.cfg`.**
  - Forest came out at 21.6 MB and loaded fine.
  - Deterministic input means the pack hash = sha256(sorted unit hashes + engine version +
    import-settings hash). That reuses `assets.py`'s unit hashes, so CI only rebuilds a pack when
    a member unit changes or the engine changes.
- Why not "export selected resources" or `--export-pack`? **Measured:** a `resources`-filtered
  pack still drags in the **autoload scripts** (`tools/shot.gd`, `game/audio/audio_bus.gd`) plus
  `project.binary` and the caches.
  - Mounting it with the default `replace_files=true` **replaced the global class cache: the class
    count went 180 → 0.** That's the "stale pack overrides new code" failure the community warns
    about.
  - `--export-patch <preset> --patches base.pck` (4.4+) does produce a clean unit diff (20.5 MB),
    and two such patches compose in either order.
  - But patches still carry the full caches and are tied to the exact base they were diffed
    against. PCKPacker packs are independent of the code version, and that's what makes them
    cacheable across updates.
- Rules enforced at mount (`ContentPacks.mount()`):
  - Mount with **`replace_files=false`**. Unit packs only add paths and never override.
  - Only paths under the pack's declared prefixes are allowed; CI verifies the file list.
  - Mount **before first use**, in the loader, one pack per frame (Android `load_resource_pack`
    can stall the UI, godot#105009).
  - Measured mount cost: **7 ms** for a 20 MB pack on desktop; loading a prop afterwards ~3 ms.
- **UIDs:** PCKPacker packs don't register UIDs (`uid://` lookups fail, path loads work). The rule
  is **no `uid://` references into `assets/**`**. Code already complies, and a test enforces it
  (§10). If ever needed, each pack can carry `uids.json` and call `ResourceUID.add_id()` at mount.
- Nested packs work: a pack file included inside the main PCK (`include_filter="packs/*.pck"`)
  mounts from `res://packs/…`, measured on desktop. That's one way to "embed" packs without
  sidecar files. Sidecars next to the executable, in the depot or in the app bundle are simpler
  for Steam/itch delta patching, which works better on separate files. Android and iOS nested
  mounting still need verifying (the Android main pack lives in APK assets).

### 5.3 Content registry: ids → pack → paths

Path prefixes stay the contract, so **no path rewriting is needed**. The registry adds:

1. `game/content/packs.gd` (data): `PACKS = {"core3d": {"stage": 2, "units": ["assets/kaykit/boardgame", …], "required": true}, …}`.
   This is the single source that CI (`assets.py` → pack builder), the loader and tests read.
2. `game/content/needs.gd` (data): content id → packs, for example
   - `hero:knight → [core3d]`
   - `biome:glade → [core3d, nature]`
   - `enemy:orc_raider → [foes]`
   - `gear:sword_F → [extra]`
   - `minigame:fossil_hunter → [extra]` (with FREE fallback)
   - `music:biome_magma → [audio]`
3. `Content.available(id) -> bool` and `Content.missing(ids) -> Array[pack]`.
   - Today these always return true (everything is embedded), so shipping this changes no behaviour.
   - Later, the Camp, class select and route picker gray out or badge unmounted content
     ("Downloading…"), and the run builder asks for the packs a route needs before GO.
4. `Props.inst/has` stays the chokepoint for props. Characters, roster, audio and theme keep their
   base constants, but their folders must be under a declared pack (test).

**Core rules** (`core/`) never know about packs. Content ids and rules are all in the code pack, so
the sim and tests are unaffected.

### 5.4 Versioning and compatibility

**Manifest schema 2** is an additive extension of `update_manifest.gd`. It's still signed by the
same key, and old binaries ignore the new fields.

```json
"packs": {
  "core3d": {"hash": "b3c1…", "url": ".../packs/core3d-b3c1….pck", "sha256": "…", "size": 18123456,
             "engine": "4.7", "format": 1, "stage": 2, "required": true}
},
"code": {"url": ".../diceroll-0.5.0-code.pck", "sha256": "…", "size": 4900000,
         "requires_packs": {"core3d": "b3c1…", "foes": "…"}}
```

- **The code version pins exact pack hashes** (`requires_packs`), like a lock file, so the state
  is always deterministic. Because pack hashes change rarely, most releases reuse every cached pack.
- **Engine gate:** imported `.scn`/`.ctex` formats are tied to the engine. A pack whose `engine`
  (major.minor) or `format` doesn't match the binary is never mounted. CI rebuilds all packs on an
  engine upgrade, and `format` is bumped when import settings change project-wide.
- **Store** (extends `update_store.gd`):
  - `user://packs/<id>-<hash>.pck` plus a `meta.json` per pack.
  - The code pack keeps staged/current/previous and rollback exactly as today.
  - Eviction: keep the hashes pinned by current and previous, delete the rest after a successful
    boot.
- **Save compatibility:**
  - Saves and profiles store **content ids**, never paths.
  - A run save whose route needs an unmounted pack shows "Continue (downloading 12 MB…)" and
    never deletes or migrates the save.
  - Profile unlocks are independent of packs.
  - Code newer than the save follows the existing save schema rules; packs don't change them.

### 5.5 Security

- Integrity: the signed manifest covers every pack `sha256`. Packs are verified after download,
  before mount, and again at boot if the size or mtime changed. Embedded packs are trusted through
  the binary's signature.
- Transport: HTTPS only. Private pre-release feeds already support a bearer token
  (`DICEROLL_UPDATE_TOKEN`).
- Data-only packs plus `replace_files=false` mean a malicious or stale pack can't inject or
  override code. Only the signed code-pack path can, as it does today.

## 6. Loader: the "gradual upgrade" boot shell (first run and every run)

### 6.1 Idea

`main.tscn` boots a **`BootShell`**, which evolves from `MissingAssetsScreen`. It uses only engine
built-ins and the tracked logo: the dark radial gradient, the DICE|ROLL lockup (logo PNG +
default-font wordmark) and a card with a progress bar and a status line. The same layout also
hosts the error, offline and missing-assets states, which replaces today's separate screen.

The shell then **upgrades itself in place** as packs mount, and finally *becomes* the title screen.
It never cuts to another scene.

### 6.2 Stages (state machine)

| State | Needs | What the player sees | Exit |
|---|---|---|---|
| `SHELL` | base | gradient, logo + default-font wordmark, card "Starting…" | immediately |
| `VERIFY` | base | card: "Checking content…" (hash only if size/mtime changed) | ok → `MOUNT_UI`; missing → `FETCH` or `ERROR` |
| `FETCH` (remote channels only) | network | card: bar + "Downloading 18 / 49 MB · 3.1 MB/s", Pause, "Wi-Fi only" note on cellular | pack verified → mount its stage |
| `MOUNT_UI` | ui | **wordmark crossfades to Lilita One**; card and bar re-theme with `UiTheme` (fonts cache invalidated) | → `MOUNT_CORE3D` |
| `MOUNT_CORE3D` | core3d | **title backdrop fades in** behind the card: orbiting board with the Knight, built only from core3d | → `MOUNT_AUDIO` |
| `MOUNT_AUDIO` | audio | **title music fades in** | → `READY` (audio isn't blocking) |
| `READY` | playable set | **the bar morphs into PLAY / Continue / Settings** in the same card slot (tween: bar width → button row, status → subtitle) | title interactive |
| `BACKGROUND` | — | optional packs (foes, nature, extra) keep downloading; a small pill in the corner; Camp/route items badge until their pack mounts | all done |
| `OFFLINE` / `ERROR` | base | same card with an explanation, "Retry" and, if the playable set exists, "Play offline" | retry / play |

**Subsequent launches:** every pack is cached, so each mount takes milliseconds. The shell holds a
~250–400 ms minimum so the fade reads as intentional, with no flicker, and skips the stages
visually. Updates check in the background after the title shows (`Updater.CHECK_DELAY`). A new
code pack uses today's "Restart to update" banner, and changed unit packs download silently,
mounting on next boot.

### 6.3 One tree, no scene cut

`main.gd` creates `BootShell` (CanvasLayer 50) first. `GameController` is created when
`MOUNT_CORE3D` completes, and `show_title()` builds the backdrop *behind* the shell. The title
screen's buttons are **reparented into (or tweened onto) the shell's card slot**. After that, the
shell frees its gradient and card, and the title screen owns the buttons. The screenshot harness
gets `--boot-stage=<state>` scenarios for every stage, so each one goes through `shoot_matrix.sh`.

**Dev gesture.** The shell must host `DevGesture` (`ui/widgets/dev_gesture.gd`: 5 taps within ~3 s
in the bottom-right 80×80 px, inside the safe area) from its first frame, in every state (errors
included), so the hidden Developer menu (update channel, build info, diagnostics) is always
reachable at boot. See docs/RELEASE.md, "Developer menu".

### 6.4 Download UX details (remote channels)

- **Resume:** HTTP `Range` requests with `HTTPRequest.download_file` into `*.part`, then verify.
- **Retry:** exponential backoff; a clear offline state; **pause/resume**.
- **Cellular:** a cellular warning on mobile when the total is over ~50 MB, since Godot can't
  reliably read the network type (needs a small platform check or just a "Download now / Wi-Fi
  later" choice).
- **Sizes:** disclosed before any first-launch download (Apple 4.2.3(ii)).
- **Pre-run prefetch:** GO checks `Content.missing(route)`. If something is missing, show
  "Downloading Magma Depths (6 MB)…" and let the player start once it's ready or pick another route.
- **Storage:** `user://packs` maps to Application Support (macOS), `%APPDATA%` (Windows),
  `~/.local/share` (Linux), app `Documents`/`Library` (iOS: mark do-not-back-up), internal storage
  (Android) and IndexedDB (Web; files also sit in memory, so ~73 MB of RAM when everything is
  mounted).
- **Eviction:** only unreferenced hashes are evicted. There's no LRU for required packs.

### 6.5 What's presentation vs infrastructure

| Work | Kind | Size |
|---|---|---|
| `BootShell` from `MissingAssetsScreen` (states, card, bar, errors) | presentation | S–M (2 d) |
| In-place upgrade: font swap, re-theme, backdrop fade, music fade, bar→buttons morph | presentation | M (2–3 d) |
| Title backdrop that needs only core3d; lazy theme/font caches | presentation | S (0.5 d) |
| Boot-stage screenshot scenarios + matrix | presentation/test | S (0.5 d) |
| `ContentPacks` (mount rules, stages, `available()`), registry | infrastructure | S–M (1.5 d) |
| Downloader (range/resume, verify, per-pack store, eviction) on top of `update_fetcher`/`update_store` | infrastructure | M (2–3 d) |
| Manifest schema 2 + CI pack builder + `update_manifest.py` | infrastructure/CI | M (2–3 d) |

## 7. Encryption: threat model and options

**What we protect:** the paid KayKit **EXTRA** meshes, against *casual* extraction. They're CC0,
so extraction isn't a legal problem. Keeping them out of the public repo is a courtesy to the
creator (spec §16). Determined extraction can't be prevented: GDRE Tools and gdsdecomp recover
projects, and gdke and published guides pull the AES key out of the binary.

| Option | How | Protects at rest? | Cost |
|---|---|---|---|
| None (today) | plain PCKs; anyone can open them with GodotPckTool or PCK Explorer | no | 0 |
| **Godot built-in PCK encryption** | CI builds **custom export templates** with `SCRIPT_AES256_ENCRYPTION_KEY` for each platform (macOS, iOS, Android, Windows, Linux x64/arm64, Web). Packs are encrypted by `PCKPacker.pck_start(path, 32, key, …)` / `add_file(…, encrypt=true)`, so the pack build itself needs no custom templates | yes, decrypted on the fly | **L:** 6–8 template builds per engine bump (~30–90 min each on CI runners, macOS runners for Apple), cached by (engine, key) hash; the key lives in the binary, so it's deterrence only |
| App-level encryption (AESContext) | encrypt files, decrypt at runtime | no: `load_resource_pack` needs a file path (loading from memory is only a proposal, godot-proposals#5389), so the plaintext would land on disk | rejected |

**Recommendation:** don't encrypt in Phases 1–3. If Vlad wants deterrence later, use built-in
encryption **for the `extra` and `foes` packs only**, and only on channels where we build the
templates. It has to be all channels or none, because the same pack is used everywhere; otherwise
we'd need per-channel pack variants.

**Public repo and forks:** the key is a CI secret. Forks build unencrypted packs from their own
`third_party/` through the same tools, and set `DICEROLL_UPDATE_BASE_URL` and their own manifest
key.

## 8. Hosting and CI

**Hosting:**

- Start with **GitHub Releases** in the public repo, using an immutable `packs` release whose
  assets are `<pack>-<hash>.pck`. They're only uploaded when the hash is new, mirroring
  `assets.py`'s "never delete old bundles".
- The manifests keep using the existing `channels` release.
- Move to **Cloudflare R2** (zero egress, S3 API; `assets.py upload --s3` already supports it)
  behind a custom domain if GitHub rate limits or bandwidth become a concern.
- Unity CCD and PlayFab CDN are engine-agnostic, but they add a vendor for no gain at this size.

**Release workflow changes (`wp-ci-release`):**

1. `assets.py fetch` → import (as today).
2. **New step:** `tools/ci/build_packs.gd` (headless PCKPacker) reads `game/content/packs.gd` and
   writes `build/packs/<id>-<hash>.pck` plus `packs.json`. It fails if a pack contains scripts or
   paths outside its units.
3. Export base presets (with `assets/**` excluded) for each platform:
   - "full" artifacts copy the packs in as sidecars (`packs/` next to the exe, inside the `.app`
     `Resources`, in the Android assets folder, in the iOS bundle);
   - "lean" artifacts don't.
4. Per-channel artifacts:
   - macOS zip/DMG (Developer ID + notarize when available), Windows zip, Linux tar/AppImage x64/arm64;
   - Android APK (sideload, release keystore) and AAB (Play);
   - **iOS unsigned IPA** for SideStore/AltStore: `xcodebuild archive CODE_SIGNING_ALLOWED=NO`,
     then `Payload/Diceroll.app` zipped as `.ipa`;
   - iOS signed build for TestFlight (manual or gated job);
   - Web (lean `index.pck` + `packs/`);
   - Steam depots (steamcmd / `game-ci/steam-deploy` style action) and itch (`butler push` per
     channel). Both are disabled by default, like the store uploads.
5. `update_manifest.py` writes schema 2 (the code pack + `packs{}`), signs it, and uploads new
   packs to the `packs` release.
6. **New:** `altstore_source.py` writes `altstore.json`. It includes both a top-level `downloadURL`
   (SideStore requires it) and a newest-first `versions[]` with `version` = CFBundleShortVersionString,
   `buildVersion`, `date`, `size`, `minOSVersion`. It's uploaded to the `channels` release or GitHub
   Pages so users add one source URL.
7. The CI screenshot job adds boot-stage scenarios. A "packs missing" test boots the base pack alone
   plus each optional pack removed (headless) and asserts no script errors, which reuses the
   free-assets fallback.

## 9. Tooling and frameworks survey (cross-platform content delivery)

| Tool / framework | What it does | Fit for Diceroll |
|---|---|---|
| **Godot built-ins**: `ProjectSettings.load_resource_pack`, `PCKPacker`, `--export-pack`, `--export-patch`/`--patches` (4.4+), delta-encoded patches (4.6+, `patch_delta_*` in our presets) | runtime mounting, programmatic packing, file-level and byte-level patches | **Core of the design.** PCKPacker for unit packs; delta patches could shrink *code* updates further (Phase 4) |
| **Godot Patch Loader** (GDExtension, Ryan-000) | loads `patch_N.pck` at core init so patches can override scripts | not needed: our `--main-pack` relaunch already swaps code; GDExtension adds per-platform binaries |
| **Content Pack Manager** (eumario), **PCK/DLC Manager** | editor plugins that split or export DLC packs | ideas only; our CI-side PCKPacker is simpler and headless |
| **GodotPckTool** (v2.3 supports 4.7 format 4), **Godot PCK Explorer**, GDRE Tools | list, extract and repack PCKs; decompile | **CI verification** (`godotpcktool --action list` to assert no scripts); GDRE shows why encryption is only deterrence |
| **Play Asset Delivery** (Play Core; Godot auto-uses install-time for AAB; no maintained Godot 4 plugin for fast-follow/on-demand) | store-hosted asset packs | not needed below 200 MB; Phase 4 would need a small Android plugin v2 wrapping `AssetPackManager`, then `load_resource_pack(abs_path)` |
| **Apple Background Assets** (managed packs, Apple-hosted from iOS 26; ODR deprecated as of iOS 27) | store-hosted, system-managed downloads | the right iOS path *if* we ever go lean on the App Store; needs a Swift plugin; iOS 26+ only |
| **SteamPipe / steamcmd** | depots, delta patches, DLC depots | ship packs as files in the depot; no custom downloader |
| **butler / wharf** (MIT) | itch uploads; **`butler diff/apply` works offline and self-hosted** (rsync-style blocks + bsdiff, Brotli) | itch channel as-is; could also generate binary *installer* deltas for direct downloads (Phase 4) |
| **Velopack** (MIT, Rust; installer + self-update + zstd delta packages for Win/macOS/Linux; any language via CLI) | whole-app installer and updater | good candidate for the **binary** half on desktop (today we only open a URL). Needs a launcher exe; evaluate after Phase 3 |
| **Sparkle** (macOS) / **WinSparkle** (Windows), EdDSA appcasts | native app self-update | alternative to Velopack for the binary half; conventional and store-free |
| **HDiffPatch / zstd `--patch-from`** | binary deltas between files or folders | only if unit packs become big and change often; today unit packs rarely change, so whole-pack replacement is fine |
| **Unity Addressables / CCD, Unreal ChunkDownloader** | engine-native catalogs + CDN | reference designs: catalog = our `packs{}` manifest; "download dependencies on first launch" + size prompt = our loader |
| **Cloudflare R2**, GitHub Releases, PlayFab CDN, Unity CCD | hosting | GitHub Releases now; R2 later (zero egress) |
| **AltStore/SideStore source JSON**, **Obtainium** | sideload update feeds (iOS / Android) | generate `altstore.json` in CI; Obtainium just tracks GitHub Releases |

## 10. Refactor cost, and "structure now, stream later"

### 10.1 Structure now (Phase 0, ~1 day, no behaviour change)

1. `game/content/packs.gd`: pack → units (the §5.1 table), and `game/content/needs.gd`: content id
   → packs for heroes, enemies/bosses, biomes, pets, gear, minigames and music ids.
2. `Content.available(id)` (always true for now), used by nothing yet or only by the Camp/class
   select badges.
3. Tests (`tests/test_content_packs.gd`):
   - every unit in `assets.lock.json` belongs to exactly one pack;
   - every `res://assets/...` literal and base constant in `game/`, `ui/` and `main.gd` lies under
     a declared unit folder;
   - **no `preload("res://assets` anywhere**;
   - **no `.tscn`/`.tres` references into `assets/`**;
   - **no `uid://` strings pointing into `assets/`**;
   - every id in `core/content/*` (`HeroDefs.IDS`, enemy/biome/pet/gear/minigame ids) has a `needs`
     entry.
4. Size wins: point the Camp at the flat forest folder and drop `forest/color*` from the import
   (−5–8 MB).
5. Fix the display font in exported builds (probable bug, see §12).

### 10.2 Full refactor footprint

| Area | Files | Change | Size |
|---|---|---|---|
| Registry + mount | new `game/content/{packs,needs,content_packs}.gd` | data + mount rules + `available()` | S–M |
| Updater | `game/update/update_manifest.gd`, `update_store.gd`, `update_policy.gd`, `update_client.gd`, `updater.gd` | schema 2, per-pack store and eviction, code pack separate from unit packs | M |
| Boot | `main.gd`, `game/boot/*` (from wp-free-assets), `ui/screens/title_screen.gd`, `game/game_controller.gd` (`show_title` needs only core3d) | BootShell, stages, morph | M |
| Lazy caches | `ui/theme/ui_theme.gd` (font cache reset on mount), `game/audio/audio_bus.gd` (already guarded), `Props._scenes` (clear negative decisions on mount) | small | S |
| Gating | `ui/camp/*`, `ui/screens/class_select.gd`, route and run start in `game/flow/*`, save Continue | `Content.available` badges and prefetch | S–M |
| Camp paths | `game/camp/camp_props.gd`, `camp_scene.gd` | flat forest folder | S |
| CI | `tools/ci/assets.py` (unit→pack hashes), new `tools/ci/build_packs.gd`, `tools/ci/update_manifest.py`, new `tools/ci/altstore_source.py`, `tools/export.sh` (base/full/lean targets), `export_presets.cfg` (base excludes `assets/**`), workflows | per-channel artifacts | M |
| Tests | new content-pack tests, boot-stage scenarios, packs-missing boot test | | S–M |

Total for Phases 0–3 is about **2.5–3.5 agent-weeks**, of which ~40% is presentation (the loader),
which Vlad explicitly wants anyway.

## 11. Phased plan

1. **Phase 0, now (S):** §10.1. It keeps every option open and costs a day.
2. **Phase 1, after `wp-ci-release` merges (M):**
   - Split build: a base preset without assets, plus PCKPacker unit packs.
   - Manifest schema 2 and a per-pack store.
   - Every channel ships packs **embedded**, so there's no network dependence anywhere.
   - Result: self-updates drop from ~70 MB to ~5 MB. Players see no change except faster updates.
3. **Phase 2 (M):** BootShell "gradual upgrade" loader on every channel, replacing
   `MissingAssetsScreen` (the same layout handles missing, offline and error states). Boot-stage
   screenshots.
4. **Phase 3 (M):** remote packs where they pay off.
   - **Web** lazy loading (the biggest user-visible win).
   - Optional **lean** desktop, Android-sideload and SideStore downloads.
   - Pre-run prefetch; resume and eviction.
   - The `altstore.json` source and the unsigned IPA in releases.
5. **Phase 4 (optional, L each, only on a trigger):**
   - encrypted packs (custom templates);
   - PAD fast-follow (if the AAB base exceeds ~150 MB);
   - Apple-hosted Background Assets (if the IPA must shrink);
   - per-biome packs for original art;
   - Velopack or Sparkle for binary self-update;
   - 4.6+ delta patches for code packs.

**Never:** downloading GDScript on store builds; live-ops "events" that need new code outside a
store update.

## 12. Risks and open questions

**Risks:**

- **Stale-pack override:** packs that contain scripts or caches can silently break class
  registration (measured: 180 → 0 classes). The mitigation is data-only PCKPacker packs,
  `replace_files=false` and a CI assertion.
- **Engine upgrades invalidate every pack.** That means a full re-download on self-updating
  channels (~64 MB), once per engine bump. It's acceptable but should be called out in notes.
- **Android specifics** are unverified:
  - mounting packs that sit inside APK assets or nested in the main pack;
  - UI stalls in `load_resource_pack` (godot#105009).
  Prototype this before Phase 3 on Android.
- **Web memory:** `user://` (IndexedDB) files also live in memory, so all packs mounted means
  ~73 MB of RAM on top of the engine. Watch low-end mobile Safari.
- **Testing matrix:** packs present or missing × channel × online or offline. The mitigation is a
  headless "each optional pack removed" boot test plus boot-stage screenshots.
- **App Review:** a lean IPA with a first-launch download could be seen as "not useful without
  download". The mitigation is to ship the whole game in the IPA for v1.
- **Two-key custody:** the manifest RSA key, plus (later) the PCK AES key and Apple/Android signing.
  Losing the Android keystore breaks Obtainium updates forever.
- **Probable existing bug (side finding, verify):**
  - `UiTheme.display_font()` loads `res://assets/fonts/LilitaOne-Regular.ttf` with
    `FontFile.load_dynamic_font()`, which reads the raw TTF.
  - The exported PCK contains only the imported `.fontdata` and the `.import` remap, not the raw
    `.ttf` (checked in the export log).
  - So exported builds probably fall back to the default font for the display face. Either
    `load()` the imported FontFile and set its properties, or add `*.ttf` to `include_filter`.
    Packs must follow whichever fix is chosen.

**Open questions for Vlad:**

1. Approve Phase 0 now and Phases 1–3 after the release pipeline merges?
2. App Store v1: ship all content in the IPA (recommended), or a lean IPA with a disclosed download?
3. Should direct desktop downloads default to **full** (offline-ready, recommended) or **lean**
   (bootstrapper)? Both can be published.
4. Is deterrence encryption of EXTRA packs wanted at all, given CC0 and the L-sized CI cost?
5. Hosting: GitHub Releases on the public repo for packs (which makes the EXTRA-derived packs
   publicly downloadable, just as the shipped game already does), or a private R2 bucket from day one?
6. Apple Developer Program ($99/yr): needed for notarization, TestFlight and non-expiring
   sideload signing. When?
7. Title backdrop: the orbiting **board** (only needs core3d, recommended for the loader), or the
   **Camp** (needs nature + extra, so it would appear later in the loader)?

---

## Appendix A: experiments (headless, scratch copy, Godot 4.7.2)

Scratch copy at `/private/tmp/claude-501/-Users-vlad-Repos-diceroll/stream-exp/` with the
`wp-ci-release` presets.

| # | Experiment | Result |
|---|---|---|
| 1 | `--export-pack` Linux / iOS / Android | 73,174,748 / 73,174,812 / 73,174,748 bytes; gzip 64.2 MB |
| 2 | Base preset excluding `assets/kaykit/forest/*` | 52.8 MB; forest absent at runtime (`exists=false`) |
| 3 | `export_filter="resources"` forest pack | 21.4 MB, **but** includes `tools/shot.gdc`, `game/audio/audio_bus.gdc`, `project.binary`, `uid_cache.bin`, `global_script_class_cache.cfg`; mounting with `replace_files=true` → global classes **180 → 0**; with `false` → 180 |
| 4 | `--export-patch Linux --patches Base.pck` | 20.5 MB forest-only diff (+ the 2 caches); classes stay 180 |
| 5 | Two unit patches (forest, music) against a base without both, mounted in either order | both load, UIDs resolve, classes 180 |
| 6 | **PCKPacker** pack from `.import` + `dest_files` (forest) | 2,654 files, 21.6 MB, **no scripts or caches**; mount 7 ms; loads by path (≈3 ms per gltf); `uid://` not registered |
| 7 | Pack file nested inside the main PCK (`res://packs/forest.pck`) | `load_resource_pack` from `res://` works on desktop |

## Sources

- Apple App Store Review Guidelines 2.5.2, 4.2.3, 4.7: https://developer.apple.com/app-store/review/guidelines/
- Apple Background Assets: https://developer.apple.com/documentation/BackgroundAssets ; managed asset packs: https://developer.apple.com/documentation/backgroundassets/creating-managed-asset-packs ; WWDC25 325: https://developer.apple.com/videos/play/wwdc2025/325 ; ODR size limits and deprecation: https://developer.apple.com/help/app-store-connect/reference/app-uploads/on-demand-resources-size-limits
- Google Play Device and Network Abuse policy: https://support.google.com/googleplay/android-developer/answer/9888379 ; Play Asset Delivery: https://developer.android.com/guide/playcore/asset-delivery ; size limits: https://support.google.com/googleplay/android-developer/answer/9859372
- Godot PAD (install-time, 3.x PR): https://github.com/godotengine/godot/pull/52526 ; Godot 4 PAD discussion: https://forum.godotengine.org/t/is-play-asset-delivery-supported-in-godot-4-2/55900 ; Android `load_resource_pack` stall: https://github.com/godotengine/godot/issues/105009 ; pack-from-stream proposal: https://github.com/godotengine/godot-proposals/issues/5389
- Godot: exporting packs, patches and mods: https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html ; 4.6 delta patching: https://godotengine.org/article/dev-snapshot-godot-4-6-dev-5/ ; patch-export bug: https://github.com/godotengine/godot/issues/102098 ; PCK encryption key: https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_with_script_encryption_key.html
- Reverse-engineering tools: https://github.com/GDRETools/gdsdecomp ; https://github.com/ctrl-kitty/godot-encryption-key-extraction ; GodotPckTool: https://github.com/hhyyrylainen/GodotPckTool ; PCK Explorer: https://github.com/DmitriySalnikov/GodotPCKExplorer
- Godot addons: https://github.com/Ryan-000/godot-patch-loader ; https://github.com/eumario/content-pack-manager ; https://godotengine.org/asset-library/asset/96 ; https://github.com/GeraldGlitch/ggupdater
- AltStore sources: https://faq.altstore.io/developers/make-a-source ; SideStore sources: https://docs.sidestore.io/docs/advanced/app-sources ; SideStore top-level downloadURL issue: https://github.com/SideStore/SideStore/issues/735 ; SideStore FAQ (3 apps / 10 App IDs): https://docs.sidestore.io/docs/faq
- butler offline diff/apply: https://itch.io/docs/butler/offline.html ; wharf: https://itch.io/docs/wharf/
- Velopack: https://velopack.io/ ; Sparkle: https://sparkle-project.org/documentation/ ; WinSparkle: https://github.com/vslavik/winsparkle ; HDiffPatch: https://github.com/sisong/HDiffPatch
- Unity Addressables remote content: https://docs.unity3d.com/Packages/com.unity.addressables@2.7/manual/remote-content-predownload.html ; Unreal ChunkDownloader: https://dev.epicgames.com/documentation/en-us/unreal-engine/implementing-chunkdownloader-in-your-gameplay-in-unreal-engine ; Unity CCD: https://unity.com/products/cloud-content-delivery ; PlayFab CDN: https://learn.microsoft.com/en-us/gaming/playfab/data-analytics/legacy/content-delivery-network/quickstart ; Cloudflare R2: https://www.cloudflare.com/products/r2/
