#!/usr/bin/env python3
"""Mock screenshots of the Field Guide journal drawn with the client's own art (wowmock).

Every pixel that is not the addon's own layout comes from the WoW: Forever client build (nine-slice dialog border,
buttons, atlas gems, FRIZQT fonts, spell icons), fetched once from wago.tools and cached under
`tools/.cache/wowmock/`. This is a mock, not a capture: the frame is drawn the way UI/Window.lua draws it, at the
window's logical size, on wowmock's plain backdrop.

    python3 tools/mockups.py

Deterministic: the specimen counts come from the species id, so a second run is byte-identical.
"""

import csv
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, NotRequired, TypedDict

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wowmock.wowmock as wowmock  # noqa: E402
from wowmock.wowmock import (  # noqa: E402
    FONTS,
    INSET_FRAME_LAYOUT,
    MenuCheckbox,
    MenuTitle,
    basic_panel,
    context_menu,
    draw_nine_slice,
    minimal_scrollbar,
    portrait_frame_art,
    search_box,
    ui_panel_button,
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
MICRO_MENU_RENDER = ROOT / "tools" / "micro_menu_render.py"


def render_micro_menu_scenes():
    with tempfile.TemporaryDirectory(prefix="field-guide-micro-menu-") as directory:
        subprocess.run([sys.executable, str(MICRO_MENU_RENDER)], cwd=directory, check=True)
        for scene in ("micro-menu-field-guide.png", "micro-menu-options.png"):
            shutil.copy2(Path(directory) / scene, OUT / scene)


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
FONTS["FieldGuideTabLabel"] = wowmock.Font(
    FONTS["GameFontDisableSmall"].path, 8, FONTS["GameFontDisableSmall"].color, (1, -1)
)
TAB_ICON_PATHS = (
    "interface/icons/inv_misc_book_09.blp",
    "interface/icons/inv_misc_spyglass_02.blp",
    "interface/icons/inv_scroll_03.blp",
    "interface/icons/inv_chest_chain_05.blp",
)
TAB_TOOLTIPS = ("CREATURES", "RARES", "SHINY", "INSTANCES")

W, H = 960, 720
# UI/Window.lua's shell geometry, and the only place these numbers live in this file: the bottom bar is 924 wide at
# BOTTOMLEFT (18, 12), and each button is anchored to the bar's TOPRIGHT by its right inset, exactly as the addon
# anchors them. Drawing from the same arithmetic the Lua does is what keeps a render from drifting off the frame.
BAR_X, BAR_Y, BAR_W, BAR_H = 18, H - 12 - 58, 924, 58
BUTTON_H, BUTTON_TOP = 26, 16
OPEN_W, OPEN_RIGHT = 120, 140
TRACK_W, TRACK_RIGHT = 120, 12
OPEN_X = BAR_X + BAR_W - OPEN_RIGHT - OPEN_W
TRACK_X = BAR_X + BAR_W - TRACK_RIGHT - TRACK_W
MASTERED_AT, RARE_TARGET, SHINY_TARGET = 10, 3, 1
PIPS = ("Discovered", "Observed", "Studied", "Mastered")


def rank_of(count):
    rank = 0
    for step, threshold in enumerate((1, 3, 6, 10)):
        if count >= threshold:
            rank = step + 1
    return rank


# Fallback name rules mirror Art.SpeciesIcon in UI/Art.lua after the generated per-NPC model icon.
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
    "Critter": "interface/icons/ability_hunter_beasttaming.blp",
    "Demon": "interface/icons/spell_shadow_metamorphosis.blp",
    "Aberration": "interface/icons/ability_creature_poison_01.blp",
}
FALLBACK_ICON = "interface/icons/ability_hunter_beasttaming.blp"
CREATURE_TYPE_NAMES = {}
CREATURE_INFO = {}
CREATURE_FAMILIES = {}
MODEL_ICONS = {}
MODEL_ICON_IDS = {}


