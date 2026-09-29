#!/usr/bin/env python3
"""Vector (SVG) app-icon art for Diceroll, rendered with cairosvg.

  vector_art.py <concept> <out.png> [size]     render one concept (default 1024)
  vector_art.py --list                          list concepts
  vector_art.py <concept> <out.svg>             write the SVG instead

Each concept is a function returning an SVG string on a 1024 canvas (full-bleed square,
no corner mask: iOS applies it). Dice are drawn from a small orthographic 3D model
(rounded cube: faces with round joins, per-face flat shading, pips mapped onto faces),
so every die is a real, consistent solid rather than a hand-drawn hexagon.
"""
import math
import sys

# Brand palette (ui/theme/palette.gd)
INK = "#0b0c1a"
NAVY = "#141630"
NAVY_2 = "#232863"
GOLD = "#f2b84b"
GOLD_BRIGHT = "#ffdc7a"
GOLD_DEEP = "#b8761f"
CREAM = "#f7f0dc"
RED = "#d9342b"

W = 1024


# --- small vector helpers ----------------------------------------------------------------

def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def rgb2hex(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v * 255))) for v in c)


def mix(a, b, t):
    a, b = hex2rgb(a), hex2rgb(b)
    return rgb2hex(tuple(x + (y - x) * t for x, y in zip(a, b)))


def shade(c, k):
    """k>1 lighter towards white, k<1 darker."""
    if k >= 1:
        return mix(c, "#ffffff", min(1.0, k - 1))
    return mix(c, "#000000", 1 - k)


def pts(p):
    return " ".join("%.2f,%.2f" % q for q in p)


def rot(v, yaw, pitch, roll=0.0):
    x, y, z = v
    # roll about z
    cr, sr = math.cos(roll), math.sin(roll)
    x, y = x * cr - y * sr, x * sr + y * cr
    # yaw about y
    cy, sy = math.cos(yaw), math.sin(yaw)
    x, z = x * cy + z * sy, -x * sy + z * cy
    # pitch about x (camera looking down)
    cp, sp = math.cos(pitch), math.sin(pitch)
    y, z = y * cp - z * sp, y * sp + z * cp
    return (x, y, z)


PIP_LAYOUT = {
    1: [(0, 0)],
    2: [(-1, -1), (1, 1)],
    3: [(-1, -1), (0, 0), (1, 1)],
    4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
    5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
    6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)],
}


