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
harness.env.TargetFrame = { TargetFrameContainer = { FrameTexture = chrome } }
local species = { id = 1025, name = "Silver Test Creature" }
local matchingTier = ns.Model.Tier(species.id)
harness.env.UnitName = function(unit)
	return unit == "target" and species.name or "Tester"
end
ns.CurrentZone = function()
	return ns.Creatures.zones[1]
end
ns.FindSpecies = function(name)
	return name == species.name and species or nil
end

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
local plate = { UnitFrame = { healthBar = { background = trough } } }
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
plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
plateR, plateG, plateB, a = trough:GetVertexColor()
assert(not trough:IsDesaturated(), "removing a pooled nameplate restores the trough")
assert(plateR == original[1] and plateG == original[2] and plateB == original[3] and a == original[4])

print("rarity: ok")
