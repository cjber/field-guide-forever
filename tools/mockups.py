#!/usr/bin/env python3
"""Mock screenshots of the Bestiary journal drawn with the client's own art (wowmock).

Every pixel that is not the addon's own layout comes from the WoW: Forever client build (nine-slice dialog border,
panel tabs, buttons, atlas gems, FRIZQT fonts, spell icons), fetched once from wago.tools and cached under
`tools/.cache/wowmock/`. This is a mock, not a capture: the frame is drawn the way UI/Window.lua draws it, at the
window's logical size, on wowmock's plain backdrop.

    python3 tools/mockups.py

Deterministic: the specimen counts come from the species id, so a second run is byte-identical.
"""

import sys
import textwrap
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "wowmock"))
import wowmock  # noqa: E402
from wowmock import FONTS, close_button, dialog_border, panel_tabs, tooltip_backdrop, ui_panel_button  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "screenshots"

# UI/Art.lua's palette, as wowmock colour tuples.
GOLD = wowmock.rgb("e0b540")
BRASS = wowmock.rgb("b8a16b")
TEXT = wowmock.rgb("e3d9c2")
MUTED = wowmock.rgb("9e998c")
BLUE = wowmock.rgb("85b8f2")
GREEN = wowmock.rgb("7d9961")
DIM = wowmock.rgb("605e58")
DARK = wowmock.rgb("1b1e22")
TROUGH = wowmock.rgb("303236")
PANEL = wowmock.rgb("212429")

W, H = 700, 480
MASTERED_AT, RARE_TARGET, SHINY_TARGET = 10, 3, 1
RANK_NAMES = ("Undiscovered", "Discovered", "Observed", "Studied", "Mastered")
PIPS = ("Discovered", "Observed", "Studied", "Mastered")


def rank_of(count):
    rank = 0
    for step, threshold in enumerate((1, 3, 6, 10)):
        if count >= threshold:
            rank = step + 1
    return rank


# One client icon per family; resolved against the pinned build and cached. The catalogue has no portraits of its
# own, and NPC portraits are not textures, so a family sigil is what the addon uses in the list and the detail head.
ICONS = {
    "Beast": "interface/icons/ability_hunter_beasttaming.blp",
    "Humanoid": "interface/icons/inv_misc_head_human_01.blp",
    "Undead": "interface/icons/spell_shadow_raisedead.blp",
    "Dragonkin": "interface/icons/inv_misc_head_dragon_01.blp",
    "Elemental": "interface/icons/spell_nature_lightning.blp",
    "Giant": "interface/icons/ability_warrior_savageblow.blp",
    "Mechanical": "interface/icons/inv_misc_gear_01.blp",
    "Critter": "interface/icons/inv_misc_food_23.blp",
    "Demon": "interface/icons/spell_shadow_metamorphosis.blp",
    "Aberration": "interface/icons/ability_creature_poison_01.blp",
}
FALLBACK_ICON = "interface/icons/inv_misc_bone_01.blp"
# A second pool, so two species of the same family are not the same picture in the list: real client spell icons,
# picked by species id rather than by hand so the choice is stable between runs.
POOL = (
    "interface/icons/ability_hunter_beasttaming.blp",
    "interface/icons/ability_creature_poison_01.blp",
    "interface/icons/spell_nature_lightning.blp",
    "interface/icons/inv_misc_head_human_01.blp",
    "interface/icons/spell_shadow_raisedead.blp",
    "interface/icons/inv_misc_head_dragon_01.blp",
    "interface/icons/ability_warrior_savageblow.blp",
    "interface/icons/inv_misc_gear_01.blp",
    "interface/icons/inv_misc_food_23.blp",
    "interface/icons/spell_shadow_metamorphosis.blp",
    "interface/icons/spell_nature_thorns.blp",
    "interface/icons/inv_misc_pelt_wolf_01.blp",
    "interface/icons/ability_rogue_sinisterstrike.blp",
    "interface/icons/spell_fire_firebolt.blp",
    "interface/icons/spell_frost_frostbolt02.blp",
    "interface/icons/inv_misc_bone_01.blp",
)
SIGIL_ICON = "interface/icons/inv_misc_book_06.blp"


