#!/usr/bin/env bash
# Populates the game's runtime asset folders (assets/kaykit, assets/audio, assets/fonts, assets/ui)
# from the central, git-ignored third-party store in third_party/ (see docs/ASSETS.md).
# Nothing third-party is committed; a fresh clone needs third_party/ filled in first.
# Idempotent: rsync only copies what changed; music is transcoded once.
# --fetch downloads fonts / Kenney SFX into third_party/ if they're missing there.
#
# Usage: tools/import_assets.sh [--fetch]   (run from anywhere)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TP="${THIRD_PARTY:-$ROOT/third_party}"
SRC="$TP/kaykit"
DST="$ROOT/assets"
KK="$DST/kaykit"

# Paid packs (*_EXTRA, Mystery Monthly) are optional: a FREE-only store (open-source forks)
# just skips their content, with one note per absent pack. A missing FREE pack still fails.
SKIPPED=" "
absent_paid() { # absent_paid <path>: true (and notes it once) when <path> is in an absent paid pack
	local rel="${1#"$SRC"/}" pack
	[ -e "$1" ] && return 1
	pack="${rel%%/*}"
	case "$pack" in *_EXTRA | KayKit_Mystery_Monthly_*) ;; *) return 1 ;; esac
	[ -d "$SRC/$pack" ] && return 1
	case "$SKIPPED" in *" $pack "*) ;; *)
		echo "   (no $pack: paid pack absent, skipping its content)"
		SKIPPED="$SKIPPED$pack " ;;
	esac
	return 0
}
sync() { # sync <src_dir> <dst_dir> [rsync args...]
	local s="$1" d="$2"; shift 2
	absent_paid "$s" && return 0
	mkdir -p "$d"
	rsync -a --delete --filter="P *.import" --filter="P *.uid" --filter="P *_texture.png" "$@" "$s/" "$d/"
}
lic() { # lic <pack_dir> <dst_dir>
	absent_paid "$SRC/$1" && return 0
	cp -f "$SRC/$1/License.txt" "$2/License.txt"
}

echo "== KayKit characters (Adventurers 2.0)"
ADV="KayKit_Adventurers_2.0_FREE"
sync "$SRC/$ADV/Characters/gltf" "$KK/adventurers/characters" --include='*.glb' --exclude='*'
sync "$SRC/$ADV/Assets/gltf" "$KK/adventurers/weapons"
lic "$ADV" "$KK/adventurers"

echo "== KayKit animations + mannequins (Character Animations 1.1)"
ANI="KayKit_Character_Animations_1.1"
sync "$SRC/$ANI/Animations/gltf/Rig_Medium" "$KK/animations/rig_medium" --include='*.glb' --exclude='*'
sync "$SRC/$ANI/Animations/gltf/Rig_Large" "$KK/animations/rig_large" --include='*.glb' --exclude='*'
sync "$SRC/$ANI/Mannequin Character/characters" "$KK/animations/mannequins" --include='*.glb' --exclude='*'
lic "$ANI" "$KK/animations"

echo "== KayKit BoardGameBits (tiles, dice, coins, tokens; class-badge cards dropped)"
BGB="KayKit_BoardGameBits_1.0_FREE"
sync "$SRC/$BGB/Assets/gltf" "$KK/boardgame" \
	--exclude='*_Badge.png' \
	--exclude='tile_barbarian_*' --exclude='tile_knight_*' --exclude='tile_mage_*' --exclude='tile_rogue_*' \
	--exclude='playercard_barbarian_*' --exclude='playercard_knight_*' --exclude='playercard_mage_*' --exclude='playercard_rogue_*'
lic "$BGB" "$KK/boardgame"

