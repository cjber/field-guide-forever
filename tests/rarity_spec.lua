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
local container = Mock.CreateFrame("Frame")
local chrome = container:CreateTexture(nil, "BACKGROUND")
chrome:SetSize(192, 67)
chrome:SetPoint("CENTER", container, "CENTER")
chrome:SetVertexColor(unpack(chromeColour))
container.Portrait = Mock.NewRegion("Texture")
local target = Mock.CreateFrame("Frame")
target.TargetFrameContainer = container
container.FrameTexture = chrome
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

local RARE_FRAME = "UI-HUD-UnitFrame-Target-Rare-PortraitOn"
local ORNAMENTS = {
	silver = "Interface\\AddOns\\FieldGuideForever\\media\\Rarity\\Laurel-Silver.tga",
	gold = "Interface\\AddOns\\FieldGuideForever\\media\\Rarity\\Laurel-Gold.tga",
	shiny = "Interface\\AddOns\\FieldGuideForever\\media\\Rarity\\Laurel-Shiny.tga",
}

local function AssertNoTint(piece, label)
	assert(not piece:IsDesaturated(), label .. ": the art is never desaturated")
	local r, g, b = piece:GetVertexColor()
	assert(r == 1 and g == 1 and b == 1, label .. ": the art is never tinted")
end

local function FrameShown()
	for _, piece in ipairs(target.FGFRarityFrame) do
		if piece:IsShown() then
			return true
		end
	end
	return false
end

---@param tier string
---@param label string
local function AssertTargetFrame(tier, label)
	local art = target.FGFRarityArt
	assert(type(art) == "table", label .. ": the target frame gets the rarity art")
	local hasSilver = tier == "silver" or tier == "shiny"
	assert(art.bar == nil and art.barMask == nil, label .. ": the rare frame's bar piece is never drawn")
	assert(art.sheen == nil and art.sheenMask == nil, label .. ": no frame sheen is created")
	if hasSilver then
		assert(art.ring:IsShown(), label .. ": the silver rare-frame ring is shown")
		assert(art.ring:GetAtlas() == RARE_FRAME, label .. ": it is the game's rare frame atlas")
		assert(art.ring.atlasUseSize, label .. ": the rare frame keeps the atlas's own size")
		AssertNoTint(art.ring, label)
		local point, relativeTo, relativePoint, x, y = art.ring:GetPoint(1)
		assert(
			point == "CENTER" and relativeTo == container and relativePoint == "CENTER" and x == 0 and y == 0,
			label .. ": the ring piece keeps FrameTexture's own anchors"
		)
		assert(art.ring.mask == art.ringMask, label .. ": the ring piece is cut to the portrait circle")
		local maskPoint, maskRelativeTo, maskRelativePoint, maskX, maskY = art.ringMask:GetPoint(1)
		assert(
			maskPoint == "CENTER"
				and maskRelativeTo == container.Portrait
				and maskRelativePoint == "CENTER"
				and maskX == 0
				and maskY == 0,
			label .. ": the circle mask is centred on the portrait"
		)
		local maskWidth, maskHeight = art.ringMask:GetSize()
		assert(maskWidth == 64 and maskHeight == 64, label .. ": the circle mask is the ring's outer diameter")
		assert(art.ringMask._texture == "Interface\\Masks\\CircleMask", label .. ": the mask is the client's circle")
	else
		assert(not art.ring:IsShown(), label .. ": no silver ring on this tier")
	end
	assert(art.ornament:IsShown(), label .. ": the " .. tier .. " ornament is shown")
	assert(art.ornament._texture == ORNAMENTS[tier], label .. ": it is the " .. tier .. " laurel ornament file")
	local width, height = art.ornament:GetSize()
	assert(width == 128 and height == 128, label .. ": the ornament keeps its square 128-unit size")
	local point, relativeTo, relativePoint, x, y = art.ornament:GetPoint(1)
	assert(
		point == "CENTER" and relativeTo == container.Portrait and relativePoint == "CENTER" and x == 16 and y == 16,
		label .. ": the ornament anchors its round hole over the portrait"
	)
	AssertNoTint(art.ornament, label)
	if tier == "shiny" then
		assert(art.anim:IsPlaying(), label .. ": the shiny sheen animates")
		assert(art.ornamentSheen:IsShown(), label .. ": the ornament sheen is shown")
		assert(art.ornamentMask:IsShown(), label .. ": the ornament sheen mask is shown")
		assert(art.ornamentSheen.mask == art.ornamentMask, label .. ": the ornament sheen is masked")
		assert(art.ornamentMask._texture == ORNAMENTS.shiny, label .. ": the ornament mask is the shiny ornament file")
	else
		assert(not art.anim:IsPlaying(), label .. ": only shiny animates")
		assert(not art.ornamentSheen:IsShown(), label .. ": the sheen hides with the art")
	end
end

Mock.Fire("PLAYER_TARGET_CHANGED")
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
assert(rawget(target, "FGFRarityTag") == nil, "no tier tag is drawn above the target name")
AssertTargetFrame("silver", "a silver target")
harness.env.UnitName = function(unit)
	return unit == "target" and gold.name or "Tester"
end
Mock.guids.target = GuidFor("gold", "t")
Mock.Fire("PLAYER_TARGET_CHANGED")
AssertTargetColoursUntouched("a gold target")
AssertTargetFrame("gold", "a gold target")

harness.env.UnitName = function()
	return "Uncatalogued"
