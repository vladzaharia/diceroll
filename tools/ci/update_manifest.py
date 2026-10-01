#!/usr/bin/env python3
"""Writes (and signs) the auto-updater manifest for one release (see game/update/, docs/RELEASE.md).

  tools/ci/update_manifest.py --version 0.2.0 --dist DIR --release-url URL --out DIR
                              [--notes store/android_whats_new.txt] [--channel stable|beta]
                              [--min-binary 0.0.0] [--min-supported ""] [--engine 4.7.2]

DIR holds the release files; the manifest references them by name under --release-url
(e.g. https://github.com/vladzaharia/diceroll/releases/download/v0.2.0):
  Diceroll-<v>-desktop.pck   -> "pack"
  Diceroll-<v>-macos.zip     -> binaries.macos
  Diceroll-<v>-windows-x86_64.zip / -linux-x86_64.tar.gz / -linux-arm64.tar.gz -> binaries.*
Writes OUT/update-<channel>.json and, when UPDATE_SIGNING_KEY (PEM RSA private key) is set,
OUT/update-<channel>.json.sig = base64(RSA PKCS#1 v1.5 SHA-256 signature of the exact bytes),
verified in-game with Crypto.verify. A final release also refreshes the beta channel (beta
players get stable releases too), so pass --channel stable once and both files are written.

--min-supported (default "": no forced update) and --min-binary (default "0.0.0": any binary
on the same engine takes the pack) must not be above --version under semver: a prerelease
sorts below its release, so "0.1.0" on 0.1.0-rc.6 would mark that very build as unsupported.
"""

from __future__ import annotations

import argparse
import base64
import datetime
import hashlib
import json
import os
import subprocess
import re
import tempfile
from pathlib import Path

SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$")

STORES = {
    "ios": "https://apps.apple.com/app/id0000000000",
    "android": "https://play.google.com/store/apps/details?id=gg.vlad.diceroll",
}
BINARIES = {
    "macos": "macos.zip",
    "windows.x86_64": "windows-x86_64.zip",
    "linux.x86_64": "linux-x86_64.tar.gz",
    "linux.arm64": "linux-arm64.tar.gz",
}


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def semver_key(v: str) -> tuple:
    """Sort key matching game/update/semver.gd (prerelease < release, numeric ids < alnum)."""
    m = SEMVER.match(v)
    if not m:
        raise SystemExit(f"update_manifest: '{v}' is not a semantic version")
    core = tuple(int(x) for x in m.group(1, 2, 3))
    if m.group(4) is None:
        return core + (1, ())
    ids = tuple((0, int(i), "") if i.isdigit() else (1, 0, i) for i in m.group(4).split("."))
    return core + (0, ids)


def check_floor(name: str, floor: str, version: str) -> None:
    """A release must satisfy its own floors, or every build of it would be told to update."""
    if floor and semver_key(floor) > semver_key(version):
        raise SystemExit(f"update_manifest: --{name} {floor} is above the release {version} "
                         f"(a prerelease sorts below its release); use {version} or lower")


def sign(data: bytes, pem: str) -> str:
    with tempfile.TemporaryDirectory() as tmp:
        key = Path(tmp) / "k.pem"
        key.touch(mode=0o600)
        key.write_text(pem)
        r = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(key)], input=data, capture_output=True)
        if r.returncode != 0:
            raise SystemExit("update_manifest: openssl signing failed (check UPDATE_SIGNING_KEY)")
        return base64.b64encode(r.stdout).decode() + "\n"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--dist", required=True)
    ap.add_argument("--release-url", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--channel")
    ap.add_argument("--notes")
    ap.add_argument("--notes-url")
    ap.add_argument("--engine", default="4.7.2")
    ap.add_argument("--min-binary", default="0.0.0")
    ap.add_argument("--min-supported", default="")
    args = ap.parse_args()

    v = args.version.lstrip("v")
    args.min_binary = args.min_binary.lstrip("v") or "0.0.0"
    args.min_supported = args.min_supported.lstrip("v")
    semver_key(v)
    check_floor("min-binary", args.min_binary, v)
    check_floor("min-supported", args.min_supported, v)
    channel = args.channel or ("beta" if "-" in v else "stable")
    dist, base = Path(args.dist), args.release_url.rstrip("/")
    notes = Path(args.notes).read_text().strip()[:500] if args.notes and Path(args.notes).exists() else ""
    manifest: dict = {
        "schema": 1, "channel": channel, "version": v,
        "released": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "notes": notes, "notes_url": args.notes_url or base.replace("/releases/download/", "/releases/tag/"),
        "engine": args.engine, "min_binary": args.min_binary, "min_supported": args.min_supported,
        "pack": None, "binaries": {}, "stores": STORES,
    }
    pck = dist / f"Diceroll-{v}-desktop.pck"
    if pck.exists():
        manifest["pack"] = {"url": f"{base}/{pck.name}", "sha256": sha256(pck), "size": pck.stat().st_size}
    for key, suffix in BINARIES.items():
        f = dist / f"Diceroll-{v}-{suffix}"
        if f.exists():
            manifest["binaries"][key] = {"url": f"{base}/{f.name}", "sha256": sha256(f), "size": f.stat().st_size}

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    channels = [channel] + (["beta"] if channel == "stable" else [])
    pem = os.environ.get("UPDATE_SIGNING_KEY", "")
    for ch in channels:
        data = (json.dumps({**manifest, "channel": ch}, indent=2) + "\n").encode()
        (out / f"update-{ch}.json").write_bytes(data)
        if pem.strip():
            (out / f"update-{ch}.json.sig").write_text(sign(data, pem))
        print(f"update_manifest: {out / f'update-{ch}.json'} ({'signed' if pem.strip() else 'UNSIGNED'})")


if __name__ == "__main__":
    main()
