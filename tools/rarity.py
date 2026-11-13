"""Rarity mockups: the target frame and the nameplate at every collection tier.

The addon's own ornaments do the work. A silver creature draws the client's rare silver portrait ring plus the silver
laurel around its portrait, gold draws the gold laurel alone, and shiny draws the rare ring, the shiny laurel and the
client's loot-toast sheen across the ornament. Each ornament is the addon's 256 px square TGA drawn at 2 px per UI
unit, so 128 UI units a side and never stretched. Nameplates carry the same quality icon to the right of the health
bar. The health bar fill and name text keep the client's own colours, and BRONZE is the untouched client frame.

Rare, elite, boss and minus-mob units already get the client's own frame art, so our ornaments are skipped for them
and the nameplate mark alone reads the coat. The nameplate sheet is an animated GIF that plays the shiny sheen on
UI/Rarity.lua's own timing. Every pixel that is not the addon's own art or layout comes from the pinned WoW:
Forever build through wowmock, so what is approved here is what the addon paints.

    python3 tools/rarity.py
"""

import os
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw
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
    ("SILVER", "1 in 25", wowmock.rgb("c9d2dc"), "silver ring and a single oak sprig"),
    ("GOLD", "1 in 100", wowmock.rgb("e8bd63"), "the gold laurel"),
    ("SHINY", "1 in 1000", wowmock.rgb("b9e6ff"), "a pearl laurel with a passing sheen"),
)
# The addon's own ornaments, one per coat. Each file is 256 px square at 2 px per UI unit, so 128 UI units a side.
ORNAMENT_DIR = ROOT / "media" / "Rarity"
ORNAMENT_SIZE = 128
ORNAMENT_FILES = {
    "SILVER": "Laurel-Silver",
    "GOLD": "Laurel-Gold",
    "SHINY": "Laurel-Shiny",
}
ORNAMENTS = {}
TARGET_FRAME_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn"
RARE_FRAME_ATLAS = "UI-HUD-UnitFrame-Target-Rare-PortraitOn"
GOLD_RING_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold"
SHEEN_ATLAS = "loottoast-sheen"
HEALTH_BAR_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
POWER_BAR_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana"
NAME_BAR_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Type"
# Art.TIER_ICONS for the tiers whose target frame and nameplate carry their quality mark, at Rarity.lua's size and
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

# The UI-HUD target frame's atlas is 192 by 67. These windows are the measured client regions inside it, in the same
# units TargetFrame.xml anchors its health, power and portrait to.
FRAME_W, FRAME_H = 192, 67
HEALTH_WINDOW = (3, 23.5, 129, 43.5)
POWER_WINDOW = (3, 44.5, 137, 54.5)
# TargetFrame.xml centres FrameTexture (192x67) in the 232x100 container, so its top-left is (20, 16.5) container
# units. The 58-wide portrait is anchored TOPRIGHT -26,-19, putting its centre at (177, 48) in the container and
# (157, 31.5) in the frame art.
PORTRAIT_CENTER = (157, 31.5)
PORTRAIT_RADIUS = 29
# TargetFrame.xml's ReputationColor is 135 by 18, anchored TOPRIGHT at -75,-25 in the 232 by 100 container, which puts
# it at (2, 8.5) in the frame art. Camelot's TargetFrame.lua then anchors Name to its TOPRIGHT at -133,-1 with width
# 117, so the name box starts at (4, 9.5) in the art and is 117 by 12.
NAME_BAR_LEFT, NAME_BAR_TOP = 2, 8.5
NAME_BAR_W, NAME_BAR_H = 135, 18
NAME_LEFT = NAME_BAR_LEFT + NAME_BAR_W - 133
NAME_TOP = NAME_BAR_TOP + 1
NAME_W, NAME_H = 117, 12
# UI/Rarity.lua draws only the rare atlas's portrait ring, cut to the client's CircleMask; its bar piece would paint a
# rectangular border over the name and health bar. The ring's measured outer diameter is 64.
RING_OUTER_DIAMETER = 64
# Camelot's TargetFrame.lua centres LevelText on LevelBackgroundCircle at the frame's bottom right, not Mainline's
# top-left spot.
LEVEL_CENTER = (188, 54)
# UI/Rarity.lua anchors each ornament by its round hole to the portrait's centre. The ornament's hole is 48 units right
# and 80 down from its top-left, so the renderer places that hole on the portrait centre it already measures.
ORNAMENT_LEFT = PORTRAIT_CENTER[0] - 48
ORNAMENT_TOP = PORTRAIT_CENTER[1] - 80

# UI/Rarity.lua anchors the sheen's CENTER on TargetFrameContainer's CENTER at -80, 0 and translates it 165 units right.
# The 232 by 100 container centres the 192 by 67 frame art, so its centre is (96, 33.5) in frame-art units.
SHEEN_START_CENTER = (96 - 80, 33.5)
SHEEN_TRAVEL = 165
# UI/Rarity.lua's sheen timing in seconds: fade in from START, travel from START, fade out from FADE_OUT, then HOLD.
SHEEN_START = 1.1
SHEEN_FADE_IN = 0.18
SHEEN_FADE_OUT = 1.575
SHEEN_FADE_OUT_DURATION = 0.25
SHEEN_TRAVEL_DURATION = 0.725
SHEEN_HOLD = 2.4
# GIF frame time while the sheen moves; GIF delays are whole hundredths of a second.
SHEEN_FRAME = 0.04

