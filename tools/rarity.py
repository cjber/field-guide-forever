"""Rarity mockups: the target frame and the nameplate at every collection tier.

The client's own classification art does the work, at atlas size and the anchors the client uses. A silver creature
draws the rare silver frame over its bronze frame, gold draws the elite gold portrait ring, and shiny draws the rare
frame plus the winged silver ring and runs the client's loot-toast sheen across both. A tier icon sits in the free
bottom-left corner, and the SILVER, GOLD or SHINY tag stays above the name. Nameplates carry the same quality icon to
the right of the health bar. The health bar fill and name text keep the client's own colours, and BRONZE is the
untouched client frame.

Rare, elite, boss and minus-mob units already get the client's own frame art, so our art is skipped for them while the
tier icon and tag still read the coat. Every pixel that is not the addon's own layout comes from the pinned
WoW: Forever build through wowmock, so what is approved here is what the addon paints.

    python3 tools/rarity.py
"""

import os
import sys
from pathlib import Path

from PIL import Image, ImageChops  # ty: ignore[unresolved-import]  # Pillow is local only
from ui_art import BUILD as ART_BUILD

ROOT = Path(__file__).resolve().parent.parent
FOREVER_CORE = Path(os.environ.get("FOREVER_CORE", ROOT.parent / "forever-core")).expanduser()
WOWMOCK = FOREVER_CORE / "tools" / "wowmock"
if not (WOWMOCK / "wowmock.py").is_file():
    raise SystemExit(f"wowmock.py not found in {WOWMOCK}; set FOREVER_CORE to the forever-core checkout")
sys.path.insert(0, str(WOWMOCK))
import wowmock  # noqa: E402  # ty: ignore[unresolved-import]
from wowmock import FONTS, Font, tint  # noqa: E402  # ty: ignore[unresolved-import]

OUT = ROOT / "docs" / "screenshots"

# UI/Rarity.lua's ladder. Bronze has no entry in COLORS because it is the client's own chrome and needs no change at
# all; the whole promise of the feature is that a bronze creature looks exactly as it always did.
TIERS = (
    ("BRONZE", "every spawn", None, "the client's frame, untouched"),
    ("SILVER", "1 in 25", wowmock.rgb("c9d2dc"), "silver rare frame, quality mark and SILVER tag"),
    ("GOLD", "1 in 100", wowmock.rgb("e8bd63"), "elite gold ring, quality mark and GOLD tag"),
    ("SHINY", "1 in 1000", wowmock.rgb("b9e6ff"), "silver frame, winged silver ring, sheen and SHINY tag"),
)
TARGET_FRAME_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn"
RARE_FRAME_ATLAS = "UI-HUD-UnitFrame-Target-Rare-PortraitOn"
GOLD_RING_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold"
WING_RING_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged"
SHEEN_ATLAS = "loottoast-sheen"
HEALTH_BAR_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
POWER_BAR_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana"
TAG_HEIGHT = 15
TAG_PAD = 4
# Art.TIER_ICONS for the tiers whose target frame and nameplate carry their quality mark, at Rarity.lua's size and
# resting alpha.
PLATE_MARKS = {
    "SILVER": "Professions-Icon-Quality-Tier2",
    "GOLD": "Professions-Icon-Quality-Tier3",
    "SHINY": "Professions-Icon-Quality-Tier4",
}
PLATE_MARK_SIZE = 17
PLATE_ACCENT_ALPHA = 0.72
# UI/Rarity.lua's target-frame mark, in the free bottom-left corner under the power bar.
TARGET_MARK_SIZE = 15
TARGET_MARK_TOP = 54.5

TEXT = wowmock.rgb("e3d9c2")
MUTED = wowmock.rgb("9e998c")
DIM = wowmock.rgb("7c786f")
BRASS = wowmock.rgb("b8a16b")
BG = wowmock.rgb("0d0f12")
TAG_TEXT = wowmock.rgb("0d0f12")

# The UI-HUD target frame's atlas is 192 by 67. These windows are the measured client regions inside it, in the same
# units TargetFrame.xml anchors its health, power and portrait to.
FRAME_W, FRAME_H = 192, 67
HEALTH_WINDOW = (2, 22, 128, 42)
POWER_WINDOW = (2, 44, 136, 54)
PORTRAIT_CENTER = (157, 36)
PORTRAIT_RADIUS = 29
LEVEL_CENTER = (188, 54)

# NumberFontNormalSmall is the client font object used by target-frame level text.
FONTS["NumberFontNormalSmall"] = Font(wowmock.ARIALN, 10, wowmock.WHITE, None, True)


def text(canvas, x, y, value, font, colour=TEXT, **kwargs):
    canvas.text(x, y, value, FONTS[font], colour, **kwargs)


