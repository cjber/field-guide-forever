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

-- The size is the spawn's too: the same GUID gives the same size on every client, from a bell body and two tails
-- of about one spawn in 200 each.
local sizeGuid = Mock.CreatureGUID(1001)
assert(Model.SpawnSize(sizeGuid) == Model.SpawnSize(sizeGuid), "a spawn GUID always rolls the same size")
assert(Model.SpawnSize(nil) == nil, "a spawn without a readable GUID has no size")
assert(Model.SpawnSize("") == nil, "an empty GUID has no size")
assert(Model.FormatSize(112) == "1.12x" and Model.FormatSize(84) == "0.84x", "sizes show two decimals")
assert(Model.SizeBadge(65) == "TINY" and Model.SizeBadge(145) == "GIANT" and Model.SizeBadge(112) == nil)

local sizes, tiny, giant, body = 100000, 0, 0, 0
local sizeSum, bodySum, inSpread = 0, 0, 0
for index = 1, sizes do
	local value = Model.SpawnSize("Creature-0-1-0-1-1001-" .. string.format("%010X", index))
	assert(value and value >= 60 and value <= 155, "a size stays inside its ladder: " .. tostring(value))
	sizeSum = sizeSum + value / 100
	if value < Model.SIZE_TINY then
		tiny = tiny + 1
	elseif value > Model.SIZE_GIANT then
		giant = giant + 1
	else
		body = body + 1
		bodySum = bodySum + value / 100
		if value >= 80 and value <= 120 then
			inSpread = inSpread + 1
		end
	end
end
assert(Near(tiny, sizes / 200, 0.35), "Tiny is roughly 1 in 200: " .. tiny)
assert(Near(giant, sizes / 200, 0.35), "Giant is roughly 1 in 200: " .. giant)
assert(body > sizes * 0.98, "almost every spawn is in the body")
local mean = sizeSum / sizes
assert(mean > 0.98 and mean < 1.02, "sizes average around 1.00x: " .. mean)
assert(bodySum / body > 0.99 and bodySum / body < 1.01, "the body averages around 1.00x")
assert(inSpread >= body * 0.9, "the body clusters in 0.80x to 1.20x: " .. inSpread / body)

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

-- Each species keeps its smallest and largest kill per character, and the two tails count as finds.
state = Model.NewState()
local firstSize = Model.Record(state, 1003, { tier = "bronze", size = 112 })
assert(
	firstSize.sizeSmallest == 112 and firstSize.sizeLargest == 112 and firstSize.newSmallest and firstSize.newLargest,
	"the first sized kill sets both records"
)
local smaller = Model.Record(state, 1003, { tier = "bronze", size = 84 })
assert(smaller.newSmallest and not smaller.newLargest, "a smaller kill sets the smallest record")
assert(smaller.sizeSmallest == 84 and smaller.sizeLargest == 112, "the largest record stays")
local larger = Model.Record(state, 1003, { tier = "bronze", size = 127 })
assert(larger.newLargest and not larger.newSmallest, "a larger kill sets the largest record")
local middle = Model.Record(state, 1003, { tier = "bronze", size = 100 })
assert(not middle.newLargest and not middle.newSmallest, "a size inside the range is not a record")
local tinyKill = Model.Record(state, 1003, { tier = "bronze", size = 65 })
assert(tinyKill.tiny and tinyKill.firstTiny and not tinyKill.giant, "under 0.70x is a Tiny find")
local giantKill = Model.Record(state, 1003, { tier = "bronze", size = 145 })
assert(giantKill.giant and giantKill.firstGiant and not giantKill.tiny, "over 1.40x is a Giant find")
assert(state.species[1003].tiny == 1 and state.species[1003].giant == 1, "each tail keeps its own count")
assert(state.species[1003].sizeSmallest == 65 and state.species[1003].sizeLargest == 145, "tails become records")

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
