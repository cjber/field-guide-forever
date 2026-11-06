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
local targetContainer = Mock.CreateFrame("Frame")
local chrome = targetContainer:CreateTexture(nil, "BACKGROUND")
chrome:SetSize(192, 67)
chrome:SetPoint("CENTER", targetContainer, "CENTER")
chrome:SetVertexColor(1, 1, 1, 1)
targetContainer.Portrait = Mock.NewRegion("Texture")
local target = Mock.CreateFrame("Frame")
target.TargetFrameContainer = targetContainer
targetContainer.FrameTexture = chrome
target.name = target:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
target.name:SetTextColor(unpack(targetNameColour))
target.healthbar = Mock.CreateFrame("Frame")
target.healthbar:SetStatusBarColor(unpack(targetHealthColour))
target.portrait = Mock.NewRegion("Texture")
harness.env.TargetFrame = target

-- Rarity must only ever add its own icon and tag; the target's health fill and name belong to the client.
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
local RARE_FRAME = "UI-HUD-UnitFrame-Target-Rare-PortraitOn"
local LAUREL_SILVER = "Interface\\AddOns\\FieldGuideForever\\media\\Rarity\\Laurel-Silver.tga"
local LAUREL_GOLD = "Interface\\AddOns\\FieldGuideForever\\media\\Rarity\\Laurel-Gold.tga"
local LAUREL_SHINY = "Interface\\AddOns\\FieldGuideForever\\media\\Rarity\\Laurel-Shiny.tga"
AssertTargetColoursUntouched("a silver preview")
assert(
	target.FGFRarityTag:IsShown() and target.FGFRarityTag.text:GetText():find("SILVER", 1, true),
	"silver previews its size and SILVER"
)
local previewArt = target.FGFRarityArt
local function PreviewFrameShown()
	return previewArt.bar:IsShown() and previewArt.ring:IsShown()
end
assert(
	PreviewFrameShown() and previewArt.bar:GetAtlas() == RARE_FRAME and previewArt.ring:GetAtlas() == RARE_FRAME,
	"the preview draws both pieces of the game's silver rare frame"
)
assert(
	previewArt.bar.atlasUseSize and previewArt.ring.atlasUseSize,
	"the preview rare frame keeps the atlas's own size"
)
assert(
	previewArt.ornament:IsShown() and previewArt.ornament._texture == LAUREL_SILVER,
	"a silver preview draws the silver laurel"
)
for _, piece in ipairs({ previewArt.bar, previewArt.ring }) do
	local previewR, previewG, previewB = piece:GetVertexColor()
	assert(
		not piece:IsDesaturated() and previewR == 1 and previewG == 1 and previewB == 1,
		"a silver preview keeps the silver art's own colour"
	)
end

local function targetCreature(name, guid)
	Mock.units.target = name
	Mock.guids.target = guid
	Mock.Fire("PLAYER_TARGET_CHANGED")
end
targetCreature("Gold Test Creature", "Creature-0-1-0-1-1100-0000000001")
AssertTargetColoursUntouched("a gold preview")
assert(target.FGFRarityTag.text:GetText():find("GOLD", 1, true), "gold previews its size and GOLD")
assert(not PreviewFrameShown(), "a gold preview adds no rare frame")
assert(
	previewArt.ornament:IsShown() and previewArt.ornament._texture == LAUREL_GOLD,
	"a gold preview draws the gold laurel"
)
assert(not previewArt.anim:IsPlaying(), "a gold preview does not animate")
targetCreature("Shiny Test Creature", "Creature-0-1-0-1-2000-0000000001")
AssertTargetColoursUntouched("a shiny preview")
assert(target.FGFRarityTag.text:GetText():find("SHINY", 1, true), "shiny previews its size and SHINY")
assert(PreviewFrameShown(), "a shiny preview keeps the silver rare frame")
assert(
	previewArt.ornament:IsShown() and previewArt.ornament._texture == LAUREL_SHINY,
	"a shiny preview draws the shiny laurel"
)
assert(previewArt.ornamentMask._texture == LAUREL_SHINY, "the shiny laurel's sheen mask follows the same art")
assert(previewArt.anim:IsPlaying(), "a shiny preview runs the sheen")

-- Nameplates take the preview tier mark, but never the preview tier's colour on the plate itself.
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
local markPoint, markRelative, markRelativePoint = unitFrame.FGFRarityMarker:GetPoint(1)
assert(
	markPoint == "LEFT" and markRelative == unitFrame.healthBar and markRelativePoint == "RIGHT",
	"the nameplate mark sits to the right of the health bar"
)

plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
AssertPlateColoursUntouched("a removed preview nameplate")
assert(not unitFrame.FGFRarityMarker:IsShown(), "removing a nameplate clears its preview mark")

plateAttached = true
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
slash("preview")
assert(not ns.RarityPreviewActive(), "preview turns off again")
AssertPlateColoursUntouched("a bronze nameplate once preview is off")
assert(not unitFrame.FGFRarityMarker:IsShown(), "a bronze nameplate keeps no mark once preview is off")

-- A friendly NPC has no spawn tier, so preview skips it and does not spend one of the three rotation tiers on it.
local friendlyUnits = { target = true, nameplate3 = true }
harness.env.UnitCanAttack = function(_, unit)
	return not friendlyUnits[unit]
end
plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
targetCreature("Silver Test Creature", GuidFor("silver", "friendly-preview-target"))
slash("preview")
assert(ns.RarityPreviewActive(), "preview turns on for the friendly checks")
assert(not PreviewFrameShown(), "a friendly preview target shows no rare frame")
assert(not previewArt.ornament:IsShown(), "a friendly preview target shows no ornament")
assert(not previewArt.anim:IsPlaying(), "a friendly preview target starts no sheen")
local friendlyTag = target.FGFRarityTag:IsShown() and target.FGFRarityTag.text:GetText() or ""
for _, tier in ipairs({ "SILVER", "GOLD", "SHINY" }) do
	assert(not friendlyTag:find(tier, 1, true), "a friendly preview target shows no " .. tier .. " tag")
end

friendlyUnits.target = false
targetCreature("Gold Test Creature", GuidFor("bronze", "preview-after-friendly-target"))
assert(
	target.FGFRarityTag.text:GetText():find("SILVER", 1, true),
	"a friendly target does not consume the first preview tier"
)
assert(PreviewFrameShown(), "the next attackable creature takes the first preview tier")

plateAttached = true
harness.env.UnitName = function(unit)
	return unit == "nameplate3" and "Shiny Test Creature" or "Tester"
end
Mock.guids.nameplate3 = GuidFor("gold", "friendly-preview-plate")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert(not unitFrame.FGFRarityMarker:IsShown(), "a friendly preview nameplate shows no tier mark")

friendlyUnits.nameplate3 = false
harness.env.UnitName = function(unit)
	return unit == "nameplate4" and "Gold Test Creature" or "Tester"
end
Mock.guids.nameplate4 = GuidFor("bronze", "preview-after-friendly-plate")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
assert(unitFrame.FGFRarityMarker:IsShown(), "an attackable preview plate shows its tier mark")
assert(
	unitFrame.FGFRarityMarker:GetAtlas() == ns.Art.TIER_ICONS.gold,
	"a friendly nameplate does not consume a preview tier"
)

print("rarity preview: ok")
