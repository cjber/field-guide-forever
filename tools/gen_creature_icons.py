#!/usr/bin/env python3
"""Generate compact NPC model icons and type/family metadata from pinned sources."""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import io
import json
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUT = ROOT / "Data" / "CreatureIcons.lua"
QUESTIE_TSV = CACHE / "questiedb-mock-catalogue-v1.0.6.tsv"
CMANGOS_COMMIT = "77b848e78fe31bdd0c5562922be49a4e8e5e79df"
CMANGOS_FILE = "ClassicDB_1_12_1_z2815.sql.gz"
CMANGOS_SHA256 = "4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0"
CMANGOS_URL = f"https://raw.githubusercontent.com/cmangos/classic-db/{CMANGOS_COMMIT}/Full_DB/{CMANGOS_FILE}"
DISPLAY_CSV = CACHE / "CreatureDisplayInfo-1.60.1.70450.csv"
MODEL_CSV = CACHE / "CreatureModelData-1.60.1.70450.csv"
MODEL_SHA256 = "8b05d7de99d4ebdd34d8001bfde0f4c9c75af44bcd6dfc627bb405e09b94509d"
LISTFILE_TAG = "202610202236"
LISTFILE_URL = f"https://github.com/wowdev/wow-listfile/releases/download/{LISTFILE_TAG}/community-listfile.csv"
LISTFILE_SHA256 = "4af8062799478d6f7a038ac9b9f3df1d9d519230e369e1bb399ff0ab41507fd6"
MODEL_PATHS = CACHE / f"creature-model-paths-{LISTFILE_TAG}.json"
MODEL_DATA_URL = "https://wago.tools/db2/CreatureModelData/csv?build=1.60.1.70450"
AGENT = "FieldGuideForever species icon generator (+https://github.com/cjber/field-guide-forever)"
MAX_RECORDS = 20_000
MAX_PACKAGED_BYTES = 220_000  # measured output: 215,402 bytes, +21,058 from the 194,344-byte baseline

