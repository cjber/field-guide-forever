---@type string, FGNamespace
local _, ns = ...

-- Pure catalogue state. Nothing here reads a frame, a saved variable or the client: Core owns the world, the UI
-- owns the pixels, and this file owns the arithmetic the specs can pin down.
---@class FGModel
local Model = {}
ns.Model = Model

Model.MASTERED_AT = 10
Model.RARE_TARGET = 3
Model.SHINY_TARGET = 1
Model.SHINY_CHANCE = 500
Model.SIGHTING_LIMIT = 50

---@param speciesId integer
---@return string
function Model.Tier(speciesId)
	local band = speciesId % 1000
	if band == 0 then
		return "shiny"
	elseif band % 100 == 0 then
		return "gold"
	elseif band % 25 == 0 then
		return "silver"
	end
	return "copper"
end

---@type table<integer, string>
Model.RANK_NAMES = {
	[0] = "Undiscovered",
	[1] = "Discovered",
	[2] = "Observed",
	[3] = "Studied",
	[4] = "Mastered",
}

-- Tests replace this with a fixed function. The default is math.random itself so a caller can reason about a
-- 1 in SHINY_CHANCE roll without a wrapper changing the distribution.
---@type fun(...: any): number
Model.random = math.random

---@param random? fun(...: any): number
function Model.SetRandom(random)
	Model.random = random or math.random
end

-- A fresh per-character state, flat enough that SavedVariables can serialise it without metatables.
---@return FGState
function Model.NewState(random)
	if random then
		Model.SetRandom(random)
	end
	return { species = {}, encounters = {} }
end

---@param count number?
---@return integer
function Model.Rank(count)
	count = tonumber(count) or 0
	if count >= Model.MASTERED_AT then
		return 4
	elseif count >= 6 then
		return 3
	elseif count >= 3 then
		return 2
	elseif count >= 1 then
		return 1
	end
	return 0
end

---@param minLevel integer
---@param maxLevel integer
---@return string
function Model.LevelRange(minLevel, maxLevel)
	if minLevel == maxLevel then
		return tostring(minLevel)
	end
	return string.format("%d–%d", minLevel, maxLevel)
end

---@param count number?
---@return string
function Model.RankName(count)
	return Model.RANK_NAMES[Model.Rank(count)] or Model.RANK_NAMES[0]
end

---@param state FGState?
---@param speciesId integer
---@return FGSpeciesState
local function Entry(state, speciesId)
	state.species = state.species or {}
	local entry = state.species[speciesId]
	if not entry then
		entry = {
			count = 0,
			kills = 0,
			killsEstimated = false,
			rare = 0,
			rareKills = 0,
			shiny = 0,
			shinyFinds = 0,
		}
		state.species[speciesId] = entry
	end
	entry.count = entry.count or 0
	if entry.kills == nil and entry.count > 0 and entry.killsEstimated == nil then
		entry.killsEstimated = true
	end
	entry.kills = entry.kills or entry.count or 0
	entry.rare = entry.rare or 0
	entry.rareKills = entry.rareKills or 0
	entry.shiny = entry.shiny or 0
	entry.shinyFinds = entry.shinyFinds or 0
	return entry
end

-- The default roll is an integer from 1 to SHINY_CHANCE, so 1 is the shiny. A spec supplies a function returning
-- a fraction in [0, 1), where 0 is the perfect roll; accepting both keeps the tests readable and the game's odds
-- exact.
---@param random fun(...: any): number
---@return boolean
local function RollShiny(random)
	if random == math.random then
		return random(Model.SHINY_CHANCE) == 1
	end
	return random() < 1 / Model.SHINY_CHANCE
end

