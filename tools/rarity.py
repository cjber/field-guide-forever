"""Rarity mockups: the target frame and the nameplate at every collection tier.

Design C: the client frame keeps its own chrome and the game's own reaction colours. A silver, gold or shiny creature
adds a soft tier-coloured aura around the bars and portrait, plus a SILVER, GOLD or SHINY tag above the target name;
nameplates take a soft tier glow and the existing mark. The health bar fill and name text are never recoloured.
BRONZE is the untouched client frame.

Every pixel that is not the addon's own layout comes from the pinned WoW: Forever build through
wowmock, so what is approved here is what the addon paints.

    python3 tools/rarity.py
"""

import os
import sys
from pathlib import Path

from PIL import Image  # ty: ignore[unresolved-import]  # Pillow is local only
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
    ("SILVER", "1 in 25", wowmock.rgb("c9d2dc"), "silver aura, quality mark and SILVER tag"),
    ("GOLD", "1 in 100", wowmock.rgb("e8bd63"), "gold aura, quality mark and GOLD tag"),
    ("SHINY", "1 in 1000", wowmock.rgb("b9e6ff"), "shiny aura, quality mark and SHINY tag"),
)
BAR_GLOW_LEFT = "UI-Frame-Bar-GlowLeft"
BAR_GLOW_CENTER = "UI-Frame-Bar-GlowCenter"
BAR_GLOW_RIGHT = "UI-Frame-Bar-GlowRight"
BAR_GLOW_LEFT_WIDTH = 35
BAR_GLOW_RIGHT_WIDTH = 34
TARGET_GLOW_LAYERS = ((9, 0.12), (5, 0.28), (2, 0.9))
PLATE_GLOW_LAYERS = ((9, 0.22), (4, 0.55), (1, 1.0))
TARGET_RING = "Portrait-Frame-Small"
TARGET_PORTRAIT_GLOW_LAYERS = ((96, 0.12), (88, 0.28), (80, 0.6), (74, 1.0))
TAG_HEIGHT = 15
TAG_PAD = 4
# Art.TIER_ICONS for the tiers whose nameplate carries its quality mark beside the name, at Rarity.lua's size and
# resting alpha.
PLATE_MARKS = {
    "SILVER": "Professions-Icon-Quality-Tier2",
    "GOLD": "Professions-Icon-Quality-Tier3",
    "SHINY": "Professions-Icon-Quality-Tier4",
}
PLATE_MARK_SIZE = 17
PLATE_ACCENT_ALPHA = 0.72

TEXT = wowmock.rgb("e3d9c2")
MUTED = wowmock.rgb("9e998c")
DIM = wowmock.rgb("7c786f")
BRASS = wowmock.rgb("b8a16b")
BG = wowmock.rgb("0d0f12")
TAG_TEXT = wowmock.rgb("0d0f12")

FRAME_W, FRAME_H = 256, 128
HEALTH_WINDOW = (32, 26, 143, 49)
POWER_WINDOW = (33, 55, 143, 61)
PORTRAIT_CENTER = (183, 44)
PORTRAIT_RADIUS = 28
LEVEL_CENTER = (201, 66)

# NumberFontNormalSmall is the client font object used by target-frame level text.
FONTS["NumberFontNormalSmall"] = Font(wowmock.ARIALN, 10, wowmock.WHITE, None, True)


def text(canvas, x, y, value, font, colour=TEXT, **kwargs):
    canvas.text(x, y, value, FONTS[font], colour, **kwargs)


def recolour(piece, colour):
    """SetDesaturated then SetVertexColor: luminance only, multiplied by the tier colour."""
    if colour is None:
        return piece
    grey = piece.convert("L").convert("RGBA")
    grey.putalpha(piece.getchannel("A"))
    return tint(grey, colour)


def art(canvas, texture, x, y):
    """Draw the complete client texture at native logical size, leaving the client's chrome untouched."""
    piece = texture.resize((canvas.px(FRAME_W), canvas.px(FRAME_H)), Image.LANCZOS)
    canvas.composite(piece, canvas.px(x), canvas.px(y))


