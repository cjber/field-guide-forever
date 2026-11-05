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
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BAR_GLOW_LEFT = "UI-Frame-Bar-GlowLeft"
local BAR_GLOW_CENTER = "UI-Frame-Bar-GlowCenter"
local BAR_GLOW_RIGHT = "UI-Frame-Bar-GlowRight"
local BAR_GLOW_LEFT_WIDTH = 35
local BAR_GLOW_RIGHT_WIDTH = 34
local TARGET_RING = "Portrait-Frame-Small"
local TARGET_BADGE = "Rare-Elite-Star"
local PLATE_MARKS = {
	silver = "nameplates-icon-elite-silver",
	gold = "nameplates-icon-elite-gold",
	shiny = TARGET_BADGE,
}
local PLATE_GLOW_LAYERS = {
	{ pad = 9, alpha = 0.22 },
	{ pad = 4, alpha = 0.55 },
	{ pad = 1, alpha = 1 },
}
local TARGET_GLOW_LAYERS = {
	{ pad = 9, alpha = 0.12 },
	{ pad = 5, alpha = 0.28 },
	{ pad = 2, alpha = 0.9 },
}
local TARGET_PORTRAIT_GLOW_LAYERS = {
	{ size = 96, alpha = 0.12 },
	{ size = 88, alpha = 0.28 },
	{ size = 80, alpha = 0.6 },
	{ size = 74, alpha = 1 },
}
local TAG_HEIGHT = 15
local TAG_PAD = 4
local TAG_TEXT = { 0.05, 0.06, 0.07 }
local TARGET_TAGS = { silver = "RARE", gold = "RARE", shiny = "SHINY" }
local PREVIEW_TIERS = { "silver", "gold", "shiny" }
local discoveredThisSession = {}

---@type table<string, table>
local platesByUnit = {}

---@type table<string, string>
local previewTiers = {}
local previewNext = 0
local previewWasActive = false
local targetPending = false

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

---@return boolean
local function InCombat()
	return InCombatLockdown and InCombatLockdown() or false
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

---@param bar table?
---@param color number[]?
local function SetBarColor(bar, color)
	if not bar or not bar.SetStatusBarColor then
		return
	end
	local original = bar.FGFRarityOriginalColor
	if type(original) ~= "table" then
		original = nil
	end
	if not original and bar.GetStatusBarColor then
		local r, g, b, a = bar:GetStatusBarColor()
		original = { r or 1, g or 1, b or 1, a or 1 }
		bar.FGFRarityOriginalColor = original
	end
	if color then
		bar:SetStatusBarColor(color[1], color[2], color[3], 1)
	elseif original then
		bar:SetStatusBarColor(original[1], original[2], original[3], original[4])
	end
end

---@param name table?
---@param color number[]?
local function SetNameColor(name, color)
	if not name or not name.SetTextColor then
		return
	end
	local original = name.FGFRarityOriginalTextColor
	if type(original) ~= "table" then
		original = nil
	end
	if not original and name.GetTextColor then
		local r, g, b, a = name:GetTextColor()
		original = { r or 1, g or 1, b or 1, a or 1 }
		name.FGFRarityOriginalTextColor = original
	end
	if color then
		name:SetTextColor(color[1], color[2], color[3], 1)
	elseif original then
		name:SetTextColor(original[1], original[2], original[3], original[4])
	end
end

---@param owner table
---@param layers { pad: number, alpha: number }[]
---@return table?
local function CreateBarGlow(owner, layers)
	local glow = owner.FGFRarityBarGlow
	if type(glow) == "table" then
		return glow
	end
	if not owner.CreateTexture then
		return nil
	end
	glow = {}
	for index, layer in ipairs(layers) do
		local textures = {}
		for _, piece in ipairs({
			{ "left", BAR_GLOW_LEFT },
			{ "center", BAR_GLOW_CENTER },
			{ "right", BAR_GLOW_RIGHT },
		}) do
			local texture = owner:CreateTexture(nil, "OVERLAY")
			texture:SetAtlas(piece[2])
			texture:SetBlendMode("ADD")
			texture:SetDesaturated(true)
			textures[piece[1]] = texture
		end
		glow[index] = { pad = layer.pad, alpha = layer.alpha, textures = textures }
	end
	owner.FGFRarityBarGlow = glow
	return glow
