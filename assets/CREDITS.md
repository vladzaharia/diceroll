# Asset credits

Everything under `assets/` except `icon/` is produced by `tools/import_assets.sh` from the
git-ignored `third_party/` store (see docs/ASSETS.md; `--fetch` downloads fonts and Kenney audio). Each pack folder keeps its
original license file.

## 3D models and animations: KayKit by Kay Lousberg (CC0 1.0)

https://kaylousberg.com · License files: `assets/kaykit/*/License.txt`

| Folder | Source pack | Contents |
|---|---|---|
| `kaykit/adventurers/characters` | KayKit Adventurers 2.0 FREE | Knight, Barbarian, Mage, Ranger, Rogue, Rogue_Hooded (GLB, textures embedded) |
| `kaykit/adventurers/weapons` | KayKit Adventurers 2.0 FREE | class weapons/shields (glTF) |
| `kaykit/animations/rig_medium`, `rig_large` | KayKit Character Animations 1.1 | animation clip GLBs |
| `kaykit/animations/mannequins` | KayKit Character Animations 1.1 | Mannequin_Medium, Mannequin_Large |
| `kaykit/boardgame` | KayKit BoardGameBits 1.0 FREE | tiles, dice, coins, tokens (class-badge tiles/cards omitted for size) |
| `kaykit/dungeon` | KayKit Dungeon Pack 1.1 FREE | full glTF set |
| `kaykit/halloween` | KayKit Halloween Bits 1.0 FREE | full glTF set |
| `kaykit/weapons` | KayKit Fantasy Weapons Bits 1.0 FREE | full glTF set |
| `kaykit/tools` | KayKit RPG Tools Bits 1.0 FREE | full glTF set (anvil, map, journal...) |
| `kaykit/platformer/{yellow,red,blue}` | KayKit Platformer Pack 1.0 FREE | star, heart, diamond pickups only |

## Sound effects: Kenney (CC0 1.0)

https://kenney.nl · License files: `assets/audio/sfx/*/License.txt`
Downloaded 2026-09-28 from the kenney.nl asset pages: Casino Audio, RPG Audio, Impact Sounds,
Interface Sounds (complete .ogg sets), Music Jingles (4 jingles) and Digital Audio (4 sounds).

## Music: OpenGameArt (CC0 1.0)

All nine beds are dedicated to the public domain under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/), so they may be used, modified and
redistributed in a commercial game with no attribution required. We credit the composers anyway.
Licences checked 2026-09-29 on each OpenGameArt page (License(s): CC0). `tools/import_assets.sh`
trims leading/trailing silence from the full-length tracks, normalises each to -16 LUFS
integrated (-1.5 dBTP) and encodes LAME VBR MP3. Originals, the CC0 legal code and a
`LICENSE-URL.txt` live in `third_party/music/{randommind,cynicmusic}/`.

| id | File | Track | Composer | Source |
|---|---|---|---|---|
| title | `bards-tale.mp3` | Medieval: The Bard's Tale (loop) | RandomMind | https://opengameart.org/content/medieval-the-bards-tale |
| calm (camp, events) | `old-tower-inn.mp3` | Medieval: The Old Tower Inn (loop) | RandomMind | https://opengameart.org/content/medieval-the-old-tower-inn |
| glade | `harvest-season.mp3` | Medieval: Harvest Season | RandomMind | https://opengameart.org/content/medieval-harvest-season |
| crypt, act1 | `lament-for-a-warriors-soul.mp3` | Fantasy: Lament for a Warrior's Soul | RandomMind | https://opengameart.org/content/fantasy-lament-for-a-warriors-soul |
| hollow, act2 | `dark-forest.mp3` | Dark Forest Theme | cynicmusic (The Cynic Project) | https://opengameart.org/content/dark-forest-theme |
| frost | `rising-moon.mp3` | Fantasy: Rising Moon | RandomMind | https://opengameart.org/content/fantasy-rising-moon |
| throne, act3 | `medieval-battle.mp3` | Medieval: Battle | RandomMind | https://opengameart.org/content/medieval-battle |
| magma | `battle-theme-b.mp3` | Battle Theme B for RPG | cynicmusic (The Cynic Project) | https://opengameart.org/content/battle-theme-b-for-rpg |
| boss | `battle-theme-a.mp3` | Battle Theme A | cynicmusic (The Cynic Project) | https://opengameart.org/content/battle-theme-a |

## Fonts (SIL Open Font License 1.1)

From https://github.com/google/fonts (license texts next to the fonts):
- Fredoka (variable, wdth+wght), The Fredoka Project Authors: `fonts/Fredoka-Variable.ttf`, `fonts/OFL-Fredoka.txt`
- Lilita One by Juan Montoreano: `fonts/LilitaOne-Regular.ttf`, `fonts/OFL-LilitaOne.txt`

## UI art: RhosGFX (https://rhosgfx.itch.io)

Only the SVGs referenced by `ui/icons/icon_map.json` and `ui/theme/ui_pack.json` are copied here
(`tools/import_ui_svgs.py`). Thanks to RhosGFX. Please support the packs at https://rhosgfx.itch.io.

| Folder | Source pack | Licence |
|---|---|---|
| ui/pack/cartoony-ui-pack-full | Cartoony UI Pack (Full), https://rhosgfx.itch.io/cartoony-ui-pack | RhosGFX licence (paid; no redistribution) |
| ui/icons/vector-icon-pack-pro | Vector Icon Pack Pro, https://rhosgfx.itch.io | RhosGFX licence (paid; no redistribution) |
| ui/icons/vector-keyboard-controls | Vector Keyboard Controls, https://rhosgfx.itch.io | CC0 1.0 |
| ui/icons/vector-emojis | Vector Emojis, https://rhosgfx.itch.io | CC0 1.0 |
| ui/icons/vector-hats | Vector Hats, https://rhosgfx.itch.io | RhosGFX licence |

## 3D models: Quaternius (CC0 1.0)

Ultimate Platformer Pack by Quaternius (https://quaternius.com), CC0 1.0. Kept in
`third_party/quaternius/`, and not used at runtime yet.