def mark(canvas, ui, name, x, y, height, colour):
    """Draw a native atlas mark at its own aspect, centred on (x, y), as SetAtlas and SetVertexColor do."""
    atlas = ui.atlas(name)
    width = height * atlas.width / atlas.height
    piece = atlas.image.resize((canvas.px(width), canvas.px(height)), Image.LANCZOS)
    piece = tint(piece, colour)
    canvas.composite(piece, canvas.px(x - width / 2), canvas.px(y - height / 2), "ADD")
    return width


def glow_piece(canvas, ui, name, x, y, width, height, colour, alpha):
    """One native glow piece, desaturated and multiplied by the tier colour, as UI/Rarity.lua paints it."""
    atlas = ui.atlas(name)
    piece = atlas.image.resize((canvas.px(width), canvas.px(height)), Image.LANCZOS)
    piece = recolour(piece, colour)
    piece.putalpha(piece.getchannel("A").point(lambda value: round(value * alpha)))
    canvas.composite(piece, canvas.px(x), canvas.px(y), "ADD")


def bar_glow(canvas, ui, bounds, colour, layers):
    """The client's three-piece bar glow, repeated at increasing padding to make a soft tier aura around the bars."""
    source_left, source_top, source_right, source_bottom = bounds
    for pad, alpha in layers:
        left = source_left - pad
        top = source_top - pad
        right = source_right + pad
        bottom = source_bottom + pad
        height = bottom - top
        glow_piece(canvas, ui, BAR_GLOW_LEFT, left, top, BAR_GLOW_LEFT_WIDTH, height, colour, alpha)
        glow_piece(
            canvas,
            ui,
            BAR_GLOW_RIGHT,
            right - BAR_GLOW_RIGHT_WIDTH,
            top,
            BAR_GLOW_RIGHT_WIDTH,
            height,
            colour,
            alpha,
        )
        glow_piece(
            canvas,
            ui,
            BAR_GLOW_CENTER,
            left + BAR_GLOW_LEFT_WIDTH,
            top,
            right - left - BAR_GLOW_LEFT_WIDTH - BAR_GLOW_RIGHT_WIDTH,
            height,
            colour,
            alpha,
        )


def portrait_glow(canvas, ui, x, y, colour):
    """The client's portrait-frame ring, repeated at increasing size to make a soft tier aura around the portrait."""
    centre_x = x + PORTRAIT_CENTER[0]
    centre_y = y + PORTRAIT_CENTER[1]
    for size, alpha in TARGET_PORTRAIT_GLOW_LAYERS:
        glow_piece(
            canvas,
            ui,
            TARGET_RING,
            centre_x - size / 2,
            centre_y - size / 2,
            size,
            size,
            colour,
            alpha,
        )


def tag(canvas, x, y, label, colour):
    """The SILVER, GOLD or SHINY plate above the name: tier colour with dark text and a thin dark edge."""
    font = FONTS["GameFontNormalSmall"]
    width = canvas.text_width(label, font) + TAG_PAD * 2
    left = x + 32 + 111 / 2 - width / 2
    top = y - 10
    canvas.fill(left - 1, top - 1, width + 2, TAG_HEIGHT + 2, TAG_TEXT)
    canvas.fill(left, top, width, TAG_HEIGHT, colour)
    canvas.text(left + TAG_PAD, top + 1, label, font, TAG_TEXT)


def status_bar(canvas, texture, bounds, fraction, colour):
    """Crop the client's StatusBar texture to the visible fill fraction."""
    left, top, right, bottom = bounds
    fraction = max(0, min(1, fraction))
    width = canvas.px(right - left)
    height = canvas.px(bottom - top)
    source_width = max(1, round(texture.width * fraction))
    fill = texture.crop((0, 0, source_width, texture.height)).resize(
        (max(1, round(width * fraction)), height), Image.LANCZOS
    )
    canvas.composite(tint(fill, colour), canvas.px(left), canvas.px(top))


