#!/usr/bin/env python3
"""Render the addon's journal window from its own data, for the README and the store gallery.

This is a layout renderer: it reads `Data/Creatures.lua` for the catalogue and draws the frame, list and detail
panel with the palette and geometry `UI/Art.lua`, `UI/Window.lua`, `UI/List.lua` and `UI/Detail.lua` use, using
Pillow only (no game client, no browser). Icons are drawn as family-coloured plates with the family's initial,
because the client's own creature portraits live in the game archives and are not part of this repository.

    python3 tools/preview.py

Every image is deterministic: the per-species progress comes from the species id, not from a random source, so a
second run produces byte-identical files.
"""

import re
import sys
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "screenshots"

# UI/Art.lua's palette, as 0-255 tuples.
BG = (11, 12, 14)
PANEL = (33, 36, 41)
PANEL_SOFT = (27, 30, 34)
BORDER = (184, 161, 107)
GOLD = (224, 181, 64)
TEXT = (227, 217, 194)
MUTED = (158, 153, 140)
BLUE = (133, 184, 242)
GREEN = (125, 153, 97)
DIM = (96, 94, 88)

FAMILY_COLOUR = {
    "Beast": (108, 84, 52),
    "Humanoid": (86, 74, 96),
    "Undead": (74, 88, 74),
    "Dragonkin": (96, 68, 60),
    "Elemental": (70, 84, 98),
    "Giant": (92, 88, 72),
    "Mechanical": (78, 86, 92),
    "Critter": (98, 92, 66),
    "Demon": (92, 62, 74),
    "Aberration": (76, 70, 92),
}

W, H = 980, 700
FONTS = Path("/usr/share/fonts/truetype/dejavu")
F_TITLE = ImageFont.truetype(str(FONTS / "DejaVuSerif-Bold.ttf"), 22)
F_H1 = ImageFont.truetype(str(FONTS / "DejaVuSans-Bold.ttf"), 17)
F_H2 = ImageFont.truetype(str(FONTS / "DejaVuSans-Bold.ttf"), 12)
F_BODY = ImageFont.truetype(str(FONTS / "DejaVuSans.ttf"), 12)
F_SMALL = ImageFont.truetype(str(FONTS / "DejaVuSans.ttf"), 10)
F_TINY = ImageFont.truetype(str(FONTS / "DejaVuSans.ttf"), 9)
F_LORE = ImageFont.truetype(str(FONTS / "DejaVuSerif.ttf"), 11)

RANK_NAMES = ("Undiscovered", "Discovered", "Observed", "Studied", "Mastered")
PIPS = ("Discovered", "Observed", "Studied", "Mastered")
MASTERED_AT = 10
RARE_TARGET = 3
SHINY_TARGET = 1


def rank_of(count):
    for step, threshold in enumerate((1, 3, 6, 10)):
        if count >= threshold:
            rank = step + 1
    return 0 if count < 1 else rank


MOB = re.compile(
    r'mob\(\s*(\d+),\s*"([^"]+)",\s*"([^"]+)",\s*(\d+),\s*(\d+),\s*"([^"]+)"(,\s*true)?\s*\)',
    re.S,
)
ZONE = re.compile(r'zone\(\s*"([^"]+)",\s*"([^"]+)",\s*\{')


def load_catalogue():
    """Every zone in Data/Creatures.lua, in the file's own order, with its species."""
    source = (ROOT / "Data" / "Creatures.lua").read_text()
    zones, order = {}, []
    for match in ZONE.finditer(source):
        name = match.group(1)
        zones[name] = {"name": name, "continent": match.group(2), "species": []}
        order.append(name)
    spans = [(m.start(), m.group(1)) for m in ZONE.finditer(source)]
    for index, (start, name) in enumerate(spans):
        end = spans[index + 1][0] if index + 1 < len(spans) else len(source)
        for mob in MOB.finditer(source[start:end]):
            zones[name]["species"].append(
                {
                    "id": int(mob.group(1)),
                    "name": mob.group(2),
                    "family": mob.group(3),
                    "min": int(mob.group(4)),
                    "max": int(mob.group(5)),
                    "lore": mob.group(6),
                    "rare": mob.group(7) is not None,
                }
            )
    return [zones[name] for name in order]


