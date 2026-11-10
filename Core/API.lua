---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

-- Public addon-to-addon interface (docs/api.md). Version 2 is the tier ladder: the old rare form and per-kill shiny
-- roll are gone, so callers reading per-creature progress now get counts for bronze, silver, gold and shiny spawns.
-- `minor` rises with each addition (1: Spawns and ZoneSpawns, 2: version 2's tier ladder, 3: the size fields, 4:
-- their removal, 5: SuiteLeaderboard and each read's not-ready answer, 6: SpawnTier, TrackedSpecies, SetTrackedSpecies,
-- Subscribe and Stats); a caller checks a member before using it.
local API = { version = 2, minor = 6 }

-- The shared shape every Forever addon's API follows: the not-ready answer a read gives while there is nothing to
-- answer (ForeverCore's docs/api-conventions.md). Core/Require.lua stops the addon before this file on an older
-- ForeverCore, so the kit is always here.
local APIKit = assert(ForeverCore.APIKit)

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

-- A read with nothing to answer, as the kit builds it: `nil, reason`. docs/api.md lists which reasons each read can
-- return, so a caller can tell "ask again later" from "there is nothing to ask about".
---@param reason FGAPIReason
---@return nil, FGAPIReason
local function NotReady(reason)
	local _, answer = APIKit.NotReady(reason)
	return nil, answer --[[@as FGAPIReason]]
end

-- Subscribe's change counters (ForeverCore's docs/api-conventions.md). Each one is bumped where the event is first
-- produced, in Core's record paths and the tracker's saved switch, never in the toast UI, so it counts whether or not
-- a player has toasts on. A counter is the channel's comparable key: zero reads as false, so a value only changes
-- when the event happens.
local changes = { sighting = 0, tier = 0, zone = 0, specimen = 0, tracked = 0 }

---@param name "sighting"|"tier"|"zone"|"specimen"|"tracked"
---@return fun(): integer|false
local function Counter(name)
	return function()
		return changes[name] ~= 0 and changes[name] or false
	end
end

local hub = APIKit.Hub("FieldGuideForever", {
	sighting = Counter("sighting"),
	tier = Counter("tier"),
	zone = Counter("zone"),
	specimen = Counter("specimen"),
	tracked = Counter("tracked"),
}, function()
	return ns.GetCharacterState(false) ~= nil
end)

-- Internal: Core and UI/Tracker bump a channel here. The counters are not part of the published API.
---@param name "sighting"|"tier"|"zone"|"specimen"|"tracked"
function ns.NotifyAPIChange(name)
	if changes[name] then
		changes[name] = changes[name] + 1
		hub.Queue()
	end
end

API.Subscribe = hub.Subscribe

