#!/usr/bin/env python3
"""Diceroll monogram app icon: a "D"-shaped die (the shipped icon) + monogram concept family.

  monogram.py ship <out_dir> [gold|inverse]    render the shipped icon: render.png (light),
                                               render_dark.png (iOS dark), render_tint.png (tinted)
  monogram.py variant <out.png> key=value ...  one variant, e.g. colour=gold rot=-6 dx=-20 dy=-24
                                               scale=1.0 shadow=soft|hard|air|none style=slab|flat|bevel
                                               mode=light|dark|tint
  monogram.py concept <name> <out.png>         one monogram-family concept (see CONCEPTS)
  monogram.py --list                           list concepts

SHIP (below) is the pipeline default; `ICON_COLOURWAY=inverse tools/export.sh icon` (or changing
SHIP["colour"]) switches the colourway. Everything is flat SVG rendered with cairosvg at 1024.

Geometry notes: rotation turns the die only. The slab's depth (extrusion), the light and the
shadow stay fixed in world space (light from the top-left, shadow down-right), so a rotated die
still reads as one solid lit from one side.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vector_art import (INK, NAVY, NAVY_2, GOLD, GOLD_BRIGHT, GOLD_DEEP, CREAM, RED, Die, bg_navy, blur_filter,
                        linear, mix, pts, radial, svg_doc)

TEAL = "#2fb3a6"

# ---- the shipped icon -------------------------------------------------------------------------
# Change "colour" to "inverse" (or set ICON_COLOURWAY=inverse) to ship the navy-D-on-gold colourway.
# #1 = matrix variant G10 (gold D-die on navy, -6 deg, nudged up-left, 112 %, soft shadow).
# #2 = matrix variant I14 (navy D-die on gold, -10 deg, centred, 100 %, hard sticker shadow).
SHIP = {"colour": "gold", "rot": -6.0, "dx": -22.0, "dy": -26.0, "scale": 1.12, "shadow": "soft", "style": "slab"}
SHIP_INVERSE = {"colour": "inverse", "rot": -10.0, "dx": 0.0, "dy": 0.0, "scale": 1.0, "shadow": "hard",
                "style": "slab"}

SCHEMES = {
    # face, face highlight, side (extrusion), pip, pip highlight, outline, rim
    "gold": dict(face=GOLD, hi=GOLD_BRIGHT, side=GOLD_DEEP, pip=NAVY, pip_hi=None, outline=INK, rim=None),
    "inverse": dict(face=NAVY_2, hi="#343b8a", side=NAVY, pip=GOLD, pip_hi=GOLD_BRIGHT, outline=INK, rim=None),
    # iOS dark appearance: same die, near-black ground; the navy die gets a gold rim to separate
    "gold_dark": dict(face=GOLD, hi=GOLD_BRIGHT, side=GOLD_DEEP, pip="#0b0c1a", pip_hi=None, outline="#000000",
                      rim=None),
    "inverse_dark": dict(face="#2a3187", hi="#3d46a8", side="#161a42", pip=GOLD, pip_hi=GOLD_BRIGHT,
                         outline="#000000", rim=GOLD),
    # iOS tinted: grayscale luminance mask (light die, black pips, black ground)
    "tint": dict(face="#d8d8d8", hi="#ffffff", side="#6a6a6a", pip="#000000", pip_hi=None, outline="#000000",
                 rim=None),
}

BASE = 600.0  # face size at scale 1 (px on the 1024 canvas)
DIAG3 = ((0.2, 0.2), (0.5, 0.5), (0.8, 0.8))


def d_path(x0, y0, x1, y1, r_left):
    """The 'D' die face: rounded-rect left side, a full half-circle on the right."""
    r = (y1 - y0) / 2
    return ("M %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f L %.1f %.1f "
            "A %.1f %.1f 0 0 1 %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f Z"
            % (x0 + r_left, y0, x1 - r, y0, r, r, x1 - r, y1, x0 + r_left, y1,
               r_left, r_left, x0, y1 - r_left, x0, y0 + r_left, r_left, r_left, x0 + r_left, y0))


def background(colour, mode):
    if mode == "tint":
        return "", '<rect width="1024" height="1024" fill="#000000"/>'
    if mode == "dark":
        defs = radial("bg", [(0, "#1a1b30", 1), (0.7, "#0b0c16", 1), (1, "#040409", 1)], 0.5, 0.42, 0.8)
        return defs, '<rect width="1024" height="1024" fill="url(#bg)"/>'
    if colour == "inverse":
        defs = radial("bg", [(0, GOLD_BRIGHT, 1), (0.75, GOLD, 1), (1, GOLD_DEEP, 1)], 0.5, 0.4, 0.85)
        return defs, '<rect width="1024" height="1024" fill="url(#bg)"/>'
    return bg_navy(GOLD, 0.3, 0.46)


class DDie:
    """One D-die. (cx, cy) = centre of the whole solid (face + slab) before rotation."""

    _n = 0

    def __init__(self, cx=512, cy=512, scale=1.0, rot=0.0, scheme="gold", style="slab", pips=DIAG3,
                 pip_scale=1.0, depth=46, r_left=110, face_content=None, uid=None):
        DDie._n += 1
        self.id = uid or "d%d" % DDie._n
        self.sc = SCHEMES[scheme] if isinstance(scheme, str) else scheme
        self.scale, self.rot, self.style = scale, rot, style
        self.depth = 0 if style == "flat" else depth * scale
        self.s = BASE * scale
        # the face sits up-left of the solid's centre by half the slab depth
        self.fcx = cx - self.depth * 0.175
        self.fcy = cy - self.depth * 0.45
        self.x0, self.y0 = self.fcx - self.s / 2, self.fcy - self.s / 2
        self.path = d_path(self.x0, self.y0, self.x0 + self.s, self.y0 + self.s, r_left * scale)
        self.pips, self.pip_scale = pips, pip_scale
        self.face_content = face_content  # callable(ddie) -> svg in face-local (unrotated) coords

    def rot_t(self):
        return "rotate(%.2f %.1f %.1f)" % (self.rot, self.fcx, self.fcy)

    def shape(self, fill, tx=0.0, ty=0.0, extra=""):
        return '<path d="%s" fill="%s" transform="translate(%.1f,%.1f) %s" %s/>' % (
            self.path, fill, tx, ty, self.rot_t(), extra)

    def local(self, fx, fy):
        """Face-local fraction -> canvas point in the unrotated face frame (use inside rot group)."""
        return self.x0 + self.s * (0.1 + fx * 0.72), self.y0 + self.s * (0.1 + fy * 0.8)

    def shadow(self, kind):
        d = self.depth
        if kind == "soft":
            return self.shape(INK, d * 0.8 + 6, d * 1.6 + 14, 'opacity="0.55" filter="url(#sh)"')
        if kind == "hard":
            o = 34 * self.scale
            # sticker shadow: crisp offset copy; darker on the navy ground so it still reads
            op = 0.42 if self.sc["face"] in (NAVY_2, "#2a3187") else 0.75
            return self.shape("#000000" if op > 0.5 else INK, d * 0.35 + o, d * 0.9 + o * 1.25, 'opacity="%.2f"' % op)
        if kind == "air":
            gy = self.fcy + self.s * 0.5 + d + 120 * self.scale
            return ('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="0.5" filter="url(#sh)"/>'
                    % (self.fcx + 40, gy, self.s * 0.36, self.s * 0.07, INK))
        return ""

    def svg(self, shadow="soft"):
        sc, d, g = self.sc, self.depth, []
        g.append(self.shadow(shadow))
        ow = 30 * self.scale
        if sc["outline"]:
            steps = max(1, int(d // 4)) if d else 1
            for i in range(steps + 1):
                k = d * i / steps
                g.append(self.shape(sc["outline"], k * 0.35, k * 0.9,
                                    'stroke="%s" stroke-width="%.1f" stroke-linejoin="round"' % (sc["outline"], ow)))
        if d:
            n = max(2, int(d // 2))
            for i in range(n, 0, -1):
                k = d * i / n
                g.append(self.shape(mix(sc["side"], INK, 0.25 * k / d), k * 0.35, k * 0.9))
        gid = "gf" + self.id
        defs = linear(gid, [(0, sc["hi"], 1), (1, sc["face"], 1)], 0, 0, 0.6, 1)
        defs += '<clipPath id="c%s"><path d="%s" transform="%s"/></clipPath>' % (self.id, self.path, self.rot_t())
        g.append(self.shape("url(#%s)" % gid))
        clip = 'clip-path="url(#c%s)"' % self.id
        if self.style == "bevel":
            # world-fixed light: highlight on the top-left inner edge, shade on the bottom-right one
            g.append('<g %s>%s%s</g>' % (
                clip,
                self.shape("none", 6 * self.scale, 8 * self.scale,
                           'stroke="#ffffff" stroke-opacity="0.32" stroke-width="%.1f"' % (16 * self.scale)),
                self.shape("none", -8 * self.scale, -10 * self.scale,
                           'stroke="#000000" stroke-opacity="0.18" stroke-width="%.1f"' % (26 * self.scale))))
        else:
            g.append('<g %s>%s</g>' % (clip, self.shape("none", 0, 5, 'stroke="#ffffff" stroke-opacity="0.35" '
                                                                       'stroke-width="10"')))
        if sc.get("rim"):
            g.append(self.shape("none", 0, 0, 'stroke="%s" stroke-width="%.1f"' % (sc["rim"], 14 * self.scale)))
        inner = []
        if self.face_content:
            inner.append(self.face_content(self))
        pr = 64 * self.scale * self.pip_scale
        for fx, fy in self.pips or ():
            cx, cy = self.local(fx, fy)
            inner.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (cx, cy, pr, mix(sc["pip"], INK, 0.3)))
            inner.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (cx, cy + 7 * self.scale, pr - 3, sc["pip"]))
            if sc["pip_hi"]:
                inner.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="0.9"/>'
                             % (cx - pr * 0.3, cy - pr * 0.3, pr * 0.22, sc["pip_hi"]))
        g.append('<g transform="%s">%s</g>' % (self.rot_t(), "".join(inner)))
        return defs, "".join(g)


def variant_svg(colour="gold", rot=0.0, dx=0.0, dy=0.0, scale=1.0, shadow="soft", style="slab", mode="light",
                pip_scale=1.0):
    scheme = colour if mode == "light" else ("tint" if mode == "tint" else colour + "_dark")
    defs, body = background(colour, mode)
    defs += blur_filter("sh", 22)
    die = DDie(512 + dx, 512 + dy, scale, rot, scheme, style, pip_scale=pip_scale)
    ddefs, dsvg = die.svg("none" if mode == "tint" else shadow)
    return svg_doc(body + dsvg, defs + ddefs)


def label(v):
    return "%s  rot %+d  %s  %d%%  %s  %s" % (
        v.get("colour", "gold"), round(v.get("rot", 0)), v.get("place", "centred"), round(v.get("scale", 1) * 100),
        v.get("shadow", "soft"), v.get("style", "slab"))


# ---- monogram-family concepts ----------------------------------------------------------------

RUNE = ('<path d="M {x0} {y0} L {x0} {y1} M {x0} {y0} L {xm} {ya} L {x0} {yb} M {x0} {yb} L {xm} {y1}" '
        'fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>')


def _page(die_list, colour="gold", extra_front="", extra_back="", mode="light", defs_extra=""):
    defs, body = background(colour, mode)
    defs += blur_filter("sh", 22) + defs_extra
    out = [body, extra_back]
    for d, sh in die_list:
        dd, ds = d.svg(sh)
        defs += dd
        out.append(ds)
    out.append(extra_front)
    return svg_doc("".join(out), defs)


def n_rune():
    """D-die whose counter is one glowing rune (the rune system) instead of pips."""
    def rune(d):
        cx, cy = d.local(0.5, 0.5)
        h = 150 * d.scale
        x0, y0, y1 = cx - 34 * d.scale, cy - h, cy + h
        return (RUNE.format(x0=x0, y0=y0, y1=y1, xm=cx + 70 * d.scale, ya=cy - h * 0.45, yb=cy + h * 0.05,
                            c=NAVY, w=58 * d.scale))
    return _page([(DDie(512, 512, 1.06, -6, "gold", "bevel", pips=(), face_content=rune), "soft")])


def n_helmet():
    """D-die with the hero's helmet as its counter: the die is the hero."""
    def helm(d):
        cx, cy = d.local(0.47, 0.5)
        k = 330 * d.scale
        return ('<g transform="translate(%.1f %.1f) scale(%.1f)">'
                '<path d="M -0.3 0.36 L -0.3 -0.02 C -0.3 -0.28 -0.16 -0.38 0 -0.38 C 0.16 -0.38 0.3 -0.28 0.3 -0.02 '
                'L 0.3 0.36 Z" fill="%s"/>'
                '<rect x="-0.22" y="-0.05" width="0.44" height="0.085" rx="0.04" fill="%s"/>'
                '<rect x="-0.042" y="-0.05" width="0.084" height="0.28" rx="0.04" fill="%s"/></g>'
                % (cx, cy, k, NAVY, GOLD, GOLD))
    return _page([(DDie(512, 512, 1.06, -6, "gold", "bevel", pips=(), face_content=helm), "soft")])


