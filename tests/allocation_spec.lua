-- Lua memory churn on the steady play path (#357). A nameplate, target or health event used to lower every name in the
-- zone and rebuild its unit identity table, which made the collector run constantly while no frame looked expensive.
-- Each path is measured the way the live collector sees it: collect before the event, then read collectgarbage("count")
-- after it, so a string built and dropped is counted every time rather than only its first, interned copy.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")

-- The JIT is off for this file: LuaJIT counts compiled traces in collectgarbage("count"), so a trace compiled
-- inside a measured region was charged to it as garbage, and where traces landed changed between runs (CI read 1.313
-- KB per NPC where a rerun read 0.712, #369). A trace is retained startup cost, not the per-event allocation guarded
-- here; with the JIT off every figure is the addon's own allocation and repeats exactly.
local jit = require("jit")
jit.off()

-- The creatures this spec's QuestieDB fixture holds, one per NPC.
local NPC_COUNT = 120
local FIRST_ID = 70001

-- An addon loaded over a QuestieDB fixture that answers from `answers`, one table per NPC, built by the spec: the
-- measurements then carry the addon's own work and not this fixture's.
---@param npcCount integer
---@return table
local function StartAddon(npcCount)
	local harness = Mock.Harness()
	local env, ns = harness.env, harness.ns
	local ids, answers = {}, {}
	for index = 1, npcCount do
		local id = FIRST_ID + index - 1
		ids[index] = id
		answers[id] = { "Zhevra " .. index, 10, 11, 0, "Beast", 17, { [17] = {} } }
	end
	-- The Barrens in the pinned client constants: every creature is placed there, so one zone holds the catalogue.
	local barrens
	for id, zone in pairs(ns.ClientData.zones) do
		if zone.name == "The Barrens" then
			barrens = id
		end
	end
	assert(barrens, "the pinned client constants contain the Barrens")
	for index = 1, npcCount do
		local answer = answers[FIRST_ID + index - 1]
		answer[6] = barrens
		answer[7] = { [barrens] = {} }
	end
	local reads = 0
	env.LibQuestieDB = {
		RequireContract = function()
			return true
		end,
		Npc = {
			GetAllIds = function()
				return ids
			end,
			GetAll = function(id)
				reads = reads + 1
				return answers[id]
			end,
		},
	}
	local onQuestieReady
	env.Questie = {
		API = {
			RegisterOnReady = function(fn)
				onQuestieReady = fn
			end,
		},
	}
	-- No yield inside the measured build: the slices are questiedb_spec's subject, and a coroutine resume per NPC
	-- would only add the engine's stack cost to the number.
	env.debugprofilestop = function()
		return 0
	end
	harness:Fire("ADDON_LOADED", "FieldGuideForever")
	harness:Fire("PLAYER_LOGIN")
	return {
		harness = harness,
		env = env,
		ns = ns,
		reads = function()
			return reads
		end,
		questieReady = function()
			return onQuestieReady
		end,
	}
end

-- Every timer login leaves pending, which is the catalogue build.
---@param addon table
local function RunBuild(addon)
	while #Mock.timers > 0 do
		addon.harness:RunTimers()
	end
end

-- What the build allocates per NPC. The zone scaffolding it also builds is the same at any NPC count, so a zero-NPC
-- build measures it and the difference is the per-creature cost. The collector is stopped for the count: otherwise it
-- sweeps mid-build and the number only shows whatever garbage happened to be left at the end.
---@param npcCount integer
---@return number kbPerNpc
local function BuildAllocation(npcCount)
	local addon = StartAddon(npcCount)
	collectgarbage("collect")
	collectgarbage("collect")
	collectgarbage("stop")
	local before = collectgarbage("count")
	RunBuild(addon)
	local allocated = collectgarbage("count") - before
	collectgarbage("restart")
	collectgarbage("collect")
	assert(addon.ns.QuestieDB.State() == "ok", "the fixture builds: " .. addon.ns.QuestieDB.State())
	return allocated
end

local emptyBuild = BuildAllocation(0)
local buildGarbagePerNpc = (BuildAllocation(NPC_COUNT) - emptyBuild) / NPC_COUNT

-- The harness the rest of this spec works in, created last: a harness resets the mock client, so the addon under
-- test must be the most recently loaded one.
local addon = StartAddon(NPC_COUNT)
local env, ns = addon.env, addon.ns
RunBuild(addon)
assert(ns.QuestieDB.State() == "ok", "the fixture builds: " .. ns.QuestieDB.State())
assert(ns.catalogueStatus == "ok", "the window reads a ready catalogue")

-- A second ready callback, or the wait fallback arriving late, must find the catalogue already built: reading the
-- database again replaced it with a second copy of every table (#357).
local onQuestieReady = assert(addon.questieReady(), "the build waits for Questie's ready callback")
local readsAfterBuild = addon.reads()
onQuestieReady()
RunBuild(addon)
assert(
	addon.reads() == readsAfterBuild and readsAfterBuild == NPC_COUNT,
	"the catalogue is built once: " .. addon.reads() .. " NPC reads for " .. NPC_COUNT
)
assert(ns.QuestieDB.State() == "ok", "a repeated ready callback leaves the catalogue ready")

---@param count integer
---@param fn fun(index: integer)
---@return number kbPerEvent
local function PerEvent(count, fn)
	for index = 1, 25 do
		fn(index)
	end
	collectgarbage("collect")
	collectgarbage("collect")
	local total = 0
	for index = 1, count do
		collectgarbage("collect")
		local before = collectgarbage("count")
		fn(index)
		total = total + collectgarbage("count") - before
	end
	return total / count
end

local LAST_NAME = "Zhevra " .. NPC_COUNT
local zone = ns.CurrentZone()
assert(zone and zone.species and #zone.species == NPC_COUNT, "the fixture is one zone in the catalogue")
assert(ns.FindSpecies(LAST_NAME, zone), "the fixture's last creature resolves")

-- A lookup of a name at the end of a zone's catalogue: the old scan lowered every name in the zone, about 5 KB of
-- garbage for a 120-creature zone on every nameplate and target event.
local lookup = PerEvent(200, function()
	assert(ns.FindSpecies(LAST_NAME, zone))
end)
assert(lookup < 0.2, string.format("a species lookup allocates %.3f KB", lookup))

Mock.units.target = LAST_NAME
Mock.guids.target = Mock.CreatureGUID(FIRST_ID + NPC_COUNT - 1)
local target = PerEvent(200, function()
	Mock.Fire("PLAYER_TARGET_CHANGED")
end)
assert(target < 0.8, string.format("a target change allocates %.3f KB", target))

Mock.units.nameplate1 = LAST_NAME
Mock.guids.nameplate1 = Mock.CreatureGUID(FIRST_ID)
Mock.canAttack.nameplate1 = true
local nameplateAdded = PerEvent(200, function()
	Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
end)
assert(nameplateAdded < 1.0, string.format("a nameplate add allocates %.3f KB", nameplateAdded))

local nameplateRemoved = PerEvent(200, function()
	Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
end)
assert(nameplateRemoved < 0.35, string.format("a nameplate removal allocates %.3f KB", nameplateRemoved))

local health = PerEvent(200, function()
	Mock.Fire("UNIT_HEALTH", "target")
end)
assert(health < 0.25, string.format("a target health event allocates %.3f KB", health))

-- A rare's minimap marker: the marker list itself comes from the client as tables, so the two reads are stubbed to
-- hand back one table each and the measurement is Field Guide's own work per update.
local markerIds, markerInfos = {}, {}
for index = 1, 12 do
	local key = "Vignette" .. index
	markerIds[index] = key
	markerInfos[key] = {
		objectGUID = Mock.CreatureGUID(FIRST_ID + index - 1),
		isDead = false,
		onMinimap = true,
		name = "Zhevra " .. index,
	}
end
local oneMarker = { markerIds[1] }
local list = markerIds
env.C_VignetteInfo.GetVignettes = function()
	return list
end
env.C_VignetteInfo.GetVignetteInfo = function(key)
	return markerInfos[key]
end

local allMarkers = PerEvent(200, function()
	Mock.Fire("VIGNETTES_UPDATED")
end)
list = oneMarker
local oneMarkerCost = PerEvent(200, function()
	Mock.Fire("VIGNETTES_UPDATED")
end)
list = markerIds
assert(allMarkers < 0.3, string.format("a 12-marker update allocates %.3f KB", allMarkers))
-- Every marker used to be parsed again on every update; eleven more markers may not cost eleven more answers.
assert(allMarkers - oneMarkerCost < 0.06, string.format("11 extra markers add %.3f KB", allMarkers - oneMarkerCost))

assert(buildGarbagePerNpc < 0.9, string.format("the build allocates %.3f KB per NPC", buildGarbagePerNpc))
print(
	string.format(
		"allocation_spec: ok, build %.3f KB/NPC, lookup %.3f, nameplate %.3f, vignettes %.3f KB/event",
		buildGarbagePerNpc,
		lookup,
		nameplateAdded,
		allMarkers
	)
)
