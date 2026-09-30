#!/usr/bin/env python3
"""Copies the RhosGFX SVGs the game references from third_party/ into the runtime folders
(called by tools/import_assets.sh; see docs/design/2026-09-30-svg-ui-pipeline.md).

  referenced = every "svg" (at any depth: "icons", "input_glyphs", ...) in
               ui/icons/icon_map.json + ui/icons/icon_map.demo.json                   -> assets/ui/icons/
             + every "svg" (at any depth) in ui/theme/ui_pack.json                    -> assets/ui/pack/

Runtime name = sanitize(<path relative to third_party/>), the rule UiSvg.sanitize() applies in
GDScript: drop a leading "rhosgfx/", lowercase, every run of characters outside [a-z0-9-] in a
path segment becomes "_" (extension kept, "_" trimmed). Each copy gets a `keep` .import
sidecar (Godot ships the raw SVG; UiSvg rasterises it at runtime as a DPITexture).
Godot's SVG rasteriser (ThorVG) drops <text> elements, so every imported file is scanned and
each one with text is reported; an entry with "strip_text": true (e.g. a keyboard keycap used as
a blank background) is imported with its <text> removed.
Only referenced files are kept: anything else under the two roots is deleted (stale), so the
folders are a deterministic function of the manifests. Missing sources are warnings.

Usage: tools/import_ui_svgs.py [--root DIR] [--third-party DIR] [--quiet]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

IMPORT_KEEP = '[remap]\n\nimporter="keep"\n'
ROOTS = {"icons": "assets/ui/icons", "pack": "assets/ui/pack"}
ICON_MAPS = ["ui/icons/icon_map.json", "ui/icons/icon_map.demo.json"]
PACK_MANIFEST = "ui/theme/ui_pack.json"
_SEG = re.compile(r"[^a-z0-9-]+")


def sanitize(tp_path: str) -> str:
    p = tp_path.strip().replace("\\", "/")
    if p.startswith("rhosgfx/"):
        p = p[len("rhosgfx/"):]
    segs = [s for s in p.split("/") if s]
    out = []
    for i, s in enumerate(segs):
        s = s.lower()
        ext = ""
        if i == len(segs) - 1:
            stem, dot, e = s.rpartition(".")
            if dot and stem:
                s, ext = stem, "." + e
        out.append(_SEG.sub("_", s).strip("_") + ext)
    return "/".join(out)


def _svgs(node) -> list[tuple[str, bool]]:
    """Every (svg path, strip_text) in a JSON tree: dicts with a string "svg" value."""
    out = []
    if isinstance(node, dict):
        v = node.get("svg")
        if isinstance(v, str) and v.strip():
            out.append((v, bool(node.get("strip_text", False))))
        for k, v in node.items():
            if k != "svg":
                out.extend(_svgs(v))
    elif isinstance(node, list):
        for v in node:
            out.extend(_svgs(v))
    return out


_TEXT = re.compile(rb"<text\b[^>]*/>|<text\b.*?</text\s*>", re.S)


def strip_text(svg: bytes) -> bytes:
    """Removes <text> elements (ThorVG renders none of them anyway)."""
    return _TEXT.sub(b"", svg)


def _load(path: Path):
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"   warning: unreadable {path}: {e}", file=sys.stderr)
        return None


def referenced(root: Path) -> dict[str, dict[str, bool]]:
    """kind -> {svg path: strip_text} (strip wins when a file is listed both ways)."""
    refs: dict[str, dict[str, bool]] = {"icons": {}, "pack": {}}
    sources = [(rel, "icons", None) for rel in ICON_MAPS] + [(PACK_MANIFEST, "pack", "pieces")]
    for rel, kind, section in sources:
        data = _load(root / rel)
        if not isinstance(data, dict):
            continue
        for svg, strip in _svgs(data.get(section, {}) if section else data):
            refs[kind][svg] = refs[kind].get(svg, False) or strip
    return refs


def _write_if_changed(dst: Path, data: bytes) -> bool:
    if dst.is_file() and dst.read_bytes() == data:
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(data)
    return True


def run(root: Path, tp: Path, quiet: bool = False) -> int:
    refs = referenced(root)
    missing = copied = removed = 0
    texty: list[str] = []
    for kind, base_rel in ROOTS.items():
        base = root / base_rel
        keep: dict[Path, str] = {}
        for src_rel in sorted(refs[kind]):
            dst = base / sanitize(src_rel)
            if dst in keep and keep[dst] != src_rel:
                print(f"   warning: {src_rel} and {keep[dst]} both map to {dst.relative_to(root)}", file=sys.stderr)
                continue
            keep[dst] = src_rel
            src = tp / src_rel
            if not src.is_file():
                missing += 1
                print(f"   warning: missing {src} (that {kind[:-1] if kind == 'icons' else 'piece'} keeps its current look)",
                      file=sys.stderr)
                continue
            data = src.read_bytes()
            if _TEXT.search(data):
                if refs[kind][src_rel]:
                    data = strip_text(data)
                else:
                    texty.append(src_rel)
            copied += _write_if_changed(dst, data)
            _write_if_changed(dst.with_name(dst.name + ".import"), IMPORT_KEEP.encode())
        wanted = set(keep) | {p.with_name(p.name + ".import") for p in keep}
        if base.is_dir():
            for p in sorted(base.rglob("*"), reverse=True):
                if p.is_file() and p not in wanted:
                    p.unlink()
                    removed += 1
                elif p.is_dir() and not any(p.iterdir()):
                    p.rmdir()
    for t in texty:
        print(f"   warning: {t} draws <text>, which Godot's SVG rasteriser drops (it renders blank); "
              f'add "strip_text": true to use it as a blank background', file=sys.stderr)
    if not quiet:
        n = len(refs["icons"]) + len(refs["pack"])
        print(f"   {len(refs['icons'])} icons + {len(refs['pack'])} pack pieces referenced: "
              f"{copied} copied, {removed} stale files removed, {missing} missing (of {n}), "
              f"{len(texty)} with <text>")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    here = Path(__file__).resolve().parents[1]
    ap.add_argument("--root", type=Path, default=here)
    ap.add_argument("--third-party", type=Path, default=Path(os.environ.get("THIRD_PARTY", here / "third_party")))
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()
    return run(a.root.resolve(), a.third_party.resolve(), a.quiet)


if __name__ == "__main__":
    sys.exit(main())
