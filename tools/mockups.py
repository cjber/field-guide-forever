#!/usr/bin/env python3
"""Mock screenshots of the Field Guide journal drawn with the client's own art (wowmock).

Every pixel that is not the addon's own layout comes from the WoW: Forever client build (nine-slice dialog border,
panel tabs, buttons, atlas gems, FRIZQT fonts, spell icons), fetched once from wago.tools and cached under
`tools/.cache/wowmock/`. This is a mock, not a capture: the frame is drawn the way UI/Window.lua draws it, at the
window's logical size, on wowmock's plain backdrop.

    python3 tools/mockups.py

Deterministic: the specimen counts come from the species id, so a second run is byte-identical.
"""

import csv
import json
import re
import subprocess
import sys
import textwrap
from pathlib import Path
from typing import Any, NotRequired, TypedDict

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


class MockSpecies(TypedDict):
    id: int
    name: str
    family: str
    min: int
    max: int
    lore: str
    rare: bool
    boss: bool
    zone: NotRequired[str]


class MockZone(TypedDict):
    id: int
    name: str
    continent: str
    species: list[MockSpecies]


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
# UI/Window.lua's shell geometry, and the only place these numbers live in this file: the bottom bar is 924 wide at
# BOTTOMLEFT (18, 12), and each button is anchored to the bar's TOPRIGHT by its right inset, exactly as the addon
# anchors them. Drawing from the same arithmetic the Lua does is what keeps a render from drifting off the frame.
BAR_X, BAR_Y, BAR_W, BAR_H = 18, H - 12 - 58, 924, 58
BUTTON_H, BUTTON_TOP = 26, 16
OPEN_W, OPEN_RIGHT = 112, 158
TRACK_W, TRACK_RIGHT = 132, 12
OPEN_X = BAR_X + BAR_W - OPEN_RIGHT - OPEN_W
TRACK_X = BAR_X + BAR_W - TRACK_RIGHT - TRACK_W
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
    """Read mock-only NPC rows extracted from the pinned, ignored QuestieDB release."""
    global MOCK_INSTANCES
    MOCK_INSTANCES = {}
    subprocess.run([sys.executable, "tools/gen_mock_catalogue.py"], cwd=ROOT, check=True)
    source = (ROOT / "Data" / "Client.lua").read_text(encoding="utf-8")
    pattern = re.compile(r'ns\.ClientData\.zones\[(\d+)\] = \{ name = "([^"]+)", continent = (\d+) \}')
    continents = {
        int(index): name for index, name in re.findall(r'ns\.ClientData\.continents\[(\d+)\] = "([^"]+)"', source)
    }
    maps = {
        int(index): (name, int(instance_type))
        for index, name, instance_type in re.findall(
            r'ns\.ClientData\.maps\[(\d+)\] = \{ name = "([^"]+)", instanceType = (\d+) \}', source
        )
    }
    areas: dict[int, tuple[str, int]] = {}
    zones: dict[int, MockZone] = {}
    for match in pattern.finditer(source):
        zone_id, name, continent = int(match.group(1)), match.group(2), int(match.group(3))
        areas[zone_id] = (name, continent)
        parent_map = maps.get(continent)
        if parent_map and parent_map[1] > 0:
            continue
        zones[zone_id] = {
            "id": zone_id,
            "name": name,
            "continent": continents.get(continent, str(continent)),
            "species": [],
        }
    fixture = ROOT / "tools" / ".cache" / "questiedb-mock-catalogue-v1.0.6.tsv"
    with fixture.open(encoding="utf-8", newline="") as stream:
        for row in csv.reader(stream, delimiter="\t"):
            if len(row) != 7:
                continue
            npc_id, name, minimum, maximum, rank, family, spawn_list = row
            species: MockSpecies = {
                "id": int(npc_id),
                "name": name,
                "family": family or "Unknown",
                "min": int(minimum or 1),
                "max": int(maximum or minimum or 1),
                "lore": "QuestieDB Forever mock fixture; no lore is supplied by the client database.",
                "rare": int(rank or 0) == 2,
                "boss": int(rank or 0) == 3,
            }
            for spawn in spawn_list.split(","):
                if spawn and int(spawn) in zones:
                    zone = zones[int(spawn)]
                    zone_species: MockSpecies = {**species, "zone": zone["name"]}
                    zone["species"].append(zone_species)
    result: list[MockZone] = []
    for zone_id in sorted(zones):
        zone = zones[zone_id]
        zone["species"].sort(key=lambda item: item["id"])
        if zone["species"]:
            result.append(zone)
    return result


