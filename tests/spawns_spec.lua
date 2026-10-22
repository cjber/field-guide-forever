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

assert(API.Spawns(1001) == nil, "spawns are unknown before ADDON_LOADED")
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
assert(API.Spawns(999999) == nil and API.ZoneSpawns("Unknown Zone") == nil, "unknown inputs return nil")

harness:Kill("Plainstrider")
local catalogued = API.Spawns(1001)
assert(catalogued[1].catalogued, "catalogued reports this character's specimen progress")

local withoutSupport = Mock.Harness()
withoutSupport.env.LibQuestieDB = {
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
assert(withoutSupport.env.FieldGuideForever.API.Spawns(1001) == nil, "missing QuestieDB Support fails closed")

print("spawns: ok")