echo "== KayKit Dungeon, Halloween, Weapons, RPG Tools"
sync "$SRC/KayKit_Dungeon_Pack_1.1_FREE/Assets/gltf" "$KK/dungeon"
lic "KayKit_Dungeon_Pack_1.1_FREE" "$KK/dungeon"
sync "$SRC/KayKit_HalloweenBits_1.0_FREE/Assets/gltf" "$KK/halloween"
lic "KayKit_HalloweenBits_1.0_FREE" "$KK/halloween"
sync "$SRC/KayKit_FantasyWeaponsBits_1.0_FREE/Assets/gltf" "$KK/weapons"
lic "KayKit_FantasyWeaponsBits_1.0_FREE" "$KK/weapons"
sync "$SRC/KayKit_RPGToolsBits_1.0_FREE/Assets/gltf" "$KK/tools"
lic "KayKit_RPGToolsBits_1.0_FREE" "$KK/tools"

echo "== KayKit BlockBits terrain cubes (Glade / Frostpeak / Magma biomes and the ice / lava tiles)"
BB="KayKit_BlockBits_1.0_FREE"
bb_keep=""
for b in grass dirt dirt_with_grass gravel_with_grass sand_with_grass snow dirt_with_snow grass_with_snow \
	gravel_with_snow stone stone_dark gravel lava tree tree_with_snow glass water wood; do
	bb_keep="$bb_keep --include=$b.gltf --include=$b.bin"
done
# shellcheck disable=SC2086
sync "$SRC/$BB/Assets/gltf" "$KK/blocks" $bb_keep --include='block_bits_texture.png' --exclude='*'
lic "$BB" "$KK/blocks"

echo "== KayKit Platformer pickups (star/heart/diamond, yellow + red + blue)"
PLAT="KayKit_Platformer_Pack_1.0_FREE"
for c in yellow red blue; do
	sync "$SRC/$PLAT/Assets/gltf/$c" "$KK/platformer/$c" \
		--include='star_*' --include='heart_*' --include='diamond_*' --include='platformer_texture.png' --exclude='*'
done
lic "$PLAT" "$KK/platformer"

echo "== KayKit Forest Nature EXTRA (Camp: trees, bushes, rocks, grass; greens, teal and autumn)"
FOR="KayKit_Forest_Nature_Pack_1.0_EXTRA"
for c in 1 2 4 6; do
	sync "$SRC/$FOR/Assets/gltf/Color$c" "$KK/forest/color$c" \
		--include='Tree_*' --include='Bush_*' --include='Rock_*' --include='Grass_*' --include='forest_texture.png' --exclude='*'
done
lic "$FOR" "$KK/forest"

echo "== KayKit ResourceBits FREE (Camp: logs, planks, pallets, textiles, bars)"
RES="KayKit_ResourceBits_1.0_FREE"
res_keep=""
for r in Wood_Log_A Wood_Log_B Wood_Log_Stack Wood_Planks_Stack_Small Wood_Planks_Stack_Medium Pallet_Wood \
	Pallet_Wood_Covered_A Textiles_Stack_Large_Colored Textiles_A Iron_Bars_Stack_Small Gold_Bars_Stack_Small Parts_Pile_Small; do
	res_keep="$res_keep --include=$r.gltf --include=$r.bin"
done
# shellcheck disable=SC2086
sync "$SRC/$RES/Assets/gltf" "$KK/resources" $res_keep --include='*.png' --exclude='*'
lic "$RES" "$KK/resources"

echo "== Camp EXTRA packs (never committed): weapons, keepers, stores, dressing"
sync "$SRC/KayKit_FantasyWeaponsBits_1.0_EXTRA/Assets/gltf" "$KK/weapons_x"
lic "KayKit_FantasyWeaponsBits_1.0_EXTRA" "$KK/weapons_x"
ADX="KayKit_Adventurers_2.0_EXTRA"
sync "$SRC/$ADX/Characters/gltf" "$KK/adventurers_x/characters" \
	--include='Druid.glb' --include='Engineer.glb' --include='Barbarian_Large.glb' --include='Rogue_Hooded.glb' --exclude='*'
