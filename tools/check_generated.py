#!/usr/bin/env python3
"""Fail when the committed client constants differ from a fresh pinned regeneration."""

import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Data" / "Client.lua"
CREATURE_OUT = ROOT / "Data" / "CreatureIcons.lua"
with tempfile.TemporaryDirectory(prefix="field-guide-data-") as temp:
    generated = Path(temp) / "Client.lua"
    command = [sys.executable, "tools/gen_zones.py", "--build", "1.60.1.70450", "--offline", "--output", str(generated)]
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
    command = [sys.executable, "tools/gen_creature_icons.py", "--offline", "--output", str(generated)]
    subprocess.run(command, cwd=ROOT, check=True)
    expected = generated.read_bytes()
    subprocess.run(command, cwd=ROOT, check=True)
    if generated.read_bytes() != expected:
        raise SystemExit("Generated creature icon data is not byte-stable")
    if CREATURE_OUT.read_bytes() != expected:
        raise SystemExit("Data/CreatureIcons.lua is stale; regenerate it with tools/gen_creature_icons.py")
print("Generated creature icon data is fresh and byte-stable.")