class Die:
    """Orthographic rounded die. Faces: top(+y), front(+z), right(+x), ..."""

    FACES = {  # normal, u axis, v axis (v points "down" on the face texture)
        "top": ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
        "front": ((0, 0, 1), (1, 0, 0), (0, -1, 0)),
        "right": ((1, 0, 0), (0, 0, -1), (0, -1, 0)),
        "left": ((-1, 0, 0), (0, 0, 1), (0, -1, 0)),
        "back": ((0, 0, -1), (-1, 0, 0), (0, -1, 0)),
        "bottom": ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
    }

    def __init__(self, cx, cy, size, yaw=0.6, pitch=0.55, roll=0.0, body=CREAM, pip=INK,
                 values=None, light=(-0.45, 0.8, 0.55), outline=INK, outline_w=0.07, round_k=0.16,
                 pip_r=0.105, pip_spread=0.27, glyph=None, glyph_face=None, pip_color_map=None):
        self.c = (cx, cy)
        self.s = size
        self.yaw, self.pitch, self.roll = yaw, pitch, roll
        self.body, self.pip = body, pip
        self.values = values or {"top": 5, "front": 3, "right": 2, "left": 4, "back": 4, "bottom": 2}
        L = light
        n = math.sqrt(sum(v * v for v in L))
        self.light = tuple(v / n for v in L)
        self.outline, self.outline_w = outline, outline_w
        self.round_k = round_k
        self.pip_r, self.pip_spread = pip_r, pip_spread
        self.glyph, self.glyph_face = glyph, glyph_face
        self.pip_color_map = pip_color_map or {}

    def P(self, v):
        x, y, z = rot(v, self.yaw, self.pitch, self.roll)
        return (self.c[0] + x * self.s, self.c[1] - y * self.s, z)

    def _face_geom(self, name, inset=0.0):
        n, u, v = self.FACES[name]
        h = 0.5 - inset
        corners = []
        for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            p = tuple(n[i] * 0.5 + u[i] * a * h + v[i] * b * h for i in range(3))
            corners.append(self.P(p)[:2])
        nr = rot(n, self.yaw, self.pitch, self.roll)
        return corners, nr

    def visible(self):
        out = []
        for name in self.FACES:
            _, nr = self._face_geom(name)
            if nr[2] > 0.02:
                out.append((nr[2], name, nr))
        out.sort()
        return out

    def lum(self, nr):
        d = nr[0] * self.light[0] + nr[1] * self.light[1] + nr[2] * self.light[2]
        return d

    def hull(self):
        ps = []
        for name in self.FACES:
            c, _ = self._face_geom(name)
            ps += c
        return convex_hull(ps)

    def svg(self, face_fill=None, shading=(0.78, 1.06), rim=True):
        s = self.s
        rj = self.round_k * s  # rounding (stroke width of the round join)
        out = []
        hull = self.hull()
        if self.outline:
            out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>'
                       % (pts(hull), self.outline, self.outline, rj + 2 * self.outline_w * s))
        # base silhouette in the darkest face colour so round joins merge cleanly
        out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>'
                   % (pts(hull), shade(self.body, shading[0] * 0.92), shade(self.body, shading[0] * 0.92), rj))
        lo, hi = shading
        for _, name, nr in self.visible():
            corners, _ = self._face_geom(name, inset=0.035)
            l = self.lum(nr)
            k = lo + (hi - lo) * max(0.0, min(1.0, (l + 0.2) / 1.2))
            fill = (face_fill or {}).get(name) or shade(self.body, k)
            out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>'
                       % (pts(corners), fill, fill, rj * 0.9))
            if rim and l > 0.55:
                # soft specular sheen near the upper-left of the lit face
                pass
            out.append(self._pips(name, nr))
        return "\n".join(out)

    def _face_matrix(self, name):
        n, u, v = self.FACES[name]
        o = self.P(tuple(x * 0.5 for x in n))
        pu = self.P(tuple(n[i] * 0.5 + u[i] for i in range(3)))
        pv = self.P(tuple(n[i] * 0.5 + v[i] for i in range(3)))
        a, b = pu[0] - o[0], pu[1] - o[1]
        c, d = pv[0] - o[0], pv[1] - o[1]
        return "matrix(%.4f %.4f %.4f %.4f %.2f %.2f)" % (a, b, c, d, o[0], o[1])

    def _pips(self, name, nr):
        m = self._face_matrix(name)
        if self.glyph and name == self.glyph_face:
            return '<g transform="%s">%s</g>' % (m, self.glyph)
        val = self.values.get(name, 0)
        if not val:
            return ""
        col = self.pip_color_map.get(name, self.pip)
        sp = self.pip_spread
        r = self.pip_r
        cs = "".join('<circle cx="%.4f" cy="%.4f" r="%.4f" fill="%s"/>' % (x * sp, y * sp, r, col)
                     for x, y in PIP_LAYOUT[val])
        return '<g transform="%s">%s</g>' % (m, cs)

    def bottom_y(self):
        return max(p[1] for p in self.hull())


def convex_hull(points):
    pts_ = sorted(set((round(x, 3), round(y, 3)) for x, y in points))
    if len(pts_) <= 2:
        return pts_

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts_:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts_):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def svg_doc(body, defs=""):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
            '<defs>%s</defs>%s</svg>' % (defs, body))


def radial(id_, stops, cx=0.5, cy=0.45, r=0.75):
    s = "".join('<stop offset="%.3f" stop-color="%s" stop-opacity="%.3f"/>' % (o, c, a if len((o, c, a)) else 1)
                for o, c, a in stops)
    return '<radialGradient id="%s" cx="%.3f" cy="%.3f" r="%.3f">%s</radialGradient>' % (id_, cx, cy, r, s)


def linear(id_, stops, x1=0, y1=0, x2=0, y2=1):
    s = "".join('<stop offset="%.3f" stop-color="%s" stop-opacity="%.3f"/>' % (o, c, a) for o, c, a in stops)
    return ('<linearGradient id="%s" x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f">%s</linearGradient>'
            % (id_, x1, y1, x2, y2, s))


def blur_filter(id_, sd):
    return ('<filter id="%s" x="-50%%" y="-50%%" width="200%%" height="200%%">'
            '<feGaussianBlur stdDeviation="%.1f"/></filter>' % (id_, sd))