def n_board():
    """The D as the looping board: tiles evenly spaced along a D outline, a die in the bowl."""
    defs, body = background("gold", "light")
    defs += blur_filter("sh", 16)
    s_, x0, y0 = 690, 190, 160
    r = s_ / 2
    left, top, bot, xr = x0, y0, y0 + s_, x0 + s_ - r
    L_stem, L_bar, L_arc = s_, xr - left, math.pi * r
    total = L_stem + 2 * L_bar + L_arc
    def at(u):  # u in [0,total): stem bottom->top, top bar, bowl, bottom bar
        if u < L_stem:
            return left, bot - u
        u -= L_stem
        if u < L_bar:
            return left + u, top
        u -= L_bar
        if u < L_arc:
            a = -math.pi / 2 + u / r
            return xr + r * math.cos(a), y0 + r + r * math.sin(a)
        u -= L_arc
        return xr - u, bot
    n = 16
    t = 92
    tiles = []
    for i in range(n):
        x, y = at(total * i / n)
        c = GOLD_BRIGHT if i == 0 else (RED if i in (5, 11) else (TEAL if i == 8 else ("#efe6cf" if i % 2 else "#d9ccab")))
        tiles.append('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="18" fill="%s"/>' % (x - t / 2, y - t / 2 + 14, t, t, INK))
        tiles.append('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="18" fill="%s" stroke="%s" stroke-width="9"/>'
                     % (x - t / 2, y - t / 2, t, t, c, INK))
    die = Die(0, 0, 230, yaw=0.62, pitch=0.62, values={"top": 5, "front": 3, "left": 1})
    die.c = (x0 + s_ * 0.44, y0 + s_ * 0.5)
    sh = ('<ellipse cx="%.1f" cy="%.1f" rx="150" ry="34" fill="%s" opacity="0.55" filter="url(#sh)"/>'
          % (die.c[0] + 10, die.bottom_y() - 16, INK))
    return svg_doc(body + "".join(tiles) + sh + die.svg(), defs)


