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

local ACCENT = "◆"
local PLATE_ACCENT_ALPHA = 0.72
local discoveredThisSession = {}

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

---@param owner table
---@param name table?
---@param healthBar table?
---@param tier string
---@param discovery boolean?
local function UpdateAccent(owner, name, healthBar, tier, discovery)
	local color = Rarity.COLORS[tier]
	if not owner then
		return
	end
	local marker = owner.FGFRarityMarker
	if type(marker) == "function" then
		marker = nil
	end
	if not marker and name and owner.CreateFontString then
		owner.FGFRarityMarker = owner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		owner.FGFRarityMarker:SetPoint("LEFT", name, "RIGHT", 2, 0)
		owner.FGFRarityMarker:SetText(ACCENT)
	end
	marker = owner.FGFRarityMarker
	if type(marker) == "function" then
		marker = nil
	end
	if marker then
		if color then
			marker:SetTextColor(color[1], color[2], color[3], 1)
			marker:Show()
			marker:SetAlpha(discovery and 1 or PLATE_ACCENT_ALPHA)
			if discovery and C_Timer and C_Timer.After then
				C_Timer.After(0.7, function()
					if marker then
						marker:SetAlpha(PLATE_ACCENT_ALPHA)
					end
				end)
			end
		else
			marker:Hide()
		end
	end
	if healthBar and healthBar.CreateTexture then
		local accent = owner.FGFRarityAccent
		if type(accent) == "function" then
			accent = nil
		end
		if not accent then
			accent = healthBar:CreateTexture(nil, "OVERLAY")
			accent:SetTexture("Interface\\Buttons\\WHITE8X8")
			accent:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", 0, 0)
			accent:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
			accent:SetHeight(2)
			owner.FGFRarityAccent = accent
		end
		if color then
			accent:SetVertexColor(color[1], color[2], color[3], 0.9)
			accent:Show()
		else
			accent:Hide()
		end
	end
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
	local target = _G.TargetFrame
	local entry = species and ns.Model.Specimen(ns.GetCharacterState(false), species.id)
	local tier = SpeciesTier(species)
	local discovery = entry
		and entry.firstSighting
		and not discoveredThisSession[species.id]
		and entry.firstSighting == (time and time() or 0)
	if species and discovery then
		discoveredThisSession[species.id] = true
	end
	UpdateAccent(
		target,
		target and (target.name or target.Name),
		target and (target.healthbar or target.HealthBar),
		tier,
		discovery
	)
end

---@param plate table
---@param unit string
local function UpdatePlate(plate, unit)
	local frame = plate and plate.UnitFrame
	local healthBar = frame and frame.healthBar
	local trough = healthBar and (healthBar.background or healthBar.Background)
	local name = UnitName and UnitName(unit) or nil
	local species = ns.FindSpecies(name, ns.CurrentZone())
	local tier = SpeciesTier(species)
	Paint(trough, tier)
	local entry = species and ns.Model.Specimen(ns.GetCharacterState(false), species.id)
	local discovery = entry
		and entry.firstSighting
		and not discoveredThisSession[species.id]
		and entry.firstSighting == (time and time() or 0)
	if species and discovery then
		discoveredThisSession[species.id] = true
	end
	UpdateAccent(frame, frame and (frame.name or frame.Name), healthBar, tier, discovery)
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
