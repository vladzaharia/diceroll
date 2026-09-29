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

echo "== KayKit Skeletons 1.1 (FREE): the minion's head/jaw/eyes make the Skull Buddy pet"
SK="KayKit_Skeletons_1.1_FREE"
sync "$SRC/$SK/characters/gltf" "$KK/skeletons" --include='Skeleton_Minion.glb' --include='*.png' --exclude='*'
lic "$SK" "$KK/skeletons"

echo "== KayKit ResourceBits EXTRA gems (Crystal Wisp pet; EXTRA = never committed, skipped if absent)"
RB="KayKit_ResourceBits_1.0_EXTRA"
if [ -d "$SRC/$RB/Assets/gltf" ]; then
	sync "$SRC/$RB/Assets/gltf" "$KK/resource" --include='Gem_*' --include='resource_bits_texture.png' --exclude='*'
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
sync "$MMS/1 - July 2023 - Orc Raider/assets/gltf" "$FOES/monthly/orc/weapons" --include='Orc_Axe.gltf.glb' --include='Orc_Club.gltf.glb' --exclude='*'
sync "$MMS/4 - October 2023 - Werewolf/characters/gltf" "$FOES/monthly/werewolf" --include='Werewolf_Wolf.glb' --exclude='*'
sync "$MMS/4 - October 2023 - Werewolf/textures" "$FOES/monthly/werewolf/textures"
sync "$MMS/4 - October 2023 - Werewolf/assets/gltf" "$FOES/monthly/werewolf/weapons" --include='axe.*' --include='werewolf_A.png' --exclude='*'
sync "$MMS/10 - April 2024 - Paladin/characters/gltf" "$FOES/monthly/paladin" --include='*.glb' --exclude='*'
sync "$MMS/10 - April 2024 - Paladin/textures" "$FOES/monthly/paladin/textures"
sync "$MMS/10 - April 2024 - Paladin/assets/gltf" "$FOES/monthly/paladin/weapons" \
	--include='paladin_hammer.*' --include='paladin_shield.*' --include='paladin_texture_A.png' --exclude='*'
sync "$MMS/8 - February 2024 - Ninja/character" "$FOES/monthly/ninja" --include='Ninja.glb' --exclude='*'
sync "$MMS/8 - February 2024 - Ninja/texture" "$FOES/monthly/ninja/textures"
sync "$MMS/8 - February 2024 - Ninja/assets/gltf" "$FOES/monthly/ninja/weapons" --include='Ninja_Katana.*' --include='ninja_texture_A.png' --exclude='*'
sync "$MMS/3 - September 2023 - Monster Costume/character/gltf" "$FOES/monthly/monster" --include='Monster.glb' --exclude='*'
sync "$MMS/3 - September 2023 - Monster Costume/textures" "$FOES/monthly/monster/textures" --include='monstercostume_texture_*.png' --exclude='*'
cp -f "$MMS/License.txt" "$FOES/monthly/License.txt"
FWX="KayKit_FantasyWeaponsBits_1.0_EXTRA"
fwx_keep=""
for w in axe_D dagger_C hammer_D scythe shield_D spear_B staff_C staff_D sword_F sword_G wand_B; do
	fwx_keep="$fwx_keep --include=$w.gltf --include=$w.bin"
done
# shellcheck disable=SC2086
sync "$SRC/$FWX/Assets/gltf" "$FOES/weapons" $fwx_keep --include='*.png' --exclude='*'
lic "$FWX" "$FOES/weapons"

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