sync "$SRC/$ADX/Assets/gltf" "$KK/adventurers_x/assets"
lic "$ADX" "$KK/adventurers_x"
RX="KayKit_ResourceBits_1.0_EXTRA"
rx_keep=""
for r in Food_Basket_A_Berries Food_Basket_B_Berries Food_Crate_Large_Apples Food_Crate_Small_Berries Food_Barrel_Fish \
	Containers_Crate_Medium_Wood Containers_Pile_Small Gems_Chest Gems_Pile_Small Gems_Sack Money_Pile_Small Money_Coins_Stack_Medium \
	Gold_Bars_Stack_Medium Iron_Bars_Stack_Medium Copper_Bars_Stack_Small; do
	rx_keep="$rx_keep --include=$r.gltf --include=$r.bin"
done
# shellcheck disable=SC2086
sync "$SRC/$RX/Assets/gltf" "$KK/resources_x" $rx_keep --include='*.png' --exclude='*'
lic "$RX" "$KK/resources_x"
DX="KayKit_Dungeon_Pack_1.1_EXTRA"
dx_keep=""
for r in bench bucket_pickaxes chest_mimic crate_large_decorated rocks_gold bookcase_single_decoratedA keg_decorated \
	barrel_large_decorated table_long_decorated_A banner_triple_red banner_triple_blue banner_thin_yellow banner_thin_green; do
	dx_keep="$dx_keep --include=$r.gltf --include=$r.bin"
done
# shellcheck disable=SC2086
sync "$SRC/$DX/Assets/gltf" "$KK/dungeon_x" $dx_keep --include='*.png' --exclude='*'
lic "$DX" "$KK/dungeon_x"
TX="KayKit_RPGToolsBits_1.0_EXTRA"
sync "$SRC/$TX/Assets/gltf" "$KK/tools_x" --include='grindstone.*' --include='fishing_rod.*' --include='fishing_tacklebox.*' \
	--include='map_rolled.*' --include='journal_open.*' --include='key_A.*' --include='*.png' --exclude='*'
lic "$TX" "$KK/tools_x"
MM="$SRC/KayKit_Mystery_Monthly_Series_4"
sync "$MM/4 - October 2023 - Werewolf/assets/gltf" "$KK/mystery/werewolf"
sync "$MM/11 - May 2024 - Clown/assets/gltf" "$KK/mystery/clown"
sync "$MM/10 - April 2024 - Paladin/assets/gltf" "$KK/mystery/paladin"
# (the orc props, war drum included, are synced below with the other Mystery set pieces: a second
# sync here with --include='*.png' deleted the textures Godot extracts from the GLBs)
absent_paid "$MM" || cp -f "$MM/License.txt" "$KK/mystery/License.txt"

echo "== KayKit EXTRA props: tile props + rendered UI icons (paid packs; skipped when absent)"
xsync() { # xsync <pack> <dst> <texture.png> <names...>: copies <name>.gltf/.bin + the texture
	local pack="$1" d="$2" tex="$3"; shift 3
	[ -d "$SRC/$pack" ] || { echo "   (no $pack, skipping)"; return 0; }
	local keep="--include=$tex"
	for n in "$@"; do keep="$keep --include=$n.gltf --include=$n.bin"; done
	# shellcheck disable=SC2086
	sync "$SRC/$pack/Assets/gltf" "$d" $keep --exclude='*'
	lic "$pack" "$d"
}
xsync KayKit_ResourceBits_1.0_EXTRA "$KK/resources" resource_bits_texture.png \
	Gold_Bars_Stack_Small Gold_Bars_Stack_Medium Gold_Nuggets Gold_Bar Money_Coins_Stack_Large \
	Money_Coins_Stack_Medium Money_Coins_Stack_Small Money_Pile_Small Gem_Large Gem_Medium Gem_Small \
	Gems_Pile_Small Gems_Chest Gems_Sack Iron_Bars_Stack_Small Wood_Log_Stack Wood_Log_A \
	Food_Basket_A_Berries Food_Crate_Small_Berries Food_Cheese Food_Apple_Red Food_Apple_Green
xsync KayKit_RPGToolsBits_1.0_EXTRA "$KK/tools_x" tools_bits_texture.png \
	anvil grindstone tongs lantern key_A key_B lock_A lock_B map_rolled