def n_doubles():
    """Doubles: a red D-die behind the gold one, both showing three."""
    red = dict(face=RED, hi="#f0605a", side="#8a1f1a", pip=CREAM, pip_hi=None, outline=INK, rim=None)
    back = DDie(640, 400, 0.66, 12, red, "slab")
    front = DDie(430, 585, 0.78, -8, "gold", "slab")
    return _page([(back, "soft"), (front, "soft")])


def n_iso():
    """Isometric 3D-flat die whose top face carries the D in negative space."""
    defs, body = background("gold", "light")
    defs += blur_filter("sh", 18)
    dglyph = ('<path d="M -0.26 -0.3 L 0.02 -0.3 A 0.3 0.3 0 0 1 0.02 0.3 L -0.26 0.3 Z" fill="%s"/>'
              '<circle cx="0.02" cy="0" r="0.07" fill="%s"/>' % (NAVY, GOLD))
    d = Die(0, 0, 460, yaw=0.785, pitch=0.62, body=GOLD, pip=NAVY, values={"front": 3, "left": 2},
            glyph=dglyph, glyph_face="top")
    d.c = (512, 540)
    sh = ('<ellipse cx="530" cy="%.1f" rx="280" ry="46" fill="%s" opacity="0.6" filter="url(#sh)"/>'
          % (d.bottom_y() - 20, INK))
    return svg_doc(body + sh + d.svg(), defs)