# Ordered model stem rules. Specific stems come before broad race/family matches.
STEM_ICONS = (
    (("human", "vrykul"), "inv_misc_head_human_01"),
    (("dwarf",), "inv_misc_head_dwarf_01"),
    (("orc",), "inv_misc_head_orc_01"),
    (("troll",), "inv_misc_head_troll_01"),
    (("tauren",), "inv_misc_head_tauren_01"),
    (("nightelf", "night_elf", "nelf", "bloodelf", "highelf"), "inv_misc_head_elf_01"),
    (("gnome", "clockworkgnome"), "inv_misc_head_gnome_01"),
    (
        ("scourge", "undead", "skeleton", "zombie", "ghoul", "ghost", "banshee", "shade", "wight", "lich"),
        "inv_misc_head_undead_01",
    ),
    (("murloc",), "inv_misc_head_murloc_01"),
    (("kobold",), "inv_misc_head_kobold_01"),
    (("gnoll",), "inv_misc_head_gnoll_01"),
    (("centaur",), "inv_misc_head_centaur_01"),
    (("quillboar",), "inv_misc_head_quillboar_01"),
    (("nerubian",), "inv_misc_head_nerubian_01"),
    (("tuskarr",), "inv_misc_head_tuskarr"),
    (("dragonblack", "blackdragon"), "inv_misc_head_dragon_black"),
    (("dragonblue", "bluedragon"), "inv_misc_head_dragon_blue"),
    (("dragonbronze", "bronzedragon"), "inv_misc_head_dragon_bronze"),
    (("dragongreen", "greendragon"), "inv_misc_head_dragon_green"),
    (("dragonred", "reddragon"), "inv_misc_head_dragon_red"),
    (("dragon", "drake", "whelp"), "inv_misc_head_dragon_01"),
    (("naga", "siren", "lobstrok"), "inv_misc_nagamale"),
    (("gryphon",), "ability_mount_gryphon_01"),
    (("wyvern",), "ability_mount_wyvern_01"),
    (("hippogryph",), "ability_mount_warhippogryph"),
    (("ridinghorse", "horse"), "ability_mount_ridinghorse"),
    (("kodo",), "ability_mount_kodo_01"),
    (("raptor",), "ability_mount_raptor"),
    (("mechastrider",), "ability_mount_mechastrider"),
    (("cat", "tiger", "panther", "lion", "sabre"), "ability_hunter_pet_cat"),
    (("hyena",), "ability_hunter_pet_hyena"),
    (("wolf", "worg", "dog", "hound"), "ability_hunter_pet_wolf"),
    (("bear",), "ability_hunter_pet_bear"),
    (("boar",), "ability_hunter_pet_boar"),
    (("spider", "tarantula"), "ability_hunter_pet_spider"),
    (("crocolisk", "crocodile"), "ability_hunter_pet_crocolisk"),
    (("turtle",), "ability_hunter_pet_turtle"),
    (("scorpid",), "ability_hunter_pet_scorpid"),
    (("scorpion",), "ability_hunter_pet_scorpid"),
    (("bat",), "ability_hunter_pet_bat"),
    (("carrionbird", "buzzard", "vulture"), "ability_hunter_pet_vulture"),
    (("thunderhawk", "windserpent", "serpent"), "ability_hunter_pet_windserpent"),
    (("parrot", "owl", "strigid", "screecher", "swoop", "condor", "razorbeak"), "ability_hunter_pet_owl"),
    (("moth",), "ability_hunter_pet_moth"),
    (("rhino",), "ability_hunter_pet_rhino"),
    (("devilsaur",), "ability_hunter_pet_devilsaur"),
    (("corehound",), "ability_hunter_pet_corehound"),
    (("dragonhawk",), "ability_hunter_pet_dragonhawk"),
    (("ravager",), "ability_hunter_pet_ravager"),
    (("warp",), "ability_hunter_pet_warpstalker"),
    (("sporebat",), "ability_hunter_pet_sporebat"),
    (("wasp",), "ability_hunter_pet_wasp"),
    (("crab",), "ability_hunter_pet_crab"),
    (("gorilla",), "ability_hunter_pet_gorilla"),
    (("raptor",), "ability_hunter_pet_raptor"),
    (("tallstrider", "strider"), "ability_hunter_pet_tallstrider"),
    (("gorilla",), "ability_hunter_pet_gorilla"),
    (("crab",), "ability_hunter_pet_crab"),
    (("silithid", "qiraji", "quiraj"), "ability_hunter_pet_silithid"),
    (("cryptfiend",), "inv_misc_head_nerubian_01"),
    (("worm", "grub"), "ability_hunter_pet_worm"),
    (("wasp",), "ability_hunter_pet_wasp"),
    (("vulture",), "ability_hunter_pet_vulture"),
    (("windserpent",), "ability_hunter_pet_windserpent"),
    (("owl",), "ability_hunter_pet_owl"),
    (("moth",), "ability_hunter_pet_moth"),
    (("chimera",), "ability_hunter_pet_chimera"),
    (("rhino",), "ability_hunter_pet_rhino"),
    (("devilsaur",), "ability_hunter_pet_devilsaur"),
    (("corehound",), "ability_hunter_pet_corehound"),
    (("dragonhawk",), "ability_hunter_pet_dragonhawk"),
    (("ravager",), "ability_hunter_pet_ravager"),
    (("warp",), "ability_hunter_pet_warpstalker"),
    (("sporebat",), "ability_hunter_pet_sporebat"),
    (
        ("demon", "satyr", "felguard", "imp", "infernal", "grell", "succubus", "doomguard", "voidwalker", "dreadlord"),
        "spell_shadow_metamorphosis",
    ),
    (("elemental", "salamander", "fire", "lava"), "spell_fire_immolation"),
    (("water",), "spell_frost_summonwaterelemental"),
    (("earth",), "spell_nature_earthquake"),
    (("wind", "air"), "spell_nature_lightning"),
    (("mechanical", "golem", "construct", "clockwork", "robot"), "inv_misc_gear_01"),
    (("giant",), "ability_warrior_savageblow"),
    (("ooze", "slime", "aberration"), "ability_creature_poison_01"),
)

CREATURE_TYPES = {
    0: "Unknown",
    1: "Beast",
    2: "Dragonkin",
    3: "Demon",
    4: "Elemental",
    5: "Giant",
    6: "Undead",
    7: "Humanoid",
    8: "Critter",
    9: "Mechanical",
    10: "Unknown",
    11: "Unknown",
    12: "Critter",
    13: "Unknown",
}


def source_bytes(offline: bool) -> bytes:
    path = CACHE / CMANGOS_FILE
    if not path.is_file():
        if offline:
            raise SystemExit(f"Missing cached CMaNGOS source: {path}")
        CACHE.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(CMANGOS_URL, headers={"User-Agent": AGENT})
        path.write_bytes(urllib.request.urlopen(request, timeout=120).read())
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != CMANGOS_SHA256:
        raise SystemExit(f"CMaNGOS source checksum mismatch: expected {CMANGOS_SHA256}, got {digest}")
    return data


def pinned_file(path: Path, url: str, offline: bool) -> bytes:
    if not path.is_file():
        if offline:
            raise SystemExit(f"Missing cached pinned source: {path}")
        CACHE.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(url, headers={"User-Agent": AGENT})
        path.write_bytes(urllib.request.urlopen(request, timeout=120).read())
    return path.read_bytes()


