# Asset inventory (local downloads) for the 3D dice-roguelite board game

Generated 2026-09-28. All paths are relative to the folder the packs were downloaded to.
Verified by parsing glTF/GLB JSON with a python script (bone names, animation names, accessor bounds, image URIs).

## TL;DR / key findings

1. **glTF is `.gltf` + `.bin` + `.png` triplets** for all prop packs (`Assets/gltf/`); **characters and animations are single `.glb`** files. FBX/OBJ are also shipped (`Assets/fbx`, `Assets/fbx(unity)`, `Assets/obj`) but glTF is the one to use for web/Three.js/Godot.
2. **Dice exist only in BoardGameBits**: D4/D6/D8/D20 in 4 colours. `D6_A`/`D6_B` have **real geometry pips** (indented dots, coloured by the shared atlas), `D6_C`, D4, D8, D20 use a **numeral texture** (`dice_<colour>.png`). There is **no D10/D12**.
3. **No hex tiles anywhere.** Square tiles only: BoardGameBits `tile_*` (1x1 x 0.2 slab), Dungeon `floor_tile_*` (2x2 / 4x4), Halloween `floor_dirt*`/`path_*`, Platformer `platform_*`, BlockBits cubes (2x2x2). For a looping board, square/ring layout is straightforward; hex would need custom geometry.
4. **KayKit Adventurers characters ship with ZERO animations embedded** (`animations: 0` in all 6 GLBs). Animations live in separate `Rig_Medium_*.glb` files. **Rig is 100% compatible**: all 6 Adventurers characters + `Mannequin_Large` have an identical 23-bone skeleton (`root, hips, spine, chest, upperarm.l/r, lowerarm.l/r, wrist.l/r, hand.l/r, handslot.l/r, head, upperleg.l/r, lowerleg.l/r, foot.l/r, toes.l/r`); `Mannequin_Medium` has the same minus `handslot.l/r` (21 bones). Every animation GLB carries the same 23-bone skeleton, so retargeting is by bone name (no remap needed in Three.js `AnimationMixer` or Godot `AnimationPlayer` import).
5. **No 3D skeleton/monster models exist in these packs** (Dungeon Pack 1.1 FREE and Halloween Bits contain props/environment only; `Skeletons_*` animation clips exist in `Rig_Medium_Special.glb` but there is no skeleton mesh). 3D enemies must come from: recolored/re-hatted Adventurers + Mannequin, 2D billboard sprites from the two Tiny RPG packs (which do have skeletons, orcs, demons, slimes, bosses), or new assets. **Big decision for the design doc.**
6. **Shared atlas**: every KayKit pack uses ONE small (~1024x1024, 20-40 KB) gradient-swatch atlas PNG per pack; models reference it through UVs pointing at flat colour columns (vertical gradient per swatch). Trivial to batch/instance (one material per pack) and to recolour by editing the PNG.
7. **Licenses**: all 9 KayKit packs are **CC0** (no attribution needed). The Tiny RPG packs ship **no license file** (see section 11); treat as "verify before shipping".
8. No sound effects were found. There are 8 `mixkit-*.mp3` music beds and a few fonts (all OFL) — see section 12.
9. Older Diceroll prototype builds also sit in Downloads (`diceroll-build-1`, `diceroll-build-2`, `build5` — Godot 4.7.2 projects + web exports; `board-overview.png`, `board-play.png` screenshots). Not assets, but may be worth a look for prior decisions.

---

## 0. Texture atlas / material setup (applies to all KayKit packs)

