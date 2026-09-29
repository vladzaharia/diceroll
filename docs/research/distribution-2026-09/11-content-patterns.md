# 11. Content packs and live content: patterns from shipped games, and a model for Diceroll

Date: 2026-09-29. Author: research agent. Status: research plus recommendation. Nothing is implemented.

Scope: how engines and shipped games structure downloadable content packs, and how they deliver new
content and balance changes without a client or binary update. The goal is a pack taxonomy,
granularity rules and a live-content model for Diceroll: Godot 4.7.2, GDScript, one developer,
iOS/iPadOS/Android/macOS/Windows/Linux/Web, ~73 MB of assets, and content defined today as GDScript
const dicts in `core/content/*.gd` (~168 KB of source in total).

This builds on `docs/design/2026-09-29-content-streaming.md` (the "streaming doc"). That doc covers
asset packs grouped by source unit, the loader, the signed manifest and the per-channel matrix. It
keeps **content definitions and rules in the code pack**. This report covers the next step: moving
**definitions** into data, so that new weapons, maps and enemies can ship without a core update.

**Legend for claims:**

- **[V]** verified in this session against the cited primary source (fetched page, official doc,
  or a local copy of Apple's DPLA or guidelines in `research/src/`).
- **[S]** secondary source (wiki, press, community reverse-engineering, forum), or only a search
  snippet of a primary source.
- **[U]** uncertain, or my own inference or design suggestion. Not verified.

---

## 0. Executive summary

1. **Split definitions from assets.** Every engine and every live game studied separates the
   *small, often-changing data* (numbers, pools, unlocks) from the *big, rarely-changing art*.
   - Examples: Unity "Can Change Post Release" vs "Cannot Change Post Release" groups; Minecraft
     behavior packs vs resource packs; Supercell `csv_logic` vs `csv_client` plus assets; Marvel
     SNAP OTAs vs client patches; Hearthstone server-side, then data-only, then client patches.
   - For Diceroll, the recommendation is **one tiny signed `defs` catalog** (all content
     definitions, balance and content strings; ~40 KB compressed), plus **content-hashed asset
     packs**. Definitions reference asset packs, never the other way round.
   - Authoring stays self-contained per "set" (a folder with defs and art). The build splits it
     into a catalog section plus an optional art pack.
2. **Data can only recombine mechanics the client already has.** Every case study draws the same
   line:
   - New *numbers*, *pools* and *content built from existing mechanics* ship as data.
   - New *mechanics* ship in a client update.
   - Examples: Hearthstone server-side patches change only stats and cost; SNAP cards ship in
     monthly client patches and release weekly by server flag; Brotato's Curses mechanic arrived
     in an app update.
   - Diceroll already has the right shape. Items carry `effect: {rule, n: {…}}` and the rules
     live in `core/item_logic.gd`. Formalize this as a **rule registry with capability ids**.
     Each set declares the rules it needs, and clients hide sets they can't run.
3. **Packs are append-only and live in a 1–25 MB band.**
   - New content goes into a new set, plus a new art pack only if it has new art.
   - A fix is a new version of the same pack.
   - Balance is a new defs catalog, never an asset pack.
   - Keep ≤ ~30 active packs. Epic says "10s of paks fine … profile at 30+". Apple-hosted Background
     Assets allows **100 asset-pack IDs per app**. Play allows 100 asset packs per bundle.
   - Compact seasonal packs into library packs at major releases.
4. **Live model in four tiers.** From fastest to slowest:
   - (T0) a signed `live.json`: kill switches, schedule, daily-challenge spec, `min_client`;
   - (T1) the signed `defs` catalog: balance patches and new sets built from existing rules;
   - (T2) asset packs: new art and audio;
   - (T3) a client update: new rules or mechanics, schema majors, engine bumps.

   Don't use Firebase/PlayFab remote config for gameplay data. They are per-user, eventually
   consistent key/value stores, and seeded runs, dailies and leaderboards need **one immutable,
   hash-identified dataset for everyone**.
5. **Determinism.**
   - Every run and every daily is pinned to a `ruleset` (defs catalog hash plus enabled sets).
   - Draw pools from stable-id-sorted, set-filtered lists, using per-system RNG streams derived
     from `hash(run_seed, stream_name)`. Slay the Spire 2 had to fix exactly this in v0.107.1.
   - Never change defs mid-run. Keep the last N defs catalogs cached so saved runs resume on their
     own data.
6. **Delivery.** The fastest path to "no client update" is **our own CDN for defs and live packs
   on every channel**, with native systems where they are strictly better:
   - Steam/itch: pack files in the depot, which SteamPipe delta-patches.
   - Apple-hosted Background Assets: optional, iOS/macOS 26+.
     - Every asset-pack version goes through review.
     - The live version is served to **all** installed app versions.
     - Limit: 100 IDs.
   - Play Asset Delivery: install-time only. PAD packs update only with a new app release.
7. **Store policy.** Data-only packs that add levels, characters and items are consistent with
   Apple 2.5.2 and DPLA §3.3.1(B). Apple's own IAP terms use "additional game levels" as the
   canonical example of in-app content "downloaded … solely as data" (DPLA Attachment 2 §1.1 and
   §2.4). Google restricts *executable* code (dex/JAR/.so), not data. Paid sets need IAP on
   Apple/Google, Steam DLC or the Steam Wallet on Steam, a restore flow, and 3.1.3(b) parity for
   cross-platform entitlements.

---

## 1. Engine reference designs

### 1.1 Unity Addressables

**Groups → bundles.** A group builds one bundle ("Pack Together"), one bundle per asset ("Pack
Separately"), or one bundle per label set ("Pack Together By Label"). Scenes are always split from
other assets. [V: https://docs.unity3d.com/Packages/com.unity.addressables@1.22/manual/PackingGroupsAsBundles.html]

**The primary rule is co-usage.** "The most important rule when organizing your Addressables content
is to create AssetBundles that contain discrete sets of assets that you expect to be loaded and
unloaded together." A bundle can be released from memory only when every asset in it is at
refcount 0. [V: https://unity.com/blog/engine-platform/addressables-planning-and-best-practices]

**Roadmap-driven grouping.** "If your game will require frequent content updates, group your content
in a way that will allow players to download exactly what they need." Labels group growing
collections. Example: a "Halloween 2023" group packed by label into Hats/Shoes/Masks bundles, where
loading the "Halloween 2023" label loads all three. [V: same blog]

**Mobile size guidance (qualitative):**

- "Opt for a group strategy that will build relatively small AssetBundles … Avoid extremely large
  bundles that will consume a substantial amount of memory … avoid a huge number of tiny bundles
  that may create a very large Addressables catalog file that will be downloaded for every content
  update. Many tiny bundles can also have an impact on the speed at which your players can download."
  [V: same blog]
- Unity's iOS ODR page: "The recommended best practice is that an AssetBundle is at most 64MB in
  size." [V: https://docs.unity3d.com/6000.0/Documentation/Manual/ios-ondemand-resources.html]

**Static vs dynamic content** (the most transferable idea) [V: https://docs.unity3d.com/Packages/com.unity.addressables@1.19/manual/ContentUpdateWorkflow.html]:

- *Cannot Change Post Release* (static): "content that you expect to update infrequently … You can
  safely set up these groups to produce fewer, larger bundles since your users usually won't need
  to download these bundles more than once." On an update, changed assets move into a new small
  `content_update_group` bundle. Unchanged assets keep loading from the original bundle, and the
  old copy stays on device as dead data.
- *Can Change Post Release* (dynamic): "a content update rebuilds the entire bundle if any assets
  inside the group have changed … you should typically set up these groups to produce smaller
  bundles containing fewer assets."
- A dependency change rebuilds the whole dependency chain: "when a dependency is changed the entire
  dependency tree needs to be rebuilt."
- "Addressables can only distribute content, not code." [V: https://docs.unity3d.com/Packages/com.unity.addressables@2.3/manual/content-update-builds-overview.html]
- On platforms with their own patching (Steam, Switch), **don't** use content-update builds. Ship a
  full fresh content build and let the platform delta-patch it. [V: ContentUpdateWorkflow 1.19]

**Catalogs.**

- One catalog maps keys to locations. A remote catalog plus a `.hash` file is checked at startup.
  If the hash differs, the new catalog is downloaded and replaces the local one.
  [V: https://docs.unity3d.com/Packages/com.unity.addressables@1.22/manual/build-content-catalogs.html]
- Updating catalogs mid-session conflicts with loaded bundles. Unity recommends updating at init or
  unloading everything first. [V: ContentUpdateWorkflow]
- "Player Version Override": if you use a unique remote catalog name for every new build, you can
  host multiple versions of your content at the same base URL. This means **one catalog per client
  version**, so old clients keep a catalog they understand. [S: search snippet of https://docs.unity3d.com/Packages/com.unity.addressables@2.8/manual/AddressableAssetSettings.html]

**Duplication.**

- The Analyze rule *Check Duplicate Bundle Dependencies* flags assets that are pulled implicitly
  into several bundles.
- The fix is to make the shared dependency explicitly addressable in its own group.
- Caveat: "duplicate assets might not always be an issue." [V: https://docs.unity3d.com/Packages/com.unity.addressables@1.22/manual/AnalyzeTool.html]

### 1.2 Unreal Engine

**Chunks.**

- A chunk is "a numbered collection of assets"; each chunk becomes a `.pak` file (IoStore
  `.utoc/.ucas` in UE5).
- Assets go into chunks through Asset Manager rules or **Primary Asset Labels** (Chunk ID, Priority,
  Cook Rule, "Label Assets in My Directory").
- Secondary assets follow the primary asset that "has authority" over them.
- Chunk 0 is the base game.

[V: https://docs.unrealengine.com/4.27/en-US/SharingAndReleasing/Patching/GeneralPatching/CookingAndChunking/]

**ChunkDownloader** is "a general patching solution intended for games that need to deliver a large
number of small files". [V: https://docs.unrealengine.com/4.27/en-US/SharingAndReleasing/Patching/ChunkDownloader/]

- The client downloads a **manifest** (`BuildManifest-<Platform>.txt`: `$BUILD_ID`, then one line
  per pak with size, version and chunk id).
- It then fetches paks by `ContentBuildId`, which "in a full build you would use an HTTP request to
  fetch".
- Epic's own *Battle Breakers* subclassed PrimaryAssetLabel to add a **Parent Chunk** "that must be
  loaded as a prerequisite". That is an explicit dependency direction.

[V: https://docs.unrealengine.com/4.27/en-US/SharingAndReleasing/Patching/ChunkDownloader/Quickstart/ ;
https://docs.unrealengine.com/4.27/en-US/SharingAndReleasing/Patching/ChunkDownloader/LocalHost/]

**Patching philosophy (Epic staff, 2025)** [S: Epic Developer Community forum answers,
https://forums.unrealengine.com/t/question-about-pak-files-chunking/2599297 and
https://forums.unrealengine.com/t/specify-a-custom-remote-path-for-patch-creation/2568976]:

- The built-in "patch paks" only replace whole assets and accumulate over time. "If you're doing
  many updates … at some point you would want to create a new base release." Epic recommends
  platform binary patching instead (Steam, Epic's BuildPatchTool) between full releases.
- For binary deltas to work, "minimize the changes in the source pak files and keep the order of
  files inside the pak consistent". Often "not compress the pak file and let the platform handle
  compression".
- On pak count: "10s of paks should be fine and I would definitely start to profile once you reach
  the mid double-digits, say 30+."
- BuildPatchTool reuses "chunks matched from previous builds" (a content-addressed chunk store).
  [V: https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/BuildPatchServices/FDirectoryChunkerConfiguration]
  The chunk size isn't documented there. The ~1 MB figure commonly cited is **[U]**.

### 1.3 Godot

**PCK/ZIP resource packs** [V: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_pcks.html]:

- Purpose: DLC, patches and mods, mounted with `ProjectSettings.load_resource_pack(path,
  replace_files=true)`.
- Same-path files **replace** existing ones by default. That is "something to watch out for when
  creating DLC or mods"; pass `false` to opt out.
- Load packs early (from an autoload's `_init`) so preloads see them.
- Security: sign expansion packs with a private key and verify with a public key kept in the main
  pack.
- Paid content: Godot provides no DRM, so copying a PCK can't be prevented.
- **Patch PCKs (4.4+):** export only the files that changed against listed "Base Packs".
  **Delta encoding (4.6+):** byte-level patches (zstd, level 19 by default), with a small per-load
  cost. It needs the *exact* base files in load order, and export non-determinism can break deltas.
  [V: same doc; https://godotengine.org/article/dev-snapshot-godot-4-6-dev-5/]

**Measured in the streaming doc (appendix A):**

- A PCKPacker-built unit pack contains no scripts or caches, mounts in ~7 ms for 20 MB, and is
  independent of the code version.
- An export-filtered pack pulled in autoload scripts and the class cache. Mounted with
  `replace_files=true`, it dropped global classes from 180 to 0.
- So: **data-only PCKPacker packs, mounted with `replace_files=false`.**

**JSON caveat:** Godot's JSON has no integer type ("converting a Variant to JSON text will convert
all numerical values to float types"). Numbers are parsed with `String.to_float()`. Object decoding
is off by default for security. [V: https://docs.godotengine.org/en/4.7/classes/class_json.html]
Definitions loaded from JSON must cast ints explicitly (ids, counts, indices).

**Godot Mod Loader** is the community reference for self-contained content packs. Each mod is a zip
with `manifest.json` (Thunderstore format) and `mod_main.gd`. Fields:

- `namespace-name` id, `version_number`;
- `dependencies`, `optional_dependencies`, `load_before`, `incompatibilities`;
- `compatible_game_version`, `compatible_mod_loader_version`;
- `config_schema` (JSON Schema).

[V: https://wiki.godotmodding.com/guides/modding/mod_files/] Its mods contain *code*, so it's a
version-gating reference only, not a model for store builds.

**Slay the Spire 2** (Godot, Early Access since March 2026) added Steam Workshop mod support in
v0.107.1. [V: https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:V0.107.1_-_Major_Update_2]

### 1.4 Platform delivery systems: facts that constrain granularity

**Apple Managed Background Assets (Apple-hosted or self-hosted; iOS/iPadOS/macOS/tvOS/visionOS 26+):**

- Download policies are essential, prefetch and on-demand. Assets "update … without needing to
  update your main app". Apple's own examples: a tutorial level, "optional downloadable content …
  that you unlock with In-App Purchase". [V: https://developer.apple.com/videos/play/wwdc2025/325]
- **Versions aren't tied to builds.** "Only one version of the asset pack can be live for each
  context … all versions of your app downloaded from the App Store will automatically be switched
  over to using asset pack version 2, including older versions … make sure that it will work on
  older app builds." [V: WWDC25 325; https://developer.apple.com/documentation/appstoreconnectapi/managing-apple-hosted-background-assets]
  **Consequence:** an Apple-hosted pack can't have per-client-version variants. Packs must be
  backward-compatible, or you change the pack **ID** on breaking changes.
- **Each asset-pack version is submitted for review** (TestFlight external and App Store). [V: same]
- The system merges all packs into one shared file namespace, so avoid path collisions. It keeps
  packs updated in the background. `checkForUpdates()` "updates outdated asset packs, and removes
  obsolete asset packs". [V: WWDC25 325; local copy of `AssetPackManager.checkForUpdates()` docs in `research/src/`]
- A downloader extension can veto downloads through `shouldDownload(_:)`, for example "if some of
  your asset packs have specific compatibility requirements". [V: WWDC25 325]
- **Limits** [V: https://developer.apple.com/help/app-store-connect/reference/apple-hosted-asset-pack-size-limits]:
  - total 200 GB per app, counted as the max version size per pack ID;
  - **100 asset packs per app record**;
  - shared across platforms.

  Archived packs didn't free IDs until a fix in January 2026. [V: https://developer.apple.com/forums/thread/810659]
- An app can't use Apple-hosted and self-hosted *Background Assets* at the same time. Plain
  URLSession downloads from your own server alongside Apple-hosted packs are fine. [V: Apple
  Frameworks Engineer, https://developer.apple.com/forums/thread/827100]
- iOS 27 adds localized asset packs, and `ba-package convert` turns a Steam depot manifest into an
  asset-pack manifest. [V: https://developer.apple.com/videos/play/wwdc2026/378]
- ODR is legacy and "will be deprecated". [V: WWDC25 325] ODR allowed 1000 tags.
  [V: https://developer.apple.com/help/app-store-connect/reference/on-demand-resources-size-limits/]

**Google Play Asset Delivery:**

- Modes: install-time, fast-follow and on-demand.
- On an app update, "the patch for the app, including all assets, is downloaded … All
  previously-downloaded asset packs are invalidated", then patched. **PAD packs change only with an
  app release** (new versionCode), even when the code is unchanged.
  [V: https://developer.android.com/guide/playcore/asset-delivery]
- Limits: 1.5 GB per pack, 4 GB install-time total, 30 GB fast-follow/on-demand total, **100 asset
  packs per bundle**. [V: https://support.google.com/googleplay/android-developer/answer/9859372]

**SteamPipe** [V: https://partner.steamgames.com/doc/sdk/uploading]:

- Files are split into ~1 MB chunks and only changed chunks are downloaded.
- Guidance for pack files:
  - keep changes "localized" within a pack;
  - group by level or feature;
  - "add new pack files for updates rather than modifying existing ones";
  - "avoid shuffling asset ordering";
  - put the table of contents at the start or end (absolute offsets cascade);
  - no timestamps or filenames inside the data;
  - compress per asset, not across assets;
  - limit pack size to 1–2 GB.
- DLC depots live in the base app's depot list. DLC content can ship in the base game and be
  ownership-checked (`BIsSubscribedApp` / `CheckAppOwnership`), or live in owner-only depots.
  [V: https://partner.steamgames.com/doc/store/application/dlc]

### 1.5 General rules for pack granularity (synthesized)

| # | Rule | Where it comes from |
|---|---|---|
| G1 | **Co-usage:** a pack is something that is needed and freed as a whole (a screen, a biome, a run set). | Unity "loaded and unloaded together"; Unreal primary-asset authority |
| G2 | **Split by change rate:** rarely-changing art goes in bigger static packs; often-changing data goes in small packs or a catalog. Never put hot data inside a big pack. | Unity static/dynamic groups; Hearthstone, SNAP, Supercell data vs client |
| G3 | **Append-only:** new content goes in new pack files. Fixes are new versions of the same pack. Never reorder or rename inside a pack. | SteamPipe; Epic "keep order consistent"; Unity content-update groups |
| G4 | **Size band:** avoid huge packs (memory, re-download cost, 64 MB mobile guidance) and swarms of tiny ones (catalog growth, request overhead, platform ID caps). | Unity blog; Unity ODR page; Apple and Play caps; Epic "30+ profile" |
| G5 | **Dependency direction:** content depends on a library, and the library on the base. A shared asset moves *down* into a library pack instead of being duplicated. Siblings never depend on each other. | Unity duplicate analysis; Unreal Parent Chunk |
| G6 | **Count budget:** tens of packs, not hundreds. Budget platform ID lifetimes (Apple: 100 per app). | Epic; Apple; Play |
| G7 | **Content addressing and determinism:** a pack's name and version come from the hash of its inputs, so unchanged packs stay cached across client releases and CDN files are immutable. | Unity hashed bundle names; BuildPatchTool chunk reuse; streaming-doc §5.2 |
| G8 | **Rebase periodically:** fold accumulated update packs back into base or library packs at major releases. | Epic "create a new base release"; Unity dead data from content-update groups |
| G9 | **Compatibility unit = catalog version:** the client reads a catalog it understands. Breaking schema changes get a new catalog name or ID, and old ones stay frozen for old clients. | Unity Player Version Override; Apple "all versions get the live pack" |

---

## 2. Live content case studies

| Game (engine) | How new content ships | How balance ships | Needs app update for new content? | Verified |
|---|---|---|---|---|
| **Marvel SNAP** (Unity) | New cards arrive in **monthly client patches** (dataminers find them in patch files), then release weekly by server flag | **OTA** ("Over-the-Air … change the game without a big download"). "We can create an OTA change in about a week, while patch changes need to be made over a month in advance as they require a series of authorizations." OTAs also carry "template and small functionality updates" (text or keyword swaps between existing mechanics) | Yes for the card's code and art (shipped dark ahead of time); no for release timing or numbers | OTA quotes [V: https://marvelsnap.com/april-27th-ota-balance-updates/, https://staging.marvelsnap.com/october-12th-balance-updates/]; functionality tweaks in OTA [S: https://marvelsnap.com/balance-update-july-16-2026/]; weekly release of already-shipped cards [S: https://blog.snap.untapped.gg/new-datamined-cards-marvel-snap-october-2024-season] |
| **Hearthstone** (Unity) | Expansions arrive in client patches | Three tiers: (1) **server-side patch**, where new stats show only in matches in red/green and not in the Collection; (2) a "**data-only patch**" soon after to update the Collection; (3) a full client patch. Players are matched only with players on the same client version. Server-side changes can alter cards mid-game, which "may surprise the player". | Yes for new cards/mechanics | Tiers [S: Blizzard CM text quoted by https://www.dailystar.co.uk/tech/gaming/hearthstone-demon-hunter-nerf-update-21840397]; same-version matchmaking and mid-game changes [V: https://hearthstone.wiki.gg/wiki/Card_changes]; recurring "server-side hotfix patch" posts [S: https://us.forums.blizzard.com/en/hearthstone/t/3441-hotfix-patch/156351] |
| **Clash Royale / Clash of Clans / Brawl Stars** (Supercell, custom engine) | At login the server returns a **fingerprint** (a JSON of files with sha plus a content version) and CDN `assetsUrl`s. The client downloads changed CSVs and assets into `/update`. Data is split into `csv_logic` (rules data) and `csv_client` (presentation data). | Same channel as new CSVs; maintenance breaks; "automatically downloaded and installed the next time players logged in" | New cards/brawlers with new behaviour come with app updates; data and art changes come via fingerprint | Community reverse-engineering [S: https://github.com/123456abcdef/sc-assets-download, https://github.com/Xayz-X/ClashOfClans, https://github.com/smlbiobot/cr]; login download [S: https://www.thesixthaxis.com/2020/06/16/brawl-stars-update-bug-fixes-brawl-pass/] |
| **Genshin Impact** (HoYoverse, Unity) | Version updates: app/launcher update plus a large **in-game resource download**, with pre-install. Hotfixes: "restart the game and update the game resources" | Mid-version value fixes ship as hotfixes, e.g. a character's stamina cost 20→25, with compensation | Version content: yes. Hotfixes: in-game download only | [S: https://pinoygamer.ph/articles/genshin-impact-maintenance-its-to-time-fix-bugs.12234/ (quotes the official notice); https://gamerant.com/genshin-impact-updates-mika-nerf-hotfix-chances/] |
| **Pokémon TCG Pocket** | An app update "prepares for" the next expansion. The set unlocks on its date. "To access … ensure your app is up to date" | Server-side events | Yes (content shipped ahead, unlocked by date) | [S: https://www.iphoneincanada.ca/2026/06/30/pokemon-tcg-pocket-everyday-wonders/, https://nintendolife.com/news/2025/01/psa-pokemon-tcg-pockets-new-expansion-is-here-but-you-can-still-open-old-packs] |
| **Slay the Spire 2** (Godot, Early Access) | Weekly, then bi-weekly **beta-branch patches**, rolled into main. Steam Workshop for mods | In the same patches | Yes (Steam patches) | [V: https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:V0.107.1_-_Major_Update_2]; engine and EA date [S: https://en.wikipedia.org/wiki/Slay_the_Spire_II] |
| **Balatro** (LÖVE/Lua) | Full patches. PC first; consoles "a week or two" later after certification; mobile later | In patches | Yes | [S: https://www.windowscentral.com/gaming/balatro-update-patch-101f] |
| **Vampire Survivors** (moved to Unity) | Each expansion ships **with a numbered patch on all platforms**, and the DLC unlocks the content. Emerald Diorama was free on Steam, consoles, iOS and Android, and even the free DLC is gated behind an in-game 50k-gold unlock "to prevent new players … being overwhelmed" | In patches | Yes | [S: https://vampire.survivors.wiki/w/Version_history, https://vampire.survivors.wiki/w/Updates/Vampire_Survivors:_Emerald_Diorama_is_free_and_out_now, https://poncle.games/emerald-diorama-faq] |
| **Brotato** (Godot; mobile port by Erabit) | Abyssal Terrors (a new **Curses** mechanic, characters, weapons, maps) arrived on mobile as **app update 1.3.542** plus an IAP ("Brotato Abyssal Terrors $2.99"). A second part came in another update 11 days later. The DLC can be toggled off in Options. In the PC code the DLC is data plus methods (`ProgressData.get_dlc_data(dlc_id).curse_item(...)`, `RunData.enabled_dlcs`) | In patches | Yes, because the new mechanic is code | [S: https://www.apkmirror.com/apk/erabit-studios/brotato-2/brotato-2-1-3-542-release/, https://apps.apple.com/us/app/brotato/id6445884925, https://brotato.wiki.spellsandguns.com/Abyssal_Terrors_DLC, mod code in https://github.com/DarkTwinge/Brotato-BalanceMod/issues/10] |
| **Dead Cells mobile** (Playdigious port) | DLC reaches mobile months after PC/console (Return to Castlevania: PC March 2023, mobile June 2023), via app update plus IAP | In patches | Yes | [S: https://toucharcade.com/2023/06/27/dead-cells-return-to-castlevania-dlc-mobile-download-update-iphone-android-price-update-playdigious/] |
| **Cult of the Lamb** | PC/console only. Woolhaven DLC launched simultaneously on all platforms (22 Jan 2026) as a paid DLC with a free patch | Patches | Yes (no mobile version) | [S: https://nintendowire.com/news/2025/08/19/cult-of-the-lambs-woolhaven-dlc-is-coming-to-all-platforms-early-next-year/] |
| **Minecraft Bedrock** (Marketplace; on iOS/Android too) | **Data packs without app updates:** behavior packs (JSON `data`) and resource packs (art) with a `manifest.json` (`uuid`, `version`, `min_engine_version`, `dependencies` on other packs by uuid+version, `modules`, `capabilities`). World templates pin `base_game_version` "to determine what version of the base game resource and behavior packs to apply" | n/a | No for data packs; the engine version gates compatibility | Manifest [V: https://learn.microsoft.com/en-us/minecraft/creator/reference/content/addonsreference/packmanifest]; Marketplace on mobile [S] |

### Patterns

- **P1: Data-driven definitions plus remote assets.**
  - Supercell (fingerprinted CSVs and assets), SNAP (OTA data) and Hearthstone (server-side and
    data-only patches) all keep definitions as data and change them outside client releases.
  - Minecraft goes furthest: whole new content packs as JSON plus art, gated by
    `min_engine_version`.
- **P2: Definitions reference only existing mechanics.**
  - Hearthstone's server-side hotfixes are limited to numbers (cost, stats, durability) and
    offering rates.
  - SNAP OTAs change numbers, and swap between existing keywords or templates ("card" → "character").
  - New mechanics (SNAP cards, Brotato's Curses, VS Glimmers, TCG Pocket features) always come in
    a client patch.
- **P3: Ship dark, release by data.** SNAP ships next month's cards in the patch and releases them
  weekly. TCG Pocket ships the set in an update, then unlocks it by date. This is how live games
  get a weekly cadence despite monthly client releases.
- **P4: Capability or version gating.**
  - Hearthstone matches only same-version clients.
  - Minecraft's `min_engine_version`, Godot Mod Loader's `compatible_game_version`, Unity's
    per-player-version catalogs and Apple's `shouldDownload` veto.
  - Supercell forces an app update when the client version is too old (commonly observed [S]).
- **P5: Forced update when mechanics change.** Every mobile case study with a new mechanic
  (Brotato, Dead Cells, VS) shipped an app update. On Android the native tool is Play In-App
  Updates "Immediate" ("require users to update and restart"). [V: https://developer.android.com/guide/playcore/in-app-updates]
  iOS has no native equivalent. Use a `min_client` gate plus a store link.
- **P6: Opt-in content sets.** Brotato lets players turn the DLC off. VS gates even free DLC behind
  an in-game unlock. This keeps base-game seeds, balance and onboarding stable.
- **P7: Indie premium games mostly don't do live data.** Balatro, StS2, Dead Cells, Cult of the Lamb
  and VS ship everything in patches. Diceroll wanting data-only live content is closer to the
  F2P/live-service pattern (Supercell, SNAP), scaled down.

---

## 3. Balance and tuning delivery

### 3.1 Options

| Mechanism | Strengths | Weaknesses for Diceroll | Facts |
|---|---|---|---|
| **Firebase Remote Config** | Per-user targeting, rollouts, realtime listener, free | Key/value, not a versioned dataset. Default fetch interval is 12 h. Targeting makes users diverge (bad for dailies and leaderboards). Needs an SDK per platform (Godot integration is community plugins [U]); web and desktop parity is uneven | 3,000 params, 2,000 conditions, 1,000,000 chars total. JSON values allowed. Loading strategies: "Avoid this approach [activate on load] in any situation where your UI could change noticeably"; prefer "load new values for next startup". [V: https://firebase.google.com/docs/remote-config/parameters, https://firebase.google.com/docs/remote-config/loading, https://firebase.google.com/docs/remote-config/android/get-started] |
| **PlayFab Title Data** | Simple global key/value, overrides via Experiments | Needs an account or login. Cache: "changes may take up to 15 minutes to refresh … best suited for Global Constant/Static Data and isn't suitable or reliable as Global Variables" | [V: https://learn.microsoft.com/en-us/gaming/playfab/live-service-management/game-configuration/titledata/] |
| **Unity Remote Config / Game Overrides** | Unity-native | Unity-centric; same key/value limits [U] | not researched further |
| **Signed data catalog on our CDN** ("balance patch" = a new defs catalog) | Atomic, versioned and hash-identified, so every client sees exactly the same dataset. Works offline (cached), on every channel, with no SDK. Reuses the existing RSA-signed manifest code (`game/update/update_manifest.gd`) | Needs our own tooling: CI, signing, a rollback pointer | SNAP OTA, Supercell fingerprint and Hearthstone data-only patch are all this pattern |
| **Client update** | Can change anything | Slow (store review, console cert), large downloads | Needed only for new rules |

**Recommendation.** Balance ships as a **new signed `defs` catalog** (tier T1). A tiny signed
`live.json` (T0) carries kill switches, a pointer to the current catalog, the event schedule and
daily specs. Skip remote-config SDKs and A/B tests. If A/B tests are ever wanted, bucket
deterministically by profile id inside `live.json`, and **exclude** dailies and leaderboards.

### 3.2 Implications

- **Seeded runs and dailies.** A seed alone is meaningless unless the data is fixed: "same seed (and
  the same settings/content version)". [S: https://playerunknownproductions.net/news/building-worlds-in-go-wayback]
  - A daily is defined as `(date, seed, ruleset)` where `ruleset = {defs: <catalog hash>, sets:
    [...], rules_api: N}`.
  - Clients fetch that exact catalog by hash (immutable URL) before starting the daily.
  - Leaderboards are keyed by `(daily_id, ruleset hash)`.
  - Hearthstone's same-version matchmaking is the precedent.
  - StS2 had to fix "daily runs diverging based on player network ID" and "Event RNG seeds are now
    consistent across all multiplayer Daily Runs". [V: https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:V0.108.0_-_Beta_Patch (search snippet) and v0.107.1 page]
- **Runs in progress.** Pin every run save to its defs hash. Keep the last N catalogs cached (they're
  tiny) so a resumed run replays on its own numbers. Hearthstone's server-side changes applying
  mid-game and mid-Arena-run is the anti-pattern. [V: https://hearthstone.wiki.gg/wiki/Card_changes]
- **Activation timing.** Download in the background. Activate at the next boot or title screen,
  never mid-run (Firebase strategy 3). Show a "Balance changes" card on first launch after an
  update, as Hearthstone does since patch 5.0. [V: hearthstone.wiki.gg Card_changes]
- **Offline.** Always boot with the last activated catalog, or with the embedded snapshot in the
  binary. Dailies need the catalog they name: offline, allow a "practice" run but no submission.
- **Kill switches.** `live.json.disable: ["item:x", "set:weapons-s2", "minigame:y"]` hides a broken
  piece from pools and shops. Saves keep the ids and the items become inert. `min_client` supports
  a soft nag or a hard gate.
- **Rollback.** Catalogs are immutable and content-addressed, so rollback means pointing `live.json`
  back at the previous hash.

---

## 4. Store policy for data-driven new content

### 4.1 Apple

- **2.5.2:** apps "may not download, install, or execute code which introduces or changes features
  or functionality of the app". [V: https://developer.apple.com/app-store/review/guidelines/, local copy]
  Data interpreted by rules already in the binary (numbers, rule ids, pools, meshes, audio) isn't
  code.
- **DPLA §3.3.1(B) Executable Code:**
  > "an Application may not download or install executable code. Interpreted code may be downloaded
  > to an Application but only so long as such code: (a) does not change the primary purpose of the
  > Application … (b) does not bypass signing, sandbox, or other security features of the OS; and
  > (c) … does not create a store or storefront for other Applications."

  [V: local `research/src/dpla.txt`, https://developer.apple.com/support/terms/apple-developer-program-license-agreement/]
  This matters if definitions ever grow an expression language (e.g. `"dmg": "2*pips+1"`). That
  would be interpreted code: allowed under (a)–(c), but it blurs the "data only" line in 2.5.2 and
  in Play's policy. **Recommendation:** keep definitions declarative (rule id plus params). No
  formulas, no scripts.
- **Apple explicitly treats downloaded levels as in-app content.** DPLA Attachment 2 §1.1: IAP is
  for content "that You make available for use within Your Application (e.g., digital books,
  **additional game levels** …)". §2.4: "An In-App Purchase item must either already exist in Your
  Application waiting to be unlocked, be streamed to Your Application after the In-App Purchase API
  transaction has been completed, or be **downloaded to Your Application solely as data** after such
  transaction has been completed." [V: local `research/src/dpla.txt`]
  - Guideline **3.1.2(a)** lists "new game levels" as appropriate subscription content. [V: guidelines]
  - Apple's Background Assets session pitches updating assets "without needing to update your main
    app" and "optional downloadable content". [V: WWDC25 325]
- **2.3.1(a):** "Don't include any hidden, dormant, or undocumented features … All new features …
  must be described … in the Notes for Review." [V]
  - Shipping *rules* dark and later using them from data (the SNAP pattern) is common practice and
    arguably content, not a feature. The residual risk is low but non-zero **[U]**.
  - Mitigation: state in the Review Notes that "new seasonal content (items, enemies, maps) is
    delivered as data between releases".
- **4.2.3(ii):** "If your app needs to download additional resources in order to function on initial
  launch, disclose the size of the download and prompt users before doing so." [V]
- **4.7** (HTML5/JS mini apps, streaming games, plug-ins) **doesn't apply** to Diceroll's data
  packs. They aren't "software not embedded in the binary". Don't frame packs as "mini-games" in
  metadata. [V text; application is my reading, U]
- **Apple-hosted packs are reviewed** per version. [V: WWDC25 325] Self-hosted data downloads aren't
  reviewed per version, but the content must still comply with the guidelines (1.x content rules,
  2.3.1).
- **Paid packs:**
  - **3.1.1** requires IAP to "unlock features or functionality … game levels, access to premium
    content"; no license keys or QR codes. [V]
  - DPLA Att. 2 §2.6: a non-consumable (e.g. "a sword for a game") must be available on all the
    user's devices, and 3.1.1 requires "a restore mechanism for any restorable in-app purchases". [V]
  - **2.3.2:** say in the description and screenshots which items need purchases. [V]
  - **3.1.3(b) Multiplatform Services:** "may allow users to access content … acquired in your app
    on other platforms or your web site … provided those items are also available as in-app
    purchases within the app." [V]

### 4.2 Google Play

- **Device and Network Abuse:** "An app distributed via Google Play may not modify, replace, or
  update itself using any method other than Google Play's update mechanism. Likewise, an app may
  not download executable code (such as dex, JAR, .so files) from a source other than Google Play.
  This restriction does not apply to code that runs in a virtual machine or an interpreter where
  either provides indirect access to Android APIs (such as JavaScript in a webview or browser)."
  Interpreted code loaded at run time "must not allow potential violations of Google Play policies".
  [V: https://support.google.com/googleplay/android-developer/answer/9888379]
  Data packs are outside this. GDScript in a pack would be interpreted code (the grey zone the
  streaming doc already avoids).
- **Payments:** "Play-distributed apps requiring or accepting payment for access to in-app features
  or services, including any app functionality, digital content or goods … must use Google Play's
  billing system", with alternative-billing exceptions by region. [V: https://support.google.com/googleplay/android-developer/answer/9858738]
  Consumption-only access to content bought elsewhere is allowed. [S: https://support.google.com/googleplay/android-developer/answer/10281818]

### 4.3 Steam

- DLC can be "actual files" or "just a license entitlement". DLC depots sit in the base app, with
  ownership checked via `BIsSubscribedApp` / `CheckAppOwnership`. [V: https://partner.steamgames.com/doc/store/application/dlc]
- In-game purchases on Steam must use Steam microtransactions (Steam Wallet). [S: https://partner.steamgames.com/doc/features/microtransactions]
- Free content packs don't need a DLC app; they can just ship in the base depot.

### 4.4 Cross-platform entitlements (if packs are ever paid)

- Model the entitlement as `set:<id>` in the profile.
- Grant it from Apple IAP (non-consumable), Google Play Billing, Steam DLC ownership, or a web store.
- To honour purchases across platforms (3.1.3(b)), the same set must also be buyable via IAP inside
  the iOS app. Google allows consumption-only access. On Steam, sell only through Steam.
- **Delivery and entitlement are independent:** ship or download the art to everyone and gate by
  entitlement. That's simplest, allowed by DPLA §2.4 ("already exist … waiting to be unlocked"),
  and used by VS and Brotato.

---

## 5. Versioning, compatibility, saves and seeds

### 5.1 Precedents

- **Minecraft** [V]:
  - pack `uuid` and `version`: "the new pack will replace the old one if the version is higher";
  - `min_engine_version`;
  - `dependencies` on other packs by uuid+version, which is how a behavior pack depends on its
    resource pack;
  - `capabilities` (optional engine features);
  - world templates pin `base_game_version`.
- **Godot Mod Loader** [V]: `compatible_game_version[]`, `dependencies`, `incompatibilities`,
  `load_before`.
- **Unity** [V/S]: catalog hash for change detection; catalog named per player version for
  compatibility.
- **Apple-hosted packs** [V]: no per-build pinning, so compatibility must be additive, or a breaking
  change gets a new pack ID.
- **Hearthstone** [V]: matchmaking only within the same client version.

### 5.2 Proposed scheme for Diceroll

**Three numbers the client knows about itself:**

- `client_version` (semver, existing).
- `rules_api`: an integer that bumps whenever the rule registry gains rules or changes parameter
  semantics.
- `defs_schema`: major.minor of the catalog format. The client reads major M only, and minor
  changes are additive.

**Per set (a section of the catalog):**

```json
"weapons-s2": {
  "set": "weapons-s2", "version": 3, "hash": "…", "domain": "armory",
  "min_client": "1.4.0",
  "requires_rules": ["item.on_pair_bonus@1", "item.first_hit_mult@2"],
  "requires_packs": {"lib-armory": "sha256:…", "art-weapons-s2": "sha256:…"},
  "requires_sets": ["armory-base"],
  "entitlement": null,
  "pool_policy": "opt-in-new-runs",
  "retired": [],
  "ids": ["item:frost_flail", "item:gilded_mace", "variant:frost_flail_ember"]
}
```

**Client rules:**

1. **Hide** a set if `min_client > client_version`, if any `requires_rules` entry is unknown to this
   build's registry, or if `defs_schema` major ≠ supported.
   - Optionally show a teaser: "Update Diceroll to get Frost & Gold".
   - CI computes `requires_rules` automatically from the rule ids the set uses, so nobody has to
     maintain it by hand.
2. **Defer** a set whose `requires_packs` aren't mounted yet: badge it "Downloading…" (the streaming
   doc's `Content.available`). Never start a run that needs an unmounted pack.
3. **Catalog naming:** the file is `defs-v<major>-<hash>.json`, indexed by
   `live.json.defs[<major>]`. A breaking change publishes a `v<major+1>` catalog, and old clients
   keep reading the frozen or maintained `v<major>` one. This is Unity's per-player-version catalog
   idea, and it matches Apple's "one live version for everyone" constraint if the catalog is ever
   Apple-hosted (a new pack ID per major).
4. **Asset packs** keep the streaming doc's `engine` + `format` gate. They're rebuilt on engine bumps.

### 5.3 Saves with missing content

- Saves store **ids** (`item:frost_flail`, `set:weapons-s2`), never paths or indices. The streaming
  doc §5.4 already requires this.
- Unknown ids are **preserved verbatim** on load and save (round-trip) and never deleted. In play
  they're inert: an "Unavailable item" placeholder in the Armory, excluded from effects and pools.
  This covers downgrades, kill switches, entitlement loss and sets hidden on old clients.
- **Retire, never remove.** A retired id stays resolvable (name, icon, inert) but leaves every pool.
- A run save carries `{defs_hash, sets[], rules_api}`. If that catalog isn't cached and can't be
  fetched, show "This run needs content (40 KB)", then retry or abandon. Never silently migrate.

### 5.4 Keeping seeds stable when content is added

The **Slay the Spire 2 lesson** [V: https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:V0.107.1_-_Major_Update_2 ;
https://tck.mn/blog/correlated-randomness-sts2/]:

- Each run has one seed, but "a run actually contains multiple PRNGs that individually influence
  your deck draw, your combat rewards, your event choices … Each one uses a seed derived from the
  run seed". The derivation is `seed + hash("niche")` etc.
- With a linear PRNG (C# `System.Random`), streams were correlated; v0.107.1 switched to
  xoshiro256**.
- Writing your own PRNG also guarantees the same seeds on all platforms. In StS1, desktop and mobile
  seeds differed because the standard library's PRNG differed, and a library change "would break
  all past seeds".
- A counter-based generator avoids "advancing" RNGs on load.

**Diceroll's status:**

- `core/rng.gd` is already its own xorshift64* with splitmix64 seeding, so it's platform-independent.
- Local streams are derived per use, e.g. `run_state.gd` `roll_affixes` uses
  `Rng.new(hash([seed, "affix", lap, idx, ids]))`, commented "the run stream is never touched".
- **Remaining risks:**
  - (a) Many draws still come from the single `run.rng` stream. Adding one entry to a pool drawn
    early shifts every later draw ("divergence typically arises when a traditional RNG is called a
    varying number of times … also … when you as the developer modify your code"). [S: https://crates.io/crates/pure_rng]
  - (b) Godot's built-in `hash()` of Variants isn't documented as stable across engine versions
    **[U]**. Derive stream seeds with an explicit stable hash (e.g. FNV-1a or
    `sha256` over a canonical string) so an engine upgrade can't silently reseed runs.

**Rules:**

1. **Streams per system:** `rng_for(run_seed, "loot"|"shop"|"board"|"enemies"|"events"|"affix"|…)`,
   plus a sub-key per decision (`lap`, `tile`, `draw#`). New content only perturbs the stream of
   the pool it joins.
2. **Stable pool order:** build every candidate list sorted by id, filtered by (enabled sets ∩
   unlocked ∩ not disabled ∩ not retired). Never use dictionary insertion or pack load order.
3. **Opt-in sets:** a run's ruleset lists its enabled sets. By default new sets join *new* runs
   (and new dailies) only. Existing saves and shared seeds keep their set list. A shared seed is
   `seed + ruleset id`.
4. **Addition-stable weighted picks (optional, [U] design suggestion):**
   - For each candidate, compute `key = u^(1/w)`, where `u = hash01(stream_seed, draw_id,
     item_id)`, and take the maximum key. This is Efraimidis–Spirakis weighted sampling with a
     keyed hash in place of a stateful RNG.
   - Adding an item changes the outcome **only** for draws the new item wins. Removing one changes
     only draws it used to win. Results don't depend on list order.
   - Cost is O(n) per draw, which is fine for pools of tens to hundreds.
   - This makes "add a weapons pack" nearly seed-preserving even for runs that enable it.
5. **Seasons as sets:** a daily or seasonal ladder names its sets explicitly
   (`["base","armory-base","weapons-s2"]`), so it stays reproducible forever, given the catalog
   hash.

---

## 6. Recommendations for Diceroll

### 6a. Pack taxonomy

**Two layers of asset packs plus one catalog.** Library packs are shared art grouped by source unit
and co-usage (this refines the streaming doc §5.1). Set packs carry new art for a content set.
Every asset pack is data-only PCKPacker, content-hashed, and mounted with `replace_files=false`.

| Layer | Pack id | Contents (current units) | ≈ MB | Change rate | Required? |
|---|---|---|---|---|---|
| binary | **base** | all GDScript incl. **rule registry**; UI scenes/shaders; loader; logo; **embedded defs snapshot** of the build | 4.3 | per client release | yes |
| T1 data | **defs** (catalog) | all set sections: heroes, foes, bosses, biomes (tile mixes, enemy tables), armory, tools, pets, potions, runes/dice, affixes, events, minigame *variants*, unlocks, economy/balance tables, and **content strings per locale** | ~0.15–0.3 raw, ~0.04 gz | weekly–monthly | yes (embedded fallback) |
| T0 data | **live.json** | catalog pointers per schema major, `min_client`, `disable[]`, event schedule, daily specs | < 0.01 | any time | no |
| library | **ui** | fonts, interface/casino/digital sfx, jingles, rendered icons | ~1.8 | rare | yes (stage 1) |
| library | **core3d** | boardgame, animations, adventurers, dungeon, skeletons, platformer, blocks, potions, resource, tools, weapons | ~17 | rare | yes |
| library | **foes** | foes, skeleton_props | ~5.7 | rare | yes for runs |
| library | **nature** | forest (after dedupe) | ~12–20 | rare | per route |
| library | **armory** | weapons_x, tools_x, tools_extra (+ future armor/back parts) | ~3–5 | rare | Armory/Camp |
| library | **props** | dungeon_x, resources(_x), mystery, adventurers_x, halloween | ~9–10 | rare | Camp, minigames, tile props |
| library | **sfx** | impact-sounds, rpg-audio | ~2–3 | rare | soft |
| library | **music-base** | title, camp and launch-biome tracks | ~8 | rare | soft |
| set | **art-\<set\>** (e.g. `art-weapons-s2`, `art-foes-s2`, `art-biome-emberfall`, `art-halloween-2027`) | only *new* meshes, textures and icons for that set | 1–25 | fix-only | if its set is enabled |
| set | **music-\<set\>** | new tracks for a biome or season | 2–10 | fix-only | soft |

**Mapping the proposed domain names** (defs-core, heroes-base, foes-base, weapons-base, armor-base,
biomes-tier1/2/3, audio-*, camp, minigames, seasonal):

- They're the right **set** names (catalog sections): `heroes-base`, `foes-base`, `armory-base`,
  `biomes-t1`, `biomes-t2`, `biomes-t3`, `camp`, `minigames-base`, `halloween-2027`…
- They aren't the right **asset** boundaries. KayKit meshes are shared across domains (Glade uses
  forest + blocks; Crypt uses dungeon + forest rocks + halloween; the Camp uses nature + props +
  armory).
- Per-domain asset packs would duplicate meshes, or force sideways dependencies (G5). So domain
  sets reference library packs, and new *original* art gets per-set art packs.

**Rules: create a new pack, or update an existing one?**

| Change | Action |
|---|---|
| New content using existing art and rules (new weapon variants, new enemy mixes, new biome tile mix, new event from existing ops) | **New set section in `defs`**, no asset pack. Most live content should be this. |
| New content with new art | New set section **plus** a new `art-<set>` pack. If the art is < 1 MB, put it in that season's shared art pack (`art-s<N>`), not in its own pack. |
| New music | a `music-<set>` pack, or the season's shared art pack if small |
| Balance or number change | a new `defs` catalog version. Never touch asset packs. |
| Fix to an existing mesh or texture | a new **version** of the same pack id (new hash, whole-pack replace; ≤ 25 MB keeps that cheap). Paths are never renamed or removed within a pack id. |
| New mechanic (rule, AI behaviour, minigame kind, tile kind) | **client update** (T3). Ship the rule, then the data that uses it. |
| Breaking catalog schema | a new catalog major (`defs-v2`). The old major is frozen for old clients. |
| Engine bump | rebuild every asset pack (the `engine`/`format` gate), once per engine upgrade |
| Removing content | never delete. Mark `retired` in defs, and keep the art until the next compaction. |
| Yearly major release | **compaction:** fold `art-*` set packs into library packs (new library versions) and retire the set pack ids. Set ids in the catalog never change. |

**Target size bands and why:**

- **Asset packs: 1–25 MB, aiming for 3–15 MB.**
  - Upper bound:
    - our own CDN has no binary delta for PCKs unless we adopt Godot 4.6 delta patches, so a fix
      re-downloads the whole pack; 25 MB is acceptable on cellular;
    - Web keeps `user://` in memory;
    - Android `load_resource_pack` stalls (streaming doc);
    - Unity's mobile guidance: avoid huge bundles, ≤ 64 MB for ODR.
  - Lower bound:
    - each pack costs a manifest entry, a signature or hash check, a mount call and an HTTP request;
    - platform ID budgets (Apple: 100 per app lifetime; Play: 100 per bundle);
    - Epic's "profile at 30+";
    - Unity's "many tiny bundles … large catalog … slow download".
  - Only `nature` sits near the top of the band today. Split it only along real co-usage (e.g.
    `nature-glade` vs `nature-moonlit`) if the dedupe leaves it above ~25 MB.
- **Catalog: < 1 MB.** If it ever grows past that, split it by domain under one signed index. It
  stays a single atomic "version" either way.
- **Count budget:** v1 has 8 library packs + defs + base. Growth is about 2–6 set packs per year,
  so compaction yearly keeps active packs ≤ ~20. That's far below every cap, and ~100 Apple IDs last
  well over a decade.

### 6b. Definitions vs assets

**Decision: separate them, with self-contained authoring.**

| Option | Pros | Cons |
|---|---|---|
| A. Each content pack contains its own defs and assets (Brotato-style DLC folder, Godot Mod Loader, a Minecraft combined pack) | One artifact per drop; simple for mods | A balance tweak re-ships art (violates G2). There's no single dataset hash for seeds, dailies and leaderboards. Cross-set references (pools, unlocks) are scattered. Apple-hosted packs would need review for every number change. |
| B. **One tiny defs catalog + asset packs** (Supercell CSV + assets; SNAP OTA; Unity catalog + bundles; Minecraft BP→RP dependency) | Balance ships in a ~40 KB atomic update on every channel, with no review for self-hosted. One hash identifies the ruleset. CI validates all cross-references in one place. Art stays cached forever by hash. | Two things to deliver, so defs must gate on asset availability (§5.2 rule 2) |
| C. **Hybrid (recommended):** author a set as one folder `content/sets/<set>/{set.json, defs/*.json, strings/*.json, art/…}`; CI emits a catalog section plus an optional `art-<set>` pack | A's authoring ergonomics with B's delivery properties | Build tooling needs a small investment |

Details:

- **Format:** JSON (or Godot `ConfigFile`), validated against a schema in CI.
  - Don't use `.tres`: a `.tres` can embed a `GDScript` sub-resource or reference script classes,
    and data-only packs must contain no scripts. A CI check already planned in the streaming doc
    lists pack contents.
  - Cast JSON numbers to int where needed (Godot JSON numbers are floats).
- **Embedded snapshot:** every binary contains the catalog it was built with, so the first launch
  is offline-complete and the downloaded catalog is only an overlay of newer versions.
- **What stays in code:** the **rule registry** (`rule_id → implementation + param schema +
  version`), the mechanics, and the presentation glue. What moves to data: everything that is
  today a `const` dict in `core/content/*.gd`.
  - `items.gd` already fits: `effect: {rule, n: {key: [I, II, III]}}`.
  - Heroes, enemies, biomes and events need their "logic hooks" expressed as rule ids plus params
    in the same way.
- **Sim and tests:** `tools/sim.gd` runs against a catalog file, so CI can simulate any candidate
  balance catalog before publishing (SNAP-style "internal data" before an OTA).

### 6c. The live-content model

| Tier | Artifact | Carries | Latency to players | Where hosted | Review? |
|---|---|---|---|---|---|
| T0 | `live.json` (signed) | kill switches, catalog pointer(s), `min_client`, event/season schedule, daily specs | next launch or poll (minutes) | own CDN (all channels) | no |
| T1 | `defs-v<major>-<hash>.json` (signed, immutable) | balance patches; new sets built from existing rules and existing or new art | next launch | own CDN (all channels) + embedded snapshot | no (self-hosted); guideline compliance still applies |
| T2 | `art-*`, `music-*`, library pack versions | new art and audio | background download; set enabled when mounted | own CDN; Steam/itch depot; optional Apple-hosted BA | Apple-hosted: yes per version. Others: no. |
| T3 | client release | new rules, schema majors, engine bumps, code fixes | store cadence | stores | yes |

Operating rules:

- Every T1 or T2 release is gated in CI:
  - schema valid;
  - all rule ids exist in the registry of every `min_client` the set claims;
  - ids unique and stable;
  - no scripts in packs;
  - the sim passes the balance band;
  - screenshot scenario per new item.
- Publish to a **beta channel** first (`live-beta.json`, switchable from the existing Developer
  menu), then promote by pointer flip. Rollback is a pointer flip back.
- **Ship dark, release by data** (SNAP P3). When a season needs a new rule, ship the rule in the
  client release before the season. Enable content with T0 or T1 on the date.
- Communicate balance changes in-game on first launch after activation (the Hearthstone pattern).
- No A/B tests. No per-user remote config. Everyone on a ruleset sees identical data.

### 6d. How a new weapons pack flows from authoring to players

1. **Author** `content/sets/weapons-s2/`:
   - `set.json` (id, domain `armory`, `min_client`, `requires_sets: ["armory-base"]`,
     `pool_policy`);
   - `defs/items.json` (new items and variants using existing `effect.rule` ids);
   - `strings/en.json` (+ other locales);
   - `art/` (new glb/png) if any.

   If a weapon needs a new rule, that goes into the next client release first.
2. **CI** (on merge to `content/*` or a tag):
   - validate;
   - compute `requires_rules`;
   - run the balance sim;
   - build `art-weapons-s2-<hash>.pck` with PCKPacker (data-only; paths under
     `res://assets/sets/weapons-s2/`);
   - build `defs-v1-<hash>.json` with the new section;
   - sign;
   - render screenshot scenarios;
   - upload to the CDN (immutable, hashed names);
   - write `live-beta.json`.
3. **Test** on the beta channel (Dev menu), on each platform class.
4. **Promote per channel:**

   | Channel | What happens |
   |---|---|
   | **Web, desktop direct, Android sideload, iOS SideStore** | Promote `live.json` to point at the new catalog. Clients fetch the catalog (~40 KB), see that `art-weapons-s2` is missing, download it in the background (Range/resume, verify sha256), and mount with `replace_files=false`. The set appears on the next title/Camp visit. No binary update. |
   | **Google Play** | Same as above, from our CDN (data-only, allowed). Don't use PAD for live packs: PAD packs change only with an app release. Keep PAD, if ever, for install-time base content. |
   | **App Store (iOS/iPadOS/macOS), default** | Same as above, self-hosted over plain HTTPS (allowed alongside anything else). Disclose the size if a download is ever needed before first play (4.2.3(ii)). |
   | **App Store, optional Apple-hosted Background Assets (OS 26+)** | Create asset-pack ID `art-weapons-s2` (on-demand or prefetch). Upload the `.aar` (Transporter or the App Store Connect API), test in TestFlight, then submit for review. Once approved, it's live for every installed version. The catalog still comes from our CDN and enables the set only after `ensureLocalAvailability` succeeds. Mind the 100-ID budget and compatibility with every old build. |
   | **Steam** | Add `packs/art-weapons-s2-<hash>.pck` and the updated catalog to the depot. Push to a beta branch, then default. SteamPipe downloads only the new file (a new pack file rather than a modified one, per Valve). The client can also fetch `live.json` and the catalog, which only changes timing. If paid: a DLC app id with an ownership check. |
   | **itch** | `butler push` the same files (wharf patching). |

5. **Client activation:**
   - `live.json` → catalog → the set passes `min_client`/`requires_rules`;
   - packs mounted → pools rebuilt sorted by id;
   - the set joins **new** runs only;
   - the "New in Armory" card appears;
   - daily challenges name the set explicitly when they include it.
6. **Paid variant:**
   - entitlement `set:weapons-s2`;
   - iOS/macOS non-consumable IAP with a restore flow;
   - Google Play Billing product;
   - Steam DLC;
   - art is downloadable by everyone, and content unlocks by entitlement (DPLA Att. 2 §2.4);
   - store listing notes (2.3.2).

### 6e. What needs code vs what can be data (Diceroll domains)

| Domain | Data-only possible (T1/T2) | Needs client update (T3) |
|---|---|---|
| Armory items, variants, tiers, prices | new items from existing `effect.rule` ids and params; new models | a new effect rule or trigger |
| Heroes/classes, skins | new skin (art); new hero from existing passives or class rules | a new class mechanic |
| Enemies and bosses | new enemy from existing intents or abilities; stat/pool tables; new mesh | a new AI behaviour or boss phase logic |
| Biomes (tile mix, enemy tables, events, dressing) | a new biome that mixes existing tile kinds; dressing from library or new art | a new tile kind or board rule |
| Affixes, runes/dice, potions, pets | from existing ops and params | a new op, or a new pet behaviour |
| Events | a composition of existing outcome ops | a new op |
| Minigames | a new *variant* of an existing minigame kind (params, props) | a new minigame kind |
| Unlocks, economy, shop, balance | all of it | — |

### 6f. Risks and open questions

- **Apple 2.3.1 "dormant features"** when rules ship ahead of their content: low risk, mitigated by
  Review Notes **[U]**.
- **Apple-hosted packs are served to all app versions.** Never make a breaking change under an
  existing pack ID [V]. Budget 100 IDs [V].
- **Godot `hash()` stability** across engine versions is undocumented **[U]**. Move seed derivation
  to an explicit hash before shipping dailies or leaderboards.
- **Android and iOS mounting** of packs from `user://`, and the Android mount stall, are still
  unverified on device (streaming doc §12).
- **Engine upgrades** force a full re-download of all asset packs (~64 MB) once per engine bump on
  self-updating channels.
- **Catalog growth:** keep strings per locale out of the hot path, or split the catalog by domain,
  only if it passes ~1 MB.
- **Open question for Vlad:** default `pool_policy` for new sets. Recommended: "opt-in-new-runs",
  with dailies naming sets. The alternative is "always on after unlock", which is simpler but
  perturbs shared seeds.
- **Open question:** do we ever want paid sets? If yes, decide early on accounts or cross-platform
  entitlements (3.1.3(b) parity).

---

## 7. Sources

**Unity**

- Addressables planning and best practices (Unity blog, 2023): https://unity.com/blog/engine-platform/addressables-planning-and-best-practices [V]
- Content update builds (1.19): https://docs.unity3d.com/Packages/com.unity.addressables@1.19/manual/ContentUpdateWorkflow.html [V]
- Content update builds overview (2.3): https://docs.unity3d.com/Packages/com.unity.addressables@2.3/manual/content-update-builds-overview.html [V]
- Content catalogs: https://docs.unity3d.com/Packages/com.unity.addressables@1.22/manual/build-content-catalogs.html [V]
- Analyze tool: https://docs.unity3d.com/Packages/com.unity.addressables@1.22/manual/AnalyzeTool.html [V]
- Packing groups into bundles: https://docs.unity3d.com/Packages/com.unity.addressables@1.22/manual/PackingGroupsAsBundles.html [V]
- Player Version Override: https://docs.unity3d.com/Packages/com.unity.addressables@2.8/manual/AddressableAssetSettings.html [S]
- iOS ODR (64 MB guidance): https://docs.unity3d.com/6000.0/Documentation/Manual/ios-ondemand-resources.html [V]

**Unreal**

- Cooking and chunking: https://docs.unrealengine.com/4.27/en-US/SharingAndReleasing/Patching/GeneralPatching/CookingAndChunking/ [V]
- ChunkDownloader: https://docs.unrealengine.com/4.27/en-US/SharingAndReleasing/Patching/ChunkDownloader/ , …/Quickstart/ , …/LocalHost/ [V]
- Epic staff forum answers: https://forums.unrealengine.com/t/question-about-pak-files-chunking/2599297 ; https://forums.unrealengine.com/t/specify-a-custom-remote-path-for-patch-creation/2568976 [S]
- BuildPatchServices config: https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/BuildPatchServices/FDirectoryChunkerConfiguration [V]

**Godot**

- Exporting packs, patches and mods (4.7): https://docs.godotengine.org/en/4.7/tutorials/export/exporting_pcks.html [V]
- Delta-encoded patch PCKs: https://godotengine.org/article/dev-snapshot-godot-4-6-dev-5/ [V]
- JSON class: https://docs.godotengine.org/en/4.7/classes/class_json.html [V]
- Godot Mod Loader manifest: https://wiki.godotmodding.com/guides/modding/mod_files/ [V]

**Platforms**

- WWDC25 "Discover Apple-Hosted Background Assets": https://developer.apple.com/videos/play/wwdc2025/325 [V]
- WWDC26 "Unlock in-game content with StoreKit and Background Assets": https://developer.apple.com/videos/play/wwdc2026/378 [V]
- Apple-hosted pack limits: https://developer.apple.com/help/app-store-connect/reference/apple-hosted-asset-pack-size-limits [V]
- Asset-pack versioning: https://developer.apple.com/documentation/appstoreconnectapi/managing-apple-hosted-background-assets [V]
- Apple forums: https://developer.apple.com/forums/thread/810659 ; https://developer.apple.com/forums/thread/827100 [V]
- ODR limits: https://developer.apple.com/help/app-store-connect/reference/on-demand-resources-size-limits/ [V]
- Play Asset Delivery: https://developer.android.com/guide/playcore/asset-delivery [V]
- Play size limits: https://support.google.com/googleplay/android-developer/answer/9859372 [V]
- Play In-App Updates: https://developer.android.com/guide/playcore/in-app-updates [V]
- SteamPipe: https://partner.steamgames.com/doc/sdk/uploading [V]
- Steam DLC: https://partner.steamgames.com/doc/store/application/dlc [V]
- Steam microtransactions: https://partner.steamgames.com/doc/features/microtransactions [S]

**Policy**

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/ [V]
- Apple DPLA (§3.3.1(B); Attachment 2 §§1.1, 2.4, 2.6): https://developer.apple.com/support/terms/apple-developer-program-license-agreement/ [V, local copy `research/src/dpla.txt`]
- Google Play Device and Network Abuse: https://support.google.com/googleplay/android-developer/answer/9888379 [V]
- Google Play Payments: https://support.google.com/googleplay/android-developer/answer/9858738 [V]
- Google Play consumption-only FAQ: https://support.google.com/googleplay/android-developer/answer/10281818 [S]

**Case studies**

- Marvel SNAP: https://marvelsnap.com/april-27th-ota-balance-updates/ [V]; https://staging.marvelsnap.com/october-12th-balance-updates/ [V]; https://marvelsnap.com/balance-update-july-16-2026/ [S]; https://marvelsnap.helpshift.com/hc/en/3-marvel-snap/faq/641-july-30-2026---ota/ [S]; https://blog.snap.untapped.gg/new-datamined-cards-marvel-snap-october-2024-season [S]
- Hearthstone: https://hearthstone.wiki.gg/wiki/Card_changes [V]; https://www.dailystar.co.uk/tech/gaming/hearthstone-demon-hunter-nerf-update-21840397 [S]; https://us.forums.blizzard.com/en/hearthstone/t/3441-hotfix-patch/156351 [S]
- Supercell: https://github.com/123456abcdef/sc-assets-download ; https://github.com/Xayz-X/ClashOfClans ; https://github.com/smlbiobot/cr ; https://www.thesixthaxis.com/2020/06/16/brawl-stars-update-bug-fixes-brawl-pass/ [S]
- Genshin Impact: https://pinoygamer.ph/articles/genshin-impact-maintenance-its-to-time-fix-bugs.12234/ ; https://gamerant.com/genshin-impact-updates-mika-nerf-hotfix-chances/ [S]
- Pokémon TCG Pocket: https://www.iphoneincanada.ca/2026/06/30/pokemon-tcg-pocket-everyday-wonders/ ; https://nintendolife.com/news/2025/01/psa-pokemon-tcg-pockets-new-expansion-is-here-but-you-can-still-open-old-packs [S]
- Slay the Spire 2: https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:V0.107.1_-_Major_Update_2 [V]; https://tck.mn/blog/correlated-randomness-sts2/ [V]; https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:V0.108.0_-_Beta_Patch [S]; https://en.wikipedia.org/wiki/Slay_the_Spire_II [S]
- Balatro: https://www.windowscentral.com/gaming/balatro-update-patch-101f [S]
- Vampire Survivors: https://vampire.survivors.wiki/w/Version_history ; https://poncle.games/emerald-diorama-faq [S]
- Brotato: https://www.apkmirror.com/apk/erabit-studios/brotato-2/brotato-2-1-3-542-release/ ; https://apps.apple.com/us/app/brotato/id6445884925 ; https://brotato.wiki.spellsandguns.com/Abyssal_Terrors_DLC ; https://github.com/DarkTwinge/Brotato-BalanceMod/issues/10 [S]
- Dead Cells: https://toucharcade.com/2023/06/27/dead-cells-return-to-castlevania-dlc-mobile-download-update-iphone-android-price-update-playdigious/ [S]
- Cult of the Lamb: https://nintendowire.com/news/2025/08/19/cult-of-the-lambs-woolhaven-dlc-is-coming-to-all-platforms-early-next-year/ [S]
- Minecraft pack manifest: https://learn.microsoft.com/en-us/minecraft/creator/reference/content/addonsreference/packmanifest [V]

**Remote config**

- Firebase parameters: https://firebase.google.com/docs/remote-config/parameters [V]
- Firebase loading strategies: https://firebase.google.com/docs/remote-config/loading [V]
- Firebase Android get started: https://firebase.google.com/docs/remote-config/android/get-started [V]
- PlayFab Title Data: https://learn.microsoft.com/en-us/gaming/playfab/live-service-management/game-configuration/titledata/ [V]

**Determinism**

- Seeds and content versions: https://playerunknownproductions.net/news/building-worlds-in-go-wayback [S]
- pure_rng (divergence from RNG call counts): https://crates.io/crates/pure_rng [S]
- Efraimidis & Spirakis, "Weighted random sampling with a reservoir", Information Processing Letters 97(5), 2006: from memory, not fetched [U]
