# 06: PC storefront distribution for Diceroll (Godot 4.7.2, content packs)

Research date: **2026-09-29**. Scope: Steam, itch.io, Epic Games Store, GOG, Microsoft Store, plus a short look at the minor stores. It covers how each store's patcher treats a *small core binary plus many small data-only `.pck` packs*, and what the game's per-platform delivery abstraction has to do on each store.

**Legend.** **[V]** = verified this session against the linked page (primary source unless noted). **[V2]** = verified from a reputable secondary source (press or community tool). **[U]** = uncertain, inferred, or from memory. Treat [U] items as things to check before relying on them.

Repo context used: `.github/workflows/release.yml` already has an optional `steam` job (`game-ci/steam-deploy@v3`, `configVdf`, depots 1/2/3 = windows/linux/macos, `releaseBranch` defaulting to `beta`) and an `itch` job (butler, channels `web`/`windows`/`linux`/`mac`, `--userversion`). `docs/design/2026-09-29-content-streaming.md` says that all content is ~73 MB, that PCKs are almost byte-identical across platform presets, that packs are built with `PCKPacker`, and that the downloader is disabled on `distribution=steam|itch`.

---

## 0. TL;DR

| Store | Cost / cut | Content packs map to | Own CDN / in-game updater | CI | Verdict |
|---|---|---|---|---|---|
| **Steam** | $100 per app (recouped after $1k AGR) [V]; 30% cut, tiered [U] | Loose `packs/*.pck` in the depot(s). Free content goes in the **base depot**, not free DLC (Valve's own guidance) [V] | **Disable.** Valve: "use Steam to handle your updates, and do not require users to download content inside your game" [V] | steamcmd + builder account + saved `config.vdf` (or TOTP). Beta branch can go live automatically; **default branch can't** [V] | **#1, do first** |
| **itch.io** | Free; open revenue share, 10% default, adjustable 0 to 100% [V] | Files in each butler channel | Allowed. The itch app patches (wharf); a direct download has no auto-update [V] | butler + `BUTLER_API_KEY` (already done) | **#2, already wired** |
| **GOG** | Curated; 70/30 (60/40 with an advance) [V2] | Files in the build; DLC = separate product [U] | Must be **DRM-free and fully offline**, and Galaxy is optional [V]. Disable the updater | Pipeline Builder CLI (Win/mac/Linux), cached credentials [V] | **#3, pitch early** |
| **Epic** | $100 per product (recouped at $1k) [V]; **100% of first $1M per product per year** since 2025-06-01, then 88/12 [V2] | Files in the artifact; DLC = extra artifact installed into the **same folder** (no path collisions) [V] | Launcher patches. Disable the updater [U: no explicit rule found] | BuildPatchTool with ClientId/Secret (no 2FA pain) [V] | **#4, optional**; needs EOS achievements if Steam has them [V] |
| **Microsoft Store** | Registration free for individuals (since 2025-09) and companies (since 2026-05) [V/V2]; 88/12 for games [V2] | Inside the package (MSIXVC via GDK is recommended); DLC = "durable with package" [V] | **Forbidden**: games "must be installed and updated only through the Store" (policy 10.2.5) [V] | GDK `makepkg`/`makepkg2 upload` (Windows-only toolchain) or `msstore` CLI for MSIX [V] | **#5, defer** (reassess after MSIXVC2 GA, Oct 2026 GDK) |
| Humble / Game Jolt / Newgrounds | n/a | n/a | n/a | manual | Skip (Humble), or web-only marketing (GJ/NG) |

**Key technical takeaway.** Diceroll's split into ~1 to 20 MB data packs is already close to ideal for every store patcher (SteamPipe ~1 MB chunks, MSIX 64 KB blocks, wharf rsync+bsdiff, Epic BPT chunks). Keep packs **uncompressed and unencrypted at the pack level**. Build them **deterministically** (stable file order, no timestamps). Prefer **adding a new pack** over rewriting an old one. Do **not** ship Godot's delta-encoded *patch PCKs* to stores: the store already diffs. Delta patch PCKs are only worth it for the self-hosted updater channel.

---

## 1. Steam

### 1.1 SteamPipe: depots, builds, branches [V]

Source: [Uploading to Steam](https://partner.steamgames.com/doc/sdk/uploading), [Branches](https://partner.steamgames.com/doc/store/application/branches).

- **Depot** = a content container with language and OS filters (`[All OSes]` or a specific OS). **Build** = one upload of an app build script that covers one or more depots. The upload yields a manifest per depot and a global **BuildID**. Depots must be added to packages (including the auto-granted *Developer Comp* package), or the files won't install. The common gotcha: "My Mac and/or Linux builds aren't installing any files" happens because the depot isn't in the package.
- **Branches**: `default` is what customers get. Beta branches can be public or password-protected; the password hides even the branch name. Players switch under *Properties → Game Versions & Betas*. Since 2024 there are in-game APIs to switch branches: `GetCurrentBetaName`, `GetNumBetas`, `GetBetaInfo`, `SetActiveBeta` ([ISteamApps](https://partner.steamgames.com/doc/api/ISteamApps), [PCGamesInsider](https://www.pcgamesinsider.biz/news/74806/valve-introduces-steamworks-apis-for-switching-game-versions/)).
- **Setting live**: the build script's `SetLive` can auto-promote to a **beta** branch only. *"the 'default' branch can not be set live automatically. That must be done through the App Admin panel."* The builds page shows the **update size before you set a build live**, which is a useful manual check.
- The Steamworks **Web API** (publisher key) has `ISteamApps/GetAppBuilds`, `GetAppBetas`, `GetAppDepotVersions` and `SetAppBuildLive` (POST: appid, buildid, betakey). For a *released* app on the public branch it also requires a `steamid` ([ISteamApps WebAPI](https://partner.steamgames.com/doc/webapi/ISteamApps)) [V]. Whether that triggers a mobile confirmation is [U]. Plan on setting `default` live by hand.
- **Builder account**: a dedicated Steam account with only *Edit App Metadata* and *Publish App Changes To Steam*. To set live on a *released* app, that account needs a phone or the Steam Mobile authenticator. Any security change (email or phone) imposes a **3-day** lock on set-live [V].
- **Steam Linux Runtime** is selectable **per branch** under *Installation → Linux Runtime* ([Linux doc](https://partner.steamgames.com/doc/store/application/platforms/linux)) [V].

### 1.2 How delta patching works [V, with the gaps marked]

From [Uploading to Steam](https://partner.steamgames.com/doc/sdk/uploading):

- *"SteamPipe initially splits each file into roughly one megabyte (MB) chunks. Each chunk is then compressed and encrypted."* When building an update, it *"searches to find any such chunks that match the previous build"*. Build step 5: *"Each file is scanned and divided into small chunks of about 1MB. If the depot has been built before, this partitioning will preserve as many of the unchanged chunks as possible."*
- **Chunking algorithm details are not public.** It is not documented as content-defined chunking (CDC). Valve's own warnings (TOC offsets, sub-MB reordering) show that matching works on whole ~1 MB chunks. On the client side, manifests let an old chunk be copied from a different offset in the old file ([DepotDownloader analysis](https://deepwiki.com/SteamRE/DepotDownloader/3.2.3-file-validation-and-integrity), [V2]). So *shifted* data can be reused **if** the builder found it, and Valve's wording suggests the builder does search. Third-party estimators (e.g. [cavs-steam](https://crates.io/crates/cavs-steam), [V2]) conservatively model fixed 1 MiB chunks at fixed offsets, where a 100 KiB insert at the front means re-downloading the whole pack. **Plan for the conservative model** [U about the real algorithm].
- The client **rebuilds every touched file in full** alongside the old one, then commits. So a 10-byte change to a 25 GB pack means 25 GB of local I/O. That's why Valve says to limit pack size (1 to 2 GB is plenty) and scope packs by level or feature [V].
- Valve's pack-file guidance, quoted [V]:
  - "Ensure asset changes are localized within the pack file"
  - "Avoid shuffling asset ordering"
  - "limit pack file size"
  - "group assets by level / realm / feature into their own pack files, and **consider adding new pack files for updates instead of modifying existing ones**"
  - "do not include any original filenames or file / build timestamps for each asset"
  - TOC: *"Ideally, there is one TOC or TOC tree near the beginning or end of the file."* Distributed TOCs with absolute offsets are "catastrophic".
  - **Compression:** *"we generally don't recommend using general compression on pack files"*. If you do compress, keep it per-asset. **Encryption:** "most likely unnecessary, and with the same risks".
  - Unreal-only: use 1 MiB padding alignment so re-alignments shift by multiples of the chunk size. Valve also has an "alternate build algorithm" it can enable on request.

### 1.3 What that means for Godot `.pck` [V from Godot source]

From Godot `master` [`core/io/file_access_pack.h`](https://github.com/godotengine/godot/blob/master/core/io/file_access_pack.h), [`core/io/pck_packer.cpp`](https://github.com/godotengine/godot/blob/master/core/io/pck_packer.cpp) and [`editor/export/editor_export_platform.cpp`](https://github.com/godotengine/godot/blob/master/editor/export/editor_export_platform.cpp). 4.7.2 is assumed to match master for these parts [U].

- PCK format v3/v4 has a small header, then file data, then **one directory (TOC) at the end** (`dir_offset` is patched into the header). Offsets are **relative to the file base** (`PACK_REL_FILEBASE`), and per-file MD5 is stored. There are **no timestamps**. This is exactly the "single TOC at the beginning/end" layout Valve wants.
- Alignment: the editor export pads each file to **16 bytes** (`PCK_PADDING = 16`). `PCKPacker.pck_start(path, alignment=32, key, encrypt_directory)` defaults to **32**. Files are written in the order you `add_file()` them, and the directory is sorted.
- Pack-level **encryption** (`PACK_DIR_ENCRYPTED`, `PACK_FILE_ENCRYPTED`) exists. **Don't use it for store builds**: it defeats deltas, and Valve discourages it.
- Per-resource compression happens *inside* resources, not across the pack: VRAM/lossless textures, and GDScript "compressed binary tokens". Per Valve, per-asset compression is acceptable. Per the Godot delta-encoding PR, compressed resources diff poorly, which is another reason to keep changes localized ([PR #112011](https://github.com/godotengine/godot/pull/112011)).
- Godot 4.4 added **patch PCK export** (`--export-patch`, Base Packs; [PR #97118](https://github.com/godotengine/godot/pull/97118), merged 2024-09-26) [V]. Godot 4.6 added **delta-encoded patch PCKs** (zstd `--patch-from`, `PACK_FILE_DELTA`; [PR #112011](https://github.com/godotengine/godot/pull/112011), merged 2025-11-26) [V]. These are **for self-hosted patching**. On stores they add runtime patch-application cost and a fragile base-pack chain, and they duplicate what SteamPipe, wharf and MSIX already do. **Ship full (regenerated) packs to stores.**
- Old gotcha: UPX-compressed Godot binaries defeated Steam deltas ([godot#4108](https://github.com/godotengine/godot/issues/4108)) [V]. Don't UPX or otherwise compress the core binary. Also don't **embed the PCK in the executable** for store builds: keep core code/UI in a sidecar `.pck` so that binary-only and data-only changes stay isolated.

**Concrete rules for Diceroll packs (all stores):**
1. In the PCKPacker tool, **sort input paths** and add them in a stable order. New assets then land at predictable positions. Optionally append new files at the *end* instead of sorting them in (this matters under the conservative fixed-chunk model) [U: benefit depends on SteamPipe's real matcher].
2. Keep packs **≤ ~20 MB** (they already are). The worst case is then re-downloading one small pack. Never let one pack grow into a "catch-all".
3. **New content = new pack** (e.g. `weapons-2026-10.pck`). Avoid rewriting `weapons-base.pck` for additions.
4. No pack-level compression or encryption on store builds. Keep the manifest (hashes, sizes) as a separate small file.
5. Verify deterministic output in CI: export twice, then `cmp`. Optionally run [`cavs-steam compare`](https://crates.io/crates/cavs-steam) [V2] or `butler push-preview` to estimate update size, and check Steamworks' "update size" before setting live.

### 1.4 DLC vs base depot; optional packs [V]

From [DLC doc](https://partner.steamgames.com/doc/store/application/dlc) and [Updating Your Game: Best Practices](https://partner.steamgames.com/doc/store/updates).

- Valve's explicit guidance: *"**Free content ⇒ part of the game.** If you intend for the content to be free … simply include that new content as part of your base game's content … (as would be the case if you released your update as free DLC)"*. Small paid items belong in microtransactions or the Inventory Service. Large paid content is DLC.
- DLC is its own app ID. DLC depots live in the **base app's** depot list, and the DLC files install into the base game's folder. The game checks ownership with `BIsSubscribedApp`/`BIsDlcInstalled`. Steam only downloads new DLC content if the user runs the newest game version.
- **Optional, on-demand content:** you can create **up to 10 DLCs as "downloadable chunks"** with *"Disable Steam automatically downloading this DLC"*. Include them in the store packages and trigger `ISteamApps::InstallDLC` / `UninstallDLC` / `GetDlcDownloadProgress` / `DlcInstalled_t` from the game. This is the only Steam-native way to have *optional* packs (e.g. an HD audio pack), and each still needs a DLC app entry.
- **Recommendation:** all Diceroll content packs (`weapons-*`, `biomes-*`, `foes`, `audio`) go in the **base depot(s)**. Use DLC only for (a) actual paid expansions or (b) at most a couple of *optional* large packs (e.g. a lossless soundtrack) via the no-auto-download DLC route.
- **Depot layout options:**
  - (A) Keep today's 3 OS depots and put `packs/` in each. Users only download their OS's depot, so this is simplest.
  - (B) Add a 4th **"content" depot set to `[All OSes]`** holding `packs/*.pck`, since the design doc measured the PCK as byte-identical across presets except for 64 bytes. This saves CI upload time and guarantees identical packs on every OS. Choose B only if the packs are *byte-identical* across the desktop presets (texture VRAM formats: S3TC/BPTC vs ETC2/ASTC for Apple Silicon [U]).
  - On macOS, put `packs/` **next to** `Diceroll.app`, not inside it. Adding or changing files inside a signed bundle breaks the code-signature seal. Steam doesn't quarantine files, so Gatekeeper usually won't complain, but it's cleaner [U: reasoning]. The Linux and Windows depots can use `packs/` next to the executable.

### 1.5 Steam Workshop (UGC)

Relevant only if Diceroll later wants **player-made content packs**. Workshop items download to a per-item folder, and the game enumerates subscribed items via `ISteamUGC` and mounts them. Workshop item versioning by game branch now exists ([doc](https://partner.steamgames.com/doc/features/workshop/itemversioning), [V]). Risk: a Godot `.pck` can carry GDScript. Reuse the design doc's "data-only pack" validator (reject `.gd`, `.gdc`, `.remap` to scripts) before mounting any UGC. **Not needed for launch.**

### 1.6 Steamworks in Godot 4.7

- **GodotSteam** moved to **Codeberg** (`codeberg.org/godotsteam/godotsteam`). The GitHub repo is **archived** and read-only, holding overflow files only ([GitHub](https://github.com/GodotSteam/GodotSteam), [migration blog](https://godotsteam.com/blog/category/migration/)) [V]. Latest is **v4.22.1 (2026-09-04), Steamworks SDK 1.65**. It ships as a **module** (prebuilt editor and templates for Godot **4.7.2** and 4.5.2) and as a **GDExtension `v4.22.1-gde` for Godot 4.4+** ([Codeberg releases](https://codeberg.org/godotsteam/godotsteam/releases), [Asset Library](https://www.godotengine.org/asset-library/asset/edit/11743)) [V]. v4.22 merged the GDExtension branch into the main Godot 4 branch ([changelog](https://godotsteam.com/changelog/godot4/)) [V]. **Update any CI that downloads GodotSteam from GitHub releases.** For Diceroll, the **GDExtension** keeps stock export templates. The module needs GodotSteam's custom templates.
- Relevant GodotSteam API (`Steam` singleton): `isDLCInstalled(id)`, `getDLCCount()`, `getDLCDataByIndex(i)`, `installDLC(id)`, `uninstallDLC(id)`, `getDLCDownloadProgress(id)`, `getAppInstallDir(app_id)`, `getAppBuildId()`, `getCurrentBetaName()`, `getInstalledDepots(app_id)`, `isSubscribedApp(id)`, `markContentCorrupt(missing_only)`, and signal `dlc_installed` ([Apps class](https://godotsteam.com/classes/apps/)) [V].
- **macOS export for Steam** ([GodotSteam mac export](https://godotsteam.com/tutorials/mac_export/)) [V]: enable the `disable-library-validation` and `allow-dyld-environment-variables` entitlements, which Valve lists as needed for the overlay and Steamworks ([Platforms doc](https://partner.steamgames.com/doc/store/application/platforms)). Steam is **incompatible with the App Sandbox entitlement**. Re-sign the GodotSteam framework whenever you update it.
- **Steam Cloud**: Auto-Cloud (paths configured in Steamworks, no code) or the ISteamRemoteStorage API. Set a quota. For cross-platform saves, use **one root plus per-OS root overrides**, because separate per-OS roots partition saves ([Cloud doc](https://partner.steamgames.com/doc/features/cloud)) [V]. Point it at Diceroll's `user://` save folder, not the pack cache.
- **Steam Input**: Godot 4.5+ uses **SDL3** for joypads ([4.5 beta 2](https://godotengine.org/article/dev-snapshot-godot-4-5-beta-2/)) [V2], so Steam Input's virtual pads just work. For Deck "Verified", glyphs must match the active device. Valve *strongly recommends* the Steam Input API for glyphs, and text entry must use the Steamworks on-screen keyboard or a controller-usable built-in keyboard ([Deck compat](https://partner.steamgames.com/doc/steamdeck/compat)) [V]. GodotSteam exposes `showGamepadTextInput` / `showFloatingGamepadTextInput` [U: names].
- **Steam Deck / Steam Machine compatibility** [V] ([doc](https://partner.steamgames.com/doc/steamdeck/compat)). Reviews now cover **Deck, Steam Machine and third-party SteamOS devices**, and *Deck Verified implies Machine Verified*. Verified needs:
  - a controller default config that reaches everything, with no settings toggles needed
  - matching glyphs and controller text input
  - 30 fps at 800p (Deck) or 1080p (Machine) by default
  - no "unsupported OS/GPU" warnings, no non-controller launchers, and ≥9 px text at 1280×800 (12 px recommended)
  
  You can request a review of an unreleased game after the build review. Results auto-publish after about a week.
- **Linux runtime** [V] ([steam-runtime README](https://github.com/ValveSoftware/steam-runtime/blob/master/README.md), [GamingOnLinux 2025-11](https://www.gamingonlinux.com/2025/11/valve-put-up-a-new-steam-linux-runtime-4-0-with-a-move-towards-64-bit/)): **Steam Linux Runtime 4.0 (steamrt4, Debian 13, x86_64-only libs) is now the recommended runtime for new native Linux games.** SLR 3.0 'sniper' is older, and the *default for a new native game is still legacy scout* unless you change it. Proton 11+ also uses steamrt4. **Action:** ship the native Linux build (Godot's templates are portable), select **SLR 4.0** (or 3.0 sniper if 4.0 misbehaves) in *Installation → Linux Runtime*, and test on a Deck. Godot dlopens X11/Wayland/Pulse/ALSA/udev/fontconfig/dbus, which should be present in steamrt4 [U: test]. Proton is the fallback if the native build has a Deck issue.
- **macOS on Steam**: Valve's platform page still says *"Starting October 14th, 2019 Steam will require all new macOS Applications to be 64-bit and notarized"*, and there is an "App Bundles Are Notarized" checkbox [V]. In practice Steam-launched apps aren't quarantined and GodotSteam says notarization is "not strictly necessary" [V2]. **Diceroll's CI already signs and notarizes when secrets exist, so keep doing it.** Set the macOS launch option to the **`.app` bundle** (not the inner binary) so Apple Silicon launches the native arm64 slice ([Uploading doc](https://partner.steamgames.com/doc/sdk/uploading)) [V].
- **Steam Playtest**: a free child app ID with sign-ups on the main store page, key distribution possible, and a store review limited to capsules and icons ([doc](https://partner.steamgames.com/doc/features/playtest)) [V]. Use it for pre-launch tests instead of a public beta branch.

### 1.7 Fees, onboarding, review [V]

- **Steam Direct fee $100 per app**, non-refundable, **recouped after $1,000 AGR** ([appfee](https://partner.steamgames.com/doc/gettingstarted/appfee)). Onboarding requires identity, bank and tax details (tax verification takes 2 to 7 business days).
- First-title timing: **30 days** from paying the fee to release, and a public **"Coming Soon" page for ≥2 weeks** ([onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding), [releasing](https://partner.steamgames.com/doc/store/releasing)).
- **Store page review and build review each take ~3 to 5 business days. Plan for 7.** After approval, updates need no further review ([review](https://partner.steamgames.com/doc/store/review_process)).
- Revenue share: 30% → 25% after $10M → 20% after $50M [U: long-standing Valve terms, not re-verified].

### 1.8 CI uploads: steamcmd, builder account, Steam Guard

- **No new token-based upload method exists as of 2026-09** [V: the Steamworks upload doc only describes steamcmd/SteamPipeGUI; nothing new found]. The CI flow is still: log in once interactively with the Steam Guard code, then persist `config/config.vdf`. *"If you do login again and provide your password, a new SteamGuard token will be issued."* The troubleshooting fix is `set_steam_guard_code` ([Uploading](https://partner.steamgames.com/doc/sdk/uploading)) [V].
- `game-ci/steam-deploy`: last tagged release **v3.2.1 (2024-08-18)**. The README on `main` says the action now shells out to `game-ci/cli deploy steam` and that **`password` is now always required** [V]. Refresh `STEAM_CONFIG_VDF` when you get a Steam Guard email in CI or see "License expired". The `default` branch doesn't work as `releaseBranch` ([game.ci docs](https://game.ci/docs/github/deployment/steam/)) [V]. The `totp` input (a shared secret from a mobile-authenticator builder account) avoids token expiry.
- **Security:** in July 2025, two popular `setup-steamcmd` actions leaked `config.vdf` auth tokens in job logs: [GHSA-c5qx-p38x-qf5w](https://osv.dev/vulnerability/GHSA-c5qx-p38x-qf5w) (RageAgainstThePixel <1.3.0) and [GHSA-mj96-mh85-r574](https://osv.dev/vulnerability/GHSA-mj96-mh85-r574) (buildalon <1.1.0) [V]. **Pin actions by SHA and never `cat` `config.vdf`/`localconfig.vdf`.**
- Recommended CI changes for Diceroll:
  1. Keep `game-ci/steam-deploy@v3`, pinned to a commit SHA. Or replace it with a ~30-line script: SDK `builder_linux/steamcmd.sh +login $U +run_app_build app_build.vdf +quit`, with explicit `FileExclusion "*.pdb"` and so on. That gives you `Preview "1"` dry runs.
  2. Always `SetLive` to a **password-protected `beta`** (or `staging`) branch. Promote to `default` manually in App Admin after checking the displayed update size.
  3. Optionally add the shared `[All OSes]` content depot (§1.4 option B).
  4. Store the builder's Steam Guard via TOTP if the builder uses the mobile authenticator, which set-live on a released app requires anyway.

### 1.9 In-game downloading from your own CDN on Steam

Not strictly banned, but Valve says: *"It is important that you use Steam to handle your updates, and do not require users to download content inside your game after it has launched."* ([updates](https://partner.steamgames.com/doc/store/updates)) [V]. Deck Verified also dislikes launchers, and an extra download at first launch breaks offline play. **Keep `distribution=steam` → updater disabled and no remote packs**, which matches the design doc.

---

## 2. itch.io

- **butler/wharf** ([pushing](https://itch.io/docs/butler/pushing.html)) [V]:
  - `butler push <dir|zip> user/game:channel`.
  - Client-side diff is **rsync-style over fixed-size blocks plus fast Brotli**. The build is live immediately with that *default patch*. The backend then regenerates an **optimized patch with bsdiff plus high-quality Brotli**, which can take ~30 min for large games.
  - Channel names drive platform tags (`win`/`windows`, `linux`, `mac`/`osx`, `android`).
  - Useful flags: `--userversion`/`--userversion-file`, `--if-changed`, `--hidden` (new channels only), `push-preview` (a per-file NEW/MODIFIED/DELETED classification, handy for PR checks), and `--dry-run`. Builds are capped at 30 GB uncompressed.
  - The unauthenticated `GET https://api.itch.io/wharf/latest?target=user/game&channel_name=…` returns the latest user-version, for "update available" prompts.
- **itch app** is actively maintained again [V]: v26.6.0 (Feb 2026, native arm64 macOS) → v26.12 (May 2026: in-app butler **Upload/Builds GUI**) → v26.17/26.18 (Jul/Aug 2026: per-game launch settings, bundles). butler is at **v15.30.0** ([changelog](https://github.com/itchio/itch/blob/master/CHANGELOG.md), [May 2026 post](https://itch.io/updates/pushing-builds-with-butler-is-now-in-the-itch-app), [butler releases](https://github.com/itchio/butler/releases)). **New in butler 15.2x: every game launched by the itch app gets `ITCHIO_APP=1` in its environment.** The delivery layer can use this to tell "itch app (auto-updated)" apart from "direct download (never updated)".
- **Web games** ([HTML5 doc](https://itch.io/docs/creators/html5)) [V]:
  - Limits: ZIP **≤1,000 files**, **≤500 MB** extracted, **≤200 MB per file**, and paths ≤240 chars. Limits can be raised on request.
  - The CDN gzips `.pck` and `.wasm` automatically, and `.br` files are served with `content-encoding: br`.
  - Web games are **donation-only** (paid needs a "Downloadable" project).
  - The opt-in "SharedArrayBuffer support" embed option exists, but Godot 4.3+ single-threaded web exports don't need it ([itch post](https://itch.io/t/2025776/experimental-sharedarraybuffer-support)) [V].
  
  Remote lazy packs on the web build must stay same-origin, inside that ZIP, and count toward the 1,000-file cap.
- **Money** ([payments](https://itch.io/docs/creators/payments), [FAQ](https://itch.io/docs/creators/faq)) [V]:
  - Free to use; minimum price can be 0 (**pay-what-you-want**).
  - **Open revenue share 0 to 100%, default 10%**, plus PayPal/Stripe fees (~$0.30 + 2.9%).
  - "Collected by itch.io" makes itch the merchant of record (handles VAT and chargebacks, $5 minimum payout).
  - Download keys cover press and backers. There's no DRM. New accounts have a soft limit of 20 projects and ~10 files per page.
- **Mapping and policy:** packs are just files in each channel, and wharf patches per file. There are no rules against self-updaters. **Recommendation:** leave the updater off for the itch *desktop* builds, as today. Optionally, when `ITCHIO_APP` is **unset** (direct download), show a non-invasive "new version on itch" prompt using `wharf/latest`, never self-patching.

---

## 3. Epic Games Store

- **Self-publishing** via the Dev Portal. You must be **18+**. Trader verification, tax interview and Hyperwallet payout setup can take **>2 weeks** ([finance](https://dev.epicgames.com/docs/epic-games-store/publishing-tools/organization-management/manage-finance)) [V]. **$100 submission fee per product, recouped after $1,000** of EGS revenue ([org mgmt](https://dev.epicgames.com/docs/epic-games-store/publishing-tools/organization-management/manage-org)) [V].
- **Revenue:** since **2025-06-01**, developers keep **100% of the first $1M net revenue per product per year**, resetting each Jan 1, and 88/12 after that. It applies to Epic-processed payments on PC, Mac and mobile. Epic First Run (exclusivity) gives 100% for 6 months ([Epic news](https://store.epicgames.com/news/epic-games-store-updates-revenue-share-keep-100-of-the-first-1m-per-product-per-year), [V2 via search snippet; page 403'd to the fetcher]).
- **Requirements** ([requirements overview](https://dev.epicgames.com/docs/epic-games-store/requirements-guidelines/distribution-requirements/requirements-overview), [before you begin](https://dev.epicgames.com/docs/epic-games-store/get-started/get-started-steps/before-you-begin)) [V]:
  - **Achievements parity:** *"If a product supports achievements through other PC storefronts … that product must also support Epic Games Store achievements … substantially similar."* This applies to products onboarded after 2023-03-09. So **Steam achievements ⇒ EOS achievements required.**
  - **Crossplay:** online multiplayer must crossplay across all PC stores. Not applicable to single-player Diceroll.
  - **Patch notes** are required for "major" updates, which also go through review. Bugfix and minor updates don't need review ([artifacts](https://dev.epicgames.com/docs/epic-games-store/store-presence/manage-artifacts)).
  - Ratings: IARC is free via the portal and required for some regions (DE, AU, BR, RU; KR needs GRAC).
- **BuildPatchTool (BPT)** [V] ([BPT 1.6 instructions](https://dev.epicgames.com/docs/epic-games-store/publishing-tools/uploading-binaries/bpt-instructions-160)):
  - `-mode=UploadBinary` takes `-OrganizationId -ProductId -ArtifactId -BuildRoot -CloudDir -BuildVersion -AppLaunch -AppArgs`, plus optional `-FileIgnoreList`, `-FileAttributeList` and prereqs.
  - Auth is a **BPT-specific ClientId plus `-ClientSecretEnvVar`**, with **no 2FA**, which makes it CI-friendly.
  - Patching: a *"general patching system … update any version … to any other version, minimising the download size"*. Optional `-mode=BinaryDeltaOptimise -BuildVersionA -BuildVersionB` builds A→B-specific smaller patches.
  - BPT is a chunked system. It is believed to use rolling-hash matching (Unreal BuildPatchServices) [U].
  - Tool OS: the docs show `Engine\Binaries\Win64\BuildPatchTool.exe`. Mac and Linux binaries are [U], so plan for a Windows runner.
  - After upload, attach the binary to the artifact and set it active in the portal.
- **DLC** [V] ([BPT 1.5 DLC section](https://dev.epicgames.com/docs/epic-games-store/publishing-tools/uploading-binaries/bpt-instructions-150), [offers](https://dev.epicgames.com/docs/epic-games-store/store-presence/manage-offers)):
  - An add-on *optionally* has its own artifact. Each DLC artifact is uploaded separately with its own ArtifactId, and *"the main game and all items of related DLC will be installed into the same directory … there must be no files … which share a common file path."*
  - Ownership: `EOS_Ecom_QueryOwnership` (not `QueryEntitlements`).
  - Launcher args include `-epicdeploymentid` and `-epicsandboxid`.
  - Diceroll's unique pack filenames already satisfy the no-collision rule.
- **Platforms:** EGS self-publishing covers Windows and macOS (plus mobile). **There is no Linux client yet.** Epic said in Aug 2026 that native Linux is coming "soon", with no date ([GamingOnLinux 2026-08](https://www.gamingonlinux.com/2026/08/epic-games-store-will-get-a-linux-version-sometime-soon/)) [V2].
- **Godot EOS:** [`3ddelano/epic-online-services-godot` (EOSG)](https://github.com/3ddelano/epic-online-services-godot) is a GDExtension for Godot 4.2+. It supports Win/Linux/macOS/Android/iOS and implements auth (including Epic Launcher login), achievements, stats, Ecom and more. 2.3.0 (Jun 2026) uses EOS SDK 1.19.1.2, and 2.3.1 adds Godot 4.7 compatibility [V for features and SDK; U for the exact 2.3.1 date].
- **Own CDN:** no explicit EGS rule found [U]. The launcher owns updates, and extra files in the install dir may upset launcher verification. **Disable the updater.**

---

## 4. GOG

- **Onboarding:** curated. Submit via GOG's game submission form. GOG weighs quality, roadmap and track record. Standard **70/30**, or **60/40 with an advance** until it's recouped ([GamingOnLinux 2023](https://gamingonlinux.com/2023/06/gog-made-it-simpler-publish-on-their-store-plus-their-pride-month-celebration), [V2]). **Ownership changed:** CD Projekt sold GOG to co-founder **Michał Kiciński**, closing 2025-12-31 (~PLN 90.7M), and GOG says the DRM-free mission is unchanged ([GameWorldObserver](https://gameworldobserver.com/2025/12/30/cd-projekt-announced-the-sale-of-gog-for-25-million)) [V2].
- **Hard rule: DRM-free and offline.** *"all games on GOG have to be playable offline and without the Galaxy client"* ([QA](https://docs.gog.com/quality-assurance/)). The Galaxy client and sign-in must be optional, with graceful offline fallback ([SDK overview](https://docs.gog.com/sdk/), [intro](https://docs.gog.com/introduction/)) [V].
- **Builds** [V]:
  - Build Creator (GUI) or **Pipeline Builder** (CLI, **Windows/macOS/Linux**): `GOGGalaxyPipelineBuilder build-game project.json --branch <b> --branch_password <p> [--username --password | cached creds] [--version]`, plus `publish-build`. The tools **cannot publish to Master or any public branch**, so do that in the Dev Portal ([pb build-game](https://docs.gog.com/pb-build-game/), [quick start](https://docs.gog.com/pb-quick-start/)).
  - Branches: Master (public default) and Beta (optionally password-protected). Staging is created by default ([branches](https://docs.gog.com/build-branches/)).
  - Offline installers are generated server-side after a Master publish, with hours of delay ([offline installers](https://docs.gog.com/offline-installers/)). Don't unpublish old Master builds, because Galaxy offers rollback.
  - Linux: Master Linux builds become installers (`start.sh` must point at the binary). A **native Galaxy for Linux is in development** (confirmed Jul 2026, no date) ([GamingOnLinux](https://gamingonlinux.com/2026/07/gog-confirm-they-are-working-towards-gog-galaxy-on-linux)) [V2].
  - macOS: GOG notes that notarized games may need "Normal folder" install mode instead of App Bundle ([QA](https://docs.gog.com/quality-assurance/)) [V].
- **Patching:** Galaxy updates Galaxy users incrementally. The details of Galaxy's delta algorithm and offline-installer patches aren't documented on the pages checked [U]. Users of offline installers re-download new installers.
- **SDK (optional):** achievements, leaderboards, cloud (≤200 MB, subfolder only). The Godot binding [`binogure-studio/GodotGOG`](https://github.com/binogure-studio/GodotGOG) is an **engine module (branch 4.5)**, so it needs a custom engine build [V]. GOG also has a "Steam SDK Wrapper (Beta)" ([Steam→GOG](https://docs.gog.com/gog-and-steam/)) [V]. GOG doesn't impose Epic-style achievement parity, so **skip the GOG SDK at launch** [U: parity not found as a rule].
- **In-game updater:** it isn't DRM, but it would modify the install directory behind Galaxy's back and phone home. **Disable it** on the `gog` distribution and rely on Galaxy and the offline installers.

---

## 5. Microsoft Store (PC)

- **Accounts:** individual registration has been **free since Sept 2025** (ID and selfie verification, starting at `storedeveloper.microsoft.com`) ([Learn](https://learn.microsoft.com/en-us/windows/apps/publish/whats-new-individual-developer), [Windows blog](https://blogs.windows.com/windowsdeveloper/2025/09/10/free-developer-registration-for-individual-developers-on-microsoft-store/)) [V]. Company accounts have been free since May 2026 ([Neowin](https://www.neowin.net/news/microsoft-makes-company-developer-accounts-free-for-the-microsoft-store/)) [V2]. Games get **88/12** (since Aug 2021) [V2].
- **Policies that decide it** ([Store Policies, updated 2026-09-15](https://learn.microsoft.com/en-us/windows/apps/publish/store-policies)) [V]:
  - **10.2.9:** the HTTPS EXE/MSI URL route is for **"Non-gaming products"** only. **A game cannot be submitted as an unpackaged EXE/MSI.** For the non-game route the developer must host and update the installer, the Store doesn't auto-update it, and a CA code-signing cert is required ([MSI/EXE requirements](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/app-package-requirements)).
  - **10.2.5:** *"All game products … must be submitted using supported package types … such products **and in-product offerings must be installed and updated only through the Store**."* ⇒ **No own updater, no own-CDN packs.**
  - 10.2.2: no dynamic code that changes described functionality. Data-only packs are fine.
  - 10.1.5: acquiring add-ons after install must go through the Store.
- **Packaging paths:**
  1. **GDK + MSIXVC is the recommended path for Win32 PC games, and self-service since ~June 2026: no ID@Xbox, no concept approval, Xbox services optional** ([Learn: Publish PC games using GDK](https://learn.microsoft.com/en-us/windows/apps/publish/whats-new-game-publishing)) [V]. MSIXVC installs flat files under `XboxGames\` ([PC packaging](https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/packaging/overviews/packaging-getting-started-for-pc)).
     - **MSIXVC2** (April 2026 GDK preview, **GA targeted for the October 2026 GDK**) uses **variable-size content-based segments**: *"Moving a file between chunks or reordering content … doesn't trigger a redownload"*. It reports 64 to 94% smaller updates, and `makepkg2 upload /d <folder>` packs and uploads in one step ([MSIXVC2 overview](https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/packaging/overviews/packaging-msixvc2-overview)) [V].
     - DLC = **"Durable with a package"**. Mount it at runtime via `XPackageEnumeratePackages` → license → `XPackageMount`. "Durable without a package" gives a license-only add-on for content already in the base game ([product types](https://learn.microsoft.com/en-us/gaming/gdk/docs/store/commerce/getting-started/xstore-choosing-the-right-product-type?view=gdk-2604), [DLC](https://learn.microsoft.com/en-us/gaming/gdk/docs/store/commerce/fundamentals/xstore-manage-and-license-optional-packages)) [V].
     - **Microsoft published an official [XBOX Godot Sample](https://github.com/microsoft/XBOX-Godot-Sample) (created 2026-05-28, MIT, Godot 4.5+ addons).** It includes `godot_gdk` (achievements, package metadata **plus DLC**, XStore), an "XBOX on PC" export platform, and `godot_gdk_packaging` (headless `makepkg` pack/validate for CI). It's a source-only sample with no support cadence, and needs the Windows GDK toolchain ([Learn: Godot + GDK](https://learn.microsoft.com/en-us/gaming/gdk/docs/gdk-dev/pc-dev/tutorials/getting-started-with-godot/gc-get-started-godot?view=gdk-2604)) [V].
  2. **Plain MSIX** (hand-written `AppxManifest.xml` with `runFullTrust` plus `makeappx`, or the new **WinApp CLI**). The Store re-signs it, so no certificate is needed. Updates are differential at **64 KB block** granularity ([MSIX overview](https://learn.microsoft.com/en-us/windows/msix/overview)) [V]. **Optional packages / DLC for plain MSIX need special Partner Center permission**, and "DLC packages are not available to all developer accounts" ([optional packages](https://learn.microsoft.com/en-us/windows/msix/package/optional-packages), [StoreContext](https://learn.microsoft.com/en-us/uwp/api/windows.services.store.storecontext.requestdownloadandinstallstorepackagesasync?view=winrt-28000)) [V]. Microsoft now steers *Win32* games to the GDK option and reserves "MSIX or PWA game" for UWP and PWA. Whether a full-trust Win32 MSIX *game* is still accepted is [U].
  
  Godot dropped its UWP exporter in 4.0, so either path is post-export packaging.
- **CI:** the `msstore` CLI (Windows/macOS/Linux, Entra ID app credentials, `msstore publish`) handles MSIX. It currently supports app updates for **free products only** ([msstore CLI](https://learn.microsoft.com/en-us/windows/apps/publish/msstore-dev-cli/overview)) [V]. The GDK path uses `makepkg`/`makepkg2 upload` (with an `/auth` option for CI [V, details not read]) on a **Windows runner** with the GDK installed. Every submission goes through **certification** (typically hours to a few days [U]).
- **Is it worth it?** Not for launch. The audience for a cozy indie roguelite is small. It adds a Windows-only packaging toolchain, per-update certification, IARC ratings (free), and a separate code path in the delivery abstraction (XPackage mounting if DLC is ever used). **Reassess after launch**, once MSIXVC2 is GA. The strongest reason to go is a later PC Game Pass or ID@Xbox pitch, and the self-service GDK path keeps that door open.

---

## 6. Others (brief)

- **Humble:** Humble Games (the publisher) laid off all staff in 2024. The Humble app gets no new games, and Humble Choice dropped Mac/Linux ([Hitmarker](https://hitmarker.net/news/humble-games-is-essentially-no-more-as-all-36-staff-are-laid-off-by-owner-ziff-davis-940551), [V2]). Bundles and the store continue [U on developer intake]. **Skip.** Offer Steam keys to bundles later if approached.
- **Game Jolt:** now social-first ("TikTok for games"), with a marketplace for paid games ([Game Developer](https://www.gamedeveloper.com/business/game-jolt-will-now-be-a-marketplace), [V2]). It can host the web demo or a download for visibility at low value. Optional.
- **Newgrounds:** good for a **web demo**. The HTML5 zip limit is reportedly ~250 MB [U]. The Godot 4.3+ single-threaded web export avoids COOP/COEP issues [V2].
- Apple Arcade / Netflix Games: not relevant to PC distribution. Skip.

---

## 7. How content packs map onto each store, and what the Godot delivery layer must do

A common rule for all store builds: packs **ship inside the store build** ("embedded"). The store's patcher is the only updater. `user://` holds saves and settings only, never packs. **Never write into the install directory**: Steam "verify files", Galaxy and Epic would revert or flag it, and MSIX/MSIXVC installs may be read-only. Detect the store from a build-time constant (`distribution=steam|itch|epic|gog|msstore`) written into the core PCK. Don't sniff the environment for that decision, except the `ITCHIO_APP` refinement.

| distribution | Where packs live | Discovery | Ownership gating | Updater / remote packs |
|---|---|---|---|---|
| `steam` | Depot: `<install>/packs/*.pck` (on macOS, next to `Diceroll.app`), or DLC depots installing into the same folder | Read the shipped `packs/manifest.json` and mount each with `ProjectSettings.load_resource_pack(abs_path, replace_files=false)`. Resolve paths from `OS.get_executable_path()` (on macOS go up out of `Contents/MacOS`), with `Steam.getAppInstallDir(APP_ID)` as a cross-check | Only for real DLC: `Steam.isDLCInstalled(dlc_id)` / `isSubscribedApp`. Optional packs: `installDLC()` plus the `dlc_installed` signal, then hot-mount. If a pack fails its manifest hash, call `Steam.markContentCorrupt(true)` and show "verify files" | **Off.** Log `getAppBuildId()` and `getCurrentBetaName()` in crash reports |
| `itch` (desktop) | Inside the channel folder | Same manifest walk | None (DRM-free) | Off. If `ITCHIO_APP` is unset, optionally show a prompt only, via `api.itch.io/wharf/latest` |
| `itch` / `web` | `index.pck` plus same-origin `packs/` in the ZIP | HTTP fetch → IndexedDB → mount (per the design doc) | None | Always latest. Respect ≤1,000 files, ≤200 MB per file |
| `epic` | Artifact folder; DLC artifacts into the same folder | Same manifest walk | Only for paid DLC: EOS `Ecom_QueryOwnership` via EOSG. Needs EOS init with the launcher's `-AUTH_PASSWORD`/`-epicdeploymentid` args [U: exact arg names beyond `-epicdeploymentid`/`-epicsandboxid`] | Off |
| `gog` | Build folder (Galaxy or offline installer); DLC as extra files | Same manifest walk | File presence only (DRM-free: no online checks) | Off |
| `msstore` (GDK) | Inside MSIXVC (`XboxGames\…`); DLC = durable-with-package, mounted at a path | Base: manifest walk. DLC: `XPackageEnumeratePackages` → `XStoreAcquireLicenseForPackage` → `XPackageMount` → `load_resource_pack(<mount path>/…)` (via Microsoft's `godot_gdk` addon) | XStore license | **Forbidden** (policy 10.2.5) |

**Manifest rules (store builds):**
- The manifest ships in the build next to the packs.
- Packs listed but missing are either optional or DLC, and get skipped gracefully. Unlisted `.pck` files are ignored (defence against stray files).
- Mount order is deterministic: base first, then dated drops in chronological order.
- Saves reference content IDs, never paths, as the design doc already specifies.

---

## 8. Recommendation: prioritization, cost and CI per store (solo dev)

1. **Steam, first and primary.** It's the biggest PC audience, with genre fit (cozy roguelites and deckbuilders do well there), Deck and Steam Machine reach, wishlists, Next Fest, and Playtest.
   - **Cost:** $100 plus about 2 to 4 dev-days: GodotSteam GDExtension, achievements, Auto-Cloud, Deck text input and glyphs, runtime choice, macOS entitlements.
   - **Timeline:** Coming Soon page ≥2 weeks before release, the 30-day fee wait, and 3 to 5 plus 3 to 5 business days of reviews. Put the Coming Soon page up **now** to collect wishlists.
   - **CI:** the existing job, pinned by SHA. Auto `SetLive` to a password-protected `beta`, manual promote to `default`. Refresh `STEAM_CONFIG_VDF` or use TOTP. Consider a shared `[All OSes]` packs depot. Select SLR 4.0 for the Linux depot. Keep notarizing macOS. Use Steam Playtest instead of public test builds.
2. **itch.io, keep as the second channel (already automated).** Free, with the web demo, pay-what-you-want or a supporter tier, devlogs and jams. **CI:** as today. Add `--if-changed` and a `push-preview` step, and optionally a `linux-arm64` channel. Set the revenue share you're comfortable with.
3. **GOG, pitch 3 to 6 months before 1.0.** DRM-free fits a single-player offline roguelite, and Linux users value it. Low technical cost: no SDK needed, and just disable the updater. **CI:** add a Pipeline Builder step (Linux binary) that uploads to `Staging` with the branch password, and promote to Master in the portal. Acceptance is the gating risk, not tech.
4. **Epic, optional after the Steam launch.** Cheap ($100, 0% cut up to $1M/yr), but low organic visibility for small indies. It costs EOS achievements (EOSG GDExtension, ~1 to 2 days) because of the parity rule, plus Windows and macOS artifacts. **CI:** BPT `UploadBinary` on a Windows runner with `-ClientSecretEnvVar`. Activate the binary in the portal. Run `BinaryDeltaOptimise` only for big patches.
5. **Microsoft Store, defer.** It's free to register, but it needs the GDK/MSIXVC toolchain (Windows runner), per-update certification, and zero self-updating. Revisit after the October 2026 GDK (MSIXVC2 GA) using Microsoft's own Godot GDK sample, mainly as a stepping stone to ID@Xbox or Game Pass.
6. **Skip Humble.** Use Game Jolt and Newgrounds only to host the web demo for marketing.

**Cross-store engineering checklist:**
- Deterministic, uncompressed and unencrypted PCKPacker packs, ≤20 MB each, with new content in new packs.
- A core binary with no embedded PCK and no UPX.
- An install-dir manifest.
- `distribution` build flag → updater off on all store channels.
- Unique pack filenames (required by Epic DLC and Steam DLC depots).
- CI compares pack bytes between two exports to catch nondeterminism.
- Watch the per-store "update size" (Steamworks builds page, butler push-preview) before promoting a build.

---

## 9. Open questions / to verify before implementation

- SteamPipe's exact chunk-matching behaviour on shifted data (rolling versus fixed offsets) [U]. Test empirically: upload two builds to a private branch that differ by one inserted asset early in a 20 MB pack, and read the update size.
- Whether the Diceroll packs are byte-identical across the Windows, Linux and macOS (universal) presets. This decides the shared-depot option.
- Whether Godot 4.7.2 Linux templates run cleanly under SLR 4.0 (steamrt4) on Deck.
- Epic BPT's Linux/macOS availability for CI, and the exact Epic launcher auth args.
- GOG's current revenue terms, DLC install layout, and whether it accepts self-updating games at all. Ask your GOG PM.
- Whether Microsoft accepts plain full-trust MSIX Win32 games from individual accounts, or requires GDK.
- Steam revenue tiers and the `SetAppBuildLive` public-branch confirmation flow.

## Sources (primary unless marked)

- Steam: [Uploading](https://partner.steamgames.com/doc/sdk/uploading) · [Branches](https://partner.steamgames.com/doc/store/application/branches) · [DLC](https://partner.steamgames.com/doc/store/application/dlc) · [Updates best practices](https://partner.steamgames.com/doc/store/updates) · [ISteamApps WebAPI](https://partner.steamgames.com/doc/webapi/ISteamApps) · [App fee](https://partner.steamgames.com/doc/gettingstarted/appfee) · [Onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding) · [Releasing](https://partner.steamgames.com/doc/store/releasing) · [Review](https://partner.steamgames.com/doc/store/review_process) · [Deck/Machine compat](https://partner.steamgames.com/doc/steamdeck/compat) · [Linux](https://partner.steamgames.com/doc/store/application/platforms/linux) · [Platforms/macOS](https://partner.steamgames.com/doc/store/application/platforms) · [Cloud](https://partner.steamgames.com/doc/features/cloud) · [Playtest](https://partner.steamgames.com/doc/features/playtest) · [Workshop versioning](https://partner.steamgames.com/doc/features/workshop/itemversioning) · [steam-runtime README](https://github.com/ValveSoftware/steam-runtime/blob/master/README.md) · [GamingOnLinux SLR 4.0](https://www.gamingonlinux.com/2025/11/valve-put-up-a-new-steam-linux-runtime-4-0-with-a-move-towards-64-bit/) (V2)
- GodotSteam: [Codeberg releases](https://codeberg.org/godotsteam/godotsteam/releases) · [GitHub (archived)](https://github.com/GodotSteam/GodotSteam) · [Changelog](https://godotsteam.com/changelog/godot4/) · [Apps class](https://godotsteam.com/classes/apps/) · [Mac export](https://godotsteam.com/tutorials/mac_export/) · [Asset Library entry](https://www.godotengine.org/asset-library/asset/edit/11743)
- CI: [game-ci/steam-deploy](https://github.com/game-ci/steam-deploy) · [releases](https://github.com/game-ci/steam-deploy/releases) · [game.ci Steam docs](https://game.ci/docs/github/deployment/steam/) · [GHSA-c5qx-p38x-qf5w](https://osv.dev/vulnerability/GHSA-c5qx-p38x-qf5w) · [GHSA-mj96-mh85-r574](https://osv.dev/vulnerability/GHSA-mj96-mh85-r574)
- Godot: [file_access_pack.h](https://github.com/godotengine/godot/blob/master/core/io/file_access_pack.h) · [pck_packer.cpp](https://github.com/godotengine/godot/blob/master/core/io/pck_packer.cpp) · [editor_export_platform.cpp](https://github.com/godotengine/godot/blob/master/editor/export/editor_export_platform.cpp) · [PR #97118 patch PCKs](https://github.com/godotengine/godot/pull/97118) · [PR #112011 delta encoding](https://github.com/godotengine/godot/pull/112011) · [Exporting packs docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html) · [issue #4108 UPX vs Steam](https://github.com/godotengine/godot/issues/4108) · [4.5 beta 2 (SDL3)](https://godotengine.org/article/dev-snapshot-godot-4-5-beta-2/) · [macOS export docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html) · [cavs-steam](https://crates.io/crates/cavs-steam) (V2) · [DepotDownloader analysis](https://deepwiki.com/SteamRE/DepotDownloader/3.2.3-file-validation-and-integrity) (V2)
- itch.io: [butler pushing](https://itch.io/docs/butler/pushing.html) · [HTML5](https://itch.io/docs/creators/html5) · [Payments](https://itch.io/docs/creators/payments) · [FAQ](https://itch.io/docs/creators/faq) · [itch app CHANGELOG](https://github.com/itchio/itch/blob/master/CHANGELOG.md) · [butler releases](https://github.com/itchio/butler/releases) · [May 2026 app update](https://itch.io/updates/pushing-builds-with-butler-is-now-in-the-itch-app) · [SharedArrayBuffer](https://itch.io/t/2025776/experimental-sharedarraybuffer-support)
- Epic: [Requirements overview](https://dev.epicgames.com/docs/epic-games-store/requirements-guidelines/distribution-requirements/requirements-overview) · [Before you begin](https://dev.epicgames.com/docs/epic-games-store/get-started/get-started-steps/before-you-begin) · [Multiplayer reqs](https://dev.epicgames.com/docs/epic-games-store/requirements-guidelines/distribution-requirements/multiplayer-reqs) · [BPT 1.6](https://dev.epicgames.com/docs/epic-games-store/publishing-tools/uploading-binaries/bpt-instructions-160) · [BPT 1.5 (DLC)](https://dev.epicgames.com/docs/epic-games-store/publishing-tools/uploading-binaries/bpt-instructions-150) · [Artifacts](https://dev.epicgames.com/docs/epic-games-store/store-presence/manage-artifacts) · [Offers](https://dev.epicgames.com/docs/epic-games-store/store-presence/manage-offers) · [Ecom](https://dev.epicgames.com/docs/epic-games-store/services/ecom/ecom-quick-start) · [Org/fee](https://dev.epicgames.com/docs/epic-games-store/publishing-tools/organization-management/manage-org) · [Revenue news](https://store.epicgames.com/news/epic-games-store-updates-revenue-share-keep-100-of-the-first-1m-per-product-per-year) · [EOSG](https://github.com/3ddelano/epic-online-services-godot) · [Linux client news](https://www.gamingonlinux.com/2026/08/epic-games-store-will-get-a-linux-version-sometime-soon/) (V2)
- GOG: [QA](https://docs.gog.com/quality-assurance/) · [Intro](https://docs.gog.com/introduction/) · [SDK](https://docs.gog.com/sdk/) · [Steam→GOG](https://docs.gog.com/gog-and-steam/) · [Branches](https://docs.gog.com/build-branches/) · [Pipeline Builder quick start](https://docs.gog.com/pb-quick-start/) · [build-game](https://docs.gog.com/pb-build-game/) · [publish-build](https://docs.gog.com/pb-publish-build/) · [Offline installers](https://docs.gog.com/offline-installers/) · [GodotGOG](https://github.com/binogure-studio/GodotGOG) · [GOG sale](https://gameworldobserver.com/2025/12/30/cd-projekt-announced-the-sale-of-gog-for-25-million) (V2) · [Galaxy Linux](https://gamingonlinux.com/2026/07/gog-confirm-they-are-working-towards-gog-galaxy-on-linux) (V2)
- Microsoft: [Store policies](https://learn.microsoft.com/en-us/windows/apps/publish/store-policies) · [MSI/EXE requirements](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/app-package-requirements) · [Free individual registration](https://learn.microsoft.com/en-us/windows/apps/publish/whats-new-individual-developer) · [Publish PC games via GDK](https://learn.microsoft.com/en-us/windows/apps/publish/whats-new-game-publishing) · [MSIXVC2](https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/packaging/overviews/packaging-msixvc2-overview) · [MSIXVC PC packaging](https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/packaging/overviews/packaging-getting-started-for-pc) · [GDK product types](https://learn.microsoft.com/en-us/gaming/gdk/docs/store/commerce/getting-started/xstore-choosing-the-right-product-type?view=gdk-2604) · [GDK DLC](https://learn.microsoft.com/en-us/gaming/gdk/docs/store/commerce/fundamentals/xstore-manage-and-license-optional-packages) · [MSIX overview](https://learn.microsoft.com/en-us/windows/msix/overview) · [Optional packages](https://learn.microsoft.com/en-us/windows/msix/package/optional-packages) · [msstore CLI](https://learn.microsoft.com/en-us/windows/apps/publish/msstore-dev-cli/overview) · [XBOX Godot Sample](https://github.com/microsoft/XBOX-Godot-Sample) · [Godot + GDK](https://learn.microsoft.com/en-us/gaming/gdk/docs/gdk-dev/pc-dev/tutorials/getting-started-with-godot/gc-get-started-godot?view=gdk-2604)
- Others: [Humble Games layoffs](https://hitmarker.net/news/humble-games-is-essentially-no-more-as-all-36-staff-are-laid-off-by-owner-ziff-davis-940551) (V2) · [Game Jolt marketplace](https://www.gamedeveloper.com/business/game-jolt-will-now-be-a-marketplace) (V2)