- Each pack has one atlas: e.g. `KayKit_BoardGameBits_1.0_FREE/Textures/boardgame_bits_texture.png` (1024x1024, 36 KB). Layout (seen by reading the PNG): top 2 rows = 16 vertical-gradient swatches (black, grey, white, blue, red, orange/yellow, green, magenta / orange, ice-blue, gold, brown, tan..., cream); bottom half is gradient ramps "reserved for future additions" (you may add colours there).
- glTF files reference the atlas as a relative URI (e.g. `"uri": "boardgame_bits_texture.png"`), and **the png is copied next to the .gltf** in `Assets/gltf/` (Platformer: inside each colour folder). Copy the `.gltf` + `.bin` + png together, or embed/convert to GLB (`gltf-transform`/`gltfpack`) when bundling.
- Materials: single material per model (`boardgame`, `dungeon`...); a few have extra materials (`boardgame_metallic` for coins, `glass` for the hourglass, per-badge material for `tile_<class>_<colour>`/`playercard_*` using `<Colour>_<Class>_Badge.png`, 520x620, ~350 KB each).
- Characters: each has its OWN atlas (`knight_texture.png`, `barbarian_texture.png`, `mage_texture.png`, `ranger_texture.png`, `rogue_texture.png`; Mannequin: `mannequin_texture.png`). Weapons in Adventurers reuse the class atlas (sword_1handed -> `knight_texture.png`, dagger/smokebomb -> `rogue_texture.png`, staff/spellbook -> `mage_texture.png`, mug -> `barbarian_texture.png`).
- Scale: 1 unit ~= 1 metre-ish. Characters are ~2.5 units tall (Knight helmet top y=2.54). Dungeon floors are 4x4 / 2x2; BoardGameBits tiles are 1x1, dice 0.75 cube, coins ~1.04 diameter (large relative to tiles, scale to taste). **Packs are not mutually scale-consistent** — BoardGameBits (1 unit tile) vs character (2.5 tall) means the hero is 2.5x taller than a tile; either scale the hero to ~0.35 or use Dungeon 4x4 floor tiles / scaled-up board tiles (x3-4) as the board.
- File size (gltf dirs): BoardGameBits 10 MB (of which ~9 MB = 25 badge PNGs, models are ~2.7 MB total), Dungeon 6.3 MB, Platformer 6.5 MB, BlockBits 1.8 MB, Halloween 1.5 MB, Weapons 1.3 MB, Tools 1.3 MB.

---

## 1. KayKit_Adventurers_2.0_FREE (22 MB) — HERO CHARACTERS

License: CC0 (`KayKit_Adventurers_2.0_FREE/License.txt`). Creation 22/10/2025.

Layout:
```
Characters/gltf/{Barbarian,Knight,Mage,Ranger,Rogue,Rogue_Hooded}.glb  + 5 atlas pngs
Characters/fbx/*.fbx
Assets/gltf/*.gltf|bin  (weapons/accessories, 67 files), Assets/fbx, Assets/fbx(unity), Assets/obj
Animations/gltf/Rig_Medium/{Rig_Medium_General,Rig_Medium_MovementBasic}.glb   (+ Animations/fbx)
Textures/{barbarian,knight,mage,ranger,rogue}_texture.png
Samples/*.png (includes druid.png/engineer.png = NOT in the FREE pack), contents.png
```
Characters (single GLB, skinned, 23 bones, 330-470 KB each, **no embedded animations**), separate meshes per body part (Body, Head, ArmLeft/Right, LegLeft/Right, Cape, Hat/Helmet...) -> easy to hide/show gear:
| File | Look | Use |
|---|---|---|
| `Characters/gltf/Knight.glb` | armored helmet, red cape | tanky hero / fighter class |
| `Characters/gltf/Barbarian.glb` | bear-hat, beard | berserker hero, also a brute enemy |
| `Characters/gltf/Ranger.glb` | green cloak, brown hair (has `Ranger_Quiver` mesh) | ranger hero |
| `Characters/gltf/Rogue.glb` | blue scarf, brown hair | rogue hero |
| `Characters/gltf/Rogue_Hooded.glb` | hood + mask | rogue alt / bandit enemy / shopkeeper |
| `Characters/gltf/Mage.glb` | wizard hat, purple robe | mage hero, cultist-type enemy (recolour atlas) |

Bone attach points: `handslot.l` / `handslot.r` for weapons.

Weapons/props in `Assets/gltf/`: `sword_1handed`, `sword_2handed`(+`_color`), `dagger`, `axe_1handed`, `axe_2handed`, `bow`, `bow_withString`, `crossbow_1handed/2handed`, `arrow_bow`, `arrow_bow_bundle`, `arrow_crossbow(_bundle)`, `quiver`, `staff`, `wand`, `spellbook_open/closed`, `shield_badge/round/round_barbarian/spikes/square` (+`_color`), `mug_empty/full`, `smokebomb`.

Animations bundled here: `Rig_Medium_General.glb` (Death_A/B, Hit_A/B, Idle_A/B, Interact, PickUp, Spawn_Air/Ground, Throw, Use_Item + T-Pose + *_Pose) and `Rig_Medium_MovementBasic.glb` (Walking_A/B/C, Running_A/B, Jump_*). Identical to the copies in the Animations pack, which has the rest.

