# Third-party notices

Diceroll's code, docs and original art are MIT-licensed (see [LICENSE](LICENSE)). The game also
uses the third-party assets below. **None of them is committed to this repository**: official
builds get them from a private asset store, and forks obtain them from the original sources
(see the README, "Build from source"). Released game builds contain them as part of the game,
which every license below permits.

## 3D models and animations: KayKit by Kay Lousberg

All KayKit packs are licensed **CC0 1.0** (public domain dedication), including the paid EXTRA
tiers and the Mystery Monthly series. The EXTRA packs are sold by the creator; please buy them
to support Kay rather than copying them from someone else. Website: https://kaylousberg.com ·
store: https://kaylousberg.itch.io

| Pack | Tier | Where to get it |
|---|---|---|
| Character Pack: Adventurers 2.0 | FREE + EXTRA | https://kaylousberg.itch.io/kaykit-adventurers |
| Character Animations 1.1 | FREE | https://kaylousberg.itch.io/kaykit-character-animations |
| Character Pack: Skeletons 1.1 | FREE + EXTRA | https://kaylousberg.itch.io/kaykit-skeletons |
| Character Pack: Mystery Monthly Series 4 | paid | https://kaylousberg.itch.io/kaykit-series-4 |
| Dungeon Pack 1.1 (Remastered) | FREE + EXTRA | https://kaylousberg.itch.io/kaykit-dungeon-pack |
| Forest Nature Pack 1.0 | EXTRA | https://kaylousberg.itch.io/kaykit-forest |
| Resource Bits 1.0 | FREE + EXTRA | https://kaylousberg.itch.io/resource-bits |
| RPG Tools Bits 1.0 | FREE + EXTRA | https://kaylousberg.itch.io/rpg-tools-bits |
| Fantasy Weapons Bits 1.0 | FREE + EXTRA | https://kaylousberg.itch.io/fantasy-weapons-bits |
| Board Game Bits 1.0 | FREE | https://kaylousberg.itch.io/board-game-bits |
| Block Bits 1.0 | FREE | https://kaylousberg.itch.io/block-bits |
| Halloween Bits 1.0 | FREE | https://kaylousberg.itch.io/halloween-bits |
| Platformer Pack 1.0 | FREE | https://kaylousberg.itch.io/kaykit-platformer |

The exact subsets the game uses are defined in `tools/import_assets.sh`; `assets/CREDITS.md`
maps each runtime folder to its pack.

## UI art: RhosGFX

Vector UI and icon packs by RhosGFX, https://rhosgfx.itch.io. Credit is appreciated by the
author, so here it is, with thanks. The game ships only the SVGs it references
(`tools/import_ui_svgs.py`).

| Pack | Licence | Where to get it |
|---|---|---|
| Cartoony UI Pack (Full) | RhosGFX licence: use and modify in projects; no resale or redistribution of the assets | https://rhosgfx.itch.io/cartoony-ui-pack |
| Vector Icon Pack (Pro) | RhosGFX licence (same terms) | https://rhosgfx.itch.io |
| Vector Hats | RhosGFX licence, https://rhosgfx.com/license | https://rhosgfx.itch.io |
| Vector Keyboard Controls | CC0 1.0 | https://rhosgfx.itch.io |
| Vector Emojis | CC0 1.0 | https://rhosgfx.itch.io |

The paid packs are not in this repository. The licence's clause on AI use, and the owner's
2026-09-30 decision about it, are recorded in `docs/ASSETS.md`.

## 3D models: Quaternius (CC0 1.0)

Ultimate Platformer Pack by Quaternius, https://quaternius.com. CC0 1.0 (public domain
dedication). Not committed; kept with the other third-party packs.

## Sound effects: Kenney (CC0 1.0)

https://kenney.nl · [Casino Audio](https://kenney.nl/assets/casino-audio),
[RPG Audio](https://kenney.nl/assets/rpg-audio),
[Impact Sounds](https://kenney.nl/assets/impact-sounds),
[Interface Sounds](https://kenney.nl/assets/interface-sounds),
[Music Jingles](https://kenney.nl/assets/music-jingles) (4 jingles),
[Digital Audio](https://kenney.nl/assets/digital-audio) (4 sounds).

## Music (CC0 1.0, OpenGameArt)

By RandomMind and cynicmusic, dedicated to the public domain under CC0 1.0
(https://creativecommons.org/publicdomain/zero/1.0/); licence pages checked 2026-09-29.
Re-encoded (silence trimmed, loudness normalized) by `tools/import_assets.sh`. Credited with thanks:

| track | used for |
|---|---|
| [Medieval: The Bard's Tale (loop)](https://opengameart.org/content/medieval-the-bards-tale) | title |
| [Medieval: The Old Tower Inn (loop)](https://opengameart.org/content/medieval-the-old-tower-inn) | camp / calm |
| [Medieval: Harvest Season](https://opengameart.org/content/medieval-harvest-season) | glade |
| [Fantasy: Lament for a Warrior's Soul](https://opengameart.org/content/fantasy-lament-for-a-warriors-soul) | crypt |
| [Fantasy: Rising Moon](https://opengameart.org/content/fantasy-rising-moon) | frost |
| [Medieval: Battle](https://opengameart.org/content/medieval-battle) | throne |
| [Dark Forest Theme](https://opengameart.org/content/dark-forest-theme) | hollow |
| [Battle Theme B for RPG](https://opengameart.org/content/battle-theme-b-for-rpg) | magma |
| [Battle Theme A](https://opengameart.org/content/battle-theme-a) | boss |

## Fonts (SIL Open Font License 1.1)

- Fredoka: https://fonts.google.com/specimen/Fredoka
- Lilita One: https://fonts.google.com/specimen/Lilita+One

The OFL allows bundling and redistribution with the license text; they are kept out of the
repository only to keep all third-party files in one place.

## Godot Engine (MIT)

Diceroll is built with [Godot Engine](https://godotengine.org) 4.7.2, © 2014-present Godot Engine
contributors, © 2007-2014 Juan Linietsky, Ariel Manzur, MIT license. Exported builds also contain
Godot's third-party components (FreeType, HarfBuzz, ICU, mbedTLS, Vulkan loader/MoltenVK, zstd,
and others) under their own permissive licenses: see
https://godotengine.org/license and `Engine.get_copyright_info()` / `Engine.get_license_info()`.

## Build tooling

GitHub Actions, git-cliff, age, zstd, gitleaks, actionlint and shellcheck are used by the CI
pipeline only and are not shipped.
