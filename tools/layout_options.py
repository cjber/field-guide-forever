"""Design mockups for the Field Guide window's tab treatment and attachment.

The shapes Cillian asked to compare, rendered from the same catalogue, icons and card content the README
screenshots use (so an option differs in chrome and geometry only, never in data):

    current          the shipping window: Blizzard LargeSideTabButtonTemplate tabs on the right edge
    spine-left       standalone window, square external tabs on the left edge
    spine-right      standalone window, square external tabs on the right edge
    map-drawer       sidecar drawer hung off the World Map's right edge, square tabs on its outer edge
    legacy-subpanel  the guide as a square-tabbed sub-panel of a LEGACY-style window

    python3 tools/layout_options.py

Renders into docs/screenshots/options/. Development only: `.pkgmeta` keeps tools/ and docs/ out of the addon.
The current option uses the same native quest-log tab atlases as the shipping addon. The other four renders remain
design comparisons and intentionally keep their existing treatments.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mockups as mk  # noqa: E402
import wowmock  # noqa: E402
from wowmock import (  # noqa: E402
    FONTS,
    PORTRAIT_FRAME_TEMPLATE_LAYOUT,
    map_art,
    minimal_scrollbar,
    portrait_frame_art,
    search_box,
    ui_panel_button,
)

OUT = mk.ROOT / "docs" / "screenshots" / "options"

W, H = 960, 720
M = 26  # canvas margin around the window, as tools/mockups.py frames it

GOLD, BRASS, TEXT, MUTED, BLUE, GREEN = mk.GOLD, mk.BRASS, mk.TEXT, mk.MUTED, mk.BLUE, mk.GREEN
DIM = mk.DIM
MUTED = wowmock.rgb("c4baa4")
DIM = MUTED
mk.MUTED = MUTED
mk.DIM = DIM
FONTS["FieldGuideTabLabel"] = wowmock.Font(
    FONTS["GameFontDisableSmall"].path, 8, FONTS["GameFontDisableSmall"].color, (1, -1)
)

TABS = ("Creatures", "Rares", "Shiny", "Instances")
TAB_INDEX = {"CREATURES": 0, "RARES": 1, "SHINY": 2, "INSTANCES": 3}


# ------------------------------------------------------------------------------------------------ tab chrome
def square_tab(canvas, x, y, size, icon, label, active, seam=None):
    """One square external tab: 1:1 plate, icon, name under it.

    `seam` names the edge that meets the frame; that edge loses its border and reaches 8 units past the
    plate, under the metal, so the tab looks carried by the window.
    """
    face = "2b2a24" if active else "171a1e"
    border = GOLD if active else wowmock.rgb("565248")
    canvas.fill(x, y, size, size, wowmock.rgb(face))
    canvas.fill(x, y, size, 1, border)
    canvas.fill(x, y + size - 1, size, 1, border)
    canvas.fill(x, y, 1, size, border)
    canvas.fill(x + size - 1, y, 1, size, border)
    if seam == "right":
        canvas.fill(x + size - 1, y, 1, size, wowmock.rgb(face))
        canvas.fill(x + size, y + 6, 8, size - 12, wowmock.rgb(face))
        canvas.fill(x + size, y + 6, 8, 1, border if active else wowmock.rgb(face))
        canvas.fill(x + size, y + size - 7, 8, 1, border if active else wowmock.rgb(face))
    elif seam == "left":
        canvas.fill(x, y, 1, size, wowmock.rgb(face))
        canvas.fill(x - 8, y + 6, 8, size - 12, wowmock.rgb(face))
        canvas.fill(x - 8, y + 6, 8, 1, border if active else wowmock.rgb(face))
        canvas.fill(x - 8, y + size - 7, 8, 1, border if active else wowmock.rgb(face))
    elif seam == "bottom":
        canvas.fill(x, y + size - 1, size, 1, wowmock.rgb(face))
        canvas.fill(x + 6, y + size, size - 12, 8, wowmock.rgb(face))
        canvas.fill(x + 6, y + size, 1, 8, border if active else wowmock.rgb(face))
        canvas.fill(x + size - 7, y + size, 1, 8, border if active else wowmock.rgb(face))
    icon_size = size - 22
    canvas.draw(icon, x + (size - icon_size) / 2, y + 6, icon_size, icon_size)
    canvas.draw(
        canvas.ui.texture("interface/common/whiteiconframe.blp"),
        x + (size - icon_size) / 2,
        y + 6,
        icon_size,
        icon_size,
        GOLD if active else BRASS,
    )
    mk.text(
        canvas,
        x,
        y + size - 14,
        label,
        "FieldGuideTabLabel",
        GOLD if active else TEXT,
        justify="CENTER",
        width=size,
        box_height=11,
    )


def frame_panel(canvas, x, y, w, h, title, close=True):
    """A metal PortraitFrameTemplate without the portrait: the shape a docked panel takes."""
    canvas.fill(x + 6, y + 22, w - 12, h - 28, wowmock.rgb("0b0c0e"))
    canvas.nine_slice(PORTRAIT_FRAME_TEMPLATE_LAYOUT, x, y, w, h)
    mk.text(canvas, x + 16, y + 6, title, "GameFontNormal", TEXT)
    if close:
        canvas.draw(canvas.ui.atlas("RedButton-Exit"), x + w - 26, y - 1, 24, 24)


# ---------------------------------------------------------------------------------------------- journal panes
SECTIONS = {
    "full": [
        ("header", 76),
        ("badges", 18),
        ("research", 84),
        ("lore", 58),
        ("variants", 66),
        ("rewards", 66),
        ("records", 60),
        ("footnote", 16),
    ],
    "compact": [("header", 76), ("badges", 18), ("research", 84), ("variants", 96), ("rewards", 100), ("records", 60)],
}


def section_tops(height, compact):
    """Spread the entry's sections to fill `height`, so every option gets even air instead of one dead band."""
    sections = SECTIONS["compact" if compact else "full"]
    natural = sum(h for _, h in sections)
    gap = max(10.0, min(34.0, (height - natural) / (len(sections) - 1)))
    tops, y = {}, 0.0
    for name, section_height in sections:
        tops[name] = y
        y += section_height + gap
    return tops