## 2. KayKit_Character_Animations_1.1 (41 MB) — ANIMATIONS (for Adventurers)

License: CC0. Creation 10/12/2025.
```
Animations/gltf/Rig_Medium/*.glb   (8 files, 0.67-1.4 MB each)   <- USE THIS with Adventurers
Animations/gltf/Rig_Large/*.glb    (6 files, 0.56-1.0 MB each)   <- big characters (Mannequin_Large, ogres)
Animations/fbx/...
Mannequin Character/characters/{Mannequin_Medium,Mannequin_Large}.{glb,fbx}   + Textures/mannequin_texture.png
```
Each animation GLB contains the skeleton (23 bones, names identical to Adventurers) and the clips only (no meshes to speak of). **Load character GLB + animation GLB(s), take clips from the latter, and bind by bone name.** (Verified: bone set of Knight.glb == bone set of every `Rig_Medium_*.glb`.)

Clips actually present (verified):
- `Rig_Medium_General`: Idle_A, Idle_B, Hit_A, Hit_B, Death_A, Death_B, Death_A_Pose, Death_B_Pose, Interact, PickUp, Throw, Use_Item, Spawn_Air, Spawn_Ground, T-Pose
- `Rig_Medium_MovementBasic`: Walking_A, Walking_B, Walking_C, Running_A, Running_B, Jump_Start, Jump_Idle, Jump_Land, Jump_Full_Short, Jump_Full_Long, T-Pose
- `Rig_Medium_MovementAdvanced`: Crawling, Crouching, Sneaking, Dodge_Forward/Backward/Left/Right, Running_Strafe_Left/Right, Walking_Backwards, Running_HoldingBow, Running_HoldingRifle
- `Rig_Medium_CombatMelee` (22): Melee_1H_Attack_Chop / Slice_Horizontal / Slice_Diagonal / Stab / Jump_Chop, Melee_2H_Attack_Chop / Slice / Spin / Spinning / Stab, Melee_2H_Idle, Melee_Dualwield_Attack_Chop/Slice/Stab, Melee_Unarmed_Attack_Kick / Punch_A, Melee_Unarmed_Idle, Melee_Block, Melee_Blocking, Melee_Block_Attack, Melee_Block_Hit
- `Rig_Medium_CombatRanged` (20): Ranged_Bow_Draw / Release / Aiming_Idle / Idle (+_Up), Ranged_1H/2H_Shoot / Shooting / Aiming / Reload, Ranged_Magic_Raise / Shoot / Spellcasting / Spellcasting_Long / Summon
- `Rig_Medium_Simulation`: **Cheering**, Waving, Sit_Chair_*, Sit_Floor_*, Lie_*, Push_Ups, Sit_Ups
- `Rig_Medium_Tools`: Lockpick, Lockpicking, Chop, Dig, Hammer, Pickaxe, Saw, Fishing_*, Holding_A/B/C, Work_A/B/C ... (29) — chest opening = `Lockpicking`/`Interact`, shop = `Holding_*`/`Use_Item`
- `Rig_Medium_Special`: Skeletons_Awaken_Floor / _Standing, Skeletons_Death, Skeletons_Death_Resurrect, Skeletons_Idle, Skeletons_Spawn_Ground, Skeletons_Taunt(_Longer), Skeletons_Walking, Skeletons_*_Pose, EXPERIMENTAL_Medium_Transform (usable on any Rig_Medium mesh, e.g. re-skinned Mannequin as an undead)
- `Rig_Large_*` (Mannequin_Large rig, same bone names): General (Idle_A/B, Hit_A, Death_A), MovementBasic (Walking_A, Running_A), MovementAdvanced (Dodge_*), CombatMelee (Melee_1H_Slash/Stab, Melee_2H_Attack/Slam, Melee_Unarmed_Punch/Kick/Smash, Dualwield, Block*), Simulation (Flexing), Special (EXPERIMENTAL_Large_Transform)

Mapping to our needs: **idle** Idle_A/B; **walk** Walking_A (board-step) / Running_A; **attack** Melee_1H_Attack_Chop/Slice_*, Ranged_Bow_Release, Ranged_Magic_Shoot/Spellcasting; **hit** Hit_A/B; **die** Death_A/B; **cheer** Cheering; **spawn** Spawn_Ground; **open chest** Interact / Lockpicking; **shop** Use_Item / PickUp.
Mannequin files: `Mannequin Character/characters/Mannequin_Medium.glb` (410 KB, 21 bones) and `Mannequin_Large.glb` (529 KB, 23 bones): grey T-pose dummies with `mannequin_texture.png` — useful as a base for enemy re-skins.