def n_sticker():
    """Flat sticker: navy D-die, thick gold rim, cream pips, a sparkle on the top pip. White die-cut edge."""
    sc = dict(face=NAVY_2, hi="#2e357e", side=NAVY, pip=CREAM, pip_hi=None, outline="#fbf3e2", rim=GOLD)
    d = DDie(512, 512, 1.02, -8, sc, "flat")
    def sparkle():
        cx, cy = d.local(0.2, 0.2)
        cx, cy = cx + 70, cy - 70
        r = 46
        star = [(cx, cy - r), (cx + r * 0.22, cy - r * 0.22), (cx + r, cy), (cx + r * 0.22, cy + r * 0.22),
                (cx, cy + r), (cx - r * 0.22, cy + r * 0.22), (cx - r, cy), (cx - r * 0.22, cy - r * 0.22)]
        return '<g transform="%s"><polygon points="%s" fill="%s"/></g>' % (d.rot_t(), pts(star), GOLD_BRIGHT)
    return _page([(d, "hard")], "gold", extra_front=sparkle())


def n_stacked():
    """A D built from nine small dice (stem + bowl), each a flat die face."""
    defs, body = background("gold", "light")
    cells = [(300, 250), (300, 400), (300, 550), (300, 700), (440, 230), (590, 300), (660, 460), (590, 620),
             (440, 690)]
    vals = [1, 2, 3, 6, 5, 4, 1, 3, 2]
    out = []
    t = 150
    from vector_art import PIP_LAYOUT
    for (x, y), v in zip(cells, vals):
        out.append('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="30" fill="%s"/>' % (x - t / 2 + 8, y - t / 2 + 14, t, t, INK))
        out.append('<rect x="%.1f" y="%.1f" width="%d" height="%d" rx="30" fill="%s" stroke="%s" stroke-width="10"/>'
                   % (x - t / 2, y - t / 2, t, t, GOLD if v != 6 else RED, INK))
        for px, py in PIP_LAYOUT[v]:
            out.append('<circle cx="%.1f" cy="%.1f" r="13" fill="%s"/>' % (x + px * 38, y + py * 38, NAVY if v != 6 else CREAM))
    return svg_doc(body + "".join(out), defs)