def progress(species):
    """A plausible saved character, deterministic in the id: mastered, part-way and untouched species."""
    seed = (species["id"] * 2654435761) % 4294967296
    return {
        "count": (seed >> 7) % 11,
        "kills": (seed >> 7) % 11 + (seed >> 17) % 23,
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


LAYOUT: dict[str, Any] = {}
MOCK_INSTANCES: dict[int, dict[str, Any]] = {}


def note(name, role, x, y, w, h):
    """Record a widget rect (canvas units) for tools/visual_audit.py: bounds, overlaps and margins."""
    widgets: list[dict[str, Any]] = LAYOUT.setdefault("widgets", [])
    widgets.append({"name": name, "role": role, "x": round(x, 1), "y": round(y, 1), "w": round(w, 1), "h": round(h, 1)})


def window(ui, zone, species, tab, icons, sigil):
    """The journal as UI/Window.lua builds it: a real PortraitFrameTemplate (metal NineSlice, circular portrait,
    centred title, close button) around the addon's own list and detail panes at their own anchors."""
    m = 26
    canvas = ui.canvas(W + m * 2, H + m * 2)
    # Every scene draws the same shell, so the last one's widget list is the layout.
    LAYOUT.pop("widgets", None)

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
    tab_rects = panel_tabs(canvas, px(20), py(54), ["Creatures", "Rares", "Shiny"], selected=index)
    strip_left = min(r[0] for r in tab_rects)
    strip_right = max(r[0] + r[2] for r in tab_rects)
    note("tabs", "tabs", strip_left, py(54), strip_right - strip_left, 32)

    text(canvas, px(24), py(90), f"{zone['continent']}  >  {zone['name']}", "GameFontNormal", TEXT)
    search_box(canvas, px(24), py(112), 250, 24, "Search creatures")
    note("search", "input", px(24), py(112), 250, 24)
    fx, fy, fw, fh = filter_dropdown(canvas, px(942), py(112), "All")
    note("filter", "input", fx, fy, fw, fh)
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
        right(canvas, px(372), y + 7, f"{state['kills']} kills", "GameFontNormal", TEXT, width=64)
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
    text(canvas, rx + 24, ry + 162, "Mastery · recorded deaths", "GameFontDisableSmall", MUTED)
    right(
        canvas,
        rx + 472,
        ry + 162,
        f"{count} / 10 · {state['kills']} kills",
        "GameFontDisableSmall",
        TEXT,
        width=140,
    )
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
    text(canvas, rx + 24, ry + 400, "Local records", "GameFontNormal", GOLD)
    sightings = [
        (f"Personal first sighting \u00b7 {zone['name']}", TEXT),
        (f"First death observed \u00b7 {state['kills']} kills recorded", BLUE),
        ("First rare or shiny record \u00b7 local to this character", GOLD),
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

    # Bottom bar: zone completion and the two buttons, at the bar's own coordinates (the addon anchors them to the
    # bar, so a button starts BAR_W - inset - width from the bar's left, not from the window's).
    by = py(BAR_Y)
    card(canvas, px(BAR_X), by, BAR_W, BAR_H)
    note("bottom bar", "bar", px(BAR_X), by, BAR_W, BAR_H)
    button_y = by + BUTTON_TOP
    text(canvas, px(32), by + 8, "ZONE COMPLETION", "GameFontDisableSmall", MUTED)
    fraction = catalogued / len(zone["species"])
    text(canvas, px(32), by + 23, f"{round(fraction * 100)}%", "GameFontNormal", GOLD)
    bar(canvas, px(138), by + 27, 320, 6, fraction, GREEN)
    text(canvas, px(138), by + 38, f"{catalogued} of {len(zone['species'])} species", "GameFontDisableSmall", MUTED)
    three_slice_button(
        canvas,
        px(OPEN_X),
        button_y,
        OPEN_W,
        BUTTON_H,
        "Open Journal",
        FONTS["GameFontNormalSmall"],
        atlas="128-RedButton",
    )
    note("Open Journal", "button", px(OPEN_X), button_y, OPEN_W, BUTTON_H)
    three_slice_button(
        canvas,
        px(TRACK_X),
        button_y,
        TRACK_W,
        BUTTON_H,
        "Track Species",
        FONTS["GameFontNormalSmall"],
        atlas="128-RedButton",
    )
    note("Track Species", "button", px(TRACK_X), button_y, TRACK_W, BUTTON_H)
    if not LAYOUT.get("canvas"):
        LAYOUT["canvas"] = {"width": canvas.width, "height": canvas.height, "scale": ui.scale}
        LAYOUT["frame"] = {"x": px(0), "y": py(0), "w": W, "h": H}
        LAYOUT["scenes"] = []
    return canvas


ZONE_PAGE_COUNT = 12


def zone_pages(zones):
    """A spread of zones across the whole catalogue, not the first N: the README shows the range."""
    if len(zones) <= ZONE_PAGE_COUNT:
        return zones
    step = len(zones) / ZONE_PAGE_COUNT
    return [zones[int(index * step)] for index in range(ZONE_PAGE_COUNT)]


def main():
    ui = wowmock.Ui(scale=2)
    OUT.mkdir(parents=True, exist_ok=True)
    for obsolete in OUT.glob("creature-??.png"):
        obsolete.unlink()
    zones = load_catalogue()
    current_ids = {zone["id"] for zone in zones}
    for previous in OUT.glob("zone-*.png"):
        if int(previous.stem.split("-")[1]) not in current_ids:
            previous.unlink()
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
    prowler = barrens["species"][0]
    all_species = [(zone, species) for zone in zones for species in zone["species"]]
    rare_zone, rare = next(((zone, species) for zone, species in all_species if species["rare"]), (barrens, prowler))
    shiny_zone, shiny = next(
        ((zone, species) for zone, species in all_species if progress(species)["shiny"]),
        (barrens, prowler),
    )

    def render(zone, species, tab="CREATURES"):
        return wowmock.scene(ui, [(window(ui, zone, species, tab, icons, sigil), 0, 0)])

    def save(scene, name):
        scene.save(OUT / name)
        scenes: list[str] = LAYOUT.setdefault("scenes", [])
        scenes.append(name)

    save(render(barrens, prowler, "CREATURES"), "field-guide.png")
    save(render(rare_zone, rare, "RARES"), "rares.png")
    save(render(shiny_zone, shiny, "SHINY"), "shiny.png")

    for zone in zone_pages(zones):
        save(render(zone, zone["species"][0], "CREATURES"), f"zone-{zone['id']:04d}.png")

    search_zone = barrens
    search_species = barrens["species"][min(3, len(barrens["species"]) - 1)]
    save(render(search_zone, search_species, "CREATURES"), "search-filter.png")
    save(render(search_zone, prowler, "CREATURES"), "tracking.png")
    save(render(rare_zone, rare, "RARES"), "rare-record.png")
    save(render(shiny_zone, shiny, "SHINY"), "shiny-record.png")

    def feature_overlay(base, title, subtitle, lines):
        canvas = wowmock.Canvas(ui, base.width, base.height)
        canvas.image = base.image.copy()
        veil = Image.new("RGBA", (canvas.image.size[0], 26 + BAR_Y), (0, 0, 0, 150))
        canvas.composite(veil, 0, 0)
        card(canvas, 205, 185, 602, 400)
        text(canvas, 240, 220, title, "GameFontNormalLarge", GOLD)
        text(canvas, 240, 257, subtitle, "GameFontDisableSmall", MUTED)
        for index, line in enumerate(lines):
            y = 305 + index * 42
            canvas.draw(ui.atlas("common-icon-checkmark"), 242, y, 20, 20, GREEN)
            text(canvas, 276, y + 1, line, "GameFontNormal", TEXT)
        return canvas

    feature_overlay(
        render(search_zone, search_species),
        "Search and status filters",
        f'Query: "{search_species["name"][:20]}" · Filter: Rare',
        [search_species["name"], "Matching species only", "Clear search to restore the list"],
    ).save(OUT / "search-filter.png")
    feature_overlay(
        render(search_zone, prowler),
        "Tracked species",
        "Tracking · current character",
        [prowler["name"], "Shown in the journal bottom bar", "Progress remains character-local"],
    ).save(OUT / "tracking.png")
    feature_overlay(
        render(barrens, prowler),
        "Field Guide Forever options",
        "Personal progress and sharing preferences",
        ["Show undiscovered species", "Show the sighting log", "Share with guild and group"],
    ).save(OUT / "settings.png")
    feature_overlay(
        render(barrens, prowler),
        "Sightings this session",
        "Your records · local to this character",
        [
            f"First sighting · {prowler['name']}",
            f"First death · {prowler['name']}",
            "Rare and shiny rolls stay personal",
        ],
    ).save(OUT / "sighting-log.png")
    instance_species = next((species for zone in zones for species in zone["species"] if species["boss"]), None)
    boss_name = instance_species["name"] if instance_species else "No boss entry in this fixture"
    feature_overlay(
        render(barrens, prowler),
        "Instances · boss records",
        "Dungeon and raid entries from QuestieDB Forever",
        [boss_name, "0 recorded boss kills · your records", "Difficulty and first-clear history"],
    ).save(OUT / "instances-boss.png")
    feature_overlay(
        render(barrens, prowler),
        "Creature catalogue unavailable",
        "QuestieDB Forever is required for creature data",
        ["Install Questie or standalone QuestieDB", "Restart the client or type /reload"],
    ).save(OUT / "missing-questiedb.png")

    def write_readme_gallery():
        features = [
            ("field-guide.png", "Creatures journal"),
            ("rares.png", "Rares page"),
            ("rare-record.png", "Personal rare record"),
            ("shiny.png", "Shiny page"),
            ("shiny-record.png", "Personal shiny record"),
            ("search-filter.png", "Search and status filter"),
            ("tracking.png", "Tracked species"),
            ("settings.png", "Options panel"),
            ("sighting-log.png", "Session sighting log"),
            ("rarity-target.png", "Target frame rarity"),
            ("rarity-nameplates.png", "Nameplate rarity"),
            ("rarity-elite.png", "Elite rarity chrome"),
            ("instances-boss.png", "Instance boss record"),
            ("missing-questiedb.png", "QuestieDB install prompt"),
        ]
        gallery = ["![A short walk through the journal](docs/screenshots/demo.gif)", "", "## Feature previews", ""]
        gallery.extend(f"![{label}](docs/screenshots/{filename})\n" for filename, label in features)
        gallery += ["## Zone pages", "", "| | | |", "| --- | --- | --- |"]
        row = []
        for zone in zone_pages(zones):
            filename = f"zone-{zone['id']:04d}.png"
            row.append(f"![{zone['name']}](docs/screenshots/{filename})")
            if len(row) == 3:
                gallery.append("| " + " | ".join(row) + " |")
                row = []
        if row:
            row.extend([""] * (3 - len(row)))
            gallery.append("| " + " | ".join(row) + " |")
        readme_path = ROOT / "README.md"
        readme = readme_path.read_text(encoding="utf-8")
        begin, finish = "<!-- SCREENSHOT_GALLERY:START -->", "<!-- SCREENSHOT_GALLERY:END -->"
        if begin not in readme or finish not in readme:
            raise ValueError("README screenshot gallery markers are missing")
        before, rest = readme.split(begin, 1)
        _, after = rest.split(finish, 1)
        readme_path.write_text(before + begin + "\n" + "\n".join(gallery) + "\n" + finish + after, encoding="utf-8")

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
    write_readme_gallery()
    (OUT / "layout.json").write_text(json.dumps(LAYOUT, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {len(list(OUT.glob('*.png')))} PNG scenes and updated README gallery")


if __name__ == "__main__":
    from PIL import Image  # ty: ignore[unresolved-import]  # Pillow is local only, like wowmock

    sys.exit(main())