## 3. KayKit_BoardGameBits_1.0_FREE (45 MB) — BOARD, DICE, COINS, TOKENS

License: CC0. Creation 28/04/2026. Formats: glTF (349 files = 162 gltf + 162 bin + 25 png), FBX (187), OBJ.
Layout: `Assets/gltf/*` flat, `Assets/fbx`, `Assets/fbx(unity)`, `Assets/obj`, `Textures/boardgame_bits_texture.png`.

**Dice (in `Assets/gltf/`)** — sizes are bounding-box extents:
- `D6_A[_red|_blue|_green|_yellow].gltf` (also plain `D6_A.gltf` = white): 0.75 cube, ~660 tris, **pips are real geometry** (dimples), colour via the shared atlas (`boardgame_bits_texture.png`). No numerals; face values are decided by orientation. `D6_B*` same idea, 740 tris (slightly different pip style/edge bevel; plain `D6_B` exists).
- `D6_C_{red,blue,green,yellow}.gltf` (no plain version): 0.75 cube, 188 tris, **textured** with `dice_<colour>.png` (numerals 1-6 in the top row of a 1024 sheet). Verified face->value mapping in glTF local axes (Y up): **+Z=1, -Y=2, -X=3, +X=4, +Y=5, -Z=6** (opposites sum to 7). Easy to re-texture to custom faces (symbols/effects) since UVs are a simple 8-cell row.
- `D4_*`, `D8_*`, `D20_*` (4 colours each): 52 / 104 / 260 tris, numeral-textured with the same `dice_<colour>.png` sheet (rows: D4 corner numerals, D8 1-8, D20 1-20). No D10/D12.
- Sizes ~0.75 (D6), 1.0 (D8), ~0.9 (D4/D20).
- Extras: `cube_{red,blue,green,yellow,gold,silver,copper}` (0.5 cubes; poker-chip-esque), `domino_tile_a-b` (28 dominoes 0-0..6-6, 1x2 slab, geometry pips).

**Board tiles**: 1 x 0.2 x 1 slabs, 140 tris (chunky rounded plates):
- `tile_{red,blue,green,yellow,purple}.gltf` — plain coloured tiles (**best base for fight/shop/chest/event/start tile colour coding**).
- `tile_{barbarian,knight,mage,rogue}_{red,blue,green,yellow}.gltf` — tiles with a character-portrait badge (16), and `tile_skeleton_{brute,mage,minion,rogue}.gltf` (4) — **skeleton-enemy portrait tiles; usable as "enemy encounter" tile markers**. Badge PNGs in the same folder (`Red_Knight_Badge.png`, `Skeleton_Minion.png`...).
- `token_{red,blue,green,yellow}` (1.08 x 0.1 x 1.08 flat disc, player token), `playerstand[_colour]` + `playercard_<class>_<colour>` (cards 1.2x1.5x0.1 with portrait; standees), `pawn_A/B_<colour>` (0.5 x 0.9 pawns; hero board-token option), `meeple_<colour>` (1.0 x 1.24), `flag_A/B_<colour>` (start/goal marker), `building_<colour>` (house marker, could mark shop), `hourglass`, `hourglass_empty` (timer, 1 x 2.5 x 1), `container_A/B/C` (+`_tall`; 2.4-4 wide tray/box, "dice tray"/dice-tower base candidate; `container_C` is the translucent glass-look tray with no texture image).
- **Coins**: `coin_{gold,silver,copper}` and denominations `coin_{1,2,5,10}_{gold,silver,copper}` (metallic material; numbers embossed; 320-660 tris, 1.04 dia x 0.2 thick).

## 4. KayKit_Dungeon_Pack_1.1_FREE (52 MB) — CHESTS, FLOORS, DECOR (props only, no characters)