def n_trail():
    """The D-die mid-roll: lifted, tilted, three speed arcs sweeping in from the upper left, shadow below."""
    d = DDie(590, 470, 0.84, -16, "gold", "slab")
    arcs = []
    for i, (w, op) in enumerate(((30, 0.9), (22, 0.65), (16, 0.45))):
        y = 300 + i * 95
        arcs.append('<path d="M %.1f %.1f Q %.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="%d" '
                    'stroke-linecap="round" opacity="%.2f"/>'
                    % (90 + i * 25, y - 150, 170 + i * 20, y - 20, 300, y + 20, GOLD_BRIGHT, w, op))
    return _page([(d, "air")], "gold", extra_back="".join(arcs))


def n_pipd():
    """A square gold die face whose six pips are laid out as the letter D."""
    defs, body = background("gold", "light")
    defs += linear("gf", [(0, GOLD_BRIGHT, 1), (1, GOLD, 1)], 0, 0, 0.6, 1) + blur_filter("sh", 22)
    x0, y0, s = 222, 200, 580
    out = ['<rect x="%d" y="%d" width="%d" height="%d" rx="120" fill="%s" opacity="0.55" filter="url(#sh)"/>'
           % (x0 + 30, y0 + 60, s, s, INK)]
    out.append('<rect x="%d" y="%d" width="%d" height="%d" rx="120" fill="%s" stroke="%s" stroke-width="30"/>'
               % (x0 + 16, y0 + 40, s, s, GOLD_DEEP, INK))
    out.append('<rect x="%d" y="%d" width="%d" height="%d" rx="120" fill="url(#gf)" stroke="%s" stroke-width="30"/>'
               % (x0, y0, s, s, INK))
    ps = [(x0 + s * fx, y0 + s * fy) for fx, fy in
          ((0.26, 0.22), (0.26, 0.5), (0.26, 0.78), (0.55, 0.24), (0.77, 0.5), (0.55, 0.76))]
    for x, y in ps:
        out.append('<circle cx="%.1f" cy="%.1f" r="56" fill="%s"/>' % (x, y, NAVY))
    return svg_doc(body + "".join(out), defs)


def n_crown():
    """Champion mark: the gold D-die wearing a small red-jewelled crown resting on its top edge."""
    d = DDie(512, 590, 0.88, 0, "gold", "slab")
    top = d.y0
    cx = d.fcx - 60
    w, h = 250, 150
    crown = [(cx - w / 2, top + 6), (cx - w / 2, top - h * 0.7), (cx - w / 4, top - h * 0.3), (cx, top - h),
             (cx + w / 4, top - h * 0.3), (cx + w / 2, top - h * 0.7), (cx + w / 2, top + 6)]
    c = ('<polygon points="%s" fill="%s" stroke="%s" stroke-width="22" stroke-linejoin="round"/>'
         '<circle cx="%.1f" cy="%.1f" r="22" fill="%s" stroke="%s" stroke-width="8"/>'
         % (pts(crown), GOLD_BRIGHT, INK, cx, top - h * 0.28, RED, INK))
    return _page([(d, "soft")], "gold", extra_front=c)


def n_tile():
    """The D-die resting on a small board tile (teal inset top, wooden plinth), its bottom ON the tile top."""
    d = DDie(512, 440, 0.82, 0, "gold", "slab")
    tile_top = d.fcy + d.s / 2 + d.depth * 0.9 + 12   # bottom of the slab + outline
    x0, x1 = 170, 854
    tl = ('<rect x="%d" y="%.1f" width="%d" height="120" rx="36" fill="%s" stroke="%s" stroke-width="22"/>'
          '<rect x="%d" y="%.1f" width="%d" height="60" rx="26" fill="%s"/>'
          % (x0, tile_top, x1 - x0, "#8a5a2b", INK, x0 + 30, tile_top + 14, x1 - x0 - 60, TEAL))
    sh = ('<ellipse cx="530" cy="%.1f" rx="300" ry="22" fill="%s" opacity="0.45" filter="url(#sh)"/>'
          % (tile_top + 20, INK))
    return _page([(d, "none")], "gold", extra_back=tl + sh)


CONCEPTS = {
    "rune": n_rune, "helmet": n_helmet, "board": n_board, "doubles": n_doubles, "iso": n_iso,
    "sticker": n_sticker, "stacked": n_stacked, "trail": n_trail, "pipd": n_pipd, "crown": n_crown,
    "tile": n_tile,
}


# ---- D-die + looping board path (branch A) and "just the pips" + path (branch B) -----------------

