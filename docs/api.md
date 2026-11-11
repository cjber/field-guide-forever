# FieldGuideForever.API

Other addons can read Field Guide Forever's catalogue and this character's progress through the global
`FieldGuideForever.API`. It is version 3, minor 7: check `version == 3` and that each function
exists before calling it. On ForeverCore 1.3.2 or later the API is also listed by `ForeverCore.APIKit.Addons()`. The
full types are in [`types/API.lua`](../types/API.lua).

Every call returns fresh tables that you may keep or change. A zone is named as the client names it, such as
`"The Barrens"`, not by uiMapID. Spawn rows carry the uiMapID in `map` and coordinates from 0 to 1.

The catalogue's zone records carry no uiMapID, only the client's AreaTable ID, so `Zones()` has no `map` field and
`Species()`, `ZoneSpawns()` and `Progress()` accept only a zone name. A spawn's `map` is resolved through QuestieDB's
own area tables, never guessed from a zone's name.

## Published functions

| function | answer |
|---|---|
| `Ready()` and `IsReady()` | whether the saved state and catalogue are ready |
| `SpawnTier(unit)` | the spawn tier a unit token shows |
| `TrackedSpecies()` and `SetTrackedSpecies(speciesId)` | the species the tracker follows, or set it |
| `Subscribe(callback)` | hear the frame after a sighting, tier, zone, specimen or tracked change |
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
| `Stats()` | this character's own total for each metric the addon counts |

The `Get*` names, `IsReady`, `Creature`, `ZoneProgress` and `SpeciesState` are deprecated aliases of the plain names
beside them. They stay published and answer exactly the same; new code uses the plain name.

## Minor history

`version` changes only when a published member breaks. Additions keep it and raise `minor`, so a caller checks the
member it wants with `type(api.Name) == "function"`.

- No minor (version 1, 0.1.0): the first contract, `Ready()`, `Zones()`, `Species()`, `SpeciesById()`, `Progress()`,
  `Specimen()`, `Sightings()` and `Specimens()` with their aliases.
- minor 1: `Spawns()` and `ZoneSpawns()`.
- minor 2: version 2, the tier ladder. `Specimen()` and `Specimens()` report `bronze`, `silver`, `gold` and `shiny`
  counts and firsts in place of the old rare fields. `Encounters()` was added after minor 1 without raising it, so
  check that it exists rather than trusting the minor number for it.
- minor 3: `sizeSmallest`, `sizeLargest`, `tiny` and `giant` on `Specimen()` and `Specimens()`.
- minor 4: those four size fields are gone again. Code that ran on minor 3 must not rely on them.
- minor 5: every read that has nothing to answer now returns a second value, the reason. `SuiteLeaderboard()` was
  added here and is gone in minor 7.
- minor 6: `SpawnTier`, `TrackedSpecies`, `SetTrackedSpecies`, `Subscribe`, `Stats`.
- minor 7: version 3, Forever Leaderboards is gone. `Leaderboard()`, `SuiteLeaderboard()`, `LeaderboardSummary()`,
  `GetLeaderboardSummary()`, `SharedStats()` and `GetSharedStats()` are no longer published, and no read answers
  `"disabled"`. `Stats()` stays.

## Not ready

A read that has nothing to answer returns `nil, reason`, as `ForeverCore.APIKit.NotReady` builds it. `nil` alone is
still a valid answer for callers written before minor 5: the first value is unchanged.

| reason | meaning |
|---|---|
| `"loading"` | Field Guide is still building its catalogue or saved state, so ask again later |
| `"none"` | there is nothing to answer, such as an unknown zone, species or argument |