License: CC0. Creation 16/07/2026. `Assets/gltf/` (211 gltf + 211 bin + `dungeon_texture.png`), also fbx, obj; `Assets/textures/dungeon_texture.png` (1024^2). Samples: `Samples/Dungeon_sample*.png`, `contents.png`. **No monsters/skeletons.**
Key models (extents x,y,z):
- **Chests/loot**: `chest.gltf` (1.7x0.97x1.91, closed), `chest_gold.gltf` (1.7x1.21x1.91, gilded; 1568 tris), `coin` (0.36 dia), `coin_stack_small/medium/large`, `key`, `keyring`, `keyring_hanging`, `sword_shield`, `sword_shield_gold`, `sword_shield_broken` (wall trophies/shop signs), `box_small/large/stacked`, `crates_stacked`, `trunk_small/medium/large_{A,B,C}` (treasure trunks), `barrel_small/large/decorated/stack`, `keg`, `bottle_{A,B,C}_{brown,green}` (potions -> shop items), `candle*`, `torch`, `torch_lit`, `torch_mounted`, `plate*`, `table_*`, `chair`, `stool`, `bed_*`, `shelf_*`, `shelves` (**shop counter dressing**), `banner_*` (6 colours x patterns; shop/fight/event tile flags, 1.5x3.2).
- **Floors (square)**: `floor_tile_large` 4x0.15x4, `floor_tile_small` 2x2, `floor_tile_small_{corner,broken_A/B,decorated,weeds_A/B}`, `floor_tile_grate(_open)`, `floor_tile_big_grate(_open)`, `floor_tile_extralarge_grates(_open)`, **`floor_tile_big_spikes`** (4x2.1x4 trap tile -> hazard event), `floor_dirt_large/small_*`, `floor_wood_large/small(_dark)`, `floor_foundation_*` (edges for a raised platform), `rubble_*`.
- **Walls/architecture**: `wall*` (4x4x1; doorway, arched, window, gated, cracked, T-split, corner, endcap...), `column`, `pillar(_decorated)`, `stairs*` (many), `barrier*`, `ceiling_tile`.
- Good for a "dungeon-themed room around the board" or a modular biome; the 4x4 `floor_tile_large` can serve directly as an oversize board tile.

## 5. KayKit_HalloweenBits_1.0_FREE (9.9 MB) — GRAVEYARD BIOME DECOR

License: CC0. Creation 06/10/2023. `Assets/gltf/` 63 gltf + `halloweenbits_texture.png`. Colour scheme: grey stone, orange/yellow pines and pumpkins.
Models: `crypt` (6x8x8 large mausoleum; boss lair), `arch`, `arch_gate`, `fence*` (4x2.2 sections, broken variants, pillar, gate), `gravestone`, `grave_A/B`, `grave_A_destroyed`, `gravemarker_A/B`, `coffin`, `coffin_decorated`, `skull`, `skull_candle`, `ribcage`, `bone_A/B/C`, `shrine`, `shrine_candles`, `plaque`, `pumpkin_{orange,yellow}[_small][_jackolantern]`, `tree_pine_{orange,yellow}_{small,medium,large}` (large 4.8x7.5), `tree_dead_{small,medium,large}(_decorated)`, `post`, `post_lantern`, `post_skull`, `lantern_hanging`, `lantern_standing`, `bench(_decorated)`, `candle*`, `pillar`, ground: `floor_dirt` 4x4x0.53, `floor_dirt_small` 2x2, `floor_dirt_grave` (open-grave floor block), `path_A-D` (~1.9 flat stone path pieces, 0.1 thick).
Use: graveyard biome around the board, bone/skull props for fight tiles (skeleton flavor without skeleton models), pumpkins as event/reward props. **No skeleton characters** (bones/skull/ribcage are static props).

## 6. KayKit_BlockBits_1.0_FREE (10 MB) — CUBE TERRAIN

License: CC0. Creation 27/03/2025. `Assets/gltf/` 40 gltf + `block_bits_texture.png`. All ~2x2x2 cubes: `grass`, `grass_with_snow`, `dirt`, `dirt_with_grass/snow`, `sand_A/B`, `sand_with_grass/snow`, `gravel*`, `snow`, `stone`, `stone_dark`, `stone_with_{copper,gold,silver}`, `bricks_A/B`, `wood`, `metal`, `glass`, `water` (2x2.23x2, wavy top), `lava` (2076 tris), `tree`, `tree_with_snow`, `colored_block_*`, `decorative_block_*`, `striped_block_*` (red/green/blue/yellow), `prototype` (grey-box).
Use: an island/diorama base under the board (water ring, lava biome, sand, snow), looks like the "sample.png" island. Also `colored_block_*` are cheap coloured tile stand-ins. Low priority for gameplay.

## 7. KayKit_Platformer_Pack_1.0_FREE (46 MB) — SQUARE PLATFORMS, COLLECTIBLES

