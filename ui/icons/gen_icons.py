#!/usr/bin/env python3
"""Writes the Diceroll UI icon set (24x24 SVG) into ui/icons/.

Style rules (keep every icon consistent):
  * #FFFFFF is the TINT SLOT: UiIcons replaces it with the requested colour at load time.
  * #1B1530 is the outline (1.6 stroke on filled shapes, +3.2 underlay on line icons).
  * white/black shapes with opacity are highlights / shading and are never tinted.
"""
import math, os, sys

OUT = sys.argv[1]
F = "#FFFFFF"
O = "#1B1530"
SW = 1.6


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">\n'
            + body + '\n</svg>\n')


def fill(d, extra=""):
    return f'<path d="{d}" fill="{F}" stroke="{O}" stroke-width="{SW}" stroke-linejoin="round" stroke-linecap="round"{extra}/>'


def circ(cx, cy, r, color=F, stroke=True):
    s = f' stroke="{O}" stroke-width="{SW}"' if stroke else ""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}"{s}/>'


def dark(d):
    return f'<path d="{d}" fill="{O}"/>'


def hl(d, w=1.4, op=0.6):
    return f'<path d="{d}" fill="none" stroke="#fff" stroke-opacity="{op}" stroke-width="{w}" stroke-linecap="round"/>'


def shade(d, op=0.18):
    return f'<path d="{d}" fill="#000" fill-opacity="{op}"/>'


def lines(ds, w=2.6, fills=()):
    """Double-stroked line art: dark underlay first, then the tint stroke on top."""
    under = "".join(f'<path d="{d}" fill="none" stroke="{O}" stroke-width="{w + 3.2}" stroke-linecap="round" stroke-linejoin="round"/>' for d in ds)
    under += "".join(f'<path d="{d}" fill="{O}" stroke="{O}" stroke-width="3.2" stroke-linejoin="round"/>' for d in fills)
    over = "".join(f'<path d="{d}" fill="none" stroke="{F}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>' for d in ds)
    over += "".join(f'<path d="{d}" fill="{F}"/>' for d in fills)
    return under + over


def poly(pts):
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


