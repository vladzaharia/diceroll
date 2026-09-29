# Third-party assets

No third-party asset is committed to this repo. All KayKit packs are CC0, but the **EXTRA** tiers and Mystery Monthly are sold by their creator, so everything third-party stays in a private store (licenses: THIRD_PARTY_NOTICES.md).

## Layout
- **`third_party/`** (git-ignored, with a `.gdignore` so Godot doesn't import it) is the canonical store. It holds the original packs:
  - `kaykit/`: all KayKit packs (FREE and EXTRA), as downloaded
  - `music/<source>/`: music beds, one folder per source (`randommind/`, `cynicmusic/`; all CC0 from OpenGameArt), each with its licence text and a `LICENSE-URL.txt` recording the licence page and the date it was checked. Only use music whose licence allows commercial use and redistribution inside a game (prefer CC0).
  - `kenney/`: Kenney CC0 SFX packs
  - `fonts/`: Fredoka and Lilita One (OFL)
  - `tiny_rpg/`: Tiny RPG character sprite packs (currently unused)
- **`assets/kaykit/`, `assets/audio/`, `assets/fonts/`** (git-ignored) are the runtime subsets the game loads. `tools/import_assets.sh` builds them from `third_party/`.
- **`assets/icon/` and `assets/CREDITS.md`** are the project's own files and stay tracked.

## Fresh clone / new machine
1. Put the packs into `third_party/` using the layout above. Extract KayKit downloads into `third_party/kaykit/<PackName>/`.
2. Run `tools/import_assets.sh` (needs `ffmpeg`: it normalises the music to -16 LUFS). From a git worktree, point it at the main checkout's store with `THIRD_PARTY=/path/to/diceroll/third_party`. Add `--fetch` to download the fonts and Kenney SFX into `third_party/` if they're missing.
3. Run `godot --headless --path . --import`.
4. Run `tools/render_icons.sh` to render the "rendered" UI icons (coin pile, chests, gems, potions, key) from the KayKit props into `ui/icons/rendered/*.png`. They derive from paid models, so they are ignored by git like the models. Without them the UI falls back to the vector glyphs.

## Adding assets from a new pack
The optional KayKit EXTRA subsets (ResourceBits, RPGToolsBits, Dungeon, Adventurers potions into `assets/kaykit/resources`, `tools_x`, `dungeon_x`, `potions`) are copied by `xsync` lines and skipped when a pack is absent; the tile props then fall back to the FREE models.

Extend `tools/import_assets.sh` with a `sync` line that copies the needed subset from `third_party/kaykit/<Pack>/...` into `assets/kaykit/<name>/`. Keep runtime subsets lean.

## Missing assets at runtime

`game/boot/asset_check.gd` compares the runtime folders against `tools/ci/assets.lock.json` at
boot (editor/dev runs only; exported builds have the assets baked in, headless tools skip it).
If a unit is missing the game shows "Required game assets are missing" with a link to the README
instead of running with broken scenes; the screenshot harness exits with an `ERROR: Shot:` line.
The game needs every pack in the lock, FREE and EXTRA.

## CI asset bundles

CI never sees `third_party/`. It gets the runtime subsets as **per-unit, content-addressed,
age-encrypted bundles** from the private repo `vladzaharia/diceroll-assets`
(`tools/ci/assets.py`):

- **Unit**: one runtime folder: each `assets/kaykit/<name>`, each `assets/audio/sfx/<pack>`,
  `assets/audio/music`, `assets/fonts`, and the rendered UI icons (31 units, ~28 MB encrypted).
  Runtime subsets are much smaller than the raw packs (~110 MB vs ~800 MB), and Godot's `.import`
  / `.uid` sidecars travel with them so resource UIDs stay stable.
- **Hash**: SHA-256 over the sorted `<relative path>\t<sha256>` lines of the unit's files.
- **Bundle**: `bundles/<unit>/<unit>-<hash16>.tar.zst.age`: deterministic tar, zstd -19, age
  X25519. Encrypting needs only the public recipient (`tools/ci/assets_recipient.txt`);
  decrypting needs the `ASSETS_AGE_KEY` secret.
- **Lock**: `tools/ci/assets.lock.json` (committed; unit names, hashes, sizes only) pins the exact
  asset version for each commit. Old bundles are never deleted from the store, so any past commit
  stays buildable. `manifest.json` in the store lists every bundle ever uploaded.

Updating assets (maintainer):

```sh
tools/import_assets.sh                      # refresh assets/ from third_party/
tools/ci/assets.py units                    # what changed (hash per unit)
tools/ci/assets.py pack                     # encrypt only changed units -> build/asset-bundles, rewrite the lock
git clone git@github.com:vladzaharia/diceroll-assets.git ../diceroll-assets   # once
tools/ci/assets.py upload --repo ../diceroll-assets --push   # commit + push only new bundles
git add tools/ci/assets.lock.json && git commit -m "build(assets): update bundle lock"
```

In CI (`.github/actions/setup-diceroll`): a blobless, depth-1 clone of the assets repo with the
read-only deploy key (`ASSETS_DEPLOY_KEY`) checks out only the bundles missing from the cache;
each is verified (ciphertext SHA-256 from the lock), decrypted, extracted, and verified again
(plaintext unit hash). The Actions cache holds only ciphertext (`.ci-cache/bundles`, keyed by the
lock digest, restoring older caches so only changed units download), and the Godot import cache
is sealed with the same key. Plaintext assets are never uploaded as artifacts or printed.
Fork PRs have no secrets, so asset jobs skip.

Other stores (same bundle layout): `fetch --s3 s3://bucket/prefix` (AWS S3 or Cloudflare R2 via
`AWS_ENDPOINT_URL` + `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`; `upload --s3` to publish), or
`fetch --gh-release owner/repo@tag` (flat release assets on a private repo, `GH_TOKEN` = a
fine-grained PAT with read access to that repo), or `--dir` for a local copy.
