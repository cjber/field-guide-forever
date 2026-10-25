---@type string, FGNamespace
local addonName, ns = ...
local L = ns.L

ns.ready = false
ns.Zones = ns.Zones or {}
ns.Instances = ns.Instances or {}
ns.SCHEMA = 2
---@type fun()[]
local progressCallbacks = {}

-- The catalogue's lookup tables are built once. Core only reads them after this, and the UI reads the same tables
-- so a zone shown in the breadcrumb and a zone matched from GetZoneText() are always the same object.
function ns.BuildCatalogue()
	ns.ZoneByName = {}
	ns.SpeciesById = {}
	ns.SpeciesZone = {}
	for _, zone in ipairs(ns.Zones or {}) do
		ns.ZoneByName[zone.name:lower()] = zone
		for _, species in ipairs(zone.species) do
			ns.SpeciesById[species.id] = species
			ns.SpeciesZone[species.id] = zone
		end
	end
	for _, instance in ipairs(ns.Instances or {}) do
		for _, species in ipairs(instance.species) do
			ns.SpeciesById[species.id] = species
		end
	end
end

ns.BuildCatalogue()

---@param name string?
---@return FGZone?
function ns.FindZone(name)
	if type(name) ~= "string" then
		return nil
	end
	return ns.ZoneByName[name:lower()]
end

---@return FGZone?
function ns.CurrentZone()
	local name = GetZoneText and GetZoneText() or nil
	if not name and GetRealZoneText then
		name = GetRealZoneText()
	end
	return ns.FindZone(name)
end

-- Exact names are what the combat log gives for a creature; case comes from the client's locale, so compare
-- lowered strings rather than relying on it.
---@param name string?
---@param zone FGZone?
---@return FGSpecies?
function ns.FindSpecies(name, zone)
	if type(name) ~= "string" or not zone then
		return nil
	end
	local wanted = name:lower()
	for _, species in ipairs(zone.species) do
		if species.name:lower() == wanted then
			return species
		end
	end
end

---@return string
function ns.CharacterKey()
	local name = UnitName and UnitName("player") or "Unknown"
	local realm = GetRealmName and GetRealmName() or "Unknown"
	return tostring(name) .. "-" .. tostring(realm)
end

local SPECIMEN_NUMBERS = {
	count = ns.Model.MASTERED_AT,
	kills = false,
	rare = ns.Model.RARE_TARGET,
	rareKills = false,
	shiny = ns.Model.SHINY_TARGET,
	shinyFinds = false,
}

local SPECIMEN_TIMES = {
	firstKill = true,
	lastKill = true,
	firstSighting = true,
	firstRare = true,
	firstShiny = true,
}

local SPECIMEN_ZONES = {
	firstKillZone = true,
	firstSightingZone = true,
	firstRareZone = true,
	firstShinyZone = true,
}

local function Integer(value, maximum)
	local number = tonumber(value)
	if not number or number ~= number then
		return 0
	end
	number = math.floor(number)
	if maximum then
		return math.max(0, math.min(number, maximum))
	end
	return math.max(0, number)
end

local function NormalizeState(state)
	local clean = { species = {}, encounters = {} }
	if type(state) ~= "table" then
		return clean
	end
	for id, old in pairs(type(state.species) == "table" and state.species or {}) do
		local numericId = tonumber(id)
		if numericId and numericId > 0 and numericId % 1 == 0 and type(old) == "table" then
			local entry = {}
			for field, maximum in pairs(SPECIMEN_NUMBERS) do
				entry[field] = Integer(old[field], maximum or nil)
			end
			entry.kills = math.max(entry.kills, entry.count)
			entry.rareKills = math.max(entry.rareKills, entry.rare)
			entry.shinyFinds = math.max(entry.shinyFinds, entry.shiny)
			entry.killsEstimated = old.killsEstimated == true
			for field in pairs(SPECIMEN_TIMES) do
				if type(old[field]) == "number" and old[field] >= 0 then
					entry[field] = old[field]
				end
			end
			for field in pairs(SPECIMEN_ZONES) do
				if type(old[field]) == "string" then
					entry[field] = old[field]
				end
			end
			clean.species[numericId] = entry
		end
	end
	for id, old in pairs(type(state.encounters) == "table" and state.encounters or {}) do
		if type(old) == "table" then
			local encounter = {
				id = Integer(old.id or id),
				name = type(old.name) == "string" and old.name or "",
				instance = type(old.instance) == "string" and old.instance or "",
				kills = Integer(old.kills),
				sightings = Integer(old.sightings),
				difficulties = {},
				difficultyNames = {},
			}
			for key, value in pairs(type(old.difficulties) == "table" and old.difficulties or {}) do
				encounter.difficulties[tostring(key)] = Integer(value)
			end
			for key, value in pairs(type(old.difficultyNames) == "table" and old.difficultyNames or {}) do
				if type(value) == "string" then
					encounter.difficultyNames[tostring(key)] = value
				end
			end
			for _, field in ipairs({ "firstSighting", "firstKill" }) do
				if type(old[field]) == "number" and old[field] >= 0 then
					encounter[field] = old[field]
				end
			end
			for _, field in ipairs({ "firstSightingDifficulty", "firstDifficulty" }) do
				if type(old[field]) == "number" then
					encounter[field] = Integer(old[field])
				end
			end
			for _, field in ipairs({ "firstSightingDifficultyName", "firstDifficultyName" }) do
				if type(old[field]) == "string" then
					encounter[field] = old[field]
				end
			end
			clean.encounters[tostring(id)] = encounter
		end
	end
	return clean
