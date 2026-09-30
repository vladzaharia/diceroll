# SVG UI pipeline (RhosGFX reskin foundation)

Status: foundation work package `wp-ui-foundation`, 2026-09-30. This doc covers the machinery.
Which pack pieces and icons the game uses, and their exact margins, is the designer's
component map in `docs/design/2026-09-30-ui-reskin.md`.

## Overview

```
third_party/rhosgfx/…            (git-ignored; paid packs, encrypted copies in the private repo)
        │  tools/import_assets.sh → tools/import_ui_svgs.py
        │  copies only the SVGs the manifests reference, sanitised names, `keep` .import sidecars
        ▼
assets/ui/icons/<pack>/…svg      ← ui/icons/icon_map.json (+ icon_map.demo.json)
assets/ui/pack/<pack>/…svg       ← ui/theme/ui_pack.json
        │  UiSvg (ui/theme/ui_svg.gd): read, tint, compose → DPITexture
        ▼
Icons (ui/icons/icon_registry.gd)    UiSkin (ui/theme/ui_skin.gd)
Icons.texture / rect / tex           UiSkin.stylebox / texture / apply_*
        │  fallback when unmapped / missing
        ▼
UiIcons (drawn glyphs)               UiTheme StyleBoxFlat look
```

Everything degrades: an unmapped id, a missing file, or a checkout without the paid packs
renders the current look. Nothing returns null where the old API didn't, and nothing crashes.

## Manifests

Every `svg` path is relative to `third_party/`, for example
`rhosgfx/vector-icon-pack-pro/Currency/Coin/Coin.svg`. The runtime copy lives at
`res://assets/ui/<icons|pack>/` plus `UiSvg.sanitize(path)`. The sanitising rule:

- Drop a leading `rhosgfx/`.
- Lowercase everything.
- In each path segment, turn every run of characters outside `[a-z0-9-]` into `_`. Keep the extension, and trim `_` from both ends.

For example, `Buttons/3D/Square/3. Yellow/button-square-3d-2.5-yellow-regular_hover.svg` becomes
`buttons/3d/square/3_yellow/button-square-3d-2_5-yellow-regular_hover.svg`.
Don't hand-edit anything under `assets/ui/`. It is regenerated, and stale files are deleted.

### `ui/icons/icon_map.json` (designer-owned)

```json
{"version": 1,
 "icons": {
   "coin":  {"svg": "rhosgfx/vector-icon-pack-pro/Currency/Coin/Coin Outline.svg", "tint": null, "note": "HUD gold"},
   "pause": {"svg": "rhosgfx/vector-icon-pack-pro/UI/Pause/Pause Flat White.svg", "tint": "palette:GOLD"},
   "rune_frost": {"svg": "…/Crystal Flat White.svg", "tint": "palette:auto"}
 },
 "input_glyphs": {
   "key_space": {"svg": "rhosgfx/vector-keyboard-controls/Keyboard Keys/Outline/SVG/space_md.svg", "strip_text": true}
 }}
```

- Ids are the game's existing icon ids, the ones `UiIcons` and the call sites already use.
- `input_glyphs` ids share the same id space. If an id appears in both sections, the `icons` entry wins.
- `tint` takes one of these values:
  - `null` keeps the SVG's own colours. Use it for full-colour art. Caller tints are ignored, because legacy call sites pass glyph colours.
  - `"#rrggbb"` or `"palette:NAME"` sets a default multiply tint that is baked into the vector. Use it with the "Flat White" variants. An explicit caller tint overrides it.
  - `"palette:auto"` uses the legacy per-id colour from `UiIcons.default_color`, such as rune, class, biome or intent colours.
- `palette:` names are `UiPalette` constants and are case-insensitive. `palette:RARITY.rare` indexes a dictionary constant.
- More optional entry keys:
  - `saturation` (0..1): the entry's default saturation.
  - `badge: {svg, corner, scale}`: a second icon composited into a corner, cached.
  - `compact_svg`: art used at 22 px or smaller.
- Documentation keys (`schema`, `missing`, `group`, `label`, …) are ignored.
- The import copies every `svg` / `*_svg` value, and badges.
- It warns when a path only matches on a case-insensitive disk. Two lead-map paths do: `General/Eye/Eye Blue Outline.svg` and `Nature/Pumpkin/Pumpkin Outline.svg`. The files on disk differ in case, and Linux imports would miss them.
- `strip_text: true` removes `<text>` elements, both at import and at runtime. Godot's SVG rasteriser (ThorVG) never draws `<text>`, so most `vector-keyboard-controls` keycaps render blank. Strip the text and put a `Label` on top.

