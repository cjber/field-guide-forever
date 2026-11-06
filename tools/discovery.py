"""Discovery feedback mockups: the new-creature line, the journal's New tag and the milestone toasts.

UI/Discovery.lua shows a first kill the way the client shows a newly explored area: one yellow line in UIErrorsFrame
(Blizzard_UIErrorsFrame/Mainline/UIErrorsFrame.xml, ErrorFont over YELLOW_FONT_COLOR). The list row carries the mount
journal's New tag (Blizzard_MountCollection.xml: GameFontHighlight NEW_CAPS over the collections-newglow atlas). The
big moments use the client's own achievement toast (Mainline/AlertFrameSystems.xml:173) with the points shield hidden;
a shiny takes the template's guild variant art, the larger frame the client already ships.

Every pixel that is not the addon's own text comes from the pinned WoW: Forever build through wowmock.

    python3 tools/discovery.py [output directory]
"""

import os
import sys
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter  # ty: ignore[unresolved-import]  # Pillow is local only
from ui_art import BUILD as ART_BUILD

ROOT = Path(__file__).resolve().parent.parent
FOREVER_CORE = Path(os.environ.get("FOREVER_CORE", ROOT.parent / "forever-core")).expanduser()
WOWMOCK = FOREVER_CORE / "tools" / "wowmock"
if not (WOWMOCK / "wowmock.py").is_file():
    raise SystemExit(f"wowmock.py not found in {WOWMOCK}; set FOREVER_CORE to the forever-core checkout")
sys.path.insert(0, str(WOWMOCK))
import wowmock  # noqa: E402  # ty: ignore[unresolved-import]
from wowmock import (  # noqa: E402  # ty: ignore[unresolved-import]
    FONTS,
    FRIZQT,
    INSET_FRAME_LAYOUT,
    Font,
    draw_nine_slice,
    tiled,
)

OUT = ROOT / "docs" / "screenshots"

TEXT = wowmock.rgb("e3d9c2")
MUTED = wowmock.rgb("9e998c")
GOLD = wowmock.rgb("e0b540")
YELLOW = (1.0, 1.0, 0.0)  # YELLOW_FONT_COLOR, the colour UIErrorsFrame gives UI_INFO_MESSAGE
BLACK = (0.0, 0.0, 0.0)

# SystemFont_Tiny is FRIZQT at 9; GameFontBlackTiny paints it black with no shadow.
FONTS.setdefault("GameFontBlackTiny", Font(FRIZQT, 9, BLACK))
FONTS.setdefault("ErrorFont", Font(FRIZQT, 16, YELLOW, (1, -1)))

CAT_ICON = "interface/icons/ability_hunter_pet_cat.blp"
BOAR_ICON = "interface/icons/ability_hunter_pet_boar.blp"
SPIDER_ICON = "interface/icons/ability_hunter_pet_spider.blp"
BOOK_ICON = "interface/icons/inv_misc_book_09.blp"
# Aldrassil, the tree at the heart of Shadowglen, on the Kalimdor continent map.
SHADOWGLEN = (1, 10311, 832)


def text(canvas, x, y, value, font, colour=None, **kwargs):
    canvas.text(x, y, value, FONTS[font], colour, **kwargs)


