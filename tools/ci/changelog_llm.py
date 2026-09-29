#!/usr/bin/env python3
"""Player-facing release notes ("What's new") from the developer changelog, via Claude.

  tools/ci/changelog_llm.py --version 0.2.0 [--from v0.1.0] [--to HEAD]
                            [--changelog build/release-notes/CHANGELOG_RELEASE.md]
                            [--out build/release-notes] [--dry-run] [--model claude-opus-5-5]

Inputs: the commit subjects in <from>..<to> (default: previous v* tag..HEAD) and the developer
changelog section for this release (git-cliff output, see cliff.toml).
Outputs (in --out):
  RELEASE_NOTES.md          GitHub Release body: player-facing notes + the developer changelog
  store/ios_whats_new.txt   App Store "What's New" (plain text, <= 4000 characters)
  store/android_whats_new.txt  Play Console release notes (plain text, <= 500 characters, en-US)
  release_notes.json        everything above + which path produced it ("claude" or "fallback")

Deterministic by construction: a fixed system prompt, inputs sorted and de-duplicated, and a
strict JSON schema (structured outputs); lengths are enforced again locally. (Current Claude
models don't take temperature; the schema + fixed prompt keep the output stable in shape.)

Without ANTHROPIC_API_KEY (or with --dry-run, or on any API error / refusal) it falls back to
a mechanical conversion of the developer changelog, so a release never blocks on the LLM.
Requires `pip install anthropic` only for the Claude path.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL = "claude-opus-5-5"
IOS_MAX = 4000
ANDROID_MAX = 500
MAX_COMMITS = 400

SYSTEM = """You write release notes for Diceroll, a cozy dice-rolling roguelite board game \
(3D, for iPhone, iPad, Android, macOS, Windows, Linux and the web). Players roll dice to move \
around a board, fight enemies, collect runes and gear, and build up a camp between runs.

You receive the developer changelog and raw commit subjects for one release. Write notes for \
PLAYERS, not developers:
- Mention only changes a player can notice: new content, gameplay and balance changes, UI and \
quality-of-life improvements, performance, and fixed bugs players could hit.
- Leave out internal work entirely: CI, build scripts, refactors, tests, docs, tooling, asset \
pipelines, code style, dependency bumps.
- Friendly, concise, concrete. No hype words ("revolutionary", "epic"), no emoji, no internal \
names, file paths, class names, ticket numbers or commit hashes. Never invent features that \
are not in the input.
- If nothing player-facing changed, say it is a stability and performance update.