def panes(canvas, ui, zone, species, tab, icons, box, px, py, compact=False):
    """The journal's own content in `box` = (x, y, w, h) window units: list left, entry right."""
    x0, y0, box_w, box_h = box
    list_w = 316 if compact else 344
    list_x = x0 + 4
    detail_x = list_x + list_w + (44 if compact else 64)
    detail_w = x0 + box_w - detail_x
    inner = 14
    card_w = detail_w - inner * 2

    catalogued = sum(1 for s in zone["species"] if mk.progress(s)["count"])
    rows = zone["species"]
    if tab == "RARES":
        rows = [s for s in rows if s["rare"] or mk.progress(s)["rare"] >= mk.RARE_TARGET]
    elif tab == "SHINY":
        rows = [s for s in rows if mk.progress(s)["shiny"]]
    rows = rows or zone["species"]

    row_h = 58
    visible = max(1, int(box_h // row_h))
    if len(rows) > visible:
        minimal_scrollbar(canvas, px(list_x + list_w + 18), py(y0), list_w + 18, visible=visible / len(rows))
    for index, row in enumerate(rows[:visible]):
        state = mk.progress(row)
        chosen = row["id"] == species["id"]
        y = py(y0 + index * row_h)
        canvas.fill(px(list_x), y, list_w, row_h, wowmock.rgb("2b2a24") if chosen else wowmock.rgb("212429"))
        canvas.draw(icons[row["id"]], px(list_x + 6), y + 13, 32, 32)
        canvas.draw(ui.texture("interface/common/whiteiconframe.blp"), px(list_x + 6), y + 13, 32, 32, BRASS)
        known = row["rare"] and state["rare"] >= mk.RARE_TARGET
        limit = 17 if compact else 24
        name = row["name"] if len(row["name"]) <= limit else row["name"][: limit - 1].rstrip() + "\u2026"
        mk.text(canvas, px(list_x + 46), y + 8, name, "GameFontNormal", BLUE if known else TEXT, width=list_w - 118)
        level = str(row["min"]) if row["min"] == row["max"] else f"{row['min']}\u2013{row['max']}"
        mk.text(canvas, px(list_x + 46), y + 27, f"{row['family']} \u00b7 Lv {level}", "GameFontDisableSmall", MUTED)
        mk.right(canvas, px(list_x + list_w - 8), y + 8, f"{state['kills']} kills", "GameFontNormal", TEXT, width=64)
        complete = state["count"] >= 1 and bool(state["shiny"]) and (not row["rare"] or state["rare"] >= mk.RARE_TARGET)
        if state["count"] >= mk.MASTERED_AT:
            mk.marker(canvas, px(list_x + list_w - 12), y + 32, 11, GOLD)
        elif complete:
            canvas.draw(ui.atlas("common-icon-checkmark"), px(list_x + list_w - 14), y + 27, 11, 11, GREEN)
        mk.bar(canvas, px(list_x + 6), y + 49, list_w - 12, 3, state["count"] / mk.MASTERED_AT, GOLD)

    # ---------------- the entry
    state = mk.progress(species)
    count = state["count"]
    rank = mk.rank_of(count)
    tops = section_tops(box_h, compact)

    def at(name):
        return y0 + tops[name]

    # header
    ry = at("header")
    portrait = ui.canvas(canvas.width, canvas.height)
    portrait.draw(icons[species["id"]], px(detail_x + inner), py(ry + 12), 58, 58)
    portrait.mask(
        ui.texture("interface/characterframe/tempportraitalphamask.blp"), px(detail_x + inner), py(ry + 12), 58, 58
    )
    canvas.paste(portrait, 0, 0)
    canvas.draw(ui.texture("interface/common/whiteiconframe.blp"), px(detail_x + inner), py(ry + 12), 58, 58, BRASS)
    mk.text(
        canvas, px(detail_x + inner + 70), py(ry + 14), species["name"], "GameFontNormalLarge", GOLD, width=card_w - 74
    )
    level = str(species["min"]) if species["min"] == species["max"] else f"{species['min']}\u2013{species['max']}"
    mk.text(
        canvas,
        px(detail_x + inner + 70),
        py(ry + 36),
        f"{species['family']} \u00b7 {zone['name']} \u00b7 Level {level}",
        "GameFontDisableSmall",
        MUTED,
        width=card_w - 74,
    )

    # badges
    by = py(at("badges"))
    bx = detail_x + inner
    for label, colour, show in (
        ("Common", TEXT, True),
        ("Rare variant known", BLUE, state["rare"] >= mk.RARE_TARGET),
        ("Shiny seen", GOLD, bool(state["shiny"])),
    ):
        if not show:
            continue
        width = max(50, canvas.text_width(label, FONTS["GameFontDisableSmall"]) + 14)
        mk.card(canvas, px(bx), by, width, 18, colour)
        mk.text(canvas, px(bx), by, label, "GameFontDisableSmall", colour, justify="CENTER", width=width, box_height=18)
        bx += width + 6

    # research
    y = at("research")
    mk.card(canvas, px(detail_x + inner), py(y), card_w, 84)
    mk.text(canvas, px(detail_x + inner + 10), py(y + 7), "Research", "GameFontNormal", GOLD)
    pip_step = (card_w - 72) / (len(mk.PIPS) - 1)
    label_w = min(78.0, max(52.0, pip_step + 12))
    for pip_index, name in enumerate(mk.PIPS):
        x = detail_x + inner + 36 + pip_index * pip_step
        on = rank >= pip_index + 1
        mk.marker(canvas, px(x), py(y + 33), 11, GOLD if on else wowmock.rgb("4a4842"))
        if pip_index < len(mk.PIPS) - 1:
            canvas.draw(
                ui.atlas("_UI-Frame-InnerTopTile"),
                px(x + 7),
                py(y + 31),
                pip_step - 14,
                3,
                GOLD if rank >= pip_index + 2 else wowmock.rgb("3a382f"),
            )
        mk.text(
            canvas,
            px(x - label_w / 2),
            py(y + 42),
            name,
            "GameFontDisableSmall",
            TEXT if on else MUTED,
            justify="CENTER",
            width=label_w,
        )
    mk.text(canvas, px(detail_x + inner + 10), py(y + 62), "Mastery", "GameFontDisableSmall", MUTED)
    mk.right(
        canvas,
        px(detail_x + inner + card_w - 10),
        py(y + 62),
        f"{count} / 10 \u00b7 {state['kills']} deaths",
        "GameFontDisableSmall",
        TEXT,
        width=170,
    )
    mk.bar(canvas, px(detail_x + inner + 10), py(y + 76), card_w - 20, 4, count / mk.MASTERED_AT, GOLD)

    # lore (full layout only: the drawer's column has no room for a 60-word paragraph)
    if not compact:
        y = at("lore")
        mk.card(canvas, px(detail_x + inner), py(y), card_w, 58)
        mk.text(canvas, px(detail_x + inner + 10), py(y + 7), "Lore", "GameFontNormal", GOLD)
        lore_font = FONTS["GameFontDisableSmall"]
        for line_index, line in enumerate(mk.wrap_pixels(species["lore"], lore_font, card_w - 20, 2, canvas)):
            mk.text(
                canvas,
                px(detail_x + inner + 10),
                py(y + 21 + line_index * 12),
                line,
                "GameFontDisableSmall",
                wowmock.rgb("c4baa4"),
            )

    variants = [
        ("Common", "Known" if count else "0 / 1", bool(count), TEXT),
        (
            "Rare variant",
            "Known" if state["rare"] >= mk.RARE_TARGET else f"{state['rare']} / {mk.RARE_TARGET}",
            state["rare"] >= mk.RARE_TARGET,
            BLUE,
        ),
        (
            "Shiny variant",
            "Known" if state["shiny"] else f"{state['shiny']} / {mk.SHINY_TARGET}",
            bool(state["shiny"]),
            GOLD,
        ),
    ]
    y = at("variants")
    if compact:
        # one card, three rows: three side-by-side cards do not survive a 300-unit column
        mk.card(canvas, px(detail_x + inner), py(y), card_w, 96)
        mk.text(canvas, px(detail_x + inner + 10), py(y + 7), "Variants", "GameFontNormal", GOLD)
        for row_index, (title, status, known, colour) in enumerate(variants):
            line_y = y + 28 + row_index * 21
            mk.text(
                canvas,
                px(detail_x + inner + 10),
                py(line_y),
                title,
                "GameFontNormal",
                TEXT if known else MUTED,
                width=120,
            )
            if known:
                canvas.draw(ui.atlas("common-icon-checkmark"), px(detail_x + inner + 132), py(line_y), 12, 12, colour)
            else:
                mk.text(canvas, px(detail_x + inner + 132), py(line_y), "\u2014", "GameFontNormal", MUTED, width=12)
            mk.right(
                canvas,
                px(detail_x + inner + card_w - 10),
                py(line_y),
                status,
                "GameFontDisableSmall",
                colour if known else MUTED,
                width=100,
            )
    else:
        mk.text(canvas, px(detail_x + inner), py(y), "Variants", "GameFontNormal", GOLD)
        variant_w = (card_w - 14) / 3
        for index, (title, status, known, colour) in enumerate(variants):
            vx = detail_x + inner + index * (variant_w + 7)
            mk.card(canvas, px(vx), py(y + 14), variant_w, 52, colour if known else wowmock.rgb("3a382f"))
            mk.text(canvas, px(vx + 10), py(y + 21), title, "GameFontNormal", TEXT, width=variant_w - 30)
            if known:
                canvas.draw(ui.atlas("common-icon-checkmark"), px(vx + variant_w - 22), py(y + 21), 12, 12, colour)
            else:
                mk.right(canvas, px(vx + variant_w - 10), py(y + 21), "\u2014", "GameFontNormal", MUTED, width=12)
            mk.text(canvas, px(vx + 10), py(y + 43), status, "GameFontDisableSmall", MUTED, width=variant_w - 18)

    # cosmetic rewards
    y = at("rewards")
    reward_rows = (
        ("Field sketch", "Discovered"),
        ("Ink study", "Observed"),
        ("Brass plate", "Studied"),
        ("Gilded entry", "Mastered"),
    )
    mk.card(canvas, px(detail_x + inner), py(y), card_w, 100 if compact else 66)
    mk.text(canvas, px(detail_x + inner + 10), py(y + 7), "Cosmetic rewards", "GameFontNormal", GOLD)
    if compact:
        for reward_index, (label, tier) in enumerate(reward_rows):
            ly = y + 26 + reward_index * 18
            unlocked = rank >= reward_index + 1
            mk.text(
                canvas,
                px(detail_x + inner + 10),
                py(ly),
                label,
                "GameFontDisableSmall",
                TEXT if unlocked else MUTED,
                width=120,
            )
            if unlocked:
                canvas.draw(ui.atlas("common-icon-checkmark"), px(detail_x + inner + 134), py(ly), 12, 12, GREEN)
            else:
                mk.text(canvas, px(detail_x + inner + 134), py(ly), "\u2014", "GameFontNormal", MUTED, width=12)
            mk.right(
                canvas,
                px(detail_x + inner + card_w - 10),
                py(ly),
                "UNLOCKED" if unlocked else f"Locked \u00b7 {tier}",
                "GameFontDisableSmall",
                GREEN if unlocked else MUTED,
                width=110,
            )
    else:
        half = card_w / 2
        for reward_index, (label, tier) in enumerate(reward_rows):
            column, row_index = reward_index % 2, reward_index // 2
            col_x = detail_x + inner + 10 + (half if column else 0)
            ly = y + 28 + row_index * 20
            unlocked = rank >= reward_index + 1
            mk.text(canvas, px(col_x), py(ly), label, "GameFontDisableSmall", TEXT if unlocked else MUTED, width=110)
            if unlocked:
                canvas.draw(ui.atlas("common-icon-checkmark"), px(col_x + 118), py(ly), 12, 12, GREEN)
            else:
                mk.text(canvas, px(col_x + 118), py(ly), "\u2014", "GameFontNormal", MUTED, width=12)
            mk.right(
                canvas,
                px(col_x + half - 14),
                py(ly),
                "UNLOCKED" if unlocked else f"Locked \u00b7 {tier}",
                "GameFontDisableSmall",
                GREEN if unlocked else MUTED,
                width=92,
            )

    # your records
    y = at("records")
    mk.card(canvas, px(detail_x + inner), py(y), card_w, 60)
    mk.text(canvas, px(detail_x + inner + 10), py(y + 7), "Your records", "GameFontNormal", GOLD)
    stamp = f"{zone['name']} \u00b7 2026-10-22 10:00"
    lines = []
    if state["kills"]:
        lines += [f"Personal first sighting: {stamp}", f"First death observed: {stamp}"]
    if state["rare"]:
        lines.append(f"First rare recorded: {stamp}")
    if state["shiny"]:
        lines.append(f"First shiny recorded: {stamp}")
    for line_index, line in enumerate((lines or ["No sightings yet this session."])[:3]):
        mk.text(
            canvas,
            px(detail_x + inner + 10),
            py(y + 21 + line_index * 12),
            line,
            "GameFontDisableSmall",
            MUTED,
            width=card_w - 20,
        )

    if not compact:
        y = at("footnote")
        mk.text(
            canvas,
            px(detail_x + inner),
            py(y),
            "Cosmetic only \u2014 the field guide never grants player power.",
            "GameFontDisableSmall",
            DIM,
        )
    return catalogued


def bottom_bar(canvas, ui, zone, catalogued, px, py, x, y, w, h):
    """Zone completion and the two actions, on one baseline, buttons inset the same on each side."""
    mk.card(canvas, px(x), py(y), w, h)
    label = "ZONE COMPLETION"
    mk.text(canvas, px(x + 14), py(y + 10), label, "GameFontDisableSmall", MUTED)
    fraction = catalogued / len(zone["species"])
    percent_x = x + 14 + canvas.text_width(label, FONTS["GameFontDisableSmall"]) + 8
    mk.text(canvas, px(percent_x), py(y + 10), f"{round(fraction * 100)}%", "GameFontNormal", GOLD)
    mk.right(
        canvas,
        px(x + 352),
        py(y + 10),
        f"{catalogued} of {len(zone['species'])} species",
        "GameFontDisableSmall",
        MUTED,
        width=140,
    )
    mk.bar(canvas, px(x + 14), py(y + 32), 320, 10, fraction, GREEN)
    ui_panel_button(canvas, px(x + w - 140 - 120), py(y + 16), 120, 26, "Open Journal")
    ui_panel_button(canvas, px(x + w - 12 - 120), py(y + 16), 120, 26, "Track Species")


# ---------------------------------------------------------------------------------------------------- shells
def standalone(ui, zone, species, tab, icons, tab_icons, sigil, side="left", size=60):
    """Option 1: the guide as its own window, square external tabs down one edge."""
    index = TAB_INDEX[tab]
    pad = 84
    right_tab_overhang = size - 8
    canvas = ui.canvas(W + M * 2 + pad + (right_tab_overhang if side == "right" else 0), H + M * 2)

    def px(value):
        return M + pad + value

    def py(value):
        return M + value

    canvas.fill(px(6), py(6), W - 12, H - 12, wowmock.rgb("0b0c0e"))
    # Tabs first, frame second: the metal edge closes over their seam.
    for tab_index, label in enumerate(TABS):
        ty = py(96 + tab_index * (size + 8))
        if side == "left":
            square_tab(canvas, px(-size + 8), ty, size, tab_icons[tab_index], label, tab_index == index, seam="right")
        else:
            square_tab(canvas, px(W - 8), ty, size, tab_icons[tab_index], label, tab_index == index, seam="left")

    portrait_frame_art(canvas, px(0), py(0), W, H, sigil, "FIELD GUIDE")
    mk.text(
        canvas,
        px(58),
        py(20),
        "Azeroth field journal",
        "GameFontDisableSmall",
        MUTED,
        justify="CENTER",
        width=W - 82,
    )

    # Breadcrumb and search take back the band the paper tabs used to occupy.
    breadcrumb = f"{zone['continent']} > {zone['name']}"
    mk.text(canvas, px(24), py(44), breadcrumb, "GameFontNormal", TEXT)
    canvas.draw(
        ui.atlas("common-dropdown-c-button-hover-arrow"),
        px(28) + canvas.text_width(breadcrumb, FONTS["GameFontNormal"]),
        py(46),
        12,
        5,
    )
    search_box(canvas, px(24), py(62), 250, 24, "Search creatures")
    ui_panel_button(canvas, px(288), py(62), 128, 24, "All")
    canvas.draw(ui.atlas("_UI-Frame-InnerTopTile"), px(18), py(94), W - 36, 3)

    box = (18, 104, W - 36, H - 104 - 12 - 58 - 12)
    catalogued = panes(canvas, ui, zone, species, tab, icons, box, px, py)
    bottom_bar(canvas, ui, zone, catalogued, px, py, 18, H - 12 - 58, W - 36, 58)
    return canvas


def map_drawer(ui, zone, species, tab, icons, tab_icons, sigil, drawer_w=700):
    """Option 2: the guide as a sidecar drawer hung off the World Map's right edge."""
    index = TAB_INDEX[tab]
    map_w, map_h, gap = 880, 700, 14
    canvas = ui.canvas(map_w + gap + drawer_w + M * 2 + 80, map_h + M * 2)

    def mx(value):
        return M + value

    def my(value):
        return M + value

    def dx(value):
        return M + map_w + gap + value

    # --- the World Map it attaches to
    canvas.fill(mx(6), my(6), map_w - 12, map_h - 12, wowmock.rgb("0b0c0e"))
    portrait_frame_art(canvas, mx(0), my(0), map_w, map_h, sigil, "WORLD MAP")
    from PIL import Image  # ty: ignore[unresolved-import]

    art = map_art(ui, 1413)
    art_w, art_h = map_w - 60, map_h - 108
    art_logical = (art.width / ui.scale, art.height / ui.scale)
    scale = min(art_w / art_logical[0], art_h / art_logical[1])
    draw_w, draw_h = art_logical[0] * scale, art_logical[1] * scale
    canvas.fill(mx(30), my(66), art_w, art_h, wowmock.rgb("11161a"))
    canvas.composite(
        art.resize((round(draw_w * ui.scale), round(draw_h * ui.scale)), Image.LANCZOS),
        round((mx(30 + (art_w - draw_w) / 2)) * ui.scale),
        round((my(66 + (art_h - draw_h) / 2)) * ui.scale),
    )
    pin_x, pin_y = mx(30) + art_w / 2, my(66) + art_h / 2
    canvas.draw(ui.atlas("common-icon-checkmark"), pin_x - 11, pin_y - 11, 22, 22, GOLD)
    mk.text(canvas, mx(24), my(map_h - 34), f"Tracking: {species['name']}", "GameFontDisableSmall", GOLD)

    # --- the drawer: flat header, no second portrait, square tabs on its outer edge
    for tab_index, label in enumerate(TABS):
        ty = my(96 + tab_index * 68)
        square_tab(canvas, dx(drawer_w - 8), ty, 60, tab_icons[tab_index], label, tab_index == index, seam="left")
    frame_panel(canvas, dx(0), my(0), drawer_w, map_h, "FIELD GUIDE")
    mk.text(canvas, dx(16), my(26), f"{zone['continent']} > {zone['name']}", "GameFontDisableSmall", MUTED)

    search_box(canvas, dx(16), my(44), 200, 24, "Search creatures")
    ui_panel_button(canvas, dx(224), my(44), 96, 24, "All")
    canvas.draw(ui.atlas("_UI-Frame-InnerTopTile"), dx(14), my(76), drawer_w - 28, 3)

    box = (14, 84, drawer_w - 28, map_h - 84 - 12 - 58 - 10)
    catalogued = panes(canvas, ui, zone, species, tab, icons, box, dx, my, compact=True)
    bottom_bar(canvas, ui, zone, catalogued, dx, my, 14, map_h - 12 - 58, drawer_w - 28, 58)
    return canvas


def legacy_subpanel(ui, zone, species, tab, icons, tab_icons, sigil):
    """Option 3: the guide as a square-tabbed sub-panel of a LEGACY-style window."""
    canvas = ui.canvas(W + M * 2, H + M * 2 + 82)

    def px(value):
        return M + value

    def py(value):
        return M + 82 + value

    host = ("Overview", "Dungeons", "Exploration", "Field Guide")
    canvas.fill(px(6), py(6), W - 12, H - 12, wowmock.rgb("0b0c0e"))
    for tab_index, label in enumerate(host):
        square_tab(
            canvas, px(30 + tab_index * 68), py(-60), 60, tab_icons[tab_index], label, tab_index == 3, seam="bottom"
        )

    portrait_frame_art(canvas, px(0), py(0), W, H, sigil, "LEGACY")
    mk.text(
        canvas,
        px(58),
        py(20),
        "Character journal \u00b7 legacy progress",
        "GameFontDisableSmall",
        MUTED,
        justify="CENTER",
        width=W - 82,
    )

    breadcrumb = f"{zone['continent']} > {zone['name']}"
    mk.text(canvas, px(24), py(44), breadcrumb, "GameFontNormal", TEXT)
    canvas.draw(
        ui.atlas("common-dropdown-c-button-hover-arrow"),
        px(28) + canvas.text_width(breadcrumb, FONTS["GameFontNormal"]),
        py(46),
        12,
        5,
    )
    search_box(canvas, px(24), py(62), 250, 24, "Search creatures")
    ui_panel_button(canvas, px(288), py(62), 128, 24, "All")
    canvas.draw(ui.atlas("_UI-Frame-InnerTopTile"), px(18), py(94), W - 36, 3)

    box = (18, 104, W - 36, H - 104 - 12 - 58 - 12)
    catalogued = panes(canvas, ui, zone, species, tab, icons, box, px, py)
    bottom_bar(canvas, ui, zone, catalogued, px, py, 18, H - 12 - 58, W - 36, 58)
    return canvas


def main():
    from PIL import Image  # ty: ignore[unresolved-import]

    ui = wowmock.Ui(scale=2)
    OUT.mkdir(parents=True, exist_ok=True)
    for stale in OUT.glob("*.png"):
        stale.unlink()
    zones = mk.load_catalogue()
    ui.wago.paths.update(mk.MODEL_ICON_IDS)
    by_name = {zone["name"]: zone for zone in zones}
    icons = {species["id"]: ui.texture(mk.species_icon(species)) for zone in zones for species in zone["species"]}
    sigil = ui.texture(mk.SIGIL_ICON)

    barrens = by_name["The Barrens"]
    prowler = barrens["species"][0]
    badlands = by_name["Badlands"]
    golem = next((s for s in badlands["species"] if s["name"] == "Siege Golem"), badlands["species"][0])
    rare = next((s for s in barrens["species"] if s["rare"]), prowler)
    shiny = next((s for s in barrens["species"] if mk.progress(s)["shiny"]), prowler)
    tab_icons = [icons[golem["id"]], icons[rare["id"]], icons[shiny["id"]], sigil]

    def save(canvas, name):
        # 256 shared colours: the map scene carries a 2000 px zone texture, and a full-colour PNG of it is 4 MB.
        # Quantising is deterministic, so a second run is byte-identical, which is what makes these diffable.
        scene = wowmock.scene(ui, [(canvas, 0, 0)])
        rgb = getattr(scene, "image", scene).convert("RGB")
        palette = rgb.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        palette.save(OUT / name, optimize=True)
        print(f"  {name}")

    save(mk.window(ui, badlands, golem, "CREATURES", icons, sigil), "current.png")
    save(standalone(ui, badlands, golem, "CREATURES", icons, tab_icons, sigil, side="left"), "spine-left.png")
    save(standalone(ui, badlands, golem, "CREATURES", icons, tab_icons, sigil, side="right"), "spine-right.png")
    save(map_drawer(ui, barrens, prowler, "CREATURES", icons, tab_icons, sigil), "map-drawer.png")
    save(legacy_subpanel(ui, badlands, golem, "CREATURES", icons, tab_icons, sigil), "legacy-subpanel.png")
    print(f"wrote {len(list(OUT.glob('*.png')))} option renders to {OUT}")


if __name__ == "__main__":
    sys.exit(main())
