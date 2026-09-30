#!/usr/bin/env bash
# Repository guard: fails if third-party assets, secrets-looking files or oversized blobs are
# tracked. Runs in CI (every push/PR) and as a git pre-commit hook (tools/git-hooks/pre-commit).
#
#   tools/ci/check_repo.sh            check every tracked file (CI)
#   tools/ci/check_repo.sh --staged   check only what's staged (pre-commit hook)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [ "${1:-}" = "--staged" ]; then
	files="$(git diff --cached --name-only --diff-filter=ACMR)"
else
	files="$(git ls-files)"
fi

fail=0
bad() { echo "check_repo: $*" >&2; fail=1; }

# 1. Third-party assets live in the private asset store only (docs/ASSETS.md).
forbidden='^(third_party/|assets/kaykit/|assets/audio/|assets/fonts/|assets/ui/icons/|assets/ui/pack/|ui/icons/rendered/.*\.png|\.ci-cache/|android/|build/)'
while IFS= read -r f; do
	[ -n "$f" ] && bad "third-party asset / build output must not be committed: $f"
done < <(grep -E "$forbidden" <<<"$files" || true)

# 2. Key material and store credentials.
secret_names='(\.p12|\.p8|\.mobileprovision|\.keystore|\.jks|\.pem|\.age|id_rsa|id_ed25519|google-play.*\.json|service-account.*\.json|config\.vdf|asset-bundle\.key)$'
while IFS= read -r f; do
	case "$f" in
		tests/fixtures/update/*) continue ;;  # throwaway test keys for the updater tests
	esac
	[ -n "$f" ] && bad "key/credential file must not be committed: $f"
done < <(grep -E "$secret_names" <<<"$files" || true)

# 3. Private key blocks in any text file (the updater's PUBLIC key is fine).
while IFS= read -r f; do
	[ -f "$f" ] || continue
	case "$f" in tests/fixtures/update/*|tools/ci/check_repo.sh) continue ;; esac
	if grep -qE "BEGIN (RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY|AGE-SECRET-KEY-1[0-9A-Z]{20,}" "$f" 2>/dev/null; then
		bad "private key material in $f"
	fi
done <<<"$files"

# 4. Large files (the repo stays small; media belongs in docs/media, modestly sized).
while IFS= read -r f; do
	[ -f "$f" ] || continue
	size=$(wc -c <"$f")
	[ "$size" -le 1500000 ] || bad "file larger than 1.5 MB: $f ($size bytes)"
done <<<"$files"

if [ $fail = 0 ]; then
	echo "check_repo: ok ($(wc -l <<<"$files" | tr -d ' ') files)"
fi
exit $fail