### `ui/theme/ui_pack.json`

```json
{"version": 1, "pieces": {
  "button_primary": {
    "note": "…", "fallback": "button",
    "slice": [9, 9, 9, 19], "scale": 1.25, "content": [24, 12, 24, 26],
    "states": {
      "normal":   {"svg": "rhosgfx/cartoony-ui-pack-full/Buttons/3D/Square/3. Yellow/button-square-3d-2.5-yellow-regular_standard.svg"},
      "hover":    {"svg": "…_hover.svg"},
      "pressed":  {"svg": "…_pressed.svg", "slice": [9, 15, 9, 13], "content": [24, 20, 24, 18]},
      "disabled": {"svg": "…_standard.svg", "saturation": 0.15, "modulate": "#b8b8c8"},
      "focus":    {"svg": "…_focus.svg"}}},
  "panel_main": {"fallback": "panel:main", "content": [34, 30, 34, 38],
    "states": {"normal": {"layers": [
      {"svg": "…/Containers/3D/0. White/container-3d-white.svg", "slice": [15, 15, 15, 25], "tint": "palette:NAVY_2"},
      {"svg": "…/Frames/Thin/3. Yellow/frame-thin-yellow.svg", "slice": [22, 22, 22, 22]}]}}},
  "toggle": {"scale": 2.0, "states": {
    "checked": {"layers": [{"svg": "…/toggle-container-round-green.svg", "offset": [0, 2]},
                           {"svg": "…/Widgets/Handles/handle-round.svg", "offset": [20, 0]}]}}}
}}
```

| key | where | meaning |
|---|---|---|
| `svg` | piece / state / layer | source file, relative to `third_party/` |
| `slice` | any | 9-slice margins `[l, t, r, b]` in **SVG units** (viewBox px of the source art) |
| `scale` | any | logical canvas px per SVG unit (default 1). The texture is viewBox × scale |
| `content` | piece / state | content margins in logical px (default slice × scale of the first layer) |
| `expand` | any | expand margins in logical px. A negative value is an inset, for example a bar fill inside its container rim |
| `tint` | any | multiply baked into the vector (crisp). Use the pack's `0. White` variants |
| `modulate` | any | `StyleBoxTexture.modulate_color`. Can carry alpha |
| `saturation` | any | below 1 desaturates (disabled states) |
| `axis` | any | `stretch` / `tile` / `tile_fit`, or `[h, v]` |
| `draw_center` | any | as on StyleBoxTexture |
| `layers` | state | bottom-first list of layer dicts. Each inherits the state's keys |
| `offset` | layer | `[x, y]` in SVG units. Used when `UiSkin.texture()` composes the layers into one image |
| `rotate` | any | 0 / 90 / 180 / 270, clockwise (horizontal bar art as a vertical track). Slice and scale refer to the rotated art |
| `runtime_tint` | layer | `false` makes per-use `opts` tints skip this layer (a gold frame over a tinted container) |
| `fallback` | piece | look when the art is missing: `button` (UiTheme's Button boxes per state), `panel:<kind>` (`UiTheme.panel_box`), `theme:<Type>` (UiTheme theme's box of that state), `empty` |

- Keys on the piece are defaults for every state, and a state overrides them.
- A state that isn't listed falls back to `normal`.
- State names are free-form. The helpers use the Godot names: `normal`, `hover`, `pressed`, `disabled`, `focus`, `hover_pressed` for buttons, `background` / `fill` for bars, `track` / `fill` / `grabber` for sliders, and `checked` / `unchecked` for toggles.

**Slice rules measured from the art.** The planners measured these in the a-theme-controls plan:
- 3D square buttons, 2.5:1 art: 9/9/9/19. Pressed is 9/15/9/13, which gives a 6-unit sink.
- Container 3D: 15/15/15/25.
- Nailed frame: 24/27/24/34.
- Thin frame: 22 on every side.
- Pills, toggles and thin bars: leave at least a 1-unit stretch band (e.g. 8/7/8/8 on a 16-unit-tall pill). A zero-size band has nothing left to stretch.
- Pack quirk: `Bars/Wide/1. Grey/progress-containerwide-grey-darker.svg` is missing a dash. Copy paths from the file system.
- The pressed 3D buttons contain a full-size white rect inside an `opacity: 0` group. ThorVG respects it, and the rect does not render (verified).

## APIs

