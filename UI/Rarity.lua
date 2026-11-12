---@type string, FGNamespace
local _, ns = ...

if ns.broken then
	return
end

local Art = ns.Art

---@class FGRarity
local Rarity = {}
ns.Rarity = Rarity

Rarity.COLORS = {
	silver = { 0.79, 0.83, 0.88 },
	gold = { 0.91, 0.74, 0.39 },
	shiny = { 0.58, 0.83, 1 },
}

local PLATE_ACCENT_ALPHA = 0.72
-- The client's own rare silver frame, at its own size, for its portrait ring alone. A normal bronze frame stays
-- exactly as the client draws it, and the ring is the piece CheckClassification uses, with no desaturation or tint of
-- ours. The rare atlas's bar piece is not drawn: it paints a rectangular border over the name and health bar that
-- does not line up with the c60 frame, and the ring and ornament already carry the tier.
local TARGET_FRAME_ATLAS = "UI-HUD-UnitFrame-Target-Rare-PortraitOn"
-- The silver ring reaches 64 across including its soft outer edge, so the ring art is cut to that circle.
local RING_OUTER_DIAMETER = 64
-- The client's circular portrait mask, clamped at both edges so it never tiles.
local CIRCLE_MASK = "Interface\\Masks\\CircleMask"
-- The addon's own ornaments, one per coat. Each file is 256 px square at 2 px per UI unit, with its round portrait
-- hole centred 48 units right and 80 units down from the texture's top-left.
local ORNAMENT_SIZE = 128
local ORNAMENT_HOLE_X, ORNAMENT_HOLE_Y = 48, 80
local ORNAMENT_OFFSET_X = ORNAMENT_SIZE / 2 - ORNAMENT_HOLE_X
local ORNAMENT_OFFSET_Y = ORNAMENT_HOLE_Y - ORNAMENT_SIZE / 2
local ORNAMENT_TEXTURES = {
	silver = [[Interface\AddOns\FieldGuideForever\media\Rarity\Laurel-Silver.tga]],
	gold = [[Interface\AddOns\FieldGuideForever\media\Rarity\Laurel-Gold.tga]],
	shiny = [[Interface\AddOns\FieldGuideForever\media\Rarity\Laurel-Shiny.tga]],
}
-- LootUpgradeFrame's sheen (Mainline/AlertFrameSystems.xml): the client's own loot-toast sweep, repeated after a hold.
local SHEEN_ATLAS = "loottoast-sheen"
local SHEEN_START = 1.1
local SHEEN_FADE_IN = 0.18
local SHEEN_FADE_OUT = 1.575
local SHEEN_FADE_OUT_DURATION = 0.25
local SHEEN_TRAVEL = 165
local SHEEN_TRAVEL_DURATION = 0.725
local SHEEN_HOLD = 2.4
-- Classifications the client already draws its own frame art for, so our art would only double it up.
local NATIVE_FRAME_CLASSIFICATIONS = {
	rare = true,
	rareelite = true,
	elite = true,
	minus = true,
}
-- The tiers whose nameplate carries its quality mark beside the bar.
local PLATE_MARKS = {
	silver = true,
	gold = true,
	shiny = true,
}
local PREVIEW_TIERS = { "silver", "gold", "shiny" }
local discoveredThisSession = {}

---@type table<string, table>
local platesByUnit = {}

---@type table<string, string>
local previewTiers = {}
local previewNext = 0
local previewWasActive = false
local targetPending = false

-- The spawn's tier comes from its readable GUID, read through Core's one shared unit read. A player and any unit the
-- player cannot attack have no spawn tier; this art draws them as the bronze frame it always has.
---@param unit string
---@return string
local function UnitTier(unit)
	return ns.UnitTier(unit) or "bronze"
end

-- Preview tiers are session state, never saved progress. Each creature gets one tier per session so retargeting it
-- does not flicker, while the next new creature takes the next tier in the rotation.
function Rarity.ResetPreview()
	previewTiers = {}
	previewNext = 0
	previewWasActive = false