xsync KayKit_Dungeon_Pack_1.1_EXTRA "$KK/dungeon_x" dungeon_texture.png \
	chest_large_gold chest_large key_gold candle_triple candle_lit rocks_gold pickaxe_gold
xsync KayKit_Adventurers_2.0_EXTRA "$KK/potions" druid_texture.png \
	potion_medium_red potion_medium_blue potion_medium_green potion_large_red

echo "== KayKit Skeletons 1.1 (FREE): the minion's head/jaw/eyes make the Skull Buddy pet"
SK="KayKit_Skeletons_1.1_FREE"
sync "$SRC/$SK/characters/gltf" "$KK/skeletons" --include='Skeleton_Minion.glb' --include='*.png' --exclude='*'
lic "$SK" "$KK/skeletons"

echo "== KayKit ResourceBits EXTRA gems, stone chunks, ore nuggets and cogs (Crystal Wisp, Pebble and Tinker pets; EXTRA = never committed, skipped if absent)"
RB="KayKit_ResourceBits_1.0_EXTRA"
if [ -d "$SRC/$RB/Assets/gltf" ]; then
	sync "$SRC/$RB/Assets/gltf" "$KK/resource" --include='Gem_*' --include='Stone_Chunks_*' \
		--include='*_Nugget_*' --include='Parts_Cog.*' --include='resource_bits_texture.png' --exclude='*'
	lic "$RB" "$KK/resource"
fi

echo "== Enemy roster (EXTRA + Mystery Monthly packs -> assets/kaykit/foes; see game/world/enemy_looks.gd)"
FOES="$KK/foes"
SKX="KayKit_Skeletons_1.1_EXTRA"
sync "$SRC/$SKX/characters/gltf" "$FOES/skeletons" --include='*.glb' --exclude='*'
sync "$SRC/$SKX/assets/gltf" "$FOES/skeletons/weapons" --exclude='Skeleton_Arrow*'
sync "$SRC/$SKX/textures" "$FOES/skeletons/textures" --include='skeleton_texture_B.png' --exclude='*'
lic "$SKX" "$FOES/skeletons"
ADX="KayKit_Adventurers_2.0_EXTRA"
sync "$SRC/$ADX/Characters/gltf" "$FOES/adventurers" --include='Barbarian_Large.glb' --include='Druid.glb' --exclude='*'
sync "$SRC/$ADX/Textures" "$FOES/adventurers/textures" --include='*_alt_*.png' --exclude='*'
adx_keep=""
for w in axe_1handed_Large axe_2handed_Large shield_round_barbarian_Large druid_staff; do
	adx_keep="$adx_keep --include=$w.gltf --include=$w.bin"
done
# shellcheck disable=SC2086
sync "$SRC/$ADX/Assets/gltf" "$FOES/adventurers/weapons" $adx_keep --include='barbarian_texture.png' --include='druid_texture.png' --exclude='*'
lic "$ADX" "$FOES/adventurers"
MMS="$SRC/KayKit_Mystery_Monthly_Series_4"
sync "$MMS/1 - July 2023 - Orc Raider/character" "$FOES/monthly/orc" --include='OrcRaider.glb' --exclude='*'
sync "$MMS/1 - July 2023 - Orc Raider/textures" "$FOES/monthly/orc/textures"
sync "$MMS/1 - July 2023 - Orc Raider/assets/gltf" "$FOES/monthly/orc/weapons" --include='Orc_Axe.gltf.glb' --include='Orc_Club.gltf.glb' \
	--include='Orc_Wardrum.gltf.glb' --include='Orc_WardrumStick.gltf.glb' --include='Orc_Backpack.gltf.glb' --include='Orc_DrinkingHorn.gltf.glb' --exclude='*'
