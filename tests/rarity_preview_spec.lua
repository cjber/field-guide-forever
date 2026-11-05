local Mock = dofile("tests/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns

local species = {
	{ id = 1001, name = "Copper Test Creature" },
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

local chrome = Mock.NewRegion("Texture")
chrome:SetVertexColor(1, 1, 1, 1)
local target = Mock.CreateFrame("Frame")
target.TargetFrameContainer = { FrameTexture = chrome }
target.name = target:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
target.name:SetTextColor(1, 1, 1, 1)
target.healthbar = Mock.CreateFrame("Frame")
target.healthbar:SetStatusBarColor(0.2, 0.6, 0.2, 1)
target.portrait = Mock.NewRegion("Texture")
harness.env.TargetFrame = target

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

-- A kill under preview records the species' real rarity, never the tier the preview shows.
ns.Model.SetRandom(function()
	return ns.Model.SHINY_CHANCE
end)
local copper = byName["Copper Test Creature"]
local result = ns.RecordKill(copper.name, copper.id)
assert(result, "a kill is still recorded while preview is on")
assert(result.rare == false and result.shiny == false, "preview does not make a kill rare or shiny")
local copperEntry = ns.Model.Specimen(ns.GetCharacterState(false), copper.id)
assert(copperEntry.rare == 0 and copperEntry.rareKills == 0, "preview writes no rare progress")
assert(copperEntry.shiny == 0 and copperEntry.shinyFinds == 0, "preview writes no shiny progress")

-- Cycle silver, gold and shiny across different creatures on the target frame.
slash("preview")
assert(not ns.RarityPreviewActive(), "the slash command turns the preview off")
Mock.units.target = "Silver Test Creature"
Mock.guids.target = "Creature-0-1-0-1-1025-0000000002"
slash("preview")
local silverColour = ns.Rarity.COLORS.silver
local goldColour = ns.Rarity.COLORS.gold
local shinyColour = ns.Rarity.COLORS.shiny
local function AssertBar(colour, label)
	local r, g, b = target.healthbar:GetStatusBarColor()
	assert(r == colour[1] and g == colour[2] and b == colour[3], label)
end
AssertBar(silverColour, "the preview paints the target health bar silver")
assert(target.FGFRarityTag:IsShown() and target.FGFRarityTag.text:GetText() == "RARE", "silver previews RARE")
assert(target.FGFRarityBarGlow[1].textures.center:IsShown(), "the preview marks the target bars")
assert(target.FGFRarityPortraitGlow[1].texture:IsShown(), "the preview marks the target portrait")

local function targetCreature(name, guid)
	Mock.units.target = name
	Mock.guids.target = guid
	Mock.Fire("PLAYER_TARGET_CHANGED")
end
targetCreature("Gold Test Creature", "Creature-0-1-0-1-1100-0000000001")
AssertBar(goldColour, "the preview paints the target health bar gold")
assert(target.FGFRarityTag.text:GetText() == "RARE", "gold previews RARE")
targetCreature("Shiny Test Creature", "Creature-0-1-0-1-2000-0000000001")
AssertBar(shinyColour, "the preview paints the target health bar cyan")
assert(target.FGFRarityTag.text:GetText() == "SHINY", "shiny previews SHINY")
assert(target.FGFRarityPortraitGlow[1].pulse:IsPlaying(), "a shiny target pulses its portrait aura")

-- Nameplates take the preview tier and give it back on removal and when preview turns off.
local plateColour = { 0.64, 0.2, 0.17, 1 }
local plateNameColour = { 1, 1, 1, 1 }
local unitFrame = Mock.CreateFrame("Frame")
unitFrame.name = unitFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
unitFrame.name:SetTextColor(unpack(plateNameColour))
unitFrame.healthBar = Mock.CreateFrame("Frame")
unitFrame.healthBar:SetStatusBarColor(unpack(plateColour))
local plate = { UnitFrame = unitFrame }
local plateAttached = true
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return plateAttached and plate or nil
	end,
}
Mock.units.nameplate1 = "Copper Test Creature"
Mock.guids.nameplate1 = "Creature-0-1-0-1-1001-0000000001"
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(unitFrame.FGFRarityMarker:IsShown(), "a nameplate shows the preview tier mark")
assert(unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "a nameplate shows the preview tier aura")
local previewR, previewG, previewB = unitFrame.healthBar:GetStatusBarColor()
assert(
	previewR ~= plateColour[1] or previewG ~= plateColour[2] or previewB ~= plateColour[3],
	"a nameplate fill takes the preview tier colour"
)

plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
local restoredR, restoredG, restoredB = unitFrame.healthBar:GetStatusBarColor()
assert(
	restoredR == plateColour[1] and restoredG == plateColour[2] and restoredB == plateColour[3],
	"removing a nameplate restores its fill"
)
assert(not unitFrame.FGFRarityMarker:IsShown(), "removing a nameplate clears its preview mark")
assert(not unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "removing a nameplate clears its aura")

plateAttached = true
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
slash("preview")
assert(not ns.RarityPreviewActive(), "preview turns off again")
local offR, offG, offB = unitFrame.healthBar:GetStatusBarColor()
assert(
	offR == plateColour[1] and offG == plateColour[2] and offB == plateColour[3],
	"a copper nameplate keeps the client fill once preview is off"
)
assert(not unitFrame.FGFRarityMarker:IsShown(), "a copper nameplate keeps no mark once preview is off")
assert(
	not unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(),
	"a copper nameplate keeps no aura once preview is off"
)

print("rarity preview: ok")
