---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

-- Public addon-to-addon interface (docs/api.md). Version 2 is the tier ladder: the old rare form and per-kill shiny
-- roll are gone, so callers reading per-creature progress now get counts for bronze, silver, gold and shiny spawns.
-- `minor` rises with each addition (1: Spawns and ZoneSpawns, 2: version 2's tier ladder, 3: the size fields, 4:
-- their removal, 5: each read's not-ready answer, 6: SpawnTier, TrackedSpecies, SetTrackedSpecies, Subscribe and
-- Stats, 7: version 3, the Forever Leaderboards reads are gone); a caller checks a member before using it.
local API = { version = 3, minor = 7 }

-- The shared shape every Forever addon's API follows: the not-ready answer a read gives while there is nothing to
-- answer (ForeverCore's docs/api-conventions.md). Core/Require.lua stops the addon before this file on an older
-- ForeverCore, so the kit is always here.
local APIKit = assert(ForeverCore.APIKit)

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

-- This character's own totals in the suite's activity-row shape: one row per metric the addon counts, with the
-- subject "all" because the row is a total rather than one species or encounter. It is a local read; eventUnix is
-- present only when a real timestamp exists.
---@return { addon: string, metric: string, subject: string, value: number, eventUnix?: number }[]?
---@return FGAPIReason?
function API.Stats()
	if not Ready() or not ns.db then
		return NotReady("loading")
	end
	return ns.Stats.Activity()
end

FieldGuideForever = FieldGuideForever or {}
FieldGuideForever.API = API --[[@as FGPublicAPI]]
if (ForeverCore.APIKit.minor or 1) >= 2 then
	ForeverCore.APIKit.Publish("FieldGuideForever", API)
end
ns.API = API --[[@as FGPublicAPI]]
