#!/usr/bin/env python3
"""Writes the in-run meta icons (potion types, pet portraits) into ui/icons/ in the style of
ui/icons/gen_icons.py (24x24 SVG, #1B1530 outline 1.6, soft shade / highlight strokes).

Unlike most of the set these are multi-colour (fixed fills, nothing in the #FFFFFF tint slot
except white highlights), so draw them with UiIcons.tex(id, px, Color.WHITE).

    python3 ui/hud/gen_hud_icons.py ui/icons
"""
import math, os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "icons")
O = "#1B1530"
SW = 1.6


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">\n'
            + body + '\n</svg>\n')


def fill(d, color, w=SW, extra=""):
    return f'<path d="{d}" fill="{color}" stroke="{O}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"{extra}/>'


def circ(cx, cy, r, color, stroke=True, w=SW):
    s = f' stroke="{O}" stroke-width="{w}"' if stroke else ""
    return f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{r:.2f}" fill="{color}"{s}/>'


def ell(cx, cy, rx, ry, color, op=1.0):
    return f'<ellipse cx="{cx:.2f}" cy="{cy:.2f}" rx="{rx:.2f}" ry="{ry:.2f}" fill="{color}" fill-opacity="{op}"/>'


def shade(d, op=0.18):
    return f'<path d="{d}" fill="#000" fill-opacity="{op}"/>'


def hl(d, w=1.3, op=0.7):
    return f'<path d="{d}" fill="none" stroke="#fff" stroke-opacity="{op}" stroke-width="{w}" stroke-linecap="round"/>'


def stroke(d, color=O, w=1.2, op=1.0):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-opacity="{op}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'


def poly(pts):
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


