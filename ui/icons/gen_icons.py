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

os.makedirs(OUT, exist_ok=True)
for name, body in ICONS.items():
    with open(os.path.join(OUT, name + ".svg"), "w") as fh:
        fh.write(svg(body))
    with open(os.path.join(OUT, name + ".svg.import"), "w") as fh:
        fh.write('[remap]\n\nimporter="keep"\n')
print(len(ICONS), "icons")
