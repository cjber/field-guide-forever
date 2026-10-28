#!/usr/bin/env python3
"""Generate client geography, instance types, families and portrait IDs from pinned Forever DB2 exports."""

import argparse
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from forever_tools.wago import db2_rows

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUT = ROOT / "Data" / "Client.lua"
AGENT = "FieldGuideForever data generator (+https://github.com/cjber/bestiary-forever)"
TABLES = {
    "AreaTable": ("ID", "AreaName_lang", "ContinentID"),
    "Map": ("ID", "MapName_lang", "InstanceType"),
    "CreatureFamily": ("ID", "Name_lang"),
    "CreatureDisplayInfo": ("ID", "PortraitTextureFileDataID"),
}


def q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def generate(build, offline=False, output=OUT):
    data = {}
    meta = {}
    for table, columns in TABLES.items():
        rows = db2_rows(
            table, build, CACHE, user_agent=AGENT, offline=offline, required=columns, ints=("ID",), unique="ID"
        )
        path = CACHE / f"{table}-{build}.csv"
        meta[table] = (len(rows), hashlib.sha256(path.read_bytes()).hexdigest())
        data[table] = rows
    lines = [
        "---@type string, FGNamespace",
        "local _, ns = ...",
        "",
        f"-- Generated from wago.tools Forever build {build}; do not edit.",
    ]
    for t, (count, digest) in meta.items():
        lines.append(f"-- {t}: {count} rows; sha256 {digest}")
    lines += [
        "ns.ClientData = { "
        f"build = {q(build)}, continents = {{}}, zones = {{}}, maps = {{}}, "
        "families = {}, portraits = {} }"
    ]
    for r in sorted(data["Map"], key=lambda x: x["ID"]):
        if r["ID"] in (0, 1) and str(r["MapName_lang"]).strip():
            lines.append(f"ns.ClientData.continents[{r['ID']}] = {q(str(r['MapName_lang']).strip())}")
    zone = []
    for r in data["AreaTable"]:
        name = str(r["AreaName_lang"]).strip()
        if name:
            zone.append((r["ID"], name, r["ContinentID"]))
    for id, name, continent in sorted(zone):
        lines.append(f"ns.ClientData.zones[{id}] = {{ name = {q(name)}, continent = {continent} }}")
    for r in sorted(data["Map"], key=lambda x: x["ID"]):
        name = str(r["MapName_lang"]).strip()
        typ = r["InstanceType"]
        if name and typ != 0:
            lines.append(f"ns.ClientData.maps[{r['ID']}] = {{ name = {q(name)}, instanceType = {typ} }}")
    for r in sorted(data["CreatureFamily"], key=lambda x: x["ID"]):
        lines.append(f"ns.ClientData.families[{r['ID']}] = {q(r['Name_lang'])}")
    for r in sorted(data["CreatureDisplayInfo"], key=lambda x: x["ID"]):
        fid = r["PortraitTextureFileDataID"]
        if fid:
            lines.append(f"ns.ClientData.portraits[{r['ID']}] = {fid}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n")
    print(
        f"Generated {output.name} for {build}: {len(zone)} zones, "
        f"{len(data['Map'])} maps, {len(data['CreatureFamily'])} families"
    )


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--build", default="1.60.1.70658")
    p.add_argument("--offline", action="store_true")
    p.add_argument("--output", type=Path, default=OUT)
    a = p.parse_args()
    generate(a.build, a.offline, a.output)