end
Mock.guids.target = GuidFor("bronze", "t")
Mock.Fire("PLAYER_TARGET_CHANGED")
AssertTargetColoursUntouched("a bronze target")
assert(not FrameShown(), "an uncatalogued target hides the frame recolour")
assert(not target.FGFRarityArt.ornament:IsShown(), "an uncatalogued target hides the ornament")
chromeR, chromeG, chromeB, chromeA = chrome:GetVertexColor()
assert(not chrome:IsDesaturated(), "the chrome stays untouched after cleanup")
assert(
	chromeR == chromeColour[1]
		and chromeG == chromeColour[2]
		and chromeB == chromeColour[3]
		and chromeA == chromeColour[4],
	"the chrome tint is unchanged after cleanup"
)

-- Rare, elite, boss and minus-mob units already get the client's own silver, gold or reduced frame art. Our ornament
-- stays out of the way; the nameplate mark still tells the player which coat this spawn rolled.
harness.env.UnitName = function(unit)
	return unit == "target" and silver.name or "Tester"
end
Mock.guids.target = GuidFor("silver", "t")
for _, classification in ipairs({ "rare", "rareelite", "elite", "minus" }) do
	Mock.classification.target = classification
	Mock.Fire("PLAYER_TARGET_CHANGED")
	assert(not FrameShown(), "a " .. classification .. " target keeps the client's own frame without our art")
	assert(not target.FGFRarityArt.ornament:IsShown(), "a " .. classification .. " target adds no ornament")
	assert(not target.FGFRarityArt.anim:IsPlaying(), "a " .. classification .. " target starts no sheen")
end
Mock.classification.target = "normal"
Mock.boss.target = true
Mock.Fire("PLAYER_TARGET_CHANGED")
assert(not FrameShown(), "a boss target keeps the client's own frame without our art")
assert(not target.FGFRarityArt.anim:IsPlaying(), "a boss target starts no sheen")
Mock.boss.target = false

-- A dead target keeps the recolour: the frame should still read as its tier, just as the client's own frame does.
Mock.dead.target = true
Mock.Fire("PLAYER_TARGET_CHANGED")
AssertTargetFrame("silver", "a dead silver target")
Mock.dead.target = false

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
AssertTargetFrame("silver", "combat leaves the previous tier untouched")
harness.env.InCombatLockdown = function()
	return false
end
Mock.Fire("PLAYER_REGEN_ENABLED")
AssertTargetColoursUntouched("a target change after combat")
AssertTargetFrame("shiny", "a shiny target after combat")

-- The sheen is cosmetic and animates nothing protected, so a fight does not stop it; hiding the art does.
local shinyArt = target.FGFRarityArt
harness.env.InCombatLockdown = function()
	return true
end
Mock.Fire("PLAYER_TARGET_CHANGED")
assert(shinyArt.anim:IsPlaying(), "the shiny sheen keeps playing in combat")
harness.env.InCombatLockdown = function()
	return false
end
Mock.Fire("PLAYER_REGEN_ENABLED")
assert(shinyArt.anim:IsPlaying(), "a combat-end relayout leaves the sheen playing")
harness.env.UnitName = function()
	return "Uncatalogued"
end
Mock.guids.target = GuidFor("bronze", "t")
Mock.Fire("PLAYER_TARGET_CHANGED")
assert(not shinyArt.anim:IsPlaying(), "the sheen stops when the target art hides")
assert(not shinyArt.ornamentSheen:IsShown(), "hiding the art hides the ornament sheen")

-- A nameplate is recycled between units, so a tier is marked by its quality icon only and never by the plate's own
-- health colour or name. The fixture is a stock plate: the client anchors a 22 by 22 RaidTargetFrame's right edge on
-- HealthBarsContainer's left, a 20 by 20 ClassificationFrame's right edge on the raid target's left, and then hangs
-- the buff row's right edge 5 units left of the classification frame while it grows left (Blizzard_NamePlates.xml
-- 186-236, Blizzard_NamePlateUnitFrame.lua:848-858, Blizzard_NamePlateAuras.lua:315-323). Both badges carry
-- collapsesLayout, so hiding one removes its 22 or 20 units instead of reserving them. The Classic health bar is
-- inset 3.5 units from the container's left; Modern fills it (Blizzard_NamePlateUnitFrame.lua:731-738).
local plateReaction = { 0.64, 0.2, 0.17, 1 }
local PLATE_RAID_TARGET_SIZE = 22
local PLATE_CLASSIFICATION_SIZE = 20
local PLATE_BUFF_ICON_SIZE = 25
local PLATE_BUFF_GAP = 5
local PLATE_MARK_GAP = 2