License: CC0. Creation 10/03/2025. `Assets/gltf/<colour>/` where colour = `blue|green|red|yellow` (167 files each, ~83 models) and `neutral/` (77 files, ~38 models, uncoloured: `ball, barrier_*, bomb, cone, floor_wood_*, pillar_*, platform_wood_1x1x1, sign, signage_*, spring, structure_A/B/C, strut_*`). Texture `platformer_texture.png` is in each folder; `Textures/platformer_texture.png`.
Models per colour (`<name>_<colour>.gltf`): `platform_1x1x1 ... platform_6x6x4` (heights 1/2/4, sizes 1,2x2,4x2,4x4,6x2,6x6 — plain square blocks with rounded coloured top and grey side; `platform_1x1x1_blue` is 1x1x1), `platform_slope_*`, `platform_arrow_*`, `platform_hole_6x6x1`, `platform_decorative_*`, `star`, `heart`, `diamond` (pickup collectibles, ~1.1 units; star/heart/diamond for events/relics), `flag_A/B/C` (goal flag), `spring_pad`, `hoop`/`hoop_angled` (loop rings), `pipe_*` (mario-style pipes; teleport tile), `bomb_A/B`, `power` (lightning), `button_base`, `lever_*`, `railing_*`, `arch*`, `signage_arrow_*`, `ball`, `cone`.
Use: 4 colour-coded square tile bases in a bright, toy-like palette (`platform_1x1x1_<colour>` as tile of 4 types!), plus star/heart/diamond pickups. Note style is glossier/candy vs the Dungeon look, but mixes OK with BoardGameBits.

## 8. KayKit_FantasyWeaponsBits_1.0_FREE (6.3 MB) — WEAPONS

License: CC0. Creation 19/02/2026. `Assets/gltf/` 31 gltf + `weapons_bits_texture.png`.
`sword_A-E`, `dagger_A/B`, `axe_A/B/C`, `hammer_A/B/C`, `halberd`, `spear_A`, `staff_A/B`, `wand_A`, `bow_A/B(+_withString)`, `arrow_A/B`, `shield_A/B/C`, `fistweapon_A/B(+_stacked)` (claws/knuckles). ~1.1-2.2 units tall (`sword_A` 0.61x1.77x0.13). Use: hand-slot attachments (`handslot.r`/`.l`), item/relic icons, loot props (a weapon shop). The Adventurers pack has more class-matched weapons already.

## 9. KayKit_RPGToolsBits_1.0_FREE (7.4 MB) — TOOLS / QUEST PROPS

License: CC0. Creation 26/11/2025. `Assets/gltf/` 49 gltf + 4 pngs (`tools_bits_texture.png`, plus `tools_bits_map.png`, `_map_empty.png`, `_blueprint.png` used by `map*`, `blueprint*`).
`anvil` (blacksmith tile), `grindstone`, `hammer`, `mallet`, `pickaxe`, `shovel`, `saw`, `axe`, `tongs`, `bucket_metal`, `lantern`, `torch(_burnt)`, `rope_bundle_A/B`, `map` (treasure map, 1.94x0.35x1.22), `map_rolled`, `map_empty`, `blueprint`, `journal_open/closed`, `compass_base`, `magnifying_glass`, `scissors`, `wrench_*`, `screwdriver_*`... Use: event tiles (map = treasure event, anvil = upgrade/forge tile, journal/magnifying_glass = lore/event), shop clutter.

## 10. KayKit assets overview table

| Pack | glTF | Chars | Anims | Dice | Tiles | Chest/coin | Enemies | Props |
|---|---|---|---|---|---|---|---|---|
| Adventurers 2.0 | GLB chars, gltf props | 6 | 2 files (subset) | - | - | mug | - | weapons |
| Character Animations 1.1 | GLB | 2 mannequins | 14 GLBs, ~190 clips | - | - | - | (skeleton clips, no mesh) | - |
| BoardGameBits | gltf | - | - | D4/D6/D8/D20 | tile_* 1x1 | coins, cubes | skeleton portrait tiles | pawns, meeples, flags, hourglass, trays |
| Dungeon 1.1 | gltf | - | - | - | floor_tile_* 2x2/4x4 | chest, chest_gold, coins, stacks | - | ~200 props |
| Halloween Bits | gltf | - | - | - | floor_dirt, path | - | - | graveyard set |
| BlockBits | gltf | - | - | - | 2x2x2 cubes | - | - | terrain |
| Platformer | gltf | - | - | - | platform_* (4 colours) | star/heart/diamond | - | hoops, pipes, flags |
| FantasyWeaponsBits | gltf | - | - | - | - | - | - | 31 weapons |
| RPGToolsBits | gltf | - | - | - | - | map | - | 49 tools |