# NumberFontNormalSmall is the client font object used by target-frame level text.
FONTS["NumberFontNormalSmall"] = Font(wowmock.ARIALN, 10, wowmock.WHITE, None, True)


def text(canvas, x, y, value, font, colour=TEXT, **kwargs):
    canvas.text(x, y, value, FONTS[font], colour, **kwargs)


def ornament(tier):
    """The coat's ornament, loaded once as RGBA from the addon's own TGA."""
    if tier not in ORNAMENTS:
        ORNAMENTS[tier] = Image.open(ORNAMENT_DIR / f"{ORNAMENT_FILES[tier]}.tga").convert("RGBA")
    return ORNAMENTS[tier]


def draw_ornament(canvas, tier, x, y):
    """The ornament at its native aspect: 256 px at 2 px per UI unit, uniform at every render scale."""
    size = canvas.px(ORNAMENT_SIZE)
    piece = ornament(tier).resize((size, size), Image.Resampling.LANCZOS)
    canvas.composite(piece, canvas.px(x + ORNAMENT_LEFT), canvas.px(y + ORNAMENT_TOP))


def rare_ring(ui):
    """UI/Rarity.lua's rare-frame ring, cut to the client's portrait circle."""
    image = ui.atlas(RARE_FRAME_ATLAS).image
    ring = image.copy()
    density = image.width / FRAME_W
    supersample = 4
    size = (image.width * supersample, image.height * supersample)
    mask = Image.new("L", size, 0)
    cx, cy = PORTRAIT_CENTER[0] * density * supersample, PORTRAIT_CENTER[1] * density * supersample
    radius = RING_OUTER_DIAMETER / 2 * density * supersample
    ImageDraw.Draw(mask).ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=255)
    ring.putalpha(ImageChops.multiply(ring.getchannel("A"), mask.resize(image.size, Image.Resampling.LANCZOS)))
    return ring


def sheen_mask(canvas, pieces):
    """The union of the art's alpha, so the sheen can only paint inside that art."""
    mask = Image.new("L", canvas.image.size, 0)
    for image, left, top, width, height in pieces:
        alpha = image.resize((canvas.px(width), canvas.px(height)), Image.Resampling.LANCZOS).getchannel("A")
        layer = Image.new("L", mask.size, 0)
        layer.paste(alpha, (canvas.px(left), canvas.px(top)))
        mask = ImageChops.lighter(mask, layer)
    return mask


def sheen(canvas, ui, x, y, pieces, travelled, alpha):
    """Draw the loot-toast sheen `travelled` units along its sweep at `alpha`, clipped to the art it crosses."""
    if alpha <= 0:
        return
    atlas = ui.atlas(SHEEN_ATLAS)
    layer = Image.new("RGBA", canvas.image.size)
    piece = atlas.image.resize((canvas.px(atlas.width), canvas.px(atlas.height)), Image.Resampling.LANCZOS)
    left = x + SHEEN_START_CENTER[0] + travelled - atlas.width / 2
    top = y + SHEEN_START_CENTER[1] - atlas.height / 2
    layer.paste(piece, (canvas.px(left), canvas.px(top)))
    mask = sheen_mask(canvas, pieces).point(lambda value: round(value * alpha))
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), mask))
    canvas.composite(layer, 0, 0, blend="ADD")


def sheen_state(t):
    """The sheen's travel and alpha `t` seconds into one loop, as UI/Rarity.lua's animation group plays it."""
    travel = SHEEN_TRAVEL * min(1, max(0, (t - SHEEN_START) / SHEEN_TRAVEL_DURATION))
    if t < SHEEN_START:
        return travel, 0.0
    if t < SHEEN_START + SHEEN_FADE_IN:
        return travel, (t - SHEEN_START) / SHEEN_FADE_IN
    if t < SHEEN_FADE_OUT:
        return travel, 1.0
    return travel, max(0.0, 1 - (t - SHEEN_FADE_OUT) / SHEEN_FADE_OUT_DURATION)