def species_icon(species):
    """Mirror Art.SpeciesIcon using the same generated model icon and type/family data."""
    name = species["name"].lower()
    packed = CREATURE_INFO.get(species["id"])
    icon_index = packed >> 20 if packed else 0
    metadata = packed & 0xFFFFF if packed else 0
    type_id, family_id = (metadata >> 16, metadata & 0xFFFF) if packed else (0, 0)
    if icon_index:
        return MODEL_ICONS[icon_index]
    creature_type = CREATURE_TYPE_NAMES.get(type_id, "Unknown")
    beast = creature_type == "Beast" or family_id > 0
    for path, side, keywords in SPECIES_ICONS:
        if side not in ("any", "beast" if beast else "people"):
            continue
        # Whole words only: a bare substring match put "owl" inside "Yowler" and gave a gnoll a bat's glyph.
        if any(re.search(rf"\b{re.escape(word)}\b", name) for word in keywords):
            return path
    if family_id:
        family_name = CREATURE_FAMILIES.get(family_id)
        if family_name in PET_FAMILY_ICONS:
            return PET_FAMILY_ICONS[family_name]
        return FAMILY_ICONS.get(creature_type, FALLBACK_ICON)
    return FAMILY_ICONS.get(creature_type, FALLBACK_ICON)


PET_FAMILY_ICONS = {
    "Wolf": "interface/icons/ability_hunter_pet_wolf.blp",
    "Cat": "interface/icons/ability_hunter_pet_cat.blp",
    "Spider": "interface/icons/ability_hunter_pet_spider.blp",
    "Bear": "interface/icons/ability_hunter_pet_bear.blp",
    "Boar": "interface/icons/ability_hunter_pet_boar.blp",
    "Crocolisk": "interface/icons/ability_hunter_pet_crocolisk.blp",
    "Carrion Bird": "interface/icons/ability_hunter_pet_bat.blp",
    "Raptor": "interface/icons/ability_hunter_pet_raptor.blp",
    "Tallstrider": "interface/icons/ability_hunter_pet_tallstrider.blp",
    "Scorpid": "interface/icons/ability_hunter_pet_scorpid.blp",
    "Turtle": "interface/icons/ability_hunter_pet_turtle.blp",
    "Bat": "interface/icons/ability_hunter_pet_bat.blp",
    "Hyena": "interface/icons/ability_hunter_pet_hyena.blp",
    "Bird of Prey": "interface/icons/ability_hunter_pet_owl.blp",
}


SIGIL_ICON = "interface/icons/inv_misc_book_06.blp"


def load_catalogue():
    """Read mock-only NPC rows extracted from the pinned, ignored QuestieDB release."""
    global MOCK_INSTANCES, CREATURE_TYPE_NAMES, CREATURE_INFO, CREATURE_FAMILIES, MODEL_ICONS, MODEL_ICON_IDS
    MOCK_INSTANCES = {}
    subprocess.run([sys.executable, "tools/gen_mock_catalogue.py"], cwd=ROOT, check=True)
    source = (ROOT / "Data" / "Client.lua").read_text(encoding="utf-8")
    creature_source = (ROOT / "Data" / "CreatureIcons.lua").read_text(encoding="utf-8")
    CREATURE_TYPE_NAMES = {
        int(type_id): name for type_id, name in re.findall(r'^\s*\[(\d+)\] = "([^"]+)"', creature_source, re.MULTILINE)
    }
    CREATURE_INFO = {
        int(npc_id): int(packed)
        for npc_id, packed in re.findall(r"^\s*\[(\d+)\] = (\d+),$", creature_source, re.MULTILINE)
    }
    MODEL_ICONS = {
        int(index): path
        for index, path in re.findall(r'^\s*\[(\d+)\] = "(interface/icons/[^\"]+)"', creature_source, re.MULTILINE)
    }
    model_source = json.loads((ROOT / "tools" / ".cache" / "creature-model-paths-202610202236.json").read_text())
    MODEL_ICON_IDS = {path: int(file_id) for path, file_id in model_source["icons"].items()}
    CREATURE_FAMILIES = {
        int(family_id): name for family_id, name in re.findall(r'ns\.ClientData\.families\[(\d+)\] = "([^"]+)"', source)
    }
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
            packed = CREATURE_INFO.get(int(npc_id))
            creature_type = CREATURE_TYPE_NAMES.get(packed >> 16, "Unknown") if packed else "Unknown"
            species: MockSpecies = {
                "id": int(npc_id),
                "name": name,
                "family": creature_type,
                "min": int(minimum or 1),
                "max": int(maximum or minimum or 1),
                "lore": "QuestieDB Forever mock fixture; no lore is supplied by the client database.",
                "rare": int(rank or 0) == 2,
                "boss": int(rank or 0) == 3,
            }
            for spawn in spawn_list.split(","):
                if not spawn:
                    continue
                area_id = int(spawn)
                zone = zones.get(area_id)
                if zone:
                    zone_species: MockSpecies = {**species, "zone": zone["name"]}
                    zone["species"].append(zone_species)
                else:
                    area = areas.get(area_id)
                    if area is None:
                        continue
                    parent = maps.get(area[1])
                    if parent and parent[1] in (1, 2):
                        map_id = area[1]
                        group = MOCK_INSTANCES.setdefault(
                            map_id,
                            {"id": map_id, "name": parent[0], "instanceType": parent[1], "species": {}},
                        )
                        group["species"][species["id"]] = species
    result: list[MockZone] = []
    for zone_id in sorted(zones):
        zone = zones[zone_id]
        zone["species"].sort(key=lambda item: item["id"])
        if zone["species"]:
            result.append(zone)
    for group in MOCK_INSTANCES.values():
        group["species"] = [group["species"][npc_id] for npc_id in sorted(group["species"])]
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