def progress(species):
    """A plausible saved character: some mastered, some part-way, a few untouched. Deterministic in the id."""
    seed = (species["id"] * 2654435761) % 4294967296
    count = (seed >> 7) % 11
    return {
        "count": count,
        "rare": min(RARE_TARGET, (seed >> 11) % (RARE_TARGET + 1)),
        "shiny": 1 if (seed >> 13) % 23 == 0 else 0,
    }


def icon(draw, box, family, glyph=None):
    x, y, size = box
    colour = FAMILY_COLOUR.get(family, (80, 80, 80))
    draw.rounded_rectangle((x, y, x + size, y + size), radius=3, fill=colour, outline=BORDER, width=1)
    letter = (glyph or family[:1]).upper()
    font = ImageFont.truetype(str(FONTS / "DejaVuSans-Bold.ttf"), max(9, int(size * 0.42)))
    draw.text((x + size / 2, y + size / 2 + 1), letter, font=font, fill=TEXT, anchor="mm")


def bar(draw, x, y, width, height, fraction, colour, trough=(48, 50, 54)):
    fraction = max(0.0, min(1.0, fraction))
    draw.rounded_rectangle((x, y, x + width, y + height), radius=height / 2, fill=trough)
    filled = int(width * fraction)
    if filled > 0:
        draw.rounded_rectangle((x, y, x + max(height, filled), y + height), radius=height / 2, fill=colour)


def label(draw, x, y, text, font, colour, anchor="la"):
    draw.text((x, y), text, font=font, fill=colour, anchor=anchor)


def frame(draw):
    draw.rounded_rectangle((6, 6, W - 6, H - 6), radius=10, outline=BORDER, width=2, fill=BG)
    draw.rounded_rectangle((14, 14, W - 14, H - 14), radius=8, outline=(72, 66, 52), width=1)
    for cx, cy in ((14, 14), (W - 14, 14), (14, H - 14), (W - 14, H - 14)):
        draw.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=GOLD)
    label(draw, 34, 24, "BESTIARY", F_TITLE, GOLD)
    draw.ellipse((W - 96, 22, W - 56, 62), outline=BORDER, width=2, fill=PANEL_SOFT)
    draw.ellipse((W - 89, 29, W - 63, 55), outline=(72, 66, 52), width=1)
    icon(draw, (W - 85, 33, 22), "Beast", "🐾")


def tabs(draw, active, zone):
    x = 34
    for name in ("BESTIARY", "RARES", "SHINY"):
        colour = GOLD if name == active else MUTED
        label(draw, x + 14, 66, name, F_H2, colour)
        dot = GOLD if name == active else (70, 70, 72)
        draw.ellipse((x + 2, 69, x + 8, 75), fill=dot)
        if name == active:
            draw.line((x, 84, x + 14 + draw.textlength(name, font=F_H2), 84), fill=GOLD, width=2)
        x += 30 + draw.textlength(name, font=F_H2)
    label(draw, W - 210, 62, zone["continent"].upper(), F_TINY, MUTED)
    label(draw, W - 210, 74, zone["name"], F_BODY, TEXT)
    label(draw, W - 40, 68, "\u25be", F_BODY, MUTED)
    draw.line((34, 92, W - 34, 92), fill=(64, 60, 50), width=1)


