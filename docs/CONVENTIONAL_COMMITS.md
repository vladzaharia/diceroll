# Commit messages: Conventional Commits

Every commit on `main` (and every PR title, which becomes the squash commit) follows
[Conventional Commits 1.0](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<optional scope>)<optional !>: <summary in lowercase, imperative, no period>

<optional body: what and why>

<optional footers, e.g. BREAKING CHANGE: ..., Co-Authored-By: ...>
```

| Type | Use for | Changelog group | Version bump (manual) |
|---|---|---|---|
| `feat` | new content, mechanics, UI | Features | minor |
| `fix` | bug fixes players could hit | Bug fixes | patch |
| `perf` | performance | Performance | patch |
| `balance` | numbers and tuning (HP, prices, drop rates) | Balance | patch |
| `refactor` | code changes without behaviour change | Refactoring | none |
| `docs` | documentation | Documentation | none |
| `test` | tests only | Maintenance | none |
| `build`, `ci` | exports, tooling, workflows | Build and CI | none |
| `chore`, `style` | housekeeping, formatting | Maintenance | none |
| `revert` | reverting a commit | Other | as reverted |

`!` after the type/scope, or a `BREAKING CHANGE:` footer, marks a breaking change (for a game:
save-format or settings incompatibility); it's flagged in the changelog and implies a major bump
(minor while in 0.x).

Common scopes: `board`, `combat`, `dice`, `camp`, `ui`, `hud`, `audio`, `meta`, `pets`,
`minigames`, `biomes`, `update`, `assets`, `ci`, `release`, `ios`, `android`, `macos`, `web`.

Examples:

```
feat(camp): add the fishing pier minigame booth
fix(combat): hero lunges from its own tile after a board move
balance(biomes): lower magma brute HP by 10%
ci(release): publish the AltStore source with each release
feat(meta)!: profile schema v3 (old saves are migrated once)
```

Where this is enforced:

- `tools/git-hooks/commit-msg` (enable with `git config core.hooksPath tools/git-hooks`)
- `.github/workflows/pr-title.yml` checks PR titles (squash merges use the title)
- `cliff.toml` groups commits into `CHANGELOG.md`; older free-form commits land in "Other"
- `tools/ci/changelog_llm.py` drops `ci`/`build`/`chore`/`test`/`docs`/`style`/`refactor`
  commits from the player-facing notes when it falls back to the mechanical conversion

Versions are plain SemVer tags `vX.Y.Z` (pre-releases `vX.Y.Z-rc.N`, `-beta.N`); see
[RELEASE.md](RELEASE.md).