end

function ns.Migrate(db)
	if type(db) ~= "table" then
		db = {}
	end
	local version = Integer(db.version)
	if version > ns.SCHEMA then
		return { version = ns.SCHEMA, chars = {}, window = {}, options = {} }
	end
	db.chars = type(db.chars) == "table" and db.chars or {}
	for key, state in pairs(db.chars) do
		if type(key) ~= "string" then
			db.chars[key] = nil
		else
			db.chars[key] = NormalizeState(state)
		end
	end
	db.window = type(db.window) == "table" and db.window or {}
	db.options = type(db.options) == "table" and db.options or {}

	db.version = ns.SCHEMA
	return db
end

---@param create? boolean
---@return FGState?
function ns.GetCharacterState(create)
	if not ns.db then
		return nil
	end
	local key = ns.CharacterKey()
	local state = ns.db.chars[key]
	if not state and create then
		state = ns.Model.NewState()
		ns.db.chars[key] = state
	end
	if state and not state.species then
		state.species = {}
	end
	if state and not state.encounters then
		state.encounters = {}
	end
	return state
end

function ns.Initialize()
	if ns.ready then
		return
	end
	if type(FieldGuideForeverDB) ~= "table" then
		FieldGuideForeverDB = {}
	end
	local db = ns.Migrate(FieldGuideForeverDB)
	FieldGuideForeverDB = db
	if db.options.showUndiscovered == nil then
		db.options.showUndiscovered = true
	end
	if db.options.showSightingLog == nil then
		db.options.showSightingLog = true
	end
	if db.options.statsShare == nil then
		db.options.statsShare = true
	end
	if db.options.microButton == nil then
		db.options.microButton = true
	end
	ns.db = db
	ns.ready = true
	ns.GetCharacterState(true)
	ns.QuestieDB.Start(function()
		if ns.Window and ns.Window.RebuildZoneMenu then
			ns.Window.RebuildZoneMenu()
		end
		ns.FireProgress()
	end)
	ns.FireProgress()
end

