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
target.healthbar = Mock.CreateFrame("Frame")
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
local seen = { [target.FGFRarityMarker:GetAtlas()] = true }
assert(target.FGFRarityMarker:IsShown(), "the preview marks the target")
assert(target.FGFRarityRing:IsShown() and target.FGFRarityBadge:IsShown(), "the preview marks the target portrait")
assert(target.FGFRarityBarGlow.center:IsShown(), "the preview marks the target bars")

local function targetCreature(name, guid)
	Mock.units.target = name
	Mock.guids.target = guid
	Mock.Fire("PLAYER_TARGET_CHANGED")
	seen[target.FGFRarityMarker:GetAtlas()] = true
end
targetCreature("Gold Test Creature", "Creature-0-1-0-1-1100-0000000001")
assert(target.FGFRarityMarker:GetAtlas() == "nameplates-icon-elite-gold", "the gold preview tier uses the gold mark")
targetCreature("Shiny Test Creature", "Creature-0-1-0-1-2000-0000000001")
assert(target.FGFRarityMarker:GetAtlas() == "Rare-Elite-Star", "the shiny preview tier uses the star")
assert(target.FGFRarityRing.FGFRarityPulse:IsPlaying(), "a shiny target pulses its portrait ring")
assert(seen["nameplates-icon-elite-silver"], "silver appears in the preview rotation")
assert(seen["nameplates-icon-elite-gold"], "gold appears in the preview rotation")
assert(seen["Rare-Elite-Star"], "shiny appears in the preview rotation")

-- Nameplates take the preview tier and give it back on removal and when preview turns off.
local trough = Mock.NewRegion("Texture")
trough:SetVertexColor(1, 1, 1, 1)
local unitFrame = Mock.CreateFrame("Frame")
unitFrame.name = unitFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
unitFrame.healthBar = Mock.CreateFrame("Frame")
unitFrame.healthBar.bgTexture = trough
unitFrame.healthBar.background, unitFrame.healthBar.Background = false, false
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
assert(unitFrame.FGFRarityBorder.top:IsShown(), "a nameplate shows the preview tier border")
assert(trough:IsDesaturated(), "a nameplate takes the preview tier colour")

plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(not unitFrame.FGFRarityMarker:IsShown(), "removing a nameplate clears its preview mark")
assert(not unitFrame.FGFRarityBorder.top:IsShown(), "removing a nameplate clears its preview border")
assert(not trough:IsDesaturated(), "removing a nameplate restores its trough")

plateAttached = true
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
slash("preview")
assert(not ns.RarityPreviewActive(), "preview turns off again")
assert(not unitFrame.FGFRarityMarker:IsShown(), "a copper nameplate keeps no mark once preview is off")
assert(not unitFrame.FGFRarityBorder.top:IsShown(), "a copper nameplate keeps no border once preview is off")
assert(not trough:IsDesaturated(), "a copper nameplate keeps the client trough once preview is off")

print("rarity preview: ok")
