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
import dataclasses
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
MINIMAP_MOCKUPS = ROOT / "tools" / "minimap_mockups.py"


def render_minimap_scenes():
    with tempfile.TemporaryDirectory(prefix="field-guide-minimap-") as directory:
        subprocess.run([sys.executable, str(MINIMAP_MOCKUPS)], cwd=directory, check=True)
        for scene in ("minimap-field-guide.png", "minimap-options.png"):
            shutil.copy2(Path(directory) / scene, OUT / scene)


# UI/Art.lua's palette, as wowmock colour tuples.
GOLD = wowmock.rgb("e8bd63")
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
    "interface/icons/inv_chest_chain_05.blp",
)
TAB_TOOLTIPS = (
    ("Creatures", "Every creature of a zone, its sightings and variants"),
    ("Instances", "Boss encounters recorded on this character"),
)

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
MASTERED_AT = 10
PIPS = ("Discovered", "Observed", "Studied", "Mastered")
BRONZE = wowmock.rgb("c7875a")
SILVER = wowmock.rgb("c9d2dc")
GOLDC = wowmock.rgb("e8bd63")
SHINY = wowmock.rgb("bae6ff")
# Detail.lua's LADDER with Art.TIER_ICONS: the crafting quality marks, one per variant.
TIERS = (
    ("bronze", "Bronze", "Professions-Icon-Quality-Tier1", BRONZE, 1, True),
    ("silver", "Silver", "Professions-Icon-Quality-Tier2", SILVER, 25, False),
    ("gold", "Gold", "Professions-Icon-Quality-Tier3", GOLDC, 100, False),
    ("shiny", "Shiny", "Professions-Icon-Quality-Tier4", SHINY, 1000, False),
)
# Detail.lua's layout: the card, the sightings bar, the variant slots, then records beside the habitat map.
PANE_W, PANE_H = 582, 514
CARD_H, TEXT_X = 156, 120
BAR_WIDTH = PANE_W - 24 - TEXT_X
SECTION_X, VARIANTS_Y, LOWER_Y = 14, 172, 340
SLOT_SIZE, SLOT_MARK = 70, 46
SLOT_SPAN = (PANE_W - SECTION_X * 2) / 4
RECORDS_W = 250
HABITAT_X = SECTION_X + RECORDS_W + 20
HABITAT_W = PANE_W - SECTION_X - HABITAT_X
MAP_W, MAP_H = 174, 116
SIDE_X = HABITAT_X + MAP_W + 16
SIDE_W = PANE_W - SECTION_X - SIDE_X
# List.lua and Instances.lua: Pet Journal rows in a 330 wide inset.
LEFT_W, ROW_H, ROW_ART_H, ROW_W = 330, 55, 51, 300


def rank_of(count):
    rank = 0
    for step, threshold in enumerate((1, 3, 6, 10)):
        if count >= threshold:
            rank = step + 1
    return rank


# Fallback name rules mirror Art.SpeciesIcon in UI/Art.lua after the generated per-NPC model icon.
def load_art_species_icons():
    """Art.SPECIES_ICONS from UI/Art.lua, so the render and the addon cannot drift apart."""
    source = (ROOT / "UI" / "Art.lua").read_text(encoding="utf-8")
    marker = "Art.SPECIES_ICONS = {"
    start = source.index(marker) + len(marker)
    depth, index, in_string, escaped = 1, start, False, False
    while index < len(source) and depth:
        char = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        index += 1
    body = source[start : index - 1]
    rules = []
    for path, side, words in re.findall(r'\{\s*"([^"]+)",\s*"(any|beast|people)",\s*\{([^}]*)\}\s*,?\s*\}', body, re.S):
        icon = path.replace("\\\\", "/").lower()
        if not icon.endswith(".blp"):
            icon += ".blp"
        rules.append((icon, side, tuple(re.findall(r'"([^"]+)"', words))))
    return tuple(rules)


SPECIES_ICONS = load_art_species_icons()

