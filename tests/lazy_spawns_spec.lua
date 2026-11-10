-- The catalogue keeps the facts the journal draws, and reads a species' spawn points from QuestieDB only when a
-- habitat map or the public spawn query asks for them. The login build therefore retains no spawn point tables, and
-- asking twice reads QuestieDB once.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns

local barrens, hinterlands
for id, zone in pairs(ns.ClientData.zones) do
	if zone.name == "The Barrens" then
		barrens = id
	elseif zone.name == "The Hinterlands" and zone.continent == 0 then
		hinterlands = id
	end
end
assert(barrens and hinterlands, "pinned client constants contain the fixture zones")

local rows = {
	[60001] = {
		name = "Plainstrider",
		minLevel = 1,
		maxLevel = 2,
		rank = 0,
		subName = "Beast",
		zoneID = barrens,
		spawns = { [barrens] = { { 25, 50 }, { 30, 60 } } },
	},
	[60002] = {
		name = "Wandering Beast",
		minLevel = 4,
		maxLevel = 5,
		rank = 0,
		subName = "Beast",
		zoneID = barrens,
		spawns = {
			[barrens] = { { 40, 40 } },
			[hinterlands] = { { 70, 20 } },
		},
	},
}

local getAllReads, getReads = 0, 0
local function FreshSpawns(id)
	local copy = {}
	for area, points in pairs(rows[id].spawns) do
		local list = {}
		for index, point in ipairs(points) do
			list[index] = { point[1], point[2] }
		end
		copy[area] = list
	end
	return copy
end

harness.env.LibQuestieDB = {
	RequireContract = function()
		return true
	end,
	Npc = {
		GetAllIds = function()
			return { 60001, 60002 }
		end,
		GetAll = function(id, fields)
			getAllReads = getAllReads + 1
			local row, values = rows[id], {}
			for index, field in ipairs(fields) do
				values[index] = field == "spawns" and FreshSpawns(id) or row[field]
			end
			return values
		end,
		Get = function(id, key)
			getReads = getReads + 1
			return key == "spawns" and FreshSpawns(id) or rows[id][key]
		end,
	},
	Support = {
		Get = function(name)
			assert(name == "ZoneDB")
			return {
				private = {
					areaIdToUiMapId = ("return {[%d]=100, [%d]=101}"):format(barrens, hinterlands),
					areaIdToUiMapIdOverride = "return {}",
				},
			}
		end,
	},
}

harness:Fire("ADDON_LOADED", "FieldGuideForever")
while #Mock.timers > 0 do
	harness:RunTimers()
end
assert(ns.ready and ns.QuestieDB.State() == "ok", "the catalogue builds")

-- Placement still reads every spawn area while the catalogue is built, so a creature that spawns in two zones is
-- listed in both, yet no point table is kept afterwards.
local function Listed(zoneName, speciesId)
	for _, zone in ipairs(ns.Zones) do
		if zone.name == zoneName then
			for _, species in ipairs(zone.species) do
				if species.id == speciesId then
					return true
				end
			end
		end
	end
	return false
end
assert(Listed("The Barrens", 60002), "the spawn areas still place a creature in its first zone")
assert(Listed("The Hinterlands", 60002), "the spawn areas still place a creature in its second zone")

local retained = 0
for _, species in pairs(ns.SpeciesById) do
	if species.spawns ~= nil then
		retained = retained + 1
	end
end
assert(retained == 0, "the build retains no species' spawn point tables: " .. retained)
assert(getReads == 0, "the build asks for no spawn points again: " .. getReads)
assert(getAllReads == 2, "the build reads each catalogue row once: " .. getAllReads)

local species = ns.SpeciesById[60001]
local points = assert(ns.QuestieDB.Spawns(species), "a species' spawn points are read on demand")
assert(points[barrens] and #points[barrens] == 2, "the demanded spawn points are the species' own")
assert(getReads == 1, "the species' spawn points are read once: " .. getReads)
assert(ns.QuestieDB.Spawns(species) == points, "the next ask reuses the species' spawn points")
assert(getReads == 1, "a second ask reads nothing: " .. getReads)

local apiRows = assert(ns.API.Spawns(60002), "the public spawn query still answers after the lazy read")
assert(#apiRows == 2, "the public spawn query returns every point: " .. #apiRows)
assert(getReads == 2, "the public spawn query reads only the species it names: " .. getReads)
local again = assert(ns.API.Spawns(60002), "the public spawn query answers again")
assert(#again == 2 and again[1] ~= apiRows[1], "each public answer is its own rows")
assert(getReads == 2, "a second public query reads nothing: " .. getReads)

print("lazy spawns: ok")