end

---@param glow table
---@param healthBar table
---@param bottomBar table
local function AnchorBarGlow(glow, healthBar, bottomBar)
	for _, layer in ipairs(glow) do
		local pad = layer.pad
		local left, center, right = layer.textures.left, layer.textures.center, layer.textures.right
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -pad, pad)
		left:SetPoint("BOTTOMLEFT", bottomBar, "BOTTOMLEFT", -pad, -pad)
		left:SetWidth(BAR_GLOW_LEFT_WIDTH)
		right:ClearAllPoints()
		right:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", pad, pad)
		right:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", pad, -pad)
		right:SetWidth(BAR_GLOW_RIGHT_WIDTH)
		center:ClearAllPoints()
		center:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
		center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
	end
end

---@param glow table?
---@param color number[]?
local function PaintBarGlow(glow, color)
	if type(glow) ~= "table" then
		return
	end
	for _, layer in ipairs(glow) do
		for _, texture in pairs(layer.textures) do
			if color then
				texture:SetVertexColor(color[1], color[2], color[3], 1)
				texture:SetAlpha(layer.alpha)
				texture:Show()
			else
				texture:Hide()
			end
		end
	end
end

---@param target table
---@param portrait table?
---@return table?
local function CreatePortraitGlow(target, portrait)
	local glow = target.FGFRarityPortraitGlow
	if type(glow) == "table" then
		return glow
	end
	if not portrait or not target.CreateTexture then
		return nil
	end
	glow = {}
	for index, layer in ipairs(TARGET_PORTRAIT_GLOW_LAYERS) do
		local texture = target:CreateTexture(nil, "OVERLAY")
		texture:SetAtlas(TARGET_RING)
		texture:SetBlendMode("ADD")
		texture:SetDesaturated(true)
		texture:SetSize(layer.size, layer.size)
		texture:SetPoint("CENTER", portrait, "CENTER", 0, 0)
		glow[index] = { texture = texture, alpha = layer.alpha }
	end
	target.FGFRarityPortraitGlow = glow
	return glow
end

---@param layer table
local function StopPulse(layer)
	local pulse = layer.pulse
	if type(pulse) == "table" then
		pulse:Stop()
	end
	layer.texture:SetAlpha(layer.alpha)
end

---@param layer table
local function StartPulse(layer)
	local texture = layer.texture
	if not texture.CreateAnimationGroup then
		texture:SetAlpha(layer.alpha)
		return
	end
	local pulse = layer.pulse
	if type(pulse) ~= "table" then
		pulse = texture:CreateAnimationGroup()
		pulse:SetLooping("REPEAT")
		local fadeIn = pulse:CreateAnimation("Alpha")
		fadeIn:SetFromAlpha(layer.alpha * 0.55)
		fadeIn:SetToAlpha(layer.alpha)
		fadeIn:SetDuration(1.2)
		fadeIn:SetOrder(1)
		local fadeOut = pulse:CreateAnimation("Alpha")
		fadeOut:SetFromAlpha(layer.alpha)
		fadeOut:SetToAlpha(layer.alpha * 0.55)
		fadeOut:SetDuration(1.2)
		fadeOut:SetOrder(2)
		layer.pulse = pulse
	end
	texture:SetAlpha(layer.alpha)
	pulse:Play()
end

---@param glow table?
---@param color number[]?
---@param tier string
local function PaintPortraitGlow(glow, color, tier)
	if type(glow) ~= "table" then
		return
	end
	for _, layer in ipairs(glow) do
		if color then
			layer.texture:SetVertexColor(color[1], color[2], color[3], 1)
			layer.texture:SetAlpha(layer.alpha)
			layer.texture:Show()
			if tier == "shiny" then
				StartPulse(layer)
			else
				StopPulse(layer)
			end
		else
			StopPulse(layer)
			layer.texture:Hide()
		end
	end
end

