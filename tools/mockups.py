#!/usr/bin/env python3
"""Mock screenshots of the Field Guide journal drawn with the client's own art (wowmock).

Every pixel that is not the addon's own layout comes from the WoW: Forever client build (nine-slice dialog border,
panel tabs, buttons, atlas gems, FRIZQT fonts, spell icons), fetched once from wago.tools and cached under
`tools/.cache/wowmock/`. This is a mock, not a capture: the frame is drawn the way UI/Window.lua draws it, at the
window's logical size, on wowmock's plain backdrop.

    python3 tools/mockups.py

Deterministic: the specimen counts come from the species id, so a second run is byte-identical.
"""

import re
import sys
import textwrap
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wowmock.wowmock as wowmock  # noqa: E402
from wowmock.wowmock import (  # noqa: E402
    FONTS,
    INSET_FRAME_LAYOUT,
    draw_nine_slice,
    filter_dropdown,
    minimal_scrollbar,
    panel_tabs,
    portrait_frame_art,
    search_box,
    three_slice_button,
)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "screenshots"

# UI/Art.lua's palette, as wowmock colour tuples.
GOLD = wowmock.rgb("e0b540")
BRASS = wowmock.rgb("b8a16b")
TEXT = wowmock.rgb("e3d9c2")
MUTED = wowmock.rgb("9e998c")
BLUE = wowmock.rgb("85b8f2")
GREEN = wowmock.rgb("7d9961")
DIM = wowmock.rgb("9e998c")
DARK = wowmock.rgb("1b1e22")
TROUGH = wowmock.rgb("303236")
PANEL = wowmock.rgb("212429")

W, H = 960, 720
MASTERED_AT, RARE_TARGET, SHINY_TARGET = 10, 3, 1
RANK_NAMES = ("Undiscovered", "Discovered", "Observed", "Studied", "Mastered")
PIPS = ("Discovered", "Observed", "Studied", "Mastered")


def rank_of(count):
    rank = 0
    for step, threshold in enumerate((1, 3, 6, 10)):
        if count >= threshold:
            rank = step + 1
    return rank


