---@type string, FGNamespace
local addonName, ns = ...
local L = ns.L

if ns.broken then
	return
end

ns.ReportTitle = L["Field Guide Forever report"]
-- The one client icon every in-game identity surface draws: the minimap button and the journal's portrait. The TOC
-- declares it once and the drawn media/Icon stays the addon's store and TOC identity.
ns.icon = C_AddOns.GetAddOnMetadata(addonName, "X-Forever-Icon") or ""
-- The addon's own ForeverCore services: the error journal, the debug log, the report window and the map canvas. The
-- report's own lines are read when the window opens, after Core/Report.lua has defined them.
ns.core = ForeverCore.Register(addonName, {
	title = ns.ReportTitle,
	lines = function()
		return ns.ReportLines()
	end,
})
ns.ready = false
ns.Zones = ns.Zones or {}
ns.Instances = ns.Instances or {}
ns.SCHEMA = 5
---@type fun()[]
local progressCallbacks = {}
---@type fun(species: FGSpecies, zone: FGZone, result: FGRecordResult)[]
local recordCallbacks = {}

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

-- Exact names are what the client gives for a creature; case comes from the client's locale, so compare
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

-- The spawn's tier comes from its readable GUID, so every player who meets that spawn sees the same coat. A player,
-- a unit the player cannot attack and a unit token that does not exist have no spawn tier: nil, rather than the
-- bronze fallback the nameplate art shows. UI/Rarity.lua and the public API both read a unit through this.
---@param unit string
---@return string?
function ns.UnitTier(unit)
	if UnitIsPlayer and UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then
		return nil
	end
	return ns.Model.SpawnTier(ns.Readable(UnitGUID(unit)))
end

-- A zone is complete when every species listed in it has at least one specimen. Model.ZoneProgress already counts
-- exactly that, so the completion is known here in Core the moment a record changes it.
---@param state FGState
---@param zone FGZone
---@return boolean
local function ZoneComplete(state, zone)
	local progress = ns.Model.ZoneProgress(state, zone.species)
	return progress.total > 0 and progress.catalogued == progress.total
end

local SPECIMEN_NUMBERS = {
	count = ns.Model.MASTERED_AT,
	kills = false,
	bronze = false,
	silver = false,
	gold = false,
	shiny = false,
}

local SPECIMEN_TIMES = {
	firstKill = true,
	lastKill = true,
	firstSighting = true,
	firstBronze = true,
	firstSilver = true,
	firstGold = true,
	firstShiny = true,
}