end

---@param unit string
---@return string
local function TierFor(unit)
	local active = ns.RarityPreviewActive and ns.RarityPreviewActive() or false
	if active and not previewWasActive then
		Rarity.ResetPreview()
		previewWasActive = true
	elseif not active then
		previewWasActive = false
	end
	if not active then
		return UnitTier(unit)
	end
	if UnitIsPlayer and UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then
		return "bronze"
	end
	local guid = ns.Readable(UnitGUID(unit))
	local key = guid and tostring(guid) or unit
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

-- The client draws its own rare, elite, boss or minus-mob frame for these units, so our recolour would only double it.
---@param unit string
---@return boolean
local function NativeFrame(unit)
	if UnitIsBossMob and UnitIsBossMob(unit) then
		return true
	end
	local classification = UnitClassification and UnitClassification(unit)
	return classification ~= nil and NATIVE_FRAME_CLASSIFICATIONS[classification] == true
end

-- Read the client frame's own anchors, so each rare piece sits where the client draws its bronze frame, then apply the
-- measured offset that lines the retail rare art up with the c60 normal art. The atlas itself supplies the size
-- (SetAtlas(..., true)), never the normal frame's measured size.
---@param texture table
---@param source table
---@param offsetX number
---@param offsetY number
local function MirrorFramePoints(texture, source, offsetX, offsetY)
	texture:ClearAllPoints()
	for index = 1, source:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = source:GetPoint(index)
		x, y = (x or 0) + offsetX, (y or 0) + offsetY
		if relativeTo and relativePoint then
			texture:SetPoint(point, relativeTo, relativePoint, x, y)
		else
			texture:SetPoint(point, x, y)
		end
	end
end

-- One sheen texture, masked by the art it crosses so it can never spill outside that piece.
---@param container table
---@param maskTarget table
---@param subLevel number
---@param applyMask fun(mask: table)
---@return table, table
local function CreateSheen(container, maskTarget, subLevel, applyMask)
	local sheen = container:CreateTexture(nil, "ARTWORK", nil, subLevel)
	sheen:SetAtlas(SHEEN_ATLAS, true)
	sheen:SetBlendMode("ADD")
	sheen:SetPoint("CENTER", container, "CENTER", -80, 0)
	sheen:SetAlpha(0)
	sheen:Hide()
	local mask = container:CreateMaskTexture(nil, "ARTWORK", nil, subLevel)
	applyMask(mask)
	mask:SetAllPoints(maskTarget)
	mask:Hide()
	sheen:AddMaskTexture(mask)
	return sheen, mask
end

-- LootUpgradeFrame's sheen timing, looping: the same fade in, travel and fade out, with a short hold between sweeps.
-- The sheen is cosmetic and owns no protected frame, so it plays in combat too.
---@param target table
---@param container table
---@param sheens table
---@return table
local function CreateSheenAnimation(target, container, sheens)
	local group = container:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	for _, sheen in ipairs(sheens) do
		local fadeIn = group:CreateAnimation("Alpha")
		fadeIn:SetTarget(sheen)
		fadeIn:SetFromAlpha(0)
		fadeIn:SetToAlpha(1)
		fadeIn:SetStartDelay(SHEEN_START)
		fadeIn:SetDuration(SHEEN_FADE_IN)
		fadeIn:SetOrder(1)

		local fadeOut = group:CreateAnimation("Alpha")
		fadeOut:SetTarget(sheen)
		fadeOut:SetFromAlpha(1)
		fadeOut:SetToAlpha(0)
		fadeOut:SetStartDelay(SHEEN_FADE_OUT)
		fadeOut:SetDuration(SHEEN_FADE_OUT_DURATION)
		fadeOut:SetEndDelay(SHEEN_HOLD)
		fadeOut:SetOrder(1)

		local travel = group:CreateAnimation("Translation")
		travel:SetTarget(sheen)
		travel:SetOffset(SHEEN_TRAVEL, 0)
		travel:SetStartDelay(SHEEN_START)
		travel:SetDuration(SHEEN_TRAVEL_DURATION)
		travel:SetOrder(1)
	end
	target.FGFRaritySheenAnim = group
	return group