local function NewStockPlate(modern, classificationShown, buffCount, raidShown)
	local fixture = {}
	-- The client treats a nameplate, and every region the addon anchors to it, as restricted: measuring one raises.
	-- The fixture is marked so, so the whole spec runs against regions that refuse GetPoint and GetNumPoints.
	fixture.plate = Mock.Restrict(Mock.CreateFrame("Frame"))
	fixture.unitFrame = Mock.CreateFrame("Frame", nil, fixture.plate)
	fixture.plate.UnitFrame = fixture.unitFrame
	fixture.container = Mock.CreateFrame("Frame", nil, fixture.unitFrame)
	fixture.unitFrame.HealthBarsContainer = fixture.container
	fixture.healthBar = Mock.CreateFrame("Frame", nil, fixture.container)
	fixture.healthBar:SetStatusBarColor(unpack(plateReaction))
	fixture.container.healthBar = fixture.healthBar
	fixture.unitFrame.healthBar = fixture.healthBar
	if modern then
		fixture.healthBar:SetPoint("TOPLEFT", fixture.container, "TOPLEFT", 0, 0)
		fixture.healthBar:SetPoint("BOTTOMRIGHT", fixture.container, "BOTTOMRIGHT", 0, 0)
	else
		fixture.healthBar:SetPoint("TOPLEFT", fixture.container, "TOPLEFT", 3.5, 0.5)
		fixture.healthBar:SetPoint("BOTTOMRIGHT", fixture.container, "BOTTOMRIGHT", -20.75, 0.5)
	end
	fixture.raidTarget = Mock.CreateFrame("Frame", nil, fixture.unitFrame)
	fixture.raidTarget.collapsesLayout = true
	fixture.raidTarget:SetSize(PLATE_RAID_TARGET_SIZE, PLATE_RAID_TARGET_SIZE)
	fixture.raidTarget:SetPoint("RIGHT", fixture.container, "LEFT", 0, 0)
	fixture.raidTarget:SetShown(raidShown or false)
	fixture.unitFrame.RaidTargetFrame = fixture.raidTarget
	fixture.classification = Mock.CreateFrame("Frame", nil, fixture.unitFrame)
	fixture.classification.collapsesLayout = true
	fixture.classification:SetSize(PLATE_CLASSIFICATION_SIZE, PLATE_CLASSIFICATION_SIZE)
	fixture.classification:SetPoint("RIGHT", fixture.raidTarget, "LEFT", 0, 0)
	-- A raid icon hides the classification frame; the two never show together.
	fixture.classification:SetShown((classificationShown or false) and not raidShown)
	fixture.unitFrame.ClassificationFrame = fixture.classification
	fixture.auras = Mock.CreateFrame("Frame", nil, fixture.unitFrame)
	fixture.unitFrame.AurasFrame = fixture.auras
	fixture.buffs = Mock.CreateFrame("Frame", nil, fixture.auras)
	fixture.auras.BuffListFrame = fixture.buffs
	fixture.aurasShown = true
	fixture.buffsShown = true
	fixture.buffCount = buffCount or 0
	-- The aura list is a layout frame: it is 1 unit wide with no icons and grows left by whole 25-unit icons.
	fixture.buffs:SetSize(math.max(1, fixture.buffCount * PLATE_BUFF_ICON_SIZE), PLATE_BUFF_ICON_SIZE)
	fixture.buffs:SetPoint("RIGHT", fixture.classification, "LEFT", -PLATE_BUFF_GAP, 0)
	-- NamePlateAurasMixin's lifecycle reduced to what the mark depends on: UpdateShownState shows or hides the buff
	-- row from the unit/CVar state, and RefreshAuras lays a shown row out after an aura change, resizing it to whole
	-- icons (Blizzard_NamePlateAuras.lua:363-404, 499-575).
	function fixture.auras:UpdateShownState()
		self:SetShown(fixture.aurasShown)
		self.BuffListFrame:SetShown(self:IsShown() and fixture.buffsShown)
	end
	function fixture.auras:RefreshAuras()
		if not self.BuffListFrame:IsShown() then
			return
		end
		self.BuffListFrame:SetSize(math.max(1, fixture.buffCount * PLATE_BUFF_ICON_SIZE), PLATE_BUFF_ICON_SIZE)
	end
	return fixture
end

-- The fixture's horizontal layout, from the stock anchors upward: container left is 0, a RIGHT anchor sits on the
-- relative frame's LEFT plus its offset, and a TOPLEFT anchor starts at the relative frame's left plus its offset.
-- A hidden collapsesLayout frame has no width, so the next anchor in the row moves onto its right edge.
local function FrameWidth(frame)
	if frame.collapsesLayout and not frame:IsShown() then
		return 0
	end
	return Mock.Size(frame)
end

local function LeftEdge(frame, root, lefts)
	if frame == root then
		return 0
	end
	lefts = lefts or {}
	if lefts[frame] then
		return lefts[frame]
	end
	local point, relativeTo, relativePoint, x = Mock.Point(frame)
	assert(relativeTo, "the fixture frame is anchored")
	local relativeLeft = LeftEdge(relativeTo, root, lefts)
	local left
	if point == "RIGHT" and relativePoint == "LEFT" then
		left = relativeLeft + (x or 0) - FrameWidth(frame)
	elseif point == "TOPLEFT" then
		left = relativeLeft + (x or 0)
	else
		error("unexpected fixture anchor " .. tostring(point))
	end
	lefts[frame] = left
	return left
end

local function AssertClears(first, second, root, label)
	local firstLeft = LeftEdge(first, root)
	local secondLeft = LeftEdge(second, root)
	assert(firstLeft + FrameWidth(first) <= secondLeft or secondLeft + FrameWidth(second) <= firstLeft, label)
end

