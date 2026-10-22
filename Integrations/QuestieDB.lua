---@type string, FGNamespace
local _, ns = ...

local DB = {}
ns.QuestieDB = DB
local status = "missing"
local WAIT = 60
local REQUIRED = { "name", "minLevel", "maxLevel", "rank", "subName", "zoneID", "spawns" }

local function IsJournalInstance(map)
	return map and (map.instanceType == 1 or map.instanceType == 2)
end

local function State(nextState)
	status = nextState
	ns.catalogueStatus = nextState
end

function DB.State()
	return status
end

local function ReadNpc(id, lib)
	if lib and lib.Npc and type(lib.Npc.GetAll) == "function" then
		local values = lib.Npc.GetAll(id, REQUIRED)
		if type(values) == "table" then
			local row = {}
			for i, key in ipairs(REQUIRED) do
				row[key] = values[i]
			end
			return row
		end
	end
	local raw = type(QuestieDB) == "table" and QuestieDB.NpcDB
	return type(raw) == "table" and raw[id] or nil
end

local function Build()
	local lib = LibQuestieDB
	local raw = type(QuestieDB) == "table" and QuestieDB.NpcDB
	local sourceIds
	if type(lib) == "table" and type(lib.Npc) == "table" and type(lib.Npc.GetAllIds) == "function" then
		sourceIds = lib.Npc.GetAllIds()
	elseif type(raw) == "table" then
		sourceIds = {}
		for id in pairs(raw) do
			if tonumber(id) then
				sourceIds[#sourceIds + 1] = tonumber(id)
			end
		end
	else
		return false
	end
	local ids = {}
	for _, id in ipairs(type(sourceIds) == "table" and sourceIds or {}) do
		if tonumber(id) then
			ids[#ids + 1] = tonumber(id)
		end
	end
	local zonesById, zones, zoneIds = {}, {}, {}
	for id in pairs(ns.ClientData.zones) do
		zoneIds[#zoneIds + 1] = tonumber(id)
	end
	table.sort(zoneIds)
	for _, id in ipairs(zoneIds) do
		local entry = ns.ClientData.zones[id]
		local zone = {
			id = id,
			name = entry.name,
			continent = ns.ClientData.continents[entry.continent] or tostring(entry.continent),
			species = {},
		}
		zonesById[id] = zone
		zones[#zones + 1] = zone
	end
	local speciesById, speciesByName, instanceSpecies = {}, {}, {}
	table.sort(ids)
	for _, id in ipairs(ids) do
		local row = ReadNpc(id, lib)
		if type(row) == "table" and type(row.name) == "string" and row.name ~= "" then
			local zoneId = tonumber(row.zoneID)
			local spawnZones = {}
			if type(row.spawns) == "table" then
				for z in pairs(row.spawns) do
					if tonumber(z) then
						spawnZones[#spawnZones + 1] = tonumber(z)
					end
				end
				table.sort(spawnZones)
			end
			if zoneId then
				spawnZones[#spawnZones + 1] = zoneId
			end
			table.sort(spawnZones)
			local unique = {}
			for _, spawnZone in ipairs(spawnZones) do
				if unique[#unique] ~= spawnZone then
					unique[#unique + 1] = spawnZone
				end
			end
			spawnZones = unique
			local species = {
				id = tonumber(id),
				name = row.name,
				minLevel = tonumber(row.minLevel) or 1,
				maxLevel = tonumber(row.maxLevel) or tonumber(row.minLevel) or 1,
				family = type(row.subName) == "string" and row.subName ~= "" and row.subName or "Unknown",
				rank = tonumber(row.rank) or 0,
				rare = tonumber(row.rank) == 2,
				boss = tonumber(row.rank) == 3,
				zoneID = zoneId,
				spawns = row.spawns or {},
			}
			speciesById[species.id] = species
			local nameKey = species.name:lower()
			if not speciesByName[nameKey] then
				speciesByName[nameKey] = species.id
			end
			local placed = false
			for _, z in ipairs(spawnZones) do
				if zonesById[z] then
					species.zone = zonesById[z].name
					zonesById[z].species[#zonesById[z].species + 1] = species
					placed = true
				end
				local map = ns.ClientData.maps[z]
				if IsJournalInstance(map) then
					local group = instanceSpecies[z]
						or { id = z, name = map.name, instanceType = map.instanceType, species = {} }
					instanceSpecies[z] = group
					group.species[#group.species + 1] = species
					placed = true
				end
			end
			if not placed and zoneId and zonesById[zoneId] then
				species.zone = zonesById[zoneId].name
				zonesById[zoneId].species[#zonesById[zoneId].species + 1] = species
			end
		end
	end
	for index = #zones, 1, -1 do
		local zone = zones[index]
		if #zone.species == 0 then
			table.remove(zones, index)
		else
			table.sort(zone.species, function(a, b)
				return a.id < b.id
			end)
		end
	end
	local instances = {}
	for _, group in pairs(instanceSpecies) do
		table.sort(group.species, function(a, b)
			return a.id < b.id
		end)
		instances[#instances + 1] = group
	end
	table.sort(instances, function(a, b)
		return a.id < b.id
	end)
	ns.Zones, ns.Instances, ns.SpeciesById = zones, instances, speciesById
	ns.BuildCatalogue()
	if ns.db and ns.LegacyIds then
		for _, state in pairs(ns.db.chars or {}) do
			local remapped = {}
			for oldId, entry in pairs(state.species or {}) do
				local oldName = ns.LegacyIds[tonumber(oldId)]
				local target
				if oldName then
					target = speciesByName[oldName:lower()]
				end
				if target then
					remapped[target] = entry
				elseif not oldName then
					remapped[oldId] = entry
				end
			end
			state.species = remapped
		end
	end
	return true
end

function DB.Start(onReady)
	local function settle()
		local ok, built = pcall(Build)
		if ok and built then
			State("ok")
			onReady()
		elseif type(LibQuestieDB) == "table" or type(QuestieDB) == "table" then
			State("unsupported")
		else
			State("missing")
		end
	end
	if type(LibQuestieDB) ~= "table" and type(QuestieDB) ~= "table" then
		State("missing")
		return
	end
	if
		type(Questie) == "table"
		and type(Questie.API) == "table"
		and type(Questie.API.RegisterOnReady) == "function"
	then
		State("loading")
		Questie.API.RegisterOnReady(function()
			C_Timer.After(0, settle)
		end)
		C_Timer.After(WAIT, function()
			if status == "loading" then
				settle()
			end
		end)
	else
		C_Timer.After(0, settle)
	end
end

function DB.Prompt()
	return status == "missing" or status == "unsupported" or status == "loading"
end
