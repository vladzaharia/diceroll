# Diceroll: release, update and signing, as built (audit 2026-09-29)

Scope: the implementation on `main` @ `4e78bb6` in `/home/user/diceroll` (Godot 4.7.2), plus what is
live on GitHub right now. Read-only audit; nothing in the repo was changed. References are
`path:line` at that commit.

Evidence beyond reading code:
- **Live GitHub state.** The `channels` rolling release and three prereleases exist:
  `v0.1.0-rc.1`, `-rc.2` and `-rc.3` (rc.3 published 2026-09-29T17:41Z). No final release exists
  yet, so `update-stable.json` and `altstore-source.json` return **404**. `update-beta.json` +
  `.sig` and `altstore-source-beta.json` exist.
- **Signature check.** The live `update-beta.json` signature verifies with `openssl dgst -sha256
  -verify` against the RSA-3072 key embedded in `game/update/update_keys.gd` ("Verified OK").
- **Unit tests.** The updater tests pass on a scratch copy (`git archive`), not in the repo:
  `tests/run_tests.gd --filter=test_update` gives **49 passed, 0 failed** on Godot 4.7.2.
- **Experiments with Godot 4.7.2 headless** (scratch projects):
  1. `HTTPRequest` **forwards a custom `Authorization` header across a cross-host redirect**
     (127.0.0.1:8765 → 302 → localhost:8766 received `Bearer SECRET`).
  2. `CryptoKey.load_from_string()` **fails on an Ed25519 public key** (mbedTLS error -15488,
     unknown PK algorithm).
  3. **ECDSA P-256 works:** the public key loads and `Crypto.verify(SHA256, DER sig)` returns true.
  4. `HashingContext` only has `HASH_MD5`, `HASH_SHA1` and `HASH_SHA256`. **There is no SHA-512.**

---

## 0. Most decision-relevant findings (TL;DR)

