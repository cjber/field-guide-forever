"""Preview native location/content art candidates, without changing the addon."""

import concurrent.futures
import json
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw
from ui_art import BUILD as ART_BUILD

FOREVER_CORE = Path(os.environ.get("FOREVER_CORE", Path(__file__).resolve().parents[2] / "forever-core"))
sys.path.insert(0, str(FOREVER_CORE / "tools/wowmock"))
import wowmock  # noqa: E402  # ty: ignore[unresolved-import]

ROOT = Path(__file__).resolve().parents[1]
ui = wowmock.Ui(build=ART_BUILD, scale=1)
candidates = [
    ("Badlands - Classic warboard", 1851093, "Location illustration candidate"),
    ("Northern Barrens - Classic warboard", 1851084, "Location illustration candidate"),
    ("Southern Barrens - Classic warboard", 1851087, "Location illustration candidate"),
    ("Elwynn Forest - Classic warboard", 1851068, "Location illustration candidate"),
    ("Badlands credits 1", 131255, "Check image subject and tile layout"),
    ("Badlands credits 2", 131256, "Check image subject and tile layout"),
    ("Uldaman loading screen", 131876, "Native dungeon illustration"),
    ("Uldaman LFG image", 136363, "Native dungeon illustration"),
    ("PetJournal-PetCard-BG", "PetJournal-PetCard-BG", "Creature-card surface candidate"),
    ("collections-background-tile", "collections-background-tile", "Collection surface candidate"),
    (
        "_GarrMissionLocation-NorthernBarrens-Mid",
        "_GarrMissionLocation-NorthernBarrens-Mid",
        "BLACKLISTED - comparison only",
    ),
]


def fetch(item):
    title, ref, status = item
    try:
        image = ui.texture(ref) if isinstance(ref, int) else ui.atlas(ref).image
        return title, image, status, str(ref)
    except Exception as error:
        return title, None, "Unavailable in pinned build: " + str(error)[:95], str(ref)


def main():
    items = candidates
    if "--zones" in sys.argv:
        cache = ROOT / "tools/.cache/zone-art-audit/warboard-classic.json"
        cache.parent.mkdir(parents=True, exist_ok=True)
        items = [
            (name.rsplit("-", 1)[-1].removesuffix(".blp"), int(file), "Zone artwork, check depicted era")
            for file, name in json.loads(
                ui.wago.cached(
                    cache,
                    "https://wago.tools/api/files?search=answer-warboard-classic",
                )
            ).items()
        ]

    with concurrent.futures.ThreadPoolExecutor(6) as pool:
        results = list(pool.map(fetch, items))
    font = ui.font(wowmock.FONTS["GameFontHighlight"])
    small = ui.font(wowmock.FONTS["GameFontHighlightSmall"])
    sheet = Image.new("RGB", (1260, 48 + ((len(items) + 2) // 3) * 260), (24, 25, 28))
    draw = ImageDraw.Draw(sheet)
    draw.text(
        (18, 12), f"Native asset audit - build {ui.wago.build} - candidates, not a final UI", font=font, fill="white"
    )
    for index, (title, image, status, ref) in enumerate(results):
        x, y = 18 + index % 3 * 414, 48 + index // 3 * 260
        if image is not None:
            image = image.copy().convert("RGBA")
            image.thumbnail((390, 192), Image.Resampling.LANCZOS)
            sheet.paste(image, (x + (390 - image.width) // 2, y), image)
            status += " | " + str(results[index][1].size)
        draw.text((x, y + 198), title, font=small, fill="white")
        draw.text(
            (x, y + 216), status[:66], font=small, fill=(255, 100, 100) if "BLACKLISTED" in status else (200, 200, 200)
        )
        draw.text((x, y + 232), ref[:64], font=small, fill=(180, 180, 180))
    out = ROOT / (
        "docs/previews/native-classic-zone-art.png"
        if "--zones" in sys.argv
        else "docs/previews/native-zone-art-candidates.png"
    )
    out.parent.mkdir(exist_ok=True, parents=True)
    sheet.save(out)
    print(out)
    for title, image, status, ref in results:
        print(title, ref, image.size if image else "-", status, flush=True)


if __name__ == "__main__":
    main()
