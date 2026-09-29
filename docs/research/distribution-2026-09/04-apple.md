# Diceroll: distribution, updates and content delivery on Apple platforms (as of 2026-09-29)

Scope: iPhone, iPad and Mac. Indie Godot 4.7.2 GDScript game, one developer, targeting only current
OSes (iOS/iPadOS 27, macOS 27; iOS 27.0.1 / macOS 27.0.1 shipped 2026-09-28). Planned design: small
core binary plus many small **data-only** Godot `.pck` content packs, mounted with
`ProjectSettings.load_resource_pack(path)` behind a per-platform delivery abstraction.

Legend: **[V]** means verified against the cited primary source (fetched today). **[V2]** means
verified against a reputable secondary source only. **[U]** means uncertain or inferred and needs a
prototype or a second source.

---

## 0. TL;DR

1. **You can add new packs and update existing packs without submitting a new app binary. [V]**
   This applies to Apple-hosted Background Assets on the App Store and TestFlight. Packs are
   uploaded and versioned independently of builds. Once the app has been approved once, a pack
   version can go to App Review "with or without an app version". Once approved, it replaces the
   previous version **for every installed app version, including old binaries**. That makes
   backward compatibility of packs your responsibility.
2. **Apple-hosted packs require an extra target and entitlements. [V]** The app needs a downloader
   extension (`StoreDownloaderExtension` from StoreKit), a shared App Group, and three Info.plist
   keys. Godot's exporter can't create extension targets, so CI has to post-process the generated
   Xcode project.
3. **You can get a plain file path. [V]** `AssetPackManager.url(for:)` returns a URL that is valid
   for the current process only. Apple packs are not delta-patched as far as anything documents
   **[U]**. Godot re-opens the `.pck` by path on every resource read [V, Godot source]. So mount an
   **immutable copy or clone** of each `.pck`, not the live system path. Background updates could
   otherwise swap the file under a mounted pack.
4. **Apple-hosted hosting is App Store/TestFlight only [V].** That means iOS, iPadOS and the
   **Mac App Store**. It is not available for Developer ID Mac apps. Developer ID keeps its own
   HTTPS pack downloader, with packs in `~/Library/Application Support`.
5. **Shipping new maps, weapons and enemies as data is endorsed [V].** Apple's own Background
   Assets docs describe downloading "level packs, 3D character models, and textures" and updating
   them independent of the app build. Guideline 2.5.2 and DPLA 3.3.1(B) forbid downloaded
   *executable* code, so **no GDScript in packs** (the design already requires this).
6. **On-Demand Resources is deprecated [V].** The deprecation is in the iOS/tvOS/visionOS 27
   release notes and Xcode 27. Don't use it.
7. **EU terms change on 2026-10-01 [V].** The Core Technology Fee is replaced by a 5% Core
   Technology Commission on *digital sales* in apps distributed outside the App Store. A free
   game pays nothing. Web Distribution eligibility is expanded but still out of reach for a solo
   indie.
8. **macOS 27 is Apple-silicon-only [V].** Ship an arm64-only Mac build, which roughly halves the
   ~163 MB universal binary.
9. **There is still no Apple API to check for or force app updates [V].** StoreKit's `AppStore`
   has none. Use your signed remote config (`min_supported`) plus the App Store page.

---

## 1. Background Assets: current state (iOS/iPadOS/macOS/tvOS/visionOS 26–27)

### 1.1 The three models

| Model | Min OS | Hosting | Extension protocol | Info.plist keys | Manifest |
|---|---|---|---|---|---|
| **Apple-hosted, managed** | 26.0 | App Store Connect (200 GB included) | `StoreDownloaderExtension` (StoreKit) | `BAAppGroupID`, `BAHasManagedAssetPacks=YES`, `BAUsesAppleHosting=YES` and **no other BA keys** | Apple JSON manifest per pack → `.aar` via `ba-package` |
| **Self-hosted, managed** | 26.0 | Your HTTPS server/CDN | `ManagedDownloaderExtension` (BackgroundAssets) | `BAAppGroupID`, `BAHasManagedAssetPacks=YES` (plus your manifest URL) | Same pack format; `ba-package download-manifest` / `--base-url` produce the server manifest [V2] |
| **Self-hosted, unmanaged** (legacy) | 16.1 | Your server | `BADownloaderExtension` (you write the scheduling code) | `BAManifestURL`, `BAInitialDownloadRestrictions`, `BAMaxInstallSize`, `BAEssentialMaxInstallSize`, `BAAppGroupID` | Your own format |

