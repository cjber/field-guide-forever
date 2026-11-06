---@type string, FGNamespace
local _, ns = ...

-- Pure catalogue state. Nothing here reads a frame, a saved variable or the client: Core owns the world, the UI
-- owns the pixels, and this file owns the arithmetic the specs can pin down.
---@class FGModel
local Model = {}
ns.Model = Model

Model.MASTERED_AT = 10
Model.SIGHTING_LIMIT = 50

-- One ladder for every creature. A spawn's tier is part of the spawn, not of the species or the character, so every
-- player who meets the same spawn sees the same tier.
Model.TIERS = { "bronze", "silver", "gold", "shiny" }
Model.TIER_ODDS = { bronze = 1, silver = 25, gold = 100, shiny = 1000 }

-- Old saves called the rare form confirmed after this many sightings.
Model.LEGACY_RARE_TARGET = 3

---@type table<integer, string>
Model.RANK_NAMES = {
	[0] = "Undiscovered",
	[1] = "Discovered",
	[2] = "Observed",
	[3] = "Studied",
	[4] = "Mastered",
}

-- A prime below 2^31 keeps every product under 2^53, where Lua 5.1's doubles still hold every integer exactly.
local HASH_MODULUS = 2147483647
local HASH_BASE = 1000003
local HASH_MIX = 48271
local TIER_ROLL = 1000000
-- Sizes ride the same stable GUID hash as the coats, with a salt of their own so the two rolls are not one another's
-- residue. Sizes are kept in hundredths, which is exactly what the wire protocol carries and what the journal shows.
local SIZE_SALT = 624544657
local SIZE_TAIL_ROLL = 200
local SIZE_BODY_MIN, SIZE_BODY_MAX = 70, 130
local SIZE_TINY_MIN, SIZE_TINY_MAX = 60, 69
local SIZE_GIANT_MIN, SIZE_GIANT_MAX = 141, 155
Model.SIZE_TINY = 70
Model.SIZE_GIANT = 140

---@param tier string?
---@return boolean
function Model.IsTier(tier)
	return tier == "bronze" or tier == "silver" or tier == "gold" or tier == "shiny"
end

-- A stable hash of the readable spawn GUID. No random source is involved, so two players looking at the same spawn
-- always agree. The final multiply spreads sequence-looking GUID suffixes across the whole roll before the ladder
-- reads it.
---@param guid string?
---@return integer
local function HashGuid(guid)
	if type(guid) ~= "string" or guid == "" then
		return 0
	end
	local hash = 2166136261 % HASH_MODULUS
	for index = 1, #guid do
		hash = (hash * HASH_BASE + guid:byte(index)) % HASH_MODULUS
	end
	return (hash * HASH_MIX) % HASH_MODULUS
end

-- The ladder partitions the roll: shiny 1 in 1000, gold 1 in 100, silver 1 in 25, and every other spawn is bronze.
-- A spawn without a readable GUID cannot be identified across clients, so it stays bronze.
---@param guid string?
---@return string
function Model.SpawnTier(guid)
	local hash = HashGuid(guid)
	if hash == 0 then
		return "bronze"
	end
	local roll = hash % TIER_ROLL
	if roll < 1000 then
		return "shiny"
	elseif roll < 11000 then
		return "gold"
	elseif roll < 51000 then
		return "silver"
	end
	return "bronze"
end

---@param hash integer
---@return integer
local function MixHash(hash)
	return (hash * HASH_MIX + 12345) % HASH_MODULUS
end

-- A spawn's size in hundredths of its normal scale (112 is 1.12x), from the same stable GUID hash family as its
-- coat with a salt of its own. The body is the sum of three uniform rolls, which is bell-shaped around 1.00x and
-- stays within 0.70x-1.30x; two rolls in 200 are instead the rare tails: Tiny under 0.70x and Giant over 1.40x.
---@param guid string?
---@return integer?
function Model.SpawnSize(guid)
	local hash = HashGuid(guid)
	if hash == 0 then
		return nil
	end
	hash = (hash * HASH_BASE + SIZE_SALT) % HASH_MODULUS
	local tail = hash % SIZE_TAIL_ROLL
	hash = MixHash(hash)
	if tail == 0 then
		return SIZE_TINY_MIN + hash % (SIZE_TINY_MAX - SIZE_TINY_MIN + 1)
	elseif tail == 1 then
		return SIZE_GIANT_MIN + hash % (SIZE_GIANT_MAX - SIZE_GIANT_MIN + 1)
	end
	local sum = 0
	for _ = 1, 3 do
		hash = MixHash(hash)
		sum = sum + hash % 1001
	end
	return SIZE_BODY_MIN + math.floor(sum * (SIZE_BODY_MAX - SIZE_BODY_MIN) / 3000 + 0.5)
end

---@param hundredths integer?
---@return string
function Model.FormatSize(hundredths)
	return string.format("%.2fx", (tonumber(hundredths) or 0) / 100)
end

