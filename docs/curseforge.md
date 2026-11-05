Field Guide Forever keeps a journal of the creatures you kill in Azeroth, zone by zone. It is cosmetic only: it never grants power, changes combat or calls a protected function.

Free, with nothing locked behind it. If you enjoy it, you can [buy me a coffee on Ko-fi](https://ko-fi.com/cjber).

![The Field Guide stepping through creatures, instances, rares and shinies in several zones](https://raw.githubusercontent.com/cjber/field-guide-forever/main/docs/screenshots/demo.gif)

Every catalogued zone has its own page of creatures, with your kills and research rank for each.

![The Field Guide on Badlands, with the creature list on the left and Siege Golem's entry on the right](https://raw.githubusercontent.com/cjber/field-guide-forever/main/docs/screenshots/field-guide.png)

Pick a creature to see its level, zone and how far you are towards Mastered. The bar at the bottom is the zone's completion.

![The Rares tab with Digmaster Shovelphlange selected and his common and rare variants marked as known](https://raw.githubusercontent.com/cjber/field-guide-forever/main/docs/screenshots/rares.png)

Rares have their own tab, and the Variants tab shows which forms of a creature you have recorded.

![The Records tab for Alamar Grimm with the dates of the first sighting, first kill and first shiny](https://raw.githubusercontent.com/cjber/field-guide-forever/main/docs/screenshots/shiny-record.png)

Records keep the date you first saw a creature, first killed one and first found its rare or shiny variant.

## Features

- **Journal**: creatures across outdoor zones, dungeons and raids, with their level, rank and zone. Search by name, filter by status, and switch between the Creatures, Rares, Shiny and Instances tabs.
- **Research ranks**: kills move a species through Discovered (1), Observed (3), Studied (6) and Mastered (10). The kill count keeps going after that.
- **Zone completion**: the share of a zone's species you have recorded.
- **Rares and shinies**: a rare variant is confirmed after three sightings, and every recorded kill has a 1 in 500 chance of a shiny.
- **Rarity marks**: some species are silver, gold or shiny, the same for every player. A rare target frame gets a soft tier-coloured aura and a RARE or SHINY tag; its nameplate gets a soft glow and a small tier mark. Health bars and names keep the game's own colours. Shiny creatures pulse gently. `/fg preview` shows all three for this session.
- **Records**: first sighting and first kill for each creature, kept per character, and a sighting log for the current session.
- **Tracking**: mark the species you are working on.
- **Instances**: bosses the game reports when an encounter ends, with first clears, attempts and kills by difficulty. It is a personal record, not a verified world-first board.
- **Sharing**: totals and first records are exchanged with guild and group members who run the addon. `/fgf leaderboard` ranks kills, with peer totals marked as reported. Turn sharing off in the options; local tracking carries on.

## How kills are counted

The Forever client keeps the combat log from addons, so Field Guide counts the kills it can see: a creature you have targeted, or whose nameplate is showing, dies and nobody outside your group tagged it first. A rare also counts when its map marker, seen alive, turns dead while it is on your minimap. Each death counts once.

A creature that dies with no nameplate showing and not targeted is not counted. Turn on enemy nameplates (`V`) to catch everything you fight.

## Usage

Type `/fg` or `/fieldguide`, press Shift-F, or click the Field Guide button in the micro menu. `/fg preview` shows every creature as silver, gold or shiny for this session, `/fgf leaderboard` prints the kill leaderboard and `/fgf help` lists the commands. Options are under Options > AddOns > Field Guide Forever.

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