def wrap_pixels(value, font, width, max_lines, canvas):
    """Wrap a FontString at its actual pixel width, keeping at most the client's line count."""
    words = value.split()
    lines = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if current and canvas.text_width(candidate, font) > width:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    if len(lines) > max_lines:
        lines = lines[:max_lines]
        last = lines[-1]
        while last and canvas.text_width(last + "…", font) > width:
            last = last.rsplit(" ", 1)[0] if " " in last else last[:-1]
        lines[-1] = last + "…"
    return lines


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
    canvas = ui.canvas(W + m * 2 + 60, H + m * 2)
    # Every scene draws the same shell, so the last one's widget list is the layout.
    LAYOUT.pop("widgets", None)

    def px(x):
        return m + x

    def py(y):
        return m + y

    # Bg first: the template is chrome only, and the addon paints its own opaque interior.
    canvas.fill(px(6), py(22), W - 12, H - 28, wowmock.rgb("0b0c0e"))
    index = ("CREATURES", "RARES", "SHINY", "INSTANCES").index(tab)
    portrait_frame_art(canvas, m, m, W, H, sigil, "FIELD GUIDE")
    strip_x, strip_y = px(W + 3), py(28)
    note("right tab strip", "tabs", strip_x, strip_y, 51, 60 * 4 + 3 * 3)
    for tab_index, tooltip in enumerate(TAB_TOOLTIPS):
        tab_x, tab_y = strip_x, strip_y + tab_index * 63
        canvas.draw(ui.atlas("questlog-tab-side"), tab_x, tab_y, 51, 60)
        icon_x, icon_y = tab_x + 9, tab_y + 15.5
        canvas.draw(ui.texture(TAB_ICON_PATHS[tab_index]), icon_x, icon_y, 29, 29)
        if tab_index == index:
            canvas.draw(ui.atlas("QuestLog-Tab-side-Glow-select"), tab_x, tab_y, 51, 60)
        note(f"tab plate {tab_index + 1} {tooltip.lower()}", "tabs", tab_x, tab_y, 51, 60)
    text(
        canvas,
        px(58),
        py(28),
        "Azeroth field journal",
        "GameFontDisableSmall",
        MUTED,
        justify="CENTER",
        width=W - 58 - 24,
    )

    if tab == "INSTANCES":
        view_x, view_y = px(18), py(104)
        text(canvas, view_x + 4, view_y + 4, "Instances", "GameFontNormalLarge", GOLD)
        text(
            canvas, view_x + 4, view_y + 26, "Boss encounters recorded on this character", "GameFontDisableSmall", MUTED
        )
        boss_rows = sorted(
            (
                (group["name"], boss["name"])
                for group in MOCK_INSTANCES.values()
                for boss in group["species"]
                if boss["boss"]
            ),
            key=lambda pair: (pair[0], pair[1]),
        )
        for row_index, (instance_name, boss_name) in enumerate(boss_rows[:4]):
            row_y = view_y + 48 + row_index * 92
            card(canvas, view_x, row_y, 884, 86)
            text(canvas, view_x + 12, row_y + 8, f"{instance_name} · {boss_name}", "GameFontNormal", TEXT, width=540)
            right(canvas, view_x + 872, row_y + 8, "0 recorded boss kills", "GameFontHighlightSmall", GOLD, width=180)
            right(canvas, view_x + 872, row_y + 27, "0 attempts recorded", "GameFontDisableSmall", MUTED, width=180)
            text(
                canvas,
                view_x + 12,
                row_y + 30,
                "Personal first boss clear: — · difficulty —",
                "GameFontDisableSmall",
                MUTED,
            )
        LAYOUT["canvas"] = {"width": canvas.width, "height": canvas.height, "scale": ui.scale}
        LAYOUT["frame"] = {"x": px(0), "y": py(0), "w": W, "h": H}
        LAYOUT.setdefault("scenes", [])
        return canvas

    breadcrumb = f"{zone['continent']} > {zone['name']}"
    text(canvas, px(24), py(44), breadcrumb, "GameFontNormal", TEXT)
    canvas.draw(
        ui.atlas("common-dropdown-c-button-hover-arrow"),
        px(28) + canvas.text_width(breadcrumb, FONTS["GameFontNormal"]),
        py(46),
        12,
        5,
    )
    search_box(canvas, px(24), py(62), 250, 24, "Search creatures")
    note("search", "input", px(24), py(62), 250, 24)
    ui_panel_button(canvas, px(288), py(62), 128, 24, "All")
    note("filter", "input", px(288), py(62), 128, 24)
    canvas.draw(ui.atlas("_UI-Frame-InnerTopTile"), px(18), py(94), W - 36, 3)

    # Left pane: the creature list.
    catalogued = sum(1 for s in zone["species"] if progress(s)["count"])
    rows = zone["species"]
    if tab == "RARES":
        rows = [s for s in rows if s["rare"] or progress(s)["rare"] >= RARE_TARGET]
    elif tab == "SHINY":
        rows = [s for s in rows if progress(s)["shiny"]]
    rows = rows or zone["species"]

    if len(rows) > 8:
        minimal_scrollbar(canvas, px(388), py(108), 440, visible=8 / len(rows))
    for row_index, row in enumerate(rows[:8]):
        state = progress(row)
        chosen = row["id"] == species["id"]
        y = py(104 + row_index * 58)
        canvas.fill(px(22), y, 344, 58, wowmock.rgb("2b2a24") if chosen else wowmock.rgb("212429"))
        canvas.draw(icons[row["id"]], px(28), y + 13, 32, 32)
        canvas.draw(ui.texture("interface/common/whiteiconframe.blp"), px(28), y + 13, 32, 32, BRASS)
        known = row["rare"] and state["rare"] >= RARE_TARGET
        # The kills figure is right-aligned from about px(308); a longer name is cut with an ellipsis so it never runs
        # under that figure and never stops mid-word without a mark.
        name = row["name"] if len(row["name"]) <= 26 else row["name"][:25].rstrip() + "\u2026"
        text(canvas, px(70), y + 8, name, "GameFontNormal", BLUE if known else TEXT, width=252)
        level = str(row["min"]) if row["min"] == row["max"] else f"{row['min']}\u2013{row['max']}"
        text(
            canvas,
            px(70),
            y + 27,
            f"{row['family']} \u00b7 Lv {level}",
            "GameFontDisableSmall",
            MUTED,
        )
        right(canvas, px(360), y + 8, f"{state['kills']} kills", "GameFontNormal", TEXT, width=64)
        complete = state["count"] >= 1 and bool(state["shiny"]) and (not row["rare"] or state["rare"] >= RARE_TARGET)
        if state["count"] >= MASTERED_AT:
            marker(canvas, px(342), y + 32, 11, GOLD)
        elif complete:
            canvas.draw(ui.atlas("common-icon-checkmark"), px(340), y + 27, 11, 11, GREEN)
        bar(canvas, px(28), y + 49, 332, 3, state["count"] / MASTERED_AT, GOLD)

    # Right pane: the selected creature's entry.
    state = progress(species)
    count = state["count"]
    rank = rank_of(count)
    rx, ry = px(426), py(104)

    # The portrait is circular: draw it on its own layer, mask that, then paste. canvas.mask multiplies the whole
    # surface's alpha, so applying it to the main canvas would erase everything outside the portrait's rect.
    portrait = ui.canvas(canvas.width, canvas.height)
    portrait.draw(icons[species["id"]], rx + 14, ry + 14, 58, 58)
    portrait.mask(ui.texture("interface/characterframe/tempportraitalphamask.blp"), rx + 14, ry + 14, 58, 58)
    canvas.paste(portrait, 0, 0)
    canvas.draw(ui.texture("interface/common/whiteiconframe.blp"), rx + 14, ry + 14, 58, 58, BRASS)
    text(canvas, rx + 84, ry + 18, species["name"], "GameFontNormalLarge", GOLD)
    level = str(species["min"]) if species["min"] == species["max"] else f"{species['min']}\u2013{species['max']}"
    text(
        canvas,
        rx + 84,
        ry + 40,
        f"{species['family']} \u00b7 {zone['name']} \u00b7 Level {level}",
        "GameFontDisableSmall",
        MUTED,
    )

    badges = [("Common", TEXT, True)]
    badges.append(("Rare variant known", BLUE, state["rare"] >= RARE_TARGET))
    badges.append(("Shiny seen", GOLD, bool(state["shiny"])))
    bx = rx + 14
    for label, colour, show in badges:
        if not show:
            continue
        width = max(50, canvas.text_width(label, FONTS["GameFontDisableSmall"]) + 14)
        card(canvas, bx, ry + 76, width, 18, colour)
        text(canvas, bx, ry + 76, label, "GameFontDisableSmall", colour, justify="CENTER", width=width, box_height=18)
        bx += width + 6
    note("Detail badges", "badge", rx + 14, ry + 76, bx - rx - 20, 18)

    # Research card.
    card(canvas, rx + 14, ry + 102, 488, 84)
    note("Research card", "card", rx + 14, ry + 102, 488, 84)
    text(canvas, rx + 24, ry + 109, "Research", "GameFontNormal", GOLD)
    for pip_index, name in enumerate(PIPS):
        x = rx + 14 + 28 + pip_index * 112
        on = rank >= pip_index + 1
        marker(canvas, x + 5, ry + 102 + 33, 11, GOLD if on else wowmock.rgb("4a4842"))
        if pip_index < len(PIPS) - 1:
            canvas.draw(
                ui.atlas("_UI-Frame-InnerTopTile"),
                x + 13,
                ry + 102 + 31,
                86,
                3,
                GOLD if rank >= pip_index + 2 else wowmock.rgb("3a382f"),
            )
        text(
            canvas,
            x - 39,
            ry + 102 + 42,
            name,
            "GameFontDisableSmall",
            TEXT if on else MUTED,
            justify="CENTER",
            width=88,
        )
    text(canvas, rx + 24, ry + 162, "Mastery", "GameFontDisableSmall", MUTED)
    right(
        canvas,
        rx + 14 + 488 - 10,
        ry + 162,
        f"{count} / 10 · {state['kills']} recorded deaths",
        "GameFontDisableSmall",
        TEXT,
        width=200,
    )
    bar(canvas, rx + 24, ry + 176, 468, 4, count / MASTERED_AT, GOLD)
    note("Research bar", "progress", rx + 24, ry + 176, 468, 4)

    # Lore card.
    card(canvas, rx + 14, ry + 196, 488, 58)
    note("Lore card", "card", rx + 14, ry + 196, 488, 58)
    text(canvas, rx + 24, ry + 203, "Lore", "GameFontNormal", GOLD)
    lore_font = FONTS["GameFontDisableSmall"]
    lines = wrap_pixels(species["lore"], lore_font, 468, 2, canvas)
    for line_index, line in enumerate(lines):
        text(canvas, rx + 24, ry + 217 + line_index * 12, line, "GameFontDisableSmall", wowmock.rgb("c4baa4"))

    # Variants.
    text(canvas, rx + 14, ry + 264, "Variants", "GameFontNormal", GOLD)
    variants = [
        ("Common", "Known" if count else "0 / 1", bool(count), TEXT),
        (
            "Rare variant",
            "Known" if state["rare"] >= RARE_TARGET else f"{state['rare']} / {RARE_TARGET}",
            state["rare"] >= RARE_TARGET,
            BLUE,
        ),
        (
            "Shiny variant",
            "Known" if state["shiny"] else f"{state['shiny']} / {SHINY_TARGET}",
            bool(state["shiny"]),
            GOLD,
        ),
    ]
    for variant_index, (title, status, known, colour) in enumerate(variants):
        vx = rx + 14 + variant_index * 165
        vy = ry + 280
        width = 158 if variant_index == 2 else 157
        card(canvas, vx, vy, width, 52, colour if known else wowmock.rgb("3a382f"))
        note(f"Variant card {variant_index + 1}", "card", vx, vy, width, 52)
        text(canvas, vx + 10, vy + 7, title, "GameFontNormal", TEXT)
        if known:
            canvas.draw(ui.atlas("common-icon-checkmark"), vx + width - 22, vy + 7, 12, 12, colour)
        else:
            right(canvas, vx + width - 10, vy + 7, "—", "GameFontNormal", MUTED, width=12)
        text(canvas, vx + 10, vy + 29, status, "GameFontDisableSmall", MUTED)

    # Cosmetic rewards.
    card(canvas, rx + 14, ry + 342, 488, 66)
    note("Rewards card", "card", rx + 14, ry + 342, 488, 66)
    text(canvas, rx + 24, ry + 349, "Cosmetic rewards", "GameFontNormal", GOLD)
    rewards = (
        ("Field sketch", "Discovered"),
        ("Ink study", "Observed"),
        ("Brass plate", "Studied"),
        ("Gilded entry", "Mastered"),
    )
    for reward_index, (label, tier) in enumerate(rewards):
        column, row_index = reward_index % 2, reward_index // 2
        col_x = rx + 24 + (248 if column else 0)
        col_right = rx + 14 + (482 if column else 234)
        ly = ry + 370 + row_index * 20
        unlocked = rank >= reward_index + 1
        text(canvas, col_x, ly, label, "GameFontDisableSmall", TEXT if unlocked else MUTED, width=104)
        if unlocked:
            canvas.draw(ui.atlas("common-icon-checkmark"), col_x + 112, ly, 12, 12, GREEN)
        else:
            text(canvas, col_x + 112, ly, "—", "GameFontNormal", MUTED, width=12)
        right(
            canvas,
            col_right,
            ly,
            "UNLOCKED" if unlocked else f"Locked · {tier}",
            "GameFontDisableSmall",
            GREEN if unlocked else MUTED,
            width=92,
        )

    # Your records: no synthetic records are shown unless the mock models the actual Lua session log.
    card(canvas, rx + 14, ry + 418, 488, 60)
    note("Your records card", "card", rx + 14, ry + 418, 488, 60)
    text(canvas, rx + 24, ry + 425, "Your records", "GameFontNormal", GOLD)
    record_lines = []
    record_stamp = f"{zone['name']} · 2026-10-22 10:00"
    if state["kills"]:
        record_lines.append(f"Personal first sighting: {record_stamp}")
        record_lines.append(f"First death observed: {record_stamp}")
    if state["rare"]:
        record_lines.append(f"First rare recorded: {record_stamp}")
    if state["shiny"]:
        record_lines.append(f"First shiny recorded: {record_stamp}")
    if not record_lines:
        record_lines.append("No sightings yet this session.")
    for line_index, line in enumerate(record_lines[:3]):
        text(canvas, rx + 24, ry + 439 + line_index * 12, line, "GameFontDisableSmall", MUTED)
    text(
        canvas,
        rx + 14,
        ry + 484,
        "Cosmetic only — the field guide never grants player power.",
        "GameFontDisableSmall",
        DIM,
    )
    note("Detail pane", "pane", rx, ry, 516, 528)

    # Bottom bar: zone completion and the two buttons, at the bar's own coordinates (the addon anchors them to the
    # bar, so a button starts BAR_W - inset - width from the bar's left, not from the window's).
    by = py(BAR_Y)
    card(canvas, px(BAR_X), by, BAR_W, BAR_H)
    note("bottom bar", "bar", px(BAR_X), by, BAR_W, BAR_H)
    button_y = by + BUTTON_TOP
    label = "ZONE COMPLETION"
    text(canvas, px(BAR_X + 14), by + 10, label, "GameFontDisableSmall", MUTED)
    fraction = catalogued / len(zone["species"])
    percent_x = BAR_X + 14 + canvas.text_width(label, FONTS["GameFontDisableSmall"]) + 8
    text(canvas, px(percent_x), by + 10, f"{round(fraction * 100)}%", "GameFontNormal", GOLD)
    right(
        canvas,
        px(BAR_X + 360),
        by + 10,
        f"{catalogued} of {len(zone['species'])} species",
        "GameFontDisableSmall",
        MUTED,
        width=140,
    )
    bar(canvas, px(BAR_X + 14), by + 28, 320, 10, fraction, GREEN)
    note("Bottom progress", "progress", px(BAR_X + 14), by + 28, 320, 10)
    ui_panel_button(canvas, px(OPEN_X), button_y, OPEN_W, BUTTON_H, "Open Journal")
    note("Open Journal", "button", px(OPEN_X), button_y, OPEN_W, BUTTON_H)
    ui_panel_button(canvas, px(TRACK_X), button_y, TRACK_W, BUTTON_H, "Track Species")
    note("Track Species", "button", px(TRACK_X), button_y, TRACK_W, BUTTON_H)
    if not LAYOUT.get("canvas"):
        LAYOUT["canvas"] = {"width": canvas.width, "height": canvas.height, "scale": ui.scale}
        LAYOUT["frame"] = {"x": px(0), "y": py(0), "w": W, "h": H}
        LAYOUT["scenes"] = []
    return canvas


