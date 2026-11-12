#!/usr/bin/env python3
"""Fail when a screenshot is older than the code it is drawn from (stdlib only).

`tools/mockups.py` draws every image from this addon's catalogue, palette and window layout with the shared renderer
in forever-core. `scenes.sha256` records
one digest over those sources beside each image's name, so any change to a source needs a fresh render. CI runs the
plain check; after `python3 tools/mockups.py` run `--record` to rewrite the digests.

`tools/visual_audit.py` then checks the render itself: the `layout.json` manifest against the frame, and the pixels
against the manifest.

    python3 tools/check_screenshots.py           # CI: fail on a stale image
    python3 tools/check_screenshots.py --record  # after a render
"""

import ast
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "screenshots"
STAMP = OUT / "scenes.sha256"
SOURCES = (
    "Data/Client.lua",
    "Data/CreatureIcons.lua",
    "tools/gen_mock_catalogue.py",
    "tools/extract_mock_catalogue.lua",
    "tools/questiedb_load.lua",
    "Integrations/QuestieDB.lua",
    "Core/Model.lua",
    "Core/Core.lua",
    "Core/Stats.lua",
    "Core/API.lua",
    "Core/Settings.lua",
    "UI/Rarity.lua",
    "UI/Discovery.lua",
    "Locales/enUS.lua",
    "UI/Art.lua",
    "UI/Detail.lua",
    "UI/Instances.lua",
    "UI/List.lua",
    "UI/Window.lua",
    "tools/ui_art.py",
    "tools/mockups.py",
    "tools/rarity.py",
    "media/Icon.tga",
    "media/Rarity/Laurel-Silver.tga",
    "media/Rarity/Laurel-Gold.tga",
    "media/Rarity/Laurel-Shiny.tga",
    "tools/discovery.py",
    "tools/minimap_mockups.py",
)
RARITY_GEOMETRY = {
    "HEALTH_WINDOW": (3, 23.5, 129, 43.5),
    "POWER_WINDOW": (3, 44.5, 137, 54.5),
    "PORTRAIT_CENTER": (157, 31.5),
    "PORTRAIT_RADIUS": 29,
    "LEVEL_CENTER": (188, 54),
    "PLATE_RAID_TARGET_SIZE": 22,
    "PLATE_CLASSIFICATION_SIZE": 20,
    "PLATE_BUFF_ICON_SIZE": 25,
    "PLATE_BUFF_GAP": 5,
    "PLATE_MARK_SIZE": 17,
    "PLATE_MARK_GAP": 2,
    "PLATE_HEALTH_WIDTH": 116,
    "PLATE_HEALTH_HEIGHT": 12,
}


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


def check_rarity_geometry() -> None:
    """Keep the rarity renderer anchored to the measured client frame and badge geometry."""
    source = ast.parse((ROOT / "tools/rarity.py").read_text(encoding="utf-8"))
    values = {}
    for node in ast.walk(source):
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id in RARITY_GEOMETRY:
                    values[target.id] = ast.literal_eval(node.value)
    if values != RARITY_GEOMETRY:
        raise ValueError(f"rarity target-frame geometry drifted: {values!r}")


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
    check_rarity_geometry()
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