local modern = NewStockPlate(true, true, 2)
local plate, unitFrame = modern.plate, modern.unitFrame
unitFrame.name = unitFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
unitFrame.name:SetTextColor(unpack(plateReaction))
unitFrame.reactionColor = plateReaction
local plateHealthCalls = SpyColour(unitFrame.healthBar, "SetStatusBarColor")
local plateNameCalls = SpyColour(unitFrame.name, "SetTextColor")
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
assert(plate.FGFRarityMarker:GetAtlas() == "Professions-Icon-Quality-Tier2", "the nameplate carries the silver mark")
assert(plate.FGFRarityMarker:IsShown(), "a tiered nameplate shows its tag")
unitFrame:Hide()
assert(plate.FGFRarityMarker:IsVisible(), "the mark stays visible when a skin hides Blizzard's UnitFrame")
unitFrame:Show()
local markerPoint, markerRelative, markerRelativePoint, markerX, markerY = Mock.Point(plate.FGFRarityMarker)
AssertClears(
	plate.FGFRarityMarker,
	modern.buffs,
	modern.container,
	"the nameplate mark clears both of the buff row's 25-unit icons"
)
AssertClears(
	plate.FGFRarityMarker,
	modern.classification,
	modern.container,
	"the nameplate mark clears the classification frame's 20-unit slot"
)
assert(
	markerPoint == "RIGHT"
		and markerRelative == modern.buffs
		and markerRelativePoint == "LEFT"
		and markerX == -PLATE_MARK_GAP
		and markerY == 0,
	"the nameplate mark sits 2 units beyond the buff row's own left edge"
)
assert(
	LeftEdge(modern.buffs, modern.container) + FrameWidth(modern.buffs)
		== LeftEdge(modern.classification, modern.container) - PLATE_BUFF_GAP,
	"the stock buff row keeps its 5-unit gap from the classification frame"
)

harness.env.UnitName = function(unit)
	return unit == "nameplate1" and gold.name or "Tester"
end
Mock.guids.nameplate1 = GuidFor("gold", "p")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
AssertPlateColoursUntouched("a nameplate after a tier change")
assert(plate.FGFRarityMarker:GetAtlas() == "Professions-Icon-Quality-Tier3", "the nameplate mark follows a tier change")

plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
AssertPlateColoursUntouched("a removed nameplate")
assert(not plate.FGFRarityMarker:IsShown(), "removing a nameplate clears its tag")

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
assert(not plate.FGFRarityMarker:IsShown(), "an untiered nameplate shows no tag")

-- A tiered unit still marks the recycled plate, again without touching its colours.
harness.env.UnitName = function(unit)
	return unit == "nameplate1" and shiny.name or "Tester"
end
Mock.guids.nameplate1 = GuidFor("shiny", "p")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
AssertPlateColoursUntouched("a tiered unit on a recycled nameplate")
assert(plate.FGFRarityMarker:IsShown(), "a tiered unit shows its tag on a recycled plate")
assert(
	plate.FGFRarityMarker:GetAtlas() == "Professions-Icon-Quality-Tier4",
	"a shiny nameplate mark is the fourth quality mark"
)
plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
AssertPlateColoursUntouched("a recycled nameplate removed again")
assert(not plate.FGFRarityMarker:IsShown(), "clearing a tiered nameplate hides its tag")

-- Both stock layouts keep the mark clear of the client's own left badge and buff row. The Classic fixture keeps the
-- health bar's 3.5-unit inset, which the old bar-left anchor still left inside the 22-unit raid target slot.
local classic = NewStockPlate(false, true, 2)
local classicPlate = classic.plate
local classicAttached = true
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return classicAttached and classicPlate or nil
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate9" and gold.name or "Tester"
end
Mock.guids.nameplate9 = GuidFor("gold", "classic")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
local classicPoint, classicRelative, classicRelativePoint, classicX = Mock.Point(classicPlate.FGFRarityMarker)
AssertClears(classicPlate.FGFRarityMarker, classic.buffs, classic.container, "the Classic mark clears both buff icons")
AssertClears(
	classicPlate.FGFRarityMarker,
	classic.classification,
	classic.container,
	"the Classic mark clears the classification frame"
)
assert(
	classicPoint == "RIGHT"
		and classicRelative == classic.buffs
		and classicRelativePoint == "LEFT"
		and classicX == -PLATE_MARK_GAP,
	"a Classic nameplate also joins the buff row's left edge"
)
assert(LeftEdge(classic.healthBar, classic.container) == 3.5, "the Classic fixture keeps the stock bar inset")
classicAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate9")
assert(not classicPlate.FGFRarityMarker:IsShown(), "removing a Classic nameplate clears its mark")

-- The reported collision: a stock plate with no raid icon and no classification badge, two buffs. Both badge frames
-- carry collapsesLayout, so the hidden 22- and 20-unit slots vanish; the buff row's right edge lands 5 units left of
-- the health container, not 47. The mark must clear the actual buffs rather than a 42-unit shadow.
local collapsed = NewStockPlate(true, false, 2, false)
local collapsedAttached = true
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return collapsedAttached and collapsed.plate or nil
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate11" and shiny.name or "Tester"
end
Mock.guids.nameplate11 = GuidFor("shiny", "collapsed")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate11")
assert(not collapsed.raidTarget:IsShown(), "the fixture has no raid icon")
assert(not collapsed.classification:IsShown(), "the fixture has no classification badge")
assert(
	LeftEdge(collapsed.raidTarget, collapsed.container) == 0
		and LeftEdge(collapsed.classification, collapsed.container) == 0,
	"hidden collapsesLayout badges reserve no width"
)
assert(
	LeftEdge(collapsed.buffs, collapsed.container) + FrameWidth(collapsed.buffs) == -PLATE_BUFF_GAP,
	"the buff row sits 5 units left of the collapsed badge slot, not 47"
)
assert(
	LeftEdge(collapsed.plate.FGFRarityMarker, collapsed.container) + FrameWidth(collapsed.plate.FGFRarityMarker)
		<= LeftEdge(collapsed.buffs, collapsed.container),
	"the mark clears both buffs when no badges are shown"
)
local collapsedPoint, collapsedRelative, collapsedRelativePoint, collapsedX =
	Mock.Point(collapsed.plate.FGFRarityMarker)
