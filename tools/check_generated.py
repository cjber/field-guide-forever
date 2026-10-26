#!/usr/bin/env python3
"""Fail when the committed client constants differ from a fresh pinned regeneration."""

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Data" / "Client.lua"
CREATURE_OUT = ROOT / "Data" / "CreatureIcons.lua"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true", help="require existing tools/.cache inputs")
    # Missing pinned sources are downloaded and sha256-checked by default, so a cold CI runner works;
    # --offline keeps a local run off the network.
    mode = ["--offline"] if parser.parse_args().offline else []
    with tempfile.TemporaryDirectory(prefix="field-guide-data-") as temp:
        generated = Path(temp) / "Client.lua"
        command = [
            sys.executable,
            "tools/gen_zones.py",
            "--build",
            "1.60.1.70532",
            *mode,
            "--output",
            str(generated),
        ]
        subprocess.run(command, cwd=ROOT, check=True)
        expected = generated.read_bytes()
        subprocess.run(command, cwd=ROOT, check=True)
        if generated.read_bytes() != expected:
            raise SystemExit("Client constants are not byte-stable")
        if OUT.read_bytes() != expected:
            raise SystemExit("Data/Client.lua is stale; regenerate it with tools/gen_zones.py")
    print("Generated client data is fresh and byte-stable.")
    with tempfile.TemporaryDirectory(prefix="field-guide-creatures-") as temp:
        generated = Path(temp) / "CreatureIcons.lua"
        command = [sys.executable, "tools/gen_creature_icons.py", *mode, "--output", str(generated)]
        subprocess.run(command, cwd=ROOT, check=True)
        expected = generated.read_bytes()
        subprocess.run(command, cwd=ROOT, check=True)
        if generated.read_bytes() != expected:
            raise SystemExit("Generated creature icon data is not byte-stable")
        if CREATURE_OUT.read_bytes() != expected:
            raise SystemExit("Data/CreatureIcons.lua is stale; regenerate it with tools/gen_creature_icons.py")
    print("Generated creature icon data is fresh and byte-stable.")
    icon_source = CREATURE_OUT.read_text(encoding="utf-8")
    generated_icons = set(re.findall(r'^\s*\[\d+\] = "(interface/icons/[^"]+)"', icon_source, re.MULTILINE))
    listfile_subset = ROOT / "tools" / ".cache" / "creature-model-paths-202610202236.json"
    listed_icons = json.loads(listfile_subset.read_text(encoding="utf-8"))["icons"]
    missing_icons = sorted(generated_icons - set(listed_icons))
    if missing_icons:
        raise SystemExit(f"Creature icon paths missing from pinned listfile: {', '.join(missing_icons)}")
    print(f"All {len(generated_icons)} generated creature icons exist in the pinned listfile.")


if __name__ == "__main__":
    main()