def left_panel(draw, zone, selected, tab):
    species = zone["species"]
    draw.rounded_rectangle((30, 104, 350, 132), radius=5, outline=(64, 60, 52), width=1, fill=PANEL_SOFT)
    draw.ellipse((40, 112, 50, 122), outline=MUTED, width=1)
    label(draw, 58, 111, "Search creatures", F_SMALL, DIM)
    draw.rounded_rectangle((358, 104, 436, 132), radius=5, outline=(64, 60, 52), width=1, fill=PANEL_SOFT)
    label(draw, 366, 111, "All", F_SMALL, TEXT)
    label(draw, 420, 111, "\u25be", F_TINY, MUTED)

    rows = species
    if tab == "RARES":
        rows = [s for s in species if s["rare"] or progress(s)["rare"]]
    elif tab == "SHINY":
        rows = [s for s in species if progress(s)["shiny"]]

    catalogued = sum(1 for s in species if progress(s)["count"] > 0)
    label(draw, 34, 144, "Creatures of the %s" % zone["name"], F_H1, TEXT)
    label(draw, 350, 148, "%d / %d catalogued" % (catalogued, len(species)), F_TINY, MUTED, anchor="ra")
    bar(draw, 34, 170, 402, 5, catalogued / len(species), GOLD)

    y = 188
    for row in rows[:9]:
        state = progress(row)
        chosen = row["id"] == selected["id"]
        if chosen:
            draw.rounded_rectangle((30, y - 4, 436, y + 34), radius=4, fill=(46, 44, 38), outline=(96, 86, 60), width=1)
        icon(draw, (38, y, 28), row["family"])
        colour = BLUE if row["rare"] and state["rare"] >= RARE_TARGET else TEXT
        label(draw, 74, y - 1, row["name"][:26], F_BODY, colour)
        label(draw, 74, y + 15, "%s \u00b7 Lv %d\u2013%d" % (row["family"], row["min"], row["max"]), F_TINY, MUTED)
        count = state["count"]
        glyph = "\u2726" if count >= MASTERED_AT else ("\u2713" if count >= 6 else "")
        glyph_colour = GOLD if count >= MASTERED_AT else GREEN
        label(draw, 428, y + 2, glyph, F_BODY, glyph_colour, anchor="ra")
        label(draw, 428, y + 18, "%d/10" % count, F_TINY, MUTED, anchor="ra")
        bar(draw, 344, y + 22, 60, 3, count / MASTERED_AT, BLUE if count < MASTERED_AT else GREEN)
        y += 42
    return rows