assert(
	collapsedPoint == "RIGHT"
		and collapsedRelative == collapsed.buffs
		and collapsedRelativePoint == "LEFT"
		and collapsedX == -PLATE_MARK_GAP,
	"the collapsed-badge mark still anchors beyond the buff row"
)
collapsedAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate11")

-- A hidden buff row draws nothing and has no laid-out width to trust, so the mark falls back to the classification
-- badge rather than hanging off a stale 300-unit aura-list frame.
local hiddenRow = NewStockPlate(true, true, 2)
hiddenRow.buffs:Hide()
local hiddenRowAttached = true
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return hiddenRowAttached and hiddenRow.plate or nil
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate14" and gold.name or "Tester"
end
Mock.guids.nameplate14 = GuidFor("gold", "hidden-row")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate14")
local hiddenPoint, hiddenRelative, hiddenRelativePoint, hiddenX = Mock.Point(hiddenRow.plate.FGFRarityMarker)
assert(
	hiddenPoint == "RIGHT"
		and hiddenRelative == hiddenRow.classification
		and hiddenRelativePoint == "LEFT"
		and hiddenX == -PLATE_MARK_GAP,
	"a hidden buff row falls back to the classification frame's left edge less 2"
)
hiddenRowAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate14")

-- A plate can be marked while its buff row is hidden, then receive buffs. The client shows the row and lays it out
-- outside our nameplate events, so the mark must leave the badge for the row's new left edge instead of staying under
-- the icons. Choosing the anchor only when the mark was created left it on the classification frame here.
local appear = NewStockPlate(true, true, 0)
local appearPlate = appear.plate
local appearAttached = true
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return appearAttached and appearPlate or nil
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate15" and silver.name or "Tester"
end
appear.buffsShown = false
appear.auras:UpdateShownState()
Mock.guids.nameplate15 = GuidFor("silver", "buffs-appear")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate15")
local appearPoint, appearRelative = Mock.Point(appearPlate.FGFRarityMarker)
assert(
	appearPoint == "RIGHT" and appearRelative == appear.classification,
	"with no buff row shown the mark waits on the classification frame"
)
appear.buffCount = 2
appear.buffsShown = true
appear.auras:UpdateShownState()
appear.auras:RefreshAuras()
local appearedPoint, appearedRelative, appearedRelativePoint, appearedX = Mock.Point(appearPlate.FGFRarityMarker)
assert(
	appearedPoint == "RIGHT"
		and appearedRelative == appear.buffs
		and appearedRelativePoint == "LEFT"
		and appearedX == -PLATE_MARK_GAP,
	"buffs appearing move the existing mark to the row's left edge"
)
AssertClears(
	appearPlate.FGFRarityMarker,
	appear.buffs,
	appear.container,
	"the moved mark clears both icons that appeared after it was created"
)
appearAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate15")

-- The client restricts a nameplate and every region anchored to it, so measuring the mark raises FrameMeasurement and
-- aborts the caller; before the fix that error stopped the reanchor after the first placement, on every aura update.
-- The mark now remembers the anchor it was given, so marking, both hooks and UpdateAccent never measure it, a changed
-- anchor still moves it, and an unchanged anchor leaves it alone.
local restricted = NewStockPlate(true, true, 0)
local restrictedPlate = restricted.plate
local restrictedAttached = true
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return restrictedAttached and restrictedPlate or nil
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate19" and silver.name or "Tester"
end
restricted.buffsShown = false
restricted.auras:UpdateShownState()
Mock.guids.nameplate19 = GuidFor("silver", "restricted")
local markedOk, markError = pcall(Mock.Fire, "NAME_PLATE_UNIT_ADDED", "nameplate19")
assert(markedOk, "marking a nameplate never measures its restricted regions: " .. tostring(markError))
local restrictedMarker = restrictedPlate.FGFRarityMarker
assert(Mock.IsRestricted(restrictedMarker), "the nameplate mark is a restricted region")
local placedPoint, placedRelative = Mock.Point(restrictedMarker)
assert(
	placedPoint == "RIGHT" and placedRelative == restricted.classification,
	"a restricted nameplate still takes its mark on the fallback anchor"
)
local placedCalls = Mock.SetPointCalls(restrictedMarker)
assert(placedCalls == 1, "the first placement sets exactly one point")

restricted.buffCount = 2
restricted.buffsShown = true
local shownOk, shownError = pcall(restricted.auras.UpdateShownState, restricted.auras)
assert(shownOk, "the shown-state hook never measures the restricted mark: " .. tostring(shownError))
local refreshedOk, refreshedError = pcall(restricted.auras.RefreshAuras, restricted.auras)
assert(refreshedOk, "the aura refresh hook never measures the restricted mark: " .. tostring(refreshedError))
local movedCalls = Mock.SetPointCalls(restrictedMarker)
assert(movedCalls == placedCalls + 1, "a changed anchor sets one new point")
local movedPoint, movedRelative = Mock.Point(restrictedMarker)
assert(
	movedPoint == "RIGHT" and movedRelative == restricted.buffs,
	"a changed anchor moves the restricted mark onto the buff row"
)
assert(Mock.PointCount(restrictedMarker) == 1, "the moved mark keeps exactly one point")

