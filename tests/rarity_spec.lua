local Mock = dofile("tests/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns

assert(ns.Model.Tier(2000) == "shiny", "the 1-in-1000 band is shiny")
assert(ns.Model.Tier(1100) == "gold", "the 1-in-100 band is gold")
assert(ns.Model.Tier(1025) == "silver", "the 1-in-25 band is silver")
assert(ns.Model.Tier(1001) == "copper", "other ids remain copper")

local chromeColour = { 0.8, 0.7, 0.6, 0.9 }
local healthColour = { 0.2, 0.6, 0.2, 1 }
local powerColour = { 0.1, 0.2, 0.8, 1 }
local nameColour = { 1, 0.9, 0.8, 1 }
local chrome = Mock.NewRegion("Texture")
chrome:SetVertexColor(unpack(chromeColour))
local target = Mock.CreateFrame("Frame")
target.TargetFrameContainer = { FrameTexture = chrome }
target.name = target:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
target.name:SetTextColor(unpack(nameColour))
target.healthbar = Mock.CreateFrame("Frame")
target.healthbar:SetStatusBarColor(unpack(healthColour))
target.manabar = Mock.CreateFrame("Frame")
target.manabar:SetStatusBarColor(unpack(powerColour))
target.portrait = Mock.NewRegion("Texture")
harness.env.TargetFrame = target

local silver = { id = 1025, name = "Silver Test Creature" }
local gold = { id = 1100, name = "Gold Test Creature" }
local shiny = { id = 2000, name = "Shiny Test Creature" }
local byName = { [silver.name] = silver, [gold.name] = gold, [shiny.name] = shiny }
ns.CurrentZone = function()
	return { name = "Fixture Zone", species = {} }
end
ns.FindSpecies = function(name)
	return byName[name]
end
harness.env.UnitName = function(unit)
	return unit == "target" and silver.name or "Tester"
end
harness:Fire("ADDON_LOADED", "FieldGuideForever")

local function AssertBarColour(bar, expected, label)
	local r, g, b = bar:GetStatusBarColor()
	assert(r == expected[1] and g == expected[2] and b == expected[3], label)
end

local function AssertTextColour(font, expected, label)
	local r, g, b = font:GetTextColor()
	assert(r == expected[1] and g == expected[2] and b == expected[3], label)
end

Mock.Fire("PLAYER_TARGET_CHANGED")
local silverColour = ns.Rarity.COLORS.silver
local chromeR, chromeG, chromeB, chromeA = chrome:GetVertexColor()
assert(not chrome:IsDesaturated(), "a rare tier leaves the client chrome untouched")
assert(
	chromeR == chromeColour[1]
		and chromeG == chromeColour[2]
		and chromeB == chromeColour[3]
		and chromeA == chromeColour[4],
	"the original chrome tint survives"
)
AssertBarColour(target.healthbar, silverColour, "the health bar fill takes the tier colour")
AssertBarColour(target.manabar, powerColour, "the power bar keeps its client fill")
AssertTextColour(target.name, silverColour, "the target name takes the tier colour")
assert(target.FGFRarityTag:IsShown(), "a tier tag sits above the target name")
assert(target.FGFRarityTag.text:GetText() == "RARE", "silver reads RARE")
local tagR, tagG, tagB = target.FGFRarityTag.plate:GetVertexColor()
assert(
	tagR == silverColour[1] and tagG == silverColour[2] and tagB == silverColour[3],
	"the tag plate takes the tier colour"
)
assert(target.FGFRarityBarGlow[1].textures.center:IsShown(), "the target bars carry a soft tier aura")
assert(target.FGFRarityPortraitGlow[1].texture:IsShown(), "the portrait carries a soft tier aura")
local auraR, auraG, auraB = target.FGFRarityBarGlow[1].textures.center:GetVertexColor()
assert(
	auraR == silverColour[1] and auraG == silverColour[2] and auraB == silverColour[3],
	"the bar aura takes the tier colour"
)
local portraitR, portraitG, portraitB = target.FGFRarityPortraitGlow[1].texture:GetVertexColor()
assert(
	portraitR == silverColour[1] and portraitG == silverColour[2] and portraitB == silverColour[3],
	"the portrait aura takes the tier colour"
)

harness.env.UnitName = function(unit)
	return unit == "target" and gold.name or "Tester"
end
Mock.Fire("PLAYER_TARGET_CHANGED")
local goldColour = ns.Rarity.COLORS.gold
AssertBarColour(target.healthbar, goldColour, "the health bar follows a tier change")
AssertTextColour(target.name, goldColour, "the name follows a tier change")
assert(target.FGFRarityTag.text:GetText() == "RARE", "gold reads RARE")
local goldTagR, goldTagG, goldTagB = target.FGFRarityTag.plate:GetVertexColor()
assert(
	goldTagR == goldColour[1] and goldTagG == goldColour[2] and goldTagB == goldColour[3],
	"the tag plate follows a tier change"
)

harness.env.UnitName = function()
	return "Uncatalogued"
end
Mock.Fire("PLAYER_TARGET_CHANGED")
AssertBarColour(target.healthbar, healthColour, "an uncatalogued target restores the health fill")
AssertTextColour(target.name, nameColour, "an uncatalogued target restores the name colour")
assert(not target.FGFRarityTag:IsShown(), "an uncatalogued target hides the tag")
assert(not target.FGFRarityBarGlow[1].textures.center:IsShown(), "an uncatalogued target hides the bar aura")
assert(not target.FGFRarityPortraitGlow[1].texture:IsShown(), "an uncatalogued target hides the portrait aura")
chromeR, chromeG, chromeB, chromeA = chrome:GetVertexColor()
assert(not chrome:IsDesaturated(), "the chrome stays untouched after cleanup")
assert(
	chromeR == chromeColour[1]
		and chromeG == chromeColour[2]
		and chromeB == chromeColour[3]
		and chromeA == chromeColour[4],
	"the chrome tint is unchanged after cleanup"
)

-- The target frame is protected: the update waits until combat ends instead of touching it in combat.
harness.env.InCombatLockdown = function()
	return true
end
harness.env.UnitName = function(unit)
	return unit == "target" and shiny.name or "Tester"
end
Mock.Fire("PLAYER_TARGET_CHANGED")
AssertBarColour(target.healthbar, healthColour, "combat leaves the health fill untouched")
assert(not target.FGFRarityTag:IsShown(), "combat leaves the tag untouched")
harness.env.InCombatLockdown = function()
	return false
end
Mock.Fire("PLAYER_REGEN_ENABLED")
local shinyColour = ns.Rarity.COLORS.shiny
AssertBarColour(target.healthbar, shinyColour, "the shiny fill applies after combat")
assert(target.FGFRarityTag.text:GetText() == "SHINY", "shiny reads SHINY")

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
harness.env.UnitName = function(unit)
	return unit == "nameplate1" and silver.name or "Tester"
end
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
AssertBarColour(unitFrame.healthBar, silverColour, "the nameplate fill takes the tier colour")
AssertTextColour(unitFrame.name, silverColour, "the nameplate name takes the tier colour")
assert(
	unitFrame.FGFRarityMarker:GetAtlas() == "nameplates-icon-elite-silver",
	"the nameplate carries the silver tier mark"
)
assert(unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "the nameplate carries a soft tier aura")

harness.env.UnitName = function(unit)
	return unit == "nameplate1" and gold.name or "Tester"
end
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
AssertBarColour(unitFrame.healthBar, goldColour, "the nameplate fill follows a tier change")
AssertTextColour(unitFrame.name, goldColour, "the nameplate name follows a tier change")
assert(unitFrame.FGFRarityMarker:GetAtlas() == "nameplates-icon-elite-gold", "the nameplate mark follows a tier change")

plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
AssertBarColour(unitFrame.healthBar, plateColour, "removing a nameplate restores its fill")
AssertTextColour(unitFrame.name, plateNameColour, "removing a nameplate restores its name colour")
assert(not unitFrame.FGFRarityMarker:IsShown(), "removing a nameplate clears its tier mark")
assert(not unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "removing a nameplate clears its aura")

-- A pooled plate comes back with a new client baseline; the next restore uses that, not the old creature's.
local nextPlateColour = { 0.2, 0.3, 0.4, 1 }
local nextPlateNameColour = { 0.5, 0.6, 0.7, 1 }
unitFrame.healthBar:SetStatusBarColor(unpack(nextPlateColour))
unitFrame.name:SetTextColor(unpack(nextPlateNameColour))
plateAttached = true
harness.env.UnitName = function(unit)
	return unit == "nameplate1" and silver.name or "Tester"
end
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
AssertBarColour(unitFrame.healthBar, nextPlateColour, "a reused nameplate restores its new fill baseline")
AssertTextColour(unitFrame.name, nextPlateNameColour, "a reused nameplate restores its new name colour")

print("rarity: ok")
