#!/usr/bin/env python3
"""Fail when a screenshot is older than the code it is drawn from (stdlib only).

`tools/mockups.py` draws every image from this addon's catalogue, palette and window layout. `scenes.sha256` records
one digest over those sources beside each image's name, so any change to a source needs a fresh render. CI runs the
plain check; after `python3 tools/mockups.py` run `--record` to rewrite the digests.

    python3 tools/check_screenshots.py           # CI: fail on a stale image
    python3 tools/check_screenshots.py --record  # after a render
"""

import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "screenshots"
STAMP = OUT / "scenes.sha256"
SOURCES = (
    "Data/Creatures.lua",
    "Locales/enUS.lua",
    "UI/Art.lua",
    "UI/Detail.lua",
    "UI/List.lua",
    "UI/Window.lua",
    "tools/mockups.py",
    "tools/rarity.py",
    "tools/wowmock/wowmock.py",
)


def digest() -> str:
    """One digest over every source, path-labelled so a rename changes it too."""
    sha = hashlib.sha256()
    for name in SOURCES:
        path = ROOT / name
        sha.update(name.encode("utf-8"))
        sha.update(b"\0")
        sha.update(path.read_bytes() if path.is_file() else b"<missing>")
        sha.update(b"\0")
    return sha.hexdigest()


def recorded(path: Path) -> dict[str, str]:
    """Each image's recorded digest, keyed by image name."""
    digests: dict[str, str] = {}
    if not path.is_file():
        return digests
    for line in path.read_text(encoding="utf-8").splitlines():
        digest, _, name = line.partition("  ")
        if name:
            digests[name] = digest
    return digests


def main(argv: list[str]) -> int:
    images = sorted(OUT.glob("*.png")) + sorted(OUT.glob("*.gif"))
    if not images:
        print(f"no screenshots in {OUT.relative_to(ROOT)}", file=sys.stderr)
        return 1
    current = digest()
    if "--record" in argv:
        STAMP.write_text("".join(f"{current}  {image.name}\n" for image in images), encoding="utf-8")
        print(f"recorded {len(images)} images against {current[:12]}")
        return 0
    stale = [image.name for image in images if recorded(STAMP).get(image.name) != current]
    if stale:
        print(
            "Screenshots are older than the code that draws them; run `python3 tools/mockups.py` and commit the "
            "images with `python3 tools/check_screenshots.py --record`:",
            file=sys.stderr,
        )
        for name in stale:
            print(f"  - {name}", file=sys.stderr)
        return 1
    print(f"{len(images)} screenshots match their sources")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
