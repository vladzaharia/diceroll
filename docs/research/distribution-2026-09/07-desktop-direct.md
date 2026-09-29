# 07: Direct (non-store) desktop distribution, self-update and code signing (Godot 4.7.2)

Research date: **2026-09-29**. Scope: Diceroll direct builds for Windows 11, macOS (current) and
Linux (including Steam Deck desktop mode), published outside Steam, itch.io and the app stores.

Labels used below:
- **[V]**: verified against a primary source today (URL given).
- **[V-2nd]**: verified against a reputable secondary source.
- **[U]**: uncertain, inferred or not tested. Check before relying on it.

---

## 0. TL;DR

1. **Blocking issue: `--main-pack` does not work on official 4.6+ export templates.** Since Godot 4.6,
   release templates are built with `disable_path_overrides=yes`. `--main-pack` (and `--path`,
   `--scene`, `--script`) then makes the engine **abort** at startup. Only editor builds, Web and
   templates compiled with `disable_path_overrides=no` accept it (Android was partly restored).
   Diceroll's current updater (`game/update/updater.gd`) relaunches with `--main-pack`, so on
   official 4.7.2 templates it will probably fail at the first code update. Test this first; see §5.1. **[V]**
   ([PR #111909](https://github.com/godotengine/godot/pull/111909),
   [issue #119376](https://github.com/godotengine/godot/issues/119376),
   [4.7 CLI docs legend](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html),
   [Flathub BaseApp fix](https://github.com/flathub/org.godotengine.godot.BaseApp/commit/5c5ce34cd7c3c55923d7b09d4c91bf6f5cbcf116))
2. **Recommended architecture: Velopack for the binary and code pack on Windows and macOS, plus
   Velopack AppImage on Linux. Flathub is a second Linux and Steam Deck channel with self-update
   turned off.** Our GDScript updater handles **data-only content packs** from R2 and nothing else.
   Code ships inside the Velopack package (engine and code `.pck`). Velopack's per-file zstd deltas
   keep code-only updates small, so the `--main-pack` swap is no longer needed on desktop.
3. **Windows signing:** use **Azure Artifact Signing** (the new name of Trusted Signing),
   **$9.99/month Basic, 5,000 signatures**. It is **only open to individuals in the US or Canada**;
   organizations can also be in the EU or UK. It **no longer gives instant SmartScreen reputation**,
   and neither does EV since 2024: reputation builds over time on a consistent identity. CI uses
   OIDC with `azure/login` and then either `vpk --azureTrustedSignFile` or `azure/artifact-signing-action@v2`. **[V]**
4. **macOS:** keep Developer ID signing, notarization and stapling (App Store Connect API key).
   Sparkle 2.9.6 is the best-in-class macOS updater (EdDSA signatures, signed feeds, BinaryDelta),
   but it needs native glue in Godot and a second release pipeline. Velopack macOS is good enough
   for one developer who wants one system. Homebrew **disabled casks that fail Gatekeeper in
   September 2026**, so a cask is only possible because we notarize. **[V]**
5. **Linux:** Flathub is possible (MIT code, CC0 and purchased art, prebuilt PCK on the Godot BaseApp,
   license `LicenseRef-proprietary` for the art). Turn off binary and code self-update inside the
   Flatpak. Data packs can go to `~/.var/app/<id>/data`, or better, ship bundled so OSTree deltas
   handle them. AppImage from Velopack for direct downloads. Keep tar.gz as a no-updater fallback.

---

## 1. Velopack

### 1.1 Status, maturity and license
- **Current version: 1.2.161, published 2026-09-29 (today).** 1.0.1 (GA) came out on 2026-05-26,
  1.1.1 on 2026-05-30, 1.2.0 on 2026-06-03 and 1.2.158 on 2026-09-21. Before May 2026 the only
  releases were `0.0.x` prereleases. **[V]** (crates.io API `crates/velopack`, NuGet `vpk` index;
  note that GitHub's release page renders these dates confusingly.)
- **License: MIT.** About 2.2k GitHub stars. Main maintainer: caesay (the Clowd.Squirrel author). **[V]**
  ([repo](https://github.com/velopack/velopack))
- The updater core is written in Rust. SDKs exist for C#, Rust, JS, **C/C++** (prebuilt
  `velopack_libc` with both a C ABI and a C++ API) and Python. The `vpk` CLI is a .NET tool
  (needs the .NET SDK; its package targets net8, net9 and net10). **[V]**
  ([docs](https://docs.velopack.io/), [C++ start](https://docs.velopack.io/getting-started/cpp))
- **Game precedent:**
  - **osu!** (ppy/osu) uses Velopack 1.2.0 (`osu.Desktop.csproj`, `Updater/VelopackUpdateManager.cs`). **[V]**
  - **Chromonia** is a Godot 4.6.1 **C#** game from 2026. Its release workflow runs `vpk pack` for
    win-x64, osx-universal and linux-x64. **[V-2nd]**
    ([workflow](https://github.com/juan-medina/chromonia/blob/b228aabe404af50dc95b1579f5edfa5203fe38c7/.github/workflows/release.yml))
  - **No GDScript or GDExtension Velopack integration exists that I could find** **[U]**. A Unity
    Asset Store item is only an open issue ([#164](https://github.com/velopack/velopack/issues/164)).

### 1.2 How it works per OS
| | Windows | macOS | Linux |
|---|---|---|---|
| Installer | `{id}-Setup.exe`: one-click, **per-user**, no UAC, installs to `%LocalAppData%\{packId}`, optional splash. Optional `--msi` for per-machine installs | Generated and signed **`.pkg`** (user picks /Applications or ~/Applications), plus a portable `.zip`. **No DMG** (make one yourself from the zip) | **No installer. The output is a single self-updating `.AppImage`** |
| Layout | `{packId}\current\` (replaced on update), `Update.exe`, root stub `{App}.exe` | Self-contained `.app` bundle, replaced atomically | Single file, replaced atomically |
| Update cache | `%LocalAppData%\{packId}\packages` | `~/Library/Caches/velopack/{packId}/packages` | `/var/tmp` |
| Elevation | None (per-user) | AppleScript prompt only if the app is in `/Applications` | `pkexec` only if the file is in a privileged folder |

All rows **[V]**: [Windows](https://docs.velopack.io/packaging/operating-systems/windows),
[macOS](https://docs.velopack.io/packaging/operating-systems/macos),
[Linux](https://docs.velopack.io/packaging/operating-systems/linux).

- Velopack **does not support the macOS App Sandbox** (not an issue for direct builds). **[V]**
- **Cross-compiling:** Windows and Linux packages can be built on any OS (`vpk [win] pack`,
  `vpk [linux] pack`). **macOS packages need a macOS machine** (codesign, productbuild). **[V]**
  ([cross-compiling](https://docs.velopack.io/packaging/cross-compiling))
- **AppImage runtime:** in May 2026 Velopack AppImages still needed FUSE2
  ([#875](https://github.com/velopack/velopack/issues/875)). [PR #899](https://github.com/velopack/velopack/pull/899)
  switched to the static **type2 runtime** (no libfuse2 needed) and was merged on 2026-05-26, so
  **1.0.1+ should include it** **[V PR merged; U that the shipped build uses it]**. The runtime
  vendored in `vpk` is about 0.94 MB, which fits the static runtime. Test on Fedora Atomic and SteamOS.

### 1.3 Delta packages
- `vpk pack` builds a delta automatically when the previous full release is in `--outputDir`.
  In CI, run `vpk download <source>` first. **[V]** ([deltas](https://docs.velopack.io/packaging/deltas))
- Deltas are **per-file binary patches made with Zstandard** (`--delta BestSpeed`, the default, or
  `BestSize`, which is about as slow as bsdiff). **No single file may exceed 2 GB.**
- Clients can chain several deltas (1.0.0 → 1.0.1 → 1.0.2 …). A heuristic falls back to the full
  package when that is cheaper. Any delta failure also falls back to the full package.
  `Update.exe patch` and `vpk delta generate|patch` expose this manually. **[V]**
- Godot note: if only the code `.pck` changes, the delta is roughly the zstd patch of that one
  file. The engine binary is unchanged, so it costs close to nothing. **[U: measure with a real diff]**

### 1.4 Feeds, hosting and channels
- The feed is **static files**: `releases.{channel}.json` plus full and delta `.nupkg` files in the same folder.
  - `UpdateManager("https://…/prefix")` fetches `…/releases.{channel}.json`.
  - Supported sources: GitHub, Gitea, GitLab, S3, Azure Blob, local folder, plain HTTP, or a custom callback.
  - `vpk download|upload s3 --endpoint …` works with S3-compatible stores and supports `--keepMaxReleases N`. **[V]**
    ([deploy CLI](https://docs.velopack.io/distributing/deploy-cli),
    [self-hosting](https://docs.velopack.io/distributing/self-hosting),
    [vpk reference](https://docs.velopack.io/reference/cli/content/vpk-windows))
- **Cloudflare R2:** R2's S3 API uses region `auto` and now documents checksum support **[V]**
  ([R2 S3 compatibility](https://developers.cloudflare.com/r2/api/s3/api/)). An older Velopack PR for
  R2 streaming-SigV4 compatibility was **reverted** ([PR #116](https://github.com/velopack/velopack/pull/116)),
  so treat `vpk upload s3` to R2 as **[U]**. Safe fallback:
  1. `vpk download http --url https://updates.<domain>/<prefix>` (public R2 custom domain)
  2. `vpk pack`
  3. Upload with `rclone` or `aws s3 cp` and **upload `releases.*.json` last**, with
     `Cache-Control: no-cache` so the CDN never serves a feed that points at files not yet uploaded.
- **Channels:** each release belongs to one channel. The default channel is the OS name. For
  cross-platform, cross-arch and stable/beta builds, use one channel per OS × arch × track, for
  example `win-x64-stable`, `win-x64-beta`, `osx-universal-stable`, `linux-x64-stable`,
  `linux-arm64-stable`. Channel switching is supported and downgrades are off by default, which
  matches Diceroll's "no downgrades" policy. **[V]** ([channels](https://docs.velopack.io/packaging/channels))
- **Integrity:** the SDK checks package size and SHA hashes from the feed (`ChecksumFailedException`).
  **The feed itself is not signed** (it relies on HTTPS and bucket write control) **[U: no feed
  signing found in docs]**. Our existing RSA-3072 manifest signing could cover it. The C API's
  `vpkc_new_source_custom_callback` lets us fetch and verify a detached signature of
  `releases.*.json` before handing it to Velopack. **[V: API exists]**
  ([C API](https://docs.velopack.io/reference/cpp/c-api))

### 1.5 Integrating with a non-.NET app (Godot)
- **Two paths:**
  1. **SDK (C ABI).** `vpkc_app_run()` must run first at startup. Then `vpkc_new_update_manager`,
     `vpkc_check_for_updates`, `vpkc_download_updates(progress cb)`, and
     `vpkc_wait_exit_then_apply_updates(asset, silent, restart, args)`. There is no apply-and-restart
     helper, so call apply and then `exit`. **[V]**
  2. **CLI only.** `Update.exe apply [--package P] [--waitPid PID] [--norestart] [-- args]`,
     `Update.exe start`, `Update.exe patch --old --delta --output`, and `Update.exe uninstall`.
     **The updater binary has no "check" or "download" command.** Those live in the SDK, so a
     GDScript-only integration would have to reimplement the feed and delta logic (fetch the feed
     JSON, pick deltas, run `Update patch`, place files in the packages dir). That is possible but
     fragile. **[V]** ([Update.exe CLI](https://docs.velopack.io/reference/cli/content/update-windows))
- **Hooks:** Velopack runs the main exe with `--veloapp-install|obsolete|updated|uninstall {ver}`
  and kills it after 15–30 s. It also sets `VELOPACK_FIRSTRUN` and `VELOPACK_RESTART`. FastCallbacks
  are Windows-only. **[V]** ([hooks](https://docs.velopack.io/integrating/hooks))
  - Godot ignores unknown CLI args **[V]** (CLI docs note), so a plain Godot exe would **boot fully
    (window and all)** on each hook, then exit only when a script handles the arg. That means
    **window flashes during install and update** **[U, likely]**.
  - Fix: a small **GDExtension** that links `velopack_libc` and calls `vpkc_app_run()` at
    `MODULE_INITIALIZATION_LEVEL_CORE`. That runs before the display server starts (the same trick
    godot-patch-loader uses) **[U: confirm that DisplayServer init comes after CORE-level extension
    init on all three OSes]**. The same GDExtension exposes check, download and apply to GDScript.
  - `vpk pack --skipVeloAppCheck` is needed because the SDK marker would sit in the GDExtension
    library, not the main exe **[U]**.
- **Size overhead** (measured from the `vpk` 1.2.161 nupkg vendor folder) **[V]**:

  | Component | Size |
  |---|---|
  | `update_x64.exe` | 5.2 MB |
  | `setup_x64.exe` template | 7.5 MB |
  | stub exe | 0.47 MB |
  | `UpdateMac` | 7.7 MB |
  | `UpdateNix_x64` | 10.4 MB |
  | `UpdateNix_arm64` | 10.7 MB |
  | AppImage runtime | ~0.94 MB |

  Next to a Godot export (~70–100 MB engine and PCK) this is 5–15 %.
- **Known issues:**
  - AV false positives on the portable-zip root stub. The maintainer's advice is to sign
    ([#703](https://github.com/velopack/velopack/issues/703)); a `--noStub` option is tracked in #1060.
  - The stub exe is never updated; only `Update.exe` is.
  - AppImage FUSE2 (fixed, see above).
  - Settings or data stored in `current\` are wiped on update. Store packs and saves elsewhere; see §5.4.
- **Hosted option:** "Velopack Flow" (paid, with tiered rollout) exists; we don't need it. **[V]**

### 1.6 Signing inside vpk
- **Windows:** `--signParams "<signtool args>"`, `--signTemplate "tool … {{file}}"`, or
  `--azureTrustedSignFile metadata.json`. `vpk` bundles signtool and the Azure Code Signing dlib,
  which need the .NET 8 runtime. Authentication uses `DefaultAzureCredential` (az CLI or GitHub
  OIDC). vpk signs Setup, Update and the app binaries itself; they must be signed at specific
  points, so **don't pre-sign externally and then pack**.
- **Cross-platform alternative:** **JSign** with `--storetype TRUSTEDSIGNING` plus an access token
  from `az account get-access-token --resource https://codesigning.azure.net`. This allows Windows
  packing and signing from a Linux runner. **[V]** ([signing docs](https://docs.velopack.io/packaging/signing))
- **macOS:** `--signAppIdentity "Developer ID Application: Name"`,
  `--signInstallIdentity "Developer ID Installer: Name"`, `--notaryProfile <notarytool profile>`,
  `--keychain`, `--signEntitlements`, `--signDisableDeep`. The default entitlements are tuned for
  .NET apps, so **pass Godot's own entitlements file**. **[V]**
- Velopack's docs say Artifact Signing gives "instant reputation". **This contradicts Microsoft's
  current docs (see §3.2); Microsoft wins.**

---

## 2. macOS

### 2.1 Sparkle 2
- **Current version: 2.9.6 (2026-08-17)**, with security hardening. 2.9.0 (2026-02-22) added:
  - **signed appcast feeds** (`SURequireSignedFeed`)
  - markdown release notes
  - `sparkle:hardwareRequirements` (arm64-only)
  - `sparkle:minimumUpdateVersion`
  - removal of `sparkle-cli` from the binary distribution (still buildable from source)
  - CocoaPods deprecated

  2.9.2–2.9.6 fixed several symlink and privilege security bugs. **[V]**
  ([releases](https://github.com/sparkle-project/Sparkle/releases))
- **Security:**
  - Archives are signed with EdDSA (ed25519): `generate_keys` stores the key in the Keychain, and
    the app carries `SUPublicEDKey`.
  - `generate_appcast` signs everything and **generates deltas automatically** from the previous
    archives in the folder.
  - `SUVerifyUpdateBeforeExtraction` and `SURequireSignedFeed` give stronger validation. **[V]**
    ([docs](https://sparkle-project.org/documentation/),
    [customization](https://sparkle-project.org/documentation/customization/))
- **Deltas:** `BinaryDelta` format 4 (Sparkle 2.7+), bsdiff-based per-file patches with a fallback
  to the full update. Deltas reject code-signing xattrs outside Mach-O files, so keep the `.pck` in
  `Contents/Resources`, which Godot already does. **[V]**
  ([delta updates](https://sparkle-project.org/documentation/delta-updates/))
- **Silent updates:** `SUEnableAutomaticChecks`, `SUAutomaticallyUpdate` (download and install in
  the background, applied on quit), `SUAllowsAutomaticUpdates`, and `SUScheduledCheckInterval`
  (default 1 day, minimum 1 h). A custom `SPUUserDriver` cannot hide the UI; silent installs only
  come through `SUAutomaticallyUpdate`. **[V]**
- **Godot integration (no official path):**
  1. **GDExtension** (Obj-C++ with godot-cpp). Link `Sparkle.framework`, list it as a framework
     dependency in the `.gdextension` so it is copied to `Contents/Frameworks`, and create
     `SPUStandardUpdaterController(startingUpdater: true …)` on the main thread. Expose
     `check_for_updates()` and `automatically_downloads_updates` to GDScript.
     **[V: API]** ([programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/));
     **[U: GDExtension framework-dependency copy]**.
  2. **No native code:** use [gilzoide/objectivec-gdextension](https://github.com/gilzoide/objectivec-gdextension)
     to message Sparkle classes from GDScript at runtime (experimental).
  3. **Helper:** build `sparkle-cli` from source, embed it in `Contents/Helpers`, and run
     `sparkle --check-immediately --defer-install <app>` through `OS.create_process`.
     **[V: CLI documented]** ([sparkle-cli](https://sparkle-project.org/documentation/sparkle-cli/))

  In every case Info.plist needs `SUFeedURL` and `SUPublicEDKey`. Add them through Godot's macOS
  export (additional plist content) or a post-export plist edit, then sign and notarize. A
  Sparkle.framework signed with our Team ID passes **library validation**, so
  `disable-library-validation` is not needed for it.
- **Sparkle vs Velopack on macOS**

  | Sparkle strengths | Velopack strengths |
  |---|---|
  | Native macOS UX | One tool, feed format and CI step for all OSes |
  | EdDSA-signed packages and (now) signed feeds | Per-user updates without prompts in ~/Applications |
  | Years of hardening | zstd deltas |
  | DMG-friendly (installs from a zip/DMG appcast enclosure) | Also signs and notarizes |

  Sparkle's cost is Obj-C glue in Godot and a second pipeline (appcast XML plus an EdDSA key to
  protect). Velopack's gaps: no DMG output, a less "Mac-native" feel, and unsigned feeds.

### 2.2 Signing, notarization and entitlements for Godot
- Godot 4.7 can sign and notarize during export: Xcode `codesign` and `notarytool` on macOS, or
  **rcodesign on Linux/Windows**. It supports **App Store Connect API key** notarization (the
  `GODOT_MACOS_NOTARIZATION_API_UUID/_API_KEY/_API_KEY_ID` env vars). You must **turn off the
  Debugging entitlement** to notarize. **[V]**
  ([exporting for macOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html))
- **Hardened-runtime entitlements for a GDScript-only game: none of the risky ones are needed.**
  - `allow-jit`, `allow-unsigned-executable-memory` and `allow-dyld-environment-variables` are
    forced on only for **Mono/.NET** exports.
  - `disable-library-validation` is needed only for **GDExtensions not signed by our team**,
    ad-hoc signing, or user-provided add-ons.
  - Sign our own GDExtension (Velopack or Sparkle glue) with the same Developer ID and leave
    library validation on.
  - Loading `.pck` data from outside the bundle is **not code** for Gatekeeper purposes, so
    user-dir packs don't affect the signature. **[V]** (same Godot page)
- **notarytool with an API key:** `xcrun notarytool store-credentials <profile> --key AuthKey_XXX.p8
  --key-id <id> --issuer <uuid>`, then `notarytool submit <zip|dmg|pkg> --keychain-profile <profile>
  --wait`, then `xcrun stapler staple`. The notary service accepts zip, UDIF DMG and signed flat
  pkg; `altool` has been dead since 2023-11-01. **[V]**
  ([Apple: customizing notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow))
  - Velopack's `--notaryProfile` just references such a profile, so API-key profiles work **[V]**.
- **DMG:** Godot can export a DMG directly, but only from macOS **[V]**. Alternatives:
  - [`create-dmg`](https://github.com/create-dmg/create-dmg) (shell) or
    [`dmgbuild`](https://github.com/dmgbuild/dmgbuild) (Python, headless and scriptable) for a
    styled DMG. **[U: current versions not rechecked]**
  - Sign the DMG itself, notarize it, and staple the **DMG**.
  - With Velopack, build the DMG from the Velopack portable `.zip` contents. The `.app` inside
    stays Velopack-updatable.
- **Homebrew cask:** Homebrew 5.0.0 deprecated casks without codesigning, **disabled all casks
  failing Gatekeeper checks in September 2026**, and deprecated `--no-quarantine`. A notarized
  Diceroll could be a cask (for example with `auto_updates true`), but it is a minor channel.
  **[V]** ([Homebrew 5.0.0](https://brew.sh/2025/11/12/homebrew-5.0.0))

---

## 3. Windows

### 3.1 Azure Artifact Signing (formerly "Trusted Signing")
- **Name:** "Artifact Signing" / "Azure Artifact Signing". Same `Microsoft.CodeSigning` resource
  provider; the CLI extension is now `az extension add --name artifact-signing`. **[V]**
  ([quickstart, updated 2026-05](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart))
- **Eligibility for Public Trust:** organizations in the **USA, Canada, EU and UK**; **individual
  developers in the USA and Canada only**.
  - Individual identity details come from the Azure **billing account, which must be of type
    Individual**.
  - Identity is checked with government ID and a face check (AU10TIX or a Microsoft Verified ID).
  - A **paid subscription is required** (no free, trial or sponsored subscriptions).
  - The certificate CN is your validated legal name; custom CN or O is not allowed. **[V]**
    ([quickstart](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart),
    [FAQ](https://learn.microsoft.com/en-us/azure/trusted-signing/faq))
- **Price:** **Basic $9.99/month with 5,000 signatures; Premium $99.99/month with 100,000; overage
  $0.005 per signature.** **[V]** (Azure Retail Prices API, SKU "Trusted Signing")
- **Certificates live 72 hours and renew daily.** Always timestamp (`http://timestamp.acs.microsoft.com`).
  Reputation attaches to the durable identity (a profile EKU), not to a single certificate. **[V]**
  ([certificate management](https://learn.microsoft.com/en-us/azure/artifact-signing/concept-certificate-management))
- **GitHub Actions:** `azure/login@v3` with OIDC (`permissions: id-token: write`, federated
  credential, role "Artifact Signing Certificate Profile Signer"), then either:
  - `azure/artifact-signing-action@v2` (renamed from `trusted-signing-action`; the
    `trusted-signing-account-name` input is deprecated in favor of `signing-account-name`;
    Windows runner), or
  - vpk's `--azureTrustedSignFile`, or JSign on Linux. **[V]**
    ([action](https://github.com/Azure/trusted-signing-action),
    [OIDC doc](https://github.com/Azure/trusted-signing-action/blob/main/docs/OIDC.md))

### 3.2 SmartScreen and Smart App Control in 2026
- Microsoft's own table:

  | Option | Status |
  |---|---|
  | Artifact Signing | "Reputation builds over time; initial warnings expected" |
  | OV | "Same as Azure Artifact Signing" |
  | **EV** | "**Same as OV since 2024 — no longer instant bypass**" |

  Reputation combines publisher reputation and file-hash reputation. It builds organically over
  "several weeks and hundreds of clean installs"; there is no submission mechanism for consumers.
  With a **consistent signing identity**, later releases can inherit trust. **[V]**
  ([code signing options](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options),
  [SmartScreen reputation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation))
- **Smart App Control (Windows 11)** can override SmartScreen and **blocks unsigned executables**
  without positive reputation, for *all* executables, not just downloaded ones. The current
  unsigned zip is at risk on SAC-enabled PCs. **[V]** (same page)
- **CA/B Forum ballot CSC-31:** publicly trusted code-signing certificates issued on or after
  **2026-03-01 last at most 460 days**. This affects OV and EV purchases, not Artifact Signing.
  **[V-2nd]** ([GlobalSign](https://www.globalsign.com/en/blog/code-signing-validity-changes),
  [DigiCert KB](https://knowledge.digicert.com/alerts/code-signing-certificates-459-day-validity))
- Since June 2023, OV and EV keys must be on an HSM or token. Cloud HSMs work in CI. **[V]** (MS page above)

### 3.3 Alternatives if Artifact Signing is unavailable (for example, an individual outside US/CA)
- **SignPath Foundation (free for OSS):** requires an **OSI license for all components, with no
  proprietary components** and no commercial dual-licensing. The certificate names **SignPath
  Foundation** as publisher. You need a code-signing-policy page and MFA. Diceroll's **purchased,
  non-free art** most likely makes it **ineligible**. **[V: terms]; [U: how they treat non-code assets]**
  ([terms](https://signpath.org/terms))
- **Certum Open Source Code Signing:** "Open Source Developer" certificate. Cloud (SimplySign)
  **from €49**, card set €69, code-only €25 (one year). It supports SmartScreen reputation building.
  CI is awkward: SimplySign needs a TOTP login through a desktop app. Community tools exist:
  [certum-container](https://github.com/hpvb/certum-container),
  [ssign](https://github.com/Le-Syl21/ssign) (pure HTTPS, PE only, created 2026-07), and ReactiveUI's
  Xvfb action. Eligibility for a game with proprietary art is **[U]**.
  **[V: prices]** ([Certum shop](https://shop.certum.eu/code-signing.html))
- **Commercial OV** with a cloud HSM (SSL.com eSigner, DigiCert KeyLocker, Sectigo, GlobalSign):
  $150–300/year according to Microsoft. SmartScreen behaves the same as Artifact Signing. **[V: MS range]**

### 3.4 Installer formats and channels
- **Velopack Setup.exe (recommended):** per-user, no UAC, deltas, one-click, signed by vpk.
  `--msi` is available if an enterprise-style install is ever needed. **[V]**
- **MSIX + App Installer (`.appinstaller`):**
  - Auto-update on launch or in the background (`HoursBetweenUpdateChecks`, `ShowPrompt`,
    `UpdateBlocksActivation`; 2021 schema; Windows 10 2004+ and all Windows 11).
  - **Block-level (64 KB) differential downloads** through `AppxBlockMap.xml` and HTTP range
    requests, which R2 supports.
  - But: the **`ms-appinstaller:` protocol has been disabled by default since December 2023**
    (users must download and double-click the `.appinstaller`).
  - Packaged-app virtualization of AppData.
  - A signing cert whose subject must match the manifest Publisher (Artifact Signing supports
    MSIX; custom CN is impossible).
  - 64 KB fixed blocks handle PCK byte shifts **worse** than zstd or bsdiff.
  - Verdict: workable, but more ceremony than Velopack for no gain. **[V]**
    ([App Installer overview](https://learn.microsoft.com/en-us/windows/msix/app-installer/app-installer-file-overview),
    [auto-update](https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview),
    [differential updates](https://learn.microsoft.com/en-us/windows/msix/app-package-updates))
- **Inno Setup:** a mature classic installer, but **no updater and no deltas**. You would pair it
  with your own updater (what Diceroll does today). Only worth it if Velopack is rejected. **[U: no 2026 recheck]**
- **winget (`microsoft/winget-pkgs`):**
  - Submit manifests by PR; they are validated automatically (malware scan, policy) and may be
    reviewed by hand.
  - The `InstallerUrl` must be the publisher's own release location.
  - Policy 1.2.1 forbids "dynamic inclusion of code" beyond the described functionality, so
    describe the content downloads in the listing.
  - Useful as a **discovery and install** channel (`winget install Diceroll`). `winget upgrade` is
    of little value for a self-updating game. Automate with `wingetcreate`/Komac later.
    **[V: policies]** ([submit](https://learn.microsoft.com/en-us/windows/package-manager/package/repository),
    [policies](https://learn.microsoft.com/en-us/windows/package-manager/package/windows-package-manager-policies));
    **[U: ARP version detection of Velopack installs]**.

---

## 4. Linux (desktop and Steam Deck)

### 4.1 Flathub
- **Licensing:**
  - "All content hosted on Flathub must allow legal redistribution." **Non-redistributable sources
    must use `extra-data`**, but **when upstream submits, redistribution permission is implicit**,
    so extra-data is normally unnecessary.
  - The license must be declared correctly in MetaInfo, for example
    `MIT AND CC0-1.0 AND LicenseRef-proprietary`.
  - Confirm that the licenses of the purchased asset packs allow distributing them inside a game
    build. Most asset-store EULAs do, but check each one. **[V: policy]; [U: specific asset EULAs]**
    ([requirements](https://docs.flathub.org/docs/for-app-authors/requirements))
- **The "build from source" rule:** "All source available submissions must be built entirely from
  source code", with case-by-case exceptions.
  - Godot games on Flathub normally ship a **prebuilt PCK on `org.godotengine.godot.BaseApp`**
    (one branch per Godot minor, built from source). Examples: Ball2Box, ROTA, Material Maker,
    Pixelorama. **[V-2nd]** ([Simon Dalvai](https://simondalvai.org/blog/godot-flathub-publish/),
    [Cassidy James](https://cassidyjames.com/blog/publish-godot-engine-game-flathub-flatpak/),
    [BaseApp](https://github.com/flathub/org.godotengine.godot.BaseApp))
  - Because the purchased art cannot be public, a from-source build is impossible. Expect to argue
    for a prebuilt PCK (reviewer discretion). **[U]**
  - The BaseApp was **rebuilt with `disable_path_overrides=no`** so `--main-pack` works inside
    Flatpaks again. **[V]** ([commit](https://github.com/flathub/org.godotengine.godot.BaseApp/commit/5c5ce34cd7c3c55923d7b09d4c91bf6f5cbcf116))
  - Check that a **4.7 branch** exists before committing. **[U]**
- **Other policies to note:**
  - Domain or repo verification: token at `/.well-known/org.flathub.VerifiedApps.txt`.
  - Builds for **x86_64 and aarch64** by default (use `flathub.json` to restrict).
  - **A Generative-AI disclosure policy**: AI-generated code, docs or packaging must be disclosed,
    and **AI agents must not open or automate the Flathub submission PR** or write its descriptions
    or replies. This matters for this repo's workflow.
  - Only stable releases; no daily updates.
  - The monetization policy applies only to paid unlocks. **[V]**
- **How updates work:** a PR to the Flathub app repo triggers a buildbot build that publishes in
  about 1–2 hours. Users update through GNOME Software, Discover or `flatpak update`; Flathub does
  not dictate client update policy. **[V]** ([updates](https://docs.flathub.org/docs/for-app-authors/updates),
  [maintenance](https://docs.flathub.org/docs/for-app-authors/maintenance))
- **Self-updater inside Flatpak:**
  - No written Flathub rule was found, but the norm is to **disable in-app binary updaters in the
    Flatpak build**, as Chatterino did. `/app` is read-only anyway.
    **[V-2nd]** ([Chatterino PR](https://github.com/Chatterino/chatterino2/pull/3051)); **[U: formal policy]**
  - Detect Flatpak with `FLATPAK_ID` or `/.flatpak-info` and set `distribution: flathub`.
  - **Code-pack swaps** from our CDN would bypass Flathub's review. Turn them off.
- **Data packs inside Flatpak:**
  - Flatpak **always sets `XDG_DATA_HOME=~/.var/app/<id>/data`** (plus config and cache
    equivalents), so Godot's `user://` lands there and is writable. **[V]**
    ([Flatpak conventions](https://docs.flatpak.org/en/latest/conventions.html))
  - Network access requires `--share=network`, which is normal for games.
  - Two options:
    - (a) Keep downloading **data-only** packs, version-pinned to the core, into `user://`.
      Acceptable in principle **[U: reviewer view]**.
    - (b) **Recommended for Flathub: bundle all packs as separate files under `/app/share/...`.**
      OSTree content addressing means updates only move changed files **[U: expect Flathub static
      deltas; not re-verified]**. The pack loader then mounts from `/app` instead of `user://`, and
      the pack downloader turns off in Flatpak.
- **Steam Deck:**
  - SteamOS has a read-only root. **Flatpak via Discover (Flathub) is the supported way to install
    desktop apps.** Updates run manually in Discover in desktop mode.
  - AppImages also work.
  - Users add games to Gaming Mode as "non-Steam games". **[V-2nd]**
    ([GamingOnLinux guide](https://www.gamingonlinux.com/guides/view/how-to-install-extra-software-apps-and-games-on-steamos-and-steam-deck/))
  - So **Flathub is the best Deck channel**, and a self-updating AppImage is second (it updates
    even from Gaming Mode, because it is our own updater).

### 4.2 AppImage, AppImageUpdate and zsync
- **type2-runtime** is now static (musl), so **libfuse2 is not needed** (it still uses FUSE or
  fusermount; `APPIMAGE_EXTRACT_AND_RUN` is the fallback). **[V]**
  ([type2-runtime](https://github.com/AppImage/type2-runtime))
- `appimagetool -u "zsync|https://…/Diceroll-x86_64.AppImage.zsync"` embeds update info and
  produces `.zsync`. `-s` signs with GPG. `AppImageUpdate`/`appimageupdatetool`/`libappimageupdate`
  then do **zsync block deltas** from any static host (R2 works; zsync needs HTTP range requests).
  **[V]** ([appimagetool](https://github.com/AppImage/appimagetool),
  [AppImageUpdate](https://github.com/AppImageCommunity/AppImageUpdate))
- If we use Velopack's AppImage, **Velopack's own updater replaces zsync**. There is no need for
  both; Velopack declined zsync in #351. **[V-2nd]**
- **Snap Store:** auto-updating and strictly confined, but **snapd is not on SteamOS** and adds a
  fourth pipeline. Skip. **[U: not re-researched]**
- **Plain tar.gz:** keep it as the "no updater" fallback (and for itch and Steam). It needs no
  signing infrastructure beyond checksums.

### 4.3 Signing Linux artifacts and aarch64
- AppImage: `appimagetool --sign` (embedded GPG signature, which AppImageUpdate's `validate` checks). **[V]**
- tar.gz and AppImage: publish `SHA256SUMS` plus a detached signature (GPG or **minisign**, which
  is simpler) and **GitHub artifact attestations** (`actions/attest-build-provenance`, verified with
  `gh attestation verify`). Public repos use the Sigstore public-good log; private repos use
  GitHub's instance. **[V]** ([attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations));
  **[U: plan limits for private repos]**
- **aarch64:** Velopack ships `UpdateNix_arm64` and an arm64 AppImage runtime **[V]**. Flathub builds
  aarch64 by default **[V]**. Godot has linux arm64 templates (already exported by `release.yml`).
  Whether `vpk [linux] pack --runtime linux-arm64` works from an x64 runner is **[U]**; otherwise
  use an `ubuntu-24.04-arm` runner ($0.005/min).

---

## 5. Architecture recommendation

### 5.1 First: the `--main-pack` problem
- Godot PR #111909 (merged 2025-11-12, shipped in **4.6**) added the SCons flag
  `disable_path_overrides`, **on by default for export templates**. It disables `--path`, `--scene`,
  `--upwards`, `-s/--script`, `--main-loop` and **`--main-pack`** (except on Web; Android was
  restored for in-APK paths in 4.6.x by PR #119495). It also forces PCK loading from the
  executable or resource directory. **[V]**
  ([PR #111909](https://github.com/godotengine/godot/pull/111909),
  [PR #119495](https://github.com/godotengine/godot/pull/119495))
- The 4.7 docs mark `--main-pack` as "Only available in editor builds, and export templates
  compiled with `disable_path_overrides=false`". The binary **aborts** with "`--main-pack` was
  specified on the command line, but this Godot binary was compiled without support for path
  overrides." **[V]**
- Diceroll pins `GODOT_VERSION: "4.7.2"` with official templates, and `updater.gd` relaunches with
  `--main-pack`. **→ The desktop code-update path is very likely broken now.**
  Test: `./Diceroll.x86_64 --main-pack /tmp/x.pck` on a 4.7.2 export.
- **Options:**

  | Option | How | Assessment |
  |---|---|---|
  | (a) Custom templates | Build with `disable_path_overrides=no` (the Flathub BaseApp does this) | Costs CI time (templates for 3 OSes, cacheable), re-opens the injection hole the Godot team closed, and needs macOS universal-template builds |
  | (b) Early pack loading | `ProjectSettings.load_resource_pack(user_code_pack, true)` in the **first autoload's `_init()`** (the documented pattern) | Caveats: `project.godot` settings, the autoload list and the global class cache still come from the base pack, and the loader script itself can't be patched **[V: docs pattern]** ([exporting PCKs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html)); **[U: class_name cache behavior in 4.7]** |
  | (c) GDExtension at CORE level | Load packs before any script, like [godot-patch-loader](https://github.com/Ryan-000/godot-patch-loader) (Godot 4.4+, loads `patches/patch_N.pck` beside the exe; we would fork it to read from `user://` because the exe dir is inside signed bundles) | Viable if we need code-only updates |
  | **(d) Recommended** | **Stop swapping code packs on desktop direct builds.** Ship code with the binary through Velopack, whose per-file deltas make a code-only release roughly as small as the changed PCK bytes | Keep (b) or (c) only for platforms without Velopack, if ever |

### 5.2 Options compared

| | **A. Velopack everywhere + GDScript data packs** (recommended) | **B. Sparkle (mac) + Velopack (win) + AppImageUpdate/Flatpak (linux)** | **C. Keep GDScript code-pack swap + Velopack only for engine bumps** |
|---|---|---|---|
| Update systems to maintain | 1 binary updater + data-pack updater | 3 binary updaters + data-pack updater | 2 (and the code-swap path is broken on 4.6+ without custom templates) |
| Native code needed | 1 small GDExtension (velopack_libc, 4 builds) | GDExtension (Obj-C Sparkle) + Velopack glue + libappimageupdate or none | Same as A, plus custom templates or a CORE-level loader |
| Deltas | zstd per file, all OSes | bsdiff (mac), zstd (win), zsync blocks (linux) | Code: full ~pack download or Godot 4.6 delta patches; engine: zstd |
| Update integrity | SHA hashes from an **unsigned** feed; add our own RSA signature of the feed | Sparkle EdDSA + signed feed (best); others as A | Our RSA manifest (good) + A for engine |
| Rollback | Re-publish the old version as a higher version, or downgrade-channel tricks. No automatic boot-failure rollback | Same | Existing 2-failed-boots rollback (nice) |
| UX | Consistent. Windows install without UAC; restart in about 2 s | Best native feel on macOS | Two kinds of updates (confusing) |
| Signing | vpk signs everything (Artifact Signing, Developer ID + notarization) | Separate steps per tool | Code packs are data (no OS signing), but a swapped code pack is effectively unsigned code, so rely on our RSA signature |
| CI time | +2–5 min per OS | +more (appcast, EdDSA, zsync) | Similar to A + template builds |
| One developer? | **Best fit** | Overkill | Complexity without benefit once Velopack deltas exist |

**Recommendation:** Option A.
- Keep our GDScript updater strictly for **data-only content packs**: per-pack manifests, R2,
  per-pack deltas, RSA-signed manifest.
- Velopack owns engine plus code, with channels `{os}-{arch}-{stable|beta}`.
- If the dev menu's stable/beta switch should keep working, map it to Velopack channel switching
  (`UpdateOptions.ExplicitChannel` or its C equivalent).
- Revisit Sparkle only if macOS users complain about the update UX, or if signed feeds become a
  requirement. Porting later is cheap because the macOS `.app` stays a normal notarized bundle.

### 5.3 Per-distribution matrix (direct only)

| Build | Installer | Binary + code updates | Data packs |
|---|---|---|---|
| Windows (website / GitHub) | Velopack `Setup.exe` (signed), optional portable zip | Velopack (R2 feed) | GDScript updater → `user://` |
| macOS (website / GitHub) | DMG made from the Velopack portable zip (plus Velopack `.pkg`), notarized and stapled | Velopack (or Sparkle later) | GDScript updater → `user://` |
| Linux (website / GitHub) | Velopack `.AppImage` (x64, arm64) + tar.gz fallback | Velopack AppImage; the tar.gz gets "new version" notifications only | GDScript updater → `user://` |
| Flathub (also the Steam Deck default) | Flathub | Flathub only; our binary/code updater **off** | Bundled in `/app` (preferred) or data-only downloads |
| itch / Steam / stores | (their tooling) | Platform; Velopack not installed → `NotInstalled`, so skip | Platform or bundled |

### 5.4 Where packs live, and how that interacts with each updater
- **Never inside the signed or replaced bundle.** Velopack replaces `current\` (Windows) and the
  whole `.app` or `.AppImage` (macOS, Linux). Sparkle replaces the `.app`. On macOS, writing into
  `.app/Contents` would also break the code-signature seal. **[V]**
  ([preserved files](https://docs.velopack.io/integrating/preserved-files))
- **Suggested locations:**
  - **Saves and settings** in Godot `user://` (Windows `%APPDATA%`, macOS
    `~/Library/Application Support`, Linux `~/.local/share` or `~/.var/app/<id>/data`). These
    survive updates and uninstall.
  - **Content packs** are re-downloadable caches, so use `OS.get_cache_dir()` or `user://packs`.
  - On Windows you could put packs in `%LocalAppData%\{packId}\packs`, one level above `current\`.
    They survive updates and are **removed on uninstall** (Velopack deletes `{packId}`), but a
    **reinstall also wipes them** (acceptable for a cache). **[V: Velopack semantics]**
- **Compatibility:** each pack declares `min_core`/`max_core`, and the core refuses to mount packs
  built for another engine or core schema. Order the release so the **binary update ships before
  packs that need it**, or so the pack manifest pins per core version.
- **Gatekeeper and SmartScreen** never look at `.pck` files; they are not PE or Mach-O. Integrity of
  data packs therefore relies entirely on our signed manifest and SHA-256 hashes (already in place).

---

## 6. CI recipes (GitHub Actions)

Assumptions:
- Updates are served from an R2 bucket behind a custom domain `https://updates.<domain>/`, using
  prefixes `win/`, `osx/` and `linux/`.
- The existing `release.yml` export jobs produce `build/windows/`, `build/Diceroll.app` and
  `build/linux-*`.
- The versions pinned below are today's. Pin actions by SHA per this repo's conventions.

### 6.1 Windows (Artifact Signing via OIDC, vpk on a Windows runner)
```yaml
permissions: { contents: write, id-token: write }
jobs:
  windows-velopack:
    runs-on: windows-2025
    environment: release            # holds AZURE_* + R2 secrets; add required reviewers if wanted
    env: { VPK_VERSION: "1.2.161", CHANNEL: win-x64-stable }
    steps:
      - uses: actions/download-artifact@v7      # Godot export: build/windows/{Diceroll.exe,Diceroll.pck,…}
        with: { name: dist-windows-raw, path: build/windows }
      - uses: actions/setup-dotnet@v5
        with: { dotnet-version: "10.0.x" }       # vpk; signtool dlib also needs the .NET 8 runtime (preinstalled on windows images)
      - uses: azure/login@v3                      # OIDC federated credential, role "Artifact Signing Certificate Profile Signer"
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - shell: pwsh
        run: |
          @{ Endpoint='https://eus.codesigning.azure.net'; CodeSigningAccountName='diceroll'; CertificateProfileName='diceroll-public' } |
            ConvertTo-Json | Set-Content -Encoding utf8NoBOM "$env:RUNNER_TEMP\metadata.json"
          dotnet tool install -g vpk --version $env:VPK_VERSION
          vpk download http --url https://updates.example.com/win --channel $env:CHANNEL   # previous full pkg → deltas
          vpk pack -u Diceroll -v $env:VERSION -p build/windows -e Diceroll.exe `
            --packTitle Diceroll --packAuthors "Vlad Zaharia" --icon tools/icons/diceroll.ico `
            --channel $env:CHANNEL --skipVeloAppCheck --delta BestSize `
            --azureTrustedSignFile "$env:RUNNER_TEMP\metadata.json"
      - name: Upload to R2 (feed last)
        shell: bash
        env: { AWS_ACCESS_KEY_ID: "${{ secrets.R2_KEY_ID }}", AWS_SECRET_ACCESS_KEY: "${{ secrets.R2_SECRET }}", AWS_DEFAULT_REGION: auto }
        run: |
          EP=https://${{ secrets.R2_ACCOUNT_ID }}.r2.cloudflarestorage.com
          aws s3 cp Releases/ s3://diceroll-updates/win/ --recursive --exclude "releases.*.json" --exclude "assets.*.json" --endpoint-url $EP
          aws s3 cp Releases/releases.$CHANNEL.json s3://diceroll-updates/win/ --cache-control no-cache --endpoint-url $EP
          # (alternative, untested on R2: vpk upload s3 --endpoint $EP --bucket diceroll-updates --prefix win --channel $CHANNEL --keepMaxReleases 10)
```
- **Linux-runner variant:**
  1. `azure/login`
  2. `TOKEN=$(az account get-access-token --resource https://codesigning.azure.net --query accessToken -o tsv)`
  3. `vpk [win] pack … --signTemplate "jsign --storetype TRUSTEDSIGNING --keystore eus.codesigning.azure.net --storepass $TOKEN --alias diceroll/diceroll-public --tsaurl http://timestamp.acs.microsoft.com --tsmode RFC3161 {{file}}"`

  **[V: documented by Velopack; U: untested]**
- Standalone signing of non-Velopack artifacts (the itch/Steam zip exe) uses
  `azure/artifact-signing-action@v2` with `endpoint`, `signing-account-name`,
  `certificate-profile-name`, `files-folder`, `files-folder-filter: exe,dll`, `file-digest: SHA256`,
  `timestamp-rfc3161: http://timestamp.acs.microsoft.com` and `timestamp-digest: SHA256`. **[V]**

### 6.2 macOS (Developer ID + notarytool API key + vpk)
```yaml
  macos-velopack:
    runs-on: macos-26
    env: { CHANNEL: osx-universal-stable }
    steps:
      - uses: actions/download-artifact@v7   # build/Diceroll.app (Godot export, universal; may be pre-signed)
      - name: Keychain + certs + notary profile
        env: { P12: "${{ secrets.MACOS_CERTS_P12_BASE64 }}", P12_PW: "${{ secrets.MACOS_CERTS_P12_PASSWORD }}" }
        run: |
          KC=$RUNNER_TEMP/build.keychain-db; security create-keychain -p x "$KC"; security set-keychain-settings -lut 21600 "$KC"
          security unlock-keychain -p x "$KC"; echo "$P12" | base64 -d > $RUNNER_TEMP/c.p12
          security import $RUNNER_TEMP/c.p12 -k "$KC" -P "$P12_PW" -T /usr/bin/codesign -T /usr/bin/productsign
          security set-key-partition-list -S apple-tool:,apple: -s -k x "$KC"; security list-keychains -d user -s "$KC" login.keychain
          echo "${{ secrets.ASC_API_KEY_P8 }}" > $RUNNER_TEMP/AuthKey.p8
          xcrun notarytool store-credentials diceroll-notary --key $RUNNER_TEMP/AuthKey.p8 \
            --key-id "${{ secrets.ASC_KEY_ID }}" --issuer "${{ secrets.ASC_ISSUER_ID }}" --keychain "$KC"
          echo "KC=$KC" >> $GITHUB_ENV
      - run: |
          dotnet tool install -g vpk --version 1.2.161
          vpk download http --url https://updates.example.com/osx --channel $CHANNEL
          vpk pack -u Diceroll -v $VERSION -p build/Diceroll.app --channel $CHANNEL --skipVeloAppCheck \
            --signAppIdentity "Developer ID Application: <Name>" --signInstallIdentity "Developer ID Installer: <Name>" \
            --signEntitlements tools/macos/diceroll.entitlements --notaryProfile diceroll-notary --keychain "$KC"
      - name: Optional DMG from the portable zip (notarize + staple the DMG)
        run: |
          ditto -x -k Releases/Diceroll-osx-Portable.zip dmgroot
          create-dmg --volname Diceroll --app-drop-link 480 170 Releases/Diceroll-$VERSION.dmg dmgroot/
          codesign -s "Developer ID Application: <Name>" --timestamp Releases/Diceroll-$VERSION.dmg
          xcrun notarytool submit Releases/Diceroll-$VERSION.dmg --keychain-profile diceroll-notary --keychain "$KC" --wait
          xcrun stapler staple Releases/Diceroll-$VERSION.dmg
      # then upload nupkg/delta first, releases.osx-universal-stable.json last (same as Windows)
```
- The portable zip file name is **[U]**; check the `Releases/` listing.
- `tools/macos/diceroll.entitlements` should contain only `com.apple.security.cs.*` entries that we
  actually need. For GDScript-only, that is none besides the hardened-runtime default; drop `debugger`.
- Alternative without a macOS runner: Godot's export with **rcodesign** on Linux for sign, notarize
  and staple **[V: Godot docs]**. But vpk's macOS packing needs macOS anyway.

### 6.3 Linux (AppImage via Velopack + checksums, signatures and attestations)
```yaml
  linux-velopack:
    runs-on: ubuntu-24.04
    permissions: { contents: write, id-token: write, attestations: write }
    strategy: { matrix: { arch: [x64, arm64] } }
    steps:
      - uses: actions/download-artifact@v7
      - uses: actions/setup-dotnet@v5
        with: { dotnet-version: "10.0.x" }
      - run: |
          dotnet tool install -g vpk --version 1.2.161
          CH=linux-${{ matrix.arch }}-stable
          vpk download http --url https://updates.example.com/linux --channel $CH
          vpk pack -u Diceroll -v $VERSION -p build/linux-${{ matrix.arch }} -e Diceroll.${{ matrix.arch == 'x64' && 'x86_64' || 'arm64' }} \
            --runtime linux-${{ matrix.arch }} --icon tools/icons/diceroll-256.png --categories Game --channel $CH --skipVeloAppCheck
          (cd Releases && sha256sum *.AppImage > SHA256SUMS && minisign -Sm SHA256SUMS -s <(echo "$MINISIGN_KEY"))
      - uses: actions/attest-build-provenance@v3
        with: { subject-path: "Releases/*.AppImage" }
      # upload to R2 (feed last) + attach AppImage/tar.gz to the GitHub Release
```
The arm64 cross-pack from an x64 runner is **[U]**. Use `runs-on: ubuntu-24.04-arm` if it fails.

### 6.4 Data packs (unchanged design)
Build with `PCKPacker` or `--export-pack` in CI, then produce per-pack deltas and a signed manifest
(existing RSA key), and upload with `aws s3 sync --endpoint-url https://<acct>.r2.cloudflarestorage.com`
or rclone. Upload the manifest last with `Cache-Control: no-cache`.

### 6.5 CI minutes and cost (estimates, [U])
- GitHub-hosted rates (private repos) **[V]**
  ([runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing)):

  | Runner | Per minute |
  |---|---|
  | Linux x64 2-core | $0.006 |
  | Linux arm64 | $0.005 |
  | Windows | $0.010 |
  | macOS | $0.062 |

  Standard runners are free for public repos.
- Per-release estimate:

  | Job | Estimate |
  |---|---|
  | Windows pack and sign | ~4–8 min (runner boot, vpk install, ~5–10 signatures at a few seconds each) |
  | macOS pack, sign and notarize (+DMG) | ~10–25 min (notarization usually a few minutes, sometimes up to an hour) |
  | Linux AppImage × 2 | ~3–6 min |

  That adds **~20–40 runner-minutes**. In a private repo this is roughly **$0.05 (Linux) +
  $0.08 (Windows) + $0.6–1.6 (macOS) ≈ $1–2 per release**.
- Artifact Signing uses about 10 signatures per release, well inside the 5,000/month Basic quota.
  Apple Developer Program costs $99/year.

---

## 7. Open questions / to verify next
1. **Run `Diceroll --main-pack x.pck` on a 4.7.2 official template now** to confirm the abort, then
   choose a fix from §5.1.
2. Prototype the Velopack GDExtension:
   - Does `vpkc_app_run()` at CORE init level beat window creation on Windows, macOS and Linux?
   - Does `--skipVeloAppCheck` behave as expected?
   - Do hooks run on macOS and Linux at all? (Docs imply they are Windows-centric.)
3. Measure real Velopack delta sizes for "code-only" and "engine bump" releases of Diceroll.
4. Confirm `vpk upload s3` against R2 (otherwise keep aws or rclone).
5. Developer location: if not a US or Canadian individual, Artifact Signing needs an
   EU/UK/US/CA organization, otherwise use Certum OSS or a commercial OV with a cloud HSM.
6. Flathub: Godot BaseApp 4.7 branch availability, reviewer stance on a prebuilt PCK with
   proprietary art, and the AI-disclosure implications for this repo's generated code.
7. Asset EULAs: redistribution inside game builds on Flathub, winget and Homebrew.

## Sources (primary unless noted)
- Velopack:
  - [docs](https://docs.velopack.io/)
  - [C/C++](https://docs.velopack.io/getting-started/cpp)
  - [C API](https://docs.velopack.io/reference/cpp/c-api)
  - [integrating](https://docs.velopack.io/integrating/overview)
  - [hooks](https://docs.velopack.io/integrating/hooks)
  - [deltas](https://docs.velopack.io/packaging/deltas)
  - [channels](https://docs.velopack.io/packaging/channels)
  - [signing](https://docs.velopack.io/packaging/signing)
  - [Windows](https://docs.velopack.io/packaging/operating-systems/windows)
  - [macOS](https://docs.velopack.io/packaging/operating-systems/macos)
  - [Linux](https://docs.velopack.io/packaging/operating-systems/linux)
  - [cross-compiling](https://docs.velopack.io/packaging/cross-compiling)
  - [deploy CLI](https://docs.velopack.io/distributing/deploy-cli)
  - [self-hosting](https://docs.velopack.io/distributing/self-hosting)
  - [GitHub Actions](https://docs.velopack.io/distributing/github-actions)
  - [Update.exe](https://docs.velopack.io/reference/cli/content/update-windows)
  - [vpk ref](https://docs.velopack.io/reference/cli/content/vpk-windows)
  - [preserved files](https://docs.velopack.io/integrating/preserved-files)
  - [repo](https://github.com/velopack/velopack)
  - [#875](https://github.com/velopack/velopack/issues/875), [PR #899](https://github.com/velopack/velopack/pull/899),
    [#703](https://github.com/velopack/velopack/issues/703), [PR #116](https://github.com/velopack/velopack/pull/116)
  - crates.io `velopack` API; NuGet `vpk` 1.2.161 package contents
- Game precedent:
  - [osu! csproj](https://raw.githubusercontent.com/ppy/osu/master/osu.Desktop/osu.Desktop.csproj)
  - [Chromonia workflow](https://github.com/juan-medina/chromonia/blob/b228aabe404af50dc95b1579f5edfa5203fe38c7/.github/workflows/release.yml)
- Godot:
  - [macOS export 4.7](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)
  - [CLI 4.7](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
  - [exporting PCKs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html)
  - [PR #111909](https://github.com/godotengine/godot/pull/111909), [PR #119495](https://github.com/godotengine/godot/pull/119495),
    [#119376](https://github.com/godotengine/godot/issues/119376)
  - [godot-patch-loader](https://github.com/Ryan-000/godot-patch-loader)
  - [objectivec-gdextension](https://github.com/gilzoide/objectivec-gdextension)
  - [Flathub BaseApp](https://github.com/flathub/org.godotengine.godot.BaseApp)
- Sparkle:
  - [releases](https://github.com/sparkle-project/Sparkle/releases)
  - [docs](https://sparkle-project.org/documentation/)
  - [programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/)
  - [delta updates](https://sparkle-project.org/documentation/delta-updates/)
  - [customization](https://sparkle-project.org/documentation/customization/)
  - [sparkle-cli](https://sparkle-project.org/documentation/sparkle-cli/)
- Apple: [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- Homebrew: [5.0.0 release notes](https://brew.sh/2025/11/12/homebrew-5.0.0)
- Microsoft:
  - [Artifact Signing quickstart](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart)
  - [overview](https://learn.microsoft.com/en-us/azure/artifact-signing/overview)
  - [FAQ](https://learn.microsoft.com/en-us/azure/trusted-signing/faq)
  - [cert management](https://learn.microsoft.com/en-us/azure/artifact-signing/concept-certificate-management)
  - [code signing options](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options)
  - [SmartScreen reputation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)
  - [App Installer](https://learn.microsoft.com/en-us/windows/msix/app-installer/app-installer-file-overview)
  - [auto-update](https://learn.microsoft.com/en-us/windows/msix/app-installer/auto-update-and-repair--overview)
  - [MSIX differential](https://learn.microsoft.com/en-us/windows/msix/app-package-updates)
  - [winget submit](https://learn.microsoft.com/en-us/windows/package-manager/package/repository)
  - [winget policies](https://learn.microsoft.com/en-us/windows/package-manager/package/windows-package-manager-policies)
  - [artifact-signing-action](https://github.com/Azure/trusted-signing-action)
  - Azure Retail Prices API
- Signing alternatives:
  - [SignPath Foundation terms](https://signpath.org/terms)
  - [Certum shop](https://shop.certum.eu/code-signing.html)
  - [ssign](https://github.com/Le-Syl21/ssign), [certum-container](https://github.com/hpvb/certum-container)
  - CSC-31: [GlobalSign](https://www.globalsign.com/en/blog/code-signing-validity-changes) (secondary)
- Linux:
  - [Flathub requirements](https://docs.flathub.org/docs/for-app-authors/requirements)
  - [Flathub updates](https://docs.flathub.org/docs/for-app-authors/updates)
  - [maintenance](https://docs.flathub.org/docs/for-app-authors/maintenance)
  - [Flatpak conventions](https://docs.flatpak.org/en/latest/conventions.html)
  - [type2-runtime](https://github.com/AppImage/type2-runtime)
  - [appimagetool](https://github.com/AppImage/appimagetool)
  - [AppImageUpdate](https://github.com/AppImageCommunity/AppImageUpdate)
  - [Chatterino Flatpak PR](https://github.com/Chatterino/chatterino2/pull/3051)
  - [GamingOnLinux Deck guide](https://www.gamingonlinux.com/guides/view/how-to-install-extra-software-apps-and-games-on-steamos-and-steam-deck/) (secondary)
  - [Simon Dalvai](https://simondalvai.org/blog/godot-flathub-publish/), [Cassidy James](https://cassidyjames.com/blog/publish-godot-engine-game-flathub-flatpak/) (secondary)
- GitHub / Cloudflare:
  - [runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing)
  - [artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations)
  - [R2 S3 API](https://developers.cloudflare.com/r2/api/s3/api/)