`Zones()`, `Sightings()`, `Specimens()` and `Encounters()` answer `nil, "loading"` until the saved state and catalogue
are ready, and never `"none"`. `Species()`, `SpeciesById()`, `Progress()`, `Specimen()`, `ZoneSpawns()` and `Spawns()`
answer `"loading"` then, and `"none"` for a zone or species the catalogue does not hold. `Spawns()` and `ZoneSpawns()`
also answer `"loading"` while QuestieDB's zone maps are not available yet. `Stats()` answers `"loading"` until the
saved state is ready. `TrackedSpecies()` answers `"loading"` until this character's state exists and `"none"` while
nothing is tracked. `SpawnTier()` answers `"none"` for a unit that does not exist, a player or a unit the player
cannot attack, and never `"loading"`. `Ready()` and `IsReady()` never answer nil.

## `Subscribe(callback) -> unsubscribe`

Available from minor 6, built on `ForeverCore.APIKit.Hub`. `callback(changes)` runs on the frame after a change, at
most once per burst, however many events landed in it. `changes` is a fresh table holding only what changed, with
one or more of these keys set to `true`:

| key | change |
|---|---|
| `sighting` | a species seen for the first time |
| `tier` | a first silver, gold or shiny of a species |
| `zone` | a zone's catalogue completed |
| `specimen` | a species' record changed, such as a kill or a rank |
| `tracked` | the tracked species changed, by the player or by `SetTrackedSpecies()` |

Read the API again rather than replaying the change. The channel counters are bumped where Core first produces the
event, not in the toast UI, so `sighting`, `tier` and `zone` fire whether or not the player has milestone toasts on.
The first subscriber takes what the channels answer then as its baseline and hears only later changes. Nothing is
read or sent until this character's state exists. The returned function unsubscribes and is safe to call twice.

## `Ready() -> boolean`

Whether the saved variables have loaded and the QuestieDB catalogue is built. Every other read answers `"loading"`
until it is true, except `SpawnTier()` and the writes.

## `SpawnTier(unit) -> string?`

Available from minor 6. The spawn tier a unit token such as `"target"`, `"nameplate3"` or `"mouseover"` shows, for
nameplates, target frames and WeakAuras: `"bronze"`, `"silver"`, `"gold"` or `"shiny"`. It is read from the unit's
readable GUID through the same function the target frame and nameplate art use, so two players looking at one spawn
agree. Preview tiers from `/fg preview` are session UI state and are never returned. A unit that does not exist, a
player, or a unit the player cannot attack has no spawn tier: `nil, "none"`, not the bronze the art falls back to.

## `Zones() -> { name, continent }[]?`

Every open-world zone in the catalogue, in the client's order, as `name` and `continent`. The record carries no
uiMapID, so there is no `map` field; spawn rows are the published places.

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

## `TrackedSpecies() -> integer?`

Available from minor 6. The QuestieDB NPC ID of the species the shared tracker column follows, or `nil, "none"`
while nothing is tracked. It is the saved switch that survives a reload, so it can name a species the catalogue no
longer holds. `nil, "loading"` comes before this character's state exists.

## `SetTrackedSpecies(speciesId) -> boolean`

Available from minor 6. Track a catalogue species, or clear the tracker with `nil`. It writes the same saved switch
as the journal's Track Species button, refreshes the section the same way and raises the `tracked` channel, with no
sound and no chat line. `true` when the switch changed; `false` for a species ID the catalogue does not hold, a
malformed ID, and a call that changes nothing, such as setting the species already tracked.

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

## `Stats() -> FGAPIStatsRow[]?`

Available from minor 6. This character's own observation totals in the suite's activity shape: a fresh array with
one row per metric the addon counts, each `{ addon = "FieldGuideForever", metric, subject = "all", value }` and an
optional `eventUnix`. `subject` is `"all"` because a row is this character's total, not one species or encounter.
`value` is 0 when the character has nothing for that metric. `eventUnix` is the latest real event time for the metric
and is left out when there is none. The metrics are `creature_kills`, `bronze_finds`, `silver_finds`, `gold_finds`,
`shiny_finds`, `first_sighting`, `first_kill`, `first_bronze`, `first_silver`, `first_gold`, `first_shiny`,
`boss_sightings`, `boss_kills`, `boss_first_sighting` and `boss_first_kill`. It is a local read of this character's
own records.
