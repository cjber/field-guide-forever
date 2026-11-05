local Mock = dofile("tests/wow_mock.lua")
local harness = Mock.Harness()
local ns = harness.ns

assert(ns.Model.Tier(2000) == "shiny", "the 1-in-1000 band is shiny")
assert(ns.Model.Tier(1100) == "gold", "the 1-in-100 band is gold")
assert(ns.Model.Tier(1025) == "silver", "the 1-in-25 band is silver")
assert(ns.Model.Tier(1001) == "copper", "other ids remain copper")

local original = { 0.8, 0.7, 0.6, 0.9 }
local chrome = Mock.NewRegion("Texture")
chrome:SetVertexColor(unpack(original))
local target = Mock.CreateFrame("Frame")
target.TargetFrameContainer = { FrameTexture = chrome }
target.name = target:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
target.healthbar = Mock.CreateFrame("Frame")
target.manabar = Mock.CreateFrame("Frame")
target.portrait = Mock.NewRegion("Texture")
harness.env.TargetFrame = target
local species = { id = 1025, name = "Silver Test Creature" }
local matchingTier = ns.Model.Tier(species.id)
harness.env.UnitName = function(unit)
	return unit == "target" and species.name or "Tester"
end
ns.CurrentZone = function()
	return { name = "Fixture Zone", species = {} }
end
ns.FindSpecies = function(name)
	return name == species.name and species or nil
end
harness:Fire("ADDON_LOADED", "FieldGuideForever")

Mock.Fire("PLAYER_TARGET_CHANGED")
if matchingTier == "copper" then
	assert(not chrome:IsDesaturated(), "copper leaves the client's chrome untouched")
	local r, g, b, a = chrome:GetVertexColor()
	assert(r == original[1] and g == original[2] and b == original[3] and a == original[4], "copper preserves its tint")
else
	local color = ns.Rarity.COLORS[matchingTier]
	local r, g, b, a = chrome:GetVertexColor()
	assert(chrome:IsDesaturated(), "a rare tier desaturates the client chrome")
	assert(r == color[1] and g == color[2] and b == color[3] and a == 1, "the tier colour is applied to the chrome")
	assert(
		target.FGFRarityMarker:GetAtlas() == "nameplates-icon-elite-silver",
		"a silver mark appears beside a known creature name"
	)
	assert(target.FGFRarityBadge:GetAtlas() == "Rare-Elite-Star", "a star badge marks the target portrait")
	assert(target.FGFRarityBadge:GetWidth() == 26, "the portrait badge is large enough to notice")
	assert(target.FGFRarityRing:IsShown(), "the target portrait carries a tier ring")
	assert(target.FGFRarityRing:GetWidth() == 76, "the portrait ring is bold")
	assert(target.FGFRarityBarGlow.center:IsShown(), "the target bars carry a tier glow")
	assert(target.healthbar.FGFRarityTint:IsShown(), "the health bar background takes the tier tint")
	assert(target.manabar.FGFRarityTint:IsShown(), "the power bar background takes the tier tint")
	assert(target.FGFRarityMarker:GetAlpha() == 1, "a new local sighting briefly highlights its gem")
	harness:RunTimers()
	assert(target.FGFRarityMarker:GetAlpha() == 0.72, "the discovery highlight settles to a quiet accent")
	local ringR, ringG, ringB = target.FGFRarityRing:GetVertexColor()
	assert(ringR == color[1] and ringG == color[2] and ringB == color[3], "the portrait ring receives the tier colour")
	local glowR, glowG, glowB = target.FGFRarityBarGlow.center:GetVertexColor()
	assert(glowR == color[1] and glowG == color[2] and glowB == color[3], "the bar glow receives the tier colour")
	local tintR, tintG, tintB, tintA = target.healthbar.FGFRarityTint:GetVertexColor()
	assert(
		tintR == color[1] and tintG == color[2] and tintB == color[3] and tintA == 0.3,
		"the bar background receives a subtle tier tint"
	)
	local badgeR, badgeG, badgeB = target.FGFRarityBadge:GetVertexColor()
	assert(
		badgeR == color[1] and badgeG == color[2] and badgeB == color[3],
		"the portrait badge receives the tier colour"
	)
end

harness.env.UnitName = function()
	return "Uncatalogued"
end
Mock.Fire("PLAYER_TARGET_CHANGED")
local r, g, b, a = chrome:GetVertexColor()
assert(not chrome:IsDesaturated(), "an uncatalogued target restores the original chrome")
assert(
	r == original[1] and g == original[2] and b == original[3] and a == original[4],
	"original tint and alpha are restored"
)

local trough = Mock.NewRegion("Texture")
trough:SetVertexColor(unpack(original))
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
harness.env.UnitName = function(unit)
	return unit == "nameplate1" and species.name or "Tester"
end
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
local plateR, plateG, plateB = trough:GetVertexColor()
local plateColor = ns.Rarity.COLORS[matchingTier]
assert(trough:IsDesaturated(), "the nameplate trough is desaturated for the creature tier")
assert(
	plateR == plateColor[1] and plateG == plateColor[2] and plateB == plateColor[3],
	"the tier colour is applied to the nameplate trough"
)
assert(
	unitFrame.FGFRarityMarker:GetAtlas() == "nameplates-icon-elite-silver",
	"the nameplate carries the silver tier mark"
)
assert(unitFrame.FGFRarityBorder.top:IsShown(), "the nameplate carries a tier-coloured border")
plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
plateR, plateG, plateB, a = trough:GetVertexColor()
assert(not trough:IsDesaturated(), "removing a pooled nameplate restores the trough")
assert(not unitFrame.FGFRarityMarker:IsShown(), "removing a nameplate clears its tier mark")
assert(not unitFrame.FGFRarityBorder.top:IsShown(), "removing a nameplate clears its tier border")
assert(plateR == original[1] and plateG == original[2] and plateB == original[3] and a == original[4])

-- Blizzard and other addons can repaint pooled textures between our events.
local changed = { 0.2, 0.4, 0.6, 0.5 }
chrome:SetVertexColor(unpack(changed))
Mock.Fire("PLAYER_TARGET_CHANGED")
r, g, b, a = chrome:GetVertexColor()
assert(r == changed[1] and g == changed[2] and b == changed[3] and a == changed[4], "cleanup preserves a later repaint")

plateAttached = true
trough:SetVertexColor(unpack(changed))
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
plateR, plateG, plateB, a = trough:GetVertexColor()
assert(
	plateR == changed[1] and plateG == changed[2] and plateB == changed[3] and a == changed[4],
	"a reused plate restores its current baseline"
)

Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
trough:SetVertexColor(unpack(original))
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
plateR, plateG, plateB, a = trough:GetVertexColor()
assert(
	plateR == original[1] and plateG == original[2] and plateB == original[3] and a == original[4],
	"plate cleanup leaves another writer's tint untouched"
)
assert(not trough:IsDesaturated(), "plate cleanup restores its own saturation after another writer changes the tint")

Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
trough:SetDesaturated(false)
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
plateR, plateG, plateB, a = trough:GetVertexColor()
assert(
	plateR == original[1] and plateG == original[2] and plateB == original[3] and a == original[4],
	"plate cleanup restores its own tint after another writer changes saturation"
)
assert(not trough:IsDesaturated(), "plate cleanup preserves another writer's saturation")

print("rarity: ok")
