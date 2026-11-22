-- UI/Tooltip.lua: creature unit tooltips show the player's Field Guide progress (rank, kills, or not yet recorded)
-- through TooltipDataProcessor.AddTooltipPostCall, staying silent in combat, on forbidden tooltips, on secret GUIDs,
-- before state is ready, on players/pets/unknown NPCs, and when turned off in settings.
local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")

-- Load everything before UI/Tooltip.lua, install local TooltipDataProcessor/Enum stubs into env, then load the rest
-- so the test exercises the real load-time registration without editing tests/wow_mock.lua.
local before, after = {}, {}
local seenTooltip = false
for _, file in ipairs(Mock.TocFiles()) do
	if file == "UI/Tooltip.lua" then
		seenTooltip = true
	end
	if seenTooltip then
		after[#after + 1] = file
	else
		before[#before + 1] = file
	end
end

local harness = Mock.Harness({ files = before })
local env, ns = harness.env, harness.ns

local postCalls = {}
env.Enum = env.Enum or {}
env.Enum.TooltipDataType = { Unit = 2 }
env.TooltipDataProcessor = {
	AddTooltipPostCall = function(dataType, fn)
		postCalls[#postCalls + 1] = { dataType = dataType, fn = fn }
	end,
}

local function MakeTooltip(opts)
	opts = opts or {}
	local added = {}
	local tooltip = {
		lines = added,
		unitLookups = 0,
		IsForbidden = function()
			return opts.forbidden == true
		end,
		GetUnit = function(self)
			self.unitLookups = self.unitLookups + 1
			return opts.unitName, opts.unitToken
		end,
	}
	return tooltip
end

env.GameTooltip_AddNormalLine = function(tooltip, text)
	tooltip.lines[#tooltip.lines + 1] = { text = text, kind = "normal" }
end
env.GameTooltip_AddHighlightLine = function(tooltip, text)
	tooltip.lines[#tooltip.lines + 1] = { text = text, kind = "highlight" }
end
env.GameTooltip_AddDisabledLine = function(tooltip, text)
	tooltip.lines[#tooltip.lines + 1] = { text = text, kind = "disabled" }
end

for _, file in ipairs(after) do
	harness.Load(file)
end

assert(#postCalls == 1, "expected one TooltipDataProcessor.AddTooltipPostCall registration, got " .. #postCalls)
assert(postCalls[1].dataType == env.Enum.TooltipDataType.Unit, "registered on Enum.TooltipDataType.Unit")
local hook = postCalls[1].fn

-- Populate a minimal catalogue with two creatures.
local wolf =
	{ id = 299, name = "Diseased Young Wolf", family = "Beast", zone = "Elwynn Forest", minLevel = 1, maxLevel = 2 }
local boar = { id = 308, name = "Young Boar", family = "Beast", zone = "Elwynn Forest", minLevel = 1, maxLevel = 2 }
ns.Zones = {
	{ id = 12, name = "Elwynn Forest", continent = "Eastern Kingdoms", species = { wolf, boar } },
}
ns.BuildCatalogue()

local wolfGuid = "Creature-0-1-0-12-299-00000001"
local boarGuid = "Creature-0-1-0-12-308-00000002"
local vehicleGuid = "Vehicle-0-1-0-12-299-00000003"
local unknownNpcGuid = "Creature-0-1-0-12-99999-00000004"
local playerGuid = "Player-6941-00000001"
local petGuid = "Pet-0-1-0-12-299-0100000005"

-- 1. State not ready yet: hovering a known creature adds nothing.
local beforeReadyTip = MakeTooltip()
hook(beforeReadyTip, { guid = wolfGuid })
assert(#beforeReadyTip.lines == 0, "no lines before addon state is ready")

-- Initialize addon state and settings.
harness:Fire("ADDON_LOADED", "FieldGuideForever")
harness:Fire("PLAYER_LOGIN")

-- 2. Known creature not yet recorded in journal.
local parseNpcId = ns.NpcId
assert(type(parseNpcId) == "function", "Kills must expose its cached GUID parser")
local parsedGuid
ns.NpcId = function(guid)
	parsedGuid = guid
	return parseNpcId(guid)
end
local unrecordedTip = MakeTooltip()
hook(unrecordedTip, { guid = wolfGuid })
ns.NpcId = parseNpcId
assert(parsedGuid == wolfGuid, "unit tooltip must pass its GUID to the shared parser")
assert(#unrecordedTip.lines == 2, "expected 2 lines for unrecorded creature, got " .. #unrecordedTip.lines)
assert(unrecordedTip.lines[1].text == "Field Guide" and unrecordedTip.lines[1].kind == "normal", "header line")
assert(
	unrecordedTip.lines[2].text == "Not yet in your journal" and unrecordedTip.lines[2].kind == "disabled",
	"unrecorded line: " .. tostring(unrecordedTip.lines[2].text)
)

-- A nameplate sighting without any kill still counts as not yet recorded in the journal.
local state = ns.GetCharacterState(true)
ns.Model.RecordSighting(state, boar.id, 1000, "Elwynn Forest")
local sightedOnlyTip = MakeTooltip()
hook(sightedOnlyTip, { guid = boarGuid })
assert(
	#sightedOnlyTip.lines == 2 and sightedOnlyTip.lines[2].text == "Not yet in your journal",
	"sighting-only creature"
)

-- 3. Recorded creature with 1 kill (singular) and Discovered rank.
ns.Model.Record(state, wolf.id, { tier = "bronze", time = 1001, zone = "Elwynn Forest" })
local oneKillTip = MakeTooltip()
hook(oneKillTip, { guid = wolfGuid })
assert(#oneKillTip.lines == 2, "expected 2 lines for recorded creature")
assert(oneKillTip.lines[1].text == "Field Guide", "recorded header")
assert(
	oneKillTip.lines[2].text == "Research: Discovered · 1 kill" and oneKillTip.lines[2].kind == "highlight",
	"1 kill line: " .. tostring(oneKillTip.lines[2].text)
)

-- 4. Recorded creature with multiple kills (Studied rank, 6 kills; then Mastered, 12 kills).
for i = 2, 6 do
	ns.Model.Record(state, wolf.id, { tier = "bronze", time = 1000 + i, zone = "Elwynn Forest" })
end
local studiedTip = MakeTooltip()
hook(studiedTip, { guid = wolfGuid })
assert(
	studiedTip.lines[2].text == "Research: Studied · 6 kills",
	"studied line: " .. tostring(studiedTip.lines[2].text)
)

for i = 7, 12 do
	ns.Model.Record(state, wolf.id, { tier = "bronze", time = 1000 + i, zone = "Elwynn Forest" })
end
local masteredTip = MakeTooltip()
hook(masteredTip, { guid = wolfGuid })
assert(
	masteredTip.lines[2].text == "Research: Mastered · 12 kills",
	"mastered line: " .. tostring(masteredTip.lines[2].text)
)

-- 5. Vehicle GUID resolves the same creature.
local vehicleTip = MakeTooltip()
hook(vehicleTip, { guid = vehicleGuid })
assert(#vehicleTip.lines == 2 and vehicleTip.lines[2].text == "Research: Mastered · 12 kills", "vehicle GUID")

-- 6. Fallback to tooltip:GetUnit() + UnitGUID when data lacks guid.
Mock.guids["mouseover"] = wolfGuid
local unitFallbackTip = MakeTooltip({ unitName = wolf.name, unitToken = "mouseover" })
hook(unitFallbackTip, {})
assert(
	#unitFallbackTip.lines == 2 and unitFallbackTip.lines[2].text == "Research: Mastered · 12 kills",
	"GetUnit fallback"
)

-- 7. Players, pets and unknown NPCs get no lines.
for label, guid in pairs({ player = playerGuid, pet = petGuid, unknown = unknownNpcGuid }) do
	local tip = MakeTooltip()
	hook(tip, { guid = guid })
	assert(#tip.lines == 0, label .. " should add no lines, got " .. #tip.lines)
end

-- 8. Secret / unreadable GUID and unit token: no lines and no errors.
local secretGuid = setmetatable({}, {
	__tostring = function()
		error("touched secret guid")
	end,
	__index = function()
		error("indexed secret guid")
	end,
})
local secretToken = setmetatable({}, {
	__tostring = function()
		error("touched secret unit token")
	end,
})
env.canaccessvalue = function(value)
	return value ~= secretGuid and value ~= secretToken
end
local errorsBefore = #(ns.db.errors or {})
local secretDataTip = MakeTooltip({ unitName = "Secret", unitToken = secretToken })
hook(secretDataTip, { guid = secretGuid })
assert(#secretDataTip.lines == 0, "secret guid adds no lines")
assert(#(ns.db.errors or {}) == errorsBefore, "secret guid logs no error")
env.canaccessvalue = nil

-- 9. Forbidden tooltip is never read or drawn on.
local forbiddenTip = MakeTooltip({ forbidden = true, unitToken = "mouseover" })
hook(forbiddenTip, { guid = wolfGuid })
assert(#forbiddenTip.lines == 0 and forbiddenTip.unitLookups == 0, "forbidden tooltip untouched")

-- 10. In combat: adds no lines.
local prevCombat = env.InCombatLockdown
env.InCombatLockdown = function()
	return true
end
local combatTip = MakeTooltip()
hook(combatTip, { guid = wolfGuid })
assert(#combatTip.lines == 0, "in combat adds no lines")
env.InCombatLockdown = prevCombat

-- 11. Settings toggle: defaults on, explains itself via tooltipText, and turning it off hides unit tooltip lines.
local panel = ns.Settings.panel
assert(panel, "settings panel registered")
local toggle
local expectedTip =
	ns.L["Hovering a catalogued creature adds its journal rank, kill count and whether it is recorded yet to its tooltip."]
for _, row in ipairs(panel.settingsRows or {}) do
	local w = row.widget
	if w and w.template == "InterfaceOptionsCheckButtonTemplate" and rawget(w, "tooltipText") == expectedTip then
		toggle = w
		break
	end
end
assert(toggle, "settings toggle checkbox exists with explanatory tooltip")
assert(toggle:GetChecked() == true, "toggle defaults on")
assert(toggle.tooltipText == expectedTip, "toggle explains what it does")

toggle:SetChecked(false)
toggle:GetScript("OnClick")(toggle)
assert(ns.db.options.creatureTooltips == false, "unchecking saves false")
local disabledTip = MakeTooltip()
hook(disabledTip, { guid = wolfGuid })
assert(#disabledTip.lines == 0, "disabled toggle suppresses unit tooltip lines")

toggle:SetChecked(true)
toggle:GetScript("OnClick")(toggle)
assert(ns.db.options.creatureTooltips == true, "rechecking saves true")
local reenabledTip = MakeTooltip()
hook(reenabledTip, { guid = wolfGuid })
assert(#reenabledTip.lines == 2, "reenabled toggle restores unit tooltip lines")

-- 12. Missing character state (e.g. CharacterKey returns nil): adds no lines.
local savedDb = ns.db
ns.db = nil
local noStateTip = MakeTooltip()
hook(noStateTip, { guid = wolfGuid })
assert(#noStateTip.lines == 0, "missing character state adds no lines")
ns.db = savedDb

print("unit_tooltip_spec: 12 checks passed")