Return JSON matching the schema:
- headline: one short sentence summarising the release (<= 90 characters).
- release_notes_md: Markdown for the GitHub release page: a "## What's new" section with \
grouped bullet points (for example New, Improved, Fixed; omit empty groups).
- ios_whats_new: plain text for the App Store "What's New" field, <= 3800 characters, short \
lines, "- " bullets allowed, no Markdown syntax.
- android_whats_new: plain text for Google Play release notes, <= 480 characters in total, \
at most 5 short "- " bullets, no Markdown syntax."""

SCHEMA = {
    "type": "object",
    "properties": {
        "headline": {"type": "string"},
        "release_notes_md": {"type": "string"},
        "ios_whats_new": {"type": "string"},
        "android_whats_new": {"type": "string"},
    },
    "required": ["headline", "release_notes_md", "ios_whats_new", "android_whats_new"],
    "additionalProperties": False,
}

INTERNAL = re.compile(r"^(ci|build|chore|test|tests|docs|style|refactor)(\(.*?\))?!?:", re.I)


def git(*args: str) -> str:
    r = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def previous_tag(to: str) -> str:
    return git("describe", "--tags", "--abbrev=0", "--match", "v[0-9]*", f"{to}^")


def commit_subjects(frm: str, to: str) -> list[str]:
    rng = f"{frm}..{to}" if frm else to
    subjects = git("log", "--no-merges", "--format=%s", rng).splitlines()
    seen, out = set(), []
    for s in subjects:
        s = s.strip()
        if s and s not in seen:
            seen.add(s)
            out.append(s)
    return sorted(out)[:MAX_COMMITS]


def truncate(text: str, limit: int) -> str:
    text = text.strip()
    if len(text) <= limit:
        return text
    cut = text[: limit - 1]
    nl = cut.rfind("\n")
    return (cut[:nl] if nl > limit // 2 else cut.rstrip()) .rstrip() + "…"


def plain(md: str) -> str:
    """Markdown -> store-friendly plain text."""
    out = []
    for ln in md.splitlines():
        ln = re.sub(r"^#+\s*", "", ln)
        ln = re.sub(r"^\s*[*+]\s+", "- ", ln)
        ln = re.sub(r"\*\*(.+?)\*\*", r"\1", ln)
        ln = re.sub(r"`([^`]*)`", r"\1", ln)
        ln = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", ln)
        ln = re.sub(r"\s*\(\[?[0-9a-f]{7,40}\]?(\([^)]*\))?\)", "", ln)  # commit links
        out.append(ln.rstrip())
    return re.sub(r"\n{3,}", "\n\n", "\n".join(out)).strip()


def fallback(version: str, dev: str, subjects: list[str]) -> dict:
    player = [s for s in subjects if not INTERNAL.match(s)]
    bullets = [re.sub(r"^\w+(\(.*?\))?!?:\s*", "", s) for s in player]
    bullets = [b[:1].upper() + b[1:] for b in bullets if b]
    body = "\n".join(f"- {b}" for b in bullets) or "- Stability and performance improvements."
    android = "\n".join(f"- {b}" for b in bullets[:5]) or "- Stability and performance improvements."
    return {
        "headline": f"Diceroll {version}",
        "release_notes_md": f"## What's new\n\n{body}\n",
        "ios_whats_new": truncate(plain(body), IOS_MAX),
        "android_whats_new": truncate(plain(android), ANDROID_MAX),
        "source": "fallback",
    }


def ask_claude(model: str, version: str, dev: str, subjects: list[str]) -> dict:
    import anthropic  # only needed on this path

    client = anthropic.Anthropic()
    user = (f"Release: Diceroll {version}\n\n<developer_changelog>\n{dev.strip() or '(empty)'}\n"
            f"</developer_changelog>\n\n<commit_subjects>\n" + "\n".join(subjects) + "\n</commit_subjects>")
    response = client.beta.messages.create(
        model=model,
        max_tokens=16000,
        system=SYSTEM,
        messages=[{"role": "user", "content": user}],
        output_config={"effort": "medium", "format": {"type": "json_schema", "schema": SCHEMA}},
        # Server-side refusal fallback: a declined request is retried on a fallback model.
        betas=["server-side-fallback-2026-07-01"],
        extra_body={"fallbacks": "default"},
    )
    if response.stop_reason == "refusal":
        raise RuntimeError("model refused")
    if response.stop_reason == "max_tokens":
        raise RuntimeError("output truncated (max_tokens)")
    text = next(b.text for b in response.content if b.type == "text")
    data = json.loads(text)
    data["source"] = "claude"
    data["model"] = response.model
    return data


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--from", dest="frm")
    ap.add_argument("--to", default="HEAD")
    ap.add_argument("--changelog", help="developer changelog for this release (Markdown)")
    ap.add_argument("--out", default=str(ROOT / "build/release-notes"))
    ap.add_argument("--model", default=os.environ.get("CHANGELOG_MODEL", DEFAULT_MODEL))
    ap.add_argument("--dry-run", action="store_true", help="never call the API (prints the prompt)")
    args = ap.parse_args()

    version = args.version.lstrip("v")
    frm = args.frm if args.frm is not None else previous_tag(args.to)
    subjects = commit_subjects(frm, args.to)
    dev = Path(args.changelog).read_text() if args.changelog and Path(args.changelog).exists() else ""

    data = None
    if args.dry_run:
        print(f"changelog_llm: dry run ({len(subjects)} commits in {frm or 'start'}..{args.to}); prompt:")
        print(SYSTEM[:400] + " …")
    elif not os.environ.get("ANTHROPIC_API_KEY"):
        print("changelog_llm: ANTHROPIC_API_KEY not set, using the fallback notes")
    else:
        try:
            data = ask_claude(args.model, version, dev, subjects)
        except Exception as e:  # never block a release on the notes
            print(f"changelog_llm: Claude path failed ({type(e).__name__}: {e}); using the fallback", file=sys.stderr)
    if data is None:
        data = fallback(version, dev, subjects)

    ios = truncate(plain(data["ios_whats_new"]), IOS_MAX)
    android = truncate(plain(data["android_whats_new"]), ANDROID_MAX)
    notes = data["release_notes_md"].strip()
    if dev.strip():
        notes += "\n\n<details><summary>Developer changelog</summary>\n\n" + dev.strip() + "\n\n</details>"
    out = Path(args.out)
    (out / "store").mkdir(parents=True, exist_ok=True)
    (out / "RELEASE_NOTES.md").write_text(notes + "\n")
    (out / "store/ios_whats_new.txt").write_text(ios + "\n")
    (out / "store/android_whats_new.txt").write_text(android + "\n")
    data.update({"version": version, "range": f"{frm}..{args.to}", "ios_whats_new": ios, "android_whats_new": android})
    (out / "release_notes.json").write_text(json.dumps(data, indent=2) + "\n")
    print(f"changelog_llm: wrote {out} via {data['source']} (iOS {len(ios)}/{IOS_MAX}, Android {len(android)}/{ANDROID_MAX} chars)")


if __name__ == "__main__":
    main()
