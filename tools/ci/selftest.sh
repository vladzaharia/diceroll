#!/usr/bin/env bash
# Self-test of the CI tooling that needs no secrets and no game assets (CI "static" job; local:
# tools/ci/selftest.sh). Uses throwaway keys in a temp dir; uploads nothing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
ok() { echo "selftest: ok - $*"; }

# 1. Asset bundles: pack -> fetch (local dir store) -> verify, in a fake project tree.
if command -v age >/dev/null && command -v zstd >/dev/null; then
	P="$T/proj"
	mkdir -p "$P/tools/ci" "$P/assets/kaykit/alpha/sub" "$P/assets/kaykit/beta" "$P/assets/fonts"
	cp "$ROOT/tools/ci/assets.py" "$P/tools/ci/"
	age-keygen -o "$T/key.txt" 2>/dev/null
	age-keygen -y "$T/key.txt" >"$P/tools/ci/assets_recipient.txt"
	echo one >"$P/assets/kaykit/alpha/a.gltf"; echo two >"$P/assets/kaykit/alpha/sub/b.bin"
	head -c 20000 /dev/urandom >"$P/assets/kaykit/beta/tex.png"; echo font >"$P/assets/fonts/F.ttf"
	python3 "$P/tools/ci/assets.py" pack >/dev/null
	h1="$(python3 "$P/tools/ci/assets.py" hash)"
	out="$(python3 "$P/tools/ci/assets.py" pack)"
	grep -q "0 newly packed" <<<"$out" # idempotent
	echo changed >"$P/assets/kaykit/beta/tex.png"
	out="$(python3 "$P/tools/ci/assets.py" pack)"
	grep -q "1 newly packed" <<<"$out" # only the changed unit
	[ "$h1" != "$(python3 "$P/tools/ci/assets.py" hash)" ]
	cp -r "$P/assets" "$T/orig" && rm -rf "$P/assets"
	ASSETS_AGE_KEY="$(grep AGE-SECRET "$T/key.txt")" python3 "$P/tools/ci/assets.py" fetch --dir "$P/build/asset-bundles" --cache "$T/cache" >/dev/null
	python3 "$P/tools/ci/assets.py" verify >/dev/null
	diff -r "$T/orig" "$P/assets"
	rm -rf "$P/assets/fonts"
	if ASSETS_AGE_KEY="" python3 "$P/tools/ci/assets.py" fetch --dir "$P/build/asset-bundles" --cache "$T/cache" 2>/dev/null; then
		echo "selftest: fetch without a key should fail" >&2; exit 1
	fi
	mkdir -p "$T/seal/in/x" && echo s >"$T/seal/in/x/y"
	python3 "$P/tools/ci/assets.py" seal "$T/seal/in" "$T/seal/s.age" >/dev/null
	ASSETS_AGE_KEY="$(grep AGE-SECRET "$T/key.txt")" python3 "$P/tools/ci/assets.py" unseal "$T/seal/s.age" "$T/seal/out" >/dev/null
	diff -r "$T/seal/in" "$T/seal/out"
	ok "asset bundles: pack/incremental/fetch/verify/seal round trip"
else
	echo "selftest: skip asset bundles (age/zstd not installed)"
fi

# 2. Versioning.
grep -q '"build": 1020304' <<<"$(python3 "$ROOT/tools/ci/stamp_version.py" --print --version 1.2.3-rc.4)"
grep -q '"build": 1020399' <<<"$(python3 "$ROOT/tools/ci/stamp_version.py" --print --version 1.2.3)"
ok "stamp_version build codes"

# 3. Release notes (dry run, no key).
ANTHROPIC_API_KEY="" python3 "$ROOT/tools/ci/changelog_llm.py" --version 9.9.9 --dry-run --out "$T/notes" >/dev/null
for f in RELEASE_NOTES.md store/ios_whats_new.txt store/android_whats_new.txt; do [ -s "$T/notes/$f" ]; done
[ "$(wc -m <"$T/notes/store/android_whats_new.txt")" -le 501 ]
ok "changelog_llm dry run"

# 4. Updater manifest: signed with a throwaway key, signature verifies with openssl.
mkdir -p "$T/dist" && head -c 3000 /dev/urandom >"$T/dist/Diceroll-2.0.0-desktop.pck"
openssl genrsa -out "$T/sign.pem" 2048 2>/dev/null
openssl rsa -in "$T/sign.pem" -pubout -out "$T/sign.pub" 2>/dev/null
UPDATE_SIGNING_KEY="$(cat "$T/sign.pem")" python3 "$ROOT/tools/ci/update_manifest.py" --version 2.0.0 \
	--dist "$T/dist" --release-url https://example.invalid/v2.0.0 --out "$T/upd" >/dev/null
base64 -d <"$T/upd/update-stable.json.sig" >"$T/sig.bin" 2>/dev/null || base64 -D <"$T/upd/update-stable.json.sig" >"$T/sig.bin"
openssl dgst -sha256 -verify "$T/sign.pub" -signature "$T/sig.bin" "$T/upd/update-stable.json" >/dev/null
[ -f "$T/upd/update-beta.json" ]
ok "update manifest signing"

# 5. Contact sheet on a synthetic result set.
mkdir -p "$T/shots"
printf 'scenario\tdevice\tresolution\tstatus\tseconds\ns\td\t1x1\tok\t1\n' >"$T/shots/results.tsv"
python3 "$ROOT/tools/ci/contact_sheet.py" "$T/shots" >/dev/null
[ -s "$T/shots/index.html" ]
ok "contact sheet"