def star_pts(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def gear_path(cx, cy, r_out, r_in, teeth=8):
    pts = []
    step = 360 / teeth
    for i in range(teeth):
        a0 = i * step
        for da, r in ((-step * 0.22, r_out), (step * 0.22, r_out), (step * 0.30, r_in), (step * 0.70, r_in)):
            a = math.radians(a0 + da)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


ICONS = {}

# ---------------------------------------------------------------- stats & resources
HEART = "M12 20.6s-8.2-4.9-8.2-11.1A4.6 4.6 0 0 1 12 6.7a4.6 4.6 0 0 1 8.2 2.8c0 6.2-8.2 11.1-8.2 11.1z"
ICONS["heart"] = fill(HEART) + shade("M12 20.6s8.2-4.9 8.2-11.1a4.6 4.6 0 0 0-3-4.3c1.2 5.6-2.4 11-5.2 15.4z", 0.16) + hl("M6.6 9.2a2.4 2.4 0 0 1 2.6-1.7")
# Wardrobe (Camp skins): a coat hanger
ICONS["wardrobe"] = (lines(["M12 7.6V6.2a2 2 0 1 1 2 2", "M12 8.4L3 16.6h18z"], 2.2)
                     + fill("M4.6 16.6h14.8v2.6H4.6z") + shade("M12 16.6h7.4v2.6H12z", 0.16))

ICONS["coin"] = (circ(12, 12, 8.6) + shade("M18.1 6a8.6 8.6 0 0 1-12.1 12.1A8.6 8.6 0 0 0 18.1 6z", 0.2)
                 + f'<circle cx="12" cy="12" r="5.7" fill="none" stroke="{O}" stroke-opacity="0.45" stroke-width="1.3"/>'
                 + f'<path d="{poly(star_pts(12, 12.3, 3.6, 1.6))}" fill="{O}" fill-opacity="0.45"/>' + hl("M7.3 9.4a5 5 0 0 1 2.4-2.6"))

SHIELD = "M12 2.9l7.6 2.9v5.7c0 4.7-3.2 8.3-7.6 9.7-4.4-1.4-7.6-5-7.6-9.7V5.8z"
ICONS["shield"] = fill(SHIELD) + shade("M12 2.9v18.3c4.4-1.4 7.6-5 7.6-9.7V5.8z") + hl("M7.4 7.4v3.8")

SWORD = [
    fill("M20.6 3.4v3.3l-9.3 9.3-3.3-3.3 9.3-9.3z"),
    shade("M20.6 3.4v3.3l-9.3 9.3-1.65-1.65z"),
    fill("M4.9 11.6l7.5 7.5-1.6 1.6-7.5-7.5z"),
    fill("M8.6 17.2l-3.4 3.4-1.8-1.8 3.4-3.4z"),
]
ICONS["sword"] = "".join(SWORD)

DROP = "M12 2.9c3.6 4.6 6.2 8 6.2 11.2a6.2 6.2 0 0 1-12.4 0c0-3.2 2.6-6.6 6.2-11.2z"
ICONS["poison"] = fill(DROP) + shade("M18.2 14.1a6.2 6.2 0 0 1-9.9 5c4.3.2 7.3-2.8 7.2-7.6 1.6 1 2.7 1.7 2.7 2.6z") + hl("M9.1 13.4a3.2 3.2 0 0 0 1 3.4")

snow = []
for k in range(3):
    a = math.radians(90 + k * 60)
    dx, dy = 8.6 * math.cos(a), 8.6 * math.sin(a)
    snow.append(f"M{12 - dx:.2f} {12 - dy:.2f} L{12 + dx:.2f} {12 + dy:.2f}")
for k in range(6):
    a = math.radians(-90 + k * 60)
    px, py = 12 + 5.6 * math.cos(a), 12 + 5.6 * math.sin(a)
    for s in (-1, 1):
        b = a + s * math.radians(40) + math.pi
        snow.append(f"M{px:.2f} {py:.2f} L{px - 2.7 * math.cos(b):.2f} {py - 2.7 * math.sin(b):.2f}")
ICONS["snowflake"] = lines(snow, 2.1)

FLAME = "M12 2.6c.9 3.3 5.8 5.4 5.8 10.4A5.8 5.8 0 0 1 12 21a5.8 5.8 0 0 1-5.8-5.9c0-2.5 1.5-4.1 2.5-5.2.2 1.9 1 3 2.1 3.6-.3-3.1.3-5.8 1.2-8.9z"
ICONS["flame"] = fill(FLAME) + '<path d="M12 12.9c1.5 1.5 2.7 2.7 2.7 4.4a2.7 2.7 0 0 1-5.4 0c0-1.7 1.2-2.9 2.7-4.4z" fill="#fff" fill-opacity="0.55"/>'

BOLT = "M14 2.4L4.8 13.6h6.1l-1.6 8 9.9-12.1h-6.3z"
ICONS["bolt"] = fill(BOLT) + shade("M13.3 9.5h6l-9.9 12.1z", 0.16)

SKULL = "M12 2.8a8.2 8.2 0 0 0-8.2 8.2c0 2.8 1.4 4.7 3.1 5.7V20a1.2 1.2 0 0 0 1.2 1.2h7.8a1.2 1.2 0 0 0 1.2-1.2v-3.3c1.7-1 3.1-2.9 3.1-5.7A8.2 8.2 0 0 0 12 2.8z"
ICONS["skull"] = (fill(SKULL) + shade("M16.2 4a8.2 8.2 0 0 1 3.9 7c0 2.8-1.4 4.7-3.1 5.7V20a1.2 1.2 0 0 1-1.2 1.2h-1.2c2.6-5.7 3.6-11.8 1.6-17.2z", 0.16)
                  + circ(8.7, 11.6, 2.2, O, False) + circ(15.3, 11.6, 2.2, O, False) + dark("M12 14.1l-1.3 2.3h2.6z")
                  + f'<path d="M10.2 18.4v2.6M13.8 18.4v2.6" stroke="{O}" stroke-width="1.3"/>')

LOCK_BODY = "M5.2 10.4h13.6a1.4 1.4 0 0 1 1.4 1.4v7.8a1.6 1.6 0 0 1-1.6 1.6H5.4a1.6 1.6 0 0 1-1.6-1.6v-7.8a1.4 1.4 0 0 1 1.4-1.4z"
ICONS["curse"] = (lines(["M8 10.4V7.7a4 4 0 0 1 8 0v2.7"], 2.4) + fill(LOCK_BODY)
                  + shade("M12 10.4h6.8a1.4 1.4 0 0 1 1.4 1.4v7.8a1.6 1.6 0 0 1-1.6 1.6H12z", 0.14)
                  + circ(12, 14.6, 1.7, O, False) + dark("M11.2 15.2h1.6l.5 3h-2.6z"))

ICONS["dice"] = (f'<rect x="3.4" y="3.4" width="17.2" height="17.2" rx="4.2" fill="{F}" stroke="{O}" stroke-width="{SW}"/>'
                 + shade("M20.6 7.6v8.8a4.2 4.2 0 0 1-4.2 4.2H7.6c6.2-1.3 11.7-6.8 13-13z", 0.14)
                 + circ(8.3, 8.3, 1.75, O, False) + circ(12, 12, 1.75, O, False) + circ(15.7, 15.7, 1.75, O, False)
                 + hl("M6.2 5.7h3.2", 1.2, 0.6))

STAR = poly(star_pts(12, 12.6, 9.6, 4.3))
ICONS["star"] = fill(STAR) + shade(poly([(12, 12.6)] + star_pts(12, 12.6, 9.6, 4.3)[1:5]), 0.14)

ICONS["xp"] = (fill("M12 2.8l7.4 6.4L12 21.4 4.6 9.2z") + shade("M12 2.8l7.4 6.4L12 21.4z", 0.16)
               + f'<path d="M4.6 9.2h14.8M9.2 9.2L12 21.4l2.8-12.2L12 2.8z" fill="none" stroke="{O}" stroke-opacity="0.5" stroke-width="1" stroke-linejoin="round"/>'
               + hl("M7.3 8.6l2.6-3", 1.2))


def arc_arrow():
    arcs = ["M18.58 9.61 A7 7 0 0 0 5.42 9.61", "M5.42 14.39 A7 7 0 0 0 18.58 14.39"]
    heads = [poly([(4.4, 12.4), (8.3, 10.6), (2.7, 8.6)]), poly([(19.6, 11.6), (15.7, 13.4), (21.3, 15.4)])]
    return lines(arcs, 2.5, heads)


ICONS["reroll"] = arc_arrow()

# ---------------------------------------------------------------- rune glyphs
ICONS["rune_blade"] = (fill("M12 2.4l2.3 3.1v9.2H9.7V5.5z") + shade("M12 2.4l2.3 3.1v9.2H12z", 0.16)
                       + fill("M7.3 14.4h9.4v2.2H7.3z") + fill("M10.9 16.6h2.2v3.6h-2.2z") + circ(12, 21.1, 1.3))
ICONS["rune_guard"] = (fill(SHIELD) + shade("M12 2.9v18.3c4.4-1.4 7.6-5 7.6-9.7V5.8z")
                       + f'<path d="M12 6.8v10.4M7.8 10.6h8.4" stroke="{O}" stroke-width="1.8" stroke-linecap="round"/>')
ICONS["rune_venom"] = (fill("M10.6 4.4c3.3 4.2 5.7 7.3 5.7 10.3a5.7 5.7 0 0 1-11.4 0c0-3 2.4-6.1 5.7-10.3z")
                       + circ(18.3, 6.2, 2.1) + circ(16.8, 2.9, 1.2) + hl("M8.1 14.2a3 3 0 0 0 .9 3.1"))
ICONS["rune_gilded"] = (fill("M4.1 17.6L3 8.2l5.2 4.1L12 5l3.8 7.3L21 8.2l-1.1 9.4z") + fill("M4.1 17.6h15.8v2.9H4.1z")
                        + circ(12, 5, 1.6) + circ(3, 8.2, 1.4) + circ(21, 8.2, 1.4) + shade("M12 5l3.8 7.3L21 8.2l-1.1 9.4H12z", 0.14))
ICONS["rune_heavy"] = (lines(["M9 8.4a3 3 0 0 1 6 0"], 2.4) + fill("M7.3 8.6h9.4l3.2 11.2a1.2 1.2 0 0 1-1.2 1.5H5.3a1.2 1.2 0 0 1-1.2-1.5z")
                       + shade("M12 8.6h4.7l3.2 11.2a1.2 1.2 0 0 1-1.2 1.5H12z", 0.16)
                       + f'<path d="M8.4 15h7.2" stroke="{O}" stroke-width="1.6" stroke-linecap="round"/>')
ICONS["rune_ember"] = ICONS["flame"]
ICONS["rune_vampire"] = fill(poly([(12.0, 18.98), (9.95, 15.34), (7.78, 17.39), (6.87, 14.31), (4.02, 15.22), (4.25, 12.14), (0.83, 11.46), (3.22, 8.5), (8.58, 8.84), (9.72, 5.53), (11.2, 7.93), (12.8, 7.93), (14.28, 5.53), (15.42, 8.84), (20.78, 8.5), (23.17, 11.46), (19.75, 12.14), (19.98, 15.22), (17.13, 14.31), (16.22, 17.39), (14.05, 15.34)])) \
    + circ(10.8, 10.8, 0.85, O, False) + circ(13.2, 10.8, 0.85, O, False)
ICONS["rune_lucky"] = (lines(["M15.4 15.4 Q17.6 18.4 20.2 19.6"], 2.0)
                       + "".join(circ(x, y, 4.4, O, False) for x, y in ((8.6, 8.6), (15.4, 8.6), (8.6, 15.4), (15.4, 15.4)))
                       + "".join(circ(x, y, 3.6, F, False) for x, y in ((8.6, 8.6), (15.4, 8.6), (8.6, 15.4), (15.4, 15.4)))
                       + f'<path d="M12 5.8v12.4M5.8 12h12.4" stroke="{O}" stroke-opacity="0.35" stroke-width="1"/>'
                       + hl("M6.6 7.8a2.2 2.2 0 0 1 1.4-1.6", 1.1))
ICONS["rune_frost"] = ICONS["snowflake"]
ICONS["rune_thunder"] = ICONS["bolt"]
ICONS["rune_echo"] = lines(["M4 12h.01", "M8.2 7.8a6 6 0 0 1 0 8.4", "M12 4.6a10.4 10.4 0 0 1 0 14.8", "M15.8 1.9a14.2 14.2 0 0 1 0 20.2"], 2.2)
SPARK = "M12 2.3c1 5.4 4.3 8.7 9.7 9.7-5.4 1-8.7 4.3-9.7 9.7-1-5.4-4.3-8.7-9.7-9.7 5.4-1 8.7-4.3 9.7-9.7z"
ICONS["rune_wild"] = fill(SPARK) + shade("M12 2.3c1 5.4 4.3 8.7 9.7 9.7-5.4 1-8.7 4.3-9.7 9.7z", 0.14) + fill(poly(star_pts(19.3, 4.7, 2.6, 1.1, 4, -90)))

# ---------------------------------------------------------------- intents
ICONS["intent_attack"] = ICONS["sword"]
ICONS["intent_block"] = ICONS["shield"]
ICONS["intent_buff"] = fill("M12 2.8l7.6 8h-4.4v10.4H8.8V10.8H4.4z") + shade("M12 2.8l7.6 8h-4.4v10.4H12z", 0.16)
ICONS["intent_curse"] = ICONS["curse"]
GHOST = "M5.4 21.2V11a6.6 6.6 0 0 1 13.2 0v10.2l-2.2-1.8-2.2 1.8-2.2-1.8-2.2 1.8-2.2-1.8z"
ICONS["intent_summon"] = (fill(GHOST) + shade("M15.6 5.2a6.6 6.6 0 0 1 3 5.8v10.2l-2.2-1.8-1.6 1.3c1.6-5 1.8-10.4.8-15.5z", 0.16)
                          + '<ellipse cx="9.6" cy="11" rx="1.3" ry="1.8" fill="%s"/><ellipse cx="14.4" cy="11" rx="1.3" ry="1.8" fill="%s"/>' % (O, O))
ICONS["intent_chaos"] = lines(["M12 12 A1.5 1.5 0 0 1 15 12 A3 3 0 0 1 9 12 A4.5 4.5 0 0 1 18 12 A6 6 0 0 1 6 12 A7.5 7.5 0 0 1 19.5 12"], 2.1)
ICONS["intent_aim"] = lines(["M12 5.5a6.5 6.5 0 1 1 0 13a6.5 6.5 0 1 1 0-13z", "M12 2.2v3.2M12 18.6v3.2M2.2 12h3.2M18.6 12h3.2"], 2.1) + circ(12, 12, 1.8)

# ---------------------------------------------------------------- classes & misc
ICONS["axe"] = (lines(["M4.6 20.6L15.6 4.6"], 2.6)
                + fill("M11.6 5.8L14.4 2.6C18 3.2 21 6.4 21.4 10.6 18.9 10.1 16.6 10.9 15.1 12.6L11.9 9.6z")
                + shade("M21.4 10.6C18.9 10.1 16.6 10.9 15.1 12.6L13.6 11.2C15.8 9.4 18.3 8.4 21.2 8.6z", 0.2))
ICONS["staff"] = (lines(["M5.2 20.8L14.6 9.4"], 2.4) + circ(16.8, 6.9, 3.7) + shade("M19.4 4.3a3.7 3.7 0 0 1-5.2 5.2c2.6-.3 4.9-2.6 5.2-5.2z", 0.2)
                  + '<circle cx="15.6" cy="5.8" r="1.1" fill="#fff" fill-opacity="0.8"/>')
ICONS["dagger"] = ('<g transform="rotate(45 12 12)">' + fill("M12 1.8l2.1 2.9v10.2H9.9V4.7z") + shade("M12 1.8l2.1 2.9v10.2H12z", 0.16)
                   + fill("M7.6 14.9h8.8v2H7.6z") + fill("M11 16.9h2v3.8h-2z") + circ(12, 21.6, 1.2) + '</g>')
ICONS["pause"] = (f'<rect x="6" y="4.6" width="4.2" height="14.8" rx="1.4" fill="{F}" stroke="{O}" stroke-width="{SW}"/>'
                  f'<rect x="13.8" y="4.6" width="4.2" height="14.8" rx="1.4" fill="{F}" stroke="{O}" stroke-width="{SW}"/>')
ICONS["gear"] = fill(gear_path(12, 12, 9.6, 7.2, 8)) + shade("M18.8 5.2A9.4 9.4 0 0 1 5.2 18.8 9.6 9.6 0 0 0 18.8 5.2z", 0.12) + circ(12, 12, 3.0, O, False)
ICONS["close"] = lines(["M6.5 6.5l11 11M17.5 6.5l-11 11"], 2.8)
ICONS["check"] = lines(["M5 12.6l4.6 4.6L19.2 7.2"], 3.0)
ICONS["arrow_right"] = lines(["M4.5 12h14M13.2 6.2L19 12l-5.8 5.8"], 2.8)
ICONS["arrow_left"] = lines(["M19.5 12h-14M10.8 6.2L5 12l5.8 5.8"], 2.8)
ICONS["crown"] = ICONS["rune_gilded"]
ICONS["flag"] = lines(["M5.6 21.2V3.4"], 2.2) + fill("M5.6 3.8h12.6l-2.8 4.3 2.8 4.3H5.6z")
ICONS["chest"] = (fill("M3.6 10.6h16.8v8.6a1.4 1.4 0 0 1-1.4 1.4H5a1.4 1.4 0 0 1-1.4-1.4z")
                  + fill("M3.6 10.6V8.2a4 4 0 0 1 4-4h8.8a4 4 0 0 1 4 4v2.4z")
                  + shade("M3.6 10.6h16.8v8.6a1.4 1.4 0 0 1-1.4 1.4H5a1.4 1.4 0 0 1-1.4-1.4z", 0.12)
                  + f'<rect x="10.2" y="9" width="3.6" height="4.6" rx="0.9" fill="{O}"/>')
ICONS["portal"] = (f'<ellipse cx="12" cy="12" rx="7.4" ry="9.4" fill="{F}" stroke="{O}" stroke-width="{SW}"/>'
                   + '<ellipse cx="12" cy="12" rx="4.4" ry="6.2" fill="#000" fill-opacity="0.25"/>'
                   + '<ellipse cx="12" cy="12" rx="2" ry="3.2" fill="#000" fill-opacity="0.3"/>'
                   + hl("M7.2 8.4a5.6 7.4 0 0 1 3-3.6", 1.2))
ICONS["potion"] = (fill("M9.6 3h4.8v1.8h-.8v4a6.6 6.6 0 1 1-3.2 0v-4h-.8z")
                   + '<path d="M6.3 14.2h11.4a5.8 5.8 0 0 1-11.4 0z" fill="#000" fill-opacity="0.2"/>'
                   + hl("M8.3 12.6a4.4 4.4 0 0 1 1.8-2.2", 1.2))
ICONS["anvil"] = (fill("M2.8 7h13.4c0 2.6 2.1 4 5 4v1.6c-2.6 0-4.1 1.1-4.6 2.6H14v2.2h3v2.9H6.8v-2.9h3v-2.2H8.4C7 13.4 5 11.6 2.8 11.2z")
                  + shade("M2.8 9.4h13.9c.9 1 2.5 1.6 4.5 1.6v1.6c-2.6 0-4.1 1.1-4.6 2.6H8.4C7 13.4 5 11.6 2.8 11.2z", 0.14))
ICONS["mirror"] = (f'<rect x="2.8" y="6" width="8.4" height="12" rx="2.2" fill="{F}" stroke="{O}" stroke-width="{SW}"/>'
                   + f'<rect x="12.8" y="6" width="8.4" height="12" rx="2.2" fill="{F}" stroke="{O}" stroke-width="{SW}"/>'
                   + shade("M12.8 8.2a2.2 2.2 0 0 1 2.2-2.2h4a2.2 2.2 0 0 1 2.2 2.2v7.6a2.2 2.2 0 0 1-2.2 2.2h-4a2.2 2.2 0 0 1-2.2-2.2z", 0.22)
                   + circ(7, 12, 1.8, O, False) + circ(17, 12, 1.8, O, False))
ICONS["plus"] = lines(["M12 5v14M5 12h14"], 3.0)
ICONS["up"] = ICONS["intent_buff"]
ICONS["speaker"] = (fill("M3.8 9.2h3.6l5-4.2v14l-5-4.2H3.8z")
                    + lines(["M15.6 8.8a4.6 4.6 0 0 1 0 6.4", "M18.4 6a8.6 8.6 0 0 1 0 12"], 1.8))
ICONS["music"] = (lines(["M9.4 17.2V5.6l10-2.2v11.6"], 2.2) + circ(7.2, 17.4, 2.8) + circ(17.2, 15.2, 2.8))
ICONS["speed"] = fill("M3 5.6l8.6 6.4L3 18.4z") + fill("M12.2 5.6l8.6 6.4-8.6 6.4z")
ICONS["question"] = lines(["M8.8 8.6a3.3 3.3 0 1 1 4.6 3c-1 .5-1.4 1.2-1.4 2.4", "M12 18.4h.01"], 2.8)
ICONS["home"] = fill("M3.4 11.4L12 3.6l8.6 7.8h-2.4v9H5.8v-9z") + f'<rect x="10" y="14.6" width="4" height="5.8" fill="{O}"/>'
ICONS["trophy"] = (fill("M7 3.4h10v6a5 5 0 0 1-10 0z") + lines(["M7 5.6H4.2a3 3 0 0 0 3 4.4", "M17 5.6h2.8a3 3 0 0 1-3 4.4"], 1.6)
                   + fill("M10.8 14.2h2.4v3.4h-2.4z") + fill("M7.4 17.6h9.2v3.2H7.4z") + shade("M12 3.4h5v6a5 5 0 0 1-5 5z", 0.14))
ICONS["campfire"] = fill("M3.8 19.2l16.4-3.6.6 2.6-16.4 3.6z") + fill("M20.2 19.2L3.8 15.6l-.6 2.6 16.4 3.6z") \
    + fill("M12 2.8c.7 2.5 4.4 4.1 4.4 7.9a4.4 4.4 0 0 1-8.8 0c0-1.9 1.1-3.1 1.9-4 .2 1.4.8 2.3 1.6 2.7-.2-2.4.2-4.4.9-6.6z")

# ---------------------------------------------------------------- passive abilities ("relics")
# One glyph per Passives.IDS entry, written as passive_<id>. Fixed accents (never tinted):
GOLD = "#FFD24A"
RED = "#E8564A"


def g(body, tf):
    return f'<g transform="{tf}">{body}</g>'


def union(elems, w=3.2):
    """Merges overlapping shapes into one silhouette: outline underlay first, then the tint fills."""
    under = "".join(e[:-2] + f' fill="{O}" stroke="{O}" stroke-width="{w}" stroke-linejoin="round"/>' for e in elems)
    over = "".join(e[:-2] + f' fill="{F}"/>' for e in elems)
    return under + over


def rrect(x, y, w, h, r, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}"{extra}/>'


PIPS = {1: [(.5, .5)], 2: [(.29, .29), (.71, .71)], 3: [(.29, .29), (.5, .5), (.71, .71)],
        4: [(.29, .29), (.71, .29), (.29, .71), (.71, .71)],
        5: [(.29, .29), (.71, .29), (.5, .5), (.29, .71), (.71, .71)],
        6: [(.29, .27), (.71, .27), (.29, .5), (.71, .5), (.29, .73), (.71, .73)]}


def die(x, y, s, n, rot=0, flip=False, pip=0.105):
    """A die face at (x, y) with side s showing n pips (flip mirrors the pip layout)."""
    rx = s * 0.24
    body = (f'<rect x="{x:.2f}" y="{y:.2f}" width="{s:.2f}" height="{s:.2f}" rx="{rx:.2f}" fill="{F}" stroke="{O}" stroke-width="{SW}"/>'
            + shade(f"M{x + s:.2f} {y + s * 0.3:.2f}V{y + s - rx:.2f}A{rx:.2f} {rx:.2f} 0 0 1 {x + s - rx:.2f} {y + s:.2f}"
                    f"H{x + s * 0.3:.2f}Q{x + s * 0.85:.2f} {y + s * 0.85:.2f} {x + s:.2f} {y + s * 0.3:.2f}z", 0.14))
    for px, py in PIPS[n]:
        if flip:
            px = 1 - px
        body += circ(round(x + px * s, 2), round(y + py * s, 2), round(s * pip, 2), O, False)
    if rot:
        body = g(body, f"rotate({rot} {x + s / 2:.2f} {y + s / 2:.2f})")
    return body


def heart(cx, cy, s, color=RED, w=1.3):
    """The HEART glyph shrunk to scale s around (cx, cy) with a ~w px outline."""
    return g(f'<path d="{HEART}" fill="{color}" stroke="{O}" stroke-width="{w / s:.2f}" stroke-linejoin="round"/>',
             f"translate({cx} {cy}) scale({s}) translate(-12 -13.2)")


def coin(cx, cy, r):
    return (circ(cx, cy, r, GOLD)
            + f'<circle cx="{cx}" cy="{cy}" r="{r * 0.55:.2f}" fill="none" stroke="{O}" stroke-opacity="0.4" stroke-width="1"/>'
            + hl(f"M{cx - r * 0.62:.2f} {cy - r * 0.1:.2f}a{r * 0.62:.2f} {r * 0.62:.2f} 0 0 1 {r * 0.5:.2f}-{r * 0.5:.2f}", 0.9, 0.7))


def sparkle(cx, cy, r, color=F, w=1.2):
    return f'<path d="{poly(star_pts(cx, cy, r, r * 0.36, 4, -90))}" fill="{color}" stroke="{O}" stroke-width="{w}" stroke-linejoin="round"/>'


def bez(p0, p1, p2, p3, t):
    u = 1 - t
    return tuple(u ** 3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t ** 3 * d for a, b, c, d in zip(p0, p1, p2, p3))


def arc(cx, cy, r, a0, a1):
    """SVG arc path from angle a0 to a1 (degrees, clockwise); also returns the end point."""
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    large = 1 if abs(a1 - a0) > 180 else 0
    return f"M{x0:.2f} {y0:.2f}A{r} {r} 0 {large} 1 {x1:.2f} {y1:.2f}", (x1, y1)


def hand(tf="", w=3.2):
    """Open palm, fingers up, thumb out to the left (merged silhouette + finger creases)."""
    parts = [rrect(6.6, 5.4, 2.7, 9, 1.35), rrect(9.3, 3.2, 2.7, 10, 1.35), rrect(12.0, 3.8, 2.7, 10, 1.35),
             rrect(14.7, 6.0, 2.6, 8, 1.3),
             '<path d="M6.6 11h10.7v4.6a5.4 5.4 0 0 1-5.4 5.4 5.4 5.4 0 0 1-5.3-5.4z"/>',
             rrect(5.0, 9.6, 2.8, 7.8, 1.4, ' transform="rotate(-32 7.2 16.6)"')]
    body = (union(parts, w)
            + shade("M17.3 11v4.6a5.4 5.4 0 0 1-5.4 5.4c2.6-1.6 3.8-4.4 3.8-7.4V11z", 0.14)
            + f'<path d="M9.3 8.4v4.4M12 7v5.6M14.7 8.6v4.2" stroke="{O}" stroke-opacity="0.45" stroke-width="1" stroke-linecap="round"/>')
    return g(body, tf) if tf else body


BOOT = "M7.4 4.2h6.6v7l4.8 2c2 .9 3.2 2.6 3.2 4.6v.4H7.4z"


def boot(tf=""):
    body = (fill(BOOT) + shade("M14 11.2l4.8 2c2 .9 3.2 2.6 3.2 4.6v.4h-5.6c.4-2.8-.4-5-2.4-7z", 0.16)
            + fill("M6.8 18h15.6v1.4a1.2 1.2 0 0 1-1.2 1.2h-8.8v1H6.8z")
            + rrect(6.6, 2.4, 8.2, 3.4, 1, f' fill="{F}" stroke="{O}" stroke-width="{SW}"')
            + f'<path d="M14 12.4l-2.2 1.4M16.2 13.4l-2 1.6" stroke="{O}" stroke-opacity="0.55" stroke-width="1.1" stroke-linecap="round"/>')
    return g(body, tf) if tf else body


P = {}

P["pair_master"] = die(2.6, 2.6, 11.6, 2, -10) + die(9.8, 9.8, 11.6, 2, 8)

P["full_house_party"] = (fill("M3 11.8L12 3.4l9 8.4h-2.5v9H5.5v-9z") + fill("M15.6 4.4h2.6v4.4l-2.6-2.4z")
                         + shade("M12 3.4l9 8.4h-2.5v9H12z", 0.14) + heart(12, 15.6, 0.44))

P["straight_shooter"] = (lines(["M4.4 19.6L18 6"], 2.6)
                         + fill(poly([(21.4, 2.6), (19.8, 10.4), (13.6, 4.2)]))
                         + lines(["M2.4 17.4H5.8V20.8", "M4.8 15H8.2V18.4"], 1.8)
                         + die(6.6, 6.6, 10.4, 3, flip=True))

P["triple_threat"] = die(2.4, 12.6, 9.0, 3) + die(12.6, 12.6, 9.0, 3) + die(7.5, 2.8, 9.0, 3)

P["snake_eyes"] = (lines(["M3.6 18.8C6.6 22.2 17 22 19 17.6C20.8 13.6 15.6 11.6 12 13C9 14.2 6.4 12.6 7.2 9.6"], 3.4)
                   + f'<path d="M14.4 6.6l2.6-1.2M17 5.4l1.4-1.4M17 5.4l1.9.2" stroke="{RED}" stroke-width="1.2" stroke-linecap="round"/>'
                   + die(4.6, 2.8, 9.2, 1, -14, pip=0.14))

P["boxcars"] = die(3.4, 3.4, 17.2, 6, pip=0.1)

TOOTH = ("M7.2 3.8C4.2 3.8 3.4 7.2 4.2 10c.8 2.8 1.8 4.6 2.2 8.2.3 2.6 2.6 2.8 3.2.4l.9-3.6c.4-1.4 2.6-1.4 3 0"
         "l.9 3.6c.6 2.4 2.9 2.2 3.2-.4.4-3.6 1.4-5.4 2.2-8.2.8-2.8 0-6.2-3-6.2-2 0-3 1-4.8 1s-2.8-1-4.8-1z")
P["gold_tooth"] = (fill(TOOTH) + shade("M16.8 3.8c3 0 3.8 3.4 3 6.2-.8 2.8-1.8 4.6-2.2 8.2-.3 2.6-2.6 2.8-3.2.4 1.8-3.6 3.4-8.6 2.4-14.8z", 0.16)
                   + f'<path d="M4.4 9.4c5 1.6 10.2 1.6 15.2 0l-.5 2.6c-4.8 1.4-9.4 1.4-14.2 0z" fill="{GOLD}" stroke="{O}" stroke-width="1.2" stroke-linejoin="round"/>'
                   + hl("M6.4 6.2a2 2 0 0 1 1.8-.9") + sparkle(19.4, 4.4, 3.4, GOLD))

P["steady_hand"] = hand()

P["loaded_hands"] = (die(2.2, 9.4, 10.4, 5, -12) + die(11.4, 10.6, 10.4, 6, 10)
                     + sparkle(18.4, 4.6, 3.8, GOLD) + sparkle(11.6, 3.6, 2.2, GOLD, 1.0))

P["double_trouble"] = (lines(["M6.4 10C7.2 4.2 15.2 3.4 17.4 8.4"], 2.2, [poly([(18.4, 11.2), (15.0, 8.4), (19.8, 7.4)])])
                       + die(2.0, 11.8, 9.4, 4) + die(12.6, 11.8, 9.4, 4))

STONE = "M6.2 3h5a2.4 2.4 0 0 1 2.4 2.4v13.2a2.4 2.4 0 0 1-2.4 2.4h-5a2.4 2.4 0 0 1-2.4-2.4V5.4A2.4 2.4 0 0 1 6.2 3z"
P["rune_echo"] = (lines(["M16.4 8.2a5.2 5.2 0 0 1 0 7.6", "M19.4 5.2a9.4 9.4 0 0 1 0 13.6"], 2.0) + fill(STONE)
                  + shade("M8.7 3h2.5a2.4 2.4 0 0 1 2.4 2.4v13.2a2.4 2.4 0 0 1-2.4 2.4H8.7z", 0.14)
                  + f'<path d="M8.7 6.4v11.2M8.7 8.4l2.4 2.2M8.7 12.2l2.4-2.2M8.7 12.6l-2.2 2.2" stroke="{O}" stroke-width="1.5" stroke-linecap="round" fill="none"/>')

GEM = poly([(7.2, 4.2), (16.8, 4.2), (21, 9.4), (12, 20.6), (3, 9.4)])
P["collector"] = (fill(GEM) + shade("M12 4.2h4.8L21 9.4 12 20.6z", 0.16)
                  + f'<path d="M3 9.4h18M7.2 4.2l2.3 5.2L12 4.2l2.5 5.2 2.3-5.2M9.5 9.4L12 20.6l2.5-11.2" fill="none" stroke="{O}" stroke-opacity="0.5" stroke-width="1" stroke-linejoin="round"/>'
                  + hl("M6 8.2l1.4-1.8", 1.2) + heart(18.4, 17.8, 0.36))

P["pathfinder"] = boot("rotate(-8 14 12) translate(0.6 0)") + "".join(circ(x, y, r) for x, y, r in ((3.6, 19.4, 1.6), (2.6, 14.6, 1.35), (3.8, 10.2, 1.15)))

P["treasure_sense"] = (fill("M4.6 12L6 5.8a2 2 0 0 1 1.9-1.5h8.2a2 2 0 0 1 1.9 1.5L19.4 12z")
                       + shade("M6.6 11.6l1-4.6h8.8l1 4.6z", 0.28)
                       + circ(8.8, 11.4, 2.2, GOLD) + circ(15.2, 11.4, 2.2, GOLD) + circ(12, 10.4, 2.4, GOLD)
                       + fill("M3.6 12h16.8v7.4a1.4 1.4 0 0 1-1.4 1.4H5a1.4 1.4 0 0 1-1.4-1.4z")
                       + shade("M12 12h8.4v7.4a1.4 1.4 0 0 1-1.4 1.4H12z", 0.14)
                       + f'<rect x="10.3" y="11" width="3.4" height="4.4" rx="0.9" fill="{O}"/>'
                       + sparkle(20.2, 3.8, 2.8, GOLD, 1.1))

P["piggy_bank"] = (union(['<ellipse cx="11.2" cy="13.8" rx="8" ry="5.8"/>', rrect(17.4, 11.2, 4.2, 4.4, 1.6),
                          '<path d="M13.2 8.8l2.2-3.6 1.8 4.6z"/>', rrect(6.4, 17, 2.8, 4.2, 1), rrect(13.2, 17, 2.8, 4.2, 1)])
                   + lines(["M3.4 12.4c-1.6-.4-1.6-2.4 0-2.2"], 1.1)
                   + shade("M19.2 13.8c0 3.2-3.6 5.8-8 5.8-2 0-3.8-.5-5.2-1.4 5 .5 10.4-1.2 11.2-4.4z", 0.14)
                   + circ(15.6, 12, 0.95, O, False) + circ(19.4, 13.4, 0.6, O, False)
                   + f'<path d="M9.2 8.6h3.4" stroke="{O}" stroke-width="1.5" stroke-linecap="round"/>'
                   + coin(10.9, 4.4, 2.8))

TAG = "M12.6 3h7.2a1.2 1.2 0 0 1 1.2 1.2v7.2L11.6 20.8a1.4 1.4 0 0 1-2 0l-6.4-6.4a1.4 1.4 0 0 1 0-2z"
P["haggler"] = (fill(TAG) + shade("M21 11.4L11.6 20.8a1.4 1.4 0 0 1-2 0l-1-1L21 7.4z", 0.16)
                + circ(17, 7, 1.6, O, False)
                + f'<path d="M8.6 15.4l5-5" stroke="{O}" stroke-width="1.5" stroke-linecap="round"/>'
                + circ(9.2, 11, 1.25, O, False) + circ(13, 14.8, 1.25, O, False))

BOOK = "M12 6.6C9.4 4.8 6.4 4.4 2.8 4.9v13.8c3.6-.5 6.6 0 9.2 1.7 2.6-1.7 5.6-2.2 9.2-1.7V4.9c-3.6-.5-6.6-.1-9.2 1.7z"
P["scholar"] = (fill(BOOK) + shade("M12 6.6c2.6-1.8 5.6-2.2 9.2-1.7v13.8c-3.6-.5-6.6 0-9.2 1.7z", 0.14)
                + f'<path d="M12 6.6v13.6" stroke="{O}" stroke-width="1.4"/>'
                + f'<path d="M5 8.6c1.6-.2 3.2 0 4.8.7M5 11.6c1.6-.2 3.2 0 4.8.7M5 14.6c1.6-.2 3.2 0 4.8.7M14.2 9.3c1.6-.7 3.2-.9 4.8-.7M14.2 12.3c1.6-.7 3.2-.9 4.8-.7" '
                  f'fill="none" stroke="{O}" stroke-opacity="0.45" stroke-width="1.1" stroke-linecap="round"/>'
                + sparkle(17.4, 15.4, 2.2, GOLD, 1.0))

ANVIL = "M2.8 7h13.4c0 2.6 2.1 4 5 4v1.6c-2.6 0-4.1 1.1-4.6 2.6H14v2.2h3v2.9H6.8v-2.9h3v-2.2H8.4C7 13.4 5 11.6 2.8 11.2z"
P["blacksmith"] = (g(f'<path d="{ANVIL}" fill="{F}" stroke="{O}" stroke-width="2" stroke-linejoin="round"/>'
                     + shade("M2.8 9.4h13.9c.9 1 2.5 1.6 4.5 1.6v1.6c-2.6 0-4.1 1.1-4.6 2.6H8.4C7 13.4 5 11.6 2.8 11.2z", 0.14),
                     "translate(12 21.2) scale(0.8) translate(-12 -20.8)")
                   + lines(["M7 5.4L15.2 9.4"], 1.8)
                   + g(rrect(2.6, 3, 7.6, 3.8, 0.8)[:-2] + f' fill="{F}" stroke="{O}" stroke-width="{SW}"/>'
                       + shade("M2.6 5.2h7.6v1.6H2.6z", 0.16), "rotate(-62 6.4 4.9)")
                   + sparkle(18.6, 4.6, 2.6, GOLD, 1.0) + sparkle(14.8, 2.6, 1.5, GOLD, 0.9))

THORN_CURVE = ((3.2, 20.2), (8.6, 18.6), (6.6, 12.4), (12, 11.2)), ((12, 11.2), (17.4, 10), (15.6, 4.8), (20.8, 3.6))
thorns, side = [], 1
for seg in THORN_CURVE:
    for t in (0.3, 0.72):
        x, y = bez(*seg, t)
        x2, y2 = bez(*seg, t + 0.02)
        ln = math.hypot(x2 - x, y2 - y)
        tx, ty = (x2 - x) / ln, (y2 - y) / ln
        nx, ny = -ty * side, tx * side
        thorns.append(f'<path d="{poly([(x - tx * 2.2, y - ty * 2.2), (x + nx * 5.2 + tx * 1.4, y + ny * 5.2 + ty * 1.4), (x + tx * 2.2, y + ty * 2.2)])}"/>')
        side = -side
VINE = "M3.2 20.2C8.6 18.6 6.6 12.4 12 11.2S15.6 4.8 20.8 3.6"
P["thorns"] = ("".join(t[:-2] + f' fill="{O}" stroke="{O}" stroke-width="3.2" stroke-linejoin="round"/>' for t in thorns)
               + f'<path d="{VINE}" fill="none" stroke="{O}" stroke-width="6.2" stroke-linecap="round"/>'
               + "".join(t[:-2] + f' fill="{F}"/>' for t in thorns)
               + f'<path d="{VINE}" fill="none" stroke="{F}" stroke-width="3.0" stroke-linecap="round"/>')

P["iron_skin"] = (fill(SHIELD) + shade("M12 2.9v18.3c4.4-1.4 7.6-5 7.6-9.7V5.8z")
                  + f'<path d="M4.6 9.8h14.8M5.4 14.6h13.2M12 2.9v18.3" fill="none" stroke="{O}" stroke-width="1.4"/>'
                  + "".join(circ(x, y, 0.8, O, False) for x, y in ((7, 7.4), (17, 7.4), (7, 12.2), (17, 12.2), (9, 17), (15, 17))))

P["bloodthirst"] = (fill("M2.6 3.6C7.6 7.2 16.4 7.2 21.4 3.6v3.6C16.4 11 7.6 11 2.6 7.2z")
                    + fill("M5.8 8.6c.3 3.6 1.4 6.4 3.2 8.6.6-2.6.9-5.2.9-7.6z")
                    + fill("M18.2 8.6c-.3 3.6-1.4 6.4-3.2 8.6-.6-2.6-.9-5.2-.9-7.6z")
                    + shade("M2.6 5.4c5 3.4 13.8 3.4 18.8 0v1.8C16.4 11 7.6 11 2.6 7.2z", 0.16)
                    + f'<path d="M12 12.2c2 2.6 3.4 4.4 3.4 6.2a3.4 3.4 0 0 1-6.8 0c0-1.8 1.4-3.6 3.4-6.2z" fill="{RED}" stroke="{O}" stroke-width="1.4" stroke-linejoin="round"/>'
                    + hl("M10.4 18a1.6 1.6 0 0 0 .6 1.6", 1.0, 0.7))

bp = []
for i in range(16):
    r = (11.4 if i % 4 == 0 else 9.2) if i % 2 == 0 else 5.2
    a = math.radians(-90 + i * 22.5)
    bp.append((12 + r * math.cos(a), 12 + r * math.sin(a)))
P["opening_salvo"] = (fill(poly(bp)) + shade(poly([(12, 12)] + bp[1:9]), 0.14)
                      + f'<path d="{poly(star_pts(12, 12, 5.2, 2.7, 8, -90))}" fill="#fff" fill-opacity="0.55"/>')

P["second_wind"] = (lines(["M3 9h10.6a2.8 2.8 0 1 0-2.8-2.8", "M3 13h14.2a3 3 0 1 1-3 3", "M3 17h5.6"], 2.2)
                    + heart(18.6, 7.4, 0.34))

P["glass_cannon"] = (lines(["M16.4 6.4c1.2-1.6 2.6-2.2 4-1.8"], 1.4) + fill("M14.2 5.2l3.4 3.4-2.2 2.2-3.4-3.4z")
                     + circ(10.6, 13.6, 7.6) + shade("M16 8.2a7.6 7.6 0 0 1-10.8 10.8A7.6 7.6 0 0 0 16 8.2z", 0.18)
                     + f'<path d="M9.6 7.4l1.4 3-2.4 2 2 2.6-1.2 2.6M11 10.4l2.6.6M8.6 12.4l-2.4.4" fill="none" stroke="{O}" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/>'
                     + hl("M5.8 12a5 5 0 0 1 1.6-3", 1.3, 0.75) + sparkle(20.8, 4, 2.4, GOLD, 1.0))

P["extra_hand"] = hand("translate(-1.2 1.8) scale(0.9)", 3.4) + lines(["M18.8 2.6v6.8M15.4 6h6.8"], 2.4)

JESTER = ["M5.2 16.4C4.6 12.4 3.8 9.4 1.8 7.4c4.6 0 8 2.8 9.4 9z",
          "M8.8 16.4C9.4 11.2 10.6 6.4 12 3.6c1.4 2.8 2.6 7.6 3.2 12.8z",
          "M18.8 16.4c.6-4 1.4-7 3.4-9-4.6 0-8 2.8-9.4 9z"]
P["crowd_pleaser"] = ("".join(fill(d) for d in JESTER) + shade("M12 3.6c1.4 2.8 2.6 7.6 3.2 12.8H12z", 0.16)
                      + circ(2.4, 7.4, 1.7, GOLD) + circ(12, 3.2, 1.7, GOLD) + circ(21.6, 7.4, 1.7, GOLD)
                      + fill("M4 16h16v4.6H4z") + shade("M12 16h8v4.6h-8z", 0.14)
                      + circ(8, 18.3, 1.05, O, False) + circ(12, 18.3, 1.05, O, False) + circ(16, 18.3, 1.05, O, False))

enc_arc, (ex, ey) = arc(12, 12, 7.8, -40, 250)
P["encore"] = (lines([enc_arc], 2.4, [poly([(ex - 3.4, ey - 1.2), (ex + 2.8, ey - 2.8), (ex + 0.6, ey + 3.4)])])
               + fill(poly(star_pts(12, 12.5, 4.8, 2.1))))

petals = ""
for k in range(5):
    petals += g(f'<ellipse cx="12" cy="6.4" rx="3.3" ry="4.6" fill="{F}" stroke="{O}" stroke-width="{SW}"/>'
                + f'<path d="M12 4.6v3.4M12 5.6l1.3 1" stroke="{O}" stroke-opacity="0.55" stroke-width="1" stroke-linecap="round"/>',
                f"rotate({k * 72} 12 12)")
P["rune_bloom"] = petals + circ(12, 12, 3.0, GOLD) + hl("M10.6 11.4a1.6 1.6 0 0 1 1-1.2", 0.9, 0.7)

feathers = []
for ang, ln in ((184, 9.2), (210, 8.4), (236, 7.0)):
    a = math.radians(ang)
    cx, cy = 10.2 + math.cos(a) * ln / 2, 10.2 + math.sin(a) * ln / 2
    feathers.append(f'<ellipse cx="{cx:.2f}" cy="{cy:.2f}" rx="{ln / 2:.2f}" ry="2.0" transform="rotate({ang} {cx:.2f} {cy:.2f})"/>')
P["fast_feet"] = (boot("translate(2 1.2) scale(0.9)") + union(feathers)
                  + f'<path d="M3.2 8.6l6 1.2M5.4 4.6l4 4.4" fill="none" stroke="{O}" stroke-opacity="0.55" stroke-width="1.1" stroke-linecap="round"/>')

P["resonance"] = (lines(["M12 5.2a6.8 6.8 0 1 1 0 13.6a6.8 6.8 0 1 1 0-13.6z"], 1.6)
                  + lines([arc(12, 12, 10.4, -40, 40)[0], arc(12, 12, 10.4, 140, 220)[0]], 1.8)
                  + fill(poly([(12, 8.6), (15.4, 12), (12, 15.4), (8.6, 12)])) + shade(poly([(12, 8.6), (15.4, 12), (12, 15.4)]), 0.16))

FEATHER = "M4.4 19.6C4.8 12.4 9.6 5.2 20.6 2.8c-.4 3-1.6 4.8-3.2 5.8 1.2.2 2 0 2.8-.4-1 3.2-3 5-5.4 6 1 .2 1.8.2 2.6-.2-2.6 3.2-6.8 5-12.8 5.6z"
P["phoenix"] = (fill(FEATHER)
                + shade("M20.6 2.8c-.4 3-1.6 4.8-3.2 5.8 1.2.2 2 0 2.8-.4-1 3.2-3 5-5.4 6 1 .2 1.8.2 2.6-.2-2.6 3.2-6.8 5-12.8 5.6 4.8-4 9.8-9.6 16-16.8z", 0.16)
                + f'<path d="M12.6 8.2c1-1.2 2.4-2 3.8-2.6M10.2 11.6c1.4-.6 2.8-.8 4.2-.8" fill="none" stroke="{O}" stroke-opacity="0.45" stroke-width="1" stroke-linecap="round"/>'
                + lines(["M2.4 21.6L16.4 7.2"], 1.3)
                + f'<path d="M20.4 3.2c-.8 2.6-2.4 4.2-4.2 5.2 1.4 0 2.6-.2 3.8-.8" fill="none" stroke="{RED}" stroke-width="1.4" stroke-linecap="round"/>')

P["midas_fist"] = (union([rrect(3.6, 5.4, 3.6, 5.6, 1.8), rrect(7.2, 4.6, 3.6, 5.8, 1.8), rrect(10.8, 4.8, 3.6, 5.8, 1.8),
                          rrect(14.4, 5.8, 3.4, 5.4, 1.7), '<path d="M3.6 8.4h14.2v7.2a4.4 4.4 0 0 1-4.4 4.4H8a4.4 4.4 0 0 1-4.4-4.4z"/>'])
                   + shade("M17.8 8.4v7.2a4.4 4.4 0 0 1-4.4 4.4h-1.6c2.6-1.2 4-3.4 4-6.4V8.4z", 0.14)
                   + f'<path d="M7.2 6v4.4M10.8 5.4v5M14.4 6.2v4.4" stroke="{O}" stroke-width="1.2" stroke-linecap="round"/>'
                   + fill("M3.4 11.6c2.8-.4 6-.2 8.6.8a1.9 1.9 0 0 1-.6 3.7c-2.6-.3-5.4-.1-8 .6z")
                   + coin(18.2, 16.8, 4.4))


# ---------------------------------------------------------------- biome intents, traits and statuses
CROSS = "M9.3 3.4h5.4a.8.8 0 0 1 .8.8v5h5a.8.8 0 0 1 .8.8v5.4a.8.8 0 0 1-.8.8h-5v5a.8.8 0 0 1-.8.8H9.3a.8.8 0 0 1-.8-.8v-5h-5a.8.8 0 0 1-.8-.8V10a.8.8 0 0 1 .8-.8h5v-5a.8.8 0 0 1 .8-.8z"
ICONS["intent_heal"] = fill(CROSS) + shade("M12 3.4h2.7a.8.8 0 0 1 .8.8v5h5a.8.8 0 0 1 .8.8v5.4a.8.8 0 0 1-.8.8h-5v5a.8.8 0 0 1-.8.8H12z", 0.14) + hl("M5 11h4.2M11 5v4")

FANG = "M3.4 3.6h9.8a.6.6 0 0 1 .6.7L10.2 13a1.4 1.4 0 0 1-2.6 0L2.8 4.3a.6.6 0 0 1 .6-.7z"
ICONS["intent_drain"] = (fill(FANG) + shade("M8.3 3.6h4.9a.6.6 0 0 1 .6.7L10.2 13a1.4 1.4 0 0 1-1.9.8z", 0.16)
                         + f'<path d="M8.9 14.2c1 1.4 1.6 2.2 1.6 3a1.6 1.6 0 0 1-3.2 0c0-.8.6-1.6 1.6-3z" fill="{RED}" stroke="{O}" stroke-width="1.1"/>'
                         + heart(17.2, 16.6, 0.5))

ICONS["intent_burn"] = ICONS["flame"]

ICONS["intent_chill"] = (g("".join(SWORD), "translate(-1.6 2.2) scale(0.86)")
                         + g(lines(snow, 2.1), "translate(13.6 1.2) scale(0.44)"))

ICONS["intent_scorch"] = (die(2.8, 8.2, 13.0, 1, 0, False, 0.0)
                          + f'<path d="M5.6 17.4l3-2.4M9.2 19l1.6-2.2" stroke="{O}" stroke-opacity="0.55" stroke-width="1.1" stroke-linecap="round"/>'
                          + g(fill(FLAME) + '<path d="M12 12.9c1.5 1.5 2.7 2.7 2.7 4.4a2.7 2.7 0 0 1-5.4 0c0-1.7 1.2-2.9 2.7-4.4z" fill="#fff" fill-opacity="0.55"/>',
                              "translate(10.2 -0.6) scale(0.6)"))

ICONS["trait_armor"] = (fill(SHIELD) + shade("M12 2.9v18.3c4.4-1.4 7.6-5 7.6-9.7V5.8z")
                        + f'<path d="M4.4 9.4h15.2M5 14.2h14M12 3.2v6.2M8.2 9.4v4.8M15.8 9.4v4.8M12 14.2v6.4" fill="none" stroke="{O}" stroke-width="1.3" stroke-linecap="round"/>')

thorn = star_pts(12, 12, 10.6, 7.2, 10, -90)
ICONS["trait_thorns"] = (f'<path d="{poly(thorn)} M12 7.2a4.8 4.8 0 1 0 0 9.6a4.8 4.8 0 1 0 0-9.6z" fill="{F}" fill-rule="evenodd" stroke="{O}" stroke-width="{SW}" stroke-linejoin="round"/>'
                         + f'<circle cx="12" cy="12" r="6.2" fill="none" stroke="{O}" stroke-opacity="0.35" stroke-width="1"/>')

ICONS["trait_ward"] = (fill("M2.8 18.4a9.2 9.2 0 0 1 18.4 0z") + shade("M12 9.2a9.2 9.2 0 0 1 9.2 9.2H12z", 0.14)
                       + fill("M1.8 18.4h20.4v2.6H1.8z") + hl("M6.4 14.6a6 6 0 0 1 3.6-3.8", 1.4, 0.8)
                       + sparkle(18.6, 4.4, 2.4, GOLD, 1.0))

ICONS["trait_pierce"] = (fill(SHIELD) + shade("M12 2.9v18.3c4.4-1.4 7.6-5 7.6-9.7V5.8z")
                         + f'<path d="M12.6 3.4l-2.2 5 2.8 2.6-2.6 4.4 1.2 5.6" fill="none" stroke="{O}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>')

# ---------------------------------------------------------------- enemy affixes (§3A: HUD badges, cards, legend)
ICONS["affix_armored"] = (fill(SHIELD) + shade("M12 2.9v18.3c4.4-1.4 7.6-5 7.6-9.7V5.8z")
                          + f'<path d="M4.6 8.6h14.8M4.8 12.8h14.4M6.4 17h11.2M9 3.8v4.8M15 3.8v4.8M12 8.6v4.2M7.6 12.8v4.2M16.4 12.8v4.2M12 17v3.6" '
                          f'fill="none" stroke="{O}" stroke-width="1.2" stroke-linecap="round"/>'
                          + hl("M6.6 6.8l1.6-.6", 1.2, 0.7))
ICONS["affix_thorned"] = ICONS["trait_thorns"]
ICONS["affix_warded"] = (fill("M2.8 18.4a9.2 9.2 0 0 1 18.4 0z") + shade("M12 9.2a9.2 9.2 0 0 1 9.2 9.2H12z", 0.14)
                         + fill("M1.8 18.4h20.4v2.6H1.8z") + hl("M6.4 14.6a6 6 0 0 1 3.6-3.8", 1.4, 0.8)
                         + f'<path d="M12 9.2v9.2M7 12.2l2.6 6.2M17 12.2l-2.6 6.2" fill="none" stroke="{O}" stroke-opacity="0.35" stroke-width="1"/>')
ICONS["affix_piercing"] = ICONS["trait_pierce"]
ICONS["affix_frenzied"] = (fill(SKULL) + shade("M16.2 4a8.2 8.2 0 0 1 3.9 7c0 2.8-1.4 4.7-3.1 5.7V20a1.2 1.2 0 0 1-1.2 1.2h-1.2c2.6-5.7 3.6-11.8 1.6-17.2z", 0.16)
                           + dark("M6.4 9.6l4.4 1.8-.6 2.6-3.2-.4z") + dark("M17.6 9.6l-4.4 1.8.6 2.6 3.2-.4z")
                           + dark("M10.8 15.6h2.4l-1.2 1.8z")
                           + f'<path d="M9.4 19.2v2M12 19.2v2M14.6 19.2v2" stroke="{O}" stroke-width="1.1" stroke-linecap="round"/>'
                           + f'<path d="M5.4 7.2l5 2.2M18.6 7.2l-5 2.2" stroke="{O}" stroke-width="1.6" stroke-linecap="round"/>')
ICONS["affix_regenerating"] = (circ(12, 12, 9.4) + shade("M18.6 5.4a9.4 9.4 0 0 1-13.2 13.2A9.4 9.4 0 0 0 18.6 5.4z", 0.16)
                               + f'<path d="M10.2 5.8h3.6v4.4h4.4v3.6h-4.4v4.4h-3.6v-4.4H5.8v-3.6h4.4z" fill="#fff" stroke="{O}" stroke-width="1.3" stroke-linejoin="round"/>')
ICONS["affix_vampiric"] = ICONS["intent_drain"]
ICONS["affix_hexing"] = (die(4.2, 5.4, 13.6, 3, 0, False, 0.1)
                         + f'<path d="M1.8 5.2c1.6-1.8 4.2-1.8 5.4.2M22.2 18.8c-1.6 1.8-4.2 1.8-5.4-.2" fill="none" stroke="{O}" stroke-width="4" stroke-linecap="round"/>'
                         + f'<path d="M1.8 5.2c1.6-1.8 4.2-1.8 5.4.2M22.2 18.8c-1.6 1.8-4.2 1.8-5.4-.2" fill="none" stroke="#c8c0d8" stroke-width="1.8" stroke-linecap="round"/>'
                         + f'<ellipse cx="3.2" cy="8.4" rx="1.8" ry="2.6" fill="none" stroke="{O}" stroke-width="3.2"/>'
                         + f'<ellipse cx="3.2" cy="8.4" rx="1.8" ry="2.6" fill="none" stroke="#c8c0d8" stroke-width="1.4"/>'
                         + f'<ellipse cx="20.8" cy="15.6" rx="1.8" ry="2.6" fill="none" stroke="{O}" stroke-width="3.2"/>'
                         + f'<ellipse cx="20.8" cy="15.6" rx="1.8" ry="2.6" fill="none" stroke="#c8c0d8" stroke-width="1.4"/>')
ICONS["affix_frostbound"] = (die(2.4, 7.8, 13.8, 2, -8)
                             + g(lines(snow, 2.3), "translate(11.4 0.6) scale(0.52)"))
ICONS["affix_gilded"] = ICONS["coin"]
ICONS["intent_rally"] = (f'<ellipse cx="12" cy="10.2" rx="7.6" ry="3.2" fill="{F}" stroke="{O}" stroke-width="{SW}"/>'
                         + fill("M4.4 10.2v6.4c0 1.8 3.4 3.2 7.6 3.2s7.6-1.4 7.6-3.2v-6.4c0 1.8-3.4 3.2-7.6 3.2s-7.6-1.4-7.6-3.2z")
                         + f'<path d="M5.6 13.6l3 5.4M9.4 13.4l2.6 6.4M14.6 13.4l-2.6 6.4M18.4 13.6l-3 5.4" stroke="{O}" stroke-opacity="0.5" stroke-width="1.1"/>'
                         + lines(["M6.6 2.6l3.8 6.4", "M17.4 2.6l-3.8 6.4"], 1.6)
                         + circ(6.4, 2.6, 1.3, "#fff") + circ(17.6, 2.6, 1.3, "#fff"))

# ---------------------------------------------------------------- biome emblems (route card, pause, summary)
ICONS["biome_glade"] = (fill("M10.5 13.6h3v7.6h-3z")
                        + union(['<circle cx="12" cy="8.6" r="6.2"/>', '<circle cx="7" cy="12" r="4.2"/>', '<circle cx="17" cy="12" r="4.2"/>'])
                        + shade("M16.6 4.4a6.2 6.2 0 0 1 4.6 7.6 4.2 4.2 0 0 1-6.4 3.2c3-2.2 3.6-6.6 1.8-10.8z", 0.16)
                        + hl("M8 7.6a4.4 4.4 0 0 1 3-3", 1.3, 0.7))

ICONS["biome_crypt"] = (fill("M4.6 21.2V10a7.4 7.4 0 0 1 14.8 0v11.2z") + shade("M12 2.6a7.4 7.4 0 0 1 7.4 7.4v11.2H12z", 0.14)
                        + f'<path d="M8.6 21.2v-7.2a3.4 3.4 0 0 1 6.8 0v7.2z" fill="{O}"/>'
                        + f'<path d="M4.6 12.4h3M16.4 12.4h3M4.6 16.6h3M16.4 16.6h3" stroke="{O}" stroke-opacity="0.45" stroke-width="1.1"/>')

PUMP = ['<ellipse cx="12" cy="14" rx="4.2" ry="6.6"/>', '<ellipse cx="7.6" cy="14" rx="4.8" ry="6.2"/>',
        '<ellipse cx="16.4" cy="14" rx="4.8" ry="6.2"/>']
ICONS["biome_hollow"] = (lines(["M12 7.6c0-2 .8-3.6 2.6-4.4"], 2.2) + union(PUMP)
                         + f'<path d="M12 7.8v12.4M7.6 8.4c-1.4 2.4-1.4 8.8 0 11.2M16.4 8.4c1.4 2.4 1.4 8.8 0 11.2" fill="none" stroke="{O}" stroke-opacity="0.35" stroke-width="1"/>'
                         + dark("M7.6 12.2l2 1.8H6.8zM16.4 12.2l.8 1.8h-2.8zM7.4 16.4h9.2l-1.2 2-1.4-1-1.3 1.2-1.3-1.2-1.4 1z"))

MOUNT = poly([(1.6, 20.6), (8.8, 6.2), (12.2, 11.6), (15.4, 7.4), (22.4, 20.6)])
ICONS["biome_frost"] = (fill(MOUNT) + shade(poly([(8.8, 6.2), (12.2, 11.6), (10.6, 20.6), (1.6, 20.6)]), 0.0)
                        + shade(poly([(15.4, 7.4), (22.4, 20.6), (13.6, 20.6)]), 0.16)
                        + f'<path d="M8.8 6.2l2.4 4.8-1.4-.6-1 1.2-1-1.4-1.2.8z" fill="#fff" stroke="{O}" stroke-width="0.9" stroke-linejoin="round"/>'
                        + f'<path d="M15.4 7.4l2 3.8-1.2-.5-.9 1-.9-1.1-.9.4z" fill="#fff" stroke="{O}" stroke-width="0.9" stroke-linejoin="round"/>')

ICONS["biome_throne"] = ICONS["rune_gilded"]

ICONS["biome_magma"] = (fill("M2.4 20.8l6.4-11.4h6.4l6.4 11.4z") + shade("M12 9.4h3.2l6.4 11.4H12z", 0.16)
                        + f'<path d="M9 9.4h6l-1.2 3.6 1.8 3.4-2.6-1.6-1.6 3 .4-4.8-2.2 1z" fill="{GOLD}" stroke="{O}" stroke-width="1" stroke-linejoin="round"/>'
                        + f'<path d="M10.2 9.2c.2-1.4 1-2 1.8-2s1.6.6 1.8 2" fill="{RED}" stroke="{O}" stroke-width="1"/>'
                        + circ(8.4, 4.6, 1.3, RED) + circ(15.8, 3.6, 1.1, GOLD) + circ(12.2, 2.4, 0.9, RED))

# ---------------------------------------------------------------- 2026-09-29 biomes + their twists
TEAL = "#5FE0D0"
SAND = "#F2CF8A"
SILVER = "#E6ECFF"
# Deep Mines: a glowing gem vein in a rock with a pickaxe
ICONS["biome_mines"] = (lines(["M4.2 4.4l8.6 8.6"], 2.2)
                        + fill("M2.6 6.2c2.2-3 6.8-3.8 9.6-2.2-3.4-.2-6.6.6-9.6 2.2z")
                        + fill("M2.4 21.2l2.6-7.4 5-3.2 5.6 1.2 4.4 4.6.6 4.8z") + shade("M15.6 11.8l4.4 4.6.6 4.8H12z", 0.16)
                        + f'<path d="M9.6 14.2l2.4-3.2 2.4 3.2-2.4 4.2z" fill="{TEAL}" stroke="{O}" stroke-width="1.1" stroke-linejoin="round"/>'
                        + f'<path d="M15.4 16.6l1.6-1.8 1.4 2-1.5 2.4z" fill="{GOLD}" stroke="{O}" stroke-width="1" stroke-linejoin="round"/>'
                        + hl("M10.8 13.8l1.2-1.6", 1.0, 0.8))
# Orc Warcamp: a war tent with a blood-red pennant
ICONS["biome_warcamp"] = (lines(["M12 2.8v4.2"], 1.8)
                          + f'<path d="M12.4 2.8l5 1.6-5 1.8z" fill="{RED}" stroke="{O}" stroke-width="1.1" stroke-linejoin="round"/>'
                          + fill("M12 6.6l9.4 14.6H2.6z") + shade("M12 6.6l9.4 14.6H12z", 0.16)
                          + f'<path d="M12 12.4l-3 8.8h6z" fill="{O}"/>'
                          + f'<path d="M6.6 15.2l2.6-1.6M17.4 15.2l-2.6-1.6" stroke="{O}" stroke-opacity="0.45" stroke-width="1.1"/>')
# Sunscorched Ruins: a broken column under a white-gold sun
ICONS["biome_ruins"] = (circ(17.2, 6.4, 3.6, GOLD)
                        + fill("M4.4 21.2v-1.8h11.2v1.8zM5.4 19.4V9.8l2.2-1.4 1.6 1.8 1.8-2.2 2.4 1.6 1.2-.6v10.4z")
                        + shade("M12 8l2.4 1.6 1.2-.6v10.4H12z", 0.16)
                        + f'<path d="M8 11.4v6.4M10.6 11v6.8M13.2 11.2v6.6" stroke="{O}" stroke-opacity="0.45" stroke-width="1.1"/>')
# Moonlit Woods: a crescent moon and a star
MOON = "M15.8 3.4a8.6 8.6 0 1 0 4.8 13.8 7 7 0 0 1-4.8-13.8z"
ICONS["biome_moonlit"] = (fill(MOON) + shade("M20.6 17.2a8.6 8.6 0 0 1-15.2-1.4c3.6 2.6 10 3.2 15.2 1.4z", 0.16)
                          + f'<path d="{poly(star_pts(18.2, 6.6, 2.6, 1.1))}" fill="{SILVER}" stroke="{O}" stroke-width="1" stroke-linejoin="round"/>'
                          + hl("M6.6 9.4a6.4 6.4 0 0 1 3.4-4", 1.2, 0.6))
# twist glyphs (HUD chip): the sun (Ruins heat), an oasis pool (cooled), ore and the war drum
rays = []
for k in range(8):
    a = math.radians(k * 45)
    rays.append(f"M{12 + 7.2 * math.cos(a):.2f} {12 + 7.2 * math.sin(a):.2f} L{12 + 10 * math.cos(a):.2f} {12 + 10 * math.sin(a):.2f}")
ICONS["sun"] = lines(rays, 1.9) + circ(12, 12, 5.2) + shade("M15.7 8.3a5.2 5.2 0 0 1-7.4 7.4 5.2 5.2 0 0 0 7.4-7.4z", 0.18)
ICONS["oasis"] = (fill("M2.6 17.4c0-2 4.2-3.4 9.4-3.4s9.4 1.4 9.4 3.4-4.2 3.4-9.4 3.4-9.4-1.4-9.4-3.4z")
                  + lines(["M12.4 15.6c.4-3.4-.2-6.4-1.4-9"], 1.6)
                  + f'<path d="M11 6.6c-2.2-1.6-5-1.2-6.6.8 2.4-.6 4.6-.4 6.6-.8zM11 6.6c1.4-2.2 4.4-3 6.8-1.8-2.6.2-4.8.8-6.8 1.8zM11 6.6c2.6-.4 5.2.8 6.2 3-2-1.4-4.2-2.2-6.2-3z" fill="#5CC46A" stroke="{O}" stroke-width="1" stroke-linejoin="round"/>'
                  + hl("M6.4 17.2c1.6.6 3.4.8 5.6.8", 1.1, 0.7))
ICONS["ore"] = (fill("M3 20.6l3.2-8.2 6-3 6.2 2.2 2.6 9z") + shade("M18.4 11.6l2.6 9h-8.6z", 0.16)
                + f'<path d="M9.4 14.4l3-4.2 3 4.2-3 5z" fill="{TEAL}" stroke="{O}" stroke-width="1.1" stroke-linejoin="round"/>'
                + f'<path d="M5.8 17.6l1.4-1.6 1.4 1.8-1.4 1.8z" fill="{GOLD}" stroke="{O}" stroke-width="1" stroke-linejoin="round"/>'
                + hl("M11.4 13.2l1-1.4", 1.0, 0.8))
ICONS["drum"] = ICONS["intent_rally"]
# intents: Bury (a die sinking into sand) and Moonfall (a falling moon)
ICONS["intent_bury"] = (die(6.2, 3.0, 11.6, 3, -12)
                        + f'<path d="M1.8 15.6c3.2-1.8 6.6-1.8 10.2 0s7 1.8 10.2 0v5.6H1.8z" fill="{SAND}" stroke="{O}" stroke-width="{SW}" stroke-linejoin="round"/>'
                        + f'<path d="M5 18.6c2-.8 4-.8 6 0M13.4 18.6c2-.8 4-.8 6 0" fill="none" stroke="{O}" stroke-opacity="0.45" stroke-width="1.1" stroke-linecap="round"/>')
ICONS["intent_moonfall"] = (lines(["M4.4 2.4l3.2 5.6", "M9.2 1.8l2.4 4.4", "M2.2 7.4l2.6 3.8"], 1.4)
                            + g(fill(MOON) + shade("M20.6 17.2a8.6 8.6 0 0 1-15.2-1.4c3.6 2.6 10 3.2 15.2 1.4z", 0.16),
                                "translate(3.2 4.2) scale(0.8)"))

# ---------------------------------------------------------------- AUTO (looping arrow + play)
def auto_icon():
    a0, a1, r = -58, 222, 8.0
    path, (x1, y1) = arc(12, 12, r, a0, a1)
    t = math.radians(a1)
    tx, ty = -math.sin(t), math.cos(t)          # clockwise tangent at the arc end
    nx, ny = math.cos(t), math.sin(t)           # outward normal
    tip = (x1 + tx * 3.4, y1 + ty * 3.4)
    head = poly([tip, (x1 + nx * 3.2 - tx * 0.6, y1 + ny * 3.2 - ty * 0.6), (x1 - nx * 3.2 - tx * 0.6, y1 - ny * 3.2 - ty * 0.6)])
    return lines([path], 2.5, [head]) + fill("M10 8.4v7.2l5.8-3.6z")


ICONS["auto"] = auto_icon()

# ---------------------------------------------------------------- classes 5-11 and their mechanics (class badge, cards)
ICONS["class_paladin"] = (fill("M11 9.6h2v11.2a1 1 0 0 1-2 0z") + fill("M5.6 3.4h12.8v6.4H5.6z")
                          + shade("M12 3.4h6.4v6.4H12z", 0.16) + hl("M7.2 5v3.2") + dark("M11 11.2h2v1.4h-2z"))
ICONS["class_ranger"] = (lines(["M7.4 3.2c6 2.4 6 15.2 0 17.6", "M7.4 3.2v17.6", "M4.6 12h14"], 2.0,
                               [poly([(20.6, 12), (16.6, 9.6), (16.6, 14.4)]), poly([(4.8, 12), (3.2, 10.2), (3.2, 13.8)])]))
ICONS["class_ninja"] = (fill(poly(star_pts(12, 12, 10, 3.2, 4, -90))) + shade(poly([(12, 12), (12, 2), (15.2, 8.8), (22, 12)]), 0.16)
                        + circ(12, 12, 1.9, "#1B1530", False))
LEAF = "M4.2 19.8C3.6 10.6 9.2 4.2 20 3.6c.6 10.6-5.8 16.4-15.8 16.2z"
ICONS["class_druid"] = (fill(LEAF) + shade("M20 3.6c.6 10.6-5.8 16.4-15.8 16.2C11.6 16 17 10.4 20 3.6z", 0.16)
                        + lines(["M4.4 19.6L14.8 9.2"], 1.2))
WRENCH = "M14.6 3.2a5 5 0 0 0-4.7 6.7l-6.4 6.4a2.1 2.1 0 0 0 3 3l6.4-6.4a5 5 0 0 0 6.7-4.7l-3.1 3.1-2.9-.7-.7-2.9z"
ICONS["class_engineer"] = fill(WRENCH) + shade("M9.9 9.9l3.3 3.3-6.4 6.4a2.1 2.1 0 0 1-3-3z", 0.16) + circ(5.2, 18.1, 0.9, "#1B1530", False)
ICONS["class_necromancer"] = (lines(["M12 11.6v10"], 2.4) + fill("M12 1.8a5.6 5.6 0 0 0-5.6 5.6c0 1.9 1 3.2 2.1 3.9v1.6h7v-1.6c1.1-.7 2.1-2 2.1-3.9A5.6 5.6 0 0 0 12 1.8z")
                              + dark("M8.6 6.6h2.4v2.2H8.6zM13 6.6h2.4v2.2H13z") + f'<path d="M6.2 8.4c-1.6-.2-2.6-1.4-2.4-3" fill="none" stroke="#7CF0B8" stroke-width="1.4" stroke-linecap="round"/>'
                              + f'<path d="M17.8 8.4c1.6-.2 2.6-1.4 2.4-3" fill="none" stroke="#7CF0B8" stroke-width="1.4" stroke-linecap="round"/>')
PAD = "M12 11.2c3.8 0 6.6 3 6.6 6.2 0 2.4-2.2 3.6-6.6 3.6s-6.6-1.2-6.6-3.6c0-3.2 2.8-6.2 6.6-6.2z"
ICONS["class_monster_kid"] = (fill(PAD) + fill("M5.4 9.8L3.2 3.6l5.2 4.2z") + fill("M12 8.2l-1.6-6.2h3.2z") + fill("M18.6 9.8l2.2-6.2-5.2 4.2z")
                              + shade("M12 11.2c3.8 0 6.6 3 6.6 6.2 0 2.4-2.2 3.6-6.6 3.6z", 0.16))
# mechanics
def sun():
    rays = []
    for k in range(8):
        a = math.radians(k * 45)
        rays.append(f"M{12 + 6.4 * math.cos(a):.2f} {12 + 6.4 * math.sin(a):.2f}L{12 + 9.6 * math.cos(a):.2f} {12 + 9.6 * math.sin(a):.2f}")
    return lines(rays, 2.2) + circ(12, 12, 4.6) + shade("M12 7.4a4.6 4.6 0 0 1 0 9.2z", 0.16)
ICONS["mech_oath"] = sun()
ICONS["mech_aim"] = (lines(["M12 2.6v4.2", "M12 17.2v4.2", "M2.6 12h4.2", "M17.2 12h4.2"], 2.2)
                     + f'<circle cx="12" cy="12" r="6.4" fill="none" stroke="{O}" stroke-width="5"/><circle cx="12" cy="12" r="6.4" fill="none" stroke="{F}" stroke-width="2"/>'
                     + circ(12, 12, 1.8))
ICONS["mech_shadow_step"] = (fill("M15.8 3.2a8.8 8.8 0 1 0 5 15.4A7.4 7.4 0 0 1 15.8 3.2z") + shade("M20.8 18.6a8.8 8.8 0 0 1-13.4 1.2c5 .6 9.8-1 13.4-1.2z", 0.2)
                             + lines(["M17.6 7.6h3.6", "M18.6 11h3"], 1.4))
ICONS["mech_overgrowth"] = (lines(["M12 21.2v-9.6"], 2.4) + fill("M12 13.2C8.2 13.6 4.6 11.4 4 6.2c4.6-.4 7.6 2.2 8 7z")
                            + fill("M12 11.6c.4-4.6 3.4-7.6 8-7.8-.2 5-3.6 7.6-8 7.8z") + shade("M12 11.6c3.2-2 5.2-4.4 8-7.8-.2 5-3.6 7.6-8 7.8z", 0.16)
                            + fill("M6.4 21.2h11.2l-1-2.8H7.4z"))
BONE = "M6.2 4.2a2.4 2.4 0 0 0-2 3.6 2.4 2.4 0 0 0 1.4 3.9l7.6 7.6a2.4 2.4 0 0 0 3.9 1.4 2.4 2.4 0 0 0 3.6-2 2.4 2.4 0 0 0-3.6-2l-7.4-7.4a2.4 2.4 0 0 0-2-4.4 2.4 2.4 0 0 0-1.5.3z"
ICONS["mech_bone_harvest"] = fill(BONE) + shade("M13.2 19.3l-7.6-7.6c1.4.4 2.4-.2 2.6-1.2l7.4 7.4c-1 .2-1.8.6-2.4 1.4z", 0.16)
ICONS["mech_turret"] = (fill("M4.4 20.6h15.2l-2-5.4H6.4z") + fill("M7.6 15.2a4.4 4.4 0 0 1 8.8 0z") + fill("M11.4 10.2l8.4-5.4 1.2 1.8-8.4 5.4z")
                        + shade("M12 20.6h7.6l-2-5.4H12z", 0.16) + circ(12, 12.8, 1.2, "#1B1530", False))
ICONS["mech_boo"] = (fill(poly(star_pts(12, 12, 10.2, 6.2, 9, -90))) + shade(poly([(12, 12)] + star_pts(12, 12, 10.2, 6.2, 9, -90)[1:8]), 0.14)
                     + dark("M10.8 6.6h2.4l-.4 7.4h-1.6z") + circ(12, 16.6, 1.3, "#1B1530", False))

# ---------------------------------------------------------------- BOO! (Monster Kid): cowering face, brave badge
ICONS["intent_cower"] = (circ(11.2, 12.8, 8.4) + shade("M11.2 4.4a8.4 8.4 0 0 1 0 16.8c3-2.2 4.8-5.2 4.8-8.4s-1.8-6.2-4.8-8.4z", 0.16)
                         + dark("M6.6 10.4l3 1.6-3 1.2zM15.8 10.4l-3 1.6 3 1.2z")
                         + f'<path d="M7.6 17.6c1.2-1.4 2.4-1.4 3.6 0s2.4 1.4 3.6 0" fill="none" stroke="{O}" stroke-width="1.5" stroke-linecap="round"/>'
                         + f'<path d="M19.6 2.6c1.6 2.2 2.4 3.6 2.4 4.6a2.4 2.4 0 0 1-4.8 0c0-1 .8-2.4 2.4-4.6z" fill="#8FD8FF" stroke="{O}" stroke-width="1.2"/>')
ICONS["trait_brave"] = (fill(SHIELD) + shade("M12 2.9v18.3c4.4-1.4 7.6-5 7.6-9.7V5.8z")
                        + f'<path d="{poly(star_pts(12, 11.6, 4.6, 2.0))}" fill="{O}"/>')

for pid, body in P.items():
    ICONS["passive_" + pid] = body

os.makedirs(OUT, exist_ok=True)
for name, body in ICONS.items():
    with open(os.path.join(OUT, name + ".svg"), "w") as fh:
        fh.write(svg(body))
    with open(os.path.join(OUT, name + ".svg.import"), "w") as fh:
        fh.write('[remap]\n\nimporter="keep"\n')
print(len(ICONS), "icons")
