# FieldGuideForever.API

Other addons can read Field Guide Forever's catalogue, this character's progress and the shared kill leaderboard
through the global `FieldGuideForever.API`. It is version 2, minor 5: check `version == 2` and that each function
exists before calling it. The full types are in [`types/API.lua`](../types/API.lua).

Every call returns fresh tables that you may keep or change. A zone is named as the client names it, such as
`"The Barrens"`, not by uiMapID. Spawn rows carry the uiMapID in `map` and coordinates from 0 to 1.

## Published functions

| function | answer |
|---|---|
| `Ready()` and `IsReady()` | whether the saved state and catalogue are ready |
| `Zones()` | every open-world zone and its continent |
| `Species(zoneName?)` and `GetSpecies(zoneName?)` | the species in a zone, or in the zone you are in |
| `SpeciesById(speciesId)`, `GetSpeciesById(speciesId)`, `Creature(speciesId)` and `GetCreature(speciesId)` | one species |
| `Progress(zoneName?)`, `GetProgress(zoneName?)`, `ZoneProgress(zoneName?)` and `GetZoneProgress(zoneName?)` | one zone's catalogued count |
| `Specimen(speciesId)`, `GetSpecimen(speciesId)` and `SpeciesState(speciesId)` | one species' progress |
| `Sightings()` and `GetSightings()` | this session's sighting log |
| `Specimens()` and `GetSpecimens()` | every species with its progress |
| `Encounters()` and `GetEncounters()` | this character's boss encounters |
| `Spawns(speciesId)` | one species' spawn points |
| `ZoneSpawns(zoneName?)` | one zone's spawn points |
| `Leaderboard(metric, subject)` | ranked rows for one metric and subject |
| `SuiteLeaderboard(limit?)` | the suite's leaderboard shape for creature kills |
| `LeaderboardSummary()` and `GetLeaderboardSummary()` | the compact kill leaderboard |
| `SharedStats()` and `GetSharedStats()` | the peer-reported metric table |

The `Get*` names, `IsReady`, `Creature`, `ZoneProgress` and `SpeciesState` are deprecated aliases of the plain names
beside them. They stay published and answer exactly the same; new code uses the plain name.

## Minor history

`version` changes only when a published member breaks. Additions keep it and raise `minor`, so a caller checks the
member it wants with `type(api.Name) == "function"`.

- No minor (version 1, 0.1.0): the first contract, `Ready()`, `Zones()`, `Species()`, `SpeciesById()`, `Progress()`,
  `Specimen()`, `Sightings()` and `Specimens()` with their aliases.
- minor 1: `Spawns()` and `ZoneSpawns()`.
- minor 2: version 2, the tier ladder. `Specimen()` and `Specimens()` report `bronze`, `silver`, `gold` and `shiny`
  counts and firsts in place of the old rare fields. `Encounters()`, `Leaderboard()`, `LeaderboardSummary()` and
  `SharedStats()` were added after minor 1 without raising it, so check that each exists rather than trusting the
  minor number for them.
- minor 3: `sizeSmallest`, `sizeLargest`, `tiny` and `giant` on `Specimen()` and `Specimens()`.
- minor 4: those four size fields are gone again. Code that ran on minor 3 must not rely on them.
- minor 5: `SuiteLeaderboard()`, and every read that has nothing to answer now returns a second value, the reason.

## Not ready

A read that has nothing to answer returns `nil, reason`, as `ForeverCore.APIKit.NotReady` builds it. `nil` alone is
still a valid answer for callers written before minor 5: the first value is unchanged.

| reason | meaning |
|---|---|
| `"loading"` | Field Guide is still building its catalogue or saved state, so ask again later |
| `"disabled"` | the player turned sharing off |
| `"none"` | there is nothing to answer, such as an unknown zone, species or argument |

`Zones()`, `Sightings()`, `Specimens()`, `Encounters()` and `LeaderboardSummary()` answer `nil, "loading"` until the
saved state and catalogue are ready, and never `"disabled"` or `"none"`. `Species()`, `SpeciesById()`, `Progress()`,
`Specimen()`, `ZoneSpawns()` and `Spawns()` answer `"loading"` then, and `"none"` for a zone or species the catalogue
does not hold. `Leaderboard()` answers `"loading"` then and `"none"` for an argument that is not a string.
`SuiteLeaderboard()` answers `"loading"` then and `"none"` for a limit that is not a whole number of zero or more.
`Spawns()` and `ZoneSpawns()` also answer `"loading"` while QuestieDB's zone maps are not available yet.
`SharedStats()` answers `"loading"` then and `"disabled"` while sharing is off. `Ready()` and `IsReady()` never
answer nil.

## No Subscribe yet

Version 2 minor 5 has no `Subscribe()`. Read a function again when you need a fresh answer; a later minor will add
`Subscribe()` through `ForeverCore.APIKit.Hub` and list its change names here. Until then there are no change names.

## `Ready() -> boolean`

Whether the saved variables have loaded and the QuestieDB catalogue is built. Every other read answers `"loading"`
until it is true.