end

---@class FGFRarityTargetArt
---@field ring Texture the rare silver frame's portrait ring
---@field ringMask MaskTexture
---@field ornament Texture the coat's ornament
---@field ornamentSheen Texture the ornament sheen
---@field ornamentMask MaskTexture
---@field anim AnimationGroup

---@param target table?
---@return FGFRarityTargetArt?
local function CreateTargetArt(target)
	local existing = target and target.FGFRarityArt
	if type(existing) == "table" then
		return existing --[[@as FGFRarityTargetArt]]
	end
	local container = target and target.TargetFrameContainer
	local source = container and container.FrameTexture
	local portrait = container and container.Portrait
	if
		not target
		or not container
		or type(source) ~= "table"
		or type(portrait) ~= "table"
		or not container.CreateTexture
	then
		return nil
	end

	-- The ring art keeps the frame's own anchors and is cut to the client's portrait circle, so the silver ring
	-- shares the portrait's centre. The mask is the measured outer diameter of the ring.
	local ring = container:CreateTexture(nil, "BACKGROUND", nil, 4)
	ring:SetAtlas(TARGET_FRAME_ATLAS, true)
	MirrorFramePoints(ring, source, 0, 0)
	local ringMask = container:CreateMaskTexture(nil, "BACKGROUND", nil, 4)
	ringMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	ringMask:SetPoint("CENTER", portrait, "CENTER")
	ringMask:SetSize(RING_OUTER_DIAMETER, RING_OUTER_DIAMETER)
	ring:AddMaskTexture(ringMask)

	-- The ornament's round hole sits over the portrait, so it is anchored from the portrait's own centre.
	local ornament = container:CreateTexture(nil, "ARTWORK", nil, 2)
	ornament:SetSize(ORNAMENT_SIZE, ORNAMENT_SIZE)
	ornament:SetPoint("CENTER", portrait, "CENTER", ORNAMENT_OFFSET_X, ORNAMENT_OFFSET_Y)

	local ornamentSheen, ornamentMask = CreateSheen(container, ornament, 4, function(mask)
		-- art-ok: the ornament is square 256 px art drawn at 128 units on both sides
		mask:SetTexture(ORNAMENT_TEXTURES.shiny, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end)
	local anim = CreateSheenAnimation(target, container, { ornamentSheen })

	ring:Hide()
	ornament:Hide()
	target.FGFRarityFrame = { ring }
	local art = {
		ring = ring,
		ringMask = ringMask,
		ornament = ornament,
		ornamentSheen = ornamentSheen,
		ornamentMask = ornamentMask,
		anim = anim,
	}
	target.FGFRarityArt = art
	return art
end

---@param target table?
---@param tier string
---@param color number[]?
---@param native boolean
local function PaintTargetFrame(target, tier, color, native)
	local art = target and CreateTargetArt(target)
	if not art then
		return
	end
	local show = color and not native
	local silver = show and (tier == "silver" or tier == "shiny")
	local shiny = show and tier == "shiny"
	local ornamentTexture = show and ORNAMENT_TEXTURES[tier]
	art.ring:SetShown(silver)
	if ornamentTexture then
		art.ornament:SetTexture(ornamentTexture) -- art-ok: the ornament is square 256 px art drawn at 128 units on both sides
		art.ornamentMask:SetTexture(ORNAMENT_TEXTURES.shiny, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		art.ornament:Show()
	else
		art.ornament:Hide()
	end
	if shiny then
		art.ornamentSheen:Show()
		art.ornamentMask:Show()
		if not art.anim:IsPlaying() then
			art.ornamentSheen:SetAlpha(0)
			art.anim:Play()
		end
	else
		art.anim:Stop()
		art.ornamentSheen:Hide()
		art.ornamentMask:Hide()
	end
end

-- Stock nameplates hang their left-hand decorations out from the health bar. A 22 by 22 RaidTargetFrame's right edge
-- sits on HealthBarsContainer's left, a 20 by 20 ClassificationFrame's right edge on the raid target's left, and
-- AurasFrame.BuffListFrame's right edge 5 units left of the classification frame, growing left with up to two 25-unit
-- buff icons (Blizzard_NamePlates.xml 186-236, Blizzard_NamePlateUnitFrame.lua:848-858, Blizzard_NamePlateAuras.lua).
-- Both badges carry collapsesLayout, so a hidden badge reserves no space and the buff row moves in. Anchoring 2 units
-- beyond a shown buff row's own left edge clears the icons and the badges, and follows the row as it grows; a hidden
-- row draws nothing, so the mark falls back through the remaining anchors to the bar. The badge fallbacks are used
-- whether the badge is shown or not: both anchors stay in place when it collapses, so a badge appearing later cannot
-- cover the mark.
local PLATE_MARK_GAP = 2
---@param frame table?
---@param healthBar table?
---@return table? anchor
---@return string relativePoint
---@return number offsetX
local function PlateMarkAnchor(frame, healthBar)
	local auras = frame and frame.AurasFrame
	local buffs = type(auras) == "table" and auras.BuffListFrame
	if type(buffs) == "table" and auras:IsShown() and buffs:IsShown() then
		return buffs, "LEFT", -PLATE_MARK_GAP
	end
	local classification = frame and frame.ClassificationFrame
	if type(classification) == "table" then
		return classification, "LEFT", -PLATE_MARK_GAP
	end
	local raidTarget = frame and frame.RaidTargetFrame
	if type(raidTarget) == "table" then
		return raidTarget, "LEFT", -PLATE_MARK_GAP
	end
	if healthBar then
		return healthBar, "LEFT", -PLATE_MARK_GAP
	end
	return nil, "LEFT", -PLATE_MARK_GAP
end

-- Move an existing marker onto the frame PlateMarkAnchor picks now, so a plate whose buff row or badges changed does
-- not keep an anchor chosen when it was first marked. Only the anchor changes; the marker keeps its atlas, alpha and
-- shown state.
---@param marker table
---@param frame table?
---@param healthBar table?
local function AnchorPlateMarker(marker, frame, healthBar)
	local anchor, relativePoint, offsetX = PlateMarkAnchor(frame, healthBar)
	if not anchor then
		return
	end
	local point, relativeTo, currentPoint, x, y = marker:GetPoint(1)
	if
		marker:GetNumPoints() == 1
		and point == "RIGHT"
		and relativeTo == anchor
		and currentPoint == relativePoint
		and x == offsetX
		and y == 0
	then
		return
	end
	marker:ClearAllPoints()
	marker:SetPoint("RIGHT", anchor, relativePoint, offsetX, 0)
end

---@param owner table?
local function ReanchorPlate(owner)
	local marker = owner and owner.FGFRarityMarker
	if type(marker) ~= "table" then
		return
	end
	local frame = owner and owner.UnitFrame
	local healthBar = frame and frame.healthBar
	if healthBar then
		AnchorPlateMarker(marker, frame, healthBar)
	end
end

-- The client changes a nameplate's buff row outside our events: SetUnit calls UpdateShownState and then RefreshAuras,
-- the aura CVars call UpdateShownState and SHOW_ALL_PERSONAL_AURAS calls RefreshAuras, and RefreshAuras lays the list
-- out again after every added, removed or rescaled aura (Blizzard_NamePlateAuras.lua:92-135, 363-404, 541-575).
-- Secure post-hooks catch calls made through the instance, but SetUnit registers its CVar callbacks with the original
-- methods before NAME_PLATE_UNIT_ADDED lets us install those hooks, so a CVar change would bypass them. The same CVar
-- registry callbacks below catch that saved-original path; their reanchor is deferred one frame because registry
-- callbacks run in table order, not registration order. Both are installed once per AurasFrame, which the plate keeps
-- across recycling; the callback reads the plate's current UnitFrame so a replacement skin is followed too.
---@param owner table?
---@param frame table?
local function WatchPlate(owner, frame)
	local auras = frame and frame.AurasFrame
	if type(auras) ~= "table" or auras.FGFRarityWatched == true then
		return
	end
	auras.FGFRarityWatched = true
	local function reanchor()
		ReanchorPlate(owner)
	end
	local function reanchorLater()
		C_Timer.After(0, reanchor)
	end
	if type(auras.UpdateShownState) == "function" then
		hooksecurefunc(auras, "UpdateShownState", reanchor)
	end
	if type(auras.RefreshAuras) == "function" then
		hooksecurefunc(auras, "RefreshAuras", reanchor)
	end
	local constants = _G.NamePlateConstants
	local registry = _G.CVarCallbackRegistry
	if type(constants) ~= "table" or type(registry) ~= "table" then
		return
	end
	local cvarOwner = {}
	for _, cvar in ipairs({
		constants.ENEMY_NPC_AURA_DISPLAY_CVAR,
		constants.ENEMY_PLAYER_AURA_DISPLAY_CVAR,
		constants.FRIENDLY_PLAYER_AURA_DISPLAY_CVAR,
		constants.SHOW_DEBUFFS_ON_FRIENDLY_CVAR,
		constants.AURA_SCALE_CVAR,
		constants.SHOW_ALL_PERSONAL_AURAS_CVAR,
	}) do
		if type(cvar) == "string" then
			registry:RegisterCallback(cvar, reanchorLater, cvarOwner)
		end
	end
	auras.FGFRarityCVarOwner = cvarOwner
end

---@param owner table?
---@param frame table?
---@param healthBar table?
---@param tier string
---@param discovery boolean?
local function UpdateAccent(owner, frame, healthBar, tier, discovery)
	if not owner then
		return
	end
	local color = Rarity.COLORS[tier]
	local mark = PLATE_MARKS[tier]
	local marker = owner.FGFRarityMarker
	if type(marker) == "function" then
		marker = nil
	end
	if not marker and healthBar and owner.CreateTexture then
		marker = owner:CreateTexture(nil, "OVERLAY")
		owner.FGFRarityMarker = marker
	end
	if marker then
		AnchorPlateMarker(marker, frame, healthBar)
		WatchPlate(owner, frame)
		if color and mark then
			Art.PaintTierIcon(marker, tier, 17)
			marker:SetVertexColor(1, 1, 1, 1)
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
end

local function UpdateTarget()
	if InCombat() then
		targetPending = true
		return
	end
	local tier = TierFor("target")
	local color = Rarity.COLORS[tier]
	PaintTargetFrame(_G.TargetFrame, tier, color, NativeFrame("target"))
end

---@param plate table
---@param unit string
local function UpdatePlate(plate, unit)
	local frame = plate and plate.UnitFrame
	local healthBar = frame and frame.healthBar
	local unitName = ns.Readable(UnitName(unit))
	local species = ns.FindSpecies(unitName, ns.CurrentZone())
	local tier = TierFor(unit)
	local entry = species and ns.Model.Specimen(ns.GetCharacterState(false), species.id)
	local discovery = species
		and entry
		and entry.firstSighting
		and not discoveredThisSession[species.id]
		and entry.firstSighting == (time and time() or 0)
	if species and discovery then
		discoveredThisSession[species.id] = true
	end
	-- Keep the mark on the nameplate itself: alternate skins may hide or replace Blizzard's UnitFrame child.
	UpdateAccent(plate, frame, healthBar, tier, discovery)
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
			if frame then
				local bar = frame.healthBar
				UpdateAccent(plate, frame, bar, "bronze", false)
			end
		end
	end
end)
