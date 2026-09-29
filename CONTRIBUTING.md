# Contributing to Diceroll

Thanks for helping! Bug reports, ideas, balance feedback and pull requests are all welcome.

## Setup

Follow the README's [Build from source](README.md#build-from-source): Godot 4.7.2, the
third-party packs in `third_party/`, `tools/import_assets.sh --fetch`, a headless import. Then
enable the git hooks once:

```sh
git config core.hooksPath tools/git-hooks   # asset/secret guard + Conventional Commits check
```

## Ground rules

- **Never commit third-party assets.** `third_party/`, `assets/kaykit/`, `assets/audio/`,
  `assets/fonts/` and rendered icons are git-ignored; the pre-commit hook and CI
  (`tools/ci/check_repo.sh`) reject them, along with keys, keystores and files over 1.5 MB.
- **Commit messages and PR titles follow [Conventional Commits](docs/CONVENTIONAL_COMMITS.md)**:
  they drive the changelog and the release notes.
- Keep changes focused; match the existing GDScript style (typed GDScript, tabs, small scenes
  built in code).
- Never launch a windowed Godot from scripts: use `godot --headless` for tests and tools, and the
  background screenshot runner `tools/shoot.sh` for visuals.

## Before opening a PR

```sh
./tests/run.sh                                        # 0 failed, no SCRIPT ERROR
godot --headless --path . -s ui/check_scripts.gd      # UI_SCRIPTS_OK
godot --headless --path . -s tools/sim.gd -- --runs=50 --class=all   # errors=0
tools/shoot_matrix.sh <scenario> /tmp/shots quick     # UI changes: check phones + desktop
tools/ci/check_repo.sh                                # nothing forbidden tracked
```

New features should come with tests in `tests/test_*.gd` (see `tests/test_case.gd`) and, for
UI, a screenshot scenario (`ui/scenarios.gd`, `game/scenarios.gd`, ...).

## CI on forks

PRs from forks run the static checks only; jobs that need the private asset bundles (tests,
screenshots, exports) are skipped and a maintainer runs them. First-time contributors' workflow
runs need a maintainer's approval.

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