sync "$MMS/4 - October 2023 - Werewolf/characters/gltf" "$FOES/monthly/werewolf" --include='Werewolf_Wolf.glb' --include='Werewolf_Man.glb' --exclude='*'
sync "$MMS/4 - October 2023 - Werewolf/textures" "$FOES/monthly/werewolf/textures"
sync "$MMS/4 - October 2023 - Werewolf/assets/gltf" "$FOES/monthly/werewolf/weapons" --include='axe.*' --include='werewolf_A.png' --exclude='*'
sync "$MMS/10 - April 2024 - Paladin/characters/gltf" "$FOES/monthly/paladin" --include='*.glb' --exclude='*'
sync "$MMS/10 - April 2024 - Paladin/textures" "$FOES/monthly/paladin/textures"
sync "$MMS/10 - April 2024 - Paladin/assets/gltf" "$FOES/monthly/paladin/weapons" \
	--include='paladin_hammer.*' --include='paladin_shield.*' --include='paladin_texture_A.png' --exclude='*'
sync "$MMS/8 - February 2024 - Ninja/character" "$FOES/monthly/ninja" --include='Ninja.glb' --exclude='*'
sync "$MMS/8 - February 2024 - Ninja/texture" "$FOES/monthly/ninja/textures"
sync "$MMS/8 - February 2024 - Ninja/assets/gltf" "$FOES/monthly/ninja/weapons" --include='Ninja_Katana.*' --include='Ninja_Shuriken.*' --include='ninja_texture_A.png' --exclude='*'
sync "$MMS/3 - September 2023 - Monster Costume/character/gltf" "$FOES/monthly/monster" --include='Monster.glb' \
	--include='MonsterCostume.glb' --exclude='*'
sync "$MMS/3 - September 2023 - Monster Costume/textures" "$FOES/monthly/monster/textures" --include='monstercostume_texture_*.png' --exclude='*'
absent_paid "$MMS" || cp -f "$MMS/License.txt" "$FOES/monthly/License.txt"
FWX="KayKit_FantasyWeaponsBits_1.0_EXTRA"
fwx_keep=""
for w in axe_D dagger_C hammer_D scythe shield_D spear_B staff_C staff_D sword_F sword_G wand_B; do
	fwx_keep="$fwx_keep --include=$w.gltf --include=$w.bin"
done
# shellcheck disable=SC2086
sync "$SRC/$FWX/Assets/gltf" "$FOES/weapons" $fwx_keep --include='*.png' --exclude='*'
lic "$FWX" "$FOES/weapons"

echo "== KayKit Forest Nature (EXTRA): trees, bare trees, bushes, rocks, grass (biome dressing)"
# All colours share one atlas (forest_texture.png), so the kept colours go into one folder.
# Colour1 green, 2 deep green, 3 lime, 4 teal, 5 gold, 6 orange (7 red / 8 pink unused).
FOR="$SRC/KayKit_Forest_Nature_Pack_1.0_EXTRA/Assets/gltf"
absent_paid "$FOR" || { mkdir -p "$KK/forest"; rsync -a --delete --filter="P *.import" --filter="P *.uid" \
	--include='Tree_[1-7]_*' --include='Tree_Bare_*' --include='Bush_[1-4]_*' --include='Rock_[1-6]_*' \
	--include='Grass_[12]_[A-D]_Color?.*' --include='forest_texture.png' --exclude='*' \
	"$FOR/Color1/" "$FOR/Color2/" "$FOR/Color3/" "$FOR/Color4/" "$FOR/Color5/" "$FOR/Color6/" "$KK/forest/"; }
lic "KayKit_Forest_Nature_Pack_1.0_EXTRA" "$KK/forest"

echo "== KayKit Dungeon (EXTRA): banners, furniture, props (no walls / floors / stairs)"
sync "$SRC/KayKit_Dungeon_Pack_1.1_EXTRA/Assets/gltf" "$KK/dungeon_x" \
	--exclude='wall*' --exclude='floor_*' --exclude='stairs*' --exclude='ceiling*' --exclude='bar_*' \
	--exclude='bartop_*' --exclude='bed_*' --exclude='scaffold_beam*'
lic "KayKit_Dungeon_Pack_1.1_EXTRA" "$KK/dungeon_x"

