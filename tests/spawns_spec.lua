local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness()
local API = harness.env.FieldGuideForever.API
local creature = {
	name = "Plainstrider",
	minLevel = 1,
	maxLevel = 2,
	rank = 0,
	subName = "Beast",
	zoneID = 17,
	spawns = {
		[17] = { { 25, 50 }, { 0.5, nil }, { -1, 40 }, { 250, 50 } },
		[18] = { { 75, 80 } },
	},
}
harness.env.LibQuestieDB = {
	Npc = {
		GetAllIds = function()
			return { 1001 }
		end,
		GetAll = function(_, fields)
			local values = {}
			for _, field in ipairs(fields) do
				values[#values + 1] = creature[field]
			end
			return values
		end,
	},
	RequireContract = function(version)
		assert(version == 2)
		return true
	end,
	Support = {
		Get = function(name)
			assert(name == "ZoneDB")
			return {
				private = {
					areaIdToUiMapId = "return {[17]=100, [18]=101}",
					areaIdToUiMapIdOverride = "return {[18]=202}",
				},
			}
		end,
	},
}

local spawnsBefore, spawnsBeforeReason = API.Spawns(1001)
assert(spawnsBefore == nil and spawnsBeforeReason == "loading", "spawns are loading before ADDON_LOADED")
harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:RunTimers()

local rows = API.Spawns(1001)
assert(rows and #rows == 2, "valid spawn coordinates are returned")
assert(rows[1].map == 100 and rows[1].x == 0.25 and rows[1].y == 0.5, "AreaId map and coordinates are converted")
assert(rows[2].map == 202 and rows[2].x == 0.75 and rows[2].y == 0.8, "QuestieDB overrides take precedence")
assert(rows[1].speciesID == 1001 and rows[1].name == "Plainstrider" and not rows[1].rare)
assert(not rows[1].catalogued and rows[1].minLevel == 1 and rows[1].maxLevel == 2)
rows[1].x = 99
rows[1].name = "Changed"
local fresh = API.Spawns(1001)
assert(fresh[1].x == 0.25 and fresh[1].name == "Plainstrider", "each call returns independent row copies")
local zoneRows = API.ZoneSpawns("The Barrens")
assert(zoneRows and #zoneRows == 1 and zoneRows[1].map == 100, "zone queries return only that zone's AreaId rows")
local unknownSpecies, unknownSpeciesReason = API.Spawns(999999)
local unknownZone, unknownZoneReason = API.ZoneSpawns("Unknown Zone")
assert(unknownSpecies == nil and unknownSpeciesReason == "none", "an unknown species has nothing to answer")
assert(unknownZone == nil and unknownZoneReason == "none", "an unknown zone has nothing to answer")
local badId, badIdReason = API.Spawns("1001")
assert(badId == nil and badIdReason == "none", "a species ID that is not a whole number has nothing to answer")

local firstArea, firstOverride = harness.ns.QuestieDB.AreaMaps()
local compileCalls = 0
harness.env.loadstring = function(source)
	compileCalls = compileCalls + 1
	return loadstring(source)
end
local cachedArea, cachedOverride = harness.ns.QuestieDB.AreaMaps()
assert(
	cachedArea == firstArea and cachedOverride == firstOverride and compileCalls == 0,
	"unchanged maps reuse compiled tables"
)
local originalSupportGet = harness.env.LibQuestieDB.Support.Get
harness.env.LibQuestieDB.Support.Get = function()
	return { private = { areaIdToUiMapId = "return {[17]=303}", areaIdToUiMapIdOverride = "return {}" } }
end
local updatedArea = harness.ns.QuestieDB.AreaMaps()
assert(
	updatedArea ~= firstArea and updatedArea[17] == 303 and compileCalls == 2,
	"changed support strings invalidate map cache"
)
harness.env.LibQuestieDB.Support.Get = originalSupportGet
harness.env.loadstring = nil

harness:Kill("Plainstrider")
local catalogued = API.Spawns(1001)
assert(catalogued[1].catalogued, "catalogued reports this character's specimen progress")

local withoutSupport = Mock.Harness()
withoutSupport.env.LibQuestieDB = {
	RequireContract = function()
		return true
	end,
	Npc = {
		GetAllIds = function()
			return { 1001 }
		end,
		GetAll = function(_, fields)
			local values = {}
			for _, field in ipairs(fields) do
				values[#values + 1] = creature[field]
			end
			return values
		end,
	},
}
withoutSupport:Fire("ADDON_LOADED", "FieldGuideForever")
withoutSupport:RunTimers()
local noSupport, noSupportReason = withoutSupport.env.FieldGuideForever.API.Spawns(1001)
assert(noSupport == nil and noSupportReason == "loading", "missing QuestieDB Support fails closed as loading")

creature.zoneID = 2917
creature.spawns = { [2917] = { { 50, 50 } } }
local barracks = Mock.Harness()
barracks.env.LibQuestieDB = {
	RequireContract = function()
		return true
	end,
	Npc = harness.env.LibQuestieDB.Npc,
}
barracks:Fire("ADDON_LOADED", "FieldGuideForever")
barracks:RunTimers()
assert(
	barracks.ns.SpeciesZone[1001].continent == barracks.ns.ClientData.maps[450].name,
	"a non-continent outdoor map uses its generated name instead of a numeric breadcrumb"
)

print("spawns: ok")