---@param hundredths integer?
---@return string?
function Model.SizeBadge(hundredths)
	local value = tonumber(hundredths)
	if not value then
		return nil
	elseif value < Model.SIZE_TINY then
		return "TINY"
	elseif value > Model.SIZE_GIANT then
		return "GIANT"
	end
end

-- A fresh per-character state, flat enough that SavedVariables can serialise it without metatables.
---@return FGState
function Model.NewState()
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
	return string.format("%d-%d", minLevel, maxLevel)
end

---@param count number?
---@return string
function Model.RankName(count)
	return Model.RANK_NAMES[Model.Rank(count)] or Model.RANK_NAMES[0]
end

---@param state FGState
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
			bronze = 0,
			silver = 0,
			gold = 0,
			shiny = 0,
			tiny = 0,
			giant = 0,
		}
		state.species[speciesId] = entry
	end
	entry.count = entry.count or 0
	if entry.kills == nil and entry.count > 0 and entry.killsEstimated == nil then
		entry.killsEstimated = true
	end
	entry.kills = entry.kills or entry.count or 0
	entry.tiny = entry.tiny or 0
	entry.giant = entry.giant or 0
	for _, tier in ipairs(Model.TIERS) do
		entry[tier] = entry[tier] or 0
	end
	return entry
end

-- Bring one old entry onto the tier ladder. A save from before schema 4 had a kill count, a rare form and a shiny
-- flag, so its kills become bronze finds, a completed rare form becomes one silver and a found shiny stays shiny.
-- Gold was never recorded, so it is never inferred.
---@param old table?
---@return table
function Model.MigrateEntry(old)
	if type(old) ~= "table" then
		return { bronze = 0, silver = 0, gold = 0, shiny = 0 }
	end
	local entry = {}
	for key, value in pairs(old) do
		entry[key] = value
	end
	if old.bronze == nil then
		local kills = tonumber(old.kills) or tonumber(old.count) or 0
		local rare = tonumber(old.rare) or 0
		local shiny = tonumber(old.shiny) or 0
		entry.bronze = math.max(0, math.floor(kills))
		entry.silver = rare >= Model.LEGACY_RARE_TARGET and 1 or 0
		entry.gold = 0
		entry.shiny = shiny >= 1 and 1 or 0
		if entry.bronze > 0 and entry.firstBronze == nil then
			entry.firstBronze = old.firstKill
			entry.firstBronzeZone = old.firstKillZone
		end
		if entry.silver == 1 and entry.firstSilver == nil then
			entry.firstSilver = old.firstRare
			entry.firstSilverZone = old.firstRareZone
		end
	end
	entry.rare = nil
	entry.rareKills = nil
	entry.shinyFinds = nil
	entry.firstRare = nil
	entry.firstRareZone = nil
	return entry
end

-- Record one specimen. `opts.guid` is the readable spawn GUID the kill detector already dedupes on; a caller may
-- pass an explicit `opts.tier` or `opts.size` instead, which keeps the model testable without a client.
---@param state FGState
---@param speciesId integer
---@param opts? { tier?: string, guid?: string, size?: integer, time?: number, zone?: string }
---@return { count: integer, kills: integer, rank: integer, previousRank: integer, tier: string,
--- newlyDiscovered: boolean, firstKill: boolean, firstTier: boolean, firstBronze: boolean, firstSilver: boolean,
--- firstGold: boolean, firstShiny: boolean, bestTier: string?, size: integer?, sizeSmallest: integer?,
--- sizeLargest: integer?, newSmallest: boolean, newLargest: boolean, tiny: boolean, giant: boolean,
--- firstTiny: boolean, firstGiant: boolean }
function Model.Record(state, speciesId, opts)
	opts = opts or {}
	local entry = Entry(state, speciesId)
	local tier = Model.IsTier(opts.tier) and opts.tier or Model.SpawnTier(opts.guid)
	local size = tonumber(opts.size) or Model.SpawnSize(opts.guid)
	local previousSmallest, previousLargest = entry.sizeSmallest, entry.sizeLargest
	local newSmallest, newLargest = false, false
	local tiny, giant = false, false
	if size and (size < 1 or size > 999 or size % 1 ~= 0) then
		size = nil
	end
	if size then
		if not previousSmallest or size < previousSmallest then
			entry.sizeSmallest, newSmallest = size, true
		end
		if not previousLargest or size > previousLargest then
			entry.sizeLargest, newLargest = size, true
		end
		tiny = size < Model.SIZE_TINY
		giant = size > Model.SIZE_GIANT
		if tiny then
			entry.tiny = (entry.tiny or 0) + 1
		end
		if giant then
			entry.giant = (entry.giant or 0) + 1
		end
	end
	local previouslyFound = entry[tier] or 0
	local newlyDiscovered = entry.count == 0
	local previousRank = Model.Rank(entry.count)
	entry.count = math.min(entry.count + 1, Model.MASTERED_AT)
	entry.kills = entry.kills + 1
	entry[tier] = previouslyFound + 1
	local recordedAt = tonumber(opts.time) or 0
	entry.lastKill = recordedAt
	local zone = type(opts.zone) == "string" and opts.zone or ""
	entry.lastKillZone = zone
	if entry.firstKill == nil then
		entry.firstKill = recordedAt
		entry.firstKillZone = zone
	end
	if entry.firstSighting == nil then
		entry.firstSighting = recordedAt
		entry.firstSightingZone = zone
	end
	local firstTier = previouslyFound == 0
	if firstTier then
		if tier == "bronze" then
			entry.firstBronze = recordedAt
			entry.firstBronzeZone = zone
		elseif tier == "silver" then
			entry.firstSilver = recordedAt
			entry.firstSilverZone = zone
		elseif tier == "gold" then
			entry.firstGold = recordedAt
			entry.firstGoldZone = zone
		elseif tier == "shiny" then
			entry.firstShiny = recordedAt
			entry.firstShinyZone = zone
		end
	end

	return {
		count = entry.count,
		kills = entry.kills,
		rank = Model.Rank(entry.count),
		previousRank = previousRank,
		tier = tier,
		newlyDiscovered = newlyDiscovered,
		firstKill = entry.kills == 1,
		firstTier = firstTier,
		firstBronze = tier == "bronze" and firstTier,
		firstSilver = tier == "silver" and firstTier,
		firstGold = tier == "gold" and firstTier,
		firstShiny = tier == "shiny" and firstTier,
		bestTier = Model.BestTier(entry),
		size = size,
		sizeSmallest = entry.sizeSmallest,
		sizeLargest = entry.sizeLargest,
		newSmallest = newSmallest,
		newLargest = newLargest,
		tiny = tiny,
		giant = giant,
		firstTiny = tiny and entry.tiny == 1,
		firstGiant = giant and entry.giant == 1,
	}