def world(ui, width, height):
    """Shadowglen from above, from the client's own minimap tiles, softened and dimmed to stand in for the 3D world."""
    map_id, x, y = SHADOWGLEN
    image = wowmock.minimap_art(ui, map_id, x, y, 220).convert("RGB")
    canvas = ui.canvas(width, height)
    w, h = canvas.image.size
    side = max(w, h)
    image = image.resize((side, side), Image.Resampling.LANCZOS)
    image = image.crop(((side - w) // 2, (side - h) // 2, (side - w) // 2 + w, (side - h) // 2 + h))
    image = ImageEnhance.Brightness(image.filter(ImageFilter.GaussianBlur(3))).enhance(0.75)
    canvas.image = image.convert("RGBA")
    return canvas


def discovery_line(ui, name):
    """UIErrorsFrame (512 wide, TOP -122 of UIParent): the first kill's line where an explored area's line appears."""
    width, height = 760, 300
    canvas = world(ui, width, height)
    frame_x, frame_y = (width - 512) / 2, 122
    text(canvas, frame_x, frame_y, f"New creature recorded: {name}", "ErrorFont", justify="CENTER", width=512)
    return canvas


def new_tag(canvas, ui, name_x, y, name):
    """The mount journal's New tag: NEW after the name's text, 8 units right, over collections-newglow."""
    left = name_x + canvas.text_width(name, FONTS["GameFontNormal"]) + 8
    label = "NEW"
    width = canvas.text_width(label, FONTS["GameFontHighlight"])
    canvas.draw(ui.atlas("collections-newglow"), left - 20, y - 10, width + 40, 12 + 20)
    shadow = ui.global_color("NEW_FEATURE_SHADOW_COLOR")[:3]
    canvas.text(left + 1, y + 1, label, Font(FRIZQT, 12, shadow))
    canvas.text(left, y, label, Font(FRIZQT, 12, wowmock.WHITE))


def list_panel(ui, rows):
    """The creature list as UI/List.lua lays it out: 304 x 46 rows of icon, name, family and level, kills, bar."""
    width, height = 304 + 36, len(rows) * 46 + 36
    canvas = ui.canvas(width, height)
    marble = ui.texture("interface/framegeneral/ui-background-marble.blp")
    tiled(canvas, marble, 0, 0, width, height, marble.width / ui.scale, marble.height / ui.scale)
    draw_nine_slice(canvas, INSET_FRAME_LAYOUT, 0, 0, width, height)
    for index, (icon, name, family, level, kills, count, new) in enumerate(rows):
        x, y = 18, 18 + index * 46
        canvas.draw(ui.texture(icon), x + 10, y + 5, 32, 32)
        text(canvas, x + 52, y + 5, name, "GameFontNormal", TEXT, width=152)
        if new:
            new_tag(canvas, ui, x + 52, y + 5, name)
        text(canvas, x + 52, y + 23, f"{family} · Lv {level}", "GameFontDisableSmall", MUTED)
        canvas.text(x + 290 - 64, y + 5, f"{kills} kills", FONTS["GameFontNormal"], TEXT, justify="RIGHT", width=64)
        canvas.draw(ui.atlas("common-stat-bar-BG"), x + 10, y + 40, 280, 3)
        if count:
            canvas.draw(ui.atlas("common-stat-bar-white"), x + 10, y + 40, 280 * count / 10, 3, GOLD)
    return canvas


def toast(ui, heading, name, icon, variant="achievement"):
    """AchievementAlertFrameTemplate as AchievementAlertFrame_SetUp leaves an already-earned achievement: shield
    hidden, heading at TOP 27,-23, the name below it. `variant="guild"` is the same function's guild branch art."""
    guild = variant == "guild"
    width, height = 300, 104 if guild else 101
    canvas = ui.canvas(width, height)
    background = ui.atlas("ui-achievement-guild-background" if guild else "ui-achievement-alert-background")
    canvas.draw(background, (width - background.width) / 2, (height - background.height) / 2)
    icon_x, icon_y = (0, 25) if guild else (-4, 15)
    canvas.draw(ui.texture(icon), icon_x + (78 - 52) / 2, icon_y + (75 - 52) / 2 + (2 if guild else 0), 52, 52)
    frame = ui.atlas("ui-achievement-guild-iconframe" if guild else "ui-achievement-iconframe")
    ox, oy = (0, 0) if guild else (-1, 2)
    canvas.draw(frame, icon_x + (78 - frame.width) / 2 + ox, icon_y + (75 - frame.height) / 2 - oy)
    heading_y = 38 if guild else 23
    heading_x = width / 2 + (0 if guild else 27) - 100
    text(canvas, heading_x, heading_y, heading, "GameFontBlackTiny", justify="CENTER", width=200)
    name_x = width / 2 + (0 if guild else 27) - 155 / 2
    text(canvas, name_x, heading_y + 12, name, "GameFontHighlight", box_height=36, justify="CENTER", width=155)
    return canvas


def main(argv):
    out = Path(argv[0]) if argv else OUT
    out.mkdir(parents=True, exist_ok=True)
    ui = wowmock.Ui(build=ART_BUILD, scale=2)
    discovery_line(ui, "Nightsaber").save(out / "discovery-new-creature.png")
    rows = [
        (CAT_ICON, "Young Nightsaber", "Beast", "1-2", 6, 6, False),
        (CAT_ICON, "Nightsaber", "Beast", "4-5", 1, 1, True),
        (BOAR_ICON, "Young Thistle Boar", "Beast", "1-2", 3, 3, False),
        (SPIDER_ICON, "Webwood Spider", "Beast", "3-4", 0, 0, False),
    ]
    wowmock.scene(ui, [(list_panel(ui, rows), 0, 0)]).save(out / "discovery-new-tag.png")
    toasts = [
        ("discovery-toast-silver.png", "Silver found", "Nightsaber", CAT_ICON, "achievement"),
        ("discovery-toast-gold.png", "Gold found", "Nightsaber", CAT_ICON, "achievement"),
        ("discovery-toast-shiny.png", "Shiny found", "Shiny Nightsaber!", CAT_ICON, "guild"),
        ("discovery-toast-mastered.png", "Mastered", "Nightsaber", CAT_ICON, "achievement"),
        ("discovery-toast-zone.png", "Zone complete", "Shadowglen: every creature recorded", BOOK_ICON, "achievement"),
    ]
    for filename, heading, name, icon, variant in toasts:
        wowmock.scene(ui, [(toast(ui, heading, name, icon, variant), 0, 0)]).save(out / filename)
    print(f"wrote {2 + len(toasts)} discovery scenes to {out}")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