echo "== KayKit ResourceBits (EXTRA): crates, piles, ores, bars, food, logs"
sync "$SRC/KayKit_ResourceBits_1.0_EXTRA/Assets/gltf" "$KK/resources" \
	--exclude='Money_Bill*' --exclude='Pallet_Plastic_*' --exclude='Fuel_*' --exclude='Money_Coins_Stack_Single*'
lic "KayKit_ResourceBits_1.0_EXTRA" "$KK/resources"

echo "== KayKit RPG Tools (EXTRA), Fantasy Weapons (EXTRA), Skeleton props (EXTRA)"
sync "$SRC/KayKit_RPGToolsBits_1.0_EXTRA/Assets/gltf" "$KK/tools_x" \
	--exclude='fishing_*' --exclude='pencil_*' --exclude='screw*' --exclude='blueprint*' --exclude='*blueprint.png' \
	--exclude='drafting_*' --exclude='compass_*' --exclude='lockpick_*' --exclude='nail*' --exclude='journal_*'
lic "KayKit_RPGToolsBits_1.0_EXTRA" "$KK/tools_x"
sync "$SRC/KayKit_FantasyWeaponsBits_1.0_EXTRA/Assets/gltf" "$KK/weapons_x"
lic "KayKit_FantasyWeaponsBits_1.0_EXTRA" "$KK/weapons_x"
sync "$SRC/KayKit_Skeletons_1.1_EXTRA/assets/gltf" "$KK/skeleton_props"
lic "KayKit_Skeletons_1.1_EXTRA" "$KK/skeleton_props"

echo "== KayKit Mystery Monthly S4 set pieces (orc war drum, woodcutter logs, paladin statue)"
MYS="$SRC/KayKit_Mystery_Monthly_Series_4"
# exact names: a pattern like 'Orc_Wardrum*' also matches the texture Godot extracts next to the model
# (Orc_Wardrum_orc_texture_A.png), which --delete would then remove on every run
orc_keep=""
for o in Orc_Wardrum Orc_WardrumStick Orc_Axe Orc_Club Orc_Backpack Orc_DrinkingHorn; do
	orc_keep="$orc_keep --include=$o.gltf.glb"
done
# shellcheck disable=SC2086
sync "$MYS/1 - July 2023 - Orc Raider/assets/gltf" "$KK/mystery/orc" $orc_keep --exclude='*'
sync "$MYS/4 - October 2023 - Werewolf/assets/gltf" "$KK/mystery/woodcutter"
sync "$MYS/10 - April 2024 - Paladin/assets/gltf" "$KK/mystery/paladin" --include='paladin_statue*' \
	--include='paladin_texture_A.png' --exclude='*'
cp -f "$MYS/License.txt" "$KK/mystery/License.txt" 2>/dev/null || true
# Godot extracts a GLB's embedded texture next to it (<model>_<texture>.png + .import). Older runs of
# this script deleted those PNGs but kept their .import files, so every load logged "Failed loading
# resource" (exports too) and the models lost their textures. Drop such orphans with the model's
# .import: the next `godot --import` re-extracts them.
find "$KK" -name '*.png.import' | while read -r imp; do
	png="${imp%.import}"
	[ -f "$png" ] && continue
	for m in "${png%_*_texture*.png}".gltf.glb "${png%_*_texture*.png}".glb; do
		[ -f "$m" ] || continue
		echo "   repairing stale extracted texture: ${png#"$DST"/}"
		rm -f "$imp" "$m.import"
	done
done
echo "== Minigames (WP-E2): dig treasures, claw prizes, dig tools (EXTRA packs: never commit these)"
RB="KayKit_ResourceBits_1.0_EXTRA"
rb_keep=""
for f in Gem_Large Gem_Medium Gem_Small Gems_Pile_Small Gems_Chest Money_Pile_Small Money_Coins_Stack_Medium Gold_Nugget_Large; do
	rb_keep="$rb_keep --include=$f.gltf --include=$f.bin"