# Tile-type colours (game/world/tile_style.gd), sRGB hex
T_START, T_ENEMY, T_CHEST, T_EVENT, T_CAMP, T_PORTAL = "#fad675", "#e6423d", "#478ffa", "#3dccc7", "#75d14d", "#9e66fa"
T_CREAM, T_SAND = "#efe6cf", "#d9ccab"
GAME_CYCLE = [T_ENEMY, T_CHEST, T_SAND, T_EVENT, T_ENEMY, T_CAMP, T_SAND, T_PORTAL]


def _poly_len(poly):
    return sum(math.dist(poly[i], poly[i + 1]) for i in range(len(poly) - 1))


def _sample(poly, n, offset=0.0):
    """n points evenly spaced by arc length along a closed polyline (first == last)."""
    total = _poly_len(poly)
    out = []
    for k in range(n):
        u = (offset + total * k / n) % total
        for i in range(len(poly) - 1):
            L = math.dist(poly[i], poly[i + 1])
            if u <= L or i == len(poly) - 2:
                t = u / L if L else 0
                out.append((poly[i][0] + (poly[i + 1][0] - poly[i][0]) * t, poly[i][1] + (poly[i + 1][1] - poly[i][1]) * t))
                break
            u -= L
    return out


def ring_poly(shape, x0, y0, x1, y1, rc=0.0):
    """Closed polyline of the ring's centre line. Starts at the bottom-left corner, runs up the left
    side (clockwise on screen), like the game's board which starts bottom-left."""
    if shape == "square":
        return [(x0, y1), (x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    if shape == "rounded":
        p = []
        cs = [((x0 + rc, y0 + rc), 180), ((x1 - rc, y0 + rc), 270), ((x1 - rc, y1 - rc), 0), ((x0 + rc, y1 - rc), 90)]
        p.append((x0, y1 - rc))
        for (cx, cy), a0 in cs:
            for i in range(13):
                a = math.radians(a0 + 90 * i / 12)
                p.append((cx + rc * math.cos(a), cy + rc * math.sin(a)))
        p.append((x0, y1 - rc))
        return p
    if shape == "circle":
        cx, cy, r = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2
        return [(cx + r * math.cos(math.radians(135 + 360 * i / 96)), cy - r * math.sin(math.radians(135 + 360 * i / 96)))
                for i in range(97)]
    if shape == "d":
        r = (y1 - y0) / 2
        xr = x1 - r
        p = [(x0, y1), (x0, y0), (xr, y0)]
        for i in range(1, 36):
            a = -math.pi / 2 + math.pi * i / 36
            p.append((xr + r * math.cos(a), y0 + r + r * math.sin(a)))
        p += [(xr, y1), (x0, y1)]
        return p
    raise ValueError(shape)


def tile_svg(x, y, t, fill, glow=False, pip=None, rnd=0.24, round_tile=False):
    o = []
    if glow:
        o.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="url(#gg)"/>' % (x, y, t * 1.05))
    lip = t * 0.13
    sw = max(6.0, t * 0.085)
    if round_tile:
        o.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (x, y + lip, t / 2, INK))
        o.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="%.1f"/>' % (x, y, t / 2, fill, INK, sw))
    else:
        o.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s"/>'
                 % (x - t / 2, y - t / 2 + lip, t, t, t * rnd, INK))
        o.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s" stroke="%s" stroke-width="%.1f"/>'
                 % (x - t / 2, y - t / 2, t, t, t * rnd, fill, INK, sw))
    if pip:
        o.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (x, y, t * 0.2, pip))
    return "".join(o)


def big_pip(x, y, r, col=GOLD, glow=False):
    o = []
    if glow:
        o.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="url(#gg)"/>' % (x, y, r * 1.9))
    o.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (x, y + r * 0.14, r + r * 0.16, INK))
    o.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="%.1f"/>' % (x, y, r, col, INK, r * 0.16))
    o.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#ffffff" opacity="0.45"/>' % (x - r * 0.32, y - r * 0.32, r * 0.22))
    return "".join(o)


def hero_token(x, y, s):
    """A tiny pawn standing on a tile (feet on the tile's top face)."""
    return ('<g transform="translate(%.1f %.1f) scale(%.2f)">'
            '<ellipse cx="0" cy="4" rx="34" ry="10" fill="%s" opacity="0.5"/>'
            '<path d="M -30 4 C -30 -30 -16 -50 0 -50 C 16 -50 30 -30 30 4 Z" fill="%s" stroke="%s" stroke-width="9"/>'
            '<circle cx="0" cy="-70" r="24" fill="%s" stroke="%s" stroke-width="9"/></g>'
            % (x, y, s, INK, CREAM, INK, CREAM, INK))


def colours(scheme, n, start=0):
    if scheme == "gold":
        return [T_START if i == start else (GOLD if i % 2 else T_CREAM) for i in range(n)]
    if scheme == "cream":
        return [T_START if i == start else T_CREAM for i in range(n)]
    if scheme == "game":
        return [T_START if i == start else GAME_CYCLE[(i - 1) % len(GAME_CYCLE)] for i in range(n)]
    if scheme == "navy":
        return [GOLD_BRIGHT if i == start else ("#2e357e" if i % 2 else NAVY_2) for i in range(n)]
    raise ValueError(scheme)


