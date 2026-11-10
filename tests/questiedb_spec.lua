-- Integrations/QuestieDB.lua against the pinned QuestieDB contract: the catalogue is read over several frames through
-- the public API alone, ZoneDB's override table is optional, and an install off the contract is reported as
-- unsupported instead of read.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local FILES = { "Locales/enUS.lua", "Data/Client.lua", "Data/CreatureIcons.lua", "Core/LegacyIds.lua" }

---@param ns table
local function BuildCatalogue(ns)
	ns.SpeciesById, ns.SpeciesZone, ns.ZoneByName = {}, {}, {}
	for _, zone in ipairs(ns.Zones) do
		ns.ZoneByName[zone.name:lower()] = zone
		for _, species in ipairs(zone.species) do
			ns.SpeciesById[species.id] = species
			ns.SpeciesZone[species.id] = zone
		end
	end
	for _, map in ipairs(ns.Instances) do
		for _, species in ipairs(map.species) do
			ns.SpeciesById[species.id] = species
		end
	end
end

---@return table
local function Harness()
	local harness = Mock.Harness({ files = FILES })
	harness.ns.BuildCatalogue = function()
		BuildCatalogue(harness.ns)
	end
	harness.Load("Integrations/QuestieDB.lua")
	return harness
end

local probe = Mock.Harness({ files = FILES })
local barrens
for id, zone in pairs(probe.ns.ClientData.zones) do
	if zone.name == "The Barrens" then
		barrens = id
	end
end
assert(barrens, "pinned client constants contain the Barrens")

local ROWS = {
	[50001] = {
		name = "Plainstrider",
		minLevel = 1,
		maxLevel = 2,
		rank = 0,
		subName = "Beast",
		zoneID = barrens,
		spawns = { [barrens] = {} },
	},
	[50002] = {
		name = "Fixture Boss",
		minLevel = 60,
		maxLevel = 60,
		rank = 3,
		subName = "Boss",
		zoneID = barrens,
		spawns = { [barrens] = {} },
	},
	[50003] = {
		name = "Fixture Rare",
		minLevel = 30,
		maxLevel = 31,
		rank = 2,
		subName = "Beast",
		zoneID = barrens,
		spawns = { [barrens] = {} },
	},
}

local reads = 0
local function Npc(ids)
	return {
		GetAllIds = function()
			return ids
		end,
		GetAll = function(id, fields)
			reads = reads + 1
			local row, values = ROWS[id], {}
			for index, field in ipairs(fields) do
				values[index] = row and row[field]
			end
			return values
		end,
	}
end

-- The catalogue is read in slices, so no frame carries the whole database.
local sliced = Harness()
sliced.env.LibQuestieDB = {
	RequireContract = function()
		return true
	end,
	Npc = Npc({ 50003, 50002, 50001 }),
}
reads = 0
local now = 0
sliced.env.debugprofilestop = function()
	now = now + 5
	return now
end
local ready = 0
sliced.ns.QuestieDB.Start(function()
	ready = ready + 1
end)
sliced:RunTimers()
assert(ready == 0 and sliced.ns.QuestieDB.State() == "loading", "the catalogue does not build in one frame")
assert(reads < 3, "the first slice reads part of the database")
assert(#Mock.timers > 0, "the build schedules the next slice")
while #Mock.timers > 0 do
	sliced:RunTimers()
end
assert(ready == 1 and sliced.ns.QuestieDB.State() == "ok", "the catalogue is ready once every slice has run")
assert(reads == 3 and sliced.ns.SpeciesById[50001], "the whole catalogue is built across the slices")

-- QuestieDB's NpcDB global is its entity reader, not a table of raw rows: it can never be the catalogue's source,
-- and reading it as one used to claim an empty catalogue was ready.
local stray = Harness()
stray.env.QuestieDB = { NpcDB = { GetAll = function() end, meta = {} } }
local strayReady = 0
stray.ns.QuestieDB.Start(function()
	strayReady = strayReady + 1
end)
while #Mock.timers > 0 do
	stray:RunTimers()
end
assert(stray.ns.QuestieDB.State() == "missing", "the NpcDB global is not a catalogue source")
assert(strayReady == 0 and next(stray.ns.SpeciesById or {}) == nil, "no catalogue is claimed without the public API")

-- Nor is a raw row a fallback when the public reader has no answer for an id.
local mixed = Harness()
mixed.env.LibQuestieDB = {
	RequireContract = function()
		return true
	end,
	Npc = {
		GetAllIds = function()
			return { 50001 }
		end,
		GetAll = function()
			return nil
		end,
	},
}
mixed.env.QuestieDB = { NpcDB = ROWS }
mixed.ns.QuestieDB.Start(function() end)
while #Mock.timers > 0 do
	mixed:RunTimers()
end
assert(mixed.ns.SpeciesById[50001] == nil, "raw NpcDB rows are never a fallback")

-- QuestieDB's ZoneDB override table is optional when no area needs remapping.
local optional = Harness()
optional.env.LibQuestieDB = {
	RequireContract = function()
		return true
	end,
	Support = {
		Get = function()
			return { private = { areaIdToUiMapId = "return {[17]=100}" } }
		end,
	},
}
local area, override = optional.ns.QuestieDB.AreaMaps()
assert(area and area[17] == 100, "the base area map is read")
assert(type(override) == "table" and next(override) == nil, "a ZoneDB without overrides is an empty override table")

-- Only a QuestieDB this file was written for is read: on the contract's range and carrying the Forever rows.
local function Settle(lib, flavour)
	local harness = Harness()
	harness.env.LibQuestieDB = lib
	if flavour then
		harness.env.C_AddOns.GetAddOnMetadata = function()
			return flavour
		end
	end
	local readyCount = 0
	harness.ns.QuestieDB.Start(function()
		readyCount = readyCount + 1
	end)
	while #Mock.timers > 0 do
		harness:RunTimers()
	end
	return harness.ns.QuestieDB.State(), readyCount
end

local state = Settle({ Npc = Npc({ 50001 }) })
assert(state == "unsupported", "a QuestieDB without its contract check is not read")
state = Settle({
	RequireContract = function()
		return false
	end,
	Npc = Npc({ 50001 }),
})
assert(state == "unsupported", "a QuestieDB outside the contract range is not read")
state = Settle({
	RequireContract = function()
		return true
	end,
	Npc = Npc({ 50001 }),
}, "Camelot")
assert(state == "unsupported", "a QuestieDB for another flavour is not read")
local ok, readyCount = Settle({
	RequireContract = function()
		return true
	end,
	Npc = Npc({ 50001 }),
})
assert(ok == "ok" and readyCount == 1, "the Forever contract is read")

print("questiedb: ok")
