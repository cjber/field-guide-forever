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

local PLATE_ACCENT_ALPHA = 0.72
local PLATE_BORDER_SIZE = 2
local BAR_GLOW_ALPHA = 0.8
local BAR_GLOW_PAD = 3
local BAR_GLOW_LEFT_WIDTH = 35
local BAR_GLOW_RIGHT_WIDTH = 34
local BAR_TINT_ALPHA = { silver = 0.3, gold = 0.3, shiny = 0.45 }
local TARGET_RING_ALPHA = 1
local TARGET_RING_SIZE = 76
local TARGET_BADGE_SIZE = 26
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TARGET_BAR_GLOW_LEFT = "UI-Frame-Bar-GlowLeft"
local TARGET_BAR_GLOW_CENTER = "UI-Frame-Bar-GlowCenter"
local TARGET_BAR_GLOW_RIGHT = "UI-Frame-Bar-GlowRight"
local TARGET_RING = "Portrait-Frame-Small"
local TARGET_BADGE = "Rare-Elite-Star"
local PLATE_MARKS = {
	silver = "nameplates-icon-elite-silver",
	gold = "nameplates-icon-elite-gold",
	shiny = TARGET_BADGE,
}
local PREVIEW_TIERS = { "silver", "gold", "shiny" }
local discoveredThisSession = {}

---@type table<table, { desaturated: boolean, r: number, g: number, b: number, a: number, painted: number[] }>
local originals = {}
---@type table<string, table>
local platesByUnit = {}

---@type table<string, string>
local previewTiers = {}
local previewNext = 0
local previewWasActive = false

---@param species FGSpecies?
---@return string
local function SpeciesTier(species)
	return species and ns.Model.Tier(species.id) or "copper"
end

-- Preview tiers are session state, never saved progress. Each creature gets one tier per session so retargeting it
-- does not flicker, while the next new creature takes the next tier in the rotation.
function Rarity.ResetPreview()
	previewTiers = {}
	previewNext = 0
	previewWasActive = false
end

