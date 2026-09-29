#!/usr/bin/env bash
# Populates the game's runtime asset folders (assets/kaykit, assets/audio, assets/fonts)
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

sync() { # sync <src_dir> <dst_dir> [rsync args...]
	local s="$1" d="$2"; shift 2
	mkdir -p "$d"
	rsync -a --delete --filter="P *.import" --filter="P *.uid" --filter="P *_texture.png" "$@" "$s/" "$d/"
}
lic() { # lic <pack_dir> <dst_dir>
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
sync "$MM/1 - July 2023 - Orc Raider/assets/gltf" "$KK/mystery/orc" --include='Orc_Wardrum*' --include='*.png' --exclude='*'
cp -f "$MM/License.txt" "$KK/mystery/License.txt"

echo "== Music beds (mixkit, re-encoded to 96 kbps mp3 to keep the repo lean)"
MUS="$DST/audio/music"
mkdir -p "$MUS"
for name in zanarkand-forest-169 spirit-in-the-woods-2-147 ambient-251 vastness-184 nature-meditation-345; do
	in="$TP/music/mixkit/mixkit-$name.mp3"
	out="$MUS/mixkit-$name.mp3"
	[ -f "$in" ] || { echo "missing $in" >&2; exit 1; }
	if [ ! -f "$out" ] || [ "$in" -nt "$out" ]; then
		if command -v ffmpeg >/dev/null; then
			ffmpeg -loglevel error -y -i "$in" -vn -c:a libmp3lame -b:a 96k "$out"
		else
			cp -f "$in" "$out"
		fi
	fi
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

du -sh "$DST"
