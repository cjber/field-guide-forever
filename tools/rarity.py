#!/usr/bin/env python3
"""Rarity recolour mockups: the target frame and the nameplate at every collection tier.

The tier mark is not an addon-drawn border. Each tier drops the chroma out of the client's own brass hardware and
multiplies the tier colour back in, which is exactly what UI/Rarity.lua does at runtime with `SetDesaturated(true)`
and `SetVertexColor`. So these sheets are the recolour itself: COMMON is the untouched client frame, and silver, gold
and shiny are the same textures with the brass removed and the tier colour laid into the shading.

Every pixel that is not the addon's own layout comes from the pinned WoW: Forever build (1.60.1.70124) through
wowmock, so what is approved here is what the addon paints.

    python3 tools/rarity.py
"""

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import wowmock.wowmock as wowmock  # noqa: E402
from wowmock.wowmock import FONTS, tint  # noqa: E402

OUT = ROOT / "docs" / "screenshots"

# UI/Rarity.lua's COLORS table, verbatim. Copper has no entry because copper is the client's own brass and needs no
# recolour at all; the whole promise of the feature is that a common creature looks exactly as it always did.
TIERS = (
    ("COMMON", "1 in 1", None, "the client's brass, untouched"),
    ("SILVER", "1 in 25", wowmock.rgb("c9d2dc"), "brass dropped out and silvered"),
    ("GOLD", "1 in 100", wowmock.rgb("e8bd63"), "brass dropped out and gilded"),
    ("SHINY", "1 in 1000", wowmock.rgb("b9e6ff"), "brass dropped out and shot through with cyan"),
)

TEXT = wowmock.rgb("e3d9c2")
MUTED = wowmock.rgb("9e998c")
DIM = wowmock.rgb("7c786f")
BRASS = wowmock.rgb("b8a16b")
BG = wowmock.rgb("0d0f12")

FRAME_W, FRAME_H = 256, 128


def text(canvas, x, y, value, font, colour=TEXT, **kwargs):
    canvas.text(x, y, value, FONTS[font], colour, **kwargs)


def recolour(piece, colour):
    """SetDesaturated then SetVertexColor: luminance only, multiplied by the tier colour."""
    if colour is None:
        return piece
    grey = piece.convert("L").convert("RGBA")
    grey.putalpha(piece.getchannel("A"))
    return tint(grey, colour)


def art(canvas, atlas, x, y, w, h, colour=None):
    """Draw an atlas the way the client would and recolour it before it lands on the canvas."""
    wpx, hpx = canvas.px(x + w) - canvas.px(x), canvas.px(y + h) - canvas.px(y)
    piece = canvas.sliced(atlas, wpx, hpx) if atlas.slice else atlas.image.resize((wpx, hpx), Image.LANCZOS)
    canvas.composite(recolour(piece, colour), canvas.px(x), canvas.px(y))


def health(canvas, x, y, w, h, fraction, fill):
    """The bar the client fills: a dark trough with the reaction colour in it."""
    canvas.fill(x, y, w, h, wowmock.rgb("1a1c20"))
    canvas.fill(x, y, round(w * fraction), h, fill)
    canvas.fill(x, y, round(w * fraction), max(2, h // 4), tuple(min(1, c * 1.35) for c in fill))


def target_frame(ui, canvas, x, y, tier, icon, name, level, elite=False):
    """One target frame: the client's brass chrome, recoloured to the tier, with its bars over the art's own trough."""
    _, _, colour, _ = tier
    atlas = ui.atlas("hud-TargetingFrame-elite" if elite else "hud-TargetingFrame")
    art(canvas, atlas, x, y, FRAME_W, FRAME_H, colour)
    health(canvas, x + 40, y + 34, 120, 22, 0.86, wowmock.rgb("3f7a34"))
    health(canvas, x + 40, y + 58, 120, 8, 0.62, wowmock.rgb("2f5a9e"))
    canvas.draw(icon, x + 168, y + 20, 56, 56)
    text(canvas, x + 42, y + 8, name, "GameFontNormalSmall", TEXT, width=116)
    text(canvas, x + 168, y + 78, str(level), "GameFontNormalSmall", wowmock.rgb("d8c58a"), width=56)


def nameplate(ui, canvas, x, y, tier, name, elite=False):
    """One nameplate: the plate's own trough recoloured to the tier, the reaction fill inside it, the elite dragon as
    the client draws it. Copper leaves the trough at the bronze the client ships."""
    _, _, colour, _ = tier
    w, h = 116, 12
    art(canvas, ui.atlas("UI-HUD-CoolDownManager-Bar-BG"), x - 4, y - 4, w + 8, h + 8, colour)
    health(canvas, x, y, w, h, 0.9, wowmock.rgb("a3342c"))
    text(canvas, x, y - 15, name, "GameFontNormalSmall", TEXT, width=w)
    if elite:
        canvas.draw(ui.atlas("nameplates-icon-elite-gold"), x + w - 15, y - 23, 14, 14)


def sheet(ui, icons, name, elite=False, plates=False):
    cols, rows = 2, 2
    cell_w, cell_h = 330, 210
    m = 34
    canvas = ui.canvas(cell_w * cols + m * 2, cell_h * rows + m * 2 + 64)
    canvas.fill(0, 0, canvas.width, canvas.height, BG)
    text(canvas, m, 18, "FIELD GUIDE  \u00b7  RARITY RECOLOUR", "GameFontNormal", BRASS)
    text(
        canvas,
        m,
        36,
        "The client's own brass, desaturated and vertex-coloured - one tier per cell",
        "GameFontDisableSmall",
        MUTED,
    )
    folk = ["Savannah Prowler", "Bristleback Boar", "Prairie Wolf", "Plainstrider"]
    glyph = ["prowler", "boar", "wolf", "strider"]
    for index, tier in enumerate(TIERS):
        col, row = index % cols, index // cols
        cx = m + col * cell_w
        cy = m + 64 + row * cell_h
        label, odds, colour, note = tier
        text(canvas, cx, cy, label, "GameFontNormal", colour or BRASS)
        odds_x = cx + canvas.text_width(label, FONTS["GameFontNormal"]) + 8
        text(canvas, odds_x, cy + 1, odds, "GameFontDisableSmall", DIM)
        text(canvas, cx, cy + 16, note, "GameFontDisableSmall", MUTED)
        target_frame(ui, canvas, cx + 14, cy + 46, tier, icons[glyph[index]], folk[index], 12 + index, elite=elite)
        if plates:
            nameplate(ui, canvas, cx + 74, cy + 186, tier, folk[index], elite=elite)
    return canvas


def main():
    ui = wowmock.Ui(scale=2)
    OUT.mkdir(parents=True, exist_ok=True)
    icons = {
        key: ui.texture(f"interface/icons/{value}.blp")
        for key, value in (
            ("prowler", "ability_hunter_pet_cat"),
            ("boar", "ability_hunter_pet_boar"),
            ("wolf", "ability_hunter_pet_wolf"),
            ("strider", "ability_hunter_pet_tallstrider"),
        )
    }
    sheet(ui, icons, "target frames").save(OUT / "rarity-target.png")
    sheet(ui, icons, "nameplates", plates=True).save(OUT / "rarity-nameplates.png")
    sheet(ui, icons, "elite frames", elite=True, plates=True).save(OUT / "rarity-elite.png")
    print("wrote 3 rarity sheets")


if __name__ == "__main__":
    sys.exit(main())