# A species shows its own kind, mirroring Art.SpeciesIcon in UI/Art.lua: the first keyword a creature's name contains
# wins, and anything unmatched falls back to its family. Every path here resolves in this client build.
SPECIES_ICONS = (
    (
        "interface/icons/ability_hunter_pet_cat.blp",
        "beast",
        (
            "prowler",
            "highmane",
            "nightsaber",
            "cougar",
            "tiger",
            "rake",
            "saber",
            "dishu",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_wolf.blp",
        "beast",
        (
            "wolf",
            "coyote",
            "darkhound",
            "hound",
            "arugal",
            "worgen",
            "stalker",
            "fenros",
            "nefaru",
            "deeb",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_boar.blp",
        "beast",
        (
            "boar",
            "goretusk",
            "bristleback",
            "quilboar",
            "bellygrub",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_tallstrider.blp",
        "beast",
        (
            "plainstrider",
            "strider",
            "giraffe",
            "mazzranache",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_raptor.blp",
        "beast",
        (
            "raptor",
            "scytheclaw",
            "taillasher",
            "scythemaw",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_scorpid.blp",
        "beast",
        (
            "scorpid",
            "sting",
            "flayer",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_spider.blp",
        "beast",
        (
            "spider",
            "tarantula",
            "venomfang",
            "lurker",
            "fang",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_crocolisk.blp",
        "beast",
        (
            "crocolisk",
            "snapjaw",
            "gesharahan",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_hyena.blp",
        "beast",
        (
            "hyena",
            "stormsnout",
        ),
    ),
    (
        "interface/icons/ability_mount_ridinghorse.blp",
        "beast",
        ("zhevra",),
    ),
    (
        "interface/icons/ability_hunter_pet_turtle.blp",
        "beast",
        ("turtle",),
    ),
    (
        "interface/icons/ability_hunter_pet_silithid.blp",
        "beast",
        (
            "silithid",
            "swarmer",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_bear.blp",
        "beast",
        (
            "bear",
            "grizzlegut",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_bat.blp",
        "any",
        (
            "harpy",
            "windfury",
            "duskbat",
            "bat",
            "owl",
            "strigid",
            "screecher",
            "swoop",
            "buzzard",
            "condor",
            "thunderhawk",
            "hippogryph",
            "razorbeak",
            "fleshripper",
        ),
    ),
    (
        "interface/icons/ability_hunter_pet_worm.blp",
        "beast",
        (
            "worm",
            "grub",
        ),
    ),
    (
        "interface/icons/inv_misc_head_tauren_01.blp",
        "people",
        (
            "ogre",
            "mo'grosh",
            "kolkar",
            "galak",
        ),
    ),
    (
        "interface/icons/inv_misc_head_gnoll_01.blp",
        "people",
        (
            "gnoll",
            "mongrel",
            "brute",
            "mystic",
            "basher",
            "trapper",
        ),
    ),
    (
        "interface/icons/inv_misc_head_kobold_01.blp",
        "people",
        (
            "kobold",
            "trogg",
            "stonesplinter",
            "digger",
        ),
    ),
    (
        "interface/icons/inv_misc_head_murloc_01.blp",
        "people",
        (
            "murloc",
            "puddlejumper",
            "oracle",
            "coastrunner",
        ),
    ),
    (
        "interface/icons/inv_misc_head_undead_01.blp",
        "people",
        (
            "ghoul",
            "dead",
            "rot",
            "plague",
            "gorelix",
        ),
    ),
    (
        "interface/icons/inv_misc_head_human_01.blp",
        "people",
        (
            "defias",
            "scarlet",
            "dalaran",
            "kul tiras",
            "human",
            "thug",
            "pillager",
            "looter",
            "highwayman",
            "smuggler",
            "blackguard",
            "mage",
            "guard",
            "theurgist",
            "sailor",
            "marine",
            "convert",
            "initiate",
            "warrior",
            "missionary",
            "scout",
            "palemane",
            "dustwind",
            "gnarlpine",
            "melanas",
            "ursal",
            "yowler",
            "zzarc",
            "slark",
            "goldtooth",
            "fedfennel",
            "gibblewilt",
            "galgosh",
        ),
    ),
    (
        "interface/icons/inv_misc_head_dragon_01.blp",
        "people",
        (
            "dragon",
            "whelp",
            "drake",
        ),
    ),
)
# One client icon per family, Art.FAMILY_ICONS in UI/Art.lua.
FAMILY_ICONS = {
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


def species_icon(species):
    """The icon Art.SpeciesIcon picks: a Beast takes the hunter-pet glyphs and everything else the people glyphs, so a
    shared keyword ("shaman", "arugal") cannot hand a humanoid a beast's icon."""
    name = species["name"].lower()
    beast = species["family"] == "Beast"
    for path, side, keywords in SPECIES_ICONS:
        if side not in ("any", "beast" if beast else "people"):
            continue
        # Whole words only: a bare substring match put "owl" inside "Yowler" and gave a gnoll a bat's glyph.
        if any(re.search(rf"\b{re.escape(word)}\b", name) for word in keywords):
            return path
    return FAMILY_ICONS.get(species["family"], FALLBACK_ICON)


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


def card(canvas, x, y, w, h, border=None):
    """A restrained inset using the client's InsetFrameTemplate NineSlice chrome."""
    canvas.fill(x, y, w, h, wowmock.rgb("171a1e"))
    draw_nine_slice(canvas, INSET_FRAME_LAYOUT, x, y, w, h)


def text(canvas, x, y, value, font, colour=TEXT, **kwargs):
    canvas.text(x, y, value, FONTS[font], colour, **kwargs)


def right(canvas, right_edge, y, value, font, colour=TEXT, width=120):
    """Text right-aligned to `right_edge`: canvas.text grows rightward from x, so hand it the box to fill."""
    canvas.text(right_edge - width, y, value, FONTS[font], colour, justify="RIGHT", width=width)


def marker(canvas, cx, cy, size, colour):
    """Use the client's checkmark atlas for completion and event markers."""
    canvas.draw(canvas.ui.atlas("common-icon-checkmark"), cx - size / 2, cy - size / 2, size, size, colour)


def window(ui, zone, species, tab, icons, sigil):
    """The journal as UI/Window.lua builds it: a real PortraitFrameTemplate (metal NineSlice, circular portrait,
    centred title, close button) around the addon's own list and detail panes at their own anchors."""
    m = 26
    canvas = ui.canvas(W + m * 2, H + m * 2)

    def px(x):
        return m + x

    def py(y):
        return m + y

    # Bg first: the template is chrome only, and the addon paints its own opaque interior.
    canvas.fill(px(6), py(22), W - 12, H - 28, wowmock.rgb("0b0c0e"))
    portrait_frame_art(canvas, m, m, W, H, sigil, "FIELD GUIDE")
    text(
        canvas,
        px(58),
        py(30),
        "Azeroth field journal",
        "GameFontDisableSmall",
        MUTED,
        justify="CENTER",
        width=W - 58 - 24,
    )

    index = ("CREATURES", "RARES", "SHINY").index(tab)
    panel_tabs(canvas, px(20), py(54), ["Creatures", "Rares", "Shiny"], selected=index)

    text(canvas, px(24), py(90), f"{zone['continent']}  >  {zone['name']}", "GameFontNormal", TEXT)
    search_box(canvas, px(24), py(112), 250, 24, "Search creatures")
    filter_dropdown(canvas, px(942), py(112), "All")
    canvas.draw(ui.atlas("_UI-Frame-InnerTopTile"), px(18), py(142), W - 36, 3)

    # Left pane: the creature list.
    catalogued = sum(1 for s in zone["species"] if progress(s)["count"])
    rows = zone["species"]
    if tab == "RARES":
        rows = [s for s in rows if s["rare"] or progress(s)["rare"] >= RARE_TARGET]
    elif tab == "SHINY":
        rows = [s for s in rows if progress(s)["shiny"]]
    rows = rows or zone["species"]

    if len(rows) > 8:
        minimal_scrollbar(canvas, px(388), py(150), 440, visible=8 / len(rows))
    for row_index, row in enumerate(rows[:8]):
        state = progress(row)
        chosen = row["id"] == species["id"]
        y = py(146 + row_index * 58)
        if chosen:
            canvas.fill(px(18), y, 368, 58, wowmock.rgb("2b2a24"))
        else:
            canvas.fill(
                px(18),
                y,
                368,
                58,
                wowmock.rgb("212429"),
            )
        canvas.draw(icons[row["id"]], px(28), y + 10, 32, 32)
        canvas.draw(ui.texture("interface/common/whiteiconframe.blp"), px(28), y + 10, 32, 32, BRASS)
        known = row["rare"] and state["rare"] >= RARE_TARGET
        text(canvas, px(70), y + 7, row["name"][:26], "GameFontNormal", BLUE if known else TEXT)
        text(
            canvas,
            px(70),
            y + 26,
            f"{row['family']} \u00b7 Lv {row['min']}\u2013{row['max']}",
            "GameFontDisableSmall",
            MUTED,
        )
        right(canvas, px(372), y + 7, f"{state['count']} / 10", "GameFontNormal", TEXT, width=44)
        complete = state["count"] >= 1 and bool(state["shiny"]) and (not row["rare"] or state["rare"] >= RARE_TARGET)
        if state["count"] >= MASTERED_AT:
            marker(canvas, px(352), y + 32, 11, GOLD)
        elif complete:
            canvas.draw(ui.atlas("common-icon-checkmark"), px(346), y + 26, 11, 11, GREEN)
        canvas.fill(px(70), y + 47, 252, 5, wowmock.rgb("303236"))
        bar(canvas, px(70), y + 48, 252, 3, state["count"] / MASTERED_AT, GOLD)

    # Right pane: the selected creature's entry.
    state = progress(species)
    count = state["count"]
    rank = rank_of(count)
    rx, ry = px(426), py(146)

    # The portrait is circular: draw it on its own layer, mask that, then paste. canvas.mask multiplies the whole
    # surface's alpha, so applying it to the main canvas would erase everything outside the portrait's rect.
    portrait = ui.canvas(canvas.width, canvas.height)
    portrait.draw(icons[species["id"]], rx + 14, ry + 14, 58, 58)
    portrait.mask(ui.texture("interface/characterframe/tempportraitalphamask.blp"), rx + 14, ry + 14, 58, 58)
    canvas.paste(portrait, 0, 0)
    canvas.draw(ui.texture("interface/common/whiteiconframe.blp"), rx + 14, ry + 14, 58, 58, BRASS)
    text(canvas, rx + 84, ry + 18, species["name"], "GameFontNormalLarge", GOLD)
    text(
        canvas,
        rx + 84,
        ry + 40,
        f"{species['family']} \u00b7 {zone['name']} \u00b7 Level {species['min']}\u2013{species['max']}",
        "GameFontDisableSmall",
        MUTED,
    )

    badges = [("Common", MUTED, True)]
    badges.append(
        (
            "Rare variant known" if state["rare"] >= RARE_TARGET else "Rare",
            BLUE,
            state["rare"] >= RARE_TARGET or species["rare"],
        )
    )
    badges.append(("Shiny seen", GOLD, bool(state["shiny"])))
    bx = rx + 14
    for label, colour, show in badges:
        if not show:
            continue
        width = max(50, canvas.text_width(label, FONTS["GameFontDisableSmall"]) + 14)
        card(canvas, bx, ry + 76, width, 18, colour)
        text(canvas, bx, ry + 76, label, "GameFontDisableSmall", colour, justify="CENTER", width=width, box_height=18)
        bx += width + 6

    # Research card.
    card(canvas, rx + 14, ry + 102, 468, 84)
    text(canvas, rx + 24, ry + 109, "Research", "GameFontNormal", GOLD)
    right(
        canvas,
        rx + 472,
        ry + 111,
        ("Rank {} \u2014 {}".format("I", RANK_NAMES[rank])) if rank else "Not yet discovered",
        "GameFontDisableSmall",
        GOLD,
        width=150,
    )
    for pip_index, name in enumerate(PIPS):
        x = rx + 14 + 28 + pip_index * 108
        on = rank >= pip_index + 1
        marker(canvas, x + 5, ry + 102 + 33, 11, GOLD if on else wowmock.rgb("4a4842"))
        if pip_index < len(PIPS) - 1:
            canvas.draw(
                ui.atlas("_UI-Frame-InnerTopTile"),
                x + 13,
                ry + 102 + 31,
                90,
                3,
                GOLD if rank >= pip_index + 2 else wowmock.rgb("3a382f"),
            )
        text(
            canvas,
            x - 38,
            ry + 102 + 42,
            name,
            "GameFontDisableSmall",
            TEXT if on else MUTED,
            justify="CENTER",
            width=86,
        )
    text(canvas, rx + 24, ry + 162, "Specimens", "GameFontDisableSmall", MUTED)
    right(canvas, rx + 472, ry + 162, f"{count} / 10", "GameFontDisableSmall", TEXT, width=60)
    bar(canvas, rx + 24, ry + 178, 448, 4, count / MASTERED_AT, GOLD)

    # Lore card.
    card(canvas, rx + 14, ry + 192, 468, 50)
    text(canvas, rx + 24, ry + 198, "Lore", "GameFontNormal", GOLD)
    for line_index, line in enumerate(textwrap.wrap(species["lore"], 74)[:2]):
        text(canvas, rx + 24, ry + 212 + line_index * 12, line, "GameFontDisableSmall", wowmock.rgb("c4baa4"))

    # Variants.
    text(canvas, rx + 14, ry + 246, "Variants", "GameFontNormal", GOLD)
    right(
        canvas,
        rx + 472,
        ry + 248,
        f"{1 + (state['rare'] >= RARE_TARGET) + bool(state['shiny'])} of 3 recorded",
        "GameFontDisableSmall",
        MUTED,
        width=120,
    )
    variants = [
        ("Common", "Catalogued", True, TEXT),
        ("Rare variant", f"{state['rare']} / {RARE_TARGET}", state["rare"] >= RARE_TARGET, BLUE),
        ("Shiny variant", f"{state['shiny']} / {SHINY_TARGET}", bool(state["shiny"]), GOLD),
    ]
    for variant_index, (title, sub, known, colour) in enumerate(variants):
        vx = rx + 14 + variant_index * 156
        vy = ry + 262
        card(canvas, vx, vy, 148, 52, colour if known else wowmock.rgb("3a382f"))
        text(canvas, vx + 8, vy + 6, title, "GameFontNormal", TEXT)
        if known:
            canvas.draw(ui.atlas("common-icon-checkmark"), vx + 124, vy + 7, 12, 12, colour)
        else:
            right(canvas, vx + 140, vy + 6, "\u2014", "GameFontNormal", MUTED, width=16)
        text(canvas, vx + 8, vy + 28, sub, "GameFontDisableSmall", MUTED)

    # Cosmetic rewards, two columns of two.
    card(canvas, rx + 14, ry + 320, 468, 66)
    text(canvas, rx + 24, ry + 326, "Cosmetic rewards", "GameFontNormal", GOLD)
    rewards = (
        ("Field sketch", "UNLOCKED" if rank >= 1 else "Locked \u00b7 Discovered", rank >= 1),
        ("Ink study", "UNLOCKED" if rank >= 2 else "Locked \u00b7 Observed", rank >= 2),
        ("Brass plate", "UNLOCKED" if rank >= 3 else "Locked \u00b7 Studied", rank >= 3),
        ("Gilded entry", "UNLOCKED" if rank >= 4 else "Locked \u00b7 Mastered", rank >= 4),
    )
    for reward_index, (label, status, open_) in enumerate(rewards):
        column, row_index = reward_index % 2, reward_index // 2
        lx, ly = rx + 34 + column * 230, ry + 345 + row_index * 20
        marker(canvas, lx - 10, ly + 5, 9, GOLD if open_ else wowmock.rgb("4a4842"))
        text(canvas, lx, ly, label, "GameFontDisableSmall", TEXT if open_ else MUTED)
        right(canvas, lx + 182, ly, status, "GameFontDisableSmall", GREEN if open_ else MUTED, width=104)

    # Sighting log.
    card(canvas, rx + 14, ry + 394, 468, 76)
    text(canvas, rx + 24, ry + 400, "Sighting log", "GameFontNormal", GOLD)
    right(canvas, rx + 472, ry + 402, "this session", "GameFontDisableSmall", DIM, width=90)
    sightings = [
        (f"{species['name']} \u2014 killed", TEXT),
        ("Dishu \u2014 rare sighting", BLUE),
        ("Plainstrider \u2014 shiny", GOLD),
    ]
    for line_index, (line, colour) in enumerate(sightings):
        ly = ry + 420 + line_index * 14
        marker(canvas, rx + 3, ly + 5, 9, colour)
        text(canvas, rx + 14, ly, line, "GameFontDisableSmall", colour)
    text(
        canvas,
        rx + 22,
        ry + 484,
        "Cosmetic only \u2014 the field guide never grants player power.",
        "GameFontDisableSmall",
        DIM,
    )

    # Bottom bar: zone completion and the two buttons.
    by = py(650)
    card(canvas, px(18), by, 924, 58)
    text(canvas, px(32), by + 8, "ZONE COMPLETION", "GameFontDisableSmall", MUTED)
    fraction = catalogued / len(zone["species"])
    text(canvas, px(32), by + 23, f"{round(fraction * 100)}%", "GameFontNormal", GOLD)
    bar(canvas, px(138), by + 27, 320, 6, fraction, GREEN)
    text(canvas, px(138), by + 38, f"{catalogued} of {len(zone['species'])} species", "GameFontDisableSmall", MUTED)
    three_slice_button(
        canvas, px(766), by + 16, 112, 26, "Open Journal", FONTS["GameFontNormalSmall"], atlas="128-RedButton"
    )
    three_slice_button(
        canvas, px(882), by + 16, 132, 26, "Track Species", FONTS["GameFontNormalSmall"], atlas="128-RedButton"
    )
    return canvas


def main():
    ui = wowmock.Ui(scale=2)
    OUT.mkdir(parents=True, exist_ok=True)
    zones = load_catalogue()
    by_name = {zone["name"]: zone for zone in zones}
    # One client icon per species, chosen by the same keyword rules as Art.SpeciesIcon.
    icons = {}
    for zone in zones:
        for species in zone["species"]:
            icons[species["id"]] = ui.texture(species_icon(species))
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

    def render(zone, species, tab="CREATURES"):
        return wowmock.scene(ui, [(window(ui, zone, species, tab, icons, sigil), 0, 0)])

    render(barrens, prowler, "CREATURES").save(OUT / "field-guide.png")
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
        render(zone, species, "CREATURES").save(OUT / (f"creature-{index:02d}.png"))

    demo = [
        render(barrens, prowler, "CREATURES"),
        render(barrens, prowler, "RARES"),
        render(rare_zone, rare, "RARES"),
        render(rare_zone, rare, "SHINY"),
        render(shiny_zone, shiny, "SHINY"),
        render(*pick("Teldrassil", lambda s: not s["rare"])),
        render(*pick("Westfall", lambda s: s["rare"])),
        render(barrens, prowler, "CREATURES"),
    ]
    palette_frames = [
        getattr(frame, "image", frame).convert("P", palette=Image.Palette.ADAPTIVE, colors=128) for frame in demo
    ]
    palette_frames[0].save(
        OUT / "demo.gif", save_all=True, append_images=palette_frames[1:], duration=900, loop=0, optimize=True
    )
    print(f"wrote {len(list(OUT.glob('*')))} files to {OUT}")


if __name__ == "__main__":
    from PIL import Image  # ty: ignore[unresolved-import]  # Pillow is local only, like wowmock

    sys.exit(main())