### Icons (`ui/icons/icon_registry.gd`, drop-in superset of `UiIcons`)

```gdscript
Icons.texture("coin", 40)              # Texture2D, logical 40 px; DPITexture → crisp at any scale
Icons.rect("heart", 48)                # TextureRect (replaces UiIcons.rect)
Icons.rect("skull", 32, UiPalette.HP)  # caller tint (applies when the map gives the id a tint)
Icons.tex("rune_frost", 64)            # fixed 64 px raster (replaces UiIcons.tex: shader uniforms,
                                       # custom _draw code that scales the texture itself)
Icons.rect("chest", 48, {"saturation": 0.0})   # locked / greyed (opts: tint, saturation)
Icons.texture("3d:coins", 40)          # the map may override "3d:" ids, else RenderedIcons
Icons.is_mapped("coin")                # RhosGFX art present for this id?
Icons.exists / class_icon / biome_icon / mechanic_icon / rune_icon / intent_icon / default_color
```

To migrate a call site, rename `UiIcons.` to `Icons.`. Unmapped ids render the current glyph:
through the same DPITexture path in `texture()` and `rect()`, and byte-identical to `UiIcons.tex`
in `tex()`. `"3d:"` ids still go to RenderedIcons.

### UiSkin (`ui/theme/ui_skin.gd`)

```gdscript
UiSkin.apply_button(btn, "button_primary")     # normal/hover/pressed/disabled/focus/hover_pressed
UiSkin.apply_panel(panel_container, "panel_main")
UiSkin.apply_progress(progress_bar, "bar_hp")  # background + fill
UiSkin.apply_slider(h_slider, "slider")        # track / fill / grabber icon
UiSkin.apply_toggle(check_button, "toggle")    # checked / unchecked icons (layers composed)
UiSkin.set_theme_type(theme, "Button", "button_secondary")
var sb := UiSkin.stylebox("button_primary", "pressed")   # fresh copy, safe to edit
UiSkin.stylebox("plaque", "normal", {"tint": UiPalette.class_color("mage")})   # per-use tint
UiSkin.stylebox("chip", "normal", {"saturation": 0.0, "fallback": UiTheme.panel_box("card")})
draw_style_box(UiSkin.stylebox("panel_card"), rect)       # custom-drawn widgets (GameButton…)
UiSkin.texture("toggle", "checked", 64)        # a piece as a plain texture
UiSkin.has("button_primary")                   # art present?
```

- `UiTheme.panel_box()` is unchanged and still returns `StyleBoxFlat`. Some callers mutate it: `camp_ui.gd`, `hud_top.gd`.
- To migrate a caller, move it to `UiSkin.stylebox("panel_…")` and let the manifest's `fallback: "panel:<kind>"` supply the flat look.
- Layered states build a `UiLayeredStyleBox` (`ui/theme/ui_layered_stylebox.gd`), a scripted StyleBox that draws its layers in order.

### UiSvg (`ui/theme/ui_svg.gd`)

This is the shared plumbing: path rule, cached sources, `svg_size`, `color("palette:…")`, `recolor(svg, tint, saturation)`, `strip_text`, `compose(parts)`, `make_texture(svg, scale)` and `raster(svg, px)`.

`recolor` rewrites the hex colours in both attributes and `<style>` CSS. `DPITexture.color_map`
only reaches attributes, and the RhosGFX files use CSS classes.

## SVG in Godot 4.7.2: the decision

**Decision: runtime `DPITexture`, from raw SVGs shipped with a `keep` importer.**

`DPITexture` is new in Godot 4.5. It keeps the SVG source and re-rasterises it for each viewport
oversampling level. On this project's `canvas_items` / `expand` canvas, oversampling is the
stretch scale × `--ui-scale` × display density. The measured levels:

| device | oversampling |
|---|---|
| iPhone @1x | 0.56 |
| 1366x768 | 0.60 |
| 1080p desktop | 0.84 |
| iPhone @2x | 1.12 |
| 1080p at 150% | 1.27 |

So one texture is always rasterised at the pixel size it is shown at.

Alternatives considered:
- **SVG import scale (CompressedTexture2D), high-res + mipmaps.**
  - It needs an import preset for each target size.
  - Downscaled through mipmaps it goes soft. Scaled up it blurs.
  - It can't be recoloured at runtime.
  - Its VRAM is about the same as DPITexture's (below).
