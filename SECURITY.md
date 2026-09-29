# Security policy

## Reporting a vulnerability

Please report security issues **privately** through
[GitHub security advisories](https://github.com/vladzaharia/diceroll/security/advisories/new)
or by email to hey@vlad.gg. Don't open a public issue. You'll get an answer within a week.

Relevant areas include the in-game auto-updater (manifest signatures, pack verification,
`game/update/`), the release pipeline (`.github/workflows/`, `tools/ci/`), and anything that could
leak the CI secrets or the private asset bundles.

## How the project protects itself

- The desktop auto-updater only accepts manifests signed with the release RSA key (verified in
  game with the public key in `game/update/update_keys.gd`) and packs whose SHA-256 matches the
  signed manifest; failed boots roll back to the previous version.
- CI uses `pull_request` (never `pull_request_target`) for untrusted code; fork PRs get no
  secrets, and first-time contributors need approval to run workflows.
- Third-party assets are only ever handled as age-encrypted bundles; caches hold ciphertext
  only; nothing decrypted is uploaded as an artifact or printed to logs.
- Secret scanning and push protection are enabled; CI runs gitleaks and a repository guard on
  every change.

## Supported versions

Only the latest release receives fixes.
