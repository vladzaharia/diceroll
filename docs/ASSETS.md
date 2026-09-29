# Third-party assets

No third-party asset is committed to this repo. Some packs, the KayKit **EXTRA** tier, are paid and not redistributable.

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