local SPECIMEN_ZONES = {
	firstKillZone = true,
	lastKillZone = true,
	firstSightingZone = true,
	firstBronzeZone = true,
	firstSilverZone = true,
	firstGoldZone = true,
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
	for id, raw in pairs(type(state.species) == "table" and state.species or {}) do
		local numericId = tonumber(id)
		if numericId and numericId > 0 and numericId % 1 == 0 and type(raw) == "table" then
			local old = ns.Model.MigrateEntry(raw)
			local entry = {}
			for field, maximum in pairs(SPECIMEN_NUMBERS) do
				entry[field] = Integer(old[field], maximum or nil)
			end
			entry.kills = math.max(entry.kills, entry.count)
			-- A save from before kills were counted has only `count`: its kills are an estimate, as Model.Specimen says.
			entry.killsEstimated = old.killsEstimated == true
				or (old.kills == nil and old.killsEstimated == nil and entry.count > 0)
			if old.sharedKillsBaseline ~= nil then
				entry.sharedKillsBaseline = Integer(old.sharedKillsBaseline, entry.kills)
			elseif entry.killsEstimated then
				entry.sharedKillsBaseline = entry.kills
			end
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
	local tracked = tonumber(state.tracked)
	if tracked and tracked > 0 and tracked % 1 == 0 then
		clean.tracked = tracked
	end
	for id, flag in pairs(type(state.unseen) == "table" and state.unseen or {}) do
		local numericId = tonumber(id)
		if flag == true and numericId and clean.species[numericId] then
			clean.unseen = clean.unseen or {}
			clean.unseen[numericId] = true
		end
	end
	return clean
end

-- The saved variables brought up to ns.SCHEMA. A save from a newer version is left untouched and the second return
-- is true: the caller then works on the fresh table it gets and must not save it over the newer data.
---@return table db
---@return boolean? newer
function ns.Migrate(db)
	if type(db) ~= "table" then
		db = {}
	end
	local version = Integer(db.version)
	if version > ns.SCHEMA then
		return { version = ns.SCHEMA, chars = {}, options = {} }, true
	end
	db.chars = type(db.chars) == "table" and db.chars or {}
	for key, state in pairs(db.chars) do
		if type(key) ~= "string" then
			db.chars[key] = nil
		else
			db.chars[key] = NormalizeState(state)
		end
	end
	-- The journal is a UI panel the game places; the old dragged position is gone.
	db.window = nil
	db.options = type(db.options) == "table" and db.options or {}
	-- Forever Leaderboards is gone: drop the peer tables and sharing setting older versions saved.
	db.peerStats = nil
	db.sharedStats = nil
	db.options.statsShare = nil

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
	local db, newer = ns.Migrate(FieldGuideForeverDB)
	if not newer then
		FieldGuideForeverDB = db
	end
	if db.options.showUndiscovered == nil then
		db.options.showUndiscovered = true
	end
	if db.options.showSightingLog == nil then
		db.options.showSightingLog = true
	end
	-- The micro menu button is gone; a player who had hidden it keeps its minimap replacement hidden.
	if db.options.microButton == false then
		db.options.minimapButtonHidden = true
	end
	db.options.microButton = nil
	if db.options.minimapButtonHidden == nil then
		db.options.minimapButtonHidden = false
	end
	if db.options.milestoneToasts == nil then
		db.options.milestoneToasts = true
	end
	if db.options.discoveryText == nil then
		db.options.discoveryText = true
	end
	ns.db = db
	-- ForeverCore keeps the shared error journal under `errors` and the debug log under `log` in this saved table, so
	-- a report lists what led to a bug after a reload. Attach also merges what the shared files saw before this line.
	ns.core.Attach(db)
	ns.ready = true
	ns.GetCharacterState(true)
	ns.QuestieDB.Start(function()
		ns.FireProgress()
	end)
	ns.FireProgress()
end

---@param fn fun()
function ns.OnProgress(fn)
	progressCallbacks[#progressCallbacks + 1] = fn
	if ns.ready then
		ns.core.SafeCall("progress", fn)
	end
end

function ns.FireProgress()
	for _, fn in ipairs(progressCallbacks) do
		ns.core.SafeCall("progress", fn)
	end
end

-- Told of every recorded kill, with what it changed. A listener only notes it and schedules its own work, as the
-- progress listeners do: this runs inside the kill handler, which can be in combat.
---@param fn fun(species: FGSpecies, zone: FGZone, result: FGRecordResult)
function ns.OnRecord(fn)
	recordCallbacks[#recordCallbacks + 1] = fn
end

-- A kill names its creature by NPC id when the client let us read the unit's GUID, else by name. Either way the
-- creature must belong to the zone the player is in, as every catalogue lookup does. The readable spawn GUID is what
-- decides the spawn's tier, so it travels with the record.
---@param name string?
---@param npcId integer?
---@param guid string?
---@return table?
function ns.RecordKill(name, npcId, guid)
	if not ns.ready then
		return nil
	end
	local zone = ns.CurrentZone()
	local species = npcId and ns.SpeciesZone[npcId] == zone and ns.SpeciesById[npcId] or ns.FindSpecies(name, zone)
	if not species or not zone then
		return nil
	end
	local state = ns.GetCharacterState(true)
	if not state then
		return nil
	end
	local timestamp = GetServerTime()
	local entry = state.species and state.species[species.id]
	local firstSighting = not (entry and entry.firstSighting)
	local zoneWasComplete = ZoneComplete(state, zone)
	local result = ns.Model.Record(state, species.id, { guid = guid, time = timestamp, zone = zone.name })
	if result.newlyDiscovered then
		state.unseen = state.unseen or {}
		state.unseen[species.id] = true
	end
	local kind = result.tier ~= "bronze" and result.tier or "kill"
	ns.Model.AddSighting({
		time = timestamp,
		zone = zone.name,
		species = species.name,
		kind = kind,
	})
	-- Model.Record builds the FGRecordResult and stays pure; the API's change counters are bumped here, where the
	-- result is first produced, so they fire whether or not milestone toasts are on.
	if firstSighting then
		ns.NotifyAPIChange("sighting")
	end
	if result.firstSilver or result.firstGold or result.firstShiny then
		ns.NotifyAPIChange("tier")
	end
	ns.NotifyAPIChange("specimen")
	if not zoneWasComplete and ZoneComplete(state, zone) then
		ns.NotifyAPIChange("zone")
	end
	ns.FireProgress()
	for _, fn in ipairs(recordCallbacks) do
		ns.core.SafeCall("record", fn, species, zone, result)
	end
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
	local species = ns.FindSpecies(ns.Readable(UnitName(unit)), zone)
	if not species or not zone then
		return false
	end
	local state = ns.GetCharacterState(true)
	if not state then
		return false
	end
	local timestamp = GetServerTime()
	local first = ns.Model.RecordSighting(state, species.id, timestamp, zone.name)
	if first then
		ns.Model.AddSighting({ time = timestamp, zone = zone.name, species = species.name, kind = "sighting" })
		ns.NotifyAPIChange("sighting")
		ns.NotifyAPIChange("specimen")
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
	if not state then
		return
	end
	local instanceName = GetInstanceInfo and select(1, GetInstanceInfo()) or ""
	local difficultyName = GetDifficultyInfo and GetDifficultyInfo(difficultyId) or nil
	local result = ns.Model.RecordEncounter(
		state,
		encounterId,
		encounterName,
		difficultyId,
		GetServerTime(),
		instanceName,
		difficultyName
	)
	ns.Model.AddSighting({
		time = GetServerTime(),
		zone = instanceName,
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
	if not state then
		return
	end
	local timestamp = GetServerTime()
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

---@type table<string, fun(...)[]>
local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event] or {}) do
		ns.core.SafeCall(event, fn, ...)
	end
end)

-- Registering for an event the client keeps from addons raises, so a refused registration returns false and leaves
-- no handler behind instead of stopping the file that asked.
---@param event string
---@param fn function
---@return boolean registered
function ns.On(event, fn)
	if not pcall(events.RegisterEvent, events, event) then
		return false
	end
	handlers[event] = handlers[event] or {}
	table.insert(handlers[event], fn)
	return true
end

ns.On("ADDON_LOADED", function(name)
	if name == addonName then
		ns.Initialize()
	end
end)
ns.On("PLAYER_LOGIN", ns.Initialize)
ns.On("NAME_PLATE_UNIT_ADDED", function(unit)
	ns.RecordSighting(unit)
end)
ns.On("PLAYER_TARGET_CHANGED", function()
	ns.RecordSighting("target")
end)
ns.On("ENCOUNTER_END", OnEncounterEnd)
ns.On("ENCOUNTER_START", OnEncounterStart)

-- Session-only rarity demo: the UI reads this and never writes it to saved progress or to a kill record.
local rarityPreview = false

---@return boolean
function ns.RarityPreviewActive()
	return rarityPreview
end

local function ToggleRarityPreview()
	rarityPreview = not rarityPreview
	if rarityPreview then
		local previewOn = "Rarity preview is on. Every creature shows silver, gold or shiny for this session; "
			.. "use /fg preview again to turn it off."
		print(L[previewOn])
	else
		print(L["Rarity preview is off."])
	end
	if ns.Rarity and ns.Rarity.Refresh then
		ns.core.SafeCall("rarity preview", ns.Rarity.Refresh)
	end
end

local function OpenGuide()
	if ns.Window and ns.Window.Toggle then
		ns.core.SafeCall("open guide", ns.Window.Toggle)
	end
end
ns.OpenGuide = OpenGuide

SLASH_FIELDGUIDEFOREVER1 = "/fieldguide"
SLASH_FIELDGUIDEFOREVER2 = "/fg"
SLASH_FIELDGUIDEFOREVER3 = "/fgf"
SlashCmdList["FIELDGUIDEFOREVER"] = function(message)
	local command = type(message) == "string" and message:lower():match("^%s*(.-)%s*$") or ""
	if ns.core.Report.Command(command) then
		return
	end
	if command == "help" then
		local help = "Open your field guide with /fieldguide or /fg, or use /fg preview to show every creature as "
			.. "silver, gold or shiny for this session."
		print(L[help])
		return
	end
	if command == "preview" then
		ToggleRarityPreview()
		return
	end
	OpenGuide()
end