def right_panel(draw, zone, species, tab):
    state = progress(species)
    count = state["count"]
    rank = rank_of(count)
    draw.rounded_rectangle((450, 104, W - 30, 116 + 470), radius=6, fill=PANEL_SOFT, outline=(58, 55, 48), width=1)

    draw.ellipse((470, 120, 534, 184), outline=BORDER, width=2, fill=FAMILY_COLOUR.get(species["family"], PANEL))
    icon(draw, (492, 142, 20), species["family"])
    label(draw, 548, 122, species["name"], F_H1, TEXT)
    label(
        draw,
        548,
        146,
        "%s \u00b7 %s \u00b7 Level %d\u2013%d" % (species["family"], zone["name"], species["min"], species["max"]),
        F_SMALL,
        MUTED,
    )

    badges = [("Common", MUTED)]
    if species["rare"]:
        badges.append(("\u2605 Rare variant known" if state["rare"] >= RARE_TARGET else "\u2605 Rare", BLUE))
    if state["shiny"]:
        badges.append(("\u2726 Shiny seen", GOLD))
    x = 548
    for text, colour in badges:
        width = draw.textlength(text, font=F_TINY) + 16
        draw.rounded_rectangle((x, 168, x + width, 186), radius=4, outline=colour, width=1)
        label(draw, x + 8, 171, text, F_TINY, colour)
        x += width + 6

    # Research card
    draw.rounded_rectangle((470, 202, W - 50, 300), radius=5, fill=PANEL, outline=(64, 60, 52), width=1)
    label(draw, 482, 210, "Research", F_H2, TEXT)
    label(draw, W - 62, 211, "Rank %s \u2014 %s" % ("I", RANK_NAMES[rank]) if rank else "Not yet discovered", F_TINY, GOLD, "ra")
    px = 492
    for index, name in enumerate(PIPS):
        on = rank >= index + 1
        draw.ellipse((px - 6, 240 - 6, px + 6, 240 + 6), fill=GOLD if on else (56, 56, 58), outline=BORDER, width=1)
        label(draw, px - 8, 254, name, F_TINY, TEXT if on else DIM, "ma")
        if index < len(PIPS) - 1:
            draw.line((px + 8, 240, px + 66, 240), fill=GOLD if rank >= index + 2 else (56, 56, 58), width=2)
        px += 74
    label(draw, 482, 272, "Specimens", F_TINY, MUTED)
    bar(draw, 546, 273, 240, 5, count / MASTERED_AT, GOLD)
    label(draw, W - 62, 268, "%d / 10" % count, F_TINY, TEXT, "ra")

    # Lore
    for index, line in enumerate(textwrap.wrap(species["lore"], 74)[:4]):
        label(draw, 470, 314 + index * 15, ('"' if index == 0 else "") + line, F_LORE, (196, 186, 164))

    # Variants
    label(draw, 470, 380, "Variants", F_H2, TEXT)
    recorded = 1 + (1 if state["rare"] >= RARE_TARGET else 0) + (1 if state["shiny"] else 0)
    label(draw, W - 62, 380, "%d of 3 recorded" % recorded, F_TINY, MUTED, "ra")
    cards = [
        ("Common", "Catalogued", True, TEXT),
        ("Rare sighting", "%d of %d" % (state["rare"], RARE_TARGET), state["rare"] >= RARE_TARGET, BLUE),
        ("Shiny", "%d of %d" % (state["shiny"], SHINY_TARGET), state["shiny"] >= SHINY_TARGET, GOLD),
    ]
    for index, (title, sub, known, colour) in enumerate(cards):
        x = 470 + index * 150
        draw.rounded_rectangle((x, 398, x + 140, 462), radius=5, outline=colour if known else (58, 55, 48), width=1, fill=PANEL)
        icon(draw, (x + 8, 408, 26), species["family"])
        label(draw, x + 42, 406, title, F_SMALL, colour if known else DIM)
        label(draw, x + 42, 420, sub, F_TINY, MUTED)
        label(draw, x + 42, 436, "Recorded" if known else "Not seen", F_TINY, colour if known else DIM)

    # Rewards
    label(draw, 470, 478, "Cosmetic rewards", F_H2, TEXT)
    label(draw, W - 62, 478, "Journal unlocks", F_TINY, MUTED, "ra")
    rewards = [
        ("Portrait frame", "%s fauna" % zone["name"], "UNLOCKED" if rank >= 3 else "RANK III", rank >= 3),
        ("Title", "%s watcher" % zone["name"].split()[-1], "UNLOCKED" if rank >= 4 else "RANK IV", rank >= 4),
        ("Journal skin", "Dustbound", "UNLOCKED" if count >= 8 else "%d / 8" % count, count >= 8),
    ]
    y = 496
    for title, sub, status, open_ in rewards:
        draw.rounded_rectangle((470, y, W - 50, y + 22), radius=4, fill=PANEL)
        label(draw, 480, y + 5, "\u25a3", F_SMALL, GOLD)
        label(draw, 500, y + 5, title, F_SMALL, TEXT)
        label(draw, 500 + draw.textlength(title, font=F_SMALL) + 6, y + 6, sub, F_TINY, MUTED)
        label(draw, W - 62, y + 6, status, F_TINY, GREEN if open_ else DIM, "ra")
        y += 26

    label(draw, 470, 588, "Cosmetic only \u2014 the bestiary never grants player power.", F_TINY, DIM)


