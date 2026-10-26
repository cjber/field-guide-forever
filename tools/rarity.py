"""Rarity recolour mockups: the target frame and the nameplate at every collection tier.

The tier mark is not an addon-drawn border. Each tier drops the chroma out of the client's own brass hardware and
multiplies the tier colour back in, which is exactly what UI/Rarity.lua does at runtime with `SetDesaturated(true)`
and `SetVertexColor`. So these sheets are the recolour itself: COMMON is the untouched client frame, and silver, gold
and shiny are the same textures with the brass removed and the tier colour laid into the shading.

Every pixel that is not the addon's own layout comes from the pinned WoW: Forever build (1.60.1.70124) through
wowmock, so what is approved here is what the addon paints.

    python3 tools/rarity.py
"""

import os
import sys
from pathlib import Path

from PIL import Image  # ty: ignore[unresolved-import]  # Pillow is local only

ROOT = Path(__file__).resolve().parent.parent
FOREVER_CORE = Path(os.environ.get("FOREVER_CORE", ROOT.parent / "forever-core")).expanduser()
WOWMOCK = FOREVER_CORE / "tools" / "wowmock"
if not (WOWMOCK / "wowmock.py").is_file():
    raise SystemExit(f"wowmock.py not found in {WOWMOCK}; set FOREVER_CORE to the forever-core checkout")
sys.path.insert(0, str(WOWMOCK))
import wowmock  # noqa: E402
from wowmock import FONTS, Font, tint  # noqa: E402

OUT = ROOT / "docs" / "screenshots"

# UI/Rarity.lua's COLORS table, verbatim. Copper has no entry because copper is the client's own brass and needs no
# recolour at all; the whole promise of the feature is that a common creature looks exactly as it always did.
TIERS = (
    ("COMMON", "1 in 1", None, "the client's brass, untouched"),
    ("SILVER", "1 in 25", wowmock.rgb("c9d2dc"), "brass dropped out and silvered"),
    ("GOLD", "1 in 100", wowmock.rgb("e8bd63"), "brass dropped out and gilded"),
    ("SHINY", "1 in 1000", wowmock.rgb("b9e6ff"), "brass dropped out and shot through with cyan"),
)

TEXT = wowmock.rgb("e3d9c2")
MUTED = wowmock.rgb("9e998c")
DIM = wowmock.rgb("7c786f")
BRASS = wowmock.rgb("b8a16b")
BG = wowmock.rgb("0d0f12")

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


def art(canvas, texture, x, y, colour=None):
    """Draw the complete client texture at native logical size and apply the runtime vertex colour."""
    piece = texture.resize((canvas.px(FRAME_W), canvas.px(FRAME_H)), Image.LANCZOS)
    canvas.composite(recolour(piece, colour), canvas.px(x), canvas.px(y))


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
    """Compose the measured client target frame, including its texture-backed troughs and circular portrait."""
    _, _, colour, _ = tier
    stem = "targetframeelite" if elite else "targetframe"
    frame = ui.texture(f"interface/targetingframe/{stem}.blp")
    bar_texture = ui.texture("interface/targetingframe/ui-targetingframe-barfill.blp")
    mask = ui.texture("interface/characterframe/tempportraitalphamask.blp")

    # The measured client windows are transparent in the frame BLP, so the canvas supplies the empty trough.
    # Draw the StatusBars and portrait before the chrome; drawing the BLP twice thickens its semi-transparent edges.
    health_bounds = tuple(v + (x if i % 2 == 0 else y) for i, v in enumerate(HEALTH_WINDOW))
    power_bounds = tuple(v + (x if i % 2 == 0 else y) for i, v in enumerate(POWER_WINDOW))
    status_bar(canvas, bar_texture, health_bounds, 0.86, wowmock.rgb("3f7a34"))
    status_bar(canvas, bar_texture, power_bounds, 0.62, wowmock.rgb("2f5a9e"))

    portrait_layer = ui.canvas(canvas.width, canvas.height)
    diameter = PORTRAIT_RADIUS * 2
    portrait_left, portrait_top = x + PORTRAIT_CENTER[0] - PORTRAIT_RADIUS, y + PORTRAIT_CENTER[1] - PORTRAIT_RADIUS
    portrait_layer.draw(icon, portrait_left, portrait_top, diameter, diameter)
    portrait_layer.mask(mask, portrait_left, portrait_top, diameter, diameter)
    canvas.paste(portrait_layer, 0, 0)
    # One native-size frame pass keeps the portrait rim, bar borders, and elite crest on the source coordinates.
    art(canvas, frame, x, y, colour)
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


def nameplate(ui, canvas, x, y, tier, name, elite=False):
    """One nameplate: the plate's own trough recoloured to the tier, the reaction fill inside it, the elite dragon as
    the client draws it. Copper leaves the trough at the bronze the client ships."""
    _, _, colour, _ = tier
    w, h = 116, 12
    fill_texture = ui.texture("interface/targetingframe/nameplatefill.blp")
    plate_colour = colour or BRASS
    trough_colour = tuple(component * 0.18 for component in plate_colour)
    canvas.draw(fill_texture, x, y, w, h, trough_colour)
    status_bar(canvas, fill_texture, (x, y, x + w, y + h), 0.9, wowmock.rgb("a3342c"))
    font = FONTS["GameFontNormalSmall"]
    label_width = canvas.text_width(name, font)
    icon_size = 14 if elite else 0
    gap = 3 if elite else 0
    group_width = label_width + gap + icon_size
    group_left = x + (w - group_width) / 2
    text(canvas, group_left, y - 15, name, "GameFontNormalSmall", TEXT)
    if elite:
        canvas.draw(
            ui.atlas("nameplates-icon-elite-gold"),
            group_left + label_width + gap,
            y - 17,
            icon_size,
            icon_size,
        )


def sheet(ui, icons, name, elite=False, plates=False):
    cols, rows = 2, 2
    cell_w, cell_h = 330, 210
    m = 34
    canvas = ui.canvas(cell_w * cols + m * 2, cell_h * rows + m * 2 + 64)
    canvas.fill(0, 0, canvas.width, canvas.height, BG)
    text(canvas, m, 18, "FIELD GUIDE  \u00b7  RARITY RECOLOUR", "GameFontNormal", BRASS)
    text(
        canvas,
        m,
        36,
        "The client's own brass, desaturated and vertex-coloured - one tier per cell",
        "GameFontDisableSmall",
        MUTED,
    )
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
        target_frame(ui, canvas, cx + 14, cy + 46, tier, icons[glyph[index]], folk[index], 12 + index, elite=elite)
        if plates:
            nameplate(ui, canvas, cx + 74, cy + 186, tier, folk[index], elite=elite)
    return canvas


def main():
    ui = wowmock.Ui(scale=2)
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
