---@type string, FGNamespace
local _, ns = ...

---@class FGRarity
local Rarity = {}
ns.Rarity = Rarity

Rarity.COLORS = {
	silver = { 0.79, 0.83, 0.88 },
	gold = { 0.91, 0.74, 0.39 },
	shiny = { 0.58, 0.83, 1 },
}

---@type table<table, { desaturated: boolean, r: number, g: number, b: number, a: number }>
local originals = {}
---@type table<string, table>
local platesByUnit = {}

---@param texture table?
local function Restore(texture)
	local original = texture and originals[texture]
	if not original then
		return
	end
	texture:SetDesaturated(original.desaturated)
	texture:SetVertexColor(original.r, original.g, original.b, original.a)
end

---@param texture table?
---@param tier string
local function Paint(texture, tier)
	if not texture or not texture.GetVertexColor then
		return
	end
	if not originals[texture] then
		local r, g, b, a = texture:GetVertexColor()
		originals[texture] = {
			desaturated = texture.IsDesaturated and texture:IsDesaturated() or false,
			r = r or 1,
			g = g or 1,
			b = b or 1,
			a = a or 1,
		}
	end
	Restore(texture)
	local color = Rarity.COLORS[tier]
	if color then
		texture:SetDesaturated(true)
		texture:SetVertexColor(color[1], color[2], color[3], 1)
	end
end

---@param species FGSpecies?
---@return string
local function SpeciesTier(species)
	return species and ns.Model.Tier(species.id) or "copper"
end

local function TargetChrome()
	local target = _G.TargetFrame
	local container = target and target.TargetFrameContainer
	return (container and container.FrameTexture) or (target and target.TargetFrameTextureFrameTexture)
end

local function UpdateTarget()
	local zone = ns.CurrentZone()
	local name = UnitName and UnitName("target") or nil
	local species = ns.FindSpecies(name, zone)
	Paint(TargetChrome(), SpeciesTier(species))
end

---@param plate table
---@param unit string
local function UpdatePlate(plate, unit)
	local frame = plate and plate.UnitFrame
	local healthBar = frame and frame.healthBar
	local trough = healthBar and (healthBar.background or healthBar.Background)
	local name = UnitName and UnitName(unit) or nil
	Paint(trough, SpeciesTier(ns.FindSpecies(name, ns.CurrentZone())))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_TARGET_CHANGED" then
		UpdateTarget()
	elseif not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
		return
	else
		if event == "NAME_PLATE_UNIT_ADDED" then
			local plate = C_NamePlate.GetNamePlateForUnit(unit)
			platesByUnit[unit] = plate
			UpdatePlate(plate, unit)
		else
			local plate = platesByUnit[unit]
			platesByUnit[unit] = nil
			if not plate then
				plate = C_NamePlate.GetNamePlateForUnit(unit)
			end
			if plate and plate.UnitFrame and plate.UnitFrame.healthBar then
				local bar = plate.UnitFrame.healthBar
				Restore(bar.background or bar.Background)
			end
		end
	end
end)