def sheen_mask(canvas, pieces):
    """The union of the client art's alpha, so the sheen can only paint inside that art."""
    mask = Image.new("L", canvas.image.size, 0)
    for atlas, left, top, width, height in pieces:
        alpha = atlas.image.resize((canvas.px(width), canvas.px(height)), Image.LANCZOS).getchannel("A")
        layer = Image.new("L", mask.size, 0)
        layer.paste(alpha, (canvas.px(left), canvas.px(top)))
        mask = ImageChops.lighter(mask, layer)
    return mask


def sheen(canvas, ui, x, y, pieces):
    """Draw the loot-toast sheen still, clipped to the rare frame and winged ring it crosses."""
    atlas = ui.atlas(SHEEN_ATLAS)
    layer = Image.new("RGBA", canvas.image.size)
    piece = atlas.image.resize((canvas.px(atlas.width), canvas.px(atlas.height)), Image.LANCZOS)
    layer.paste(piece, (canvas.px(x + 90), canvas.px(y - 4)))
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), sheen_mask(canvas, pieces)))
    canvas.composite(layer, 0, 0, blend="ADD")


def target_frame(ui, canvas, x, y, tier, icon, name, level, native=False):
    """Compose the client target frame with its own classification art, the tier icon and the tag."""
    label, _, colour, _ = tier
    frame = ui.atlas(TARGET_FRAME_ATLAS)
    health_bar = ui.atlas(HEALTH_BAR_ATLAS)
    power_bar = ui.atlas(POWER_BAR_ATLAS)
    mask = ui.texture("interface/characterframe/tempportraitalphamask.blp")

    portrait_layer = ui.canvas(canvas.width, canvas.height)
    diameter = PORTRAIT_RADIUS * 2
    portrait_left = x + PORTRAIT_CENTER[0] - PORTRAIT_RADIUS
    portrait_top = y + PORTRAIT_CENTER[1] - PORTRAIT_RADIUS
    portrait_layer.draw(icon, portrait_left, portrait_top, diameter, diameter)
    portrait_layer.mask(mask, portrait_left, portrait_top, diameter, diameter)
    canvas.paste(portrait_layer, 0, 0)

    canvas.draw(frame, x, y, FRAME_W, FRAME_H)

    # Client art at atlas size and the client's own anchors. A rare, elite or boss unit keeps the art the client
    # already drew there instead.
    if not native:
        if label in ("SILVER", "SHINY"):
            canvas.draw(ui.atlas(RARE_FRAME_ATLAS), x, y, FRAME_W, FRAME_H)
        if label == "GOLD":
            ring = ui.atlas(GOLD_RING_ATLAS)
            canvas.draw(ring, x + 112, y - 17.5, ring.width, ring.height)
        if label == "SHINY":
            wing = ui.atlas(WING_RING_ATLAS)
            canvas.draw(wing, x + 111, y - 9.5, wing.width, wing.height)
            sheen(
                canvas,
                ui,
                x,
                y,
                (
                    (ui.atlas(RARE_FRAME_ATLAS), x, y, FRAME_W, FRAME_H),
                    (wing, x + 111, y - 9.5, wing.width, wing.height),
                ),
            )
    else:
        ring = ui.atlas(GOLD_RING_ATLAS)
        canvas.draw(ring, x + 112, y - 17.5, ring.width, ring.height)

    # The status bar art already carries the client's green and blue fills; crop it to the shown fraction.
    for atlas, bounds, fraction in (
        (health_bar, HEALTH_WINDOW, 0.86),
        (power_bar, POWER_WINDOW, 0.62),
    ):
        left, top, right, bottom = bounds
        width, height = canvas.px(right - left), canvas.px(bottom - top)
        full = atlas.image.resize((width, height), Image.LANCZOS)
        filled = max(1, round(width * fraction))
        canvas.composite(full.crop((0, 0, filled, height)), canvas.px(x + left), canvas.px(y + top))

    text(
        canvas,
        x + HEALTH_WINDOW[0],
        y + HEALTH_WINDOW[1],
        name,
        "GameFontNormalSmall",
        TEXT,
        justify="CENTER",
        width=HEALTH_WINDOW[2] - HEALTH_WINDOW[0],
        box_height=HEALTH_WINDOW[3] - HEALTH_WINDOW[1],
    )
    text(
        canvas,
        x + LEVEL_CENTER[0] - 15,
        y + LEVEL_CENTER[1] - 5,
        str(level),
        "NumberFontNormalSmall",
        wowmock.WHITE,
        justify="CENTER",
        width=30,
    )

    if colour:
        tag(canvas, x, y, label, colour)
        mark(
            canvas,
            ui,
            PLATE_MARKS[label],
            x + 4 + TARGET_MARK_SIZE / 2,
            y + TARGET_MARK_TOP + TARGET_MARK_SIZE / 2,
            TARGET_MARK_SIZE,
            wowmock.WHITE,
        )


