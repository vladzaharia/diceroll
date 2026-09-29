# CI/CD and releases

Everything runs on GitHub Actions in the public repo `vladzaharia/diceroll`. Third-party assets
come from the private repo `vladzaharia/diceroll-assets` as encrypted bundles (docs/ASSETS.md).

## Pipeline overview

```mermaid
flowchart LR
  subgraph PR["pull_request / push main / nightly (ci.yml)"]
    plan[Plan: changed paths, secrets?, matrix] --> static[Static: repo guard, gitleaks,<br/>actionlint, shellcheck, tooling selftest]
    plan --> test[Tests: script check, dice tray,<br/>tests/run.sh, sim smoke 50 runs/class]
    plan --> shots[Screenshots: Xvfb + lavapipe<br/>quick on PRs / sharded full matrix]
    shots --> report[Contact sheet + report-only diff<br/>vs main baseline]
    plan --> smoke[Export smoke: Linux, Windows, Web<br/>(push/nightly)]
  end
  subgraph REL["tag vX.Y.Z / manual (release.yml)"]
    prep[Version + notes:<br/>git-cliff + Claude] --> dw[Linux x64/arm64, Windows,<br/>Web, desktop .pck]
    prep --> and[Android APK + AAB]
    prep --> apple[macOS .dmg/.zip sign+notarize<br/>iOS/iPadOS .ipa + sideload .ipa]
    dw & and & apple --> pub[GitHub Release: files, SHA256SUMS,<br/>build manifest, notes]
    pub --> ch[Rolling release 'channels':<br/>signed updater manifests,<br/>AltStore/SideStore source]
    apple -.ENABLE_APPSTORE.-> tf[TestFlight]
    and -.ENABLE_PLAY.-> play[Play internal track]
    dw -.ENABLE_ITCH.-> itch[itch.io butler]
    dw -.ENABLE_STEAM.-> steam[Steam steamcmd]
  end
  assets[(diceroll-assets<br/>private, age-encrypted<br/>per-unit bundles)] -. deploy key .-> test & shots & dw & and & apple
```

Every job that needs assets uses the composite action `.github/actions/setup-diceroll`: Godot
4.7.2 + export templates (downloaded once, SHA-512 verified, pruned per OS, cached), the asset
bundles (encrypted cache keyed by the lock file, incremental restore), and the headless import
(its `.godot` cache is stored **encrypted** too, since it is derived from the licensed assets).

## Distribution channels

| Channel | Artifact | Updates | Status |
|---|---|---|---|
| GitHub Releases (direct) | `Diceroll-<v>-macos.dmg/.zip`, `-windows-x86_64.zip`, `-linux-x86_64.tar.gz`, `-linux-arm64.tar.gz` | In-game updater: signed content packs (`-desktop.pck`), "new version" prompt for binaries | on |
| Web | `Diceroll-<v>-web.zip` (nothreads build: no COOP/COEP headers needed) | Always the deployed version (host with cache-busting) | on |
| Android APK sideload / Obtainium | `Diceroll-<v>-android.apk` | Obtainium tracks GitHub releases (APK asset per release); in-game prompt | on (debug-signed until a release keystore is set) |
| iOS/iPadOS SideStore / AltStore | `Diceroll-<v>-ios-sideload.ipa` (unsigned; the store app re-signs it) | Source: `https://github.com/vladzaharia/diceroll/releases/download/channels/altstore-source.json` (`-beta.json` for pre-releases) | on |
| TestFlight / App Store | `Diceroll-<v>-ios.ipa` (App Store Connect signed) | App Store; in-game prompt to the store link | `ENABLE_APPSTORE` |
| Play internal → production | `Diceroll-<v>-android.aab` | Play Store (in-app updates API is a future option) | `ENABLE_PLAY` |
| itch.io | web / windows / linux / mac channels via butler | itch app | `ENABLE_ITCH` |
| Steam (incl. Steam Deck) | depots windows / linux / macos | Steam client | `ENABLE_STEAM` |

Per-channel artifacts stay separate files, so content packs per channel can be added later
without changing the release layout (see docs/design/2026-09-29-content-streaming.md).

## Versioning

- SemVer tags `vX.Y.Z`; pre-releases `vX.Y.Z-rc.N` / `-beta.N` (published as GitHub pre-releases
  on the `beta` updater channel; final releases update both `stable` and `beta`).
- `tools/ci/stamp_version.py` writes the version into `project.godot`, the export presets and
  `build_info.json` (version, commit, channel, distribution) at build time; nothing is committed.
- Build number (iOS `CFBundleVersion`, Android `versionCode`) is monotonic across pre-releases:
  `major*1000000 + minor*10000 + patch*100 + (rc number | 99 for final)`, e.g. 0.1.0-rc.1 → 10001,
  0.1.0 → 10099.
