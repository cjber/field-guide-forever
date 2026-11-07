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
- **Rarity marks**: a silver, gold or shiny spawn wears a laurel ornament around its portrait that grows from a plain silver ring with one oak sprig through the gold wreath to a fuller crystal wreath. Silver and shiny also keep the client's rare silver frame, and shiny sweeps with a slow light sheen. The tier shows in the ornament's colour, with a SILVER, GOLD or SHINY tag above the name. Its nameplate gets the same quality mark to the right of the health bar. Health bars, names and the client's own rare, elite and boss art keep their colours. Bronze creatures look exactly as they always did, and `/fg preview` cycles the three higher coats for this session.
- **Records**: first sighting, first kill and best coat for each creature, kept per character, and a sighting log for the current session.
- **Track Species**: put the species you are working on in the Forever tracker column every Forever addon shares, with its zone, sightings toward Mastered and kills.
- **Instances**: bosses the game reports when an encounter ends, with first clears, attempts and kills by difficulty. It is a personal record, not a verified world-first board.
- **Sharing**: totals and first records are exchanged with guild and group members who run the addon. `/fgf leaderboard` opens the shared Forever Leaderboards window on the Field Guide tab, with this week's progress, the all-time total and peer values marked as reported. Sharing is on unless you turn it off in the options or the window; local tracking carries on.

## How kills are counted

The Forever client keeps the combat log from addons, so Field Guide counts the kills it can see: a creature you have targeted, or whose nameplate is showing, dies and nobody outside your group tagged it first. A rare also counts when its map marker, seen alive, turns dead while it is on your minimap. Each death counts once.

A creature that dies with no nameplate showing and not targeted is not counted. Turn on enemy nameplates (`V`) to catch everything you fight.

## Usage

Type `/fg` or `/fieldguide`, press Shift-F, or click the Field Guide button on the minimap rim; drag it around the rim to move it, or hide it in the options. `/fg preview` shows every creature as silver, gold or shiny for this session, `/fgf leaderboard` opens Forever Leaderboards on the Field Guide tab and `/fgf help` lists the commands. Options are under Options > AddOns > Field Guide Forever.

Field Guide needs [Questie](https://www.curseforge.com/wow/addons/questie) or the standalone QuestieDB addon for its creature list. Without one, the window says what to install.

<!-- forever-family:start -->

## The Forever addons

Each one works on its own, and they work together when you install more than one.

| Addon | What it does | Issues |
|---|---|---|
| [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) | Plans journeys on foot, by air, by sea and through portals, with directions in the tracker. | [Issues](https://github.com/cjber/shortest-path-forever/issues) |
| [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) | Suggests quests for your level and routes you from one to the next. | [Issues](https://github.com/cjber/adventure-guide-forever/issues) |
| [SkillUp Forever](https://www.curseforge.com/wow/addons/skillup-forever) | Shows skill-up chances, recipe costs and levelling routes in the Professions window. | [Issues](https://github.com/cjber/skillup-forever/issues) |
| [Legacy Forever](https://www.curseforge.com/wow/addons/legacy-forever) | Shows your unfinished Legacy challenges on the world map and tracks the ones you choose. | [Issues](https://github.com/cjber/legacy-forever/issues) |
| [Tweaks Forever](https://www.curseforge.com/wow/addons/tweaks-forever) | Adds quest automation, rare alerts and merchant options to the game's settings. | [Issues](https://github.com/cjber/tweaks-forever/issues) |
| [Field Guide Forever](https://www.curseforge.com/wow/addons/field-guide-forever) | Keeps a cosmetic journal of the creatures you kill, zone by zone. | [Issues](https://github.com/cjber/field-guide-forever/issues) |

Bug reports, feature requests and pull requests are welcome on each addon's GitHub. Everyone whose report or idea ships is thanked by name in the addon's credits and changelog.

For help, ideas and each day's release notes, join [cjber's Workshop on Discord](https://discord.gg/FpHugGxRJY).

<!-- forever-family:end -->

Source code: [github.com/cjber/field-guide-forever](https://github.com/cjber/field-guide-forever). Licence: GPL-3.0-or-later.

Built with AI assistance.
