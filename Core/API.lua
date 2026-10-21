---@type string, BFNamespace
local _, ns = ...

-- Public addon-to-addon interface. nil means the answer is not known yet: before the saved variables load there is
-- no catalogue state to read, and a caller such as a map addon should ask again after PLAYER_LOGIN rather than
-- treating the silence as an empty bestiary. Version 1 is the first contract.
---@class BFPublicAPI
local API = { version = 1 }

---@return boolean
local function Ready()
	return ns.ready == true
end

---@return boolean
function API.Ready()
	return Ready()
end

API.IsReady = API.Ready

---@param species BFSpecies
---@return BFSpecies
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
	if not Ready() then
		return nil
	end
	local zones = {}
	for _, zone in ipairs(ns.Creatures.zones) do
		zones[#zones + 1] = { name = zone.name, continent = zone.continent }
	end
	return zones
end

---@param zoneName? string
---@return BFSpecies[]?
function API.Species(zoneName)
	if not Ready() then
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
---@return BFSpecies?
function API.SpeciesById(speciesId)
	if not Ready() then
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
	if not Ready() then
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
---@return { id: integer, name: string, count: integer, rank: integer, rare: boolean, shiny: boolean,
--- rareCount: integer, shinyCount: integer }?
function API.Specimen(speciesId)
	if not Ready() then
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
		rank = ns.Model.Rank(entry.count),
		rare = entry.rare >= ns.Model.RARE_TARGET,
		shiny = entry.shiny >= ns.Model.SHINY_TARGET,
		rareCount = entry.rare,
		shinyCount = entry.shiny,
	}
end

API.GetSpecimen = API.Specimen
API.SpeciesState = API.Specimen

---@return BFSighting[]?
function API.Sightings()
	if not Ready() then
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
---@return { id: integer, name: string, zone: string, count: integer, rank: integer, rare: boolean, shiny: boolean }[]?
function API.Specimens()
	if not Ready() then
		return nil
	end
	local specimens = {}
	for _, zone in ipairs(ns.Creatures.zones) do
		for _, species in ipairs(zone.species) do
			local entry = ns.Model.Specimen(ns.GetCharacterState(false), species.id)
			specimens[#specimens + 1] = {
				id = species.id,
				name = species.name,
				zone = zone.name,
				count = entry.count,
				rank = ns.Model.Rank(entry.count),
				rare = entry.rare >= ns.Model.RARE_TARGET,
				shiny = entry.shiny >= ns.Model.SHINY_TARGET,
			}
		end
	end
	return specimens
end

API.GetSpecimens = API.Specimens

BestiaryForever = BestiaryForever or {}
BestiaryForever.API = API
ns.API = API
