---@type string, FGNamespace
local _, ns = ...
local L = ns.L
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
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- The client's own rare silver frame, at its own size. A normal bronze frame stays exactly as the client draws it,
-- and the rare frame is the piece CheckClassification uses, with no desaturation or tint of ours.
local TARGET_FRAME_ATLAS = "UI-HUD-UnitFrame-Target-Rare-PortraitOn"
-- Forever's normal target frame is the c60 atlas, but the rare atlas has no c60 member and returns the retail art.
-- Both are 192 by 67, yet the retail rare art draws its name/health divider 2 units above the c60 art (name bar rows
-- 20 to 23 against 21 to 25, health rows 24 to 41 against 26 to 41). The client name is anchored to ReputationColor,
-- not to this texture, so centring the overlay leaves the name 2 units closer to the line above the health bar. Drop
-- the overlay 2 units so its divider and health bar line up with the frame it covers.
local RARE_FRAME_OFFSET_Y = -2
-- The addon's own ornaments, one per coat. Each file is 256 px square at 2 px per UI unit, with the portrait's hole
-- centred 48 units right and 80 units down from the texture's top-left, so the portrait's centre (55 left of and 48
-- below the container's top-right) is the ornament's round hole.
local ORNAMENT_SIZE = 128
local ORNAMENT_X, ORNAMENT_Y = -103, 32
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
local TAG_HEIGHT = 15
local TAG_PAD = 4
local TAG_TEXT = { 0.05, 0.06, 0.07 }
local TARGET_TAGS = { silver = "SILVER", gold = "GOLD", shiny = "SHINY" }
local SIZE_TAG_COLORS = {
	TINY = { 0.58, 0.83, 1 },
	GIANT = { 0.91, 0.74, 0.39 },
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

-- The spawn's tier comes from its readable GUID, so every player who meets that spawn sees the same coat. A player
-- and any unit the player cannot attack have no spawn tier, and a unit whose GUID the client hides stays bronze.
---@param unit string
---@return string
local function UnitTier(unit)
	if UnitIsPlayer and UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then
		return "bronze"
	end
	return ns.Model.SpawnTier(ns.Readable(UnitGUID(unit)))
end

-- The spawn's size belongs to the same readable GUID as its coat, so every player sees the same size on the same
-- spawn. Players have none, and a unit whose GUID the client hides has no size to show.
---@param unit string
---@return integer?
local function UnitSize(unit)
	if UnitIsPlayer and UnitIsPlayer(unit) then
		return nil
	end
	return ns.Model.SpawnSize(ns.Readable(UnitGUID(unit)))
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

-- Read the client frame's own anchors, so the rare overlay sits where it draws its bronze frame, then apply the
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
---@field overlay Texture the rare silver frame
---@field ornament Texture the coat's ornament
---@field sheen Texture the frame sheen
---@field ornamentSheen Texture the ornament sheen
---@field sheenMask MaskTexture
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
	if not target or not container or type(source) ~= "table" or not container.CreateTexture then
		return nil
	end

	local overlay = container:CreateTexture(nil, "BACKGROUND", nil, 3)
	overlay:SetAtlas(TARGET_FRAME_ATLAS, true)
	MirrorFramePoints(overlay, source, 0, RARE_FRAME_OFFSET_Y)

	-- The ornament's round hole sits over the portrait, so the art is anchored from the container's top-right corner.
	local ornament = container:CreateTexture(nil, "ARTWORK", nil, 2)
	ornament:SetSize(ORNAMENT_SIZE, ORNAMENT_SIZE)
	ornament:SetPoint("TOPLEFT", container, "TOPRIGHT", ORNAMENT_X, ORNAMENT_Y)

	local sheen, sheenMask = CreateSheen(container, overlay, 3, function(mask)
		mask:SetAtlas(TARGET_FRAME_ATLAS, true)
	end)
	local ornamentSheen, ornamentMask = CreateSheen(container, ornament, 4, function(mask)
		-- art-ok: the ornament is square 256 px art drawn at 128 units on both sides
		mask:SetTexture(ORNAMENT_TEXTURES.shiny, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end)
	local anim = CreateSheenAnimation(target, container, { sheen, ornamentSheen })

	overlay:Hide()
	ornament:Hide()
	target.FGFRarityFrame = overlay
	local art = {
		overlay = overlay,
		ornament = ornament,
		sheen = sheen,
		ornamentSheen = ornamentSheen,
		sheenMask = sheenMask,
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
	art.overlay:SetShown(silver)
	if ornamentTexture then
		art.ornament:SetTexture(ornamentTexture) -- art-ok: the ornament is square 256 px art drawn at 128 units on both sides
		art.ornamentMask:SetTexture(ORNAMENT_TEXTURES.shiny, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		art.ornament:Show()
	else
		art.ornament:Hide()
	end
	if shiny then
		art.sheen:Show()
		art.sheenMask:Show()
		art.ornamentSheen:Show()
		art.ornamentMask:Show()
		if not art.anim:IsPlaying() then
			art.sheen:SetAlpha(0)
			art.ornamentSheen:SetAlpha(0)
			art.anim:Play()
		end
	else
		art.anim:Stop()
		art.sheen:Hide()
		art.sheenMask:Hide()
		art.ornamentSheen:Hide()
		art.ornamentMask:Hide()
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
		tag.text:SetText(label)
		tag.plate:SetVertexColor(color[1], color[2], color[3], 1)
		tag:SetSize(math.max(24, tag.text:GetStringWidth() + TAG_PAD * 2), TAG_HEIGHT)
		tag:Show()
	else
		tag:Hide()
	end
end

---@param owner table?
---@param healthBar table?
---@param tier string
---@param discovery boolean?
local function UpdateAccent(owner, healthBar, tier, discovery)
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
		marker:SetPoint("LEFT", healthBar, "RIGHT", 2, 0)
		owner.FGFRarityMarker = marker
	end
	if marker then
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
	local size = UnitSize("target")
	local target = _G.TargetFrame
	local name = target and (target.name or target.Name)
	if type(name) ~= "table" then
		name = nil
	end

	PaintTargetFrame(target, tier, color, NativeFrame("target"))
	local parts = {}
	local badge = ns.Model.SizeBadge(size)
	if size then
		parts[#parts + 1] = ns.Model.FormatSize(size)
	end
	if badge then
		table.insert(parts, 1, L[badge])
	end
	if TARGET_TAGS[tier] then
		parts[#parts + 1] = L[TARGET_TAGS[tier]]
	end
	local tagColor = color or (badge and SIZE_TAG_COLORS[badge])
	if not tagColor and size then
		local r, g, b = Art.RGBA("muted", 1)
		tagColor = { r, g, b }
	end
	PaintTag(target, name, tagColor, #parts > 0 and table.concat(parts, " · ") or nil)
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
	UpdateAccent(frame, healthBar, tier, discovery)
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
				UpdateAccent(frame, bar, "bronze", false)
			end
		end
	end
end)
