"""Fail when the committed client constants differ from a fresh pinned regeneration."""

import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Data" / "Client.lua"
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