## 11. Tiny RPG Character Asset Packs (2D pixel sprites) — ENEMIES / BOSSES (billboardable)

Paths: `Tiny RPG Character Asset Pack 01 v2.0 -Full 22 Characters/` (3.5 MB, also `.zip`) and `Tiny RPG Character Asset Pack 02 -Full 20 Characters/` (3.1 MB; zip is `... 02 v1.01-Full 20 Characters.zip`).
**No license/readme file in the folders or zips.** These are the Zerie "Tiny RPG" packs (free for commercial use per the itch page, from memory) — **unverified; confirm terms before shipping**, and treat as non-CC0.
Layout: `Characters(100x100 split)/<Name>/<Name>/<Name>_<Anim>.png` (horizontal strip, frame = **100x100 px**, frame count = width/100; the actual sprite is small, ~20-30 px within the frame, i.e. very tiny/pixel-y), a `<Name> with shadows/` twin folder (same strips with baked shadow), a full sheet `<Name>/<Name>/<Name>.png`, `Aseprite file/<Name>.aseprite`, plus projectiles (`Arrow(Projectile)`, `Magic(Projectile)` in 32x32 & 100x100; pack 02 `Projectile/`).
Every character has Idle (6f), Walk (8f), Hurt (4f), Death (4f, some 6-11), Attack01-03 (6-18f) [flyers: Flying instead of Idle/Walk]. Extra: Block, Summon (skeletons/necromancer), Heal (priest), *_Effect strips.
Pack 01 (22): Archer, Armored Axeman, Armored Orc, Armored Skeleton, Bat, Elite Orc, Greatsword Skeleton, Knight, Knight Templar, Lancer, Necromancer, Orc, Orc rider, Priest, Skeleton, Skeleton Archer, Slime, Soldier, Swordsman, Werebear, Werewolf, Wizard.
Pack 02 (20): Black Knight_A/B/C, Blood Monster_A/B, Demon_A-E, Demoness_A/B, Eyeball Monster, Flame Golem, Ghostfire, Hellbat, Hellhound, Lava Slime, Minotaur, Warlock.
Use: they don't match the 3D low-poly look natively (pixel art), but as Y-billboards with nearest-neighbour filtering they are the only source of skeleton/orc/slime/demon/boss enemies here; also good as 2D enemy portraits in the fight UI (cropped/scaled). Also 3D-only alternative below.

## 12. Other files

Music: the mixkit beds (`mixkit-*.mp3`, Mixkit Free License: no redistribution as standalone
files). Fonts and SFX were sourced later (Google Fonts OFL, Kenney CC0); see assets/CREDITS.md.

---

## Recommended asset picks

**Heroes (3D, animated)** — `KayKit_Adventurers_2.0_FREE/Characters/gltf/`: `Knight.glb`, `Barbarian.glb`, `Rogue.glb`, `Ranger.glb`, `Mage.glb` (+`Rogue_Hooded.glb` as unlockable/6th). Animations from `KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/`: General (Idle_A, Hit_A, Death_A, Interact, Use_Item, Spawn_Ground), MovementBasic (Walking_A/Running_A for stepping along the board, Jump_Full_Short for a hop between tiles), CombatMelee (Melee_1H_Attack_Chop/Slice_Horizontal), CombatRanged (Ranged_Bow_Release, Ranged_Magic_Shoot/Spellcasting), Simulation (Cheering on victory), Tools (Lockpicking at chests). Weapons via `handslot.r/l` from `Adventurers/Assets/gltf/` (sword_1handed, staff, bow, dagger, shield_round) or `FantasyWeaponsBits`.

