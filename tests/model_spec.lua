local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness({
	files = { "Locales/enUS.lua", "Core/Model.lua" },
})
local ns = harness.ns
local Model = ns.Model
assert(Model, "Model is exposed on the namespace")

assert(Model.Rank(0) == 0, "no specimens is undiscovered")
assert(Model.Rank(1) == 1, "one is discovered")
assert(Model.Rank(2) == 1, "still discovered")
assert(Model.Rank(3) == 2, "three is observed")
assert(Model.Rank(5) == 2, "still observed")
assert(Model.Rank(6) == 3, "six is studied")
assert(Model.Rank(9) == 3, "still studied")
assert(Model.Rank(10) == 4, "ten is mastered")
assert(Model.Rank(999) == 4, "rank never exceeds mastered")
assert(Model.RANK_NAMES[0] == "Undiscovered" and Model.RANK_NAMES[4] == "Mastered")
assert(Model.LevelRange(40, 40) == "40", "a single-level creature does not print a range")
assert(Model.LevelRange(39, 41) == "39-41", "level ranges use a hyphen")

-- The tier belongs to the spawn, not the species: the same GUID is the same coat on every client.
local guid = Mock.CreatureGUID(1001)
assert(Model.SpawnTier(guid) == Model.SpawnTier(guid), "a spawn GUID always rolls the same tier")
assert(Model.SpawnTier(nil) == "bronze", "a spawn without a readable GUID is bronze")
assert(Model.SpawnTier("") == "bronze", "an empty GUID is bronze")
for _, tier in ipairs(Model.TIERS) do
	assert(Model.IsTier(tier), tier .. " is on the ladder")
end

-- Over many synthetic spawns the nested ladder lands near its stated odds: silver 1 in 25, gold 1 in 100,
-- shiny 1 in 1000. Bronze is everything else.
local counts = { bronze = 0, silver = 0, gold = 0, shiny = 0 }
local samples = 100000
for index = 1, samples do
	local tier = Model.SpawnTier("Creature-0-1-0-1-1001-" .. string.format("%010X", index))
	counts[tier] = counts[tier] + 1
end
local function Near(value, expected, tolerance)
	return value >= expected * (1 - tolerance) and value <= expected * (1 + tolerance)
end
assert(Near(counts.silver, samples / 25, 0.25), "silver is roughly 1 in 25: " .. counts.silver)
assert(Near(counts.gold, samples / 100, 0.25), "gold is roughly 1 in 100: " .. counts.gold)
assert(Near(counts.shiny, samples / 1000, 0.35), "shiny is roughly 1 in 1000: " .. counts.shiny)

local state = Model.NewState()
assert(type(state.species) == "table" and next(state.species) == nil, "a fresh state has no species")

local first = Model.Record(state, 1001, { tier = "bronze" })
assert(first.count == 1 and first.rank == 1 and first.newlyDiscovered, "the first specimen discovers")
assert(first.tier == "bronze" and first.firstBronze, "the first bronze spawn is recorded")
local silver = Model.Record(state, 1001, { tier = "silver" })
assert(silver.tier == "silver" and silver.firstSilver and not silver.firstBronze, "a silver spawn is a new coat")
assert(silver.bestTier == "silver", "silver is the best coat so far")
assert(state.species[1001].bronze == 1 and state.species[1001].silver == 1, "each coat keeps its own count")
for _ = 1, 15 do
	Model.Record(state, 1001, { tier = "bronze" })
end
assert(state.species[1001].count == Model.MASTERED_AT, "specimens stop at ten")
assert(state.species[1001].kills == 17, "recorded kills remain uncapped after mastery")
assert(state.species[1001].bronze == 16, "tier finds keep counting after mastery")
assert(Model.Rank(Model.Specimen(state, 1001).count) == 4, "the cap is mastered")
assert(state.species[1001].firstKill == 0 and state.species[1001].firstSighting == 0, "first records persist")

-- A kill read from the client passes its GUID through, and the GUID decides the coat.
local goldGuid
for index = 1, 100000 do
	local candidate = "Creature-0-1-0-1-1002-" .. string.format("%010X", index)
	if Model.SpawnTier(candidate) == "gold" then
		goldGuid = candidate
		break
	end