-- QuestieDB stores AreaTable IDs and 0–100 coordinates. Resolve them only through its own ZoneDB tables; an
-- unknown mapping is omitted instead of drawing the creature on a guessed map. The spawn points themselves stay in
-- QuestieDB until a caller asks: the catalogue keeps no copy, so a query reads only the species it names.
---@param species FGSpecies
---@param speciesId integer
---@param area table<integer, integer>
---@param override table<integer, integer>
---@param wantedArea integer? only the rows of this AreaTable ID
---@return FGSpawn[]
local function SpawnRows(species, speciesId, area, override, wantedArea)
	local rows = {}
	local progress = ns.Model.Specimen(ns.GetCharacterState(false), speciesId)
	for areaId, points in pairs(ns.QuestieDB.Spawns(species) or {}) do
		local numericAreaId = tonumber(areaId)
		if numericAreaId and (wantedArea == nil or numericAreaId == wantedArea) and type(points) == "table" then
			local map = override[numericAreaId] or area[numericAreaId]
			if type(map) == "number" then
				for _, point in pairs(points) do
					local x = type(point) == "table" and point[1]
					local y = type(point) == "table" and point[2]
					if type(x) == "number" and type(y) == "number" then
						x, y = x / 100, y / 100
						if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
							rows[#rows + 1] = {
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
						end
					end
				end
			end
		end
	end
	return rows
end

---@return table<integer, integer>? area
---@return table<integer, integer>? override
local function SpawnMaps()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return nil
	end
	local area, override = ns.QuestieDB.AreaMaps()
	if not area or not override then
		return nil
	end
	return area, override
end

---@param speciesId integer
---@return FGSpawn[]?
---@return FGAPIReason?
function API.Spawns(speciesId)
	local area, override = SpawnMaps()
	if not area or not override then
		return NotReady("loading")
	end
	if type(speciesId) ~= "number" or speciesId % 1 ~= 0 then
		return NotReady("none")
	end
	local species = ns.SpeciesById[speciesId]
	if not species then
		return NotReady("none")
	end
	return SpawnRows(species, speciesId, area, override)
end

---@param zoneName? string
---@return FGSpawn[]?
---@return FGAPIReason?
function API.ZoneSpawns(zoneName)
	local area, override = SpawnMaps()
	if not area or not override then
		return NotReady("loading")
	end
	local zone
	if zoneName ~= nil then
		zone = ns.FindZone(zoneName)
	else
		zone = ns.CurrentZone()
	end
	if not zone then
		return NotReady("none")
	end
	local rows = {}
	for _, species in ipairs(zone.species) do
		local speciesRows = SpawnRows(species, species.id, area, override, zone.id)
		for _, row in ipairs(speciesRows) do
			rows[#rows + 1] = row
		end
	end
	return rows
end

---@return boolean
function API.Ready()
	return Ready()
end

API.IsReady = API.Ready

-- The spawn's coat as the nameplate and target frame draw it, for a unit token such as "target", "nameplate3" or
-- "mouseover". A unit that does not exist, a player and a unit the player cannot attack have no spawn tier, so they
-- answer nil, "none"; this is deliberately not the bronze the art falls back to. Preview tiers are session-only UI
-- state and never leave UI/Rarity.lua.
---@param unit string
---@return string?
---@return FGAPIReason?
function API.SpawnTier(unit)
	if type(unit) ~= "string" then
		return NotReady("none")
	end
	local tier = ns.UnitTier(unit)
	if not tier then
		return NotReady("none")
	end
	return tier
end

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
---@return FGAPIReason?
function API.Zones()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return NotReady("loading")
	end
	local zones = {}
	for _, zone in ipairs(ns.Zones) do
		zones[#zones + 1] = { name = zone.name, continent = zone.continent }
	end
	return zones
end

---@param zoneName? string
---@return FGSpecies[]?
---@return FGAPIReason?
function API.Species(zoneName)
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return NotReady("loading")
	end
	local zone
	if zoneName ~= nil then
		zone = ns.FindZone(zoneName)
	else
		zone = ns.CurrentZone()
	end
	if not zone then
		return NotReady("none")
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
---@return FGAPIReason?
function API.SpeciesById(speciesId)
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return NotReady("loading")
	end
	local species = ns.SpeciesById[speciesId]
	if not species then
		return NotReady("none")
	end
	return CopySpecies(species)
end

API.GetSpeciesById = API.SpeciesById
API.Creature = API.SpeciesById
API.GetCreature = API.SpeciesById

---@param zoneName? string
---@return { zone: string, catalogued: integer, total: integer, fraction: number }?
---@return FGAPIReason?
function API.Progress(zoneName)
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return NotReady("loading")
	end
	local zone
	if zoneName ~= nil then
		zone = ns.FindZone(zoneName)
	else
		zone = ns.CurrentZone()
	end
	if not zone then
		return NotReady("none")
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
---@return FGAPIReason?
function API.Specimen(speciesId)
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return NotReady("loading")
	end
	local species = ns.SpeciesById[speciesId]
	if not species then
		return NotReady("none")
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

-- The species the shared tracker column follows, as the saved switch that survives a reload. nil with "loading"
-- before this character's state exists, and nil with "none" while nothing is tracked.
---@return integer?
---@return FGAPIReason?
function API.TrackedSpecies()
	local state = ns.GetCharacterState(false)
	if not state then
		return NotReady("loading")
	end
	local speciesId = ns.Tracker.TrackedSpecies()
	if not speciesId then
		return NotReady("none")
	end
	return speciesId
end

-- Set the tracked species, or clear it with nil. It writes the same saved switch as the journal's button, with no
-- sound and no chat line, and refreshes the section. False for an id the catalogue does not hold and for a call that
-- changes nothing.
---@param speciesId integer?
---@return boolean
function API.SetTrackedSpecies(speciesId)
	if not Ready() then
		return false
	end
	if speciesId ~= nil then
		if type(speciesId) ~= "number" or speciesId % 1 ~= 0 or not ns.SpeciesById[speciesId] then
			return false
		end
	end
	return ns.Tracker.SetTracked(speciesId)
end

---@return FGSighting[]?
---@return FGAPIReason?
function API.Sightings()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return NotReady("loading")
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
---@return FGAPIReason?
function API.Specimens()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return NotReady("loading")
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
---@return FGAPIReason?
function API.Encounters()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return NotReady("loading")
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
---@return FGAPIReason?
function API.Leaderboard(metric, subject)
	if not Ready() or not ns.db then
		return NotReady("loading")
	end
	if type(metric) ~= "string" or type(subject) ~= "string" then
		return NotReady("none")
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

-- The suite leaderboard shape (docs/api-conventions.md): the same ranked kill rows as
-- Leaderboard("creature_kills", "all"), with the rank, name and personal mark the shared window uses. This
-- character's row is always included, even below the limit. Peer values are reports received from addon users and
-- are not independently verified; they are left out while sharing is off, and the local row remains.
---@param limit? integer how many top rows, ten unless given, 25 at most; this character's row is always included
---@return { metric: string, scope: string, sharing: boolean, total: integer,
--- rows: { rank: integer, name: string, value: integer, eventUnix: integer?, self: boolean }[] }?
---@return FGAPIReason?
function API.SuiteLeaderboard(limit)
	if limit == nil then
		limit = 10
	elseif type(limit) ~= "number" or limit < 0 or limit % 1 ~= 0 then
		return NotReady("none")
	end
	if limit > 25 then
		limit = 25
	end
	local board, reason = API.Leaderboard("creature_kills", "all")
	if not board then
		return nil, reason
	end
	local rows = {}
	local selfRow
	for index, row in ipairs(board) do
		local shaped = {
			rank = index,
			name = row.player,
			value = row.value,
			eventUnix = row.time and row.time > 0 and row.time or nil,
			self = row.source == "local",
		}
		if shaped.self then
			selfRow = shaped
		end
		if index <= limit then
			rows[#rows + 1] = shaped
		end
	end
	if selfRow and selfRow.rank > limit then
		rows[#rows + 1] = selfRow
	end
	return {
		metric = "creature_kills",
		scope = "guild_group",
		sharing = ns.db ~= nil and ns.db.options.statsShare ~= false,
		total = #board,
		rows = rows,
	}
end

-- A compact kill leaderboard for other addons. Peer values are reports received from addon users and are not
-- independently verified; local records remain visible when sharing is disabled.
---@return { player: string, value: integer, source: string }[]?
---@return FGAPIReason?
function API.LeaderboardSummary()
	if not Ready() or ns.catalogueStatus ~= "ok" then
		return NotReady("loading")
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

-- This character's own totals in the suite's activity-row shape: one row per metric SharedStats publishes, with the
-- subject "all" because the row is a total rather than one species or encounter. It is a local read, so sharing being
-- off changes nothing here; eventUnix is present only when a real timestamp exists.
---@return { addon: string, metric: string, subject: string, value: number, eventUnix?: number }[]?
---@return FGAPIReason?
function API.Stats()
	if not Ready() or not ns.db then
		return NotReady("loading")
	end
	return ns.Stats.Activity()
end

---@return table<string, table>?
---@return FGAPIReason?
function API.SharedStats()
	if not Ready() or not ns.db then
		return NotReady("loading")
	end
	if ns.db.options.statsShare == false then
		return NotReady("disabled")
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
FieldGuideForever.API = API --[[@as FGPublicAPI]]
ns.API = API --[[@as FGPublicAPI]]
