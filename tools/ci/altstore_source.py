#!/usr/bin/env python3
"""Updates the AltStore / SideStore source (the JSON users add to receive Diceroll updates).

  tools/ci/altstore_source.py --version 0.2.0 --build 20099 --ipa dist/Diceroll-0.2.0-ios-sideload.ipa
                              --download-url URL --notes store/ios_whats_new.txt
                              [--existing old-source.json] --out channels/altstore-source.json

Format: AltStore source v2 (https://faq.altstore.io/developers/make-a-source), which SideStore
reads too. The newest version goes first in apps[0].versions; older ones are kept (capped) so
users can downgrade. Published as an asset of the rolling "channels" GitHub release, i.e.
  https://github.com/vladzaharia/diceroll/releases/download/channels/altstore-source.json
(stable) and altstore-source-beta.json (pre-releases). The IPA is the unsigned sideload build:
AltStore/SideStore re-sign it with the user's Apple ID.
"""

from __future__ import annotations

import argparse
import datetime
import json
from pathlib import Path

REPO = "https://github.com/vladzaharia/diceroll"
RAW = "https://raw.githubusercontent.com/vladzaharia/diceroll/main"
MAX_VERSIONS = 20
TINT = "E4572E"

DESCRIPTION = (
    "Diceroll is a cozy dice-rolling roguelite board game. Roll your dice to move around the "
    "board, fight monsters with combos, collect runes and gear, and grow your camp between runs. "
    "Built with Godot; open source under the MIT license."
)


def base_source(beta: bool) -> dict:
    return {
        "name": "Diceroll" + (" (beta)" if beta else ""),
        "identifier": "gg.vlad.diceroll.source" + (".beta" if beta else ""),
        "subtitle": "Dice-rolling roguelite board game",
        "description": DESCRIPTION,
        "iconURL": f"{RAW}/assets/icon/icon.png",
        "website": REPO,
        "tintColor": TINT,
        "featuredApps": ["gg.vlad.diceroll"],
        "apps": [
            {
                "name": "Diceroll",
                "bundleIdentifier": "gg.vlad.diceroll",
                "developerName": "Vlad Zaharia",
                "subtitle": "Roll, move, fight, loot.",
                "localizedDescription": DESCRIPTION,
                "iconURL": f"{RAW}/assets/icon/icon.png",
                "tintColor": TINT,
                "category": "games",
                "screenshots": [f"{RAW}/docs/media/{n}" for n in ("board.png", "combat.png", "camp.png")],
                "appPermissions": {"entitlements": [], "privacy": {}},
                "versions": [],
            }
        ],
        "news": [],
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--build", required=True)
    ap.add_argument("--ipa", required=True)
    ap.add_argument("--download-url", required=True)
    ap.add_argument("--notes")
    ap.add_argument("--existing")
    ap.add_argument("--min-os", default="15.0")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    beta = "-" in args.version
    source = base_source(beta)
    if args.existing and Path(args.existing).exists():
        try:
            old = json.loads(Path(args.existing).read_text())
            source["apps"][0]["versions"] = old["apps"][0].get("versions", [])
            source["news"] = old.get("news", [])
        except (json.JSONDecodeError, KeyError, IndexError):
            print("altstore_source: existing source unreadable, starting fresh")
    notes = Path(args.notes).read_text().strip() if args.notes and Path(args.notes).exists() else ""
    entry = {
        "version": args.version.split("-")[0],  # CFBundleShortVersionString
        "buildVersion": str(args.build),         # CFBundleVersion
        "marketingVersion": args.version,
        "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "localizedDescription": notes or f"Diceroll {args.version}",
        "downloadURL": args.download_url,
        "size": Path(args.ipa).stat().st_size,
        "minOSVersion": args.min_os,
    }
    versions = [v for v in source["apps"][0]["versions"] if v.get("buildVersion") != entry["buildVersion"]]
    source["apps"][0]["versions"] = [entry] + versions[: MAX_VERSIONS - 1]
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(source, indent=2) + "\n")
    print(f"altstore_source: {out} ({len(source['apps'][0]['versions'])} versions, latest {args.version})")


if __name__ == "__main__":
    main()
