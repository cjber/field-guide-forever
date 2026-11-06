-- Kill recording on a client like Forever 1.60.1, where the combat log is secure-only (issue #91): kills come from the
-- target and nameplates dying and from rare map markers, each death counts once, and secret values are never read.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")

local npcFixture = {
	[1001] = {
		name = "Plainstrider",
		minLevel = 1,
		maxLevel = 2,
		rank = 0,
		subName = "Beast",
		zoneID = 17,
		spawns = { [17] = {} },
	},
	[1003] = {
		name = "Savannah Prowler",
		minLevel = 9,
		maxLevel = 10,
		rank = 0,
		subName = "Beast",
		zoneID = 17,
		spawns = { [17] = {} },
	},
	[1019] = {
		name = "Dishu",
		minLevel = 13,
		maxLevel = 13,
		rank = 2,
		subName = "Beast",
		zoneID = 17,
		spawns = { [17] = {} },
	},
}

---@param opts? table
local function Start(opts)
	local harness = Mock.Harness(opts)
	harness.env.LibQuestieDB = {
		Npc = {
			GetAllIds = function()
				return { 1001, 1003, 1019 }
			end,
			GetAll = function(id, fields)
				local row, values = npcFixture[id], {}
				for _, field in ipairs(fields) do
					values[#values + 1] = row[field]
				end
				return values
			end,
		},
	}
	harness:Fire("ADDON_LOADED", "FieldGuideForever")
	harness:Fire("PLAYER_LOGIN")
	harness:RunTimers()
	assert(harness.ns.ready, "the addon initialises")
	return harness
end

---@param harness table
---@param id integer
---@return integer
local function Kills(harness, id)
	local entry = harness.ns.Model.Specimen(harness.ns.GetCharacterState(false), id)
	return entry and entry.kills or 0
end

---@param harness table
---@param unit string
---@param name string
---@param guid string
local function Dies(harness, unit, name, guid)
	Mock.units[unit], Mock.guids[unit], Mock.dead[unit] = name, guid, true
	harness:Fire("UNIT_HEALTH", unit)
end

-- Values the client keeps secret: any comparison, index or concatenation raises, and canaccessvalue says no.
local secrets = setmetatable({}, { __mode = "k" })
local function Secret()
	local value = newproxy(true)
	local meta = getmetatable(value)
	local function refuse()
		error("attempt to use a secret value", 2)
	end
	meta.__index, meta.__eq, meta.__lt, meta.__le, meta.__concat, meta.__len, meta.__call =
		refuse, refuse, refuse, refuse, refuse, refuse, refuse
	secrets[value] = true
	return value
end

local harness = Start()
local ns = harness.ns

assert(
	not Mock.eventFrames.COMBAT_LOG_EVENT_UNFILTERED,
	"with no addon reader for the combat log, its event is not registered"
)

-- The target dies.
local first = Mock.CreatureGUID(1001)
Dies(harness, "target", "Plainstrider", first)
assert(Kills(harness, 1001) == 1, "a target that dies is recorded as a kill")

-- The same creature is also on a nameplate; its health event and its nameplate leaving report the same death.
Dies(harness, "nameplate1", "Plainstrider", first)
harness:Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(Kills(harness, 1001) == 1, "one death seen as target and nameplate counts once")

-- Two creatures of one name dying together are two kills.
Dies(harness, "nameplate2", "Plainstrider", Mock.CreatureGUID(1001))
Dies(harness, "nameplate3", "Plainstrider", Mock.CreatureGUID(1001))
assert(Kills(harness, 1001) == 3, "two creatures with different GUIDs are two kills")

-- Not kills: a living creature's health change, a unit other than the target or a nameplate, and a creature that
-- another player tagged.
Mock.units.nameplate4, Mock.guids.nameplate4, Mock.dead.nameplate4 = "Plainstrider", Mock.CreatureGUID(1001), false
harness:Fire("UNIT_HEALTH", "nameplate4")
Dies(harness, "party1target", "Plainstrider", Mock.CreatureGUID(1001))
Mock.tapDenied.nameplate5 = true
Dies(harness, "nameplate5", "Plainstrider", Mock.CreatureGUID(1001))
assert(Kills(harness, 1001) == 3, "living, unwatched and tapped-by-others creatures are not counted")

-- A GUID the client keeps secret: the name still counts it, once per death across target and nameplate.
harness.env.canaccessvalue = function(value)
	return not secrets[value]
end
Dies(harness, "target", "Savannah Prowler", Secret())
Dies(harness, "nameplate1", "Savannah Prowler", Secret())
assert(Kills(harness, 1003) == 1, "with the GUID secret, one death reported twice by name counts once")
Mock.clock = Mock.clock + 10
Dies(harness, "nameplate2", "Savannah Prowler", Secret())
assert(Kills(harness, 1003) == 2, "a later death of the same name is a new kill")

-- A secret name with a readable GUID: the NPC id inside the GUID names the creature.
Dies(harness, "target", Secret(), Mock.CreatureGUID(1003))
assert(Kills(harness, 1003) == 3, "the NPC id in a readable GUID identifies a creature whose name is secret")

-- Both secret: nothing to name it by, so nothing is recorded and nothing raises.
Dies(harness, "target", Secret(), Secret())
assert(Kills(harness, 1003) == 3, "a creature with secret name and GUID is skipped")
Mock.units.nameplate1 = Secret()
harness:Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(#ns.GetErrors() == 0, "secret names and GUIDs never raise: " .. tostring((ns.GetErrors()[1] or {}).message))

-- A rare's map marker: seen alive, then dead while on the minimap, counts once, even when its corpse is then
-- targeted.
local dishu = Mock.CreatureGUID(1019)
local marker = { vignetteGUID = "Vignette-1", objectGUID = dishu, name = "Dishu", isDead = false, onMinimap = true }
Mock.vignettes = { marker }
harness:Fire("VIGNETTES_UPDATED")
assert(Kills(harness, 1019) == 0, "a living rare's marker is not a kill")
marker.isDead = true
harness:Fire("VIGNETTES_UPDATED")
harness:Fire("VIGNETTE_MINIMAP_UPDATED", "Vignette-1", true)
Dies(harness, "target", "Dishu", dishu)
assert(Kills(harness, 1019) == 1, "a rare's marker turning dead is one kill, however many sources report it")

-- A marker already dead when first seen, or far off the minimap when it dies, is someone else's kill.
Mock.vignettes = {
	{
		vignetteGUID = "Vignette-2",
		objectGUID = Mock.CreatureGUID(1019),
		name = "Dishu",
		isDead = true,
		onMinimap = true,
	},
}
harness:Fire("VIGNETTES_UPDATED")
local far = { vignetteGUID = "Vignette-3", objectGUID = Mock.CreatureGUID(1019), name = "Dishu", isDead = false }
Mock.vignettes = { far }
harness:Fire("VIGNETTES_UPDATED")
far.isDead, far.onMinimap = true, false
harness:Fire("VIGNETTES_UPDATED")
assert(Kills(harness, 1019) == 1, "a marker dead on first sight or off the minimap is not counted")
assert(#ns.GetErrors() == 0, "the kill paths raise no errors")

-- A client that still hands addons the combat log but refuses the event: loading does not fail.
harness = Start({ combatLog = true, refuse = { COMBAT_LOG_EVENT_UNFILTERED = true } })
assert(harness.ns.ready, "a refused combat log registration leaves the addon working")
Mock.Kill("Plainstrider", 1001)
assert(Kills(harness, 1001) == 1, "with the combat log refused, target deaths still count")

-- A client whose combat log works: its UNIT_DIED counts, and the same death from the target is not counted again.
harness = Start({ combatLog = true })
local guid = Mock.CreatureGUID(1001)
Mock.combatLog = { 0, "UNIT_DIED", false, nil, nil, nil, nil, guid, "Plainstrider", 0x440 }
harness:Fire("COMBAT_LOG_EVENT_UNFILTERED")
Dies(harness, "target", "Plainstrider", guid)
assert(Kills(harness, 1001) == 1, "a combat log death and the target's death are one kill")
-- A reader that raises is quiet.
harness.env.CombatLogGetCurrentEventInfo = function()
	error("blocked")
end
harness:Fire("COMBAT_LOG_EVENT_UNFILTERED")
assert(#harness.ns.GetErrors() == 0, "a blocked combat log read reports no error")

print("kills_spec: ok")