---@param unit string
---@param species FGSpecies?
---@return string
local function TierFor(unit, species)
	local active = ns.RarityPreviewActive and ns.RarityPreviewActive() or false
	if active and not previewWasActive then
		Rarity.ResetPreview()
		previewWasActive = true
	elseif not active then
		previewWasActive = false
	end
	if not active then
		return SpeciesTier(species)
	end
	if UnitIsPlayer and UnitIsPlayer(unit) then
		return "copper"
	end
	local guid = ns.Readable(UnitGUID(unit))
	local key = guid and tostring(guid) or (species and ("species:" .. species.id)) or unit
	local tier = previewTiers[key]
	if not tier then
		previewNext = previewNext + 1
		tier = PREVIEW_TIERS[(previewNext - 1) % #PREVIEW_TIERS + 1]
		previewTiers[key] = tier
	end
	return tier
end

---@param texture table?
local function Restore(texture)
	local original = texture and originals[texture]
	if not texture or not original then
		return
	end
	originals[texture] = nil
	local r, g, b, a = texture:GetVertexColor()
	local painted = original.painted
	-- Each property may have another writer. Undo only the values we still own.
	if texture:IsDesaturated() then
		texture:SetDesaturated(original.desaturated)
	end
	if r == painted[1] and g == painted[2] and b == painted[3] and a == painted[4] then
		texture:SetVertexColor(original.r, original.g, original.b, original.a)
	end
end

---@param texture table?
---@param tier string
local function Paint(texture, tier)
	if not texture or not texture.GetVertexColor then
		return
	end
	Restore(texture)
	local color = Rarity.COLORS[tier]
	if color then
		local r, g, b, a = texture:GetVertexColor()
		local original = {
			desaturated = texture.IsDesaturated and texture:IsDesaturated() or false,
			r = r or 1,
			g = g or 1,
			b = b or 1,
			a = a or 1,
			painted = {},
		}
		texture:SetDesaturated(true)
		texture:SetVertexColor(color[1], color[2], color[3], 1)
		-- Read back the engine's colour precision before comparing it on cleanup.
		original.painted = { texture:GetVertexColor() } -- multi-value: retain the four colour channels
		originals[texture] = original
	end
end

---@param owner table
---@param healthBar table
---@return table?
local function PlateBorder(owner, healthBar)
	local border = owner.FGFRarityBorder
	if type(border) == "table" then
		return border
	end
	if not owner.CreateTexture then
		return nil
	end
	border = {}
	local function Edge()
		local texture = owner:CreateTexture(nil, "OVERLAY")
		texture:SetTexture(WHITE)
		return texture
	end
	local top = Edge()
	top:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
	top:SetHeight(PLATE_BORDER_SIZE)
	local bottom = Edge()
	bottom:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
	bottom:SetHeight(PLATE_BORDER_SIZE)
	local left = Edge()
	left:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", 0, 0)
	left:SetWidth(PLATE_BORDER_SIZE)
	local right = Edge()
	right:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(PLATE_BORDER_SIZE)
	border.top, border.bottom, border.left, border.right = top, bottom, left, right
	owner.FGFRarityBorder = border
	return border
end

---@param owner table?
---@param name table?
---@param healthBar table?
---@param tier string
---@param discovery boolean?
---@param border boolean?
local function UpdateAccent(owner, name, healthBar, tier, discovery, border)
	if not owner then
		return
	end
	local color = Rarity.COLORS[tier]
	local mark = PLATE_MARKS[tier]
	local marker = owner.FGFRarityMarker
	if type(marker) == "function" then
		marker = nil
	end
	if not marker and name and owner.CreateTexture then
		marker = owner:CreateTexture(nil, "OVERLAY")
		marker:SetPoint("LEFT", name, "RIGHT", 2, 0)
		owner.FGFRarityMarker = marker
	end
	if marker then
		if color and mark then
			marker:SetAtlas(mark)
			marker:SetSize(tier == "shiny" and 16 or 17, 16)
			if tier == "shiny" then
				marker:SetVertexColor(color[1], color[2], color[3], 1)
			else
				marker:SetVertexColor(1, 1, 1, 1)
			end
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
	local edges = border and healthBar and PlateBorder(owner, healthBar) or owner.FGFRarityBorder
	if type(edges) == "table" then
		for _, texture in pairs(edges) do
			if color then
				texture:SetVertexColor(color[1], color[2], color[3], 0.9)
				texture:Show()
			else
				texture:Hide()
			end
		end
	end
end

---@param target table?
---@return table?
local function TargetPortrait(target)
	return target and (target.portrait or target.Portrait) or TargetFramePortrait
end

---@param target table?
---@return table?
local function TargetPowerBar(target)
	if not target then
		return nil
	end
	for _, key in ipairs({ "manabar", "ManaBar", "powerbar", "PowerBar" }) do
		local bar = target[key]
		if type(bar) == "table" then
			return bar
		end
	end
end

-- The bar's own background, behind the StatusBar fill, so the empty part of each bar reads as the tier while the
-- filled part keeps the client's health and power colours.
---@param bar table
---@return table?
local function BarTint(bar)
	local tint = bar.FGFRarityTint
	if type(tint) == "table" then
		return tint
	end
	if not bar.CreateTexture then
		return nil
	end
	tint = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
	tint:SetTexture(WHITE)
	tint:SetAllPoints(bar)
	bar.FGFRarityTint = tint
	return tint
end

---@param bar table?
---@param color number[]?
---@param alpha number
local function PaintBarTint(bar, color, alpha)
	local tint = type(bar) == "table" and BarTint(bar) or nil
	if not tint then
		return
	end
	if color then
		tint:SetVertexColor(color[1], color[2], color[3], alpha)
		tint:Show()
	else
		tint:Hide()
	end
end

---@param glow table
local function StopShinyPulse(glow)
	local pulse = glow.FGFRarityPulse
	if type(pulse) == "table" then
		pulse:Stop()
	end
	glow:SetAlpha(TARGET_RING_ALPHA)
end

---@param glow table
local function StartShinyPulse(glow)
	if not glow.CreateAnimationGroup then
		return
	end
	local pulse = glow.FGFRarityPulse
	if type(pulse) ~= "table" then
		pulse = glow:CreateAnimationGroup()
		pulse:SetLooping("REPEAT")
		local fadeIn = pulse:CreateAnimation("Alpha")
		fadeIn:SetFromAlpha(0.35)
		fadeIn:SetToAlpha(1)
		fadeIn:SetDuration(0.8)
		fadeIn:SetOrder(1)
		local fadeOut = pulse:CreateAnimation("Alpha")
		fadeOut:SetFromAlpha(1)
		fadeOut:SetToAlpha(0.35)
		fadeOut:SetDuration(0.8)
		fadeOut:SetOrder(2)
		glow.FGFRarityPulse = pulse
	end
	glow:SetAlpha(1)
	pulse:Play()
end

---@param target table
---@return table?
local function TargetBarGlow(target)
	local glow = target.FGFRarityBarGlow
	if type(glow) == "table" then
		return glow
	end
	if not target.CreateTexture then
		return nil
	end
	glow = {}
	for key, atlas in pairs({
		left = TARGET_BAR_GLOW_LEFT,
		center = TARGET_BAR_GLOW_CENTER,
		right = TARGET_BAR_GLOW_RIGHT,
	}) do
		local texture = target:CreateTexture(nil, "BACKGROUND", nil, -8)
		texture:SetAtlas(atlas)
		texture:SetBlendMode("ADD")
		texture:SetDesaturated(true)
		glow[key] = texture
	end
	target.FGFRarityBarGlow = glow
	return glow
end

---@param glow table
---@param healthBar table
---@param bottomBar table
local function AnchorBarGlow(glow, healthBar, bottomBar)
	glow.left:ClearAllPoints()
	glow.left:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -BAR_GLOW_PAD, BAR_GLOW_PAD)
	glow.left:SetPoint("BOTTOMLEFT", bottomBar, "BOTTOMLEFT", -BAR_GLOW_PAD, -BAR_GLOW_PAD)
	glow.left:SetWidth(BAR_GLOW_LEFT_WIDTH)
	glow.right:ClearAllPoints()
	glow.right:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", BAR_GLOW_PAD, BAR_GLOW_PAD)
	glow.right:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", BAR_GLOW_PAD, -BAR_GLOW_PAD)
	glow.right:SetWidth(BAR_GLOW_RIGHT_WIDTH)
	glow.center:ClearAllPoints()
	glow.center:SetPoint("TOPLEFT", glow.left, "TOPRIGHT", 0, 0)
	glow.center:SetPoint("BOTTOMRIGHT", glow.right, "BOTTOMLEFT", 0, 0)
