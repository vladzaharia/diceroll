# 05: Android distribution, updates and content delivery for Diceroll

As of **2026-09-29**. Engine: Godot **4.7.2-stable**. Package `gg.vlad.diceroll`.

Current state, taken from the repo:
- `export_presets.cfg` has a non-Gradle APK export (arm64 only) and a Gradle AAB export (armeabi-v7a and arm64).
- Both builds are signed with the same `ANDROID_KEYSTORE_*` secret.
- `release.yml` uploads the AAB to the Play **internal** track as a **draft** using `r0adkll/upload-google-play@v1`.
- The GitHub release carries the APK for sideloading and Obtainium.

**Labels:**
- **[V]** means verified against the cited primary source, or against Godot or bundletool source code I read at the 4.7.2 or master tag.
- **[U]** means uncertain, inferred, or taken only from a secondary source.
- **[P]** means it needs a prototype or device test before we rely on it.

---

## 0. Executive summary

1. **Asset packs cannot be added or updated without a new app version.**
   - Updating asset packs without a new app binary ("asset-only updates") is **not a publicly available Play feature**.
   - bundletool has an `ASSET_ONLY` bundle type:
     - It has been there since 0.15.0 (May 2020).
     - It holds only fast-follow or on-demand packs.
     - It targets a list of existing app `versionCode`s and carries an `asset_version_tag`.
   - The Publishing API shows an "asset module version" field.
   - There is no public Console UI, API method or documentation for uploading such bundles. Assume it is partner or allowlist only. [V code / U availability]
   - **Consequence:** on Play, every new or changed PAD pack needs a new versionCode and a review.
   - Play's Device and Network Abuse policy allows data-only packs downloaded from your own server. That is the only way to update content "without a binary" on Play.
2. **Godot 4.7.2 already uses Play Asset Delivery (PAD) for AAB exports.**
   - The Gradle AAB export puts **all project files into an `install-time` asset pack**, `assetPackInstallTime`.
   - It indexes them with an `assets.sparsepck` directory. The sparse PCK format arrived in 4.5.
   - This needs no code: install-time packs are read through `AssetManager`. [V source]
3. **At 90–130 MB, PAD's size benefits don't matter.**
   - Play limits (verified): base module 500 MB, 1.5 GB per pack, 4 GB install-time total, 30 GB fast-follow plus on-demand, 100 packs. The mobile-data warning appears above 200 MB.
   - **Recommendation:**
     - Launch and "tier 1" `.pck` packs ship inside the binary on every channel. On Play they sit in the install-time pack.
     - Live or seasonal data packs come from **our own CDN** on every channel, using a signed manifest.
     - Keep a PAD fast-follow/on-demand backend behind the abstraction as an **optional later optimization**, for large optional packs such as HD audio. Don't build it for 1.0.
4. **Binary updates:**
   - **Play:** Play auto-update, plus the In-App Updates API. Use flexible by default, and immediate when below the minimum version or when priority is 4 or higher. `inAppUpdatePriority` can be set only through the Publishing API.
   - **GitHub/Obtainium:** Obtainium, plus an in-game "update available" notice that links out.
   - **Minimum-version enforcement:** a signed remote JSON (`min_version_code`) plus `min_core` or content-schema checks on each pack.
5. **Developer verification is urgent.**
   - **Tomorrow, 2026-09-30:**
     - Every Play package must be registered, or it is removed from Play.
     - Enforcement also starts in Brazil, Indonesia, Singapore and Thailand. It applies **only to installs from participating stores**: Play, Galaxy Store, OPPO, vivo, Xiaomi, HONOR, Transsion.
   - **In 2027** it goes global for **all** installs on certified devices, including GitHub and Obtainium sideloads. ADB is exempt.
   - **Action now:** confirm in the Play Console Home page that `gg.vlad.diceroll` is registered. Register any additional non-Play signing key under the same package. [V]
6. **Signing is the biggest cross-channel trap.**
   - New Play apps now default to Google-generated **"quantum-ready hybrid signing"**:
     - Three keys: RSA-4096 for Android 16 and lower, plus a new classical key and an ML-DSA-65 key.
     - APK Signature Scheme **v3.2** on **Android 17+**.
   - Today the GitHub APK is signed with our own key and the Play build with Google's key. **Users cannot move between channels without uninstalling.**
   - **Recommendation (option A):** publish the **Play-generated universal APK**, downloaded in CI with `generatedapks.download`, as the GitHub/Obtainium APK.
     - One signer everywhere, including the v3.2 hybrid.
     - Registration is automatic.
     - This is explicitly allowed by Play.
   - **Alternative (option B):** upload our own key as the Play app signing key through PEPK. This only works before any open-testing or production release.
     - Whether Play adds v3.2 hybrid on top of a custom key is **unknown [P]**.
7. **Channels worth doing:**
   - Worth it: Google Play (primary), GitHub + Obtainium (keep), itch.io APK (trivial), and optionally IzzyOnDroid, since the project is MIT.
   - Google Play Games on PC: **mobile games are now on PC by default, with opt-out**. Add the x86_64 ABI and mouse support.
   - Watch: Epic Games Store mobile self-publishing (announced for August 2026) and Galaxy Store.
   - Skip: Accrescent (closed to new developers), Amazon (dead on non-Fire Android since 2025-08-20), Huawei, and the F-Droid main repo for now.
8. **Godot `load_resource_pack` on Android:**
   - It can mount a `.pck` that lives in APK assets or the install-time pack (`res://…pck`, read with `AAssetManager`). It can also mount one from any filesystem path. [V source; P for performance]
   - Issue godot#105009 (a first mount freezing the UI) is still open. Its cause is the first-pack `res://` directory snapshot.
   - On 4.5+ Android, the sparse main pack sets `using_datapack` at boot, so that path **should no longer trigger** [U → P].
   - Mount at boot or behind a loading screen anyway. The call is synchronous.

---

## 1. Play Asset Delivery (PAD), current state

### 1.1 Delivery modes [V] <https://developer.android.com/guide/playcore/asset-delivery>

| Mode | Served as | Counts in store size | When available | Access |
|---|---|---|---|---|
| install-time | split APKs, part of the APK set | yes | at launch | `AssetManager` (`context.assets.open(...)`). Not a filesystem path. The Play Core API can't query or remove these packs. |
| fast-follow | archive files, expanded in internal storage | no | downloaded automatically right after install, without opening the app | `AssetPackManager.getPackLocation(pack).assetsPath()` gives a real directory |
| on-demand | archive files, expanded in internal storage | no | when the app calls `fetch` / `requestFetch` | same as fast-follow |

Other rules:
- Packs hold **no executable code**. [V]
- fast-follow and on-demand files "may be deleted by the user or moved by the Play Asset Delivery Library across play sessions". Treat them as read-only, because patching depends on their integrity. [V]
- Install-time packs "require at least **two times the size** of all asset packs in free disk space" for installs and updates. [V]

### 1.2 Size limits [V] <https://support.google.com/googleplay/android-developer/answer/9859372>

| Item | Limit |
|---|---|
| Base module | **500 MB** (older docs say 150 or 200 MB, which is stale) |
| Individual asset pack | 1.5 GB |
| All modules plus install-time packs | 4 GB |
| fast-follow plus on-demand total | 30 GB |
| Max asset packs per bundle | **100** |
| Total | 34 GB |

