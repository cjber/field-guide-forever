Field Guide Forever keeps a journal of the creatures you kill in Azeroth, zone by zone. It is cosmetic only: it never grants power, changes combat or calls a protected function.

Free, with nothing locked behind it. If you enjoy it, you can [buy me a coffee on Ko-fi](https://ko-fi.com/cjber).

![The Field Guide stepping through creatures, instances and the coat filters in several zones](https://raw.githubusercontent.com/cjber/field-guide-forever/main/docs/screenshots/demo.gif)

Every catalogued zone has its own page of creatures, with your kills and research rank for each.

![The Field Guide on Badlands, with the creature list on the left and Siege Golem's entry on the right](https://raw.githubusercontent.com/cjber/field-guide-forever/main/docs/screenshots/field-guide.png)

Pick a creature to see its level, zone and how far you are towards Mastered. The bar at the bottom is the zone's completion.

![The Creatures page filtered to Silver found, with Irradiated Invader selected and its bronze, silver, gold and shiny slots](https://raw.githubusercontent.com/cjber/field-guide-forever/main/docs/screenshots/variants.png)

Creatures and Instances share the side rail. The list opens on Discovered. Silver, gold and shiny are filters, and each entry shows all four coats a spawn can wear.

![The Records tab for Alamar Grimm with when it was first and last seen and the best coat found](https://raw.githubusercontent.com/cjber/field-guide-forever/main/docs/screenshots/shiny-record.png)

Records keep when you first and last saw a creature, how many deaths you recorded and the best coat you have found.

## Features

- **Journal**: creatures across outdoor zones, dungeons and raids, with their level, rank and zone. It opens on Discovered, so a new character starts with what they have actually met. Search by name, filter by status or coat, and switch between the Creatures and Instances tabs.
- **Research ranks**: kills move a species through Discovered (1), Observed (3), Studied (6) and Mastered (10). The kill count keeps going after that.
- **Zone completion**: the share of a zone's species you have recorded.
- **The coat ladder**: every spawn is bronze, silver (1 in 25), gold (1 in 100) or shiny (1 in 1000), decided by a stable hash of its spawn GUID. Every player sees the same coat on the same spawn, and the journal keeps how many of each you have found.
- **Rarity marks**: a silver, gold or shiny spawn wears the client's own classification art at its own size — the rare silver frame for silver, the elite gold portrait ring for gold, and the winged silver ring with a slow light sheen for shiny — plus the coat's quality mark in the target frame's bottom-left corner and a SILVER, GOLD or SHINY tag. Its nameplate gets the same quality mark to the right of the health bar. Health bars, names and the client's own rare, elite and boss art keep their colours. Bronze creatures look exactly as they always did, and `/fg preview` cycles the three higher coats for this session.
- **Sizes**: a spawn is usually 0.80x to 1.30x its normal size on a bell curve, from the same stable hash as its coat with a different salt. About one spawn in 200 is Tiny (under 0.70x) or Giant (over 1.40x). The journal keeps its smallest and largest kill per species, the target frame tag shows the spawn's size to hunt, and Tiny and Giant finds get a badge and a toast.
- **Records**: first sighting, first kill and the smallest and largest size for each creature, kept per character, and a sighting log for the current session.
- **Tracking**: mark the species you are working on.
- **Instances**: bosses the game reports when an encounter ends, with first clears, attempts and kills by difficulty. It is a personal record, not a verified world-first board.
- **Sharing**: totals and first records are exchanged with guild and group members who run the addon. `/fgf leaderboard` ranks kills, with peer totals marked as reported. Turn sharing off in the options; local tracking carries on.

## How kills are counted

The Forever client keeps the combat log from addons, so Field Guide counts the kills it can see: a creature you have targeted, or whose nameplate is showing, dies and nobody outside your group tagged it first. A rare also counts when its map marker, seen alive, turns dead while it is on your minimap. Each death counts once.

A creature that dies with no nameplate showing and not targeted is not counted. Turn on enemy nameplates (`V`) to catch everything you fight.

## Usage

Type `/fg` or `/fieldguide`, press Shift-F, or click the Field Guide button on the minimap rim; drag it around the rim to move it, or hide it in the options. `/fg preview` shows every creature as silver, gold or shiny for this session, `/fgf leaderboard` prints the kill leaderboard and `/fgf help` lists the commands. Options are under Options > AddOns > Field Guide Forever.

Field Guide needs [Questie](https://www.curseforge.com/wow/addons/questie) or the standalone QuestieDB addon for its creature list. Without one, the window says what to install.

<!-- forever-family:start -->

## The Forever addons

Each one works on its own, and they work together when you install more than one.

| Addon | What it does |
|---|---|
| [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) | Plans journeys on foot, by air, by sea and through portals, with directions in the tracker. |
| [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) | Suggests quests for your level and routes you from one to the next. |
| [SkillUp Forever](https://www.curseforge.com/wow/addons/skillup-forever) | Shows skill-up chances, recipe costs and levelling routes in the Professions window. |
| [Legacy Forever](https://www.curseforge.com/wow/addons/legacy-forever) | Shows your unfinished Legacy challenges on the world map and tracks the ones you choose. |
| [Tweaks Forever](https://www.curseforge.com/wow/addons/tweaks-forever) | Adds quest automation, rare alerts and merchant options to the game's settings. |

<!-- forever-family:end -->

Source code: [github.com/cjber/field-guide-forever](https://github.com/cjber/field-guide-forever). Licence: GPL-3.0-or-later.

Built with AI assistance.