local accentOk, accentError = pcall(Mock.Fire, "NAME_PLATE_UNIT_ADDED", "nameplate19")
assert(accentOk, "UpdateAccent never measures the restricted mark: " .. tostring(accentError))
local againOk, againError = pcall(restricted.auras.UpdateShownState, restricted.auras)
assert(againOk, "a repeated shown state never measures the restricted mark: " .. tostring(againError))
local againRefreshOk, againRefreshError = pcall(restricted.auras.RefreshAuras, restricted.auras)
assert(againRefreshOk, "a repeated aura refresh never measures the restricted mark: " .. tostring(againRefreshError))
assert(Mock.SetPointCalls(restrictedMarker) == movedCalls, "an unchanged anchor does not call SetPoint again")

restricted.buffsShown = false
local hiddenOk, hiddenError = pcall(restricted.auras.UpdateShownState, restricted.auras)
assert(hiddenOk, "hiding the buff row never measures the restricted mark: " .. tostring(hiddenError))
local backPoint, backRelative = Mock.Point(restrictedMarker)
assert(
	backPoint == "RIGHT" and backRelative == restricted.classification,
	"hiding the buff row moves the restricted mark back to the classification frame"
)
local hiddenCalls = Mock.SetPointCalls(restrictedMarker)
assert(hiddenCalls == movedCalls + 1, "hiding the buff row sets one new point")
local settledOk, settledError = pcall(restricted.auras.UpdateShownState, restricted.auras)
assert(settledOk, "a repeated hidden state never measures the restricted mark: " .. tostring(settledError))
assert(
	Mock.SetPointCalls(restrictedMarker) == hiddenCalls,
	"a reanchor onto the anchor already set does not call SetPoint"
)
restrictedAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate19")

-- The row can also grow while it stays shown. Its right edge is fixed and each new 25-unit icon moves the left edge
-- further out, so the same anchor keeps the mark clear without another lifecycle event.
local growing = NewStockPlate(true, true, 1)
local growingPlate = growing.plate
local growingAttached = true
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return growingAttached and growingPlate or nil
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate16" and gold.name or "Tester"
end
Mock.guids.nameplate16 = GuidFor("gold", "buffs-grow")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate16")
local oneBuffLeft = LeftEdge(growing.buffs, growing.container)
growing.buffCount = 2
growing.auras:RefreshAuras()
local grewPoint, grewRelative, grewRelativePoint, grewX = Mock.Point(growingPlate.FGFRarityMarker)
assert(
	grewPoint == "RIGHT" and grewRelative == growing.buffs and grewRelativePoint == "LEFT" and grewX == -PLATE_MARK_GAP,
	"a second buff keeps the mark on the row's left edge"
)
assert(
	LeftEdge(growing.buffs, growing.container) == oneBuffLeft - PLATE_BUFF_ICON_SIZE,
	"the second icon grows the row another 25 units left"
)
AssertClears(
	growingPlate.FGFRarityMarker,
	growing.buffs,
	growing.container,
	"the mark clears the row after it grows to two icons"
)
growingAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate16")

