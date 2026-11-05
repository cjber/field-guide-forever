#!/usr/bin/env python3
"""Mock screenshots of the Field Guide journal drawn with the client's own art (wowmock).

Every pixel that is not the addon's own layout comes from the WoW: Forever client build (nine-slice dialog border,
buttons, atlas gems, FRIZQT fonts, spell icons), fetched once from wago.tools and cached under
`tools/.cache/wowmock/`. This is a mock, not a capture: the frame is drawn the way UI/Window.lua draws it, at the
window's logical size, on wowmock's plain backdrop.

    python3 tools/mockups.py

Headless gallery scenes show the native model's icon fallback. FIELD_GUIDE_DESIGN_PREVIEW=1 writes a separate
layout preview; FIELD_GUIDE_MODEL_REFERENCE=/path/to/reference.webp may illustrate its Siege Golem viewport,
labelled as a composition reference. Neither environment option changes the gallery's model fidelity.

Deterministic: the specimen counts come from the species id, so a second run is byte-identical.
"""

import csv
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, NotRequired, TypedDict

from gen_creature_icons import model_paths
from gen_mock_catalogue import EXTRACTED, FIXTURE
from PIL import Image  # ty: ignore[unresolved-import]
from ui_art import BUILD as ART_BUILD

FOREVER_CORE = Path(os.environ.get("FOREVER_CORE", Path(__file__).resolve().parents[2] / "forever-core")).expanduser()
WOWMOCK = FOREVER_CORE / "tools" / "wowmock"
if not (WOWMOCK / "wowmock.py").is_file():
    raise SystemExit(f"wowmock.py not found in {WOWMOCK}; set FOREVER_CORE to the forever-core checkout")
sys.path.insert(0, str(WOWMOCK))
import wowmock  # noqa: E402  # ty: ignore[unresolved-import]
from wowmock import (  # noqa: E402  # ty: ignore[unresolved-import]
    FONTS,
    INSET_FRAME_LAYOUT,
    MenuCheckbox,
    MenuTitle,
    context_menu,
    draw_nine_slice,
    minimal_scrollbar,
    portrait_frame_art,
    search_box,
    side_tab,
    tiled,
    ui_panel_button,
)


class MockSpecies(TypedDict):
    id: int
    name: str
    family: str
    min: int
    max: int
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
# The settings page title: Blizzard's GameFontHighlightHuge, white FRIZQT at 20 (SystemFont_Shadow_Huge1).
FONTS["GameFontHighlightHuge"] = wowmock.Font(
    FONTS["GameFontHighlight"].path, 20, FONTS["GameFontHighlight"].color, (1, -1)
)
FONTS["GameFontDisableHuge"] = wowmock.Font(
    FONTS["GameFontDisableSmall"].path, 20, FONTS["GameFontDisableSmall"].color, (1, -1)
)
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

W, H = 960, 700
# UI/Window.lua's shell geometry, and the only place these numbers live in this file: the bottom bar is 924 wide at
# BOTTOMLEFT (18, 12), and each button is anchored to the bar's TOPRIGHT by its right inset, exactly as the addon
# anchors them. Drawing from the same arithmetic the Lua does is what keeps a render from drifting off the frame.
BAR_X, BAR_Y, BAR_W, BAR_H = 18, H - 12 - 58, 924, 58
BUTTON_H, BUTTON_TOP = 26, 16
OPEN_W, OPEN_RIGHT = 120, 140
TRACK_W, TRACK_RIGHT = 120, 12
OPEN_X = BAR_X + BAR_W - OPEN_RIGHT - OPEN_W
TRACK_X = BAR_X + BAR_W - TRACK_RIGHT - TRACK_W
MASTERED_AT, RARE_TARGET, SHINY_CHANCE = 10, 3, 500
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
    _, MODEL_ICON_IDS = model_paths(offline=False)
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
            "continent": continents.get(continent, parent_map[0] if parent_map else "Unknown location"),
            "species": [],
        }
    fixture = FIXTURE
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
        "rare": min(RARE_TARGET, (seed >> 11) % (RARE_TARGET + 1)) if species["rare"] else 0,
        "shiny": 1 if (seed >> 13) % 23 == 0 else 0,
    }