## `Zones() -> { name, continent }[]?`

Every open-world zone in the catalogue, in the client's order, as `name` and `continent`.

## `Species(zoneName?) -> FGSpecies[]?`

The species listed under a zone. Without a name it answers for the zone the player is in. Each row carries the
catalogue's shared facts: `id`, `name`, `family`, `minLevel`, `maxLevel`, `zone`, `rare` and `lore`.

## `SpeciesById(speciesId) -> FGSpecies?`

One species by QuestieDB NPC ID. `SpeciesState` is the same call under its old name.

## `Progress(zoneName?) -> { zone, catalogued, total, fraction }?`

One zone's progress for this character: how many species are catalogued, how many the zone holds, and the fraction
between them. Without a name it answers for the zone the player is in.

## `Specimen(speciesId) -> FGAPISpecimen?`

One species' saved progress for this character. `count` is the number of specimens toward mastery, `kills` the
observed kills, and `killsEstimated` says whether the kills came from a save that counted only specimens. `rank` is
the mastery rank, `bestTier` the best coat found, and `bronze`, `silver`, `gold` and `shiny` say whether each coat
was found, with the counts in `bronzeCount`, `silverCount`, `goldCount` and `shinyCount`. Each first has its
`time()` stamp and the zone where it happened: `firstSighting` and `firstSightingZone`, `firstKill` and
`firstKillZone`, then the same pair for `firstBronze`, `firstSilver`, `firstGold` and `firstShiny`.

## `Sightings() -> FGSighting[]?`

This session's sighting log, newest first. Each line has `time`, `zone`, `species` and `kind`. The log is not saved
and is empty after a reload.

## `Specimens() -> FGAPISpecimenSummary[]?`

Every species with its current progress, for a caller drawing its own summary: `id`, `name`, `zone`, `count`,
`kills`, `killsEstimated`, `rank`, `bestTier`, `silver`, `gold` and `shiny`.

## `Encounters() -> FGAPIEncounter[]?`

This character's recorded boss encounters, sorted by name. These are local records from the client's own encounter
events, not a complete dungeon catalogue or externally verified firsts. Each row has `id`, `name`, `instance`,
`kills`, `sightings`, the first sighting and first kill with their difficulty IDs and names, and `difficulties` and
`difficultyNames` keyed by the difficulty ID as a string.

## `Spawns(speciesId) -> FGSpawn[]?`

One species' spawn points, each resolved through QuestieDB's own ZoneDB tables to a uiMapID and 0 to 1 coordinates.
A spawn whose zone has no known map is left out rather than guessed. Each row has `speciesID`, `name`, `rare`,
`catalogued`, `minLevel`, `maxLevel`, `map`, `x` and `y`.

## `ZoneSpawns(zoneName?) -> FGSpawn[]?`

The spawn points of every species in a zone, in the same row shape as `Spawns()`. Without a name it answers for the
zone the player is in.

## `Leaderboard(metric, subject) -> FGAPILeaderboardRow[]?`

Ranked rows for one metric and subject: `player`, `value`, `time` and `source`, where `source` is `"local"` for this
character or `"peer"` for a report received from another player. Peer values are player reports and are not
independently verified. The local row stays when sharing is off.

Metrics are `creature_kills` and the coat finds `bronze_finds`, `silver_finds`, `gold_finds` and `shiny_finds`, each
with the species ID as the subject, plus `first_sighting`, `first_kill`, `first_bronze`, `first_silver`, `first_gold`
and `first_shiny`. `creature_kills` with the subject `all` is this character's total across the catalogue. Boss
metrics are `boss_kills`, `boss_sightings`, `boss_first_kill` and `boss_first_sighting`, with the encounter ID as the
subject, or the encounter ID and difficulty as `"id_difficulty"` for `boss_kills`.

## `SuiteLeaderboard(limit?) -> FGAPISuiteLeaderboard?`

Available from minor 5. The suite's leaderboard shape over the same rows as `Leaderboard("creature_kills", "all")`:
`metric` is `"creature_kills"`, `scope` is `"guild_group"`, `sharing` says whether sharing is on, `total` counts
every eligible row, and `rows` are ranked rows with `rank`, `name`, `value`, an optional `eventUnix` and `self` set
on this character's row. Peer values are player reports and are not independently verified.

The default top list is 10, capped at 25. A non-integer or negative limit answers `nil, "none"`. Zero asks for only
this character's row. This character's row is always included, even when it ranks below the limit. With sharing off
the peer rows are left out and the local row remains.

## `LeaderboardSummary() -> { player, value, source }[]?`

A compact kill leaderboard: one row per player with `player`, `value` and `source`, where `source` is `"local"` for
this character or `"reported"` for a peer total. It uses a peer's `all` total when they reported one, and otherwise
sums their per-species kill reports, so it can include a peer who has not reported the `all` subject.

## `SharedStats() -> table<string, table>?`

Every peer report this character has received, as `player -> addon -> subject -> metric -> { value, time }`. It
answers `nil, "disabled"` while sharing is off. Peer values are player reports and are not independently verified.
