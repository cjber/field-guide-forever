---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

---@class FGQuestieDBModule
local DB = {}
ns.QuestieDB = DB
local status = "missing"
-- Questie can load and then never report ready, when its own startup stops on an error for one character. Waiting
-- longer than this would leave the journal on its loading line for the whole session, so the catalogue is read
-- without Questie's live policy instead.
local WAIT = 60
-- The addon whose metadata the contract and flavour checks read.
local ADDON = "QuestieDB"
-- The contract this file was written against. QuestieDB checks a range, so a newer additive release keeps working.
local CONTRACT = 2
-- A build is sliced across frames: reading every NPC with all seven fields in one frame stalls it. A few frames a
-- second for a couple of seconds is the smaller cost.
local SLICE_MS = 2
local REQUIRED = { "name", "minLevel", "maxLevel", "rank", "subName", "zoneID", "spawns" }
-- A build in progress, so a late ready callback or the wait fallback never starts a second one over it.
local building = false

local function IsJournalInstance(map)
	return map and (map.instanceType == 1 or map.instanceType == 2)
end

local function IsInstanceMap(map)
	return map and map.instanceType and map.instanceType > 0
end

local function State(nextState)
	status = nextState
	ns.catalogueStatus = nextState
end

function DB.State()
	return status
end

-- QuestieDB as this file reads it: on a contract this file understands and carrying the Forever rows. A version
-- outside the range, or another flavour, has a different shape, so its state is unsupported rather than read.
---@return boolean
local function Fit()
	local lib = LibQuestieDB
	if type(lib) ~= "table" or type(lib.RequireContract) ~= "function" then
		return false
	end
	local called, fits = pcall(lib.RequireContract, CONTRACT)
	if not (called and fits) then
		return false
	end
	local get = C_AddOns and C_AddOns.GetAddOnMetadata
	local read, flavour = pcall(get, ADDON, "X-Flavor")
	return read and flavour == "Forever"
end

---@param source any
---@return table?
local function ReadSupportTable(source)
	local chunk = type(source) == "string" and loadstring(source)
	if not chunk then
		return nil
	end
	setfenv(chunk, {})
	local ok, value = pcall(chunk)
	return ok and type(value) == "table" and value or nil
end

local cachedAreaSource, cachedOverrideSource, cachedArea, cachedOverride

-- QuestieDB's own ZoneDB tables from AreaTable ID to uiMapID: the base table and its overrides. nil when the lib,
-- contract 2 or ZoneDB is missing. The override table is optional, so a ZoneDB without one returns an empty table.
---@return table<integer, integer>? area
---@return table<integer, integer>? override
function DB.AreaMaps()
	local lib = rawget(_G, "LibQuestieDB")
	if
		type(lib) ~= "table"
		or type(lib.RequireContract) ~= "function"
		or type(lib.Support) ~= "table"
		or type(lib.Support.Get) ~= "function"
	then
		return nil
	end
	local ok, contract = pcall(lib.RequireContract, CONTRACT)
	if not ok or not contract then
		return nil
	end
	local got, zoneDb = pcall(lib.Support.Get, "ZoneDB")
	local private = got and type(zoneDb) == "table" and zoneDb.private
	local areaSource = private and private.areaIdToUiMapId
	local overrideSource = private and private.areaIdToUiMapIdOverride
	if cachedArea and areaSource == cachedAreaSource and overrideSource == cachedOverrideSource then
		return cachedArea, cachedOverride
	end
	local area = ReadSupportTable(areaSource)
	-- The override table is optional: ZoneDB ships without one when no area needs remapping.
	local override = ReadSupportTable(overrideSource) or {}
	if not area then
		return nil
	end
	cachedAreaSource, cachedOverrideSource = areaSource, overrideSource
	cachedArea, cachedOverride = area, override
	return area, override
end

-- One NPC's required fields, in REQUIRED's order, and where each sits in Get's answer.
local NAME, MIN_LEVEL, MAX_LEVEL, RANK, ZONE_ID, SPAWNS = 1, 2, 3, 4, 6, 7
-- Catalogue order by NPC id, shared by every sort so none of them builds a comparator.
---@param a { id: integer }
---@param b { id: integer }
---@return boolean
local function ById(a, b)
	return a.id < b.id
end

