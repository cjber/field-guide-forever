#!/usr/bin/env python3
"""Check the rules this repository holds that no linter covers. CI runs it in the `project-rules` job.

- `no-handwritten-creatures`: creature names, levels and placement come from the player's QuestieDB at runtime
  (WFA-28), so the deleted hand-maintained catalogue `Data/Creatures.lua` must not come back.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def findings(root: Path) -> list[str]:
    if (root / "Data/Creatures.lua").is_file():
        return ["Data/Creatures.lua:1: no-handwritten-creatures: creature rows must come from QuestieDB."]
    return []


def main() -> int:
    hits = findings(ROOT)
    for hit in hits:
        print(hit)
    return int(bool(hits))


if __name__ == "__main__":
    sys.exit(main())