---@param target table?
---@param name table?
---@return table?
local function TargetTag(target, name)
	if not target or not name then
		return nil
	end
	local tag = target.FGFRarityTag
	if type(tag) == "table" then
		return tag
	end
	if not target.CreateFrame then
		return nil
	end
	tag = CreateFrame("Frame", nil, target)
	tag.plate = tag:CreateTexture(nil, "BACKGROUND")
	tag.plate:SetTexture(WHITE)
	tag.plate:SetAllPoints(tag)
	tag.text = tag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	tag.text:SetPoint("CENTER", tag, "CENTER", 0, 0)
	tag.text:SetTextColor(TAG_TEXT[1], TAG_TEXT[2], TAG_TEXT[3], 1)
	tag:SetPoint("BOTTOM", name, "TOP", 0, 2)
	tag:Hide()
	target.FGFRarityTag = tag
	return tag
end

---@param target table?
---@param name table?
---@param color number[]?
---@param label string?
local function PaintTag(target, name, color, label)
	local tag = TargetTag(target, name)
	if not tag then
		return
	end
	if color and label then
		tag.text:SetText(ns.L[label])
		tag.plate:SetVertexColor(color[1], color[2], color[3], 1)
		tag:SetSize(math.max(24, tag.text:GetStringWidth() + TAG_PAD * 2), TAG_HEIGHT)
		tag:Show()
	else
		tag:Hide()
	end
end

---@param owner table?
---@param name table?
---@param healthBar table?
---@param tier string
---@param discovery boolean?
local function UpdateAccent(owner, name, healthBar, tier, discovery)
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
	local glow = CreateBarGlow(owner, PLATE_GLOW_LAYERS)
	if type(glow) == "table" then
		if color and healthBar then
			AnchorBarGlow(glow, healthBar, healthBar)
			PaintBarGlow(glow, color)
		else
			PaintBarGlow(glow, nil)
		end
	end
end

local function UpdateTarget()
	if InCombat() then
		targetPending = true
		return
	end
	local zone = ns.CurrentZone()
	local unitName = ns.Readable(UnitName("target"))
	local species = ns.FindSpecies(unitName, zone)
	local tier = TierFor("target", species)
	local color = Rarity.COLORS[tier]
	local target = _G.TargetFrame
	local name = target and (target.name or target.Name)
	if type(name) ~= "table" then
		name = nil
	end
	local healthBar = target and (target.healthbar or target.HealthBar)
	if type(healthBar) ~= "table" then
		healthBar = nil
	end
	local powerBar = TargetPowerBar(target)
	local portrait = TargetPortrait(target)

	SetBarColor(healthBar, color)
	SetNameColor(name, color)
	local glow = target and CreateBarGlow(target, TARGET_GLOW_LAYERS)
	if type(glow) == "table" then
		if color and healthBar then
			AnchorBarGlow(glow, healthBar, powerBar or healthBar)
			PaintBarGlow(glow, color)
		else
			PaintBarGlow(glow, nil)
		end
	end
	local portraitGlow = target and CreatePortraitGlow(target, portrait)
	PaintPortraitGlow(portraitGlow, color, tier)
	PaintTag(target, name, color, TARGET_TAGS[tier])
end

---@param plate table
---@param unit string
local function UpdatePlate(plate, unit)
	local frame = plate and plate.UnitFrame
	local healthBar = frame and frame.healthBar
	local name = frame and (frame.name or frame.Name)
	local unitName = ns.Readable(UnitName(unit))
	local species = ns.FindSpecies(unitName, ns.CurrentZone())
	local tier = TierFor(unit, species)
	local color = Rarity.COLORS[tier]
	SetBarColor(healthBar, color)
	SetNameColor(name, color)
	local entry = species and ns.Model.Specimen(ns.GetCharacterState(false), species.id)
	local discovery = species
		and entry
		and entry.firstSighting
		and not discoveredThisSession[species.id]
		and entry.firstSighting == (time and time() or 0)
	if species and discovery then
		discoveredThisSession[species.id] = true
	end
	UpdateAccent(frame, name, healthBar, tier, discovery)
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
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_TARGET_CHANGED" then
		UpdateTarget()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if targetPending then
			targetPending = false
			UpdateTarget()
		end
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
				SetBarColor(bar, nil)
				local name = frame.name or frame.Name
				if type(name) == "table" then
					SetNameColor(name, nil)
					name.FGFRarityOriginalTextColor = nil
				end
				bar.FGFRarityOriginalColor = nil
				UpdateAccent(frame, type(name) == "table" and name or nil, bar, "copper", false)
			end
		end
	end
end)
