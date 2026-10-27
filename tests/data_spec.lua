local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local harness = Mock.Harness({
	files = { "Locales/enUS.lua", "Data/Client.lua", "Data/CreatureIcons.lua", "Core/LegacyIds.lua" },
})
local ns = harness.ns
harness.Load("Integrations/QuestieDB.lua")
ns.BuildCatalogue = function()
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
ns.QuestieDB.Start(function()
	error("missing QuestieDB cannot become ready")
end)
assert(ns.QuestieDB.State() == "missing", "missing shared data is an explicit state")
local barrens, shadowfang, hinterlands
for id, zone in pairs(ns.ClientData.zones) do
	if zone.name == "The Barrens" then
		barrens = id
	elseif zone.name == "Shadowfang Keep" and zone.continent == 33 then
		shadowfang = id
	elseif zone.name == "The Hinterlands" and zone.continent == 0 then
		hinterlands = id
	end
end
assert(barrens, "pinned client constants contain the Barrens")
assert(shadowfang and ns.ClientData.zones[shadowfang].continent == 33, "instance area data points to its client map")
assert(
	hinterlands and ns.ClientData.zones[hinterlands].continent ~= 47,
	"outdoor area IDs do not equal instance map IDs"
)
ns.LegacyIds[90001] = "Fixture Beast"
ns.db = { chars = { ["Player-Realm"] = { species = { [90001] = { count = 4 } } } } }
local fixture = {
	[50001] = {
		name = "Fixture Beast",
		minLevel = 4,
		maxLevel = 5,
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
		zoneID = 0,
		spawns = { [shadowfang] = {} },
	},
	[50003] = {
		name = "Hinterlands Boss",
		minLevel = 60,
		maxLevel = 60,
		rank = 3,
		subName = "Dragon",
		zoneID = hinterlands,
		spawns = { [hinterlands] = {} },
	},
}
harness.env.LibQuestieDB = {
	Npc = {
		GetAllIds = function()
			return { 50003, 50002, 50001 }
		end,
		GetAll = function(id, fields)
			local row, values = fixture[id], {}
			for _, field in ipairs(fields) do
				values[#values + 1] = row[field]
			end
			return values
		end,
	},
}
local ready = 0
ns.QuestieDB.Start(function()
	ready = ready + 1
end)
harness:RunTimers()
assert(ready == 1 and ns.QuestieDB.State() == "ok", "populated shared data becomes ready")
assert(ns.SpeciesById[50001].id == 50001, "the game NPC id is the stable species identity")
assert(ns.SpeciesById[50001].family == "Unknown", "an NPC title is not treated as its creature type")
assert(ns.SpeciesById[50001].zone == "The Barrens", "outdoor NPCs group under their client zone")
assert(ns.db.chars["Player-Realm"].species[50001].count == 4, "schema migration rekeys legacy IDs to NPC IDs")
assert(ns.db.chars["Player-Realm"].species[90001] == nil, "legacy IDs are dropped after remapping")
local bossMap
for _, map in ipairs(ns.Instances) do
	if map.id == 33 then
		bossMap = map
	end
end
assert(bossMap and bossMap.species[1].id == 50002 and bossMap.species[1].boss, "instance bosses group under their map")
assert(bossMap.name == "Shadowfang Keep", "instance grouping resolves area IDs through their parent map")
for _, map in ipairs(ns.Instances) do
	assert(map.id ~= 47, "an outdoor area ID is not mistaken for the Razorfen Kraul map")
end
assert(ns.SpeciesById[50003] and ns.SpeciesById[50003].zone == "The Hinterlands", "outdoor NPCs stay in their zone")
assert(ns.ClientData.build == "1.60.1.70630", "generated constants retain the pinned Forever build")
print("data: ok")
