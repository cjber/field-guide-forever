#!/usr/bin/env python3
"""Paint the Field Guide micro-menu glyph from client art and write the two shipped TGA files.

The preview's `painted()` treatment is kept here: crop the baked icon bevel, keep the bright shape, tint it warm
gold, feather the edge round and leave the corners transparent so the native ButtonBG plate shows through. The
hover variant is the same shape a little brighter.

    FOREVER_CORE=/path/to/forever-core python3 tools/gen_micro_glyph.py

Writes `media/MicroGlyph.tga` and `media/MicroGlyphHover.tga` at a power-of-two 64 x 64. Deterministic: a second run
is byte-identical.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

from PIL import Image  # ty: ignore[unresolved-import]
from ui_art import BUILD as ART_BUILD

ROOT = Path(__file__).resolve().parent.parent
FOREVER_CORE = Path(os.environ.get("FOREVER_CORE", ROOT.parent / "forever-core")).expanduser()
WOWMOCK = FOREVER_CORE / "tools" / "wowmock"
if not (WOWMOCK / "wowmock.py").is_file():
    raise SystemExit(f"wowmock.py not found in {WOWMOCK}; set FOREVER_CORE to the forever-core checkout")
sys.path.insert(0, str(WOWMOCK))
import wowmock  # noqa: E402  # ty: ignore[unresolved-import]

OUT = ROOT / "media"
ICON = "interface/icons/ability_hunter_pet_wolf.blp"
SIZE = 64
COLOUR = (1.0, 0.82, 0.45)
HOVER_COLOUR = (1.0, 0.92, 0.62)


def painted(icon: Image.Image, size: int, colour: tuple[float, float, float], lift: float) -> Image.Image:
    """The approved frameless glyph treatment, at native pixel size."""
    cropped = icon.convert("RGBA").resize((round(size * 1.24), round(size * 1.24)), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(cropped, (round(-size * 0.12), round(-size * 0.12)))
    img = canvas.convert("RGB")
    lum = img.convert("L")
    alpha = Image.new("L", img.size)
    rgb = Image.new("RGB", img.size)
    lp, ap, rp = lum.load(), alpha.load(), rgb.load()
    for y in range(size):
        yy = (y - size / 2) / (size / 2)
        for x in range(size):
            xx = (x - size / 2) / (size / 2)
            radius = (xx * xx + yy * yy) ** 0.5
            edge = max(0.0, min(1.0, (1.0 - radius) / 0.18))
            value = lp[x, y] / 255
            shape = max(0.0, min(1.0, (value - 0.18) / 0.35))
            ap[x, y] = int(255 * edge * shape)
            brightness = lift + 0.75 * value
            rp[x, y] = tuple(int(min(255, 255 * channel * brightness)) for channel in colour)
    rgb.putalpha(alpha)
    return rgb


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ui = wowmock.Ui(build=ART_BUILD, scale=1)
    icon = ui.texture(ICON)
    painted(icon, SIZE, COLOUR, 0.55).save(OUT / "MicroGlyph.tga", format="TGA")
    painted(icon, SIZE, HOVER_COLOUR, 0.70).save(OUT / "MicroGlyphHover.tga", format="TGA")
    for name in ("MicroGlyph.tga", "MicroGlyphHover.tga"):
        path = OUT / name
        image = Image.open(path)
        if image.size != (SIZE, SIZE):
            raise SystemExit(f"{path.name}: expected {SIZE}x{SIZE}, got {image.size}")
        print(f"wrote {path.relative_to(ROOT)} {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
