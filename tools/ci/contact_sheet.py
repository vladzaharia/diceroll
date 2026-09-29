#!/usr/bin/env python3
"""Builds a self-contained HTML contact sheet (index.html) for a CI screenshot directory.

  tools/ci/contact_sheet.py DIR [--title T] [--diff DIR/diff/diff.json]

Groups DIR/<scenario>__<device>.png by scenario, shows the device, resolution and status from
DIR/results.tsv, and (report-only) the visual-diff fraction against the baseline from
tools/ci/img_diff.gd, with a link to the magenta diff image. Also writes DIR/summary.md for the
GitHub job summary. Stdlib only.
"""

from __future__ import annotations

import argparse
import csv
import html
import json
from collections import defaultdict
from pathlib import Path

CSS = """
body{font:14px/1.4 system-ui,sans-serif;margin:0;padding:16px;background:#15101a;color:#eee}
h1{font-size:20px;margin:0 0 4px}h2{font-size:16px;margin:24px 0 8px;border-bottom:1px solid #333}
.meta{color:#aaa;margin-bottom:12px}.grid{display:flex;flex-wrap:wrap;gap:12px;align-items:flex-start}
figure{margin:0;background:#221a2a;border-radius:8px;padding:8px;max-width:340px}
figure img{display:block;max-width:320px;max-height:320px;border-radius:4px;background:#000}
figcaption{font-size:12px;margin-top:6px;color:#ccc}.fail{color:#ff6b6b;font-weight:bold}
.warn{color:#ffd166}.ok{color:#7bd389}a{color:#9ecbff}
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--title", default="Diceroll screenshots")
    ap.add_argument("--diff", default=None, help="diff.json from tools/ci/img_diff.gd")
    ap.add_argument("--warn", type=float, default=0.02, help="diff fraction flagged as changed")
    args = ap.parse_args()
    root = Path(args.dir)
    results = {}
    tsv = root / "results.tsv"
    if tsv.exists():
        with tsv.open() as f:
            for row in csv.DictReader(f, delimiter="\t"):
                results[f"{row['scenario']}__{row['device']}.png"] = row
    diff_path = Path(args.diff) if args.diff else root / "diff" / "diff.json"
    diffs = json.loads(diff_path.read_text()) if diff_path.exists() else {}

    groups: dict[str, list[str]] = defaultdict(list)
    names = sorted({p.name for p in root.glob("*.png")} | set(results))
    for name in names:
        groups[name.split("__")[0]].append(name)

    failed = [n for n, r in results.items() if r["status"] != "ok"]
    changed = [n for n, d in diffs.items() if d.get("changed", 0) > args.warn]
    parts = [f"<!doctype html><meta charset=utf-8><title>{html.escape(args.title)}</title><style>{CSS}</style>",
             f"<h1>{html.escape(args.title)}</h1>",
             f"<div class=meta>{len(names)} shots, {len(failed)} failed"
             + (f", {len(changed)} visually changed vs baseline (&gt;{args.warn:.0%} pixels)" if diffs else ", no baseline")
             + "</div>"]
    for scenario, files in groups.items():
        parts.append(f"<h2>{html.escape(scenario)}</h2><div class=grid>")
        for name in files:
            r = results.get(name, {})
            device = r.get("device") or name.split("__", 1)[-1][:-4]
            status = r.get("status", "ok" if (root / name).exists() else "missing")
            cls = "ok" if status == "ok" else "fail"
            cap = f"<b>{html.escape(device)}</b> {html.escape(r.get('resolution', ''))} <span class={cls}>{status}</span>"
            if r.get("seconds"):
                cap += f" · {r['seconds']}s"
            d = diffs.get(name)
            if d:
                if d.get("new"):
                    cap += " · <span class=warn>new</span>"
                else:
                    frac = d.get("changed", 0)
                    dcls = "warn" if frac > args.warn else "ok"
                    diff_img = f"diff/{name[:-4]}.diff.png"
                    cap += f" · <a class={dcls} href='{html.escape(diff_img)}'>diff {frac:.1%}</a>"
            img = f"<a href='{html.escape(name)}'><img loading=lazy src='{html.escape(name)}' alt=''></a>" if (root / name).exists() else "<div class=fail>no image</div>"
            parts.append(f"<figure>{img}<figcaption>{cap}</figcaption></figure>")
        parts.append("</div>")
    (root / "index.html").write_text("\n".join(parts))

    md = [f"### {args.title}", f"{len(names)} shots, **{len(failed)} failed**"
          + (f", {len(changed)} changed vs baseline (report-only)" if diffs else "")]
    for n in failed:
        md.append(f"- failed: `{n}` ({results[n]['status']})")
    for n in changed[:30]:
        md.append(f"- changed: `{n}` ({diffs[n]['changed']:.1%})")
    (root / "summary.md").write_text("\n".join(md) + "\n")
    print(f"contact sheet: {root / 'index.html'} ({len(names)} shots, {len(failed)} failed, {len(changed)} changed)")


if __name__ == "__main__":
    main()
