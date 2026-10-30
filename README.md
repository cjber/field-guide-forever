# Field Guide Forever

A field journal for the creatures of Azeroth. Hostile NPC deaths reported in a catalogued zone are recorded in the journal. The addon reads names, levels, ranks and placements from the player’s Forever QuestieDB; the catalogue follows that database as it updates. Rare creatures keep separate personal records, and each observed death has a 1-in-500 shiny roll.

Field Guide Forever is cosmetic only. It never grants player power, changes combat or calls a protected function.

## Features

- A live catalogue of creatures across outdoor zones, dungeons and raids, including NPC levels, families and ranks from QuestieDB.
- Uncapped recorded-death totals, with a separate ten-step mastery track: Discovered, Observed, Studied and Mastered.
- Character-local first sightings and first observed deaths, plus first rare and shiny records.
- By default, shared cumulative records and earliest firsts are exchanged with guild and group addon users; disable this
  in the options to stop sending/receiving. Local tracking continues when sharing is off.
- An Instances page for bosses reported by encounter events, with local first clears, attempts, kill totals and
  difficulty records. Entries appear after the client reports an encounter; this is not a verified world-first board.
- Common, rare and shiny variants. A rare species needs three sightings to confirm its rare variant; a shiny is a
  1-in-500 roll on every kill.
- A session sighting log, so the day's walk stays with the journal until the client closes.
- Search, status filters and CREATURES, RARES, SHINY and INSTANCES tabs.
- Tracking for the species you are currently working on.
- A movable, closable window that remembers where you left it. `/fieldguide` or `/fg` toggles it.

## Creature database

Install Questie or the standalone QuestieDB addon. Field Guide reads the Forever QuestieDB API at runtime and shows an install prompt when it is missing or incompatible. Creature names, levels, ranks and spawn locations are not bundled. Client-only zone names, instance types, families and portrait IDs are generated from pinned wago.tools DB2 exports.

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
2. Extract it so the folder is `World of Warcraft/Interface/AddOns/FieldGuideForever`.
3. Make sure `FieldGuideForever.toc` is directly inside that folder.
4. Install Questie or QuestieDB, then restart the client or type `/reload`.

The addon targets the WoW: Forever client, Interface 16001.

## Screenshots

<!-- SCREENSHOT_GALLERY:START -->
![A short walk through the journal](docs/screenshots/demo.gif)

## Feature previews

![Creatures journal](docs/screenshots/field-guide.png)

![Rares page](docs/screenshots/rares.png)

![Personal rare record](docs/screenshots/rare-record.png)

![Shiny page](docs/screenshots/shiny.png)

![Personal shiny record](docs/screenshots/shiny-record.png)

![Search and status filter](docs/screenshots/search-filter.png)

![Tracked species](docs/screenshots/tracking.png)

![Options panel](docs/screenshots/settings.png)

![Field Guide micro menu button](docs/screenshots/micro-menu-field-guide.png)

![Micro menu button settings](docs/screenshots/micro-menu-options.png)

![Session sighting log](docs/screenshots/sighting-log.png)

![Target frame rarity](docs/screenshots/rarity-target.png)

![Nameplate rarity](docs/screenshots/rarity-nameplates.png)

![Elite rarity chrome](docs/screenshots/rarity-elite.png)

![Instance boss record](docs/screenshots/instances-boss.png)

![QuestieDB install prompt](docs/screenshots/missing-questiedb.png)

## Zone pages

| | | |
| --- | --- | --- |
| ![Dun Morogh](docs/screenshots/zone-0001.png) | ![Duskwood](docs/screenshots/zone-0010.png) | ![Azshara](docs/screenshots/zone-0016.png) |
| ![Loch Modan](docs/screenshots/zone-0038.png) | ![Burning Steppes](docs/screenshots/zone-0046.png) | ![Ashenvale](docs/screenshots/zone-0331.png) |
| ![Hillsbrad Foothills](docs/screenshots/zone-0267.png) | ![Desolace](docs/screenshots/zone-0405.png) | ![Mount Hyjal](docs/screenshots/zone-0616.png) |
| ![Undercity](docs/screenshots/zone-1497.png) | ![Orgrimmar](docs/screenshots/zone-1637.png) | ![Hall of Legends](docs/screenshots/zone-2917.png) |
<!-- SCREENSHOT_GALLERY:END -->
These mocked screenshots use the WoW: Forever client art and a disposable fixture extracted from the pinned QuestieDB Forever release into the ignored `tools/.cache/` directory. The addon never ships that fixture; in game it reads the player’s installed QuestieDB. The shared renderer in `forever-core` caches WoW: Forever client assets under `~/.cache/wowmock/`; set `FOREVER_CORE` to that checkout when regenerating scenes.

## Credits

Made by cjber. Blizzard Entertainment for Azeroth, its creatures and the client art the journal is built from; the WoW: Forever project for the client it is written for; and QuestieDB, read at runtime, for the creatures themselves. Thanks to everyone who reports a creature missing from the catalogue, a bug or a feature idea, here or on CurseForge. [THIRD_PARTY.md](THIRD_PARTY.md) lists every input and the full credits.

World of Warcraft is a trademark of Blizzard Entertainment, Inc. This addon is not affiliated with or endorsed by
Blizzard Entertainment.