end

---@param state FGState?
---@param speciesId integer
---@return FGSpeciesState
function Model.Specimen(state, speciesId)
	local entry = state and state.species and state.species[speciesId]
	if not entry then
		return { count = 0, kills = 0, bronze = 0, silver = 0, gold = 0, shiny = 0, tiny = 0, giant = 0 }
	end
	entry.count = entry.count or 0
	if entry.kills == nil and entry.count > 0 and entry.killsEstimated == nil then
		entry.killsEstimated = true
	end
	entry.kills = entry.kills or entry.count or 0
	entry.tiny = entry.tiny or 0
	entry.giant = entry.giant or 0
	for _, tier in ipairs(Model.TIERS) do
		entry[tier] = entry[tier] or 0
	end
	return entry
end

-- The best coat this character has found on a species, or nil before its first recorded sighting.
---@param entry FGSpeciesState?
---@return string?
function Model.BestTier(entry)
	if type(entry) ~= "table" then
		return nil
	end
	for index = #Model.TIERS, 1, -1 do
		local tier = Model.TIERS[index]
		if (tonumber(entry[tier]) or 0) > 0 then
			return tier
		end
	end
	return nil
end

-- Historical mastery counts are estimates. Only kills observed after that baseline belong on shared boards.
---@param entry FGSpeciesState
---@return number
function Model.ObservedKills(entry)
	if entry.killsEstimated and entry.sharedKillsBaseline == nil then
		entry.sharedKillsBaseline = entry.kills or entry.count or 0
	end
	return math.max(0, (entry.kills or 0) - (entry.sharedKillsBaseline or 0))
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

-- What a species has shown so far: each coat is known once this character has found one spawn wearing it.
---@param state FGState?
---@param speciesId integer
---@return { bronze: FGVariant, silver: FGVariant, gold: FGVariant, shiny: FGVariant }
function Model.Variants(state, speciesId)
	local entry = Model.Specimen(state, speciesId)
	local variants = {}
	for _, tier in ipairs(Model.TIERS) do
		local count = tonumber(entry[tier]) or 0
		variants[tier] = { known = count > 0, count = count, target = 1 }
	end
	return variants
end

-- How many species in a list have each coat found. Bronze is every species and needs no total; the header counts the
-- three that stand out.
---@param state FGState?
---@param speciesList FGSpecies[]
---@return { silver: integer, gold: integer, shiny: integer }
function Model.TierTotals(state, speciesList)
	local totals = { silver = 0, gold = 0, shiny = 0 }
	for _, species in ipairs(speciesList or {}) do
		local entry = Model.Specimen(state, species.id)
		for _, tier in ipairs({ "silver", "gold", "shiny" }) do
			if (tonumber(entry[tier]) or 0) > 0 then
				totals[tier] = totals[tier] + 1
			end
		end
	end
	return totals
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
---@type FGSightingLog
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

---@return FGSightingLog
function Model.GetSightings()
	return sightings
end

Model.Sightings.Add = Model.AddSighting
Model.Sightings.Push = Model.AddSighting
Model.Sightings.Clear = Model.ClearSightings
Model.Sightings.List = Model.GetSightings

return Model
