local Mock = dofile("tests/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns

local function GuidFor(tier, salt)
	for index = 1, 1000000 do
		local guid = "Creature-0-1-0-1-1001-" .. salt .. string.format("%010X", index)
		if ns.Model.SpawnTier(guid) == tier then
			return guid
		end
	end
	error("no GUID rolls " .. tier)
end

local species = {
	{ id = 1001, name = "Bronze Test Creature" },
	{ id = 1025, name = "Silver Test Creature" },
	{ id = 1100, name = "Gold Test Creature" },
	{ id = 2000, name = "Shiny Test Creature" },
}
local byName = {}
for _, entry in ipairs(species) do
	byName[entry.name] = entry
end
ns.CurrentZone = function()
	return { name = "Fixture Zone", species = species }
end
ns.FindSpecies = function(name)
	return byName[name]
end

local targetHealthColour = { 0.2, 0.6, 0.2, 1 }
local targetNameColour = { 1, 1, 1, 1 }
local chrome = Mock.NewRegion("Texture")
chrome:SetVertexColor(1, 1, 1, 1)
local target = Mock.CreateFrame("Frame")
target.TargetFrameContainer = { FrameTexture = chrome }
target.name = target:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
target.name:SetTextColor(unpack(targetNameColour))
target.healthbar = Mock.CreateFrame("Frame")
target.healthbar:SetStatusBarColor(unpack(targetHealthColour))
target.portrait = Mock.NewRegion("Texture")
harness.env.TargetFrame = target

-- Rarity must only ever add its own glow and tag; the target's health fill and name belong to the client.
local function SpyColour(region, method)
	local calls = 0
	region[method] = function()
		calls = calls + 1
	end
	return function()
		return calls
	end
end

local targetHealthCalls = SpyColour(target.healthbar, "SetStatusBarColor")
local targetNameCalls = SpyColour(target.name, "SetTextColor")

local function AssertTargetColoursUntouched(label)
	assert(targetHealthCalls() == 0, label .. ": the target health bar is never recoloured")
	assert(targetNameCalls() == 0, label .. ": the target name is never recoloured")
	local r, g, b = target.healthbar:GetStatusBarColor()
	assert(
		r == targetHealthColour[1] and g == targetHealthColour[2] and b == targetHealthColour[3],
		label .. ": the target health fill stays the client's"
	)
	r, g, b = target.name:GetTextColor()
	assert(
		r == targetNameColour[1] and g == targetNameColour[2] and b == targetNameColour[3],
		label .. ": the target name colour stays the client's"
	)
end

harness:Fire("ADDON_LOADED", "FieldGuideForever")

local messages = {}
harness.env.print = function(message)
	messages[#messages + 1] = message
end
local slash = harness.env.SlashCmdList["FIELDGUIDEFOREVER"]

-- A creature already seen this session: preview must not change any saved rarity field on it.
local state = ns.GetCharacterState(true)
ns.Model.RecordSighting(state, 1025, 1, "Fixture Zone")
local entry = ns.Model.Specimen(state, 1025)
local before = {}
for key, value in pairs(entry) do
	before[key] = value
end

slash("preview")
assert(ns.RarityPreviewActive(), "the slash command turns the preview on")
assert(#messages == 1, "turning preview on prints one chat line")
assert(messages[1]:find("silver", 1, true), "the chat line names the preview tiers")
assert(messages[1]:find("/fg preview", 1, true), "the chat line says how to turn it off")

Mock.units.target = "Silver Test Creature"
Mock.guids.target = "Creature-0-1-0-1-1025-0000000001"
Mock.Fire("PLAYER_TARGET_CHANGED")
for key, value in pairs(entry) do
	assert(before[key] == value, "preview leaves saved progress alone: " .. key)
end

-- A kill under preview records the spawn's real tier, never the tier the preview shows. Without a GUID that is bronze.
local bronze = byName["Bronze Test Creature"]
local result = ns.RecordKill(bronze.name, bronze.id)
assert(result, "a kill is still recorded while preview is on")
assert(result.tier == "bronze", "a kill without a GUID is bronze even while preview is on")
local bronzeEntry = ns.Model.Specimen(ns.GetCharacterState(false), bronze.id)
assert(bronzeEntry.bronze == 1, "preview writes the real bronze find")
assert(bronzeEntry.silver == 0 and bronzeEntry.gold == 0 and bronzeEntry.shiny == 0, "preview writes no other coat")

-- Cycle silver, gold and shiny across different creatures on the target frame.
slash("preview")
assert(not ns.RarityPreviewActive(), "the slash command turns the preview off")
Mock.units.target = "Silver Test Creature"
Mock.guids.target = "Creature-0-1-0-1-1025-0000000002"
slash("preview")
local silverColour = ns.Rarity.COLORS.silver
AssertTargetColoursUntouched("a silver preview")
assert(target.FGFRarityTag:IsShown() and target.FGFRarityTag.text:GetText() == "SILVER", "silver previews SILVER")
assert(target.FGFRarityBarGlow[1].textures.center:IsShown(), "the preview marks the target bars")
assert(target.FGFRarityPortraitGlow[1].texture:IsShown(), "the preview marks the target portrait")
local auraR, auraG, auraB = target.FGFRarityBarGlow[1].textures.center:GetVertexColor()
assert(
	auraR == silverColour[1] and auraG == silverColour[2] and auraB == silverColour[3],
	"the preview aura takes the silver tier colour"
)

local function targetCreature(name, guid)
	Mock.units.target = name
	Mock.guids.target = guid
	Mock.Fire("PLAYER_TARGET_CHANGED")
end
targetCreature("Gold Test Creature", "Creature-0-1-0-1-1100-0000000001")
AssertTargetColoursUntouched("a gold preview")
assert(target.FGFRarityTag.text:GetText() == "GOLD", "gold previews GOLD")
targetCreature("Shiny Test Creature", "Creature-0-1-0-1-2000-0000000001")
AssertTargetColoursUntouched("a shiny preview")
assert(target.FGFRarityTag.text:GetText() == "SHINY", "shiny previews SHINY")
assert(target.FGFRarityPortraitGlow[1].pulse:IsPlaying(), "a shiny target pulses its portrait aura")

-- Nameplates take the preview tier mark and glow, but never the preview tier's colour on the plate itself.
local plateColour = { 0.64, 0.2, 0.17, 1 }
local plateNameColour = { 1, 1, 1, 1 }
local unitFrame = Mock.CreateFrame("Frame")
unitFrame.name = unitFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
unitFrame.name:SetTextColor(unpack(plateNameColour))
unitFrame.healthBar = Mock.CreateFrame("Frame")
unitFrame.healthBar:SetStatusBarColor(unpack(plateColour))
unitFrame.reactionColor = plateColour
local plateHealthCalls = SpyColour(unitFrame.healthBar, "SetStatusBarColor")
local plateNameCalls = SpyColour(unitFrame.name, "SetTextColor")
local plate = { UnitFrame = unitFrame }
local plateAttached = true
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return plateAttached and plate or nil
	end,
}

local function AssertPlateColoursUntouched(label)
	assert(plateHealthCalls() == 0, label .. ": the nameplate health bar is never recoloured")
	assert(plateNameCalls() == 0, label .. ": the nameplate name is never recoloured")
	local r, g, b = unitFrame.healthBar:GetStatusBarColor()
	assert(r == plateColour[1] and g == plateColour[2] and b == plateColour[3], label .. ": the plate fill stays")
	r, g, b = unitFrame.name:GetTextColor()
	assert(
		r == plateNameColour[1] and g == plateNameColour[2] and b == plateNameColour[3],
		label .. ": the plate name colour stays"
	)
end

Mock.units.nameplate1 = "Bronze Test Creature"
Mock.guids.nameplate1 = GuidFor("bronze", "plate")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
AssertPlateColoursUntouched("a previewed nameplate")
assert(unitFrame.FGFRarityMarker:IsShown(), "a nameplate shows the preview tier mark")
assert(unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "a nameplate shows the preview tier aura")

plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
AssertPlateColoursUntouched("a removed preview nameplate")
assert(not unitFrame.FGFRarityMarker:IsShown(), "removing a nameplate clears its preview mark")
assert(not unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "removing a nameplate clears its aura")

plateAttached = true
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
slash("preview")
assert(not ns.RarityPreviewActive(), "preview turns off again")
AssertPlateColoursUntouched("a bronze nameplate once preview is off")
assert(not unitFrame.FGFRarityMarker:IsShown(), "a bronze nameplate keeps no mark once preview is off")
assert(
	not unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(),
	"a bronze nameplate keeps no aura once preview is off"
)

print("rarity preview: ok")
