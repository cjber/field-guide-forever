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

-- The tag carries the spawn's size first, its Tiny/Giant badge if it has one, then the coat.
local function ExpectedTag(tier)
	local parts = {}
	local size = ns.Model.SpawnSize(Mock.guids.target)
	local badge = ns.Model.SizeBadge(size)
	if badge then
		parts[#parts + 1] = badge
	end
	if size then
		parts[#parts + 1] = ns.Model.FormatSize(size)
	end
	if tier ~= "bronze" then
		parts[#parts + 1] = tier:upper()
	end
	return table.concat(parts, " · ")
end

local chromeColour = { 0.8, 0.7, 0.6, 0.9 }
local healthColour = { 0.2, 0.6, 0.2, 1 }
local powerColour = { 0.1, 0.2, 0.8, 1 }
local nameColour = { 1, 0.9, 0.8, 1 }
local container = Mock.CreateFrame("Frame")
local chrome = container:CreateTexture(nil, "BACKGROUND")
chrome:SetSize(192, 67)
chrome:SetPoint("CENTER", container, "CENTER")
chrome:SetVertexColor(unpack(chromeColour))
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
local GOLD_RING = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold"
local WING_RING = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged"

local function AssertNoTint(piece, label)
	assert(not piece:IsDesaturated(), label .. ": the client art is never desaturated")
	local r, g, b = piece:GetVertexColor()
	assert(r == 1 and g == 1 and b == 1, label .. ": the client art is never tinted")
end

---@param tier string
---@param label string
local function AssertTargetFrame(tier, label)
	local art = target.FGFRarityArt
	assert(type(art) == "table", label .. ": the target frame gets the client's classification art")
	local hasSilver = tier == "silver" or tier == "shiny"
	if hasSilver then
		assert(art.overlay:IsShown(), label .. ": the silver rare frame is shown")
		assert(art.overlay:GetAtlas() == RARE_FRAME, label .. ": it is the game's rare frame atlas")
		assert(art.overlay.atlasUseSize, label .. ": the rare frame keeps the atlas's own size")
		local point, relativeTo, relativePoint = art.overlay:GetPoint(1)
		assert(
			point == "CENTER" and relativeTo == container and relativePoint == "CENTER",
			label .. ": the rare frame copies FrameTexture's anchors"
		)
		AssertNoTint(art.overlay, label)
	else
		assert(not art.overlay:IsShown(), label .. ": no silver frame on this tier")
	end
	if tier == "gold" then
		assert(art.gold:IsShown(), label .. ": the gold portrait ring is shown")
		assert(art.gold:GetAtlas() == GOLD_RING, label .. ": it is the game's elite gold ring")
		assert(art.gold.atlasUseSize, label .. ": the gold ring keeps the atlas's own size")
		local point, relativeTo, relativePoint, x, y = art.gold:GetPoint(1)
		assert(
			point == "TOPRIGHT" and relativeTo == container and relativePoint == "TOPRIGHT" and x == 0 and y == 1,
			label .. ": the gold ring takes GetBossPortraitFrameData's elite anchor"
		)
		AssertNoTint(art.gold, label)
	else
		assert(not art.gold:IsShown(), label .. ": no gold ring on this tier")
	end
	if tier == "shiny" then
		assert(art.wing:IsShown(), label .. ": the winged silver ring is shown")
		assert(art.wing:GetAtlas() == WING_RING, label .. ": it is the game's rare winged silver ring")
		assert(art.wing.atlasUseSize, label .. ": the winged ring keeps the atlas's own size")
		local point, relativeTo, relativePoint, x, y = art.wing:GetPoint(1)
		assert(
			point == "TOPRIGHT" and relativeTo == container and relativePoint == "TOPRIGHT" and x == 8 and y == -7,
			label .. ": the winged ring takes GetBossPortraitFrameData's shiny anchor"
		)
		AssertNoTint(art.wing, label)
		assert(art.anim:IsPlaying(), label .. ": the shiny sheen animates")
		assert(art.sheen:IsShown() and art.wingSheen:IsShown(), label .. ": both sheen textures are shown")
		assert(art.sheenMask:IsShown() and art.wingMask:IsShown(), label .. ": both sheen masks are shown")
		assert(art.sheen.mask == art.sheenMask, label .. ": the frame sheen is masked")
		assert(art.wingSheen.mask == art.wingMask, label .. ": the winged sheen is masked")
		assert(art.sheenMask:GetAtlas() == RARE_FRAME, label .. ": the frame mask follows the rare frame")
		assert(art.wingMask:GetAtlas() == WING_RING, label .. ": the winged mask follows the winged ring")
	else
		assert(not art.wing:IsShown(), label .. ": no winged ring on this tier")
		assert(not art.anim:IsPlaying(), label .. ": only shiny animates")
		assert(not art.sheen:IsShown() and not art.wingSheen:IsShown(), label .. ": the sheen hides with the art")
	end
end

---@param tier string
---@param label string
local function AssertTargetIcon(tier, label)
	local icon = target.FGFRarityIcon
	assert(type(icon) == "table", label .. ": the target frame gets a tier icon")
	assert(icon:IsShown(), label .. ": the tier icon is shown")
	assert(icon:GetAtlas() == ns.Art.TIER_ICONS[tier], label .. ": the target icon shows the tier's quality mark")
	local width, height = icon:GetSize()
	assert(width == 15 and height == 15, label .. ": the target icon keeps its compact size")
	local point, relativeTo, relativePoint, x, y = icon:GetPoint(1)
	assert(
		point == "BOTTOMLEFT" and relativeTo == container and relativePoint == "BOTTOMLEFT" and x == 24 and y == 14,
		label .. ": the tier icon sits in the free bottom-left corner, clear of the PvP badge"
	)
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
assert(target.FGFRarityTag.text:GetText() == ExpectedTag("silver"), "silver reads its size and SILVER")
local silverTag = target.FGFRarityTag.text:GetText()
local tagR, tagG, tagB = target.FGFRarityTag.plate:GetVertexColor()
assert(
	tagR == silverColour[1] and tagG == silverColour[2] and tagB == silverColour[3],
	"the tag plate takes the tier colour"
)
AssertTargetFrame("silver", "a silver target")
AssertTargetIcon("silver", "a silver target")
harness.env.UnitName = function(unit)
	return unit == "target" and gold.name or "Tester"
end
Mock.guids.target = GuidFor("gold", "t")
Mock.Fire("PLAYER_TARGET_CHANGED")
local goldColour = ns.Rarity.COLORS.gold
AssertTargetColoursUntouched("a gold target")
assert(target.FGFRarityTag.text:GetText() == ExpectedTag("gold"), "gold reads its size and GOLD")
local goldTagR, goldTagG, goldTagB = target.FGFRarityTag.plate:GetVertexColor()
assert(
	goldTagR == goldColour[1] and goldTagG == goldColour[2] and goldTagB == goldColour[3],
	"the tag plate follows a tier change"
)
AssertTargetFrame("gold", "a gold target")
AssertTargetIcon("gold", "a gold target")

harness.env.UnitName = function()
	return "Uncatalogued"
end
Mock.guids.target = GuidFor("bronze", "t")
Mock.Fire("PLAYER_TARGET_CHANGED")
AssertTargetColoursUntouched("a bronze target")
assert(target.FGFRarityTag:IsShown(), "a bronze target still shows its size tag")
assert(target.FGFRarityTag.text:GetText() == ExpectedTag("bronze"), "bronze reads its size")
assert(not target.FGFRarityFrame:IsShown(), "an uncatalogued target hides the frame recolour")
assert(not target.FGFRarityIcon:IsShown(), "an uncatalogued target hides the tier icon")
chromeR, chromeG, chromeB, chromeA = chrome:GetVertexColor()
assert(not chrome:IsDesaturated(), "the chrome stays untouched after cleanup")
assert(
	chromeR == chromeColour[1]
		and chromeG == chromeColour[2]
		and chromeB == chromeColour[3]
		and chromeA == chromeColour[4],
	"the chrome tint is unchanged after cleanup"
)

-- Rare, elite, boss and minus-mob units already get the client's own silver, gold or reduced frame art. Our art
-- stays out of its way, while the tier icon and tag still tell the player which coat this spawn rolled.
harness.env.UnitName = function(unit)
	return unit == "target" and silver.name or "Tester"
end
Mock.guids.target = GuidFor("silver", "t")
for _, classification in ipairs({ "rare", "rareelite", "elite", "minus" }) do
	Mock.classification.target = classification
	Mock.Fire("PLAYER_TARGET_CHANGED")
	assert(
		not target.FGFRarityFrame:IsShown(),
		"a " .. classification .. " target keeps the client's own frame without our art"
	)
	assert(not target.FGFRarityArt.gold:IsShown(), "a " .. classification .. " target adds no gold ring")
	assert(not target.FGFRarityArt.wing:IsShown(), "a " .. classification .. " target adds no winged ring")
	assert(not target.FGFRarityArt.anim:IsPlaying(), "a " .. classification .. " target starts no sheen")
	assert(target.FGFRarityTag:IsShown(), "a " .. classification .. " target still shows its tier tag")
	assert(target.FGFRarityIcon:IsShown(), "a " .. classification .. " target still shows its tier icon")
end
Mock.classification.target = "normal"
Mock.boss.target = true
Mock.Fire("PLAYER_TARGET_CHANGED")
assert(not target.FGFRarityFrame:IsShown(), "a boss target keeps the client's own frame without our art")
assert(not target.FGFRarityArt.anim:IsPlaying(), "a boss target starts no sheen")
Mock.boss.target = false

-- A dead target keeps the recolour: the frame should still read as its tier, just as the client's own frame does.
Mock.dead.target = true
Mock.Fire("PLAYER_TARGET_CHANGED")
AssertTargetFrame("silver", "a dead silver target")
AssertTargetIcon("silver", "a dead silver target")
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
assert(
	target.FGFRarityTag:IsShown() and target.FGFRarityTag.text:GetText() == silverTag,
	"combat leaves the previous tier untouched"
)
harness.env.InCombatLockdown = function()
	return false
end
Mock.Fire("PLAYER_REGEN_ENABLED")
AssertTargetColoursUntouched("a target change after combat")
assert(target.FGFRarityTag:IsShown(), "the shiny tag applies after combat")
assert(target.FGFRarityTag.text:GetText() == ExpectedTag("shiny"), "shiny reads its size and SHINY")
AssertTargetFrame("shiny", "a shiny target after combat")
AssertTargetIcon("shiny", "a shiny target after combat")

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
assert(not shinyArt.sheen:IsShown() and not shinyArt.wingSheen:IsShown(), "hiding the art hides both sheen textures")

-- A nameplate is recycled between units, so a tier is marked by its quality icon only and never by the plate's own
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
local markerPoint, markerRelative, markerRelativePoint, markerX, markerY = unitFrame.FGFRarityMarker:GetPoint(1)
assert(
	markerPoint == "LEFT"
		and markerRelative == unitFrame.healthBar
		and markerRelativePoint == "RIGHT"
		and markerX == 2
		and markerY == 0,
	"the nameplate mark sits clear to the right of the health bar, centred on it"
)

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
plateAttached = false
Mock.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
AssertPlateColoursUntouched("a recycled nameplate removed again")
assert(not unitFrame.FGFRarityMarker:IsShown(), "clearing a tiered nameplate hides its tag")

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

print("rarity: ok")