- Untagged builds are `<last tag>-dev.<n>`.

## Changelog and release notes

- **Developer changelog**: [git-cliff](https://git-cliff.org) from Conventional Commits
  (`cliff.toml`). Chosen over release-please because releases here are tag-driven by one
  maintainer: git-cliff is a stateless generator that runs inside the tag workflow, needs no
  standing release PR or version files, and handles the Godot project without custom updaters.
  Regenerate `CHANGELOG.md` with `git-cliff -o CHANGELOG.md` (e.g. right before tagging).
- **Player-facing notes**: `tools/ci/changelog_llm.py` sends the release's commit subjects and
  developer changelog to the Anthropic Messages API (`claude-opus-5-5` by default, override with
  the `CHANGELOG_MODEL` env var) with a fixed prompt and a strict JSON schema, then enforces the store
  limits locally: `RELEASE_NOTES.md` (GitHub Release body, developer changelog folded below),
  `store/ios_whats_new.txt` (≤ 4000 chars), `store/android_whats_new.txt` (≤ 500 chars, used by
  the Play upload and the updater manifest). Without `ANTHROPIC_API_KEY`, on any API error or a
  refusal it falls back to a mechanical conversion; a release never blocks on it.
  Local dry run: `tools/ci/changelog_llm.py --version 0.2.0 --dry-run --out /tmp/notes`.

## Cutting a release

1. Make sure `main` is green (CI) and the asset lock is current (`tools/ci/assets.py verify`).
2. Optional: `git-cliff --unreleased --tag v0.2.0` to preview; `git-cliff -o CHANGELOG.md`,
   commit as `docs(changelog): v0.2.0`.
3. Tag and push: `git tag -a v0.2.0 -m "v0.2.0" && git push origin v0.2.0`
   (pre-release: `v0.2.0-rc.1`). Or run **Actions > Release > Run workflow** with a version:
   it creates the tag on publish.
4. The Release workflow builds everything (~25-40 min), publishes the GitHub Release and updates
   the `channels` release (updater manifests + AltStore source). Enabled store flows run last.
5. Check the release page, download one build per OS, verify `sha256sum -c SHA256SUMS.txt`.

Never delete the `channels` release: installed games read their updates from it.

## In-game auto-updates

`game/update/` (autoload `Updater`, first in the autoload list):

- Desktop builds with `distribution: github` check
  `<base>/update-<channel>.json` (+ `.json.sig`) at most every 6 h; base =
  `https://github.com/vladzaharia/diceroll/releases/download/channels`, configurable via the
  project setting `diceroll/update/base_url` (or `DICEROLL_UPDATE_BASE_URL` for testing).
- The manifest is signed with RSA-3072 PKCS#1 v1.5 / SHA-256 (`UPDATE_SIGNING_KEY` secret); the
  game verifies it with the public key in `game/update/update_keys.gd` and the pack by SHA-256.
- Same engine version and a new enough binary → the full content pack (`-desktop.pck`) downloads
  to `user://updates/staged`, and the next launch relaunches the binary with `--main-pack` (so
  scripts, classes and settings all come from the new version). Two failed boots roll back to
  the previous pack. Otherwise (engine changed) the player gets a "new version" download prompt.
- iOS/Android builds only show a "new version in the store" prompt; Web, itch and Steam builds rely
  on their platform. Players can turn automatic checks off in Settings.

## Secrets and variables

Set with `gh secret set NAME -R vladzaharia/diceroll` (or Settings > Secrets and variables >
Actions). Everything except the asset secrets is optional: the matching step is skipped or
falls back.

| Secret | Required for | What it is / how to create |
|---|---|---|
| `ASSETS_AGE_KEY` | tests, screenshots, all builds | age identity (`AGE-SECRET-KEY-1…`) decrypting the asset bundles. Created with `age-keygen`; the maintainer's copy lives in `~/.config/diceroll/asset-bundle.key` (outside the repo). Public half: `tools/ci/assets_recipient.txt`. |
| `ASSETS_DEPLOY_KEY` | same | SSH private key of a **read-only deploy key** on `vladzaharia/diceroll-assets` (`ssh-keygen -t ed25519`, `gh repo deploy-key add key.pub -R vladzaharia/diceroll-assets`). |
| `UPDATE_SIGNING_KEY` | signed updater manifests | RSA private key PEM (`openssl genrsa -out update-signing.pem 3072`); public half in `game/update/update_keys.gd`. Maintainer copy: `~/.config/diceroll/update-signing.pem`. Without it manifests are unsigned and games ignore them. |
| `ANTHROPIC_API_KEY` | Claude release notes | https://console.anthropic.com > API keys. |
| `MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD` | macOS signing | "Developer ID Application" certificate exported from Keychain as .p12, `base64 -i cert.p12`. |
| `APPLE_API_KEY_P8`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID` | notarization, iOS signing, TestFlight | App Store Connect > Users and Access > Integrations > Team Keys: a key with the App Manager (or Admin) role; paste the .p8 file contents, the key id and the issuer id. |
| `APPLE_TEAM_ID` | iOS signing | 10-character team id (developer.apple.com > Membership). With the API key, xcodebuild creates the certificates and profiles automatically (`-allowProvisioningUpdates`); register the bundle id `gg.vlad.diceroll` and create the app record in App Store Connect first. |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` | Android release signing | `keytool -genkeypair -v -keystore diceroll.keystore -alias diceroll -keyalg RSA -keysize 4096 -validity 10000`, then `base64 -i diceroll.keystore`. Keep a backup: Play App Signing needs the same upload key forever. Without it builds use a throwaway debug key. |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play upload | Google Cloud service account with a JSON key, invited in Play Console > Users and permissions with release rights for the app. The first AAB must be uploaded by hand in Play Console. |
| `BUTLER_API_KEY` | itch.io | https://itch.io/user/settings/api-keys |
| `STEAM_USERNAME`, `STEAM_CONFIG_VDF` | Steam | A builder account; run `steamcmd +login <user> +quit` locally (Steam Guard), then `base64 -i ~/Steam/config/config.vdf`. |

| Variable (`gh variable set`) | Effect |
|---|---|
| `ENABLE_APPSTORE` = `true` | upload the signed .ipa to TestFlight |
| `ENABLE_PLAY` = `true` | upload the AAB to Play (`PLAY_TRACK` default `internal`, `PLAY_STATUS` default `draft`) |
| `ENABLE_ITCH` = `true`, `ITCH_TARGET` = `user/game` | butler push |
| `ENABLE_STEAM` = `true`, `STEAM_APP_ID`, `STEAM_BRANCH` (default `beta`) | steamcmd upload (depots 1 windows, 2 linux, 3 macos) |

## First-time setup checklist

- [ ] Public game repo, private assets repo `vladzaharia/diceroll-assets`.
- [ ] Assets: `tools/import_assets.sh`, `tools/ci/assets.py pack`, clone the assets repo,
      `tools/ci/assets.py upload --repo ../diceroll-assets --push`, commit `tools/ci/assets.lock.json`.
- [ ] Read-only deploy key on the assets repo; `ASSETS_DEPLOY_KEY` + `ASSETS_AGE_KEY` secrets.
- [ ] `UPDATE_SIGNING_KEY` secret (matches `game/update/update_keys.gd`).
- [ ] Optional: `ANTHROPIC_API_KEY`; Apple, Android, store secrets and `ENABLE_*` variables as
      each channel goes live.
- [ ] Settings > Actions > General: "Require approval for first-time contributors" (or all
      outside collaborators), workflow permissions read-only by default.
- [ ] Settings > Code security: secret scanning + push protection on.
- [ ] Branch protection on `main` (optional): require the "Static checks", "Scripts, tests,
      balance smoke" and "Conventional Commit title" checks.
- [ ] Keep offline backups of `~/.config/diceroll/` (asset key, update signing key) and the
      Android keystore.

## Local validation

```sh
actionlint                                  # all workflows
shellcheck -S warning tools/*.sh tools/ci/*.sh tools/git-hooks/* tests/run.sh
tools/ci/selftest.sh                        # bundles round trip, versioning, notes, signing
tools/ci/check_repo.sh && gitleaks git --config .gitleaks.toml .
tools/ci/shoot_ci.sh --set=quick --scenarios="game_title" --out=/tmp/shots   # background on macOS
tools/export.sh linux|windows|web|pck|android|android-aab|macos|ios
```

## Cost and runtime notes

- The game repo is public, so standard GitHub-hosted runners are free. The design still keeps
  macOS minutes low (10x the Linux price on private repos): only the release's `apple` job runs
  on macOS; screenshots use Linux software rendering (Mesa lavapipe, Vulkan Forward+: ~45 s for
  the first shot while shaders compile, ~7 s per shot after, shader cache persisted).
- PRs: concurrency cancels superseded runs; docs-only changes skip the heavy jobs; the PR
  screenshot matrix is 3 scenarios x 5 devices. main/nightly: 12 scenarios x 25 devices, one
  shard per scenario.
- Caches: Godot + templates per OS, encrypted asset bundles (incremental via restore-keys),
  encrypted import cache, shader cache, Gradle. Artifacts: shots 7-14 days, baseline 30 days,
  release builds 7 days (the GitHub Release is the permanent copy).