end

---@param target table?
---@param tier string
---@param discovery boolean?
local function UpdateTargetMark(target, tier, discovery)
	if not target or not target.CreateTexture then
		return
	end
	local color = Rarity.COLORS[tier]
	local tintAlpha = BAR_TINT_ALPHA[tier] or 0.3
	local portrait = TargetPortrait(target)
	local healthBar = target.healthbar or target.HealthBar
	if type(healthBar) ~= "table" then
		healthBar = nil
	end
	local powerBar = TargetPowerBar(target)
	local bottomBar = powerBar or healthBar
	local barGlow = TargetBarGlow(target)
	local ring = target.FGFRarityRing
	if type(ring) == "function" then
		ring = nil
	end
	if not ring then
		ring = target:CreateTexture(nil, "OVERLAY")
		ring:SetAtlas(TARGET_RING)
		ring:SetBlendMode("ADD")
		ring:SetDesaturated(true)
		ring:SetSize(TARGET_RING_SIZE, TARGET_RING_SIZE)
		if portrait then
			ring:SetPoint("CENTER", portrait, "CENTER", 0, 0)
		else
			ring:SetPoint("CENTER", target, "TOPRIGHT", -34, -34)
		end
		target.FGFRarityRing = ring
	end
	local badge = target.FGFRarityBadge
	if type(badge) == "function" then
		badge = nil
	end
	if not badge then
		badge = target:CreateTexture(nil, "OVERLAY")
		badge:SetAtlas(TARGET_BADGE)
		badge:SetBlendMode("ADD")
		badge:SetSize(TARGET_BADGE_SIZE, TARGET_BADGE_SIZE)
		if portrait then
			badge:SetPoint("CENTER", portrait, "TOPRIGHT", -5, -5)
		else
			badge:SetPoint("CENTER", target, "TOPRIGHT", -20, -20)
		end
		target.FGFRarityBadge = badge
	end
	if color and healthBar and bottomBar and barGlow then
		AnchorBarGlow(barGlow, healthBar, bottomBar)
		for _, texture in pairs(barGlow) do
			texture:SetVertexColor(color[1], color[2], color[3], 1)
			texture:SetAlpha(BAR_GLOW_ALPHA)
			texture:Show()
		end
	elseif barGlow then
		for _, texture in pairs(barGlow) do
			texture:Hide()
		end
	end
	PaintBarTint(healthBar, color, tintAlpha)
	PaintBarTint(powerBar, color, tintAlpha)
	if color and portrait then
		ring:SetVertexColor(color[1], color[2], color[3], 1)
		ring:SetAlpha(TARGET_RING_ALPHA)
		ring:Show()
		if tier == "shiny" then
			StartShinyPulse(ring)
		else
			StopShinyPulse(ring)
		end
	else
		StopShinyPulse(ring)
		ring:Hide()
	end
	if color then
		badge:SetVertexColor(color[1], color[2], color[3], 1)
		badge:SetAlpha(discovery and 1 or 0.9)
		badge:Show()
	else
		badge:Hide()
	end