def star_pts(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def eyes(cx, cy, gap, r=1.35):
    """Two cute eyes (dark with a white glint)."""
    out = ""
    for s in (-1, 1):
        x = cx + s * gap
        out += circ(x, cy, r, O, False) + circ(x - r * 0.35, cy - r * 0.4, r * 0.42, "#FFFFFF", False)
    return out


def blush(cx, cy, gap, color="#FF7A9A"):
    return ell(cx - gap, cy, 1.1, 0.6, color, 0.7) + ell(cx + gap, cy, 1.1, 0.6, color, 0.7)


ICONS = {}

# ---------------------------------------------------------------- potions (belt, shop)
GLASS = "#DDEBFF"
CORK = "#B9824A"
HEART = "M12 20.6s-8.2-4.9-8.2-11.1A4.6 4.6 0 0 1 12 6.7a4.6 4.6 0 0 1 8.2 2.8c0 6.2-8.2 11.1-8.2 11.1z"
SHIELD = "M12 2.9l7.6 2.9v5.7c0 4.7-3.2 8.3-7.6 9.7-4.4-1.4-7.6-5-7.6-9.7V5.8z"


def mini(path, cx, cy, s, color, w=1.1, ox=12, oy=12):
    return (f'<g transform="translate({cx} {cy}) scale({s}) translate({-ox} {-oy})">'
            f'<path d="{path}" fill="{color}" stroke="{O}" stroke-width="{w / s:.2f}" stroke-linejoin="round"/></g>')


def flask(liquid, dark, emblem, shape="round"):
    """Glass bottle (neck + cork) with `liquid` filling its lower part and `emblem` on top."""
    if shape == "round":
        body = "M10 4.6h4v4.1a6.9 6.9 0 1 1-4 0z"
        liq = "M5.2 13.2h13.6a6.9 6.9 0 1 1-13.6 0z"
        dk = "M18.8 13.2a6.9 6.9 0 0 1-9.2 7.4c4.4-.4 7.6-3.4 7.9-7.4z"
        gl = hl("M7.6 11.6a5 5 0 0 1 2-2.3", 1.2, 0.85)
        neck_y = 2.4
    elif shape == "square":
        body = "M10 4.6h4v2.6h2.4a2.4 2.4 0 0 1 2.4 2.4v9.2a2.4 2.4 0 0 1-2.4 2.4H7.6a2.4 2.4 0 0 1-2.4-2.4V9.6a2.4 2.4 0 0 1 2.4-2.4H10z"
        liq = "M5.2 12.2h13.6v6.6a2.4 2.4 0 0 1-2.4 2.4H7.6a2.4 2.4 0 0 1-2.4-2.4z"
        dk = "M18.8 12.2v6.6a2.4 2.4 0 0 1-2.4 2.4h-3c3-1 4.4-4.6 4.4-9z"
        gl = hl("M7.2 9.8v3", 1.2, 0.85)
        neck_y = 2.4
    elif shape == "vial":
        body = "M9.8 4.6h4.4v2.2l1.6 1.6v10.4a3.8 3.8 0 0 1-7.6 0V8.4l1.6-1.6z"
        liq = "M8.2 11.4h7.6v7.4a3.8 3.8 0 0 1-7.6 0z"
        dk = "M15.8 11.4v7.4a3.8 3.8 0 0 1-3.8 3.8c2-1.2 2.4-5.4 2.4-11.2z"
        gl = hl("M9.8 9.6v4.6", 1.1, 0.85)
        neck_y = 2.4
    else:  # drop-shaped flask
        body = "M10 4.6h4v3.6c3 2.4 5.6 5.4 5.6 8.6a7.6 7.6 0 0 1-15.2 0c0-3.2 2.6-6.2 5.6-8.6z"
        liq = "M4.6 14.4h14.8c.1.8.2 1.6.2 2.4a7.6 7.6 0 0 1-15.2 0c0-.8.1-1.6.2-2.4z"
        dk = "M19.6 16.8a7.6 7.6 0 0 1-9.8 7.2c4.8-.6 8.2-4 8.4-9.6.9 1 1.4 1.6 1.4 2.4z"
        gl = hl("M7.4 13.2a6 6 0 0 1 2.4-3.2", 1.2, 0.85)
        neck_y = 2.4
    out = fill(body, GLASS)
    out += f'<path d="{liq}" fill="{liquid}"/>' + shade(dk, 0.22)
    out += f'<path d="{body}" fill="none" stroke="{O}" stroke-width="{SW}" stroke-linejoin="round"/>'
    out += fill(f"M9.2 {neck_y}h5.6v2.8H9.2z", CORK, 1.3)
    out += gl + emblem
    return out


ICONS["potion_healing"] = flask("#EF4A5E", "#A81E36", mini(HEART, 12, 16.4, 0.36, "#FFE3E8"))
ICONS["potion_stoneskin"] = flask("#8C9CB4", "#55627A", mini(SHIELD, 12, 16.6, 0.36, "#8FC3FF"), "square")
TONIC_DIE = ('<rect x="9.7" y="13.4" width="4.6" height="4.6" rx="1.1" fill="#FFF3D0" stroke="%s" stroke-width="1"/>' % O
             + circ(10.9, 14.6, 0.55, O, False) + circ(12, 15.7, 0.55, O, False) + circ(13.1, 16.8, 0.55, O, False))
ICONS["potion_reroll_tonic"] = flask("#FFB52E", "#C26A0A", TONIC_DIE, "vial")
ICONS["potion_cleanse"] = flask("#5CD6FF", "#1E8FC4",
                                f'<path d="{poly(star_pts(12, 17.2, 3.0, 1.1, 4, -90))}" fill="#FFFFFF" stroke="{O}" stroke-width="0.9" stroke-linejoin="round"/>',
                                "drop")
# empty belt slot: a dashed bottle outline
ICONS["potion_empty"] = (f'<path d="M10 4.6h4v4.1a6.9 6.9 0 1 1-4 0z" fill="#FFFFFF" fill-opacity="0.08" stroke="#FFFFFF" stroke-opacity="0.45" stroke-width="1.3" stroke-dasharray="2 1.6" stroke-linejoin="round"/>')

# ---------------------------------------------------------------- pet portraits (HUD meter)
ORANGE = "#FF8A2A"
ICONS["pet_pumpkin_sprite"] = (
    fill("M11.4 5.6c-.2-1.6.4-2.8 1.8-3.4l.8 1c-.9.5-1.1 1.3-1 2.4z", "#4E8A34", 1.1)
    + fill("M12 5.6c4.8-1.2 9.2 1.8 9.2 7.2 0 5-4 8.4-9.2 8.4s-9.2-3.4-9.2-8.4c0-5.4 4.4-8.4 9.2-7.2z", ORANGE)
    + stroke("M12 6.2c-1.6 3-1.6 11.2 0 14.4M8 7c-2.2 3-2.2 10 0 13M16 7c2.2 3 2.2 10 0 13", "#B84A10", 1.0, 0.6)
    + shade("M17.4 6.8c2.4 1.4 3.8 3.6 3.8 6 0 5-4 8.4-9.2 8.4 5.2-2.8 6.6-8.6 5.4-14.4z", 0.16)
    + fill("M7.4 10.8l2.6.4-1.6 2.2z", "#FFE45A", 0.9) + fill("M16.6 10.8l-2.6.4 1.6 2.2z", "#FFE45A", 0.9)
    + fill("M7.6 15c1.4 1.4 2.8 2 4.4 2s3-.6 4.4-2l-1.2 2.4-1.2-.8-1 1.2-1-1.2-1 1.2-1-1.2-1.2.8z", "#FFE45A", 0.9)
    + hl("M6.2 9.6a4 4 0 0 1 2-2", 1.1, 0.6))

BONE = "#F2EAD8"
SKULL = "M12 2.8a8.2 8.2 0 0 0-8.2 8.2c0 2.8 1.4 4.7 3.1 5.7V20a1.2 1.2 0 0 0 1.2 1.2h7.8a1.2 1.2 0 0 0 1.2-1.2v-3.3c1.7-1 3.1-2.9 3.1-5.7A8.2 8.2 0 0 0 12 2.8z"
ICONS["pet_skull_buddy"] = (
    fill(SKULL, BONE)
    + shade("M16.2 4a8.2 8.2 0 0 1 3.9 7c0 2.8-1.4 4.7-3.1 5.7V20a1.2 1.2 0 0 1-1.2 1.2h-1.2c2.6-5.7 3.6-11.8 1.6-17.2z", 0.14)
    + ell(8.7, 11.8, 2.4, 2.6, O) + ell(15.3, 11.8, 2.4, 2.6, O)
    + circ(8.9, 11.9, 1.2, "#B6FF6A", False) + circ(15.1, 11.9, 1.2, "#B6FF6A", False)
    + circ(8.5, 11.4, 0.45, "#FFFFFF", False) + circ(14.7, 11.4, 0.45, "#FFFFFF", False)
    + f'<path d="M12 14.4l-1.1 2h2.2z" fill="{O}"/>'
    + stroke("M9.8 18.6v2.4M12 18.6v2.4M14.2 18.6v2.4", O, 1.1)
    + blush(12, 15.4, 5.4) + hl("M6.4 7.4a6 6 0 0 1 3-2.6", 1.1, 0.8))

CYAN = "#7DF9E0"
ICONS["pet_lantern_ghost"] = (
    fill("M9.4 2.4h5.2l.8 2.2H8.6z", "#4A3A5E", 1.1)
    + fill("M7 5h10a1.2 1.2 0 0 1 1.2 1.2V19a1.4 1.4 0 0 1-1.4 1.4H7.2A1.4 1.4 0 0 1 5.8 19V6.2A1.2 1.2 0 0 1 7 5z", "#3A2D4E")
    + f'<rect x="7.8" y="7" width="8.4" height="11.4" rx="1.4" fill="{CYAN}" fill-opacity="0.35"/>'
    + fill("M12 7.6c2.6 2 4 4.2 4 6.6a4 4 0 0 1-8 0c0-2.4 1.4-4.6 4-6.6z", CYAN, 1.1)
    + '<path d="M12 11.2c1.2 1 1.9 2 1.9 3.1a1.9 1.9 0 0 1-3.8 0c0-1.1.7-2.1 1.9-3.1z" fill="#FFFFFF" fill-opacity="0.6"/>'
    + eyes(12, 14.2, 1.6, 0.85)
    + fill("M5.4 20.2h13.2v1.8H5.4z", "#4A3A5E", 1.1)
    + hl("M7 7.4v6", 1.0, 0.5))

ICONS["pet_crystal_wisp"] = (
    fill("M5.6 12.2l2.4-4 2.4 4-2.4 6.6z", "#8A7CFF", 1.2)
    + fill("M18.4 12.2l-2.4-4-2.4 4 2.4 6.6z", "#8A7CFF", 1.2)
    + fill("M12 2.4l4.6 6.2-1 6.2L12 21.4 8.4 14.8l-1-6.2z", "#6FE3FF")
    + shade("M12 2.4l4.6 6.2-1 6.2L12 21.4z", 0.16)
    + stroke("M9.4 5.8l-1.6 2.8", "#FFFFFF", 1.0, 0.7)
    + eyes(12, 11.6, 1.8, 1.0) + blush(12, 13.4, 2.6)
    + circ(19.8, 4.4, 0.9, "#FFFFFF", False) + circ(4.4, 5.6, 0.6, "#FFFFFF", False))

DIE_BLUE = "#3E78E6"
ICONS["pet_guard_die"] = (
    '<rect x="3.6" y="4.2" width="16.8" height="16.8" rx="4.2" fill="%s" stroke="%s" stroke-width="%s"/>' % (DIE_BLUE, O, SW)
    + shade("M20.4 8.4v8.4a4.2 4.2 0 0 1-4.2 4.2H7.8c6.2-1.3 11.3-6.4 12.6-12.6z", 0.2)
    + eyes(12, 11.4, 3.0, 1.5)
    + stroke("M10.2 15.4c1.2.9 2.4.9 3.6 0", O, 1.2)
    + blush(12, 14.2, 4.8)
    + f'<path d="{poly(star_pts(18.6, 4.8, 3.2, 1.0, 4, -90))}" fill="#FFFFFF" stroke="{O}" stroke-width="0.8"/>'
    + hl("M6.4 6.4h3", 1.1, 0.7))

WOOD = "#B06A32"
ICONS["pet_coin_mimic"] = (
    fill("M3.4 12h17.2v7.4a1.6 1.6 0 0 1-1.6 1.6H5a1.6 1.6 0 0 1-1.6-1.6z", WOOD)
    + fill("M4.4 11.2l15.2-.6.6 1.6H3.8z", "#FFFFFF", 0.8)
    + f'<path d="M5 12.2l1.3 2 1.3-2 1.3 2 1.3-2 1.3 2 1.3-2 1.3 2 1.3-2 1.3 2 1.3-2 1.2 2V12.2z" fill="#FFFFFF" stroke="{O}" stroke-width="0.8" stroke-linejoin="round"/>'
    + fill("M3.8 11.4L3.4 7.2a4 4 0 0 1 4-3.6h9.2a4 4 0 0 1 4 3.6l-.4 4.2z", "#C87B3A")
    + stroke("M3.6 7.4h16.8", "#FFD24A", 1.3)
    + eyes(12, 8.6, 3.2, 1.3)
    + stroke("M7.4 6.4l2.6 1M16.6 6.4l-2.6 1", O, 1.1)
    + ell(12, 16.8, 2.8, 1.6, "#FF6F8C")
    + circ(20.2, 3.6, 2.0, "#FFD24A", True, 1.0) + circ(19.7, 3.1, 0.6, "#FFFFFF", False))

# ---------------------------------------------------------------- the six newer pets (WP-E4)
STONE = "#B8AC9E"
ICONS["pet_pebble_golem"] = (
    # amber thorns behind the shoulders
    fill("M5.6 9.4L3.2 6.6l3.8 1z", "#FFB066", 1.1) + fill("M18.4 9.4l2.4-2.8-3.8 1z", "#FFB066", 1.1)
    # the rock body
    + fill("M7.2 6.8l4.4-1.6 5 1.2 3 4.4-.6 5.8-3.6 3.4H8.4l-3.6-3.6-.4-5.2z", STONE)
    + shade("M16.6 6.4l3 4.4-.6 5.8-3.6 3.4h-3.2c3.8-2.6 5.4-7.6 4.4-13.6z", 0.18)
    + stroke("M9 7.6l1.4 2.2M15.4 16.6l1.6-.8", "#8A7E72", 1.0, 0.8)
    # gold ore, moss and a sprout
    + fill("M5.6 14.4l1.6-.8 1 1.4-1.2 1.2z", "#FFD24A", 0.9)
    + fill("M9 5.8c1.6-1.2 4.4-1.4 6.2-.2-1.6.8-4.4.9-6.2.2z", "#6CC04A", 1.0)
    + stroke("M12 5.6V3.4", "#3E7A2A", 1.2)
    + fill("M12 3.6c-.8-1.2-2.2-1.4-3-.8.8 1 2 1.2 3 .8zM12 3.6c.8-1.2 2.2-1.4 3-.8-.8 1-2 1.2-3 .8z", "#7FD65A", 0.8)
    # fists
    + fill("M2.2 14.6a1.9 1.9 0 1 1 3.4 1.8 1.9 1.9 0 0 1-3.4-1.8z", STONE, 1.2)
    + fill("M18.4 16.4a1.9 1.9 0 1 1 3.4-1.8 1.9 1.9 0 0 1-3.4 1.8z", STONE, 1.2)
    + eyes(12, 12, 2.4, 1.25) + blush(12, 14.2, 3.9) + circ(12, 15.2, 0.55, O, False))

ICE_BLUE = "#9FDBFF"
flake = ""
for k in range(6):
    a = math.radians(k * 60 - 90)
    x2, y2 = 12 + 9.4 * math.cos(a), 12 + 9.4 * math.sin(a)
    flake += stroke(f"M12 12L{x2:.2f} {y2:.2f}", O, 3.4)
    flake += stroke(f"M12 12L{x2:.2f} {y2:.2f}", ICE_BLUE, 1.6)
    bx, by = 12 + 7 * math.cos(a), 12 + 7 * math.sin(a)
    for s in (-1, 1):
        b = a + s * math.radians(45)
        flake += stroke(f"M{bx:.2f} {by:.2f}l{2.2 * math.cos(b):.2f} {2.2 * math.sin(b):.2f}", ICE_BLUE, 1.3)
ICONS["pet_frost_mote"] = (
    flake
    + circ(12, 12, 5.4, "#F4FAFF")
    + shade("M15.4 8a5.4 5.4 0 0 1-5.6 9.2c3.6-.8 5.8-4.6 5.6-9.2z", 0.12)
    + eyes(12, 11.6, 1.9, 1.05) + blush(12, 13.4, 3.0, "#FF9ABA")
    + hl("M8.6 10a3.6 3.6 0 0 1 1.8-2", 1.0, 0.9))

ICONS["pet_wick"] = (
    # the chamberstick dish and ring handle
    fill("M4.4 19.6h15.2l-1.4 2.2H5.8z", "#E8A94A", 1.3)
    + f'<circle cx="20.4" cy="19.2" r="1.5" fill="none" stroke="{O}" stroke-width="2.6"/>'
    + f'<circle cx="20.4" cy="19.2" r="1.5" fill="none" stroke="#E8A94A" stroke-width="1.1"/>'
    # the candle with drips
    + fill("M7.4 12.4h9.2v7.2H7.4z", "#FFF6EC")
    + fill("M7.4 12.2h9.2v1.6c-.6 0-.8 2.4-1.6 2.4s-.8-1.6-1.4-1.6-.6 2.8-1.4 2.8-.8-2.8-1.4-2.8-.8 1.4-1.6 1.4-.8-1.8-1.8-1.8z", "#FFFFFF", 1.1)
    + shade("M14.8 14.8h1.8v4.8h-1.8z", 0.12)
    + stroke("M12 12.4v-1", O, 1.2)
    # the flame with a face
    + fill("M12 1.8c1.2 2.4 4.6 4 4.6 7a4.6 4.6 0 0 1-9.2 0c0-2.6 2.2-3.2 3-4.6.4 1 .8 1.4 1.6 1.6z", "#FF7A1E")
    + '<path d="M12 6.4c.8 1.4 2.6 2 2.6 3.6a2.6 2.6 0 0 1-5.2 0c0-1.4 1.6-2.2 2.6-3.6z" fill="#FFD85A"/>'
    + eyes(12, 9.2, 1.5, 0.85)
    + blush(12, 17.2, 2.6))

TEAL = "#2BB5A0"
BRASS = "#E6B04E"

def gear_pts(cx, cy, r_out, r_in, n=8):
    """Gear outline: n square-ish teeth between radius r_in and r_out."""
    pts = []
    for k in range(n):
        a0 = math.radians(k * 360 / n)
        w = math.radians(360 / n / 4)
        for a, r in ((a0 - 2 * w, r_in), (a0 - w, r_out), (a0 + w, r_out), (a0 + 2 * w, r_in)):
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


cog = fill(poly(gear_pts(12, 5.4, 4.6, 3.3)), BRASS, 1.2)
ICONS["pet_tinker_gear"] = (
    cog + circ(12, 5.4, 1.3, O, False)
    # legs
    + stroke("M4.6 15.4l-2 1.2M5.4 18.4l-1.8 1.8M19.4 15.4l2 1.2M18.6 18.4l1.8 1.8", O, 1.6)
    # the jewel shell
    + fill("M3.8 16.4a8.2 7.4 0 0 1 16.4 0z", TEAL)
    + shade("M16.4 10.2a8.2 7.4 0 0 1 3.8 6.2h-3.4c.4-2.2.2-4.4-.4-6.2z", 0.2)
    + circ(8.2, 12.8, 1.0, "#FFE58A", True, 0.8) + circ(15.8, 12.8, 1.0, "#FFE58A", True, 0.8)
    + hl("M6.6 12.8a6 5 0 0 1 3-2.8", 1.1, 0.8)
    # head with goggle eyes
    + fill("M7.6 17.8a4.4 3.8 0 0 1 8.8 0 4.4 3.8 0 0 1-8.8 0z", "#3A3040")
    + circ(10.1, 17.6, 1.7, BRASS, True, 0.9) + circ(13.9, 17.6, 1.7, BRASS, True, 0.9)
    + circ(10.1, 17.6, 1.15, "#FFFFFF", False) + circ(13.9, 17.6, 1.15, "#FFFFFF", False)
    + eyes(12, 17.7, 1.9, 0.75)
    + stroke("M10.4 13.4L8.6 10.8M13.6 13.4l1.8-2.6", O, 1.0)
    + circ(8.4, 10.6, 0.8, BRASS, True, 0.8) + circ(15.6, 10.6, 0.8, BRASS, True, 0.8))

VIOLET = "#8A5CD6"
PAGE = "#FFF6E2"
ICONS["pet_grimoire"] = (
    # page wings
    fill("M6.2 8.6L1.4 6.2l.8 4.6-1 2.6 4.8 1.4z", PAGE, 1.2)
    + stroke("M5.6 10.4L2.6 9.6M5.6 12.6l-3.4-.4", "#B9A7D6", 0.9)
    + fill("M17.8 8.6l4.8-2.4-.8 4.6 1 2.6-4.8 1.4z", PAGE, 1.2)
    + stroke("M18.4 10.4l3-.8M18.4 12.6l3.4-.4", "#B9A7D6", 0.9)
    # the book
    + fill("M6.2 3.4h11.2a1.2 1.2 0 0 1 1.2 1.2v15.2a1.2 1.2 0 0 1-1.2 1.2H6.2z", VIOLET)
    + fill("M6.2 3.4h1.8v17.6H6.2z", "#5E3A9E", 1.2)
    + shade("M16.2 3.4h1.2a1.2 1.2 0 0 1 1.2 1.2v15.2a1.2 1.2 0 0 1-1.2 1.2h-1.2z", 0.18)
    + fill("M15.8 3.4h2.8v2.6z", "#D8D2E0", 1.0) + fill("M15.8 21h2.8v-2.6z", "#D8D2E0", 1.0)
    # the big eye in a gold rim
    + circ(12.6, 10.2, 3.9, "#FFD06A", True, 1.2)
    + circ(12.6, 10.2, 2.9, "#FFFFFF", False)
    + circ(12.6, 10.4, 1.8, "#9D5CFF", False) + circ(12.6, 10.4, 0.95, O, False)
    + circ(12.0, 9.7, 0.5, "#FFFFFF", False)
    + stroke("M10 6.2l-.6-1M12.6 5.6V4.5M15.2 6.2l.6-1", O, 0.9)
    # rune
    + f'<circle cx="12.6" cy="17" r="2.1" fill="none" stroke="#E7C6FF" stroke-width="1.0"/>'
    + f'<path d="M12.6 15.5l1.1 1.5-1.1 1.5-1.1-1.5z" fill="#E7C6FF"/>'
    # bookmark
    + fill("M9.2 21h1.6v2.2l-.8-.7-.8.7z", "#F0506A", 0.8))

POT = "#3C3548"
BREW = "#FF5CAE"
ICONS["pet_cauldron"] = (
    # ladle
    stroke("M14.6 10.4l4.4-8", O, 2.8) + stroke("M14.6 10.4l4.4-8", "#C88A4E", 1.2)
    # legs
    + fill("M6.6 19.2h2.4l-.4 2.6H7z", POT, 1.1) + fill("M15 19.2h2.4l-.4 2.6H15.4z", POT, 1.1)
    # the pot
    + fill("M3.2 11.6h17.6c0 5-3.8 8.6-8.8 8.6s-8.8-3.6-8.8-8.6z", POT)
    + shade("M17.8 11.6h3c0 5-3.8 8.6-8.8 8.6 3.6-1.6 5.6-4.6 5.8-8.6z", 0.22)
    + fill("M2.4 10.2h19.2a1.1 1.1 0 0 1 0 2.2H2.4a1.1 1.1 0 0 1 0-2.2z", "#5A5268", 1.3)
    # brew and bubbles
    + ell(12, 10.6, 8.4, 1.2, BREW)
    + circ(8.8, 8.2, 1.5, "#FFB6DA", True, 1.0) + circ(12.4, 6.4, 1.1, "#FFB6DA", True, 1.0)
    + circ(15.6, 7.8, 0.8, "#FFB6DA", True, 0.9)
    + circ(8.4, 7.8, 0.45, "#FFFFFF", False)
    # face
    + eyes(12, 14.6, 2.6, 1.15) + blush(12, 16.4, 4.2)
    + stroke("M11.2 17c.5.4 1.1.4 1.6 0", "#FFFFFF", 0.9, 0.9)
    + hl("M5.4 14a6.6 6 0 0 0 1.6 3", 1.1, 0.4))

os.makedirs(OUT, exist_ok=True)
for name, body in ICONS.items():
    with open(os.path.join(OUT, name + ".svg"), "w") as fh:
        fh.write(svg(body))
    with open(os.path.join(OUT, name + ".svg.import"), "w") as fh:
        fh.write('[remap]\n\nimporter="keep"\n')
print(len(ICONS), "hud icons")
