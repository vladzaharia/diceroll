# Distribution research notes (2026-09-29)

Point-in-time research behind
[`docs/design/2026-09-29-distribution-v2.md`](../../design/2026-09-29-distribution-v2.md) and its
[plan](../../plans/2026-09-29-distribution-v2-plan.md). Each note marks its claims as verified
against a primary source, tested on Godot 4.7.2, taken from a sibling note, or uncertain, and ends
with its sources. **Where a note and the design disagree, the design wins**: the design reconciles
the notes (for example, Apple's current limit is 200 asset packs per app record, not 100; the
`--main-pack` code-pack updater can't be fixed by a code-pack "bridge", because shipped binaries
refuse `--main-pack`).

| Note | Topic |
|---|---|
| [01-current-implementation.md](01-current-implementation.md) | Audit of the updater, release workflows, export presets and docs as of `4e78bb6` |
| [02-content-model.md](02-content-model.md) | Content tables, id hard-wiring in the rules, saves, determinism; the JSON/ContentDB/capabilities design and refactor plan |
| [04-apple.md](04-apple.md) | Background Assets (Apple-hosted and self-hosted), App Review rules, macOS channels, EU terms, Godot integration, CI |
| [05-android.md](05-android.md) | Play Asset Delivery, Godot 4.7 on Android, In-App Updates, Play policy, developer verification, signing, other stores, CI |
| [06-pc-stores.md](06-pc-stores.md) | Steam, itch.io, Epic, GOG, Microsoft Store |
| [07-desktop-direct.md](07-desktop-direct.md) | Velopack, Sparkle, Windows signing, Linux (Flathub, AppImage), the `--main-pack` finding |
| [08-web-cdn-delta.md](08-web-cdn-delta.md) | Web export and hosting, R2 and GitHub Releases as CDNs, delta-update schemes |
| [09-godot-engine.md](09-godot-engine.md) | Pack mounting, script injection through resources, crypto, UIDs, delta patches, HTTP, platform bridges |
| [11-content-patterns.md](11-content-patterns.md) | How shipped games structure packs and live content; granularity rules; store policy |
| [12-ci-release.md](12-ci-release.md) | GitHub Actions facts, release trains, promotion, pack pipeline, workflows |

Two further notes (the Polaris Key evaluation and the detailed signing-architecture study) describe
the internals of a private repository and are kept with Polaris Key's own specs.
