#!/usr/bin/env python3
"""Rarity trim mockups: the target frame, the nameplate and an elite frame at each collection tier.

Drawn with the pinned WoW: Forever build's own art (targeting frame nine-slice, status bar border and fill,
nameplate health bar, atlas gems, FRIZQT), so what is approved here is what UI/Rarity.lua paints.

    python3 tools/rarity.py
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import wowmock.wowmock as wowmock  # noqa: E402
from wowmock.wowmock import FONTS  # noqa: E402

OUT = ROOT / "docs" / "screenshots"

# The tier palette. Copper is the client's own frame colour, so it adds nothing: the whole point is that a
# common creature looks exactly like it always did.
TIERS = (
    ("COPPER", "common", wowmock.rgb("8a6a44"), "1 in 1", "no trim, the frame the client already draws"),
    ("SILVER", "1 in 25", wowmock.rgb("c9d2dc"), "1 in 25", "silver rim and inner hairline"),
    ("GOLD", "1 in 100", wowmock.rgb("e8bd63"), "1 in 100", "gold rim, dragon crest warmed to match"),
    ("SHINY", "1 in 1000", wowmock.rgb("b9e6ff"), "1 in 1000", "iridescent rim, sparkles, slow shimmer"),
)

TEXT = wowmock.rgb("e3d9c2")
MUTED = wowmock.rgb("9e998c")
DIM = wowmock.rgb("7c786f")
BRASS = wowmock.rgb("b8a16b")
TROUGH = wowmock.rgb("22252a")
BG = wowmock.rgb("0d0f12")

FRAME_W, FRAME_H = 256, 128


def text(canvas, x, y, value, font, colour=TEXT, **kwargs):
    canvas.text(x, y, value, FONTS[font], colour, **kwargs)


def stroke(canvas, x, y, w, h, colour, thickness=2):
    canvas.fill(x, y, w, thickness, colour)
    canvas.fill(x, y + h - thickness, w, thickness, colour)
    canvas.fill(x, y, thickness, h, colour)
    canvas.fill(x + w - thickness, y, thickness, h, colour)


def corner_gems(canvas, x, y, w, h, colour, size=5):
    """The client marks frames with small atlas diamonds, so the trim's corners get the same treatment."""
    for cx, cy in ((x, y), (x + w, y), (x, y + h), (x + w, y + h)):
        for row in range(size):
            inset = abs(row - size / 2 + 0.5)
            canvas.fill(cx - (size / 2 - inset), cy - size / 2 + row, max(1, (size / 2 - inset) * 2), 1, colour)


def sparkle(canvas, cx, cy, size, colour):
    """A four point star from fills: FRIZQT has no star glyph and the client draws these with art."""
    canvas.fill(cx - size, cy, size * 2 + 1, 1, colour)
    canvas.fill(cx, cy - size, 1, size * 2 + 1, colour)
    canvas.fill(cx - 1, cy - 1, 3, 3, colour)


def iridescent(x, y, w, h):
    """SHINY's rim: a cyan to violet sweep, because one flat colour would read as 'another gold'."""
    top = wowmock.rgb("8fe3ff")
    bottom = wowmock.rgb("c8a8ff")
    for row in range(h):
        blend = row / max(1, h - 1)
        colour = tuple(round(top[i] + (bottom[i] - top[i]) * blend) for i in range(3))
        canvas_row = colour
        yield (x, y + row, w, canvas_row)


