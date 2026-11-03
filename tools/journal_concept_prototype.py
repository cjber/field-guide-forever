#!/usr/bin/env python3
"""Throwaway Field Guide composition, not an in-game screenshot.

Run: FOREVER_CORE=/path/to/forever-core uv run --with pillow==12.3.0 python tools/journal_concept_prototype.py
Native journal artwork is resolved by wowmock against 1.60.1.70124.
Archaedas image: https://wow.zamimg.com/modelviewer/classic/webthumbs/npc/100/5988.webp
Display 5988 for NPC 2748 comes from gen_creature_icons.py's pinned CMaNGOS source.
The CDN reference is composition-only; runtime would use a live PlayerModel widget.
Counts and selected state below are illustrative, not saved player progress.
"""

import os
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(os.environ["FOREVER_CORE"]) / "tools/wowmock"))
import wowmock  # noqa: E402

ui = wowmock.Ui(scale=2)
c = ui.canvas(1040, 750)
f = wowmock.FONTS
ink = (0, 0, 0)
body = wowmock.Font(f["GameFontHighlight"].path, 12, ink)
heading = wowmock.Font(f["GameFontHighlightLarge"].path, 16, ink)
small = wowmock.Font(f["GameFontHighlightSmall"].path, 10, ink)
rock = ui.texture("interface/framegeneral/ui-background-rock.blp")
wowmock.tiled(c, rock, 28, 48, 968, 622, rock.width / 2, rock.height / 2)
c.draw(ui.atlas("_UI-Frame-TopTileStreaks"), 30, 47, 962, 43)
wowmock.portrait_frame_art(c, 26, 26, 974, 654, "interface/icons/inv_misc_book_09.blp", "Field Guide")
wowmock.search_box(c, 53, 76, 255, instructions="Search creatures")
c.text(735, 83, "Barry Buckfast", f["GameFontNormal"], width=220, justify="RIGHT")
# Native Encounter Journal open book, with unused transparent sheet area removed.
book = ui.texture("interface/encounterjournal/ui-ej-journalbg.blp").crop((0, 0, 784, 425))
c.draw(book, 52, 119, 920, 920 * 425 / 784)
# Left page: location artwork and a compact native selection list.
c.text(86, 145, "Uldaman", heading)
c.draw(ui.texture("interface/lfgframe/lfgicon-uldaman.blp"), 86, 179, 164, 164)
c.text(269, 183, "Badlands", heading)
c.text(269, 215, "Creatures encountered", body)
c.text(269, 239, "4 discovered", body)
c.text(269, 259, "1 mastered", body)
c.text(86, 367, "Encounters", heading)
for i, name in enumerate(("Revelosh", "Ironaya", "Galgann Firehammer", "Archaedas")):
    y = 402 + i * 39
    if i == 3:
        c.draw(ui.texture("interface/questframe/ui-questtitlehighlight.blp"), 79, y - 6, 386, 33, blend="ADD")
    c.text(96, y, name, body)
    c.text(417, y, "6 / 10" if i == 3 else "Seen", small, width=43, justify="RIGHT")
# Right page: name, model and a single progress line, no nested cards.
c.text(553, 145, "Archaedas", heading, width=370, justify="CENTER")
c.text(553, 172, "Ancient Stone Watcher", small, width=370, justify="CENTER")
model = Image.open(ROOT / "tools/prototype-assets/archaedas-classic.webp").convert("RGBA")
c.draw(model, 569, 207, 335, 335)
c.text(555, 561, "Studied", heading, width=365, justify="CENTER")
c.text(555, 588, "6 / 10 observations", body, width=365, justify="CENTER")
wowmock.panel_tabs(c, 553, 620, ["Overview", "Variants", "Records"])
wowmock.ui_panel_button(c, 64, 638, 126, 24, "Open map")
c.text(
    29,
    704,
    "Design concept - sample progress. Model image is a composition reference, not a client capture.",
    f["GameFontHighlightSmall"],
    width=974,
    justify="CENTER",
)
c.save(ROOT / "docs/prototypes/journal-concept.png")
print(ROOT / "docs/prototypes/journal-concept.png")
