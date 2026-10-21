local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness({
	files = { "Locales/enUS.lua", "Data/Creatures.lua", "Core/Model.lua" },
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

local state = Model.NewState(function()
	return 1
end)
assert(type(state.species) == "table" and next(state.species) == nil, "a fresh state has no species")

local first = Model.Record(state, 1001)
assert(first.count == 1 and first.rank == 1 and first.newlyDiscovered, "the first specimen discovers")
assert(not first.shiny, "a failing roll is not shiny")
local second = Model.Record(state, 1001)
assert(second.count == 2 and not second.newlyDiscovered, "later specimens are not new discoveries")
for _ = 1, 15 do
	Model.Record(state, 1001)
end
assert(state.species[1001].count == Model.MASTERED_AT, "specimens stop at ten")
assert(Model.Rank(Model.Specimen(state, 1001).count) == 4, "the cap is mastered")

Model.SetRandom(function()
	return 1
end)
state = Model.NewState()
local miss = Model.Record(state, 1001)
assert(not miss.shiny and state.species[1001].shiny == 0, "a roll of one misses")
Model.SetRandom(function()
	return 0
end)
local hit = Model.Record(state, 1001)
assert(hit.shiny and state.species[1001].shiny == Model.SHINY_TARGET, "a roll of zero finds the shiny")
assert(Model.Record(state, 1001).shiny, "the shiny stays found and is rolled per kill")

Model.SetRandom(function()
	return 1
end)
state = Model.NewState()
for count = 1, Model.RARE_TARGET do
	local result = Model.Record(state, 1019, { rare = true })
	assert(result.rare, "a rare species records a rare sighting")
	assert(state.species[1019].rare == count, "rare sightings count up to the target")
end
assert(Model.Variants(state, 1019).rare.known, "the rare variant is known at the target")
Model.Record(state, 1019, { rare = true })
assert(state.species[1019].rare == Model.RARE_TARGET, "rare sightings stop at the target")
assert(Model.Variants(state, 1019).common.known, "the common variant follows discovery")

local zones = ns.Creatures.zones
local zone = zones[1]
state = Model.NewState()
Model.Record(state, zone.species[1].id)
Model.Record(state, zone.species[2].id)
local progress = Model.ZoneProgress(state, zone.species)
assert(progress.total == #zone.species, "every species counts toward the zone")
assert(progress.catalogued == 2, "two species are catalogued")
assert(math.abs(progress.fraction - 2 / #zone.species) < 1e-9, "the fraction is catalogued over total")
local empty = Model.ZoneProgress(Model.NewState(), {})
assert(empty.total == 0 and empty.catalogued == 0 and empty.fraction == 0, "an empty list has no division by zero")

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