ZONE_PAGE_COUNT = 12
README_RACE_ICONS = {
    "inv_misc_head_human_01.blp",
    "inv_misc_head_dwarf_01.blp",
    "inv_misc_head_orc_01.blp",
    "inv_misc_head_troll_01.blp",
    "inv_misc_head_tauren_01.blp",
    "inv_misc_head_elf_01.blp",
    "inv_misc_head_gnome_01.blp",
    "inv_misc_head_undead_01.blp",
}


def zone_pages(zones):
    """A spread of zones across the whole catalogue, not the first N: the README shows the range."""
    if len(zones) <= ZONE_PAGE_COUNT:
        return zones
    step = len(zones) / ZONE_PAGE_COUNT
    pages = [zones[int(index * step)] for index in range(ZONE_PAGE_COUNT)]

    def race_icons(zone):
        return {species_icon(species).rsplit("/", 1)[-1] for species in zone["species"][:8]} & README_RACE_ICONS

    selected = {zone["id"] for zone in pages}
    covered = set().union(*(race_icons(zone) for zone in pages))
    while covered != README_RACE_ICONS:
        candidate = max(
            (zone for zone in zones if zone["id"] not in selected),
            key=lambda zone: len(race_icons(zone) - covered),
            default=None,
        )
        if candidate is None or not race_icons(candidate) - covered:
            raise ValueError(f"No mock NPCs cover the required race icons: {sorted(README_RACE_ICONS - covered)}")
        replace = min(range(len(pages)), key=lambda index: len(race_icons(pages[index]) & covered))
        selected.remove(pages[replace]["id"])
        pages[replace] = candidate
        selected.add(candidate["id"])
        covered.update(race_icons(candidate))
    return pages


