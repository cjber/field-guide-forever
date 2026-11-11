---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

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
-- Known limit: a creature that dies with no nameplate shown and not targeted is not seen, and one that was never
-- seen while its name or GUID was readable cannot be named; that kill is skipped rather than guessed.

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

-- What a unit token last showed while its name and GUID were readable.
---@class FGUnitIdentity
---@field guid? string
---@field name? string
---@field npcId? integer
---@field alive? boolean
---@field player? boolean
---@field canAttack? boolean
---@field tapDenied? boolean

-- In combat the client hides both for hostile units, so a nameplate or target seen alive is remembered by the
-- token it used, and the death it later reports is named from that memory. A token that is added or retargeted
-- replaces it, and a nameplate that leaves forgets it.
---@type table<string, FGUnitIdentity>
local identities = {}

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

-- The creature a unit token last showed, from what is readable now or what it showed while alive.
---@param unit string
---@param fresh boolean true when the token has just been given to a new unit
---@return FGUnitIdentity?
local function Identity(unit, fresh)
	local guid = ns.Readable(UnitGUID(unit))
	local name = ns.Readable(UnitName(unit))
	local creatureId = UnitCreatureID and ns.Readable(UnitCreatureID(unit)) or nil
	local npcId = NpcId(guid) or creatureId
	local info = not fresh and identities[unit] or nil
	if info and ((guid and guid ~= info.guid) or (name and info.name and name ~= info.name)) then
		info = nil
	end
	if guid or name or npcId then
		info = info or {}
		info.guid = guid or info.guid
		info.name = name or info.name
		info.npcId = npcId or info.npcId
		identities[unit] = info
	elseif fresh then
		identities[unit] = nil
		info = nil
	end
	if info and not UnitIsDead(unit) then
		info.alive = true
		info.player = UnitIsPlayer(unit)
		info.canAttack = UnitCanAttack("player", unit)
		info.tapDenied = UnitIsTapDenied(unit)
	end
	return info
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
---@param npcId integer?
local function Report(guid, name, npcId)
	npcId = npcId or NpcId(guid)
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
	if not ns.ready then
		return
	end
	local info = Identity(unit, false)
	if not UnitIsDead(unit) then
		return
	end
	local player = UnitIsPlayer(unit)
	local canAttack = UnitCanAttack("player", unit)
	local tapDenied = UnitIsTapDenied(unit)
	if info and info.alive then
		player, canAttack, tapDenied = info.player, info.canAttack, info.tapDenied
	end
	if player or not canAttack or tapDenied then -- a player, out of reach, or tagged by someone outside the group
		return
	end
	Report(
		info and info.guid or ns.Readable(UnitGUID(unit)),
		info and info.name or ns.Readable(UnitName(unit)),
		info and info.npcId
	)
end

---@param unit string
local function OnUnitHealth(unit)
	if unit == "target" or (type(unit) == "string" and unit:sub(1, 9) == "nameplate") then
		OnUnitDeath(unit)
	end
end

---@param unit string
local function OnUnitAdded(unit)
	if ns.ready then
		Identity(unit, true)
	end
end

---@param unit string
local function OnUnitRemoved(unit)
	OnUnitDeath(unit)
	identities[unit] = nil
end

local function OnTargetChanged()
	if ns.ready then
		Identity("target", true)
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
ns.On("PLAYER_TARGET_CHANGED", OnTargetChanged)
ns.On("NAME_PLATE_UNIT_ADDED", OnUnitAdded)
ns.On("NAME_PLATE_UNIT_REMOVED", OnUnitRemoved)
ns.On("VIGNETTES_UPDATED", OnVignettes)
ns.On("VIGNETTE_MINIMAP_UPDATED", OnVignettes)
-- Forever has no addon reader for the combat log; a client that has one may still refuse the event, which ns.On
-- survives.
if CombatLogGetCurrentEventInfo then
	ns.On("COMBAT_LOG_EVENT_UNFILTERED", OnCombatLog)
end