def load_catalogue():
    """The zones and species Data/Creatures.lua defines, read by parsing the file (no Lua interpreter needed)."""
    import re

    source = (ROOT / "Data" / "Creatures.lua").read_text()
    zone_re = re.compile(r'zone\(\s*"([^"]+)",\s*"([^"]+)",\s*\{')
    mob_re = re.compile(
        r'mob\(\s*(\d+),\s*"([^"]+)",\s*"([^"]+)",\s*(\d+),\s*(\d+),\s*"([^"]+)"(,\s*true)?\s*\)',
        re.S,
    )
    spans = [(m.start(), m.group(1), m.group(2)) for m in zone_re.finditer(source)]
    zones = []
    for index, (start, name, continent) in enumerate(spans):
        end = spans[index + 1][0] if index + 1 < len(spans) else len(source)
        species = []
        for mob in mob_re.finditer(source[start:end]):
            species.append(
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
        zones.append({"name": name, "continent": continent, "species": species})
    return zones


def progress(species):
    """A plausible saved character, deterministic in the id: mastered, part-way and untouched species."""
    seed = (species["id"] * 2654435761) % 4294967296
    return {
        "count": (seed >> 7) % 11,
        "rare": min(RARE_TARGET, (seed >> 11) % (RARE_TARGET + 1)),
        "shiny": 1 if (seed >> 13) % 23 == 0 else 0,
    }


def bar(canvas, x, y, w, h, fraction, colour):
    canvas.fill(x, y, w, h, TROUGH)
    filled = max(0, min(w, round(w * fraction)))
    if filled:
        canvas.fill(x, y, filled, h, colour)


def card(canvas, x, y, w, h, border=BRASS):
    """A small inset: the addon's own panel colour with a one-unit brass edge. Kept off tooltip_backdrop, whose
    12-unit corners need more room than a badge or a search field has."""
    canvas.fill(x, y, w, h, wowmock.rgb("171a1e"))
    canvas.fill(x, y, w, 1, border)
    canvas.fill(x, y + h - 1, w, 1, border)
    canvas.fill(x, y, 1, h, border)
    canvas.fill(x + w - 1, y, 1, h, border)


def panel(canvas, x, y, w, h):
    """The detail panel: BackdropTemplate's tooltip backdrop, the client's own inset frame art."""
    tooltip_backdrop(canvas, x, y, w, h, background=(0.08, 0.09, 0.10, 0.95), border=(0.45, 0.40, 0.30, 1))


def text(canvas, x, y, value, font, colour=TEXT, **kwargs):
    canvas.text(x, y, value, FONTS[font], colour, **kwargs)


def right(canvas, right_edge, y, value, font, colour=TEXT, width=120):
    """Text right-aligned to `right_edge`: canvas.text grows rightward from x, so hand it the box to fill."""
    canvas.text(right_edge - width, y, value, FONTS[font], colour, justify="RIGHT", width=width)


def diamond(canvas, cx, cy, size, colour):
    """FRIZQT has no diamond or star, and the client draws status marks with art, so these are built from fills."""
    half = size / 2
    for row in range(size):
        inset = abs(row - half + 0.5)
        canvas.fill(cx - (half - inset), cy - half + row, max(1, (half - inset) * 2), 1, colour)


def triangle(canvas, x, y, width, colour):
    """A dropdown arrow, drawn as stepped rows because the font has no solid triangle."""
    for row in range(max(2, width // 2)):
        canvas.fill(x + row, y + row, max(1, width - 2 * row), 1, colour)


def window(ui, zone, species, tab, icons, sigil):
    canvas = ui.canvas(W, H)
    dialog_border(canvas, 0, 0, W, H, background=(0.043, 0.047, 0.055, 0.94))
    close_button(canvas, W - 6, 6)

    # Title bar: the journal's sigil, its name, and the character whose journal this is.
    canvas.draw(sigil, 26, 12, 18, 18)
    text(canvas, 50, 12, "BESTIARY", "GameFontNormalLarge", GOLD)
    text(canvas, 50, 30, "Field journal of Tester, TestRealm", "GameFontDisableSmall", MUTED)
    right(
        canvas,
        W - 44,
        30,
        f"{TOTAL_SPECIES} species \u00b7 {TOTAL_ZONES} zones",
        "GameFontDisableSmall",
        MUTED,
        width=180,
    )

    index = ("BESTIARY", "RARES", "SHINY").index(tab)
    panel_tabs(canvas, 26, 46, ["Bestiary", "Rares", "Shiny"], selected=index)

    # Breadcrumb and the search/filter row.
    text(canvas, 26, 78, zone["continent"].upper(), "GameFontDisableSmall", MUTED)
    text(canvas, 26, 88, zone["name"], "GameFontNormal", TEXT)
    triangle(canvas, 30 + canvas.text_width(zone["name"], FONTS["GameFontNormal"]), 94, 7, MUTED)

    card(canvas, 236, 78, 198, 20)
    text(canvas, 244, 82, "Search creatures", "GameFontDisableSmall", DIM)
    card(canvas, 442, 78, 66, 20)
    text(canvas, 450, 82, "All", "GameFontNormalSmall", TEXT)
    triangle(canvas, 488, 87, 7, MUTED)

    catalogued = sum(1 for s in zone["species"] if progress(s)["count"])
    right(
        canvas,
        W - 40,
        82,
        f"{catalogued} / {len(zone['species'])} catalogued",
        "GameFontDisableSmall",
        MUTED,
        width=150,
    )

    rows = zone["species"]
    if tab == "RARES":
        rows = [s for s in rows if s["rare"] or progress(s)["rare"] >= RARE_TARGET]
    elif tab == "SHINY":
        rows = [s for s in rows if progress(s)["shiny"]]
    rows = rows or zone["species"]

    # Left list: eight rows, then the session log under them.
    y = 110
    for row in rows[:7]:
        state = progress(row)
        chosen = row["id"] == species["id"]
        if chosen:
            canvas.fill(22, y - 2, 308, 34, wowmock.rgb("2e2c26"))
            canvas.fill(22, y - 2, 2, 34, GOLD)
        canvas.draw(icons[row["id"]], 30, y + 2, 24, 24)
        known = row["rare"] and state["rare"] >= RARE_TARGET
        text(canvas, 60, y, row["name"][:24], "GameFontNormalSmall", BLUE if known else TEXT)
        text(
            canvas,
            60,
            y + 13,
            f"{row['family']} \u00b7 Lv {row['min']}\u2013{row['max']}",
            "GameFontDisableSmall",
            MUTED,
        )
        right(canvas, 330, y + 1, f"{state['count']}/10", "GameFontDisableSmall", MUTED, width=34)
        bar(canvas, 60, y + 26, 108, 3, state["count"] / MASTERED_AT, GREEN if state["count"] >= 6 else BLUE)
        if state["count"] >= MASTERED_AT:
            diamond(canvas, 282, y + 12, 7, GOLD)
        elif state["count"] >= 6:
            canvas.draw(ui.atlas("common-icon-checkmark"), 276, y + 6, 11, 11, GREEN)
        y += 34

    text(canvas, 26, 352, "Sighting log", "GameFontNormalSmall", TEXT)
    text(canvas, 120, 353, "this session", "GameFontDisableSmall", DIM)
    sightings = [
        ("{} \u2014 killed".format(species["name"]), TEXT),
        ("Dishu \u2014 rare sighting", BLUE),
        ("Plainstrider \u2014 shiny", GOLD),
    ]
    for line_index, (line, colour) in enumerate(sightings):
        diamond(canvas, 30, 368 + line_index * 12, 3, colour)
        text(canvas, 38, 364 + line_index * 12, line, "GameFontDisableSmall", colour)

    # Right detail panel.
    state = progress(species)
    count = state["count"]
    rank = rank_of(count)
    panel(canvas, 340, 104, W - 364, 326)

    canvas.draw(icons[species["id"]], 350, 112, 48, 48)
    text(canvas, 406, 110, species["name"], "GameFontNormalLarge", GOLD)
    text(
        canvas,
        406,
        128,
        f"{species['family']} \u00b7 {zone['name']} \u00b7 Level {species['min']}\u2013{species['max']}",
        "GameFontDisableSmall",
        MUTED,
    )

    badges = ["Common"]
    if species["rare"]:
        badges.append("Rare variant known" if state["rare"] >= RARE_TARGET else "Rare")
    if state["shiny"]:
        badges.append("Shiny seen")
    bx = 406
    for badge in badges:
        width = canvas.text_width(badge, FONTS["GameFontDisableSmall"]) + 12
        card(canvas, bx, 144, width, 14, BRASS if badge == "Common" else (BLUE if "Rare" in badge else GOLD))
        text(
            canvas,
            bx + 6,
            145,
            badge,
            "GameFontDisableSmall",
            MUTED if badge == "Common" else (BLUE if "Rare" in badge else GOLD),
        )
        bx += width + 4

    # Research card: four pips joined by connectors, then the specimens bar.
    text(canvas, 350, 170, "Research", "GameFontNormalSmall", TEXT)
    right(
        canvas,
        W - 40,
        172,
        ("Rank {} \u2014 {}".format("I", RANK_NAMES[rank])) if rank else "Not yet discovered",
        "GameFontDisableSmall",
        GOLD,
        width=170,
    )
    px = 358
    for pip_index, name in enumerate(PIPS):
        on = rank >= pip_index + 1
        diamond(canvas, px, 190, 8, GOLD if on else TROUGH)
        if pip_index < len(PIPS) - 1:
            canvas.fill(px + 6, 189, 50, 1, GOLD if rank >= pip_index + 2 else TROUGH)
        text(canvas, px - 8, 198, name, "GameFontDisableSmall", TEXT if on else DIM)
        px += 62

    text(canvas, 350, 216, "Specimens", "GameFontDisableSmall", MUTED)
    bar(canvas, 412, 219, 150, 4, count / MASTERED_AT, GOLD)
    right(canvas, W - 40, 213, f"{count} / 10", "GameFontNormalSmall", TEXT, width=60)

    # Lore, then the three variant cards.
    for line_index, line in enumerate(textwrap.wrap(species["lore"], 58)[:3]):
        text(
            canvas,
            350,
            232 + line_index * 12,
            ('"' if line_index == 0 else "") + line,
            "GameFontNormalSmall",
            wowmock.rgb("c4baa4"),
        )
    text(canvas, 350, 266, "Variants", "GameFontNormalSmall", TEXT)
    recorded = 1 + (state["rare"] >= RARE_TARGET) + bool(state["shiny"])
    right(canvas, W - 40, 268, f"{recorded} of 3 recorded", "GameFontDisableSmall", MUTED, width=120)
    variants = [
        ("Common", "Catalogued", True, TEXT),
        ("Rare sighting", f"{state['rare']} of {RARE_TARGET}", state["rare"] >= RARE_TARGET, BLUE),
        ("Shiny", f"{state['shiny']} of {SHINY_TARGET}", state["shiny"] >= SHINY_TARGET, GOLD),
    ]
    for variant_index, (title, sub, known, colour) in enumerate(variants):
        vx = 350 + variant_index * 106
        card(canvas, vx, 282, 100, 42, colour if known else wowmock.rgb("3a382f"))
        canvas.draw(icons[species["id"]], vx + 6, 288, 18, 18, colour if known else (0.5, 0.5, 0.5, 1))
        text(canvas, vx + 30, 286, title, "GameFontNormalSmall", colour if known else DIM)
        text(canvas, vx + 30, 298, sub, "GameFontDisableSmall", MUTED)
        text(canvas, vx + 30, 310, "Recorded" if known else "Not seen", "GameFontDisableSmall", GREEN if known else DIM)

    # Rewards, then the corner note.
    text(canvas, 350, 332, "Cosmetic rewards", "GameFontNormalSmall", TEXT)
    right(canvas, W - 40, 334, "journal unlocks", "GameFontDisableSmall", DIM, width=120)
    rewards = [
        ("Portrait frame", "UNLOCKED" if rank >= 3 else "RANK III", rank >= 3),
        ("Title: {} watcher".format(zone["name"].split()[-1]), "UNLOCKED" if rank >= 4 else "RANK IV", rank >= 4),
        ("Journal skin", "UNLOCKED" if count >= 8 else f"{count} / 8", count >= 8),
    ]
    for reward_index, (title, status, open_) in enumerate(rewards):
        ry = 346 + reward_index * 14
        canvas.fill(350, ry, W - 388, 12, wowmock.rgb("1c1f23"))
        diamond(canvas, 356, ry + 6, 5, GOLD if open_ else TROUGH)
        text(canvas, 364, ry, title, "GameFontDisableSmall", TEXT if open_ else MUTED)
        right(canvas, W - 44, ry, status, "GameFontDisableSmall", GREEN if open_ else DIM, width=80)

    text(canvas, 350, 396, "Cosmetic only \u2014 the bestiary never grants player power.", "GameFontDisableSmall", DIM)

    # Bottom bar: zone completion and the two buttons.
    canvas.fill(20, 430, W - 44, 1, wowmock.rgb("403a2e"))
    text(canvas, 26, 434, "ZONE COMPLETION", "GameFontDisableSmall", MUTED)
    fraction = catalogued / len(zone["species"])
    text(canvas, 26, 445, f"{round(fraction * 100)}%", "GameFontNormalSmall", GOLD)
    bar(canvas, 70, 449, 150, 5, fraction, GOLD)
    text(canvas, 232, 445, f"{catalogued} of {len(zone['species'])} species", "GameFontDisableSmall", MUTED)
    ui_panel_button(canvas, W - 244, 442, 98, 20, "Open Journal", FONTS["GameFontNormalSmall"])
    ui_panel_button(canvas, W - 138, 442, 102, 20, "Track Species", FONTS["GameFontNormalSmall"])
    return canvas


def main():
    ui = wowmock.Ui(scale=2)
    OUT.mkdir(parents=True, exist_ok=True)
    zones = load_catalogue()
    by_name = {zone["name"]: zone for zone in zones}
    global TOTAL_SPECIES, TOTAL_ZONES
    TOTAL_SPECIES = sum(len(zone["species"]) for zone in zones)
    TOTAL_ZONES = len(zones)

    # One client icon per species, from the pool, so two beasts in a row are not the same picture.
    icons = {}
    textures = {}
    for path in POOL:
        try:
            textures[path] = ui.texture(path)
        except KeyError:
            continue
    if not textures:
        textures[FALLBACK_ICON] = ui.texture(FALLBACK_ICON)
    pool = sorted(textures)
    for zone in zones:
        for species in zone["species"]:
            icons[species["id"]] = textures[pool[(species["id"] * 7 + len(species["family"])) % len(pool)]]
    sigil = ui.texture(SIGIL_ICON)

    def pick(zone_name, matcher):
        zone = by_name[zone_name]
        for species in zone["species"]:
            if matcher(species):
                return zone, species
        return zone, zone["species"][0]

    barrens = by_name["The Barrens"]
    prowler = next(s for s in barrens["species"] if "Prowler" in s["name"])
    rare_zone, rare = pick("The Barrens", lambda s: s["rare"])
    shiny_zone, shiny = pick(
        "The Barrens", lambda s: progress(s)["shiny"] or (progress(s)["count"] >= 6 and not s["rare"])
    )

    def render(zone, species, tab="BESTIARY"):
        return wowmock.scene(ui, [(window(ui, zone, species, tab, icons, sigil), 0, 0)])

    render(barrens, prowler, "BESTIARY").save(OUT / "bestiary.png")
    render(rare_zone, rare, "RARES").save(OUT / "rares.png")
    render(shiny_zone, shiny, "SHINY").save(OUT / "shiny.png")

    examples = [
        ("The Barrens", lambda s: "Prowler" in s["name"]),
        ("Durotar", lambda s: not s["rare"]),
        ("Mulgore", lambda s: s["rare"]),
        ("Teldrassil", lambda s: not s["rare"]),
        ("Elwynn Forest", lambda s: not s["rare"]),
        ("Westfall", lambda s: s["rare"]),
        ("Redridge Mountains", lambda s: not s["rare"]),
        ("Loch Modan", lambda s: not s["rare"]),
        ("Tirisfal Glades", lambda s: s["rare"]),
        ("Silverpine Forest", lambda s: not s["rare"]),
    ]
    for index, (zone_name, matcher) in enumerate(examples, start=1):
        zone, species = pick(zone_name, matcher)
        render(zone, species, "BESTIARY").save(OUT / (f"creature-{index:02d}.png"))

    demo = [
        render(barrens, prowler, "BESTIARY"),
        render(barrens, prowler, "RARES"),
        render(rare_zone, rare, "RARES"),
        render(rare_zone, rare, "SHINY"),
        render(shiny_zone, shiny, "SHINY"),
        render(*pick("Teldrassil", lambda s: not s["rare"]), "BESTIARY"),
        render(*pick("Westfall", lambda s: s["rare"]), "BESTIARY"),
        render(barrens, prowler, "BESTIARY"),
    ]
    palette_frames = [
        getattr(frame, "image", frame).convert("P", palette=Image.Palette.ADAPTIVE, colors=128) for frame in demo
    ]
    palette_frames[0].save(
        OUT / "demo.gif", save_all=True, append_images=palette_frames[1:], duration=900, loop=0, optimize=True
    )
    print(f"wrote {len(list(OUT.glob('*')))} files to {OUT}")


if __name__ == "__main__":
    from PIL import Image

    sys.exit(main())