- **Runtime `Image.load_svg_from_string` at a fixed size (today's `UiIcons.tex`).**
  - At 1x it aliases below oversampling 1: jaggy crowns and coins on an iPhone @1x.
  - At 2x + mipmaps it is soft, and uses about 2x the VRAM.
  - It stays in the API as `Icons.tex()` / `UiSvg.raster()` for shader uniforms and 3D, where DPITexture is not meant to be used. Use it for badges in 3D.

**Measurements.** `ui_skin_bench`, 300 icons from the designer's `icon_map.json`, drawn at
48 px, Metal, M-series Mac, two resolutions:

| approach | create (CPU) | first draw | VRAM (300) | RAM (300) |
|---|---|---|---|---|
| **DPITexture** (chosen) | 25 ms | 52 ms (rasterises at draw, once per oversampling level) | ~20 MB | ~7 MB (keeps SVG sources) |
| runtime raster 2x + mipmaps | 60 ms | 6–9 ms | ~57 MB | ~3.7 MB |
| imported CompressedTexture2D (svg/scale 1, mipmaps) | 88 ms to load (+ ~4 s one-off editor import) | 6–9 ms | ~21 MB | ~4 MB |

Notes on the measurements:
- VRAM is what freeing the textures returned, minus a 13.7 MB noise floor measured with n=0. It is driver-reported, so compare the rows with each other, not with theory.
- The numbers are the same at 1920x1080 and 804x1748.
- The totals are well under 0.1 s for a whole screen of icons, and each icon rasterises once per oversampling level, when it is first drawn.
- A window resize or zoom change re-rasterises the visible icons. That is one hitch of about 0.2 ms per icon.

**9-slice.** `StyleBoxTexture` with a DPITexture is seamless at every oversampling in the matrix.
We checked crops at 1366x768 and at 1366 with 125% zoom. Corners stay crisp.
`UiLayeredStyleBox` stacks several such boxes: container + frame.

**ThorVG quirks found:**
- `<text>` is dropped. Use `strip_text` and put a `Label` on top.
- Only the first `<style>` element is honoured. `UiSvg.compose` hoists all CSS into one.
- `opacity: 0` groups are respected.
- CSS classes work, but `DPITexture.color_map` does not reach them. That is why tinting rewrites the colours in the text (`UiSvg.recolor`).

**Rules for engineers:**
- In 2D UI, use `Icons.texture()` / `rect()` / `UiSkin.*`. They always give DPITexture.
- For shader uniforms, 3D (Label3D, badge.gdshader) and code that samples a texture at a size it chooses, use `Icons.tex()`, a fixed raster with mipmaps.
- Don't scale Controls to size art: a node's `scale` is not part of oversampling. Size the texture with `size_px` / `scale` instead.

## No-spillover audit (acceptance gate)

`UiAudit` (`ui/theme/ui_audit.gd`) runs after every shot with `--audit`. It prints one line per finding:

- `AUDIT_OVERFLOW <px> <node> > <frame>`: a Control pokes out of its nearest frame. A frame is:
  - a PanelContainer / Panel with a visible box,
  - a UiModal's `panel`, for everything in that modal,
  - or any Control with meta `contain = true`.
- `AUDIT_SAFE <px> <node>`: content (text, buttons, icons, ranges) outside the device safe area, or off-screen.
- `AUDIT_CLIP <px> "<text>" <node>`: a Label wider than its rect with no autowrap and no ellipsis, or a RichTextLabel taller than its rect.

Scrolled-out content is ignored, because ScrollContainer and `clip_contents` bound the check.

Opt-outs:
- Meta `allow_overflow = true` exempts a node and its subtree from the *frame* check only. The modal ribbon has it, and so should the round close button. The safe-area and clip checks still apply.
- Meta `audit_skip = true` skips a subtree entirely (drag previews).

To run it on your scenario across the matrix (no `AUDIT_*` lines under a device = pass):

```sh
tools/shoot_matrix.sh <scenario> /tmp/shots/x all --audit
```

`ui_skin_demo` passes on every device in the quick, mobile, dpi and zoom sets.
`tests/test_ui_skin.gd` covers the rules.

## CI asset units

`tools/ci/assets.py` UNIT_ROOTS has one unit per source pack under each root:
- `ui-icons-<pack>` from `assets/ui/icons/<pack>`
- `ui-pack-<pack>` from `assets/ui/pack/<pack>`

Changing either manifest changes the unit hashes. After a manifest change, run
`tools/import_assets.sh`, then `python3 tools/ci/assets.py pack` and `upload`, then commit the lock
file (docs/ASSETS.md).