A non-blocking mobile-data dialog appears for apps **>200 MB**. Higher limits exist for partners. The Level Up program also lists "expanded APK size limits" as a benefit. [V] <https://developer.android.com/blog/posts/level-up-test-sidekick-and-prepare-for-upcoming-program-milestones>

### 1.3 API: `com.google.android.play:asset-delivery(-ktx):2.3.0` [V]

The latest library release is 2.3.0 (Dec 2024). The release-notes page was last updated 2026-08-14 with nothing newer. <https://developer.android.com/reference/com/google/android/play/core/release-notes-asset_delivery>
- `getPackStates()` / `requestPackStates()`: apps are **required to disclose the download size** before fetching (`totalBytesToDownload()`).
- `fetch()` / `requestFetch()`: starts or completes a download. `registerListener(AssetPackStateUpdateListener)` reports progress per pack.
- `getPackLocation(name)` or `getPackLocations()` returns an `AssetPackLocation`. `.assetsPath()` is the `assets/` directory, or null if the pack isn't ready.
- `removePack()`.
- Cellular: if a download is **>200 MB** and the user isn't on Wi-Fi, the pack sits in `WAITING_FOR_WIFI` / `REQUIRES_USER_CONFIRMATION` until the app calls `showConfirmationDialog(...)`. That API was added in 2.2.0. `showCellularDataConfirmation` is deprecated. The same dialog also handles "the app is not recognized by Play, please update". [V] <https://developer.android.com/guide/playcore/asset-delivery/integrate-java>
- Local testing: `bundletool build-apks --local-testing`. In this mode fast-follow behaves like on-demand, and updates aren't supported. Internal app sharing gives real Play behaviour. [V] <https://developer.android.com/guide/playcore/asset-delivery/test>

### 1.4 Updates and delta patching [V] with gaps [U]

- **Install-time packs** update together with the base app.
- **fast-follow and on-demand packs**:
  1. The patch for the whole app, including all assets, is downloaded.
  2. The binary and install-time packs are updated.
  3. **All previously downloaded packs are invalidated.**
  4. The asset patches are applied to internal storage.
- The game "must accommodate" opening while packs are still invalid, for example with an "Update in progress" UI. [V] <https://developer.android.com/guide/playcore/asset-delivery>
- "Play also takes care of delta patching for you." [V] <https://android-developers.googleblog.com/2020/06/introducing-google-play-asset-delivery.html>
  - How fine-grained the patching is (per file, per byte, per pack) is **not documented [U]**.
  - For Godot `.pck` files, which are single large files, keep exports **deterministic**, with stable ordering and no timestamps, so byte-level patches stay small [P].
- **Pack names must stay stable across versions.** In 2025 a Unity bug showed that renaming or removing packs between versions made Play updates fail with "all packs are unavailable" until the Play Store cache was cleared. [V] <https://github.com/google/play-asset-delivery-unity/issues/1>
- Play-as-you-download optimizes **install-time** packs only. [V] <https://developer.android.com/google/play/play-as-you-download/best-practices>

### 1.5 Updating or adding packs without a new app version

**Finding: not publicly available. Treat it as not an option.**

- **bundletool supports asset-only bundles.** [V code]
  - `BundleConfig.BundleType.ASSET_ONLY` plus `AssetModulesConfig { repeated int64 app_version /* "App versionCodes that will be updated with these asset modules" */; string asset_version_tag; }`. <https://github.com/google/bundletool/blob/master/src/main/proto/config.proto>
  - The validator enforces that an asset-only bundle has only asset modules and **no install-time** packs (`AssetBundleValidator.java`).
  - `git log -S ASSET_ONLY` shows it was introduced in **bundletool 0.15.0 (2020-05-18)**. The latest bundletool is 1.18.3 (Dec 2025).
- **The Publishing API v3 hints at it** (discovery revision 20260929). `GeneratedAssetPackSlice.version` is described as "Asset module version". [V]
  - But `edits.bundles.upload` has only `deviceTierConfigId` as a special parameter.
  - There is no asset-only method, and no Console or Help documentation. <https://androidpublisher.googleapis.com/$discovery/rest?version=v3>
- **Searches found no public Google page, blog or I/O/GDC 2025–2026 announcement** for "asset-only updates". Searched: developer.android.com, support.google.com, android-developers.googleblog.com, the I/O 2026 "What's new in Google Play" post, and the GDC 2026 posts. [U: absence of evidence]
- **Working conclusion:** it is probably limited to partners such as the Google Play Partner Program for Games. If it ever matters, ask a Play partner contact or support.

### 1.6 Texture compression format targeting (TCFT) and device targeting

- **TCFT** [V] <https://developer.android.com/guide/playcore/asset-delivery/texture-compression>
  - Folder suffixes like `textures#tcf_astc`, `#tcf_etc2`, and so on. Play strips the suffix on delivery.
  - Needs `bundle { texture { enableSplit true } }` and AGP 4.1+.
  - A suffix-less default folder is mandatory. Without it, the app is unavailable on non-matching devices.
  - Download limits apply per format.
  - **Not relevant to Diceroll.** It's a cozy 2D game, and Godot doesn't emit `#tcf_` variants natively. You'd need two differently imported pack builds.
- **Device targeting (beta)** [V] <https://developer.android.com/guide/playcore/asset-delivery/device-targeting>
  - `#group_<name>` folder suffixes, with groups defined by RAM, device model, system features or SoC in an XML config.
  - The older `#tier_` device-tier API is gone from the docs. `deviceTierConfigs` still exists in the Publishing API.
  - Non-targeted devices always get the default variant.
  - Not needed for Diceroll.

---

## 2. Godot 4.7.2 on Android

All of the following was verified by reading the `4.7.2-stable` source.

### 2.1 What the export does [V source]

- **Gradle template:**
  - AGP **8.6.1**, Gradle 8.11.1, compileSdk and targetSdk **36**, minSdk **24**, **NDK r29** (29.0.14206865), Kotlin 2.1.21, Java 17. Source: `platform/android/java/app/config.gradle`.
- **AAB export:**
  - The template's `app/build.gradle` declares `assetPacks = [":assetPackInstallTime"]`. That module uses `deliveryType = "install-time"`.
  - `export_plugin.cpp` writes all project files to `assetPackInstallTime/src/main/assets` (`AAB_ASSETS_DIRECTORY`).
  - **So Godot already uses PAD install-time delivery automatically for AABs.**
  - An APK export writes to `src/main/assets` instead.
- **Sparse PCK:**
  - Files are stored individually, and an `assets.sparsepck` directory index is written.
  - At startup `ProjectSettings` calls `_load_resource_pack("res://assets.sparsepck", …, main_pack=true)`, under `#ifdef ANDROID_ENABLED`.
  - Without PCK encryption, file paths are kept, so `res://packs/x.pck` becomes `assets/packs/x.pck`. With encryption, names are SHA-256 hashed.
  - Sparse PCK is PR #105984, merged for **4.5** (2025-06-25). It took Android patch-PCK mounting from about 8–12 s to milliseconds. [V] <https://github.com/godotengine/godot/pull/105984>
