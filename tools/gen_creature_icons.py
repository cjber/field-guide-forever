#!/usr/bin/env python3
"""Generate compact NPC type/family metadata from the pinned Classic-DB fallback."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
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
AGENT = "FieldGuideForever species icon generator (+https://github.com/cjber/bestiary-forever)"
MAX_RECORDS = 20_000
MAX_PACKAGED_BYTES = 200 * 1024

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
    questie_hash = hashlib.sha256(QUESTIE_TSV.read_bytes()).hexdigest()
    lines = [
        "---@type string, FGNamespace",
        "local _, ns = ...",
        "",
        f"-- Generated from CMaNGOS Classic-DB 1.12.1 z2815 at {CMANGOS_COMMIT}.",
        "-- CMaNGOS Classic-DB is GPL-3.0; this filtered table contains only NPC IDs and numeric metadata.",
        f"-- CMaNGOS source sha256 {CMANGOS_SHA256}.",
        f"-- Pinned QuestieDB catalogue sha256 {questie_hash}.",
        f"-- {len(entries)} of {len(ids)} catalogue NPCs have non-zero type or family data.",
        "ns.CreatureInfo = {",
        "\ttypes = {",
    ]
    for type_id, name in CREATURE_TYPES.items():
        lines.append(f'\t\t[{type_id}] = "{name}",')
    lines.extend(["\t},", "\tentries = {"])
    for npc_id, (type_id, family_id) in sorted(entries.items()):
        packed = type_id * 65536 + family_id
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
            "\treturn math.floor(packed / 65536), packed % 65536",
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