def bottom(draw, zone):
    species = zone["species"]
    catalogued = sum(1 for s in species if progress(s)["count"] > 0)
    mastered = sum(1 for s in species if progress(s)["count"] >= MASTERED_AT)
    fraction = catalogued / len(species)
    draw.line((30, 632, W - 30, 632), fill=(64, 60, 52), width=1)
    label(draw, 34, 640, "ZONE COMPLETION", F_TINY, MUTED)
    label(draw, 34, 652, "%d%%" % round(fraction * 100), F_H2, GOLD)
    bar(draw, 108, 654, 250, 6, fraction, GOLD)
    label(draw, 370, 650, "%d of %d species \u00b7 %d mastered" % (catalogued, len(species), mastered), F_TINY, MUTED)
    draw.rounded_rectangle((W - 260, 646, W - 150, 674), radius=5, outline=BORDER, width=1)
    label(draw, W - 205, 653, "Open Journal", F_SMALL, TEXT, "ma")
    draw.rounded_rectangle((W - 140, 646, W - 30, 674), radius=5, fill=(150, 120, 48), outline=GOLD, width=1)
    label(draw, W - 85, 653, "Track Species", F_SMALL, (18, 15, 10), "ma")


def render(zone, species, tab="BESTIARY"):
    image = Image.new("RGB", (W, H), (7, 8, 9))
    draw = ImageDraw.Draw(image)
    frame(draw)
    tabs(draw, tab, zone)
    left_panel(draw, zone, species, tab)
    right_panel(draw, zone, species, tab)
    bottom(draw, zone)
    return image


def main():
    zones = load_catalogue()
    OUT.mkdir(parents=True, exist_ok=True)
    by_name = {zone["name"]: zone for zone in zones}

    def pick(zone_name, matcher):
        zone = by_name[zone_name]
        for species in zone["species"]:
            if matcher(species):
                return zone, species
        return zone, zone["species"][0]

    barrens = by_name["The Barrens"]
    prowler = next(s for s in barrens["species"] if "Prowler" in s["name"])
    render(barrens, prowler, "BESTIARY").save(OUT / "bestiary.png")

    rare_zone, rare = pick("The Barrens", lambda s: s["rare"])
    render(rare_zone, rare, "RARES").save(OUT / "rares.png")

    shiny_zone, shiny = pick(
        "The Barrens", lambda s: progress(s)["shiny"] or (progress(s)["count"] >= 6 and not s["rare"])
    )
    render(shiny_zone, shiny, "SHINY").save(OUT / "shiny.png")

    examples = [
        ("The Barrens", lambda s: s["name"] == "Savannah Prowler"),
        ("Durotar", lambda s: not s["rare"]),
        ("Mulgore", lambda s: not s["rare"]),
        ("Teldrassil", lambda s: True),
        ("Elwynn Forest", lambda s: not s["rare"]),
        ("Westfall", lambda s: True),
        ("Redridge Mountains", lambda s: not s["rare"]),
        ("Loch Modan", lambda s: True),
        ("Tirisfal Glades", lambda s: not s["rare"]),
        ("Silverpine Forest", lambda s: True),
    ]
    frames = []
    for index, (zone_name, matcher) in enumerate(examples, start=1):
        zone, species = pick(zone_name, matcher)
        image = render(zone, species, "BESTIARY")
        image.save(OUT / ("creature-%02d.png" % index))
        if index <= 4:
            frames.append(image)

    # The demo animates the three tabs and two selections, so it shows the pages rather than one still repeated.
    demo = [
        render(barrens, prowler, "BESTIARY"),
        render(barrens, prowler, "BESTIARY"),
        render(rare_zone, rare, "RARES"),
        render(rare_zone, rare, "RARES"),
        render(shiny_zone, shiny, "SHINY"),
        render(shiny_zone, shiny, "SHINY"),
        render(*pick("Teldrassil", lambda s: True), "BESTIARY"),
        render(*pick("Westfall", lambda s: True), "BESTIARY"),
        render(barrens, prowler, "BESTIARY"),
    ]
    palette_frames = [frame.quantize(colors=128, method=Image.Quantize.MEDIANCUT) for frame in demo]
    palette_frames[0].save(
        OUT / "demo.gif",
        save_all=True,
        append_images=palette_frames[1:],
        duration=900,
        loop=0,
        optimize=True,
    )
    print("wrote %d images to %s" % (len(list(OUT.glob("*.png"))) + 1, OUT))


if __name__ == "__main__":
    sys.exit(main())