def target_frame(ui, canvas, x, y, tier, icon, name, level, elite=False):
    """Compose the measured client target frame with design C's aura, tier tag and the client's health colours."""
    label, _, colour, _ = tier
    stem = "targetframeelite" if elite else "targetframe"
    frame = ui.texture(f"interface/targetingframe/{stem}.blp")
    bar_texture = ui.atlas("UI-HUD-CoolDownManager-Bar").image
    mask = ui.texture("interface/characterframe/tempportraitalphamask.blp")

    health_bounds = tuple(v + (x if i % 2 == 0 else y) for i, v in enumerate(HEALTH_WINDOW))
    power_bounds = tuple(v + (x if i % 2 == 0 else y) for i, v in enumerate(POWER_WINDOW))

    portrait_layer = ui.canvas(canvas.width, canvas.height)
    diameter = PORTRAIT_RADIUS * 2
    portrait_left, portrait_top = x + PORTRAIT_CENTER[0] - PORTRAIT_RADIUS, y + PORTRAIT_CENTER[1] - PORTRAIT_RADIUS
    portrait_layer.draw(icon, portrait_left, portrait_top, diameter, diameter)
    portrait_layer.mask(mask, portrait_left, portrait_top, diameter, diameter)
    canvas.paste(portrait_layer, 0, 0)

    # One native frame pass keeps the portrait rim, bar borders, and elite crest on the source coordinates.
    art(canvas, frame, x, y)
    if colour:
        bar_glow(
            canvas,
            ui,
            (x + 32, y + HEALTH_WINDOW[1], x + 143, y + POWER_WINDOW[3]),
            colour,
            TARGET_GLOW_LAYERS,
        )
    status_bar(canvas, bar_texture, health_bounds, 0.86, wowmock.rgb("3f7a34"))
    status_bar(canvas, bar_texture, power_bounds, 0.62, wowmock.rgb("2f5a9e"))
    if colour:
        portrait_glow(canvas, ui, x, y, colour)
        tag(canvas, x, y, label, colour)
    text(canvas, x + 32, y + 8, name, "GameFontNormalSmall", TEXT, justify="CENTER", width=111)
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


def nameplate(ui, canvas, x, y, tier, name):
    """One nameplate: a soft tier aura and the ladder's mark, over the client's own reaction colours.
    Every tier keeps the client's red fill and white name; only bronze has no aura or mark."""
    label, _, colour, _ = tier
    w, h = 116, 12
    fill_texture = ui.texture("interface/targetingframe/nameplatefill.blp")
    if colour:
        bar_glow(canvas, ui, (x, y, x + w, y + h), colour, PLATE_GLOW_LAYERS)
    trough_colour = tuple(component * 0.18 for component in BRASS)
    canvas.draw(fill_texture, x, y, w, h, trough_colour)
    status_bar(canvas, fill_texture, (x, y, x + w, y + h), 0.9, wowmock.rgb("a3342c"))
    font = FONTS["GameFontNormalSmall"]
    label_width = canvas.text_width(name, font)
    atlas_name = PLATE_MARKS.get(label)
    mark_width = PLATE_MARK_SIZE if atlas_name else 0
    gap = 2 if mark_width else 0
    group_left = x + (w - label_width - gap - mark_width) / 2
    text(canvas, group_left, y - 15, name, "GameFontNormalSmall", TEXT)
    if atlas_name:
        # LEFT on the name's RIGHT, centred on its line.
        canvas.draw(
            ui.atlas(atlas_name),
            group_left + label_width + gap,
            y - 15 + (font.height - PLATE_MARK_SIZE) / 2,
            PLATE_MARK_SIZE,
            PLATE_MARK_SIZE,
            (1, 1, 1, PLATE_ACCENT_ALPHA),
        )


def sheet(ui, icons, name, elite=False, plates=False):
    cols, rows = 2, 2
    cell_w, cell_h = 330, 220
    m = 34
    canvas = ui.canvas(cell_w * cols + m * 2, cell_h * rows + m * 2 + 64)
    canvas.fill(0, 0, canvas.width, canvas.height, BG)
    text(canvas, m, 18, "FIELD GUIDE  \u00b7  RARITY AT A GLANCE", "GameFontNormal", BRASS)
    subtitle = "Normal frame with a tier aura and a SILVER, GOLD or SHINY tag; the game keeps its health colours"
    if elite:
        subtitle = "Elite frame keeps its client dragon chrome; the rarity adds the aura and tag"
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
        target_frame(ui, canvas, cx + 14, cy + 52, tier, icons[glyph[index]], folk[index], 12 + index, elite=elite)
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
    sheet(ui, icons, "elite frames", elite=True, plates=True).save(OUT / "rarity-elite.png")
    print("wrote 3 rarity sheets")


if __name__ == "__main__":
    sys.exit(main())