# One client icon per family, Art.FAMILY_ICONS in UI/Art.lua.
FAMILY_ICONS = {
    "Beast": "interface/icons/ability_hunter_beasttaming.blp",
    "Humanoid": "interface/icons/inv_misc_head_human_01.blp",
    "Undead": "interface/icons/spell_shadow_raisedead.blp",
    "Dragonkin": "interface/icons/inv_misc_head_dragon_01.blp",
    "Elemental": "interface/icons/spell_nature_lightning.blp",
    "Giant": "interface/icons/ability_warrior_savageblow.blp",
    "Mechanical": "interface/icons/inv_misc_gear_01.blp",
    "Critter": "interface/icons/pet_type_critter.blp",
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
    icon_index = (packed >> 20) & 0xFF if packed else 0
    metadata = packed & 0xFFFFF if packed else 0
    type_id, family_id = (metadata >> 16, metadata & 0xFFFF) if packed else (0, 0)
    if icon_index:
        return MODEL_ICONS[icon_index]
    creature_type = CREATURE_TYPE_NAMES.get(type_id, "Unknown")
    beast = creature_type in ("Beast", "Critter") or family_id > 0
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
            creature_type = CREATURE_TYPE_NAMES.get((packed & 0xFFFFF) >> 16, "Unknown") if packed else "Unknown"
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
    shiny = 1 if (seed >> 13) % 23 == 0 else 0
    # A shiny is found on a recorded kill, so it always comes with at least one sighting.
    count = max((seed >> 7) % 11, shiny)
    return {
        "count": count,
        "kills": count + (seed >> 17) % 23,
        "bronze": count,
        "silver": (seed >> 5) % 3 if count > 3 else 0,
        "gold": 1 if count > 6 and (seed >> 9) % 3 == 0 else 0,
        "shiny": shiny,
    }


def best_tier(state):
    for tier, _, _, _, _, _ in reversed(TIERS):
        if state[tier]:
            return tier
    return None


def tier_totals(species_list):
    """Model.TierTotals: how many species in the list have each of the three standout coats."""
    totals = {"silver": 0, "gold": 0, "shiny": 0}
    for species in species_list:
        state = progress(species)
        for tier in totals:
            if state[tier]:
                totals[tier] += 1
    return totals


def tier_icon(canvas, tier, x, y, size, known=True):
    """Art.PaintTierIcon: the variant's quality mark, desaturated and dimmed while missing."""
    atlas = canvas.ui.atlas(next(item for item in TIERS if item[0] == tier)[2])
    if known:
        canvas.draw(atlas, x, y, size, size)
    else:
        canvas.draw(desaturated(atlas), x, y, size, size, (0.35, 0.35, 0.35, 0.8))


def desaturated(source):
    """Texture:SetDesaturated(true) on a texture or atlas member."""
    if isinstance(source, wowmock.Atlas):
        return dataclasses.replace(source, image=grey(source.image))
    return grey(source)


def grey(image):
    alpha = image.getchannel("A")
    out = image.convert("L").convert("RGBA")
    out.putalpha(alpha)
    return out


def bordered_icon(canvas, image, x, y, icon_size, border, collected, shade=1.0, desaturate=False):
    """Art.BorderedIcon: the icon at (x, y), the Collections item border of `border` centred on it."""
    canvas.draw(grey(image) if desaturate else image, x, y, icon_size, icon_size, (shade, shade, shade, 1))
    edge = (border - icon_size) / 2
    atlas = "collections-itemborder-collected" if collected else "collections-itemborder-uncollected"
    canvas.draw(canvas.ui.atlas(atlas), x - edge, y - edge, border, border)


def header(canvas, x, y, width, label):
    """Art.Header: the quest tracker's header band at its 30 height, the title centred on it 7 in."""
    canvas.draw(canvas.ui.atlas("UI-QuestTracker-Secondary-Objective-Header"), x, y, width, 30)
    text(canvas, x + 7, y, label, "GameFontNormalLarge", GOLD, box_height=30)


def objective_bar(canvas, x, y, width, ticks, fraction):
    """Art.ObjectiveBar: the world quest bar's track, yellow fill, three-piece border and a tick per quarter."""
    ui = canvas.ui
    canvas.draw(ui.atlas("objectivewidget-bar-background"), x + 4, y + 5, width - 8, 12)
    filled = (width - 8) * max(0, min(1, fraction))
    if filled > 0:
        canvas.draw(ui.atlas("ui-frame-bar-fill-yellow"), x + 4, y + 5, filled, 12)
    canvas.draw(ui.atlas("objectivewidget-bar-border-left"), x, y, 8, 22)
    canvas.draw(ui.atlas("objectivewidget-bar-border-middle"), x + 8, y, width - 16, 22)
    canvas.draw(ui.atlas("objectivewidget-bar-border-right"), x + width - 8, y, 8, 22)
    for index in range(1, ticks):
        canvas.draw(ui.atlas("ui-frame-bar-bordertick"), x + width * index / ticks - 5, y - 1, 10, 24)


ZONE_MAPS: dict[int, Any] = {}


def zone_map(ui, map_id):
    """Art.SetZoneMap: the uiMap's base art with every exploration overlay on top, fully explored."""
    if map_id not in ZONE_MAPS:
        try:
            image = wowmock.map_art(ui, map_id)
        except (KeyError, StopIteration):
            ZONE_MAPS[map_id] = None
            return None
        for overlay in wowmock.map_overlays(ui, map_id):
            wowmock.draw_overlay(
                ui, image, overlay.offset_x, overlay.offset_y, overlay.width, overlay.height, overlay.tiles
            )
        ZONE_MAPS[map_id] = image
    return ZONE_MAPS[map_id]


def truncate(canvas, value, font, width):
    while canvas.text_width(value, FONTS[font]) > width:
        value = value[:-2].rstrip() + "…"
    return value


def level_range(low, high):
    return str(low) if low == high else f"{low}-{high}"


def fraction_of_ranks(count):
    """Detail.UpdateResearch: each quarter of the bar is one rank, filled by the sightings between ranks."""
    bounds = (0, 1, 3, 6, MASTERED_AT)
    return sum(max(0, min(1, (count - low) / (high - low))) for low, high in zip(bounds, bounds[1:], strict=False)) / 4


def status_bar(canvas, x, y, w, h, fraction):
    """Art.StatusBar: the Professions skill bar, gold CoolDownManager bar fill inside the client's progress frame."""
    canvas.draw(canvas.ui.atlas("Profession-ProgressBar-BG"), x, y, w, h)
    filled = w * max(0, min(1, fraction))
    if filled:
        canvas.draw(canvas.ui.atlas("UI-HUD-CoolDownManager-Bar"), x, y, filled, h, GOLD)
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


FILTER_LABELS = {
    None: "All",
    "discovered": "Discovered",
    "undiscovered": "Undiscovered",
    "mastered": "Mastered",
    "silver": "Silver found",
    "gold": "Gold found",
    "shiny": "Shiny found",
    "missingShiny": "Missing shiny",
}
LAYOUT: dict[str, Any] = {}
MOCK_INSTANCES: dict[int, dict[str, Any]] = {}


def note(name, role, x, y, w, h, parent=None):
    """Record a widget rect (canvas units) for tools/visual_audit.py: bounds, overlaps and margins."""
    widget: dict[str, Any] = {
        "name": name,
        "role": role,
        "x": round(x, 1),
        "y": round(y, 1),
        "w": round(w, 1),
        "h": round(h, 1),
    }
    if parent:
        widget["parent"] = parent
    widgets: list[dict[str, Any]] = LAYOUT.setdefault("widgets", [])
    widgets.append(widget)


def zone_map_id(zone):
    """QuestieDB's area to uiMap table, overrides first, as Detail.UpdateLocation reads it."""
    map_source = (EXTRACTED / "QuestieDB/support/Forever/Zones/areaIdToUiMapId.lua").read_text()
    map_tables = {}
    for name, body in re.findall(r"ZoneDB.private.(\w+) = \[\[return \{(.*?)\}\]\]", map_source, re.S):
        map_tables[name] = {int(area): int(map_id) for area, map_id in re.findall(r"\[(\d+)\] = (\d+)", body)}
    return map_tables.get("areaIdToUiMapIdOverride", {}).get(
        zone["id"], map_tables.get("areaIdToUiMapId", {}).get(zone["id"], 0)
    )


def lua_table(name, pattern):
    """A table literal from UI/Art.lua, so the mock reads the same hand-mapped art the addon ships."""
    body = re.search(rf"Art.{name} = \{{(.*?)\n\}}", (ROOT / "UI/Art.lua").read_text(), re.S)
    assert body, name
    return dict(re.findall(pattern, body[1]))


def tab_tooltip(ui, index):
    """SidePanelTabButtonMixin:OnEnter with the addon's setup function: the tab's name, then its detail line."""
    title, detail = TAB_TOOLTIPS[index]
    return wowmock.tooltip(ui, [wowmock.TooltipLine(title), wowmock.TooltipLine(detail)])


def window(ui, zone, species, tab, icons, sigil, filter_key=None, tracked=False, unavailable=False, catalogue=None):
    """The journal as UI/Window.lua builds it: a real PortraitFrameTemplate (metal NineSlice, circular portrait,
    centred title, close button) around the addon's own list and detail panes at their own anchors."""
    m = 26
    strip_x, strip_y = m + W + 3, m + 28
    tip = tab_tooltip(ui, 1) if tab == "INSTANCES" else None
    # The Instances scene shows its tab's tooltip, anchored right of the tab, so the canvas grows to hold it.
    width = W + m * 2 + 60
    if tip:
        width = max(width, strip_x + 55 + tip.width + m)
    canvas = ui.canvas(width, H + m * 2)
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
    index = ("CREATURES", "INSTANCES").index(tab)
    portrait_frame_art(canvas, m, m, W, H, sigil, "Field Guide")
    if unavailable:
        # Window.body: the one inset shown only while the catalogue is missing, with the notice centred on the frame.
        note("Catalogue body", "pane", px(18), py(104), 924, 514)
        note("Catalogue notice", "content", px(140), py(344), 680, 36)
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

    note("right tab strip", "tabs", strip_x, strip_y, 55, 55 * 2 + 3)
    for tab_index, (title, _detail) in enumerate(TAB_TOOLTIPS):
        tab_x, tab_y = strip_x, strip_y + tab_index * 58
        side_tab(canvas, tab_x, tab_y, TAB_ICON_PATHS[tab_index], selected=tab_index == index)
        note(f"tab plate {tab_index + 1} {title.lower()}", "tabs", tab_x, tab_y, 55, 55)

    search_box(canvas, px(24), py(62), 250, 24, "Search instances" if tab == "INSTANCES" else "Search creatures")
    note("search", "input", px(24), py(62), 250, 24)
    canvas.draw(ui.atlas("_UI-Frame-InnerTopTile"), px(18), py(94), W - 36, 3)

    if tab == "INSTANCES":
        instances_view(ui, canvas, px, py, icons)
        if tip:
            # ANCHOR_RIGHT: the tooltip's bottom left on the Instances tab's top right.
            canvas.paste(tip, strip_x + 55, strip_y + 58 - tip.height)
        return canvas

    breadcrumb = f"{zone['continent']} > {zone['name']}"
    text(canvas, px(64), py(32), breadcrumb, "GameFontHighlightMedium", TEXT, box_height=20)
    canvas.draw(
        ui.atlas("common-dropdown-c-button-hover-arrow"),
        px(68) + canvas.text_width(breadcrumb, FONTS["GameFontHighlightMedium"]),
        py(32 + 7.5),
        12,
        5,
    )
    ui_panel_button(canvas, px(288), py(62), 128, 24, FILTER_LABELS[filter_key])
    note("filter", "input", px(288), py(62), 128, 24)

    # Left pane: List.lua's Pet Journal rows in their own inset.
    lx, ly = px(18), py(104)
    card(canvas, lx, ly, LEFT_W, PANE_H)
    note("Creature list", "list", lx, ly, LEFT_W, PANE_H)

    def matches(species):
        state = progress(species)
        if filter_key == "discovered" and not state["count"]:
            return False
        if filter_key == "undiscovered" and state["count"]:
            return False
        if filter_key == "mastered" and state["count"] < MASTERED_AT:
            return False
        if filter_key == "silver" and not state["silver"]:
            return False
        if filter_key == "gold" and not state["gold"]:
            return False
        if filter_key == "shiny" and not state["shiny"]:
            return False
        if filter_key == "missingShiny" and state["shiny"]:
            return False
        return True

    rows = [s for s in zone["species"] if matches(s)]
    view_h = PANE_H - 12
    selected_row = next((i for i, row in enumerate(rows) if row["id"] == species["id"]), 0)
    first_row = max(0, min(selected_row - 4, len(rows) - view_h // ROW_H))
    draw_rows(
        canvas,
        lx,
        ly,
        [
            {
                "icon": icons[row["id"]],
                "icon_size": 37,
                "icon_at": (8, 7),
                "name": row["name"],
                "sub": f"{row['family']} · Level {level_range(row['min'], row['max'])}",
                "known": progress(row)["count"] > 0,
                "mark": best_tier(progress(row)) if best_tier(progress(row)) != "bronze" else None,
                "selected": row["id"] == species["id"],
            }
            for row in rows[first_row : first_row + view_h // ROW_H + 1]
        ],
        len(rows),
        first_row,
    )

    detail(canvas, px(360), py(104), zone, species, icons)

    # Bottom bar: zone completion, how many species here have each standout variant, then the two buttons. The
    # addon anchors them to the bar, so a button starts BAR_W - inset - width from the bar's left.
    catalogued = sum(1 for s in zone["species"] if progress(s)["count"])
    bx, by = px(BAR_X), py(BAR_Y)
    card(canvas, bx, by, BAR_W, BAR_H)
    note("bottom bar", "bar", bx, by, BAR_W, BAR_H)
    label = "Zone completion"
    fraction = catalogued / len(zone["species"])
    text(canvas, bx + 14, by + 8, label, "GameFontNormalLarge", GOLD)
    label_w = canvas.text_width(label, FONTS["GameFontNormalLarge"])
    text(canvas, bx + 14 + label_w + 10, by + 8, f"{round(fraction * 100)}%", "GameFontNormalLarge", GOLD)
    right(canvas, bx + 334, by + 10, f"{catalogued} of {len(zone['species'])}", "GameFontHighlight", MUTED)
    status_bar(canvas, bx + 14, by + 32, 320, 12, fraction)
    note("Bottom progress", "progress", bx + 14, by + 32, 320, 12)
    x = bx + 370
    for tier in ("silver", "gold", "shiny"):
        value = str(sum(1 for s in zone["species"] if progress(s)[tier]))
        tier_icon(canvas, tier, x, by + 16, 26)
        text(canvas, x + 30, by + 16, value, "GameFontHighlightLarge", TEXT, box_height=26)
        x += 30 + canvas.text_width(value, FONTS["GameFontHighlightLarge"]) + 20
    note("Variant totals", "label", bx + 370, by + 16, x - 20 - bx - 370, 26)
    button_y = by + BUTTON_TOP
    ui_panel_button(canvas, px(OPEN_X), button_y, OPEN_W, BUTTON_H, "Open Journal")
    note("Open Journal", "button", px(OPEN_X), button_y, OPEN_W, BUTTON_H)
    ui_panel_button(canvas, px(TRACK_X), button_y, TRACK_W, BUTTON_H, "Tracking" if tracked else "Track Species")
    note("Track Species", "button", px(TRACK_X), button_y, TRACK_W, BUTTON_H)
    return canvas


def draw_rows(canvas, lx, ly, rows, total, first_row):
    """Pet Journal rows from the scroll frame's TOPLEFT (4, 6), clipped to its bottom, with the scroll bar."""
    ui = canvas.ui
    view_h = PANE_H - 12
    if total * ROW_H > view_h:
        minimal_scrollbar(
            canvas,
            lx + LEFT_W - 20,
            ly + 6,
            view_h,
            visible=view_h / (total * ROW_H),
            offset=first_row * ROW_H / (total * ROW_H - view_h),
        )
    clip = canvas.px(ly + 6 + view_h)
    below = canvas.image.crop((0, clip, canvas.image.width, canvas.image.height))
    for row_index, row in enumerate(rows):
        x, y = lx + 4, ly + 6 + row_index * ROW_H
        canvas.draw(ui.atlas("petlist-buttonbackground"), x, y, ROW_W, ROW_ART_H)
        if row["selected"]:
            canvas.draw(ui.atlas("petlist-buttonselect"), x, y, ROW_W, ROW_ART_H)
        known = row["known"]
        size = row["icon_size"]
        ix, iy = row["icon_at"]
        bordered_icon(canvas, row["icon"], x + ix, y + iy, size, 45, known, 1 if known else 0.5, not known)
        name = truncate(canvas, row["name"], "GameFontNormalLarge", 196)
        text(canvas, x + 58, y + 8, name, "GameFontNormalLarge", GOLD if known else MUTED)
        text(canvas, x + 58, y + 30, truncate(canvas, row["sub"], "GameFontHighlight", 196), "GameFontHighlight", MUTED)
        if row["mark"]:
            tier_icon(canvas, row["mark"], x + ROW_W - 12 - 26, y + (ROW_ART_H - 26) / 2, 26)
    canvas.image.paste(below, (0, clip))


def detail(canvas, rx, ry, zone, species, icons):
    """Detail.Create and Detail.Show: the Pet Journal card, the variants, then records beside the habitat."""
    ui = canvas.ui
    state = progress(species)
    count = state["count"]
    known = count > 0
    rank = rank_of(count)
    card(canvas, rx, ry, PANE_W, PANE_H)
    note("Detail pane", "pane", rx, ry, PANE_W, PANE_H)
    canvas.draw(ui.atlas("PetJournal-PetCard-BG"), rx + 4, ry + 4, PANE_W - 8, CARD_H)
    canvas.draw(ui.atlas("ChallengeMode-ThinDivider"), rx + 4, ry + 4 + CARD_H - 1, PANE_W - 8, 3)
    bordered_icon(canvas, icons[species["id"]], rx + 24, ry + 22, 72, 90, known, 1 if known else 0.12, not known)
    note("Detail portrait", "content", rx + 15, ry + 13, 90, 90, parent="Detail pane")

    tx = rx + TEXT_X
    text(canvas, tx, ry + 20, species["name"], "GameFontHighlightHuge", GOLD if known else MUTED, width=BAR_WIDTH)
    note("Detail name", "content", tx, ry + 20, BAR_WIDTH, 24, parent="Detail pane")
    sub = f"{species['family']} · {zone['name']} · Level {level_range(species['min'], species['max'])}"
    text(canvas, tx, ry + 50, sub, "GameFontHighlight", TEXT, width=BAR_WIDTH)
    note("Detail subtitle", "content", tx, ry + 50, BAR_WIDTH, 16, parent="Detail pane")
    if known:
        text(canvas, tx, ry + 78, PIPS[rank - 1], "GameFontNormalLarge", GOLD)
        right(canvas, rx + PANE_W - 24, ry + 80, f"{count} / {MASTERED_AT} sightings", "GameFontHighlight", width=220)
        objective_bar(canvas, tx, ry + 100, BAR_WIDTH, len(PIPS), fraction_of_ranks(count))
        note("Research bar", "progress", tx, ry + 100, BAR_WIDTH, 22, parent="Detail pane")
        span = BAR_WIDTH / len(PIPS)
        for pip_index, label in enumerate(PIPS):
            colour = TEXT if rank > pip_index else MUTED
            text(
                canvas,
                tx + pip_index * span,
                ry + 126,
                label,
                "GameFontHighlightSmall",
                colour,
                width=span,
                justify="CENTER",
            )
    else:
        text(canvas, tx, ry + 78, "Not yet in your journal", "GameFontNormalLarge", MUTED)
        text(
            canvas,
            tx,
            ry + 104,
            "Defeat one to add it, then watch for its rarer variants.",
            "GameFontHighlight",
            TEXT,
            width=BAR_WIDTH,
        )

    header(canvas, rx + SECTION_X, ry + VARIANTS_Y, 300, "Variants")
    note("Variants heading", "content", rx + SECTION_X, ry + VARIANTS_Y, 300, 30, parent="Detail pane")
    for slot_index, (tier, label, _atlas, colour, odds, every) in enumerate(TIERS):
        sx, sy = rx + SECTION_X + slot_index * SLOT_SPAN, ry + VARIANTS_Y + 40
        cx = sx + SLOT_SPAN / 2
        found = bool(state[tier])
        if found and tier == "shiny":
            glow = SLOT_SIZE + 52
            canvas.draw(
                ui.atlas("collections-upgradeglow"),
                cx - glow / 2,
                sy + SLOT_SIZE / 2 - glow / 2,
                glow,
                glow,
                blend="ADD",
            )
        atlas = "collections-itemborder-collected" if found else "collections-itemborder-uncollected"
        canvas.draw(ui.atlas(atlas), cx - SLOT_SIZE / 2, sy, SLOT_SIZE, SLOT_SIZE)
        tier_icon(canvas, tier, cx - SLOT_MARK / 2, sy + (SLOT_SIZE - SLOT_MARK) / 2, SLOT_MARK, found)
        text(
            canvas,
            sx,
            sy + SLOT_SIZE + 6,
            label,
            "GameFontNormalLarge",
            colour if found else MUTED,
            width=SLOT_SPAN,
            justify="CENTER",
        )
        if found:
            status = "Found" if tier == "shiny" else f"Found {state[tier]}"
        else:
            status = "Every spawn" if every else f"1 in {odds} spawns"
        text(
            canvas,
            sx,
            sy + SLOT_SIZE + 28,
            status,
            "GameFontHighlight",
            GREEN if found else MUTED,
            width=SLOT_SPAN,
            justify="CENTER",
        )
        note(f"{label} variant", "card", sx + 4, sy, SLOT_SPAN - 8, 112)

    header(canvas, rx + SECTION_X, ry + LOWER_Y, RECORDS_W, "Records")
    note("Records heading", "content", rx + SECTION_X, ry + LOWER_Y, RECORDS_W, 30, parent="Detail pane")
    if not known:
        pairs = [("Nothing recorded yet.", "")]
    else:
        top = best_tier(state)
        pairs = [("Sightings", str(count))]
        if state["kills"]:
            pairs.append(("Deaths recorded", str(state["kills"])))
        pairs += [("First seen", "22 Oct"), ("Last seen", "4 Nov")]
        if top:
            pairs.append(("Best variant", top.capitalize()))
    for pair_index, (key, value) in enumerate(pairs):
        y = ry + LOWER_Y + 40 + pair_index * 22
        key_w = RECORDS_W - 24 if value == "" else 130
        text(canvas, rx + SECTION_X + 12, y, key, "GameFontHighlight", MUTED, width=key_w)
        if value:
            right(canvas, rx + SECTION_X + RECORDS_W - 10, y, value, "GameFontHighlight", TEXT, width=RECORDS_W - 152)
    note("Records", "content", rx + SECTION_X, ry + LOWER_Y + 40, RECORDS_W, 22 * len(pairs), parent="Detail pane")

    hx = rx + HABITAT_X
    header(canvas, hx, ry + LOWER_Y, HABITAT_W, "Habitat")
    note("Habitat heading", "content", hx, ry + LOWER_Y, HABITAT_W, 30, parent="Detail pane")
    map_id = zone_map_id(zone)
    image = zone_map(ui, map_id) if map_id > 0 else None
    art_file = None if image else lua_table("LOCATION_ART", r"\[(\d+)\] = (\d+)").get(str(zone["id"]))
    ly = ry + LOWER_Y + 38
    if image or art_file:
        card(canvas, hx, ly, MAP_W + 6, MAP_H + 6)
        note("Habitat map", "card", hx, ly, MAP_W + 6, MAP_H + 6)
        if image:
            scaled = image.resize((round(MAP_W * ui.scale), round(MAP_H * ui.scale)), Image.Resampling.LANCZOS)
            canvas.draw(scaled, hx + 3, ly + 3, MAP_W, MAP_H)
        elif art_file:
            canvas.draw(ui.texture(int(art_file)), hx + 3, ly + 3, MAP_W, MAP_H)
    sx = rx + SIDE_X
    lines = wrap_pixels(zone["name"], FONTS["GameFontNormalLarge"], SIDE_W, 3, canvas)
    text(canvas, sx, ry + LOWER_Y + 42, "\n".join(lines), "GameFontNormalLarge", GOLD)
    note("Zone name", "content", sx, ry + LOWER_Y + 42, SIDE_W, 18 * len(lines), parent="Detail pane")
    if map_id > 0:
        button_y = ry + LOWER_Y + 38 + MAP_H - 18
        ui_panel_button(canvas, sx, button_y, SIDE_W, 24, "Open map")
        note("Open map", "button", sx, button_y, SIDE_W, 24)


# Encounter records for the Instances scene: boss name to (kills, first kill), by instance.
MOCK_ENCOUNTERS = {
    "Deadmines": {
        "Rhahk'Zor": (4, "18 Oct"),
        "Sneed": (4, "18 Oct"),
        "Gilnid": (3, "18 Oct"),
        "Mr. Smite": (3, "18 Oct"),
        "Captain Greenskin": (2, "21 Oct"),
        "Edwin VanCleef": (2, "21 Oct"),
        "Cookie": (0, None),
    },
    "Wailing Caverns": {
        "Lord Cobrahn": (2, "14 Oct"),
        "Kresh": (1, "14 Oct"),
        "Lord Pythas": (2, "14 Oct"),
        "Skum": (1, "14 Oct"),
        "Lord Serpentis": (1, "14 Oct"),
        "Verdan the Everliving": (1, "14 Oct"),
        "Mutanus the Devourer": (1, "14 Oct"),
    },
    "Shadowfang Keep": {
        "Rethilgore": (1, "2 Nov"),
        "Razorclaw the Butcher": (1, "2 Nov"),
        "Baron Silverlaine": (1, "2 Nov"),
        "Commander Springvale": (0, None),
        "Odo the Blindwatcher": (0, None),
        "Fenrus the Devourer": (0, None),
        "Wolf Master Nandos": (0, None),
        "Archmage Arugal": (0, None),
    },
}


def instance_groups():
    """Instances.Group: each instance's catalogue bosses with this character's records merged by name, records the
    catalogue lacks under their own instance, visited instances first and then by name."""
    groups = []
    for group in MOCK_INSTANCES.values():
        records = dict(MOCK_ENCOUNTERS.get(group["name"], {}))
        rows = []
        for species in group["species"]:
            if species["boss"]:
                kills, first = records.pop(species["name"], (0, None))
                rows.append({"name": species["name"], "kills": kills, "first": first, "tried": kills > 0})
        rows += [{"name": name, "kills": k, "first": f, "tried": True} for name, (k, f) in records.items()]
        groups.append(
            {
                "name": group["name"],
                "id": group["id"],
                "raid": group.get("instanceType") == 2,
                "species": group["species"],
                "rows": rows,
                "done": sum(1 for row in rows if row["kills"]),
                "visited": any(row["tried"] for row in rows),
            }
        )
    return sorted(groups, key=lambda group: (not group["visited"], group["name"]))


def instances_view(ui, canvas, px, py, icons):
    """UI/Instances.lua: the instance list on the left, the open instance's card and bosses on the right."""
    groups = instance_groups()
    open_group = groups[0]
    kind = "Raids" if open_group["raid"] else "Dungeons"
    text(canvas, px(64), py(32), f"{kind} > {open_group['name']}", "GameFontHighlightMedium", TEXT, box_height=20)
    instance_icons = lua_table("INSTANCE_ICONS", r'\[(\d+)\] = "([^"]+)"')

    def instance_icon(group):
        path = instance_icons.get(str(group["id"]), "Interface\\Icons\\INV_Misc_Book_09")
        # The Lua source escapes each backslash, so the table holds two per separator.
        return ui.texture(path.replace("\\\\", "/").replace("\\", "/").lower() + ".blp")

    lx, ly = px(18), py(104)
    card(canvas, lx, ly, LEFT_W, PANE_H)
    note("Instance list", "list", lx, ly, LEFT_W, PANE_H)
    draw_rows(
        canvas,
        lx,
        ly,
        [
            {
                "icon": instance_icon(group),
                "icon_size": 35,
                "icon_at": (8, 7),
                "name": group["name"],
                "sub": f"{group['done']} of {len(group['rows'])} bosses" if group["visited"] else "Not visited",
                "known": group["visited"],
                "mark": "gold" if group["rows"] and group["done"] == len(group["rows"]) else None,
                "selected": group is open_group,
            }
            for group in groups[: (PANE_H - 12) // ROW_H + 1]
        ],
        len(groups),
        0,
    )

    rx, ry = px(360), py(104)
    card(canvas, rx, ry, PANE_W, PANE_H)
    note("Instance pane", "pane", rx, ry, PANE_W, PANE_H)
    canvas.draw(ui.atlas("PetJournal-PetCard-BG"), rx + 4, ry + 4, PANE_W - 8, 120)
    canvas.draw(ui.atlas("ChallengeMode-ThinDivider"), rx + 4, ry + 3 + 120, PANE_W - 8, 3)
    bordered_icon(canvas, instance_icon(open_group), rx + 24, ry + 22, 72, 90, True)
    tx = rx + TEXT_X
    text(canvas, tx, ry + 20, open_group["name"], "GameFontHighlightHuge", GOLD, width=BAR_WIDTH)
    note("Instance name", "content", tx, ry + 20, BAR_WIDTH, 24, parent="Instance pane")
    levels = [(s["min"], s["max"]) for s in open_group["species"] if s["max"] > 1]
    sub = "Raid" if open_group["raid"] else "Dungeon"
    if levels:
        sub += f" · Level {level_range(min(lo for lo, _ in levels), max(hi for _, hi in levels))}"
    text(canvas, tx, ry + 50, sub, "GameFontHighlight", TEXT)
    rows = open_group["rows"]
    text(canvas, tx, ry + 78, f"{open_group['done']} of {len(rows)} bosses recorded", "GameFontNormalLarge", GOLD)
    header(canvas, rx + 14, ry + 140, 300, "Bosses")
    note("Bosses heading", "content", rx + 14, ry + 140, 300, 30, parent="Instance pane")
    by_name = {s["name"].lower(): s for s in open_group["species"]}
    boss_w = PANE_W - 46
    for row_index, row in enumerate(rows):
        x, y = rx + 16, ry + 180 + row_index * 44
        killed = row["kills"] > 0
        canvas.draw(ui.atlas("petlist-buttonbackground"), x, y, boss_w, 40)
        species = by_name.get(row["name"].lower())
        icon = icons.get(species["id"]) if species else None
        if icon is None:
            icon = ui.texture(species_icon(species) if species else "interface/icons/ability_hunter_beasttaming.blp")
        bordered_icon(canvas, icon, x + 8, y + 6, 28, 34, killed, 1 if killed else 0.5, not killed)
        text(canvas, x + 48, y, row["name"], "GameFontNormalLarge", GOLD if killed else MUTED, box_height=40)
        detail_text = "Not defeated yet"
        if killed:
            detail_text = f"{row['kills']} kill{'s' if row['kills'] != 1 else ''}"
            if row["first"]:
                detail_text += f" · first {row['first']}"
        canvas.text(
            x + boss_w - 14 - 220,
            y,
            detail_text,
            FONTS["GameFontHighlight"],
            TEXT if killed else MUTED,
            box_height=40,
            justify="RIGHT",
            width=220,
        )
        note(f"Boss row {row_index + 1}", "content", x, y, boss_w, 40, parent="Instance pane")

    bx, by = px(BAR_X), py(BAR_Y)
    card(canvas, bx, by, BAR_W, BAR_H)
    note("bottom bar", "bar", bx, by, BAR_W, BAR_H)
    cleared = sum(1 for group in groups if group["rows"] and group["done"] == len(group["rows"]))
    label = "Dungeons cleared"
    text(canvas, bx + 14, by + 8, label, "GameFontNormalLarge", GOLD)
    label_w = canvas.text_width(label, FONTS["GameFontNormalLarge"])
    text(canvas, bx + 14 + label_w + 10, by + 8, f"{cleared} of {len(groups)}", "GameFontNormalLarge", GOLD)
    status_bar(canvas, bx + 14, by + 32, 320, 12, cleared / len(groups))
    note("Cleared progress", "progress", bx + 14, by + 32, 320, 12)
    kills = sum(row["kills"] for group in groups for row in group["rows"])
    text(canvas, bx + 370, by + 16, f"{kills} boss kills recorded", "GameFontHighlightLarge", TEXT, box_height=26)


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
    silvers = [(zone, species) for zone, species in all_species if progress(species)["silver"]] or [(barrens, prowler)]
    golds = [(zone, species) for zone, species in all_species if progress(species)["gold"]] or silvers
    shinies = [(zone, species) for zone, species in all_species if progress(species)["shiny"]] or silvers
    silver_zone, silver = silvers[0]
    gold_zone, gold = golds[0]
    shiny_zone, shiny = shinies[0]
    rich_zone, rich = max(
        all_species,
        key=lambda pair: (progress(pair[1])["gold"], progress(pair[1])["silver"], progress(pair[1])["count"]),
    )

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
    # Darnassus has the critters and treants from the icon report in one list: Deer, Squirrel, Toad, the Ancients.
    icons_zone = by_name["Darnassus"]
    icons_species = next((species for species in icons_zone["species"] if species["name"] == "Deer"), None)
    if icons_species:
        save(render(icons_zone, icons_species, "CREATURES"), "creature-icons.png")
    save(render(rich_zone, rich, "CREATURES", "silver"), "variants.png")
    save(render(shiny_zone, shiny, "CREATURES", "shiny"), "shiny.png")

    for zone in zone_pages(zones):
        save(render(zone, zone["species"][0], "CREATURES"), f"zone-{zone['id']:04d}.png")

    search_zone = barrens
    search_species = next((s for s in barrens["species"] if not progress(s)["shiny"]), prowler)

    save(render(search_zone, prowler, "CREATURES", tracked=True), "tracking.png")
    save(render(silver_zone, silver, "CREATURES", "silver"), "silver-record.png")
    # The record itself, on the full list rather than the Shiny filter shown in shiny.png, for a shiny that no zone
    # page opens on, so it is not the same picture as that zone's render.
    record_zone, record = next(
        ((zone, species) for zone, species in shinies if species is not zone["species"][0]), (shiny_zone, shiny)
    )
    save(render(record_zone, record, "CREATURES"), "shiny-record.png")

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
            MenuCheckbox("Silver found", False),
            MenuCheckbox("Gold found", False),
            MenuCheckbox("Shiny found", False),
            MenuCheckbox("Missing shiny", True),
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
        "Show the records list",
        "Announce newly recorded creatures",
        "Show milestone toasts",
        "Share progress with guild and group addon users",
        "Minimap button",
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
    text(
        settings,
        36,
        222,
        "The Field Guide button can also be bound in Key Bindings > AddOns.",
        "GameFontDisableSmall",
        MUTED,
    )
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
    render_minimap_scenes()
    subprocess.run([sys.executable, str(ROOT / "tools" / "rarity.py")], check=True)
    subprocess.run([sys.executable, str(ROOT / "tools" / "discovery.py")], check=True)

    def write_gallery():
        features = [
            ("leaderboard.png", "Recorded kills leaderboard"),
            ("field-guide.png", "Creatures journal"),
            ("creature-icons.png", "Creature list icons in Darnassus"),
            ("variants.png", "Silver and gold coat filters"),
            ("silver-record.png", "Personal silver record"),
            ("shiny.png", "Shiny filter"),
            ("shiny-record.png", "Personal shiny record"),
            ("search-filter.png", "Search and status filter"),
            ("tracking.png", "Tracked species"),
            ("discovery-new-creature.png", "A first kill, announced like an explored area"),
            ("discovery-new-tag.png", "New tag in the journal"),
            ("discovery-toast-silver.png", "Silver milestone toast"),
            ("discovery-toast-gold.png", "Gold milestone toast"),
            ("discovery-toast-shiny.png", "Shiny milestone toast"),
            ("discovery-toast-mastered.png", "Mastery milestone toast"),
            ("discovery-toast-zone.png", "Zone milestone toast"),
            ("settings.png", "Settings canvas content"),
            ("minimap-field-guide.png", "Field Guide minimap button"),
            ("minimap-options.png", "Minimap button setting"),
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
        render(rich_zone, rich, "CREATURES", "silver"),
        render(silver_zone, silver, "CREATURES", "silver"),
        render(gold_zone, gold, "CREATURES", "gold"),
        render(shiny_zone, shiny, "CREATURES", "shiny"),
        render(*pick("Teldrassil", lambda s: not progress(s)["silver"])),
        render(*pick("Westfall", lambda s: progress(s)["gold"])),
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
    # Two gallery images showing one picture is a scene bug, not a render detail.
    seen = {}
    for image in sorted(OUT.glob("*.png")):
        seen.setdefault(image.read_bytes(), []).append(image.name)
    duplicates = [names for names in seen.values() if len(names) > 1]
    if duplicates:
        print(f"identical renders: {duplicates}", file=sys.stderr)
        return 1
    (OUT / "layout.json").write_text(json.dumps(LAYOUT, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {len(list(OUT.glob('*.png')))} PNG scenes and docs/gallery.md")


if __name__ == "__main__":
    sys.exit(main())