Sources: [Background Assets](https://developer.apple.com/documentation/backgroundassets) [V];
[BAHasManagedAssetPacks](https://developer.apple.com/documentation/bundleresources/information-property-list/bahasmanagedassetpacks) [V];
[BAUsesAppleHosting](https://developer.apple.com/documentation/bundleresources/information-property-list/bausesapplehosting) [V];
[Configuring an unmanaged project](https://developer.apple.com/documentation/backgroundassets/configuring-an-unmanaged-background-assets-project) [V];
[Downloading Apple-hosted asset packs](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs) [V].
The self-hosted managed manifest mechanics are thinly documented. The `ba-package download-manifest`
subcommand is described by the [Axiom reference](https://github.com/charleswiltgen/axiom/blob/main/axiom-codex/skills/axiom-integration/skills/background-assets-ref.md)
and the [freight Flutter package](https://pub.dev/packages/freight) **[V2/U]**.

**Is a downloader extension still needed for Apple-hosted packs? Yes. [V]**
- The `AssetPackManager` docs say you must adopt `ManagedDownloaderExtension` (self-hosted) or
  `StoreDownloaderExtension` from StoreKit (Apple-hosted). "Not doing so is a programmer error."
- In practice it is a four-line struct from Xcode's "Background Download → Apple-Hosted, Managed"
  template:
  ```swift
  import BackgroundAssets; import ExtensionFoundation; import StoreKit
  @main struct DownloaderExtension: StoreDownloaderExtension {
      func shouldDownload(_ assetPack: AssetPack) -> Bool { true } // optional filter
  }
  ```
- It is an ExtensionKit extension. Its `Info.plist` declares
  `EXExtensionPointIdentifier = com.apple.background-asset-downloader-extension`
  ([Schmitt, May 2026](https://schmittsfn.com/blog/2026/background-assets-in-production) [V2]).
- The app and the extension must share an App Group.
- A missing extension or app group **crashes** rather than erroring ([freight](https://pub.dev/packages/freight) [V2]).
- The process must be signed with a real team ID. There were simulator issues through 26.4, fixed
  in 26.5 per an Apple engineer ([forum 803976](https://origin-devforums.apple.com/forums/thread/803976) [V2]).

### 1.2 Swift API (`actor AssetPackManager`, `struct AssetPack`)

From the [AssetPackManager reference](https://developer.apple.com/documentation/backgroundassets/assetpackmanager) [V].
Availability comes from each symbol's page metadata.

| Purpose | API | Availability |
|---|---|---|
| Shared instance | `AssetPackManager.shared` | 26.0 |
| Discover available packs (current) | `manifest: AssetPackManifest` (async throws) → `.assetPacks`, `.assetPack(withID:)`, `.localizedAssetPacks` | **27.0** |
| Discover (older) | `allAssetPacks`, `assetPack(withID:)` | 26.0, **deprecated in 27.0** |
| Download / ensure present | `ensureLocalAvailability(of: AssetPack, requireLatestVersion: Bool = false)` | 26.4 (the plain `ensureLocalAvailability(of:)` is 26.0 and deprecated in 26.4) |
| Batch download | `ensureLocalAvailability(of: Set<AssetPack>, requireLatestVersions:)` throws `LocalAvailabilityError` with successes/failures | 27.0 |
| Force update check | `checkForUpdates() -> (updatingIDs, removedIDs)` (also removes obsolete packs) | 26.0 |
| Progress stream | `statusUpdates` (all packs) and `statusUpdates(forAssetPackWithID:)`: `.began`, `.paused`, `.downloading(pack, Progress)`, `.finished`, `.failed(pack, error)`; cancel via `progress.cancel()` | 26.0 |
| Status | `status(relativeTo:)` (26.4), `localStatus(ofAssetPackWithID:)` (26.4, offline), `assetPackIsAvailableLocally(withID:)` (26.4, sync); `status(ofAssetPackWithID:)` deprecated in 26.4. `AssetPack.Status` is an OptionSet: `downloadAvailable`, `downloading`, `downloaded`, `upToDate`, `outOfDate`, `obsolete`, `updateAvailable` | see left |
| Read files | `contents(at:searchingInAssetPackWithID:options:)` returns `Data`, mmapped by default. `descriptor(for:searchingInAssetPackWithID:)` returns a `FileDescriptor` you must close. **`url(for: FilePath) -> URL`** | 26.0 |
| Localized variants | `contents/descriptor/url(for:asLocalizedFor:)`, `resolvedLanguage`, `reconcilePreferredLanguages()` | 27.0 |
| Remove | `remove(assetPackWithID:)` | 26.0 |
| Version / size | `AssetPack.version: Int`, `AssetPack.downloadSize`; `localVersion(ofAssetPackWithID:)`, `localSize(...)` | 26.0 / **27.2 (currently beta)** |
| Metadata | `AssetPack.userInfo` is **always nil for Apple-hosted packs** ([doc](https://developer.apple.com/documentation/backgroundassets/assetpack/userinfo)) | 26.0 |

Objective-C equivalents exist (`BAAssetPackManager`, `BAManagedAssetPackDownloadDelegate`,
`getManifestWithCompletionHandler:` in 27, and so on). **This matters for Godot:** a plain
Objective-C++ GDExtension can drive BA without Swift.

**Removal and "relinquish".** There is no relinquish or purge concept. The system **never removes
packs automatically while the app is installed**, so call `remove(assetPackWithID:)` yourself.
`checkForUpdates()` removes packs that became obsolete, for example because they were archived in
App Store Connect. ([Downloading Apple-hosted packs](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs) [V];
[checkForUpdates](https://developer.apple.com/documentation/backgroundassets/assetpackmanager/checkforupdates()) [V].)

**Discovering newly available packs at runtime.**
- Read `AssetPackManager.shared.manifest` on iOS/macOS 27 (or `allAssetPacks` on 26). Diff it
  against the pack IDs you know about, then `ensureLocalAvailability` the ones you want.
- The system "automatically polls for updates periodically in the background" and keeps
  *downloaded* packs up to date ([status(relativeTo:)](https://developer.apple.com/documentation/backgroundassets/assetpackmanager/status(relativeto:)) [V]).
- **[U]** `essential`/`prefetch` policies are tied to `installationEventTypes` (`firstInstallation`,
  `subsequentUpdate`). A brand-new `prefetch` pack uploaded *between* app versions therefore
  probably is **not** fetched for existing installs until the next app update or an explicit
  request. Plan for the game to request new packs itself.

### 1.3 Download policies [V]

- `essential`: downloaded as part of install or update. It counts in the App Store / Home Screen
  progress, so the app launches with the pack present. It still may fail on network problems,
  so always call `ensureLocalAvailability`.
- `prefetch`: starts during install and may continue in the background after launch.
- `onDemand`: only on API request.

`essential` and `prefetch` take `installationEventTypes`: `["firstInstallation"]`,
`["subsequentUpdate"]`, or both. See
[Creating managed asset packs](https://developer.apple.com/documentation/backgroundassets/creating-managed-asset-packs) [V].

### 1.4 `ba-package`, the manifest, and local testing

**Commands**
- `xcrun ba-package template -o Manifest.json`, then `xcrun ba-package Manifest.json -o Pack.aar`.
  Paths are relative to the working directory or to `sourceRoot` [V].
- The packaging tool and mock server also exist for **Linux** ("Managed Background Assets
  Developer Tools for Linux", [ASC help](https://developer.apple.com/help/app-store-connect/manage-asset-packs/overview-of-apple-hosted-asset-packs) [V]).
  Localized packs are not supported by the Linux tools.
- Xcode 27 adds `ba-package convert` (Steam depot `.vdf` → manifest) [V: Xcode 27 release notes]
  and reportedly `ba-package evaluate` [V2].

**Manifest keys (Xcode 27 template)**
- `assetPackID`
- `downloadPolicy`
- `fileSelectors`: `file`, `directory`, and new in 27 `filePattern` (glob), `fileSource`/`fileDestination`,
  `directorySource`/`directoryDestination`, `fileExclusion`
- `platforms`: `iOS`, `macOS`, `tvOS`, `visionOS`. **Don't list `iPadOS`**, because `iOS` covers
  iPad and `ba-package` rejects it ([zenn, Jun 2026](https://zenn.dev/mtfum/articles/ios_apple_hosted_background_assets?locale=en) [V2]).
- `language` (27)
- `sourceRoot` (27)
- `userInfo` (self-hosted only)

The key list comes from the template quoted in [Itsuki, Sep 2026](https://medium.com/@itsuki.enjoy/swift-integrate-apple-hosted-managed-background-assets-7867175cbe98) [V2].
The Xcode 27 release notes list the feature set: "path wildcards, file exclusion, hard-coded source
roots, and custom destination subpaths" [V].

Example Diceroll pack manifest:

```json
{ "assetPackID": "s1.weapons-2026-10",
  "downloadPolicy": { "prefetch": { "installationEventTypes": ["firstInstallation","subsequentUpdate"] } },
  "fileSelectors": [ { "fileSource": "out/packs/weapons-2026-10.pck", "fileDestination": "packs/s1/weapons-2026-10.pck" },
                     { "fileSource": "out/packs/weapons-2026-10.json", "fileDestination": "packs/s1/weapons-2026-10.json" } ],
  "platforms": ["iOS", "macOS"] }
```

**Local testing**
- `xcrun ba-serve --host <host> Pack.aar …` is an HTTPS mock server; you need a self-made root CA
  trusted on the device.
- On-device override: Settings → Developer → Background Assets Testing → Development Overrides.
- On macOS: `xcrun ba-serve url-override <base URL>`
  ([Testing asset packs locally](https://developer.apple.com/documentation/backgroundassets/testing-asset-packs-locally) [V]).
- Xcode 27 can serve packs automatically from a "Background Asset Packs folder" in the Run scheme
  options [V: Xcode 27 RN].
- Apple-hosted packs **don't resolve in Xcode-installed builds**. Use the mock server, or install
  from TestFlight ([forum 809580](https://developer.apple.com/forums/thread/809580) [V2]).

### 1.5 Uploading packs (App Store Connect)

- **Transporter** (macOS app, v1.4.5 released 2026-09-08), **iTMSTransporter** (macOS, Windows,
  Linux CLI), and **`xcrun altool --upload-asset-pack <file> --apple-id <app Apple ID> …`**
  ([Upload Apple-hosted asset packs](https://developer.apple.com/help/app-store-connect/manage-asset-packs/upload-apple-hosted-asset-packs) [V]).
  One report says altool needs an **App Store Connect API key**
  (`--apiKey … --apiIssuer …`, with an optional `--type ios` and `--asset-pack-identifier`), and
  that app-specific passwords return 401 ([zenn](https://zenn.dev/mtfum/articles/ios_apple_hosted_background_assets?locale=en) [V2/U]).
- **App Store Connect REST API** ([Uploading and versioning Apple hosted background assets](https://developer.apple.com/documentation/appstoreconnectapi/managing-apple-hosted-background-assets) [V]).
  API 4.0 added it; 4.1 added checksums and release resources; 4.2 added `stateDetails`; 4.3 added
  `usedBytes`; 4.4 added the locale filter.

  | Step | Endpoint |
  |---|---|
  | Create pack record (once per pack ID) | `POST /v1/backgroundAssets` (`assetPackIdentifier` plus the app relationship) |
  | New version (auto-incrementing number) | `POST /v1/backgroundAssetVersions` |
  | Reserve upload (optionally validate `MANIFEST` first) | `POST /v1/backgroundAssetUploadFiles` (`assetType: ASSET` or `MANIFEST`, `fileName`, `fileSize`), then `PUT` the parts to the returned URLs |
  | Commit | `PATCH /v1/backgroundAssetUploadFiles/{id}` (`uploaded: true`, `sourceFileChecksums`) |
  | Read | `GET /v1/apps/{id}/backgroundAssets`, `GET /v1/backgroundAssets/{id}(/versions)`, `GET /v1/backgroundAssetVersions/{id}`, `…InternalBetaReleases/{id}`, `…ExternalBetaReleases/{id}`, `…AppStoreReleases/{id}` |
  | External TestFlight | `POST /v1/betaAppReviewSubmissions` |
  | App Store | `POST /v1/reviewSubmissions` plus review submission items (up to 10 packs per submission, one version per pack) |
  | Webhooks | `BACKGROUND_ASSET_VERSION_INTERNAL_BETA_RELEASE_CREATED`, `…EXTERNAL_BETA_RELEASE_STATE_UPDATED`, `…APP_STORE_RELEASE_STATE_UPDATED` (API 4.1) |

  Sources: [Background assets resource index](https://developer.apple.com/documentation/appstoreconnectapi/background-assets) [V];
  [ASC API release notes](https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-release-notes) [V].
- **`asc` CLI** ([rorkai/App-Store-Connect-CLI](https://github.com/rorkai/App-Store-Connect-CLI), a Go
  binary that runs on Linux) has a `background-assets` command group: create, versions,
  upload-files [V2]. Whether it has a one-shot "upload .aar and commit" is **[U]**.
- **Xcode** is not listed as an upload path for packs [V].

### 1.6 Review, TestFlight and release semantics

**Versioning is independent of builds. [V]**
- "You can also update additional content without creating a new app version." "Once uploaded,
  the asset pack is assigned a version, and it is not tied to any specific app build."
- An approved version "is available to any version of your app live on the App Store".
  ([ASC API guide](https://developer.apple.com/documentation/appstoreconnectapi/managing-apple-hosted-background-assets);
  [WWDC25-325](https://developer.apple.com/videos/play/wwdc2025/325/))
- WWDC25-325 warns that all installed versions switch to the new pack version, "so, before you
  update the asset pack, make sure that it will work on older app builds and versions as well." [V]

**App Review** ([Submit asset packs](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-apple-hosted-asset-packs) [V])
- Before the first app approval, pack versions must be submitted **in the same submission as the
  first app version**.
- After that, a pack version can be submitted "with or without an app version".
- There is a maximum of 10 packs per submission and one version of each.
- On approval it becomes available automatically and replaces previous versions.
- The "Processing for Distribution" state can take **up to 24 h**
  ([statuses](https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-statuses) [V]).

**TestFlight** ([Test asset packs](https://developer.apple.com/help/app-store-connect/test-a-beta-version/test-apple-hosted-asset-packs) [V])
- Internal testers get the latest processed version automatically, with no review.
- External testers need a TestFlight App Review of the pack version, one at a time, and a build
  must already be available for external testing.

**Size and count limits** ([limits](https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-size-limits) [V])
- **200 GB total per app record** (the maximum version size of each pack, summed) and
  **200 packs per app record**, shared across platforms.
- No per-pack or per-file limit is published.
- Archiving a pack removes all of its versions everywhere, including live ones.
- **One Apple-hosted pack serves one app across multiple platforms** ([WWDC25-325](https://developer.apple.com/videos/play/wwdc2025/325/) [V]).
  So a universal-purchase app record (iOS + macOS) can use the same packs on iPhone, iPad and Mac.

**Cellular. [U]** No developer-facing cellular policy is documented for managed packs. One
practitioner reports background essential/prefetch downloads wait for Wi-Fi. `shouldDownload(_:)`
can veto background downloads, for example on expensive networks via `NWPathMonitor` in the
extension ([zenn](https://zenn.dev/mtfum/articles/ios_apple_hosted_background_assets?locale=en) [V2]).
How foreground `onDemand` requests behave on cellular needs a prototype.

**Delta patching. [U]** The docs say only that the system handles "downloads, updates,
compression". A pack update appears to re-download the whole pack (a practitioner reports whole
multi-GB re-downloads). Keep packs small and immutable, and prefer **new pack IDs** for new
content over growing old packs.

### 1.7 Where files land, and getting a file path for Godot

- Location on disk is not documented. It is system-managed storage coordinated through the App
  Group, and people have reported it is outside the app sandbox. Usage appears under the app in
  Settings → Storage. [U]/[V2]
- All packs are **merged into one namespace** as if pasted into one root folder. Path collisions
  resolve arbitrarily, so give every file a pack-unique prefix, e.g. `packs/s1/<id>.pck`. [V]
- **`url(for:)` returns a well-formed file URL (`.path` gives the string for Godot). Don't persist
  it beyond the current process.** It also resolves directories. [V]
  ([url(for:)](https://developer.apple.com/documentation/backgroundassets/assetpackmanager/url(for:)))
- A practitioner feeds these URLs to an ML runtime that reads the files directly [V2]. From a
  descriptor, `fcntl(fd, F_GETPATH)` gives the real path. **`/dev/fd/N` is blocked by the iOS
  sandbox (EPERM)** ([zenn](https://zenn.dev/mtfum/articles/ios_apple_hosted_background_assets?locale=en) [V2]).
- **Godot constraint [V, source]:** `FileAccessPack` re-opens `pf.pack` **by path for every
  resource read** ([core/io/file_access_pack.cpp @4.7](https://github.com/godotengine/godot/blob/4.7/core/io/file_access_pack.cpp)).
  Godot 4.7 also has **no API to unload a pack**
  ([ProjectSettings @4.7](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html)).
  If Background Assets replaces a mounted pack in the background mid-session, offsets from the old
  directory would be read from the new file.
- **Recommendation:** after `ensureLocalAvailability`, `FileManager.copyItem` the `.pck` to
  `Library/Application Support/packs/<id>@v<version>.pck`. APFS makes this a copy-on-write clone,
  so it is near-free in time and space. Mount the copy, and garbage-collect old versions on next
  launch. **[U: prototype that clone works across the BA store and the app container, and that
  the space is really shared.]**

### 1.8 Platform availability

- **iOS/iPadOS 26+, macOS 26+, tvOS 26+, visionOS 26+ for managed packs; not watchOS. [V]**
  Unmanaged is iOS 16.1+ / macOS 13+. iPhone and iPad apps running on visionOS get Background
  Assets from visionOS 1.0 [V].
- **Apple-hosted = "apps distributed through the App Store on all platforms except watchOS",
  plus TestFlight. [V]** That includes the **Mac App Store** and TestFlight for Mac.
- **Developer ID Mac apps:** Apple hosting is not offered.
  - Self-hosted managed or unmanaged BA is not explicitly restricted to the App Store, but:
    - install-time extension launches are tied to App Store installs ([WWDC23-10108](https://developer.apple.com/videos/play/wwdc2023/10108/) [V2]);
    - on macOS the extension does get periodic runtime even after the app is quit ([forum 724374](https://developer.apple.com/forums/thread/724374) [V2]);
    - unmanaged BA on macOS requires **App Sandbox on both the app and the extension** [V].
  - Viability for Developer ID is **[U]**, and not worth it. A plain HTTPS downloader is simpler
    there.
- **Localized asset packs** are new in 27 [V] (not needed now).
- **iOS 27 / Xcode 27 changes [V]:**
  - `manifest` API
  - batch ensure
  - localized packs
  - manifest wildcards and exclusions, `sourceRoot`, destination subpaths
  - Steam converter
  - Xcode-served packs while debugging
  - a fixed ba-package bug that could produce invalid on-demand archives
  - `localVersion` / `localSize` in 27.2 beta

  Sources: [iOS 27 RN](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes);
  [Xcode 27 RN](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes);
  [WWDC26-378 "Unlock in-game content with StoreKit and Background Assets"](https://developer.apple.com/videos/play/wwdc2026/378/),
  which also announced Unity plug-ins for StoreKit and Background Assets. Their repo location is **[U]**.

### 1.9 On-Demand Resources

"On Demand Resources and the `NSBundleResourceRequest` API are deprecated. Use Background Assets
instead." Source: iOS & iPadOS 27 and Xcode 27 release notes [V]. `NSBundleResourceRequest` shows
availability "iOS 9.0 – 27.0". No removal date is given. Don't adopt it.

---

## 2. App Store Review Guidelines (last updated 2026-06-08) and DPLA

All quotes are from the [current guidelines](https://developer.apple.com/app-store/review/guidelines/) [V].

**2.5.2**
- Apps "may not … download, install, or execute code which introduces or changes features or
  functionality of the app."
- It restricts **code**, not data.

**DPLA 3.3.1(B)** ([DPLA, updated 2026-08-18](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) [V])
- "An Application may not download or install executable code."
- Interpreted code may be downloaded only if it (a) doesn't change the app's primary purpose,
  (b) doesn't bypass signing or sandbox, and (c) doesn't create a storefront for other apps.
- GDScript would arguably fit here, but keep packs **data-only** anyway. That removes any argument
  and matches the Play policy.

**4.2.3**
- "(i) Your app should work on its own without requiring installation of another app."
- "(ii) If your app needs to download additional resources in order to function on initial
  launch, disclose the size of the download and prompt users before doing so."
- In practice: keep the core playable from the IPA plus `essential` packs, which count as install
  and need no prompt. Show a size-disclosing prompt before any large `onDemand` download that
  gates play.

**2.1 App Completeness**
- Reviewers must be able to exercise all features.
- Include the referenced asset packs in the submission. A practitioner warns about rejection if
  the reviewer sees a "download to use" gate ([Schmitt](https://schmittsfn.com/blog/2026/background-assets-in-production) [V2]).

**2.3.1(a)**
- No hidden or dormant features, and describe new features in the Review Notes.
- Content added later via Apple-hosted packs goes through App Review, which satisfies this.
- For self-hosted content, keep it within the declared age rating and described functionality.

**4.7 (mini apps, mini games, streaming, plug-ins, emulators)**
- Allows HTML5/JS mini games "not embedded in the binary", subject to 4.7.1–4.7.5 (privacy,
  content filtering, 3.1 compliance, an index with universal links, age gating).
- **Not relevant** to first-party data packs. Don't frame packs as "games".

**2.4.5 (Mac App Store only)**
- "(iv) They may not download or install standalone apps, kexts, additional code, **or resources
  to add functionality or significantly change the app** from what we see during the review
  process."
- "(vii) They must use the Mac App Store to distribute updates."
- On the Mac App Store, only deliver content via **Apple-hosted packs** (which are reviewed), not
  self-hosted downloads.

**Is new content as downloaded data explicitly acceptable? Yes, by Apple's own framing [V].**
- The Background Assets overview example is a game downloading "level packs, 3D character
  models, and textures".
- Apple-hosted hosting exists precisely to "update them independent of your app build".

**If packs ever become paid DLC**
- **3.1.1:** unlocking "game levels, access to premium content" must use IAP, and restorable
  purchases need a restore mechanism. For permanent DLC use a **non-consumable** IAP and gate
  mounting on StoreKit 2 `Transaction.currentEntitlements`.
- **[U]** Apple-hosted packs have no per-user entitlement gating: any install can download the
  bytes. So entitlement checks happen in the app before mounting. That is the same deterrence
  level as Steam or itch.
- **3.1.3(b) Multiplatform Services:** items bought elsewhere (Steam, itch, web) may be unlocked
  "provided those items are also available as in-app purchases within the app".
- **3.1.1(a):** external purchase links are allowed on the **US storefront** without an
  entitlement.
- **EU (from 2026-10-01):** alternative payments alongside IAP. EU App Store IAP commission is
  26%, or **15% for Small Business Program** members; alternative in-app PSP is 20%/10%
  ([DMA page](https://developer.apple.com/support/dma-and-apps-in-the-eu/) [V]).

---

## 3. macOS: Developer ID vs Mac App Store

### 3.1 Developer ID (keep as the primary Mac channel)

**Architecture**
- "macOS 26 is the final release supporting Intel Mac computers and Rosetta — macOS 27 will be
  Apple silicon only" ([Apple news 2026-09-09](https://developer.apple.com/news/?id=k1mtkt1k) [V]).
- If you target macOS 27 only, set Godot `binary_format/architecture=arm64`. This drops the
  x86_64 slice of the ~163 MB universal bundle.
- Keep universal only if you want to keep supporting macOS 26 on Intel.

**Signing and hardened runtime**
- The existing `tools/ci/macos_package.sh` (codesign `--options runtime --timestamp`, notarytool
  with an API key, staple the .app) is correct.
- A GDScript-only Godot game needs **no extra hardened-runtime entitlements**: no JIT, no unsigned
  memory.
- Godot's doc says to enable *Disable Library Validation* only for GDExtensions or ad-hoc signing
  ([Exporting for macOS @4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html) [V]).
  If you add a GDExtension (Sparkle bridge) or Sparkle.framework, **sign them with the same
  Developer ID team** and library validation passes without that entitlement [U: standard
  behavior, verify with `codesign -dv` and a launch test].
- Remove the `Debugging` entitlement before notarizing [V].

**Notarization** ([Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) [V])
- Submit with `xcrun notarytool submit <zip|dmg|pkg> --key AuthKey.p8 --key-id … --issuer … --wait`.
- **ZIPs can't be stapled.** Staple the .app, then re-zip (this already happens).
- DMGs and flat pkgs can be stapled.
- Improvement: also notarize and staple the signed DMG, not only the .app inside it.

**Container format**
- **DMG** for first install (drag to /Applications).
- **ZIP** or Apple Archive for update payloads.
- **pkg** isn't needed: no system-wide install, no root.

**Content packs**
- Store in `~/Library/Application Support/<bundle-id>/packs/` (Godot `user://` with a custom
  user dir). Never modify the signed bundle.
- Download with the existing signed-manifest updater: RSA SHA-256 `.sig`, per-pack sha256.

**Binary updates**

| Option | Pros | Cons |
|---|---|---|
| **Sparkle 2 (2.9.6, 2026-08-17)** ([releases](https://github.com/sparkle-project/Sparkle/releases) [V]) | macOS standard: EdDSA-signed updates **and** (2.9) signed appcast feeds, `generate_appcast` builds **binary delta updates**, gentle reminders, sandbox support via XPC services, zip/dmg/pkg/`.aar` archives, `sparkle:minimumUpdateVersion` and `sparkle:hardwareRequirements` (arm64) in 2.9 | Needs a small native bridge: Godot has no nib, so start `SPUStandardUpdaterController` from an Objective-C GDExtension or GDExtension init. `sparkle-cli` was removed from the binary distribution in 2.9.0 [V], so a CLI-only approach is harder. Min macOS 12 |
| Velopack ([docs](https://docs.velopack.io/packaging/operating-systems/macos) [V2]) | One tool for Win/mac/Linux, Zstandard deltas, can generate pkg and notarize | **App Sandbox unsupported**; built for .NET/Rust/C apps (needs a native lib in Godot); replaces the bundle via AppleScript elevation when in /Applications |
| Own updater (current: "open URL") | Zero native code | Manual re-download; no delta |

**Recommendation:** keep "open URL" until 1.0. Then add Sparkle 2 through a tiny GDExtension.
Frequent updates are already handled by the pack updater, so binary updates are rare.

**Background Assets on Developer ID:** not recommended (§1.8).

### 3.2 Mac App Store and TestFlight for Mac (optional, phase 2+)

**Why consider it**
- Apple-hosted packs work on the Mac App Store (macOS 26+). **One app record with universal
  purchase** (same bundle ID for the iOS and macOS builds) means one set of packs,
  `platforms: ["iOS","macOS"]`, serves all three devices.
- TestFlight supports macOS builds [V].

**Costs**
- App Sandbox is mandatory (Godot has `codesign/entitlements/app_sandbox/*`).
- Updates must come from the Mac App Store (2.4.5(vii)).
- Self-hosted downloads are risky (2.4.5(iv)).
- You need a downloader extension target, so export the macOS **Xcode project**. Godot 4.7's
  macOS exporter can generate one: `application/version` maps to "Identity > Build in the
  generated Xcode project" ([EditorExportPlatformMacOS @4.7](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformmacos.html) [V]).

**Cheapest variant:** let the **iPad build run on Apple-silicon Macs** ("Designed for iPad").
Godot's doc notes iOS exports run natively on Apple-silicon Macs [V]. It's a checkbox in App Store
Connect, but Mac UX (window, mouse, keyboard) is iPad-like, and Background Assets behavior for
iPad-on-Mac is **[U]**.

**Verdict:** worth it *after* the iOS App Store pipeline with Background Assets works. Most of the
Xcode post-processing and pack logic is shared.

---

## 4. iOS distribution channels in 2026

### 4.1 Apple Developer Program

- **$99/yr** ([What's included](https://developer.apple.com/programs/whats-included/) [V]). It
  includes Developer ID and notarization, TestFlight, **up to 200 GB Apple-hosted Background
  Assets**, and 25 Xcode Cloud compute hours per month.
- Commission is 30%, or **15% in the Small Business Program**.
- SDK floor: **from April 2027, uploads must use the iOS 27 SDK (Xcode 27)**
  ([news 2026-09-09](https://developer.apple.com/news/?id=k1mtkt1k) [V]).
- Xcode 27 (27A266a) shipped on 2026-09-14. 27.1 and 27.2 are in beta
  ([releases](https://developer.apple.com/news/releases/) [V]).

### 4.2 TestFlight

- 100 internal testers, **10,000 external**, public links with criteria, and **90-day build
  expiry**.
- The first external build needs Beta App Review.
- Asset packs have their own review track.
- Sources: [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview) [V];
  [developer.apple.com/testflight](https://developer.apple.com/testflight/) [V].

### 4.3 EU alternative distribution (new unified terms, effective 2026-10-01)

Sources: [news 2026-08-18](https://developer.apple.com/news/?id=gmws0jgp);
[DMA page](https://developer.apple.com/support/dma-and-apps-in-the-eu/);
[Web Distribution](https://developer.apple.com/support/web-distribution-eu/). All [V].

**Fees**
- The **Core Technology Fee** (per install) is replaced by the **Core Technology Commission:
  5% of digital transactions** in apps distributed outside the App Store.
- The Initial Acquisition Fee and Store Services Fee are eliminated.
- **A free app with no digital sales pays 0.**

**Notarization** is mandatory for all iOS apps on every channel. It is a baseline review that
includes "no executable code downloads". Apple encrypts and signs the resulting Alternative
Distribution Package.

**Web Distribution eligibility (from Oct 1)** requires **one** of:
- a D&B low-risk score
- a public listing
- VC funding from a listed firm
- a US$1M standby letter of credit
- an audited financial statement
- nonprofit, education or government status
- 2 years of membership **and** 1M first annual EU installs

That is realistically out of reach for a solo indie.

**AltStore PAL** ([docs](https://faq.altstore.io/developers/distribute-with-altstore-pal.md) [V2])
- Needs a paid developer account, notarization, and a self-hosted ADP (Alternative Distribution
  Package) plus a source JSON with `marketplaceID`.
- Available in the **EU, Japan and Brazil**.
- The steps for authorizing the marketplace in App Store Connect under the new unified terms are
  **[U]**; verify after Oct 1.

### 4.4 SideStore / AltStore Classic (unsigned IPA)

**Free Apple ID limits** ([SideStore FAQ](https://docs.sidestore.io/docs/faq) [V2])
- 7-day signing with automatic refresh through SideStore.
- **3 active apps** (including SideStore itself).
- **10 App IDs per 7 days.** Each app extension consumes its own App ID [U].
- SideStore's install doc lists support "iOS/iPadOS 18.0–26.x". **iOS 27 support is [U].**

**Source JSON format** ([AltStore "Make a Source"](https://faq.altstore.io/developers/make-a-source), [Updating apps](https://faq.altstore.io/developers/updating-apps) [V2])
- Source fields: `name`, `subtitle`, `description`, `iconURL`, `headerURL`, `website`,
  `tintColor`, `featuredApps`, `apps[]`, `news[]`.
- App fields: `name`, `bundleIdentifier`, `developerName`, `localizedDescription`, `iconURL`,
  `category`, `screenshots` (also a `{iphone:[…], ipad:[…]}` form), `versions[]`, and
  **`appPermissions {entitlements[], privacy{}}`**, which must match the IPA exactly or install
  is refused.
- Version fields: `version`, `buildVersion`, `marketingVersion`, `date`, `localizedDescription`,
  `downloadURL`, `size`, `minOSVersion`, `maxOSVersion`, `assetURLs`.
- Newest version goes first. AltStore compares index 0 and ignores dates.

**Is the sideload IPA worth continuing?** Keep it as a **cheap CI by-product**. Don't invest in it.
- Once enrolled, TestFlight public links (10k testers, 90 days, no 7-day or 3-app pain) serve
  testers better.
- **Background Assets won't work in the sideload IPA**: Apple hosting needs TestFlight or App
  Store installs, and the extension costs an extra App ID.
- So build the sideload IPA **without** the downloader extension and BA plist keys, as a
  "full" IPA with packs embedded (~95 MB) or with the HTTPS pack downloader.

---

## 5. Godot 4.5–4.7 integration on iOS and macOS

**Two ways to call native APIs**
1. **GDExtension (recommended).**
   - An `.xcframework` or static lib listed in a `.gdextension`, loaded on iOS, macOS and visionOS.
   - The GDExtension API is forward-compatible across 4.x minors.
   - Proven examples:
     - [migueldeicaza/GodotApplePlugins](https://github.com/migueldeicaza/GodotApplePlugins): GameCenter, StoreKit2, Sign in with Apple, ARKit, CoreMotion. iOS xcframework as a Mergeable Library (~1.7 MB merged). iOS 17 / macOS 14 minimum. On the Godot Asset Store, updated 2026-06-15 [V2].
     - [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot): Swift bindings targeting Godot 4.6 [V2].
     - [atlasapplications/godot-store-kit](https://github.com/atlasapplications/godot-store-kit): StoreKit 2 via SwiftGodot, Godot 4.5.1 [V2].
     - [godot-sdk-integrations/godot-storekit2](https://github.com/vertexludi/godot-storekit2) [V2].
     - [hrk4649/godot_ios_plugin_iap](https://github.com/hrk4649/godot_ios_plugin_iap): built with Godot 4.7 and Xcode 26.5 [V2].
     - Apple's own [apple/plugins-for-godot](https://github.com/apple/plugins-for-godot): RealityKit (visionOS) and PHASE [V2].
   - **No existing Godot plugin for Background Assets was found.** You will write one:
     - Option (a): ~200 lines of **Objective-C++ against `BAAssetPackManager`** with godot-cpp.
       No Swift runtime, and the same code works for iOS and macOS.
     - Option (b): SwiftGodot, reusing Miguel's patterns.
2. **Legacy `.gdip` iOS plugin.**
   - A static lib compiled against *exact* engine headers
     ([docs @4.7](https://docs.godotengine.org/en/4.7/tutorials/platform/ios/ios_plugin.html), flagged "outdated" [V]).
   - Avoid it: it must be rebuilt for every Godot patch release.

**"Apple Embedded" restructure** [V]
- Godot 4.5 introduced `EditorExportPlatformAppleEmbedded` as the base for the iOS and visionOS
  exporters. Godot 4.5 added visionOS export.
- The `EditorExportPlugin.add_ios_*` methods are **deprecated** in favor of
  `add_apple_embedded_platform_{framework, embedded_framework, plist_content, linker_flags, bundle_file, cpp_code, project_static_lib}`
  ([EditorExportPlugin @4.7](https://docs.godotengine.org/en/4.7/classes/class_editorexportplugin.html)).

**What the Godot exporter can and can't do**
- Export options already cover:
  - `entitlements/additional` (add the App Group)
  - `application/additional_plist_content` (the BA keys)
  - `capabilities/additional`
  - `application/export_project_only` (hand the Xcode project to CI)

  ([EditorExportPlatformIOS @4.7](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformios.html) [V])
- **Nothing in Godot adds an app extension target. [V, absence in docs]**
- CI must post-process `build/ios/Diceroll.xcodeproj`, for example with the Ruby
  [`xcodeproj`](https://github.com/CocoaPods/Xcodeproj) gem, which ships with CocoaPods on the
  runner images. The script would:
  - add a target of type `com.apple.product-type.extensionkit-extension`, with Swift sources and
    an Info.plist carrying `EXAppExtensionAttributes.EXExtensionPointIdentifier = com.apple.background-asset-downloader-extension` **[U: verify the product type/embedding phase Xcode 27's template uses]**;
  - set bundle ID `<app>.BADownloader` and the App Group entitlement;
  - link BackgroundAssets, StoreKit and ExtensionFoundation;
  - add an "Embed ExtensionKit Extensions" copy phase (destination `Extensions`);
  - add a target dependency.
- Alternative: keep a small hand-made "wrapper" Xcode project, or XcodeGen/Tuist spec, that
  references Godot's generated sources. Regenerating with Godot's export on each build is simpler
  than the wrapper.

**`load_resource_pack` outside the bundle** [V]
- Works from arbitrary paths on exported iOS/macOS builds. The well-known `res://` DirAccess
  issues affect only the editor and Android
  ([#96298](https://github.com/godotengine/godot/issues/96298),
  [PR #90425](https://github.com/godotengine/godot/pull/90425),
  [#94793](https://github.com/godotengine/godot/issues/94793) fixed by 4.4.1).
- Load packs early, in an autoload's `_init`, and before anything references their paths
  (already the case: no preloads).
- **Engine-version gate:** runtime rejects packs "created with a newer version of the engine"
  (major.minor), and PCK format v4 is current in 4.7 [V, source].
  - Content packs must be built with the **oldest Godot minor among live binaries**.
  - A Godot minor upgrade needs a new pack-schema prefix. Apple-hosted packs are shared by all
    live binaries.
  - A SwiftGodotKit user hit "Pack version unsupported: 3" with version-mismatched runtimes
    ([SwiftGodotKit#54](https://github.com/migueldeicaza/SwiftGodotKit/issues/54) [V2]).
- Godot's **delta-encoded patch PCKs** exist ([Exporting packs @4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_pcks.html) [V]).
  They are useful for the desktop HTTPS channel. They are **fragile with Apple-hosted packs**,
  because base packs must be byte-identical and loaded in order. Prefer whole small packs on Apple.

---

## 6. CI (GitHub Actions) for Apple

### 6.1 Runners ([actions/runner-images](https://github.com/actions/runner-images) [V])

| Label | Details |
|---|---|
| `macos-26` / `macos-latest` (arm64) | macOS 26.6.2, default **Xcode 26.6** (26.0.1–26.6 installed) |
| **`xcode-27`** (arm64, *public preview*) | macOS 27.0 with **Xcode 27.0 default**, plus 27.1 and 27.2 beta; iOS 27.0–27.2 SDKs; fastlane 2.240.1 |
| `macos-26-intel` / `macos-15(-intel)` | still available |
| `macos-14` | deprecated, unsupported from 2026-11-02 |

- Use `xcode-27` for iOS 27 / macOS 27 SDK builds, and fall back to `macos-26` if the preview is
  flaky. Xcode 27 is mandatory from April 2027.
- Price for private repos is ~$0.062/min with a 10× included-minutes multiplier
  ([secondary](https://tenki.cloud/blog/github-actions-cost-optimization-2026) [V2]).
- Public repos are free.

### 6.2 Pipeline (build on the existing `ios_build.sh` and `macos_package.sh`)

1. **Linux job, packs.**
   - Export each data-only pack (Godot headless `--export-pack` with per-pack filters, or
     `PCKPacker`) plus `<id>.json`: id, schema, `min_binary`, `engine`, sha256, file list.
   - **Lint that no `.gd/.gdc/.gde/.cs/.dll/.so/.dylib/.gdextension` is inside.**
   - Sign the desktop manifest (existing RSA).
   - Build `.aar` per pack with `ba-package`: the Linux tools, or on the macOS job.
2. **Pack upload (only for changed packs).**
   - `asc background-assets …`, or a ~150-line Python client for the four ASC API calls (JWT from
     the existing `APPLE_API_KEY_*` secrets), or `xcrun altool --upload-asset-pack` with the API
     key on macOS.
   - Poll or webhook until "Ready for Internal Testing".
   - Submit external TestFlight review and App Store review via ASC API when promoting.
3. **macOS job, iOS.**
   - `tools/export.sh ios`, then the `xcodeproj` post-process (add the BA extension target and
     App Group).
   - `xcodebuild archive … -allowProvisioningUpdates -authenticationKeyPath/-ID/-IssuerID`.
     This is already done. With automatic signing, the key (Admin or App Manager role) also
     registers the extension App ID and App Group [U: confirm App Group creation works via
     automatic signing in CI; otherwise pre-create them once in the portal].
   - `xcodebuild -exportArchive` with `method=app-store-connect` and `destination=upload`, or
     `asc builds upload` / `altool --upload-package`.
   - Uploads via altool, Transporter, Xcode and the ASC API "Build uploads" resource (API 4.1)
     are all supported
     ([Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds) [V];
     [Build uploads API](https://developer.apple.com/documentation/appstoreconnectapi/build-uploads) [V]).
     altool is **not** deprecated for uploads. It was retired only for notarization, in 2023
     [U: from memory].
   - Build the sideload IPA from the project **before** post-processing, so it has no extension.
4. **Build numbers.** `CFBundleShortVersionString` is the semver. `CFBundleVersion` must strictly
   increase per version; use `github.run_number` or `asc builds next-build-number`. Godot maps
   them to `application/short_version` and `application/version`.
5. **macOS Developer ID.**
   - Export `arm64` (macOS 27 target), sign, notarize, and staple the .app and the DMG.
   - Later, Sparkle: `sign_update` with the EdDSA private key in a secret, `generate_appcast`
     (deltas), and publish `appcast.xml` to GitHub Pages or Releases.
6. **(Phase 2) Mac App Store.**
   - Godot macOS export as an Xcode project with the sandbox on, plus the same BA extension
     post-process.
   - Archive with `-allowProvisioningUpdates`, export the `.pkg` for App Store Connect, and
     upload.

---

## 7. Update prompts on the App Store

- **No Apple API reports "an update is available" or forces a minimum version [V].** StoreKit's
  `AppStore` has only environment, payments, age rating, device verification, subscription
  management, `requestReview`, offer codes, `sync`, and 27's `presentMerchandising(.subscriptionBundle)`
  ([AppStore](https://developer.apple.com/documentation/storekit/appstore) [V]).
- Recommended approach, which is what `game/update/update_policy.gd` already does:
  1. Read the signed remote `min_supported` / `latest` per channel.
  2. Optionally cross-check `https://itunes.apple.com/lookup?bundleId=…&country=…`. This is
     unofficial, cached, and per storefront [V2].
  3. Show a soft prompt (or a hard gate only below `min_supported`).
  4. Open the product page with `SKStoreProductViewController` (native plugin) or
     `OS.shell_open("itms-apps://apps.apple.com/app/id<APPLE_ID>")`.
- Content is independent of this: Background Assets keep packs updated for **all** binaries, so
  "new content requires new app" must be expressed per pack (`min_binary` in pack JSON). The game
  then shows "Update the app to unlock this content" instead of mounting.

---

## 8. Recommended Apple strategy

### 8.1 Channels

| Priority | Channel | Status |
|---|---|---|
| 1 | **iOS/iPadOS App Store + TestFlight** (one universal iPhone+iPad binary; min iOS **27.0** to use `manifest`; 26.4 is the fallback floor if reach matters) | build now |
| 2 | **macOS Developer ID** (GitHub Releases / site, notarized DMG, arm64-only for macOS 27) | keep; add Sparkle post-1.0 |
| 3 | **Mac App Store + TestFlight for Mac** in the **same app record** (universal purchase → shared Apple-hosted packs) | phase 2, after BA works on iOS |
| 4 | SideStore/AltStore Classic unsigned "full" IPA | keep as a free CI by-product, no new investment; iOS 27 support by SideStore [U] |
| 5 | AltStore PAL (EU/JP/BR) | optional; free app ⇒ no CTC; needs notarization + ADP hosting |
| — | EU Web Distribution | not eligible in practice |

### 8.2 Binary update mechanism per channel

| Channel | Binary updates |
|---|---|
| App Store / TestFlight / Mac App Store | Store (auto-update) plus an in-game prompt from the signed remote config |
| Developer ID | Now: prompt + open URL. Later: Sparkle 2 (EdDSA, deltas, gentle reminders) via a GDExtension bridge |
| Sideload IPA | AltStore source JSON (`versions[0]`), which SideStore also reads |
| AltStore PAL | PAL source with `marketplaceID` and ADP URL |

### 8.3 Content-pack delivery per channel

| Channel | Pack source | Notes |
|---|---|---|
| **iOS/iPadOS App Store + TestFlight** | **Apple-hosted managed Background Assets** | See below |
| Mac App Store | Apple-hosted (same packs, `platforms:["iOS","macOS"]`) | Don't self-host (2.4.5(iv)) |
| macOS Developer ID | Own HTTPS CDN (GitHub Releases / R2) → `~/Library/Application Support/<id>/packs` | Same `.pck` files and signed manifest as the other desktop channels; per-pack sha256 |
| Sideload IPA | Embedded ("full" IPA), optionally the HTTPS downloader to `Library/Application Support` | No BA extension |

Why Apple-hosted on the App Store:
- no CDN
- system background downloads and updates that survive app kills
- install-integrated `essential`/`prefetch`
- 200 GB free
- Apple-reviewed content, so it complies with 2.3.1 and 2.4.5

What it costs:
- a review round-trip plus up to 24 h processing for each content drop
- no per-binary pinning
- no `userInfo`
- testing via TestFlight or `ba-serve`

**Self-hosted managed** is the alternative if review latency becomes painful. The game-side
abstraction makes that a backend swap.

Pack policies:
- Core gameplay stays **in the IPA** (main PCK).
- Launch-critical packs use `essential` with `firstInstallation` + `subsequentUpdate`, e.g.
  `biomes-tier1`, `foes`, `audio`.
- Nice-to-have packs use `prefetch`.
- Seasonal drops use **new pack IDs** (`weapons-2026-10`), discovered via `manifest` and fetched
  by the game.

### 8.4 Game-side abstraction

```
ContentDelivery (autoload, GDScript)
 ├─ backend: EmbeddedBackend | HttpBackend (desktop/sideload/web) | AppleAssetPackBackend (GDExtension) | PlayAssetBackend
 ├─ list_available() -> Array[PackInfo]          # Apple: manifest.assetPacks (27) / allAssetPacks (26)
 ├─ status(id) -> {state, local_version, remote_version, download_size}
 ├─ ensure(id) -> emits progress(id, fraction), ready(id, local_path) | failed(id, err)
 ├─ remove(id); check_updates()                  # Apple: checkForUpdates()
 └─ mount(id): read <id>.json → gate on schema/min_binary/engine → ProjectSettings.load_resource_pack(stable_path, false)
```

How the Apple backend works:
- It lives in an Objective-C++ GDExtension that wraps `BAAssetPackManager`.
- Pack IDs are namespaced by schema, e.g. `s1.<name>`.
- Each `.pck` and `.json` sits at `packs/s1/<name>.*` inside its asset pack.
- After `ensureLocalAvailability`, it resolves `url(for:)`, then **APFS-clones** the file to
  `Library/Application Support/packs/<name>@v<AssetPack.version>.pck` and returns that path.
- It never caches the system URL across launches.
- It relays `statusUpdates` as Godot signals, marshalled to the main thread.
- If a mounted pack updates mid-session, it records "update ready, applies next launch".

Rules for every backend:
- packs are data-only
- mount with `replace_files=false` for additive content (a code/UI patch pack, if any, is not used on iOS)
- mount before first `load()`
- the registry is built from pack JSON so new content appears without code changes

### 8.5 Costs (per year)

| Item | Cost |
|---|---|
| Apple Developer Program (Developer ID, notarization, TestFlight, 200 GB BA hosting, 25 h Xcode Cloud/mo) | **$99** |
| Commission (only if paid) | 15% (Small Business Program); EU from Oct 1: IAP 15%/26%, CTC 5% outside the App Store |
| GitHub macOS minutes | $0 on a public repo; private ~$0.062/min (10× multiplier) |
| Desktop pack CDN | $0 (GitHub Releases) or ~$0 egress (Cloudflare R2) |
| AltStore PAL | $0 for a free app (CTC is on sales only) [U: PAL-side fees] |

---

## 9. Open unknowns that need prototypes (in priority order)

1. **Godot mounting a BA-delivered `.pck` on an iOS 27 device and macOS 27.**
   - Is the `url(for:)` path readable by Godot's `FileAccess` (plain `open`)?
   - Does `FileManager.copyItem` produce an APFS clone from the BA store into the app container,
     without doubling storage?
   - Fallback: `descriptor` + `fcntl(F_GETPATH)`.
2. **Behavior when a pack updates while the game runs.** Is the old file kept (inode) or swapped?
   Does the system defer? This decides whether cloning is mandatory.
3. **Discovery of new packs uploaded after install.** Does `manifest` list them immediately? Does
   a new `prefetch` pack auto-download for existing installs, or only on the next app update or
   on request?
4. **Adding the ExtensionKit downloader target to Godot's generated Xcode project in CI**
   (`xcodeproj` gem), including automatic signing registering the extension App ID and App Group
   via the API key.
5. **Review latency and behavior for pack-only submissions** (typical time to "Ready for
   Distribution", and whether "Processing for Distribution" really takes up to 24 h). Also,
   2.1 reviewer expectations when some content is `onDemand`.
6. **Delta updates for pack versions.** Likely none, so measure bytes transferred on a
   one-file change.
7. **Cellular behavior** of foreground `onDemand` requests, and whether a user prompt is needed
   (4.2.3(ii)).
8. **`ba-package` on Linux** (download location, version parity with Xcode 27) and a scripted
   ASC upload path: `asc background-assets` vs a Python client vs altool with an API key.
9. **Universal purchase with a native Godot macOS build**, and Background Assets for the
   "Designed for iPad" Mac variant.
10. **Engine-version drift.** Test that packs built by the oldest live Godot minor load in newer
    binaries, and document the schema bump policy.
11. **SideStore on iOS 27**, and whether the sideload IPA still installs and refreshes.
12. **AltStore PAL onboarding under the Oct 1 terms** (marketplace authorization in App Store
    Connect, ADP hosting on GitHub Releases via `assetURLs`).
13. **Sparkle via GDExtension:** signing Sparkle's XPC services and Autoupdate with Developer ID,
    and hardened-runtime launch without Disable Library Validation.

---

## 10. Source index (primary unless noted)

**Background Assets and App Store Connect**
- Background Assets framework: https://developer.apple.com/documentation/backgroundassets
- Creating managed asset packs: https://developer.apple.com/documentation/backgroundassets/creating-managed-asset-packs
- Downloading Apple-hosted packs: https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs
- Testing locally: https://developer.apple.com/documentation/backgroundassets/testing-asset-packs-locally
- Localized packs: https://developer.apple.com/documentation/backgroundassets/reducing-download-and-storage-demands-with-localized-asset-packs
- AssetPackManager: https://developer.apple.com/documentation/backgroundassets/assetpackmanager
- AssetPack: https://developer.apple.com/documentation/backgroundassets/assetpack
- Unmanaged configuration: https://developer.apple.com/documentation/backgroundassets/configuring-an-unmanaged-background-assets-project
- ASC Help, overview: https://developer.apple.com/help/app-store-connect/manage-asset-packs/overview-of-apple-hosted-asset-packs
- ASC Help, upload: https://developer.apple.com/help/app-store-connect/manage-asset-packs/upload-apple-hosted-asset-packs
- ASC Help, submit: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-apple-hosted-asset-packs
- ASC Help, TestFlight: https://developer.apple.com/help/app-store-connect/test-a-beta-version/test-apple-hosted-asset-packs
- ASC Help, size limits: https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-size-limits
- ASC Help, statuses: https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-statuses
- ASC API guide: https://developer.apple.com/documentation/appstoreconnectapi/managing-apple-hosted-background-assets
- ASC API endpoints: https://developer.apple.com/documentation/appstoreconnectapi/background-assets
- ASC API release notes: https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-release-notes
- WWDC25-325: https://developer.apple.com/videos/play/wwdc2025/325/
- WWDC26-378: https://developer.apple.com/videos/play/wwdc2026/378/

**Release notes and news**
- iOS & iPadOS 27 RN: https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
- macOS 27 RN: https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes
- Xcode 27 RN: https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
- Releases: https://developer.apple.com/news/releases/
- News, SDK requirements and Apple silicon: https://developer.apple.com/news/?id=k1mtkt1k
- News, EU terms: https://developer.apple.com/news/?id=gmws0jgp

**Policy and terms**
- Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- DPLA: https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
- DMA page: https://developer.apple.com/support/dma-and-apps-in-the-eu/
- Web Distribution: https://developer.apple.com/support/web-distribution-eu/
- What's included: https://developer.apple.com/programs/whats-included/

**Distribution tooling**
- TestFlight overview: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview
- Upload builds: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds
- Build uploads API: https://developer.apple.com/documentation/appstoreconnectapi/build-uploads
- Notarization workflow: https://developer.apple.com/documentation/security/customizing-the-notarization-workflow
- StoreKit AppStore: https://developer.apple.com/documentation/storekit/appstore
- NSBundleResourceRequest: https://developer.apple.com/documentation/foundation/nsbundleresourcerequest

**Godot**
- iOS plugins: https://docs.godotengine.org/en/4.7/tutorials/platform/ios/ios_plugin.html
- Exporting for iOS: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html
- Exporting for macOS: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html
- Exporting packs: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_pcks.html
- EditorExportPlugin: https://docs.godotengine.org/en/4.7/classes/class_editorexportplugin.html
- EditorExportPlatformIOS: https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformios.html
- EditorExportPlatformMacOS: https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformmacos.html
- ProjectSettings: https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html
- `file_access_pack.cpp` @4.7: https://github.com/godotengine/godot/blob/4.7/core/io/file_access_pack.cpp

**CI and updaters**
- Runner images: https://github.com/actions/runner-images
- Sparkle releases: https://github.com/sparkle-project/Sparkle/releases
- Sparkle docs: https://sparkle-project.org/documentation/
- Velopack macOS: https://docs.velopack.io/packaging/operating-systems/macos

**Secondary sources [V2]**
- Stefan Schmitt, "What Apple's Background Assets docs don't tell you" (2026-05): https://schmittsfn.com/blog/2026/background-assets-in-production
- zenn/mtfum, Apple-hosted BA (2026-06): https://zenn.dev/mtfum/articles/ios_apple_hosted_background_assets?locale=en
- Itsuki, Medium (2026-09): https://medium.com/@itsuki.enjoy/swift-integrate-apple-hosted-managed-background-assets-7867175cbe98
- Blake Crosley, ODR deprecation: https://blakecrosley.com/blog/on-demand-resources-deprecated-background-assets
- Axiom BA reference: https://github.com/charleswiltgen/axiom/blob/main/axiom-codex/skills/axiom-integration/skills/background-assets-ref.md
- freight: https://pub.dev/packages/freight
- Apple forums: https://developer.apple.com/forums/thread/809580, https://origin-devforums.apple.com/forums/thread/803976, https://developer.apple.com/forums/thread/724374
- AltStore source docs: https://faq.altstore.io/developers/make-a-source and https://faq.altstore.io/developers/updating-apps
- AltStore PAL: https://faq.altstore.io/developers/distribute-with-altstore-pal.md
- SideStore FAQ: https://docs.sidestore.io/docs/faq
- asc CLI: https://github.com/rorkai/App-Store-Connect-CLI
- Godot plugins: https://github.com/migueldeicaza/GodotApplePlugins, https://github.com/migueldeicaza/SwiftGodot, https://github.com/apple/plugins-for-godot