-- NamePlateAurasMixin:SetUnit registers its CVar callbacks with the original UpdateShownState and RefreshAuras before
-- NAME_PLATE_UNIT_ADDED lets Field Guide install post-hooks. A CVar change therefore calls the saved originals and
-- hides or shows the row without passing through those hooks. The registry mock fires Field Guide's callback before
-- the native one, because registry order is unspecified; only a deferred reanchor can wait for the native work.
local auraCvars = {
	ENEMY_NPC_AURA_DISPLAY_CVAR = "nameplateEnemyNpcAuraDisplay",
	ENEMY_PLAYER_AURA_DISPLAY_CVAR = "nameplateEnemyPlayerAuraDisplay",
	FRIENDLY_PLAYER_AURA_DISPLAY_CVAR = "nameplateFriendlyPlayerAuraDisplay",
	SHOW_DEBUFFS_ON_FRIENDLY_CVAR = "nameplateShowDebuffsOnFriendly",
	AURA_SCALE_CVAR = "nameplateAuraScale",
	SHOW_ALL_PERSONAL_AURAS_CVAR = "nameplateShowAllPersonalAuras",
}
harness.env.NamePlateConstants = auraCvars
local cvarRegistry = { callbacks = {} }
function cvarRegistry:RegisterCallback(event, callback, owner)
	local callbacks = self.callbacks[event] or {}
	self.callbacks[event] = callbacks
	callbacks[#callbacks + 1] = { callback = callback, owner = owner }
end
function cvarRegistry:Fire(event)
	local callbacks = self.callbacks[event] or {}
	for index = #callbacks, 1, -1 do
		local entry = callbacks[index]
		entry.callback(entry.owner)
	end
end
harness.env.CVarCallbackRegistry = cvarRegistry

local cvarPlate = NewStockPlate(true, true, 2)
local cvarPlateAttached = true
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return cvarPlateAttached and cvarPlate.plate or nil
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate18" and silver.name or "Tester"
end
Mock.guids.nameplate18 = GuidFor("silver", "cvar-saved-original")
function cvarPlate.auras:UpdateAuraScale()
	self:RefreshAuras()
end
local savedShownState = cvarPlate.auras.UpdateShownState
local savedRefreshAuras = cvarPlate.auras.RefreshAuras
local savedAuraScale = cvarPlate.auras.UpdateAuraScale
local shownStateCvars = {
	auraCvars.ENEMY_NPC_AURA_DISPLAY_CVAR,
	auraCvars.ENEMY_PLAYER_AURA_DISPLAY_CVAR,
	auraCvars.FRIENDLY_PLAYER_AURA_DISPLAY_CVAR,
	auraCvars.SHOW_DEBUFFS_ON_FRIENDLY_CVAR,
}
for _, cvar in ipairs(shownStateCvars) do
	cvarRegistry:RegisterCallback(cvar, savedShownState, cvarPlate.auras)
end
cvarRegistry:RegisterCallback(auraCvars.AURA_SCALE_CVAR, savedAuraScale, cvarPlate.auras)
cvarRegistry:RegisterCallback(auraCvars.SHOW_ALL_PERSONAL_AURAS_CVAR, savedRefreshAuras, cvarPlate.auras)
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate18")
for _, cvar in ipairs({
	auraCvars.ENEMY_NPC_AURA_DISPLAY_CVAR,
	auraCvars.ENEMY_PLAYER_AURA_DISPLAY_CVAR,
	auraCvars.FRIENDLY_PLAYER_AURA_DISPLAY_CVAR,
	auraCvars.SHOW_DEBUFFS_ON_FRIENDLY_CVAR,
	auraCvars.AURA_SCALE_CVAR,
	auraCvars.SHOW_ALL_PERSONAL_AURAS_CVAR,
}) do
	assert(#(cvarRegistry.callbacks[cvar] or {}) == 2, "Field Guide follows the native CVar " .. cvar)
end
assert(cvarPlate.auras.UpdateShownState ~= savedShownState, "the plate now carries Field Guide's instance hook")
local cvarStartPoint, cvarStartRelative = Mock.Point(cvarPlate.plate.FGFRarityMarker)
assert(
	cvarStartPoint == "RIGHT" and cvarStartRelative == cvarPlate.buffs,
	"the saved-original test starts with the mark on the buff row"
)
for _, cvar in ipairs(shownStateCvars) do
	cvarPlate.buffsShown = false
	cvarRegistry:Fire(cvar)
	assert(not cvarPlate.buffs:IsShown(), cvar .. ": the native saved callback hides the row")
	local pendingPoint, pendingRelative = Mock.Point(cvarPlate.plate.FGFRarityMarker)
	assert(
		pendingPoint == "RIGHT" and pendingRelative == cvarPlate.buffs,
		cvar .. ": before the deferred reanchor the mark still follows the hidden row"
	)
	harness:RunTimers()
	local savedHiddenPoint, savedHiddenRelative, savedHiddenRelativePoint, savedHiddenX =
		Mock.Point(cvarPlate.plate.FGFRarityMarker)
	assert(
		savedHiddenPoint == "RIGHT"
			and savedHiddenRelative == cvarPlate.classification
			and savedHiddenRelativePoint == "LEFT"
			and savedHiddenX == -PLATE_MARK_GAP,
		cvar .. ": the deferred reanchor moves the mark off the hidden row"
	)

	cvarPlate.buffsShown = true
	cvarRegistry:Fire(cvar)
	assert(cvarPlate.buffs:IsShown(), cvar .. ": the native saved callback shows the row again")
	harness:RunTimers()
	local shownPoint, shownRelative = Mock.Point(cvarPlate.plate.FGFRarityMarker)
	assert(
		shownPoint == "RIGHT" and shownRelative == cvarPlate.buffs,
		cvar .. ": the deferred reanchor follows the row back out"
	)
end
cvarPlateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate18")
assert(not cvarPlate.plate.FGFRarityMarker:IsShown(), "removing the saved-original plate clears its mark")

-- A plate is recycled between units. It can lose its buff row while detached and come back to a new unit, so the
-- anchor chosen for the old unit must not survive the recycle; the mark follows the row's current state.
local recycled = NewStockPlate(true, true, 2)
local recycledPlate = recycled.plate
local recycledAttached = true
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return recycledAttached and recycledPlate or nil
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate17" and shiny.name or "Tester"
end
Mock.guids.nameplate17 = GuidFor("shiny", "recycle")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate17")
local recycledPoint, recycledRelative = Mock.Point(recycledPlate.FGFRarityMarker)
assert(recycledPoint == "RIGHT" and recycledRelative == recycled.buffs, "the first unit's mark starts on the buff row")
recycledAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate17")
assert(not recycledPlate.FGFRarityMarker:IsShown(), "the detached plate hides its mark")
recycled.buffsShown = false
recycled.auras:UpdateShownState()
harness.env.UnitName = function(unit)
	return unit == "nameplate17" and gold.name or "Tester"
end
Mock.guids.nameplate17 = GuidFor("gold", "recycle-again")
recycledAttached = true
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate17")
local recycledAgainPoint, recycledAgainRelative, recycledAgainPointRelative, recycledAgainX =
	Mock.Point(recycledPlate.FGFRarityMarker)
assert(
	recycledAgainPoint == "RIGHT"
		and recycledAgainRelative == recycled.classification
		and recycledAgainPointRelative == "LEFT"
		and recycledAgainX == -PLATE_MARK_GAP,
	"a recycled plate with no buff row reanchors to the classification frame"
)
assert(recycledPlate.FGFRarityMarker:IsShown(), "the recycled plate shows the new unit's mark")
recycledAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate17")

-- Skins without Blizzard's buff row fall back through the remaining stock anchors, each 2 units clear. This proves
-- the reference fallbacks only; it does not claim where any particular skin draws its own decorations.
local function NewFallbackPlate()
	local frame = Mock.CreateFrame("Frame")
	frame.healthBar = Mock.CreateFrame("Frame", nil, frame)
	return frame, Mock.CreateFrame("Frame")
end

local classificationFrame, classificationPlate = NewFallbackPlate()
Mock.Restrict(classificationPlate)
classificationFrame.ClassificationFrame = Mock.CreateFrame("Frame", nil, classificationFrame)
classificationFrame.ClassificationFrame:SetSize(PLATE_CLASSIFICATION_SIZE, PLATE_CLASSIFICATION_SIZE)
classificationFrame.ClassificationFrame:SetPoint("RIGHT", classificationFrame.healthBar, "LEFT", -42, 0)
classificationPlate.UnitFrame = classificationFrame
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return classificationPlate
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate12" and silver.name or "Tester"
end
Mock.guids.nameplate12 = GuidFor("silver", "fallback-classification")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate12")
local classificationPoint, classificationRelative, classificationRelativePoint, classificationX =
	Mock.Point(classificationPlate.FGFRarityMarker)
assert(
	classificationPoint == "RIGHT"
		and classificationRelative == classificationFrame.ClassificationFrame
		and classificationRelativePoint == "LEFT"
		and classificationX == -PLATE_MARK_GAP,
	"without a buff row the mark falls back to the classification frame's left edge less 2"
)

local raidFrame, raidPlate = NewFallbackPlate()
Mock.Restrict(raidPlate)
raidFrame.RaidTargetFrame = Mock.CreateFrame("Frame", nil, raidFrame)
raidFrame.RaidTargetFrame:SetSize(PLATE_RAID_TARGET_SIZE, PLATE_RAID_TARGET_SIZE)
raidFrame.RaidTargetFrame:SetPoint("RIGHT", raidFrame.healthBar, "LEFT", 0, 0)
raidPlate.UnitFrame = raidFrame
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return raidPlate
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate13" and gold.name or "Tester"
end
Mock.guids.nameplate13 = GuidFor("gold", "fallback-raid")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate13")
local raidPoint, raidRelative, raidRelativePoint, raidX = Mock.Point(raidPlate.FGFRarityMarker)
assert(
	raidPoint == "RIGHT"
		and raidRelative == raidFrame.RaidTargetFrame
		and raidRelativePoint == "LEFT"
		and raidX == -PLATE_MARK_GAP,
	"without a buff row or classification frame the mark falls back to the raid target's left edge less 2"
)

local bareFrame = Mock.CreateFrame("Frame")
bareFrame.healthBar = Mock.CreateFrame("Frame")
local barePlate = Mock.Restrict(Mock.CreateFrame("Frame"))
barePlate.UnitFrame = bareFrame
harness.env.C_NamePlate = {
	GetNamePlateForUnit = function()
		return barePlate
	end,
}
harness.env.UnitName = function(unit)
	return unit == "nameplate10" and silver.name or "Tester"
end
Mock.guids.nameplate10 = GuidFor("silver", "bare")
Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate10")
local barePoint, bareRelative, bareRelativePoint, bareX = Mock.Point(barePlate.FGFRarityMarker)
assert(
	barePoint == "RIGHT"
		and bareRelative == bareFrame.healthBar
		and bareRelativePoint == "LEFT"
		and bareX == -PLATE_MARK_GAP,
	"a nameplate without the stock frames falls back to the bar's left edge less 2"
)
assert(barePlate.FGFRarityMarker:IsShown(), "the fallback still shows the mark")

-- A plate the addon first sees with no tier keeps the client's own colours and shows no mark.
local freshFrame = Mock.CreateFrame("Frame")
freshFrame.name = freshFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
freshFrame.name:SetTextColor(unpack(friendlyReaction))
freshFrame.healthBar = Mock.CreateFrame("Frame")
freshFrame.healthBar:SetStatusBarColor(unpack(friendlyReaction))
freshFrame.reactionColor = friendlyReaction
local freshHealthCalls = SpyColour(freshFrame.healthBar, "SetStatusBarColor")
local freshNameCalls = SpyColour(freshFrame.name, "SetTextColor")
local freshPlate = Mock.Restrict(Mock.CreateFrame("Frame"))
freshPlate.UnitFrame = freshFrame
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
assert(not freshPlate.FGFRarityMarker:IsShown(), "an untiered plate shows no tier mark")

-- The kill path only counts units the player can attack, so a friendly vendor or quest giver has no spawn tier: a
-- GUID that would roll silver, gold or shiny still paints the plain bronze frame, with no rare frame, ornament, tag or
-- plate mark.
harness.env.UnitCanAttack = function(_, unit)
	return unit ~= "target" and unit ~= "nameplate3"
end
harness.env.UnitName = function(unit)
	return (unit == "target" or unit == "nameplate3") and silver.name or "Sentinel Kyra Starsong"
end
for _, tier in ipairs({ "silver", "gold", "shiny" }) do
	local label = "a friendly " .. tier .. " target"
	Mock.guids.target = GuidFor(tier, "friendly-target")
	Mock.Fire("PLAYER_TARGET_CHANGED")
	assert(not FrameShown(), label .. ": no silver frame")
	assert(not target.FGFRarityArt.ornament:IsShown(), label .. ": no ornament")
	assert(not target.FGFRarityArt.anim:IsPlaying(), label .. ": no sheen")

	Mock.guids.nameplate3 = GuidFor(tier, "friendly-plate")
	Mock.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
	assert(not freshPlate.FGFRarityMarker:IsShown(), label .. ": no plate mark")
end

print("rarity: ok")