- **Compression:**
  - The non-Gradle APK path never compresses `.pck` (the `unconditional_compress_ext` list, which includes `".pck"`), `.ogg`, `.png`, `.webp`, `.ctex` or `.scn`.
  - The Gradle template sets **no `noCompress`**, so AGP or bundletool may compress `.pck` inside the install-time pack. **[P]** Add `androidResources { noCompress += ['pck'] }` to the template and measure.
- **16 KB pages:**
  - NDK r28+ builds 16 KB-aligned ELF by default.
  - AGP ≥ 8.5.1 zip-aligns uncompressed `.so` files at 16 KB. The template's 8.6.1 qualifies.
  - The non-Gradle exporter pads `.so` entries to 16 KB (`PAGE_SIZE_KB = 16 * 1024` in `export_plugin.cpp`).
  - **Godot 4.7.2 complies.** Third-party AAR or GDExtension `.so` files must also comply. Check in CI with `zipalign -c -P 16 -v 4` or `check_elf_alignment.sh`.

### 2.2 Android plugin v2 architecture [V]

Sources: <https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html> and `GodotPlugin.java`.

- **Packaging:** an Android library (AAR) with a class that extends `org.godotengine.godot.plugin.GodotPlugin`.
- **Registration:** `<meta-data android:name="org.godotengine.plugin.v2.<PluginName>" android:value="<init class FQN>"/>` in the AAR manifest.
- **Callable methods:** annotated with `@UsedByGodot`. Names must match exactly; there is no snake_case conversion.
- **Signals:** override `getPluginSignals(): Set<SignalInfo>` and call `emitSignal(name, args…)`.
- **Threading helpers:** `runOnUiThread`, `runOnHostThread`, `runOnRenderThread`.
- **Lifecycle hooks:**
  - `onMainActivityResult`, `onMainResume`, `onMainPause`, `onMainDestroy`
  - `onGodotSetupCompleted`, `onGodotMainLoopStarted`
  - `getActivity()`, `getContext()`
- **Editor side:** an `EditorExportPlugin` with:
  - `_supports_platform`
  - `_get_android_libraries` (AAR paths)
  - `_get_android_dependencies` (Maven coordinates, for example `com.google.android.play:asset-delivery-ktx:2.3.0`)
  - `_get_android_dependencies_maven_repos`
  - `_get_android_manifest_*`
- Plugins require **Gradle builds** (Godot 4.2+). **Our current APK preset uses `gradle_build/use_gradle_build=false`, so it cannot include plugins.**
- **GDScript access:** `if Engine.has_singleton("X"): var s = Engine.get_singleton("X")`.
- **No-Kotlin alternative in 4.7** [V: `doc/classes/JavaClassWrapper.xml`]:
  - `JavaClassWrapper.wrap(...)`, `JavaClassWrapper.create_proxy(obj, ["iface"])` and `JavaClassWrapper.create_sam_callback("iface", callable)`.
  - The `AndroidRuntime` singleton exposes `getActivity()` and `getApplicationContext()`.
  - This lets GDScript call Play Core APIs directly, as long as a plugin or template adds the Maven dependency.
  - Good for a prototype. A Kotlin AAR is more robust for Task callbacks, activity results and tests.
- **Limitation:** there is **no export-plugin hook to add asset-pack modules.** Using fast-follow or on-demand packs means editing the installed `android/build` template: add `include ':packX'` in `settings.gradle`, add to `assetPacks`, and create a `packX/build.gradle` with `com.android.asset-pack`. Then copy the `.pck` files into `packX/src/main/assets/` before the Gradle step [V code / P workflow].

### 2.3 Existing Godot 4 Android plugins

| Need | Plugin | Status |
|---|---|---|
| Play Billing | `godot-sdk-integrations/godot-google-play-billing` | [V] v2 plugin, Godot 4.2+. 3.2.0 (2026-03-15) moved to PBL 8.3.0, and later notes mention PBL 9.1.0. Docs: <https://godot-sdk-integrations.github.io/godot-google-play-billing> |
| Play Games Services v2 | `godot-sdk-integrations/godot-play-game-services` | [V] Godot 4.3+ |
| In-app review | `godot-sdk-integrations/godot-inapp-review` | [V, secondary] one GDScript API for Android and iOS |
| In-app updates | `icecube092/GodotInAppUpdate` | [V repo README] Godot 4.6, app-update 2.1.0, flexible and immediate flows, priority and staleness. Third-party and small; vendoring is fine. |
| **Play Asset Delivery** | **none found** for Godot 4 | [U: GitHub, Asset Library and web searches]. The 3.x PAD PR #52526 covered install-time only. **Write our own**; it's a small Kotlin AAR. |

Org index: <https://github.com/godot-sdk-integrations>

### 2.4 Can `load_resource_pack` mount packs from APK assets or install-time packs? [V source, P performance]

- **`load_resource_pack("res://packs/foo.pck")` works for a `.pck` exported as a project file.**
  - Include it with the export filter "non-resource files".
  - `PackedSourcePCK::try_open_pack` calls `FileAccess::open(path)`. That resolves through the sparse main pack to `FileAccessAndroid`, which uses `AAssetManager_open(..., AASSET_MODE_STREAMING)` with `AAsset_seek`.
  - Godot's own docs use `load_resource_pack("res://mod.pck")`. <https://docs.godotengine.org/en/4.6/tutorials/export/exporting_pcks.html>
  - **Risk:** a *compressed* asset makes random seeks expensive. Keep `.pck` files stored (uncompressed): the non-Gradle APK already does this, and the Gradle template needs `noCompress 'pck'` [P].
- **PAD fast-follow or on-demand** give a real directory.
  - Absolute paths use `FileAccessFilesystemJAndroid`, which is Java/JNI based.
  - `user://` is `context.getFilesDir()` (`GodotIO.getDataDir()`) and uses `FileAccessUnix`.
  - Expanded PAD packs typically live under `filesDir/assetpacks/...`. If the path starts with `OS.get_user_data_dir()`, rewrite it to `user://…` to get the native POSIX path [U → P].
