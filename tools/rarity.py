"""Rarity mockups: the target frame and the nameplate at every collection tier.

The addon's own ornaments do the work. A silver creature draws the client's rare silver frame plus the silver laurel
around its portrait, gold draws the gold laurel alone, and shiny draws the rare frame, the shiny laurel and the
client's loot-toast sheen across both pieces. Each ornament is the addon's 256 px square TGA drawn at 2 px per UI
unit, so 128 UI units a side and never stretched. The coat's quality gem sits in a socket at six o'clock in the
ornament, and the SILVER, GOLD or SHINY tag stays above the name. Nameplates carry the same quality icon to the right
of the health bar. The health bar fill and name text keep the client's own colours, and BRONZE is the untouched
client frame.

Rare, elite, boss and minus-mob units already get the client's own frame art, so our ornaments and their gem are
skipped for them while the tag still reads the coat. Every pixel that is not the addon's own art or layout comes from
the pinned WoW: Forever build through wowmock, so what is approved here is what the addon paints.

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
    ("SILVER", "1 in 25", wowmock.rgb("c9d2dc"), "silver coat, quality gem and SILVER tag"),
    ("GOLD", "1 in 100", wowmock.rgb("e8bd63"), "gold coat, quality gem and GOLD tag"),
    ("SHINY", "1 in 1000", wowmock.rgb("b9e6ff"), "shiny coat, quality gem and SHINY tag"),
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
# UI/Rarity.lua's GEM_SOCKETS and GEM_SIZES: each gem is centred on the ornament's six o'clock socket, from the art's
# top-left, and drawn as a square so the 50 px quality atlas keeps its aspect.
ORNAMENT_HOLE = (48, 80)
GEM_SOCKETS = {
    "SILVER": (0.5, 31.5),
    "GOLD": (1.25, 30.75),
    "SHINY": (0.75, 31.0),
}
GEM_SIZES = {
    "SILVER": 11.5,
    "GOLD": 12,
    "SHINY": 11.7,
}
TARGET_FRAME_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn"
RARE_FRAME_ATLAS = "UI-HUD-UnitFrame-Target-Rare-PortraitOn"
GOLD_RING_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold"
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
# TargetFrame.xml centres FrameTexture (192x67) in the 232x100 container, so its top-left is (20, 16.5) container
# units. The 58-wide portrait is anchored TOPRIGHT -26,-19, putting its centre at (177, 48) in the container and
# (157, 31.5) in the frame art.
PORTRAIT_CENTER = (157, 31.5)
PORTRAIT_RADIUS = 29
# Camelot's TargetFrame.lua centres LevelText on LevelBackgroundCircle at the frame's bottom right, not Mainline's
# top-left spot.
LEVEL_CENTER = (188, 54)
# UI/Rarity.lua anchors each ornament at TOPLEFT container TOPRIGHT -103, 32, which puts its round hole (centred 48
# units right and 80 down from the ornament's top-left) over the portrait. The renderer draws from the frame art's own
# origin, so it places that hole on the portrait centre it already measures.
ORNAMENT_LEFT = PORTRAIT_CENTER[0] - 48
ORNAMENT_TOP = PORTRAIT_CENTER[1] - 80

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
    piece = ornament(tier).resize((size, size), Image.LANCZOS)
    canvas.composite(piece, canvas.px(x + ORNAMENT_LEFT), canvas.px(y + ORNAMENT_TOP))


def draw_gem(canvas, ui, label, x, y):
    """The tier's quality gem, centred on the ornament's socket exactly as UI/Rarity.lua anchors it."""
    socket = GEM_SOCKETS[label]
    mark(
        canvas,
        ui,
        PLATE_MARKS[label],
        x + ORNAMENT_LEFT + ORNAMENT_HOLE[0] + socket[0],
        y + ORNAMENT_TOP + ORNAMENT_HOLE[1] + socket[1],
        GEM_SIZES[label],
        wowmock.WHITE,
    )


def sheen_mask(canvas, pieces):
    """The union of the art's alpha, so the sheen can only paint inside that art."""
    mask = Image.new("L", canvas.image.size, 0)
    for image, left, top, width, height in pieces:
        alpha = image.resize((canvas.px(width), canvas.px(height)), Image.LANCZOS).getchannel("A")
        layer = Image.new("L", mask.size, 0)
        layer.paste(alpha, (canvas.px(left), canvas.px(top)))
        mask = ImageChops.lighter(mask, layer)
    return mask


def sheen(canvas, ui, x, y, pieces):
    """Draw the loot-toast sheen still, clipped to the rare frame and ornament it crosses."""
    atlas = ui.atlas(SHEEN_ATLAS)
    layer = Image.new("RGBA", canvas.image.size)
    piece = atlas.image.resize((canvas.px(atlas.width), canvas.px(atlas.height)), Image.LANCZOS)
    layer.paste(piece, (canvas.px(x + 90), canvas.px(y - 4)))
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), sheen_mask(canvas, pieces)))
    canvas.composite(layer, 0, 0, blend="ADD")


def target_frame(ui, canvas, x, y, tier, icon, name, level, native=False):
    """Compose the client target frame with the addon's ornament, the quality gem and the tag."""
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

    # The client's rare frame under the addon's own ornament. A rare, elite or boss unit keeps the art the client
    # already drew there instead.
    if not native:
        if label in ("SILVER", "SHINY"):
            canvas.draw(ui.atlas(RARE_FRAME_ATLAS), x, y, FRAME_W, FRAME_H)
        if label in ORNAMENT_FILES:
            draw_ornament(canvas, label, x, y)
            draw_gem(canvas, ui, label, x, y)
        if label == "SHINY":
            sheen(
                canvas,
                ui,
                x,
                y,
                (
                    (ui.atlas(RARE_FRAME_ATLAS).image, x, y, FRAME_W, FRAME_H),
                    (ornament(label), x + ORNAMENT_LEFT, y + ORNAMENT_TOP, ORNAMENT_SIZE, ORNAMENT_SIZE),
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
    subtitle = "Field Guide's own laurel ornaments around each portrait, with the quality gem and tag"
    if native:
        subtitle = "The client's own rare and elite frame art stays; the tag still names the coat"
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
