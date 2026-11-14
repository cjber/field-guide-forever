#!/usr/bin/env python3
"""Draw the README scenes for Field Guide's minimap button with the client's own art.

The layout follows forever-core's `docs/handoff/minimap-buttons/render.py`: the client's Minimap face and frame, then
Field Guide's LibDBIcon button on the rim at the shared module's first default angle. The icon is the client's book,
the addon's declared `## X-Forever-Icon`.

    FOREVER_CORE=/path/to/forever-core python3 tools/minimap_mockups.py

Writes `minimap-field-guide.png` and `minimap-options.png` in the working directory. `tools/mockups.py` copies them into
`docs/screenshots/`. Deterministic: a second run is byte-identical.
"""

import math
import os
import sys
from pathlib import Path

from PIL import Image, ImageChops

FOREVER_CORE = Path(os.environ.get("FOREVER_CORE", Path(__file__).resolve().parents[2] / "forever-core")).expanduser()
WOWMOCK = FOREVER_CORE / "tools" / "wowmock"
if not (WOWMOCK / "wowmock.py").is_file():
    raise SystemExit(f"wowmock.py not found in {WOWMOCK}; set FOREVER_CORE to the forever-core checkout")
sys.path.insert(0, str(WOWMOCK))
import wowmock as W  # noqa: E402  # ty: ignore[import-not-found]
from ui_art import BUILD as ART_BUILD  # noqa: E402

# LibDBIcon's construction, the art every LibDBIcon addon button on the rim uses.
BTN = 31
OVERLAY = 50
BACKGROUND = 24
ICON = 18
MINIMAP = 198
RIM_OFFSET = 5
HIGHLIGHT = 136477  # interface/minimap/ui-minimap-zoombutton-highlight.blp
TRACKING_BORDER = 136430  # interface/minimap/minimap-trackingborder.blp
MINIMAP_BACKGROUND = 136467  # interface/minimap/ui-minimap-background.blp
# Core/MinimapButton.lua's first default angle: bottom-left.
FIELD_GUIDE_ANGLE = 225
FIELD_GUIDE_ICON = "interface/icons/inv_misc_book_09.blp"

ui = W.Ui(build=ART_BUILD, scale=2)


def icon_art(canvas_ui, icon):
    """The icon as Core/MinimapButton.lua draws it: cropped to texcoords 0.05-0.95, unmasked."""
    art = canvas_ui.texture(icon)
    width, height = art.size
    art = art.crop((round(width * 0.05), round(height * 0.05), round(width * 0.95), round(height * 0.95)))
    out = canvas_ui.canvas(ICON, ICON)
    out.draw(art, 0, 0, ICON, ICON)
    return out


def add_glow(canvas, texture, left, top, size):
    """Additive like the client's highlight: the texture's black backing adds nothing and stays transparent."""
    box = (canvas.px(left), canvas.px(top), canvas.px(left + size), canvas.px(top + size))
    region = canvas.image.crop(box)
    piece = texture.resize((box[2] - box[0], box[3] - box[1]), Image.Resampling.LANCZOS)
    added = ImageChops.add(region.convert("RGB"), piece.convert("RGB"))
    alpha = ImageChops.lighter(region.getchannel("A"), piece.convert("L"))
    out = added.convert("RGBA")
    out.putalpha(alpha)
    canvas.image.paste(out, box[:2])


def button(canvas, cx, cy, angle, icon, hover=False):
    """LibDBIcon's pieces at its own sizes: background under the icon, tracking border over it, highlight on top."""
    radius = MINIMAP / 2 + RIM_OFFSET
    x = cx + math.cos(math.radians(angle)) * radius
    y = cy - math.sin(math.radians(angle)) * radius
    left, top = x - BTN / 2, y - BTN / 2
    canvas.draw(
        canvas.ui.texture(MINIMAP_BACKGROUND),
        x - BACKGROUND / 2,
        y - BACKGROUND / 2,
        BACKGROUND,
        BACKGROUND,
    )
    canvas.paste(icon_art(canvas.ui, icon), x - ICON / 2, y - ICON / 2)
    canvas.draw(canvas.ui.texture(TRACKING_BORDER), left, top, OVERLAY, OVERLAY)
    if hover:
        add_glow(canvas, canvas.ui.texture(HIGHLIGHT), left, top, BTN)


def minimap(canvas, cx, cy):
    """The client's Minimap at Auberdine: masked face, native frame, then Field Guide's button on the rim."""
    terrain = W.minimap_art(canvas.ui, 1, 6464.8, 662.9, 233 + 1 / 3)
    face = canvas.ui.canvas(MINIMAP, MINIMAP)
    face.image = terrain.resize(face.image.size)
    face.mask(canvas.ui.atlas("ui-hud-minimap-frame-generic-mask").image, 0, 0, MINIMAP, MINIMAP)
    canvas.paste(face, cx - MINIMAP / 2, cy - MINIMAP / 2)
    frame = canvas.ui.atlas("UI-HUD-Minimap-Frame")
    canvas.draw(frame, cx - frame.width / 2, cy - frame.height / 2)
    cycle = canvas.ui.atlas("UI-HUD-Minimap-Frame-Cycle")
    canvas.draw(cycle, cx + 63 - cycle.width / 2, cy - 72 - cycle.height / 2)
    button(canvas, cx, cy, FIELD_GUIDE_ANGLE, FIELD_GUIDE_ICON, hover=True)


def scene(path, tooltip_lines):
    width, height = 540, 340
    canvas = ui.canvas(width, height)
    minimap(canvas, 350, 175)
    if tooltip_lines:
        tip = W.tooltip(ui, tooltip_lines)
        canvas.paste(tip, 20, 120)
    base = W.backdrop(ui, width, height)
    base.paste(canvas, 0, 0)
    base.save(path)
    print("wrote", path, base.image.size)


def options(path):
    panel, px, py = W.basic_panel(ui, "Field Guide Forever options", 420, 180)
    x, y = px + 20, py + 34
    panel.text(x, y, "Minimap", W.FONTS["GameFontNormalLarge"], W.NORMAL)
    W.edit_mode_checkbox(panel, x, y + 28, "Minimap button", checked=True)
    panel.text(
        x,
        y + 78,
        "The Field Guide button can also be bound in Key Bindings > AddOns.",
        W.FONTS["GameFontDisableSmall"],
    )
    base = W.backdrop(ui, panel.width, panel.height)
    base.paste(panel, 0, 0)
    base.save(path)
    print("wrote", path, base.image.size)


scene(
    "minimap-field-guide.png",
    [
        W.TooltipLine("Field Guide"),
        W.TooltipLine("(Shift-F)", W.NORMAL),
        W.TooltipLine("Click to browse the field compendium", W.rgb("808080")),
    ],
)
options("minimap-options.png")
