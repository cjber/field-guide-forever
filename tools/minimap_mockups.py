#!/usr/bin/env python3
"""Draw the README scenes for Field Guide's minimap button with the client's own art.

The layout follows forever-core's `docs/handoff/minimap-buttons/render.py`: the client's Minimap face and frame, then
Field Guide's button on the rim at the shared module's first default angle. The icon is the client's wolf, the art the
old painted micro-menu glyph was tinted from.

    FOREVER_CORE=/path/to/forever-core python3 tools/minimap_mockups.py

Writes `minimap-field-guide.png` and `minimap-options.png` in the working directory. `tools/mockups.py` copies them into
`docs/screenshots/`. Deterministic: a second run is byte-identical.
"""

import math
import os
import sys
from pathlib import Path

FOREVER_CORE = Path(os.environ.get("FOREVER_CORE", Path(__file__).resolve().parents[2] / "forever-core")).expanduser()
WOWMOCK = FOREVER_CORE / "tools" / "wowmock"
if not (WOWMOCK / "wowmock.py").is_file():
    raise SystemExit(f"wowmock.py not found in {WOWMOCK}; set FOREVER_CORE to the forever-core checkout")
sys.path.insert(0, str(WOWMOCK))
import wowmock as W  # noqa: E402  # ty: ignore[unresolved-import]
from ui_art import BUILD as ART_BUILD  # noqa: E402

BTN = 20
ICON = 13
MINIMAP = 198
RIM_OFFSET = 5
# Core/MinimapButton.lua's first default angle: bottom-left.
FIELD_GUIDE_ANGLE = 225
FIELD_GUIDE_ICON = "interface/icons/ability_hunter_pet_wolf.blp"

ui = W.Ui(build=ART_BUILD, scale=2)


def round_icon(canvas_ui, icon):
    """The icon as Core/MinimapButton.lua draws it: cropped to 0.08-0.92 and masked by CircleMaskScalable."""
    art = canvas_ui.texture(icon)
    width, height = art.size
    art = art.crop((round(width * 0.08), round(height * 0.08), round(width * 0.92), round(height * 0.92)))
    out = canvas_ui.canvas(ICON, ICON)
    out.draw(art, 0, 0, ICON, ICON)
    out.mask(canvas_ui.atlas("CircleMaskScalable").image, 0, 0, ICON, ICON)
    return out


def button(canvas, cx, cy, angle, icon, hover=False):
    """The client's minimap plate, the addon's icon and the native round hover glow."""
    radius = MINIMAP / 2 + RIM_OFFSET
    x = cx + math.cos(math.radians(angle)) * radius
    y = cy - math.sin(math.radians(angle)) * radius
    state = "UI-HUD-Minimap-Button-Down" if hover else "UI-HUD-Minimap-Button"
    canvas.draw(canvas.ui.atlas(state), x - BTN / 2, y - BTN / 2, BTN, BTN)
    canvas.paste(round_icon(canvas.ui, icon), x - ICON / 2, y - ICON / 2)
    if hover:
        canvas.draw(
            canvas.ui.atlas("bags-roundhighlight"),
            x - BTN / 2,
            y - BTN / 2,
            BTN,
            BTN,
            color=(1, 1, 1, 0.55),
            blend="ADD",
        )


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