-- The names the old synthetic ids are re-keyed to, when a save still holds one. A save from schema 2 or later needs
-- no name index, and building one would key a string for every NPC in the database only to drop it.
---@return table<string, true>?
local function LegacyNames()
	if not (ns.LegacyIds and ns.db) then
		return nil
	end
	for _, state in pairs(ns.db.chars or {}) do
		for oldId in pairs(state.species or {}) do
			if ns.LegacyIds[tonumber(oldId)] then
				local names = {}
				for _, name in pairs(ns.LegacyIds) do
					if type(name) == "string" then
						names[name:lower()] = true
					end
				end
				return names
			end
		end
	end
	return nil
end

-- The catalogue, as a coroutine body: `yield` runs between NPCs so no frame reads the whole database.
---@param yield fun()
---@return boolean
local function Build(yield)
	local lib = LibQuestieDB
	if
		type(lib) ~= "table"
		or type(lib.Npc) ~= "table"
		or type(lib.Npc.GetAllIds) ~= "function"
		or type(lib.Npc.GetAll) ~= "function"
	then
		return false
	end
	local sourceIds = lib.Npc.GetAllIds()
	local ids = {}
	for _, id in ipairs(type(sourceIds) == "table" and sourceIds or {}) do
		if tonumber(id) then
			ids[#ids + 1] = tonumber(id)
		end
	end
	local zonesById, zones, zoneIds = {}, {}, {}
	for id in pairs(ns.ClientData.zones) do
		local areaId = tonumber(id)
		local area = ns.ClientData.zones[areaId]
		local parentMap = area and ns.ClientData.maps[tonumber(area.continent)]
		-- QuestieDB spawn keys are AreaTable IDs. Instance areas point to their map in ContinentID;
		-- for example, AreaTable 209 is Shadowfang Keep on Map 33.
		if not IsInstanceMap(parentMap) then
			zoneIds[#zoneIds + 1] = areaId
		end
	end
	table.sort(zoneIds)
	for _, id in ipairs(zoneIds) do
		local entry = ns.ClientData.zones[id]
		local map = ns.ClientData.maps[entry.continent]
		local zone = {
			id = id,
			name = entry.name,
			continent = ns.ClientData.continents[entry.continent] or (map and map.name) or ns.L["Unknown location"],
			species = {},
		}
		zonesById[id] = zone
		zones[#zones + 1] = zone
	end
	local legacyNames = LegacyNames()
	local speciesById, speciesByName, instanceSpecies = {}, {}, {}
	-- One scratch list of the areas an NPC is placed in, reused for every NPC: the species keeps only its placement,
	-- so this list is never retained and never needs to be a fresh table.
	local spawnZones = {}
	table.sort(ids)
	for _, id in ipairs(ids) do
		local values = lib.Npc.GetAll(id, REQUIRED)
		local name = type(values) == "table" and values[NAME] or nil
		if type(name) == "string" and name ~= "" then
			---@cast values table the reader answered with a table, since a name came out of it
			local zoneId = tonumber(values[ZONE_ID])
			local spawns = values[SPAWNS]
			wipe(spawnZones)
			if type(spawns) == "table" then
				for spawnZone in pairs(spawns) do
					spawnZone = tonumber(spawnZone)
					if spawnZone then
						spawnZones[#spawnZones + 1] = spawnZone
					end
				end
			end
			if zoneId then
				spawnZones[#spawnZones + 1] = zoneId
			end
			-- Sort, then keep the first of each run in place: a set of one area per spawn point would be a second
			-- table for every NPC in the database.
			table.sort(spawnZones)
			local kept = 0
			for index = 1, #spawnZones do
				local spawnZone = spawnZones[index]
				if kept == 0 or spawnZones[kept] ~= spawnZone then
					kept = kept + 1
					spawnZones[kept] = spawnZone
				end
			end
			local creatureTypeID, familyID = ns.CreatureInfo.Get(tonumber(id))
			local creatureType = creatureTypeID and ns.CreatureInfo.types[creatureTypeID]
			local rank = tonumber(values[RANK]) or 0
			local minLevel = tonumber(values[MIN_LEVEL]) or 1
			local species = {
				id = tonumber(id),
				name = name,
				minLevel = minLevel,
				maxLevel = tonumber(values[MAX_LEVEL]) or minLevel,
				family = creatureType and creatureType ~= "Unknown" and creatureType or "Unknown",
				familyID = familyID,
				creatureTypeID = creatureTypeID,
				rank = rank,
				rare = rank == 2,
				boss = rank == 3,
				zoneID = zoneId,
				-- Spawn points are read again when a habitat map or the public API asks for them: keeping every
				-- point here retained the whole spawn database, about 10 MB, and its collections were the idle frame.
			}
			speciesById[species.id] = species
			if legacyNames then
				local nameKey = name:lower()
				if legacyNames[nameKey] and not speciesByName[nameKey] then
					speciesByName[nameKey] = species.id
				end
			end
			local placed = false
			for index = 1, kept do
				local z = spawnZones[index]
				local area = ns.ClientData.zones[z]
				local mapId = area and tonumber(area.continent)
				local map = mapId and ns.ClientData.maps[mapId]
				if mapId and map and IsJournalInstance(map) then
					local group = instanceSpecies[mapId]
					if not group then
						group = {
							id = mapId,
							name = map.name,
							instanceType = map.instanceType,
							species = {},
							speciesById = {},
						}
						instanceSpecies[mapId] = group
					end
					group.speciesById[species.id] = species
					placed = true
				elseif zonesById[z] then
					species.zone = zonesById[z].name
					zonesById[z].species[#zonesById[z].species + 1] = species
					placed = true
				end
			end
			if not placed and zoneId and zonesById[zoneId] then
				species.zone = zonesById[zoneId].name
				zonesById[zoneId].species[#zonesById[zoneId].species + 1] = species
			end
		end
		yield()
	end
	for index = #zones, 1, -1 do
		local zone = zones[index]
		if #zone.species == 0 then
			table.remove(zones, index)
		else
			table.sort(zone.species, ById)
		end
	end
	local instances = {}
	for _, group in pairs(instanceSpecies) do
		for _, species in pairs(group.speciesById) do
			group.species[#group.species + 1] = species
		end
		group.speciesById = nil
		table.sort(group.species, ById)
		instances[#instances + 1] = group
	end
	table.sort(instances, ById)
	ns.Zones, ns.Instances, ns.SpeciesById = zones, instances, speciesById
	ns.BuildCatalogue()
	if legacyNames and ns.db then
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

-- The spawn points grouped by area, read from QuestieDB the first time a habitat map or the public API needs them and
-- kept on the species for the next ask. The catalogue itself carries only placement, names and levels.
---@param species FGSpecies?
---@return table<integer, number[][]>?
function DB.Spawns(species)
	if type(species) ~= "table" or type(species.id) ~= "number" then
		return nil
	end
	if species.spawns == nil then
		local lib = LibQuestieDB
		if type(lib) ~= "table" or type(lib.Npc) ~= "table" then
			return nil
		end
		local spawns
		if type(lib.Npc.Get) == "function" then
			spawns = lib.Npc.Get(species.id, "spawns")
		elseif type(lib.Npc.GetAll) == "function" then
			local values = lib.Npc.GetAll(species.id, { "spawns" })
			spawns = type(values) == "table" and values[1] or nil
		else
			return nil
		end
		species.spawns = type(spawns) == "table" and spawns or {}
	end
	return species.spawns
end

function DB.Start(onReady)
	local started
	-- Runs between NPCs: a slice lasts SLICE_MS, then the next frame resumes the build.
	local function Yield()
		if debugprofilestop() - started >= SLICE_MS then
			coroutine.yield()
		end
	end
	local function settle()
		-- One build per session: a second ready callback, or the wait fallback arriving after a build, must not read
		-- the database again and replace the catalogue it already produced.
		if building or status == "ok" then
			return
		end
		building = true
		State("loading")
		local thread = coroutine.create(function()
			return Build(Yield)
		end)
		local function step()
			started = debugprofilestop()
			local ok, built = coroutine.resume(thread)
			if ok and coroutine.status(thread) ~= "dead" then
				C_Timer.After(0, step)
				return
			end
			building = false
			if ok and built then
				State("ok")
				onReady()
			else
				State("unsupported")
			end
		end
		step()
	end
	if type(LibQuestieDB) ~= "table" then
		State("missing")
		return
	end
	if not Fit() then
		State("unsupported")
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