def tag(canvas, x, y, label, colour):
    """The SILVER, GOLD or SHINY plate above the health bar: tier colour with dark text and a thin dark edge."""
    font = FONTS["GameFontNormalSmall"]
    width = canvas.text_width(label, font) + TAG_PAD * 2
    bar_width = HEALTH_WINDOW[2] - HEALTH_WINDOW[0]
    left = x + HEALTH_WINDOW[0] + (bar_width - width) / 2
    top = y - TAG_HEIGHT - 3
    canvas.fill(left - 1, top - 1, width + 2, TAG_HEIGHT + 2, TAG_TEXT)
    canvas.fill(left, top, width, TAG_HEIGHT, colour)
    canvas.text(left + TAG_PAD, top + 1, label, font, TAG_TEXT)


def mark(canvas, ui, name, x, y, height, colour):
    """Draw a native atlas mark at its own aspect, centred on (x, y), as SetAtlas and SetVertexColor do."""
    atlas = ui.atlas(name)
    width = height * atlas.width / atlas.height
    piece = atlas.image.resize((canvas.px(width), canvas.px(height)), Image.LANCZOS)
    piece = tint(piece, colour)
    canvas.composite(piece, canvas.px(x - width / 2), canvas.px(y - height / 2))


def nameplate(ui, canvas, x, y, tier, name):
    """One nameplate: the ladder's mark to the right of the bar, over the client's own reaction colours.
    Every tier keeps the client's red fill and white name; only bronze has no mark."""
    label, _, colour, _ = tier
    w, h = 116, 12
    fill_texture = ui.texture("interface/targetingframe/nameplatefill.blp")
    trough_colour = tuple(component * 0.18 for component in BRASS)
    canvas.draw(fill_texture, x, y, w, h, trough_colour)
    full = fill_texture.resize((canvas.px(w), canvas.px(h)), Image.LANCZOS)
    full = tint(full, wowmock.rgb("a3342c"))
    canvas.composite(full.crop((0, 0, canvas.px(w * 0.9), canvas.px(h))), canvas.px(x), canvas.px(y))
    text(
        canvas,
        x,
        y - 15,
        name,
        "GameFontNormalSmall",
        TEXT,
        justify="CENTER",
        width=w,
    )
    atlas_name = PLATE_MARKS.get(label)
    if atlas_name:
        # LEFT on the health bar's RIGHT, centred on its line.
        mark(
            canvas,
            ui,
            atlas_name,
            x + w + 2 + PLATE_MARK_SIZE / 2,
            y + h / 2,
            PLATE_MARK_SIZE,
            (1, 1, 1, PLATE_ACCENT_ALPHA),
        )


def sheet(ui, icons, name, native=False, plates=False):
    cols, rows = 2, 2
    cell_w, cell_h = 330, 220
    m = 34
    canvas = ui.canvas(cell_w * cols + m * 2, cell_h * rows + m * 2 + 64)
    canvas.fill(0, 0, canvas.width, canvas.height, BG)
    text(canvas, m, 18, "FIELD GUIDE  \u00b7  RARITY AT A GLANCE", "GameFontNormal", BRASS)
    subtitle = "The client's own classification art at its own size, with the tier icon and tag"
    if native:
        subtitle = "The client's own rare and elite frame art stays; the tier icon and tag still name the coat"
    text(canvas, m, 36, subtitle, "GameFontDisableSmall", MUTED)
    folk = ["Savannah Prowler", "Bristleback Boar", "Prairie Wolf", "Plainstrider"]
    glyph = ["prowler", "boar", "wolf", "strider"]
    for index, tier in enumerate(TIERS):
        col, row = index % cols, index // cols
        cx = m + col * cell_w
        cy = m + 64 + row * cell_h
        label, odds, colour, note = tier
        text(canvas, cx, cy, label, "GameFontNormal", colour or BRASS)
        odds_x = cx + canvas.text_width(label, FONTS["GameFontNormal"]) + 8
        text(canvas, odds_x, cy + 1, odds, "GameFontDisableSmall", DIM)
        text(canvas, cx, cy + 16, note, "GameFontDisableSmall", MUTED)
        target_frame(ui, canvas, cx + 14, cy + 52, tier, icons[glyph[index]], folk[index], 12 + index, native=native)
        if plates:
            nameplate(ui, canvas, cx + 74, cy + 196, tier, folk[index])
    return canvas


def main():
    ui = wowmock.Ui(build=ART_BUILD, scale=2)
    OUT.mkdir(parents=True, exist_ok=True)
    icons = {
        key: ui.texture(f"interface/icons/{value}.blp")
        for key, value in (
            ("prowler", "ability_hunter_pet_cat"),
            ("boar", "ability_hunter_pet_boar"),
            ("wolf", "ability_hunter_pet_wolf"),
            ("strider", "ability_hunter_pet_tallstrider"),
        )
    }
    sheet(ui, icons, "target frames").save(OUT / "rarity-target.png")
    sheet(ui, icons, "nameplates", plates=True).save(OUT / "rarity-nameplates.png")
    sheet(ui, icons, "elite frames", native=True, plates=True).save(OUT / "rarity-elite.png")
    print("wrote 3 rarity sheets")


if __name__ == "__main__":
    sys.exit(main())
