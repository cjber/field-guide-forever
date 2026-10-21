# Bestiary Forever

A field journal for the creatures of Azeroth. Every hostile creature a character kills is recorded in its zone's
catalogue, from the plainstriders of Mulgore to the worgen of Silverpine. Rare creatures keep their own variant
records, and one kill in five hundred turns up a shiny colour variant.

Bestiary Forever is cosmetic only. It never grants player power, changes combat or calls a protected function.

## Features

- A zone-by-zone catalogue of 183 Classic creatures across ten starting zones, each with a real family, level range
  and a line of field notes.
- Specimen counts with four research ranks: Discovered, Observed, Studied and Mastered.
- Common, rare and shiny variants. A rare species needs three sightings to confirm its rare variant; a shiny is a
  1-in-500 roll on every kill.
- A session sighting log, so the day's walk stays with the journal until the client closes.
- Search, status filters and BESTIARY, RARES and SHINY tabs.
- Tracking for the species you are currently working on.
- A movable, closable window that remembers where you left it. `/bestiary` or `/bst` toggles it.

## Zones

| Continent | Zones |
| --- | --- |
| Kalimdor | The Barrens, Durotar, Mulgore, Teldrassil |
| Eastern Kingdoms | Elwynn Forest, Westfall, Redridge Mountains, Loch Modan, Tirisfal Glades, Silverpine Forest |

## Research ranks

| Specimens | Rank | What it means |
| --- | --- | --- |
| 1 | Discovered | The species is in the journal. |
| 3 | Observed | Enough sightings to note how it behaves. |
| 6 | Studied | A proper entry, with its habits recorded. |
| 10 | Mastered | The full plate, and the gold mark in the list. |

A species is catalogued in its zone from the first specimen. Zone completion counts catalogued species, not mastered
ones, so the bar moves with every new creature rather than waiting for a long grind.

## Installing

1. Download the zip from the latest release.
2. Extract it so the folder is `World of Warcraft/Interface/AddOns/BestiaryForever`.
3. Make sure `BestiaryForever.toc` is directly inside that folder.
4. Restart the client or type `/reload`.

The addon targets the WoW: Forever client, Interface 16001. It has no dependencies.

## Screenshots

![A short walk through the journal](docs/screenshots/demo.gif)

The three pages of the journal:

![The Bestiary page](docs/screenshots/bestiary.png)

![Rare species](docs/screenshots/rares.png)

![A shiny sighting](docs/screenshots/shiny.png)

Ten creatures from ten zones, one per page, in the order the catalogue opens them:

| | | |
| --- | --- | --- |
| ![Savannah Prowler, The Barrens](docs/screenshots/creature-01.png) | ![Durotar](docs/screenshots/creature-02.png) | ![Mulgore](docs/screenshots/creature-03.png) |
| ![Teldrassil](docs/screenshots/creature-04.png) | ![Elwynn Forest](docs/screenshots/creature-05.png) | ![Westfall](docs/screenshots/creature-06.png) |
| ![Redridge Mountains](docs/screenshots/creature-07.png) | ![Loch Modan](docs/screenshots/creature-08.png) | ![Tirisfal Glades](docs/screenshots/creature-09.png) |
| ![Silverpine Forest](docs/screenshots/creature-10.png) | | |

All of them are rendered from this addon's own catalogue and palette by `tools/preview.py` (`python3
tools/preview.py`), which reads `Data/Creatures.lua` and draws the window, list and detail panel the way
`UI/Window.lua`, `UI/List.lua` and `UI/Detail.lua` lay them out. The creature plates stand in for the client's
portraits, which live in the game archives, and the per-species progress is derived from the species id so the
render is reproducible.

## Credits

- cjber, for the addon and the rest of the Forever addon suite.
- Blizzard Entertainment, for Azeroth, its creatures and the client art the journal is built from.
- The WoW: Forever project, for the client this addon is written for.
- Everyone who reports a creature that is missing from the catalogue.

World of Warcraft is a trademark of Blizzard Entertainment, Inc. This addon is not affiliated with or endorsed by
Blizzard Entertainment.