def target_frame(ui, canvas, x, y, tier, icon, name, level, native=False, sheen_at=None):
    """Compose the client target frame with the addon's ornament; `sheen_at` is the time into the shiny sheen loop."""
    label = tier[0]
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

    # The client's rare portrait ring under the addon's own ornament. A rare, elite or boss unit keeps the art the
    # client already drew there instead.
    if not native:
        if label in ("SILVER", "SHINY"):
            ring = rare_ring(ui)
            canvas.draw(ring, x, y, FRAME_W, FRAME_H)
        if label in ORNAMENT_FILES:
            draw_ornament(canvas, label, x, y)
        if label == "SHINY" and sheen_at is not None:
            # UI/Rarity.lua masks the sheen by the shiny ornament alone.
            pieces = ((ornament(label), x + ORNAMENT_LEFT, y + ORNAMENT_TOP, ORNAMENT_SIZE, ORNAMENT_SIZE),)
            sheen(canvas, ui, x, y, pieces, *sheen_state(sheen_at))
    else:
        ring = ui.atlas(GOLD_RING_ATLAS)
        canvas.draw(ring, x + 112, y - 17.5, ring.width, ring.height)

    # The client's name bar sits over the frame art, and the name sits inside it where Camelot anchors it.
    canvas.draw(ui.atlas(NAME_BAR_ATLAS), x + NAME_BAR_LEFT, y + NAME_BAR_TOP, NAME_BAR_W, NAME_BAR_H)

    # The status bar art already carries the client's green and blue fills; crop it to the shown fraction.
    for atlas, bounds, fraction in (
        (health_bar, HEALTH_WINDOW, 0.86),
        (power_bar, POWER_WINDOW, 0.62),
    ):
        left, top, right, bottom = bounds
        width, height = canvas.px(right - left), canvas.px(bottom - top)
        full = atlas.image.resize((width, height), Image.Resampling.LANCZOS)
        filled = max(1, round(width * fraction))
        canvas.composite(full.crop((0, 0, filled, height)), canvas.px(x + left), canvas.px(y + top))

    text(
        canvas,
        x + NAME_LEFT,
        y + NAME_TOP,
        name,
        "GameFontNormalSmall",
        TEXT,
        justify="LEFT",
        width=NAME_W,
        box_height=NAME_H,
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


def mark(canvas, ui, name, x, y, height, colour):
    """Draw a native atlas mark at its own aspect, centred on (x, y), as SetAtlas and SetVertexColor do."""
    atlas = ui.atlas(name)
    width = height * atlas.width / atlas.height
    piece = atlas.image.resize((canvas.px(width), canvas.px(height)), Image.Resampling.LANCZOS)
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
    full = fill_texture.resize((canvas.px(w), canvas.px(h)), Image.Resampling.LANCZOS)
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


def sheet(ui, icons, name, native=False, plates=False, sheen_at=None):
    cols, rows = 2, 2
    cell_w, cell_h = 330, 220
    m = 34
    canvas = ui.canvas(cell_w * cols + m * 2, cell_h * rows + m * 2 + 64)
    canvas.fill(0, 0, canvas.width, canvas.height, BG)
    text(canvas, m, 18, "FIELD GUIDE  \u00b7  RARITY AT A GLANCE", "GameFontNormal", BRASS)
    subtitle = "Field Guide's own laurel ornaments around each portrait"
    if native:
        subtitle = "The client's own rare and elite frame art stays; the nameplate mark names the coat"
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
        target_frame(ui, canvas, cx + 14, cy + 52, tier, icons[glyph[index]], folk[index], 12 + index, native, sheen_at)
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
    # The still sheets catch the sheen mid-sweep, so a static image still shows that shiny shines.
    still = SHEEN_START + SHEEN_TRAVEL_DURATION / 2
    sheet(ui, icons, "target frames", sheen_at=still).save(OUT / "rarity-target.png")
    sheet(ui, icons, "elite frames", native=True, plates=True).save(OUT / "rarity-elite.png")
    nameplates_gif(ui, icons)
    print("wrote 3 rarity sheets")


def nameplates_gif(ui, icons):
    """The nameplate sheet as one loop of the shiny sheen: a hold frame, the sweep at SHEEN_FRAME, then the hold."""
    sweep_end = SHEEN_FADE_OUT + SHEEN_FADE_OUT_DURATION
    times = [0.0]
    t = SHEEN_START
    while t < sweep_end - SHEEN_FRAME / 2:
        times.append(t)
        t = round(t + SHEEN_FRAME, 6)
    times.append(sweep_end)
    loop = sweep_end + SHEEN_HOLD
    durations = [round((b - a) * 1000) for a, b in zip(times, times[1:] + [loop], strict=True)]
    frames = [sheet(ui, icons, "nameplates", plates=True, sheen_at=t).image.convert("RGB") for t in times]
    # One palette from the first frame and the sheen mid-sweep, so the static art keeps one colour through the loop.
    # No dither, which would flicker between frames and defeat GIF compression.
    palette_source = Image.new("RGB", (frames[0].width, frames[0].height * 2))
    palette_source.paste(frames[0], (0, 0))
    palette_source.paste(frames[len(frames) // 2], (0, frames[0].height))
    # libimagequant keeps the small hues (the teal shiny mark, the laurel's violet) that median cut merges away.
    # Pillow wheels ship without it, so fall back to median cut rather than failing the render on a stock interpreter.
    method = Image.Quantize.LIBIMAGEQUANT
    try:
        palette = palette_source.quantize(colors=256, method=method)
    except ValueError:
        palette = palette_source.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    quantised = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    quantised[0].save(
        OUT / "rarity-nameplates.gif",
        save_all=True,
        append_images=quantised[1:],
        duration=durations,
        loop=0,
        optimize=False,
        disposal=1,
    )


if __name__ == "__main__":
    sys.exit(main())
