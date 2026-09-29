#!/usr/bin/env python3
"""Icon post-processing for Diceroll (needs Pillow).

  icon_tools.py ios    <render.png> <out.png>            flatten to opaque RGB 1024 (iOS / App Store)
  icon_tools.py tinted <render.png> <out.png>            grayscale opaque (iOS 18 tinted)
  icon_tools.py macos  <render.png> <out.png>            macOS grid: 824 px squircle body + shadow, transparent
  icon_tools.py iconset <macos.png> <dir.iconset>        16..512@2x PNGs for iconutil
  icon_tools.py sheet  <out.png> <label=render.png>...   comparison sheet: 1024/180/120/60/29 px, masked,
                                                         on light and dark home-screen backgrounds
  icon_tools.py grid   <out.png> label=cand.png ... -- label=ref.png ...
                                                         crowded home-screen mock: each candidate at 60 px
                                                         among competitor icons, light + dark wallpaper
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 4  # supersampling for masks


def squircle_mask(size, radius_frac=0.2237, n=5.0):
    """Apple-like continuous-corner mask: superellipse corners blended into straight edges.

    Uses a superellipse |x|^n + |y|^n <= 1 per corner of radius r*1.25 (the continuous
    curve starts earlier than a circular one), supersampled for smooth edges."""
    big = size * SS
    r = radius_frac * big * 1.28
    m = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(m)
    d.rectangle([0, 0, big, big], fill=255)
    # carve the four corners
    pts = []
    import math
    steps = 256
    for i in range(steps + 1):
        t = i / steps * (math.pi / 2)
        c, s = math.cos(t), math.sin(t)
        x = abs(c) ** (2.0 / n)
        y = abs(s) ** (2.0 / n)
        pts.append((x, y))
    for cx, cy, sx, sy in ((r, r, -1, -1), (big - r, r, 1, -1), (big - r, big - r, 1, 1), (r, big - r, -1, 1)):
        corner = Image.new("L", (big, big), 0)
        cd = ImageDraw.Draw(corner)
        poly = [(cx + sx * x * r, cy + sy * y * r) for x, y in pts]
        poly.append((cx, cy))
        cd.polygon(poly, fill=255)
        # region outside the curve inside the corner square -> transparent
        box = [min(cx, cx + sx * r), min(cy, cy + sy * r), max(cx, cx + sx * r), max(cy, cy + sy * r)]
        sq = Image.new("L", (big, big), 0)
        ImageDraw.Draw(sq).rectangle(box, fill=255)
        from PIL import ImageChops
        outside = ImageChops.subtract(sq, corner)
        m = ImageChops.subtract(m, outside)
    return m.resize((size, size), Image.LANCZOS)


def load_rgb(path):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, (0, 0, 0, 255))
    bg.alpha_composite(im)
    im = bg.convert("RGB")
    if im.size != (1024, 1024):
        im = im.resize((1024, 1024), Image.LANCZOS)
    return im


def cmd_ios(src, out):
    load_rgb(src).save(out, optimize=True)


def cmd_tinted(src, out):
    """iOS 18 tinted variant: grayscale, opaque; the system tints it."""
    from PIL import ImageOps
    g = ImageOps.autocontrast(load_rgb(src).convert("L"), cutoff=0.5)
    g.convert("RGB").save(out, optimize=True)


def cmd_macos(src, out):
    art = load_rgb(src)
    body = 824
    off = (1024 - body) // 2
    art = art.resize((body, body), Image.LANCZOS).convert("RGBA")
    mask = squircle_mask(body, radius_frac=0.225)
    # subtle inner edge highlight so the body reads on dark docks
    edge = Image.new("RGBA", (body, body), (255, 236, 190, 0))
    inner = mask.filter(ImageFilter.MinFilter(5))
    from PIL import ImageChops
    ring = ImageChops.subtract(mask, inner).point(lambda v: v * 0.22)
    edge.putalpha(ring)
    art.alpha_composite(edge)
    art.putalpha(mask)
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    sm = Image.new("L", (1024, 1024), 0)
    sm.paste(mask, (off, off + 12))
    sm = sm.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.42))
    shadow.putalpha(sm)
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(art, (off, off))
    canvas.save(out, optimize=True)


def cmd_iconset(src, outdir):
    import os
    os.makedirs(outdir, exist_ok=True)
    im = Image.open(src).convert("RGBA")
    for s in (16, 32, 128, 256, 512):
        im.resize((s, s), Image.LANCZOS).save(f"{outdir}/icon_{s}x{s}.png")
        im.resize((s * 2, s * 2), Image.LANCZOS).save(f"{outdir}/icon_{s}x{s}@2x.png")


def font(size):
    for p in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


def _wrap(d, xy, text, f, width, fill=(20, 20, 20), lh=26):
    """Draws `text` word-wrapped to `width` px."""
    x, y = xy
    line = ""
    for w in text.split():
        t = (line + " " + w).strip()
        if d.textlength(t, font=f) > width and line:
            d.text((x, y), line, fill=fill, font=f)
            y += lh
            line = w
        else:
            line = t
    if line:
        d.text((x, y), line, fill=fill, font=f)


def cmd_sheet(out, items):
    sizes = [180, 120, 60, 29]
    big = 300
    pad = 24
    row_h = big + 2 * pad
    group_w = sum(sizes) + pad * (len(sizes) + 1)
    W = 200 + big + pad + 2 * group_w + pad
    H = 40 + row_h * len(items)
    sheet = Image.new("RGB", (W, H), (245, 243, 238))
    d = ImageDraw.Draw(sheet)
    f = font(22)
    light = (232, 226, 214)  # light wallpaper
    dark = (22, 22, 28)
    d.text((200 + big + pad + pad, 10), "light home screen", fill=(40, 40, 40), font=font(18))
    d.text((200 + big + pad + group_w + pad, 10), "dark home screen", fill=(40, 40, 40), font=font(18))
    for i, (label, path) in enumerate(items):
        y0 = 40 + i * row_h
        art = load_rgb(path).convert("RGBA")
        mask = squircle_mask(1024)
        art.putalpha(mask)
        _wrap(d, (pad, y0 + pad), label, f, 200 - 2 * pad)
        sheet.paste(art.resize((big, big), Image.LANCZOS), (200, y0 + pad), art.resize((big, big), Image.LANCZOS))
        for g, bgc in enumerate((light, dark)):
            gx = 200 + big + pad + g * group_w
            d.rectangle([gx, y0 + 4, gx + group_w - 4, y0 + row_h - 4], fill=bgc)
            x = gx + pad
            for s in sizes:
                small = art.resize((s, s), Image.LANCZOS)
                sheet.paste(small, (x, y0 + pad + (big - s) // 2), small)
                x += s + pad
    sheet.save(out)


def _home_grid(cands, refs, bg, cols=4, icon=60, gap_x=27, gap_y=26, label_color=(255, 255, 255), labels=None):
    """One iPhone-like home-screen page (1x scale: 60 px icons) with `cands` mixed into `refs`."""
    rows = (len(cands) + len(refs) + cols - 1) // cols
    pad = 24
    w = pad * 2 + cols * icon + (cols - 1) * gap_x
    h = pad * 2 + rows * (icon + 14) + (rows - 1) * gap_y
    page = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(page)
    mask = squircle_mask(icon * 4).resize((icon, icon), Image.LANCZOS)
    items = list(refs)
    # spread candidates through the page (not all in a corner)
    slots = [5, 10, 2, 13, 7, 0]
    for i, c in enumerate(cands):
        items.insert(min(slots[i % len(slots)], len(items)), c)
    f = font(10)
    for i, (label, path) in enumerate(items):
        x = pad + (i % cols) * (icon + gap_x)
        y = pad + (i // cols) * (icon + 14 + gap_y)
        art = load_rgb(path).resize((icon, icon), Image.LANCZOS).convert("RGBA")
        art.putalpha(mask)
        page.paste(art, (x, y), art)
        tw = d.textlength(label[:11], font=f)
        d.text((x + (icon - tw) / 2, y + icon + 3), label[:11], fill=label_color, font=f)
    return page


def cmd_grid(out, cands, refs):
    """Crowded-grid mock: each candidate on a home-screen page among competitor icons, on a light
    and a dark wallpaper, plus a 2x "App Store search" strip at 64/40 px."""
    pages = []
    for label, path in cands:
        lt = _home_grid([(label, path)], refs, (214, 205, 190), label_color=(30, 30, 30))
        dk = _home_grid([(label, path)], refs, (20, 20, 26))
        pages.append((label, lt, dk))
    pw, ph = pages[0][1].size
    head = 30
    cols = 1 if len(pages) < 3 else (2 if len(pages) < 7 else 3)  # candidate columns (light + dark each)
    rows = (len(pages) + cols - 1) // cols
    cw = 2 * pw + 16 + 40
    W = cols * cw + 16
    H = rows * (ph + head + 16) + 16
    sheet = Image.new("RGB", (W, H), (245, 243, 238))
    d = ImageDraw.Draw(sheet)
    for i, (label, lt, dk) in enumerate(pages):
        x = 16 + (i % cols) * cw
        y = 16 + (i // cols) * (ph + head + 16)
        d.text((x, y + 4), label, fill=(20, 20, 20), font=font(20))
        sheet.paste(lt, (x, y + head))
        sheet.paste(dk, (x + 16 + pw, y + head))
    sheet.save(out)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    c = argv[1]
    if c == "ios":
        cmd_ios(argv[2], argv[3])
    elif c == "tinted":
        cmd_tinted(argv[2], argv[3])
    elif c == "macos":
        cmd_macos(argv[2], argv[3])
    elif c == "iconset":
        cmd_iconset(argv[2], argv[3])
    elif c == "sheet":
        cmd_sheet(argv[2], [a.split("=", 1) for a in argv[3:]])
    elif c == "grid":
        # grid <out.png> label=cand.png ... -- label=ref.png ...
        i = argv.index("--")
        cmd_grid(argv[2], [a.split("=", 1) for a in argv[3:i]], [a.split("=", 1) for a in argv[i + 1:]])
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