def model_paths(offline: bool) -> tuple[dict[int, str], dict[str, int]]:
    if not MODEL_PATHS.is_file():
        if offline:
            raise SystemExit(f"Missing cached pinned listfile subset: {MODEL_PATHS}")
        CACHE.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(LISTFILE_URL, headers={"User-Agent": AGENT})
        digest = hashlib.sha256()
        models: dict[int, str] = {}
        icons: dict[str, int] = {}
        candidates = {f"interface/icons/{icon}.blp" for _, icon in STEM_ICONS}
        with urllib.request.urlopen(request, timeout=240) as response:
            while line := response.readline():
                digest.update(line)
                try:
                    file_id, path = line.decode("utf-8").rstrip("\r\n").split(";", 1)
                except ValueError:
                    continue
                normalized = path.lower()
                if normalized.startswith(("creature/", "character/")) and normalized.endswith(".m2"):
                    models[int(file_id)] = normalized
                elif normalized in candidates:
                    icons[normalized] = int(file_id)
        if digest.hexdigest() != LISTFILE_SHA256:
            raise SystemExit(f"Pinned listfile checksum mismatch: {digest.hexdigest()}")
        MODEL_PATHS.write_text(json.dumps({"models": models, "icons": icons}, separators=(",", ":")))
    cached = json.loads(MODEL_PATHS.read_text(encoding="utf-8"))
    return {int(k): v for k, v in cached["models"].items()}, {k: int(v) for k, v in cached["icons"].items()}


def model_mapping(offline: bool, npc_ids: set[int]) -> tuple[dict[int, str], dict[str, int]]:
    display_data = pinned_file(
        DISPLAY_CSV, "https://wago.tools/db2/CreatureDisplayInfo/csv?build=1.60.1.70450", offline
    )
    model_data = pinned_file(MODEL_CSV, MODEL_DATA_URL, offline)
    if hashlib.sha256(model_data).hexdigest() != MODEL_SHA256:
        raise SystemExit("CreatureModelData checksum mismatch")
    display_to_model = {}
    for row in csv.DictReader(io.StringIO(display_data.decode("utf-8"))):
        display_to_model[int(row["ID"])] = int(row["ModelID"])
    model_to_file = {}
    for row in csv.DictReader(io.StringIO(model_data.decode("utf-8"))):
        model_to_file[int(row["ID"])] = int(row["FileDataID"])
    paths, icon_paths = model_paths(offline)
    source = source_bytes(offline)
    with gzip.GzipFile(fileobj=io.BytesIO(source)) as compressed:
        found: dict[int, str] = {}
        for raw_line in compressed:
            line = raw_line.decode("latin1")
            if not line.startswith("INSERT INTO `creature_template` VALUES "):
                continue
            for row in sql_tuples(line):
                npc_id = int(row[0])
                if npc_id not in npc_ids:
                    continue
                display_id = int(row[5])
                model_id = display_to_model.get(display_id)
                file_id = model_to_file.get(model_id, 0)
                if file_id in paths:
                    found[npc_id] = paths[file_id]
    return found, icon_paths


def stem_icon(path: str) -> str | None:
    stem = path.rsplit("/", 1)[-1].removesuffix(".m2").lower().replace("_", "")
    for needles, icon in STEM_ICONS:
        if any(needle.replace("_", "") in stem for needle in needles):
            return icon
    return None


def questie_ids(offline: bool) -> set[int]:
    if not QUESTIE_TSV.is_file():
        if offline:
            raise SystemExit(f"Missing cached QuestieDB mock catalogue: {QUESTIE_TSV}")
        subprocess.run([sys.executable, "tools/gen_mock_catalogue.py"], cwd=ROOT, check=True)
    return {int(line.split("\t", 1)[0]) for line in QUESTIE_TSV.read_text(encoding="utf-8").splitlines()}


def sql_tuples(line: str):
    """Yield comma-separated SQL tuple fields while respecting quoted strings and escapes."""
    index = line.find("VALUES ") + len("VALUES ")
    while index < len(line):
        while index < len(line) and line[index] in " ,;":
            index += 1
        if index >= len(line) or line[index] != "(":
            return
        index += 1
        start = index
        fields = []
        quoted = False
        while index < len(line):
            char = line[index]
            if quoted:
                if char == "\\":
                    index += 2
                    continue
                if char == "'":
                    if index + 1 < len(line) and line[index + 1] == "'":
                        index += 2
                        continue
                    quoted = False
            elif char == "'":
                quoted = True
            elif char == ",":
                fields.append(line[start:index].strip())
                start = index + 1
            elif char == ")":
                fields.append(line[start:index].strip())
                index += 1
                yield fields
                break
            index += 1