-- Record one specimen. `opts.rare` marks a rare sighting (or inherit it from `opts.species.rare`), and the roll is
-- per kill, not per species, because a shiny is a property of the individual encountered.
---@param state FGState
---@param speciesId integer
---@param opts? { rare?: boolean, species?: FGSpecies, random?: fun(...: any): number }
---@return { count: integer, rank: integer, shiny: boolean, rare: boolean, newlyDiscovered: boolean,
--- rareKnown: boolean, shinyKnown: boolean }
function Model.Record(state, speciesId, opts)
	if type(opts) == "boolean" then
		opts = { rare = opts }
	end
	opts = opts or {}
	local entry = Entry(state, speciesId)
	local newlyDiscovered = entry.count == 0
	entry.count = math.min(entry.count + 1, Model.MASTERED_AT)
	entry.kills = entry.kills + 1
	local recordedAt = tonumber(opts.time) or 0
	entry.lastKill = recordedAt
	local zone = type(opts.zone) == "string" and opts.zone or ""
	if entry.firstKill == nil then
		entry.firstKill = recordedAt
		entry.firstKillZone = zone
	end
	if entry.firstSighting == nil then
		entry.firstSighting = recordedAt
		entry.firstSightingZone = zone
	end

	local isRare = opts.rare
	if isRare == nil and type(opts.species) == "table" then
		isRare = opts.species.rare == true
	end
	if isRare then
		entry.rare = math.min(entry.rare + 1, Model.RARE_TARGET)
		entry.rareKills = entry.rareKills + 1
		if entry.firstRare == nil then
			entry.firstRare = recordedAt
			entry.firstRareZone = zone
		end
	end

	local shiny = RollShiny(opts.random or Model.random)
	if shiny then
		entry.shiny = math.min(entry.shiny + 1, Model.SHINY_TARGET)
		entry.shinyFinds = entry.shinyFinds + 1
		if entry.firstShiny == nil then
			entry.firstShiny = recordedAt
			entry.firstShinyZone = zone
		end
	end

	return {
		count = entry.count,
		kills = entry.kills,
		rank = Model.Rank(entry.count),
		shiny = shiny,
		rare = isRare == true,
		newlyDiscovered = newlyDiscovered,
		firstKill = entry.kills == 1,
		rareKnown = entry.rare >= Model.RARE_TARGET,
		shinyKnown = entry.shiny >= Model.SHINY_TARGET,
	}
end

---@param state FGState?
---@param speciesId integer
---@return FGSpeciesState
function Model.Specimen(state, speciesId)
	local entry = state and state.species and state.species[speciesId]
	if not entry then
		return { count = 0, kills = 0, rare = 0, rareKills = 0, shiny = 0, shinyFinds = 0 }
	end
	entry.count = entry.count or 0
	if entry.kills == nil and entry.count > 0 and entry.killsEstimated == nil then
		entry.killsEstimated = true
	end
	entry.kills = entry.kills or entry.count or 0
	entry.rare = entry.rare or 0
	entry.rareKills = entry.rareKills or 0
	entry.shiny = entry.shiny or 0
	entry.shinyFinds = entry.shinyFinds or 0
	return entry
end

-- A nameplate observation is a local first sighting, not a claim that nobody else has seen the creature.
---@param state FGState
---@param speciesId integer
---@param timestamp number
---@param zone string
---@return boolean first
function Model.RecordSighting(state, speciesId, timestamp, zone)
	local entry = Entry(state, speciesId)
	if entry.firstSighting ~= nil then
		return false
	end
	entry.firstSighting = tonumber(timestamp) or 0
	entry.firstSightingZone = type(zone) == "string" and zone or ""
	return true
end

---@param state FGState
---@param encounterId integer
---@param name string
---@param difficultyId integer
---@param timestamp number
---@param instance string?
---@param difficultyName string?
---@return { firstSighting: boolean, record: FGEncounterState }
function Model.ObserveEncounter(state, encounterId, name, difficultyId, timestamp, instance, difficultyName)
	state.encounters = state.encounters or {}
	local key = tostring(encounterId)
	local encounter = state.encounters[key]
	if not encounter then
		encounter = {
			id = encounterId,
			name = name,
			instance = instance or "",
			kills = 0,
			sightings = 0,
			difficulties = {},
			difficultyNames = {},
		}
		state.encounters[key] = encounter
	end
	encounter.name = name or encounter.name or ""
	encounter.instance = instance or encounter.instance or ""
	encounter.sightings = (tonumber(encounter.sightings) or 0) + 1
	encounter.difficultyNames = encounter.difficultyNames or {}
	if difficultyName then
		encounter.difficultyNames[tostring(difficultyId or 0)] = difficultyName
	end
	local firstSighting = encounter.firstSighting == nil
	if firstSighting then
		encounter.firstSighting = tonumber(timestamp) or 0
		encounter.firstSightingDifficulty = tonumber(difficultyId) or 0
	end
	return { firstSighting = firstSighting, record = encounter }
end