VARIANT_BORDERS = {
    "common": "loottoast-itemborder-white",
    "rare": "loottoast-itemborder-blue",
    "shiny": "loottoast-itemborder-gold",
}
SHINY_STAR = "Rare-Elite-Star"
CARD_W, CARD_H, CARD_GAP, CARD_ICON = 164, 219, 20, 72


def variant_states(species):
    """Model.Variants plus Model.HasRareForm for the fake character: known flags and the rare kill count."""
    state = progress(species)
    return {
        "common": state["count"] > 0,
        "rare": state["rare"] >= RARE_TARGET,
        "shiny": bool(state["shiny"]),
        "rare_form": bool(species["rare"]) or state["rare"] > 0,
        "rare_count": state["rare"],
    }


def variant_mark(canvas, kind, known, icon, x, y, size=16):
    """Art.VariantMark: the species icon in its quality border, or the gold star for shiny; dark while missing."""
    shade = 1 if known else 0.3
    if kind == "shiny":
        r, g, b = GOLD[:3]
        canvas.draw(canvas.ui.atlas(SHINY_STAR), x, y, size, size, (r * shade, g * shade, b * shade, 1))
        return
    tint = (shade, shade, shade, 1)
    canvas.draw(icon if known else icon.convert("LA").convert("RGBA"), x + 2, y + 2, size - 4, size - 4, tint)
    canvas.draw(canvas.ui.atlas(VARIANT_BORDERS[kind]), x, y, size, size, tint)


def variant_card(canvas, kind, states, icon, x, y):
    """One Detail card: the Appearances tab's card frame, the form's icon in its quality border, title and status."""
    ui = canvas.ui
    absent = kind == "rare" and not states["rare_form"]
    known = states[kind] and not absent
    if kind == "shiny" and known:
        glow = CARD_ICON + 48
        canvas.draw(
            ui.atlas("collections-upgradeglow"), x + (CARD_W - glow) / 2, y + 82 - glow / 2, glow, glow, blend="ADD"
        )
    border = "transmog-wardrobe-border-collected" if known else "transmog-wardrobe-border-uncollected"
    canvas.draw(ui.atlas(border), x, y, CARD_W, CARD_H, (1, 1, 1, 0.5 if absent else 1))
    ix, iy = x + (CARD_W - CARD_ICON) / 2, y + 82 - CARD_ICON / 2
    if not absent:
        if known:
            canvas.draw(icon, ix, iy, CARD_ICON, CARD_ICON)
        else:
            canvas.draw(icon.convert("LA").convert("RGBA"), ix, iy, CARD_ICON, CARD_ICON, (0.08, 0.08, 0.08, 1))
        edge = 1 if known else 0.45
        canvas.draw(
            ui.atlas(VARIANT_BORDERS[kind]), ix - 6, iy - 6, CARD_ICON + 12, CARD_ICON + 12, (edge, edge, edge, 1)
        )
        if not known:
            text(canvas, ix, iy + 25, "?", "GameFontDisableHuge", MUTED, width=CARD_ICON, justify="CENTER")
    if kind == "shiny" and known:
        cx, cy = ix + CARD_ICON / 2, iy + CARD_ICON / 2
        for dx, dy, size in ((0.36, -0.44, 16), (-0.44, -0.30, 11), (0.48, 0.20, 9)):
            canvas.draw(ui.atlas(SHINY_STAR), cx + dx * 96 - size / 2, cy + dy * 96 - size / 2, size, size, blend="ADD")
    if absent:
        title, status = "No rare form", "Only rare creatures have one"
    elif known:
        title, status = kind.capitalize(), "Collected"
    elif kind == "common":
        title, status = "Common", "Defeat one"
    elif kind == "rare":
        title, status = "Rare", f"{states['rare_count']} / {RARE_TARGET} rare kills"
    else:
        title, status = "Shiny", f"1 in {SHINY_CHANCE} per kill"
    colour = (BLUE if kind == "rare" else GOLD) if known else MUTED
    text(
        canvas,
        x,
        y + 150,
        title,
        "GameFontNormalLarge" if known else "GameFontNormal",
        colour,
        width=CARD_W,
        justify="CENTER",
    )
    text(
        canvas,
        x + 6,
        y + 176,
        status,
        "GameFontHighlightSmall" if known else "GameFontDisableSmall",
        GREEN if known else MUTED,
        width=CARD_W - 12,
        justify="CENTER",
    )