done
# shellcheck disable=SC2086
sync "$SRC/$RB/Assets/gltf" "$KK/resources" $rb_keep --include='resource_bits_texture.png' --exclude='*'
lic "$RB" "$KK/resources"
TX="KayKit_RPGToolsBits_1.0_EXTRA"
tx_keep=""
for f in pickaxe magnifying_glass map_rolled trowel lantern shovel; do
	tx_keep="$tx_keep --include=$f.gltf --include=$f.bin"
done
# shellcheck disable=SC2086
sync "$SRC/$TX/Assets/gltf" "$KK/tools_extra" $tx_keep --include='tools_bits_texture.png' --exclude='*'
lic "$TX" "$KK/tools_extra"
MM="KayKit_Mystery_Monthly_Series_4"
sync "$SRC/$MM/11 - May 2024 - Clown/assets/gltf" "$KK/mystery/clown" --include='balloon_dog_*' --include='clown_ball.*' \
	--include='clown_texture.png' --exclude='*'
if ! absent_paid "$SRC/$MM"; then
	mkdir -p "$KK/mystery/figures"
	cp -f "$SRC/$MM/12 - June 2024 - Robot/characters/Robot_One.glb" "$KK/mystery/figures/Robot_One.glb"
	cp -f "$SRC/$MM/6 - December 2023 - Action Figure/character/gltf/ActionFigure.glb" "$KK/mystery/figures/ActionFigure.glb"
fi
lic "$MM" "$KK/mystery"

echo "== Music beds (CC0, OpenGameArt: RandomMind + cynicmusic) -> mp3, -16 LUFS"
# out name | source dir under third_party/music | source file | trim (1 = strip leading/trailing
# silence from full-length tracks; 0 = author's seamless loop version, left untouched).
# Two-pass loudnorm (linear) to -16 LUFS integrated, -1.5 dBTP, then LAME VBR q4 (~165 kbps;
# the LAME tag's delay/padding keeps loops gapless in Godot). Homebrew ffmpeg has no libvorbis.
MUS="$DST/audio/music"
mkdir -p "$MUS"
command -v ffmpeg >/dev/null || { echo "ffmpeg is required to import music" >&2; exit 1; }
keep=" "
while IFS='|' read -r name dir file trim; do
	in="$TP/music/$dir/$file"
	out="$MUS/$name.mp3"
	keep="$keep$name.mp3 $name.mp3.import "
	# a missing track only mutes that bed
	[ -f "$in" ] || { echo "   warning: missing $in (that music bed stays silent)" >&2; continue; }
	[ -f "$out" ] && [ ! "$in" -nt "$out" ] && continue
	pre="anull"
	[ "$trim" = 1 ] && pre="silenceremove=start_periods=1:start_threshold=-60dB,areverse,silenceremove=start_periods=1:start_threshold=-60dB,areverse"
	m="$(ffmpeg -nostdin -hide_banner -nostats -i "$in" -af "$pre,loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json" -f null - 2>&1)"
	j() { echo "$m" | sed -n "s/.*\"$1\" : \"\([^\"]*\)\".*/\1/p" | tail -1; }
	ln="loudnorm=I=-16:TP=-1.5:LRA=11:linear=true:measured_I=$(j input_i):measured_TP=$(j input_tp)"
	ln="$ln:measured_LRA=$(j input_lra):measured_thresh=$(j input_thresh):offset=$(j target_offset)"
	ffmpeg -nostdin -loglevel error -y -i "$in" -vn -af "$pre,$ln" -ar 44100 -c:a libmp3lame -q:a 4 "$out"