def read_mapping(data: bytes, ids: set[int]) -> dict[int, tuple[int, int]]:
    found = {}
    with gzip.GzipFile(fileobj=io.BytesIO(data)) as source:
        for raw_line in source:
            line = raw_line.decode("latin1")
            if not line.startswith("INSERT INTO `creature_template` VALUES "):
                continue
            for row in sql_tuples(line):
                if len(row) < 13:
                    raise SystemExit("Malformed CMaNGOS creature_template row")
                npc_id = int(row[0])
                if npc_id not in ids:
                    continue
                family_id = 0 if row[11] == "NULL" else int(row[11])
                type_id = 0 if row[12] == "NULL" else int(row[12])
                if type_id not in CREATURE_TYPES or (type_id == 0 and family_id == 0):
                    continue
                if npc_id in found:
                    raise SystemExit(f"Duplicate CMaNGOS creature_template ID {npc_id}")
                found[npc_id] = (type_id, family_id)
    return found


def generate(offline: bool = False, output: Path = OUT) -> None:
    ids = questie_ids(offline)
    source = source_bytes(offline)
    entries = read_mapping(source, ids)
    resolved, listed_icons = model_mapping(offline, ids)
    npc_icons = {npc_id: icon for npc_id, model in resolved.items() if (icon := stem_icon(model))}
    icon_paths = sorted({f"interface/icons/{icon}.blp" for icon in npc_icons.values()})
    missing = [path for path in icon_paths if path not in listed_icons]
    if missing:
        raise SystemExit(f"Generated icon paths missing from pinned listfile: {', '.join(missing)}")
    icon_index = {path: index for index, path in enumerate(icon_paths, 1)}
    questie_hash = hashlib.sha256(QUESTIE_TSV.read_bytes()).hexdigest()
    lines = [
        "---@type string, FGNamespace",
        "local _, ns = ...",
        "",
        f"-- Generated from CMaNGOS Classic-DB 1.12.1 z2815 at {CMANGOS_COMMIT}.",
        "-- CMaNGOS Classic-DB is GPL-3.0; this filtered table contains only NPC IDs and numeric metadata.",
        f"-- CMaNGOS source sha256 {CMANGOS_SHA256}.",
        f"-- CreatureModelData build 1.60.1.70450 sha256 {MODEL_SHA256}.",
        f"-- wow-listfile release {LISTFILE_TAG} sha256 {LISTFILE_SHA256}.",
        f"-- Pinned QuestieDB catalogue sha256 {questie_hash}.",
        f"-- {len(npc_icons)} of {len(ids)} catalogue NPCs have a model-derived icon; "
        f"{len(icon_paths)} distinct icons.",
        "ns.CreatureInfo = {",
        "\ticons = {",
    ]
    for index, path in enumerate(icon_paths, 1):
        lines.append(f'\t\t[{index}] = "{path}",')
    lines.extend(
        [
            "\t},",
            "\ttypes = {",
        ]
    )
    for type_id, name in CREATURE_TYPES.items():
        lines.append(f'\t\t[{type_id}] = "{name}",')
    lines.extend(["\t},", "\tentries = {"])
    for npc_id in sorted(set(entries) | set(npc_icons)):
        type_id, family_id = entries.get(npc_id, (0, 0))
        icon_id = icon_index.get(f"interface/icons/{npc_icons[npc_id]}.blp", 0) if npc_id in npc_icons else 0
        packed = icon_id * 1048576 + type_id * 65536 + family_id
        lines.append(f"\t\t[{npc_id}] = {packed},")
    lines.extend(
        [
            "\t},",
            "}",
            "",
            "function ns.CreatureInfo.Get(npcID)",
            "\tlocal packed = ns.CreatureInfo.entries[npcID]",
            "\tif not packed then",
            "\t\treturn nil",
            "\tend",
            "\tlocal iconIndex = math.floor(packed / 1048576)",
            "\tlocal metadata = packed % 1048576",
            "\treturn math.floor(metadata / 65536), metadata % 65536, ns.CreatureInfo.icons[iconIndex]",
            "end",
            "",
        ]
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")
    output_size = output.stat().st_size
    if len(entries) > MAX_RECORDS or output_size > MAX_PACKAGED_BYTES:
        output.unlink()
        raise SystemExit(f"Creature icon data exceeds package guard: {len(entries)} records, {output_size:,} bytes")
    print(f"Generated {output.name}: {len(entries)} / {len(ids)} NPCs, {output.stat().st_size:,} bytes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--output", type=Path, default=OUT)
    args = parser.parse_args()
    generate(args.offline, args.output)