def d_tiles(x0, y0, x1, y1, n_stem=4):
    """Tile centres on a D: a straight stem with a tile on each corner, top/bottom bars and the bowl,
    all at (about) the stem's spacing, so corner tiles never collide. Starts bottom-left."""
    h = y1 - y0
    sp = h / (n_stem - 1)
    r = h / 2
    xr = x1 - r
    out = [(x0, y1 - i * sp) for i in range(n_stem)]
    bar = xr - x0
    nb = max(1, round(bar / sp))
    out += [(x0 + j * bar / nb, y0) for j in range(1, nb + 1)]
    na = max(2, round(math.pi * r / sp))
    out += [(xr + r * math.cos(-math.pi / 2 + math.pi * k / na), y0 + r + r * math.sin(-math.pi / 2 + math.pi * k / na))
            for k in range(1, na)]
    out += [(xr - j * bar / nb, y1) for j in range(0, nb)]
    return out, sp


def loop_page(shape="square", n=12, t=120, box=(150, 150, 874, 874), rc=90, scheme="gold", die=None,
              pips=None, glow_tile=None, hero_tile=None, bg="gold", gap=None, arc=False, round_tiles=False,
              tile_pips=None, offset=0.0, extra_front="", extra_back="", fills=None, tf=0.78):
    defs, body = background(bg, "light")
    defs += blur_filter("sh", 20)
    defs += radial("gg", [(0, GOLD_BRIGHT, 0.95), (0.45, GOLD, 0.55), (1, GOLD, 0)], 0.5, 0.5, 0.5)
    x0, y0, x1, y1 = box
    poly = ring_poly(shape, x0, y0, x1, y1, rc)
    m = n + (gap or 0)
    if tf and m:  # tile size from the spacing along the path: tiles nearly touch, like the real board
        t = _poly_len(poly) / m * tf
    ptsl = _sample(poly, m, offset)[:n]
    if shape == "d" and n == 0:  # explicit D layout (corner tiles on the stem)
        ptsl, sp = d_tiles(x0, y0, x1, y1)
        n = len(ptsl)
        t = sp * (tf or 0.78)
    cols = colours(scheme, max(n, 1))
    for k, v in (fills or {}).items():
        cols[k] = v
    out = [body, extra_back]
    if arc:
        # the path opens: the missing tiles become a gold motion arc into the die
        a, b = _sample(poly, m, offset)[n - 1], _sample(poly, m, offset)[0]
        out.append('<path d="M %.1f %.1f Q %.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="%.1f" '
                   'stroke-linecap="round" stroke-dasharray="1 %.1f"/>'
                   % (a[0], a[1], (a[0] + b[0]) / 2 + 60, (a[1] + b[1]) / 2 + 60, b[0], b[1], GOLD_BRIGHT, t * 0.28, t * 0.55))
    for i, (x, y) in enumerate(ptsl):
        pip = None
        if tile_pips and i in tile_pips:
            pip = tile_pips[i]
        out.append(tile_svg(x, y, t, cols[i], glow=(glow_tile == i), pip=pip, round_tile=round_tiles))
    ddefs = ""
    if die is not None:
        dd, ds = die.svg("soft")
        ddefs += dd
        out.append(ds)
    if pips:
        for (x, y, r, col, g) in pips:
            out.append(big_pip(x, y, r, col, g))
    if hero_tile is not None:
        hx, hy = ptsl[hero_tile]
        out.append(hero_token(hx, hy + t * 0.12, t / 150))
    out.append(extra_front)
    return svg_doc("".join(out), defs + ddefs)


def g10_die(scale, cx=512, cy=512, rot=-6, colour="gold"):
    return DDie(cx, cy, scale, rot, colour, "slab")


DIAG = lambda c, s, r, col=GOLD, g=False: [(c[0] - s, c[1] - s, r, col, g), (c[0], c[1], r, col, g), (c[0] + s, c[1] + s, r, col, g)]