done <<'EOF'
bards-tale|randommind|Loop_The_Bards_Tale.wav|0
old-tower-inn|randommind|Loop_The_Old_Tower_Inn.wav|0
harvest-season|randommind|harvestseason.wav|1
lament-for-a-warriors-soul|randommind|Lament_for_a_Warriors_Soul_REUPLOAD.mp3|1
rising-moon|randommind|Rising_Moon_0.mp3|1
medieval-battle|randommind|battle_1.wav|1
dark-forest|cynicmusic|GameMusic_ForestTheme_24_0.mp3|1
battle-theme-b|cynicmusic|battleThemeB.mp3|1
battle-theme-a|cynicmusic|battleThemeA.mp3|1
EOF
# drop any retired beds so they can't ship in an export
for f in "$MUS"/*; do
	case "$keep" in *" ${f##*/} "*) ;; *) rm -f "$f" ;; esac
done

if [ "${1:-}" = "--fetch" ]; then
	echo "== Fonts (Google Fonts GitHub, OFL) -> third_party/fonts"
	FON="$TP/fonts"
	mkdir -p "$FON"
	GF="https://raw.githubusercontent.com/google/fonts/main/ofl"
	[ -f "$FON/Fredoka-Variable.ttf" ] || curl -fsSL -o "$FON/Fredoka-Variable.ttf" "$GF/fredoka/Fredoka%5Bwdth,wght%5D.ttf"
	[ -f "$FON/LilitaOne-Regular.ttf" ] || curl -fsSL -o "$FON/LilitaOne-Regular.ttf" "$GF/lilitaone/LilitaOne-Regular.ttf"
	[ -f "$FON/OFL-Fredoka.txt" ] || curl -fsSL -o "$FON/OFL-Fredoka.txt" "$GF/fredoka/OFL.txt"
	[ -f "$FON/OFL-LilitaOne.txt" ] || curl -fsSL -o "$FON/OFL-LilitaOne.txt" "$GF/lilitaone/OFL.txt"

	echo "== Kenney SFX packs (CC0) -> third_party/kenney/<pack>/"
	TMP="$(mktemp -d)"
	# pack name, then an optional egrep filter of the .ogg basenames to keep (default: all).
	for spec in "casino-audio" "rpg-audio" "impact-sounds" "interface-sounds" \
		"music-jingles:jingles_(PIZZI00|PIZZI10|SAX04|STEEL00)" \
		"digital-audio:(powerUp2|powerUp7|phaseJump1|zapThreeToneUp)"; do
		pack="${spec%%:*}"
		filter="."; [ "$spec" != "$pack" ] && filter="${spec#*:}"
		out="$TP/kenney/$pack"
		[ -d "$out" ] && continue
		url="$(curl -fsSL "https://kenney.nl/assets/$pack" | grep -oE 'https://kenney.nl/media/pages/assets/[^"]+\.zip' | head -1)"
		[ -n "$url" ] || { echo "no zip url for $pack" >&2; continue; }
		curl -fsSL -o "$TMP/$pack.zip" "$url"
		mkdir -p "$TMP/$pack" "$out"
		unzip -q -o "$TMP/$pack.zip" -d "$TMP/$pack"
		find "$TMP/$pack" -name '*.ogg' ! -name 'Preview.ogg' | grep -E "$filter" | while read -r f; do cp -f "$f" "$out/"; done
		find "$TMP/$pack" -iname 'License*.txt' -exec cp -f {} "$out/License.txt" \;
	done
	rm -rf "$TMP" 2>/dev/null || true
fi

echo "== Fonts and Kenney SFX (third_party -> assets)"
sync "$TP/fonts" "$DST/fonts"
sync "$TP/kenney" "$DST/audio/sfx"

echo "== RhosGFX UI (paid: never committed): referenced SVGs only -> assets/ui/icons, assets/ui/pack"
# Referenced = ui/icons/icon_map.json (+ the demo map) and ui/theme/ui_pack.json; the rest of the
# ~6,000 pack SVGs stay in third_party/. Stale copies are deleted; a missing source only warns
# (that icon / control keeps its current look). See docs/design/2026-09-30-svg-ui-pipeline.md.
[ -d "$TP/rhosgfx" ] || echo "   (no $TP/rhosgfx: RhosGFX packs absent, the UI keeps its drawn look)"
python3 "$ROOT/tools/import_ui_svgs.py" --root "$ROOT" --third-party "$TP"

du -sh "$DST"