end
assert(goldGuid, "a synthetic GUID rolls gold")
state = Model.NewState()
local gold = Model.Record(state, 1002, { guid = goldGuid })
assert(gold.tier == "gold" and state.species[1002].gold == 1, "the spawn GUID records its gold coat")
local plain = Model.Record(state, 1002, {})
assert(plain.tier == "bronze" and state.species[1002].bronze == 1, "a missing GUID falls back to bronze")

-- Old saves migrate onto the ladder: kills become bronze, a completed rare form becomes one silver, a shiny
-- stays one shiny, and gold is never inferred.
local migrated = Model.MigrateEntry({
	count = 7,
	kills = 9,
	rare = 3,
	shiny = 4,
	firstRare = 50,
	firstRareZone = "The Barrens",
	firstShiny = 60,
})
assert(migrated.bronze == 9 and migrated.silver == 1 and migrated.gold == 0 and migrated.shiny == 1)
assert(migrated.firstSilver == 50 and migrated.firstSilverZone == "The Barrens", "the rare first carries to silver")
assert(migrated.firstShiny == 60, "the shiny first survives")
assert(migrated.rare == nil and migrated.rareKills == nil and migrated.shinyFinds == nil, "old form fields go")
local partialRare = Model.MigrateEntry({ count = 4, rare = 2, shiny = 0 })
assert(partialRare.bronze == 4 and partialRare.silver == 0 and partialRare.shiny == 0, "unfinished old forms stay put")
local alreadyNew = Model.MigrateEntry({ bronze = 5, silver = 2, gold = 1, shiny = 1 })
assert(alreadyNew.bronze == 5 and alreadyNew.silver == 2 and alreadyNew.gold == 1 and alreadyNew.shiny == 1)

state = Model.NewState()
assert(Model.RecordSighting(state, 1001, 123, "The Barrens"), "first visible nameplate is recorded")
assert(not Model.RecordSighting(state, 1001, 124, "The Barrens"), "later nameplates do not replace the first")
assert(state.species[1001].firstSighting == 123 and state.species[1001].firstSightingZone == "The Barrens")
local seenEncounter = Model.ObserveEncounter(state, 77, "Example Boss", 2, 150, "Example Dungeon")
assert(seenEncounter.firstSighting, "first boss encounter start records a personal sighting")
local encounter = Model.RecordEncounter(state, 77, "Example Boss", 2, 200, "Example Dungeon")
assert(encounter.firstKill and encounter.kills == 1, "first successful boss encounter is recorded")
encounter = Model.RecordEncounter(state, 77, "Example Boss", 3, 300, "Example Dungeon")
assert(not encounter.firstKill and encounter.kills == 2, "boss encounter count remains uncapped")
assert(encounter.record.difficulties["2"] == 1 and encounter.record.difficulties["3"] == 1)
assert(
	encounter.record.sightings == 1 and encounter.record.firstSighting == 150,
	"successful clears do not inflate attempt counts"
)

local zone = { species = { { id = 12345 }, { id = 12346 } } }
state = Model.NewState()
Model.Record(state, zone.species[1].id, { tier = "silver" })
Model.Record(state, zone.species[2].id, { tier = "bronze" })
local progress = Model.ZoneProgress(state, zone.species)
assert(progress.total == #zone.species, "every species counts toward the zone")
assert(progress.catalogued == 2, "two species are catalogued")
assert(math.abs(progress.fraction - 2 / #zone.species) < 1e-9, "the fraction is catalogued over total")
local empty = Model.ZoneProgress(Model.NewState(), {})
assert(empty.total == 0 and empty.catalogued == 0 and empty.fraction == 0, "an empty list has no division by zero")
local totals = Model.TierTotals(state, zone.species)
assert(totals.silver == 1 and totals.gold == 0 and totals.shiny == 0, "header totals count species per coat")

Model.ClearSightings()
for index = 1, 55 do
	Model.AddSighting({
		time = index,
		zone = "The Barrens",
		species = "Creature " .. index,
		kind = "kill",
	})
end
assert(#Model.Sightings == 50, "the session log keeps fifty")
assert(Model.Sightings[1].time == 55, "newest first")
assert(Model.Sightings[50].time == 6, "the oldest kept is the 6th")
Model.ClearSightings()
assert(#Model.Sightings == 0, "clearing empties the log")

print("model: ok")
