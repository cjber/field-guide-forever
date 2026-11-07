---@type string, FGNamespace
local _, ns = ...

-- Public addon-to-addon interface. nil means the answer is not known yet: before the saved variables load there is
-- no catalogue state to read, and a caller such as a map addon should ask again after PLAYER_LOGIN rather than
-- treating the silence as an empty field guide. Version 2 is the tier ladder: the old rare form and per-kill shiny
-- roll are gone, so callers reading per-creature progress now get counts for bronze, silver, gold and shiny spawns.
---@class FGPublicAPI
local API = { version = 2, minor = 4 }
---@type FGSpawnCache?
local spawnCache
local FIRST_METRICS = {
	first_sighting = true,
	first_kill = true,
	first_bronze = true,
	first_silver = true,
	first_gold = true,
	first_shiny = true,
	boss_first_sighting = true,
	boss_first_kill = true,
}

---@return boolean
local function Ready()
	return ns.ready == true
end

-- QuestieDB stores AreaTable IDs and 0–100 coordinates. Resolve them only through its own ZoneDB tables; an
-- unknown mapping is omitted instead of drawing the creature on a guessed map.
---@return FGSpawnCache?
local function BuildSpawnCache()
	local area, override = ns.QuestieDB.AreaMaps()
	if not area or not override then
		return nil
	end
	local bySpecies, byZone = {}, {}
	for speciesId, species in pairs(ns.SpeciesById or {}) do
		local rows = {}
		local progress = ns.Model.Specimen(ns.GetCharacterState(false), speciesId)
		for areaId, points in pairs(species.spawns or {}) do
			local numericAreaId = tonumber(areaId)
			local map = override[numericAreaId] or area[numericAreaId]
			if type(map) == "number" and type(points) == "table" then
				for _, point in pairs(points) do
					local x = type(point) == "table" and point[1]
					local y = type(point) == "table" and point[2]
					if type(x) == "number" and type(y) == "number" then
						x, y = x / 100, y / 100
						if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
							local row = {
								speciesID = speciesId,
								name = species.name,
								rare = species.rare == true,
								catalogued = progress.count > 0,
								minLevel = species.minLevel,
								maxLevel = species.maxLevel,
								map = map,
								x = x,
								y = y,
							}
							rows[#rows + 1] = row
							if numericAreaId then
								byZone[numericAreaId] = byZone[numericAreaId] or {}
								byZone[numericAreaId][#byZone[numericAreaId] + 1] = row
							end
						end
					end
				end
			end
		end
		bySpecies[speciesId] = rows
	end
	return { species = bySpecies, zones = byZone }
end

---@param rows FGSpawn[]
---@return FGSpawn[]
local function CopySpawns(rows)
	local copy = {}
	local progressBySpecies = {}
	for i, row in ipairs(rows) do
		local progress = progressBySpecies[row.speciesID]
		if not progress then
			progress = ns.Model.Specimen(ns.GetCharacterState(false), row.speciesID)
			progressBySpecies[row.speciesID] = progress
		end
		copy[i] = {
			speciesID = row.speciesID,
			name = row.name,
			rare = row.rare,
			catalogued = progress.count > 0,
			minLevel = row.minLevel,
			maxLevel = row.maxLevel,
			map = row.map,
			x = row.x,
			y = row.y,
		}
	end
	return copy
end

local function SpawnsReady()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return false
	end
	if not spawnCache then
		spawnCache = BuildSpawnCache()
	end
	return spawnCache ~= nil
end

---@param speciesId integer
---@return FGSpawn[]?
function API.Spawns(speciesId)
	if not SpawnsReady() or not spawnCache or type(speciesId) ~= "number" or speciesId % 1 ~= 0 then
		return nil
	end
	local species = ns.SpeciesById[speciesId]
	if not species then
		return nil
	end
	return CopySpawns(spawnCache.species[speciesId] or {})
end

---@param zoneName? string
---@return FGSpawn[]?
function API.ZoneSpawns(zoneName)
	if not SpawnsReady() or not spawnCache then
		return nil
	end
	local zone
	if zoneName ~= nil then
		zone = ns.FindZone(zoneName)
	else
		zone = ns.CurrentZone()
	end
	if not zone then
		return nil
	end
	local rows = {}
	for _, row in ipairs(spawnCache.zones[zone.id] or {}) do
		rows[#rows + 1] = row
	end
	return CopySpawns(rows)
end

---@return boolean
function API.Ready()
	return Ready()
end

API.IsReady = API.Ready

---@param species FGSpecies
---@return FGSpecies
local function CopySpecies(species)
	return {
		id = species.id,
		name = species.name,
		family = species.family,
		minLevel = species.minLevel,
		maxLevel = species.maxLevel,
		zone = species.zone,
		rare = species.rare == true,
		lore = species.lore,
	}
end

---@return { name: string, continent: string }[]?
function API.Zones()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return nil
	end
	local zones = {}
	for _, zone in ipairs(ns.Zones) do
		zones[#zones + 1] = { name = zone.name, continent = zone.continent }
	end
	return zones
end

---@param zoneName? string
---@return FGSpecies[]?
function API.Species(zoneName)
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return nil
	end
	local zone
	if zoneName ~= nil then
		zone = ns.FindZone(zoneName)
	else
		zone = ns.CurrentZone()
	end
	if not zone then
		return nil
	end
	local species = {}
	for _, entry in ipairs(zone.species) do
		species[#species + 1] = CopySpecies(entry)
	end
	return species
end

API.GetSpecies = API.Species

---@param speciesId integer
---@return FGSpecies?
function API.SpeciesById(speciesId)
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return nil
	end
	local species = ns.SpeciesById[speciesId]
	return species and CopySpecies(species)
end

API.GetSpeciesById = API.SpeciesById
API.Creature = API.SpeciesById
API.GetCreature = API.SpeciesById

---@param zoneName? string
---@return { zone: string, catalogued: integer, total: integer, fraction: number }?
function API.Progress(zoneName)
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return nil
	end
	local zone
	if zoneName ~= nil then
		zone = ns.FindZone(zoneName)
	else
		zone = ns.CurrentZone()
	end
	if not zone then
		return nil
	end
	local progress = ns.Model.ZoneProgress(ns.GetCharacterState(false), zone.species)
	return {
		zone = zone.name,
		catalogued = progress.catalogued,
		total = progress.total,
		fraction = progress.fraction,
	}
end

API.GetProgress = API.Progress
API.ZoneProgress = API.Progress
API.GetZoneProgress = API.Progress

---@param speciesId integer
---@return { id: integer, name: string, count: integer, kills: integer, killsEstimated: boolean,
--- rank: integer, bestTier: string?, bronze: boolean, silver: boolean, gold: boolean, shiny: boolean,
--- bronzeCount: integer, silverCount: integer, goldCount: integer, shinyCount: integer,
--- firstSighting: number?, firstSightingZone: string?, firstKill: number?, firstKillZone: string?,
--- firstBronze: number?, firstBronzeZone: string?, firstSilver: number?, firstSilverZone: string?,
--- firstGold: number?, firstGoldZone: string?, firstShiny: number?, firstShinyZone: string? }?
function API.Specimen(speciesId)
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return nil
	end
	local species = ns.SpeciesById[speciesId]
	if not species then
		return nil
	end
	local state = ns.GetCharacterState(false)
	local entry = ns.Model.Specimen(state, speciesId)
	return {
		id = species.id,
		name = species.name,
		count = entry.count,
		kills = entry.kills,
		killsEstimated = entry.killsEstimated,
		bestTier = ns.Model.BestTier(entry),
		firstSighting = entry.firstSighting,
		firstSightingZone = entry.firstSightingZone,
		firstKill = entry.firstKill,
		firstKillZone = entry.firstKillZone,
		firstBronze = entry.firstBronze,
		firstBronzeZone = entry.firstBronzeZone,
		firstSilver = entry.firstSilver,
		firstSilverZone = entry.firstSilverZone,
		firstGold = entry.firstGold,
		firstGoldZone = entry.firstGoldZone,
		firstShiny = entry.firstShiny,
		firstShinyZone = entry.firstShinyZone,
		rank = ns.Model.Rank(entry.count),
		bronze = entry.bronze > 0,
		silver = entry.silver > 0,
		gold = entry.gold > 0,
		shiny = entry.shiny > 0,
		bronzeCount = entry.bronze,
		silverCount = entry.silver,
		goldCount = entry.gold,
		shinyCount = entry.shiny,
	}
end

API.GetSpecimen = API.Specimen
API.SpeciesState = API.Specimen

---@return FGSighting[]?
function API.Sightings()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return nil
	end
	local sightings = {}
	for index, entry in ipairs(ns.Model.GetSightings()) do
		sightings[index] = {
			time = entry.time,
			zone = entry.zone,
			species = entry.species,
			kind = entry.kind,
		}
	end
	return sightings
end

API.GetSightings = API.Sightings

-- Every species with its current specimen row, for a caller drawing its own summary. A fresh table on each call keeps
-- the saved state out of reach.
---@return { id: integer, name: string, zone: string, count: integer, kills: integer, rank: integer,
--- bestTier: string?, silver: boolean, gold: boolean, shiny: boolean }[]?
function API.Specimens()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return nil
	end
	local specimens = {}
	for _, zone in ipairs(ns.Zones) do
		for _, species in ipairs(zone.species) do
			local entry = ns.Model.Specimen(ns.GetCharacterState(false), species.id)
			specimens[#specimens + 1] = {
				id = species.id,
				name = species.name,
				zone = zone.name,
				count = entry.count,
				kills = entry.kills,
				killsEstimated = entry.killsEstimated,
				rank = ns.Model.Rank(entry.count),
				bestTier = ns.Model.BestTier(entry),
				silver = entry.silver > 0,
				gold = entry.gold > 0,
				shiny = entry.shiny > 0,
			}
		end
	end
	return specimens
end

API.GetSpecimens = API.Specimens

-- Encounter names and IDs arrive from successful client encounter events. These are local recorded encounters, not
-- a complete dungeon catalogue or externally verified firsts.
---@return { id: integer, name: string, instance: string, kills: integer, sightings: integer,
--- firstSighting: number?, firstSightingDifficulty: integer?, firstSightingDifficultyName: string?,
--- firstKill: number?, firstDifficulty: integer?,
--- firstDifficultyName: string?, difficulties: table<string, integer>, difficultyNames: table<string, string> }[]?
function API.Encounters()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return nil
	end
	local state = ns.GetCharacterState(false)
	local encounters = {}
	for _, encounter in pairs(state and state.encounters or {}) do
		local copy = {
			id = encounter.id,
			name = encounter.name,
			instance = encounter.instance,
			kills = encounter.kills or 0,
			sightings = encounter.sightings or 0,
			firstSighting = encounter.firstSighting,
			firstSightingDifficulty = encounter.firstSightingDifficulty,
			firstSightingDifficultyName = encounter.firstSightingDifficultyName,
			firstKill = encounter.firstKill,
			firstDifficulty = encounter.firstDifficulty,
			firstDifficultyName = encounter.firstDifficultyName,
			difficulties = {},
			difficultyNames = {},
		}
		for difficulty, count in pairs(encounter.difficulties or {}) do
			copy.difficulties[difficulty] = count
		end
		for difficulty, name in pairs(encounter.difficultyNames or {}) do
			copy.difficultyNames[difficulty] = name
		end
		encounters[#encounters + 1] = copy
	end
	table.sort(encounters, function(a, b)
		return (a.name or "") < (b.name or "")
	end)
	return encounters
end

API.GetEncounters = API.Encounters

---@param metric string
---@param subject string
---@return { player: string, value: integer, time: integer, source: string }[]?
function API.Leaderboard(metric, subject)
	if not Ready() or not ns.db or type(metric) ~= "string" or type(subject) ~= "string" then
		return nil
	end
	local rows = {}
	local state = ns.GetCharacterState(false)
	local localRecord
	local creatureMetric = metric == "creature_kills"
		or metric == "bronze_finds"
		or metric == "silver_finds"
		or metric == "gold_finds"
		or metric == "shiny_finds"
		or metric:match("^first_")
	if creatureMetric then
		local entry = ns.Model.Specimen(state, tonumber(subject) or 0)
		local fields = {
			creature_kills = { value = ns.Model.ObservedKills(entry), time = entry.lastKill },
			bronze_finds = { value = entry.bronze, time = entry.firstBronze },
			silver_finds = { value = entry.silver, time = entry.firstSilver },
			gold_finds = { value = entry.gold, time = entry.firstGold },
			shiny_finds = { value = entry.shiny, time = entry.firstShiny },
			first_sighting = { value = 1, time = entry.firstSighting },
			first_kill = { value = 1, time = entry.firstKill },
			first_bronze = { value = 1, time = entry.firstBronze },
			first_silver = { value = 1, time = entry.firstSilver },
			first_gold = { value = 1, time = entry.firstGold },
			first_shiny = { value = 1, time = entry.firstShiny },
		}
		localRecord = fields[metric]
		if metric == "creature_kills" and subject == "all" then
			local total, stamp = 0, 0
			for _, specimen in pairs(state and state.species or {}) do
				total = total + ns.Model.ObservedKills(specimen)
				stamp = math.max(stamp, specimen.lastKill or 0)
			end
			localRecord = { value = total, time = stamp }
		end
	elseif metric:match("^boss_") then
		local encounterId, difficulty = subject:match("^(%d+)_(%d+)$")
		local encounter = state and state.encounters and state.encounters[encounterId or subject]
		if encounter then
			if metric == "boss_kills" then
				localRecord = {
					value = encounter.difficulties and encounter.difficulties[difficulty or "0"] or 0,
					time = encounter.firstKill,
				}
			elseif metric == "boss_sightings" then
				localRecord = { value = encounter.sightings or 0, time = encounter.firstSighting }
			elseif metric == "boss_first_kill" then
				localRecord = { value = 1, time = encounter.firstKill }
			elseif metric == "boss_first_sighting" then
				localRecord = { value = 1, time = encounter.firstSighting }
			end
		end
	end
	local playerName = string.format(
		"%s-%s",
		UnitName and UnitName("player") or "Unknown",
		GetRealmName and GetRealmName() or "Unknown"
	)
	if localRecord then
		rows[#rows + 1] = {
			player = playerName,
			value = FIRST_METRICS[metric] and not localRecord.time and 0 or localRecord.value,
			time = localRecord.time or 0,
			source = "local",
		}
	end
	local peers = ns.db.options.statsShare ~= false and ns.Stats and ns.Stats.Shared() or {}
	for peerName, peer in pairs(peers) do
		local data = peer.fieldguide and peer.fieldguide[subject] and peer.fieldguide[subject][metric]
		if data then
			rows[#rows + 1] = { player = peerName, value = data.value, time = data.time, source = "peer" }
		end
	end
	table.sort(rows, function(a, b)
		if FIRST_METRICS[metric] and (a.time == 0) ~= (b.time == 0) then
			return b.time == 0
		end
		if FIRST_METRICS and FIRST_METRICS[metric] and a.time ~= b.time then
			return a.time < b.time
		end
		if a.value == b.value then
			return a.player < b.player
		end
		return a.value > b.value
	end)
	return rows
end

-- A compact kill leaderboard for other addons. Peer values are reports received from addon users and are not
-- independently verified; local records remain visible when sharing is disabled.
---@return { player: string, value: integer, source: string }[]?
function API.LeaderboardSummary()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return nil
	end
	local totals = {}
	local localTotal = 0
	local state = ns.GetCharacterState(false)
	for _, entry in pairs(state and state.species or {}) do
		localTotal = localTotal + ns.Model.ObservedKills(entry)
	end
	local localPlayer = string.format(
		"%s-%s",
		UnitName and UnitName("player") or "Unknown",
		GetRealmName and GetRealmName() or "Unknown"
	)
	totals[localPlayer] = { player = localPlayer, value = localTotal, source = "local" }
	if ns.db and ns.db.options.statsShare ~= false then
		for player, peer in pairs(ns.Stats and ns.Stats.Shared() or {}) do
			local species = peer.fieldguide
			if type(species) == "table" then
				local total = 0
				local aggregate = species.all and species.all.creature_kills
				for subject, metrics in pairs(species) do
					local kills = type(metrics) == "table" and metrics.creature_kills
					if subject ~= "all" and type(kills) == "table" then
						total = total + (tonumber(kills.value) or 0)
					end
				end
				if aggregate then
					total = aggregate.value
				end
				if total > 0 and player ~= localPlayer then
					totals[player] = { player = player, value = total, source = "reported" }
				end
			end
		end
	end
	local rows = {}
	for _, row in pairs(totals) do
		rows[#rows + 1] = row
	end
	table.sort(rows, function(a, b)
		if a.value == b.value then
			return a.player < b.player
		end
		return a.value > b.value
	end)
	return rows
end

API.GetLeaderboardSummary = API.LeaderboardSummary

---@return table<string, table>?
function API.SharedStats()
	if not Ready() or not ns.db or ns.db.options.statsShare == false then
		return nil
	end
	local result = {}
	for player, addons in pairs(ns.Stats and ns.Stats.Shared() or {}) do
		result[player] = {}
		for addon, subjects in pairs(addons) do
			result[player][addon] = {}
			for subject, metrics in pairs(subjects) do
				result[player][addon][subject] = {}
				for metric, record in pairs(metrics) do
					result[player][addon][subject][metric] = { value = record.value, time = record.time }
				end
			end
		end
	end
	return result
end

API.GetSharedStats = API.SharedStats

FieldGuideForever = FieldGuideForever or {}
FieldGuideForever.API = API
ns.API = API