COMBOS = {
    # --- A: D-die + path
    "A1_sq12_gold": lambda: loop_page("square", 12, 0, (190, 190, 834, 834), scheme="gold", die=g10_die(0.52)),
    "A2_sq16_game": lambda: loop_page("square", 16, 0, (175, 175, 849, 849), scheme="game", die=g10_die(0.58)),
    "A3_round12_glow": lambda: loop_page("rounded", 12, 0, (190, 190, 834, 834), rc=150, scheme="cream",
                                         die=g10_die(0.52), glow_tile=0),
    "A4_dpath14": lambda: loop_page("d", 14, 0, (180, 190, 860, 850), scheme="cream", die=g10_die(0.5, 490, 520),
                                    glow_tile=0),
    "A5_circle10_hero": lambda: loop_page("circle", 10, 0, (195, 195, 829, 829), scheme="game",
                                          die=g10_die(0.52), hero_tile=0),
    "A6_sq8_overlap": lambda: loop_page("square", 8, 0, (225, 225, 799, 799), scheme="gold",
                                        die=g10_die(0.8, 570, 570)),
    "A7_open_arc": lambda: loop_page("rounded", 10, 0, (190, 190, 834, 834), rc=150, scheme="game", gap=2,
                                     arc=True, die=g10_die(0.52), offset=40),
    "A8_inverse_sq12": lambda: loop_page("square", 12, 0, (190, 190, 834, 834), scheme="navy", bg="inverse",
                                         die=g10_die(0.52, colour="inverse")),
    # --- B: just the pips
    "B1_pips_in_ring": lambda: loop_page("square", 12, 0, (190, 190, 834, 834), scheme="cream",
                                         pips=DIAG((512, 512), 115, 62)),
    "B2_pip_ring": lambda: loop_page("rounded", 12, 0, (190, 190, 834, 834), rc=170, scheme="cream", round_tiles=True,
                                     glow_tile=0, pips=[(512, 512, 120, GOLD, False)]),
    "B3_one_pip_sq8": lambda: loop_page("square", 8, 0, (225, 225, 799, 799), scheme="gold",
                                        pips=[(512, 512, 118, GOLD, True)]),
    "B4_travelling_pip": lambda: loop_page("square", 12, 0, (190, 190, 834, 834), scheme="cream", glow_tile=0,
                                           tile_pips={0: NAVY}, pips=DIAG((512, 512), 112, 54, CREAM)),
    "B5_start_target": lambda: loop_page("square", 12, 0, (190, 190, 834, 834), scheme="cream",
                                         tile_pips={0: NAVY, 5: CREAM}, fills={5: T_ENEMY},
                                         extra_front=('<path d="M 300 690 Q 380 400 620 330" fill="none" stroke="%s" '
                                                      'stroke-width="30" stroke-linecap="round" stroke-dasharray="2 56"/>'
                                                      % GOLD_BRIGHT)),
    "B6_dpath_pips": lambda: loop_page("d", 14, 0, (180, 190, 860, 850), scheme="cream", glow_tile=0,
                                       pips=DIAG((490, 520), 100, 52)),
    # --- refinements of the top 3 (fewer, bigger tiles for 29 px; one glowing start tile)
    "R1_dpath_pips": lambda: loop_page("d", 0, 0, (215, 210, 845, 830), scheme="gold", glow_tile=0, tf=0.76,
                                       pips=DIAG((490, 520), 96, 58)),
    "R2_dpath_die": lambda: loop_page("d", 0, 0, (215, 210, 845, 830), scheme="gold", glow_tile=0, tf=0.76,
                                      die=g10_die(0.5, 500, 522)),
    "R3_sq8_overlap": lambda: loop_page("square", 8, 0, (240, 240, 784, 784), scheme="gold", glow_tile=0, tf=0.7,
                                        die=g10_die(0.66, 590, 590)),
}
CONCEPTS.update(COMBOS)


def to_png(svg, out, size=1024):
    if out.endswith(".svg"):
        open(out, "w").write(svg)
        return
    import cairosvg
    cairosvg.svg2png(bytestring=svg.encode(), write_to=out, output_width=size, output_height=size)


def parse_kv(args):
    v = {}
    for a in args:
        k, val = a.split("=", 1)
        try:
            v[k] = float(val)
        except ValueError:
            v[k] = val
    return v


def main(argv):
    if len(argv) >= 2 and argv[1] == "--list":
        print("\n".join(CONCEPTS))
        return 0
    if len(argv) >= 3 and argv[1] == "ship":
        colour = argv[3] if len(argv) > 3 else os.environ.get("ICON_COLOURWAY", SHIP["colour"])
        v = dict(SHIP_INVERSE if colour == "inverse" else SHIP)
        os.makedirs(argv[2], exist_ok=True)
        for mode, name in (("light", "render.png"), ("dark", "render_dark.png"), ("tint", "render_tint.png")):
            to_png(variant_svg(mode=mode, **v), os.path.join(argv[2], name))
        print("monogram: shipped %s" % label(v))
        return 0
    if len(argv) >= 3 and argv[1] == "variant":
        to_png(variant_svg(**parse_kv(argv[3:])), argv[2])
        return 0
    if len(argv) >= 4 and argv[1] == "concept" and argv[2] in CONCEPTS:
        to_png(CONCEPTS[argv[2]](), argv[3])
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
