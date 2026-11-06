---@type string, FGNamespace
local _, ns = ...

-- Kill detection from the signals the Forever client gives addons.
--
-- Forever 1.60.1 keeps the combat log to Blizzard's secure code: C_CombatLog has no GetCurrentEventInfo, the only
-- reader is C_CombatLogSecure.GetCurrentEventInfo (Environment "SecureOnly"), COMBAT_LOG_EVENT_UNFILTERED is a
-- restricted event, and the default combat log window itself now reads COMBAT_LOG_MESSAGE from a secure processor.
-- The UNIT_DIED and PARTY_KILL events carry a GUID that is secret for any unit not player-controlled or in the group.
-- So a kill is counted from what an addon can still read:
--   1. A creature the player can see, as the target or on a nameplate, that dies (UNIT_HEALTH, or its nameplate
--      leaving with UnitIsDead true) while it is attackable and not tapped by someone else.
--   2. A rare's map marker (C_VignetteInfo) that the player saw alive and that turns dead while on the minimap.
--   3. The combat log, only on a client that still hands it to addons.
-- Known limit: a creature that dies with no nameplate shown and not targeted is not seen, and when the client keeps a
-- unit's name and GUID secret there is nothing to name it by, so that kill is skipped rather than guessed.

-- Two reports of one name within this many seconds, where either lacks a GUID, are one death.
local SAME_DEATH_SECONDS = 3
-- A dead creature never dies again, so the GUID memory is only bounded, never aged.
local MAX_REMEMBERED = 500

---@type table<string, true>
local countedGuids = {}
local countedCount = 0
---@type table<string, { time: number, guid: string? }>
local recentNames = {}
-- Rares whose marker was seen alive, by the creature's GUID; a marker that is dead on first sight is not our kill.
---@type table<string, true>
local markersAlive = {}

-- The NPC id inside a creature GUID ("Creature-0-<server>-<instance>-<zone>-<npc id>-<spawn>").
---@param guid string?
---@return integer?
local function NpcId(guid)
	if type(guid) ~= "string" then
		return nil
	end
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
	if kind == "Creature" or kind == "Vehicle" then
		return tonumber(id)
	end
end

-- True the first time a death is reported. Every source reports the same death in its own way (target and nameplate
-- both see it, a rare's marker too), so a GUID counts once, and a name counts once per window when a GUID is missing
-- on either side. Two creatures of one name with different GUIDs are two kills.
---@param guid string?
---@param name string?
---@return boolean
local function FirstReport(guid, name)
	if guid and countedGuids[guid] then
		return false
	end
	local now = GetTime()
	local key = name and name:lower()
	local last = key and recentNames[key]
	if last and now - last.time < SAME_DEATH_SECONDS and not (guid and last.guid) then
		return false
	end
	if guid then
		if countedCount >= MAX_REMEMBERED then
			countedGuids, countedCount, recentNames = {}, 0, {}
		end
		countedGuids[guid] = true
		countedCount = countedCount + 1
	end
	if key then
		recentNames[key] = { time = now, guid = guid }
	end
	return true
end

---@param guid string?
---@param name string?
local function Report(guid, name)
	local npcId = NpcId(guid)
	if not npcId and not name then
		return
	end
	if FirstReport(guid, name) then
		ns.RecordKill(name, npcId, guid)
	end
end

-- UnitIsDead, UnitCanAttack, UnitIsPlayer and UnitIsTapDenied are never secret; the GUID and name may be.
---@param unit string
local function OnUnitDeath(unit)
	if not ns.ready or not UnitIsDead(unit) or UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then
		return
	end
	if UnitIsTapDenied(unit) then -- tagged by someone outside the group: their kill, not ours
		return
	end
	Report(ns.Readable(UnitGUID(unit)), ns.Readable(UnitName(unit)))
end

---@param unit string
local function OnUnitHealth(unit)
	if unit == "target" or (type(unit) == "string" and unit:sub(1, 9) == "nameplate") then
		OnUnitDeath(unit)
	end
end

local function OnVignettes()
	if not ns.ready or not C_VignetteInfo then
		return
	end
	---@type table<string, true>
	local present = {}
	for _, vignetteGUID in ipairs(C_VignetteInfo.GetVignettes() or {}) do
		local info = C_VignetteInfo.GetVignetteInfo(vignetteGUID)
		local guid = info and ns.Readable(info.objectGUID)
		if info and NpcId(guid) then
			---@cast guid string
			if not ns.Readable(info.isDead) then
				markersAlive[guid] = true
				present[guid] = true
			elseif markersAlive[guid] and ns.Readable(info.onMinimap) then
				Report(guid, ns.Readable(info.name))
			end
		end
	end
	for guid in pairs(markersAlive) do
		if not present[guid] then
			markersAlive[guid] = nil
		end
	end
end

local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x00000040
local NPC = COMBATLOG_OBJECT_TYPE_NPC or 0x00000400

-- Combat log flags are powers of two; division keeps this file free of the bit library.
---@param flags any
---@param flag integer
---@return boolean
local function HasFlag(flags, flag)
	return type(flags) == "number" and math.floor(flags / flag) % 2 == 1
end

-- A refused read is quiet: on a client that blocks it, every combat event would otherwise report an error.
local function OnCombatLog()
	local ok, _, subevent, _, _, _, _, _, destGUID, destName, destFlags = pcall(CombatLogGetCurrentEventInfo)
	if not ok or ns.Readable(subevent) ~= "UNIT_DIED" then
		return
	end
	destFlags = ns.Readable(destFlags)
	if HasFlag(destFlags, HOSTILE) and HasFlag(destFlags, NPC) then
		Report(ns.Readable(destGUID), ns.Readable(destName))
	end
end

ns.On("UNIT_HEALTH", OnUnitHealth)
ns.On("NAME_PLATE_UNIT_REMOVED", OnUnitDeath)
ns.On("VIGNETTES_UPDATED", OnVignettes)
ns.On("VIGNETTE_MINIMAP_UPDATED", OnVignettes)
-- Forever has no addon reader for the combat log; a client that has one may still refuse the event, which ns.On
-- survives.
if CombatLogGetCurrentEventInfo then
	ns.On("COMBAT_LOG_EVENT_UNFILTERED", OnCombatLog)
end