def shadow_ellipse(cx, cy, rx, ry, op=0.45, blur=18, color=INK, fid="sh"):
    return ('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="%.2f" filter="url(#%s)"/>'
            % (cx, cy, rx, ry, color, op, fid))


def bg_navy(extra_glow=GOLD, glow_op=0.55, cy=0.42):
    defs = radial("bg", [(0, NAVY_2, 1), (0.7, NAVY, 1), (1, INK, 1)], 0.5, cy, 0.8)
    defs += radial("glow", [(0, extra_glow, glow_op), (0.55, extra_glow, 0.0), (1, extra_glow, 0)], 0.5, cy, 0.62)
    body = '<rect width="1024" height="1024" fill="url(#bg)"/><rect width="1024" height="1024" fill="url(#glow)"/>'
    return defs, body


# --- concepts -----------------------------------------------------------------------------

def c_ring():
    """V1 Ring board: the 8x8 looping board seen from above, one cream die resting in the middle."""
    defs, body = bg_navy(GOLD, 0.22, 0.5)
    defs += blur_filter("sh", 14)
    n = 7  # tiles per side
    m = 118  # margin
    span = W - 2 * m
    t = span / n
    gap = 12
    cols = ["#e25a4f", "#3f8fe0", "#2fb3a6", GOLD, "#8a63d8", "#e25a4f", "#6fbf4a", "#3f8fe0"]
    tiles = []
    k = 0
    ring = []
    for i in range(n):
        ring.append((i, 0))
    for j in range(1, n):
        ring.append((n - 1, j))
    for i in range(n - 2, -1, -1):
        ring.append((i, n - 1))
    for j in range(n - 2, 0, -1):
        ring.append((0, j))
    for idx, (i, j) in enumerate(ring):
        x = m + i * t + gap / 2
        y = m + j * t + gap / 2
        s = t - gap
        c = cols[idx % len(cols)] if idx % 3 != 2 else "#cdbf9f"
        if idx == 0:
            c = GOLD_BRIGHT
        tiles.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="16" fill="%s"/>'
                     % (x, y + 12, s, s, shade(c, 0.55)))
        tiles.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="16" fill="%s"/>' % (x, y, s, s, c))
    d = Die(512, 520, 250, yaw=0.62, pitch=0.62, values={"top": 5, "front": 3, "right": 2})
    sh = shadow_ellipse(512 + 20, d.bottom_y() - 30, 190, 60, 0.55, 14)
    return svg_doc(body + "".join(tiles) + sh + d.svg(), defs)


def c_pair():
    """V2 Doubles: two chunky vector dice (cream + red Blade) resting on the same floor, both showing 3."""
    defs, body = bg_navy(GOLD, 0.6, 0.45)
    defs += blur_filter("sh", 16)
    floor_y = 760
    a = Die(0, 0, 330, yaw=0.5, pitch=0.5, values={"top": 3, "front": 2, "right": 6, "left": 4})
    b = Die(0, 0, 330, yaw=-0.35, pitch=0.5, body=RED, pip=CREAM, values={"top": 3, "front": 1, "left": 5, "right": 2})
    # rest both on the floor: shift so hull bottom == floor
    a.c = (350, floor_y - (a.bottom_y() - 0))
    b.c = (680, floor_y - (b.bottom_y() - 0) - 40)
    sh = shadow_ellipse(350, floor_y - 6, 210, 34, 0.6) + shadow_ellipse(680, floor_y - 46, 210, 34, 0.6)
    return svg_doc(body + sh + b.svg() + a.svg(), defs)


RUNE_GLYPH = ('<path d="M -0.03 -0.3 L -0.03 0.3 M -0.03 -0.3 L 0.2 -0.12 L -0.03 0.04 M -0.03 0.04 L 0.2 0.3" '
              'fill="none" stroke="{c}" stroke-width="0.09" stroke-linecap="round" stroke-linejoin="round"/>')


def c_rune():
    """V3 Rune die: one big gilded die, a glowing rune carved on its front, on navy."""
    defs, body = bg_navy(GOLD, 0.5, 0.45)
    defs += blur_filter("sh", 18) + blur_filter("gl", 22)
    d = Die(0, 0, 470, yaw=0.62, pitch=0.5, body=GOLD, pip=GOLD_DARK_HEX,
            values={"top": 1, "right": 6},
            glyph=RUNE_GLYPH.format(c="#fff6d8"), glyph_face="front")
    d.c = (512, 800 - d.bottom_y())
    glow = '<g filter="url(#gl)" opacity="0.9"><g transform="%s">%s</g></g>' % (
        d._face_matrix("front"), RUNE_GLYPH.format(c="#ffe9a0").replace("0.09", "0.2"))
    sh = shadow_ellipse(512, 800, 300, 40, 0.65)
    return svg_doc(body + sh + d.svg() + glow, defs)


