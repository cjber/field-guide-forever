local Mock = dofile("tests/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns

---@param tier string
---@param salt string
---@return string
local function GuidFor(tier, salt)
	for index = 1, 1000000 do
		local guid = "Creature-0-1-0-1-1001-" .. salt .. string.format("%010X", index)
		if ns.Model.SpawnTier(guid) == tier then
			return guid
		end
	end
	error("no GUID rolls " .. tier)
end
assert(ns.Model.SpawnTier(GuidFor("shiny", "a")) == "shiny", "a spawn GUID can be shiny")
assert(ns.Model.SpawnTier(GuidFor("gold", "b")) == "gold", "a spawn GUID can be gold")
assert(ns.Model.SpawnTier(GuidFor("silver", "c")) == "silver", "a spawn GUID can be silver")
assert(ns.Model.SpawnTier(nil) == "bronze", "no readable GUID stays bronze")

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

-- Every colour setter the client could recolour a bar or name with is watched. Rarity must never call one, whether the
-- unit is tiered, untiered or the plate has just been recycled.
local function SpyColour(region, method)
	local calls = 0
	region[method] = function()
		calls = calls + 1
	end
	return function()
		return calls
	end
end

local healthBarCalls = SpyColour(target.healthbar, "SetStatusBarColor")
local powerBarCalls = SpyColour(target.manabar, "SetStatusBarColor")
local nameCalls = SpyColour(target.name, "SetTextColor")

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
Mock.guids.target = GuidFor("silver", "t")
harness:Fire("ADDON_LOADED", "FieldGuideForever")

local function AssertColour(region, expected, label)
	local r, g, b = region:GetStatusBarColor()
	assert(r == expected[1] and g == expected[2] and b == expected[3], label)
end

local function AssertTextColour(font, expected, label)
	local r, g, b = font:GetTextColor()
	assert(r == expected[1] and g == expected[2] and b == expected[3], label)
end

local function AssertTargetColoursUntouched(label)
	assert(healthBarCalls() == 0, label .. ": the target health bar is never recoloured")
	assert(powerBarCalls() == 0, label .. ": the target power bar is never recoloured")
	assert(nameCalls() == 0, label .. ": the target name is never recoloured")
	AssertColour(target.healthbar, healthColour, label .. ": the health fill stays the client's")
	AssertColour(target.manabar, powerColour, label .. ": the power fill stays the client's")
	AssertTextColour(target.name, nameColour, label .. ": the name colour stays the client's")
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
AssertTargetColoursUntouched("a silver target")
assert(target.FGFRarityTag:IsShown(), "a tier tag sits above the target name")
assert(target.FGFRarityTag.text:GetText() == "SILVER", "silver reads SILVER")
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
Mock.guids.target = GuidFor("gold", "t")
Mock.Fire("PLAYER_TARGET_CHANGED")
local goldColour = ns.Rarity.COLORS.gold
AssertTargetColoursUntouched("a gold target")
assert(target.FGFRarityTag.text:GetText() == "GOLD", "gold reads GOLD")
local goldTagR, goldTagG, goldTagB = target.FGFRarityTag.plate:GetVertexColor()
assert(
	goldTagR == goldColour[1] and goldTagG == goldColour[2] and goldTagB == goldColour[3],
	"the tag plate follows a tier change"
)

harness.env.UnitName = function()
	return "Uncatalogued"
end
Mock.guids.target = GuidFor("bronze", "t")
Mock.Fire("PLAYER_TARGET_CHANGED")
AssertTargetColoursUntouched("a bronze target")
assert(not target.FGFRarityTag:IsShown(), "a bronze target hides the tag")
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
Mock.guids.target = GuidFor("shiny", "t")
Mock.Fire("PLAYER_TARGET_CHANGED")
AssertTargetColoursUntouched("a target change in combat")
assert(not target.FGFRarityTag:IsShown(), "combat leaves the tag untouched")
harness.env.InCombatLockdown = function()
	return false
end
Mock.Fire("PLAYER_REGEN_ENABLED")
AssertTargetColoursUntouched("a target change after combat")
assert(target.FGFRarityTag:IsShown(), "the shiny tag applies after combat")
assert(target.FGFRarityTag.text:GetText() == "SHINY", "shiny reads SHINY")
assert(target.FGFRarityBarGlow[1].textures.center:IsShown(), "the shiny bar aura applies after combat")
assert(target.FGFRarityPortraitGlow[1].texture:IsShown(), "the shiny portrait aura applies after combat")

-- A nameplate is recycled between units, so a tier is marked by the glow and tag only and never by the plate's own
-- health colour or name.
local plateReaction = { 0.64, 0.2, 0.17, 1 }
local unitFrame = Mock.CreateFrame("Frame")
unitFrame.name = unitFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
unitFrame.name:SetTextColor(unpack(plateReaction))
unitFrame.healthBar = Mock.CreateFrame("Frame")
unitFrame.healthBar:SetStatusBarColor(unpack(plateReaction))
unitFrame.reactionColor = plateReaction
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
	AssertColour(unitFrame.healthBar, plateReaction, label .. ": the plate fill stays the client's")
	AssertTextColour(unitFrame.name, plateReaction, label .. ": the plate name colour stays the client's")
end

harness.env.UnitName = function(unit)
	return unit == "nameplate1" and silver.name or "Tester"
end
Mock.guids.nameplate1 = GuidFor("silver", "p")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
AssertPlateColoursUntouched("a tiered nameplate")
assert(
	unitFrame.FGFRarityMarker:GetAtlas() == "Professions-Icon-Quality-Tier2",
	"the nameplate carries the silver mark"
)
assert(unitFrame.FGFRarityMarker:IsShown(), "a tiered nameplate shows its tag")
assert(unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "the nameplate carries a soft tier aura")

harness.env.UnitName = function(unit)
	return unit == "nameplate1" and gold.name or "Tester"
end
Mock.guids.nameplate1 = GuidFor("gold", "p")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
AssertPlateColoursUntouched("a nameplate after a tier change")
assert(
	unitFrame.FGFRarityMarker:GetAtlas() == "Professions-Icon-Quality-Tier3",
	"the nameplate mark follows a tier change"
)

plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
AssertPlateColoursUntouched("a removed nameplate")
assert(not unitFrame.FGFRarityMarker:IsShown(), "removing a nameplate clears its tag")
assert(not unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "removing a nameplate clears its aura")

-- The reported bug: a plate first used by a hostile unit, removed, then reused for a friendly untiered unit. It must
-- still show no tier and Field Guide must leave the new unit's reaction colour alone.
local friendlyReaction = { 0.2, 0.7, 0.2, 1 }
unitFrame.reactionColor = friendlyReaction
plateAttached = true
harness.env.UnitName = function()
	return "Sentinel Kyra Starsong"
end
Mock.guids.nameplate1 = GuidFor("bronze", "p")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
AssertPlateColoursUntouched("a recycled untiered nameplate")
assert(not unitFrame.FGFRarityMarker:IsShown(), "an untiered nameplate shows no tag")
assert(not unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "an untiered nameplate shows no aura")

-- A tiered unit still marks the recycled plate, again without touching its colours.
harness.env.UnitName = function(unit)
	return unit == "nameplate1" and shiny.name or "Tester"
end
Mock.guids.nameplate1 = GuidFor("shiny", "p")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
AssertPlateColoursUntouched("a tiered unit on a recycled nameplate")
assert(unitFrame.FGFRarityMarker:IsShown(), "a tiered unit shows its tag on a recycled plate")
assert(
	unitFrame.FGFRarityMarker:GetAtlas() == "Professions-Icon-Quality-Tier4",
	"a shiny nameplate mark is the fourth quality mark"
)
assert(unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "a tiered unit shows its aura on a recycled plate")
plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
AssertPlateColoursUntouched("a recycled nameplate removed again")
assert(not unitFrame.FGFRarityMarker:IsShown(), "clearing a tiered nameplate hides its tag")
assert(not unitFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "clearing a tiered nameplate hides its aura")

-- A plate the addon first sees with no tier keeps the client's own colours and shows no mark.
local freshFrame = Mock.CreateFrame("Frame")
freshFrame.name = freshFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
freshFrame.name:SetTextColor(unpack(friendlyReaction))
freshFrame.healthBar = Mock.CreateFrame("Frame")
freshFrame.healthBar:SetStatusBarColor(unpack(friendlyReaction))
freshFrame.reactionColor = friendlyReaction
local freshHealthCalls = SpyColour(freshFrame.healthBar, "SetStatusBarColor")
local freshNameCalls = SpyColour(freshFrame.name, "SetTextColor")
local freshPlate = { UnitFrame = freshFrame }
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return freshPlate
	end,
}
harness.env.UnitName = function()
	return "Sentinel Kyra Starsong"
end
Mock.guids.nameplate2 = GuidFor("bronze", "q")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(freshHealthCalls() == 0, "an untiered plate is never given a health colour")
assert(freshNameCalls() == 0, "an untiered plate is never given a name colour")
AssertColour(freshFrame.healthBar, friendlyReaction, "an untiered plate keeps the client's health colour")
AssertTextColour(freshFrame.name, friendlyReaction, "an untiered plate keeps the client's name colour")
assert(not freshFrame.FGFRarityMarker:IsShown(), "an untiered plate shows no tier mark")
assert(not freshFrame.FGFRarityBarGlow[1].textures.center:IsShown(), "an untiered plate shows no aura")

print("rarity: ok")
