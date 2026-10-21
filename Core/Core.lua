---@type string, BFNamespace
local addonName, ns = ...
local L = ns.L

ns.ready = false
---@type fun()[]
local progressCallbacks = {}

-- The catalogue's lookup tables are built once. Core only reads them after this, and the UI reads the same tables
-- so a zone shown in the breadcrumb and a zone matched from GetZoneText() are always the same object.
function ns.BuildCatalogue()
	ns.ZoneByName = {}
	ns.SpeciesById = {}
	ns.SpeciesZone = {}
	for _, zone in ipairs(ns.Creatures.zones) do
		ns.ZoneByName[zone.name:lower()] = zone
		for _, species in ipairs(zone.species) do
			ns.SpeciesById[species.id] = species
			ns.SpeciesZone[species.id] = zone
		end
	end
end

ns.BuildCatalogue()

---@param name string?
---@return BFZone?
function ns.FindZone(name)
	if type(name) ~= "string" then
		return nil
	end
	return ns.ZoneByName[name:lower()]
end

---@return BFZone?
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
---@param zone BFZone?
---@return BFSpecies?
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

---@param create? boolean
---@return BFState?
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
	return state
end

function ns.Initialize()
	if ns.ready then
		return
	end
	if type(BestiaryForeverDB) ~= "table" then
		BestiaryForeverDB = {}
	end
	local db = BestiaryForeverDB
	db.version = db.version or 1
	db.chars = db.chars or {}
	db.window = db.window or {}
	db.options = db.options or {}
	if db.options.showUndiscovered == nil then
		db.options.showUndiscovered = true
	end
	if db.options.showSightingLog == nil then
		db.options.showSightingLog = true
	end
	ns.db = db
	ns.ready = true
	ns.GetCharacterState(true)
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
	local result = ns.Model.Record(state, species.id, { species = species })
	local kind = "kill"
	if result.shiny then
		kind = "shiny"
	elseif result.rare then
		kind = "rare"
	end
	ns.Model.AddSighting({
		time = time and time() or 0,
		zone = zone.name,
		species = species.name,
		kind = kind,
	})
	ns.FireProgress()
	return result
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

SLASH_BESTIARYFOREVER1 = "/bestiary"
SLASH_BESTIARYFOREVER2 = "/bst"
SlashCmdList["BESTIARYFOREVER"] = function(message)
	local command = type(message) == "string" and message:lower():match("^%s*(.-)%s*$") or ""
	if command == "help" then
		print(L["Open your bestiary with /bestiary or /bst."])
		return
	end
	if ns.Window and ns.Window.Toggle then
		ns.SafeCall("slash", ns.Window.Toggle)
	end
end