GOLD_DARK_HEX = "#6e4214"


def c_monogram():
    """V4 Monogram: a 'D'-shaped die face (right side rounded) in gold, three navy pips on the diagonal."""
    defs, body = bg_navy(GOLD, 0.25, 0.5)
    defs += linear("gf", [(0, GOLD_BRIGHT, 1), (1, GOLD, 1)])
    defs += blur_filter("sh", 20)
    x0, y0, x1, y1 = 232, 212, 812, 812
    r = (y1 - y0) / 2
    path = ("M %d %d L %d %d A %d %d 0 0 1 %d %d L %d %d Z"
            % (x0 + 60, y0, x1 - r, y0, r, r, x1 - r, y1, x0 + 60, y1))
    base = '<path d="%s" fill="%s" stroke="%s" stroke-width="120" stroke-linejoin="round" transform="translate(0,24)"/>' % (path, GOLD_DEEP, GOLD_DEEP)
    face = '<path d="%s" fill="url(#gf)" stroke="%s" stroke-width="120" stroke-linejoin="round" />' % (path, GOLD)
    pips = "".join('<circle cx="%d" cy="%d" r="62" fill="%s"/>' % (x, y, NAVY) for x, y in ((345, 330), (512, 512), (680, 694)))
    sh = '<path d="%s" fill="%s" opacity="0.6" stroke="%s" stroke-width="120" stroke-linejoin="round" transform="translate(0,48)" filter="url(#sh)"/>' % (path, INK, INK)
    return svg_doc(body + sh + base + face + pips, defs)


def c_loop():
    """V5 Loop: a big cream die face showing one gold pip, circled by a gold looping arrow (reroll / lap)."""
    defs, body = bg_navy(GOLD, 0.2, 0.5)
    defs += blur_filter("sh", 18)
    d = Die(0, 0, 380, yaw=0.62, pitch=0.52, values={"top": 1, "front": 1, "right": 2}, pip_color_map={"front": RED})
    d.c = (512, 540)
    # loop arrow: an arc around the die, with a head
    cx, cy, R = 512, 520, 400
    a0, a1 = math.radians(200), math.radians(160 + 360 - 40)
    p0 = (cx + R * math.cos(a0), cy + R * math.sin(a0))
    p1 = (cx + R * math.cos(a1), cy + R * math.sin(a1))
    arc = ('<path d="M %.1f %.1f A %d %d 0 1 1 %.1f %.1f" fill="none" stroke="%s" stroke-width="58" stroke-linecap="round"/>'
           % (p0[0], p0[1], R, R, p1[0], p1[1], GOLD))
    # arrow head at p1 tangent
    tx, ty = -math.sin(a1), math.cos(a1)
    nx, ny = math.cos(a1), math.sin(a1)
    L = 90
    head = [(p1[0] + tx * L, p1[1] + ty * L), (p1[0] + nx * 75 - tx * 10, p1[1] + ny * 75 - ty * 10),
            (p1[0] - nx * 75 - tx * 10, p1[1] - ny * 75 - ty * 10)]
    headsvg = '<polygon points="%s" fill="%s" stroke="%s" stroke-width="20" stroke-linejoin="round"/>' % (pts(head), GOLD, GOLD)
    sh = shadow_ellipse(512, d.bottom_y() - 10, 230, 40, 0.55)
    return svg_doc(body + arc + headsvg + sh + d.svg(), defs)


HELMET = ('<g>'
          '<path d="M -0.3 0.34 L -0.3 -0.02 C -0.3 -0.26 -0.16 -0.36 0 -0.36 C 0.16 -0.36 0.3 -0.26 0.3 -0.02 L 0.3 0.34 Z" fill="{c}"/>'
          '<rect x="-0.22" y="-0.04" width="0.44" height="0.075" rx="0.035" fill="{bg}"/>'
          '<rect x="-0.035" y="-0.04" width="0.07" height="0.26" rx="0.03" fill="{bg}"/>'
          '</g>')