def variant_totals(species_list):
    """Model.VariantTotals: a species with no rare form adds nothing to the rare figures."""
    rare = rare_total = shiny = 0
    for species in species_list:
        states = variant_states(species)
        if states["rare_form"]:
            rare_total += 1
            rare += states["rare"]
        shiny += states["shiny"]
    return rare, rare_total, shiny, len(species_list)


def status_bar(canvas, x, y, w, h, fraction):
    """Art.StatusBar: the Professions skill bar, gold UI-StatusBar fill inside the client's progress frame."""
    canvas.draw(canvas.ui.atlas("Profession-ProgressBar-BG"), x, y, w, h)
    filled = w * max(0, min(1, fraction))
    if filled:
        canvas.draw(canvas.ui.texture("interface/targetingframe/ui-statusbar.blp"), x, y, filled, h, GOLD)
    canvas.draw(canvas.ui.atlas("Profession-ProgressBar-frame"), x, y, w, h)


def card(canvas, x, y, w, h, border=None):
    """A restrained inset using the client's InsetFrameTemplate NineSlice chrome."""
    marble = canvas.ui.texture("interface/framegeneral/ui-background-marble.blp")
    tiled(canvas, marble, x, y, w, h, marble.width / canvas.ui.scale, marble.height / canvas.ui.scale)
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


FILTER_LABELS = {None: "All", "missingShiny": "Missing shiny"}
LAYOUT: dict[str, Any] = {}
MOCK_INSTANCES: dict[int, dict[str, Any]] = {}


def note(name, role, x, y, w, h):
    """Record a widget rect (canvas units) for tools/visual_audit.py: bounds, overlaps and margins."""
    widgets: list[dict[str, Any]] = LAYOUT.setdefault("widgets", [])
    widgets.append({"name": name, "role": role, "x": round(x, 1), "y": round(y, 1), "w": round(w, 1), "h": round(h, 1)})


