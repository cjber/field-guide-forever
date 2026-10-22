#!/usr/bin/env python3
# sift-scope: all
# sift-fix: Keep creature names and placement in QuestieDB; do not commit a replacement hand-written catalogue.
"""Reject the deleted hand-maintained creature catalogue if it returns."""

import os
from pathlib import Path

root = Path(os.environ["SIFT_ROOT"])
paths = Path(os.environ["SIFT_FILES"]).read_text(encoding="utf-8").splitlines()
hits = []
for name in paths:
    if name == "Data/Creatures.lua":
        hits.append(f"{name}:1: no-handwritten-creatures Creature rows must come from QuestieDB.")
for hit in hits:
    print(hit)
raise SystemExit(bool(hits))
