#!/usr/bin/env python3
"""Check the packager's output before an upload (stdlib only).

Runs after the BigWigs packager in the CI package job and before a tag in the release workflow, so what ships is
checked rather than assumed: every file the TOC loads is present, nothing from development is, the licence and README
are there, and the TOC's version and interface were actually substituted by the packager.

    printf 'Package check\\n' > .release-notes.md
    <BigWigs packager> -d -z
    python3 tools/check_package.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELEASE = ROOT / ".release"
ADDON = "FieldGuideForever"
DEVELOPMENT = ("tests", "tools", "docs", "reference", "scratch", ".github")
REQUIRED = ("LICENSE", "README.md")


def toc_files(toc: Path) -> list[str]:
    """The files the client loads: every non-comment TOC line, in order."""
    loaded = []
    for line in toc.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("##"):
            continue
        loaded.append(line.replace("\\", "/"))
    return loaded


def check(root: Path) -> list[str]:
    problems = []
    addon = root / ADDON
    toc = addon / f"{ADDON}.toc"
    if not toc.is_file():
        return [f"{ADDON}/{ADDON}.toc is missing from the package"]
    text = toc.read_text(encoding="utf-8")
    if "@project-version@" in text:
        problems.append("the TOC still holds @project-version@: the packager did not substitute a version")
    if not re.search(r"^## Interface: \d+", text, re.MULTILINE):
        problems.append("the TOC has no ## Interface line")
    for name in toc_files(toc):
        if not (addon / name).is_file():
            problems.append(f"the TOC loads {name}, which the package does not ship")
    for name in REQUIRED:
        if not (addon / name).is_file():
            problems.append(f"{ADDON}/{name} is missing from the package")
    for entry in DEVELOPMENT:
        if (addon / entry).exists():
            problems.append(f"{ADDON}/{entry} is development-only and must not ship")
    return problems


def main() -> int:
    if not RELEASE.is_dir():
        print(f"{RELEASE.name}/ not found: run the packager first", file=sys.stderr)
        return 1
    problems = check(RELEASE)
    if problems:
        print("The package is not shippable:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1
    print(f"{ADDON} ships every file its TOC loads, with no development folders")
    return 0


if __name__ == "__main__":
    sys.exit(main())