**Enemies (need a decision — no 3D monster meshes exist)**
- Option A (3D, all from these packs): re-use Adventurers/Mannequin with recoloured atlas + the `Rig_Medium_Special` `Skeletons_*` clips: Skeleton (Mannequin_Medium tinted bone-white, Skeletons_Idle/Walking/Death), Skeleton Archer (Ranger silhouette + bow), Skeleton Mage (Mage), Bandit (Rogue_Hooded), Brute/Ogre (Mannequin_Large or Barbarian scaled up, `Rig_Large_*` anims), Cultist (Mage recoloured), Knight-Fallen (Knight recoloured), Slime (procedural squashed sphere) ; Boss = Mannequin_Large scaled 1.8x with Barbarian/Knight helmet + crown.
- Option B (2D billboards, best variety): Tiny RPG — Slime, Skeleton, Skeleton Archer, Armored Skeleton, Orc, Elite Orc, Bat, Werewolf, Necromancer, Lava Slime (grunt to elite); Boss: Minotaur / Flame Golem / Black Knight_C / Demon_D / Greatsword Skeleton. Render as pixel billboards or 2D UI portraits.
- Fight-tile markers: `KayKit_BoardGameBits_1.0_FREE/Assets/gltf/tile_skeleton_{minion,brute,mage,rogue}.gltf` (portraits of skeleton types, 4 enemy tiers) and `playercard_skeleton_*.gltf`.

**Board tiles** (looping ring of square tiles): `KayKit_BoardGameBits_1.0_FREE/Assets/gltf/tile_{red,blue,green,yellow,purple}.gltf` = fight / shop / chest / event / boss-or-start (1x0.2x1, scale hero to ~0.4 or tiles to ~x3). Alternative larger tiles: `KayKit_Dungeon_Pack_1.1_FREE/Assets/gltf/floor_tile_large.gltf` (4x4) for a stone board, `floor_tile_big_spikes.gltf` for trap tiles, `KayKit_Platformer_Pack_1.0_FREE/Assets/gltf/{blue,red,yellow,green}/platform_1x1x1_<colour>.gltf` for candy colour-coded blocks. Start marker: `flag_A_<colour>`; player marker: `token_*` / `pawn_A_*`.

**Dice**: `KayKit_BoardGameBits_1.0_FREE/Assets/gltf/D6_C_red.gltf` (numeral texture, 188 tris, easy to re-texture with custom faces; face map +Z=1,-Y=2,-X=3,+X=4,+Y=5,-Z=6) for the main die; `D6_A_<colour>.gltf` (pips as geometry, classic look) as a second style; `D4_*`, `D8_*`, `D20_*` for special/upgraded dice; `container_C.gltf` (glass tray) / `container_A.gltf` as the dice tray; colours red/blue/green/yellow = dice element types. Dominoes optional for a bonus mechanic.

**Chest / coin / shop props**: `KayKit_Dungeon_Pack_1.1_FREE/Assets/gltf/chest.gltf` (common), `chest_gold.gltf` (rare), `coin.gltf`, `coin_stack_{small,medium,large}.gltf`, `key.gltf`; currency UI/pickups `KayKit_BoardGameBits_1.0_FREE/Assets/gltf/coin_gold.gltf`/`coin_10_gold.gltf`; shop: `table_long_tablecloth.gltf`, `shelf_small_candles.gltf`, `bottle_A_green/brown`, `banner_shield_*`, `barrel_small`, `building_<colour>` marker; upgrade/forge: `KayKit_RPGToolsBits_1.0_FREE/Assets/gltf/anvil.gltf`; event: `map.gltf`, `journal_open.gltf`, Platformer `star_*`/`diamond_*`/`heart_*` as relic/heal pickups.

**Decoration set (around the board)**: primary biome = Halloween/graveyard (`KayKit_HalloweenBits_1.0_FREE`: `tree_pine_orange_large`, `tree_dead_large`, `gravestone`, `fence`, `arch_gate`, `pumpkin_orange_jackolantern`, `lantern_standing`, `crypt` as boss lair, `floor_dirt` ground) + Dungeon props (`torch_lit`, `column`, `banner_*`, `barrel_large`, `crates_stacked`, `wall` sections) for an indoor variant + BlockBits `grass/dirt/water/lava` for island or biome bases. Colour palette across packs is compatible (all share the KayKit warm/cool gradient style).

**UI fonts**: Rajdhani (`Michroma,Rajdhani,Science_Gothic/Rajdhani/Rajdhani-Bold.ttf` for numbers/HUD) and BitterPro (`bitter-ht-full-pack/BitterPro-Bold.ttf` for titles/flavor text) — both OFL; a chunky display font (e.g. a bubbly Google font) would suit the KayKit look better and is not present. Music: `mixkit-zanarkand-forest-169.mp3`, `mixkit-spirit-in-the-woods-2-147.mp3` as bed tracks. SFX: none available, must be sourced.
