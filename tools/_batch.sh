#!/bin/sh
# Local batch runner for balance sims (not committed). Usage: sh tools/_batch.sh <tag> <spec>...
# spec = policy:profile:runs[:extra args joined with ,]
cd "$(dirname "$0")/.." || exit 1
OUT=/private/tmp/claude-501/-Users-vlad-Repos-diceroll/da9dfc75-f2f7-44cb-8676-9a1f1fec07e8/scratchpad/sims
mkdir -p "$OUT"
tag=$1
shift
for spec in "$@"; do
	pol=$(echo "$spec" | cut -d: -f1)
	prof=$(echo "$spec" | cut -d: -f2)
	runs=$(echo "$spec" | cut -d: -f3)
	extra=$(echo "$spec" | cut -d: -f4 | tr ',' ' ')
	name=$(echo "${tag}_${spec}" | tr ':,= ' '____')
	godot --headless --path . -s tools/sim.gd -- --runs="$runs" --class=all --policy="$pol" --profile="$prof" $extra > "$OUT/$name.txt" 2>&1 &
done
wait
for spec in "$@"; do
	name=$(echo "${tag}_${spec}" | tr ':,= ' '____')
	echo "== $spec"
	grep -E "^\| (knight|barbarian|mage|rogue) |overall" "$OUT/$name.txt"
done
