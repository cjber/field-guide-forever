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

![Session sighting log](docs/screenshots/sighting-log.png)

![Target frame rarity](docs/screenshots/rarity-target.png)

![Nameplate rarity](docs/screenshots/rarity-nameplates.png)

![Elite rarity chrome](docs/screenshots/rarity-elite.png)

![Instance boss record](docs/screenshots/instances-boss.png)

![QuestieDB install prompt](docs/screenshots/missing-questiedb.png)

## Zone pages

| | | |
| --- | --- | --- |
| ![Dun Morogh](docs/screenshots/zone-0001.png) | ![Badlands](docs/screenshots/zone-0003.png) | ![Blasted Lands](docs/screenshots/zone-0004.png) |
| ![Swamp of Sorrows](docs/screenshots/zone-0008.png) | ![Duskwood](docs/screenshots/zone-0010.png) | ![Wetlands](docs/screenshots/zone-0011.png) |
| ![Elwynn Forest](docs/screenshots/zone-0012.png) | ![Durotar](docs/screenshots/zone-0014.png) | ![Dustwallow Marsh](docs/screenshots/zone-0015.png) |
| ![Azshara](docs/screenshots/zone-0016.png) | ![The Barrens](docs/screenshots/zone-0017.png) | ![Western Plaguelands](docs/screenshots/zone-0028.png) |
| ![Stranglethorn Vale](docs/screenshots/zone-0033.png) | ![Alterac Mountains](docs/screenshots/zone-0036.png) | ![Loch Modan](docs/screenshots/zone-0038.png) |
| ![Westfall](docs/screenshots/zone-0040.png) | ![Deadwind Pass](docs/screenshots/zone-0041.png) | ![Redridge Mountains](docs/screenshots/zone-0044.png) |
| ![Arathi Highlands](docs/screenshots/zone-0045.png) | ![Burning Steppes](docs/screenshots/zone-0046.png) | ![The Hinterlands](docs/screenshots/zone-0047.png) |
| ![Searing Gorge](docs/screenshots/zone-0051.png) | ![Tirisfal Glades](docs/screenshots/zone-0085.png) | ![Silverpine Forest](docs/screenshots/zone-0130.png) |
| ![Eastern Plaguelands](docs/screenshots/zone-0139.png) | ![Teldrassil](docs/screenshots/zone-0141.png) | ![Darkshore](docs/screenshots/zone-0148.png) |
| ![Shadowfang Keep](docs/screenshots/zone-0209.png) | ![Mulgore](docs/screenshots/zone-0215.png) | ![Hillsbrad Foothills](docs/screenshots/zone-0267.png) |
| ![Ashenvale](docs/screenshots/zone-0331.png) | ![Feralas](docs/screenshots/zone-0357.png) | ![Felwood](docs/screenshots/zone-0361.png) |
| ![Thousand Needles](docs/screenshots/zone-0400.png) | ![Desolace](docs/screenshots/zone-0405.png) | ![Stonetalon Mountains](docs/screenshots/zone-0406.png) |
| ![Tanaris](docs/screenshots/zone-0440.png) | ![Un'Goro Crater](docs/screenshots/zone-0490.png) | ![Razorfen Kraul](docs/screenshots/zone-0491.png) |
| ![Moonglade](docs/screenshots/zone-0493.png) | ![Mount Hyjal](docs/screenshots/zone-0616.png) | ![Winterspring](docs/screenshots/zone-0618.png) |
| ![The Stockade](docs/screenshots/zone-0717.png) | ![Wailing Caverns](docs/screenshots/zone-0718.png) | ![Blackfathom Deeps](docs/screenshots/zone-0719.png) |
| ![Gnomeregan](docs/screenshots/zone-0721.png) | ![Razorfen Downs](docs/screenshots/zone-0722.png) | ![Scarlet Monastery](docs/screenshots/zone-0796.png) |
| ![Zul'Farrak](docs/screenshots/zone-1176.png) | ![Uldaman](docs/screenshots/zone-1337.png) | ![Silithus](docs/screenshots/zone-1377.png) |
| ![The Temple of Atal'Hakkar](docs/screenshots/zone-1477.png) | ![Undercity](docs/screenshots/zone-1497.png) | ![Stormwind City](docs/screenshots/zone-1519.png) |
| ![Ironforge](docs/screenshots/zone-1537.png) | ![The Deadmines](docs/screenshots/zone-1581.png) | ![Blackrock Spire](docs/screenshots/zone-1583.png) |
| ![Blackrock Depths](docs/screenshots/zone-1584.png) | ![Orgrimmar](docs/screenshots/zone-1637.png) | ![Thunder Bluff](docs/screenshots/zone-1638.png) |
| ![Darnassus](docs/screenshots/zone-1657.png) | ![Zul'Gurub](docs/screenshots/zone-1977.png) | ![Stratholme](docs/screenshots/zone-2017.png) |
| ![Scholomance](docs/screenshots/zone-2057.png) | ![Maraudon](docs/screenshots/zone-2100.png) | ![Onyxia's Lair](docs/screenshots/zone-2159.png) |
| ![Deeprun Tram](docs/screenshots/zone-2257.png) | ![Ragefire Chasm](docs/screenshots/zone-2437.png) | ![Dire Maul](docs/screenshots/zone-2557.png) |
| ![Alterac Valley](docs/screenshots/zone-2597.png) | ![Blackwing Lair](docs/screenshots/zone-2677.png) | ![Molten Core](docs/screenshots/zone-2717.png) |
| ![Hall of Legends](docs/screenshots/zone-2917.png) | ![Champions' Hall](docs/screenshots/zone-2918.png) | ![Warsong Gulch](docs/screenshots/zone-3277.png) |
| ![Arathi Basin](docs/screenshots/zone-3358.png) | ![Ahn'Qiraj](docs/screenshots/zone-3428.png) | ![Ruins of Ahn'Qiraj](docs/screenshots/zone-3429.png) |
| ![Naxxramas](docs/screenshots/zone-3456.png) | ![Riverglades](docs/screenshots/zone-16591.png) | ![Zephras Isle](docs/screenshots/zone-16593.png) |
| ![Ruins of Lordaeron](docs/screenshots/zone-16611.png) | ![Shen'dralas](docs/screenshots/zone-16651.png) | ![The Hall of Thanes](docs/screenshots/zone-16919.png) |
<!-- SCREENSHOT_GALLERY:END -->
These mocked screenshots use the WoW: Forever client art and a disposable fixture extracted from the pinned QuestieDB Forever release into the ignored `tools/.cache/` directory. The addon never ships that fixture; in game it reads the player’s installed QuestieDB. The renderer also caches WoW: Forever client assets under `tools/.cache/wowmock/`.

## Credits

- cjber, for the addon and the rest of the Forever addon suite.
- Blizzard Entertainment, for Azeroth, its creatures and the client art the journal is built from.
- The WoW: Forever project, for the client this addon is written for.
- Everyone who reports a creature that is missing from the catalogue.

World of Warcraft is a trademark of Blizzard Entertainment, Inc. This addon is not affiliated with or endorsed by
Blizzard Entertainment.
