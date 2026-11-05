"""Rarity recolour mockups: the target frame and the nameplate at every collection tier.

The tier mark is not an addon-drawn border. Each tier drops the chroma out of the client's own brass hardware and
multiplies the tier colour back in, which is exactly what UI/Rarity.lua does at runtime with `SetDesaturated(true)`
and `SetVertexColor`. So these sheets are the recolour itself: COMMON is the untouched client frame, and silver, gold
and shiny are the same textures with the brass removed and the tier colour laid into the shading.

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

# UI/Rarity.lua's COLORS table, verbatim. Copper has no entry because copper is the client's own brass and needs no
# recolour at all; the whole promise of the feature is that a common creature looks exactly as it always did.
TIERS = (
    ("COMMON", "1 in 1", None, "the client's brass, untouched"),
    ("SILVER", "1 in 25", wowmock.rgb("c9d2dc"), "silver chrome, border and elite mark"),
    ("GOLD", "1 in 100", wowmock.rgb("e8bd63"), "gold chrome, border and elite mark"),
    ("SHINY", "1 in 1000", wowmock.rgb("b9e6ff"), "cyan chrome, star badge and pulsing aura"),
)
TARGET_BAR_GLOW_LEFT = "UI-Frame-Bar-GlowLeft"
TARGET_BAR_GLOW_CENTER = "UI-Frame-Bar-GlowCenter"
TARGET_BAR_GLOW_RIGHT = "UI-Frame-Bar-GlowRight"
TARGET_BAR_GLOW_LEFT_WIDTH = 35
TARGET_BAR_GLOW_RIGHT_WIDTH = 34
TARGET_BAR_GLOW_PAD = 3
TARGET_RING = "Portrait-Frame-Small"
TARGET_RING_SIZE = 76
TARGET_BADGE = "Rare-Elite-Star"
TARGET_BADGE_SIZE = 26
BAR_TINT_ALPHA = {"SILVER": 0.3, "GOLD": 0.3, "SHINY": 0.45}
PLATE_MARKS = {
    "SILVER": "nameplates-icon-elite-silver",
    "GOLD": "nameplates-icon-elite-gold",
    "SHINY": TARGET_BADGE,
}

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


def bar_glow(canvas, ui, x, y, colour):
    """The client's three-piece bar glow, stretched over the health and mana chrome exactly as the runtime anchors
    it, with no fill behind the bars."""
    left = x + min(HEALTH_WINDOW[0], POWER_WINDOW[0]) - TARGET_BAR_GLOW_PAD
    top = y + HEALTH_WINDOW[1] - TARGET_BAR_GLOW_PAD
    right = x + max(HEALTH_WINDOW[2], POWER_WINDOW[2]) + TARGET_BAR_GLOW_PAD
    bottom = y + POWER_WINDOW[3] + TARGET_BAR_GLOW_PAD
    height = bottom - top
    glow_piece(canvas, ui, TARGET_BAR_GLOW_LEFT, left, top, TARGET_BAR_GLOW_LEFT_WIDTH, height, colour, 0.8)
    glow_piece(
        canvas,
        ui,
        TARGET_BAR_GLOW_RIGHT,
        right - TARGET_BAR_GLOW_RIGHT_WIDTH,
        top,
        TARGET_BAR_GLOW_RIGHT_WIDTH,
        height,
        colour,
        0.8,
    )
    glow_piece(
        canvas,
        ui,
        TARGET_BAR_GLOW_CENTER,
        left + TARGET_BAR_GLOW_LEFT_WIDTH,
        top,
        right - left - TARGET_BAR_GLOW_LEFT_WIDTH - TARGET_BAR_GLOW_RIGHT_WIDTH,
        height,
        colour,
        0.8,
    )


def bar_tint(canvas, bounds, colour, alpha):
    """The tier tint behind a bar's fill, so its empty background reads as the tier rather than the client's dark
    trough."""
    left, top, right, bottom = bounds
    canvas.fill(left, top, right - left, bottom - top, (*colour, alpha))


def portrait_ring(canvas, ui, x, y, colour):
    """The client's portrait-frame ring, tinted to the tier and scaled uniformly around the portrait."""
    glow_piece(
        canvas,
        ui,
        TARGET_RING,
        x + PORTRAIT_CENTER[0] - TARGET_RING_SIZE / 2,
        y + PORTRAIT_CENTER[1] - TARGET_RING_SIZE / 2,
        TARGET_RING_SIZE,
        TARGET_RING_SIZE,
        colour,
        0.85,
    )


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

    # The bar glow sits behind the client chrome, so it haloes the bars without washing them out.
    if colour:
        bar_glow(canvas, ui, x, y, colour)
    # The measured client windows are transparent in the frame BLP, so the canvas supplies the empty trough.
    # Draw the StatusBars and portrait before the chrome; drawing the BLP twice thickens its semi-transparent edges.
    health_bounds = tuple(v + (x if i % 2 == 0 else y) for i, v in enumerate(HEALTH_WINDOW))
    power_bounds = tuple(v + (x if i % 2 == 0 else y) for i, v in enumerate(POWER_WINDOW))
    if colour:
        alpha = BAR_TINT_ALPHA.get(tier[0], 0.3)
        bar_tint(canvas, health_bounds, colour, alpha)
        bar_tint(canvas, power_bounds, colour, alpha)
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
    if colour:
        portrait_ring(canvas, ui, x, y, colour)
        centre_x = x + PORTRAIT_CENTER[0]
        centre_y = y + PORTRAIT_CENTER[1]
        mark(canvas, ui, TARGET_BADGE, centre_x + 23, centre_y - 23, TARGET_BADGE_SIZE, colour)
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
    """One nameplate: the plate's own trough recoloured to the tier, the reaction fill inside it, and a native tier
    border and mark beside the name. Copper leaves the client's bronze trough and adds nothing."""
    label, _, colour, _ = tier
    w, h = 116, 12
    fill_texture = ui.texture("interface/targetingframe/nameplatefill.blp")
    plate_colour = colour or BRASS
    trough_colour = tuple(component * 0.18 for component in plate_colour)
    canvas.draw(fill_texture, x, y, w, h, trough_colour)
    status_bar(canvas, fill_texture, (x, y, x + w, y + h), 0.9, wowmock.rgb("a3342c"))
    if colour:
        for left, top, width, height in (
            (x - 2, y - 2, w + 4, 2),
            (x - 2, y + h, w + 4, 2),
            (x - 2, y - 2, 2, h + 4),
            (x + w, y - 2, 2, h + 4),
        ):
            canvas.fill(left, top, width, height, colour)
    font = FONTS["GameFontNormalSmall"]
    label_width = canvas.text_width(name, font)
    atlas_name = PLATE_MARKS.get(label)
    atlas = ui.atlas(atlas_name) if atlas_name else None
    icon_height = 14
    icon_width = icon_height * atlas.width / atlas.height if atlas else 0
    gap = 3 if atlas else 0
    group_width = label_width + gap + icon_width
    group_left = x + (w - group_width) / 2
    text(canvas, group_left, y - 15, name, "GameFontNormalSmall", TEXT)
    if atlas:
        # The native elite marks already carry silver and gold; the shiny star takes the tier colour.
        mark_colour = colour if label == "SHINY" else wowmock.WHITE
        canvas.draw(
            atlas,
            group_left + label_width + gap,
            y - 17,
            icon_width,
            icon_height,
            mark_colour,
        )


def sheet(ui, icons, name, elite=False, plates=False):
    cols, rows = 2, 2
    cell_w, cell_h = 330, 210
    m = 34
    canvas = ui.canvas(cell_w * cols + m * 2, cell_h * rows + m * 2 + 64)
    canvas.fill(0, 0, canvas.width, canvas.height, BG)
    text(canvas, m, 18, "FIELD GUIDE  \u00b7  RARITY AT A GLANCE", "GameFontNormal", BRASS)
    text(
        canvas,
        m,
        36,
        "Tier colour, glow and mark on the target frame and its nameplate - one tier per cell",
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
            nameplate(ui, canvas, cx + 74, cy + 186, tier, folk[index])
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