def target_frame(ui, canvas, x, y, tier, icon, name, level, elite=False, nameplate=False):
    """One target frame: the client's targeting frame art, a health fill, the creature icon in the portrait, and
    the tier's trim. Copper draws no trim at all, which is the design's whole claim."""
    label, odds, colour, _, _ = tier

    art = "hud-TargetingFrame-elite" if elite else "hud-TargetingFrame"
    atlas = ui.atlas(art)
    canvas.draw(atlas, x, y, FRAME_W, FRAME_H)
    # The atlas carries transparent margins, so the trim follows the art's own bounds rather than the draw box.
    left, top, right, bottom = atlas.image.convert("RGBA").getbbox()

    # Health: the trough the client carves at the left of the frame, filled the way a live target reads.
    hx, hy, hw, hh = x + 40, y + 34, 120, 22
    canvas.fill(hx, hy, hw, hh, TROUGH)
    canvas.fill(hx, hy, round(hw * 0.86), hh, wowmock.rgb("3f7a34"))
    canvas.fill(hx, hy, round(hw * 0.86), max(2, hh // 4), wowmock.rgb("59a049"))
    # Mana under it, thinner, so the frame reads as the real thing rather than a bare bar.
    canvas.fill(hx, hy + hh + 2, hw, 8, TROUGH)
    canvas.fill(hx, hy + hh + 2, round(hw * 0.62), 8, wowmock.rgb("2f5a9e"))

    # Portrait: the circle the template leaves at the right of the frame.
    canvas.draw(icon, x + 168, y + 20, 56, 56)
    text(canvas, x + 42, y + 8, name, "GameFontNormalSmall", TEXT, width=116)
    text(canvas, x + 168, y + 78, str(level), "GameFontNormalSmall", wowmock.rgb("d8c58a"), width=56)

    if label == "COPPER":
        return

    # Trim sits outside the art, never on top of it: an elite keeps its dragon and only gains an outer edge, so
    # the two decorations never fight for the same pixels.
    pad = 3
    tx, ty = x + left - pad, y + top - pad
    tw, th = (right - left) + pad * 2, (bottom - top) + pad * 2
    if label == "SHINY":
        for row, (rx, ry, rw, rc) in enumerate(iridescent(tx, ty, tw, th)):
            pass
        # A soft two-tone edge: cyan along the top, violet along the bottom, plus a faint halo.
        canvas.fill(tx, ty, tw, 2, wowmock.rgb("8fe3ff"))
        canvas.fill(tx, ty + th - 2, tw, 2, wowmock.rgb("c8a8ff"))
        canvas.fill(tx, ty, 2, th, wowmock.rgb("a6d4ff"))
        canvas.fill(tx + tw - 2, ty, 2, th, wowmock.rgb("c8a8ff"))
        canvas.fill(tx - 1, ty - 1, tw + 2, 1, wowmock.rgb("5f88a8"))
        canvas.fill(tx - 1, ty + th, tw + 2, 1, wowmock.rgb("7f6aa0"))
        for sx, sy, size in ((tx + 18, ty + 10, 4), (tx + tw - 26, ty + 34, 3), (tx + 40, ty + th - 14, 3)):
            sparkle(canvas, sx, sy, size, wowmock.rgb("d8f2ff"))
    else:
        stroke(canvas, tx, ty, tw, th, colour, 2)
        canvas.fill(tx + 2, ty + 2, tw - 4, 1, wowmock.rgb("2a2118") if label == "GOLD" else wowmock.rgb("232830"))

    if label == "GOLD":
        # The dragon crest is part of the elite art, so a gold tier warms the frame's own brass rather than
        # layering a second metal on top of it.
        canvas.fill(tx, ty, tw, 1, wowmock.rgb("f6d79a"))


def nameplate(ui, canvas, x, y, tier, name, elite=False):
    """The nameplate trim: the client's own plate bar, edged in the tier colour so it is legible at a glance in
    a pull of eight mobs. Copper keeps the plate exactly as the client draws it."""
    label, _, colour, _, _ = tier
    w, h = 116, 10
    canvas.fill(x, y, w, h, TROUGH)
    canvas.fill(x, y, round(w * 0.9), h, wowmock.rgb("a3342c"))
    canvas.fill(x, y, round(w * 0.9), 2, wowmock.rgb("c04a3f"))

    if label == "COPPER":
        stroke(canvas, x - 1, y - 1, w + 2, h + 2, wowmock.rgb("2e3138"), 1)
    elif label == "SHINY":
        canvas.fill(x - 2, y - 2, w + 4, 1, wowmock.rgb("8fe3ff"))
        canvas.fill(x - 2, y + h + 1, w + 4, 1, wowmock.rgb("c8a8ff"))
        canvas.fill(x - 2, y - 2, 1, h + 4, wowmock.rgb("a6d4ff"))
        canvas.fill(x + w + 1, y - 2, 1, h + 4, wowmock.rgb("c8a8ff"))
        sparkle(canvas, x + w + 6, y - 4, 3, wowmock.rgb("d8f2ff"))
    else:
        stroke(canvas, x - 2, y - 2, w + 4, h + 4, colour, 1)

    text(canvas, x, y - 15, name, "GameFontNormalSmall", TEXT, width=w)
    if elite:
        # Elite plates keep the client's gold dragon and gain only a rarity edge, so the two never overlap.
        canvas.draw(ui.atlas("nameplates-icon-elite-gold"), x + w - 15, y - 22, 14, 14)


def main():
    ui = wowmock.Ui(scale=2)
    OUT.mkdir(parents=True, exist_ok=True)

    icons = {
        k: ui.texture(f"interface/icons/{v}.blp")
        for k, v in (
            ("prowler", "ability_hunter_pet_cat"),
            ("boar", "ability_hunter_pet_boar"),
            ("wolf", "ability_hunter_pet_wolf"),
            ("strider", "ability_hunter_pet_tallstrider"),
        )
    }

    def sheet(name, elite=False, plates=False):
        cols, rows = 2, 2
        cell_w, cell_h = 330, 196
        m = 34
        canvas = ui.canvas(cell_w * cols + m * 2, cell_h * rows + m * 2 + 64)
        canvas.fill(0, 0, canvas.width, canvas.height, BG)
        text(canvas, m, 18, "FIELD GUIDE  \u00b7  RARITY TRIM", "GameFontNormal", BRASS)
        text(
            canvas,
            m,
            36,
            "Target frame and nameplate, one tier per cell",
            "GameFontDisableSmall",
            MUTED,
        )
        folk = ["Savannah Prowler", "Bristleback Boar", "Prairie Wolf", "Plainstrider"]
        glyph = ["prowler", "boar", "wolf", "strider"]
        for index, tier in enumerate(TIERS):
            col, row = index % cols, index // cols
            cx = m + col * cell_w
            cy = m + 64 + row * cell_h
            label, odds, colour, _, note = tier
            # Tier heading and odds, the way the guide's own cards title a variant.
            text(canvas, cx, cy, label, "GameFontNormal", colour)
            text(canvas, cx + 62, cy + 1, odds, "GameFontDisableSmall", DIM)
            text(canvas, cx, cy + 16, note, "GameFontDisableSmall", MUTED)

            target_frame(ui, canvas, cx + 14, cy + 46, tier, icons[glyph[index]], folk[index], 12 + index, elite=elite)
            if plates:
                nameplate(ui, canvas, cx + 70, cy + 170, tier, folk[index], elite=elite)
        return canvas

    sheet("target frames").save(OUT / "rarity-target.png")
    sheet("nameplates", plates=True).save(OUT / "rarity-nameplates.png")
    sheet("elite frames", elite=True, plates=True).save(OUT / "rarity-elite.png")
    print("wrote 3 rarity sheets")


if __name__ == "__main__":
    sys.exit(main())