1. **The content-streaming proposal is 0% implemented, apart from two §8 items that were built
   with the release pipeline:** the unsigned sideload IPA and the AltStore/SideStore source.
   - None of these exist: `game/content/`, `packs.gd`, `needs.gd`, `ContentPacks`, `BootShell`,
     PCKPacker builder, base preset without `assets/**`, manifest schema 2, per-pack store,
     `load_resource_pack` call, content tests.
   - The forest dedupe (Phase 0 size win) is not done.
   - **The display-font bug is already fixed** (`ui/theme/ui_theme.gd:33-38`, commit `4bb9028`,
     PR #1). The design doc (§10.1 item 5, §12) is stale on this.
2. **Updates today are one full main-pack PCK**: `Diceroll-<v>-desktop.pck`, **85.3 MB at
   rc.3**. It is applied by relaunching the executable with `--main-pack` and replaces all code
   and content. That makes the manifest signing key effectively a **code-signing key** for every
   self-updating install.
3. **Old clients will reject a "schema 2" manifest.**
   - `update_manifest.gd:116-117` rejects anything with `schema != 1` ("unsupported schema").
   - The proposal's claim that schema 2 is additive ("old binaries ignore the new fields") is
     false as written.
   - Two ways out: keep `"schema": 1` and add fields (validate copies unknown keys through), or
     publish v2 at a new file name while still publishing v1 files.
4. **Distribution stamping doesn't match the documented channel behaviour:**
   - **Steam and itch get the GitHub-stamped desktop builds**, so they self-update from GitHub
     Releases and relaunch themselves with `--main-pack`
     (`release.yml:103-112,424-429,445-450`; the itch comment admits it).
   - **The sideload APK is stamped `play`** (`release.yml:185`).
   - **The sideload IPA is stamped `appstore`** (`release.yml:246`, one export for all IPAs).
   - Result: sideloaded mobile users get "update in the store" prompts. The App Store URL is a
     placeholder (`id0000000000`, `update_manifest.py:32`). The Play listing may not exist, and
     Play uploads default to `draft`.
   - `docs/RELEASE.md:42,107-108,129-131` describe behaviour the code doesn't have.
5. **Signing and verification details:**
   - RSA-3072 PKCS#1 v1.5 / SHA-256, detached base64 `.sig` over the exact JSON bytes.
   - Verified in GDScript via `CryptoKey.load_from_string(pem, true)` + `HashingContext(SHA256)` +
     `Crypto.verify()`.
   - An RSA-only DER pre-check (`_modulus_bits`) rejects non-RSA keys.
   - One hard-coded key, no key id, no key list, no expiry, no anti-freeze counter.
   - **Ed25519 can't be verified with Godot's built-in crypto** (mbedTLS has no EdDSA, and there
     is no SHA-512). A Polaris Key EdDSA-JWS design needs one of: a pure-GDScript Ed25519+SHA-512
     verifier, a GDExtension (Web export has `extensions_support=false`), a custom engine module,
     or a second ES256 signature (P-256 verifies fine in Godot).
6. **CI/secret exposure:**
   - `UPDATE_SIGNING_KEY` is a plain repository secret used in the tag-triggered release
     workflow, with **no GitHub Environment or approval gate**.
   - Anyone who can push a `v*` tag (the workflow file comes from the tagged commit) can obtain a
     valid signature, or the key itself.
   - Third-party actions are pinned by tag, not SHA.
7. **Updater bugs and weaknesses, worth fixing before building on it:**
   - A channel switch during an in-flight download stages the old channel's pack.
   - Turning Auto-update off silently reverts to the binary's built-in content.
   - The "build default" channel becomes the pack's channel after running a beta pack.
   - The 10 s boot-OK window means quick quits cause false rollbacks.
   - The parent process builds the whole title scene before quitting on every relaunch.
   - Engine gating is an exact patch-level string match (`4.7.2`).
   - `min_binary`/`min_supported` are always `0.1.0`: the workflow never passes them.
   - The bearer token leaks across redirects.
   - The download has no size cap and no resume.
8. **Web:** nothreads, no PWA, no hosting job. The zip is 86.3 MB and carries both texture
   families. Only itch (gated) or manual hosting is available.

---

## 1. The in-game updater (`game/update/*`)

### 1.1 Files and roles

| File | Lines | Role |
|---|---|---|
| `game/update/updater.gd` | 370 | Autoload `Updater`, **first** in `[autoload]` (`project.godot:16`). Class-less, so it works across `--main-pack` versions (`updater.gd:1-3`). Handles gating, boot relaunch, checks, channel switch, banner. |
| `game/update/update_client.gd` | 91 | Pipeline: fetch manifest + sig → verify → parse → decide → download pack to staged |
| `game/update/update_fetcher.gd` | 124 | HTTP(S) via `HTTPRequest`, or local paths (`file://`, `res://`, `user://`, absolute, `C:\`) for tests |
| `game/update/update_manifest.gd` | 164 | Schema-1 validation + RSA signature verification (pure static) |
| `game/update/update_keys.gd` | 21 | `PUBLIC_KEY_PEM` constant (`update_keys.gd:10`) |
| `game/update/update_policy.gd` | 270 | `build_info()`, platform key, base URL, channels, `decide()` |
| `game/update/update_store.gd` | 287 | `user://updates/{staged,current,previous}` + `state.cfg`; boot maintenance, rotation, rollback |
| `game/update/semver.gd` | 76 | SemVer 2.0 compare. Leading `v` allowed, build metadata ignored, missing parts count as 0 |
| `ui/widgets/update_banner.gd` | ~110 | Top-centre toast: Downloading…/RESTART/DOWNLOAD/UPDATE. Close is hidden when mandatory (`:80`) |
| `ui/modals/settings_panel.gd:153-176` | | "Auto-update" ON/OFF + CHECK. Visible only when `can_check()` |
| `ui/modals/dev_menu.gd`, `ui/widgets/dev_gesture.gd` | 437 / 114 | Hidden developer menu: channel picker, check now, reset, build info, diagnostics |

### 1.2 Manifest schema 1 (every field)

Producer: `tools/ci/update_manifest.py:80-93`. Consumer: `update_manifest.gd:115-154`, then
`update_policy.gd:209-262`. Doc comment: `update_manifest.gd:8-13`.

| Field | Type | Producer value | Client handling |
|---|---|---|---|
| `schema` | int | `1` | **Must equal 1** (`update_manifest.gd:17,116-117`). Anything else fails the whole check. |
| `channel` | string | `stable` or `beta`. A final release writes both files, with beta = the stable content (`update_manifest.py:77,97-100`) | Must equal the requested channel (`:121-122`), so channel substitution is blocked |
| `version` | semver | release version | Required and semver-valid (`:118-125`). Compared with the running version (`decide`) |
| `released` | string (ISO UTC) | `now()` at publish (`update_manifest.py:82`) | Normalised to a string (`:132-133`). **Never checked** (no expiry or freshness) |
| `notes` | string ≤500 | `store/android_whats_new.txt` (`update_manifest.py:79`) | Clamped to 500 chars (`:18,134`). Not shown in the banner |
| `notes_url` | string | `/releases/tag/v<ver>` (`:83`) | Fallback for the binary URL (`update_policy.gd:266-270`) |
| `engine` | semver | `--engine` default `4.7.2` (`update_manifest.py:71`); the workflow never overrides it | **Exact string equality** with `Engine.get_version_info()` "major.minor.patch" (`update_policy.gd:57-59,248`) |
| `min_binary` | semver | default `0.1.0` (`:72`); **never passed by the workflow** (`release.yml:287-288`) | Pack only if `binary_version >= min_binary` (`update_policy.gd:249`) |
| `min_supported` | semver or "" | default `0.1.0` (`:73`); never passed | If `binary_version < min_supported`: `mandatory=true`, action BINARY/STORE, no close button (`:214-215,258-259`) |
| `pack` | `{url, sha256, size}` or null | Absolute URL of `Diceroll-<v>-desktop.pck` on the version's release, sha256, size (`update_manifest.py:87-89`) | url required; sha256 = 64 hex (lower-cased); size > 0 (`:135-147`) |
| `binaries` | `{platform: {url, sha256, size}}` | `macos`, `windows.x86_64`, `linux.x86_64`, `linux.arm64` archives (`:35-40,90-93`) | Only `url` is used, opened in the browser (`update_policy.gd:266-270`). **The sha256 is never used.** |
| `stores` | `{ios, android}` | `ios: https://apps.apple.com/app/id0000000000` (**placeholder**); `android: …details?id=gg.vlad.diceroll` (`update_manifest.py:31-34`) | Opened for the STORE action (`update_policy.gd:229-237`) |

The live `update-beta.json` (rc.3) matches exactly: pack 85,253,008 bytes; binaries 104–137 MB;
min fields 0.1.0; engine 4.7.2.

### 1.3 Signature scheme and verification

- **Signing (CI).**
  - `update_manifest.py:51-59` runs `openssl dgst -sha256 -sign <PEM>` over the exact JSON bytes
    it writes (`json.dumps(..., indent=2) + "\n"`, `:100`).
  - The `.sig` is standard base64 + newline.
  - Key from the `UPDATE_SIGNING_KEY` env (`release.yml:281`).
  - **Without a key it silently publishes UNSIGNED manifests** (`:102-104`), which clients then
    reject.
- **Verification (GDScript).** `update_manifest.gd:23-48`:
  1. Strip whitespace, check base64 charset and length % 4, `Marshalls.base64_to_raw`, size ≥ 64
     (`:26-37`).
  2. `sig.size()*8 == _modulus_bits(pem)`. This is a hand-rolled DER walk of an RSA
     SubjectPublicKeyInfo (`:40,53-101`). **It is RSA-specific: any non-RSA key returns 0 and
     fails.** It exists to stop mbedTLS logging errors on malformed input.
  3. `CryptoKey.new().load_from_string(pem, true)` (public only) (`:42-44`).
  4. `HashingContext` SHA-256 over the bytes, then
     **`Crypto.new().verify(HashingContext.HASH_SHA256, digest, sig, key)`** (`:45-48`). That is
     mbedTLS `pk_verify` with PKCS#1 v1.5 padding.
- Signature verification happens **before** JSON parse (`update_client.gd:55-60`), which is good.
- The empty-key case fails closed (`update_keys.gd` comment; test
  `test_update_e2e.gd:82 test_placeholder_key_fails_closed`).
- **The pack itself isn't signed.** Its sha256 + size come from the signed manifest and are
  checked after download (`update_store.gd:159-174`).

### 1.4 Key embedding

- `update_keys.gd:10`: one `const PUBLIC_KEY_PEM` (RSA-3072 SPKI PEM). It differs from the test
  fixture key: the fixture is `tests/fixtures/update/test_signing.pub.pem`, RSA-2048, and its
  private key is committed for tests and allow-listed in `.gitleaks.toml` and
  `tools/ci/check_repo.sh:100,108`.
- The key constant lives in the **PCK**, not the executable.
  - When the game runs a downloaded pack, the checker is the pack's `Updater` + `update_keys.gd`.
  - So a pack update can rotate the key for github-desktop installs.
  - Binary-only installs (mobile store builds, anything after an engine bump) keep the key baked
    into their own PCK.
- **There is no key id, no list of trusted keys and no revocation.** Rotation is a hard cut:
  - old clients verify with the old key only;
  - a single `.sig` can't carry two signatures;
  - you'd publish old-key-signed manifests whose pack carries the new key, then switch.
- Maintainer copy: `~/.config/diceroll/update-signing.pem` (`docs/RELEASE.md:150`).

### 1.5 Fetch logic (`update_fetcher.gd`)

- **Manifest and sig.**
  - `fetch()` creates an `HTTPRequest` with `use_threads=true`, `timeout=30 s`,
    `max_redirects=10` ("GitHub release assets redirect to a CDN") and
    `body_size_limit = 1 MiB` (`:13-15,43-57,91-97`).
  - Two separate GETs: `<base>/update-<ch>.json`, then `+ ".sig"` (`update_client.gd:47-53`).
- **Pack.** `download()` (`:60-88`):
  - `HTTPRequest.download_file = staged/diceroll.pck.part`, `timeout = 0`.
  - A 0.25 s polling loop emits progress. A **stall watchdog** cancels after 30 s without new
    bytes.
  - **No `body_size_limit`**, so a hostile or broken server can fill the disk. Size is checked
    only afterwards.
  - **No resume or Range.** `HTTPRequest.download_file` rewrites the file, and
    `begin_staging()` deletes staged/ first (`update_store.gd:151-154`). A failed download
    deletes the `.part` (`update_client.gd:83-85`).
- **URL joining:** relative refs are joined to the base. Absolute URLs pass through
  (`update_fetcher.gd:37-40`), so the manifest can point packs at any host.
- **Base URL:** env `DICEROLL_UPDATE_BASE_URL` > project setting `diceroll/update/base_url`
  (`project.godot:22`) > `DEFAULT_BASE_URL` = `https://github.com/vladzaharia/diceroll/releases/download/channels`
  (`update_policy.gd:11-13,86-91`).
- **Token:**
  - Env `DICEROLL_UPDATE_TOKEN` becomes `Authorization: Bearer …` on **every** request
    (`updater.gd:187-189`).
  - **Tested: Godot 4.7.2 keeps that header across cross-host redirects**, so it would leak to
    `objects.githubusercontent.com` or any redirect target.
  - Env-only, so it is useless for end users. Private GitHub release assets also need the API
    asset URL + `Accept: application/octet-stream`, not the browser URL.
- **TLS:** default `HTTPRequest` TLS options (Godot's bundled or system CA bundle). There is no
  pinning.

### 1.6 Store layout (`update_store.gd:1-11`)

```
user://updates/
  staged/   diceroll.pck (+ .part while downloading) + meta.json   downloaded + verified, not active
  current/  diceroll.pck + meta.json                               pack the game relaunches into
  previous/ diceroll.pck + meta.json                               rollback target
  state.cfg [state] boot_attempts, active, skip_version, binary_version ; [check] last
```

- `meta.json` holds `{version, sha256, size, engine}` and is written locally from the signed
  manifest (`:172-173`).
- `user://` is Godot's default app_userdata path (no custom user dir in `project.godot`):
  - `~/Library/Application Support/Godot/app_userdata/Diceroll` on macOS;
  - `%APPDATA%\Godot\app_userdata\Diceroll` on Windows;
  - `~/.local/share/godot/app_userdata/Diceroll` on Linux.
- The `active` key is written (`:201,217,262`) but **never read**. The `binary_version` state is a
  fallback only (`updater.gd:157-158`).
- **No lock file.** Two instances started together both run `boot()` and the renames.

### 1.7 Boot and relaunch mechanics

**Parent launch** (not started with a pack), `updater.gd:73-87`:

1. `info = build_info()`, `running_pack = _started_with_pack()`. That flag is true if
   `--main-pack` is in the engine args or `--diceroll-pack=` is in the user args
   (`:162-168`).
2. If `can_apply_packs()` fails, stop. It requires all of: `_active()` (not headless, not
   editor, no `--scenario`/`--shot` user arg), `OS.has_feature("template")`,
   distribution `github`, a desktop platform key (`macos`/`windows.*`/`linux.*`) and
   **Auto-update ON** (`:118-120`).
3. `store.boot(engine, binary_version)` (`update_store.gd:228-263`):
   - discard slots whose `engine` differs from the running engine, or whose version is **not
     newer** than the binary;
   - roll back if `boot_attempts ≥ 2`;
   - verify staged (size + sha256 vs `meta.json`), then activate it
     (current → previous, staged → current);
   - **use current only if its size matches** `meta.json` (no hash at every boot).
4. If there's a current pack, `_relaunch()` (`:311-323`):
   - `note_launch()` (boot_attempts++);
   - `OS.create_process(OS.get_executable_path(), ["--main-pack", <abs pck>, <original engine args minus --main-pack>, "--", <original user args> + "--diceroll-pack=<ver>" + "--diceroll-binary-version=<ver>"])`
     (`:313-316,328-347`);
   - mute bus 0, `get_tree().quit()`.
   - If `create_process` fails (pid ≤ 0), mark the boot OK and run the built-in content.

**Child launch** (running the pack):

- `Updater` comes from the **pack**, so it is the new code. It returns early in `_enter_tree`
  (`:80-81`).
- In `_ready`: `mark_boot_ok()` after `BOOT_OK_SECONDS = 10` (`:49,93-95`); a check 4 s later
  (`:48,96-98`).

**"Restart" from the banner** (`restart_to_update`, `:288-295`):

- `activate_staged()`, then `_relaunch(current)`.
- If the rename fails (Windows: the running `current/diceroll.pck` is open), start a **plain**
  relaunch without `--main-pack`. The new parent's `boot()` then activates staged.
- `_rename` retries 12 × 250 ms with `OS.delay_msec` on the main thread (`update_store.gd:269-274`),
  which can freeze the UI for about 3 s.

**Per-OS notes:**

- **macOS:**
  - `OS.get_executable_path()` is `Diceroll.app/Contents/MacOS/Diceroll`. `create_process`
    fork/execs the inner binary directly, not through LaunchServices. `OS.create_instance()`
    exists for this case.
  - The downloaded pack lives outside the bundle, so the Developer ID signature and
    notarization stay valid. Hardened runtime doesn't block this, because no native code is
    loaded.
  - Relaunching from a translocated or DMG-mounted path is untested.
- **Windows:** handled by the rename-retry + plain-relaunch fallback. Side effect: a failed
  `activate_staged()` has **already deleted `previous/`** (`update_store.gd:189`).
- **Linux:** straightforward (tar.gz only, no AppImage or Flatpak). Linux arm64 gets the same
  x86 desktop PCK (see 1.14 #12).
- **Cost:** the relaunching parent still instantiates `main.tscn`. `main.gd:11-19` builds
  `GameController` and `show_title()` in the same frame before `quit()` takes effect, so every
  boot with an active pack **loads the title twice** (`updater.gd:321` comment).

### 1.8 Rollback

- `MAX_BOOT_ATTEMPTS = 2` (`update_store.gd:20`).
- Each relaunch increments `boot_attempts`. The child resets it after 10 s of running.
- When the parent sees ≥ 2 (`:243-246`), `rollback()` (`:208-218`) runs:
  - discard current, previous → current;
  - `skip_version = bad version`, so the checker won't re-download it (`update_policy.gd:247`).
- Rollback runs in the **parent**, i.e. the binary's own built-in updater code. A pack with
  broken scripts can't break its own rollback. That's good.
- **Gaps:**
  - a pack that crashes after 10 s is never rolled back;
  - two quick quits (< 10 s) cause a **false rollback** plus a permanent skip of that version;
  - `skip_version` is a single value;
  - there's no user-visible notice of a rollback (only `print`).

### 1.9 Channel handling

- `CHANNELS = ["stable","beta"]`, default `stable` (`update_policy.gd:26-27`). A test asserts
  that this matches the CI script (`tests/test_update_channel.gd:35-39`).
- Build default: `build_info.channel`, set by `stamp_version.py:101` to `beta` for prereleases
  and `stable` otherwise. Unknown values become stable (`update_policy.gd:105-107`).
- Override: `user://settings.cfg [update] channel`, set from the Developer menu
  (`update_policy.gd:111-136`).
  - `effective_channel()` honours it only when `channel_lock_reason()` is empty (`:141-164`).
  - Lock reasons: store-managed (`appstore`/`testflight`/`play`), `web`, any non-github
    distribution, and github on non-desktop ("sideloaded mobile").
- `switch_channel()` / `reset_channel()`: persist, discard `staged/`, `check_now(true)`
  (`updater.gd:249-269`).
- **No downgrades:** `decide()` returns NONE with `behind=true` when the channel's version is
  below the running one, even if `min_supported` would force it (`update_policy.gd:217-225`).
  The dev menu confirms beta → stable while a prerelease runs (`dev_menu.gd:312-320`).

### 1.10 Policy decisions (`UpdatePolicy.decide`, `update_policy.gd:209-262`)

Inputs:
- `distribution`, `platform`, `engine`;
- `version` = running content (pack if any);
- `binary_version` = executable (from `--diceroll-binary-version`);
- `staged_version` and `skip_version` from the store.

Order of evaluation:
1. `mandatory = min_supported != "" && binary < min_supported`.
2. `behind` (channel older than running): **NONE**, mandatory forced false.
3. Not newer and not mandatory: **NONE** ("up to date").
4. Distribution `appstore`/`play` (`STORE_DISTS`): **STORE** with `stores.ios` or
   `stores.android` (NONE if the URL is empty). Mandatory carries through.
5. Distribution ≠ `github`: **NONE** ("updates elsewhere").
6. Not mandatory and newer:
   - staged == ver → **READY**;
   - pack present **and** `engine` string equal **and** `binary ≥ min_binary` **and** not
     skipped → **PACK**;
   - else → **BINARY** (reason: no pack / engine differs / below min_binary / rolled back).
7. Mandatory → **BINARY** with `binaries[platform].url`, else `notes_url`.

`UpdateClient` turns PACK into a download, then READY (`update_client.gd:67-73`).

### 1.11 Which builds check, download or prompt

Gates: `can_check()` = active && !web && ((github && desktop) || appstore || play)
(`updater.gd:124-128`). `can_apply_packs()` as in 1.7. Automatic check: 4 s after boot, at most
every 6 h (`CHECK_INTERVAL`, `:47,181`), unless Auto-update is OFF. Manual checks force
(settings CHECK, dev menu).

| Artifact (as built) | Stamped `distribution` (release.yml) | Behaviour today | Documented behaviour (RELEASE.md) |
|---|---|---|---|
| macOS zip/dmg | `github` (`:235`) | check + download pack + relaunch; binary prompt | same ✔ |
| Windows zip, Linux x64/arm64 tar.gz | `github` (`:106`) | same | same ✔ |
| `-desktop.pck` | `github` (its own `build_info.json`) | this is the update payload | — |
| **itch desktop channels** | same GitHub zips (`:424-429`) | **self-update from GitHub + relaunch** | "rely on their platform" ✘ (`:107-108`) |
| **Steam depots 1/2/3** | same GitHub zips (`:445-450`) | **self-update from GitHub + relaunch** (a relaunched child process under Steam is untested) | "downloader disabled" ✘ |
| Web zip | `web` (`:117`) | never checks | ✔ |
| **Android APK (sideload/Obtainium)** | **`play`** (`:185`, one stamp for APK + AAB) | STORE prompt to the Play listing; picker says "updates through Google Play" | "in-game prompt"; picker "sideloaded mobile" reason ✘ |
| Android AAB (Play) | `play` | STORE prompt (fires even when the Play release is a draft or in review) | ✔ |
| **iOS sideload IPA (SideStore/AltStore)** | **`appstore`** (`:246`, one Godot export for all IPAs) | STORE prompt to a **placeholder** App Store URL | "source-based updates", picker sideload reason ✘ |
| iOS signed IPA (TestFlight/App Store) | `appstore` (`testflight` is never stamped) | STORE prompt | ✔ (store link is still a placeholder) |
| CI export-smoke | `dev` (`ci.yml:282`) | never | ✔ |

**Store prompts come from GitHub manifests, not from what the store actually has.** A mobile user
is told "update available" as soon as a tag publishes, even when App Review or a Play draft
hasn't shipped anything.

### 1.12 Developer menu and gesture

- `DevGesture` (`ui/widgets/dev_gesture.gd:17-20,50-60`): 5 taps within 3000 ms in the
  bottom-right 80×80 px inside the safe area. It only watches `_input` and never blocks.
  - Hosted on the title screen (`ui/screens/title_screen.gd:68-69`) and `MissingAssetsScreen`
    (`game/boot/missing_assets_screen.gd:87`).
- `DevMenu` (`ui/modals/dev_menu.gd`):
  - sections `updates` (10): channel picker, CHECK NOW, RESET TO DEFAULT;
  - section `build` (90): version, commit, channel, distribution, Godot, built, plus COPY
    DIAGNOSTICS;
  - extensible via `register_section`/`register_row` (`:43-90`);
  - uses the `Updater` duck-typed (`:246-271`).
- **It ships in release builds**, so any player on a github desktop build can switch to beta.

### 1.13 Tests covering the update system

- `tests/test_update_manifest.gd` (9): fixture parse, schema/channel mismatch, bad fields,
  normalisation, valid/wrapped/tampered/wrong-key/garbage signatures, `_modulus_bits`.
- `tests/test_update_policy.gd` (11): pack/none/binary (engine, min_binary, no pack), running-pack
  binary version, mandatory, ready/skip, store builds, other distributions, build_info defaults,
  platform/URLs.
- `tests/test_update_store.gd` (9): streaming sha256, finish_staging verification, rotation,
  corrupt staged, boot-attempt rollback, mark_ok, engine mismatch, not-newer discard,
  wrong-size current.
- `tests/test_update_e2e.gd` (7): local feed check → stage → boot activate, `file://` base,
  wrong key, empty key, up-to-date/binary paths, `download=false`.
- `tests/test_update_channel.gd` (9): override persistence, policy/updater/client use, reset,
  switch drops staged, store lock-out, downgrade guard (policy + e2e).
- `tests/test_update_semver.gd` (4).
- `tests/test_dev_menu.gd`: gesture, menu.
- Fixtures: `tests/fixtures/update/feed/{update-stable,update-beta}.json(.sig)`, a 3000-byte
  pack, RSA-2048 test keys.
- **Not tested:**
  - `_relaunch`/`_base_args`/`restart_to_update`, and any real `--main-pack` boot of an
    exported build;
  - HTTP paths (redirects, stall, 4xx);
  - Windows rename behaviour;
  - concurrent check/switch;
  - Steam/itch runtime behaviour.
- Nothing tests packs or manifests beyond schema 1.

### 1.14 Bugs, race conditions, security weaknesses

Severity: H = fix before building on it, M = should fix, L = minor.

1. **H – Distribution mis-stamping** (1.11). Steam and itch builds self-update and relaunch.
   The sideload APK/IPA prompt to Play or the App Store (IPA: placeholder URL). This needs
   separate stamps: `steam`, `itch`, `sideload-ios`, `sideload-android`, `testflight`. Because
   `build_info.json` lives inside the PCK, that means separate exports or a sidecar override.
2. **H – Signing-key custody.**
   - `UPDATE_SIGNING_KEY` is a repo secret exposed to `release.yml` on any `v*` tag push and on
     `workflow_dispatch` (`release.yml:7-18,281`). There is no `environment:` with required
     reviewers anywhere (`grep` finds none).
   - A tag push runs the workflow file **from the tagged commit**, so a writer can tag a commit
     that exfiltrates the key.
   - The key signs what is effectively executable code (the full main pack).
3. **H – Schema lock-in** (TL;DR #3): `update_manifest.gd:116-117`.
4. **M – No freshness or anti-freeze.**
   - `released` is never checked, there is no expiry, and the client persists no "highest seen
     manifest version/sequence".
   - A stale or malicious mirror, or anyone able to serve an old signed manifest, can freeze
     clients at a version indefinitely.
   - Rollback of the *installed* version is prevented: `decide()` never goes backwards and
     `boot()` discards packs not newer than the binary.
5. **M – Single key, no `kid`, no multi-key, no revocation** (1.4). A compromise means shipping
   a new binary, and binary-only installs can't be rescued in-band.
6. **M – Channel switch during a download.**
   - While a pack downloads, only `staged/diceroll.pck.part` exists, so `has_pack("staged")` is
     false.
   - `_after_channel_change()` (`updater.gd:264-269`) therefore discards nothing.
   - `check_now(true)` hits `client.busy` → "check already running" (`update_client.gd:36-37`).
     The dev menu shows "Check failed".
   - The in-flight download of the **old** channel then completes, is staged and gets offered
     (READY).
   - Also, the failed concurrent check sets `status=""` (`updater.gd:195-196`), so the progress
     banner flickers away.
7. **M – Auto-update OFF reverts content.** `can_apply_packs()` requires `is_auto_enabled()`
   (`:118-120`). With it OFF, the next launch runs the binary's built-in version even if a newer
   pack is `current`. Settings CHECK still downloads packs (`settings_panel.gd:172`), and
   RESTART runs them once.
8. **M – Build-default channel drifts.** While a pack runs, `Policy.build_info()` reads the
   **pack's** `res://build_info.json`. After a stable user switches to beta and runs a beta
   pack, `build_channel()` is `beta`, so "RESET TO DEFAULT" means beta.
9. **M – False rollbacks.** Quitting within `BOOT_OK_SECONDS=10` twice rolls back and
   permanently skips that version (`update_store.gd:208-218`). Crashes after 10 s never roll
   back.
10. **M – `min_binary`/`min_supported` are never set** by the workflow (defaults `0.1.0`,
    `update_manifest.py:72-73`; `release.yml:287-288` passes neither). Nothing prevents a pack
    that needs a newer executable (template or preset change, new engine-side feature) from
    being applied to an old binary.
11. **M – Engine gate is exact** `major.minor.patch` (`update_policy.gd:248`,
    `update_store.gd:237`). Any Godot patch bump forces a full binary re-download for everyone
    and discards all packs. `GODOT_VERSION` is hard-coded in 4 places: `release.yml:28`,
    `ci.yml:27`, `stamp_version.py:36`, `update_manifest.py:71`.
12. **M – Texture format of the update pack.**
    - `tools/export.sh:224-231` exports the pack from the **Linux x86_64** preset, which has
      S3TC/BPTC only (`export_presets.cfg:423-424`).
    - `linux.arm64` installs, whose preset carries ETC2/ASTC too (`:453-454`), receive this pack.
    - On ARM GPUs without BC support the imported `.ctex` remaps likely fail to load. Needs
      verifying.
    - macOS (Apple Silicon supports BC) is fine.
13. **M – Token leak on redirect** (tested) + env-only token (1.5).
14. **L – No download size cap** (`update_fetcher.gd:60-66`). No resume. Failed checks still
    consume the 6 h throttle, because `set_last_check` runs before the fetch (`updater.gd:191`).
15. **L – Current pack integrity at boot is size-only** (`update_store.gd:257`). This is a local
    attacker only, since `user://` is writable by the user anyway.
16. **L – Non-atomic channel publish.** `gh release upload --clobber channels/*`
    (`release.yml:341`) replaces `.json` and `.sig` one after another, so a client can briefly
    see mismatched pairs (signature invalid) or a 404. It's transient.
17. **L – Double title load** on every relaunch (1.7). There's also a 3 s main-thread block in
    Windows rename retries.
18. **L – `binaries[].sha256` unused**; the binary "update" is just the browser opening an
    archive URL. There's no Sparkle, Velopack or WinSparkle.
19. **L – `Policy.build_info()` merges string values only** (`update_policy.gd:50-52`). The int
    `build` (build code) is dropped.
20. **L – Windows file version for prereleases** is `X.Y.Z.<rc>` and for finals `X.Y.Z.0`
    (`stamp_version.py:119`). That isn't monotonic from rc to final, which matters for MSIX or
    Velopack later.
21. **L – Harness in release builds.** `tools/shot.gd` (autoload `Shot`) and scenarios ship in
    every export (`export_filter="all_resources"`, exclude only `docs/* tests/* build/*`).
    `-- --scenario=…` works in release builds and also disables the updater (`updater.gd:107-109`).

---

## 2. CI / release pipeline

### 2.1 `ci.yml` (PR, push main, nightly 06:17 UTC, dispatch; `ci.yml:6-17`)

All jobs run on `ubuntu-24.04`. Concurrency cancels superseded PR runs (`:19-21`).

| Job | What it does | Gate |
|---|---|---|
| `plan` (`:31-86`) | Changed paths (docs-only → `code=false`); asset secret present?; screenshot matrix (quick on PRs, one shard per scenario on main/nightly/dispatch full) | — |
| `static` (`:89-115`) | `tools/ci/check_repo.sh` (no third-party assets, key files, private-key blocks, files > 1.5 MB); gitleaks 8.30.1 (curl, no checksum); actionlint 1.7.12 (`curl \| bash`); shellcheck; `py_compile` + `tools/ci/selftest.sh` (bundle round trip, build codes, notes dry run, **RSA-2048 sign + openssl verify of the manifest**) | always, forks included |
| `test` (`:118-145`) | setup-diceroll; `assets.py verify`; `ui/check_scripts.gd`; `game/dice/check_dice_tray.gd`; `tests/run.sh`; sim smoke 50 runs/class | code && assets secret |
| `shots` (`:148-197`) | Xvfb + Mesa lavapipe; shader cache; `shoot_ci.sh` | same |
| `shots-report` (`:200-263`) | merge shards; baseline from last green main; `img_diff.gd`; contact sheet; publish baseline on main; fail on broken shots | after shots |
| `export-smoke` (`:266-285`) | stamps `dev`, exports Linux, Windows, Web (artifacts not uploaded) | push/nightly only (not PRs) |

`pr-title.yml`: `amannn/action-semantic-pull-request@v6`, Conventional Commit types incl.
`balance`, lowercase subject.

### 2.2 `release.yml` (tag `v[0-9]+.[0-9]+.[0-9]+*` or dispatch with `version` + `publish`; `:7-18`)

Job graph: `prepare` → {`desktop-web`, `android`, `apple`} → `publish`.

Store jobs depend **only on their build job, not on `publish`**. They run in parallel with it
and even when `publish=false`, which contradicts RELEASE.md:88 ("Enabled store flows run last").

| Job | Runner | Builds / does | Stamp |
|---|---|---|---|
| `prepare` (`:32-79`) | ubuntu-24.04 | Resolve version (`stamp_version.py --print --github-output`: version, short, build code, channel, prerelease); git-cliff dev changelog; `changelog_llm.py` (Claude model from `CHANGELOG_MODEL`, JSON-schema output, fallback without key) → `release-notes` artifact (30 d) | — |
| `desktop-web` (`:82-137`) | ubuntu-24.04 | `export.sh linux`, `linux-arm64`, `windows`, `pck`; re-stamp `web`, then `export.sh web`; package tar.gz/zip; copies `build/pck/Diceroll-desktop.pck` → `dist/Diceroll-<v>-desktop.pck` | `github` then `web` |
| `android` (`:140-197`) | ubuntu-24.04 + temurin 17 | Optional release keystore from secrets → `GODOT_ANDROID_KEYSTORE_RELEASE_*` (else **debug key**, warning); `export.sh android` (APK), `android-aab` (Gradle) | `play` for both |
| `apple` (`:200-253`) | **macos-26**, "newest `Xcode_*.app`" chosen with `sort -V` (unpinned) | macOS: `export.sh macos` + `macos_package.sh` (sign/notarize/zip/dmg). iOS: `ios_build.sh` (signed `-ios.ipa` if the 4 Apple secrets exist; always unsigned `-ios-sideload.ipa`; else `-ios-simulator.zip`) | macOS `github`; iOS `appstore` |
| `publish` (`:256-349`) | ubuntu-24.04, `contents: write` | `update_manifest.py` → `channels/update-<ch>.json(+.sig)`; download the existing AltStore source from `channels`, then `altstore_source.py`; build manifest JSON (asset lock hash + unit hashes, artifact sha256/bytes, run URL); `SHA256SUMS.txt`; what's-new txt copies; release body; `softprops/action-gh-release@v3` (prerelease flag, make_latest for finals); ensure the `channels` prerelease exists, then `gh release upload channels --clobber channels/*` | — |
| `testflight` (`:353-375`) | ubuntu-24.04 | `apple-actions/upload-testflight-build@v5` with the ASC API key; requires `-ios.ipa` | `vars.ENABLE_APPSTORE == 'true'` |
| `google-play` (`:377-401`) | ubuntu-24.04 | `r0adkll/upload-google-play@v1`, AAB, track `vars.PLAY_TRACK \|\| internal`, status `vars.PLAY_STATUS \|\| draft`, whatsnew-en-US | `vars.ENABLE_PLAY` |
| `itch` (`:403-429`) | ubuntu-24.04 | butler from `broth.itch.zone/.../LATEST` (no checksum); push web, windows, linux (x64 only), mac channels | `vars.ENABLE_ITCH`, `vars.ITCH_TARGET` |
| `steam` (`:431-461`) | ubuntu-24.04 | Unpack windows/linux x64/macos zips into depots 1/2/3; `game-ci/steam-deploy@v3`; `releaseBranch` = `vars.STEAM_BRANCH \|\| beta` | `vars.ENABLE_STEAM`, `vars.STEAM_APP_ID` |

### 2.3 Signing per platform

| Platform | Implemented | Where |
|---|---|---|
| Updater manifests | RSA-3072 via `openssl dgst -sha256 -sign`; unsigned without the secret | `update_manifest.py:51-59,98-104`, `release.yml:281` |
| macOS | Godot built-in ad-hoc (`codesign/codesign=1`, `export_presets.cfg:45`). With `MACOS_CERT_P12_BASE64`: temp keychain, `codesign --force --deep --options runtime --timestamp` (no entitlements file, no sandbox) (`macos_package.sh:29-46`). With the ASC API key: `notarytool submit --wait`, `stapler staple`, `spctl --assess` (`:51-58`). DMG is `codesign`ed (`:81`) but **not notarized or stapled** | `tools/ci/macos_package.sh` |
| iOS | With `APPLE_TEAM_ID` + ASC key: `xcodebuild archive` with automatic signing and `-allowProvisioningUpdates`, export `app-store-connect` (`ios_build.sh:34-58`). Sideload IPA always **unsigned** (`CODE_SIGNING_ALLOWED=NO`, `:61-66`) | `tools/ci/ios_build.sh` |
| Android | Release keystore via env (`release.yml:165-180`), else a generated debug keystore (`export.sh:244-255`). APK and AAB use the same key. With Play App Signing, Play installs and sideload APKs **can't update each other** (different signing certs) | |
| Windows | **None.** `codesign/enable=false` (`export_presets.cfg:382`); no Authenticode step | |
| Linux | None | |
| Release files | `SHA256SUMS.txt` **unsigned**; no minisign/cosign/GPG; no `actions/attest-build-provenance` | `release.yml:311` |

Live evidence: rc.3 shipped `-ios-simulator.zip`, so the **Apple signing secrets weren't
configured** at rc.3 and there's no `-ios.ipa`. macOS signing status can't be told from the asset
list.

### 2.4 Artifacts (names from `release.yml`; sizes from the live rc.3 release)

`Diceroll-<v>-`:

| Suffix | rc.3 size |
|---|---|
| `android.aab` | 137.6 MB (armv7 + arm64) |
| `android.apk` | 112.8 MB (arm64) |
| `desktop.pck` | **85.3 MB** |
| `ios-sideload.ipa` | 101.6 MB |
| `ios-simulator.zip` | 102.3 MB |
| `linux-arm64.tar.gz` | 103.4 MB |
| `linux-x86_64.tar.gz` | 104.2 MB |
| `macos.dmg` | 145.7 MB |
| `macos.zip` | 136.9 MB |
| `web.zip` | 86.3 MB |
| `windows-x86_64.zip` | 113.9 MB |
| `build-manifest.json`, `whats-new-{ios,android}.txt` | small |

Plus `SHA256SUMS.txt`.

Artifact retention: dist 7 d, notes 30 d, `release-<v>` (sums, build manifest, channels) 30 d.

### 2.5 The `channels` rolling release and AltStore source

- Tag `channels`, prerelease, `--latest=false`, created on first publish (`release.yml:336-340`).
- Assets:
  - `update-stable.json(.sig)` (finals; each final also rewrites `update-beta.json`);
  - `update-beta.json(.sig)`;
  - `altstore-source.json` (finals) or `altstore-source-beta.json` (prereleases).
- Live: only the beta files exist.
- **AltStore source** (`tools/ci/altstore_source.py`):
  - AltStore source v2: source metadata; one app `gg.vlad.diceroll`; `versions[]` newest first,
    capped at 20 (`:25,96-97`), each with `version` (short), `buildVersion` (build code),
    `marketingVersion`, `date`, `localizedDescription`, `downloadURL`, `size`, `minOSVersion`
    (default 15.0) (`:86-95`).
  - **No app-level `downloadURL`/`version`/`size`.** The proposal (§8.6) says SideStore needs a
    top-level `downloadURL`. Confirmed on the live JSON: app keys lack it.
  - Finals only update the stable source, so users of the beta source never see final releases.
    (The updater manifests do refresh beta.)
  - Icon and screenshots come from `raw.githubusercontent.com/.../main/...`.
  - `appPermissions` is empty.

### 2.6 Store and platform uploads

- **TestFlight:** upload only, no metadata. "What's new" is manual (`release.yml:374-375`).
- **Play:** the first AAB must be uploaded by hand (RELEASE.md:156). Default track is internal,
  default status draft.
- **itch:** butler channels `web`, `windows`, `linux`, `mac`. No linux-arm64. Uses the
  self-updating GitHub builds.
- **Steam:** `game-ci/steam-deploy@v3` with depot1 = windows, depot2 = linux x64, depot3 = macos
  (the action derives depot IDs from the app id). No Steamworks integration in the game (grep
  finds no Steam code). Uses the self-updating GitHub builds.
- All four are gated by `vars.ENABLE_*`. `ENABLE_*` state on the repo is unknown, and nothing
  store-side shows in the live release.

### 2.7 Runners, toolchains, Godot templates, caching

- **Runners:**
  - `ubuntu-24.04` everywhere except `apple`: **`macos-26`**, changed from macos-15 in
    `865d1cb`.
  - Xcode: the newest `/Applications/Xcode_*.app` on the image, unpinned (`release.yml:209-213`).
  - Java: temurin 17 (`setup-java@v6`). Android SDK from the runner image (`ANDROID_HOME`).
- **Action pins (tags, not SHAs):**
  - GitHub: checkout@v7, upload-artifact@v7, download-artifact@v8, cache@v6, setup-java@v6.
  - Third-party: softprops/action-gh-release@v3, apple-actions/upload-testflight-build@v5,
    r0adkll/upload-google-play@v1, game-ci/steam-deploy@v3,
    amannn/action-semantic-pull-request@v6.
  - The third-party store actions receive secrets.
- **Godot + templates** (composite `.github/actions/setup-diceroll/action.yml`):
  - Official `godotengine/godot-builds` `4.7.2-stable` editor zip + `export_templates.tpz`,
    **SHA-512 verified** against `SHA512-SUMS.txt` from the same release (`:80-90`).
  - Templates pruned per runner (`:93-99`). `desktop` = `linux_*`, `windows_*_x86_64*`,
    `web_nothreads_*`, `android_*`. `apple` = `macos.zip`, `ios.zip`.
  - **No custom templates** (`custom_template/*` empty in every preset), so no PCK encryption key
    and no engine modules.
  - Cached under `godot-<ver>-<pkg>-tpl-<set>-v1`.
- **Caches:**
  - Godot + templates.
  - Encrypted asset bundles in `.ci-cache/bundles`, keyed by the lock digest with a
    `asset-bundles-` restore prefix (incremental).
  - Encrypted `.godot` import cache (age-sealed; key = OS + Godot + lock hash +
    `project.godot`/shaders).
  - Shader cache in `shots`.
  - **No Gradle cache**, removed in `865d1cb`, although RELEASE.md:204-205 still lists it.
- **Asset bundles** (`tools/ci/assets.py`, `assets.lock.json`):
  - The lock has **31 units: 23 kaykit, 6 sfx, music, fonts**. That's 106.8 MB plaintext,
    38.6 MB encrypted, 8,384 files; `lock_hash` `da33571ef6b790c3`.
  - Largest units: forest 23.3 MB plain / 3,977 files; music 18.8 MB; animations 12.6 MB;
    foes 8.2 MB; dungeon 6.2 MB; resources 5.4 MB; dungeon_x 4.8 MB; boardgame 4.1 MB.
  - **There is no `rendered-icons` unit in the lock** even though `assets.py:66-67` defines one.
    ASSETS.md:41 ("31 units … rendered UI icons … ~28 MB") is inaccurate.
  - Hash: sha256 over sorted `relpath\tsha256` lines. `.import` files are hashed **without
    their per-checkout `uid=` line** (`assets.py` `content_sha`, commit `796a7b0`). **Asset UIDs
    are not stable across checkouts**, which reinforces path-only loading.
  - Storage backends already implemented: private git repo (deploy key), `--s3` (AWS/R2 via
    `AWS_ENDPOINT_URL`), `--gh-release`, `--dir`.

### 2.8 CI risks relevant to a new distribution design

- No `environment:` protection on signing or store secrets (1.14 #2). No tag protection is
  visible in-repo (rulesets are not inspectable from here).
- Supply chain: tag-pinned third-party actions receiving secrets; unverified butler `LATEST`;
  `curl | bash` for actionlint.
- The GitHub Release is created **before** the channels upload. If the channels step fails,
  users don't get the update, but the release is public.
- `workflow_dispatch` with `publish=false` still runs store uploads if they're enabled.
- The macOS DMG isn't notarized. No Windows Authenticode (SmartScreen). The Android debug-key
  fallback silently ships in releases when the keystore secret is missing: Obtainium users would
  have to reinstall when the real key arrives.

---

## 3. Content-streaming proposal: what exists

Proposal: `docs/design/2026-09-29-content-streaming.md`. Status line "Nothing here is
implemented" (`:3`) is essentially still true.

| Phase / item | Status | Evidence |
|---|---|---|
| **P0** `game/content/packs.gd`, `needs.gd`, `Content.available()` | ✘ absent | `ls game/content`: no such directory; grep for `ContentPacks`/`Content.available`/`packs.gd`/`needs.gd` finds nothing outside docs |
| P0 tests (`tests/test_content_packs.gd`: unit→pack, path prefixes, no preload/uid/tscn refs, ids covered) | ✘ absent | no file. The invariants do hold today: no `preload("res://assets`, no `uid://` in `.gd`, no `.tscn`/`.tres` referencing `res://assets` (grep). Nothing enforces them. |
| P0 forest dedupe (Camp on the flat folder, drop `color*/`) | ✘ not done | `game/camp/camp_scene.gd:28`, `game/camp/camp_props.gd:7` still use `forest/color%d/…`; `tools/import_assets.sh:96-97` still syncs `color$c` plus the flat copy (`:232-238`) |
| P0 display-font fix | ✔ **done** | `ui/theme/ui_theme.gd:25-43`: `load(DISPLAY_PATH)` when `ResourceLoader.exists`, `load_dynamic_font` only as the source-checkout fallback (`:36-38`); commit `4bb9028` "fix(ui): load the imported display font in exported builds (#1)". The design doc §10.1.5 / §12 is stale. |
| **P1** base preset excluding `assets/**` | ✘ | all 8 presets use `export_filter="all_resources"`, `include_filter="build_info.json"`, `exclude_filter="docs/*, tests/*, build/*"` |
| P1 PCKPacker unit-pack builder (`tools/ci/build_packs.gd`) | ✘ | no `PCKPacker` anywhere in code |
| P1 manifest schema 2 (`packs{}`, `code{requires_packs}`) | ✘ | `SCHEMA := 1` (`update_manifest.gd:17`); `update_manifest.py:81` writes schema 1 |
| P1 per-pack store / eviction | ✘ | 3 fixed slots, one `diceroll.pck` (`update_store.gd:15-18`) |
| P1 `load_resource_pack(…, replace_files=false)` mount | ✘ | no `load_resource_pack` call anywhere |
| **P2** `BootShell` loader + boot-stage scenarios | ✘ | `main.gd:11-19` is still AssetCheck → `MissingAssetsScreen` (source checkouts only) → `GameController.show_title()`. The seed exists: `game/boot/missing_assets_screen.gd` (engine built-ins + logo, hosts DevGesture) with the `asset_missing` scenario (`game/boot/scenarios.gd`) |
| **P3** Web lazy packs, lean installers, resume, eviction, prefetch | ✘ | Web is one `index.pck`; no Range/resume |
| P3/§8 unsigned sideload IPA | ✔ built | `tools/ci/ios_build.sh:60-66` |
| P3/§8 AltStore/SideStore source | ✔ built (without the top-level `downloadURL` the proposal calls for) | `tools/ci/altstore_source.py` |
| §8 `packs` release on GitHub | ✘ | only `channels` + per-version releases |
| §4 `build_info.packs {source, downloads, required_embedded, scripts_in_packs}` | ✘ | `stamp_version.py:103-105` writes no `packs` object |
| §4 CI "no scripts in packs" check (godotpcktool) | ✘ | — |
| **P4** encryption (custom templates), PAD, Background Assets, per-biome packs, Velopack/Sparkle, delta patches | ✘ | `encrypt_pck=false`/`encrypt_directory=false` everywhere; `patch_delta_encoding=false` (keys present only in the macOS/iOS/Web presets: `export_presets.cfg:14-18,81-85,195-199`); `patches=PackedStringArray()` everywhere |

**Measured drift since the proposal:** the full PCK is now **85.3 MB** (the doc measured 73.2 MB).

---

## 4. `build_info.json`

- **Writer:** `tools/ci/stamp_version.py:85-132`, run per export step (git-ignored:
  `.gitignore` `/build_info.json`).
- **Fields** (`:103-105`):
  - `version`: full semver.
  - `short_version`: X.Y.Z.
  - `build`: int, `major*1e6 + minor*1e4 + patch*100 + (pre number ≤98, or 99)` (`:57-62`).
  - `commit`: 12 chars of `GITHUB_SHA`/HEAD.
  - `channel`: `--channel`, else `beta` if prerelease, else `stable` (`:101`).
  - `distribution`: `--distribution`, default `github`.
  - `godot`: **hard-coded "4.7.2"** (`:36`).
  - `built`: UTC ISO.
- **The same run also patches** (not committed):
  - `project.godot` `config/version`;
  - presets:
    - macOS/iOS `application/short_version` and `application/version` (build code);
    - Android `version/name` and `version/code`;
    - Windows `file_version`/`product_version` = `X.Y.Z.<pre#|0>` (`:118-130`).
- **Exported** through every preset's `include_filter="build_info.json"`, so it lives **inside
  the PCK**. That's why the update pack carries its own `build_info` (1.14 #8).
- **Reader:** `UpdatePolicy.build_info()` (`update_policy.gd:42-53`) merges **string** values
  over the defaults `{version: ProjectSettings config/version, commit "", channel "stable",
  distribution "dev", godot engine_version(), built ""}`.
- **Stamps per job:** `github` (Linux x64/arm64, Windows, desktop pck, macOS), `web`, `play`
  (APK **and** AAB), `appstore` (all IPAs), `dev` (CI smoke).
- **Values the code understands** (`update_policy.gd:16-21,149-164`): `github`, `dev`,
  `appstore`, `play`, `testflight`, `web`, plus any other string, which gets the generic
  "updated by its storefront" treatment.
- **Per-channel flags:** none beyond `channel`/`distribution`. There's no `packs`, `downloads`,
  or `updates_enabled` flag.

---

## 5. Platform export settings (`export_presets.cfg`)

Common to all 8 presets:
- `export_filter="all_resources"`, `include_filter="build_info.json"`,
  `exclude_filter="docs/*, tests/*, build/*"`;
- `script_export_mode=2` (compressed binary tokens);
- `encrypt_pck=false`, `encrypt_directory=false`, empty encryption filters, `seed=0`;
- `patches=[]`;
- no custom templates.

| Preset (lines) | Platform settings |
|---|---|
| **macOS** (`:1-66`) | `architecture="universal"`; min macOS 10.13 (x86_64) / 11.00 (arm64); bundle id `gg.vlad.diceroll`; category Games; `codesign/codesign=1` (built-in ad-hoc), identity/team empty; all entitlements false, **app sandbox off**, no custom entitlements file; `notarization/notarization=0` (done by script instead); textures **S3TC/BPTC + ETC2/ASTC**; high-res on; `patch_delta_encoding=false` (zstd 19, min reduction 0.1). Hardened runtime is added by `macos_package.sh` (`--options runtime`), with no entitlements. |
| **iOS** (`:68-180`) | `architectures/arm64=true`; `app_store_team_id=""` (placeholder injected at export, `export.sh:128-134`; real team from `APPLE_TEAM_ID`); `export_method_release=0` (App Store), `export_method_debug=1`; bundle `gg.vlad.diceroll`; **min iOS 15.0**; plist `UIRequiresFullScreen=true`; `targeted_device_family=2` (iPhone + iPad); `export_project_only=true` (xcodebuild in CI); **capabilities: none** (`access_wifi`, `performance_gaming_tier`, `performance_a12` false; no additional); Files-app and iTunes sharing off; no privacy strings; full icon set incl. dark/tinted; storyboard bg `#1a0f0f`. |
| **Web** (`:182-231`) | `variant/thread_support=false` (**nothreads**, no COOP/COEP; `export.sh:196` asserts it); `extensions_support=false` (no GDExtension on web); VRAM compression **for desktop and mobile** (both texture families shipped); canvas resize policy 2; `progressive_web_app/enabled=false` (no service worker/offline); renderer `gl_compatibility` (`project.godot:38`). Zip 86.3 MB at rc.3. **No hosting/deploy job** (GitHub Pages absent; itch only when enabled). |
| **Android APK** (`:233-291`) | `gradle_build/use_gradle_build=false` (prebuilt template); **min/target SDK not pinned** (empty, so Godot 4.7 template defaults; confirm against Play's current target-API rule); **arm64-v8a only**; package `gg.vlad.diceroll`; signed; permissions `INTERNET`, `ACCESS_NETWORK_STATE`; immersive; `user_data_backup/allow=false`; `apk_expansion` off. |
| **Android AAB** (`:293-351`) | `use_gradle_build=true`, `export_format=1` (AAB); **armeabi-v7a + arm64-v8a**; otherwise identical. The build template is installed at export time (`export.sh:283-296`). Godot's Gradle template puts assets in an install-time asset pack. No fast-follow/on-demand PAD. |
| **Windows** (`:353-395`) | x86_64; `embed_pck=false` (sidecar `.pck`); S3TC/BPTC only; `codesign/enable=false`; rcedit `modify_resources=true`; company/product metadata; `export_d3d12=0`, `export_angle=0`; icon empty (project icon). |
| **Linux** (`:397-425`) | x86_64; sidecar pck; **S3TC/BPTC only**. This preset is also the source of the updater's `desktop.pck` (`export.sh:231`). |
| **Linux ARM64** (`:427-455`) | arm64; sidecar pck; S3TC/BPTC **+ ETC2/ASTC**. |

Project-level (`project.godot`):
- `config/version="0.1.0"` (`:7`);
- renderer `forward_plus`, mobile `mobile`, web `gl_compatibility`;
- `import_etc2_astc=true` (`:41`);
- autoloads `Updater`, `Shot`, `Audio` (`:16-18`);
- `[diceroll] update/base_url` (`:22`).

---

## 6. Gap and risk list for the new distribution proposal

### (a) Per-pack delta updates

Must change:

1. **Manifest compatibility.**
   - Installed clients hard-reject `schema != 1` (`update_manifest.gd:116-117`).
   - Either keep `"schema": 1` and add `packs{}`/`code{}` (unknown keys survive `validate()`),
     or publish `update-<ch>.v2.json` beside the v1 files for a transition period.
   - Old clients also expect `pack` to be the **full main pack**. Keep publishing it until they
     have migrated.
2. **Build.**
   - A base preset excluding `assets/**` and `ui/icons/rendered/*.png`.
   - A headless PCKPacker builder from `.godot/imported` + `.import` files, with deterministic
     pack hash = f(unit hashes, engine major.minor, import-settings hash).
   - A CI assertion that packs contain no `.gd`/`.gdc`/`.remap`/`project.binary`/caches.
   - Unit hashes exist (`assets.py`), but the lock lacks `rendered-icons` and the hash ignores
     `uid=` lines. That's fine for path loads; PCKPacker packs don't register UIDs anyway.
3. **Texture formats.** Pack builds must be universal (S3TC/BPTC + ETC2/ASTC) or per-format. The
   current desktop PCK is S3TC/BPTC-only and is served to `linux.arm64` (1.14 #12).
4. **Client store.**
   - Replace the single-pack slots with content-addressed `user://packs/<id>-<hash>.pck` + meta,
     "pinned by current and previous" eviction, and verification before mount.
   - The code pack can keep staged/current/previous + `--main-pack`.
5. **Mounting.**
   - Nothing calls `ProjectSettings.load_resource_pack` today.
   - It must happen before first use and with `replace_files=false`.
   - The parent-vs-child relaunch split means mounts must happen in the child (pack code).
   - Android `load_resource_pack` stalls (godot#105009) remain unverified.
6. **Engine gating.** Move from an exact `x.y.z` string (`update_policy.gd:248`,
   `update_store.gd:237`) to a pack `format` + engine `major.minor`, with CI rebuilding packs on
   an engine bump.
7. **Downloader.**
   - Resume via Range: `HTTPRequest.download_file` truncates, so this needs a custom
     `HTTPClient` loop or chunked parts.
   - A size cap per the signed size.
   - Parallel/serial pack queue, backoff, and pausing.
   - The current `busy` flag only allows one check or download at a time.
8. **Policy.**
   - Per-pack decisions, and `requires_packs` pinning for the code version.
   - Rollback must restore the previous code pack **and** its pinned pack set.
   - `skip_version` becomes per-code-version.
   - The 10 s boot-OK heuristic needs rethinking (1.14 #9).
9. **Deltas below the pack level** (optional): Godot 4.6+ `--export-patch` / `patch_delta_*` is
   off everywhere and ties patches to exact bases. It would need N from-versions per release.
   zstd `--patch-from` / HDiffPatch are alternatives.
10. **`min_binary` must become real.** CI needs a rule for when the executable or templates
    change. Today it is always `0.1.0`.

### (b) Platform-native delivery (Background Assets, Play Asset Delivery, Steam depots)

1. **Distribution identity first.**
   - Steam and itch currently get self-updating `github` builds. The sideload APK is stamped
     `play` and the sideload IPA `appstore`.
   - Add `steam`, `itch`, `sideload-android`, `sideload-ios`, `testflight` (or a
     `build_info.updates` flag).
   - Because `build_info.json` is inside the PCK, per-channel builds need per-channel exports, a
     tiny per-channel override pack, or a sidecar/bundle file read at boot.
   - Stop pushing GitHub self-updaters to Steam and itch.
2. **Steam.**
   - Ship packs as separate files in the depot (better SteamPipe chunk deltas).
   - Disable the in-game downloader. `OS.create_process` relaunch under the Steam client is
     untested; avoid it on Steam.
   - Linux arm64 isn't in depots (Deck is x86_64, fine).
   - macOS depot = the same notarized app.
   - No Steamworks SDK integration exists; add GodotSteam only if needed.
3. **Play Asset Delivery.**
   - The AAB uses the Godot Gradle template (install-time asset pack only).
   - Fast-follow/on-demand needs Gradle template edits (asset-pack modules) plus an Android
     plugin (v2) wrapping `AssetPackManager`, then `load_resource_pack(abs_path)`.
   - Sideload APKs can't use PAD, so they need the embedded or remote path.
   - Play App Signing breaks APK ↔ Play cross-updates. Decide whether the sideload APK uses a
     distinct applicationId.
   - Pin `min_sdk`/`target_sdk` (currently empty).
4. **Apple Background Assets (Apple-hosted managed packs).**
   - iOS 26+ only. The preset's **min iOS is 15.0**, so it needs a fallback (embedded packs) or
     a raised minimum.
   - Needs a Swift/ObjC iOS plugin (GDExtension or `.gdip`) and entitlements/Info.plist keys
     (capabilities are currently all off).
   - Needs CI packaging and upload of asset packs to App Store Connect. `ios_build.sh` only
     archives and exports today.
   - Not usable for SideStore/AltStore. ODR is deprecated.
5. **Web.** No PWA/service worker (`progressive_web_app/enabled=false`) and no hosting job.
   Lazy packs need same-origin or CORS hosting and IndexedDB-backed `user://` (memory cost).
6. **CI.** Store jobs don't depend on `publish` and ignore `publish=false`. Native-delivery
   uploads should be ordered after a successful publish or gated by environments.

### (c) Ed25519 / compact JWS (EdDSA) signing via Polaris Key (Cloudflare Worker)

1. **Verification capability in Godot 4.7.2 (tested):**
   - `CryptoKey` can't parse Ed25519 keys (mbedTLS -15488).
   - `HashingContext` has no SHA-512, which Ed25519 needs internally.
   - `Crypto.verify` does work with **ECDSA P-256** (DER signatures).
   - Options:
     1. **pure-GDScript Ed25519 + SHA-512** verifier (manifests are small, so speed is fine;
        ~500–800 lines of crypto to test against RFC 8032 vectors);
     2. a GDExtension (libsodium/monocypher) built for macOS/Windows/Linux x64+arm64/Android/iOS.
        Web needs `variant/extensions_support=true` (dlink template), currently false
        (`export_presets.cfg:211`);
     3. an engine module in custom export templates (the same L-sized CI cost as encryption);
     4. have Polaris Key also emit an **ES256** JWS, or keep RSA in parallel during migration.
        JWS ES256 signatures are raw r‖s and must be converted to DER for `Crypto.verify`.
2. **Code to change:**
   - `update_manifest.gd:23-48`. The `_modulus_bits` RSA-only pre-check (`:40,53-101`) rejects
     any other key type.
   - JWS parsing: base64url (Marshalls is standard base64 only), header JSON, `alg` allowlist
     (`EdDSA` only; never `none`/HS*), `kid` lookup, signing input = ASCII `header.payload`.
   - The payload becomes the manifest (or its hash).
   - `update_client.gd:47-57` fetches two files. JWS can be one file (`update-<ch>.jws`) or a
     detached JWS kept beside the JSON.
3. **Keys:**
   - Replace the single `PUBLIC_KEY_PEM` (`update_keys.gd:10`) with a `kid → key` set, and
     accept any trusted `kid`.
   - Rotation happens in-band for github-desktop via the pack, and only via binary updates for
     store/sideload builds. Plan an overlap window and a revocation list.
4. **Claims:** add `iat`/`exp` (bounded validity; decide the clock-skew policy for offline
   devices), a monotonic `seq` persisted in `state.cfg` (reject lower), `channel`, and
   `min_client_schema`.
5. **Backward compatibility:** installed clients only understand `update-<ch>.json` +
   RSA `.sig`. Keep producing those (RSA key or a Polaris-held RSA key) until the install base
   has moved to a JWS-capable build.
6. **CI:**
   - Replace `openssl dgst -sign` (`update_manifest.py:51-59`) and the `UPDATE_SIGNING_KEY`
     secret with a call to the Worker, authenticated by a GitHub OIDC token (`id-token: write`)
     whose claims (repo, ref = protected tag, environment) the Worker checks. That also fixes
     1.14 #2.
   - Update `selftest.sh` step 4 and the test fixtures (RSA today) with EdDSA vectors.
   - Sign `SHA256SUMS.txt` and the AltStore source too, if desired.

### (d) Cloudflare R2 instead of GitHub Releases

1. **Baked URLs.**
   - `DEFAULT_BASE_URL` (`update_policy.gd:11`) and `project.godot:22` point at
     `github.com/…/releases/download/channels`. Every installed build polls there.
   - github-desktop installs can be moved by a pack update, since `project.godot` → ProjectSettings
     comes from the pack.
   - Store/sideload builds and anything that can't take a pack keep polling GitHub until their
     binary updates.
   - So keep publishing manifests at the GitHub `channels` URL (possibly as stubs whose pack
     URLs are absolute R2 URLs; `Fetcher.join` accepts absolute URLs, `update_fetcher.gd:37-40`),
     or keep a permanent redirect.
2. **CI.**
   - `update_manifest.py` derives pack/binary URLs from `--release-url` (`:78,87-93`). Add a CDN
     base.
   - Add an upload step: `aws s3 cp` with `AWS_ENDPOINT_URL`, like `assets.py:160-169`, or
     wrangler.
   - Upload immutable content-addressed objects first, manifests last.
   - Cache-Control: manifests `no-cache`/short TTL, packs `immutable`.
   - Replace `--clobber` sequencing (1.14 #16). With JWS a single object makes the flip atomic.
3. **Client.**
   - HTTPS with Godot's CA bundle is fine for Cloudflare.
   - R2 supports Range (needed for resume).
   - For private or pre-release feeds, don't reuse `DICEROLL_UPDATE_TOKEN` (env-only, leaks on
     redirect). Use Worker-issued signed URLs or public read with signed manifests.
4. **Other consumers of GitHub URLs:**
   - the AltStore/SideStore source URL users added (`…/channels/altstore-source[-beta].json`);
   - Obtainium tracks GitHub Releases APK assets;
   - the release body text (`release.yml:316`).
   - Keep GitHub Releases as the human-facing download page and the source of truth for these,
     or migrate users explicitly.
5. **Web** lazy packs from R2 on another origin need CORS. Same-origin via a Worker route is
   simpler.
6. **Provenance:** the build manifest and `SHA256SUMS` live on GitHub today. If binaries move to
   R2, sign the checksums (JWS or minisign) so GitHub isn't the trust anchor.

---

## 7. Where the docs disagree with the code

| Doc claim | Reality |
|---|---|
| RELEASE.md:107-108 "Web, itch and Steam builds rely on their platform" | itch and Steam get `github`-stamped self-updaters (`release.yml:424-429,445-450`) |
| RELEASE.md:42 APK "in-game prompt"; :129-131 sideloaded mobile builds show the "sideload" lock reason | APK is `play`, IPA is `appstore`: store prompts and store lock reasons |
| RELEASE.md:88 "Enabled store flows run last" | store jobs depend only on their build jobs (`release.yml:355,379,405,433`) |
| RELEASE.md:204-205 Gradle cache | removed in `865d1cb` |
| ASSETS.md:41 "31 units incl. rendered UI icons, ~28 MB encrypted" | 31 units, **no** rendered-icons unit, 38.6 MB encrypted |
| content-streaming §5.4 "schema 2 … old binaries ignore the new fields" | the validator rejects any schema ≠ 1 |
| content-streaming §1/§12: display-font bug | fixed (`4bb9028`) |
| content-streaming §8.6 AltStore top-level `downloadURL` | not emitted |
| content-streaming §1 "Web, itch, Steam and dev builds never check" | itch and Steam do (see above) |
| content-streaming §2 "73 MB" PCK | 85.3 MB at rc.3 |
