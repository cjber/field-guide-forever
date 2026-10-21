---@type string, BFNamespace
local _, ns = ...

-- Pure catalogue state. Nothing here reads a frame, a saved variable or the client: Core owns the world, the UI
-- owns the pixels, and this file owns the arithmetic the specs can pin down.
---@class BFModel
local Model = {}
ns.Model = Model

Model.MASTERED_AT = 10
Model.RARE_TARGET = 3
Model.SHINY_TARGET = 1
Model.SHINY_CHANCE = 500
Model.SIGHTING_LIMIT = 50

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
---@return BFState
function Model.NewState(random)
	if random then
		Model.SetRandom(random)
	end
	return { species = {} }
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

---@param count number?
---@return string
function Model.RankName(count)
	return Model.RANK_NAMES[Model.Rank(count)] or Model.RANK_NAMES[0]
end

---@param state BFState?
---@param speciesId integer
---@return BFSpeciesState
local function Entry(state, speciesId)
	state.species = state.species or {}
	local entry = state.species[speciesId]
	if not entry then
		entry = { count = 0, rare = 0, shiny = 0 }
		state.species[speciesId] = entry
	end
	entry.count = entry.count or 0
	entry.rare = entry.rare or 0
	entry.shiny = entry.shiny or 0
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
---@param state BFState
---@param speciesId integer
---@param opts? { rare?: boolean, species?: BFSpecies, random?: fun(...: any): number }
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

	local isRare = opts.rare
	if isRare == nil and type(opts.species) == "table" then
		isRare = opts.species.rare == true
	end
	if isRare then
		entry.rare = math.min(entry.rare + 1, Model.RARE_TARGET)
	end

	local shiny = RollShiny(opts.random or Model.random)
	if shiny then
		entry.shiny = math.min(entry.shiny + 1, Model.SHINY_TARGET)
	end

	return {
		count = entry.count,
		rank = Model.Rank(entry.count),
		shiny = shiny,
		rare = isRare == true,
		newlyDiscovered = newlyDiscovered,
		rareKnown = entry.rare >= Model.RARE_TARGET,
		shinyKnown = entry.shiny >= Model.SHINY_TARGET,
	}
end

---@param state BFState?
---@param speciesId integer
---@return BFSpeciesState
function Model.Specimen(state, speciesId)
	local entry = state and state.species and state.species[speciesId]
	if not entry then
		return { count = 0, rare = 0, shiny = 0 }
	end
	entry.count = entry.count or 0
	entry.rare = entry.rare or 0
	entry.shiny = entry.shiny or 0
	return entry
end

-- What a species has shown so far: common is known from the first specimen, rare needs RARE_TARGET sightings,
-- and shiny needs one lucky roll.
---@param state BFState?
---@param speciesId integer
---@return { common: BFVariant, rare: BFVariant, shiny: BFVariant }
function Model.Variants(state, speciesId)
	local entry = Model.Specimen(state, speciesId)
	return {
		common = { known = entry.count > 0, count = math.min(entry.count, 1), target = 1 },
		rare = { known = entry.rare >= Model.RARE_TARGET, count = entry.rare, target = Model.RARE_TARGET },
		shiny = { known = entry.shiny >= Model.SHINY_TARGET, count = entry.shiny, target = Model.SHINY_TARGET },
	}
end

---@param state BFState?
---@param speciesId integer
---@param species? BFSpecies
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
---@param state BFState?
---@param speciesList BFSpecies[]
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
---@type BFSighting[]
local sightings = {}
Model.Sightings = sightings

---@param entry BFSighting
---@return BFSighting
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

---@return BFSighting[]
function Model.GetSightings()
	return sightings
end

Model.Sightings.Add = Model.AddSighting
Model.Sightings.Push = Model.AddSighting
Model.Sightings.Clear = Model.ClearSightings
Model.Sightings.List = Model.GetSightings

return Model