def main():
    ui = wowmock.Ui(scale=2)
    OUT.mkdir(parents=True, exist_ok=True)
    for obsolete in OUT.glob("creature-??.png"):
        obsolete.unlink()
    zones = load_catalogue()
    ui.wago.paths.update(MODEL_ICON_IDS)
    ui.wago.paths_file.write_text(json.dumps(ui.wago.paths, indent=1, sort_keys=True))
    catalogued_ids = {species["id"] for zone in zones for species in zone["species"]}
    instance_ids = {species["id"] for group in MOCK_INSTANCES.values() for species in group["species"]}
    boss_ids = {species["id"] for group in MOCK_INSTANCES.values() for species in group["species"] if species["boss"]}
    print(
        f"QuestieDB Forever fixture coverage: {len(zones)} outdoor areas, "
        f"{len(catalogued_ids | instance_ids)} placed NPCs, {len(MOCK_INSTANCES)} dungeons and raids, "
        f"{len(boss_ids)} rank-3 boss records."
    )
    current_ids = {zone["id"] for zone in zones}
    for previous in OUT.glob("zone-*.png"):
        if int(previous.stem.split("-")[1]) not in current_ids:
            previous.unlink()
    by_name = {zone["name"]: zone for zone in zones}
    # One client icon per species, resolved from generated NPC model icons before the shared fallbacks.
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
    badlands, siege_golem = pick("Badlands", lambda species: species["name"] == "Siege Golem")
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

    save(render(badlands, siege_golem, "CREATURES"), "field-guide.png")
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
        dialog, _, _ = basic_panel(ui, title, 602, 400)
        dialog_x = (canvas.image.width - dialog.image.width) // 2
        dialog_y = (canvas.image.height - dialog.image.height) // 2
        canvas.composite(dialog.image, dialog_x, dialog_y)
        content_x, content_y = 250, 238
        text(canvas, content_x, content_y, subtitle, "GameFontDisableSmall", MUTED)
        for index, line in enumerate(lines):
            y = content_y + 38 + index * 34
            canvas.draw(ui.atlas("common-icon-checkmark"), content_x, y + 3, 16, 16, GREEN)
            text(canvas, content_x + 28, y, line, "GameFontNormal", TEXT)
        return canvas

    # Show the native filter menu on the same all-species state as the All label and visible list.
    filtered = render(badlands, siege_golem)
    filter_menu, _ = context_menu(
        ui,
        [
            MenuTitle("Filter species"),
            MenuCheckbox("All", True),
            MenuCheckbox("Discovered", False),
            MenuCheckbox("Undiscovered", False),
            MenuCheckbox("Mastered", False),
            MenuCheckbox("Rare species", False),
            MenuCheckbox("Shiny seen", False),
        ],
    )
    # `scene()` adds 24 UI units of margin around the window; open the menu just below the filter button.
    filtered.composite(filter_menu.image, filtered.px(312), filtered.px(110))
    filtered.save(OUT / "search-filter.png")
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
    render(barrens, prowler, "INSTANCES").save(OUT / "instances-boss.png")
    feature_overlay(
        render(barrens, prowler),
        "Creature catalogue unavailable",
        "QuestieDB Forever is required for creature data",
        ["Install Questie or standalone QuestieDB", "Restart the client or type /reload"],
    ).save(OUT / "missing-questiedb.png")
    render_micro_menu_scenes()

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
            ("micro-menu-field-guide.png", "Field Guide micro menu button"),
            ("micro-menu-options.png", "Micro menu button settings"),
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
        render(barrens, prowler, "INSTANCES"),
        render(barrens, prowler, "RARES"),
        render(rare_zone, rare, "RARES"),
        render(rare_zone, rare, "SHINY"),
        render(shiny_zone, shiny, "SHINY"),
        render(*pick("Teldrassil", lambda s: not s["rare"])),
        render(*pick("Westfall", lambda s: s["rare"])),
        render(barrens, prowler, "CREATURES"),
    ]
    # One palette shared by every frame, sampled from all of them: per-frame adaptive palettes shift the colour of the
    # shared chrome and backdrop from frame to frame, and optimisation then leaks the previous frame through the
    # disposal, which reads as a torn background. Quantise once and clear each frame before the next is drawn.
    rgb_frames = [getattr(frame, "image", frame).convert("RGB") for frame in demo]
    palette_source = Image.new("RGB", (512, 8 * 395))
    for index, frame in enumerate(rgb_frames):
        palette_source.paste(frame.resize((512, 395)), (0, index * 395))
    palette = palette_source.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    palette_frames = [frame.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG) for frame in rgb_frames]
    palette_frames[0].save(
        OUT / "demo.gif",
        save_all=True,
        append_images=palette_frames[1:],
        duration=900,
        loop=0,
        optimize=False,
        disposal=2,
    )
    write_readme_gallery()
    (OUT / "layout.json").write_text(json.dumps(LAYOUT, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {len(list(OUT.glob('*.png')))} PNG scenes and updated README gallery")


if __name__ == "__main__":
    from PIL import Image  # ty: ignore[unresolved-import]  # Pillow is local only, like wowmock

    sys.exit(main())