def c_hero():
    """V6 Hero face: a cream die whose front '1' is the knight's helmet (the die is the hero)."""
    defs, body = bg_navy(GOLD, 0.45, 0.45)
    defs += blur_filter("sh", 18)
    d = Die(0, 0, 470, yaw=0.55, pitch=0.42, values={"top": 3, "right": 2},
            glyph=HELMET.format(c=NAVY, bg=CREAM), glyph_face="front")
    d.c = (512, 800 - d.bottom_y())
    sh = shadow_ellipse(512, 800, 300, 40, 0.65)
    return svg_doc(body + sh + d.svg(), defs)


def d_path(x0, y0, x1, y1, r_left=70):
    """The 'D' die face: rounded-rect left side, a full half-circle on the right."""
    h = y1 - y0
    r = h / 2
    return ("M %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f L %.1f %.1f "
            "A %.1f %.1f 0 0 1 %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f Z"
            % (x0 + r_left, y0, x1 - r, y0, r, r, x1 - r, y1, x0 + r_left, y1,
               r_left, r_left, x0, y1 - r_left, x0, y0 + r_left, r_left, r_left, x0 + r_left, y0))


def c_loop2(arrow=GOLD, tiles=False):
    """Loop v2: a real die (5 / 3 / 2 faces) wrapped by a gold loop arrow (the lap, the reroll)."""
    defs, body = bg_navy(GOLD, 0.3, 0.5)
    defs += blur_filter("sh", 18)
    d = Die(0, 0, 360, yaw=0.62, pitch=0.62, values={"top": 5, "front": 3, "left": 1})
    d.c = (512, 520)
    cx, cy, R = 512, 512, 392
    parts = []
    # arrow drawn in two halves so the die overlaps the back half and the front half overlaps the die
    a_start, a_end = 150.0, 150.0 + 300.0
    def arc(a0, a1, w, col):
        p0 = (cx + R * math.cos(math.radians(a0)), cy + R * 0.42 * math.sin(math.radians(a0)))
        p1 = (cx + R * math.cos(math.radians(a1)), cy + R * 0.42 * math.sin(math.radians(a1)))
        large = 1 if (a1 - a0) % 360 > 180 else 0
        return ('<path d="M %.1f %.1f A %.1f %.1f 0 %d 1 %.1f %.1f" fill="none" stroke="%s" stroke-width="%d" '
                'stroke-linecap="round"/>' % (p0[0], p0[1], R, R * 0.42, large, p1[0], p1[1], col, w))
    ring_y = 700
    cy = ring_y
    back = arc(180, 360, 64, INK) + arc(180, 360, 44, GOLD_DEEP)
    front = arc(0, 150, 64, INK) + arc(0, 150, 44, arrow) + arc(210, 180 + 0.01, 1, arrow)
    # arrow head at angle 150 (pointing along travel direction, clockwise)
    a = math.radians(150)
    px, py = cx + R * math.cos(a), cy + R * 0.42 * math.sin(a)
    tx, ty = -R * math.sin(a), R * 0.42 * math.cos(a)
    n = math.hypot(tx, ty); tx, ty = tx / n, ty / n
    nx, ny = -ty, tx
    head = [(px + tx * 95, py + ty * 95), (px + nx * 70, py + ny * 70), (px - nx * 70, py - ny * 70)]
    headsvg = ('<polygon points="%s" fill="%s" stroke="%s" stroke-width="22" stroke-linejoin="round"/>'
               % (pts(head), arrow, INK))
    shift = ring_y - 40 - d.bottom_y()
    d.c = (512, d.c[1] + shift)
    sh = shadow_ellipse(512, ring_y - 30, 210, 50, 0.6)
    return svg_doc(body + back + sh + d.svg() + front + headsvg, defs)


CONCEPTS = {
    "loop2": c_loop2,
    "ring": c_ring,
    "pair": c_pair,
    "rune": c_rune,
    "monogram": c_monogram,
    "loop": c_loop,
    "hero": c_hero,
}


def render(name, out, size=1024):
    svg = CONCEPTS[name]()
    if out.endswith(".svg"):
        open(out, "w").write(svg)
        return
    import cairosvg
    cairosvg.svg2png(bytestring=svg.encode(), write_to=out, output_width=size, output_height=size)


def main(argv):
    if len(argv) >= 2 and argv[1] == "--list":
        print("\n".join(CONCEPTS))
        return 0
    if len(argv) < 3 or argv[1] not in CONCEPTS:
        print(__doc__)
        return 2
    render(argv[1], argv[2], int(argv[3]) if len(argv) > 3 else 1024)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
