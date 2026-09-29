#!/usr/bin/env python3
"""Stamps a release version into the project before an export (CI; safe to run locally, then
`git checkout project.godot export_presets.cfg` to undo).

  tools/ci/stamp_version.py [--version 1.2.3[-rc.1]] [--channel stable|beta] [--distribution github]
                            [--print] [--github-output]

Without --version the version comes from git: the exact tag `vX.Y.Z[-pre]` on HEAD, otherwise
`<last tag>-dev.<commits since>` (or 0.0.0-dev.<n> without any tag).

Writes:
  project.godot        application/config/version = full semver
  export_presets.cfg   macOS/iOS short_version = X.Y.Z, version = build code;
                       Android version/name = full, version/code = build code;
                       Windows file/product_version = X.Y.Z.<pre number>
  build_info.json      {"version","commit","channel","distribution","godot","built","build"}
                       (exported via include_filter; read by the game's updater / version label)

Build code (CFBundleVersion / Android versionCode) is monotonic across pre-releases:
  major*1_000_000 + minor*10_000 + patch*100 + (pre-release number, or 99 for a final release)
e.g. 0.1.0-rc.1 -> 10001, 0.1.0 -> 10099, 1.2.3 -> 1020399.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$")
GODOT_VERSION = "4.7.2"


def git(*args: str) -> str:
    r = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def version_from_git() -> str:
    exact = git("describe", "--tags", "--exact-match", "--match", "v[0-9]*", "HEAD")
    if exact:
        return exact[1:]
    desc = git("describe", "--tags", "--match", "v[0-9]*", "--long", "HEAD")  # v1.2.3-4-gabc
    if desc:
        m = re.match(r"^v(.+)-(\d+)-g[0-9a-f]+$", desc)
        if m:
            return f"{m.group(1).split('-')[0]}-dev.{m.group(2)}"
    count = git("rev-list", "--count", "HEAD") or "0"
    return f"0.0.0-dev.{count}"


def build_code(major: int, minor: int, patch: int, pre: str | None) -> int:
    n = 99
    if pre:
        nums = re.findall(r"\d+", pre)
        n = min(int(nums[-1]), 98) if nums else 0
    return major * 1_000_000 + minor * 10_000 + patch * 100 + n


def set_key(text: str, section: str, key: str, value: str) -> str:
    """Sets key=value inside [section] of a Godot cfg file (adds it when missing)."""
    lines = text.split("\n")
    out, in_sec, done = [], False, False
    for ln in lines:
        if ln.startswith("["):
            if in_sec and not done:
                while out and out[-1] == "":
                    out.pop()
                out += [f"{key}={value}", ""]
                done = True
            in_sec = ln.strip() == f"[{section}]"
        elif in_sec and ln.startswith(f"{key}="):
            ln, done = f"{key}={value}", True
        out.append(ln)
    if in_sec and not done:
        out.append(f"{key}={value}")
    return "\n".join(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version")
    ap.add_argument("--channel")
    ap.add_argument("--distribution", default="github")
    ap.add_argument("--print", action="store_true", help="only print the resolved version")
    ap.add_argument("--github-output", action="store_true", help="append version=... to $GITHUB_OUTPUT")
    args = ap.parse_args()

    version = (args.version or version_from_git()).lstrip("v")
    m = SEMVER.match(version)
    if not m:
        raise SystemExit(f"stamp_version: '{version}' is not semver")
    major, minor, patch, pre = int(m[1]), int(m[2]), int(m[3]), m[4]
    short = f"{major}.{minor}.{patch}"
    code = build_code(major, minor, patch, pre)
    channel = args.channel or ("beta" if pre else "stable")
    commit = os.environ.get("GITHUB_SHA") or git("rev-parse", "HEAD")
    info = {"version": version, "short_version": short, "build": code, "commit": commit[:12],
            "channel": channel, "distribution": args.distribution, "godot": GODOT_VERSION,
            "built": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
    if args.github_output and os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as f:
            for k in ("version", "short_version", "build", "channel"):
                f.write(f"{k}={info[k]}\n")
            f.write(f"prerelease={'true' if pre else 'false'}\n")
    if args.print:
        print(json.dumps(info))
        return

    pg = ROOT / "project.godot"
    pg.write_text(set_key(pg.read_text(), "application", "config/version", f'"{version}"'))

    presets = (ROOT / "export_presets.cfg").read_text()
    win_ver = f'"{short}.{code % 100 if pre else 0}"'
    subs = {
        r'^application/short_version=".*"$': f'application/short_version="{short}"',
        r'^application/version=".*"$': f'application/version="{code}"',
        r'^version/name=".*"$': f'version/name="{version}"',
        r"^version/code=\d+$": f"version/code={code}",
        r'^application/file_version=".*"$': f"application/file_version={win_ver}",
        r'^application/product_version=".*"$': f"application/product_version={win_ver}",
    }
    for pat, rep in subs.items():
        presets = re.sub(pat, rep, presets, flags=re.M)
    (ROOT / "export_presets.cfg").write_text(presets)
    (ROOT / "build_info.json").write_text(json.dumps(info, indent=2) + "\n")
    print(f"stamped {version} (build {code}, {channel}/{args.distribution})")


if __name__ == "__main__":
    main()