---@param fn fun()
function ns.OnProgress(fn)
	progressCallbacks[#progressCallbacks + 1] = fn
	if ns.ready then
		ns.SafeCall("progress", fn)
	end
end

function ns.FireProgress()
	for _, fn in ipairs(progressCallbacks) do
		ns.SafeCall("progress", fn)
	end
end

local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x00000040
local NPC = COMBATLOG_OBJECT_TYPE_NPC or 0x00000400

-- Combat log flags are powers of two. Division keeps this file free of the bit library and of any client API that
-- a headless spec would need to stub.
---@param flags integer?
---@param flag integer
---@return boolean
local function HasFlag(flags, flag)
	if not flags or flag <= 0 then
		return false
	end
	return math.floor(flags / flag) % 2 == 1
end

---@param name string?
---@return table?
function ns.RecordKill(name)
	if not ns.ready then
		return nil
	end
	local zone = ns.CurrentZone()
	local species = ns.FindSpecies(name, zone)
	if not species then
		return nil
	end
	local state = ns.GetCharacterState(true)
	local timestamp = time and time() or 0
	local result = ns.Model.Record(state, species.id, { species = species, time = timestamp, zone = zone.name })
	local kind = "kill"
	if result.shiny then
		kind = "shiny"
	elseif result.rare then
		kind = "rare"
	end
	ns.Model.AddSighting({
		time = timestamp,
		zone = zone.name,
		species = species.name,
		kind = kind,
	})
	ns.FireProgress()
	return result
end

-- Nameplates provide a concrete local sighting event; scanning nearby units would be incomplete and can mislabel
-- creatures hidden by range, phasing, or client nameplate settings.
---@param unit string
function ns.RecordSighting(unit)
	if not ns.ready or not UnitIsEnemy or not UnitIsEnemy("player", unit) or not UnitName then
		return false
	end
	if UnitIsPlayer and UnitIsPlayer(unit) then
		return false
	end
	local zone = ns.CurrentZone()
	local species = ns.FindSpecies(UnitName(unit), zone)
	if not species then
		return false
	end
	local state = ns.GetCharacterState(true)
	local timestamp = time and time() or 0
	local first = ns.Model.RecordSighting(state, species.id, timestamp, zone.name)
	if first then
		ns.Model.AddSighting({ time = timestamp, zone = zone.name, species = species.name, kind = "sighting" })
		ns.FireProgress()
	end
	return first
end

-- ENCOUNTER_END reports completed instance encounters, giving us a dependable boss identity and difficulty.
local function OnEncounterEnd(encounterId, encounterName, difficultyId, _, success)
	if not ns.ready or success ~= 1 or type(encounterId) ~= "number" or type(encounterName) ~= "string" then
		return
	end
	local state = ns.GetCharacterState(true)
	local instanceName = GetInstanceInfo and select(1, GetInstanceInfo()) or ""
	local difficultyName = GetDifficultyInfo and GetDifficultyInfo(difficultyId) or nil
	local result = ns.Model.RecordEncounter(
		state,
		encounterId,
		encounterName,
		difficultyId,
		time and time() or 0,
		instanceName,
		difficultyName
	)
	ns.Model.AddSighting({
		time = time and time() or 0,
		zone = encounterName,
		species = encounterName,
		kind = result.firstKill and "boss-first" or "boss-kill",
	})
	ns.FireProgress()
end

local function OnEncounterStart(encounterId, encounterName, difficultyId)
	if not ns.ready or type(encounterId) ~= "number" or type(encounterName) ~= "string" then
		return
	end
	local state = ns.GetCharacterState(true)
	local timestamp = time and time() or 0
	local instanceName = GetInstanceInfo and select(1, GetInstanceInfo()) or ""
	local difficultyName = GetDifficultyInfo and GetDifficultyInfo(difficultyId) or nil
	local result = ns.Model.ObserveEncounter(
		state,
		encounterId,
		encounterName,
		difficultyId,
		timestamp,
		instanceName,
		difficultyName
	)
	if result.firstSighting then
		ns.Model.AddSighting({
			time = timestamp,
			zone = instanceName,
			species = encounterName,
			kind = "boss-sighting",
		})
	end
	ns.FireProgress()
end

-- UNIT_DIED names the creature in the destination fields. Only a hostile NPC counts: a friendly guard or another
-- player dying is not a field observation.
local function OnCombatLog()
	if not CombatLogGetCurrentEventInfo then
		return
	end
	local _, subevent, _, _, _, _, _, _, destName, destFlags = CombatLogGetCurrentEventInfo()
	if subevent ~= "UNIT_DIED" then
		return
	end
	if not HasFlag(destFlags, HOSTILE) or not HasFlag(destFlags, NPC) then
		return
	end
	ns.RecordKill(destName)
end

---@type table<string, fun(...)[]>
local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event] or {}) do
		ns.SafeCall(event, fn, ...)
	end
end)

---@param event string
---@param fn function
function ns.On(event, fn)
	handlers[event] = handlers[event] or {}
	table.insert(handlers[event], fn)
	events:RegisterEvent(event)
end

ns.On("ADDON_LOADED", function(name)
	if name == addonName then
		ns.Initialize()
	end
end)
ns.On("PLAYER_LOGIN", ns.Initialize)
ns.On("COMBAT_LOG_EVENT_UNFILTERED", OnCombatLog)
ns.On("NAME_PLATE_UNIT_ADDED", function(unit)
	ns.RecordSighting(unit)
end)
ns.On("PLAYER_TARGET_CHANGED", function()
	ns.RecordSighting("target")
end)
ns.On("ENCOUNTER_END", OnEncounterEnd)
ns.On("ENCOUNTER_START", OnEncounterStart)

local function OpenGuide()
	if ns.Window and ns.Window.Toggle then
		ns.SafeCall("open guide", ns.Window.Toggle)
	end
end
ns.OpenGuide = OpenGuide

SLASH_FIELDGUIDEFOREVER1 = "/fieldguide"
SLASH_FIELDGUIDEFOREVER2 = "/fg"
SLASH_FIELDGUIDEFOREVER3 = "/fgf"
SlashCmdList["FIELDGUIDEFOREVER"] = function(message)
	local command = type(message) == "string" and message:lower():match("^%s*(.-)%s*$") or ""
	if command == "help" then
		print(L["Open your field guide with /fieldguide or /fg. Use /fgf leaderboard to view recorded kills."])
		return
	end
	if command == "leaderboard" then
		local rows = ns.API and ns.API.LeaderboardSummary()
		if not rows then
			print(L["Leaderboard data is not ready yet."])
			return
		end
		print(L["Field Guide recorded kills (peer totals are reported, not verified):"])
		for index = 1, math.min(10, #rows) do
			local row = rows[index]
			local label = row.source == "local" and L["local"] or L["reported"]
			print(string.format(L["%d. %s — %d kills (%s)"], index, row.player, row.value, label))
		end
		return
	end
	OpenGuide()
end