end

local function TargetChrome()
	local target = _G.TargetFrame
	local container = target and target.TargetFrameContainer
	return (container and container.FrameTexture) or (target and target.TargetFrameTextureFrameTexture)
end

local function UpdateTarget()
	local zone = ns.CurrentZone()
	local name = ns.Readable(UnitName("target"))
	local species = ns.FindSpecies(name, zone)
	local tier = TierFor("target", species)
	Paint(TargetChrome(), tier)
	local target = _G.TargetFrame
	local entry = species and ns.Model.Specimen(ns.GetCharacterState(false), species.id)
	local discovery = species
		and entry
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
		discovery,
		false
	)
	UpdateTargetMark(target, tier, discovery)
end

---@param plate table
---@param unit string
local function UpdatePlate(plate, unit)
	local frame = plate and plate.UnitFrame
	local healthBar = frame and frame.healthBar
	local trough = healthBar and healthBar.bgTexture
	local name = ns.Readable(UnitName(unit))
	local species = ns.FindSpecies(name, ns.CurrentZone())
	local tier = TierFor(unit, species)
	Paint(trough, tier)
	local entry = species and ns.Model.Specimen(ns.GetCharacterState(false), species.id)
	local discovery = species
		and entry
		and entry.firstSighting
		and not discoveredThisSession[species.id]
		and entry.firstSighting == (time and time() or 0)
	if species and discovery then
		discoveredThisSession[species.id] = true
	end
	UpdateAccent(frame, frame and (frame.name or frame.Name), healthBar, tier, discovery, true)
end

-- Redraw every visible mark after the preview toggles, so the change is immediate rather than waiting for the next
-- target or nameplate event.
function Rarity.Refresh()
	UpdateTarget()
	if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
		return
	end
	for unit, stored in pairs(platesByUnit) do
		UpdatePlate(C_NamePlate.GetNamePlateForUnit(unit) or stored, unit)
	end
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
			---@type table?
			local plate = platesByUnit[unit]
			platesByUnit[unit] = nil
			if not plate then
				plate = C_NamePlate.GetNamePlateForUnit(unit) --[[@as table?]]
			end
			local frame = plate and plate.UnitFrame
			local bar = frame and frame.healthBar
			if frame and bar then
				Restore(bar.bgTexture)
				UpdateAccent(frame, frame.name or frame.Name, bar, "copper", false, true)
			end
		end
	end
end)