def window(ui, zone, species, tab, icons, sigil, filter_key=None, tracked=False, unavailable=False, catalogue=None):
    """The journal as UI/Window.lua builds it: a real PortraitFrameTemplate (metal NineSlice, circular portrait,
    centred title, close button) around the addon's own list and detail panes at their own anchors."""
    m = 26
    canvas = ui.canvas(W + m * 2 + 60, H + m * 2)
    # Each saved scene captures its own controls, including optional map navigation.
    LAYOUT["widgets"] = []
    LAYOUT["canvas"] = {"width": canvas.width, "height": canvas.height, "scale": ui.scale}
    LAYOUT["frame"] = {"x": m, "y": m, "w": W, "h": H}

    def px(x):
        return m + x

    def py(y):
        return m + y

    # PortraitFrameTexturedBaseTemplate supplies tiled rock, not a flat black fill.
    rock = ui.texture("interface/framegeneral/ui-background-rock.blp")
    tiled(canvas, rock, px(2), py(21), W - 4, H - 23, rock.width / ui.scale, rock.height / ui.scale)
    canvas.draw(ui.atlas("_UI-Frame-TopTileStreaks"), px(6), py(21), W - 8, 43)
    index = ("CREATURES", "RARES", "SHINY", "INSTANCES").index(tab)
    portrait_frame_art(canvas, m, m, W, H, sigil, "Field Guide")
    if unavailable:
        note("Catalogue body", "pane", px(18), py(104), 924, 514)
        note("Catalogue notice", "content", px(140), py(344), 680, 60)
        card(canvas, px(18), py(104), 924, 514)
        text(
            canvas,
            px(140),
            py(344),
            "Install QuestieDB or Questie to load the creature catalogue.\nhttps://www.curseforge.com/wow/addons/questie",
            "GameFontNormalLarge",
            TEXT,
            width=680,
            justify="CENTER",
        )
        return canvas

    strip_x, strip_y = px(W + 3), py(28)
    note("right tab strip", "tabs", strip_x, strip_y, 55, 55 * 4 + 3 * 3)
    for tab_index, tooltip in enumerate(TAB_TOOLTIPS):
        tab_x, tab_y = strip_x, strip_y + tab_index * 58
        side_tab(canvas, tab_x, tab_y, TAB_ICON_PATHS[tab_index], selected=tab_index == index)
        note(f"tab plate {tab_index + 1} {tooltip.lower()}", "tabs", tab_x, tab_y, 55, 55)

    card(canvas, px(18), py(104), 924, 514)

    if tab == "INSTANCES":
        view_x, view_y = px(18), py(104)
        note("Instances body", "pane", view_x, view_y, 924, 514)
        note("Instances title", "content", view_x + 4, view_y + 4, 884, 20)
        note("Instances subtitle", "content", view_x + 4, view_y + 26, 884, 16)
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
            note(f"Instance row {row_index + 1}", "content", view_x, row_y, 884, 86)
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
        return canvas

    breadcrumb = f"{zone['continent']} > {zone['name']}"
    text(canvas, px(64), py(32), breadcrumb, "GameFontNormal", TEXT)
    canvas.draw(
        ui.atlas("common-dropdown-c-button-hover-arrow"),
        px(68) + canvas.text_width(breadcrumb, FONTS["GameFontNormal"]),
        py(34),
        12,
        5,
    )
    search_box(canvas, px(24), py(62), 250, 24, "Search creatures")
    note("search", "input", px(24), py(62), 250, 24)
    ui_panel_button(canvas, px(288), py(62), 128, 24, FILTER_LABELS[filter_key])
    note("filter", "input", px(288), py(62), 128, 24)
    canvas.draw(ui.atlas("_UI-Frame-InnerTopTile"), px(18), py(94), W - 36, 3)

    # Window.UpdateProgress: rare and shiny collected here, then across every zone.
    every = [s for area in (catalogue or [zone]) for s in area["species"]]
    for index, (label, species_list) in enumerate(((zone["name"], zone["species"]), ("All zones", every))):
        rare, rare_total, shiny, shiny_total = variant_totals(species_list)
        values = f"Rare {rare} / {rare_total} · Shiny {shiny} / {shiny_total}"
        font = "GameFontHighlightSmall" if index == 0 else "GameFontDisableSmall"
        width = canvas.text_width(values, FONTS[font])
        right_edge, y = px(W - 24), py(30 + index * 18)
        right(canvas, right_edge, y, values, font, TEXT if index == 0 else MUTED, width=width)
        label_font = "GameFontNormalSmall" if index == 0 else "GameFontDisableSmall"
        right(canvas, right_edge - width - 10, y, label, label_font, GOLD if index == 0 else MUTED, width=160)
        span = width + 10 + canvas.text_width(label, FONTS[label_font])
        note(f"{label} totals", "header", right_edge - span, y, span, 12)

    # Left pane: the creature list.
    catalogued = sum(1 for s in zone["species"] if progress(s)["count"])
    rows = zone["species"]
    if tab in ("RARES", "SHINY"):
        rows = [s for area in (catalogue or [zone]) for s in area["species"]]
        rows = [s for s in rows if s["rare"]] if tab == "RARES" else [s for s in rows if progress(s)["shiny"]]
    if filter_key == "missingShiny":
        rows = [s for s in rows if not progress(s)["shiny"]]

    selected_row = next((i for i, row in enumerate(rows) if row["id"] == species["id"]), 0)
    first_row = max(0, min(selected_row - 5, len(rows) - 12))
    if len(rows) * 46 > 514:
        minimal_scrollbar(
            canvas,
            px(322),
            py(108),
            506,
            visible=514 / (len(rows) * 46),
            offset=first_row * 46 / (len(rows) * 46 - 514),
        )
    list_bottom = canvas.px(py(618))
    below_list = canvas.image.crop((0, list_bottom, canvas.image.width, canvas.image.height))
    for row_index, row in enumerate(rows[first_row : first_row + 12]):
        state = progress(row)
        chosen = row["id"] == species["id"]
        y = py(104 + row_index * 46)
        if chosen:
            canvas.draw(ui.texture("interface/questframe/ui-questtitlehighlight.blp"), px(18), y, 304, 46, blend="ADD")
        canvas.draw(icons[row["id"]], px(28), y + 5, 32, 32)
        states = variant_states(row)
        # Marks sit from x 230 (Art.CreateVariantMark slots); a longer name is cut with an ellipsis before them.
        name = row["name"]
        while canvas.text_width(name, FONTS["GameFontNormal"]) > 152:
            name = name[:-2].rstrip() + "…"
        text(canvas, px(70), y + 5, name, "GameFontNormal", TEXT, width=152)
        level = str(row["min"]) if row["min"] == row["max"] else f"{row['min']}-{row['max']}"
        text(
            canvas,
            px(70),
            y + 23,
            f"{row['family']} \u00b7 Lv {level}",
            "GameFontDisableSmall",
            MUTED,
        )
        for slot, kind in enumerate(("common", "rare", "shiny")):
            if kind == "rare" and not states["rare_form"]:
                continue
            mark_x = px(18 + 304 - 14 - (2 - slot) * 22 - 16)
            variant_mark(canvas, kind, states[kind], icons[row["id"]], mark_x, y + 15)

    canvas.image.paste(below_list, (0, list_bottom))

    # Detail.Create: the native 582x514 inset over Collections-background, the three variant cards, research,
    # records and the place.
    state = progress(species)
    count = state["count"]
    rank = rank_of(count)
    states = variant_states(species)
    rx, ry = px(360), py(104)
    card(canvas, rx, ry, 582, 514)
    canvas.draw(ui.atlas("Collections-background"), rx + 3, ry + 3, 576, 508)
    note("Detail pane", "pane", rx, ry, 582, 514)
    text(canvas, rx + 14, ry + 14, species["name"], "GameFontNormalLarge", GOLD, width=554)
    level = str(species["min"]) if species["min"] == species["max"] else f"{species['min']}-{species['max']}"
    text(
        canvas,
        rx + 14,
        ry + 38,
        f"{species['family']} · {zone['name']} · Level {level}",
        "GameFontHighlightSmall",
        TEXT,
        width=554,
    )
    left = (582 - (CARD_W * 3 + CARD_GAP * 2)) / 2
    for index, kind in enumerate(("common", "rare", "shiny")):
        cx = rx + left + index * (CARD_W + CARD_GAP)
        variant_card(canvas, kind, states, icons[species["id"]], cx, ry + 64)
        note(f"{kind.capitalize()} card", "card", cx, ry + 64, CARD_W, CARD_H)

    card(canvas, rx + 14, ry + 300, 554, 52)
    text(canvas, rx + 24, ry + 308, PIPS[rank - 1] if rank else "Research", "GameFontNormal", GOLD)
    right(
        canvas,
        rx + 558,
        ry + 308,
        f"{count} / 10 · {state['kills']} recorded deaths",
        "GameFontHighlightSmall",
        TEXT,
        width=350,
    )
    status_bar(canvas, rx + 24, ry + 330, 534, 12, count / MASTERED_AT)
    note("Research strip", "card", rx + 14, ry + 300, 554, 52)
    note("Research bar", "progress", rx + 24, ry + 330, 534, 12)

    records = []
    stamp = f"{zone['name']} · 2026-10-22 10:00"
    if state["kills"]:
        records.extend((f"Personal first sighting: {stamp}", f"First death observed: {stamp}"))
    if state["rare"]:
        records.append(f"First rare recorded: {stamp}")
    if state["shiny"]:
        records.append(f"First shiny recorded: {stamp}")
    text(canvas, rx + 14, ry + 370, "Records", "GameFontNormal", GOLD)
    for index, line in enumerate(records[:4] or ["No sightings yet this session."]):
        line = wrap_pixels(line, FONTS["GameFontHighlightSmall"], 350, 1, canvas)[0]
        text(canvas, rx + 14, ry + 392 + index * 14, line, "GameFontHighlightSmall", TEXT, width=350)
    note("Records", "content", rx + 14, ry + 370, 350, 102)

    art_table = re.search(r"Art.LOCATION_ART = \{(.*?)\n\}", (ROOT / "UI/Art.lua").read_text(), re.S)
    assert art_table
    locations = {int(zone_id): int(file) for zone_id, file in re.findall(r"\[(\d+)\] = (\d+)", art_table[1])}
    art_file = locations.get(zone["id"])
    map_source = (EXTRACTED / "QuestieDB/support/Forever/Zones/areaIdToUiMapId.lua").read_text()
    map_tables = {}
    for name, body in re.findall(r"ZoneDB.private.(\w+) = \[\[return \{(.*?)\}\]\]", map_source, re.S):
        map_tables[name] = {int(area): int(map_id) for area, map_id in re.findall(r"\[(\d+)\] = (\d+)", body)}
    map_id = map_tables.get("areaIdToUiMapIdOverride", {}).get(
        zone["id"], map_tables.get("areaIdToUiMapId", {}).get(zone["id"], 0)
    )
    if art_file:
        card(canvas, rx + 378, ry + 364, 190, 112)
        canvas.draw(ui.texture(art_file).crop((33, 0, 223, 128)), rx + 384, ry + 368, 178, 104)
        name = zone["name"]
        while canvas.text_width(name, FONTS["GameFontNormal"]) > 88:
            name = name[:-2].rstrip() + "…"
        text(canvas, rx + 378, ry + 484, name, "GameFontNormal", GOLD, width=88)
        note("Zone artwork frame", "card", rx + 378, ry + 364, 190, 112)
    if map_id > 0:
        ui_panel_button(canvas, rx + 470, ry + 480, 98, 22, "Open map")
        note("Open map", "button", rx + 470, ry + 480, 98, 22)

    # Bottom bar: zone completion and the two buttons, at the bar's own coordinates (the addon anchors them to the
    # bar, so a button starts BAR_W - inset - width from the bar's left, not from the window's).
    by = py(BAR_Y)
    card(canvas, px(BAR_X), by, BAR_W, BAR_H)
    note("bottom bar", "bar", px(BAR_X), by, BAR_W, BAR_H)
    button_y = by + BUTTON_TOP
    label = "Zone completion"
    text(canvas, px(BAR_X + 14), by + 10, label, "GameFontNormal", GOLD)
    fraction = catalogued / len(zone["species"])
    percent_x = BAR_X + 14 + canvas.text_width(label, FONTS["GameFontNormal"]) + 8
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
    status_bar(canvas, px(BAR_X + 14), by + 30, 320, 12, fraction)
    note("Bottom progress", "progress", px(BAR_X + 14), by + 30, 320, 12)
    ui_panel_button(canvas, px(OPEN_X), button_y, OPEN_W, BUTTON_H, "Open Journal")
    note("Open Journal", "button", px(OPEN_X), button_y, OPEN_W, BUTTON_H)
    ui_panel_button(canvas, px(TRACK_X), button_y, TRACK_W, BUTTON_H, "Tracking" if tracked else "Track Species")
    note("Track Species", "button", px(TRACK_X), button_y, TRACK_W, BUTTON_H)
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
    ui = wowmock.Ui(build=ART_BUILD, scale=2)
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
    current_ids = {zone["id"] for zone in zone_pages(zones)}
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
    rare_zone, rare = next(
        (
            (zone, species)
            for zone, species in all_species
            if species["rare"] and progress(species)["rare"] >= RARE_TARGET
        ),
        (barrens, prowler),
    )
    hunting_zone, hunting = next(
        (
            (zone, species)
            for zone, species in all_species
            if species["rare"] and 0 < progress(species)["rare"] < RARE_TARGET
        ),
        (rare_zone, rare),
    )
    shinies = [(zone, species) for zone, species in all_species if progress(species)["shiny"]] or [(barrens, prowler)]
    shiny_zone, shiny = shinies[0]
    second_zone, second_shiny = shinies[min(1, len(shinies) - 1)]

    def render(zone, species, tab="CREATURES", filter_key=None, tracked=False, unavailable=False):
        return wowmock.scene(
            ui, [(window(ui, zone, species, tab, icons, sigil, filter_key, tracked, unavailable, zones), 0, 0)]
        )

    def save(scene, name):
        scene.save(OUT / name)
        scenes: list[str] = LAYOUT.setdefault("scenes", [])
        scenes.append(name)
        LAYOUT.setdefault("scene_layouts", {})[name] = {
            "frame": dict(LAYOUT["frame"]),
            "canvas": dict(LAYOUT["canvas"]),
            "widgets": [dict(widget) for widget in LAYOUT["widgets"]],
        }

    if os.environ.get("FIELD_GUIDE_DESIGN_PREVIEW"):
        preview = render(badlands, siege_golem, "CREATURES")
        preview.save(ROOT / "docs/previews/field-guide-model-layout.png")
        print("Design preview only: CDN model is a composition reference, not an in-game capture.")
        return

    save(render(badlands, siege_golem, "CREATURES"), "field-guide.png")
    save(render(rare_zone, rare, "RARES"), "rares.png")
    save(render(shiny_zone, shiny, "SHINY"), "shiny.png")

    for zone in zone_pages(zones):
        save(render(zone, zone["species"][0], "CREATURES"), f"zone-{zone['id']:04d}.png")

    search_zone = barrens
    search_species = next((s for s in barrens["species"] if not progress(s)["shiny"]), prowler)

    save(render(search_zone, prowler, "CREATURES", tracked=True), "tracking.png")
    save(render(hunting_zone, hunting, "RARES"), "rare-record.png")
    save(render(second_zone, second_shiny, "SHINY"), "shiny-record.png")

    # Show the native filter menu on the same all-species state as the All label and visible list.
    filtered = render(search_zone, search_species, "CREATURES", "missingShiny")
    filter_menu, _ = context_menu(
        ui,
        [
            MenuTitle("Filter species"),
            MenuCheckbox("All", False),
            MenuCheckbox("Discovered", False),
            MenuCheckbox("Undiscovered", False),
            MenuCheckbox("Mastered", False),
            MenuCheckbox("Rare species", False),
            MenuCheckbox("Shiny seen", False),
            MenuCheckbox("Missing shiny", True),
            MenuCheckbox("Missing rare", False),
        ],
    )
    # `scene()` adds 24 UI units of margin around the window; open the menu just below the filter button.
    filtered.composite(filter_menu.image, filtered.px(312), filtered.px(110))
    save(filtered, "search-filter.png")
    # Core/Settings.lua registers this content in the client's Settings canvas, not a journal popup.
    settings = ui.canvas(620, 276)
    LAYOUT["widgets"] = []
    LAYOUT["canvas"] = {"width": settings.width, "height": settings.height, "scale": ui.scale}
    LAYOUT["frame"] = {"x": 0, "y": 0, "w": 620, "h": 276}
    note("Settings content", "pane", 12, 12, 596, 252)
    note("Settings title", "content", 16, 16, 380, 24)
    settings.fill(0, 0, 620, 276, wowmock.rgb("0d0f12"))
    text(settings, 16, 16, "Field Guide Forever options", "GameFontHighlightHuge", FONTS["GameFontHighlightHuge"].color)
    labels = [
        "Show undiscovered species",
        "Show the sighting log",
        "Announce newly recorded creatures",
        "Show milestone toasts",
        "Share progress with guild and group addon users",
        "Show the Field Guide micro menu button",
    ]
    for index, label in enumerate(labels):
        y = 48 + index * 28
        note(f"Settings checkbox {index + 1}", "content", 16, y, 26, 26)
        note(
            f"Settings label {index + 1}", "content", 46, y + 6, settings.text_width(label, FONTS["GameFontNormal"]), 16
        )
        settings.draw(ui.texture("interface/buttons/ui-checkbox-up.blp"), 16, y, 26, 26)
        settings.draw(ui.texture("interface/buttons/ui-checkbox-check.blp"), 16, y, 26, 26)
        text(settings, 46, y + 6, label, "GameFontNormal", GOLD)
    text(settings, 36, 222, "Both buttons can also be bound in Key Bindings > AddOns.", "GameFontDisableSmall", MUTED)
    note("Settings binding note", "content", 36, 222, 560, 16)
    save(settings, "settings.png")
    save(render(barrens, prowler, "CREATURES"), "sighting-log.png")
    save(render(barrens, prowler, unavailable=True), "missing-questiedb.png")
    save(render(barrens, prowler, "INSTANCES"), "instances-boss.png")
    output = subprocess.run(
        ["luajit", "tools/leaderboard_scene.lua"], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout.splitlines()
    font = wowmock.Font("fonts/arialn.ttf", 14, wowmock.rgb("ffffff"), (1, -1))
    measure = ui.canvas(1, 1)
    width = max(measure.text_width(line, font) for line in output) + 24
    height = len(output) * 22 + 16
    chat = ui.canvas(width, height)
    chat.fill(0, 0, width, height, wowmock.rgb("0d0f12"))
    LAYOUT["widgets"] = []
    LAYOUT["canvas"] = {"width": width, "height": height, "scale": ui.scale}
    LAYOUT["frame"] = {"x": 0, "y": 0, "w": width, "h": height}
    for index, line in enumerate(output):
        chat.text(12, 8 + index * 22, line, font)
        note(f"Leaderboard line {index + 1}", "content", 12, 8 + index * 22, width - 24, 16)
    save(chat, "leaderboard.png")
    render_micro_menu_scenes()
    subprocess.run([sys.executable, str(ROOT / "tools" / "rarity.py")], check=True)
    subprocess.run([sys.executable, str(ROOT / "tools" / "discovery.py")], check=True)

    def write_gallery():
        features = [
            ("leaderboard.png", "Recorded kills leaderboard"),
            ("field-guide.png", "Creatures journal"),
            ("rares.png", "Rares page"),
            ("rare-record.png", "Personal rare record"),
            ("shiny.png", "Shiny page"),
            ("shiny-record.png", "Personal shiny record"),
            ("search-filter.png", "Search and status filter"),
            ("tracking.png", "Tracked species"),
            ("discovery-new-creature.png", "A first kill, announced like an explored area"),
            ("discovery-new-tag.png", "New tag in the journal"),
            ("discovery-toast-rare.png", "Rare milestone toast"),
            ("discovery-toast-shiny.png", "Shiny milestone toast"),
            ("discovery-toast-mastered.png", "Mastery milestone toast"),
            ("discovery-toast-zone.png", "Zone milestone toast"),
            ("settings.png", "Settings canvas content"),
            ("micro-menu-field-guide.png", "Field Guide micro menu button"),
            ("micro-menu-options.png", "Micro menu button settings"),
            ("sighting-log.png", "Sighting records"),
            ("rarity-target.png", "Target frame rarity"),
            ("rarity-nameplates.png", "Nameplate rarity"),
            ("rarity-elite.png", "Elite rarity chrome"),
            ("instances-boss.png", "Instance boss record"),
            ("missing-questiedb.png", "QuestieDB install prompt"),
        ]
        gallery = ["![A short walk through the journal](screenshots/demo.gif)", "", "## Feature previews", ""]
        gallery.extend(f"![{label}](screenshots/{filename})\n" for filename, label in features)
        gallery += ["## Zone pages", "", "| | | |", "| --- | --- | --- |"]
        row = []
        for zone in zone_pages(zones):
            filename = f"zone-{zone['id']:04d}.png"
            row.append(f"![{zone['name']}](screenshots/{filename})")
            if len(row) == 3:
                gallery.append("| " + " | ".join(row) + " |")
                row = []
        if row:
            row.extend([""] * (3 - len(row)))
            gallery.append("| " + " | ".join(row) + " |")
        # Every scene, for review. README and the store page pick their headline images by hand (WFA-10, WFA-25).
        header = [
            "# Screenshot gallery",
            "",
            "Every scene `tools/mockups.py` renders. Written by that script; do not edit by hand.",
            "",
        ]
        (ROOT / "docs" / "gallery.md").write_text("\n".join(header + gallery) + "\n", encoding="utf-8")

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
    # Half the scene scale (960 px wide), so the GIF stays under the stores' 2 MB limit per image.
    rgb_frames = [getattr(frame, "image", frame).convert("RGB") for frame in demo]
    demo_size = (960, round(rgb_frames[0].height * 960 / rgb_frames[0].width))
    rgb_frames = [frame.resize(demo_size, Image.Resampling.LANCZOS) for frame in rgb_frames]
    palette_source = Image.new("RGB", (512, len(rgb_frames) * 395))
    for index, frame in enumerate(rgb_frames):
        palette_source.paste(frame.resize((512, 395)), (0, index * 395))
    palette = palette_source.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    # No dither: dithered noise defeats GIF compression.
    palette_frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in rgb_frames]
    palette_frames[0].save(
        OUT / "demo.gif",
        save_all=True,
        append_images=palette_frames[1:],
        duration=900,
        loop=0,
        optimize=False,
        disposal=2,
    )
    write_gallery()
    (OUT / "layout.json").write_text(json.dumps(LAYOUT, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {len(list(OUT.glob('*.png')))} PNG scenes and docs/gallery.md")


if __name__ == "__main__":
    sys.exit(main())