---@param state FGState
---@param encounterId integer
---@param name string
---@param difficultyId integer
---@param timestamp number
---@param instance string?
---@param difficultyName string?
---@return { kills: integer, firstKill: boolean, record: FGEncounterState }
function Model.RecordEncounter(state, encounterId, name, difficultyId, timestamp, instance, difficultyName)
	state.encounters = state.encounters or {}
	local key = tostring(encounterId)
	local encounter = state.encounters[key]
	if not encounter then
		encounter = {
			id = encounterId,
			name = name,
			instance = instance or "",
			sightings = 0,
			difficulties = {},
			difficultyNames = {},
		}
		state.encounters[key] = encounter
	end
	encounter.name = name or encounter.name or ""
	encounter.instance = instance or encounter.instance or ""
	encounter.kills = (tonumber(encounter.kills) or 0) + 1
	encounter.difficulties = encounter.difficulties or {}
	local difficulty = tostring(difficultyId or 0)
	encounter.difficulties[difficulty] = (tonumber(encounter.difficulties[difficulty]) or 0) + 1
	encounter.difficultyNames = encounter.difficultyNames or {}
	if difficultyName then
		encounter.difficultyNames[difficulty] = difficultyName
	end
	local firstKill = encounter.firstKill == nil
	if firstKill then
		encounter.firstKill = tonumber(timestamp) or 0
		encounter.firstDifficulty = tonumber(difficultyId) or 0
	end
	return { kills = encounter.kills, firstKill = firstKill, record = encounter }
end

-- What a species has shown so far: common is known from the first specimen, rare needs RARE_TARGET sightings,
-- and shiny needs one lucky roll.
---@param state FGState?
---@param speciesId integer
---@return { common: FGVariant, rare: FGVariant, shiny: FGVariant }
function Model.Variants(state, speciesId)
	local entry = Model.Specimen(state, speciesId)
	return {
		common = { known = entry.count > 0, count = math.min(entry.count, 1), target = 1 },
		rare = { known = entry.rare >= Model.RARE_TARGET, count = entry.rare, target = Model.RARE_TARGET },
		shiny = { known = entry.shiny >= Model.SHINY_TARGET, count = entry.shiny, target = Model.SHINY_TARGET },
	}
end

---@param state FGState?
---@param speciesId integer
---@param species? FGSpecies
---@return boolean
function Model.IsComplete(state, speciesId, species)
	local variants = Model.Variants(state, speciesId)
	if not variants.common.known or not variants.shiny.known then
		return false
	end
	return not (species and species.rare) or variants.rare.known
end

-- A zone is catalogued when a species has at least one specimen, not when it is mastered. `fraction` is between
-- 0 and 1 and 0 for an empty catalogue, so a caller can draw a bar without dividing by zero.
---@param state FGState?
---@param speciesList FGSpecies[]
---@return { catalogued: integer, total: integer, fraction: number }
function Model.ZoneProgress(state, speciesList)
	local total = speciesList and #speciesList or 0
	local catalogued = 0
	for _, species in ipairs(speciesList or {}) do
		local entry = Model.Specimen(state, species.id)
		if entry.count > 0 then
			catalogued = catalogued + 1
		end
	end
	return {
		catalogued = catalogued,
		total = total,
		fraction = total > 0 and catalogued / total or 0,
	}
end

-- Session-only sightings, newest first. They are deliberately outside the saved state: a field journal keeps the
-- catalogue forever, but remembers today's walk only until the client closes.
---@type FGSighting[]
local sightings = {}
Model.Sightings = sightings

---@param entry FGSighting
---@return FGSighting
function Model.AddSighting(entry)
	local sighting = {
		time = entry.time or 0,
		zone = entry.zone or "",
		species = entry.species or "",
		kind = entry.kind or "kill",
	}
	table.insert(sightings, 1, sighting)
	while #sightings > Model.SIGHTING_LIMIT do
		table.remove(sightings)
	end
	return sighting
end

function Model.ClearSightings()
	for index = #sightings, 1, -1 do
		sightings[index] = nil
	end
end

---@return FGSighting[]
function Model.GetSightings()
	return sightings
end

Model.Sightings.Add = Model.AddSighting
Model.Sightings.Push = Model.AddSighting
Model.Sightings.Clear = Model.ClearSightings
Model.Sightings.List = Model.GetSightings

return Model