- **Mount semantics:**
  - Pass `replace_files` (default `true`) to let a pack override files. Use `false` for additive packs.
  - Resources that are already cached are **not** replaced (PR #90425 discussion), so mount before loading content, for example in an autoload `_init`. [V docs]
  - Keep each pack's files under `res://content/<pack_id>/…` to avoid collisions.
- **godot#105009**, "load_resource_pack hangs up UI on Android". [V] <https://github.com/godotengine/godot/issues/105009>
  - Still **open**. Labels: regression, needs testing. Last activity 2025-07-07. The milestone was removed.
  - Cause, according to its author: PR #90425 takes a `res://` directory snapshot (`PackedSourceDirectory`) when the *first* non-main pack loads.
  - The workaround was mounting an empty PCK first, but one user saw a 20 s delay with it.
  - **Our analysis [U → P]:** in 4.7.2 that snapshot runs only when `!using_datapack` (`project_settings.cpp`). On Android, `using_datapack` becomes `true` when `assets.sparsepck` mounts at startup, so the snapshot path shouldn't run.
  - What remains is per-mount work on the calling (main) thread: reading the PCK directory, `refresh_global_class_list()` and `ResourceUID::load_from_cache`.
  - **Measure mounting 5–20 small packs on a low-end device.**
- **Delta patch PCKs are new in 4.x.** [V source]
  - Export presets have `patch_delta_encoding_enabled`, zstd level, a minimum-reduction threshold and include/exclude filters.
  - There are also `EditorExportPlatform.export_pack_patch()` / `save_pack_patch()` and `core/io/delta_encoding.*`.
  - A patch PCK holds only changed files, optionally as zstd deltas against the base pack.
  - This is the CDN-side equivalent of Play's delta patching. The base pack must be mounted first [P].

---

## 3. Play In-App Updates API

Sources [V]:
- <https://developer.android.com/guide/playcore/in-app-updates>
- <https://developer.android.com/guide/playcore/in-app-updates/kotlin-java>
- <https://developer.android.com/guide/playcore/in-app-updates/test>

**Basics:**
- Library `com.google.android.play:app-update(-ktx):2.1.0`, released May 2023. It is required when targeting Android 14+, and still the latest as of the notes updated 2026-09-16.
- Android 5.0+. Supported on phones, tablets and ChromeOS. **Not compatible with OBB.**
- **Flexible** flow: downloads in the background, then the app calls `completeUpdate()`. **Immediate** flow: full-screen, and Play restarts the app.
- `AppUpdateOptions.setAllowAssetPackDeletion(true)` lets the update clear asset packs when storage is low.

**Priority and staleness:**
- `inAppUpdatePriority` is 0–5 and is set **only through the Publishing API** (`edits.tracks` → `releases[]`).
- It **cannot be changed after rollout**, and it is not supported for internal-app-sharing uploads.
- `clientVersionStalenessDays()` reports how long the update has been available.

**Testing:**
- Use internal app sharing.
- The account must own the app. The application ID and signing key must match, and the new build needs a higher versionCode.
- The API works **only for Play-installed builds.** Sideloaded or ADB builds report "no update".

**Is it the right mechanism?** Yes for Play binaries. Play already auto-updates; the in-app API handles:
1. Users who open the game before auto-update has run.
2. Enforcing a minimum version.

**Minimum-version enforcement.** Play has no native "minimum version" gate, so build one:
- Host a signed `config.json` on the CDN with `{min_version_code, recommended_version_code, per_channel…}`.
- On boot, if `versionCode < min`:
  - **Play:** start the **immediate** flow.
  - **GitHub/Obtainium:** show a blocking screen with a link to the release or Obtainium.
- Also set priority 5 in CI for critical releases.

---

## 4. Google Play policies

### 4.1 Device and Network Abuse [V] <https://support.google.com/googleplay/android-developer/answer/9888379>

Quoted text:
- "An app distributed via Google Play may not modify, replace, or update itself using any method other than Google Play's update mechanism."
- "Likewise, an app may not download executable code (such as dex, JAR, .so files) from a source other than Google Play."
- "This restriction does not apply to code that runs in a virtual machine or an interpreter where either provides indirect access to Android APIs (such as JavaScript in a webview or browser)."
- "Apps or third-party code, like SDKs, with interpreted languages (JavaScript, Python, Lua, etc.) loaded at run time … must not allow potential violations of Google Play policies."

**Interpretation for Godot `.pck` files [U, but industry practice]:**
- **Data-only packs** (`.tres`/`.res`, `.ctex`, `.ogg`, JSON, scenes without scripts) are *content*, not executable code. Games routinely download levels and items this way.
- **Packs with GDScript** are a grey zone. GDScript is interpreted, but in 4.7 it can reach Android APIs fairly directly through `JavaClassWrapper`, `AndroidRuntime` and plugin singletons. That weakens the "indirect access" exemption. Apple's App Store guideline 2.5.2 is stricter still.
- **Policy for Diceroll:**
  - Content packs **must not contain `.gd`, `.gdc` or `.cs` files, or scenes with embedded scripts.**
  - CI enforces this.
  - The runtime mounts only packs whose SHA-256 appears in a **signed** manifest.
  - Behaviour changes ship in the binary. Packs declare `min_core` (content-schema version).

### 4.2 Payments [V] <https://support.google.com/googleplay/android-developer/answer/9858738>

- In-app sales of digital items or content ("add-on items, characters…", "app functionality or content") **must use Play Billing**. The exception is the alternative-billing and external-offer programs in eligible regions, which require enrolment.
- **March 2026 changes** (Epic settlement): <https://android-developers.googleblog.com/2026/03/a-new-era-for-choice-and-openness.html> [V]
  - Developers may offer their own billing alongside Play's, or link out.
  - Play billing costs a separate 5% in the EEA, UK and US.
  - The IAP service fee is 20% on new installs. Participants in the revamped Level Up or Apps Experience programs get lower rates: "20% … from existing installs and a 15% fee on transactions from new app installs". Subscriptions are 10%.
  - Rollout: EEA, UK and US by June 30, 2026. Australia by Sept 30. Korea and Japan by Dec 31. The rest by Sept 30, 2027.
  - "Registered App Stores" arrives with a major Android release by the end of 2026.
- **Cross-platform:** an app may be "consumption-only" and unlock content bought elsewhere, for example a web or Steam entitlement, as long as it doesn't sell inside the app. [V, search snippet] <https://support.google.com/googleplay/android-developer/answer/10281818>
- **If packs become paid DLC:**
  - **Play build:** Play Billing one-time product, then entitlement, then download from the CDN. A server should verify purchase tokens.
  - **GitHub build:** your own store, such as itch.io or Stripe, or a cross-platform account entitlement.
- **Pack delivery and payment are separate.** PAD doesn't check purchases, so any client can fetch any on-demand pack. That's fine for DLC as long as unlocking is gated by entitlement.

### 4.3 Target API and 16 KB [V]

- **Target API** <https://support.google.com/googleplay/android-developer/answer/11926878>:
  - New apps and updates must target **API 36 (Android 16) from Aug 31, 2026**, with an extension to Nov 1, 2026 on request.
  - Existing apps must target ≥ 35 to stay visible on newer OS versions.
  - **Godot 4.7.2 defaults to target 36** (`DEFAULT_TARGET_SDK_VERSION = 36`). Our presets leave `target_sdk=""`, so 36 applies.
- **16 KB pages** <https://developer.android.com/guide/practices/page-sizes> (page updated 2026-09-16):
  - All apps targeting API 35+ must support 16 KB pages on 64-bit devices.
  - "**Starting February 1, 2027**, if your app updates don't support 16 KB memory page sizes, you won't be able to release these updates." Earlier "Nov 1 2025 / May 2026" dates in secondary sources are superseded.
  - Godot 4.7.2 complies (see 2.1).

### 4.4 Other relevant Play items

- **Level Up program** (optional). The benefits are featuring and "expanded APK size limits", with lower fees planned.
  - Requirements: Sidekick integration plus PGS achievements by **July 2026**, and cloud save by **November 2026**. [V] <https://developer.android.com/blog/posts/level-up-test-sidekick-and-prepare-for-upcoming-program-milestones>
- **PGS v1 SDK removal:** removed from the SDK in May 2026, and calls fail from as early as July 2028. Use v2 only. [V] <https://developer.android.com/games/docs/release-notes>
- **`REQUEST_INSTALL_PACKAGES`** is a restricted permission on Play. Don't ship a self-updater in any binary that also goes to Play. [U: known policy, not re-fetched]

---

## 5. Android developer verification, status on 2026-09-29

Sources [V]:
- <https://developer.android.com/developer-verification>
- <https://developer.android.com/developer-verification/guides>
- <https://developer.android.com/developer-verification/guides/faq>
- <https://developer.android.com/developer-verification/guides/google-play-console>
- <https://support.google.com/googleplay/android-developer/answer/16984799>
- <https://support.google.com/googleplay/android-developer/answer/16761053>

**Timeline:**
- **Aug 2026:** developer APIs, limited-distribution accounts and the power-user "advanced flow" launch.
- **Sept 30, 2026 (tomorrow):**
  - Enforcement starts in **Brazil, Indonesia, Singapore and Thailand** on certified Android 7+ devices.
  - It covers **installs from participating stores only**: Google Play, HONOR App Market, OPPO App Market, Galaxy Store, Palm Store, V-Appstore, GetApps.
  - FAQ (updated 2026-07-15): "The September 30, 2026 deadline only applies to the specific participating stores … if users sideload your app directly, these new verification requirements won't apply to your app yet."
  - Secondary press claims all sideloads are covered from September. That contradicts the primary FAQ; trust the FAQ.
- **2027:** global enforcement for **all apps on certified devices**, whatever the install source, so including GitHub and Obtainium.

**Play side:**
- "Effective September 30, 2026, all Play packages must be registered … Apps not registered by Sep 30, 2026 will be removed from Play." About 99% were auto-registered.
- If you use Play App Signing, apps are claimed automatically.
- Check the Play Console Home page. **Action today.**

**Distributing on and off Play:**
- Use the existing Play Console. It can register off-Play apps and **additional signing keys** for a package: "Once you have registered a package name, you can add additional keys."
- Ownership proof: build a release APK containing an `assets/adi-registration.properties` snippet, signed with that key.
- The Android Developer Console (ADC) for off-Play-only developers costs **$25** for full distribution. Individuals need government ID; organisations need a D-U-N-S number and a verified website.

**Limited distribution:**
- Free, no ID, **up to 20 devices**. For students and hobbyists.
- You can upgrade to full distribution later, but not downgrade.

**ADB and the advanced flow:**
- **ADB installs are exempt**, with no waiting period.
- **Advanced flow** for unregistered apps:
  1. Enable developer mode.
  2. Answer an "are you being coached?" check.
  3. Reboot and re-authenticate.
  4. Wait a one-time **24 h**.
  5. Confirm with biometrics.
  6. Allow unregistered installs for 7 days or indefinitely. A warning still shows at install.
- Unregistered apps can be updated **only** while the advanced flow is enabled.

**APIs for CI:** the "Android Developer ID Status API" (check eligibility and status) and the "Android Developer Console API" (register packages and keys).

**Impact on the GitHub/Obtainium channel:**
- If `gg.vlad.diceroll` is registered with **every key used for GitHub APKs**, sideload users see no change in 2027.
- If Obtainium itself stays unregistered, users need the advanced flow once to install Obtainium. [U: Obtainium's registration status unknown]
- Installers running with ADB privileges through Shizuku appear to bypass verification. AOSP skips verification for `INSTALL_FROM_ADB` unless `forceVerification` is set. [U, secondary] <https://gist.github.com/agnostic-apollo/b8d8daa24cbdd216687a6bef53d417a6>
- F-Droid argues the scheme is existential for its re-signed catalogue. F-Droid 2.0 shipped 2026-09-24. [U, secondary] <https://pinggy.io/blog/f_droid_2_0_android_developer_verification/>

---

## 6. Signing

Sources [V]:
- <https://support.google.com/googleplay/android-developer/answer/9842756>
- <https://developer.android.com/google/play/app-updates>
- <https://source.android.com/docs/security/features/apksigning/v3-2>

**Keys:**
- **Upload key:** ours. RSA ≥ 2048. It can be reset.
- **App signing key:** held by Google.
- **New apps** are "automatically enrolled in **quantum-ready, hybrid signing** with Google-generated keys":
  - A classical RSA-4096 key for Android ≤ 16.
  - A **separate** new classical key plus an **ML-DSA-65** key in a **v3.2** hybrid block for **Android 17 (API 37)+**.
  - That's three keys in total. All three fingerprints must be registered with API providers, such as the PGS OAuth client.
  - v4 signing isn't used with hybrid signing.

**Changing the default:**
- "Change the app signing key", allowed **before any release reaches open testing or production**, offers two choices:
  - "Use the same key as another app in this developer account".
  - "Provide a copy of your app signing key", uploaded with the PEPK tool.
- Changing it strands existing internal and closed testers: they must reinstall. <https://support.google.com/googleplay/android-developer/answer/9859348>

**Cross-store distribution.** Play documents two options:
1. "let Google generate your app signing key and **download a signed, universal APK** from the Play Console or the Play Developer API to distribute elsewhere".
2. "generate the app signing key you want to use for all app stores and transfer a copy of it to Google".

Android accepts an update only if the application ID matches, the signing certificate matches (or a valid proof-of-rotation is present), and the versionCode is ≥ the installed one. **There is no installer lock.** Any store with the same key can cross-update. To prefer one store, give its builds higher versionCodes.

**Key upgrade (rotation):**
- Play offers an **annual** key upgrade.
- Android 17+ enforces the upgraded hybrid key (v3.2).
- Android 13–16 enforces the latest classical key (v3.1).
- Android 7–12 is checked by Play Protect only.
- Self-managed rotation: `apksigner rotate` plus a v3 lineage (Android 9+).

**v3.2 behaviour:**
- The hybrid block is an **implicit rotation**: `K0 → C_K1 → PQC_K1`.
- Rolling back to a classical-only signer needs a ROLLBACK capability in the lineage.
- **So if a Play build with v3.2 is installed on Android 17+, a GitHub APK signed only with K0 may be rejected as a downgrade.** [U → P]
- We don't know whether Play grants ROLLBACK, or whether it applies hybrid signing to custom (PEPK-uploaded) keys. [U]

**Can we use one signing key for Play and GitHub so users can switch?** Yes, two ways:

| Option | How | Pros | Cons |
|---|---|---|---|
| **A (recommended): Play-signed universal APK on GitHub** | CI uploads the AAB, then `generatedapks.list(versionCode)` → `generatedUniversalApk.downloadId` → `generatedapks.download`, and attaches the APK to the GitHub release | Same signer everywhere, including the Android 17 hybrid. Works even if Play already uses a Google-generated key. Auto-registered for verification. No distribution key to guard. | GitHub releases depend on Play processing (poll). A fat APK with all AAB ABIs. Google holds the key. Rules out F-Droid reproducible builds under our key. Must **not** enable Play "automatic protection" (the API lists "unprotected" variants only for split and standalone APKs). **Existing GitHub users signed with our current key must reinstall once.** |
| B: own key everywhere | Upload the current GitHub keystore as the app signing key through PEPK, before any open or production release. Create a *new* upload key. Keep signing GitHub APKs ourselves. | Existing sideload users keep updating. Independent of Google. | Key custody. Play recommends separate upload and signing keys. **Unknown whether Play adds v3.2 hybrid for Android 17+ and how Play→GitHub updates then behave [P].** The Play "Change key" window closes at the first open or production release. |

**Recommendation:** decide **before the first open-testing or production release**.
- Default to **A**. It's the only option with no known Android 17 risk, and it's explicitly supported.
- Choose **B** only if independence from Google or an F-Droid path matters more.
- In both cases, keep the upload key and PGS OAuth fingerprints in the runbook.

---

## 7. Alternative Android stores and channels, 2026

| Channel | Status (2026) | Effort | Verdict |
|---|---|---|---|
| **Google Play** | Primary. PAD, In-App Updates, PGS, Billing. | – | **Yes** |
| **GitHub Releases + Obtainium** | Obtainium is active (v1.6.x). Sources include GitHub, GitLab, Codeberg, F-Droid, IzzyOnDroid, itch.io and direct links. [V] <https://github.com/ImranR98/Obtainium> | already done | **Keep.** Register the key or use option A. |
| **itch.io (APK)** | CI already pushes web builds to itch. Obtainium supports itch.io. [V, secondary] | trivial | Yes, optional |
| **IzzyOnDroid repo** | Serves developer-signed APKs from GitHub; FOSS required (the repo is MIT). [U: requirements not re-checked] | low | Optional |
| **Self-hosted F-Droid repo** (`fdroidserver` on GitHub Pages) | Works with any APK. Marginal value over Obtainium. | low–medium | Skip unless requested |
| **F-Droid main repo** | Builds from source and signs with the F-Droid key (conflicts with option A). The Godot build-from-source recipe is heavy. Uncertain future under verification. | high | Skip for now |
| **Accrescent** | "Sign-up … only permitted for allowlisted GitHub accounts … **not currently accepting new allowlist requests**". Funding-limited. [V] <https://accrescent.app/docs/guide/getting-started/new-app.html> | – | No |
| **Epic Games Store (mobile)** | Android worldwide. Self-publishing for iOS and Android announced "from August 2026" at 0% on the first $1M, then 12%. [V announcement] <https://www.pocketgamer.biz/epic-games-store-opens-up-to-mobile-self-publishing-in-august/> Launch not confirmed. [U] | medium (Epic payments for IAP) | Watch; revisit after 1.0 |
| **Samsung Galaxy Store** | Participating store for verification. Samsung-device reach. | medium | Later / optional |
| **Amazon Appstore** | Discontinued on non-Amazon Android on **2025-08-20**. Fire tablets and TV continue. [V] <https://community.amazondeveloper.com/t/whats-changed-as-of-aug-20-amazon-appstore-for-android-shutdown/16282> | – | No (Fire: low value, no GMS) |
| **Google Play Games on PC** | "Making all mobile games available on PC **by default** with the option to opt out" (Mar 2025). [V] <https://android-developers.googleblog.com/2025/03/making-google-play-best-place-to-grow-pc-games.html> ARM or x86-64. ARM games run through Intel Bridge, but x86-64 is recommended. Needs GLES ≤ 3.2 or Vulkan ≤ 1.1, and mouse and keyboard playability. [V] <https://developer.android.com/games/playgames/start> | low: add `architectures/x86_64=true` to the AAB, test in the PC dev emulator | **Yes** (cheap reach). Keep the Steam/itch native desktop builds separate. |
| **Play native PC (WAB)** | Windows App Bundle publishing exists, but the checklist relies on "Play partner" contact and early-access GUIDs. [V] <https://developer.android.com/games/playgames/native-pc/checklist> | – | Not for now (see 06-pc-stores.md) |
| **Huawei AppGallery** | Not researched in depth. HarmonyOS NEXT doesn't run APKs. [U] | medium | Skip |

---

## 8. CI: Google Play Developer Publishing API and tools

Sources [V]:
- <https://developers.google.com/android-publisher/getting_started>
- <https://developers.google.com/android-publisher/edits>
- Discovery doc revision 20260929

**Setup:**
- Create a Cloud project and enable "Google Play Android Developer API".
- Create a service account.
- In Play Console → **Users & permissions**, **invite the service-account email**. "You no longer need to link your developer account to a Google Cloud Project."

**Edits:**
- `edits.insert` → `edits.bundles.upload` (resumable, max 50 GB). **Asset packs travel inside the AAB**; there is no separate pack upload.
- Then `edits.tracks.update/patch` → `edits.commit`.
- Only **one open edit per user**. Console changes discard an open edit.
- `commit` options:
  - `changesNotSentForReview`
  - `changesInReviewBehavior`, which defaults to `CANCEL_IN_REVIEW_AND_SUBMIT`. Use `ERROR_IF_IN_REVIEW` to avoid cancelling a pending review.

**Releases:**
- `TrackRelease`: `versionCodes`, `status` (`draft`, `inProgress`, `halted` or `completed`), `userFraction` for staged rollout (only with `inProgress` or `halted`), `inAppUpdatePriority` (0–5, immutable after rollout), `releaseNotes`, and `countryTargeting` (production `inProgress` only).
- **Internal app sharing:** `internalappsharingartifacts.uploadbundle` (≤ 10 GB) returns a `downloadUrl`. Use it for testing in-app updates and PAD.
- **Generated APKs:** `generatedapks.list(versionCode)` returns `generatedUniversalApk`, `generatedSplitApks`, `generatedAssetPackSlices` and `unprotected*` variants. `generatedapks.download` fetches them. This powers option A.
- Other endpoints: `applications.deviceTierConfigs.*` and `appsigning.rotateAppSigningKey`. The latter is interesting but not needed.

**Tools, all maintained:**
- `r0adkll/upload-google-play` v1.1.5, commits as recent as 2026-09-06.
- Triple-T `gradle-play-publisher` 4.1.1 (Aug 2026).
- fastlane `supply` 2.240.1.
- Keep r0adkll. **Change `status: draft` → `completed` for the internal track** so testers actually receive builds. Use `inProgress` plus `userFraction` for staged production.
- r0adkll supports `inAppUpdatePriority` and `userFraction` inputs. [U: input names not re-checked]

---

## 9. Recommended Android strategy for Diceroll

### 9.1 Channels

1. **Google Play** is the primary channel. Enable the Google Play Games on PC form factor after adding `x86_64` to the AAB preset and testing mouse input.
2. **GitHub Releases + Obtainium** is the secondary channel. The APK is the **Play-signed universal APK** (option A).
3. **itch.io APK** is optional and cheap. Later: IzzyOnDroid, Galaxy Store, and Epic mobile if self-publishing is really open.

### 9.2 Binary update mechanism per channel

| Channel | Mechanism | Min-version enforcement |
|---|---|---|
| Play | Play auto-update plus the In-App Updates plugin: flexible by default, immediate if `versionCode < min_version_code` or priority ≥ 4 | Signed `config.json` on the CDN. CI sets `inAppUpdatePriority`. |
| GitHub/Obtainium | Obtainium polls releases. The game fetches `config.json` or the GitHub `releases/latest` and shows a banner or blocking screen that links out. **No self-installer.** | Same `config.json` |
| Installer detection | Kotlin: `packageManager.getInstallSourceInfo(pkg).installingPackageName == "com.android.vending"` (API 30+) chooses the Play or CDN backends | – |

versionCode scheme: monotonic, derived from semver, identical across channels because the build is identical under option A.

### 9.3 Content-pack delivery per channel

- **Tier 0, core:**
  - What: code, UI, rules, save system.
  - Where: the main export. Play: `assetPackInstallTime`, automatic. GitHub: APK assets.
  - Updated by: binary release.
- **Tier 1, launch data packs** (`weapons-base`, `biomes-tier1`, `foes`, `audio`):
  - What: `.pck` files, data only.
  - Where: embedded as `res://packs/*.pck` on every channel. On Play they sit in the install-time pack. Add the `noCompress 'pck'` template tweak.
  - Updated by: binary release, **or** a CDN patch PCK. A newer pack version on the CDN wins.
- **Tier 2, live and seasonal packs** (`weapons-2026-10`, …):
  - Where: **own CDN** on every channel. Use Cloudflare R2 (egress free, 10 GB-month free storage [V] <https://developers.cloudflare.com/r2/pricing/>) or a GitHub release named "packs".
  - Stored as `user://packs/<id>/<ver>.pck`.
  - Updated by: publishing the pack and manifest. **No binary release.**
- **Tier 3, optional heavy packs** (HD music and similar):
  - Where: first the CDN. Later, optionally PAD **on-demand** on Play only, if hosting cost or UX justifies it. That means template edits and a new versionCode per change.
  - Updated by: as its tier.

**Why not PAD fast-follow or on-demand for tiers 1–2 on Play?**
1. Any change still needs a new AAB and review; asset-only updates aren't public.
2. The sideload build needs the CDN anyway, so one code path is simpler.
3. At less than 130 MB, PAD's hosting and size advantages barely matter.
4. PAD adds invalidation-during-update states and template surgery.

**When to revisit:** content passes about 500 MB, CDN egress starts to cost money (R2 egress doesn't), or asset-only updates become public.

**Pack format and safety:**
- Each pack contains `res://content/<id>/pack.tres` with id, version, `min_core`, `requires` and a registry of definitions. The core discovers content data-driven.
- A **signed** `manifest.json` lists `{id, version, url, size, sha256, min_core, max_core, base (for delta patches)}`.
- Sign it with RSA or ECDSA through Godot `Crypto.verify`, with the public key embedded in the binary. [U: EC key support in `CryptoKey`; RSA is safe.]
- Mount only verified packs.
- Downloads are resumable (HTTP `Range`), verified with streamed SHA-256, and written atomically (temp file, then rename).
- **Wi-Fi only by default**, with a size disclosure prompt. That's the same UX Play requires for PAD.
- Keep `user_data_backup/allow=false`, or exclude `user://packs` from Auto Backup.

### 9.4 Plugin and abstraction shape

The GDScript side is platform-agnostic and shared with desktop and iOS:

```gdscript
# ContentService (autoload)
signal pack_state_changed(id: String, state: int)          # NOT_INSTALLED, PENDING, DOWNLOADING, WAITING_FOR_WIFI, NEEDS_CONFIRMATION, INSTALLED, INVALID, FAILED
signal pack_progress(id: String, bytes: int, total: int)
func refresh_catalog() -> void                              # fetch and verify the manifest, merge with embedded packs
func get_packs() -> Array[PackInfo]                         # id, version, size, state, source
func ensure(ids: PackedStringArray, allow_cellular := false) -> void
func confirm_cellular() -> void                             # Play: showConfirmationDialog; CDN: set a flag
func mount(id: String) -> Error                             # resolve path -> ProjectSettings.load_resource_pack(path, false)
func remove(id: String) -> void
# Backends: EmbeddedBackend (res://packs), CdnBackend (HTTPRequest -> user://packs), PlayAssetBackend (Android plugin)
```

The Android plugin is `DicerollPlay`: a v2 AAR written in Kotlin, with an `EditorExportPlugin` that adds Maven dependencies. Its `@UsedByGodot` surface:

- **Install source:** `getInstallSource(): String`
- **PAD:** `padGetStates(names: Array<String>)`, `padFetch(names)`, `padGetLocation(name): String` (empty if not ready), `padRemove(name)`, `padShowConfirmation()`
- **In-app updates:** `updCheck()`, `updStartFlexible()`, `updStartImmediate()`, `updComplete()`
- **Review:** `reviewRequest()`
- **Signals:** `pad_state(name, status, bytes, total, error)`, `upd_available(versionCode, priority, staleness)`, `upd_state(status, bytes, total)`, `review_done()`
- **Threading:** Play `Task` callbacks run on the main looper, then call `emitSignal`. Confirm how signals are marshalled onto Godot's thread [U]. Use `onMainResume` to resume an interrupted immediate update.

Dependencies:
- `com.google.android.play:asset-delivery-ktx:2.3.0`
- `com.google.android.play:app-update-ktx:2.1.0`
- `com.google.android.play:review-ktx` (latest; version not re-checked)

Billing and PGS: use the `godot-sdk-integrations` plugins rather than reimplementing them.

The APK preset must move to **Gradle builds** (`use_gradle_build=true`) so plugins are included. That happens automatically under option A, because the APK comes from the AAB.

### 9.5 CI steps (release.yml)

1. **Export the AAB** (Gradle, arm64-v8a + armeabi-v7a + x86_64, target 36) with the `DicerollPlay` plugin and the `noCompress 'pck'` template tweak.
2. **Verify** with `zipalign -c -P 16 -v 4` or `check_elf_alignment.sh` on a bundletool-built universal APK. Assert the AAB contains no `.gd`/`.gdc` files outside core, and that content packs contain none at all.
3. **Build packs** with a per-pack export preset or `godot --headless --export-pack`, or `export_pack_patch` with delta encoding for updates. Then compute SHA-256, write and sign `manifest.json`, and upload to R2 (S3 API) or a GitHub "packs" release.
4. **Upload to Play**, internal track, `status: completed`. For production use `status: inProgress`, a `userFraction` of 0.05 → 0.2 → 1.0, and `inAppUpdatePriority`. Use `changesInReviewBehavior=ERROR_IF_IN_REVIEW` when committing directly through the API.
5. **Option A:** poll `generatedapks.list(versionCode)`, download the universal APK, verify its signer with `apksigner verify --print-certs` against the expected SHA-256, and attach it to the GitHub release as `Diceroll-<v>-android.apk`. Obtainium keeps working.
6. **Update `config.json`** (`min_version_code`, the latest versions and pack pointers) and sign it.
7. **Developer verification (optional):** call the Developer ID Status API to assert that the package and key are registered.

### 9.6 Immediate action items

- [ ] **Today:** Play Console Home page → confirm `gg.vlad.diceroll` is registered for developer verification (deadline 2026-09-30). If Play is not live yet, confirm the app exists and is registered.
- [ ] Decide signing option A or B **before** any open-testing or production release. If B, upload through PEPK now.
- [ ] Switch r0adkll to `status: completed` for the internal track.
- [ ] Add a per-channel notice for GitHub users about the one-time reinstall if moving to option A. Provide save export or cloud save first.

---

## 10. Open unknowns and prototypes needed

1. **[P] Mount performance.** Measure `load_resource_pack` on 4.7.2 for:
   - (a) `res://packs/x.pck` inside the non-Gradle APK, stored uncompressed;
   - (b) the same inside the AAB install-time pack, with and without `noCompress 'pck'`;
   - (c) `user://packs/x.pck`;
   - (d) the PAD `getPackLocation` absolute path versus the same path rewritten to `user://`.

   Mount 5–20 packs at boot on a low-end device. Re-test the godot#105009 scenario.
2. **[P] PAD Kotlin plugin smoke test** through internal app sharing:
   - fast-follow and on-demand states, the cellular dialog, the path layout under `filesDir`;
   - behaviour right after an app update (invalidated packs);
   - stable pack names across versions.
3. **[P] Signing matrix** on Android 14, 16 and 17 devices or emulators:
   - Option A: install from Play, then update with the GitHub universal APK, and the reverse.
   - Option B: whether Play applies v3.2 hybrid to PEPK keys, and whether Play-to-sideload updates fail on 17+.
   - Android 14+ "update ownership": whether the Play Store claims ownership so Obtainium updates need confirmation. [U]
4. **[P] `generatedapks` timing and availability** for internal-track draft or completed bundles, and whether the universal APK includes all install-time content and ABIs.
5. **[U] Asset-only updates.** Ask Play support or a partner contact whether asset-only bundles are available to non-partners. Revisit yearly.
6. **[P] CDN pack pipeline:**
   - resumable download with `HTTPRequest` and a `Range` header;
   - streamed SHA-256 through `HashingContext`;
   - `Crypto.verify` of the manifest;
   - Godot delta-patch PCK applied on top of a mounted base pack.
7. **[U] Play review turnaround** for content-only binary releases. This matters if Tier 1 fixes ship through binaries.
8. **[P] Google Play Games on PC.** An x86_64 build in the developer emulator, mouse-only playability, and Vulkan versus Compatibility renderer.
9. **[U] Epic mobile self-publishing.** Did it open in August 2026? What are the requirements and billing rules?
10. **[U] Advanced flow.** Is it actually shipped on devices, and what is Obtainium's registration status? This only matters if we ever distribute an unregistered build.

---

## Sources (primary unless noted)

**Play Asset Delivery and bundletool**
- PAD overview: https://developer.android.com/guide/playcore/asset-delivery
- PAD Kotlin/Java integration: https://developer.android.com/guide/playcore/asset-delivery/integrate-java
- PAD testing: https://developer.android.com/guide/playcore/asset-delivery/test
- PAD library release notes: https://developer.android.com/reference/com/google/android/play/core/release-notes-asset_delivery
- Texture compression format targeting: https://developer.android.com/guide/playcore/asset-delivery/texture-compression
- Device targeting (beta): https://developer.android.com/guide/playcore/asset-delivery/device-targeting
- Play size limits: https://support.google.com/googleplay/android-developer/answer/9859372
- PAD launch blog (2020): https://android-developers.googleblog.com/2020/06/introducing-google-play-asset-delivery.html
- Play-as-you-download best practices: https://developer.android.com/google/play/play-as-you-download/best-practices
- bundletool `config.proto`: https://github.com/google/bundletool/blob/master/src/main/proto/config.proto
- Unity PAD pack-rename issue: https://github.com/google/play-asset-delivery-unity/issues/1
- Publishing API discovery doc: https://androidpublisher.googleapis.com/$discovery/rest?version=v3

**Godot**
- Godot 4.7.2 source (platform/android, core/io, core/config, editor/export): https://github.com/godotengine/godot/tree/4.7.2-stable
- Android plugins docs: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html
- Exporting PCKs docs: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_pcks.html
- Issue #105009: https://github.com/godotengine/godot/issues/105009
- PR #105984 (sparse PCK): https://github.com/godotengine/godot/pull/105984
- PR #90425: https://github.com/godotengine/godot/pull/90425
- Community SDK integrations: https://github.com/godot-sdk-integrations
- Play Billing plugin 3.2.0: https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/tag/3.2.0
- Play Games Services plugin: https://github.com/godot-sdk-integrations/godot-play-game-services
- In-app update plugin: https://github.com/icecube092/GodotInAppUpdate

**In-app updates**
- Overview: https://developer.android.com/guide/playcore/in-app-updates
- Kotlin/Java guide: https://developer.android.com/guide/playcore/in-app-updates/kotlin-java
- Testing: https://developer.android.com/guide/playcore/in-app-updates/test
- Release notes: https://developer.android.com/reference/com/google/android/play/core/release-notes-in_app_updates

**Play policy**
- Device and Network Abuse: https://support.google.com/googleplay/android-developer/answer/9888379
- Payments: https://support.google.com/googleplay/android-developer/answer/9858738
- Billing FAQ: https://support.google.com/googleplay/android-developer/answer/10281818
- Target API level: https://support.google.com/googleplay/android-developer/answer/11926878
- 16 KB page sizes: https://developer.android.com/guide/practices/page-sizes
- March 2026 billing and fees: https://android-developers.googleblog.com/2026/03/a-new-era-for-choice-and-openness.html
- Level Up program milestones: https://developer.android.com/blog/posts/level-up-test-sidekick-and-prepare-for-upcoming-program-milestones
- Android games release notes: https://developer.android.com/games/docs/release-notes

**Developer verification**
- Overview: https://developer.android.com/developer-verification
- Guides: https://developer.android.com/developer-verification/guides
- FAQ: https://developer.android.com/developer-verification/guides/faq
- Play Console guide: https://developer.android.com/developer-verification/guides/google-play-console
- Registering Play package names: https://support.google.com/googleplay/android-developer/answer/16984799
- Registering Android package names: https://support.google.com/googleplay/android-developer/answer/16761053

**Signing**
- Play App Signing: https://support.google.com/googleplay/android-developer/answer/9842756
- How app updates work: https://developer.android.com/google/play/app-updates
- APK Signature Scheme v3.2: https://source.android.com/docs/security/features/apksigning/v3-2
- Prepare and roll out a release: https://support.google.com/googleplay/android-developer/answer/9859348

**Stores**
- Amazon Appstore shutdown: https://community.amazondeveloper.com/t/whats-changed-as-of-aug-20-amazon-appstore-for-android-shutdown/16282
- Accrescent new-app guide: https://accrescent.app/docs/guide/getting-started/new-app.html
- Epic mobile self-publishing (press): https://www.pocketgamer.biz/epic-games-store-opens-up-to-mobile-self-publishing-in-august/
- Play Games on PC by default (2025): https://android-developers.googleblog.com/2025/03/making-google-play-best-place-to-grow-pc-games.html
- Play Games on PC getting started: https://developer.android.com/games/playgames/start
- Play native PC checklist: https://developer.android.com/games/playgames/native-pc/checklist
- Obtainium: https://github.com/ImranR98/Obtainium
- Cloudflare R2 pricing: https://developers.cloudflare.com/r2/pricing/

**CI**
- Publishing API setup: https://developers.google.com/android-publisher/getting_started
- Edits: https://developers.google.com/android-publisher/edits
- Tools: https://github.com/r0adkll/upload-google-play, https://github.com/Triple-T/gradle-play-publisher, fastlane

**Secondary context (not relied on for facts)**
- https://pinggy.io/blog/f_droid_2_0_android_developer_verification/
- https://gist.github.com/agnostic-apollo/b8d8daa24cbdd216687a6bef53d417a6
- https://android.gadgethacks.com/news/how-android-sideloading-verification-rules-affect-f-droid-and-privacy-tools/
